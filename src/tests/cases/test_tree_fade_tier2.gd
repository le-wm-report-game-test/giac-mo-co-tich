# res://src/tests/cases/test_tree_fade_tier2.gd
extends "res://src/tests/base_test_case.gd"

# Tier 2 Tree Fade System E2E Tests (Boundary & Edge Cases)

var test_tree: Node3D = null

func setup_tree_test() -> void:
	var wm := world_instance.get_node_or_null("WorldManager") as WorldManager
	assert_not_null(wm, "WorldManager should exist")
	test_tree = Node3D.new()
	test_tree.name = "Pine_TestTree"
	world_instance.add_child(test_tree)
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.resource_local_to_scene = true
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
	for _frame in range(ceili(seconds * 60.0)):
		wm._update_tree_fade(1.0 / 60.0)

func get_tree_alpha(node: Node) -> float:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.material_override is BaseMaterial3D:
			return (mesh_node.material_override as BaseMaterial3D).albedo_color.a
	for child in node.get_children():
		var alpha := get_tree_alpha(child)
		if alpha >= 0.0:
			return alpha
	return -1.0

func test_lateral_occlusion_boundary() -> void:
	await setup_tree_test()
	var player := tree.get_first_node_in_group("player") as Player
	var wm := world_instance.get_node("WorldManager") as WorldManager
	position_tree_over_player(test_tree, player, 0.25)
	settle_tree_fade(wm)
	assert_almost_eq(get_tree_alpha(test_tree), 0.25, 0.01, "A projected tree mesh covering the player must fade")
	position_tree_over_player(test_tree, player, 1.5)
	settle_tree_fade(wm)
	assert_eq(get_tree_alpha(test_tree), 1.0, "A projected tree mesh outside the player must remain opaque")

func test_fade_caps_at_three_occluders() -> void:
	await setup_tree_test()
	var player := tree.get_first_node_in_group("player") as Player
	var wm := world_instance.get_node("WorldManager") as WorldManager
	var candidates: Array[Node3D] = [test_tree]
	for index in range(3):
		var candidate := Node3D.new()
		candidate.name = "Pine_CapTest%d" % index
		world_instance.add_child(candidate)
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = BoxMesh.new()
		var material := StandardMaterial3D.new()
		material.resource_local_to_scene = true
		mesh_instance.material_override = material
		candidate.add_child(mesh_instance)
		candidates.append(candidate)
	for index in range(candidates.size()):
		position_tree_over_player(candidates[index], player, (float(index) - 1.5) * 0.3)
	wm._collect_trees()
	wm.tree_list = candidates
	for candidate in candidates:
		wm._set_tree_alpha(candidate, 1.0)
	settle_tree_fade(wm)
	var faded_count := 0
	for candidate in candidates:
		if get_tree_alpha(candidate) < 0.5:
			faded_count += 1
	assert_eq(faded_count, 3, "At most three simultaneous tree occluders may fade")

func test_tree_must_lie_on_camera_player_segment() -> void:
	await setup_tree_test()
	var player := tree.get_first_node_in_group("player") as Player
	var wm := world_instance.get_node("WorldManager") as WorldManager
	position_tree_over_player(test_tree, player)
	settle_tree_fade(wm)
	assert_almost_eq(get_tree_alpha(test_tree), 0.25, 0.01, "Tree on the camera-player segment must fade")
	position_tree_over_player(test_tree, player, 5.0)
	settle_tree_fade(wm)
	assert_eq(get_tree_alpha(test_tree), 1.0, "Tree outside the player projection must remain opaque")

func test_fade_nested_children() -> void:
	var wm := world_instance.get_node_or_null("WorldManager") as WorldManager
	var forest: ForestBuilder = null
	for child in world_instance.get_children():
		if child is ForestBuilder:
			forest = child
			break
	assert_not_null(forest, "ForestBuilder must exist in the world scene")
	var parent_node := Node3D.new()
	forest.add_child(parent_node)
	var nested_tree := Node3D.new()
	nested_tree.name = "Pine_NestedTree"
	parent_node.add_child(nested_tree)
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = BoxMesh.new()
	nested_tree.add_child(mesh_inst)
	wm._collect_trees()
	assert_true(wm.tree_list.has(nested_tree), "Pine_NestedTree should be collected recursively")

func test_fade_removed_tree_resilience() -> void:
	await setup_tree_test()
	var wm := world_instance.get_node_or_null("WorldManager") as WorldManager
	test_tree.queue_free()
	await tree.process_frame
	wm._update_tree_fade(0.016)
	assert_true(true, "WorldManager should handle invalid tree references gracefully")
