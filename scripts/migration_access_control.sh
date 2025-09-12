#!/bin/bash
# Temporary access control for migration activities

create_migration_user() {
    local username="$1"
    local access_level="$2"
    local duration_hours="$3"
    local justification="$4"
    
    echo "Creating temporary migration access for $username"
    echo "Access level: $access_level"
    echo "Duration: $duration_hours hours" 
    echo "Justification: $justification"
    
    # Create temporary PostgreSQL user
    sudo -u postgres createuser "$username"
    
    case $access_level in
        "read_only")
            sudo -u postgres psql -c "GRANT CONNECT ON DATABASE production_new TO $username;"
            sudo -u postgres psql -c "GRANT USAGE ON SCHEMA public TO $username;"
            sudo -u postgres psql -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO $username;"
            ;;
        "data_migration")
            sudo -u postgres psql -c "GRANT CONNECT ON DATABASE production_new TO $username;"
            sudo -u postgres psql -c "GRANT USAGE ON SCHEMA public TO $username;"
            sudo -u postgres psql -c "GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO $username;"
            ;;
        "admin")
            sudo -u postgres psql -c "ALTER USER $username CREATEDB;"
            sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE production_new TO $username;"
            ;;
    esac
    
    # Set automatic expiration
    echo "sudo -u postgres dropuser $username" | at now + $duration_hours hours
    
    # Log access creation
    echo "$(date): Created migration access for $username ($access_level) expires in $duration_hours hours" >> /var/log/migration_access.log
}

revoke_migration_access() {
    local username="$1"
    
    echo "Revoking migration access for $username"
    sudo -u postgres dropuser "$username"
    
    # Log access revocation
    echo "$(date): Revoked migration access for $username" >> /var/log/migration_access.log
}

audit_migration_access() {
    echo "=== Current Migration Access Audit ==="
    echo "Active database users:"
    sudo -u postgres psql -c "\du"
    
    echo "Active system sessions:"
    who
    
    echo "Recent access log:"
    tail -20 /var/log/migration_access.log
}

# Example usage:
# create_migration_user "consultant_john" "read_only" 8 "Data validation during migration"
# create_migration_user "dba_sarah" "data_migration" 24 "Database schema migration"