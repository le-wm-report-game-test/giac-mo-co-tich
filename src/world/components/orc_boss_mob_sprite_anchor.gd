class_name OrcBossSpriteAnchor
extends RefCounted

const ALPHA_THRESHOLD: float = 0.05
const BODY_COLOR_VARIANCE: float = 0.08
const MAX_BODY_VALUE: float = 0.92
const TORSO_TOP_RATIO: float = 0.2
const TORSO_BOTTOM_RATIO: float = 0.68
const BODY_WINDOW_RATIO: float = 0.3
const MIN_BODY_HALF_WIDTH: float = 18.0
const FOOT_BAND_RATIO: float = 0.12
const MIN_FOOT_BAND_PIXELS: int = 4

var _anchor_cache: Dictionary = {}


func get_primary_vertical_rect(atlas_image: Image, rough_rect: Rect2) -> Rect2:
	if atlas_image == null or rough_rect.size.x <= 0.0 or rough_rect.size.y <= 0.0:
		return rough_rect
	var x_start := clampi(int(rough_rect.position.x), 0, atlas_image.get_width())
	var x_end := clampi(int(rough_rect.position.x + rough_rect.size.x), x_start, atlas_image.get_width())
	var y_start := clampi(int(rough_rect.position.y), 0, atlas_image.get_height())
	var y_end := clampi(int(rough_rect.position.y + rough_rect.size.y), y_start, atlas_image.get_height())
	var best_start := y_start
	var best_end := y_end - 1
	var best_area := -1
	var run_start := -1
	var run_area := 0
	for y in range(y_start, y_end):
		var row_area := 0
		for x in range(x_start, x_end):
			if atlas_image.get_pixel(x, y).a > ALPHA_THRESHOLD:
				row_area += 1
		if row_area > 0:
			if run_start < 0:
				run_start = y
			run_area += row_area
		elif run_start >= 0:
			if run_area > best_area:
				best_start = run_start
				best_end = y - 1
				best_area = run_area
			run_start = -1
			run_area = 0
	if run_start >= 0 and run_area > best_area:
		best_start = run_start
		best_end = y_end - 1
		best_area = run_area
	if best_area < 0:
		return rough_rect
	return Rect2(rough_rect.position.x, best_start, rough_rect.size.x, best_end - best_start + 1)



func get_frame_offset(
	atlas_path: String,
	atlas_image: Image,
	region: Rect2,
	flip_h: bool
) -> Vector2:
	if atlas_image == null or region.size.x <= 0.0 or region.size.y <= 0.0:
		return Vector2.ZERO
	var anchor := _get_body_anchor(atlas_path, atlas_image, region)
	var center_x := region.position.x + region.size.x * 0.5
	var source_delta_x := anchor.x - center_x
	var local_ground_y := anchor.y - region.position.y
	var ground_offset_y := local_ground_y - region.size.y * 0.5
	return Vector2(source_delta_x if flip_h else -source_delta_x, ground_offset_y)


func _get_body_anchor(atlas_path: String, atlas_image: Image, region: Rect2) -> Vector2:
	var key := _make_cache_key(atlas_path, region)
	if not _anchor_cache.has(key):
		_anchor_cache[key] = _measure_body_anchor(atlas_image, region)
	return _anchor_cache.get(key, region.position + region.size * 0.5)


func _make_cache_key(atlas_path: String, region: Rect2) -> String:
	return "%s:%d:%d:%d:%d" % [
		atlas_path,
		int(region.position.x),
		int(region.position.y),
		int(region.size.x),
		int(region.size.y),
	]


func _measure_body_anchor(atlas_image: Image, region: Rect2) -> Vector2:
	var visible_pixels := _collect_visible_pixels(atlas_image, region)
	if visible_pixels.is_empty():
		return region.position + Vector2(region.size.x * 0.5, region.size.y - 1.0)
	var body_pixels := _filter_body_pixels(atlas_image, visible_pixels)
	if body_pixels.is_empty():
		body_pixels = visible_pixels
	var torso_center_x := _get_torso_center_x(body_pixels, region)
	var half_width := maxf(MIN_BODY_HALF_WIDTH, region.size.x * BODY_WINDOW_RATIO)
	var ground_y := -INF
	for point: Vector2i in visible_pixels:
		if absf(float(point.x) - torso_center_x) <= half_width:
			ground_y = maxf(ground_y, float(point.y))
	if is_inf(ground_y):
		return region.position + Vector2(region.size.x * 0.5, region.size.y - 1.0)
	var foot_start := ground_y - maxi(MIN_FOOT_BAND_PIXELS, int(region.size.y * FOOT_BAND_RATIO))
	var weighted_x := 0.0
	var pixel_count := 0
	for point: Vector2i in visible_pixels:
		if float(point.y) >= foot_start and absf(float(point.x) - torso_center_x) <= half_width:
			weighted_x += point.x
			pixel_count += 1
	var foot_x := weighted_x / float(pixel_count) if pixel_count > 0 else torso_center_x
	return Vector2(foot_x, ground_y)


func _collect_visible_pixels(atlas_image: Image, region: Rect2) -> Array[Vector2i]:
	var pixels: Array[Vector2i] = []
	var x_start := clampi(int(region.position.x), 0, atlas_image.get_width())
	var x_end := clampi(int(region.position.x + region.size.x), x_start, atlas_image.get_width())
	var y_start := clampi(int(region.position.y), 0, atlas_image.get_height())
	var y_end := clampi(int(region.position.y + region.size.y), y_start, atlas_image.get_height())
	for y in range(y_start, y_end):
		for x in range(x_start, x_end):
			if atlas_image.get_pixel(x, y).a > ALPHA_THRESHOLD:
				pixels.append(Vector2i(x, y))
	return pixels


func _filter_body_pixels(atlas_image: Image, visible_pixels: Array[Vector2i]) -> Array[Vector2i]:
	var body_pixels: Array[Vector2i] = []
	for point: Vector2i in visible_pixels:
		var color := atlas_image.get_pixelv(point)
		var brightest := maxf(color.r, maxf(color.g, color.b))
		var darkest := minf(color.r, minf(color.g, color.b))
		if brightest - darkest > BODY_COLOR_VARIANCE and brightest < MAX_BODY_VALUE:
			body_pixels.append(point)
	return body_pixels


func _get_torso_center_x(body_pixels: Array[Vector2i], region: Rect2) -> float:
	var torso_top := region.position.y + region.size.y * TORSO_TOP_RATIO
	var torso_bottom := region.position.y + region.size.y * TORSO_BOTTOM_RATIO
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
