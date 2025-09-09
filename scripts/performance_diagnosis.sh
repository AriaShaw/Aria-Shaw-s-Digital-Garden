#!/bin/bash
# Odoo Performance Diagnosis Script
# Quick performance issue identification and resolution

set -e

# Configuration
DB_NAME="odoo_production_new"
LOG_FILE="/tmp/performance_diagnosis_$(date +%Y%m%d_%H%M%S).log"
REPORT_FILE="/tmp/performance_report_$(date +%Y%m%d_%H%M%S).txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

echo -e "${BLUE}🔍 Odoo Performance Diagnosis Tool${NC}"
echo "===================================="
echo ""

log "Starting performance diagnosis..."

# Initialize report
cat > "$REPORT_FILE" << EOF
Odoo Performance Diagnosis Report
=================================
Generated: $(date)
Server: $(hostname)
Database: $DB_NAME

EOF

# 1. System Resource Check
echo -e "${BLUE}📊 System Resources${NC}"
echo "==================="

# CPU Analysis
CPU_CORES=$(nproc)
LOAD_AVERAGE=$(uptime | awk '{print $NF}')
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')

echo "CPU Cores: $CPU_CORES"
echo "Load Average: $LOAD_AVERAGE"
echo "Current CPU Usage: ${CPU_USAGE}%"

if (( $(echo "$LOAD_AVERAGE > $CPU_CORES" | bc -l) )); then
    echo -e "${RED}⚠️ High CPU load detected${NC}"
    echo "High CPU Load: $LOAD_AVERAGE (cores: $CPU_CORES)" >> "$REPORT_FILE"
else
    echo -e "${GREEN}✅ CPU load is normal${NC}"
fi

# Memory Analysis
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
USED_MEM=$(free -m | awk '/^Mem:/{print $3}')
MEM_PERCENTAGE=$(echo "scale=1; $USED_MEM * 100 / $TOTAL_MEM" | bc)

echo "Memory: ${USED_MEM}MB / ${TOTAL_MEM}MB (${MEM_PERCENTAGE}%)"

if (( $(echo "$MEM_PERCENTAGE > 90" | bc -l) )); then
    echo -e "${RED}⚠️ High memory usage detected${NC}"
    echo "High Memory Usage: ${MEM_PERCENTAGE}%" >> "$REPORT_FILE"
elif (( $(echo "$MEM_PERCENTAGE > 80" | bc -l) )); then
    echo -e "${YELLOW}⚠️ Memory usage is elevated${NC}"
    echo "Elevated Memory Usage: ${MEM_PERCENTAGE}%" >> "$REPORT_FILE"
else
    echo -e "${GREEN}✅ Memory usage is normal${NC}"
fi

# Disk I/O Analysis
DISK_USAGE=$(df /opt | awk 'NR==2{print $5}' | sed 's/%//')
echo "Disk Usage: ${DISK_USAGE}%"

if [[ $DISK_USAGE -gt 90 ]]; then
    echo -e "${RED}⚠️ Critical disk usage${NC}"
    echo "Critical Disk Usage: ${DISK_USAGE}%" >> "$REPORT_FILE"
elif [[ $DISK_USAGE -gt 80 ]]; then
    echo -e "${YELLOW}⚠️ High disk usage${NC}"
    echo "High Disk Usage: ${DISK_USAGE}%" >> "$REPORT_FILE"
else
    echo -e "${GREEN}✅ Disk usage is normal${NC}"
fi

echo ""

# 2. Database Performance Analysis
echo -e "${BLUE}🐘 Database Performance${NC}"
echo "======================="

# Connection count
ACTIVE_CONNECTIONS=$(sudo -u postgres psql -t -c "SELECT count(*) FROM pg_stat_activity WHERE datname='$DB_NAME';" | xargs)
MAX_CONNECTIONS=$(sudo -u postgres psql -t -c "SHOW max_connections;" | xargs)
CONNECTION_PERCENTAGE=$(echo "scale=1; $ACTIVE_CONNECTIONS * 100 / $MAX_CONNECTIONS" | bc)

echo "Database Connections: $ACTIVE_CONNECTIONS / $MAX_CONNECTIONS (${CONNECTION_PERCENTAGE}%)"

if (( $(echo "$CONNECTION_PERCENTAGE > 80" | bc -l) )); then
    echo -e "${RED}⚠️ High connection usage${NC}"
    echo "High DB Connection Usage: ${CONNECTION_PERCENTAGE}%" >> "$REPORT_FILE"
else
    echo -e "${GREEN}✅ Connection usage is normal${NC}"
fi

# Cache hit ratio
CACHE_HIT_RATIO=$(sudo -u postgres psql -d "$DB_NAME" -t -c "
SELECT round(100.0 * sum(blks_hit) / (sum(blks_hit) + sum(blks_read)), 2) 
FROM pg_stat_database WHERE datname='$DB_NAME';" | xargs)

echo "Cache Hit Ratio: ${CACHE_HIT_RATIO}%"

if (( $(echo "$CACHE_HIT_RATIO < 90" | bc -l) )); then
    echo -e "${RED}⚠️ Low cache hit ratio${NC}"
    echo "Low Cache Hit Ratio: ${CACHE_HIT_RATIO}%" >> "$REPORT_FILE"
elif (( $(echo "$CACHE_HIT_RATIO < 95" | bc -l) )); then
    echo -e "${YELLOW}⚠️ Cache hit ratio could be improved${NC}"
    echo "Suboptimal Cache Hit Ratio: ${CACHE_HIT_RATIO}%" >> "$REPORT_FILE"
else
    echo -e "${GREEN}✅ Excellent cache performance${NC}"
fi

# Database size and growth
DB_SIZE=$(sudo -u postgres psql -d "$DB_NAME" -t -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" | xargs)
echo "Database Size: $DB_SIZE"

# Long running queries
LONG_QUERIES=$(sudo -u postgres psql -t -c "
SELECT count(*) FROM pg_stat_activity 
WHERE datname='$DB_NAME' 
AND state='active' 
AND now() - query_start > interval '30 seconds';" | xargs)

echo "Long Running Queries (>30s): $LONG_QUERIES"

if [[ $LONG_QUERIES -gt 0 ]]; then
    echo -e "${YELLOW}⚠️ Found $LONG_QUERIES long-running queries${NC}"
    echo "Long Running Queries: $LONG_QUERIES" >> "$REPORT_FILE"
    
    # Show details of long queries
    sudo -u postgres psql -c "
    SELECT pid, now() - query_start as duration, left(query, 50) as query_preview
    FROM pg_stat_activity 
    WHERE datname='$DB_NAME' 
    AND state='active' 
    AND now() - query_start > interval '30 seconds'
    ORDER BY query_start;" >> "$REPORT_FILE"
fi

echo ""

# 3. Odoo Service Analysis
echo -e "${BLUE}🚀 Odoo Service Analysis${NC}"
echo "========================"

# Check if Odoo is running
if systemctl is-active --quiet odoo; then
    echo -e "${GREEN}✅ Odoo service is running${NC}"
    
    # Check Odoo processes
    ODOO_PROCESSES=$(pgrep -f odoo-server | wc -l)
    echo "Odoo Worker Processes: $ODOO_PROCESSES"
    
    # Get worker configuration
    CONFIGURED_WORKERS=$(grep "^workers" /etc/odoo/odoo.conf | cut -d'=' -f2 | xargs)
    echo "Configured Workers: ${CONFIGURED_WORKERS:-1}"
    
    # Calculate optimal workers
    OPTIMAL_WORKERS=$((CPU_CORES * 2 + 1))
    echo "Recommended Workers: $OPTIMAL_WORKERS (for $CPU_CORES CPU cores)"
    
    if [[ -n "$CONFIGURED_WORKERS" ]] && [[ $CONFIGURED_WORKERS -lt $OPTIMAL_WORKERS ]]; then
        echo -e "${YELLOW}⚠️ Consider increasing worker count${NC}"
        echo "Suboptimal Worker Configuration: $CONFIGURED_WORKERS (recommended: $OPTIMAL_WORKERS)" >> "$REPORT_FILE"
    fi
else
    echo -e "${RED}❌ Odoo service is not running${NC}"
    echo "Odoo Service Down" >> "$REPORT_FILE"
fi

# Check response time
echo "Testing web response time..."
RESPONSE_TIME=$(curl -s -w "%{time_total}" -o /dev/null http://localhost:8069/web/database/selector)
echo "Web Response Time: ${RESPONSE_TIME}s"

if (( $(echo "$RESPONSE_TIME > 3.0" | bc -l) )); then
    echo -e "${RED}⚠️ Slow web response time${NC}"
    echo "Slow Web Response: ${RESPONSE_TIME}s" >> "$REPORT_FILE"
elif (( $(echo "$RESPONSE_TIME > 1.0" | bc -l) )); then
    echo -e "${YELLOW}⚠️ Response time could be improved${NC}"
    echo "Suboptimal Web Response: ${RESPONSE_TIME}s" >> "$REPORT_FILE"
else
    echo -e "${GREEN}✅ Good response time${NC}"
fi

echo ""

# 4. Generate Recommendations
echo -e "${BLUE}🎯 Performance Recommendations${NC}"
echo "==============================="

cat >> "$REPORT_FILE" << EOF

PERFORMANCE RECOMMENDATIONS:
============================

EOF

# Analyze and provide specific recommendations
if (( $(echo "$MEM_PERCENTAGE > 90" | bc -l) )); then
    echo -e "${YELLOW}💡 High Memory Usage Solutions:${NC}"
    echo "   • Reduce PostgreSQL shared_buffers if set too high"
    echo "   • Decrease Odoo worker count temporarily"
    echo "   • Consider adding more RAM"
    echo ""
    echo "High Memory Usage Solutions:" >> "$REPORT_FILE"
    echo "- Reduce PostgreSQL shared_buffers" >> "$REPORT_FILE"
    echo "- Decrease Odoo worker count" >> "$REPORT_FILE"
    echo "- Consider RAM upgrade" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
fi

if (( $(echo "$CACHE_HIT_RATIO < 95" | bc -l) )); then
    echo -e "${YELLOW}💡 Database Cache Optimization:${NC}"
    echo "   • Increase PostgreSQL shared_buffers"
    echo "   • Consider increasing effective_cache_size"
    echo "   • Run VACUUM ANALYZE on database"
    echo ""
    echo "Database Cache Optimization:" >> "$REPORT_FILE"
    echo "- Increase shared_buffers in postgresql.conf" >> "$REPORT_FILE"
    echo "- Increase effective_cache_size" >> "$REPORT_FILE"
    echo "- Run VACUUM ANALYZE" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
fi

if [[ -n "$CONFIGURED_WORKERS" ]] && [[ $CONFIGURED_WORKERS -lt $OPTIMAL_WORKERS ]]; then
    echo -e "${YELLOW}💡 Odoo Worker Optimization:${NC}"
    echo "   • Increase workers to $OPTIMAL_WORKERS in /etc/odoo/odoo.conf"
    echo "   • Restart Odoo service after changing worker count"
    echo ""
    echo "Odoo Worker Optimization:" >> "$REPORT_FILE"
    echo "- Set workers = $OPTIMAL_WORKERS in odoo.conf" >> "$REPORT_FILE"
    echo "- Restart odoo service" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
fi

if (( $(echo "$RESPONSE_TIME > 2.0" | bc -l) )); then
    echo -e "${YELLOW}💡 Response Time Improvement:${NC}"
    echo "   • Check for long-running database queries"
    echo "   • Consider enabling Odoo database connection pooling"
    echo "   • Review custom module performance"
    echo ""
    echo "Response Time Improvement:" >> "$REPORT_FILE"
    echo "- Investigate slow queries" >> "$REPORT_FILE"
    echo "- Enable connection pooling" >> "$REPORT_FILE"
    echo "- Review custom modules" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
fi

# Quick fix commands
echo -e "${BLUE}🛠️ Quick Fix Commands${NC}"
echo "===================="
echo ""
echo "Run database maintenance:"
echo "  sudo -u postgres psql -d $DB_NAME -c 'VACUUM ANALYZE;'"
echo ""
echo "Check slow queries:"
echo "  sudo -u postgres psql -d $DB_NAME -c \"SELECT query, calls, total_time FROM pg_stat_statements ORDER BY total_time DESC LIMIT 5;\""
echo ""
echo "Restart Odoo service:"
echo "  sudo systemctl restart odoo"
echo ""

# Final summary
echo -e "${GREEN}📋 Diagnosis Complete${NC}"
echo "===================="
echo "Full report saved to: $REPORT_FILE"
echo "Diagnosis log saved to: $LOG_FILE"
echo ""

log "Performance diagnosis completed"