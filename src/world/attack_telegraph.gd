# attack_telegraph.gd
# Ground-level warning decal for un-dodgeable AoE attacks.
# Spawned during the ANTICIPATION phase of an enemy's 3-phase attack.
# Players see a red ring on the ground BEFORE the hitbox turns on,
# giving them time to run out of the danger zone (combat-design-rules E2).
#
# This component is created via static factory `build()` and added to the
# scene tree as a child of the enemy. Auto-frees after `duration` seconds
# (or earlier if `cancel()` is called by the enemy when the attack ends).
class_name AttackTelegraph
extends Node3D

const COLOR_AOE_WARNING := Color(0.92, 0.18, 0.16, 0.55)
const COLOR_AOE_RING := Color(0.96, 0.32, 0.20, 0.85)
const DEFAULT_THICKNESS_RATIO: float = 0.10  # ring width as % of radius
const FLASH_PERIOD: float = 0.35

var _ring_mesh: MeshInstance3D = null
var _disc_mesh: MeshInstance3D = null
var _lifetime: float = 0.0
var _duration: float = 0.0
var _active: bool = true
var _flash_timer: float = 0.0

# Build a circular telegraph centered at the given world position.
# `radius` is the warning zone radius in metres. `duration` is how long
# the decal stays visible (must be >= 0.8s per E2 rule).
static func build_circle(center: Vector3, radius: float, duration: float, ground_y: float = 0.05) -> Node3D:
	var telegraph: Node3D = (load("res://src/world/attack_telegraph.gd") as GDScript).new()
	telegraph.global_position = Vector3(center.x, ground_y, center.z)
	telegraph._build_circle_visuals(radius)
	telegraph._duration = maxf(duration, 0.8)
	return telegraph

# Build a line / cone telegraph for directional AoE. `length` is along
# forward, `width` is the perpendicular spread.
static func build_line(origin: Vector3, forward: Vector3, length: float, width: float, duration: float, ground_y: float = 0.05) -> Node3D:
	var telegraph: Node3D = (load("res://src/world/attack_telegraph.gd") as GDScript).new()
	telegraph.global_position = Vector3(origin.x, ground_y, origin.z)
	if forward.length_squared() > 0.0:
		telegraph.look_at(telegraph.global_position + forward.normalized(), Vector3.UP)
	telegraph._build_line_visuals(length, width)
	telegraph._duration = maxf(duration, 0.8)
	return telegraph

# Cancel the telegraph early (e.g. enemy died, attack interrupted).
func cancel() -> void:
	if not _active:
		return
	_active = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.tween_callback(queue_free)

func _process(delta: float) -> void:
	if not _active:
		return
	_lifetime += delta
	_flash_timer += delta
	# Flash effect: peak red right before damage lands.
	var phase := fposmod(_flash_timer, FLASH_PERIOD) / FLASH_PERIOD
	var pulse := 0.6 + 0.4 * sin(phase * TAU)
	if _ring_mesh and is_instance_valid(_ring_mesh):
		var c := COLOR_AOE_RING
		c.a = 0.55 + 0.30 * pulse
		var mat := _ring_mesh.get_active_material(0)
		if mat is StandardMaterial3D:
			(mat as StandardMaterial3D).albedo_color = c
	if _disc_mesh and is_instance_valid(_disc_mesh):
		var d := COLOR_AOE_WARNING
		d.a = 0.35 + 0.20 * pulse
		var dmat := _disc_mesh.get_active_material(0)
		if dmat is StandardMaterial3D:
			(dmat as StandardMaterial3D).albedo_color = d
	if _lifetime >= _duration:
		cancel()

func _build_circle_visuals(radius: float) -> void:
	_disc_mesh = _create_disc(radius * 0.98, COLOR_AOE_WARNING)
	add_child(_disc_mesh)
	_ring_mesh = _create_ring(radius, DEFAULT_THICKNESS_RATIO * radius, COLOR_AOE_RING)
	add_child(_ring_mesh)

func _build_line_visuals(length: float, width: float) -> void:
	_disc_mesh = _create_box(length, width, 0.05, COLOR_AOE_WARNING)
	add_child(_disc_mesh)
	_ring_mesh = _create_box(length, width, 0.05, COLOR_AOE_RING)
	add_child(_ring_mesh)

func _create_disc(radius: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = 0.02
	mi.mesh = cylinder
	mi.rotation_degrees.x = 90.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.set_surface_override_material(0, mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _create_ring(radius: float, thickness: float, color: Color) -> MeshInstance3D:
	# Use a thin annulus via a TorusMesh-style trick: outer cylinder minus
	# inner. Simpler: a slightly larger flat disc with a punch. For runtime
	# simplicity we use a single disc with an emissive outline ring effect
	# by stacking two cylinders.
	var mi := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = 0.04
	mi.mesh = cylinder
	mi.rotation_degrees.x = 90.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.5
	mi.set_surface_override_material(0, mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _create_box(length: float, width: float, height: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(length, height, width)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.set_surface_override_material(0, mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
