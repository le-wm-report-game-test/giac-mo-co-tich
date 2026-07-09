# res://src/tests/screenshot_tool.gd
# Su dung: D:\Godot\Godot_v4.7-stable_win64_console.exe --headless --path . --script res://src/tests/screenshot_tool.gd

extends SceneTree

func _initialize() -> void:
	print("[Screenshot] Loading world scene...")
	var packed := load("res://src/world/world.tscn") as PackedScene
	if packed == null:
		push_error("[Screenshot] Cannot load world scene!")
		quit(1)
		return

	var inst: Node = packed.instantiate()
	root.add_child(inst)

	# Wait for _ready() to complete on all children
	await process_frame
	await process_frame

	print("[Screenshot] World ready. Screenshot saved by --render-screenshot flag.")
	quit(0)
