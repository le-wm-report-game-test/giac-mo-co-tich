# minimap.gd
# HUD Minimap — hiển thị dot xanh (player) + dot đỏ (orc) theo vị trí world trên map
class_name Minimap
extends Control

@export var radar_range: float = 30.0
@export var map_limit: float = 48.0
@export var show_panel_background: bool = true
@export var show_panel_border: bool = true

# Cache dữ liệu vị trí để _draw() sử dụng
var _player_pos: Vector3 = Vector3.ZERO
var _enemies: Array[Dictionary] = []  # [{position: Vector3, is_boss: bool}] — chỉ quái đang tấn công
var _foods: Array[Vector3] = []
var _player_valid: bool = false

# ─── Constants ───────────────────────────────────────────────────────────────

const BG_COLOR := Color(0.05, 0.05, 0.08, 0.6)
const BORDER_COLOR := Color(0.8, 0.8, 0.85, 0.9)
const GRID_COLOR := Color(0.3, 0.3, 0.35, 0.4)
const PLAYER_COLOR := Color(0.2, 0.5, 1.0)
const ENEMY_COLOR := Color(1.0, 0.15, 0.15)
const FOOD_COLOR := Color(0.25, 0.95, 0.35)
const PLAYER_RADIUS: float = 3.0
const ENEMY_RADIUS: float = 3.0
const BOSS_RADIUS: float = 6.0
const FOOD_RADIUS: float = 1.0


func setup(size_pixels: Vector2) -> void:
	size = size_pixels
	custom_minimum_size = size_pixels
	queue_redraw()


func update_positions(player_pos: Vector3, enemies: Array[Dictionary], foods: Array[Vector3] = []) -> void:
	_player_pos = player_pos
	_enemies = enemies
	_foods = foods
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
	draw_circle(_world_to_canvas(_player_pos), PLAYER_RADIUS, PLAYER_COLOR)

	# Vẽ dot food (xanh lá, nhỏ)
	for food_pos: Vector3 in _foods:
		draw_circle(_world_to_canvas(food_pos), FOOD_RADIUS, FOOD_COLOR)

	# Vẽ dot orc đang tấn công
	for enemy: Dictionary in _enemies:
		var enemy_pos: Vector3 = enemy.get("position", Vector3.ZERO)
		var is_boss: bool = enemy.get("is_boss", false)
		
		var canvas_pos := _world_to_canvas(enemy_pos)
		
		var radius: float = BOSS_RADIUS if is_boss else ENEMY_RADIUS
		draw_circle(canvas_pos, radius, ENEMY_COLOR)


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
