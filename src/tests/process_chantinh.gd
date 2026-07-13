# res://src/tests/process_chantinh.gd
extends SceneTree

func _initialize() -> void:
	print("=== Chằn Tinh Sprite Sheet Processor (New Threshold) ===")
	
	var base_path := "res://Assets/_ChanTinh"
	var output_dir_path := "res://Assets/_ChanTinh/processed"
	var global_output_dir = ProjectSettings.globalize_path(output_dir_path)
	
	var dir := DirAccess.open("res://")
	if not dir.dir_exists(output_dir_path):
		dir.make_dir_recursive(output_dir_path)
		print("[Processor] Created output directory: ", output_dir_path)
		
	var files = {
		"idle.jpg": "idle.png",
		"running.jpg": "walk.png",
		"attack.jpg": "attack.png",
		"hurt.jpg": "hurt.png",
		"die.jpg": "death.png"
	}
	
	for src_file in files:
		var dest_file: String = files[src_file]
		var src_path = base_path + "/" + src_file
		var global_src_path = ProjectSettings.globalize_path(src_path)
		var dest_path = output_dir_path + "/" + dest_file
		var global_dest_path = ProjectSettings.globalize_path(dest_path)
		
		print("[Processor] Loading: ", src_file)
		var img = Image.load_from_file(global_src_path)
		if img == null:
			push_error("[Processor] Failed to load: " + global_src_path)
			continue
			
		# Convert to RGBA8 for transparency support
		img.convert(Image.FORMAT_RGBA8)
		
		var w := img.get_width()
		var h := img.get_height()
		
		# Process pixels to key out the white background
		print("[Processor] Keying out background with 0.85 threshold...")
		for y in range(h):
			for x in range(w):
				var pixel := img.get_pixel(x, y)
				# Key out any pixel that is very bright/white (R, G, B > 0.85)
				if pixel.r > 0.85 and pixel.g > 0.85 and pixel.b > 0.85:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
					
		# Save as transparent PNG
		var err = img.save_png(global_dest_path)
		if err == OK:
			print("[Processor] Saved transparent sheet: ", dest_file)
		else:
			push_error("[Processor] Failed to save: " + dest_path + " (Error: " + error_string(err) + ")")
			
	print("[Processor] Processing complete!")
	quit(0)
