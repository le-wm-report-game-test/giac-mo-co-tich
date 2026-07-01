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
	mesh_inst.mesh = BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mesh_inst.material_override = mat
	test_tree.add_child(mesh_inst)
	
	wm._collect_trees()
	wm.tree_list = [test_tree]
	wm._set_tree_alpha(test_tree, 1.0)

func position_tree_over_player(node: Node3D, player: Node3D, camera_x_offset: float = 0.0) -> void:
	var camera := player.get_viewport().get_camera_3d()
	var player_focus := player.global_position + Vector3.UP
	var focus_local := camera.to_local(player_focus)
	focus_local.x += camera_x_offset
	focus_local.z += minf(maxf(-focus_local.z * 0.35, 0.05), 0.2)
	node.global_position = camera.to_global(focus_local)

func settle_tree_fade(wm: WorldManager, seconds: float = 0.3) -> void:
	var frames := ceili(seconds * 60.0)
	for _frame in range(frames):
		wm._update_tree_fade(1.0 / 60.0)

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
	
	var wm := world_instance.get_node("WorldManager") as WorldManager
	position_tree_over_player(test_tree, player, 5.0)
	settle_tree_fade(wm)
	
	var alpha := get_tree_alpha(test_tree)
	assert_eq(alpha, 1.0, "Tree opacity should be 1.0 when player is far away")

func test_tree_fade_active() -> void:
	await setup_tree_test()
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(player, "Player should exist")
	
	var wm := world_instance.get_node("WorldManager") as WorldManager
	position_tree_over_player(test_tree, player)
	settle_tree_fade(wm)
	
	var alpha := get_tree_alpha(test_tree)
	assert_almost_eq(alpha, 0.25, 0.01, "Tree covering the player on screen should fade to 0.25")

func test_tree_fade_out_of_range() -> void:
	await setup_tree_test()
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(player, "Player should exist")
	
	var wm := world_instance.get_node("WorldManager") as WorldManager
	position_tree_over_player(test_tree, player, 5.0)
	settle_tree_fade(wm)
	
	var alpha := get_tree_alpha(test_tree)
	assert_eq(alpha, 1.0, "Tree opacity should remain 1.0 when player is too far behind tree")

func test_tree_fade_in_front() -> void:
	await setup_tree_test()
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(player, "Player should exist")
	
	var wm := world_instance.get_node("WorldManager") as WorldManager
	var camera := player.get_viewport().get_camera_3d()
	var focus_local := camera.to_local(player.global_position + Vector3.UP)
	focus_local.z -= 2.0
	test_tree.global_position = camera.to_global(focus_local)
	settle_tree_fade(wm)
	
	var alpha := get_tree_alpha(test_tree)
	assert_eq(alpha, 1.0, "Tree opacity should remain 1.0 when player is in front of the tree")

func test_tree_fade_side_offset() -> void:
	await setup_tree_test()
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(player, "Player should exist")
	
	var wm := world_instance.get_node("WorldManager") as WorldManager
	position_tree_over_player(test_tree, player, 1.5)
	settle_tree_fade(wm)
	
	var alpha := get_tree_alpha(test_tree)
	assert_eq(alpha, 1.0, "Tree opacity should remain 1.0 when player is offset on X axis beyond 2.5m")
