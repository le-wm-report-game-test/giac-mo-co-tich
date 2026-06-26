# orc_mob.gd
class_name OrcMob
extends CharacterBody3D

enum State { IDLE, WANDER, CHASE, ATTACK, HURT, DEATH }

@export var speed: float = 2.0
@export var gravity: float = 9.8
@export var detection_range: float = 12.0
@export var attack_range: float = 1.05
@export var attack_cooldown_time: float = 1.5
@export var max_health: float = 50.0
@export var sprite_pixel_size: float = 0.014
@export var attack_damage: float = 10.0:
	set(val):
		attack_damage = val
		if hitbox_component:
			hitbox_component.damage = val

var current_state: State = State.IDLE
var state_timer: float = 0.0
var wander_direction: Vector3 = Vector3.ZERO
var attack_cooldown_timer: float = 0.0
var frame_timer: float = 0.0
var current_frame: int = 0
var anim_fps: float = 6.0
var strafe_dir: float = 1.0
var facing_right: bool = true

var candidate_directions: Array[Vector3] = []
var _texture_cache: Dictionary = {}
var sprite: Sprite3D
var health_component: HealthComponent
var hurtbox_component: HurtboxComponent
var hitbox_component: HitboxComponent
var hitbox_col: CollisionShape3D

func _ready() -> void:
	# Giữ physics node ở scale 1; chỉ scale Sprite3D bằng pixel_size để hitbox không bị phóng đại.
	scale = Vector3.ONE
	if is_in_group("boss"):
		sprite_pixel_size = maxf(sprite_pixel_size, 0.026)
		attack_range = maxf(attack_range, 1.65)
	add_to_group("orc_mobs")
	strafe_dir = 1.0 if randf() > 0.5 else -1.0
	for i in range(8):
		var angle := i * (TAU / 8.0)
		candidate_directions.append(Vector3(cos(angle), 0.0, sin(angle)))
	_setup_nodes()
	state_timer = randf_range(1.0, 3.0)

func _setup_nodes() -> void:
	collision_layer = 4
	collision_mask = 7
	var col := CollisionShape3D.new()
	col.shape = SphereShape3D.new()
	col.shape.radius = 0.4
	col.position.y = 0.4
	add_child(col)
	
	sprite = Sprite3D.new()
	sprite.billboard = StandardMaterial3D.BILLBOARD_FIXED_Y
	sprite.shaded = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.12
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.region_enabled = true
	sprite.pixel_size = sprite_pixel_size
	sprite.position.y = maxf(0.5, sprite_pixel_size * 50.0)
	add_child(sprite)
	
	health_component = HealthComponent.new()
	health_component.max_health = max_health
	health_component.current_health = max_health
	add_child(health_component)
	health_component.died.connect(_on_died)
	health_component.damaged.connect(_on_damaged)
	
	hurtbox_component = HurtboxComponent.new()
	hurtbox_component.collision_layer = 256
	add_child(hurtbox_component)
	hurtbox_component.health_component = health_component
	var hurt_col := CollisionShape3D.new()
	hurt_col.shape = CapsuleShape3D.new()
	hurt_col.shape.radius = 0.5
	hurt_col.shape.height = 1.2
	hurt_col.position.y = 0.6
	hurtbox_component.add_child(hurt_col)
	
	hitbox_component = HitboxComponent.new()
	hitbox_component.collision_mask = 128
	hitbox_component.damage = attack_damage
	hitbox_component.monitoring = false
	add_child(hitbox_component)
	hitbox_col = CollisionShape3D.new()
	hitbox_col.shape = SphereShape3D.new()
	hitbox_col.shape.radius = maxf(0.6, attack_range * 0.55)
	hitbox_col.position.y = 0.6
	hitbox_component.add_child(hitbox_col)
	
	# Load initial sprite
	_update_sprite()

func _physics_process(delta: float) -> void:
	if current_state == State.DEATH:
		_process_death_state(delta)
		return
	velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta
	_update_ai_state(delta)
	_apply_movement(delta)
	_update_animation(delta)
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

func _update_ai_state(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		current_state = State.IDLE
		return
	var dist := global_position.distance_to(player.global_position)
	if current_state == State.ATTACK or current_state == State.HURT: return
	if dist <= attack_range and attack_cooldown_timer <= 0.0:
		current_state = State.ATTACK
		current_frame = 0
		frame_timer = 0.0
		velocity = Vector3.ZERO
		return
	if dist <= detection_range:
		current_state = State.CHASE
	else:
		if current_state == State.CHASE:
			current_state = State.IDLE
			state_timer = 1.0
		state_timer -= delta
		if state_timer <= 0.0:
			_choose_new_wander_state()

func _choose_new_wander_state() -> void:
	if current_state == State.IDLE:
		current_state = State.WANDER
		state_timer = randf_range(2.0, 5.0)
		var angle := randf_range(0.0, TAU)
		wander_direction = Vector3(cos(angle), 0.0, sin(angle)).normalized()
	else:
		current_state = State.IDLE
		state_timer = randf_range(1.0, 3.0)
		wander_direction = Vector3.ZERO

func _check_obstacle(dir: Vector3, dist: float) -> bool:
	var space := get_world_3d().direct_space_state
	if not space: return false
	var start := global_position + Vector3(0, 0.5, 0)
	var query := PhysicsRayQueryParameters3D.create(start, start + dir * dist, 1)
	query.exclude = [get_rid()]
	return not space.intersect_ray(query).is_empty()

func _apply_movement(delta: float) -> void:
	if current_state == State.ATTACK or current_state == State.HURT:
		move_and_slide()
		return
	var target_dir := Vector3.ZERO
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if current_state == State.CHASE and player:
		var dist := global_position.distance_to(player.global_position)
		var dir := (player.global_position - global_position).normalized()
		dir.y = 0.0
		dir = dir.normalized()
		var perp := Vector3(-dir.z, 0.0, dir.x) * strafe_dir
		if _check_obstacle(perp, 1.5):
			strafe_dir = -strafe_dir
			perp = Vector3(-dir.z, 0.0, dir.x) * strafe_dir
		if dist <= 4.0:
			var blend := clampf((4.0 - dist) / 2.5, 0.0, 0.8)
			target_dir = (dir * (1.0 - blend) + perp * blend).normalized()
		else:
			target_dir = dir
	elif current_state == State.WANDER:
		target_dir = wander_direction

	var steer := _get_context_steering_direction(target_dir)
	var sep := _get_diagonal_separation_force()
	var move_dir := (steer + sep * 1.5).normalized()
	if move_dir != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, move_dir.x * speed, speed * 10.0 * delta)
		velocity.z = move_toward(velocity.z, move_dir.z * speed, speed * 10.0 * delta)
		# Update facing
		if move_dir.x > 0.05:
			facing_right = true
		elif move_dir.x < -0.05:
			facing_right = false
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * 10.0 * delta)
	move_and_slide()

func _get_diagonal_separation_force() -> Vector3:
	var force := Vector3.ZERO
	var neighbors := get_tree().get_nodes_in_group("orc_mobs")
	var count := 0
	for n in neighbors:
		if n == self or not is_instance_valid(n): continue
		var orc := n as OrcMob
		if orc == null or orc.current_state == State.DEATH: continue
		var to_n: Vector3 = global_position - orc.global_position
		to_n.y = 0.0
		var dist := to_n.length()
		if dist > 0.0 and dist < 2.0:
			var diag_push := to_n.normalized().rotated(Vector3.UP, PI / 4.0 * strafe_dir)
			force += diag_push * ((2.0 - dist) / 2.0)
			count += 1
	return force / count if count > 0 else Vector3.ZERO

func _get_context_steering_direction(target_dir: Vector3) -> Vector3:
	if target_dir == Vector3.ZERO: return Vector3.ZERO
	var interest: Array[float] = []; var danger: Array[float] = []
	interest.resize(8); danger.resize(8); interest.fill(0.0); danger.fill(0.0)
	for i in range(8):
		interest[i] = maxf(0.0, candidate_directions[i].dot(target_dir))
	
	var space := get_world_3d().direct_space_state
	if space:
		var start := global_position + Vector3(0, 0.5, 0)
		for i in range(8):
			var query := PhysicsRayQueryParameters3D.create(start, start + candidate_directions[i] * 2.0, 1)
			query.exclude = [get_rid()]
			var res := space.intersect_ray(query)
			if not res.is_empty():
				danger[i] = maxf(danger[i], ((2.0 - global_position.distance_to(res.position)) / 2.0) * 1.5)
				
	var neighbors := get_tree().get_nodes_in_group("orc_mobs")
	for n in neighbors:
		if n == self or not is_instance_valid(n): continue
		var orc := n as OrcMob
		if orc == null or orc.current_state == State.DEATH: continue
		var diff: Vector3 = orc.global_position - global_position
		diff.y = 0.0
		var dist := diff.length()
		if dist > 0.0 and dist < 2.0:
			var dir := diff.normalized()
			var val := (2.0 - dist) / 2.0
			for i in range(8):
				var d := candidate_directions[i].dot(dir)
				if d > 0.0:
					danger[i] = maxf(danger[i], d * val * 1.8)
					
	var chosen := Vector3.ZERO
	for i in range(8):
		chosen += candidate_directions[i] * (interest[i] - danger[i])
	return chosen.normalized() if chosen != Vector3.ZERO else Vector3.ZERO

func _update_animation(delta: float) -> void:
	var max_frames := 6
	anim_fps = 6.0
	
	match current_state:
		State.IDLE:
			max_frames = 6
			anim_fps = 5.0
		State.WANDER, State.CHASE:
			max_frames = 8
			anim_fps = 8.0 if current_state == State.WANDER else 10.0
		State.ATTACK:
			max_frames = 6
			anim_fps = 8.0
		State.HURT:
			max_frames = 3
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
		hitbox_component.monitoring = (current_frame == 4)
	
	_update_sprite()

func _update_sprite() -> void:
	var prefix := "idle"
	var frame := clampi(current_frame, 0, 5)
	
	match current_state:
		State.IDLE:
			prefix = "idle"
			frame = clampi(current_frame, 0, 5)
		State.WANDER, State.CHASE:
			prefix = "walk"
			frame = clampi(current_frame, 0, 7)
		State.ATTACK:
			prefix = "attack"
			frame = clampi(current_frame, 0, 5)
		State.HURT:
			prefix = "hurt"
			frame = clampi(current_frame, 0, 2)
		State.DEATH:
			prefix = "death"
			frame = clampi(current_frame, 0, 3)
	
	# Try sprite sheet first, fall back to individual frames
	var sheet_path := "res://Assets/Tiny RPG Character Asset Pack v1.03 -Free Soldier&Orc/Characters(100x100)/Orc/Orc/sprite_sheets/%s.png" % prefix
	if not _texture_cache.has(sheet_path):
		if ResourceLoader.exists(sheet_path):
			_texture_cache[sheet_path] = load(sheet_path) as Texture2D
		else:
			_texture_cache[sheet_path] = null
			
	var tex: Texture2D = _texture_cache[sheet_path]
	if tex:
		var total_frames := _get_sheet_frames(prefix)
		var fw := tex.get_width() / total_frames
		sprite.texture = tex
		sprite.region_enabled = true
		sprite.region_rect = Rect2(frame * fw, 0, fw, tex.get_height())
		sprite.flip_h = not facing_right
		return
	
	# Fallback to individual frames
	var path := "res://Assets/Tiny RPG Character Asset Pack v1.03 -Free Soldier&Orc/Characters(100x100)/Orc/Orc/cropped/%s_%d.png" % [prefix, frame]
	if not _texture_cache.has(path):
		if ResourceLoader.exists(path):
			_texture_cache[path] = load(path) as Texture2D
		else:
			_texture_cache[path] = null
			
	var fallback_tex: Texture2D = _texture_cache[path]
	if fallback_tex:
		sprite.texture = fallback_tex
		sprite.region_enabled = false

func _get_sheet_frames(prefix: String) -> int:
	match prefix:
		"idle": return 6
		"walk": return 8
		"attack": return 6
		"hurt": return 3
		"death": return 4
	return 1

func _on_damaged(amount: float, source: Node3D) -> void:
	if current_state == State.DEATH:
		return
	current_state = State.HURT
	current_frame = 0
	frame_timer = 0.0
	velocity = Vector3.ZERO
	
	# Emit damage event for floating numbers
	EventBus.enemy_damaged.emit(self, amount, global_position)
	
	# Play hurt sound
	var audio := get_node_or_null("/root/World/AudioManager") as AudioManager
	if audio:
		audio.play_sfx("hurt", global_position, 0.15)

func _on_died() -> void:
	current_state = State.DEATH
	current_frame = 0
	frame_timer = 0.0
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	hurtbox_component.collision_layer = 0
	hitbox_component.collision_mask = 0
	hitbox_component.monitoring = false
	
	# Play death sound
	var audio := get_node_or_null("/root/World/AudioManager") as AudioManager
	if audio:
		audio.play_sfx("death", global_position, 0.1)
	
	# Notify world
	EventBus.enemy_died.emit(self)

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
