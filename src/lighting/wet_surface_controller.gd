# wet_surface_controller.gd
# Tunes ground surface wetness (roughness, metallic, albedo darken) when the
# weather changes. Discovers any ShaderMaterial bound to `ground_surface.gdshader`
# on MultiMeshInstance3D nodes under the forest and tweens `wet_amount` to the
# target value declared by the active LightingProfile.
class_name WetSurfaceController
extends Node

const GROUND_SURFACE_SHADER_PATH: String = "res://src/world/ground_surface.gdshader"
const PROFILES_GROUP: StringName = &"lighting_director"
const WET_TRANSITION_SECONDS: float = 4.5
const WET_DRY_DELAY_SECONDS: float = 6.0

var _ground_materials: Array[ShaderMaterial] = []
var _active_tween: Tween = null
var _drying_delay_tween: Tween = null
var _lighting_director: Node = null

func _ready() -> void:
	add_to_group("wet_surface_controller")
	_collect_ground_materials()
	_resolve_lighting_director()
	if not EventBus.weather_changed.is_connected(_on_weather_changed):
		EventBus.weather_changed.connect(_on_weather_changed)
	# Apply the current profile so the initial scene state matches
	# whatever weather was active at spawn time.
	_apply_profile_for_weather(_get_current_weather(), false)

func _collect_ground_materials() -> void:
	_ground_materials.clear()
	var forest := get_tree().get_first_node_in_group("forest")
	if forest == null:
		# Fallback: search the whole tree for MultiMeshInstance3D that
		# uses the ground shader. This is more expensive but works
		# when the forest node is not in the group yet (deferred _ready).
		_collect_materials_recursive(get_tree().root)
		return
	_collect_materials_recursive(forest)

func _collect_materials_recursive(node: Node) -> void:
	if node is MultiMeshInstance3D or node is MeshInstance3D:
		var geom := node as GeometryInstance3D
		if geom.material_override is ShaderMaterial:
			var sm := geom.material_override as ShaderMaterial
			if _uses_ground_shader(sm):
				_ground_materials.append(sm)
	for child in node.get_children():
		_collect_materials_recursive(child)

func _uses_ground_shader(material: ShaderMaterial) -> bool:
	if material.shader == null:
		return false
	return material.shader.resource_path == GROUND_SURFACE_SHADER_PATH

func _resolve_lighting_director() -> void:
	var director := get_tree().get_first_node_in_group(PROFILES_GROUP)
	if director != null:
		_lighting_director = director

func _on_weather_changed(weather: String) -> void:
	_apply_profile_for_weather(weather, true)

func _get_current_weather() -> String:
	if _lighting_director == null:
		return "clear"
	var current: Variant = _lighting_director.get("_current_weather")
	if current is StringName:
		return String(current)
	if current is String:
		return current
	return "clear"

func _apply_profile_for_weather(weather: String, animated: bool) -> void:
	var target_wet: float = _lookup_wet_amount(weather)
	if target_wet <= 0.0 and weather == "clear":
		# Gradual drying: delay the transition so the ground stays
		# wet for a few seconds after the rain ends, which is what
		# real ground does and what the user asked for.
		_schedule_gradual_dry()
		return
	_tween_wet_amount(target_wet, animated)

func _lookup_wet_amount(weather: String) -> float:
	if _lighting_director == null:
		return 0.0
	var profile: Resource = null
	match weather:
		&"rain", "rain":
			profile = _lighting_director.get("rain_profile")
		&"storm", "storm":
			profile = _lighting_director.get("storm_profile")
		_:
			profile = _lighting_director.get("clear_profile")
	if profile == null or not ("wet_amount" in profile):
		return 0.0
	return float(profile.get("wet_amount"))

func _schedule_gradual_dry() -> void:
	if _drying_delay_tween != null and _drying_delay_tween.is_valid():
		_drying_delay_tween.kill()
	_drying_delay_tween = create_tween()
	_drying_delay_tween.tween_interval(WET_DRY_DELAY_SECONDS)
	_drying_delay_tween.tween_callback(func() -> void:
		_tween_wet_amount(0.0, true)
	)

func _tween_wet_amount(target: float, animated: bool) -> void:
	if _drying_delay_tween != null and _drying_delay_tween.is_valid():
		_drying_delay_tween.kill()
		_drying_delay_tween = null
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	if _ground_materials.is_empty():
		return
	var duration: float = WET_TRANSITION_SECONDS if animated else 0.0
	if duration <= 0.0:
		for mat in _ground_materials:
			mat.set_shader_parameter("wet_amount", target)
		return
	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	for mat in _ground_materials:
		_active_tween.tween_method(
			func(value: float) -> void: mat.set_shader_parameter("wet_amount", value),
			_get_current_wet_value(),
			target,
			duration
		)

func _get_current_wet_value() -> float:
	if _ground_materials.is_empty():
		return 0.0
	var first := _ground_materials[0]
	var value: Variant = first.get_shader_parameter("wet_amount")
	if value == null:
		return 0.0
	return float(value)
