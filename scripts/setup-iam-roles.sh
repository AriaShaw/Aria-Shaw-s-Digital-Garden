#!/bin/bash

################################################################################
# Odoo AWS IAM Roles & Policies Setup
#
# Description:
#   Creates IAM roles and policies for Odoo EC2 instances with least-privilege
#   permissions. Eliminates hardcoded credentials.
#
# What this script creates:
#   - IAM policy with S3, Secrets Manager, and CloudWatch permissions
#   - IAM role for EC2 with trust policy
#   - Instance profile for EC2 attachment
#
# Usage:
#   ./setup-iam-roles.sh <S3_BUCKET_NAME> <SECRET_NAME> <AWS_ACCOUNT_ID>
#
# Example:
#   ./setup-iam-roles.sh odoo-filestore-bucket odoo/db/password 123456789012
#
# Prerequisites:
#   - AWS CLI configured with credentials
#   - IAM permissions: iam:CreatePolicy, iam:CreateRole, iam:CreateInstanceProfile
#   - S3 bucket and Secrets Manager secret already created
#
# Output:
#   Instance Profile ARN to attach to EC2 instances
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
if [ $# -ne 3 ]; then
  echo -e "${RED}Usage: $0 <S3_BUCKET_NAME> <SECRET_NAME> <AWS_ACCOUNT_ID>${NC}"
  echo ""
  echo "Example:"
  echo "  $0 odoo-filestore-bucket odoo/db/password 123456789012"
  echo ""
  echo "To get your AWS Account ID:"
  echo "  aws sts get-caller-identity --query Account --output text"
  exit 1
fi

S3_BUCKET=$1
SECRET_NAME=$2
ACCOUNT_ID=$3
REGION="us-east-1"

echo -e "${GREEN}==== Odoo AWS IAM Roles & Policies Setup ====${NC}\n"
echo "S3 Bucket: ${S3_BUCKET}"
echo "Secret Name: ${SECRET_NAME}"
echo "Account ID: ${ACCOUNT_ID}"
echo ""

# Step 1: Create IAM Policy
echo -e "${YELLOW}[1/5] Creating IAM policy...${NC}"

# Generate policy document
cat > /tmp/odoo-ec2-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3FilestoreAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::${S3_BUCKET}/*"
    },
    {
      "Sid": "S3ListBucket",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": "arn:aws:s3:::${S3_BUCKET}"
    },
    {
      "Sid": "SecretsManagerRead",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:${REGION}:${ACCOUNT_ID}:secret:${SECRET_NAME}-*"
    },
    {
      "Sid": "CloudWatchLogs",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ],
      "Resource": "arn:aws:logs:${REGION}:${ACCOUNT_ID}:log-group:/aws/ec2/odoo:*"
    },
    {
      "Sid": "CloudWatchMetrics",
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricData"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "cloudwatch:namespace": "Odoo/Production"
        }
      }
    }
  ]
}
EOF

# Create policy
POLICY_ARN=$(aws iam create-policy \
  --policy-name OdooEC2Policy \
  --policy-document file:///tmp/odoo-ec2-policy.json \
  --description "Least-privilege policy for Odoo EC2 instances" \
  --query 'Policy.Arn' \
  --output text 2>/dev/null || \
  aws iam list-policies --scope Local \
    --query "Policies[?PolicyName=='OdooEC2Policy'].Arn" \
    --output text)

echo -e "IAM Policy: ${GREEN}${POLICY_ARN}${NC}\n"

# Step 2: Create IAM Role
echo -e "${YELLOW}[2/5] Creating IAM role...${NC}"

# Create trust policy
cat > /tmp/trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create role
ROLE_ARN=$(aws iam create-role \
  --role-name OdooEC2Role \
  --assume-role-policy-document file:///tmp/trust-policy.json \
  --description "IAM role for Odoo EC2 instances" \
  --query 'Role.Arn' \
  --output text 2>/dev/null || \
  aws iam get-role --role-name OdooEC2Role --query 'Role.Arn' --output text)

echo -e "IAM Role: ${GREEN}${ROLE_ARN}${NC}\n"

# Step 3: Attach Policy to Role
echo -e "${YELLOW}[3/5] Attaching policy to role...${NC}"
aws iam attach-role-policy \
  --role-name OdooEC2Role \
  --policy-arn $POLICY_ARN 2>/dev/null || echo "Policy already attached"

echo -e "${GREEN}✓ Policy attached${NC}\n"

# Step 4: Create Instance Profile
echo -e "${YELLOW}[4/5] Creating instance profile...${NC}"
PROFILE_ARN=$(aws iam create-instance-profile \
  --instance-profile-name OdooEC2InstanceProfile \
  --query 'InstanceProfile.Arn' \
  --output text 2>/dev/null || \
  aws iam get-instance-profile \
    --instance-profile-name OdooEC2InstanceProfile \
    --query 'InstanceProfile.Arn' \
    --output text)

echo -e "Instance Profile: ${GREEN}${PROFILE_ARN}${NC}\n"

# Step 5: Add Role to Instance Profile
echo -e "${YELLOW}[5/5] Adding role to instance profile...${NC}"
aws iam add-role-to-instance-profile \
  --instance-profile-name OdooEC2InstanceProfile \
  --role-name OdooEC2Role 2>/dev/null || echo "Role already in profile"

echo -e "${GREEN}✓ Role added to instance profile${NC}\n"

# Clean up temp files
rm -f /tmp/odoo-ec2-policy.json /tmp/trust-policy.json

# Output Summary
echo -e "${GREEN}==== Setup Complete ====${NC}\n"
echo "Policy ARN:           ${POLICY_ARN}"
echo "Role ARN:             ${ROLE_ARN}"
echo "Instance Profile ARN: ${PROFILE_ARN}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Attach instance profile to NEW EC2 instance during launch:"
echo "   aws ec2 run-instances \\"
echo "     --iam-instance-profile Name=OdooEC2InstanceProfile \\"
echo "     --image-id ami-xxxxx --instance-type t3.medium ..."
echo ""
echo "2. Attach instance profile to EXISTING EC2 instance:"
echo "   aws ec2 associate-iam-instance-profile \\"
echo "     --instance-id i-0your-instance-id \\"
echo "     --iam-instance-profile Name=OdooEC2InstanceProfile"
echo ""
echo "3. Verify instance has profile:"
echo "   aws ec2 describe-instances \\"
echo "     --instance-ids i-0your-instance-id \\"
echo "     --query 'Reservations[0].Instances[0].IamInstanceProfile'"
echo ""
echo -e "${GREEN}Permissions Granted:${NC}"
echo "  ✓ S3: Read/write to ${S3_BUCKET}"
echo "  ✓ Secrets Manager: Read ${SECRET_NAME}"
echo "  ✓ CloudWatch: Logs and metrics to Odoo/Production namespace"
echo ""
