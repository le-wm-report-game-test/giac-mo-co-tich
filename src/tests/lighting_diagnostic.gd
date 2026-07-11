# res://src/tests/lighting_diagnostic.gd
# Chạy: godot.exe --headless --path . --script res://src/tests/lighting_diagnostic.gd

extends SceneTree

func _initialize() -> void:
	print("[Diag] Lighting diagnostic...")
	var packed := load("res://src/world/world.tscn") as PackedScene
	if packed == null:
		push_error("[Diag] Cannot load world scene!")
		quit(1)
		return

	var inst: Node = packed.instantiate()
	root.add_child(inst)

	await process_frame
	await process_frame

	# Lay LightingDirector
	var ld := inst.get_node_or_null("LightingDirector") as Node
	if ld == null:
		push_error("[Diag] LightingDirector not found!")
		inst.free()
		await process_frame
		quit(1)
		return

	print("=== RUNTIME LIGHTING VALUES ===")

	# Doc current profile qua exported properties
	var clear_profile: Resource = ld.get("clear_profile")
	if clear_profile != null:
		print("clear_profile.actor_fill_energy = ", _get_prop(clear_profile, "actor_fill_energy"))
		print("clear_profile.player_accent_energy = ", _get_prop(clear_profile, "player_accent_energy"))
		print("clear_profile.ambient_energy = ", _get_prop(clear_profile, "ambient_energy"))
		print("clear_profile.exposure = ", _get_prop(clear_profile, "exposure"))
	else:
		print("clear_profile = null")

	# Doc internal light energies
	var actor_fill := ld.get_node_or_null(NodePath("ActorReadabilityLight")) as DirectionalLight3D
	var player_accent := ld.get_node_or_null(NodePath("PlayerAccentLight")) as DirectionalLight3D
	if actor_fill != null:
		print("_actor_fill_light.light_energy = ", actor_fill.light_energy)
		print("_actor_fill_light.light_color = ", actor_fill.light_color)
	else:
		print("_actor_fill_light = null")

	if player_accent != null:
		print("_player_accent_light.light_energy = ", player_accent.light_energy)
		print("_player_accent_light.light_color = ", player_accent.light_color)
	else:
		print("_player_accent_light = null")

	# Doc environment
	var env_node := inst.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node != null and env_node.environment != null:
		var env := env_node.environment
		print("_environment.ambient_light_energy = ", env.ambient_light_energy)
		print("_environment.ambient_light_color = ", env.ambient_light_color)
		print("_environment.tonemap_exposure = ", env.tonemap_exposure)
		print("_environment.adjustment_contrast = ", env.adjustment_contrast)
	else:
		print("_environment = null")

	print("=== END ===")
	inst.free()
	packed = null
	await process_frame
	await process_frame
	quit(0)


func _get_prop(res: Resource, name: String) -> Variant:
	if res == null:
		return "null"
	if name in res:
		return res.get(name)
	return "N/A"


func _get_node_by_name(parent: Node, name: String) -> Node:
	var result := parent.get_node_or_null(NodePath(name))
	if result != null:
		return result
	# search recursively
	for child in parent.get_children():
		if child.name == name:
			return child
		var found := _get_node_by_name(child, name)
		if found != null:
			return found
	return null
