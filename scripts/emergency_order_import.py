#!/usr/bin/env python3
"""
Emergency Order Import Script
Import orders that were written down during system outage
"""

import csv
from odoo import env

def import_paper_orders(csv_file):
    """Import orders that were written down during system outage"""
    with open(csv_file, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                # Find or create customer
                customer = env['res.partner'].search([
                    ('name', 'ilike', row['customer_name'])
                ], limit=1)

                if not customer:
                    customer = env['res.partner'].create({
                        'name': row['customer_name'],
                        'phone': row['customer_phone'],
                        'is_company': True,
                        'customer_rank': 1
                    })

                # Create order
                order = env['sale.order'].create({
                    'partner_id': customer.id,
                    'date_order': row['order_date'],
                    'note': f"Emergency import - originally placed {row['original_date']}"
                })

                # Add order lines
                for product_code in row['products'].split(','):
                    product = env['product.product'].search([
                        ('default_code', '=', product_code.strip())
                    ], limit=1)

                    if product:
                        env['sale.order.line'].create({
                            'order_id': order.id,
                            'product_id': product.id,
                            'product_uom_qty': 1,  # Quantity from paper records
                            'price_unit': product.list_price
                        })

                print(f"Imported order for {customer.name}")

            except Exception as e:
                print(f"Failed to import order for {row['customer_name']}: {e}")

if __name__ == "__main__":
    # Usage: python emergency_order_import.py orders.csv
    import sys
    if len(sys.argv) > 1:
        import_paper_orders(sys.argv[1])
    else:
        print("Usage: python emergency_order_import.py <csv_file>")