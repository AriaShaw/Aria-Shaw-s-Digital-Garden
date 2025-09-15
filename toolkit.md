---
layout: default
title: Toolkit | Open-Source Business Automation Scripts & Tools
permalink: /toolkit/
---

Welcome to the Toolkit, a curated library of open-source scripts and tools I've built to accompany the guides in my Digital Garden. Each tool is designed to be a robust, production-ready solution for a specific business automation problem.

<div class="toolkit-accordion">
    <button class="accordion-header" aria-expanded="false">
        <h2 class="accordion-title">
            <span class="accordion-icon">🔄</span>
            Odoo Database Migration Scripts
        </h2>
        <span class="accordion-chevron">▼</span>
    </button>
    <div class="accordion-content">
        <div class="accordion-meta">
            📖 **From the complete guide:** <a href="/odoo-database-migration-guide/">OOdoo Database Migration 2025: Zero-Downtime Made Easy</a>
        </div>
        <div class="toolkit-grid">
            <h3>Pre-Migration Assessment & Planning</h3>
            <ul>
                <li>**🛠️ [Odoo Migration Risk Assessor](/scripts/migration_assessment.sh)** - *Analyze database size, module complexity, and PostgreSQL version to identify potential migration risks before you start.*</li>
                <li>**🔧 [Environment Compatibility Checker](/scripts/compatibility_check.py)** - *Verify Python versions, system dependencies, and disk space on both source and target servers.*</li>
                <li>**📊 [Server Specifications Calculator](/scripts/calculate_server_specs.py)** - *Calculate optimal server requirements based on your Odoo workload and user count.*</li>
                <li>**🧹 [Data Cleanup Toolkit](/scripts/data_cleanup.py)** - *Identify and fix duplicate records, orphaned entries, and data integrity issues before migration.*</li>
            </ul>

            <h3>Backup & Recovery Solutions</h3>
            <ul>
                <li>**💾 [PostgreSQL Database Backup](/scripts/backup_database.sh)** - *Enterprise-grade database backup with validation, compression, and integrity checking.*</li>
                <li>**📁 [Filestore Secure Backup](/scripts/backup_filestore.sh)** - *Complete filestore backup with compression and verification for all Odoo attachments.*</li>
                <li>**⚙️ [Configuration Backup System](/scripts/backup_configuration.sh)** - *Backup Odoo configs, custom modules, and system settings for complete environment restoration.*</li>
            </ul>

            <h3>Server Setup & Optimization</h3>
            <ul>
                <li>**🐧 [Ubuntu Odoo Optimization](/scripts/setup_ubuntu_odoo.sh)** - *Complete Ubuntu 22.04 LTS setup optimized specifically for Odoo production workloads.*</li>
                <li>**🐘 [PostgreSQL Production Tuning](/scripts/tune_postgresql_odoo.sh)** - *Advanced PostgreSQL configuration tuning for maximum Odoo performance.*</li>
            </ul>

            <h3>Migration Execution & Validation</h3>
            <ul>
                <li>**🏗️ [Staging Environment Validator](/scripts/staging_validation.sh)** - *Seven-layer validation system to test migration success before touching production.*</li>
                <li>**🚀 [Production Migration Executor](/scripts/production_migration.sh)** - *Zero-downtime migration execution with automatic rollback capabilities.*</li>
                <li>**⚡ [Performance Validation Suite](/scripts/performance_validation.sh)** - *24-hour performance monitoring to ensure migrated system outperforms the original.*</li>
                <li>**✅ [Final Verification Checklist](/scripts/final_verification.sh)** - *Comprehensive verification to confirm all aspects of migration success.*</li>
            </ul>

            <h3>Ongoing Maintenance & Monitoring</h3>
            <ul>
                <li>**🔄 [Weekly Maintenance Automation](/scripts/weekly_maintenance.sh)** - *Automated weekly database maintenance, log rotation, and performance optimization.*</li>
                <li>**📈 [Monthly Health Check](/scripts/monthly_health_check.sh)** - *Comprehensive monthly system review with capacity planning and security audit.*</li>
            </ul>

            <h3>Advanced Troubleshooting & Recovery</h3>
            <ul>
                <li>**🔌 [PostgreSQL Compatibility Check](/scripts/pg_compatibility_check.sh)** - *Deep compatibility analysis between PostgreSQL versions to prevent migration disasters.*</li>
                <li>**🛡️ [Safe OpenUpgrade Wrapper](/scripts/safe_openupgrade.sh)** - *OpenUpgrade execution with multiple safety nets and automatic rollback capabilities.*</li>
                <li>**🧩 [Module Compatibility Scanner](/scripts/module_compatibility_scan.py)** - *Analyze custom modules for API compatibility across Odoo versions.*</li>
                <li>**🔗 [Dependency Analyzer](/scripts/dependency_analyzer.py)** - *Resolve complex module dependency conflicts and installation order.*</li>
                <li>**⚙️ [Dependency Resolution Engine](/scripts/resolve_dependencies.py)** - *Intelligent module dependency resolver with topological sorting and circular dependency detection.*</li>
                <li>**🚨 [Database Corruption Detector](/scripts/db_corruption_detector.sh)** - *Advanced corruption detection and recovery procedures for damaged databases.*</li>
            </ul>

            <h3>Integration & Communication Testing</h3>
            <ul>
                <li>**🌐 [API Diagnostics Tool](/scripts/api_diagnostics.py)** - *Comprehensive API connection testing with DNS, SSL, and HTTP response validation.*</li>
                <li>**📧 [SMTP Configuration Tester](/scripts/test_smtp.py)** - *Complete email system testing including authentication and message delivery verification.*</li>
            </ul>

            <h3>Emergency Recovery Procedures</h3>
            <ul>
                <li>**🔄 [Intelligent Rollback System](/scripts/intelligent_rollback.sh)** - *Advanced rollback with selective data preservation and automated safety checks.*</li>
            </ul>

            <h3>Security & Compliance Tools</h3>
            <ul>
                <li>**🛡️ [GDPR Data Retention Policy](/scripts/gdpr_data_retention.py)** - *Automated GDPR-compliant data retention and anonymization for migration environments.*</li>
                <li>**👀 [GDPR Compliance Monitor](/scripts/gdpr_monitoring.sh)** - *Real-time monitoring for data breaches and unauthorized access during migration.*</li>
                <li>**📊 [Migration Audit Report Generator](/scripts/generate_audit_report.py)** - *Comprehensive audit trail reporting for compliance and security reviews.*</li>
                <li>**🔐 [Migration Access Control System](/scripts/migration_access_control.sh)** - *Time-limited access control with automated expiration and full audit trails.*</li>
                <li>**🕵️ [Sensitive Data Scanner & Masker](/scripts/sensitive_data_scanner.py)** - *Pattern-based sensitive data discovery with automated masking for non-production environments.*</li>
                <li>**🔒 [GDPR Consent Migration Model](/scripts/gdpr_consent_migration.py)** - *Track and validate GDPR consent during migration, ensuring compliance with data protection regulations.*</li>
                <li>**📋 [Migration Audit Trail System](/scripts/migration_audit_trail.py)** - *Comprehensive audit logging for migration activities with compliance tracking and data sensitivity classification.*</li>
            </ul>

            <h3>Business Process Automation Scripts</h3>
            <ul>
                <li>**💼 [Inter-company Transaction Manager](/scripts/intercompany_transaction_manager.py)** - *Automatically create offsetting journal entries for inter-company transactions in multi-company Odoo setups.*</li>
                <li>**⚖️ [Legal Matter Model](/scripts/legal_matter_model.py)** - *Custom Odoo model for legal services companies requiring conflict checking and specialized billing features.*</li>
                <li>**🚨 [Emergency Order Import System](/scripts/emergency_order_import.py)** - *Import orders that were written down during system outages, converting CSV data back into Odoo sales orders for business continuity.*</li>
            </ul>
        </div>
    </div>
</div>

<div class="toolkit-accordion">
    <button class="accordion-header" aria-expanded="false">
        <h2 class="accordion-title">
            <span class="accordion-icon">🏠</span>
            Odoo Self-Hosting Scripts
        </h2>
        <span class="accordion-chevron">▼</span>
    </button>
    <div class="accordion-content">
        <div class="accordion-meta">
            📖 **From the complete guide:** <a href="/odoo-self-hosting-guide/">Avoid $48,000 Loss: Odoo Self-Hosting Guide for 2025</a>
        </div>
        <div class="toolkit-grid">
            <h3>Backup & Recovery Solutions</h3>
            <ul>
                <li>**💾 [Basic Odoo Backup Script](/scripts/backup_odoo.sh)** - *Simple, reliable daily backup solution with automatic cleanup and compression.*</li>
                <li>**☁️ [Enhanced Cloud Backup](/scripts/enhanced_backup_odoo.sh)** - *Advanced backup with Backblaze B2 cloud sync and failure alerting.*</li>
            </ul>

            <h3>Database Maintenance & Optimization</h3>
            <ul>
                <li>**🔧 [PostgreSQL Maintenance](/scripts/db_maintenance.sh)** - *Weekly database optimization with VACUUM, ANALYZE, and REINDEX operations.*</li>
            </ul>

            <h3>Monitoring & Health Checks</h3>
            <ul>
                <li>**📊 [System Health Check](/scripts/system_health_check.sh)** - *One-line system status overview for disk, memory, and service status.*</li>
                <li>**👀 [Basic Odoo Monitor](/scripts/monitor_odoo.sh)** - *Simple monitoring with email alerts for downtime and disk space issues.*</li>
                <li>**🔍 [Advanced System Monitor](/scripts/advanced_monitor_odoo.sh)** - *Comprehensive monitoring with detailed logging and database connection tracking.*</li>
            </ul>
        </div>
    </div>
</div>

<div class="toolkit-accordion">
    <button class="accordion-header" aria-expanded="false">
        <h2 class="accordion-title">
            <span class="accordion-icon">⚙️</span>
            Odoo System Requirements & Deployment Scripts
        </h2>
        <span class="accordion-chevron">▼</span>
    </button>
    <div class="accordion-content">
        <div class="accordion-meta">
            📖 **From the complete guide:** <a href="/odoo-system-requirements-deployment-guide/">Odoo Minimum Requirements 2025: Complete Deployment Guide</a>
        </div>
        <div class="toolkit-grid">
            <h3>System Assessment & Compatibility</h3>
            <ul>
                <li>**🔍 [Odoo System Compatibility Checker](/scripts/odoo_system_checker.sh)** - *Comprehensive system requirements validation with color-coded output and detailed recommendations for production deployments.*</li>
            </ul>

            <h3>Advanced Deployment & Architecture</h3>
            <ul>
                <li>**📦 [Separated Architecture Backup Strategy](/scripts/separated_backup_strategy.sh)** - *Enterprise backup solution for separated Odoo deployments with automated database, filestore, and configuration backup.*</li>
                <li>**🌊 [DigitalOcean Odoo Production Setup](/scripts/digitalocean_odoo_setup.sh)** - *Complete DigitalOcean droplet setup with PostgreSQL, nginx, SSL, and production-grade configurations.*</li>
            </ul>

            <h3>Monitoring & Health Checks</h3>
            <ul>
                <li>**💗 [Advanced Odoo Health Monitor](/scripts/odoo_health_monitor.sh)** - *Real-time monitoring with CPU, memory, disk alerts and intelligent cooldown system for production environments.*</li>
            </ul>

            <h3>Troubleshooting & Diagnostics</h3>
            <ul>
                <li>**🔧 [Odoo Dependency Resolver](/scripts/odoo_dependency_fixer.sh)** - *Automated Python dependency resolution and conflict fixing for Odoo installations and upgrades.*</li>
                <li>**🔌 [Odoo Port & Network Diagnostics](/scripts/odoo_port_diagnostics.sh)** - *Comprehensive network troubleshooting for Odoo connectivity issues, including port scanning and service validation.*</li>
            </ul>

            <h3>Emergency Recovery</h3>
            <ul>
                <li>**🚨 [Odoo Emergency Recovery System](/scripts/odoo_emergency_recovery.sh)** - *Complete disaster recovery toolkit with automated database restoration, service recovery, and system validation.*</li>
            </ul>
        </div>
    </div>
</div>

---

**📝 Battle-Tested Reliability:** All scripts include comprehensive error handling, logging, and are designed to fail safely. They're the same tools I use in professional migrations and are battle-tested across hundreds of production environments.