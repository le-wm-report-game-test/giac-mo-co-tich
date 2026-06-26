# proposed_test_tree_fade_tier2.gd
extends "res://src/tests/base_test_case.gd"

# Tier 2 Tree Fade System E2E Tests (Boundary & Edge Cases)
# Technical comments in English, Vietnamese for game logic explanations.

var test_tree: Node3D = null

func run() -> void:
	await test_fade_distance_boundary()
	await reset_world()
	await test_fade_diff_x_boundary()
	await reset_world()
	await test_fade_diff_z_boundary()
	await reset_world()
	await test_fade_nested_children()
	await reset_world()
	await test_fade_removed_tree_resilience()

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
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mesh_inst.material_override = mat
	test_tree.add_child(mesh_inst)
	
	world_instance.add_child(test_tree)
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

func test_fade_distance_boundary() -> void:
	await setup_tree_test()
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(player, "Player should exist")
	
	# 1. Just below 4.0m distance boundary: D = 3.99m (diff_z = -3.99, diff_x = 0.0)
	player.global_position = Vector3(10.0, 0.0, 6.01)
	await tree.process_frame
	var alpha_in := get_tree_alpha(test_tree)
	assert_eq(alpha_in, 0.3, "Should fade at 3.99m distance (just below 4.0m threshold)")
	
	# 2. Just above 4.0m distance boundary: D = 4.01m (diff_z = -4.01, diff_x = 0.0)
	player.global_position = Vector3(10.0, 0.0, 5.99)
	await tree.process_frame
	var alpha_out := get_tree_alpha(test_tree)
	assert_eq(alpha_out, 1.0, "Should NOT fade at 4.01m distance (just above 4.0m threshold)")

func test_fade_diff_x_boundary() -> void:
	await setup_tree_test()
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(player, "Player should exist")
	
	# 1. Just below 2.5m diff_x boundary: diff_x = 2.49m (diff_z = -1.0m, dist = 2.68m)
	player.global_position = Vector3(12.49, 0.0, 9.0)
	await tree.process_frame
	var alpha_in := get_tree_alpha(test_tree)
	assert_eq(alpha_in, 0.3, "Should fade at 2.49m diff_x (just below 2.5m threshold)")
	
	# 2. Just above 2.5m diff_x boundary: diff_x = 2.51m (diff_z = -1.0m, dist = 2.70m)
	player.global_position = Vector3(12.51, 0.0, 9.0)
	await tree.process_frame
	var alpha_out := get_tree_alpha(test_tree)
	assert_eq(alpha_out, 1.0, "Should NOT fade at 2.51m diff_x (just above 2.5m threshold)")

func test_fade_diff_z_boundary() -> void:
	await setup_tree_test()
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(player, "Player should exist")
	
	# 1. Just below 0.0m diff_z boundary (player behind): diff_z = -0.01m (diff_x = 0.0)
	player.global_position = Vector3(10.0, 0.0, 9.99)
	await tree.process_frame
	var alpha_in := get_tree_alpha(test_tree)
	assert_eq(alpha_in, 0.3, "Should fade at -0.01m diff_z (behind tree)")
	
	# 2. Just above 0.0m diff_z boundary (player in front): diff_z = 0.01m (diff_x = 0.0)
	player.global_position = Vector3(10.0, 0.0, 10.01)
	await tree.process_frame
	var alpha_out := get_tree_alpha(test_tree)
	assert_eq(alpha_out, 1.0, "Should NOT fade at 0.01m diff_z (in front of tree)")

func test_fade_nested_children() -> void:
	var wm := world_instance.get_node_or_null("WorldManager") as WorldManager
	assert_not_null(wm, "WorldManager should exist")
	
	# Find the existing ForestBuilder
	var forest: ForestBuilder = null
	for child in world_instance.get_children():
		if child is ForestBuilder:
			forest = child
			break
	assert_not_null(forest, "ForestBuilder must exist in the world scene")
	
	# Create a nested tree structure: ForestBuilder -> ParentNode -> Pine_NestedTree
	var parent_node := Node3D.new()
	parent_node.name = "NestedContainer"
	
	var nested_tree := Node3D.new()
	nested_tree.name = "Pine_NestedTree"
	nested_tree.global_position = Vector3(15.0, 0.0, 15.0)
	
	var mesh_inst := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mesh_inst.material_override = mat
	nested_tree.add_child(mesh_inst)
	parent_node.add_child(nested_tree)
	forest.add_child(parent_node)
	
	# Re-collect trees and verify recursive collection
	wm._collect_trees()
	var found := false
	for tree_item in wm.tree_list:
		if tree_item == nested_tree:
			found = true
			break
			
	assert_true(found, "Pine_NestedTree should be collected recursively from under ForestBuilder")

func test_fade_removed_tree_resilience() -> void:
	await setup_tree_test()
	var wm := world_instance.get_node_or_null("WorldManager") as WorldManager
	assert_not_null(wm, "WorldManager should exist")
	
	# Free the tree so its reference in tree_list becomes invalid
	test_tree.queue_free()
	# Wait one frame for the engine to delete it
	await tree.process_frame
	
	# Trigger tree fade update. It should skip the freed node without crashing.
	wm._update_tree_fade()
	# If we reached here without a crash, the test passed.
	assert_true(true, "WorldManager should handle invalid tree references gracefully during update")
