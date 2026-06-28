# procedural_audio_generator.gd
# Helper to generate synth-based AudioStreamWAV assets
class_name ProceduralAudioGenerator
extends Object

static func generate_whoosh_sound(duration: float, freq_start: float, freq_end: float) -> AudioStreamWAV:
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

static func generate_impact_sound(duration: float) -> AudioStreamWAV:
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

static func generate_grunt_sound(duration: float) -> AudioStreamWAV:
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

static func generate_death_sound(duration: float) -> AudioStreamWAV:
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

static func generate_pickup_sound(duration: float) -> AudioStreamWAV:
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

static func generate_noise_sound(duration: float, volume: float) -> AudioStreamWAV:
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

static func generate_thunder_sound(duration: float) -> AudioStreamWAV:
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

static func generate_boss_roar(duration: float) -> AudioStreamWAV:
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
