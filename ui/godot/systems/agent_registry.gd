# ═══════════════════════════════════════════════════════════════════════════
# agent_registry.gd - Central Agent Management System
# ═══════════════════════════════════════════════════════════════════════════
# Place this file in: addons/agentvm/systems/agent_registry.gd

extends Node
class_name AgentRegistry

## Central registry for managing all agent entities in the game world
## Handles spawning, tracking, and coordinating agent entities

# ═══════════════════════════════════════════════════════════════════════════
# Core Registry Data
# ═══════════════════════════════════════════════════════════════════════════

## All active agent entities by ID
var active_agents: Dictionary[String, AgentEntity] = {}

## Agent templates for different types
var agent_templates: Dictionary = {}

## Configuration resource
var config: AgentConfig

func _ready() -> void:
	"""Initialize the registry"""
	print("[AgentRegistry] Initializing agent management system...")
	
	# Load configuration
	_load_configuration()
	
	# Initialize subsystems
	_initialize_subsystems()
	
	# Start monitoring agent states
	var monitor_timer = Timer.new()
	monitor_timer.wait_time = 0.5
	monitor_timer.timeout.connect(_monitor_agent_states)
	add_child(monitor_timer)
	monitor_timer.start()
	
	print("[AgentRegistry] Ready to manage agents!")


func _load_configuration() -> void:
	"""Load configuration from resource"""
	config = AgentConfig.new()
	
	# Try to load existing configuration
	if ResourceLoader.exists("res://addons/agentvm/config/agent_config.tres"):
		config = load("res://addons/agentvm/config/agent_config.tres")
		print("[AgentRegistry] Loaded configuration from file")
	else:
		# Save default configuration
		config.save_to_file("res://addons/agentvm/config/agent_config.tres")
		print("[AgentRegistry] Created default configuration")
	
	# Initialize agent templates from config
	agent_templates = config.agent_templates.duplicate()
	# Add custom agent types
	for agent_type in config.custom_agent_types:
		agent_templates[agent_type] = config.custom_agent_types[agent_type]
	},
	"opencode": {
		"name": "OpenCode",
		"description": "Autonomous coding agent",
		"color": Color.GREEN,
		"mesh": "capsule",
		"personality": {
			"friendliness": 0.9,
			"efficiency": 0.8,
			"creativity": 0.9,
			"talkativeness": 0.8,
			"collaboration": 0.9
		}
	},
	"claude": {
		"name": "Claude",
		"description": "Conversational coding assistant",
		"color": Color.ORANGE,
		"mesh": "capsule",
		"personality": {
			"friendliness": 0.95,
			"efficiency": 0.85,
			"creativity": 0.8,
			"talkativeness": 0.9,
			"collaboration": 0.85
		}
	}
}

## Available spawn points in the world
var spawn_points: Array[Vector3] = [
	Vector3(0, 0, 0),
	Vector3(3, 0, 0),
	Vector3(-3, 0, 0),
	Vector3(0, 0, 3),
	Vector3(0, 0, -3),
	Vector3(3, 0, 3),
	Vector3(-3, 0, 3),
	Vector3(3, 0, -3),
	Vector3(-3, 0, -3)
]

## Agent counter for unique IDs
var agent_counter: int = 0

## Reference to the AgentVM manager
var agent_manager: AgentVMManager

## Configuration resource
var config: AgentConfig:
    set(value):
        config = value
        # Update dependent systems when config changes
        if behavior_system:
            behavior_system.update_configuration(value)
        if visualization_system:
            visualization_system.update_configuration(value)

# ═══════════════════════════════════════════════════════════════════════════
# Agent Management Systems
# ═══════════════════════════════════════════════════════════════════════════

## Behavior system for agent AI
var behavior_system: AgentBehaviorSystem:
    set(value):
        behavior_system = value
        if value and config:
            value.update_configuration(config)

## Visualization system for agent appearance
var visualization_system: AgentVisualizationSystem:
    set(value):
        visualization_system = value
        if value and config:
            value.update_configuration(config)

## Interaction system for agent communication
var interaction_system: AgentInteractionSystem

## Scene for agent entity
@onready var agent_entity_scene = preload("res://addons/agentvm/scenes/agent_entity.tscn")

# ═══════════════════════════════════════════════════════════════════════════
# Signals
# ═══════════════════════════════════════════════════════════════════════════

signal agent_spawned(agent_id: String, agent: AgentEntity)
signal agent_despawned(agent_id: String)
signal task_assigned(agent_id: String, task: String)
signal agent_state_changed(agent_id: String, state: AgentEntity.AgentState)
signal all_agents_idle()
signal collaboration_started(agent1_id: String, agent2_id: String)


# ═══════════════════════════════════════════════════════════════════════════
# Initialization
# ═══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	"""Initialize the registry"""
	print("[AgentRegistry] Initializing agent management system...")
	
	# Find the AgentVM manager from the plugin
	agent_manager = _find_agent_manager()
	
	# Initialize subsystems
	_initialize_subsystems()
	
	# Start monitoring agent states
	var monitor_timer = Timer.new()
	monitor_timer.wait_time = 0.5
	monitor_timer.timeout.connect(_monitor_agent_states)
	add_child(monitor_timer)
	monitor_timer.start()
	
	print("[AgentRegistry] Ready to manage agents!")


func _find_agent_manager() -> AgentVMManager:
	"""Find the AgentVM manager in the editor plugin"""
	# Look for it in the editor interface
	var editor_interface = Engine.get_singleton("EditorInterface")
	if editor_interface:
		var base_control = editor_interface.get_base_control()
		var agent_vm_node = base_control.find_child("AgentVMManager", true, false)
		if agent_vm_node:
			return agent_vm_node as AgentVMManager
	
	# Fallback: create temporary manager
	push_warning("[AgentRegistry] No AgentVM manager found, creating temporary one")
	var temp_manager = AgentVMManager.new()
	add_child(temp_manager)
	return temp_manager


func _initialize_subsystems() -> void:
	"""Initialize all subsystems"""
	# Create behavior system
	behavior_system = AgentBehaviorSystem.new()
	behavior_system.name = "BehaviorSystem"
	add_child(behavior_system)
	
	# Create visualization system
	visualization_system = AgentVisualizationSystem.new()
	visualization_system.name = "VisualizationSystem"
	add_child(visualization_system)
	
	# Create interaction system
	interaction_system = AgentInteractionSystem.new()
	interaction_system.name = "InteractionSystem"
	add_child(interaction_system)


# ═══════════════════════════════════════════════════════════════════════════
# Public API - Agent Lifecycle Management
# ═══════════════════════════════════════════════════════════════════════════

func spawn_agent(agent_type: String, position: Vector3 = Vector3.ZERO) -> String:
	"""Spawn a new agent of the specified type"""
	if not agent_templates.has(agent_type):
		push_error("[AgentRegistry] Unknown agent type: %s" % agent_type)
		return ""
	
	# Validate position to prevent extreme values
	if position.length() > 1000:
		push_warning("[AgentRegistry] Extreme position detected, resetting to origin")
		position = Vector3.ZERO
	
	# Generate unique ID
	agent_counter += 1
	var agent_id = "%s_agent_%d" % [agent_type, agent_counter]
	
	# Choose spawn position if not provided
	var spawn_pos = position
	if spawn_pos == Vector3.ZERO:
		spawn_pos = _get_next_spawn_point()
	
	# Create agent entity
	var agent_entity = _create_agent_entity(agent_id, agent_type, spawn_pos)
	if not agent_entity:
		push_error("[AgentRegistry] Failed to create agent entity")
		return ""
	
	# Add to scene tree
	get_tree().current_scene.add_child(agent_entity)
	
	# Initialize agent
	agent_entity.initialize(agent_id, agent_type, agent_manager, spawn_pos)
	
	# Register agent
	active_agents[agent_id] = agent_entity
	
	# Connect signals
	_connect_agent_signals(agent_entity)
	
	# Apply subsystem configurations
	behavior_system.apply_agent_behavior(agent_entity)
	visualization_system.apply_agent_visualization(agent_entity)
	interaction_system.register_agent(agent_entity)
	
	print("[AgentRegistry] Spawned %s agent at %s" % [agent_type, spawn_pos])
	agent_spawned.emit(agent_id, agent_entity)
	
	return agent_id


func despawn_agent(agent_id: String) -> bool:
	"""Despawn an agent"""
	if not active_agents.has(agent_id):
		push_warning("[AgentRegistry] Agent not found: %s" % agent_id)
		return false
	
	var agent = active_agents[agent_id]
	
	# Clean up subsystems
	interaction_system.unregister_agent(agent)
	
	# Remove from scene
	agent.queue_free()
	
	# Remove from registry
	active_agents.erase(agent_id)
	
	print("[AgentRegistry] Despawned agent: %s" % agent_id)
	agent_despawned.emit(agent_id)
	
	return true


func despawn_all_agents() -> void:
	"""Despawn all agents"""
	var agent_ids = active_agents.keys()
	for agent_id in agent_ids:
		despawn_agent(agent_id)


func get_agent(agent_id: String) -> AgentEntity:
	"""Get agent by ID"""
	return active_agents.get(agent_id, null)


func get_agents_by_type(agent_type: String) -> Array[AgentEntity]:
	"""Get all agents of a specific type"""
	var result: Array[AgentEntity] = []
	for agent in active_agents.values():
		if agent.agent_type == agent_type:
			result.append(agent)
	return result


func get_idle_agents() -> Array[AgentEntity]:
	"""Get all idle agents"""
	var result: Array[AgentEntity] = []
	for agent in active_agents.values():
		if agent.state == AgentEntity.AgentState.IDLE:
			result.append(agent)
	return result


func get_active_agents() -> Array[AgentEntity]:
	"""Get all agents (copy of values)"""
	return active_agents.values()


func get_agent_count() -> int:
	"""Get total number of agents"""
	return active_agents.size()


func get_agent_count_by_type(agent_type: String) -> int:
	"""Get number of agents of specific type"""
	var count = 0
	for agent in active_agents.values():
		if agent.agent_type == agent_type:
			count += 1
	return count


# ═══════════════════════════════════════════════════════════════════════════
# Public API - Task Management
# ═══════════════════════════════════════════════════════════════════════════

func assign_task_to_agent(agent_id: String, task: String) -> bool:
	"""Assign a task to a specific agent"""
	var agent = get_agent(agent_id)
	if not agent:
		push_warning("[AgentRegistry] Agent not found: %s" % agent_id)
		return false
	
	agent.assign_task(task)
	task_assigned.emit(agent_id, task)
	return true


func assign_task_to_best_agent(task: String, preferred_type: String = "") -> String:
	"""Assign task to the best available agent"""
	var candidates: Array[AgentEntity] = []
	
	# Get all idle agents
	var idle_agents = get_idle_agents()
	
	# Filter by preferred type if specified
	if preferred_type != "":
		candidates = get_agents_by_type(preferred_type).filter(
			func(agent): return agent.state == AgentEntity.AgentState.IDLE
		)
	
	# Fall back to any idle agent
	if candidates.is_empty():
		candidates = idle_agents
	
	if candidates.is_empty():
		push_warning("[AgentRegistry] No available agents for task assignment")
		return ""
	
	# Select the best candidate (simple implementation - first available)
	var best_agent = candidates[0]
	
	assign_task_to_agent(best_agent.agent_id, task)
	return best_agent.agent_id


func assign_collaborative_task(task: String, team_size: int = 2) -> Array[String]:
	"""Assign a task to a team of agents for collaboration"""
	var idle_agents = get_idle_agents()
	
	if idle_agents.size() < team_size:
		push_warning("[AgentRegistry] Not enough idle agents for collaboration")
		return []
	
	var team: Array[String] = []
	for i in range(team_size):
		var agent = idle_agents[i]
		team.append(agent.agent_id)
		assign_task_to_agent(agent.agent_id, task)
	
	# Trigger collaboration
	if team.size() >= 2:
		_trigger_collaboration(team[0], team[1])
	
	return team


# ═══════════════════════════════════════════════════════════════════════════
# Public API - Configuration
# ═══════════════════════════════════════════════════════════════════════════

func add_spawn_point(position: Vector3) -> void:
	"""Add a new spawn point"""
	spawn_points.append(position)


func set_spawn_points(positions: Array[Vector3]) -> void:
	"""Set all spawn points"""
	spawn_points = positions


func get_spawn_points() -> Array[Vector3]:
	"""Get all spawn points"""
	return spawn_points.duplicate()


func register_agent_template(agent_type: String, template: Dictionary) -> void:
	"""Register a new agent template"""
	agent_templates[agent_type] = template


func get_agent_template(agent_type: String) -> Dictionary:
	"""Get agent template by type"""
	return agent_templates.get(agent_type, {})


func get_available_agent_types() -> Array[String]:
	"""Get list of available agent types"""
	return agent_templates.keys()


# ═══════════════════════════════════════════════════════════════════════════
# Private Methods
# ═══════════════════════════════════════════════════════════════════════════

func _create_agent_entity(agent_id: String, agent_type: String, position: Vector3) -> AgentEntity:
	"""Create an agent entity"""
	# Try to load from scene file first
	if ResourceLoader.exists("res://addons/agentvm/scenes/agent_entity.tscn"):
		var scene = load("res://addons/agentvm/scenes/agent_entity.tscn") as PackedScene
		if scene:
			var agent = scene.instantiate() as AgentEntity
			agent.global_position = position
			return agent
	
	# Fallback: create agent entity programmatically
	var agent = AgentEntity.new()
	agent.global_position = position
	
	# Create basic components
	_create_basic_agent_components(agent)
	
	return agent


func _create_basic_agent_components(agent: AgentEntity) -> void:
	"""Create basic components for agent entity"""
	# Create mesh
	var mesh_instance = MeshInstance3D.new()
	var capsule_mesh = CapsuleMesh.new()
	capsule_mesh.height = 1.8
	capsule_mesh.radius = 0.4
	mesh_instance.mesh = capsule_mesh
	agent.add_child(mesh_instance)
	
	# Create collision shape
	var collision_shape = CollisionShape3D.new()
	var capsule_shape = CapsuleShape3D.new()
	capsule_shape.height = 1.8
	capsule_shape.radius = 0.4
	collision_shape.shape = capsule_shape
	agent.add_child(collision_shape)
	
	# Create animation player
	var animation_player = AnimationPlayer.new()
	agent.add_child(animation_player)
	
	# Create status indicator
	var status_indicator = Sprite3D.new()
	status_indicator.position.y = 2.2
	status_indicator.texture = _create_status_indicator_texture()
	agent.add_child(status_indicator)
	
	# Create label
	var label = Label3D.new()
	label.position.y = 2.5
	label.font_size = 16
	agent.add_child(label)
	
	# Create interaction area
	var interaction_area = Area3D.new()
	var collision_shape_2 = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 2.0
	collision_shape_2.shape = sphere_shape
	interaction_area.add_child(collision_shape_2)
	agent.add_child(interaction_area)


func _create_status_indicator_texture() -> Texture2D:
	"""Create a simple status indicator texture"""
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	
	# Draw a simple circle
	for x in range(32):
		for y in range(32):
			var dist = Vector2(x - 16, y - 16).length()
			if dist < 12:
				image.set_pixel(x, y, Color.WHITE)
	
	return ImageTexture.create_from_image(image)


func _get_next_spawn_point() -> Vector3:
	"""Get the next available spawn point"""
	if spawn_points.is_empty():
		return Vector3.ZERO
	
	# Simple round-robin selection
	var index = agent_counter % spawn_points.size()
	return spawn_points[index]


func _connect_agent_signals(agent: AgentEntity) -> void:
	"""Connect agent signals to registry"""
	agent.task_started.connect(_on_agent_task_started)
	agent.task_completed.connect(_on_agent_task_completed)
	agent.task_failed.connect(_on_agent_task_failed)
	agent.state_changed.connect(_on_agent_state_changed)
	agent.interaction_requested.connect(_on_agent_interaction_requested)


func _trigger_collaboration(agent1_id: String, agent2_id: String) -> void:
	"""Trigger collaboration between two agents"""
	var agent1 = get_agent(agent1_id)
	var agent2 = get_agent(agent2_id)
	
	if agent1 and agent2:
		agent1.collaborate_with(agent2)
		collaboration_started.emit(agent1_id, agent2_id)


# ═══════════════════════════════════════════════════════════════════════════
# Signal Handlers
# ═══════════════════════════════════════════════════════════════════════════

func _on_agent_task_started(agent_id: String, task: String) -> void:
	"""Handle agent task started"""
	print("[AgentRegistry] Agent %s started task: %s" % [agent_id, task.substr(0, 30)])


func _on_agent_task_completed(agent_id: String, result: String) -> void:
	"""Handle agent task completed"""
	print("[AgentRegistry] Agent %s completed task" % agent_id)
	_monitor_agent_states()


func _on_agent_task_failed(agent_id: String, error: String) -> void:
	"""Handle agent task failed"""
	print("[AgentRegistry] Agent %s task failed: %s" % [agent_id, error.substr(0, 30)])


func _on_agent_state_changed(agent_id: String, new_state: AgentEntity.AgentState) -> void:
	"""Handle agent state change"""
	print("[AgentRegistry] Agent %s state changed to: %s" % [agent_id, new_state])
	agent_state_changed.emit(agent_id, new_state)


func _on_agent_interaction_requested(agent_id: String) -> void:
	"""Handle agent interaction request"""
	print("[AgentRegistry] Agent %s interaction requested" % agent_id)
	# TODO: Show interaction UI


func _monitor_agent_states() -> void:
	"""Monitor all agent states and emit signals"""
	var all_idle = true
	
	for agent in active_agents.values():
		if agent.state != AgentEntity.AgentState.IDLE:
			all_idle = false
			break
	
	if all_idle and not active_agents.is_empty():
		all_agents_idle.emit()