#!/usr/bin/env python3
"""
Odoo Backup Validation Tool
Comprehensive backup validation without full restore
Part of "The Definitive Guide to Odoo Database Backup and Restore"
Created by Aria Shaw - 2025
"""

import zipfile
import json
import tempfile
import subprocess
import os
import sys
import argparse
from datetime import datetime, timedelta

class OdooBackupValidator:
    def __init__(self, backup_path):
        self.backup_path = backup_path
        self.validation_results = {
            'zip_integrity': False,
            'manifest_valid': False,
            'database_valid': False,
            'filestore_present': False,
            'size_reasonable': False,
            'version_compatible': False,
            'timestamp_recent': False
        }
        self.details = {}

    def validate_zip_integrity(self):
        """Check if ZIP file is intact and readable"""
        try:
            with zipfile.ZipFile(self.backup_path, 'r') as zip_ref:
                # Test ZIP integrity
                bad_file = zip_ref.testzip()
                if bad_file:
                    self.details['zip_error'] = f"Corrupted file in ZIP: {bad_file}"
                    return False

                self.validation_results['zip_integrity'] = True
                self.details['zip_files'] = len(zip_ref.namelist())
                return True
        except zipfile.BadZipFile:
            self.details['zip_error'] = "Invalid ZIP file format"
            return False
        except Exception as e:
            self.details['zip_error'] = str(e)
            return False

    def validate_manifest(self):
        """Validate manifest.json file"""
        try:
            with zipfile.ZipFile(self.backup_path, 'r') as zip_ref:
                # Check if manifest exists
                if 'manifest.json' not in zip_ref.namelist():
                    self.details['manifest_error'] = "manifest.json not found in backup"
                    return False

                # Read and parse manifest
                manifest_data = zip_ref.read('manifest.json')
                manifest = json.loads(manifest_data)

                # Check required fields
                required_fields = ['odoo_version', 'timestamp', 'version_info']
                for field in required_fields:
                    if field not in manifest:
                        self.details['manifest_error'] = f"Missing required field: {field}"
                        return False

                self.validation_results['manifest_valid'] = True
                self.details['odoo_version'] = manifest.get('odoo_version', 'unknown')
                self.details['backup_timestamp'] = manifest.get('timestamp', 'unknown')

                # Check version compatibility (basic check)
                version_info = manifest.get('version_info', [])
                if isinstance(version_info, list) and len(version_info) >= 2:
                    major_version = version_info[0]
                    if major_version >= 13:  # Support versions 13+
                        self.validation_results['version_compatible'] = True
                    self.details['major_version'] = major_version

                # Check timestamp recency (within last 7 days is reasonable)
                try:
                    backup_time = datetime.fromisoformat(manifest.get('timestamp', '').replace('Z', '+00:00'))
                    age_days = (datetime.now() - backup_time.replace(tzinfo=None)).days
                    if age_days <= 7:
                        self.validation_results['timestamp_recent'] = True
                    self.details['backup_age_days'] = age_days
                except:
                    self.details['timestamp_error'] = "Could not parse backup timestamp"

                return True

        except json.JSONDecodeError:
            self.details['manifest_error'] = "Invalid JSON format in manifest"
            return False
        except Exception as e:
            self.details['manifest_error'] = str(e)
            return False

    def validate_database_dump(self):
        """Validate PostgreSQL database dump"""
        try:
            with zipfile.ZipFile(self.backup_path, 'r') as zip_ref:
                # Look for database dump file
                dump_file = None
                for filename in zip_ref.namelist():
                    if filename.endswith(('.sql', '.dump', '.backup')):
                        dump_file = filename
                        break

                if not dump_file:
                    self.details['database_error'] = "No database dump file found"
                    return False

                # Extract and validate dump
                with tempfile.NamedTemporaryFile(suffix='.sql', delete=False) as temp_file:
                    temp_file.write(zip_ref.read(dump_file))
                    temp_file.flush()
                    temp_path = temp_file.name

                try:
                    # Check file size
                    dump_size = os.path.getsize(temp_path)
                    self.details['dump_size_mb'] = dump_size / (1024 * 1024)

                    # Try to validate with pg_restore if available
                    if dump_file.endswith(('.dump', '.backup')):
                        result = subprocess.run([
                            'pg_restore', '--list', temp_path
                        ], capture_output=True, text=True, timeout=30)

                        if result.returncode == 0:
                            self.validation_results['database_valid'] = True
                            # Count tables/objects
                            table_count = result.stdout.count('TABLE DATA')
                            self.details['table_count'] = table_count
                        else:
                            self.details['database_error'] = f"pg_restore validation failed: {result.stderr}"

                    # For SQL files, do basic validation
                    elif dump_file.endswith('.sql'):
                        with open(temp_path, 'r', encoding='utf-8', errors='ignore') as f:
                            first_lines = f.read(1024)
                            if 'PostgreSQL database dump' in first_lines or 'CREATE TABLE' in first_lines:
                                self.validation_results['database_valid'] = True
                            else:
                                self.details['database_error'] = "SQL file doesn't appear to be a valid PostgreSQL dump"

                    return self.validation_results['database_valid']

                finally:
                    # Cleanup temp file
                    try:
                        os.unlink(temp_path)
                    except:
                        pass

        except subprocess.TimeoutExpired:
            self.details['database_error'] = "Database validation timed out"
            return False
        except Exception as e:
            self.details['database_error'] = str(e)
            return False

    def validate_filestore(self):
        """Check for filestore presence and basic structure"""
        try:
            with zipfile.ZipFile(self.backup_path, 'r') as zip_ref:
                filestore_files = [f for f in zip_ref.namelist() if f.startswith('filestore/')]

                if filestore_files:
                    self.validation_results['filestore_present'] = True
                    self.details['filestore_file_count'] = len(filestore_files)

                    # Check for reasonable directory structure
                    directories = set()
                    for f in filestore_files:
                        parts = f.split('/')
                        if len(parts) >= 3:  # filestore/db_name/xx/
                            directories.add('/'.join(parts[:3]))

                    self.details['filestore_directories'] = len(directories)
                    return True
                else:
                    self.details['filestore_note'] = "No filestore found (database-only backup)"
                    return False

        except Exception as e:
            self.details['filestore_error'] = str(e)
            return False

    def validate_size(self):
        """Check if backup size is reasonable"""
        try:
            size = os.path.getsize(self.backup_path)
            size_mb = size / (1024 * 1024)
            self.details['backup_size_mb'] = round(size_mb, 2)

            # Consider >10MB reasonable for real data
            if size > 10 * 1024 * 1024:  # 10MB
                self.validation_results['size_reasonable'] = True
            else:
                self.details['size_warning'] = "Backup size seems unusually small"

            return self.validation_results['size_reasonable']

        except Exception as e:
            self.details['size_error'] = str(e)
            return False

    def run_full_validation(self):
        """Run all validation checks"""
        print(f"🔍 Validating backup: {os.path.basename(self.backup_path)}")
        print("=" * 60)

        # Check if file exists
        if not os.path.exists(self.backup_path):
            print(f"❌ ERROR: Backup file not found: {self.backup_path}")
            return False

        # Run all validation steps
        validations = [
            ("ZIP Integrity", self.validate_zip_integrity),
            ("Manifest", self.validate_manifest),
            ("Database Dump", self.validate_database_dump),
            ("Filestore", self.validate_filestore),
            ("File Size", self.validate_size)
        ]

        for name, validator in validations:
            try:
                result = validator()
                status = "✅ PASS" if result else "❌ FAIL"
                print(f"{name:15}: {status}")
            except Exception as e:
                print(f"{name:15}: ❌ ERROR - {str(e)}")

        # Print detailed results
        print("\n📊 Detailed Results:")
        print("-" * 40)

        for key, value in self.details.items():
            if '_error' in key:
                print(f"❌ {key.replace('_', ' ').title()}: {value}")
            elif '_warning' in key:
                print(f"⚠️  {key.replace('_', ' ').title()}: {value}")
            else:
                print(f"ℹ️  {key.replace('_', ' ').title()}: {value}")

        # Calculate overall health
        passed_checks = sum(self.validation_results.values())
        total_checks = len(self.validation_results)
        health_percentage = (passed_checks / total_checks) * 100

        print(f"\n🎯 Overall Health Score: {health_percentage:.0f}% ({passed_checks}/{total_checks} checks passed)")

        # Health interpretation
        if health_percentage >= 85:
            print("🟢 Status: EXCELLENT - Backup appears to be in good condition")
        elif health_percentage >= 70:
            print("🟡 Status: GOOD - Minor issues detected, but backup should be usable")
        elif health_percentage >= 50:
            print("🟠 Status: FAIR - Several issues detected, manual verification recommended")
        else:
            print("🔴 Status: POOR - Significant issues detected, backup may be corrupted")

        # Recommendations
        print("\n💡 Recommendations:")
        if not self.validation_results['zip_integrity']:
            print("• ❗ ZIP file is corrupted - backup is likely unusable")
        if not self.validation_results['manifest_valid']:
            print("• ⚠️  Manifest issues detected - restore may fail")
        if not self.validation_results['database_valid']:
            print("• ❗ Database dump validation failed - critical issue")
        if not self.validation_results['filestore_present']:
            print("• ℹ️  No filestore found - verify if this is a database-only backup")
        if not self.validation_results['size_reasonable']:
            print("• ⚠️  Unusually small backup size - verify completeness")
        if not self.validation_results['version_compatible']:
            print("• ⚠️  Version compatibility issues detected")
        if not self.validation_results['timestamp_recent']:
            print("• ℹ️  Backup is older than 7 days - ensure it's the intended version")

        if health_percentage >= 85:
            print("• ✅ Backup validation passed - safe to use for restore")

        return health_percentage >= 70

def main():
    parser = argparse.ArgumentParser(description='Validate Odoo backup files')
    parser.add_argument('backup_file', help='Path to the backup ZIP file to validate')
    parser.add_argument('--quiet', '-q', action='store_true', help='Reduce output verbosity')
    parser.add_argument('--json', action='store_true', help='Output results in JSON format')

    args = parser.parse_args()

    if not os.path.exists(args.backup_file):
        print(f"Error: File not found: {args.backup_file}")
        sys.exit(1)

    validator = OdooBackupValidator(args.backup_file)

    if args.json:
        # JSON output for automation
        result = validator.run_full_validation()
        output = {
            'backup_file': args.backup_file,
            'validation_results': validator.validation_results,
            'details': validator.details,
            'overall_health': sum(validator.validation_results.values()) / len(validator.validation_results) * 100,
            'validation_passed': result,
            'timestamp': datetime.now().isoformat()
        }
        print(json.dumps(output, indent=2))
    else:
        # Human-readable output
        result = validator.run_full_validation()

    # Exit with appropriate code
    sys.exit(0 if result else 1)

if __name__ == "__main__":
    main()