# Oligarchy AgentVM - Enhanced Agent Management System

**Distributed AI Agent Management Platform for Godot and Web Applications**

Copyright 2026 DeMoD LLC. All rights reserved.  
License: BSD 3-Clause - See LICENSE file for details.

## Overview

This enhanced Godot plugin provides seamless integration with the DeMoD Agent System, allowing AI coding agents to appear as interactive NPCs within Godot games while supporting both local and cloud-based deployment scenarios.

## Key Features

### Enhanced Capabilities
- **Dockerized Backend**: Connect to AgentVM API running in Docker containers
- **Multi-Environment Support**: Local, staging, and production configurations
- **Cloud-Native Deployment**: AWS, Azure, and GCP support
- **Real-time Communication**: WebSocket connections for live agent status
- **Professional REST API**: FastAPI-based service with comprehensive endpoints
- **Scalable Architecture**: Auto-scaling with configurable policies

### Integration Options

#### Local Development
```bash
# Start local AgentVM instance
docker-compose -f docker-compose.yml up -d

# Configure Godot plugin
# In Godot editor, go to Project → Settings → Plugins → Oligarchy AgentVM
# Set API endpoint: http://localhost:8000
# Set API key: development-key
```

#### Cloud Deployment
```bash
# Deploy to AWS
cd deployment/terraform/aws
terraform apply

# Configure Godot plugin
# In production, set: https://your-agent-api.demod.com
# Use production API key from environment variables
```

## Quick Start

### 1. System Setup

1. **Start Agent System Backend**
   ```bash
   # Clone the Agent System repository
   git clone https://github.com/demod/agent-system.git
   cd agent-system
   
   # Start the services
   docker-compose -f docker-compose.yml up -d
   ```

2. **Configure Godot Plugin**
   - Open your Godot project
   - Go to `Project → Settings → Plugins`
   - Enable "Oligarchy AgentVM" plugin
   - Configure API endpoint in plugin settings

3. **Verify Connection**
   - Check API health: http://localhost:8000/health
   - Test agent creation in Godot editor
   - Verify real-time communication

### 2. Agent Management in Games

#### Creating Agents
```gdscript
# In your game script
var agent_manager = get_node("/AgentVMManager")
var agent_id = await agent_manager.create_agent("aider")
```

#### Task Assignment
```gdscript
# Assign coding task to agent
var task_id = await agent_manager.assign_task(
    agent_id, 
    "Fix the player movement bug"
    "debugging"
)
```

#### Real-time Collaboration
```gdscript
# Create collaborative task
var team_task_ids = await agent_manager.assign_collaborative_task(
    "Implement multiplayer networking",
    3  # Team of 3 agents
)
```

## Configuration

### Plugin Settings

Configure the plugin through Godot editor:

#### API Configuration
- **API Endpoint**: URL of the AgentVM API service
- **API Key**: Authentication key for API access
- **Environment**: Development, staging, or production
- **Auto-Connect**: Automatically connect on plugin startup

#### Agent Preferences
- **Default Agent Type**: Preferred agent type for new agents
- **Auto-Spawn**: Automatically spawn minimum agents
- **Visual Settings**: Particle effects and animation quality
- **Performance**: Update frequency and rendering options

### Environment Files

Configuration is managed through the Agent System:

1. **Development**: `configs/development.yaml`
2. **Staging**: `configs/staging.yaml`
3. **Production**: `configs/production.yaml`

Example production configuration:
```yaml
api:
  endpoint: "https://agent-api.demod.com"
  timeout: 60
  retry_attempts: 3

agentvm:
  api_key: "production-api-key-here"
  
system:
  max_agents: 50
  auto_spawn: true
  min_idle_agents: 5
```

## API Reference

### Core Endpoints

#### Agent Management
- `POST /agents/create` - Create new agent in game world
- `GET /agents/{agent_id}` - Get specific agent details
- `PUT /agents/{agent_id}/position` - Update agent position
- `DELETE /agents/{agent_id}` - Remove agent from game

#### Task Management
- `POST /tasks/assign` - Assign task to game agent
- `GET /tasks/{task_id}/status` - Get task progress
- `POST /tasks/{task_id}/cancel` - Cancel running task

#### Game Integration
- `POST /game/connect` - Register game session
- `PUT /game/scene/{scene_id}` - Update game scene information
- `GET /game/agents/{game_id}` - Get agents for specific game

### WebSocket Events
- `agent.created` - New agent created
- `agent.state_changed` - Agent state update
- `task.started` - Task execution started
- `task.completed` - Task finished successfully
- `task.failed` - Task execution failed

## Development Workflow

### Local Development Setup

1. **Start Backend Services**
   ```bash
   cd agent-system
   docker-compose -f docker-compose.yml up -d
   ```

2. **Configure Godot**
   - Open the plugin settings in Godot editor
   - Set API endpoint to `http://localhost:8000`
   - Enable "Auto-connect on startup"

3. **Develop Game Logic**
   ```gdscript
   extends Node3D
   
   func _ready():
       _setup_agent_system()
   
   func _setup_agent_system():
       agent_manager = AgentVMManager.new()
       add_child(agent_manager)
       
       # Connect to backend
       await agent_manager.connect_to_api(
           "http://localhost:8000",
           "development-key"
       )
       
       # Create initial agents
       await _spawn_development_team()
   ```

### Testing Integration

1. **Unit Tests**
   ```bash
   # Run agent system tests
   cd agent-system
   pytest tests/ -v
   
   # Run Godot plugin tests
   # In Godot editor, run test scenes
   ```

2. **Integration Tests**
   ```bash
   # Run end-to-end tests
   pytest tests/integration/ -v --env AGENT_ENV=testing
   ```

## Deployment

### Production Deployment

#### Docker Compose Production

```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  api:
    build: .
    ports:
      - "8000:8000"
    environment:
      - FLASK_ENV=production
      - AGENT_ENV=production
    volumes:
      - ./configs/production.yaml:/app/configs
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

#### Cloud Deployment

Deploy the Agent System backend using the provided Terraform configurations:

- **AWS ECS**: Automatically scalable container deployment
- **Azure Container Apps**: Serverless scaling with cost optimization
- **GKE**: Kubernetes-native deployment with auto-scaling

### Configuration for Production

#### Environment Variables
```bash
# Production configuration
export AGENT_ENV=production
export DATABASE_URL="postgresql://produser:securepass@rds.amazonaws.com:5432/agentsystem"
export REDIS_URL="redis://elasticache.example.com:6379/0"
export API_ENDPOINT="https://agent-api.demod.com"
export AGENTVM_API_KEY="${PRODUCTION_API_KEY}"
```

## Migration from Original System

### Data Migration

If you're migrating from the original local AgentVM:

1. **Export Existing Configuration**
   ```bash
   # Export agent personalities and custom settings
   python scripts/export_config.py
   ```

2. **Import to New System**
   ```bash
   # Import configuration to new system
   python scripts/import_config.py
   ```

3. **Compatibility Mode**
   The plugin maintains compatibility with the original API format, allowing gradual migration.

### Gradual Transition

1. **Phase 1**: Run both systems in parallel
2. **Phase 2**: Use new system for new agents
3. **Phase 3**: Migrate all agents to new system
4. **Phase 4**: Decommission of original system

## Security

### API Security
- API key-based authentication for all endpoints
- HTTPS enforced in production environments
- Input validation and sanitization
- Rate limiting to prevent abuse
- CORS configuration for cross-origin requests

### Game Security
- Plugin authentication with API keys
- Encrypted communication channels
- Input validation for agent interactions
- Session management with timeouts

## Monitoring and Analytics

### System Monitoring

- **Health Checks**: Comprehensive health monitoring at `/health`
- **Performance Metrics**: Response times, error rates, resource usage
- **Agent Statistics**: Active agents, task completion rates
- **Integration Health**: API connectivity and WebSocket status

### Game Analytics

- **Agent Performance**: Task execution times and success rates
- **User Engagement**: Agent interaction frequency and patterns
- **System Usage**: Resource consumption and scaling events

## Troubleshooting

### Common Issues

#### Connection Problems
**Issue**: Plugin cannot connect to API
**Solution**:
   1. Verify API service is running: `curl http://localhost:8000/health`
   2. Check network connectivity
   3. Verify API key in plugin settings
   4. Check firewall settings

#### Agent Performance Issues
**Issue**: Agents respond slowly or not at all
**Solution**:
   1. Check system status: `curl http://localhost:8000/system/status`
   2. Monitor API response times
   3. Check agent resource limits
   4. Review task complexity and agent capabilities

#### Deployment Issues
**Issue**: Container crashes or fails to start
**Solution**:
   1. Check container logs: `docker logs agent-system`
   2. Verify configuration files
   3. Check resource allocation
   4. Validate environment variables

### Getting Support

For technical support:

1. **Documentation**: Complete documentation at https://docs.demod-agent-system.com/godot
2. **GitHub Issues**: Report plugin issues at https://github.com/demod/agent-system/issues
3. **Community Discussions**: Join conversations at https://github.com/demod/agent-system/discussions
4. **Professional Support**: Contact support@demod.com for enterprise support

### Support Information

When reporting issues, include:

1. **Environment**: Godot version, OS, deployment type
2. **Configuration**: Plugin settings and system configuration
3. **Logs**: Error messages and console output
4. **Reproduction Steps**: Detailed steps to reproduce the issue
5. **Expected Behavior**: What should happen vs. what actually happened

## Architecture

### System Components

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Godot Game  │    │   Godot Plugin │    │   Agent System   │
│               │───▶│   AgentVM        │◀─▶│   REST API       │
│               │    │   Plugin        │    │   (FastAPI)     │
│               │    │                │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
        │                    │    │                 │
        ▼                    ▼    ▼                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        Agent System Backend                   │
│                                                           │
│   ┌─────────────┐  ┌──────────────┐  ┌─────────────┐  │
│   │   API        │  │   Manager     │  │   Database    │  │
│   │   Service    │  │   Core        │  │   (PostgreSQL) │
│   │              │  │              │  │                 │
│   │              │  │              │  │                 │
│   └─────────────┘  └──────────────┘  └─────────────┘  │
│                                                           │
│   ┌─────────────────────────────────────────────────────┐   │
│   │           Cloud Infrastructure (AWS/Azure/GCP)      │   │
│   │   ┌─────────────────┐  ┌─────────────┐      │
│   │   │   ECS/Container  │  │   Database     │      │
│   │   │   Apps/Functions │  │   (RDS/Redis) │      │
│   │   │                 │  │               │      │
│   │   └─────────────────┘  └─────────────┘      │
│   └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘   │
```

### Data Flow

1. **Agent Creation**: Game → Plugin → API → Database → Response → Game
2. **Task Assignment**: Game → Plugin → API → Core → Queue → Worker → Response → Game
3. **Status Updates**: Core → WebSocket → Plugin → Game
4. **Real-time Sync**: Database changes → WebSocket → Game Updates

## Performance Optimization

### Best Practices

#### For Large Numbers of Agents
- Use agent pools instead of creating/destroying
- Implement LOD (Level of Detail) for distant agents
- Batch state updates instead of individual requests
- Optimize update frequencies based on distance

#### For Network Communication
- Use WebSocket for real-time updates
- Implement request batching for multiple agents
- Add connection retries with exponential backoff
- Compress large payloads where applicable

#### For Memory Management
- Implement object pooling for agent entities
- Clear completed tasks and old data
- Monitor memory usage and implement limits
- Use streaming for large responses

## Future Enhancements

### Version 1.1
- **Web-based Management Interface**: Browser-based agent management
- **Advanced Analytics**: Detailed performance and usage metrics
- **Machine Learning**: AI-driven task optimization
- **Multi-Game Support**: Cross-game agent sharing

### Version 2.0
- **Mobile Applications**: Native iOS and Android apps
- **Advanced Collaboration**: Real-time multi-agent coordination
- **Custom Agent Creation**: Visual agent designer
- **Plugin Marketplace**: Community-contributed extensions

---

**DeMoD AgentVM Enhanced** - Professional Agent Management for Godot

For complete documentation, visit: https://docs.demod-agent-system.com/godot