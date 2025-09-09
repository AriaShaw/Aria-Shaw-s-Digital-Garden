#!/bin/bash
# Odoo Data Integrity Check Script
# Comprehensive validation of data consistency and integrity

set -e

# Configuration
DB_NAME="${1:-odoo_production_new}"
REPORT_FILE="/tmp/data_integrity_report_$(date +%Y%m%d_%H%M%S).txt"
LOG_FILE="/tmp/data_integrity_$(date +%Y%m%d_%H%M%S).log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

if [[ -z "$1" ]]; then
    echo "Usage: $0 <database_name>"
    echo "Example: $0 odoo_production_new"
    exit 1
fi

echo -e "${BLUE}🔍 Odoo Data Integrity Check${NC}"
echo "============================"
echo "Database: $DB_NAME"
echo ""

log "Starting data integrity check for database: $DB_NAME"

# Initialize report
cat > "$REPORT_FILE" << EOF
Odoo Data Integrity Check Report
================================
Database: $DB_NAME
Generated: $(date)
Server: $(hostname)

EOF

# Verify database exists
if ! sudo -u postgres psql -lqt | cut -d\| -f1 | grep -qw "$DB_NAME"; then
    echo -e "${RED}❌ Database '$DB_NAME' does not exist${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Database '$DB_NAME' found${NC}"
echo ""

# 1. Basic Database Health
echo -e "${BLUE}📊 Database Health Check${NC}"
echo "========================"

# Check database size
DB_SIZE=$(sudo -u postgres psql -d "$DB_NAME" -t -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" | xargs)
echo "Database Size: $DB_SIZE"

# Check table count
TABLE_COUNT=$(sudo -u postgres psql -d "$DB_NAME" -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';" | xargs)
echo "Total Tables: $TABLE_COUNT"

# Check for corrupted tables
CORRUPTED_TABLES=$(sudo -u postgres psql -d "$DB_NAME" -t -c "
SELECT tablename FROM pg_tables WHERE schemaname='public' 
AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name=tablename);" | grep -v "^$" | wc -l)

echo "Corrupted Tables: $CORRUPTED_TABLES"
if [[ $CORRUPTED_TABLES -gt 0 ]]; then
    echo -e "${RED}⚠️ Found $CORRUPTED_TABLES potentially corrupted tables${NC}"
    echo "Corrupted Tables Found: $CORRUPTED_TABLES" >> "$REPORT_FILE"
else
    echo -e "${GREEN}✅ No corrupted tables detected${NC}"
fi

echo ""

# 2. Core Data Integrity Checks
echo -e "${BLUE}🔍 Core Data Integrity${NC}"
echo "======================"

echo "Running integrity checks..." | tee -a "$REPORT_FILE"

# Check 1: Users and Partners consistency
USER_PARTNER_INCONSISTENCY=$(sudo -u postgres psql -d "$DB_NAME" -t -c "
SELECT COUNT(*) FROM res_users u 
LEFT JOIN res_partner p ON u.partner_id = p.id 
WHERE p.id IS NULL AND u.active = true;" | xargs)

echo "User-Partner Inconsistencies: $USER_PARTNER_INCONSISTENCY"
if [[ $USER_PARTNER_INCONSISTENCY -gt 0 ]]; then
    echo -e "${YELLOW}⚠️ Found $USER_PARTNER_INCONSISTENCY users without partner records${NC}"
    echo "User-Partner Inconsistencies: $USER_PARTNER_INCONSISTENCY" >> "$REPORT_FILE"
else
    echo -e "${GREEN}✅ User-Partner relationships are consistent${NC}"
fi

# Check 2: Company consistency
COMPANY_INCONSISTENCY=$(sudo -u postgres psql -d "$DB_NAME" -t -c "
SELECT COUNT(*) FROM res_users u 
LEFT JOIN res_company c ON u.company_id = c.id 
WHERE c.id IS NULL AND u.active = true;" | xargs)

echo "User-Company Inconsistencies: $COMPANY_INCONSISTENCY"
if [[ $COMPANY_INCONSISTENCY -gt 0 ]]; then
    echo -e "${YELLOW}⚠️ Found $COMPANY_INCONSISTENCY users without company records${NC}"
    echo "User-Company Inconsistencies: $COMPANY_INCONSISTENCY" >> "$REPORT_FILE"
else
    echo -e "${GREEN}✅ User-Company relationships are consistent${NC}"
fi

# Check 3: Module dependencies
BROKEN_DEPENDENCIES=$(sudo -u postgres psql -d "$DB_NAME" -t -c "
SELECT COUNT(*) FROM ir_module_module m1
WHERE m1.state = 'installed' 
AND EXISTS (
    SELECT 1 FROM ir_module_module_dependency d 
    JOIN ir_module_module m2 ON d.module_id = m2.id 
    WHERE d.module_id = m1.id 
    AND m2.state != 'installed'
);" | xargs)

echo "Broken Module Dependencies: $BROKEN_DEPENDENCIES"
if [[ $BROKEN_DEPENDENCIES -gt 0 ]]; then
    echo -e "${YELLOW}⚠️ Found $BROKEN_DEPENDENCIES modules with broken dependencies${NC}"
    echo "Broken Module Dependencies: $BROKEN_DEPENDENCIES" >> "$REPORT_FILE"
else
    echo -e "${GREEN}✅ Module dependencies are consistent${NC}"
fi

echo ""

# 3. Financial Data Integrity
echo -e "${BLUE}💰 Financial Data Integrity${NC}"
echo "==========================="

# Check for orphaned account moves
ORPHANED_MOVES=$(sudo -u postgres psql -d "$DB_NAME" -t -c "
SELECT COUNT(*) FROM account_move am 
LEFT JOIN account_journal aj ON am.journal_id = aj.id 
WHERE aj.id IS NULL;" 2>/dev/null | xargs || echo "0")

echo "Orphaned Account Moves: $ORPHANED_MOVES"
if [[ $ORPHANED_MOVES -gt 0 ]]; then
    echo -e "${YELLOW}⚠️ Found $ORPHANED_MOVES account moves without journals${NC}"
    echo "Orphaned Account Moves: $ORPHANED_MOVES" >> "$REPORT_FILE"
else
    echo -e "${GREEN}✅ Account moves are properly linked${NC}"
fi

# Check account balance consistency
UNBALANCED_MOVES=$(sudo -u postgres psql -d "$DB_NAME" -t -c "
SELECT COUNT(*) FROM (
    SELECT move_id, SUM(debit - credit) as balance 
    FROM account_move_line 
    GROUP BY move_id 
    HAVING ABS(SUM(debit - credit)) > 0.01
) unbalanced;" 2>/dev/null | xargs || echo "0")

echo "Unbalanced Account Moves: $UNBALANCED_MOVES"
if [[ $UNBALANCED_MOVES -gt 0 ]]; then
    echo -e "${RED}⚠️ Found $UNBALANCED_MOVES unbalanced account moves${NC}"
    echo "Unbalanced Account Moves: $UNBALANCED_MOVES" >> "$REPORT_FILE"
else
    echo -e "${GREEN}✅ All account moves are balanced${NC}"
fi

echo ""

# 4. Inventory Data Integrity
echo -e "${BLUE}📦 Inventory Data Integrity${NC}"
echo "==========================="

# Check for products without categories
PRODUCTS_WITHOUT_CATEGORY=$(sudo -u postgres psql -d "$DB_NAME" -t -c "
SELECT COUNT(*) FROM product_template pt 
WHERE pt.categ_id IS NULL;" 2>/dev/null | xargs || echo "0")

echo "Products Without Category: $PRODUCTS_WITHOUT_CATEGORY"
if [[ $PRODUCTS_WITHOUT_CATEGORY -gt 0 ]]; then
    echo -e "${YELLOW}⚠️ Found $PRODUCTS_WITHOUT_CATEGORY products without categories${NC}"
    echo "Products Without Category: $PRODUCTS_WITHOUT_CATEGORY" >> "$REPORT_FILE"
else
    echo -e "${GREEN}✅ All products have categories${NC}"
fi

# Check stock move consistency
INCONSISTENT_STOCK_MOVES=$(sudo -u postgres psql -d "$DB_NAME" -t -c "
SELECT COUNT(*) FROM stock_move sm 
LEFT JOIN product_product pp ON sm.product_id = pp.id 
WHERE pp.id IS NULL;" 2>/dev/null | xargs || echo "0")

echo "Stock Moves with Invalid Products: $INCONSISTENT_STOCK_MOVES"
if [[ $INCONSISTENT_STOCK_MOVES -gt 0 ]]; then
    echo -e "${RED}⚠️ Found $INCONSISTENT_STOCK_MOVES stock moves with invalid products${NC}"
    echo "Invalid Stock Moves: $INCONSISTENT_STOCK_MOVES" >> "$REPORT_FILE"
else
    echo -e "${GREEN}✅ Stock moves are consistent${NC}"
fi

echo ""

# 5. Attachment and File Integrity
echo -e "${BLUE}📁 Attachment Integrity${NC}"
echo "======================="

# Check attachment records
TOTAL_ATTACHMENTS=$(sudo -u postgres psql -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM ir_attachment;" | xargs)
ATTACHMENTS_WITH_FILES=$(sudo -u postgres psql -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM ir_attachment WHERE store_fname IS NOT NULL;" | xargs)

echo "Total Attachments: $TOTAL_ATTACHMENTS"
echo "Attachments with Files: $ATTACHMENTS_WITH_FILES"

# Check for orphaned attachment records (files not on disk)
FILESTORE_DIR="/opt/odoo/filestore"
if [[ -d "$FILESTORE_DIR" ]]; then
    ACTUAL_FILES=$(find "$FILESTORE_DIR" -type f 2>/dev/null | wc -l)
    echo "Files on Disk: $ACTUAL_FILES"
    
    if [[ $ATTACHMENTS_WITH_FILES -gt $ACTUAL_FILES ]]; then
        MISSING_FILES=$((ATTACHMENTS_WITH_FILES - ACTUAL_FILES))
        echo -e "${YELLOW}⚠️ $MISSING_FILES attachment records may have missing files${NC}"
        echo "Missing Files: $MISSING_FILES" >> "$REPORT_FILE"
    else
        echo -e "${GREEN}✅ Attachment file count looks consistent${NC}"
    fi
else
    echo -e "${YELLOW}⚠️ Filestore directory not found at expected location${NC}"
    echo "Filestore Directory Missing" >> "$REPORT_FILE"
fi

echo ""

# 6. Record Count Summary
echo -e "${BLUE}📈 Record Count Summary${NC}"
echo "======================="

# Key record counts
cat >> "$REPORT_FILE" << EOF

RECORD COUNT SUMMARY:
====================
EOF

declare -A CORE_TABLES=(
    ["res_partner"]="Partners/Contacts"
    ["res_users"]="Users"
    ["product_template"]="Products"
    ["sale_order"]="Sales Orders"
    ["account_move"]="Journal Entries"
    ["stock_move"]="Stock Moves"
    ["ir_attachment"]="Attachments"
)

for table in "${!CORE_TABLES[@]}"; do
    if sudo -u postgres psql -d "$DB_NAME" -c "\d $table" >/dev/null 2>&1; then
        COUNT=$(sudo -u postgres psql -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM $table;" | xargs)
        printf "%-20s: %s\n" "${CORE_TABLES[$table]}" "$COUNT"
        printf "%-30s: %s\n" "${CORE_TABLES[$table]}" "$COUNT" >> "$REPORT_FILE"
    else
        printf "%-20s: Table not found\n" "${CORE_TABLES[$table]}"
        printf "%-30s: Table not found\n" "${CORE_TABLES[$table]}" >> "$REPORT_FILE"
    fi
done

echo ""

# 7. Generate Final Assessment
echo -e "${BLUE}📋 Integrity Assessment${NC}"
echo "======================="

# Count issues found
TOTAL_ISSUES=0
CRITICAL_ISSUES=0

if [[ $CORRUPTED_TABLES -gt 0 ]]; then ((TOTAL_ISSUES++)); ((CRITICAL_ISSUES++)); fi
if [[ $UNBALANCED_MOVES -gt 0 ]]; then ((TOTAL_ISSUES++)); ((CRITICAL_ISSUES++)); fi
if [[ $INCONSISTENT_STOCK_MOVES -gt 0 ]]; then ((TOTAL_ISSUES++)); ((CRITICAL_ISSUES++)); fi
if [[ $USER_PARTNER_INCONSISTENCY -gt 0 ]]; then ((TOTAL_ISSUES++)); fi
if [[ $COMPANY_INCONSISTENCY -gt 0 ]]; then ((TOTAL_ISSUES++)); fi
if [[ $BROKEN_DEPENDENCIES -gt 0 ]]; then ((TOTAL_ISSUES++)); fi

cat >> "$REPORT_FILE" << EOF

FINAL ASSESSMENT:
================
Total Issues Found: $TOTAL_ISSUES
Critical Issues: $CRITICAL_ISSUES

EOF

if [[ $CRITICAL_ISSUES -eq 0 ]]; then
    echo -e "${GREEN}🎉 DATA INTEGRITY: EXCELLENT${NC}"
    echo "No critical data integrity issues found."
    echo "Status: EXCELLENT - No critical issues" >> "$REPORT_FILE"
elif [[ $CRITICAL_ISSUES -le 2 ]]; then
    echo -e "${YELLOW}⚠️ DATA INTEGRITY: GOOD WITH WARNINGS${NC}"
    echo "Minor issues found that should be addressed."
    echo "Status: GOOD - Minor issues to resolve" >> "$REPORT_FILE"
else
    echo -e "${RED}❌ DATA INTEGRITY: NEEDS ATTENTION${NC}"
    echo "Critical issues found that require immediate attention."
    echo "Status: NEEDS ATTENTION - Critical issues found" >> "$REPORT_FILE"
fi

echo ""
echo -e "${BLUE}📄 Full Report: $REPORT_FILE${NC}"
echo -e "${BLUE}📄 Detailed Log: $LOG_FILE${NC}"

log "Data integrity check completed for database: $DB_NAME"

# Provide recommendations if issues found
if [[ $TOTAL_ISSUES -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}🛠️ Recommended Actions:${NC}"
    
    if [[ $CORRUPTED_TABLES -gt 0 ]]; then
        echo "• Investigate corrupted tables and restore from backup if necessary"
    fi
    
    if [[ $UNBALANCED_MOVES -gt 0 ]]; then
        echo "• Review and correct unbalanced accounting entries"
    fi
    
    if [[ $USER_PARTNER_INCONSISTENCY -gt 0 ]]; then
        echo "• Fix user-partner relationship inconsistencies"
    fi
    
    if [[ $BROKEN_DEPENDENCIES -gt 0 ]]; then
        echo "• Review and fix module dependency issues"
    fi
    
    echo "• Consider running integrity repair commands"
    echo "• Schedule regular integrity checks"
fi

echo ""