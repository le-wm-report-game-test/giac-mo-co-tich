# loading_screen.gd
class_name LoadingScreen
extends Control

const DEFAULT_TARGET_SCENE: String = "res://src/world/world.tscn"
const META_KEY: String = "loading_target_scene"

const TIPS: Array[String] = [
	"Rừng sâu thường giấu lối đi bên dưới những tán lá tĩnh lặng.",
	"Lắng nghe bước chân và tiếng gầm xa, đó là cách người anh hùng sống sót.",
	"Mỗi vật phẩm nhặt được đều có thể cứu bạn trong trận chiến kế tiếp.",
	"Cổ tích chỉ mở đường cho người đủ dũng cảm tiến về phía trước.",
]

@onready var _progress_bar: ProgressBar = %ProgressBar
@onready var _percent_label: Label = %PercentLabel
@onready var _tip_label: Label = %TipLabel

var _target_path: String = DEFAULT_TARGET_SCENE
var _progress: Array = []
var _request_started: bool = false
var _tip_timer: Timer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if EventBus.has_meta(META_KEY):
		_target_path = EventBus.get_meta(META_KEY)
		EventBus.remove_meta(META_KEY)

	_start_tip_rotation()
	_update_ui(0.0)
	_start_load()

func _start_tip_rotation() -> void:
	if TIPS.is_empty():
		return
	_tip_label.text = TIPS[0]
	if TIPS.size() <= 1:
		return
	_tip_timer = Timer.new()
	_tip_timer.wait_time = 3.0
	_tip_timer.autostart = true
	_tip_timer.timeout.connect(_on_tip_timer_timeout)
	add_child(_tip_timer)

func _on_tip_timer_timeout() -> void:
	var next_index := (TIPS.find(_tip_label.text) + 1) % TIPS.size()
	var tween := create_tween()
	tween.tween_property(_tip_label, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func(): _tip_label.text = TIPS[next_index])
	tween.tween_property(_tip_label, "modulate:a", 1.0, 0.25)

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
