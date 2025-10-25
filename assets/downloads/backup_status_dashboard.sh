#!/bin/bash
# Backup Status Dashboard Generator
# Creates a web-based dashboard showing backup status and health
# Part of "The Definitive Guide to Odoo Database Backup and Restore"
# Created by Aria Shaw - 2025

# Configuration
HTML_FILE="/var/www/html/backup-status.html"
BACKUP_DIR="/backup/odoo"
S3_BUCKET="your-company-odoo-backups"
REFRESH_INTERVAL=300  # 5 minutes

# Colors and icons for status
SUCCESS_COLOR="green"
WARNING_COLOR="orange"
ERROR_COLOR="red"

# Function to generate CSS styles
generate_css() {
    cat << 'EOF'
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 10px;
            margin-bottom: 20px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .header h1 { margin: 0; }
        .header p { margin: 5px 0 0 0; opacity: 0.9; }

        .dashboard { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
        .card {
            background: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .card h2 {
            margin-top: 0;
            color: #333;
            border-bottom: 2px solid #eee;
            padding-bottom: 10px;
        }

        .success { color: #28a745; font-weight: bold; }
        .warning { color: #ffc107; font-weight: bold; }
        .error { color: #dc3545; font-weight: bold; }

        table {
            border-collapse: collapse;
            width: 100%;
            background: white;
        }
        th, td {
            border: 1px solid #ddd;
            padding: 12px 8px;
            text-align: left;
        }
        th {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            font-weight: bold;
        }

        .metrics {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin: 20px 0;
        }
        .metric {
            text-align: center;
            padding: 15px;
            background: #f8f9fa;
            border-radius: 8px;
            border-left: 4px solid #007bff;
        }
        .metric-value {
            font-size: 2em;
            font-weight: bold;
            color: #007bff;
            margin-bottom: 5px;
        }
        .metric-label {
            color: #666;
            font-size: 0.9em;
        }

        .status-indicator {
            display: inline-block;
            width: 12px;
            height: 12px;
            border-radius: 50%;
            margin-right: 8px;
        }
        .status-ok { background-color: #28a745; }
        .status-warning { background-color: #ffc107; }
        .status-error { background-color: #dc3545; }

        .progress-bar {
            width: 100%;
            height: 20px;
            background-color: #e9ecef;
            border-radius: 10px;
            overflow: hidden;
            margin: 10px 0;
        }
        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #28a745 0%, #20c997 100%);
            transition: width 0.3s ease;
        }

        pre {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 5px;
            overflow-x: auto;
            border-left: 4px solid #007bff;
        }

        .footer {
            text-align: center;
            margin-top: 30px;
            padding: 20px;
            background: #343a40;
            color: white;
            border-radius: 10px;
        }

        .refresh-info {
            position: fixed;
            top: 20px;
            right: 20px;
            background: rgba(0,0,0,0.8);
            color: white;
            padding: 10px 15px;
            border-radius: 20px;
            font-size: 0.9em;
        }

        @media (max-width: 768px) {
            .dashboard { grid-template-columns: 1fr; }
            .metrics { grid-template-columns: 1fr; }
        }
    </style>
EOF
}

# Function to check backup health and generate status
check_backup_status() {
    local backup_file="$1"
    local status="success"
    local message="✓ Success"

    # Check if file exists and is not empty
    if [ ! -f "$backup_file" ] || [ ! -s "$backup_file" ]; then
        status="error"
        message="❌ Missing/Empty"
        echo "$status|$message"
        return
    fi

    # Check file age (warn if older than 48 hours)
    local file_age=$(( ($(date +%s) - $(stat -c %Y "$backup_file" 2>/dev/null || stat -f %m "$backup_file" 2>/dev/null || echo 0)) / 3600 ))
    if [ $file_age -gt 48 ]; then
        status="warning"
        message="⚠️ Old (${file_age}h)"
    fi

    # Quick integrity check for ZIP files
    if [[ "$backup_file" == *.zip ]] && command -v unzip >/dev/null 2>&1; then
        if ! unzip -t "$backup_file" >/dev/null 2>&1; then
            status="error"
            message="❌ Corrupted"
        fi
    fi

    echo "$status|$message"
}

# Function to get storage usage percentage
get_storage_usage() {
    if [ -d "$BACKUP_DIR" ]; then
        df "$BACKUP_DIR" | awk 'NR==2{gsub("%",""); print $5}' || echo "0"
    else
        echo "0"
    fi
}

# Function to get backup count by type
get_backup_counts() {
    local total=0
    local daily=0
    local weekly=0
    local monthly=0

    if [ -d "$BACKUP_DIR" ]; then
        total=$(find "$BACKUP_DIR" -name "*.zip" -type f 2>/dev/null | wc -l)
        daily=$(find "$BACKUP_DIR" -name "*daily*.zip" -type f 2>/dev/null | wc -l)
        weekly=$(find "$BACKUP_DIR" -name "*weekly*.zip" -type f 2>/dev/null | wc -l)
        monthly=$(find "$BACKUP_DIR" -name "*monthly*.zip" -type f 2>/dev/null | wc -l)
    fi

    echo "$total|$daily|$weekly|$monthly"
}

# Function to check S3 status
check_s3_status() {
    if [ "$S3_BUCKET" = "your-company-odoo-backups" ] || ! command -v aws >/dev/null 2>&1; then
        echo "Not configured"
        return
    fi

    if aws s3 ls "s3://$S3_BUCKET/" >/dev/null 2>&1; then
        local recent_count=$(aws s3 ls "s3://$S3_BUCKET/odoo-backups/" --recursive 2>/dev/null | \
            awk -v date="$(date -d '7 days ago' +%Y-%m-%d)" '$1 >= date' | wc -l)
        echo "✅ Connected ($recent_count recent)"
    else
        echo "❌ Connection failed"
    fi
}

# Main function to generate dashboard
generate_dashboard() {
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')
    local backup_counts=$(get_backup_counts)
    local total_backups=$(echo "$backup_counts" | cut -d'|' -f1)
    local daily_backups=$(echo "$backup_counts" | cut -d'|' -f2)
    local weekly_backups=$(echo "$backup_counts" | cut -d'|' -f3)
    local monthly_backups=$(echo "$backup_counts" | cut -d'|' -f4)
    local storage_usage=$(get_storage_usage)
    local s3_status=$(check_s3_status)

    # Create HTML file
    cat > "$HTML_FILE" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Odoo Backup Status Dashboard</title>
    <meta http-equiv="refresh" content="$REFRESH_INTERVAL">
    $(generate_css)
</head>
<body>
    <div class="refresh-info">
        🔄 Auto-refresh: ${REFRESH_INTERVAL}s
    </div>

    <div class="header">
        <h1>🔐 Odoo Backup Status Dashboard</h1>
        <p>Last updated: $current_time | Directory: $BACKUP_DIR</p>
    </div>

    <div class="metrics">
        <div class="metric">
            <div class="metric-value">$total_backups</div>
            <div class="metric-label">Total Backups</div>
        </div>
        <div class="metric">
            <div class="metric-value">$daily_backups</div>
            <div class="metric-label">Daily Backups</div>
        </div>
        <div class="metric">
            <div class="metric-value">$weekly_backups</div>
            <div class="metric-label">Weekly Backups</div>
        </div>
        <div class="metric">
            <div class="metric-value">$storage_usage%</div>
            <div class="metric-label">Storage Used</div>
        </div>
    </div>

    <div class="dashboard">
        <div class="card">
            <h2>📁 Recent Backups</h2>
            <table>
                <tr>
                    <th>Status</th>
                    <th>Date</th>
                    <th>Filename</th>
                    <th>Size</th>
                    <th>Age</th>
                </tr>
EOF

    # Add backup entries
    local count=0
    for backup in $(ls -t "$BACKUP_DIR"/*.zip 2>/dev/null | head -15); do
        if [ -f "$backup" ]; then
            local filename=$(basename "$backup")
            local size=$(du -h "$backup" 2>/dev/null | cut -f1 || echo "?")
            local date=$(date -r "$backup" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "Unknown")
            local file_age=$(( ($(date +%s) - $(stat -c %Y "$backup" 2>/dev/null || stat -f %m "$backup" 2>/dev/null || echo 0)) / 3600 ))
            local age_text="${file_age}h"

            local status_info=$(check_backup_status "$backup")
            local status_class=$(echo "$status_info" | cut -d'|' -f1)
            local status_message=$(echo "$status_info" | cut -d'|' -f2)

            cat >> "$HTML_FILE" << EOF
                <tr>
                    <td class="$status_class">
                        <span class="status-indicator status-$([ "$status_class" = "success" ] && echo "ok" || echo "$status_class")"></span>
                        $status_message
                    </td>
                    <td>$date</td>
                    <td>$filename</td>
                    <td>$size</td>
                    <td>$age_text</td>
                </tr>
EOF
            ((count++))
        fi
    done

    if [ $count -eq 0 ]; then
        cat >> "$HTML_FILE" << EOF
                <tr>
                    <td colspan="5" style="text-align: center; color: #666;">No backup files found</td>
                </tr>
EOF
    fi

    # Continue with storage and system info
    cat >> "$HTML_FILE" << EOF
            </table>
        </div>

        <div class="card">
            <h2>💾 Storage & System Status</h2>

            <h3>Storage Usage</h3>
            <div class="progress-bar">
                <div class="progress-fill" style="width: ${storage_usage}%"></div>
            </div>
            <p>Disk usage: ${storage_usage}% of backup directory</p>

            <pre>$(df -h "$BACKUP_DIR" 2>/dev/null || echo "Backup directory not found: $BACKUP_DIR")</pre>

            <h3>☁️ Cloud Storage Status</h3>
            <p><span class="status-indicator $([ "$s3_status" = *"✅"* ] && echo "status-ok" || echo "status-warning")"></span>S3: $s3_status</p>

            $(if [ "$s3_status" != "Not configured" ] && [ "$s3_status" != "❌ Connection failed" ]; then
                echo "<pre>$(aws s3 ls "s3://$S3_BUCKET/odoo-backups/" 2>/dev/null | tail -5 || echo "No recent S3 files")</pre>"
            fi)
        </div>
    </div>

    <div class="card" style="margin-top: 20px;">
        <h2>📊 System Health Check</h2>
        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 15px;">

            <div>
                <h4>🔍 Last Backup Check</h4>
                $(
                    if [ -n "$(ls -t "$BACKUP_DIR"/*.zip 2>/dev/null | head -1)" ]; then
                        latest_backup=$(ls -t "$BACKUP_DIR"/*.zip 2>/dev/null | head -1)
                        latest_age=$(( ($(date +%s) - $(stat -c %Y "$latest_backup" 2>/dev/null || stat -f %m "$latest_backup" 2>/dev/null || echo 0)) / 3600 ))

                        if [ $latest_age -le 24 ]; then
                            echo "<span class='success'>✅ Recent backup found (${latest_age}h ago)</span>"
                        elif [ $latest_age -le 48 ]; then
                            echo "<span class='warning'>⚠️ Last backup ${latest_age}h ago</span>"
                        else
                            echo "<span class='error'>❌ No recent backups (${latest_age}h ago)</span>"
                        fi
                    else
                        echo "<span class='error'>❌ No backups found</span>"
                    fi
                )
            </div>

            <div>
                <h4>💿 Disk Space</h4>
                $(
                    if [ $storage_usage -lt 80 ]; then
                        echo "<span class='success'>✅ Sufficient space (${storage_usage}% used)</span>"
                    elif [ $storage_usage -lt 95 ]; then
                        echo "<span class='warning'>⚠️ Space running low (${storage_usage}% used)</span>"
                    else
                        echo "<span class='error'>❌ Disk almost full (${storage_usage}% used)</span>"
                    fi
                )
            </div>

            <div>
                <h4>🔧 Backup Tools</h4>
                $(
                    tools_status=""
                    [ -x "$(command -v pg_dump)" ] && tools_status="$tools_status PostgreSQL ✓"
                    [ -x "$(command -v aws)" ] && tools_status="$tools_status AWS-CLI ✓"
                    [ -x "$(command -v curl)" ] && tools_status="$tools_status cURL ✓"

                    if [ -n "$tools_status" ]; then
                        echo "<span class='success'>$tools_status</span>"
                    else
                        echo "<span class='warning'>⚠️ Some tools missing</span>"
                    fi
                )
            </div>

        </div>
    </div>

    <div class="footer">
        <p>🛡️ Backup Status Dashboard | Generated by Aria Shaw's Odoo Backup Guide</p>
        <p>For complete backup management, visit: <a href="https://ariashaw.com" style="color: #17a2b8;">ariashaw.github.io</a></p>
    </div>

</body>
</html>
EOF

    echo "✅ Backup status dashboard updated: $HTML_FILE"
}

# Function to show usage
show_usage() {
    echo "Backup Status Dashboard Generator"
    echo "================================"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --output FILE    Specify output HTML file (default: $HTML_FILE)"
    echo "  --refresh SEC    Set refresh interval in seconds (default: $REFRESH_INTERVAL)"
    echo "  --help          Show this help message"
    echo ""
    echo "Configuration:"
    echo "Edit the script to configure:"
    echo "• HTML_FILE: Output path for dashboard"
    echo "• BACKUP_DIR: Backup directory to monitor"
    echo "• S3_BUCKET: AWS S3 bucket name"
    echo ""
    echo "Setup:"
    echo "1. Configure web server to serve the HTML file"
    echo "2. Add to cron for automatic updates:"
    echo "   */5 * * * * /path/to/backup_status_dashboard.sh"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --output)
            HTML_FILE="$2"
            shift 2
            ;;
        --refresh)
            REFRESH_INTERVAL="$2"
            shift 2
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Create output directory if it doesn't exist
HTML_DIR=$(dirname "$HTML_FILE")
if [ ! -d "$HTML_DIR" ]; then
    echo "Creating output directory: $HTML_DIR"
    mkdir -p "$HTML_DIR"
fi

# Check if we can write to output file
if ! touch "$HTML_FILE" 2>/dev/null; then
    echo "Error: Cannot write to $HTML_FILE"
    echo "Please check permissions or run as appropriate user"
    exit 1
fi

# Generate the dashboard
generate_dashboard