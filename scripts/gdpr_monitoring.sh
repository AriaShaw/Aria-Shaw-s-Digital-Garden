#!/bin/bash
# GDPR Compliance Monitoring During Migration

LOG_FILE="/var/log/gdpr_compliance.log"

# Monitor database access
echo "$(date): Checking database access logs" >> $LOG_FILE
sudo tail -n 100 /var/log/postgresql/postgresql-14-main.log | \
  grep -E "(CONNECT|DISCONNECT|ERROR|FATAL)" >> $LOG_FILE

# Monitor file access to personal data
echo "$(date): Checking file access to personal data" >> $LOG_FILE  
sudo ausearch -f /opt/odoo/filestore/ -ts recent | \
  grep -v "success=yes" >> $LOG_FILE

# Check for unauthorized data export attempts
echo "$(date): Checking for data export attempts" >> $LOG_FILE
sudo netstat -an | grep :5432 | grep ESTABLISHED | \
  awk '{print $5}' | cut -d: -f1 | sort | uniq -c | \
  awk '$1 > 10 {print "WARNING: High connection count from " $2}' >> $LOG_FILE

# Alert on suspicious activity
if grep -q "WARNING\|ERROR\|FATAL" $LOG_FILE; then
    echo "GDPR Alert: Suspicious activity detected during migration" | \
    mail -s "GDPR Compliance Alert" compliance@yourcompany.com
fi