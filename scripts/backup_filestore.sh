#!/bin/bash
# Odoo Filestore Backup Script
# Usage: ./backup_filestore.sh <database_name> [backup_location]

set -e

# Configuration
DB_NAME="${1:-odoo_production}"
BACKUP_DIR="${2:-/secure/backup}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
FILESTORE_BACKUP="$BACKUP_DIR/filestore_${DB_NAME}_${TIMESTAMP}.tar.gz"
LOG_FILE="$BACKUP_DIR/filestore_backup_${TIMESTAMP}.log"

# Common filestore locations (in order of likelihood)
FILESTORE_LOCATIONS=(
    "/opt/odoo/.local/share/Odoo/filestore/$DB_NAME"
    "/var/lib/odoo/.local/share/Odoo/filestore/$DB_NAME"
    "$HOME/.local/share/Odoo/filestore/$DB_NAME"
    "/home/odoo/.local/share/Odoo/filestore/$DB_NAME"
)

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "📁 Starting Filestore Backup"
echo "============================="
echo "Database: $DB_NAME"
echo "Target: $FILESTORE_BACKUP"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"

log_message() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

# Find the actual filestore location
FILESTORE_PATH=""
for location in "${FILESTORE_LOCATIONS[@]}"; do
    if [ -d "$location" ]; then
        FILESTORE_PATH="$location"
        log_message "${GREEN}✅ Found filestore at: $FILESTORE_PATH${NC}"
        break
    fi
done

if [ -z "$FILESTORE_PATH" ]; then
    log_message "${RED}❌ ERROR: Could not locate filestore directory${NC}"
    log_message "Searched locations:"
    for location in "${FILESTORE_LOCATIONS[@]}"; do
        log_message "   - $location"
    done
    log_message ""
    log_message "💡 Manual check required:"
    log_message "   1. Find your odoo.conf file"
    log_message "   2. Look for 'data_dir' parameter"  
    log_message "   3. Filestore should be at: <data_dir>/filestore/$DB_NAME"
    exit 1
fi

# Analyze filestore contents
log_message "🔍 Analyzing filestore contents..."
FILE_COUNT=$(find "$FILESTORE_PATH" -type f | wc -l)
TOTAL_SIZE=$(du -sh "$FILESTORE_PATH" | cut -f1)
LARGEST_FILES=$(find "$FILESTORE_PATH" -type f -exec ls -lh {} + | sort -k5 -hr | head -5)

log_message "📊 Filestore Analysis:"
log_message "   Location: $FILESTORE_PATH"
log_message "   Files: $FILE_COUNT"
log_message "   Total Size: $TOTAL_SIZE"
log_message ""

if [ "$FILE_COUNT" -eq 0 ]; then
    log_message "${YELLOW}⚠️  WARNING: No files found in filestore${NC}"
    log_message "This might be normal for a new installation"
fi

# Check available space
FILESTORE_SIZE_KB=$(du -sk "$FILESTORE_PATH" | cut -f1)
AVAILABLE_SPACE_KB=$(df "$BACKUP_DIR" | awk 'NR==2 {print $4}')

if [ "$AVAILABLE_SPACE_KB" -lt $((FILESTORE_SIZE_KB * 2)) ]; then
    log_message "${RED}❌ WARNING: Insufficient disk space for compressed backup${NC}"
    log_message "Required: ~$((FILESTORE_SIZE_KB * 2 / 1024))MB, Available: $((AVAILABLE_SPACE_KB / 1024))MB"
fi

# Create backup with verification
log_message "🗜️  Creating compressed filestore backup..."
log_message "⏰ This may take several minutes for large filestores..."

# Use tar with optimal compression and verification
if tar -czf "$FILESTORE_BACKUP" \
    -C "$(dirname "$FILESTORE_PATH")" \
    "$(basename "$FILESTORE_PATH")" \
    --totals \
    2>> "$LOG_FILE"; then
    
    log_message "${GREEN}✅ Filestore backup created successfully${NC}"
else
    log_message "${RED}❌ ERROR: Filestore backup failed${NC}"
    exit 1
fi

# Verify backup integrity
log_message "🔍 Verifying backup integrity..."
if tar -tzf "$FILESTORE_BACKUP" > /dev/null 2>> "$LOG_FILE"; then
    log_message "${GREEN}✅ Backup integrity verified${NC}"
else
    log_message "${RED}❌ ERROR: Backup integrity check failed${NC}"
    exit 1
fi

# Generate checksums for verification
log_message "🔐 Generating checksums..."
BACKUP_SIZE=$(du -sh "$FILESTORE_BACKUP" | cut -f1)
BACKUP_MD5=$(md5sum "$FILESTORE_BACKUP" | cut -d' ' -f1)

# Create detailed backup manifest
MANIFEST_FILE="$BACKUP_DIR/filestore_manifest_${TIMESTAMP}.txt"
log_message "📋 Creating backup manifest..."

cat > "$MANIFEST_FILE" << EOF
Filestore Backup Manifest
========================
Database: $DB_NAME
Created: $(date -Iseconds)
Source: $FILESTORE_PATH
Backup: $FILESTORE_BACKUP
Size: $BACKUP_SIZE
MD5: $BACKUP_MD5
Files: $FILE_COUNT

Top 10 Largest Files:
EOF

# Add largest files to manifest
echo "$LARGEST_FILES" | head -10 >> "$MANIFEST_FILE"

# Quick integrity test
log_message "🧪 Running quick extraction test..."
TEST_DIR="/tmp/filestore_test_$$"
mkdir -p "$TEST_DIR"

if tar -xzf "$FILESTORE_BACKUP" -C "$TEST_DIR" --totals 2>> "$LOG_FILE"; then
    EXTRACTED_FILES=$(find "$TEST_DIR" -type f | wc -l)
    if [ "$EXTRACTED_FILES" -eq "$FILE_COUNT" ]; then
        log_message "${GREEN}✅ Extraction test passed ($EXTRACTED_FILES files)${NC}"
    else
        log_message "${YELLOW}⚠️  File count mismatch: Expected $FILE_COUNT, got $EXTRACTED_FILES${NC}"
    fi
    rm -rf "$TEST_DIR"
else
    log_message "${RED}❌ ERROR: Extraction test failed${NC}"
    rm -rf "$TEST_DIR"
    exit 1
fi

# Generate restoration commands
RESTORE_SCRIPT="$BACKUP_DIR/restore_filestore_${TIMESTAMP}.sh"
cat > "$RESTORE_SCRIPT" << EOF
#!/bin/bash
# Filestore Restore Script
# Generated: $(date)

echo "🔧 Restoring filestore for database: $DB_NAME"
echo "Source backup: $FILESTORE_BACKUP"
echo ""

# Extract filestore
TARGET_DIR="\${1:-/opt/odoo/.local/share/Odoo/filestore}"
echo "Target directory: \$TARGET_DIR"

mkdir -p "\$TARGET_DIR"
tar -xzf "$FILESTORE_BACKUP" -C "\$TARGET_DIR" --totals

# Set proper ownership (adjust as needed)
chown -R odoo:odoo "\$TARGET_DIR/$DB_NAME"
chmod -R 755 "\$TARGET_DIR/$DB_NAME"

echo "✅ Filestore restoration complete"
echo "Files restored to: \$TARGET_DIR/$DB_NAME"
EOF

chmod +x "$RESTORE_SCRIPT"

# Final summary
log_message ""
log_message "🎉 FILESTORE BACKUP COMPLETE!"
log_message "=============================="
log_message "✅ Source: $FILESTORE_PATH"
log_message "✅ Backup: $FILESTORE_BACKUP ($BACKUP_SIZE)"
log_message "✅ Files: $FILE_COUNT"
log_message "✅ Integrity: Verified"
log_message "📋 Manifest: $MANIFEST_FILE"
log_message "🔧 Restore Script: $RESTORE_SCRIPT"
log_message ""
log_message "💡 To restore on target server:"
log_message "   $RESTORE_SCRIPT /path/to/target/filestore"
log_message ""
log_message "Completed: $(date)"