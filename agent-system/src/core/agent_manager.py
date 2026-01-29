# ========================================
# Agent Manager Core - Technology Agnostic
# ========================================

from abc import ABC, abstractmethod
from typing import Dict, List, Optional, Any, Union
import asyncio
import logging
import uuid
import time
from datetime import datetime

# ========================================
# Data Models
# ========================================

class AgentState:
    IDLE = "idle"
    THINKING = "thinking"
    CODING = "coding"
    SPEAKING = "speaking"
    MOVING = "moving"
    COLLABORATING = "collaborating"
    ERROR = "error"

class AgentType:
    AIDER = "aider"
    OPENCODE = "opencode"
    CLAUDE = "claude"
    CUSTOM = "custom"

class AgentPersonality:
    def __init__(self, friendliness: float = 0.8, efficiency: float = 0.9, 
                 creativity: float = 0.7, talkativeness: float = 0.6, 
                 collaboration: float = 0.8):
        self.friendliness = friendliness
        self.efficiency = efficiency
        self.creativity = creativity
        self.talkativeness = talkativeness
        self.collaboration = collaboration

class AgentConfig:
    def __init__(self, id: str, type: str, name: str, description: str, 
                 color: str, personality: AgentPersonality,
                 position: Optional[Dict[str, float]] = None,
                 capabilities: Optional[List[str]] = None,
                 created_at: Optional[datetime] = None,
                 metadata: Optional[Dict[str, Any]] = None):
        self.id = id
        self.type = type
        self.name = name
        self.description = description
        self.color = color
        self.personality = personality
        self.position = position or {"x": 0.0, "y": 0.0, "z": 0.0}
        self.capabilities = capabilities or []
        self.created_at = created_at or datetime.now()
        self.metadata = metadata or {}

class TaskRequest:
    def __init__(self, agent_id: str, prompt: str, task_type: str = "general",
                 priority: float = 1.0, timeout: int = 600,
                 metadata: Optional[Dict[str, Any]] = None,
                 task_id: Optional[str] = None,
                 created_at: Optional[datetime] = None):
        self.id = task_id or str(uuid.uuid4())
        self.agent_id = agent_id
        self.prompt = prompt
        self.task_type = task_type
        self.priority = priority
        self.timeout = timeout
        self.metadata = metadata or {}
        self.created_at = created_at or datetime.now()

class TaskResult:
    def __init__(self, task_id: str, agent_id: str, success: bool = True,
                 output: str = "", error: str = "",
                 started_at: Optional[datetime] = None,
                 completed_at: Optional[datetime] = None,
                 execution_time: Optional[float] = None):
        self.id = task_id
        self.agent_id = agent_id
        self.success = success
        self.output = output
        self.error = error
        self.started_at = started_at or datetime.now()
        self.completed_at = completed_at
        self.execution_time = execution_time

# ========================================
# Core Interfaces
# ========================================

class APIAdapter(ABC):
    """Abstract interface for API communication with AgentVM"""
    
    @abstractmethod
    async def execute_agent(self, agent_type: str, prompt: str, **kwargs) -> TaskResult:
        """Execute agent task and return result"""
        pass
    
    @abstractmethod
    async def get_agent_status(self, task_id: str) -> Dict[str, Any]:
        """Get status of running agent task"""
        pass
    
    @abstractmethod
    async def cancel_task(self, task_id: str) -> bool:
        """Cancel running task"""
        pass
    
    @abstractmethod
    def is_connected(self) -> bool:
        """Check if API is connected"""
        pass

class EntityAdapter(ABC):
    """Abstract interface for agent entity management"""
    
    @abstractmethod
    async def create_agent(self, config: AgentConfig) -> str:
        """Create new agent entity"""
        pass
    
    @abstractmethod
    async def update_agent_state(self, agent_id: str, state: str) -> bool:
        """Update agent visual state"""
        pass
    
    @abstractmethod
    async def destroy_agent(self, agent_id: str) -> bool:
        """Remove agent entity"""
        pass
    
    @abstractmethod
    def get_agent_position(self, agent_id: str) -> Optional[Dict[str, float]]:
        """Get agent position"""
        pass

class ConfigurationService(ABC):
    """Abstract interface for configuration management"""
    
    @abstractmethod
    def load_config(self, environment: str = "development") -> Dict[str, Any]:
        """Load configuration for environment"""
        pass
    
    @abstractmethod
    def save_config(self, config: Dict[str, Any], environment: str = "development") -> bool:
        """Save configuration for environment"""
        pass
    
    @abstractmethod
    def get_agent_types(self) -> List[AgentConfig]:
        """Get all available agent types"""
        pass

# ========================================
# Core Agent Manager
# ========================================

class AgentManagerCore:
    """Technology-agnostic agent management system"""
    
    def __init__(self, config_service: ConfigurationService):
        self.config_service = config_service
        self.agents: Dict[str, AgentConfig] = {}
        self.tasks: Dict[str, TaskRequest] = {}
        self.task_results: Dict[str, TaskResult] = {}
        self.active_conversations: Dict[str, List[str]] = {}
        
        # Adapters (injected)
        self.api_adapter: Optional[APIAdapter] = None
        self.entity_adapter: Optional[EntityAdapter] = None
        
        # Configuration
        self.max_agents: int = 10
        self.auto_spawn: bool = True
        self.min_idle_agents: int = 2
        
        # Event callbacks
        self.event_handlers: Dict[str, List[callable]] = {}
        
        # Logging
        self.logger = logging.getLogger(__name__)
        
        self._load_configuration()
    
    def _load_configuration(self) -> None:
        """Load system configuration"""
        try:
            config = self.config_service.load_config()
            system_config = config.get("system", {})
            self.max_agents = system_config.get("max_agents", 10)
            self.auto_spawn = system_config.get("auto_spawn", True)
            self.min_idle_agents = system_config.get("min_idle_agents", 2)
            
            self.logger.info("Configuration loaded successfully")
        except Exception as e:
            self.logger.error(f"Failed to load configuration: {e}")
            # Use defaults
            self.max_agents = 10
            self.auto_spawn = True
            self.min_idle_agents = 2
    
    def set_adapters(self, api_adapter: APIAdapter, entity_adapter: EntityAdapter) -> None:
        """Inject adapters for API and entity management"""
        self.api_adapter = api_adapter
        self.entity_adapter = entity_adapter
        self.logger.info("Adapters set successfully")
    
    # ========================================
    # Agent Lifecycle Management
    # ========================================
    
    async def create_agent(self, agent_type: str, position: Optional[Dict[str, float]] = None, **kwargs) -> str:
        """Create new agent"""
        if len(self.agents) >= self.max_agents:
            raise RuntimeError(f"Maximum agents ({self.max_agents}) reached")
        
        # Get agent type configuration
        agent_types = self.config_service.get_agent_types()
        agent_type_config = None
        for at in agent_types:
            if at.type == agent_type:
                agent_type_config = at
                break
        
        if not agent_type_config:
            raise ValueError(f"Unknown agent type: {agent_type}")
        
        # Create agent configuration
        agent_id = str(uuid.uuid4())
        agent_config = AgentConfig(
            id=agent_id,
            type=agent_type,
            name=agent_type_config.name,
            description=agent_type_config.description,
            color=agent_type_config.color,
            personality=agent_type_config.personality,
            position=position,
            capabilities=agent_type_config.capabilities,
            metadata=kwargs
        )
        
        # Register agent
        self.agents[agent_id] = agent_config
        
        # Create entity
        if self.entity_adapter:
            await self.entity_adapter.create_agent(agent_config)
        
        self.logger.info(f"Created agent {agent_id} of type {agent_type}")
        self._emit_event("agent_created", {"agent_id": agent_id, "type": agent_type})
        
        return agent_id
    
    async def destroy_agent(self, agent_id: str) -> bool:
        """Destroy agent"""
        if agent_id not in self.agents:
            return False
        
        # Cancel any active tasks
        await self.cancel_agent_tasks(agent_id)
        
        # Destroy entity
        if self.entity_adapter:
            await self.entity_adapter.destroy_agent(agent_id)
        
        # Remove from registry
        del self.agents[agent_id]
        
        self.logger.info(f"Destroyed agent {agent_id}")
        self._emit_event("agent_destroyed", {"agent_id": agent_id})
        
        return True
    
    def get_agent(self, agent_id: str) -> Optional[AgentConfig]:
        """Get agent configuration"""
        return self.agents.get(agent_id)
    
    def get_all_agents(self) -> List[AgentConfig]:
        """Get all agents"""
        return list(self.agents.values())
    
    def get_agents_by_type(self, agent_type: str) -> List[AgentConfig]:
        """Get agents by type"""
        return [agent for agent in self.agents.values() if agent.type == agent_type]
    
    def get_idle_agents(self) -> List[AgentConfig]:
        """Get idle agents (not currently working)"""
        idle_agents = []
        for agent in self.agents.values():
            # Check if agent has active tasks
            active_tasks = [t for t in self.tasks.values() if t.agent_id == agent.id]
            if not active_tasks:
                idle_agents.append(agent)
        return idle_agents
    
    # ========================================
    # Task Management
    # ========================================
    
    async def assign_task(self, agent_id: str, prompt: str, task_type: str = "general", **kwargs) -> str:
        """Assign task to specific agent"""
        if agent_id not in self.agents:
            raise ValueError(f"Agent {agent_id} not found")
        
        if not self.api_adapter:
            raise RuntimeError("API adapter not configured")
        
        # Create task request
        task = TaskRequest(
            agent_id=agent_id,
            prompt=prompt,
            task_type=task_type,
            **kwargs
        )
        
        # Register task
        self.tasks[task.id] = task
        
        # Execute via API adapter
        try:
            result = await self.api_adapter.execute_agent(self.agents[agent_id].type, prompt)
            
            # Store result
            result.completed_at = datetime.now()
            result.execution_time = (result.completed_at - task.created_at).total_seconds()
            self.task_results[task.id] = result
            
            self.logger.info(f"Task {task.id} completed for agent {agent_id}")
            self._emit_event("task_completed", {"task_id": task.id, "agent_id": agent_id, "result": result})
            
            return task.id
            
        except Exception as e:
            self.logger.error(f"Task {task.id} failed for agent {agent_id}: {e}")
            error_result = TaskResult(
                task_id=task.id,
                agent_id=agent_id,
                success=False,
                error=str(e),
                completed_at=datetime.now()
            )
            self.task_results[task.id] = error_result
            self._emit_event("task_failed", {"task_id": task.id, "agent_id": agent_id, "error": str(e)})
            return task.id
    
    def get_task_status(self, task_id: str) -> Optional[TaskResult]:
        """Get task status and result"""
        return self.task_results.get(task_id)
    
    def get_system_status(self) -> Dict[str, Any]:
        """Get overall system status"""
        return {
            "total_agents": len(self.agents),
            "idle_agents": len(self.get_idle_agents()),
            "active_tasks": len(self.tasks),
            "completed_tasks": len([r for r in self.task_results.values() if r.success]),
            "failed_tasks": len([r for r in self.task_results.values() if not r.success]),
            "active_conversations": len(self.active_conversations),
            "api_connected": self.api_adapter.is_connected() if self.api_adapter else False,
            "max_agents": self.max_agents,
            "auto_spawn": self.auto_spawn
        }
    
    # ========================================
    # Event Management
    # ========================================
    
    def on(self, event_name: str, handler: callable) -> None:
        """Register event handler"""
        if event_name not in self.event_handlers:
            self.event_handlers[event_name] = []
        self.event_handlers[event_name].append(handler)
    
    def off(self, event_name: str, handler: callable = None) -> None:
        """Unregister event handler"""
        if event_name in self.event_handlers:
            if handler:
                if handler in self.event_handlers[event_name]:
                    self.event_handlers[event_name].remove(handler)
            else:
                self.event_handlers[event_name].clear()
    
    def _emit_event(self, event_name: str, data: Dict[str, Any]) -> None:
        """Emit event to all handlers"""
        if event_name in self.event_handlers:
            for handler in self.event_handlers[event_name]:
                try:
                    handler(data)
                except Exception as e:
                    self.logger.error(f"Event handler failed for {event_name}: {e}")
    
    # ========================================
    # Cleanup and Maintenance
    # ========================================
    
    async def cleanup_completed_tasks(self, older_than_hours: int = 24) -> int:
        """Clean up old task results"""
        cutoff_time = datetime.now().timestamp() - (older_than_hours * 3600)
        
        old_tasks = [
            task_id for task_id, result in self.task_results.items()
            if result.completed_at and result.completed_at.timestamp() < cutoff_time
        ]
        
        for task_id in old_tasks:
            del self.task_results[task_id]
        
        self.logger.info(f"Cleaned up {len(old_tasks)} old tasks")
        return len(old_tasks)
    
    async def cancel_agent_tasks(self, agent_id: str) -> None:
        """Cancel all tasks for an agent"""
        agent_tasks = [task for task in self.tasks.values() if task.agent_id == agent_id]
        
        for task in agent_tasks:
            if self.api_adapter:
                try:
                    await self.api_adapter.cancel_task(task.id)
                except Exception as e:
                    self.logger.error(f"Failed to cancel task {task.id}: {e}")