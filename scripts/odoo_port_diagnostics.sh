#!/bin/bash

# Odoo Port Accessibility Diagnostics
# Created by Aria Shaw
# Version 1.0 - 2025

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================"
echo "    Odoo Port Accessibility Diagnostics"
echo "========================================"
echo ""

log_message() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success_message() {
    echo -e "${GREEN}[✓]${NC} $1"
}

warning_message() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

error_message() {
    echo -e "${RED}[✗]${NC} $1"
}

# Test 1: Check if Odoo service is running
check_odoo_service() {
    log_message "Checking Odoo service status..."

    if systemctl is-active --quiet odoo; then
        success_message "Odoo service is running"
        return 0
    elif systemctl is-enabled --quiet odoo; then
        error_message "Odoo service is enabled but not running"
        log_message "Try: sudo systemctl start odoo"
        return 1
    else
        error_message "Odoo service is not configured"
        log_message "Check your systemd service configuration"
        return 1
    fi
}

# Test 2: Check Odoo process
check_odoo_process() {
    log_message "Checking Odoo processes..."

    ODOO_PROCESSES=$(ps aux | grep -c '[o]doo')

    if [ "$ODOO_PROCESSES" -gt 0 ]; then
        success_message "Found $ODOO_PROCESSES Odoo process(es)"
        ps aux | grep '[o]doo' | head -3
        return 0
    else
        error_message "No Odoo processes found"
        return 1
    fi
}

# Test 3: Check port binding
check_port_binding() {
    log_message "Checking port 8069 binding..."

    PORT_BINDING=$(netstat -tlnp 2>/dev/null | grep ':8069')

    if [ -n "$PORT_BINDING" ]; then
        success_message "Port 8069 is bound:"
        echo "$PORT_BINDING"

        # Check what interface it's bound to
        if echo "$PORT_BINDING" | grep -q "0.0.0.0:8069"; then
            success_message "Bound to all interfaces (0.0.0.0) - external access enabled"
        elif echo "$PORT_BINDING" | grep -q "127.0.0.1:8069"; then
            warning_message "Bound to localhost only (127.0.0.1) - no external access"
            log_message "To enable external access, set xmlrpc_interface = 0.0.0.0 in config"
        fi
        return 0
    else
        error_message "Port 8069 is not bound by any process"
        return 1
    fi
}

# Test 4: Check local connectivity
check_local_connectivity() {
    log_message "Testing local connectivity to port 8069..."

    if curl -s -I http://localhost:8069 >/dev/null 2>&1; then
        success_message "Local HTTP connection successful"
        RESPONSE=$(curl -s -I http://localhost:8069 | head -1)
        echo "Response: $RESPONSE"
        return 0
    else
        error_message "Local HTTP connection failed"
        log_message "Odoo may not be listening on port 8069"
        return 1
    fi
}

# Test 5: Check firewall configuration
check_firewall() {
    log_message "Checking firewall configuration..."

    # Check UFW
    if command -v ufw >/dev/null 2>&1; then
        UFW_STATUS=$(ufw status 2>/dev/null)
        if echo "$UFW_STATUS" | grep -q "Status: active"; then
            if echo "$UFW_STATUS" | grep -q "8069"; then
                success_message "UFW is active and port 8069 is configured:"
                echo "$UFW_STATUS" | grep "8069"
            else
                warning_message "UFW is active but port 8069 is not explicitly allowed"
                log_message "Try: sudo ufw allow 8069/tcp"
            fi
        else
            log_message "UFW is not active"
        fi
    fi

    # Check iptables
    if command -v iptables >/dev/null 2>&1; then
        IPTABLES_RULES=$(iptables -L INPUT -n 2>/dev/null | grep -E "(8069|ACCEPT.*tcp)")
        if [ -n "$IPTABLES_RULES" ]; then
            log_message "Relevant iptables rules:"
            echo "$IPTABLES_RULES"
        fi
    fi
}

# Test 6: Check Odoo configuration
check_odoo_config() {
    log_message "Checking Odoo configuration..."

    CONFIG_PATHS=(
        "/etc/odoo/odoo.conf"
        "/etc/odoo.conf"
        "/opt/odoo/odoo.conf"
        "/usr/local/etc/odoo.conf"
    )

    CONFIG_FILE=""
    for path in "${CONFIG_PATHS[@]}"; do
        if [ -f "$path" ]; then
            CONFIG_FILE="$path"
            break
        fi
    done

    if [ -n "$CONFIG_FILE" ]; then
        success_message "Found config file: $CONFIG_FILE"

        # Check key configuration values
        if grep -q "^xmlrpc_interface" "$CONFIG_FILE"; then
            INTERFACE=$(grep "^xmlrpc_interface" "$CONFIG_FILE")
            echo "  $INTERFACE"
        else
            warning_message "xmlrpc_interface not explicitly set (defaults to 0.0.0.0)"
        fi

        if grep -q "^xmlrpc_port" "$CONFIG_FILE"; then
            PORT=$(grep "^xmlrpc_port" "$CONFIG_FILE")
            echo "  $PORT"
        else
            log_message "xmlrpc_port not set (defaults to 8069)"
        fi

        if grep -q "^proxy_mode" "$CONFIG_FILE"; then
            PROXY=$(grep "^proxy_mode" "$CONFIG_FILE")
            echo "  $PROXY"
        else
            warning_message "proxy_mode not set (should be True if using nginx/Apache)"
        fi

    else
        error_message "No Odoo configuration file found"
        log_message "Check these locations: ${CONFIG_PATHS[*]}"
    fi
}

# Test 7: Check external connectivity (if applicable)
check_external_connectivity() {
    log_message "Testing external connectivity..."

    # Get external IP if possible
    EXTERNAL_IP=$(curl -s -m 5 ifconfig.me 2>/dev/null || echo "unknown")

    if [ "$EXTERNAL_IP" != "unknown" ]; then
        log_message "External IP: $EXTERNAL_IP"

        # Test if port is accessible from outside (basic check)
        if command -v nc >/dev/null 2>&1; then
            if timeout 5 nc -z localhost 8069 2>/dev/null; then
                success_message "Port 8069 is accessible locally"
            else
                error_message "Port 8069 is not accessible even locally"
            fi
        fi
    else
        warning_message "Could not determine external IP"
    fi
}

# Test 8: Check logs for errors
check_logs() {
    log_message "Checking recent Odoo logs for errors..."

    LOG_PATHS=(
        "/var/log/odoo/odoo.log"
        "/var/log/odoo.log"
        "/opt/odoo/odoo.log"
    )

    LOG_FILE=""
    for path in "${LOG_PATHS[@]}"; do
        if [ -f "$path" ]; then
            LOG_FILE="$path"
            break
        fi
    done

    if [ -n "$LOG_FILE" ]; then
        success_message "Found log file: $LOG_FILE"

        # Check for recent errors
        RECENT_ERRORS=$(tail -50 "$LOG_FILE" | grep -i "error\|exception\|failed" | tail -5)
        if [ -n "$RECENT_ERRORS" ]; then
            warning_message "Recent errors found in logs:"
            echo "$RECENT_ERRORS"
        else
            success_message "No recent errors found in logs"
        fi

        # Check for port binding messages
        BINDING_LOGS=$(tail -100 "$LOG_FILE" | grep -i "listening\|bind\|port" | tail -3)
        if [ -n "$BINDING_LOGS" ]; then
            log_message "Port binding logs:"
            echo "$BINDING_LOGS"
        fi

    else
        warning_message "No Odoo log file found"
        log_message "Check these locations: ${LOG_PATHS[*]}"
    fi
}

# Generate recommendations
generate_recommendations() {
    echo ""
    echo "========================================"
    echo "          RECOMMENDATIONS"
    echo "========================================"

    echo ""
    echo "Based on the diagnostics above, here are common solutions:"
    echo ""

    echo "If Odoo service is not running:"
    echo "  sudo systemctl start odoo"
    echo "  sudo systemctl enable odoo"
    echo ""

    echo "If port 8069 is not accessible externally:"
    echo "  sudo ufw allow 8069/tcp"
    echo "  # Or set up nginx proxy (recommended for production)"
    echo ""

    echo "If bound to localhost only:"
    echo "  # Edit /etc/odoo/odoo.conf and set:"
    echo "  xmlrpc_interface = 0.0.0.0"
    echo "  # Then restart: sudo systemctl restart odoo"
    echo ""

    echo "If using nginx/Apache proxy:"
    echo "  # Ensure proxy_mode = True in /etc/odoo/odoo.conf"
    echo "  # And xmlrpc_interface = 127.0.0.1"
    echo ""

    echo "If experiencing 502 errors:"
    echo "  # Check nginx/Apache configuration"
    echo "  # Ensure upstream points to correct port"
    echo "  # Verify proxy_mode = True in Odoo config"
    echo ""
}

# Main execution
main() {
    log_message "Starting comprehensive port diagnostics..."
    echo ""

    # Run all diagnostic tests
    check_odoo_service
    echo ""
    check_odoo_process
    echo ""
    check_port_binding
    echo ""
    check_local_connectivity
    echo ""
    check_firewall
    echo ""
    check_odoo_config
    echo ""
    check_external_connectivity
    echo ""
    check_logs

    # Generate recommendations
    generate_recommendations

    echo ""
    log_message "Diagnostics complete!"
}

# Run main function
main "$@"