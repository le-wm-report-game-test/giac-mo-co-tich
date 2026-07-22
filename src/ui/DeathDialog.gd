# src/ui/DeathDialog.gd
# CanvasLayer độc lập – hiện dialog khi nhân vật chết.
# Lắng nghe EventBus.player_died, không can thiệp logic core.
class_name DeathDialog
extends CanvasLayer

const UITheme = preload("res://src/ui/ui_theme.gd")

const MAIN_MENU_SCENE_PATH := "res://src/ui/MainMenu.tscn"

var _overlay: Control = null

func _ready() -> void:
	layer = 20  # Trên HUD (layer 10)
	# Lắng nghe sự kiện chết của nhân vật
	EventBus.player_died.connect(_on_player_died)

func _on_player_died() -> void:
	# Tránh tạo dialog nhiều lần
	if _overlay != null:
		return
	_build_dialog()

func _build_dialog() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "DeathOverlay"
	_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_overlay.anchor_right  = 1.0
	_overlay.anchor_bottom = 1.0
	add_child(_overlay)

	var panel := PanelContainer.new()
	panel.name = "DeathPanel"
	var panel_style := UITheme.make_panel_style()
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.anchor_left   = 0.5
	panel.anchor_top    = 0.5
	panel.anchor_right  = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
	panel.offset_left   = -260.0
	panel.offset_right  =  260.0
	panel.offset_top    = -150.0
	panel.offset_bottom =  150.0
	_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Bạn Đã Ngã Xuống"
	UITheme.apply_heading(title, 28)
	title.add_theme_color_override("font_color", Color(0.97, 0.78, 0.68))
	vbox.add_child(title)

	var sep := UITheme.create_separator(14.0)
	vbox.add_child(sep)

	var sub := Label.new()
	sub.text = "Hành trình chưa kết thúc. Hãy đứng dậy hoặc trở về menu để chuẩn bị lại."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(420.0, 0.0)
	UITheme.apply_body(sub, 15, UITheme.BODY_MUTED_COLOR)
	vbox.add_child(sub)

	var stats := Label.new()
	stats.name = "RunStats"
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_body(stats, 15, Color(0.92, 0.78, 0.4))
	vbox.add_child(stats)
	_animate_run_stats(stats)

	var btn_row := HBoxContainer.new()
	btn_row.name = "HBoxContainer"
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var btn_replay := Button.new()
	btn_replay.name = "ReplayButton"
	btn_replay.text = "Chơi lại"
	btn_replay.custom_minimum_size = Vector2(200, 52)
	UITheme.apply_button(btn_replay)
	btn_replay.pressed.connect(_on_replay_pressed)
	btn_row.add_child(btn_replay)

	var btn_menu := Button.new()
	btn_menu.name = "MenuButton"
	btn_menu.text = "Về menu"
	btn_menu.custom_minimum_size = Vector2(200, 52)
	UITheme.apply_button(btn_menu, "danger")
	btn_menu.pressed.connect(_on_menu_pressed)
	btn_row.add_child(btn_menu)

	panel.modulate.a = 0.0
	panel.scale = Vector2(0.80, 0.80)
	panel.pivot_offset = Vector2(260.0, 150.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_overlay, "color", Color(0.0, 0.0, 0.0, 0.72), 0.40)\
		.set_trans(Tween.TRANS_SINE)
	tw.tween_property(panel, "modulate:a", 1.0, 0.35)\
		.set_trans(Tween.TRANS_SINE).set_delay(0.15)
	tw.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.30)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.15)

func _format_run_stats(orcs: int, elapsed: float) -> String:
	var total_seconds := int(elapsed)
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60
	return "Đã hạ %d Orc · Sống sót %dp %02ds" % [orcs, minutes, seconds]

func _animate_run_stats(label: Label) -> void:
	var world_manager := get_tree().get_first_node_in_group("world_manager")
	var orcs := int(world_manager.get("orcs_killed")) if world_manager else 0
	var elapsed := float(world_manager.get("run_elapsed")) if world_manager else 0.0
	label.text = _format_run_stats(0, 0.0)
	var tw := create_tween()
	tw.tween_method(
		func(t: float) -> void:
			label.text = _format_run_stats(roundi(orcs * t), elapsed * t),
		0.0, 1.0, 0.6
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.3)

func _on_replay_pressed() -> void:
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
