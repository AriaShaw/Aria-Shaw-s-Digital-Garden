#!/bin/bash

# Odoo Separated Architecture Backup Strategy
# Created by Aria Shaw
# Version 1.0 - 2025

# Configuration - Modify these variables for your setup
DB_HOST="10.0.1.10"
DB_NAME="odoo_production"
DB_USER="odoo_user"
APP_SERVER="10.0.1.20"
BACKUP_DIR="/backup/odoo"
RETENTION_DAYS=30
EMAIL_ALERTS="admin@yourcompany.com"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Timestamp for backup files
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${BACKUP_DIR}/backup.log"
}

send_alert() {
    if command -v mail &> /dev/null; then
        echo "$2" | mail -s "$1" "$EMAIL_ALERTS"
    fi
    log_message "ALERT: $1 - $2"
}

check_prerequisites() {
    log_message "Checking backup prerequisites..."

    # Check if backup directory exists
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        log_message "Created backup directory: $BACKUP_DIR"
    fi

    # Check database connectivity
    if ! PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c '\q' 2>/dev/null; then
        send_alert "Database Connection Failed" "Cannot connect to PostgreSQL database"
        exit 1
    fi

    # Check available disk space (require at least 5GB free)
    AVAILABLE_SPACE=$(df "$BACKUP_DIR" | awk 'NR==2 {print $4}')
    if [ "$AVAILABLE_SPACE" -lt 5242880 ]; then  # 5GB in KB
        send_alert "Low Disk Space" "Less than 5GB available for backups"
        exit 1
    fi

    log_message "Prerequisites check passed"
}

backup_database() {
    log_message "Starting database backup..."

    DB_BACKUP_FILE="${BACKUP_DIR}/db_${DB_NAME}_${TIMESTAMP}.sql"

    # Perform database backup with compression
    if PGPASSWORD="$DB_PASSWORD" pg_dump -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" \
        --verbose --no-owner --no-privileges | gzip > "${DB_BACKUP_FILE}.gz"; then

        log_message "Database backup completed: ${DB_BACKUP_FILE}.gz"

        # Verify backup integrity
        if gunzip -t "${DB_BACKUP_FILE}.gz"; then
            log_message "Database backup integrity verified"
        else
            send_alert "Backup Integrity Check Failed" "Database backup file appears corrupted"
            return 1
        fi
    else
        send_alert "Database Backup Failed" "pg_dump command failed"
        return 1
    fi
}

backup_filestore() {
    log_message "Starting filestore backup..."

    FILESTORE_BACKUP_FILE="${BACKUP_DIR}/filestore_${TIMESTAMP}.tar.gz"

    # Backup Odoo filestore from application server
    if ssh "odoo@${APP_SERVER}" "tar -czf - /opt/odoo/.local/share/Odoo/filestore/${DB_NAME}" \
        > "$FILESTORE_BACKUP_FILE" 2>/dev/null; then

        log_message "Filestore backup completed: $FILESTORE_BACKUP_FILE"
    else
        log_message "Warning: Filestore backup failed or no filestore found"
        # Don't fail the entire backup for filestore issues
    fi
}

backup_configuration() {
    log_message "Starting configuration backup..."

    CONFIG_BACKUP_FILE="${BACKUP_DIR}/config_${TIMESTAMP}.tar.gz"

    # Backup configuration files from application server
    if ssh "root@${APP_SERVER}" "tar -czf - /etc/odoo/ /etc/nginx/sites-available/odoo* /etc/systemd/system/odoo*" \
        > "$CONFIG_BACKUP_FILE" 2>/dev/null; then

        log_message "Configuration backup completed: $CONFIG_BACKUP_FILE"
    else
        log_message "Warning: Configuration backup failed"
    fi
}

cleanup_old_backups() {
    log_message "Cleaning up backups older than $RETENTION_DAYS days..."

    find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete
    find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete

    CLEANED_COUNT=$(find "$BACKUP_DIR" -name "*_${TIMESTAMP%_*}*" -mtime +$RETENTION_DAYS | wc -l)

    if [ "$CLEANED_COUNT" -gt 0 ]; then
        log_message "Cleaned up $CLEANED_COUNT old backup files"
    fi
}

generate_backup_report() {
    log_message "Generating backup report..."

    REPORT_FILE="${BACKUP_DIR}/backup_report_${TIMESTAMP}.txt"

    cat > "$REPORT_FILE" << EOF
Odoo Backup Report - $(date)
=====================================

Backup Configuration:
- Database: ${DB_NAME}@${DB_HOST}
- Application Server: ${APP_SERVER}
- Backup Directory: ${BACKUP_DIR}
- Retention Period: ${RETENTION_DAYS} days

Files Created:
$(ls -lh "${BACKUP_DIR}"/*"${TIMESTAMP}"* 2>/dev/null || echo "No files created")

Disk Usage:
$(df -h "$BACKUP_DIR")

Recent Backup History:
$(ls -lt "${BACKUP_DIR}"/*.sql.gz 2>/dev/null | head -5 || echo "No previous backups found")

EOF

    log_message "Backup report generated: $REPORT_FILE"
}

main() {
    log_message "=== Starting Odoo Separated Architecture Backup ==="

    # Load database password from environment or prompt
    if [ -z "$DB_PASSWORD" ]; then
        echo -n "Enter database password: "
        read -s DB_PASSWORD
        echo
        export DB_PASSWORD
    fi

    check_prerequisites

    # Perform backups
    if backup_database; then
        backup_filestore
        backup_configuration
        cleanup_old_backups
        generate_backup_report

        log_message "=== Backup completed successfully ==="

        # Send success notification
        if command -v mail &> /dev/null; then
            echo "Backup completed successfully at $(date)" | \
                mail -s "Odoo Backup Success - ${HOSTNAME}" "$EMAIL_ALERTS"
        fi
    else
        log_message "=== Backup failed ==="
        exit 1
    fi
}

# Run main function
main "$@"