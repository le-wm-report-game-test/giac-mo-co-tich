# loading_screen.gd
class_name LoadingScreen
extends Control

const DEFAULT_TARGET_SCENE: String = "res://src/world/world.tscn"
const META_KEY: String = "loading_target_scene"

@onready var _progress_bar: ProgressBar = %ProgressBar
@onready var _percent_label: Label = %PercentLabel

var _target_path: String = DEFAULT_TARGET_SCENE
var _progress: Array = []
var _request_started: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if EventBus.has_meta(META_KEY):
		_target_path = EventBus.get_meta(META_KEY)
		EventBus.remove_meta(META_KEY)

	_update_ui(0.0)
	_start_load()

func _start_load() -> void:
	var err := ResourceLoader.load_threaded_request(_target_path)
	if err != OK:
		push_error("LoadingScreen: không thể bắt đầu tải %s: %s" % [_target_path, error_string(err)])
		get_tree().change_scene_to_file(_target_path)
		return
	_request_started = true
	set_process(true)

func _process(_delta: float) -> void:
	if not _request_started:
		return

	var status := ResourceLoader.load_threaded_get_status(_target_path, _progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var pct := 0.0
			if _progress.size() > 0:
				pct = float(_progress[0]) * 100.0
			_update_ui(pct)
		ResourceLoader.THREAD_LOAD_LOADED:
			_request_started = false
			_update_ui(100.0)
			var packed: PackedScene = ResourceLoader.load_threaded_get(_target_path)
			call_deferred("_finish_load", packed)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_request_started = false
			push_error("LoadingScreen: tải thất bại cho %s" % _target_path)
			get_tree().change_scene_to_file(_target_path)

func _update_ui(pct: float) -> void:
	_progress_bar.value = pct
	_percent_label.text = "%d%%" % int(pct)

func _finish_load(packed: PackedScene) -> void:
	get_tree().change_scene_to_packed(packed)
