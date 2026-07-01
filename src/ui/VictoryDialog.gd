# src/ui/VictoryDialog.gd
# CanvasLayer độc lập - hiện lời chúc mừng khi người chơi đánh bại boss.
class_name VictoryDialog
extends CanvasLayer

const MAIN_MENU_SCENE_PATH := "res://src/ui/MainMenu.tscn"
const VICTORY_CHIME := preload("res://Assets/audio/scratchonix-victory-chime-366449.mp3")
const PANEL_WIDTH := 820.0
const PANEL_HEIGHT := 520.0
const CONTENT_WIDTH := 700.0
const THACH_SANH_STORY := """Chúc mừng! Bạn đã dũng cảm đánh bại Chằn Tinh, giải cứu dân làng khỏi nỗi khiếp sợ bấy lâu. Bằng lòng can đảm, sự kiên trì và những nhát kiếm chính xác, bạn đã chứng minh mình là một người anh hùng thực thụ.

Nhưng hành trình của Thạch Sanh vẫn chưa kết thúc. Phía trước còn nhiều thử thách và những bí mật đang chờ bạn khám phá. Hãy nghỉ ngơi, chuẩn bị hành trang và tiếp tục cuộc phiêu lưu để bảo vệ công lý và mang lại bình yên cho muôn dân.

Bạn đã hoàn thành màn chơi: Chằn Tinh! ✨"""

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
	_build_dialog()
	_play_victory_chime()

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
	panel.offset_left = -PANEL_WIDTH * 0.5
	panel.offset_right = PANEL_WIDTH * 0.5
	panel.offset_top = -PANEL_HEIGHT * 0.5
	panel.offset_bottom = PANEL_HEIGHT * 0.5
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var title := Label.new()
	title.name = "VictoryTitle"
	title.text = "Chúc mừng! Chằn Tinh đã bị tiêu diệt"
	title.custom_minimum_size = Vector2(CONTENT_WIDTH, 0.0)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.35))
	vbox.add_child(title)

	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.95, 0.74, 0.28, 0.45)
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.name = "StoryScroll"
	scroll.custom_minimum_size = Vector2(CONTENT_WIDTH, 300.0)
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
	body.add_theme_font_size_override("font_size", 20)
	body.add_theme_constant_override("line_separation", 7)
	body.add_theme_color_override("font_color", Color(0.92, 0.88, 0.74))
	scroll.add_child(body)

	var return_btn := Button.new()
	return_btn.name = "ReturnToMenuButton"
	return_btn.text = "TRỞ VỀ MENU"
	return_btn.custom_minimum_size = Vector2(230.0, 50.0)
	return_btn.add_theme_font_size_override("font_size", 18)
	return_btn.pressed.connect(_on_return_to_menu_pressed)
	vbox.add_child(return_btn)

	panel.modulate.a = 0.0
	panel.scale = Vector2(0.85, 0.85)
	panel.pivot_offset = Vector2(PANEL_WIDTH * 0.5, PANEL_HEIGHT * 0.5)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_overlay, "color", Color(0.0, 0.0, 0.0, 0.70), 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(panel, "modulate:a", 1.0, 0.30).set_trans(Tween.TRANS_SINE).set_delay(0.10)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.10)

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
