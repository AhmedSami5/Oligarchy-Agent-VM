# ═══════════════════════════════════════════════════════════════════════════
# agent_behavior_system.gd - Agent Behavior and AI Management
# ═══════════════════════════════════════════════════════════════════════════
# Place this file in: addons/agentvm/systems/agent_behavior_system.gd

extends Node
class_name AgentBehaviorSystem

## Manages agent behaviors, AI patterns, and personality-driven actions
## Provides different behavior profiles for different agent types

# ═══════════════════════════════════════════════════════════════════════════
# Behavior Profiles
# ═══════════════════════════════════════════════════════════════════════════

## Behavior configurations for different agent types
var behavior_profiles: Dictionary = {
	"aider": {
		"work_style": "focused",
		"communication_pattern": "concise",
		"collaboration_tendency": 0.8,
		"autonomy_level": 0.9,
		"preferred_tasks": ["refactoring", "debugging", "optimization"],
		"avoid_tasks": ["creative_writing", "ui_design"],
		"idle_behaviors": ["observe_code", "check_documentation", "plan_next_task"],
		"working_animations": ["focused_typing", "code_review", "debug_analysis"]
	},
	"opencode": {
		"work_style": "autonomous",
		"communication_pattern": "enthusiastic",
		"collaboration_tendency": 0.9,
		"autonomy_level": 0.95,
		"preferred_tasks": ["feature_development", "code_generation", "system_design"],
		"avoid_tasks": ["routine_maintenance", "documentation"],
		"idle_behaviors": ["explore_codebase", "experiment_with_ideas", "seek_new_tasks"],
		"working_animations": ["creative_typing", "rapid_prototyping", "system_architecture"]
	},
	"claude": {
		"work_style": "collaborative",
		"communication_pattern": "conversational",
		"collaboration_tendency": 0.95,
		"autonomy_level": 0.8,
		"preferred_tasks": ["explanation", "teaching", "code_review", "documentation"],
		"avoid_tasks": ["low_level_optimization", "system_critical_tasks"],
		"idle_behaviors": ["chat_with_others", "help_teammates", "explain_code"],
		"working_animations": ["thoughtful_typing", "explanatory_gestures", "collaborative_discussion"]
	}
}

# ═══════════════════════════════════════════════════════════════════════════
# Agent State Management
# ═══════════════════════════════════════════════════════════════════════════

## Registered agents with their behavior data
var registered_agents: Dictionary[String, Dictionary] = {}

## Behavior update timer
var behavior_timer: Timer

## Configuration resource
var config: AgentConfig

## Environment context for decision making
var environment_context: Dictionary = {
	"time_of_day": "morning",
	"project_complexity": "medium",
	"team_size": 0,
	"deadline_pressure": 0.5,
	"available_tasks": []
}


# ═══════════════════════════════════════════════════════════════════════════
# Signals
# ═══════════════════════════════════════════════════════════════════════════

signal behavior_triggered(agent_id: String, behavior: String)
signal collaboration_initiated(agent_id: String, target_id: String)
signal task_preference_detected(agent_id: String, task_type: String)


# ═══════════════════════════════════════════════════════════════════════════
# Initialization
# ═══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	"""Initialize the behavior system"""
	print("[AgentBehaviorSystem] Initializing behavior management...")
	
	# Set up behavior update timer
	behavior_timer = Timer.new()
	behavior_timer.wait_time = 1.0
	behavior_timer.timeout.connect(_update_behaviors)
	add_child(behavior_timer)
	behavior_timer.start()
	
	# Load default configuration
	update_configuration(AgentConfig.new())


func update_configuration(new_config: AgentConfig) -> void:
	"""Update system configuration"""
	config = new_config
	
	# Update behavior profiles from config
	for agent_type in config.agent_templates:
		var template = config.agent_templates[agent_type]
		if template.has("behavior_profile"):
			behavior_profiles[agent_type] = template.behavior_profile
	
	# Update behavior timer frequency
	if behavior_timer:
		behavior_timer.wait_time = config.behavior_update_frequency
	
	print("[AgentBehaviorSystem] Configuration updated")


func apply_agent_behavior(agent: AgentEntity) -> void:
	"""Apply behavior profile to an agent"""
	if not agent:
		return
	
	var agent_id = agent.agent_id
	var agent_type = agent.agent_type
	
	# Get behavior profile
	var profile = behavior_profiles.get(agent_type, {})
	
	# Create agent behavior data
	var behavior_data = {
		"agent": agent,
		"profile": profile,
		"current_behavior": "idle",
		"behavior_history": [],
		"collaboration_partners": [],
		"task_preferences": profile.get("preferred_tasks", []),
		"autonomy_level": profile.get("autonomy_level", 0.8),
		"last_behavior_change": Time.get_unix_time_from_system()
	}
	
	# Register agent
	registered_agents[agent_id] = behavior_data
	
	print("[AgentBehaviorSystem] Applied behavior profile to %s" % agent_id)


# ═══════════════════════════════════════════════════════════════════════════
# Behavior Control
# ═══════════════════════════════════════════════════════════════════════════

var behavior_cooldowns: Dictionary[String, float] = {}

func set_agent_behavior(agent_id: String, behavior: String) -> bool:
	"""Set specific behavior for an agent"""
	if not registered_agents.has(agent_id):
		return false
	
	# Check behavior cooldown
	if behavior_cooldowns.get(agent_id, 0) > Time.get_unix_time_from_system():
		return false
	
	# Set cooldown to prevent rapid behavior switching
	behavior_cooldowns[agent_id] = Time.get_unix_time_from_system() + randf_range(2.0, 5.0)
	
	var behavior_data = registered_agents[agent_id]
	var agent = behavior_data.agent
	
	# Record behavior change
	behavior_data.behavior_history.append({
		"behavior": behavior,
		"timestamp": Time.get_unix_time_from_system()
	})
	
	behavior_data.current_behavior = behavior
	behavior_data.last_behavior_change = Time.get_unix_time_from_system()
	
	# Execute behavior
	_execute_behavior(agent, behavior)
	
	behavior_triggered.emit(agent_id, behavior)
	return true


func trigger_idle_behavior(agent_id: String) -> bool:
	"""Trigger an appropriate idle behavior"""
	if not registered_agents.has(agent_id):
		return false
	
	var behavior_data = registered_agents[agent_id]
	var agent = behavior_data.agent
	
	# Get idle behaviors for agent type
	var idle_behaviors = behavior_data.profile.get("idle_behaviors", ["idle_wait"])
	
	if idle_behaviors.is_empty():
		return false
	
	# Choose random idle behavior
	var behavior = idle_behaviors[randi() % idle_behaviors.size()]
	return set_agent_behavior(agent_id, behavior)


func trigger_work_behavior(agent_id: String, task_type: String) -> bool:
	"""Trigger work behavior based on task type"""
	if not registered_agents.has(agent_id):
		return false
	
	var behavior_data = registered_agents[agent_id]
	var agent = behavior_data.agent
	
	# Map task types to behaviors
	var task_behavior_map: Dictionary = {
		"debugging": "focused_debugging",
		"coding": "active_coding",
		"collaboration": "team_collaboration",
		"planning": "strategic_planning",
		"documentation": "thoughtful_writing",
		"refactoring": "careful_refactoring"
	}
	
	var behavior = task_behavior_map.get(task_type, "general_coding")
	return set_agent_behavior(agent_id, behavior)


func should_collaborate(agent_id: String, other_agent_id: String) -> float:
	"""Calculate collaboration probability between two agents"""
	if not registered_agents.has(agent_id) or not registered_agents.has(other_agent_id):
		return 0.0
	
	var agent1_data = registered_agents[agent_id]
	var agent2_data = registered_agents[other_agent_id]
	
	var collaboration_tendency = (
		agent1_data.profile.get("collaboration_tendency", 0.5) +
		agent2_data.profile.get("collaboration_tendency", 0.5)
	) / 2.0
	
	# Modify based on agent types
	var type_bonus = 0.0
	if agent1_data.agent.agent_type != agent2_data.agent.agent_type:
		type_bonus = 0.2  # Different types collaborate better
	
	return clamp(collaboration_tendency + type_bonus, 0.0, 1.0)


func suggest_collaboration(agent_id: String) -> String:
	"""Suggest a collaboration partner for an agent"""
	if not registered_agents.has(agent_id):
		return ""
	
	var best_partner = ""
	var best_score = 0.0
	
	for other_id in registered_agents.keys():
		if other_id == agent_id:
			continue
		
		var other_agent = registered_agents[other_id].agent
		
		# Only suggest idle agents
		if other_agent.state != AgentEntity.AgentState.IDLE:
			continue
		
		var score = should_collaborate(agent_id, other_id)
		if score > best_score:
			best_score = score
			best_partner = other_id
	
	return best_partner


# ═══════════════════════════════════════════════════════════════════════════
# Behavior Execution
# ═══════════════════════════════════════════════════════════════════════════

func _execute_behavior(agent: AgentEntity, behavior: String) -> void:
	"""Execute a specific behavior"""
	match behavior:
		"idle_wait":
			_execute_idle_wait(agent)
		"observe_code":
			_execute_observe_code(agent)
		"check_documentation":
			_execute_check_documentation(agent)
		"explore_codebase":
			_execute_explore_codebase(agent)
		"focused_typing":
			_execute_focused_typing(agent)
		"creative_typing":
			_execute_creative_typing(agent)
		"thoughtful_typing":
			_execute_thoughtful_typing(agent)
		"team_collaboration":
			_execute_team_collaboration(agent)
		"debug_analysis":
			_execute_debug_analysis(agent)
		"code_review":
			_execute_code_review(agent)
		_:
			_execute_default_behavior(agent)


func _execute_idle_wait(agent: AgentEntity) -> void:
	"""Execute idle waiting behavior"""
	agent.speak("Waiting for next task...", 2.0)
	
	# Gentle floating animation
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(agent, "position:y", 0.1, 3.0)
	tween.tween_property(agent, "position:y", -0.1, 3.0)


func _execute_observe_code(agent: AgentEntity) -> void:
	"""Execute code observation behavior"""
	agent.speak("Analyzing code patterns...", 2.5)
	
	# Look around animation
	var tween = create_tween()
	tween.tween_property(agent, "rotation:y", 45.0, 1.0)
	tween.tween_property(agent, "rotation:y", -45.0, 1.0)
	tween.tween_property(agent, "rotation:y", 0.0, 1.0)


func _execute_check_documentation(agent: AgentEntity) -> void:
	"""Execute documentation checking behavior"""
	agent.speak("Reviewing documentation...", 2.0)
	
	# Nodding animation
	var tween = create_tween()
	tween.set_loops()
	for i in range(3):
		tween.tween_property(agent, "rotation:x", 15.0, 0.3)
		tween.tween_property(agent, "rotation:x", -15.0, 0.3)


func _execute_explore_codebase(agent: AgentEntity) -> void:
	"""Execute codebase exploration behavior"""
	agent.speak("Exploring new areas of code...", 2.0)
	
	# Movement animation
	var original_pos = agent.global_position
	var target_pos = original_pos + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
	agent.move_to_position(target_pos)


func _execute_focused_typing(agent: AgentEntity) -> void:
	"""Execute focused typing behavior"""
	agent.set_state(AgentEntity.AgentState.CODING)
	
	# Rapid, focused typing animation
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(agent, "scale", Vector3(1.05, 1.05, 1.05), 0.2)
	tween.tween_property(agent, "scale", Vector3.ONE, 0.2)


func _execute_creative_typing(agent: AgentEntity) -> void:
	"""Execute creative typing behavior"""
	agent.set_state(AgentEntity.AgentState.CODING)
	agent.speak("Creating something new!", 2.0)
	
	# Energetic typing animation
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(agent, "rotation:z", 5.0, 0.3)
	tween.tween_property(agent, "rotation:z", -5.0, 0.3)


func _execute_thoughtful_typing(agent: AgentEntity) -> void:
	"""Execute thoughtful typing behavior"""
	agent.set_state(AgentEntity.AgentState.CODING)
	
	# Slow, deliberate typing animation
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(agent, "position:y", 0.05, 1.0)
	tween.tween_property(agent, "position:y", -0.05, 1.0)


func _execute_team_collaboration(agent: AgentEntity) -> void:
	"""Execute team collaboration behavior"""
	agent.set_state(AgentEntity.AgentState.COLLABORATING)
	agent.speak("Working together!", 2.0)
	
	# Find nearest agent to collaborate with
	var nearest_agent = _find_nearest_agent(agent)
	if nearest_agent:
		agent.collaborate_with(nearest_agent)


func _execute_debug_analysis(agent: AgentEntity) -> void:
	"""Execute debug analysis behavior"""
	agent.set_state(AgentEntity.AgentState.THINKING)
	agent.speak("Analyzing the issue...", 2.0)
	
	# Magnifying glass motion
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(agent, "rotation:y", 360.0, 2.0)


func _execute_code_review(agent: AgentEntity) -> void:
	"""Execute code review behavior"""
	agent.set_state(AgentEntity.AgentState.THINKING)
	agent.speak("Reviewing code quality...", 2.0)
	
	# Nod and shake animation
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(agent, "rotation:x", 10.0, 0.5)
	tween.tween_property(agent, "rotation:x", -10.0, 0.5)


func _execute_default_behavior(agent: AgentEntity) -> void:
	"""Execute default behavior"""
	agent.speak("Working on it...", 2.0)


# ═══════════════════════════════════════════════════════════════════════════
# Utility Methods
# ═══════════════════════════════════════════════════════════════════════════

func _find_nearest_agent(agent: AgentEntity) -> AgentEntity:
	"""Find the nearest agent to collaborate with"""
	var nearest: AgentEntity = null
	var nearest_distance = INF
	
	for behavior_data in registered_agents.values():
		var other_agent = behavior_data.agent
		if other_agent == agent:
			continue
		
		if other_agent.state != AgentEntity.AgentState.IDLE:
			continue
		
		var distance = agent.global_position.distance_to(other_agent.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = other_agent
	
	return nearest


func _update_behaviors() -> void:
	"""Update behaviors for all registered agents"""
	for agent_id in registered_agents.keys():
		var behavior_data = registered_agents[agent_id]
		var agent = behavior_data.agent
		
		# Only update idle agents
		if agent.state != AgentEntity.AgentState.IDLE:
			continue
		
		# Check if it's time for a new idle behavior
		var time_since_change = Time.get_unix_time_from_system() - behavior_data.last_behavior_change
		
		if time_since_change > 5.0:  # Change behavior every 5 seconds
			if randf() < 0.3:  # 30% chance to trigger new idle behavior
				trigger_idle_behavior(agent_id)


func update_environment_context(key: String, value) -> void:
	"""Update environment context that affects behaviors"""
	environment_context[key] = value


func get_agent_behavior_data(agent_id: String) -> Dictionary:
	"""Get behavior data for an agent"""
	return registered_agents.get(agent_id, {})


func remove_agent(agent_id: String) -> void:
	"""Remove agent from behavior system"""
	registered_agents.erase(agent_id)