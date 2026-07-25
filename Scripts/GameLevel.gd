extends Node3D

@onready var default_car = $car
@onready var car_resetter = %CarResetter

var coin_scene = preload("res://Scenes/Coin.tscn")
var fuel_station_scene = preload("res://Scenes/FuelStation.tscn")
var hud_scene = preload("res://Scenes/MobileHUD.tscn")
var car_scene = preload("res://cars/BaseCar.tscn")

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
	
	# 4. Procedurally Generate Forza-Level Map Features (Terrain, Roads, Houses, Grass, Physics Debris, and Coins!)
	_generate_horizon_map()
	
	# 5. Spawn Fuel Stations
	_spawn_fuel_stations()
	
	# 6. Setup multiplayer / local cars
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
	_apply_paint_recursive(car_node, color)

func _apply_paint_recursive(node: Node, color: Color):
	if node is MeshInstance3D:
		if not "wheel" in node.name.to_lower() and not "tire" in node.name.to_lower():
			var mat = StandardMaterial3D.new()
			mat.albedo_color = color
			mat.metallic = 0.8
			mat.roughness = 0.15
			node.material_override = mat
			
	for child in node.get_children():
		_apply_paint_recursive(child, color)

# --- PROCEDURAL MAP GENERATION (Terrain, Roads, Houses, Grass, Physics & Coins) ---
func _generate_horizon_map():
	# Setup Materials
	var grass_mat = StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.1, 0.65, 0.15) # bright lush green
	grass_mat.roughness = 0.9
	
	var road_mat = StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.15, 0.15, 0.18) # dark asphalt
	road_mat.roughness = 0.8
	
	var house_mat_base = StandardMaterial3D.new()
	house_mat_base.albedo_color = Color(0.85, 0.8, 0.75) # beige wall
	house_mat_base.roughness = 0.5
	
	var roof_mat = StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.8, 0.25, 0.2) # terracotta tile
	roof_mat.roughness = 0.6
	
	var prop_mat = StandardMaterial3D.new()
	prop_mat.albedo_color = Color(0.6, 0.4, 0.2) # wooden crates
	prop_mat.roughness = 0.7
	
	# A. Spawn Roads (Asphalt Tracks)
	var road_nodes = [
		{"pos": Vector3(0, 0.02, 15), "size": Vector3(8, 0.04, 80)},
		{"pos": Vector3(20, 0.02, -10), "size": Vector3(60, 0.04, 8)},
		{"pos": Vector3(-20, 0.02, -15), "size": Vector3(8, 0.04, 70)},
	]
	for r in road_nodes:
		var road = StaticBody3D.new()
		add_child(road)
		road.global_transform.origin = r["pos"]
		
		# Collision
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = r["size"]
		col.shape = shape
		road.add_child(col)
		
		# Mesh
		var mesh_inst = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		box_mesh.size = r["size"]
		box_mesh.material = road_mat
		mesh_inst.mesh = box_mesh
		road.add_child(mesh_inst)
	
	# B. Spawn Uneven Ground (Hills, stunt ramps, and jumps)
	var hill_nodes = [
		{"pos": Vector3(18, 0.5, 30), "size": Vector3(15, 3, 15), "col": Color(0.12, 0.55, 0.18)},
		{"pos": Vector3(-25, 1.5, 10), "size": Vector3(20, 5, 20), "col": Color(0.1, 0.5, 0.15)},
		{"pos": Vector3(40, 2.0, -35), "size": Vector3(25, 6, 25), "col": Color(0.12, 0.58, 0.18)},
		# Ramps for stunts!
		{"pos": Vector3(5, 0.8, -5), "size": Vector3(6, 1.6, 12), "rot": Vector3(15, 0, 0), "col": Color(0.3, 0.3, 0.3)},
		{"pos": Vector3(-12, 1.2, 25), "size": Vector3(5, 2.4, 10), "rot": Vector3(-20, 0, 0), "col": Color(0.35, 0.35, 0.35)},
	]
	for h in hill_nodes:
		var hill = StaticBody3D.new()
		add_child(hill)
		hill.global_transform.origin = h["pos"]
		if h.has("rot"):
			hill.rotation_degrees = h["rot"]
			
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = h["size"]
		col.shape = shape
		hill.add_child(col)
		
		var mesh_inst = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		box_mesh.size = h["size"]
		var m = StandardMaterial3D.new()
		m.albedo_color = h["col"]
		m.roughness = 0.9
		box_mesh.material = m
		mesh_inst.mesh = box_mesh
		hill.add_child(mesh_inst)

	# C. Spawn Low-Poly Buildings (Houses)
	var house_positions = [
		Vector3(-8, 0, -22),
		Vector3(-32, 0, -10),
		Vector3(35, 0, 5),
		Vector3(25, 0, 28),
		Vector3(-18, 0, 42)
	]
	for i in range(house_positions.size()):
		var p = house_positions[i]
		var house = StaticBody3D.new()
		add_child(house)
		house.global_transform.origin = p + Vector3(0, 1.5, 0)
		
		# Base wall collision & mesh
		var col_base = CollisionShape3D.new()
		var shape_base = BoxShape3D.new()
		shape_base.size = Vector3(5, 3, 5)
		col_base.shape = shape_base
		house.add_child(col_base)
		
		var mesh_base = MeshInstance3D.new()
		var box_base = BoxMesh.new()
		box_base.size = Vector3(5, 3, 5)
		box_base.material = house_mat_base
		mesh_base.mesh = box_base
		house.add_child(mesh_base)
		
		# Roof mesh (Prism representation sitting on top of base)
		var roof = MeshInstance3D.new()
		var prism = PrismMesh.new()
		prism.size = Vector3(6, 2, 6)
		prism.material = roof_mat
		roof.mesh = prism
		roof.transform.origin = Vector3(0, 2.5, 0) # sit on top of base
		house.add_child(roof)

	# D. Spawn Abundant Gold Coins Scattered All Over
	var coin_coords = [
		# Scattered along the roads
		Vector3(0, 0.8, 5), Vector3(0, 0.8, -5), Vector3(0, 0.8, -15),
		Vector3(10, 0.8, -10), Vector3(20, 0.8, -10), Vector3(30, 0.8, -10),
		Vector3(-20, 0.8, 0), Vector3(-20, 0.8, 10), Vector3(-20, 0.8, 20),
		# On top of the jumps/ramps
		Vector3(5, 2.5, -5), Vector3(-12, 3.2, 25),
		# Surrounding houses
		Vector3(-8, 0.8, -16), Vector3(-32, 0.8, -4), Vector3(35, 0.8, 11),
		# High-altitude coins on hills
		Vector3(18, 3.5, 30), Vector3(-25, 5.5, 10), Vector3(40, 6.5, -35),
		# Extra exploration rings
		Vector3(15, 0.8, 20), Vector3(20, 0.8, 20), Vector3(25, 0.8, 20),
		Vector3(-5, 0.8, 35), Vector3(-10, 0.8, 35), Vector3(-15, 0.8, 35)
	]
	for pos in coin_coords:
		var coin = coin_scene.instantiate()
		add_child(coin)
		coin.global_transform.origin = pos

	# E. Spawn Lush 3D Grass Blades (Procedural Green cylinders)
	for i in range(150):
		var rx = randf_range(-60, 60)
		var rz = randf_range(-60, 60)
		# Avoid spawning grass on the middle of roads
		if abs(rx) < 5 and abs(rz) < 45:
			continue
			
		var grass = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.05
		cyl.bottom_radius = 0.15
		cyl.height = 1.2
		
		# Vibrant green grass color
		var m = StandardMaterial3D.new()
		m.albedo_color = Color(0.1, randf_range(0.5, 0.85), 0.15)
		m.roughness = 1.0
		cyl.material = m
		
		grass.mesh = cyl
		add_child(grass)
		# Place on ground slightly sunken so bottom is hidden
		grass.global_transform.origin = Vector3(rx, 0.5, rz)

	# F. Spawn Highly Interactive Physics Debris (RigidBody wooden crates and balls)
	var prop_mesh = BoxMesh.new()
	prop_mesh.size = Vector3(1.5, 1.5, 1.5)
	prop_mesh.material = prop_mat
	
	var beach_ball_mesh = SphereMesh.new()
	beach_ball_mesh.radius = 1.2
	beach_ball_mesh.height = 2.4
	var ball_mat = StandardMaterial3D.new()
	ball_mat.albedo_color = Color(1.0, 0.2, 0.1) # vibrant sports red
	ball_mat.roughness = 0.2
	beach_ball_mesh.material = ball_mat
	
	var crate_positions = [
		Vector3(0, 1.0, 20),
		Vector3(1, 1.0, 22),
		Vector3(-1, 1.0, 22),
		Vector3(0, 2.5, 21), # Stacked crate!
		Vector3(25, 1.0, -10),
		Vector3(-20, 1.0, 5),
		# Beach balls
		Vector3(-8, 1.5, 15),
		Vector3(14, 1.5, -25)
	]
	
	for i in range(crate_positions.size()):
		var p = crate_positions[i]
		var is_ball = (i >= 6) # last two are beach balls
		
		var prop = RigidBody3D.new()
		prop.mass = 4.0 if is_ball else 15.0 # lighter balls fly off further!
		prop.contact_monitor = true
		prop.max_contacts_reported = 2
		add_child(prop)
		prop.global_transform.origin = p
		
		var col = CollisionShape3D.new()
		if is_ball:
			var s = SphereShape3D.new()
			s.radius = 1.2
			col.shape = s
		else:
			var s = BoxShape3D.new()
			s.size = Vector3(1.5, 1.5, 1.5)
			col.shape = s
		prop.add_child(col)
		
		var mesh_inst = MeshInstance3D.new()
		mesh_inst.mesh = beach_ball_mesh if is_ball else prop_mesh
		prop.add_child(mesh_inst)

func _spawn_fuel_stations():
	var station_positions = [
		Vector3(15, 0, 5), 
		Vector3(-15, 0, -15)
	]
	
	for pos in station_positions:
		var fs = fuel_station_scene.instantiate()
		add_child(fs)
		fs.global_transform.origin = pos

func setup_multiplayer_game():
	if is_instance_valid(default_car):
		default_car.queue_free()
		
	var my_id = multiplayer.get_unique_id()
	var _my_car = spawn_player_car(my_id)
	
	if GameManager.is_host:
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		
		for id in multiplayer.get_peers():
			spawn_player_car(id)

func _on_peer_connected(id: int):
	var _peer_car = spawn_player_car(id)

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
	
	var spawn_offset = Vector3(float(peer_id % 3) * 3.0, 0.5, float(peer_id % 2) * 3.0)
	new_car.global_transform.origin = Vector3(5, 0.5, 4) + spawn_offset
	
	if has_custom_paint:
		_apply_car_paint(new_car, active_paint_color)
		
	return new_car
