#!/bin/bash
# PostgreSQL Database Backup Script
# Purpose: Automated database backups with point-in-time recovery capability

set -euo pipefail

# Configuration
BACKUP_DIR="/backups"
RETENTION_DAYS=30
DB_HOST="postgres"
DB_PORT="5432"
DB_NAME="agentsystem"
DB_USER="agent"
DB_PASSWORD="password"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/database_backup_${TIMESTAMP}.sql"
WAL_BACKUP_DIR="${BACKUP_DIR}/wal_backup_${TIMESTAMP}"

# Create backup directory
mkdir -p "${BACKUP_DIR}"
mkdir -p "${WAL_BACKUP_DIR}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${BACKUP_DIR}/backup.log"
}

# Check database connection
check_database_connection() {
    log "Checking database connection..."
    if ! pg_isready -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}"; then
        log "ERROR: Database is not ready for backup"
        exit 1
    fi
    log "Database connection verified"
}

# Create database backup
create_database_backup() {
    log "Starting database backup..."
    
    # Create consistent backup using pg_dump with custom format
    pg_dump \
        -h "${DB_HOST}" \
        -p "${DB_PORT}" \
        -U "${DB_USER}" \
        -d "${DB_NAME}" \
        -F custom \
        -Z 9 \
        -f "${BACKUP_FILE}" \
        --verbose \
        --lock-wait-timeout=30000
    
    if [ $? -eq 0 ]; then
        log "SUCCESS: Database backup created: ${BACKUP_FILE}"
        log "Backup size: $(du -h "${BACKUP_FILE}" | cut -f1)"
    else
        log "ERROR: Database backup failed"
        exit 1
    fi
}

# Backup WAL files for point-in-time recovery
backup_wal_files() {
    log "Starting WAL files backup..."
    
    # Archive current WAL files
    pg_receivewal \
        -h "${DB_HOST}" \
        -p "${DB_PORT}" \
        -U "${DB_USER}" \
        -D "${DB_NAME}" \
        -d "${WAL_BACKUP_DIR}" \
        --no-sync
    
    if [ $? -eq 0 ]; then
        log "SUCCESS: WAL backup completed: ${WAL_BACKUP_DIR}"
    else
        log "ERROR: WAL backup failed"
        exit 1
    fi
}

# Create recovery configuration
create_recovery_config() {
    local recovery_file="${BACKUP_DIR}/recovery_${TIMESTAMP}.conf"
    
    cat > "${recovery_file}" << EOF
# PostgreSQL Recovery Configuration
# Generated: $(date)
# Purpose: Point-in-time recovery configuration

# Restore commands
# 1. Stop PostgreSQL service
# 2. Copy this file to postgresql.conf
# 3. Copy WAL backup to pg_wal directory
# 4. Start PostgreSQL in recovery mode
# 5. After recovery, create backup

# Recovery target settings
restore_command = 'cp "${WAL_BACKUP_DIR}/%f" %p'
archive_cleanup_command = 'rm "${WAL_BACKUP_DIR}/%f"'

# Point-in-time recovery (uncomment and modify as needed)
# recovery_target_time = '2024-01-01T12:00:00'
# recovery_target_xid = '12345'

# Recovery target name (alternative to time/XID)
# recovery_target_name = 'before_maintenance'

# Uncomment for standby recovery
# standby_mode = 'on'
EOF

    log "SUCCESS: Recovery configuration created: ${recovery_file}"
}

# Verify backup integrity
verify_backup() {
    log "Verifying backup integrity..."
    
    if [ -f "${BACKUP_FILE}" ]; then
        # Check if backup file is readable and has content
        if [ -s "${BACKUP_FILE}" ]; then
            log "SUCCESS: Backup file verified and accessible"
            
            # Test restore (dry run)
            pg_restore \
                -h "${DB_HOST}" \
                -p "${DB_PORT}" \
                -U "${DB_USER}" \
                -d test_restore_db \
                --list \
                "${BACKUP_FILE}" \
                > /dev/null 2>&1
            
            if [ $? -eq 0 ]; then
                log "SUCCESS: Backup integrity check passed"
            else
                log "WARNING: Backup integrity check failed - backup may be corrupted"
            fi
        else
            log "ERROR: Backup file is empty"
            exit 1
        fi
    else
        log "ERROR: Backup file not found"
        exit 1
    fi
}

# Cleanup old backups
cleanup_old_backups() {
    log "Cleaning up old backups (retention: ${RETENTION_DAYS} days)..."
    
    # Remove old database backups
    find "${BACKUP_DIR}" -name "database_backup_*.sql" -mtime +${RETENTION_DAYS} -exec rm -f {} \;
    find "${BACKUP_DIR}" -name "recovery_*.conf" -mtime +${RETENTION_DAYS} -exec rm -f {} \;
    
    # Remove old WAL backups (keep only latest 5)
    cd "${BACKUP_DIR}"
    ls -1t | grep "wal_backup_" | tail -n +6 | xargs -r rm -rf
    
    log "SUCCESS: Old backup cleanup completed"
}

# Generate backup report
generate_backup_report() {
    local report_file="${BACKUP_DIR}/backup_report_${TIMESTAMP}.txt"
    
    cat > "${report_file}" << EOF
========================================
DeMoD Agent System - Database Backup Report
========================================

Backup Information:
- Timestamp: $(date)
- Backup File: ${BACKUP_FILE}
- WAL Directory: ${WAL_BACKUP_DIR}
- Database: ${DB_NAME}
- Host: ${DB_HOST}
- User: ${DB_USER}

Backup Statistics:
- Backup Size: $(du -h "${BACKUP_FILE}" | cut -f1)
- WAL Files Count: $(find "${WAL_BACKUP_DIR}" -name "*.gz" | wc -l)
- Total Size: $(du -sh "${BACKUP_DIR}" | cut -f1)

Recovery Information:
- Recovery Config: ${BACKUP_DIR}/recovery_${TIMESTAMP}.conf
- Point-in-Time Recovery: Available via WAL backup
- Testing Command: pg_restore -l "${BACKUP_FILE}"

Maintenance:
- Retention Policy: ${RETENTION_DAYS} days
- Next Scheduled Backup: $(date -d "+1 hour" +"%Y-%m-%d %H:%M:%S")
========================================
EOF

    log "SUCCESS: Backup report generated: ${report_file}"
}

# Main backup workflow
main() {
    log "Starting PostgreSQL backup workflow..."
    
    check_database_connection
    create_database_backup
    backup_wal_files
    create_recovery_config
    verify_backup
    cleanup_old_backups
    generate_backup_report
    
    log "SUCCESS: Backup workflow completed successfully"
    log "Backup available at: ${BACKUP_FILE}"
    log "Recovery config at: ${BACKUP_DIR}/recovery_${TIMESTAMP}.conf"
}

# Execute main function
main "$@"