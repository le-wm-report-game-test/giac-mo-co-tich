# src/ui/DeathDialog.gd
# CanvasLayer độc lập – hiện dialog khi nhân vật chết.
# Lắng nghe EventBus.player_died, không can thiệp logic core.
class_name DeathDialog
extends CanvasLayer


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
	# ── Lớp phủ tối mờ ──────────────────────────────────────────
	_overlay = ColorRect.new()
	_overlay.name = "DeathOverlay"
	_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_overlay.anchor_right  = 1.0
	_overlay.anchor_bottom = 1.0
	add_child(_overlay)

	# ── Hộp thoại ───────────────────────────────────────────────
	var panel := PanelContainer.new()
	panel.name = "DeathPanel"
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color      = Color(0.06, 0.04, 0.04, 0.97)
	panel_style.border_color  = Color(0.72, 0.22, 0.18, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel_style.set_content_margin_all(36.0)
	panel_style.shadow_color = Color(0.6, 0.05, 0.05, 0.4)
	panel_style.shadow_size  = 20
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
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 22)
	panel.add_child(vbox)

	# ── Tiêu đề ─────────────────────────────────────────────────
	var skull := Label.new()
	skull.text = "💀"
	skull.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skull.add_theme_font_size_override("font_size", 52)
	vbox.add_child(skull)

	var title := Label.new()
	title.text = "Bạn Đã Ngã Xuống"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.30, 0.25))
	vbox.add_child(title)

	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.72, 0.22, 0.18, 0.45)
	sep_style.set_content_margin_all(0.0)
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	var sub := Label.new()
	sub.text = "Hành trình chưa kết thúc..."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.75, 0.65, 0.60))
	vbox.add_child(sub)

	# ── Hàng nút ────────────────────────────────────────────────
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 28)
	vbox.add_child(btn_row)

	var replay_style := _make_style(Color(0.12, 0.28, 0.14, 0.92), Color(0.45, 0.80, 0.42), 4)
	var replay_hover := _make_style(Color(0.16, 0.38, 0.18, 0.97), Color(0.65, 1.00, 0.60), 7)

	var btn_replay := Button.new()
	btn_replay.text = "⟳  Chơi Lại"
	btn_replay.custom_minimum_size = Vector2(200, 52)
	btn_replay.add_theme_stylebox_override("normal",  replay_style)
	btn_replay.add_theme_stylebox_override("hover",   replay_hover)
	btn_replay.add_theme_stylebox_override("pressed", replay_style)
	btn_replay.add_theme_stylebox_override("focus",   replay_hover)
	btn_replay.add_theme_color_override("font_color",       Color(0.85, 1.00, 0.85))
	btn_replay.add_theme_color_override("font_hover_color", Color.WHITE)
	btn_replay.add_theme_font_size_override("font_size", 18)
	btn_replay.pressed.connect(_on_replay_pressed)
	btn_row.add_child(btn_replay)

	# ── Animate in ──────────────────────────────────────────────
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

func _make_style(bg: Color, border: Color, shadow_sz: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color     = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	if shadow_sz > 0:
		s.shadow_color = Color(border.r, border.g, border.b, 0.25)
		s.shadow_size  = shadow_sz
	return s

func _on_replay_pressed() -> void:
	# Chơi lại màn hiện tại, nhân vật reset về spawn point
	get_tree().reload_current_scene()

