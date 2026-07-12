extends SceneTree

func _initialize() -> void:
	var WorldManager = load("res://src/world/world_manager.gd")
	var OrcBossMob = load("res://src/world/orc_boss_mob.gd")
	var boss := OrcBossMob.new()
	boss.add_to_group("orc_mobs")
	boss.add_to_group("boss")
	boss.configure_arena(Vector3(-15.0, 0.2, -15.0))
	root.add_child(boss)
	await process_frame
	await process_frame
	print("max_health: ", boss.health_component.max_health)
	print("current_health: ", boss.health_component.current_health)
	boss.health_component.take_damage(300.0)
	print("after dmg current_health: ", boss.health_component.current_health)
	print("state: ", boss.current_state)
	await create_timer(3.0).timeout
	print("after 3s valid: ", is_instance_valid(boss))
	if is_instance_valid(boss):
		print("state: ", boss.current_state)
		print("frame: ", boss.current_frame)
	quit(0)
