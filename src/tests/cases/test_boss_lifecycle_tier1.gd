# res://src/tests/cases/test_boss_lifecycle_tier1.gd
extends "res://src/tests/base_test_case.gd"

# Kiểm thử vòng đời Boss Chằn Tinh - Tier 1 (Happy Path)
# Technical comments in English, Vietnamese for game logic explanations.

var _world_manager: WorldManager = null

func setup() -> void:
	await super.setup()
	_world_manager = world_instance.get_node_or_null("WorldManager") as WorldManager
	assert_not_null(_world_manager, "WorldManager must exist")

func test_boss_not_spawned_initially() -> void:
	assert_false(_world_manager.boss_spawned, "Boss should not be spawned initially")
	var bosses := tree.get_nodes_in_group("boss")
	assert_eq(bosses.size(), 0, "No boss in group 'boss' initially")
	var hud_bar: Control = _world_manager.get_node_or_null("UI/BossHealthContainer") as Control
	assert_true(hud_bar == null or not hud_bar.visible, "Boss health UI should be hidden/non-existent initially")

func test_boss_spawn_trigger() -> void:
	_world_manager.orcs_to_kill_for_boss = 3
	var dummy_orc := CharacterBody3D.new()
	dummy_orc.add_to_group("orc_mobs")
	world_instance.add_child(dummy_orc)
	
	for i in range(3):
		EventBus.enemy_died.emit(dummy_orc)
		await wait_physics_frames(1)
		
	dummy_orc.queue_free()
	await wait_physics_frames(1)
	
	assert_true(_world_manager.boss_spawned, "Boss should spawn after 3 orcs killed")
	var bosses := tree.get_nodes_in_group("boss")
	assert_eq(bosses.size(), 1, "There should be exactly one boss in group 'boss'")

func test_boss_initial_properties() -> void:
	_world_manager.orcs_to_kill_for_boss = 1
	var dummy := CharacterBody3D.new()
	dummy.add_to_group("orc_mobs")
	world_instance.add_child(dummy)
	EventBus.enemy_died.emit(dummy)
	await wait_physics_frames(2)
	dummy.queue_free()
	
	var boss := _world_manager.boss_instance as CharacterBody3D
	assert_not_null(boss, "Boss instance should be valid")
	assert_eq(boss.name, "BossChằnTinh", "Boss node name should match")
	assert_true(boss.is_in_group("boss") and boss.is_in_group("orc_mobs"), "Boss should be in groups")
	assert_eq(boss.scale, Vector3(1.0, 1.0, 1.0), "Boss scale should be 1.0")
	assert_eq(boss.health_component.max_health, 300.0, "Boss max health should be 300")
	assert_eq(boss.speed, 1.5, "Boss speed should be 1.5")

func test_boss_hud_visibility_on_spawn() -> void:
	_world_manager.orcs_to_kill_for_boss = 1
	var dummy := CharacterBody3D.new()
	dummy.add_to_group("orc_mobs")
	world_instance.add_child(dummy)
	EventBus.enemy_died.emit(dummy)
	await wait_physics_frames(2)
	dummy.queue_free()
	
	var hud_bar: Control = world_instance.get_node_or_null("WorldManager/UI/BossHealthContainer") as Control
	assert_not_null(hud_bar, "HUD BossHealthContainer should exist")
	assert_true(hud_bar.visible, "HUD BossHealthContainer should be visible")

func test_boss_death_sequence() -> void:
	_world_manager.orcs_to_kill_for_boss = 1
	var dummy := CharacterBody3D.new()
	dummy.add_to_group("orc_mobs")
	world_instance.add_child(dummy)
	EventBus.enemy_died.emit(dummy)
	await wait_physics_frames(2)
	dummy.queue_free()
	
	var boss := _world_manager.boss_instance as CharacterBody3D
	assert_not_null(boss, "Boss must exist")
	
	# Gây sát thương làm boss chết
	boss.health_component.take_damage(300.0)
	await wait_physics_frames(10)
	
	# Trạng thái của OrcMob lúc chết là State.DEATH (5)
	assert_eq(boss.get("current_state"), 5, "Boss should be in State.DEATH (5)")
	
	# Chờ tween fade-out hoàn tất và giải phóng node (2.5s)
	await tree.create_timer(2.5).timeout
	assert_false(is_instance_valid(boss), "Boss should be freed and invalid")
	
	var hud_bar: Control = world_instance.get_node_or_null("WorldManager/UI/BossHealthContainer") as Control
	assert_true(hud_bar == null or not hud_bar.visible, "HUD BossHealthContainer should be hidden on boss death")
