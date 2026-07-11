extends Node

const MAP_HALF: float = 50.0
const ZONE_CLEARING: int = 1
const ZONE_PATH: int = 2
const ZONE_LAKE: int = 4

var _owner: Node = null
var _rng: RandomNumberGenerator = null


func setup(owner: Node, rng: RandomNumberGenerator) -> void:
	_owner = owner
	_rng = rng


func scatter_all() -> void:
	var grass_count := roundi(
		int(_owner.get("num_grass_clumps"))
		* float(_owner.get("grass_clump_density_multiplier"))
	)
	_scatter_group(_owner.get("grass_clump_meshes"), grass_count, false, 0.6, 1.1, true)
	_scatter_group(_owner.get("flower_meshes"), int(_owner.get("num_flowers")), false, 0.8, 1.2)
	_scatter_group(_owner.get("mushroom_meshes"), int(_owner.get("num_mushrooms")), false, 0.7, 1.1)
	_scatter_group(
		_owner.get("rock_meshes"),
		int(_owner.get("num_rocks")),
		false,
		0.8,
		1.5,
		false,
		0.6,
		0.3,
		"Rock"
	)


func _scatter_group(
	items: Array,
	count: int,
	avoid_clearing: bool,
	scale_min: float,
	scale_max: float,
	apply_wind: bool = false,
	collision_radius_scale: float = 0.0,
	collision_height_scale: float = 0.0,
	name_prefix: String = "Decoration"
) -> void:
	if items.is_empty():
		return
	var transforms_by_mesh: Dictionary = {}
	var placed := 0
	var attempts := 0
	while placed < count and attempts < count * 10:
		attempts += 1
		var x := _rng.randf_range(-MAP_HALF + 0.5, MAP_HALF - 0.5)
		var z := _rng.randf_range(-MAP_HALF + 0.5, MAP_HALF - 0.5)
		var zone := int(_owner.call("_get_zone", x, z))
		if zone == ZONE_PATH or zone == ZONE_LAKE:
			continue
		if avoid_clearing and zone == ZONE_CLEARING:
			continue
		var mesh := items[_rng.randi_range(0, items.size() - 1)] as Mesh
		if mesh == null:
			continue
		var scale_value := _rng.randf_range(scale_min, scale_max)
		var transform := _create_transform(x, z, scale_value)
		if collision_radius_scale > 0.0:
			_add_collidable_visual(
				mesh,
				transform,
				scale_value,
				collision_radius_scale,
				collision_height_scale,
				placed,
				name_prefix
			)
		else:
			_append_transform(transforms_by_mesh, mesh, transform)
		placed += 1
	_spawn_batches(transforms_by_mesh, apply_wind, name_prefix)


func _create_transform(x: float, z: float, scale_value: float) -> Transform3D:
	var height := float(_owner.call("_get_hill_height", x, z))
	var rotation := _rng.randf_range(0.0, TAU)
	var basis := Basis(Vector3.UP, rotation).scaled(Vector3.ONE * scale_value)
	return Transform3D(basis, Vector3(x, height, z))


func _append_transform(batches: Dictionary, mesh: Mesh, transform: Transform3D) -> void:
	if not batches.has(mesh):
		var transforms: Array[Transform3D] = []
		batches[mesh] = transforms
	var transforms: Array[Transform3D] = batches[mesh]
	transforms.append(transform)


func _spawn_batches(batches: Dictionary, apply_wind: bool, prefix: String) -> void:
	var index := 0
	for mesh_value in batches:
		var mesh := mesh_value as Mesh
		var transforms: Array[Transform3D] = batches[mesh_value]
		var material: Material = null
		if apply_wind and mesh.get_surface_count() > 0:
			material = _owner.call("_create_wind_material", mesh.surface_get_material(0)) as Material
		_spawn_multimesh(mesh, transforms, material, "%sBatch_%d" % [prefix, index])
		index += 1


func _spawn_multimesh(
	mesh: Mesh,
	transforms: Array[Transform3D],
	material: Material,
	node_name: String
) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	multimesh.custom_aabb = AABB(Vector3(-50.0, -2.0, -50.0), Vector3(100.0, 12.0, 100.0))
	for index in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.material_override = material
	_owner.add_child(instance)


func _add_collidable_visual(
	mesh: Mesh,
	transform: Transform3D,
	scale_value: float,
	radius_scale: float,
	height_scale: float,
	index: int,
	prefix: String
) -> void:
	var instance := MeshInstance3D.new()
	instance.name = "%sMesh_%d" % [prefix, index]
	instance.mesh = mesh
	instance.transform = transform
	_owner.add_child(instance)
	_add_collision(transform, scale_value, radius_scale, height_scale, index, prefix)


func _add_collision(
	transform: Transform3D,
	scale_value: float,
	radius_scale: float,
	height_scale: float,
	index: int,
	prefix: String
) -> void:
	var body := StaticBody3D.new()
	body.name = "%sBody_%d" % [prefix, index]
	body.position = transform.origin
	body.add_to_group("rock_obstacles")
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius_scale * scale_value
	collision.shape = sphere
	collision.position.y = height_scale * scale_value
	body.add_child(collision)
	_owner.add_child(body)
