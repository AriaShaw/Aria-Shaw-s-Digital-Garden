#!/bin/bash
# Comprehensive Filestore Backup Verification Script
# Ensures filestore backups contain all expected files
# Part of "The Definitive Guide to Odoo Database Backup and Restore"
# Created by Aria Shaw - 2025

# Configuration
DB_NAME="${1:-your_database}"
FILESTORE_BASE_PATH="/var/lib/odoo/filestore"
FILESTORE_PATH="$FILESTORE_BASE_PATH/$DB_NAME"
BACKUP_DIR="${BACKUP_DIR:-/backup/odoo}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/filestore_${DB_NAME}_${TIMESTAMP}.tar.gz"

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
    echo -e "${BLUE}[FILESTORE]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Filestore Backup Verification Script"
    echo "===================================="
    echo ""
    echo "Usage: $0 [database_name] [options]"
    echo ""
    echo "Options:"
    echo "  --backup-only      Create backup without verification"
    echo "  --verify-only      Verify existing backup file"
    echo "  --backup-file FILE Specify backup file path"
    echo "  --help             Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  BACKUP_DIR         Backup directory (default: /backup/odoo)"
    echo "  FILESTORE_BASE_PATH Base filestore path (default: /var/lib/odoo/filestore)"
    echo ""
    echo "Examples:"
    echo "  $0 production_db"
    echo "  $0 staging_db --backup-file /tmp/staging_filestore.tar.gz"
    echo "  BACKUP_DIR=/mnt/backups $0 production_db"
    echo ""
}

# Function to check database connectivity
check_database_connectivity() {
    print_header "🔍 Checking database connectivity for: $DB_NAME"

    if ! sudo -u postgres psql -l | grep -q "^ $DB_NAME "; then
        print_error "Database '$DB_NAME' not found in PostgreSQL"
        print_error "Available databases:"
        sudo -u postgres psql -l | grep -E "^ [a-zA-Z]" | awk '{print "  - " $1}'
        return 1
    fi

    print_status "✅ Database '$DB_NAME' found and accessible"
    return 0
}

# Function to count attachment records in database
count_database_attachments() {
    print_header "📊 Counting attachment records in database"

    local db_files
    db_files=$(sudo -u postgres psql -d "$DB_NAME" -t -c \
        "SELECT COUNT(*) FROM ir_attachment WHERE store_fname IS NOT NULL AND store_fname != '';" 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$db_files" ]; then
        print_warning "Could not query ir_attachment table"
        print_warning "Database might not be an Odoo database or is inaccessible"
        return 1
    fi

    # Remove whitespace
    db_files=$(echo "$db_files" | tr -d ' ')

    print_status "Database attachment records with files: $db_files"
    echo "$db_files"
    return 0
}

# Function to analyze filestore structure
analyze_filestore() {
    print_header "📁 Analyzing filestore structure: $FILESTORE_PATH"

    if [ ! -d "$FILESTORE_PATH" ]; then
        print_warning "Filestore directory not found: $FILESTORE_PATH"
        print_warning "This might be normal for databases without file uploads"
        return 1
    fi

    # Count files
    local fs_files
    fs_files=$(find "$FILESTORE_PATH" -type f 2>/dev/null | wc -l)

    # Count directories
    local fs_dirs
    fs_dirs=$(find "$FILESTORE_PATH" -type d 2>/dev/null | wc -l)

    # Calculate total size
    local fs_size
    fs_size=$(du -sh "$FILESTORE_PATH" 2>/dev/null | cut -f1)

    # Check for symlinks
    local symlinks
    symlinks=$(find "$FILESTORE_PATH" -type l 2>/dev/null | wc -l)

    print_status "Filestore files: $fs_files"
    print_status "Filestore directories: $fs_dirs"
    print_status "Filestore size: $fs_size"

    if [ "$symlinks" -gt 0 ]; then
        print_status "Symbolic links found: $symlinks (deduplication active)"
    fi

    # Check for common filestore structure
    if [ -d "$FILESTORE_PATH" ]; then
        local bucket_dirs
        bucket_dirs=$(find "$FILESTORE_PATH" -mindepth 1 -maxdepth 1 -type d -name "[0-9][0-9]" | wc -l)
        if [ "$bucket_dirs" -gt 0 ]; then
            print_status "✅ Standard filestore structure detected ($bucket_dirs bucket directories)"
        else
            print_warning "⚠️  Non-standard filestore structure - files not in bucket directories"
        fi
    fi

    echo "$fs_files"
    return 0
}

# Function to create filestore backup
create_filestore_backup() {
    local target_file="$1"

    print_header "📦 Creating filestore backup: $(basename "$target_file")"

    # Create backup directory if it doesn't exist
    mkdir -p "$(dirname "$target_file")"

    if [ ! -d "$FILESTORE_PATH" ]; then
        print_warning "No filestore directory found - creating empty backup marker"
        echo "No filestore data for database: $DB_NAME" > "${target_file%.tar.gz}.txt"
        return 2
    fi

    # Check available disk space
    local backup_dir
    backup_dir=$(dirname "$target_file")
    local available_space
    available_space=$(df "$backup_dir" | awk 'NR==2{print $4}')
    local filestore_size
    filestore_size=$(du -sk "$FILESTORE_PATH" | cut -f1)

    if [ "$available_space" -lt $((filestore_size * 2)) ]; then
        print_error "Insufficient disk space for backup"
        print_error "Required: ~$((filestore_size * 2 / 1024))MB, Available: $((available_space / 1024))MB"
        return 1
    fi

    # Create the backup with compression
    print_status "Compressing filestore data..."
    if tar -czf "$target_file" -C "$FILESTORE_BASE_PATH" "$DB_NAME" 2>/dev/null; then
        print_status "✅ Backup created successfully"
        return 0
    else
        print_error "❌ Failed to create backup"
        return 1
    fi
}

# Function to verify backup integrity
verify_backup_integrity() {
    local backup_file="$1"

    print_header "🔍 Verifying backup integrity: $(basename "$backup_file")"

    if [ ! -f "$backup_file" ]; then
        print_error "Backup file not found: $backup_file"
        return 1
    fi

    # Test tar file integrity
    print_status "Testing archive integrity..."
    if tar -tzf "$backup_file" >/dev/null 2>&1; then
        print_status "✅ Archive integrity check passed"
    else
        print_error "❌ Archive is corrupted or invalid"
        return 1
    fi

    # Count files in backup
    local backup_files
    backup_files=$(tar -tzf "$backup_file" | grep -v '/$' | wc -l)

    print_status "Files in backup: $backup_files"

    # Get backup file size
    local backup_size
    backup_size=$(du -h "$backup_file" | cut -f1)
    print_status "Backup file size: $backup_size"

    echo "$backup_files"
    return 0
}

# Function to compare database vs filestore vs backup
perform_comprehensive_comparison() {
    local backup_file="$1"

    print_header "🔄 Performing comprehensive verification"

    # Get counts from all sources
    local db_count fs_count backup_count

    print_status "Gathering data from all sources..."

    # Database count
    db_count=$(count_database_attachments)
    local db_status=$?

    # Filestore count
    fs_count=$(analyze_filestore)
    local fs_status=$?

    # Backup count
    if [ -f "$backup_file" ]; then
        backup_count=$(verify_backup_integrity "$backup_file")
        local backup_status=$?
    else
        backup_count=0
        backup_status=1
    fi

    # Summary table
    print_header "📋 Verification Summary"
    echo "+" + "=" * 50 + "+"
    printf "| %-20s | %-10s | %-10s |\n" "Source" "Count" "Status"
    echo "+" + "=" * 50 + "+"

    if [ $db_status -eq 0 ]; then
        printf "| %-20s | %-10s | %-10s |\n" "Database Records" "$db_count" "✅ OK"
    else
        printf "| %-20s | %-10s | %-10s |\n" "Database Records" "N/A" "❌ ERROR"
    fi

    if [ $fs_status -eq 0 ]; then
        printf "| %-20s | %-10s | %-10s |\n" "Filestore Files" "$fs_count" "✅ OK"
    elif [ $fs_status -eq 1 ]; then
        printf "| %-20s | %-10s | %-10s |\n" "Filestore Files" "0" "⚠️  NONE"
    fi

    if [ $backup_status -eq 0 ]; then
        printf "| %-20s | %-10s | %-10s |\n" "Backup Files" "$backup_count" "✅ OK"
    else
        printf "| %-20s | %-10s | %-10s |\n" "Backup Files" "N/A" "❌ ERROR"
    fi

    echo "+" + "=" * 50 + "+"

    # Analysis and recommendations
    print_header "💡 Analysis and Recommendations"

    local issues_found=0

    # Check for mismatches
    if [ $db_status -eq 0 ] && [ $fs_status -eq 0 ]; then
        if [ "$db_count" -ne "$fs_count" ]; then
            print_warning "Mismatch between database records ($db_count) and filestore files ($fs_count)"
            print_warning "This could indicate:"
            print_warning "  • Orphaned files in filestore"
            print_warning "  • Missing files for database records"
            print_warning "  • Deduplication or symlinks in use"
            ((issues_found++))
        else
            print_status "✅ Database and filestore counts match perfectly"
        fi
    fi

    if [ $backup_status -eq 0 ] && [ $fs_status -eq 0 ]; then
        if [ "$backup_count" -ne "$fs_count" ]; then
            print_warning "Backup file count ($backup_count) doesn't match filestore ($fs_count)"
            print_warning "Backup may be incomplete or corrupted"
            ((issues_found++))
        else
            print_status "✅ Backup contains all filestore files"
        fi
    fi

    # Overall status
    if [ $issues_found -eq 0 ]; then
        print_status "🎉 All verification checks passed!"
        return 0
    else
        print_warning "⚠️  $issues_found issue(s) found - manual review recommended"
        return 1
    fi
}

# Main execution
main() {
    local backup_only=false
    local verify_only=false
    local custom_backup_file=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --backup-only)
                backup_only=true
                shift
                ;;
            --verify-only)
                verify_only=true
                shift
                ;;
            --backup-file)
                custom_backup_file="$2"
                shift 2
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            --*)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                if [ -z "$1" ]; then
                    break
                fi
                DB_NAME="$1"
                shift
                ;;
        esac
    done

    # Set backup file path
    if [ -n "$custom_backup_file" ]; then
        BACKUP_FILE="$custom_backup_file"
    fi

    # Validate database name
    if [ "$DB_NAME" = "your_database" ]; then
        print_error "Please specify a valid database name"
        show_usage
        exit 1
    fi

    # Update paths with actual database name
    FILESTORE_PATH="$FILESTORE_BASE_PATH/$DB_NAME"

    print_header "🚀 Starting filestore verification for database: $DB_NAME"
    print_header "=================================================="

    # Check database connectivity unless we're only verifying a backup file
    if [ "$verify_only" = false ]; then
        if ! check_database_connectivity; then
            exit 1
        fi
    fi

    # Perform requested operations
    if [ "$verify_only" = true ]; then
        # Only verify existing backup
        if [ ! -f "$BACKUP_FILE" ]; then
            print_error "Backup file not found: $BACKUP_FILE"
            exit 1
        fi
        verify_backup_integrity "$BACKUP_FILE"
        exit $?

    elif [ "$backup_only" = true ]; then
        # Only create backup
        create_filestore_backup "$BACKUP_FILE"
        exit $?

    else
        # Full verification process
        create_filestore_backup "$BACKUP_FILE"
        backup_status=$?

        if [ $backup_status -eq 0 ] || [ $backup_status -eq 2 ]; then
            perform_comprehensive_comparison "$BACKUP_FILE"
            exit $?
        else
            print_error "Backup creation failed, skipping verification"
            exit 1
        fi
    fi
}

# Run main function
main "$@"