# terrain_generator.gd
class_name TerrainGenerator
extends Node3D

@export_group("Terrain Settings")
@export var map_size: Vector2 = Vector2(100.0, 100.0)
@export var subdivisions: int = 100
@export var height_scale: float = 4.2
@export var noise_frequency: float = 0.02
@export var noise_seed: int = 42

@export_group("Foliage Settings")
@export var num_trees: int = 200
@export var num_rocks: int = 50
@export var num_grass: int = 2000
@export var tree_scenes: Array[PackedScene] = [
	preload("res://Assets/Assets/gltf/Tree_1_A_Color1.gltf"),
	preload("res://Assets/Assets/gltf/Tree_2_A_Color1.gltf"),
	preload("res://Assets/Assets/gltf/Tree_3_A_Color1.gltf"),
	preload("res://Assets/Assets/gltf/Tree_4_A_Color1.gltf"),
	preload("res://Assets/Assets/gltf/Tree_1_C_Color1.gltf")
]
@export var rock_scenes: Array[PackedScene] = [
	preload("res://Assets/Assets/gltf/Rock_1_A_Color1.gltf"),
	preload("res://Assets/Assets/gltf/Rock_2_A_Color1.gltf"),
	preload("res://Assets/Assets/gltf/Rock_3_A_Color1.gltf")
]

@export_group("Road Settings")
@export var road_width: float = 2.0
@export var road_blend: float = 1.5
@export var road_clear_radius: float = 3.5

var _noise: FastNoiseLite
var _mesh_instance: MeshInstance3D
var _collision_shape: CollisionShape3D

func _ready() -> void:
	# 1. Initialize noise generator
	_noise = FastNoiseLite.new()
	_noise.seed = noise_seed
	_noise.frequency = noise_frequency
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX

	# 2. Build the deformed mesh
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "TerrainMesh"
	add_child(_mesh_instance)
	_generate_terrain_mesh()

	# 3. Create collision shape under a dynamic StaticBody3D
	var static_body := StaticBody3D.new()
	static_body.name = "TerrainStaticBody"
	add_child(static_body)

	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "TerrainCollision"
	static_body.add_child(_collision_shape)
	_generate_terrain_collision()

	# 4. Scatter foliage
	_scatter_foliage()

	# 5. Scatter 3D Grass using MultiMeshInstance3D for high performance
	_scatter_grass()

func get_height_at(x: float, z: float) -> float:
	if not _noise:
		return 0.0
	return _noise.get_noise_2d(x, z) * height_scale

func get_normal_at(x: float, z: float) -> Vector3:
	var delta := 0.1
	var h_left := get_height_at(x - delta, z)
	var h_right := get_height_at(x + delta, z)
	var h_down := get_height_at(x, z - delta)
	var h_up := get_height_at(x, z + delta)

	var tangent := Vector3(2.0 * delta, h_right - h_left, 0.0).normalized()
	var bitangent := Vector3(0.0, h_up - h_down, 2.0 * delta).normalized()
	return bitangent.cross(tangent).normalized()

func _generate_terrain_mesh() -> void:
	# Create basic plane mesh
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = map_size
	plane_mesh.subdivide_width = subdivisions
	plane_mesh.subdivide_depth = subdivisions

	# Deform vertices using MeshDataTool
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plane_mesh.get_mesh_arrays())
	
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(array_mesh, 0)

	# Search for road path
	var road_path: Path3D = get_node_or_null("RoadPath") as Path3D
	var has_road := road_path != null and road_path.curve != null and road_path.curve.point_count > 0

	for i in range(mdt.get_vertex_count()):
		var vertex := mdt.get_vertex(i)
		var height := get_height_at(vertex.x, vertex.z)
		var road_weight := 0.0
		
		if has_road:
			# 2-step query to find the closest point on the curve ignoring Y-skewing
			var closest := road_path.curve.get_closest_point(Vector3(vertex.x, 0.0, vertex.z))
			closest = road_path.curve.get_closest_point(Vector3(vertex.x, closest.y, vertex.z))
			
			var dist_xz := Vector2(vertex.x, vertex.z).distance_to(Vector2(closest.x, closest.z))
			
			if dist_xz < road_width + road_blend:
				var t := clampf((dist_xz - road_width) / road_blend, 0.0, 1.0)
				if dist_xz <= road_width:
					t = 0.0
				
				# Road height is determined exactly by the curve's Y height
				var road_height := closest.y
				height = lerpf(road_height, height, t)
				
				# Smooth transition for painting albedo
				road_weight = smoothstep(road_width + road_blend, road_width - 1.0, dist_xz)
		
		vertex.y = height
		mdt.set_vertex(i, vertex)
		mdt.set_vertex_color(i, Color(road_weight, 0.0, 0.0, 1.0))

	# Commit back to deformed mesh
	var deformed_mesh := ArrayMesh.new()
	mdt.commit_to_surface(deformed_mesh)

	# Recalculate normals and tangents for shader lighting
	var st := SurfaceTool.new()
	st.create_from(deformed_mesh, 0)
	st.generate_normals()
	st.generate_tangents()
	var final_mesh := st.commit()

	_mesh_instance.mesh = final_mesh

	# Apply slope material
	var material := ShaderMaterial.new()
	material.shader = load("res://src/world/terrain_shader.gdshader")
	material.set_shader_parameter("grass_albedo", load("res://demo/assets/textures/ground037_alb_ht.png"))
	material.set_shader_parameter("grass_normal", load("res://demo/assets/textures/ground037_nrm_rgh.png"))
	material.set_shader_parameter("rock_albedo", load("res://demo/assets/textures/rock023_alb_ht.png"))
	material.set_shader_parameter("rock_normal", load("res://demo/assets/textures/rock023_nrm_rgh.png"))
	material.set_shader_parameter("road_albedo", load("res://demo/assets/textures/ground037_alb_ht.png"))
	material.set_shader_parameter("road_normal", load("res://demo/assets/textures/ground037_nrm_rgh.png"))
	material.set_shader_parameter("road_color_tint", Color(0.48, 0.38, 0.28))
	material.set_shader_parameter("slope_threshold", 0.78)
	material.set_shader_parameter("slope_blend", 0.12)
	material.set_shader_parameter("uv_scale", Vector2(15.0, 15.0))
	
	_mesh_instance.material_override = material

func _generate_terrain_collision() -> void:
	if _mesh_instance and _mesh_instance.mesh:
		# Use Godot's built-in trimesh shape generator for perfect collision shape
		var trimesh_shape := _mesh_instance.mesh.create_trimesh_shape()
		_collision_shape.shape = trimesh_shape

func _scatter_foliage() -> void:
	# Check if road path exists for foliage clearing
	var road_path: Path3D = get_node_or_null("RoadPath") as Path3D
	var has_road := road_path != null and road_path.curve != null and road_path.curve.point_count > 0

	# Initialize local RNG with a fixed seed for reproducible scattering
	var rng := RandomNumberGenerator.new()
	rng.seed = noise_seed + 100 # Offset seed to differentiate from noise

	# Create a node to hold all foliage instances to keep scene tree organized
	var foliage_holder := Node3D.new()
	foliage_holder.name = "Foliage"
	add_child(foliage_holder)

	# Scatter Trees
	var trees_placed := 0
	var tree_attempts := 0
	var max_attempts := num_trees * 5
	
	while trees_placed < num_trees and tree_attempts < max_attempts:
		tree_attempts += 1
		var rx := rng.randf_range(-map_size.x / 2.0, map_size.x / 2.0)
		var rz := rng.randf_range(-map_size.y / 2.0, map_size.y / 2.0)
		
		# Prevent placing trees directly on the spawn point (center)
		if Vector2(rx, rz).length() < 6.0:
			continue

		# Prevent placing trees on/near the road path
		if has_road:
			# 2-step query for XZ accuracy
			var closest := road_path.curve.get_closest_point(Vector3(rx, 0.0, rz))
			closest = road_path.curve.get_closest_point(Vector3(rx, closest.y, rz))
			var dist_xz := Vector2(rx, rz).distance_to(Vector2(closest.x, closest.z))
			if dist_xz < road_clear_radius:
				continue

		var normal := get_normal_at(rx, rz)
		# Only place trees on relatively flat ground (normal Y close to 1.0)
		if normal.y < 0.82:
			continue

		var height := get_height_at(rx, rz)
		var tree_idx := rng.randi() % tree_scenes.size()
		var tree_scene := tree_scenes[tree_idx]

		if tree_scene:
			var tree_inst := tree_scene.instantiate() as Node3D
			tree_inst.global_position = Vector3(rx, height, rz)
			
			# Random scaling and Y rotation for a natural forest look
			var s := rng.randf_range(0.8, 1.3)
			tree_inst.scale = Vector3(s, s, s)
			tree_inst.rotation.y = rng.randf_range(0.0, TAU)
			
			foliage_holder.add_child(tree_inst)
			
			# Generate static collision for trees so player cannot walk through them
			_create_static_collision_for_node(tree_inst)
			
			trees_placed += 1

	# Scatter Rocks
	var rocks_placed := 0
	var rock_attempts := 0
	
	while rocks_placed < num_rocks and rock_attempts < max_attempts:
		rock_attempts += 1
		var rx := rng.randf_range(-map_size.x / 2.0, map_size.x / 2.0)
		var rz := rng.randf_range(-map_size.y / 2.0, map_size.y / 2.0)
		
		if Vector2(rx, rz).length() < 6.0:
			continue

		# Prevent placing rocks on/near the road path
		if has_road:
			# 2-step query for XZ accuracy
			var closest := road_path.curve.get_closest_point(Vector3(rx, 0.0, rz))
			closest = road_path.curve.get_closest_point(Vector3(rx, closest.y, rz))
			var dist_xz := Vector2(rx, rz).distance_to(Vector2(closest.x, closest.z))
			if dist_xz < road_clear_radius:
				continue

		var normal := get_normal_at(rx, rz)
		# Rocks can sit on slightly steeper slopes
		if normal.y < 0.70:
			continue

		var height := get_height_at(rx, rz)
		if not rock_scenes.is_empty():
			var rock_idx := rng.randi() % rock_scenes.size()
			var rock_scene := rock_scenes[rock_idx]
			if rock_scene:
				var rock_inst := rock_scene.instantiate() as Node3D
				# Bury rocks slightly for a more natural look
				rock_inst.global_position = Vector3(rx, height - rng.randf_range(0.1, 0.4), rz)
				
				var s := rng.randf_range(0.7, 1.8)
				rock_inst.scale = Vector3(s, s, s)
				rock_inst.rotation = Vector3(
					rng.randf_range(-0.1, 0.1),
					rng.randf_range(0.0, TAU),
					rng.randf_range(-0.1, 0.1)
				)
				
				foliage_holder.add_child(rock_inst)
				_create_static_collision_for_node(rock_inst)
				rocks_placed += 1

func _create_static_collision_for_node(node: Node3D) -> void:
	# Recursively search for MeshInstance3D to generate collision
	var meshes: Array[MeshInstance3D] = []
	_find_meshes_recursive(node, meshes)
	
	for mesh_inst in meshes:
		if mesh_inst.mesh:
			var body := StaticBody3D.new()
			var col := CollisionShape3D.new()
			col.shape = mesh_inst.mesh.create_trimesh_shape()
			body.add_child(col)
			mesh_inst.add_child(body)

func _find_meshes_recursive(node: Node, out_meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out_meshes.append(node)
	for child in node.get_children():
		_find_meshes_recursive(child, out_meshes)

func _scatter_grass() -> void:
	# Check if road path exists for grass clearing
	var road_path: Path3D = get_node_or_null("RoadPath") as Path3D
	var has_road := road_path != null and road_path.curve != null and road_path.curve.point_count > 0

	var multimesh_instance := MultiMeshInstance3D.new()
	multimesh_instance.name = "GrassMultiMesh"
	add_child(multimesh_instance)

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _create_grass_mesh()
	multimesh_instance.material_override = _create_grass_material()

	# Scatter instances of grass clumps
	var count := num_grass
	multimesh.instance_count = count

	var rng := RandomNumberGenerator.new()
	rng.seed = noise_seed + 200

	var placed := 0
	var attempts := 0
	var max_attempts := count * 10

	while placed < count and attempts < max_attempts:
		attempts += 1
		var rx := rng.randf_range(-map_size.x / 2.0, map_size.x / 2.0)
		var rz := rng.randf_range(-map_size.y / 2.0, map_size.y / 2.0)

		# Avoid spawn point
		if Vector2(rx, rz).length() < 4.0:
			continue

		# Avoid road path
		if has_road:
			# 2-step query for XZ accuracy
			var closest := road_path.curve.get_closest_point(Vector3(rx, 0.0, rz))
			closest = road_path.curve.get_closest_point(Vector3(rx, closest.y, rz))
			var dist_xz := Vector2(rx, rz).distance_to(Vector2(closest.x, closest.z))
			if dist_xz < road_clear_radius:
				continue

		var normal := get_normal_at(rx, rz)
		# Only place grass on relatively flat ground (normal Y close to 1.0)
		if normal.y < 0.85:
			continue

		var height := get_height_at(rx, rz)

		var xform := Transform3D()
		# Add a bit of random Y rotation
		xform = xform.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
		# Scale slightly randomly
		var s := rng.randf_range(0.6, 1.2)
		xform = xform.scaled(Vector3(s, s, s))
		# Position on terrain
		xform.origin = Vector3(rx, height, rz)

		multimesh.set_instance_transform(placed, xform)
		placed += 1

	multimesh.visible_instance_count = placed
	multimesh_instance.multimesh = multimesh

func _create_grass_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Create 3 intersecting vertical blades of grass
	var num_blades := 3
	var grass_color := Color(0.24, 0.58, 0.16) # Natural warm green
	
	for i in num_blades:
		var angle := float(i) * PI / float(num_blades)
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		
		# Define vertices for a vertical triangle (blade of grass)
		var left := dir * -0.12
		var right := dir * 0.12
		var top := Vector3(0.0, randf_range(0.35, 0.55), 0.0) + (dir * randf_range(-0.04, 0.04))
		
		# Front face
		st.set_color(grass_color)
		st.add_vertex(left)
		st.add_vertex(top)
		st.add_vertex(right)
		
		# Back face
		st.set_color(grass_color)
		st.add_vertex(right)
		st.add_vertex(top)
		st.add_vertex(left)
		
	st.generate_normals()
	return st.commit()

func _create_grass_material() -> Material:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0)
	mat.vertex_color_use_as_albedo = true # Use the warm green baked color
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED # Render both sides of the grass blades
	return mat
