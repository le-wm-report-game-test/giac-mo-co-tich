# fire_hazard.gd
class_name FireHazard
extends Area3D

@export var life_time: float = 12.0
@export var fire_radius: float = 1.2

var _age: float = 0.0
var _is_extinguished: bool = false
var _particles: GPUParticles3D = null
var _light: OmniLight3D = null
var _base_light_energy: float = 2.5

func _ready() -> void:
	# Cấu hình Area3D để giám sát các HurtboxComponent
	monitoring = true
	monitorable = false
	
	# Nhận diện va chạm với Player (Layer 8 = 128) và Enemy (Layer 9 = 256)
	collision_mask = 128 | 256
	
	_setup_collision_shape()
	_setup_fire_particles()
	_setup_light()

func _process(delta: float) -> void:
	if _is_extinguished:
		return

	# Hiệu ứng ánh lửa nhấp nháy (flicker)
	if _light:
		_light.light_energy = _base_light_energy + randf_range(-0.4, 0.4)

	_age += delta
	if _age >= life_time:
		_extinguish()
		return

	# Quét tất cả các Area3D đang nằm trong vùng lửa
	for area in get_overlapping_areas():
		if area is HurtboxComponent:
			_apply_burning_status(area)

# Áp dụng trạng thái cháy lên thực thể sở hữu Hurtbox
func _apply_burning_status(hurtbox: HurtboxComponent) -> void:
	var target: Node = hurtbox.get_parent()
	if not target:
		return
		
	# Tìm xem thực thể đã có trạng thái cháy chưa
	var existing_status: BurningStatusComponent = null
	for child in target.get_children():
		if child is BurningStatusComponent:
			existing_status = child
			break
			
	if existing_status:
		# Nếu đã cháy rồi thì reset thời gian cháy về tối đa
		existing_status.reset_duration()
	else:
		# Nếu chưa thì tạo mới trạng thái cháy và thêm vào thực thể đó
		var new_status := BurningStatusComponent.new()
		target.add_child(new_status)

# Tạo CollisionShape3D hình trụ bao quanh đống lửa
func _setup_collision_shape() -> void:
	var col_shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = fire_radius
	cylinder.height = 2.0
	col_shape.shape = cylinder
	add_child(col_shape)
	# Đặt tâm hình trụ cao lên một chút để quét chính xác
	col_shape.position.y = 1.0

# Khởi tạo hiệu ứng hạt lửa cháy bùng lên
func _setup_fire_particles() -> void:
	_particles = GPUParticles3D.new()
	_particles.name = "FireParticles"
	_particles.amount = 40
	_particles.lifetime = 0.8
	_particles.local_coords = false
	
	var process_mat := ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_mat.emission_box_extents = Vector3(fire_radius * 0.6, 0.05, fire_radius * 0.6)
	process_mat.gravity = Vector3(0.0, 3.0, 0.0) # Bay lên khá nhanh
	process_mat.direction = Vector3.UP
	process_mat.spread = 10.0
	process_mat.initial_velocity_min = 0.5
	process_mat.initial_velocity_max = 1.5
	
	# Chuyển sắc lửa sinh động hơn
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(1.0, 0.9, 0.3, 1.0), # Vàng sáng tâm lửa
		Color(1.0, 0.5, 0.0, 0.9), # Cam rực bên ngoài
		Color(0.9, 0.1, 0.0, 0.5), # Đỏ rìa ngọn lửa
		Color(0.1, 0.1, 0.1, 0.0)  # Khói xám tan biến
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	process_mat.color_ramp = gradient_tex
	
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.5))
	curve.add_point(Vector2(0.2, 1.2)) # Lửa bùng lên rồi thu nhỏ
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

# Tạo nguồn sáng động xung quanh đống lửa
func _setup_light() -> void:
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.15) # Ánh sáng cam ấm
	_light.light_energy = _base_light_energy
	_light.omni_range = 7.0
	_light.omni_attenuation = 1.2
	_light.shadow_enabled = true
	add_child(_light)
	_light.position.y = 0.5

# Dập tắt lửa từ từ thay vì biến mất đột ngột
func _extinguish() -> void:
	_is_extinguished = true
	if _particles:
		_particles.emitting = false
	
	var tween := create_tween()
	if _light:
		# Giảm dần ánh sáng về 0
		tween.tween_property(_light, "light_energy", 0.0, 1.5)
		
	tween.tween_interval(1.5) # Chờ hạt cũ bay hết
	tween.tween_callback(queue_free)
