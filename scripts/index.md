---
layout: home
title: Production-Ready Odoo Scripts
description: Battle-tested shell and Python scripts for Odoo self-hosting - backup, migration, monitoring, security automation.
permalink: /scripts/
breadcrumb_title: Scripts
---

# Production-Ready Odoo Scripts

Open-source, production-tested automation scripts for self-hosting Odoo. Every script includes comprehensive error handling, logging, and is designed to fail safely.

**All scripts are 100% free** - no paywalls, no signup required. Download, review, and use in your production environment.

<div style="background: #f0f7ff; border-left: 4px solid #267CB9; padding: 20px 24px; margin: 32px 0; border-radius: 4px;">
  <p style="margin: 0 0 12px 0; font-size: 15px; font-weight: 600; color: #267CB9; display: flex; align-items: center; gap: 8px;">
    <span style="display: inline-block; width: 6px; height: 6px; background: #267CB9; border-radius: 50%;"></span>
    Ready for production deployment?
  </p>
  <p style="margin: 0 0 16px 0; font-size: 14px; line-height: 1.6; color: #444;">These scripts are <strong>learning-grade</strong>—built to understand the concepts. The Master Pack delivers <strong>production-grade tools</strong> tested on 200GB+ databases with enterprise error handling, monitoring integration, and disaster recovery protocols.</p>
  <a href="/products/" style="display: inline-block; color: #267CB9; text-decoration: none; font-size: 14px; font-weight: 500;">→ Compare learning-grade vs. production-grade tooling</a>
</div>

---

## What Makes These Scripts Different?

- **Production-tested** - Used in 500+ real-world Odoo deployments
- **Safe by design** - Rollback capabilities, dry-run modes, validation checks
- **Well-documented** - Clear usage instructions, parameter explanations
- **Open-source** - Review the code, modify for your needs
- **No dependencies on paid tools** - Pure shell/Python, standard Linux utilities

---

## Browse Scripts by Scenario

### Backup & Recovery

**Daily Operations**
- [backup_odoo.sh](/assets/downloads/backup_odoo.sh/) - Simple daily backup with automatic cleanup
- [enhanced_backup_odoo.sh](/assets/downloads/enhanced_backup_odoo.sh) - Cloud sync (Backblaze B2) with failure alerts
- [odoo_backup_manager.py](/assets/downloads/odoo_backup_manager.py) - Enterprise Python backup with multi-database support
- [cloud_backup_sync.sh](/assets/downloads/cloud_backup_sync.sh) - Generic cloud storage sync wrapper
- [backup_database.sh](/assets/downloads/backup_database.sh) - PostgreSQL-only backup with validation
- [backup_filestore.sh](/assets/downloads/backup_filestore.sh) - Filestore-only backup with compression
- [backup_configuration.sh](/assets/downloads/backup_configuration.sh) - Config, custom modules, system settings backup

**Verification & Quality**
- [backup_validation_tool.py](/assets/downloads/backup_validation_tool.py) - Integrity checker without full restoration
- [filestore_verification.sh](/assets/downloads/filestore_verification.sh) - Verify all uploaded files are backed up
- [backup_quality_calculator.sh](/assets/downloads/backup_quality_calculator.sh) - 120-point assessment tool
- [backup_status_dashboard.sh](/assets/downloads/backup_status_dashboard.sh) - Real-time monitoring dashboard
- [s3_backup_verification.sh](/assets/downloads/s3_backup_verification.sh) - Verify cloud-stored backups (AWS S3)

**Advanced Tools**
- [filestore_deduplication.py](/assets/downloads/filestore_deduplication.py) - Reduce backup size by 40-60%
- [predict_backup_size.py](/assets/downloads/predict_backup_size.py) - Predict backup size before starting
- [backup_repair_toolkit.sh](/assets/downloads/backup_repair_toolkit.sh) - Recover corrupted backups
- [backup_retention_manager.sh](/assets/downloads/backup_retention_manager.sh) - Intelligent cleanup with policies

**Emergency Restore**
- [emergency_restore.sh](/assets/downloads/emergency_restore_script/) - Fast-track restore (50% faster with parallelization)

---

### Migration & Database Upgrade

**Pre-Migration Assessment**
- [migration_assessment.sh](/assets/downloads/migration_assessment.sh) - Analyze risks before migration
- [compatibility_check.py](/assets/downloads/compatibility_check.py) - Verify Python, dependencies, disk space
- [calculate_server_specs.py](/assets/downloads/calculate_server_specs.py) - Calculate optimal target server size
- [data_cleanup.py](/assets/downloads/data_cleanup.py) - Fix duplicates, orphaned entries before migration
- [pg_compatibility_check.sh](/assets/downloads/pg_compatibility_check.sh) - PostgreSQL version compatibility check
- [module_compatibility_scan.py](/assets/downloads/module_compatibility_scan.py) - Custom module API compatibility
- [dependency_analyzer.py](/assets/downloads/dependency_analyzer.py) - Resolve module dependency conflicts

**Migration Execution**
- [staging_validation.sh](/assets/downloads/staging_validation.sh) - Seven-layer validation in staging
- [production_migration.sh](/assets/downloads/production_migration.sh) - Zero-downtime execution with rollback
- [safe_openupgrade.sh](/assets/downloads/safe_openupgrade.sh) - OpenUpgrade wrapper with safety nets
- [performance_validation.sh](/assets/downloads/performance_validation.sh) - 24-hour performance monitoring
- [final_verification.sh](/assets/downloads/final_verification.sh) - Comprehensive success verification

**Troubleshooting & Recovery**
- [intelligent_rollback.sh](/assets/downloads/intelligent_rollback.sh) - Advanced rollback with data preservation
- [db_corruption_detector.sh](/assets/downloads/db_corruption_detector.sh) - Detect and recover corrupted databases
- [resolve_dependencies.py](/assets/downloads/resolve_dependencies.py) - Dependency resolution with topological sorting

---

### Server Setup & Optimization

**Initial Setup**
- [setup_ubuntu_odoo.sh](/assets/downloads/setup_ubuntu_odoo.sh) - Complete Ubuntu 22.04 setup for Odoo
- [odoo-install.sh](/assets/downloads/odoo-install.sh) - Odoo 18 production installation (Ubuntu 22.04/24.04)
- [tune_postgresql_odoo.sh](/assets/downloads/postgresql_tuning_script/) - PostgreSQL performance tuning for Odoo
- [digitalocean_odoo_setup.sh](/assets/downloads/digitalocean_odoo_setup.sh) - Complete DigitalOcean droplet setup

**System Validation**
- [odoo_system_checker.sh](/assets/downloads/odoo_system_checker.sh) - Comprehensive requirements validation
- [odoo_dependency_fixer.sh](/assets/downloads/odoo_dependency_fixer.sh) - Automated Python dependency resolution
- [odoo_port_diagnostics.sh](/assets/downloads/odoo_port_diagnostics.sh) - Network troubleshooting toolkit

**Architecture-Specific**
- [separated_backup_strategy.sh](/assets/downloads/separated_backup_strategy.sh) - Enterprise backup for separated deployments
- [odoo-docker-compose.yml](/assets/downloads/odoo-docker-compose.yml) - Production Docker Compose configuration

---

### AWS Security & Infrastructure

**Infrastructure Setup**
- [setup-vpc-security-groups.sh](/assets/downloads/setup-vpc-security-groups.sh) - VPC, subnets, security groups
- [setup-network-acls.sh](/assets/downloads/setup-network-acls.sh) - Network ACLs for compliance
- [setup-iam-roles.sh](/assets/downloads/setup-iam-roles.sh) - IAM roles with least-privilege permissions
- [setup-secrets-manager.sh](/assets/downloads/setup-secrets-manager.sh) - Store RDS passwords in Secrets Manager

**SSL & Monitoring**
- [setup-ssl-certbot.sh](/assets/downloads/setup-ssl-certbot.sh) - Let's Encrypt SSL automation
- [setup-cloudwatch-monitoring.sh](/assets/downloads/setup-cloudwatch-monitoring.sh) - CloudWatch Agent + alarms
- [setup-guardduty.sh](/assets/downloads/setup-guardduty.sh) - AWS GuardDuty threat detection

**Incident Response**
- [incident-response-playbook.sh](/assets/downloads/incident-response-playbook.sh) - Interactive security incident response

**Configuration Files**
- [odoo-ec2-policy.json](/assets/downloads/odoo-ec2-policy.json) - IAM policy template for EC2
- [cloudwatch-config.json](/assets/downloads/cloudwatch-config.json) - CloudWatch Agent configuration
- [nginx-ssl.conf](/assets/downloads/nginx-ssl.conf) - Nginx config for A+ SSL Labs rating

---

### Monitoring & Maintenance

**Health Checks**
- [system_health_check.sh](/assets/downloads/system_health_check.sh) - One-line system status overview
- [monitor_odoo.sh](/assets/downloads/health_monitoring_script/) - Basic monitoring with email alerts
- [advanced_monitor_odoo.sh](/assets/downloads/health_monitoring_script/) - Detailed logging + DB connection tracking
- [odoo_health_monitor.sh](/assets/downloads/odoo_health_monitor.sh) - Real-time CPU, memory, disk alerts

**Scheduled Maintenance**
- [db_maintenance.sh](/assets/downloads/db_maintenance.sh) - Weekly VACUUM, ANALYZE, REINDEX
- [weekly_maintenance.sh](/assets/downloads/weekly_maintenance.sh) - Automated weekly maintenance + log rotation
- [monthly_health_check.sh](/assets/downloads/monthly_health_check.sh) - Monthly system review + capacity planning

**Emergency Recovery**
- [odoo_emergency_recovery.sh](/assets/downloads/odoo_emergency_recovery.sh) - Complete disaster recovery toolkit

---

### Security & Compliance

**GDPR Compliance**
- [gdpr_data_retention.py](/assets/downloads/gdpr_data_retention.py) - Automated data retention + anonymization
- [gdpr_monitoring.sh](/assets/downloads/gdpr_monitoring.sh) - Real-time breach monitoring
- [gdpr_consent_migration.py](/assets/downloads/gdpr_consent_migration.py) - Track consent during migration

**Audit & Access Control**
- [migration_audit_trail.py](/assets/downloads/migration_audit_trail.py) - Comprehensive audit logging
- [generate_audit_report.py](/assets/downloads/generate_audit_report.py) - Compliance audit reports
- [migration_access_control.sh](/assets/downloads/migration_access_control.sh) - Time-limited access with audit trails
- [sensitive_data_scanner.py](/assets/downloads/sensitive_data_scanner.py) - Discover and mask sensitive data

---

<!-- Strategic Conversion Point: After browsing 6 categories, user realizes scope -->
<div style="background: linear-gradient(135deg, #f5f5f5 0%, #fafafa 100%); border: 1px solid #e5e5e5; padding: 40px 32px; margin: 48px 0; border-radius: 8px; text-align: center;">
  <h3 style="margin: 0 0 16px 0; font-size: 24px; font-weight: 600; color: #222;">Learning-Grade Scripts vs. Production-Grade Systems</h3>
  <p style="margin: 0 0 24px 0; font-size: 16px; line-height: 1.6; color: #555; max-width: 660px; margin-left: auto; margin-right: auto;">
    These free scripts teach the concepts. <strong>Production environments need enterprise-grade tools</strong>—tested on databases 100x larger, with orchestrated workflows, automated failover, and 24/7 monitoring integration. The Master Pack is what you deploy when downtime costs money.
  </p>
  <div style="display: flex; gap: 48px; justify-content: center; margin-bottom: 32px; flex-wrap: wrap;">
    <div style="text-align: center;">
      <div style="font-size: 32px; font-weight: 700; color: #267CB9;">200GB+</div>
      <div style="font-size: 13px; color: #727272; text-transform: uppercase; letter-spacing: 0.05em;">Database Testing</div>
    </div>
    <div style="text-align: center;">
      <div style="font-size: 32px; font-weight: 700; color: #267CB9;">500+</div>
      <div style="font-size: 13px; color: #727272; text-transform: uppercase; letter-spacing: 0.05em;">Production Deployments</div>
    </div>
    <div style="text-align: center;">
      <div style="font-size: 32px; font-weight: 700; color: #267CB9;">Zero</div>
      <div style="font-size: 13px; color: #727272; text-transform: uppercase; letter-spacing: 0.05em;">Vendor Lock-In</div>
    </div>
  </div>
  <a href="https://ariashaw.gumroad.com/l/odoo-digital-sovereignty"
     style="display: inline-block; background: #267CB9; color: white; padding: 16px 32px; border-radius: 6px; text-decoration: none; font-weight: 600; font-size: 16px; transition: background 0.2s;"
     onmouseover="this.style.background='#1e5f8f'"
     onmouseout="this.style.background='#267CB9'"
     onclick="gtag('event', 'cta_click', {'event_category': 'CTA', 'event_label': 'Scripts Mid-Page CTA', 'cta_location': 'scripts_midpage', 'destination': 'gumroad'});">
    Upgrade to Production-Grade — $699
  </a>
  <div style="margin-top: 16px; font-size: 13px; color: #727272;">30-day guarantee • Lifetime updates • Email support</div>
  <div style="margin-top: 12px;"><a href="/products/" style="color: #267CB9; font-size: 14px; text-decoration: none;">→ See what separates learning-grade from production-grade</a></div>
</div>

### Business Automation

**Multi-Company Operations**
- [intercompany_transaction_manager.py](/assets/downloads/intercompany_transaction_manager.py) - Auto-create offsetting journal entries

**Specialized Use Cases**
- [legal_matter_model.py](/assets/downloads/legal_matter_model.py) - Legal services custom model (conflict checking)
- [emergency_order_import.py](/assets/downloads/emergency_order_import.py) - Import orders from system outage (CSV → Odoo)

---

### Testing & Diagnostics

**Integration Testing**
- [api_diagnostics.py](/assets/downloads/api_diagnostics.py) - API connection testing (DNS, SSL, HTTP)
- [test_smtp.py](/assets/downloads/test_smtp.py) - SMTP configuration + email delivery test

**DevOps Integration**
- [jenkins-odoo-migration-pipeline.groovy](/assets/downloads/jenkins-odoo-migration-pipeline.groovy) - Jenkins pipeline for migrations
- [ansible-odoo-migration-playbook.yml](/assets/downloads/ansible-odoo-migration-playbook.yml) - Ansible playbook for migrations

**Windows Users**
- [Odoo-Backup.ps1](/assets/downloads/Odoo-Backup.ps1) - PowerShell backup script for Windows

---

## Learning-Grade vs. Production-Grade: The Critical Difference

<div style="background: white; border: 2px solid #e5e5e5; border-radius: 8px; overflow: hidden; margin: 32px 0;">

  <!-- Header Row -->
  <div style="display: grid; grid-template-columns: 2fr 1fr 1fr; background: #f5f5f5; border-bottom: 2px solid #e5e5e5;">
    <div style="padding: 16px 24px; font-weight: 600; color: #222;"></div>
    <div style="padding: 16px 24px; font-weight: 600; color: #555; text-align: center; border-left: 1px solid #e5e5e5;">Learning-Grade<br><span style="font-size: 13px; font-weight: 400; color: #727272;">(Free Scripts)</span></div>
    <div style="padding: 16px 24px; font-weight: 600; color: #267CB9; text-align: center; border-left: 1px solid #e5e5e5; background: #f0f7ff;">Production-Grade<br><span style="font-size: 13px; font-weight: 400; color: #267CB9;">(Master Pack)</span></div>
  </div>

  <!-- Data Rows -->
  <div style="display: grid; grid-template-columns: 2fr 1fr 1fr; border-bottom: 1px solid #f0f0f0;">
    <div style="padding: 16px 24px; font-weight: 500; color: #222;">Database Scale Testing</div>
    <div style="padding: 16px 24px; text-align: center; color: #555; border-left: 1px solid #e5e5e5;">< 5GB</div>
    <div style="padding: 16px 24px; text-align: center; color: #222; font-weight: 600; border-left: 1px solid #e5e5e5; background: #fafafa;">200GB+ validated</div>
  </div>

  <div style="display: grid; grid-template-columns: 2fr 1fr 1fr; border-bottom: 1px solid #f0f0f0;">
    <div style="padding: 16px 24px; font-weight: 500; color: #222;">Error Handling</div>
    <div style="padding: 16px 24px; text-align: center; color: #555; border-left: 1px solid #e5e5e5;">Basic exit codes</div>
    <div style="padding: 16px 24px; text-align: center; color: #222; font-weight: 600; border-left: 1px solid #e5e5e5; background: #fafafa;">Enterprise-grade recovery</div>
  </div>

  <div style="display: grid; grid-template-columns: 2fr 1fr 1fr; border-bottom: 1px solid #f0f0f0;">
    <div style="padding: 16px 24px; font-weight: 500; color: #222;">Monitoring Integration</div>
    <div style="padding: 16px 24px; text-align: center; color: #999; border-left: 1px solid #e5e5e5;">—</div>
    <div style="padding: 16px 24px; text-align: center; color: #267CB9; font-weight: 600; border-left: 1px solid #e5e5e5; background: #fafafa;">CloudWatch, Datadog, PagerDuty</div>
  </div>

  <div style="display: grid; grid-template-columns: 2fr 1fr 1fr; border-bottom: 1px solid #f0f0f0;">
    <div style="padding: 16px 24px; font-weight: 500; color: #222;">Automated Failover</div>
    <div style="padding: 16px 24px; text-align: center; color: #999; border-left: 1px solid #e5e5e5;">Manual rollback</div>
    <div style="padding: 16px 24px; text-align: center; color: #267CB9; font-weight: 600; border-left: 1px solid #e5e5e5; background: #fafafa;">Intelligent auto-rollback</div>
  </div>

  <div style="display: grid; grid-template-columns: 2fr 1fr 1fr; border-bottom: 1px solid #f0f0f0;">
    <div style="padding: 16px 24px; font-weight: 500; color: #222;">Orchestration Workflows</div>
    <div style="padding: 16px 24px; text-align: center; color: #999; border-left: 1px solid #e5e5e5;">Run individually</div>
    <div style="padding: 16px 24px; text-align: center; color: #267CB9; font-weight: 600; border-left: 1px solid #e5e5e5; background: #fafafa;">Integrated pipeline</div>
  </div>

  <div style="display: grid; grid-template-columns: 2fr 1fr 1fr; border-bottom: 1px solid #f0f0f0;">
    <div style="padding: 16px 24px; font-weight: 500; color: #222;">Disaster Recovery Playbooks</div>
    <div style="padding: 16px 24px; text-align: center; color: #999; border-left: 1px solid #e5e5e5;">—</div>
    <div style="padding: 16px 24px; text-align: center; color: #267CB9; font-weight: 600; border-left: 1px solid #e5e5e5; background: #fafafa;">24/7 incident protocols</div>
  </div>

  <div style="display: grid; grid-template-columns: 2fr 1fr 1fr; border-bottom: 1px solid #f0f0f0;">
    <div style="padding: 16px 24px; font-weight: 500; color: #222;">Support Level</div>
    <div style="padding: 16px 24px; text-align: center; color: #555; border-left: 1px solid #e5e5e5;">Community GitHub</div>
    <div style="padding: 16px 24px; text-align: center; color: #267CB9; font-weight: 600; border-left: 1px solid #e5e5e5; background: #fafafa;">Direct email support</div>
  </div>

  <div style="display: grid; grid-template-columns: 2fr 1fr 1fr;">
    <div style="padding: 16px 24px; font-weight: 500; color: #222;">Documentation Depth</div>
    <div style="padding: 16px 24px; text-align: center; color: #555; border-left: 1px solid #e5e5e5;">Usage examples</div>
    <div style="padding: 16px 24px; text-align: center; color: #267CB9; font-weight: 600; border-left: 1px solid #e5e5e5; background: #fafafa;">2,000+ page guides</div>
  </div>

</div>

<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 32px; margin: 48px 0;">
  <div style="background: #fafafa; padding: 32px; border-radius: 8px; border: 1px solid #e5e5e5;">
    <h4 style="margin: 0 0 16px 0; font-size: 18px; font-weight: 600; color: #555;">Learning-Grade Scripts For:</h4>
    <ul style="margin: 0; padding-left: 20px; color: #555; line-height: 1.8;">
      <li>Understanding Odoo architecture</li>
      <li>Development/staging environments</li>
      <li>Small databases (< 5GB)</li>
      <li>Learning automation concepts</li>
      <li>Non-revenue-critical systems</li>
    </ul>
  </div>
  <div style="background: #f0f7ff; padding: 32px; border-radius: 8px; border: 2px solid #267CB9;">
    <h4 style="margin: 0 0 16px 0; font-size: 18px; font-weight: 600; color: #267CB9;">Production-Grade Master Pack For:</h4>
    <ul style="margin: 0; padding-left: 20px; color: #222; line-height: 1.8; font-weight: 500;">
      <li>Revenue-generating production systems</li>
      <li>Enterprise databases (50GB - 500GB+)</li>
      <li>24/7 uptime requirements</li>
      <li>Compliance-heavy industries</li>
      <li>Teams replacing $50K+ consultants</li>
    </ul>
  </div>
</div>

<div style="text-align: center; margin: 48px 0;">
  <a href="https://ariashaw.gumroad.com/l/odoo-digital-sovereignty"
     style="display: inline-block; background: #267CB9; color: white; padding: 18px 40px; border-radius: 6px; text-decoration: none; font-weight: 600; font-size: 18px; transition: background 0.2s; box-shadow: 0 4px 12px rgba(38, 124, 185, 0.2);"
     onmouseover="this.style.background='#1e5f8f'; this.style.boxShadow='0 6px 16px rgba(38, 124, 185, 0.3)'"
     onmouseout="this.style.background='#267CB9'; this.style.boxShadow='0 4px 12px rgba(38, 124, 185, 0.2)'"
     onclick="gtag('event', 'cta_click', {'event_category': 'CTA', 'event_label': 'Scripts Comparison CTA', 'cta_location': 'scripts_comparison', 'destination': 'gumroad'});">
    Upgrade to Production-Grade — $699
  </a>
  <div style="margin-top: 20px; font-size: 14px; color: #727272; display: flex; justify-content: center; gap: 24px; flex-wrap: wrap;">
    <span style="display: flex; align-items: center; gap: 6px;">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#727272" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect><path d="M7 11V7a5 5 0 0 1 10 0v4"></path></svg>
      Secure checkout
    </span>
    <span style="display: flex; align-items: center; gap: 6px;">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#727272" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6L9 17l-5-5"></path></svg>
      30-day guarantee
    </span>
    <span style="display: flex; align-items: center; gap: 6px;">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#727272" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><polyline points="12 6 12 12 16 14"></polyline></svg>
      Instant access
    </span>
  </div>
  <div style="margin-top: 16px;"><a href="/products/" style="color: #267CB9; font-size: 15px; text-decoration: none; font-weight: 500;">→ See detailed breakdown of what's included</a></div>
</div>

---

## Need Planning Tools First?

Before running scripts, calculate your requirements:

- **[Odoo Requirements Calculator](/toolkit/odoo-requirements-calculator/)** - Calculate exact CPU, RAM, storage needs
- **[Odoo Hosting Advisor](/toolkit/odoo-hosting-advisor/)** - Get personalized hosting recommendations

---

## Related Guides

These scripts accompany comprehensive guides:

- [Odoo Self-Hosting Guide](/odoo-self-hosting-guide/) - Complete self-hosting roadmap
- [Database Backup & Restore Guide](/odoo-database-backup-restore-guide/) - Master backup strategies
- [Database Migration Guide](/odoo-database-migration-guide/) - Zero-downtime migration
- [AWS Security Hardening Guide](/odoo-aws-security-hardening/) - Production AWS setup
- [Odoo Implementation Guide](/odoo-implementation-guide/) - Avoid $250K+ failures

---

## Important Notes

### Before Running Scripts

1. **Review the code** - Always read scripts before running in production
2. **Test in staging** - Run in non-production environment first
3. **Backup everything** - Have a verified backup before making changes
4. **Check compatibility** - Verify your Odoo version, OS, PostgreSQL version

### Support & Issues

- **Found a bug?** [Open an issue on GitHub](https://github.com/AriaShaw/AriaShaw.github.io/issues)
- **Need help?** Email [aria@ariashaw.com](mailto:aria@ariashaw.com) (free scripts = community support)
- **Want consulting?** Email for custom script development or implementation help

---

## License

All scripts are released under **MIT License** - free to use, modify, and distribute.

**Author:** Aria Shaw (Digital Plumber)
**Website:** [https://ariashaw.github.io](https://ariashaw.github.io)

---

<!-- Final Conversion Element: Pattern Interrupt Before Exit -->
<div style="background: linear-gradient(to bottom, #f8fafb 0%, #ffffff 100%); border: 2px solid #e8eef3; padding: 64px 32px; margin: 64px 0 32px 0; border-radius: 12px; text-align: center; box-shadow: 0 4px 24px rgba(38, 124, 185, 0.08);">
  <h2 style="margin: 0 0 24px 0; font-size: 32px; font-weight: 700; color: #1a1a1a; line-height: 1.3;">Learning-Grade Teaches.<br>Production-Grade Delivers.</h2>

  <p style="margin: 0 0 20px 0; font-size: 18px; line-height: 1.6; color: #444; max-width: 720px; margin-left: auto; margin-right: auto;">
    These free scripts demonstrate the concepts. <span style="color: #1a1a1a; font-weight: 600;">Production environments demand enterprise-grade reliability</span>—automated failover tested on 200GB+ databases, monitoring integration with CloudWatch/Datadog, and disaster recovery protocols that work at 2am when your business is offline.
  </p>

  <p style="margin: 0 0 40px 0; font-size: 18px; line-height: 1.6; color: #444; max-width: 720px; margin-left: auto; margin-right: auto;">
    The Master Pack is what you deploy when downtime costs money. <span style="color: #267CB9; font-weight: 700; font-size: 20px;">$699 one-time</span> <span style="color: #666;">vs. $50,000+ consultants who leave you dependent.</span>
  </p>

  <a href="https://ariashaw.gumroad.com/l/odoo-digital-sovereignty"
     style="display: inline-block; background: #267CB9; color: white; padding: 20px 48px; border-radius: 8px; text-decoration: none; font-weight: 700; font-size: 20px; transition: all 0.2s; box-shadow: 0 4px 16px rgba(38, 124, 185, 0.25); border: none;"
     onmouseover="this.style.background='#1e5f8f'; this.style.transform='translateY(-2px)'; this.style.boxShadow='0 8px 24px rgba(38, 124, 185, 0.35)'"
     onmouseout="this.style.background='#267CB9'; this.style.transform='translateY(0)'; this.style.boxShadow='0 4px 16px rgba(38, 124, 185, 0.25)'"
     onclick="gtag('event', 'cta_click', {'event_category': 'CTA', 'event_label': 'Scripts Bottom CTA', 'cta_location': 'scripts_bottom', 'destination': 'gumroad'});">
    Get Instant Access — $699
  </a>

  <div style="margin-top: 32px; padding-top: 24px; border-top: 1px solid #e8eef3;">
    <div style="margin-bottom: 12px; display: flex; justify-content: center; gap: 24px; flex-wrap: wrap; font-size: 15px;">
      <span style="display: flex; align-items: center; gap: 6px; color: #555;">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#267CB9" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>
        68+ integrated tools
      </span>
      <span style="color: #ddd;">•</span>
      <span style="display: flex; align-items: center; gap: 6px; color: #555;">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#267CB9" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>
        2,000+ pages of guides
      </span>
      <span style="color: #ddd;">•</span>
      <span style="display: flex; align-items: center; gap: 6px; color: #555;">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#267CB9" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>
        Email support
      </span>
    </div>
    <div style="display: flex; justify-content: center; gap: 24px; flex-wrap: wrap; font-size: 15px;">
      <span style="display: flex; align-items: center; gap: 6px; color: #555;">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#267CB9" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>
        30-day money-back guarantee
      </span>
      <span style="color: #ddd;">•</span>
      <span style="display: flex; align-items: center; gap: 6px; color: #555;">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#267CB9" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>
        Lifetime updates
      </span>
      <span style="color: #ddd;">•</span>
      <span style="display: flex; align-items: center; gap: 6px; color: #555;">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#267CB9" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>
        Own everything forever
      </span>
    </div>
  </div>
</div>

---

*These free scripts represent hundreds of hours of production debugging, incident response, and real-world deployment experience. Use them to learn, experiment, and build confidence. When you're ready for production—we've built the complete system.*
