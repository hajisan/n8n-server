#!/bin/bash

LOG_FILE="/var/log/system-auto-update.log"

echo "=== System Update Started: $(date) ===" >> $LOG_FILE

apt update >> $LOG_FILE 2>&1
apt upgrade -y >> $LOG_FILE 2>&1

# Tjek om genstart er påkrævet
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
