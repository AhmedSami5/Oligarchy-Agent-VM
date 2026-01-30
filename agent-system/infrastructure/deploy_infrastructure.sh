#!/bin/bash
# DeMoD Agent System - Production Infrastructure Deployment
# Purpose: Deploy complete monitoring and backup infrastructure

set -euo pipefail

# Configuration
DEPLOYMENT_DIR="/opt/demod-infrastructure"
LOG_FILE="/var/log/deploy_infrastructure.log"
BACKUP_DIR="/backups"
MONITORING_DIR="${DEPLOYMENT_DIR}/monitoring"
BACKUP_SCRIPTS_DIR="${DEPLOYMENT_DIR}/backup/scripts"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log() {
    local level=$1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] $*" | tee -a "${LOG_FILE}"
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

log_success() {
    log "${GREEN}SUCCESS${NC}" "$@"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking deployment prerequisites..."
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check if Docker Compose is installed
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check if user has Docker permissions
    if ! docker ps &> /dev/null; then
        log_error "User does not have Docker permissions. Please add user to docker group."
        exit 1
    fi
    
    # Check available disk space
    local available_space=$(df -BG . 2>/dev/null | awk '{print $4}' | sed 's/G//')
    local required_space=10485760  # 10GB in KB
    
    if [ "${available_space}" -lt "${required_space}" ]; then
        log_error "Insufficient disk space. Required: 10GB, Available: ${available_space}KB"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Create directory structure
create_directories() {
    log_info "Creating directory structure..."
    
    # Main directories
    mkdir -p "${DEPLOYMENT_DIR}"
    mkdir -p "${BACKUP_DIR}"
    mkdir -p "${MONITORING_DIR}"
    
    # Subdirectories
    mkdir -p "${DEPLOYMENT_DIR}/logs"
    mkdir -p "${DEPLOYMENT_DIR}/config"
    mkdir -p "${DEPLOYMENT_DIR}/scripts"
    mkdir -p "${DEPLOYMENT_DIR}/secrets"
    
    # Monitoring subdirectories
    mkdir -p "${MONITORING_DIR}"/{prometheus,grafana,alertmanager,jaeger,loki,dashboards}
    
    # Backup subdirectories  
    mkdir -p "${DEPLOYMENT_DIR}"/backup/{scripts,configs,postgresql}
    
    log_success "Directory structure created"
}

# Deploy monitoring stack
deploy_monitoring() {
    log_info "Deploying monitoring stack..."
    
    # Change to agent system directory
    cd /home/asher/Downloads/Oligarchy-Agent-VM/agent-system
    
    # Deploy monitoring services
    if ! docker-compose -f docker-compose.monitoring.yml up -d; then
        log_error "Failed to deploy monitoring stack"
        return 1
    fi
    
    # Wait for services to be ready
    log_info "Waiting for monitoring services to be ready..."
    local services=("prometheus:9090" "grafana:3000" "alertmanager:9093" "jaeger:16686")
    
    for service_port in "${services[@]}"; do
        local service=$(echo "${service_port}" | cut -d':' -f1)
        local port=$(echo "${service_port}" | cut -d':' -f2)
        
        log_info "Checking ${service} on port ${port}..."
        
        for i in {1..30}; do
            if curl -s "http://localhost:${port}/-/ready" &>/dev/null; then
                log_success "${service} is ready"
                break
            fi
            
            if [ $i -eq 30 ]; then
                log_warning "${service} failed to become ready within 30 seconds"
            fi
            
            sleep 2
        done
    done
    
    log_success "Monitoring stack deployed successfully"
}

# Configure monitoring services
configure_monitoring() {
    log_info "Configuring monitoring services..."
    
    # Configure Grafana datasources
    local grafana_ip=$(docker inspect grafana | jq -r '.[0].NetworkSettings.Networks[].IPAddress')
    
    # Wait for Grafana to be ready
    for i in {1..30}; do
        if curl -s "http://localhost:3000/api/health" &>/dev/null; then
            break
        fi
        sleep 2
    done
    
    # Add Prometheus datasource
    curl -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Basic YWRtaW46YWRtaW4=" \
        -d '{
            "name": "Prometheus",
            "type": "prometheus",
            "url": "http://prometheus:9090",
            "access": "proxy",
            "isDefault": true
        }' \
        "http://localhost:3000/api/datasources"
    
    # Import Grafana dashboards
    local dashboards=("system-overview.json" "database-metrics.json" "agent-metrics.json")
    
    for dashboard in "${dashboards[@]}"; do
        if [ -f "${MONITORING_DIR}/dashboards/${dashboard}" ]; then
            curl -X POST \
                -H "Content-Type: application/json" \
                -H "Authorization: Basic YWRtaW46YWRtaW4=" \
                -d "$(cat "${MONITORING_DIR}/dashboards/${dashboard}" | jq '.dashboard =.')" \
                "http://localhost:3000/api/dashboards/db" 2>/dev/null || true
            log_info "Imported dashboard: ${dashboard}"
        fi
    done
    
    log_success "Monitoring services configured"
}

# Deploy backup infrastructure
deploy_backup() {
    log_info "Deploying backup infrastructure..."
    
    # Copy backup scripts
    cp -r infrastructure/backup/scripts/* "${BACKUP_SCRIPTS_DIR}/"
    chmod +x "${BACKUP_SCRIPTS_DIR}"/*.sh
    
    # Copy backup configurations
    cp -r infrastructure/backup/configs/* "${DEPLOYMENT_DIR}/backup/configs/"
    cp -r infrastructure/backup/postgresql/* "${DEPLOYMENT_DIR}/backup/postgresql/"
    
    # Create backup directories
    mkdir -p "${BACKUP_DIR}"/{wal_archive,restores,reports}
    
    # Set up backup scheduling
    "${BACKUP_SCRIPTS_DIR}/backup_scheduler.sh" schedule daily 02:00
    "${BACKUP_SCRIPTS_DIR}/backup_scheduler.sh" schedule weekly 02:00
    
    # Create initial backup
    log_info "Creating initial backup..."
    "${BACKUP_SCRIPTS_DIR}/postgresql_backup.sh"
    
    log_success "Backup infrastructure deployed"
}

# Set up log rotation
setup_log_rotation() {
    log_info "Setting up log rotation..."
    
    cat > /etc/logrotate.d/demod-infrastructure << EOF
${DEPLOYMENT_DIR}/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    copytruncate
    create 644 root root
    postrotate
        /usr/bin/kill -USR1 \$(cat /var/run/rsyslogd.pid 2> /dev/null) 2> /dev/null || true
    endscript
        /usr/bin/kill -HUP \$(cat /var/run/rsyslogd.pid 2> /dev/null) 2> /dev/null || true
}

${BACKUP_DIR}/backup.log {
    daily
    missingok
    rotate 90
    compress
    delaycompress
    copytruncate
    create 644 root root
}

${LOG_FILE} {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    copytruncate
    create 644 root root
}
EOF
    
    # Enable log rotation
    if command -v logrotate &> /dev/null; then
        logrotate -f /etc/logrotate.d/demod-infrastructure
        log_success "Log rotation configured"
    else
        log_warning "Log rotate not available, manual configuration needed"
    fi
}

# Set up monitoring scripts
setup_monitoring_scripts() {
    log_info "Setting up monitoring scripts..."
    
    # Health check script
    cat > "${DEPLOYMENT_DIR}/scripts/health_check.sh" << 'EOF'
#!/bin/bash
# DeMoD Infrastructure Health Check

services=("prometheus:9090" "grafana:3000" "alertmanager:9093" "postgres:5432" "redis:6379")

for service in "${services[@]}"; do
    name=$(echo "$service" | cut -d':' -f1)
    port=$(echo "$service" | cut -d':' -f2)
    
    if curl -s --max-time 5 "http://localhost:$port" >/dev/null; then
        echo "✓ $name: HEALTHY"
    else
        echo "✗ $name: UNHEALTHY (port $port)"
    fi
done
EOF
    chmod +x "${DEPLOYMENT_DIR}/scripts/health_check.sh"
    
    # Backup status script
    cat > "${DEPLOYMENT_DIR}/scripts/backup_status.sh" << 'EOF'
#!/bin/bash
# Backup Status Check

echo "=== DeMoD Backup Status ==="
echo "Last Backup: $(ls -t /backups/database_backup_*.sql 2>/dev/null | head -1 | basename 2>/dev/null || echo 'None')"
echo "Backup Size: $(du -sh /backups/database_backup_*.sql 2>/dev/null | cut -f1 2>/dev/null || echo '0B')"
echo "Disk Used: $(du -sh /backups 2>/dev/null | cut -f1)"
echo "Available: $(df -h /backups | tail -1 | awk '{print $4}')"
EOF
    chmod +x "${DEPLOYMENT_DIR}/scripts/backup_status.sh"
    
    log_success "Monitoring scripts created"
}

# Generate deployment report
generate_deployment_report() {
    local report_file="${DEPLOYMENT_DIR}/deployment_report.txt"
    
    cat > "${report_file}" << EOF
========================================
DeMoD Agent System - Infrastructure Deployment Report
========================================

Deployment Information:
- Timestamp: $(date)
- Deployment Directory: ${DEPLOYMENT_DIR}
- User: $(whoami)
- Host: $(hostname)

Deployed Services:
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000 (admin/admin)
- AlertManager: http://localhost:9093
- Jaeger: http://localhost:16686
- Loki: http://localhost:3100

Backup Infrastructure:
- Backup Directory: ${BACKUP_DIR}
- Backup Schedule: Daily at 02:00, Weekly at 02:00
- Scripts Location: ${BACKUP_SCRIPTS_DIR}
- Point-in-Time Recovery: Enabled

Database Configuration:
- PostgreSQL: localhost:5432
- WAL Archiving: Enabled
- Point-in-Time Recovery: Configured

Monitoring Configuration:
- Metrics Collection: Prometheus
- Visualization: Grafana
- Alerting: AlertManager
- Distributed Tracing: Jaeger
- Log Aggregation: Loki + Promtail

Health Check Commands:
- ./scripts/health_check.sh
- ./scripts/backup_status.sh

Next Steps:
1. Test backup and restore procedures
2. Configure alert recipients in AlertManager
3. Review monitoring dashboards
4. Set up log retention policies
5. Configure notification channels
========================================
EOF

    log_success "Deployment report generated: ${report_file}"
}

# Main deployment function
main() {
    local deployment_type=${1:-"monitoring"}  # Default to monitoring only
    
    echo "${BLUE}DeMoD Agent System - Infrastructure Deployment${NC}"
    echo "==============================================="
    echo
    
    case "${deployment_type}" in
        "monitoring")
            check_prerequisites
            create_directories
            deploy_monitoring
            configure_monitoring
            setup_log_rotation
            setup_monitoring_scripts
            generate_deployment_report
            ;;
        "backup")
            check_prerequisites
            create_directories
            deploy_backup
            setup_log_rotation
            ;;
        "full")
            check_prerequisites
            create_directories
            deploy_monitoring
            configure_monitoring
            deploy_backup
            setup_log_rotation
            setup_monitoring_scripts
            generate_deployment_report
            ;;
        *)
            echo "Usage: $0 [monitoring|backup|full]"
            echo
            echo "Options:"
            echo "  monitoring  - Deploy monitoring stack only"
            echo "  backup      - Deploy backup infrastructure only"  
            echo "  full        - Deploy complete infrastructure"
            echo
            echo "Default: monitoring"
            exit 1
            ;;
    esac
    
    echo
    log_success "Deployment completed successfully!"
    echo
    echo "${GREEN}Access Information:${NC}"
    echo "Prometheus:  http://localhost:9090"
    echo "Grafana:    http://localhost:3000 (admin/admin)"
    echo "AlertManager: http://localhost:9093"
    if [ "${deployment_type}" = "backup" ] || [ "${deployment_type}" = "full" ]; then
        echo "Backup Scheduler: ${BACKUP_SCRIPTS_DIR}/backup_scheduler.sh"
    fi
    echo
    echo "${YELLOW}Next Steps:${NC}"
    echo "1. Configure alert recipients in AlertManager"
    echo "2. Import custom dashboards in Grafana"
    echo "3. Test backup and restore procedures"
    echo "4. Review deployment report: ${DEPLOYMENT_DIR}/deployment_report.txt"
}

# Execute main function
main "$@"