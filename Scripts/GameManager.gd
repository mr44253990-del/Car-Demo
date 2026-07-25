extends Node

# --- Global Game State ---
var coins: int = 500
var daily_mission_completed: bool = false
var selected_mission_id: int = 0 # 0: Free Roam, 1: Coin Rush, 2: Fuel Survivor

# --- Daily Check-In persistent save ---
var last_claim_date: String = ""

# --- Performance Upgrades (Persistent, Max 5 levels each) ---
var upgrade_engine: int = 1
var upgrade_handling: int = 1
var upgrade_brakes: int = 1

# --- Underglow Color Choice (Persistent) ---
var underglow_color: String = "cyan" # cyan, pink, gold, red

# --- Car State ---
var car_fuel: float = 100.0
var car_max_fuel: float = 100.0
var car_damage: float = 0.0 # 0.0 (Perfect) to 100.0 (Destroyed)
var car_max_damage: float = 100.0

# --- Settings ---
var volume_master: float = 1.0
var volume_music: float = 0.8
var volume_sfx: float = 0.8

var graphics_preset: int = 1 # 0: Low, 1: Medium, 2: High
var render_distance: float = 250.0
var resolution_scale: float = 1.0
var texture_quality: int = 1

# --- Current Active Weather in Level ---
var current_weather: String = "sunny" # updated dynamically by GameLevel

# --- Multiplayer State ---
var is_multiplayer: bool = false
var is_host: bool = false
var my_player_name: String = "Player"
var room_id: String = "1234"
var connected_players: Dictionary = {}

# --- Scene Transition Helper ---
var target_scene_path: String = ""

func _ready():
	load_game_settings()
	apply_graphics_settings()

func save_game_settings():
	var save_data = {
		"coins": coins,
		"last_claim_date": last_claim_date,
		"upgrade_engine": upgrade_engine,
		"upgrade_handling": upgrade_handling,
		"upgrade_brakes": upgrade_brakes,
		"underglow_color": underglow_color,
		"volume_master": volume_master,
		"volume_music": volume_music,
		"volume_sfx": volume_sfx,
		"graphics_preset": graphics_preset,
		"render_distance": render_distance,
		"resolution_scale": resolution_scale,
		"texture_quality": texture_quality
	}
	var file = FileAccess.open("user://car_demo_save.cfg", FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()

func load_game_settings():
	if FileAccess.file_exists("user://car_demo_save.cfg"):
		var file = FileAccess.open("user://car_demo_save.cfg", FileAccess.READ)
		if file:
			var save_data = file.get_var()
			if save_data is Dictionary:
				if save_data.has("coins"): coins = save_data["coins"]
				if save_data.has("last_claim_date"): last_claim_date = save_data["last_claim_date"]
				if save_data.has("upgrade_engine"): upgrade_engine = save_data["upgrade_engine"]
				if save_data.has("upgrade_handling"): upgrade_handling = save_data["upgrade_handling"]
				if save_data.has("upgrade_brakes"): upgrade_brakes = save_data["upgrade_brakes"]
				if save_data.has("underglow_color"): underglow_color = save_data["underglow_color"]
				if save_data.has("volume_master"): volume_master = save_data["volume_master"]
				if save_data.has("volume_music"): volume_music = save_data["volume_music"]
				if save_data.has("volume_sfx"): volume_sfx = save_data["volume_sfx"]
				if save_data.has("graphics_preset"): graphics_preset = save_data["graphics_preset"]
				if save_data.has("render_distance"): render_distance = save_data["render_distance"]
				if save_data.has("resolution_scale"): resolution_scale = save_data["resolution_scale"]
				if save_data.has("texture_quality"): texture_quality = save_data["texture_quality"]
			file.close()

func apply_graphics_settings():
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(volume_master))
	
	var music_bus_idx = AudioServer.get_bus_index("Music")
	if music_bus_idx != -1:
		AudioServer.set_bus_volume_db(music_bus_idx, linear_to_db(volume_music))
	var sfx_bus_idx = AudioServer.get_bus_index("SFX")
	if sfx_bus_idx != -1:
		AudioServer.set_bus_volume_db(sfx_bus_idx, linear_to_db(volume_sfx))
		
	get_viewport().scaling_3d_scale = resolution_scale
	
	match graphics_preset:
		0: # Low
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
			get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		1: # Medium
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		2: # High
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2

# --- DAILY REWARD SYSTEM ---
func claim_daily_reward() -> Dictionary:
	var today_date = Time.get_date_string_from_system()
	
	if last_claim_date == today_date:
		return {
			"success": false,
			"message": "Already claimed today! Come back tomorrow."
		}
	else:
		coins += 200
		last_claim_date = today_date
		save_game_settings()
		return {
			"success": true,
			"message": "Claimed today's reward! +200 Coins 🪙",
			"coins": coins
		}

func transition_to_scene(scene_path: String):
	target_scene_path = scene_path
	get_tree().change_scene_to_file("res://Scenes/LoadingScreen.tscn")

func reset_car_state():
	car_fuel = car_max_fuel
	car_damage = 0.0
