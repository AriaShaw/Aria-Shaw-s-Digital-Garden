#!/bin/bash
# Ubuntu 22.04 LTS Optimized Setup for Odoo Production
# Usage: sudo ./setup_ubuntu_odoo.sh

set -e

# Configuration
ODOO_USER="odoo"
ODOO_HOME="/opt/odoo"
POSTGRES_VERSION="14"
NODE_VERSION="18"
PYTHON_VERSION="3.10"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Starting Ubuntu 22.04 LTS Optimization for Odoo${NC}"
echo "========================================================="
echo "This script will:"
echo "  ✅ Update system packages"
echo "  ✅ Install and configure PostgreSQL $POSTGRES_VERSION"
echo "  ✅ Install Python $PYTHON_VERSION with optimizations"
echo "  ✅ Install Node.js $NODE_VERSION and build tools"
echo "  ✅ Configure system-level optimizations"
echo "  ✅ Set up security and firewall"
echo "  ✅ Create optimized Odoo user and directories"
echo ""

# Verify running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ This script must be run as root (use sudo)${NC}"
   exit 1
fi

# Log function
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check Ubuntu version
log "Checking Ubuntu version..."
if [[ $(lsb_release -rs) != "22.04" ]]; then
    warn "This script is optimized for Ubuntu 22.04 LTS"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Update system
log "Updating system packages..."
apt update && apt upgrade -y

# Install essential packages
log "Installing essential packages..."
apt install -y \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    wget \
    unzip \
    git \
    build-essential \
    python3-dev \
    libxml2-dev \
    libxslt1-dev \
    libevent-dev \
    libsasl2-dev \
    libldap2-dev \
    pkg-config \
    libtiff5-dev \
    libjpeg8-dev \
    libopenjp2-7-dev \
    zlib1g-dev \
    libfreetype6-dev \
    liblcms2-dev \
    libwebp-dev \
    tcl8.6-dev \
    tk8.6-dev \
    python3-tk \
    libharfbuzz-dev \
    libfribidi-dev \
    libxcb1-dev \
    python3-pip \
    python3-venv \
    python3-wheel \
    python3-setuptools

# Install PostgreSQL
log "Installing PostgreSQL $POSTGRES_VERSION..."
apt install -y postgresql-$POSTGRES_VERSION postgresql-client-$POSTGRES_VERSION postgresql-contrib-$POSTGRES_VERSION

# Start and enable PostgreSQL
systemctl start postgresql
systemctl enable postgresql

# Install Node.js and npm
log "Installing Node.js $NODE_VERSION..."
curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | sudo -E bash -
apt install -y nodejs

# Install additional Node.js tools
npm install -g less less-plugin-clean-css
npm install -g rtlcss

# Install wkhtmltopdf (required for PDF reports)
log "Installing wkhtmltopdf..."
WKHTMLTOPDF_VERSION="0.12.6.1-2"
WKHTMLTOPDF_URL="https://github.com/wkhtmltopdf/packaging/releases/download/${WKHTMLTOPDF_VERSION}/wkhtmltox_${WKHTMLTOPDF_VERSION}.jammy_amd64.deb"

cd /tmp
wget $WKHTMLTOPDF_URL -O wkhtmltox.deb
apt install -y ./wkhtmltox.deb
rm wkhtmltox.deb

# Create Odoo system user
log "Creating Odoo system user..."
if ! id "$ODOO_USER" &>/dev/null; then
    adduser --system --quiet --shell=/bin/bash --group \
            --gecos 'Odoo' --home=$ODOO_HOME $ODOO_USER
else
    log "User $ODOO_USER already exists"
fi

# Create Odoo directories
log "Setting up Odoo directory structure..."
mkdir -p $ODOO_HOME/{server,custom-addons,logs,backups}
mkdir -p /var/lib/odoo
mkdir -p /var/log/odoo
mkdir -p /etc/odoo

# Set proper ownership
chown -R $ODOO_USER:$ODOO_USER $ODOO_HOME
chown -R $ODOO_USER:$ODOO_USER /var/lib/odoo
chown -R $ODOO_USER:$ODOO_USER /var/log/odoo
chown $ODOO_USER:$ODOO_USER /etc/odoo

# Configure PostgreSQL for Odoo
log "Configuring PostgreSQL for optimal Odoo performance..."

# Create Odoo PostgreSQL user
sudo -u postgres createuser -s $ODOO_USER 2>/dev/null || log "PostgreSQL user $ODOO_USER already exists"

# Get system memory for PostgreSQL optimization
TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_MEM_GB=$((TOTAL_MEM_KB / 1024 / 1024))

# Calculate PostgreSQL settings
SHARED_BUFFERS=$((TOTAL_MEM_GB * 256 / 4))  # 25% of RAM in MB
EFFECTIVE_CACHE=$((TOTAL_MEM_GB * 768))     # 75% of RAM in MB
WORK_MEM=$((TOTAL_MEM_GB * 4))              # 4MB per GB of RAM
MAINTENANCE_WORK_MEM=$((TOTAL_MEM_GB * 64)) # 64MB per GB of RAM, max 2GB
MAINTENANCE_WORK_MEM=$((MAINTENANCE_WORK_MEM > 2048 ? 2048 : MAINTENANCE_WORK_MEM))

# Create PostgreSQL optimization config
log "Applying PostgreSQL performance optimizations..."
cat > /tmp/postgresql_odoo.conf << EOF
# Odoo Performance Optimizations for PostgreSQL $POSTGRES_VERSION
# Applied: $(date)

# Memory Configuration
shared_buffers = ${SHARED_BUFFERS}MB
effective_cache_size = ${EFFECTIVE_CACHE}MB
work_mem = ${WORK_MEM}MB
maintenance_work_mem = ${MAINTENANCE_WORK_MEM}MB

# Connection Configuration
max_connections = 200
superuser_reserved_connections = 3

# Checkpoint Configuration
checkpoint_completion_target = 0.9
wal_buffers = 16MB
checkpoint_timeout = 15min
max_wal_size = 1GB
min_wal_size = 80MB

# Query Planner Configuration
random_page_cost = 1.1
effective_io_concurrency = 200
seq_page_cost = 1.0

# Logging Configuration
log_destination = 'stderr'
logging_collector = on
log_directory = '/var/log/postgresql'
log_filename = 'postgresql-%a.log'
log_truncate_on_rotation = on
log_rotation_age = 1d
log_min_duration_statement = 1000
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
log_checkpoints = on
log_connections = on
log_disconnections = on
log_lock_waits = on

# Performance Monitoring
track_activities = on
track_counts = on
track_io_timing = on
track_functions = pl
EOF

# Apply PostgreSQL configuration
PG_CONFIG_DIR="/etc/postgresql/$POSTGRES_VERSION/main"
cp "$PG_CONFIG_DIR/postgresql.conf" "$PG_CONFIG_DIR/postgresql.conf.backup"
cat /tmp/postgresql_odoo.conf >> "$PG_CONFIG_DIR/postgresql.conf"

# Configure PostgreSQL access
log "Configuring PostgreSQL authentication..."
PG_HBA_FILE="$PG_CONFIG_DIR/pg_hba.conf"
cp "$PG_HBA_FILE" "$PG_HBA_FILE.backup"

# Add local connections for Odoo
if ! grep -q "local.*$ODOO_USER.*trust" "$PG_HBA_FILE"; then
    sed -i "/^local.*all.*postgres.*peer/a local   all             $ODOO_USER                                trust" "$PG_HBA_FILE"
fi

# Restart PostgreSQL to apply changes
log "Restarting PostgreSQL..."
systemctl restart postgresql

# System-level optimizations
log "Applying system-level performance optimizations..."

# Configure kernel parameters
cat > /etc/sysctl.d/99-odoo.conf << EOF
# Odoo System Optimizations

# Virtual Memory
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_background_ratio = 5
vm.dirty_ratio = 15

# Network Performance
net.core.somaxconn = 65536
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 65536
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 20

# File System
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288

# Process Limits
kernel.pid_max = 4194304
EOF

# Apply sysctl settings
sysctl -p /etc/sysctl.d/99-odoo.conf

# Configure system limits
log "Configuring system resource limits..."
cat > /etc/security/limits.d/99-odoo.conf << EOF
# Odoo Resource Limits
$ODOO_USER soft nofile 65536
$ODOO_USER hard nofile 65536
$ODOO_USER soft nproc 8192
$ODOO_USER hard nproc 8192

# PostgreSQL Limits
postgres soft nofile 65536
postgres hard nofile 65536
postgres soft nproc 8192
postgres hard nproc 8192
EOF

# Configure log rotation
log "Setting up log rotation..."
cat > /etc/logrotate.d/odoo << EOF
/var/log/odoo/*.log {
    daily
    missingok
    rotate 30
    compress
    notifempty
    create 0644 $ODOO_USER $ODOO_USER
    postrotate
        systemctl reload odoo > /dev/null 2>&1 || true
    endscript
}
EOF

# Install and configure UFW firewall
log "Configuring firewall..."
apt install -y ufw

# Configure firewall rules
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (be careful not to lock yourself out!)
ufw allow ssh

# Allow HTTP and HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Allow Odoo default port (8069) - you should change this in production
ufw allow 8069/tcp

# Allow PostgreSQL from localhost only
ufw allow from 127.0.0.1 to any port 5432

# Enable firewall
ufw --force enable

# Configure timezone and NTP
log "Configuring system time..."
timedatectl set-timezone UTC
apt install -y ntp
systemctl enable ntp
systemctl start ntp

# Install Python packages for Odoo
log "Installing Python packages for Odoo..."
pip3 install --upgrade pip setuptools wheel

# Essential Python packages for Odoo
pip3 install \
    Babel==2.9.1 \
    decorator==4.4.2 \
    docutils==0.17 \
    ebaysdk==2.1.5 \
    freezegun==1.1.0 \
    gevent==22.10.2 \
    greenlet==2.0.2 \
    idna==2.10 \
    Jinja2==3.0.3 \
    lxml==4.9.2 \
    MarkupSafe==2.1.2 \
    num2words==0.5.10 \
    ofxparse==0.21 \
    passlib==1.7.4 \
    Pillow==9.4.0 \
    polib==1.1.1 \
    psutil==5.9.4 \
    psycopg2==2.9.5 \
    pydot==1.4.2 \
    pyopenssl==23.0.0 \
    PyPDF2==3.0.1 \
    pyserial==3.5 \
    python-dateutil==2.8.2 \
    pytz==2022.7.1 \
    pyusb==1.2.1 \
    qrcode==7.3.1 \
    reportlab==3.6.12 \
    requests==2.28.2 \
    urllib3==1.26.14 \
    vobject==0.9.6.1 \
    Werkzeug==2.2.2 \
    xlrd==2.0.1 \
    XlsxWriter==3.0.8 \
    xlwt==1.3.0 \
    zeep==4.2.1

# Create sample Odoo configuration
log "Creating sample Odoo configuration..."
cat > /etc/odoo/odoo.conf << EOF
[options]
# Server Configuration
addons_path = $ODOO_HOME/server/addons,$ODOO_HOME/custom-addons
data_dir = /var/lib/odoo
logfile = /var/log/odoo/odoo.log
log_level = info

# Database Configuration
db_host = localhost
db_port = 5432
db_user = $ODOO_USER
db_password = False
list_db = False

# Web Interface Configuration
xmlrpc_interface = 127.0.0.1
xmlrpc_port = 8069
proxy_mode = True

# Performance Configuration
# These will be calculated based on your server specs
workers = 4
max_cron_threads = 2
limit_memory_hard = 2684354560
limit_memory_soft = 2147483648
limit_request = 8192
limit_time_cpu = 600
limit_time_real = 1200

# Security Configuration
admin_passwd = \$pbkdf2-sha512\$25000\$fake_hash_change_this
EOF

chown $ODOO_USER:$ODOO_USER /etc/odoo/odoo.conf
chmod 640 /etc/odoo/odoo.conf

# Create systemd service
log "Creating Odoo systemd service..."
cat > /etc/systemd/system/odoo.service << EOF
[Unit]
Description=Odoo
Documentation=http://www.odoo.com
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=notify
User=$ODOO_USER
Group=$ODOO_USER
ExecStart=$ODOO_HOME/server/odoo-bin -c /etc/odoo/odoo.conf
KillMode=mixed
KillSignal=SIGINT

# Resource Limits
LimitNOFILE=65536
LimitNPROC=8192

# Security Settings
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/lib/odoo /var/log/odoo /tmp

[Install]
WantedBy=multi-user.target
EOF

# Enable but don't start Odoo service (user needs to install Odoo first)
systemctl daemon-reload
systemctl enable odoo

# Clean up
log "Cleaning up temporary files..."
apt autoremove -y
apt autoclean

# Create installation summary
log "Creating installation summary..."
cat > /root/odoo_setup_summary.txt << EOF
Odoo Ubuntu 22.04 LTS Setup Complete
=====================================
Date: $(date)

Installed Components:
- Ubuntu 22.04 LTS (optimized)
- PostgreSQL $POSTGRES_VERSION (tuned for ${TOTAL_MEM_GB}GB RAM)
- Python $PYTHON_VERSION with Odoo dependencies
- Node.js $NODE_VERSION with build tools
- wkhtmltopdf for PDF generation

Created Users:
- System user: $ODOO_USER
- PostgreSQL user: $ODOO_USER (superuser privileges)

Directory Structure:
- Odoo home: $ODOO_HOME
- Config file: /etc/odoo/odoo.conf
- Log directory: /var/log/odoo
- Data directory: /var/lib/odoo

Next Steps:
1. Download and install Odoo:
   cd $ODOO_HOME
   git clone https://www.github.com/odoo/odoo --depth 1 --branch 17.0 server
   chown -R $ODOO_USER:$ODOO_USER server/

2. Update /etc/odoo/odoo.conf with your specific settings

3. Start Odoo service:
   systemctl start odoo

4. Access Odoo at: http://your-server-ip:8069

Security Notes:
- UFW firewall is enabled
- Only necessary ports are open
- PostgreSQL is configured for local connections only
- Change the admin password in odoo.conf immediately
- Consider setting up SSL/TLS for production use

System Optimizations Applied:
- PostgreSQL: ${SHARED_BUFFERS}MB shared_buffers, ${EFFECTIVE_CACHE}MB effective_cache_size
- Kernel: Reduced swappiness, optimized network settings
- Limits: Increased file and process limits for Odoo user
- Logging: Configured rotation for both Odoo and PostgreSQL logs
EOF

# Final output
echo ""
echo -e "${GREEN}🎉 Ubuntu 22.04 LTS Optimization Complete!${NC}"
echo "========================================================="
echo -e "${BLUE}📋 Installation Summary:${NC}"
echo "  ✅ System packages updated and optimized"
echo "  ✅ PostgreSQL $POSTGRES_VERSION installed and tuned"
echo "  ✅ Python environment prepared with all dependencies"
echo "  ✅ System resources optimized for Odoo workloads"
echo "  ✅ Security hardened with firewall configuration"
echo "  ✅ Logging and monitoring configured"
echo ""
echo -e "${YELLOW}📝 Summary saved to: /root/odoo_setup_summary.txt${NC}"
echo -e "${YELLOW}🔧 Sample config created: /etc/odoo/odoo.conf${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Install Odoo source code"
echo "2. Configure your specific settings"
echo "3. Start the Odoo service"
echo ""
echo -e "${GREEN}System is ready for Odoo installation!${NC}"