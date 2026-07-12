# src/save/SaveManager.gd
# Autoload singleton - quan ly luu/tai toan bo trang thai game.
extends Node

const SAVE_FILE_PATH: String = "user://savegame.json"
const DEFAULT_GAME_SCENE_PATH: String = "res://src/world/world.tscn"

signal save_completed(success: bool)
signal load_completed(data: Dictionary, success: bool)

func trigger_save() -> void:
	var data: Dictionary = _collect_game_state()
	if data.is_empty():
		return
	save_progress(data)

func save_progress(data: Dictionary) -> void:
	var payload: Dictionary = {
		"scene_path": data.get("scene_path", DEFAULT_GAME_SCENE_PATH),
		"pos_x": data.get("pos_x", 0.0),
		"pos_y": data.get("pos_y", 1.0),
		"pos_z": data.get("pos_z", 0.0),
		"health": data.get("health", 100.0),
		"max_health": data.get("max_health", 100.0),
		"orcs_killed": data.get("orcs_killed", 0),
		"boss_spawned": data.get("boss_spawned", false),
		"weather_state": data.get("weather_state", "clear"),
		"timestamp": Time.get_datetime_string_from_unix_time(Time.get_unix_time_from_system(), true),
	}
	var json_text: String = JSON.stringify(payload, "\t")
	var file: FileAccess = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: khong mo duoc file ghi.")
		emit_signal("save_completed", false)
		return
	file.store_string(json_text)
	file.close()
	print("SaveManager: da luu tai %s" % SAVE_FILE_PATH)
	emit_signal("save_completed", true)

func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		emit_signal("load_completed", {}, false)
		return
	var file: FileAccess = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: khong mo duoc file doc.")
		emit_signal("load_completed", {}, false)
		return
	var raw: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	if json.parse(raw) != OK:
		push_error("SaveManager: loi parse JSON.")
		emit_signal("load_completed", {}, false)
		return

	var p: Variant = json.get_data()
	if typeof(p) != TYPE_DICTIONARY:
		push_error("SaveManager: dinh dang file luu khong hop le.")
		emit_signal("load_completed", {}, false)
		return

	var d: Dictionary = p as Dictionary
	var out: Dictionary = {
		"scene_path": d.get("scene_path", DEFAULT_GAME_SCENE_PATH),
		"position": Vector3(float(d.get("pos_x", 0.0)), float(d.get("pos_y", 1.0)), float(d.get("pos_z", 0.0))),
		"health": float(d.get("health", 100.0)),
		"max_health": float(d.get("max_health", 100.0)),
		"orcs_killed": int(d.get("orcs_killed", 0)),
		"boss_spawned": bool(d.get("boss_spawned", false)),
		"weather_state": str(d.get("weather_state", "clear")),
	}
	emit_signal("load_completed", out, true)

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_FILE_PATH)

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_FILE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_FILE_PATH))
		print("SaveManager: da xoa file luu.")

func _collect_game_state() -> Dictionary:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return {}

	var data: Dictionary = {}
	var root := get_tree().get_root()
	var current_scene := root.get_child(root.get_child_count() - 1)
	var scene_path: String = current_scene.scene_file_path
	if scene_path.is_empty():
		scene_path = DEFAULT_GAME_SCENE_PATH
	data["scene_path"] = scene_path

	data["pos_x"] = player.global_position.x
	data["pos_y"] = player.global_position.y
	data["pos_z"] = player.global_position.z

	var hp_comp: HealthComponent = player.get_node_or_null("HealthComponent")
	if hp_comp:
		data["health"] = hp_comp.current_health
		data["max_health"] = hp_comp.max_health
	else:
		data["health"] = player.get("max_health") if player.get("max_health") != null else 100.0
		data["max_health"] = data["health"]

	var wm: WorldManager = get_tree().get_first_node_in_group("world_manager") as WorldManager
	if wm == null:
		wm = get_tree().root.find_child("WorldManager", true, false) as WorldManager
	if wm:
		data["orcs_killed"] = wm.orcs_killed
		data["boss_spawned"] = wm.boss_spawned
		data["weather_state"] = wm.weather_state
	else:
		data["orcs_killed"] = 0
		data["boss_spawned"] = false
		data["weather_state"] = "clear"

	return data
