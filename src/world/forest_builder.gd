# forest_builder.gd
# Xây dựng khu rừng modular 60x60m sử dụng Modular Terrain Collection (chủ đề Hilly)
# Cây cối: Stylized Nature MegaKit (.gltf) — texture stylized đẹp, có thân và lá riêng
# Bố cục: 1 Spawn Clearing trung tâm + 2 Combat Arenas + 1 Boss Arena + đường mòn
class_name ForestBuilder
extends Node3D

# ─── Terrain Tile Meshes ───────────────────────────────────────────────────
@export_group("Terrain Tiles")
@export var grass_floor_mesh: Mesh = preload("res://Assets/modular_terrain_collection/Hilly_Terrain_Grass_Floor.obj")
@export var path_center_mesh: Mesh = preload("res://Assets/modular_terrain_collection/Hilly_Terrain_Path_Center.obj")
@export var path_side_mesh: Mesh = preload("res://Assets/modular_terrain_collection/Hilly_Terrain_Path_Side.obj")
@export var path_corner_inner_mesh: Mesh = preload("res://Assets/modular_terrain_collection/Hilly_Terrain_Path_Corner_Inner_2x2.obj")
@export var path_corner_outer_mesh: Mesh = preload("res://Assets/modular_terrain_collection/Hilly_Terrain_Path_Corner_Outer_2x2.obj")
@export var hill_side_gentle_mesh: Mesh = preload("res://Assets/modular_terrain_collection/Hilly_Terrain_Hill_Side_Gentle.obj")
@export var hill_corner_inner_mesh: Mesh = preload("res://Assets/modular_terrain_collection/Hilly_Terrain_Hill_Corner_Inner_2x2.obj")
@export var hill_corner_outer_mesh: Mesh = preload("res://Assets/modular_terrain_collection/Hilly_Terrain_Hill_Corner_Outer_2x2.obj")

# ─── Tree Scenes (Stylized Nature MegaKit .gltf) ─────────────────────────
@export_group("Tree Props")
@export var tree_scenes: Array[PackedScene] = [
	preload("res://Assets/Stylized Nature MegaKit[Standard]/glTF/Pine_1.gltf"),
	preload("res://Assets/Stylized Nature MegaKit[Standard]/glTF/Pine_2.gltf"),
	preload("res://Assets/Stylized Nature MegaKit[Standard]/glTF/Pine_3.gltf"),
	preload("res://Assets/Stylized Nature MegaKit[Standard]/glTF/Pine_4.gltf"),
	preload("res://Assets/Stylized Nature MegaKit[Standard]/glTF/Pine_5.gltf"),
]
@export var bush_scenes: Array[PackedScene] = [
	preload("res://Assets/Stylized Nature MegaKit[Standard]/glTF/Bush_Common.gltf"),
	preload("res://Assets/Stylized Nature MegaKit[Standard]/glTF/Bush_Common_Flowers.gltf"),
	preload("res://Assets/Stylized Nature MegaKit[Standard]/glTF/Fern_1.gltf"),
	preload("res://Assets/Stylized Nature MegaKit[Standard]/glTF/Plant_1.gltf"),
	preload("res://Assets/Stylized Nature MegaKit[Standard]/glTF/Plant_1_Big.gltf"),
]

# ─── Decoration Prop Meshes ────────────────────────────────────────────────
@export_group("Decoration Props")
@export var grass_clump_meshes: Array[Mesh] = [
	preload("res://Assets/modular_terrain_collection/Hilly_Prop_Grass_Clump_1.obj"),
	preload("res://Assets/modular_terrain_collection/Hilly_Prop_Grass_Clump_2.obj"),
]
@export var flower_meshes: Array[Mesh] = [
	preload("res://Assets/modular_terrain_collection/Hilly_Prop_Flower_Daisy.obj"),
	preload("res://Assets/modular_terrain_collection/Hilly_Prop_Flower_Rose.obj"),
	preload("res://Assets/modular_terrain_collection/Hilly_Prop_Flower_Tulip.obj"),
]
@export var mushroom_meshes: Array[Mesh] = [
	preload("res://Assets/modular_terrain_collection/Hilly_Prop_Mushroom_1.obj"),
	preload("res://Assets/modular_terrain_collection/Hilly_Prop_Mushroom_2.obj"),
]
@export var rock_meshes: Array[Mesh] = [
	preload("res://Assets/modular_terrain_collection/Hilly_Prop_Rock_1.obj"),
	preload("res://Assets/modular_terrain_collection/Hilly_Prop_Rock_2.obj"),
	preload("res://Assets/modular_terrain_collection/Hilly_Prop_Rock_3.obj"),
]
@export var boulder_meshes: Array[Mesh] = [
	preload("res://Assets/modular_terrain_collection/Shared_Prop_Boulder_1.obj"),
	preload("res://Assets/modular_terrain_collection/Shared_Prop_Boulder_2.obj"),
	preload("res://Assets/modular_terrain_collection/Shared_Prop_Boulder_3.obj"),
]
@export var stump_mesh: Mesh = preload("res://Assets/modular_terrain_collection/Hilly_Prop_Stump.obj")

# ─── Forest Settings ───────────────────────────────────────────────────────
@export_group("Forest Settings")
@export var num_trees: int = 105
@export var num_bushes: int = 200
@export var num_grass_clumps: int = 350
@export var num_flowers: int = 150
@export var num_mushrooms: int = 80
@export var num_rocks: int = 100
@export var num_boulders: int = 25
@export var num_orcs: int = 24
@export var random_seed: int = 2025
@export_range(0.0, 1.0, 0.01) var large_tree_spawn_multiplier: float = 0.75
@export_range(1.0, 3.0, 0.05) var large_tree_scale_threshold: float = 1.65
@export_range(1.0, 8.0, 0.1) var tree_min_spacing: float = 4.2
@export_range(0.0, 5.0, 0.1) var tree_large_spacing_bonus: float = 1.1
@export_range(0.0, 1.0, 0.01) var grass_clump_density_multiplier: float = 0.90

# ─── Map Constants ─────────────────────────────────────────────────────────
const MAP_HALF: float = 50.0
const TILE_SIZE: float = 1.0

# Zone enum để dễ đọc
enum Zone { FOREST, CLEARING, PATH, HILL }

# Bố cục clearing & path (tọa độ XZ, trục Y = 0 là mặt đất phẳng)
# Spawn Clearing: trung tâm, bán kính 6m
# East Arena:  center (18, 0), bán kính 5m
# South Arena: center (0, 18), bán kính 5m
# Boss Arena:  center (-15, -15), bán kính 7m

const SPAWN_CENTER: Vector2 = Vector2(0.0, 0.0)
const SPAWN_RADIUS: float = 7.0

const EAST_ARENA_CENTER: Vector2 = Vector2(18.0, 0.0)
const EAST_ARENA_RADIUS: float = 5.5

const SOUTH_ARENA_CENTER: Vector2 = Vector2(0.0, 18.0)
const SOUTH_ARENA_RADIUS: float = 5.5

const BOSS_ARENA_CENTER: Vector2 = Vector2(-15.0, -15.0)
const BOSS_ARENA_RADIUS: float = 7.0

# Path width
const PATH_HALF_WIDTH: float = 1.5

# Hill zones (center XZ, bán kính, height offset)
const HILL_ZONES: Array = [
	{"center": Vector2(10.0, -10.0), "radius": 5.0, "height": 1.5},
	{"center": Vector2(-10.0, 12.0), "radius": 4.0, "height": 1.2},
	{"center": Vector2(22.0, 14.0), "radius": 4.5, "height": 1.0},
	{"center": Vector2(-20.0, 5.0), "radius": 3.5, "height": 1.3},
]

# ─── Materials ─────────────────────────────────────────────────────────────
var _mat_grass: ShaderMaterial
var _mat_dirt: ShaderMaterial
var _mat_tree: StandardMaterial3D

var _rng: RandomNumberGenerator

# Lưu trữ vị trí và scale cây để kiểm tra spawn enemy (tránh che khuất gameplay)
var _tree_positions: Array[Vector2] = []
var _tree_scales: Array[float] = []

# ─── Ready ─────────────────────────────────────────────────────────────────
var _terrain_heightmap: TerrainHeightmap = null
var _terrain_data: Dictionary = {}

func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = random_seed

	add_to_group("forest")
	_setup_materials()
	# Build the heightmap once and share its mesh + collision shape across
	# the visual ground, the physics body and downstream spawners.
	_terrain_heightmap = TerrainHeightmap.new()
	_terrain_heightmap.name = "TerrainHeightmap"
	add_child(_terrain_heightmap)
	_terrain_data = _terrain_heightmap.build(HILL_ZONES)
	_build_ground_floor()
	_build_under_floor()
	_build_ground_collision()
	_scatter_trees()
	_scatter_bushes()
	_scatter_decorations()
	_scatter_boulders()
	_spawn_animals()
	_spawn_orcs()


# ─── Materials Setup ────────────────────────────────────────────────────────
func _setup_materials() -> void:
	_mat_grass = _create_ground_material(Color("#385637"), Color("#668455"), 0.92, 0.2)
	_mat_dirt = _create_ground_material(Color("#6E543A"), Color("#A0774D"), 0.88, 0.18)

	_mat_tree = StandardMaterial3D.new()
	_mat_tree.albedo_color = Color("#294A28")
	_mat_tree.roughness = 0.85

func _create_ground_material(
	base_color: Color,
	variation_color: Color,
	roughness: float,
	variation_strength: float
) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://src/world/ground_surface.gdshader")
	material.set_shader_parameter("base_color", base_color)
	material.set_shader_parameter("variation_color", variation_color)
	material.set_shader_parameter("surface_roughness", roughness)
	material.set_shader_parameter("variation_strength", variation_strength)
	return material


# ─── Ground Floor (MultiMesh cỏ phẳng + đường mòn) ─────────────────────────
func _build_ground_floor() -> void:
	# Tính số lượng tile
	var total_tiles: int = int(MAP_HALF * 2) * int(MAP_HALF * 2)

	# Đếm grass và path tiles trước
	var grass_positions: Array[Transform3D] = []
	var path_positions: Array[Transform3D] = []

	var start: int = int(-MAP_HALF)
	var end: int = int(MAP_HALF)

	for x_i in range(start, end):
		for z_i in range(start, end):
			var xf: float = float(x_i) + 0.5
			var zf: float = float(z_i) + 0.5
			var pos := Vector3(xf, 0.0, zf)

			var zone := _get_zone(xf, zf)
			var height_offset: float = _get_hill_height(xf, zf)
			pos.y = height_offset

			var t := Transform3D(Basis.IDENTITY, pos)

			if zone == Zone.PATH:
				path_positions.append(t)
			else:
				grass_positions.append(t)

	# Render grass tiles
	if grass_positions.size() > 0 and grass_floor_mesh != null:
		_spawn_multimesh(grass_floor_mesh, grass_positions, _mat_grass, "GrassTiles")

	# Render path tiles
	if path_positions.size() > 0 and path_center_mesh != null:
		_spawn_multimesh(path_center_mesh, path_positions, _mat_dirt, "PathTiles")


# ─── Nền lót dưới mặt đất (Under-floor để che khe hở) ──────────────────────────
func _build_under_floor() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "UnderFloor"
	
	var plane := PlaneMesh.new()
	# Tạo diện tích lớn hơn map một chút để phủ kín hoàn toàn
	plane.size = Vector2(MAP_HALF * 2.0 + 10.0, MAP_HALF * 2.0 + 10.0)
	mi.mesh = plane
	
	var mat := StandardMaterial3D.new()
	# Màu xanh cỏ đậm hoặc đất tối để khi hở khe nhìn tự nhiên như đổ bóng
	mat.albedo_color = Color("#17251C")
	mat.roughness = 1.0
	mi.material_override = mat
	
	# Đặt thấp hơn mặt đất phẳng một chút để tránh hiện tượng Z-fighting
	mi.position = Vector3(0.0, -0.02, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ─── Collision cho mặt đất ─────────────────────────────────────────────────
# Two-layer architecture (see _build_ground_floor):
#   1. VISUAL: 10,000 grass / path tiles at their heightmap-sampled Y.
#   2. COLLISION: a single heightmap-based StaticBody. The tiles are pure
#      decoration — they do NOT add their own CollisionShape3D. The previous
#      implementation stacked 1m × 1m BoxShape3Ds on top of every tile with
#      height_offset > 0.05, creating vertical step walls the player capsule
#      (radius 0.4m) could not climb. That "bậc thang" bug is fixed here by
#      using one smooth BoxShape3D for the flat ground plus one lightweight
#      ConcavePolygonShape3D per hill (built from a small fan mesh).
func _build_ground_collision() -> void:
	if _terrain_heightmap == null or _terrain_data.is_empty():
		push_error("ForestBuilder: TerrainHeightmap instance missing")
		return

	var ground_body := StaticBody3D.new()
	ground_body.name = "GroundBody"
	add_child(ground_body)

	# Flat base box covering the whole map. The box top sits exactly at Y=0
	# so flat terrain (where sample_height returns 0) matches the player
	# capsule resting Y=0 too.
	var flat_col := CollisionShape3D.new()
	flat_col.shape = _terrain_data["flat_collision_shape"]
	flat_col.position = Vector3(0.0, -0.5, 0.0)
	ground_body.add_child(flat_col)

	# One ConcavePolygonShape3D per hill. Each hill mesh is small
	# (~30 triangles) so Jolt compiles it in microseconds.
	var hill_meshes: Array = _terrain_data["hill_collision_meshes"]
	for i in range(hill_meshes.size()):
		var hill_mesh: ArrayMesh = hill_meshes[i]
		var hill_shape: Shape3D = hill_mesh.create_trimesh_shape()
		if hill_shape == null:
			push_warning("ForestBuilder: failed to build hill collision mesh %d; skipping" % i)
			continue
		var hill_col := CollisionShape3D.new()
		hill_col.shape = hill_shape
		# Mesh vertices are already in world coordinates (center.x, height, center.z).
		# No additional offset on the CollisionShape3D node or the shape would be
		# double-translated away from where the player can step.
		hill_col.position = Vector3.ZERO
		ground_body.add_child(hill_col)


# Preload Wind Sway Shader
var _wind_shader: Shader = preload("res://src/world/wind_sway.gdshader")

func _configure_geometry_for_rendering(node: Node, cull_margin: float = 2.0) -> void:
	if node is GeometryInstance3D:
		var gi := node as GeometryInstance3D
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		gi.extra_cull_margin = maxf(gi.extra_cull_margin, cull_margin)
	for child in node.get_children():
		_configure_geometry_for_rendering(child, cull_margin)


func _create_wind_material(original_material: Material) -> ShaderMaterial:
	var tex: Texture2D = null
	var color := Color(1.0, 1.0, 1.0, 1.0)
	var normal_tex: Texture2D = null
	var roughness_tex: Texture2D = null
	var metallic_tex: Texture2D = null
	var ao_tex: Texture2D = null
	var normal_enabled := false
	var ao_enabled := false
	var normal_scale := 1.0
	var roughness := 0.85
	var metallic := 0.0
	var roughness_channel := 0
	var metallic_channel := 0
	var ao_channel := 0
	var uv_scale := Vector3.ONE
	var uv_offset := Vector3.ZERO
	if original_material is BaseMaterial3D:
		var base_mat := original_material as BaseMaterial3D
		tex = base_mat.albedo_texture
		color = base_mat.albedo_color
		normal_tex = base_mat.normal_texture
		roughness_tex = base_mat.roughness_texture
		metallic_tex = base_mat.metallic_texture
		ao_tex = base_mat.ao_texture
		normal_enabled = base_mat.normal_enabled
		ao_enabled = base_mat.ao_enabled
		normal_scale = base_mat.normal_scale
		roughness = base_mat.roughness
		metallic = base_mat.metallic
		roughness_channel = int(base_mat.roughness_texture_channel)
		metallic_channel = int(base_mat.metallic_texture_channel)
		ao_channel = int(base_mat.ao_texture_channel)
		uv_scale = base_mat.uv1_scale
		uv_offset = base_mat.uv1_offset
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = _wind_shader
	if tex != null:
		shader_mat.set_shader_parameter("albedo_texture", tex)
	if normal_tex != null:
		shader_mat.set_shader_parameter("normal_texture", normal_tex)
	if roughness_tex != null:
		shader_mat.set_shader_parameter("roughness_texture", roughness_tex)
	if metallic_tex != null:
		shader_mat.set_shader_parameter("metallic_texture", metallic_tex)
	if ao_tex != null:
		shader_mat.set_shader_parameter("ao_texture", ao_tex)
	shader_mat.set_shader_parameter("albedo_color", color)
	shader_mat.set_shader_parameter("has_normal_texture", normal_enabled and normal_tex != null)
	shader_mat.set_shader_parameter("has_roughness_texture", roughness_tex != null)
	shader_mat.set_shader_parameter("has_metallic_texture", metallic_tex != null)
	shader_mat.set_shader_parameter("has_ao_texture", ao_enabled and ao_tex != null)
	shader_mat.set_shader_parameter("normal_scale", normal_scale)
	shader_mat.set_shader_parameter("base_roughness", roughness)
	shader_mat.set_shader_parameter("base_metallic", metallic)
	shader_mat.set_shader_parameter("roughness_channel", roughness_channel)
	shader_mat.set_shader_parameter("metallic_channel", metallic_channel)
	shader_mat.set_shader_parameter("ao_channel", ao_channel)
	shader_mat.set_shader_parameter("uv1_scale", uv_scale)
	shader_mat.set_shader_parameter("uv1_offset", uv_offset)
	shader_mat.set_shader_parameter("alpha_multiplier", 1.0)
	return shader_mat


# Đệ quy duyệt qua các Mesh con và áp dụng ShaderMaterial giữ nguyên texture gốc và màu sắc từng surface
func _apply_wind_shader(node: Node) -> void:
	if node is MeshInstance3D:
		_configure_geometry_for_rendering(node, 5.0)
		var mesh: Mesh = node.mesh
		if mesh != null:
			for i in range(mesh.get_surface_count()):
				node.set_surface_override_material(i, _create_wind_material(node.get_active_material(i)))
					
	for child in node.get_children():
		_apply_wind_shader(child)


# ─── Scatter Trees (MegaKit .gltf PackedScene) ──────────────────────────────
func _scatter_trees() -> void:
	if tree_scenes.is_empty():
		return

	# Reset stored tree data for spawn checking
	_tree_positions.clear()
	_tree_scales.clear()

	var placed: int = 0
	var attempts: int = 0
	var max_attempts: int = num_trees * 16

	while placed < num_trees and attempts < max_attempts:
		attempts += 1
		var x: float = _rng.randf_range(-MAP_HALF + 2.0, MAP_HALF - 2.0)
		var z: float = _rng.randf_range(-MAP_HALF + 2.0, MAP_HALF - 2.0)

		var zone := _get_zone(x, z)
		# Không đặt cây trong clearing hay path
		if zone == Zone.CLEARING or zone == Zone.PATH:
			continue

		var height: float = _get_hill_height(x, z)
		var scene_idx: int = _rng.randi() % tree_scenes.size()
		var scene: PackedScene = tree_scenes[scene_idx]
		if scene == null:
			continue

		var scale_val: float = _rng.randf_range(1.2, 2.0)  # Tree height 8-12m (base ~6m * 1.2-2.0)
		var is_large_tree: bool = scale_val >= large_tree_scale_threshold
		if is_large_tree and _rng.randf() > large_tree_spawn_multiplier:
			continue

		var tree_pos_2d := Vector2(x, z)
		if not _can_place_tree(tree_pos_2d, scale_val, _tree_positions, _tree_scales):
			continue

		var rot_y: float = _rng.randf_range(0.0, TAU)

		# instantiate() giữ nguyên toàn bộ scene gốc (materials, textures)
		var tree_node: Node3D = scene.instantiate() as Node3D
		if tree_node == null:
			continue
		tree_node.position = Vector3(x, height, z)
		tree_node.rotation.y = rot_y
		tree_node.scale = Vector3(scale_val, scale_val, scale_val)
		tree_node.add_to_group("trees")
		_apply_wind_shader(tree_node)
		add_child(tree_node)

		# Collision cho thân cây
		var tree_body := StaticBody3D.new()
		tree_body.position = tree_node.position
		var tree_col := CollisionShape3D.new()
		var tree_cap := CapsuleShape3D.new()
		tree_cap.radius = 0.5 * scale_val  # Thân cây to hơn
		tree_cap.height = 4.0 * scale_val  # Cao hơn
		tree_col.shape = tree_cap
		tree_col.position.y = 2.0 * scale_val
		tree_body.add_child(tree_col)
		add_child(tree_body)

		_tree_positions.append(tree_pos_2d)
		_tree_scales.append(scale_val)
		placed += 1


func _can_place_tree(
	tree_pos: Vector2,
	tree_scale: float,
	existing_positions: Array[Vector2],
	existing_scales: Array[float]
) -> bool:
	var required_spacing: float = tree_min_spacing
	if tree_scale >= large_tree_scale_threshold:
		required_spacing += tree_large_spacing_bonus

	for i in range(existing_positions.size()):
		var other_spacing: float = tree_min_spacing
		if existing_scales[i] >= large_tree_scale_threshold:
			other_spacing += tree_large_spacing_bonus
		if tree_pos.distance_to(existing_positions[i]) < maxf(required_spacing, other_spacing):
			return false

	return true


# ─── Scatter Bushes (MegaKit .gltf PackedScene) ─────────────────────────────
func _scatter_bushes() -> void:
	if bush_scenes.is_empty():
		return

	var placed: int = 0
	var attempts: int = 0
	var max_attempts: int = num_bushes * 10

	while placed < num_bushes and attempts < max_attempts:
		attempts += 1
		var x: float = _rng.randf_range(-MAP_HALF + 1.0, MAP_HALF - 1.0)
		var z: float = _rng.randf_range(-MAP_HALF + 1.0, MAP_HALF - 1.0)

		var zone := _get_zone(x, z)
		if zone == Zone.PATH:
			continue

		var height: float = _get_hill_height(x, z)
		var scene_idx: int = _rng.randi() % bush_scenes.size()
		var scene: PackedScene = bush_scenes[scene_idx]
		if scene == null:
			continue

		var scale_val: float = _rng.randf_range(0.7, 1.2)
		var bush_node: Node3D = scene.instantiate() as Node3D
		if bush_node == null:
			continue
		bush_node.position = Vector3(x, height, z)
		bush_node.rotation.y = _rng.randf_range(0.0, TAU)
		bush_node.scale = Vector3(scale_val, scale_val, scale_val)
		
		# Áp dụng cho bụi lớn (Bush_Common, Bush_Common_Flowers, Plant_1_Big), các bụi/cây xỉ nhỏ khác giữ yên lặng
		var res_path := scene.resource_path
		if "Bush_Common" in res_path or "Plant_1_Big" in res_path:
			_apply_wind_shader(bush_node)
		else:
			_configure_geometry_for_rendering(bush_node, 2.0)
			
		add_child(bush_node)
		placed += 1


# ─── Scatter Decorations (cỏ clump, hoa, nấm, đá nhỏ) ─────────────────────
func _scatter_decorations() -> void:
	# Cỏ clump đung đưa nhẹ trong gió, các loại hoa/nấm/đá khác giữ tĩnh lặng
	var grass_clump_count: int = int(round(num_grass_clumps * grass_clump_density_multiplier))
	_scatter_mesh_group(grass_clump_meshes, grass_clump_count, false, null, 0.6, 1.1, true)
	_scatter_mesh_group(flower_meshes, num_flowers, false, null, 0.8, 1.2, false)
	_scatter_mesh_group(mushroom_meshes, num_mushrooms, false, null, 0.7, 1.1, false)
	_scatter_mesh_group(rock_meshes, num_rocks, false, null, 0.8, 1.5, false, 0.6, 0.3, "Rock")


func _scatter_mesh_group(
	meshes: Array[Mesh],
	count: int,
	avoid_clearing: bool,
	mat_override: StandardMaterial3D,
	scale_min: float,
	scale_max: float,
	apply_wind: bool = false,
	collision_radius_scale: float = 0.0,
	collision_height_offset_scale: float = 0.0,
	name_prefix: String = "Decoration"
) -> void:
	if meshes.is_empty():
		return

	var placed: int = 0
	var attempts: int = 0
	var max_attempts: int = count * 10

	while placed < count and attempts < max_attempts:
		attempts += 1
		var x: float = _rng.randf_range(-MAP_HALF + 0.5, MAP_HALF - 0.5)
		var z: float = _rng.randf_range(-MAP_HALF + 0.5, MAP_HALF - 0.5)

		var zone := _get_zone(x, z)
		if zone == Zone.PATH:
			continue
		if avoid_clearing and zone == Zone.CLEARING:
			continue

		var height: float = _get_hill_height(x, z)
		var mesh_idx: int = _rng.randi() % meshes.size()
		var mesh: Mesh = meshes[mesh_idx]
		if mesh == null:
			continue

		var scale_val: float = _rng.randf_range(scale_min, scale_max)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		if mat_override != null:
			mi.material_override = mat_override
		mi.position = Vector3(x, height, z)
		mi.rotation.y = _rng.randf_range(0.0, TAU)
		mi.scale = Vector3(scale_val, scale_val, scale_val)
		mi.name = "%sMesh_%d" % [name_prefix, placed]
		if apply_wind:
			_apply_wind_shader(mi)
		else:
			_configure_geometry_for_rendering(mi, 1.5)
		add_child(mi)

		if collision_radius_scale > 0.0:
			var body := StaticBody3D.new()
			body.name = "%sBody_%d" % [name_prefix, placed]
			body.position = mi.position
			body.rotation.y = mi.rotation.y
			body.add_to_group("rock_obstacles")
			var col := CollisionShape3D.new()
			var sphere := SphereShape3D.new()
			sphere.radius = collision_radius_scale * scale_val
			col.shape = sphere
			col.position.y = collision_height_offset_scale * scale_val
			body.add_child(col)
			add_child(body)

		placed += 1


# ─── Scatter Boulders (combat cover) ───────────────────────────────────────
func _scatter_boulders() -> void:
	if boulder_meshes.is_empty():
		return

	# Boulder placements: rải trong clearings và ven rừng tạo cover
	var boulder_positions: Array[Vector2] = [
		Vector2(4.5, 2.0),   # Spawn clearing edge
		Vector2(-3.5, 5.0),  # Spawn clearing edge
		Vector2(15.0, 3.5),  # East arena cover
		Vector2(20.5, -3.0), # East arena cover
		Vector2(2.5, 15.0),  # South arena cover
		Vector2(-2.5, 21.0), # South arena cover
		Vector2(-12.0, -12.0), # Boss arena edge
		Vector2(-18.5, -11.0), # Boss arena edge
		Vector2(-13.0, -19.0), # Boss arena edge
		Vector2(12.0, -8.0),   # Rừng - cover di chuyển
		Vector2(-8.0, 8.0),    # Rừng - cover di chuyển
		Vector2(8.0, 10.0),    # Rừng - cover di chuyển
	]

	for i in range(boulder_positions.size()):
		var bp := boulder_positions[i]
		if boulder_meshes.is_empty():
			continue
		var mesh_idx: int = _rng.randi() % boulder_meshes.size()
		var mesh: Mesh = boulder_meshes[mesh_idx]
		if mesh == null:
			continue

		var height: float = _get_hill_height(bp.x, bp.y)
		var scale_val: float = _rng.randf_range(1.0, 1.8)

		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = Vector3(bp.x, height, bp.y)
		mi.rotation.y = _rng.randf_range(0.0, TAU)
		mi.scale = Vector3(scale_val, scale_val, scale_val)
		_configure_geometry_for_rendering(mi, 2.0)
		add_child(mi)

		# Collision cho boulder
		var boulder_body := StaticBody3D.new()
		boulder_body.name = "BoulderBody_%d" % i
		boulder_body.position = mi.position
		boulder_body.add_to_group("rock_obstacles")
		var boulder_col := CollisionShape3D.new()
		var boulder_sphere := SphereShape3D.new()
		boulder_sphere.radius = 1.2 * scale_val
		boulder_col.shape = boulder_sphere
		boulder_col.position.y = 0.8 * scale_val
		boulder_body.add_child(boulder_col)
		add_child(boulder_body)


# ─── Helper: Zone Detection ─────────────────────────────────────────────────
func _get_zone(x: float, z: float) -> Zone:
	var p := Vector2(x, z)

	# Clearing zones
	if p.distance_to(SPAWN_CENTER) <= SPAWN_RADIUS:
		return Zone.CLEARING
	if p.distance_to(EAST_ARENA_CENTER) <= EAST_ARENA_RADIUS:
		return Zone.CLEARING
	if p.distance_to(SOUTH_ARENA_CENTER) <= SOUTH_ARENA_RADIUS:
		return Zone.CLEARING
	if p.distance_to(BOSS_ARENA_CENTER) <= BOSS_ARENA_RADIUS:
		return Zone.CLEARING

	# Path zones (các đường mòn nối clearings)
	# Đường mòn: Spawn → East (dọc trục X dương)
	if _is_on_path(p, SPAWN_CENTER, EAST_ARENA_CENTER):
		return Zone.PATH
	# Đường mòn: Spawn → South (dọc trục Z dương)
	if _is_on_path(p, SPAWN_CENTER, SOUTH_ARENA_CENTER):
		return Zone.PATH
	# Đường mòn: East → Boss (chéo)
	if _is_on_path(p, EAST_ARENA_CENTER, BOSS_ARENA_CENTER):
		return Zone.PATH
	# Đường mòn: South → Boss (chéo)
	if _is_on_path(p, SOUTH_ARENA_CENTER, BOSS_ARENA_CENTER):
		return Zone.PATH

	# Hill zones
	for zone_data in HILL_ZONES:
		var c: Vector2 = zone_data["center"]
		var r: float = zone_data["radius"]
		if p.distance_to(c) <= r:
			return Zone.HILL

	return Zone.FOREST


# ─── Helper: Path Detection ─────────────────────────────────────────────────
func _is_on_path(p: Vector2, from_pos: Vector2, to_pos: Vector2) -> bool:
	# Kiểm tra điểm p có nằm trong dải PATH_HALF_WIDTH quanh đoạn thẳng from→to không
	var ab: Vector2 = to_pos - from_pos
	var ap: Vector2 = p - from_pos
	var ab_len_sq: float = ab.dot(ab)
	if ab_len_sq < 0.0001:
		return false
	var t: float = clampf(ap.dot(ab) / ab_len_sq, 0.0, 1.0)
	var closest: Vector2 = from_pos + ab * t
	return p.distance_to(closest) <= PATH_HALF_WIDTH


# ─── Helper: Hill Height Offset ─────────────────────────────────────────────
func _get_hill_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var max_h: float = 0.0
	for zone_data in HILL_ZONES:
		var c: Vector2 = zone_data["center"]
		var r: float = zone_data["radius"]
		var h: float = zone_data["height"]
		var dist: float = p.distance_to(c)
		if dist < r:
			# Smooth falloff từ tâm ra rìa gò đất
			var t: float = 1.0 - (dist / r)
			var hill_h: float = h * t * t
			if hill_h > max_h:
				max_h = hill_h
	return max_h


# ─── Helper: Spawn MultiMesh ─────────────────────────────────────────────────
func _spawn_multimesh(
	mesh: Mesh,
	transforms: Array[Transform3D],
	mat: Material,
	node_name: String
) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()

	for i in range(transforms.size()):
		multimesh.set_instance_transform(i, transforms[i])

	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = multimesh
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if mat != null:
		mmi.material_override = mat
	add_child(mmi)


# ─── Spawning Animal Bots ──────────────────────────────────────────────────
func _spawn_animals() -> void:
	var bot_script := preload("res://src/world/animal_bot.gd")
	
	# Spawn 4 bots per species (Dog removed as requested)
	var species_list := [
		{"type": 1, "count": 4, "name": "Cat"},
		{"type": 2, "count": 4, "name": "Rabbit"},
		{"type": 3, "count": 4, "name": "Parrot"}
	]
	
	for sp in species_list:
		for i in range(sp["count"]):
			var placed := false
			var attempts := 0
			while not placed and attempts < 100:
				attempts += 1
				var x := _rng.randf_range(-MAP_HALF + 5.0, MAP_HALF - 5.0)
				var z := _rng.randf_range(-MAP_HALF + 5.0, MAP_HALF - 5.0)
				
				# Avoid spawning right next to the player's spawn point
				var pos_2d := Vector2(x, z)
				if pos_2d.distance_to(SPAWN_CENTER) < 6.0:
					continue
					
				var zone := _get_zone(x, z)
				if zone == Zone.HILL:
					continue
					
				var bot := CharacterBody3D.new()
				bot.set_script(bot_script)
				bot.animal_type = sp["type"] as AnimalBot.AnimalType
				bot.speed = _rng.randf_range(1.0, 1.8)
				bot.position = Vector3(x, 0.2, z)
				bot.name = "%sBot_%d" % [sp["name"], i]
				
				# Ensure correct collision layer/mask so they collide with trees and environment
				bot.collision_layer = 16
				bot.collision_mask = 1
				
				add_child(bot)
				placed = true


# ─── Spawning Orc Mobs ──────────────────────────────────────────────────────
func _spawn_orcs() -> void:
	var orc_script := preload("res://src/world/orc_mob.gd")
	for i in range(num_orcs):
		var placed := false
		var attempts := 0
		while not placed and attempts < 100:
			attempts += 1
			var x := _rng.randf_range(-MAP_HALF + 5.0, MAP_HALF - 5.0)
			var z := _rng.randf_range(-MAP_HALF + 5.0, MAP_HALF - 5.0)
			var pos_2d := Vector2(x, z)
			if pos_2d.distance_to(SPAWN_CENTER) < 8.0:
				continue
			var zone := _get_zone(x, z)
			if zone == Zone.HILL:
				continue
			# Tránh spawn dưới tán cây lớn (Priority 2 - gameplay readability)
			if _is_under_large_tree_canopy(x, z):
				continue
			var bot := CharacterBody3D.new()
			bot.set_script(orc_script)
			bot.position = Vector3(x, 0.2, z)
			bot.name = "OrcMob_%d" % i
			bot.set("use_3d_model", true)
			add_child(bot)
			placed = true

# Kiểm tra xem vị trí có nằm dưới tán cây lớn không (che khuất gameplay)
func _is_under_large_tree_canopy(x: float, z: float) -> bool:
	for i in range(_tree_positions.size()):
		var tree_scale: float = _tree_scales[i] if i < _tree_scales.size() else 1.0
		if tree_scale < large_tree_scale_threshold:
			continue
		# Large trees có tán rộng ~3-4m, kiểm tra bán kính 4m
		var tree_pos := _tree_positions[i]
		var dist := Vector2(x, z).distance_to(tree_pos)
		if dist < 4.0:
			return true
	return false
