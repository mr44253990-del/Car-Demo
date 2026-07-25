extends Control

# Panel references
@onready var main_buttons_container = $MainLayout/Sidebar/ButtonsContainer
@onready var play_panel = $MainLayout/ContentArea/PlayPanel
@onready var garage_panel = $MainLayout/ContentArea/GaragePanel
@onready var settings_panel = $MainLayout/ContentArea/SettingsPanel
@onready var multiplayer_panel = $MainLayout/ContentArea/MultiplayerPanel
@onready var daily_panel = $MainLayout/ContentArea/DailyPanel

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

@onready var engine_up_label = $MainLayout/ContentArea/GaragePanel/UpgradesContainer/EngineUp/Label
@onready var handling_up_label = $MainLayout/ContentArea/GaragePanel/UpgradesContainer/HandlingUp/Label
@onready var brakes_up_label = $MainLayout/ContentArea/GaragePanel/UpgradesContainer/BrakesUp/Label

# Daily Panel labels
@onready var daily_status_label = $MainLayout/ContentArea/DailyPanel/DailyStatusLabel

# Multiplayer inputs/labels
@onready var ip_input = $MainLayout/ContentArea/MultiplayerPanel/GridContainer/IpInput
@onready var port_input = $MainLayout/ContentArea/MultiplayerPanel/GridContainer/PortInput
@onready var mp_status_label = $MainLayout/ContentArea/MultiplayerPanel/MpStatusLabel
@onready var player_list_label = $MainLayout/ContentArea/MultiplayerPanel/PlayerListLabel
@onready var start_mp_btn = $MainLayout/ContentArea/MultiplayerPanel/StartMpButton

const DEFAULT_PORT = 25565
var peer = ENetMultiplayerPeer.new()

# Store original positions of panels for slide-in transitions
var panel_positions: Dictionary = {}

func _ready():
	get_tree().paused = false
	
	# Connect multiplayer signals safely
	if not multiplayer.peer_connected.is_connected(_on_player_connected):
		multiplayer.peer_connected.connect(_on_player_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_player_disconnected):
		multiplayer.peer_disconnected.connect(_on_player_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connection_success):
		multiplayer.connected_to_server.connect(_on_connection_success)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	_cache_panel_positions()
	
	update_global_ui()
	show_panel(play_panel) # Default panel
	init_settings_values()
	select_mission(0)
	
	_apply_dynamic_hover_animations()

func _cache_panel_positions():
	var panels = [play_panel, garage_panel, settings_panel, multiplayer_panel, daily_panel]
	for p in panels:
		panel_positions[p.name] = p.position

func update_global_ui():
	coins_label.text = "COINS: " + str(GameManager.coins) + " 🪙"
	update_garage_ui()
	update_daily_status_ui()

# --- SLIDING PANEL TRANSITIONS (Forza Horizon Style) ---
func show_panel(target_panel: Panel):
	var panels = [play_panel, garage_panel, settings_panel, multiplayer_panel, daily_panel]
	for p in panels:
		p.visible = false
		p.modulate.a = 0.0
	
	target_panel.visible = true
	target_panel.modulate.a = 0.0
	
	var orig_pos = panel_positions.get(target_panel.name, target_panel.position)
	target_panel.position = orig_pos + Vector2(60, 0)
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUART)
	tween.tween_property(target_panel, "modulate:a", 1.0, 0.35)
	tween.parallel().tween_property(target_panel, "position", orig_pos, 0.35)

# --- DYNAMIC HOVER EFFECTS ---
func _apply_dynamic_hover_animations():
	_hook_buttons_recursive(self)

func _hook_buttons_recursive(node: Node):
	if node is Button:
		node.pivot_offset = node.size / 2.0
		if not node.mouse_entered.is_connected(_on_button_hover_enter.bind(node)):
			node.mouse_entered.connect(_on_button_hover_enter.bind(node))
		if not node.mouse_exited.is_connected(_on_button_hover_exit.bind(node)):
			node.mouse_exited.connect(_on_button_hover_exit.bind(node))
			
	for child in node.get_children():
		_hook_buttons_recursive(child)

func _on_button_hover_enter(btn: Button):
	btn.pivot_offset = btn.size / 2.0
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.4)
	btn.add_theme_color_override("font_color", Color(1, 0, 0.45))

func _on_button_hover_exit(btn: Button):
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.25)
	btn.remove_theme_color_override("font_color")

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

func _on_daily_tab_pressed():
	show_panel(daily_panel)
	update_daily_status_ui()

func _on_exit_pressed():
	get_tree().quit()

# --- PLAY PANEL MISSION SELECT ---
func select_mission(id: int):
	GameManager.selected_mission_id = id
	match id:
		0:
			mission_desc_label.text = "MISSION 1: Free Roam\n\nNo time limit! Practice drifting, explore the map, collect coins, and refuel whenever you want."
		1:
			mission_desc_label.text = "MISSION 2: Coin Rush\n\nCollect all 100+ scattered coins on the map before time runs out! Drive fast and precise."
		2:
			mission_desc_label.text = "MISSION 3: Fuel Survivor\n\nFuel consumption is doubled! Keep buying fuel from stations before running empty. Survive as long as you can!"

func _on_start_game_pressed():
	GameManager.reset_car_state()
	GameManager.is_multiplayer = false
	GameManager.transition_to_scene("res://main.tscn")

# --- GARAGE SYSTEM (TUNING & LIVERY) ---
func update_garage_ui():
	var damage = GameManager.car_damage
	damage_label.text = "Car Damage: " + str(round(damage)) + "%"
	var cost = int(damage * 5)
	repair_cost_label.text = "Repair Cost: " + str(cost) + " Coins"
	
	if damage == 0:
		garage_car_status.text = "Status: Perfect Condition!"
		garage_car_status.add_theme_color_override("font_color", Color.GREEN)
	elif damage < 50:
		garage_car_status.text = "Status: Light Scratches & Dents."
		garage_car_status.add_theme_color_override("font_color", Color.YELLOW)
	else:
		garage_car_status.text = "Status: Heavily Damaged! Repair immediately."
		garage_car_status.add_theme_color_override("font_color", Color.RED)
		
	# Update Tuning Labels & Upgrade Prices
	var cost_engine = GameManager.upgrade_engine * 150
	var cost_handling = GameManager.upgrade_handling * 150
	var cost_brakes = GameManager.upgrade_brakes * 150
	
	engine_up_label.text = "Engine (Lvl " + str(GameManager.upgrade_engine) + "/5)\nCost: " + (str(cost_engine) if GameManager.upgrade_engine < 5 else "MAX") + " 🪙"
	handling_up_label.text = "Handling (Lvl " + str(GameManager.upgrade_handling) + "/5)\nCost: " + (str(cost_handling) if GameManager.upgrade_handling < 5 else "MAX") + " 🪙"
	brakes_up_label.text = "Brakes (Lvl " + str(GameManager.upgrade_brakes) + "/5)\nCost: " + (str(cost_brakes) if GameManager.upgrade_brakes < 5 else "MAX") + " 🪙"

func _on_repair_button_pressed():
	var cost = int(GameManager.car_damage * 5)
	if GameManager.car_damage <= 0:
		return
	if GameManager.coins >= cost:
		GameManager.coins -= cost
		GameManager.car_damage = 0.0
		GameManager.save_game_settings()
		update_global_ui()
		update_garage_ui()
	else:
		repair_cost_label.text = "NOT ENOUGH COINS! Need " + str(cost) + " Coins"

func _on_upgrade_pressed(type: String):
	var current_lvl = 1
	if type == "engine": current_lvl = GameManager.upgrade_engine
	elif type == "handling": current_lvl = GameManager.upgrade_handling
	elif type == "brakes": current_lvl = GameManager.upgrade_brakes
	
	if current_lvl >= 5:
		repair_cost_label.text = "Tuning category is already at MAX level! 🏁"
		return
		
	var cost = current_lvl * 150
	if GameManager.coins >= cost:
		GameManager.coins -= cost
		if type == "engine": GameManager.upgrade_engine += 1
		elif type == "handling": GameManager.upgrade_handling += 1
		elif type == "brakes": GameManager.upgrade_brakes += 1
		
		GameManager.save_game_settings()
		update_global_ui()
		repair_cost_label.text = "Upgraded " + type.to_upper() + " successfully! 🪙 -" + str(cost)
	else:
		repair_cost_label.text = "NOT ENOUGH COINS! Need " + str(cost) + " Coins 🪙"

func _on_paint_car(color_name: String):
	var paint_cost = 50
	if GameManager.coins >= paint_cost:
		GameManager.coins -= paint_cost
		var save_data = {
			"coins": GameManager.coins,
			"car_paint": color_name
		}
		var file = FileAccess.open("user://car_paint.cfg", FileAccess.WRITE)
		if file:
			file.store_var(save_data)
			file.close()
		update_global_ui()
		repair_cost_label.text = "Painted " + color_name.to_upper() + "! Cost: " + str(paint_cost) + " Coins"
	else:
		repair_cost_label.text = "NOT ENOUGH COINS! Paint cost: " + str(paint_cost) + " Coins"

func _on_underglow_color_pressed(color_name: String):
	GameManager.underglow_color = color_name
	GameManager.save_game_settings()
	repair_cost_label.text = "Underglow changed to " + color_name.to_upper() + "! 💡"

# --- PERSISTENT DAILY REWARD CENTER ---
func update_daily_status_ui():
	var today_date = Time.get_date_string_from_system()
	if GameManager.last_claim_date == today_date:
		daily_status_label.text = "Status: ALREADY CLAIMED TODAY ✅\nCome back tomorrow for your next reward!"
		daily_status_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		daily_status_label.text = "Status: REWARD READY TO CLAIM 🎁\nClaim now to receive 200 Coins persistently on your device!"
		daily_status_label.add_theme_color_override("font_color", Color(1, 0, 0.45)) # neon pink

func _on_claim_daily_pressed():
	var res = GameManager.claim_daily_reward()
	daily_status_label.text = res["message"]
	if res["success"]:
		daily_status_label.add_theme_color_override("font_color", Color.GREEN)
		update_global_ui()
	else:
		daily_status_label.add_theme_color_override("font_color", Color.YELLOW)

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

# --- MULTIPLAYER SYSTEM ---
func _on_host_wifi_pressed():
	var port = int(port_input.text) if port_input.text != "" else DEFAULT_PORT
	peer.close()
	var err = peer.create_server(port, 6)
	if err != OK:
		mp_status_label.text = "Failed to host room! Error: " + str(err)
		return
	
	multiplayer.multiplayer_peer = peer
	GameManager.is_multiplayer = true
	GameManager.is_host = true
	mp_status_label.text = "Room Created! Port: " + str(port) + "\nShare your Hotspot/WiFi IP with friends."
	start_mp_btn.visible = true
	update_players_list()

func _on_join_room_pressed():
	var ip = ip_input.text if ip_input.text != "" else "127.0.0.1"
	var port = int(port_input.text) if port_input.text != "" else DEFAULT_PORT
	
	mp_status_label.text = "Connecting to " + ip + ":" + str(port) + "..."
	peer.close()
	var err = peer.create_client(ip, port)
	if err != OK:
		mp_status_label.text = "Connection failed! Error: " + str(err)
		return
		
	multiplayer.multiplayer_peer = peer
	GameManager.is_multiplayer = true
	GameManager.is_host = false
	start_mp_btn.visible = false

func _on_start_multiplayer_game():
	if GameManager.is_host:
		start_game_rpc.rpc()

@rpc("any_peer", "call_local", "reliable")
func start_game_rpc():
	GameManager.reset_car_state()
	GameManager.transition_to_scene("res://main.tscn")

func _on_player_connected(id: int):
	mp_status_label.text = "Player connected! ID: " + str(id)
	update_players_list()

func _on_player_disconnected(id: int):
	mp_status_label.text = "Player disconnected! ID: " + str(id)
	update_players_list()

func _on_connection_success():
	mp_status_label.text = "Successfully joined the room!"
	update_players_list()

func _on_connection_failed():
	mp_status_label.text = "Failed to connect to host! Check IP."

func _on_server_disconnected():
	mp_status_label.text = "Host disconnected."
	start_mp_btn.visible = false
	GameManager.is_multiplayer = false

func update_players_list():
	var plist = "Connected Players:\n"
	plist += "- Host (You)\n" if GameManager.is_host else "- Host\n"
	for p in multiplayer.get_peers():
		plist += "- Player " + str(p) + "\n"
	player_list_label.text = plist
