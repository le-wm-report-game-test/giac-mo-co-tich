# res://src/tests/analyze_background.gd
extends SceneTree

func _initialize() -> void:
	print("=== Analyze _ChanTinh Background Colors ===")
	var base_path := "res://Assets/_ChanTinh"
	var files := ["idle.jpg", "running.jpg", "attack.jpg", "hurt.jpg", "die.jpg"]
	for file in files:
		var path = base_path + "/" + file
		var global_path = ProjectSettings.globalize_path(path)
		var img = Image.load_from_file(global_path)
		if img:
			# Sample the four corners
			var c1 = img.get_pixel(0, 0)
			var c2 = img.get_pixel(img.get_width() - 1, 0)
			var c3 = img.get_pixel(0, img.get_height() - 1)
			var c4 = img.get_pixel(img.get_width() - 1, img.get_height() - 1)
			print("File: %s | Corner Pixels: (0,0)=%s | (W,0)=%s | (0,H)=%s | (W,H)=%s" % [file, c1, c2, c3, c4])
		else:
			print("File: %s | Failed to load" % file)
	quit(0)
