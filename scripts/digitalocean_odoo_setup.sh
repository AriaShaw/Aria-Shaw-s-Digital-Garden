#!/bin/bash

# DigitalOcean Odoo Production Setup Script
# Created by Aria Shaw
# Version 1.0 - 2025
# Optimized for Ubuntu 22.04 LTS on DigitalOcean

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "    DigitalOcean Odoo Production Setup"
echo "=========================================="
echo ""

# Configuration variables
ODOO_VERSION="17.0"
ODOO_USER="odoo"
ODOO_HOME="/opt/odoo"
ODOO_CONFIG="/etc/odoo/odoo.conf"
DOMAIN_NAME=""
EMAIL=""

log_message() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

success_message() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning_message() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error_message() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error_message "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Get configuration from user
get_configuration() {
    log_message "Gathering configuration information..."

    echo -n "Enter your domain name (e.g., odoo.yourcompany.com): "
    read DOMAIN_NAME

    echo -n "Enter your email for SSL certificate (e.g., admin@yourcompany.com): "
    read EMAIL

    echo -n "Enter Odoo version (default: 17.0): "
    read VERSION_INPUT
    if [ -n "$VERSION_INPUT" ]; then
        ODOO_VERSION="$VERSION_INPUT"
    fi

    echo ""
    echo "Configuration Summary:"
    echo "Domain: $DOMAIN_NAME"
    echo "Email: $EMAIL"
    echo "Odoo Version: $ODOO_VERSION"
    echo ""

    read -p "Continue with this configuration? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled"
        exit 1
    fi
}

# Update system
update_system() {
    log_message "Updating system packages..."

    apt update
    apt upgrade -y

    # Install essential packages
    apt install -y \
        curl \
        wget \
        git \
        unzip \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release

    success_message "System updated successfully"
}

# Install Python 3.10 and dependencies
install_python() {
    log_message "Installing Python 3.10 and dependencies..."

    # Python 3.10 is default on Ubuntu 22.04, but ensure it's installed
    apt install -y \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        python3-wheel \
        python3-setuptools

    # Build dependencies for Python packages
    apt install -y \
        build-essential \
        libxml2-dev \
        libxslt1-dev \
        libffi-dev \
        libssl-dev \
        libjpeg-dev \
        libpng-dev \
        libtiff-dev \
        zlib1g-dev \
        libfreetype6-dev \
        liblcms2-dev \
        libwebp-dev \
        libharfbuzz-dev \
        libfribidi-dev \
        libxcb1-dev \
        libpq-dev

    success_message "Python and dependencies installed"
}

# Install and configure PostgreSQL
install_postgresql() {
    log_message "Installing and configuring PostgreSQL..."

    # Install PostgreSQL 14
    apt install -y postgresql postgresql-contrib

    # Start and enable PostgreSQL
    systemctl start postgresql
    systemctl enable postgresql

    # Create Odoo user and database
    sudo -u postgres createuser -s $ODOO_USER 2>/dev/null || true
    sudo -u postgres createdb $ODOO_USER 2>/dev/null || true

    # Set PostgreSQL password for Odoo user
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-16)
    sudo -u postgres psql -c "ALTER USER $ODOO_USER WITH PASSWORD '$POSTGRES_PASSWORD';"

    # Optimize PostgreSQL for Odoo
    PG_CONFIG="/etc/postgresql/14/main/postgresql.conf"

    # Get total RAM in GB
    TOTAL_RAM_GB=$(free -g | awk 'NR==2{print $2}')
    SHARED_BUFFERS=$((TOTAL_RAM_GB * 256))MB  # 25% of RAM
    EFFECTIVE_CACHE=$((TOTAL_RAM_GB * 768))MB  # 75% of RAM

    cat >> $PG_CONFIG << EOF

# Odoo Optimization
shared_buffers = ${SHARED_BUFFERS}
effective_cache_size = ${EFFECTIVE_CACHE}
work_mem = 20MB
maintenance_work_mem = 512MB
max_connections = 200
checkpoint_completion_target = 0.9
wal_buffers = 16MB
random_page_cost = 1.1
effective_io_concurrency = 200
EOF

    # Restart PostgreSQL
    systemctl restart postgresql

    success_message "PostgreSQL installed and configured"
    echo "PostgreSQL password for $ODOO_USER: $POSTGRES_PASSWORD"
}

# Install and configure Odoo
install_odoo() {
    log_message "Installing Odoo $ODOO_VERSION..."

    # Create Odoo user
    adduser --system --home=$ODOO_HOME --group $ODOO_USER

    # Create directories
    mkdir -p $ODOO_HOME
    mkdir -p /etc/odoo
    mkdir -p /var/log/odoo

    # Download Odoo
    cd /opt
    git clone https://www.github.com/odoo/odoo --depth 1 --branch $ODOO_VERSION --single-branch odoo

    # Create virtual environment
    python3 -m venv $ODOO_HOME/venv
    source $ODOO_HOME/venv/bin/activate

    # Install Python dependencies
    pip install --upgrade pip setuptools wheel
    pip install -r /opt/odoo/requirements.txt

    # Set ownership
    chown -R $ODOO_USER:$ODOO_USER $ODOO_HOME
    chown -R $ODOO_USER:$ODOO_USER /var/log/odoo

    success_message "Odoo installed successfully"
}

# Configure Odoo
configure_odoo() {
    log_message "Configuring Odoo..."

    # Generate admin password
    ADMIN_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-24)

    # Create Odoo configuration file
    cat > $ODOO_CONFIG << EOF
[options]
# Database settings
admin_passwd = $ADMIN_PASSWORD
db_host = localhost
db_port = 5432
db_user = $ODOO_USER
db_password = $POSTGRES_PASSWORD

# Server settings
addons_path = /opt/odoo/addons
data_dir = /var/lib/odoo
logfile = /var/log/odoo/odoo.log
log_level = info

# Security settings
list_db = False
proxy_mode = True

# Performance settings
workers = 4
max_cron_threads = 2
limit_memory_hard = 2684354560
limit_memory_soft = 2147483648
limit_request = 8192
limit_time_cpu = 600
limit_time_real = 1200

# Network settings
xmlrpc_interface = 127.0.0.1
xmlrpc_port = 8069
longpolling_port = 8072
EOF

    # Set proper permissions
    chown root:$ODOO_USER $ODOO_CONFIG
    chmod 640 $ODOO_CONFIG

    # Create data directory
    mkdir -p /var/lib/odoo
    chown $ODOO_USER:$ODOO_USER /var/lib/odoo

    success_message "Odoo configured"
    echo "Odoo admin password: $ADMIN_PASSWORD"
}

# Create systemd service
create_systemd_service() {
    log_message "Creating systemd service..."

    cat > /etc/systemd/system/odoo.service << EOF
[Unit]
Description=Odoo
Documentation=http://www.odoo.com
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=notify
SyslogIdentifier=odoo
User=$ODOO_USER
Group=$ODOO_USER
ExecStart=$ODOO_HOME/venv/bin/python3 /opt/odoo/odoo-bin -c $ODOO_CONFIG
StandardOutput=journal+console
Restart=on-failure
RestartSec=30
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and start Odoo
    systemctl daemon-reload
    systemctl enable odoo
    systemctl start odoo

    success_message "Systemd service created and started"
}

# Install and configure Nginx
install_nginx() {
    log_message "Installing and configuring Nginx..."

    apt install -y nginx

    # Create Nginx configuration
    cat > /etc/nginx/sites-available/odoo << EOF
upstream odoo {
    server 127.0.0.1:8069;
}

upstream odoochat {
    server 127.0.0.1:8072;
}

# HTTP redirect to HTTPS
server {
    listen 80;
    server_name $DOMAIN_NAME;
    return 301 https://\$server_name\$request_uri;
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name $DOMAIN_NAME;

    # SSL configuration (will be updated by Certbot)
    ssl_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;

    # SSL security settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;

    # Proxy settings
    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;
    proxy_set_header X-Forwarded-Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Real-IP \$remote_addr;

    # Handle longpolling requests
    location /longpolling {
        proxy_pass http://odoochat;
    }

    # Handle normal requests
    location / {
        proxy_pass http://odoo;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Gzip compression
    gzip on;
    gzip_types text/css text/javascript text/xml text/plain application/javascript application/xml+rss application/json;
}
EOF

    # Enable the site
    ln -sf /etc/nginx/sites-available/odoo /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default

    # Test and restart Nginx
    nginx -t
    systemctl restart nginx
    systemctl enable nginx

    success_message "Nginx installed and configured"
}

# Install SSL certificate
install_ssl() {
    log_message "Installing SSL certificate with Let's Encrypt..."

    # Install Certbot
    apt install -y snapd
    snap install core; snap refresh core
    snap install --classic certbot

    # Create symlink
    ln -sf /snap/bin/certbot /usr/bin/certbot

    # Get SSL certificate
    certbot --nginx -d $DOMAIN_NAME --email $EMAIL --agree-tos --non-interactive

    success_message "SSL certificate installed"
}

# Configure firewall
configure_firewall() {
    log_message "Configuring UFW firewall..."

    # Reset UFW
    ufw --force reset

    # Allow SSH
    ufw allow 22/tcp

    # Allow HTTP and HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp

    # Deny direct access to Odoo port
    ufw deny 8069/tcp

    # Enable firewall
    ufw --force enable

    success_message "Firewall configured"
}

# Setup automated backups
setup_backups() {
    log_message "Setting up automated backups..."

    # Create backup directory
    mkdir -p /opt/backups

    # Create backup script
    cat > /opt/backups/odoo_backup.sh << 'EOF'
#!/bin/bash

BACKUP_DIR="/opt/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

# Create database backup
sudo -u postgres pg_dump odoo > "$BACKUP_DIR/odoo_db_$TIMESTAMP.sql"

# Create filestore backup
tar -czf "$BACKUP_DIR/odoo_filestore_$TIMESTAMP.tar.gz" -C /var/lib/odoo filestore/ 2>/dev/null || true

# Cleanup old backups
find "$BACKUP_DIR" -name "odoo_*.sql" -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR" -name "odoo_*.tar.gz" -mtime +$RETENTION_DAYS -delete

echo "Backup completed: $TIMESTAMP"
EOF

    chmod +x /opt/backups/odoo_backup.sh

    # Add to crontab for daily backups at 2 AM
    (crontab -l 2>/dev/null; echo "0 2 * * * /opt/backups/odoo_backup.sh") | crontab -

    success_message "Automated backups configured"
}

# Final system check
final_check() {
    log_message "Performing final system check..."

    echo ""
    echo "=== SYSTEM STATUS ==="
    echo "Odoo Service: $(systemctl is-active odoo)"
    echo "PostgreSQL Service: $(systemctl is-active postgresql)"
    echo "Nginx Service: $(systemctl is-active nginx)"
    echo ""

    echo "=== CONNECTIVITY TEST ==="
    sleep 5
    if curl -s -I https://$DOMAIN_NAME | head -1; then
        success_message "Odoo is responding via HTTPS"
    else
        warning_message "HTTPS connectivity test failed - check DNS and SSL"
    fi

    echo ""
    echo "=== CONFIGURATION SUMMARY ==="
    echo "Domain: https://$DOMAIN_NAME"
    echo "Odoo Config: $ODOO_CONFIG"
    echo "Odoo Logs: /var/log/odoo/odoo.log"
    echo "Nginx Config: /etc/nginx/sites-available/odoo"
    echo "Backup Script: /opt/backups/odoo_backup.sh"
    echo ""
    echo "Admin Password: $ADMIN_PASSWORD"
    echo "Database Password: $POSTGRES_PASSWORD"
}

# Generate setup report
generate_report() {
    log_message "Generating setup report..."

    REPORT_FILE="/root/odoo_setup_report_$(date +%Y%m%d_%H%M%S).txt"

    cat > "$REPORT_FILE" << EOF
DigitalOcean Odoo Production Setup Report
=========================================
Date: $(date)
Server: $(hostname)
Domain: https://$DOMAIN_NAME

Installation Details:
- Odoo Version: $ODOO_VERSION
- Python Version: $(python3 --version)
- PostgreSQL Version: $(sudo -u postgres psql -c "SELECT version();" -t | head -1 | xargs)
- Nginx Version: $(nginx -v 2>&1)

Configuration Files:
- Odoo Config: $ODOO_CONFIG
- Nginx Config: /etc/nginx/sites-available/odoo
- Systemd Service: /etc/systemd/system/odoo.service

Credentials (STORE SECURELY):
- Odoo Admin Password: $ADMIN_PASSWORD
- PostgreSQL Password: $POSTGRES_PASSWORD

Services Status:
- Odoo: $(systemctl is-active odoo)
- PostgreSQL: $(systemctl is-active postgresql)
- Nginx: $(systemctl is-active nginx)

Important Commands:
- Restart Odoo: sudo systemctl restart odoo
- View Odoo logs: sudo journalctl -u odoo -f
- Check Nginx config: sudo nginx -t
- Run backup manually: sudo /opt/backups/odoo_backup.sh

Next Steps:
1. Access Odoo at https://$DOMAIN_NAME
2. Complete the initial setup wizard
3. Install required modules
4. Configure users and permissions
5. Test backup and restore procedures

Security Notes:
- Firewall configured to allow only HTTP, HTTPS, and SSH
- SSL certificate auto-renewal configured
- Direct access to port 8069 blocked
- Database access restricted to localhost

EOF

    success_message "Setup report generated: $REPORT_FILE"
    echo ""
    cat "$REPORT_FILE"
}

# Main execution
main() {
    check_root
    get_configuration

    log_message "Starting DigitalOcean Odoo production setup..."
    echo ""

    update_system
    install_python
    install_postgresql
    install_odoo
    configure_odoo
    create_systemd_service
    install_nginx

    if [ -n "$DOMAIN_NAME" ] && [ -n "$EMAIL" ]; then
        install_ssl
    else
        warning_message "Skipping SSL installation - domain or email not provided"
    fi

    configure_firewall
    setup_backups
    final_check
    generate_report

    echo ""
    echo "=========================================="
    echo -e "${GREEN}    SETUP COMPLETE!${NC}"
    echo "=========================================="
    echo ""
    echo "Your Odoo installation is ready!"
    echo "Access it at: https://$DOMAIN_NAME"
    echo ""
    echo "Important: Save the admin password and database password!"
    echo "They are shown in the setup report above."
}

# Run main function
main "$@"