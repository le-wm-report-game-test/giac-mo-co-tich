# res://src/tests/capture_mobs.gd
extends SceneTree

func _initialize() -> void:
	print("[Capture] Initializing scene...")
	var root_node = Node3D.new()
	root.add_child(root_node)
	
	# Camera
	var camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.0
	camera.position = Vector3(0.0, 1.0, 4.0)
	root_node.add_child(camera)
	
	# Light
	var vp_light = DirectionalLight3D.new()
	vp_light.light_energy = 2.5
	vp_light.position = Vector3(2.0, 4.0, 2.0)
	root_node.add_child(vp_light)
	
	# Wait for nodes to enter tree
	await process_frame
	await process_frame
	
	# Now they are in the tree, we can look_at
	camera.look_at(Vector3(0.0, 1.0, 0.0))
	vp_light.look_at(Vector3.ZERO)
	
	# Spawn regular Orc on the left
	var orc := OrcMob.new()
	orc.position = Vector3(-1.0, 0.2, 0.0)
	orc.name = "OrcMob"
	root_node.add_child(orc)
	
	# Spawn Orc Boss on the right
	var boss := OrcBossMob.new()
	boss.position = Vector3(1.0, 0.2, 0.0)
	boss.name = "OrcBoss"
	boss.add_to_group("boss")
	root_node.add_child(boss)
	
	# Wait multiple frames for physics and textures to load
	for i in range(30):
		await process_frame
		
	# Force update of sprites
	orc._update_sprite()
	boss._update_sprite()
	
	await process_frame
	await process_frame
	
	var img = root.get_texture().get_image()
	if img:
		var path = "res://mobs_screenshot.png"
		var err = img.save_png(path)
		if err == OK:
			print("[Capture] Saved screenshot to: ", path)
		else:
			print("[Capture] Failed to save: ", error_string(err))
	else:
		print("[Capture] Error: Main viewport image is null!")
	
	quit(0)
