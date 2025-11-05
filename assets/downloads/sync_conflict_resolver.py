#!/usr/bin/env python3
"""
Synchronization Conflict Resolver
Identifies duplicate records, detects sync conflicts, suggests resolution strategies.
"""

import json
import argparse
from datetime import datetime
from typing import List, Dict, Any
from difflib import SequenceMatcher

class ConflictResolver:
    def __init__(self):
        self.conflicts = []
        self.duplicates = []

    def find_duplicates(self, records: List[Dict], key_fields: List[str]) -> List[Dict]:
        """
        Find duplicate records based on key fields

        Args:
            records: List of record dictionaries
            key_fields: Fields to use for duplicate detection (e.g., ['email', 'phone'])
        """
        print(f"\n[DUPLICATE DETECTION] Analyzing {len(records)} records...")
        print(f"Key fields: {', '.join(key_fields)}")
        print("-" * 80)

        seen = {}
        duplicates = []

        for idx, record in enumerate(records):
            # Create composite key from key fields
            key_values = []
            for field in key_fields:
                value = record.get(field, '')
                if value:
                    # Normalize for comparison
                    key_values.append(str(value).strip().lower())

            if not key_values:
                continue

            key = tuple(key_values)

            if key in seen:
                # Duplicate found
                original_idx = seen[key]
                duplicates.append({
                    'record_1': {'index': original_idx, 'data': records[original_idx]},
                    'record_2': {'index': idx, 'data': record},
                    'matching_fields': key_fields,
                    'key_values': key_values
                })
                print(f"  ✗ Duplicate found: Record {original_idx} ≈ Record {idx}")
                print(f"    Matching: {dict(zip(key_fields, key_values))}")
            else:
                seen[key] = idx

        print(f"\n  Found {len(duplicates)} duplicate(s)")
        self.duplicates = duplicates
        return duplicates

    def detect_field_conflicts(self, record1: Dict, record2: Dict) -> List[Dict]:
        """Detect field-level conflicts between two records"""
        conflicts = []

        all_fields = set(record1.keys()) | set(record2.keys())

        for field in all_fields:
            val1 = record1.get(field)
            val2 = record2.get(field)

            if val1 != val2:
                conflicts.append({
                    'field': field,
                    'value_1': val1,
                    'value_2': val2,
                    'conflict_type': self.classify_conflict(val1, val2)
                })

        return conflicts

    def classify_conflict(self, val1: Any, val2: Any) -> str:
        """Classify type of conflict between two values"""
        if val1 is None and val2 is not None:
            return 'missing_in_record_1'
        elif val1 is not None and val2 is None:
            return 'missing_in_record_2'
        elif isinstance(val1, str) and isinstance(val2, str):
            similarity = SequenceMatcher(None, val1, val2).ratio()
            if similarity > 0.8:
                return 'minor_difference'
            else:
                return 'major_difference'
        else:
            return 'value_mismatch'

    def suggest_resolution(self, record1: Dict, record2: Dict, strategy='most_recent') -> Dict:
        """
        Suggest resolution strategy for conflict

        Strategies:
        - most_recent: Keep record with latest timestamp
        - merge: Merge non-conflicting fields
        - manual: Flag for manual review
        """
        print(f"\n[RESOLUTION] Suggesting strategy: {strategy}")

        if strategy == 'most_recent':
            # Compare timestamps
            ts1 = record1.get('updated_at') or record1.get('created_at', '')
            ts2 = record2.get('updated_at') or record2.get('created_at', '')

            if ts1 > ts2:
                print(f"  → Keep Record 1 (newer: {ts1})")
                return {'action': 'keep_record_1', 'reason': 'most_recent'}
            elif ts2 > ts1:
                print(f"  → Keep Record 2 (newer: {ts2})")
                return {'action': 'keep_record_2', 'reason': 'most_recent'}
            else:
                print(f"  → Manual review required (same timestamp)")
                return {'action': 'manual_review', 'reason': 'equal_timestamps'}

        elif strategy == 'merge':
            # Merge non-null values
            merged = {}
            all_fields = set(record1.keys()) | set(record2.keys())

            for field in all_fields:
                val1 = record1.get(field)
                val2 = record2.get(field)

                if val1 is not None and val2 is None:
                    merged[field] = val1
                elif val1 is None and val2 is not None:
                    merged[field] = val2
                elif val1 == val2:
                    merged[field] = val1
                else:
                    # Conflict - flag for review
                    merged[field] = f"[CONFLICT: '{val1}' vs '{val2}']"

            print(f"  → Merged {len(merged)} fields")
            return {'action': 'merge', 'merged_data': merged}

        else:
            print(f"  → Manual review required")
            return {'action': 'manual_review', 'reason': 'unknown_strategy'}

    def generate_report(self):
        """Generate conflict resolution report"""
        print("\n" + "=" * 80)
        print("CONFLICT RESOLUTION REPORT")
        print("=" * 80)

        print(f"\nTotal Duplicates: {len(self.duplicates)}")

        if self.duplicates:
            print(f"\nDuplicate Details:")
            for idx, dup in enumerate(self.duplicates, 1):
                print(f"\n  {idx}. Records {dup['record_1']['index']} and {dup['record_2']['index']}")
                print(f"     Matching on: {', '.join(dup['matching_fields'])}")

                # Detect field conflicts
                conflicts = self.detect_field_conflicts(
                    dup['record_1']['data'],
                    dup['record_2']['data']
                )

                if conflicts:
                    print(f"     Field conflicts: {len(conflicts)}")
                    for conflict in conflicts[:3]:  # Show first 3
                        print(f"       - {conflict['field']}: '{conflict['value_1']}' vs '{conflict['value_2']}'")

                # Suggest resolution
                resolution = self.suggest_resolution(
                    dup['record_1']['data'],
                    dup['record_2']['data']
                )
                print(f"     Suggested action: {resolution['action']}")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Detect and resolve sync conflicts')
    parser.add_argument('records_file', help='JSON file containing records to analyze')
    parser.add_argument('--key-fields', nargs='+', required=True,
                        help='Fields to use for duplicate detection (e.g., email phone)')
    parser.add_argument('--strategy', choices=['most_recent', 'merge', 'manual'],
                        default='most_recent', help='Resolution strategy')
    parser.add_argument('--output', help='Output file for resolution report (JSON)')

    args = parser.parse_args()

    # Load records
    with open(args.records_file, 'r') as f:
        records = json.load(f)

    # Detect conflicts
    resolver = ConflictResolver()
    duplicates = resolver.find_duplicates(records, args.key_fields)

    # Generate report
    resolver.generate_report()

    # Save report if output specified
    if args.output:
        report = {
            'total_records': len(records),
            'duplicates_found': len(duplicates),
            'duplicates': duplicates,
            'timestamp': datetime.now().isoformat()
        }
        with open(args.output, 'w') as f:
            json.dump(report, f, indent=2)
        print(f"\n📄 Report saved to: {args.output}")
