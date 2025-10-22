#!/bin/bash
# Comprehensive Database Corruption Detector for Odoo
# Usage: ./db_corruption_detector.sh database_name

set -e

DATABASE="$1"
REPORT_FILE="/tmp/db_corruption_report_$(date +%Y%m%d_%H%M%S).txt"

if [ -z "$DATABASE" ]; then
    echo "Usage: $0 database_name"
    exit 1
fi

# Check if database exists
if ! sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$DATABASE"; then
    echo "Error: Database '$DATABASE' does not exist"
    exit 1
fi

echo "=== DATABASE CORRUPTION DETECTION REPORT ===" | tee "$REPORT_FILE"
echo "Database: $DATABASE" | tee -a "$REPORT_FILE"
echo "Started at: $(date)" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

CORRUPTION_ISSUES=0

# Function to log results
log_result() {
    local level="$1"
    local message="$2"
    local icon=""
    
    case $level in
        "OK") icon="✓" ;;
        "WARNING") icon="⚠️ " ;;
        "ERROR") icon="✗" ;;
        "INFO") icon="ℹ️ " ;;
    esac
    
    echo "$icon $message" | tee -a "$REPORT_FILE"
    
    if [ "$level" = "ERROR" ]; then
        CORRUPTION_ISSUES=$((CORRUPTION_ISSUES + 1))
    fi
}

# Test 1: Basic database connectivity
echo "1. Database Connectivity Test" | tee -a "$REPORT_FILE"
echo "=============================" | tee -a "$REPORT_FILE"

if sudo -u postgres psql -d "$DATABASE" -c "SELECT 1;" > /dev/null 2>&1; then
    log_result "OK" "Database is accessible"
else
    log_result "ERROR" "Database is not accessible"
fi
echo "" | tee -a "$REPORT_FILE"

# Test 2: Table integrity checks
echo "2. Table Integrity Checks" | tee -a "$REPORT_FILE"
echo "==========================" | tee -a "$REPORT_FILE"

# Get list of critical Odoo tables
CRITICAL_TABLES=(
    "res_users"
    "res_partner"
    "ir_module_module"
    "ir_model"
    "ir_model_fields"
    "account_move"
    "account_move_line"
    "stock_move"
    "stock_picking"
    "sale_order"
    "purchase_order"
)

for table in "${CRITICAL_TABLES[@]}"; do
    if sudo -u postgres psql -d "$DATABASE" -t -c "SELECT 1 FROM information_schema.tables WHERE table_name='$table';" | grep -q 1; then
        # Check if table is accessible and has data
        count=$(sudo -u postgres psql -d "$DATABASE" -t -c "SELECT COUNT(*) FROM $table;" 2>/dev/null | tr -d ' ')
        if [ $? -eq 0 ]; then
            log_result "OK" "Table $table: $count records"
        else
            log_result "ERROR" "Table $table: Cannot read table"
        fi
    else
        log_result "WARNING" "Table $table: Does not exist"
    fi
done
echo "" | tee -a "$REPORT_FILE"

# Test 3: Foreign key constraint violations
echo "3. Foreign Key Constraint Violations" | tee -a "$REPORT_FILE"
echo "=====================================" | tee -a "$REPORT_FILE"

# Check for orphaned records in critical relationships
ORPHAN_CHECKS="
-- Check orphaned account move lines
SELECT 'account_move_line' as table_name, COUNT(*) as orphaned_count
FROM account_move_line aml
WHERE aml.move_id NOT IN (SELECT id FROM account_move WHERE id IS NOT NULL);

-- Check orphaned res_partner children
SELECT 'res_partner (children)' as table_name, COUNT(*) as orphaned_count
FROM res_partner p
WHERE p.parent_id IS NOT NULL 
AND p.parent_id NOT IN (SELECT id FROM res_partner WHERE id IS NOT NULL);

-- Check orphaned stock moves
SELECT 'stock_move' as table_name, COUNT(*) as orphaned_count
FROM stock_move sm
WHERE sm.picking_id IS NOT NULL
AND sm.picking_id NOT IN (SELECT id FROM stock_picking WHERE id IS NOT NULL);

-- Check orphaned sale order lines
SELECT 'sale_order_line' as table_name, COUNT(*) as orphaned_count
FROM sale_order_line sol
WHERE sol.order_id NOT IN (SELECT id FROM sale_order WHERE id IS NOT NULL);
"

orphan_results=$(sudo -u postgres psql -d "$DATABASE" -t -c "$ORPHAN_CHECKS" 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "$orphan_results" | while IFS='|' read -r table_name orphaned_count; do
        table_name=$(echo "$table_name" | tr -d ' ')
        orphaned_count=$(echo "$orphaned_count" | tr -d ' ')
        
        if [ "$orphaned_count" -gt 0 ]; then
            log_result "ERROR" "Orphaned records in $table_name: $orphaned_count"
        else
            log_result "OK" "No orphaned records in $table_name"
        fi
    done
else
    log_result "WARNING" "Could not check foreign key constraints"
fi
echo "" | tee -a "$REPORT_FILE"

# Test 4: Sequence consistency check
echo "4. Sequence Consistency Check" | tee -a "$REPORT_FILE"
echo "=============================" | tee -a "$REPORT_FILE"

SEQUENCE_CHECKS="
SELECT 
    sequence_name,
    last_value as sequence_value,
    CASE 
        WHEN sequence_name LIKE 'res_partner%' THEN (SELECT COALESCE(MAX(id), 0) FROM res_partner)
        WHEN sequence_name LIKE 'account_move%' THEN (SELECT COALESCE(MAX(id), 0) FROM account_move)
        WHEN sequence_name LIKE 'stock_move%' THEN (SELECT COALESCE(MAX(id), 0) FROM stock_move)
        WHEN sequence_name LIKE 'sale_order%' THEN (SELECT COALESCE(MAX(id), 0) FROM sale_order)
        ELSE 0
    END as table_max_id
FROM information_schema.sequences 
WHERE sequence_name LIKE '%_id_seq'
AND sequence_name IN ('res_partner_id_seq', 'account_move_id_seq', 'stock_move_id_seq', 'sale_order_id_seq')
ORDER BY sequence_name;
"

sequence_results=$(sudo -u postgres psql -d "$DATABASE" -t -c "$SEQUENCE_CHECKS" 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "$sequence_results" | while IFS='|' read -r seq_name seq_value table_max; do
        seq_name=$(echo "$seq_name" | tr -d ' ')
        seq_value=$(echo "$seq_value" | tr -d ' ')
        table_max=$(echo "$table_max" | tr -d ' ')
        
        if [ "$seq_value" -lt "$table_max" ]; then
            log_result "ERROR" "Sequence $seq_name ($seq_value) is behind table max ID ($table_max)"
        else
            log_result "OK" "Sequence $seq_name is consistent"
        fi
    done
else
    log_result "WARNING" "Could not check sequence consistency"
fi
echo "" | tee -a "$REPORT_FILE"

# Test 5: Database statistics and bloat check
echo "5. Database Statistics and Bloat Check" | tee -a "$REPORT_FILE"
echo "=======================================" | tee -a "$REPORT_FILE"

# Check table sizes and potential bloat
TABLE_STATS="
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) as index_size,
    n_tup_ins + n_tup_upd + n_tup_del as total_modifications,
    last_vacuum,
    last_autovacuum
FROM pg_tables pt
LEFT JOIN pg_stat_user_tables psut ON pt.tablename = psut.relname
WHERE schemaname = 'public'
AND pg_total_relation_size(schemaname||'.'||tablename) > 10485760  -- > 10MB
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;
"

table_stats=$(sudo -u postgres psql -d "$DATABASE" -c "$TABLE_STATS" 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "Largest tables:" | tee -a "$REPORT_FILE"
    echo "$table_stats" | tee -a "$REPORT_FILE"
    log_result "INFO" "Table statistics collected successfully"
else
    log_result "WARNING" "Could not collect table statistics"
fi
echo "" | tee -a "$REPORT_FILE"

# Test 6: Index health check
echo "6. Index Health Check" | tee -a "$REPORT_FILE"
echo "=====================" | tee -a "$REPORT_FILE"

# Check for missing or corrupt indexes
INDEX_HEALTH="
-- Check for tables without primary keys
SELECT 'Missing primary key' as issue, tablename as table_name
FROM pg_tables pt
LEFT JOIN pg_constraint pc ON pc.conrelid = (pt.schemaname||'.'||pt.tablename)::regclass AND pc.contype = 'p'
WHERE pt.schemaname = 'public'
AND pc.conname IS NULL
AND pt.tablename IN ('res_users', 'res_partner', 'account_move', 'stock_move')

UNION ALL

-- Check for unused indexes
SELECT 'Unused index' as issue, indexname as table_name
FROM pg_stat_user_indexes 
WHERE idx_tup_read = 0 AND idx_tup_fetch = 0
AND pg_relation_size(indexrelid) > 10485760  -- > 10MB
LIMIT 5;
"

index_results=$(sudo -u postgres psql -d "$DATABASE" -t -c "$INDEX_HEALTH" 2>/dev/null)

if [ $? -eq 0 ]; then
    if [ -n "$index_results" ]; then
        echo "$index_results" | while IFS='|' read -r issue table_name; do
            issue=$(echo "$issue" | tr -d ' ')
            table_name=$(echo "$table_name" | tr -d ' ')
            log_result "WARNING" "$issue: $table_name"
        done
    else
        log_result "OK" "No obvious index issues found"
    fi
else
    log_result "WARNING" "Could not check index health"
fi
echo "" | tee -a "$REPORT_FILE"

# Test 7: Transaction log and deadlock check
echo "7. Transaction Log and Deadlock Check" | tee -a "$REPORT_FILE"
echo "=====================================" | tee -a "$REPORT_FILE"

# Check for long-running transactions
LONG_TRANSACTIONS="
SELECT 
    pid,
    state,
    query_start,
    now() - query_start as duration,
    substring(query, 1, 50) as query_snippet
FROM pg_stat_activity 
WHERE state != 'idle'
AND now() - query_start > interval '5 minutes'
AND datname = '$DATABASE';
"

long_tx=$(sudo -u postgres psql -d "$DATABASE" -t -c "$LONG_TRANSACTIONS" 2>/dev/null)

if [ $? -eq 0 ]; then
    if [ -n "$long_tx" ]; then
        log_result "WARNING" "Found long-running transactions"
        echo "$long_tx" | tee -a "$REPORT_FILE"
    else
        log_result "OK" "No long-running transactions found"
    fi
else
    log_result "WARNING" "Could not check for long-running transactions"
fi
echo "" | tee -a "$REPORT_FILE"

# Test 8: Critical Odoo data validation
echo "8. Critical Odoo Data Validation" | tee -a "$REPORT_FILE"
echo "=================================" | tee -a "$REPORT_FILE"

# Check admin user exists
admin_check=$(sudo -u postgres psql -d "$DATABASE" -t -c "SELECT COUNT(*) FROM res_users WHERE login = 'admin' AND active = true;" 2>/dev/null | tr -d ' ')
if [ "$admin_check" -eq 1 ]; then
    log_result "OK" "Admin user exists and is active"
elif [ "$admin_check" -eq 0 ]; then
    log_result "ERROR" "Admin user not found or inactive"
else
    log_result "WARNING" "Multiple admin users found"
fi

# Check base module is installed
base_module=$(sudo -u postgres psql -d "$DATABASE" -t -c "SELECT state FROM ir_module_module WHERE name = 'base';" 2>/dev/null | tr -d ' ')
if [ "$base_module" = "installed" ]; then
    log_result "OK" "Base module is properly installed"
else
    log_result "ERROR" "Base module is not installed (state: $base_module)"
fi

# Check for duplicate email addresses
duplicate_emails=$(sudo -u postgres psql -d "$DATABASE" -t -c "SELECT COUNT(*) FROM (SELECT email FROM res_partner WHERE email IS NOT NULL GROUP BY email HAVING COUNT(*) > 1) as dup;" 2>/dev/null | tr -d ' ')
if [ "$duplicate_emails" -gt 0 ]; then
    log_result "WARNING" "Found $duplicate_emails duplicate email addresses"
else
    log_result "OK" "No duplicate email addresses found"
fi

echo "" | tee -a "$REPORT_FILE"

# Final summary
echo "CORRUPTION DETECTION SUMMARY" | tee -a "$REPORT_FILE"
echo "============================" | tee -a "$REPORT_FILE"
echo "Completed at: $(date)" | tee -a "$REPORT_FILE"
echo "Report saved to: $REPORT_FILE" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

if [ $CORRUPTION_ISSUES -eq 0 ]; then
    log_result "OK" "No database corruption detected"
    echo "Database appears to be healthy and ready for use." | tee -a "$REPORT_FILE"
elif [ $CORRUPTION_ISSUES -le 3 ]; then
    log_result "WARNING" "$CORRUPTION_ISSUES issues found - manual review recommended"
    echo "Database has minor issues that should be addressed." | tee -a "$REPORT_FILE"
else
    log_result "ERROR" "$CORRUPTION_ISSUES critical issues found - immediate attention required"
    echo "Database has significant corruption issues requiring immediate repair." | tee -a "$REPORT_FILE"
fi

echo "" | tee -a "$REPORT_FILE"
echo "For detailed repair procedures, see the Advanced Troubleshooting Guide." | tee -a "$REPORT_FILE"

# Exit with appropriate code
exit $CORRUPTION_ISSUES