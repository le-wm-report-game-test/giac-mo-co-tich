# world_manager.gd
# Handles: boss spawning, HUD, weather, damage numbers, tree fade, sound, camera magnets
class_name WorldManager
extends Node

const SettingsMenuScript := preload("res://src/common/settings_menu.gd")
const BossManagerScript := preload("res://src/world/components/world_boss_manager.gd")
const WeatherManagerScript := preload("res://src/world/components/world_weather_manager.gd")
const HudManagerScript := preload("res://src/world/components/world_hud_manager.gd")

# ─── Boss Config ─────────────────────────────────────────────────────────────
@export var orcs_to_kill_for_boss: int = 5
var orcs_killed: int = 0
var boss_spawned: bool = false
var boss_instance: Node3D = null

# ─── Weather Config ──────────────────────────────────────────────────────────
var weather_timer: float = 0.0
var weather_duration: float = 0.0
var weather_state: String = "clear"  # clear, rain, storm
var rain_cycle_count: int = 0
var rain_particles: GPUParticles3D = null
var lightning_timer: float = 0.0
var is_raining: bool = false



# ─── HUD References ──────────────────────────────────────────────────────────
var player_health_bar: TextureProgressBar = null
var player_health_fill: ColorRect = null
var orc_counter_label: Label = null
var minimap: Minimap = null
var minimap_container: Control = null
var minimap_zoomed: bool = false

# ─── Tree Fade ───────────────────────────────────────────────────────────────
const TREE_FADE_ALPHA: float = 0.25
const TREE_FADE_OUT_SECONDS: float = 0.15
const TREE_FADE_IN_SECONDS: float = 0.24
const TREE_MAX_OCCLUDERS: int = 3
const TREE_FALLBACK_RADIUS: float = 2.4
const TREE_FALLBACK_HEIGHT: float = 6.0
const TREE_SHADOW_MAX_COUNT: int = 24
const TREE_SHADOW_DISTANCE: float = 28.0
const TREE_SHADOW_REFRESH_SECONDS: float = 0.35

var tree_list: Array[Node3D] = []
var _tree_alpha_states: Dictionary = {}
var _tree_local_bounds: Dictionary = {}
var _tree_has_geometry: Dictionary = {}
var _tree_shadow_refresh_timer: float = 0.0

# ─── Camera Magnet ───────────────────────────────────────────────────────────
var camera_magnet_active: bool = false
var camera_magnet_target: Vector3 = Vector3.ZERO
var camera_magnet_zoom: float = 0.0
var camera_magnet_duration: float = 0.0
var camera_magnet_timer: float = 0.0

var _boss_manager: Node = null
var _weather_manager: Node = null
var _hud_manager: Node = null


func _setup_components() -> void:
	_boss_manager = BossManagerScript.new() as Node
	_boss_manager.name = "BossManager"
	add_child(_boss_manager)
	_boss_manager.setup(self)
	_weather_manager = WeatherManagerScript.new() as Node
	_weather_manager.name = "WeatherManager"
	add_child(_weather_manager)
	_weather_manager.setup(self)
	_hud_manager = HudManagerScript.new() as Node
	_hud_manager.name = "HUDManager"
	add_child(_hud_manager)
	_hud_manager.setup(self)


func _ready() -> void:
	# Đăng ký group để SaveManager có thể tìm thấy
	add_to_group("world_manager")
	_setup_components()

	# Connect to event bus
	var eb := get_node("/root/EventBus")
	if eb:
		eb.enemy_died.connect(_on_enemy_died)
		eb.player_health_changed.connect(_on_player_health_changed)
		eb.player_took_damage.connect(_on_player_took_damage)
		eb.enemy_damaged.connect(_on_enemy_damaged)
	
	# Start weather system
	weather_timer = 300.0  # 5 minutes until first rain
	
	# Create HUD
	_create_hud()
	
	# Create settings menu
	var settings_menu := SettingsMenuScript.new()
	settings_menu.name = "SettingsMenu"
	add_child(settings_menu)

	_configure_lighting()
	await get_tree().process_frame
	_collect_trees()

# Phím tắt Debug để kiểm tra nhanh thời tiết và sấm sét
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			_toggle_minimap_zoom()

	# Chỉ hoạt động khi chạy chạy thử trong Godot Editor (Debug build)
	if OS.is_debug_build() and event is InputEventKey and event.pressed:
		if event.keycode == KEY_K:
			print("DEBUG: Kích hoạt mưa bão (Storm) ngay lập tức!")
			_start_storm_instantly()
		elif event.keycode == KEY_L:
			print("DEBUG: Gọi sét đánh ngay lập tức!")
			_strike_lightning()

# Phóng to / thu nhỏ minimap khi bấm phím M
func _toggle_minimap_zoom() -> void:
	_hud_manager.toggle_minimap_zoom()


func _process(delta: float) -> void:
	_update_weather(delta)
	_update_rain_coverage()
	_update_tree_fade(delta)
	_update_tree_shadow_budget(delta)
	_update_tree_camera_clip()
	_update_camera_magnet(delta)
	_update_minimap(delta)

# ══════════════════════════════════════════════════════════════════════════════
# BOSS SYSTEM
# ══════════════════════════════════════════════════════════════════════════════


func _on_enemy_died(enemy: Node3D) -> void:
	_boss_manager.on_enemy_died(enemy)


func _spawn_boss() -> void:
	_boss_manager.spawn_boss()

# ══════════════════════════════════════════════════════════════════════════════
# WEATHER SYSTEM
# ══════════════════════════════════════════════════════════════════════════════

func _update_weather(delta: float) -> void:
	_weather_manager.update(delta)


func _start_storm_instantly() -> void:
	_weather_manager.start_storm_instantly()


func _start_rain() -> void:
	_weather_manager.start_rain()


func _end_rain() -> void:
	_weather_manager.end_rain()


func _create_rain_particles() -> void:
	_weather_manager.create_rain_particles()


func _update_rain_coverage() -> void:
	_weather_manager.update_rain_coverage()


func _strike_lightning() -> void:
	_weather_manager.strike_lightning()


func trigger_screen_flash() -> void:
	_weather_manager.trigger_screen_flash()


func _configure_lighting() -> void:
	var lighting := get_tree().get_first_node_in_group("lighting_director") as LightingDirector
	if lighting:
		lighting.refresh_from_scene()


func _update_weather_lighting(is_rainy: bool) -> void:
	_weather_manager.update_lighting(is_rainy)


# ══════════════════════════════════════════════════════════════════════════════
# CAMERA MAGNET SYSTEM
# ══════════════════════════════════════════════════════════════════════════════

func _activate_camera_magnet(target_pos: Vector3, zoom_size: float, duration: float) -> void:
	camera_magnet_active = true
	camera_magnet_target = target_pos
	camera_magnet_zoom = zoom_size
	camera_magnet_duration = duration
	camera_magnet_timer = duration
	
	var game_cam := get_tree().get_first_node_in_group("camera") as GameCamera
	if game_cam:
		game_cam.set_meta("original_zoom", game_cam.camera.size)
		game_cam.activate_magnet(target_pos, zoom_size)

func _update_camera_magnet(delta: float) -> void:
	if not camera_magnet_active:
		return

	camera_magnet_timer -= delta

	if camera_magnet_timer <= 0.0:
		# Restore normal camera
		camera_magnet_active = false
		var game_cam := get_tree().get_first_node_in_group("camera") as GameCamera
		if game_cam:
			game_cam.deactivate_magnet()
		return

	# NOTE: we deliberately do NOT touch game_cam.global_position here.
	# game_camera.gd's `magnet_pcam` (a PhantomCamera3D with priority 20)
	# owns the cinematic cut: it tweens from the player follow anchor to the
	# boss anchor using its own easing. Lerping the camera global_position
	# by hand fights the pcam tween and used to fling the camera off-map on
	# the way to the boss. Just keep the magnet active so game_camera.gd's
	# _process keeps returning early and the pcam tween finishes cleanly.

func _create_hud() -> void:
	_hud_manager.create_hud()


func _update_ui_orc_counter() -> void:
	_hud_manager.update_orc_counter()


func _on_player_health_changed(current: float, max_health: float) -> void:
	_hud_manager.update_health(current, max_health)


func _format_orc_counter_text() -> String:
	return _hud_manager.format_orc_counter()

func _show_boss_health_bar(boss: Node3D = null) -> void:
	if boss:
		_hud_manager.show_boss_health_bar(boss)

func _hide_boss_health_bar() -> void:
	_hud_manager.hide_boss_health_bar()

# ══════════════════════════════════════════════════════════════════════════════
# DAMAGE NUMBERS
# ══════════════════════════════════════════════════════════════════════════════

func _on_player_took_damage(amount: float, position: Vector3) -> void:
	_hud_manager.spawn_damage_number(amount, position, DamagePopup.Kind.PLAYER_HIT)


func _on_enemy_damaged(
	_enemy: Node3D,
	amount: float,
	position: Vector3,
	is_critical: bool = false
) -> void:
	var kind := DamagePopup.Kind.CRITICAL if is_critical else DamagePopup.Kind.ENEMY_HIT
	_hud_manager.spawn_damage_number(amount, position, kind)


func _spawn_damage_number(
	amount: float,
	world_position: Vector3,
	popup_kind: DamagePopup.Kind
) -> void:
	_hud_manager.spawn_damage_number(amount, world_position, popup_kind)

# ══════════════════════════════════════════════════════════════════════════════
# TREE FADE (75% mờ khi cây nằm giữa camera và player)
# ══════════════════════════════════════════════════════════════════════════════

func _collect_trees() -> void:
	tree_list.clear()
	_tree_alpha_states.clear()
	_tree_local_bounds.clear()
	_tree_has_geometry.clear()
	var world := get_parent()
	for child in world.get_children():
		if child.is_in_group("trees") or "Pine_" in child.name:
			_register_tree_for_fade(child as Node3D)
		if child is ForestBuilder:
			_collect_tree_children(child)

func _collect_tree_children(node: Node) -> void:
	for child in node.get_children():
		if child.is_in_group("trees") or "Pine_" in child.name:
			_register_tree_for_fade(child as Node3D)
			# Root tree owns all rendered descendants. Registering a Pine child too
			# would spend the three-occluder budget twice on the same visual tree.
			continue
		if child.get_child_count() > 0:
			_collect_tree_children(child)


func _register_tree_for_fade(tree: Node3D) -> void:
	if tree == null or tree_list.has(tree):
		return
	tree.visible = true
	tree_list.append(tree)
	_tree_alpha_states[tree] = 1.0
	var bounds := _compute_tree_local_bounds(tree)
	if bounds.size.length_squared() > 0.0001:
		_tree_local_bounds[tree] = bounds.grow(0.35)


func _compute_tree_local_bounds(tree: Node3D) -> AABB:
	var state := {"has_bounds": false, "bounds": AABB()}
	var root_inverse := tree.global_transform.affine_inverse()
	_merge_tree_geometry_bounds(tree, root_inverse, state)
	_tree_has_geometry[tree] = bool(state["has_bounds"])
	return state["bounds"] as AABB if bool(state["has_bounds"]) else AABB()


func _merge_tree_geometry_bounds(node: Node, root_inverse: Transform3D, state: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			var relative_transform := root_inverse * mesh_instance.global_transform
			var local_bounds := relative_transform * mesh_instance.mesh.get_aabb()
			if bool(state["has_bounds"]):
				state["bounds"] = (state["bounds"] as AABB).merge(local_bounds)
			else:
				state["bounds"] = local_bounds
				state["has_bounds"] = true
	for child in node.get_children():
		_merge_tree_geometry_bounds(child, root_inverse, state)


func _update_tree_fade(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var player_focus := player.global_position + Vector3.UP
	if camera.is_position_behind(player_focus):
		return
	var player_screen := camera.unproject_position(player_focus)
	var player_depth := -camera.to_local(player_focus).z

	var occluders: Array[Dictionary] = []
	for tree in tree_list:
		if not is_instance_valid(tree) or not bool(_tree_has_geometry.get(tree, false)):
			continue
		var score := _tree_occlusion_score(tree, camera, player_screen, player_depth)
		if score < INF:
			occluders.append({"tree": tree, "score": score})

	occluders.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) < float(b["score"])
	)
	var faded_trees: Dictionary = {}
	for index in range(mini(TREE_MAX_OCCLUDERS, occluders.size())):
		faded_trees[occluders[index]["tree"]] = true

	for tree in tree_list:
		if not is_instance_valid(tree):
			continue
		var target_alpha := TREE_FADE_ALPHA if faded_trees.has(tree) else 1.0
		_set_tree_alpha_smooth(tree, target_alpha, delta)


func _tree_occlusion_score(
	tree: Node3D,
	camera: Camera3D,
	player_screen: Vector2,
	player_depth: float
) -> float:
	var local_bounds := _tree_local_bounds.get(tree, AABB()) as AABB
	if local_bounds.size.length_squared() <= 0.0001:
		local_bounds = AABB(
			Vector3(-TREE_FALLBACK_RADIUS, 0.0, -TREE_FALLBACK_RADIUS),
			Vector3(TREE_FALLBACK_RADIUS * 2.0, TREE_FALLBACK_HEIGHT, TREE_FALLBACK_RADIUS * 2.0)
		)

	var screen_min := Vector2(INF, INF)
	var screen_max := Vector2(-INF, -INF)
	var nearest_depth := INF
	var projected_corner_count := 0
	for corner_index in range(8):
		var local_corner := Vector3(
			local_bounds.end.x if (corner_index & 1) != 0 else local_bounds.position.x,
			local_bounds.end.y if (corner_index & 2) != 0 else local_bounds.position.y,
			local_bounds.end.z if (corner_index & 4) != 0 else local_bounds.position.z
		)
		var world_corner := tree.global_transform * local_corner
		var depth := -camera.to_local(world_corner).z
		if depth <= camera.near:
			continue
		var screen_corner := camera.unproject_position(world_corner)
		screen_min.x = minf(screen_min.x, screen_corner.x)
		screen_min.y = minf(screen_min.y, screen_corner.y)
		screen_max.x = maxf(screen_max.x, screen_corner.x)
		screen_max.y = maxf(screen_max.y, screen_corner.y)
		nearest_depth = minf(nearest_depth, depth)
		projected_corner_count += 1

	if projected_corner_count == 0:
		return INF
	var screen_bounds := Rect2(screen_min, screen_max - screen_min).grow(6.0)
	if not screen_bounds.has_point(player_screen) or nearest_depth >= player_depth:
		return INF

	var half_extent := screen_bounds.size * 0.5
	var normalized_screen_distance := screen_bounds.get_center().distance_to(player_screen) / maxf(half_extent.length(), 1.0)
	return normalized_screen_distance + nearest_depth / maxf(player_depth, 0.001) * 0.1


func _set_tree_alpha_smooth(tree: Node3D, target_alpha: float, delta: float) -> void:
	var current_alpha := float(_tree_alpha_states.get(tree, 1.0))
	var duration := TREE_FADE_OUT_SECONDS if target_alpha < current_alpha else TREE_FADE_IN_SECONDS
	var step := delta / maxf(duration, 0.001)
	current_alpha = move_toward(current_alpha, target_alpha, step)
	_tree_alpha_states[tree] = current_alpha
	_set_tree_alpha(tree, current_alpha)


func _update_tree_shadow_budget(delta: float) -> void:
	_tree_shadow_refresh_timer -= delta
	if _tree_shadow_refresh_timer > 0.0:
		return
	_tree_shadow_refresh_timer = TREE_SHADOW_REFRESH_SECONDS
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var max_distance_squared := TREE_SHADOW_DISTANCE * TREE_SHADOW_DISTANCE
	var candidates: Array[Dictionary] = []
	for tree in tree_list:
		if not is_instance_valid(tree):
			continue
		var distance_squared := tree.global_position.distance_squared_to(player.global_position)
		if distance_squared <= max_distance_squared:
			candidates.append({"tree": tree, "distance_squared": distance_squared})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance_squared"]) < float(b["distance_squared"])
	)
	var shadow_trees: Dictionary = {}
	for index in range(mini(TREE_SHADOW_MAX_COUNT, candidates.size())):
		shadow_trees[candidates[index]["tree"]] = true
	for tree in tree_list:
		if is_instance_valid(tree):
			_set_tree_shadow_enabled(tree, shadow_trees.has(tree))


func _set_tree_shadow_enabled(node: Node, enabled: bool) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if enabled
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
	for child in node.get_children():
		_set_tree_shadow_enabled(child, enabled)

func _tree_has_rendered_geometry(node: Node) -> bool:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return true
	for child in node.get_children():
		if _tree_has_rendered_geometry(child):
			return true
	return false

func _set_tree_alpha(node: Node, alpha: float) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh:
			for i in range(mesh_node.mesh.get_surface_count()):
				var mat := mesh_node.get_surface_override_material(i)
				if mat is ShaderMaterial:
					(mat as ShaderMaterial).set_shader_parameter("alpha_multiplier", alpha)
					continue
				var base_mat := mat as BaseMaterial3D
				if not base_mat:
					var mesh_mat := mesh_node.mesh.surface_get_material(i) as BaseMaterial3D
					if mesh_mat:
						base_mat = mesh_mat.duplicate() as BaseMaterial3D
						mesh_node.set_surface_override_material(i, base_mat)
				if base_mat:
					base_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					base_mat.albedo_color.a = alpha
		
		if mesh_node.material_override:
			var override_mat := mesh_node.material_override
			if override_mat is ShaderMaterial:
				(override_mat as ShaderMaterial).set_shader_parameter("alpha_multiplier", alpha)
			elif override_mat is BaseMaterial3D:
				var base_override_mat := override_mat as BaseMaterial3D
				if not base_override_mat.is_local_to_scene():
					base_override_mat = base_override_mat.duplicate() as BaseMaterial3D
					mesh_node.material_override = base_override_mat
				base_override_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				base_override_mat.albedo_color.a = alpha
	
	for child in node.get_children():
		_set_tree_alpha(child, alpha)

# ══════════════════════════════════════════════════════════════════════════════
# CAMERA TREE CLIPPING (cây tan biến khi camera đi qua)
# ══════════════════════════════════════════════════════════════════════════════

func _update_tree_camera_clip() -> void:
	# Visibility is restored once during registration; fade only changes materials.
	pass

func _update_minimap(delta: float = 0.0) -> void:
	_hud_manager.update_minimap(delta, delta <= 0.0)


func _is_orc_attacking(candidate: Variant) -> bool:
	return _hud_manager.is_orc_attacking(candidate)


func _is_minimap_orc_marker(candidate: Variant) -> bool:
	return _hud_manager.is_orc_marker(candidate)
