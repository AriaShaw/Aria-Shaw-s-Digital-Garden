#!/bin/bash
# Professional cloud backup sync script for Odoo database migrations
# Compatible with Backblaze B2, AWS S3, and other rclone-supported providers

# Configuration
LOCAL_BACKUP_DIR="/secure/backup"
REMOTE_NAME="b2-backup"  # Name from rclone config
BUCKET_NAME="company-odoo-backups"
LOG_FILE="/var/log/cloud_backup.log"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to log with timestamp
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Check if rclone is installed
if ! command -v rclone &> /dev/null; then
    echo -e "${RED}✗ rclone is not installed. Please install from https://rclone.org/downloads/${NC}"
    exit 1
fi

# Check if local backup directory exists
if [ ! -d "$LOCAL_BACKUP_DIR" ]; then
    echo -e "${RED}✗ Local backup directory $LOCAL_BACKUP_DIR does not exist${NC}"
    exit 1
fi

# Check if rclone remote is configured
if ! rclone listremotes | grep -q "^${REMOTE_NAME}:$"; then
    echo -e "${RED}✗ Remote '$REMOTE_NAME' not configured. Run 'rclone config' first${NC}"
    exit 1
fi

log_message "Starting cloud backup sync..."
echo -e "${YELLOW}Syncing backups to cloud storage...${NC}"

# Create version directory name
VERSION_DIR="versions/$(date +%Y%m%d_%H%M%S)"

# Sync with versioning
rclone sync "$LOCAL_BACKUP_DIR" "$REMOTE_NAME:$BUCKET_NAME" \
  --backup-dir "$REMOTE_NAME:$BUCKET_NAME/$VERSION_DIR" \
  --transfers 4 \
  --checkers 8 \
  --progress \
  --log-file "$LOG_FILE" \
  --log-level INFO

# Check exit status
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Cloud backup completed successfully${NC}"
    log_message "Cloud backup completed successfully"
    echo "Backup location: $REMOTE_NAME:$BUCKET_NAME"
    echo "Version backup: $REMOTE_NAME:$BUCKET_NAME/$VERSION_DIR"

    # Show backup size
    BACKUP_SIZE=$(rclone size "$REMOTE_NAME:$BUCKET_NAME" 2>/dev/null | grep "Total size" | awk '{print $3 " " $4}')
    if [ ! -z "$BACKUP_SIZE" ]; then
        echo "Total backup size: $BACKUP_SIZE"
    fi
else
    echo -e "${RED}✗ Cloud backup failed - check logs at $LOG_FILE${NC}"
    log_message "Cloud backup failed"
    exit 1
fi