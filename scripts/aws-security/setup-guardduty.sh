#!/bin/bash

################################################################################
# Odoo AWS GuardDuty Setup
#
# Description:
#   Enables AWS GuardDuty threat detection and configures alerts for
#   high-severity findings via EventBridge and SNS.
#
# What this script does:
#   - Enables GuardDuty in specified region
#   - Creates EventBridge rule for HIGH severity findings
#   - Connects findings to SNS topic for alerting
#
# Usage:
#   ./setup-guardduty.sh <SNS_TOPIC_ARN>
#
# Example:
#   ./setup-guardduty.sh arn:aws:sns:us-east-1:123456789012:odoo-security-alerts
#
# Prerequisites:
#   - AWS CLI configured with credentials
#   - IAM permissions: guardduty:*, events:*, sns:*
#   - SNS topic created for security alerts
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
if [ $# -ne 1 ]; then
  echo -e "${RED}Usage: $0 <SNS_TOPIC_ARN>${NC}"
  echo ""
  echo "Example:"
  echo "  $0 arn:aws:sns:us-east-1:123456789012:odoo-security-alerts"
  echo ""
  echo "To create SNS topic:"
  echo "  aws sns create-topic --name odoo-security-alerts"
  exit 1
fi

SNS_TOPIC_ARN=$1
REGION="us-east-1"

echo -e "${GREEN}==== Odoo AWS GuardDuty Setup ====${NC}\n"
echo "SNS Topic: ${SNS_TOPIC_ARN}"
echo "Region: ${REGION}"
echo ""

# Step 1: Enable GuardDuty
echo -e "${YELLOW}[1/3] Enabling GuardDuty...${NC}"

DETECTOR_ID=$(aws guardduty create-detector \
  --enable \
  --region "$REGION" \
  --query 'DetectorId' \
  --output text 2>/dev/null || \
  aws guardduty list-detectors \
    --region "$REGION" \
    --query 'DetectorIds[0]' \
    --output text)

if [ -z "$DETECTOR_ID" ]; then
  echo -e "${RED}Failed to enable GuardDuty${NC}"
  exit 1
fi

echo -e "GuardDuty Detector: ${GREEN}${DETECTOR_ID}${NC}\n"

# Step 2: Create EventBridge Rule
echo -e "${YELLOW}[2/3] Creating EventBridge rule for HIGH severity findings...${NC}"

aws events put-rule \
  --name odoo-guardduty-high \
  --description "GuardDuty HIGH severity findings for Odoo" \
  --event-pattern '{
    "source": ["aws.guardduty"],
    "detail-type": ["GuardDuty Finding"],
    "detail": {"severity": [7, 8, 9]}
  }' \
  --state ENABLED \
  --region "$REGION"

echo -e "${GREEN}✓ EventBridge rule created${NC}\n"

# Step 3: Add SNS Target
echo -e "${YELLOW}[3/3] Connecting EventBridge to SNS...${NC}"

aws events put-targets \
  --rule odoo-guardduty-high \
  --targets "Id=1,Arn=${SNS_TOPIC_ARN}" \
  --region "$REGION"

# Add EventBridge permission to publish to SNS (if not already added)
aws sns set-topic-attributes \
  --topic-arn "$SNS_TOPIC_ARN" \
  --attribute-name Policy \
  --attribute-value "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [{
      \"Effect\": \"Allow\",
      \"Principal\": {\"Service\": \"events.amazonaws.com\"},
      \"Action\": \"sns:Publish\",
      \"Resource\": \"${SNS_TOPIC_ARN}\"
    }]
  }" \
  --region "$REGION" 2>/dev/null || true

echo -e "${GREEN}✓ SNS target configured${NC}\n"

# Output Summary
echo -e "${GREEN}==== Setup Complete ====${NC}\n"
echo "GuardDuty Detector: ${DETECTOR_ID}"
echo "EventBridge Rule: odoo-guardduty-high"
echo "Alert Destination: ${SNS_TOPIC_ARN}"
echo ""
echo -e "${YELLOW}Common Threats GuardDuty Detects:${NC}"
echo "  • Brute-force SSH attempts (Recon:EC2/SSHBruteForce)"
echo "  • Cryptocurrency mining (CryptoCurrency:EC2/BitcoinTool.B!DNS)"
echo "  • Data exfiltration (Exfiltration:S3/ObjectRead.Unusual)"
echo "  • Compromised credentials (UnauthorizedAccess:IAMUser/*)"
echo "  • Malware detection (Execution:EC2/MaliciousFile)"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Subscribe to SNS topic for email alerts:"
echo "   aws sns subscribe --topic-arn ${SNS_TOPIC_ARN} --protocol email --notification-endpoint your-email@example.com"
echo ""
echo "2. View GuardDuty findings:"
echo "   https://console.aws.amazon.com/guardduty/home?region=${REGION}#/findings"
echo ""
echo "3. Test alert (simulate finding):"
echo "   aws guardduty create-sample-findings --detector-id ${DETECTOR_ID} --finding-types Recon:EC2/PortProbeUnprotectedPort"
echo ""
echo "4. Disable GuardDuty (if needed):"
echo "   aws guardduty delete-detector --detector-id ${DETECTOR_ID}"
echo ""
