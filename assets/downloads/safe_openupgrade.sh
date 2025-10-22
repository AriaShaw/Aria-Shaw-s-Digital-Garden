#!/bin/bash
# Safe OpenUpgrade Wrapper with Rollback Protection
# Usage: ./safe_openupgrade.sh --from-version 13.0 --to-version 15.0 --database production_db

set -e

# Default values
FROM_VERSION=""
TO_VERSION=""
DATABASE=""
BACKUP_DIR="/backup/openupgrade_safety"
LOG_FILE="/var/log/safe_openupgrade.log"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --from-version)
            FROM_VERSION="$2"
            shift 2
            ;;
        --to-version)
            TO_VERSION="$2"
            shift 2
            ;;
        --database)
            DATABASE="$2"
            shift 2
            ;;
        --backup-dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$FROM_VERSION" ] || [ -z "$TO_VERSION" ] || [ -z "$DATABASE" ]; then
    echo "Error: Missing required parameters"
    echo "Usage: $0 --from-version X.X --to-version Y.Y --database db_name"
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Safe OpenUpgrade Migration Started ==="
log "From: Odoo $FROM_VERSION"
log "To: Odoo $TO_VERSION"
log "Database: $DATABASE"

# Step 1: Pre-migration validation
log "Step 1: Pre-migration validation"

# Check if database exists
if ! sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$DATABASE"; then
    log "ERROR: Database '$DATABASE' does not exist"
    exit 1
fi

# Check disk space (need at least 2x database size)
DB_SIZE=$(sudo -u postgres psql -d "$DATABASE" -t -c "SELECT pg_size_pretty(pg_database_size('$DATABASE'));" | tr -d ' ')
log "Database size: $DB_SIZE"

AVAILABLE_SPACE=$(df -h "$BACKUP_DIR" | awk 'NR==2{print $4}')
log "Available backup space: $AVAILABLE_SPACE"

# Step 2: Create safety snapshot
log "Step 2: Creating safety snapshot"
SNAPSHOT_FILE="$BACKUP_DIR/pre_openupgrade_${DATABASE}_$(date +%Y%m%d_%H%M%S).backup"

log "Creating database snapshot: $SNAPSHOT_FILE"
sudo -u postgres pg_dump -d "$DATABASE" \
    --format=custom \
    --compress=6 \
    --verbose \
    --file="$SNAPSHOT_FILE" 2>&1 | tee -a "$LOG_FILE"

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    log "ERROR: Failed to create database snapshot"
    exit 1
fi

log "Snapshot created successfully: $SNAPSHOT_FILE"

# Step 3: Verify snapshot integrity
log "Step 3: Verifying snapshot integrity"
if ! sudo -u postgres pg_restore --list "$SNAPSHOT_FILE" > /dev/null 2>&1; then
    log "ERROR: Snapshot verification failed"
    exit 1
fi
log "Snapshot verification passed"

# Step 4: Check module dependencies
log "Step 4: Checking module dependencies"
FAILED_MODULES=$(sudo -u postgres psql -d "$DATABASE" -t -c "
    SELECT string_agg(name, ', ') 
    FROM ir_module_module 
    WHERE state IN ('to upgrade', 'to install') 
    AND auto_install = false;" | tr -d ' ')

if [ -n "$FAILED_MODULES" ]; then
    log "WARNING: Modules in transitional state: $FAILED_MODULES"
    log "These modules may cause upgrade issues"
fi

# Step 5: Download and prepare OpenUpgrade
log "Step 5: Preparing OpenUpgrade"
OPENUPGRADE_DIR="/opt/openupgrade"

if [ ! -d "$OPENUPGRADE_DIR" ]; then
    log "Cloning OpenUpgrade repository"
    sudo git clone https://github.com/OCA/OpenUpgrade.git "$OPENUPGRADE_DIR"
fi

cd "$OPENUPGRADE_DIR"
sudo git fetch --all
sudo git checkout "$TO_VERSION"

# Check if odoo-bin exists (for newer versions)
if [ -f "$OPENUPGRADE_DIR/odoo-bin" ]; then
    ODOO_BIN="$OPENUPGRADE_DIR/odoo-bin"
elif [ -f "$OPENUPGRADE_DIR/openerp-server" ]; then
    ODOO_BIN="$OPENUPGRADE_DIR/openerp-server"
else
    log "ERROR: Cannot find Odoo executable in OpenUpgrade"
    exit 1
fi

log "Using Odoo executable: $ODOO_BIN"

# Step 6: Stop current Odoo service
log "Step 6: Stopping Odoo service"
sudo systemctl stop odoo || true
sleep 5

# Kill any remaining Odoo processes
sudo pkill -f odoo || true
sudo pkill -f openerp || true
sleep 2

# Step 7: Execute OpenUpgrade with monitoring
log "Step 7: Executing OpenUpgrade migration"

# Create a temporary config file
TEMP_CONFIG="/tmp/openupgrade_config.conf"
cat > "$TEMP_CONFIG" << EOF
[options]
db_host = localhost
db_port = 5432
db_user = odoo
db_password = odoo
addons_path = $OPENUPGRADE_DIR/addons,$OPENUPGRADE_DIR/odoo/addons
logfile = $LOG_FILE
log_level = info
EOF

# Set up automatic rollback on failure
rollback_on_failure() {
    log "ERROR: OpenUpgrade failed. Initiating automatic rollback..."
    
    # Stop any running processes
    sudo pkill -f odoo || true
    sudo pkill -f openerp || true
    
    # Drop the corrupted database
    sudo -u postgres dropdb "$DATABASE" || true
    
    # Restore from snapshot
    log "Restoring database from snapshot..."
    sudo -u postgres pg_restore --create --clean \
        -d postgres "$SNAPSHOT_FILE" 2>&1 | tee -a "$LOG_FILE"
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        log "Rollback completed successfully"
        log "Your original database has been restored"
    else
        log "CRITICAL: Rollback failed. Manual intervention required."
        log "Snapshot location: $SNAPSHOT_FILE"
    fi
    
    # Restart original Odoo service
    sudo systemctl start odoo
    
    exit 1
}

# Set trap for automatic rollback
trap rollback_on_failure ERR

# Execute the upgrade
log "Starting OpenUpgrade migration process..."
timeout 7200 sudo -u odoo python3 "$ODOO_BIN" \
    -c "$TEMP_CONFIG" \
    -d "$DATABASE" \
    --update=all \
    --stop-after-init 2>&1 | tee -a "$LOG_FILE"

# Step 8: Verify migration success
log "Step 8: Verifying migration success"

# Check if database is accessible
if ! sudo -u postgres psql -d "$DATABASE" -c "SELECT 1;" > /dev/null 2>&1; then
    log "ERROR: Database is not accessible after migration"
    rollback_on_failure
fi

# Check critical tables
CRITICAL_TABLES=("res_users" "res_partner" "ir_module_module")
for table in "${CRITICAL_TABLES[@]}"; do
    count=$(sudo -u postgres psql -d "$DATABASE" -t -c "SELECT COUNT(*) FROM $table;" 2>/dev/null | tr -d ' ')
    if [ -z "$count" ] || [ "$count" -eq 0 ]; then
        log "ERROR: Critical table $table is empty or inaccessible"
        rollback_on_failure
    fi
    log "✓ Table $table: $count records"
done

# Step 9: Test Odoo startup
log "Step 9: Testing Odoo startup"
timeout 120 sudo -u odoo python3 "$ODOO_BIN" \
    -c "$TEMP_CONFIG" \
    -d "$DATABASE" \
    --test-enable \
    --stop-after-init 2>&1 | tee -a "$LOG_FILE"

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    log "ERROR: Odoo failed to start properly after migration"
    rollback_on_failure
fi

# Step 10: Success cleanup
log "Step 10: Migration completed successfully"

# Remove trap (disable automatic rollback)
trap - ERR

# Clean up temporary files
rm -f "$TEMP_CONFIG"

# Keep snapshot for safety
log "Migration completed successfully!"
log "Original database snapshot preserved at: $SNAPSHOT_FILE"
log "You can safely delete this snapshot after confirming everything works correctly."

# Restart Odoo service
sudo systemctl start odoo

log "Safe OpenUpgrade migration completed at $(date)"
log "Database '$DATABASE' successfully upgraded from $FROM_VERSION to $TO_VERSION"

exit 0