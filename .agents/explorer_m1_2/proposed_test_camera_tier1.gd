# proposed_test_camera_tier1.gd
extends "res://src/tests/base_test_case.gd"

# Tier 1 Camera Clipping & Magnet E2E Tests
# Technical comments in English, Vietnamese for game logic explanations.

var test_tree: Node3D = null

func run() -> void:
	await test_camera_follows_player()
	await reset_world()
	await test_camera_clipping_active()
	await reset_world()
	await test_camera_clipping_inactive()
	await reset_world()
	await test_camera_magnet_activation()
	await reset_world()
	await test_camera_magnet_restoration()

func reset_world() -> void:
	await teardown()
	await setup()

func setup_tree_test() -> void:
	var wm := world_instance.get_node_or_null("WorldManager") as WorldManager
	assert_not_null(wm, "WorldManager should exist")
	
	test_tree = Node3D.new()
	test_tree.name = "Pine_TestTree"
	test_tree.global_position = Vector3(10.0, 0.0, 10.0)
	
	var mesh_inst := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mesh_inst.material_override = mat
	test_tree.add_child(mesh_inst)
	
	world_instance.add_child(test_tree)
	wm._collect_trees()

func test_camera_follows_player() -> void:
	var player := tree.get_first_node_in_group("player") as Player
	var camera := tree.get_first_node_in_group("camera") as GameCamera
	assert_not_null(player, "Player should exist")
	assert_not_null(camera, "Camera should exist")
	
	# Position player at central coordinates
	player.global_position = Vector3(5.0, 0.0, 5.0)
	
	# Process multiple frames to let the camera follow-lerp catch up
	for i in range(30):
		await tree.process_frame
		
	# Verify that camera position has moved close to player position
	var dist := camera.global_position.distance_to(player.global_position)
	assert_true(dist < 0.2, "Camera should lerp close to player's global position")

func test_camera_clipping_active() -> void:
	await setup_tree_test()
	var camera := tree.get_first_node_in_group("camera") as GameCamera
	assert_not_null(camera, "Camera should exist")
	
	# Target distance = 1.4m (< 1.5m threshold)
	# Viewport Camera3D needs to be at tree.global_position + Vector3(1.4, 0.0, 0.0)
	camera.target = null
	var target_cam_pos := test_tree.global_position + Vector3(1.4, 0.0, 0.0)
	camera.global_position = target_cam_pos - camera.camera_offset
	camera.target_position = camera.global_position
	camera._snap_to_target()
	
	# Wait for WorldManager to process clipping check
	await tree.process_frame
	await tree.process_frame
	
	assert_false(test_tree.visible, "Tree should be hidden (visible = false) when camera is within 1.5m")

func test_camera_clipping_inactive() -> void:
	await setup_tree_test()
	var camera := tree.get_first_node_in_group("camera") as GameCamera
	assert_not_null(camera, "Camera should exist")
	
	# Target distance = 1.6m (>= 1.5m threshold)
	camera.target = null
	var target_cam_pos := test_tree.global_position + Vector3(1.6, 0.0, 0.0)
	camera.global_position = target_cam_pos - camera.camera_offset
	camera.target_position = camera.global_position
	camera._snap_to_target()
	
	await tree.process_frame
	await tree.process_frame
	
	assert_true(test_tree.visible, "Tree should be visible when camera is at or beyond 1.5m")

func test_camera_magnet_activation() -> void:
	var wm := world_instance.get_node_or_null("WorldManager") as WorldManager
	var camera := tree.get_first_node_in_group("camera") as GameCamera
	assert_not_null(wm, "WorldManager should exist")
	assert_not_null(camera, "Camera should exist")
	
	var magnet_target := Vector3(25.0, 0.0, -25.0)
	var magnet_zoom := 35.0
	var magnet_duration := 2.0
	
	# Activate camera magnet
	wm._activate_camera_magnet(magnet_target, magnet_zoom, magnet_duration)
	await tree.process_frame
	
	assert_true(wm.camera_magnet_active, "Camera magnet should be active")
	assert_eq(wm.camera_magnet_target, magnet_target, "Magnet target should be set")
	assert_eq(wm.camera_magnet_zoom, magnet_zoom, "Magnet zoom should be set")
	assert_eq(wm.camera_magnet_duration, magnet_duration, "Magnet duration should be set")
	assert_eq(wm.camera_magnet_timer, magnet_duration, "Magnet timer should start at duration value")

func test_camera_magnet_restoration() -> void:
	var wm := world_instance.get_node_or_null("WorldManager") as WorldManager
	var camera := tree.get_first_node_in_group("camera") as GameCamera
	assert_not_null(wm, "WorldManager should exist")
	assert_not_null(camera, "Camera should exist")
	
	var original_zoom: float = camera.camera.size
	
	# Activate camera magnet with very short duration for quick test
	wm._activate_camera_magnet(Vector3(10.0, 0.0, 10.0), 30.0, 0.1)
	assert_true(wm.camera_magnet_active, "Magnet should start active")
	
	# Wait for 0.15s duration to elapse
	# Since WorldManager updates magnet using _process(delta)
	# we can simulate the timer decrease by setting camera_magnet_timer directly
	# or letting it run. Let's force it directly to verify expiration logic.
	wm.camera_magnet_timer = 0.0
	await tree.process_frame
	await tree.process_frame
	
	assert_false(wm.camera_magnet_active, "Camera magnet should deactivate when timer reaches zero")
