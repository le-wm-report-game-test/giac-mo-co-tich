class_name OrcBossMob
extends OrcMob

enum VisualFacing { FRONT, FRONT_DIAG, SIDE, BACK_DIAG, BACK }

const IDLE_ATLAS_PATH := "res://Assets/enemies/orc_boss/boss_idle.png"
const WALK_ATLAS_PATH := "res://Assets/enemies/orc_boss/boss_walk.png"
const ATTACK_ATLAS_PATH := "res://Assets/enemies/orc_boss/boss_attack.png"
const HURT_ATLAS_PATH := "res://Assets/enemies/orc_boss/boss_hurt.png"
const DEATH_ATLAS_PATH := "res://Assets/enemies/orc_boss/boss_death.png"
const BOSS_VISUAL_PIXEL_SIZE: float = 0.04
const BOSS_SPRITE_TINT := Color(1.50, 1.50, 1.38, 1.5)
const BOSS_HEALTH_BAR_RENDER_PIXEL_SIZE: float = 0.02  # scaled up to match boss body scale
const BOSS_HEALTH_BAR_TOP_MARGIN: float = 0.06

const WALK_DIR_UP_LEFT := "wa"
const WALK_DIR_UP_RIGHT := "wd"
const WALK_DIR_DOWN_LEFT := "sa"
const WALK_DIR_DOWN_RIGHT := "sd"
const WALK_DIR_UP := "w"
const WALK_DIR_LEFT := "a"
const WALK_DIR_DOWN := "s"
const WALK_DIR_RIGHT := "d"
const BOSS_WALK_UP_RECTS := [
	Rect2(55, 272, 82, 107),
	Rect2(197, 272, 81, 108),
	Rect2(340, 275, 78, 105),
	Rect2(487, 272, 83, 108),
]
const BOSS_WALK_SIDE_RECTS := [
	Rect2(61, 137, 73, 135),
	Rect2(208, 137, 67, 135),
	Rect2(349, 137, 71, 99),
	Rect2(500, 137, 68, 135),
]
const BOSS_WALK_DOWN_RECTS := [
	Rect2(42, 8, 86, 99),
	Rect2(195, 8, 77, 99),
	Rect2(337, 8, 81, 99),
	Rect2(483, 8, 82, 99),
]

var _frames_by_state: Dictionary = {}
var _active_frame_size: Vector2 = Vector2(64.0, 80.0)
var _visual_facing: VisualFacing = VisualFacing.FRONT
var _flip_h_visual: bool = false
var _atlas_images: Dictionary = {}
var _walk_direction_key: String = WALK_DIR_DOWN

# Boss-tier stats. Override via configure_arena() or Inspector. Defaults
# match the original _spawn_boss values from world_manager.gd.
@export var boss_max_health: float = 300.0
@export var boss_attack_damage: float = 25.0
@export var boss_speed: float = 1.5
@export var boss_attack_cooldown_time: float = 2.5
@export var boss_attack_range: float = 1.65
@export var boss_detection_range: float = 20.0

# Spawn state set by configure_arena(); used by _ready to apply stats.
var _arena_position: Vector3 = Vector3(-15.0, 0.2, -15.0)
var _stats_applied: bool = false

func configure_arena(arena_pos: Vector3) -> void:
	# Called by WorldManager BEFORE add_child(). Stores arena position and
	# defers stat application to _ready() so the parent scene tree is set
	# up by the time we touch health_component / sprite.
	_arena_position = arena_pos
	position = arena_pos

func _ready() -> void:
	_build_frame_manifest()
	super._ready()
	_apply_boss_stats()
	sprite_pixel_size = BOSS_VISUAL_PIXEL_SIZE
	attack_frame_count = 6  # boss attack animation has fewer frames than orc
	if is_instance_valid(sprite):
		sprite.pixel_size = sprite_pixel_size
		sprite.position.y = _get_grounded_sprite_y()
		sprite.modulate = BOSS_SPRITE_TINT
	if is_instance_valid(health_bar_sprite):
		health_bar_sprite.pixel_size = BOSS_HEALTH_BAR_RENDER_PIXEL_SIZE
		health_bar_sprite.position.y = _get_health_bar_height(is_in_group("boss"))
	if is_instance_valid(health_component):
		health_component.max_health = max_health
		health_component.current_health = max_health

func _apply_boss_stats() -> void:
	if _stats_applied:
		return
	_stats_applied = true
	max_health = boss_max_health
	attack_damage = boss_attack_damage
	speed = boss_speed
	attack_cooldown_time = boss_attack_cooldown_time
	attack_range = boss_attack_range
	detection_range = boss_detection_range

func _build_frame_manifest() -> void:
	_frames_by_state = {
		"idle": {
			VisualFacing.FRONT: _trimmed_grid_row_frames(IDLE_ATLAS_PATH, 0, 3, 4),
			VisualFacing.FRONT_DIAG: _trimmed_grid_row_frames(IDLE_ATLAS_PATH, 0, 3, 4),
			VisualFacing.SIDE: _trimmed_grid_row_frames(IDLE_ATLAS_PATH, 1, 3, 4),
			VisualFacing.BACK_DIAG: _trimmed_grid_row_frames(IDLE_ATLAS_PATH, 2, 3, 4),
			VisualFacing.BACK: _trimmed_grid_row_frames(IDLE_ATLAS_PATH, 2, 3, 4),
		},
		"walk": {
			WALK_DIR_UP: BOSS_WALK_UP_RECTS,
			WALK_DIR_LEFT: BOSS_WALK_SIDE_RECTS,
			WALK_DIR_DOWN: BOSS_WALK_DOWN_RECTS,
			WALK_DIR_RIGHT: BOSS_WALK_SIDE_RECTS,
		},
		"attack": {
			VisualFacing.FRONT: _trimmed_grid_row_frames(ATTACK_ATLAS_PATH, 0, 3, 4),
			VisualFacing.FRONT_DIAG: _trimmed_grid_row_frames(ATTACK_ATLAS_PATH, 0, 3, 4),
			VisualFacing.SIDE: _trimmed_grid_row_frames(ATTACK_ATLAS_PATH, 1, 3, 4),
			VisualFacing.BACK_DIAG: _trimmed_grid_row_frames(ATTACK_ATLAS_PATH, 2, 3, 3),
			VisualFacing.BACK: _trimmed_grid_row_frames(ATTACK_ATLAS_PATH, 2, 3, 3),
		},
		"hurt": {
			VisualFacing.FRONT: _trimmed_grid_row_frames(HURT_ATLAS_PATH, 0, 3, 4),
			VisualFacing.FRONT_DIAG: _trimmed_grid_row_frames(HURT_ATLAS_PATH, 0, 3, 4),
			VisualFacing.SIDE: _trimmed_grid_row_frames(HURT_ATLAS_PATH, 1, 3, 4),
			VisualFacing.BACK_DIAG: _trimmed_grid_row_frames(HURT_ATLAS_PATH, 2, 3, 4),
			VisualFacing.BACK: _trimmed_grid_row_frames(HURT_ATLAS_PATH, 2, 3, 4),
		},
		"death": {
			VisualFacing.FRONT: _trimmed_grid_row_frames(DEATH_ATLAS_PATH, 0, 3, 4),
			VisualFacing.FRONT_DIAG: _trimmed_grid_row_frames(DEATH_ATLAS_PATH, 0, 3, 4),
			VisualFacing.SIDE: _trimmed_grid_row_frames(DEATH_ATLAS_PATH, 1, 3, 4),
			VisualFacing.BACK_DIAG: _trimmed_grid_row_frames(DEATH_ATLAS_PATH, 2, 3, 4),
			VisualFacing.BACK: _trimmed_grid_row_frames(DEATH_ATLAS_PATH, 2, 3, 4),
		},
	}

func _grid_row_frames(atlas_path: String, row_index: int, rows: int, columns: int) -> Array:
	var frames: Array = []
	var atlas_texture := load(atlas_path) as Texture2D
	if atlas_texture == null or rows <= 0 or columns <= 0:
		return frames
	var atlas_size := atlas_texture.get_size()
	var cell_width := atlas_size.x / float(columns)
	var cell_height := atlas_size.y / float(rows)
	var y0 := int(round(row_index * cell_height))
	var y1 := int(round((row_index + 1) * cell_height)) - 1
	for index in range(columns):
		var x0 := int(round(index * cell_width))
		var x1 := int(round((index + 1) * cell_width)) - 1
		frames.append(Rect2(x0, y0, x1 - x0 + 1, y1 - y0 + 1))
	return frames

func _trimmed_grid_row_frames(atlas_path: String, row_index: int, rows: int, columns: int) -> Array:
	var frames := _grid_row_frames(atlas_path, row_index, rows, columns)
	var trimmed: Array = []
	for frame in frames:
		trimmed.append(_get_trimmed_rect(atlas_path, frame))
	return trimmed

func _get_trimmed_rect(atlas_path: String, rough_rect: Rect2) -> Rect2:
	var atlas_image: Image = _get_atlas_image(atlas_path)
	if atlas_image == null:
		return rough_rect
	var min_x := int(rough_rect.position.x + rough_rect.size.x)
	var max_x := int(rough_rect.position.x)
	var min_y := int(rough_rect.position.y + rough_rect.size.y)
	var max_y := int(rough_rect.position.y)
	for y in range(int(rough_rect.position.y), int(rough_rect.position.y + rough_rect.size.y)):
		for x in range(int(rough_rect.position.x), int(rough_rect.position.x + rough_rect.size.x)):
			if x < 0 or y < 0 or x >= atlas_image.get_width() or y >= atlas_image.get_height():
				continue
			if atlas_image.get_pixel(x, y).a <= 0.05:
				continue
			min_x = mini(min_x, x)
			max_x = maxi(max_x, x)
			min_y = mini(min_y, y)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return rough_rect
	return Rect2(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func _get_atlas_image(atlas_path: String) -> Image:
	if not _atlas_images.has(atlas_path):
		var atlas_texture := load(atlas_path) as Texture2D
		_atlas_images[atlas_path] = atlas_texture.get_image() if atlas_texture != null else null
	return _atlas_images.get(atlas_path) as Image

func _get_grounded_sprite_y() -> float:
	return _active_frame_size.y * sprite_pixel_size * 0.5 + SPRITE_GROUND_CLEARANCE

func _get_health_bar_height(is_boss: bool) -> float:
	if not is_boss:
		return super._get_health_bar_height(is_boss)
	return _get_grounded_sprite_y() + _active_frame_size.y * sprite_pixel_size + BOSS_HEALTH_BAR_TOP_MARGIN

func _update_visual_facing() -> void:
	if current_state == State.DEATH:
		return
	var look_dir := Vector3.ZERO
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if (current_state == State.CHASE or current_state == State.ATTACK) and player:
		look_dir = _get_planar_offset_to(player)
	elif velocity.length_squared() > 0.01:
		look_dir = velocity
	if look_dir.length_squared() <= 0.0001:
		return
	look_dir = look_dir.normalized()
	var abs_x := absf(look_dir.x)
	var abs_z := absf(look_dir.z)
	if abs_x >= 0.38 and abs_z >= 0.38:
		if look_dir.x < 0.0 and look_dir.z < 0.0:
			_walk_direction_key = WALK_DIR_UP if abs_z >= abs_x else WALK_DIR_LEFT
			_visual_facing = VisualFacing.BACK if abs_z >= abs_x else VisualFacing.SIDE
			_flip_h_visual = true
		elif look_dir.x > 0.0 and look_dir.z < 0.0:
			_walk_direction_key = WALK_DIR_UP if abs_z >= abs_x else WALK_DIR_RIGHT
			_visual_facing = VisualFacing.BACK if abs_z >= abs_x else VisualFacing.SIDE
			_flip_h_visual = false
		elif look_dir.x < 0.0 and look_dir.z >= 0.0:
			_walk_direction_key = WALK_DIR_DOWN if abs_z >= abs_x else WALK_DIR_LEFT
			_visual_facing = VisualFacing.FRONT if abs_z >= abs_x else VisualFacing.SIDE
			_flip_h_visual = true
		else:
			_walk_direction_key = WALK_DIR_DOWN if abs_z >= abs_x else WALK_DIR_RIGHT
			_visual_facing = VisualFacing.FRONT if abs_z >= abs_x else VisualFacing.SIDE
			_flip_h_visual = false
	elif abs_x > abs_z:
		if look_dir.x < 0.0:
			_walk_direction_key = WALK_DIR_LEFT
			_visual_facing = VisualFacing.SIDE
			_flip_h_visual = true
		else:
			_walk_direction_key = WALK_DIR_RIGHT
			_visual_facing = VisualFacing.SIDE
			_flip_h_visual = false
	elif look_dir.z >= 0.0:
		_walk_direction_key = WALK_DIR_DOWN
		_visual_facing = VisualFacing.FRONT
		_flip_h_visual = false
	else:
		_walk_direction_key = WALK_DIR_UP
		_visual_facing = VisualFacing.BACK
		_flip_h_visual = false

func _get_state_name() -> String:
	match current_state:
		State.IDLE:
			return "idle"
		State.WANDER, State.CHASE:
			return "walk"
		State.ATTACK:
			return "attack"
		State.HURT:
			return "hurt"
		State.DEATH:
			return "death"
	return "idle"

func _get_state_atlas_path(state_name: String) -> String:
	match state_name:
		"idle":
			return IDLE_ATLAS_PATH
		"walk":
			return WALK_ATLAS_PATH
		"attack":
			return ATTACK_ATLAS_PATH
		"hurt":
			return HURT_ATLAS_PATH
		"death":
			return DEATH_ATLAS_PATH
	return IDLE_ATLAS_PATH

func _get_frames_for_state(state_name: String) -> Array:
	if state_name == "walk":
		var walk_state_frames: Dictionary = _frames_by_state.get("walk", {})
		return walk_state_frames.get(_walk_direction_key, [])
	var state_frames: Dictionary = _frames_by_state.get(state_name, {})
	var facing_frames: Array = state_frames.get(_visual_facing, [])
	if not facing_frames.is_empty():
		return facing_frames
	for fallback in [VisualFacing.FRONT_DIAG, VisualFacing.FRONT, VisualFacing.SIDE, VisualFacing.BACK_DIAG, VisualFacing.BACK]:
		facing_frames = state_frames.get(fallback, [])
		if not facing_frames.is_empty():
			return facing_frames
	return []

func _update_animation(delta: float) -> void:
	_update_visual_facing()
	var state_name: String = _get_state_name()
	var frames: Array = _get_frames_for_state(state_name)
	var max_frames: int = maxi(1, frames.size())
	anim_fps = 6.0
	match current_state:
		State.IDLE:
			anim_fps = 5.0
		State.WANDER, State.CHASE:
			anim_fps = 8.0 if current_state == State.WANDER else 10.0
		State.ATTACK:
			anim_fps = attack_animation_fps
		State.HURT:
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
			hitbox_component.monitoring = (current_frame == clampi(int(max_frames / 2), 1, max_frames - 1))
	_update_sprite()

func _update_sprite() -> void:
	_update_visual_facing()
	var state_name: String = _get_state_name()
	var frames: Array = _get_frames_for_state(state_name)
	if frames.is_empty():
		return
	var frame_index: int = clampi(current_frame, 0, frames.size() - 1)
	var region: Rect2 = frames[frame_index]
	var atlas_path: String = _get_state_atlas_path(state_name)
	if not _texture_cache.has(atlas_path):
		_texture_cache[atlas_path] = load(atlas_path) as Texture2D
	var atlas: Texture2D = _texture_cache.get(atlas_path) as Texture2D
	if atlas == null:
		return
	sprite.texture = atlas
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.flip_h = _flip_h_visual if state_name != "walk" else _should_flip_walk_direction(_walk_direction_key)
	sprite.modulate = BOSS_SPRITE_TINT
	_active_frame_size = region.size
	sprite.position.y = _get_grounded_sprite_y()
	if is_instance_valid(health_bar_sprite):
		health_bar_sprite.pixel_size = BOSS_HEALTH_BAR_RENDER_PIXEL_SIZE
		health_bar_sprite.position.y = _get_health_bar_height(is_in_group("boss"))

func _should_flip_walk_direction(direction_key: String) -> bool:
	return direction_key == WALK_DIR_LEFT
