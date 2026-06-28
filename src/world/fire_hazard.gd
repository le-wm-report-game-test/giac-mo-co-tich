# fire_hazard.gd
# Area3D spawn bởi LightningBolt khi sét đánh trúng đất.
# Ánh sáng cam-ấm tỏa qua sương mù (volumetric fog) trong storm,
# mạnh hơn đủ để người chơi nhìn rõ vùng sáng quanh lửa.
class_name FireHazard
extends Area3D

@export var life_time: float = 12.0
@export var fire_radius: float = 1.2

# ─── Light setup ────────────────────────────────────────────────────────────
# Boosted từ energy 2.5 / range 7 để ánh lửa chiếu rõ trong storm u ám
# và xuyên qua volumetric fog. light_volumetric_fog_energy > 0 làm tia
# sáng nhìn thấy như cột sáng trong sương mù → rất cinematic.
const LIGHT_BASE_ENERGY: float = 5.0
const LIGHT_RADIUS: float = 12.0
const LIGHT_VOLUMETRIC_FOG_ENERGY: float = 1.5
const LIGHT_FLICKER_AMPLITUDE: float = 0.8
const FLICKER_HIGH_FREQ_CHANCE: float = 0.18

# ─── Age color shift (vàng → cam → đỏ → tàn) ──────────────────────────────
# Ánh sáng chuyển tone ấm hơn khi lửa già đi, giống đống than đang tắt.
# Người chơi nhìn được progression của lửa thay vì đứng yên một màu.
const COLOR_FRESH: Color = Color(1.0, 0.78, 0.35)   # vàng sáng, lửa mới
const COLOR_MID: Color = Color(1.0, 0.45, 0.10)    # cam rực, lửa ổn định
const COLOR_OLD: Color = Color(0.85, 0.15, 0.05)   # đỏ sậm, lửa sắp tắt

var _age: float = 0.0
var _is_extinguished: bool = false
var _particles: GPUParticles3D = null
var _light: OmniLight3D = null

func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_mask = 128 | 256

	_setup_collision_shape()
	_setup_fire_particles()
	_setup_light()

func _process(delta: float) -> void:
	if _is_extinguished:
		return

	# Flicker mạnh hơn trước (±0.8 so với ±0.4 cũ), thỉnh thoảng flicker
	# tần số cao để mô phỏng tàn lửa nhảy.
	if _light:
		var base := LIGHT_BASE_ENERGY
		var amplitude := LIGHT_FLICKER_AMPLITUDE
		if randf() < FLICKER_HIGH_FREQ_CHANCE:
			amplitude *= 1.6
		_light.light_energy = base + randf_range(-amplitude, amplitude)
		_apply_age_color_shift()

	_age += delta
	if _age >= life_time:
		_extinguish()
		return

	for area in get_overlapping_areas():
		if area is HurtboxComponent:
			_apply_burning_status(area)

func _apply_burning_status(hurtbox: HurtboxComponent) -> void:
	var target: Node = hurtbox.get_parent()
	if not target:
		return

	var existing_status: BurningStatusComponent = null
	for child in target.get_children():
		if child is BurningStatusComponent:
			existing_status = child
			break

	if existing_status:
		existing_status.reset_duration()
	else:
		var new_status := BurningStatusComponent.new()
		target.add_child(new_status)

func _apply_age_color_shift() -> void:
	# Lerp 2 stop dựa trên tuổi lửa. Tỉ lệ mid đạt đỉnh ở 35% life_time,
	# từ đó fade về old. Phase fresh → mid là lúc lửa bùng lên.
	var t: float = clampf(_age / life_time, 0.0, 1.0)
	var color: Color
	if t < 0.35:
		var local_t: float = t / 0.35
		color = COLOR_FRESH.lerp(COLOR_MID, local_t)
	else:
		var local_t: float = (t - 0.35) / 0.65
		color = COLOR_MID.lerp(COLOR_OLD, local_t)
	_light.light_color = color
	# Light mờ dần khi lửa già — giảm energy theo t
	var dim_factor: float = 1.0 - t * 0.35
	# dim_factor áp vào base energy (giữ nguyên flicker amplitude ở trên)
	_light.light_energy *= dim_factor

func _setup_collision_shape() -> void:
	var col_shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = fire_radius
	cylinder.height = 2.0
	col_shape.shape = cylinder
	add_child(col_shape)
	col_shape.position.y = 1.0

func _setup_fire_particles() -> void:
	_particles = GPUParticles3D.new()
	_particles.name = "FireParticles"
	_particles.amount = 40
	_particles.lifetime = 0.8
	_particles.local_coords = false

	var process_mat := ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_mat.emission_box_extents = Vector3(fire_radius * 0.6, 0.05, fire_radius * 0.6)
	process_mat.gravity = Vector3(0.0, 3.0, 0.0)
	process_mat.direction = Vector3.UP
	process_mat.spread = 10.0
	process_mat.initial_velocity_min = 0.5
	process_mat.initial_velocity_max = 1.5

	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(1.0, 0.9, 0.3, 1.0),
		Color(1.0, 0.5, 0.0, 0.9),
		Color(0.9, 0.1, 0.0, 0.5),
		Color(0.1, 0.1, 0.1, 0.0)
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])

	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	process_mat.color_ramp = gradient_tex

	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.5))
	curve.add_point(Vector2(0.2, 1.2))
	curve.add_point(Vector2(1.0, 0.1))
	var curve_tex := CurveTexture.new()
	curve_tex.curve = curve
	process_mat.scale_curve = curve_tex

	_particles.process_material = process_mat

	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true

	quad.material = mat
	_particles.draw_pass_1 = quad

	add_child(_particles)
	_particles.emitting = true

func _setup_light() -> void:
	_light = OmniLight3D.new()
	_light.light_color = COLOR_FRESH
	_light.light_energy = LIGHT_BASE_ENERGY
	_light.omni_range = LIGHT_RADIUS
	_light.omni_attenuation = 1.2
	_light.shadow_enabled = true
	# Tia sáng nhìn thấy qua volumetric fog — đây là thứ làm cho lửa
	# trong storm thực sự cinematic thay vì chỉ là một quầng sáng trên đất.
	_light.light_volumetric_fog_energy = LIGHT_VOLUMETRIC_FOG_ENERGY
	add_child(_light)
	_light.position.y = 0.5

func _extinguish() -> void:
	_is_extinguished = true
	if _particles:
		_particles.emitting = false

	var tween := create_tween()
	if _light:
		tween.tween_property(_light, "light_energy", 0.0, 1.5)
		tween.parallel().tween_property(_light, "light_volumetric_fog_energy", 0.0, 1.5)
	tween.tween_interval(1.5)
	tween.tween_callback(queue_free)
