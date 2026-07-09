class_name PlayerSpriteAnimator
extends Node

const CELL_SIZE := 64
const SHEET_COLUMNS := 6
const SHEET_PATHS := {
	"idle": "res://Assets/_ThachSanh_V2/spr_thach_sanh_idle_6x4_alpha.png",
	"run": "res://Assets/_ThachSanh_V2/spr_thach_sanh_run_6x4_alpha.png",
	"attack": "res://Assets/_ThachSanh_V2/spr_thach_sanh_attack_6x4_alpha.png",
	"hurt": "res://Assets/_ThachSanh_V2/spr_thach_sanh_hurt_6x4_alpha.png",
}

var _texture_cache: Dictionary = {}
var _metrics_cache: Dictionary = {}


func prewarm() -> void:
	for state_name: String in SHEET_PATHS:
		_get_texture(state_name)


func has_animation(state_name: String) -> bool:
	return SHEET_PATHS.has(_normalize_state_name(state_name))


func get_frame_count(_state_name: String) -> int:
	return SHEET_COLUMNS


func apply_to_sprite(
		sprite: Sprite3D,
		state_name: String,
		frame_index: int,
		dir_name: String,
		target_height: float
) -> bool:
	var normalized_state := _normalize_state_name(state_name)
	var tex := _get_texture(normalized_state)
	if tex == null:
		return false

	var frame := clampi(frame_index, 0, SHEET_COLUMNS - 1)
	var row := _direction_to_row(dir_name)
	var metrics := _get_frame_metrics(tex, normalized_state, row, frame)
	var used_height := maxf(1.0, float(metrics.get("used_height", CELL_SIZE)))
	var feet_offset := float(metrics.get("feet_offset", CELL_SIZE / 2.0))

	sprite.texture = tex
	sprite.region_enabled = true
	sprite.region_rect = Rect2(frame * CELL_SIZE, row * CELL_SIZE, CELL_SIZE, CELL_SIZE)
	sprite.flip_h = false
	sprite.centered = true
	sprite.pixel_size = target_height / used_height

	var visuals_node := sprite.get_parent() as Node3D
	var visuals_global_y := visuals_node.global_position.y if visuals_node else 0.0
	sprite.position.y = -visuals_global_y + feet_offset * sprite.pixel_size
	return true


func _normalize_state_name(state_name: String) -> String:
	if state_name == "walk":
		return "run"
	if state_name == "death":
		return "hurt"
	return state_name


func _direction_to_row(dir_name: String) -> int:
	match dir_name:
		"up", "up_left", "up_right":
			return 1
		"left":
			return 2
		"right":
			return 3
		_:
			return 0


func _get_texture(state_name: String) -> Texture2D:
	if _texture_cache.has(state_name):
		return _texture_cache[state_name] as Texture2D
	var path: String = SHEET_PATHS.get(state_name, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		_texture_cache[state_name] = null
		return null
	var tex := load(path) as Texture2D
	_texture_cache[state_name] = tex
	return tex


func _get_frame_metrics(tex: Texture2D, state_name: String, row: int, frame: int) -> Dictionary:
	var key := "%s:%d:%d" % [state_name, row, frame]
	if _metrics_cache.has(key):
		return _metrics_cache[key] as Dictionary

	var metrics := {
		"used_height": float(CELL_SIZE),
		"feet_offset": float(CELL_SIZE / 2),
	}
	var img := tex.get_image()
	if img != null:
		var region := img.get_region(Rect2i(frame * CELL_SIZE, row * CELL_SIZE, CELL_SIZE, CELL_SIZE))
		var used_rect := region.get_used_rect()
		if used_rect.size.y > 0:
			metrics["used_height"] = float(used_rect.size.y)
			metrics["feet_offset"] = float((used_rect.position.y + used_rect.size.y) - (CELL_SIZE / 2))

	_metrics_cache[key] = metrics
	return metrics

