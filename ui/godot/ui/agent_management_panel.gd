# ═══════════════════════════════════════════════════════════════════════════
# agent_management_panel.gd - UI for Managing Agent Workforce
# ═══════════════════════════════════════════════════════════════════════════
# Place this file in: addons/agentvm/ui/agent_management_panel.gd

@tool
extends Control

## Main interface for managing AI agents in the game world
## Provides spawning, task assignment, and monitoring capabilities

# ═══════════════════════════════════════════════════════════════════════════
# UI References
# ═══════════════════════════════════════════════════════════════════════════

@onready var agent_list: ItemList = %AgentList
@onready var spawn_button: Button = %SpawnButton
@onready var despawn_button: Button = %DespawnButton
@onready var task_button: Button = %TaskButton
@onready var collaborate_button: Button = %CollaborateButton
@onready var status_label: Label = %StatusLabel
@onready var agent_info: RichTextLabel = %AgentInfo
@onready var task_input: LineEdit = %TaskInput
@onready var agent_type_selector: OptionButton = %AgentTypeSelector

# Management system references
var extended_manager: AgentVMManagerExtended
var agent_registry: AgentRegistry

# State
var selected_agent_id: String = ""
var update_timer: Timer

# ═══════════════════════════════════════════════════════════════════════════
# Initialization
# ═══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	"""Initialize the management panel"""
	if not Engine.is_editor_hint():
		return
	
	# Set up UI
	_setup_ui()
	
	# Find management systems
	_find_management_systems()
	
	# Start update timer
	_start_update_timer()
	
	print("[AgentManagementPanel] Management panel initialized")


func _setup_ui() -> void:
	"""Set up UI components"""
	# Set up agent type selector
	agent_type_selector.clear()
	agent_type_selector.add_item("Aider", 0)
	agent_type_selector.add_item("OpenCode", 1)
	agent_type_selector.add_item("Claude", 2)
	
	# Connect signals
	spawn_button.pressed.connect(_on_spawn_pressed)
	despawn_button.pressed.connect(_on_despawn_pressed)
	task_button.pressed.connect(_on_task_pressed)
	collaborate_button.pressed.connect(_on_collaborate_pressed)
	agent_list.item_selected.connect(_on_agent_selected)
	
	# Set initial button states
	_update_button_states()


func _find_management_systems() -> void:
	"""Find the management systems"""
	# Try to find extended manager
	var root = get_tree().current_scene
	extended_manager = _find_node_recursive(root, "AgentVMManagerExtended")
	agent_registry = _find_node_recursive(root, "AgentRegistry")
	
	if extended_manager:
		print("[AgentManagementPanel] Found extended manager")
		status_label.text = "Connected to Agent System"
		status_label.modulate = Color.GREEN
	else:
		status_label.text = "Not connected to Agent System"
		status_label.modulate = Color.RED


func _find_node_recursive(node: Node, name: String) -> Node:
	"""Find node recursively"""
	if node.name == name:
		return node
	
	for child in node.get_children():
		var result = _find_node_recursive(child, name)
		if result:
			return result
	
	return null


func _start_update_timer() -> void:
	"""Start the update timer"""
	update_timer = Timer.new()
	update_timer.wait_time = 1.0
	update_timer.timeout.connect(_update_agent_list)
	add_child(update_timer)
	update_timer.start()


# ═══════════════════════════════════════════════════════════════════════════
# UI Updates
# ═══════════════════════════════════════════════════════════════════════════

func _update_agent_list() -> void:
	"""Update the agent list display"""
	if not extended_manager:
		return
	
	var agents = extended_manager.get_all_agent_status()
	
	# Clear and rebuild list
	agent_list.clear()
	
	for agent_data in agents:
		var agent_id = agent_data.id
		var agent_type = agent_data.type
		var agent_state = agent_data.state
		
		# Create display text
		var state_icon = _get_state_icon(agent_state)
		var display_text = "%s [%s] %s" % [state_icon, agent_type.to_upper(), agent_id]
		
		agent_list.add_item(display_text)
		agent_list.set_item_metadata(agent_list.get_item_count() - 1, agent_id)
		
		# Color code by state
		var color = _get_state_color(agent_state)
		agent_list.set_item_custom_fg_color(agent_list.get_item_count() - 1, color)
	
	# Update status
	status_label.text = "Active Agents: %d" % agents.size()


func _update_button_states() -> void:
	"""Update button states based on selection"""
	var has_selection = selected_agent_id != ""
	
	despawn_button.disabled = not has_selection
	task_button.disabled = not has_selection
	collaborate_button.disabled = not has_selection


func _update_agent_info() -> void:
	"""Update agent information display"""
	if not extended_manager or selected_agent_id == "":
		agent_info.text = "Select an agent to view details"
		return
	
	var agent_data = extended_manager.get_agent_status(selected_agent_id)
	
	var info_text = """[b]Agent Details[/b]

[b]ID:[/b] %s
[b]Type:[/b] %s
[b]State:[/b] %s
[b]Position:[/b] (%.1f, %.1f, %.1f)
[b]Workspace:[/b] %s

[b]Personality:[/b]
• Friendliness: %.1f
• Efficiency: %.1f
• Creativity: %.1f
• Talkativeness: %.1f
• Collaboration: %.1f

[b]Current Task:[/b] %s
""" % [
	agent_data.id,
	agent_data.type.to_upper(),
	_agent_state_to_string(agent_data.state),
	agent_data.position.x, agent_data.position.y, agent_data.position.z,
	agent_data.workspace,
	agent_data.personality.friendliness,
	agent_data.personality.efficiency,
	agent_data.personality.creativity,
	agent_data.personality.talkativeness,
	agent_data.personality.collaboration,
	agent_data.current_task if agent_data.current_task else "None"
]

	agent_info.text = info_text


func _get_state_icon(state: AgentEntity.AgentState) -> String:
	"""Get icon for agent state"""
	match state:
		AgentEntity.AgentState.IDLE: return "⚪"
		AgentEntity.AgentState.THINKING: return "🤔"
		AgentEntity.AgentState.CODING: return "💻"
		AgentEntity.AgentState.SPEAKING: return "💬"
		AgentEntity.AgentState.MOVING: return "🚶"
		AgentEntity.AgentState.COLLABORATING: return "🤝"
		AgentEntity.AgentState.ERROR: return "❌"
		_: return "❓"


func _get_state_color(state: AgentEntity.AgentState) -> Color:
	"""Get color for agent state"""
	match state:
		AgentEntity.AgentState.IDLE: return Color.GRAY
		AgentEntity.AgentState.THINKING: return Color.YELLOW
		AgentEntity.AgentState.CODING: return Color.CYAN
		AgentEntity.AgentState.SPEAKING: return Color.GREEN
		AgentEntity.AgentState.MOVING: return Color.BLUE
		AgentEntity.AgentState.COLLABORATING: return Color.MAGENTA
		AgentEntity.AgentState.ERROR: return Color.RED
		_: return Color.WHITE


func _agent_state_to_string(state: AgentEntity.AgentState) -> String:
	"""Convert agent state to string"""
	match state:
		AgentEntity.AgentState.IDLE: return "Idle"
		AgentEntity.AgentState.THINKING: return "Thinking"
		AgentEntity.AgentState.CODING: return "Coding"
		AgentEntity.AgentState.SPEAKING: return "Speaking"
		AgentEntity.AgentState.MOVING: return "Moving"
		AgentEntity.AgentState.COLLABORATING: return "Collaborating"
		AgentEntity.AgentState.ERROR: return "Error"
		_: return "Unknown"


# ═══════════════════════════════════════════════════════════════════════════
# Signal Handlers
# ═══════════════════════════════════════════════════════════════════════════

func _on_spawn_pressed() -> void:
	"""Handle spawn button press"""
	if not extended_manager:
		return
	
	var agent_types = ["aider", "opencode", "claude"]
	var selected_type = agent_types[agent_type_selector.selected]
	
	# Spawn agent
	var agent_id = extended_manager.spawn_game_agent(selected_type)
	
	if agent_id != "":
		print("[AgentManagementPanel] Spawned agent: %s" % agent_id)
		
		# Assign initial task if provided
		var task = task_input.text.strip_edges()
		if task != "":
			extended_manager.assign_game_task(agent_id, task)
			task_input.text = ""
	else:
		print("[AgentManagementPanel] Failed to spawn agent")


func _on_despawn_pressed() -> void:
	"""Handle despawn button press"""
	if not extended_manager or selected_agent_id == "":
		return
	
	var success = extended_manager.despawn_game_agent(selected_agent_id)
	
	if success:
		print("[AgentManagementPanel] Despawned agent: %s" % selected_agent_id)
		selected_agent_id = ""
		_update_button_states()
		_update_agent_info()
	else:
		print("[AgentManagementPanel] Failed to despawn agent")


func _on_task_pressed() -> void:
	"""Handle task assignment button press"""
	if not extended_manager or selected_agent_id == "":
		return
	
	var task = task_input.text.strip_edges()
	if task == "":
		return
	
	var success = extended_manager.assign_game_task(selected_agent_id, task)
	
	if success:
		print("[AgentManagementPanel] Assigned task to %s: %s" % [selected_agent_id, task])
		task_input.text = ""
	else:
		print("[AgentManagementPanel] Failed to assign task")


func _on_collaborate_pressed() -> void:
	"""Handle collaboration button press"""
	if not extended_manager or selected_agent_id == "":
		return
	
	# Find another idle agent
	var idle_agents = extended_manager.get_idle_game_agents()
	
	# Remove current agent from idle list
	idle_agents = idle_agents.filter(func(agent): return agent.agent_id != selected_agent_id)
	
	if idle_agents.is_empty():
		print("[AgentManagementPanel] No other idle agents available for collaboration")
		return
	
	var other_agent = idle_agents[0]
	var task = "Collaborative coding task"
	
	if task_input.text.strip_edges() != "":
		task = task_input.text.strip_edges()
	
	# Assign collaborative task
	var team = extended_manager.assign_collaborative_task(task, 2)
	
	if team.size() >= 2:
		print("[AgentManagementPanel] Started collaboration between agents: %s" % str(team))
		task_input.text = ""
	else:
		print("[AgentManagementPanel] Failed to start collaboration")


func _on_agent_selected(index: int) -> void:
	"""Handle agent selection in list"""
	if index < 0 or index >= agent_list.get_item_count():
		selected_agent_id = ""
	else:
		selected_agent_id = agent_list.get_item_metadata(index)
	
	_update_button_states()
	_update_agent_info()


# ═══════════════════════════════════════════════════════════════════════════
# Utility Methods
# ═══════════════════════════════════════════════════════════════════════════

func show_agent_overview() -> void:
	"""Show agent overview statistics"""
	if not extended_manager:
		return
	
	var all_agents = extended_manager.get_all_agent_status()
	
	var state_counts = {}
	var type_counts = {}
	
	for agent_data in all_agents:
		# Count by state
		var state = agent_data.state
		state_counts[state] = state_counts.get(state, 0) + 1
		
		# Count by type
		var type = agent_data.type
		type_counts[type] = type_counts.get(type, 0) + 1
	
	var overview_text = """[b]Agent Overview[/b]

Total Agents: %d

[b]By State:[/b]
""" % all_agents.size()

	for state in state_counts:
		overview_text += "• %s: %d\n" % [_agent_state_to_string(state), state_counts[state]]

	overview_text += "\n[b]By Type:[/b]\n"
	for type in type_counts:
		overview_text += "• %s: %d\n" % [type.to_upper(), type_counts[type]]

	agent_info.text = overview_text


func refresh_systems() -> void:
	"""Refresh connection to management systems"""
	_find_management_systems()
	_update_agent_list()