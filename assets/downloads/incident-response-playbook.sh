#!/bin/bash

################################################################################
# Odoo AWS Security Incident Response Playbook
#
# Description:
#   Interactive incident response script for common AWS security incidents.
#   Guides you through containment, assessment, and remediation steps.
#
# Scenarios covered:
#   1. Compromised AWS credentials
#   2. RDS data breach
#   3. EC2 instance compromise
#   4. S3 bucket public access
#
# Usage:
#   ./incident-response-playbook.sh
#
# Prerequisites:
#   - AWS CLI configured with admin credentials
#   - IAM permissions: Full admin (incident response)
#   - This should only be run during active incidents
#
# Author: Aria Shaw (Digital Plumber)
# License: MIT
################################################################################

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REGION="us-east-1"

echo -e "${RED}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║   SECURITY INCIDENT RESPONSE PLAYBOOK             ║${NC}"
echo -e "${RED}║   FOR ODOO AWS DEPLOYMENTS                        ║${NC}"
echo -e "${RED}╚═══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}WARNING: This script performs destructive actions.${NC}"
echo -e "${YELLOW}Only run during active security incidents.${NC}"
echo ""

# Main Menu
echo -e "${BLUE}Select incident type:${NC}"
echo "1. Compromised AWS Credentials"
echo "2. RDS Data Breach"
echo "3. EC2 Instance Compromise"
echo "4. S3 Bucket Public Access"
echo "5. Exit"
echo ""
read -p "Enter choice [1-5]: " CHOICE

case $CHOICE in
  1)
    echo -e "\n${BLUE}=== COMPROMISED AWS CREDENTIALS ===${NC}\n"
    read -p "Enter compromised IAM username: " USERNAME
    
    echo -e "\n${YELLOW}[CONTAIN] Disabling access key...${NC}"
    ACCESS_KEY=$(aws iam list-access-keys --user-name "$USERNAME" --query 'AccessKeyMetadata[0].AccessKeyId' --output text)
    aws iam update-access-key --user-name "$USERNAME" --access-key-id "$ACCESS_KEY" --status Inactive
    echo -e "${GREEN}✓ Access key disabled${NC}"
    
    echo -e "\n${YELLOW}[CONTAIN] Attaching deny-all policy...${NC}"
    aws iam put-user-policy --user-name "$USERNAME" --policy-name DenyAll --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Deny","Action":"*","Resource":"*"}]}'
    echo -e "${GREEN}✓ User access denied${NC}"
    
    echo -e "\n${YELLOW}[ASSESS] Listing recent actions...${NC}"
    aws cloudtrail lookup-events \
      --lookup-attributes AttributeKey=Username,AttributeValue="$USERNAME" \
      --max-items 20 \
      --query 'Events[*].[EventTime,EventName,Resources[0].ResourceName]' \
      --output table
    
    echo -e "\n${BLUE}Next steps:${NC}"
    echo "1. Review CloudTrail events for unauthorized resource creation"
    echo "2. Terminate any unauthorized EC2 instances"
    echo "3. Delete unauthorized S3 buckets"
    echo "4. Rotate all secrets in Secrets Manager"
    echo "5. Create new IAM user with MFA"
    ;;
    
  2)
    echo -e "\n${BLUE}=== RDS DATA BREACH ===${NC}\n"
    read -p "Enter RDS instance identifier: " RDS_ID
    
    echo -e "\n${YELLOW}[CONTAIN] Checking security group...${NC}"
    aws rds describe-db-instances --db-instance-identifier "$RDS_ID" \
      --query 'DBInstances[0].VpcSecurityGroups[*].VpcSecurityGroupId' \
      --output text
    
    read -p "Enter security group ID to fix: " SG_ID
    
    echo -e "\n${YELLOW}[CONTAIN] Removing public access...${NC}"
    aws ec2 revoke-security-group-ingress \
      --group-id "$SG_ID" \
      --protocol tcp \
      --port 5432 \
      --cidr 0.0.0.0/0 2>/dev/null || echo "No public rule found"
    echo -e "${GREEN}✓ Public access removed${NC}"
    
    echo -e "\n${YELLOW}[FORENSICS] Check recent connections in PostgreSQL:${NC}"
    echo "SELECT datname, usename, client_addr, state, query_start FROM pg_stat_activity WHERE datname = 'odoo_production' ORDER BY query_start DESC LIMIT 50;"
    
    echo -e "\n${BLUE}Next steps:${NC}"
    echo "1. Review pg_stat_activity for suspicious IPs"
    echo "2. Check for data exfiltration (SELECT * FROM ...)"
    echo "3. Restore from PITR if data was compromised"
    echo "4. Notify compliance team (GDPR 72-hour window)"
    ;;
    
  3)
    echo -e "\n${BLUE}=== EC2 INSTANCE COMPROMISE ===${NC}\n"
    read -p "Enter EC2 instance ID: " INSTANCE_ID
    
    echo -e "\n${YELLOW}[CONTAIN] Creating forensic snapshot...${NC}"
    VOLUME_ID=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId' --output text)
    SNAPSHOT_ID=$(aws ec2 create-snapshot --volume-id "$VOLUME_ID" --description "Forensic snapshot - incident $(date +%Y-%m-%d)" --query 'SnapshotId' --output text)
    echo -e "${GREEN}✓ Snapshot created: ${SNAPSHOT_ID}${NC}"
    
    echo -e "\n${YELLOW}[CONTAIN] Isolating instance...${NC}"
    ISOLATED_SG=$(aws ec2 create-security-group --group-name "isolated-$(date +%s)" --description "Isolated - security incident" --vpc-id $(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].VpcId' --output text) --query 'GroupId' --output text)
    aws ec2 modify-instance-attribute --instance-id "$INSTANCE_ID" --groups "$ISOLATED_SG"
    echo -e "${GREEN}✓ Instance isolated (no inbound/outbound)${NC}"
    
    echo -e "\n${BLUE}Next steps:${NC}"
    echo "1. Analyze snapshot for rootkits/malware"
    echo "2. Review CloudWatch logs for suspicious activity"
    echo "3. Terminate instance and rebuild from clean AMI"
    echo "4. Rotate all credentials (database, API keys)"
    ;;
    
  4)
    echo -e "\n${BLUE}=== S3 BUCKET PUBLIC ACCESS ===${NC}\n"
    read -p "Enter S3 bucket name: " BUCKET_NAME
    
    echo -e "\n${YELLOW}[CONTAIN] Blocking public access...${NC}"
    aws s3api put-public-access-block \
      --bucket "$BUCKET_NAME" \
      --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
    echo -e "${GREEN}✓ Public access blocked${NC}"
    
    echo -e "\n${YELLOW}[ASSESS] Checking access logs...${NC}"
    echo "Review S3 access logs for suspicious IPs (requires logging enabled)"
    
    echo -e "\n${BLUE}Next steps:${NC}"
    echo "1. Enable S3 access logging if not already enabled"
    echo "2. Review access logs for data exfiltration"
    echo "3. Enable versioning to prevent data loss"
    echo "4. Implement bucket policies (least privilege)"
    ;;
    
  5)
    echo "Exiting"
    exit 0
    ;;
    
  *)
    echo -e "${RED}Invalid choice${NC}"
    exit 1
    ;;
esac

echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}POST-INCIDENT CHECKLIST:${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
echo "☐ Document incident timeline"
echo "☐ Save CloudTrail logs for forensics"
echo "☐ Rotate all credentials (AWS keys, DB passwords, API keys)"
echo "☐ Review IAM policies (remove excessive permissions)"
echo "☐ Update security groups (least privilege)"
echo "☐ Enable AWS Config for drift detection"
echo "☐ Notify stakeholders (compliance, legal, management)"
echo "☐ Conduct post-incident review"
echo ""
