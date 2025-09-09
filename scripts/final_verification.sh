#!/bin/bash
# Final Migration Verification and Go-Live Checklist
# Comprehensive system verification before declaring migration complete

set -euo pipefail

VERIFICATION_REPORT="/tmp/odoo_final_verification_$(date +%Y%m%d_%H%M%S).txt"
CHECKLIST_ITEMS=0
CHECKLIST_PASSED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Verification functions
verify_item() {
    local description="$1"
    local command="$2"
    
    CHECKLIST_ITEMS=$((CHECKLIST_ITEMS + 1))
    
    echo -n "Verifying: $description... "
    
    if eval "$command" &>/dev/null; then
        echo -e "${GREEN}PASS${NC}"
        echo "✅ $description: PASS" >> "$VERIFICATION_REPORT"
        CHECKLIST_PASSED=$((CHECKLIST_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        echo "❌ $description: FAIL" >> "$VERIFICATION_REPORT"
        return 1
    fi
}

# Main verification
main() {
    echo "=================================================================="
    echo -e "${GREEN}🔍 Final Migration Verification${NC}"
    echo "=================================================================="
    echo ""
    
    # Initialize report
    cat > "$VERIFICATION_REPORT" <<EOF
================================================================
Odoo Migration Final Verification Report
Generated: $(date)
================================================================

EOF
    
    echo "Running comprehensive verification checklist..."
    echo ""
    
    # System Service Verification
    echo -e "${BLUE}System Services:${NC}"
    verify_item "Odoo service running" "systemctl is-active odoo --quiet"
    verify_item "PostgreSQL service running" "systemctl is-active postgresql --quiet"
    verify_item "Nginx service running" "systemctl is-active nginx --quiet"
    
    # Database Verification
    echo ""
    echo -e "${BLUE}Database:${NC}"
    verify_item "Database connectivity" "sudo -u postgres psql -d odoo_production_new -c 'SELECT 1' >/dev/null"
    verify_item "All modules loaded" "sudo -u postgres psql -d odoo_production_new -t -c 'SELECT COUNT(*) FROM ir_module_module WHERE state='\''installed'\''' | grep -q '[1-9]'"
    verify_item "No database errors" "! sudo -u postgres psql -d odoo_production_new -c 'SELECT * FROM ir_logging WHERE level='\''ERROR'\'' AND create_date > NOW() - INTERVAL '\''1 hour'\'''; | grep -q '[1-9]'"
    
    # Web Interface Verification
    echo ""
    echo -e "${BLUE}Web Interface:${NC}"
    verify_item "Homepage accessible" "curl -s http://localhost:8069/web/database/selector | grep -q 'database'"
    verify_item "Login page accessible" "curl -s http://localhost:8069/web/login | grep -q 'login'"
    verify_item "Response time acceptable" "test \$(curl -s -w '%{time_total}' -o /dev/null http://localhost:8069/web/database/selector) -lt 3"
    
    # File System Verification
    echo ""
    echo -e "${BLUE}File System:${NC}"
    verify_item "Filestore accessible" "test -d /opt/odoo/filestore && test -r /opt/odoo/filestore"
    verify_item "Filestore permissions correct" "test \$(stat -c '%U:%G' /opt/odoo/filestore) = 'odoo:odoo'"
    verify_item "Configuration file valid" "test -f /etc/odoo/odoo.conf && python3 -c 'import configparser; c=configparser.ConfigParser(); c.read(\"/etc/odoo/odoo.conf\")'"
    
    # Performance Verification
    echo ""
    echo -e "${BLUE}Performance:${NC}"
    verify_item "CPU usage reasonable" "test \$(top -bn1 | grep 'Cpu(s)' | awk '{print \$2}' | sed 's/%us,//' | cut -d'.' -f1) -lt 80"
    verify_item "Memory usage reasonable" "test \$(free | grep '^Mem:' | awk '{printf \"%.0f\", \$3/\$2*100}') -lt 85"
    verify_item "Disk space sufficient" "test \$(df /opt | awk 'NR==2{print \$5}' | sed 's/%//') -lt 80"
    
    # Security Verification
    echo ""
    echo -e "${BLUE}Security:${NC}"
    verify_item "Odoo running as odoo user" "ps aux | grep -v grep | grep odoo-server | grep -q '^odoo'"
    verify_item "No world-writable files" "! find /opt/odoo -type f -perm -002 | grep -q ."
    verify_item "Configuration file protected" "test \$(stat -c '%a' /etc/odoo/odoo.conf) = '640'"
    
    # Generate final report
    echo ""
    echo "=================================================================="
    echo -e "${GREEN}📋 VERIFICATION COMPLETE${NC}"
    echo "=================================================================="
    echo ""
    
    local success_rate=$(echo "scale=1; $CHECKLIST_PASSED * 100 / $CHECKLIST_ITEMS" | bc -l)
    
    echo -e "${CYAN}Results:${NC}"
    echo "• Total checks: $CHECKLIST_ITEMS"
    echo "• Passed: $CHECKLIST_PASSED"
    echo "• Success rate: ${success_rate}%"
    echo ""
    
    # Append summary to report
    cat >> "$VERIFICATION_REPORT" <<EOF

================================================================
VERIFICATION SUMMARY
================================================================

Total Checks: $CHECKLIST_ITEMS
Passed: $CHECKLIST_PASSED
Success Rate: ${success_rate}%

EOF
    
    if [[ $CHECKLIST_PASSED -eq $CHECKLIST_ITEMS ]]; then
        echo -e "${GREEN}🎉 ALL VERIFICATIONS PASSED!${NC}"
        echo -e "${GREEN}✅ Your migration is COMPLETE and SUCCESSFUL!${NC}"
        
        cat >> "$VERIFICATION_REPORT" <<EOF
STATUS: MIGRATION COMPLETE AND SUCCESSFUL
All verification checks passed. System is ready for production use.

NEXT STEPS:
1. Monitor system performance for the next 48 hours
2. Schedule regular backups using the provided scripts
3. Set up monitoring alerts for proactive maintenance
4. Document any custom configurations for future reference

EOF
        
    elif [[ $(echo "$success_rate > 90" | bc -l) -eq 1 ]]; then
        echo -e "${YELLOW}⚠️ Migration mostly successful with minor issues${NC}"
        echo "Review failed checks and address if necessary"
        
        cat >> "$VERIFICATION_REPORT" <<EOF
STATUS: MIGRATION MOSTLY SUCCESSFUL
Minor issues detected that should be addressed for optimal operation.
EOF
        
    else
        echo -e "${RED}❌ Migration has significant issues${NC}"
        echo "Review failed checks and consider rollback if critical"
        
        cat >> "$VERIFICATION_REPORT" <<EOF
STATUS: MIGRATION REQUIRES ATTENTION
Significant issues detected that must be resolved before declaring success.
EOF
    fi
    
    echo ""
    echo -e "${BLUE}📄 Full verification report: $VERIFICATION_REPORT${NC}"
    
    # Final recommendations
    echo ""
    echo -e "${CYAN}🎯 Post-Migration Recommendations:${NC}"
    echo ""
    echo "1. ${GREEN}Monitor for 48 hours${NC}"
    echo "   • Watch system performance and user feedback"
    echo "   • Keep rollback plan available for 7 days"
    echo ""
    echo "2. ${GREEN}Set up maintenance schedule${NC}"
    echo "   • Weekly database maintenance (VACUUM ANALYZE)"
    echo "   • Monthly log rotation and cleanup"
    echo "   • Quarterly performance review"
    echo ""
    echo "3. ${GREEN}Document the new environment${NC}"
    echo "   • Server specifications and configuration"
    echo "   • Backup and restore procedures"
    echo "   • Contact information for support"
    echo ""
    echo "4. ${GREEN}Plan for future upgrades${NC}"
    echo "   • Schedule regular Odoo version updates"
    echo "   • Monitor module compatibility"
    echo "   • Keep system documentation current"
    
    echo ""
    echo -e "${GREEN}🚀 Congratulations! Your Odoo migration is complete!${NC}"
}

main "$@"