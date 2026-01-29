# ═══════════════════════════════════════════════════════════════════════════
# agent_visualization_system.gd - Agent Appearance and Visual Effects
# ═══════════════════════════════════════════════════════════════════════════
# Place this file in: addons/agentvm/systems/agent_visualization_system.gd

extends Node
class_name AgentVisualizationSystem

## Manages visual appearance, animations, and effects for agent entities
## Provides unique visual identity for different agent types and states

# ═══════════════════════════════════════════════════════════════════════════
# Visual Configuration
# ═══════════════════════════════════════════════════════════════════════════

## Visual themes for different agent types
var visual_themes: Dictionary = {
	"aider": {
		"primary_color": Color.BLUE,
		"secondary_color": Color.CYAN,
		"accent_color": Color.WHITE,
		"mesh_type": "capsule",
		"material_properties": {
			"metallic": 0.2,
			"roughness": 0.7,
			"emission_energy": 0.1
		},
		"particle_colors": [Color.BLUE, Color.CYAN, Color.WHITE],
		"glow_intensity": 0.3,
		"height": 1.8,
		"radius": 0.4
	},
	"opencode": {
		"primary_color": Color.GREEN,
		"secondary_color": Color.LIME,
		"accent_color": Color.YELLOW,
		"mesh_type": "capsule",
		"material_properties": {
			"metallic": 0.1,
			"roughness": 0.6,
			"emission_energy": 0.2
		},
		"particle_colors": [Color.GREEN, Color.LIME, Color.YELLOW],
		"glow_intensity": 0.5,
		"height": 1.8,
		"radius": 0.4
	},
	"claude": {
		"primary_color": Color.ORANGE,
		"secondary_color": Color.ORANGE_RED,
		"accent_color": Color.WHITE,
		"mesh_type": "capsule",
		"material_properties": {
			"metallic": 0.3,
			"roughness": 0.5,
			"emission_energy": 0.15
		},
		"particle_colors": [Color.ORANGE, Color.ORANGE_RED, Color.YELLOW],
		"glow_intensity": 0.4,
		"height": 1.8,
		"radius": 0.4
	}
}

## State-based visual configurations
var state_visuals: Dictionary = {
	"idle": {
		"animation": "gentle_float",
		"glow_pulse": true,
		"particle_emission": false,
		"animation_speed": 0.5
	},
	"thinking": {
		"animation": "slow_rotate",
		"glow_pulse": true,
		"particle_emission": true,
		"particle_type": "thought",
		"animation_speed": 0.3
	},
	"coding": {
		"animation": "typing_motion",
		"glow_pulse": false,
		"particle_emission": true,
		"particle_type": "code",
		"animation_speed": 1.0
	},
	"speaking": {
		"animation": "bounce_pulse",
		"glow_pulse": true,
		"particle_emission": false,
		"animation_speed": 0.8
	},
	"moving": {
		"animation": "walk_cycle",
		"glow_pulse": false,
		"particle_emission": false,
		"animation_speed": 1.0
	},
	"collaborating": {
		"animation": "collaborative_motion",
		"glow_pulse": true,
		"particle_emission": true,
		"particle_type": "collaboration",
		"animation_speed": 0.6
	},
	"error": {
		"animation": "error_shake",
		"glow_pulse": true,
		"particle_emission": true,
		"particle_type": "error",
		"animation_speed": 0.4
	}
}

# ═══════════════════════════════════════════════════════════════════════════
# Visual Assets
# ═══════════════════════════════════════════════════════════════════════════

## Preloaded particle systems
var particle_systems: Dictionary = {}

## Animation library
var animation_library: AnimationLibrary

## Material library
var material_library: Dictionary = {}

## Registered agents with their visual data
var registered_agents: Dictionary[String, Dictionary] = {}


# ═══════════════════════════════════════════════════════════════════════════
# Initialization
# ═══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	"""Initialize visualization system"""
	print("[AgentVisualizationSystem] Initializing visual systems...")
	
	# Load default configuration
	update_configuration(AgentConfig.new())
	
	print("[AgentVisualizationSystem] Visual systems ready!")


func update_configuration(new_config: AgentConfig) -> void:
	"""Update system configuration"""
	config = new_config
	
	# Update visual themes from config
	for agent_type in config.agent_templates:
		var template = config.agent_templates[agent_type]
		visual_themes[agent_type] = {
			"primary_color": template.color,
			"secondary_color": template.secondary_color,
			"mesh_type": template.mesh_type,
			"height": template.height,
			"radius": template.radius,
			"material_properties": {
				"metallic": 0.2,
				"roughness": 0.7,
				"emission_energy": 0.1
			}
		}
	
	# Update quality settings
	max_particles_per_type = 10 + (10 * config.particle_quality)
	
	# Recreate visual assets
	_create_particle_systems()
	_create_animation_library()
	_create_material_library()
	
	print("[AgentVisualizationSystem] Configuration updated")


func apply_agent_visualization(agent: AgentEntity) -> void:
	"""Apply visual theme and setup to an agent"""
	if not agent:
		return
	
	var agent_id = agent.agent_id
	var agent_type = agent.agent_type
	
	# Get visual theme
	var theme = visual_themes.get(agent_type, visual_themes["aider"])
	
	# Create visual data
	var visual_data = {
		"agent": agent,
		"theme": theme,
		"current_state": "idle",
		"mesh_instance": null,
		"animation_player": null,
		"status_indicator": null,
		"particle_systems": {},
		"current_material": null,
		"original_transform": agent.transform
	}
	
	# Apply visual theme
	_apply_theme(agent, theme)
	
	# Set up components
	_setup_visual_components(agent, visual_data)
	
	# Register agent
	registered_agents[agent_id] = visual_data
	
	# Apply initial state
	update_agent_visual_state(agent_id, "idle")
	
	print("[AgentVisualizationSystem] Applied visualization to %s" % agent_id)


# ═══════════════════════════════════════════════════════════════════════════
# Visual State Management
# ═══════════════════════════════════════════════════════════════════════════

func update_agent_visual_state(agent_id: String, state: String) -> void:
	"""Update agent's visual state"""
	if not registered_agents.has(agent_id):
		return
	
	var visual_data = registered_agents[agent_id]
	var state_config = state_visuals.get(state, state_visuals["idle"])
	
	visual_data.current_state = state
	
	# Update animation
	_update_animation(visual_data, state_config)
	
	# Update glow
	_update_glow(visual_data, state_config)
	
	# Update particles
	_update_particles(visual_data, state_config)


func update_agent_color(agent_id: String, color: Color) -> void:
	"""Update agent's primary color"""
	if not registered_agents.has(agent_id):
		return
	
	var visual_data = registered_agents[agent_id]
	var material = visual_data.current_material
	
	if material:
		material.albedo_color = color


func trigger_effect(agent_id: String, effect_type: String) -> void:
	"""Trigger special visual effect"""
	if not registered_agents.has(agent_id):
		return
	
	var visual_data = registered_agents[agent_id]
	var agent = visual_data.agent
	
	match effect_type:
		"spawn":
			_play_spawn_effect(agent)
		"task_complete":
			_play_completion_effect(agent)
		"error":
			_play_error_effect(agent)
		"collaboration_start":
			_play_collaboration_effect(agent)
		"power_up":
			_play_power_up_effect(agent)


func create_connection_effect(agent1_id: String, agent2_id: String) -> void:
	"""Create visual connection between two agents"""
	if not registered_agents.has(agent1_id) or not registered_agents.has(agent2_id):
		return
	
	var agent1 = registered_agents[agent1_id].agent
	var agent2 = registered_agents[agent2_id].agent
	
	# Create line between agents
	var line_mesh = ImmediateMesh.new()
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = line_mesh
	
	# Create material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.CYAN
	material.emission_enabled = true
	material.emission = Color.CYAN
	material.emission_energy_multiplier = 2.0
	mesh_instance.material_override = material
	
	# Add to scene
	get_tree().current_scene.add_child(mesh_instance)
	
	# Animate connection
	_animate_connection(mesh_instance, agent1, agent2)


# ═══════════════════════════════════════════════════════════════════════════
# Private Visual Methods
# ═══════════════════════════════════════════════════════════════════════════

func _apply_theme(agent: AgentEntity, theme: Dictionary) -> void:
	"""Apply visual theme to agent"""
	var mesh_instance = agent.get_node("MeshInstance3D") as MeshInstance3D
	if not mesh_instance:
		return
	
	# Create or get capsule mesh
	var capsule_mesh = CapsuleMesh.new()
	capsule_mesh.height = theme.get("height", 1.8)
	capsule_mesh.radius = theme.get("radius", 0.4)
	mesh_instance.mesh = capsule_mesh
	
	# Create themed material
	var material = _create_themed_material(theme)
	mesh_instance.material_override = material


func _create_themed_material(theme: Dictionary) -> StandardMaterial3D:
	"""Create material based on theme"""
	var material = StandardMaterial3D.new()
	
	# Apply base color
	material.albedo_color = theme.get("primary_color", Color.WHITE)
	
	# Apply material properties
	var props = theme.get("material_properties", {})
	material.metallic = props.get("metallic", 0.0)
	material.roughness = props.get("roughness", 0.5)
	
	# Set up emission
	if props.get("emission_energy", 0.0) > 0.0:
		material.emission_enabled = true
		material.emission = theme.get("secondary_color", Color.WHITE)
		material.emission_energy_multiplier = props.get("emission_energy", 0.0)
	
	return material


func _setup_visual_components(agent: AgentEntity, visual_data: Dictionary) -> void:
	"""Set up visual components for agent"""
	# Get or create mesh instance
	var mesh_instance = agent.get_node("MeshInstance3D") as MeshInstance3D
	if mesh_instance:
		visual_data.mesh_instance = mesh_instance
		visual_data.current_material = mesh_instance.material_override
	
	# Get or create animation player
	var animation_player = agent.get_node("AnimationPlayer") as AnimationPlayer
	if animation_player:
		visual_data.animation_player = animation_player
	
	# Get or create status indicator
	var status_indicator = agent.get_node("StatusIndicator") as Sprite3D
	if status_indicator:
		visual_data.status_indicator = status_indicator
		_setup_status_indicator(status_indicator, visual_data.theme)
	
	# Set up particle systems
	_setup_particle_systems(agent, visual_data)


func _setup_status_indicator(status_indicator: Sprite3D, theme: Dictionary) -> void:
	"""Set up status indicator with theme"""
	# Create status texture
	var texture = _create_status_indicator_texture(theme)
	status_indicator.texture = texture


func _setup_particle_systems(agent: AgentEntity, visual_data: Dictionary) -> void:
	"""Set up particle systems for agent"""
	var particle_types = ["thought", "code", "collaboration", "error"]
	
	for particle_type in particle_types:
		var particle_system = _create_particle_system(particle_type, visual_data.theme)
		particle_system.name = particle_type + "Particles"
		agent.add_child(particle_system)
		particle_system.emitting = false
		
		visual_data.particle_systems[particle_type] = particle_system


func _create_particle_material(type: String, theme: Dictionary) -> ParticleProcessMaterial:
	"""Create particle material based on type and theme"""
	match type:
		"thought":
			return _create_thought_particles(theme)
		"code":
			return _create_code_particles(theme)
		"collaboration":
			return _create_collaboration_particles(theme)
		"error":
			return _create_error_particles(theme)
		_:
			return ParticleProcessMaterial.new()


func _create_particle_system(type: String, theme: Dictionary) -> GPUParticles3D:
	"""Create particle system for specific type using resource pooling"""
	var particles: GPUParticles3D
	
	# Check if we have a pooled particle system available
	if particle_pool[type].size() > 0:
		particles = particle_pool[type].pop_back()
		particles.emitting = false
		# Reconfigure particles
		particles.process_material = _create_particle_material(type, theme)
		particles.restart()
	else:
		# Create new particle system if pool is empty
		particles = GPUParticles3D.new()
		particles.name = "%sParticles_%d" % [type, particle_systems.size()]
		particles.process_material = _create_particle_material(type, theme)
		
	# Common settings
	particles.position.y = 2.0
	particles.emitting = false
	particles.amount = 20 + (10 * get_config().particle_quality)  # Quality-based particle count
	
	# Limit pool size
	if particle_pool[type].size() < max_particles_per_type:
		particle_pool[type].push_back(particles)
	
	return particles
	
	# Configure based on type
	match type:
		"thought":
			particles.process_material = _create_thought_particles(theme)
		"code":
			particles.process_material = _create_code_particles(theme)
		"collaboration":
			particles.process_material = _create_collaboration_particles(theme)
		"error":
			particles.process_material = _create_error_particles(theme)
	
	# Common settings
	particles.position.y = 2.0
	particles.emitting = false
	
	return particles


func _create_thought_particles(theme: Dictionary) -> ParticleProcessMaterial:
	"""Create thought bubble particles"""
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3.UP
	material.spread = 10.0
	material.initial_velocity_min = 0.5
	material.initial_velocity_max = 1.0
	material.gravity = Vector3.ZERO
	material.scale_min = 0.1
	material.scale_max = 0.3
	material.color = theme.get("secondary_color", Color.WHITE)
	return material


func _create_code_particles(theme: Dictionary) -> ParticleProcessMaterial:
	"""Create code particles"""
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3.UP
	material.spread = 30.0
	material.initial_velocity_min = 1.0
	material.initial_velocity_max = 2.0
	material.gravity = Vector3.ZERO
	material.scale_min = 0.05
	material.scale_max = 0.15
	material.color = theme.get("accent_color", Color.WHITE)
	return material


func _create_collaboration_particles(theme: Dictionary) -> ParticleProcessMaterial:
	"""Create collaboration particles"""
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3.UP
	material.spread = 45.0
	material.initial_velocity_min = 0.8
	material.initial_velocity_max = 1.5
	material.gravity = Vector3.ZERO
	material.scale_min = 0.08
	material.scale_max = 0.2
	material.color = Color.MAGENTA
	return material


func _create_error_particles(theme: Dictionary) -> ParticleProcessMaterial:
	"""Create error particles"""
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3.UP
	material.spread = 60.0
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 3.0
	material.gravity = Vector3.DOWN * 0.5
	material.scale_min = 0.1
	material.scale_max = 0.2
	material.color = Color.RED
	return material


func _update_animation(visual_data: Dictionary, state_config: Dictionary) -> void:
	"""Update agent animation"""
	var animation_player = visual_data.animation_player
	if not animation_player:
		return
	
	var animation_name = state_config.get("animation", "gentle_float")
	var animation_speed = state_config.get("animation_speed", 1.0)
	
	# Create and play animation
	var animation = _create_animation(animation_name)
	if animation:
		animation_player.add_animation(animation_name, animation)
		animation_player.play(animation_name, -1, animation_speed)


func _update_glow(visual_data: Dictionary, state_config: Dictionary) -> void:
	"""Update glow effect"""
	var mesh_instance = visual_data.mesh_instance
	var material = visual_data.current_material
	var theme = visual_data.theme
	
	if not mesh_instance or not material:
		return
	
	var should_glow = state_config.get("glow_pulse", false)
	var base_glow = theme.get("glow_intensity", 0.0)
	
	if should_glow:
		# Create pulsing glow effect
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(material, "emission_energy_multiplier", base_glow * 2.0, 1.0)
		tween.tween_property(material, "emission_energy_multiplier", base_glow, 1.0)
	else:
		# Set steady glow
		material.emission_energy_multiplier = base_glow


func _update_particles(visual_data: Dictionary, state_config: Dictionary) -> void:
	"""Update particle emissions"""
	var should_emit = state_config.get("particle_emission", false)
	var particle_type = state_config.get("particle_type", "")
	
	# Turn off all particles first
	for particles in visual_data.particle_systems.values():
		if particles:
			particles.emitting = false
	
	# Turn on specific particle type if needed
	if should_emit and visual_data.particle_systems.has(particle_type):
		var particles = visual_data.particle_systems[particle_type]
		if particles:
			particles.emitting = true


# ═══════════════════════════════════════════════════════════════════════════
# Animation Creation
# ═══════════════════════════════════════════════════════════════════════════

func _create_animation_library() -> void:
	"""Create library of animations"""
	animation_library = AnimationLibrary.new()


func _create_animation(animation_name: String) -> Animation:
	"""Create specific animation"""
	var animation = Animation.new()
	var animation_length = 2.0
	
	match animation_name:
		"gentle_float":
			_create_gentle_float_animation(animation, animation_length)
		"slow_rotate":
			_create_slow_rotate_animation(animation, animation_length)
		"typing_motion":
			_create_typing_animation(animation, animation_length)
		"bounce_pulse":
			_create_bounce_animation(animation, animation_length)
		"walk_cycle":
			_create_walk_animation(animation, animation_length)
		"collaborative_motion":
			_create_collaboration_animation(animation, animation_length)
		"error_shake":
			_create_shake_animation(animation, animation_length)
	
	return animation


func _create_gentle_float_animation(animation: Animation, length: float) -> void:
	"""Create gentle floating animation"""
	var track_index = animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(track_index, ".:position")
	animation.track_set_interpolation_type(track_index, Animation.INTERPOLATION_LINEAR)
	animation.length = length
	
	# Float up and down
	animation.track_insert_key(track_index, 0.0, Vector3(0, 0, 0))
	animation.track_insert_key(track_index, length * 0.5, Vector3(0, 0.1, 0))
	animation.track_insert_key(track_index, length, Vector3(0, 0, 0))


func _create_slow_rotate_animation(animation: Animation, length: float) -> void:
	"""Create slow rotation animation"""
	var track_index = animation.add_track(Animation.TYPE_ROTATION_3D)
	animation.track_set_path(track_index, ".:rotation")
	animation.track_set_interpolation_type(track_index, Animation.INTERPOLATION_LINEAR)
	animation.length = length
	
	var start_quat = Quaternion.IDENTITY
	var end_quat = Quaternion(Vector3.UP, deg_to_rad(360))
	
	animation.track_insert_key(track_index, 0.0, start_quat)
	animation.track_insert_key(track_index, length, end_quat)


func _create_typing_animation(animation: Animation, length: float) -> void:
	"""Create typing motion animation"""
	var track_index = animation.add_track(Animation.TYPE_SCALE_3D)
	animation.track_set_path(track_index, ".:scale")
	animation.track_set_interpolation_type(track_index, Animation.INTERPOLATION_LINEAR)
	animation.length = length
	
	var base_scale = Vector3.ONE
	var typing_scale = Vector3(1.05, 1.05, 1.05)
	
	animation.track_insert_key(track_index, 0.0, base_scale)
	animation.track_insert_key(track_index, length * 0.3, typing_scale)
	animation.track_insert_key(track_index, length * 0.6, base_scale)
	animation.track_insert_key(track_index, length, typing_scale)


func _create_bounce_animation(animation: Animation, length: float) -> void:
	"""Create bounce pulse animation"""
	var track_index = animation.add_track(Animation.TYPE_SCALE_3D)
	animation.track_set_path(track_index, ".:scale")
	animation.track_set_interpolation_type(track_index, Animation.INTERPOLATION_EASE_IN_OUT)
	animation.length = length
	
	var base_scale = Vector3.ONE
	var bounce_scale = Vector3(1.1, 1.1, 1.1)
	
	animation.track_insert_key(track_index, 0.0, base_scale)
	animation.track_insert_key(track_index, length * 0.5, bounce_scale)
	animation.track_insert_key(track_index, length, base_scale)


func _create_walk_animation(animation: Animation, length: float) -> void:
	"""Create walk cycle animation"""
	var track_index = animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(track_index, ".:position")
	animation.track_set_interpolation_type(track_index, Animation.INTERPOLATION_LINEAR)
	animation.length = length
	
	animation.track_insert_key(track_index, 0.0, Vector3(0, 0, 0))
	animation.track_insert_key(track_index, length * 0.5, Vector3(0, 0.1, 0))
	animation.track_insert_key(track_index, length, Vector3(0, 0, 0))


func _create_collaboration_animation(animation: Animation, length: float) -> void:
	"""Create collaboration animation"""
	var scale_track = animation.add_track(Animation.TYPE_SCALE_3D)
	animation.track_set_path(scale_track, ".:scale")
	animation.track_set_interpolation_type(scale_track, Animation.INTERPOLATION_EASE_IN_OUT)
	
	var rotation_track = animation.add_track(Animation.TYPE_ROTATION_3D)
	animation.track_set_path(rotation_track, ".:rotation")
	animation.track_set_interpolation_type(rotation_track, Animation.INTERPOLATION_EASE_IN_OUT)
	
	animation.length = length
	
	var base_scale = Vector3.ONE
	var collab_scale = Vector3(1.15, 1.15, 1.15)
	var start_quat = Quaternion.IDENTITY
	var end_quat = Quaternion(Vector3.UP, deg_to_rad(15))
	
	# Scale animation
	animation.track_insert_key(scale_track, 0.0, base_scale)
	animation.track_insert_key(scale_track, length * 0.5, collab_scale)
	animation.track_insert_key(scale_track, length, base_scale)
	
	# Rotation animation
	animation.track_insert_key(rotation_track, 0.0, start_quat)
	animation.track_insert_key(rotation_track, length * 0.5, end_quat)
	animation.track_insert_key(rotation_track, length, start_quat)


func _create_shake_animation(animation: Animation, length: float) -> void:
	"""Create error shake animation"""
	var track_index = animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(track_index, ".:position")
	animation.track_set_interpolation_type(track_index, Animation.INTERPOLATION_LINEAR)
	animation.length = length
	
	var base_pos = Vector3(0, 0, 0)
	
	animation.track_insert_key(track_index, 0.0, base_pos)
	animation.track_insert_key(track_index, 0.1, Vector3(0.1, 0, 0))
	animation.track_insert_key(track_index, 0.2, Vector3(-0.1, 0, 0))
	animation.track_insert_key(track_index, 0.3, Vector3(0, 0.1, 0))
	animation.track_insert_key(track_index, 0.4, Vector3(0, -0.1, 0))
	animation.track_insert_key(track_index, length, base_pos)


# ═══════════════════════════════════════════════════════════════════════════
# Special Effects
# ═══════════════════════════════════════════════════════════════════════════

func _play_spawn_effect(agent: AgentEntity) -> void:
	"""Play spawn effect"""
	var tween = create_tween()
	
	# Start with small scale and grow
	agent.scale = Vector3.ZERO
	tween.tween_property(agent, "scale", Vector3.ONE, 0.5)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)


func _play_completion_effect(agent: AgentEntity) -> void:
	"""Play task completion effect"""
	var tween = create_tween()
	
	# Bounce up and down
	tween.tween_property(agent, "scale", Vector3(1.2, 1.2, 1.2), 0.3)
	tween.tween_property(agent, "scale", Vector3.ONE, 0.3)
	tween.set_ease(Tween.EASE_OUT)


func _play_error_effect(agent: AgentEntity) -> void:
	"""Play error effect"""
	var tween = create_tween()
	
	# Shake effect
	for i in range(5):
		tween.tween_property(agent, "rotation:y", deg_to_rad(5), 0.1)
		tween.tween_property(agent, "rotation:y", deg_to_rad(-5), 0.1)
	
	tween.tween_property(agent, "rotation:y", 0.0, 0.1)


func _play_collaboration_effect(agent: AgentEntity) -> void:
	"""Play collaboration start effect"""
	var tween = create_tween()
	
	# Spin effect
	tween.tween_property(agent, "rotation:y", deg_to_rad(360), 0.5)
	tween.set_ease(Tween.EASE_IN_OUT)


func _play_power_up_effect(agent: AgentEntity) -> void:
	"""Play power-up effect"""
	var tween = create_tween()
	
	# Glowing pulse
	tween.tween_property(agent, "scale", Vector3(1.3, 1.3, 1.3), 0.4)
	tween.tween_property(agent, "scale", Vector3.ONE, 0.4)
	tween.set_ease(Tween.EASE_OUT)


func _animate_connection(mesh_instance: MeshInstance3D, agent1: AgentEntity, agent2: AgentEntity) -> void:
	"""Animate connection line between agents"""
	var tween = create_tween()
	
	# Animate for 3 seconds then remove
	tween.tween_property(mesh_instance.material_override, "emission_energy_multiplier", 5.0, 1.5)
	tween.tween_property(mesh_instance.material_override, "emission_energy_multiplier", 1.0, 1.5)
	
	tween.finished.connect(mesh_instance.queue_free)
	
	# Update line positions
	_update_connection_line(mesh_instance, agent1, agent2)


func _update_connection_line(mesh_instance: MeshInstance3D, agent1: AgentEntity, agent2: AgentEntity) -> void:
	"""Update connection line positions"""
	if not is_instance_valid(mesh_instance) or not is_instance_valid(agent1) or not is_instance_valid(agent2):
		return
	
	var line_mesh = mesh_instance.mesh as ImmediateMesh
	if not line_mesh:
		return
	
	line_mesh.clear_surfaces()
	
	var start = agent1.global_position
	var end = agent2.global_position + Vector3.UP  # Offset to agent height
	
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	line_mesh.surface_add_vertex(start)
	line_mesh.surface_add_vertex(end)
	line_mesh.surface_end()
	
	# Continue updating
	call_deferred("_update_connection_line", mesh_instance, agent1, agent2)


func _create_status_indicator_texture(theme: Dictionary) -> Texture2D:
	"""Create status indicator texture based on theme"""
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var primary_color = theme.get("primary_color", Color.WHITE)
	
	# Draw filled circle
	for x in range(32):
		for y in range(32):
			var dist = Vector2(x - 16, y - 16).length()
			if dist < 14:
				var alpha = 1.0 - (dist / 14.0)
				image.set_pixel(x, y, Color(primary_color.r, primary_color.g, primary_color.b, alpha))
			else:
				image.set_pixel(x, y, Color.TRANSPARENT)
	
	return ImageTexture.create_from_image(image)


func _create_particle_systems() -> void:
	"""Create reusable particle systems"""
	# This would be expanded with more complex particle systems
	pass


func _create_material_library() -> void:
	"""Create material library"""
	# Pre-create materials for common use cases
	for agent_type in visual_themes.keys():
		var theme = visual_themes[agent_type]
		material_library[agent_type] = _create_themed_material(theme)


func remove_agent(agent_id: String) -> void:
	"""Remove agent from visualization system and return resources to pool"""
	if not registered_agents.has(agent_id):
		return
	
	var visual_data = registered_agents[agent_id]
	
	# Return particle systems to pool
	for particle_type in visual_data.particle_systems:
		var particles = visual_data.particle_systems[particle_type]
		if particles and particle_pool.has(particle_type):
			particles.emitting = false
			if particle_pool[particle_type].size() < max_particles_per_type:
				particle_pool[particle_type].push_back(particles)
			else:
				particles.queue_free()
	
	# Remove from registry
	registered_agents.erase(agent_id)