class_name MainMenuGuideDialog
extends CanvasLayer

const UITheme = preload("res://src/ui/ui_theme.gd")

var _return_focus: Button = null
var _close_button: Button = null


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	hide()


func open(return_focus: Button) -> void:
	_return_focus = return_focus
	show()
	_close_button.grab_focus()


func close() -> void:
	hide()
	if is_instance_valid(_return_focus):
		_return_focus.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.name = "GuideOverlay"
	overlay.color = Color(0.02, 0.02, 0.02, 0.78)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var panel := PanelContainer.new()
	panel.name = "GuidePanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_left = -310.0
	panel.offset_top = -235.0
	panel.offset_right = 310.0
	panel.offset_bottom = 235.0
	panel.custom_minimum_size = Vector2(620.0, 470.0)
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_style())
	overlay.add_child(panel)

	var content := VBoxContainer.new()
	content.name = "GuideContent"
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)

	var title := Label.new()
	title.name = "GuideTitle"
	title.text = "HƯỚNG DẪN HÀNH TRÌNH"
	UITheme.apply_heading(title, 28)
	content.add_child(title)
	content.add_child(UITheme.create_separator(16.0))
	content.add_child(_create_section_title("Điều khiển"))
	content.add_child(_create_guide_row("W A S D", "Di chuyển trong khu rừng"))
	content.add_child(_create_guide_row("Chuột trái / Space", "Tấn công theo hướng đang đối mặt"))
	content.add_child(_create_guide_row("ESC", "Tạm dừng và mở cài đặt"))
	content.add_child(_create_guide_row("Chạm vào thức ăn", "Tự động nhặt và nhận hiệu ứng"))
	content.add_child(UITheme.create_separator(12.0))
	content.add_child(_create_section_title("Mục tiêu"))

	var objective := Label.new()
	objective.name = "ObjectiveText"
	objective.text = "Hạ đủ 5 Orc để triệu hồi Chằn Tinh, sau đó đánh bại hắn để giải cứu khu rừng."
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective.custom_minimum_size = Vector2(500.0, 54.0)
	UITheme.apply_body(objective, 16, UITheme.BODY_TEXT_COLOR)
	content.add_child(objective)

	_close_button = Button.new()
	_close_button.name = "CloseGuideButton"
	_close_button.text = "Đã hiểu"
	_close_button.custom_minimum_size = Vector2(210.0, 46.0)
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UITheme.apply_button(_close_button)
	_close_button.pressed.connect(close)
	content.add_child(_close_button)


func _create_section_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	UITheme.apply_heading(label, 20)
	return label


func _create_guide_row(key_text: String, description: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var key_label := Label.new()
	key_label.text = key_text
	key_label.custom_minimum_size = Vector2(190.0, 30.0)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.apply_body(key_label, 16, UITheme.GOLD_TEXT_COLOR)
	row.add_child(key_label)
	var description_label := Label.new()
	description_label.text = description
	description_label.custom_minimum_size = Vector2(300.0, 30.0)
	UITheme.apply_body(description_label, 16, UITheme.BODY_TEXT_COLOR)
	row.add_child(description_label)
	return row
