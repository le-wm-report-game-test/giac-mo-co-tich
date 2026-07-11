class_name WorldWeatherManager
extends Node

const RainEmitterScript := preload("res://src/world/components/world_rain_emitter.gd")

var _world_manager: Node = null
var _rain_emitter: Node = null


func setup(world_manager: Node) -> void:
	_world_manager = world_manager
	_rain_emitter = RainEmitterScript.new() as Node
	_rain_emitter.name = "RainEmitter"
	add_child(_rain_emitter)
	_rain_emitter.setup(world_manager)


func update(delta: float) -> void:
	if _world_manager.weather_state == "clear":
		_world_manager.weather_timer -= delta
		if _world_manager.weather_timer <= 0.0:
			start_rain()
	else:
		_world_manager.weather_duration -= delta
		if _world_manager.weather_duration <= 0.0:
			end_rain()
	if _world_manager.weather_state == "storm":
		_world_manager.lightning_timer -= delta
		if _world_manager.lightning_timer <= 0.0:
			strike_lightning()
			_world_manager.lightning_timer = randf_range(3.0, 8.0)


func start_storm_instantly() -> void:
	_world_manager.is_raining = true
	_world_manager.weather_state = "storm"
	_world_manager.weather_duration = 180.0
	_world_manager.lightning_timer = 1.0
	EventBus.weather_changed.emit(_world_manager.weather_state)
	_rain_emitter.create()
	_play_rain_audio()


func start_rain() -> void:
	_world_manager.rain_cycle_count += 1
	_world_manager.is_raining = true
	if _world_manager.rain_cycle_count >= 3:
		_world_manager.weather_state = "storm"
		_world_manager.weather_duration = 60.0
		_world_manager.rain_cycle_count = 0
		_world_manager.lightning_timer = 3.0
	else:
		_world_manager.weather_state = "rain"
		_world_manager.weather_duration = 60.0
	EventBus.weather_changed.emit(_world_manager.weather_state)
	_rain_emitter.create()
	_play_rain_audio()


func end_rain() -> void:
	_world_manager.is_raining = false
	_world_manager.weather_state = "clear"
	_world_manager.weather_timer = 300.0
	_rain_emitter.stop()
	EventBus.weather_changed.emit(&"clear")
	var audio := _get_audio_manager()
	if audio:
		audio.stop_ambience()


func create_rain_particles() -> void:
	_rain_emitter.create()


func update_rain_coverage() -> void:
	_rain_emitter.update_coverage()


func strike_lightning() -> void:
	var strike_pos := _choose_strike_position()
	strike_pos.y = 0.0
	var bolt := LightningBolt.new()
	bolt.position = strike_pos
	_world_manager.get_parent().add_child(bolt)


func trigger_screen_flash() -> void:
	var flash := ColorRect.new()
	flash.color = Color(1.0, 1.0, 1.0, 0.75)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.size = _world_manager.get_viewport().get_visible_rect().size
	var ui_layer := _world_manager.get_node_or_null("UI")
	if ui_layer == null:
		flash.queue_free()
		return
	ui_layer.add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.25)
	tween.tween_callback(flash.queue_free)


func update_lighting(is_rainy: bool) -> void:
	var lighting := get_tree().get_first_node_in_group("lighting_director") as LightingDirector
	if lighting == null:
		return
	var weather := StringName(_world_manager.weather_state) if is_rainy else &"clear"
	lighting.set_weather(weather)


func _choose_strike_position() -> Vector3:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if _is_test_run() or player == null:
		return Vector3(randf_range(-45.0, 45.0), 0.0, randf_range(-45.0, 45.0))
	if randf() < 0.15:
		return player.global_position
	var angle := randf() * TAU
	var distance := randf_range(10.0, 22.0)
	return player.global_position + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)


func _is_test_run() -> bool:
	var main_loop := Engine.get_main_loop()
	if main_loop == null or main_loop.get_script() == null:
		return false
	return "test_runner" in main_loop.get_script().resource_path


func _play_rain_audio() -> void:
	var audio := _get_audio_manager()
	if audio:
		audio.play_ambience("rain_ambience")


func _get_audio_manager() -> AudioManager:
	return get_tree().get_first_node_in_group("audio_manager") as AudioManager
