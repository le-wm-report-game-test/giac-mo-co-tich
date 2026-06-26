# audio_manager.gd
# Manages all game audio - procedural sounds + external file loading
class_name AudioManager
extends Node

# Audio buses
const BUS_MASTER: String = "Master"
const BUS_MUSIC: String = "Music"
const BUS_SFX: String = "SFX"
const BUS_AMBIENCE: String = "Ambience"

# Volume levels
var sfx_volume: float = 0.8
var music_volume: float = 0.5
var ambience_volume: float = 0.6

# Audio players pool
var _sfx_players: Array[AudioStreamPlayer3D] = []
var _ambience_player: AudioStreamPlayer3D = null
var _music_player: AudioStreamPlayer = null

# Cached procedural sounds
var _procedural_sounds: Dictionary = {}

func _ready() -> void:
	# Create audio buses if they don't exist
	_setup_audio_buses()
	
	# Create 3D audio player pool (8 concurrent SFX)
	for i in range(8):
		var player := AudioStreamPlayer3D.new()
		player.name = "SFXPlayer_%d" % i
		player.bus = BUS_SFX
		player.max_distance = 30.0
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
		add_child(player)
		_sfx_players.append(player)
	
	# Create ambience player
	_ambience_player = AudioStreamPlayer3D.new()
	_ambience_player.name = "AmbiencePlayer"
	_ambience_player.bus = BUS_AMBIENCE
	_ambience_player.max_distance = 50.0
	add_child(_ambience_player)
	
	# Create music player (2D - non-spatial)
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = BUS_MUSIC
	add_child(_music_player)
	
	# Generate procedural sounds
	_generate_procedural_sounds()
	
	# Connect to event bus
	var eb := get_node("/root/EventBus")
	if eb:
		eb.player_spawned.connect(_on_player_spawned)

func _setup_audio_buses() -> void:
	var bus_layout := AudioServer.generate_bus_layout()
	
	# Check if buses exist
	var has_music := false
	var has_sfx := false
	var has_ambience := false
	
	for i in range(AudioServer.bus_count):
		var bus_name := AudioServer.get_bus_name(i)
		if bus_name == BUS_MUSIC: has_music = true
		if bus_name == BUS_SFX: has_sfx = true
		if bus_name == BUS_AMBIENCE: has_ambience = true
	
	# Add missing buses
	if not has_sfx:
		AudioServer.add_bus(AudioServer.bus_count)
		AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS_SFX)
		AudioServer.set_bus_volume_db(AudioServer.bus_count - 1, linear_to_db(sfx_volume))
	
	if not has_music:
		AudioServer.add_bus(AudioServer.bus_count)
		AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS_MUSIC)
		AudioServer.set_bus_volume_db(AudioServer.bus_count - 1, linear_to_db(music_volume))
	
	if not has_ambience:
		AudioServer.add_bus(AudioServer.bus_count)
		AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS_AMBIENCE)
		AudioServer.set_bus_volume_db(AudioServer.bus_count - 1, linear_to_db(ambience_volume))

func _generate_procedural_sounds() -> void:
	# Generate sword swing sound (synthetic whoosh)
	_procedural_sounds["sword_swing"] = _generate_whoosh_sound(0.3, 200.0, 2000.0)
	
	# Generate hit sound (impact thud)
	_procedural_sounds["hit"] = _generate_impact_sound(0.15)
	
	# Generate hurt sound (grunt)
	_procedural_sounds["hurt"] = _generate_grunt_sound(0.3)
	
	# Generate death sound
	_procedural_sounds["death"] = _generate_death_sound(0.5)
	
	# Generate pickup sound
	_procedural_sounds["pickup"] = _generate_pickup_sound(0.2)
	
	# Generate rain ambience
	_procedural_sounds["rain_ambience"] = _generate_noise_sound(5.0, 0.3)
	
	# Generate thunder
	_procedural_sounds["thunder"] = _generate_thunder_sound(1.5)
	
	# Generate boss roar
	_procedural_sounds["boss_roar"] = _generate_boss_roar(1.0)
	
	print("Procedural sounds generated: %d" % _procedural_sounds.size())

func _generate_whoosh_sound(duration: float, freq_start: float, freq_end: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)  # 16-bit mono
	
	for i in range(num_samples):
		var t := float(i) / sample_rate
		var progress := float(i) / num_samples
		var freq := lerpf(freq_start, freq_end, progress)
		var amp := sin(progress * PI) * 0.4  # Fade in/out
		var sample := sin(t * freq * TAU) * amp * 0.5
		sample += (randf() - 0.5) * 0.1 * amp  # Add noise
		var val := clampi(int(sample * 32767), -32767, 32767)
		data.encode_s16(i * 2, val)
	
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	return wav

func _generate_impact_sound(duration: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	
	for i in range(num_samples):
		var t := float(i) / sample_rate
		var progress := float(i) / num_samples
		var amp := exp(-progress * 15.0)  # Quick decay
		var sample := (randf() - 0.5) * amp * 0.8  # Noise burst
		sample += sin(t * 80.0 * TAU) * amp * 0.3  # Low thud
		var val := clampi(int(sample * 32767), -32767, 32767)
		data.encode_s16(i * 2, val)
	
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	return wav

func _generate_grunt_sound(duration: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	
	for i in range(num_samples):
		var progress := float(i) / num_samples
		var amp := sin(progress * PI) * 0.6
		var freq := lerpf(120.0, 80.0, progress)
		var sample := sin(float(i) / sample_rate * freq * TAU) * amp
		sample += (randf() - 0.5) * 0.15 * amp
		var val := clampi(int(sample * 32767), -32767, 32767)
		data.encode_s16(i * 2, val)
	
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	return wav

func _generate_death_sound(duration: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	
	for i in range(num_samples):
		var progress := float(i) / num_samples
		var amp := exp(-progress * 8.0)
		var freq := lerpf(150.0, 40.0, progress)
		var sample := sin(float(i) / sample_rate * freq * TAU) * amp * 0.5
		sample += (randf() - 0.5) * 0.2 * amp
		var val := clampi(int(sample * 32767), -32767, 32767)
		data.encode_s16(i * 2, val)
	
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	return wav

func _generate_pickup_sound(duration: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	
	for i in range(num_samples):
		var progress := float(i) / num_samples
		var amp := sin(progress * PI) * 0.5
		var freq := lerpf(400.0, 800.0, progress)
		var sample := sin(float(i) / sample_rate * freq * TAU) * amp
		var val := clampi(int(sample * 32767), -32767, 32767)
		data.encode_s16(i * 2, val)
	
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	return wav

func _generate_noise_sound(duration: float, volume: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	
	for i in range(num_samples):
		var sample := (randf() - 0.5) * volume * 0.5
		var val := clampi(int(sample * 32767), -32767, 32767)
		data.encode_s16(i * 2, val)
	
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	return wav

func _generate_thunder_sound(duration: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	
	for i in range(num_samples):
		var progress := float(i) / num_samples
		var amp := exp(-progress * 5.0) * 0.8
		var sample := (randf() - 0.5) * amp * 0.6
		sample += sin(float(i) / sample_rate * 60.0 * TAU) * amp * 0.4
		var val := clampi(int(sample * 32767), -32767, 32767)
		data.encode_s16(i * 2, val)
	
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	return wav

func _generate_boss_roar(duration: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	
	for i in range(num_samples):
		var progress := float(i) / num_samples
		var amp := sin(progress * PI) * 0.7
		var freq := lerpf(80.0, 150.0, progress)
		var sample := sin(float(i) / sample_rate * freq * TAU) * amp * 0.5
		sample += sin(float(i) / sample_rate * freq * 1.5 * TAU) * amp * 0.3
		sample += (randf() - 0.5) * 0.2 * amp
		var val := clampi(int(sample * 32767), -32767, 32767)
		data.encode_s16(i * 2, val)
	
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	return wav

# ─── Public API ──────────────────────────────────────────────────────────────

func play_sfx(sound_name: String, position: Vector3, pitch_variation: float = 0.1) -> void:
	if not _procedural_sounds.has(sound_name):
		push_warning("Sound not found: %s" % sound_name)
		return
	
	var player := _get_free_sfx_player()
	if not player:
		return
	
	player.stream = _procedural_sounds[sound_name]
	player.global_position = position
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()

func play_ambience(sound_name: String, position: Vector3 = Vector3.ZERO) -> void:
	if not _procedural_sounds.has(sound_name):
		return
	_ambience_player.stream = _procedural_sounds[sound_name]
	_ambience_player.global_position = position
	_ambience_player.play()

func stop_ambience() -> void:
	_ambience_player.stop()

func play_music(stream: AudioStream) -> void:
	_music_player.stream = stream
	_music_player.play()

func stop_music() -> void:
	_music_player.stop()

func _get_free_sfx_player() -> AudioStreamPlayer3D:
	for player in _sfx_players:
		if not player.playing:
			return player
	# If all busy, reuse the oldest
	return _sfx_players[0]

func _on_player_spawned(player: Node3D) -> void:
	# Play ambience at player position
	play_ambience("rain_ambience")
	
	# Connect to player attack
	if player.has_signal("attack_performed"):
		player.attack_performed.connect(func():
			play_sfx("sword_swing", player.global_position)
		)

# External sound loading (for when user downloads actual audio files)
func load_external_sound(sound_name: String, file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		push_error("Sound file not found: %s" % file_path)
		return false
	
	var stream := load(file_path) as AudioStream
	if not stream:
		push_error("Failed to load sound: %s" % file_path)
		return false
	
	_procedural_sounds[sound_name] = stream
	print("Loaded external sound: %s -> %s" % [sound_name, file_path])
	return true
