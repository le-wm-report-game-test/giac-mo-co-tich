# food_spawner.gd
class_name FoodSpawner
extends Node3D

@export var food_scene: PackedScene
@export_range(5, 50) var max_food_items: int = 20
@export_range(1, 50) var initial_food_count: int = 15
@export_range(5.0, 48.0, 0.5) var spawn_radius: float = 40.0
@export_range(10.0, 120.0) var respawn_delay: float = 45.0

@export_group("Reachable Spawn")
@export var random_seed: int = 2026
@export_range(0.5, 2.0, 0.25) var grid_cell_size: float = 1.0
@export_range(3.0, 10.0, 0.5) var min_spawn_distance: float = 5.0
@export_range(1.0, 5.0, 0.25) var min_food_spacing: float = 2.5
@export_range(2.0, 10.0, 0.5) var min_respawn_displacement: float = 5.0
@export_range(40.0, 48.0, 0.5) var playable_half_extent: float = 47.0
@export_range(0.0, 0.2, 0.01) var max_flat_height_delta: float = 0.05
@export_range(0.0, 0.5, 0.05) var obstacle_safety_margin: float = 0.2
@export_range(0.1, 1.0, 0.05) var pickup_ground_offset: float = 0.45
@export var avoid_paths: bool = true

const PLAYER_COLLISION_RADIUS: float = 0.4
const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
]
const ALL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i(-1, -1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(1, 1),
]

var _spawned_items: Array[FoodItem] = []
var _candidate_positions: Array[Vector3] = []
var _walkable_cells: Dictionary = {}
var _reachable_cells: Dictionary = {}
var _obstacle_circles: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _forest: ForestBuilder


func _ready() -> void:
	# Forest tạo collision/props trong _ready; chờ một frame để snapshot đầy đủ.
	await get_tree().process_frame
	_rng.seed = random_seed
	_forest = get_node_or_null("../Forest") as ForestBuilder
	_rebuild_spawn_graph()
	_spawn_initial_food()


func _spawn_initial_food() -> void:
	var initial_count := mini(max_food_items, initial_food_count)
	for i in range(initial_count):
		if not _spawn_random_food():
			push_warning("FoodSpawner exhausted reachable candidates after %d items" % _spawned_items.size())
			break


func _spawn_random_food() -> bool:
	if _spawned_items.size() >= max_food_items:
		return false

	var spawn_pos := _get_random_spawn_position()
	if spawn_pos == Vector3.ZERO:
		return false

	_spawn_food_at_position(spawn_pos, _rng.randi_range(0, 3) as FoodItem.FoodType)
	return true


func _get_random_spawn_position(excluded_food: FoodItem = null) -> Vector3:
	if _candidate_positions.is_empty():
		return Vector3.ZERO

	var start_index := _rng.randi_range(0, _candidate_positions.size() - 1)
	for offset in range(_candidate_positions.size()):
		var candidate := _candidate_positions[(start_index + offset) % _candidate_positions.size()]
		if excluded_food != null:
			var old_planar := Vector2(excluded_food.global_position.x, excluded_food.global_position.z)
			var new_planar := Vector2(candidate.x, candidate.z)
			if old_planar.distance_to(new_planar) < min_respawn_displacement:
				continue
		if _has_food_spacing(candidate, excluded_food):
			return candidate
	return Vector3.ZERO


func _is_valid_spawn_position(pos: Vector3) -> bool:
	var planar := Vector2(pos.x, pos.z)
	if planar.length() < min_spawn_distance or planar.length() > spawn_radius:
		return false
	var cell := _world_to_cell(planar)
	return _reachable_cells.has(cell) and _is_flat_surface(planar) and _has_obstacle_clearance(planar)


func is_position_reachable(pos: Vector3) -> bool:
	return _reachable_cells.has(_world_to_cell(Vector2(pos.x, pos.z)))


func get_reachable_candidate_count() -> int:
	return _candidate_positions.size()


func get_spawned_items() -> Array[FoodItem]:
	return _spawned_items.duplicate()


func _rebuild_spawn_graph() -> void:
	_candidate_positions.clear()
	_walkable_cells.clear()
	_reachable_cells.clear()
	_obstacle_circles.clear()
	if _forest == null:
		push_warning("FoodSpawner requires a ForestBuilder sibling")
		return

	_collect_obstacle_circles()
	_build_walkable_grid()
	_flood_fill_from_spawn()
	_build_candidate_pool()
	_shuffle_candidates()


func _collect_obstacle_circles() -> void:
	var clearance := PLAYER_COLLISION_RADIUS + obstacle_safety_margin
	for node in get_tree().get_nodes_in_group("trees"):
		if not (node is Node3D) or not _forest.is_ancestor_of(node):
			continue
		var tree_node := node as Node3D
		var tree_scale := tree_node.global_transform.basis.get_scale()
		var scale_radius := maxf(absf(tree_scale.x), absf(tree_scale.z)) * 0.5
		_obstacle_circles.append({
			"center": Vector2(tree_node.global_position.x, tree_node.global_position.z),
			"radius": scale_radius + clearance,
		})

	for node in get_tree().get_nodes_in_group("rock_obstacles"):
		if not (node is StaticBody3D) or not _forest.is_ancestor_of(node):
			continue
		var body := node as StaticBody3D
		var shape_node := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape_node == null or not (shape_node.shape is SphereShape3D):
			continue
		var sphere := shape_node.shape as SphereShape3D
		var body_scale := body.global_transform.basis.get_scale()
		var scale_radius := maxf(absf(body_scale.x), absf(body_scale.z))
		_obstacle_circles.append({
			"center": Vector2(body.global_position.x, body.global_position.z),
			"radius": sphere.radius * scale_radius + clearance,
		})


func _build_walkable_grid() -> void:
	var max_cell := int(floor(playable_half_extent / grid_cell_size))
	for grid_x in range(-max_cell, max_cell + 1):
		for grid_z in range(-max_cell, max_cell + 1):
			var cell := Vector2i(grid_x, grid_z)
			var point := _cell_to_world(cell)
			if _is_flat_surface(point) and _has_obstacle_clearance(point):
				_walkable_cells[cell] = true


func _flood_fill_from_spawn() -> void:
	var start := Vector2i.ZERO
	if not _walkable_cells.has(start):
		for direction in CARDINAL_DIRECTIONS:
			if _walkable_cells.has(direction):
				start = direction
				break
	if not _walkable_cells.has(start):
		push_warning("FoodSpawner cannot find a walkable player spawn cell")
		return

	var queue: Array[Vector2i] = [start]
	var cursor := 0
	_reachable_cells[start] = true
	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1
		for direction in ALL_DIRECTIONS:
			var neighbor := current + direction
			if _reachable_cells.has(neighbor) or not _walkable_cells.has(neighbor):
				continue
			if abs(direction.x) + abs(direction.y) == 2:
				if not _walkable_cells.has(current + Vector2i(direction.x, 0)):
					continue
				if not _walkable_cells.has(current + Vector2i(0, direction.y)):
					continue
			_reachable_cells[neighbor] = true
			queue.append(neighbor)


func _build_candidate_pool() -> void:
	for key in _reachable_cells.keys():
		var cell := key as Vector2i
		var point := _cell_to_world(cell)
		var distance_to_spawn := point.length()
		if distance_to_spawn < min_spawn_distance or distance_to_spawn > spawn_radius:
			continue
		var ground_height := _forest._get_hill_height(point.x, point.y)
		_candidate_positions.append(Vector3(point.x, ground_height + pickup_ground_offset, point.y))


func _shuffle_candidates() -> void:
	for index in range(_candidate_positions.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var value := _candidate_positions[index]
		_candidate_positions[index] = _candidate_positions[swap_index]
		_candidate_positions[swap_index] = value


func _is_flat_surface(point: Vector2) -> bool:
	if _forest == null:
		return false
	var zone := _forest._get_zone(point.x, point.y)
	if zone == ForestBuilder.Zone.HILL:
		return false
	if avoid_paths and zone == ForestBuilder.Zone.PATH:
		return false

	var sample_offset := grid_cell_size * 0.4
	var min_height := INF
	var max_height := -INF
	for offset in [Vector2.ZERO, Vector2(sample_offset, 0.0), Vector2(-sample_offset, 0.0), Vector2(0.0, sample_offset), Vector2(0.0, -sample_offset)]:
		var height := _forest._get_hill_height(point.x + offset.x, point.y + offset.y)
		min_height = minf(min_height, height)
		max_height = maxf(max_height, height)
	return max_height - min_height <= max_flat_height_delta and max_height <= max_flat_height_delta


func _has_obstacle_clearance(point: Vector2) -> bool:
	for obstacle in _obstacle_circles:
		var center := obstacle["center"] as Vector2
		var radius := float(obstacle["radius"])
		if point.distance_squared_to(center) < radius * radius:
			return false
	return true


func _has_food_spacing(candidate: Vector3, excluded_food: FoodItem) -> bool:
	var candidate_planar := Vector2(candidate.x, candidate.z)
	for food in _spawned_items:
		if not is_instance_valid(food) or food == excluded_food:
			continue
		var food_planar := Vector2(food.global_position.x, food.global_position.z)
		if candidate_planar.distance_to(food_planar) < min_food_spacing:
			return false
	return true


func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x) * grid_cell_size, float(cell.y) * grid_cell_size)


func _world_to_cell(point: Vector2) -> Vector2i:
	return Vector2i(roundi(point.x / grid_cell_size), roundi(point.y / grid_cell_size))


func _create_food_item(type: FoodItem.FoodType) -> FoodItem:
	var food := FoodItem.new()
	food.food_type = type
	food.respawn_time = respawn_delay

	match type:
		FoodItem.FoodType.APPLE_RED:
			food.heal_amount = 20.0
		FoodItem.FoodType.ORANGE:
			food.speed_boost_percent = 0.25
		FoodItem.FoodType.PEAR:
			food.heal_amount = 15.0
		FoodItem.FoodType.GRAPES:
			pass  # Shield, no amount needed

	return food


func _spawn_food_at_position(position: Vector3, type: FoodItem.FoodType) -> FoodItem:
	var food := _create_food_item(type)
	food.position = position
	food.signal_respawn_requested.connect(_on_food_respawn_requested)
	add_child(food)
	_spawned_items.append(food)
	return food


func _on_food_respawn_requested(food: FoodItem) -> void:
	if not is_instance_valid(food):
		return
	var spawn_pos := _get_random_spawn_position(food)
	if spawn_pos == Vector3.ZERO:
		spawn_pos = food.global_position
	food.respawn_at(spawn_pos)


func spawn_food_at(position: Vector3, type: FoodItem.FoodType = FoodItem.FoodType.APPLE_RED) -> void:
	if _spawned_items.size() >= max_food_items:
		return

	var resolved_position := position
	if not _is_valid_spawn_position(resolved_position) or not _has_food_spacing(resolved_position, null):
		resolved_position = _get_random_spawn_position()
	if resolved_position != Vector3.ZERO:
		_spawn_food_at_position(resolved_position, type)
