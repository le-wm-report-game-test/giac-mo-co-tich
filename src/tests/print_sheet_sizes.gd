# res://src/tests/print_sheet_sizes.gd
extends SceneTree

func _initialize() -> void:
	print("=== ORC SPRITE SHEET ANALYZER ===")
	var dirs := ["N", "NE", "E", "SE", "S"]
	var anims := ["idle", "walk", "attack", "hurt", "death"]
	var base_path := "res://Assets/orc_spring_enemy/game_ready"
	
	print("\n--- Root Legacy Sheets ---")
	for anim in anims:
		var path := "%s/%s.png" % [base_path, anim]
		if ResourceLoader.exists(path):
			var tex = load(path) as Texture2D
			if tex:
				var w := tex.get_width()
				var h := tex.get_height()
				print("  Legacy %s: %dx%d (divided by 6: %.1f, divided by 8: %.1f, divided by 4: %.1f)" % [
					anim, w, h, float(w)/6.0, float(w)/8.0, float(w)/4.0
				])
			else:
				print("  Legacy %s: Failed to load texture" % anim)
		else:
			print("  Legacy %s: File not found" % anim)
			
	print("\n--- Directional Sheets ---")
	for anim in anims:
		print("\nAnimation: ", anim)
		for dir in dirs:
			var path := "%s/%s/%s.png" % [base_path, dir, anim]
			if ResourceLoader.exists(path):
				var tex = load(path) as Texture2D
				if tex:
					var w := tex.get_width()
					var h := tex.get_height()
					print("  Dir %s: %dx%d (divided by 6: %.1f, divided by 8: %.1f, divided by 4: %.1f)" % [
						dir, w, h, float(w)/6.0, float(w)/8.0, float(w)/4.0
					])
				else:
					print("  Dir %s: Failed to load texture" % dir)
			else:
				print("  Dir %s: File not found" % dir)
				
	quit(0)
