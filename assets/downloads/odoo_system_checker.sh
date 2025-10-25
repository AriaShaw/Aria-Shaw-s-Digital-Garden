#!/bin/bash

# Odoo System Compatibility Checker
# Created by Aria Shaw
# Version 1.0 - 2025

echo "=========================================="
echo "    Odoo System Requirements Checker"
echo "=========================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Initialize score
score=0
max_score=10

echo "Checking system compatibility for Odoo 17/18..."
echo ""

# Check 1: Operating System
echo "1. Operating System Check:"
if command -v lsb_release &> /dev/null; then
    os_info=$(lsb_release -d | cut -f2)
    echo "   Detected: $os_info"

    if echo "$os_info" | grep -qi "ubuntu"; then
        if echo "$os_info" | grep -E "(20\.04|22\.04|24\.04)" &> /dev/null; then
            echo -e "   Status: ${GREEN}✓ Compatible Ubuntu LTS version${NC}"
            ((score++))
        else
            echo -e "   Status: ${YELLOW}⚠ Old Ubuntu version - consider upgrading${NC}"
        fi
    else
        echo -e "   Status: ${YELLOW}⚠ Non-Ubuntu Linux - may require additional setup${NC}"
    fi
else
    echo -e "   Status: ${RED}✗ Unable to detect OS version${NC}"
fi
echo ""

# Check 2: Python Version
echo "2. Python Version Check:"
if command -v python3 &> /dev/null; then
    python_version=$(python3 --version | cut -d' ' -f2)
    echo "   Detected: Python $python_version"

    # Check if Python 3.10 or higher
    if python3 -c "import sys; exit(0 if sys.version_info >= (3, 10) else 1)" 2>/dev/null; then
        echo -e "   Status: ${GREEN}✓ Python 3.10+ compatible${NC}"
        ((score+=2))
    else
        echo -e "   Status: ${RED}✗ Python 3.10+ required for Odoo 17/18${NC}"
        echo "   Action: Run 'sudo apt install python3.10 python3.10-venv python3.10-dev'"
    fi
else
    echo -e "   Status: ${RED}✗ Python3 not found${NC}"
fi
echo ""

# Check 3: Memory
echo "3. Memory Check:"
total_ram=$(free -m | awk 'NR==2{printf "%.0f", $2}')
echo "   Detected: ${total_ram}MB RAM"

if [ "$total_ram" -ge 8192 ]; then
    echo -e "   Status: ${GREEN}✓ Excellent - Suitable for medium business${NC}"
    ((score+=2))
elif [ "$total_ram" -ge 4096 ]; then
    echo -e "   Status: ${GREEN}✓ Good - Suitable for small business${NC}"
    ((score+=2))
elif [ "$total_ram" -ge 2048 ]; then
    echo -e "   Status: ${YELLOW}⚠ Minimal - Only for testing/development${NC}"
    ((score++))
else
    echo -e "   Status: ${RED}✗ Insufficient RAM for Odoo production${NC}"
fi
echo ""

# Check 4: CPU Cores
echo "4. CPU Check:"
cpu_cores=$(nproc)
echo "   Detected: ${cpu_cores} CPU cores"

if [ "$cpu_cores" -ge 4 ]; then
    echo -e "   Status: ${GREEN}✓ Excellent for production use${NC}"
    ((score+=2))
elif [ "$cpu_cores" -ge 2 ]; then
    echo -e "   Status: ${GREEN}✓ Adequate for small to medium deployment${NC}"
    ((score+=2))
else
    echo -e "   Status: ${YELLOW}⚠ Single core - development only${NC}"
    ((score++))
fi
echo ""

# Check 5: Disk Space and Type
echo "5. Storage Check:"
available_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
echo "   Available space: ${available_space}GB"

if [ "$available_space" -ge 100 ]; then
    echo -e "   Status: ${GREEN}✓ Plenty of space for production${NC}"
    ((score++))
elif [ "$available_space" -ge 50 ]; then
    echo -e "   Status: ${GREEN}✓ Adequate for small deployment${NC}"
    ((score++))
else
    echo -e "   Status: ${YELLOW}⚠ Consider adding more storage${NC}"
fi

# Check if SSD (best effort)
if lsblk -d -o name,rota | grep -q " 0"; then
    echo -e "   Storage type: ${GREEN}✓ SSD detected${NC}"
else
    echo -e "   Storage type: ${YELLOW}⚠ HDD detected - SSD recommended${NC}"
fi
echo ""

# Check 6: PostgreSQL
echo "6. PostgreSQL Check:"
if command -v psql &> /dev/null; then
    pg_version=$(psql --version | awk '{print $3}' | cut -d. -f1)
    echo "   Detected: PostgreSQL $pg_version"

    if [ "$pg_version" -ge 12 ]; then
        echo -e "   Status: ${GREEN}✓ Compatible PostgreSQL version${NC}"
        ((score++))
    else
        echo -e "   Status: ${RED}✗ PostgreSQL 12+ required${NC}"
        echo "   Action: Upgrade PostgreSQL"
    fi
else
    echo "   Status: PostgreSQL not installed"
    echo "   Action: Run 'sudo apt install postgresql postgresql-contrib'"
fi
echo ""

# Final Score and Recommendations
echo "=========================================="
echo "         COMPATIBILITY SUMMARY"
echo "=========================================="
echo "Score: $score/$max_score"
echo ""

if [ "$score" -ge 9 ]; then
    echo -e "${GREEN}🎉 EXCELLENT: Your system is ready for Odoo production!${NC}"
elif [ "$score" -ge 7 ]; then
    echo -e "${GREEN}✅ GOOD: Minor adjustments needed for optimal performance${NC}"
elif [ "$score" -ge 5 ]; then
    echo -e "${YELLOW}⚠️  CAUTION: Several issues need addressing before production${NC}"
else
    echo -e "${RED}❌ NOT READY: Significant upgrades required${NC}"
fi

echo ""
echo "Recommendations based on your system:"

# Generate specific recommendations
if [ "$total_ram" -lt 4096 ]; then
    echo "• Upgrade RAM to at least 4GB (8GB recommended)"
fi

if [ "$cpu_cores" -lt 2 ]; then
    echo "• Consider upgrading to a multi-core system"
fi

if [ "$available_space" -lt 50 ]; then
    echo "• Add more storage (minimum 50GB for small deployment)"
fi

if ! python3 -c "import sys; exit(0 if sys.version_info >= (3, 10) else 1)" 2>/dev/null; then
    echo "• Install Python 3.10+: sudo apt install python3.10 python3.10-venv"
fi

if ! command -v psql &> /dev/null; then
    echo "• Install PostgreSQL: sudo apt install postgresql postgresql-contrib"
fi

echo ""
echo "For detailed setup instructions, visit:"
echo "https://ariashaw.com/odoo-system-requirements-deployment-guide/"
echo ""