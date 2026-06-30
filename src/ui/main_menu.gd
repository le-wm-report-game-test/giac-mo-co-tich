# main_menu.gd
class_name MainMenu
extends Control

# Hằng số đường dẫn tài nguyên do người dùng cung cấp
const GAME_SCENE_PATH: String = "res://src/world/world.tscn"
const LEGACY_GAME_SCENE_PATH: String = "res://Scenes/Game.tscn"
const BG_PATH: String = "res://Assets/OpenScreenAssets/Background_Screen.png"
const BTN_START_PATH: String = "res://Assets/OpenScreenAssets/Start_Button.png"
const BTN_CONTINUE_PATH: String = "res://Assets/OpenScreenAssets/Continue_Button.png"
const BTN_SETTINGS_PATH: String = "res://Assets/OpenScreenAssets/Setting_Button.png"
const BTN_QUIT_PATH: String = "res://Assets/OpenScreenAssets/Quit_Button.png"


@export var hover_sfx: AudioStream = preload("res://Assets/audio/Select_Sound.mp3")

var sfx_player: AudioStreamPlayer = null
var _settings_menu_instance: SettingsMenu = null
var bg: TextureRect = null
var _new_game_dialog: Control = null
var _loading_overlay: Control = null
var _scene_change_in_progress: bool = false

func _ready() -> void:
	
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	
	resized.connect(_on_resized)
	
	
	bg = TextureRect.new()
	bg.name = "Background"
	
	var bg_tex: Texture2D = load(BG_PATH) as Texture2D
	if bg_tex != null:
		bg.texture = bg_tex
	else:
		push_warning("Không tìm thấy ảnh nền tại: %s. Đang dùng nền màu xám mặc định." % BG_PATH)
		var placeholder_bg := ColorRect.new()
		placeholder_bg.color = Color(0.12, 0.12, 0.14)
		placeholder_bg.anchor_right = 1.0
		placeholder_bg.anchor_bottom = 1.0
		bg.add_child(placeholder_bg)
		
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)
	
	# Khởi tạo kích thước nền dựa trên kích thước màn hình hiện tại
	_update_background_size()
	
	# 2. Tạo VBoxContainer chứa các nút bấm
	var container: VBoxContainer = VBoxContainer.new()
	container.name = "ButtonContainer"
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 20)
	
	# Căn giữa container trên màn hình
	container.anchor_left = 0.5
	container.anchor_top = 0.5
	container.anchor_right = 0.5
	container.anchor_bottom = 0.5
	container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	container.grow_vertical = Control.GROW_DIRECTION_BOTH
	container.custom_minimum_size = Vector2(400, 400)
	container.offset_left = -200
	container.offset_top = -100
	container.offset_right = 200
	container.offset_bottom = 300
	add_child(container)
	
	# 3. Tạo SFX Player động
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	sfx_player.volume_db = -10.0
	add_child(sfx_player)
	
	# 4. Định nghĩa dữ liệu nút bấm
	var buttons_data: Array[Dictionary] = [
		{"name": "Start",    "label": "BẮT ĐẦU / START",     "texture": BTN_START_PATH,    "pressed": _on_play_pressed},
		{"name": "Continue", "label": "TIẾP TỤC / CONTINUE", "texture": BTN_CONTINUE_PATH, "pressed": _on_continue_pressed},
		{"name": "Settings", "label": "CÀI ĐẶT / SETTINGS",  "texture": BTN_SETTINGS_PATH, "pressed": _on_settings_pressed},
		{"name": "Quit",     "label": "THOÁT / QUIT",        "texture": BTN_QUIT_PATH,     "pressed": _on_quit_pressed}
	]
	
	# 5. Sinh nút bấm động và kết nối sự kiện
	var normal_box := _create_style(Color(0.12, 0.22, 0.14, 0.75), Color(0.76, 0.64, 0.38, 0.8))
	var hover_box := _create_style(Color(0.18, 0.32, 0.20, 0.85), Color(0.95, 0.82, 0.53, 1.0), 5)
	var pressed_box := _create_style(Color(0.08, 0.15, 0.10, 0.9), Color(0.60, 0.50, 0.30, 0.8))
	
	for data in buttons_data:
		var btn: Control = null
		var normal_tex := load(data["texture"]) as Texture2D if data["texture"] != "" and ResourceLoader.exists(data["texture"]) else null
		if normal_tex:
			var tex_btn := TextureButton.new()
			tex_btn.texture_normal = normal_tex
			tex_btn.ignore_texture_size = true
			tex_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			var ts: Vector2 = normal_tex.get_size()
			# Nếu có target_height, cố định height rồi tính width theo tỷ lệ ảnh
			if data.has("target_height"):
				var h: float = float(data["target_height"])
				tex_btn.custom_minimum_size = Vector2(h * ts.x / ts.y, h)
			else:
				tex_btn.custom_minimum_size = Vector2(412.0, 412.0 * ts.y / ts.x)
			btn = tex_btn
		else:
			var std_btn := Button.new()
			std_btn.text = data["label"]
			std_btn.custom_minimum_size = Vector2(280, 55)
			std_btn.add_theme_stylebox_override("normal", normal_box)
			std_btn.add_theme_stylebox_override("hover", hover_box)
			std_btn.add_theme_stylebox_override("pressed", pressed_box)
			std_btn.add_theme_stylebox_override("focus", hover_box)
			std_btn.add_theme_color_override("font_color", Color(0.95, 0.85, 0.70))
			std_btn.add_theme_color_override("font_hover_color", Color.WHITE)
			std_btn.add_theme_font_size_override("font_size", 18)
			std_btn.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.05, 0.9))
			std_btn.add_theme_constant_override("outline_size", 5)
			btn = std_btn
		btn.name = data["name"]
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(data["pressed"])
		btn.mouse_entered.connect(_on_button_hover.bind(btn, true))
		btn.mouse_exited.connect(_on_button_hover.bind(btn, false))
		btn.focus_entered.connect(_on_button_hover.bind(btn, true))
		btn.focus_exited.connect(_on_button_hover.bind(btn, false))
		btn.pivot_offset = btn.custom_minimum_size / 2.0
		container.add_child(btn)

func _create_style(bg_col: Color, border_col: Color, shadow: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg_col
	s.border_color = border_col
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	if shadow > 0:
		s.shadow_color = Color(border_col.r, border_col.g, border_col.b, 0.2)
		s.shadow_size = shadow
	return s

func _on_button_hover(button: Control, is_hovered: bool) -> void:
	button.pivot_offset = button.size / 2.0
	var tween: Tween = create_tween().set_parallel(true)
	var target_scale: Vector2 = Vector2(1.08, 1.08) if is_hovered else Vector2(1.0, 1.0)
	var target_color: Color = Color(1.15, 1.15, 1.15) if is_hovered else Color.WHITE
	tween.tween_property(button, "scale", target_scale, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "modulate", target_color, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if is_hovered and hover_sfx and sfx_player:
		sfx_player.stream = hover_sfx
		sfx_player.play()

func _on_play_pressed() -> void:
	# Nếu có bản lưu cũ, hiện cảnh báo trước khi chơi mới
	if SaveManager.has_save():
		_show_new_game_warning()
		return
	_start_new_game()

func _start_new_game() -> void:
	await _change_to_game_scene(GAME_SCENE_PATH)

func _change_to_game_scene(requested_path: String) -> bool:
	if _scene_change_in_progress:
		return false

	var scene_path := _resolve_game_scene_path(requested_path)
	if scene_path.is_empty():
		push_error("Không tìm thấy scene game hợp lệ: %s" % requested_path)
		return false

	_scene_change_in_progress = true
	_show_loading_overlay()
	# Cho Godot render phản hồi click trước khi tải world đồng bộ.
	await get_tree().process_frame

	var err := get_tree().change_scene_to_file(scene_path)
	if err == OK:
		return true

	_scene_change_in_progress = false
	_hide_loading_overlay()
	push_error("Không thể vào game tại %s: %s" % [scene_path, error_string(err)])
	return false

func _resolve_game_scene_path(requested_path: String) -> String:
	if (
		requested_path != LEGACY_GAME_SCENE_PATH
		and ResourceLoader.exists(requested_path, "PackedScene")
	):
		return requested_path
	if ResourceLoader.exists(GAME_SCENE_PATH, "PackedScene"):
		return GAME_SCENE_PATH
	return ""

func _show_loading_overlay() -> void:
	if _loading_overlay != null:
		return

	var overlay := ColorRect.new()
	overlay.name = "LoadingOverlay"
	overlay.color = Color(0.02, 0.04, 0.025, 0.92)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var label := Label.new()
	label.text = "ĐANG VÀO GAME..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.53))
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(label)
	add_child(overlay)
	_loading_overlay = overlay

func _hide_loading_overlay() -> void:
	if _loading_overlay == null:
		return
	_loading_overlay.queue_free()
	_loading_overlay = null

# ── Hộp thoại cảnh báo chơi mới ──────────────────────────────────
func _show_new_game_warning() -> void:
	if _new_game_dialog != null:
		return

	# Lớp phủ tối phía sau
	var overlay := ColorRect.new()
	overlay.name = "NewGameDialogOverlay"
	overlay.color = Color(0.0, 0.0, 0.0, 0.65)
	overlay.anchor_right  = 1.0
	overlay.anchor_bottom = 1.0
	add_child(overlay)

	# Hộp thoại chính
	var dialog := PanelContainer.new()
	dialog.name = "NewGameDialog"
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color            = Color(0.08, 0.13, 0.09, 0.97)
	panel_style.border_color        = Color(0.76, 0.64, 0.38, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.set_content_margin_all(32.0)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	panel_style.shadow_size  = 12
	dialog.add_theme_stylebox_override("panel", panel_style)
	dialog.anchor_left   = 0.5
	dialog.anchor_top    = 0.5
	dialog.anchor_right  = 0.5
	dialog.anchor_bottom = 0.5
	dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dialog.grow_vertical   = Control.GROW_DIRECTION_BOTH
	dialog.offset_left  = -280.0
	dialog.offset_right =  280.0
	dialog.offset_top   = -130.0
	dialog.offset_bottom =  130.0
	overlay.add_child(dialog)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	dialog.add_child(vbox)

	# Tiêu đề
	var title := Label.new()
	title.text = "⚠  Chơi Mới?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.95, 0.80, 0.35))
	vbox.add_child(title)

	# Đường kẻ phân cách
	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.76, 0.64, 0.38, 0.4)
	sep_style.set_content_margin_all(0.0)
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	# Nội dung cảnh báo
	var body := Label.new()
	body.text = "Bạn đang có một tiến độ chơi dở dang.\nNếu bắt đầu mới, toàn bộ tiến độ cũ\nsẽ bị xoá vĩnh viễn!"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", Color(0.90, 0.85, 0.75))
	vbox.add_child(body)

	# Gợi ý tiếp tục
	var hint := Label.new()
	hint.text = "(Bấm TIẾP TỤC nếu muốn chơi tiếp)"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.65, 0.82, 0.65, 0.85))
	vbox.add_child(hint)

	# Hàng nút
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 24)
	vbox.add_child(btn_row)

	var confirm_style := _create_style(Color(0.55, 0.10, 0.08, 0.9),  Color(0.90, 0.35, 0.30), 4)
	var cancel_style  := _create_style(Color(0.10, 0.20, 0.12, 0.9),  Color(0.60, 0.80, 0.50), 4)
	var confirm_hover := _create_style(Color(0.70, 0.15, 0.10, 0.95), Color(1.00, 0.50, 0.45), 6)
	var cancel_hover  := _create_style(Color(0.15, 0.30, 0.18, 0.95), Color(0.80, 1.00, 0.70), 6)

	var btn_confirm := Button.new()
	btn_confirm.text = "Chơi Mới"
	btn_confirm.custom_minimum_size = Vector2(150, 46)
	btn_confirm.add_theme_stylebox_override("normal",  confirm_style)
	btn_confirm.add_theme_stylebox_override("hover",   confirm_hover)
	btn_confirm.add_theme_stylebox_override("pressed", confirm_style)
	btn_confirm.add_theme_stylebox_override("focus",   confirm_hover)
	btn_confirm.add_theme_color_override("font_color",       Color(1.0, 0.88, 0.85))
	btn_confirm.add_theme_color_override("font_hover_color", Color.WHITE)
	btn_confirm.add_theme_font_size_override("font_size", 17)
	btn_confirm.pressed.connect(_on_new_game_confirmed)
	btn_row.add_child(btn_confirm)

	var btn_cancel := Button.new()
	btn_cancel.text = "Huỷ"
	btn_cancel.custom_minimum_size = Vector2(150, 46)
	btn_cancel.add_theme_stylebox_override("normal",  cancel_style)
	btn_cancel.add_theme_stylebox_override("hover",   cancel_hover)
	btn_cancel.add_theme_stylebox_override("pressed", cancel_style)
	btn_cancel.add_theme_stylebox_override("focus",   cancel_hover)
	btn_cancel.add_theme_color_override("font_color",       Color(0.85, 0.95, 0.85))
	btn_cancel.add_theme_color_override("font_hover_color", Color.WHITE)
	btn_cancel.add_theme_font_size_override("font_size", 17)
	btn_cancel.pressed.connect(_on_new_game_cancelled)
	btn_row.add_child(btn_cancel)

	_new_game_dialog = overlay
	# Animate in
	dialog.modulate.a = 0.0
	dialog.scale = Vector2(0.85, 0.85)
	dialog.pivot_offset = Vector2(280.0, 130.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(dialog, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE)
	tw.tween_property(dialog, "scale",      Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _close_new_game_dialog() -> void:
	if _new_game_dialog != null:
		_new_game_dialog.queue_free()
		_new_game_dialog = null

func _on_new_game_confirmed() -> void:
	_close_new_game_dialog()
	SaveManager.delete_save()
	_start_new_game()

func _on_new_game_cancelled() -> void:
	_close_new_game_dialog()

func _on_continue_pressed() -> void:
	# Tránh connect nhiều lần nếu bấm nút liên tục
	if not SaveManager.load_completed.is_connected(_on_load_completed):
		SaveManager.load_completed.connect(_on_load_completed)
	SaveManager.load_progress()

func _on_settings_pressed() -> void:
	if _settings_menu_instance == null:
		_settings_menu_instance = SettingsMenu.new()
		add_child(_settings_menu_instance)
	_settings_menu_instance.toggle_menu()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_load_completed(data: Dictionary, success: bool) -> void:
	# Disconnect ngay để tránh bị gọi lại nhiều lần
	if SaveManager.load_completed.is_connected(_on_load_completed):
		SaveManager.load_completed.disconnect(_on_load_completed)

	if not success:
		push_warning("SaveManager: chưa có tiến độ – bắt đầu game mới.")
		_on_play_pressed()
		return

	# Lưu dữ liệu save vào SaveManager để world có thể đọc sau khi load
	SaveManager.set_meta("pending_restore", data)

	var scene_path: String = data.get("scene_path", GAME_SCENE_PATH)
	var scene_changed := await _change_to_game_scene(scene_path)
	if not scene_changed:
		SaveManager.remove_meta("pending_restore")

func _apply_loaded_state(_data: Dictionary) -> void:
	pass  # Không còn dùng; việc restore do GameStateRestorer trong world.gd xử lý

func _on_resized() -> void:
	_update_background_size()

func _update_background_size() -> void:
	if not bg:
		return
	if not bg.texture:
		bg.anchor_left = 0.0
		bg.anchor_top = 0.0
		bg.anchor_right = 1.0
		bg.anchor_bottom = 1.0
		bg.offset_left = 0
		bg.offset_top = 0
		bg.offset_right = 0
		bg.offset_bottom = 0
		return
	bg.anchor_left = 0.0
	bg.anchor_top = 0.0
	bg.anchor_right = 0.0
	bg.anchor_bottom = 0.0
	var tex_size: Vector2 = bg.texture.get_size()
	var screen_size: Vector2 = size
	var target_width: float
	var target_height: float
	if tex_size.x > screen_size.x or tex_size.y > screen_size.y:
		target_width = screen_size.x
		target_height = screen_size.x * (tex_size.y / tex_size.x)
	else:
		target_width = tex_size.x
		target_height = tex_size.y
	bg.size = Vector2(target_width, target_height)
	bg.position = (screen_size - bg.size) / 2.0
