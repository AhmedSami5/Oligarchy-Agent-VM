# ========================================
# Configuration Service - Multi-Environment Support
# ========================================

import os
import yaml
from typing import Dict, List, Any, Optional
from pathlib import Path
import logging
from dataclasses import dataclass

from .agent_manager import AgentConfig, AgentType, AgentPersonality

@dataclass
class EnvironmentConfig:
    name: str
    database_url: str
    redis_url: str
    api_endpoint: str
    max_agents: int
    auto_spawn: bool
    min_idle_agents: int
    log_level: str
    debug: bool

class ConfigurationService:
    """Universal configuration management for all deployment environments"""
    
    def __init__(self, config_dir: str = "configs"):
        self.config_dir = Path(config_dir)
        self.logger = logging.getLogger(__name__)
        self._ensure_config_directory()
    
    def _ensure_config_directory(self) -> None:
        """Ensure configuration directory exists"""
        self.config_dir.mkdir(parents=True, exist_ok=True)
        
        # Create default configs if they don't exist
        self._create_default_configs()
    
    def _create_default_configs(self) -> None:
        """Create default configuration files"""
        defaults = {
            "development.yaml": self._get_development_config(),
            "staging.yaml": self._get_staging_config(),
            "production.yaml": self._get_production_config(),
            "local.yaml": self._get_local_config()
        }
        
        for filename, config in defaults.items():
            config_path = self.config_dir / filename
            if not config_path.exists():
                with open(config_path, 'w') as f:
                    yaml.dump(config, f, default_flow_style=False)
                self.logger.info(f"Created default config: {config_path}")
    
    def load_config(self, environment: Optional[str] = None) -> Dict[str, Any]:
        """Load configuration for specified environment"""
        if environment is None:
            environment = os.getenv("AGENT_ENV", "development")
        
        config_file = self.config_dir / f"{environment}.yaml"
        
        if not config_file.exists():
            self.logger.error(f"Configuration file not found: {config_file}")
            return self._get_development_config()
        
        try:
            with open(config_file, 'r') as f:
                config = yaml.safe_load(f)
            
            # Override with environment variables
            config = self._apply_env_overrides(config)
            
            self.logger.info(f"Loaded configuration for environment: {environment}")
            return config
            
        except Exception as e:
            self.logger.error(f"Failed to load configuration {config_file}: {e}")
            return self._get_development_config()
    
    def save_config(self, config: Dict[str, Any], environment: Optional[str] = None) -> bool:
        """Save configuration to file"""
        if environment is None:
            environment = os.getenv("AGENT_ENV", "development")
        
        config_file = self.config_dir / f"{environment}.yaml"
        
        try:
            with open(config_file, 'w') as f:
                yaml.dump(config, f, default_flow_style=False)
            
            self.logger.info(f"Saved configuration for environment: {environment}")
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to save configuration {config_file}: {e}")
            return False
    
    def get_agent_types(self) -> List[AgentConfig]:
        """Get all available agent type configurations"""
        try:
            agents_file = self.config_dir / "agents.yaml"
            
            if agents_file.exists():
                with open(agents_file, 'r') as f:
                    agents_data = yaml.safe_load(f)
            else:
                agents_data = self._get_default_agents_config()
                self._save_agents_config(agents_data)
            
            # Convert to AgentConfig objects
            agent_configs = []
            for agent_type, data in agents_data.items():
                type_data = data
                personality_data = data.get("personality", {})
                agent_config = AgentConfig(
                    id=agent_type,
                    type=agent_type,
                    name=type_data.get("name", agent_type.capitalize()),
                    description=type_data.get("description", ""),
                    color=type_data.get("color", "#ffffff"),
                    personality=AgentPersonality(**personality_data),
                    capabilities=type_data.get("capabilities", [])
                )
                agent_configs.append(agent_config)
            
            return agent_configs
            
        except Exception as e:
            self.logger.error(f"Failed to load agent types: {e}")
            return []
    
    def _save_agents_config(self, agents_data: Dict[str, Any]) -> None:
        """Save agents configuration"""
        agents_file = self.config_dir / "agents.yaml"
        with open(agents_file, 'w') as f:
            yaml.dump(agents_data, f, default_flow_style=False)
    
    def _apply_env_overrides(self, config: Dict[str, Any]) -> Dict[str, Any]:
        """Apply environment variable overrides"""
        env_mappings = {
            "DATABASE_URL": ["database", "url"],
            "REDIS_URL": ["redis", "url"],
            "API_ENDPOINT": ["api", "endpoint"],
            "MAX_AGENTS": ["system", "max_agents"],
            "AUTO_SPAWN": ["system", "auto_spawn"],
            "MIN_IDLE_AGENTS": ["system", "min_idle_agents"],
            "LOG_LEVEL": ["logging", "level"],
            "DEBUG": ["system", "debug"],
            "AGENTVM_API_KEY": ["agentvm", "api_key"],
        }
        
        for env_var, config_path in env_mappings.items():
            env_value = os.getenv(env_var)
            if env_value is not None:
                # Navigate to nested config path
                current = config
                for key in config_path[:-1]:
                    if key not in current:
                        current[key] = {}
                    current = current[key]
                
                # Set the final value
                final_key = config_path[-1]
                if env_var in ["DEBUG"]:
                    current[final_key] = env_value.lower() in ["true", "1", "yes"]
                elif env_var in ["MAX_AGENTS", "MIN_IDLE_AGENTS"]:
                    current[final_key] = int(env_value)
                else:
                    current[final_key] = env_value
        
        return config
    
    def _get_development_config(self) -> Dict[str, Any]:
        """Default development configuration"""
        return {
            "database": {
                "url": "sqlite:///dev.db",
                "pool_size": 5
            },
            "redis": {
                "url": "redis://localhost:6379/0",
                "decode_responses": True
            },
            "api": {
                "endpoint": "http://localhost:8000",
                "timeout": 30,
                "retry_attempts": 3
            },
            "agentvm": {
                "api_key": "dev-key-change-in-production"
            },
            "system": {
                "max_agents": 10,
                "auto_spawn": True,
                "min_idle_agents": 2,
                "cleanup_interval": 3600,
                "health_check_interval": 60
            },
            "logging": {
                "level": "INFO",
                "format": "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
                "file": "logs/agent-system.log"
            },
            "cloud": {
                "provider": "local",
                "region": "us-west-2",
                "resources": {
                    "cpu_limit": 2,
                    "memory_limit": "4G",
                    "replicas": 1
                }
            },
            "ui": {
                "platform": "web",
                "rendering": {
                    "api": "auto",
                    "quality": "medium",
                    "fps": 60
                }
            }
        }
    
    def _get_staging_config(self) -> Dict[str, Any]:
        """Staging environment configuration"""
        config = self._get_development_config()
        
        # Override staging-specific settings
        config.update({
            "database": {
                "url": os.getenv("DATABASE_URL", "postgresql://agent:password@postgres:5432/agentsystem_staging"),
                "pool_size": 10
            },
            "logging": {
                "level": "DEBUG"
            },
            "cloud": {
                "provider": "aws",
                "resources": {
                    "cpu_limit": 1,
                    "memory_limit": "2G",
                    "replicas": 2
                }
            }
        })
        
        return config
    
    def _get_production_config(self) -> Dict[str, Any]:
        """Production environment configuration"""
        config = self._get_development_config()
        
        # Override production-specific settings
        config.update({
            "database": {
                "url": os.getenv("DATABASE_URL", "postgresql://agent:password@postgres:5432/agentsystem"),
                "pool_size": 20
            },
            "api": {
                "endpoint": os.getenv("API_ENDPOINT", "https://api.agentvm.com"),
                "timeout": 60,
                "retry_attempts": 5
            },
            "agentvm": {
                "api_key": os.getenv("AGENTVM_API_KEY", "")
            },
            "logging": {
                "level": "WARNING",
                "format": "%(asctime)s [%(levelname)s] %(name)s: %(message)s"
            },
            "cloud": {
                "provider": os.getenv("CLOUD_PROVIDER", "aws"),
                "resources": {
                    "cpu_limit": 2,
                    "memory_limit": "4G",
                    "replicas": 3,
                    "autoscaling": True
                }
            }
        })
        
        return config
    
    def _get_local_config(self) -> Dict[str, Any]:
        """Local development configuration"""
        config = self._get_development_config()
        
        # Local-specific overrides
        config.update({
            "database": {
                "url": "sqlite:///local.db"
            },
            "logging": {
                "level": "DEBUG",
                "file": "logs/local-debug.log"
            }
        })
        
        return config
    
    def _get_default_agents_config(self) -> Dict[str, Any]:
        """Default agent type configurations"""
        return {
            "aider": {
                "name": "Aider",
                "description": "Multi-file coding specialist",
                "color": "#0066CC",
                "personality": {
                    "friendliness": 0.7,
                    "efficiency": 0.95,
                    "creativity": 0.6,
                    "talkativeness": 0.4,
                    "collaboration": 0.8
                },
                "capabilities": [
                    "refactoring",
                    "debugging",
                    "optimization",
                    "multi_file_editing"
                ]
            },
            "opencode": {
                "name": "OpenCode",
                "description": "Autonomous coding agent",
                "color": "#00CC66",
                "personality": {
                    "friendliness": 0.9,
                    "efficiency": 0.8,
                    "creativity": 0.9,
                    "talkativeness": 0.8,
                    "collaboration": 0.9
                },
                "capabilities": [
                    "feature_development",
                    "code_generation",
                    "system_design",
                    "autonomous_coding"
                ]
            },
            "claude": {
                "name": "Claude",
                "description": "Conversational coding assistant",
                "color": "#CC6600",
                "personality": {
                    "friendliness": 0.95,
                    "efficiency": 0.85,
                    "creativity": 0.8,
                    "talkativeness": 0.9,
                    "collaboration": 0.85
                },
                "capabilities": [
                    "explanation",
                    "teaching",
                    "code_review",
                    "documentation",
                    "conversation"
                ]
            }
        }
    
    def validate_config(self, config: Dict[str, Any]) -> List[str]:
        """Validate configuration and return list of errors"""
        errors = []
        
        # Required fields
        required_sections = ["database", "api", "system"]
        for section in required_sections:
            if section not in config:
                errors.append(f"Missing required section: {section}")
        
        # Validate database URL
        if "database" in config:
            db_config = config["database"]
            if "url" not in db_config or not db_config["url"]:
                errors.append("Database URL is required")
        
        # Validate API endpoint
        if "api" in config:
            api_config = config["api"]
            if "endpoint" not in api_config or not api_config["endpoint"]:
                errors.append("API endpoint is required")
        
        # Validate system limits
        if "system" in config:
            sys_config = config["system"]
            if sys_config.get("max_agents", 0) <= 0:
                errors.append("max_agents must be positive")
            if sys_config.get("min_idle_agents", 0) < 0:
                errors.append("min_idle_agents cannot be negative")
            if sys_config.get("min_idle_agents", 0) > sys_config.get("max_agents", 0):
                errors.append("min_idle_agents cannot be greater than max_agents")
        
        return errors