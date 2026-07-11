# forest_builder.gd
# Xây dựng khu rừng modular 60x60m sử dụng Modular Terrain Collection (chủ đề Hilly)
# Cây cối: Stylized Nature MegaKit (.gltf) — texture stylized đẹp, có thân và lá riêng
# Bố cục: 1 Spawn Clearing trung tâm + 2 Combat Arenas + 1 Boss Arena + đường mòn
class_name ForestBuilder
extends Node3D

const FloraScattererScript := preload("res://src/world/components/forest_flora_scatterer.gd")
const EntitySpawnerScript := preload("res://src/world/components/forest_entity_spawner.gd")
const TerrainBuilderScript := preload("res://src/world/components/forest_terrain_builder.gd")
const BoundaryBuilderScript := preload("res://src/world/components/forest_boundary_builder.gd")

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
	preload("res://Assets/Stylized Nature MegaKit[Standard]/glTF/CommonTree_1.gltf"),
	preload("res://Assets/Stylized Nature MegaKit[Standard]/glTF/CommonTree_2.gltf"),
	preload("res://Assets/Stylized Nature MegaKit[Standard]/glTF/CommonTree_3.gltf"),
	preload("res://Assets/Stylized Nature MegaKit[Standard]/glTF/CommonTree_4.gltf"),
	preload("res://Assets/Stylized Nature MegaKit[Standard]/glTF/CommonTree_5.gltf"),
	preload("res://Assets/Stylized Nature MegaKit[Standard]/glTF/DeadTree_1.gltf"),
	preload("res://Assets/Stylized Nature MegaKit[Standard]/glTF/DeadTree_2.gltf"),
	preload("res://Assets/Stylized Nature MegaKit[Standard]/glTF/DeadTree_3.gltf"),
	preload("res://Assets/Stylized Nature MegaKit[Standard]/glTF/DeadTree_4.gltf"),
	preload("res://Assets/Stylized Nature MegaKit[Standard]/glTF/DeadTree_5.gltf"),
]
@export var bush_scenes: Array[PackedScene] = [
	preload("res://Assets/Stylized Nature MegaKit[Standard]/glTF/Bush_Common.gltf"),
	preload("res://Assets/Stylized Nature MegaKit[Standard]/glTF/Fern_1.gltf"),
	preload("res://Assets/Stylized Nature MegaKit[Standard]/glTF/Plant_7.gltf"),
	preload("res://Assets/Stylized Nature MegaKit[Standard]/glTF/Plant_7_Big.gltf"),
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
	preload("res://Assets/modular_terrain_collection/Hilly_Prop_Flower_Sunflower.obj"),
	preload("res://Assets/modular_terrain_collection/Hilly_Prop_Flower_Lily_Blue.obj"),
	preload("res://Assets/modular_terrain_collection/Hilly_Prop_Flower_Lily_Pink.obj"),
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
@export var num_trees: int = 205
@export var num_bushes: int = 200
@export var num_grass_clumps: int = 550
@export var num_flowers: int = 450
@export var num_mushrooms: int = 80
@export var num_rocks: int = 100
@export var num_boulders: int = 25
@export var num_orcs: int = 24
@export var random_seed: int = 2025
@export_range(0.0, 1.0, 0.01) var large_tree_spawn_multiplier: float = 0.60
@export_range(1.0, 3.0, 0.05) var large_tree_scale_threshold: float = 1.65
@export_range(1.0, 8.0, 0.1) var tree_min_spacing: float = 4.2
@export_range(0.0, 5.0, 0.1) var tree_large_spacing_bonus: float = 1.1
@export_range(0.0, 1.0, 0.01) var grass_clump_density_multiplier: float = 0.90

# ─── Map Constants ─────────────────────────────────────────────────────────
const MAP_HALF: float = 50.0
const TILE_SIZE: float = 1.0

# Zone enum để dễ đọc
enum Zone { FOREST, CLEARING, PATH, HILL, LAKE }

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


var _rng: RandomNumberGenerator

# Lưu trữ vị trí và scale cây để kiểm tra spawn enemy (tránh che khuất gameplay)
var _tree_positions: Array[Vector2] = []
var _tree_scales: Array[float] = []

# ─── Ready ─────────────────────────────────────────────────────────────────
var _terrain_heightmap: TerrainHeightmap = null
var _terrain_data: Dictionary = {}
var _flora_scatterer: Node = null
var _entity_spawner: Node = null
var _terrain_builder: Node = null
var _boundary_builder: Node = null


func _setup_components() -> void:
	_flora_scatterer = FloraScattererScript.new() as Node
	_flora_scatterer.name = "FloraScatterer"
	add_child(_flora_scatterer)
	_flora_scatterer.setup(self, _rng)
	_entity_spawner = EntitySpawnerScript.new() as Node
	_entity_spawner.name = "EntitySpawner"
	add_child(_entity_spawner)
	_entity_spawner.setup(self, _rng)
	_terrain_builder = TerrainBuilderScript.new() as Node
	_terrain_builder.name = "TerrainBuilder"
	add_child(_terrain_builder)
	_terrain_builder.setup(self)
	_boundary_builder = BoundaryBuilderScript.new() as Node
	_boundary_builder.name = "BoundaryBuilder"
	add_child(_boundary_builder)
	_boundary_builder.setup(self)


func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = random_seed
	_setup_components()

	add_to_group("forest")
	_terrain_data = _terrain_builder.build(HILL_ZONES, Callable(self, "_get_zone"))
	_build_map_walls()
	_build_boss_arena_enclosure()
	_scatter_trees()
	_scatter_bushes()
	_scatter_decorations()
	_scatter_boulders()
	_spawn_animals()
	_spawn_orcs()


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
		if tex != null:
			var tex_path := tex.resource_path
			if "Leaves_TwistedTree" in tex_path or "Flowers" in tex_path:
				tex = preload("res://Assets/Stylized Nature MegaKit[Standard]/glTF/Leaves.png")
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
		# Không đặt cây trong clearing, path hay hồ nước
		if zone == Zone.CLEARING or zone == Zone.PATH or zone == Zone.LAKE:
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
		if zone == Zone.PATH or zone == Zone.LAKE:
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
	_flora_scatterer.scatter_all()

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
		var item_idx: int = _rng.randi() % boulder_meshes.size()
		var item: Mesh = boulder_meshes[item_idx]
		if item == null:
			continue

		var height: float = _get_hill_height(bp.x, bp.y)
		var scale_val: float = _rng.randf_range(1.5, 2.5) # Phóng to đá PBR thành đá tảng lớn

		var instance := MeshInstance3D.new()
		instance.mesh = item

		instance.position = Vector3(bp.x, height, bp.y)
		instance.rotation.y = _rng.randf_range(0.0, TAU)
		instance.scale = Vector3(scale_val, scale_val, scale_val)
		_configure_geometry_for_rendering(instance, 2.0)
		add_child(instance)

		# Collision cho boulder
		var boulder_body := StaticBody3D.new()
		boulder_body.name = "BoulderBody_%d" % i
		boulder_body.position = instance.position
		boulder_body.add_to_group("rock_obstacles")
		var boulder_col := CollisionShape3D.new()
		var boulder_sphere := SphereShape3D.new()
		boulder_sphere.radius = 1.0 * scale_val
		boulder_col.shape = boulder_sphere
		boulder_col.position.y = 0.6 * scale_val
		boulder_body.add_child(boulder_col)
		add_child(boulder_body)


# ─── Helper: Zone Detection ─────────────────────────────────────────────────
func _is_in_lake(x: float, z: float) -> bool:
	var c := Vector2(24.0, -24.0)
	var p := Vector2(x, z)
	var dist_to_lake := p.distance_to(c)
	var angle := atan2(z - c.y, x - c.x)
	var perturbed_radius := 8.0 + 2.0 * sin(angle * 3.0) + 1.2 * cos(angle * 5.0)
	return dist_to_lake < perturbed_radius

func _get_zone(x: float, z: float) -> Zone:
	if _is_in_lake(x, z):
		return Zone.LAKE
		
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
# ─── Spawning Animal Bots ──────────────────────────────────────────────────
func _spawn_animals() -> void:
	_entity_spawner.spawn_animals()


func _spawn_orcs() -> void:
	_entity_spawner.spawn_orcs()

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

# ─── World Boundaries ──────────────────────────────────────────────────────
func _build_map_walls() -> void:
	_boundary_builder.build_map_walls()


func _build_boss_arena_enclosure() -> void:
	_boundary_builder.build_boss_enclosure()
