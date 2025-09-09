#!/usr/bin/env python3
# Odoo Server Hardware Calculator
# Save as 'calculate_server_specs.py'
# Usage: python3 calculate_server_specs.py

import math
import json
from datetime import datetime

class OdooServerCalculator:
    def __init__(self):
        # Base requirements for different Odoo components
        self.base_requirements = {
            'odoo_core': {'cpu_cores': 1, 'ram_gb': 2, 'disk_gb': 10},
            'postgresql': {'cpu_cores': 1, 'ram_gb': 2, 'disk_gb': 20},
            'web_server': {'cpu_cores': 0.5, 'ram_gb': 0.5, 'disk_gb': 5},
            'system_overhead': {'cpu_cores': 0.5, 'ram_gb': 1, 'disk_gb': 20}
        }
        
        # Scaling factors based on usage patterns
        self.scaling_factors = {
            'concurrent_users': {
                'cpu_per_user': 0.1,      # CPU cores per concurrent user
                'ram_per_user': 0.15,     # GB RAM per concurrent user
                'worker_ratio': 6         # Users per Odoo worker process
            },
            'database_size': {
                'small': {'multiplier': 1.0, 'max_gb': 1},
                'medium': {'multiplier': 1.5, 'max_gb': 10},
                'large': {'multiplier': 2.0, 'max_gb': 50},
                'xlarge': {'multiplier': 3.0, 'max_gb': float('inf')}
            },
            'transaction_volume': {
                'low': {'multiplier': 1.0, 'max_per_hour': 100},
                'medium': {'multiplier': 1.3, 'max_per_hour': 1000},
                'high': {'multiplier': 1.8, 'max_per_hour': 5000},
                'extreme': {'multiplier': 2.5, 'max_per_hour': float('inf')}
            }
        }

    def get_database_category(self, db_size_gb):
        """Determine database size category"""
        for category, info in self.scaling_factors['database_size'].items():
            if db_size_gb <= info['max_gb']:
                return category, info['multiplier']
        return 'xlarge', self.scaling_factors['database_size']['xlarge']['multiplier']

    def get_transaction_category(self, transactions_per_hour):
        """Determine transaction volume category"""
        for category, info in self.scaling_factors['transaction_volume'].items():
            if transactions_per_hour <= info['max_per_hour']:
                return category, info['multiplier']
        return 'extreme', self.scaling_factors['transaction_volume']['extreme']['multiplier']

    def calculate_requirements(self, concurrent_users, db_size_gb, transactions_per_hour, 
                             has_ecommerce=False, has_manufacturing=False, has_accounting=True):
        """Calculate server requirements based on usage parameters"""
        
        print("🔧 Odoo Server Hardware Calculator")
        print("=" * 50)
        print(f"Calculation started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"Concurrent Users: {concurrent_users}")
        print(f"Database Size: {db_size_gb}GB")
        print(f"Transactions/Hour: {transactions_per_hour}")
        print(f"E-commerce Module: {'Yes' if has_ecommerce else 'No'}")
        print(f"Manufacturing Module: {'Yes' if has_manufacturing else 'No'}")
        print(f"Accounting Module: {'Yes' if has_accounting else 'No'}")
        print()

        # Start with base requirements
        total_cpu = sum(req['cpu_cores'] for req in self.base_requirements.values())
        total_ram = sum(req['ram_gb'] for req in self.base_requirements.values())
        total_disk = sum(req['disk_gb'] for req in self.base_requirements.values())

        # Scale based on concurrent users
        user_cpu = concurrent_users * self.scaling_factors['concurrent_users']['cpu_per_user']
        user_ram = concurrent_users * self.scaling_factors['concurrent_users']['ram_per_user']
        
        total_cpu += user_cpu
        total_ram += user_ram

        # Scale based on database size
        db_category, db_multiplier = self.get_database_category(db_size_gb)
        total_cpu *= db_multiplier
        total_ram *= db_multiplier
        
        # Add database storage requirements
        # Rule: 3x database size for working space + backups
        database_disk = db_size_gb * 3
        total_disk += database_disk

        # Scale based on transaction volume
        trans_category, trans_multiplier = self.get_transaction_category(transactions_per_hour)
        total_cpu *= trans_multiplier
        total_ram *= trans_multiplier

        # Module-specific adjustments
        module_cpu_bonus = 0
        module_ram_bonus = 0
        
        if has_ecommerce:
            module_cpu_bonus += 1  # E-commerce adds significant load
            module_ram_bonus += 2
            print("📊 E-commerce module: +1 CPU core, +2GB RAM")
        
        if has_manufacturing:
            module_cpu_bonus += 2  # Manufacturing is CPU-intensive
            module_ram_bonus += 4
            print("🏭 Manufacturing module: +2 CPU cores, +4GB RAM")
        
        if has_accounting and concurrent_users > 20:
            module_ram_bonus += 1  # Accounting with many users needs more RAM
            print("📈 Large accounting deployment: +1GB RAM")

        total_cpu += module_cpu_bonus
        total_ram += module_ram_bonus

        # Calculate Odoo workers
        # Formula: (CPU cores - 1) for workers, but max 1 worker per 6 users
        max_workers_by_cpu = max(1, int(total_cpu) - 1)
        max_workers_by_users = max(1, concurrent_users // 6)
        recommended_workers = min(max_workers_by_cpu, max_workers_by_users)

        # Round up to reasonable values
        total_cpu = math.ceil(total_cpu)
        total_ram = math.ceil(total_ram)
        total_disk = math.ceil(total_disk)

        # Apply safety margins (production best practice)
        total_cpu = int(total_cpu * 1.2)  # 20% CPU headroom
        total_ram = int(total_ram * 1.3)  # 30% RAM headroom
        total_disk = int(total_disk * 1.5)  # 50% disk headroom

        # Minimum viable requirements (don't go below these)
        total_cpu = max(total_cpu, 2)
        total_ram = max(total_ram, 4)
        total_disk = max(total_disk, 50)

        results = {
            'input_parameters': {
                'concurrent_users': concurrent_users,
                'database_size_gb': db_size_gb,
                'transactions_per_hour': transactions_per_hour,
                'has_ecommerce': has_ecommerce,
                'has_manufacturing': has_manufacturing,
                'has_accounting': has_accounting
            },
            'calculated_requirements': {
                'cpu_cores': total_cpu,
                'ram_gb': total_ram,
                'disk_gb': total_disk,
                'recommended_workers': recommended_workers
            },
            'categorization': {
                'database_category': db_category,
                'transaction_category': trans_category
            },
            'recommendations': self.generate_recommendations(total_cpu, total_ram, total_disk, 
                                                           concurrent_users, recommended_workers)
        }

        return results

    def generate_recommendations(self, cpu, ram, disk, users, workers):
        """Generate specific server and configuration recommendations"""
        recommendations = {
            'server_specs': {},
            'postgresql_config': {},
            'odoo_config': {},
            'monitoring_alerts': {}
        }

        # Server specifications
        if cpu <= 4 and ram <= 8:
            tier = "Basic"
            recommendations['server_specs'] = {
                'tier': tier,
                'cpu_type': 'Shared/Burstable CPU (AWS t3.large, DigitalOcean 4GB)',
                'storage_type': 'SSD (minimum 3000 IOPS)',
                'network': 'Standard bandwidth',
                'estimated_monthly_cost': '$50-80'
            }
        elif cpu <= 8 and ram <= 16:
            tier = "Professional"
            recommendations['server_specs'] = {
                'tier': tier,
                'cpu_type': 'Dedicated CPU (AWS c5.2xlarge, DigitalOcean 8GB)',
                'storage_type': 'High-Performance SSD (6000+ IOPS)',
                'network': 'Enhanced networking',
                'estimated_monthly_cost': '$150-250'
            }
        else:
            tier = "Enterprise"
            recommendations['server_specs'] = {
                'tier': tier,
                'cpu_type': 'High-Performance CPU (AWS c5.4xlarge+)',
                'storage_type': 'NVMe SSD or Provisioned IOPS',
                'network': 'High-performance networking',
                'estimated_monthly_cost': '$400-800+'
            }

        # PostgreSQL configuration
        shared_buffers = min(int(ram * 0.25 * 1024), 8192)  # 25% of RAM, max 8GB
        effective_cache = int(ram * 0.75 * 1024)  # 75% of RAM
        work_mem = max(4, int((ram * 1024) / (workers * 2)))  # Conservative work_mem
        
        recommendations['postgresql_config'] = {
            'shared_buffers': f"{shared_buffers}MB",
            'effective_cache_size': f"{effective_cache}MB",
            'work_mem': f"{work_mem}MB",
            'maintenance_work_mem': f"{min(2048, int(ram * 0.1 * 1024))}MB",
            'max_connections': min(200, workers * 10 + 50),
            'checkpoint_completion_target': 0.9,
            'wal_buffers': '16MB',
            'random_page_cost': 1.1  # SSD assumption
        }

        # Odoo configuration
        recommendations['odoo_config'] = {
            'workers': workers,
            'max_cron_threads': max(1, workers // 4),
            'limit_memory_hard': int(ram * 1024 * 1024 * 1024 * 0.8 / workers),  # 80% RAM per worker
            'limit_memory_soft': int(ram * 1024 * 1024 * 1024 * 0.6 / workers),  # 60% RAM per worker
            'limit_time_cpu': 600,  # 10 minutes
            'limit_time_real': 1200,  # 20 minutes
            'limit_request': 8192
        }

        # Monitoring alerts
        recommendations['monitoring_alerts'] = {
            'cpu_usage_threshold': '80%',
            'memory_usage_threshold': '85%',
            'disk_usage_threshold': '85%',
            'response_time_threshold': '2 seconds',
            'concurrent_connections_threshold': recommendations['postgresql_config']['max_connections'] * 0.8
        }

        return recommendations

    def print_results(self, results):
        """Print formatted calculation results"""
        print("🎯 CALCULATION RESULTS")
        print("=" * 30)
        
        req = results['calculated_requirements']
        print(f"CPU Cores: {req['cpu_cores']}")
        print(f"RAM: {req['ram_gb']}GB")
        print(f"Storage: {req['disk_gb']}GB SSD")
        print(f"Recommended Workers: {req['recommended_workers']}")
        
        print(f"\nDatabase Category: {results['categorization']['database_category']}")
        print(f"Transaction Load: {results['categorization']['transaction_category']}")
        
        print("\n💰 SERVER RECOMMENDATIONS")
        print("=" * 30)
        server = results['recommendations']['server_specs']
        print(f"Tier: {server['tier']}")
        print(f"CPU Type: {server['cpu_type']}")
        print(f"Storage: {server['storage_type']}")
        print(f"Est. Monthly Cost: {server['estimated_monthly_cost']}")
        
        print("\n🐘 POSTGRESQL CONFIGURATION")
        print("=" * 30)
        pg = results['recommendations']['postgresql_config']
        for key, value in pg.items():
            print(f"{key} = {value}")
        
        print("\n⚙️  ODOO CONFIGURATION")
        print("=" * 30)
        odoo = results['recommendations']['odoo_config']
        for key, value in odoo.items():
            print(f"{key} = {value}")

    def save_results(self, results, filename=None):
        """Save results to JSON file"""
        if filename is None:
            filename = f"odoo_server_specs_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        
        with open(filename, 'w') as f:
            json.dump(results, f, indent=2)
        
        print(f"\n💾 Results saved to: {filename}")
        return filename

def main():
    calculator = OdooServerCalculator()
    
    print("🔧 Odoo Server Hardware Calculator")
    print("Please answer the following questions about your deployment:")
    print()
    
    try:
        # Get user input
        concurrent_users = int(input("How many concurrent users? (people using Odoo simultaneously): "))
        db_size_gb = float(input("Current database size in GB (or estimated for new installation): "))
        transactions_per_hour = int(input("Estimated transactions per hour (sales orders, invoices, etc.): "))
        
        print("\nModules in use:")
        has_ecommerce = input("E-commerce/Website (y/n): ").lower().startswith('y')
        has_manufacturing = input("Manufacturing/MRP (y/n): ").lower().startswith('y')
        has_accounting = input("Accounting (y/n): ").lower().startswith('y')
        
        print()
        
        # Calculate requirements
        results = calculator.calculate_requirements(
            concurrent_users=concurrent_users,
            db_size_gb=db_size_gb,
            transactions_per_hour=transactions_per_hour,
            has_ecommerce=has_ecommerce,
            has_manufacturing=has_manufacturing,
            has_accounting=has_accounting
        )
        
        # Display results
        calculator.print_results(results)
        
        # Save results
        save_file = input("\nSave results to file? (y/n): ").lower().startswith('y')
        if save_file:
            calculator.save_results(results)
        
        print("\n✅ Calculation complete!")
        print("💡 Pro tip: Add 20% to these specs if you plan to grow in the next 2 years")
        
    except KeyboardInterrupt:
        print("\n\nCalculation cancelled.")
    except ValueError as e:
        print(f"\n❌ Invalid input: Please enter numeric values where requested.")
    except Exception as e:
        print(f"\n❌ Error: {e}")

if __name__ == "__main__":
    main()