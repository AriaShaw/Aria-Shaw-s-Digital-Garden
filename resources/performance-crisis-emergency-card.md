# ⚡ SEVERE PERFORMANCE DEGRADATION
=================================

## IMMEDIATE DIAGNOSTICS:

### 1. CHECK system resources
```bash
top
htop
iostat -x 1
```

### 2. IDENTIFY database bottlenecks
```bash
sudo -u postgres psql -c "SELECT query, calls, total_time FROM pg_stat_statements ORDER BY total_time DESC LIMIT 5;"
```

### 3. CHECK for blocking queries
```bash
sudo -u postgres psql -c "SELECT pid, state, query FROM pg_stat_activity WHERE state != 'idle';"
```

### 4. MONITOR disk I/O
```bash
iotop -o
```

## IMMEDIATE ACTIONS:

### 1. KILL problematic queries (if identified)
```bash
sudo -u postgres psql -c "SELECT pg_terminate_backend([PID]);"
```

### 2. RESTART application (if safe)
```bash
sudo systemctl restart odoo
```

### 3. INCREASE resource limits (if needed)
```bash
# Edit /etc/postgresql/14/main/postgresql.conf
# Increase shared_buffers, work_mem as appropriate
```

## ⚠️ ESCALATION
If no improvement in 15 minutes, implement rollback procedures

---

**Emergency Contact Information:**
- Primary Technical: _______________
- Secondary Technical: _______________
- Database Administrator: _______________
- System Administrator: _______________

**Critical Thresholds:**
- CPU Usage: >90% for 5+ minutes
- Memory Usage: >95%
- Disk I/O: >80% utilization
- Response Time: >30 seconds