#!/usr/bin/env python3
"""Comprehensive scan for sensitive data patterns and data masking implementation"""

import re
import hashlib
import logging

def scan_for_sensitive_data():
    """Comprehensive scan for sensitive data patterns"""
    
    sensitive_patterns = {
        'credit_card': r'\b(?:\d{4}[-\s]?){3}\d{4}\b',
        'ssn': r'\b\d{3}-\d{2}-\d{4}\b',
        'email': r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
        'phone': r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b',
        'iban': r'\b[A-Z]{2}\d{2}[A-Z0-9]{4}\d{7}([A-Z0-9]?){0,16}\b',
        'passport': r'\b[A-Z]{1,2}\d{6,9}\b'
    }
    
    # Scan text fields across all tables
    for model_name in env.registry:
        try:
            model = env[model_name]
            if hasattr(model, '_fields'):
                for field_name, field in model._fields.items():
                    if field.type in ('char', 'text', 'html'):
                        # Search for sensitive patterns
                        records = model.search([])
                        for record in records:
                            field_value = getattr(record, field_name, '')
                            if field_value:
                                for pattern_name, pattern in sensitive_patterns.items():
                                    if re.search(pattern, str(field_value)):
                                        # Log potential sensitive data
                                        env['sensitive.data.log'].create({
                                            'model': model_name,
                                            'record_id': record.id,
                                            'field': field_name,
                                            'pattern_type': pattern_name,
                                            'found_value': str(field_value)[:100],  # Truncated for security
                                            'discovery_date': fields.Datetime.now(),
                                            'review_required': True
                                        })
        except Exception as e:
            logging.error(f"Error scanning {model_name}: {e}")

def implement_data_masking():
    """Implement data masking for non-production environments"""
    
    masking_rules = {
        'res.partner': {
            'email': lambda x: f"masked_{hash(x)[:8]}@example.com",
            'phone': lambda x: "555-0100" if x else False,
            'street': lambda x: "123 Main Street" if x else False,
            'name': lambda x: f"Customer {hash(x) % 10000}" if x else False
        },
        'hr.employee': {
            'work_email': lambda x: f"employee_{hash(x)[:8]}@company.com",
            'private_email': lambda x: f"private_{hash(x)[:8]}@example.com",
            'identification_id': lambda x: "***MASKED***" if x else False
        }
    }
    
    for model_name, field_rules in masking_rules.items():
        model = env[model_name]
        records = model.search([])
        
        for record in records:
            update_values = {}
            for field_name, masking_func in field_rules.items():
                current_value = getattr(record, field_name, False)
                if current_value:
                    update_values[field_name] = masking_func(current_value)
            
            if update_values:
                record.write(update_values)

if __name__ == "__main__":
    print("Sensitive Data Scanner and Masking Tool")
    print("This script should be run within Odoo environment")
    print("Usage: python3 sensitive_data_scanner.py")