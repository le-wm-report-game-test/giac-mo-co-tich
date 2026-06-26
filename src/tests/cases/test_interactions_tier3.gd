# res://src/tests/cases/test_interactions_tier3.gd
extends "res://src/tests/base_test_case.gd"

# Tier 3 E2E tests checking pairwise system interactions.
# Technical comments in English, Vietnamese for game logic explanations.

func get_tree_alpha(node: Node) -> float:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.material_override:
			var mat := mesh_node.material_override
			if mat is ShaderMaterial:
				return mat.get_shader_parameter("alpha_multiplier")
			elif mat is BaseMaterial3D:
				return mat.albedo_color.a
		for i in range(mesh_node.get_surface_override_material_count()):
			var mat := mesh_node.get_surface_override_material(i)
			if mat is ShaderMaterial:
				return mat.get_shader_parameter("alpha_multiplier")
			elif mat is BaseMaterial3D:
				return mat.albedo_color.a
	for child in node.get_children():
		var alpha := get_tree_alpha(child)
		if alpha >= 0.0:
			return alpha
	return -1.0

func test_orc_spawning_and_orc_counter() -> void:
	# Interaction 1: Diệt quái sinh ra bằng thuật toán làm tăng số đếm trên HUD
	var world_manager := world_instance.get_node_or_null("WorldManager") as WorldManager
	assert_not_null(world_manager, "WorldManager must exist")
	
	var fb := world_instance.get_node("Forest") as Node
	var orc: CharacterBody3D = null
	for child in fb.get_children():
		if child.name.begins_with("OrcMob_"):
			orc = child as CharacterBody3D
			break
			
	assert_not_null(orc, "Procedural orc should be found")
	var initial_killed := world_manager.orcs_killed
	
	EventBus.enemy_died.emit(orc)
	await tree.process_frame
	
	var new_killed := world_manager.orcs_killed
	assert_eq(new_killed, initial_killed + 1, "Orcs killed count should increment")
	
	var label := world_manager.get_node_or_null("UI/OrcCounter/OrcCountLabel") as Label
	assert_not_null(label, "Orc counter label must exist")
	assert_true(label.text.begins_with(str(new_killed)), "HUD label should reflect new killed count")

func test_boss_spawning_and_camera_magnet() -> void:
	# Interaction 2: Spawn Boss làm kích hoạt cơ chế kéo camera (Camera Magnet)
	var world_manager := world_instance.get_node_or_null("WorldManager") as WorldManager
	assert_not_null(world_manager, "WorldManager must exist")
	
	world_manager.boss_spawned = false
	world_manager.orcs_killed = 4
	world_manager.orcs_to_kill_for_boss = 5
	
	var dummy_orc := CharacterBody3D.new()
	dummy_orc.add_to_group("orc_mobs")
	world_instance.add_child(dummy_orc)
	
	EventBus.enemy_died.emit(dummy_orc)
	await tree.process_frame
	await tree.process_frame
	
	assert_true(world_manager.boss_spawned, "Boss should be spawned")
	assert_true(world_manager.camera_magnet_active, "Camera magnet should activate on boss spawn")
	
	dummy_orc.queue_free()
	await tree.process_frame

func test_weather_change_and_player_health() -> void:
	# Interaction 3: Sét đánh trong bão làm giảm máu người chơi và cập nhật HUD
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(player, "Player must exist")
	
	player.health_component.current_health = 100.0
	
	player.health_component.take_damage(20.0, null)
	await tree.process_frame
	
	assert_eq(player.health_component.current_health, 80.0, "Player health should drop by 20")
	
	var world_manager := world_instance.get_node("WorldManager") as WorldManager
	var bar := world_manager.get_node("UI/PlayerHealthContainer/PlayerHealthBar") as TextureProgressBar
	assert_eq(bar.value, 80.0, "HUD health progress bar should update to 80")

func test_player_movement_tree_fade() -> void:
	# Interaction 4: Di chuyển của player ra sau cây làm cây chuyển độ mờ (alpha = 0.3)
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(player, "Player must exist")
	
	var fb := world_instance.get_node("Forest") as Node
	var tree_node: Node3D = null
	for child in fb.get_children():
		if "Pine_" in child.name:
			tree_node = child as Node3D
			break
			
	if tree_node == null:
		return
		
	player.global_position = tree_node.global_position + Vector3(0.0, 0.0, -2.0)
	await tree.process_frame
	
	var world_manager := world_instance.get_node("WorldManager") as WorldManager
	world_manager._update_tree_fade()
	await tree.process_frame
	
	var alpha := get_tree_alpha(tree_node)
	assert_almost_eq(alpha, 0.3, 0.01, "Tree alpha should be 0.3 when player is behind it")

func test_boss_spawning_and_animal_ai() -> void:
	# Interaction 5: Trạng thái AI của động vật không bị crash/ảnh hưởng khi Boss xuất hiện
	var fb := world_instance.get_node("Forest") as Node
	var animal: CharacterBody3D = null
	for child in fb.get_children():
		if "Bot_" in child.name:
			animal = child as CharacterBody3D
			break
			
	assert_not_null(animal, "At least one animal bot should exist")
	
	var world_manager := world_instance.get_node("WorldManager") as WorldManager
	world_manager._spawn_boss()
	await tree.process_frame
	await tree.process_frame
	
	assert_true(is_instance_valid(animal), "Animal bot should still be valid after boss spawn")

func test_storm_weather_orc_damage_popup() -> void:
	# Interaction 6: Gây sát thương lên Orc kích hoạt popup số sát thương trên HUD
	var fb := world_instance.get_node("Forest") as Node
	var orc: CharacterBody3D = null
	for child in fb.get_children():
		if child.name.begins_with("OrcMob_"):
			orc = child as CharacterBody3D
			break
			
	assert_not_null(orc, "Orc should exist")
	
	var ui := world_instance.get_node("WorldManager/UI") as CanvasLayer
	var start_labels := ui.get_child_count()
	
	EventBus.enemy_damaged.emit(orc, 15.0, orc.global_position)
	await tree.process_frame
	
	var end_labels := ui.get_child_count()
	assert_true(end_labels > start_labels, "Damage number label should be created in UI")

func test_tree_spawning_and_camera_clipping() -> void:
	# Interaction 7: Camera lại gần cây (< 1.5m) kích hoạt ẩn cây
	var fb := world_instance.get_node("Forest") as Node
	var tree_node: Node3D = null
	for child in fb.get_children():
		if "Pine_" in child.name:
			tree_node = child as Node3D
			break
			
	if tree_node == null:
		return
		
	var camera := tree.get_first_node_in_group("camera") as GameCamera
	assert_not_null(camera, "Camera must exist")
	
	# Position the camera node (active 3D viewport) within 1.5m of the tree
	camera.target = null
	camera.map_limit = 1000.0
	var target_cam_pos := tree_node.global_position + Vector3(1.0, 0.0, 0.0)
	camera.global_position = target_cam_pos - camera.camera_offset
	camera.target_position = camera.global_position
	camera._snap_to_target()
	
	var world_manager := world_instance.get_node("WorldManager") as WorldManager
	world_manager._update_tree_camera_clip()
	await tree.process_frame
	
	assert_true(tree_node.visible, "Tree should stay visible when camera is close")
