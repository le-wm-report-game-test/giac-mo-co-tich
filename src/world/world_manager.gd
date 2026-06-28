# world_manager.gd
# Handles: boss spawning, HUD, weather, damage numbers, tree fade, sound, camera magnets
class_name WorldManager
extends Node

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
const PLAYER_HUD_TEXTURE_SIZE := Vector2(853.0, 292.0)
const PLAYER_HUD_TARGET_WIDTH := 290.0
#const PLAYER_HUD_FILL_POSITION := Vector2(214.0, 72.0)
#const PLAYER_HUD_FILL_SIZE := Vector2(532.0, 66.0)
const PLAYER_HUD_FILL_POSITION = Vector2(214.0, 83.0)
const PLAYER_HUD_FILL_SIZE = Vector2(518.0, 40.0)

const PLAYER_HUD_FILL_COLOR := Color(0.78, 0.08, 0.1, 1.0)
#const ORC_COUNTER_TEXT_POSITION := Vector2(260.0, 188.0)
#const ORC_COUNTER_TEXT_SIZE := Vector2(170.0, 44.0)
const ORC_COUNTER_TEXT_POSITION := Vector2(150.0, 195.0)
const ORC_COUNTER_TEXT_SIZE := Vector2(300.0, 44.0)

# ─── HUD References ──────────────────────────────────────────────────────────
var player_health_bar: Node = null
var player_health_fill: ColorRect = null
var boss_health_bar: Node = null
var orc_counter_label: Node = null
var minimap: Minimap = null

# ─── Tree Fade ───────────────────────────────────────────────────────────────
var tree_list: Array[Node3D] = []

# ─── Camera Magnet ───────────────────────────────────────────────────────────
var camera_magnet_active: bool = false
var camera_magnet_target: Vector3 = Vector3.ZERO
var camera_magnet_zoom: float = 0.0
var camera_magnet_duration: float = 0.0
var camera_magnet_timer: float = 0.0

func _ready() -> void:
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
	var settings_menu := SettingsMenu.new()
	settings_menu.name = "SettingsMenu"
	add_child(settings_menu)
	
	# Configure Godot 3D lighting
	_configure_lighting()
	
	# Collect all trees for fade/transparency
	await get_tree().process_frame
	_collect_trees()

func _process(delta: float) -> void:
	_update_weather(delta)
	_update_rain_coverage()
	_update_tree_fade()
	_update_tree_camera_clip()
	_update_camera_magnet(delta)
	_update_minimap()

# ══════════════════════════════════════════════════════════════════════════════
# BOSS SYSTEM
# ══════════════════════════════════════════════════════════════════════════════

func _on_enemy_died(enemy: Node3D) -> void:
	if enemy.is_in_group("boss"):
		_hide_boss_health_bar()
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
	print("BOSS SPAWNED! Chằn Tinh xuất hiện!")
	
	# Create boss using Minotaur asset
	var boss := CharacterBody3D.new()
	boss.name = "BossChằnTinh"
	boss.add_to_group("boss")
	boss.add_to_group("orc_mobs")
	
	# Script will be added via set_script
	var boss_script := preload("res://src/world/chan_tinh_mob.gd")
	boss.set_script(boss_script)
	
	# Position boss at boss arena center
	boss.position = Vector3(-15.0, 0.2, -15.0)
	
	# Boss dùng sprite lớn hơn Orc thường nhưng physics vẫn scale 1 để không phóng đại hitbox.
	boss.set("sprite_pixel_size", OrcMob.BOSS_SPRITE_PIXEL_SIZE)
	boss.set("attack_range", 2.5)
	
	get_parent().add_child(boss)
	boss_instance = boss
	
	# Override boss stats
	if boss.has_method("_setup_nodes"):
		if boss.health_component:
			boss.health_component.max_health = 300.0
			boss.health_component.current_health = 300.0
			boss.health_component.health_changed.connect(func(current: float, max_h: float) -> void:
				var bar := get_node_or_null("UI/BossHealthContainer/BossHealthBar") as TextureProgressBar
				if bar:
					bar.max_value = max_h
					bar.value = current
			)
		boss.speed = 1.5
		boss.attack_damage = 25.0
		boss.attack_range = 1.65
		boss.detection_range = 20.0
	
	# Show boss health bar
	_show_boss_health_bar()
	
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
	
	var x := randf_range(-45.0, 45.0)
	var z := randf_range(-45.0, 45.0)
	var strike_pos := Vector3(x, 0.0, z)
	
	# Flash effect
	var flash := ColorRect.new()
	flash.color = Color(1.0, 1.0, 1.0, 0.8)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.size = get_viewport().get_visible_rect().size
	var ui_layer := get_node_or_null("UI")
	if ui_layer:
		ui_layer.add_child(flash)
		var tween := create_tween()
		tween.tween_property(flash, "color:a", 0.0, 0.3)
		tween.tween_callback(flash.queue_free)
	else:
		flash.queue_free()
	
	# Lightning bolt visual
	var bolt := MeshInstance3D.new()
	var bolt_mesh := immediate_mesh_create_lightning(strike_pos, strike_pos + Vector3(0, 15, 0))
	if bolt_mesh:
		bolt.mesh = bolt_mesh
		get_parent().add_child(bolt)
		var bt := create_tween()
		bt.tween_interval(0.2)
		bt.tween_callback(bolt.queue_free)
	
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and player.global_position.distance_to(strike_pos) < 5.0:
		if player.has_method("_on_damaged"):
			player._on_damaged(20.0, null)
	
	var audio := get_node_or_null("/root/World/AudioManager") as AudioManager
	if audio:
		audio.play_sfx("thunder", strike_pos, 0.2)

func immediate_mesh_create_lightning(from: Vector3, to: Vector3) -> Mesh:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.1
	cylinder.bottom_radius = 0.1
	cylinder.height = from.distance_to(to)
	return cylinder

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
		# Store original zoom
		game_cam.set_meta("original_zoom", game_cam.camera.size)
		# Zoom out to show arena
		var tween := create_tween()
		if tween:
			tween.tween_method(func(v): game_cam.camera.size = v, game_cam.camera.size, zoom_size, 1.0)

func _update_camera_magnet(delta: float) -> void:
	if not camera_magnet_active:
		return
	
	camera_magnet_timer -= delta
	
	if camera_magnet_timer <= 0.0:
		# Restore normal camera
		camera_magnet_active = false
		var game_cam := get_tree().get_first_node_in_group("camera") as GameCamera
		if game_cam and game_cam.camera:
			var original_zoom: float = game_cam.get_meta("original_zoom", 20.0)
			var tween := create_tween()
			if tween:
				tween.tween_method(func(v): game_cam.camera.size = v, game_cam.camera.size, original_zoom, 1.0)
		return
		
	var game_cam := get_tree().get_first_node_in_group("camera") as GameCamera
	if not game_cam:
		return
	
	# Override camera target to magnet position
	game_cam.global_position = game_cam.global_position.lerp(
		camera_magnet_target,
		clampf(3.0 * delta, 0.0, 1.0)
	)

func _create_solid_texture(color: Color, size: Vector2i) -> ImageTexture:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

func _create_player_health_fill_material(fill_size: Vector2) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;

uniform vec2 bar_size = vec2(1.0, 1.0);
uniform vec4 fill_color : source_color = vec4(0.78, 0.08, 0.1, 1.0);
uniform float fill_ratio : hint_range(0.0, 1.0) = 1.0;

float rounded_box_sdf(vec2 point, vec2 center, vec2 half_extents, float radius) {
	vec2 q = abs(point - center) - (half_extents - vec2(radius));
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	float fill_width = clamp(fill_ratio, 0.0, 1.0) * bar_size.x;
	if (fill_width > 0.0) {
		vec2 pixel = UV * bar_size;
		vec2 half_extents = vec2(fill_width * 0.5, bar_size.y * 0.5);
		vec2 center = vec2(half_extents.x, half_extents.y);
		float radius = min(bar_size.y * 0.5, half_extents.x);
		float dist = rounded_box_sdf(pixel, center, half_extents, radius);
		float alpha = 1.0 - smoothstep(0.0, 1.0, dist);
		COLOR = vec4(fill_color.rgb, fill_color.a * alpha);
	} else {
		COLOR = vec4(0.0);
	}
}
"""

	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("bar_size", fill_size)
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
	hp_fill.material = _create_player_health_fill_material(hp_fill_size)
	hp_mask.add_child(hp_fill)
	player_health_fill = hp_fill
	
	var hp_bar := TextureProgressBar.new()
	hp_bar.name = "PlayerHealthBar"
	hp_bar.min_value = 0.0
	hp_bar.max_value = 100.0
	hp_bar.value = 100.0
	hp_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_bar.offset_left = 0.0
	hp_bar.offset_top = 0.0
	hp_bar.offset_right = 0.0
	hp_bar.offset_bottom = 0.0
	hp_bar.custom_minimum_size = hp_fill_size
	hp_bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	hp_bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar.tint_under = Color(1.0, 1.0, 1.0, 0.0)
	hp_bar.tint_progress = Color.WHITE
	hp_bar.tint_over = Color(1.0, 1.0, 1.0, 0.0)
	hp_bar.texture_under = _create_solid_texture(Color(0.0, 0.0, 0.0, 0.0), Vector2i(int(hp_fill_size.x), int(hp_fill_size.y)))
	hp_bar.texture_progress = _create_solid_texture(PLAYER_HUD_FILL_COLOR, Vector2i(int(hp_fill_size.x), int(hp_fill_size.y)))
	hp_bar.texture_over = _create_solid_texture(Color(0.0, 0.0, 0.0, 0.0), Vector2i(int(hp_fill_size.x), int(hp_fill_size.y)))
	hp_bar.visible = false
	hp_mask.add_child(hp_bar)
	player_health_bar = hp_bar
	
	var hp_text := Label.new()
	hp_text.name = "PlayerHealthText"
	hp_text.text = "100/100"
	hp_text.visible = false
	hp_container.add_child(hp_text)
	
	# ─── Orc Counter ───
	var orc_counter := Control.new()
	orc_counter.name = "OrcCounter"
	orc_counter.set_anchors_preset(Control.PRESET_TOP_LEFT)
	orc_counter.position = Vector2(
		round(ORC_COUNTER_TEXT_POSITION.x * hp_scale),
		round(ORC_COUNTER_TEXT_POSITION.y * hp_scale)
	)
	orc_counter.custom_minimum_size = Vector2(
		round(ORC_COUNTER_TEXT_SIZE.x * hp_scale),
		round(ORC_COUNTER_TEXT_SIZE.y * hp_scale)
	)
	orc_counter.size = orc_counter.custom_minimum_size
	orc_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_container.add_child(orc_counter)
	
	var orc_count_label := Label.new()
	orc_count_label.name = "OrcCountLabel"
	orc_count_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	orc_count_label.offset_left = 0.0
	orc_count_label.offset_top = 0.0
	orc_count_label.offset_right = 0.0
	orc_count_label.offset_bottom = 0.0
	orc_count_label.text = "Orc Killed: 0/%d" % orcs_to_kill_for_boss
	orc_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	orc_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	orc_count_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.74, 1.0))
	orc_count_label.add_theme_constant_override("outline_size", 2)
	orc_count_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	orc_count_label.add_theme_font_size_override("font_size", max(12, int(round(18.0 * hp_scale))))
	orc_counter.add_child(orc_count_label)
	
	# ─── Boss Health Bar (hidden initially) ───
	var boss_container := VBoxContainer.new()
	boss_container.name = "BossHealthContainer"
	boss_container.position = Vector2(get_viewport().get_visible_rect().size.x / 2 - 150, 20)
	boss_container.visible = false
	ui.add_child(boss_container)
	
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
	boss_hp_bar.custom_minimum_size = Vector2(300, 25)
	boss_hp_bar.texture_under = _create_solid_texture(Color(0.3, 0.0, 0.0), Vector2i(300, 25))
	boss_hp_bar.texture_progress = _create_solid_texture(Color(0.8, 0.1, 0.0), Vector2i(300, 25))
	
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
	
	# ─── Minimap HUD ───
	var minimap_script := preload("res://src/ui/minimap.gd")
	minimap = minimap_script.new()
	minimap.name = "Minimap"
	ui.add_child(minimap)
	minimap.setup(Vector2(120, 120))
	minimap.position = Vector2(1920 - 120 - 20, 20)

func _update_ui_orc_counter() -> void:
	var label := get_node_or_null("UI/OrcCounter/OrcCountLabel") as Label
	if label:
		label.text = "Orc Killed: %d/%d" % [orcs_killed, orcs_to_kill_for_boss]

func _on_player_health_changed(current: float, max_h: float) -> void:
	var bar := get_node_or_null("UI/PlayerHealthContainer/PlayerHealthBar") as TextureProgressBar
	if bar:
		bar.min_value = minf(0.0, current)
		bar.max_value = maxf(max_h, current)
		bar.value = current
	_update_player_health_fill(current, max_h)
	var text := get_node_or_null("UI/PlayerHealthContainer/PlayerHealthText") as Label
	if text:
		text.text = "%d/%d" % [current, max_h]

func _show_boss_health_bar() -> void:
	var container := get_node_or_null("UI/BossHealthContainer")
	if container:
		container.visible = true

func _hide_boss_health_bar() -> void:
	var container := get_node_or_null("UI/BossHealthContainer")
	if container:
		container.visible = false

# ══════════════════════════════════════════════════════════════════════════════
# DAMAGE NUMBERS
# ══════════════════════════════════════════════════════════════════════════════

func _on_player_took_damage(amount: float, position: Vector3) -> void:
	_spawn_damage_number(amount, position, DamagePopup.Kind.PLAYER_HIT)

func _on_enemy_damaged(enemy: Node3D, amount: float, position: Vector3) -> void:
	var is_critical := randf() < 0.15
	if is_critical:
		amount *= 2.0
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
# TREE FADE (70% mờ khi người nấp sau cây)
# ══════════════════════════════════════════════════════════════════════════════

func _collect_trees() -> void:
	tree_list.clear()
	var world := get_parent()
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
	var game_camera := get_tree().get_first_node_in_group("camera") as GameCamera
	var toward_camera := Vector3.ZERO
	if game_camera != null and game_camera.camera != null:
		toward_camera = game_camera.camera.global_position - player.global_position
		toward_camera.y = 0.0
		toward_camera = toward_camera.normalized()
	
	for tree in tree_list:
		if not is_instance_valid(tree):
			continue
		
		var dist := player.global_position.distance_to(tree.global_position)
		var diff_z := player.global_position.z - tree.global_position.z
		var diff_x := player.global_position.x - tree.global_position.x
		
		# Giữ tương thích với rule cũ và bổ sung kiểm tra đúng theo hướng camera orthographic.
		var is_behind_legacy: bool = absf(diff_x) < 2.5 and absf(diff_z) < 4.0 and diff_z < 0.0
		var is_camera_occluder := false
		if toward_camera != Vector3.ZERO and _tree_has_rendered_geometry(tree):
			var player_to_tree := tree.global_position - player.global_position
			player_to_tree.y = 0.0
			var depth_toward_camera := player_to_tree.dot(toward_camera)
			var lateral_offset := (player_to_tree - toward_camera * depth_toward_camera).length()
			is_camera_occluder = (
				depth_toward_camera > 0.0
				and depth_toward_camera < 14.0
				and lateral_offset < 4.25
			)
		
		if is_behind_legacy and dist < 4.0:
			# Giữ hành vi fade gần đã được gameplay và test suite phụ thuộc.
			_set_tree_alpha(tree, 0.3)
		elif is_camera_occluder:
			# Cây cao có thể che player từ xa. Ẩn hoàn toàn canopy đang chắn camera
			# để không tạo screen-door noise quanh silhouette của player.
			_set_tree_alpha(tree, 0.0)
		else:
			_set_tree_alpha(tree, 1.0)

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
	
	game_cam.force_update_transform()
	game_cam.camera.force_update_transform()
	
	for tree in tree_list:
		if not is_instance_valid(tree):
			continue
		# Không hard-hide cây khi camera tới gần: camera đã được nâng cao hơn canopy,
		# còn occlusion của player xử lý bằng alpha trong _update_tree_fade().
		tree.visible = true

func _update_minimap() -> void:
	if not minimap or not is_instance_valid(minimap):
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player or not is_instance_valid(player):
		return
	var enemies: Array[Dictionary] = []
	var orcs := get_tree().get_nodes_in_group("orc_mobs")
	for orc in orcs:
		if is_instance_valid(orc) and orc is Node3D and orc.get("current_state") != 5:
			enemies.append({
				"position": orc.global_position,
				"is_boss": orc.is_in_group("boss")
			})
	var animals := get_tree().get_nodes_in_group("animals")
	for animal in animals:
		if is_instance_valid(animal) and animal is Node3D:
			enemies.append({
				"position": animal.global_position,
				"is_boss": false
			})
	minimap.update_positions(player.global_position, enemies)
