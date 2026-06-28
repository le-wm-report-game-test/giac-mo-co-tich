# burning_status_component.gd
class_name BurningStatusComponent
extends Node3D

# Tín hiệu khi bắt đầu và kết thúc cháy để các hệ thống khác (như âm thanh, UI) có thể nhận biết
signal signal_burn_started
signal signal_burn_ended

@export var duration: float = 5.0
@export var damage_per_second: float = 2.0

var _timer: float = 0.0
var _damage_timer: float = 0.0
var _health_component: HealthComponent = null
var _particles: GPUParticles3D = null

func _ready() -> void:
	# Tìm HealthComponent ở node cha
	_health_component = get_parent().get_node_or_null("HealthComponent") as HealthComponent
	if not _health_component:
		# Nếu không thấy trực tiếp, tìm trong các node con của cha
		for child in get_parent().get_children():
			if child is HealthComponent:
				_health_component = child
				break

	if not _health_component:
		push_warning("BurningStatusComponent: No HealthComponent found on parent. Status will not deal damage.")

	_setup_particles()
	signal_burn_started.emit()

func _process(delta: float) -> void:
	_timer += delta
	_damage_timer += delta

	# Gây sát thương mỗi giây
	if _damage_timer >= 1.0:
		_damage_timer -= 1.0
		if _health_component:
			# Gây sát thương lên thực thể chứa component này
			_health_component.take_damage(damage_per_second, owner)

	# Hết thời gian cháy thì tự hủy
	if _timer >= duration:
		signal_burn_ended.emit()
		queue_free()

# Làm mới thời gian cháy khi chạm lại vào nguồn lửa
func reset_duration() -> void:
	_timer = 0.0

# Khởi tạo hiệu ứng hạt lửa cháy bốc lên xung quanh nhân vật
func _setup_particles() -> void:
	_particles = GPUParticles3D.new()
	_particles.name = "BurnParticles"
	_particles.amount = 15
	_particles.lifetime = 0.5
	_particles.local_coords = false
	
	# Định cấu hình Process Material cho hạt
	var process_mat := ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_mat.emission_box_extents = Vector3(0.3, 0.1, 0.3)
	process_mat.gravity = Vector3(0.0, 2.5, 0.0) # Hạt bay thẳng lên
	process_mat.direction = Vector3.UP
	process_mat.spread = 15.0
	process_mat.initial_velocity_min = 0.5
	process_mat.initial_velocity_max = 1.2
	
	# Tạo dải màu chuyển sắc từ vàng -> cam -> đỏ -> trong suốt
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(1.0, 0.9, 0.2, 1.0), # Vàng sáng
		Color(1.0, 0.4, 0.0, 0.8), # Cam rực
		Color(0.8, 0.1, 0.0, 0.4), # Đỏ đậm
		Color(0.2, 0.0, 0.0, 0.0)  # Trong suốt hoàn toàn
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	process_mat.color_ramp = gradient_tex
	
	# Thay đổi kích thước hạt nhỏ dần khi bay lên
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.2))
	var curve_tex := CurveTexture.new()
	curve_tex.curve = curve
	process_mat.scale_curve = curve_tex
	
	_particles.process_material = process_mat
	
	# Định cấu hình Mesh vẽ hạt (Billboard Quad)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.25, 0.25)
	
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	
	quad.material = mat
	_particles.draw_pass_1 = quad
	
	add_child(_particles)
	# Đặt vị trí hạt ngang tầm thân dưới của nhân vật
	_particles.position = Vector3(0.0, 0.5, 0.0)
	_particles.emitting = true
