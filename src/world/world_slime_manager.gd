# world_slime_manager.gd
# Manages spawn / lifecycle / active-flag of WorldSlime instances.
# Uses AnimatedSprite3D with PocketWitch GIF sprite frames (16 frames each).
class_name WorldSlimeManager
extends Node

const HARD_CAP: int = 30
const INITIAL_DENSITY: float = 0.6                    # spawn 60% of cap at start
const RESPAWN_POLL_SECONDS: float = 30.0
const ACTIVE_RADIUS_SQ: float = 400.0                # sqrt(400) = 20m active radius
const ACTIVE_REFRESH_SECONDS: float = 0.5
const SPAWN_RADIUS: float = 48.0
const SPAWN_MIN_PLAYER_DIST_SQ: float = 64.0          # 8m avoid spawning on player
const MAX_SPAWN_ATTEMPTS: int = 12
const ZONE_PATH: int = 2
const SLIME_BASE_PATH := "res://Assets/PocketWitch-Slimes_v2.1/Slimes"
const GIF_FPS: float = 12.0
const HURT_FRAME_RATE: float = 1.0
const DIRECTION_SUFFIX := {
	WorldSlime.MoveDir.DOWN: "front",
	WorldSlime.MoveDir.UP: "back",
	WorldSlime.MoveDir.LEFT: "side",
	WorldSlime.MoveDir.RIGHT: "side",
}
const SUPPORTED_COLORS := ["green", "blue", "violet", "purple"]

@export var slime_script: Script = preload("res://src/world/world_slime.gd")

var _slimes: Array[CharacterBody3D] = []
var _rng: RandomNumberGenerator
var _respawn_timer: float = 0.0
var _active_refresh_timer: float = 0.0
# Cache: {color: {direction: SpriteFrames}}
var _sprite_frames_cache: Dictionary = {}


func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	_spawn_initial_slimes()


func _process(delta: float) -> void:
	_respawn_timer -= delta
	_active_refresh_timer -= delta
	if _respawn_timer <= 0.0:
		_respawn_timer = RESPAWN_POLL_SECONDS
		_top_up_slimes()
	if _active_refresh_timer <= 0.0:
		_active_refresh_timer = ACTIVE_REFRESH_SECONDS
		_refresh_active_flags()


func _spawn_initial_slimes() -> void:
	var target: int = int(round(HARD_CAP * INITIAL_DENSITY))
	for i in range(target):
		_try_spawn_one()


func _top_up_slimes() -> void:
	var alive: int = _count_alive_slimes()
	while alive < int(round(HARD_CAP * INITIAL_DENSITY)) and _slimes.size() < HARD_CAP:
		if not _try_spawn_one():
			break
		alive = _count_alive_slimes()


func _count_alive_slimes() -> int:
	var count := 0
	for slime in _slimes:
		if is_instance_valid(slime):
			count += 1
	return count


func _try_spawn_one() -> bool:
	for attempt in range(MAX_SPAWN_ATTEMPTS):
		var pos := _pick_random_ground_position()
		if pos != Vector3.INF:
			_instantiate_slime(pos)
			return true
	return false


func _pick_random_ground_position() -> Vector3:
	var x: float = _rng.randf_range(-SPAWN_RADIUS, SPAWN_RADIUS)
	var z: float = _rng.randf_range(-SPAWN_RADIUS, SPAWN_RADIUS)

	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and Vector2(x, z).distance_squared_to(Vector2(player.global_position.x, player.global_position.z)) < SPAWN_MIN_PLAYER_DIST_SQ:
		return Vector3.INF

	var forest := get_tree().get_first_node_in_group("forest")
	if forest == null:
		return Vector3.INF

	if forest.has_method("_get_zone") and int(forest._get_zone(x, z)) == ZONE_PATH:
		return Vector3.INF

	if forest.has_method("_is_under_large_tree_canopy") and forest._is_under_large_tree_canopy(x, z):
		return Vector3.INF

	var y: float = 0.0
	if forest.has_method("_get_hill_height"):
		y = forest._get_hill_height(x, z)
	return Vector3(x, y, z)


func _instantiate_slime(pos: Vector3) -> CharacterBody3D:
	var slime := CharacterBody3D.new()
	slime.set_script(slime_script)
	slime.position = pos
	slime.name = "Slime"
	slime.collision_layer = 16
	slime.collision_mask = 1
	# Pre-assign _color_key so component attachments can read it.
	var color: String = SUPPORTED_COLORS[_rng.randi() % SUPPORTED_COLORS.size()]
	slime.set("_color_key", color)
	# Attach children BEFORE add_child(slime): @onready in world_slime.gd
	# resolves the moment the slime enters the tree.
	_attach_components(slime, color)
	add_child(slime)
	_slimes.append(slime)
	return slime


func _attach_components(slime: CharacterBody3D, color: String) -> void:
	var animated := AnimatedSprite3D.new()
	animated.name = "Sprite3D"
	animated.sprite_frames = get_or_load_sprite_frames(color, WorldSlime.MoveDir.DOWN)
	animated.play("default")
	slime.add_child(animated)

	var body_shape := CollisionShape3D.new()
	body_shape.name = "CollisionShape3D"
	body_shape.shape = SphereShape3D.new()
	body_shape.shape.radius = 0.28
	body_shape.position.y = 0.28
	slime.add_child(body_shape)

	var health := HealthComponent.new()
	health.name = "HealthComponent"
	slime.add_child(health)

	var hurtbox := HurtboxComponent.new()
	hurtbox.name = "Hurtbox"
	hurtbox.health_component = health
	slime.add_child(hurtbox)
	var hurt_shape := CollisionShape3D.new()
	hurt_shape.name = "CollisionShape3D"
	hurt_shape.shape = SphereShape3D.new()
	hurt_shape.shape.radius = 0.4
	hurt_shape.position.y = 0.28
	hurtbox.add_child(hurt_shape)


func get_or_load_sprite_frames(color: String, direction: int) -> SpriteFrames:
	var color_dict: Dictionary = _sprite_frames_cache.get(color, {})
	if color_dict.has(direction):
		return color_dict[direction]
	var frames: SpriteFrames = _build_gif_sprite_frames(color, direction)
	if frames == null:
		var placeholder := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		placeholder.fill(Color.MAGENTA)
		frames = SpriteFrames.new()
		frames.add_animation("default")
		frames.set_animation_speed("default", 1.0)
		frames.add_frame("default", ImageTexture.create_from_image(placeholder))
	color_dict[direction] = frames
	_sprite_frames_cache[color] = color_dict
	return frames


func build_hurt_sprite_frames(color: String) -> SpriteFrames:
	var path := "%s/%s slime/slime_hurt.png" % [SLIME_BASE_PATH, color]
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	var frames := SpriteFrames.new()
	frames.add_animation("default")
	frames.set_animation_speed("default", HURT_FRAME_RATE)
	frames.add_frame("default", tex)
	return frames


func _build_gif_sprite_frames(color: String, direction: int) -> SpriteFrames:
	var suffix: String = DIRECTION_SUFFIX.get(direction, "front")
	var path := "%s/%s slime/slime_%s_%s.gif" % [SLIME_BASE_PATH, color, color, suffix]
	if not ResourceLoader.exists(path):
		return null
	var frames := SpriteFrames.new()
	frames.add_animation("default")
	frames.set_animation_speed("default", GIF_FPS)
	frames.set_animation_loop("default", true)
	for tex in _extract_gif_frames(path):
		frames.add_frame("default", tex)
	return frames


func _extract_gif_frames(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var bytes := file.get_buffer(file.get_length())
	file.close()
	var image := Image.new()
	if image.load_gif_from_buffer(bytes) != OK:
		return []
	var probe := image.duplicate()
	var frame_count := 1
	for i in range(1, 64):
		if probe.seek(i) != OK:
			break
		frame_count = i + 1
	var result: Array = []
	for i in range(frame_count):
		var frame_img := image.duplicate()
		if frame_count > 1:
			frame_img.seek(i)
		var tex := ImageTexture.create_from_image(frame_img)
		if tex != null:
			result.append(tex)
	return result


func _refresh_active_flags() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var player_pos := player.global_position if player else Vector3.ZERO
	for slime in _slimes:
		if not is_instance_valid(slime):
			continue
		var active: bool = true
		if player:
			var dx: float = slime.global_position.x - player_pos.x
			var dz: float = slime.global_position.z - player_pos.z
			active = (dx * dx + dz * dz) <= ACTIVE_RADIUS_SQ
		slime.set("_active", active)


func get_slime_count() -> int:
	return _count_alive_slimes()
