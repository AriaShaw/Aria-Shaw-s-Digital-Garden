#!/bin/bash

################################################################################
# Odoo SSL Certificate Setup with Let's Encrypt
#
# Description:
#   Automates SSL/TLS certificate installation using Certbot and Let's Encrypt.
#   Configures Nginx for A+ SSL Labs rating.
#
# What this script does:
#   - Installs Certbot and Nginx plugin
#   - Obtains SSL certificate from Let's Encrypt
#   - Configures auto-renewal (90-day cycle)
#   - Updates Nginx with security headers
#
# Usage:
#   sudo ./setup-ssl-certbot.sh <DOMAIN> <EMAIL>
#
# Example:
#   sudo ./setup-ssl-certbot.sh odoo.example.com admin@example.com
#
# Prerequisites:
#   - Ubuntu/Debian system with Nginx installed
#   - Domain DNS pointing to server IP
#   - Port 80 accessible from internet (for ACME challenge)
#   - Root or sudo access
#
# Output:
#   SSL certificate installed, auto-renewal configured
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
  echo -e "${RED}Usage: sudo $0 <DOMAIN> <EMAIL>${NC}"
  echo ""
  echo "Example:"
  echo "  sudo $0 odoo.example.com admin@example.com"
  exit 1
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}Please run as root (use sudo)${NC}"
  exit 1
fi

DOMAIN=$1
EMAIL=$2

echo -e "${GREEN}==== Odoo SSL Certificate Setup ====${NC}\n"
echo "Domain: ${DOMAIN}"
echo "Email: ${EMAIL}"
echo ""

# Step 1: Install Certbot
echo -e "${YELLOW}[1/5] Installing Certbot...${NC}"

apt update
apt install -y certbot python3-certbot-nginx

echo -e "${GREEN}✓ Certbot installed${NC}\n"

# Step 2: Obtain Certificate
echo -e "${YELLOW}[2/5] Obtaining SSL certificate from Let's Encrypt...${NC}"

certbot --nginx \
  -d "$DOMAIN" \
  --non-interactive \
  --agree-tos \
  --email "$EMAIL" \
  --redirect \
  --hsts \
  --staple-ocsp

echo -e "${GREEN}✓ Certificate obtained and installed${NC}\n"

# Step 3: Configure Auto-Renewal
echo -e "${YELLOW}[3/5] Configuring auto-renewal...${NC}"

# Test renewal
certbot renew --dry-run

# Certbot installs systemd timer automatically
systemctl status certbot.timer --no-pager || systemctl enable certbot.timer

echo -e "${GREEN}✓ Auto-renewal configured (checks twice daily)${NC}\n"

# Step 4: Update Nginx Security Headers
echo -e "${YELLOW}[4/5] Updating Nginx security headers...${NC}"

NGINX_CONF="/etc/nginx/sites-available/odoo"

if [ -f "$NGINX_CONF" ]; then
  # Backup original config
  cp "$NGINX_CONF" "${NGINX_CONF}.bak"
  
  # Add security headers if not present
  if ! grep -q "X-Frame-Options" "$NGINX_CONF"; then
    sed -i '/ssl_certificate/a \    # Security headers\n    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;\n    add_header X-Frame-Options "SAMEORIGIN" always;\n    add_header X-Content-Type-Options "nosniff" always;\n    add_header X-XSS-Protection "1; mode=block" always;' "$NGINX_CONF"
  fi
  
  # Reload Nginx
  nginx -t && systemctl reload nginx
  
  echo -e "${GREEN}✓ Security headers added${NC}\n"
else
  echo -e "${YELLOW}⚠️  Nginx config not found at $NGINX_CONF${NC}"
  echo -e "${YELLOW}   Manually add security headers to your Nginx config${NC}\n"
fi

# Step 5: Verify SSL Configuration
echo -e "${YELLOW}[5/5] Verifying SSL configuration...${NC}"

# Test HTTPS
if curl -sI "https://$DOMAIN" | grep -q "HTTP/2 200"; then
  echo -e "${GREEN}✓ HTTPS working${NC}"
else
  echo -e "${RED}✗ HTTPS not responding${NC}"
fi

# Check certificate expiry
EXPIRY=$(echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)
echo -e "Certificate expires: ${GREEN}${EXPIRY}${NC}\n"

# Output Summary
echo -e "${GREEN}==== Setup Complete ====${NC}\n"
echo "SSL Certificate: Installed"
echo "Domain: ${DOMAIN}"
echo "Auto-renewal: Enabled (90-day cycle)"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Test SSL Labs rating:"
echo "   https://www.ssllabs.com/ssltest/analyze.html?d=${DOMAIN}"
echo "   Expected grade: A+"
echo ""
echo "2. Verify auto-renewal:"
echo "   sudo certbot renew --dry-run"
echo ""
echo "3. Check renewal timer:"
echo "   sudo systemctl status certbot.timer"
echo ""
echo "4. Manual renewal (if needed):"
echo "   sudo certbot renew --force-renewal"
echo "   sudo systemctl reload nginx"
echo ""
echo -e "${GREEN}Certificate Files:${NC}"
echo "  Certificate: /etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
echo "  Private Key: /etc/letsencrypt/live/${DOMAIN}/privkey.pem"
echo ""
