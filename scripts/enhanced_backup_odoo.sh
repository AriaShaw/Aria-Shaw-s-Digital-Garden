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

# Sync to Backblaze B2 (add after local backup)
echo "Syncing to cloud..."
b2 sync /home/odoo/backups/ b2://odoo-backups/$(hostname)/

# Verify cloud backup
CLOUD_FILES=$(b2 ls odoo-backups --long | wc -l)
echo "Cloud backup files: $CLOUD_FILES"

if [ $CLOUD_FILES -lt 2 ]; then
  echo "WARNING: Cloud backup failed!" | mail -s "Backup Alert" admin@yourcompany.com
fi

echo "Enhanced backup completed: $DATE"