#!/bin/bash
# Real-Time Integration Health Monitor
# Monitors sync status, API call success rates, alerts on failures

set -e

# Configuration
LOG_FILE="/var/log/odoo/integration_health.log"
ERROR_THRESHOLD=10  # Alert if >10% API calls fail
LATENCY_THRESHOLD=5000  # Alert if latency >5s
CHECK_INTERVAL=60  # Check every 60 seconds

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_api_health() {
    local api_url="$1"
    local start_time=$(date +%s%3N)

    response=$(curl -s -w "\n%{http_code}" -o /tmp/api_response "$api_url" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    latency=$(($(date +%s%3N) - start_time))

    if [ "$http_code" = "200" ]; then
        if [ "$latency" -gt "$LATENCY_THRESHOLD" ]; then
            echo -e "${YELLOW}WARN${NC} API responding slowly: ${latency}ms"
            log_message "WARNING: High latency $latency ms for $api_url"
            return 1
        else
            echo -e "${GREEN}OK${NC} API healthy: ${latency}ms"
            return 0
        fi
    else
        echo -e "${RED}FAIL${NC} API returned HTTP $http_code"
        log_message "ERROR: API health check failed with HTTP $http_code for $api_url"
        return 2
    fi
}

check_sync_status() {
    # Check last sync timestamp in Odoo database
    local db_name="${1:-odoo}"
    local query="SELECT MAX(write_date) FROM ir_cron WHERE active=true;"

    last_sync=$(sudo -u postgres psql -d "$db_name" -t -c "$query" 2>/dev/null || echo "N/A")

    if [ "$last_sync" != "N/A" ]; then
        echo -e "${GREEN}✓${NC} Last cron execution: $last_sync"
        log_message "INFO: Last sync at $last_sync"
    else
        echo -e "${RED}✗${NC} Cannot determine last sync time"
        log_message "ERROR: Failed to query sync status"
    fi
}

check_failed_jobs() {
    local db_name="${1:-odoo}"
    local query="SELECT COUNT(*) FROM ir_cron WHERE numbercall < 0;"

    failed_count=$(sudo -u postgres psql -d "$db_name" -t -c "$query" 2>/dev/null | tr -d ' ')

    if [ "$failed_count" -gt 0 ]; then
        echo -e "${YELLOW}⚠${NC} Failed cron jobs: $failed_count"
        log_message "WARNING: $failed_count failed cron jobs detected"
    else
        echo -e "${GREEN}✓${NC} No failed cron jobs"
    fi
}

monitor_loop() {
    local api_url="${1:-http://localhost:8069/web/health}"
    local db_name="${2:-odoo}"

    log_message "Starting integration health monitoring..."
    log_message "API Endpoint: $api_url"
    log_message "Database: $db_name"
    log_message "Check interval: ${CHECK_INTERVAL}s"

    while true; do
        echo ""
        echo "========================================="
        echo "Integration Health Check - $(date)"
        echo "========================================="

        # Check API health
        echo -n "API Health: "
        check_api_health "$api_url"

        # Check sync status
        echo -n "Sync Status: "
        check_sync_status "$db_name"

        # Check failed jobs
        echo -n "Failed Jobs: "
        check_failed_jobs "$db_name"

        echo ""
        echo "Next check in ${CHECK_INTERVAL}s..."
        sleep "$CHECK_INTERVAL"
    done
}

# Main execution
case "${1:-}" in
    --once)
        check_api_health "${2:-http://localhost:8069/web/health}"
        check_sync_status "${3:-odoo}"
        check_failed_jobs "${3:-odoo}"
        ;;
    --help|-h)
        echo "Usage: $0 [--once] [api_url] [db_name]"
        echo ""
        echo "Options:"
        echo "  --once        Run single health check and exit"
        echo "  --help        Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0                                    # Continuous monitoring (default)"
        echo "  $0 --once                            # Single check"
        echo "  $0 http://api.example.com/health odoo_prod  # Custom endpoint and DB"
        ;;
    *)
        monitor_loop "${1:-http://localhost:8069/web/health}" "${2:-odoo}"
        ;;
esac
