#!/bin/bash
# Professional-grade backup with automatic cloud sync
# Usage: ./professional-backup-with-cloud-sync.sh --database production_db --s3-bucket your-company-odoo-backups

set -euo pipefail

# Configuration
DATE=$(date +%Y%m%d_%H%M%S)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/odoo-backup-${DATE}.log"

# Default values
DATABASE=""
S3_BUCKET=""
BACKUP_DIR="/backup"
RETENTION_DAYS=30

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to show usage
usage() {
    cat << EOF
Usage: $0 --database DATABASE_NAME --s3-bucket S3_BUCKET_NAME [OPTIONS]

Required:
  --database         Name of the PostgreSQL database to backup
  --s3-bucket       S3 bucket name for cloud storage

Optional:
  --backup-dir      Local backup directory (default: /backup)
  --retention-days  Days to retain backups (default: 30)
  --help           Show this help message

Examples:
  $0 --database production_db --s3-bucket company-odoo-backups
  $0 --database production_db --s3-bucket company-odoo-backups --backup-dir /opt/backups

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --database)
            DATABASE="$2"
            shift 2
            ;;
        --s3-bucket)
            S3_BUCKET="$2"
            shift 2
            ;;
        --backup-dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        --retention-days)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$DATABASE" || -z "$S3_BUCKET" ]]; then
    echo "Error: --database and --s3-bucket are required"
    usage
    exit 1
fi

# Check if AWS CLI is installed and configured
if ! command -v aws &> /dev/null; then
    log "ERROR: AWS CLI is not installed"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    log "ERROR: AWS credentials not configured"
    exit 1
fi

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

log "Starting backup process for database: $DATABASE"

# Create local backup
BACKUP_FILE="$BACKUP_DIR/${DATABASE}_${DATE}.sql"
log "Creating local backup: $BACKUP_FILE"

if sudo -u postgres pg_dump -F c -b -v "$DATABASE" > "$BACKUP_FILE"; then
    log "Local backup created successfully"
else
    log "ERROR: Failed to create local backup"
    exit 1
fi

# Compress backup
log "Compressing backup file"
if gzip "$BACKUP_FILE"; then
    BACKUP_FILE="${BACKUP_FILE}.gz"
    log "Backup compressed successfully"
else
    log "ERROR: Failed to compress backup"
    exit 1
fi

# Calculate checksum
CHECKSUM=$(sha256sum "$BACKUP_FILE" | cut -d' ' -f1)
echo "$CHECKSUM" > "${BACKUP_FILE}.sha256"
log "Checksum calculated: $CHECKSUM"

# Sync to S3 with intelligent tiering
log "Syncing backup to S3 bucket: $S3_BUCKET"
if aws s3 cp "$BACKUP_FILE" "s3://$S3_BUCKET/daily/" \
    --storage-class INTELLIGENT_TIERING \
    --metadata "checksum=$CHECKSUM,database=$DATABASE,backup-date=$DATE"; then
    log "Backup synced to S3 successfully"
else
    log "ERROR: Failed to sync backup to S3"
    exit 1
fi

# Upload checksum file
aws s3 cp "${BACKUP_FILE}.sha256" "s3://$S3_BUCKET/daily/" \
    --storage-class INTELLIGENT_TIERING

# Enable versioning on S3 bucket (if not already enabled)
log "Ensuring S3 bucket versioning is enabled"
aws s3api put-bucket-versioning \
    --bucket "$S3_BUCKET" \
    --versioning-configuration Status=Enabled

# Clean up old local backups
log "Cleaning up local backups older than $RETENTION_DAYS days"
find "$BACKUP_DIR" -name "${DATABASE}_*.sql.gz" -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR" -name "${DATABASE}_*.sql.gz.sha256" -mtime +$RETENTION_DAYS -delete

# Verify backup integrity by attempting a test restore (optional)
if [[ "${VERIFY_RESTORE:-false}" == "true" ]]; then
    log "Performing test restore verification"
    TEST_DB="${DATABASE}_test_restore_${DATE}"

    if gunzip -c "$BACKUP_FILE" | sudo -u postgres pg_restore -C -d postgres; then
        log "Test restore successful"
        # Clean up test database
        sudo -u postgres dropdb "$TEST_DB" 2>/dev/null || true
    else
        log "WARNING: Test restore failed"
    fi
fi

# Send notification (if configured)
if [[ -n "${NOTIFICATION_EMAIL:-}" ]]; then
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo "Backup completed successfully for database: $DATABASE
    Backup size: $BACKUP_SIZE
    Backup file: $BACKUP_FILE
    S3 location: s3://$S3_BUCKET/daily/
    Checksum: $CHECKSUM
    Date: $DATE" | mail -s "Odoo Backup Completed: $DATABASE" "$NOTIFICATION_EMAIL"
fi

log "Backup process completed successfully"
log "Backup file: $BACKUP_FILE"
log "S3 location: s3://$S3_BUCKET/daily/"
log "Checksum: $CHECKSUM"

exit 0