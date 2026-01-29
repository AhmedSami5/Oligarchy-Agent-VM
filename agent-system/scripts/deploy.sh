#!/bin/bash
# ========================================
# deploy.sh - Deployment automation for DeMoD Agent System
# ========================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to print colored output
print_status() {
    echo -e "${BLUE}=== $1 ===${NC}"
    echo -e "${NC}$2${NC}"
    echo -e "${NC}$3${NC}"
}

# Function to print error and exit
error_exit() {
    echo -e "${RED}ERROR: $1${NC}"
    echo -e "${RED}$2${NC}"
    exit 1
}

# Function to print success message
success_message() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
    echo -e "${GREEN}$2${NC}"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="demod-agent-system"
ENVIRONMENT="${DEPLOYMENT_ENV:-development}"
DOCKER_REGISTRY="${DOCKER_REGISTRY:-localhost:5000}"

echo "Deploying ${PROJECT_NAME} to ${ENVIRONMENT} environment"

# Parse command line arguments
FORCE_BUILD=false
SKIP_TESTS=false
SKIP_DOCS=false
SKIP_BUILD=false
SKIP_DEPLOY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force-build) FORCE_BUILD=true; shift ;;
        --skip-tests) SKIP_TESTS=true; shift ;;
        --skip-docs) SKIP_DOCS=true; shift ;;
        --skip-build) SKIP_BUILD=true; shift ;;
        --skip-deploy) SKIP_DEPLOY=true; shift ;;
        --*) error_exit "Unknown option: $1" ;;
    esac
done

# ========================================
# Environment-specific Configuration
# ========================================

case "$ENVIRONMENT" in
    "development")
        DEPLOY_COMMAND="docker-compose -f docker-compose.yml up -d"
        HEALTH_CHECK_URL="http://localhost:8000/health"
        API_URL="http://localhost:8000"
        ;;
    "staging")
        DEPLOY_COMMAND="docker-compose -f docker-compose.staging.yml up -d"
        HEALTH_CHECK_URL="https://staging-api.demod.com/health"
        API_URL="https://staging-api.demod.com"
        ;;
    "production")
        DEPLOY_COMMAND="docker-compose -f docker-compose.prod.yml up -d"
        HEALTH_CHECK_URL="https://agent-api.demod.com/health"
        API_URL="https://agent-api.demod.com"
        ;;
    "aws")
        DEPLOY_COMMAND="cd deployment/terraform/aws && terraform apply -auto-approve"
        HEALTH_CHECK_URL="https://agent-api.demod.com/health"
        API_URL="https://agent-api.demod.com"
        ;;
    "azure")
        DEPLOY_COMMAND="cd deployment/terraform/azure && terraform apply -auto-approve"
        HEALTH_CHECK_URL="https://agent-api.demod.com/health"
        API_URL="https://agent-api.demod.com"
        ;;
    "gcp")
        DEPLOY_COMMAND="cd deployment/terraform/gcp && terraform apply -auto-approve"
        HEALTH_CHECK_URL="https://agent-api.demod.com/health"
        API_URL="https://agent-api.demod.com"
        ;;
    *)
        error_exit "Unknown environment: $ENVIRONMENT. Use one of: development, staging, production, aws, azure, gcp"
        ;;
esac

# ========================================
# Deployment Functions
# ========================================

check_environment() {
    print_status "Checking $ENVIRONMENT environment"
    
    case "$ENVIRONMENT" in
        "development"|"staging"|"production")
            # Check if configuration file exists
            if [ ! -f "configs/${ENVIRONMENT}.yaml" ]; then
                error_exit "Configuration file configs/${ENVIRONMENT}.yaml not found"
            fi
            ;;
        "aws"|"azure"|"gcp")
            # Check cloud CLI tools
            case "$ENVIRONMENT" in
                "aws")
                    if ! command -v aws &> /dev/null; then
                        error_exit "AWS CLI not installed"
                    fi
                    ;;
                "azure")
                    if ! command -v az &> /dev/null; then
                        error_exit "Azure CLI not installed"
                    fi
                    ;;
                "gcp")
                    if ! command -v gcloud &> /dev/null; then
                        error_exit "GCloud CLI not installed"
                    fi
                    ;;
            esac
            ;;
    esac
    
    success_message "$ENVIRONMENT environment check passed"
}

build_and_test() {
    if [ "$SKIP_BUILD" = false ]; then
        print_status "Building and testing"
        "$SCRIPT_DIR/scripts/build.sh" "local"
        
        if [ $? -ne 0 ]; then
            error_exit "Build failed"
        fi
    fi
    
    if [ "$SKIP_TESTS" = false ]; then
        print_status "Running tests"
        "$SCRIPT_DIR/scripts/build.sh" "tests"
        
        if [ $? -ne 0 ]; then
            error_exit "Tests failed"
        fi
    fi
    
    success_message "Build and test phase completed"
}

deploy_services() {
    if [ "$SKIP_DEPLOY" = false ]; then
        print_status "Deploying to $ENVIRONMENT"
        
        cd "$SCRIPT_DIR"
        
        # Deploy based on environment type
        if [[ "$ENVIRONMENT" =~ ^(development|staging|production)$ ]]; then
            # Docker Compose deployment
            eval "$DEPLOY_COMMAND"
            
            # Wait for services to be ready
            echo "Waiting for services to be ready..."
            sleep 30
            
            # Health check
            max_attempts=30
            attempt=1
            
            while [ $attempt -le $max_attempts ]; do
                if curl -s "$HEALTH_CHECK_URL" > /dev/null 2>&1; then
                    success_message "Services are ready (attempt $attempt/$max_attempts)"
                    break
                fi
                
                echo "Health check attempt $attempt/$max_attempts..."
                sleep 2
                ((attempt++))
            done
            
            if [ $attempt -gt $max_attempts ]; then
                error_exit "Services failed to become ready after $max_attempts attempts"
            fi
            
        else
            # Terraform deployment
            print_status "Deploying cloud infrastructure"
            
            cd "deployment/terraform/${ENVIRONMENT}"
            
            # Initialize Terraform if needed
            if [ ! -f ".terraform/terraform.tfstate" ]; then
                terraform init
            fi
            
            # Plan and apply
            terraform plan
            read -p "Continue with deployment? [y/N] " -r
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                terraform apply -auto-approve
            else
                echo "Deployment cancelled"
                exit 0
            fi
        fi
        
        success_message "Deployment to $ENVIRONMENT completed"
    fi
}

setup_monitoring() {
    print_status "Setting up monitoring"
    
    # Configure local monitoring tools if available
    if command -v docker-compose &> /dev/null; then
        # Set up monitoring stack
        cat > docker-compose.monitoring.yml << 'EOF
version: "3.8"

services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus
    
  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    volumes:
      - ./monitoring/grafana/provisioning:/etc/grafana/provisioning
    depends_on:
      - prometheus
    
  agent-system:
    image: ${DOCKER_REGISTRY}/${PROJECT_NAME}:latest
    ports:
      - "8000:8000"
    depends_on:
      - prometheus
    environment:
      - METRICS_PORT: 9090
      - HEALTH_CHECK_URL: $HEALTH_CHECK_URL
EOF
        
        # Create Grafana provisioning
        mkdir -p monitoring/grafana/provisioning/dashboards
        cat > monitoring/grafana/provisioning/dashboards/agent-system.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "DeMoD Agent System",
    "tags": ["agent-system", "demod"],
    "timezone": "browser",
    "panels": [
      {
        "id": "agent-metrics",
        "name": "Agent Metrics",
        "type": "graph",
        "targets": [
          {
            "expr": "sum(rate(apiserver_http_requests_total[5m]))",
            "refId": "A"
          },
          {
            "expr": "sum(rate(apiserver_http_requests_total[5m]))",
            "refId": "A"
          }
        ]
      }
    ]
  }
}
EOF
        
        docker-compose -f docker-compose.monitoring.yml up -d
        
        success_message "Monitoring stack deployed"
    else
        echo "Docker Compose not available, skipping monitoring setup"
    fi
}

post_deployment_tasks() {
    print_status "Running post-deployment tasks"
    
    # Smoke test the deployment
    echo "Performing smoke tests..."
    
    if curl -s "$API_URL/health" > /dev/null 2>&1; then
        success_message "Smoke test passed"
    else
        error_exit "Smoke test failed"
    fi
    
    # Load initial agents
    echo "Creating initial agents..."
    
    AGENT_TYPES=("aider" "opencode" "claude")
    for agent_type in "${AGENT_TYPES[@]}"; do
        echo "Creating $agent_type agent..."
        
        response=$(curl -s -X POST "$API_URL/agents/create" \
            -H "Content-Type: application/json" \
            -H "X-API-Key: $AGENTVM_API_KEY" \
            -d "{\"agent_type\": \"$agent_type\"}" \
            2>&1)
        
        if echo "$response" | grep -q "\"success\":true"; then
            success_message "$agent_type agent created successfully"
        else
            echo "Warning: Failed to create $agent_type agent"
        fi
    done
    
    success_message "Post-deployment tasks completed"
}

# ========================================
# Rollback Functions
# ========================================

rollback_terraform() {
    print_status "Rolling back Terraform deployment"
    
    cd "$SCRIPT_DIR/deployment/terraform/${ENVIRONMENT}"
    
    if [ ! -f ".terraform/terraform.tfstate" ]; then
        echo "No Terraform state found, nothing to rollback"
        return
    fi
    
    echo "Rolling back changes..."
    terraform plan
    
    read -p "Continue with rollback? [y/N] " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        terraform destroy -auto-approve
        
        if [ $? -eq 0 ]; then
            success_message "Rollback completed successfully"
        else
            echo "Rollback cancelled"
            exit 0
        else
        echo "No rollback needed"
    fi
}

rollback_docker() {
    print_status "Rolling back Docker deployment"
    
    # Stop services
    docker-compose -f "docker-compose.yml" down
    
    # Remove volumes if they exist
    docker volume rm agent-system_logs 2>/dev/null || true
    docker volume rm agent_system_data 2>/dev/null || true
    
    echo "Docker rollback completed"
}

# ========================================
# Health Verification
# ========================================

verify_deployment() {
    print_status "Verifying deployment"
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "Health check attempt $attempt/$max_attempts..."
        
        if curl -s "$HEALTH_CHECK_URL" > /dev/null 2>&1; then
            success_message "Deployment verified successfully"
            return 0
        fi
        
        echo "Waiting before next attempt..."
        sleep 3
        ((attempt++))
    done
    
    error_exit "Deployment verification failed after $max_attempts attempts"
}

# ========================================
# Main Execution
# ========================================

main() {
    echo -e "${BLUE}DeMoD Agent System Deployment${NC}"
    echo -e "${BLUE}Environment: $ENVIRONMENT${NC}"
    echo -e "${BLUE}Registry: $DOCKER_REGISTRY${NC}"
    
    # Check environment
    check_environment
    
    # Build and test
    if [ "$SKIP_BUILD" = false ] || [ "$SKIP_TESTS" = false ]; then
        build_and_test
    fi
    
    # Deploy services
    deploy_services
    
    # Set up monitoring (except for local)
    if [[ ! "$ENVIRONMENT" =~ ^(development)$ ]]; then
        setup_monitoring
    fi
    
    # Post-deployment tasks
    if [[ ! "$ENVIRONMENT" =~ ^(development)$ ]]; then
        post_deployment_tasks
    fi
    
    # Verify deployment
    verify_deployment
    
    success_message "Deployment completed successfully!"
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi