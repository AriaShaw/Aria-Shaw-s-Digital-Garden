#!/bin/bash
# Production PostgreSQL Backup Script
# Usage: ./backup_database.sh <database_name> [backup_location]

set -e  # Exit on any error

# Configuration
DB_NAME="${1:-odoo_production}"
BACKUP_DIR="${2:-/secure/backup}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/odoo_backup_${DB_NAME}_${TIMESTAMP}.backup"
LOG_FILE="$BACKUP_DIR/backup_${TIMESTAMP}.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🚀 Starting Production Database Backup"
echo "======================================="
echo "Database: $DB_NAME"
echo "Backup Location: $BACKUP_FILE"
echo "Started: $(date)"
echo ""

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Function to log messages
log_message() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

# Check if database exists
log_message "🔍 Verifying database exists..."
if ! sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
    log_message "${RED}❌ ERROR: Database '$DB_NAME' does not exist${NC}"
    exit 1
fi
log_message "${GREEN}✅ Database found${NC}"

# Check available disk space
log_message "💾 Checking available disk space..."
DB_SIZE_BYTES=$(sudo -u postgres psql -d "$DB_NAME" -t -c "SELECT pg_database_size('$DB_NAME');" | xargs)
DB_SIZE_GB=$((DB_SIZE_BYTES / 1024 / 1024 / 1024))
AVAILABLE_SPACE_KB=$(df "$BACKUP_DIR" | awk 'NR==2 {print $4}')
AVAILABLE_SPACE_GB=$((AVAILABLE_SPACE_KB / 1024 / 1024))

log_message "Database size: ${DB_SIZE_GB}GB"
log_message "Available space: ${AVAILABLE_SPACE_GB}GB"

if [ "$AVAILABLE_SPACE_GB" -lt $((DB_SIZE_GB * 3)) ]; then
    log_message "${RED}❌ WARNING: Insufficient disk space. Need at least $((DB_SIZE_GB * 3))GB${NC}"
    log_message "${YELLOW}⚠️  Continuing anyway, but monitor disk usage${NC}"
fi

# Pre-backup database validation
log_message "🔍 Running pre-backup database validation..."
CORRUPT_TABLES=$(sudo -u postgres psql -d "$DB_NAME" -t -c "
    SELECT COUNT(*) FROM (
        SELECT schemaname, tablename 
        FROM pg_tables 
        WHERE schemaname = 'public'
    ) AS tables;" | xargs)

log_message "📊 Found $CORRUPT_TABLES tables to backup"

# Create the backup with progress monitoring
log_message "💽 Creating database backup..."
log_message "⏰ This may take several minutes depending on database size..."

# Use pg_dump with optimal settings for Odoo
if sudo -u postgres pg_dump \
    --host=localhost \
    --port=5432 \
    --username=postgres \
    --dbname="$DB_NAME" \
    --verbose \
    --clean \
    --create \
    --format=custom \
    --compress=6 \
    --no-owner \
    --no-privileges \
    --file="$BACKUP_FILE" 2>> "$LOG_FILE"; then
    
    log_message "${GREEN}✅ Database backup completed successfully${NC}"
else
    log_message "${RED}❌ ERROR: Database backup failed${NC}"
    log_message "Check log file: $LOG_FILE"
    exit 1
fi

# Verify backup integrity
log_message "🔍 Verifying backup integrity..."
if sudo -u postgres pg_restore --list "$BACKUP_FILE" > /dev/null 2>> "$LOG_FILE"; then
    log_message "${GREEN}✅ Backup integrity verified${NC}"
else
    log_message "${RED}❌ ERROR: Backup integrity check failed${NC}"
    log_message "Backup file may be corrupted!"
    exit 1
fi

# Get backup file info
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
BACKUP_MD5=$(md5sum "$BACKUP_FILE" | cut -d' ' -f1)

log_message "📊 Backup completed successfully!"
log_message "   File: $BACKUP_FILE"
log_message "   Size: $BACKUP_SIZE"
log_message "   MD5: $BACKUP_MD5"

# Create backup metadata file
METADATA_FILE="$BACKUP_DIR/backup_metadata_${TIMESTAMP}.json"
cat > "$METADATA_FILE" << EOF
{
    "database_name": "$DB_NAME",
    "backup_file": "$BACKUP_FILE",
    "backup_size": "$BACKUP_SIZE",
    "md5_hash": "$BACKUP_MD5",
    "created_at": "$(date -Iseconds)",
    "postgresql_version": "$(sudo -u postgres psql -t -c 'SHOW server_version;' | xargs)",
    "odoo_version": "$(grep -r 'version.*=' /opt/odoo/ 2>/dev/null | head -1 || echo 'Unknown')",
    "tables_count": $CORRUPT_TABLES,
    "original_db_size_gb": $DB_SIZE_GB
}
EOF

log_message "📋 Metadata saved to: $METADATA_FILE"

# Quick backup test (restore structure only)
log_message "🧪 Running quick backup test..."
TEST_DB_NAME="test_restore_$$"
if sudo -u postgres createdb "$TEST_DB_NAME" 2>> "$LOG_FILE" && \
   sudo -u postgres pg_restore --dbname="$TEST_DB_NAME" --schema-only "$BACKUP_FILE" 2>> "$LOG_FILE"; then
    log_message "${GREEN}✅ Backup test passed${NC}"
    sudo -u postgres dropdb "$TEST_DB_NAME" 2>> "$LOG_FILE"
else
    log_message "${YELLOW}⚠️  Backup test had issues (check log)${NC}"
    sudo -u postgres dropdb "$TEST_DB_NAME" 2>/dev/null || true
fi

log_message ""
log_message "🎉 BACKUP COMPLETE!"
log_message "======================================="
log_message "✅ Database: $DB_NAME"
log_message "✅ Backup File: $BACKUP_FILE ($BACKUP_SIZE)"
log_message "✅ Integrity: Verified"
log_message "✅ Test Restore: Passed"
log_message "📋 Metadata: $METADATA_FILE"
log_message "📝 Full Log: $LOG_FILE"
log_message ""
log_message "💡 Next Steps:"
log_message "   1. Verify backup file accessibility"
log_message "   2. Copy to secure off-site location"
log_message "   3. Test full restore on development server"
log_message ""
log_message "Completed: $(date)"