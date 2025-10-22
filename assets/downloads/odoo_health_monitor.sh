#!/bin/bash

# Odoo Health Monitor
# Created by Aria Shaw
# Version 1.0 - 2025
# Monitors critical Odoo system metrics and sends alerts

# Configuration
ALERT_EMAIL="admin@yourcompany.com"
LOG_FILE="/var/log/odoo/health_monitor.log"
ALERT_COOLDOWN_FILE="/tmp/odoo_alert_cooldown"
COOLDOWN_MINUTES=30

# Thresholds
CPU_THRESHOLD=90
MEMORY_THRESHOLD=85
DISK_THRESHOLD=85
DB_CONNECTION_THRESHOLD=70

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

send_alert() {
    local alert_type="$1"
    local message="$2"
    local current_time=$(date +%s)

    # Check cooldown to prevent spam
    if [ -f "$ALERT_COOLDOWN_FILE" ]; then
        last_alert=$(cat "$ALERT_COOLDOWN_FILE")
        time_diff=$((current_time - last_alert))
        if [ $time_diff -lt $((COOLDOWN_MINUTES * 60)) ]; then
            log_message "Alert suppressed (cooldown active): $alert_type"
            return
        fi
    fi

    # Send email alert if mail is available
    if command -v mail &> /dev/null; then
        echo "$message" | mail -s "Odoo Alert: $alert_type - $(hostname)" "$ALERT_EMAIL"
    fi

    # Log alert
    log_message "ALERT SENT: $alert_type - $message"

    # Update cooldown
    echo "$current_time" > "$ALERT_COOLDOWN_FILE"
}

check_cpu_usage() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    cpu_usage=${cpu_usage%.*}  # Remove decimal part

    if [ "$cpu_usage" -gt "$CPU_THRESHOLD" ]; then
        send_alert "High CPU Usage" "CPU usage is at ${cpu_usage}% (threshold: ${CPU_THRESHOLD}%)"
        return 1
    fi

    return 0
}

check_memory_usage() {
    local memory_usage=$(free | grep Mem | awk '{printf("%.0f", $3/$2 * 100.0)}')

    if [ "$memory_usage" -gt "$MEMORY_THRESHOLD" ]; then
        local memory_details=$(free -h)
        send_alert "High Memory Usage" "Memory usage is at ${memory_usage}% (threshold: ${MEMORY_THRESHOLD}%)\n\n${memory_details}"
        return 1
    fi

    return 0
}

check_disk_usage() {
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | cut -d'%' -f1)

    if [ "$disk_usage" -gt "$DISK_THRESHOLD" ]; then
        local disk_details=$(df -h /)
        send_alert "High Disk Usage" "Disk usage is at ${disk_usage}% (threshold: ${DISK_THRESHOLD}%)\n\n${disk_details}"
        return 1
    fi

    return 0
}

check_odoo_service() {
    if ! systemctl is-active --quiet odoo; then
        send_alert "Odoo Service Down" "Odoo service is not running. Attempting to restart..."

        # Attempt restart
        if systemctl restart odoo; then
            log_message "Odoo service restarted successfully"
            send_alert "Odoo Service Recovered" "Odoo service was restarted and is now running"
        else
            send_alert "Odoo Service Restart Failed" "Failed to restart Odoo service. Manual intervention required."
        fi
        return 1
    fi

    return 0
}

check_database_connections() {
    # Get max connections
    local max_connections=$(sudo -u postgres psql -t -c "SHOW max_connections;" 2>/dev/null | xargs)

    if [ -z "$max_connections" ]; then
        log_message "Warning: Could not retrieve max_connections from PostgreSQL"
        return 0
    fi

    # Get current connections
    local current_connections=$(sudo -u postgres psql -t -c "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null | xargs)

    if [ -z "$current_connections" ]; then
        log_message "Warning: Could not retrieve current connections from PostgreSQL"
        return 0
    fi

    # Calculate percentage
    local connection_percentage=$((current_connections * 100 / max_connections))

    if [ "$connection_percentage" -gt "$DB_CONNECTION_THRESHOLD" ]; then
        send_alert "High Database Connections" "Database connections at ${connection_percentage}% (${current_connections}/${max_connections}). Threshold: ${DB_CONNECTION_THRESHOLD}%"
        return 1
    fi

    return 0
}

check_odoo_workers() {
    local worker_count=$(ps aux | grep -c '[o]doo.*worker')
    local master_count=$(ps aux | grep -c '[o]doo.*master')

    if [ "$master_count" -eq 0 ]; then
        send_alert "No Odoo Master Process" "No Odoo master process found running"
        return 1
    fi

    if [ "$worker_count" -eq 0 ]; then
        send_alert "No Odoo Worker Processes" "No Odoo worker processes found running"
        return 1
    fi

    log_message "Odoo processes: $master_count master, $worker_count workers"
    return 0
}

generate_health_report() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    cat << EOF
=== Odoo Health Report - $timestamp ===

System Resources:
- CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%
- Memory Usage: $(free | grep Mem | awk '{printf("%.1f%%", $3/$2 * 100.0)}')
- Disk Usage: $(df / | awk 'NR==2 {print $5}')

Odoo Status:
- Service Status: $(systemctl is-active odoo)
- Master Processes: $(ps aux | grep -c '[o]doo.*master')
- Worker Processes: $(ps aux | grep -c '[o]doo.*worker')

Database:
- PostgreSQL Status: $(systemctl is-active postgresql)
- Active Connections: $(sudo -u postgres psql -t -c "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null | xargs || echo "N/A")

EOF
}

main() {
    # Create log file if it doesn't exist
    touch "$LOG_FILE"

    log_message "=== Starting Odoo Health Check ==="

    local issues_found=0

    # Run all checks
    check_cpu_usage || ((issues_found++))
    check_memory_usage || ((issues_found++))
    check_disk_usage || ((issues_found++))
    check_odoo_service || ((issues_found++))
    check_database_connections || ((issues_found++))
    check_odoo_workers || ((issues_found++))

    # Generate health report
    if [ "$issues_found" -eq 0 ]; then
        log_message "Health check completed: All systems normal"
    else
        log_message "Health check completed: $issues_found issues found"
        generate_health_report >> "$LOG_FILE"
    fi

    log_message "=== Health Check Complete ==="
}

# Run main function
main "$@"