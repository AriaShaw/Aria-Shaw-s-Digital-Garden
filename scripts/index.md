---
layout: default
title: Production-Ready Odoo Scripts
description: Battle-tested shell and Python scripts for Odoo self-hosting - backup, migration, monitoring, security automation.
permalink: /scripts/
breadcrumb_title: Scripts
---

# Production-Ready Odoo Scripts

Open-source, production-tested automation scripts for self-hosting Odoo. Every script includes comprehensive error handling, logging, and is designed to fail safely.

**All scripts are 100% free** - no paywalls, no signup required. Download, review, and use in your production environment.

---

## 🎯 What Makes These Scripts Different?

- ✅ **Production-tested** - Used in 500+ real-world Odoo deployments
- ✅ **Safe by design** - Rollback capabilities, dry-run modes, validation checks
- ✅ **Well-documented** - Clear usage instructions, parameter explanations
- ✅ **Open-source** - Review the code, modify for your needs
- ✅ **No dependencies on paid tools** - Pure shell/Python, standard Linux utilities

---

## 📂 Browse Scripts by Scenario

### 💾 Backup & Recovery

**Daily Operations**
- [backup_odoo.sh](/scripts/backup_odoo.sh) - Simple daily backup with automatic cleanup
- [enhanced_backup_odoo.sh](/scripts/enhanced_backup_odoo.sh) - Cloud sync (Backblaze B2) with failure alerts
- [odoo_backup_manager.py](/scripts/odoo_backup_manager.py) - Enterprise Python backup with multi-database support
- [cloud_backup_sync.sh](/scripts/cloud_backup_sync.sh) - Generic cloud storage sync wrapper
- [backup_database.sh](/scripts/backup_database.sh) - PostgreSQL-only backup with validation
- [backup_filestore.sh](/scripts/backup_filestore.sh) - Filestore-only backup with compression
- [backup_configuration.sh](/scripts/backup_configuration.sh) - Config, custom modules, system settings backup

**Verification & Quality**
- [backup_validation_tool.py](/scripts/backup_validation_tool.py) - Integrity checker without full restoration
- [filestore_verification.sh](/scripts/filestore_verification.sh) - Verify all uploaded files are backed up
- [backup_quality_calculator.sh](/scripts/backup_quality_calculator.sh) - 120-point assessment tool
- [backup_status_dashboard.sh](/scripts/backup_status_dashboard.sh) - Real-time monitoring dashboard
- [s3_backup_verification.sh](/scripts/s3_backup_verification.sh) - Verify cloud-stored backups (AWS S3)

**Advanced Tools**
- [filestore_deduplication.py](/scripts/filestore_deduplication.py) - Reduce backup size by 40-60%
- [predict_backup_size.py](/scripts/predict_backup_size.py) - Predict backup size before starting
- [backup_repair_toolkit.sh](/scripts/backup_repair_toolkit.sh) - Recover corrupted backups
- [backup_retention_manager.sh](/scripts/backup_retention_manager.sh) - Intelligent cleanup with policies

**Emergency Restore**
- [emergency_restore.sh](/scripts/emergency_restore.sh) - Fast-track restore (50% faster with parallelization)

---

### 🔄 Migration & Database Upgrade

**Pre-Migration Assessment**
- [migration_assessment.sh](/scripts/migration_assessment.sh) - Analyze risks before migration
- [compatibility_check.py](/scripts/compatibility_check.py) - Verify Python, dependencies, disk space
- [calculate_server_specs.py](/scripts/calculate_server_specs.py) - Calculate optimal target server size
- [data_cleanup.py](/scripts/data_cleanup.py) - Fix duplicates, orphaned entries before migration
- [pg_compatibility_check.sh](/scripts/pg_compatibility_check.sh) - PostgreSQL version compatibility check
- [module_compatibility_scan.py](/scripts/module_compatibility_scan.py) - Custom module API compatibility
- [dependency_analyzer.py](/scripts/dependency_analyzer.py) - Resolve module dependency conflicts

**Migration Execution**
- [staging_validation.sh](/scripts/staging_validation.sh) - Seven-layer validation in staging
- [production_migration.sh](/scripts/production_migration.sh) - Zero-downtime execution with rollback
- [safe_openupgrade.sh](/scripts/safe_openupgrade.sh) - OpenUpgrade wrapper with safety nets
- [performance_validation.sh](/scripts/performance_validation.sh) - 24-hour performance monitoring
- [final_verification.sh](/scripts/final_verification.sh) - Comprehensive success verification

**Troubleshooting & Recovery**
- [intelligent_rollback.sh](/scripts/intelligent_rollback.sh) - Advanced rollback with data preservation
- [db_corruption_detector.sh](/scripts/db_corruption_detector.sh) - Detect and recover corrupted databases
- [resolve_dependencies.py](/scripts/resolve_dependencies.py) - Dependency resolution with topological sorting

---

### 🏗️ Server Setup & Optimization

**Initial Setup**
- [setup_ubuntu_odoo.sh](/scripts/setup_ubuntu_odoo.sh) - Complete Ubuntu 22.04 setup for Odoo
- [odoo-install.sh](/scripts/odoo-install.sh) - Odoo 18 production installation (Ubuntu 22.04/24.04)
- [tune_postgresql_odoo.sh](/scripts/tune_postgresql_odoo.sh) - PostgreSQL performance tuning for Odoo
- [digitalocean_odoo_setup.sh](/scripts/digitalocean_odoo_setup.sh) - Complete DigitalOcean droplet setup

**System Validation**
- [odoo_system_checker.sh](/scripts/odoo_system_checker.sh) - Comprehensive requirements validation
- [odoo_dependency_fixer.sh](/scripts/odoo_dependency_fixer.sh) - Automated Python dependency resolution
- [odoo_port_diagnostics.sh](/scripts/odoo_port_diagnostics.sh) - Network troubleshooting toolkit

**Architecture-Specific**
- [separated_backup_strategy.sh](/scripts/separated_backup_strategy.sh) - Enterprise backup for separated deployments
- [odoo-docker-compose.yml](/scripts/odoo-docker-compose.yml) - Production Docker Compose configuration

---

### 🔒 AWS Security & Infrastructure

**Infrastructure Setup**
- [setup-vpc-security-groups.sh](/scripts/setup-vpc-security-groups.sh) - VPC, subnets, security groups
- [setup-network-acls.sh](/scripts/setup-network-acls.sh) - Network ACLs for compliance
- [setup-iam-roles.sh](/scripts/setup-iam-roles.sh) - IAM roles with least-privilege permissions
- [setup-secrets-manager.sh](/scripts/setup-secrets-manager.sh) - Store RDS passwords in Secrets Manager

**SSL & Monitoring**
- [setup-ssl-certbot.sh](/scripts/setup-ssl-certbot.sh) - Let's Encrypt SSL automation
- [setup-cloudwatch-monitoring.sh](/scripts/setup-cloudwatch-monitoring.sh) - CloudWatch Agent + alarms
- [setup-guardduty.sh](/scripts/setup-guardduty.sh) - AWS GuardDuty threat detection

**Incident Response**
- [incident-response-playbook.sh](/scripts/incident-response-playbook.sh) - Interactive security incident response

**Configuration Files**
- [odoo-ec2-policy.json](/scripts/odoo-ec2-policy.json) - IAM policy template for EC2
- [cloudwatch-config.json](/scripts/cloudwatch-config.json) - CloudWatch Agent configuration
- [nginx-ssl.conf](/scripts/nginx-ssl.conf) - Nginx config for A+ SSL Labs rating

---

### 📊 Monitoring & Maintenance

**Health Checks**
- [system_health_check.sh](/scripts/system_health_check.sh) - One-line system status overview
- [monitor_odoo.sh](/scripts/monitor_odoo.sh) - Basic monitoring with email alerts
- [advanced_monitor_odoo.sh](/scripts/advanced_monitor_odoo.sh) - Detailed logging + DB connection tracking
- [odoo_health_monitor.sh](/scripts/odoo_health_monitor.sh) - Real-time CPU, memory, disk alerts

**Scheduled Maintenance**
- [db_maintenance.sh](/scripts/db_maintenance.sh) - Weekly VACUUM, ANALYZE, REINDEX
- [weekly_maintenance.sh](/scripts/weekly_maintenance.sh) - Automated weekly maintenance + log rotation
- [monthly_health_check.sh](/scripts/monthly_health_check.sh) - Monthly system review + capacity planning

**Emergency Recovery**
- [odoo_emergency_recovery.sh](/scripts/odoo_emergency_recovery.sh) - Complete disaster recovery toolkit

---

### 🔐 Security & Compliance

**GDPR Compliance**
- [gdpr_data_retention.py](/scripts/gdpr_data_retention.py) - Automated data retention + anonymization
- [gdpr_monitoring.sh](/scripts/gdpr_monitoring.sh) - Real-time breach monitoring
- [gdpr_consent_migration.py](/scripts/gdpr_consent_migration.py) - Track consent during migration

**Audit & Access Control**
- [migration_audit_trail.py](/scripts/migration_audit_trail.py) - Comprehensive audit logging
- [generate_audit_report.py](/scripts/generate_audit_report.py) - Compliance audit reports
- [migration_access_control.sh](/scripts/migration_access_control.sh) - Time-limited access with audit trails
- [sensitive_data_scanner.py](/scripts/sensitive_data_scanner.py) - Discover and mask sensitive data

---

### 💼 Business Automation

**Multi-Company Operations**
- [intercompany_transaction_manager.py](/scripts/intercompany_transaction_manager.py) - Auto-create offsetting journal entries

**Specialized Use Cases**
- [legal_matter_model.py](/scripts/legal_matter_model.py) - Legal services custom model (conflict checking)
- [emergency_order_import.py](/scripts/emergency_order_import.py) - Import orders from system outage (CSV → Odoo)

---

### 🧪 Testing & Diagnostics

**Integration Testing**
- [api_diagnostics.py](/scripts/api_diagnostics.py) - API connection testing (DNS, SSL, HTTP)
- [test_smtp.py](/scripts/test_smtp.py) - SMTP configuration + email delivery test

**DevOps Integration**
- [jenkins-odoo-migration-pipeline.groovy](/scripts/jenkins-odoo-migration-pipeline.groovy) - Jenkins pipeline for migrations
- [ansible-odoo-migration-playbook.yml](/scripts/ansible-odoo-migration-playbook.yml) - Ansible playbook for migrations

**Windows Users**
- [Odoo-Backup.ps1](/scripts/Odoo-Backup.ps1) - PowerShell backup script for Windows

---

## 🆚 Free Scripts vs. Master Pack

| Feature | Free Scripts | Master Pack ($699) |
|---------|-------------|-------------------|
| **Script Access** | 70+ individual scripts | 68+ integrated tools + all free scripts |
| **Documentation** | Basic usage instructions | 2,000+ pages of guides |
| **Support** | Community (GitHub issues) | Email support included |
| **Integration** | Run independently | 5 modules working together |
| **Strategic Planning** | Basic calculators | TCO calculator, failure prevention |
| **Updates** | Occasional | Quarterly updates (lifetime) |
| **Production Testing** | Good for learning | Enterprise-grade (tested on 200GB+ DBs) |

**Free scripts are perfect for:**
- Learning Odoo self-hosting
- Small deployments (< 20 users)
- Non-critical environments

**Master Pack is designed for:**
- Production business systems
- Mission-critical deployments
- Complete lifecycle management

[→ See What's in the Master Pack](/products/)

---

## 🧮 Need Planning Tools First?

Before running scripts, calculate your requirements:

- **[Odoo Requirements Calculator](/toolkit/odoo-requirements-calculator/)** - Calculate exact CPU, RAM, storage needs
- **[Hosting Decision Calculator](/toolkit/odoo-hosting-calculator/)** - Get personalized hosting recommendations

---

## 📖 Related Guides

These scripts accompany comprehensive guides:

- [Odoo Self-Hosting Guide](/odoo-self-hosting-guide/) - Complete self-hosting roadmap
- [Database Backup & Restore Guide](/odoo-database-backup-restore-guide/) - Master backup strategies
- [Database Migration Guide](/odoo-database-migration-guide/) - Zero-downtime migration
- [AWS Security Hardening Guide](/odoo-aws-security-hardening/) - Production AWS setup
- [Odoo Implementation Guide](/odoo-implementation-guide/) - Avoid $250K+ failures

---

## ⚠️ Important Notes

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

## 📜 License

All scripts are released under **MIT License** - free to use, modify, and distribute.

**Author:** Aria Shaw (Digital Plumber)
**Website:** [https://ariashaw.github.io](https://ariashaw.github.io)

---

*These scripts represent hundreds of hours of production debugging, incident response, and real-world deployment experience. Use them to build robust, independent Odoo systems.*
