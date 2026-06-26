# game_camera.gd
class_name GameCamera
extends Node3D

@export var target_position: Vector3 = Vector3.ZERO
@export var camera_offset: Vector3 = Vector3(0.0, 18.0, 18.0)
@export var camera_rotate: Vector3 = Vector3(-45.0, 0.0, 0.0)
@export var follow_speed: float = 8.0
@export var map_limit: float = 50.0

var target: Node3D

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	add_to_group("camera")

	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20.0
	camera.near = 0.01
	camera.far = 180.0

	camera.position = camera_offset
	camera.rotation_degrees = camera_rotate

	_snap_to_target()


func _process(delta: float) -> void:
	var world_manager: Node = get_node_or_null("/root/World/WorldManager")
	if world_manager and world_manager.get("camera_magnet_active"):
		camera.position = camera_offset
		camera.rotation_degrees = camera_rotate
		return

	var desired_position := get_target_position()

	var next_pos := global_position.lerp(
		desired_position,
		clamp(follow_speed * delta, 0.0, 1.0)
	)

	# Dynamic viewport boundary clamping
	if camera != null and camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		var viewport_size := get_viewport().get_visible_rect().size
		var aspect_ratio := 16.0 / 9.0
		if viewport_size.y > 0.0:
			aspect_ratio = viewport_size.x / viewport_size.y

		# Vertical half span of orthogonal camera is size / 2.
		# Since the camera is rotated downward by camera_rotate.x, the projection on Z-axis is divided by sin(angle)
		var angle_rad := deg_to_rad(abs(camera_rotate.x))
		var half_depth := camera.size / (2.0 * sin(angle_rad)) if sin(angle_rad) > 0.0 else camera.size / 2.0
		
		# Horizontal half span is (size * aspect_ratio) / 2
		var half_width := (camera.size * aspect_ratio) / 2.0

		# Calculate clamp range
		var x_min := -map_limit + half_width
		var x_max := map_limit - half_width
		if x_min > x_max:
			x_min = 0.0
			x_max = 0.0

		var z_min := -map_limit + half_depth
		var z_max := map_limit - half_depth
		if z_min > z_max:
			z_min = 0.0
			z_max = 0.0

		next_pos.x = clampf(next_pos.x, x_min, x_max)
		next_pos.z = clampf(next_pos.z, z_min, z_max)

	global_position = next_pos

	# Khóa góc camera, không cho bị xoay lệch
	camera.position = camera_offset
	camera.rotation_degrees = camera_rotate


func set_target(new_target: Node3D) -> void:
	target = new_target
	_snap_to_target()


func get_target_position() -> Vector3:
	if target != null:
		return target.global_position

	return target_position


func _snap_to_target() -> void:
	global_position = get_target_position()
