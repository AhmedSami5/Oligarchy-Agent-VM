# ═══════════════════════════════════════════════════════════════════════════
# agent_interaction_system.gd - Agent Communication and Interaction
# ═══════════════════════════════════════════════════════════════════════════
# Place this file in: addons/agentvm/systems/agent_interaction_system.gd

extends Node
class_name AgentInteractionSystem

## Manages agent-to-agent communication, player interaction, and dialogue system
## Handles social behaviors and collaborative interactions

# ═══════════════════════════════════════════════════════════════════════════
# Interaction Configuration
# ═══════════════════════════════════════════════════════════════════════════

## Dialogue and communication patterns
var dialogue_patterns: Dictionary = {
	"greetings": {
		"aider": ["Ready to optimize some code!", "Let's refactor this.", "What needs debugging?"],
		"opencode": ["Hey! What are we building?", "Excited to code with you!", "Let's create something amazing!"],
		"claude": ["Hello! How can I help?", "Happy to assist with coding!", "Let me explain what I'm thinking..."]
	},
	"task_start": {
		"aider": ["Starting optimization...", "Analyzing the code structure...", "Let's tackle this systematically."],
		"opencode": ["Time to create!", "Building this feature now!", "Let's make some magic happen!"],
		"claude": ["I'll work through this step by step...", "Let me think about the best approach...", "Here's what I'm planning..."]
	},
	"task_complete": {
		"aider": ["Optimization complete.", "Code refactored successfully.", "All issues resolved."],
		"opencode": ["Feature implemented!", "Code generated successfully!", "Check out what I built!"],
		"claude": ["Task completed! Here's what I did...", "All done! Let me explain the changes...", "Finished! Here are the details..."]
	},
	"collaboration": {
		"aider": ["Let's coordinate our approach.", "I'll handle the optimization.", "Great teamwork!"],
		"opencode": ["This is exciting! Let's build together!", "I'll take this part, you take that!", "Awesome collaboration!"],
		"claude": ["I think we should discuss the approach...", "Let me share my thoughts...", "This is working out really well!"]
	},
	"help_offer": {
		"aider": ["Need help with debugging?", "Let me optimize that for you.", "I can help refactor that."],
		"opencode": ["Want to build something cool together?", "I've got an idea for this!", "Let me help with that feature!"],
		"claude": ["Can I explain how this works?", "Let me help you understand...", "I'd be happy to assist with this."]
	}
}

## Interaction behaviors and personality responses
var interaction_behaviors: Dictionary = {
	"friendliness": {
		"high": {"dialogue_chance": 0.8, "help_frequency": 0.7, "collaboration_initiative": 0.9},
		"medium": {"dialogue_chance": 0.5, "help_frequency": 0.4, "collaboration_initiative": 0.6},
		"low": {"dialogue_chance": 0.2, "help_frequency": 0.2, "collaboration_initiative": 0.3}
	}
}

# ═══════════════════════════════════════════════════════════════════════════
# System State
# ═══════════════════════════════════════════════════════════════════════════

## Registered agents
var registered_agents: Dictionary[String, Dictionary] = {}

## Active conversations
var conversations: Array[Dictionary] = []

## Conversation timeout timers
var conversation_timers: Dictionary[String, Timer] = {}

## Interaction history
var interaction_history: Array[Dictionary] = []

## Player interaction UI
var interaction_ui: Control

## Interaction cooldown timers
var interaction_cooldowns: Dictionary[String, float] = {}

# ═══════════════════════════════════════════════════════════════════════════
# Signals
# ═══════════════════════════════════════════════════════════════════════════

signal agent_spoke(agent_id: String, message: String, target_id: String)
signal conversation_started(conversation_id: String, participants: Array[String])
signal conversation_ended(conversation_id: String)
signal help_offered(agent_id: String, target_id: String, task: String)
signal collaboration_requested(agent_id: String, target_id: String)


# ═══════════════════════════════════════════════════════════════════════════
# Initialization
# ═══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	"""Initialize interaction system"""
	print("[AgentInteractionSystem] Initializing interaction management...")
	
	# Create interaction UI
	_create_interaction_ui()
	
	# Start interaction timer
	var interaction_timer = Timer.new()
	interaction_timer.wait_time = 2.0
	interaction_timer.timeout.connect(_process_interactions)
	add_child(interaction_timer)
	interaction_timer.start()
	
	print("[AgentInteractionSystem] Interaction system ready!")


func register_agent(agent: AgentEntity) -> void:
	"""Register an agent for interaction management"""
	var agent_id = agent.agent_id
	var agent_type = agent.agent_type
	
	# Create interaction data
	var interaction_data = {
		"agent": agent,
		"agent_type": agent_type,
		"personality": agent.personality,
		"last_interaction": 0.0,
		"current_conversation": "",
		"dialogue_cooldown": 0.0,
		"help_cooldown": 0.0,
		"relationship_scores": {},  # agent_id -> score
		"interaction_frequency": {},
		"preferred_partners": []
	}
	
	# Connect agent signals
	agent.interaction_requested.connect(_on_agent_interaction_requested)
	agent.dialogue_spoken.connect(_on_agent_dialogue_spoken)
	
	registered_agents[agent_id] = interaction_data
	
	print("[AgentInteractionSystem] Registered agent for interactions: %s" % agent_id)


# ═══════════════════════════════════════════════════════════════════════════
# Public API - Interaction Management
# ═══════════════════════════════════════════════════════════════════════════

func initiate_conversation(initiator_id: String, target_id: String, topic: String = "") -> String:
	"""Start a conversation between two agents"""
	if not registered_agents.has(initiator_id) or not registered_agents.has(target_id):
		return ""
	
	var initiator_data = registered_agents[initiator_id]
	var target_data = registered_agents[target_id]
	
	# Check if either agent is busy
	if _is_agent_busy(initiator_id) or _is_agent_busy(target_id):
		return ""
	
	# Generate conversation ID
	var conversation_id = "conv_%d" % Time.get_unix_time_from_system()
	
	# Create conversation
	var conversation = {
		"id": conversation_id,
		"participants": [initiator_id, target_id],
		"topic": topic,
		"start_time": Time.get_unix_time_from_system(),
		"messages": [],
		"state": "active"
	}
	
	conversations.append(conversation)
	
	# Update agent states
	initiator_data.current_conversation = conversation_id
	target_data.current_conversation = conversation_id
	
	# Send initial greeting
	var greeting = _get_dialogue(initiator_data.agent_type, "greetings")
	_send_message(initiator_id, target_id, greeting)
	
	# Target responds
	await get_tree().create_timer(1.0).timeout
	var response = _get_dialogue(target_data.agent_type, "greetings")
	_send_message(target_id, initiator_id, response)
	
	# Set up conversation timeout
	_setup_conversation_timeout(conversation_id)
	
	conversation_started.emit(conversation_id, [initiator_id, target_id])
	
	return conversation_id


func _setup_conversation_timeout(conversation_id: String) -> void:
	"""Set up timeout for conversation"""
	# Clear any existing timer for this conversation
	if conversation_timers.has(conversation_id):
		var old_timer = conversation_timers[conversation_id]
		if old_timer:
			old_timer.queue_free()
		conversation_timers.erase(conversation_id)
	
	# Create new timeout timer
	var timeout_timer = Timer.new()
	timeout_timer.wait_time = 30.0  # 30 second timeout
	timeout_timer.timeout.connect(func():
		end_conversation(conversation_id)
	)
	add_child(timeout_timer)
	timeout_timer.start()
	
	conversation_timers[conversation_id] = timeout_timer


func end_conversation(conversation_id: String) -> void:
	"""End a conversation"""
	for i in range(conversations.size()):
		var conversation = conversations[i]
		if conversation.id == conversation_id:
			# Update agent states
			for participant_id in conversation.participants:
				if registered_agents.has(participant_id):
					registered_agents[participant_id].current_conversation = ""
			
			# Mark as ended
			conversation.state = "ended"
			conversation.end_time = Time.get_unix_time_from_system()
			
			# Clean up timeout timer
			if conversation_timers.has(conversation_id):
				var timer = conversation_timers[conversation_id]
				if timer:
					timer.queue_free()
				conversation_timers.erase(conversation_id)
			
			conversation_ended.emit(conversation_id)
			break


func offer_help(helper_id: String, target_id: String, task: String) -> bool:
	"""Offer help from one agent to another"""
	if not registered_agents.has(helper_id) or not registered_agents.has(target_id):
		return false
	
	var helper_data = registered_agents[helper_id]
	var target_data = registered_agents[target_id]
	
	# Check cooldowns
	if helper_data.help_cooldown > Time.get_unix_time_from_system():
		return false
	
	# Check if target is busy with a difficult task
	if not _should_offer_help(helper_id, target_id):
		return false
	
	# Offer help
	var help_message = _get_help_offer(helper_data.agent_type, task)
	_send_message(helper_id, target_id, help_message)
	
	# Update cooldown
	helper_data.help_cooldown = Time.get_unix_time_from_system() + 30.0
	
	# Update relationship score
	_update_relationship_score(helper_id, target_id, 0.1)
	
	help_offered.emit(helper_id, target_id, task)
	
	return true


func request_collaboration(requester_id: String, target_id: String) -> bool:
	"""Request collaboration between agents"""
	if not registered_agents.has(requester_id) or not registered_agents.has(target_id):
		return false
	
	var requester_data = registered_agents[requester_id]
	var target_data = registered_agents[target_id]
	
	# Check if both agents are available
	if _is_agent_busy(requester_id) or _is_agent_busy(target_id):
		return false
	
	# Calculate collaboration probability
	var collab_probability = _calculate_collaboration_probability(requester_id, target_id)
	
	if randf() > collab_probability:
		return false
	
	# Send collaboration request
	var collab_message = _get_collaboration_request(requester_data.agent_type)
	_send_message(requester_id, target_id, collab_message)
	
	# Wait for response
	await get_tree().create_timer(1.5).timeout
	var response = _get_collaboration_response(target_data.agent_type)
	_send_message(target_id, requester_id, response)
	
	# Start collaboration if accepted
	if "accept" in response.to_lower():
		_initiate_collaboration_session(requester_id, target_id)
	
	collaboration_requested.emit(requester_id, target_id)
	
	return true


func handle_player_interaction(agent_id: String, interaction_type: String) -> void:
	"""Handle player interaction with agent"""
	if not registered_agents.has(agent_id):
		return
	
	var agent_data = registered_agents[agent_id]
	var agent = agent_data.agent
	
	match interaction_type:
		"click":
			_handle_player_click(agent)
		"task_assign":
			_show_task_assignment_ui(agent)
		"conversation":
			_show_conversation_ui(agent)
		"help":
			_show_help_ui(agent)


# ═══════════════════════════════════════════════════════════════════════════
# Private Methods - Interaction Logic
# ═══════════════════════════════════════════════════════════════════════════

func _send_message(sender_id: String, target_id: String, message: String) -> void:
	"""Send a message between agents"""
	var sender_data = registered_agents[sender_id]
	var sender = sender_data.agent
	
	# Update interaction time
	sender_data.last_interaction = Time.get_unix_time_from_system()
	
	# Make agent speak
	sender.speak(message, 3.0)
	
	# Record in conversation if active
	var conversation_id = sender_data.current_conversation
	if conversation_id != "":
		for conversation in conversations:
			if conversation.id == conversation_id:
				conversation.messages.append({
					"sender": sender_id,
					"target": target_id,
					"message": message,
					"timestamp": Time.get_unix_time_from_system()
				})
				break
	
	# Record in history
	interaction_history.append({
		"type": "message",
		"sender": sender_id,
		"target": target_id,
		"message": message,
		"timestamp": Time.get_unix_time_from_system()
	})
	
	agent_spoke.emit(sender_id, message, target_id)


func _get_dialogue(agent_type: String, context: String) -> String:
	"""Get contextual dialogue for agent type"""
	var context_dialogues = dialogue_patterns.get(context, {})
	var agent_dialogues = context_dialogues.get(agent_type, ["Working on it..."])
	
	return agent_dialogues[randi() % agent_dialogues.size()]


func _get_help_offer(agent_type: String, task: String) -> String:
	"""Get help offer dialogue"""
	var offers = dialogue_patterns.get("help_offer", {}).get(agent_type, ["Can I help?"])
	var base_offer = offers[randi() % offers.size()]
	
	# Add task context if provided
	if task != "":
		return "%s with %s" % [base_offer, task]
	
	return base_offer


func _get_collaboration_request(agent_type: String) -> String:
	"""Get collaboration request dialogue"""
	return dialogue_patterns.get("collaboration", {}).get(agent_type, ["Want to collaborate?"])


func _get_collaboration_response(agent_type: String) -> String:
	"""Get collaboration response dialogue"""
	var responses = {
		"aider": ["Sure, let's coordinate.", "I can help with that.", "Sounds good."],
		"opencode": ["Absolutely! Let's do this!", "Yes! This will be awesome!", "I'm in!"],
		"claude": ["I'd be happy to collaborate.", "That sounds like a great idea.", "Let's discuss the approach."]
	}
	
	var agent_responses = responses.get(agent_type, ["Sure!"])
	return agent_responses[randi() % agent_responses.size()]


func _is_agent_busy(agent_id: String) -> bool:
	"""Check if agent is busy"""
	if not registered_agents.has(agent_id):
		return true
	
	var agent_data = registered_agents[agent_id]
	var agent = agent_data.agent
	
	return agent.state in [AgentEntity.AgentState.CODING, AgentEntity.AgentState.THINKING]


func _should_offer_help(helper_id: String, target_id: String) -> bool:
	"""Determine if agent should offer help"""
	var helper_data = registered_agents[helper_id]
	var target_data = registered_agents[target_id]
	var target_agent = target_data.agent
	
	# Only offer to agents that are coding/thinking
	if target_agent.state not in [AgentEntity.AgentState.CODING, AgentEntity.AgentState.THINKING]:
		return false
	
	# Check personality traits
	var friendliness = helper_data.personality.get("friendliness", 0.5)
	var help_probability = friendliness * 0.3  # Base 30% modified by friendliness
	
	# Consider relationship score
	var relationship_score = helper_data.relationship_scores.get(target_id, 0.0)
	help_probability += relationship_score * 0.2
	
	return randf() < help_probability


func _calculate_collaboration_probability(requester_id: String, target_id: String) -> float:
	"""Calculate probability of collaboration acceptance"""
	var requester_data = registered_agents[requester_id]
	var target_data = registered_agents[target_id]
	
	# Base probability from personalities
	var base_prob = (
		requester_data.personality.get("collaboration", 0.5) +
		target_data.personality.get("collaboration", 0.5)
	) / 2.0
	
	# Modify by relationship score
	var relationship = target_data.relationship_scores.get(requester_id, 0.0)
	base_prob += relationship * 0.3
	
	# Different agent types collaborate better
	if requester_data.agent_type != target_data.agent_type:
		base_prob += 0.1
	
	return clamp(base_prob, 0.0, 1.0)


func _initiate_collaboration_session(agent1_id: String, agent2_id: String) -> void:
	"""Start a collaboration session"""
	var agent1 = registered_agents[agent1_id].agent
	var agent2 = registered_agents[agent2_id].agent
	
	# Set both agents to collaborating state
	agent1.collaborate_with(agent2)
	agent2.collaborate_with(agent1)
	
	# Start collaboration conversation
	var conversation_id = initiate_conversation(agent1_id, agent2_id, "collaboration")
	
	# Update relationship scores
	_update_relationship_score(agent1_id, agent2_id, 0.2)
	_update_relationship_score(agent2_id, agent1_id, 0.2)


func _update_relationship_score(agent1_id: String, agent2_id: String, delta: float) -> void:
	"""Update relationship score between agents"""
	if not registered_agents.has(agent1_id):
		return
	
	var agent1_data = registered_agents[agent1_id]
	var current_score = agent1_data.relationship_scores.get(agent2_id, 0.0)
	var new_score = clamp(current_score + delta, -1.0, 1.0)
	agent1_data.relationship_scores[agent2_id] = new_score


# ═══════════════════════════════════════════════════════════════════════════
# Private Methods - UI Management
# ═══════════════════════════════════════════════════════════════════════════

func _create_interaction_ui() -> void:
	"""Create interaction UI elements"""
	interaction_ui = Control.new()
	interaction_ui.name = "InteractionUI"
	interaction_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(interaction_ui)
	
	# UI will be populated as needed


func _handle_player_click(agent: AgentEntity) -> void:
	"""Handle player clicking on agent"""
	agent.speak("Click me again to assign a task!", 2.0)
	
	# Show simple interaction menu
	_show_interaction_menu(agent)


func _show_interaction_menu(agent: AgentEntity) -> void:
	"""Show interaction menu for agent"""
	# Create simple popup menu
	var menu = PopupPanel.new()
	interaction_ui.add_child(menu)
	
	var vbox = VBoxContainer.new()
	menu.add_child(vbox)
	
	# Add menu options
	var assign_btn = Button.new()
	assign_btn.text = "Assign Task"
	assign_btn.pressed.connect(_show_task_assignment_ui.bind(agent))
	vbox.add_child(assign_btn)
	
	var chat_btn = Button.new()
	chat_btn.text = "Chat"
	chat_btn.pressed.connect(_show_conversation_ui.bind(agent))
	vbox.add_child(chat_btn)
	
	var help_btn = Button.new()
	help_btn.text = "Request Help"
	help_btn.pressed.connect(_show_help_ui.bind(agent))
	vbox.add_child(help_btn)
	
	# Show menu
	menu.position = get_viewport().get_mouse_position()
	menu.popup()


func _show_task_assignment_ui(agent: AgentEntity) -> void:
	"""Show task assignment interface"""
	# Create task assignment dialog
	var dialog = AcceptDialog.new()
	dialog.title = "Assign Task to " + agent.agent_id
	interaction_ui.add_child(dialog)
	
	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)
	
	var label = Label.new()
	label.text = "Enter task description:"
	vbox.add_child(label)
	
	var text_edit = LineEdit.new()
	text_edit.placeholder_text = "e.g., Fix the bug in player movement"
	vbox.add_child(text_edit)
	
	# Add task assignment logic
	dialog.confirmed.connect(func():
		var task = text_edit.text.strip_edges()
		if task != "":
			agent.assign_task(task)
		dialog.queue_free()
	)
	
	dialog.popup_centered()


func _show_conversation_ui(agent: AgentEntity) -> void:
	"""Show conversation interface"""
	# Create conversation dialog
	var dialog = AcceptDialog.new()
	dialog.title = "Chat with " + agent.agent_id
	interaction_ui.add_child(dialog)
	
	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)
	
	var label = Label.new()
	label.text = "What would you like to discuss?"
	vbox.add_child(label)
	
	var options = ["Project status", "Code review", "General chat"]
	var option_buttons: Array[Button] = []
	
	for option in options:
		var btn = Button.new()
		btn.text = option
		btn.pressed.connect(func():
			agent.speak("Let's talk about %s!" % option.to_lower(), 3.0)
			dialog.queue_free()
		)
		vbox.add_child(btn)
	
	dialog.popup_centered()


func _show_help_ui(agent: AgentEntity) -> void:
	"""Show help request interface"""
	agent.speak("I'm here to help! What do you need?", 3.0)
	
	# Find an idle agent to help
	var registry = get_node_or_null("../AgentRegistry")
	if registry:
		var idle_agents = registry.get_idle_agents()
		for other_agent in idle_agents:
			if other_agent != agent:
				agent.collaborate_with(other_agent)
				break


func _process_interactions() -> void:
	"""Process automatic interactions between agents"""
	for agent_id in registered_agents.keys():
		var agent_data = registered_agents[agent_id]
		
		# Process cooldowns
		if agent_data.dialogue_cooldown < Time.get_unix_time_from_system():
			_process_autonomous_interaction(agent_id)


func _process_autonomous_interaction(agent_id: String) -> void:
	"""Process autonomous interactions for an agent"""
	var agent_data = registered_agents[agent_id]
	var agent = agent_data.agent
	
	# Only interact if idle and not in conversation
	if agent.state != AgentEntity.AgentState.IDLE or agent_data.current_conversation != "":
		return
	
	# Check for help opportunities
	var other_agents = registered_agents.keys()
	for other_id in other_agents:
		if other_id == agent_id:
			continue
		
		if offer_help(agent_id, other_id, "current task"):
			return
	
	# Check for collaboration opportunities
	if randf() < 0.1:  # 10% chance per cycle
		var target_id = _find_collaboration_partner(agent_id)
		if target_id != "":
			request_collaboration(agent_id, target_id)


func _find_collaboration_partner(agent_id: String) -> String:
	"""Find best collaboration partner for agent"""
	var best_partner = ""
	var best_score = 0.0
	
	var agent_data = registered_agents[agent_id]
	
	for other_id in registered_agents.keys():
		if other_id == agent_id:
			continue
		
		var other_data = registered_agents[other_id]
		var other_agent = other_data.agent
		
		# Only consider idle agents
		if other_agent.state != AgentEntity.AgentState.IDLE:
			continue
		
		# Calculate compatibility score
		var score = _calculate_collaboration_probability(agent_id, other_id)
		if score > best_score:
			best_score = score
			best_partner = other_id
	
	return best_partner


# ═══════════════════════════════════════════════════════════════════════════
# Signal Handlers
# ═══════════════════════════════════════════════════════════════════════════

func _on_agent_interaction_requested(agent_id: String) -> void:
	"""Handle agent interaction request"""
	_show_interaction_menu(registered_agents[agent_id].agent)


func _on_agent_dialogue_spoken(agent_id: String, text: String) -> void:
	"""Handle agent dialogue"""
	# Record dialogue in history
	interaction_history.append({
		"type": "dialogue",
		"agent": agent_id,
		"text": text,
		"timestamp": Time.get_unix_time_from_system()
	})


func remove_agent(agent_id: String) -> void:
	"""Remove agent from interaction system"""
	if not registered_agents.has(agent_id):
		return
	
	var agent_data = registered_agents[agent_id]
	
	# End any active conversations
	if agent_data.current_conversation != "":
		end_conversation(agent_data.current_conversation)
	
	# Remove from registry
	registered_agents.erase(agent_id)
	
	print("[AgentInteractionSystem] Removed agent from interactions: %s" % agent_id)