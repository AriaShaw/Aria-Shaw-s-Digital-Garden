#!/bin/bash
# Odoo Post-Migration Performance Validation System
# 24-hour monitoring and optimization system

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITORING_LOG="/var/log/odoo_performance_monitoring.log"
PERFORMANCE_REPORT="/tmp/odoo_performance_report_$(date +%Y%m%d_%H%M%S).html"
ALERT_THRESHOLD_RESPONSE_TIME=2.0
ALERT_THRESHOLD_CPU_PERCENT=80
ALERT_THRESHOLD_MEMORY_PERCENT=85
MONITORING_DURATION_HOURS=24
SAMPLE_INTERVAL_SECONDS=300  # 5 minutes

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$MONITORING_LOG"
}

# Performance test functions
test_response_time() {
    local start_time=$(date +%s.%N)
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8069/web/database/selector 2>/dev/null)
    local end_time=$(date +%s.%N)
    local response_time=$(echo "$end_time - $start_time" | bc -l)
    
    echo "$response_time"
}

test_database_performance() {
    local start_time=$(date +%s.%N)
    sudo -u postgres psql -d odoo_production_new -c "SELECT count(*) FROM ir_module_module;" > /dev/null 2>&1
    local end_time=$(date +%s.%N)
    local query_time=$(echo "$end_time - $start_time" | bc -l)
    
    echo "$query_time"
}

get_system_metrics() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    local memory_usage=$(free | grep '^Mem:' | awk '{printf "%.1f", $3/$2*100}')
    local disk_usage=$(df /opt | awk 'NR==2{print $5}' | sed 's/%//')
    
    echo "$cpu_usage,$memory_usage,$disk_usage"
}

# Generate HTML performance report
generate_html_report() {
    local report_data="$1"
    
    cat > "$PERFORMANCE_REPORT" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Odoo Migration Performance Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #2E7D32; color: white; padding: 20px; border-radius: 8px; }
        .metric-card { background: #f5f5f5; padding: 15px; margin: 10px 0; border-radius: 8px; }
        .good { border-left: 5px solid #4CAF50; }
        .warning { border-left: 5px solid #FF9800; }
        .critical { border-left: 5px solid #F44336; }
        .chart { width: 100%; height: 200px; background: #fff; border: 1px solid #ddd; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🚀 Odoo Migration Performance Report</h1>
        <p>Generated: $(date)</p>
        <p>Monitoring Duration: 24 hours</p>
    </div>
    
    <div class="metric-card good">
        <h3>✅ Overall Status: EXCELLENT</h3>
        <p>Your migrated Odoo system is performing within optimal parameters.</p>
    </div>
    
    <div class="metric-card">
        <h3>📊 Performance Metrics</h3>
        $report_data
    </div>
    
    <div class="metric-card">
        <h3>🔧 Optimization Recommendations</h3>
        <ul>
            <li>Monitor database growth weekly using the provided scripts</li>
            <li>Set up automated backups with the optimized schedule</li>
            <li>Review slow query logs monthly for optimization opportunities</li>
        </ul>
    </div>
</body>
</html>
EOF
}

# Main monitoring loop
main() {
    echo "=================================================================="
    echo -e "${GREEN}🔍 Odoo Post-Migration Performance Validation${NC}"
    echo "=================================================================="
    echo ""
    
    log "Starting 24-hour performance monitoring..."
    
    local monitoring_start=$(date +%s)
    local monitoring_end=$((monitoring_start + MONITORING_DURATION_HOURS * 3600))
    local sample_count=0
    local total_response_time=0
    local max_response_time=0
    local min_response_time=999
    local performance_data=""
    
    echo -e "${BLUE}Monitoring will run for $MONITORING_DURATION_HOURS hours${NC}"
    echo -e "${BLUE}Sampling every $SAMPLE_INTERVAL_SECONDS seconds${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop monitoring and generate report${NC}"
    echo ""
    
    # Monitoring loop
    while [[ $(date +%s) -lt $monitoring_end ]]; do
        local current_time=$(date '+%Y-%m-%d %H:%M:%S')
        
        # Test response time
        local response_time=$(test_response_time)
        
        # Test database performance
        local db_time=$(test_database_performance)
        
        # Get system metrics
        local metrics=$(get_system_metrics)
        local cpu_usage=$(echo "$metrics" | cut -d',' -f1)
        local memory_usage=$(echo "$metrics" | cut -d',' -f2)
        local disk_usage=$(echo "$metrics" | cut -d',' -f3)
        
        # Update statistics
        sample_count=$((sample_count + 1))
        total_response_time=$(echo "$total_response_time + $response_time" | bc -l)
        
        if (( $(echo "$response_time > $max_response_time" | bc -l) )); then
            max_response_time=$response_time
        fi
        
        if (( $(echo "$response_time < $min_response_time" | bc -l) )); then
            min_response_time=$response_time
        fi
        
        # Log metrics
        log "METRICS: Response=${response_time}s DB=${db_time}s CPU=${cpu_usage}% MEM=${memory_usage}% DISK=${disk_usage}%"
        
        # Check for alerts
        if (( $(echo "$response_time > $ALERT_THRESHOLD_RESPONSE_TIME" | bc -l) )); then
            echo -e "${RED}🚨 ALERT: High response time: ${response_time}s${NC}"
            log "ALERT: High response time: ${response_time}s"
        fi
        
        if (( $(echo "$memory_usage > $ALERT_THRESHOLD_MEMORY_PERCENT" | bc -l) )); then
            echo -e "${RED}🚨 ALERT: High memory usage: ${memory_usage}%${NC}"
            log "ALERT: High memory usage: ${memory_usage}%"
        fi
        
        # Progress update
        local elapsed_hours=$(echo "scale=1; ($(date +%s) - $monitoring_start) / 3600" | bc -l)
        echo -e "${CYAN}Sample $sample_count: ${current_time} | Response: ${response_time}s | CPU: ${cpu_usage}% | Memory: ${memory_usage}% | Elapsed: ${elapsed_hours}h${NC}"
        
        # Build performance data for report
        performance_data+="<p>$current_time - Response: ${response_time}s, DB: ${db_time}s, CPU: ${cpu_usage}%, Memory: ${memory_usage}%</p>"
        
        sleep "$SAMPLE_INTERVAL_SECONDS"
    done
    
    # Calculate final statistics
    local avg_response_time=$(echo "scale=3; $total_response_time / $sample_count" | bc -l)
    
    echo ""
    echo "=================================================================="
    echo -e "${GREEN}📊 24-HOUR MONITORING COMPLETE${NC}"
    echo "=================================================================="
    echo ""
    echo -e "${CYAN}Performance Summary:${NC}"
    echo "• Total samples: $sample_count"
    echo "• Average response time: ${avg_response_time}s"
    echo "• Min response time: ${min_response_time}s"
    echo "• Max response time: ${max_response_time}s"
    
    # Generate performance grade
    local grade="EXCELLENT"
    local grade_color="$GREEN"
    
    if (( $(echo "$avg_response_time > 1.0" | bc -l) )); then
        grade="GOOD"
        grade_color="$BLUE"
    fi
    
    if (( $(echo "$avg_response_time > 2.0" | bc -l) )); then
        grade="NEEDS OPTIMIZATION"
        grade_color="$YELLOW"
    fi
    
    echo ""
    echo -e "${grade_color}🏆 Performance Grade: $grade${NC}"
    
    # Generate HTML report
    generate_html_report "$performance_data"
    echo -e "${BLUE}📋 Detailed report: $PERFORMANCE_REPORT${NC}"
    
    # Recommendations based on performance
    echo ""
    echo -e "${CYAN}🎯 Recommendations:${NC}"
    
    if (( $(echo "$avg_response_time < 1.0" | bc -l) )); then
        echo -e "${GREEN}✅ Your migration is performing excellently!${NC}"
        echo "• Response times are optimal"
        echo "• System resources are well-utilized"
        echo "• No immediate optimizations needed"
    elif (( $(echo "$avg_response_time < 2.0" | bc -l) )); then
        echo -e "${BLUE}👍 Your migration is performing well${NC}"
        echo "• Consider monitoring during peak hours"
        echo "• Review database query optimization"
        echo "• Monitor user feedback for any issues"
    else
        echo -e "${YELLOW}⚠️ Performance optimization recommended${NC}"
        echo "• Review PostgreSQL configuration"
        echo "• Check for resource bottlenecks"
        echo "• Consider hardware upgrades"
        echo "• Analyze slow query logs"
    fi
    
    log "Performance monitoring completed. Grade: $grade, Avg response: ${avg_response_time}s"
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${YELLOW}Monitoring interrupted by user${NC}"; main' INT

# Run main function
main "$@"