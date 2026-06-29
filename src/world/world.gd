# world.gd
class_name World
extends Node3D

const DEFAULT_PLAYER_SPAWN_POSITION := Vector3(0.0, 1.0, 0.0)

@export var player_scene: PackedScene = preload("res://src/player/player.tscn")
@export var camera_scene: PackedScene = preload("res://src/camera/game_camera.tscn")

@onready var spawn_point: Marker3D = get_node_or_null("SpawnPoint") as Marker3D

func _ready() -> void:
	var has_pending_restore := SaveManager.has_meta("pending_restore")

	# Không để một marker bị thiếu làm hỏng toàn bộ quá trình khởi tạo game.
	var player_spawn_position := DEFAULT_PLAYER_SPAWN_POSITION
	if spawn_point:
		player_spawn_position = spawn_point.global_position
	else:
		push_warning("SpawnPoint Marker3D is missing; using the default player spawn position.")
		
	# 1. Spawn Player
	var player := player_scene.instantiate() as Player
	player.add_to_group("player")
	add_child(player)
	player.global_position = player_spawn_position
	
	# 2. Spawn Camera
	var camera := camera_scene.instantiate() as GameCamera
	add_child(camera)
	camera.set_target(player)
	if not has_pending_restore:
		camera.play_startup_intro(player)
	
	# 3. Create World Manager (HUD, Boss, Weather, etc.)
	var world_manager := WorldManager.new()
	world_manager.name = "WorldManager"
	add_child(world_manager)
	
	# 4. Create Audio Manager
	var audio_manager := AudioManager.new()
	audio_manager.name = "AudioManager"
	add_child(audio_manager)

	# 5. Death Dialog – hiện khi nhân vật chết
	var death_dialog := DeathDialog.new()
	death_dialog.name = "DeathDialog"
	add_child(death_dialog)
	
	# 6. Notify Event Bus
	if get_node_or_null("/root/EventBus"):
		var event_bus := get_node("/root/EventBus")
		if event_bus.has_signal("player_spawned"):
			event_bus.emit_signal("player_spawned", player)

	# 7. Khôi phục trạng thái đã lưu (nếu có) – không can thiệp vào logic core
	if has_pending_restore:
		var restore_data: Dictionary = SaveManager.get_meta("pending_restore")
		SaveManager.remove_meta("pending_restore")
		var restorer := GameStateRestorer.new()
		restorer.name = "GameStateRestorer"
		add_child(restorer)
		await restorer.restore(restore_data)
		camera.skip_startup_intro()
