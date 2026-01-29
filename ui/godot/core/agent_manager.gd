# ═══════════════════════════════════════════════════════════════════════════
# agent_manager.gd - Core Agent Communication Manager
# ═══════════════════════════════════════════════════════════════════════════
# Place this file in: addons/agentvm/core/agent_manager.gd

extends Node
class_name AgentVMManager

## Manages communication with AgentVM API and task execution

# Signals
signal task_started(task_id: String, prompt: String)
signal task_completed(task_id: String, output: String)
signal task_failed(task_id: String, error: String)
signal task_progress(task_id: String, progress: float)
signal connection_status_changed(connected: bool)

# Configuration
var api_url: String = "http://localhost:8000"
var api_key: String = "change-this-in-production-2026"
var default_agent: String = "aider"
var default_timeout: int = 600

# State
var active_tasks: Dictionary = {}  # task_id -> TaskInfo
var task_history: Array[Dictionary] = []
var is_connected: bool = false

# HTTP request pool
var http_request_pool: Array[HTTPRequest] = []
const MAX_CONCURRENT_REQUESTS = 4


# ═══════════════════════════════════════════════════════════════════════════
# Task Management
# ═══════════════════════════════════════════════════════════════════════════

class TaskInfo:
	var id: String
	var agent: String
	var prompt: String
	var status: String  # "pending", "running", "completed", "failed"
	var started_at: float
	var completed_at: float
	var output: String
	var error: String
	var http_request: HTTPRequest
	
	func _init(p_id: String, p_agent: String, p_prompt: String):
		id = p_id
		agent = p_agent
		prompt = p_prompt
		status = "pending"
		started_at = Time.get_unix_time_from_system()


func _ready() -> void:
	"""Initialize the manager"""
	# Create HTTP request pool
	for i in range(MAX_CONCURRENT_REQUESTS):
		var req = HTTPRequest.new()
		add_child(req)
		http_request_pool.append(req)
	
	# Start connection check timer
	var timer = Timer.new()
	timer.wait_time = 5.0
	timer.timeout.connect(_check_connection)
	add_child(timer)
	timer.start()
	
	# Initial connection check
	_check_connection()


# ═══════════════════════════════════════════════════════════════════════════
# Public API
# ═══════════════════════════════════════════════════════════════════════════

func run_agent(prompt: String, agent: String = "", repo_path: String = "") -> String:
	"""
	Run an AI coding agent with the specified prompt.
	
	Args:
		prompt: The coding task or instruction
		agent: Agent to use (aider, opencode, claude). Uses default if empty.
		repo_path: Path to repository. Uses project root if empty.
	
	Returns:
		Task ID for tracking progress
	"""
	if not is_connected:
		push_error("[AgentVM] Not connected to API")
		return ""
	
	# Generate task ID
	var task_id = "task_%d" % Time.get_unix_time_from_system()
	
	# Use defaults if not specified
	if agent.is_empty():
		agent = default_agent
	
	if repo_path.is_empty():
		repo_path = ProjectSettings.globalize_path("res://")
	
	# Create task info
	var task = TaskInfo.new(task_id, agent, prompt)
	active_tasks[task_id] = task
	
	# Get available HTTP request
	var http = _get_available_request()
	if not http:
		push_error("[AgentVM] No available HTTP request slots")
		task.status = "failed"
		task.error = "No available request slots"
		task_failed.emit(task_id, task.error)
		return ""
	
	task.http_request = http
	
	# Prepare request
	var headers = [
		"X-API-Key: %s" % api_key,
		"Content-Type: application/json"
	]
	
	var body = JSON.stringify({
		"agent": agent,
		"prompt": prompt,
		"repo_path": repo_path,
		"timeout": default_timeout
	})
	
	# Connect signals
	http.request_completed.connect(_on_request_completed.bind(task_id))
	
	# Send request
	var err = http.request("%s/agent/run" % api_url, headers, HTTPClient.METHOD_POST, body)
	
	if err != OK:
		push_error("[AgentVM] Failed to send request: %d" % err)
		task.status = "failed"
		task.error = "Request failed: %d" % err
		task_failed.emit(task_id, task.error)
		return ""
	
	task.status = "running"
	task_started.emit(task_id, prompt)
	
	return task_id


func cancel_task(task_id: String) -> void:
	"""Cancel a running task"""
	if not active_tasks.has(task_id):
		return
	
	var task: TaskInfo = active_tasks[task_id]
	if task.http_request:
		task.http_request.cancel_request()
	
	task.status = "failed"
	task.error = "Cancelled by user"
	task_failed.emit(task_id, task.error)
	
	_cleanup_task(task_id)


func get_task_status(task_id: String) -> Dictionary:
	"""Get status of a task"""
	if not active_tasks.has(task_id):
		# Check history
		for entry in task_history:
			if entry.id == task_id:
				return entry
		return {}
	
	var task: TaskInfo = active_tasks[task_id]
	return {
		"id": task.id,
		"agent": task.agent,
		"prompt": task.prompt,
		"status": task.status,
		"started_at": task.started_at,
		"completed_at": task.completed_at,
		"output": task.output,
		"error": task.error
	}


func get_active_tasks() -> Array[String]:
	"""Get list of active task IDs"""
	return active_tasks.keys() as Array[String]


func get_task_history(limit: int = 10) -> Array[Dictionary]:
	"""Get recent task history"""
	var count = min(limit, task_history.size())
	return task_history.slice(0, count)


func clear_history() -> void:
	"""Clear task history"""
	task_history.clear()


# ═══════════════════════════════════════════════════════════════════════════
# Quick Actions
# ═══════════════════════════════════════════════════════════════════════════

func quick_fix_errors() -> String:
	"""Quick action: Fix errors in current scene/script"""
	return run_agent("Fix any errors or warnings in the current code")


func quick_add_comments() -> String:
	"""Quick action: Add documentation comments"""
	return run_agent("Add comprehensive comments and documentation to the code")


func quick_refactor() -> String:
	"""Quick action: Refactor for better code quality"""
	return run_agent("Refactor the code to improve readability and maintainability")


func quick_add_tests() -> String:
	"""Quick action: Generate unit tests"""
	return run_agent("Generate comprehensive unit tests for the current code")


func quick_optimize() -> String:
	"""Quick action: Optimize performance"""
	return run_agent("Optimize the code for better performance")


# ═══════════════════════════════════════════════════════════════════════════
# Internal Methods
# ═══════════════════════════════════════════════════════════════════════════

func _get_available_request() -> HTTPRequest:
	"""Get an available HTTP request from the pool"""
	for req in http_request_pool:
		if req.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
			return req
	return null


func _check_connection() -> void:
	"""Check if API is reachable"""
	var http = _get_available_request()
	if not http:
		return
	
	var headers = ["X-API-Key: %s" % api_key]
	
	http.request_completed.connect(_on_health_check_completed, CONNECT_ONE_SHOT)
	http.request("%s/health" % api_url, headers, HTTPClient.METHOD_GET)


func _on_health_check_completed(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	"""Handle health check response"""
	var was_connected = is_connected
	is_connected = (result == HTTPRequest.RESULT_SUCCESS and response_code == 200)
	
	if is_connected != was_connected:
		connection_status_changed.emit(is_connected)
		if is_connected:
			print("[AgentVM] Connected to API at %s" % api_url)
		else:
			push_warning("[AgentVM] Lost connection to API")


func _on_request_completed(
	result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray,
	task_id: String
) -> void:
	"""Handle agent task completion"""
	if not active_tasks.has(task_id):
		return
	
	var task: TaskInfo = active_tasks[task_id]
	task.completed_at = Time.get_unix_time_from_system()
	
	# Disconnect signal
	if task.http_request:
		task.http_request.request_completed.disconnect(_on_request_completed)
	
	# Check for request errors
	if result != HTTPRequest.RESULT_SUCCESS:
		task.status = "failed"
		task.error = "Request error: %d" % result
		task_failed.emit(task_id, task.error)
		_cleanup_task(task_id)
		return
	
	if response_code != 200:
		task.status = "failed"
		task.error = "HTTP error: %d" % response_code
		task_failed.emit(task_id, task.error)
		_cleanup_task(task_id)
		return
	
	# Parse response
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	
	if parse_result != OK:
		task.status = "failed"
		task.error = "Failed to parse response"
		task_failed.emit(task_id, task.error)
		_cleanup_task(task_id)
		return
	
	var data = json.data
	
	# Check if agent succeeded
	if data.get("success", false):
		task.status = "completed"
		task.output = data.get("stdout", "")
		task_completed.emit(task_id, task.output)
	else:
		task.status = "failed"
		task.error = data.get("error", data.get("stderr", "Unknown error"))
		task_failed.emit(task_id, task.error)
	
	_cleanup_task(task_id)


func _cleanup_task(task_id: String) -> void:
	"""Move task to history and clean up"""
	if not active_tasks.has(task_id):
		return
	
	var task: TaskInfo = active_tasks[task_id]
	
	# Add to history
	task_history.push_front({
		"id": task.id,
		"agent": task.agent,
		"prompt": task.prompt,
		"status": task.status,
		"started_at": task.started_at,
		"completed_at": task.completed_at,
		"output": task.output,
		"error": task.error
	})
	
	# Keep history size limited
	if task_history.size() > 100:
		task_history.resize(100)
	
	# Remove from active tasks
	active_tasks.erase(task_id)
