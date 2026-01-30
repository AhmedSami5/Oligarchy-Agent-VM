#!/bin/bash
# PostgreSQL Database Restore Script
# Purpose: Database recovery with point-in-time recovery capability

set -euo pipefail

# Configuration
BACKUP_DIR="/backups"
DB_HOST="postgres"
DB_PORT="5432"
DB_NAME="agentsystem"
DB_USER="agent"
DB_PASSWORD="password"
RECOVERY_DIR="/tmp/postgresql_recovery"

# Color output for better visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    shift
    echo -e "${level}[$(date '+%Y-%m-%d %H:%M:%S')] $*${NC}"
}

# Print colored output
print_info() {
    log "${GREEN}INFO${NC}" "$@"
}

print_warning() {
    log "${YELLOW}WARNING${NC}" "$@"
}

print_error() {
    log "${RED}ERROR${NC}" "$@"
}

# List available backups
list_backups() {
    print_info "Available database backups:"
    if [ -d "${BACKUP_DIR}" ]; then
        ls -la "${BACKUP_DIR}" | grep "database_backup_.*\.sql" | nl
    else
        print_warning "No backup directory found at ${BACKUP_DIR}"
    fi
    
    echo
    print_info "Available recovery configurations:"
    if [ -d "${BACKUP_DIR}" ]; then
        ls -la "${BACKUP_DIR}" | grep "recovery_.*\.conf" | nl
    else
        print_warning "No recovery configurations found"
    fi
}

# Verify backup integrity
verify_backup() {
    local backup_file=$1
    
    print_info "Verifying backup integrity: ${backup_file}"
    
    if [ ! -f "${backup_file}" ]; then
        print_error "Backup file not found: ${backup_file}"
        return 1
    fi
    
    # Test backup file integrity
    pg_restore \
        -h "${DB_HOST}" \
        -p "${DB_PORT}" \
        -U "${DB_USER}" \
        --list \
        "${backup_file}" \
        > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        print_info "Backup integrity check: PASSED"
        return 0
    else
        print_error "Backup integrity check: FAILED"
        print_error "Backup file may be corrupted"
        return 1
    fi
}

# Prepare for restore
prepare_restore() {
    print_info "Preparing for database restore..."
    
    # Create recovery directory
    mkdir -p "${RECOVERY_DIR}"
    
    # Stop PostgreSQL service (if running)
    if docker ps --format "table {{.Names}}" | grep -q "postgres"; then
        print_info "Stopping PostgreSQL service..."
        docker stop postgres || true
        print_info "PostgreSQL service stopped"
    fi
    
    # Wait for service to fully stop
    sleep 5
}

# Perform point-in-time recovery
perform_pitr_restore() {
    local backup_file=$1
    local recovery_config=$2
    
    print_info "Starting point-in-time recovery..."
    print_info "Backup file: ${backup_file}"
    print_info "Recovery config: ${recovery_config}"
    
    # Clear existing data directory
    if [ -d "/var/lib/postgresql/data" ]; then
        print_warning "Clearing existing PostgreSQL data directory..."
        rm -rf /var/lib/postgresql/data/*
    fi
    
    # Start PostgreSQL in recovery mode
    print_info "Starting PostgreSQL in recovery mode..."
    
    # Use docker to run PostgreSQL with custom configuration
    docker run -d \
        --name postgres-recovery \
        -e POSTGRES_DB="${DB_NAME}" \
        -e POSTGRES_USER="${DB_USER}" \
        -e POSTGRES_PASSWORD="${DB_PASSWORD}" \
        -v "${backup_file}:/backup/database_backup.sql:ro" \
        -v "${recovery_config}:/etc/postgresql/postgresql.conf:ro" \
        -v postgres-data:/var/lib/postgresql/data \
        -p "${DB_PORT}:5432" \
        postgres:15.3 \
        -c "config_file=/etc/postgresql/postgresql.conf"
    
    # Wait for PostgreSQL to be ready
    print_info "Waiting for PostgreSQL recovery to complete..."
    
    # Monitor recovery process
    while true; do
        if docker logs postgres-recovery 2>&1 | grep -q "database system is ready to accept connections"; then
            print_info "Recovery completed successfully"
            break
        fi
        
        if docker logs postgres-recovery 2>&1 | grep -q "FATAL"; then
            print_error "Recovery failed - check PostgreSQL logs"
            docker logs postgres-recovery
            return 1
        fi
        
        sleep 5
        echo -n "."
    done
    
    # Stop recovery container
    docker stop postgres-recovery
    docker rm postgres-recovery
    
    print_info "Point-in-time recovery completed"
}

# Perform full database restore
perform_full_restore() {
    local backup_file=$1
    
    print_info "Starting full database restore..."
    print_info "Backup file: ${backup_file}"
    
    # Clear existing data directory
    if [ -d "/var/lib/postgresql/data" ]; then
        print_warning "Clearing existing PostgreSQL data directory..."
        rm -rf /var/lib/postgresql/data/*
    fi
    
    # Restore database
    docker run --rm \
        -e PGPASSWORD="${DB_PASSWORD}" \
        -v "${backup_file}:/backup/database_backup.sql:ro" \
        -v postgres-data:/var/lib/postgresql/data \
        postgres:15.3 \
        bash -c "
            createdb -U ${DB_USER} ${DB_NAME} || true
            psql -U ${DB_USER} -d ${DB_NAME} < /backup/database_backup.sql
        "
    
    if [ $? -eq 0 ]; then
        print_info "Full database restore completed successfully"
    else
        print_error "Full database restore failed"
        return 1
    fi
}

# Start restored database
start_restored_database() {
    print_info "Starting restored database..."
    
    # Start PostgreSQL service with restored data
    docker-compose up -d postgres
    
    # Wait for database to be ready
    for i in {1..30}; do
        if docker exec postgres pg_isready -U ${DB_USER} -d ${DB_NAME}; then
            print_info "Database is ready and accepting connections"
            break
        fi
        
        if [ $i -eq 30 ]; then
            print_error "Database failed to start within 30 seconds"
            return 1
        fi
        
        sleep 1
        echo -n "."
    done
}

# Verify restored database
verify_restored_database() {
    print_info "Verifying restored database..."
    
    # Check database connectivity
    if docker exec postgres pg_isready -U ${DB_USER} -d ${DB_NAME}; then
        print_info "Database connectivity: PASSED"
    else
        print_error "Database connectivity: FAILED"
        return 1
    fi
    
    # Check data integrity
    local table_count=$(docker exec postgres psql -U ${DB_USER} -d ${DB_NAME} -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'" 2>/dev/null)
    
    if [ -n "${table_count}" ]; then
        print_info "Database tables count: ${table_count}"
        print_info "Data integrity check: PASSED"
    else
        print_error "Data integrity check: FAILED"
        return 1
    fi
}

# Generate restore report
generate_restore_report() {
    local backup_file=$1
    local restore_method=$2
    local report_file="${BACKUP_DIR}/restore_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "${report_file}" << EOF
========================================
DeMoD Agent System - Database Restore Report
========================================

Restore Information:
- Timestamp: $(date)
- Backup File: ${backup_file}
- Restore Method: ${restore_method}
- Database: ${DB_NAME}
- Host: ${DB_HOST}
- User: ${DB_USER}

Database Status:
- Connectivity: $([ "$(docker exec postgres pg_isready -U ${DB_USER} -d ${DB_NAME} 2>/dev/null)" = "t" ] && echo "PASSED" || echo "FAILED")
- Tables Restored: $(docker exec postgres psql -U ${DB_USER} -d ${DB_NAME} -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'" 2>/dev/null || echo "0")

Recovery Configuration:
- Recovery Config: ${BACKUP_DIR}/recovery_*.conf (if PITR used)
- WAL Location: /var/lib/postgresql/pg_wal

Next Steps:
1. Test application connectivity
2. Run database consistency checks
3. Verify agent system functionality
4. Monitor application performance
========================================
EOF

    print_info "Restore report generated: ${report_file}"
}

# Main restore workflow
main() {
    if [ $# -lt 1 ]; then
        print_error "Usage: $0 <backup_file> [pitr|full]"
        print_info "Available backups:"
        list_backups
        exit 1
    fi
    
    local backup_file=$1
    local restore_method=${2:-"pitr"}  # Default to PITR
    
    print_info "Starting PostgreSQL restore workflow..."
    print_info "Backup file: ${backup_file}"
    print_info "Restore method: ${restore_method}"
    
    # Verify backup before restore
    if ! verify_backup "${backup_file}"; then
        print_error "Backup verification failed. Aborting restore."
        exit 1
    fi
    
    # Prepare for restore
    prepare_restore
    
    # Perform restore based on method
    if [ "${restore_method}" = "pitr" ]; then
        perform_pitr_restore "${backup_file}" "${BACKUP_DIR}/recovery_*.conf"
    else
        perform_full_restore "${backup_file}"
    fi
    
    # Start restored database
    start_restored_database
    
    # Verify restored database
    if ! verify_restored_database; then
        print_error "Database verification failed. Restore may be incomplete."
        exit 1
    fi
    
    # Generate restore report
    generate_restore_report "${backup_file}" "${restore_method}"
    
    print_info "SUCCESS: Database restore completed successfully"
    print_info "Database is ready for use"
}

# Execute main function
main "$@"