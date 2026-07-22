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
		_play_entrance_flash()
		_play_player_entrance_pop(player)
	_spawn_ambient_motes(player_spawn_position)

	# 3. Create World Manager (HUD, Boss, Weather, etc.)
	var world_manager := WorldManager.new()
	world_manager.name = "WorldManager"
	add_child(world_manager)

	# 3.5. Create Slime Manager (passive ambient slimes scattered around the forest)
	var slime_manager := WorldSlimeManager.new()
	slime_manager.name = "SlimeManager"
	add_child(slime_manager)

	# 4. Create Audio Manager
	var audio_manager := AudioManager.new()
	audio_manager.name = "AudioManager"
	add_child(audio_manager)

	# 5. Death Dialog – hiện khi nhân vật chết
	var death_dialog := DeathDialog.new()
	death_dialog.name = "DeathDialog"
	add_child(death_dialog)

	# 6. Victory Dialog - hiện khi người chơi đánh bại boss
	var victory_dialog := VictoryDialog.new()
	victory_dialog.name = "VictoryDialog"
	add_child(victory_dialog)
	
	# 7. Notify Event Bus
	if get_node_or_null("/root/EventBus"):
		var event_bus := get_node("/root/EventBus")
		if event_bus.has_signal("player_spawned"):
			event_bus.emit_signal("player_spawned", player)

	# 8. Khôi phục trạng thái đã lưu (nếu có) – không can thiệp vào logic core
	if has_pending_restore:
		var restore_data: Dictionary = SaveManager.get_meta("pending_restore")
		SaveManager.remove_meta("pending_restore")
		var restorer := GameStateRestorer.new()
		restorer.name = "GameStateRestorer"
		add_child(restorer)
		await restorer.restore(restore_data)
		camera.skip_startup_intro()


func _play_entrance_flash() -> void:
	var flash_layer := CanvasLayer.new()
	flash_layer.name = "EntranceFlashLayer"
	flash_layer.layer = 5
	add_child(flash_layer)
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.96, 0.85, 0.85)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.anchor_right = 1.0
	flash.anchor_bottom = 1.0
	flash_layer.add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_delay(0.05)
	tween.tween_callback(flash_layer.queue_free)


func _play_player_entrance_pop(target_player: Player) -> void:
	var visuals := target_player.get_node_or_null("Visuals") as Node3D
	if visuals == null:
		return
	visuals.scale = Vector3.ZERO
	var tween := create_tween()
	tween.tween_property(visuals, "scale", Vector3.ONE, 0.4)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.15)
	tween.tween_callback(_play_entrance_landing_burst.bind(target_player))


func _play_entrance_landing_burst(target_player: Player) -> void:
	# Punctuates the moment the pop-in finishes landing — the opening 3s is
	# otherwise just a flash + scale tween, which reads as flat on a silent clip.
	if not is_instance_valid(target_player):
		return
	CombatJuice.camera_shake(get_tree(), 0.12, 3.0)
	CombatJuice.spawn_impact_burst(
		self,
		target_player.global_position + Vector3(0.0, 0.9, 0.0),
		Vector3.UP,
		PackedColorArray([
			Color(1.0, 0.95, 0.7, 0.95),
			Color(1.0, 0.8, 0.35, 0.85),
			Color(0.9, 0.55, 0.1, 0.0),
		]),
		20, 0.6, 0.08
	)


func _spawn_ambient_motes(at_position: Vector3) -> void:
	# Subtle drifting dust/pollen so the spawn clearing has motion in frame 1
	# even before the player moves. Same CPUParticles3D recipe already used
	# for pickup/hit bursts, just continuous instead of one-shot.
	var motes := CPUParticles3D.new()
	motes.name = "AmbientMotes"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.03, 0.03, 0.03)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	motes.mesh = mesh
	motes.amount = 36
	motes.lifetime = 5.0
	motes.preprocess = 5.0
	motes.one_shot = false
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(14.0, 3.0, 10.0)
	motes.direction = Vector3.UP
	motes.spread = 30.0
	motes.gravity = Vector3(0.0, 0.06, 0.0)
	motes.initial_velocity_min = 0.05
	motes.initial_velocity_max = 0.18
	motes.color = Color(1.0, 0.92, 0.72, 0.4)
	add_child(motes)
	motes.position = at_position + Vector3(0.0, 1.5, 0.0)
	motes.emitting = true
