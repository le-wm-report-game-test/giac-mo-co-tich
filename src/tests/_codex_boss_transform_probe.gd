extends SceneTree


func _initialize() -> void:
	call_deferred("_run_probe")


func _run_probe() -> void:
	var boss_script: Script = load("res://src/world/orc_boss_mob.gd")
	var boss: Node3D = boss_script.new()
	boss.add_to_group("boss")
	boss.add_to_group("orc_mobs")
	root.add_child(boss)
	await process_frame
	await process_frame
	print("BOSS root local=", boss.position, " global=", boss.global_position)
	for node: Node in boss.find_children("*", "Sprite3D", true, false):
		var sprite := node as Sprite3D
		print(
			"SPRITE path=", sprite.get_path(),
			" local=", sprite.position,
			" global=", sprite.global_position,
			" region=", sprite.region_rect,
			" offset=", sprite.offset,
			" pixel_size=", sprite.pixel_size,
			" aabb=", sprite.get_aabb()
		)
	for node: Node in boss.find_children("*", "CollisionShape3D", true, false):
		var collision := node as CollisionShape3D
		print(
			"COLLISION path=", collision.get_path(),
			" local=", collision.position,
			" global=", collision.global_position,
			" shape=", collision.shape
		)
	boss.queue_free()
	await process_frame
	quit()
