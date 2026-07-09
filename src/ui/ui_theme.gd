class_name UITheme
extends RefCounted

const TEX_BTN_NORMAL: Texture2D = preload("res://Assets/SettingAssets/parts/10_button_normal_forest.png")
const TEX_BTN_HOVER: Texture2D = preload("res://Assets/SettingAssets/parts/11_button_hover_forest.png")
const TEX_PANEL_BG: Texture2D = preload("res://Assets/SettingAssets/parts/01_large_settings_panel.png")
const TEX_SEPARATOR: Texture2D = preload("res://Assets/SettingAssets/parts/27_decorative_separator.png")

const FONT_HEADING: Font = preload("res://Assets/UI/Fonts/CormorantSC/CormorantSC-SemiBold.ttf")
const FONT_HEADING_BOLD: Font = preload("res://Assets/UI/Fonts/CormorantSC/CormorantSC-Bold.ttf")
const FONT_BODY: Font = preload("res://Assets/UI/Fonts/BeVietnamPro/BeVietnamPro-Regular.ttf")
const FONT_BODY_MEDIUM: Font = preload("res://Assets/UI/Fonts/BeVietnamPro/BeVietnamPro-Medium.ttf")
const FONT_BODY_SEMIBOLD: Font = preload("res://Assets/UI/Fonts/BeVietnamPro/BeVietnamPro-SemiBold.ttf")

const GOLD_TEXT_COLOR := Color(0.92, 0.78, 0.4)
const GOLD_TEXT_HOVER_COLOR := Color(1.0, 0.9, 0.55)
const BODY_TEXT_COLOR := Color(0.93, 0.89, 0.8)
const BODY_MUTED_COLOR := Color(0.76, 0.71, 0.61)
const DANGER_COLOR := Color(0.68, 0.24, 0.18)

static func make_texture_stylebox(tex: Texture2D, left: int, top: int, right: int, bottom: int) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = left
	sb.texture_margin_top = top
	sb.texture_margin_right = right
	sb.texture_margin_bottom = bottom
	return sb

static func make_panel_style() -> StyleBoxTexture:
	var style := make_texture_stylebox(TEX_PANEL_BG, 30, 30, 30, 30)
	style.content_margin_left = 36
	style.content_margin_right = 36
	style.content_margin_top = 28
	style.content_margin_bottom = 24
	return style

static func apply_heading(label: Label, font_size: int = 28, centered: bool = true) -> void:
	label.add_theme_font_override("font", FONT_HEADING_BOLD)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", GOLD_TEXT_COLOR)
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

static func apply_body(label: Control, font_size: int = 16, color: Color = BODY_TEXT_COLOR) -> void:
	label.add_theme_font_override("normal_font", FONT_BODY)
	label.add_theme_font_override("bold_font", FONT_BODY_SEMIBOLD)
	label.add_theme_font_override("italics_font", FONT_BODY)
	label.add_theme_font_override("mono_font", FONT_BODY_MEDIUM)
	label.add_theme_font_override("font", FONT_BODY)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)

static func apply_button(button: Button, variant: String = "primary") -> void:
	button.add_theme_font_override("font", FONT_BODY_SEMIBOLD)
	button.add_theme_font_size_override("font_size", 16)

	var normal_style := make_texture_stylebox(TEX_BTN_NORMAL, 22, 20, 22, 20)
	var hover_style := make_texture_stylebox(TEX_BTN_HOVER, 22, 20, 22, 20)
	var disabled_style := normal_style.duplicate() as StyleBoxTexture

	if variant == "danger":
		var font_color := Color(1.0, 0.88, 0.78)
		var hover_color := Color(1.0, 0.95, 0.9)
		button.add_theme_color_override("font_color", font_color)
		button.add_theme_color_override("font_hover_color", hover_color)
		button.add_theme_color_override("font_pressed_color", hover_color)
	else:
		button.add_theme_color_override("font_color", GOLD_TEXT_COLOR)
		button.add_theme_color_override("font_hover_color", GOLD_TEXT_HOVER_COLOR)
		button.add_theme_color_override("font_pressed_color", GOLD_TEXT_HOVER_COLOR)
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.51, 0.45))
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", hover_style)
	button.add_theme_stylebox_override("focus", hover_style)
	button.add_theme_stylebox_override("disabled", disabled_style)

static func create_separator(height: float = 18.0) -> TextureRect:
	var separator := TextureRect.new()
	separator.texture = TEX_SEPARATOR
	separator.stretch_mode = TextureRect.STRETCH_SCALE
	separator.custom_minimum_size = Vector2(0.0, height)
	separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return separator
