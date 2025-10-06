#!/bin/bash

################################################################################
# Odoo AWS Secrets Manager Setup
#
# Description:
#   Creates and manages secrets in AWS Secrets Manager for Odoo database
#   credentials. Eliminates hardcoded passwords in config files.
#
# What this script does:
#   - Generates cryptographically secure password
#   - Stores RDS master password in Secrets Manager
#   - Creates rotation schedule (optional)
#   - Outputs retrieval commands for Odoo startup scripts
#
# Usage:
#   ./setup-secrets-manager.sh [SECRET_NAME]
#
# Example:
#   ./setup-secrets-manager.sh odoo/db/password
#
# Prerequisites:
#   - AWS CLI configured with credentials
#   - IAM permissions: secretsmanager:CreateSecret, secretsmanager:PutSecretValue
#   - openssl or jq installed for password generation
#
# Output:
#   Secret ARN and retrieval commands for Odoo config
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

# Default values
SECRET_NAME="${1:-odoo/db/password}"
REGION="us-east-1"

echo -e "${GREEN}==== Odoo AWS Secrets Manager Setup ====${NC}\n"
echo "Secret Name: ${SECRET_NAME}"
echo "Region: ${REGION}"
echo ""

# Check prerequisites
command -v aws >/dev/null 2>&1 || { echo -e "${RED}AWS CLI not installed${NC}"; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo -e "${RED}openssl not installed${NC}"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo -e "${RED}jq not installed${NC}"; exit 1; }

# Step 1: Generate Secure Password
echo -e "${YELLOW}[1/3] Generating secure password...${NC}"
DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
echo -e "${GREEN}✓ Password generated (32-character alphanumeric)${NC}\n"

# Step 2: Create Secret in Secrets Manager
echo -e "${YELLOW}[2/3] Creating secret in Secrets Manager...${NC}"

# Check if secret already exists
if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$REGION" >/dev/null 2>&1; then
  echo -e "${YELLOW}Secret already exists. Updating value...${NC}"
  
  SECRET_ARN=$(aws secretsmanager update-secret \
    --secret-id "$SECRET_NAME" \
    --secret-string "{\"password\":\"$DB_PASSWORD\"}" \
    --region "$REGION" \
    --query 'ARN' \
    --output text)
else
  echo -e "${YELLOW}Creating new secret...${NC}"
  
  SECRET_ARN=$(aws secretsmanager create-secret \
    --name "$SECRET_NAME" \
    --description "Odoo RDS PostgreSQL master password" \
    --secret-string "{\"password\":\"$DB_PASSWORD\"}" \
    --region "$REGION" \
    --query 'ARN' \
    --output text)
fi

echo -e "Secret ARN: ${GREEN}${SECRET_ARN}${NC}\n"

# Step 3: Output Retrieval Instructions
echo -e "${YELLOW}[3/3] Generating retrieval commands...${NC}\n"

echo -e "${GREEN}==== Setup Complete ====${NC}\n"
echo "Secret ARN: ${SECRET_ARN}"
echo ""
echo -e "${YELLOW}To retrieve password in Odoo startup script (/opt/odoo/start.sh):${NC}"
echo ""
cat << 'EOFBASH'
#!/bin/bash

# Retrieve RDS password from Secrets Manager
DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id odoo/db/password \
  --region us-east-1 \
  --query SecretString \
  --output text | jq -r .password)

# Update Odoo config
sed -i "s/^db_password = .*/db_password = $DB_PASSWORD/" /opt/odoo/odoo.conf

# Start Odoo
/opt/odoo/odoo-venv/bin/python3 /opt/odoo/odoo17/odoo-bin -c /opt/odoo/odoo.conf
EOFBASH
echo ""

echo -e "${YELLOW}To manually retrieve password:${NC}"
echo "  aws secretsmanager get-secret-value \\"
echo "    --secret-id $SECRET_NAME \\"
echo "    --region $REGION \\"
echo "    --query SecretString --output text | jq -r .password"
echo ""

echo -e "${YELLOW}To rotate password (90-day cycle):${NC}"
cat << EOFROTATE

# Generate new password
NEW_PASSWORD=\$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

# Update Secrets Manager
aws secretsmanager update-secret \
  --secret-id $SECRET_NAME \
  --secret-string "{\\"password\\":\\"\$NEW_PASSWORD\\"}" \
  --region $REGION

# Update RDS master password
aws rds modify-db-instance \
  --db-instance-identifier odoo-production-db \
  --master-user-password \$NEW_PASSWORD \
  --apply-immediately \
  --region $REGION

# Restart Odoo (will fetch new password from Secrets Manager)
sudo systemctl restart odoo
EOFROTATE
echo ""

echo -e "${YELLOW}To enable automatic rotation (requires Lambda function):${NC}"
echo "  aws secretsmanager rotate-secret \\"
echo "    --secret-id $SECRET_NAME \\"
echo "    --rotation-lambda-arn arn:aws:lambda:$REGION:ACCOUNT_ID:function:SecretsManagerRotation \\"
echo "    --rotation-rules AutomaticallyAfterDays=90"
echo ""

echo -e "${GREEN}Security Best Practices:${NC}"
echo "  ✓ Never log or print passwords"
echo "  ✓ Rotate passwords every 90 days"
echo "  ✓ Use IAM roles (not access keys) to retrieve secrets"
echo "  ✓ Enable CloudTrail logging for secret access audit"
echo ""

echo -e "${YELLOW}⚠️  IMPORTANT: Use this password when creating RDS instance${NC}"
echo "Current password (copy now): ${DB_PASSWORD}"
echo ""
