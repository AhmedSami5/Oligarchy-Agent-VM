#!/bin/bash
# Automated Backup Scheduler for DeMoD Agent System
# Purpose: Schedule and manage database backups with monitoring

set -euo pipefail

# Configuration
BACKUP_SCRIPT_DIR="/infrastructure/backup/scripts"
BACKUP_LOG_FILE="/var/log/backup_scheduler.log"
SCHEDULE_FILE="/var/log/backup_schedule.conf"
BACKUP_LOCK_FILE="/var/run/backup.lock"
EMAIL_RECIPIENTS="ops-team@demod-agent.com"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging function
log() {
    local level=$1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] $*" | tee -a "${BACKUP_LOG_FILE}"
}

log_info() {
    log "INFO" "$@"
}

log_warning() {
    log "WARNING" "$@"
}

log_error() {
    log "ERROR" "$@"
}

# Send notification
send_notification() {
    local subject=$1
    local message=$2
    
    if [ -n "${EMAIL_RECIPIENTS}" ]; then
        echo "${message}" | mail -s "${subject}" "${EMAIL_RECIPIENTS}"
        log_info "Notification sent: ${subject}"
    fi
}

# Check if backup is already running
check_backup_lock() {
    if [ -f "${BACKUP_LOCK_FILE}" ]; then
        local pid=$(cat "${BACKUP_LOCK_FILE}")
        if kill -0 "${pid}" 2>/dev/null; then
            log_warning "Backup already running (PID: ${pid})"
            return 1
        else
            log_warning "Removing stale lock file (PID ${pid} not running)"
            rm -f "${BACKUP_LOCK_FILE}"
        fi
    fi
    return 0
}

# Create backup lock
create_backup_lock() {
    echo $$ > "${BACKUP_LOCK_FILE}"
    log_info "Backup lock created (PID: $$)"
}

# Remove backup lock
remove_backup_lock() {
    rm -f "${BACKUP_LOCK_FILE}"
    log_info "Backup lock removed"
}

# Schedule backup job
schedule_backup() {
    local schedule_type=$1  # daily, weekly, monthly
    local backup_time=${2:-"02:00"}  # Default 2 AM
    
    log_info "Scheduling backup: ${schedule_type} at ${backup_time}"
    
    # Create cron job based on schedule type
    case "${schedule_type}" in
        "daily")
            (crontab -l 2>/dev/null; echo "${backup_time} * * * ${PWD}/${BACKUP_SCRIPT_DIR}/postgresql_backup.sh daily >> ${SCHEDULE_FILE}") | crontab -
            ;;
        "weekly")
            (crontab -l 2>/dev/null; echo "${backup_time} * * 0 ${PWD}/${BACKUP_SCRIPT_DIR}/postgresql_backup.sh weekly >> ${SCHEDULE_FILE}") | crontab -
            ;;
        "monthly")
            (crontab -l 2>/dev/null; echo "${backup_time} 1 * * ${PWD}/${BACKUP_SCRIPT_DIR}/postgresql_backup.sh monthly >> ${SCHEDULE_FILE}") | crontab -
            ;;
        *)
            log_error "Invalid schedule type: ${schedule_type}. Use: daily, weekly, monthly"
            return 1
            ;;
    esac
    
    log_info "Backup scheduled successfully"
    crontab -l | grep "postgresql_backup" > "${SCHEDULE_FILE}"
}

# Run scheduled backup
run_scheduled_backup() {
    local backup_type=${1:-"daily"}
    
    log_info "Starting scheduled backup: ${backup_type}"
    
    # Check if backup is already running
    if check_backup_lock; then
        log_warning "Skipping scheduled backup - previous backup still running"
        return 0
    fi
    
    # Create lock
    create_backup_lock
    
    # Run backup script
    local backup_script="${PWD}/${BACKUP_SCRIPT_DIR}/postgresql_backup.sh"
    if [ -x "${backup_script}" ]; then
        local start_time=$(date +%s)
        
        # Execute backup
        "${backup_script}" "${backup_type}"
        local backup_result=$?
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        # Log result
        if [ ${backup_result} -eq 0 ]; then
            log_info "Scheduled backup completed successfully (${backup_type})"
            send_notification "SUCCESS: ${backup_type} Backup Completed" "The ${backup_type} database backup completed successfully in ${duration} seconds."
        else
            log_error "Scheduled backup failed (${backup_type})"
            send_notification "ALERT: ${backup_type} Backup Failed" "The ${backup_type} database backup failed after ${duration} seconds. Check logs for details."
        fi
    else
        log_error "Backup script not found or not executable: ${backup_script}"
        return 1
    fi
    
    # Remove lock
    remove_backup_lock
}

# Monitor backup progress
monitor_backup_progress() {
    local backup_pid=$1
    
    log_info "Monitoring backup progress (PID: ${backup_pid})"
    
    while kill -0 "${backup_pid}" 2>/dev/null; do
        # Check if backup script is still running
        if ! kill -0 "${backup_pid}" 2>/dev/null; then
            log_info "Backup process ended"
            break
        fi
        
        # Check backup file size growth
        local latest_backup=$(ls -t /backups/database_backup_*.sql 2>/dev/null | head -1)
        if [ -n "${latest_backup}" ] && [ -f "${latest_backup}" ]; then
            local backup_size=$(du -h "${latest_backup}" | cut -f1)
            log_info "Current backup size: ${backup_size}"
        fi
        
        sleep 30
    done
}

# Backup health check
backup_health_check() {
    log_info "Running backup health check..."
    
    local backup_count=$(find /backups -name "database_backup_*.sql" -mtime -7 | wc -l)
    local latest_backup=$(find /backups -name "database_backup_*.sql" -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2)
    local latest_age=0
    
    if [ -n "${latest_backup}" ]; then
        local current_time=$(date +%s)
        local backup_time=$(date -r "${latest_backup}" +%s 2>/dev/null)
        latest_age=$((current_time - backup_time))
    fi
    
    # Check backup health
    if [ ${backup_count} -lt 7 ]; then
        log_warning "Low backup count: ${backup_count} backups in last 7 days"
        send_notification "WARNING: Low Backup Count" "Only ${backup_count} backups found in the last 7 days. Expected minimum 7."
    fi
    
    if [ ${latest_age} -gt 172800 ]; then  # 48 hours in seconds
        log_warning "Old backup detected: Latest backup is ${latest_age} seconds old"
        send_notification "WARNING: Old Backup" "Latest database backup is ${latest_age} seconds old. Please check backup schedule."
    fi
    
    # Check backup disk space
    local backup_dir_size=$(du -sh /backups 2>/dev/null | cut -f1)
    local available_space=$(df -h /backups 2>/dev/null | awk 'NR==2 {print $4}')
    
    log_info "Backup directory size: ${backup_dir_size}"
    log_info "Available disk space: ${available_space}"
    
    if [ "${available_space: -1}" -lt 20 ]; then  # Less than 20GB available
        log_warning "Low disk space for backups: ${available_space} available"
        send_notification "ALERT: Low Disk Space" "Backup directory has only ${available_space} space remaining."
    fi
    
    log_info "Backup health check completed"
}

# Cleanup old backups
cleanup_old_backups() {
    local retention_days=${1:-30}
    
    log_info "Cleaning up old backups (retention: ${retention_days} days)..."
    
    # Remove old database backups
    find /backups -name "database_backup_*.sql" -mtime +${retention_days} -exec rm -f {} \;
    local removed_count=$(find /backups -name "database_backup_*.sql" -mtime +${retention_days} | wc -l)
    
    # Remove old WAL backups
    find /backups -name "wal_backup_*" -mtime +${retention_days} -exec rm -rf {} \;
    
    log_info "Cleanup completed: ${removed_count} old backups removed"
}

# Generate backup schedule report
generate_schedule_report() {
    local report_file="/var/log/backup_schedule_report.txt"
    
    cat > "${report_file}" << EOF
========================================
DeMoD Agent System - Backup Schedule Report
========================================

Current Schedule:
$(cat "${SCHEDULE_FILE}" 2>/dev/null || echo "No active schedule")

Recent Backups (Last 7 days):
$(find /backups -name "database_backup_*.sql" -mtime -7 -ls -lh 2>/dev/null || echo "No recent backups found")

Backup Statistics:
- Total Backups: $(find /backups -name "database_backup_*.sql" | wc -l)
- Recent Backups (7 days): $(find /backups -name "database_backup_*.sql" -mtime -7 | wc -l)
- Backup Directory Size: $(du -sh /backups 2>/dev/null | cut -f1)
- Available Disk Space: $(df -h /backups 2>/dev/null | awk 'NR==2 {print $4}')

System Health:
- Last Health Check: $(tail -5 /var/log/backup_scheduler.log 2>/dev/null | grep "health check" | tail -1)
- Cron Jobs: $(crontab -l | grep -c "postgresql_backup")

Recommendations:
1. Monitor backup success rates
2. Ensure adequate disk space
3. Test restore procedures regularly
4. Review backup retention policy
========================================
EOF

    log_info "Schedule report generated: ${report_file}"
}

# Main function
main() {
    case "${1:-help}" in
        "schedule")
            if [ $# -ne 3 ]; then
                echo "Usage: $0 schedule <daily|weekly|monthly> <time>"
                echo "Example: $0 schedule daily 02:00"
                exit 1
            fi
            schedule_backup "$2" "$3"
            ;;
        "run")
            run_scheduled_backup "$2"
            ;;
        "monitor")
            if [ $# -ne 2 ]; then
                echo "Usage: $0 monitor <backup_pid>"
                exit 1
            fi
            monitor_backup_progress "$2"
            ;;
        "health")
            backup_health_check
            ;;
        "cleanup")
            cleanup_old_backups "$2"
            ;;
        "report")
            generate_schedule_report
            ;;
        "help"|*)
            echo "DeMoD Agent System - Backup Scheduler"
            echo
            echo "Usage: $0 <command> [options]"
            echo
            echo "Commands:"
            echo "  schedule <daily|weekly|monthly> <time>  Schedule regular backups"
            echo "  run [type]                            Run scheduled backup"
            echo "  monitor <pid>                         Monitor backup progress"
            echo "  health                                Run backup health check"
            echo "  cleanup [days]                        Clean up old backups"
            echo "  report                                Generate schedule report"
            echo "  help                                  Show this help"
            echo
            echo "Examples:"
            echo "  $0 schedule daily 02:00              # Schedule daily backup at 2 AM"
            echo "  $0 run daily                           # Run daily backup now"
            echo "  $0 health                                # Check backup health"
            exit 0
            ;;
    esac
}

# Execute main function
main "$@"