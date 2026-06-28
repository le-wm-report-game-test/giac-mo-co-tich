# lightning_visual_builder.gd
# Tách các hàm dựng mesh/material cho LightningBolt ra file riêng để giữ
# file chính dưới 200 dòng theo performance/architecture rules.
class_name LightningVisualBuilder

static func build_warning_ring(damage_radius: float) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var imm_ring := ImmediateMesh.new()
	ring.mesh = imm_ring

	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(1.0, 0.1, 0.1)
	ring.material_override = ring_mat

	imm_ring.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in range(33):
		var angle := float(i) * TAU / 32.0
		imm_ring.surface_add_vertex(Vector3(cos(angle) * damage_radius, 0.05, sin(angle) * damage_radius))
	imm_ring.surface_end()
	return ring

static func build_bolt_mesh(strike_height: float) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var imm_mesh := ImmediateMesh.new()
	mesh_instance.mesh = imm_mesh

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(2.2, 2.8, 6.0)
	mesh_instance.material_override = mat

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

	var offsets := [Vector3.ZERO, Vector3(0.06, 0.0, 0.06), Vector3(-0.06, 0.0, -0.06)]
	for offset_vec in offsets:
		for k in range(points.size() - 1):
			imm_mesh.surface_add_vertex(points[k] + offset_vec)
			imm_mesh.surface_add_vertex(points[k+1] + offset_vec)

	_draw_branch(imm_mesh, points[4], Vector3(-4.0, 4.0, -3.0))
	_draw_branch(imm_mesh, points[7], Vector3(4.0, 2.0, 3.0))

	imm_mesh.surface_end()
	return mesh_instance

static func _draw_branch(imm_mesh: ImmediateMesh, start_pt: Vector3, direction: Vector3) -> void:
	var current_pt := start_pt
	var segments := 4
	for i in range(segments):
		var next_pt := current_pt + (direction / segments) + Vector3(randf_range(-0.8, 0.8), -1.5, randf_range(-0.8, 0.8))
		imm_mesh.surface_add_vertex(current_pt)
		imm_mesh.surface_add_vertex(next_pt)
		current_pt = next_pt

static func build_sparks() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "StrikeSparks"
	particles.amount = 30
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 0.95

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

	particles.process_material = process_mat

	var quad := QuadMesh.new()
	quad.size = Vector2(0.15, 0.15)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	quad.material = mat

	particles.draw_pass_1 = quad
	return particles
