# settings_menu.gd
class_name SettingsMenu
extends CanvasLayer

const SETTINGS_PATH: String = "user://settings.cfg"
const DEFAULT_LIGHTING_QUALITY: String = "Cinematic"

var is_open: bool = false
var brightness: float = 1.0
var lighting_quality: String = DEFAULT_LIGHTING_QUALITY
var window_mode_index: int = 0
var fps_index: int = 0

var _overlay: ColorRect
var _panel: PanelContainer
var _brightness_label: Label
var _brightness_slider: HSlider
var _lighting_quality_option: OptionButton
var _window_mode_option: OptionButton
var _fps_option: OptionButton
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
	# Semi-transparent backdrop overlay
	_overlay = ColorRect.new()
	_overlay.color = Color(0.05, 0.05, 0.05, 0.75)
	_overlay.anchor_right = 1.0
	_overlay.anchor_bottom = 1.0
	add_child(_overlay)
	
	# Main Panel Centered
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(440, 450)
	
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
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	_panel.add_child(vbox)
	
	# Title
	var title := Label.new()
	title.text = "CÀI ĐẶT / SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2))
	vbox.add_child(title)
	
	# Add controls
	_create_brightness_control(vbox)
	_create_lighting_quality_control(vbox)
	_create_window_mode_control(vbox)
	_create_fps_control(vbox)
	_create_action_buttons(vbox)

func _create_brightness_control(parent: Control) -> void:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)
	parent.add_child(container)
	
	_brightness_label = Label.new()
	_brightness_label.text = "Độ sáng / Brightness: %d%%" % int(brightness * 100)
	_brightness_label.add_theme_font_size_override("font_size", 14)
	container.add_child(_brightness_label)
	
	_brightness_slider = HSlider.new()
	_brightness_slider.min_value = 0.85
	_brightness_slider.max_value = 1.15
	_brightness_slider.step = 0.01
	_brightness_slider.value = brightness
	_brightness_slider.value_changed.connect(_on_brightness_changed)
	container.add_child(_brightness_slider)

func _create_lighting_quality_control(parent: Control) -> void:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)
	parent.add_child(container)

	var label := Label.new()
	label.text = "Chất lượng ánh sáng / Lighting Quality:"
	label.add_theme_font_size_override("font_size", 14)
	container.add_child(label)

	_lighting_quality_option = OptionButton.new()
	_lighting_quality_option.add_item("Cinematic")
	_lighting_quality_option.add_item("Performance")
	_lighting_quality_option.selected = 1 if lighting_quality == "Performance" else 0
	_lighting_quality_option.item_selected.connect(_on_lighting_quality_selected)
	container.add_child(_lighting_quality_option)

func _create_window_mode_control(parent: Control) -> void:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)
	parent.add_child(container)
	
	var label := Label.new()
	label.text = "Chế độ hiển thị (1920x1080) / Window Mode:"
	label.add_theme_font_size_override("font_size", 14)
	container.add_child(label)
	
	_window_mode_option = OptionButton.new()
	_window_mode_option.add_item("Cửa sổ (Windowed 1920x1080)")
	_window_mode_option.add_item("Không viền (Borderless 1920x1080)")
	_window_mode_option.add_item("Toàn màn hình (Fullscreen 1920x1080)")
	_window_mode_option.item_selected.connect(_on_window_mode_selected)
	_window_mode_option.selected = window_mode_index
	container.add_child(_window_mode_option)

func _create_fps_control(parent: Control) -> void:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)
	parent.add_child(container)
	
	var label := Label.new()
	label.text = "Giới hạn FPS / FPS Limit:"
	label.add_theme_font_size_override("font_size", 14)
	container.add_child(label)
	
	_fps_option = OptionButton.new()
	_fps_option.add_item("Không giới hạn (Unlimited)")
	_fps_option.add_item("30 FPS")
	_fps_option.add_item("60 FPS")
	_fps_option.add_item("120 FPS")
	_fps_option.item_selected.connect(_on_fps_selected)
	_fps_option.selected = fps_index
	container.add_child(_fps_option)

func _create_action_buttons(parent: Control) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(hbox)
	
	var resume_btn := Button.new()
	resume_btn.text = "TIẾP TỤC / RESUME"
	resume_btn.custom_minimum_size = Vector2(150, 40)
	resume_btn.pressed.connect(toggle_menu)
	hbox.add_child(resume_btn)
	
	var quit_btn := Button.new()
	quit_btn.text = "THOÁT / QUIT"
	quit_btn.custom_minimum_size = Vector2(150, 40)
	quit_btn.pressed.connect(func(): get_tree().quit())
	hbox.add_child(quit_btn)

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

func _apply_settings() -> void:
	_apply_brightness()
	_on_lighting_quality_selected(1 if lighting_quality == "Performance" else 0)
	_on_window_mode_selected(window_mode_index)
	_on_fps_selected(fps_index)

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

func _save_settings() -> void:
	if _suppress_save:
		return
	var config := ConfigFile.new()
	config.set_value("display", "brightness", brightness)
	config.set_value("display", "lighting_quality", lighting_quality)
	config.set_value("display", "window_mode", window_mode_index)
	config.set_value("display", "fps_limit", fps_index)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Could not persist settings: %s" % error_string(error))
