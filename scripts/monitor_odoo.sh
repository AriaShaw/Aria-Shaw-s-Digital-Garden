#!/bin/bash
DOMAIN="https://yourdomain.com"
EMAIL="admin@yourcompany.com"

# Check if Odoo is responding
if ! curl -f -s $DOMAIN/web/login > /dev/null; then
    echo "ALERT: Odoo is down!" | mail -s "Odoo Down Alert" $EMAIL
    echo "$(date): Odoo down" >> /var/log/odoo-monitor.log
fi

# Check disk space
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 85 ]; then
    echo "ALERT: Disk usage is ${DISK_USAGE}%" | mail -s "Disk Space Alert" $EMAIL
fi