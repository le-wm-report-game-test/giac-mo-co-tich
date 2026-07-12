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
