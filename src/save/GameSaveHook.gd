# src/save/GameSaveHook.gd
# Autoload nhỏ – chỉ xử lý auto-save khi tắt game.
# Không chứa bất kỳ game logic nào.
extends Node

func _ready() -> void:
	# Bắt tín hiệu đóng cửa sổ để lưu trước khi thoát
	get_tree().set_auto_accept_quit(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Lưu state trước khi thoát
		SaveManager.trigger_save()
		# Đợi một frame để FileAccess.close() hoàn tất, rồi mới thoát
		await get_tree().process_frame
		get_tree().quit()
