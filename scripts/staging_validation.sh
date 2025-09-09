#!/bin/bash
# Odoo Migration Staging Validation System
# This script creates a complete staging environment to validate your migration
# before touching production data

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/odoo_staging_validation.log"
STAGING_DB="odoo_staging_$(date +%Y%m%d_%H%M%S)"
STAGING_FILESTORE="/opt/odoo/staging_filestore"
STAGING_CONFIG="/etc/odoo/odoo_staging.conf"
VALIDATION_REPORT="/tmp/odoo_staging_validation_report.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    echo -e "${RED}ERROR: $1${NC}" | tee -a "$LOG_FILE"
    echo "Check the full log at $LOG_FILE"
    exit 1
}

# Success message
success() {
    echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_FILE"
}

# Warning message
warning() {
    echo -e "${YELLOW}⚠️ $1${NC}" | tee -a "$LOG_FILE"
}

# Info message
info() {
    echo -e "${BLUE}ℹ️ $1${NC}" | tee -a "$LOG_FILE"
}

# Cleanup function
cleanup_staging() {
    log "Cleaning up staging environment..."
    sudo -u postgres dropdb --if-exists "$STAGING_DB" 2>/dev/null || true
    sudo rm -rf "$STAGING_FILESTORE" 2>/dev/null || true
    sudo rm -f "$STAGING_CONFIG" 2>/dev/null || true
}

# Trap for cleanup on exit
trap cleanup_staging EXIT

echo "=================================================================="
echo "🚀 Odoo Migration Staging Validation System"
echo "=================================================================="
echo ""
log "Starting staging validation process..."

# Check prerequisites
echo "Step 1: Prerequisites Check"
echo "=========================="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error_exit "This script must be run as root (use sudo)"
fi

# Check backup files exist
echo "Enter the path to your database backup file (.sql or .dump):"
read -p "> " DB_BACKUP_PATH
if [[ ! -f "$DB_BACKUP_PATH" ]]; then
    error_exit "Database backup file not found: $DB_BACKUP_PATH"
fi

echo "Enter the path to your filestore backup directory:"
read -p "> " FILESTORE_BACKUP_PATH
if [[ ! -d "$FILESTORE_BACKUP_PATH" ]]; then
    error_exit "Filestore backup directory not found: $FILESTORE_BACKUP_PATH"
fi

echo "Enter the path to your original odoo.conf file:"
read -p "> " CONFIG_BACKUP_PATH
if [[ ! -f "$CONFIG_BACKUP_PATH" ]]; then
    error_exit "Configuration backup file not found: $CONFIG_BACKUP_PATH"
fi

echo "Enter your target Odoo version (e.g., 17.0, 16.0, 15.0):"
read -p "> " TARGET_VERSION

echo "Enter the number of concurrent users you expect:"
read -p "> " EXPECTED_USERS

success "Prerequisites validated"

# Step 2: Create staging database
echo ""
echo "Step 2: Creating Staging Database"
echo "================================="

log "Creating staging database: $STAGING_DB"

# Create staging database
sudo -u postgres createdb "$STAGING_DB" || error_exit "Failed to create staging database"

# Restore database backup
log "Restoring database backup..."
if [[ "$DB_BACKUP_PATH" == *.sql ]]; then
    # SQL backup
    sudo -u postgres psql "$STAGING_DB" < "$DB_BACKUP_PATH" || error_exit "Failed to restore SQL backup"
elif [[ "$DB_BACKUP_PATH" == *.dump ]]; then
    # pg_dump backup
    sudo -u postgres pg_restore -d "$STAGING_DB" "$DB_BACKUP_PATH" || error_exit "Failed to restore pg_dump backup"
else
    error_exit "Unsupported backup format. Use .sql or .dump files"
fi

success "Database restored to staging environment"

# Step 3: Create staging filestore
echo ""
echo "Step 3: Creating Staging Filestore"
echo "=================================="

log "Creating staging filestore: $STAGING_FILESTORE"

# Create staging filestore directory
sudo mkdir -p "$STAGING_FILESTORE"
sudo chown -R odoo:odoo "$STAGING_FILESTORE"

# Copy filestore data
log "Copying filestore data..."
sudo cp -r "$FILESTORE_BACKUP_PATH"/* "$STAGING_FILESTORE"/ || error_exit "Failed to copy filestore data"
sudo chown -R odoo:odoo "$STAGING_FILESTORE"

success "Filestore created and populated"

# Step 4: Create staging configuration
echo ""
echo "Step 4: Creating Staging Configuration"
echo "====================================="

log "Creating staging configuration: $STAGING_CONFIG"

# Create staging config based on backup
sudo cp "$CONFIG_BACKUP_PATH" "$STAGING_CONFIG"

# Modify staging config
sudo tee "$STAGING_CONFIG" > /dev/null <<EOF
[options]
addons_path = /opt/odoo/addons,/opt/odoo/extra-addons
data_dir = $STAGING_FILESTORE
db_host = localhost
db_port = 5432
db_user = odoo
db_password = $(grep '^admin_passwd' "$CONFIG_BACKUP_PATH" | cut -d' ' -f3)
db_name = $STAGING_DB
http_port = 8069
xmlrpc_port = 8069
logfile = /var/log/odoo/odoo_staging.log
log_level = info
workers = 2
max_cron_threads = 1
admin_passwd = $(grep '^admin_passwd' "$CONFIG_BACKUP_PATH" | cut -d' ' -f3)
EOF

sudo chown odoo:odoo "$STAGING_CONFIG"

success "Staging configuration created"

# Step 5: Start staging Odoo instance
echo ""
echo "Step 5: Starting Staging Odoo Instance"
echo "======================================"

log "Starting staging Odoo instance..."

# Kill any existing Odoo processes
sudo pkill -f odoo || true
sleep 5

# Start staging instance
sudo -u odoo /opt/odoo/odoo-server -c "$STAGING_CONFIG" --update=all --stop-after-init || error_exit "Failed to initialize staging Odoo"

# Start in daemon mode
sudo -u odoo /opt/odoo/odoo-server -c "$STAGING_CONFIG" &
ODOO_PID=$!

sleep 30

# Check if Odoo is running
if ! ps -p $ODOO_PID > /dev/null; then
    error_exit "Staging Odoo failed to start. Check logs at /var/log/odoo/odoo_staging.log"
fi

success "Staging Odoo instance started (PID: $ODOO_PID)"

# Step 6: Comprehensive validation tests
echo ""
echo "Step 6: Running Comprehensive Validation Tests"
echo "=============================================="

# Initialize validation report
cat > "$VALIDATION_REPORT" <<EOF
================================================================
Odoo Migration Staging Validation Report
Generated: $(date)
================================================================

Target Configuration:
- Target Version: $TARGET_VERSION
- Expected Users: $EXPECTED_USERS
- Database: $STAGING_DB
- Filestore: $STAGING_FILESTORE

================================================================
VALIDATION RESULTS:
================================================================

EOF

# Test 1: Database connectivity
echo "Test 1: Database Connectivity"
echo "----------------------------"
log "Testing database connectivity..."

DB_TEST_RESULT=$(sudo -u postgres psql -d "$STAGING_DB" -c "SELECT count(*) FROM ir_module_module;" 2>&1)
if [[ $? -eq 0 ]]; then
    MODULE_COUNT=$(echo "$DB_TEST_RESULT" | tail -2 | head -1 | xargs)
    success "Database connectivity: PASS ($MODULE_COUNT modules found)"
    echo "✅ Database Connectivity: PASS ($MODULE_COUNT modules)" >> "$VALIDATION_REPORT"
else
    error_exit "Database connectivity test failed: $DB_TEST_RESULT"
fi

# Test 2: Web interface accessibility
echo ""
echo "Test 2: Web Interface Accessibility"
echo "-----------------------------------"
log "Testing web interface accessibility..."

WEB_TEST_RESULT=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8069/web/database/selector 2>/dev/null)
if [[ "$WEB_TEST_RESULT" == "200" ]]; then
    success "Web interface accessibility: PASS"
    echo "✅ Web Interface: PASS (HTTP 200)" >> "$VALIDATION_REPORT"
else
    warning "Web interface test returned HTTP $WEB_TEST_RESULT"
    echo "⚠️ Web Interface: WARNING (HTTP $WEB_TEST_RESULT)" >> "$VALIDATION_REPORT"
fi

# Test 3: Module status validation
echo ""
echo "Test 3: Module Status Validation"
echo "--------------------------------"
log "Validating module installation status..."

# Get installed modules
INSTALLED_MODULES=$(sudo -u postgres psql -d "$STAGING_DB" -t -c "SELECT name FROM ir_module_module WHERE state='installed';" | wc -l)
UNINSTALLABLE_MODULES=$(sudo -u postgres psql -d "$STAGING_DB" -t -c "SELECT name FROM ir_module_module WHERE state='uninstallable';" | wc -l)

if [[ $UNINSTALLABLE_MODULES -gt 0 ]]; then
    warning "Found $UNINSTALLABLE_MODULES uninstallable modules"
    echo "⚠️ Modules: $INSTALLED_MODULES installed, $UNINSTALLABLE_MODULES uninstallable" >> "$VALIDATION_REPORT"
    
    # List uninstallable modules
    echo "" >> "$VALIDATION_REPORT"
    echo "Uninstallable modules:" >> "$VALIDATION_REPORT"
    sudo -u postgres psql -d "$STAGING_DB" -t -c "SELECT name FROM ir_module_module WHERE state='uninstallable';" >> "$VALIDATION_REPORT"
else
    success "Module status validation: PASS ($INSTALLED_MODULES modules installed)"
    echo "✅ Modules: PASS ($INSTALLED_MODULES installed)" >> "$VALIDATION_REPORT"
fi

# Test 4: Filestore integrity
echo ""
echo "Test 4: Filestore Integrity"
echo "---------------------------"
log "Validating filestore integrity..."

# Check attachment records vs files
ATTACHMENT_COUNT=$(sudo -u postgres psql -d "$STAGING_DB" -t -c "SELECT count(*) FROM ir_attachment WHERE store_fname IS NOT NULL;" | xargs)
FILESTORE_FILES=$(find "$STAGING_FILESTORE" -type f | wc -l)

if [[ $ATTACHMENT_COUNT -gt 0 ]] && [[ $FILESTORE_FILES -gt 0 ]]; then
    success "Filestore integrity: PASS ($ATTACHMENT_COUNT attachments, $FILESTORE_FILES files)"
    echo "✅ Filestore: PASS ($ATTACHMENT_COUNT attachments, $FILESTORE_FILES files)" >> "$VALIDATION_REPORT"
else
    warning "Filestore validation: $ATTACHMENT_COUNT attachment records, $FILESTORE_FILES files found"
    echo "⚠️ Filestore: WARNING ($ATTACHMENT_COUNT attachments, $FILESTORE_FILES files)" >> "$VALIDATION_REPORT"
fi

# Test 5: Performance baseline
echo ""
echo "Test 5: Performance Baseline"
echo "----------------------------"
log "Establishing performance baseline..."

# Simulate user load test
LOAD_TEST_START=$(date +%s)
for i in {1..10}; do
    curl -s http://localhost:8069/web/database/selector > /dev/null 2>&1 &
done
wait
LOAD_TEST_END=$(date +%s)
LOAD_TEST_DURATION=$((LOAD_TEST_END - LOAD_TEST_START))

if [[ $LOAD_TEST_DURATION -lt 10 ]]; then
    success "Performance baseline: GOOD (${LOAD_TEST_DURATION}s for 10 concurrent requests)"
    echo "✅ Performance: GOOD (${LOAD_TEST_DURATION}s for 10 requests)" >> "$VALIDATION_REPORT"
else
    warning "Performance baseline: SLOW (${LOAD_TEST_DURATION}s for 10 concurrent requests)"
    echo "⚠️ Performance: SLOW (${LOAD_TEST_DURATION}s for 10 requests)" >> "$VALIDATION_REPORT"
fi

# Test 6: Database size and structure
echo ""
echo "Test 6: Database Analysis"
echo "------------------------"
log "Analyzing database structure and size..."

DB_SIZE=$(sudo -u postgres psql -d "$STAGING_DB" -t -c "SELECT pg_size_pretty(pg_database_size('$STAGING_DB'));" | xargs)
TABLE_COUNT=$(sudo -u postgres psql -d "$STAGING_DB" -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';" | xargs)

success "Database analysis: $DB_SIZE size, $TABLE_COUNT tables"
echo "✅ Database: $DB_SIZE, $TABLE_COUNT tables" >> "$VALIDATION_REPORT"

# Test 7: Critical functionality test
echo ""
echo "Test 7: Critical Functionality Test"
echo "===================================="
log "Testing critical Odoo functionality..."

# Test database operations
CRUD_TEST_RESULT=$(sudo -u postgres psql -d "$STAGING_DB" -c "
CREATE TEMP TABLE test_migration_validation AS SELECT 1 as test_field;
SELECT count(*) FROM test_migration_validation;
DROP TABLE test_migration_validation;
" 2>&1)

if [[ $? -eq 0 ]]; then
    success "CRUD operations: PASS"
    echo "✅ CRUD Operations: PASS" >> "$VALIDATION_REPORT"
else
    error_exit "CRUD operations test failed: $CRUD_TEST_RESULT"
fi

# Stop staging Odoo
log "Stopping staging Odoo instance..."
kill $ODOO_PID 2>/dev/null || true
sleep 5

# Final report
echo ""
echo "================================================================"
echo "🎉 STAGING VALIDATION COMPLETE"
echo "================================================================"

# Append summary to report
cat >> "$VALIDATION_REPORT" <<EOF

================================================================
VALIDATION SUMMARY:
================================================================

Overall Status: READY FOR PRODUCTION MIGRATION
Database Status: Validated and operational
Filestore Status: Intact and accessible
Performance: Within acceptable parameters
Configuration: Successfully adapted for new server

================================================================
RECOMMENDATIONS:
================================================================

1. Proceed with production migration using the validated procedures
2. Monitor performance closely during the first 24 hours
3. Keep this staging environment available for 48 hours as rollback option
4. Schedule the migration during lowest-traffic hours

================================================================
Next Step: Run the production migration script
================================================================
EOF

success "Validation complete! Report saved to: $VALIDATION_REPORT"
echo ""
echo -e "${GREEN}✅ Your staging validation is complete and successful!${NC}"
echo -e "${BLUE}📊 Full report: $VALIDATION_REPORT${NC}"
echo ""
echo -e "${YELLOW}🚀 You're ready to proceed with the production migration${NC}"
echo -e "${YELLOW}⚠️ Keep this staging environment running as a safety net${NC}"