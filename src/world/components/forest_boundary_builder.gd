extends Node

const MAP_HALF: float = 50.0
const WALL_HEIGHT: float = 6.0
const WALL_THICKNESS: float = 1.0
const BOSS_CENTER := Vector3(-15.0, 0.0, -15.0)
const BOSS_RADIUS: float = 9.0
const BOSS_BOULDER_COUNT: int = 8
const BOSS_BOULDER_SCALE: float = 2.8

var _owner: Node3D = null


func setup(owner: Node3D) -> void:
	_owner = owner


func build_map_walls() -> void:
	var wall_specs: Array[Dictionary] = [
		{"position": Vector3(0.0, WALL_HEIGHT * 0.5, -MAP_HALF), "size": Vector3(102.0, WALL_HEIGHT, WALL_THICKNESS)},
		{"position": Vector3(0.0, WALL_HEIGHT * 0.5, MAP_HALF), "size": Vector3(102.0, WALL_HEIGHT, WALL_THICKNESS)},
		{"position": Vector3(-MAP_HALF, WALL_HEIGHT * 0.5, 0.0), "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 102.0)},
		{"position": Vector3(MAP_HALF, WALL_HEIGHT * 0.5, 0.0), "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, 102.0)},
	]
	var root := Node3D.new()
	root.name = "MapWalls"
	_owner.add_child(root)
	for spec in wall_specs:
		var body := StaticBody3D.new()
		body.position = spec["position"]
		body.collision_layer = 1
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec["size"]
		collision.shape = box
		body.add_child(collision)
		root.add_child(body)


func build_boss_enclosure() -> void:
	var root := Node3D.new()
	root.name = "BossArenaEnclosure"
	_owner.add_child(root)
	for index in range(BOSS_BOULDER_COUNT):
		var angle := TAU * float(index) / float(BOSS_BOULDER_COUNT)
		var position := BOSS_CENTER + Vector3(cos(angle), 0.0, sin(angle)) * BOSS_RADIUS
		root.add_child(_create_boulder(position))


func _create_boulder(position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = position
	body.scale = Vector3.ONE * BOSS_BOULDER_SCALE
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.6
	collision.shape = sphere
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 8
	mesh.rings = 6
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.45, 0.4, 0.35)
	material.roughness = 0.95
	visual.set_surface_override_material(0, material)
	body.add_child(visual)
	return body
