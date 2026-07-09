# src/ui/VictoryDialog.gd
# CanvasLayer độc lập - hiện lời chúc mừng khi người chơi đánh bại boss.
class_name VictoryDialog
extends CanvasLayer

const UITheme = preload("res://src/ui/ui_theme.gd")

const MAIN_MENU_SCENE_PATH := "res://src/ui/MainMenu.tscn"
const VICTORY_CHIME := preload("res://Assets/audio/scratchonix-victory-chime-366449.mp3")
const PANEL_WIDTH := 780.0
const PANEL_HEIGHT := 360.0
const CONTENT_WIDTH := 700.0
const THACH_SANH_STORY := "Chúc mừng! Bạn đã cùng Thạch Sanh đánh bại Chằn Tinh và đem lại bình yên cho dân làng.\n\nTừ khu rừng sâu cho tới mái nhà ven suối, câu chuyện về lòng dũng cảm ấy sẽ còn được kể lại như một truyền thuyết đẹp của đất Việt.\n\nHành trình vẫn chưa khép lại, nhưng chiến công này xứng đáng để người anh hùng dừng chân, lắng nghe tiếng rừng và ghi nhớ vì sao mình đã cầm kiếm bước đi."

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

	var panel := PanelContainer.new()
	panel.name = "VictoryPanel"
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_style())
	
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

	var title := Label.new()
	title.name = "VictoryTitle"
	title.text = "Chúc mừng chiến thắng"
	title.custom_minimum_size = Vector2(CONTENT_WIDTH, 0.0)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_heading(title, 30)
	vbox.add_child(title)

	var sep := UITheme.create_separator(16.0)
	sep.name = "HSeparator"
	vbox.add_child(sep)

	var summary := Label.new()
	summary.name = "VictorySummary"
	summary.text = "Bóng tối đã lùi bước, khu rừng trở lại yên bình."
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.custom_minimum_size = Vector2(CONTENT_WIDTH, 0.0)
	UITheme.apply_body(summary, 15, UITheme.BODY_MUTED_COLOR)
	vbox.add_child(summary)

	var scroll := ScrollContainer.new()
	scroll.name = "StoryScroll"
	scroll.custom_minimum_size = Vector2(CONTENT_WIDTH, 130.0)
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
	body.add_theme_constant_override("line_separation", 6)
	UITheme.apply_body(body, 16, Color(0.21, 0.18, 0.15))
	scroll.add_child(body)

	var return_btn := Button.new()
	return_btn.name = "ReturnToMenuButton"
	return_btn.text = "Trở về menu"
	return_btn.custom_minimum_size = Vector2(210.0, 46.0)
	UITheme.apply_button(return_btn)
	return_btn.pivot_offset = Vector2(105.0, 23.0)
	return_btn.pressed.connect(_on_return_to_menu_pressed)
	return_btn.mouse_entered.connect(func(): _tween_button_scale(return_btn, Vector2(1.05, 1.05)))
	return_btn.mouse_exited.connect(func(): _tween_button_scale(return_btn, Vector2.ONE))
	vbox.add_child(return_btn)
	
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.80, 0.80)
	panel.pivot_offset = Vector2(PANEL_WIDTH * 0.5, PANEL_HEIGHT * 0.5)
	
	title.modulate.a = 0.0
	sep.modulate.a = 0.0
	summary.modulate.a = 0.0
	scroll.modulate.a = 0.0
	return_btn.modulate.a = 0.0

	var tw := create_tween().set_parallel(true)
	tw.tween_property(_overlay, "color", Color(0.02, 0.02, 0.02, 0.75), 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(panel, "modulate:a", 1.0, 0.30).set_trans(Tween.TRANS_SINE).set_delay(0.05)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.05)

	var seq := create_tween()
	seq.tween_property(title, "modulate:a", 1.0, 0.20).set_delay(0.3)
	seq.tween_property(sep, "modulate:a", 1.0, 0.15)
	seq.tween_property(summary, "modulate:a", 1.0, 0.20)
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
