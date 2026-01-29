# ═══════════════════════════════════════════════════════════════════════════
# agent_entity.gd - Core 3D Agent Entity Class
# ═══════════════════════════════════════════════════════════════════════════
# Place this file in: addons/agentvm/entities/agent_entity.gd

extends CharacterBody3D
class_name AgentEntity

## Represents an AI coding agent as a 3D entity in the game world
## Combines visual representation with AgentVM functionality

# ═══════════════════════════════════════════════════════════════════════════
# Core Agent Properties
# ═══════════════════════════════════════════════════════════════════════════

## Unique identifier for this agent instance
var agent_id: String:
    set(value):
        if value.is_empty():
            push_error("Agent ID cannot be empty")
        else:
            agent_id = value

## Agent type (aider, opencode, claude)
enum AgentType { AIDER, OPENCODE, CLAUDE }
var agent_type: AgentType:
    set(value):
        if value in [AgentType.AIDER, AgentType.OPENCODE, AgentType.CLAUDE]:
            agent_type = value
        else:
            push_error("Invalid agent type")
            agent_type = AgentType.AIDER

## Reference to the AgentVM manager
var agent_manager: AgentVMManager

## Current task being worked on
var current_task: String = ""

## Agent personality and behavioral traits
var personality: Dictionary = {
	"friendliness": 0.8,
	"efficiency": 0.9,
	"creativity": 0.7,
	"talkativeness": 0.6,
	"collaboration": 0.8
}

# ═══════════════════════════════════════════════════════════════════════════
# Agent State Management
# ═══════════════════════════════════════════════════════════════════════════

enum AgentState {
	IDLE,
	THINKING,
	CODING,
	SPEAKING,
	MOVING,
	COLLABORATING,
	ERROR
}

## Current state of the agent
var state: AgentState = AgentState.IDLE

## Previous state for smooth transitions
var previous_state: AgentState = AgentState.IDLE

## State transition timer
var state_timer: float = 0.0

# ═══════════════════════════════════════════════════════════════════════════
# Visual Components
# ═══════════════════════════════════════════════════════════════════════════

## Main mesh for the agent body
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

## Animation player for agent actions
@onready var animation_player: AnimationPlayer = $AnimationPlayer

## Status indicator floating above agent
@onready var status_indicator: Sprite3D = $StatusIndicator

## Agent label showing name and status
@onready var agent_label: Label3D = $AgentLabel

## Interaction area for player clicks
@onready var interaction_area: Area3D = $InteractionArea

## Dialogue bubble for speaking
@onready var dialogue_bubble: Control = $DialogueBubble/SubViewportContainer/SubViewport/DialogueBubble

## Particle system for coding effects
@onready var coding_particles: GPUParticles3D = $CodingParticles

## Sound effects
@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer3D

# ═══════════════════════════════════════════════════════════════════════════
# Agent Configuration
# ═══════════════════════════════════════════════════════════════════════════

## Movement speed when navigating
var move_speed: float = 3.0

## Rotation speed for smooth turning
var rotation_speed: float = 5.0

## Target position for movement
var target_position: Vector3

## Is agent currently moving
var is_moving: bool = false

## Workspace position agent should return to
var workspace_position: Vector3

## Agent color scheme based on type
var agent_colors: Dictionary = {
	"aider": Color.BLUE,
	"opencode": Color.GREEN,
	"claude": Color.ORANGE
}

# ═══════════════════════════════════════════════════════════════════════════
# Signals
# ═══════════════════════════════════════════════════════════════════════════

signal task_started(agent_id: String, task: String)
signal task_completed(agent_id: String, result: String)
signal task_failed(agent_id: String, error: String)
signal state_changed(agent_id: String, new_state: AgentState)
signal interaction_requested(agent_id: String)
signal dialogue_spoken(agent_id: String, text: String)


# ═══════════════════════════════════════════════════════════════════════════
# Initialization
# ═══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	"""Initialize the agent entity"""
	# Set up interaction area
	if interaction_area:
		interaction_area.input_event.connect(_on_interaction_input)
	
	# Initialize visual appearance
	_setup_visual_appearance()
	
	# Set up status indicator
	_setup_status_indicator()
	
	# Start idle animations
	_play_idle_animation()
	
	# Start state update timer
	var state_timer = Timer.new()
	state_timer.wait_time = 0.1
	state_timer.timeout.connect(_update_state)
	add_child(state_timer)
	state_timer.start()


func initialize(p_agent_id: String, p_agent_type: String, p_manager: AgentVMManager, p_position: Vector3 = Vector3.ZERO) -> void:
	"""Initialize agent with given parameters"""
	agent_id = p_agent_id
	agent_type = p_agent_type
	agent_manager = p_manager
	global_position = p_position
	workspace_position = p_position
	
	# Set agent name
	if agent_label:
		agent_label.text = "%s_%s" % [agent_type.to_upper(), agent_id.split("_")[1]]
	
	# Apply agent-specific configuration
	_apply_agent_type_config()
	
	# Connect to agent manager signals
	if agent_manager:
		agent_manager.task_started.connect(_on_manager_task_started.bind(agent_id))
		agent_manager.task_completed.connect(_on_manager_task_completed.bind(agent_id))
		agent_manager.task_failed.connect(_on_manager_task_failed.bind(agent_id))
	
	print("[AgentEntity] Initialized %s agent at position %s" % [agent_type, p_position])


# ═══════════════════════════════════════════════════════════════════════════
# Public API
# ═══════════════════════════════════════════════════════════════════════════

func assign_task(prompt: String) -> void:
	"""Assign a coding task to this agent"""
	if not agent_manager:
		push_error("[AgentEntity] No agent manager available")
		return
	
	current_task = prompt
	set_state(AgentState.THINKING)
	
	# Generate a unique task ID for this agent
	var task_id = agent_manager.run_agent(prompt, agent_type)
	
	if not task_id.is_empty():
		print("[AgentEntity] %s started task: %s" % [agent_id, prompt])
		speak("Working on: " + prompt.substr(0, 50) + "...")
		task_started.emit(agent_id, prompt)
	else:
		set_state(AgentState.ERROR)
		speak("I couldn't start that task...")
		task_failed.emit(agent_id, "Failed to start task")


func move_to_position(position: Vector3) -> void:
	"""Move agent to specific position"""
	target_position = position
	is_moving = true
	set_state(AgentState.MOVING)


func return_to_workspace() -> void:
	"""Return agent to their workspace"""
	move_to_position(workspace_position)


func speak(text: String, duration: float = 3.0) -> void:
	"""Make agent speak with dialogue bubble"""
	set_state(AgentState.SPEAKING)
	
	if dialogue_bubble:
		dialogue_bubble.show_dialogue(text)
	
	# Show dialogue for specified duration
	var dialogue_timer = Timer.new()
	dialogue_timer.wait_time = duration
	dialogue_timer.timeout.connect(func(): 
		set_state(AgentState.IDLE)
		dialogue_bubble.hide_dialogue()
	)
	add_child(dialogue_timer)
	dialogue_timer.start()
	
	dialogue_spoken.emit(agent_id, text)


func collaborate_with(other_agent: AgentEntity) -> void:
	"""Collaborate with another agent"""
	set_state(AgentState.COLLABORATING)
	other_agent.set_state(AgentState.COLLABORATING)
	
	# Move towards each other
	var midpoint = (global_position + other_agent.global_position) / 2
	move_to_position(midpoint)
	other_agent.move_to_position(midpoint)
	
	speak("Let's work together on this!")


func set_state(new_state: AgentState) -> void:
	"""Change agent state with appropriate transitions"""
	if new_state == state:
		return
	
	previous_state = state
	state = new_state
	state_changed.emit(agent_id, new_state)
	
	# Update visual indicators
	_update_visual_state()
	
	# Play appropriate animation
	_play_state_animation()


func get_status() -> Dictionary:
	"""Get current agent status"""
	return {
		"id": agent_id,
		"type": agent_type,
		"state": state,
		"task": current_task,
		"position": global_position,
		"personality": personality
	}


# ═══════════════════════════════════════════════════════════════════════════
# Private Methods
# ═══════════════════════════════════════════════════════════════════════════

func _setup_visual_appearance() -> void:
	"""Set up the visual appearance based on agent type"""
	if not mesh_instance:
		return
	
	# Create a simple capsule mesh for the agent
	var capsule_mesh = CapsuleMesh.new()
	capsule_mesh.height = 1.8
	capsule_mesh.radius = 0.4
	mesh_instance.mesh = capsule_mesh
	
	# Apply agent-specific color
	var material = StandardMaterial3D.new()
	material.albedo_color = agent_colors.get(agent_type, Color.WHITE)
	mesh_instance.material_override = material


func _setup_status_indicator() -> void:
	"""Set up the floating status indicator"""
	if not status_indicator:
		return
	
	# Position above agent head
	status_indicator.position.y = 2.2
	
	# Set initial status
	_update_status_color()


func _apply_agent_type_config() -> void:
	"""Apply configuration specific to agent type"""
	match agent_type:
		"aider":
			personality.efficiency = 0.95
			personality.creativity = 0.6
			personality.talkativeness = 0.4
		"opencode":
			personality.efficiency = 0.8
			personality.creativity = 0.9
			personality.talkativeness = 0.8
		"claude":
			personality.efficiency = 0.85
			personality.creativity = 0.8
			personality.talkativeness = 0.9


func _update_visual_state() -> void:
	"""Update visual indicators based on current state"""
	_update_status_color()
	_update_particles()
	_update_label()


func _update_status_color() -> void:
	"""Update status indicator color based on state"""
	if not status_indicator:
		return
	
	var status_color: Color
	match state:
		AgentState.IDLE: status_color = Color.GRAY
		AgentState.THINKING: status_color = Color.YELLOW
		AgentState.CODING: status_color = Color.CYAN
		AgentState.SPEAKING: status_color = Color.GREEN
		AgentState.MOVING: status_color = Color.BLUE
		AgentState.COLLABORATING: status_color = Color.MAGENTA
		AgentState.ERROR: status_color = Color.RED
		_: status_color = Color.WHITE
	
	status_indicator.modulate = status_color


func _update_particles() -> void:
	"""Update particle effects based on state"""
	if not coding_particles:
		return
	
	match state:
		AgentState.CODING:
			coding_particles.emitting = true
		AgentState.THINKING:
			coding_particles.emitting = true
			coding_particles.emission RingEmitter.AMOUNT_RATIO = 0.5
		_:
			coding_particles.emitting = false


func _update_label() -> void:
	"""Update agent label with current status"""
	if not agent_label:
		return
	
	var status_text = ""
	match state:
		AgentState.IDLE: status_text = "Idle"
		AgentState.THINKING: status_text = "Thinking..."
		AgentState.CODING: status_text = "Coding..."
		AgentState.SPEAKING: status_text = "Speaking"
		AgentState.MOVING: status_text = "Moving"
		AgentState.COLLABORATING: status_text = "Collaborating"
		AgentState.ERROR: status_text = "Error"
	
	agent_label.text = "%s\n%s" % [agent_type.to_upper(), status_text]


func _play_state_animation() -> void:
	"""Play animation appropriate to current state"""
	if not animation_player:
		return
	
	match state:
		AgentState.IDLE: _play_idle_animation()
		AgentState.CODING: _play_coding_animation()
		AgentState.THINKING: _play_thinking_animation()
		AgentState.SPEAKING: _play_speaking_animation()
		AgentState.MOVING: _play_moving_animation()


func _play_idle_animation() -> void:
	"""Play idle animation"""
	# Simple floating animation
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(mesh_instance, "position:y", 0.1, 2.0)
	tween.tween_property(mesh_instance, "position:y", -0.1, 2.0)


func _play_coding_animation() -> void:
	"""Play typing animation"""
	var tween = create_tween()
	tween.set_loops()
	
	# Subtle bobbing while typing
	tween.tween_property(mesh_instance, "rotation:z", 0.05, 0.3)
	tween.tween_property(mesh_instance, "rotation:z", -0.05, 0.3)


func _play_thinking_animation() -> void:
	"""Play thinking animation"""
	var tween = create_tween()
	tween.set_loops()
	
	# Slow rotation while thinking
	tween.tween_property(mesh_instance, "rotation:y", 360.0, 4.0)


func _play_speaking_animation() -> void:
	"""Play speaking animation"""
	var tween = create_tween()
	tween.set_loops()
	
	# Bouncing while speaking
	tween.tween_property(mesh_instance, "scale", Vector3(1.1, 1.1, 1.1), 0.5)
	tween.tween_property(mesh_instance, "scale", Vector3.ONE, 0.5)


func _play_moving_animation() -> void:
	"""Play movement animation"""
	# Walking animation would be handled in _physics_process
	pass


# ═══════════════════════════════════════════════════════════════════════════
# Game Loop
# ═══════════════════════════════════════════════════════════════════════════

func _physics_process(delta: float) -> void:
	"""Handle physics and movement"""
	if is_moving and state == AgentState.MOVING:
		_move_towards_target(delta)


func _move_towards_target(delta: float) -> void:
	"""Move agent towards target position"""
	var direction = target_position - global_position
	var distance = direction.length()
	
	if distance < 0.1:
		# Reached target
		is_moving = false
		set_state(AgentState.IDLE)
		return
	
	# Move towards target
	direction = direction.normalized()
	velocity = direction * move_speed
	move_and_slide()
	
	# Rotate to face movement direction
	if direction.length_squared() > 0.01:
		var target_rotation = Quaternion(Vector3.UP, atan2(direction.x, direction.z))
		transform.basis = transform.basis.slerp(target_rotation, rotation_speed * delta)


func _update_state() -> void:
	"""Update state timer and behaviors"""
	state_timer += 0.1
	
	# Add state-specific behaviors here
	match state:
		AgentState.IDLE:
			# Random idle behaviors
			if state_timer > 5.0 and randf() < 0.1:
				_play_idle_animation()
				state_timer = 0.0
		AgentState.THINKING:
			# Thinking visual effects
			if state_timer > 2.0:
				set_state(AgentState.CODING)


# ═══════════════════════════════════════════════════════════════════════════
# Signal Handlers
# ═══════════════════════════════════════════════════════════════════════════

func _on_interaction_input(camera: Node, event: InputEvent, position: Vector3, normal: Vector3, shape_idx: int) -> void:
	"""Handle player interaction"""
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			interaction_requested.emit(agent_id)
			speak("Click me to assign a task!", 2.0)


func _on_manager_task_started(agent_id_filter: String, task_id: String, prompt: String) -> void:
	"""Handle task started from agent manager"""
	if agent_id_filter == agent_id:
		set_state(AgentState.CODING)


func _on_manager_task_completed(agent_id_filter: String, task_id: String, output: String) -> void:
	"""Handle task completed from agent manager"""
	if agent_id_filter == agent_id:
		current_task = ""
		set_state(AgentState.IDLE)
		speak("Task completed successfully!")
		task_completed.emit(agent_id, output)


func _on_manager_task_failed(agent_id_filter: String, task_id: String, error: String) -> void:
	"""Handle task failed from agent manager"""
	if agent_id_filter == agent_id:
		current_task = ""
		set_state(AgentState.ERROR)
		speak("I encountered an error: " + error.substr(0, 30))
		task_failed.emit(agent_id, error)