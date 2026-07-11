# minimap.gd
# HUD Minimap — hiển thị marker riêng cho player, orc, boss và vật phẩm.
class_name Minimap
extends Control

@export var radar_range: float = 30.0
@export var map_limit: float = 48.0
@export var show_panel_background: bool = true
@export var show_panel_border: bool = true

# Cache dữ liệu vị trí để _draw() sử dụng
const MARKER_PLAYER := &"player"
const MARKER_ORC := &"orc"
const MARKER_BOSS := &"boss"
const MARKER_ITEM := &"item"

var _player_pos: Vector3 = Vector3.ZERO
var _markers: Array[Dictionary] = []  # [{position: Vector3, marker_type: StringName}]
var _player_valid: bool = false

# ─── Constants ───────────────────────────────────────────────────────────────

const BG_COLOR := Color(0.05, 0.05, 0.08, 0.6)
const BORDER_COLOR := Color(0.8, 0.8, 0.85, 0.9)
const GRID_COLOR := Color(0.3, 0.3, 0.35, 0.4)
const PLAYER_COLOR := Color(0.25, 0.72, 1.0)
const ENEMY_COLOR := Color(0.9, 0.18, 0.16)
const BOSS_COLOR := Color(0.96, 0.78, 0.22)
const FOOD_COLOR := Color(0.3, 0.95, 0.45)
const PLAYER_RADIUS: float = 4.0
const ENEMY_RADIUS: float = 3.0
const BOSS_RADIUS: float = 6.0
const FOOD_RADIUS: float = 2.0


func setup(size_pixels: Vector2) -> void:
	size = size_pixels
	custom_minimum_size = size_pixels
	queue_redraw()


func update_positions(player_pos: Vector3, markers: Array[Dictionary]) -> void:
	_player_pos = player_pos
	_markers = markers
	_player_valid = true
	queue_redraw()


func _world_to_canvas(world_pos: Vector3) -> Vector2:
	"""Chuyển world position → canvas position theo tọa độ tuyệt đối trên map"""
	var clamped_x := clampf(world_pos.x, -map_limit, map_limit)
	var clamped_z := clampf(world_pos.z, -map_limit, map_limit)
	var cx := remap(clamped_x, -map_limit, map_limit, 0.0, size.x)
	var cy := remap(clamped_z, -map_limit, map_limit, 0.0, size.y)
	return Vector2(cx, cy)


func _draw() -> void:
	if show_panel_background or show_panel_border:
		_draw_background()
	_draw_grid()
	
	if not _player_valid:
		return
	
	# Vẽ dot player theo vị trí thật trên map
	var player_canvas := _world_to_canvas(_player_pos)
	_draw_player_marker(player_canvas)

	for marker: Dictionary in _markers:
		_draw_marker(
			_world_to_canvas(marker.get("position", Vector3.ZERO)),
			marker.get("marker_type", MARKER_ORC)
		)


func _draw_background() -> void:
	if show_panel_background:
		draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR)
	if show_panel_border:
		draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, 1.0)


func _draw_grid() -> void:
	"""Vẽ grid 12-unit cells"""
	var grid_world_step: float = 12.0  # Mỗi ô grid = 12 world units
	var grid_px_step := (grid_world_step / (map_limit * 2.0)) * size.x
	
	if grid_px_step < 8.0:
		return  # Grid quá nhỏ, bỏ qua
	
	var count := int(ceilf(size.x / grid_px_step))
	
	for i: int in range(count + 1):
		var offset: float = i * grid_px_step
		# Đường dọc
		draw_line(Vector2(offset, 0.0), Vector2(offset, size.y), GRID_COLOR, 0.5)
		# Đường ngang
		draw_line(Vector2(0.0, offset), Vector2(size.x, offset), GRID_COLOR, 0.5)


func _draw_player_marker(center: Vector2) -> void:
	draw_circle(center, PLAYER_RADIUS + 1.5, Color(0.03, 0.09, 0.14, 0.82))
	draw_circle(center, PLAYER_RADIUS, PLAYER_COLOR)
	draw_line(
		center + Vector2(0.0, -PLAYER_RADIUS - 2.0),
		center + Vector2(0.0, PLAYER_RADIUS + 2.0),
		Color(0.88, 0.98, 1.0, 0.95),
		1.4
	)
	draw_line(
		center + Vector2(-PLAYER_RADIUS - 2.0, 0.0),
		center + Vector2(PLAYER_RADIUS + 2.0, 0.0),
		Color(0.88, 0.98, 1.0, 0.95),
		1.4
	)


func _draw_marker(center: Vector2, marker_type: StringName) -> void:
	match marker_type:
		MARKER_BOSS:
			_draw_boss_marker(center)
		MARKER_ITEM:
			_draw_item_marker(center)
		_:
			_draw_orc_marker(center)


func _draw_orc_marker(center: Vector2) -> void:
	var points := PackedVector2Array([
		center + Vector2(0.0, -ENEMY_RADIUS - 1.5),
		center + Vector2(ENEMY_RADIUS + 1.5, 0.0),
		center + Vector2(0.0, ENEMY_RADIUS + 1.5),
		center + Vector2(-ENEMY_RADIUS - 1.5, 0.0),
	])
	draw_colored_polygon(points, Color(0.12, 0.05, 0.05, 0.82))
	var inner_points := PackedVector2Array([
		center + Vector2(0.0, -ENEMY_RADIUS),
		center + Vector2(ENEMY_RADIUS, 0.0),
		center + Vector2(0.0, ENEMY_RADIUS),
		center + Vector2(-ENEMY_RADIUS, 0.0),
	])
	draw_colored_polygon(inner_points, ENEMY_COLOR)


func _draw_boss_marker(center: Vector2) -> void:
	draw_circle(center, BOSS_RADIUS + 1.5, Color(0.18, 0.08, 0.02, 0.9))
	draw_circle(center, BOSS_RADIUS, BOSS_COLOR)
	var horn_color := Color(0.32, 0.16, 0.03, 0.95)
	var left_horn := PackedVector2Array([
		center + Vector2(-2.0, -BOSS_RADIUS + 0.5),
		center + Vector2(-BOSS_RADIUS - 2.5, -BOSS_RADIUS - 3.0),
		center + Vector2(-0.5, -BOSS_RADIUS - 1.5),
	])
	var right_horn := PackedVector2Array([
		center + Vector2(2.0, -BOSS_RADIUS + 0.5),
		center + Vector2(BOSS_RADIUS + 2.5, -BOSS_RADIUS - 3.0),
		center + Vector2(0.5, -BOSS_RADIUS - 1.5),
	])
	draw_colored_polygon(left_horn, horn_color)
	draw_colored_polygon(right_horn, horn_color)


func _draw_item_marker(center: Vector2) -> void:
	var points := PackedVector2Array([
		center + Vector2(0.0, -FOOD_RADIUS - 1.0),
		center + Vector2(FOOD_RADIUS + 1.0, 0.0),
		center + Vector2(0.0, FOOD_RADIUS + 1.0),
		center + Vector2(-FOOD_RADIUS - 1.0, 0.0),
	])
	draw_colored_polygon(points, FOOD_COLOR)
	draw_circle(center, 0.9, Color(0.96, 1.0, 0.94, 0.95))
