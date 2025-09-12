#!/bin/bash
# Intelligent rollback procedure

echo "=== EMERGENCY ROLLBACK PROCEDURE ==="
echo "This will rollback to pre-migration state with optional data preservation"
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Rollback cancelled"
    exit 1
fi

BACKUP_FILE="/backup/pre_migration_snapshot.backup"
CURRENT_DB="production_new"
ROLLBACK_DB="production_rollback_$(date +%Y%m%d_%H%M%S)"

# Step 1: Preserve critical new data
echo "Step 1: Analyzing new data created during migration window..."
sudo -u postgres psql -d "$CURRENT_DB" -c "
CREATE TABLE rollback_new_data AS
SELECT 
    'res_partner' as table_name,
    id,
    create_date,
    write_date
FROM res_partner 
WHERE create_date > (SELECT MAX(create_date) FROM res_partner WHERE create_date < '$(date -d '1 day ago' '+%Y-%m-%d')')

UNION ALL

SELECT 
    'account_move' as table_name,
    id,
    create_date,
    write_date
FROM account_move 
WHERE create_date > (SELECT MAX(create_date) FROM account_move WHERE create_date < '$(date -d '1 day ago' '+%Y-%m-%d')');"

NEW_RECORDS=$(sudo -u postgres psql -d "$CURRENT_DB" -t -c "SELECT COUNT(*) FROM rollback_new_data;")
echo "Found $NEW_RECORDS new records created during migration window"

# Step 2: Create rollback database
echo "Step 2: Creating rollback database..."
sudo -u postgres createdb "$ROLLBACK_DB"

# Step 3: Restore from backup
echo "Step 3: Restoring from pre-migration backup..."
sudo -u postgres pg_restore -d "$ROLLBACK_DB" "$BACKUP_FILE"

# Step 4: Optional - Import critical new data
if [ "$NEW_RECORDS" -gt 0 ]; then
    read -p "Import $NEW_RECORDS new records into rollback database? (yes/no): " import_new
    if [ "$import_new" = "yes" ]; then
        echo "Step 4: Importing new data..."
        # This would require custom logic based on your specific data relationships
        echo "Manual data import required - see documentation"
    fi
fi

# Step 5: Switch databases
echo "Step 5: Switching to rollback database..."
sudo systemctl stop odoo

# Update Odoo configuration
sudo sed -i "s/db_name = $CURRENT_DB/db_name = $ROLLBACK_DB/" /etc/odoo/odoo.conf

# Step 6: Restart services
echo "Step 6: Restarting Odoo with rollback database..."
sudo systemctl start odoo

echo "Rollback completed successfully!"
echo "Current database: $ROLLBACK_DB"
echo "Failed migration database preserved as: $CURRENT_DB"