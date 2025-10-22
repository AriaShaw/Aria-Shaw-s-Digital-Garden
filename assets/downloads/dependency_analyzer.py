#!/usr/bin/env python3
"""
Advanced Odoo Module Dependency Analyzer
Analyzes and resolves complex module dependency issues
Usage: python3 dependency_analyzer.py --database production_new --fix-mode
"""

import argparse
import psycopg2
import json
import sys
from collections import defaultdict, deque
import networkx as nx
import matplotlib.pyplot as plt


class DependencyAnalyzer:
    def __init__(self, database, host='localhost', user='odoo', password='odoo'):
        self.database = database
        self.host = host
        self.user = user
        self.password = password
        self.conn = None
        self.dependency_graph = nx.DiGraph()
        self.modules = {}
        
    def connect(self):
        """Connect to PostgreSQL database"""
        try:
            self.conn = psycopg2.connect(
                host=self.host,
                database=self.database,
                user=self.user,
                password=self.password
            )
            print(f"✓ Connected to database: {self.database}")
            return True
        except Exception as e:
            print(f"✗ Database connection failed: {e}")
            return False
    
    def load_module_data(self):
        """Load module information and dependencies from database"""
        if not self.conn:
            return False
        
        cursor = self.conn.cursor()
        
        # Get all modules with their states
        cursor.execute("""
            SELECT 
                m.id,
                m.name,
                m.state,
                m.latest_version,
                m.installed_version,
                m.auto_install,
                m.application,
                m.category_id
            FROM ir_module_module m
            ORDER BY m.name
        """)
        
        modules_data = cursor.fetchall()
        
        for module_data in modules_data:
            module_id, name, state, latest_version, installed_version, auto_install, application, category_id = module_data
            self.modules[name] = {
                'id': module_id,
                'state': state,
                'latest_version': latest_version,
                'installed_version': installed_version,
                'auto_install': auto_install,
                'application': application,
                'category_id': category_id,
                'dependencies': [],
                'dependents': []
            }
            self.dependency_graph.add_node(name, **self.modules[name])
        
        # Get dependencies
        cursor.execute("""
            SELECT 
                m.name as module_name,
                d.name as dependency_name
            FROM ir_module_module m
            JOIN ir_module_module_dependency md ON m.id = md.module_id
            JOIN ir_module_module d ON md.name = d.name
            ORDER BY m.name, d.name
        """)
        
        dependencies_data = cursor.fetchall()
        
        for module_name, dependency_name in dependencies_data:
            if module_name in self.modules and dependency_name in self.modules:
                self.modules[module_name]['dependencies'].append(dependency_name)
                self.modules[dependency_name]['dependents'].append(module_name)
                self.dependency_graph.add_edge(dependency_name, module_name)
        
        print(f"✓ Loaded {len(self.modules)} modules with {len(dependencies_data)} dependencies")
        return True
    
    def find_circular_dependencies(self):
        """Find circular dependencies in the module graph"""
        try:
            cycles = list(nx.simple_cycles(self.dependency_graph))
            return cycles
        except nx.NetworkXError:
            return []
    
    def find_missing_dependencies(self):
        """Find modules that depend on non-existent modules"""
        cursor = self.conn.cursor()
        
        cursor.execute("""
            SELECT 
                m.name as module_name,
                md.name as missing_dependency
            FROM ir_module_module m
            JOIN ir_module_module_dependency md ON m.id = md.module_id
            LEFT JOIN ir_module_module d ON md.name = d.name
            WHERE d.name IS NULL
            ORDER BY m.name, md.name
        """)
        
        missing_deps = cursor.fetchall()
        return missing_deps
    
    def get_installation_order(self, modules_to_install=None):
        """Calculate topological installation order"""
        if modules_to_install is None:
            # Get all modules that need to be installed/upgraded
            modules_to_install = [
                name for name, data in self.modules.items()
                if data['state'] in ['to install', 'to upgrade']
            ]
        
        # Create subgraph with only modules to install and their dependencies
        subgraph_nodes = set()
        for module in modules_to_install:
            subgraph_nodes.add(module)
            # Add all dependencies recursively
            deps = self._get_all_dependencies(module)
            subgraph_nodes.update(deps)
        
        subgraph = self.dependency_graph.subgraph(subgraph_nodes)
        
        try:
            # Topological sort gives us the installation order
            install_order = list(nx.topological_sort(subgraph))
            return install_order
        except nx.NetworkXError as e:
            print(f"✗ Cannot determine installation order: {e}")
            return []
    
    def _get_all_dependencies(self, module, visited=None):
        """Recursively get all dependencies of a module"""
        if visited is None:
            visited = set()
        
        if module in visited or module not in self.modules:
            return set()
        
        visited.add(module)
        all_deps = set(self.modules[module]['dependencies'])
        
        for dep in self.modules[module]['dependencies']:
            all_deps.update(self._get_all_dependencies(dep, visited.copy()))
        
        return all_deps
    
    def analyze_problematic_modules(self):
        """Identify modules causing dependency issues"""
        problems = {
            'circular_dependencies': self.find_circular_dependencies(),
            'missing_dependencies': self.find_missing_dependencies(),
            'uninstallable_modules': [],
            'high_dependency_modules': []
        }
        
        # Find modules with too many dependencies
        for name, data in self.modules.items():
            if len(data['dependencies']) > 10:
                problems['high_dependency_modules'].append({
                    'name': name,
                    'dependency_count': len(data['dependencies']),
                    'state': data['state']
                })
        
        # Find modules that can't be uninstalled due to dependents
        for name, data in self.modules.items():
            if data['state'] == 'installed' and len(data['dependents']) > 5:
                problems['uninstallable_modules'].append({
                    'name': name,
                    'dependent_count': len(data['dependents']),
                    'dependents': data['dependents'][:10]  # Limit to first 10
                })
        
        return problems
    
    def generate_dependency_report(self):
        """Generate comprehensive dependency analysis report"""
        print("\n" + "="*80)
        print("ODOO MODULE DEPENDENCY ANALYSIS REPORT")
        print("="*80)
        
        # Basic statistics
        total_modules = len(self.modules)
        installed_modules = len([m for m in self.modules.values() if m['state'] == 'installed'])
        to_install = len([m for m in self.modules.values() if m['state'] == 'to install'])
        to_upgrade = len([m for m in self.modules.values() if m['state'] == 'to upgrade'])
        
        print(f"Total modules: {total_modules}")
        print(f"Installed: {installed_modules}")
        print(f"To install: {to_install}")
        print(f"To upgrade: {to_upgrade}")
        print()
        
        # Problem analysis
        problems = self.analyze_problematic_modules()
        
        print("DEPENDENCY ISSUES DETECTED:")
        print("-" * 30)
        
        # Circular dependencies
        if problems['circular_dependencies']:
            print(f"🚨 CRITICAL: {len(problems['circular_dependencies'])} circular dependencies found!")
            for i, cycle in enumerate(problems['circular_dependencies'][:5], 1):
                cycle_str = " → ".join(cycle + [cycle[0]])
                print(f"  {i}. {cycle_str}")
            if len(problems['circular_dependencies']) > 5:
                print(f"  ... and {len(problems['circular_dependencies']) - 5} more")
        else:
            print("✓ No circular dependencies found")
        
        # Missing dependencies
        if problems['missing_dependencies']:
            print(f"⚠️  WARNING: {len(problems['missing_dependencies'])} missing dependencies!")
            missing_by_module = defaultdict(list)
            for module, missing_dep in problems['missing_dependencies']:
                missing_by_module[module].append(missing_dep)
            
            for module, missing_deps in list(missing_by_module.items())[:10]:
                print(f"  {module}: {', '.join(missing_deps)}")
        else:
            print("✓ No missing dependencies found")
        
        # High dependency modules
        if problems['high_dependency_modules']:
            print(f"⚠️  INFO: {len(problems['high_dependency_modules'])} modules with high dependency count:")
            for module_info in problems['high_dependency_modules'][:5]:
                print(f"  {module_info['name']}: {module_info['dependency_count']} dependencies ({module_info['state']})")
        
        print()
        
        # Installation order
        print("RECOMMENDED INSTALLATION ORDER:")
        print("-" * 32)
        install_order = self.get_installation_order()
        if install_order:
            for i, module in enumerate(install_order[:20], 1):
                state = self.modules[module]['state']
                print(f"{i:2d}. {module} ({state})")
            if len(install_order) > 20:
                print(f"    ... and {len(install_order) - 20} more modules")
        else:
            print("❌ Cannot determine installation order due to circular dependencies")
        
        return problems
    
    def fix_common_issues(self, dry_run=True):
        """Attempt to fix common dependency issues"""
        if not self.conn:
            return False
        
        print("\n" + "="*50)
        print("AUTOMATIC ISSUE RESOLUTION")
        print("="*50)
        
        if dry_run:
            print("DRY RUN MODE - No changes will be made")
            print()
        
        cursor = self.conn.cursor()
        fixes_applied = 0
        
        # Fix 1: Remove dependencies on missing modules
        missing_deps = self.find_missing_dependencies()
        if missing_deps:
            print(f"Fixing {len(missing_deps)} missing dependencies...")
            for module_name, missing_dep in missing_deps:
                print(f"  Removing dependency: {module_name} → {missing_dep}")
                if not dry_run:
                    cursor.execute("""
                        DELETE FROM ir_module_module_dependency 
                        WHERE module_id = (SELECT id FROM ir_module_module WHERE name = %s)
                        AND name = %s
                    """, (module_name, missing_dep))
                fixes_applied += 1
        
        # Fix 2: Mark problematic modules as uninstalled
        problems = self.analyze_problematic_modules()
        if problems['circular_dependencies']:
            print("Attempting to break circular dependencies...")
            # For each cycle, mark the least critical module as uninstalled
            for cycle in problems['circular_dependencies']:
                # Choose module with least dependents
                least_critical = min(cycle, key=lambda m: len(self.modules[m]['dependents']))
                print(f"  Marking {least_critical} as uninstalled to break cycle")
                if not dry_run:
                    cursor.execute("""
                        UPDATE ir_module_module 
                        SET state = 'uninstalled' 
                        WHERE name = %s
                    """, (least_critical,))
                fixes_applied += 1
        
        if not dry_run and fixes_applied > 0:
            self.conn.commit()
            print(f"✓ Applied {fixes_applied} fixes to dependency issues")
        elif dry_run:
            print(f"Would apply {fixes_applied} fixes (dry run mode)")
        else:
            print("No fixes needed")
        
        return fixes_applied > 0
    
    def export_dependency_graph(self, output_file="dependency_graph.png"):
        """Export dependency graph visualization"""
        try:
            plt.figure(figsize=(20, 16))
            
            # Create layout
            pos = nx.spring_layout(self.dependency_graph, k=3, iterations=50)
            
            # Color nodes by state
            node_colors = []
            for node in self.dependency_graph.nodes():
                state = self.modules[node]['state']
                if state == 'installed':
                    node_colors.append('lightgreen')
                elif state == 'to install':
                    node_colors.append('lightblue')
                elif state == 'to upgrade':
                    node_colors.append('orange')
                else:
                    node_colors.append('lightgray')
            
            # Draw the graph
            nx.draw(self.dependency_graph, pos, 
                   node_color=node_colors,
                   with_labels=True,
                   node_size=100,
                   font_size=8,
                   arrows=True,
                   arrowsize=10,
                   edge_color='gray',
                   alpha=0.7)
            
            plt.title("Odoo Module Dependency Graph")
            plt.savefig(output_file, dpi=300, bbox_inches='tight')
            print(f"✓ Dependency graph saved to: {output_file}")
            
        except ImportError:
            print("⚠️  matplotlib not available - cannot export graph visualization")
        except Exception as e:
            print(f"✗ Failed to export graph: {e}")


def main():
    parser = argparse.ArgumentParser(description='Analyze Odoo module dependencies')
    parser.add_argument('--database', required=True, help='Database name')
    parser.add_argument('--host', default='localhost', help='Database host')
    parser.add_argument('--user', default='odoo', help='Database user')
    parser.add_argument('--password', default='odoo', help='Database password')
    parser.add_argument('--fix-mode', action='store_true', help='Attempt to fix issues')
    parser.add_argument('--dry-run', action='store_true', help='Show fixes without applying')
    parser.add_argument('--export-graph', help='Export dependency graph to file')
    parser.add_argument('--output', help='Output analysis results to JSON file')
    
    args = parser.parse_args()
    
    # Create analyzer
    analyzer = DependencyAnalyzer(args.database, args.host, args.user, args.password)
    
    # Connect to database
    if not analyzer.connect():
        sys.exit(1)
    
    # Load module data
    if not analyzer.load_module_data():
        sys.exit(1)
    
    # Generate report
    problems = analyzer.generate_dependency_report()
    
    # Export results if requested
    if args.output:
        with open(args.output, 'w') as f:
            json.dump(problems, f, indent=2, default=str)
        print(f"✓ Analysis results saved to: {args.output}")
    
    # Export graph if requested
    if args.export_graph:
        analyzer.export_dependency_graph(args.export_graph)
    
    # Fix issues if requested
    if args.fix_mode:
        analyzer.fix_common_issues(dry_run=args.dry_run)
    
    # Exit with error code if critical issues found
    critical_issues = len(problems['circular_dependencies']) + len(problems['missing_dependencies'])
    if critical_issues > 0:
        print(f"\n⚠️  {critical_issues} critical dependency issues require attention")
        sys.exit(1)
    else:
        print("\n✓ No critical dependency issues found")
        sys.exit(0)


if __name__ == '__main__':
    main()