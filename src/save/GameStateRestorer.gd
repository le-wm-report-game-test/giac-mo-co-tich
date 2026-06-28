# src/save/GameStateRestorer.gd
# Node tạm thời được thêm vào world khi cần restore save data.
# Tự xóa sau khi hoàn tất. Không can thiệp vào logic core.
class_name GameStateRestorer
extends Node

var _save_data: Dictionary = {}

func restore(data: Dictionary) -> void:
	_save_data = data
	# Đợi các node trong world sẵn sàng
	await get_tree().process_frame
	await get_tree().process_frame
	_apply_state()

func _apply_state() -> void:
	# ── Player ──────────────────────────────────────────────────────
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		# Vị trí
		player.global_position = _save_data.get("position", Vector3(0.0, 1.0, 0.0))

		# Máu
		var hp_comp: HealthComponent = player.get_node_or_null("HealthComponent")
		if hp_comp:
			var saved_max: float = _save_data.get("max_health", hp_comp.max_health)
			var saved_hp: float  = _save_data.get("health", saved_max)

			# Nếu lưu khi đang chết (health <= 0), hồi phục về max
			# vì không có ý nghĩa khi tiếp tục từ trạng thái chết.
			if saved_hp <= 0.0:
				saved_hp = saved_max

			hp_comp.max_health     = saved_max
			hp_comp.current_health = clampf(saved_hp, 1.0, saved_max)
			# Emit để HUD health bar cập nhật ngay
			hp_comp.health_changed.emit(hp_comp.current_health, hp_comp.max_health)

	# ── WorldManager ────────────────────────────────────────────────
	var wm: WorldManager = get_tree().get_first_node_in_group("world_manager") as WorldManager
	if wm == null:
		wm = get_tree().root.find_child("WorldManager", true, false) as WorldManager
	if wm:
		wm.orcs_killed  = _save_data.get("orcs_killed",  0)
		wm.boss_spawned = _save_data.get("boss_spawned", false)
		wm.weather_state = _save_data.get("weather_state", "clear")

		# Cập nhật HUD orc counter ngay sau khi restore
		wm._update_ui_orc_counter()

		# Emit orc_killed_count để các listener khác cũng cập nhật
		EventBus.orc_killed_count.emit(wm.orcs_killed)

	print("GameStateRestorer: đã khôi phục trạng thái game.")
	queue_free()

