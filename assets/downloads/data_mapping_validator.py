#!/usr/bin/env python3
"""
Integration Data Mapping Validator
Validates field mappings, tests data type conversions, identifies mapping gaps.
"""

import json
import sys
from datetime import datetime
from typing import Any, Dict, List
import argparse

class MappingValidator:
    def __init__(self, mapping_file):
        with open(mapping_file, 'r') as f:
            self.mappings = json.load(f)

        self.errors = []
        self.warnings = []

    def validate_field_exists(self, data: Dict, field_path: str) -> bool:
        """Check if nested field exists in data"""
        keys = field_path.split('.')
        current = data

        for key in keys:
            if isinstance(current, dict) and key in current:
                current = current[key]
            else:
                return False
        return True

    def get_field_value(self, data: Dict, field_path: str) -> Any:
        """Get value from nested field path"""
        keys = field_path.split('.')
        current = data

        for key in keys:
            current = current[key]
        return current

    def validate_data_type(self, value: Any, expected_type: str) -> bool:
        """Validate if value matches expected data type"""
        type_map = {
            'string': str,
            'integer': int,
            'float': float,
            'boolean': bool,
            'array': list,
            'object': dict
        }

        expected_class = type_map.get(expected_type.lower())
        if not expected_class:
            self.warnings.append(f"Unknown type: {expected_type}")
            return True

        return isinstance(value, expected_class)

    def transform_value(self, value: Any, transformation: str) -> Any:
        """Apply transformation to value"""
        if transformation == 'uppercase':
            return str(value).upper()
        elif transformation == 'lowercase':
            return str(value).lower()
        elif transformation == 'to_int':
            return int(value)
        elif transformation == 'to_float':
            return float(value)
        elif transformation == 'to_string':
            return str(value)
        elif transformation == 'trim':
            return str(value).strip()
        else:
            self.warnings.append(f"Unknown transformation: {transformation}")
            return value

    def validate_mapping(self, source_data: Dict, target_data: Dict = None) -> Dict:
        """Validate complete mapping configuration"""
        print(f"\n[VALIDATION] Starting mapping validation...")
        print("=" * 80)

        results = {
            'field_mappings': [],
            'missing_source_fields': [],
            'type_mismatches': [],
            'transformation_errors': []
        }

        for mapping in self.mappings.get('field_mappings', []):
            source_field = mapping['source_field']
            target_field = mapping['target_field']
            expected_type = mapping.get('target_type', 'string')
            transformation = mapping.get('transformation')

            print(f"\n  Mapping: {source_field} -> {target_field}")

            # Check if source field exists
            if not self.validate_field_exists(source_data, source_field):
                error = f"Source field missing: {source_field}"
                print(f"    ✗ {error}")
                results['missing_source_fields'].append(source_field)
                self.errors.append(error)
                continue

            # Get and validate source value
            try:
                source_value = self.get_field_value(source_data, source_field)
                print(f"    Source Value: {source_value} ({type(source_value).__name__})")

                # Apply transformation if specified
                if transformation:
                    try:
                        transformed_value = self.transform_value(source_value, transformation)
                        print(f"    Transformed: {transformed_value} (via {transformation})")
                        source_value = transformed_value
                    except Exception as e:
                        error = f"Transformation failed for {source_field}: {e}"
                        print(f"    ✗ {error}")
                        results['transformation_errors'].append({
                            'field': source_field,
                            'transformation': transformation,
                            'error': str(e)
                        })
                        self.errors.append(error)

                # Validate target type
                if not self.validate_data_type(source_value, expected_type):
                    error = f"Type mismatch: {source_field} ({type(source_value).__name__}) != {expected_type}"
                    print(f"    ✗ {error}")
                    results['type_mismatches'].append({
                        'field': source_field,
                        'actual_type': type(source_value).__name__,
                        'expected_type': expected_type
                    })
                    self.warnings.append(error)
                else:
                    print(f"    ✓ Type valid: {expected_type}")

                results['field_mappings'].append({
                    'source_field': source_field,
                    'target_field': target_field,
                    'value': source_value,
                    'type': type(source_value).__name__,
                    'status': 'ok'
                })

            except Exception as e:
                error = f"Failed to process {source_field}: {e}"
                print(f"    ✗ {error}")
                self.errors.append(error)

        return results

    def generate_report(self, results: Dict):
        """Generate validation report"""
        print("\n" + "=" * 80)
        print("VALIDATION REPORT")
        print("=" * 80)

        print(f"\nTotal Mappings: {len(self.mappings.get('field_mappings', []))}")
        print(f"Successful: {len(results['field_mappings'])}")
        print(f"Missing Source Fields: {len(results['missing_source_fields'])}")
        print(f"Type Mismatches: {len(results['type_mismatches'])}")
        print(f"Transformation Errors: {len(results['transformation_errors'])}")

        if self.errors:
            print(f"\n❌ ERRORS ({len(self.errors)}):")
            for error in self.errors:
                print(f"  - {error}")

        if self.warnings:
            print(f"\n⚠ WARNINGS ({len(self.warnings)}):")
            for warning in self.warnings:
                print(f"  - {warning}")

        if not self.errors and not self.warnings:
            print(f"\n✅ All mappings validated successfully!")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Validate data mapping configuration')
    parser.add_argument('mapping_file', help='JSON file containing mapping configuration')
    parser.add_argument('source_data_file', help='JSON file containing source data sample')
    parser.add_argument('--output', help='Output file for validation results (JSON)')

    args = parser.parse_args()

    # Load source data
    with open(args.source_data_file, 'r') as f:
        source_data = json.load(f)

    # Validate mappings
    validator = MappingValidator(args.mapping_file)
    results = validator.validate_mapping(source_data)

    # Generate report
    validator.generate_report(results)

    # Save results if output specified
    if args.output:
        with open(args.output, 'w') as f:
            json.dump(results, f, indent=2)
        print(f"\n📄 Results saved to: {args.output}")

    # Exit with error code if validation failed
    sys.exit(1 if validator.errors else 0)
