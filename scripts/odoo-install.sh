#!/bin/bash

# Odoo 18 Production Installation Script for Ubuntu 22.04/24.04
# Author: Aria Shaw
# Version: 2025.1
# Usage: sudo bash odoo-install.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ODOO_VERSION="18.0"
ODOO_USER="odoo"
ODOO_PORT="8069"
LONGPOLL_PORT="8072"
ODOO_HOME="/opt/odoo"
ODOO_CONFIG="/etc/odoo.conf"
POSTGRESQL_VERSION="15"

# Functions
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run this script as root (use sudo)"
    exit 1
fi

print_status "Starting Odoo 18 installation on Ubuntu..."

# Update system
print_status "Updating system packages..."
apt update && apt upgrade -y

# Install PostgreSQL
print_status "Installing PostgreSQL ${POSTGRESQL_VERSION}..."
apt install -y postgresql postgresql-contrib

# Start and enable PostgreSQL
systemctl start postgresql
systemctl enable postgresql

# Create Odoo database user
print_status "Creating Odoo database user..."
sudo -u postgres createuser -s $ODOO_USER 2>/dev/null || print_warning "User $ODOO_USER already exists"

# Install Python dependencies
print_status "Installing Python dependencies..."
apt install -y python3-pip python3-dev python3-venv libxml2-dev libxslt1-dev \
    libevent-dev libsasl2-dev libldap2-dev pkg-config libtiff5-dev libjpeg8-dev \
    libopenjp2-7-dev zlib1g-dev libfreetype6-dev liblcms2-dev libwebp-dev \
    libharfbuzz-dev libfribidi-dev libxcb1-dev libpq-dev

# Install Node.js and npm
print_status "Installing Node.js and npm..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs

# Install wkhtmltopdf
print_status "Installing wkhtmltopdf..."
wget -q https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.jammy_amd64.deb
apt install -y ./wkhtmltox_0.12.6.1-2.jammy_amd64.deb
rm wkhtmltox_0.12.6.1-2.jammy_amd64.deb

# Create Odoo user
print_status "Creating Odoo system user..."
adduser --system --home=$ODOO_HOME --group $ODOO_USER

# Install Odoo
print_status "Downloading and installing Odoo ${ODOO_VERSION}..."
cd /opt
git clone --depth 1 --branch $ODOO_VERSION https://github.com/odoo/odoo.git $ODOO_HOME
chown -R $ODOO_USER:$ODOO_USER $ODOO_HOME

# Create Python virtual environment
print_status "Creating Python virtual environment..."
sudo -u $ODOO_USER python3 -m venv $ODOO_HOME/venv
sudo -u $ODOO_USER $ODOO_HOME/venv/bin/pip install --upgrade pip

# Install Python requirements
print_status "Installing Odoo Python requirements..."
sudo -u $ODOO_USER $ODOO_HOME/venv/bin/pip install -r $ODOO_HOME/requirements.txt

# Create directories
mkdir -p /var/log/odoo
mkdir -p /etc/odoo
mkdir -p $ODOO_HOME/custom/addons
chown $ODOO_USER:$ODOO_USER /var/log/odoo
chown $ODOO_USER:$ODOO_USER /etc/odoo
chown -R $ODOO_USER:$ODOO_USER $ODOO_HOME/custom

# Create Odoo configuration file
print_status "Creating Odoo configuration file..."
cat > $ODOO_CONFIG << EOF
[options]
; Server startup config
admin_passwd = $(openssl rand -base64 32)
http_port = $ODOO_PORT
longpolling_port = $LONGPOLL_PORT
workers = 2
max_cron_threads = 1

; Database settings
db_host = localhost
db_port = 5432
db_user = $ODOO_USER
db_password = False

; Logging
logfile = /var/log/odoo/odoo.log
log_level = info

; Security
list_db = False
proxy_mode = True

; Paths
addons_path = $ODOO_HOME/addons,$ODOO_HOME/custom/addons
data_dir = $ODOO_HOME/.local/share/Odoo

; Performance
limit_memory_hard = 2684354560
limit_memory_soft = 2147483648
limit_request = 8192
limit_time_cpu = 600
limit_time_real = 1200
limit_time_real_cron = -1
EOF

chown $ODOO_USER:$ODOO_USER $ODOO_CONFIG
chmod 640 $ODOO_CONFIG

# Create systemd service file
print_status "Creating systemd service file..."
cat > /etc/systemd/system/odoo.service << EOF
[Unit]
Description=Odoo 18
Documentation=https://www.odoo.com/documentation/
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=notify
SyslogIdentifier=odoo
PermissionsStartOnly=true
User=$ODOO_USER
Group=$ODOO_USER
ExecStart=$ODOO_HOME/venv/bin/python $ODOO_HOME/odoo-bin -c $ODOO_CONFIG
ExecReload=/bin/kill -s HUP \$MAINPID
KillMode=mixed
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF

# Enable and start Odoo service
print_status "Enabling and starting Odoo service..."
systemctl daemon-reload
systemctl enable odoo
systemctl start odoo

# Install and configure Nginx
print_status "Installing and configuring Nginx..."
apt install -y nginx certbot python3-certbot-nginx

# Create Nginx configuration
cat > /etc/nginx/sites-available/odoo << 'EOF'
# This is a basic Nginx configuration for Odoo
# For production use, please refer to the complete nginx-odoo.conf script

upstream odoo {
    server 127.0.0.1:8069;
}

upstream odoochat {
    server 127.0.0.1:8072;
}

server {
    listen 80;
    server_name _;

    location /longpolling {
        proxy_pass http://odoochat;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location / {
        proxy_pass http://odoo;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_redirect off;
    }

    client_max_body_size 20M;
}
EOF

# Enable Nginx site
ln -sf /etc/nginx/sites-available/odoo /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

# Configure firewall
print_status "Configuring firewall..."
ufw allow ssh
ufw allow 'Nginx Full'
ufw --force enable

print_status "Installation completed successfully!"
echo ""
echo "=================================="
echo "Odoo 18 Installation Summary"
echo "=================================="
echo "Odoo User: $ODOO_USER"
echo "Odoo Home: $ODOO_HOME"
echo "Config File: $ODOO_CONFIG"
echo "Log File: /var/log/odoo/odoo.log"
echo "Admin Password: Check $ODOO_CONFIG"
echo ""
echo "Access Odoo at: http://$(hostname -I | awk '{print $1}')"
echo ""
echo "Useful commands:"
echo "  sudo systemctl status odoo    # Check Odoo status"
echo "  sudo systemctl restart odoo   # Restart Odoo"
echo "  sudo tail -f /var/log/odoo/odoo.log  # View logs"
echo ""
print_warning "Please change the default admin password and configure SSL certificates for production use!"