#!/bin/bash

# Odoo Emergency Recovery Toolkit
# Created by Aria Shaw
# Version 1.0 - 2025
# Use this when everything is broken and you need to get back online fast

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================"
echo "    ODOO EMERGENCY RECOVERY TOOLKIT"
echo "========================================"
echo ""
echo -e "${RED}WARNING: This script performs emergency recovery actions${NC}"
echo -e "${RED}Only use this during active outages when normal procedures fail${NC}"
echo ""

read -p "Continue with emergency recovery? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Emergency recovery cancelled"
    exit 1
fi

# Logging
LOG_FILE="/var/log/odoo_emergency_$(date +%Y%m%d_%H%M%S).log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

log_message() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

success_message() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning_message() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error_message() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if we're running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error_message "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Emergency diagnostic check
emergency_diagnostics() {
    log_message "Running emergency diagnostics..."

    echo "=== SYSTEM STATUS ==="
    echo "Date: $(date)"
    echo "Uptime: $(uptime)"
    echo "Load: $(cat /proc/loadavg)"
    echo "Memory: $(free -h | grep Mem)"
    echo "Disk: $(df -h / | tail -1)"
    echo ""

    echo "=== SERVICES STATUS ==="
    echo "Odoo: $(systemctl is-active odoo 2>/dev/null || echo 'unknown')"
    echo "PostgreSQL: $(systemctl is-active postgresql 2>/dev/null || echo 'unknown')"
    echo "Nginx: $(systemctl is-active nginx 2>/dev/null || echo 'inactive')"
    echo ""

    echo "=== PROCESS CHECK ==="
    echo "Odoo processes: $(ps aux | grep -c '[o]doo')"
    echo "PostgreSQL processes: $(ps aux | grep -c '[p]ostgres')"
    echo ""

    echo "=== PORT CHECK ==="
    netstat -tlnp 2>/dev/null | grep -E ':8069|:5432' || echo "No listening ports found"
    echo ""
}

# Kill hanging processes
kill_hanging_processes() {
    log_message "Killing hanging Odoo processes..."

    # Get all Odoo PIDs
    ODOO_PIDS=$(pgrep -f "odoo")

    if [ -n "$ODOO_PIDS" ]; then
        warning_message "Found Odoo processes: $ODOO_PIDS"

        # Try graceful shutdown first
        for pid in $ODOO_PIDS; do
            log_message "Sending TERM signal to PID $pid"
            kill -TERM "$pid" 2>/dev/null
        done

        # Wait 10 seconds
        sleep 10

        # Force kill if still running
        REMAINING_PIDS=$(pgrep -f "odoo")
        if [ -n "$REMAINING_PIDS" ]; then
            warning_message "Force killing remaining processes: $REMAINING_PIDS"
            for pid in $REMAINING_PIDS; do
                kill -KILL "$pid" 2>/dev/null
            done
        fi

        success_message "Odoo processes cleaned up"
    else
        log_message "No Odoo processes found to kill"
    fi
}

# Clear temporary files and locks
clear_temp_files() {
    log_message "Clearing temporary files and locks..."

    # Clear Odoo session files
    find /tmp -name "odoo*" -type f -mtime +1 -delete 2>/dev/null || true

    # Clear any lock files
    find /opt/odoo -name "*.lock" -delete 2>/dev/null || true
    find /var/lib/odoo -name "*.lock" -delete 2>/dev/null || true

    # Clear systemd failed states
    systemctl reset-failed odoo 2>/dev/null || true
    systemctl reset-failed postgresql 2>/dev/null || true

    success_message "Temporary files cleared"
}

# Check and fix database connectivity
check_database() {
    log_message "Checking PostgreSQL database..."

    # Start PostgreSQL if not running
    if ! systemctl is-active --quiet postgresql; then
        warning_message "PostgreSQL is not running, attempting to start..."
        systemctl start postgresql

        if systemctl is-active --quiet postgresql; then
            success_message "PostgreSQL started successfully"
        else
            error_message "Failed to start PostgreSQL"
            return 1
        fi
    else
        success_message "PostgreSQL is running"
    fi

    # Test database connectivity
    if sudo -u postgres psql -c '\l' >/dev/null 2>&1; then
        success_message "Database connectivity OK"
    else
        error_message "Database connectivity failed"

        # Try to restart PostgreSQL
        warning_message "Restarting PostgreSQL..."
        systemctl restart postgresql
        sleep 5

        if sudo -u postgres psql -c '\l' >/dev/null 2>&1; then
            success_message "Database connectivity restored after restart"
        else
            error_message "Database connectivity still failing"
            return 1
        fi
    fi
}

# Apply emergency configuration
apply_emergency_config() {
    log_message "Applying emergency configuration..."

    CONFIG_FILE="/etc/odoo/odoo.conf"

    if [ ! -f "$CONFIG_FILE" ]; then
        error_message "Odoo config file not found at $CONFIG_FILE"
        return 1
    fi

    # Backup current config
    cp "$CONFIG_FILE" "${CONFIG_FILE}.emergency_backup_$(date +%Y%m%d_%H%M%S)"

    # Apply emergency settings (conservative values for stability)
    cat >> "$CONFIG_FILE" << 'EOF'

# Emergency Recovery Settings
workers = 2
max_cron_threads = 1
limit_memory_hard = 1073741824
limit_memory_soft = 805306368
limit_request = 4096
limit_time_cpu = 300
limit_time_real = 600
db_maxconn = 32
EOF

    success_message "Emergency configuration applied"
}

# Restart services with proper ordering
restart_services() {
    log_message "Restarting services with proper dependency ordering..."

    # Stop all services first
    systemctl stop odoo 2>/dev/null || true
    systemctl stop nginx 2>/dev/null || true

    # Start PostgreSQL first
    if ! systemctl is-active --quiet postgresql; then
        systemctl start postgresql
        sleep 3
    fi

    # Start Odoo
    log_message "Starting Odoo service..."
    systemctl start odoo

    # Wait for Odoo to be ready
    log_message "Waiting for Odoo to be ready..."
    RETRY_COUNT=0
    MAX_RETRIES=30

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if curl -s -I http://localhost:8069 >/dev/null 2>&1; then
            success_message "Odoo is responding on port 8069"
            break
        fi

        sleep 2
        ((RETRY_COUNT++))
        echo -n "."
    done

    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        error_message "Odoo failed to respond after $MAX_RETRIES attempts"
        return 1
    fi

    # Start nginx if it was running
    if systemctl is-enabled --quiet nginx 2>/dev/null; then
        systemctl start nginx 2>/dev/null || true
    fi

    success_message "Services restarted successfully"
}

# Check final status
check_final_status() {
    log_message "Checking final system status..."

    echo "=== FINAL STATUS ==="
    echo "Odoo Service: $(systemctl is-active odoo)"
    echo "PostgreSQL Service: $(systemctl is-active postgresql)"
    echo "Nginx Service: $(systemctl is-active nginx 2>/dev/null || echo 'not configured')"
    echo ""

    echo "=== CONNECTIVITY TEST ==="
    if curl -s -I http://localhost:8069 | head -1; then
        success_message "Odoo is responding to HTTP requests"
    else
        error_message "Odoo is not responding to HTTP requests"
    fi

    echo ""
    echo "=== RECENT LOGS ==="
    journalctl -u odoo --no-pager -n 5 --since "5 minutes ago" || echo "No recent logs available"
}

# Generate recovery report
generate_recovery_report() {
    log_message "Generating recovery report..."

    REPORT_FILE="/tmp/odoo_recovery_report_$(date +%Y%m%d_%H%M%S).txt"

    cat > "$REPORT_FILE" << EOF
Odoo Emergency Recovery Report
==============================
Date: $(date)
Operator: $(whoami)
Server: $(hostname)

Actions Taken:
- Emergency diagnostics run
- Hanging processes killed
- Temporary files cleared
- Database connectivity checked
- Emergency configuration applied
- Services restarted

Final Status:
- Odoo Service: $(systemctl is-active odoo)
- PostgreSQL Service: $(systemctl is-active postgresql)
- HTTP Response: $(curl -s -I http://localhost:8069 | head -1 || echo "No response")

Log File: $LOG_FILE

Recommendations:
1. Monitor system for 30 minutes to ensure stability
2. Review emergency configuration in $CONFIG_FILE
3. Check application logs for any errors
4. Plan proper configuration review during maintenance window
5. Consider implementing proper monitoring to prevent future emergencies

EOF

    success_message "Recovery report generated: $REPORT_FILE"
    echo ""
    cat "$REPORT_FILE"
}

# Main recovery sequence
main() {
    check_root

    log_message "Starting emergency recovery sequence..."
    echo ""

    emergency_diagnostics
    echo ""

    kill_hanging_processes
    echo ""

    clear_temp_files
    echo ""

    check_database
    echo ""

    apply_emergency_config
    echo ""

    restart_services
    echo ""

    check_final_status
    echo ""

    generate_recovery_report

    echo ""
    echo "========================================"
    echo -e "${GREEN}    EMERGENCY RECOVERY COMPLETE${NC}"
    echo "========================================"
    echo ""
    echo "Next steps:"
    echo "1. Monitor the system for stability"
    echo "2. Review the emergency configuration changes"
    echo "3. Plan proper configuration optimization"
    echo "4. Set up monitoring to prevent future emergencies"
    echo ""
    echo "Emergency log: $LOG_FILE"
}

# Run main function
main "$@"