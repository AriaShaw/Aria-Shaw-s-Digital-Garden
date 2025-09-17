#!/bin/bash
# Odoo Backup Repair Toolkit
# Attempts to repair corrupted Odoo backup files
# Part of "The Definitive Guide to Odoo Database Backup and Restore"
# Created by Aria Shaw - 2025

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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
    echo -e "${BLUE}[REPAIR]${NC} $1"
}

repair_corrupted_backup() {
    local backup_file="$1"
    local repair_dir="/tmp/backup_repair_$(date +%s)"

    if [ ! -f "$backup_file" ]; then
        print_error "Backup file not found: $backup_file"
        return 1
    fi

    print_header "🔧 Attempting backup repair for: $(basename "$backup_file")"
    mkdir -p "$repair_dir"

    # Try to extract what we can
    print_status "📦 Extracting recoverable files..."
    cd "$repair_dir" || exit 1

    # Try different extraction methods
    if unzip -q "$backup_file" 2>/dev/null; then
        print_status "✅ Standard ZIP extraction successful"
    elif unzip -j "$backup_file" 2>/dev/null; then
        print_warning "⚠️  ZIP extraction had issues, extracted without directory structure"
    elif tar -tf "$backup_file" >/dev/null 2>&1 && tar -xf "$backup_file" 2>/dev/null; then
        print_status "✅ TAR extraction successful (backup was tar format)"
    else
        print_error "❌ Could not extract backup file with any method"
        rm -rf "$repair_dir"
        return 1
    fi

    # List extracted files
    print_status "📂 Files found in backup:"
    ls -la | grep -v "^total" | while read -r line; do
        echo "    $line"
    done

    # Repair database dump if possible
    if [ -f "dump.sql" ]; then
        print_header "🗄️ Repairing database dump..."

        # Create backup of original dump
        cp dump.sql dump.sql.original

        # Remove problematic lines
        print_status "Removing error lines and warnings..."
        sed -i '/^ERROR:/d' dump.sql
        sed -i '/^WARNING:/d' dump.sql
        sed -i '/^NOTICE:/d' dump.sql

        # Remove incomplete transactions
        sed -i '/^BEGIN;$/,/^ROLLBACK;$/d' dump.sql

        # Fix common SQL issues
        print_status "Fixing common SQL syntax issues..."

        # Remove problematic encoding declarations
        sed -i '/SET client_encoding/d' dump.sql

        # Validate SQL syntax if PostgreSQL is available
        if command -v psql >/dev/null 2>&1; then
            print_status "Validating SQL syntax..."
            if sudo -u postgres psql -d postgres -f dump.sql --dry-run >/dev/null 2>&1; then
                print_status "✅ Database dump syntax validation passed"
            else
                print_warning "⚠️  Database dump has syntax issues, but may still be recoverable"
            fi
        else
            print_warning "PostgreSQL not available for syntax validation"
        fi

        # Check file size difference
        original_size=$(wc -l < dump.sql.original)
        repaired_size=$(wc -l < dump.sql)
        removed_lines=$((original_size - repaired_size))

        if [ $removed_lines -gt 0 ]; then
            print_status "📊 Removed $removed_lines problematic lines from SQL dump"
        fi

    elif [ -f "*.backup" ] || [ -f "*.dump" ]; then
        print_header "🗄️ Found PostgreSQL custom format backup"
        backup_custom_file=$(find . -name "*.backup" -o -name "*.dump" | head -1)

        if [ -n "$backup_custom_file" ]; then
            print_status "Testing custom format backup integrity..."
            if command -v pg_restore >/dev/null 2>&1; then
                if pg_restore --list "$backup_custom_file" >/dev/null 2>&1; then
                    print_status "✅ Custom format backup appears intact"
                else
                    print_warning "⚠️  Custom format backup may have issues"
                fi
            else
                print_warning "pg_restore not available for testing custom format"
            fi
        fi
    else
        print_warning "No database dump found in backup"
    fi

    # Reconstruct manifest if missing
    if [ ! -f "manifest.json" ] && [ ! -f "manifest" ]; then
        print_header "📋 Reconstructing manifest..."
        cat > manifest.json << EOF
{
  "odoo_version": "unknown",
  "version_info": [16, 0, 0, "final", 0],
  "timestamp": "$(date -Iseconds)",
  "modules": [],
  "pg_version": "unknown",
  "restored_by": "backup_repair_toolkit",
  "repair_date": "$(date -Iseconds)"
}
EOF
        print_status "✅ Basic manifest reconstructed"
    fi

    # Check for filestore
    if [ -d "filestore" ] || find . -name "filestore" -type d >/dev/null 2>&1; then
        print_status "✅ Filestore directory found in backup"
        filestore_files=$(find . -path "*/filestore/*" -type f | wc -l)
        print_status "   Contains $filestore_files files"
    else
        print_warning "⚠️  No filestore found - backup may be database-only"
    fi

    # Repackage if everything looks good
    has_database=false
    has_manifest=false

    if [ -f "dump.sql" ] || [ -f "*.backup" ] || [ -f "*.dump" ]; then
        has_database=true
    fi

    if [ -f "manifest.json" ] || [ -f "manifest" ]; then
        has_manifest=true
    fi

    if [ "$has_database" = true ] && [ "$has_manifest" = true ]; then
        print_header "📦 Repackaging repaired backup..."
        repaired_file="${backup_file%.zip}_repaired.zip"

        if zip -r "$repaired_file" . >/dev/null 2>&1; then
            print_status "✅ Repaired backup created: $(basename "$repaired_file")"

            # Compare sizes
            original_size=$(stat -c%s "$backup_file" 2>/dev/null || stat -f%z "$backup_file" 2>/dev/null)
            repaired_size=$(stat -c%s "$repaired_file" 2>/dev/null || stat -f%z "$repaired_file" 2>/dev/null)

            if [ -n "$original_size" ] && [ -n "$repaired_size" ]; then
                size_diff=$(( (repaired_size * 100) / original_size ))
                print_status "📊 Repaired backup is ${size_diff}% the size of the original"

                if [ $size_diff -lt 50 ]; then
                    print_warning "⚠️  Significant size reduction - verify content manually"
                elif [ $size_diff -gt 90 ]; then
                    print_status "✅ Size looks reasonable - minimal data loss"
                fi
            fi
        else
            print_error "❌ Failed to create repaired backup file"
        fi
    else
        print_error "❌ Cannot create repaired backup - missing essential components"
        if [ "$has_database" = false ]; then
            print_error "   Missing: Database dump"
        fi
        if [ "$has_manifest" = false ]; then
            print_error "   Missing: Manifest file"
        fi
    fi

    # Generate repair report
    print_header "📋 Generating repair report..."
    report_file="${backup_file%.zip}_repair_report.txt"
    cat > "$report_file" << EOF
Odoo Backup Repair Report
========================
Original file: $(basename "$backup_file")
Repair date: $(date)
Repair location: $repair_dir

Files found in backup:
$(ls -la | grep -v "^total")

Repair actions taken:
EOF

    if [ -f "dump.sql.original" ]; then
        echo "- Cleaned SQL dump (removed $removed_lines problematic lines)" >> "$report_file"
    fi

    if [ -f "manifest.json" ] && grep -q "backup_repair_toolkit" manifest.json; then
        echo "- Reconstructed missing manifest file" >> "$report_file"
    fi

    if [ -f "${backup_file%.zip}_repaired.zip" ]; then
        echo "- Successfully repackaged repaired backup" >> "$report_file"
        echo "" >> "$report_file"
        echo "Result: REPAIR SUCCESSFUL" >> "$report_file"
        echo "Repaired file: $(basename "${backup_file%.zip}_repaired.zip")" >> "$report_file"
    else
        echo "- Could not repackage backup" >> "$report_file"
        echo "" >> "$report_file"
        echo "Result: REPAIR FAILED" >> "$report_file"
    fi

    print_status "📄 Repair report saved: $(basename "$report_file")"

    # Cleanup
    rm -rf "$repair_dir"
}

# Show usage information
show_usage() {
    echo "Odoo Backup Repair Toolkit"
    echo "=========================="
    echo ""
    echo "Usage: $0 <backup_file.zip>"
    echo ""
    echo "This tool attempts to repair corrupted Odoo backup files by:"
    echo "• Extracting recoverable files from damaged archives"
    echo "• Cleaning problematic lines from SQL dumps"
    echo "• Reconstructing missing manifest files"
    echo "• Repackaging into a new backup file"
    echo ""
    echo "Example:"
    echo "  $0 production_backup_corrupted.zip"
    echo ""
    echo "Output files:"
    echo "• <filename>_repaired.zip - The repaired backup (if successful)"
    echo "• <filename>_repair_report.txt - Detailed repair report"
    echo ""
}

# Main execution
if [ $# -eq 0 ]; then
    show_usage
    exit 1
fi

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_usage
    exit 0
fi

backup_file="$1"

if [ ! -f "$backup_file" ]; then
    print_error "File not found: $backup_file"
    exit 1
fi

print_header "Starting Odoo Backup Repair Process"
print_header "==================================="

repair_corrupted_backup "$backup_file"
exit_code=$?

if [ $exit_code -eq 0 ]; then
    print_header "🎉 Repair process completed!"
    print_status "Check the repair report for details on what was fixed."
    print_warning "⚠️  Always test the repaired backup before using in production!"
else
    print_error "❌ Repair process failed"
    print_error "The backup file may be too damaged to recover automatically."
    print_error "Consider manual recovery or restoring from an earlier backup."
fi

exit $exit_code