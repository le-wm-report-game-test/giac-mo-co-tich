# orc_mob.gd
class_name OrcMob
extends CharacterBody3D

enum State { IDLE, WANDER, CHASE, ATTACK, DEATH }

@export var speed: float = 2.0
@export var gravity: float = 9.8
@export var detection_range: float = 12.0
@export var attack_range: float = 1.5
@export var attack_cooldown_time: float = 1.5

var current_state: State = State.IDLE
var state_timer: float = 0.0
var wander_direction: Vector3 = Vector3.ZERO
var attack_cooldown_timer: float = 0.0
var frame_timer: float = 0.0
var current_frame: int = 0
var anim_fps: float = 6.0
var strafe_dir: float = 1.0

var candidate_directions: Array[Vector3] = []
var sprite: Sprite3D
var health_component: HealthComponent
var hurtbox_component: HurtboxComponent
var hitbox_component: HitboxComponent
var hitbox_col: CollisionShape3D

func _ready() -> void:
	scale = Vector3(10.0, 10.0, 10.0)
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
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.position.y = 0.5
	add_child(sprite)
	
	health_component = HealthComponent.new()
	health_component.max_health = 50.0
	health_component.current_health = 50.0
	add_child(health_component)
	health_component.died.connect(_on_died)
	
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
	hitbox_component.damage = 10.0
	add_child(hitbox_component)
	hitbox_col = CollisionShape3D.new()
	hitbox_col.shape = SphereShape3D.new()
	hitbox_col.shape.radius = 1.2
	hitbox_col.position.y = 0.6
	hitbox_component.add_child(hitbox_col)

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
	if current_state == State.ATTACK: return
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
	if current_state == State.ATTACK:
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
	var prefix := "idle"; var max_frames := 6; anim_fps = 6.0
	match current_state:
		State.WANDER, State.CHASE:
			prefix = "walk"; max_frames = 8
			anim_fps = 8.0 if current_state == State.WANDER else 10.0
		State.ATTACK:
			prefix = "attack"; max_frames = 6; anim_fps = 8.0
	frame_timer += delta
	if frame_timer >= 1.0 / anim_fps:
		frame_timer = 0.0
		current_frame += 1
		if current_frame >= max_frames:
			if current_state == State.ATTACK:
				current_state = State.IDLE
				current_frame = 0
				attack_cooldown_timer = attack_cooldown_time
				hitbox_component.monitoring = false
			else:
				current_frame = 0
	if current_state == State.ATTACK:
		hitbox_component.monitoring = (current_frame == 4)
	_update_sprite(prefix)

func _update_sprite(prefix: String) -> void:
	if velocity.x > 0.05:
		sprite.flip_h = false
	elif velocity.x < -0.05:
		sprite.flip_h = true
	var path := "res://Assets/Tiny RPG Character Asset Pack v1.03 -Free Soldier&Orc/Characters(100x100)/Orc/Orc/cropped/%s_%d.png" % [prefix, current_frame]
	if ResourceLoader.exists(path):
		sprite.texture = load(path)

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
	_update_sprite("death")
