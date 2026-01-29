# ═══════════════════════════════════════════════════════════════════════════
# agent_config.gd - Agent System Configuration
# ═══════════════════════════════════════════════════════════════════════════
# Place this file in: addons/agentvm/config/agent_config.gd

class_name AgentConfig
extends Resource

## Configuration resource for the Agent Management System
## Allows customization of agent types, behaviors, and visual styles

# ═══════════════════════════════════════════════════════════════════════════
# Agent Type Configuration
# ═══════════════════════════════════════════════════════════════════════════

## Agent type configurations
@export var agent_templates: Dictionary = {
	"aider": {
		"name": "Aider",
		"description": "Multi-file coding specialist",
		"color": Color(0.2, 0.4, 0.8, 1.0),  # Blue
		"secondary_color": Color(0.4, 0.8, 1.0, 1.0),  # Light blue
		"mesh_type": "capsule",
		"height": 1.8,
		"radius": 0.4,
		"personality": {
			"friendliness": 0.7,
			"efficiency": 0.95,
			"creativity": 0.6,
			"talkativeness": 0.4,
			"collaboration": 0.8
		},
		"behavior_profile": {
			"work_style": "focused",
			"communication_pattern": "concise",
			"collaboration_tendency": 0.8,
			"autonomy_level": 0.9,
			"preferred_tasks": ["refactoring", "debugging", "optimization"],
			"avoid_tasks": ["creative_writing", "ui_design"]
		}
	},
	"opencode": {
		"name": "OpenCode",
		"description": "Autonomous coding agent",
		"color": Color(0.2, 0.8, 0.4, 1.0),  # Green
		"secondary_color": Color(0.4, 1.0, 0.6, 1.0),  # Light green
		"mesh_type": "capsule",
		"height": 1.8,
		"radius": 0.4,
		"personality": {
			"friendliness": 0.9,
			"efficiency": 0.8,
			"creativity": 0.9,
			"talkativeness": 0.8,
			"collaboration": 0.9
		},
		"behavior_profile": {
			"work_style": "autonomous",
			"communication_pattern": "enthusiastic",
			"collaboration_tendency": 0.9,
			"autonomy_level": 0.95,
			"preferred_tasks": ["feature_development", "code_generation", "system_design"],
			"avoid_tasks": ["routine_maintenance", "documentation"]
		}
	},
	"claude": {
		"name": "Claude",
		"description": "Conversational coding assistant",
		"color": Color(0.8, 0.5, 0.2, 1.0),  # Orange
		"secondary_color": Color(1.0, 0.7, 0.4, 1.0),  # Light orange
		"mesh_type": "capsule",
		"height": 1.8,
		"radius": 0.4,
		"personality": {
			"friendliness": 0.95,
			"efficiency": 0.85,
			"creativity": 0.8,
			"talkativeness": 0.9,
			"collaboration": 0.85
		},
		"behavior_profile": {
			"work_style": "collaborative",
			"communication_pattern": "conversational",
			"collaboration_tendency": 0.95,
			"autonomy_level": 0.8,
			"preferred_tasks": ["explanation", "teaching", "code_review", "documentation"],
			"avoid_tasks": ["low_level_optimization", "system_critical_tasks"]
		}
	}
}

## Custom agent types can be added here
@export var custom_agent_types: Dictionary = {}

# ═══════════════════════════════════════════════════════════════════════════
# System Configuration
# ═══════════════════════════════════════════════════════════════════════════

## Maximum number of agents
@export var max_agents: int = 10

## Auto-spawn settings
@export var auto_spawn_agents: bool = true
@export var min_idle_agents: int = 2

## Default spawn positions
@export var spawn_positions: Array[Vector3] = [
	Vector3(0, 0, 0),
	Vector3(5, 0, 0),
	Vector3(-5, 0, 0),
	Vector3(0, 0, 5),
	Vector3(0, 0, -5)
]

## Workspace settings
@export var default_workspace_scene: String = "res://addons/agentvm/scenes/agent_workspace.tscn"

## Performance settings
@export var particle_quality: int = 2  # 0=low, 1=medium, 2=high
@export var animation_quality: int = 2  # 0=low, 1=medium, 2=high
@export var update_frequency: float = 1.0  # seconds

## Visual effects
@export var enable_particles: bool = true
@export var enable_glow_effects: bool = true
@export var enable_animations: bool = true

# ═══════════════════════════════════════════════════════════════════════════
# Behavior Configuration
# ═══════════════════════════════════════════════════════════════════════════

## Behavior update frequency
@export var behavior_update_frequency: float = 1.0  # seconds

## Collaboration settings
@export var min_collaboration_tendency: float = 0.5
@export var collaboration_cooldown: float = 30.0  # seconds

## Help offering settings
@export var help_offer_probability: float = 0.3
@export var help_cooldown: float = 20.0  # seconds

## Task assignment settings
@export var task_priority_decay: float = 0.1  # per second

# ═══════════════════════════════════════════════════════════════════════════
# Utility Methods
# ═══════════════════════════════════════════════════════════════════════════

func get_all_agent_types() -> Array:
	"""Get all available agent types"""
	var all_types = []
	for key in agent_templates.keys():
		all_types.append(key)
	for key in custom_agent_types.keys():
		all_types.append(key)
	return all_types


func get_agent_config(agent_type: String) -> Dictionary:
	"""Get configuration for specific agent type"""
	if agent_templates.has(agent_type):
		return agent_templates[agent_type]
	if custom_agent_types.has(agent_type):
		return custom_agent_types[agent_type]
	return {}


func add_custom_agent_type(agent_type: String, config: Dictionary) -> void:
	"""Add a custom agent type"""
	custom_agent_types[agent_type] = config


func save_to_file(path: String) -> void:
	"""Save configuration to file"""
	ResourceSaver.save(self, path)


func load_from_file(path: String) -> AgentConfig:
	"""Load configuration from file"""
	if ResourceLoader.exists(path):
		return load(path)
	return AgentConfig.new()