# res://src/tests/render_sprite_grid.gd
extends SceneTree

func _initialize() -> void:
	print("[Grid Render] Starting clean sprite grid generator with wider spacing...")
	# Set global rendering clear color to solid white
	RenderingServer.set_default_clear_color(Color.WHITE)
	
	var root_node = Node3D.new()
	root.add_child(root_node)
	
	# Camera (increased size to fit the wider spacing)
	var camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 26.0
	camera.position = Vector3(0.0, 0.0, 15.0)
	root_node.add_child(camera)
	
	# Wait for camera to enter tree
	await process_frame
	await process_frame
	
	camera.look_at(Vector3(0.0, 0.0, 0.0))
	
	# Direction and mirroring configuration matching orc_mob.gd
	var direction_configs = [
		{"name": "N (0)", "source": "N", "mirror": false},
		{"name": "NE (1)", "source": "NE", "mirror": false},
		{"name": "E (2)", "source": "E", "mirror": false},
		{"name": "SE (3)", "source": "SE", "mirror": false},
		{"name": "S (4)", "source": "S", "mirror": false},
		{"name": "SW (5)", "source": "SE", "mirror": true},
		{"name": "W (6)", "source": "E", "mirror": true},
		{"name": "NW (7)", "source": "NE", "mirror": true}
	]
	
	var base_path := "res://Assets/orc_spring_enemy/game_ready"
	var frame_width := 100.0
	var frame_height := 100.0
	var total_frames := 6
	var pixel_size := 0.0231
	
	var grid_spacing := 3.0 # Spacing in meters (larger than sprite dimensions of 2.31m)
	
	# Spawn a grid of Sprite3Ds
	for r in range(direction_configs.size()):
		var config = direction_configs[r]
		var source_dir: String = config["source"]
		var mirror: bool = config["mirror"]
		
		# Load the attack texture sheet
		var sheet_path := "%s/%s/attack.png" % [base_path, source_dir]
		var tex = load(sheet_path) as Texture2D
		if tex == null:
			push_error("[Grid Render] Cannot load texture: " + sheet_path)
			continue
			
		# Row label on the left (offset to not overlap the first column)
		var label := Label3D.new()
		label.text = config["name"]
		label.font_size = 48
		label.modulate = Color.BLACK
		label.outline_modulate = Color.WHITE
		label.outline_size = 10
		label.position = Vector3(-10.0, (3.5 - r) * grid_spacing, 0.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		root_node.add_child(label)
		
		# Spawn each of the 6 frames horizontally
		for f in range(total_frames):
			var sprite := Sprite3D.new()
			sprite.texture = tex
			sprite.region_enabled = true
			sprite.region_rect = Rect2(f * frame_width, 0.0, frame_width, frame_height)
			sprite.flip_h = mirror
			sprite.pixel_size = pixel_size
			sprite.shaded = false # Disable shading so there are no light/shadow artifacts
			sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST # Clean pixels
			
			# Layout positioning
			var x_pos := (f - 2.5) * grid_spacing
			var y_pos := (3.5 - r) * grid_spacing
			sprite.position = Vector3(x_pos, y_pos, 0.0)
			
			root_node.add_child(sprite)
			
	# Wait for multiple frames for rendering to stabilize
	for i in range(15):
		await process_frame
		
	var img = root.get_texture().get_image()
	if img:
		var path = "res://orc_attack_clean_grid.png"
		var err = img.save_png(path)
		if err == OK:
			print("[Grid Render] Saved clean sprite grid to: ", path)
		else:
			print("[Grid Render] Failed to save: ", error_string(err))
	else:
		print("[Grid Render] Error: Viewport image is null!")
		
	quit(0)
