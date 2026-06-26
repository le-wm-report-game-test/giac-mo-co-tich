# minimap.gd
# HUD Minimap — hiển thị dot xanh (player) + dot đỏ (quái) trong radar range 30 units
class_name Minimap
extends Control

@export var radar_range: float = 30.0
@export var map_limit: float = 48.0

# Cache dữ liệu vị trí để _draw() sử dụng
var _player_pos: Vector3 = Vector3.ZERO
var _enemies: Array[Dictionary] = []  # [{position: Vector3, is_boss: bool}]
var _player_valid: bool = false

# ─── Constants ───────────────────────────────────────────────────────────────

const BG_COLOR := Color(0.05, 0.05, 0.08, 0.6)
const BORDER_COLOR := Color(0.8, 0.8, 0.85, 0.9)
const GRID_COLOR := Color(0.3, 0.3, 0.35, 0.4)
const PLAYER_COLOR := Color(0.2, 0.5, 1.0)
const ENEMY_COLOR := Color(1.0, 0.15, 0.15)
const PLAYER_RADIUS: float = 3.0
const ENEMY_RADIUS: float = 3.0
const BOSS_RADIUS: float = 6.0


func setup(size_pixels: Vector2) -> void:
	size = size_pixels
	custom_minimum_size = size_pixels
	queue_redraw()


func update_positions(player_pos: Vector3, enemies: Array[Dictionary]) -> void:
	_player_pos = player_pos
	_enemies = enemies
	_player_valid = true
	queue_redraw()


func _world_to_canvas(world_pos: Vector3) -> Vector2:
	"""Chuyển world position → canvas position (player làm trung tâm minimap)"""
	var half_w := size.x / 2.0
	var rel_x := world_pos.x - _player_pos.x
	var rel_z := world_pos.z - _player_pos.z
	var cx := (rel_x / radar_range) * half_w + half_w
	var cy := half_w - (rel_z / radar_range) * half_w
	return Vector2(cx, cy)


func _draw() -> void:
	_draw_background()
	_draw_grid()
	
	if not _player_valid:
		return
	
	# Vẽ dot player (luôn ở trung tâm)
	draw_circle(Vector2(size.x / 2.0, size.y / 2.0), PLAYER_RADIUS, PLAYER_COLOR)
	
	# Vẽ dot quái
	for enemy: Dictionary in _enemies:
		var enemy_pos: Vector3 = enemy.get("position", Vector3.ZERO)
		var is_boss: bool = enemy.get("is_boss", false)
		
		# Chỉ vẽ nếu trong radar range
		var dist := _player_pos.distance_to(enemy_pos)
		if dist > radar_range:
			continue
		
		var canvas_pos := _world_to_canvas(enemy_pos)
		
		# Clip trong canvas
		if canvas_pos.x < 0.0 or canvas_pos.x > size.x or canvas_pos.y < 0.0 or canvas_pos.y > size.y:
			continue
		
		var radius: float = BOSS_RADIUS if is_boss else ENEMY_RADIUS
		draw_circle(canvas_pos, radius, ENEMY_COLOR)


func _draw_background() -> void:
	# Nền tối semi-transparent
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR)
	# Border trắng
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, 1.0)


func _draw_grid() -> void:
	"""Vẽ grid 12-unit cells"""
	var grid_world_step: float = 12.0  # Mỗi ô grid = 12 world units
	var grid_px_step := (grid_world_step / radar_range) * (size.x / 2.0)
	
	if grid_px_step < 8.0:
		return  # Grid quá nhỏ, bỏ qua
	
	var count := int(ceilf(size.x / grid_px_step))
	
	for i: int in range(count + 1):
		var offset: float = i * grid_px_step
		# Đường dọc
		draw_line(Vector2(offset, 0.0), Vector2(offset, size.y), GRID_COLOR, 0.5)
		# Đường ngang
		draw_line(Vector2(0.0, offset), Vector2(size.x, offset), GRID_COLOR, 0.5)
