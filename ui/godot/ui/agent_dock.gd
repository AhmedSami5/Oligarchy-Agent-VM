# ═══════════════════════════════════════════════════════════════════════════
# agent_dock.gd - Main Dock Panel UI
# ═══════════════════════════════════════════════════════════════════════════
# Place this file in: addons/agentvm/ui/agent_dock.gd

@tool
extends Control

## Main AgentVM control panel in the editor

# References
var agent_manager: AgentVMManager

# UI nodes (set in _ready from scene)
@onready var status_label: Label = %StatusLabel
@onready var prompt_input: TextEdit = %PromptInput
@onready var agent_selector: OptionButton = %AgentSelector
@onready var run_button: Button = %RunButton
@onready var cancel_button: Button = %CancelButton
@onready var task_list: ItemList = %TaskList
@onready var connection_indicator: ColorRect = %ConnectionIndicator
@onready var quick_actions_container: VBoxContainer = %QuickActionsContainer

# State
var current_task_id: String = ""


func _ready() -> void:
	"""Initialize UI"""
	# Set up agent selector
	agent_selector.clear()
	agent_selector.add_item("aider", 0)
	agent_selector.add_item("opencode", 1)
	agent_selector.add_item("claude", 2)
	
	# Connect signals
	run_button.pressed.connect(_on_run_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	task_list.item_selected.connect(_on_task_selected)
	
	# Set up quick action buttons
	_setup_quick_actions()
	
	# Update UI state
	_update_ui()
	
	# Start update timer
	var timer = Timer.new()
	timer.wait_time = 0.5
	timer.timeout.connect(_update_ui)
	add_child(timer)
	timer.start()


func _setup_quick_actions() -> void:
	"""Create quick action buttons"""
	var actions = [
		{"label": "🔧 Fix Errors", "method": "quick_fix_errors"},
		{"label": "📝 Add Comments", "method": "quick_add_comments"},
		{"label": "♻️ Refactor", "method": "quick_refactor"},
		{"label": "🧪 Add Tests", "method": "quick_add_tests"},
		{"label": "⚡ Optimize", "method": "quick_optimize"}
	]
	
	for action in actions:
		var button = Button.new()
		button.text = action.label
		button.pressed.connect(func(): _run_quick_action(action.method))
		quick_actions_container.add_child(button)


func _update_ui() -> void:
	"""Update UI state"""
	if not agent_manager:
		return
	
	# Update connection indicator
	if connection_indicator:
		if agent_manager.is_connected:
			connection_indicator.color = Color.GREEN
			status_label.text = "Connected"
		else:
			connection_indicator.color = Color.RED
			status_label.text = "Disconnected"
	
	# Update button states
	var has_active_task = not current_task_id.is_empty()
	run_button.disabled = has_active_task or not agent_manager.is_connected
	cancel_button.disabled = not has_active_task
	
	# Update task list
	_refresh_task_list()


func _refresh_task_list() -> void:
	"""Refresh the task list display"""
	if not task_list or not agent_manager:
		return
	
	task_list.clear()
	
	# Add active tasks first
	for task_id in agent_manager.get_active_tasks():
		var task = agent_manager.get_task_status(task_id)
		var status_icon = _get_status_icon(task.status)
		var text = "%s [%s] %s" % [status_icon, task.agent, task.prompt.substr(0, 40)]
		task_list.add_item(text)
		task_list.set_item_metadata(task_list.item_count - 1, task_id)
	
	# Add recent history
	for entry in agent_manager.get_task_history(10):
		var status_icon = _get_status_icon(entry.status)
		var text = "%s [%s] %s" % [status_icon, entry.agent, entry.prompt.substr(0, 40)]
		task_list.add_item(text)
		task_list.set_item_metadata(task_list.item_count - 1, entry.id)


func _get_status_icon(status: String) -> String:
	"""Get emoji icon for status"""
	match status:
		"pending": return "⏳"
		"running": return "⚙️"
		"completed": return "✅"
		"failed": return "❌"
		_: return "⚪"


# ═══════════════════════════════════════════════════════════════════════════
# Signal Handlers
# ═══════════════════════════════════════════════════════════════════════════

func _on_run_pressed() -> void:
	"""Handle run button click"""
	if not agent_manager:
		return
	
	var prompt = prompt_input.text.strip_edges()
	if prompt.is_empty():
		push_warning("[AgentVM] Prompt cannot be empty")
		return
	
	var agent = ["aider", "opencode", "claude"][agent_selector.selected]
	
	current_task_id = agent_manager.run_agent(prompt, agent)
	
	if not current_task_id.is_empty():
		prompt_input.text = ""
		_update_ui()


func _on_cancel_pressed() -> void:
	"""Handle cancel button click"""
	if current_task_id.is_empty() or not agent_manager:
		return
	
	agent_manager.cancel_task(current_task_id)
	current_task_id = ""
	_update_ui()


func _on_task_selected(index: int) -> void:
	"""Handle task selection in list"""
	if not task_list:
		return
	
	var task_id = task_list.get_item_metadata(index)
	var task = agent_manager.get_task_status(task_id)
	
	if task.is_empty():
		return
	
	# Show task details in a popup
	_show_task_details(task)


func _run_quick_action(method_name: String) -> void:
	"""Run a quick action"""
	if not agent_manager:
		return
	
	var callable = Callable(agent_manager, method_name)
	if callable.is_valid():
		current_task_id = callable.call()
		_update_ui()


# ═══════════════════════════════════════════════════════════════════════════
# Helper Methods
# ═══════════════════════════════════════════════════════════════════════════

func _show_task_details(task: Dictionary) -> void:
	"""Show detailed task information in a dialog"""
	var dialog = AcceptDialog.new()
	dialog.title = "Task Details"
	dialog.dialog_text = """
Task ID: %s
Agent: %s
Status: %s
Prompt: %s

Output:
%s

%s
""" % [
		task.id,
		task.agent,
		task.status,
		task.prompt,
		task.output if task.output else "(no output yet)",
		"Error: %s" % task.error if task.error else ""
	]
	
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)
