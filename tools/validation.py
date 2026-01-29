#!/usr/bin/env python3
"""
Input validation utilities for API endpoints

Provides consistent input validation for FastAPI endpoints.
"""

from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field, validator
from enum import Enum


class AgentType(str, Enum):
    """Valid agent types"""
    AIDER = "aider"
    OPENCODE = "opencode"
    CLAUDE = "claude"


class AgentRequest(BaseModel):
    """Request model for running agents"""
    agent: AgentType = Field(..., description="Agent to run")
    prompt: str = Field(..., min_length=1, max_length=10000, description="Coding task")
    repo_path: Optional[str] = Field(
        default="/mnt/host-projects/current",
        description="Path to repository"
    )
    timeout: int = Field(
        default=600,
        ge=1,
        le=3600,
        description="Execution timeout in seconds"
    )
    extra_args: Optional[List[str]] = Field(
        default=None,
        description="Additional command-line arguments"
    )
    
    @validator('repo_path')
    def validate_repo_path(cls, v):
        """Validate repository path"""
        if v and not v.startswith(("/", "~", ".")):
            raise ValueError("Repository path must be absolute or relative")
        return v


class TaskStatusResponse(BaseModel):
    """Response model for task status"""
    success: bool
    task_id: Optional[str] = None
    status: str
    result: Optional[Dict[str, Any]] = None
    message: str


class SystemStatusResponse(BaseModel):
    """Response model for system status"""
    success: bool
    status: Dict[str, Any]
    timestamp: str


class AgentCreateRequest(BaseModel):
    """Request model for creating agents"""
    agent_type: str = Field(..., description="Type of agent to create")
    position: Optional[Dict[str, float]] = Field(None, description="Position for agent")
    metadata: Optional[Dict[str, Any]] = Field(None, description="Additional metadata")
    
    @validator('agent_type')
    def validate_agent_type(cls, v):
        """Validate agent type"""
        valid_types = ["aider", "opencode", "claude"]
        if v not in valid_types:
            raise ValueError(
                f"Invalid agent type. Must be one of: {', '.join(valid_types)}"
            )
        return v


class TaskAssignRequest(BaseModel):
    """Request model for assigning tasks"""
    agent_id: Optional[str] = Field(None, description="Specific agent ID")
    prompt: str = Field(..., min_length=1, max_length=10000, description="Task prompt")
    task_type: str = Field(default="general", description="Type of task")
    preferred_type: Optional[str] = Field(None, description="Preferred agent type")
    priority: float = Field(default=1.0, gt=0, description="Task priority")
    timeout: int = Field(
        default=600, ge=1, le=3600, description="Task timeout in seconds"
    )
    
    @validator('priority')
    def validate_priority(cls, v):
        """Validate priority"""
        if not 0 < v <= 10:
            raise ValueError("Priority must be between 0 and 10")
        return v


def validate_agent_request(request: AgentRequest) -> None:
    """Additional validation for agent requests"""
    # Additional business logic validation can go here
    pass


def validate_task_assign_request(request: TaskAssignRequest) -> None:
    """Additional validation for task assignment requests"""
    # Additional business logic validation can go here
    pass