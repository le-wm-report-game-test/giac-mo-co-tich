# audio_manager.gd
# Manages all game audio - procedural sounds + external file loading
class_name AudioManager
extends Node

const ProceduralAudioGenerator = preload("res://src/audio/procedural_audio_generator.gd")

const BUS_MASTER: String = "Master"
const BUS_MUSIC: String = "Music"
const BUS_SFX: String = "SFX"
const BUS_AMBIENCE: String = "Ambience"

var sfx_volume: float = 0.8
var music_volume: float = 0.3
var ambience_volume: float = 0.6

var _sfx_players: Array[AudioStreamPlayer3D] = []
var _ambience_player: AudioStreamPlayer3D = null
var _music_player: AudioStreamPlayer = null
var _footstep_player: AudioStreamPlayer3D = null
var _footstep_timeout: float = 0.0

var _sounds: Dictionary = {}

func _ready() -> void:
	add_to_group("audio_manager")
	_load_initial_volumes()
	_setup_audio_buses()
	_create_players()
	_generate_procedural_sounds()
	_load_assets()
	_connect_event_bus()

func _process(delta: float) -> void:
	if _footstep_timeout > 0.0:
		_footstep_timeout -= delta
		if _footstep_timeout <= 0.0 and _footstep_player and _footstep_player.playing:
			_footstep_player.stop()

func _load_initial_volumes() -> void:
	var settings := get_tree().get_first_node_in_group("settings_menu") as SettingsMenu
	if settings:
		music_volume = settings.music_volume
		sfx_volume = settings.sfx_volume
		ambience_volume = settings.ambience_volume

func _setup_audio_buses() -> void:
	var buses := {BUS_MUSIC: music_volume, BUS_SFX: sfx_volume, BUS_AMBIENCE: ambience_volume}
	for b_name in buses:
		var idx := AudioServer.get_bus_index(b_name)
		if idx == -1:
			AudioServer.add_bus()
			idx = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b_name)
		AudioServer.set_bus_volume_db(idx, linear_to_db(buses[b_name]))

func _create_players() -> void:
	for i in range(8):
		var player := AudioStreamPlayer3D.new()
		player.name = "SFXPlayer_%d" % i
		player.bus = BUS_SFX
		player.volume_db = 8.0 # Boost SFX volume (+8 dB)
		player.unit_size = 12.0 # Make sound carry further before attenuating
		player.max_distance = 50.0
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
		add_child(player)
		_sfx_players.append(player)
	
	_ambience_player = AudioStreamPlayer3D.new()
	_ambience_player.name = "AmbiencePlayer"
	_ambience_player.bus = BUS_AMBIENCE
	_ambience_player.volume_db = 4.0 # Boost ambience volume (+4 dB)
	_ambience_player.unit_size = 20.0 # Make environment sound carry much further
	_ambience_player.max_distance = 80.0
	_ambience_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	add_child(_ambience_player)
	
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = BUS_MUSIC
	add_child(_music_player)
	_music_player.finished.connect(_on_music_finished)

	_footstep_player = AudioStreamPlayer3D.new()
	_footstep_player.name = "FootstepPlayer"
	_footstep_player.bus = BUS_SFX
	_footstep_player.volume_db = 13.0 # Boost player footsteps without raising other SFX
	_footstep_player.unit_size = 15.0 # Make sound carry further before attenuating
	_footstep_player.max_distance = 60.0
	_footstep_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	add_child(_footstep_player)

func _generate_procedural_sounds() -> void:
	_sounds["sword_swing"] = ProceduralAudioGenerator.generate_whoosh_sound(0.3, 200.0, 2000.0)
	_sounds["hit"] = ProceduralAudioGenerator.generate_impact_sound(0.15)
	_sounds["hurt"] = ProceduralAudioGenerator.generate_grunt_sound(0.3)
	_sounds["death"] = ProceduralAudioGenerator.generate_death_sound(0.5)
	_sounds["pickup"] = ProceduralAudioGenerator.generate_pickup_sound(0.2)
	_sounds["rain_ambience"] = ProceduralAudioGenerator.generate_noise_sound(5.0, 0.3)
	_sounds["thunder"] = ProceduralAudioGenerator.generate_thunder_sound(1.5)
	_sounds["boss_roar"] = ProceduralAudioGenerator.generate_boss_roar(1.0)

func _load_assets() -> void:
	var assets := {
		"sword_swing": "res://Assets/audio/sound_attack.mp3",
		"hit": "res://Assets/audio/punch.mp3",
		"hurt": "res://Assets/audio/heavy-grunt.mp3",
		"thunder": "res://Assets/audio/thunder.mp3",
		"footstep": "res://Assets/audio/walk_on_grass.mp3",
		"gameplay_music": "res://Assets/audio/panic.mp3",
		"boss_music": "res://Assets/audio/giant_beast_roar.mp3"
	}
	for s_name in assets:
		var _ok: bool = load_external_sound(s_name, str(assets[s_name]))

	for key in ["gameplay_music", "footstep"]:
		var stream := _sounds.get(key) as AudioStream
		if stream and "loop" in stream:
			stream.loop = true

func _connect_event_bus() -> void:
	var eb := get_node_or_null("/root/EventBus")
	if not eb: return
	eb.player_spawned.connect(_on_player_spawned)
	eb.player_died.connect(_on_player_died)
	eb.player_took_damage.connect(_on_player_took_damage)
	eb.player_stepped.connect(_on_player_stepped)
	eb.enemy_damaged.connect(_on_enemy_damaged)
	eb.enemy_died.connect(_on_enemy_died)
	eb.boss_spawned.connect(_on_boss_spawned)
	eb.weather_changed.connect(_on_weather_changed)

func _on_player_spawned(_player: CharacterBody3D) -> void:
	var music_stream := _sounds.get("gameplay_music") as AudioStream
	if music_stream: play_music(music_stream)
	var wm := get_tree().get_first_node_in_group("world_manager") as WorldManager
	if wm and wm.get("is_raining"): play_ambience("rain_ambience")

func _on_player_died() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player: play_sfx("death", player.global_position, 0.1)
	stop_music()

func _on_player_took_damage(_amount: float, pos: Vector3) -> void:
	play_sfx("hurt", pos, 0.15)

func _on_player_stepped(pos: Vector3) -> void:
	if _footstep_player:
		_footstep_player.global_position = pos
		if not _footstep_player.playing and _sounds.has("footstep"):
			_footstep_player.stream = _sounds["footstep"]
			_footstep_player.play()
		_footstep_timeout = 0.8

func _on_enemy_damaged(_enemy: Node3D, _amount: float, _pos: Vector3, _is_critical: bool) -> void:
	play_sfx("hit", _pos, 0.1)

func _on_enemy_died(enemy: Node3D) -> void:
	play_sfx("death", enemy.global_position, 0.1)

func _on_boss_spawned(boss: Node3D) -> void:
	play_sfx("boss_roar", boss.global_position, 0.0)
	play_sfx("thunder", boss.global_position, 0.1)
	var music_stream := _sounds.get("boss_music") as AudioStream
	if music_stream: play_music(music_stream)

func _on_weather_changed(weather_type: String) -> void:
	if weather_type == "rain": play_ambience("rain_ambience")
	else: stop_ambience()

func play_sfx(sound_name: String, position: Vector3, pitch_var: float = 0.1) -> void:
	if not _sounds.has(sound_name): return
	var player := _get_free_sfx_player()
	if not player: return
	player.stream = _sounds[sound_name]
	player.global_position = position
	player.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	player.play()

func play_ambience(sound_name: String, pos: Vector3 = Vector3.ZERO) -> void:
	if not _sounds.has(sound_name): return
	_ambience_player.stream = _sounds[sound_name]
	_ambience_player.global_position = pos
	_ambience_player.play()

func stop_ambience() -> void:
	_ambience_player.stop()

func play_music(stream: AudioStream) -> void:
	_music_player.stream = stream
	_music_player.play()

func _on_music_finished() -> void:
	# Only non-looping tracks (the boss entrance sting) reach here; once it
	# plays out, drop back to the looping gameplay track automatically.
	var music_stream := _sounds.get("gameplay_music") as AudioStream
	if music_stream: play_music(music_stream)

func stop_music() -> void:
	_music_player.stop()

func _get_free_sfx_player() -> AudioStreamPlayer3D:
	for player in _sfx_players:
		if not player.playing: return player
	return _sfx_players[0]

func load_external_sound(sound_name: String, file_path: String) -> bool:
	if not FileAccess.file_exists(file_path): return false
	var stream := load(file_path) as AudioStream
	if not stream: return false
	_sounds[sound_name] = stream
	return true

func set_music_volume(vol: float) -> void:
	music_volume = clampf(vol, 0.0, 1.0)
	_set_bus_vol(BUS_MUSIC, music_volume)

func set_sfx_volume(vol: float) -> void:
	sfx_volume = clampf(vol, 0.0, 1.0)
	_set_bus_vol(BUS_SFX, sfx_volume)

func set_ambience_volume(vol: float) -> void:
	ambience_volume = clampf(vol, 0.0, 1.0)
	_set_bus_vol(BUS_AMBIENCE, ambience_volume)

func _set_bus_vol(bus_name: String, vol: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1: AudioServer.set_bus_volume_db(idx, linear_to_db(vol))
