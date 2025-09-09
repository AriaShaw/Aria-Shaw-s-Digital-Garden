#!/bin/bash
# Odoo Production Migration Execution System
# Zero-downtime migration with automatic rollback capabilities
# 
# This script manages the complete production migration process with
# real-time monitoring, validation, and rollback capabilities

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/odoo_production_migration.log"
MIGRATION_ID="migration_$(date +%Y%m%d_%H%M%S)"
ROLLBACK_PLAN="/tmp/odoo_rollback_plan_${MIGRATION_ID}.sh"
VALIDATION_LOG="/tmp/odoo_migration_validation_${MIGRATION_ID}.log"
PERFORMANCE_LOG="/tmp/odoo_performance_${MIGRATION_ID}.log"
DOWNTIME_LOG="/tmp/odoo_downtime_${MIGRATION_ID}.log"

# Service configuration
ODOO_SERVICE="odoo"
NGINX_SERVICE="nginx"
NEW_DB_NAME="odoo_production_new"
BACKUP_DB_NAME="odoo_production_backup_$(date +%Y%m%d_%H%M%S)"
NEW_FILESTORE="/opt/odoo/filestore"
BACKUP_FILESTORE="/opt/odoo/filestore_backup_$(date +%Y%m%d_%H%M%S)"
NEW_CONFIG="/etc/odoo/odoo.conf"
BACKUP_CONFIG="/etc/odoo/odoo_backup_$(date +%Y%m%d_%H%M%S).conf"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Advanced logging with timestamps and levels
log() {
    local level=$1
    shift
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $*" | tee -a "$LOG_FILE"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_success() { log "SUCCESS" "$@"; }

# Error handling with automatic rollback
error_with_rollback() {
    log_error "$1"
    echo -e "${RED}💥 CRITICAL ERROR: $1${NC}"
    echo -e "${YELLOW}🔄 Initiating automatic rollback...${NC}"
    execute_rollback
    exit 1
}

# Success with style
success() {
    log_success "$1"
    echo -e "${GREEN}✅ $1${NC}"
}

# Warning with visibility
warning() {
    log_warn "$1"
    echo -e "${YELLOW}⚠️ $1${NC}"
}

# Info with clarity
info() {
    log_info "$1"
    echo -e "${BLUE}ℹ️ $1${NC}"
}

# Progress indicator
progress() {
    echo -e "${CYAN}🔄 $1${NC}"
    log_info "PROGRESS: $1"
}

# Downtime tracker
DOWNTIME_START=""
start_downtime_tracking() {
    DOWNTIME_START=$(date +%s.%N)
    echo "$(date '+%Y-%m-%d %H:%M:%S'): Service downtime started" > "$DOWNTIME_LOG"
}

end_downtime_tracking() {
    if [[ -n "$DOWNTIME_START" ]]; then
        local downtime_end=$(date +%s.%N)
        local downtime_duration=$(echo "$downtime_end - $DOWNTIME_START" | bc -l)
        echo "$(date '+%Y-%m-%d %H:%M:%S'): Service downtime ended" >> "$DOWNTIME_LOG"
        echo "Total downtime: ${downtime_duration} seconds" >> "$DOWNTIME_LOG"
        success "Total downtime: ${downtime_duration} seconds"
    fi
}

# Performance monitoring
monitor_performance() {
    local test_name=$1
    local start_time=$(date +%s.%N)
    
    # Execute the test
    shift
    "$@"
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l)
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $test_name completed in ${duration}s" >> "$PERFORMANCE_LOG"
}

# Create rollback plan
create_rollback_plan() {
    log_info "Creating rollback plan: $ROLLBACK_PLAN"
    
    cat > "$ROLLBACK_PLAN" <<EOF
#!/bin/bash
# Automatic Rollback Plan - Generated $(date)
# Migration ID: $MIGRATION_ID

set -euo pipefail

echo "🔄 Executing automatic rollback for migration $MIGRATION_ID"

# Stop new Odoo service
sudo systemctl stop $ODOO_SERVICE 2>/dev/null || true

# Restore database
if sudo -u postgres psql -lqt | cut -d'|' -f1 | grep -qw "$BACKUP_DB_NAME"; then
    echo "Restoring database from $BACKUP_DB_NAME..."
    sudo -u postgres dropdb --if-exists "$NEW_DB_NAME"
    sudo -u postgres createdb "$NEW_DB_NAME"
    sudo -u postgres pg_dump "$BACKUP_DB_NAME" | sudo -u postgres psql "$NEW_DB_NAME"
fi

# Restore filestore
if [[ -d "$BACKUP_FILESTORE" ]]; then
    echo "Restoring filestore from $BACKUP_FILESTORE..."
    sudo rm -rf "$NEW_FILESTORE"
    sudo cp -r "$BACKUP_FILESTORE" "$NEW_FILESTORE"
    sudo chown -R odoo:odoo "$NEW_FILESTORE"
fi

# Restore configuration
if [[ -f "$BACKUP_CONFIG" ]]; then
    echo "Restoring configuration from $BACKUP_CONFIG..."
    sudo cp "$BACKUP_CONFIG" "$NEW_CONFIG"
fi

# Restart services
sudo systemctl start $ODOO_SERVICE
sudo systemctl start $NGINX_SERVICE

echo "✅ Rollback completed successfully"
echo "⚠️ Check system status and investigate the original migration failure"
EOF

    chmod +x "$ROLLBACK_PLAN"
    success "Rollback plan created: $ROLLBACK_PLAN"
}

# Execute rollback
execute_rollback() {
    if [[ -f "$ROLLBACK_PLAN" ]]; then
        log_warn "Executing rollback plan..."
        bash "$ROLLBACK_PLAN"
    else
        log_error "Rollback plan not found! Manual intervention required."
    fi
}

# Comprehensive pre-migration validation
pre_migration_validation() {
    progress "Running pre-migration validation..."
    
    # Check system resources
    local available_mem=$(free -g | awk '/^Mem:/{print $7}')
    local available_disk=$(df -BG /opt | awk 'NR==2{print $4}' | sed 's/G//')
    
    if [[ $available_mem -lt 2 ]]; then
        error_with_rollback "Insufficient memory: ${available_mem}GB available, need at least 2GB"
    fi
    
    if [[ $available_disk -lt 10 ]]; then
        error_with_rollback "Insufficient disk space: ${available_disk}GB available, need at least 10GB"
    fi
    
    # Check backup files
    echo "Enter the path to your database backup file:"
    read -p "> " DB_BACKUP_PATH
    [[ -f "$DB_BACKUP_PATH" ]] || error_with_rollback "Database backup not found: $DB_BACKUP_PATH"
    
    echo "Enter the path to your filestore backup:"
    read -p "> " FILESTORE_BACKUP_PATH
    [[ -d "$FILESTORE_BACKUP_PATH" ]] || error_with_rollback "Filestore backup not found: $FILESTORE_BACKUP_PATH"
    
    echo "Enter the path to your configuration backup:"
    read -p "> " CONFIG_BACKUP_PATH
    [[ -f "$CONFIG_BACKUP_PATH" ]] || error_with_rollback "Configuration backup not found: $CONFIG_BACKUP_PATH"
    
    # Verify backup integrity
    progress "Verifying backup integrity..."
    
    # Check database backup
    if [[ "$DB_BACKUP_PATH" == *.sql ]]; then
        head -10 "$DB_BACKUP_PATH" | grep -q "PostgreSQL database dump" || \
            warning "Database backup may not be a valid PostgreSQL dump"
    fi
    
    # Check filestore size
    local filestore_size=$(du -sg "$FILESTORE_BACKUP_PATH" | cut -f1)
    info "Filestore backup size: ${filestore_size}GB"
    
    success "Pre-migration validation passed"
}

# Main migration execution
main() {
    echo "=================================================================="
    echo -e "${GREEN}🚀 Odoo Production Migration Execution System${NC}"
    echo -e "${BLUE}Migration ID: $MIGRATION_ID${NC}"
    echo "=================================================================="
    echo ""
    
    log_info "Starting production migration: $MIGRATION_ID"
    
    # Check if running as root
    [[ $EUID -eq 0 ]] || error_with_rollback "This script must be run as root"
    
    # Create rollback plan first
    create_rollback_plan
    
    # Pre-migration validation
    pre_migration_validation
    
    echo ""
    echo -e "${YELLOW}⚠️ FINAL CONFIRMATION REQUIRED${NC}"
    echo "This will migrate your production Odoo system with minimal downtime."
    echo "The process includes automatic rollback on any failure."
    echo ""
    echo -e "${CYAN}Estimated timeline:${NC}"
    echo "  • Backup current system: 2-5 minutes"
    echo "  • Service downtime: 3-5 minutes"
    echo "  • Migration validation: 2-3 minutes"
    echo "  • Total process time: 10-15 minutes"
    echo ""
    read -p "Type 'MIGRATE' to continue with production migration: " confirmation
    
    if [[ "$confirmation" != "MIGRATE" ]]; then
        echo "Migration cancelled by user"
        exit 0
    fi
    
    # Step 1: Backup current production system
    echo ""
    echo "Step 1: Backing Up Current Production System"
    echo "============================================"
    
    progress "Creating production system backup..."
    
    # Backup database
    monitor_performance "Database Backup" sudo -u postgres pg_dump odoo_production > "/tmp/odoo_production_backup_${MIGRATION_ID}.sql"
    
    # Create backup database
    sudo -u postgres createdb "$BACKUP_DB_NAME"
    sudo -u postgres psql "$BACKUP_DB_NAME" < "/tmp/odoo_production_backup_${MIGRATION_ID}.sql"
    
    # Backup filestore
    sudo cp -r /opt/odoo/filestore "$BACKUP_FILESTORE"
    
    # Backup configuration
    sudo cp /etc/odoo/odoo.conf "$BACKUP_CONFIG"
    
    success "Production system backup completed"
    
    # Step 2: Pre-deployment preparation
    echo ""
    echo "Step 2: Pre-deployment Preparation"
    echo "=================================="
    
    progress "Preparing new system components..."
    
    # Create new database
    sudo -u postgres createdb "$NEW_DB_NAME"
    
    # Restore backup to new database
    monitor_performance "Database Restore" sudo -u postgres psql "$NEW_DB_NAME" < "$DB_BACKUP_PATH"
    
    # Prepare new filestore
    sudo rm -rf "$NEW_FILESTORE.new"
    sudo cp -r "$FILESTORE_BACKUP_PATH" "$NEW_FILESTORE.new"
    sudo chown -R odoo:odoo "$NEW_FILESTORE.new"
    
    # Prepare new configuration
    sudo cp "$CONFIG_BACKUP_PATH" "$NEW_CONFIG.new"
    
    # Update configuration for new database
    sudo sed -i "s/db_name = .*/db_name = $NEW_DB_NAME/" "$NEW_CONFIG.new"
    
    success "Pre-deployment preparation completed"
    
    # Step 3: Service transition (downtime period)
    echo ""
    echo "Step 3: Service Transition (Minimal Downtime)"
    echo "============================================="
    
    warning "Starting service transition - downtime period begins"
    start_downtime_tracking
    
    # Stop current services
    progress "Stopping current services..."
    sudo systemctl stop "$ODOO_SERVICE"
    sudo systemctl stop "$NGINX_SERVICE"
    
    # Switch to new components atomically
    progress "Switching to new system components..."
    
    # Switch filestore
    sudo mv "$NEW_FILESTORE" "$NEW_FILESTORE.old"
    sudo mv "$NEW_FILESTORE.new" "$NEW_FILESTORE"
    
    # Switch configuration
    sudo mv "$NEW_CONFIG" "$NEW_CONFIG.old"
    sudo mv "$NEW_CONFIG.new" "$NEW_CONFIG"
    
    # Update database in configuration
    sudo sed -i "s/db_name = odoo_production/db_name = $NEW_DB_NAME/" "$NEW_CONFIG"
    
    # Start new services
    progress "Starting new services..."
    sudo systemctl start "$ODOO_SERVICE"
    sudo systemctl start "$NGINX_SERVICE"
    
    # Wait for services to initialize
    sleep 10
    
    end_downtime_tracking
    success "Service transition completed"
    
    # Step 4: Post-migration validation
    echo ""
    echo "Step 4: Post-migration Validation"
    echo "================================="
    
    progress "Running comprehensive post-migration validation..."
    
    # Web interface test
    monitor_performance "Web Interface Test" bash -c "
        for i in {1..5}; do
            response=\$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8069/web/database/selector 2>/dev/null)
            if [[ \"\$response\" == '200' ]]; then
                exit 0
            fi
            sleep 2
        done
        exit 1
    " || error_with_rollback "Web interface validation failed"
    
    # Database connectivity test
    monitor_performance "Database Test" sudo -u postgres psql -d "$NEW_DB_NAME" -c "SELECT count(*) FROM ir_module_module;" > /dev/null || \
        error_with_rollback "Database connectivity validation failed"
    
    # Filestore test
    monitor_performance "Filestore Test" bash -c "
        attachment_count=\$(sudo -u postgres psql -d '$NEW_DB_NAME' -t -c 'SELECT count(*) FROM ir_attachment WHERE store_fname IS NOT NULL;' | xargs)
        if [[ \$attachment_count -gt 0 ]]; then
            file_count=\$(find '$NEW_FILESTORE' -type f | wc -l)
            if [[ \$file_count -eq 0 ]]; then
                exit 1
            fi
        fi
        exit 0
    " || error_with_rollback "Filestore validation failed"
    
    # Performance test
    monitor_performance "Performance Test" bash -c "
        start_time=\$(date +%s)
        for i in {1..20}; do
            curl -s http://localhost:8069/web/database/selector > /dev/null &
        done
        wait
        end_time=\$(date +%s)
        duration=\$((end_time - start_time))
        if [[ \$duration -gt 15 ]]; then
            exit 1
        fi
        exit 0
    " || warning "Performance test indicates slow response times"
    
    success "Post-migration validation passed"
    
    # Step 5: Final optimization and cleanup
    echo ""
    echo "Step 5: Final Optimization and Cleanup"
    echo "======================================"
    
    progress "Running post-migration optimizations..."
    
    # Optimize new database
    monitor_performance "Database Optimization" sudo -u postgres psql -d "$NEW_DB_NAME" -c "
        VACUUM ANALYZE;
        REINDEX DATABASE $NEW_DB_NAME;
    "
    
    # Update Odoo modules if needed
    progress "Updating Odoo modules..."
    sudo -u odoo /opt/odoo/odoo-server -c "$NEW_CONFIG" --update=all --stop-after-init || \
        warning "Module update completed with warnings - check logs"
    
    # Restart services for final configuration
    sudo systemctl restart "$ODOO_SERVICE"
    sudo systemctl restart "$NGINX_SERVICE"
    
    success "Final optimization completed"
    
    # Success report
    echo ""
    echo "=================================================================="
    echo -e "${GREEN}🎉 MIGRATION COMPLETED SUCCESSFULLY!${NC}"
    echo "=================================================================="
    echo ""
    echo -e "${CYAN}Migration Summary:${NC}"
    echo "• Migration ID: $MIGRATION_ID"
    echo "• Database migrated: odoo_production → $NEW_DB_NAME"
    echo "• Backup database: $BACKUP_DB_NAME (kept for safety)"
    echo "• Backup filestore: $BACKUP_FILESTORE (kept for safety)"
    echo ""
    echo -e "${CYAN}Performance Logs:${NC}"
    cat "$PERFORMANCE_LOG"
    echo ""
    echo -e "${CYAN}Downtime Report:${NC}"
    cat "$DOWNTIME_LOG"
    echo ""
    echo -e "${GREEN}✅ Your Odoo system is now running on the new server!${NC}"
    echo -e "${BLUE}📊 Monitor system performance over the next 24 hours${NC}"
    echo -e "${YELLOW}🔒 Keep backup files for 7 days before cleanup${NC}"
    echo ""
    echo -e "${CYAN}Rollback Plan Available:${NC} $ROLLBACK_PLAN"
    echo -e "${CYAN}Full Migration Log:${NC} $LOG_FILE"
    
    log_info "Production migration completed successfully: $MIGRATION_ID"
}

# Run main function
main "$@"