# AWS Security Scripts for Odoo Deployment

Production-ready security automation scripts for deploying Odoo on AWS with enterprise-grade security controls.

## 📥 Quick Start

### Download All Scripts

```bash
# Download entire directory
wget -r -np -nH --cut-dirs=2 -R "index.html*" https://ariashaw.github.io/scripts/aws-security/

# Or download individual scripts (see below)
```

### Prerequisites

- AWS CLI configured with appropriate credentials
- `jq` and `openssl` installed for JSON parsing and password generation
- Basic understanding of AWS VPC, IAM, and security groups
- Root/sudo access for server-side scripts (Certbot, CloudWatch Agent)

---

## 🔒 Security Setup Scripts

### 1. VPC & Security Groups Setup

**File:** [setup-vpc-security-groups.sh](setup-vpc-security-groups.sh)

**Purpose:** Creates production VPC with public/private subnets and security groups

**What it does:**
- Creates VPC (10.0.0.0/16) with DNS enabled
- Sets up public subnet (10.0.1.0/24) and private subnet (10.0.2.0/24)
- Configures Internet Gateway and route tables
- Creates security groups for ALB, EC2, and RDS with least-privilege rules

**Usage:**
```bash
wget https://ariashaw.github.io/scripts/aws-security/setup-vpc-security-groups.sh
chmod +x setup-vpc-security-groups.sh
./setup-vpc-security-groups.sh
```

**Outputs:** VPC ID, Subnet IDs, Security Group IDs (save these for deployment)

---

### 2. Network ACLs Setup (Optional)

**File:** [setup-network-acls.sh](setup-network-acls.sh)

**Purpose:** Additional defense layer beyond security groups (for compliance)

**When to use:**
- ✅ Compliance requirement (PCI-DSS, HIPAA, SOC2)
- ✅ DDoS mitigation (block IP ranges)
- ✅ Defense against compromised security groups

**Usage:**
```bash
wget https://ariashaw.github.io/scripts/aws-security/setup-network-acls.sh
chmod +x setup-network-acls.sh
./setup-network-acls.sh <VPC_ID> <PUBLIC_SUBNET_ID> <PRIVATE_SUBNET_ID>
```

---

### 3. IAM Roles & Policies Setup

**File:** [setup-iam-roles.sh](setup-iam-roles.sh)

**Purpose:** Creates IAM roles with least-privilege permissions for EC2 instances

**What it does:**
- Creates IAM policy (S3, Secrets Manager, CloudWatch access)
- Creates IAM role with EC2 trust policy
- Creates instance profile for EC2 attachment

**Usage:**
```bash
wget https://ariashaw.github.io/scripts/aws-security/setup-iam-roles.sh
chmod +x setup-iam-roles.sh
./setup-iam-roles.sh <S3_BUCKET_NAME> <SECRET_NAME> <AWS_ACCOUNT_ID>
```

**Example:**
```bash
./setup-iam-roles.sh odoo-filestore-bucket odoo/db/password 123456789012
```

---

### 4. Secrets Manager Setup

**File:** [setup-secrets-manager.sh](setup-secrets-manager.sh)

**Purpose:** Stores RDS database password in AWS Secrets Manager

**What it does:**
- Generates cryptographically secure password (32 characters)
- Stores password in Secrets Manager
- Outputs retrieval commands for Odoo startup scripts

**Usage:**
```bash
wget https://ariashaw.github.io/scripts/aws-security/setup-secrets-manager.sh
chmod +x setup-secrets-manager.sh
./setup-secrets-manager.sh [SECRET_NAME]
```

**Example:**
```bash
./setup-secrets-manager.sh odoo/db/password
```

---

### 5. SSL Certificate Setup (Let's Encrypt)

**File:** [setup-ssl-certbot.sh](setup-ssl-certbot.sh)

**Purpose:** Automates SSL/TLS certificate installation with Certbot

**What it does:**
- Installs Certbot and Nginx plugin
- Obtains SSL certificate from Let's Encrypt
- Configures auto-renewal (90-day cycle)
- Updates Nginx with security headers for A+ SSL Labs rating

**Usage:**
```bash
wget https://ariashaw.github.io/scripts/aws-security/setup-ssl-certbot.sh
chmod +x setup-ssl-certbot.sh
sudo ./setup-ssl-certbot.sh <DOMAIN> <EMAIL>
```

**Example:**
```bash
sudo ./setup-ssl-certbot.sh odoo.example.com admin@example.com
```

**Prerequisites:**
- Ubuntu/Debian system with Nginx installed
- Domain DNS pointing to server IP
- Port 80 accessible from internet

---

### 6. CloudWatch Monitoring Setup

**File:** [setup-cloudwatch-monitoring.sh](setup-cloudwatch-monitoring.sh)

**Purpose:** Installs CloudWatch Agent and configures alarms

**What it does:**
- Installs CloudWatch Agent
- Configures metrics collection (CPU, memory, disk)
- Sets up log forwarding (Odoo, Nginx)
- Creates CloudWatch alarms for critical metrics

**Usage:**
```bash
wget https://ariashaw.github.io/scripts/aws-security/setup-cloudwatch-monitoring.sh
chmod +x setup-cloudwatch-monitoring.sh
sudo ./setup-cloudwatch-monitoring.sh <RDS_IDENTIFIER> <SNS_TOPIC_ARN>
```

**Example:**
```bash
sudo ./setup-cloudwatch-monitoring.sh odoo-production-db arn:aws:sns:us-east-1:123456789012:odoo-alerts
```

---

### 7. GuardDuty Threat Detection

**File:** [setup-guardduty.sh](setup-guardduty.sh)

**Purpose:** Enables AWS GuardDuty for threat detection

**What it does:**
- Enables GuardDuty in specified region
- Creates EventBridge rule for HIGH severity findings
- Connects findings to SNS topic for alerting

**Usage:**
```bash
wget https://ariashaw.github.io/scripts/aws-security/setup-guardduty.sh
chmod +x setup-guardduty.sh
./setup-guardduty.sh <SNS_TOPIC_ARN>
```

**Example:**
```bash
./setup-guardduty.sh arn:aws:sns:us-east-1:123456789012:odoo-security-alerts
```

**Threats detected:**
- Brute-force SSH attempts
- Cryptocurrency mining
- Data exfiltration
- Compromised credentials
- Malware detection

---

### 8. Incident Response Playbook

**File:** [incident-response-playbook.sh](incident-response-playbook.sh)

**Purpose:** Interactive incident response for common AWS security incidents

**Scenarios covered:**
1. Compromised AWS credentials
2. RDS data breach
3. EC2 instance compromise
4. S3 bucket public access

**Usage:**
```bash
wget https://ariashaw.github.io/scripts/aws-security/incident-response-playbook.sh
chmod +x incident-response-playbook.sh
./incident-response-playbook.sh
```

⚠️ **WARNING:** Only run during active security incidents. This script performs destructive actions.

---

## 🔐 Configuration Files

### `odoo-ec2-policy.json`

IAM policy template with minimal required permissions for Odoo EC2 instances.

**Download:**
```bash
wget https://ariashaw.github.io/scripts/aws-security/odoo-ec2-policy.json
```

**Customize:**
- Replace `odoo-filestore-bucket` with your S3 bucket name
- Update `ACCOUNT_ID` with your AWS account ID
- Adjust Secrets Manager secret name if different

---

### `cloudwatch-config.json`

CloudWatch Agent configuration for Odoo monitoring.

**Download:**
```bash
wget https://ariashaw.github.io/scripts/aws-security/cloudwatch-config.json
sudo mv cloudwatch-config.json /opt/aws/amazon-cloudwatch-agent/etc/config.json
```

**What it collects:**
- Metrics: CPU, memory, disk, network stats
- Logs: Odoo application, Nginx access/error logs
- Namespace: `Odoo/Production`

---

### `nginx-ssl.conf`

Nginx configuration template for A+ SSL Labs rating.

**Download:**
```bash
wget https://ariashaw.github.io/scripts/aws-security/nginx-ssl.conf
```

**Features:**
- TLS 1.3 + 1.2 protocols
- Strong cipher suites (GCM only)
- OCSP stapling
- Security headers (HSTS, X-Frame-Options, etc.)
- Gzip compression
- Static asset caching

**Setup:**
```bash
sudo cp nginx-ssl.conf /etc/nginx/sites-available/odoo
# Update: server_name, ssl_certificate paths, upstream odoo port
sudo ln -s /etc/nginx/sites-available/odoo /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

---

## 📚 Related Documentation

For detailed explanations and security best practices, see:
- [Odoo AWS Security Hardening Guide](/odoo-aws-security-hardening/)
- [Odoo AWS Deployment Guide](/odoo-aws-deployment-guide/)
- [Odoo AWS Architecture Guide](/odoo-aws-architecture-design-guide/)

---

## ⚠️ Security Warnings

1. **SSH Access:** Default scripts allow SSH from 0.0.0.0/0. **Update with your IP immediately** after running scripts.
2. **Secrets:** Never hardcode passwords in scripts. Use AWS Secrets Manager.
3. **Review First:** Always review scripts before running in production.
4. **Test:** Run in non-production environment first.

---

## 🤝 Contributing

Found a bug or have an improvement? [Open an issue](https://github.com/AriaShaw/AriaShaw.github.io/issues).

---

## 📄 License

MIT License - Free to use and modify for your Odoo deployments.

**Author:** Aria Shaw (Digital Plumber)
**Website:** https://ariashaw.github.io
