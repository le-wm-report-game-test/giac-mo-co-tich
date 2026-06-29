extends "res://src/tests/base_test_case.gd"

# Kiểm thử intro camera đầu game: focus nhân vật rồi zoom ra map.

func test_startup_camera_starts_on_player_without_origin_jump() -> void:
	var player := tree.get_first_node_in_group("player") as Player
	var camera := tree.get_first_node_in_group("camera") as GameCamera
	assert_not_null(player, "Player should exist")
	assert_not_null(camera, "GameCamera should exist")
	if player == null or camera == null:
		return
	assert_true(camera.startup_intro_active, "Startup intro should run for a new game")
	assert_almost_eq(camera.global_position.x, player.global_position.x, 0.01, "Camera anchor should start at player X")
	assert_almost_eq(camera.global_position.z, player.global_position.z, 0.01, "Camera anchor should start at player Z")
	assert_eq(camera.camera.size, camera.startup_close_camera_size, "Startup intro should begin at close zoom")
	assert_true(player.input_locked, "Player input should be locked during startup intro")

func test_startup_camera_zoom_out_unlocks_player() -> void:
	var player := tree.get_first_node_in_group("player") as Player
	var camera := tree.get_first_node_in_group("camera") as GameCamera
	assert_not_null(player, "Player should exist")
	assert_not_null(camera, "GameCamera should exist")
	if player == null or camera == null:
		return
	camera.startup_close_hold_time = 0.0
	camera.startup_zoom_out_duration = 0.05
	camera.play_startup_intro(player)
	assert_true(player.input_locked, "Player input should lock while replayed intro runs")
	for i in range(10):
		await tree.process_frame
	assert_false(camera.startup_intro_active, "Startup intro should finish after zoom out")
	assert_true(camera.startup_intro_finished, "Startup intro should mark itself finished")
	assert_false(player.input_locked, "Player input should unlock after startup intro")
	assert_almost_eq(camera.camera.size, camera.normal_camera_size, 0.01, "Camera should end at normal map zoom")

func test_restore_skips_startup_camera_intro() -> void:
	if is_instance_valid(world_instance):
		world_instance.queue_free()
		world_instance = null
		await wait_physics_frames(2)

	var restore_pos := Vector3(12.0, 1.0, -8.0)
	SaveManager.set_meta("pending_restore", {
		"position": restore_pos,
		"health": 80.0,
		"max_health": 100.0,
		"orcs_killed": 2,
		"boss_spawned": false,
		"weather_state": "clear",
	})
	await super.setup()

	var player := tree.get_first_node_in_group("player") as Player
	var camera := tree.get_first_node_in_group("camera") as GameCamera
	assert_not_null(player, "Restored Player should exist")
	assert_not_null(camera, "Restored GameCamera should exist")
	if player == null or camera == null:
		return
	assert_false(camera.startup_intro_active, "Restore should skip startup intro")
	assert_true(camera.startup_intro_finished, "Restore should leave camera in finished startup state")
	assert_false(player.input_locked, "Restore should not leave player input locked")
	assert_almost_eq(player.global_position.x, restore_pos.x, 0.01, "Player restore X should apply")
	assert_almost_eq(player.global_position.z, restore_pos.z, 0.01, "Player restore Z should apply")
	assert_almost_eq(camera.global_position.x, restore_pos.x, 0.01, "Camera should snap to restored player X")
	assert_almost_eq(camera.global_position.z, restore_pos.z, 0.01, "Camera should snap to restored player Z")
