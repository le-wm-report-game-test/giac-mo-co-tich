# chan_tinh_mob.gd
class_name ChanTinhMob
extends OrcMob

# Enums and Constants
enum MoveDir { DOWN, UP, RIGHT, LEFT, DOWN_RIGHT, DOWN_LEFT, UP_RIGHT, UP_LEFT }

const MOVE_DIR_NAMES: Dictionary = {
	MoveDir.DOWN: "down",
	MoveDir.UP: "up",
	MoveDir.RIGHT: "right",
	MoveDir.LEFT: "left",
	MoveDir.DOWN_RIGHT: "down_right",
	MoveDir.DOWN_LEFT: "down_left",
	MoveDir.UP_RIGHT: "up_right",
	MoveDir.UP_LEFT: "up_left",
}

var facing_direction: Vector3 = Vector3(0.0, 0.0, 1.0)
var move_direction: MoveDir = MoveDir.DOWN

func _ready() -> void:
	super._ready()
	
	# Thiết lập chỉ số cho Chằn Tinh sau super._ready() để tránh bị ghi đè bởi cấu hình OrcMob thường
	if not is_in_group("boss"):
		max_health = 80.0
		attack_damage = 15.0
		speed = 1.6
		sprite_pixel_size = 2.0 / 256.0 # Chiều cao khoảng 2m
	else:
		# Giữ chỉ số Boss đã được cấu hình từ WorldManager nhưng cập nhật pixel_size
		max_health = 300.0
		attack_damage = 25.0
		speed = 1.5
		sprite_pixel_size = 3.5 / 256.0 # Chiều cao Boss khoảng 3.5m (khoảng gấp đôi nhân vật)
		
	# Áp dụng pixel_size chuẩn cho sprite và cập nhật vị trí Y chạm đất thực tế
	if is_instance_valid(sprite):
		sprite.pixel_size = sprite_pixel_size
		sprite.position.y = _get_grounded_sprite_y()
		
	# Cập nhật lại chỉ số máu cho component
	if is_instance_valid(health_component):
		health_component.max_health = max_health
		health_component.current_health = max_health

func _get_grounded_sprite_y() -> float:
	# Căn chỉnh cạnh dưới của ảnh 256x256 sát mặt đất (tâm ảnh nằm ở giữa)
	return (256.0 * sprite_pixel_size) / 2.0

func _update_facing_direction() -> void:
	var look_dir := Vector3.ZERO
	var player := get_tree().get_first_node_in_group("player") as Node3D
	
	if current_state == State.DEATH:
		return
		
	if (current_state == State.CHASE or current_state == State.ATTACK) and player:
		look_dir = _get_planar_offset_to(player)
	elif velocity.length_squared() > 0.01:
		look_dir = velocity
		
	if look_dir.length_squared() > 0.0001:
		facing_direction = _snap_direction_to_octant(look_dir.normalized())
		move_direction = _get_move_direction_from_facing(facing_direction)

func _snap_direction_to_octant(dir: Vector3) -> Vector3:
	var angle := atan2(dir.z, dir.x)
	var snapped_angle := roundf(angle / (PI / 4.0)) * (PI / 4.0)
	return Vector3(cos(snapped_angle), 0.0, sin(snapped_angle)).normalized()

func _get_move_direction_from_facing(dir: Vector3) -> MoveDir:
	var x_positive := dir.x > 0.25
	var x_negative := dir.x < -0.25
	var z_positive := dir.z > 0.25
	var z_negative := dir.z < -0.25

	if x_positive and z_positive:
		return MoveDir.DOWN_RIGHT
	if x_negative and z_positive:
		return MoveDir.DOWN_LEFT
	if x_positive and z_negative:
		return MoveDir.UP_RIGHT
	if x_negative and z_negative:
		return MoveDir.UP_LEFT
	if x_positive:
		return MoveDir.RIGHT
	if x_negative:
		return MoveDir.LEFT
	if z_negative:
		return MoveDir.UP
	return MoveDir.DOWN

func _update_sprite() -> void:
	_update_facing_direction()
	
	var prefix := "idle"
	var frame_count := 3
	
	match current_state:
		State.IDLE:
			prefix = "idle"
			frame_count = 3
		State.WANDER, State.CHASE:
			prefix = "walk"
			frame_count = 7
		State.ATTACK:
			prefix = "attack"
			frame_count = 4
		State.HURT:
			prefix = "hurt"
			frame_count = 4
		State.DEATH:
			prefix = "die"
			frame_count = 4
			
	var frame := clampi(current_frame, 0, frame_count - 1)
	var dir_name: String = MOVE_DIR_NAMES.get(move_direction, "down")
	var path := "res://Assets/enemies/chan_tinh/movement_frames/%s_%s_%d.png" % [dir_name, prefix, frame]
	
	if not _texture_cache.has(path):
		if ResourceLoader.exists(path):
			_texture_cache[path] = load(path) as Texture2D
		else:
			_texture_cache[path] = null
			
	var tex: Texture2D = _texture_cache[path]
	if tex:
		sprite.texture = tex
		sprite.region_enabled = false
		sprite.flip_h = false

func _update_animation(delta: float) -> void:
	var max_frames := 3
	anim_fps = 6.0
	
	match current_state:
		State.IDLE:
			max_frames = 3
			anim_fps = 5.0
		State.WANDER, State.CHASE:
			max_frames = 7
			anim_fps = 8.0 if current_state == State.WANDER else 10.0
		State.ATTACK:
			max_frames = 4
			anim_fps = attack_animation_fps
		State.HURT:
			max_frames = 4
			anim_fps = 6.0
	
	frame_timer += delta
	if frame_timer >= 1.0 / anim_fps:
		frame_timer = 0.0
		current_frame += 1
		if current_frame >= max_frames:
			match current_state:
				State.ATTACK:
					current_state = State.IDLE
					current_frame = 0
					attack_cooldown_timer = attack_cooldown_time
					hitbox_component.monitoring = false
				State.HURT:
					current_state = State.IDLE
					current_frame = 0
				_:
					current_frame = 0
	
	if current_state == State.ATTACK:
		hitbox_component.monitoring = (current_frame == 2)
	
	_update_sprite()

func _process_death_state(delta: float) -> void:
	velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta
	move_and_slide()
	frame_timer += delta
	if frame_timer >= 1.0 / 6.0:
		frame_timer = 0.0
		if current_frame < 3:
			current_frame += 1
		else:
			set_physics_process(false)
			var tween := create_tween()
			tween.tween_property(sprite, "modulate:a", 0.0, 1.5)
			tween.tween_callback(queue_free)
			return
	_update_sprite()
