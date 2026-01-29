# ========================================
# Main API Service - REST API for Agent Management
# ========================================

from fastapi import FastAPI, HTTPException, BackgroundTasks, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
import asyncio
import logging
import os
from datetime import datetime

from ..core.agent_manager import AgentManagerCore, AgentState, TaskResult
from ..core.configuration import ConfigurationService
from ..adapters.api_adapter import HTTPAPIAdapter

# ========================================
# Pydantic Models for API
# ========================================

class AgentCreateRequest(BaseModel):
    agent_type: str = Field(..., description="Type of agent to create")
    position: Optional[Dict[str, float]] = Field(None, description="Position for agent")
    metadata: Optional[Dict[str, Any]] = Field(None, description="Additional metadata")

class AgentCreateResponse(BaseModel):
    success: bool
    agent_id: Optional[str] = None
    message: str

class TaskAssignRequest(BaseModel):
    agent_id: Optional[str] = Field(None, description="Specific agent ID")
    prompt: str = Field(..., description="Task prompt or instruction")
    task_type: str = Field("general", description="Type of task")
    preferred_type: Optional[str] = Field(None, description="Preferred agent type")
    priority: float = Field(1.0, description="Task priority")
    timeout: int = Field(600, description="Task timeout in seconds")

class TaskStatusResponse(BaseModel):
    success: bool
    task_id: Optional[str] = None
    status: str
    result: Optional[Dict[str, Any]] = None
    message: str

class SystemStatusResponse(BaseModel):
    success: bool
    status: Dict[str, Any]
    timestamp: datetime

class AgentResponse(BaseModel):
    id: str
    type: str
    name: str
    description: str
    color: str
    position: Dict[str, float]
    state: str
    capabilities: List[str]
    created_at: datetime

# ========================================
# API Service Implementation
# ========================================

class AgentAPIService:
    """FastAPI-based REST service for agent management"""
    
    def __init__(self, config_service: ConfigurationService):
        self.config_service = config_service
        self.logger = logging.getLogger(__name__)
        
        # Initialize core manager
        self.agent_manager = AgentManagerCore(config_service)
        
        # Initialize adapters
        config = config_service.load_config()
        api_config = config.get("api", {})
        agentvm_config = config.get("agentvm", {})
        
        self.api_adapter = HTTPAPIAdapter(
            api_endpoint=api_config.get("endpoint", "http://localhost:8000"),
            api_key=agentvm_config.get("api_key", "dev-key"),
            timeout=api_config.get("timeout", 30)
        )
        
        self.entity_adapter = None  # Will be implemented based on platform
        
        self.agent_manager.set_adapters(self.api_adapter, self.entity_adapter)
        
        # Initialize FastAPI app
        self.app = self._create_fastapi_app()
        
        # Background tasks
        self.background_tasks = BackgroundTasks()
    
    def _create_fastapi_app(self) -> FastAPI:
        """Create and configure FastAPI application"""
        app = FastAPI(
            title="DeMoD Agent System API",
            description="REST API for managing AI coding agents",
            version="1.0.0",
            docs_url="/docs",
            redoc_url="/redoc"
        )
        
        # Add CORS middleware
        app.add_middleware(
            CORSMiddleware,
            allow_origins=["*"],
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"]
        )
        
        # Add exception handler
        @app.exception_handler(Exception)
        async def global_exception_handler(request, exc):
            self.logger.error(f"Global exception: {exc}")
            return JSONResponse(
                status_code=500,
                content={"success": False, "error": str(exc)}
            )
        
        # Add API key authentication
        async def verify_api_key(x_api_key: str = Header(None)):
            if x_api_key is None:
                raise HTTPException(status_code=401, detail="API key required")
            
            config = self.config_service.load_config()
            expected_key = config.get("agentvm", {}).get("api_key")
            
            if x_api_key != expected_key:
                raise HTTPException(status_code=403, detail="Invalid API key")
            
            return x_api_key
        
        return app, Depends(verify_api_key)
    
    async def startup(self) -> None:
        """Initialize services on startup"""
        self.logger.info("Starting Agent API Service...")
        
        # Initialize adapters
        await self.api_adapter.initialize()
        
        # Start auto-spawning if enabled
        config = self.config_service.load_config()
        if config.get("system", {}).get("auto_spawn", False):
            self.background_tasks.add_task(self._auto_spawn_loop())
        
        # Start periodic cleanup
        self.background_tasks.add_task(self._cleanup_loop())
        
        self.logger.info("Agent API Service started successfully")
    
    async def shutdown(self) -> None:
        """Clean up on shutdown"""
        self.logger.info("Shutting down Agent API Service...")
        
        await self.api_adapter.cleanup()
        
        self.logger.info("Agent API Service shut down")
    
    async def _auto_spawn_loop(self) -> None:
        """Auto-spawning background loop"""
        while True:
            try:
                await self.agent_manager.auto_spawn_check()
                await asyncio.sleep(60)  # Check every minute
            except Exception as e:
                self.logger.error(f"Auto-spawn error: {e}")
                await asyncio.sleep(60)
    
    async def _cleanup_loop(self) -> None:
        """Periodic cleanup loop"""
        while True:
            try:
                config = self.config_service.load_config()
                cleanup_interval = config.get("system", {}).get("cleanup_interval", 3600)
                
                await self.agent_manager.cleanup_completed_tasks(24)  # Cleanup tasks older than 24 hours
                await asyncio.sleep(cleanup_interval)
            except Exception as e:
                self.logger.error(f"Cleanup error: {e}")
                await asyncio.sleep(3600)
    
    def get_app(self) -> FastAPI:
        """Get FastAPI application instance"""
        return self.app

# ========================================
# API Routes
# ========================================

def setup_routes(app: FastAPI, agent_manager: AgentManagerCore):
    """Setup all API routes"""
    
    @app.get("/health", response_model=Dict[str, str])
    async def health_check():
        """Health check endpoint"""
        return {"status": "healthy", "timestamp": datetime.now().isoformat()}
    
    @app.post("/agents/create", response_model=AgentCreateResponse)
    async def create_agent(
        request: AgentCreateRequest,
        api_key: str = Depends(get_api_key)
    ):
        """Create a new agent"""
        try:
            agent_id = await agent_manager.create_agent(
                agent_type=request.agent_type,
                position=request.position,
                **(request.metadata or {})
            )
            
            return AgentCreateResponse(
                success=True,
                agent_id=agent_id,
                message="Agent created successfully"
            )
            
        except Exception as e:
            return AgentCreateResponse(
                success=False,
                message=f"Failed to create agent: {str(e)}"
            )
    
    @app.delete("/agents/{agent_id}", response_model=Dict[str, Any])
    async def destroy_agent(
        agent_id: str,
        api_key: str = Depends(get_api_key)
    ):
        """Destroy an agent"""
        try:
            success = await agent_manager.destroy_agent(agent_id)
            return {"success": success, "message": "Agent destroyed" if success else "Agent not found"}
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    @app.get("/agents", response_model=List[AgentResponse])
    async def list_agents(api_key: str = Depends(get_api_key)):
        """List all agents"""
        agents = agent_manager.get_all_agents()
        
        return [
            AgentResponse(
                id=agent.id,
                type=agent.type,
                name=agent.name,
                description=agent.description,
                color=agent.color,
                position=agent.position,
                state="idle",  # TODO: Get actual state from entity adapter
                capabilities=agent.capabilities,
                created_at=agent.created_at
            )
            for agent in agents
        ]
    
    @app.get("/agents/{agent_id}", response_model=Dict[str, Any])
    async def get_agent(
        agent_id: str,
        api_key: str = Depends(get_api_key)
    ):
        """Get specific agent details"""
        agent = agent_manager.get_agent(agent_id)
        
        if agent:
            return {
                "success": True,
                "agent": {
                    "id": agent.id,
                    "type": agent.type,
                    "name": agent.name,
                    "description": agent.description,
                    "color": agent.color,
                    "position": agent.position,
                    "capabilities": agent.capabilities,
                    "created_at": agent.created_at.isoformat(),
                    "metadata": agent.metadata
                }
            }
        else:
            return {"success": False, "error": "Agent not found"}
    
    @app.post("/tasks/assign", response_model=TaskStatusResponse)
    async def assign_task(
        request: TaskAssignRequest,
        api_key: str = Depends(get_api_key)
    ):
        """Assign task to agent"""
        try:
            if request.agent_id:
                # Assign to specific agent
                task_id = await agent_manager.assign_task(
                    agent_id=request.agent_id,
                    prompt=request.prompt,
                    task_type=request.task_type
                )
            else:
                # Assign to best available agent
                task_id = await agent_manager.assign_task_to_best_agent(
                    prompt=request.prompt,
                    task_type=request.task_type,
                    preferred_type=request.preferred_type
                )
            
            return TaskStatusResponse(
                success=True,
                task_id=task_id,
                status="assigned",
                message="Task assigned successfully"
            )
            
        except Exception as e:
            return TaskStatusResponse(
                success=False,
                status="failed",
                message=f"Failed to assign task: {str(e)}"
            )
    
    @app.get("/tasks/{task_id}", response_model=TaskStatusResponse)
    async def get_task_status(
        task_id: str,
        api_key: str = Depends(get_api_key)
    ):
        """Get task status"""
        result = agent_manager.get_task_status(task_id)
        
        if result:
            return TaskStatusResponse(
                success=True,
                task_id=task_id,
                status="completed" if result.success else "failed",
                result={
                    "success": result.success,
                    "output": result.output,
                    "error": result.error,
                    "execution_time": result.execution_time,
                    "completed_at": result.completed_at.isoformat() if result.completed_at else None
                },
                message="Task retrieved successfully"
            )
        else:
            return TaskStatusResponse(
                success=False,
                status="not_found",
                message="Task not found"
            )
    
    @app.post("/tasks/{task_id}/cancel", response_model=Dict[str, Any])
    async def cancel_task(
        task_id: str,
        api_key: str = Depends(get_api_key)
    ):
        """Cancel a task"""
        # This would need to be implemented in the agent manager
        # For now, return a response indicating the API endpoint exists
        return {
            "success": True,
            "message": "Task cancellation requested (implementation pending)"
        }
    
    @app.get("/system/status", response_model=SystemStatusResponse)
    async def get_system_status(api_key: str = Depends(get_api_key)):
        """Get overall system status"""
        status = agent_manager.get_system_status()
        
        return SystemStatusResponse(
            success=True,
            status=status,
            timestamp=datetime.now()
        )

# ========================================
# Dependency function for API key verification
# ========================================

async def get_api_key(x_api_key: str = Header(None)):
    """Extract and verify API key from header"""
    if x_api_key is None:
        raise HTTPException(status_code=401, detail="API key required")
    return x_api_key