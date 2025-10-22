#!/usr/bin/env python3
"""
Odoo Backup Size Prediction Script
Predict backup sizes before starting to avoid storage surprises
Part of "The Definitive Guide to Odoo Database Backup and Restore"
Created by Aria Shaw - 2025
"""

import subprocess
import json
import sys
import os

def predict_backup_size(database_name):
    """Predict backup size without creating backup"""

    # Get database size
    db_size_query = f"""
    SELECT pg_size_pretty(pg_database_size('{database_name}')) as readable_size,
           pg_database_size('{database_name}') as size_bytes
    """

    result = subprocess.run([
        'sudo', '-u', 'postgres', 'psql', '-d', database_name,
        '-t', '-c', db_size_query
    ], capture_output=True, text=True)

    if result.returncode != 0:
        print(f"Error connecting to database {database_name}: {result.stderr}")
        return None

    # Parse database size
    lines = result.stdout.strip().split('\n')
    size_info = lines[0].strip().split('|')
    readable_size = size_info[0].strip()
    size_bytes = int(size_info[1].strip())

    # Get filestore size
    filestore_path = f"/var/lib/odoo/filestore/{database_name}"

    filestore_result = subprocess.run([
        'du', '-sb', filestore_path
    ], capture_output=True, text=True)

    filestore_bytes = 0
    if filestore_result.returncode == 0:
        filestore_bytes = int(filestore_result.stdout.split()[0])
    else:
        print(f"Warning: Could not access filestore at {filestore_path}")

    # Compression estimation (typical ratios)
    db_compression_ratio = 0.3  # SQL compresses well
    filestore_compression_ratio = 0.8  # Files vary in compressibility

    predicted_db_compressed = size_bytes * db_compression_ratio
    predicted_filestore_compressed = filestore_bytes * filestore_compression_ratio
    total_predicted = predicted_db_compressed + predicted_filestore_compressed

    print(f"Backup Size Prediction for '{database_name}':")
    print("=" * 50)
    print(f"Database size (raw):      {readable_size}")
    print(f"Filestore size (raw):     {filestore_bytes / 1024 / 1024:.1f} MB")
    print(f"Predicted compressed DB:  {predicted_db_compressed / 1024 / 1024:.1f} MB")
    print(f"Predicted compressed FS:  {predicted_filestore_compressed / 1024 / 1024:.1f} MB")
    print(f"Total predicted backup:   {total_predicted / 1024 / 1024:.1f} MB")
    print(f"Estimated backup time:    {total_predicted / 1024 / 1024 / 5:.1f} minutes")

    # Check available disk space
    backup_dir = "/backup/odoo"  # Default backup directory
    if os.path.exists(backup_dir):
        statvfs = os.statvfs(backup_dir)
        available_bytes = statvfs.f_frsize * statvfs.f_bavail

        print(f"\nDisk Space Check:")
        print(f"Available space:          {available_bytes / 1024 / 1024:.1f} MB")

        if available_bytes > total_predicted * 1.5:  # 50% buffer
            print("✅ Sufficient disk space available")
        elif available_bytes > total_predicted:
            print("⚠️  Tight on disk space - consider cleanup")
        else:
            print("❌ Insufficient disk space - backup will fail!")

    return total_predicted

def predict_multiple_databases():
    """Predict backup sizes for all Odoo databases"""
    # Get list of databases
    result = subprocess.run([
        'sudo', '-u', 'postgres', 'psql', '-t', '-c',
        "SELECT datname FROM pg_database WHERE datname NOT IN ('template0', 'template1', 'postgres') ORDER BY datname;"
    ], capture_output=True, text=True)

    if result.returncode != 0:
        print("Error listing databases")
        return

    databases = [line.strip() for line in result.stdout.strip().split('\n') if line.strip()]

    total_predicted = 0
    print("Multi-Database Backup Size Prediction")
    print("=" * 60)

    for db in databases:
        predicted = predict_backup_size(db)
        if predicted:
            total_predicted += predicted
        print()

    print(f"TOTAL PREDICTED SIZE: {total_predicted / 1024 / 1024:.1f} MB")
    print(f"ESTIMATED TOTAL TIME: {total_predicted / 1024 / 1024 / 5:.1f} minutes")

# Usage
if __name__ == "__main__":
    if len(sys.argv) == 1:
        print("Odoo Backup Size Prediction Tool")
        print("Usage:")
        print("  python3 predict_backup_size.py <database_name>")
        print("  python3 predict_backup_size.py --all")
        sys.exit(1)

    if sys.argv[1] == "--all":
        predict_multiple_databases()
    else:
        predict_backup_size(sys.argv[1])