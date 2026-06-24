# player.gd
class_name Player
extends CharacterBody3D

@export var speed: float = 5.0
@export var acceleration: float = 15.0
@export var deceleration: float = 15.0
@export var gravity: float = 9.8

# Runtime velocity direction
var _target_velocity: Vector3 = Vector3.ZERO

func _ready() -> void:
	_setup_input_actions()

func _setup_input_actions() -> void:
	var actions: Dictionary = {
		"move_left": KEY_A,
		"move_right": KEY_D,
		"move_up": KEY_W,
		"move_down": KEY_S
	}
	
	for action: String in actions:
		var action_name := StringName(action)
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		else:
			InputMap.action_erase_events(action_name)
			
		var event := InputEventKey.new()
		event.physical_keycode = actions[action]
		event.keycode = actions[action]
		InputMap.action_add_event(action_name, event)

func _physics_process(delta: float) -> void:
	# Add gravity if not on ground
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Get input direction
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := _get_camera_relative_direction(input_vector)

	if direction != Vector3.ZERO:
		# Calculate target velocity on horizontal plane
		_target_velocity.x = direction.x * speed
		_target_velocity.z = direction.z * speed
		
		# Rotate Player mesh/body to face the movement direction
		var target_rotation_y := atan2(-direction.x, -direction.z)
		rotation.y = rotate_toward(rotation.y, target_rotation_y, 10.0 * delta)
		
		# Smooth acceleration
		velocity.x = move_toward(velocity.x, _target_velocity.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, _target_velocity.z, acceleration * delta)
	else:
		# Smooth deceleration
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)

	move_and_slide()

	# Clamp player position within the forest map bounds (-28 to 28)
	global_position.x = clampf(global_position.x, -28.0, 28.0)
	global_position.z = clampf(global_position.z, -28.0, 28.0)

func _get_camera_relative_direction(input_dir: Vector2) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return Vector3(input_dir.x, 0.0, input_dir.y).normalized()

	var cam_forward := -camera.global_transform.basis.z
	var cam_right := camera.global_transform.basis.x

	# Project onto the XZ (horizontal) plane
	cam_forward.y = 0.0
	cam_right.y = 0.0
	cam_forward = cam_forward.normalized()
	cam_right = cam_right.normalized()

	# Combine vectors based on input (negate y because move_up makes input_dir.y negative)
	var direction := cam_right * input_dir.x + cam_forward * -input_dir.y
	return direction.normalized()
