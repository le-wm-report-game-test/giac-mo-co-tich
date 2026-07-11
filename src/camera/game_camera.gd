# game_camera.gd
class_name GameCamera
extends Node3D

@export var target_position: Vector3 = Vector3.ZERO
@export var camera_offset: Vector3 = Vector3(10.32, 18.0, 14.74)
@export var camera_rotate: Vector3 = Vector3(-45.0, 35.0, 0.0)
@export var follow_speed: float = 8.0
@export var map_limit: float = 50.0
@export var normal_camera_size: float = 15.0
@export var min_camera_size: float = 12.0  # 20% closer than normal
@export var scroll_zoom_sensitivity: float = 0.5
@export var scroll_zoom_tween_duration: float = 0.15
@export var startup_close_camera_size: float = 5.5
@export var startup_close_hold_time: float = 0.8
@export var startup_zoom_out_duration: float = 1.4

var _scroll_tween: Tween = null
var _current_camera_size: float = 15.0

var target: Node3D
var player_pcam: PhantomCamera3D
var magnet_pcam: PhantomCamera3D
var camera_noise: PhantomCameraNoise3D
var startup_intro_active: bool = false
var startup_intro_finished: bool = false
var _startup_intro_tween: Tween = null

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	add_to_group("camera")

	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = normal_camera_size
	camera.near = 0.01
	camera.far = 180.0

	camera.position = camera_offset
	camera.rotation_degrees = camera_rotate

	_init_phantom_cameras()
	_snap_to_target()


func _process(delta: float) -> void:
	var world_manager := get_tree().get_first_node_in_group("world_manager") as WorldManager
	if world_manager and world_manager.get("camera_magnet_active"):
		return

	# The PhantomCamera3D owns the cinematic framing — it lerps its anchor
	# toward `self` using its own damping. We just have to make sure `self`
	# (the GameCamera node) actually follows the player; otherwise the pcam
	# anchor freezes at world origin and the player runs off-screen.
	# The earlier version snap-set global_position every frame which caused
	# the visible stutter (the pcam damping could never catch up to a snap
	# that happened before its tween tick). With follow_damping_value = 1.0
	# the pcam snaps in ~16ms which the player can't perceive as lag.
	if target == null:
		return
	global_position = _clamp_position(target.global_position)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if not mb.pressed:
				return
			var delta_size := -scroll_zoom_sensitivity if mb.button_index == MOUSE_BUTTON_WHEEL_UP else scroll_zoom_sensitivity
			_zoom_camera(_current_camera_size + delta_size)


func _zoom_camera(target_size: float) -> void:
	var clamped := clampf(target_size, min_camera_size, normal_camera_size)
	if is_equal_approx(clamped, _current_camera_size):
		return
	if _scroll_tween:
		_scroll_tween.kill()
	_scroll_tween = create_tween()
	_scroll_tween.set_trans(Tween.TRANS_CUBIC)
	_scroll_tween.set_ease(Tween.EASE_OUT)
	_scroll_tween.tween_method(
		func(v: float) -> void:
			_current_camera_size = v
			_set_player_camera_size(v),
		_current_camera_size,
		clamped,
		scroll_zoom_tween_duration
	)


func set_target(new_target: Node3D) -> void:
	target = new_target
	if target != null:
		snap_to_target()


func get_target_position() -> Vector3:
	if target != null:
		return target.global_position
	return target_position


func snap_to_target() -> void:
	global_position = _clamp_position(get_target_position())
	target_position = global_position
	force_update_transform()
	if camera:
		camera.force_update_transform()


func _snap_to_target() -> void:
	snap_to_target()


func play_startup_intro(new_target: Node3D = null) -> void:
	if new_target != null:
		set_target(new_target)
	if target == null:
		return
	if _startup_intro_tween:
		_startup_intro_tween.kill()
	snap_to_target()
	startup_intro_active = true
	startup_intro_finished = false
	_set_target_input_locked(true)
	_set_player_camera_size(startup_close_camera_size)
	_startup_intro_tween = create_tween()
	_startup_intro_tween.set_trans(Tween.TRANS_CUBIC)
	_startup_intro_tween.set_ease(Tween.EASE_IN_OUT)
	_startup_intro_tween.tween_interval(startup_close_hold_time)
	_startup_intro_tween.tween_method(
		_set_player_camera_size,
		startup_close_camera_size,
		normal_camera_size,
		startup_zoom_out_duration
	)
	_startup_intro_tween.tween_callback(_finish_startup_intro)


func skip_startup_intro() -> void:
	if _startup_intro_tween:
		_startup_intro_tween.kill()
	startup_intro_active = false
	startup_intro_finished = true
	_set_player_camera_size(normal_camera_size)
	_current_camera_size = normal_camera_size
	_set_target_input_locked(false)
	snap_to_target()


func _finish_startup_intro() -> void:
	startup_intro_active = false
	startup_intro_finished = true
	_set_player_camera_size(normal_camera_size)
	_current_camera_size = normal_camera_size
	_set_target_input_locked(false)


func _set_player_camera_size(size: float) -> void:
	if camera:
		camera.size = size
	if player_pcam and player_pcam.camera_3d_resource:
		player_pcam.camera_3d_resource.size = size


func _set_target_input_locked(locked: bool) -> void:
	var player := target as Player
	if player:
		player.input_locked = locked


func activate_magnet(target_pos: Vector3, zoom_size: float) -> void:
	if not magnet_pcam:
		return
	# Place the magnet anchor at a slightly wider offset than the player
	# follow so the boss has room to breathe in frame (the player offset
	# sits ~14m behind, which puts the boss at the very edge of view).
	var magnet_offset: Vector3 = camera_offset * Vector3(1.25, 1.05, 1.25)
	magnet_pcam.global_position = target_pos + magnet_offset
	magnet_pcam.rotation_degrees = camera_rotate
	# Aim the camera at the boss instead of relying on a static rotation, so
	# the framing survives even if the boss drifts off the arena centre.
	if magnet_pcam.has_method("look_at_target"):
		magnet_pcam.set("look_at_target", target_pos)
	if magnet_pcam.camera_3d_resource:
		magnet_pcam.camera_3d_resource.size = zoom_size
	magnet_pcam.priority = 100  # higher than any other pcam so the tween wins


func deactivate_magnet() -> void:
	if magnet_pcam:
		magnet_pcam.priority = 0


func shake(duration: float, amplitude: float) -> void:
	if player_pcam and camera_noise:
		camera_noise.amplitude = amplitude
		camera_noise.set_trauma(1.0)
		player_pcam.noise = camera_noise
		var tween := create_tween()
		if tween:
			tween.tween_method(
				func(v: float) -> void: camera_noise.set_trauma(v),
				1.0,
				0.0,
				duration
			)
			tween.tween_callback(func() -> void:
				player_pcam.noise = null
			)


func _init_phantom_cameras() -> void:
	# 1. Create Host
	var host := PhantomCameraHost.new()
	host.name = "PhantomCameraHost"
	host.process_priority = 300
	host.process_physics_priority = 300
	camera.add_child(host)

	# 2. Create Player Follow PCam
	player_pcam = PhantomCamera3D.new()
	player_pcam.name = "PlayerPhantomCamera"
	player_pcam.top_level = true
	add_child(player_pcam)
	
	var play_res := Camera3DResource.new()
	play_res.projection = camera.projection as int
	play_res.size = camera.size
	play_res.near = camera.near
	play_res.far = camera.far
	play_res.fov = camera.fov
	player_pcam.camera_3d_resource = play_res
	
	player_pcam.priority = 10
	var player_tween := PhantomCameraTween.new()
	player_tween.duration = 0.0
	player_pcam.tween_resource = player_tween
	player_pcam.follow_mode = 2 # SIMPLE
	player_pcam.follow_target = self
	player_pcam.follow_offset = camera_offset
	player_pcam.rotation_degrees = camera_rotate
	# PhantomCamera damping is a smoothing duration in seconds: lower values
	# converge faster. Keep startup close to the player without losing all ease.
	player_pcam.follow_damping = true
	player_pcam.follow_damping_value = Vector3(0.08, 0.08, 0.08)

	# Set up Noise for Screen Shake
	camera_noise = PhantomCameraNoise3D.new()
	camera_noise.amplitude = 10.0
	camera_noise.frequency = 0.2
	camera_noise.positional_noise = true
	camera_noise.rotational_noise = true
	player_pcam.noise = null # Keep it null initially to prevent idle wobbling

	# 3. Create Magnet Arena PCam
	magnet_pcam = PhantomCamera3D.new()
	magnet_pcam.name = "MagnetPhantomCamera"
	magnet_pcam.top_level = true
	add_child(magnet_pcam)
	
	var mag_res := Camera3DResource.new()
	mag_res.projection = camera.projection as int
	mag_res.size = camera.size
	mag_res.near = camera.near
	mag_res.far = camera.far
	mag_res.fov = camera.fov
	magnet_pcam.camera_3d_resource = mag_res
	
	magnet_pcam.priority = 0
	magnet_pcam.follow_mode = 0 # NONE (placed statically at magnet offset)
	
	var tween_res := PhantomCameraTween.new()
	tween_res.duration = 2.0
	tween_res.transition = 7 # CUBIC
	tween_res.ease = 2 # EASE_IN_OUT
	magnet_pcam.tween_resource = tween_res


func _clamp_position(pos: Vector3) -> Vector3:
	var clamped := pos
	if camera != null and camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		var viewport_size := get_viewport().get_visible_rect().size
		var aspect_ratio := 16.0 / 9.0
		if viewport_size.y > 0.0:
			aspect_ratio = viewport_size.x / viewport_size.y

		var angle_rad := deg_to_rad(abs(camera_rotate.x))
		var span_depth := camera.size / sin(angle_rad) if sin(angle_rad) > 0.0 else camera.size
		var span_width := camera.size * aspect_ratio
		
		var yaw_rad := deg_to_rad(camera_rotate.y)
		var cam_right_proj := Vector3(cos(yaw_rad), 0.0, -sin(yaw_rad)).normalized()
		var cam_forward_proj := Vector3(sin(yaw_rad), 0.0, cos(yaw_rad)).normalized()
		
		var vec_w := cam_right_proj * (span_width / 2.0)
		var vec_d := cam_forward_proj * (span_depth / 2.0)
		
		var max_x := absf(vec_w.x) + absf(vec_d.x)
		var max_z := absf(vec_w.z) + absf(vec_d.z)

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

		clamped.x = clampf(clamped.x, x_min, x_max)
		clamped.z = clampf(clamped.z, z_min, z_max)

	return clamped
