class_name WorldBossManager
extends Node

var _world_manager: Node = null


func setup(world_manager: Node) -> void:
	_world_manager = world_manager


func on_enemy_died(enemy: Node3D) -> void:
	if enemy.is_in_group("boss"):
		_world_manager._hide_boss_health_bar()
		_world_manager.boss_instance = null
		var lighting := get_tree().get_first_node_in_group("lighting_director") as LightingDirector
		if lighting:
			lighting.clear_active_objective()
		return
	if not enemy.is_in_group("orc_mobs"):
		return
	_world_manager.orcs_killed += 1
	EventBus.orc_killed_count.emit(_world_manager.orcs_killed)
	_world_manager._update_ui_orc_counter()
	if (
		_world_manager.orcs_killed >= _world_manager.orcs_to_kill_for_boss
		and not _world_manager.boss_spawned
	):
		spawn_boss()


func spawn_boss() -> void:
	if _world_manager.boss_spawned:
		return
	_world_manager.boss_spawned = true
	var boss := OrcBossMob.new()
	boss.name = "BossChằnTinh"
	boss.configure_arena(Vector3(-15.0, 0.2, -15.0))
	boss.add_to_group("orc_mobs")
	boss.add_to_group("boss")
	_world_manager.get_parent().add_child(boss)
	_world_manager.boss_instance = boss
	_world_manager._show_boss_health_bar(boss)
	_world_manager._activate_camera_magnet(Vector3(-15.0, 0.0, -15.0), 25.0, 8.0)
	EventBus.boss_spawned.emit(boss)
	var lighting := get_tree().get_first_node_in_group("lighting_director") as LightingDirector
	if lighting:
		lighting.set_active_objective(boss.global_position)
