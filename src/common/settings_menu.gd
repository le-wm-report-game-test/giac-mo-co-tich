# settings_menu.gd
class_name SettingsMenu
extends CanvasLayer

const SETTINGS_PATH: String = "user://settings.cfg"
const DEFAULT_LIGHTING_QUALITY: String = "Cinematic"
const PANEL_MIN_SIZE: Vector2 = Vector2(820, 560)
const BODY_FONT_SIZE: int = 16
const SECTION_FONT_SIZE: int = 18
const TITLE_FONT_SIZE: int = 26
const FIELD_MIN_HEIGHT: float = 42.0

var is_open: bool = false
var brightness: float = 1.0
var lighting_quality: String = DEFAULT_LIGHTING_QUALITY
var window_mode_index: int = 0
var fps_index: int = 0

# Audio settings
var music_volume: float = 0.5
var sfx_volume: float = 0.8
var ambience_volume: float = 0.6

var _overlay: ColorRect
var _panel: PanelContainer
var _brightness_label: Label
var _music_label: Label
var _sfx_label: Label
var _ambience_label: Label
var _suppress_save: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_load_settings()
	_create_ui()
	_apply_settings()
	_suppress_save = false

func toggle_menu() -> void:
	is_open = not is_open
	visible = is_open
	get_tree().paused = is_open

func _create_ui() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0.05, 0.05, 0.05, 0.75)
	_overlay.anchor_right = 1.0
	_overlay.anchor_bottom = 1.0
	add_child(_overlay)
	
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = PANEL_MIN_SIZE
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.14, 0.98)
	style.border_color = Color(0.85, 0.65, 0.15)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 36
	style.content_margin_right = 36
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	_panel.add_child(vbox)
	
	var title := Label.new()
	title.text = "CÀI ĐẶT / SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2))
	vbox.add_child(title)
	
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 32)
	vbox.add_child(columns)
	
	var display_column := VBoxContainer.new()
	display_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display_column.add_theme_constant_override("separation", 12)
	columns.add_child(display_column)
	
	var display_title := Label.new()
	display_title.text = "HIỂN THỊ / DISPLAY"
	display_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	display_title.add_theme_font_size_override("font_size", SECTION_FONT_SIZE)
	display_title.add_theme_color_override("font_color", Color(0.85, 0.65, 0.15))
	display_column.add_child(display_title)
	
	_create_brightness_control(display_column)
	_add_option(display_column, "Chất lượng ánh sáng / Lighting Quality:", ["Cinematic", "Performance"], 1 if lighting_quality == "Performance" else 0, _on_lighting_quality_selected)
	_add_option(display_column, "Chế độ hiển thị (1920x1080) / Window Mode:", ["Cửa sổ (Windowed)", "Không viền (Borderless)", "Toàn màn hình (Fullscreen)"], window_mode_index, _on_window_mode_selected)
	_add_option(display_column, "Giới hạn FPS / FPS Limit:", ["Không giới hạn (Unlimited)", "30 FPS", "60 FPS", "120 FPS"], fps_index, _on_fps_selected)
	
	var audio_column := VBoxContainer.new()
	audio_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	audio_column.add_theme_constant_override("separation", 12)
	columns.add_child(audio_column)
	_create_audio_controls(audio_column)
	
	# Buttons
	_create_action_buttons(vbox)

func _create_brightness_control(parent: Control) -> void:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 8)
	parent.add_child(container)
	_brightness_label = Label.new()
	_brightness_label.text = "Độ sáng / Brightness: %d%%" % int(brightness * 100)
	_style_setting_label(_brightness_label)
	container.add_child(_brightness_label)
	var slider := HSlider.new()
	_style_slider(slider)
	slider.min_value = 0.85
	slider.max_value = 1.15
	slider.step = 0.01
	slider.value = brightness
	slider.value_changed.connect(_on_brightness_changed)
	container.add_child(slider)

func _create_audio_controls(parent: Control) -> void:
	var title := Label.new()
	title.text = "ÂM THANH / AUDIO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", SECTION_FONT_SIZE)
	title.add_theme_color_override("font_color", Color(0.85, 0.65, 0.15))
	parent.add_child(title)
	
	_music_label = Label.new()
	_style_setting_label(_music_label)
	_add_audio_slider(parent, _music_label, "Nhạc nền / Music", music_volume, _on_music_volume_changed)
	
	_sfx_label = Label.new()
	_style_setting_label(_sfx_label)
	_add_audio_slider(parent, _sfx_label, "Hiệu ứng / SFX", sfx_volume, _on_sfx_volume_changed)
	
	_ambience_label = Label.new()
	_style_setting_label(_ambience_label)
	_add_audio_slider(parent, _ambience_label, "Môi trường / Ambience", ambience_volume, _on_ambience_volume_changed)
	
	_update_audio_labels()

func _add_audio_slider(parent: Control, label: Label, _text_lbl: String, val: float, callback: Callable) -> void:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 8)
	parent.add_child(container)
	container.add_child(label)
	var slider := HSlider.new()
	_style_slider(slider)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = val
	slider.value_changed.connect(callback)
	container.add_child(slider)

func _update_audio_labels() -> void:
	_music_label.text = "Nhạc nền / Music Volume: %d%%" % int(music_volume * 100)
	_sfx_label.text = "Hiệu ứng / SFX Volume: %d%%" % int(sfx_volume * 100)
	_ambience_label.text = "Môi trường / Ambience Volume: %d%%" % int(ambience_volume * 100)

func _add_option(parent: Control, label_text: String, items: Array[String], selected_idx: int, callback: Callable) -> void:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 8)
	parent.add_child(container)
	var lbl := Label.new()
	lbl.text = label_text
	_style_setting_label(lbl)
	container.add_child(lbl)
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(0, FIELD_MIN_HEIGHT)
	opt.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	for item in items:
		opt.add_item(item)
	opt.selected = selected_idx
	opt.item_selected.connect(callback)
	container.add_child(opt)

func _create_action_buttons(parent: Control) -> void:
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(hbox)
	
	var resume_btn: Button = Button.new()
	resume_btn.text = "TIẾP TỤC / RESUME"
	_style_action_button(resume_btn)
	resume_btn.pressed.connect(toggle_menu)
	hbox.add_child(resume_btn)
	
	var main_menu_btn: Button = Button.new()
	main_menu_btn.text = "VỀ MENU / MAIN MENU"
	_style_action_button(main_menu_btn)
	main_menu_btn.pressed.connect(_on_main_menu_pressed)
	hbox.add_child(main_menu_btn)
	
	var quit_btn: Button = Button.new()
	quit_btn.text = "THOÁT / QUIT"
	_style_action_button(quit_btn)
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	hbox.add_child(quit_btn)

func _style_setting_label(label: Label) -> void:
	label.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _style_slider(slider: HSlider) -> void:
	slider.custom_minimum_size = Vector2(0, FIELD_MIN_HEIGHT)

func _style_action_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(190, 48)
	button.add_theme_font_size_override("font_size", BODY_FONT_SIZE)

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	# Lưu tiến độ trước khi về menu
	SaveManager.trigger_save()
	var err: Error = get_tree().change_scene_to_file("res://src/ui/MainMenu.tscn")
	if err != OK:
		push_error("Failed to load main menu scene: %s" % error_string(err))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_menu()
		get_viewport().set_input_as_handled()

func _on_brightness_changed(value: float) -> void:
	brightness = clampf(value, 0.85, 1.15)
	_brightness_label.text = "Độ sáng / Brightness: %d%%" % int(brightness * 100)
	_apply_brightness()
	_save_settings()

func _on_lighting_quality_selected(index: int) -> void:
	lighting_quality = "Performance" if index == 1 else "Cinematic"
	var director := get_tree().get_first_node_in_group("lighting_director") as LightingDirector
	if director != null:
		director.set_quality_preset(lighting_quality)
	_save_settings()

func _on_window_mode_selected(index: int) -> void:
	window_mode_index = clampi(index, 0, 2)
	var win := get_window()
	if window_mode_index == 0:
		win.mode = Window.MODE_WINDOWED
		win.borderless = false
		win.size = Vector2i(1920, 1080)
	elif window_mode_index == 1:
		win.mode = Window.MODE_WINDOWED
		win.borderless = true
		win.size = Vector2i(1920, 1080)
	elif window_mode_index == 2:
		win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		win.size = Vector2i(1920, 1080)
	_save_settings()

func _on_fps_selected(index: int) -> void:
	fps_index = clampi(index, 0, 3)
	if fps_index == 0:
		Engine.max_fps = 0
	elif fps_index == 1:
		Engine.max_fps = 30
	elif fps_index == 2:
		Engine.max_fps = 60
	elif fps_index == 3:
		Engine.max_fps = 120
	_save_settings()

func _on_music_volume_changed(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_update_audio_labels()
	var audio := get_node_or_null("/root/World/AudioManager") as AudioManager
	if audio:
		audio.set_music_volume(music_volume)
	_save_settings()

func _on_sfx_volume_changed(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_update_audio_labels()
	var audio := get_node_or_null("/root/World/AudioManager") as AudioManager
	if audio:
		audio.set_sfx_volume(sfx_volume)
	_save_settings()

func _on_ambience_volume_changed(value: float) -> void:
	ambience_volume = clampf(value, 0.0, 1.0)
	_update_audio_labels()
	var audio := get_node_or_null("/root/World/AudioManager") as AudioManager
	if audio:
		audio.set_ambience_volume(ambience_volume)
	_save_settings()

func _apply_settings() -> void:
	_apply_brightness()
	_on_lighting_quality_selected(1 if lighting_quality == "Performance" else 0)
	_on_window_mode_selected(window_mode_index)
	_on_fps_selected(fps_index)
	var audio := get_node_or_null("/root/World/AudioManager") as AudioManager
	if audio:
		audio.set_music_volume(music_volume)
		audio.set_sfx_volume(sfx_volume)
		audio.set_ambience_volume(ambience_volume)

func _apply_brightness() -> void:
	var director := get_tree().get_first_node_in_group("lighting_director") as LightingDirector
	if director != null:
		director.set_user_brightness(brightness)
		return
	var world_env := get_node_or_null("/root/World/WorldEnvironment") as WorldEnvironment
	if world_env and world_env.environment:
		if not world_env.environment.is_local_to_scene():
			world_env.environment = world_env.environment.duplicate()
		world_env.environment.tonemap_exposure = brightness

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	brightness = clampf(float(config.get_value("display", "brightness", 1.0)), 0.85, 1.15)
	var saved_quality := String(config.get_value("display", "lighting_quality", DEFAULT_LIGHTING_QUALITY))
	lighting_quality = saved_quality if saved_quality in ["Cinematic", "Performance"] else DEFAULT_LIGHTING_QUALITY
	window_mode_index = clampi(int(config.get_value("display", "window_mode", 0)), 0, 2)
	fps_index = clampi(int(config.get_value("display", "fps_limit", 0)), 0, 3)
	
	music_volume = clampf(float(config.get_value("audio", "music_volume", 0.5)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value("audio", "sfx_volume", 0.8)), 0.0, 1.0)
	ambience_volume = clampf(float(config.get_value("audio", "ambience_volume", 0.6)), 0.0, 1.0)

func _save_settings() -> void:
	if _suppress_save:
		return
	var config := ConfigFile.new()
	config.set_value("display", "brightness", brightness)
	config.set_value("display", "lighting_quality", lighting_quality)
	config.set_value("display", "window_mode", window_mode_index)
	config.set_value("display", "fps_limit", fps_index)
	
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "ambience_volume", ambience_volume)
	
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Could not persist settings: %s" % error_string(error))
