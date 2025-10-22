#!/bin/bash

LOG_FILE="/var/log/odoo/monitor.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Check if Odoo is running
if systemctl is-active --quiet odoo; then
    ODOO_STATUS="UP"
else
    ODOO_STATUS="DOWN"
    echo "$DATE - ALERT: Odoo is DOWN!" >> $LOG_FILE
fi

# Check disk usage
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 80 ]; then
    echo "$DATE - WARNING: Disk usage is ${DISK_USAGE}%" >> $LOG_FILE
fi

# Check memory usage
MEMORY_USAGE=$(free | grep Mem | awk '{printf("%.0f", $3/$2 * 100.0)}')
if [ $MEMORY_USAGE -gt 90 ]; then
    echo "$DATE - WARNING: Memory usage is ${MEMORY_USAGE}%" >> $LOG_FILE
fi

# Check database connections
DB_CONNECTIONS=$(sudo -u postgres psql -t -c "SELECT count(*) FROM pg_stat_activity WHERE datname='production';" | tr -d ' ')
if [ $DB_CONNECTIONS -gt 50 ]; then
    echo "$DATE - WARNING: High database connections: $DB_CONNECTIONS" >> $LOG_FILE
fi

# Log status
echo "$DATE - Status: Odoo=$ODOO_STATUS, Disk=${DISK_USAGE}%, Memory=${MEMORY_USAGE}%, DB_Conn=$DB_CONNECTIONS" >> $LOG_FILE