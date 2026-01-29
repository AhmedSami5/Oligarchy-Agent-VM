# ═══════════════════════════════════════════════════════════════════════════
# bottom_panel.gd - Output Panel for Agent Results
# ═══════════════════════════════════════════════════════════════════════════
# Place this file in: addons/agentvm/ui/bottom_panel.gd

@tool
extends Control

## Bottom panel for displaying agent output and logs

var agent_manager: AgentVMManager

@onready var output_text: TextEdit = %OutputText
@onready var clear_button: Button = %ClearButton
@onready var auto_scroll_check: CheckBox = %AutoScrollCheck

var auto_scroll: bool = true


func _ready() -> void:
	"""Initialize panel"""
	if not agent_manager:
		return
	
	# Connect signals
	agent_manager.task_started.connect(_on_task_started)
	agent_manager.task_completed.connect(_on_task_completed)
	agent_manager.task_failed.connect(_on_task_failed)
	
	# Connect UI signals
	clear_button.pressed.connect(_on_clear_pressed)
	auto_scroll_check.toggled.connect(_on_auto_scroll_toggled)
	
	# Set up output text
	output_text.editable = false
	output_text.syntax_highlighter = null


func _append_text(text: String, color: Color = Color.WHITE) -> void:
	"""Append colored text to output"""
	var timestamp = Time.get_time_string_from_system()
	var line = "[%s] %s\n" % [timestamp, text]
	
	output_text.text += line
	
	if auto_scroll:
		# Scroll to bottom
		output_text.scroll_vertical = output_text.get_line_count()


# ═══════════════════════════════════════════════════════════════════════════
# Signal Handlers
# ═══════════════════════════════════════════════════════════════════════════

func _on_task_started(task_id: String, prompt: String) -> void:
	"""Handle task start"""
	_append_text("⚙️  STARTED: %s" % prompt.substr(0, 60), Color.YELLOW)


func _on_task_completed(task_id: String, output: String) -> void:
	"""Handle task completion"""
	_append_text("✅ COMPLETED: Task %s" % task_id, Color.GREEN)
	
	if not output.is_empty():
		_append_text("Output:", Color.WHITE)
		_append_text(output, Color.LIGHT_GRAY)
	
	_append_text("─" * 60, Color.DARK_GRAY)


func _on_task_failed(task_id: String, error: String) -> void:
	"""Handle task failure"""
	_append_text("❌ FAILED: Task %s" % task_id, Color.RED)
	_append_text("Error: %s" % error, Color.ORANGE_RED)
	_append_text("─" * 60, Color.DARK_GRAY)


func _on_clear_pressed() -> void:
	"""Clear output text"""
	output_text.text = ""


func _on_auto_scroll_toggled(enabled: bool) -> void:
	"""Toggle auto-scroll"""
	auto_scroll = enabled
