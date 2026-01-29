# ═══════════════════════════════════════════════════════════════════════════
# plugin.gd - Main Plugin Registration
# ═══════════════════════════════════════════════════════════════════════════
# Place this file in: addons/agentvm/plugin.gd

@tool
extends EditorPlugin

# Plugin components
var dock: Control
var settings_panel: Control
var agent_manager: Node
var bottom_panel: Control
var extended_manager: AgentVMManagerExtended
var management_panel: Control

# Constants
const DOCK_SCENE = preload("res://addons/agentvm/ui/agent_dock.tscn")
const BOTTOM_PANEL_SCENE = preload("res://addons/agentvm/ui/bottom_panel.tscn")
const MANAGEMENT_PANEL_SCENE = preload("res://addons/agentvm/ui/agent_management_panel.tscn")
const AGENT_MANAGER = preload("res://addons/agentvm/core/agent_manager.gd")
const AGENT_MANAGER_EXTENDED = preload("res://addons/agentvm/core/agent_manager_extended.gd")

func _enter_tree() -> void:
	"""Called when plugin is enabled"""
	print("[AgentVM] Initializing plugin...")
	
	# Create base agent manager
	agent_manager = AGENT_MANAGER.new()
	agent_manager.name = "AgentVMManager"
	add_child(agent_manager)
	
	# Create extended manager for game integration
	extended_manager = AGENT_MANAGER_EXTENDED.new()
	extended_manager.name = "AgentVMManagerExtended"
	add_child(extended_manager)
	
	# Load settings
	_load_settings()
	
	# Add main dock
	dock = DOCK_SCENE.instantiate()
	dock.agent_manager = agent_manager
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
	
	# Add bottom panel for output
	bottom_panel = BOTTOM_PANEL_SCENE.instantiate()
	bottom_panel.agent_manager = agent_manager
	add_control_to_bottom_panel(bottom_panel, "AgentVM Output")
	
	# Add management panel for runtime use
	management_panel = MANAGEMENT_PANEL_SCENE.instantiate()
	management_panel.visible = false
	get_editor_interface().get_base_control().add_child(management_panel)
	
	# Connect signals
	agent_manager.task_started.connect(_on_task_started)
	agent_manager.task_completed.connect(_on_task_completed)
	agent_manager.task_failed.connect(_on_task_failed)
	
	# Add custom menu items
	_add_menu_items()
	
	print("[AgentVM] Plugin loaded successfully!")


func _exit_tree() -> void:
	"""Called when plugin is disabled"""
	print("[AgentVM] Unloading plugin...")
	
	# Remove UI components
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
	
	if bottom_panel:
		remove_control_from_bottom_panel(bottom_panel)
		bottom_panel.queue_free()
	
	if management_panel:
		management_panel.queue_free()
	
	# Remove managers
	if extended_manager:
		extended_manager.queue_free()
	
	if agent_manager:
		agent_manager.queue_free()
	
	# Remove menu items
	_remove_menu_items()
	
	print("[AgentVM] Plugin unloaded")


func _load_settings() -> void:
	"""Load plugin settings from project settings"""
	var config = ConfigFile.new()
	var err = config.load("res://addons/agentvm/config.ini")
	
	if err == OK:
		agent_manager.api_url = config.get_value("api", "url", "http://localhost:8000")
		agent_manager.api_key = config.get_value("api", "key", "change-this-in-production-2026")
		agent_manager.default_agent = config.get_value("agent", "default", "aider")
	else:
		print("[AgentVM] No config found, using defaults")
		# Create default config
		config.set_value("api", "url", "http://localhost:8000")
		config.set_value("api", "key", "change-this-in-production-2026")
		config.set_value("agent", "default", "aider")
		config.save("res://addons/agentvm/config.ini")


func _add_menu_items() -> void:
	"""Add custom menu items to editor"""
	var menu = get_editor_interface().get_base_control().get_menu_bar()
	# Add custom menu for agent management
	var agent_menu = menu.get_item_index(0)  # File menu index
	
	# Add separator and agent management items
	menu.add_separator("AgentVM", agent_menu)
	menu.add_item("Show Agent Management", agent_menu)
	
	# Connect menu signals
	menu.id_pressed.connect(_on_menu_item_pressed)


func _remove_menu_items() -> void:
	"""Remove custom menu items"""
	var menu = get_editor_interface().get_base_control().get_menu_bar()
	# Remove AgentVM menu items (implementation depends on Godot version)


# Signal handlers
func _on_task_started(task_id: String, prompt: String) -> void:
	print("[AgentVM] Task started: %s" % task_id)
	make_bottom_panel_item_visible(bottom_panel)


func _on_task_completed(task_id: String, output: String) -> void:
	print("[AgentVM] Task completed: %s" % task_id)


func _on_task_failed(task_id: String, error: String) -> void:
	push_error("[AgentVM] Task failed: %s - %s" % [task_id, error])


func _on_menu_item_pressed(id: int) -> void:
	"""Handle menu item presses"""
	var menu = get_editor_interface().get_base_control().get_menu_bar()
	var item_text = menu.get_item_text(id)
	
	match item_text:
		"Show Agent Management":
			if management_panel:
				management_panel.visible = not management_panel.visible
				management_panel.refresh_systems()
