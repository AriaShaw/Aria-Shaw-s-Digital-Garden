#!/bin/bash
DB_NAME="production"

echo "Starting database maintenance..."

# Analyze tables for better query planning
sudo -u postgres psql $DB_NAME -c "ANALYZE;"

# Vacuum tables to reclaim space
sudo -u postgres psql $DB_NAME -c "VACUUM ANALYZE;"

# Reindex for better performance  
sudo -u postgres psql $DB_NAME -c "REINDEX DATABASE $DB_NAME;"

echo "Database maintenance completed"