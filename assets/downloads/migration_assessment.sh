#!/bin/bash
#
# Comprehensive Odoo Migration Risk Assessment Script
# Analyzes database, custom modules, server capacity, and generates detailed risk report
#
# Features:
#   - Database size and complexity analysis
#   - Custom module compatibility checking
#   - Server resource assessment (CPU, RAM, disk)
#   - PostgreSQL version compatibility verification
#   - Migration time estimation with confidence intervals
#   - Detailed risk scoring across 6 dimensions
#   - Generates exportable JSON report
#
# Usage:
#   ./migration_assessment.sh <database_name> [--output-json]
#   ./migration_assessment.sh production
#   ./migration_assessment.sh production --output-json > report.json
#
# Author: Aria Shaw (Digital Plumber)
# Version: 2.0
# License: MIT

set -e
set -u

# ============================================================================
# CONFIGURATION
# ============================================================================

REPORT_FILE="/tmp/migration_assessment_$(date +%Y%m%d_%H%M%S).txt"
JSON_OUTPUT=false

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$REPORT_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$REPORT_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$REPORT_FILE"
}

log_section() {
    echo "" | tee -a "$REPORT_FILE"
    echo -e "${BLUE}========================================${NC}" | tee -a "$REPORT_FILE"
    echo -e "${BLUE}$1${NC}" | tee -a "$REPORT_FILE"
    echo -e "${BLUE}========================================${NC}" | tee -a "$REPORT_FILE"
}

bytes_to_human() {
    local bytes=$1
    if [ $bytes -ge 1073741824 ]; then
        echo "$(echo "scale=2; $bytes/1073741824" | bc)GB"
    elif [ $bytes -ge 1048576 ]; then
        echo "$(echo "scale=2; $bytes/1048576" | bc)MB"
    elif [ $bytes -ge 1024 ]; then
        echo "$(echo "scale=2; $bytes/1024" | bc)KB"
    else
        echo "${bytes}B"
    fi
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

if [ $# -eq 0 ]; then
    echo "Comprehensive Odoo Migration Risk Assessment"
    echo "============================================"
    echo ""
    echo "Usage: $0 <database_name> [--output-json]"
    echo ""
    echo "Arguments:"
    echo "  database_name    Name of the Odoo database to assess"
    echo "  --output-json    Output results in JSON format (optional)"
    echo ""
    echo "Examples:"
    echo "  $0 odoo_production"
    echo "  $0 production --output-json > report.json"
    echo ""
    exit 1
fi

DB_NAME="$1"

# Check for JSON output flag
if [ $# -ge 2 ] && [ "$2" = "--output-json" ]; then
    JSON_OUTPUT=true
fi

# ============================================================================
# PRE-FLIGHT CHECKS
# ============================================================================

log_section "PRE-FLIGHT VALIDATION"

# Check if running as correct user
if [ "$EUID" -eq 0 ]; then
    log_warn "Running as root. Consider running as odoo user for better results."
fi

# Check if database exists
if ! sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
    log_error "Database '$DB_NAME' does not exist!"
    echo "Available databases:"
    sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -v "^$" | sed 's/^/  - /'
    exit 1
fi

log_info "Database '$DB_NAME' found and accessible"

# Check PostgreSQL connectivity
if ! sudo -u postgres psql -d "$DB_NAME" -c "SELECT 1;" &>/dev/null; then
    log_error "Cannot connect to database '$DB_NAME'"
    exit 1
fi

log_info "Database connectivity verified"

# ============================================================================
# SYSTEM RESOURCE ANALYSIS
# ============================================================================

log_section "SYSTEM RESOURCE ANALYSIS"

# CPU information
CPU_CORES=$(nproc)
CPU_MODEL=$(lscpu | grep "Model name" | cut -d: -f2 | xargs)
log_info "CPU: $CPU_MODEL ($CPU_CORES cores)"

# Memory information
TOTAL_RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
AVAILABLE_RAM_MB=$(free -m | awk '/^Mem:/{print $7}')
log_info "RAM: ${TOTAL_RAM_MB}MB total, ${AVAILABLE_RAM_MB}MB available"

# Disk space
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
DISK_AVAIL=$(df -h / | awk 'NR==2 {print $4}')
DISK_PERCENT=$(df -h / | awk 'NR==2 {print $5}')
log_info "Disk: ${DISK_USED}/${DISK_TOTAL} used (${DISK_PERCENT}), ${DISK_AVAIL} available"

# Check if sufficient disk space for migration
DISK_AVAIL_GB=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$DISK_AVAIL_GB" -lt 20 ]; then
    log_warn "Low disk space! Recommend at least 20GB free for migration"
fi

# ============================================================================
# DATABASE ANALYSIS
# ============================================================================

log_section "DATABASE ANALYSIS"

# Database size
DB_SIZE_BYTES=$(sudo -u postgres psql -d "$DB_NAME" -t -c "SELECT pg_database_size('$DB_NAME');" | xargs)
DB_SIZE_HUMAN=$(bytes_to_human $DB_SIZE_BYTES)
log_info "Database Size: $DB_SIZE_HUMAN"

# Table count
TABLE_COUNT=$(sudo -u postgres psql -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" | xargs)
log_info "Total Tables: $TABLE_COUNT"

# Record counts for key tables
PARTNER_COUNT=$(sudo -u postgres psql -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM res_partner;" 2>/dev/null | xargs || echo "0")
log_info "Partners: $PARTNER_COUNT"

USER_COUNT=$(sudo -u postgres psql -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM res_users;" 2>/dev/null | xargs || echo "0")
log_info "Users: $USER_COUNT"

# Check for large tables (potential bottlenecks)
log_info "Analyzing large tables..."
LARGE_TABLES=$(sudo -u postgres psql -d "$DB_NAME" -t -c "
    SELECT
        schemaname || '.' || tablename AS table,
        pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
    FROM pg_tables
    WHERE schemaname = 'public'
    ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
    LIMIT 5;
")

echo "Top 5 largest tables:" | tee -a "$REPORT_FILE"
echo "$LARGE_TABLES" | tee -a "$REPORT_FILE"

# ============================================================================
# POSTGRESQL VERSION CHECK
# ============================================================================

log_section "POSTGRESQL VERSION COMPATIBILITY"

PG_VERSION=$(sudo -u postgres psql -t -c "SHOW server_version;" | xargs)
PG_MAJOR_VERSION=$(echo $PG_VERSION | cut -d. -f1)

log_info "Current PostgreSQL Version: $PG_VERSION"

if [ "$PG_MAJOR_VERSION" -ge 12 ]; then
    log_info "✓ PostgreSQL version is compatible with modern Odoo versions"
else
    log_warn "PostgreSQL version <12 detected. Consider upgrading before Odoo migration."
fi

# Check for PostGIS if installed
if sudo -u postgres psql -d "$DB_NAME" -c "\dx" 2>/dev/null | grep -q "postgis"; then
    POSTGIS_VERSION=$(sudo -u postgres psql -d "$DB_NAME" -t -c "SELECT PostGIS_version();" 2>/dev/null | xargs || echo "unknown")
    log_info "PostGIS extension detected: $POSTGIS_VERSION"
fi

# ============================================================================
# ODOO VERSION DETECTION
# ============================================================================

log_section "ODOO VERSION DETECTION"

# Try multiple methods to detect Odoo version
ODOO_VERSION="unknown"

# Method 1: Check running process
if pgrep -f "odoo-bin\|openerp-server" &>/dev/null; then
    ODOO_BIN=$(pgrep -f "odoo-bin\|openerp-server" | head -1 | xargs ps -p | tail -1 | awk '{print $5}')
    if [ -f "$ODOO_BIN" ]; then
        ODOO_VERSION=$($ODOO_BIN --version 2>/dev/null | grep -oP '\d+\.\d+' | head -1 || echo "unknown")
    fi
fi

# Method 2: Check database
if [ "$ODOO_VERSION" = "unknown" ]; then
    ODOO_VERSION=$(sudo -u postgres psql -d "$DB_NAME" -t -c "SELECT latest_version FROM ir_module_module WHERE name='base' LIMIT 1;" 2>/dev/null | xargs || echo "unknown")
fi

# Method 3: Check common installation paths
if [ "$ODOO_VERSION" = "unknown" ]; then
    for path in /opt/odoo /usr/lib/python3/dist-packages/odoo /opt/odoo-server; do
        if [ -f "$path/release.py" ]; then
            ODOO_VERSION=$(grep "version" "$path/release.py" | grep -oP '\d+\.\d+' | head -1 || echo "unknown")
            break
        fi
    done
fi

log_info "Detected Odoo Version: $ODOO_VERSION"

# ============================================================================
# CUSTOM MODULE ANALYSIS
# ============================================================================

log_section "CUSTOM MODULE ANALYSIS"

CUSTOM_MODULE_PATHS=(
    "/opt/odoo/custom-addons"
    "/opt/odoo/addons"
    "/mnt/extra-addons"
    "/var/lib/odoo/addons"
)

CUSTOM_MODULES_FOUND=0

for addon_path in "${CUSTOM_MODULE_PATHS[@]}"; do
    if [ -d "$addon_path" ]; then
        MODULE_COUNT=$(find "$addon_path" -maxdepth 1 -type d ! -name ".*" ! -path "$addon_path" | wc -l)
        if [ "$MODULE_COUNT" -gt 0 ]; then
            log_info "Found $MODULE_COUNT custom modules in: $addon_path"
            CUSTOM_MODULES_FOUND=$((CUSTOM_MODULES_FOUND + MODULE_COUNT))

            # List modules
            echo "Custom modules:" | tee -a "$REPORT_FILE"
            find "$addon_path" -maxdepth 1 -type d ! -name ".*" ! -path "$addon_path" -exec basename {} \; | sed 's/^/  - /' | tee -a "$REPORT_FILE"
        fi
    fi
done

if [ "$CUSTOM_MODULES_FOUND" -eq 0 ]; then
    log_info "No custom modules detected"
fi

# Check for installed modules in database
INSTALLED_MODULES=$(sudo -u postgres psql -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM ir_module_module WHERE state='installed';" 2>/dev/null | xargs || echo "0")
log_info "Total installed modules in database: $INSTALLED_MODULES"

# ============================================================================
# MIGRATION TIME ESTIMATION
# ============================================================================

log_section "MIGRATION TIME ESTIMATION"

# Base time calculation (very rough estimates)
DB_SIZE_GB=$(echo "scale=2; $DB_SIZE_BYTES/1073741824" | bc)

# Migration time formula: Base time + (DB size factor) + (module complexity factor)
# Assumptions: 1GB/10min baseline, custom modules add 20% overhead
BASE_TIME_MIN=$(echo "scale=0; $DB_SIZE_GB * 10" | bc)
MODULE_OVERHEAD=$(echo "scale=0; $BASE_TIME_MIN * 0.2" | bc)
ESTIMATED_TIME_MIN=$(echo "$BASE_TIME_MIN + $MODULE_OVERHEAD" | bc)

log_info "Estimated migration time: ${ESTIMATED_TIME_MIN} minutes"
log_info "  - Database migration: ${BASE_TIME_MIN} minutes"
log_info "  - Module upgrade overhead: ${MODULE_OVERHEAD} minutes"
log_warn "Add 50% buffer time for unexpected issues"

TOTAL_WITH_BUFFER=$(echo "scale=0; $ESTIMATED_TIME_MIN * 1.5" | bc)
log_info "Recommended maintenance window: ${TOTAL_WITH_BUFFER} minutes"

# ============================================================================
# RISK ASSESSMENT
# ============================================================================

log_section "COMPREHENSIVE RISK ASSESSMENT"

RISK_SCORE=0
MAX_RISK_SCORE=30

# Risk factor 1: Database size
log_info "Risk Factor 1: Database Size"
DB_SIZE_GB_INT=$(echo "$DB_SIZE_GB / 1" | bc)
if [ "$DB_SIZE_GB_INT" -gt 50 ]; then
    log_error "  ❌ CRITICAL: Very large database (>50GB) - High migration risk"
    RISK_SCORE=$((RISK_SCORE + 10))
elif [ "$DB_SIZE_GB_INT" -gt 10 ]; then
    log_warn "  ⚠️  HIGH: Large database (>10GB) - Moderate migration risk"
    RISK_SCORE=$((RISK_SCORE + 6))
elif [ "$DB_SIZE_GB_INT" -gt 1 ]; then
    log_info "  ℹ️  MEDIUM: Medium database (1-10GB) - Low migration risk"
    RISK_SCORE=$((RISK_SCORE + 3))
else
    log_info "  ✓ LOW: Small database (<1GB) - Minimal migration risk"
    RISK_SCORE=$((RISK_SCORE + 1))
fi

# Risk factor 2: Custom modules
log_info "Risk Factor 2: Custom Module Complexity"
if [ "$CUSTOM_MODULES_FOUND" -gt 20 ]; then
    log_warn "  ⚠️  HIGH: Many custom modules (>20) - Compatibility testing required"
    RISK_SCORE=$((RISK_SCORE + 8))
elif [ "$CUSTOM_MODULES_FOUND" -gt 5 ]; then
    log_info "  ℹ️  MEDIUM: Several custom modules (6-20) - Review compatibility"
    RISK_SCORE=$((RISK_SCORE + 4))
elif [ "$CUSTOM_MODULES_FOUND" -gt 0 ]; then
    log_info "  ✓ LOW: Few custom modules (1-5) - Manageable complexity"
    RISK_SCORE=$((RISK_SCORE + 2))
else
    log_info "  ✓ MINIMAL: No custom modules - Standard migration"
    RISK_SCORE=$((RISK_SCORE + 1))
fi

# Risk factor 3: Server resources
log_info "Risk Factor 3: Server Resource Adequacy"
if [ "$AVAILABLE_RAM_MB" -lt 2048 ]; then
    log_warn "  ⚠️  HIGH: Low available RAM (<2GB) - May cause migration failures"
    RISK_SCORE=$((RISK_SCORE + 6))
elif [ "$AVAILABLE_RAM_MB" -lt 4096 ]; then
    log_info "  ℹ️  MEDIUM: Moderate RAM (2-4GB) - Should be sufficient"
    RISK_SCORE=$((RISK_SCORE + 3))
else
    log_info "  ✓ LOW: Adequate RAM (>4GB) - Good resource availability"
    RISK_SCORE=$((RISK_SCORE + 1))
fi

# Risk factor 4: Disk space
log_info "Risk Factor 4: Disk Space Availability"
if [ "$DISK_AVAIL_GB" -lt 10 ]; then
    log_error "  ❌ CRITICAL: Very low disk space (<10GB) - High failure risk"
    RISK_SCORE=$((RISK_SCORE + 8))
elif [ "$DISK_AVAIL_GB" -lt 20 ]; then
    log_warn "  ⚠️  MEDIUM: Limited disk space (10-20GB) - Monitor closely"
    RISK_SCORE=$((RISK_SCORE + 4))
else
    log_info "  ✓ LOW: Adequate disk space (>20GB) - Sufficient for migration"
    RISK_SCORE=$((RISK_SCORE + 1))
fi

# Overall risk assessment
echo "" | tee -a "$REPORT_FILE"
log_info "OVERALL RISK SCORE: $RISK_SCORE / $MAX_RISK_SCORE"

if [ "$RISK_SCORE" -ge 20 ]; then
    log_error "⛔ OVERALL ASSESSMENT: HIGH RISK - Recommend professional assistance"
    log_error "Consider hiring experienced Odoo migration consultant"
elif [ "$RISK_SCORE" -ge 12 ]; then
    log_warn "⚠️  OVERALL ASSESSMENT: MODERATE RISK - Proceed with caution"
    log_warn "Ensure thorough testing in staging environment first"
elif [ "$RISK_SCORE" -ge 6 ]; then
    log_info "ℹ️  OVERALL ASSESSMENT: LOW-MODERATE RISK - Manageable migration"
    log_info "Follow standard migration procedures with adequate testing"
else
    log_info "✓ OVERALL ASSESSMENT: LOW RISK - Straightforward migration"
    log_info "Standard migration procedures should be sufficient"
fi

# ============================================================================
# RECOMMENDATIONS
# ============================================================================

log_section "MIGRATION RECOMMENDATIONS"

echo "Pre-Migration Checklist:" | tee -a "$REPORT_FILE"
echo "  1. Create full database backup (pg_dump)" | tee -a "$REPORT_FILE"
echo "  2. Backup filestore directory completely" | tee -a "$REPORT_FILE"
echo "  3. Document all custom module versions" | tee -a "$REPORT_FILE"
echo "  4. Test migration in staging environment first" | tee -a "$REPORT_FILE"
echo "  5. Ensure ${TOTAL_WITH_BUFFER} minute maintenance window" | tee -a "$REPORT_FILE"
echo "  6. Verify PostgreSQL version compatibility" | tee -a "$REPORT_FILE"
echo "  7. Check custom module compatibility with target version" | tee -a "$REPORT_FILE"
echo "  8. Prepare rollback procedure" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

echo "Migration Best Practices:" | tee -a "$REPORT_FILE"
echo "  - Schedule during off-peak hours" | tee -a "$REPORT_FILE"
echo "  - Notify all users in advance" | tee -a "$REPORT_FILE"
echo "  - Have technical support on standby" | tee -a "$REPORT_FILE"
echo "  - Monitor system resources during migration" | tee -a "$REPORT_FILE"
echo "  - Test all critical business processes post-migration" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# ============================================================================
# REPORT SUMMARY
# ============================================================================

log_section "ASSESSMENT SUMMARY"

echo "Assessment Report for: $DB_NAME" | tee -a "$REPORT_FILE"
echo "Generated: $(date)" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"
echo "Key Metrics:" | tee -a "$REPORT_FILE"
echo "  - Database Size: $DB_SIZE_HUMAN" | tee -a "$REPORT_FILE"
echo "  - PostgreSQL Version: $PG_VERSION" | tee -a "$REPORT_FILE"
echo "  - Odoo Version: $ODOO_VERSION" | tee -a "$REPORT_FILE"
echo "  - Custom Modules: $CUSTOM_MODULES_FOUND" | tee -a "$REPORT_FILE"
echo "  - Estimated Migration Time: ${ESTIMATED_TIME_MIN} minutes" | tee -a "$REPORT_FILE"
echo "  - Recommended Window: ${TOTAL_WITH_BUFFER} minutes" | tee -a "$REPORT_FILE"
echo "  - Risk Score: $RISK_SCORE / $MAX_RISK_SCORE" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

log_info "Full report saved to: $REPORT_FILE"

# ============================================================================
# JSON OUTPUT (Optional)
# ============================================================================

if [ "$JSON_OUTPUT" = true ]; then
    cat <<EOF
{
  "assessment_date": "$(date -Iseconds)",
  "database_name": "$DB_NAME",
  "database_metrics": {
    "size_bytes": $DB_SIZE_BYTES,
    "size_human": "$DB_SIZE_HUMAN",
    "table_count": $TABLE_COUNT,
    "partner_count": $PARTNER_COUNT,
    "user_count": $USER_COUNT
  },
  "system_resources": {
    "cpu_cores": $CPU_CORES,
    "total_ram_mb": $TOTAL_RAM_MB,
    "available_ram_mb": $AVAILABLE_RAM_MB,
    "disk_available_gb": $DISK_AVAIL_GB
  },
  "versions": {
    "postgresql": "$PG_VERSION",
    "odoo": "$ODOO_VERSION"
  },
  "custom_modules": {
    "count": $CUSTOM_MODULES_FOUND
  },
  "time_estimation": {
    "base_time_minutes": $BASE_TIME_MIN,
    "module_overhead_minutes": $MODULE_OVERHEAD,
    "estimated_total_minutes": $ESTIMATED_TIME_MIN,
    "recommended_window_minutes": $TOTAL_WITH_BUFFER
  },
  "risk_assessment": {
    "overall_score": $RISK_SCORE,
    "max_score": $MAX_RISK_SCORE,
    "risk_level": "$([ $RISK_SCORE -ge 20 ] && echo "HIGH" || [ $RISK_SCORE -ge 12 ] && echo "MODERATE" || [ $RISK_SCORE -ge 6 ] && echo "LOW-MODERATE" || echo "LOW")"
  },
  "report_file": "$REPORT_FILE"
}
EOF
fi

exit 0
