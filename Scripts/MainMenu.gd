extends Control

# Panel references
@onready var main_buttons_container = $MainLayout/Sidebar/ButtonsContainer
@onready var play_panel = $MainLayout/ContentArea/PlayPanel
@onready var garage_panel = $MainLayout/ContentArea/GaragePanel
@onready var settings_panel = $MainLayout/ContentArea/SettingsPanel
@onready var multiplayer_panel = $MainLayout/ContentArea/MultiplayerPanel

# Coin and status labels
@onready var coins_label = $TopBar/CoinsLabel

# Settings sliders/options
@onready var master_slider = $MainLayout/ContentArea/SettingsPanel/VolumeContainer/MasterSlider
@onready var music_slider = $MainLayout/ContentArea/SettingsPanel/VolumeContainer/MusicSlider
@onready var sfx_slider = $MainLayout/ContentArea/SettingsPanel/VolumeContainer/SfxSlider
@onready var graphics_preset_btn = $MainLayout/ContentArea/SettingsPanel/GraphicsContainer/PresetOption
@onready var render_distance_slider = $MainLayout/ContentArea/SettingsPanel/GraphicsContainer/DistSlider
@onready var res_scale_slider = $MainLayout/ContentArea/SettingsPanel/GraphicsContainer/ResSlider

# Play panel mission buttons
@onready var mission_desc_label = $MainLayout/ContentArea/PlayPanel/MissionDescLabel

# Garage panel labels
@onready var damage_label = $MainLayout/ContentArea/GaragePanel/DamageLabel
@onready var repair_cost_label = $MainLayout/ContentArea/GaragePanel/RepairCostLabel
@onready var garage_car_status = $MainLayout/ContentArea/GaragePanel/CarStatusLabel

# Multiplayer inputs/labels
@onready var ip_input = $MainLayout/ContentArea/MultiplayerPanel/GridContainer/IpInput
@onready var port_input = $MainLayout/ContentArea/MultiplayerPanel/GridContainer/PortInput
@onready var mp_status_label = $MainLayout/ContentArea/MultiplayerPanel/MpStatusLabel
@onready var player_list_label = $MainLayout/ContentArea/MultiplayerPanel/PlayerListLabel
@onready var start_mp_btn = $MainLayout/ContentArea/MultiplayerPanel/StartMpButton

const DEFAULT_PORT = 25565
var peer = ENetMultiplayerPeer.new()

func _ready():
	# Connect multiplayer signals
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connection_success)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	update_global_ui()
	show_panel(play_panel) # Default panel
	init_settings_values()
	select_mission(0)

func update_global_ui():
	coins_label.text = "🪙 কয়েন: " + str(GameManager.coins)
	update_garage_ui()

func show_panel(target_panel: Panel):
	play_panel.visible = false
	garage_panel.visible = false
	settings_panel.visible = false
	multiplayer_panel.visible = false
	
	target_panel.visible = true

# --- TAB SELECTION HANDLERS ---
func _on_play_tab_pressed():
	show_panel(play_panel)

func _on_garage_tab_pressed():
	show_panel(garage_panel)
	update_garage_ui()

func _on_multiplayer_tab_pressed():
	show_panel(multiplayer_panel)

func _on_settings_tab_pressed():
	show_panel(settings_panel)

func _on_exit_pressed():
	get_tree().quit()

# --- PLAY PANEL MISSION SELECT ---
func select_mission(id: int):
	GameManager.selected_mission_id = id
	match id:
		0:
			mission_desc_label.text = "মিশন ১: ফ্রি রোম (Free Roam)\n\nকোন সময়সীমা নেই! ম্যাপে ঘুরে বেড়ান, ড্রিপ্ট করা শিখুন এবং কয়েন সংগ্রহ করুন।"
		1:
			mission_desc_label.text = "মিশন ২: কয়েন হান্টার (Coin Rush)\n\n৯০ সেকেন্ডের মধ্যে ম্যাপের সব ছড়িয়ে থাকা কয়েন সংগ্রহ করুন! দ্রুত ড্রাইভ করুন।"
		2:
			mission_desc_label.text = "মিশন ৩: ফুয়েল সার্ভাইভার (Fuel Survivor)\n\nফুয়েল দ্রুত শেষ হবে! ফুয়েল স্টেশনে যাওয়ার আগে ফুয়েল শেষ হতে দেওয়া যাবে না।"

func _on_start_game_pressed():
	GameManager.reset_car_state()
	GameManager.is_multiplayer = false
	GameManager.transition_to_scene("res://main.tscn")

# --- GARAGE SYSTEM ---
func update_garage_ui():
	var damage = GameManager.car_damage
	damage_label.text = "গাড়ির ড্যামেজ: " + str(round(damage)) + "%"
	var cost = int(damage * 5)
	repair_cost_label.text = "মেরামত খরচ: " + str(cost) + " 🪙 কয়েন"
	
	if damage == 0:
		garage_car_status.text = "গাড়ির কন্ডিশন: চমৎকার! (মেরামত প্রয়োজন নেই)"
		garage_car_status.add_theme_color_override("font_color", Color.GREEN)
	elif damage < 50:
		garage_car_status.text = "গাড়ির কন্ডিশন: হালকা ড্যামেজ।"
		garage_car_status.add_theme_color_override("font_color", Color.YELLOW)
	else:
		garage_car_status.text = "গাড়ির কন্ডিশন: মারাত্মক ড্যামেজ! এখনই মেরামত করুন।"
		garage_car_status.add_theme_color_override("font_color", Color.RED)

func _on_repair_button_pressed():
	var cost = int(GameManager.car_damage * 5)
	if GameManager.car_damage <= 0:
		mp_status_label.text = "গাড়ি ইতিমধ্যেই সম্পূর্ণ ঠিক আছে!"
		return
	if GameManager.coins >= cost:
		GameManager.coins -= cost
		GameManager.car_damage = 0.0
		GameManager.save_game_settings()
		update_global_ui()
		update_garage_ui()
	else:
		# Flash error
		repair_cost_label.text = "পর্যাপ্ত কয়েন নেই! মেরামত করতে " + str(cost) + " কয়েন লাগবে।"

# --- SETTINGS SYSTEM ---
func init_settings_values():
	master_slider.value = GameManager.volume_master
	music_slider.value = GameManager.volume_music
	sfx_slider.value = GameManager.volume_sfx
	graphics_preset_btn.selected = GameManager.graphics_preset
	render_distance_slider.value = GameManager.render_distance
	res_scale_slider.value = GameManager.resolution_scale

func _on_volume_changed(value: float, bus: String):
	if bus == "Master":
		GameManager.volume_master = value
	elif bus == "Music":
		GameManager.volume_music = value
	elif bus == "SFX":
		GameManager.volume_sfx = value
	GameManager.apply_graphics_settings()
	GameManager.save_game_settings()

func _on_preset_selected(index: int):
	GameManager.graphics_preset = index
	match index:
		0: # Low
			GameManager.render_distance = 100.0
			GameManager.resolution_scale = 0.7
		1: # Medium
			GameManager.render_distance = 250.0
			GameManager.resolution_scale = 1.0
		2: # High
			GameManager.render_distance = 500.0
			GameManager.resolution_scale = 1.3
			
	init_settings_values()
	GameManager.apply_graphics_settings()
	GameManager.save_game_settings()

func _on_render_distance_changed(value: float):
	GameManager.render_distance = value
	GameManager.save_game_settings()

func _on_res_scale_changed(value: float):
	GameManager.resolution_scale = value
	GameManager.apply_graphics_settings()
	GameManager.save_game_settings()

# --- MULTIPLAYER SYSTEM (WiFi / Hotspot Offline) ---
func _on_host_wifi_pressed():
	# Start server
	var port = int(port_input.text) if port_input.text != "" else DEFAULT_PORT
	peer.close()
	var err = peer.create_server(port, 6) # max 6 players
	if err != OK:
		mp_status_label.text = "রুম তৈরি করতে ব্যর্থ! এরর কোড: " + str(err)
		return
	
	multiplayer.multiplayer_peer = peer
	GameManager.is_multiplayer = true
	GameManager.is_host = true
	mp_status_label.text = "রুম তৈরি হয়েছে! পোর্ট: " + str(port) + "\nআপনার আইপি অ্যাড্রেস বন্ধুদের দিন।"
	start_mp_btn.visible = true
	update_players_list()

func _on_join_room_pressed():
	var ip = ip_input.text if ip_input.text != "" else "127.0.0.1"
	var port = int(port_input.text) if port_input.text != "" else DEFAULT_PORT
	
	mp_status_label.text = "কানেক্ট করা হচ্ছে: " + ip + ":" + str(port) + "..."
	peer.close()
	var err = peer.create_client(ip, port)
	if err != OK:
		mp_status_label.text = "কানেকশন শুরু করতে ব্যর্থ! এরর কোড: " + str(err)
		return
		
	multiplayer.multiplayer_peer = peer
	GameManager.is_multiplayer = true
	GameManager.is_host = false
	start_mp_btn.visible = false

func _on_start_multiplayer_game():
	if GameManager.is_host:
		# Inform all clients to load the game
		start_game_rpc.rpc()

@rpc("any_peer", "call_local", "reliable")
func start_game_rpc():
	GameManager.reset_car_state()
	GameManager.transition_to_scene("res://main.tscn")

func _on_player_connected(id: int):
	mp_status_label.text = "নতুন খেলোয়াড় যুক্ত হয়েছে! আইডি: " + str(id)
	update_players_list()

func _on_player_disconnected(id: int):
	mp_status_label.text = "খেলোয়াড় চলে গেছে! আইডি: " + str(id)
	update_players_list()

func _on_connection_success():
	mp_status_label.text = "রুমে সফলভাবে যুক্ত হয়েছেন!"
	update_players_list()

func _on_connection_failed():
	mp_status_label.text = "কানেকশন ব্যর্থ হয়েছে! আইপি বা পোর্ট চেক করুন।"

func _on_server_disconnected():
	mp_status_label.text = "হোস্ট সার্ভার বন্ধ করে দিয়েছে।"
	start_mp_btn.visible = false
	GameManager.is_multiplayer = false

func update_players_list():
	var plist = "যুক্ত প্লেয়ারদের তালিকা:\n"
	plist += "- হোস্ট (আপনি)\n" if GameManager.is_host else "- হোস্ট\n"
	for p in multiplayer.get_peers():
		plist += "- প্লেয়ার " + str(p) + "\n"
	player_list_label.text = plist
