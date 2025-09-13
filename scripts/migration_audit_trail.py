#!/usr/bin/env python3
"""
Migration Audit Trail Model
Comprehensive audit trail for migration activities with compliance tracking
"""

import json
from odoo import models, fields, api

class MigrationAuditTrail(models.Model):
    _name = 'migration.audit.trail'
    _description = 'Comprehensive Audit Trail for Migration Activities'
    _order = 'timestamp desc'

    timestamp = fields.Datetime('Timestamp', default=fields.Datetime.now)
    user_id = fields.Many2one('res.users', 'User')
    session_id = fields.Char('Session ID')
    ip_address = fields.Char('IP Address')
    user_agent = fields.Text('User Agent')

    action_type = fields.Selection([
        ('read', 'Data Read'),
        ('write', 'Data Write'),
        ('delete', 'Data Delete'),
        ('export', 'Data Export'),
        ('import', 'Data Import'),
        ('backup', 'Backup Creation'),
        ('restore', 'Backup Restore'),
        ('login', 'System Login'),
        ('logout', 'System Logout'),
        ('admin', 'Administrative Action')
    ])

    table_name = fields.Char('Database Table')
    record_id = fields.Integer('Record ID')
    field_name = fields.Char('Field Name')
    old_value = fields.Text('Previous Value')
    new_value = fields.Text('New Value')

    data_sensitivity = fields.Selection([
        ('public', 'Public Data'),
        ('internal', 'Internal Data'),
        ('confidential', 'Confidential Data'),
        ('restricted', 'Restricted Data'),
        ('personal', 'Personal Data (GDPR)')
    ])

    compliance_flags = fields.Text('Compliance Flags')
    migration_phase = fields.Selection([
        ('preparation', 'Migration Preparation'),
        ('backup', 'Backup Phase'),
        ('transfer', 'Data Transfer'),
        ('validation', 'Validation Phase'),
        ('cutover', 'System Cutover'),
        ('post_migration', 'Post-Migration')
    ])

    @api.model
    def log_migration_activity(self, action_type, details):
        """Log all migration activities with full context"""
        request = self.env.context.get('request')

        self.create({
            'action_type': action_type,
            'user_id': self.env.user.id,
            'session_id': request.session.sid if request else 'system',
            'ip_address': request.httprequest.remote_addr if request else 'localhost',
            'user_agent': request.httprequest.user_agent.string if request else 'system',
            'table_name': details.get('table_name'),
            'record_id': details.get('record_id'),
            'field_name': details.get('field_name'),
            'old_value': details.get('old_value'),
            'new_value': details.get('new_value'),
            'data_sensitivity': details.get('data_sensitivity', 'internal'),
            'migration_phase': details.get('migration_phase'),
            'compliance_flags': json.dumps(details.get('compliance_flags', {}))
        })