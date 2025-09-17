#!/bin/bash
# Wget-based Odoo Database Backup Script
# Alternative to cURL for systems where wget is preferred
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
    print_error "Edit this script and update the configuration section at the top"
    exit 1
fi

print_status "Starting wget-based Odoo backup for database: $DB_NAME"

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

if [ ! -d "$BACKUP_DIR" ]; then
    print_error "Failed to create backup directory: $BACKUP_DIR"
    exit 1
fi

# Check available disk space
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

print_status "Creating backup: $(basename "$BACKUP_FILE")"
print_status "Using wget with POST data method..."

# Perform backup using wget
wget \
  --post-data="master_pwd=${MASTER_PWD}&name=${DB_NAME}&backup_format=zip" \
  --progress=bar:force \
  --timeout=3600 \
  --tries=3 \
  --output-document="$BACKUP_FILE" \
  "${ODOO_URL}/web/database/backup"

# Check wget exit status
wget_status=$?

if [ $wget_status -eq 0 ]; then
    print_status "✅ wget completed successfully"
else
    print_error "❌ wget failed with exit code: $wget_status"
    case $wget_status in
        1) print_error "Generic error code" ;;
        2) print_error "Parse error (command line options)" ;;
        3) print_error "File I/O error" ;;
        4) print_error "Network failure" ;;
        5) print_error "SSL verification failure" ;;
        6) print_error "Username/password authentication failure" ;;
        7) print_error "Protocol errors" ;;
        8) print_error "Server issued an error response" ;;
        *) print_error "Unknown error" ;;
    esac
fi

# Verify backup file exists and is not empty
if [ -f "$BACKUP_FILE" ] && [ -s "$BACKUP_FILE" ]; then
    FILE_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    FILE_SIZE_BYTES=$(stat -f%z "$BACKUP_FILE" 2>/dev/null || stat -c%s "$BACKUP_FILE" 2>/dev/null)

    print_status "✅ Backup file created successfully"
    print_status "File: $(basename "$BACKUP_FILE")"
    print_status "Size: $FILE_SIZE"

    # Basic validation
    if [ "$FILE_SIZE_BYTES" -lt 1024 ]; then
        print_warning "⚠️  Backup file seems too small (< 1KB). This might indicate an error."
        print_warning "Check if the master password and database name are correct."
    fi

    # Test ZIP integrity if unzip is available
    if command -v unzip >/dev/null 2>&1; then
        print_status "Testing ZIP integrity..."
        if unzip -t "$BACKUP_FILE" >/dev/null 2>&1; then
            print_status "✅ ZIP integrity check passed"
        else
            print_error "❌ ZIP integrity check failed - backup may be corrupted"
            exit 1
        fi
    fi

    # Show backup contents if possible
    if command -v unzip >/dev/null 2>&1; then
        print_status "Backup contents:"
        unzip -l "$BACKUP_FILE" 2>/dev/null | head -10 | tail -n +4
    fi

    print_status "🎉 Backup completed successfully!"

    # Cleanup old backups (keep last 7 days)
    print_status "Cleaning up old backups..."
    find "$BACKUP_DIR" -name "${DB_NAME}_*.zip" -mtime +7 -delete 2>/dev/null

else
    print_error "❌ Backup failed or file is empty"
    print_error "Please check:"
    print_error "1. Odoo server is accessible at $ODOO_URL"
    print_error "2. Master password is correct"
    print_error "3. Database '$DB_NAME' exists"
    print_error "4. Network connectivity is working"
    print_error "5. Sufficient disk space is available"

    # Clean up empty/failed backup file
    [ -f "$BACKUP_FILE" ] && rm -f "$BACKUP_FILE"
    exit 1
fi