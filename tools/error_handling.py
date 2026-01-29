#!/usr/bin/env python3
"""
Error handling utilities for Oligarchy AgentVM

Provides consistent error handling patterns across the codebase.
"""

from typing import Optional, Dict, Any, Union
from dataclasses import dataclass
import logging

logger = logging.getLogger(__name__)


@dataclass
class APIError(Exception):
    """Base exception for API-related errors"""
    message: str
    status_code: Optional[int] = None
    details: Optional[Dict[str, Any]] = None
    
    def __str__(self) -> str:
        if self.status_code:
            return f"[{self.status_code}] {self.message}"
        return self.message


@dataclass
class ValidationError(Exception):
    """Raised when input validation fails"""
    field: str
    value: Any
    message: str
    
    def __str__(self) -> str:
        return f"Validation error in field '{self.field}': {self.message}"


@dataclass
class ConfigurationError(Exception):
    """Raised when configuration is invalid or missing"""
    component: str
    message: str
    
    def __str__(self) -> str:
        return f"Configuration error in {self.component}: {self.message}"


class ErrorHandler:
    """Centralized error handling utilities"""
    
    @staticmethod
    def validate_agent_type(agent_type: str) -> None:
        """Validate agent type"""
        valid_types = ["aider", "opencode", "claude"]
        if agent_type not in valid_types:
            raise ValidationError(
                field="agent_type",
                value=agent_type,
                message="Invalid agent type. Must be one of: "
                       f"{', '.join(valid_types)}"
            )
    
    @staticmethod
    def validate_prompt(prompt: str) -> None:
        """Validate prompt"""
        if not prompt or not prompt.strip():
            raise ValidationError(
                field="prompt",
                value=prompt,
                message="Prompt cannot be empty"
            )
        if len(prompt) > 10000:  # Arbitrary limit
            raise ValidationError(
                field="prompt",
                value=len(prompt),
                message="Prompt too long (max 10000 characters)"
            )
    
    @staticmethod
    def validate_timeout(timeout: Union[int, float]) -> None:
        """Validate timeout value"""
        if not isinstance(timeout, (int, float)) or timeout <= 0:
            raise ValidationError(
                field="timeout",
                value=timeout,
                message="Timeout must be a positive number"
            )
        if timeout > 3600:  # 1 hour limit
            raise ValidationError(
                field="timeout",
                value=timeout,
                message="Timeout too long (max 3600 seconds)"
            )
    
    @staticmethod
    def validate_repo_path(repo_path: Optional[str]) -> None:
        """Validate repository path"""
        if repo_path and not repo_path.startswith(("/", "~", ".")):
            raise ValidationError(
                field="repo_path",
                value=repo_path,
                message="Repository path must be absolute or relative"
            )
    
    @staticmethod
    def handle_api_error(response, context: str = "") -> None:
        """Handle API response errors"""
        if response.status_code >= 400:
            try:
                error_data = response.json()
                error_msg = error_data.get("detail", response.text)
            except Exception:
                error_msg = response.text
            
            logger.error(f"API error {context}: {response.status_code} - {error_msg}")
            
            raise APIError(
                message=f"API request failed: {error_msg}",
                status_code=response.status_code,
                details={
                    "context": context, 
                    "response_text": response.text
                }
            )
    
    @staticmethod
    def handle_network_error(exception: Exception, context: str = "") -> None:
        """Handle network-related errors"""
        logger.error(f"Network error {context}: {exception}")
        
        raise APIError(
            message=f"Network error: {str(exception)}",
            details={"context": context, "original_error": str(exception)}
        )
    
    @staticmethod
    def handle_timeout_error(exception: Exception, context: str = "") -> None:
        """Handle timeout errors"""
        logger.error(f"Timeout error {context}: {exception}")
        
        raise APIError(
            message=f"Request timed out: {str(exception)}",
            details={"context": context, "original_error": str(exception)}
        )
    
    @staticmethod
    def validate_api_key(api_key: Optional[str]) -> None:
        """Validate API key"""
        if not api_key:
            raise ConfigurationError(
                component="API client",
                message="API key is required"
            )
        if len(api_key) < 8:
            raise ValidationError(
                field="api_key",
                value="***",
                message="API key too short (minimum 8 characters)"
            )


def safe_execute(func):
    """Decorator to provide consistent error handling"""
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except ValidationError as e:
            logger.error(f"Validation error: {e}")
            raise
        except APIError as e:
            logger.error(f"API error: {e}")
            raise
        except Exception as e:
            logger.error(f"Unexpected error: {e}")
            raise APIError(
                message=f"Unexpected error: {str(e)}",
                details={"function": func.__name__, "args": str(args)}
            )
    return wrapper