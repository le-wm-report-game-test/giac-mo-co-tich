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
	var boss_script := preload("res://src/world/orc_mob.gd")
	boss.set_script(boss_script)
	
	# Position boss at boss arena center
	boss.position = Vector3(-15.0, 0.2, -15.0)
	
	# Boss dùng sprite lớn hơn nhưng physics vẫn scale 1 để không phóng đại hitbox.
	boss.set("sprite_pixel_size", 0.075)
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
	
	get_parent().add_child(rain_particles)

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

func _apply_ambient_darkening(factor: float) -> void:
	var world_env := get_node_or_null("/root/World/WorldEnvironment")
	if world_env and world_env.environment:
		var tween := create_tween()
		tween.tween_method(func(v): 
			world_env.environment.adjustment_brightness = v
		, world_env.environment.adjustment_brightness, factor, 2.0)

# ══════════════════════════════════════════════════════════════════════════════
# GODOT 3D LIGHTING CONFIG — using built-in DirectionalLight3D + WorldEnvironment
# ══════════════════════════════════════════════════════════════════════════════

func _configure_lighting() -> void:
	# The world.tscn already has DirectionalLight3D + WorldEnvironment with:
	# - SSAO (ambient occlusion)
	# - SSIL (indirect lighting)
	# - Glow/Bloom
	# - Volumetric Fog
	# We just tune them for a lush jungle atmosphere
	
	var sun := get_node_or_null("/root/World/DirectionalLight3D") as DirectionalLight3D
	if sun:
		# Warm golden sunlight piercing through canopy
		sun.light_color = Color(1.0, 0.92, 0.72)
		sun.light_energy = 1.68
		sun.light_angular_distance = 0.5
		sun.shadow_enabled = true
		sun.shadow_bias = 0.02
		sun.shadow_normal_bias = 1.2
		sun.shadow_blur = 2.0
		sun.directional_shadow_max_distance = 80.0
	
	# Configure WorldEnvironment for jungle atmosphere
	var world_env := get_node_or_null("/root/World/WorldEnvironment") as WorldEnvironment
	if world_env and world_env.environment:
		if not world_env.environment.is_local_to_scene():
			world_env.environment = world_env.environment.duplicate()
		var env := world_env.environment
		
		# SSAO — soft shadows under trees
		env.ssao_enabled = true
		env.ssao_radius = 1.8
		env.ssao_intensity = 1.2
		env.ssao_power = 1.5
		env.ssao_detail = 0.5
		
		# SSIL — bounced light from jungle floor
		env.ssil_enabled = true
		env.ssil_radius = 3.0
		env.ssil_intensity = 0.8
		
		# Glow — subtle atmospheric bloom (levels 0,1 active; rest off)
		env.glow_enabled = true
		env.glow_bloom = 0.12
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
		env.glow_hdr_threshold = 0.8
		env.glow_hdr_scale = 1.5
		
		# Volumetric fog — misty jungle atmosphere
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.012
		env.volumetric_fog_albedo = Color(0.65, 0.82, 0.75)  # Slightly green tint
		env.volumetric_fog_emission = Color(0.6, 0.7, 0.5)
		env.volumetric_fog_emission_energy = 0.3
		
		# Tonemap
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.tonemap_exposure = 1.2
		env.tonemap_white = 10.0
	
	# Add ambient light for shadow areas (under canopy)
	var ambient := get_node_or_null("/root/World/AmbientLight")
	if not ambient:
		ambient = DirectionalLight3D.new()
		ambient.name = "AmbientLight"
		ambient.light_color = Color(0.5, 0.6, 0.7)  # Cool sky bounce
		ambient.light_energy = 0.216
		ambient.light_indirect_energy = 0.5
		ambient.shadow_enabled = false
		get_node("/root/World").add_child(ambient)
		ambient.owner = get_node("/root/World")

func _update_weather_lighting(is_rainy: bool) -> void:
	"""Adjust lighting when rain starts/stops"""
	var sun := get_node_or_null("/root/World/DirectionalLight3D") as DirectionalLight3D
	if not sun:
		return
	
	var tween := create_tween()
	tween.set_parallel(true)
	
	if is_rainy:
		# Darker, cooler during rain
		tween.tween_property(sun, "light_energy", 0.84, 2.0)
		tween.tween_property(sun, "light_color", Color(0.6, 0.65, 0.75), 2.0)
	else:
		# Back to warm sunlight
		tween.tween_property(sun, "light_energy", 1.68, 3.0)
		tween.tween_property(sun, "light_color", Color(1.0, 0.92, 0.72), 3.0)

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
	
	var ui := get_node_or_null("UI")
	if ui:
		ui.add_child(label)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(label, "position:y", label.position.y - 50, 1.0)
		tween.tween_property(label, "modulate:a", 0.0, 1.0)
		tween.chain()
		tween.tween_callback(label.queue_free)

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
	
	for tree in tree_list:
		if not is_instance_valid(tree):
			continue
		
		var dist := player.global_position.distance_to(tree.global_position)
		var diff_z := player.global_position.z - tree.global_position.z
		var diff_x := player.global_position.x - tree.global_position.x
		
		# Check if player is behind the tree (rough check)
		# Mở rộng vùng check để phát hiện tốt hơn
		var is_behind: bool = absf(diff_x) < 2.5 and absf(diff_z) < 4.0 and diff_z < 0.0
		
		if is_behind and dist < 4.0:
			# Fade tree to 70% transparent (only 30% visible)
			_set_tree_alpha(tree, 0.3)
		else:
			_set_tree_alpha(tree, 1.0)

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
