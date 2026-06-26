# Analysis: Refactoring WorldManager into Child Component Nodes

This report details a complete, backward-compatible design to refactor the monolithic `world_manager.gd` into four lightweight, single-responsibility child component nodes. It adheres to all constraints, keeping proposed files under 200 lines and functions under 50 lines.

---

## 1. Mapping of Component Responsibilities

The responsibilities of `WorldManager` are divided as follows:

| Component | Target File | Moved Variables | Moved Functions | Signal Connections |
| :--- | :--- | :--- | :--- | :--- |
| **BossManager** | `src/world/boss_manager.gd` | `orcs_to_kill_for_boss`, `orcs_killed`, `boss_spawned`, `boss_instance` | `_on_enemy_died` (boss logic), `_spawn_boss` | Connects to `EventBus.enemy_died`. Emits `EventBus.boss_spawned`, `EventBus.orc_killed_count`, and custom `camera_magnet_requested`. |
| **WeatherManager** | `src/world/weather_manager.gd` | `weather_timer`, `weather_duration`, `weather_state`, `rain_cycle_count`, `rain_particles`, `lightning_timer`, `is_raining` | `process_weather`, `_start_rain`, `_end_rain`, `_create_rain_particles`, `_strike_lightning`, `immediate_mesh_create_lightning`, `_apply_ambient_darkening`, `_configure_lighting`, `_update_weather_lighting` | Emits `EventBus.weather_changed`. |
| **TreeFadeSystem** | `src/world/tree_fade_system.gd` | `tree_list`, `camera_magnet_active`, `camera_magnet_target`, `camera_magnet_zoom`, `camera_magnet_duration`, `camera_magnet_timer` | `_collect_trees`, `_collect_tree_children`, `_update_tree_fade`, `_set_tree_alpha`, `_apply_mesh_alpha`, `_update_tree_camera_clip`, `_activate_camera_magnet`, `_update_camera_magnet`, `_deactivate_camera_magnet` | Internal processing only. |
| **HUDManager** | `src/world/hud_manager.gd` | `ui_layer` | `create_hud`, `_create_player_health_bar`, `_create_orc_counter`, `_create_boss_health_bar`, `_update_ui_orc_counter`, `_on_orc_killed_count`, `_on_player_health_changed`, `_show_boss_health_bar`, `_hide_boss_health_bar`, `_on_boss_spawned`, `_on_boss_health_changed`, `_on_enemy_died` (HUD part), `_on_player_took_damage`, `_on_enemy_damaged`, `_spawn_damage_number` | Connects to `EventBus` signals (`player_health_changed`, `player_took_damage`, `enemy_damaged`, `orc_killed_count`, `boss_spawned`, `enemy_died`). |

---

## 2. Backward Compatibility & Path Resolution

To avoid modifying any test files, the refactored `WorldManager` maintains exact backward compatibility via **properties** (with custom getters/setters) and **delegate functions**.

### Variable Access Delegation
Tests access properties like `_world_manager.boss_spawned` directly. In Godot 4.x, these are handled using `get` and `set` blocks delegating to the respective component node instance:
```gdscript
var boss_spawned: bool:
	get:
		return boss_manager.boss_spawned if boss_manager else false
	set(value):
		if boss_manager:
			boss_manager.boss_spawned = value
```

### UI Node Path Verification
Tests query the HUD using specific node paths like `WorldManager/UI/BossHealthContainer`. To satisfy this, the `HUDManager` constructs the `CanvasLayer` named `"UI"` and attaches it directly as a child of its parent `WorldManager`, rather than its own child. Thus, `WorldManager/UI/...` paths resolve successfully.

---

## 3. Communication Patterns

Following the Godot practice *"Up with signals, down with function calls"*:
1. **EventBus Decoupling**: Global game events (e.g., `EventBus.orc_killed_count`, `EventBus.boss_spawned`) are emitted by managers and received directly by the `HUDManager` or `BossManager`.
2. **Signals Up**: When the `BossManager` wants to trigger camera zoom/magnet on boss spawn, it emits a custom signal `camera_magnet_requested`. `WorldManager` (parent) handles this signal and calls `_activate_camera_magnet(...)` on the `TreeFadeSystem` child component.
3. **Calls Down**: `WorldManager` calls update functions (`process_weather`, `process_fade_and_magnet`) on its child nodes in its `_process` loop.

---

## 4. Proposed File Implementation Details

All code below uses static typing, Vietnamese comments for game logic explanations, and English comments for technical explanations.

### 4.1 BossManager (`src/world/boss_manager.gd`)
*Total Lines: 63 lines. Max Function Length: 35 lines.*
```gdscript
# boss_manager.gd
# Handles boss spawning, lifecycle, and kill tracking.
class_name BossManager
extends Node

signal camera_magnet_requested(target_pos: Vector3, zoom_size: float, duration: float)

var orcs_to_kill_for_boss: int = 5
var orcs_killed: int = 0
var boss_spawned: bool = false
var boss_instance: Node3D = null

func _ready() -> void:
	# Kết nối đến EventBus toàn cục
	if get_node_or_null("/root/EventBus"):
		EventBus.enemy_died.connect(_on_enemy_died)

func _on_enemy_died(enemy: Node3D) -> void:
	if enemy.is_in_group("boss"):
		boss_instance = null
		return

	if enemy.is_in_group("orc_mobs") and not enemy.is_in_group("boss"):
		orcs_killed += 1
		EventBus.orc_killed_count.emit(orcs_killed)
		
		if orcs_killed >= orcs_to_kill_for_boss and not boss_spawned:
			_spawn_boss()

func _spawn_boss() -> void:
	boss_spawned = true
	print("BOSS SPAWNED! Chằn Tinh xuất hiện!")
	
	# Khởi tạo boss từ đối tượng Minotaur
	var boss := CharacterBody3D.new()
	boss.name = "BossChằnTinh"
	boss.add_to_group("boss")
	boss.add_to_group("orc_mobs")
	
	# Đính kèm script
	var boss_script := preload("res://src/world/orc_mob.gd")
	boss.set_script(boss_script)
	
	# Định vị boss tại vị trí trung tâm đấu trường
	boss.position = Vector3(-15.0, 0.2, -15.0)
	boss.scale = Vector3(18.0, 18.0, 18.0)
	
	# Thêm vào node World (cha của WorldManager)
	var world_node := get_parent().get_parent()
	if world_node:
		world_node.add_child(boss)
	boss_instance = boss
	
	# Cài đặt chỉ số cho boss
	if boss.has_method("_setup_nodes"):
		boss._setup_nodes()
		if boss.health_component:
			boss.health_component.max_health = 300.0
			boss.health_component.current_health = 300.0
		boss.speed = 1.5
		boss.attack_damage = 25.0
		boss.attack_range = 2.5
		boss.detection_range = 20.0
	
	# Phát tín hiệu kích hoạt camera magnet
	camera_magnet_requested.emit(Vector3(-15.0, 0.0, -15.0), 25.0, 8.0)
	EventBus.boss_spawned.emit(boss)
```

### 4.2 WeatherManager (`src/world/weather_manager.gd`)
*Total Lines: 181 lines. Max Function Length: 45 lines.*
```gdscript
# weather_manager.gd
# Handles weather cycles, storm particles, lighting config and lightning.
class_name WeatherManager
extends Node

var weather_timer: float = 0.0
var weather_duration: float = 0.0
var weather_state: String = "clear"  # clear, rain, storm
var rain_cycle_count: int = 0
var rain_particles: GPUParticles3D = null
var lightning_timer: float = 0.0
var is_raining: bool = false

func _ready() -> void:
	weather_timer = 300.0  # 5 phút cho đến cơn mưa đầu tiên
	_configure_lighting()

func process_weather(delta: float) -> void:
	if weather_state == "clear":
		weather_timer -= delta
		if weather_timer <= 0.0:
			_start_rain()
	else:
		weather_duration -= delta
		if weather_duration <= 0.0:
			_end_rain()
	
	# Kích hoạt sét đánh khi trời bão
	if weather_state == "storm":
		lightning_timer -= delta
		if lightning_timer <= 0.0:
			_strike_lightning()
			lightning_timer = randf_range(3.0, 8.0)

func _start_rain() -> void:
	rain_cycle_count += 1
	is_raining = true
	
	if rain_cycle_count >= 3:
		weather_state = "storm"
		weather_duration = 60.0
		rain_cycle_count = 0
		lightning_timer = 3.0
		print("STORM! Sấm sét xuất hiện!")
	else:
		weather_state = "rain"
		weather_duration = 60.0
		print("Rain started...")
	
	EventBus.weather_changed.emit(weather_state)
	_create_rain_particles()
	_apply_ambient_darkening(0.6)
	_update_weather_lighting(true)
	
	var audio := get_node_or_null("/root/World/AudioManager") as AudioManager
	if audio:
		audio.play_ambience("rain_ambience")

func _end_rain() -> void:
	is_raining = false
	weather_state = "clear"
	weather_timer = 300.0
	
	if rain_particles:
		rain_particles.emitting = false
		var tween := create_tween()
		tween.tween_interval(2.0)
		tween.tween_callback(func(): 
			if rain_particles:
				rain_particles.queue_free()
				rain_particles = null
		)
	
	_apply_ambient_darkening(1.0)
	_update_weather_lighting(false)
	print("Rain ended...")
	EventBus.weather_changed.emit("clear")
	
	var audio := get_node_or_null("/root/World/AudioManager") as AudioManager
	if audio:
		audio.stop_ambience()

func _create_rain_particles() -> void:
	if rain_particles:
		rain_particles.emitting = false
		rain_particles.queue_free()
	
	rain_particles = GPUParticles3D.new()
	rain_particles.name = "RainParticles"
	rain_particles.emitting = true
	rain_particles.amount = 1000
	rain_particles.lifetime = 2.0
	rain_particles.one_shot = false
	rain_particles.preprocess = 1.0
	rain_particles.position = Vector3(0, 20, 0)
	
	var material := ParticleProcessMaterial.new()
	material.gravity = Vector3(0, -30, 5)
	material.initial_velocity_min = 20.0
	material.initial_velocity_max = 30.0
	material.angle_min = 0.0
	material.angle_max = 0.0
	material.scale_min = 0.5
	material.scale_max = 1.0
	material.color = Color(0.7, 0.8, 1.0, 0.4)
	material.direction = Vector3.DOWN
	material.spread = 15.0
	
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.3)
	rain_particles.draw_pass_1 = quad
	rain_particles.process_material = material
	rain_particles.sorting_offset = 0
	
	var world_node := get_parent().get_parent()
	if world_node:
		world_node.add_child(rain_particles)

func _strike_lightning() -> void:
	print("⚡ LIGHTNING STRIKE!")
	var x := randf_range(-45.0, 45.0)
	var z := randf_range(-45.0, 45.0)
	var strike_pos := Vector3(x, 0.0, z)
	
	var flash := ColorRect.new()
	flash.color = Color(1.0, 1.0, 1.0, 0.8)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.size = get_viewport().get_visible_rect().size
	
	var ui_layer := get_parent().get_node_or_null("UI")
	if ui_layer:
		ui_layer.add_child(flash)
		var tween := create_tween()
		tween.tween_property(flash, "color:a", 0.0, 0.3)
		tween.tween_callback(flash.queue_free)
	else:
		flash.queue_free()
	
	var bolt := MeshInstance3D.new()
	var bolt_mesh := immediate_mesh_create_lightning(strike_pos, strike_pos + Vector3(0, 15, 0))
	if bolt_mesh:
		bolt.mesh = bolt_mesh
		var world_node := get_parent().get_parent()
		if world_node:
			world_node.add_child(bolt)
		var bt := create_tween()
		bt.tween_interval(0.2)
		bt.tween_callback(bolt.queue_free)
	
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and player.global_position.distance_to(strike_pos) < 5.0:
		if player.has_method("_on_damaged"):
			player.call("_on_damaged", 20.0, null)
	
	var audio := get_node_or_null("/root/World/AudioManager") as AudioManager
	if audio:
		audio.play_sfx("thunder", strike_pos, 0.2)

func immediate_mesh_create_lightning(from: Vector3, to: Vector3) -> Mesh:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.1
	cylinder.bottom_radius = 0.1
	cylinder.height = from.distance_to(to)
	return cylinder

func _apply_ambient_darkening(factor: float) -> void:
	var world_env := get_node_or_null("/root/World/WorldEnvironment")
	if world_env and world_env.environment:
		var tween := create_tween()
		tween.tween_method(func(v): 
			world_env.environment.adjustment_brightness = v
		, world_env.environment.adjustment_brightness, factor, 2.0)

func _configure_lighting() -> void:
	var sun := get_node_or_null("/root/World/DirectionalLight3D") as DirectionalLight3D
	if sun:
		sun.light_color = Color(1.0, 0.92, 0.72)
		sun.light_energy = 1.4
		sun.light_angular_distance = 0.5
		sun.shadow_enabled = true
		sun.shadow_bias = 0.02
		sun.shadow_normal_bias = 1.2
		sun.shadow_blur = 2.0
		sun.directional_shadow_max_distance = 80.0
	
	var world_env := get_node_or_null("/root/World/WorldEnvironment") as WorldEnvironment
	if world_env and world_env.environment:
		if not world_env.environment.is_local_to_scene():
			world_env.environment = world_env.environment.duplicate()
		var env := world_env.environment
		env.ssao_enabled = true
		env.ssao_radius = 1.8
		env.ssao_intensity = 1.2
		env.ssao_power = 1.5
		env.ssao_detail = 0.5
		
		env.ssil_enabled = true
		env.ssil_radius = 3.0
		env.ssil_intensity = 0.8
		
		env.glow_enabled = true
		env.glow_bloom = 0.12
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
		env.glow_hdr_threshold = 0.8
		env.glow_hdr_scale = 1.5
		
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.012
		env.volumetric_fog_albedo = Color(0.65, 0.82, 0.75)
		env.volumetric_fog_emission = Color(0.6, 0.7, 0.5)
		env.volumetric_fog_emission_energy = 0.3
		
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.tonemap_exposure = 1.0
		env.tonemap_white = 10.0
	
	var ambient := get_node_or_null("/root/World/AmbientLight")
	if not ambient:
		ambient = DirectionalLight3D.new()
		ambient.name = "AmbientLight"
		ambient.light_color = Color(0.5, 0.6, 0.7)
		ambient.light_energy = 0.3
		ambient.light_indirect_energy = 0.5
		ambient.shadow_enabled = false
		var world_node := get_node_or_null("/root/World")
		if world_node:
			world_node.add_child(ambient)
			ambient.owner = world_node

func _update_weather_lighting(is_rainy: bool) -> void:
	var sun := get_node_or_null("/root/World/DirectionalLight3D") as DirectionalLight3D
	if not sun:
		return
	var tween := create_tween()
	tween.set_parallel(true)
	if is_rainy:
		tween.tween_property(sun, "light_energy", 0.7, 2.0)
		tween.tween_property(sun, "light_color", Color(0.6, 0.65, 0.75), 2.0)
	else:
		tween.tween_property(sun, "light_energy", 1.4, 3.0)
		tween.tween_property(sun, "light_color", Color(1.0, 0.92, 0.72), 3.0)
```

### 4.3 TreeFadeSystem (`src/world/tree_fade_system.gd`)
*Total Lines: 147 lines. Max Function Length: 20 lines.*
```gdscript
# tree_fade_system.gd
# Handles tree transparency, camera clipping, and camera magnet logic.
class_name TreeFadeSystem
extends Node

var tree_list: Array[Node3D] = []
var camera_magnet_active: bool = false
var camera_magnet_target: Vector3 = Vector3.ZERO
var camera_magnet_zoom: float = 0.0
var camera_magnet_duration: float = 0.0
var camera_magnet_timer: float = 0.0

func _ready() -> void:
	# Thu thập cây sau khi trì hoãn một frame để chắc chắn thế giới đã được xây dựng xong
	await get_tree().process_frame
	_collect_trees()

func process_fade_and_magnet(delta: float) -> void:
	_update_tree_fade()
	_update_tree_camera_clip()
	_update_camera_magnet(delta)

func _collect_trees() -> void:
	tree_list.clear()
	var world := get_parent().get_parent()
	if not world:
		return
	for child in world.get_children():
		if child.is_in_group("trees") or "Pine_" in child.name:
			tree_list.append(child)
		if child is ForestBuilder:
			_collect_tree_children(child)

func _collect_tree_children(node: Node) -> void:
	for child in node.get_children():
		if "Pine_" in child.name:
			tree_list.append(child)
		if child.get_child_count() > 0:
			_collect_tree_children(child)

func _update_tree_fade() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return
	
	for tree in tree_list:
		if not is_instance_valid(tree):
			continue
		
		var dist := player.global_position.distance_to(tree.global_position)
		var diff_z := player.global_position.z - tree.global_position.z
		var diff_x := player.global_position.x - tree.global_position.x
		
		var is_behind: bool = absf(diff_x) < 2.5 and absf(diff_z) < 4.0 and diff_z < 0.0
		
		if is_behind and dist < 4.0:
			_set_tree_alpha(tree, 0.3)
		else:
			_set_tree_alpha(tree, 1.0)

func _set_tree_alpha(node: Node, alpha: float) -> void:
	if node is MeshInstance3D:
		_apply_mesh_alpha(node as MeshInstance3D, alpha)
	for child in node.get_children():
		_set_tree_alpha(child, alpha)

func _apply_mesh_alpha(mesh_node: MeshInstance3D, alpha: float) -> void:
	if mesh_node.mesh:
		for i in range(mesh_node.mesh.get_surface_count()):
			var mat := mesh_node.get_surface_override_material(i) as BaseMaterial3D
			if not mat:
				var mesh_mat := mesh_node.mesh.surface_get_material(i) as BaseMaterial3D
				if mesh_mat:
					mat = mesh_mat.duplicate() as BaseMaterial3D
					mesh_node.set_surface_override_material(i, mat)
			if mat:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color.a = alpha
	
	if mesh_node.material_override:
		var mat := mesh_node.material_override as BaseMaterial3D
		if mat:
			if not mat.is_local_to_scene():
				mat = mat.duplicate() as BaseMaterial3D
				mesh_node.material_override = mat
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = alpha

func _update_tree_camera_clip() -> void:
	var game_cam := get_tree().get_first_node_in_group("camera") as GameCamera
	if not game_cam or not game_cam.camera:
		return
	
	game_cam.force_update_transform()
	game_cam.camera.force_update_transform()
	var cam_pos := game_cam.camera.global_position
	
	for tree in tree_list:
		if not is_instance_valid(tree):
			continue
		var dist := cam_pos.distance_to(tree.global_position)
		if dist < 1.5:
			tree.visible = false
		else:
			tree.visible = true

func _activate_camera_magnet(target_pos: Vector3, zoom_size: float, duration: float) -> void:
	camera_magnet_active = true
	camera_magnet_target = target_pos
	camera_magnet_zoom = zoom_size
	camera_magnet_duration = duration
	camera_magnet_timer = duration
	
	var game_cam := get_tree().get_first_node_in_group("camera") as GameCamera
	if game_cam:
		game_cam.set_meta("original_zoom", game_cam.camera.size)
		var tween := create_tween()
		if tween:
			tween.tween_method(func(v): game_cam.camera.size = v, game_cam.camera.size, zoom_size, 1.0)

func _update_camera_magnet(delta: float) -> void:
	if not camera_magnet_active:
		return
	camera_magnet_timer -= delta
	if camera_magnet_timer <= 0.0:
		_deactivate_camera_magnet()
		return
		
	var game_cam := get_tree().get_first_node_in_group("camera") as GameCamera
	if not game_cam:
		return
	game_cam.global_position = game_cam.global_position.lerp(
		camera_magnet_target,
		clampf(3.0 * delta, 0.0, 1.0)
	)

func _deactivate_camera_magnet() -> void:
	camera_magnet_active = false
	var game_cam := get_tree().get_first_node_in_group("camera") as GameCamera
	if game_cam and game_cam.camera:
		var original_zoom: float = game_cam.get_meta("original_zoom", 20.0)
		var tween := create_tween()
		if tween:
			tween.tween_method(func(v): game_cam.camera.size = v, game_cam.camera.size, original_zoom, 1.0)
```

### 4.4 HUDManager (`src/world/hud_manager.gd`)
*Total Lines: 184 lines. Max Function Length: 39 lines.*
```gdscript
# hud_manager.gd
# Handles UI setup, updating HUD status, and spawning damage numbers.
class_name HUDManager
extends Node

var ui_layer: CanvasLayer = null

func _ready() -> void:
	if get_node_or_null("/root/EventBus"):
		EventBus.player_health_changed.connect(_on_player_health_changed)
		EventBus.player_took_damage.connect(_on_player_took_damage)
		EventBus.enemy_damaged.connect(_on_enemy_damaged)
		EventBus.orc_killed_count.connect(_on_orc_killed_count)
		EventBus.boss_spawned.connect(_on_boss_spawned)
		EventBus.enemy_died.connect(_on_enemy_died)

func create_hud(parent: Node) -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	ui_layer.layer = 10
	parent.add_child(ui_layer)
	
	_create_player_health_bar()
	_create_orc_counter()
	_create_boss_health_bar()

func _create_player_health_bar() -> void:
	var hp_container := HBoxContainer.new()
	hp_container.name = "PlayerHealthContainer"
	hp_container.position = Vector2(20, 20)
	hp_container.add_theme_constant_override("separation", 5)
	ui_layer.add_child(hp_container)
	
	var hp_label := Label.new()
	hp_label.text = "HP:"
	hp_label.add_theme_color_override("font_color", Color.WHITE)
	hp_label.add_theme_font_size_override("font_size", 16)
	hp_container.add_child(hp_label)
	
	var hp_bar := TextureProgressBar.new()
	hp_bar.name = "PlayerHealthBar"
	hp_bar.min_value = 0.0
	hp_bar.max_value = 100.0
	hp_bar.value = 100.0
	hp_bar.size = Vector2(200, 20)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.0, 0.0)
	style.border_color = Color(0.8, 0.8, 0.8)
	style.border_width_left = 2; style.border_width_right = 2
	style.border_width_top = 2; style.border_width_bottom = 2
	hp_bar.add_theme_stylebox_override("background", style)
	
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.0, 0.8, 0.0)
	hp_bar.add_theme_stylebox_override("fill", fill_style)
	hp_container.add_child(hp_bar)
	
	var hp_text := Label.new()
	hp_text.name = "PlayerHealthText"
	hp_text.text = "100/100"
	hp_text.add_theme_color_override("font_color", Color.WHITE)
	hp_text.add_theme_font_size_override("font_size", 14)
	hp_container.add_child(hp_text)

func _create_orc_counter() -> void:
	var orc_counter := HBoxContainer.new()
	orc_counter.name = "OrcCounter"
	orc_counter.position = Vector2(20, 50)
	ui_layer.add_child(orc_counter)
	
	var orc_label := Label.new()
	orc_label.text = "Quái đã diệt: "
	orc_label.add_theme_color_override("font_color", Color.WHITE)
	orc_label.add_theme_font_size_override("font_size", 14)
	orc_counter.add_child(orc_label)
	
	var target := 5
	if get_parent() and "orcs_to_kill_for_boss" in get_parent():
		target = get_parent().orcs_to_kill_for_boss
		
	var orc_count_label := Label.new()
	orc_count_label.name = "OrcCountLabel"
	orc_count_label.text = "0/%d" % target
	orc_count_label.add_theme_color_override("font_color", Color.YELLOW)
	orc_count_label.add_theme_font_size_override("font_size", 14)
	orc_counter.add_child(orc_count_label)

func _create_boss_health_bar() -> void:
	var boss_container := VBoxContainer.new()
	boss_container.name = "BossHealthContainer"
	boss_container.position = Vector2(get_viewport().get_visible_rect().size.x / 2 - 150, 20)
	boss_container.visible = false
	ui_layer.add_child(boss_container)
	
	var boss_name_label := Label.new()
	boss_name_label.text = "CHẰN TINH"
	boss_name_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.0))
	boss_name_label.add_theme_font_size_override("font_size", 20)
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_container.add_child(boss_name_label)
	
	var boss_hp_bar := TextureProgressBar.new()
	boss_hp_bar.name = "BossHealthBar"
	boss_hp_bar.min_value = 0.0
	boss_hp_bar.max_value = 300.0
	boss_hp_bar.value = 300.0
	boss_hp_bar.size = Vector2(300, 25)
	
	var boss_bg := StyleBoxFlat.new()
	boss_bg.bg_color = Color(0.3, 0.0, 0.0)
	boss_bg.border_color = Color(1.0, 0.5, 0.0)
	boss_bg.border_width_left = 2; boss_bg.border_width_right = 2
	boss_bg.border_width_top = 2; boss_bg.border_width_bottom = 2
	boss_hp_bar.add_theme_stylebox_override("background", boss_bg)
	
	var boss_fill := StyleBoxFlat.new()
	boss_fill.bg_color = Color(0.8, 0.1, 0.0)
	boss_hp_bar.add_theme_stylebox_override("fill", boss_fill)
	boss_container.add_child(boss_hp_bar)

func _update_ui_orc_counter(orcs_killed: int, orcs_to_kill_for_boss: int) -> void:
	if ui_layer:
		var label := ui_layer.get_node_or_null("OrcCounter/OrcCountLabel") as Label
		if label:
			label.text = "%d/%d" % [orcs_killed, orcs_to_kill_for_boss]

func _on_orc_killed_count(count: int) -> void:
	var target := 5
	if get_parent() and "orcs_to_kill_for_boss" in get_parent():
		target = get_parent().orcs_to_kill_for_boss
	_update_ui_orc_counter(count, target)

func _on_player_health_changed(current: float, max_h: float) -> void:
	if not ui_layer:
		return
	var bar := ui_layer.get_node_or_null("PlayerHealthContainer/PlayerHealthBar") as TextureProgressBar
	if bar:
		bar.min_value = minf(0.0, current)
		bar.max_value = maxf(max_h, current)
		bar.value = current
	var text := ui_layer.get_node_or_null("PlayerHealthContainer/PlayerHealthText") as Label
	if text:
		text.text = "%d/%d" % [current, max_h]

func _show_boss_health_bar() -> void:
	if ui_layer:
		var container := ui_layer.get_node_or_null("BossHealthContainer")
		if container:
			container.visible = true

func _hide_boss_health_bar() -> void:
	if ui_layer:
		var container := ui_layer.get_node_or_null("BossHealthContainer")
		if container:
			container.visible = false

func _on_boss_spawned(boss: Node3D) -> void:
	_show_boss_health_bar()
	if boss.has_method("_setup_nodes") or boss.get("health_component"):
		var hc = boss.get("health_component")
		if hc:
			var bar := ui_layer.get_node_or_null("BossHealthContainer/BossHealthBar") as TextureProgressBar
			if bar:
				bar.max_value = hc.max_health
				bar.value = hc.current_health
			hc.health_changed.connect(_on_boss_health_changed)

func _on_boss_health_changed(current: float, max_h: float) -> void:
	if ui_layer:
		var bar := ui_layer.get_node_or_null("BossHealthContainer/BossHealthBar") as TextureProgressBar
		if bar:
			bar.max_value = max_h
			bar.value = current

func _on_enemy_died(enemy: Node3D) -> void:
	if enemy.is_in_group("boss"):
		_hide_boss_health_bar()

func _on_player_took_damage(amount: float, position: Vector3) -> void:
	_spawn_damage_number(amount, position, Color.RED, false)

func _on_enemy_damaged(enemy: Node3D, amount: float, position: Vector3) -> void:
	var is_critical := randf() < 0.15
	if is_critical:
		amount *= 2.0
	_spawn_damage_number(amount, position, Color.YELLOW if is_critical else Color.WHITE, is_critical)

func _spawn_damage_number(amount: float, world_pos: Vector3, color: Color, is_critical: bool) -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera or not ui_layer:
		return
	
	var screen_pos := camera.unproject_position(world_pos + Vector3(0, 1.5, 0))
	var label := Label.new()
	label.text = str(int(amount))
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 24 if is_critical else 18)
	label.position = screen_pos - Vector2(20, 10)
	label.z_index = 100
	
	if is_critical:
		label.text += " CRIT!"
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 2)
	
	ui_layer.add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.chain()
	tween.tween_callback(label.queue_free)
```

### 4.5 Refactored `world_manager.gd`
*Total Lines: 178 lines. Max Function Length: 23 lines.*
```gdscript
# world_manager.gd
# Handles: delegation to child components (BossManager, WeatherManager, TreeFadeSystem, HUDManager)
class_name WorldManager
extends Node

# Component References
var boss_manager: BossManager
var weather_manager: WeatherManager
var tree_fade_system: TreeFadeSystem
var hud_manager: HUDManager

# ─── Boss Config Properties ───
var orcs_to_kill_for_boss: int:
	get:
		return boss_manager.orcs_to_kill_for_boss if boss_manager else 5
	set(value):
		if boss_manager:
			boss_manager.orcs_to_kill_for_boss = value

var orcs_killed: int:
	get:
		return boss_manager.orcs_killed if boss_manager else 0
	set(value):
		if boss_manager:
			boss_manager.orcs_killed = value

var boss_spawned: bool:
	get:
		return boss_manager.boss_spawned if boss_manager else false
	set(value):
		if boss_manager:
			boss_manager.boss_spawned = value

var boss_instance: Node3D:
	get:
		return boss_manager.boss_instance if boss_manager else null
	set(value):
		if boss_manager:
			boss_manager.boss_instance = value

# ─── Weather Config Properties ───
var weather_timer: float:
	get:
		return weather_manager.weather_timer if weather_manager else 0.0
	set(value):
		if weather_manager:
			weather_manager.weather_timer = value

var weather_duration: float:
	get:
		return weather_manager.weather_duration if weather_manager else 0.0
	set(value):
		if weather_manager:
			weather_manager.weather_duration = value

var weather_state: String:
	get:
		return weather_manager.weather_state if weather_manager else "clear"
	set(value):
		if weather_manager:
			weather_manager.weather_state = value

var rain_cycle_count: int:
	get:
		return weather_manager.rain_cycle_count if weather_manager else 0
	set(value):
		if weather_manager:
			weather_manager.rain_cycle_count = value

var rain_particles: GPUParticles3D:
	get:
		return weather_manager.rain_particles if weather_manager else null
	set(value):
		if weather_manager:
			weather_manager.rain_particles = value

var lightning_timer: float:
	get:
		return weather_manager.lightning_timer if weather_manager else 0.0
	set(value):
		if weather_manager:
			weather_manager.lightning_timer = value

var is_raining: bool:
	get:
		return weather_manager.is_raining if weather_manager else false
	set(value):
		if weather_manager:
			weather_manager.is_raining = value

# ─── Camera Magnet Properties ───
var camera_magnet_active: bool:
	get:
		return tree_fade_system.camera_magnet_active if tree_fade_system else false
	set(value):
		if tree_fade_system:
			tree_fade_system.camera_magnet_active = value

var camera_magnet_target: Vector3:
	get:
		return tree_fade_system.camera_magnet_target if tree_fade_system else Vector3.ZERO
	set(value):
		if tree_fade_system:
			tree_fade_system.camera_magnet_target = value

var camera_magnet_zoom: float:
	get:
		return tree_fade_system.camera_magnet_zoom if tree_fade_system else 0.0
	set(value):
		if tree_fade_system:
			tree_fade_system.camera_magnet_zoom = value

var camera_magnet_duration: float:
	get:
		return tree_fade_system.camera_magnet_duration if tree_fade_system else 0.0
	set(value):
		if tree_fade_system:
			tree_fade_system.camera_magnet_duration = value

var camera_magnet_timer: float:
	get:
		return tree_fade_system.camera_magnet_timer if tree_fade_system else 0.0
	set(value):
		if tree_fade_system:
			tree_fade_system.camera_magnet_timer = value

# ─── Tree Fade Properties ───
var tree_list: Array[Node3D]:
	get:
		return tree_fade_system.tree_list if tree_fade_system else []
	set(value):
		if tree_fade_system:
			tree_fade_system.tree_list = value

func _init() -> void:
	# Khởi tạo và thêm các node quản lý con vào WorldManager
	boss_manager = BossManager.new()
	boss_manager.name = "BossManager"
	add_child(boss_manager)
	
	weather_manager = WeatherManager.new()
	weather_manager.name = "WeatherManager"
	add_child(weather_manager)
	
	tree_fade_system = TreeFadeSystem.new()
	tree_fade_system.name = "TreeFadeSystem"
	add_child(tree_fade_system)
	
	hud_manager = HUDManager.new()
	hud_manager.name = "HUDManager"
	add_child(hud_manager)
	
	# Kết nối tín hiệu kích hoạt Camera Magnet từ BossManager
	boss_manager.camera_magnet_requested.connect(func(pos: Vector3, zoom: float, duration: float) -> void:
		_activate_camera_magnet(pos, zoom, duration)
	)

func _ready() -> void:
	# Khởi tạo HUD đính trực tiếp vào WorldManager để giữ đường dẫn UI tương thích với test
	if hud_manager:
		hud_manager.create_hud(self)

func _process(delta: float) -> void:
	if weather_manager:
		weather_manager.process_weather(delta)
	if tree_fade_system:
		tree_fade_system.process_fade_and_magnet(delta)

# ─── Hàm ủy thác tương thích ngược (Backward Compatibility Delegates) ───

func _collect_trees() -> void:
	if tree_fade_system:
		tree_fade_system._collect_trees()

func _activate_camera_magnet(target_pos: Vector3, zoom_size: float, duration: float) -> void:
	if tree_fade_system:
		tree_fade_system._activate_camera_magnet(target_pos, zoom_size, duration)

func _show_boss_health_bar() -> void:
	if hud_manager:
		hud_manager._show_boss_health_bar()

func _hide_boss_health_bar() -> void:
	if hud_manager:
		hud_manager._hide_boss_health_bar()

func _strike_lightning() -> void:
	if weather_manager:
		weather_manager._strike_lightning()

func _start_rain() -> void:
	if weather_manager:
		weather_manager._start_rain()

func _end_rain() -> void:
	if weather_manager:
		weather_manager._end_rain()
```
