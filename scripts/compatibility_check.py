#!/usr/bin/env python3
# PostgreSQL Version Compatibility Checker
# Run this on both source and target servers to ensure compatibility

import subprocess
import re
import sys

def run_command(command):
    """Run system command and return output"""
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        return result.stdout.strip()
    except Exception as e:
        return f"Error: {str(e)}"

def check_postgresql_compatibility():
    """Check PostgreSQL versions between source and target"""
    print("🔍 PostgreSQL Compatibility Check")
    print("-" * 40)
    
    # Check current PostgreSQL version
    source_version = run_command("sudo -u postgres psql -c 'SHOW server_version;' -t")
    source_major = re.search(r'(\d+)', source_version)
    
    if source_major:
        source_major_num = int(source_major.group(1))
        print(f"Source PostgreSQL: {source_version}")
        print(f"Major Version: {source_major_num}")
        
        # Compatibility rules
        if source_major_num >= 12:
            print("✅ Modern PostgreSQL version - Good compatibility")
            print("📋 Recommended target versions: 12, 13, 14, 15, 16")
        else:
            print("⚠️  Older PostgreSQL version detected")
            print("🚨 CRITICAL: Upgrade source PostgreSQL before migration")
            print("📋 Required: Upgrade to PostgreSQL 12+ first")
    
    return source_major_num if source_major else None

def check_python_compatibility():
    """Check Python version compatibility"""
    print("\n🐍 Python Compatibility Check")
    print("-" * 40)
    
    python_version = run_command("python3 --version")
    print(f"Current Python: {python_version}")
    
    # Extract version numbers
    version_match = re.search(r'(\d+)\.(\d+)', python_version)
    if version_match:
        major, minor = int(version_match.group(1)), int(version_match.group(2))
        
        if major == 3 and minor >= 8:
            print("✅ Python version compatible with modern Odoo")
        elif major == 3 and minor >= 6:
            print("⚠️  Python version works but consider upgrading")
        else:
            print("❌ Python version too old - upgrade required")
            print("📋 Required: Python 3.8+ for Odoo 15+")

def check_disk_space():
    """Check available disk space for migration"""
    print("\n💾 Disk Space Analysis")
    print("-" * 40)
    
    disk_usage = run_command("df -h /")
    print("Current disk usage:")
    print(disk_usage)
    
    # Get available space in GB (rough estimate)
    available_match = re.search(r'(\d+)G.*(\d+)%', disk_usage)
    if available_match:
        available_gb = int(available_match.group(1))
        usage_percent = int(available_match.group(2))
        
        print(f"\n📊 Available space: {available_gb}GB")
        print(f"📊 Current usage: {usage_percent}%")
        
        if available_gb > 50 and usage_percent < 80:
            print("✅ Sufficient disk space for migration")
        else:
            print("❌ Insufficient disk space detected")
            print("📋 Required: At least 3x your database size in free space")

if __name__ == "__main__":
    print("🔧 Odoo Migration Compatibility Assessment")
    print("=" * 50)
    
    pg_version = check_postgresql_compatibility()
    check_python_compatibility()
    check_disk_space()
    
    print("\n🎯 COMPATIBILITY SUMMARY")
    print("=" * 30)
    print("✅ Green items: Ready to proceed")
    print("⚠️  Yellow items: Proceed with caution")
    print("❌ Red items: Must fix before migration")
    
    print("\n💡 Pro Tip: Address all red items before proceeding.")
    print("Migration failures are expensive - compatibility checks are free.")