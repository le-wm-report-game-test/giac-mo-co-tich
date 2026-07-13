# res://src/tests/inspect_chantinh.gd
extends SceneTree

func _initialize() -> void:
	print("=== inspect _ChanTinh JPG files ===")
	var base_path := "res://Assets/_ChanTinh"
	var files := ["idle.jpg", "running.jpg", "attack.jpg", "hurt.jpg", "die.jpg"]
	for file in files:
		var path = base_path + "/" + file
		var global_path = ProjectSettings.globalize_path(path)
		var img = Image.load_from_file(global_path)
		if img:
			print("File: %s | Size: %dx%d | Format: %s" % [file, img.get_width(), img.get_height(), img.get_format()])
		else:
			print("File: %s | Failed to load Image at %s" % [file, global_path])
	quit(0)
