#!/usr/bin/env python3
# Odoo Database Cleanup & Optimization Script
# Save as 'data_cleanup.py'

import psycopg2
import sys
from datetime import datetime

def connect_database(db_name, user="odoo", password="odoo", host="localhost"):
    """Connect to PostgreSQL database"""
    try:
        conn = psycopg2.connect(
            dbname=db_name,
            user=user,
            password=password,
            host=host
        )
        return conn
    except psycopg2.Error as e:
        print(f"❌ Database connection failed: {e}")
        sys.exit(1)

def find_duplicate_partners(conn):
    """Identify duplicate customer/vendor records"""
    print("🔍 Scanning for duplicate partners...")
    
    cursor = conn.cursor()
    
    # Find potential duplicates by email
    cursor.execute("""
        SELECT email, COUNT(*), array_agg(id) as duplicate_ids
        FROM res_partner 
        WHERE email IS NOT NULL AND email != ''
        GROUP BY email 
        HAVING COUNT(*) > 1
        ORDER BY COUNT(*) DESC;
    """)
    
    email_duplicates = cursor.fetchall()
    
    # Find potential duplicates by name
    cursor.execute("""
        SELECT name, COUNT(*), array_agg(id) as duplicate_ids
        FROM res_partner 
        WHERE name IS NOT NULL AND name != ''
        GROUP BY name 
        HAVING COUNT(*) > 1
        ORDER BY COUNT(*) DESC
        LIMIT 10;
    """)
    
    name_duplicates = cursor.fetchall()
    
    print(f"📊 Found {len(email_duplicates)} email duplicates")
    print(f"📊 Found {len(name_duplicates)} name duplicates")
    
    if email_duplicates:
        print("\n⚠️  Top email duplicates:")
        for email, count, ids in email_duplicates[:5]:
            print(f"   📧 {email}: {count} records (IDs: {ids[:3]}{'...' if len(ids) > 3 else ''})")
    
    if name_duplicates:
        print("\n⚠️  Top name duplicates:")
        for name, count, ids in name_duplicates[:5]:
            print(f"   👤 {name}: {count} records (IDs: {ids[:3]}{'...' if len(ids) > 3 else ''})")
    
    cursor.close()
    return len(email_duplicates) + len(name_duplicates)

def find_orphaned_records(conn):
    """Find records that reference non-existent partners"""
    print("\n🔍 Scanning for orphaned records...")
    
    cursor = conn.cursor()
    
    # Check sale orders with missing customers
    cursor.execute("""
        SELECT COUNT(*) 
        FROM sale_order so 
        LEFT JOIN res_partner rp ON so.partner_id = rp.id 
        WHERE rp.id IS NULL;
    """)
    
    orphaned_sales = cursor.fetchone()[0]
    
    # Check invoices with missing customers
    cursor.execute("""
        SELECT COUNT(*) 
        FROM account_move am 
        LEFT JOIN res_partner rp ON am.partner_id = rp.id 
        WHERE rp.id IS NULL AND am.move_type IN ('out_invoice', 'out_refund');
    """)
    
    orphaned_invoices = cursor.fetchone()[0]
    
    print(f"📊 Found {orphaned_sales} orphaned sale orders")
    print(f"📊 Found {orphaned_invoices} orphaned invoices")
    
    if orphaned_sales > 0 or orphaned_invoices > 0:
        print("🚨 CRITICAL: Orphaned records found - these will cause migration failures!")
        print("📋 Action required: Clean up orphaned records before migration")
    
    cursor.close()
    return orphaned_sales + orphaned_invoices

def check_large_tables(conn):
    """Identify large tables that might slow down migration"""
    print("\n🔍 Analyzing table sizes...")
    
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT 
            schemaname,
            tablename,
            pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size,
            pg_total_relation_size(schemaname||'.'||tablename) as size_bytes
        FROM pg_tables 
        WHERE schemaname = 'public'
        ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC 
        LIMIT 10;
    """)
    
    large_tables = cursor.fetchall()
    
    print("📊 Largest tables in your database:")
    for schema, table, size, size_bytes in large_tables:
        print(f"   📋 {table}: {size}")
        
        # Flag tables over 1GB
        if size_bytes > 1073741824:  # 1GB in bytes
            print(f"      ⚠️  Large table - consider archiving old data")
    
    cursor.close()

def analyze_custom_modules(conn):
    """Check for custom module data that might cause issues"""
    print("\n🔍 Analyzing custom module usage...")
    
    cursor = conn.cursor()
    
    # Check for installed modules
    cursor.execute("""
        SELECT name, state, latest_version 
        FROM ir_module_module 
        WHERE state = 'installed' AND name NOT LIKE 'base%'
        ORDER BY name;
    """)
    
    installed_modules = cursor.fetchall()
    
    print(f"📊 Found {len(installed_modules)} installed modules")
    
    # Look for potentially problematic modules
    custom_modules = [module for module in installed_modules if not any(
        standard in module[0] for standard in ['sale', 'purchase', 'account', 'stock', 'crm', 'hr', 'project']
    )]
    
    if custom_modules:
        print(f"\n⚠️  {len(custom_modules)} custom/third-party modules detected:")
        for name, state, version in custom_modules[:10]:
            print(f"   🔧 {name} ({version})")
        
        if len(custom_modules) > 10:
            print(f"   ... and {len(custom_modules) - 10} more")
        
        print("\n📋 Action required: Verify these modules are compatible with target Odoo version")
    
    cursor.close()
    return len(custom_modules)

def generate_cleanup_report(db_name, duplicates, orphaned, custom_modules):
    """Generate a summary report"""
    print("\n" + "="*60)
    print("📋 DATA CLEANUP ASSESSMENT REPORT")
    print("="*60)
    print(f"Database: {db_name}")
    print(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    total_issues = duplicates + orphaned + (custom_modules if custom_modules > 0 else 0)
    
    if total_issues == 0:
        print("✅ EXCELLENT: No major data issues detected!")
        print("📋 Your database is ready for migration")
    elif total_issues < 5:
        print("⚠️  MINOR ISSUES: Some cleanup recommended")
        print("📋 Consider addressing these issues but migration can proceed")
    else:
        print("🚨 MAJOR ISSUES: Cleanup required before migration")
        print("📋 DO NOT proceed with migration until these issues are resolved")
    
    print(f"\n🎯 Issue Summary:")
    print(f"   • Duplicate records: {duplicates}")
    print(f"   • Orphaned records: {orphaned}")
    print(f"   • Custom modules: {custom_modules}")
    
    print(f"\n💡 Next Steps:")
    if duplicates > 0:
        print("   1. Review and merge duplicate partner records")
    if orphaned > 0:
        print("   2. Fix or remove orphaned records")
    if custom_modules > 5:
        print("   3. Test custom modules in staging environment")
    
    print("   4. Run this analysis again after cleanup")
    print("   5. Proceed with migration only after all issues are resolved")

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 data_cleanup.py <database_name>")
        sys.exit(1)
    
    db_name = sys.argv[1]
    print(f"🔧 Starting data cleanup analysis for: {db_name}")
    print("="*60)
    
    # Connect to database
    conn = connect_database(db_name)
    
    try:
        # Run all checks
        duplicates = find_duplicate_partners(conn)
        orphaned = find_orphaned_records(conn)
        check_large_tables(conn)
        custom_modules = analyze_custom_modules(conn)
        
        # Generate report
        generate_cleanup_report(db_name, duplicates, orphaned, custom_modules)
        
    except Exception as e:
        print(f"❌ Analysis failed: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    main()