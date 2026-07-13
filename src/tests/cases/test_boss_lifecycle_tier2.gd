# res://src/tests/cases/test_boss_lifecycle_tier2.gd
extends "res://src/tests/base_test_case.gd"

# Kiểm thử vòng đời Boss Chằn Tinh - Tier 2 (Boundary/Edge cases)
# Technical comments in English, Vietnamese for game logic explanations.

var _world_manager: WorldManager = null

func setup() -> void:
	await super.setup()
	_world_manager = world_instance.get_node_or_null("WorldManager") as WorldManager
	assert_not_null(_world_manager, "WorldManager must exist")

func test_boss_double_spawn_prevention() -> void:
	_world_manager.orcs_to_kill_for_boss = 2
	var dummy := CharacterBody3D.new()
	dummy.add_to_group("orc_mobs")
	world_instance.add_child(dummy)
	
	# Spawn boss bằng cách báo chết 2 lần
	EventBus.enemy_died.emit(dummy)
	EventBus.enemy_died.emit(dummy)
	await wait_physics_frames(2)
	assert_true(_world_manager.boss_spawned, "Boss should be spawned")
	
	# Giết tiếp orc để đảm bảo boss thứ hai không được tạo ra
	EventBus.enemy_died.emit(dummy)
	EventBus.enemy_died.emit(dummy)
	await wait_physics_frames(2)
	
	dummy.queue_free()
	var bosses := tree.get_nodes_in_group("boss")
	assert_eq(bosses.size(), 1, "There should never be more than 1 boss spawned")

func test_boss_spawn_location_clearance() -> void:
	_world_manager.orcs_to_kill_for_boss = 1
	var dummy := CharacterBody3D.new()
	dummy.add_to_group("orc_mobs")
	world_instance.add_child(dummy)
	EventBus.enemy_died.emit(dummy)
	await wait_physics_frames(2)
	dummy.queue_free()
	
	var boss := _world_manager.boss_instance as CharacterBody3D
	assert_not_null(boss, "Boss must exist")
	# Tọa độ chỉ định: (-15.0, 0.2, -15.0)
	assert_almost_eq(boss.global_position.x, -15.0, 0.3, "Boss spawn X should be -15.0")
	assert_almost_eq(boss.global_position.z, -15.0, 0.3, "Boss spawn Z should be -15.0")

func test_boss_damage_ui_sync() -> void:
	_world_manager.orcs_to_kill_for_boss = 1
	var dummy := CharacterBody3D.new()
	dummy.add_to_group("orc_mobs")
	world_instance.add_child(dummy)
	EventBus.enemy_died.emit(dummy)
	await wait_physics_frames(2)
	dummy.queue_free()
	
	var boss := _world_manager.boss_instance as CharacterBody3D
	assert_not_null(boss, "Boss must exist")

	# Máu boss giờ chỉ dùng screen HUD lớn, không còn thanh dưới chân.
	boss.health_component.take_damage(60.0)
	await wait_physics_frames(2)
	var hud_bar := _world_manager.get_node_or_null("UI/BossHealthBar") as BossHealthBar
	assert_not_null(hud_bar, "Boss screen HUD should stay present while boss health changes")

func test_boss_camera_magnet_activation() -> void:
	_world_manager.orcs_to_kill_for_boss = 1
	var dummy := CharacterBody3D.new()
	dummy.add_to_group("orc_mobs")
	world_instance.add_child(dummy)
	EventBus.enemy_died.emit(dummy)
	await wait_physics_frames(2)
	dummy.queue_free()
	
	# Kiểm tra trạng thái camera magnet có kích hoạt sau khi boss xuất hiện
	var is_magnet_active: bool = _world_manager.get("camera_magnet_active") as bool
	assert_true(is_magnet_active, "Camera magnet should be activated upon boss spawn")

func test_boss_health_underflow_overflow() -> void:
	_world_manager.orcs_to_kill_for_boss = 1
	var dummy := CharacterBody3D.new()
	dummy.add_to_group("orc_mobs")
	world_instance.add_child(dummy)
	EventBus.enemy_died.emit(dummy)
	await wait_physics_frames(2)
	dummy.queue_free()
	
	var boss := _world_manager.boss_instance as CharacterBody3D
	assert_not_null(boss, "Boss must exist")
	
	# Gây sát thương lớn hơn lượng máu tối đa
	boss.health_component.take_damage(400.0)
	await wait_physics_frames(2)
	assert_eq(boss.health_component.current_health, 0.0, "Boss health should clamp to 0.0")
	
	# Thử hồi máu khi đã chết (không được phép hồi phục)
	boss.health_component.heal(100.0)
	await wait_physics_frames(2)
	assert_eq(boss.health_component.current_health, 0.0, "Dead boss should not be healable")

func test_player_attack_damages_spawned_boss() -> void:
	var boss := await _spawn_boss_for_combat()
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(boss, "Spawned boss must exist")
	assert_not_null(player, "Player must exist")
	if boss == null or player == null:
		return

	boss.set_physics_process(false)
	player.set_physics_process(false)
	player.global_position = boss.global_position + Vector3(-1.55, 0.0, 0.0)
	player._set_facing_from_world_direction(Vector3.RIGHT)
	await wait_physics_frames(2)

	var initial_health := boss.health_component.current_health
	player._start_attack()
	await _step_player_attack(player, 60)
	assert_true(
		boss.health_component.current_health < initial_health,
		"Player attack should damage the visible boss body"
	)

func test_spawned_boss_attack_damages_player_at_trigger_range() -> void:
	var boss := await _spawn_boss_for_combat()
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(boss, "Spawned boss must exist")
	assert_not_null(player, "Player must exist")
	if boss == null or player == null:
		return

	boss.set_physics_process(false)
	player.set_physics_process(false)
	boss.global_position = Vector3.ZERO
	player.global_position = Vector3(boss.attack_range, 0.0, 0.0)
	boss.current_state = OrcMob.State.CHASE
	boss.attack_cooldown_timer = 0.0
	await wait_physics_frames(2)

	var initial_health := player.health_component.current_health
	boss._update_ai_state(1.0 / 60.0)
	assert_eq(boss.current_state, OrcMob.State.ATTACK, "Boss should enter ATTACK at its trigger range")
	await _step_boss_attack(boss, 90)
	assert_true(
		player.health_component.current_health < initial_health,
		"Boss active hitbox should overlap the player at its trigger range"
	)

func test_boss_attack_does_not_damage_behind_committed_swing() -> void:
	var boss := await _spawn_boss_for_combat()
	var player := tree.get_first_node_in_group("player") as Player
	assert_not_null(player, "Player must exist")
	if boss == null or player == null:
		return
	boss.set_physics_process(false)
	player.set_physics_process(false)
	boss.global_position = Vector3.ZERO
	player.global_position = Vector3(boss.attack_range * 0.9, 0.0, 0.0)
	boss.current_state = OrcMob.State.CHASE
	boss.attack_cooldown_timer = 0.0
	await wait_physics_frames(2)

	var initial_health := player.health_component.current_health
	boss._update_ai_state(1.0 / 60.0)
	assert_eq(boss.current_state, OrcMob.State.ATTACK, "Boss must commit before checking the locked strike direction")
	player.global_position = Vector3(-boss.attack_range * 0.9, 0.0, 0.0)
	await _step_boss_attack(boss, 90)
	assert_almost_eq(player.health_component.current_health, initial_health, 0.001, "Committed boss swing must not damage behind its visible impact")

func _spawn_boss_for_combat() -> OrcBossMob:
	_world_manager.orcs_to_kill_for_boss = 1
	var dummy := CharacterBody3D.new()
	dummy.add_to_group("orc_mobs")
	world_instance.add_child(dummy)
	EventBus.enemy_died.emit(dummy)
	await wait_physics_frames(2)
	dummy.free()
	return _world_manager.boss_instance as OrcBossMob

func _step_player_attack(player: Player, frame_count: int) -> void:
	var delta := 1.0 / 60.0
	for _frame in range(frame_count):
		if player.combat_v2.tick(delta) or player.anim_state == Player.AnimState.ATTACK:
			player._process_animation(delta)
		await tree.physics_frame

func _step_boss_attack(boss: OrcBossMob, frame_count: int) -> void:
	var delta := 1.0 / 60.0
	for _frame in range(frame_count):
		boss._update_animation(delta)
		await tree.physics_frame
