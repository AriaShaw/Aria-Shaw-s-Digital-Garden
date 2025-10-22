#!/bin/bash
# Weekly Odoo System Maintenance Script
# Run every Sunday at 2 AM via cron: 0 2 * * 0 /path/to/weekly_maintenance.sh

set -e

# Configuration
LOG_FILE="/var/log/odoo_maintenance.log"
BACKUP_DIR="/secure/backup"
RETENTION_DAYS=14
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

log "Starting weekly maintenance routine"

# 1. Database Maintenance
log "Running database maintenance..."
sudo -u postgres psql -d odoo_production_new -c "VACUUM ANALYZE;"

# Check for bloated indexes and reindex if needed
BLOATED_INDEXES=$(sudo -u postgres psql -d odoo_production_new -t -c "
SELECT schemaname||'.'||tablename as table, 
       indexname,
       pg_size_pretty(pg_relation_size(indexname::regclass)) as size
FROM pg_stat_user_indexes 
WHERE idx_scan < 10 AND pg_relation_size(indexname::regclass) > 10485760
ORDER BY pg_relation_size(indexname::regclass) DESC;
" | grep -v "^$" | wc -l)

if [[ $BLOATED_INDEXES -gt 0 ]]; then
    log "Found $BLOATED_INDEXES potentially bloated indexes, reindexing..."
    sudo -u postgres psql -d odoo_production_new -c "REINDEX DATABASE odoo_production_new;"
fi

# 2. Log Rotation and Cleanup
log "Rotating and cleaning up logs..."
find /var/log/odoo/ -name "*.log" -type f -mtime +$RETENTION_DAYS -delete
find /var/log/postgresql/ -name "*.log" -type f -mtime +$RETENTION_DAYS -delete

# Compress recent logs
find /var/log/odoo/ -name "*.log" -type f -mtime +2 -exec gzip {} \;

# 3. Backup Verification
log "Verifying recent backups..."
LATEST_BACKUP=$(find $BACKUP_DIR -name "odoo_backup_*.backup" -type f -mtime -7 | sort | tail -1)

if [[ -n "$LATEST_BACKUP" ]]; then
    # Test backup integrity
    if sudo -u postgres pg_restore --list "$LATEST_BACKUP" > /dev/null 2>&1; then
        log "✅ Backup verification successful: $(basename $LATEST_BACKUP)"
    else
        log "❌ Backup verification failed: $(basename $LATEST_BACKUP)"
    fi
else
    log "⚠️ No recent backups found in the last 7 days"
fi

# 4. System Updates (Security only)
log "Checking for security updates..."
SECURITY_UPDATES=$(apt list --upgradable 2>/dev/null | grep -i security | wc -l)

if [[ $SECURITY_UPDATES -gt 0 ]]; then
    log "Installing $SECURITY_UPDATES security updates..."
    apt-get update > /dev/null 2>&1
    apt-get -y upgrade -o "Dpkg::Options::=--force-confold" \
        $(apt list --upgradable 2>/dev/null | grep -i security | cut -d'/' -f1)
    
    # Check if restart is required
    if [[ -f /var/run/reboot-required ]]; then
        log "⚠️ System restart required after security updates"
        # Schedule restart for 3 AM (1 hour from now)
        echo "systemctl reboot" | at 03:00
    fi
fi

# 5. Performance Monitoring
log "Generating weekly performance report..."
REPORT_FILE="/tmp/weekly_performance_${TIMESTAMP}.txt"

cat > "$REPORT_FILE" << EOF
Weekly Performance Report - $(date)
=====================================

Database Size:
$(sudo -u postgres psql -d odoo_production_new -c "SELECT pg_size_pretty(pg_database_size('odoo_production_new'));" -t | xargs)

Active Connections:
$(sudo -u postgres psql -c "SELECT count(*) FROM pg_stat_activity WHERE datname='odoo_production_new';" -t | xargs)

Cache Hit Ratio:
$(sudo -u postgres psql -d odoo_production_new -c "SELECT round(100.0 * sum(blks_hit) / (sum(blks_hit) + sum(blks_read)), 2) as cache_hit_ratio FROM pg_stat_database WHERE datname='odoo_production_new';" -t | xargs)%

Slow Queries (>1s in the last week):
$(tail -10000 /var/log/postgresql/postgresql-*.log | grep "duration:" | awk '$5 > 1000.0' | wc -l)

System Resources:
CPU Load: $(uptime | awk '{print $NF}')
Memory Usage: $(free | grep '^Mem:' | awk '{printf "%.1f%%", $3/$2*100}')
Disk Usage: $(df /opt | awk 'NR==2{print $5}')
EOF

log "Performance report saved to: $REPORT_FILE"

# 6. Storage Cleanup
log "Cleaning up temporary files..."
find /tmp -name "odoo_*" -type f -mtime +7 -delete
find /var/tmp -name "odoo_*" -type f -mtime +7 -delete

# Clean old backup files
find $BACKUP_DIR -name "*backup*" -type f -mtime +30 -delete

# 7. Service Health Check
log "Checking service health..."
SERVICES=("odoo" "postgresql" "nginx")

for service in "${SERVICES[@]}"; do
    if systemctl is-active --quiet $service; then
        log "✅ $service is running"
    else
        log "❌ $service is not running - attempting restart"
        systemctl restart $service
        sleep 5
        if systemctl is-active --quiet $service; then
            log "✅ $service restarted successfully"
        else
            log "❌ Failed to restart $service - manual intervention required"
        fi
    fi
done

# 8. Generate Summary
MAINTENANCE_END=$(date +%s)
log "Weekly maintenance completed successfully"
log "Summary report available at: $REPORT_FILE"
log "Next maintenance scheduled for: $(date -d '+7 days' '+%Y-%m-%d %H:%M:%S')"