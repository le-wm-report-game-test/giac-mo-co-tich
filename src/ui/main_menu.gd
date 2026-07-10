# main_menu.gd
class_name MainMenu
extends Control

const UITheme = preload("res://src/ui/ui_theme.gd")
const SettingsMenuScript = preload("res://src/common/settings_menu.gd")

# Hằng số đường dẫn tài nguyên do người dùng cung cấp
const GAME_SCENE_PATH: String = "res://src/world/world.tscn"
const LEGACY_GAME_SCENE_PATH: String = "res://Scenes/Game.tscn"
const LOADING_SCENE_PATH: String = "res://src/ui/LoadingScreen.tscn"
const BG_PATH: String = "res://Assets/OpenScreenAssets/Background_Screen.png"
const BUTTON_WIDTH: float = 280.0
const BUTTON_HEIGHT: float = 50.0

@export var hover_sfx: AudioStream = preload("res://Assets/audio/Select_Sound.mp3")
@export var bg_music: AudioStream = preload("res://Assets/audio/intro.mp3")

var sfx_player: AudioStreamPlayer = null
var _music_player: AudioStreamPlayer = null
var _settings_menu_instance: CanvasLayer = null
var bg: TextureRect = null
var _scene_change_in_progress: bool = false
var _continue_button: Button = null
var _continue_hint: Label = null

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
	_update_background_size()

	var button_backdrop := PanelContainer.new()
	button_backdrop.name = "ButtonBackdrop"
	button_backdrop.anchor_left = 0.5
	button_backdrop.anchor_top = 0.5
	button_backdrop.anchor_right = 0.5
	button_backdrop.anchor_bottom = 0.5
	button_backdrop.grow_horizontal = Control.GROW_DIRECTION_BOTH
	button_backdrop.grow_vertical = Control.GROW_DIRECTION_BOTH
	button_backdrop.offset_left = -210
	button_backdrop.offset_top = 50
	button_backdrop.offset_right = 210
	button_backdrop.offset_bottom = 305
	var backdrop_style := StyleBoxFlat.new()
	backdrop_style.bg_color = Color(0.04, 0.08, 0.05, 0.58)
	backdrop_style.set_corner_radius_all(18)
	backdrop_style.set_border_width_all(1)
	backdrop_style.border_color = Color(0.75, 0.63, 0.38, 0.45)
	backdrop_style.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
	backdrop_style.shadow_size = 20
	backdrop_style.content_margin_left = 32.0
	backdrop_style.content_margin_right = 32.0
	backdrop_style.content_margin_top = 26.0
	backdrop_style.content_margin_bottom = 26.0
	button_backdrop.add_theme_stylebox_override("panel", backdrop_style)
	add_child(button_backdrop)

	var container: VBoxContainer = VBoxContainer.new()
	container.name = "ButtonContainer"
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 14)
	button_backdrop.add_child(container)

	var menu_title := Label.new()
	menu_title.text = "Hành Trình Cổ Tích"
	UITheme.apply_heading(menu_title, 26)
	container.add_child(menu_title)

	var menu_subtitle := Label.new()
	menu_subtitle.text = "Thắp kiếm, bước vào khu rừng và viết tiếp truyền thuyết Thạch Sanh."
	menu_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_body(menu_subtitle, 14, UITheme.BODY_TEXT_COLOR)
	container.add_child(menu_subtitle)

	container.add_child(UITheme.create_separator(14.0))

	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.stream = bg_music
	_music_player.volume_db = -10.0
	add_child(_music_player)
	if bg_music:
		if bg_music is AudioStreamMP3:
			(bg_music as AudioStreamMP3).loop = true
		_music_player.play()

	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	sfx_player.volume_db = -10.0
	add_child(sfx_player)

	var buttons_data: Array[Dictionary] = [
		{"name": "Start", "label": "Bắt đầu", "hint": "Khởi đầu lại hành trình từ đầu.", "pressed": _on_play_pressed},
		{"name": "Continue", "label": "Tiếp tục", "hint": "", "pressed": _on_continue_pressed},
		{"name": "Settings", "label": "Cài đặt", "hint": "Âm thanh, đồ họa và tốc độ khung hình.", "pressed": _on_settings_pressed},
		{"name": "Quit", "label": "Thoát", "hint": "Rời khỏi trò chơi.", "pressed": _on_quit_pressed, "variant": "danger"}
	]

	for data in buttons_data:
		var entry := _create_menu_button(data["name"], data["label"], data["hint"], data["pressed"], data.get("variant", "primary"))
		container.add_child(entry)

	_refresh_continue_state()

func _create_menu_button(name: String, label_text: String, hint_text: String, pressed_handler: Callable, variant: String) -> Control:
	var wrapper := VBoxContainer.new()
	wrapper.name = "%sEntry" % name
	wrapper.alignment = BoxContainer.ALIGNMENT_CENTER
	wrapper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrapper.add_theme_constant_override("separation", 4)

	var button := Button.new()
	button.name = name
	button.text = label_text
	button.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UITheme.apply_button(button, variant)
	button.pressed.connect(pressed_handler)
	button.mouse_entered.connect(_on_button_hover.bind(button, true))
	button.mouse_exited.connect(_on_button_hover.bind(button, false))
	button.focus_entered.connect(_on_button_hover.bind(button, true))
	button.focus_exited.connect(_on_button_hover.bind(button, false))
	button.pivot_offset = button.custom_minimum_size / 2.0
	wrapper.add_child(button)

	var hint := Label.new()
	hint.name = "%sHint" % name
	hint.text = hint_text
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(BUTTON_WIDTH, 0.0)
	UITheme.apply_body(hint, 12, UITheme.BODY_MUTED_COLOR)
	wrapper.add_child(hint)

	if name == "Continue":
		_continue_button = button
		_continue_hint = hint

	return wrapper

func _on_button_hover(button: Control, is_hovered: bool) -> void:
	button.pivot_offset = button.size / 2.0
	if button is BaseButton and (button as BaseButton).disabled:
		return
	var tween: Tween = create_tween().set_parallel(true)
	var target_scale: Vector2 = Vector2(1.08, 1.08) if is_hovered else Vector2(1.0, 1.0)
	var target_color: Color = Color(1.15, 1.15, 1.15) if is_hovered else Color.WHITE
	tween.tween_property(button, "scale", target_scale, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "modulate", target_color, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if is_hovered and hover_sfx and sfx_player:
		sfx_player.stream = hover_sfx
		sfx_player.play()

func _refresh_continue_state() -> void:
	if _continue_button == null or _continue_hint == null:
		return
	var has_save := SaveManager.has_save()
	_continue_button.disabled = not has_save
	_continue_hint.text = (
		"Tiếp tục từ lần lưu gần nhất."
		if has_save
		else "Chưa có dữ liệu lưu để tiếp tục hành trình."
	)
	_continue_button.tooltip_text = "" if has_save else "Hãy bắt đầu trò chơi mới để tạo dữ liệu lưu."
	_continue_button.modulate = Color.WHITE if has_save else Color(0.72, 0.68, 0.62, 0.92)
	_continue_hint.add_theme_color_override(
		"font_color",
		UITheme.BODY_MUTED_COLOR if has_save else Color(0.86, 0.68, 0.48)
	)

func _on_play_pressed() -> void:
	if SaveManager.has_save():
		SaveManager.delete_save()
	_refresh_continue_state()
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
	if not SaveManager.has_save():
		_refresh_continue_state()
		return
	if not SaveManager.load_completed.is_connected(_on_load_completed):
		SaveManager.load_completed.connect(_on_load_completed)
	SaveManager.load_progress()

func _on_settings_pressed() -> void:
	if _settings_menu_instance == null:
		_settings_menu_instance = SettingsMenuScript.new()
		add_child(_settings_menu_instance)
	_settings_menu_instance.call("toggle_menu")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_load_completed(data: Dictionary, success: bool) -> void:
	if SaveManager.load_completed.is_connected(_on_load_completed):
		SaveManager.load_completed.disconnect(_on_load_completed)

	if not success:
		push_warning("SaveManager: chưa có tiến độ để tiếp tục.")
		_refresh_continue_state()
		return

	# Lưu dữ liệu save vào SaveManager để world có thể đọc sau khi load
	SaveManager.set_meta("pending_restore", data)

	var scene_path: String = data.get("scene_path", GAME_SCENE_PATH)
	var scene_changed := await _change_to_game_scene(scene_path)
	if not scene_changed:
		SaveManager.remove_meta("pending_restore")

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
