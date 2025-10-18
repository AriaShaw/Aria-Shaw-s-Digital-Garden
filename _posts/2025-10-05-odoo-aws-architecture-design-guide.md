---
layout: post
title: "Odoo AWS Architecture Guide: 3 Tiers from $100 to $350/mo"
author: "Aria Shaw"
date: 2025-10-05
description: "Design production Odoo architecture on AWS. Compare single-server, separated, and multi-AZ setups with cost breakdowns, sizing calculators, and decision frameworks."
---

**You deploy Odoo on AWS without a clear architecture plan. Six months later, you discover your RDS instance costs 4x more than necessary, your filestore balloons to $200/month in EBS charges, and you can't scale because you chose the wrong tier.**

This guide prevents that. You'll design the correct architecture before deployment, choose the right tier for your workload, and calculate exact monthly costs.

**Who this serves:**
- CTOs evaluating AWS deployment options
- Solutions Architects designing Odoo infrastructure
- DevOps Engineers planning scalable systems

**Prerequisites:**
- Understanding of AWS fundamentals (EC2, RDS, S3)
- Odoo deployment experience (on-premise or cloud)
- Budget authority or technical decision-making role

**Time investment:** 45 minutes to select architecture, 2 hours to validate with cost calculator.

---

## Three Architecture Tiers Explained

AWS provides three distinct paths for Odoo deployment. Each tier balances cost, performance, and operational complexity.

### Quick Comparison

**Not sure which tier you need?** Use our [Odoo Requirements Calculator](/toolkit/odoo-requirements-calculator/) to determine exact CPU, RAM, and storage specifications for your deployment—then match those specs to the appropriate AWS architecture tier below.

| Factor | Tier 1: Single | Tier 2: Separated | Tier 3: Multi-AZ |
|:---|:---|:---|:---|
| **Monthly Cost** | $100-120 | $180-220 | $350-420 |
| **Deployment Time** | 2 hours | 4 hours | 8 hours |
| **Scaling** | Manual resize | Vertical + horizontal | Auto-scaling |
| **Downtime Risk** | High (single point) | Medium (planned) | Low (<5 min/year) |
| **Backup Strategy** | EBS snapshots | RDS auto-backup | Multi-region replica |
| **Best For** | POC, <10 users | Production, <100 users | Mission-critical, 100+ users |

**Decision shortcut:**
- Revenue impact of 4-hour downtime <$5,000 → Tier 1
- Revenue impact $5,000-$50,000 → Tier 2
- Revenue impact >$50,000 → Tier 3

---

## Tier 1: Single-Server Architecture

**All components run on one EC2 instance.** Nginx proxies to Odoo, Odoo connects to local PostgreSQL. Filestore sits on EBS volume attached to instance.

### Architecture Diagram

![Tier 1 single-server architecture showing all components on one EC2 instance with EBS storage](/assets/images/architecture-tier1-single-server.webp){:loading="lazy"}

### Technical Specifications

**EC2 Instance:**
- Type: `t3.medium` (2 vCPU, 4GB RAM)
- OS: Ubuntu 22.04 LTS
- EBS: 100GB gp3 (3,000 IOPS baseline)
- Elastic IP: 1 static IP ($0 when attached)

**Software Stack:**
- Nginx 1.24+ (reverse proxy, SSL termination)
- Odoo 17 Community (5 workers)
- PostgreSQL 15 (shared_buffers: 1GB)

**Backup Strategy:**
- Daily EBS snapshots (7-day retention)
- Manual database dumps to S3 (weekly)
- Recovery Time Objective (RTO): 2-4 hours
- Recovery Point Objective (RPO): 24 hours

### Cost Breakdown

| Component | Specification | Monthly Cost |
|:---|:---|---:|
| EC2 t3.medium | On-Demand, us-east-1 | $30.37 |
| EBS gp3 100GB | 3,000 IOPS | $8.00 |
| EBS Snapshots | 100GB × 7 days | $3.50 |
| Elastic IP | 1 IP (attached) | $0.00 |
| Data Transfer | 500GB outbound | $45.00 |
| **Total** | | **$86.87** |

*Add 20% buffer for burstable CPU credits: **$104/month***

### When to Choose Tier 1

**Good fit:**
- Proof-of-concept deployments (3-6 month timeline)
- Internal tools with <10 concurrent users
- Development/staging environments
- Budget constraint: <$150/month total AWS spend

**Poor fit:**
- Customer-facing applications (single point of failure)
- Growing user base (scaling requires downtime)
- Compliance requirements (limited backup granularity)

### Scaling Limitations

**Vertical scaling:**
1. Stop EC2 instance (downtime: 5-10 minutes)
2. Resize to t3.large (4GB → 8GB RAM)
3. Restart instance
4. Reconfigure Odoo workers (adjust `/opt/odoo/odoo.conf`)

**Problem:** Database and application share resources. PostgreSQL memory pressure impacts Odoo response times. No way to scale independently.

**Maximum capacity:** ~20 concurrent users before performance degrades.

---

## Tier 2: Separated Architecture

**Application and database run on separate instances.** EC2 hosts Nginx + Odoo. RDS manages PostgreSQL. S3 stores filestore attachments.

### Architecture Diagram

![Tier 2 separated architecture with EC2 application server, RDS database, and S3 filestore](/assets/images/architecture-tier2-separated.webp){:loading="lazy"}

### Technical Specifications

**EC2 Application Server:**
- Type: `t3.large` (2 vCPU, 8GB RAM)
- Odoo workers: 5 (formula: 2×CPU + 1)
- OS: Ubuntu 22.04 LTS
- EBS: 50GB gp3 (application + logs only)

**RDS Database:**
- Engine: PostgreSQL 15 (latest: 15.12 as of Feb 2025)
- Instance: `db.t3.medium` (2 vCPU, 4GB RAM)
- Storage: 100GB gp3 (3,000 IOPS)
- Multi-AZ: Disabled (saves 50% cost, acceptable for this tier)
- Automated backups: 7-day retention, daily snapshots

**S3 Filestore:**
- Storage class: S3 Standard
- Lifecycle policy: Transition to IA after 90 days
- Versioning: Enabled (compliance requirement)
- Encryption: AES-256 server-side

**Backup Strategy:**
- RDS automated backups (daily + transaction logs)
- Point-in-time recovery (PITR): 5-minute granularity
- S3 versioning (90-day retention)
- RTO: 30 minutes
- RPO: 5 minutes

### Cost Breakdown

| Component | Specification | Monthly Cost |
|:---|:---|---:|
| EC2 t3.large | On-Demand | $60.74 |
| RDS db.t3.medium | Single-AZ | $48.18 |
| RDS Storage 100GB | gp3 | $11.50 |
| RDS Backup 100GB | 7-day retention | $9.50 |
| S3 Standard 50GB | Filestore | $1.15 |
| S3 Requests | 100K PUT, 500K GET | $0.50 |
| EBS gp3 50GB | Application tier | $4.00 |
| Data Transfer | 500GB outbound | $45.00 |
| **Total** | | **$180.57** |

*Conservative estimate: **$200/month** with buffer.*

### When to Choose Tier 2

**Good fit:**
- Production deployments with <100 concurrent users
- Growing companies (10-50 employees)
- Budget: $200-300/month acceptable
- Downtime tolerance: 1-2 hours/month for maintenance

**Advantages over Tier 1:**
- Independent scaling (resize database without touching application)
- Better backup granularity (5-minute PITR vs 24-hour snapshots)
- S3 filestore costs 3.5× cheaper than EBS ($1.15 vs $4.00 per 50GB)
- Database maintenance during low-traffic windows (read replicas possible)

**Limitations:**
- Single EC2 instance (application layer still has downtime risk)
- RDS single-AZ (database failover requires manual intervention)
- No load balancing (can't distribute traffic across multiple Odoo instances)

### Scaling Path

**Phase 1: Vertical scaling (0-50 users)**
- Resize EC2: t3.large → t3.xlarge (8GB → 16GB RAM)
- Resize RDS: db.t3.medium → db.t3.large (4GB → 8GB RAM)
- Adjust Odoo workers: 5 → 9 (2×4 CPU + 1)

**Phase 2: Read replicas (50-80 users)**
- Create RDS read replica ($48/month additional)
- Configure Odoo for read-write splitting (custom module required)
- Route reporting queries to replica

**Phase 3: Horizontal scaling → Migrate to Tier 3**
- Add Application Load Balancer
- Launch second EC2 instance
- Enable RDS Multi-AZ
- Total cost jumps to ~$350/month (Tier 3 territory)

---

## Tier 3: High-Availability Architecture

**Multi-AZ deployment with automatic failover.** Application Load Balancer distributes traffic across two EC2 instances in separate availability zones. RDS Multi-AZ provides sub-60-second database failover.

### Architecture Diagram

![Tier 3 high-availability architecture with load balancer, multi-AZ EC2 instances, RDS Multi-AZ, and cross-region S3 replication](/assets/images/architecture-tier3-high-availability.webp){:loading="lazy"}

### Technical Specifications

**Application Load Balancer:**
- Scheme: Internet-facing
- Listeners: HTTPS (443), HTTP (80 → 443 redirect)
- Health checks: `/web/health` endpoint (30-second interval)
- Sticky sessions: Enabled (cookie-based affinity)

**EC2 Application Servers (×2):**
- Type: `t3.xlarge` (4 vCPU, 16GB RAM)
- Odoo workers: 9 per instance (total capacity: 18 workers)
- Auto Scaling Group: Min 2, Max 4 instances
- Launch template: AMI with pre-baked Odoo 17 + dependencies

**RDS Multi-AZ:**
- Engine: PostgreSQL 15 (latest: 15.12 as of Feb 2025)
- Instance: `db.t3.large` (2 vCPU, 8GB RAM)
- Storage: 200GB gp3 (autoscaling enabled to 500GB)
- Multi-AZ: Enabled (synchronous replication to standby)
- Automated failover: <60 seconds (DNS endpoint remains constant)

**S3 Filestore:**
- Cross-Region Replication (CRR): Enabled to us-west-2
- Storage class: Intelligent-Tiering (auto-optimization)
- Versioning: Enabled with 90-day lifecycle

**Backup Strategy:**
- RDS automated backups: 30-day retention
- PITR: 5-minute granularity
- S3 CRR: Real-time replication to DR region
- RTO: <5 minutes (automatic failover)
- RPO: <1 minute (synchronous replication)

### Cost Breakdown

| Component | Specification | Monthly Cost |
|:---|:---|---:|
| ALB | 0.5 LCU average | $22.00 |
| EC2 t3.xlarge ×2 | On-Demand | $121.47 × 2 |
| RDS db.t3.large | Multi-AZ | $96.36 × 2 |
| RDS Storage 200GB | gp3 Multi-AZ | $23.00 × 2 |
| RDS Backup 200GB | 30-day retention | $19.00 |
| S3 Standard 100GB | Filestore + CRR | $2.30 + $2.30 |
| EBS gp3 50GB ×2 | Application tier | $4.00 × 2 |
| Data Transfer | 1TB outbound | $90.00 |
| **Total** | | **$427.43** |

*Budget with 10% buffer: **$470/month***

### When to Choose Tier 3

**Good fit:**
- Mission-critical production (revenue-generating applications)
- 100+ concurrent users
- Compliance requirements (SOC2, HIPAA, ISO 27001)
- SLA commitment: 99.9% uptime (8.76 hours downtime/year budget)

**Advantages over Tier 2:**
- Automatic failover (no manual intervention during AZ outages)
- Zero-downtime deployments (rolling updates across ASG)
- Horizontal scaling (add EC2 instances without code changes)
- Cross-region disaster recovery (S3 CRR to DR region)

**When NOT to choose Tier 3:**
- User count <50 (over-provisioned, waste 60% of capacity)
- Budget constraint <$400/month
- Team lacks AWS expertise (operational complexity 3× higher than Tier 2)

### Scaling Path

**Phase 1: Vertical scaling (100-200 users)**
- Resize EC2: t3.xlarge → t3.2xlarge (16GB → 32GB RAM)
- Resize RDS: db.t3.large → db.r6g.xlarge (8GB → 32GB RAM)
- Cost increase: +$180/month (~$600 total)

**Phase 2: Horizontal scaling (200-500 users)**
- Increase ASG max capacity: 4 → 6 instances
- Add RDS read replicas (2 replicas for reporting queries)
- Cost increase: +$350/month (~$800 total)

**Phase 3: Enterprise (500+ users)**
- Multi-region active-active deployment
- Aurora PostgreSQL (better horizontal scaling than RDS)
- CloudFront CDN for static assets
- Cost: $1,500-2,500/month

---

## Cost Comparison Matrix

### 3-Year Total Cost of Ownership

| Item | Tier 1 | Tier 2 | Tier 3 |
|:---|---:|---:|---:|
| **Monthly AWS** | $104 | $200 | $470 |
| **Year 1** | $1,248 | $2,400 | $5,640 |
| **Year 2** (10% growth) | $1,373 | $2,640 | $6,204 |
| **Year 3** (10% growth) | $1,510 | $2,904 | $6,824 |
| **3-Year Total** | $4,131 | $7,944 | $18,668 |
| **Downtime Cost** (assumed) | $12,000 | $3,000 | $500 |
| **True TCO** | **$16,131** | **$10,944** | **$19,168** |

**Downtime assumptions:**
- Tier 1: 4 outages/year × 4 hours × $750/hour revenue impact
- Tier 2: 2 outages/year × 2 hours × $750/hour
- Tier 3: 1 outage/3 years × 1 hour × $500/hour

**Conclusion:** Tier 2 offers best TCO for most production deployments when downtime costs are factored in.

### Break-Even Analysis

**When does Tier 2 justify its cost over Tier 1?**

Monthly delta: $200 - $104 = $96/month premium

If one 4-hour outage costs your business >$1,152 in lost revenue ($96 × 12 months), Tier 2 pays for itself in year one.

**Calculation:**
- $1,152 ÷ 4 hours = $288/hour revenue impact threshold
- $288/hour ÷ $40/hour average employee cost = 7 employees affected

**Decision rule:** If 7+ employees lose productivity during Odoo downtime, choose Tier 2.

**When does Tier 3 justify its cost over Tier 2?**

Monthly delta: $470 - $200 = $270/month premium

Annual premium: $3,240

If one 2-hour outage costs >$3,240, Tier 3 pays for itself.

**Calculation:**
- $3,240 ÷ 2 hours = $1,620/hour revenue impact threshold
- Example: E-commerce site processing $500K/month revenue
- $500K ÷ 30 days ÷ 24 hours = $694/hour average
- 2-hour outage = $1,388 lost revenue (below threshold)
- BUT: Peak hours (10am-2pm) process 40% of daily volume
- Peak outage cost: $2,777 (approaches threshold)

**Decision rule:** If peak-hour downtime costs exceed $1,500/hour, choose Tier 3.

---

## Architecture Decision Framework

### Step 1: Calculate Downtime Cost

**Formula:**
```
Hourly Impact = (Affected Employees × Avg Hourly Cost) + Direct Revenue Loss
```

**Example (50-person company, $100K/month revenue):**
- Employees affected: 30 (60% of staff uses Odoo daily)
- Avg hourly cost: $40/hour (burdened rate)
- Employee cost: 30 × $40 = $1,200/hour
- Revenue loss: $100K ÷ 30 days ÷ 24 hours = $139/hour
- **Total: $1,339/hour downtime cost**

### Step 2: Apply Decision Tree

![Architecture decision tree based on downtime cost calculation and production status](/assets/images/architecture-decision-tree.webp){:loading="lazy"}

### Step 3: Validate with Growth Projections

**User growth rates:**
- Startup (seed stage): 20-30% user growth/quarter
- SMB (established): 5-10% growth/quarter
- Enterprise: 2-5% growth/quarter

**Example (Tier 2 sizing validation):**

Current: 25 users, 10 concurrent sessions

Year 1 projection: 25 × 1.20^4 = 52 users
Year 2 projection: 52 × 1.15^4 = 91 users
Year 3 projection: 91 × 1.10^4 = 133 users

**Tier 2 capacity:** 100 concurrent users (t3.large + db.t3.medium)

**Verdict:** Tier 2 fits years 1-2, requires resize in year 3 (upgrade to t3.xlarge + db.t3.large). Total cost remains <$300/month. Better than starting with Tier 3 at $470/month.

### Step 4: Compliance Check

**Regulatory requirements forcing architecture choices:**

| Requirement | Minimum Tier | Why |
|:---|:---|:---|
| GDPR data residency | Tier 2 | RDS encryption at rest mandatory |
| SOC2 Type II | Tier 3 | Multi-AZ for availability control |
| HIPAA BAA | Tier 3 | AWS requires Multi-AZ for BAA |
| PCI-DSS | Tier 2 | Network segmentation (VPC) required |

**Gotcha:** HIPAA compliance forces Tier 3 even if user count is low. Budget accordingly.

---

## Component Deep-Dives

### EC2 Instance Sizing Calculator

**Formula:**
```
Required RAM = (Concurrent Users × 150MB) + PostgreSQL Buffer + OS Overhead
```

**Example (50 concurrent users):**
- Odoo per-user: 50 × 150MB = 7.5GB
- PostgreSQL: 25% of instance RAM (2GB on 8GB instance)
- OS overhead: 1GB
- **Total: 10.5GB → Choose t3.xlarge (16GB RAM)**

**Worker count formula:**
```
Workers = (2 × vCPU cores) + 1
```

**Validation:**
- Each worker consumes ~150MB RAM
- Total worker RAM: Workers × 150MB
- Must be <50% of instance RAM (leave headroom for cron jobs)

**Example (t3.large with 2 vCPU, 8GB RAM):**
- Workers: (2 × 2) + 1 = 5 workers
- Worker RAM: 5 × 150MB = 750MB (9% of 8GB ✓)
- PostgreSQL local (Tier 1): 2GB (25%)
- OS + cache: 2GB (25%)
- **Headroom: 3.25GB (40%) ✓**

### RDS vs Self-Managed PostgreSQL

| Factor | RDS | Self-Managed (EC2) |
|:---|:---|:---|
| **Setup Time** | 10 minutes (console clicks) | 2-3 hours (install, tune, secure) |
| **Automated Backups** | Included, PITR 5-min granularity | Manual (pg_dump cron job) |
| **Patching** | Automated, scheduled maintenance window | Manual (test, apply, restart) |
| **Monitoring** | CloudWatch metrics (free) | Install Prometheus + Grafana |
| **Failover** | Multi-AZ: automatic <60s | Manual (promote replica, update DNS) |
| **Cost (100GB)** | $48/month (db.t3.medium Single-AZ) | $30/month (t3.medium EC2 only) |
| **True Cost** | $48/month | $30 + 4 hours/month admin × $75/hour = **$330/month** |

**Conclusion:** RDS costs 60% more in infrastructure, but saves $280/month in admin labor. Use RDS unless you have dedicated DBA on staff.

### S3 vs EFS vs EBS for Filestore

**Odoo filestore requirements:**
- Random read/write access (user uploads attachments)
- Concurrent access (multiple Odoo workers)
- Growth rate: 10-50GB/year (document-heavy workflows)

| Storage | $/GB/month | IOPS | Latency | Multi-Instance Access | Best For |
|:---|---:|:---|:---|:---|:---|
| **EBS gp3** | $0.08 | 3,000-16,000 | <1ms | ❌ Single EC2 | Tier 1 only |
| **EFS** | $0.30 | Variable | 1-3ms | ✓ Shared across EC2 | Legacy (expensive) |
| **S3 Standard** | $0.023 | N/A | 10-50ms | ✓ Boto3 integration | Tier 2, 3 (recommended) |

**S3 cost advantage example (50GB filestore):**
- EBS: 50GB × $0.08 = $4.00/month
- EFS: 50GB × $0.30 = $15.00/month
- S3: 50GB × $0.023 = $1.15/month

**S3 savings: 71% vs EBS, 92% vs EFS.**

**S3 implementation requirements:**
1. Install `boto3` on EC2 instance
2. Configure Odoo `ir.attachment` storage: `s3://bucket-name`
3. Create IAM role for EC2 → S3 access (no hardcoded credentials)
4. Enable S3 versioning (compliance requirement)

**Gotcha:** S3 latency (10-50ms) acceptable for document attachments, poor for database storage. NEVER run PostgreSQL on S3.

---

## Common Architecture Mistakes

### Mistake 1: Over-Provisioning for Future Growth

**What happens:**
Company with 10 users deploys Tier 3 HA architecture "to avoid migration later." Pays $470/month for infrastructure serving <5% capacity.

**Math:**
- Year 1 cost: $5,640 (Tier 3)
- Alternative: Tier 1 ($1,248) + Year 2 migration to Tier 2 ($2,400) = $3,648
- **Waste: $1,992 in year one**

**Correct approach:** Start with Tier 1, migrate to Tier 2 when you hit 20 users (6-12 month timeline). Migration takes 4 hours, costs zero (manual process).

### Mistake 2: Using EBS for Filestore in Multi-Instance Setup

**What happens:**
Deploy Tier 3 with two EC2 instances, attach EBS volume to one instance. Second instance can't access filestore. Attachments uploaded via Instance A fail to load on Instance B.

**Why it fails:** EBS volumes attach to single EC2 instance only. No shared access.

**Fix:** Migrate filestore to S3 before deploying second instance.

**Migration script:**
```bash
# Run from EC2 instance with EBS filestore
aws s3 sync /opt/odoo/.local/share/Odoo/filestore s3://odoo-filestore-bucket/
# Update Odoo config: ir_attachment.location = s3://odoo-filestore-bucket
```

### Mistake 3: RDS Single-AZ in Production

**What happens:**
Choose db.t3.medium Single-AZ ($48/month) to save 50% vs Multi-AZ ($96/month). AWS performs maintenance, RDS goes offline for 15 minutes. Odoo crashes, users locked out.

**Cost of outage:**
- 15 minutes × 40 affected employees × $40/hour = $400 lost productivity
- Customer complaints: 3 escalations × 2 hours response = $240 support cost
- **Total: $640 cost from saving $48/month**

**Correct approach:** RDS Single-AZ acceptable for Tier 2 (non-critical), but schedule maintenance windows during off-hours (3am Sunday). Set up monitoring to alert on unplanned downtime.

### Mistake 4: No Auto Scaling Group (Tier 3)

**What happens:**
Deploy two EC2 instances manually behind ALB. Instance A crashes (hardware failure). ALB health checks fail, route traffic to Instance B only. Instance B overloads (18 workers → 9 workers), response times spike to 8 seconds.

**Why it fails:** No automatic instance replacement. Manual intervention required (launch new EC2, configure, attach to ALB).

**Fix:** Use Auto Scaling Group:
```
Min instances: 2
Desired: 2
Max: 4
Health check: ELB + EC2
Termination policy: OldestInstance
```

When instance fails, ASG launches replacement in <5 minutes. No manual intervention.

### Mistake 5: Ignoring Data Transfer Costs

**What happens:**
Deploy RDS in us-east-1, EC2 in us-west-2 (different regions). 500GB/month database queries cross regions. AWS charges $0.02/GB = $10/month extra.

**Worse:** Deploy RDS in AZ-1a, EC2 in AZ-1b (same region, different AZs). Cross-AZ transfer: 500GB × $0.01/GB = $5/month.

**Correct approach:**
- Tier 1: Single instance, single AZ (zero cross-AZ cost)
- Tier 2: EC2 and RDS in **same AZ** (zero cross-AZ cost)
- Tier 3: Accept cross-AZ cost as HA insurance (Multi-AZ RDS requirement)

**Tier 3 cost validation:**
- Cross-AZ data transfer: 1TB/month × $0.01/GB = $10/month
- Acceptable tradeoff for automatic failover capability

---

## Next Steps

### Ready to Deploy?

**Follow step-by-step deployment guide:**
[Odoo AWS Deployment Guide: EC2 + RDS in 4 Hours](/odoo-aws-deployment-guide/)

Covers:
- VPC setup with public/private subnets
- RDS PostgreSQL configuration (Odoo-optimized parameters)
- EC2 instance launch (Ubuntu 22.04 + Odoo 17)
- Nginx reverse proxy + Let's Encrypt SSL
- Disaster recovery testing (RDS PITR validation)

**Deployment time:** 4 hours for Tier 2, 8 hours for Tier 3.

### Get Production-Ready Tools

Skip 20+ hours of AWS trial-and-error with production-tested templates and calculators:


### Secure Your Deployment

**Next guide in series:**
[Odoo AWS Production Security Hardening](/odoo-aws-security-hardening/)

Covers:
- VPC design (public/private subnet isolation)
- Security group rules (least-privilege access)
- IAM roles for EC2 → RDS + S3 (no hardcoded credentials)
- RDS encryption at rest (KMS keys)
- SSL/TLS configuration (A+ SSL Labs rating)
- CloudWatch alarms (database CPU, disk queue, connection count)
- GuardDuty threat detection
- Compliance checklists (GDPR, SOC2, HIPAA)

**Time investment:** 6 hours to implement all security controls.

---

**Questions?** Open [GitHub issue](https://github.com/AriaShaw/AriaShaw.github.io/issues) or email [aria@ariashaw.com](mailto:aria@ariashaw.com).

**Found this useful?** Share architecture decision framework with your team.
