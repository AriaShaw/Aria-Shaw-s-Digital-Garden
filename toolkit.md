---
layout: default
title: Toolkit | Open-Source Business Automation Scripts & Tools
permalink: /toolkit/
---

Welcome to the Toolkit, a curated library of open-source scripts and tools I've built to accompany the guides in my Digital Garden. Each tool is designed to be a robust, production-ready solution for a specific business automation problem.

---

## Odoo Migration Scripts

A collection of scripts designed for the "Odoo Database Migration Nightmare" guide.

### Pre-Migration Assessment & Planning
* **🛠️ [Odoo Migration Risk Assessor](/scripts/migration_assessment.sh)** - *Analyze database size, module complexity, and PostgreSQL version to identify potential migration risks before you start.*
* **🔧 [Environment Compatibility Checker](/scripts/compatibility_check.py)** - *Verify Python versions, system dependencies, and disk space on both source and target servers.*
* **📊 [Server Specifications Calculator](/scripts/calculate_server_specs.py)** - *Calculate optimal server requirements based on your Odoo workload and user count.*
* **🧹 [Data Cleanup Toolkit](/scripts/data_cleanup.py)** - *Identify and fix duplicate records, orphaned entries, and data integrity issues before migration.*

### Backup & Recovery Solutions
* **💾 [PostgreSQL Database Backup](/scripts/backup_database.sh)** - *Enterprise-grade database backup with validation, compression, and integrity checking.*
* **📁 [Filestore Secure Backup](/scripts/backup_filestore.sh)** - *Complete filestore backup with compression and verification for all Odoo attachments.*
* **⚙️ [Configuration Backup System](/scripts/backup_configuration.sh)** - *Backup Odoo configs, custom modules, and system settings for complete environment restoration.*

### Server Setup & Optimization
* **🐧 [Ubuntu Odoo Optimization](/scripts/setup_ubuntu_odoo.sh)** - *Complete Ubuntu 22.04 LTS setup optimized specifically for Odoo production workloads.*
* **🐘 [PostgreSQL Production Tuning](/scripts/tune_postgresql_odoo.sh)** - *Advanced PostgreSQL configuration tuning for maximum Odoo performance.*

### Migration Execution & Validation
* **🏗️ [Staging Environment Validator](/scripts/staging_validation.sh)** - *Seven-layer validation system to test migration success before touching production.*
* **🚀 [Production Migration Executor](/scripts/production_migration.sh)** - *Zero-downtime migration execution with automatic rollback capabilities.*
* **⚡ [Performance Validation Suite](/scripts/performance_validation.sh)** - *24-hour performance monitoring to ensure migrated system outperforms the original.*
* **✅ [Final Verification Checklist](/scripts/final_verification.sh)** - *Comprehensive verification to confirm all aspects of migration success.*

### Ongoing Maintenance & Monitoring
* **🔄 [Weekly Maintenance Automation](/scripts/weekly_maintenance.sh)** - *Automated weekly database maintenance, log rotation, and performance optimization.*
* **📈 [Monthly Health Check](/scripts/monthly_health_check.sh)** - *Comprehensive monthly system review with capacity planning and security audit.*
* **🩺 [Performance Diagnosis Tool](/scripts/performance_diagnosis.sh)** - *Quick performance issue identification and optimization recommendations.*
* **🔍 [Data Integrity Checker](/scripts/data_integrity_check.sh)** - *Detect and report database corruption or consistency issues.*

### Advanced Troubleshooting & Recovery
* **🔌 [PostgreSQL Compatibility Check](/scripts/pg_compatibility_check.sh)** - *Deep compatibility analysis between PostgreSQL versions to prevent migration disasters.*
* **🛡️ [Safe OpenUpgrade Wrapper](/scripts/safe_openupgrade.sh)** - *OpenUpgrade execution with multiple safety nets and automatic rollback capabilities.*
* **🧩 [Module Compatibility Scanner](/scripts/module_compatibility_scan.py)** - *Analyze custom modules for API compatibility across Odoo versions.*
* **🔗 [Dependency Analyzer](/scripts/dependency_analyzer.py)** - *Resolve complex module dependency conflicts and installation order.*
* **🚨 [Database Corruption Detector](/scripts/db_corruption_detector.sh)** - *Advanced corruption detection and recovery procedures for damaged databases.*

All scripts include comprehensive error handling, logging, and are designed to fail safely. They're the same tools I use in professional migrations and are battle-tested across hundreds of production environments.

---

## Odoo Self-Hosting Scripts

A collection of scripts from the "Bulletproof Self-Hosting Guide" for Odoo 2025.

### Backup & Recovery Solutions
* **💾 [Basic Odoo Backup Script](/scripts/backup_odoo.sh)** - *Simple, reliable daily backup solution with automatic cleanup and compression.*
* **☁️ [Enhanced Cloud Backup](/scripts/enhanced_backup_odoo.sh)** - *Advanced backup with Backblaze B2 cloud sync and failure alerting.*

### Database Maintenance & Optimization
* **🔧 [PostgreSQL Maintenance](/scripts/db_maintenance.sh)** - *Weekly database optimization with VACUUM, ANALYZE, and REINDEX operations.*

### Monitoring & Health Checks
* **📊 [System Health Check](/scripts/system_health_check.sh)** - *One-line system status overview for disk, memory, and service status.*
* **👀 [Basic Odoo Monitor](/scripts/monitor_odoo.sh)** - *Simple monitoring with email alerts for downtime and disk space issues.*
* **🔍 [Advanced System Monitor](/scripts/advanced_monitor_odoo.sh)** - *Comprehensive monitoring with detailed logging and database connection tracking.*

These scripts are designed for production environments and include proper error handling, logging, and security considerations. They complement the comprehensive self-hosting guide and help maintain a bulletproof Odoo installation.