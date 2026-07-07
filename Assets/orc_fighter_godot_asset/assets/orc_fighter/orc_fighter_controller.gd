extends Node3D
class_name OrcFighter

@export var default_animation: String = "idle"
@export var return_to_idle_after_action: bool = true

var _animation_player: AnimationPlayer
var _return_to_idle_pending := false

func _ready() -> void:
	_animation_player = _find_animation_player(self)
	if _animation_player:
		if not _animation_player.animation_finished.is_connected(_on_animation_finished):
			_animation_player.animation_finished.connect(_on_animation_finished)
		play_state(default_animation, false)
	else:
		push_warning("OrcFighter: Không tìm thấy AnimationPlayer. Hãy kiểm tra file .glb đã import xong chưa.")

func play_state(state_name: String, auto_return_to_idle: bool = true) -> void:
	if not _animation_player:
		return
	var anim_name := _resolve_animation_name(state_name)
	if anim_name == "":
		push_warning("OrcFighter: Không có animation state: " + state_name)
		return
	_return_to_idle_pending = auto_return_to_idle and state_name.to_lower() != "idle" and state_name.to_lower() != "defeated"
	_animation_player.play(anim_name)

func idle() -> void:
	play_state("idle", false)

func attack() -> void:
	play_state("attack", true)

func hit() -> void:
	play_state("hit", true)

func defeated() -> void:
	play_state("defeated", false)

func _on_animation_finished(anim_name: StringName) -> void:
	if _return_to_idle_pending and return_to_idle_after_action:
		_return_to_idle_pending = false
		play_state("idle", false)
	elif String(anim_name).to_lower().find("idle") != -1:
		# glTF không lưu loop flag chuẩn; tự phát lại idle để nhân vật không đứng hình.
		play_state("idle", false)

func _resolve_animation_name(state_name: String) -> String:
	if _animation_player.has_animation(state_name):
		return state_name
	var wanted := state_name.to_lower()
	for anim in _animation_player.get_animation_list():
		var a := String(anim)
		var low := a.to_lower()
		if low == wanted or low.ends_with("/" + wanted) or low.find(wanted) != -1:
			return a
	return ""

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null
