# world.gd
class_name World
extends Node3D

@export var player_scene: PackedScene = preload("res://src/player/player.tscn")
@export var camera_scene: PackedScene = preload("res://src/camera/game_camera.tscn")

@onready var spawn_point: Marker3D = $SpawnPoint

func _ready() -> void:
	# Ensure spawn point exists
	if not spawn_point:
		push_error("SpawnPoint Marker3D is missing from World scene.")
		return
		
	# 1. Spawn Player
	var player := player_scene.instantiate() as Player
	player.add_to_group("player")
	add_child(player)
	player.global_position = spawn_point.global_position
	
	# 2. Spawn Camera
	var camera := camera_scene.instantiate() as GameCamera
	add_child(camera)
	camera.set_target(player)
	
	# 3. Create World Manager (HUD, Boss, Weather, etc.)
	var world_manager := WorldManager.new()
	world_manager.name = "WorldManager"
	add_child(world_manager)
	
	# 4. Create Audio Manager
	var audio_manager := AudioManager.new()
	audio_manager.name = "AudioManager"
	add_child(audio_manager)
	
	# 5. Notify Event Bus
	if get_node_or_null("/root/EventBus"):
		var event_bus := get_node("/root/EventBus")
		if event_bus.has_signal("player_spawned"):
			event_bus.emit_signal("player_spawned", player)
