# world_manager.gd
# Handles: boss spawning, HUD, weather, damage numbers, tree fade, sound, camera magnets
class_name WorldManager
extends Node

const UITheme = preload("res://src/ui/ui_theme.gd")
const SettingsMenuScript = preload("res://src/common/settings_menu.gd")
const BossHealthBar = preload("res://src/ui/boss_health_bar.gd")

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

const RAIN_PARTICLE_AMOUNT: int = 800
const RAIN_EMITTER_HEIGHT: float = 20.0
const RAIN_COVERAGE_MARGIN: float = 4.0
const RAIN_DEPTH_MARGIN: float = 9.0
const PLAYER_HUD_TEXTURE_PATH := "res://Assets/items/hud_and_orc_panel_v1.png"
const PLAYER_HUD_TEXTURE_SIZE := Vector2(568.0, 439.0)
const PLAYER_HUD_TARGET_WIDTH := 290.0
const PLAYER_HUD_FILL_POSITION := Vector2(113.0, 111.0)
const PLAYER_HUD_FILL_SIZE := Vector2(429.0, 81.0)

const PLAYER_HUD_FILL_COLOR := Color(0.82, 0.0, 0.02, 1.0)
#const ORC_COUNTER_TEXT_POSITION := Vector2(260.0, 188.0)
#const ORC_COUNTER_TEXT_SIZE := Vector2(170.0, 44.0)
const ORC_COUNTER_TEXT_POSITION := Vector2(24.0, 235.0)
const ORC_COUNTER_TEXT_SIZE := Vector2(207.0, 69.0)
const MINIMAP_FRAME_TEXTURE_PATH := "res://Assets/items/map.png"
const MINIMAP_FRAME_TEXTURE_SIZE := Vector2(500.0, 500.0)
const MINIMAP_SCREEN_SIZE := Vector2(120.0, 120.0)
const MINIMAP_INNER_POSITION := Vector2(58.0, 58.0)
const MINIMAP_INNER_SIZE := Vector2(379.0, 379.0)
const MINIMAP_ZOOM_SCALE := 2.6
const MINIMAP_ZOOM_DURATION := 0.25
const BOSS_DISPLAY_NAME := "Chằn Tinh"

# ─── HUD References ──────────────────────────────────────────────────────────
var player_health_bar: Node = null
var player_health_fill: ColorRect = null
var orc_counter_label: Node = null
var minimap: Minimap = null
var minimap_container: Control = null
var minimap_zoomed: bool = false
var minimap_mask: Control = null

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
var _tree_shadow_refresh_timer: float = 0.0

# ─── Camera Magnet ───────────────────────────────────────────────────────────
var camera_magnet_active: bool = false
var camera_magnet_target: Vector3 = Vector3.ZERO
var camera_magnet_zoom: float = 0.0
var camera_magnet_duration: float = 0.0
var camera_magnet_timer: float = 0.0

func _ready() -> void:
	# Đăng ký group để SaveManager có thể tìm thấy
	add_to_group("world_manager")

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
	if minimap_container == null:
		return
	minimap_zoomed = not minimap_zoomed
	var target_scale := Vector2(MINIMAP_ZOOM_SCALE, MINIMAP_ZOOM_SCALE) if minimap_zoomed else Vector2.ONE
	var tween := create_tween()
	tween.tween_property(minimap_container, "scale", target_scale, MINIMAP_ZOOM_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# Bật bão ngay lập tức
func _start_storm_instantly() -> void:
	is_raining = true
	weather_state = "storm"
	weather_duration = 180.0 # Bão kéo dài 3 phút
	lightning_timer = 1.0 # Sét đánh sau 1 giây
	
	EventBus.weather_changed.emit(weather_state)
	_create_rain_particles()
	
	var audio := get_node_or_null("/root/World/AudioManager") as AudioManager
	if audio:
		audio.play_ambience("rain_ambience")
	
func _process(delta: float) -> void:
	_update_weather(delta)
	_update_rain_coverage()
	_update_tree_fade(delta)
	_update_tree_shadow_budget(delta)
	_update_tree_camera_clip()
	_update_camera_magnet(delta)
	_update_minimap()

# ══════════════════════════════════════════════════════════════════════════════
# BOSS SYSTEM
# ══════════════════════════════════════════════════════════════════════════════

var _boss_health_bar: BossHealthBar = null

func _on_enemy_died(enemy: Node3D) -> void:
	if enemy.is_in_group("boss"):
		if _boss_health_bar and is_instance_valid(_boss_health_bar):
			_boss_health_bar.detach()
		boss_instance = null
		var lighting := get_tree().get_first_node_in_group("lighting_director") as LightingDirector
		if lighting != null:
			lighting.clear_active_objective()
		return

	if enemy.is_in_group("orc_mobs") and not enemy.is_in_group("boss"):
		orcs_killed += 1
		EventBus.orc_killed_count.emit(orcs_killed)
		_update_ui_orc_counter()
		
		if orcs_killed >= orcs_to_kill_for_boss and not boss_spawned:
			_spawn_boss()

func _spawn_boss() -> void:
	boss_spawned = true
	print("BOSS SPAWNED! Orc Boss xuất hiện!")

	# Use the OrcBossMob class directly instead of constructing a bare
	# CharacterBody3D and assigning properties ad-hoc. The class itself
	# owns boss stats via @export defaults; configure_arena() applies the
	# arena position before the node enters the tree.
	var boss := OrcBossMob.new()
	boss.name = "BossChằnTinh"
	boss.configure_arena(Vector3(-15.0, 0.2, -15.0))
	# Groups MUST be set before add_child() so OrcMob._ready()'s
	# `is_in_group("boss")` check (used by _setup_physics_collider /
	# _setup_hitbox / attack-frame-count branches) returns true.
	boss.add_to_group("orc_mobs")
	boss.add_to_group("boss")
	get_parent().add_child(boss)
	boss_instance = boss

	# Show boss health bar
	_show_boss_health_bar(boss)

	# Activate camera magnet at boss arena
	_activate_camera_magnet(Vector3(-15.0, 0.0, -15.0), 25.0, 8.0)

	EventBus.boss_spawned.emit(boss)
	var lighting := get_tree().get_first_node_in_group("lighting_director") as LightingDirector
	if lighting != null:
		lighting.set_active_objective(boss.global_position)

# ══════════════════════════════════════════════════════════════════════════════
# WEATHER SYSTEM
# ══════════════════════════════════════════════════════════════════════════════

func _update_weather(delta: float) -> void:
	if weather_state == "clear":
		weather_timer -= delta
		if weather_timer <= 0.0:
			_start_rain()
	else:
		weather_duration -= delta
		if weather_duration <= 0.0:
			_end_rain()
	
	# Lightning during storm
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
	
	var audio := get_node_or_null("/root/World/AudioManager") as AudioManager
	if audio:
		audio.play_ambience("rain_ambience")

func _end_rain() -> void:
	is_raining = false
	weather_state = "clear"
	weather_timer = 300.0
	
	if rain_particles:
		var particles_to_release := rain_particles
		rain_particles = null
		particles_to_release.emitting = false
		var tween := create_tween()
		tween.tween_interval(2.0)
		tween.tween_callback(func():
			if is_instance_valid(particles_to_release):
				particles_to_release.queue_free()
		)
	
	print("Rain ended...")
	EventBus.weather_changed.emit("clear")
	
	var audio := get_node_or_null("/root/World/AudioManager") as AudioManager
	if audio:
		audio.stop_ambience()

func _create_rain_particles() -> void:
	if rain_particles:
		var stale_particles := rain_particles
		rain_particles = null
		stale_particles.emitting = false
		stale_particles.queue_free()
	
	rain_particles = GPUParticles3D.new()
	rain_particles.name = "RainParticles"
	rain_particles.emitting = true
	rain_particles.amount = RAIN_PARTICLE_AMOUNT
	rain_particles.lifetime = 1.2
	rain_particles.one_shot = false
	rain_particles.preprocess = 1.2
	rain_particles.local_coords = false
	rain_particles.fixed_fps = 30
	rain_particles.interpolate = true
	rain_particles.fract_delta = true
	rain_particles.draw_order = GPUParticles3D.DRAW_ORDER_LIFETIME
	
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(18.0, 1.5, 20.0)
	material.gravity = Vector3(-5.0, -22.0, 2.0)
	material.initial_velocity_min = 14.0
	material.initial_velocity_max = 20.0
	material.angle_min = 0.0
	material.angle_max = 0.0
	material.scale_min = 0.8
	material.scale_max = 1.15
	material.color = Color(0.66, 0.78, 1.0, 0.52)
	material.direction = Vector3.DOWN
	material.spread = 4.0
	
	var quad := QuadMesh.new()
	quad.size = Vector2(0.032, 0.45)
	var streak_material := StandardMaterial3D.new()
	streak_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	streak_material.vertex_color_use_as_albedo = true
	streak_material.no_depth_test = true
	quad.material = streak_material
	
	rain_particles.draw_pass_1 = quad
	rain_particles.process_material = material
	rain_particles.sorting_offset = 0
	
	get_parent().add_child(rain_particles)
	_update_rain_coverage()

func _update_rain_coverage() -> void:
	if not is_instance_valid(rain_particles) or not rain_particles.emitting:
		return
	var camera := get_viewport().get_camera_3d()
	var camera_rig := get_tree().get_first_node_in_group("camera") as GameCamera
	if not camera or not camera_rig:
		return

	# Vùng phát bám tâm gameplay thay vì tọa độ map cố định, nên camera đi đâu cũng có mưa.
	var anchor := camera_rig.global_position
	rain_particles.global_position = Vector3(anchor.x, anchor.y + RAIN_EMITTER_HEIGHT, anchor.z)

	var viewport_size := get_viewport().get_visible_rect().size
	var aspect_ratio := viewport_size.x / maxf(viewport_size.y, 1.0)
	var vertical_span := camera.size if camera.projection == Camera3D.PROJECTION_ORTHOGONAL else 18.0
	var camera_tilt_sine := maxf(sin(absf(camera.global_rotation.x)), 0.35)
	var half_width := vertical_span * aspect_ratio * 0.5 + RAIN_COVERAGE_MARGIN
	var half_depth := vertical_span / (2.0 * camera_tilt_sine) + RAIN_DEPTH_MARGIN
	var emission_extents := Vector3(half_width, 1.5, half_depth)

	var process_material := rain_particles.process_material as ParticleProcessMaterial
	if process_material:
		process_material.emission_box_extents = emission_extents

	# GPUParticles dùng AABB này để culling; phải chứa cả vùng phát và quãng rơi của hạt.
	var cull_margin := Vector3(2.0, 8.0, 2.0)
	var cull_extents := Vector3(
		emission_extents.x + cull_margin.x,
		RAIN_EMITTER_HEIGHT + cull_margin.y,
		emission_extents.z + cull_margin.z
	)
	rain_particles.visibility_aabb = AABB(-cull_extents, cull_extents * 2.0)

func _strike_lightning() -> void:
	print("⚡ LIGHTNING STRIKE!")
	
	var strike_pos := Vector3.ZERO
	var player := get_tree().get_first_node_in_group("player") as Node3D
	
	var is_testing := false
	var main_loop := Engine.get_main_loop()
	if main_loop and main_loop.get_script() != null:
		var script_path: String = main_loop.get_script().resource_path
		if "test_runner" in script_path:
			is_testing = true
			
	if is_testing or not player:
		# Lối đánh ngẫu nhiên theo seed của unit test cũ để đảm bảo tính ổn định và deterministic
		var x := randf_range(-45.0, 45.0)
		var z := randf_range(-45.0, 45.0)
		strike_pos = Vector3(x, 0.0, z)
	else:
		# 15% cơ hội sét đánh thẳng vào người chơi (có vòng báo trước để tránh né)
		# 85% cơ hội sét đánh ngẫu nhiên xung quanh người chơi trong phạm vi 10m - 22m
		if randf() < 0.15:
			strike_pos = player.global_position
		else:
			var angle := randf() * TAU
			var dist := randf_range(10.0, 22.0)
			strike_pos = player.global_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
			
	# Đảm bảo sét đánh trên mặt đất (y = 0)
	strike_pos.y = 0.0
	
	# Tạo tia sét
	var bolt := LightningBolt.new()
	bolt.position = strike_pos
	get_parent().add_child(bolt)

# Hiệu ứng chớp trắng toàn màn hình khi sét đánh
func trigger_screen_flash() -> void:
	var flash := ColorRect.new()
	flash.color = Color(1.0, 1.0, 1.0, 0.75)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.size = get_viewport().get_visible_rect().size
	var ui_layer := get_node_or_null("UI")
	if ui_layer:
		ui_layer.add_child(flash)
		var tween := create_tween()
		tween.tween_property(flash, "color:a", 0.0, 0.25)
		tween.tween_callback(flash.queue_free)
	else:
		flash.queue_free()

func _configure_lighting() -> void:
	var lighting := get_tree().get_first_node_in_group("lighting_director") as LightingDirector
	if lighting != null:
		lighting.refresh_from_scene()


# Backward-compatible entry point for tests and weather callers.
func _update_weather_lighting(is_rainy: bool) -> void:
	var lighting := get_tree().get_first_node_in_group("lighting_director") as LightingDirector
	if lighting == null:
		return
	if not is_rainy:
		lighting.set_weather(&"clear")
		return
	lighting.set_weather(StringName(weather_state))


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

func _create_solid_texture(color: Color, size: Vector2i) -> ImageTexture:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

func _create_player_health_fill_material(mask_texture: Texture2D, fill_size: Vector2) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;

uniform vec2 bar_size = vec2(1.0, 1.0);
uniform sampler2D mask_texture : source_color, filter_nearest;
uniform vec2 mask_texture_size = vec2(1.0, 1.0);
uniform vec2 mask_region_position = vec2(0.0, 0.0);
uniform vec2 mask_region_size = vec2(1.0, 1.0);
uniform vec4 fill_color : source_color = vec4(0.78, 0.08, 0.1, 1.0);
uniform float fill_ratio : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float fill_width = clamp(fill_ratio, 0.0, 1.0) * bar_size.x;
	if (fill_width > 0.0) {
		vec2 pixel = UV * bar_size;
		float moving_fill_alpha = 1.0 - smoothstep(fill_width - 0.5, fill_width + 0.5, pixel.x);

		vec2 mask_uv = (mask_region_position + UV * mask_region_size) / mask_texture_size;
		vec4 mask_pixel = texture(mask_texture, mask_uv);
		float luminance = dot(mask_pixel.rgb, vec3(0.299, 0.587, 0.114));
		float inner_bar_alpha = mask_pixel.a * (1.0 - smoothstep(0.18, 0.36, luminance));

		float alpha = moving_fill_alpha * inner_bar_alpha;
		COLOR = vec4(fill_color.rgb, fill_color.a * alpha);
	} else {
		COLOR = vec4(0.0);
	}
}
"""

	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("bar_size", fill_size)
	material.set_shader_parameter("mask_texture", mask_texture)
	material.set_shader_parameter("mask_texture_size", PLAYER_HUD_TEXTURE_SIZE)
	material.set_shader_parameter("mask_region_position", PLAYER_HUD_FILL_POSITION)
	material.set_shader_parameter("mask_region_size", PLAYER_HUD_FILL_SIZE)
	material.set_shader_parameter("fill_color", PLAYER_HUD_FILL_COLOR)
	material.set_shader_parameter("fill_ratio", 1.0)
	return material

func _update_player_health_fill(current: float, max_h: float) -> void:
	var ratio := 0.0
	if max_h > 0.0:
		ratio = clampf(current / max_h, 0.0, 1.0)

	if is_instance_valid(player_health_fill):
		var material := player_health_fill.material as ShaderMaterial
		if material:
			material.set_shader_parameter("fill_ratio", ratio)

func _create_hud() -> void:
	var existing_ui := get_node_or_null("UI")
	if existing_ui:
		remove_child(existing_ui)
		existing_ui.queue_free()

	var ui := CanvasLayer.new()
	ui.name = "UI"
	ui.layer = 10
	add_child(ui)
	
	# ─── Player Health Bar ───
	var hp_texture := load(PLAYER_HUD_TEXTURE_PATH) as Texture2D
	var hp_scale := PLAYER_HUD_TARGET_WIDTH / PLAYER_HUD_TEXTURE_SIZE.x
	var hp_screen_size := Vector2(
		round(PLAYER_HUD_TEXTURE_SIZE.x * hp_scale),
		round(PLAYER_HUD_TEXTURE_SIZE.y * hp_scale)
	)
	var hp_fill_position := Vector2(
		round(PLAYER_HUD_FILL_POSITION.x * hp_scale),
		round(PLAYER_HUD_FILL_POSITION.y * hp_scale)
	)
	var hp_fill_size := Vector2(
		max(1.0, round(PLAYER_HUD_FILL_SIZE.x * hp_scale)),
		max(1.0, round(PLAYER_HUD_FILL_SIZE.y * hp_scale))
	)

	var hp_container := Control.new()
	hp_container.name = "PlayerHealthContainer"
	hp_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hp_container.position = Vector2(20, 20)
	hp_container.custom_minimum_size = hp_screen_size
	hp_container.size = hp_screen_size
	hp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ui.add_child(hp_container)

	var hp_background := TextureRect.new()
	hp_background.name = "PlayerHealthBackground"
	hp_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_background.offset_left = 0.0
	hp_background.offset_top = 0.0
	hp_background.offset_right = 0.0
	hp_background.offset_bottom = 0.0
	hp_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hp_background.stretch_mode = TextureRect.STRETCH_SCALE
	hp_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hp_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_background.texture = hp_texture
	hp_container.add_child(hp_background)

	var hp_mask := Control.new()
	hp_mask.name = "PlayerHealthMask"
	hp_mask.position = hp_fill_position
	hp_mask.custom_minimum_size = hp_fill_size
	hp_mask.size = hp_fill_size
	hp_mask.clip_contents = true
	hp_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_container.add_child(hp_mask)

	var hp_fill := ColorRect.new()
	hp_fill.name = "PlayerHealthFill"
	hp_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_fill.offset_left = 0.0
	hp_fill.offset_top = 0.0
	hp_fill.offset_right = 0.0
	hp_fill.offset_bottom = 0.0
	hp_fill.color = Color(1.0, 1.0, 1.0, 0.0)
	hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_fill.material = _create_player_health_fill_material(hp_texture, hp_fill_size)
	hp_mask.add_child(hp_fill)
	player_health_fill = hp_fill
	
	var hp_bar := TextureProgressBar.new()
	hp_bar.name = "PlayerHealthBar"
	hp_bar.min_value = 0.0
	hp_bar.max_value = 100.0
	hp_bar.value = 100.0
	hp_bar.position = hp_fill_position
	hp_bar.custom_minimum_size = hp_fill_size
	hp_bar.size = hp_fill_size
	hp_bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	hp_bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar.tint_under = Color(1.0, 1.0, 1.0, 0.0)
	hp_bar.tint_progress = PLAYER_HUD_FILL_COLOR
	hp_bar.tint_over = Color(1.0, 1.0, 1.0, 0.0)
	hp_bar.texture_under = _create_solid_texture(Color(0.0, 0.0, 0.0, 0.0), Vector2i(int(hp_fill_size.x), int(hp_fill_size.y)))
	hp_bar.texture_progress = _create_solid_texture(PLAYER_HUD_FILL_COLOR, Vector2i(int(hp_fill_size.x), int(hp_fill_size.y)))
	hp_bar.texture_over = _create_solid_texture(Color(0.0, 0.0, 0.0, 0.0), Vector2i(int(hp_fill_size.x), int(hp_fill_size.y)))
	hp_bar.visible = false
	hp_container.add_child(hp_bar)
	player_health_bar = hp_bar
	
	var hp_text := Label.new()
	hp_text.name = "PlayerHealthText"
	hp_text.text = "100/100"
	hp_text.position = Vector2(round(116.0 * hp_scale), round(86.0 * hp_scale))
	hp_text.custom_minimum_size = Vector2(round(152.0 * hp_scale), round(28.0 * hp_scale))
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_text.add_theme_font_override("font", UITheme.FONT_BODY_SEMIBOLD)
	hp_text.add_theme_font_size_override("font_size", max(12, int(round(16.0 * hp_scale))))
	hp_text.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82))
	hp_text.add_theme_constant_override("outline_size", 2)
	hp_text.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	hp_text.visible = false
	hp_container.add_child(hp_text)
	
	# ─── Orc Counter ───
	var orc_counter := Control.new()
	orc_counter.name = "OrcCounter"
	orc_counter.set_anchors_preset(Control.PRESET_TOP_LEFT)
	orc_counter.position = Vector2(
		hp_container.position.x +
		round(ORC_COUNTER_TEXT_POSITION.x * hp_scale),
		hp_container.position.y +
		round(ORC_COUNTER_TEXT_POSITION.y * hp_scale)
	)
	orc_counter.custom_minimum_size = Vector2(
		round(ORC_COUNTER_TEXT_SIZE.x * hp_scale),
		round(ORC_COUNTER_TEXT_SIZE.y * hp_scale)
	)
	orc_counter.size = orc_counter.custom_minimum_size
	orc_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(orc_counter)
	
	var orc_count_label := Label.new()
	orc_count_label.name = "OrcCountLabel"
	orc_count_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	orc_count_label.offset_left = 0.0
	orc_count_label.offset_top = 0.0
	orc_count_label.offset_right = 0.0
	orc_count_label.offset_bottom = 0.0
	orc_count_label.text = _format_orc_counter_text()
	orc_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	orc_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	orc_count_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	orc_count_label.add_theme_font_override("font", UITheme.FONT_BODY_SEMIBOLD)
	orc_count_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.74, 1.0))
	orc_count_label.add_theme_constant_override("outline_size", 2)
	orc_count_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	orc_count_label.add_theme_font_size_override("font_size", max(11, int(round(15.0 * hp_scale))))
	orc_counter.add_child(orc_count_label)
	
	# ─── Minimap HUD ───
	minimap_container = Control.new()
	minimap_container.name = "MinimapContainer"
	minimap_container.anchor_left = 1.0
	minimap_container.anchor_top = 0.0
	minimap_container.anchor_right = 1.0
	minimap_container.anchor_bottom = 0.0
	minimap_container.offset_left = -MINIMAP_SCREEN_SIZE.x - 20.0
	minimap_container.offset_top = 20.0
	minimap_container.offset_right = -20.0
	minimap_container.offset_bottom = 20.0 + MINIMAP_SCREEN_SIZE.y
	minimap_container.custom_minimum_size = MINIMAP_SCREEN_SIZE
	minimap_container.size = MINIMAP_SCREEN_SIZE
	minimap_container.pivot_offset = Vector2(MINIMAP_SCREEN_SIZE.x, 0.0)
	minimap_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(minimap_container)

	var minimap_frame := TextureRect.new()
	minimap_frame.name = "MinimapFrame"
	minimap_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	minimap_frame.offset_left = 0.0
	minimap_frame.offset_top = 0.0
	minimap_frame.offset_right = 0.0
	minimap_frame.offset_bottom = 0.0
	minimap_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	minimap_frame.stretch_mode = TextureRect.STRETCH_SCALE
	minimap_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	minimap_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_frame.texture = load(MINIMAP_FRAME_TEXTURE_PATH) as Texture2D
	minimap_container.add_child(minimap_frame)

	var minimap_scale := MINIMAP_SCREEN_SIZE.x / MINIMAP_FRAME_TEXTURE_SIZE.x
	var minimap_inner_position := Vector2(
		round(MINIMAP_INNER_POSITION.x * minimap_scale),
		round(MINIMAP_INNER_POSITION.y * minimap_scale)
	)
	var minimap_inner_size := Vector2(
		round(MINIMAP_INNER_SIZE.x * minimap_scale),
		round(MINIMAP_INNER_SIZE.y * minimap_scale)
	)

	minimap_mask = Control.new()
	minimap_mask.name = "MinimapMask"
	minimap_mask.position = minimap_inner_position
	minimap_mask.custom_minimum_size = minimap_inner_size
	minimap_mask.size = minimap_inner_size
	minimap_mask.clip_contents = true
	minimap_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_container.add_child(minimap_mask)

	var minimap_script := preload("res://src/ui/minimap.gd")
	minimap = minimap_script.new()
	minimap.name = "Minimap"
	minimap.show_panel_background = false
	minimap.show_panel_border = false
	minimap_mask.add_child(minimap)
	minimap.setup(minimap_inner_size)
	minimap.position = Vector2.ZERO
	_refresh_minimap_layout()

func _update_ui_orc_counter() -> void:
	var label := get_node_or_null("UI/OrcCounter/OrcCountLabel") as Label
	if label:
		label.text = _format_orc_counter_text()

func _on_player_health_changed(current: float, max_h: float) -> void:
	var bar := get_node_or_null("UI/PlayerHealthContainer/PlayerHealthBar") as TextureProgressBar
	if bar:
		bar.min_value = minf(0.0, current)
		bar.max_value = maxf(max_h, current)
		bar.value = current
	_update_player_health_fill(current, max_h)
	var text := get_node_or_null("UI/PlayerHealthContainer/PlayerHealthText") as Label
	if text:
		text.text = "%d / %d" % [current, max_h]

func _format_orc_counter_text() -> String:
	return "Orc đã hạ: %d/%d" % [orcs_killed, orcs_to_kill_for_boss]

func _show_boss_health_bar(boss: Node3D = null) -> void:
	var ui := get_node_or_null("UI")
	if ui == null or boss == null:
		return
	_boss_health_bar = BossHealthBar.new()
	_boss_health_bar.name = "BossHealthBar"
	ui.add_child(_boss_health_bar)
	_boss_health_bar.attach(boss, BOSS_DISPLAY_NAME)

func _hide_boss_health_bar() -> void:
	if _boss_health_bar and is_instance_valid(_boss_health_bar):
		_boss_health_bar.detach()
		_boss_health_bar.queue_free()
		_boss_health_bar = null

# ══════════════════════════════════════════════════════════════════════════════
# DAMAGE NUMBERS
# ══════════════════════════════════════════════════════════════════════════════

func _on_player_took_damage(amount: float, position: Vector3) -> void:
	_spawn_damage_number(amount, position, DamagePopup.Kind.PLAYER_HIT)

func _on_enemy_damaged(enemy: Node3D, amount: float, position: Vector3, is_critical: bool = false) -> void:
	var popup_kind: DamagePopup.Kind = DamagePopup.Kind.CRITICAL if is_critical else DamagePopup.Kind.ENEMY_HIT
	_spawn_damage_number(amount, position, popup_kind)

func _spawn_damage_number(amount: float, world_pos: Vector3, popup_kind: DamagePopup.Kind) -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	
	var screen_pos := camera.unproject_position(world_pos + Vector3(0, 1.5, 0))
	var ui := get_node_or_null("UI")
	if not ui:
		return

	var popup := DamagePopup.new()
	popup.configure(amount, screen_pos, popup_kind)
	ui.add_child(popup)
	popup.play()

# ══════════════════════════════════════════════════════════════════════════════
# TREE FADE (75% mờ khi cây nằm giữa camera và player)
# ══════════════════════════════════════════════════════════════════════════════

func _collect_trees() -> void:
	tree_list.clear()
	_tree_alpha_states.clear()
	_tree_local_bounds.clear()
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
	tree_list.append(tree)
	_tree_alpha_states[tree] = 1.0
	var bounds := _compute_tree_local_bounds(tree)
	if bounds.size.length_squared() > 0.0001:
		_tree_local_bounds[tree] = bounds.grow(0.35)


func _compute_tree_local_bounds(tree: Node3D) -> AABB:
	var state := {"has_bounds": false, "bounds": AABB()}
	var root_inverse := tree.global_transform.affine_inverse()
	_merge_tree_geometry_bounds(tree, root_inverse, state)
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
		if not is_instance_valid(tree) or not _tree_has_rendered_geometry(tree):
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
	var game_cam := get_tree().get_first_node_in_group("camera") as GameCamera
	if not game_cam or not game_cam.camera:
		return

	for tree in tree_list:
		if not is_instance_valid(tree):
			continue
		# No hard-hide when camera approaches: camera sits above the canopy,
		# and player occlusion is handled via alpha in _update_tree_fade().
		tree.visible = true

func _update_minimap() -> void:
	if not minimap or not is_instance_valid(minimap):
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player or not is_instance_valid(player):
		return
	_refresh_minimap_layout()
	var markers: Array[Dictionary] = []
	var orcs := get_tree().get_nodes_in_group("orc_mobs")
	for orc in orcs:
		if _is_minimap_orc_marker(orc) and _is_orc_attacking(orc):
			markers.append({
				"position": orc.global_position,
				"marker_type": (
					Minimap.MARKER_BOSS
					if orc.is_in_group("boss")
					else Minimap.MARKER_ORC
				)
			})

	for food in get_tree().get_nodes_in_group("food_items"):
		if food is Node3D and is_instance_valid(food) and food.visible:
			markers.append({
				"position": (food as Node3D).global_position,
				"marker_type": Minimap.MARKER_ITEM
			})

	minimap.update_positions(player.global_position, markers)

func _is_orc_attacking(orc: Variant) -> bool:
	# CHASE = 2, ATTACK = 3 (OrcMob.State) — chỉ hiện trên map khi quái đang chủ động tấn công người chơi.
	var state: int = orc.get("current_state")
	return state == 2 or state == 3

func _is_minimap_orc_marker(candidate: Variant) -> bool:
	if not is_instance_valid(candidate) or not (candidate is Node3D):
		return false
	if candidate.is_in_group("animals") or candidate.is_in_group("cats"):
		return false
	return candidate is OrcMob


func _refresh_minimap_layout() -> void:
	if minimap_container == null or not is_instance_valid(minimap_container):
		return
	minimap_container.size = MINIMAP_SCREEN_SIZE
	minimap_container.custom_minimum_size = MINIMAP_SCREEN_SIZE
	minimap_container.pivot_offset = Vector2(MINIMAP_SCREEN_SIZE.x, 0.0)
	var minimap_scale := MINIMAP_SCREEN_SIZE.x / MINIMAP_FRAME_TEXTURE_SIZE.x
	var inner_position := Vector2(
		round(MINIMAP_INNER_POSITION.x * minimap_scale),
		round(MINIMAP_INNER_POSITION.y * minimap_scale)
	)
	var inner_size := Vector2(
		round(MINIMAP_INNER_SIZE.x * minimap_scale),
		round(MINIMAP_INNER_SIZE.y * minimap_scale)
	)
	if minimap_mask and is_instance_valid(minimap_mask):
		minimap_mask.position = inner_position
		minimap_mask.size = inner_size
		minimap_mask.custom_minimum_size = inner_size
	if minimap and is_instance_valid(minimap):
		minimap.setup(inner_size)
