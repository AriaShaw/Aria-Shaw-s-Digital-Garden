#!/bin/bash
# Automated Migration Risk Assessment Script
# Run this on your current server to assess migration complexity and risks
#
# Usage: ./migration_assessment.sh your_database_name

if [ $# -eq 0 ]; then
    echo "Usage: $0 <database_name>"
    echo "Example: $0 odoo_production"
    exit 1
fi

DB_NAME="$1"

echo "=== Odoo Migration Risk Assessment Starting ==="
echo "Generated on: $(date)"
echo ""

# Check database size
echo "📊 DATABASE SIZE ANALYSIS"
echo "------------------------"
DB_SIZE=$(sudo -u postgres psql -d $DB_NAME -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" -t | xargs)
echo "Database Size: $DB_SIZE"

# Count total records
RECORD_COUNT=$(sudo -u postgres psql -d $DB_NAME -c "SELECT COUNT(*) FROM res_partner;" -t | xargs)
echo "Total Partners: $RECORD_COUNT"

# Check PostgreSQL version
PG_VERSION=$(sudo -u postgres psql -c "SHOW server_version;" -t | xargs)
echo "PostgreSQL Version: $PG_VERSION"

# Check Odoo version
ODOO_VERSION=$(grep "version" /opt/odoo/odoo.py 2>/dev/null || echo "Version file not found")
echo "Current Odoo Version: $ODOO_VERSION"

echo ""
echo "🔍 CUSTOM MODULE ANALYSIS"
echo "-------------------------"
if [ -d "/opt/odoo/custom-addons" ]; then
    echo "Custom modules found:"
    ls -la /opt/odoo/custom-addons/ | grep "^d" | awk '{print $9}' | grep -v "^\.$\|^\.\.$"
else
    echo "No custom addon directory found at /opt/odoo/custom-addons"
fi

echo ""
echo "⚠️  RISK ASSESSMENT"
echo "-------------------"

# Database size risk
DB_SIZE_NUM=$(echo $DB_SIZE | grep -o '[0-9]*')
if [ "$DB_SIZE_NUM" -gt 10 ]; then
    echo "❌ HIGH RISK: Large database (>10GB) - Migration will take 2+ hours"
elif [ "$DB_SIZE_NUM" -gt 1 ]; then
    echo "⚠️  MEDIUM RISK: Medium database (1-10GB) - Migration will take 30-120 minutes"
else
    echo "✅ LOW RISK: Small database (<1GB) - Migration should take <30 minutes"
fi

echo ""
echo "🎯 RECOMMENDED MIGRATION WINDOW"
echo "------------------------------"
echo "Based on your database size, plan for:"
echo "- Testing phase: 2-4 hours"
echo "- Production migration: [Time will be calculated based on your specific setup]"
echo "- Buffer time: Add 50% to all estimates"

echo ""
echo "=== Assessment Complete ==="