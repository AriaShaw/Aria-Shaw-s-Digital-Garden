#!/bin/bash
# Monthly Odoo System Health Check Script
# Comprehensive system analysis and capacity planning

set -e

# Configuration
REPORT_FILE="/tmp/monthly_health_report_$(date +%Y%m%d_%H%M%S).html"
LOG_FILE="/var/log/odoo_monthly_health.log"
DB_NAME="odoo_production_new"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

log "Starting monthly health check..."

# Gather system information
HOSTNAME=$(hostname)
UPTIME=$(uptime -p)
KERNEL=$(uname -r)
DISTRO=$(lsb_release -d | cut -f2)

# Database metrics
DB_SIZE=$(sudo -u postgres psql -d "$DB_NAME" -t -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" | xargs)
DB_SIZE_BYTES=$(sudo -u postgres psql -d "$DB_NAME" -t -c "SELECT pg_database_size('$DB_NAME');" | xargs)
TABLE_COUNT=$(sudo -u postgres psql -d "$DB_NAME" -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';" | xargs)
USER_COUNT=$(sudo -u postgres psql -d "$DB_NAME" -t -c "SELECT count(*) FROM res_users WHERE active = true;" | xargs)

# System resources
CPU_CORES=$(nproc)
TOTAL_MEM_GB=$(free -g | awk '/^Mem:/{print $2}')
USED_MEM_GB=$(free -g | awk '/^Mem:/{print $3}')
TOTAL_DISK_GB=$(df -BG /opt | awk 'NR==2{print $2}' | sed 's/G//')
USED_DISK_GB=$(df -BG /opt | awk 'NR==2{print $3}' | sed 's/G//')
DISK_USAGE_PERCENT=$(df /opt | awk 'NR==2{print $5}' | sed 's/%//')

# Performance metrics
LOAD_AVERAGE=$(uptime | awk '{print $NF}')
CACHE_HIT_RATIO=$(sudo -u postgres psql -d "$DB_NAME" -t -c "
SELECT round(100.0 * sum(blks_hit) / (sum(blks_hit) + sum(blks_read)), 2) 
FROM pg_stat_database WHERE datname='$DB_NAME';" | xargs)

# Growth analysis (compare with data from 30 days ago if available)
GROWTH_FILE="/var/log/odoo_growth_tracking.log"
CURRENT_DATE=$(date +%Y-%m-%d)

# Record current metrics
echo "$CURRENT_DATE,$DB_SIZE_BYTES,$USER_COUNT,$TABLE_COUNT" >> "$GROWTH_FILE"

# Calculate growth if historical data exists
DB_GROWTH_RATE="N/A"
USER_GROWTH_RATE="N/A"

if [[ -f "$GROWTH_FILE" ]] && [[ $(wc -l < "$GROWTH_FILE") -gt 1 ]]; then
    # Get data from 30 days ago (approximately)
    HISTORICAL_DATA=$(tail -30 "$GROWTH_FILE" | head -1)
    if [[ -n "$HISTORICAL_DATA" ]]; then
        HIST_DB_SIZE=$(echo "$HISTORICAL_DATA" | cut -d',' -f2)
        HIST_USER_COUNT=$(echo "$HISTORICAL_DATA" | cut -d',' -f3)
        
        if [[ "$HIST_DB_SIZE" -gt 0 ]]; then
            DB_GROWTH_RATE=$(echo "scale=2; (($DB_SIZE_BYTES - $HIST_DB_SIZE) / $HIST_DB_SIZE) * 100" | bc -l)
        fi
        
        if [[ "$HIST_USER_COUNT" -gt 0 ]]; then
            USER_GROWTH_RATE=$(echo "scale=2; (($USER_COUNT - $HIST_USER_COUNT) / $HIST_USER_COUNT) * 100" | bc -l)
        fi
    fi
fi

# Generate comprehensive HTML report
cat > "$REPORT_FILE" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Monthly Odoo Health Report - $(date '+%B %Y')</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .header { background: #2E7D32; color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .metric-card { background: white; padding: 20px; margin: 10px 0; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .good { border-left: 5px solid #4CAF50; }
        .warning { border-left: 5px solid #FF9800; }
        .critical { border-left: 5px solid #F44336; }
        .metric-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 15px; }
        .metric-value { font-size: 2em; font-weight: bold; color: #2E7D32; }
        .metric-label { color: #666; font-size: 0.9em; }
        .chart-placeholder { height: 200px; background: #e0e0e0; border-radius: 4px; display: flex; align-items: center; justify-content: center; color: #666; margin: 15px 0; }
        .recommendation { background: #e3f2fd; padding: 15px; border-radius: 4px; margin: 10px 0; }
        .status-good { color: #4CAF50; font-weight: bold; }
        .status-warning { color: #FF9800; font-weight: bold; }
        .status-critical { color: #F44336; font-weight: bold; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🏥 Monthly Odoo Health Report</h1>
        <p>Server: $HOSTNAME | Generated: $(date) | Report Period: $(date -d '30 days ago' '+%B %d') - $(date '+%B %d, %Y')</p>
    </div>

    <div class="metric-card good">
        <h2>📊 System Overview</h2>
        <div class="metric-grid">
            <div>
                <div class="metric-value">$UPTIME</div>
                <div class="metric-label">System Uptime</div>
            </div>
            <div>
                <div class="metric-value">$DB_SIZE</div>
                <div class="metric-label">Database Size</div>
            </div>
            <div>
                <div class="metric-value">$USER_COUNT</div>
                <div class="metric-label">Active Users</div>
            </div>
            <div>
                <div class="metric-value">${CACHE_HIT_RATIO}%</div>
                <div class="metric-label">DB Cache Hit Ratio</div>
            </div>
        </div>
    </div>

    <div class="metric-card $([ $DISK_USAGE_PERCENT -gt 80 ] && echo 'warning' || echo 'good')">
        <h2>💾 Resource Utilization</h2>
        <div class="metric-grid">
            <div>
                <div class="metric-value">${USED_MEM_GB}GB / ${TOTAL_MEM_GB}GB</div>
                <div class="metric-label">Memory Usage</div>
            </div>
            <div>
                <div class="metric-value">${USED_DISK_GB}GB / ${TOTAL_DISK_GB}GB</div>
                <div class="metric-label">Disk Usage ($DISK_USAGE_PERCENT%)</div>
            </div>
            <div>
                <div class="metric-value">$LOAD_AVERAGE</div>
                <div class="metric-label">Load Average ($CPU_CORES cores)</div>
            </div>
        </div>
    </div>

    <div class="metric-card good">
        <h2>📈 Growth Analysis</h2>
        <div class="metric-grid">
            <div>
                <div class="metric-value">$DB_GROWTH_RATE%</div>
                <div class="metric-label">Database Growth (30 days)</div>
            </div>
            <div>
                <div class="metric-value">$USER_GROWTH_RATE%</div>
                <div class="metric-label">User Growth (30 days)</div>
            </div>
        </div>
        <div class="chart-placeholder">Database Growth Trend Chart</div>
    </div>

    <div class="metric-card">
        <h2>🔍 Health Status</h2>
EOF

# Add service status
for service in odoo postgresql nginx; do
    if systemctl is-active --quiet $service; then
        echo "        <p>✅ <span class=\"status-good\">$service</span> - Running normally</p>" >> "$REPORT_FILE"
    else
        echo "        <p>❌ <span class=\"status-critical\">$service</span> - Service down</p>" >> "$REPORT_FILE"
    fi
done

# Performance analysis
if (( $(echo "$CACHE_HIT_RATIO < 95" | bc -l) )); then
    echo "        <p>⚠️ <span class=\"status-warning\">Database Cache</span> - Hit ratio below 95% ($CACHE_HIT_RATIO%)</p>" >> "$REPORT_FILE"
else
    echo "        <p>✅ <span class=\"status-good\">Database Cache</span> - Optimal performance ($CACHE_HIT_RATIO%)</p>" >> "$REPORT_FILE"
fi

# Disk space warning
if [[ $DISK_USAGE_PERCENT -gt 80 ]]; then
    echo "        <p>⚠️ <span class=\"status-warning\">Disk Space</span> - Usage above 80% ($DISK_USAGE_PERCENT%)</p>" >> "$REPORT_FILE"
else
    echo "        <p>✅ <span class=\"status-good\">Disk Space</span> - Adequate free space ($DISK_USAGE_PERCENT% used)</p>" >> "$REPORT_FILE"
fi

cat >> "$REPORT_FILE" << EOF
    </div>

    <div class="metric-card">
        <h2>🎯 Recommendations</h2>
EOF

# Generate specific recommendations
if [[ $DISK_USAGE_PERCENT -gt 75 ]]; then
    cat >> "$REPORT_FILE" << EOF
        <div class="recommendation">
            <h3>Storage Management</h3>
            <p>Disk usage is at $DISK_USAGE_PERCENT%. Consider:</p>
            <ul>
                <li>Cleaning up old backup files and logs</li>
                <li>Archiving old database records</li>
                <li>Planning storage expansion</li>
            </ul>
        </div>
EOF
fi

if (( $(echo "$DB_GROWTH_RATE > 10" | bc -l) )); then
    cat >> "$REPORT_FILE" << EOF
        <div class="recommendation">
            <h3>Database Growth</h3>
            <p>Database has grown $DB_GROWTH_RATE% in the last 30 days. Consider:</p>
            <ul>
                <li>Implementing data archiving strategies</li>
                <li>Optimizing storage allocation</li>
                <li>Planning capacity upgrades</li>
            </ul>
        </div>
EOF
fi

cat >> "$REPORT_FILE" << EOF
        <div class="recommendation">
            <h3>Regular Maintenance</h3>
            <p>Monthly maintenance recommendations:</p>
            <ul>
                <li>Review slow query logs and optimize bottlenecks</li>
                <li>Update system packages and security patches</li>
                <li>Test backup and recovery procedures</li>
                <li>Review user access and permissions</li>
            </ul>
        </div>
    </div>

    <div class="metric-card">
        <h2>📋 System Information</h2>
        <p><strong>Operating System:</strong> $DISTRO</p>
        <p><strong>Kernel:</strong> $KERNEL</p>
        <p><strong>PostgreSQL Version:</strong> $(sudo -u postgres psql -t -c 'SELECT version();' | head -1 | xargs)</p>
        <p><strong>Report Generated:</strong> $(date)</p>
    </div>
</body>
</html>
EOF

log "Health check completed successfully"
log "Report generated: $REPORT_FILE"

# Display summary in terminal
echo ""
echo -e "${BLUE}🏥 Monthly Health Check Summary${NC}"
echo "================================="
echo -e "Database Size: ${GREEN}$DB_SIZE${NC}"
echo -e "Active Users: ${GREEN}$USER_COUNT${NC}"
echo -e "Cache Hit Ratio: ${GREEN}${CACHE_HIT_RATIO}%${NC}"
echo -e "Disk Usage: $([ $DISK_USAGE_PERCENT -gt 80 ] && echo -e "${YELLOW}$DISK_USAGE_PERCENT%${NC}" || echo -e "${GREEN}$DISK_USAGE_PERCENT%${NC}")"
echo ""
echo -e "📊 Full report: ${BLUE}$REPORT_FILE${NC}"
echo ""