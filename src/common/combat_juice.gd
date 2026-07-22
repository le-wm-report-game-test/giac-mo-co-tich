# combat_juice.gd
# Shared combat feedback helpers: camera shake + one-shot impact particle
# bursts. Static-only, mirrors the UITheme pattern (src/ui/ui_theme.gd) so
# callers never instantiate it — just `CombatJuice.camera_shake(...)`.
class_name CombatJuice
extends RefCounted

const HIT_FLASH_DURATION: float = 0.14
const HIT_FLASH_COLOR := Color(2.6, 1.5, 1.3)

static func camera_shake(tree: SceneTree, duration: float, amplitude: float) -> void:
	if tree == null:
		return
	var cam := tree.get_first_node_in_group("camera") as GameCamera
	if cam:
		cam.shake(duration, amplitude)

static func spawn_impact_burst(
	parent: Node,
	world_position: Vector3,
	spray_direction: Vector3,
	colors: PackedColorArray,
	amount: int = 12,
	lifetime: float = 0.5,
	box_size: float = 0.06
) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return

	var particles := CPUParticles3D.new()
	particles.name = "ImpactBurst"

	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * box_size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	particles.mesh = mesh

	particles.amount = amount
	particles.explosiveness = 1.0
	particles.one_shot = true
	particles.lifetime = lifetime

	var dir := spray_direction
	if dir.length_squared() < 0.0001:
		dir = Vector3.UP
	particles.direction = dir.normalized()
	particles.spread = 45.0
	particles.initial_velocity_min = 3.0
	particles.initial_velocity_max = 5.0
	particles.damping_min = 1.0
	particles.damping_max = 2.0

	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	var stops := maxi(colors.size() - 1, 1)
	for i in range(colors.size()):
		offsets.append(float(i) / float(stops))
	gradient.offsets = offsets
	gradient.colors = colors
	particles.color_ramp = gradient

	parent.add_child(particles)
	particles.global_position = world_position
	particles.emitting = true

	var timer := parent.get_tree().create_timer(lifetime + 0.15)
	timer.timeout.connect(particles.queue_free)

static func spawn_ground_shockwave(
	parent: Node,
	world_position: Vector3,
	color: Color,
	max_radius: float = 4.0,
	duration: float = 0.6
) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return

	var ring := MeshInstance3D.new()
	ring.name = "GroundShockwave"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.55
	mesh.outer_radius = 1.0
	ring.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = mat

	parent.add_child(ring)
	ring.global_position = world_position + Vector3(0.0, 0.05, 0.0)
	ring.scale = Vector3(0.05, 0.05, 0.05)

	var tween := parent.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(max_radius, 0.05, max_radius), duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, duration).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_callback(ring.queue_free)
