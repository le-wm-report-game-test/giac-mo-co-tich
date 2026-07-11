class_name WorldRainEmitter
extends Node

const PARTICLE_AMOUNT: int = 800
const EMITTER_HEIGHT: float = 20.0
const COVERAGE_MARGIN: float = 4.0
const DEPTH_MARGIN: float = 9.0

var _world_manager: Node = null


func setup(world_manager: Node) -> void:
	_world_manager = world_manager


func create() -> void:
	_release_existing_immediately()
	var particles := GPUParticles3D.new()
	particles.name = "RainParticles"
	particles.emitting = true
	particles.amount = PARTICLE_AMOUNT
	particles.lifetime = 1.2
	particles.preprocess = 1.2
	particles.local_coords = false
	particles.fixed_fps = 30
	particles.interpolate = true
	particles.fract_delta = true
	particles.draw_order = GPUParticles3D.DRAW_ORDER_LIFETIME
	particles.process_material = _create_process_material()
	particles.draw_pass_1 = _create_draw_pass()
	_world_manager.get_parent().add_child(particles)
	_world_manager.rain_particles = particles
	update_coverage()


func stop() -> void:
	var particles := _world_manager.get("rain_particles") as GPUParticles3D
	_world_manager.rain_particles = null
	if not is_instance_valid(particles):
		return
	particles.emitting = false
	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_callback(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)


func update_coverage() -> void:
	var particles := _world_manager.get("rain_particles") as GPUParticles3D
	if not is_instance_valid(particles) or not particles.emitting:
		return
	var camera := _world_manager.get_viewport().get_camera_3d()
	var camera_rig := get_tree().get_first_node_in_group("camera") as GameCamera
	if camera == null or camera_rig == null:
		return
	var anchor := camera_rig.global_position
	particles.global_position = Vector3(anchor.x, anchor.y + EMITTER_HEIGHT, anchor.z)
	var viewport_size := _world_manager.get_viewport().get_visible_rect().size
	var aspect_ratio := viewport_size.x / maxf(viewport_size.y, 1.0)
	var vertical_span := camera.size if camera.projection == Camera3D.PROJECTION_ORTHOGONAL else 18.0
	var tilt_sine := maxf(sin(absf(camera.global_rotation.x)), 0.35)
	var extents := Vector3(
		vertical_span * aspect_ratio * 0.5 + COVERAGE_MARGIN,
		1.5,
		vertical_span / (2.0 * tilt_sine) + DEPTH_MARGIN
	)
	var material := particles.process_material as ParticleProcessMaterial
	if material:
		material.emission_box_extents = extents
	var cull_extents := Vector3(extents.x + 2.0, EMITTER_HEIGHT + 8.0, extents.z + 2.0)
	particles.visibility_aabb = AABB(-cull_extents, cull_extents * 2.0)


func _release_existing_immediately() -> void:
	var particles := _world_manager.get("rain_particles") as GPUParticles3D
	_world_manager.rain_particles = null
	if is_instance_valid(particles):
		particles.emitting = false
		particles.queue_free()


func _create_process_material() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(18.0, 1.5, 20.0)
	material.gravity = Vector3(-5.0, -22.0, 2.0)
	material.initial_velocity_min = 14.0
	material.initial_velocity_max = 20.0
	material.scale_min = 0.8
	material.scale_max = 1.15
	material.color = Color(0.66, 0.78, 1.0, 0.52)
	material.direction = Vector3.DOWN
	material.spread = 4.0
	return material


func _create_draw_pass() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.032, 0.45)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	quad.material = material
	return quad
