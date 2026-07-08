# world_slime.gd
# Passive ambient slime — 4 colors, hops randomly, flees player within 5m.
# Uses AnimatedSprite3D with GIF sprite frames loaded by WorldSlimeManager.
# 1 HP: damaged → hurt anim 0.3s → queue_free.
class_name WorldSlime
extends CharacterBody3D

const FLEE_RANGE_SQ: float = 25.0
const FLEE_SPEED_MULT: float = 1.5
const IDLE_DURATION_RANGE := Vector2(3.0, 8.0)
const WANDER_DURATION_RANGE := Vector2(3.0, 8.0)
const HOP_CYCLE_SECONDS: float = 0.6
const HURT_DURATION: float = 0.3
const HOP_LIFT_Y: float = 0.45
const HOP_SQUASH_XZ := 1.2
const HOP_SQUASH_Y := 0.8
const HOP_STRETCH_XZ := 0.9
const HOP_STRETCH_Y := 1.1
const IDLE_SQUASH_AMPLITUDE: float = 0.125
const IDLE_CYCLE_SECONDS: float = 1.5
const HURT_SQUASH_AMPLITUDE: float = 0.3
const TARGET_VISIBLE_HEIGHT: float = 0.53

enum State { IDLE, WANDER, FLEE, HURT }
enum MoveDir { DOWN, UP, LEFT, RIGHT }

@export var speed: float = 1.2
@export var gravity: float = 9.8

@onready var sprite: AnimatedSprite3D = $Sprite3D
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var health_component: HealthComponent = $HealthComponent
@onready var manager: WorldSlimeManager = get_parent() as WorldSlimeManager

var current_state: State = State.IDLE
var state_timer: float = 0.0
var active_time: float = 0.0
var move_direction: Vector3 = Vector3.ZERO
var current_dir: MoveDir = MoveDir.DOWN
var color_key: String = ""
var _active: bool = true
# Set by WorldSlimeManager._instantiate_slime() before children attach.
var _color_key: String = ""


func _ready() -> void:
	add_to_group("slime_mobs")
	if manager == null:
		manager = get_parent() as WorldSlimeManager
	color_key = String(_color_key) if _color_key != null else "green"
	_setup_health()
	current_state = State.WANDER
	state_timer = randf_range(WANDER_DURATION_RANGE.x, WANDER_DURATION_RANGE.y)
	_choose_wander_direction()
	_apply_sprite_baseline()


func _setup_health() -> void:
	if health_component:
		health_component.max_health = 1.0
		health_component.current_health = 1.0
		health_component.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	if not _active:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	active_time += delta
	state_timer -= delta

	match current_state:
		State.IDLE:
			_apply_idle_anim()
		State.WANDER:
			_apply_motion_towards(move_direction, speed, delta)
			_apply_hop_anim()
			if state_timer <= 0.0:
				_enter_idle()
		State.FLEE:
			var flee_dir := _compute_flee_direction()
			if flee_dir == Vector3.ZERO:
				_enter_wander()
			else:
				_apply_motion_towards(flee_dir, speed * FLEE_SPEED_MULT, delta)
			_apply_hop_anim()
		State.HURT:
			_apply_hurt_anim()
			if state_timer <= 0.0:
				queue_free()

	move_and_slide()


func _apply_idle_anim() -> void:
	var t: float = fposmod(active_time, IDLE_CYCLE_SECONDS) / IDLE_CYCLE_SECONDS
	var squash_factor: float = sin(t * TAU) * IDLE_SQUASH_AMPLITUDE
	sprite.scale = Vector3(1.0 + squash_factor, 1.0 - squash_factor, 1.0 + squash_factor)


func _apply_motion_towards(dir: Vector3, magnitude: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, dir.x * magnitude, magnitude * delta)
	velocity.z = move_toward(velocity.z, dir.z * magnitude, magnitude * delta)
	_update_dir_from_motion()


func _compute_flee_direction() -> Vector3:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return Vector3.ZERO
	var away := global_position - player.global_position
	away.y = 0.0
	var dist_sq := away.length_squared()
	if dist_sq > FLEE_RANGE_SQ * 4.0:
		return Vector3.ZERO
	return away.normalized() if dist_sq > 0.0001 else Vector3.ZERO


func _apply_hop_anim() -> void:
	var cycle_pos: float = fposmod(active_time, HOP_CYCLE_SECONDS) / HOP_CYCLE_SECONDS
	var baseline_y := _get_baseline_y()
	if cycle_pos < 0.25:
		sprite.scale = Vector3(HOP_SQUASH_XZ, HOP_SQUASH_Y, HOP_SQUASH_XZ)
		sprite.position.y = baseline_y - 0.05
	elif cycle_pos < 0.67:
		sprite.scale = Vector3(HOP_STRETCH_XZ, HOP_STRETCH_Y, HOP_STRETCH_XZ)
		sprite.position.y = baseline_y + HOP_LIFT_Y
	else:
		sprite.scale = Vector3.ONE
		sprite.position.y = baseline_y


func _apply_hurt_anim() -> void:
	var t: float = clampf(state_timer / HURT_DURATION, 0.0, 1.0)
	var squash: float = (1.0 - t) * HURT_SQUASH_AMPLITUDE
	sprite.scale = Vector3(1.0 - squash, 1.0 + squash, 1.0 - squash)
	sprite.position.y = _get_baseline_y()


func _enter_idle() -> void:
	current_state = State.IDLE
	state_timer = randf_range(IDLE_DURATION_RANGE.x, IDLE_DURATION_RANGE.y)


func _enter_wander() -> void:
	current_state = State.WANDER
	state_timer = randf_range(WANDER_DURATION_RANGE.x, WANDER_DURATION_RANGE.y)
	_choose_wander_direction()


func _choose_wander_direction() -> void:
	var angle := randf_range(0.0, TAU)
	move_direction = Vector3(cos(angle), 0.0, sin(angle)).normalized()


func _update_dir_from_motion() -> void:
	var v := Vector3(velocity.x, 0.0, velocity.z)
	if v.length_squared() < 0.01:
		return
	var prev_dir := current_dir
	if absf(v.x) > absf(v.z):
		current_dir = MoveDir.RIGHT if v.x > 0.0 else MoveDir.LEFT
	else:
		current_dir = MoveDir.DOWN if v.z > 0.0 else MoveDir.UP
	if current_dir != prev_dir:
		_apply_direction_anim()


func _apply_direction_anim() -> void:
	if sprite == null or manager == null:
		return
	var frames: SpriteFrames = manager.get_or_load_sprite_frames(color_key, current_dir)
	if frames == null:
		return
	sprite.flip_h = current_dir == MoveDir.RIGHT
	if sprite.sprite_frames != frames:
		sprite.sprite_frames = frames
		sprite.play("default")


func _apply_sprite_baseline() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var first_frame := sprite.sprite_frames.get_frame_texture("default", 0)
	if first_frame == null:
		return
	sprite.pixel_size = TARGET_VISIBLE_HEIGHT / float(first_frame.get_height())
	sprite.position.y = _get_baseline_y()
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.shaded = true
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.play("default")


func _get_baseline_y() -> float:
	var forest := get_parent().get_node_or_null("Forest")
	if forest and forest.has_method("_get_hill_height"):
		var terrain_h: float = forest._get_hill_height(global_position.x, global_position.z)
		var base: float = 0.28
		if forest.has_method("_get_zone"):
			var zone_value: int = int(forest._get_zone(global_position.x, global_position.z))
			if zone_value == 2:
				base = 0.08
		return terrain_h + base
	return 0.28


func _on_died() -> void:
	if current_state == State.HURT or sprite == null or manager == null:
		return
	current_state = State.HURT
	state_timer = HURT_DURATION
	velocity = Vector3.ZERO
	var hurt_frames: SpriteFrames = manager.build_hurt_sprite_frames(color_key)
	if hurt_frames == null:
		return
	sprite.sprite_frames = hurt_frames
	sprite.flip_h = false
	sprite.play("default")
