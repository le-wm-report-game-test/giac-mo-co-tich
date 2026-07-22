extends RefCounted

const UIThemeScript := preload("res://src/ui/ui_theme.gd")
const FillShader := preload("res://src/world/components/player_health_fill.gdshader")

const HUD_TEXTURE_PATH := "res://Assets/items/hud_and_orc_panel_v1.png"
const HUD_TEXTURE_SIZE := Vector2(568.0, 439.0)
const HUD_TARGET_WIDTH := 290.0
const FILL_POSITION := Vector2(113.0, 111.0)
const FILL_SIZE := Vector2(429.0, 81.0)
const FILL_COLOR := Color(0.82, 0.0, 0.02, 1.0)
const COUNTER_POSITION := Vector2(24.0, 235.0)
const COUNTER_SIZE := Vector2(207.0, 69.0)
const COUNTER_RIGHT_PADDING := 16.0


static func build(ui: CanvasLayer, owner: Node) -> void:
	var texture := load(HUD_TEXTURE_PATH) as Texture2D
	var hud_scale := HUD_TARGET_WIDTH / HUD_TEXTURE_SIZE.x
	var screen_size := (HUD_TEXTURE_SIZE * hud_scale).round()
	var fill_position := (FILL_POSITION * hud_scale).round()
	var fill_size := (FILL_SIZE * hud_scale).round().max(Vector2.ONE)
	var container := _create_container(ui, screen_size)
	_add_background(container, texture)
	var fill := _add_fill(container, texture, fill_position, fill_size)
	var bar := _add_semantic_bar(container, fill_position, fill_size)
	_add_health_text(container, hud_scale)
	_add_orc_counter(ui, owner, container.position, hud_scale)
	owner.set("player_health_fill", fill)
	owner.set("player_health_bar", bar)


static func _create_container(ui: CanvasLayer, screen_size: Vector2) -> Control:
	var container := Control.new()
	container.name = "PlayerHealthContainer"
	container.position = Vector2(20.0, 20.0)
	container.custom_minimum_size = screen_size
	container.size = screen_size
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ui.add_child(container)
	return container


static func _add_background(container: Control, texture: Texture2D) -> void:
	var background := TextureRect.new()
	background.name = "PlayerHealthBackground"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.texture = texture
	container.add_child(background)


static func _add_fill(
	container: Control,
	texture: Texture2D,
	fill_position: Vector2,
	fill_size: Vector2
) -> ColorRect:
	var mask := Control.new()
	mask.name = "PlayerHealthMask"
	mask.position = fill_position
	mask.size = fill_size
	mask.clip_contents = true
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(mask)
	var fill := ColorRect.new()
	fill.name = "PlayerHealthFill"
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fill.color = Color.TRANSPARENT
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.material = _create_fill_material(texture, fill_size)
	mask.add_child(fill)
	return fill


static func _create_fill_material(texture: Texture2D, fill_size: Vector2) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FillShader
	material.set_shader_parameter("bar_size", fill_size)
	material.set_shader_parameter("mask_texture", texture)
	material.set_shader_parameter("mask_texture_size", HUD_TEXTURE_SIZE)
	material.set_shader_parameter("mask_region_position", FILL_POSITION)
	material.set_shader_parameter("mask_region_size", FILL_SIZE)
	material.set_shader_parameter("fill_color", FILL_COLOR)
	material.set_shader_parameter("fill_ratio", 1.0)
	return material


static func _add_semantic_bar(
	container: Control,
	fill_position: Vector2,
	fill_size: Vector2
) -> TextureProgressBar:
	var bar := TextureProgressBar.new()
	bar.name = "PlayerHealthBar"
	bar.position = fill_position
	bar.size = fill_size
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.visible = false
	container.add_child(bar)
	return bar


static func _add_health_text(container: Control, hud_scale: float) -> void:
	var text := Label.new()
	text.name = "PlayerHealthText"
	text.text = "100 / 100"
	text.position = Vector2(116.0, 86.0) * hud_scale
	text.custom_minimum_size = Vector2(152.0, 28.0) * hud_scale
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_font_override("font", UIThemeScript.FONT_BODY_SEMIBOLD)
	text.add_theme_font_size_override("font_size", maxi(12, roundi(16.0 * hud_scale)))
	text.visible = false
	container.add_child(text)


static func _add_orc_counter(
	ui: CanvasLayer,
	owner: Node,
	container_position: Vector2,
	hud_scale: float
) -> void:
	var counter := Control.new()
	counter.name = "OrcCounter"
	counter.position = container_position + COUNTER_POSITION * hud_scale
	counter.size = COUNTER_SIZE * hud_scale
	counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(counter)
	var label := Label.new()
	label.name = "OrcCountLabel"
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_right -= COUNTER_RIGHT_PADDING
	label.text = "Đã hạ %d" % int(owner.get("orcs_killed"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UIThemeScript.FONT_BODY_SEMIBOLD)
	label.add_theme_font_size_override("font_size", maxi(11, roundi(15.0 * hud_scale)))
	counter.add_child(label)
