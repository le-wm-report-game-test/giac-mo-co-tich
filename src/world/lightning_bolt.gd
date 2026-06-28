# lightning_bolt.gd
class_name LightningBolt
extends Node3D

@export var strike_height: float = 30.0
@export var damage_radius: float = 3.0
@export var damage_amount: float = 25.0
@export var fire_hazard_scene: PackedScene = null

var _light: OmniLight3D = null
var _particles: GPUParticles3D = null
var _mesh_instance: MeshInstance3D = null
var _warning_ring: MeshInstance3D = null

var _time_alive: float = 0.0
var _flicker_timer: float = 0.0
var _has_struck: bool = false

func _ready() -> void:
	# 1. Khởi tạo sẵn tia sét nhưng ẩn đi
	_setup_lightning_mesh()
	_mesh_instance.visible = false
	
	# 2. Khởi tạo nguồn sáng chớp và hạt lửa nhưng chưa kích hoạt
	_setup_light()
	_light.visible = false
	
	_setup_sparks()
	_particles.emitting = false
	
	# 3. Vẽ vòng tròn cảnh báo màu đỏ dưới đất
	_setup_warning_ring()
	
	# 4. Tạo hiệu ứng cảnh báo co giãn (pulse) trong 1.0 giây trước khi sét đánh
	var tween := create_tween()
	tween.tween_property(_warning_ring, "scale", Vector3(1.1, 1.1, 1.1), 0.5)
	tween.tween_property(_warning_ring, "scale", Vector3(1.0, 1.0, 1.0), 0.5)
	tween.tween_callback(_strike)

func _process(delta: float) -> void:
	_time_alive += delta
	
	if _has_struck:
		# Làm mờ dần ánh sáng sét đánh
		if _light and _light.light_energy > 0.0:
			_light.light_energy = move_toward(_light.light_energy, 0.0, delta * 50.0)
			
		# Tạo hiệu ứng chớp tắt (flicker) cho tia sét
		_flicker_timer += delta
		if _flicker_timer > 0.04 and _mesh_instance:
			_mesh_instance.visible = not _mesh_instance.visible
			_flicker_timer = 0.0
			
		# Tự giải phóng sau khi sét đánh được 1.0 giây
		if _time_alive >= 2.25:
			queue_free()

# Thực hiện cú sét đánh
func _strike() -> void:
	_has_struck = true
	_time_alive = 1.0 # Bắt đầu đếm thời gian sau sét đánh
	
	# Xóa vòng cảnh báo
	if _warning_ring:
		_warning_ring.queue_free()
		
	# Hiển thị tia sét và kích hoạt ánh sáng, hạt
	if _mesh_instance:
		_mesh_instance.visible = true
	if _light:
		_light.visible = true
	if _particles:
		_particles.emitting = true
		
	# Gây chớp màn hình (tìm qua WorldManager nếu có)
	_trigger_screen_flash()
		
	# Gây sát thương và tạo lửa
	_deal_strike_damage()
	_spawn_fire_hazard()
	_play_thunder_sound()

# Vẽ vòng tròn cảnh báo màu đỏ nét mảnh dưới đất
func _setup_warning_ring() -> void:
	_warning_ring = MeshInstance3D.new()
	var imm_ring := ImmediateMesh.new()
	_warning_ring.mesh = imm_ring
	
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(1.0, 0.1, 0.1) # Đỏ cảnh báo
	_warning_ring.material_override = ring_mat
	
	add_child(_warning_ring)
	
	imm_ring.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in range(33):
		var angle := float(i) * TAU / 32.0
		# Vẽ cao hơn mặt đất một chút (0.05) để tránh lỗi đè texture (z-fighting)
		imm_ring.surface_add_vertex(Vector3(cos(angle) * damage_radius, 0.05, sin(angle) * damage_radius))
	imm_ring.surface_end()

# Vẽ tia sét hình zig-zag ngẫu nhiên
func _setup_lightning_mesh() -> void:
	_mesh_instance = MeshInstance3D.new()
	var imm_mesh := ImmediateMesh.new()
	_mesh_instance.mesh = imm_mesh
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(2.2, 2.8, 6.0) # HDR Bloom màu xanh trắng
	_mesh_instance.material_override = mat
	
	add_child(_mesh_instance)
	
	var start_pos := Vector3(0.0, strike_height, 0.0)
	var end_pos := Vector3.ZERO
	var segments := 12
	var points: Array[Vector3] = []
	
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var base_pos := start_pos.lerp(end_pos, t)
		var offset := Vector3.ZERO
		
		if i > 0 and i < segments:
			var max_deviation := 2.5 * sin(t * PI)
			offset = Vector3(
				randf_range(-max_deviation, max_deviation),
				0.0,
				randf_range(-max_deviation, max_deviation)
			)
		points.append(base_pos + offset)
		
	imm_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	
	# Vẽ 3 đường sét chính lồng vào nhau để tăng độ dày
	var offsets := [Vector3.ZERO, Vector3(0.06, 0.0, 0.06), Vector3(-0.06, 0.0, -0.06)]
	for offset_vec in offsets:
		for k in range(points.size() - 1):
			imm_mesh.surface_add_vertex(points[k] + offset_vec)
			imm_mesh.surface_add_vertex(points[k+1] + offset_vec)
			
	# Vẽ thêm 2 nhánh sét phụ
	_draw_branch(imm_mesh, points[4], Vector3(-4.0, 4.0, -3.0))
	_draw_branch(imm_mesh, points[7], Vector3(4.0, 2.0, 3.0))
	
	imm_mesh.surface_end()

func _draw_branch(imm_mesh: ImmediateMesh, start_pt: Vector3, direction: Vector3) -> void:
	var current_pt := start_pt
	var segments := 4
	for i in range(segments):
		var next_pt := current_pt + (direction / segments) + Vector3(randf_range(-0.8, 0.8), -1.5, randf_range(-0.8, 0.8))
		imm_mesh.surface_add_vertex(current_pt)
		imm_mesh.surface_add_vertex(next_pt)
		current_pt = next_pt

func _setup_light() -> void:
	_light = OmniLight3D.new()
	_light.light_color = Color(0.75, 0.9, 1.0)
	_light.light_energy = 20.0
	_light.omni_range = 22.0
	_light.omni_attenuation = 1.0
	_light.shadow_enabled = false
	add_child(_light)
	_light.position.y = 1.5

func _setup_sparks() -> void:
	_particles = GPUParticles3D.new()
	_particles.name = "StrikeSparks"
	_particles.amount = 30
	_particles.lifetime = 0.5
	_particles.one_shot = true
	_particles.explosiveness = 0.95
	
	var process_mat := ParticleProcessMaterial.new()
	process_mat.direction = Vector3.UP
	process_mat.spread = 80.0
	process_mat.initial_velocity_min = 7.0
	process_mat.initial_velocity_max = 14.0
	process_mat.gravity = Vector3(0.0, -14.0, 0.0)
	
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(2.5, 3.0, 6.0, 1.0),
		Color(0.2, 0.6, 1.0, 0.6),
		Color(0.0, 0.0, 0.2, 0.0)
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	process_mat.color_ramp = gradient_tex
	
	_particles.process_material = process_mat
	
	var quad := QuadMesh.new()
	quad.size = Vector2(0.15, 0.15)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	
	_particles.draw_pass_1 = quad
	add_child(_particles)

func _deal_strike_damage() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and player.global_position.distance_to(global_position) < damage_radius:
		var hurtbox := player.get_node_or_null("HurtboxComponent") as HurtboxComponent
		if hurtbox:
			hurtbox.receive_hit(damage_amount, self)
		elif player.has_method("take_damage"):
			player.take_damage(damage_amount)
			
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Node3D and enemy.global_position.distance_to(global_position) < damage_radius:
			var hurtbox := enemy.get_node_or_null("HurtboxComponent") as HurtboxComponent
			if hurtbox:
				hurtbox.receive_hit(damage_amount, self)

func _spawn_fire_hazard() -> void:
	var fire_hazard: FireHazard = null
	if fire_hazard_scene:
		fire_hazard = fire_hazard_scene.instantiate() as FireHazard
	else:
		fire_hazard = FireHazard.new()
		
	get_parent().add_child(fire_hazard)
	fire_hazard.global_position = global_position

func _play_thunder_sound() -> void:
	var audio := get_node_or_null("/root/World/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx("thunder", global_position, 0.2)

func _trigger_screen_flash() -> void:
	var world_mgr := get_tree().get_first_node_in_group("world_manager") as Node
	if not world_mgr:
		world_mgr = get_parent().get_node_or_null("WorldManager")
		
	if world_mgr and world_mgr.has_method("trigger_screen_flash"):
		world_mgr.trigger_screen_flash()
