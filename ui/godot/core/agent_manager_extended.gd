# ═══════════════════════════════════════════════════════════════════════════
# agent_manager_extended.gd - Extended Manager for Game Integration
# ═══════════════════════════════════════════════════════════════════════════
# Place this file in: addons/agentvm/core/agent_manager_extended.gd

extends Node
class_name AgentVMManagerExtended

## Extended agent manager that integrates with the game world
## Combines the original AgentVMManager with game-specific functionality

# ═══════════════════════════════════════════════════════════════════════════
# Original AgentVM Components
# ═══════════════════════════════════════════════════════════════════════════

## Original agent manager for API communication
var base_manager: AgentVMManager

# ═══════════════════════════════════════════════════════════════════════════
# Game Integration Components
# ═══════════════════════════════════════════════════════════════════════════

## Agent registry for managing game entities
var agent_registry: AgentRegistry

## Active agent entities
var active_entities: Dictionary[String, AgentEntity] = {}

## Agent workspaces
var workspaces: Dictionary[String, Node3D] = {}

## Game task queue
var game_task_queue: Array[Dictionary] = []

## Agent assignments
var agent_assignments: Dictionary[String, String] = {}  # agent_id -> task_id

# ═══════════════════════════════════════════════════════════════════════════
# Extended Configuration
# ═══════════════════════════════════════════════════════════════════════════

## Maximum number of agents
var max_agents: int = 10

## Default workspace scene
var workspace_scene: PackedScene

## Agent spawn positions
var spawn_positions: Array[Vector3] = [
	Vector3(0, 0, 0),
	Vector3(5, 0, 0),
	Vector3(-5, 0, 0),
	Vector3(0, 0, 5),
	Vector3(0, 0, -5)
]

## Auto-spawn settings
var auto_spawn_agents: bool = true
var min_idle_agents: int = 2

# ═══════════════════════════════════════════════════════════════════════════
# Extended Signals
# ═══════════════════════════════════════════════════════════════════════════

signal game_agent_spawned(agent_id: String, agent: AgentEntity)
signal game_agent_despawned(agent_id: String)
signal workspace_created(workspace_id: String, workspace: Node3D)
signal agent_assigned_to_workspace(agent_id: String, workspace_id: String)
signal game_task_completed(agent_id: String, task_result: Dictionary)


# ═══════════════════════════════════════════════════════════════════════════
# Initialization
# ═══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	"""Initialize the extended manager"""
	print("[AgentVMManagerExtended] Initializing extended manager...")
	
	# Create base manager
	_create_base_manager()
	
	# Create agent registry
	_create_agent_registry()
	
	# Load workspace scene
	_load_workspace_scene()
	
	# Start management timers
	_start_management_timers()
	
	# Auto-spawn initial agents
	if auto_spawn_agents:
		await get_tree().create_timer(2.0).timeout
		_spawn_initial_agents()
	
	print("[AgentVMManagerExtended] Extended manager ready!")


func _create_base_manager() -> void:
	"""Create the base AgentVM manager"""
	base_manager = AgentVMManager.new()
	base_manager.name = "BaseManager"
	add_child(base_manager)
	
	# Connect base manager signals
	base_manager.task_started.connect(_on_base_task_started)
	base_manager.task_completed.connect(_on_base_task_completed)
	base_manager.task_failed.connect(_on_base_task_failed)
	base_manager.connection_status_changed.connect(_on_base_connection_changed)


func _create_agent_registry() -> void:
	"""Create the agent registry"""
	agent_registry = AgentRegistry.new()
	agent_registry.name = "AgentRegistry"
	add_child(agent_registry)
	
	# Connect registry signals
	agent_registry.agent_spawned.connect(_on_registry_agent_spawned)
	agent_registry.agent_despawned.connect(_on_registry_agent_despawned)
	agent_registry.task_assigned.connect(_on_registry_task_assigned)
	agent_registry.agent_state_changed.connect(_on_registry_state_changed)


func _load_workspace_scene() -> void:
	"""Load the workspace scene"""
	if ResourceLoader.exists("res://addons/agentvm/scenes/agent_workspace.tscn"):
		workspace_scene = load("res://addons/agentvm/scenes/agent_workspace.tscn") as PackedScene
		print("[AgentVMManagerExtended] Workspace scene loaded")
	else:
		print("[AgentVMManagerExtended] Workspace scene not found, will create programmatically")


func _start_management_timers() -> void:
	"""Start management timers"""
	# Task queue processor
	var task_timer = Timer.new()
	task_timer.wait_time = 1.0
	task_timer.timeout.connect(_process_task_queue)
	add_child(task_timer)
	task_timer.start()
	
	# Agent balancer
	var balance_timer = Timer.new()
	balance_timer.wait_time = 5.0
	balance_timer.timeout.connect(_balance_agent_workload)
	add_child(balance_timer)
	balance_timer.start()


func _spawn_initial_agents() -> void:
	"""Spawn initial set of agents"""
	var agent_types = ["aider", "opencode", "claude"]
	
	for i in range(min_idle_agents):
		var agent_type = agent_types[i % agent_types.size()]
		var position = spawn_positions[i % spawn_positions.size()]
		
		var agent_id = spawn_game_agent(agent_type, position)
		
		# Assign to workspace
		if agent_id != "":
			_assign_agent_to_workspace(agent_id)


# ═══════════════════════════════════════════════════════════════════════════
# Public API - Agent Lifecycle
# ═══════════════════════════════════════════════════════════════════════════

func spawn_game_agent(agent_type: String, position: Vector3 = Vector3.ZERO) -> String:
	"""Spawn a new agent in the game world"""
	if active_entities.size() >= max_agents:
		print("[AgentVMManagerExtended] Max agents reached")
		return ""
	
	# Create agent via registry
	var agent_id = agent_registry.spawn_agent(agent_type, position)
	
	if agent_id == "":
		return ""
	
	var agent = agent_registry.get_agent(agent_id)
	if agent:
		active_entities[agent_id] = agent
		agent_assignments[agent_id] = ""
		
		print("[AgentVMManagerExtended] Spawned game agent: %s" % agent_id)
		game_agent_spawned.emit(agent_id, agent)
	
	return agent_id


func despawn_game_agent(agent_id: String) -> bool:
	"""Despawn a game agent"""
	if not active_entities.has(agent_id):
		return false
	
	# Remove from workspace
	_unassign_agent_from_workspace(agent_id)
	
	# Remove via registry
	agent_registry.despawn_agent(agent_id)
	
	# Clean up assignments
	agent_assignments.erase(agent_id)
	active_entities.erase(agent_id)
	
	print("[AgentVMManagerExtended] Despawned game agent: %s" % agent_id)
	game_agent_despawned.emit(agent_id)
	
	return true


func get_game_agent(agent_id: String) -> AgentEntity:
	"""Get a game agent by ID"""
	return active_entities.get(agent_id, null)


func get_all_game_agents() -> Dictionary:
	"""Get all game agents"""
	return active_entities.duplicate()


func get_idle_game_agents() -> Array[AgentEntity]:
	"""Get all idle game agents"""
	var idle_agents: Array[AgentEntity] = []
	for agent in active_entities.values():
		if agent.state == AgentEntity.AgentState.IDLE:
			idle_agents.append(agent)
	return idle_agents


# ═══════════════════════════════════════════════════════════════════════════
# Public API - Task Management
# ═══════════════════════════════════════════════════════════════════════════

func assign_game_task(agent_id: String, task: String, task_type: String = "general") -> bool:
	"""Assign a task to a specific game agent"""
	# Validate task input
	var clean_task = task.strip_edges()
	if clean_task.is_empty():
		push_error("[AgentVMManagerExtended] Task cannot be empty")
		return false
	
	if clean_task.length() > 500:
		push_error("[AgentVMManagerExtended] Task description too long (max 500 chars)")
		return false
	
	var agent = get_game_agent(agent_id)
	if not agent:
		return false
	
	# Add to game task queue
	game_task_queue.append({
		"agent_id": agent_id,
		"task": task,
		"task_type": task_type,
		"priority": 1.0,
		"timestamp": Time.get_unix_time_from_system()
	})
	
	return true


func assign_task_to_best_agent(task: String, task_type: String = "general") -> String:
	"""Assign task to the best available agent"""
	var best_agent_id = ""
	var best_score = 0.0
	
	for agent_id in active_entities.keys():
		var agent = active_entities[agent_id]
		
		# Only consider idle agents
		if agent.state != AgentEntity.AgentState.IDLE:
			continue
		
		# Calculate score based on agent type and personality
		var score = _calculate_task_suitability(agent_id, task_type)
		
		if score > best_score:
			best_score = score
			best_agent_id = agent_id
	
	if best_agent_id != "":
		assign_game_task(best_agent_id, task, task_type)
	
	return best_agent_id


func assign_collaborative_task(task: String, team_size: int = 2) -> Array[String]:
	"""Assign a collaborative task to a team of agents"""
	var idle_agents = get_idle_game_agents()
	
	if idle_agents.size() < team_size:
		return []
	
	var team: Array[String] = []
	
	# Select best team based on compatibility
	var best_team = _select_best_team(idle_agents, team_size, task)
	
	for agent in best_team:
		assign_game_task(agent.agent_id, task, "collaboration")
		team.append(agent.agent_id)
	
	# Trigger collaboration
	if team.size() >= 2:
		_trigger_agent_collaboration(team)
	
	return team


# ═══════════════════════════════════════════════════════════════════════════
# Public API - Workspace Management
# ═══════════════════════════════════════════════════════════════════════════

func create_workspace(workspace_id: String, position: Vector3 = Vector3.ZERO) -> Node3D:
	"""Create a new workspace"""
	if workspaces.has(workspace_id):
		return workspaces[workspace_id]
	
	var workspace: Node3D
	
	if workspace_scene:
		workspace = workspace_scene.instantiate()
	else:
		workspace = _create_default_workspace()
	
	workspace.name = workspace_id
	workspace.global_position = position
	get_tree().current_scene.add_child(workspace)
	
	workspaces[workspace_id] = workspace
	
	print("[AgentVMManagerExtended] Created workspace: %s" % workspace_id)
	workspace_created.emit(workspace_id, workspace)
	
	return workspace


func assign_agent_to_workspace(agent_id: String, workspace_id: String) -> bool:
	"""Assign an agent to a workspace"""
	var agent = get_game_agent(agent_id)
	var workspace = workspaces.get(workspace_id)
	
	if not agent or not workspace:
		return false
	
	# Find agent position in workspace
	var agent_position = workspace.get_node("AgentPosition")
	if agent_position:
		agent.move_to_position(agent_position.global_position)
		agent.workspace_position = agent_position.global_position
	
	agent_assignments[agent_id] = workspace_id
	
	print("[AgentVMManagerExtended] Assigned %s to workspace %s" % [agent_id, workspace_id])
	agent_assigned_to_workspace.emit(agent_id, workspace_id)
	
	return true


func _assign_agent_to_workspace(agent_id: String) -> void:
	"""Auto-assign agent to available workspace"""
	var available_workspaces = []
	
	for workspace_id in workspaces.keys():
		var assigned = false
		for other_agent_id in agent_assignments.keys():
			if agent_assignments[other_agent_id] == workspace_id:
				assigned = true
				break
		if not assigned:
			available_workspaces.append(workspace_id)
	
	if not available_workspaces.is_empty():
		assign_agent_to_workspace(agent_id, available_workspaces[0])
	else:
		# Create new workspace
		var workspace_id = "workspace_%d" % workspaces.size()
		var position = spawn_positions[workspaces.size() % spawn_positions.size()]
		create_workspace(workspace_id, position)
		assign_agent_to_workspace(agent_id, workspace_id)


func _unassign_agent_from_workspace(agent_id: String) -> void:
	"""Unassign agent from workspace"""
	agent_assignments.erase(agent_id)


# ═══════════════════════════════════════════════════════════════════════════
# Private Methods - Task Processing
# ═══════════════════════════════════════════════════════════════════════════

func _process_task_queue() -> void:
	"""Process the game task queue"""
	if game_task_queue.is_empty():
		return
	
	# Sort by priority and timestamp
	game_task_queue.sort_custom(func(a, b): 
		if a.priority != b.priority:
			return a.priority > b.priority
		return a.timestamp < b.timestamp
	)
	
	# Process as many tasks as we have idle agents
	var idle_agents = get_idle_game_agents()
	
	for task in game_task_queue.duplicate():
		if idle_agents.is_empty():
			break
		
		var agent = idle_agents.pop_back()
		_execute_agent_task(agent.agent_id, task)
		game_task_queue.erase(task)


func _execute_agent_task(agent_id: String, task_data: Dictionary) -> void:
	"""Execute a task on an agent"""
	var agent = get_game_agent(agent_id)
	if not agent:
		return
	
	var task = task_data.task
	var task_type = task_data.task_type
	
	# Assign task to agent
	agent_assignments[agent_id] = task_data.get("task_id", "")
	
	# Execute via base manager
	var base_task_id = base_manager.run_agent(task, agent.agent_type)
	
	if base_task_id != "":
		agent_assignments[agent_id] = base_task_id
		agent.assign_task(task)
		print("[AgentVMManagerExtended] Executed task on %s: %s" % [agent_id, task.substr(0, 30)])
	else:
		print("[AgentVMManagerExtended] Failed to execute task on %s" % agent_id)


func _calculate_task_suitability(agent_id: String, task_type: String) -> float:
	"""Calculate how suitable an agent is for a task"""
	var agent = get_game_agent(agent_id)
	if not agent:
		return 0.0
	
	var base_score = 0.5
	
	# Agent type bonuses
	match task_type:
		"debugging", "optimization":
			if agent.agent_type == "aider":
				base_score += 0.3
		"feature_development", "creative":
			if agent.agent_type == "opencode":
				base_score += 0.3
		"documentation", "teaching":
			if agent.agent_type == "claude":
				base_score += 0.3
	
	# Personality factors
	var efficiency = agent.personality.get("efficiency", 0.5)
	var creativity = agent.personality.get("creativity", 0.5)
	var collaboration = agent.personality.get("collaboration", 0.5)
	
	match task_type:
		"debugging":
			base_score += efficiency * 0.2
		"feature_development":
			base_score += creativity * 0.2
		"collaboration":
			base_score += collaboration * 0.2
	
	return clamp(base_score, 0.0, 1.0)


func _select_best_team(agents: Array[AgentEntity], team_size: int, task: String) -> Array[AgentEntity]:
	"""Select the best team for a collaborative task"""
	var best_team: Array[AgentEntity] = []
	var best_score = 0.0
	
	# Try all combinations (simplified for performance)
	if agents.size() >= team_size:
		# Just take the first N agents for now
		# In a more complex implementation, we'd test all combinations
		for i in range(team_size):
			if i < agents.size():
				best_team.append(agents[i])
	
	return best_team


func _trigger_agent_collaboration(team: Array[String]) -> void:
	"""Trigger collaboration between team members"""
	if team.size() < 2:
		return
	
	var agent1 = get_game_agent(team[0])
	var agent2 = get_game_agent(team[1])
	
	if agent1 and agent2:
		agent1.collaborate_with(agent2)


func _balance_agent_workload() -> void:
	"""Balance workload among agents"""
	if not auto_spawn_agents:
		return
	
	var idle_count = get_idle_game_agents().size()
	var active_count = active_entities.size()
	
	# Spawn more agents if needed
	if idle_count < min_idle_agents and active_count < max_agents:
		var agent_types = ["aider", "opencode", "claude"]
		var agent_type = agent_types[randi() % agent_types.size()]
		var position = spawn_positions[active_count % spawn_positions.size()]
		
		var agent_id = spawn_game_agent(agent_type, position)
		if agent_id != "":
			_assign_agent_to_workspace(agent_id)
	
	# Despawn excess agents if too many idle
	elif idle_count > min_idle_agents + 2:
		var idle_agents = get_idle_game_agents()
		if not idle_agents.is_empty():
			despawn_game_agent(idle_agents[0].agent_id)


# ═══════════════════════════════════════════════════════════════════════════
# Private Methods - Workspace Creation
# ═══════════════════════════════════════════════════════════════════════════

func _create_default_workspace() -> Node3D:
	"""Create a default workspace programmatically"""
	var workspace = Node3D.new()
	
	# Create floor
	var floor_mesh = BoxMesh.new()
	floor_mesh.size = Vector3(4, 0.1, 4)
	var floor = MeshInstance3D.new()
	floor.mesh = floor_mesh
	floor.position.y = -0.05
	workspace.add_child(floor)
	
	# Create desk
	var desk_mesh = BoxMesh.new()
	desk_mesh.size = Vector3(1.5, 1.2, 0.8)
	var desk = MeshInstance3D.new()
	desk.mesh = desk_mesh
	desk.position.y = 0.6
	workspace.add_child(desk)
	
	# Create agent position marker
	var marker = Marker3D.new()
	marker.name = "AgentPosition"
	marker.position.y = 0.6
	marker.position.z = 1.2
	workspace.add_child(marker)
	
	return workspace


# ═══════════════════════════════════════════════════════════════════════════
# Signal Handlers
# ═══════════════════════════════════════════════════════════════════════════

func _on_base_task_started(task_id: String, prompt: String) -> void:
	"""Handle base manager task started"""
	# Find which agent is executing this task
	for agent_id in agent_assignments.keys():
		if agent_assignments[agent_id] == task_id:
			var agent = get_game_agent(agent_id)
			if agent:
				agent.set_state(AgentEntity.AgentState.CODING)
			break


func _on_base_task_completed(task_id: String, output: String) -> void:
	"""Handle base manager task completed"""
	# Find which agent completed this task
	for agent_id in agent_assignments.keys():
		if agent_assignments[agent_id] == task_id:
			var agent = get_game_agent(agent_id)
			if agent:
				agent.set_state(AgentEntity.AgentState.IDLE)
				
				# Emit game-specific signal
				game_task_completed.emit(agent_id, {
					"task_id": task_id,
					"output": output,
					"agent_id": agent_id
				})
			
			agent_assignments[agent_id] = ""
			break


func _on_base_task_failed(task_id: String, error: String) -> void:
	"""Handle base manager task failed"""
	for agent_id in agent_assignments.keys():
		if agent_assignments[agent_id] == task_id:
			var agent = get_game_agent(agent_id)
			if agent:
				agent.set_state(AgentEntity.AgentState.ERROR)
			
			agent_assignments[agent_id] = ""
			break


func _on_base_connection_changed(connected: bool) -> void:
	"""Handle base manager connection change"""
	if not connected:
		print("[AgentVMManagerExtended] Lost connection to AgentVM API")
	else:
		print("[AgentVMManagerExtended] Connected to AgentVM API")


func _on_registry_agent_spawned(agent_id: String, agent: AgentEntity) -> void:
	"""Handle registry agent spawned"""
	# Extended manager already handles this, but we can add additional logic here


func _on_registry_agent_despawned(agent_id: String) -> void:
	"""Handle registry agent despawned"""
	# Extended manager already handles this


func _on_registry_task_assigned(agent_id: String, task: String) -> void:
	"""Handle registry task assignment"""
	# Process through the extended task queue
	assign_game_task(agent_id, task)


func _on_registry_state_changed(agent_id: String, new_state: AgentEntity.AgentState) -> void:
	"""Handle registry state change"""
	# Can add game-specific state handling here
	pass


# ═══════════════════════════════════════════════════════════════════════════
# Utility Methods
# ═══════════════════════════════════════════════════════════════════════════

func get_agent_status(agent_id: String) -> Dictionary:
	"""Get comprehensive agent status"""
	var agent = get_game_agent(agent_id)
	if not agent:
		return {}
	
	var workspace_id = agent_assignments.get(agent_id, "")
	
	return {
		"id": agent_id,
		"type": agent.agent_type,
		"state": agent.state,
		"position": agent.global_position,
		"workspace": workspace_id,
		"personality": agent.personality,
		"current_task": agent.current_task
	}


func get_all_agent_status() -> Array[Dictionary]:
	"""Get status of all agents"""
	var status_list: Array[Dictionary] = []
	for agent_id in active_entities.keys():
		status_list.append(get_agent_status(agent_id))
	return status_list


func get_workspace_status(workspace_id: String) -> Dictionary:
	"""Get workspace status"""
	var workspace = workspaces.get(workspace_id)
	if not workspace:
		return {}
	
	var assigned_agents = []
	for agent_id in agent_assignments.keys():
		if agent_assignments[agent_id] == workspace_id:
			assigned_agents.append(agent_id)
	
	return {
		"id": workspace_id,
		"position": workspace.global_position,
		"assigned_agents": assigned_agents,
		"agent_count": assigned_agents.size()
	}