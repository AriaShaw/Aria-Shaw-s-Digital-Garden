#!/bin/bash
# Complete Odoo Configuration & Modules Backup Script
# Usage: ./backup_configuration.sh <database_name> [backup_location]

set -e

# Configuration
DB_NAME="${1:-odoo_production}"
BACKUP_DIR="${2:-/secure/backup}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CONFIG_BACKUP="$BACKUP_DIR/odoo_config_${DB_NAME}_${TIMESTAMP}.tar.gz"
LOG_FILE="$BACKUP_DIR/config_backup_${TIMESTAMP}.log"

# Common Odoo installation paths
ODOO_PATHS=(
    "/opt/odoo"
    "/usr/lib/python3/dist-packages/odoo"
    "/home/odoo"
    "/var/lib/odoo"
)

# Common config file locations
CONFIG_LOCATIONS=(
    "/etc/odoo/odoo.conf"
    "/opt/odoo/odoo.conf"
    "/etc/odoo.conf"
    "/home/odoo/odoo.conf"
    "/var/lib/odoo/odoo.conf"
)

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "⚙️  Starting Configuration Backup"
echo "================================="
echo "Database: $DB_NAME"
echo "Target: $CONFIG_BACKUP"
echo ""

mkdir -p "$BACKUP_DIR"

log_message() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

# Find Odoo installation directory
ODOO_HOME=""
for path in "${ODOO_PATHS[@]}"; do
    if [ -d "$path" ] && [ -r "$path" ]; then
        ODOO_HOME="$path"
        log_message "${GREEN}✅ Found Odoo installation: $ODOO_HOME${NC}"
        break
    fi
done

if [ -z "$ODOO_HOME" ]; then
    log_message "${YELLOW}⚠️  Could not auto-detect Odoo installation directory${NC}"
    log_message "Will backup configurations only"
fi

# Find active configuration file
CONFIG_FILE=""
for config in "${CONFIG_LOCATIONS[@]}"; do
    if [ -f "$config" ]; then
        CONFIG_FILE="$config"
        log_message "${GREEN}✅ Found config file: $CONFIG_FILE${NC}"
        break
    fi
done

if [ -z "$CONFIG_FILE" ]; then
    log_message "${RED}❌ ERROR: Could not locate odoo.conf file${NC}"
    log_message "Searched locations:"
    for config in "${CONFIG_LOCATIONS[@]}"; do
        log_message "   - $config"
    done
    exit 1
fi

# Create temporary staging directory for backup
STAGING_DIR="/tmp/odoo_config_backup_$$"
mkdir -p "$STAGING_DIR"

log_message "📦 Preparing configuration backup..."

# Function to safely copy files/directories
safe_copy() {
    local source="$1"
    local dest="$2"
    local name="$3"
    
    if [ -e "$source" ]; then
        log_message "${BLUE}📁 Backing up $name...${NC}"
        cp -r "$source" "$dest/" 2>> "$LOG_FILE" || {
            log_message "${YELLOW}⚠️  Warning: Could not backup $name${NC}"
        }
        return 0
    else
        log_message "${YELLOW}⚠️  $name not found at $source${NC}"
        return 1
    fi
}

# Backup main configuration file
safe_copy "$CONFIG_FILE" "$STAGING_DIR" "main configuration"

# Create config analysis
log_message "🔍 Analyzing configuration..."
CONFIG_ANALYSIS="$STAGING_DIR/config_analysis.txt"
cat > "$CONFIG_ANALYSIS" << EOF
Odoo Configuration Analysis
===========================
Generated: $(date)
Config File: $CONFIG_FILE
Database: $DB_NAME

Configuration Contents:
EOF

# Parse and document key configuration settings
if [ -f "$CONFIG_FILE" ]; then
    {
        echo ""
        echo "=== Main Configuration ==="
        cat "$CONFIG_FILE"
        echo ""
        
        echo "=== Key Settings Summary ==="
        grep -E "^(db_host|db_port|db_user|db_password|addons_path|data_dir|xmlrpc_port|workers|limit_memory_hard)" "$CONFIG_FILE" | while read -r line; do
            echo "  $line"
        done
    } >> "$CONFIG_ANALYSIS"
fi

# Find and backup custom addons
log_message "🔍 Searching for custom addon directories..."
ADDONS_PATHS=()

# Extract addons_path from config file
if [ -f "$CONFIG_FILE" ]; then
    ADDONS_LINE=$(grep "^addons_path" "$CONFIG_FILE" || true)
    if [ -n "$ADDONS_LINE" ]; then
        # Parse comma-separated paths
        IFS='=' read -ra ADDR <<< "$ADDONS_LINE"
        IFS=',' read -ra PATHS <<< "${ADDR[1]}"
        for path in "${PATHS[@]}"; do
            # Trim whitespace
            trimmed_path=$(echo "$path" | xargs)
            if [ -d "$trimmed_path" ] && [[ "$trimmed_path" == *custom* || "$trimmed_path" == *local* ]]; then
                ADDONS_PATHS+=("$trimmed_path")
            fi
        done
    fi
fi

# Common custom addon locations
CUSTOM_ADDON_LOCATIONS=(
    "$ODOO_HOME/custom-addons"
    "$ODOO_HOME/addons-custom"  
    "$ODOO_HOME/local-addons"
    "/opt/odoo-custom"
    "/var/lib/odoo/addons"
)

for location in "${CUSTOM_ADDON_LOCATIONS[@]}"; do
    if [ -d "$location" ]; then
        ADDONS_PATHS+=("$location")
    fi
done

# Remove duplicates
UNIQUE_ADDONS=($(printf "%s\n" "${ADDONS_PATHS[@]}" | sort -u))

# Backup each custom addon directory
ADDON_MANIFEST="$STAGING_DIR/custom_addons_manifest.txt"
echo "Custom Addons Backup Manifest" > "$ADDON_MANIFEST"
echo "=============================" >> "$ADDON_MANIFEST"
echo "Generated: $(date)" >> "$ADDON_MANIFEST"
echo "" >> "$ADDON_MANIFEST"

for addon_path in "${UNIQUE_ADDONS[@]}"; do
    if [ -d "$addon_path" ]; then
        addon_name=$(basename "$addon_path")
        log_message "${BLUE}📁 Backing up custom addons: $addon_path${NC}"
        
        # Create addon backup directory
        mkdir -p "$STAGING_DIR/addons"
        cp -r "$addon_path" "$STAGING_DIR/addons/" 2>> "$LOG_FILE"
        
        # Document addon contents
        {
            echo "Addon Directory: $addon_path"
            echo "Modules found:"
            for module in "$addon_path"/*; do
                if [ -d "$module" ] && [ -f "$module/__manifest__.py" -o -f "$module/__openerp__.py" ]; then
                    module_name=$(basename "$module")
                    echo "  - $module_name"
                    
                    # Try to extract module info
                    manifest_file="$module/__manifest__.py"
                    [ ! -f "$manifest_file" ] && manifest_file="$module/__openerp__.py"
                    
                    if [ -f "$manifest_file" ]; then
                        version=$(grep -E "^\s*['\"]version['\"]" "$manifest_file" | head -1 || echo "    'version': 'unknown'")
                        echo "    $version"
                    fi
                fi
            done
            echo ""
        } >> "$ADDON_MANIFEST"
    fi
done

# Backup systemd service files (if they exist)
SYSTEMD_FILES=(
    "/etc/systemd/system/odoo.service"
    "/lib/systemd/system/odoo.service"
    "/usr/lib/systemd/system/odoo.service"
)

for service_file in "${SYSTEMD_FILES[@]}"; do
    if [ -f "$service_file" ]; then
        log_message "${BLUE}📁 Backing up systemd service: $service_file${NC}"
        safe_copy "$service_file" "$STAGING_DIR" "systemd service"
        break
    fi
done

# Backup nginx/apache configuration (if it exists)
WEB_CONFIGS=(
    "/etc/nginx/sites-available/odoo"
    "/etc/nginx/sites-enabled/odoo"
    "/etc/apache2/sites-available/odoo.conf"
    "/etc/apache2/sites-enabled/odoo.conf"
)

for web_config in "${WEB_CONFIGS[@]}"; do
    safe_copy "$web_config" "$STAGING_DIR" "web server configuration"
done

# Create environment documentation
ENV_DOC="$STAGING_DIR/environment_info.txt"
log_message "📋 Documenting system environment..."

{
    echo "System Environment Documentation"
    echo "================================"
    echo "Generated: $(date)"
    echo ""
    
    echo "=== System Information ==="
    echo "OS: $(lsb_release -d 2>/dev/null | cut -f2 || uname -a)"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo ""
    
    echo "=== Python Environment ==="
    echo "Python Version: $(python3 --version 2>&1)"
    echo "Python Path: $(which python3)"
    echo ""
    
    echo "=== PostgreSQL Information ==="
    echo "PostgreSQL Version: $(sudo -u postgres psql -t -c 'SHOW server_version;' 2>/dev/null | xargs || echo 'Not accessible')"
    echo ""
    
    echo "=== Installed Python Packages ==="
    pip3 list | grep -i odoo || echo "No Odoo packages found via pip"
    echo ""
    
    echo "=== Network Configuration ==="
    echo "Listening ports:"
    netstat -tlnp 2>/dev/null | grep -E ":(8069|8072)" || echo "No Odoo ports detected"
    
} > "$ENV_DOC"

# Create restoration guide
RESTORE_GUIDE="$STAGING_DIR/RESTORATION_GUIDE.md"
cat > "$RESTORE_GUIDE" << EOF
# Odoo Configuration Restoration Guide

Generated: $(date)
Source Database: $DB_NAME

## Quick Restoration Steps

### 1. Extract Configuration Backup
\`\`\`bash
tar -xzf $CONFIG_BACKUP -C /tmp/
cd /tmp/odoo_config_backup_*
\`\`\`

### 2. Restore Main Configuration
\`\`\`bash
# Copy main config file
sudo cp odoo.conf /etc/odoo/
sudo chown odoo:odoo /etc/odoo/odoo.conf
sudo chmod 640 /etc/odoo/odoo.conf
\`\`\`

### 3. Restore Custom Addons
\`\`\`bash
# Copy custom addons
sudo cp -r addons/* /opt/odoo/
sudo chown -R odoo:odoo /opt/odoo/custom-addons/
\`\`\`

### 4. Restore System Services
\`\`\`bash
# Restore systemd service (if exists)
sudo cp odoo.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable odoo
\`\`\`

### 5. Update Configuration for New Server
Before starting Odoo, review and update:
- Database connection settings (db_host, db_port, db_user, db_password)
- File paths (data_dir, addons_path)
- Network settings (xmlrpc_interface, xmlrpc_port)

### 6. Start Odoo Service
\`\`\`bash
sudo systemctl start odoo
sudo systemctl status odoo
\`\`\`

## Important Notes
- Review \`config_analysis.txt\` for current settings
- Check \`custom_addons_manifest.txt\` for module list
- Verify \`environment_info.txt\` for system requirements
- Update database name in config if different

## Troubleshooting
If Odoo fails to start:
1. Check log files: \`journalctl -u odoo -f\`
2. Verify database connectivity
3. Confirm all paths in config file exist
4. Ensure proper file ownership and permissions
EOF

# Create the final backup archive
log_message "🗜️  Creating configuration archive..."
cd "$STAGING_DIR"
tar -czf "$CONFIG_BACKUP" . 2>> "$LOG_FILE"

# Cleanup
rm -rf "$STAGING_DIR"

# Verify backup
log_message "🔍 Verifying backup integrity..."
if tar -tzf "$CONFIG_BACKUP" > /dev/null 2>> "$LOG_FILE"; then
    log_message "${GREEN}✅ Configuration backup integrity verified${NC}"
else
    log_message "${RED}❌ ERROR: Configuration backup integrity check failed${NC}"
    exit 1
fi

# Final summary
BACKUP_SIZE=$(du -sh "$CONFIG_BACKUP" | cut -f1)
BACKUP_MD5=$(md5sum "$CONFIG_BACKUP" | cut -d' ' -f1)

log_message ""
log_message "🎉 CONFIGURATION BACKUP COMPLETE!"
log_message "================================="
log_message "✅ Config File: $CONFIG_FILE"
log_message "✅ Custom Addons: ${#UNIQUE_ADDONS[@]} directories"
log_message "✅ Backup: $CONFIG_BACKUP ($BACKUP_SIZE)"
log_message "✅ MD5: $BACKUP_MD5"
log_message "📋 Restoration Guide: Included in backup"
log_message ""
log_message "💡 To restore:"
log_message "   1. Extract: tar -xzf $CONFIG_BACKUP"
log_message "   2. Follow: RESTORATION_GUIDE.md"
log_message ""
log_message "Completed: $(date)"