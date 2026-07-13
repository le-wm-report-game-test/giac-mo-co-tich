class_name BossHealthBar
extends Control

const FADE_OUT_DURATION: float = 0.6
const BAR_WIDTH: float = 600.0
const BAR_HEIGHT: float = 28.0
const BAR_MARGIN_TOP: float = 16.0
const NAME_FONT_SIZE: int = 24
const NAME_ROW_HEIGHT: float = 34.0
const NAME_BAR_GAP: float = 6.0
const BAR_CONTENT_TOP: float = NAME_ROW_HEIGHT + NAME_BAR_GAP
const HUD_HEIGHT: float = BAR_CONTENT_TOP + BAR_HEIGHT
const NAME_OUTLINE: int = 5
const NAME_COLOR := Color(0.96, 0.92, 0.82)
const NAME_OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.9)
const BAR_BACK_COLOR := Color(0.08, 0.04, 0.04, 0.82)
const BAR_FILL_COLOR := Color(0.85, 0.18, 0.12, 1.0)

var _health_component: HealthComponent = null
var _boss_node: Node3D = null
var _bar: TextureProgressBar
var _name_label: Label
var _background: ColorRect
var _border: ColorRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -BAR_WIDTH * 0.5
	offset_right = BAR_WIDTH * 0.5
	offset_top = BAR_MARGIN_TOP
	offset_bottom = BAR_MARGIN_TOP + HUD_HEIGHT
	custom_minimum_size = Vector2(BAR_WIDTH, HUD_HEIGHT)
	pivot_offset = Vector2(BAR_WIDTH * 0.5, HUD_HEIGHT * 0.5)
	_build_children()
	hide()

func attach(boss: Node3D, display_name: String) -> void:
	if not is_instance_valid(boss):
		return
	_boss_node = boss
	_health_component = boss.get_node_or_null("HealthComponent") as HealthComponent
	if _health_component == null and "health_component" in boss:
		_health_component = boss.get("health_component") as HealthComponent
	if _health_component == null:
		push_warning("BossHealthBar.attach: boss has no HealthComponent")
		return
	_name_label.text = display_name
	_bar.min_value = 0.0
	_bar.max_value = _health_component.max_health
	_bar.value = _health_component.current_health
	_health_component.health_changed.connect(_on_health_changed)
	_health_component.died.connect(_on_boss_died)
	show()

func detach() -> void:
	if _health_component and is_instance_valid(_health_component):
		if _health_component.health_changed.is_connected(_on_health_changed):
			_health_component.health_changed.disconnect(_on_health_changed)
		if _health_component.died.is_connected(_on_boss_died):
			_health_component.died.disconnect(_on_boss_died)
	_health_component = null
	_boss_node = null

func _build_children() -> void:
	_build_background()
	_build_fill_bar()
	_build_name_label()

func _build_background() -> void:
	_background = ColorRect.new()
	_background.name = "BossBarBackground"
	_background.color = BAR_BACK_COLOR
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.offset_left = 0.0
	_background.offset_top = BAR_CONTENT_TOP
	_background.offset_right = 0.0
	_background.offset_bottom = 0.0
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	var inner_border := ColorRect.new()
	inner_border.name = "BossBarBorder"
	inner_border.color = Color(0.0, 0.0, 0.0, 1.0)
	inner_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner_border.offset_left = 0.0
	inner_border.offset_top = BAR_CONTENT_TOP
	inner_border.offset_right = 0.0
	inner_border.offset_bottom = 0.0
	inner_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(inner_border)
	_border = inner_border

func _build_fill_bar() -> void:
	_bar = TextureProgressBar.new()
	_bar.name = "BossBarFill"
	_bar.min_value = 0.0
	_bar.max_value = 100.0
	_bar.value = 100.0
	_bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bar.offset_left = 0.0
	_bar.offset_top = BAR_CONTENT_TOP
	_bar.offset_right = 0.0
	_bar.offset_bottom = -1.0
	_bar.tint_under = Color(1.0, 1.0, 1.0, 0.0)
	_bar.tint_progress = BAR_FILL_COLOR
	_bar.tint_over = Color(1.0, 1.0, 1.0, 0.0)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.texture_under = _solid_texture(Color(0.0, 0.0, 0.0, 0.0), Vector2i(2, 2))
	# Use a full-size texture so Godot stretches the red fill across the bar
	# instead of rendering only the source texture's tiny 2x2 area.
	_bar.texture_progress = _solid_texture(BAR_FILL_COLOR, Vector2i(int(BAR_WIDTH), int(BAR_HEIGHT)))
	_bar.texture_over = _solid_texture(Color(0.0, 0.0, 0.0, 0.0), Vector2i(2, 2))
	add_child(_bar)

func _build_name_label() -> void:
	_name_label = Label.new()
	_name_label.name = "BossBarName"
	_name_label.text = ""
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_name_label.offset_left = 0.0
	_name_label.offset_right = 0.0
	_name_label.offset_top = 0.0
	_name_label.offset_bottom = NAME_ROW_HEIGHT
	_name_label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	_name_label.add_theme_color_override("font_color", NAME_COLOR)
	_name_label.add_theme_font_override("font", preload("res://src/ui/ui_theme.gd").FONT_HEADING)
	_name_label.add_theme_constant_override("outline_size", NAME_OUTLINE)
	_name_label.add_theme_color_override("font_outline_color", NAME_OUTLINE_COLOR)
	_name_label.add_theme_constant_override("shadow_offset_x", 0)
	_name_label.add_theme_constant_override("shadow_offset_y", 2)
	_name_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.42))
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)

func _on_health_changed(current: float, max_h: float) -> void:
	if not is_instance_valid(_bar):
		return
	_bar.max_value = max_h
	_bar.value = current

func _on_boss_died() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_DURATION)
	tween.tween_callback(queue_free)

func _solid_texture(color: Color, size: Vector2i) -> ImageTexture:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
