# src/ui/VictoryDialog.gd
# CanvasLayer độc lập - hiện lời chúc mừng khi người chơi đánh bại boss.
class_name VictoryDialog
extends CanvasLayer

const MAIN_MENU_SCENE_PATH := "res://src/ui/MainMenu.tscn"
const VICTORY_CHIME := preload("res://Assets/audio/scratchonix-victory-chime-366449.mp3")
const PANEL_WIDTH := 780.0
const PANEL_HEIGHT := 400.0
const CONTENT_WIDTH := 700.0
const THACH_SANH_STORY := "Chúc mừng! Bạn đã dũng cảm cùng Thạch Sanh đánh bại Chằn Tinh, giải cứu dân làng.\nHành trình truyền thuyết vẫn đang tiếp diễn! ✨"

var _overlay: Control = null
var _chime_player: AudioStreamPlayer = null

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
		
	# Tạm dừng game để đảm bảo an toàn cho người chơi và tránh bị quái tấn công
	get_tree().paused = true
	
	# Ẩn DeathDialog nếu đang hiển thị để tránh chồng đè UI
	var death_dialog = get_parent().get_node_or_null("DeathDialog")
	if death_dialog:
		var death_overlay = death_dialog.get_node_or_null("DeathOverlay")
		if death_overlay:
			death_overlay.visible = false
			
	_build_dialog()
	_play_victory_chime()

func _build_dialog() -> void:
	# Lớp phủ mờ nền
	_overlay = ColorRect.new()
	_overlay.name = "VictoryOverlay"
	_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_overlay.anchor_right = 1.0
	_overlay.anchor_bottom = 1.0
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	# Bảng chính - Giấy Cuộn Thần Thoại Việt
	var panel := PanelContainer.new()
	panel.name = "VictoryPanel"
	
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.98, 0.96, 0.90, 0.98) # Màu giấy cuộn nâu be ấm áp
	panel_style.border_color = Color(0.65, 0.18, 0.15, 0.95) # Đỏ son truyền thống đậm
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	panel_style.set_content_margin_all(28.0)
	panel_style.shadow_color = Color(0.15, 0.10, 0.08, 0.35) # Bóng đổ nâu ấm sâu
	panel_style.shadow_size = 18
	panel.add_theme_stylebox_override("panel", panel_style)
	
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_left = -PANEL_WIDTH * 0.5
	panel.offset_right = PANEL_WIDTH * 0.5
	panel.offset_top = -PANEL_HEIGHT * 0.5
	panel.offset_bottom = PANEL_HEIGHT * 0.5
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	# Tiêu đề Chiến thắng
	var title := Label.new()
	title.name = "VictoryTitle"
	title.text = "CHIẾN THẮNG!"
	title.custom_minimum_size = Vector2(CONTENT_WIDTH, 0.0)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.65, 0.18, 0.15)) # Đỏ son nổi bật
	vbox.add_child(title)

	var sep := HSeparator.new()
	sep.name = "HSeparator"
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.80, 0.65, 0.30, 0.6) # Đường kẻ vàng đồng nhạt
	sep_style.set_border_width_all(1)
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	# Bảng thống kê phần thưởng (Rewards/Stats)
	var rewards_hbox := HBoxContainer.new()
	rewards_hbox.name = "RewardsHBox"
	rewards_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	rewards_hbox.add_theme_constant_override("separation", 32)
	vbox.add_child(rewards_hbox)

	var gold_label := Label.new()
	gold_label.name = "GoldLabel"
	gold_label.text = "🪙 Vàng nhận: +150 Vàng"
	gold_label.add_theme_font_size_override("font_size", 16)
	gold_label.add_theme_color_override("font_color", Color(0.33, 0.25, 0.15)) # Nâu đồng đậm
	rewards_hbox.add_child(gold_label)

	var exp_label := Label.new()
	exp_label.name = "ExpLabel"
	exp_label.text = "✨ Kinh nghiệm: +500 EXP"
	exp_label.add_theme_font_size_override("font_size", 16)
	exp_label.add_theme_color_override("font_color", Color(0.15, 0.35, 0.20)) # Xanh ngọc sẫm
	rewards_hbox.add_child(exp_label)

	# Cốt truyện cổ tích cuộn
	var scroll := ScrollContainer.new()
	scroll.name = "StoryScroll"
	scroll.custom_minimum_size = Vector2(CONTENT_WIDTH, 110.0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var body := RichTextLabel.new()
	body.name = "VictoryBody"
	body.bbcode_enabled = false
	body.fit_content = true
	body.scroll_active = false
	body.text = THACH_SANH_STORY
	body.custom_minimum_size = Vector2(CONTENT_WIDTH, 0.0)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 16)
	body.add_theme_constant_override("line_separation", 6)
	body.add_theme_color_override("font_color", Color(0.20, 0.15, 0.12)) # Nâu đất trầm ấm cổ xưa
	scroll.add_child(body)

	# Nút Trở về Menu
	var return_btn := Button.new()
	return_btn.name = "ReturnToMenuButton"
	return_btn.text = "TRỞ VỀ MENU"
	return_btn.custom_minimum_size = Vector2(210.0, 46.0)
	return_btn.add_theme_font_size_override("font_size", 16)
	
	# Thiết lập kiểu dáng nút đồng bộ màu sắc đỏ son + vàng kim
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.65, 0.18, 0.15)
	btn_normal.border_color = Color(0.80, 0.65, 0.30)
	btn_normal.set_border_width_all(2)
	btn_normal.set_corner_radius_all(6)
	
	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.78, 0.22, 0.18)
	btn_hover.border_color = Color(0.95, 0.85, 0.40)
	btn_hover.set_border_width_all(2)
	btn_hover.set_corner_radius_all(6)
	
	return_btn.add_theme_stylebox_override("normal", btn_normal)
	return_btn.add_theme_stylebox_override("hover", btn_hover)
	return_btn.add_theme_stylebox_override("pressed", btn_normal)
	return_btn.add_theme_stylebox_override("focus", btn_hover)
	return_btn.add_theme_color_override("font_color", Color(0.98, 0.96, 0.90))
	return_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	
	return_btn.pivot_offset = Vector2(105.0, 23.0) # Đặt tâm pivot ở giữa nút để tween scale từ giữa
	return_btn.pressed.connect(_on_return_to_menu_pressed)
	return_btn.mouse_entered.connect(func(): _tween_button_scale(return_btn, Vector2(1.05, 1.05)))
	return_btn.mouse_exited.connect(func(): _tween_button_scale(return_btn, Vector2.ONE))
	vbox.add_child(return_btn)

	# Thiết lập trạng thái ẩn ban đầu để chạy hiệu ứng mượt mà
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.80, 0.80)
	panel.pivot_offset = Vector2(PANEL_WIDTH * 0.5, PANEL_HEIGHT * 0.5)
	
	title.modulate.a = 0.0
	sep.modulate.a = 0.0
	rewards_hbox.modulate.a = 0.0
	scroll.modulate.a = 0.0
	return_btn.modulate.a = 0.0

	# Chạy hiệu ứng song song (Overlay và Panel chính)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_overlay, "color", Color(0.02, 0.02, 0.02, 0.75), 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(panel, "modulate:a", 1.0, 0.30).set_trans(Tween.TRANS_SINE).set_delay(0.05)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.05)

	# Chạy hiệu ứng tuần tự xuất hiện các phần tử bên trong (Staggered Fade-in)
	var seq := create_tween()
	seq.tween_property(title, "modulate:a", 1.0, 0.20).set_delay(0.3)
	seq.tween_property(sep, "modulate:a", 1.0, 0.15)
	seq.tween_property(rewards_hbox, "modulate:a", 1.0, 0.20)
	seq.tween_property(scroll, "modulate:a", 1.0, 0.20)
	seq.tween_property(return_btn, "modulate:a", 1.0, 0.15)

func _tween_button_scale(btn: Button, target_scale: Vector2) -> void:
	var tw := create_tween()
	tw.tween_property(btn, "scale", target_scale, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _play_victory_chime() -> void:
	if _chime_player == null:
		_chime_player = AudioStreamPlayer.new()
		_chime_player.name = "VictoryChimePlayer"
		_chime_player.stream = VICTORY_CHIME
		_chime_player.bus = "Master"
		add_child(_chime_player)
	_chime_player.stop()
	_chime_player.play()

func _on_return_to_menu_pressed() -> void:
	get_tree().paused = false
	var err := get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
	if err != OK:
		push_error("Failed to load main menu scene after victory: %s" % error_string(err))
