#!/bin/bash

# One-line system status
echo "=== SYSTEM STATUS ===" && \
echo "Disk Usage: $(df -h / | tail -1 | awk '{print $5}')" && \
echo "Memory Usage: $(free | grep Mem | awk '{printf("%.1f%%", $3/$2 * 100.0)}')" && \
echo "Odoo Status: $(systemctl is-active odoo)" && \
echo "Nginx Status: $(systemctl is-active nginx)" && \
echo "PostgreSQL Status: $(systemctl is-active postgresql)" && \
echo "Last Backup: $(ls -lt /home/odoo/backups/*.sql | head -1 | awk '{print $6, $7, $8}')"