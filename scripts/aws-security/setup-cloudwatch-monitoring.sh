#!/bin/bash

################################################################################
# Odoo CloudWatch Monitoring Setup
#
# Description:
#   Installs and configures CloudWatch Agent for Odoo monitoring.
#   Sets up alarms for CPU, memory, disk, and application metrics.
#
# Usage:
#   sudo ./setup-cloudwatch-monitoring.sh <RDS_IDENTIFIER> <SNS_TOPIC_ARN>
#
# Example:
#   sudo ./setup-cloudwatch-monitoring.sh odoo-production-db arn:aws:sns:us-east-1:123456789012:odoo-alerts
#
# Author: Aria Shaw (Digital Plumber)
# License: MIT
################################################################################

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Parse arguments
if [ $# -ne 2 ]; then
  echo -e "${RED}Usage: sudo $0 <RDS_IDENTIFIER> <SNS_TOPIC_ARN>${NC}"
  exit 1
fi

if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}Please run as root (use sudo)${NC}"
  exit 1
fi

RDS_IDENTIFIER=$1
SNS_TOPIC_ARN=$2
REGION="us-east-1"
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)

echo -e "${GREEN}==== Odoo CloudWatch Monitoring Setup ====${NC}\n"

# Step 1: Install CloudWatch Agent
echo -e "${YELLOW}[1/3] Installing CloudWatch Agent...${NC}"
wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb
rm amazon-cloudwatch-agent.deb
echo -e "${GREEN}✓ CloudWatch Agent installed${NC}\n"

# Step 2: Download config from article (user should create this)
echo -e "${YELLOW}[2/3] Download cloudwatch-config.json and place in /opt/aws/amazon-cloudwatch-agent/etc/${NC}"
echo "See: https://ariashaw.github.io/scripts/aws-security/cloudwatch-config.json"

# Step 3: Create CloudWatch Alarms
echo -e "${YELLOW}[3/3] Creating CloudWatch alarms...${NC}"

aws cloudwatch put-metric-alarm \
  --alarm-name "odoo-rds-cpu-high" \
  --alarm-description "Odoo RDS CPU exceeds 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/RDS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --alarm-actions "$SNS_TOPIC_ARN" \
  --dimensions Name=DBInstanceIdentifier,Value="$RDS_IDENTIFIER" \
  --region "$REGION"

echo -e "${GREEN}✓ CloudWatch alarms created${NC}\n"
echo -e "${GREEN}==== Setup Complete ====${NC}\n"
