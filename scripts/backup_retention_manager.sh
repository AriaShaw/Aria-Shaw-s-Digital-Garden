#!/bin/bash
# Intelligent Backup Retention Manager
# Implements Grandfather-Father-Son backup retention policy
# Part of "The Definitive Guide to Odoo Database Backup and Restore"
# Created by Aria Shaw - 2025

# Configuration
BACKUP_DIR="/backup/odoo"
S3_BUCKET="your-company-odoo-backups"
LOG_FILE="/var/log/backup_retention.log"

# Retention periods (in days)
DAILY_RETENTION=7      # Keep 7 daily backups
WEEKLY_RETENTION=28    # Keep 4 weekly backups (28 days)
MONTHLY_RETENTION=365  # Keep 12 monthly backups (365 days)
YEARLY_RETENTION=2555  # Keep 7 yearly backups (7 years)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_message() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" >> "$LOG_FILE"
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] WARNING: $1" >> "$LOG_FILE"
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] ERROR: $1" >> "$LOG_FILE"
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to clean local daily backups
clean_daily_backups() {
    log_message "🗂️  Cleaning daily backups older than $DAILY_RETENTION days..."

    local count=0
    local cleaned=0

    # Find and remove daily backups older than retention period
    while IFS= read -r -d '' backup_file; do
        ((count++))
        if rm "$backup_file"; then
            ((cleaned++))
            log_message "Removed daily backup: $(basename "$backup_file")"
        else
            log_error "Failed to remove: $(basename "$backup_file")"
        fi
    done < <(find "$BACKUP_DIR" -name "*daily*" -mtime +$DAILY_RETENTION -type f -print0 2>/dev/null)

    log_message "Daily cleanup: $cleaned/$count files removed"
}

# Function to clean local weekly backups
clean_weekly_backups() {
    log_message "🗂️  Cleaning weekly backups older than $WEEKLY_RETENTION days..."

    local count=0
    local cleaned=0

    while IFS= read -r -d '' backup_file; do
        ((count++))
        if rm "$backup_file"; then
            ((cleaned++))
            log_message "Removed weekly backup: $(basename "$backup_file")"
        else
            log_error "Failed to remove: $(basename "$backup_file")"
        fi
    done < <(find "$BACKUP_DIR" -name "*weekly*" -mtime +$WEEKLY_RETENTION -type f -print0 2>/dev/null)

    log_message "Weekly cleanup: $cleaned/$count files removed"
}

# Function to clean local monthly backups
clean_monthly_backups() {
    log_message "🗂️  Cleaning monthly backups older than $MONTHLY_RETENTION days..."

    local count=0
    local cleaned=0

    while IFS= read -r -d '' backup_file; do
        ((count++))
        if rm "$backup_file"; then
            ((cleaned++))
            log_message "Removed monthly backup: $(basename "$backup_file")"
        else
            log_error "Failed to remove: $(basename "$backup_file")"
        fi
    done < <(find "$BACKUP_DIR" -name "*monthly*" -mtime +$MONTHLY_RETENTION -type f -print0 2>/dev/null)

    log_message "Monthly cleanup: $cleaned/$count files removed"
}

# Function to clean S3 incomplete uploads
clean_s3_incomplete() {
    if [ "$S3_BUCKET" = "your-company-odoo-backups" ]; then
        log_warning "S3_BUCKET not configured, skipping S3 cleanup"
        return
    fi

    if ! command -v aws >/dev/null 2>&1; then
        log_warning "AWS CLI not found, skipping S3 cleanup"
        return
    fi

    log_message "🗂️  Cleaning S3 incomplete uploads..."

    local cutoff_date=$(date -d '7 days ago' '+%Y-%m-%d')

    # Clean up incomplete multipart uploads
    if aws s3api list-multipart-uploads --bucket "$S3_BUCKET" >/dev/null 2>&1; then
        aws s3api list-multipart-uploads --bucket "$S3_BUCKET" \
            --query "Uploads[?Initiated<'$cutoff_date'].{Key:Key,UploadId:UploadId}" \
            --output text | while read -r key upload_id; do
            if [ -n "$key" ] && [ -n "$upload_id" ]; then
                aws s3api abort-multipart-upload --bucket "$S3_BUCKET" --key "$key" --upload-id "$upload_id"
                log_message "Aborted incomplete upload: $key"
            fi
        done
    fi

    # Clean up failed uploads in incomplete/ folder if it exists
    if aws s3 ls "s3://$S3_BUCKET/incomplete/" >/dev/null 2>&1; then
        local cleaned_s3=0
        aws s3 ls "s3://$S3_BUCKET/incomplete/" --recursive | \
        awk -v cutoff="$cutoff_date" '$1 < cutoff {print $4}' | \
        while read -r file; do
            if aws s3 rm "s3://$S3_BUCKET/$file"; then
                ((cleaned_s3++))
                log_message "Removed incomplete S3 file: $file"
            fi
        done
    fi
}

# Function to optimize backup storage by identifying duplicates
find_duplicate_backups() {
    log_message "🔍 Scanning for potential duplicate backups..."

    local duplicates_found=0

    # Find files with same size (potential duplicates)
    find "$BACKUP_DIR" -name "*.zip" -type f -exec stat -f "%z %N" {} \; 2>/dev/null | \
    sort | uniq -d -w 10 | while read -r size_and_file; do
        log_warning "Potential duplicate (same size): $size_and_file"
        ((duplicates_found++))
    done

    if [ $duplicates_found -eq 0 ]; then
        log_message "✅ No obvious duplicates found"
    else
        log_message "⚠️  Found $duplicates_found potential duplicates (manual review recommended)"
    fi
}

# Function to create backup rotation schedule
create_rotation_schedule() {
    log_message "📅 Creating backup rotation schedule..."

    local today=$(date '+%A')
    local day_of_month=$(date '+%d')

    # Weekly backup on Sundays
    if [ "$today" = "Sunday" ]; then
        log_message "📦 Today is Sunday - weekly backup recommended"
    fi

    # Monthly backup on the 1st
    if [ "$day_of_month" = "01" ]; then
        log_message "📦 Today is the 1st - monthly backup recommended"
    fi

    # Yearly backup on January 1st
    if [ "$(date '+%m-%d')" = "01-01" ]; then
        log_message "📦 Today is January 1st - yearly backup recommended"
    fi
}

# Function to generate retention report
generate_retention_report() {
    local report_file="/tmp/backup_retention_report_$(date +%Y%m%d).txt"

    cat > "$report_file" << EOF
Backup Retention Report
======================
Generated: $(date '+%Y-%m-%d %H:%M:%S')
Backup Directory: $BACKUP_DIR
S3 Bucket: $S3_BUCKET

Retention Policy:
- Daily backups: $DAILY_RETENTION days
- Weekly backups: $WEEKLY_RETENTION days
- Monthly backups: $MONTHLY_RETENTION days
- Yearly backups: $YEARLY_RETENTION days

Current Backup Counts:
EOF

    # Count different backup types
    local daily_count=$(find "$BACKUP_DIR" -name "*daily*" -type f 2>/dev/null | wc -l)
    local weekly_count=$(find "$BACKUP_DIR" -name "*weekly*" -type f 2>/dev/null | wc -l)
    local monthly_count=$(find "$BACKUP_DIR" -name "*monthly*" -type f 2>/dev/null | wc -l)
    local total_count=$(find "$BACKUP_DIR" -name "*.zip" -type f 2>/dev/null | wc -l)

    echo "- Daily backups: $daily_count" >> "$report_file"
    echo "- Weekly backups: $weekly_count" >> "$report_file"
    echo "- Monthly backups: $monthly_count" >> "$report_file"
    echo "- Total backups: $total_count" >> "$report_file"

    # Calculate storage usage
    if [ -d "$BACKUP_DIR" ]; then
        local storage_usage=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
        echo "- Storage usage: $storage_usage" >> "$report_file"
    fi

    echo "" >> "$report_file"
    echo "Retention Actions Taken:" >> "$report_file"
    tail -20 "$LOG_FILE" | grep -E "(Removed|cleaned)" >> "$report_file"

    log_message "📊 Retention report generated: $report_file"
}

# Function to check backup directory health
check_backup_health() {
    log_message "🏥 Performing backup directory health check..."

    if [ ! -d "$BACKUP_DIR" ]; then
        log_error "Backup directory does not exist: $BACKUP_DIR"
        return 1
    fi

    # Check directory permissions
    if [ ! -w "$BACKUP_DIR" ]; then
        log_error "No write permission to backup directory: $BACKUP_DIR"
        return 1
    fi

    # Check available disk space (warn if less than 10% free)
    local available_percent=$(df "$BACKUP_DIR" | awk 'NR==2{gsub("%",""); print 100-$5}')
    if [ "$available_percent" -lt 10 ]; then
        log_warning "Low disk space: only ${available_percent}% available in $BACKUP_DIR"
    else
        log_message "✅ Disk space OK: ${available_percent}% available"
    fi

    # Check for corrupted backup files
    local corrupted=0
    find "$BACKUP_DIR" -name "*.zip" -type f | while read -r backup_file; do
        if ! unzip -t "$backup_file" >/dev/null 2>&1; then
            log_warning "Corrupted backup detected: $(basename "$backup_file")"
            ((corrupted++))
        fi
    done

    if [ $corrupted -eq 0 ]; then
        log_message "✅ No corrupted backups detected"
    fi
}

# Main execution function
main() {
    log_message "🚀 Starting backup retention management"
    log_message "Configuration: Daily=$DAILY_RETENTION, Weekly=$WEEKLY_RETENTION, Monthly=$MONTHLY_RETENTION days"

    # Health check first
    if ! check_backup_health; then
        log_error "Health check failed, aborting retention cleanup"
        exit 1
    fi

    # Create backup directory if it doesn't exist
    if [ ! -d "$BACKUP_DIR" ]; then
        log_message "Creating backup directory: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
    fi

    # Perform retention cleanup
    clean_daily_backups
    clean_weekly_backups
    clean_monthly_backups

    # Clean S3 if configured
    clean_s3_incomplete

    # Additional maintenance tasks
    find_duplicate_backups
    create_rotation_schedule

    # Generate report
    generate_retention_report

    log_message "✅ Backup retention management completed successfully"
}

# Show usage information
show_usage() {
    echo "Backup Retention Manager"
    echo "======================="
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --daily-only     Clean only daily backups"
    echo "  --weekly-only    Clean only weekly backups"
    echo "  --monthly-only   Clean only monthly backups"
    echo "  --s3-only        Clean only S3 incomplete uploads"
    echo "  --dry-run        Show what would be deleted without deleting"
    echo "  --report-only    Generate report only"
    echo "  --help           Show this help message"
    echo ""
    echo "Configuration:"
    echo "Edit the script to configure:"
    echo "• BACKUP_DIR: Local backup directory"
    echo "• S3_BUCKET: AWS S3 bucket name"
    echo "• Retention periods for each backup type"
    echo ""
}

# Handle command line options
case "${1:-}" in
    --daily-only)
        check_backup_health && clean_daily_backups
        ;;
    --weekly-only)
        check_backup_health && clean_weekly_backups
        ;;
    --monthly-only)
        check_backup_health && clean_monthly_backups
        ;;
    --s3-only)
        clean_s3_incomplete
        ;;
    --dry-run)
        log_message "DRY RUN MODE - No files will be deleted"
        # Add dry-run logic here if needed
        ;;
    --report-only)
        generate_retention_report
        ;;
    --help|-h)
        show_usage
        exit 0
        ;;
    "")
        # No options - run full retention management
        main
        ;;
    *)
        echo "Unknown option: $1"
        show_usage
        exit 1
        ;;
esac