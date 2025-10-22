#!/usr/bin/env python3
"""
Odoo Inter-company Transaction Manager
Automatically creates offsetting journal entries for inter-company transactions
"""

def create_intercompany_transaction(
    source_company,
    target_company,
    amount,
    description
):
    """Automatically create offsetting journal entries for inter-company transactions"""

    # Create expense in source company
    source_entry = env['account.move'].create({
        'company_id': source_company.id,
        'move_type': 'entry',
        'line_ids': [
            (0, 0, {
                'account_id': intercompany_expense_account.id,
                'debit': amount,
                'name': f"Inter-company expense: {description}",
            }),
            (0, 0, {
                'account_id': intercompany_payable_account.id,
                'credit': amount,
                'name': f"Due to {target_company.name}",
            }),
        ]
    })

    # Create corresponding revenue in target company
    target_entry = env['account.move'].create({
        'company_id': target_company.id,
        'move_type': 'entry',
        'line_ids': [
            (0, 0, {
                'account_id': intercompany_receivable_account.id,
                'debit': amount,
                'name': f"Due from {source_company.name}",
            }),
            (0, 0, {
                'account_id': intercompany_revenue_account.id,
                'credit': amount,
                'name': f"Inter-company revenue: {description}",
            }),
        ]
    })

    # Link the entries for consolidation reporting
    source_entry.intercompany_link_id = target_entry.id
    target_entry.intercompany_link_id = source_entry.id