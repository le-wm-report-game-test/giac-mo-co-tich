# settings_menu.gd
class_name SettingsMenu
extends CanvasLayer

var is_open: bool = false
var brightness: float = 1.2

var _overlay: ColorRect
var _panel: PanelContainer
var _brightness_label: Label
var _brightness_slider: HSlider
var _window_mode_option: OptionButton
var _fps_option: OptionButton
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_create_ui()
	_apply_settings()
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
	_panel.custom_minimum_size = Vector2(420, 380)
	
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
	_brightness_slider.min_value = 0.5
	_brightness_slider.max_value = 2.0
	_brightness_slider.step = 0.05
	_brightness_slider.value = brightness
	_brightness_slider.value_changed.connect(_on_brightness_changed)
	container.add_child(_brightness_slider)

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
	_window_mode_option.selected = 0
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
	_fps_option.selected = 0
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
	brightness = value
	_brightness_label.text = "Độ sáng / Brightness: %d%%" % int(brightness * 100)
	_apply_brightness()

func _on_window_mode_selected(index: int) -> void:
	var win := get_window()
	if index == 0:
		win.mode = Window.MODE_WINDOWED
		win.borderless = false
		win.size = Vector2i(1920, 1080)
	elif index == 1:
		win.mode = Window.MODE_WINDOWED
		win.borderless = true
		win.size = Vector2i(1920, 1080)
	elif index == 2:
		win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		win.size = Vector2i(1920, 1080)

func _on_fps_selected(index: int) -> void:
	if index == 0:
		Engine.max_fps = 0
	elif index == 1:
		Engine.max_fps = 30
	elif index == 2:
		Engine.max_fps = 60
	elif index == 3:
		Engine.max_fps = 120

func _apply_settings() -> void:
	_apply_brightness()
	# Apply default windowed 1920x1080
	_on_window_mode_selected(0)
	# Apply default unlimited FPS
	_on_fps_selected(0)

func _apply_brightness() -> void:
	var world_env := get_node_or_null("/root/World/WorldEnvironment") as WorldEnvironment
	if world_env and world_env.environment:
		if not world_env.environment.is_local_to_scene():
			world_env.environment = world_env.environment.duplicate()
		world_env.environment.tonemap_exposure = brightness
