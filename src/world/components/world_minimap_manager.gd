extends Node

const MinimapScript := preload("res://src/ui/minimap.gd")
const FRAME_TEXTURE_PATH := "res://Assets/items/map.png"
const FRAME_TEXTURE_SIZE := Vector2(500.0, 500.0)
const SCREEN_SIZE := Vector2(120.0, 120.0)
const INNER_POSITION := Vector2(58.0, 58.0)
const INNER_SIZE := Vector2(379.0, 379.0)
const ZOOM_SCALE := 2.6
const ZOOM_DURATION := 0.25
const UPDATE_INTERVAL := 0.1

var _owner: Node = null
var _minimap: Minimap = null
var _container: Control = null
var _zoomed: bool = false
var _update_timer: float = 0.0


func setup(owner: Node) -> void:
	_owner = owner


func build(ui: CanvasLayer) -> void:
	_container = Control.new()
	_container.name = "MinimapContainer"
	_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_container.offset_left = -SCREEN_SIZE.x - 20.0
	_container.offset_top = 20.0
	_container.offset_right = -20.0
	_container.offset_bottom = 20.0 + SCREEN_SIZE.y
	_container.custom_minimum_size = SCREEN_SIZE
	_container.pivot_offset = Vector2(SCREEN_SIZE.x, 0.0)
	_container.offset_transform_enabled = true
	_container.offset_transform_scale = Vector2.ONE
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_container)
	_add_frame()
	_add_map()
	_refresh_layout()
	_owner.set("minimap", _minimap)
	_owner.set("minimap_container", _container)


func toggle_zoom() -> void:
	if not is_instance_valid(_container):
		return
	_zoomed = not _zoomed
	_owner.set("minimap_zoomed", _zoomed)
	var target := Vector2.ONE * (ZOOM_SCALE if _zoomed else 1.0)
	var tween := create_tween()
	tween.tween_property(_container, "offset_transform_scale", target, ZOOM_DURATION).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_OUT)


func update(delta: float, force: bool = false) -> void:
	_update_timer -= delta
	if not force and _update_timer > 0.0:
		return
	_update_timer = UPDATE_INTERVAL
	if not is_instance_valid(_minimap):
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	_refresh_layout()
	var markers: Array[Dictionary] = []
	for candidate in get_tree().get_nodes_in_group("orc_mobs"):
		if is_orc_marker(candidate) and is_orc_attacking(candidate):
			markers.append({
				"position": (candidate as Node3D).global_position,
				"marker_type": (
					Minimap.MARKER_BOSS
					if candidate.is_in_group("boss")
					else Minimap.MARKER_ORC
				),
			})
	for candidate in get_tree().get_nodes_in_group("food_items"):
		if candidate is Node3D and is_instance_valid(candidate) and (candidate as Node3D).visible:
			markers.append({
				"position": (candidate as Node3D).global_position,
				"marker_type": Minimap.MARKER_ITEM,
			})
	_minimap.update_positions(player.global_position, markers)


func is_orc_attacking(candidate: Variant) -> bool:
	if not is_instance_valid(candidate):
		return false
	var state := int(candidate.get("current_state"))
	return state == 2 or state == 3


func is_orc_marker(candidate: Variant) -> bool:
	if not is_instance_valid(candidate) or not (candidate is Node3D):
		return false
	if candidate.is_in_group("animals") or candidate.is_in_group("cats"):
		return false
	return candidate is OrcMob


func _add_frame() -> void:
	var frame := TextureRect.new()
	frame.name = "MinimapFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.texture = load(FRAME_TEXTURE_PATH) as Texture2D
	_container.add_child(frame)


func _add_map() -> void:
	var scale_ratio := SCREEN_SIZE.x / FRAME_TEXTURE_SIZE.x
	var mask := Control.new()
	mask.name = "MinimapMask"
	mask.position = (INNER_POSITION * scale_ratio).round()
	mask.size = (INNER_SIZE * scale_ratio).round()
	mask.custom_minimum_size = mask.size
	mask.clip_contents = true
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.add_child(mask)
	_owner.set("minimap_mask", mask)
	_minimap = MinimapScript.new() as Minimap
	_minimap.name = "Minimap"
	_minimap.show_panel_background = false
	_minimap.show_panel_border = false
	mask.add_child(_minimap)
	_minimap.setup(mask.size)
	_minimap.position = Vector2.ZERO


func _refresh_layout() -> void:
	if not is_instance_valid(_container):
		return
	_container.size = SCREEN_SIZE
	_container.custom_minimum_size = SCREEN_SIZE
	_container.pivot_offset = Vector2(SCREEN_SIZE.x, 0.0)
	var scale_ratio := SCREEN_SIZE.x / FRAME_TEXTURE_SIZE.x
	var mask := _container.get_node_or_null("MinimapMask") as Control
	if mask:
		mask.position = (INNER_POSITION * scale_ratio).round()
		mask.size = (INNER_SIZE * scale_ratio).round()
		mask.custom_minimum_size = mask.size
	if is_instance_valid(_minimap):
		_minimap.setup(mask.size if mask else SCREEN_SIZE)
