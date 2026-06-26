# Refactoring Analysis: Splitting `world_manager.gd`

This document details the architectural design to refactor `world_manager.gd` from a monolithic manager (697 lines) into four clean, single-responsibility child component nodes while preserving complete backward compatibility with the existing test suites.

---

## 1. Architectural Overview & Component Breakdown

The refactored design decomposes the responsibilities of `WorldManager` into 4 dedicated, decoupled child component nodes added to the scene tree. `WorldManager` remains as a parent facade that exposes the existing variables and APIs to preserve backward compatibility for tests and external scripts.

```
WorldManager (Facade)
├── BossManager (Boss lifecycle & kill tracking)
├── WeatherManager (Weather cycles & lighting/ambience)
├── TreeFadeSystem (Tree transparency & Camera clipping/magnet)
└── HUDManager (HUD setup, health, and damage popups)
```

### Component Definition and Responsibilities

| Component | Target File | Responsibilities | Key API / Variables |
|---|---|---|---|
| **BossManager** | `res://src/world/boss_manager.gd` | Spawns Boss (Chằn Tinh), tracks orc kills, updates boss stats, handles boss death. | `orcs_to_kill_for_boss`, `orcs_killed`, `boss_spawned`, `boss_instance`, `_spawn_boss()` |
| **WeatherManager** | `res://src/world/weather_manager.gd` | Drives weather cycles (clear, rain, storm), manages rain particles, lightning visual and audio effects, and updates environment lighting. | `weather_state`, `weather_timer`, `weather_duration`, `rain_particles`, `_strike_lightning()` |
| **TreeFadeSystem** | `res://src/world/tree_fade_system.gd` | Collects trees recursively, fades trees if player is behind them, hides trees near camera, and handles camera magnet transitions. | `tree_list`, `camera_magnet_active`, `_collect_trees()`, `_activate_camera_magnet()` |
| **HUDManager** | `res://src/world/hud_manager.gd` | Instantiates CanvasLayer "UI" and HUD progress bars, updates health bars/orc counters, and handles critical/normal damage popups. | `player_health_bar`, `boss_health_bar`, `orc_counter_label`, `_create_hud()`, `_spawn_damage_number()` |

---

## 2. Backward Compatibility Strategy

To ensure that no test files need to be modified, `WorldManager` continues to act as the primary interface for properties and functions. We use **GDScript property getters and setters** to dynamically redirect property access to the child component nodes, and **delegator functions** to forward API calls.

### Property Redirection Pattern
Using GDScript 2.0 getter/setter syntax, each legacy field is redirected. For example:
```gdscript
var weather_state: String = "clear":
	get:
		return weather_manager.weather_state if weather_manager else _weather_state
	set(value):
		_weather_state = value
		if weather_manager:
			weather_manager.weather_state = value
var _weather_state: String = "clear"
```
This guarantees that:
- Direct dot access (e.g. `wm.weather_state = "rain"`) continues to work.
- Node paths (e.g. `get_node("WorldManager")` and subnodes under `WorldManager/UI`) remain perfectly valid since `HUDManager` adds the `UI` node as a child of its parent `WorldManager`.

---

## 3. Communication Patterns between Components

The child components communicate cleanly and remain decoupled:
1. **Facade Delegation (Downwards):** The parent `WorldManager` calls methods on children (e.g., `hud_manager._show_boss_health_bar()`).
2. **Facade Access (Upwards):** Child components access parent properties or trigger shared services via `get_parent()` (e.g., `get_parent()._activate_camera_magnet(...)`).
3. **Global Event Bus (Decoupled):** Global events such as enemy death or player health changes use the central `EventBus` singleton. For example:
   - `BossManager` listens to `EventBus.enemy_died` to increment kills.
   - `BossManager` emits `EventBus.boss_spawned(boss)`.
   - `HUDManager` listens to `EventBus.boss_spawned` to connect to the boss's health component and show the health bar.

---

## 4. Proposed Source Code for Components

All proposed files are under 200 lines and all functions are under 50 lines.

### A. BossManager (`res://src/world/boss_manager.gd`)
*Total Lines: ~75 lines | Maximum Function Length: 31 lines*
```gdscript
# boss_manager.gd
# Handles: boss spawning, kill tracking
extends Node

var orcs_to_kill_for_boss: int = 5
var orcs_killed: int = 0
var boss_spawned: bool = false
var boss_instance: Node3D = null

func _ready() -> void:
	var eb := get_node("/root/EventBus")
	if eb:
		eb.enemy_died.connect(_on_enemy_died)

func _on_enemy_died(enemy: Node3D) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy.is_in_group("boss"):
		get_parent()._hide_boss_health_bar()
		boss_instance = null
		return

	if enemy.is_in_group("orc_mobs") and not enemy.is_in_group("boss"):
		orcs_killed += 1
		var eb := get_node("/root/EventBus")
		if eb:
			eb.orc_killed_count.emit(orcs_killed)
		get_parent()._update_ui_orc_counter()
		
		if orcs_killed >= orcs_to_kill_for_boss and not boss_spawned:
			_spawn_boss()

func _spawn_boss() -> void:
	boss_spawned = true
	print("BOSS SPAWNED! Chằn Tinh xuất hiện!")
	
	var boss := CharacterBody3D.new()
	boss.name = "BossChằnTinh"
	boss.add_to_group("boss")
	boss.add_to_group("orc_mobs")
	
	var boss_script := preload("res://src/world/orc_mob.gd")
	boss.set_script(boss_script)
	boss.position = Vector3(-15.0, 0.2, -15.0)
	boss.scale = Vector3(18.0, 18.0, 18.0)
	
	get_parent().get_parent().add_child(boss)
	boss_instance = boss
	
	if boss.has_method("_setup_nodes"):
		_setup_boss_stats(boss)
	
	get_parent()._show_boss_health_bar()
	get_parent()._activate_camera_magnet(Vector3(-15.0, 0.0, -15.0), 25.0, 8.0)
	
	var eb := get_node("/root/EventBus")
	if eb:
		eb.boss_spawned.emit(boss)

func _setup_boss_stats(boss: CharacterBody3D) -> void:
	if boss.health_component:
		boss.health_component.max_health = 300.0
		boss.health_component.current_health = 300.0
		boss.health_component.health_changed.connect(func(current: float, max_h: float) -> void:
			var bar := get_parent().get_node_or_null("UI/BossHealthContainer/BossHealthBar") as TextureProgressBar
			if bar:
				bar.max_value = max_h
				bar.value = current
		)
	boss.speed = 1.5
	boss.attack_damage = 25.0
	boss.attack_range = 2.5
	boss.detection_range = 20.0
```

### B. WeatherManager (`res://src/world/weather_manager.gd`)
*Total Lines: ~195 lines | Maximum Function Length: 32 lines*
```gdscript
# weather_manager.gd
# Handles: weather cycles, storm particle effects, lightning strikes
extends Node

var weather_timer: float = 300.0
var weather_duration: float = 0.0
var weather_state: String = "clear"
var rain_cycle_count: int = 0
var rain_particles: GPUParticles3D = null
var lightning_timer: float = 0.0
var is_raining: bool = false

func _process(delta: float) -> void:
	_update_weather(delta)

func _update_weather(delta: float) -> void:
	if weather_state == "clear":
		weather_timer -= delta
		if weather_timer <= 0.0:
			_start_rain()
	else:
		weather_duration -= delta
		if weather_duration <= 0.0:
			_end_rain()
	
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
	
	var eb := get_node("/root/EventBus")
	if eb:
		eb.weather_changed.emit(weather_state)
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
	var eb := get_node("/root/EventBus")
	if eb:
		eb.weather_changed.emit("clear")
	
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
	
	get_parent().get_parent().add_child(rain_particles)

func _strike_lightning() -> void:
	print("⚡ LIGHTNING STRIKE!")
	var x := randf_range(-45.0, 45.0)
	var z := randf_range(-45.0, 45.0)
	var strike_pos := Vector3(x, 0.0, z)
	
	_spawn_lightning_flash()
	_spawn_lightning_bolt(strike_pos)
	
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and player.global_position.distance_to(strike_pos) < 5.0:
		if player.has_method("_on_damaged"):
			player._on_damaged(20.0, null)
	
	var audio := get_node_or_null("/root/World/AudioManager") as AudioManager
	if audio:
		audio.play_sfx("thunder", strike_pos, 0.2)

func _spawn_lightning_flash() -> void:
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

func _spawn_lightning_bolt(strike_pos: Vector3) -> void:
	var bolt := MeshInstance3D.new()
	var bolt_mesh := immediate_mesh_create_lightning(strike_pos, strike_pos + Vector3(0, 15, 0))
	if bolt_mesh:
		bolt.mesh = bolt_mesh
		get_parent().get_parent().add_child(bolt)
		var bt := create_tween()
		bt.tween_interval(0.2)
		bt.tween_callback(bolt.queue_free)

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
		_setup_env_effects(world_env.environment)
	
	_add_ambient_light()

func _setup_env_effects(env: Environment) -> void:
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

func _add_ambient_light() -> void:
	var ambient := get_node_or_null("/root/World/AmbientLight")
	if not ambient:
		var new_ambient = DirectionalLight3D.new()
		new_ambient.name = "AmbientLight"
		new_ambient.light_color = Color(0.5, 0.6, 0.7)
		new_ambient.light_energy = 0.3
		new_ambient.light_indirect_energy = 0.5
		new_ambient.shadow_enabled = false
		get_node("/root/World").add_child(new_ambient)
		new_ambient.owner = get_node("/root/World")

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

### C. TreeFadeSystem (`res://src/world/tree_fade_system.gd`)
*Total Lines: ~135 lines | Maximum Function Length: 21 lines*
```gdscript
# tree_fade_system.gd
# Handles: transparent trees, camera clipping checks, camera magnet
extends Node

var tree_list: Array[Node3D] = []

# Camera Magnet State
var camera_magnet_active: bool = false
var camera_magnet_target: Vector3 = Vector3.ZERO
var camera_magnet_zoom: float = 0.0
var camera_magnet_duration: float = 0.0
var camera_magnet_timer: float = 0.0

func _process(delta: float) -> void:
	_update_tree_fade()
	_update_tree_camera_clip()
	_update_camera_magnet(delta)

func _collect_trees() -> void:
	tree_list.clear()
	var world := get_parent().get_parent()
	if world:
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
		tree.visible = dist >= 1.5

func _activate_camera_magnet(target_pos: Vector3, zoom_size: float, duration: float) -> void:
	camera_magnet_active = true
	camera_magnet_target = target_pos
	camera_magnet_zoom = zoom_size
	camera_magnet_duration = duration
	camera_magnet_timer = duration
	
	var game_cam := get_tree().get_first_node_in_group("camera") as GameCamera
	if game_cam and game_cam.camera:
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
	if game_cam:
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

### D. HUDManager (`res://src/world/hud_manager.gd`)
*Total Lines: ~180 lines | Maximum Function Length: 32 lines*
```gdscript
# hud_manager.gd
# Handles: HUD/UI initialization, damage numbers
extends Node

var player_health_bar: Node = null
var boss_health_bar: Node = null
var orc_counter_label: Node = null
var ui_canvas: CanvasLayer = null

func _ready() -> void:
	var eb := get_node("/root/EventBus")
	if eb:
		eb.player_health_changed.connect(_on_player_health_changed)
		eb.player_took_damage.connect(_on_player_took_damage)
		eb.enemy_damaged.connect(_on_enemy_damaged)
		eb.boss_spawned.connect(_on_boss_spawned)
	_create_hud()

func _create_hud() -> void:
	ui_canvas = CanvasLayer.new()
	ui_canvas.name = "UI"
	ui_canvas.layer = 10
	get_parent().add_child(ui_canvas)
	
	_create_player_health_bar()
	_create_orc_counter()
	_create_boss_health_bar()

func _create_player_health_bar() -> void:
	var hp_container := HBoxContainer.new()
	hp_container.name = "PlayerHealthContainer"
	hp_container.position = Vector2(20, 20)
	hp_container.add_theme_constant_override("separation", 5)
	ui_canvas.add_child(hp_container)
	
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
	hp_bar.fill_mode = 0
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.0, 0.0)
	style.border_color = Color(0.8, 0.8, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	hp_bar.add_theme_stylebox_override("background", style)
	
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.0, 0.8, 0.0)
	hp_bar.add_theme_stylebox_override("fill", fill_style)
	
	hp_container.add_child(hp_bar)
	player_health_bar = hp_bar
	
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
	ui_canvas.add_child(orc_counter)
	
	var orc_label := Label.new()
	orc_label.text = "Quái đã diệt: "
	orc_label.add_theme_color_override("font_color", Color.WHITE)
	orc_label.add_theme_font_size_override("font_size", 14)
	orc_counter.add_child(orc_label)
	
	var orc_count_label := Label.new()
	orc_count_label.name = "OrcCountLabel"
	orc_count_label.text = "0/%d" % get_parent().orcs_to_kill_for_boss
	orc_count_label.add_theme_color_override("font_color", Color.YELLOW)
	orc_count_label.add_theme_font_size_override("font_size", 14)
	orc_counter.add_child(orc_count_label)
	orc_counter_label = orc_count_label

func _create_boss_health_bar() -> void:
	var boss_container := VBoxContainer.new()
	boss_container.name = "BossHealthContainer"
	boss_container.position = Vector2(get_viewport().get_visible_rect().size.x / 2 - 150, 20)
	boss_container.visible = false
	ui_canvas.add_child(boss_container)
	
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
	boss_bg.border_width_left = 2
	boss_bg.border_width_right = 2
	boss_bg.border_width_top = 2
	boss_bg.border_width_bottom = 2
	boss_hp_bar.add_theme_stylebox_override("background", boss_bg)
	
	var boss_fill := StyleBoxFlat.new()
	boss_fill.bg_color = Color(0.8, 0.1, 0.0)
	boss_hp_bar.add_theme_stylebox_override("fill", boss_fill)
	
	boss_container.add_child(boss_hp_bar)
	boss_health_bar = boss_hp_bar

func _update_ui_orc_counter() -> void:
	var label := ui_canvas.get_node_or_null("OrcCounter/OrcCountLabel") as Label
	if label:
		var killed := get_parent().orcs_killed
		var target := get_parent().orcs_to_kill_for_boss
		label.text = "%d/%d" % [killed, target]

func _on_player_health_changed(current: float, max_h: float) -> void:
	var bar := ui_canvas.get_node_or_null("PlayerHealthContainer/PlayerHealthBar") as TextureProgressBar
	if bar:
		bar.min_value = minf(0.0, current)
		bar.max_value = maxf(max_h, current)
		bar.value = current
	var text := ui_canvas.get_node_or_null("PlayerHealthContainer/PlayerHealthText") as Label
	if text:
		text.text = "%d/%d" % [current, max_h]

func _show_boss_health_bar() -> void:
	var container := ui_canvas.get_node_or_null("BossHealthContainer")
	if container:
		container.visible = true

func _hide_boss_health_bar() -> void:
	var container := ui_canvas.get_node_or_null("BossHealthContainer")
	if container:
		container.visible = false

func _on_player_took_damage(amount: float, position: Vector3) -> void:
	_spawn_damage_number(amount, position, Color.RED, false)

func _on_enemy_damaged(enemy: Node3D, amount: float, position: Vector3) -> void:
	var is_critical := randf() < 0.15
	if is_critical:
		amount *= 2.0
	_spawn_damage_number(amount, position, Color.YELLOW if is_critical else Color.WHITE, is_critical)

func _spawn_damage_number(amount: float, world_pos: Vector3, color: Color, is_critical: bool) -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
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
	
	ui_canvas.add_child(label)
	_animate_damage_number(label)

func _animate_damage_number(label: Label) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.chain()
	tween.tween_callback(label.queue_free)

func _on_boss_spawned(boss: Node3D) -> void:
	if boss and boss.has_node("HealthComponent"):
		var health := boss.get_node("HealthComponent")
		if health.has_signal("health_changed"):
			health.health_changed.connect(func(current: float, max_h: float) -> void:
				if boss_health_bar:
					boss_health_bar.max_value = max_h
					boss_health_bar.value = current
			)
```

### E. Backward-Compatible Facade (`res://src/world/world_manager.gd`)
*Total Lines: ~180 lines | Maximum Function Length: 8 lines*
```gdscript
# world_manager.gd
# Facade that delegates to 4 child components for modularity
class_name WorldManager
extends Node

# Child Component References
var boss_manager: Node = null
var weather_manager: Node = null
var tree_fade_system: Node = null
var hud_manager: Node = null

# ─── Boss Config Delegation ──────────────────────────────────────────────────
@export var orcs_to_kill_for_boss: int = 5:
	get:
		return boss_manager.orcs_to_kill_for_boss if boss_manager else _orcs_to_kill_for_boss
	set(value):
		_orcs_to_kill_for_boss = value
		if boss_manager:
			boss_manager.orcs_to_kill_for_boss = value
var _orcs_to_kill_for_boss: int = 5

var orcs_killed: int = 0:
	get:
		return boss_manager.orcs_killed if boss_manager else _orcs_killed
	set(value):
		_orcs_killed = value
		if boss_manager:
			boss_manager.orcs_killed = value
var _orcs_killed: int = 0

var boss_spawned: bool = false:
	get:
		return boss_manager.boss_spawned if boss_manager else _boss_spawned
	set(value):
		_boss_spawned = value
		if boss_manager:
			boss_manager.boss_spawned = value
var _boss_spawned: bool = false

var boss_instance: Node3D = null:
	get:
		return boss_manager.boss_instance if boss_manager else _boss_instance
	set(value):
		_boss_instance = value
		if boss_manager:
			boss_manager.boss_instance = value
var _boss_instance: Node3D = null

# ─── Weather Config Delegation ───────────────────────────────────────────────
var weather_timer: float = 0.0:
	get:
		return weather_manager.weather_timer if weather_manager else _weather_timer
	set(value):
		_weather_timer = value
		if weather_manager:
			weather_manager.weather_timer = value
var _weather_timer: float = 0.0

var weather_duration: float = 0.0:
	get:
		return weather_manager.weather_duration if weather_manager else _weather_duration
	set(value):
		_weather_duration = value
		if weather_manager:
			weather_manager.weather_duration = value
var _weather_duration: float = 0.0

var weather_state: String = "clear":
	get:
		return weather_manager.weather_state if weather_manager else _weather_state
	set(value):
		_weather_state = value
		if weather_manager:
			weather_manager.weather_state = value
var _weather_state: String = "clear"

var rain_cycle_count: int = 0:
	get:
		return weather_manager.rain_cycle_count if weather_manager else _rain_cycle_count
	set(value):
		_rain_cycle_count = value
		if weather_manager:
			weather_manager.rain_cycle_count = value
var _rain_cycle_count: int = 0

var rain_particles: GPUParticles3D = null:
	get:
		return weather_manager.rain_particles if weather_manager else _rain_particles
	set(value):
		_rain_particles = value
		if weather_manager:
			weather_manager.rain_particles = value
var _rain_particles: GPUParticles3D = null

var lightning_timer: float = 0.0:
	get:
		return weather_manager.lightning_timer if weather_manager else _lightning_timer
	set(value):
		_lightning_timer = value
		if weather_manager:
			weather_manager.lightning_timer = value
var _lightning_timer: float = 0.0

var is_raining: bool = false:
	get:
		return weather_manager.is_raining if weather_manager else _is_raining
	set(value):
		_is_raining = value
		if weather_manager:
			weather_manager.is_raining = value
var _is_raining: bool = false

# ─── Tree Fade & Camera Magnet Delegation ───────────────────────────────────
var tree_list: Array[Node3D] = []:
	get:
		return tree_fade_system.tree_list if tree_fade_system else _tree_list
	set(value):
		_tree_list = value
		if tree_fade_system:
			tree_fade_system.tree_list = value
var _tree_list: Array[Node3D] = []

var camera_magnet_active: bool = false:
	get:
		return tree_fade_system.camera_magnet_active if tree_fade_system else _camera_magnet_active
	set(value):
		_camera_magnet_active = value
		if tree_fade_system:
			tree_fade_system.camera_magnet_active = value
var _camera_magnet_active: bool = false

var camera_magnet_target: Vector3 = Vector3.ZERO:
	get:
		return tree_fade_system.camera_magnet_target if tree_fade_system else _camera_magnet_target
	set(value):
		_camera_magnet_target = value
		if tree_fade_system:
			tree_fade_system.camera_magnet_target = value
var _camera_magnet_target: Vector3 = Vector3.ZERO

var camera_magnet_zoom: float = 0.0:
	get:
		return tree_fade_system.camera_magnet_zoom if tree_fade_system else _camera_magnet_zoom
	set(value):
		_camera_magnet_zoom = value
		if tree_fade_system:
			tree_fade_system.camera_magnet_zoom = value
var _camera_magnet_zoom: float = 0.0

var camera_magnet_duration: float = 0.0:
	get:
		return tree_fade_system.camera_magnet_duration if tree_fade_system else _camera_magnet_duration
	set(value):
		_camera_magnet_duration = value
		if tree_fade_system:
			tree_fade_system.camera_magnet_duration = value
var _camera_magnet_duration: float = 0.0

var camera_magnet_timer: float = 0.0:
	get:
		return tree_fade_system.camera_magnet_timer if tree_fade_system else _camera_magnet_timer
	set(value):
		_camera_magnet_timer = value
		if tree_fade_system:
			tree_fade_system.camera_magnet_timer = value
var _camera_magnet_timer: float = 0.0

# ─── HUD References Delegation ───────────────────────────────────────────────
var player_health_bar: Node:
	get:
		return hud_manager.player_health_bar if hud_manager else null
	set(value):
		if hud_manager: hud_manager.player_health_bar = value
var boss_health_bar: Node:
	get:
		return hud_manager.boss_health_bar if hud_manager else null
	set(value):
		if hud_manager: hud_manager.boss_health_bar = value
var orc_counter_label: Node:
	get:
		return hud_manager.orc_counter_label if hud_manager else null
	set(value):
		if hud_manager: hud_manager.orc_counter_label = value

func _ready() -> void:
	boss_manager = _setup_component("BossManager", preload("res://src/world/boss_manager.gd"))
	weather_manager = _setup_component("WeatherManager", preload("res://src/world/weather_manager.gd"))
	tree_fade_system = _setup_component("TreeFadeSystem", preload("res://src/world/tree_fade_system.gd"))
	hud_manager = _setup_component("HUDManager", preload("res://src/world/hud_manager.gd"))
	
	boss_manager.orcs_to_kill_for_boss = _orcs_to_kill_for_boss
	weather_manager._configure_lighting()

func _setup_component(c_name: String, script: Script) -> Node:
	var comp = get_node_or_null(c_name)
	if not comp:
		comp = Node.new()
		comp.name = c_name
		comp.set_script(script)
		add_child(comp)
	return comp

# ─── Backward Compatible Delegation Methods ───────────────────────────────────
func _collect_trees() -> void:
	if tree_fade_system:
		tree_fade_system._collect_trees()

func _show_boss_health_bar() -> void:
	if hud_manager:
		hud_manager._show_boss_health_bar()

func _hide_boss_health_bar() -> void:
	if hud_manager:
		hud_manager._hide_boss_health_bar()

func _update_ui_orc_counter() -> void:
	if hud_manager:
		hud_manager._update_ui_orc_counter()

func _activate_camera_magnet(target_pos: Vector3, zoom_size: float, duration: float) -> void:
	if tree_fade_system:
		tree_fade_system._activate_camera_magnet(target_pos, zoom_size, duration)
```

---

## 5. Verification Plan

Since this is a read-only investigation, the proposed design can be verified immediately after implementer execution using the project's test command (using Godot GUT or equivalent test runner for the project):
```powershell
# Run Gut tests in the project (from project root)
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://src/tests/cases
```

All existing tests in `src/tests/cases/` must pass cleanly without code changes. Specifically:
- `test_boss_lifecycle_tier1.gd` & `test_boss_lifecycle_tier2.gd` (boss spawning and properties)
- `test_weather_tier1.gd` & `test_weather_tier2.gd` (weather timer and duration transitions)
- `test_camera_tier1.gd` & `test_camera_tier2.gd` (camera clipping and magnet)
- `test_hud_ui_tier1.gd` & `test_hud_ui_tier2.gd` (UI controls and progress bars)
- `test_tree_fade_tier1.gd` & `test_tree_fade_tier2.gd` (tree fading and recursion)
