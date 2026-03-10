#!/bin/bash

# Log fil
LOG_FILE="/var/log/n8n-auto-update.log"

echo "=== n8n Auto Update Started: $(date) ===" >> $LOG_FILE

# Gå til n8n mappe
cd /root/n8n || exit 1

# Tjek nuværende version
OLD_VERSION=$(docker exec n8n n8n --version 2>/dev/null || echo "unknown")
echo "Current version: $OLD_VERSION" >> $LOG_FILE

# Pull ny image
docker pull docker.n8n.io/n8nio/n8n >> $LOG_FILE 2>&1

# Opdater med docker-compose
docker-compose pull >> $LOG_FILE 2>&1
docker-compose down >> $LOG_FILE 2>&1
docker-compose up -d >> $LOG_FILE 2>&1

# Vent på n8n starter
sleep 10

# Tjek ny version
NEW_VERSION=$(docker exec n8n n8n --version 2>/dev/null || echo "unknown")
echo "New version: $NEW_VERSION" >> $LOG_FILE

# Tjek at n8n kører
if docker ps | grep -q n8n; then
    echo "✅ n8n is running" >> $LOG_FILE
else
    echo "❌ n8n failed to start!" >> $LOG_FILE
fi

echo "=== n8n Auto Update Finished: $(date) ===" >> $LOG_FILE
echo "" >> $LOG_FILE
