#!/bin/bash
# Basic Odoo Database Backup Script using cURL
# Part of "The Definitive Guide to Odoo Database Backup and Restore"
# Created by Aria Shaw - 2025

# Configuration variables
ODOO_URL="http://localhost:8069"
MASTER_PWD="your_master_password"
DB_NAME="your_database_name"
BACKUP_DIR="/backup/odoo"
DATE=$(date +%Y%m%d_%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if configuration is set
if [ "$MASTER_PWD" = "your_master_password" ] || [ "$DB_NAME" = "your_database_name" ]; then
    print_error "Please configure the script by setting MASTER_PWD and DB_NAME variables"
    exit 1
fi

print_status "Starting Odoo backup for database: $DB_NAME"
print_status "Backup URL: $ODOO_URL"

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR
if [ ! -d "$BACKUP_DIR" ]; then
    print_error "Failed to create backup directory: $BACKUP_DIR"
    exit 1
fi

# Check available disk space (require at least 1GB free)
AVAILABLE_SPACE=$(df "$BACKUP_DIR" | awk 'NR==2{print $4}')
if [ "$AVAILABLE_SPACE" -lt 1048576 ]; then  # 1GB in KB
    print_warning "Low disk space available: $(($AVAILABLE_SPACE/1024))MB"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${DATE}.zip"

print_status "Creating backup file: $BACKUP_FILE"

# Perform the backup with progress
curl -X POST \
  -F "master_pwd=${MASTER_PWD}" \
  -F "name=${DB_NAME}" \
  -F "backup_format=zip" \
  -o "$BACKUP_FILE" \
  --progress-bar \
  "${ODOO_URL}/web/database/backup"

# Check if backup was successful
if [ $? -eq 0 ] && [ -f "$BACKUP_FILE" ]; then
    FILE_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    FILE_SIZE_BYTES=$(stat -f%z "$BACKUP_FILE" 2>/dev/null || stat -c%s "$BACKUP_FILE" 2>/dev/null)

    print_status "Backup successful: $(basename "$BACKUP_FILE")"
    print_status "File size: $FILE_SIZE"

    # Basic validation
    if [ "$FILE_SIZE_BYTES" -lt 1024 ]; then
        print_warning "Backup file seems too small (< 1KB). Please verify manually."
    fi

    # Test ZIP integrity
    if command -v unzip >/dev/null 2>&1; then
        print_status "Testing ZIP integrity..."
        if unzip -t "$BACKUP_FILE" >/dev/null 2>&1; then
            print_status "✅ ZIP integrity check passed"
        else
            print_error "❌ ZIP integrity check failed"
            exit 1
        fi
    fi

    print_status "✅ Backup completed successfully!"

    # Optional cleanup of old backups (keep last 7 days by default)
    RETENTION_DAYS=7
    print_status "Cleaning up backups older than $RETENTION_DAYS days..."
    find "$BACKUP_DIR" -name "${DB_NAME}_*.zip" -mtime +$RETENTION_DAYS -delete 2>/dev/null

else
    print_error "Backup failed for database: $DB_NAME"
    print_error "Please check:"
    print_error "1. Odoo server is accessible at $ODOO_URL"
    print_error "2. Master password is correct"
    print_error "3. Database name '$DB_NAME' exists"
    print_error "4. Sufficient disk space is available"

    # Clean up failed backup file
    [ -f "$BACKUP_FILE" ] && rm -f "$BACKUP_FILE"
    exit 1
fi