# res://src/tests/cases/test_weather_tier1.gd
extends "res://src/tests/base_test_case.gd"

# Tier 1 Weather Cycles E2E Tests
# Technical comments in English, Vietnamese for game logic explanations.

func test_initial_state() -> void:
	var wm := world_instance.get_node_or_null("WorldManager") as WorldManager
	assert_not_null(wm, "WorldManager should exist")
	assert_eq(wm.weather_state, "clear", "Initial weather state must be clear")
	assert_almost_eq(wm.weather_timer, 300.0, 0.5, "Initial weather timer must be 300.0 seconds")
	assert_false(wm.is_raining, "Should not be raining initially")
	assert_true(wm.rain_particles == null, "Rain particles should be null initially")

func test_clear_to_rain() -> void:
	var wm := world_instance.get_node_or_null("WorldManager") as WorldManager
	assert_not_null(wm, "WorldManager should exist")
	
	# Force timer to expire to trigger transition
	wm.weather_timer = 0.0
	await tree.process_frame
	await tree.process_frame
	
	assert_eq(wm.weather_state, "rain", "Weather state should transition to rain")
	assert_true(wm.is_raining, "is_raining should be true during rain")
	assert_not_null(wm.rain_particles, "Rain particles node should be spawned")
	assert_true(wm.rain_particles.emitting, "Rain particles should be emitting")
	assert_eq(wm.rain_cycle_count, 1, "Rain cycle count should increment to 1")
	var process_material := wm.rain_particles.process_material as ParticleProcessMaterial
	assert_not_null(process_material, "Rain must use a particle process material")
	assert_eq(process_material.emission_shape, ParticleProcessMaterial.EMISSION_SHAPE_BOX, "Rain should emit across a volume, not from one point")
	assert_false(wm.rain_particles.local_coords, "Existing drops should remain in world space while the emitter follows the camera")

func test_rain_volume_follows_and_covers_camera() -> void:
	var wm := world_instance.get_node_or_null("WorldManager") as WorldManager
	var camera_rig := tree.get_first_node_in_group("camera") as GameCamera
	assert_not_null(wm, "WorldManager should exist")
	assert_not_null(camera_rig, "GameCamera should exist")

	wm._start_rain()
	camera_rig.set_process(false)
	camera_rig.global_position = Vector3(17.0, 2.0, -13.0)
	camera_rig.camera.size = 25.0
	wm._update_rain_coverage()

	assert_almost_eq(wm.rain_particles.global_position.x, 17.0, 0.01, "Rain emitter should follow camera X")
	assert_almost_eq(wm.rain_particles.global_position.z, -13.0, 0.01, "Rain emitter should follow camera Z")
	var process_material := wm.rain_particles.process_material as ParticleProcessMaterial
	var viewport_size := wm.get_viewport().get_visible_rect().size
	var aspect_ratio := viewport_size.x / maxf(viewport_size.y, 1.0)
	assert_true(process_material.emission_box_extents.x >= camera_rig.camera.size * aspect_ratio * 0.5, "Rain width should cover the zoomed viewport")
	assert_true(wm.rain_particles.visibility_aabb.size.x > process_material.emission_box_extents.x * 2.0, "Rain culling bounds should contain the full emission volume")
	assert_true(wm.rain_particles.visibility_aabb.size.z > process_material.emission_box_extents.z * 2.0, "Rain culling bounds should contain falling streaks at screen depth")

func test_rain_to_clear() -> void:
	var wm := world_instance.get_node_or_null("WorldManager") as WorldManager
	assert_not_null(wm, "WorldManager should exist")
	
	# Transition to rain first
	wm.weather_timer = 0.0
	await tree.process_frame
	await tree.process_frame
	
	# Now force rain duration to end
	wm.weather_duration = 0.0
	await tree.process_frame
	await tree.process_frame
	
	assert_eq(wm.weather_state, "clear", "Weather state should return to clear")
	assert_false(wm.is_raining, "is_raining should be false after rain ends")
	assert_almost_eq(wm.weather_timer, 300.0, 0.5, "Weather timer should reset to 300.0 seconds")
	assert_true(wm.rain_particles == null or not wm.rain_particles.emitting, "Rain particles should stop emitting")

func test_storm_progression() -> void:
	var wm := world_instance.get_node_or_null("WorldManager") as WorldManager
	assert_not_null(wm, "WorldManager should exist")
	
	# Cycle 1: Clear -> Rain -> Clear
	wm.weather_timer = 0.0
	await tree.process_frame; await tree.process_frame
	assert_eq(wm.weather_state, "rain", "Cycle 1 starts rain")
	wm.weather_duration = 0.0
	await tree.process_frame; await tree.process_frame
	
	# Cycle 2: Clear -> Rain -> Clear
	wm.weather_timer = 0.0
	await tree.process_frame; await tree.process_frame
	assert_eq(wm.weather_state, "rain", "Cycle 2 starts rain")
	wm.weather_duration = 0.0
	await tree.process_frame; await tree.process_frame
	
	# Cycle 3: Clear -> Storm
	wm.weather_timer = 0.0
	await tree.process_frame; await tree.process_frame
	assert_eq(wm.weather_state, "storm", "Cycle 3 must trigger a storm")
	assert_eq(wm.rain_cycle_count, 0, "rain_cycle_count should reset to 0 in storm state")
	assert_almost_eq(wm.weather_duration, 60.0, 0.5, "Storm duration should be 60.0 seconds")

func test_lightning_damage_radius() -> void:
	var wm := world_instance.get_node_or_null("WorldManager") as WorldManager
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(wm, "WorldManager should exist")
	assert_not_null(player, "Player should exist")
	
	# Place player at center and seed RNG for deterministic strike
	player.global_position = Vector3(0.0, 0.0, 0.0)
	
	# We set seed and calculate where the strike will fall
	seed(999)
	var expected_x := randf_range(-45.0, 45.0)
	var expected_z := randf_range(-45.0, 45.0)
	var strike_pos := Vector3(expected_x, 0.0, expected_z)
	
	# Position player exactly at the expected strike position
	player.global_position = strike_pos
	
	# Reset the seed so the actual _strike_lightning generates the exact same position
	seed(999)
	wm._strike_lightning()
	await tree.process_frame
	
	# Lightning deals 20 damage directly to player via player._on_damaged
	# This sets anim_state to HURT
	assert_eq(player.anim_state, Player.AnimState.HURT, "Player should be in HURT state after lightning strike")
