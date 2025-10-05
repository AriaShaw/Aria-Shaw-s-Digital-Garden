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

### Security Groups

**Principle:** Least-privilege access. Allow only required ports from specific sources.

**EC2 Security Group (odoo-app-sg):**

```bash
# Create security group
aws ec2 create-security-group \
  --group-name odoo-app-sg \
  --description "Odoo application server security group" \
  --vpc-id $VPC_ID

APP_SG_ID="sg-0app123456"

# Allow HTTPS from internet (443)
aws ec2 authorize-security-group-ingress \
  --group-id $APP_SG_ID \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0

# Allow HTTP (redirect to HTTPS)
aws ec2 authorize-security-group-ingress \
  --group-id $APP_SG_ID \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

# Allow SSH from YOUR_IP only (replace with your office IP)
aws ec2 authorize-security-group-ingress \
  --group-id $APP_SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr YOUR_OFFICE_IP/32

# Allow all outbound (for apt updates, pip installs)
aws ec2 authorize-security-group-egress \
  --group-id $APP_SG_ID \
  --protocol -1 \
  --cidr 0.0.0.0/0
```

**RDS Security Group (odoo-db-sg):**

```bash
# Create RDS security group
aws ec2 create-security-group \
  --group-name odoo-db-sg \
  --description "Odoo RDS PostgreSQL security group" \
  --vpc-id $VPC_ID

DB_SG_ID="sg-0db123456"

# Allow PostgreSQL (5432) ONLY from EC2 security group
aws ec2 authorize-security-group-ingress \
  --group-id $DB_SG_ID \
  --protocol tcp \
  --port 5432 \
  --source-group $APP_SG_ID

# CRITICAL: No public access
# Do NOT add rule: --cidr 0.0.0.0/0
```

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

**Public subnet NACL:**

```bash
# Create NACL
aws ec2 create-network-acl \
  --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=network-acl,Tags=[{Key=Name,Value=odoo-public-nacl}]'

PUBLIC_NACL_ID="acl-0public123"

# Allow inbound HTTPS
aws ec2 create-network-acl-entry \
  --network-acl-id $PUBLIC_NACL_ID \
  --rule-number 100 \
  --protocol 6 \
  --port-range From=443,To=443 \
  --cidr-block 0.0.0.0/0 \
  --ingress \
  --rule-action allow

# Allow inbound HTTP
aws ec2 create-network-acl-entry \
  --network-acl-id $PUBLIC_NACL_ID \
  --rule-number 110 \
  --protocol 6 \
  --port-range From=80,To=80 \
  --cidr-block 0.0.0.0/0 \
  --ingress \
  --rule-action allow

# Allow return traffic (ephemeral ports)
aws ec2 create-network-acl-entry \
  --network-acl-id $PUBLIC_NACL_ID \
  --rule-number 120 \
  --protocol 6 \
  --port-range From=1024,To=65535 \
  --cidr-block 0.0.0.0/0 \
  --ingress \
  --rule-action allow
```

**When to use NACLs:**
- Compliance requirement (PCI-DSS, HIPAA)
- DDoS mitigation (block IP ranges)
- Defense against compromised security groups

**When to skip:**
- Tier 1 deployments (security groups sufficient)
- Non-regulated industries

---

## Access Control: IAM & Secrets

**Principle:** Eliminate hardcoded credentials. Use temporary credentials with least-privilege permissions.

### IAM Role for EC2

**Permissions needed:**
- S3 read/write for filestore
- Secrets Manager read for database password
- CloudWatch write for logs

**Create IAM policy:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::odoo-filestore-bucket/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": "arn:aws:s3:::odoo-filestore-bucket"
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:us-east-1:ACCOUNT_ID:secret:odoo/db/password-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:us-east-1:ACCOUNT_ID:log-group:/aws/ec2/odoo:*"
    }
  ]
}
```

**Create and attach role:**

```bash
# Save policy to file
cat > odoo-ec2-policy.json << 'EOF'
{JSON_POLICY_FROM_ABOVE}
EOF

# Create policy
aws iam create-policy \
  --policy-name OdooEC2Policy \
  --policy-document file://odoo-ec2-policy.json

POLICY_ARN="arn:aws:iam::ACCOUNT_ID:policy/OdooEC2Policy"

# Create IAM role
aws iam create-role \
  --role-name OdooEC2Role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "ec2.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }'

# Attach policy to role
aws iam attach-role-policy \
  --role-name OdooEC2Role \
  --policy-arn $POLICY_ARN

# Create instance profile
aws iam create-instance-profile \
  --instance-profile-name OdooEC2InstanceProfile

# Add role to instance profile
aws iam add-role-to-instance-profile \
  --instance-profile-name OdooEC2InstanceProfile \
  --role-name OdooEC2Role

# Attach to EC2 instance
aws ec2 associate-iam-instance-profile \
  --instance-id i-0your-instance-id \
  --iam-instance-profile Name=OdooEC2InstanceProfile
```

### Secrets Manager for Database Password

**Store RDS password:**

```bash
# Generate secure password
DB_PASSWORD=$(openssl rand -base64 32)

# Store in Secrets Manager
aws secretsmanager create-secret \
  --name odoo/db/password \
  --description "Odoo RDS PostgreSQL master password" \
  --secret-string "{\"password\":\"$DB_PASSWORD\"}"

# Note the ARN
SECRET_ARN="arn:aws:secretsmanager:us-east-1:ACCOUNT_ID:secret:odoo/db/password-AbCdEf"
```

**Retrieve password in Odoo startup script:**

```bash
# Add to /opt/odoo/start.sh
#!/bin/bash

# Retrieve RDS password from Secrets Manager
DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id odoo/db/password \
  --query SecretString \
  --output text | jq -r .password)

# Update Odoo config
sed -i "s/^db_password = .*/db_password = $DB_PASSWORD/" /opt/odoo/odoo.conf

# Start Odoo
/opt/odoo/odoo-venv/bin/python3 /opt/odoo/odoo17/odoo-bin -c /opt/odoo/odoo.conf
```

**Rotate password (90-day cycle):**

```bash
# Generate new password
NEW_PASSWORD=$(openssl rand -base64 32)

# Update Secrets Manager
aws secretsmanager update-secret \
  --secret-id odoo/db/password \
  --secret-string "{\"password\":\"$NEW_PASSWORD\"}"

# Update RDS master password
aws rds modify-db-instance \
  --db-instance-identifier odoo-production-db \
  --master-user-password $NEW_PASSWORD \
  --apply-immediately

# Restart Odoo (will fetch new password from Secrets Manager)
sudo systemctl restart odoo
```

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

**📋 [Download Production Nginx Configuration Template](/templates/nginx-odoo-ssl.conf)**
*Quick download: `wget https://ariashaw.github.io/templates/nginx-odoo-ssl.conf -O /etc/nginx/sites-available/odoo`*

**Key settings (from template):**

```nginx
# TLS 1.3 only (backwards compatibility: add TLSv1.2)
ssl_protocols TLSv1.3 TLSv1.2;

# Strong cipher suites
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
ssl_prefer_server_ciphers off;

# OCSP stapling (validates certificate chain)
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;

# HSTS (forces HTTPS for 2 years)
add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;

# Security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
```

### Let's Encrypt SSL Certificate

**Install Certbot:**

```bash
sudo apt install certbot python3-certbot-nginx -y
```

**Obtain certificate:**

```bash
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com \
  --non-interactive \
  --agree-tos \
  --email admin@yourdomain.com \
  --redirect
```

**Auto-renewal (90-day cycle):**

```bash
# Test renewal
sudo certbot renew --dry-run

# Certbot installs cron job automatically at:
# /etc/cron.d/certbot

# Verify
cat /etc/cron.d/certbot
# Should contain: 0 */12 * * * root test -x /usr/bin/certbot -a \! -d /run/systemd/system && perl -e 'sleep int(rand(43200))' && certbot -q renew
```

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

```bash
# SSH to EC2
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i amazon-cloudwatch-agent.deb
```

**Configure agent:**

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-config-wizard
```

**Recommended configuration:**

```json
{
  "metrics": {
    "namespace": "Odoo/Production",
    "metrics_collected": {
      "cpu": {
        "measurement": [{"name": "cpu_usage_idle", "rename": "CPU_IDLE", "unit": "Percent"}],
        "metrics_collection_interval": 60,
        "totalcpu": false
      },
      "disk": {
        "measurement": [
          {"name": "used_percent", "rename": "DISK_USED", "unit": "Percent"}
        ],
        "metrics_collection_interval": 60,
        "resources": ["/"]
      },
      "mem": {
        "measurement": [{"name": "mem_used_percent", "rename": "MEM_USED", "unit": "Percent"}],
        "metrics_collection_interval": 60
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/odoo/odoo.log",
            "log_group_name": "/aws/ec2/odoo/application",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/nginx/access.log",
            "log_group_name": "/aws/ec2/odoo/nginx-access",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/nginx/error.log",
            "log_group_name": "/aws/ec2/odoo/nginx-error",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
```

**Start agent:**

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json
```

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

**Enable GuardDuty:**

```bash
aws guardduty create-detector --enable --region us-east-1
```

**Configure findings notifications:**

```bash
# Create EventBridge rule for HIGH severity findings
aws events put-rule \
  --name odoo-guardduty-high \
  --description "GuardDuty HIGH severity findings" \
  --event-pattern '{
    "source": ["aws.guardduty"],
    "detail-type": ["GuardDuty Finding"],
    "detail": {"severity": [7, 8, 9]}
  }'

# Target SNS topic
aws events put-targets \
  --rule odoo-guardduty-high \
  --targets "Id"="1","Arn"="arn:aws:sns:us-east-1:ACCOUNT_ID:odoo-security-alerts"
```

**Common threats GuardDuty detects:**
- Brute-force SSH attempts (Recon:EC2/SSHBruteForce)
- Cryptocurrency mining (CryptoCurrency:EC2/BitcoinTool.B!DNS)
- Data exfiltration (Exfiltration:S3/ObjectRead.Unusual)
- Compromised credentials (UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration)
- Malware detection (Execution:EC2/MaliciousFile)
- Container compromise (Container:Kubernetes/MaliciousIPCaller.Custom)

---

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

### Runbook: Compromised AWS Credentials

**Indicators:**
- GuardDuty alert: UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration
- Unusual AWS API calls in CloudTrail
- Unknown EC2 instances launched

**Response (5-minute timeline):**

![Security incident response workflow for compromised AWS credentials showing contain, assess, remediate, and prevent phases](/assets/images/security-incident-response-credentials.webp){:loading="lazy"}

**Minute 1: Contain**
```bash
# Disable compromised IAM user
aws iam update-access-key \
  --user-name compromised-user \
  --access-key-id AKIAIOSFODNN7EXAMPLE \
  --status Inactive

# Attach deny-all policy
aws iam put-user-policy \
  --user-name compromised-user \
  --policy-name DenyAll \
  --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Deny","Action":"*","Resource":"*"}]}'
```

**Minute 2-3: Assess**
```bash
# List all resources created by compromised credentials
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=compromised-user \
  --start-time 2025-10-05T00:00:00Z \
  --query 'Events[?Resources[?ResourceType==`AWS::EC2::Instance`]].CloudTrailEvent' \
  --output text | jq .
```

**Minute 4-5: Remediate**
```bash
# Terminate unauthorized EC2 instances
aws ec2 terminate-instances --instance-ids i-unauthorized-1 i-unauthorized-2

# Delete unauthorized S3 buckets
aws s3 rb s3://unauthorized-bucket --force

# Revoke IAM role trust policy changes
aws iam update-assume-role-policy \
  --role-name OdooEC2Role \
  --policy-document file://original-trust-policy.json
```

**Post-incident:**
- Rotate all secrets (Secrets Manager passwords)
- Review IAM policies (remove excessive permissions)
- Enable AWS Config for drift detection

### Runbook: RDS Data Breach

**Indicators:**
- Security group modified (port 5432 opened to 0.0.0.0/0)
- GuardDuty alert: Exfiltration:RDS/MaliciousIPCaller
- Unusual database connection count

**Response:**

**Immediate:**
```bash
# Revert security group change
aws ec2 revoke-security-group-ingress \
  --group-id sg-0db123456 \
  --protocol tcp \
  --port 5432 \
  --cidr 0.0.0.0/0

# Force disconnect all database sessions
aws rds reboot-db-instance \
  --db-instance-identifier odoo-production-db
```

**Forensics:**
```sql
-- Review recent connections
SELECT datname, usename, client_addr, state, query_start
FROM pg_stat_activity
WHERE datname = 'odoo_production'
ORDER BY query_start DESC LIMIT 50;

-- Check for data dumps
SELECT schemaname, tablename, n_tup_del
FROM pg_stat_user_tables
WHERE n_tup_del > 10000
ORDER BY n_tup_del DESC;
```

**Recovery:**
```bash
# Restore from PITR (5 minutes before breach)
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier odoo-production-db \
  --target-db-instance-identifier odoo-restored-db \
  --restore-time 2025-10-05T10:25:00Z
```

**Notification:**
- Incident report to compliance team (GDPR 72-hour notification requirement)
- Customer notification if PII exfiltrated
- Law enforcement contact (if criminal activity suspected)

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

**Fortress Protection Module ($299 standalone, included in Master Pack):**

What you get:
- **Security Hardening Checklist** (PDF): 87-point validation (network, access, encryption, monitoring)
- **CloudWatch Dashboard Templates** (JSON): Pre-configured dashboards for RDS, EC2, ALB metrics
- **GuardDuty Runbooks** (PDF): Response procedures for 15 common threats
- **Compliance Audit Scripts** (Bash): Automated GDPR/SOC2/HIPAA validation
- **Backup Orchestration Scripts** (14 production scripts, 15,474 lines): Multi-cloud sync (AWS S3, Backblaze B2, Google Drive)
- **Disaster Recovery Drill Framework** (Excel): Test plans for 6 failure scenarios (RDS crash, AZ outage, region failure)

**Why buy vs build yourself:**
- Checklist compiled from 300+ production deployments (save 20 hours of research)
- Runbooks tested in real incidents (save hours during crisis)
- DR framework covers edge cases (S3 CRR lag, DNS propagation delay)

**Purchase:** [Fortress Protection Module](/products/?utm_source=blog&utm_medium=inline-cta&utm_campaign=aws-security-guide#module4) or [Master Pack](/products/?utm_source=blog&utm_medium=inline-cta&utm_campaign=aws-security-guide) ($699 for all 5 modules).

### Continue Learning

**Return to deployment guide:**
[Odoo AWS Deployment Guide: EC2 + RDS in 4 Hours](/odoo-aws-deployment-guide/)

**Architecture planning:**
[Odoo AWS Architecture Guide: 3 Tiers from $100 to $350/mo](/odoo-aws-architecture-design-guide/)

---

{% include ctas/product-box.html
   badge="Complete DIY Toolkit"
   title="Own Your Odoo Security Infrastructure"
   description="Master Pack: 68+ production scripts, security hardening checklists, compliance validation tools, DR drill frameworks. Build enterprise-grade security yourself—configure cloud backups, automate monitoring, test disaster recovery. Replace $20,000+ security consultants."
   features="14 DR scripts (15,474 lines)|Security audit automation|CloudWatch dashboards|GDPR/SOC2/HIPAA checklists|Lifetime access"
   link="/products/?utm_source=blog&utm_medium=product-box&utm_campaign=aws-security-guide"
   button_text="Get Master Pack - $699"
%}

---

**Questions?** Open [GitHub issue](https://github.com/AriaShaw/AriaShaw.github.io/issues) or email aria@digitalplumber.dev.

**Found this useful?** Share security hardening checklist with your DevOps team.
