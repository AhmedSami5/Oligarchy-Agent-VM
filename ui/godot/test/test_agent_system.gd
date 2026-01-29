# ═══════════════════════════════════════════════════════════════════════════
# test_agent_system.gd - Comprehensive Test Suite for Agent Management System
# ═══════════════════════════════════════════════════════════════════════════
# Place this file in: addons/agentvm/test/test_agent_system.gd

extends "res://addons/gut/test.gd"

## Test suite for the Agent Management System
## Requires the GUT (Godot Unit Test) plugin

# Test dependencies
const AgentRegistry = preload("res://addons/agentvm/systems/agent_registry.gd")
const AgentEntity = preload("res://addons/agentvm/entities/agent_entity.gd")
const AgentVMManagerExtended = preload("res://addons/agentvm/core/agent_manager_extended.gd")


# ═══════════════════════════════════════════════════════════════════════════
# AgentRegistry Tests
# ═══════════════════════════════════════════════════════════════════════════

func test_agent_registry_spawn_and_despawn():
	"""Test agent spawning and despawning lifecycle"""
	var registry = AgentRegistry.new()
	add_child(registry)
	
	# Test spawn
	var agent_id = registry.spawn_agent("aider")
	assert_not_eq(agent_id, "", "Agent spawn should return valid ID")
	assert_true(registry.active_agents.has(agent_id), "Agent should be registered")
	
	# Test get agent
	var agent = registry.get_agent(agent_id)
	assert_not_null(agent, "Agent should be retrievable")
	assert_eq(agent.agent_type, "aider", "Agent type should match")
	
	# Test despawn
	var despawn_result = registry.despawn_agent(agent_id)
	assert_true(despawn_result, "Despawn should succeed")
	assert_false(registry.active_agents.has(agent_id), "Agent should be unregistered")


func test_agent_registry_invalid_types():
	"""Test handling of invalid agent types"""
	var registry = AgentRegistry.new()
	add_child(registry)
	
	# Test invalid type
	var agent_id = registry.spawn_agent("invalid_type")
	assert_eq(agent_id, "", "Invalid type should return empty ID")
	
	# Test case sensitivity
	agent_id = registry.spawn_agent("AIDER")  # Should fail - case sensitive
	assert_eq(agent_id, "", "Invalid case should return empty ID")


func test_agent_registry_task_assignment():
	"""Test task assignment to agents"""
	var registry = AgentRegistry.new()
	add_child(registry)
	
	# Spawn agent
	var agent_id = registry.spawn_agent("aider")
	assert_not_eq(agent_id, "", "Agent spawn should succeed")
	
	# Assign task
	var task_result = registry.assign_task_to_agent(agent_id, "Test task")
	assert_true(task_result, "Task assignment should succeed")
	
	# Verify task is assigned
	var agent = registry.get_agent(agent_id)
	assert_eq(agent.current_task, "Test task", "Task should be assigned to agent")


func test_agent_registry_collaboration():
	"""Test collaborative task assignment"""
	var registry = AgentRegistry.new()
	add_child(registry)
	
	# Spawn multiple agents
	var agent1_id = registry.spawn_agent("aider")
	var agent2_id = registry.spawn_agent("opencode")
	assert_not_eq(agent1_id, "", "First agent spawn should succeed")
	assert_not_eq(agent2_id, "", "Second agent spawn should succeed")
	
	# Assign collaborative task
	var team = registry.assign_collaborative_task("Collaborative task", 2)
	assert_eq(team.size(), 2, "Should assign to 2 agents")
	assert_true(team.has(agent1_id), "First agent should be in team")
	assert_true(team.has(agent2_id), "Second agent should be in team")


# ═══════════════════════════════════════════════════════════════════════════
# AgentEntity Tests
# ═══════════════════════════════════════════════════════════════════════════

func test_agent_entity_initialization():
	"""Test agent entity initialization"""
	var agent = AgentEntity.new()
	add_child(agent)
	
	# Create mock manager
	var mock_manager = Node.new()
	add_child(mock_manager)
	
	# Initialize agent
	agent.initialize("test_agent_1", "aider", mock_manager, Vector3(1, 2, 3))
	
	assert_eq(agent.agent_id, "test_agent_1", "Agent ID should be set")
	assert_eq(agent.agent_type, "aider", "Agent type should be set")
	assert_eq(agent.global_position, Vector3(1, 2, 3), "Position should be set")
	assert_eq(agent.workspace_position, Vector3(1, 2, 3), "Workspace position should be set")


func test_agent_entity_state_management():
	"""Test agent state transitions"""
	var agent = AgentEntity.new()
	add_child(agent)
	
	# Initialize agent
	var mock_manager = Node.new()
	add_child(mock_manager)
	agent.initialize("test_agent_2", "aider", mock_manager)
	
	# Test state changes
	agent.set_state(AgentEntity.AgentState.CODING)
	assert_eq(agent.state, AgentEntity.AgentState.CODING, "State should change to CODING")
	
	agent.set_state(AgentEntity.AgentState.THINKING)
	assert_eq(agent.state, AgentEntity.AgentState.THINKING, "State should change to THINKING")
	
	agent.set_state(AgentEntity.AgentState.IDLE)
	assert_eq(agent.state, AgentEntity.AgentState.IDLE, "State should change to IDLE")


func test_agent_entity_task_assignment():
	"""Test agent task assignment"""
	var agent = AgentEntity.new()
	add_child(agent)
	
	# Create mock manager with task assignment capability
	var mock_manager = Node.new()
	add_child(mock_manager)
	mock_manager.run_agent = func(prompt, agent_type): return "test_task_123"
	
	agent.initialize("test_agent_3", "aider", mock_manager)
	
	# Assign task
	agent.assign_task("Test coding task")
	
	assert_eq(agent.current_task, "Test coding task", "Task should be assigned")
	assert_eq(agent.state, AgentEntity.AgentState.THINKING, "Agent should enter THINKING state")


# ═══════════════════════════════════════════════════════════════════════════
# AgentVMManagerExtended Tests
# ═══════════════════════════════════════════════════════════════════════════

func test_extended_manager_spawn_and_workspace():
	"""Test agent spawning and workspace assignment"""
	var manager = AgentVMManagerExtended.new()
	add_child(manager)
	
	# Test agent spawning
	var agent_id = manager.spawn_game_agent("aider")
	assert_not_eq(agent_id, "", "Agent spawn should succeed")
	
	# Test workspace creation
	var workspace_id = "test_workspace_1"
	var workspace = manager.create_workspace(workspace_id)
	assert_not_null(workspace, "Workspace should be created")
	
	# Test agent to workspace assignment
	var assignment_result = manager.assign_agent_to_workspace(agent_id, workspace_id)
	assert_true(assignment_result, "Agent should be assigned to workspace")


func test_extended_manager_task_assignment():
	"""Test task assignment through extended manager"""
	var manager = AgentVMManagerExtended.new()
	add_child(manager)
	
	# Spawn agent
	var agent_id = manager.spawn_game_agent("aider")
	assert_not_eq(agent_id, "", "Agent spawn should succeed")
	
	# Assign task
	var task_result = manager.assign_game_task(agent_id, "Test task through manager")
	assert_true(task_result, "Task assignment should succeed")


func test_extended_manager_invalid_inputs():
	"""Test handling of invalid inputs"""
	var manager = AgentVMManagerExtended.new()
	add_child(manager)
	
	# Test empty task assignment
	var result = manager.assign_game_task("nonexistent_agent", "")
	assert_false(result, "Empty task should fail")
	
	# Test long task assignment
	var long_task = "Very long task " * 50  # 750 characters
	result = manager.assign_game_task("nonexistent_agent", long_task)
	assert_false(result, "Long task should fail")


# ═══════════════════════════════════════════════════════════════════════════
# Integration Tests
# ═══════════════════════════════════════════════════════════════════════════

func test_full_agent_lifecycle():
	"""Test complete agent lifecycle from spawn to task completion"""
	var manager = AgentVMManagerExtended.new()
	add_child(manager)
	
	# Track events
	var events = []
	manager.game_agent_spawned.connect(func(agent_id, agent): events.append("spawned:%s" % agent_id))
	manager.game_task_completed.connect(func(agent_id, result): events.append("completed:%s" % agent_id))
	
	# Spawn agent
	var agent_id = manager.spawn_game_agent("aider")
	assert_not_eq(agent_id, "", "Agent spawn should succeed")
	
	# Assign task
	var task_result = manager.assign_game_task(agent_id, "Complete lifecycle test")
	assert_true(task_result, "Task assignment should succeed")
	
	# Simulate task completion (normally done by base manager)
	manager._on_base_task_completed("task_123", "Task completed successfully")
	
	# Verify events
	assert_eq(events.size(), 2, "Should have 2 events")
	assert_true(events[0].begins_with("spawned:"), "First event should be spawn")
	assert_true(events[1].begins_with("completed:"), "Second event should be completion")


func test_agent_collaboration_workflow():
	"""Test collaborative workflow between agents"""
	var manager = AgentVMManagerExtended.new()
	add_child(manager)
	
	# Spawn multiple agents
	var agent1_id = manager.spawn_game_agent("aider")
	var agent2_id = manager.spawn_game_agent("opencode")
	assert_not_eq(agent1_id, "", "First agent spawn should succeed")
	assert_not_eq(agent2_id, "", "Second agent spawn should succeed")
	
	# Assign collaborative task
	var team = manager.assign_collaborative_task("Collaborative test", 2)
	assert_eq(team.size(), 2, "Should assign to 2 agents")
	assert_true(team.has(agent1_id), "First agent should be in team")
	assert_true(team.has(agent2_id), "Second agent should be in team")


# ═══════════════════════════════════════════════════════════════════════════
# Performance Tests
# ═══════════════════════════════════════════════════════════════════════════

func test_performance_multiple_agents():
	"""Test performance with multiple agents"""
	var manager = AgentVMManagerExtended.new()
	add_child(manager)
	
	# Measure time
	var start_time = Time.get_ticks_usec()
	
	# Spawn multiple agents
	var agent_ids = []
	for i in range(10):  # Test with 10 agents
		var agent_id = manager.spawn_game_agent("aider")
		agent_ids.append(agent_id)
	
	var end_time = Time.get_ticks_usec()
	var spawn_time = (end_time - start_time) / 1000.0  # Convert to ms
	
	print("Spawned 10 agents in %s ms" % spawn_time)
	assert_true(spawn_time < 500, "Spawning 10 agents should take less than 500ms")
	
	# Clean up
	for agent_id in agent_ids:
		manager.despawn_game_agent(agent_id)


func test_performance_task_assignment():
	"""Test performance of task assignment"""
	var manager = AgentVMManagerExtended.new()
	add_child(manager)
	
	# Spawn agents
	var agent_ids = []
	for i in range(5):
		var agent_id = manager.spawn_game_agent("aider")
		agent_ids.append(agent_id)
	
	# Measure task assignment time
	var start_time = Time.get_ticks_usec()
	
	for agent_id in agent_ids:
		manager.assign_game_task(agent_id, "Performance test task")
	
	var end_time = Time.get_ticks_usec()
	var assignment_time = (end_time - start_time) / 1000.0  # Convert to ms
	
	print("Assigned tasks to 5 agents in %s ms" % assignment_time)
	assert_true(assignment_time < 200, "Assigning to 5 agents should take less than 200ms")
	
	# Clean up
	for agent_id in agent_ids:
		manager.despawn_game_agent(agent_id)