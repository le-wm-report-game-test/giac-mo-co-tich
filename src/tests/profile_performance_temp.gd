extends SceneTree

func _initialize() -> void:
	var packed_scene := load("res://src/world/world.tscn") as PackedScene
	var world := packed_scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	var director := root.get_tree().get_first_node_in_group("lighting_director")
	if director != null:
		director.set_quality_preset("Cinematic")
	var mode := OS.get_environment("LIGHTING_PROFILE_PROBE")
	var world_environment := world.get_node("WorldEnvironment") as WorldEnvironment
	var sun := world.get_node("DirectionalLight3D") as DirectionalLight3D
	if mode == "no_ssil":
		world_environment.environment.ssil_enabled = false
	elif mode == "two_splits":
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	elif mode == "optimized":
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		ProjectSettings.set_setting("rendering/environment/ssil/quality", 1)
		ProjectSettings.set_setting("rendering/environment/ssil/blur_passes", 2)
