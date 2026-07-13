# res://src/tests/render_chantinh_preview.gd
extends SceneTree

func _initialize() -> void:
	print("[Chằn Tinh Preview] Initializing scene...")
	# Set clear color to light blue-gray so we can see the transparency edges clearly
	RenderingServer.set_default_clear_color(Color(0.82, 0.85, 0.90))
	
	var root_node = Node3D.new()
	root.add_child(root_node)
	
	# Camera
	var camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 14.0
	camera.position = Vector3(0.0, 0.0, 10.0)
	root_node.add_child(camera)
	
	# Wait for camera to enter tree
	await process_frame
	await process_frame
	
	camera.look_at(Vector3(0.0, 0.0, 0.0))
	
	var base_path := "res://Assets/_ChanTinh/processed"
	var states = [
		{"name": "Idle", "file": "idle.png"},
		{"name": "Walk (Running)", "file": "walk.png"},
		{"name": "Attack", "file": "attack.png"},
		{"name": "Hurt", "file": "hurt.png"},
		{"name": "Death", "file": "death.png"}
	]
	
	var frame_width := 724.0
	var frame_height := 724.0
	var total_frames := 3
	# Using 0.003 pixel size so 724px sprite scales to ~2.17 meters in 3D
	var pixel_size := 0.003 
	var grid_spacing_x := 2.8
	var grid_spacing_y := 2.5
	
	# Spawn Chằn Tinh grid
	for r in range(states.size()):
		var state = states[r]
		var file_path = base_path + "/" + state["file"]
		var global_path = ProjectSettings.globalize_path(file_path)
		
		# Load programmatically via Image -> ImageTexture
		var img = Image.load_from_file(global_path)
		var tex: ImageTexture = null
		if img:
			tex = ImageTexture.create_from_image(img)
			
		if tex == null:
			push_error("[Chằn Tinh Preview] Cannot load texture: " + file_path)
			continue
			
		# Row label on the left
		var label := Label3D.new()
		label.text = state["name"]
		label.font_size = 40
		label.modulate = Color.BLACK
		label.outline_modulate = Color.WHITE
		label.outline_size = 8
		label.position = Vector3(-4.5, (2.0 - r) * grid_spacing_y, 0.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		root_node.add_child(label)
		
		# Spawn each of the 3 frames
		for f in range(total_frames):
			var sprite := Sprite3D.new()
			sprite.texture = tex
			sprite.region_enabled = true
			sprite.region_rect = Rect2(f * frame_width, 0.0, frame_width, frame_height)
			sprite.pixel_size = pixel_size
			sprite.shaded = false # Flat colors for inspection
			sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			
			# Layout positioning
			var x_pos := (f - 1.0) * grid_spacing_x
			var y_pos := (2.0 - r) * grid_spacing_y
			sprite.position = Vector3(x_pos, y_pos, 0.0)
			
			root_node.add_child(sprite)
			
	# Wait for rendering to stabilize
	for i in range(15):
		await process_frame
		
	var img = root.get_texture().get_image()
	if img:
		var path = "res://chantinh_review_grid.png"
		var err = img.save_png(path)
		if err == OK:
			print("[Chằn Tinh Preview] Saved screenshot to: ", path)
		else:
			print("[Chằn Tinh Preview] Failed to save: ", error_string(err))
	else:
		print("[Chằn Tinh Preview] Error: Viewport image is null!")
		
	quit(0)
