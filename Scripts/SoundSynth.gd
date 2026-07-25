extends Node
class_name SoundSynth

# Procedural Audio Synth for Engine, Horn, and Drifts (No asset files needed!)
var engine_player: AudioStreamPlayer = null
var horn_player: AudioStreamPlayer = null
var skid_player: AudioStreamPlayer = null

var generator_engine: AudioStreamGenerator = null
var generator_horn: AudioStreamGenerator = null
var generator_skid: AudioStreamGenerator = null

var playback_engine: AudioStreamGeneratorPlayback = null
var playback_horn: AudioStreamGeneratorPlayback = null
var playback_skid: AudioStreamGeneratorPlayback = null

var engine_pitch_factor: float = 1.0
var is_horn_active: bool = false
var is_skid_active: bool = false

var phase_engine: float = 0.0
var phase_horn: float = 0.0
var phase_skid: float = 0.0

func _ready():
	# 1. Setup Engine Sound Player
	engine_player = AudioStreamPlayer.new()
	add_child(engine_player)
	generator_engine = AudioStreamGenerator.new()
	generator_engine.mix_rate = 22050
	generator_engine.buffer_length = 0.1
	engine_player.stream = generator_engine
	engine_player.volume_db = -10.0
	engine_player.play()
	playback_engine = engine_player.get_stream_playback()
	
	# 2. Setup Horn Player
	horn_player = AudioStreamPlayer.new()
	add_child(horn_player)
	generator_horn = AudioStreamGenerator.new()
	generator_horn.mix_rate = 22050
	generator_horn.buffer_length = 0.1
	horn_player.stream = generator_horn
	horn_player.volume_db = -15.0
	horn_player.play()
	playback_horn = horn_player.get_stream_playback()
	
	# 3. Setup Brake Skid Player
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
	# Synthesize Engine audio wave (Low frequency rumble that pitch-scales with speed)
	if playback_engine:
		var frames_available = playback_engine.get_frames_available()
		var target_freq = 60.0 + (engine_pitch_factor * 120.0) # mapping speed to frequency
		var increment = target_freq / 22050.0
		
		for i in range(frames_available):
			var sample = sin(phase_engine * 2.0 * PI) * 0.5 # Sine wave
			# Add square wave harmonic for engine rumble texture
			sample += (1.0 if sin(phase_engine * 2.0 * PI * 2.0) > 0.0 else -1.0) * 0.15
			playback_engine.push_frame(Vector2(sample, sample))
			phase_engine = fmod(phase_engine + increment, 1.0)
			
	# Synthesize Horn audio wave (High frequency dual-tone beep)
	if playback_horn:
		var frames_available = playback_horn.get_frames_available()
		var increment1 = 440.0 / 22050.0
		var increment2 = 445.0 / 22050.0 # dual tone harmonic
		
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
				# Add white noise to friction squeal for realism
				sample = (sin(phase_skid * 2.0 * PI) + randf_range(-1.0, 1.0) * 0.4) * 0.15
			playback_skid.push_frame(Vector2(sample, sample))
			phase_skid = fmod(phase_skid + increment, 1.0)

func set_engine_pitch(factor: float):
	engine_pitch_factor = clamp(factor, 0.2, 3.5)

func set_horn(active: bool):
	is_horn_active = active

func set_skid(active: bool):
	is_skid_active = active
