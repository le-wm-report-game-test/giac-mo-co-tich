class_name LightingDirector
extends Node3D

enum LightingQuality { PERFORMANCE, CINEMATIC }

const WORLD_RENDER_MASK: int = 1
const COMBAT_ACTOR_RENDER_MASK: int = 2
const PLAYER_ACCENT_RENDER_MASK: int = 4
const ACCENT_LIGHT_COUNT: int = 3
const ACCENT_REFRESH_SECONDS: float = 0.35
const POI_POSITIONS: Array[Vector3] = [
	Vector3(0.0, 0.0, 0.0),
	Vector3(18.0, 0.0, 0.0),
	Vector3(0.0, 0.0, 18.0),
	Vector3(-15.0, 0.0, -15.0),
]

@export var clear_profile: LightingProfile = preload("res://src/lighting/profiles/cinematic_clear.tres")
@export var rain_profile: LightingProfile = preload("res://src/lighting/profiles/cinematic_rain.tres")
@export var storm_profile: LightingProfile = preload("res://src/lighting/profiles/cinematic_storm.tres")
@export var world_environment_path: NodePath = NodePath("../WorldEnvironment")
@export var sun_path: NodePath = NodePath("../DirectionalLight3D")

var _environment: Environment
var _sun: DirectionalLight3D
var _actor_fill_light: DirectionalLight3D
var _player_accent_light: DirectionalLight3D
var _accent_lights: Array[SpotLight3D] = []
var _sky_material: ProceduralSkyMaterial
var _current_profile: LightingProfile
var _current_weather: StringName = &"clear"
var _quality: LightingQuality = LightingQuality.CINEMATIC
var _user_brightness: float = 1.0
var _weather_tween: Tween
var _accent_refresh_timer: float = 0.0
var _has_active_objective: bool = false
var _active_objective_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	add_to_group("lighting_director")
	_resolve_scene_resources()
	if _environment == null or _sun == null:
		push_error("LightingDirector requires WorldEnvironment and DirectionalLight3D siblings.")
		set_process(false)
		return

	_create_readability_lights()
	_create_navigation_lights()
	_connect_events()
	_apply_quality_settings()
	set_weather(&"clear", false)
	_refresh_navigation_lights()

func _process(delta: float) -> void:
	_accent_refresh_timer -= delta
	if _accent_refresh_timer > 0.0:
		return
	_accent_refresh_timer = ACCENT_REFRESH_SECONDS
	_refresh_navigation_lights()

func set_weather(weather: StringName, animated: bool = true) -> void:
	_current_weather = weather if weather in [&"clear", &"rain", &"storm"] else &"clear"
	var profile := _get_profile(_current_weather)
	_apply_profile(profile, animated)

func set_quality_preset(preset: String) -> void:
	var normalized := preset.strip_edges().to_lower()
	_quality = LightingQuality.PERFORMANCE if normalized == "performance" else LightingQuality.CINEMATIC
	_apply_quality_settings()
	if _current_profile != null:
		_apply_profile(_current_profile, false)

func get_quality_preset() -> String:
	return "Performance" if _quality == LightingQuality.PERFORMANCE else "Cinematic"

func set_user_brightness(multiplier: float) -> void:
	_user_brightness = clampf(multiplier, 0.5, 2.0)
	if _environment != null and _current_profile != null:
		_environment.tonemap_exposure = _current_profile.exposure * _user_brightness

func set_active_objective(world_position: Vector3) -> void:
	_has_active_objective = true
	_active_objective_position = world_position
	_refresh_navigation_lights()

func clear_active_objective() -> void:
	_has_active_objective = false
	_refresh_navigation_lights()

func refresh_from_scene() -> void:
	_apply_quality_settings()
	set_weather(_current_weather, false)

func _resolve_scene_resources() -> void:
	var world_environment := get_node_or_null(world_environment_path) as WorldEnvironment
	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	if world_environment == null or world_environment.environment == null:
		return

	_environment = world_environment.environment.duplicate(true) as Environment
	world_environment.environment = _environment
	if _environment.sky == null:
		return

	var local_sky := _environment.sky.duplicate(true) as Sky
	_environment.sky = local_sky
	if local_sky.sky_material is ProceduralSkyMaterial:
		_sky_material = local_sky.sky_material.duplicate(true) as ProceduralSkyMaterial
		local_sky.sky_material = _sky_material

func _connect_events() -> void:
	if not EventBus.weather_changed.is_connected(_on_weather_changed):
		EventBus.weather_changed.connect(_on_weather_changed)
	if not EventBus.boss_spawned.is_connected(_on_boss_spawned):
		EventBus.boss_spawned.connect(_on_boss_spawned)
	if not EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.connect(_on_enemy_died)

func _create_readability_lights() -> void:
	_actor_fill_light = _make_directional_fill("ActorReadabilityLight", COMBAT_ACTOR_RENDER_MASK)
	_player_accent_light = _make_directional_fill("PlayerAccentLight", PLAYER_ACCENT_RENDER_MASK)
	_actor_fill_light.rotation_degrees = Vector3(-32.0, -40.0, 0.0)
	_actor_fill_light.light_specular = 0.08
	_player_accent_light.rotation_degrees = Vector3(-26.0, 150.0, 0.0)
	_player_accent_light.light_specular = 0.12

func _make_directional_fill(node_name: String, render_mask: int) -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.name = node_name
	light.light_cull_mask = render_mask
	light.shadow_enabled = false
	light.light_indirect_energy = 0.0
	light.light_volumetric_fog_energy = 0.0
	add_child(light)
	return light

func _create_navigation_lights() -> void:
	for index in range(ACCENT_LIGHT_COUNT):
		var light := SpotLight3D.new()
		light.name = "NavigationAccent%d" % (index + 1)
		light.shadow_enabled = false
		light.spot_range = 12.0
		light.spot_angle = 38.0
		light.spot_angle_attenuation = 0.85
		light.spot_attenuation = 1.35
		light.light_specular = 0.25
		light.light_volumetric_fog_energy = 0.24
		light.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		add_child(light)
		_accent_lights.append(light)

func _get_profile(weather: StringName) -> LightingProfile:
	match weather:
		&"rain":
			return rain_profile
		&"storm":
			return storm_profile
		_:
			return clear_profile

func _apply_profile(profile: LightingProfile, animated: bool) -> void:
	if profile == null or _environment == null or _sun == null:
		return
	_current_profile = profile
	if is_instance_valid(_weather_tween):
		_weather_tween.kill()

	var fog_scale := 0.78 if _quality == LightingQuality.PERFORMANCE else 1.0
	var accent_scale := 0.8 if _quality == LightingQuality.PERFORMANCE else 1.0
	var exposure := profile.exposure * _user_brightness
	if not animated or profile.transition_seconds <= 0.0:
		_apply_profile_immediately(profile, fog_scale, accent_scale, exposure)
		return

	_weather_tween = create_tween()
	_weather_tween.set_parallel(true)
	var duration := profile.transition_seconds
	_weather_tween.tween_property(_sun, "light_color", profile.sun_color, duration)
	_weather_tween.tween_property(_sun, "light_energy", profile.sun_energy, duration)
	_weather_tween.tween_property(_sun, "rotation_degrees", profile.sun_rotation_degrees, duration)
	_weather_tween.tween_property(_sun, "light_volumetric_fog_energy", profile.sun_volumetric_energy, duration)
	_weather_tween.tween_property(_environment, "ambient_light_color", profile.ambient_color, duration)
	_weather_tween.tween_property(_environment, "ambient_light_energy", profile.ambient_energy, duration)
	_weather_tween.tween_property(_environment, "volumetric_fog_density", profile.fog_density * fog_scale, duration)
	_weather_tween.tween_property(_environment, "volumetric_fog_albedo", profile.fog_albedo, duration)
	_weather_tween.tween_property(_environment, "volumetric_fog_emission", profile.fog_emission, duration)
	_weather_tween.tween_property(_environment, "volumetric_fog_emission_energy", profile.fog_emission_energy, duration)
	_weather_tween.tween_property(_environment, "fog_light_color", profile.fog_albedo, duration)
	_weather_tween.tween_property(_environment, "fog_density", profile.fog_density * fog_scale * 0.28, duration)
	_weather_tween.tween_property(_environment, "tonemap_exposure", exposure, duration)
	_weather_tween.tween_property(_environment, "adjustment_contrast", profile.contrast, duration)
	_weather_tween.tween_property(_environment, "adjustment_saturation", profile.saturation, duration)
	_weather_tween.tween_property(_actor_fill_light, "light_color", profile.actor_fill_color, duration)
	_weather_tween.tween_property(_actor_fill_light, "light_energy", profile.actor_fill_energy, duration)
	_weather_tween.tween_property(_player_accent_light, "light_color", profile.player_accent_color, duration)
	_weather_tween.tween_property(_player_accent_light, "light_energy", profile.player_accent_energy, duration)
	if _sky_material != null:
		_weather_tween.tween_property(_sky_material, "sky_top_color", profile.sky_top_color, duration)
		_weather_tween.tween_property(_sky_material, "sky_horizon_color", profile.sky_horizon_color, duration)
		_weather_tween.tween_property(_sky_material, "ground_bottom_color", profile.ground_bottom_color, duration)
		_weather_tween.tween_property(_sky_material, "ground_horizon_color", profile.ground_horizon_color, duration)
	for index in range(_accent_lights.size()):
		var multiplier := 1.2 if index == 0 and _has_active_objective else 1.0 - float(index) * 0.12
		_weather_tween.tween_property(
			_accent_lights[index],
			"light_energy",
			profile.navigation_accent_energy * accent_scale * multiplier,
			duration
		)
		_weather_tween.tween_property(_accent_lights[index], "light_color", profile.navigation_accent_color, duration)

func _apply_profile_immediately(
	profile: LightingProfile,
	fog_scale: float,
	accent_scale: float,
	exposure: float
) -> void:
	_sun.light_color = profile.sun_color
	_sun.light_energy = profile.sun_energy
	_sun.rotation_degrees = profile.sun_rotation_degrees
	_sun.light_volumetric_fog_energy = profile.sun_volumetric_energy
	_environment.ambient_light_color = profile.ambient_color
	_environment.ambient_light_energy = profile.ambient_energy
	_environment.volumetric_fog_density = profile.fog_density * fog_scale
	_environment.volumetric_fog_albedo = profile.fog_albedo
	_environment.volumetric_fog_emission = profile.fog_emission
	_environment.volumetric_fog_emission_energy = profile.fog_emission_energy
	_environment.fog_light_color = profile.fog_albedo
	_environment.fog_density = profile.fog_density * fog_scale * 0.28
	_environment.tonemap_exposure = exposure
	_environment.adjustment_contrast = profile.contrast
	_environment.adjustment_saturation = profile.saturation
	_actor_fill_light.light_color = profile.actor_fill_color
	_actor_fill_light.light_energy = profile.actor_fill_energy
	_player_accent_light.light_color = profile.player_accent_color
	_player_accent_light.light_energy = profile.player_accent_energy
	if _sky_material != null:
		_sky_material.sky_top_color = profile.sky_top_color
		_sky_material.sky_horizon_color = profile.sky_horizon_color
		_sky_material.ground_bottom_color = profile.ground_bottom_color
		_sky_material.ground_horizon_color = profile.ground_horizon_color
	for index in range(_accent_lights.size()):
		var multiplier := 1.2 if index == 0 and _has_active_objective else 1.0 - float(index) * 0.12
		_accent_lights[index].light_color = profile.navigation_accent_color
		_accent_lights[index].light_energy = profile.navigation_accent_energy * accent_scale * multiplier

func _apply_quality_settings() -> void:
	if _environment == null or _sun == null:
		return
	var cinematic := _quality == LightingQuality.CINEMATIC
	# Two cascades avoid the large SSIL + four-cascade GPU cost on the target
	# GTX 1660 / RX 580 class while preserving a wide cinematic shadow range.
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_sun.directional_shadow_max_distance = 68.0 if cinematic else 46.0
	_sun.shadow_enabled = true
	_sun.shadow_bias = 0.008
	_sun.shadow_normal_bias = 0.12
	_sun.shadow_blur = 1.05 if cinematic else 0.75
	_sun.shadow_opacity = 0.64 if cinematic else 0.54
	_sun.light_angular_distance = 0.62
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.tonemap_white = 6.0
	_environment.adjustment_enabled = true
	_environment.adjustment_brightness = 1.0
	_environment.ssao_enabled = true
	_environment.ssao_radius = 1.45 if cinematic else 1.2
	_environment.ssao_intensity = 1.08 if cinematic else 0.72
	_environment.ssao_power = 1.35
	_environment.ssao_detail = 0.62 if cinematic else 0.32
	_environment.ssao_horizon = 0.4
	# SSIL is expensive — enable only for Cinematic.
	# SSAO + volumetric fog carry the depth stack in Performance mode.
	_environment.ssil_enabled = false
	_environment.ssil_radius = 2.2
	_environment.ssil_intensity = 0.52
	_environment.volumetric_fog_enabled = cinematic
	_environment.volumetric_fog_length = 58.0 if cinematic else 38.0
	_environment.fog_enabled = true
	_environment.fog_light_energy = 0.56 if cinematic else 0.48
	_environment.fog_aerial_perspective = 0.62
	_environment.fog_sky_affect = 0.5
	_environment.glow_enabled = cinematic
	_environment.glow_bloom = 0.045
	_environment.glow_strength = 0.1 if cinematic else 0.07
	_environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	_environment.glow_hdr_threshold = 1.25

func _refresh_navigation_lights() -> void:
	if _accent_lights.is_empty():
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var origin := player.global_position if player != null else Vector3.ZERO
	var candidates: Array[Vector3] = POI_POSITIONS.duplicate()
	candidates.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return a.distance_squared_to(origin) < b.distance_squared_to(origin)
	)

	var light_index := 0
	if _has_active_objective:
		_place_accent_light(_accent_lights[0], _active_objective_position)
		light_index = 1
	for position in candidates:
		if light_index >= _accent_lights.size():
			break
		if _has_active_objective and position.distance_squared_to(_active_objective_position) < 1.0:
			continue
		_place_accent_light(_accent_lights[light_index], position)
		light_index += 1

func _place_accent_light(light: SpotLight3D, ground_position: Vector3) -> void:
	light.global_position = ground_position + Vector3(0.0, 6.0, 0.0)

func _on_weather_changed(weather: String) -> void:
	set_weather(StringName(weather), true)

func _on_boss_spawned(boss: Node3D) -> void:
	if is_instance_valid(boss):
		set_active_objective(boss.global_position)

func _on_enemy_died(enemy: Node3D) -> void:
	if enemy != null and enemy.is_in_group("boss"):
		clear_active_objective()
