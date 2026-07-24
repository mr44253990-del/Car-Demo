extends Node3D

@onready var default_car = $car
@onready var car_resetter = %CarResetter

var coin_scene = preload("res://Scenes/Coin.tscn")
var fuel_station_scene = preload("res://Scenes/FuelStation.tscn")
var hud_scene = preload("res://Scenes/MobileHUD.tscn")
var car_scene = preload("res://cars/BaseCar.tscn") # For multiplayer spawning

func _ready():
	# Hide legacy HUD if present
	if has_node("Hud"):
		get_node("Hud").visible = false
		
	# 1. Instance Mobile HUD overlay
	var hud_inst = hud_scene.instantiate()
	add_child(hud_inst)
	
	# 2. Setup level elements
	_spawn_coins()
	_spawn_fuel_stations()
	
	# 3. Setup multiplayer if active
	if GameManager.is_multiplayer:
		setup_multiplayer_game()
	else:
		# Singleplayer: make sure car is in group
		if is_instance_valid(default_car):
			default_car.add_to_group("player_car")

func _spawn_coins():
	# Define coordinate locations to scatter coins
	var coin_positions = [
		Vector3(0, 0.5, 10),
		Vector3(0, 0.5, 15),
		Vector3(0, 0.5, 20),
		Vector3(15, 0.5, -10),
		Vector3(15, 0.5, -5),
		Vector3(25, 1.0, 5),
		Vector3(25, 1.0, 10),
		Vector3(-10, 0.5, -20),
		Vector3(-20, 0.5, -25),
		Vector3(32, 1.5, -21),
		Vector3(40, 1.5, -21),
		Vector3(48, 1.5, -21),
		Vector3(32, 1.5, -29),
		Vector3(40, 1.5, -29),
		Vector3(48, 1.5, -29),
	]
	
	for pos in coin_positions:
		var coin = coin_scene.instantiate()
		add_child(coin)
		coin.global_transform.origin = pos

func _spawn_fuel_stations():
	var station_positions = [
		Vector3(10, 0, 5), # Near starting point
		Vector3(-15, 0, -15) # Far side of the level
	]
	
	for pos in station_positions:
		var fs = fuel_station_scene.instantiate()
		add_child(fs)
		fs.global_transform.origin = pos

func setup_multiplayer_game():
	# Hide / remove default editor car
	if is_instance_valid(default_car):
		default_car.queue_free()
		
	# Spawn local player car
	var my_id = multiplayer.get_unique_id()
	spawn_player_car(my_id)
	
	# If host, listen to incoming peers to spawn their cars
	if GameManager.is_host:
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		
		# Spawn cars for already connected peers
		for id in multiplayer.get_peers():
			spawn_player_car(id)

func _on_peer_connected(id: int):
	# Spawn car for new client
	spawn_player_car(id)

func _on_peer_disconnected(id: int):
	# Remove client car
	var peer_car = get_node_or_null(str(id))
	if is_instance_valid(peer_car):
		peer_car.queue_free()

func spawn_player_car(peer_id: int):
	var new_car = car_scene.instantiate()
	new_car.name = str(peer_id)
	add_child(new_car)
	
	# Set authority so inputs are handled correctly
	new_car.set_multiplayer_authority(peer_id)
	new_car.add_to_group("player_car")
	
	# Calculate different spawn positions to avoid overlap
	var spawn_offset = Vector3(float(peer_id % 3) * 3.0, 0.5, float(peer_id % 2) * 3.0)
	new_car.global_transform.origin = Vector3(5, 0.5, 4) + spawn_offset
	
	# If this is the local player, hook camera up
	if peer_id == multiplayer.get_unique_id():
		# The Camera Follow works as child of car body, let's verify
		# It's inside look node in BaseCar.tscn
		print("Spawned local player car with ID: ", peer_id)
