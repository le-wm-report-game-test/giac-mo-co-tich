# player.gd
class_name Player
extends CharacterBody3D

@export var speed: float = 5.0
@export var acceleration: float = 15.0
@export var deceleration: float = 15.0
@export var gravity: float = 9.8
@export var attack_damage: float = 25.0
@export var attack_range: float = 1.15
@export var max_health: float = 100.0

# Runtime velocity direction
var _target_velocity: Vector3 = Vector3.ZERO

# Animation
enum AnimState { IDLE, WALK, ATTACK, HURT, DEATH }
var anim_state: AnimState = AnimState.IDLE
var anim_frame: int = 0
var anim_timer: float = 0.0
var anim_fps: float = 6.0
var facing_right: bool = true

# Attack
var is_attacking: bool = false
var attack_cooldown: float = 0.0
var attack_window_active: bool = false
var attack_mouse_pos: Vector2 = Vector2.ZERO

# Hurt
var invulnerable_timer: float = 0.0
var invulnerable_duration: float = 0.5

var _texture_cache: Dictionary = {}

@onready var health_component: HealthComponent = $HealthComponent
@onready var sprite: Sprite3D = $Visuals/Sprite3D
@onready var hitbox_area: Area3D = $HitboxArea
@onready var hitbox_shape: CollisionShape3D = $HitboxArea/HitboxShape

func _ready() -> void:
	_setup_input_actions()
	if health_component:
		health_component.max_health = max_health
		health_component.current_health = max_health
		health_component.died.connect(_on_died)
		health_component.health_changed.connect(_on_health_changed)
		health_component.damaged.connect(_on_damaged)
	
	# Setup sprite
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.billboard = StandardMaterial3D.BILLBOARD_FIXED_Y
	sprite.shaded = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.12
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sprite.pixel_size = 0.0086  # Scale sprite to ~1.9m height (221px sprite * 0.0086 = 1.9m)
	
	# Setup collision (CapsuleShape3D for 1.8m human)
	$CollisionShape3D.shape.height = 1.6
	$CollisionShape3D.position.y = 0.8
	
	# Setup hitbox
	hitbox_area.monitoring = false
	hitbox_area.area_entered.connect(_on_hitbox_area_entered)
	_configure_attack_hitbox()
	
	_update_sprite()

func _configure_attack_hitbox() -> void:
	var box := hitbox_shape.shape as BoxShape3D
	if box == null:
		box = BoxShape3D.new()
		hitbox_shape.shape = box
	box.size = Vector3(maxf(0.55, attack_range * 0.55), 1.0, 0.85)
	_update_attack_hitbox_position()

func _update_attack_hitbox_position() -> void:
	var dir := 1.0 if facing_right else -1.0
	hitbox_shape.position = Vector3(dir * attack_range * 0.45, 0.9, 0.0)

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

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if anim_state != AnimState.DEATH and not is_attacking and attack_cooldown <= 0.0:
			_start_attack()

func _physics_process(delta: float) -> void:
	# Cooldowns
	if attack_cooldown > 0.0:
		attack_cooldown -= delta
	if invulnerable_timer > 0.0:
		invulnerable_timer -= delta
		# Blink effect when invulnerable
		sprite.modulate.a = 0.5 if int(invulnerable_timer * 10) % 2 == 0 else 1.0
	else:
		sprite.modulate.a = 1.0
	
	# Don't process movement during attack or death
	if anim_state == AnimState.ATTACK or anim_state == AnimState.DEATH:
		_process_animation(delta)
		move_and_slide()
		return
	
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
		
		# Determine facing direction based on movement
		if direction.x > 0.1:
			facing_right = true
		elif direction.x < -0.1:
			facing_right = false
		
		# Smooth acceleration
		velocity.x = move_toward(velocity.x, _target_velocity.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, _target_velocity.z, acceleration * delta)
		
		anim_state = AnimState.WALK
	else:
		# Smooth deceleration
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
		
		if anim_state != AnimState.HURT:
			anim_state = AnimState.IDLE

	move_and_slide()
	
	# Clamp player position within the forest map bounds (-48 to 48)
	global_position.x = clampf(global_position.x, -48.0, 48.0)
	global_position.z = clampf(global_position.z, -48.0, 48.0)
	
	_process_animation(delta)

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

func _start_attack() -> void:
	is_attacking = true
	anim_state = AnimState.ATTACK
	anim_frame = 0
	anim_timer = 0.0
	anim_fps = 10.0
	attack_window_active = false
	velocity = Vector3.ZERO
	
	# Play attack sound
	var audio := get_node_or_null("/root/World/AudioManager") as AudioManager
	if audio:
		audio.play_sfx("sword_swing", global_position, 0.15)
	
	# Get mouse position for attack direction
	attack_mouse_pos = get_viewport().get_mouse_position()
	
	# Determine facing direction based on mouse position
	var camera := get_viewport().get_camera_3d()
	if camera:
		var from := camera.project_ray_origin(attack_mouse_pos)
		var dir := camera.project_ray_normal(attack_mouse_pos)
		var plane := Plane(Vector3(0, 1, 0), global_position.y)
		var hit: Variant = plane.intersects_ray(from, dir)
		if hit != null:
			var target_pos: Vector3 = hit
			var diff: Vector3 = target_pos - global_position
			if diff.x > 0.1:
				facing_right = true
			elif diff.x < -0.1:
				facing_right = false
	_update_attack_hitbox_position()

func _process_animation(delta: float) -> void:
	anim_timer += delta
	var fps := anim_fps
	
	match anim_state:
		AnimState.IDLE:
			fps = 5.0
		AnimState.WALK:
			fps = 8.0
		AnimState.ATTACK:
			fps = 10.0
		AnimState.HURT:
			fps = 6.0
		AnimState.DEATH:
			fps = 5.0
	
	if anim_timer >= 1.0 / fps:
		anim_timer = 0.0
		anim_frame += 1
		_check_animation_end()
	
	# Enable hitbox during specific attack frame
	if anim_state == AnimState.ATTACK:
		hitbox_area.monitoring = (anim_frame == 3)
	
	_update_sprite()

func _check_animation_end() -> void:
	match anim_state:
		AnimState.IDLE:
			var max_frames := 3
			if anim_frame >= max_frames:
				anim_frame = 0
		AnimState.WALK:
			var max_frames := 8
			if anim_frame >= max_frames:
				anim_frame = 0
		AnimState.ATTACK:
			var max_frames := 5
			if anim_frame >= max_frames:
				is_attacking = false
				anim_state = AnimState.IDLE
				anim_frame = 0
				attack_cooldown = 0.3
				hitbox_area.monitoring = false
		AnimState.HURT:
			var max_frames := 3
			if anim_frame >= max_frames:
				anim_state = AnimState.IDLE
				anim_frame = 0
		AnimState.DEATH:
			var max_frames := 3
			if anim_frame >= max_frames:
				set_physics_process(false)

func _update_sprite() -> void:
	var prefix := "thach_sanh_idle"
	var frame := anim_frame
	
	match anim_state:
		AnimState.IDLE:
			prefix = "thach_sanh_idle"
			frame = clampi(anim_frame, 0, 2)
		AnimState.WALK:
			prefix = "thach_sanh_walk"
			frame = clampi(anim_frame, 0, 7)
		AnimState.ATTACK:
			prefix = "thach_sanh_attack"
			frame = clampi(anim_frame, 0, 4)
		AnimState.HURT:
			prefix = "thach_sanh_hurt"
			frame = clampi(anim_frame, 0, 2)
		AnimState.DEATH:
			prefix = "thach_sanh_death"
			frame = clampi(anim_frame, 0, 2)
	
	var path := "res://Assets/player/thach_sanh/%s.png" % prefix
	if not _texture_cache.has(path):
		if ResourceLoader.exists(path):
			_texture_cache[path] = load(path) as Texture2D
		else:
			_texture_cache[path] = null
			
	var tex: Texture2D = _texture_cache[path]
	if tex:
		# Calculate region for the specific frame
		var frame_w := tex.get_width() / _get_total_frames(prefix)
		var frame_h := tex.get_height()
		sprite.texture = tex
		sprite.region_enabled = true
		sprite.region_rect = Rect2(frame * frame_w, 0, frame_w, frame_h)
		sprite.flip_h = not facing_right
		_update_attack_hitbox_position()

func _get_total_frames(prefix: String) -> int:
	match prefix:
		"thach_sanh_idle": return 3
		"thach_sanh_walk": return 8
		"thach_sanh_attack": return 5
		"thach_sanh_hurt": return 3
		"thach_sanh_death": return 3
	return 1

func _on_hitbox_area_entered(area: Area3D) -> void:
	if area is HurtboxComponent:
		var hurtbox := area as HurtboxComponent
		hurtbox.receive_hit(attack_damage, self)
		
		# Play hit sound
		var audio := get_node_or_null("/root/World/AudioManager") as AudioManager
		if audio:
			audio.play_sfx("hit", global_position, 0.1)

func _on_damaged(amount: float, source: Node3D) -> void:
	if anim_state == AnimState.DEATH:
		return
	anim_state = AnimState.HURT
	anim_frame = 0
	anim_timer = 0.0
	invulnerable_timer = invulnerable_duration
	
	# Emit damage event for floating numbers
	EventBus.player_took_damage.emit(amount, global_position)

func _on_died() -> void:
	anim_state = AnimState.DEATH
	anim_frame = 0
	anim_timer = 0.0
	velocity = Vector3.ZERO
	hitbox_area.monitoring = false
	collision_layer = 0
	collision_mask = 0
	print("Player Died!")
	EventBus.player_died.emit()

func _on_health_changed(current: float, max_h: float) -> void:
	# Update HUD
	EventBus.player_health_changed.emit(current, max_h)
