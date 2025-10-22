#!/usr/bin/env python3
"""
Comprehensive Odoo Backup Manager
Supports multiple databases, cloud storage, and intelligent error handling
Created by Aria Shaw - 2025
"""

import os
import sys
import json
import logging
import subprocess
import datetime
import configparser
import argparse
from pathlib import Path
from typing import List, Dict, Optional

class OdooBackupManager:
    def __init__(self, config_file: str = 'backup_config.ini'):
        self.config = configparser.ConfigParser()
        self.config.read(config_file)

        # Setup logging
        log_level = self.config.get('logging', 'level', fallback='INFO')
        logging.basicConfig(
            level=getattr(logging, log_level),
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(self.config.get('logging', 'file', fallback='backup.log')),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)

    def backup_database(self, db_name: str, backup_dir: str) -> Dict[str, str]:
        """Backup a single Odoo database using pg_dump"""
        timestamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')

        # Database backup
        db_file = f"{backup_dir}/{db_name}_db_{timestamp}.dump"
        db_cmd = [
            'pg_dump',
            '-h', self.config.get('database', 'host', fallback='localhost'),
            '-p', self.config.get('database', 'port', fallback='5432'),
            '-U', self.config.get('database', 'user', fallback='odoo'),
            '--format=custom',
            '--compress=9',
            '--verbose',
            f'--file={db_file}',
            db_name
        ]

        # Set password environment variable
        env = os.environ.copy()
        env['PGPASSWORD'] = self.config.get('database', 'password')

        try:
            self.logger.info(f"Starting database backup for {db_name}")
            result = subprocess.run(db_cmd, env=env, capture_output=True, text=True)

            if result.returncode != 0:
                self.logger.error(f"Database backup failed: {result.stderr}")
                return {'status': 'failed', 'error': result.stderr}

            # Filestore backup
            filestore_path = Path(self.config.get('odoo', 'filestore_path', fallback='/var/lib/odoo/filestore')) / db_name
            fs_file = None

            if filestore_path.exists():
                fs_file = f"{backup_dir}/{db_name}_filestore_{timestamp}.tar.gz"
                tar_cmd = ['tar', '-czf', fs_file, '-C', str(filestore_path.parent), db_name]

                fs_result = subprocess.run(tar_cmd, capture_output=True, text=True)
                if fs_result.returncode != 0:
                    self.logger.warning(f"Filestore backup failed: {fs_result.stderr}")
                    fs_file = None

            # Create manifest
            manifest = {
                'database_name': db_name,
                'backup_date': datetime.datetime.now().isoformat(),
                'database_file': os.path.basename(db_file),
                'filestore_file': os.path.basename(fs_file) if fs_file else None,
                'backup_size_mb': round(os.path.getsize(db_file) / (1024*1024), 2)
            }

            manifest_file = f"{backup_dir}/{db_name}_manifest_{timestamp}.json"
            with open(manifest_file, 'w') as f:
                json.dump(manifest, f, indent=2)

            self.logger.info(f"Backup completed successfully for {db_name}")
            return {
                'status': 'success',
                'database_file': db_file,
                'filestore_file': fs_file,
                'manifest_file': manifest_file
            }

        except Exception as e:
            self.logger.error(f"Backup failed with exception: {str(e)}")
            return {'status': 'failed', 'error': str(e)}

    def upload_to_s3(self, file_path: str, s3_bucket: str, s3_key: str) -> bool:
        """Upload backup file to AWS S3"""
        try:
            import boto3
            s3_client = boto3.client('s3')
            s3_client.upload_file(file_path, s3_bucket, s3_key)
            self.logger.info(f"Uploaded {file_path} to s3://{s3_bucket}/{s3_key}")
            return True
        except ImportError:
            self.logger.error("boto3 not installed, cannot upload to S3")
            return False
        except Exception as e:
            self.logger.error(f"S3 upload failed: {str(e)}")
            return False

    def cleanup_old_backups(self, backup_dir: str, retention_days: int):
        """Remove backup files older than retention_days"""
        cutoff_date = datetime.datetime.now() - datetime.timedelta(days=retention_days)

        for file_path in Path(backup_dir).glob('*'):
            if file_path.stat().st_mtime < cutoff_date.timestamp():
                file_path.unlink()
                self.logger.info(f"Removed old backup: {file_path}")

    def run_backup(self, databases: List[str]):
        """Run backup for multiple databases"""
        backup_dir = self.config.get('backup', 'directory', fallback='/backup/odoo')
        Path(backup_dir).mkdir(parents=True, exist_ok=True)

        results = {}
        for db_name in databases:
            results[db_name] = self.backup_database(db_name, backup_dir)

            # Upload to S3 if configured
            if self.config.has_section('s3') and results[db_name]['status'] == 'success':
                s3_bucket = self.config.get('s3', 'bucket')
                for file_type in ['database_file', 'filestore_file', 'manifest_file']:
                    file_path = results[db_name].get(file_type)
                    if file_path and os.path.exists(file_path):
                        s3_key = f"odoo-backups/{os.path.basename(file_path)}"
                        self.upload_to_s3(file_path, s3_bucket, s3_key)

        # Cleanup old backups
        retention_days = int(self.config.get('backup', 'retention_days', fallback='30'))
        self.cleanup_old_backups(backup_dir, retention_days)

        return results

def main():
    parser = argparse.ArgumentParser(description='Backup Odoo databases')
    parser.add_argument('databases', nargs='+', help='Database names to backup')
    parser.add_argument('--config', default='backup_config.ini', help='Configuration file')

    args = parser.parse_args()

    backup_manager = OdooBackupManager(args.config)
    results = backup_manager.run_backup(args.databases)

    # Print summary
    for db_name, result in results.items():
        if result['status'] == 'success':
            print(f"✅ {db_name}: Backup successful")
        else:
            print(f"❌ {db_name}: Backup failed - {result.get('error', 'Unknown error')}")

if __name__ == '__main__':
    main()