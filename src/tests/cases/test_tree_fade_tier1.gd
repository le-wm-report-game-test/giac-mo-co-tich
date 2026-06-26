# res://src/tests/cases/test_tree_fade_tier1.gd
extends "res://src/tests/base_test_case.gd"

# Tier 1 Tree Fade System E2E Tests
# Technical comments in English, Vietnamese for game logic explanations.

var test_tree: Node3D = null

func setup_tree_test() -> void:
	var wm := world_instance.get_node_or_null("WorldManager") as WorldManager
	assert_not_null(wm, "WorldManager should exist")
	
	# Create a dummy tree and add it to the scene
	test_tree = Node3D.new()
	test_tree.name = "Pine_TestTree"
	world_instance.add_child(test_tree)
	test_tree.global_position = Vector3(10.0, 0.0, 10.0)
	
	var mesh_inst := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mesh_inst.material_override = mat
	test_tree.add_child(mesh_inst)
	
	wm._collect_trees()

func get_tree_alpha(node: Node) -> float:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.material_override:
			var mat := mesh_node.material_override as BaseMaterial3D
			if mat:
				return mat.albedo_color.a
		for i in range(mesh_node.get_surface_override_material_count()):
			var mat := mesh_node.get_surface_override_material(i) as BaseMaterial3D
			if mat:
				return mat.albedo_color.a
	for child in node.get_children():
		var alpha := get_tree_alpha(child)
		if alpha >= 0.0:
			return alpha
	return -1.0

func test_initial_tree_alpha() -> void:
	await setup_tree_test()
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(player, "Player should exist")
	
	# Player is at spawn (0.0, 0.0, 0.0) which is > 10m away from tree (10.0, 0.0, 10.0)
	player.global_position = Vector3(0.0, 0.0, 0.0)
	await tree.process_frame
	
	var alpha := get_tree_alpha(test_tree)
	assert_eq(alpha, 1.0, "Tree opacity should be 1.0 when player is far away")

func test_tree_fade_active() -> void:
	await setup_tree_test()
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(player, "Player should exist")
	
	# Player behind tree (diff_z = -2.0, diff_x = 0.0, dist = 2.0 < 4.0)
	player.global_position = Vector3(10.0, 0.0, 8.0)
	await tree.process_frame
	
	var alpha := get_tree_alpha(test_tree)
	assert_almost_eq(alpha, 0.3, 0.01, "Tree opacity should fade to 0.3 when player is behind tree in range")

func test_tree_fade_out_of_range() -> void:
	await setup_tree_test()
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(player, "Player should exist")
	
	# Player behind tree but out of range (diff_z = -5.0, diff_x = 0.0, dist = 5.0 > 4.0)
	player.global_position = Vector3(10.0, 0.0, 5.0)
	await tree.process_frame
	
	var alpha := get_tree_alpha(test_tree)
	assert_eq(alpha, 1.0, "Tree opacity should remain 1.0 when player is too far behind tree")

func test_tree_fade_in_front() -> void:
	await setup_tree_test()
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(player, "Player should exist")
	
	# Player in front of tree (diff_z = 2.0 > 0.0, diff_x = 0.0, dist = 2.0)
	player.global_position = Vector3(10.0, 0.0, 12.0)
	await tree.process_frame
	
	var alpha := get_tree_alpha(test_tree)
	assert_eq(alpha, 1.0, "Tree opacity should remain 1.0 when player is in front of the tree")

func test_tree_fade_side_offset() -> void:
	await setup_tree_test()
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(player, "Player should exist")
	
	# Player to the side of tree (diff_z = -1.0, diff_x = 3.0 > 2.5, dist = sqrt(10) < 4.0)
	player.global_position = Vector3(13.0, 0.0, 9.0)
	await tree.process_frame
	
	var alpha := get_tree_alpha(test_tree)
	assert_eq(alpha, 1.0, "Tree opacity should remain 1.0 when player is offset on X axis beyond 2.5m")
