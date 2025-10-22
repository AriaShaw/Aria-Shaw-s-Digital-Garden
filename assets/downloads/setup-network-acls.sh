#!/bin/bash

################################################################################
# Odoo AWS Network ACLs Setup (Optional Security Layer)
#
# Description:
#   Creates Network ACLs for additional defense layer beyond security groups.
#   Recommended for compliance requirements (PCI-DSS, HIPAA, SOC2).
#
# What this script creates:
#   - Public subnet NACL (allows HTTP/HTTPS, ephemeral ports)
#   - Private subnet NACL (allows PostgreSQL from public subnet only)
#
# Usage:
#   ./setup-network-acls.sh <VPC_ID> <PUBLIC_SUBNET_ID> <PRIVATE_SUBNET_ID>
#
# Example:
#   ./setup-network-acls.sh vpc-0abc123 subnet-0public123 subnet-0private456
#
# Prerequisites:
#   - VPC and subnets already created
#   - AWS CLI configured with credentials
#   - IAM permissions: ec2:CreateNetworkAcl*, ec2:AssociateNetworkAcl
#
# When to use:
#   ✅ Compliance requirement (PCI-DSS, HIPAA)
#   ✅ DDoS mitigation (block IP ranges)
#   ✅ Defense against compromised security groups
#
# When to skip:
#   ❌ Tier 1 deployments (security groups sufficient)
#   ❌ Non-regulated industries
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
  echo -e "${RED}Usage: $0 <VPC_ID> <PUBLIC_SUBNET_ID> <PRIVATE_SUBNET_ID>${NC}"
  echo ""
  echo "Example:"
  echo "  $0 vpc-0abc123 subnet-0public123 subnet-0private456"
  exit 1
fi

VPC_ID=$1
PUBLIC_SUBNET_ID=$2
PRIVATE_SUBNET_ID=$3
REGION="us-east-1"

echo -e "${GREEN}==== Odoo AWS Network ACLs Setup ====${NC}\n"
echo "VPC: ${VPC_ID}"
echo "Public Subnet: ${PUBLIC_SUBNET_ID}"
echo "Private Subnet: ${PRIVATE_SUBNET_ID}"
echo ""

# Step 1: Create Public Subnet NACL
echo -e "${YELLOW}[1/4] Creating public subnet NACL...${NC}"
PUBLIC_NACL_ID=$(aws ec2 create-network-acl \
  --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=network-acl,Tags=[{Key=Name,Value=odoo-public-nacl}]' \
  --region $REGION \
  --query 'NetworkAcl.NetworkAclId' \
  --output text)
echo -e "Public NACL created: ${GREEN}${PUBLIC_NACL_ID}${NC}\n"

# Step 2: Configure Public NACL Rules
echo -e "${YELLOW}[2/4] Configuring public NACL rules...${NC}"

# Inbound Rules
# Allow HTTPS (443)
aws ec2 create-network-acl-entry \
  --network-acl-id $PUBLIC_NACL_ID \
  --rule-number 100 \
  --protocol 6 \
  --port-range From=443,To=443 \
  --cidr-block 0.0.0.0/0 \
  --ingress \
  --rule-action allow \
  --region $REGION

# Allow HTTP (80)
aws ec2 create-network-acl-entry \
  --network-acl-id $PUBLIC_NACL_ID \
  --rule-number 110 \
  --protocol 6 \
  --port-range From=80,To=80 \
  --cidr-block 0.0.0.0/0 \
  --ingress \
  --rule-action allow \
  --region $REGION

# Allow SSH (22) - restrict to your IP if needed
aws ec2 create-network-acl-entry \
  --network-acl-id $PUBLIC_NACL_ID \
  --rule-number 120 \
  --protocol 6 \
  --port-range From=22,To=22 \
  --cidr-block 0.0.0.0/0 \
  --ingress \
  --rule-action allow \
  --region $REGION

# Allow return traffic (ephemeral ports 1024-65535)
aws ec2 create-network-acl-entry \
  --network-acl-id $PUBLIC_NACL_ID \
  --rule-number 130 \
  --protocol 6 \
  --port-range From=1024,To=65535 \
  --cidr-block 0.0.0.0/0 \
  --ingress \
  --rule-action allow \
  --region $REGION

# Outbound Rules
# Allow all outbound (can be restricted based on compliance needs)
aws ec2 create-network-acl-entry \
  --network-acl-id $PUBLIC_NACL_ID \
  --rule-number 100 \
  --protocol -1 \
  --cidr-block 0.0.0.0/0 \
  --egress \
  --rule-action allow \
  --region $REGION

echo -e "${GREEN}✓ Public NACL rules configured${NC}\n"

# Step 3: Create Private Subnet NACL
echo -e "${YELLOW}[3/4] Creating private subnet NACL...${NC}"
PRIVATE_NACL_ID=$(aws ec2 create-network-acl \
  --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=network-acl,Tags=[{Key=Name,Value=odoo-private-nacl}]' \
  --region $REGION \
  --query 'NetworkAcl.NetworkAclId' \
  --output text)
echo -e "Private NACL created: ${GREEN}${PRIVATE_NACL_ID}${NC}\n"

# Step 4: Configure Private NACL Rules
echo -e "${YELLOW}[4/4] Configuring private NACL rules...${NC}"

# Inbound Rules
# Allow PostgreSQL (5432) from public subnet only
aws ec2 create-network-acl-entry \
  --network-acl-id $PRIVATE_NACL_ID \
  --rule-number 100 \
  --protocol 6 \
  --port-range From=5432,To=5432 \
  --cidr-block 10.0.1.0/24 \
  --ingress \
  --rule-action allow \
  --region $REGION

# Allow return traffic (ephemeral ports)
aws ec2 create-network-acl-entry \
  --network-acl-id $PRIVATE_NACL_ID \
  --rule-number 110 \
  --protocol 6 \
  --port-range From=1024,To=65535 \
  --cidr-block 10.0.1.0/24 \
  --ingress \
  --rule-action allow \
  --region $REGION

# Outbound Rules
# Allow all outbound to VPC
aws ec2 create-network-acl-entry \
  --network-acl-id $PRIVATE_NACL_ID \
  --rule-number 100 \
  --protocol -1 \
  --cidr-block 10.0.0.0/16 \
  --egress \
  --rule-action allow \
  --region $REGION

# Allow outbound HTTPS for updates (via NAT Gateway)
aws ec2 create-network-acl-entry \
  --network-acl-id $PRIVATE_NACL_ID \
  --rule-number 110 \
  --protocol 6 \
  --port-range From=443,To=443 \
  --cidr-block 0.0.0.0/0 \
  --egress \
  --rule-action allow \
  --region $REGION

echo -e "${GREEN}✓ Private NACL rules configured${NC}\n"

# Associate NACLs with subnets
echo -e "${YELLOW}Associating NACLs with subnets...${NC}"

# Get current associations to replace them
PUBLIC_ASSOC_ID=$(aws ec2 describe-network-acls \
  --filters "Name=association.subnet-id,Values=$PUBLIC_SUBNET_ID" \
  --region $REGION \
  --query 'NetworkAcls[0].Associations[?SubnetId==`'$PUBLIC_SUBNET_ID'`].NetworkAclAssociationId' \
  --output text)

PRIVATE_ASSOC_ID=$(aws ec2 describe-network-acls \
  --filters "Name=association.subnet-id,Values=$PRIVATE_SUBNET_ID" \
  --region $REGION \
  --query 'NetworkAcls[0].Associations[?SubnetId==`'$PRIVATE_SUBNET_ID'`].NetworkAclAssociationId' \
  --output text)

# Replace associations
aws ec2 replace-network-acl-association \
  --association-id $PUBLIC_ASSOC_ID \
  --network-acl-id $PUBLIC_NACL_ID \
  --region $REGION

aws ec2 replace-network-acl-association \
  --association-id $PRIVATE_ASSOC_ID \
  --network-acl-id $PRIVATE_NACL_ID \
  --region $REGION

echo -e "${GREEN}✓ NACLs associated with subnets${NC}\n"

# Output Summary
echo -e "${GREEN}==== Setup Complete ====${NC}\n"
echo "Public NACL:  ${PUBLIC_NACL_ID}"
echo "Private NACL: ${PRIVATE_NACL_ID}"
echo ""
echo -e "${YELLOW}Network ACL Rules Summary:${NC}"
echo ""
echo "Public Subnet (${PUBLIC_SUBNET_ID}):"
echo "  Inbound:  HTTP/HTTPS/SSH + ephemeral ports"
echo "  Outbound: All traffic"
echo ""
echo "Private Subnet (${PRIVATE_SUBNET_ID}):"
echo "  Inbound:  PostgreSQL (5432) from 10.0.1.0/24 only"
echo "  Outbound: VPC traffic + HTTPS for updates"
echo ""
echo -e "${GREEN}Validation:${NC}"
echo "  aws ec2 describe-network-acls --network-acl-ids $PUBLIC_NACL_ID $PRIVATE_NACL_ID"
echo ""
