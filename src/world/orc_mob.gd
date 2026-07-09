# orc_mob.gd
class_name OrcMob
extends CharacterBody3D

const EnemyCombatV2 = preload("res://src/world/enemy_combat_v2.gd")

enum State { IDLE, WANDER, CHASE, ATTACK, HURT, DEATH }

const ORC_ATTACK_FRAME_COUNT: int = 8  # legacy sprite sheet attack sequence

const REGULAR_SPRITE_PIXEL_SIZE: float = 0.0231
const BOSS_SPRITE_PIXEL_SIZE: float = 0.0346
const SPRITE_FRAME_CENTER_Y_PX: float = 50.0
# Asset orc_spring_enemy vẽ kín khung 100x100 (đầu ~y=4, chân ~y=95), khác hẳn
# asset Tiny RPG cũ chỉ chiếm một vùng nhỏ giữa khung.
const SPRITE_FEET_BASELINE_Y_PX: float = 95.0
const SPRITE_GROUND_CLEARANCE: float = 0.03
const BOSS_ATTACK_COOLDOWN: float = 2.2
const BOSS_ATTACK_ANIMATION_FPS: float = 5.0
const ORC_FIGHTER_SCENE_PATH := "res://Assets/orc_fighter_godot_asset/assets/orc_fighter/orc_fighter.tscn"
const ORC_SPRITE_SHEET_DIR := "res://Assets/orc_spring_enemy/game_ready"
# 8 hướng theo chiều kim đồng hồ bắt đầu từ N (nhìn từ sau lưng orc).
# Chỉ có 5 hướng gốc (N, NE, E, SE, S) được vẽ thật; SW/W/NW dùng lại ảnh của
# SE/E/NE rồi lật ngang (mirror) vì orc đối xứng trái-phải.
const DIRECTION_ORDER: Array[String] = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
const DIRECTION_SOURCE: Array[String] = ["N", "NE", "E", "SE", "S", "SE", "E", "NE"]
const DIRECTION_MIRROR: Array[bool] = [false, false, false, false, false, true, true, true]
# Một số animation ở hướng E/NE bị lỗi asset nguồn (sai nội dung); dùng tạm
# ảnh của hướng lân cận gần nhất cho tới khi có asset đúng.
const DIRECTION_ANIM_FALLBACK: Dictionary = {
	"E": {"hurt": "SE", "death": "SE"},
	"NE": {"walk": "N", "death": "N"},
}
const DEFAULT_CAMERA_YAW_DEG: float = 35.0
const WORLD_RENDER_MASK: int = 1
const COMBAT_ACTOR_RENDER_MASK: int = 2
const REGULAR_HEALTH_BAR_SIZE := Vector2i(64, 8)
const BOSS_HEALTH_BAR_SIZE := Vector2i(96, 10)
const HEALTH_BAR_BORDER_PX: float = 1.0
const HEALTH_BAR_BACK_COLOR := Color(0.08, 0.0, 0.0, 0.82)
const HEALTH_BAR_FILL_COLOR := Color(0.85, 0.05, 0.04, 1.0)
const REGULAR_HEALTH_BAR_HEIGHT_FACTOR: float = 54.0
const BOSS_HEALTH_BAR_HEIGHT_FACTOR: float = 58.0
# Kích thước thanh máu cố định, không phụ thuộc sprite_pixel_size của quái,
# để quái to/nhỏ khác nhau vẫn có thanh máu dễ đọc như nhau.
const REGULAR_HEALTH_BAR_PIXEL_SIZE: float = 0.008
const BOSS_HEALTH_BAR_PIXEL_SIZE: float = 0.012
# Tỉ lệ thanh máu so với sprite pixel size; dùng để override kích thước
# thanh máu cho các lớp con (vd. OrcBossMob) mà không vi phạm quy tắc
# GDScript không cho override const ở lớp cha.
const HEALTH_BAR_PIXEL_SIZE_FACTOR: float = 0.519481  # 0.012 / 0.0231

@export var speed: float = 2.0
@export var gravity: float = 9.8
@export var detection_range: float = 12.0
@export var attack_range: float = 1.2
@export var attack_cooldown_time: float = 0.8
@export var attack_animation_fps: float = 10.0
@export_range(0.0, 2.0, 0.05) var attack_commit_margin: float = 0.55
@export_range(0.0, 1.0, 0.05) var attack_recommit_window: float = 0.25
@export_range(0.0, 1.0, 0.05) var close_range_strafe_weight: float = 0.45
@export var max_health: float = 50.0
@export_range(0.01, 0.25, 0.005) var sprite_pixel_size: float = REGULAR_SPRITE_PIXEL_SIZE
@export var use_3d_model: bool = false
@export var model_scale: float = 1.0
@export var model_height: float = 1.8
@export var model_rotation_offset_deg: float = 0.0
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
var facing_dir: Vector3 = Vector3.BACK

var candidate_directions: Array[Vector3] = []
var _texture_cache: Dictionary = {}
var _cached_game_camera: Node3D = null
var sprite: Sprite3D
var model: Node3D = null
var _model_last_anim: String = ""
var _model_ground_offset: float = 0.0
var health_component: HealthComponent
var hurtbox_component: HurtboxComponent
var hitbox_component: HitboxComponent
var hitbox_col: CollisionShape3D
var health_bar_viewport: SubViewport
var health_bar_sprite: Sprite3D
var health_bar_fill: ColorRect
var health_bar_fill_max_width: float = 0.0
var combat_v2: Node = null

func _ready() -> void:
	# Mount Combat V2 child component (3-phase attack + telegraph)
	combat_v2 = EnemyCombatV2.new()
	combat_v2.name = "EnemyCombatV2"
	add_child(combat_v2)

	# Giữ physics node ở scale 1; chỉ scale Sprite3D bằng pixel_size để hitbox không bị phóng đại.
	scale = Vector3.ONE
	if is_in_group("boss"):
		sprite_pixel_size = maxf(sprite_pixel_size, BOSS_SPRITE_PIXEL_SIZE)
		attack_range = maxf(attack_range, 2.5)
		# Boss giữ nhịp đánh nặng và có khoảng nghỉ rõ ràng; buff cadence chỉ dành cho Orc thường.
		attack_cooldown_time = maxf(attack_cooldown_time, BOSS_ATTACK_COOLDOWN)
		attack_animation_fps = minf(attack_animation_fps, BOSS_ATTACK_ANIMATION_FPS)
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
	var is_boss := is_in_group("boss")
	_setup_physics_collider(is_boss)
	_setup_sprite_node()
	_setup_health_component()
	_setup_health_bar(is_boss)
	_setup_hurtbox(is_boss)
	_setup_hitbox(is_boss)

func _setup_physics_collider(is_boss: bool) -> void:
	var col := CollisionShape3D.new()
	var body_shape := SphereShape3D.new()
	if is_boss:
		body_shape.radius = 0.8
		col.position.y = 0.8
	else:
		body_shape.radius = 0.4
		col.position.y = 0.4
	col.shape = body_shape
	add_child(col)

func _setup_sprite_node() -> void:
	if use_3d_model:
		var scene: PackedScene = load(ORC_FIGHTER_SCENE_PATH) as PackedScene
		var instance: Node = scene.instantiate() if scene else null
		if instance is Node3D:
			model = instance as Node3D
			add_child(model)
			_fit_model_to_height(model, model_height)
			return
		if instance:
			instance.queue_free()
		push_warning("OrcMob: không tải được model 3D orc_fighter tại %s, dùng sprite 2D thay thế." % ORC_FIGHTER_SCENE_PATH)
		use_3d_model = false

	sprite = Sprite3D.new()
	_setup_sprite_visual()

func _setup_sprite_visual() -> void:
	sprite.billboard = StandardMaterial3D.BILLBOARD_FIXED_Y
	sprite.shaded = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.12
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sprite.layers = WORLD_RENDER_MASK | COMBAT_ACTOR_RENDER_MASK
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.region_enabled = true
	sprite.pixel_size = sprite_pixel_size
	# Asset 100x100 có nhiều vùng trong suốt; chân Orc thực nằm ở y=56, không phải đáy frame.
	# Neo theo baseline thực để sprite đứng trên mặt đất và bóng không bị chiếu lệch từ độ cao ảo.
	sprite.position.y = _get_grounded_sprite_y()
	sprite.position.z = 0.0
	add_child(sprite)

func _fit_model_to_height(node: Node3D, target_height: float) -> void:
	# Asset 3D là bản prototype, toạ độ gốc các bộ phận không đáng tin cậy;
	# đo AABB thật của mesh rồi co giãn về đúng chiều cao mong muốn và đặt chân chạm đất.
	var acc := {"aabb": AABB(), "has": false}
	_accumulate_aabb(node, node, acc)
	if not acc["has"] or (acc["aabb"] as AABB).size.y <= 0.0001:
		node.scale = Vector3.ONE * model_scale
		_model_ground_offset = 0.0
		return
	var aabb: AABB = acc["aabb"]
	var fit_scale := (target_height / aabb.size.y) * model_scale
	node.scale = Vector3.ONE * fit_scale
	_model_ground_offset = -aabb.position.y * fit_scale

func _accumulate_aabb(root: Node3D, current: Node, acc: Dictionary) -> void:
	if current is VisualInstance3D:
		var vi := current as VisualInstance3D
		var local_aabb := vi.get_aabb()
		var xform := root.global_transform.affine_inverse() * vi.global_transform
		var world_aabb: AABB = xform * local_aabb
		if acc["has"]:
			acc["aabb"] = (acc["aabb"] as AABB).merge(world_aabb)
		else:
			acc["aabb"] = world_aabb
			acc["has"] = true
	for child in current.get_children():
		_accumulate_aabb(root, child, acc)

func _get_grounded_sprite_y() -> float:
	var feet_offset_px := SPRITE_FEET_BASELINE_Y_PX - SPRITE_FRAME_CENTER_Y_PX
	return feet_offset_px * sprite_pixel_size + SPRITE_GROUND_CLEARANCE

func _setup_health_component() -> void:
	health_component = HealthComponent.new()
	health_component.max_health = max_health
	health_component.current_health = max_health
	add_child(health_component)
	health_component.died.connect(_on_died)
	health_component.damaged.connect(_on_damaged)
	health_component.health_changed.connect(_on_health_changed)

	if combat_v2:
		combat_v2.bind(self, hitbox_component)

func _setup_health_bar(is_boss: bool) -> void:
	var bar_size := BOSS_HEALTH_BAR_SIZE if is_boss else REGULAR_HEALTH_BAR_SIZE
	health_bar_viewport = SubViewport.new()
	health_bar_viewport.name = "HealthBarViewport"
	health_bar_viewport.size = bar_size
	health_bar_viewport.transparent_bg = true
	health_bar_viewport.disable_3d = true
	health_bar_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(health_bar_viewport)
	
	var bar_root := Control.new()
	bar_root.name = "HealthBarRoot"
	bar_root.size = Vector2(bar_size)
	bar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bar_viewport.add_child(bar_root)
	
	var backing := ColorRect.new()
	backing.name = "HealthBarBack"
	backing.color = HEALTH_BAR_BACK_COLOR
	backing.set_anchors_preset(Control.PRESET_FULL_RECT)
	backing.offset_left = 0.0
	backing.offset_top = 0.0
	backing.offset_right = 0.0
	backing.offset_bottom = 0.0
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_root.add_child(backing)
	
	health_bar_fill = ColorRect.new()
	health_bar_fill.name = "HealthBarFill"
	health_bar_fill.color = HEALTH_BAR_FILL_COLOR
	health_bar_fill.position = Vector2(HEALTH_BAR_BORDER_PX, HEALTH_BAR_BORDER_PX)
	health_bar_fill.size = Vector2(
		float(bar_size.x) - HEALTH_BAR_BORDER_PX * 2.0,
		float(bar_size.y) - HEALTH_BAR_BORDER_PX * 2.0
	)
	health_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_root.add_child(health_bar_fill)
	health_bar_fill_max_width = health_bar_fill.size.x
	
	health_bar_sprite = Sprite3D.new()
	health_bar_sprite.name = "HealthBarSprite"
	health_bar_sprite.billboard = StandardMaterial3D.BILLBOARD_FIXED_Y
	health_bar_sprite.shaded = false
	health_bar_sprite.layers = WORLD_RENDER_MASK | COMBAT_ACTOR_RENDER_MASK
	health_bar_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	health_bar_sprite.texture = health_bar_viewport.get_texture()
	health_bar_sprite.pixel_size = BOSS_HEALTH_BAR_PIXEL_SIZE if is_boss else REGULAR_HEALTH_BAR_PIXEL_SIZE
	health_bar_sprite.position.y = _get_health_bar_height(is_boss)
	add_child(health_bar_sprite)
	_update_health_bar(health_component.current_health, health_component.max_health)

func _get_health_bar_height(is_boss: bool) -> float:
	if use_3d_model:
		return model_height + 0.3
	var height_factor := BOSS_HEALTH_BAR_HEIGHT_FACTOR if is_boss else REGULAR_HEALTH_BAR_HEIGHT_FACTOR
	return _get_grounded_sprite_y() + height_factor * sprite_pixel_size

func _on_health_changed(current: float, max_h: float) -> void:
	_update_health_bar(current, max_h)

func _update_health_bar(current: float, max_h: float) -> void:
	if health_bar_fill == null:
		return
	var ratio := 0.0 if max_h <= 0.0 else clampf(current / max_h, 0.0, 1.0)
	health_bar_fill.size.x = roundf(health_bar_fill_max_width * ratio)
	if health_bar_sprite:
		health_bar_sprite.visible = current > 0.0

func _setup_hurtbox(is_boss: bool) -> void:
	hurtbox_component = HurtboxComponent.new()
	hurtbox_component.collision_layer = 256
	add_child(hurtbox_component)
	hurtbox_component.health_component = health_component
	var hurt_col := CollisionShape3D.new()
	var hurt_shape := CapsuleShape3D.new()
	if is_boss:
		hurt_shape.radius = 0.9
		hurt_shape.height = 2.4
		hurt_col.position.y = 1.2
	else:
		hurt_shape.radius = 0.6
		hurt_shape.height = 1.6
		hurt_col.position.y = 0.8
	hurt_col.shape = hurt_shape
	hurtbox_component.add_child(hurt_col)

func _setup_hitbox(is_boss: bool) -> void:
	hitbox_component = HitboxComponent.new()
	hitbox_component.collision_mask = 128
	hitbox_component.damage = attack_damage
	hitbox_component.monitoring = false
	add_child(hitbox_component)
	hitbox_col = CollisionShape3D.new()
	var hit_shape := SphereShape3D.new()
	if is_boss:
		hit_shape.radius = 1.5
		hitbox_col.position.y = 1.0
	else:
		# Tầm hit phải theo sát tầm kích hoạt attack để Orc không vung trúng hình nhưng hụt hitbox.
		hit_shape.radius = maxf(0.65, attack_range * 0.65)
		hitbox_col.position.y = 0.6
	hitbox_col.shape = hit_shape
	hitbox_component.add_child(hitbox_col)
	
	# Load initial visual (sprite frame hoặc model 3D)
	if use_3d_model:
		_update_model_visual()
	else:
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
	_update_sprite_height()

func _update_sprite_height() -> void:
	if sprite == null and model == null:
		return
	var offset_y = 0.0
	var forest = get_parent().get_node_or_null("Forest")
	if forest and forest.has_method("_get_zone"):
		var zone = forest._get_zone(global_position.x, global_position.z)
		var is_path = (zone == 2) # Zone.PATH is 2
		if not is_path:
			offset_y = 0.2
	if sprite:
		sprite.position.y = _get_grounded_sprite_y() + offset_y
	elif model:
		model.position.y = _model_ground_offset + offset_y

func _update_ai_state(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		current_state = State.IDLE
		return
	var dist := _get_planar_offset_to(player).length()
	if current_state == State.ATTACK or current_state == State.HURT: return
	if dist <= attack_range and attack_cooldown_timer <= 0.0:
		current_state = State.ATTACK
		current_frame = 0
		frame_timer = 0.0
		velocity = Vector3.ZERO
		if combat_v2 and combat_v2.enabled:
			combat_v2.on_attack_started(attack_animation_fps, ORC_ATTACK_FRAME_COUNT)
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

func _get_planar_offset_to(target: Node3D) -> Vector3:
	var offset := target.global_position - global_position
	offset.y = 0.0
	return offset

func _is_holding_attack_position(player: Node3D) -> bool:
	return attack_cooldown_timer > 0.0 and _get_planar_offset_to(player).length() <= attack_range

func _get_chase_target_direction(player: Node3D) -> Vector3:
	var offset := _get_planar_offset_to(player)
	var dist := offset.length()
	if dist <= 0.0001:
		return Vector3.ZERO
	var dir := offset / dist

	# Trong tầm đánh, Orc giữ vị trí chờ cooldown thay vì tự strafe ra khỏi tầm.
	if dist <= attack_range and attack_cooldown_timer > 0.0:
		return Vector3.ZERO

	# Khi đã gần mục tiêu hoặc cooldown sắp xong, ưu tiên đường thẳng để commit đòn kế tiếp.
	if dist <= attack_range + attack_commit_margin \
			and attack_cooldown_timer <= attack_recommit_window:
		return dir

	var perp := Vector3(-dir.z, 0.0, dir.x) * strafe_dir
	if _check_obstacle(perp, 1.5):
		strafe_dir = -strafe_dir
		perp = Vector3(-dir.z, 0.0, dir.x) * strafe_dir
	if dist <= 4.0:
		var blend := clampf((4.0 - dist) / 2.5, 0.0, close_range_strafe_weight)
		return (dir * (1.0 - blend) + perp * blend).normalized()
	return dir

func _apply_movement(delta: float) -> void:
	if current_state == State.ATTACK or current_state == State.HURT:
		if current_state == State.HURT:
			# Decelerate the knockback velocity smoothly during the 0.5s hurt state
			velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
		move_and_slide()
		return
	var target_dir := Vector3.ZERO
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var hold_attack_position := false
	if current_state == State.CHASE and player:
		hold_attack_position = _is_holding_attack_position(player)
		target_dir = _get_chase_target_direction(player)
	elif current_state == State.WANDER:
		target_dir = wander_direction

	var steer := _get_context_steering_direction(target_dir)
	var sep := Vector3.ZERO if hold_attack_position else _get_diagonal_separation_force()
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
			anim_fps = attack_animation_fps
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
		if combat_v2 and combat_v2.enabled:
			combat_v2.tick(delta)
			hitbox_component.monitoring = combat_v2.phase == EnemyCombatV2.AttackPhase.ATTACK
		else:
			hitbox_component.monitoring = (current_frame == 4)

	if use_3d_model:
		_update_model_visual()
	else:
		_update_facing_direction()
		_update_sprite()

func _update_model_visual() -> void:
	if model == null:
		return
	_update_model_facing()

	var wanted_anim := "idle"
	match current_state:
		State.ATTACK:
			wanted_anim = "attack"
		State.HURT:
			wanted_anim = "hit"
		State.DEATH:
			wanted_anim = "defeated"
		_:
			wanted_anim = "idle"

	if wanted_anim != _model_last_anim:
		_model_last_anim = wanted_anim
		if model.has_method(wanted_anim):
			model.call(wanted_anim)

func _update_model_facing() -> void:
	if model == null or current_state == State.DEATH:
		return
	var look_dir := Vector3.ZERO
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if (current_state == State.CHASE or current_state == State.ATTACK) and player:
		look_dir = _get_planar_offset_to(player)
	elif velocity.length_squared() > 0.01:
		look_dir = Vector3(velocity.x, 0.0, velocity.z)
	if look_dir.length_squared() > 0.0001:
		model.rotation.y = atan2(look_dir.x, look_dir.z) + deg_to_rad(model_rotation_offset_deg)

func _update_facing_direction() -> void:
	if current_state == State.DEATH:
		return
	var look_dir := Vector3.ZERO
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if (current_state == State.CHASE or current_state == State.ATTACK) and player:
		look_dir = _get_planar_offset_to(player)
	elif velocity.length_squared() > 0.01:
		look_dir = Vector3(velocity.x, 0.0, velocity.z)
	if look_dir.length_squared() > 0.0001:
		facing_dir = look_dir.normalized()

func _get_camera_yaw_deg() -> float:
	if _cached_game_camera == null:
		_cached_game_camera = get_tree().get_first_node_in_group("camera") as Node3D
	if _cached_game_camera:
		var rot = _cached_game_camera.get("camera_rotate")
		if rot is Vector3:
			return (rot as Vector3).y
	return DEFAULT_CAMERA_YAW_DEG

# Camera có yaw cố định (không xoay theo player), nên góc "orc quay mặt so với
# camera" tính được ổn định để chọn 1 trong 8 hướng sprite đã dựng sẵn.
func _get_direction_index() -> int:
	var yaw_rad := deg_to_rad(_get_camera_yaw_deg())
	var cam_forward := Vector3(sin(yaw_rad), 0.0, cos(yaw_rad))
	var cam_right := Vector3(cos(yaw_rad), 0.0, -sin(yaw_rad))
	var theta := atan2(facing_dir.dot(cam_right), facing_dir.dot(cam_forward))
	var deg := rad_to_deg(theta)
	if deg < 0.0:
		deg += 360.0
	return int(round(deg / 45.0)) % 8

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

	var dir_idx := _get_direction_index()
	var source_dir: String = DIRECTION_SOURCE[dir_idx]
	var mirror: bool = DIRECTION_MIRROR[dir_idx]
	if DIRECTION_ANIM_FALLBACK.has(source_dir) and (DIRECTION_ANIM_FALLBACK[source_dir] as Dictionary).has(prefix):
		source_dir = (DIRECTION_ANIM_FALLBACK[source_dir] as Dictionary)[prefix]

	# Try directional sprite sheet first, fall back to legacy single-direction assets
	var sheet_path := "%s/%s/%s.png" % [ORC_SPRITE_SHEET_DIR, source_dir, prefix]
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
		sprite.flip_h = mirror
		return

	# Legacy fallback: old single-direction sheet (only flips left/right)
	var legacy_sheet_path := "%s/%s.png" % [ORC_SPRITE_SHEET_DIR, prefix]
	if not _texture_cache.has(legacy_sheet_path):
		if ResourceLoader.exists(legacy_sheet_path):
			_texture_cache[legacy_sheet_path] = load(legacy_sheet_path) as Texture2D
		else:
			_texture_cache[legacy_sheet_path] = null

	var legacy_tex: Texture2D = _texture_cache[legacy_sheet_path]
	if legacy_tex:
		var total_frames := _get_sheet_frames(prefix)
		var fw := legacy_tex.get_width() / total_frames
		sprite.texture = legacy_tex
		sprite.region_enabled = true
		sprite.region_rect = Rect2(frame * fw, 0, fw, legacy_tex.get_height())
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

func _on_damaged(amount: float, source: Node3D, is_critical: bool = false) -> void:
	if current_state == State.DEATH:
		return
	current_state = State.HURT
	current_frame = 0
	frame_timer = 0.0
	
	# Calculate knockback direction away from the source
	var kb_dir := Vector3.ZERO
	if source:
		kb_dir = (global_position - source.global_position).normalized()
		kb_dir.y = 0.0
		kb_dir = kb_dir.normalized()
	if kb_dir == Vector3.ZERO:
		kb_dir = Vector3.LEFT if facing_right else Vector3.RIGHT
	
	# Set knockback velocity (6.0 force)
	var knockback_force := 6.0
	velocity = kb_dir * knockback_force
	
	# Spawn golden-orange-red square particle burst if in scene tree and has parent
	if is_inside_tree() and get_parent():
		var particles := CPUParticles3D.new()
		particles.name = "HitParticles"
		
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.06, 0.06, 0.06)
		
		var mat := StandardMaterial3D.new()
		mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true # Correct Godot 4 property for particle colors
		mesh.material = mat
		
		particles.mesh = mesh
		particles.amount = 12
		particles.explosiveness = 1.0
		particles.one_shot = true
		particles.lifetime = 0.5
		
		# Particles spray in the direction of hit, slightly upwards
		var spray_dir := kb_dir
		spray_dir.y = 0.4
		particles.direction = spray_dir.normalized()
		particles.spread = 45.0
		particles.initial_velocity_min = 3.0
		particles.initial_velocity_max = 5.0
		particles.damping_min = 1.0
		particles.damping_max = 2.0
		
		# Color gradient: Light Gold -> Orange -> Red -> Fade
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.4, 0.8, 1.0])
		gradient.colors = PackedColorArray([
			Color("#FFF1B2"), # Light gold-white
			Color("#FF9F33"), # Orange
			Color("#D92B2B"), # Deep red
			Color(0.85, 0.17, 0.17, 0.0) # Transparent red
		])
		particles.color_ramp = gradient
		
		get_parent().add_child(particles)
		particles.global_position = global_position + Vector3(0.0, 0.6, 0.0)
		particles.emitting = true
		
		# Auto delete particles after emission completes
		get_tree().create_timer(0.6).timeout.connect(particles.queue_free)
	
	# Emit damage event for floating numbers
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus:
		event_bus.enemy_damaged.emit(self, amount, global_position, is_critical)

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
	if health_bar_sprite:
		health_bar_sprite.visible = false
	
	# Notify world
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus:
		event_bus.enemy_died.emit(self)

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
			if sprite:
				var tween := create_tween()
				tween.tween_property(sprite, "modulate:a", 0.0, 1.5)
				tween.tween_callback(queue_free)
			else:
				get_tree().create_timer(1.5).timeout.connect(queue_free)
			return
	if use_3d_model:
		_update_model_visual()
	else:
		_update_sprite()
