# Deployment Guide

## Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Local Deployment](#local-deployment)
- [Cloud Deployment](#cloud-deployment)
- [Configuration](#configuration)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)

## Overview

This guide covers deployment of the DeMoD Agent System in various environments, from local development to production cloud deployments.

## Prerequisites

### System Requirements
- Docker 20.10+ and Docker Compose 2.0+
- Python 3.11+ (for local development)
- Node.js 18+ (for web UI components)
- 4GB RAM minimum (8GB recommended for production)
- 20GB disk space minimum

### Cloud Provider Accounts

#### AWS
- AWS account with appropriate permissions
- IAM user with ECS, RDS, and ElastiCache access
- ECR repository for container images

#### Azure
- Azure subscription
- Container Registry access
- Azure CLI configured

#### GCP
- Google Cloud project
- Container Registry access
- gcloud CLI configured

## Local Deployment

### Development Environment

1. **Clone Repository**
   ```bash
   git clone https://github.com/demod/agent-system.git
   cd agent-system
   ```

2. **Environment Setup**
   ```bash
   # Copy environment configuration
   cp configs/development.yaml configs/current.yaml
   
   # Set environment variables
   export AGENT_ENV=development
   export DATABASE_URL="postgresql://agent:password@localhost:5432/agentsystem"
   export REDIS_URL="redis://localhost:6379/0"
   ```

3. **Start Services**
   ```bash
   # Using Docker Compose (recommended)
   docker-compose -f docker-compose.yml up -d
   
   # Or using Nix
   nix develop
   ```

4. **Verify Deployment**
   ```bash
   # Check service health
   curl http://localhost:8000/health
   
   # Check system status
   curl -H "X-API-Key: dev-key" http://localhost:8000/system/status
   ```

### Local Production

1. **Build Production Image**
   ```bash
   docker build -t demod-agent-system:latest .
   ```

2. **Deploy with Production Compose**
   ```bash
   docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
   ```

## Cloud Deployment

### AWS Deployment

#### 1. Infrastructure Setup

1. **Configure AWS CLI**
   ```bash
   aws configure
   AWS Access Key ID: YOUR_ACCESS_KEY
   AWS Secret Access Key: YOUR_SECRET_KEY
   Default region name: us-west-2
   Default output format: json
   ```

2. **Deploy Infrastructure**
   ```bash
   cd deployment/terraform/aws
   terraform init
   terraform plan
   terraform apply
   ```

3. **Deploy Application**
   ```bash
   # Build and push Docker image
   docker build -t demod-agent-system .
   docker tag demod-agent-system:latest 123456789012.dkr.ecr.us-west-2.amazonaws.com/demod-agent-system
   docker push 123456789012.dkr.ecr.us-west-2.amazonaws.com/demod-agent-system
   
   # Update Kubernetes deployment
   kubectl set image deployment/demod-agent-system demod-agent-system=123456789012.dkr.ecr.us-west-2.amazonaws.com/demod-agent-system:latest
   kubectl apply -f deployment/kubernetes/
   ```

### Azure Deployment

#### 1. Azure Setup**
   ```bash
   # Login to Azure
   az login
   az account set --subscription "Demod-Production"
   
   # Set resource group
   az group create --name demod-agent-rg --location "East US"
   ```

#### 2. Deploy Infrastructure
   ```bash
   cd deployment/terraform/azure
   terraform init
   terraform plan
   terraform apply
   ```

#### 3. Deploy Application
   ```bash
   # Build and push to Azure Container Registry
   docker build -t demod-agent-system .
   docker tag demod-agent-system demodacr.azurecr.io/demod-agent-system:latest
   docker push demodacr.azurecr.io/demod-agent-system
   
   # Deploy to Container Apps
   az containerapp up \
     --resource-group demod-agent-rg \
     --name demod-agent \
     --image demodacr.azurecr.io/demod-agent-system:latest \
     --cpu 0.5 \
     --memory 1.0
   ```

### GCP Deployment

#### 1. GCP Setup**
   ```bash
   # Configure gcloud
   gcloud config set project demod-agent-system
   gcloud config set compute/zone us-west1-a
   ```

#### 2. Deploy Infrastructure
   ```bash
   cd deployment/terraform/gcp
   terraform init
   terraform plan
   terraform apply
   ```

#### 3. Deploy Application
   ```bash
   # Build and push to Google Container Registry
   docker build -t demod-agent-system .
   docker tag demod-agent-system gcr.io/demod-agent-system/demod-agent-system:latest
   docker push gcr.io/demod-agent-system/demod-agent-system
   
   # Deploy to GKE
   kubectl apply -f deployment/kubernetes/
   ```

## Kubernetes Deployment

### 1. Cluster Preparation
   ```bash
   # Create namespace
   kubectl create namespace demod-agent-system
   
   # Apply configurations
   kubectl apply -f deployment/kubernetes/
   ```

### 2. Application Deployment
   ```bash
   # Deploy application
   kubectl apply -f deployment/kubernetes/deployment.yaml
   
   # Expose service
   kubectl apply -f deployment/kubernetes/service.yaml
   ```

### 3. Auto-scaling Configuration
   ```bash
   # Apply horizontal pod autoscaler
   kubectl apply -f deployment/kubernetes/hpa.yaml
   
   # Check autoscaler status
   kubectl get hpa demod-agent-system
   ```

## Configuration

### Environment Variables

#### Required Variables
```bash
# Database Configuration
DATABASE_URL=postgresql://user:password@host:5432/database
REDIS_URL=redis://host:6379/0

# API Configuration
API_ENDPOINT=http://your-domain.com
AGENTVM_API_KEY=your-production-api-key

# System Configuration
MAX_AGENTS=50
AUTO_SPAWN=true
MIN_IDLE_AGENTS=5
```

#### Optional Variables
```bash
# Cloud Provider
CLOUD_PROVIDER=aws  # aws, azure, gcp, local
AWS_DEFAULT_REGION=us-west-2
AZURE_LOCATION="East US"
GCP_PROJECT=demod-agent-system

# Logging
LOG_LEVEL=INFO
LOG_FORMAT=json

# Performance
WORKER_PROCESSES=4
TASK_TIMEOUT=600
```

### Configuration Files

Configuration is managed through YAML files:

1. **configs/development.yaml** - Local development
2. **configs/staging.yaml** - Staging environment
3. **configs/production.yaml** - Production settings
4. **configs/local.yaml** - Local overrides

## Monitoring

### Health Checks

Configure health checks for load balancers and monitoring:

```bash
# Application health
curl -f http://your-domain.com/health

# System status
curl -H "X-API-Key: $API_KEY" http://your-domain.com/system/status
```

### Logging

The system provides structured logging in multiple formats:

```bash
# Application logs
docker logs demod-agent-system-container

# Kubernetes logs
kubectl logs -f deployment/demod-agent-system -n demod-agent-system
```

### Metrics

Prometheus metrics are available at `/metrics` endpoint:

- Agent system metrics (total agents, active tasks)
- Performance metrics (response times, error rates)
- Resource metrics (CPU, memory usage)

### Alerting

Configure alerts for critical system events:

1. **API Failure Rate**: Alert when error rate exceeds threshold
2. **Agent Capacity**: Alert when agent count is below minimum
3. **Database Connectivity**: Alert on database connection issues
4. **Task Failure Rate**: Alert when task failure rate is high

## Troubleshooting

### Common Issues

#### Docker Deployment Issues

**Problem**: Container fails to start
**Solution**: 
   ```bash
   # Check logs
   docker logs demod-agent-system
   
   # Verify configuration
   docker-compose config
   
   # Rebuild if necessary
   docker-compose up --build
   ```

#### Database Connection Issues

**Problem**: Database connection failed
**Solution**:
   ```bash
   # Check database URL
   echo $DATABASE_URL
   
   # Test connection
   python -c "import sqlalchemy; engine=sqlalchemy.create_engine('$DATABASE_URL'); engine.connect()"
   
   # Verify database is running
   docker ps | grep postgres
   ```

#### Cloud Deployment Issues

**Problem**: Terraform apply fails
**Solution**:
   ```bash
   # Check Terraform state
   terraform plan
   terraform validate
   
   # Check provider configuration
   terraform version
   terraform providers
   ```

#### Performance Issues

**Problem**: High response times
**Solution**:
   ```bash
   # Check system status
   curl -s -w "Total time: %{time_total}s" http://your-domain.com/system/status
   
   # Check resource usage
   docker stats demod-agent-system-container
   
   # Adjust worker processes
   kubectl scale deployment/demod-agent-system --replicas=4
   ```

### Getting Help

For additional support:

1. **Documentation**: Full documentation at https://docs.demod-agent-system.com
2. **GitHub Issues**: Report bugs at https://github.com/demod/agent-system/issues
3. **Community**: Join discussions at https://github.com/demod/agent-system/discussions
4. **Support**: Contact support@demod.com for enterprise support

### Support Information

When reporting issues, please include:

1. **System Information**: OS version, Docker version, cloud provider
2. **Configuration**: Relevant environment variables and settings
3. **Logs**: Error logs and system status
4. **Steps Taken**: What you've tried so far
5. **Expected Behavior**: What you expected to happen

This information will help us provide faster and more accurate support.