# main_menu.gd
class_name MainMenu
extends Control

# Hằng số đường dẫn tài nguyên do người dùng cung cấp
const GAME_SCENE_PATH: String = "res://src/world/world.tscn"
const LEGACY_GAME_SCENE_PATH: String = "res://Scenes/Game.tscn"
const LOADING_SCENE_PATH: String = "res://src/ui/LoadingScreen.tscn"
const BG_PATH: String = "res://Assets/OpenScreenAssets/Background_Screen.png"
const BTN_START_PATH: String = "res://Assets/OpenScreenAssets/Start_Button.png"
const BTN_CONTINUE_PATH: String = "res://Assets/OpenScreenAssets/Continue_Button.png"
const BTN_SETTINGS_PATH: String = "res://Assets/OpenScreenAssets/Setting_Button.png"
const BTN_QUIT_PATH: String = "res://Assets/OpenScreenAssets/Quit_Button.png"


@export var hover_sfx: AudioStream = preload("res://Assets/audio/Select_Sound.mp3")
@export var bg_music: AudioStream = preload("res://Assets/audio/intro.mp3")

var sfx_player: AudioStreamPlayer = null
var _music_player: AudioStreamPlayer = null
var _settings_menu_instance: SettingsMenu = null
var bg: TextureRect = null
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
	container.offset_top = -40
	container.offset_right = 200
	container.offset_bottom = 360
	add_child(container)
	
	# 3. Tạo Music Player
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.stream = bg_music
	_music_player.volume_db = -10.0
	add_child(_music_player)
	if bg_music:
		if bg_music is AudioStreamMP3:
			(bg_music as AudioStreamMP3).loop = true
		_music_player.play()

	# 4. Tạo SFX Player động
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
	# Bấm Bắt Đầu là vào game ngay, xoá luôn tiến độ cũ nếu có
	if SaveManager.has_save():
		SaveManager.delete_save()
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

	EventBus.set_meta("loading_target_scene", scene_path)
	var err := get_tree().change_scene_to_file(LOADING_SCENE_PATH)
	if err == OK:
		return true

	EventBus.remove_meta("loading_target_scene")
	_scene_change_in_progress = false
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
