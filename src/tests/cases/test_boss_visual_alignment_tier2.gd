# res://src/tests/cases/test_boss_visual_alignment_tier2.gd
extends "res://src/tests/base_test_case.gd"

const ALPHA_THRESHOLD: float = 0.05
const BODY_COLOR_VARIANCE: float = 0.08
const MAX_BODY_VALUE: float = 0.92
const BODY_WINDOW_RATIO: float = 0.3
const MIN_BODY_HALF_WIDTH: float = 18.0
const FOOT_BAND_RATIO: float = 0.12
const MIN_FOOT_BAND_PIXELS: int = 4

var _player: Player = null


func setup() -> void:
	await super.setup()
	_player = tree.get_first_node_in_group("player") as Player
	assert_not_null(_player, "Player must exist")
	for candidate: Node in tree.get_nodes_in_group("orc_mobs"):
		if candidate is OrcMob:
			candidate.set_physics_process(false)


func test_walk_side_frames_exclude_detached_bottom_fragments() -> void:
	var boss := await _spawn_boss()
	var walk_states: Dictionary = boss._frames_by_state.get("walk", {})
	var frames: Array = walk_states.get(OrcBossMob.WALK_DIR_RIGHT, [])
	assert_eq(frames.size(), 4, "Boss side walk must keep four frames")
	for frame: Rect2 in frames:
		assert_eq(int(frame.position.y), 137, "Side walk frame must start on the body row")
		assert_eq(int(frame.size.y), 99, "Side walk frame must exclude detached pixels below the feet")


func test_attack_side_frames_exclude_detached_top_fragments() -> void:
	var boss := await _spawn_boss()
	var attack_states: Dictionary = boss._frames_by_state.get("attack", {})
	var frames: Array = attack_states.get(OrcBossMob.VisualFacing.SIDE, [])
	var expected_starts := [162, 145, 159, 162]
	assert_eq(frames.size(), expected_starts.size(), "Boss side attack must keep four frames")
	for frame_index in range(frames.size()):
		var frame: Rect2 = frames[frame_index]
		assert_eq(int(frame.position.y), expected_starts[frame_index], "Attack crop must start at the primary alpha run")
		assert_eq(int(frame.position.y + frame.size.y), 272, "Attack crop must end at the grounded body run")


func test_body_anchor_matches_physics_origin_in_all_cardinal_directions() -> void:
	var boss := await _spawn_boss()
	var directions := [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]
	var state_names := ["idle", "walk", "attack", "hurt"]
	var state_values := [OrcMob.State.IDLE, OrcMob.State.CHASE, OrcMob.State.ATTACK, OrcMob.State.HURT]
	var worst_error := 0.0
	var worst_frame := ""
	for target_direction in directions:
		_player.global_position = boss.global_position + target_direction * 3.0
		boss.velocity = target_direction
		boss._committed_attack_direction = target_direction
		for state_index in range(state_names.size()):
			boss.current_state = state_values[state_index]
			var frames: Array = boss._get_frames_for_state(state_names[state_index])
			for frame_index in range(frames.size()):
				boss.current_frame = frame_index
				boss._update_sprite()
				boss._update_sprite_height()
				var error := _measure_body_anchor_error(boss.sprite)
				if error > worst_error:
					worst_error = error
					worst_frame = "%s[%d] direction=%s" % [
						state_names[state_index],
						frame_index,
						target_direction,
					]
	assert_true(
		worst_error <= 0.08,
		"Boss body anchor must stay within 8cm of physics origin; %s drifts %.2fm" % [worst_frame, worst_error]
	)


func _spawn_boss() -> OrcBossMob:
	var boss := OrcBossMob.new()
	boss.add_to_group("boss")
	boss.add_to_group("orc_mobs")
	world_instance.add_child(boss)
	boss.set_physics_process(false)
	await tree.physics_frame
	return boss


func _measure_body_anchor_error(sprite: Sprite3D) -> float:
	var region := sprite.region_rect
	var visible_pixels := _collect_visible_pixels(sprite.texture.get_image(), region)
	assert_true(not visible_pixels.is_empty(), "Boss frame must contain visible pixels")
	if visible_pixels.is_empty():
		return INF
	var body_pixels := _filter_body_pixels(sprite.texture.get_image(), visible_pixels)
	if body_pixels.is_empty():
		body_pixels = visible_pixels
	var torso_center_x := _get_torso_center_x(body_pixels, region)
	var half_width := maxf(MIN_BODY_HALF_WIDTH, region.size.x * BODY_WINDOW_RATIO)
	var ground_y := -INF
	for point: Vector2i in visible_pixels:
		if absf(float(point.x) - torso_center_x) <= half_width:
			ground_y = maxf(ground_y, float(point.y))
	var foot_start := ground_y - maxi(MIN_FOOT_BAND_PIXELS, int(region.size.y * FOOT_BAND_RATIO))
	var weighted_x := 0.0
	var pixel_count := 0
	for point: Vector2i in visible_pixels:
		if float(point.y) >= foot_start and absf(float(point.x) - torso_center_x) <= half_width:
			weighted_x += point.x
			pixel_count += 1
	var foot_x := weighted_x / float(pixel_count)
	var source_delta_x := foot_x - (region.position.x + region.size.x * 0.5)
	var rendered_x := sprite.offset.x + (-source_delta_x if sprite.flip_h else source_delta_x)
	var local_ground_y := ground_y - region.position.y
	var rendered_ground_y := sprite.position.y + (
		sprite.offset.y + region.size.y * 0.5 - local_ground_y
	) * sprite.pixel_size
	return maxf(
		absf(rendered_x) * sprite.pixel_size,
		absf(rendered_ground_y - OrcMob.SPRITE_GROUND_CLEARANCE)
	)


func _collect_visible_pixels(image: Image, region: Rect2) -> Array[Vector2i]:
	var pixels: Array[Vector2i] = []
	var x_start := clampi(int(region.position.x), 0, image.get_width())
	var x_end := clampi(int(region.position.x + region.size.x), x_start, image.get_width())
	var y_start := clampi(int(region.position.y), 0, image.get_height())
	var y_end := clampi(int(region.position.y + region.size.y), y_start, image.get_height())
	for y in range(y_start, y_end):
		for x in range(x_start, x_end):
			if image.get_pixel(x, y).a > ALPHA_THRESHOLD:
				pixels.append(Vector2i(x, y))
	return pixels


func _filter_body_pixels(image: Image, visible_pixels: Array[Vector2i]) -> Array[Vector2i]:
	var body_pixels: Array[Vector2i] = []
	for point: Vector2i in visible_pixels:
		var color := image.get_pixelv(point)
		var brightest := maxf(color.r, maxf(color.g, color.b))
		var darkest := minf(color.r, minf(color.g, color.b))
		if brightest - darkest > BODY_COLOR_VARIANCE and brightest < MAX_BODY_VALUE:
			body_pixels.append(point)
	return body_pixels


func _get_torso_center_x(body_pixels: Array[Vector2i], region: Rect2) -> float:
	var torso_top := region.position.y + region.size.y * 0.2
	var torso_bottom := region.position.y + region.size.y * 0.68
	var torso_x: Array[int] = []
	for point: Vector2i in body_pixels:
		if float(point.y) >= torso_top and float(point.y) <= torso_bottom:
			torso_x.append(point.x)
	if torso_x.is_empty():
		for point: Vector2i in body_pixels:
			torso_x.append(point.x)
	torso_x.sort()
	var middle := torso_x.size() / 2
	if torso_x.size() % 2 == 1:
		return float(torso_x[middle])
	return (float(torso_x[middle - 1]) + float(torso_x[middle])) * 0.5
