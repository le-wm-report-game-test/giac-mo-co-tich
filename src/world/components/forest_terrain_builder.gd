extends Node

var _owner: Node3D = null


func setup(owner: Node3D) -> void:
	_owner = owner


func build(hill_zones: Array, zone_resolver: Callable) -> Dictionary:
	var heightmap := TerrainHeightmap.new()
	heightmap.name = "TerrainHeightmap"
	_owner.add_child(heightmap)
	var data := heightmap.build(hill_zones, zone_resolver)
	_owner.set("_terrain_heightmap", heightmap)
	_owner.set("_terrain_data", data)
	_build_collision(data)
	_build_visual_ground(data)
	_build_lake()
	return data


func _build_collision(data: Dictionary) -> void:
	if data.is_empty():
		push_error("ForestTerrainBuilder: terrain data missing")
		return
	var body := StaticBody3D.new()
	body.name = "GroundBody"
	_owner.add_child(body)
	var flat_collision := CollisionShape3D.new()
	flat_collision.shape = data["flat_collision_shape"] as Shape3D
	flat_collision.position = Vector3(0.0, -0.5, 0.0)
	body.add_child(flat_collision)
	var hill_meshes: Array = data["hill_collision_meshes"]
	for index in range(hill_meshes.size()):
		var hill_mesh := hill_meshes[index] as ArrayMesh
		var shape := hill_mesh.create_trimesh_shape()
		if shape == null:
			push_warning("ForestTerrainBuilder: hill collision %d failed" % index)
			continue
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)


func _build_visual_ground(data: Dictionary) -> void:
	var instance := MeshInstance3D.new()
	instance.name = "VisualGround"
	instance.mesh = data["mesh"] as Mesh
	var material := ShaderMaterial.new()
	material.shader = preload("res://src/world/ground_surface.gdshader")
	material.set_shader_parameter(
		"grass_texture",
		preload("res://Assets/Stylized Nature MegaKit[Standard]/glTF/Grass.png")
	)
	material.set_shader_parameter(
		"path_texture",
		preload("res://Assets/Stylized Nature MegaKit[Standard]/glTF/PathRocks_Diffuse.png")
	)
	material.set_shader_parameter(
		"rock_texture",
		preload("res://Assets/Stylized Nature MegaKit[Standard]/glTF/Rocks_Diffuse.png")
	)
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_owner.add_child(instance)


func _build_lake() -> void:
	var water := MeshInstance3D.new()
	water.name = "LakeWater"
	var plane := PlaneMesh.new()
	plane.size = Vector2(24.0, 24.0)
	plane.subdivide_width = 48
	plane.subdivide_depth = 48
	water.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = preload("res://src/world/water.gdshader")
	water.material_override = material
	water.position = Vector3(24.0, -0.4, -24.0)
	_owner.add_child(water)
	var barrier := StaticBody3D.new()
	barrier.name = "LakeCollisionBarrier"
	barrier.position = Vector3(24.0, 0.0, -24.0)
	var collision := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 8.0
	cylinder.height = 10.0
	collision.shape = cylinder
	barrier.add_child(collision)
	_owner.add_child(barrier)
