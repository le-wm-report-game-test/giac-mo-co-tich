# proposed_test_weather_tier2.gd
extends "res://src/tests/base_test_case.gd"

# Tier 2 Weather Cycles E2E Tests (Boundary & Edge Cases)
# Technical comments in English, Vietnamese for game logic explanations.

func run() -> void:
	await test_weather_during_player_death()
	await reset_world()
	await test_lightning_just_outside_radius()
	await reset_world()
	await test_lightning_just_inside_radius()
	await reset_world()
	await test_rapid_weather_forcing()
	await reset_world()
	await test_missing_components_resilience()

func reset_world() -> void:
	await teardown()
	await setup()

func test_weather_during_player_death() -> void:
	var wm := world_instance.get_node_or_null("WorldManager") as WorldManager
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(wm, "WorldManager should exist")
	assert_not_null(player, "Player should exist")
	
	# Kill player
	player.health_component.take_damage(100.0, null)
	await tree.process_frame
	assert_eq(player.anim_state, Player.AnimState.DEATH, "Player must be in DEATH state")
	
	# Trigger weather change
	wm.weather_timer = 0.0
	await tree.process_frame
	await tree.process_frame
	
	# Verify weather state changed, but player remains dead
	assert_eq(wm.weather_state, "rain", "Weather should transition to rain")
	assert_eq(player.anim_state, Player.AnimState.DEATH, "Player must remain in DEATH state unaffected by weather")

func test_lightning_just_outside_radius() -> void:
	var wm := world_instance.get_node_or_null("WorldManager") as WorldManager
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(wm, "WorldManager should exist")
	assert_not_null(player, "Player should exist")
	
	seed(999)
	var expected_x := randf_range(-45.0, 45.0)
	var expected_z := randf_range(-45.0, 45.0)
	var strike_pos := Vector3(expected_x, 0.0, expected_z)
	
	# Position player just outside damage radius (5.01 meters away)
	player.global_position = strike_pos + Vector3(5.01, 0.0, 0.0)
	
	seed(999)
	wm._strike_lightning()
	await tree.process_frame
	
	# Player should not take damage
	assert_eq(player.anim_state, Player.AnimState.IDLE, "Player should remain IDLE when just outside lightning range")

func test_lightning_just_inside_radius() -> void:
	var wm := world_instance.get_node_or_null("WorldManager") as WorldManager
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(wm, "WorldManager should exist")
	assert_not_null(player, "Player should exist")
	
	seed(999)
	var expected_x := randf_range(-45.0, 45.0)
	var expected_z := randf_range(-45.0, 45.0)
	var strike_pos := Vector3(expected_x, 0.0, expected_z)
	
	# Position player just inside damage radius (4.99 meters away)
	player.global_position = strike_pos + Vector3(4.99, 0.0, 0.0)
	
	seed(999)
	wm._strike_lightning()
	await tree.process_frame
	
	# Player should take damage
	assert_eq(player.anim_state, Player.AnimState.HURT, "Player should enter HURT state when just inside lightning range")

func test_rapid_weather_forcing() -> void:
	var wm := world_instance.get_node_or_null("WorldManager") as WorldManager
	assert_not_null(wm, "WorldManager should exist")
	
	# Trigger start and end rain multiple times in the same frame
	wm._start_rain()
	wm._end_rain()
	wm._start_rain()
	wm._end_rain()
	wm._start_rain() # Cycles = 3, state -> storm
	
	await tree.process_frame
	await tree.process_frame
	
	# State machine should settle on storm correctly
	assert_eq(wm.weather_state, "storm", "Rapid state forcing should settle on the latest valid state")
	assert_not_null(wm.rain_particles, "Particles should be active")

func test_missing_components_resilience() -> void:
	var wm := world_instance.get_node_or_null("WorldManager") as WorldManager
	assert_not_null(wm, "WorldManager should exist")
	
	# Remove WorldEnvironment and DirectionalLight3D from tree
	var env := world_instance.get_node_or_null("WorldEnvironment")
	if env:
		env.queue_free()
	var sun := world_instance.get_node_or_null("DirectionalLight3D")
	if sun:
		sun.queue_free()
		
	await tree.process_frame
	
	# Trigger weather change - should not crash
	wm._start_rain()
	await tree.process_frame
	
	assert_eq(wm.weather_state, "rain", "Weather state transitions to rain even with missing lighting nodes")
	wm._end_rain()
	await tree.process_frame
	assert_eq(wm.weather_state, "clear", "Weather transitions back to clear safely without crashing")
