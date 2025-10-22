#!/bin/bash
#
# Odoo AWS Security: VPC & Security Groups Setup
#
# Description:
#   Creates production-ready VPC with public/private subnets and security groups
#   for Odoo deployment on AWS. Implements least-privilege network isolation.
#
# Usage:
#   ./setup-vpc-security-groups.sh
#
# Prerequisites:
#   - AWS CLI configured with appropriate credentials
#   - jq installed for JSON parsing
#
# Author: Aria Shaw (Digital Plumber)
# License: MIT
# Version: 1.0.0

set -e  # Exit on error
set -u  # Exit on undefined variable

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check prerequisites
command -v aws >/dev/null 2>&1 || error "AWS CLI not installed"
command -v jq >/dev/null 2>&1 || error "jq not installed"

info "Starting VPC and Security Groups setup for Odoo..."

# Step 1: Create VPC
info "Creating VPC (10.0.0.0/16)..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=odoo-production-vpc}]' \
  --query 'Vpc.VpcId' \
  --output text)

if [ -z "$VPC_ID" ]; then
    error "Failed to create VPC"
fi

info "VPC created: $VPC_ID"

# Enable DNS hostnames
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames
info "DNS hostnames enabled"

# Step 2: Create Internet Gateway
info "Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=odoo-igw}]' \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)

aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID"
info "Internet Gateway attached: $IGW_ID"

# Step 3: Create Subnets
info "Creating public subnet (10.0.1.0/24)..."
PUBLIC_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.0.1.0/24 \
  --availability-zone us-east-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=odoo-public-subnet-1a}]' \
  --query 'Subnet.SubnetId' \
  --output text)

info "Public subnet created: $PUBLIC_SUBNET_ID"

info "Creating private subnet (10.0.2.0/24)..."
PRIVATE_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block 10.0.2.0/24 \
  --availability-zone us-east-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=odoo-private-subnet-1a}]' \
  --query 'Subnet.SubnetId' \
  --output text)

info "Private subnet created: $PRIVATE_SUBNET_ID"

# Step 4: Create and configure route tables
info "Creating public route table..."
PUBLIC_RT_ID=$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=odoo-public-rt}]' \
  --query 'RouteTable.RouteTableId' \
  --output text)

# Add route to Internet Gateway
aws ec2 create-route \
  --route-table-id "$PUBLIC_RT_ID" \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id "$IGW_ID"

# Associate with public subnet
aws ec2 associate-route-table \
  --subnet-id "$PUBLIC_SUBNET_ID" \
  --route-table-id "$PUBLIC_RT_ID"

info "Public route table configured: $PUBLIC_RT_ID"

# Step 5: Create Security Groups
info "Creating Application Load Balancer security group..."
ALB_SG_ID=$(aws ec2 create-security-group \
  --group-name odoo-alb-sg \
  --description "Security group for Odoo Application Load Balancer" \
  --vpc-id "$VPC_ID" \
  --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=odoo-alb-sg}]' \
  --query 'GroupId' \
  --output text)

# Allow HTTPS from internet
aws ec2 authorize-security-group-ingress \
  --group-id "$ALB_SG_ID" \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0

# Allow HTTP (for redirect to HTTPS)
aws ec2 authorize-security-group-ingress \
  --group-id "$ALB_SG_ID" \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

info "ALB security group created: $ALB_SG_ID"

info "Creating EC2 application server security group..."
EC2_SG_ID=$(aws ec2 create-security-group \
  --group-name odoo-ec2-sg \
  --description "Security group for Odoo EC2 instances" \
  --vpc-id "$VPC_ID" \
  --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=odoo-ec2-sg}]' \
  --query 'GroupId' \
  --output text)

# Allow traffic from ALB only
aws ec2 authorize-security-group-ingress \
  --group-id "$EC2_SG_ID" \
  --protocol tcp \
  --port 8069 \
  --source-group "$ALB_SG_ID"

# Allow SSH from your IP (REPLACE WITH YOUR IP)
warn "IMPORTANT: Update SSH rule with your IP address!"
warn "Current rule allows SSH from 0.0.0.0/0 - INSECURE!"
aws ec2 authorize-security-group-ingress \
  --group-id "$EC2_SG_ID" \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

info "EC2 security group created: $EC2_SG_ID"

info "Creating RDS database security group..."
DB_SG_ID=$(aws ec2 create-security-group \
  --group-name odoo-rds-sg \
  --description "Security group for Odoo RDS database" \
  --vpc-id "$VPC_ID" \
  --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=odoo-rds-sg}]' \
  --query 'GroupId' \
  --output text)

# Allow PostgreSQL from EC2 only
aws ec2 authorize-security-group-ingress \
  --group-id "$DB_SG_ID" \
  --protocol tcp \
  --port 5432 \
  --source-group "$EC2_SG_ID"

info "RDS security group created: $DB_SG_ID"

# Step 6: Output summary
echo ""
info "========================================="
info "VPC and Security Groups Setup Complete!"
info "========================================="
echo ""
echo "VPC ID:              $VPC_ID"
echo "Internet Gateway:    $IGW_ID"
echo "Public Subnet:       $PUBLIC_SUBNET_ID"
echo "Private Subnet:      $PRIVATE_SUBNET_ID"
echo "Public Route Table:  $PUBLIC_RT_ID"
echo ""
echo "Security Groups:"
echo "  ALB:  $ALB_SG_ID (ports 80, 443 from 0.0.0.0/0)"
echo "  EC2:  $EC2_SG_ID (port 8069 from ALB, SSH from 0.0.0.0/0)"
echo "  RDS:  $DB_SG_ID (port 5432 from EC2 only)"
echo ""
warn "NEXT STEPS:"
warn "1. Update EC2 security group SSH rule with your IP:"
warn "   aws ec2 revoke-security-group-ingress --group-id $EC2_SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0"
warn "   aws ec2 authorize-security-group-ingress --group-id $EC2_SG_ID --protocol tcp --port 22 --cidr YOUR.IP.ADDRESS.HERE/32"
warn "2. Save these IDs for deployment scripts"
warn "3. Verify security group rules:"
warn "   aws ec2 describe-security-groups --group-ids $ALB_SG_ID $EC2_SG_ID $DB_SG_ID"
echo ""
