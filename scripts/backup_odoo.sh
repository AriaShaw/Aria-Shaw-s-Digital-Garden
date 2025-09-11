#!/bin/bash

# Configuration
DB_NAME="production"
DB_USER="odoo"
BACKUP_DIR="/home/odoo/backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p $BACKUP_DIR

# Database backup
pg_dump -U $DB_USER -h localhost $DB_NAME > $BACKUP_DIR/db_backup_$DATE.sql

# Filestore backup  
tar -czf $BACKUP_DIR/filestore_backup_$DATE.tar.gz -C /home/odoo/.local/share/Odoo/filestore $DB_NAME

# Keep only last 7 days of backups
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: $DATE"