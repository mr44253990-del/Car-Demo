extends Node3D

@onready var default_car = $car
@onready var car_resetter = %CarResetter

var coin_scene = preload("res://Scenes/Coin.tscn")
var fuel_station_scene = preload("res://Scenes/FuelStation.tscn")
var hud_scene = preload("res://Scenes/MobileHUD.tscn")
var car_scene = preload("res://cars/BaseCar.tscn") # For multiplayer spawning

var active_paint_color: Color = Color.WHITE
var has_custom_paint: bool = false

func _ready():
	# Ensure the game is fully unpaused on level load
	get_tree().paused = false
	
	# 1. Hide legacy HUD if present
	if has_node("Hud"):
		get_node("Hud").visible = false
		
	# 2. Instance Mobile HUD overlay
	var hud_inst = hud_scene.instantiate()
	add_child(hud_inst)
	
	# 3. Read custom car paint color
	_load_custom_paint()
	
	# 4. Setup level elements (Coins & Fuel Stations)
	_spawn_coins()
	_spawn_fuel_stations()
	
	# 5. Setup multiplayer / local cars
	if GameManager.is_multiplayer:
		setup_multiplayer_game()
	else:
		# Singleplayer: make sure car is in group and apply paint
		if is_instance_valid(default_car):
			default_car.add_to_group("player_car")
			if has_custom_paint:
				_apply_car_paint(default_car, active_paint_color)

func _load_custom_paint():
	if FileAccess.file_exists("user://car_paint.cfg"):
		var file = FileAccess.open("user://car_paint.cfg", FileAccess.READ)
		if file:
			var paint_data = file.get_var()
			if paint_data is Dictionary and paint_data.has("car_paint"):
				var color_name = paint_data["car_paint"]
				has_custom_paint = true
				match color_name:
					"red": active_paint_color = Color(0.9, 0.1, 0.1)
					"blue": active_paint_color = Color(0.1, 0.4, 0.9)
					"green": active_paint_color = Color(0.1, 0.8, 0.2)
					"gold": active_paint_color = Color(1.0, 0.84, 0.0)
			file.close()

func _apply_car_paint(car_node: Node, color: Color):
	# Recursively search for mesh instances to apply custom material override
	_apply_paint_recursive(car_node, color)

func _apply_paint_recursive(node: Node, color: Color):
	if node is MeshInstance3D:
		# Don't paint wheels or tires
		if not "wheel" in node.name.to_lower() and not "tire" in node.name.to_lower():
			var mat = StandardMaterial3D.new()
			mat.albedo_color = color
			mat.metallic = 0.8
			mat.roughness = 0.15
			node.material_override = mat
			
	for child in node.get_children():
		_apply_paint_recursive(child, color)

func _spawn_coins():
	var coin_positions = [
		Vector3(0, 0.5, 10),
		Vector3(0, 0.5, 18),
		Vector3(0, 0.5, 26),
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
		Vector3(12, 0, 5), # Near starting point
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
	var _my_car = spawn_player_car(my_id)
	
	# If host, listen to incoming peers to spawn their cars
	if GameManager.is_host:
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		
		# Spawn cars for already connected peers
		for id in multiplayer.get_peers():
			spawn_player_car(id)

func _on_peer_connected(id: int):
	spawn_player_car(id)

func _on_peer_disconnected(id: int):
	var peer_car = get_node_or_null(str(id))
	if is_instance_valid(peer_car):
		peer_car.queue_free()

func spawn_player_car(peer_id: int) -> BaseCar:
	var new_car = car_scene.instantiate()
	new_car.name = str(peer_id)
	add_child(new_car)
	
	new_car.set_multiplayer_authority(peer_id)
	new_car.add_to_group("player_car")
	
	# Calculate offset spawn
	var spawn_offset = Vector3(float(peer_id % 3) * 3.0, 0.5, float(peer_id % 2) * 3.0)
	new_car.global_transform.origin = Vector3(5, 0.5, 4) + spawn_offset
	
	# Apply custom color to this spawned car
	if has_custom_paint:
		_apply_car_paint(new_car, active_paint_color)
		
	return new_car
