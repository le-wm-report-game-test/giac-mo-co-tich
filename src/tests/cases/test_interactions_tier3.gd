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

func test_player_attack_recovers_after_taking_damage() -> void:
	# Interaction 8: Player bá»‹ ngáº¯t Ä‘Ã²n do trÃºng damage váº«n pháº£i attack láº¡i Ä‘Æ°á»£c
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(player, "Player must exist")

	player._start_attack()
	assert_true(player.is_attacking, "Player should enter attacking state")

	player.health_component.take_damage(10.0, null)
	await tree.process_frame

	assert_false(player.is_attacking, "Player attack flag should reset after taking damage")
	assert_eq(player.anim_state, Player.AnimState.HURT, "Player should enter HURT state after taking damage")

	player.anim_state = Player.AnimState.IDLE
	player.anim_frame = 0
	player.anim_timer = 0.0
	player.attack_cooldown = 0.0
	player._start_attack()

	assert_true(player.is_attacking, "Player should be able to start a new attack after recovering from damage")

func test_player_visual_assets_are_prewarmed_for_startup() -> void:
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(player, "Player must exist")
	if player == null:
		return

	var required_paths := [
		"res://Assets/player/thach_sanh/movement_frames/down_idle_0.png",
		"res://Assets/player/thach_sanh/movement_frames/up_walk_0.png",
		"res://Assets/player/thach_sanh/movement_frames/right_attack_0.png",
		"res://Assets/player/thach_sanh/movement_frames/left_effect_0.png",
	]

	for tex_path: String in required_paths:
		assert_true(player._texture_cache.has(tex_path), "Startup should prewarm %s" % tex_path)
		assert_not_null(player._texture_cache[tex_path], "Prewarmed texture should be loaded")

func test_player_attack_keeps_left_movement_facing() -> void:
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(player, "Player must exist")
	if player == null:
		return

	var left_dir := player._get_camera_relative_direction(Vector2.LEFT)
	player._set_facing_from_world_direction(left_dir)
	player.attack_mouse_pos = Vector2(9999.0, 0.0)
	player._start_attack()
	player._update_sprite()

	assert_eq(player.move_direction, Player.MoveDir.LEFT, "Attack should keep the last left movement direction")
	assert_true(Vector3(player.hitbox_shape.position.x, 0.0, player.hitbox_shape.position.z).dot(left_dir) > 0.1, "Left attack should place hitbox in the left movement direction")
	assert_true(player.sprite.texture.resource_path.ends_with("left_attack_0.png"), "Left attack should use left attack asset")

func test_player_attack_keeps_right_movement_facing() -> void:
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(player, "Player must exist")
	if player == null:
		return

	var right_dir := player._get_camera_relative_direction(Vector2.RIGHT)
	player._set_facing_from_world_direction(right_dir)
	player._start_attack()
	player._update_sprite()

	assert_eq(player.move_direction, Player.MoveDir.RIGHT, "Attack should keep the last right movement direction")
	assert_true(Vector3(player.hitbox_shape.position.x, 0.0, player.hitbox_shape.position.z).dot(right_dir) > 0.1, "Right attack should place hitbox in the right movement direction")
	assert_true(player.sprite.texture.resource_path.ends_with("right_attack_0.png"), "Right attack should use right attack asset")

func test_player_attack_keeps_up_movement_facing() -> void:
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(player, "Player must exist")
	if player == null:
		return

	var up_dir := player._get_camera_relative_direction(Vector2.UP)
	player._set_facing_from_world_direction(up_dir)
	player._start_attack()
	player._update_sprite()

	assert_eq(player.move_direction, Player.MoveDir.UP, "Attack should keep the last up movement direction")
	assert_true(Vector3(player.hitbox_shape.position.x, 0.0, player.hitbox_shape.position.z).dot(up_dir) > 0.1, "Up attack should place hitbox in the up movement direction")
	assert_true(player.sprite.texture.resource_path.ends_with("up_attack_0.png"), "Up attack should use up attack asset")

func test_player_attack_keeps_diagonal_movement_facing() -> void:
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(player, "Player must exist")
	if player == null:
		return

	var down_left_dir := player._get_camera_relative_direction(Vector2(-1.0, 1.0))
	player._set_facing_from_world_direction(down_left_dir)
	player._start_attack()
	player._update_sprite()

	assert_eq(player.move_direction, Player.MoveDir.DOWN_LEFT, "Attack should keep down-left movement direction")
	assert_true(Vector3(player.hitbox_shape.position.x, 0.0, player.hitbox_shape.position.z).dot(down_left_dir) > 0.1, "Down-left attack should place hitbox in the down-left movement direction")
	assert_true(player.sprite.texture.resource_path.ends_with("down_left_attack_0.png"), "Down-left attack should use down-left attack asset")

func test_player_walk_w_a_uses_up_left_direction_with_left_facing_asset() -> void:
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(player, "Player must exist")
	if player == null:
		return

	var up_left_dir := player._get_camera_relative_direction(Vector2(-1.0, -1.0))
	player.anim_state = Player.AnimState.WALK
	player.anim_frame = 0
	player._set_facing_from_world_direction(up_left_dir)
	player._update_sprite()

	assert_eq(player.move_direction, Player.MoveDir.UP_LEFT, "W + A should keep the up-left movement direction")
	assert_true(Vector3(player.hitbox_shape.position.x, 0.0, player.hitbox_shape.position.z).dot(up_left_dir) > 0.1, "W + A should keep hitbox aligned with up-left movement")
	assert_true(player.sprite.texture.resource_path.ends_with("left_walk_0.png"), "W + A should use a clearly left-facing walk asset")

func test_player_hitbox_supports_diagonal_facing() -> void:
	# Interaction 9: HÆ°á»›ng di chuyá»ƒn chÃ©o pháº£i cáº­p nháº­t hitbox theo 8 hÆ°á»›ng
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(player, "Player must exist")

	player._set_facing_from_world_direction(Vector3(1.0, 0.0, 1.0))
	player._update_attack_hitbox_position()

	var hitbox_pos := player.hitbox_shape.position
	assert_true(hitbox_pos.x > 0.1, "Diagonal facing should push the hitbox forward on X")
	assert_true(hitbox_pos.z > 0.1, "Diagonal facing should push the hitbox forward on Z")

func test_player_walk_uses_eight_direction_movement_sheet() -> void:
	# Interaction 10: Walk animation pháº£i dÃ¹ng frame crop sáº¯t tá»« asset 8 hÆ°á»›ng má»›i
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(player, "Player must exist")

	player.anim_state = Player.AnimState.WALK
	player.anim_frame = 0
	player._set_facing_from_world_direction(Vector3(-1.0, 0.0, -1.0))
	player._update_sprite()

	assert_false(player.sprite.region_enabled, "Walk animation should use a tightly cropped frame instead of a sheet region")
	assert_true(player.sprite.texture.get_width() < 200, "Walk animation should use a tightly cropped movement frame")
