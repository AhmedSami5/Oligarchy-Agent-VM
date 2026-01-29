# DeMoD Agent System

**Enterprise-Grade Distributed AI Agent Management Platform**

Copyright 2026 DeMoD LLC. All rights reserved.  
License: BSD 3-Clause - See LICENSE file for details.

## Overview

DeMoD Agent System is a comprehensive, technology-agnostic platform for managing AI coding agents across multiple deployment environments. It provides a REST API for agent lifecycle management, task assignment, and system monitoring, with support for both local and cloud deployments.

## Key Features

### Core Capabilities
- **Multi-Agent Management**: Create, monitor, and coordinate multiple AI agents
- **Task Assignment System**: Intelligent task routing based on agent capabilities and personality
- **Technology Agnostic**: Deploy on any infrastructure (local, AWS, Azure, GCP)
- **Real-time Communication**: WebSocket support for live agent status updates
- **Scalable Architecture**: Auto-scaling with configurable limits and policies
- **Professional REST API**: FastAPI-based service with comprehensive OpenAPI documentation

### Agent Types
- **Aider**: Multi-file coding specialist with high efficiency (95%)
- **OpenCode**: Autonomous coding agent with maximum creativity (90%)
- **Claude**: Conversational coding assistant with exceptional communication skills

### Deployment Options
- **Local Development**: Docker Compose with development services
- **Production Cloud**: Containerized deployment with cloud provider support
- **Kubernetes**: Production-ready manifests with auto-scaling
- **NixOS**: Reproducible system configuration

## Quick Start

### Prerequisites
- Docker and Docker Compose
- Python 3.11+ (or use provided Docker images)
- For local development: Node.js 18+ for UI components
- For cloud deployment: Terraform and kubectl

### Local Development

1. **Clone Repository**
   ```bash
   git clone https://github.com/demod/agent-system.git
   cd agent-system
   ```

2. **Start Development Environment**
   ```bash
   # Using Docker Compose
   docker-compose -f docker-compose.yml up -d
   
   # Or using Nix
   nix develop
   ```

3. **Access Services**
   - API Documentation: http://localhost:8000/docs
   - Health Check: http://localhost:8000/health
   - System Status: http://localhost:8000/system/status

### Cloud Deployment

1. **Build Docker Image**
   ```bash
   docker build -t demod-agent-system .
   ```

2. **Deploy to AWS**
   ```bash
   cd deployment/terraform/aws
   terraform init
   terraform apply
   ```

3. **Deploy to Kubernetes**
   ```bash
   kubectl apply -f deployment/kubernetes/
   ```

## API Documentation

### Authentication
All API endpoints require an API key passed in the `X-API-Key` header:

```bash
curl -H "X-API-Key: your-api-key" http://localhost:8000/health
```

### Core Endpoints

#### Agent Management
- `POST /agents/create` - Create new agent
- `GET /agents` - List all agents
- `GET /agents/{agent_id}` - Get agent details
- `DELETE /agents/{agent_id}` - Destroy agent

#### Task Management
- `POST /tasks/assign` - Assign task to agent
- `GET /tasks/{task_id}` - Get task status
- `POST /tasks/{task_id}/cancel` - Cancel running task

#### System Monitoring
- `GET /health` - System health check
- `GET /system/status` - Complete system status

### Example Usage

#### Create an Agent
```bash
curl -X POST "http://localhost:8000/agents/create" \
  -H "X-API-Key: your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "agent_type": "aider",
    "position": {"x": 0, "y": 0, "z": 0},
    "metadata": {"project": "my-app"}
  }'
```

#### Assign a Task
```bash
curl -X POST "http://localhost:8000/tasks/assign" \
  -H "X-API-Key: your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Fix the authentication bug in user service",
    "task_type": "debugging",
    "priority": 2.0
  }'
```

## Configuration

### Environment Variables
Configure the system using environment variables or YAML configuration files:

```bash
# Database
DATABASE_URL=postgresql://agent:password@localhost:5432/agentsystem

# API
API_ENDPOINT=http://localhost:8000
AGENTVM_API_KEY=your-production-key

# System
MAX_AGENTS=20
AUTO_SPAWN=true
MIN_IDLE_AGENTS=3

# Cloud
CLOUD_PROVIDER=aws
AWS_DEFAULT_REGION=us-west-2
```

### Configuration Files

Configuration is managed through YAML files in the `configs/` directory:

- `development.yaml` - Local development settings
- `staging.yaml` - Staging environment configuration
- `production.yaml` - Production deployment settings
- `local.yaml` - Local development overrides

## Architecture

### System Components

1. **API Layer**: FastAPI REST service with WebSocket support
2. **Core Engine**: Technology-agnostic agent management system
3. **Configuration Service**: Multi-environment configuration management
4. **Adapter Pattern**: Pluggable API and entity management interfaces
5. **Infrastructure**: Docker and Kubernetes deployment configurations

### Data Flow

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Web Client   │    │   REST API       │    │   AgentVM API   │
│   (Godot/UI)  │───▶│   (FastAPI)       │◀─▶│   (AgentVM Core) │
│               │    │                   │    │                   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
        │                    │    │                   │
        ▼                    ▼    ▼                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   Agent Manager Core                     │
│                                                       │
│   ┌─────────────┐  ┌──────────────┐  ┌─────────────┐ │
│   │   Agents     │  │    Tasks      │  │   Config     │ │
│   │   Registry   │  │   Queue       │  │   Service    │ │
│   │              │  │               │  │              │
│   └─────────────┘  └──────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

## Development

### Setup Development Environment

```bash
# Clone and setup
git clone https://github.com/demod/agent-system.git
cd agent-system

# Using Nix (recommended)
nix develop

# Using Docker
docker-compose -f docker-compose.yml up -d
```

### Running Tests

```bash
# Run all tests
pytest tests/ -v --cov=src

# Run specific test suite
pytest tests/unit/ -v

# Run with coverage report
pytest --cov=src --cov-report=html tests/
```

### Code Quality

The project uses several code quality tools:

```bash
# Format code
black src/
isort src/

# Lint code
ruff check src/
mypy src/

# Run pre-commit hooks
pre-commit run --all-files
```

## Deployment

### Local Production

```bash
# Build and run with Docker Compose
docker-compose -f docker-compose.yml up --build
```

### Cloud Deployment

#### AWS (ECS + RDS + ElastiCache)

```bash
# Deploy infrastructure
cd deployment/terraform/aws
terraform init
terraform plan
terraform apply

# Update environment variables
export AWS_DEFAULT_REGION=us-west-2
export AGENTVM_API_KEY=$PRODUCTION_KEY

# Deploy application
docker build -t demod-agent-system .
docker push your-registry/demod-agent-system:latest
```

#### Kubernetes

```bash
# Apply Kubernetes manifests
kubectl apply -f deployment/kubernetes/

# Check deployment status
kubectl get pods -l app=demod-agent-system
```

### Monitoring

The system includes comprehensive monitoring:

- **Health Checks**: `/health` endpoint
- **Metrics**: Prometheus metrics at `/metrics`
- **Logs**: Structured logging with multiple levels
- **Alerting**: Integration with monitoring systems

## Security

### Authentication
- API key-based authentication for all endpoints
- Support for JWT tokens (future enhancement)
- Secure communication via HTTPS in production

### Data Protection
- Database connections encrypted
- API keys stored securely (use environment variables)
- No sensitive data in repository
- Regular security updates and dependency scanning

### Network Security
- Rate limiting implemented
- CORS configuration for web clients
- Input validation and sanitization
- SQL injection protection via ORM

## Contributing

We welcome contributions! Please see our contributing guidelines:

1. Fork the repository
2. Create a feature branch
3. Implement your changes with tests
4. Ensure code quality standards are met
5. Submit a pull request

### Development Guidelines

- Follow PEP 8 style guidelines
- Write comprehensive tests for new features
- Update documentation for API changes
- Use conventional commit messages
- Ensure all CI/CD checks pass

## Support

### Documentation
- **API Reference**: Complete API documentation at `/docs`
- **Deployment Guides**: Step-by-step deployment instructions
- **Architecture Documentation**: Detailed system architecture overview
- **Troubleshooting**: Common issues and solutions

### Community
- **GitHub Issues**: Report bugs and request features
- **Discussions**: General questions and community support
- **Wiki**: Additional documentation and guides

## Roadmap

### Version 1.1 (Q2 2026)
- Enhanced WebSocket communication
- Advanced analytics and monitoring
- Multi-region cloud support
- Plugin system for custom agents

### Version 2.0 (Q3 2026)
- Machine learning-based task optimization
- Advanced collaboration features
- Web-based management interface
- Mobile application support

## License

This project is licensed under the BSD 3-Clause License. See the [LICENSE](LICENSE) file for the full license text.

## Acknowledgments

Built by DeMoD LLC with contributions from the open-source community.

### Core Technologies
- FastAPI for high-performance API development
- SQLAlchemy for database abstraction
- Docker for containerization and deployment
- Nix for reproducible builds and development
- Terraform for infrastructure as code

### Inspired By
- The AgentVM project for AI agent management
- Modern microservices architecture patterns
- Enterprise-grade deployment practices

---

**DeMoD Agent System** - Enterprise AI Agent Management Platform

For more information, visit [https://github.com/demod/agent-system](https://github.com/demod/agent-system) or contact us at [support@demod.com](support@demod.com).