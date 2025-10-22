#!/bin/bash
# S3 Backup Verification and Notification Script
# Verifies daily Odoo backups in AWS S3 and sends alerts
# Part of "The Definitive Guide to Odoo Database Backup and Restore"
# Created by Aria Shaw - 2025

# Configuration
BUCKET="your-company-odoo-backups"
PREFIX="odoo-backups/$(date +%Y/%m/%d)"
EMAIL="admin@yourcompany.com"
MIN_BACKUP_SIZE=10485760  # 10MB minimum
SLACK_WEBHOOK_URL=""  # Optional: Slack notifications

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[S3-VERIFY]${NC} $1"
}

# Function to send email notification
send_email_alert() {
    local subject="$1"
    local message="$2"
    local priority="$3"  # high, normal, low

    if command -v mail >/dev/null 2>&1; then
        if [ "$priority" = "high" ]; then
            echo "$message" | mail -s "URGENT: $subject" "$EMAIL"
        else
            echo "$message" | mail -s "$subject" "$EMAIL"
        fi
        print_status "Email alert sent to: $EMAIL"
    else
        print_warning "Mail command not available, cannot send email alert"
    fi
}

# Function to send Slack notification (optional)
send_slack_alert() {
    local message="$1"
    local color="$2"  # good, warning, danger

    if [ -n "$SLACK_WEBHOOK_URL" ] && command -v curl >/dev/null 2>&1; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"attachments\":[{\"color\":\"$color\",\"text\":\"$message\"}]}" \
            "$SLACK_WEBHOOK_URL" >/dev/null 2>&1

        if [ $? -eq 0 ]; then
            print_status "Slack notification sent"
        else
            print_warning "Failed to send Slack notification"
        fi
    fi
}

# Function to check AWS CLI availability and credentials
check_aws_setup() {
    if ! command -v aws >/dev/null 2>&1; then
        print_error "AWS CLI not found. Please install AWS CLI first."
        print_error "Install: pip install awscli"
        exit 1
    fi

    # Test AWS credentials
    if ! aws s3 ls >/dev/null 2>&1; then
        print_error "AWS credentials not configured or invalid"
        print_error "Configure: aws configure"
        exit 1
    fi

    print_status "✅ AWS CLI and credentials verified"
}

# Function to verify bucket access
verify_bucket_access() {
    print_status "Verifying S3 bucket access: $BUCKET"

    if aws s3 ls "s3://$BUCKET" >/dev/null 2>&1; then
        print_status "✅ S3 bucket accessible"
        return 0
    else
        print_error "❌ Cannot access S3 bucket: $BUCKET"
        send_email_alert "S3 Bucket Access Failed" \
            "Cannot access S3 bucket: $BUCKET. Please check bucket name and permissions." \
            "high"
        return 1
    fi
}

# Function to check today's backup
check_todays_backup() {
    print_header "🔍 Checking today's backup: $PREFIX"

    # Get list of files in today's backup folder
    TODAY_BACKUP_COUNT=$(aws s3 ls "s3://$BUCKET/$PREFIX/" 2>/dev/null | wc -l)
    TODAY_BACKUPS=$(aws s3 ls "s3://$BUCKET/$PREFIX/" 2>/dev/null)

    print_status "Found $TODAY_BACKUP_COUNT backup files for today"

    if [ "$TODAY_BACKUP_COUNT" -eq 0 ]; then
        print_error "❌ No backup found in S3 for today"
        local error_msg="ERROR: No Odoo backup found in S3 for $(date +%Y-%m-%d)
Bucket: $BUCKET
Path: $PREFIX/

This could indicate:
1. Backup script failed to run
2. Backup upload to S3 failed
3. Network connectivity issues
4. AWS credentials expired

Please investigate immediately."

        send_email_alert "Missing Daily Backup" "$error_msg" "high"
        send_slack_alert "🚨 CRITICAL: Missing daily Odoo backup for $(date +%Y-%m-%d)" "danger"
        return 1
    fi

    # Show backup files found
    print_status "Backup files found:"
    echo "$TODAY_BACKUPS" | while read -r line; do
        if [ -n "$line" ]; then
            echo "  📄 $line"
        fi
    done

    return 0
}

# Function to check backup sizes
check_backup_sizes() {
    print_header "📏 Verifying backup file sizes"

    # Get total size of all files in today's backup
    BACKUP_SIZE_INFO=$(aws s3 ls "s3://$BUCKET/$PREFIX/" --recursive --summarize 2>/dev/null | tail -2)
    TOTAL_SIZE_LINE=$(echo "$BACKUP_SIZE_INFO" | grep "Total Size:")

    if [ -n "$TOTAL_SIZE_LINE" ]; then
        BACKUP_SIZE=$(echo "$TOTAL_SIZE_LINE" | awk '{print $3}')
        BACKUP_SIZE_MB=$(echo "scale=2; $BACKUP_SIZE / 1024 / 1024" | bc 2>/dev/null || echo "0")

        print_status "Total backup size: ${BACKUP_SIZE_MB}MB (${BACKUP_SIZE} bytes)"

        if [ "$BACKUP_SIZE" -lt "$MIN_BACKUP_SIZE" ]; then
            print_warning "⚠️  Backup size seems unusually small"

            local warning_msg="WARNING: Today's Odoo backup size is unusually small
Size: ${BACKUP_SIZE_MB}MB (expected > $(echo "scale=2; $MIN_BACKUP_SIZE / 1024 / 1024" | bc)MB)
Date: $(date +%Y-%m-%d)
Bucket: $BUCKET
Path: $PREFIX/

This could indicate:
1. Partial backup failure
2. Empty or corrupt backup files
3. Database size significantly reduced

Please verify backup integrity manually."

            send_email_alert "Small Backup Size Warning" "$warning_msg" "normal"
            send_slack_alert "⚠️ Odoo backup size warning: ${BACKUP_SIZE_MB}MB ($(date +%Y-%m-%d))" "warning"
            return 1
        else
            print_status "✅ Backup size looks healthy"
            return 0
        fi
    else
        print_warning "Could not determine backup size"
        return 1
    fi
}

# Function to test backup file integrity
test_backup_integrity() {
    print_header "🧪 Testing backup file integrity (sample check)"

    # Find ZIP files in today's backup
    ZIP_FILES=$(aws s3 ls "s3://$BUCKET/$PREFIX/" 2>/dev/null | grep '\.zip$' | awk '{print $4}')

    if [ -n "$ZIP_FILES" ]; then
        # Test first ZIP file found
        FIRST_ZIP=$(echo "$ZIP_FILES" | head -1)
        print_status "Testing ZIP integrity: $FIRST_ZIP"

        # Download first few KB to test ZIP header
        TEMP_FILE="/tmp/backup_test_$(date +%s).zip"
        if aws s3api get-object --bucket "$BUCKET" --key "$PREFIX/$FIRST_ZIP" --range "bytes=0-1023" "$TEMP_FILE" >/dev/null 2>&1; then

            # Check if it starts with ZIP signature
            if file "$TEMP_FILE" 2>/dev/null | grep -q "ZIP\|archive"; then
                print_status "✅ ZIP file header looks valid"
                rm -f "$TEMP_FILE"
                return 0
            else
                print_warning "⚠️  ZIP file header appears invalid"
                rm -f "$TEMP_FILE"
                return 1
            fi
        else
            print_warning "Could not download backup file for testing"
            return 1
        fi
    else
        print_warning "No ZIP files found for integrity testing"
        return 1
    fi
}

# Function to check backup retention
check_backup_retention() {
    print_header "📅 Checking backup retention policy"

    # Check last 7 days for backup consistency
    local missing_days=0
    local total_checked=0

    for i in {1..7}; do
        CHECK_DATE=$(date -d "-$i days" +%Y/%m/%d)
        CHECK_PREFIX="odoo-backups/$CHECK_DATE"

        BACKUP_COUNT=$(aws s3 ls "s3://$BUCKET/$CHECK_PREFIX/" 2>/dev/null | wc -l)

        if [ "$BACKUP_COUNT" -eq 0 ]; then
            print_warning "⚠️  Missing backup for: $CHECK_DATE"
            ((missing_days++))
        else
            print_status "✅ Backup exists for: $CHECK_DATE ($BACKUP_COUNT files)"
        fi

        ((total_checked++))
    done

    RETENTION_SUCCESS_RATE=$(echo "scale=2; ($total_checked - $missing_days) * 100 / $total_checked" | bc)
    print_status "📊 Backup success rate (last 7 days): ${RETENTION_SUCCESS_RATE}%"

    if [ "$missing_days" -gt 2 ]; then
        send_email_alert "Backup Retention Issue" \
            "Multiple missing backups detected in the last 7 days. Missing: $missing_days days out of $total_checked checked." \
            "normal"
    fi
}

# Function to generate verification report
generate_report() {
    local status="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local report_file="/var/log/s3_backup_verification_$(date +%Y%m%d).log"

    cat >> "$report_file" << EOF
========================================
S3 Backup Verification Report
========================================
Timestamp: $timestamp
Status: $status
Bucket: $BUCKET
Path: $PREFIX/
Email: $EMAIL

Verification Results:
- Backup Existence: $([ "$backup_exists" = "0" ] && echo "PASS" || echo "FAIL")
- Size Check: $([ "$size_check" = "0" ] && echo "PASS" || echo "FAIL")
- Integrity Test: $([ "$integrity_check" = "0" ] && echo "PASS" || echo "WARN")

========================================
EOF

    print_status "📄 Report saved to: $report_file"
}

# Main execution
main() {
    print_header "🚀 Starting S3 Backup Verification"
    print_header "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    print_header "Bucket: $BUCKET"
    print_header "Path: $PREFIX/"

    # Initialize status variables
    backup_exists=1
    size_check=1
    integrity_check=1

    # Step 1: Check AWS setup
    check_aws_setup

    # Step 2: Verify bucket access
    if ! verify_bucket_access; then
        generate_report "CRITICAL_FAILURE"
        exit 1
    fi

    # Step 3: Check today's backup
    if check_todays_backup; then
        backup_exists=0
    fi

    # Step 4: Check backup sizes (only if backup exists)
    if [ "$backup_exists" = "0" ]; then
        if check_backup_sizes; then
            size_check=0
        fi

        # Step 5: Test backup integrity
        if test_backup_integrity; then
            integrity_check=0
        fi
    fi

    # Step 6: Check backup retention
    check_backup_retention

    # Final status
    if [ "$backup_exists" = "0" ] && [ "$size_check" = "0" ]; then
        print_status "🎉 S3 backup verification completed successfully"
        send_slack_alert "✅ Daily Odoo backup verification passed ($(date +%Y-%m-%d))" "good"
        generate_report "SUCCESS"
        exit 0
    else
        print_error "❌ S3 backup verification failed"
        generate_report "FAILURE"
        exit 1
    fi
}

# Show usage if no bucket configured
if [ "$BUCKET" = "your-company-odoo-backups" ]; then
    echo "S3 Backup Verification Script"
    echo "============================"
    echo ""
    echo "Please configure the script by editing the variables at the top:"
    echo "- BUCKET: Your S3 bucket name"
    echo "- EMAIL: Alert notification email"
    echo "- SLACK_WEBHOOK_URL: Optional Slack webhook"
    echo ""
    echo "Usage: $0"
    echo ""
    exit 1
fi

# Run main function
main "$@"