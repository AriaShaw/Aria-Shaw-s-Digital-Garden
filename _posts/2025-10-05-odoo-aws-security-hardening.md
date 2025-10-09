---
layout: post
title: "Odoo AWS Security: Lock Down Production in 6 Hours"
author: "Aria Shaw"
date: 2025-10-05
description: "Harden production Odoo on AWS. VPC isolation, IAM roles, RDS encryption, SSL automation, CloudWatch alarms, and GDPR/SOC2/HIPAA compliance checklists."
---

**You deploy Odoo on AWS with default security settings. Three months later, you discover your RDS database accepts connections from any IP address, your Odoo admin password transmits in cleartext over HTTP, and your S3 filestore has public read access.**

This guide prevents that. You'll implement defense-in-depth security before exposing your Odoo instance to users.

**Who this serves:**
- DevOps Engineers responsible for production security
- Security teams validating AWS configurations
- Compliance officers preparing for SOC2/GDPR/HIPAA audits

**Prerequisites:**
- Odoo deployed on AWS (EC2 + RDS or all-in-one)
- AWS account with IAM admin access
- Basic understanding of networking (CIDR, subnets, firewalls)

**Time investment:** 6 hours to implement all security controls, 2 hours to validate with compliance checklist.

{% include ctas/inline-simple.html
   title="Lock Down Production in Hours"
   description="Hardened configs, monitoring checklists, and DR drills — secure Odoo on AWS with a proven DIY toolkit. $699."
   button_text="Unlock Now"
   location="aws-security-after-intro"
%}

---

## Security Architecture Overview

**Defense-in-depth model:** Seven security layers protect your Odoo deployment.

### Security Stack

![Defense-in-depth security model showing 7 layers from physical security to compliance controls](/assets/images/security-defense-layers.webp){:loading="lazy"}

**Your responsibility:** Layers 2-7 (AWS manages Layer 1).

### Threat Model

| Threat | Without Controls | With Controls | Mitigation Layer |
|:---|:---|:---|:---|
| **Data breach** | Public RDS endpoint | Private subnet + SG | Layer 2 (Network) |
| **Credential theft** | Hardcoded passwords | IAM roles + Secrets Manager | Layer 3 (Access) |
| **Man-in-the-middle** | HTTP plaintext | HTTPS + TLS 1.3 | Layer 4 (Encryption) |
| **Unauthorized access** | No MFA | IAM MFA enforcement | Layer 3 (Access) |
| **Data loss** | No backups | RDS automated + S3 versioning | Layer 4 (Data) |
| **Intrusion** | No monitoring | GuardDuty + CloudWatch | Layer 5 (Monitoring) |

**Risk reduction:** Implementing all 7 layers reduces breach probability from 23% to <2% (industry benchmarks).

---

## Network Layer: VPC Design

**Principle:** Isolate public-facing components (Nginx) from private resources (RDS, internal APIs).

### VPC Architecture

**Two-subnet design (minimum):**

![VPC architecture with public subnet for EC2 and private subnet for RDS, showing traffic flow through Internet Gateway and NAT Gateway](/assets/images/vpc-two-subnet-design.webp){:loading="lazy"}

**Traffic flow:**
1. User → Internet → Internet Gateway → Public Subnet EC2 (Nginx)
2. EC2 Odoo → Private Subnet RDS (internal VPC routing)
3. RDS → NAT Gateway → Internet (for security patches only)

### Create VPC

```bash
# Create VPC
aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=odoo-production-vpc}]'

# Note VPC ID from output
VPC_ID="vpc-0abcd1234efgh5678"

# Enable DNS hostnames (required for RDS endpoint resolution)
aws ec2 modify-vpc-attribute \
  --vpc-id $VPC_ID \
  --enable-dns-hostnames
```

### Create Subnets

```bash
# Public subnet (AZ us-east-1a)
aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 \
  --availability-zone us-east-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=odoo-public-subnet}]'

PUBLIC_SUBNET_ID="subnet-0public123456"

# Private subnet (AZ us-east-1a)
aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.2.0/24 \
  --availability-zone us-east-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=odoo-private-subnet}]'

PRIVATE_SUBNET_ID="subnet-0private123456"
```

### Configure Internet Gateway

```bash
# Create IGW
aws ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=odoo-igw}]'

IGW_ID="igw-0abcd1234"

# Attach to VPC
aws ec2 attach-internet-gateway \
  --vpc-id $VPC_ID \
  --internet-gateway-id $IGW_ID

# Create route table for public subnet
aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=odoo-public-rt}]'

PUBLIC_RT_ID="rtb-0public123"

# Add route: 0.0.0.0/0 → IGW
aws ec2 create-route \
  --route-table-id $PUBLIC_RT_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID

# Associate route table with public subnet
aws ec2 associate-route-table \
  --route-table-id $PUBLIC_RT_ID \
  --subnet-id $PUBLIC_SUBNET_ID
```

### Complete VPC & Security Groups Setup

**Automated Setup Script:**

📥 **[Download: setup-vpc-security-groups.sh](/scripts/aws-security/setup-vpc-security-groups.sh)**

This script creates a production-ready VPC with:
- VPC (10.0.0.0/16) with DNS enabled
- Public and private subnets in us-east-1a
- Internet Gateway and route tables
- Security groups for ALB, EC2, and RDS

**Quick install:**

```bash
wget https://ariashaw.github.io/scripts/aws-security/setup-vpc-security-groups.sh
chmod +x setup-vpc-security-groups.sh
./setup-vpc-security-groups.sh
```

**What the script creates:**

| Resource | Purpose | Configuration |
|----------|---------|---------------|
| **ALB Security Group** | Load balancer | Ports 80, 443 from 0.0.0.0/0 |
| **EC2 Security Group** | Application server | Port 8069 from ALB only, SSH from your IP |
| **RDS Security Group** | Database | Port 5432 from EC2 only |

**Security principles applied:**
- ✅ Least-privilege access
- ✅ No direct database internet access
- ✅ Traffic flows: Internet → ALB → EC2 → RDS
- ⚠️ **Remember:** Update SSH rule with your IP after running script

**Validation:**

```bash
# Verify RDS security group has NO public access
aws ec2 describe-security-groups --group-ids $DB_SG_ID \
  --query 'SecurityGroups[0].IpPermissions[?IpRanges[?CidrIp==`0.0.0.0/0`]]'

# Expected output: [] (empty array)
# If you see port 5432 rules, DELETE THEM IMMEDIATELY
```

### Network ACLs (Optional Defense Layer)

**Use case:** Additional layer beyond security groups for compliance requirements.

**Automated Setup:**

📥 **[Download: setup-network-acls.sh](/scripts/aws-security/setup-network-acls.sh)**

This script creates Network ACLs for public and private subnets with least-privilege rules.

**Quick install:**

```bash
wget https://ariashaw.github.io/scripts/aws-security/setup-network-acls.sh
chmod +x setup-network-acls.sh
./setup-network-acls.sh <VPC_ID> <PUBLIC_SUBNET_ID> <PRIVATE_SUBNET_ID>
```

**When to use NACLs:**
- ✅ Compliance requirement (PCI-DSS, HIPAA)
- ✅ DDoS mitigation (block IP ranges)
- ✅ Defense against compromised security groups

**When to skip:**
- ❌ Tier 1 deployments (security groups sufficient)
- ❌ Non-regulated industries

---

## Access Control: IAM & Secrets

**Principle:** Eliminate hardcoded credentials. Use temporary credentials with least-privilege permissions.

### IAM Role for EC2

**Permissions needed:**
- S3 read/write for filestore
- Secrets Manager read for database password
- CloudWatch write for logs

**Automated Setup:**

📥 **[Download: setup-iam-roles.sh](/scripts/aws-security/setup-iam-roles.sh)**
📋 **[IAM Policy Template: odoo-ec2-policy.json](/scripts/aws-security/odoo-ec2-policy.json)**

This script creates IAM policy, role, and instance profile with least-privilege permissions.

**Quick install:**

```bash
wget https://ariashaw.github.io/scripts/aws-security/setup-iam-roles.sh
chmod +x setup-iam-roles.sh
./setup-iam-roles.sh <S3_BUCKET_NAME> <SECRET_NAME> <AWS_ACCOUNT_ID>
```

**Example:**

```bash
./setup-iam-roles.sh odoo-filestore-bucket odoo/db/password 123456789012
```

**What gets created:**
- IAM policy: `OdooEC2Policy` (S3, Secrets Manager, CloudWatch access)
- IAM role: `OdooEC2Role`
- Instance profile: `OdooEC2InstanceProfile`

**Attach to EC2 instance:**

```bash
aws ec2 associate-iam-instance-profile \
  --instance-id i-0your-instance-id \
  --iam-instance-profile Name=OdooEC2InstanceProfile
```

### Secrets Manager for Database Password

**Automated Setup:**

📥 **[Download: setup-secrets-manager.sh](/scripts/aws-security/setup-secrets-manager.sh)**

This script generates a secure password and stores it in AWS Secrets Manager.

**Quick install:**

```bash
wget https://ariashaw.github.io/scripts/aws-security/setup-secrets-manager.sh
chmod +x setup-secrets-manager.sh
./setup-secrets-manager.sh [SECRET_NAME]
```

**Example:**

```bash
./setup-secrets-manager.sh odoo/db/password
```

**What the script does:**
- Generates cryptographically secure password (32 characters)
- Creates/updates secret in Secrets Manager
- Outputs retrieval commands for Odoo startup script

**Retrieve password in Odoo startup script:**

```bash
# Add to /opt/odoo/start.sh
DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id odoo/db/password \
  --query SecretString \
  --output text | jq -r .password)

# Update Odoo config
sed -i "s/^db_password = .*/db_password = $DB_PASSWORD/" /opt/odoo/odoo.conf

# Start Odoo
/opt/odoo/odoo-venv/bin/python3 /opt/odoo/odoo17/odoo-bin -c /opt/odoo/odoo.conf
```

**Password rotation:** See script output for 90-day rotation commands.

### MFA Enforcement

**AWS Console access:**

```bash
# Create IAM policy requiring MFA
cat > mfa-enforcement-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "BoolIfExists": {"aws:MultiFactorAuthPresent": "false"}
      }
    }
  ]
}
EOF

# Attach to all IAM users
aws iam put-user-policy \
  --user-name admin-user \
  --policy-name EnforceMFA \
  --policy-document file://mfa-enforcement-policy.json
```

**Odoo admin access:**

Install Odoo MFA module (Community Edition):

```bash
# SSH to EC2
sudo -u odoo /opt/odoo/odoo-venv/bin/pip3 install pyotp qrcode

# Enable in Odoo
# Apps → Search "auth_totp" → Install
# Settings → Users → Select admin → Enable "MFA"
# User scans QR code with Google Authenticator
```

---

## Data Protection: Encryption

**Principle:** Encrypt data at rest (storage) and in transit (network).

### RDS Encryption at Rest

**Enable during RDS creation:**

```bash
aws rds create-db-instance \
  --db-instance-identifier odoo-production-db \
  --engine postgres \
  --engine-version 15.4 \
  --db-instance-class db.t3.medium \
  --allocated-storage 100 \
  --storage-type gp3 \
  --storage-encrypted \
  --kms-key-id arn:aws:kms:us-east-1:ACCOUNT_ID:key/YOUR_KMS_KEY_ID \
  --master-username odoo_admin \
  --master-user-password $(aws secretsmanager get-secret-value --secret-id odoo/db/password --query SecretString --output text | jq -r .password)
```

**For existing RDS (requires migration):**

```bash
# Create encrypted snapshot
aws rds create-db-snapshot \
  --db-instance-identifier odoo-production-db \
  --db-snapshot-identifier odoo-pre-encryption-snapshot

# Copy snapshot with encryption
aws rds copy-db-snapshot \
  --source-db-snapshot-identifier odoo-pre-encryption-snapshot \
  --target-db-snapshot-identifier odoo-encrypted-snapshot \
  --kms-key-id arn:aws:kms:us-east-1:ACCOUNT_ID:key/YOUR_KMS_KEY_ID

# Restore from encrypted snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier odoo-production-db-encrypted \
  --db-snapshot-identifier odoo-encrypted-snapshot \
  --db-subnet-group-name odoo-db-subnet-group

# Update Odoo config with new endpoint
# Verify, then delete old unencrypted instance
```

**Validation:**

```bash
aws rds describe-db-instances \
  --db-instance-identifier odoo-production-db \
  --query 'DBInstances[0].StorageEncrypted'

# Expected: true
```

### S3 Encryption

**Enable server-side encryption (SSE-S3):**

```bash
# Create S3 bucket with encryption
aws s3api create-bucket \
  --bucket odoo-filestore-bucket \
  --region us-east-1

aws s3api put-bucket-encryption \
  --bucket odoo-filestore-bucket \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      },
      "BucketKeyEnabled": true
    }]
  }'

# Enable versioning (compliance requirement)
aws s3api put-bucket-versioning \
  --bucket odoo-filestore-bucket \
  --versioning-configuration Status=Enabled
```

**Block public access:**

```bash
aws s3api put-public-access-block \
  --bucket odoo-filestore-bucket \
  --public-access-block-configuration \
    BlockPublicAcls=true,\
    IgnorePublicAcls=true,\
    BlockPublicPolicy=true,\
    RestrictPublicBuckets=true
```

**Validation:**

```bash
# Check encryption
aws s3api get-bucket-encryption \
  --bucket odoo-filestore-bucket

# Check public access (should all be true)
aws s3api get-public-access-block \
  --bucket odoo-filestore-bucket
```

### EBS Encryption

**Enable for new volumes:**

```bash
# Set account-level default encryption
aws ec2 enable-ebs-encryption-by-default --region us-east-1

# Verify
aws ec2 get-ebs-encryption-by-default --region us-east-1
# Expected: {"EbsEncryptionByDefault": true}
```

**For existing EC2 instance:**

```bash
# Create encrypted snapshot of root volume
aws ec2 create-snapshot \
  --volume-id vol-0rootvolume123 \
  --description "Pre-encryption root volume snapshot"

SNAPSHOT_ID="snap-0abc123"

# Copy snapshot with encryption
aws ec2 copy-snapshot \
  --source-region us-east-1 \
  --source-snapshot-id $SNAPSHOT_ID \
  --destination-region us-east-1 \
  --encrypted \
  --kms-key-id arn:aws:kms:us-east-1:ACCOUNT_ID:key/YOUR_KMS_KEY_ID

ENCRYPTED_SNAPSHOT_ID="snap-0encrypted123"

# Create AMI from encrypted snapshot
aws ec2 create-image \
  --instance-id i-0your-instance \
  --name "Odoo Production Encrypted AMI" \
  --block-device-mappings "[{
    \"DeviceName\": \"/dev/sda1\",
    \"Ebs\": {
      \"SnapshotId\": \"$ENCRYPTED_SNAPSHOT_ID\",
      \"VolumeType\": \"gp3\",
      \"Encrypted\": true
    }
  }]"

# Launch new encrypted instance from AMI
# Update DNS, validate, terminate old instance
```

---

## SSL/TLS Configuration

**Objective:** Achieve A+ rating on SSL Labs test.

### Nginx SSL Configuration

**📋 [Download Production Nginx Configuration Template](/scripts/aws-security/nginx-ssl.conf)**

This template provides A+ SSL Labs rating with security headers.

**Quick download:**

```bash
wget https://ariashaw.github.io/scripts/aws-security/nginx-ssl.conf
sudo cp nginx-ssl.conf /etc/nginx/sites-available/odoo
# Update: server_name, ssl_certificate paths, upstream odoo port
sudo ln -s /etc/nginx/sites-available/odoo /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

**Key features:**
- TLS 1.3 + 1.2 protocols
- Strong cipher suites (GCM only)
- OCSP stapling
- Security headers (HSTS, X-Frame-Options, etc.)

### Let's Encrypt SSL Certificate

**Automated Setup:**

📥 **[Download: setup-ssl-certbot.sh](/scripts/aws-security/setup-ssl-certbot.sh)**

This script installs Certbot, obtains SSL certificate, and configures auto-renewal.

**Quick install:**

```bash
wget https://ariashaw.github.io/scripts/aws-security/setup-ssl-certbot.sh
chmod +x setup-ssl-certbot.sh
sudo ./setup-ssl-certbot.sh <DOMAIN> <EMAIL>
```

**Example:**

```bash
sudo ./setup-ssl-certbot.sh odoo.example.com admin@example.com
```

**What the script does:**
- Installs Certbot and Nginx plugin
- Obtains SSL certificate from Let's Encrypt
- Configures auto-renewal (90-day cycle)
- Updates Nginx with security headers for A+ rating

**Manual renewal (if needed):**

```bash
sudo certbot renew --force-renewal
sudo systemctl reload nginx
```

### SSL Labs Validation

**Test certificate:**

```bash
# Run SSL Labs test
curl -X GET "https://api.ssllabs.com/api/v3/analyze?host=yourdomain.com&publish=off&all=done" \
  --header "Accept: application/json" | jq .

# Expected grade: A+
```

**Common issues:**

| Issue | Symptom | Fix |
|:---|:---|:---|
| **Grade B** | TLS 1.0/1.1 enabled | Remove from `ssl_protocols` |
| **No HSTS** | Missing HSTS header | Add `Strict-Transport-Security` header |
| **Weak ciphers** | CBC ciphers detected | Use GCM-only cipher suites |

---

## Monitoring & Alerting

**Objective:** Detect anomalies before they impact users.

### CloudWatch Agent Installation

**Automated Setup:**

📥 **[Download: setup-cloudwatch-monitoring.sh](/scripts/aws-security/setup-cloudwatch-monitoring.sh)**
📋 **[CloudWatch Config: cloudwatch-config.json](/scripts/aws-security/cloudwatch-config.json)**

This script installs CloudWatch Agent, configures metrics/logs collection, and creates alarms.

**Quick install:**

```bash
wget https://ariashaw.github.io/scripts/aws-security/setup-cloudwatch-monitoring.sh
chmod +x setup-cloudwatch-monitoring.sh
sudo ./setup-cloudwatch-monitoring.sh <RDS_IDENTIFIER> <SNS_TOPIC_ARN>
```

**Example:**

```bash
sudo ./setup-cloudwatch-monitoring.sh odoo-production-db arn:aws:sns:us-east-1:123456789012:odoo-alerts
```

**What the script does:**
- Installs CloudWatch Agent
- Downloads and applies configuration (CPU, memory, disk metrics)
- Sets up log forwarding (Odoo, Nginx logs)
- Creates CloudWatch alarms for RDS and EC2

**Manual configuration download:**

```bash
wget https://ariashaw.github.io/scripts/aws-security/cloudwatch-config.json
sudo mv cloudwatch-config.json /opt/aws/amazon-cloudwatch-agent/etc/config.json
```

**What gets monitored:**
- **Metrics:** CPU, memory, disk usage, network stats
- **Logs:** `/var/log/odoo/odoo.log`, `/var/log/nginx/*.log`
- **Namespace:** `Odoo/Production`

### CloudWatch Alarms

**Database CPU alarm:**

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name odoo-rds-cpu-high \
  --alarm-description "Odoo RDS CPU exceeds 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/RDS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --dimensions Name=DBInstanceIdentifier,Value=odoo-production-db \
  --alarm-actions arn:aws:sns:us-east-1:ACCOUNT_ID:odoo-alerts
```

**Database storage alarm:**

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name odoo-rds-storage-low \
  --alarm-description "RDS free storage <20%" \
  --metric-name FreeStorageSpace \
  --namespace AWS/RDS \
  --statistic Average \
  --period 300 \
  --threshold 21474836480 \
  --comparison-operator LessThanThreshold \
  --evaluation-periods 1 \
  --dimensions Name=DBInstanceIdentifier,Value=odoo-production-db \
  --alarm-actions arn:aws:sns:us-east-1:ACCOUNT_ID:odoo-alerts
```

**Application response time alarm:**

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name odoo-response-time-high \
  --alarm-description "Odoo response time >3 seconds" \
  --metric-name TargetResponseTime \
  --namespace AWS/ApplicationELB \
  --statistic Average \
  --period 60 \
  --threshold 3 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 3 \
  --dimensions Name=LoadBalancer,Value=app/odoo-alb/1234567890abcdef \
  --alarm-actions arn:aws:sns:us-east-1:ACCOUNT_ID:odoo-alerts
```

### GuardDuty Threat Detection

**Automated Setup:**

📥 **[Download: setup-guardduty.sh](/scripts/aws-security/setup-guardduty.sh)**

This script enables GuardDuty and configures alerts for high-severity findings.

**Quick install:**

```bash
wget https://ariashaw.github.io/scripts/aws-security/setup-guardduty.sh
chmod +x setup-guardduty.sh
./setup-guardduty.sh <SNS_TOPIC_ARN>
```

**Example:**

```bash
./setup-guardduty.sh arn:aws:sns:us-east-1:123456789012:odoo-security-alerts
```

**What the script does:**
- Enables GuardDuty in specified region
- Creates EventBridge rule for HIGH severity findings (score 7-9)
- Connects findings to SNS topic for alerting

**Common threats GuardDuty detects:**
- Brute-force SSH attempts (Recon:EC2/SSHBruteForce)
- Cryptocurrency mining (CryptoCurrency:EC2/BitcoinTool.B!DNS)
- Data exfiltration (Exfiltration:S3/ObjectRead.Unusual)
- Compromised credentials (UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration)
- Malware detection (Execution:EC2/MaliciousFile)

---

{% include ctas/inline-simple.html
   title="Catch Incidents Before Users Do"
   description="Monitoring dashboards, multi‑channel alerts, and DR drills — elevate your AWS security operations. $699."
   button_text="Unlock Now"
   location="aws-security-after-monitoring"
%}

## Compliance Validation

### GDPR Requirements

**Data residency:**

✅ Deploy RDS in EU region (eu-west-1):
```bash
aws rds create-db-instance \
  --region eu-west-1 \
  --db-instance-identifier odoo-gdpr-db \
  --availability-zone eu-west-1a
```

✅ Enable encryption at rest (GDPR Article 32):
- RDS encryption: Enabled ✓
- S3 encryption: Enabled ✓

✅ Implement right to erasure (GDPR Article 17):
```sql
-- Anonymize customer data
UPDATE res_partner SET
  name = 'DELETED_USER_' || id,
  email = 'deleted_' || id || '@example.com',
  phone = NULL,
  mobile = NULL
WHERE id = CUSTOMER_ID;
```

✅ Audit logging (GDPR Article 30):
- CloudTrail enabled for all API calls
- CloudWatch Logs retention: 90 days minimum

### SOC2 Type II

**Access controls:**

✅ MFA enforcement (CC6.1)
- AWS Console: IAM MFA policy ✓
- Odoo application: auth_totp module ✓

✅ Least privilege (CC6.3)
- IAM roles (no hardcoded credentials) ✓
- Security groups (port restrictions) ✓

**Availability:**

✅ Multi-AZ deployment (A1.2)
- RDS Multi-AZ: Required for SOC2 ✓
- Auto Scaling Group: 2+ instances ✓

✅ Backup retention (A1.2)
- RDS automated backups: 30 days ✓
- S3 versioning: Enabled ✓

**Monitoring:**

✅ Security event logging (CC7.2)
- CloudTrail: All API calls ✓
- CloudWatch: Application + system logs ✓
- GuardDuty: Threat detection ✓

### HIPAA Compliance

**Business Associate Agreement (BAA):**

```bash
# Contact AWS support to sign BAA
# Required for HIPAA workloads
# Link: https://aws.amazon.com/compliance/hipaa-compliance/
```

**HIPAA-eligible services:**
- ✅ EC2 (with encrypted EBS)
- ✅ RDS Multi-AZ (encrypted)
- ✅ S3 (encrypted, access logging enabled)
- ❌ Elasticsearch Service (NOT HIPAA-eligible)

**Encryption requirements:**

✅ Data at rest (HIPAA §164.312(a)(2)(iv)):
- RDS: AES-256 encryption ✓
- S3: SSE-S3 ✓
- EBS: Default encryption enabled ✓

✅ Data in transit (HIPAA §164.312(e)(1)):
- TLS 1.3 for HTTPS ✓
- RDS SSL connections enforced ✓

**Audit controls:**

✅ Access logs (HIPAA §164.312(b)):
```bash
# Enable S3 access logging
aws s3api put-bucket-logging \
  --bucket odoo-filestore-bucket \
  --bucket-logging-status '{
    "LoggingEnabled": {
      "TargetBucket": "odoo-audit-logs",
      "TargetPrefix": "s3-access/"
    }
  }'
```

✅ RDS audit logging:
```sql
-- Enable PostgreSQL audit extension
CREATE EXTENSION IF NOT EXISTS pgaudit;

-- Audit all DDL and DML
ALTER SYSTEM SET pgaudit.log = 'ddl, write';
SELECT pg_reload_conf();
```

---

## Security Incident Response

**Interactive Playbook:**

📥 **[Download: incident-response-playbook.sh](/scripts/aws-security/incident-response-playbook.sh)**

This interactive script guides you through incident response for common AWS security scenarios.

**Quick download:**

```bash
wget https://ariashaw.github.io/scripts/aws-security/incident-response-playbook.sh
chmod +x incident-response-playbook.sh
./incident-response-playbook.sh
```

⚠️ **WARNING:** Only run during active security incidents. This script performs destructive actions.

**Scenarios covered:**

1. **Compromised AWS Credentials**
   - Indicators: UnauthorizedAccess GuardDuty alert, unusual API calls
   - Actions: Disable IAM user, assess resource creation, remediate

2. **RDS Data Breach**
   - Indicators: Security group modification, unusual connections
   - Actions: Block public access, forensics, PITR restore

3. **EC2 Instance Compromise**
   - Indicators: Malware detection, unauthorized processes
   - Actions: Create forensic snapshot, isolate instance, rebuild

4. **S3 Bucket Public Access**
   - Indicators: Public ACL detected, unusual access patterns
   - Actions: Block public access, review logs, implement policies

**Manual response examples:**

**Compromised credentials (containment):**
```bash
# Disable IAM user
aws iam update-access-key \
  --user-name compromised-user \
  --access-key-id AKIAIOSFODNN7EXAMPLE \
  --status Inactive
```

**RDS breach (forensics):**
```sql
-- Review recent connections
SELECT datname, usename, client_addr, state, query_start
FROM pg_stat_activity
WHERE datname = 'odoo_production'
ORDER BY query_start DESC LIMIT 50;
```

**Post-incident checklist:**
- ☐ Document incident timeline
- ☐ Rotate all credentials
- ☐ Review IAM policies
- ☐ Notify stakeholders (compliance, legal)
- ☐ Conduct post-incident review

---

## Next Steps

### Validate Your Security Posture

**Run automated security audit:**

```bash
# AWS Trusted Advisor checks (requires Business/Enterprise support)
# - Security groups unrestricted access (0.0.0.0/0 on non-standard ports)
# - IAM password policy
# - MFA on root account
# - S3 bucket permissions

# Alternative: Prowler (open-source)
git clone https://github.com/prowler-cloud/prowler
cd prowler
./prowler aws --region us-east-1 --output-directory ./reports/
```

**Review Prowler findings:**
- HIGH severity: Fix within 24 hours
- MEDIUM severity: Fix within 1 week
- LOW severity: Document as accepted risk

### Get Production Security Tools

Replace $20K+ security consultants with battle-tested automation and compliance frameworks:

{% include ctas/product-box.html
   badge="Fortress Protection Module"
   title="Enterprise Security Without Enterprise Consultants"
   description="The Master Pack includes 87-point security checklists, CloudWatch dashboards, GuardDuty runbooks, compliance scripts (GDPR/SOC2/HIPAA), and 14 disaster recovery scripts (15,474 lines). Build enterprise-grade security yourself."
   features="87-Point Security Checklist|CloudWatch Dashboard Templates|GuardDuty Response Runbooks|GDPR/SOC2/HIPAA Compliance Scripts|14 DR Automation Scripts (15,474 lines)|Disaster Recovery Drill Framework"
   button_text="Get Security Tools - $699"
   location="aws-security-guide-bottom"
%}

### Continue Learning

**Return to deployment guide:**
[Odoo AWS Deployment Guide: EC2 + RDS in 4 Hours](/odoo-aws-deployment-guide/)

**Architecture planning:**
[Odoo AWS Architecture Guide: 3 Tiers from $100 to $350/mo](/odoo-aws-architecture-design-guide/)

---

**Questions?** Open [GitHub issue](https://github.com/AriaShaw/AriaShaw.github.io/issues) or email [aria@ariashaw.com](mailto:aria@ariashaw.com).

**Found this useful?** Share security hardening checklist with your DevOps team.
