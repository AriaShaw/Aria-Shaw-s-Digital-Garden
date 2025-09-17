#!/usr/bin/env python3
"""
Odoo Filestore Deduplication Tool
Reduces backup sizes by eliminating duplicate files in the filestore
Part of "The Definitive Guide to Odoo Database Backup and Restore"
Created by Aria Shaw - 2025
"""

import hashlib
import os
import sys
import argparse
from pathlib import Path
import json
from datetime import datetime

class FilestoreDeduplicator:
    def __init__(self, filestore_path, min_file_size=1048576, dry_run=False):
        self.filestore_path = Path(filestore_path)
        self.min_file_size = min_file_size  # 1MB default
        self.dry_run = dry_run
        self.seen_hashes = {}
        self.stats = {
            'files_processed': 0,
            'duplicates_found': 0,
            'space_saved': 0,
            'errors': 0,
            'start_time': datetime.now(),
            'databases_processed': []
        }

    def calculate_file_hash(self, file_path):
        """Calculate SHA-256 hash of a file"""
        try:
            with open(file_path, 'rb') as f:
                file_hash = hashlib.sha256()
                # Read file in chunks to handle large files
                for chunk in iter(lambda: f.read(8192), b""):
                    file_hash.update(chunk)
                return file_hash.hexdigest()
        except Exception as e:
            print(f"❌ Error calculating hash for {file_path}: {e}")
            self.stats['errors'] += 1
            return None

    def is_safe_to_deduplicate(self, file_path):
        """Check if file is safe to deduplicate"""
        try:
            # Check file size threshold
            if file_path.stat().st_size < self.min_file_size:
                return False

            # Check file permissions
            if not os.access(file_path, os.R_OK):
                return False

            # Avoid system files and hidden files
            if file_path.name.startswith('.'):
                return False

            # Check if it's already a symlink
            if file_path.is_symlink():
                return False

            return True

        except Exception:
            return False

    def create_symlink(self, duplicate_path, original_path):
        """Create symlink from duplicate to original file"""
        try:
            if self.dry_run:
                print(f"[DRY RUN] Would create symlink: {duplicate_path} -> {original_path}")
                return True

            # Remove the duplicate file
            duplicate_path.unlink()

            # Create relative symlink if possible
            try:
                relative_path = os.path.relpath(original_path, duplicate_path.parent)
                duplicate_path.symlink_to(relative_path)
            except (OSError, ValueError):
                # Fall back to absolute symlink
                duplicate_path.symlink_to(original_path.absolute())

            return True

        except Exception as e:
            print(f"❌ Error creating symlink {duplicate_path} -> {original_path}: {e}")
            self.stats['errors'] += 1
            return False

    def deduplicate_database(self, database_path):
        """Deduplicate files for a specific database"""
        database_name = database_path.name
        print(f"🔍 Processing database: {database_name}")

        if not database_path.is_dir():
            print(f"⚠️  Skipping {database_name}: not a directory")
            return

        local_stats = {
            'files_processed': 0,
            'duplicates_found': 0,
            'space_saved': 0
        }

        # Process all files in this database's filestore
        for file_path in database_path.rglob('*'):
            if not file_path.is_file():
                continue

            if not self.is_safe_to_deduplicate(file_path):
                continue

            local_stats['files_processed'] += 1
            self.stats['files_processed'] += 1

            # Show progress for large operations
            if self.stats['files_processed'] % 100 == 0:
                print(f"  📄 Processed {self.stats['files_processed']} files...")

            # Calculate file hash
            file_hash = self.calculate_file_hash(file_path)
            if not file_hash:
                continue

            # Check for duplicates
            if file_hash in self.seen_hashes:
                original_file = self.seen_hashes[file_hash]
                file_size = file_path.stat().st_size

                # Verify the original file still exists and is valid
                if not original_file.exists() or original_file.is_symlink():
                    # Original file is gone or is itself a symlink, skip
                    continue

                print(f"  🔗 Duplicate found: {file_path.relative_to(self.filestore_path)}")
                print(f"     Original: {original_file.relative_to(self.filestore_path)}")
                print(f"     Size: {file_size / 1024 / 1024:.2f} MB")

                if self.create_symlink(file_path, original_file):
                    local_stats['duplicates_found'] += 1
                    local_stats['space_saved'] += file_size
                    self.stats['duplicates_found'] += 1
                    self.stats['space_saved'] += file_size

            else:
                # First time seeing this hash
                self.seen_hashes[file_hash] = file_path

        # Database summary
        print(f"  ✅ Database {database_name} complete:")
        print(f"     Files processed: {local_stats['files_processed']}")
        print(f"     Duplicates found: {local_stats['duplicates_found']}")
        print(f"     Space saved: {local_stats['space_saved'] / 1024 / 1024:.2f} MB")
        print()

        self.stats['databases_processed'].append({
            'name': database_name,
            'files_processed': local_stats['files_processed'],
            'duplicates_found': local_stats['duplicates_found'],
            'space_saved': local_stats['space_saved']
        })

    def deduplicate_all(self):
        """Deduplicate all databases in the filestore"""
        if not self.filestore_path.exists():
            print(f"❌ Filestore path does not exist: {self.filestore_path}")
            return False

        if not self.filestore_path.is_dir():
            print(f"❌ Filestore path is not a directory: {self.filestore_path}")
            return False

        print(f"🚀 Starting filestore deduplication")
        print(f"📁 Filestore path: {self.filestore_path}")
        print(f"📏 Minimum file size: {self.min_file_size / 1024 / 1024:.1f} MB")
        if self.dry_run:
            print(f"🔄 DRY RUN MODE - No changes will be made")
        print("=" * 60)

        # Find all database directories
        database_dirs = [d for d in self.filestore_path.iterdir() if d.is_dir()]

        if not database_dirs:
            print("⚠️  No database directories found in filestore")
            return False

        print(f"📊 Found {len(database_dirs)} database(s) to process:")
        for db_dir in database_dirs:
            print(f"  - {db_dir.name}")
        print()

        # Process each database
        for db_dir in database_dirs:
            try:
                self.deduplicate_database(db_dir)
            except KeyboardInterrupt:
                print("\n⚠️  Operation cancelled by user")
                break
            except Exception as e:
                print(f"❌ Error processing database {db_dir.name}: {e}")
                self.stats['errors'] += 1
                continue

        return True

    def generate_report(self, output_file=None):
        """Generate detailed deduplication report"""
        end_time = datetime.now()
        duration = end_time - self.stats['start_time']

        report = {
            'summary': {
                'filestore_path': str(self.filestore_path),
                'start_time': self.stats['start_time'].isoformat(),
                'end_time': end_time.isoformat(),
                'duration_seconds': duration.total_seconds(),
                'dry_run': self.dry_run,
                'min_file_size_mb': self.min_file_size / 1024 / 1024
            },
            'results': {
                'databases_processed': len(self.stats['databases_processed']),
                'files_processed': self.stats['files_processed'],
                'duplicates_found': self.stats['duplicates_found'],
                'space_saved_mb': self.stats['space_saved'] / 1024 / 1024,
                'space_saved_gb': self.stats['space_saved'] / 1024 / 1024 / 1024,
                'errors': self.stats['errors'],
                'deduplication_rate': (self.stats['duplicates_found'] / max(self.stats['files_processed'], 1)) * 100
            },
            'databases': self.stats['databases_processed']
        }

        # Print summary to console
        print("\n" + "=" * 60)
        print("📊 DEDUPLICATION SUMMARY")
        print("=" * 60)
        print(f"🕒 Duration: {duration}")
        print(f"📁 Databases processed: {len(self.stats['databases_processed'])}")
        print(f"📄 Files processed: {self.stats['files_processed']:,}")
        print(f"🔗 Duplicates found: {self.stats['duplicates_found']:,}")
        print(f"💾 Space saved: {self.stats['space_saved'] / 1024 / 1024:.2f} MB ({self.stats['space_saved'] / 1024 / 1024 / 1024:.2f} GB)")
        print(f"📈 Deduplication rate: {report['results']['deduplication_rate']:.1f}%")

        if self.stats['errors'] > 0:
            print(f"❌ Errors encountered: {self.stats['errors']}")

        if self.dry_run:
            print("\n🔄 This was a DRY RUN - no changes were made")

        # Save detailed report to file
        if output_file:
            try:
                with open(output_file, 'w') as f:
                    json.dump(report, f, indent=2, default=str)
                print(f"\n📄 Detailed report saved to: {output_file}")
            except Exception as e:
                print(f"❌ Error saving report: {e}")

        return report

def main():
    parser = argparse.ArgumentParser(
        description='Deduplicate Odoo filestore to reduce backup sizes',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s /var/lib/odoo/filestore
  %(prog)s /path/to/filestore --min-size 2097152 --dry-run
  %(prog)s /path/to/filestore --database mydb --report dedup_report.json

Configuration for Odoo (add to odoo.conf):
  [options]
  filestore_deduplicate = True
  filestore_deduplicate_threshold = 1048576
        """
    )

    parser.add_argument('filestore_path', help='Path to Odoo filestore directory')
    parser.add_argument('--min-size', type=int, default=1048576,
                       help='Minimum file size in bytes for deduplication (default: 1MB)')
    parser.add_argument('--database', help='Process only specific database')
    parser.add_argument('--dry-run', action='store_true',
                       help='Show what would be done without making changes')
    parser.add_argument('--report', help='Save detailed JSON report to file')
    parser.add_argument('--quiet', action='store_true', help='Reduce output verbosity')

    args = parser.parse_args()

    # Validate filestore path
    filestore_path = Path(args.filestore_path)
    if not filestore_path.exists():
        print(f"❌ Error: Filestore path does not exist: {filestore_path}")
        sys.exit(1)

    if not filestore_path.is_dir():
        print(f"❌ Error: Filestore path is not a directory: {filestore_path}")
        sys.exit(1)

    # Create deduplicator instance
    deduplicator = FilestoreDeduplicator(
        filestore_path=filestore_path,
        min_file_size=args.min_size,
        dry_run=args.dry_run
    )

    try:
        if args.database:
            # Process specific database
            db_path = filestore_path / args.database
            if not db_path.exists():
                print(f"❌ Error: Database directory not found: {db_path}")
                sys.exit(1)
            deduplicator.deduplicate_database(db_path)
        else:
            # Process all databases
            if not deduplicator.deduplicate_all():
                sys.exit(1)

        # Generate report
        deduplicator.generate_report(args.report)

        # Exit with appropriate code
        if deduplicator.stats['errors'] > 0:
            print(f"\n⚠️  Completed with {deduplicator.stats['errors']} errors")
            sys.exit(1)
        else:
            print(f"\n✅ Deduplication completed successfully!")
            sys.exit(0)

    except KeyboardInterrupt:
        print("\n❌ Operation cancelled by user")
        sys.exit(130)
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()