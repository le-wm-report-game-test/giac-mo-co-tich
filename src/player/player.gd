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
@export var target_sprite_height: float = 1.9

# Runtime velocity direction
var _target_velocity: Vector3 = Vector3.ZERO

# Animation
enum AnimState { IDLE, WALK, ATTACK, HURT, DEATH }
enum MoveDir { DOWN, UP, RIGHT, LEFT, DOWN_RIGHT, DOWN_LEFT, UP_RIGHT, UP_LEFT }

const MOVEMENT_IDLE_FRAMES := 3
const MOVEMENT_WALK_FRAMES := 8
const MOVEMENT_FRAME_DIR := "res://Assets/player/thach_sanh/movement_frames"
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

var _texture_cache: Dictionary = {}
var _last_footprint_pos: Vector3 = Vector3.ZERO
var _footprint_left_side: bool = false
var dust_particles: CPUParticles3D = null
var _sprite_feet_offsets: Dictionary = {}

@onready var health_component: HealthComponent = $HealthComponent
@onready var sprite: Sprite3D = $Visuals/Sprite3D
@onready var attack_effect: Sprite3D = $Visuals/AttackEffect
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
	
	# Initialize movement dust particles
	dust_particles = CPUParticles3D.new()
	dust_particles.name = "DustParticles"
	
	# Mesh: Small retro cube
	var d_mesh := BoxMesh.new()
	d_mesh.size = Vector3(0.04, 0.04, 0.04)
	
	var d_mat := StandardMaterial3D.new()
	d_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	d_mat.vertex_color_use_as_albedo = true
	d_mesh.material = d_mat
	
	dust_particles.mesh = d_mesh
	dust_particles.amount = 16
	dust_particles.lifetime = 0.8
	dust_particles.local_coords = false # trail stays stationary in world space
	
	# Light upward and backward drift
	dust_particles.direction = Vector3.UP
	dust_particles.spread = 30.0
	dust_particles.gravity = Vector3(0, 0.15, 0)
	dust_particles.initial_velocity_min = 0.3
	dust_particles.initial_velocity_max = 0.6
	
	# Color gradient: Soft grey-beige fading to transparent
	var d_gradient := Gradient.new()
	d_gradient.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	d_gradient.colors = PackedColorArray([
		Color("#D9CBBC", 0.5), # Soft grey-beige
		Color("#CFC0AF", 0.3), # Fading grey-beige
		Color(0.85, 0.78, 0.72, 0.0) # Transparent
	])
	dust_particles.color_ramp = d_gradient
	
	# Scale curve: Shrink dust as it fades
	var d_curve := Curve.new()
	d_curve.add_point(Vector2(0.0, 1.0))
	d_curve.add_point(Vector2(1.0, 0.0))
	dust_particles.scale_amount_curve = d_curve
	
	# Setup position at feet and add to scene
	dust_particles.position = Vector3(0.0, 0.02, 0.0)
	dust_particles.emitting = false
	add_child(dust_particles)
	
	_update_sprite()

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
	move_direction = _get_move_direction_from_facing(facing_direction)
	_update_facing_side_from_camera(facing_direction)

func _snap_direction_to_octant(dir: Vector3) -> Vector3:
	var angle: float = atan2(dir.z, dir.x)
	var snapped_angle: float = round(angle / (PI / 4.0)) * (PI / 4.0)
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
	
	# Snap visuals to actual physics collision ground height to prevent floating/shadow gaps
	var visuals_node := get_node_or_null("Visuals") as Node3D
	if visuals_node and is_inside_tree():
		var space_state := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(
			global_position + Vector3(0.0, 1.0, 0.0),
			global_position + Vector3(0.0, -1.0, 0.0),
			1 # Collide with ground layer
		)
		var result := space_state.intersect_ray(query)
		if result:
			var base_y = result.position.y
			var offset_y = 0.0
			var forest := get_parent().get_node_or_null("Forest")
			if forest and forest.has_method("_get_zone"):
				var zone = forest._get_zone(global_position.x, global_position.z)
				var is_path = (zone == 2) # Zone.PATH is 2
				if not is_path:
					offset_y = 0.2
			visuals_node.global_position.y = base_y + offset_y
		else:
			# Fallback: check forest heightmap if raycast misses, adding visual offsets
			var forest := get_parent().get_node_or_null("Forest")
			if forest and forest.has_method("_get_hill_height"):
				var height_offset: float = forest._get_hill_height(global_position.x, global_position.z)
				var zone = forest._get_zone(global_position.x, global_position.z) if forest.has_method("_get_zone") else 0
				# 2 corresponds to Zone.PATH. All other zones are grass-based (offset +0.2m)
				var base_h := 0.0 if zone == 2 else 0.2
				visuals_node.global_position.y = height_offset + base_h
			else:
				visuals_node.position.y = 0.0
	elif visuals_node:
		visuals_node.position.y = 0.0
			
	# Update dust particle emission based on movement state
	if is_instance_valid(dust_particles):
		dust_particles.emitting = (anim_state == AnimState.WALK)
	
	_process_animation(delta)
	_handle_footprints(delta)

func _handle_footprints(_delta: float) -> void:
	if anim_state != AnimState.WALK:
		return
	if global_position.distance_to(_last_footprint_pos) < 0.7:
		return
	var fp := Footprint.new()
	get_parent().add_child(fp)
	var right_dir := Vector3(facing_direction.z, 0.0, -facing_direction.x).normalized()
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
			_set_facing_from_world_direction(diff)
	_update_attack_hitbox_position()

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
	
	# Enable hitbox during specific attack frame (frame index 2 is the strike point in 4-frame animation)
	if anim_state == AnimState.ATTACK:
		hitbox_area.monitoring = (anim_frame == 2)
	
	_update_sprite()

func _check_animation_end() -> void:
	match anim_state:
		AnimState.IDLE:
			var max_frames := 3
			if anim_frame >= max_frames:
				anim_frame = 0
		AnimState.WALK:
			var max_frames := MOVEMENT_WALK_FRAMES
			if anim_frame >= max_frames:
				anim_frame = 0
		AnimState.ATTACK:
			var max_frames := 4
			if anim_frame >= max_frames:
				is_attacking = false
				anim_state = AnimState.IDLE
				anim_frame = 0
				attack_cooldown = 0.3
				hitbox_area.monitoring = false
		AnimState.HURT:
			var max_frames := 4
			if anim_frame >= max_frames:
				anim_state = AnimState.IDLE
				anim_frame = 0
		AnimState.DEATH:
			var max_frames := 4
			if anim_frame >= max_frames:
				set_physics_process(false)

func _update_sprite() -> void:
	var frame_count := 1
	var anim_name := "idle"
	
	match anim_state:
		AnimState.IDLE:
			frame_count = 3
			anim_name = "idle"
		AnimState.WALK:
			frame_count = 8
			anim_name = "walk"
		AnimState.ATTACK:
			frame_count = 4
			anim_name = "attack"
		AnimState.HURT:
			frame_count = 4
			anim_name = "hurt"
		AnimState.DEATH:
			frame_count = 4
			anim_name = "death"

	var clamped_frame := clampi(anim_frame, 0, frame_count - 1)
	var dir_name: String = MOVE_DIR_NAMES.get(move_direction, "down")
	var tex_path := "%s/%s_%s_%d.png" % [MOVEMENT_FRAME_DIR, dir_name, anim_name, clamped_frame]
	
	if not _texture_cache.has(tex_path):
		if ResourceLoader.exists(tex_path):
			var loaded_tex := load(tex_path) as Texture2D
			_texture_cache[tex_path] = loaded_tex
			if loaded_tex:
				var img := loaded_tex.get_image()
				if img:
					var rect := img.get_used_rect()
					var fh := loaded_tex.get_height()
					_sprite_feet_offsets[loaded_tex] = (rect.position.y + rect.size.y) - (fh / 2.0)
				else:
					_sprite_feet_offsets[loaded_tex] = 0.0
		else:
			_texture_cache[tex_path] = null

	var tex: Texture2D = _texture_cache[tex_path]
	if tex == null:
		# Fallback to down direction if specific direction is missing
		var fallback_path := "%s/down_%s_%d.png" % [MOVEMENT_FRAME_DIR, anim_name, clamped_frame]
		if not _texture_cache.has(fallback_path):
			if ResourceLoader.exists(fallback_path):
				var loaded_tex := load(fallback_path) as Texture2D
				_texture_cache[fallback_path] = loaded_tex
				if loaded_tex:
					var img := loaded_tex.get_image()
					if img:
						var rect := img.get_used_rect()
						var fh := loaded_tex.get_height()
						_sprite_feet_offsets[loaded_tex] = (rect.position.y + rect.size.y) - (fh / 2.0)
					else:
						_sprite_feet_offsets[loaded_tex] = 0.0
			else:
				_texture_cache[fallback_path] = null
		tex = _texture_cache[fallback_path]

	if tex == null:
		return

	sprite.texture = tex
	sprite.region_enabled = false
	sprite.flip_h = false
	
	var frame_h := tex.get_height()
	sprite.pixel_size = target_sprite_height / frame_h
	
	# Position the player's actual feet exactly on the floor by checking the bottom-most active pixel
	var feet_offset_px: float = 0.0
	if _sprite_feet_offsets.has(tex):
		feet_offset_px = _sprite_feet_offsets[tex]
	else:
		var img := tex.get_image()
		if img:
			var rect := img.get_used_rect()
			feet_offset_px = (rect.position.y + rect.size.y) - (frame_h / 2.0)
			_sprite_feet_offsets[tex] = feet_offset_px
		else:
			_sprite_feet_offsets[tex] = 0.0
			
	sprite.position.y = feet_offset_px * sprite.pixel_size
	
	# Update attack effect visibility and texture
	if attack_effect:
		if anim_state == AnimState.ATTACK and (clamped_frame == 2 or clamped_frame == 3):
			var effect_frame := clamped_frame - 2  # frame 2 -> effect 0, frame 3 -> effect 1
			var eff_path := "%s/%s_effect_%d.png" % [MOVEMENT_FRAME_DIR, dir_name, effect_frame]
			if not _texture_cache.has(eff_path):
				if ResourceLoader.exists(eff_path):
					_texture_cache[eff_path] = load(eff_path) as Texture2D
				else:
					_texture_cache[eff_path] = null
			
			var eff_tex: Texture2D = _texture_cache[eff_path]
			if eff_tex:
				attack_effect.texture = eff_tex
				attack_effect.region_enabled = false
				attack_effect.flip_h = false
				var eff_h := eff_tex.get_height()
				attack_effect.pixel_size = target_sprite_height / eff_h
				attack_effect.position.y = sprite.position.y # align with player height
				attack_effect.visible = true
			else:
				attack_effect.visible = false
		else:
			attack_effect.visible = false
			
	_update_attack_hitbox_position()

func _on_hitbox_area_entered(area: Area3D) -> void:
	if area is HurtboxComponent:
		var hurtbox := area as HurtboxComponent
		hurtbox.receive_hit(attack_damage, self)

func _on_damaged(amount: float, source: Node3D) -> void:
	if anim_state == AnimState.DEATH:
		return
	_interrupt_attack()
	anim_state = AnimState.HURT
	anim_frame = 0
	anim_timer = 0.0
	invulnerable_timer = invulnerable_duration
	
	# Emit damage event for floating numbers
	EventBus.player_took_damage.emit(amount, global_position)

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
