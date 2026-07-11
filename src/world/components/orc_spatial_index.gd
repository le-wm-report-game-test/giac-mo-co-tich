extends RefCounted

const CELL_SIZE: float = 4.0

static var _cached_frame: int = -1
static var _grid: Dictionary = {}


static func fill_neighbors(
	tree: SceneTree,
	world_position: Vector3,
	output: Array[Node]
) -> void:
	_rebuild_if_needed(tree)
	output.clear()
	var center := _cell_for(world_position)
	for x_offset in range(-1, 2):
		for z_offset in range(-1, 2):
			var cell := center + Vector2i(x_offset, z_offset)
			var bucket: Array = _grid.get(cell, [])
			for instance_id in bucket:
				var candidate := instance_from_id(int(instance_id)) as Node
				if is_instance_valid(candidate):
					output.append(candidate)


static func _rebuild_if_needed(tree: SceneTree) -> void:
	var frame := Engine.get_physics_frames()
	if frame == _cached_frame:
		return
	_cached_frame = frame
	for bucket in _grid.values():
		(bucket as Array).clear()
	for candidate in tree.get_nodes_in_group("orc_mobs"):
		if not is_instance_valid(candidate) or not (candidate is Node3D):
			continue
		var cell := _cell_for((candidate as Node3D).global_position)
		if not _grid.has(cell):
			_grid[cell] = []
		(_grid[cell] as Array).append(candidate.get_instance_id())


static func _cell_for(world_position: Vector3) -> Vector2i:
	return Vector2i(
		floori(world_position.x / CELL_SIZE),
		floori(world_position.z / CELL_SIZE)
	)
