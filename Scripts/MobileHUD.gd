extends CanvasLayer

@onready var fps_label = $MainContainer/TopLeft/FpsLabel
@onready var coins_label = $MainContainer/TopLeft/CoinsLabel
@onready var speed_label = $MainContainer/SpeedLabel
@onready var gear_label = $MainContainer/GearLabel
@onready var fuel_bar = $MainContainer/StatsContainer/FuelBar
@onready var fuel_label = $MainContainer/StatsContainer/FuelBar/Label
@onready var damage_bar = $MainContainer/StatsContainer/DamageBar
@onready var damage_label = $MainContainer/StatsContainer/DamageBar/Label

@onready var pause_menu = $PauseMenu
@onready var mission_status_label = $MainContainer/MissionStatusLabel

# Sound sliders in pause menu
@onready var master_slider = $PauseMenu/VolumeContainer/MasterSlider
@onready var music_slider = $PauseMenu/VolumeContainer/MusicSlider
@onready var sfx_slider = $PauseMenu/VolumeContainer/SfxSlider

# Fuel Station Interactive Elements
@onready var refuel_prompt_btn = $MainContainer/RefuelPromptBtn
@onready var refuel_menu = $RefuelMenu
@onready var refuel_status_label = $RefuelMenu/StatusLabel

var car_node: BaseCar = null

func _ready():
	add_to_group("mobile_hud")
	
	pause_menu.visible = false
	refuel_menu.visible = false
	refuel_prompt_btn.visible = false
	
	# Try to find car
	var cars = get_tree().get_nodes_in_group("player_car")
	if cars.size() > 0:
		car_node = cars[0] as BaseCar
		
	# Setup pause menu sliders
	master_slider.value = GameManager.volume_master
	music_slider.value = GameManager.volume_music
	sfx_slider.value = GameManager.volume_sfx
	
	# Update HUD display according to selected mission
	match GameManager.selected_mission_id:
		0:
			mission_status_label.text = "MISSION: Free Roam (No time limit)"
		1:
			mission_status_label.text = "MISSION: Coin Rush (Collect all coins)"
		2:
			mission_status_label.text = "MISSION: Fuel Survivor (Refuel before empty)"

func _process(delta):
	# Update FPS
	fps_label.text = "FPS: " + str(Engine.get_frames_per_second())
	
	# Update Coins
	coins_label.text = "COINS: " + str(GameManager.coins) + " 🪙"
	
	# Find car if null
	if not is_instance_valid(car_node):
		var cars = get_tree().get_nodes_in_group("player_car")
		if cars.size() > 0:
			car_node = cars[0] as BaseCar
			
	# Update Car stats
	if is_instance_valid(car_node):
		var speed_kmh = round(car_node.linear_velocity.length() * 3.6)
		speed_label.text = str(speed_kmh) + " KMPH"
		gear_label.text = "Gear: " + ("A" if car_node.speed > 0 else "N") + str(car_node.gearshift)
		
	# Update Fuel and Damage bars
	fuel_bar.value = GameManager.car_fuel
	fuel_label.text = "FUEL: " + str(round(GameManager.car_fuel)) + "%"
	
	damage_bar.value = GameManager.car_damage
	damage_label.text = "DAMAGE: " + str(round(GameManager.car_damage)) + "%"
	
	# Mission conditions
	if GameManager.selected_mission_id == 1:
		var remaining_coins = get_tree().get_nodes_in_group("coins").size()
		if remaining_coins == 0:
			mission_status_label.text = "CONGRATULATIONS! Collected all coins!"
			mission_status_label.add_theme_color_override("font_color", Color.GREEN)
		else:
			mission_status_label.text = "Coins Remaining: " + str(remaining_coins)

# --- REFUEL STATION INTERACTION ---
func show_refuel_prompt(is_visible: bool):
	refuel_prompt_btn.visible = is_visible
	if not is_visible:
		refuel_menu.visible = false

func _on_refuel_prompt_pressed():
	refuel_menu.visible = true
	refuel_status_label.text = "Fuel Level: " + str(round(GameManager.car_fuel)) + "%"

func _on_buy_fuel_pressed(pct: int, cost: int):
	if GameManager.coins >= cost:
		if GameManager.car_fuel >= 100.0:
			refuel_status_label.text = "Tank is already full! 🔋"
			return
			
		GameManager.coins -= cost
		GameManager.car_fuel = clamp(GameManager.car_fuel + pct, 0.0, GameManager.car_max_fuel)
		GameManager.save_game_settings()
		refuel_status_label.text = "Successfully bought +" + str(pct) + "% Fuel! 🪙 -" + str(cost)
	else:
		refuel_status_label.text = "NOT ENOUGH COINS! Need " + str(cost) + " Coins 🪙"

func _on_close_refuel_pressed():
	refuel_menu.visible = false

# --- LIGHTS & HORN CONTROLS ---
func _on_lights_pressed():
	if is_instance_valid(car_node) and car_node.has_method("toggle_headlights"):
		car_node.toggle_headlights(not car_node.headlights_active)

func _on_horn_pressed():
	if is_instance_valid(car_node) and car_node.has_method("trigger_horn"):
		car_node.trigger_horn(true)

func _on_horn_released():
	if is_instance_valid(car_node) and car_node.has_method("trigger_horn"):
		car_node.trigger_horn(false)

# --- TOUCH CONTROLS SIMULATION ---
func _on_left_pressed():
	Input.action_press("left")

func _on_left_released():
	Input.action_release("left")

func _on_right_pressed():
	Input.action_press("right")

func _on_right_released():
	Input.action_release("right")

func _on_forward_pressed():
	Input.action_press("forward")

func _on_forward_released():
	Input.action_release("forward")

func _on_backward_pressed():
	Input.action_press("backward")

func _on_backward_released():
	Input.action_release("backward")

func _on_drift_pressed():
	Input.action_press("ui_select")

func _on_drift_released():
	Input.action_release("ui_select")

func _on_camera_pressed():
	var cameras = get_tree().get_nodes_in_group("game_camera")
	for cam in cameras:
		if cam.has_method("toggle_camera_mode"):
			cam.toggle_camera_mode()

func _on_reset_pressed():
	Input.action_press("ui_cancel")
	await get_tree().create_timer(0.1).timeout
	Input.action_release("ui_cancel")

# --- PAUSE MENU SYSTEM ---
func _on_pause_pressed():
	get_tree().paused = true
	pause_menu.visible = true

func _on_resume_pressed():
	get_tree().paused = false
	pause_menu.visible = false

func _on_home_pressed():
	get_tree().paused = false
	GameManager.transition_to_scene("res://Scenes/MainMenu.tscn")

func _on_volume_changed(value: float, bus: String):
	if bus == "Master":
		GameManager.volume_master = value
	elif bus == "Music":
		GameManager.volume_music = value
	elif bus == "SFX":
		GameManager.volume_sfx = value
	GameManager.apply_graphics_settings()
	GameManager.save_game_settings()
