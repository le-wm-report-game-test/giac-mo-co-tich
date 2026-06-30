# src/ui/VictoryDialog.gd
# CanvasLayer độc lập - hiện lời chúc mừng khi người chơi đánh bại boss.
class_name VictoryDialog
extends CanvasLayer

const MAIN_MENU_SCENE_PATH := "res://src/ui/MainMenu.tscn"

@export var return_delay: float = 3.0
@export var auto_return_to_menu: bool = true

var _overlay: Control = null

func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.connect(_on_enemy_died)

func _on_enemy_died(enemy: Node3D) -> void:
	if enemy == null or not enemy.is_in_group("boss"):
		return
	if _overlay != null:
		return
	_build_dialog()
	if auto_return_to_menu:
		_return_to_main_menu_after_delay()

func _build_dialog() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "VictoryOverlay"
	_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_overlay.anchor_right = 1.0
	_overlay.anchor_bottom = 1.0
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var panel := PanelContainer.new()
	panel.name = "VictoryPanel"
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.12, 0.07, 0.97)
	panel_style.border_color = Color(0.95, 0.74, 0.28, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel_style.set_content_margin_all(36.0)
	panel_style.shadow_color = Color(0.95, 0.74, 0.28, 0.22)
	panel_style.shadow_size = 20
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_left = -330.0
	panel.offset_right = 330.0
	panel.offset_top = -150.0
	panel.offset_bottom = 150.0
	_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)

	var title := Label.new()
	title.name = "VictoryTitle"
	title.text = "Chúc mừng!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.35))
	vbox.add_child(title)

	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.95, 0.74, 0.28, 0.45)
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	var body := Label.new()
	body.name = "VictoryBody"
	body.text = "Bạn đã đánh bại Chằn Tinh!\nTrở về đầu trang game..."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.add_theme_font_size_override("font_size", 20)
	body.add_theme_color_override("font_color", Color(0.92, 0.88, 0.74))
	vbox.add_child(body)

	panel.modulate.a = 0.0
	panel.scale = Vector2(0.85, 0.85)
	panel.pivot_offset = Vector2(330.0, 150.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_overlay, "color", Color(0.0, 0.0, 0.0, 0.70), 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(panel, "modulate:a", 1.0, 0.30).set_trans(Tween.TRANS_SINE).set_delay(0.10)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.10)

func _return_to_main_menu_after_delay() -> void:
	get_tree().paused = false
	await get_tree().create_timer(return_delay).timeout
	get_tree().paused = false
	var err := get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
	if err != OK:
		push_error("Failed to load main menu scene after victory: %s" % error_string(err))
