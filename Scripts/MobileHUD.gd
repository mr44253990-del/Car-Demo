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

var car_node: BaseCar = null

func _ready():
	pause_menu.visible = false
	
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
	
	# Find car if null (in multiplayer or spawn delay)
	if not is_instance_valid(car_node):
		var cars = get_tree().get_nodes_in_group("player_car")
		if cars.size() > 0:
			car_node = cars[0] as BaseCar
			
	# Update Car stats
	if is_instance_valid(car_node):
		var speed_kmh = round(car_node.linear_velocity.length() * 3.6)
		speed_label.text = str(speed_kmh) + " KMPH"
		gear_label.text = "Gear: " + str(car_node.gearshift)
		
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

func _on_gear_pressed():
	Input.action_press("gear")
	await get_tree().create_timer(0.1).timeout
	Input.action_release("gear")

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
