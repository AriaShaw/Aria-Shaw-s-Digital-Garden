# 🚨 DATABASE CORRUPTION DETECTED
================================

## IMMEDIATE ACTIONS:

### 1. STOP all application services
```bash
sudo systemctl stop odoo nginx
```

### 2. ASSESS damage extent
```bash
sudo -u postgres pg_dump --schema-only production_db > schema_check.sql
```

### 3. RESTORE from last known good backup
```bash
sudo -u postgres dropdb production_db
sudo -u postgres pg_restore -C -d postgres backup_file.backup
```

### 4. VERIFY data integrity
```bash
sudo -u postgres psql -d production_db -c "SELECT COUNT(*) FROM res_users;"
```

### 5. RESTART services only after verification
```bash
sudo systemctl start postgresql odoo nginx
```

## ⚠️ CRITICAL
Document all actions taken for post-incident analysis

---

**Emergency Contact Information:**
- Primary Technical: _______________
- Secondary Technical: _______________
- Business Owner: _______________
- Executive Sponsor: _______________

**Backup Locations:**
- Primary: _______________
- Secondary: _______________
- Cloud: _______________