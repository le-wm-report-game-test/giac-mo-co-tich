# game_camera.gd
class_name GameCamera
extends Node3D

@export var target_position: Vector3 = Vector3.ZERO
@export var camera_offset: Vector3 = Vector3(0.0, 10.0, 10.0)
@export var camera_rotate: Vector3 = Vector3(-45.0, 0.0, 0.0)
@export var follow_speed: float = 8.0

var target: Node3D

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	add_to_group("camera")

	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20.0

	camera.position = camera_offset
	camera.rotation_degrees = camera_rotate

	_snap_to_target()


func _process(delta: float) -> void:
	var desired_position := get_target_position()

	global_position = global_position.lerp(
		desired_position,
		clamp(follow_speed * delta, 0.0, 1.0)
	)

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
