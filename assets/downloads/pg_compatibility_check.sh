#!/bin/bash
# PostgreSQL Compatibility Checker for Odoo Migration
# Usage: ./pg_compatibility_check.sh source_server target_server

set -e

SOURCE_SERVER="$1"
TARGET_SERVER="$2"

if [ -z "$SOURCE_SERVER" ] || [ -z "$TARGET_SERVER" ]; then
    echo "Usage: $0 source_server target_server"
    echo "Example: $0 production.old.com staging.new.com"
    exit 1
fi

echo "=== PostgreSQL Compatibility Check for Odoo Migration ==="
echo "Source: $SOURCE_SERVER"
echo "Target: $TARGET_SERVER"
echo ""

# Function to get PostgreSQL version
get_pg_version() {
    local server="$1"
    echo "Checking PostgreSQL version on $server..."
    if [ "$server" = "localhost" ] || [ "$server" = "127.0.0.1" ]; then
        sudo -u postgres psql -t -c "SELECT version();" 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1
    else
        ssh root@"$server" "sudo -u postgres psql -t -c \"SELECT version();\"" 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1
    fi
}

# Function to check extensions
check_extensions() {
    local server="$1"
    echo "Checking required PostgreSQL extensions on $server..."
    
    required_extensions=("unaccent" "pg_trgm" "btree_gin" "btree_gist")
    
    for ext in "${required_extensions[@]}"; do
        if [ "$server" = "localhost" ] || [ "$server" = "127.0.0.1" ]; then
            result=$(sudo -u postgres psql -t -c "SELECT 1 FROM pg_available_extensions WHERE name='$ext';" 2>/dev/null)
        else
            result=$(ssh root@"$server" "sudo -u postgres psql -t -c \"SELECT 1 FROM pg_available_extensions WHERE name='$ext';\"" 2>/dev/null)
        fi
        
        if [ -n "$result" ]; then
            echo "  ✓ $ext: Available"
        else
            echo "  ✗ $ext: Missing (CRITICAL)"
            COMPATIBILITY_ISSUES=$((COMPATIBILITY_ISSUES + 1))
        fi
    done
}

# Function to check encoding
check_encoding() {
    local server="$1"
    echo "Checking database encoding on $server..."
    
    if [ "$server" = "localhost" ] || [ "$server" = "127.0.0.1" ]; then
        encoding=$(sudo -u postgres psql -t -c "SHOW server_encoding;" 2>/dev/null | tr -d ' ')
    else
        encoding=$(ssh root@"$server" "sudo -u postgres psql -t -c \"SHOW server_encoding;\"" 2>/dev/null | tr -d ' ')
    fi
    
    if [ "$encoding" = "UTF8" ]; then
        echo "  ✓ Encoding: $encoding (Compatible)"
    else
        echo "  ✗ Encoding: $encoding (May cause issues)"
        COMPATIBILITY_ISSUES=$((COMPATIBILITY_ISSUES + 1))
    fi
}

# Function to check authentication method
check_auth() {
    local server="$1"
    echo "Checking authentication configuration on $server..."
    
    if [ "$server" = "localhost" ] || [ "$server" = "127.0.0.1" ]; then
        auth_methods=$(sudo -u postgres psql -t -c "SELECT DISTINCT auth_method FROM pg_hba_file_rules WHERE database = 'all' OR database ~ 'odoo';" 2>/dev/null | tr -d ' ' | sort -u)
    else
        auth_methods=$(ssh root@"$server" "sudo -u postgres psql -t -c \"SELECT DISTINCT auth_method FROM pg_hba_file_rules WHERE database = 'all' OR database ~ 'odoo';\"" 2>/dev/null | tr -d ' ' | sort -u)
    fi
    
    for method in $auth_methods; do
        case $method in
            "md5"|"scram-sha-256"|"trust"|"peer")
                echo "  ✓ Auth method: $method (Compatible)"
                ;;
            "password"|"crypt")
                echo "  ⚠ Auth method: $method (Deprecated, update recommended)"
                ;;
            *)
                echo "  ? Auth method: $method (Unknown compatibility)"
                ;;
        esac
    done
}

# Main compatibility check
COMPATIBILITY_ISSUES=0

echo "1. PostgreSQL Version Check"
echo "=========================="
SOURCE_VERSION=$(get_pg_version "$SOURCE_SERVER")
TARGET_VERSION=$(get_pg_version "$TARGET_SERVER")

echo "Source PostgreSQL version: $SOURCE_VERSION"
echo "Target PostgreSQL version: $TARGET_VERSION"

if [ "$TARGET_VERSION" \< "$SOURCE_VERSION" ]; then
    echo "✗ CRITICAL: Target version is older than source! This will cause compatibility issues."
    COMPATIBILITY_ISSUES=$((COMPATIBILITY_ISSUES + 1))
elif [ "$TARGET_VERSION" = "$SOURCE_VERSION" ]; then
    echo "✓ Perfect: Same PostgreSQL versions"
else
    echo "✓ Good: Target version is newer (should be compatible)"
fi
echo ""

echo "2. Extension Availability Check"
echo "=============================="
check_extensions "$SOURCE_SERVER"
echo ""
check_extensions "$TARGET_SERVER"
echo ""

echo "3. Database Encoding Check"
echo "========================="
check_encoding "$SOURCE_SERVER"
check_encoding "$TARGET_SERVER"
echo ""

echo "4. Authentication Method Check"
echo "============================="
check_auth "$SOURCE_SERVER"
echo ""
check_auth "$TARGET_SERVER"
echo ""

echo "5. Compatibility Summary"
echo "======================="
if [ $COMPATIBILITY_ISSUES -eq 0 ]; then
    echo "✓ EXCELLENT: No compatibility issues detected"
    echo "  You can proceed with migration confidently."
elif [ $COMPATIBILITY_ISSUES -le 2 ]; then
    echo "⚠ WARNING: Minor compatibility issues detected ($COMPATIBILITY_ISSUES issues)"
    echo "  Review the issues above and fix before migration."
else
    echo "✗ CRITICAL: Major compatibility issues detected ($COMPATIBILITY_ISSUES issues)"
    echo "  DO NOT proceed with migration until all issues are resolved."
fi

echo ""
echo "Compatibility check completed on $(date)"
echo "Save this report for your migration documentation."

exit $COMPATIBILITY_ISSUES