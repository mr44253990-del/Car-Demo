extends Node
class_name SoundSynth

# Procedural & Dynamic Audio Synth featuring custom WAV engine loop!
var engine_player: AudioStreamPlayer = null
var horn_player: AudioStreamPlayer = null
var skid_player: AudioStreamPlayer = null

var generator_horn: AudioStreamGenerator = null
var generator_skid: AudioStreamGenerator = null

var playback_horn: AudioStreamGeneratorPlayback = null
var playback_skid: AudioStreamGeneratorPlayback = null

var engine_pitch_factor: float = 1.0
var is_horn_active: bool = false
var is_skid_active: bool = false

var phase_horn: float = 0.0
var phase_skid: float = 0.0

func _ready():
	# 1. Setup Engine Sound Player (Loads custom WAV loop!)
	engine_player = AudioStreamPlayer.new()
	add_child(engine_player)
	
	var wav_stream = load("res://smooth_01.wav")
	if wav_stream is AudioStreamWAV:
		# Enable continuous looping in Godot 4
		wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		engine_player.stream = wav_stream
		engine_player.volume_db = -15.0
		engine_player.play()
		print("Custom smooth_01.wav loaded and looping as engine audio stream.")
	else:
		print("Warning: res://smooth_01.wav is not a valid AudioStreamWAV.")

	# 2. Setup Horn Player (Procedural Synth)
	horn_player = AudioStreamPlayer.new()
	add_child(horn_player)
	generator_horn = AudioStreamGenerator.new()
	generator_horn.mix_rate = 22050
	generator_horn.buffer_length = 0.1
	horn_player.stream = generator_horn
	horn_player.volume_db = -15.0
	horn_player.play()
	playback_horn = horn_player.get_stream_playback()
	
	# 3. Setup Brake Skid Player (Procedural Synth)
	skid_player = AudioStreamPlayer.new()
	add_child(skid_player)
	generator_skid = AudioStreamGenerator.new()
	generator_skid.mix_rate = 22050
	generator_skid.buffer_length = 0.1
	skid_player.stream = generator_skid
	skid_player.volume_db = -20.0
	skid_player.play()
	playback_skid = skid_player.get_stream_playback()

func _process(delta):
	# Update Engine Pitch & Volume Dynamically based on current speed/engine_pitch_factor
	if engine_player and engine_player.playing:
		# Speed ranges map pitch scale from 0.6x (idle) to 2.8x (top speed!)
		engine_player.pitch_scale = clamp(0.5 + (engine_pitch_factor * 0.75), 0.5, 3.0)
		# Increase volume slightly at high speeds for realistic throttle rumble
		engine_player.volume_db = clamp(-18.0 + (engine_pitch_factor * 4.0), -20.0, 0.0)
			
	# Synthesize Horn audio wave (High frequency dual-tone beep)
	if playback_horn:
		var frames_available = playback_horn.get_frames_available()
		var increment1 = 440.0 / 22050.0
		
		for i in range(frames_available):
			var sample = 0.0
			if is_horn_active:
				sample = (sin(phase_horn * 2.0 * PI) + sin(phase_horn * 2.0 * PI * 1.5)) * 0.3
			playback_horn.push_frame(Vector2(sample, sample))
			phase_horn = fmod(phase_horn + increment1, 1.0)

	# Synthesize Tire Skid audio wave (High frequency friction squeal)
	if playback_skid:
		var frames_available = playback_skid.get_frames_available()
		var increment = 880.0 / 22050.0
		
		for i in range(frames_available):
			var sample = 0.0
			if is_skid_active:
				sample = (sin(phase_skid * 2.0 * PI) + randf_range(-1.0, 1.0) * 0.4) * 0.15
			playback_skid.push_frame(Vector2(sample, sample))
			phase_skid = fmod(phase_skid + increment, 1.0)

func set_engine_pitch(factor: float):
	engine_pitch_factor = clamp(factor, 0.2, 3.5)

func set_horn(active: bool):
	is_horn_active = active

func set_skid(active: bool):
	is_skid_active = active
