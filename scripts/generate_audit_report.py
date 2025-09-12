#!/usr/bin/env python3
import psycopg2
import json
from datetime import datetime, timedelta

def generate_migration_audit_report(start_date, end_date):
    """Generate comprehensive audit report for migration period"""
    
    conn = psycopg2.connect("dbname=production_new user=odoo")
    cur = conn.cursor()
    
    # Data access summary
    cur.execute("""
        SELECT 
            action_type,
            data_sensitivity,
            COUNT(*) as access_count,
            COUNT(DISTINCT user_id) as unique_users
        FROM migration_audit_trail 
        WHERE timestamp BETWEEN %s AND %s
        GROUP BY action_type, data_sensitivity
        ORDER BY access_count DESC
    """, (start_date, end_date))
    
    access_summary = cur.fetchall()
    
    # Sensitive data access details
    cur.execute("""
        SELECT 
            u.name as user_name,
            mat.timestamp,
            mat.action_type,
            mat.table_name,
            mat.data_sensitivity,
            mat.ip_address
        FROM migration_audit_trail mat
        JOIN res_users u ON mat.user_id = u.id
        WHERE mat.timestamp BETWEEN %s AND %s
        AND mat.data_sensitivity IN ('confidential', 'restricted', 'personal')
        ORDER BY mat.timestamp DESC
    """, (start_date, end_date))
    
    sensitive_access = cur.fetchall()
    
    # Generate report
    report = {
        'report_period': f"{start_date} to {end_date}",
        'generated_at': datetime.now().isoformat(),
        'access_summary': [
            {
                'action_type': row[0],
                'data_sensitivity': row[1], 
                'access_count': row[2],
                'unique_users': row[3]
            } for row in access_summary
        ],
        'sensitive_data_access': [
            {
                'user': row[0],
                'timestamp': row[1].isoformat(),
                'action': row[2],
                'table': row[3],
                'sensitivity': row[4],
                'ip_address': row[5]
            } for row in sensitive_access
        ]
    }
    
    # Save report
    with open(f'audit_report_{start_date}_{end_date}.json', 'w') as f:
        json.dump(report, f, indent=2, default=str)
    
    print(f"Audit report generated: audit_report_{start_date}_{end_date}.json")
    return report

if __name__ == "__main__":
    import sys
    start_date = sys.argv[1] if len(sys.argv) > 1 else "2025-01-01"
    end_date = sys.argv[2] if len(sys.argv) > 2 else "2025-12-31"
    generate_migration_audit_report(start_date, end_date)