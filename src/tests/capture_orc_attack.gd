# res://src/tests/capture_orc_attack.gd
extends SceneTree

func _initialize() -> void:
	print("[Capture] Initializing Orc Attack directions scene with wider spacing...")
	var root_node = Node3D.new()
	root.add_child(root_node)
	
	# Camera (increased size to fit the wider spacing)
	var camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 11.0
	camera.position = Vector3(0.0, 1.0, 6.0)
	root_node.add_child(camera)
	
	# Light
	var vp_light = DirectionalLight3D.new()
	vp_light.light_energy = 2.5
	vp_light.position = Vector3(2.0, 5.0, 4.0)
	root_node.add_child(vp_light)
	
	# Wait for camera and light to enter tree
	await process_frame
	await process_frame
	
	camera.look_at(Vector3(0.0, 0.0, 0.0))
	vp_light.look_at(Vector3.ZERO)
	
	# 8 Directions info with wider spacing
	var directions = [
		{"name": "N (0)", "dir": Vector3(0, 0, -1), "pos": Vector3(-4.5, 1.5, 0.5)},
		{"name": "NE (1)", "dir": Vector3(1, 0, -1).normalized(), "pos": Vector3(-1.5, 1.5, 0.5)},
		{"name": "E (2)", "dir": Vector3(1, 0, 0), "pos": Vector3(1.5, 1.5, 0.5)},
		{"name": "SE (3)", "dir": Vector3(1, 0, 1).normalized(), "pos": Vector3(4.5, 1.5, 0.5)},
		{"name": "S (4)", "dir": Vector3(0, 0, 1), "pos": Vector3(-4.5, -1.5, -0.5)},
		{"name": "SW (5)", "dir": Vector3(-1, 0, 1).normalized(), "pos": Vector3(-1.5, -1.5, -0.5)},
		{"name": "W (6)", "dir": Vector3(-1, 0, 0), "pos": Vector3(1.5, -1.5, -0.5)},
		{"name": "NW (7)", "dir": Vector3(-1, 0, -1).normalized(), "pos": Vector3(4.5, -1.5, -0.5)}
	]
	
	var spawned_orcs = []
	for d in directions:
		var orc := OrcMob.new()
		orc.position = d["pos"]
		orc.facing_dir = d["dir"]
		orc.current_state = OrcMob.State.ATTACK
		orc.current_frame = 3 # Swing/impact frame
		root_node.add_child(orc)
		spawned_orcs.append(orc)
		
		# Add a Label3D above each Orc to identify the direction
		var label := Label3D.new()
		label.text = d["name"]
		label.font_size = 42
		label.outline_size = 10
		label.position = Vector3(0.0, 1.2, 0.0)
		label.billboard = StandardMaterial3D.BILLBOARD_FIXED_Y
		orc.add_child(label)
		
	# Wait multiple frames for assets to load and resolve
	for i in range(30):
		await process_frame
		
	# Force update of sprites with attack frame 3
	for orc in spawned_orcs:
		orc.current_state = OrcMob.State.ATTACK
		orc.current_frame = 3
		orc._update_sprite()
		
	await process_frame
	await process_frame
	
	var img = root.get_texture().get_image()
	if img:
		var path = "res://orc_attack_screenshot.png"
		var err = img.save_png(path)
		if err == OK:
			print("[Capture] Saved screenshot to: ", path)
		else:
			print("[Capture] Failed to save: ", error_string(err))
	else:
		print("[Capture] Error: Main viewport image is null!")
		
	quit(0)
