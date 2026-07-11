# player.gd
# NOTE: This file exceeds the 200-line rule (currently ~720 lines).
# Phase 1.6 will refactor it into player_input.gd / player_movement.gd
# / player_animation.gd. Tracked in fix-plan.md under "Phase 1.6 refactor".
class_name Player
extends CharacterBody3D

const PlayerCombatV2 = preload("res://src/player/player_combat_v2.gd")

@export var speed: float = 5.0
@export var acceleration: float = 15.0
@export var deceleration: float = 15.0
@export var gravity: float = 9.8
@export var attack_damage: float = 25.0
@export var attack_range: float = 1.15
@export var max_health: float = 100.0
@export var target_sprite_height: float = 1.9

var input_locked: bool = false

# Runtime velocity direction
var _target_velocity: Vector3 = Vector3.ZERO

# Animation
enum AnimState { IDLE, WALK, ATTACK, HURT, DEATH }
enum MoveDir { DOWN, UP, RIGHT, LEFT, DOWN_RIGHT, DOWN_LEFT, UP_RIGHT, UP_LEFT }

# Combat V2 lives in child component `PlayerCombatV2` to keep player.gd under
# the 200-line rule. Set PlayerCombatV2.enabled = false to revert to legacy
# 2-frame attack timing.
@onready var combat_v2: Node = get_node_or_null("PlayerCombatV2")

const MOVEMENT_IDLE_FRAMES := 2
const MOVEMENT_WALK_FRAMES := 3
const MOVEMENT_FRAME_DIR := "res://Assets/_ThachSanh"
const PLAYER_VISUAL_DIRECTIONS := [
	"down",
	"up",
	"right",
	"left",
	"down_right",
	"down_left",
	"up_right",
	"up_left",
]
const ANIMATION_FRAME_COUNTS := {
	"idle": 2,
	"run": 3,
	"attack": 2,
	"hurt": 1,
	"death": 1,
}
const ATTACK_EFFECT_FRAME_COUNT := 0
const WORLD_RENDER_MASK: int = 1
const COMBAT_ACTOR_RENDER_MASK: int = 2
const PLAYER_ACCENT_RENDER_MASK: int = 4
const MOVE_DIR_NAMES := {
	MoveDir.DOWN: "down",
	MoveDir.UP: "up",
	MoveDir.RIGHT: "right",
	MoveDir.LEFT: "left",
	MoveDir.DOWN_RIGHT: "down_right",
	MoveDir.DOWN_LEFT: "down_left",
	MoveDir.UP_RIGHT: "up_right",
	MoveDir.UP_LEFT: "up_left",
}
const VISUAL_DIR_NAME_OVERRIDES := {
	MoveDir.UP_LEFT: "left",
	MoveDir.UP_RIGHT: "right",
}

var anim_state: AnimState = AnimState.IDLE
var anim_frame: int = 0
var anim_timer: float = 0.0
var anim_fps: float = 6.0
var facing_right: bool = true
var facing_direction: Vector3 = Vector3(0.0, 0.0, 1.0)
var move_direction: MoveDir = MoveDir.DOWN

# Attack
var is_attacking: bool = false
var attack_cooldown: float = 0.0
var attack_window_active: bool = false
var attack_mouse_pos: Vector2 = Vector2.ZERO

# Hurt
var invulnerable_timer: float = 0.0
var invulnerable_duration: float = 0.5

# Speed boost
var _speed_boost_active: bool = false
var _speed_boost_timer: float = 0.0
var _speed_boost_multiplier: float = 1.0
var _base_speed: float = 5.0

# Shield
var _has_shield: bool = false

var _texture_cache: Dictionary = {}
var _last_footprint_pos: Vector3 = Vector3.ZERO
var _footprint_left_side: bool = false
var _sprite_feet_offsets: Dictionary = {}

@onready var health_component: HealthComponent = $HealthComponent
@onready var sprite: Sprite3D = $Visuals/Sprite3D
@onready var attack_effect: Sprite3D = $Visuals/AttackEffect
@onready var hitbox_area: Area3D = $HitboxArea
@onready var hitbox_shape: CollisionShape3D = $HitboxArea/HitboxShape
@onready var movement_dust: MovementDustTrail = $MovementDustTrail
@onready var sprite_animator: PlayerSpriteAnimator = get_node_or_null("SpriteAnimator") as PlayerSpriteAnimator

func _ready() -> void:
	_setup_input_actions()
	_base_speed = speed
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
	sprite.layers = WORLD_RENDER_MASK | COMBAT_ACTOR_RENDER_MASK | PLAYER_ACCENT_RENDER_MASK
	sprite.pixel_size = 0.0086  # Scale sprite to ~1.9m height (221px sprite * 0.0086 = 1.9m)
	sprite.position.z = 0.0  # Set to 0.0 to keep shadow aligned with character feet
	
	if attack_effect:
		attack_effect.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		attack_effect.billboard = StandardMaterial3D.BILLBOARD_FIXED_Y
		attack_effect.shaded = true
		attack_effect.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		attack_effect.alpha_scissor_threshold = 0.12
		attack_effect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		attack_effect.layers = WORLD_RENDER_MASK | COMBAT_ACTOR_RENDER_MASK | PLAYER_ACCENT_RENDER_MASK
		attack_effect.position.z = 0.01  # Slightly in front of the player sprite to prevent z-fighting
		attack_effect.visible = false
	
	# Setup collision (CapsuleShape3D for 1.8m human)
	$CollisionShape3D.shape.height = 1.6
	$CollisionShape3D.position.y = 0.8
	
	# Setup hitbox
	hitbox_area.monitoring = false
	hitbox_area.area_entered.connect(_on_hitbox_area_entered)
	_configure_attack_hitbox()

	# Combat V2 child component
	if combat_v2:
		combat_v2.bind(self)

	prewarm_visual_assets()
	_update_sprite()

func prewarm_visual_assets() -> void:
	if sprite_animator != null and sprite_animator.prewarm():
		return

	# Legacy frames remain a fallback for projects that omit the V2 animator.
	for dir_name: String in PLAYER_VISUAL_DIRECTIONS:
		for anim_name: String in ANIMATION_FRAME_COUNTS:
			var folder := "hurt" if anim_name == "death" else anim_name
			var suffix := "hurt" if anim_name == "death" else anim_name
			var frame_count: int = ANIMATION_FRAME_COUNTS[anim_name]
			for frame_index in range(frame_count):
				var path := "%s/%s/%s_%s_%d.png" % [
					MOVEMENT_FRAME_DIR, folder, dir_name, suffix, frame_index,
				]
				_cache_texture(path)

func _cache_texture(tex_path: String) -> Texture2D:
	if _texture_cache.has(tex_path):
		return _texture_cache[tex_path] as Texture2D

	if not ResourceLoader.exists(tex_path):
		_texture_cache[tex_path] = null
		return null

	var loaded_tex := load(tex_path) as Texture2D
	_texture_cache[tex_path] = loaded_tex
	_cache_sprite_feet_offset(loaded_tex)
	return loaded_tex

func _cache_sprite_feet_offset(tex: Texture2D) -> void:
	if tex == null or _sprite_feet_offsets.has(tex):
		return

	var img := tex.get_image()
	if img == null:
		_sprite_feet_offsets[tex] = 0.0
		return

	var rect := img.get_used_rect()
	var frame_h := tex.get_height()
	_sprite_feet_offsets[tex] = (rect.position.y + rect.size.y) - (frame_h / 2.0)

func _configure_attack_hitbox() -> void:
	var box := hitbox_shape.shape as BoxShape3D
	if box == null:
		box = BoxShape3D.new()
		hitbox_shape.shape = box
	box.size = Vector3(maxf(0.55, attack_range * 0.55), 1.0, 0.85)
	_update_attack_hitbox_position()

func _update_attack_hitbox_position() -> void:
	var snapped_dir := Vector2(facing_direction.x, facing_direction.z)
	if snapped_dir == Vector2.ZERO:
		snapped_dir = Vector2(1.0, 0.0) if facing_right else Vector2(-1.0, 0.0)
	snapped_dir = snapped_dir.normalized()
	hitbox_shape.position = Vector3(
		snapped_dir.x * attack_range * 0.45,
		0.9,
		snapped_dir.y * attack_range * 0.45
	)

func _set_facing_from_world_direction(dir: Vector3) -> void:
	var planar_dir := Vector3(dir.x, 0.0, dir.z)
	if planar_dir.length_squared() <= 0.0001:
		return
	facing_direction = _snap_direction_to_octant(planar_dir.normalized())
	move_direction = _get_move_direction_from_visual_direction(facing_direction)
	_update_facing_side_from_camera(facing_direction)

func _snap_direction_to_octant(dir: Vector3) -> Vector3:
	var angle: float = atan2(dir.z, dir.x)
	var snapped_angle: float = round(angle / (PI / 4.0)) * (PI / 4.0)
	return Vector3(cos(snapped_angle), 0.0, sin(snapped_angle)).normalized()

func _get_move_direction_from_visual_direction(dir: Vector3) -> MoveDir:
	var screen_dir := _get_camera_relative_screen_direction(dir)
	var x_positive := screen_dir.x > 0.25
	var x_negative := screen_dir.x < -0.25
	var y_positive := screen_dir.y > 0.25
	var y_negative := screen_dir.y < -0.25

	if x_positive and y_positive:
		return MoveDir.DOWN_RIGHT
	if x_negative and y_positive:
		return MoveDir.DOWN_LEFT
	if x_positive and y_negative:
		return MoveDir.UP_RIGHT
	if x_negative and y_negative:
		return MoveDir.UP_LEFT
	if x_positive:
		return MoveDir.RIGHT
	if x_negative:
		return MoveDir.LEFT
	if y_negative:
		return MoveDir.UP
	return MoveDir.DOWN

func _get_visual_dir_name(dir: MoveDir) -> String:
	# Hướng chéo lên ưu tiên silhouette trái/phải để input W+A/W+D không nhìn ngược hướng.
	return VISUAL_DIR_NAME_OVERRIDES.get(dir, MOVE_DIR_NAMES.get(dir, "down"))

func _get_camera_relative_screen_direction(dir: Vector3) -> Vector2:
	var planar_dir := Vector3(dir.x, 0.0, dir.z)
	if planar_dir.length_squared() <= 0.0001:
		return Vector2.ZERO
	planar_dir = planar_dir.normalized()

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector2(planar_dir.x, planar_dir.z)

	var cam_forward := -camera.global_transform.basis.z
	var cam_right := camera.global_transform.basis.x
	cam_forward.y = 0.0
	cam_right.y = 0.0
	cam_forward = cam_forward.normalized()
	cam_right = cam_right.normalized()
	return Vector2(planar_dir.dot(cam_right), -planar_dir.dot(cam_forward))

func _update_facing_side_from_camera(dir: Vector3) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		facing_right = dir.x >= 0.0
		return
	var cam_right := camera.global_transform.basis.x
	cam_right.y = 0.0
	cam_right = cam_right.normalized()
	var side_dot := dir.dot(cam_right)
	if absf(side_dot) > 0.05:
		facing_right = side_dot >= 0.0

func _setup_input_actions() -> void:
	_ensure_key_action(&"move_left", KEY_A)
	_ensure_key_action(&"move_right", KEY_D)
	_ensure_key_action(&"move_up", KEY_W)
	_ensure_key_action(&"move_down", KEY_S)
	if not InputMap.has_action(&"attack"):
		InputMap.add_action(&"attack")
	if InputMap.action_get_events(&"attack").is_empty():
		_add_key_event(&"attack", KEY_SPACE)
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event(&"attack", mouse_event)


func _ensure_key_action(action: StringName, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if InputMap.action_get_events(action).is_empty():
		_add_key_event(action, keycode)


func _add_key_event(action: StringName, keycode: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	InputMap.action_add_event(action, event)


func _unhandled_input(event: InputEvent) -> void:
	if input_locked:
		return
	if anim_state == AnimState.DEATH:
		return
	if not event.is_action_pressed(&"attack"):
		return
	# Combat V2: chain attack if buffer was set during previous recovery
	if combat_v2 and combat_v2.enabled and combat_v2.consume_recovery_buffer():
		_start_attack()
		return

	# Combat V2: buffer the press during non-cancelable phase
	if combat_v2 and combat_v2.enabled and is_attacking:
		combat_v2.try_buffer_input()
		return

	if is_attacking or attack_cooldown > 0.0:
		return
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

	# Speed boost timer
	if _speed_boost_active:
		_speed_boost_timer -= delta
		if _speed_boost_timer <= 0.0:
			_speed_boost_active = false
			_speed_boost_multiplier = 1.0
			speed = _base_speed

	# Combat V2: drive 3-phase attack state machine + IASA cancel
	if combat_v2 and combat_v2.enabled and combat_v2.tick(delta):
		_process_animation(delta)
		move_and_slide()
		return
	
	# Don't process movement during attack or death
	if anim_state == AnimState.ATTACK or anim_state == AnimState.DEATH:
		_process_animation(delta)
		move_and_slide()
		return
	
	# Add gravity if not on ground
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Get input direction
	var input_vector := Vector2.ZERO
	if not input_locked:
		input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := _get_camera_relative_direction(input_vector)

	if direction != Vector3.ZERO:
		var current_speed := speed * _speed_boost_multiplier
		_target_velocity.x = direction.x * current_speed
		_target_velocity.z = direction.z * current_speed
		
		_set_facing_from_world_direction(direction)
		
		# Smooth acceleration
		velocity.x = move_toward(velocity.x, _target_velocity.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, _target_velocity.z, acceleration * delta)
		
		if anim_state != AnimState.WALK:
			anim_state = AnimState.WALK
			_last_footprint_pos = Vector3(9999.0, 9999.0, 9999.0)
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
	
	# Snap visuals to actual physics collision ground height to prevent floating/shadow gaps.
	# The ForestBuilder now exposes the same heightmap that the collision uses, so we
	# can read ground height directly (no raycast guesswork) and keep visuals aligned.
	var visuals_node := get_node_or_null("Visuals") as Node3D
	if visuals_node and is_inside_tree():
		var forest := get_parent().get_node_or_null("Forest")
		if forest and forest.has_method("_get_hill_height"):
			var terrain_h: float = forest._get_hill_height(global_position.x, global_position.z)
			# ForestBuilder.Zone.PATH == 2. Grass zones lift the sprite +0.2m so
			# the sprite feet visually touch the heightmap top.
			var base_h: float = 0.2
			if forest.has_method("_get_zone"):
				var zone_value: int = int(forest._get_zone(global_position.x, global_position.z))
				if zone_value == 2:
					base_h = 0.0
			visuals_node.global_position.y = terrain_h + base_h
		else:
			visuals_node.global_position.y = global_position.y
	elif visuals_node:
		visuals_node.position.y = 0.0
			
	_process_animation(delta)
	_handle_footprints(delta)

func _handle_footprints(_delta: float) -> void:
	if anim_state != AnimState.WALK:
		return
	if global_position.distance_to(_last_footprint_pos) < 0.7:
		return
	var fp := Footprint.new()
	get_parent().add_child(fp)

	# Compute right direction based on sprite flip state, not raw facing_direction.
	# This ensures footprint alignment stays consistent when player strafes.
	var right_dir: Vector3
	if facing_right:
		right_dir = Vector3(facing_direction.z, 0.0, -facing_direction.x).normalized()
	else:
		right_dir = Vector3(-facing_direction.z, 0.0, facing_direction.x).normalized()

	if right_dir == Vector3.ZERO:
		right_dir = Vector3.RIGHT if facing_right else Vector3.LEFT

	var offset_side := 0.12 if _footprint_left_side else -0.12
	_footprint_left_side = not _footprint_left_side
	var fp_pos := global_position + right_dir * offset_side
	var visuals_node := get_node_or_null("Visuals") as Node3D
	if visuals_node:
		fp_pos.y = visuals_node.global_position.y + 0.02
	else:
		fp_pos.y = global_position.y + 0.02
	fp.global_position = fp_pos

	# Rotation aligned with movement direction for dust sprites.
	var move_y_rad := atan2(facing_direction.z, facing_direction.x)
	if movement_dust != null:
		movement_dust.spawn_at(fp_pos, move_y_rad)
	_last_footprint_pos = global_position
	
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal("player_stepped"):
		event_bus.player_stepped.emit(fp_pos)

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
	var audio := get_tree().get_first_node_in_group("audio_manager") as AudioManager
	if audio:
		audio.play_sfx("sword_swing", global_position, 0.15)

	_update_attack_hitbox_position()

	if combat_v2 and combat_v2.enabled:
		combat_v2.on_attack_started(anim_fps, _get_animation_frame_count("attack"))

func _interrupt_attack(reset_cooldown: bool = false) -> void:
	if not is_attacking and not hitbox_area.monitoring:
		return
	is_attacking = false
	attack_window_active = false
	hitbox_area.monitoring = false
	if reset_cooldown:
		attack_cooldown = maxf(attack_cooldown, 0.3)

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
	
	# V2 attack has wind-up, strike, impact, recover; legacy keeps the old 2-frame timing.
	if anim_state == AnimState.ATTACK:
		hitbox_area.monitoring = _is_attack_damage_frame(anim_frame)
	
	_update_sprite()

func _check_animation_end() -> void:
	match anim_state:
		AnimState.IDLE:
			var max_frames := _get_animation_frame_count("idle")
			if anim_frame >= max_frames:
				anim_frame = 0
		AnimState.WALK:
			var max_frames := _get_animation_frame_count("run")
			if anim_frame >= max_frames:
				anim_frame = 0
		AnimState.ATTACK:
			var max_frames := _get_animation_frame_count("attack")
			if anim_frame >= max_frames:
				is_attacking = false
				anim_state = AnimState.IDLE
				anim_frame = 0
				attack_cooldown = 0.3
				hitbox_area.monitoring = false
		AnimState.HURT:
			var max_frames := _get_animation_frame_count("hurt")
			if anim_frame >= max_frames:
				anim_state = AnimState.IDLE
				anim_frame = 0
		AnimState.DEATH:
			var max_frames := _get_animation_frame_count("death")
			if anim_frame >= max_frames:
				set_physics_process(false)

func _get_animation_frame_count(anim_name: String) -> int:
	if sprite_animator != null and sprite_animator.has_animation(anim_name):
		return sprite_animator.get_frame_count(anim_name)
	return int(ANIMATION_FRAME_COUNTS.get(anim_name, 1))

func _is_attack_damage_frame(frame_index: int) -> bool:
	if _get_animation_frame_count("attack") >= 6:
		return frame_index == 3 or frame_index == 4
	return frame_index == 1

func _update_sprite() -> void:
	var frame_count := 1
	var folder := "idle"
	var suffix := "idle"
	
	match anim_state:
		AnimState.IDLE:
			frame_count = 2
			folder = "idle"
			suffix = "idle"
		AnimState.WALK:
			frame_count = 3
			folder = "run"
			suffix = "run"
		AnimState.ATTACK:
			frame_count = 2
			folder = "attack"
			suffix = "attack"
		AnimState.HURT:
			frame_count = 1
			folder = "hurt"
			suffix = "hurt"
		AnimState.DEATH:
			frame_count = 1
			folder = "hurt"
			suffix = "hurt"

	frame_count = _get_animation_frame_count(suffix)
	var clamped_frame := clampi(anim_frame, 0, frame_count - 1)
	var dir_name := _get_visual_dir_name(move_direction)
	if sprite_animator != null and sprite_animator.apply_to_sprite(sprite, suffix, clamped_frame, dir_name, target_sprite_height):
		if attack_effect:
			attack_effect.visible = false
		_update_attack_hitbox_position()
		return

	frame_count = int(ANIMATION_FRAME_COUNTS.get(suffix, frame_count))
	clamped_frame = clampi(anim_frame, 0, frame_count - 1)
	var tex_path := "%s/%s/%s_%s_%d.png" % [MOVEMENT_FRAME_DIR, folder, dir_name, suffix, clamped_frame]
	
	var tex := _cache_texture(tex_path)
	if tex == null:
		# Fallback to down direction if specific direction is missing
		var fallback_path := "%s/%s/down_%s_%d.png" % [MOVEMENT_FRAME_DIR, folder, suffix, clamped_frame]
		tex = _cache_texture(fallback_path)

	if tex == null:
		return

	sprite.texture = tex
	sprite.region_enabled = false
	sprite.flip_h = false
	sprite.centered = true  # Pivot ở giữa quad (centered = local 0,0)

	var frame_h := tex.get_height()
	sprite.pixel_size = target_sprite_height / frame_h

	# Đặt sprite sao cho CHÂN NHÂN VẬT (used_rect bottom) chạm world Y = 0 (mặt đất),
	# dùng offset đã cache để tránh đọc lại image data trong lúc chơi.
	var feet_offset_rows: float = _sprite_feet_offsets.get(tex, 0.0)
	var visuals_node := sprite.get_parent() as Node3D
	var visuals_global_y := visuals_node.global_position.y if visuals_node else 0.0
	sprite.position.y = -visuals_global_y + feet_offset_rows * sprite.pixel_size
	
	# Update attack effect visibility and texture
	if attack_effect:
		attack_effect.visible = false
			
	_update_attack_hitbox_position()

const CRIT_CHANCE: float = 0.15
const CRIT_MULTIPLIER: float = 2.0

func _on_hitbox_area_entered(area: Area3D) -> void:
	if area is HurtboxComponent:
		var hurtbox := area as HurtboxComponent
		var is_critical := randf() < CRIT_CHANCE
		var final_damage := attack_damage * CRIT_MULTIPLIER if is_critical else attack_damage
		hurtbox.receive_hit(final_damage, self, is_critical)

func _on_damaged(amount: float, source: Node3D, is_critical: bool = false) -> void:
	if anim_state == AnimState.DEATH:
		return

	# Shield absorbs one hit
	if _has_shield:
		_has_shield = false
		EventBus.player_shield_broken.emit()
		return

	# C5: punish committing an attack into an incoming hit. PlayerCombatV2
	# owns the canonical "is actively attacking" check; falls back to flag.
	var was_attacking := is_attacking
	var final_damage: float = amount
	if combat_v2 and combat_v2.enabled:
		was_attacking = was_attacking or combat_v2.should_apply_interrupt_penalty()
	if was_attacking:
		final_damage *= PlayerCombatV2.COMBAT_V2_INTERRUPT_DAMAGE_MULT

	_interrupt_attack()
	if combat_v2:
		combat_v2.on_attack_interrupted()
	anim_state = AnimState.HURT
	anim_frame = 0
	anim_timer = 0.0
	invulnerable_timer = invulnerable_duration

	# Emit damage event for floating numbers (use penalized amount so player sees it)
	EventBus.player_took_damage.emit(final_damage, global_position)


func apply_speed_boost(multiplier: float, duration: float) -> void:
	_speed_boost_active = true
	_speed_boost_timer = duration
	_speed_boost_multiplier = 1.0 + multiplier
	speed = _base_speed * _speed_boost_multiplier


func apply_shield() -> void:
	_has_shield = true


func _on_died() -> void:
	_interrupt_attack()
	anim_state = AnimState.DEATH
	anim_frame = 0
	anim_timer = 0.0
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	print("Player Died!")
	EventBus.player_died.emit()

func _on_health_changed(current: float, max_h: float) -> void:
	# Update HUD
	EventBus.player_health_changed.emit(current, max_h)
