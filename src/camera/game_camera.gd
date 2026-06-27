# game_camera.gd
class_name GameCamera
extends Node3D

@export var target_position: Vector3 = Vector3.ZERO
@export var camera_offset: Vector3 = Vector3(10.32, 18.0, 14.74)
@export var camera_rotate: Vector3 = Vector3(-45.0, 35.0, 0.0)
@export var follow_speed: float = 8.0
@export var map_limit: float = 50.0

var target: Node3D

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	add_to_group("camera")

	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 15.0
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

		# Dynamic viewport boundary clamping accounting for camera Y-rotation (yaw)
		var angle_rad := deg_to_rad(abs(camera_rotate.x))
		var span_depth := camera.size / sin(angle_rad) if sin(angle_rad) > 0.0 else camera.size
		var span_width := camera.size * aspect_ratio
		
		# Get projected unit vectors for camera's local X (right) and Z (forward) directions
		var yaw_rad := deg_to_rad(camera_rotate.y)
		var cam_right_proj := Vector3(cos(yaw_rad), 0.0, -sin(yaw_rad)).normalized()
		var cam_forward_proj := Vector3(sin(yaw_rad), 0.0, cos(yaw_rad)).normalized()
		
		# Half vectors of the viewport footprint on the ground
		var vec_w := cam_right_proj * (span_width / 2.0)
		var vec_d := cam_forward_proj * (span_depth / 2.0)
		
		# Bounding extension of the rotated viewport rectangle along global axes
		var max_x := absf(vec_w.x) + absf(vec_d.x)
		var max_z := absf(vec_w.z) + absf(vec_d.z)

		# Calculate clamp range
		var x_min := -map_limit + max_x
		var x_max := map_limit - max_x
		if x_min > x_max:
			x_min = 0.0
			x_max = 0.0

		var z_min := -map_limit + max_z
		var z_max := map_limit - max_z
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
