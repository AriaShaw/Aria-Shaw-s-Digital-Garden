#!/bin/bash

# Odoo Dependency Fixer - The Nuclear Option
# Created by Aria Shaw
# Version 1.0 - 2025

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================"
echo "    Odoo Dependency Fixer (Nuclear)"
echo "========================================"
echo ""

log_message() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"
}

warn_message() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error_message() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error_message "This script must be run as root (use sudo)"
    exit 1
fi

# Detect Odoo version
detect_odoo_version() {
    log_message "Detecting Odoo version..."

    if [ -f "/opt/odoo/odoo/odoo-bin" ]; then
        ODOO_VERSION=$(grep -o 'version.*=.*[0-9]\+\.[0-9]\+' /opt/odoo/odoo/odoo/__init__.py | grep -o '[0-9]\+\.[0-9]\+' | head -1)
    elif [ -f "/usr/bin/odoo" ]; then
        ODOO_VERSION=$(odoo --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+' | head -1)
    else
        warn_message "Could not detect Odoo version automatically"
        echo -n "Please enter your Odoo version (e.g., 17.0, 18.0): "
        read ODOO_VERSION
    fi

    log_message "Target Odoo version: $ODOO_VERSION"
}

# Remove conflicting packages
remove_conflicting_packages() {
    log_message "Removing conflicting system packages..."

    # Stop Odoo service if running
    systemctl stop odoo 2>/dev/null || true

    # Remove problematic system packages
    apt-get remove -y python3-odoo* 2>/dev/null || true
    apt-get remove -y odoo 2>/dev/null || true

    # Remove pip packages that often conflict
    pip3 uninstall -y lxml psycopg2 psycopg2-binary 2>/dev/null || true

    log_message "Conflicting packages removed"
}

# Install system dependencies
install_system_dependencies() {
    log_message "Installing system dependencies..."

    apt-get update

    # Core build dependencies
    apt-get install -y \
        python3-dev \
        python3-pip \
        python3-venv \
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
        libpq-dev \
        postgresql-client \
        git \
        curl \
        wget

    # Python 3.10 specific for Odoo 17+
    if [[ "$ODOO_VERSION" =~ ^(17|18) ]]; then
        log_message "Installing Python 3.10 for Odoo $ODOO_VERSION"
        apt-get install -y python3.10 python3.10-dev python3.10-venv
        update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1
    fi

    log_message "System dependencies installed"
}

# Create virtual environment
create_virtual_environment() {
    log_message "Creating clean Python virtual environment..."

    # Remove existing virtual environment
    rm -rf /opt/odoo/venv

    # Create new virtual environment
    mkdir -p /opt/odoo
    python3 -m venv /opt/odoo/venv

    # Activate virtual environment
    source /opt/odoo/venv/bin/activate

    # Upgrade pip and essential tools
    pip install --upgrade pip setuptools wheel

    log_message "Virtual environment created"
}

# Install Python dependencies
install_python_dependencies() {
    log_message "Installing Python dependencies for Odoo $ODOO_VERSION..."

    source /opt/odoo/venv/bin/activate

    # Install specific versions based on Odoo version
    case "$ODOO_VERSION" in
        "17.0")
            pip install \
                lxml==4.9.3 \
                psycopg2==2.9.7 \
                Pillow==10.0.1 \
                reportlab==4.0.4 \
                werkzeug==2.3.7 \
                requests==2.31.0
            ;;
        "18.0")
            pip install \
                lxml==4.9.3 \
                psycopg2==2.9.7 \
                Pillow==10.0.1 \
                reportlab==4.0.4 \
                werkzeug==2.3.7 \
                requests==2.31.0
            ;;
        *)
            warn_message "Using generic dependency installation for version $ODOO_VERSION"
            pip install lxml psycopg2 Pillow reportlab werkzeug requests
            ;;
    esac

    # Install additional common dependencies
    pip install \
        babel \
        chardet \
        cryptography \
        decorator \
        docutils \
        ebaysdk \
        freezegun \
        gevent \
        greenlet \
        idna \
        jinja2 \
        libsass \
        markupsafe \
        num2words \
        ofxparse \
        passlib \
        polib \
        pypdf2 \
        pyserial \
        python-dateutil \
        python-ldap \
        python-stdnum \
        pytz \
        pyusb \
        qrcode \
        suds-jurko \
        vobject \
        xlrd \
        xlsxwriter \
        xlwt \
        zeep

    log_message "Python dependencies installed"
}

# Fix LXML specifically
fix_lxml_issues() {
    log_message "Applying LXML-specific fixes..."

    source /opt/odoo/venv/bin/activate

    # Uninstall any existing LXML
    pip uninstall -y lxml

    # Install LXML with specific compilation flags
    STATIC_DEPS=true pip install --no-binary lxml lxml

    # Verify LXML installation
    if python3 -c "import lxml; print('LXML version:', lxml.__version__)" 2>/dev/null; then
        log_message "LXML installed successfully"
    else
        error_message "LXML installation failed"
        exit 1
    fi
}

# Configure systemd service
configure_systemd_service() {
    log_message "Configuring systemd service..."

    cat > /etc/systemd/system/odoo.service << EOF
[Unit]
Description=Odoo
Documentation=http://www.odoo.com
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=notify
SyslogIdentifier=odoo
User=odoo
Group=odoo
ExecStart=/opt/odoo/venv/bin/python3 /opt/odoo/odoo/odoo-bin -c /etc/odoo/odoo.conf
StandardOutput=journal+console
Restart=on-failure
RestartSec=30
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    log_message "Systemd service configured"
}

# Verify installation
verify_installation() {
    log_message "Verifying installation..."

    source /opt/odoo/venv/bin/activate

    # Test critical imports
    python3 -c "
import sys
print('Python version:', sys.version)

try:
    import lxml
    print('✓ LXML version:', lxml.__version__)
except ImportError as e:
    print('✗ LXML import failed:', e)

try:
    import psycopg2
    print('✓ psycopg2 version:', psycopg2.__version__)
except ImportError as e:
    print('✗ psycopg2 import failed:', e)

try:
    import PIL
    print('✓ Pillow version:', PIL.__version__)
except ImportError as e:
    print('✗ Pillow import failed:', e)

try:
    import werkzeug
    print('✓ Werkzeug version:', werkzeug.__version__)
except ImportError as e:
    print('✗ Werkzeug import failed:', e)
"

    log_message "Installation verification complete"
}

# Main execution
main() {
    log_message "Starting dependency nuclear reset..."

    detect_odoo_version
    remove_conflicting_packages
    install_system_dependencies
    create_virtual_environment
    install_python_dependencies
    fix_lxml_issues
    configure_systemd_service
    verify_installation

    echo ""
    echo "========================================"
    echo -e "${GREEN}    Dependency Reset Complete!${NC}"
    echo "========================================"
    echo ""
    echo "Next steps:"
    echo "1. Configure your /etc/odoo/odoo.conf file"
    echo "2. Set proper ownership: chown -R odoo:odoo /opt/odoo"
    echo "3. Start Odoo: systemctl start odoo"
    echo "4. Check status: systemctl status odoo"
    echo ""
    echo "Virtual environment location: /opt/odoo/venv"
    echo "To activate: source /opt/odoo/venv/bin/activate"
}

# Run main function
main "$@"