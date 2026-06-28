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

# ─── HUD References ──────────────────────────────────────────────────────────
var player_health_bar: Node = null
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
	var settings_menu := SettingsMenu.new()
	settings_menu.name = "SettingsMenu"
	add_child(settings_menu)

# Phím tắt Debug để kiểm tra nhanh thời tiết và sấm sét
func _unhandled_input(event: InputEvent) -> void:
	# Chỉ hoạt động khi chạy chạy thử trong Godot Editor (Debug build)
	if OS.is_debug_build() and event is InputEventKey and event.pressed:
		if event.keycode == KEY_K:
			print("DEBUG: Kích hoạt mưa bão (Storm) ngay lập tức!")
			_start_storm_instantly()
		elif event.keycode == KEY_L:
			print("DEBUG: Gọi sét đánh ngay lập tức!")
			_strike_lightning()

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
	
	var strike_pos := Vector3.ZERO
	var player := get_tree().get_first_node_in_group("player") as Node3D
	
	if player:
		# 15% cơ hội sét đánh thẳng vào người chơi (có vòng báo trước để tránh né)
		# 85% cơ hội sét đánh ngẫu nhiên xung quanh người chơi trong phạm vi 10m - 22m
		if randf() < 0.15:
			strike_pos = player.global_position
		else:
			var angle := randf() * TAU
			var dist := randf_range(10.0, 22.0)
			strike_pos = player.global_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	else:
		# Nếu không tìm thấy player, sét đánh ngẫu nhiên trên map
		var x := randf_range(-45.0, 45.0)
		var z := randf_range(-45.0, 45.0)
		strike_pos = Vector3(x, 0.0, z)
		
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

func _create_hud() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	ui.layer = 10
	add_child(ui)
	
	# ─── Player Health Bar ───
	var hp_container := HBoxContainer.new()
	hp_container.name = "PlayerHealthContainer"
	hp_container.position = Vector2(20, 20)
	hp_container.add_theme_constant_override("separation", 5)
	ui.add_child(hp_container)
	
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
	hp_bar.custom_minimum_size = Vector2(200, 20)
	hp_bar.fill_mode = 0
	hp_bar.texture_under = _create_solid_texture(Color(0.3, 0.0, 0.0), Vector2i(200, 20))
	hp_bar.texture_progress = _create_solid_texture(Color(0.0, 0.8, 0.0), Vector2i(200, 20))
	
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
	
	var hp_text := Label.new()
	hp_text.name = "PlayerHealthText"
	hp_text.text = "100/100"
	hp_text.add_theme_color_override("font_color", Color.WHITE)
	hp_text.add_theme_font_size_override("font_size", 14)
	hp_container.add_child(hp_text)
	
	# ─── Orc Counter ───
	var orc_counter := HBoxContainer.new()
	orc_counter.name = "OrcCounter"
	orc_counter.position = Vector2(20, 50)
	ui.add_child(orc_counter)
	
	var orc_label := Label.new()
	orc_label.text = "Quái đã diệt: "
	orc_label.add_theme_color_override("font_color", Color.WHITE)
	orc_label.add_theme_font_size_override("font_size", 14)
	orc_counter.add_child(orc_label)
	
	var orc_count_label := Label.new()
	orc_count_label.name = "OrcCountLabel"
	orc_count_label.text = "0/%d" % orcs_to_kill_for_boss
	orc_count_label.add_theme_color_override("font_color", Color.YELLOW)
	orc_count_label.add_theme_font_size_override("font_size", 14)
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
		label.text = "%d/%d" % [orcs_killed, orcs_to_kill_for_boss]

func _on_player_health_changed(current: float, max_h: float) -> void:
	var bar := get_node_or_null("UI/PlayerHealthContainer/PlayerHealthBar") as TextureProgressBar
	if bar:
		bar.min_value = minf(0.0, current)
		bar.max_value = maxf(max_h, current)
		bar.value = current
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
