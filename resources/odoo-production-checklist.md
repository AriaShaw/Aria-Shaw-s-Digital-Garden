# Odoo Production Environment Health Checklist
*The Complete 47-Point Deployment Verification Guide*

---

**Document Information:**
- **Version:** 2.1
- **Last Updated:** September 2025
- **Created by:** Aria Shaw
- **Purpose:** Pre-production verification for Odoo deployments

---

## Pre-Checklist Instructions

**How to Use This Checklist:**
1. ✅ Check each completed item
2. ❌ Mark any failed items for immediate attention
3. ⚠️ Note items that need monitoring or follow-up
4. **Do NOT deploy to production until all items are ✅**

**Severity Levels:**
- 🔴 **Critical:** Must be completed - deployment blocking
- 🟡 **Important:** Should be completed - affects performance/security
- 🟢 **Recommended:** Nice to have - improves operational efficiency

---

## Security Hardening (12 Checkpoints)

### Core Security Configuration
☐ **1.** 🔴 Admin password changed from default and stored securely
   - [ ] Password is 32+ characters with mixed case, numbers, symbols
   - [ ] Password stored in team password manager
   - [ ] Default admin password documented nowhere in plain text

☐ **2.** 🔴 Database list disabled (`list_db = False`)
   - [ ] Verified `list_db = False` in `/etc/odoo/odoo.conf`
   - [ ] Tested that `/web/database/manager` returns access denied
   - [ ] No database enumeration possible via web interface

☐ **3.** 🔴 Firewall configured to block direct port 8069 access
   - [ ] UFW or equivalent firewall active and configured
   - [ ] Port 8069 blocked from external access
   - [ ] Only HTTP (80) and HTTPS (443) accessible externally
   - [ ] SSH access restricted to management IPs only

### Network Security
☐ **4.** 🔴 Reverse proxy (nginx/Apache) properly configured
   - [ ] Odoo running behind reverse proxy
   - [ ] `proxy_mode = True` set in Odoo configuration
   - [ ] Proper X-Forwarded headers configured
   - [ ] SSL termination handled by proxy

☐ **5.** 🔴 SSL certificate installed and auto-renewal configured
   - [ ] Valid SSL certificate installed (Let's Encrypt or commercial)
   - [ ] Certificate auto-renewal configured and tested
   - [ ] HTTP redirects to HTTPS enforced
   - [ ] SSL Labs test score A or A+

☐ **6.** 🟡 Network interface bindings secured
   - [ ] `xmlrpc_interface = 127.0.0.1` (localhost only)
   - [ ] `netrpc_interface = 127.0.0.1` (localhost only)
   - [ ] No external direct access to Odoo service

### Database Security
☐ **7.** 🔴 PostgreSQL security hardening completed
   - [ ] PostgreSQL user created with minimal required permissions
   - [ ] Database password is strong (32+ characters)
   - [ ] `listen_addresses = 'localhost'` (unless separated architecture)
   - [ ] PostgreSQL version 12+ installed

☐ **8.** 🔴 Database authentication configured
   - [ ] `password_encryption = scram-sha-256` enabled
   - [ ] Connection logging enabled (`log_connections = on`)
   - [ ] Failed authentication attempts logged
   - [ ] No trust authentication methods for production databases

### System Security
☐ **9.** 🔴 Dedicated odoo user configured (never run as root)
   - [ ] System user `odoo` created with restricted permissions
   - [ ] Odoo service runs as non-root user
   - [ ] Home directory `/opt/odoo` properly secured
   - [ ] No sudo access for odoo user

☐ **10.** 🟡 File permissions properly configured
   - [ ] Configuration file `/etc/odoo/odoo.conf` owned by root:odoo (640)
   - [ ] Log directory `/var/log/odoo` owned by odoo:odoo (750)
   - [ ] Odoo installation files have appropriate permissions
   - [ ] No world-readable sensitive files

☐ **11.** 🟡 System updates and security patches current
   - [ ] Operating system fully updated
   - [ ] Security patches applied and documented
   - [ ] Update schedule established (monthly minimum)
   - [ ] Critical security notifications configured

☐ **12.** 🟢 Additional security measures implemented
   - [ ] Fail2ban configured for SSH and web services
   - [ ] Intrusion detection system configured (optional)
   - [ ] Security monitoring alerts configured
   - [ ] Regular security audit schedule established

---

## Performance Optimization (14 Checkpoints)

### Worker Process Configuration
☐ **13.** 🔴 Worker processes calculated and configured correctly
   - [ ] Worker count based on CPU cores: `(cores × 2) + 1`
   - [ ] Workers setting matches available RAM capacity
   - [ ] `max_cron_threads = 2` configured appropriately
   - [ ] Worker recycling limits configured

☐ **14.** 🔴 Memory limits properly configured
   - [ ] `limit_memory_hard = 2684354560` (2.5GB) configured
   - [ ] `limit_memory_soft = 2147483648` (2GB) configured
   - [ ] `limit_request = 8192` configured
   - [ ] Memory limits tested under load

☐ **15.** 🔴 Request timeout limits configured
   - [ ] `limit_time_cpu = 600` (10 minutes) configured
   - [ ] `limit_time_real = 1200` (20 minutes) configured
   - [ ] Timeouts appropriate for business processes
   - [ ] Long-running operations identified and optimized

### Database Performance
☐ **16.** 🔴 PostgreSQL performance tuning completed
   - [ ] `shared_buffers` set to 25% of total RAM
   - [ ] `effective_cache_size` set to 75% of total RAM
   - [ ] `work_mem` configured appropriately (10-20MB)
   - [ ] `maintenance_work_mem` set (512MB-1GB)

☐ **17.** 🔴 Database connections properly managed
   - [ ] `max_connections` set appropriately (100-200)
   - [ ] `db_maxconn` configured in Odoo (64 recommended)
   - [ ] Connection pooling tested under load
   - [ ] No connection exhaustion during peak usage

☐ **18.** 🟡 Database maintenance scheduled
   - [ ] VACUUM ANALYZE scheduled (weekly minimum)
   - [ ] Database statistics updated regularly
   - [ ] Index maintenance scheduled
   - [ ] Slow query monitoring configured

### System Performance
☐ **19.** 🔴 Storage performance optimized
   - [ ] SSD storage used for database files
   - [ ] Sufficient disk space allocated (20% buffer minimum)
   - [ ] Disk I/O monitored and optimized
   - [ ] No storage bottlenecks identified

☐ **20.** 🟡 Caching configured
   - [ ] Redis or memcached configured (if applicable)
   - [ ] Database query caching enabled
   - [ ] Static file caching configured in reverse proxy
   - [ ] Cache hit rates monitored

☐ **21.** 🟡 Load testing completed
   - [ ] System tested with expected user load
   - [ ] Performance benchmarks established
   - [ ] Bottlenecks identified and addressed
   - [ ] Capacity planning documentation created

### Resource Monitoring
☐ **22.** 🔴 System resource baselines established
   - [ ] CPU usage baseline documented (< 70% average)
   - [ ] Memory usage baseline documented (< 80% average)
   - [ ] Disk I/O baseline documented
   - [ ] Network usage baseline documented

☐ **23.** 🟡 Performance monitoring configured
   - [ ] Resource usage tracking automated
   - [ ] Performance degradation alerts configured
   - [ ] Trend analysis tools configured
   - [ ] Performance reports scheduled

☐ **24.** 🟡 Capacity planning implemented
   - [ ] Growth projections documented
   - [ ] Scaling triggers identified
   - [ ] Resource upgrade path planned
   - [ ] Capacity alerts configured

☐ **25.** 🟢 Performance optimization ongoing
   - [ ] Regular performance reviews scheduled
   - [ ] Optimization opportunities identified
   - [ ] Performance tuning documentation maintained
   - [ ] Best practices documentation updated

☐ **26.** 🟢 Advanced performance features
   - [ ] CDN configured for static assets (if applicable)
   - [ ] Image optimization implemented
   - [ ] Database partitioning considered (large deployments)
   - [ ] Advanced monitoring tools configured

---

## Backup and Recovery (8 Checkpoints)

### Backup Configuration
☐ **27.** 🔴 Automated daily backups configured
   - [ ] Database backup script configured and tested
   - [ ] Filestore backup script configured and tested
   - [ ] Backup schedule automated (daily minimum)
   - [ ] Backup completion notifications configured

☐ **28.** 🔴 Backup integrity verification
   - [ ] Backup verification script implemented
   - [ ] Regular backup restore testing scheduled
   - [ ] Backup corruption detection configured
   - [ ] Failed backup alerts configured

☐ **29.** 🔴 Backup retention policy implemented
   - [ ] Daily backups retained (minimum 7 days)
   - [ ] Weekly backups retained (minimum 4 weeks)
   - [ ] Monthly backups retained (minimum 12 months)
   - [ ] Automated cleanup script configured

☐ **30.** 🔴 Offsite backup storage configured
   - [ ] Backups stored in separate location/cloud
   - [ ] Backup transfer encryption configured
   - [ ] Offsite backup access tested
   - [ ] Geographic separation ensured

### Recovery Procedures
☐ **31.** 🔴 Disaster recovery plan documented
   - [ ] Complete recovery procedures documented
   - [ ] Recovery time objectives (RTO) defined
   - [ ] Recovery point objectives (RPO) defined
   - [ ] Emergency contact list maintained

☐ **32.** 🔴 Recovery testing completed
   - [ ] Full system restore tested within last 3 months
   - [ ] Partial recovery procedures tested
   - [ ] Recovery time measured and documented
   - [ ] Recovery procedures validated by team

☐ **33.** 🟡 Backup monitoring and alerting
   - [ ] Backup success/failure monitoring configured
   - [ ] Backup size trending monitored
   - [ ] Storage capacity alerts configured
   - [ ] Backup performance monitoring enabled

☐ **34.** 🟢 Advanced backup features
   - [ ] Point-in-time recovery capability configured
   - [ ] Incremental backup strategy implemented
   - [ ] Backup deduplication enabled (if available)
   - [ ] Backup encryption configured

---

## Monitoring and Alerting (7 Checkpoints)

### System Monitoring
☐ **35.** 🔴 Core system monitoring configured
   - [ ] CPU usage monitoring (alert > 85%)
   - [ ] Memory usage monitoring (alert > 80%)
   - [ ] Disk space monitoring (alert < 15% free)
   - [ ] Disk I/O monitoring configured

☐ **36.** 🔴 Odoo application monitoring configured
   - [ ] Odoo service status monitoring
   - [ ] Worker process monitoring
   - [ ] Response time monitoring (alert > 5 seconds)
   - [ ] Error rate monitoring configured

☐ **37.** 🔴 Database monitoring configured
   - [ ] PostgreSQL service monitoring
   - [ ] Database connection monitoring
   - [ ] Query performance monitoring
   - [ ] Database size growth monitoring

### Alerting System
☐ **38.** 🔴 Critical alert configuration
   - [ ] System down alerts configured (immediate)
   - [ ] Service failure alerts configured (immediate)
   - [ ] Resource exhaustion alerts configured (5 minutes)
   - [ ] Security breach alerts configured (immediate)

☐ **39.** 🟡 Alert delivery methods configured
   - [ ] Email alerts configured and tested
   - [ ] SMS/phone alerts configured for critical issues
   - [ ] Slack/Teams integration configured (if applicable)
   - [ ] On-call rotation configured (if applicable)

☐ **40.** 🟡 Log monitoring configured
   - [ ] Application logs monitored for errors
   - [ ] System logs monitored for security events
   - [ ] Log rotation configured
   - [ ] Log retention policy implemented

☐ **41.** 🟢 Advanced monitoring features
   - [ ] Dashboard created for key metrics
   - [ ] Trending analysis configured
   - [ ] Predictive alerting configured
   - [ ] Business metrics monitoring (uptime, users)

---

## Documentation and Handover (6 Checkpoints)

### Technical Documentation
☐ **42.** 🔴 System architecture documented
   - [ ] Server specifications documented
   - [ ] Network topology documented
   - [ ] Service dependencies mapped
   - [ ] Configuration files inventoried

☐ **43.** 🔴 Operational procedures documented
   - [ ] Startup/shutdown procedures documented
   - [ ] Backup/restore procedures documented
   - [ ] Emergency response procedures documented
   - [ ] Maintenance procedures documented

☐ **44.** 🟡 Access and credential management
   - [ ] All system accounts documented
   - [ ] Access control list maintained
   - [ ] Password policy documented
   - [ ] Key management procedures documented

### Knowledge Transfer
☐ **45.** 🔴 Team training completed
   - [ ] Primary administrator trained on all procedures
   - [ ] Backup administrator identified and trained
   - [ ] Team has access to all documentation
   - [ ] Escalation procedures communicated

☐ **46.** 🟡 Maintenance schedule established
   - [ ] Regular maintenance windows scheduled
   - [ ] Update and patch schedule defined
   - [ ] Performance review schedule established
   - [ ] Security audit schedule established

☐ **47.** 🟢 Continuous improvement process
   - [ ] Incident review process established
   - [ ] Documentation update process defined
   - [ ] Performance improvement process active
   - [ ] Team feedback mechanism established

---

## Deployment Sign-off

**Pre-Production Verification:**
- [ ] All 47 checkpoints completed
- [ ] Critical (🔴) items: ___/29 completed
- [ ] Important (🟡) items: ___/13 completed
- [ ] Recommended (🟢) items: ___/5 completed

**Sign-off Authorization:**

**Technical Lead:** _________________________ Date: _____________

**System Administrator:** _________________________ Date: _____________

**Project Manager:** _________________________ Date: _____________

---

## Quick Reference: Critical Commands

**Service Management:**
```bash
# Check Odoo service status
sudo systemctl status odoo

# Restart Odoo service
sudo systemctl restart odoo

# Check PostgreSQL status
sudo systemctl status postgresql
```

**Log Monitoring:**
```bash
# Check Odoo logs
sudo tail -f /var/log/odoo/odoo.log

# Check system resources
htop

# Check disk space
df -h
```

**Emergency Contacts:**
- **Primary Administrator:** [Name] - [Phone] - [Email]
- **Backup Administrator:** [Name] - [Phone] - [Email]
- **Hosting Provider Support:** [Contact Info]
- **Odoo Partner/Consultant:** [Contact Info]

---

**Document Control:**
- **Next Review Date:** [6 months from deployment]
- **Version History:** Available in project documentation
- **Distribution:** Project team, system administrators, management

*This checklist is based on analysis of 50+ production Odoo deployments and industry best practices. Customize as needed for your specific environment.*