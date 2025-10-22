#!/usr/bin/env python3
"""
Odoo Module Compatibility Scanner
Scans custom modules for compatibility issues before migration
Usage: python3 module_compatibility_scan.py --odoo-path /opt/odoo --target-version 17.0
"""

import os
import re
import ast
import sys
import argparse
import json
from pathlib import Path
from collections import defaultdict


class ModuleCompatibilityScanner:
    def __init__(self, odoo_path, target_version):
        self.odoo_path = Path(odoo_path)
        self.target_version = target_version
        self.issues = defaultdict(list)
        self.deprecated_apis = self.load_deprecated_apis()
        
    def load_deprecated_apis(self):
        """Load known deprecated APIs for different Odoo versions"""
        return {
            '16.0': {
                'imports': [
                    'from openerp import',
                    'import openerp',
                ],
                'methods': [
                    '.sudo()',  # Now required for cross-model access
                    '_columns',  # Old API fields
                    '_defaults',  # Old API defaults
                ],
                'fields': [
                    'size=',  # Size parameter deprecated for Char fields
                    'select=',  # Select parameter deprecated
                ]
            },
            '17.0': {
                'imports': [
                    'from openerp import',
                    'import openerp',
                    'from odoo.addons.base.ir.ir_qweb import',
                ],
                'methods': [
                    '_columns',
                    '_defaults',
                    'fields.function',
                    'create_uid',
                    'write_uid', 
                ],
                'fields': [
                    'size=',
                    'select=',
                    'group_operator=',
                ]
            }
        }
    
    def scan_module(self, module_path):
        """Scan a single module for compatibility issues"""
        module_name = module_path.name
        print(f"Scanning module: {module_name}")
        
        # Check manifest file
        self.check_manifest(module_path, module_name)
        
        # Check Python files
        for py_file in module_path.rglob("*.py"):
            if py_file.name == '__init__.py':
                continue
            self.check_python_file(py_file, module_name)
        
        # Check XML files
        for xml_file in module_path.rglob("*.xml"):
            self.check_xml_file(xml_file, module_name)
    
    def check_manifest(self, module_path, module_name):
        """Check __manifest__.py or __openerp__.py for issues"""
        manifest_files = ['__manifest__.py', '__openerp__.py']
        manifest_path = None
        
        for manifest_file in manifest_files:
            potential_path = module_path / manifest_file
            if potential_path.exists():
                manifest_path = potential_path
                break
        
        if not manifest_path:
            self.issues[module_name].append({
                'type': 'error',
                'file': 'manifest',
                'issue': 'No manifest file found',
                'recommendation': 'Create __manifest__.py file'
            })
            return
        
        try:
            with open(manifest_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Check for deprecated manifest keys
            if "'installable': False" in content:
                self.issues[module_name].append({
                    'type': 'warning',
                    'file': str(manifest_path),
                    'issue': 'Module marked as not installable',
                    'recommendation': 'Review and update module for target version'
                })
            
            # Check version compatibility
            version_pattern = r"['\"]version['\"]:\s*['\"]([^'\"]+)['\"]"
            version_match = re.search(version_pattern, content)
            if version_match:
                version = version_match.group(1)
                if not version.startswith(self.target_version.split('.')[0]):
                    self.issues[module_name].append({
                        'type': 'warning',
                        'file': str(manifest_path),
                        'issue': f'Version mismatch: {version} vs target {self.target_version}',
                        'recommendation': f'Update version to {self.target_version}.x.x.x'
                    })
            
        except Exception as e:
            self.issues[module_name].append({
                'type': 'error',
                'file': str(manifest_path),
                'issue': f'Cannot parse manifest: {str(e)}',
                'recommendation': 'Fix manifest syntax errors'
            })
    
    def check_python_file(self, file_path, module_name):
        """Check Python file for compatibility issues"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Check for deprecated imports
            deprecated_imports = self.deprecated_apis.get(self.target_version, {}).get('imports', [])
            for deprecated_import in deprecated_imports:
                if deprecated_import in content:
                    self.issues[module_name].append({
                        'type': 'error',
                        'file': str(file_path),
                        'issue': f'Deprecated import: {deprecated_import}',
                        'recommendation': 'Update import to use "from odoo import"'
                    })
            
            # Check for deprecated methods
            deprecated_methods = self.deprecated_apis.get(self.target_version, {}).get('methods', [])
            for deprecated_method in deprecated_methods:
                if deprecated_method in content:
                    self.issues[module_name].append({
                        'type': 'warning',
                        'file': str(file_path),
                        'issue': f'Potentially deprecated method: {deprecated_method}',
                        'recommendation': 'Review method usage for new API compatibility'
                    })
            
            # Check for deprecated field parameters
            deprecated_fields = self.deprecated_apis.get(self.target_version, {}).get('fields', [])
            for deprecated_field in deprecated_fields:
                if deprecated_field in content:
                    self.issues[module_name].append({
                        'type': 'warning',
                        'file': str(file_path),
                        'issue': f'Deprecated field parameter: {deprecated_field}',
                        'recommendation': 'Remove deprecated field parameters'
                    })
            
            # Check for specific API changes
            self.check_api_changes(content, file_path, module_name)
            
        except Exception as e:
            self.issues[module_name].append({
                'type': 'error',
                'file': str(file_path),
                'issue': f'Cannot read Python file: {str(e)}',
                'recommendation': 'Check file encoding and syntax'
            })
    
    def check_api_changes(self, content, file_path, module_name):
        """Check for specific API changes between versions"""
        
        # Check for old-style field definitions
        if re.search(r'fields\.(char|text|integer|float|boolean|date|datetime)\s*\(', content, re.IGNORECASE):
            old_field_pattern = r'(\w+)\s*=\s*fields\.\w+\([^)]*size\s*='
            if re.search(old_field_pattern, content):
                self.issues[module_name].append({
                    'type': 'warning',
                    'file': str(file_path),
                    'issue': 'Old-style field definition with size parameter',
                    'recommendation': 'Remove size parameter from field definitions'
                })
        
        # Check for @api decorators compatibility
        if '@api.one' in content:
            self.issues[module_name].append({
                'type': 'error',
                'file': str(file_path),
                'issue': '@api.one decorator is deprecated',
                'recommendation': 'Replace @api.one with @api.model or remove decorator'
            })
        
        # Check for cr, uid parameters (old API)
        if re.search(r'def\s+\w+\s*\([^)]*\bcr\b[^)]*\buid\b', content):
            self.issues[module_name].append({
                'type': 'error',
                'file': str(file_path),
                'issue': 'Old API method signature with cr, uid parameters',
                'recommendation': 'Update to new API without cr, uid parameters'
            })
    
    def check_xml_file(self, file_path, module_name):
        """Check XML file for compatibility issues"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Check for deprecated XML elements
            deprecated_elements = [
                '<menuitem.*string.*action.*/>',  # Old menuitem syntax
                'eval="time',  # time module usage in XML
                'context.*active_id',  # Deprecated context usage
            ]
            
            for pattern in deprecated_elements:
                if re.search(pattern, content):
                    self.issues[module_name].append({
                        'type': 'warning',
                        'file': str(file_path),
                        'issue': f'Potentially deprecated XML pattern: {pattern}',
                        'recommendation': 'Review XML syntax for new version compatibility'
                    })
            
        except Exception as e:
            self.issues[module_name].append({
                'type': 'error',
                'file': str(file_path),
                'issue': f'Cannot read XML file: {str(e)}',
                'recommendation': 'Check file encoding'
            })
    
    def generate_report(self):
        """Generate compatibility report"""
        print("\n" + "="*80)
        print(f"ODOO MODULE COMPATIBILITY REPORT - Target Version: {self.target_version}")
        print("="*80)
        
        total_modules = len(self.issues)
        total_issues = sum(len(issues) for issues in self.issues.values())
        error_count = sum(1 for issues in self.issues.values() 
                         for issue in issues if issue['type'] == 'error')
        warning_count = total_issues - error_count
        
        print(f"Modules scanned: {total_modules}")
        print(f"Total issues found: {total_issues}")
        print(f"  - Errors (must fix): {error_count}")
        print(f"  - Warnings (should review): {warning_count}")
        print()
        
        if total_issues == 0:
            print("🎉 EXCELLENT: No compatibility issues found!")
            print("Your modules appear ready for migration.")
            return True
        
        # Group modules by severity
        modules_with_errors = []
        modules_with_warnings = []
        
        for module_name, issues in self.issues.items():
            has_errors = any(issue['type'] == 'error' for issue in issues)
            if has_errors:
                modules_with_errors.append(module_name)
            else:
                modules_with_warnings.append(module_name)
        
        if modules_with_errors:
            print(f"🚨 CRITICAL: {len(modules_with_errors)} modules have errors that MUST be fixed:")
            for module in modules_with_errors:
                print(f"  - {module}")
            print()
        
        if modules_with_warnings:
            print(f"⚠️  WARNING: {len(modules_with_warnings)} modules have warnings to review:")
            for module in modules_with_warnings:
                print(f"  - {module}")
            print()
        
        # Detailed issue breakdown
        print("DETAILED ISSUE BREAKDOWN:")
        print("-" * 40)
        
        for module_name, issues in self.issues.items():
            if not issues:
                continue
                
            print(f"\nModule: {module_name}")
            print("-" * len(module_name) + "-------")
            
            for issue in issues:
                icon = "🚨" if issue['type'] == 'error' else "⚠️ "
                print(f"{icon} {issue['issue']}")
                print(f"   File: {issue['file']}")
                print(f"   Fix: {issue['recommendation']}")
                print()
        
        # Migration readiness assessment
        print("MIGRATION READINESS ASSESSMENT:")
        print("-" * 35)
        
        if error_count == 0:
            print("✅ READY: No critical errors found")
            print("   You can proceed with migration after reviewing warnings.")
        elif error_count <= 5:
            print("⚠️  NEEDS WORK: Some critical errors found")
            print("   Fix the errors above before migration.")
        else:
            print("🚨 NOT READY: Many critical errors found")
            print("   Significant work needed before migration is safe.")
        
        return error_count == 0
    
    def save_report(self, output_file):
        """Save detailed report to JSON file"""
        report_data = {
            'scan_date': str(Path.cwd()),
            'target_version': self.target_version,
            'total_modules': len(self.issues),
            'total_issues': sum(len(issues) for issues in self.issues.values()),
            'modules': dict(self.issues)
        }
        
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(report_data, f, indent=2, ensure_ascii=False)
        
        print(f"Detailed report saved to: {output_file}")


def main():
    parser = argparse.ArgumentParser(description='Scan Odoo modules for compatibility issues')
    parser.add_argument('--odoo-path', required=True, help='Path to Odoo installation')
    parser.add_argument('--target-version', required=True, help='Target Odoo version (e.g., 17.0)')
    parser.add_argument('--modules', help='Specific modules to scan (comma-separated)')
    parser.add_argument('--output', help='Output file for detailed report')
    
    args = parser.parse_args()
    
    scanner = ModuleCompatibilityScanner(args.odoo_path, args.target_version)
    
    # Find addons directories
    addons_paths = []
    odoo_path = Path(args.odoo_path)
    
    # Standard addons paths
    potential_paths = [
        odoo_path / 'addons',
        odoo_path / 'odoo' / 'addons',
        odoo_path / 'custom_addons',
        odoo_path / 'extra_addons',
    ]
    
    for path in potential_paths:
        if path.exists() and path.is_dir():
            addons_paths.append(path)
    
    if not addons_paths:
        print(f"Error: No addons directories found in {odoo_path}")
        sys.exit(1)
    
    print(f"Scanning addons in: {', '.join(str(p) for p in addons_paths)}")
    
    # Scan modules
    modules_to_scan = []
    if args.modules:
        modules_to_scan = args.modules.split(',')
    
    for addons_path in addons_paths:
        for module_dir in addons_path.iterdir():
            if not module_dir.is_dir():
                continue
            if module_dir.name.startswith('.'):
                continue
            if modules_to_scan and module_dir.name not in modules_to_scan:
                continue
            
            # Check if it's actually an Odoo module
            manifest_files = ['__manifest__.py', '__openerp__.py']
            if any((module_dir / manifest).exists() for manifest in manifest_files):
                scanner.scan_module(module_dir)
    
    # Generate and display report
    success = scanner.generate_report()
    
    # Save detailed report if requested
    if args.output:
        scanner.save_report(args.output)
    
    # Exit with appropriate code
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()