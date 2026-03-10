# n8n Server – Self-Hosted Automation on DigitalOcean

Self-hosted [n8n](https://n8n.io) running on a DigitalOcean Droplet with multi-layer security. All admin access goes through Tailscale VPN. Webhooks are served via Cloudflare Tunnel. Direct IP access is blocked at the firewall level.

**Stack:** Ubuntu 24.04 LTS · Docker · Tailscale · Cloudflare Tunnel · iptables · Fail2ban

---

## Architecture

```
 Admin (Tailscale)     ──► Tailscale VPN        ──► n8n UI
 Webhooks (HTTPS)      ──► Cloudflare Tunnel     ──► n8n Webhooks
 Direct IP             ──► iptables DROP
```

---

## Security

| Layer | What it does |
|---|---|
| Tailscale VPN | Zero-trust admin access – n8n UI only reachable from Tailscale network |
| Cloudflare Tunnel | HTTPS webhook endpoint without exposed ports or a domain |
| iptables | Blocks direct IP access to port 80 at RAW table + DOCKER-USER chain (handles Docker bypass of UFW) |
| Fail2ban | Bans IPs after 3 failed SSH attempts for 1 hour |
| SSH key-only | Password auth disabled |

---

## Docker Compose

```yaml
version: '3.8'

services:
  n8n:
    image: docker.n8n.io/n8nio/n8n
    container_name: n8n
    restart: unless-stopped
    ports:
      - "0.0.0.0:80:5678"
    environment:
      - N8N_SECURE_COOKIE=false
      - N8N_HOST=<YOUR_TAILSCALE_IP>
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - GENERIC_TIMEZONE=Europe/Copenhagen
      - WEBHOOK_URL=<YOUR_CLOUDFLARE_TUNNEL_URL>
      - N8N_DEFAULT_BINARY_DATA_MODE=filesystem
      - N8N_BLOCK_FILE_ACCESS_TO_N8N_FILES=false
    volumes:
      - n8n_data:/home/node/.n8n
      - ./backups:/backups

volumes:
  n8n_data:
```

---

## Automatic Updates

Two scripts run every Sunday via cron – system update at 02:00, n8n update at 03:00.

```
0 2 * * 0 /root/system-auto-update.sh
0 3 * * 0 /root/n8n-auto-update.sh
```

### `/root/system-auto-update.sh`

```bash
#!/bin/bash

LOG_FILE="/var/log/system-auto-update.log"

echo "=== System Update Started: $(date) ===" >> $LOG_FILE
apt update >> $LOG_FILE 2>&1
apt upgrade -y >> $LOG_FILE 2>&1

if [ -f /var/run/reboot-required ]; then
    echo "Reboot required – rebooting in 1 minute" >> $LOG_FILE
    echo "=== System Update Finished: $(date) ===" >> $LOG_FILE
    echo "" >> $LOG_FILE
    shutdown -r +1
else
    echo "No reboot required" >> $LOG_FILE
    echo "=== System Update Finished: $(date) ===" >> $LOG_FILE
    echo "" >> $LOG_FILE
fi
```

### `/root/n8n-auto-update.sh`

```bash
#!/bin/bash

LOG_FILE="/var/log/n8n-auto-update.log"

echo "=== n8n Auto Update Started: $(date) ===" >> $LOG_FILE

cd /root/n8n || exit 1

OLD_VERSION=$(docker exec n8n n8n --version 2>/dev/null || echo "unknown")
echo "Current version: $OLD_VERSION" >> $LOG_FILE

docker pull docker.n8n.io/n8nio/n8n >> $LOG_FILE 2>&1
docker-compose pull >> $LOG_FILE 2>&1
docker-compose down >> $LOG_FILE 2>&1
docker-compose up -d >> $LOG_FILE 2>&1

sleep 10

NEW_VERSION=$(docker exec n8n n8n --version 2>/dev/null || echo "unknown")
echo "New version: $NEW_VERSION" >> $LOG_FILE

if docker ps | grep -q n8n; then
    echo "n8n is running" >> $LOG_FILE
else
    echo "n8n failed to start!" >> $LOG_FILE
fi

echo "=== n8n Auto Update Finished: $(date) ===" >> $LOG_FILE
echo "" >> $LOG_FILE
```

---

## Log Rotation

Logs are rotated monthly, kept for 6 months. Config: `/etc/logrotate.d/n8n-server`

```
/var/log/n8n-auto-update.log /var/log/system-auto-update.log {
    su root root
    monthly
    rotate 6
    compress
    missingok
    notifempty
}
```

---

## Key Files

| File | Purpose |
|---|---|
| `/root/n8n/docker-compose.yml` | n8n container config |
| `/etc/systemd/system/cloudflared-quick.service` | Cloudflare Tunnel service |
| `/etc/fail2ban/jail.local` | Fail2ban SSH config |
| `/etc/ssh/sshd_config.d/50-cloud-init.conf` | SSH hardening |
| `/etc/iptables/rules.v4` | Persisted firewall rules |
| `/root/system-auto-update.sh` | System update script |
| `/root/n8n-auto-update.sh` | n8n update script |
| `/var/log/system-auto-update.log` | System update log |
| `/var/log/n8n-auto-update.log` | n8n update log |
| `/var/log/fail2ban.log` | Fail2ban activity log |
