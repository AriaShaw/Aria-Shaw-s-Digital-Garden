#!/usr/bin/env python3
import psycopg2
from collections import defaultdict, deque

def get_install_order(db_name):
    conn = psycopg2.connect(f"dbname={db_name} user=odoo")
    cur = conn.cursor()
    
    # Get all modules and their dependencies
    cur.execute("""
        SELECT m.name, m.state, array_agg(d.name) as deps
        FROM ir_module_module m
        LEFT JOIN ir_module_module_dependency md ON m.id = md.module_id
        LEFT JOIN ir_module_module d ON md.name = d.name
        WHERE m.state IN ('to install', 'to upgrade', 'uninstalled')
        GROUP BY m.name, m.state
    """)
    
    modules = {}
    for name, state, deps in cur.fetchall():
        clean_deps = [d for d in (deps or []) if d]
        modules[name] = {'state': state, 'dependencies': clean_deps}
    
    # Topological sort for installation order
    install_order = []
    visited = set()
    temp_visited = set()
    
    def visit(module):
        if module in temp_visited:
            raise Exception(f"Circular dependency involving {module}")
        if module in visited:
            return
        
        temp_visited.add(module)
        for dep in modules.get(module, {}).get('dependencies', []):
            if dep in modules:
                visit(dep)
        temp_visited.remove(module)
        visited.add(module)
        install_order.append(module)
    
    for module in modules:
        if module not in visited:
            visit(module)
    
    return install_order

if __name__ == "__main__":
    import sys
    db_name = sys.argv[1] if len(sys.argv) > 1 else "production_new"
    order = get_install_order(db_name)
    print("Installation order:")
    for i, module in enumerate(order, 1):
        print(f"{i:2d}. {module}")