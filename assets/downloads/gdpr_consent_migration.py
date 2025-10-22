#!/usr/bin/env python3
"""
GDPR Consent Migration Model
Track and validate GDPR consent during Odoo migration
"""

from odoo import models, fields, api
from odoo.exceptions import ValidationError

class GDPRConsentMigration(models.Model):
    _name = 'gdpr.consent.migration'
    _description = 'GDPR Consent Tracking During Migration'

    partner_id = fields.Many2one('res.partner', 'Data Subject')
    consent_type = fields.Selection([
        ('marketing', 'Marketing Communications'),
        ('analytics', 'Analytics and Tracking'),
        ('essential', 'Essential Business Operations'),
        ('profiling', 'Automated Decision Making')
    ])
    consent_given = fields.Boolean('Consent Given')
    consent_date = fields.Datetime('Consent Date')
    consent_method = fields.Selection([
        ('explicit', 'Explicit Consent (Opt-in)'),
        ('legitimate', 'Legitimate Business Interest'),
        ('contract', 'Contractual Necessity'),
        ('legal', 'Legal Obligation')
    ])
    migration_verified = fields.Boolean('Verified During Migration')

    def validate_consent_during_migration(self):
        """Validate that all consent records are properly documented"""
        invalid_consents = self.search([
            ('consent_given', '=', True),
            ('consent_date', '=', False)
        ])

        if invalid_consents:
            raise ValidationError(
                f"Found {len(invalid_consents)} consent records without proper documentation. "
                "GDPR compliance requires explicit consent documentation."
            )