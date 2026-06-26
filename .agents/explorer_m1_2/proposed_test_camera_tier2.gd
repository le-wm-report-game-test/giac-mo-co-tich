# proposed_test_camera_tier2.gd
extends "res://src/tests/base_test_case.gd"

# Tier 2 Camera Clipping & Magnet E2E Tests (Boundary & Edge Cases)
# Technical comments in English, Vietnamese for game logic explanations.

var test_tree: Node3D = null

func run() -> void:
	await test_clipping_distance_boundary()
	await reset_world()
	await test_magnet_override_player_movement()
	await reset_world()
	await test_camera_map_clamping()
	await reset_world()
	await test_consecutive_magnet_triggers()
	await reset_world()
	await test_zero_duration_magnet()

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

func test_clipping_distance_boundary() -> void:
	await setup_tree_test()
	var camera := tree.get_first_node_in_group("camera") as GameCamera
	assert_not_null(camera, "Camera should exist")
	
	# 1. Just below 1.5m clipping boundary: distance = 1.49m (hidden)
	camera.target = null
	var target_cam_pos_in := test_tree.global_position + Vector3(1.49, 0.0, 0.0)
	camera.global_position = target_cam_pos_in - camera.camera_offset
	camera.target_position = camera.global_position
	camera._snap_to_target()
	await tree.process_frame
	await tree.process_frame
	assert_false(test_tree.visible, "Tree must be hidden at camera distance 1.49m (just under 1.5m)")
	
	# 2. Just above 1.5m clipping boundary: distance = 1.51m (visible)
	var target_cam_pos_out := test_tree.global_position + Vector3(1.51, 0.0, 0.0)
	camera.global_position = target_cam_pos_out - camera.camera_offset
	camera.target_position = camera.global_position
	camera._snap_to_target()
	await tree.process_frame
	await tree.process_frame
	assert_true(test_tree.visible, "Tree must be visible at camera distance 1.51m (just over 1.5m)")

func test_magnet_override_player_movement() -> void:
	var wm := world_instance.get_node_or_null("WorldManager") as WorldManager
	var player := tree.get_first_node_in_group("player") as Player
	var camera := tree.get_first_node_in_group("camera") as GameCamera
	assert_not_null(wm, "WorldManager should exist")
	assert_not_null(player, "Player should exist")
	assert_not_null(camera, "Camera should exist")
	
	var magnet_target := Vector3(20.0, 0.0, 20.0)
	wm._activate_camera_magnet(magnet_target, 25.0, 5.0)
	
	# Move player far away
	player.global_position = Vector3(-40.0, 0.0, -40.0)
	
	# Process multiple frames
	for i in range(20):
		await tree.process_frame
		
	# Verify camera is close to magnet target, NOT player position
	var dist_to_magnet := camera.global_position.distance_to(magnet_target)
	var dist_to_player := camera.global_position.distance_to(player.global_position)
	assert_true(dist_to_magnet < 5.0, "Camera should remain close to magnet target position")
	assert_true(dist_to_player > 20.0, "Camera should override player follow behavior when magnet is active")

func test_camera_map_clamping() -> void:
	var player := tree.get_first_node_in_group("player") as Player
	var camera := tree.get_first_node_in_group("camera") as GameCamera
	assert_not_null(player, "Player should exist")
	assert_not_null(camera, "Camera should exist")
	
	# Move player far beyond map limit (50.0)
	player.global_position = Vector3(100.0, 0.0, 100.0)
	
	# Process frames to let camera update position
	for i in range(30):
		await tree.process_frame
		
	# Camera position must be clamped, so it cannot reach 100.0
	assert_true(camera.global_position.x < 50.0, "Camera X position must be clamped below map limit")
	assert_true(camera.global_position.z < 50.0, "Camera Z position must be clamped below map limit")

func test_consecutive_magnet_triggers() -> void:
	var wm := world_instance.get_node_or_null("WorldManager") as WorldManager
	assert_not_null(wm, "WorldManager should exist")
	
	# Trigger first magnet
	wm._activate_camera_magnet(Vector3(10.0, 0.0, 10.0), 25.0, 5.0)
	assert_eq(wm.camera_magnet_target, Vector3(10.0, 0.0, 10.0), "First target should be set")
	
	# Trigger second magnet immediately
	wm._activate_camera_magnet(Vector3(30.0, 0.0, 30.0), 40.0, 2.0)
	assert_eq(wm.camera_magnet_target, Vector3(30.0, 0.0, 30.0), "Second target should override the first")
	assert_eq(wm.camera_magnet_zoom, 40.0, "Second zoom should override the first")
	assert_eq(wm.camera_magnet_timer, 2.0, "Second timer should override the first")

func test_zero_duration_magnet() -> void:
	var wm := world_instance.get_node_or_null("WorldManager") as WorldManager
	assert_not_null(wm, "WorldManager should exist")
	
	# Trigger magnet with 0 duration
	wm._activate_camera_magnet(Vector3(10.0, 0.0, 10.0), 30.0, 0.0)
	assert_true(wm.camera_magnet_active, "Magnet should be active upon call")
	
	# Process one frame
	await tree.process_frame
	
	# Should deactivate in the next update loop
	assert_false(wm.camera_magnet_active, "Magnet should deactivate immediately in the next process frame")
