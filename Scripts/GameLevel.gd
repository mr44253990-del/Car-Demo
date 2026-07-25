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
	get_tree().paused = false
	
	# 1. Hide legacy HUD if present
	if has_node("Hud"):
		get_node("Hud").visible = false
		
	# 2. Instance Mobile HUD overlay
	var hud_inst = hud_scene.instantiate()
	add_child(hud_inst)
	
	# 3. Read custom car paint color
	_load_custom_paint()
	
	# 4. Generate Huge City & Offroad Horizon Map (Huge terrain, city layout, skyscrapers, coins, and debris)
	_generate_horizon_map()
	
	# 5. Spawn Fuel Stations
	_spawn_fuel_stations()
	
	# 6. Setup multiplayer / local cars
	if GameManager.is_multiplayer:
		setup_multiplayer_game()
	else:
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

# --- GIANT PROCEDURAL HORIZON FESTIVAL MAP GENERATION ---
func _generate_horizon_map():
	# Setup Materials
	var road_mat = StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.12, 0.12, 0.15) # dark asphalt
	road_mat.roughness = 0.85
	
	var dirt_mat = StandardMaterial3D.new()
	dirt_mat.albedo_color = Color(0.35, 0.25, 0.15) # earthy dirt color for hills
	dirt_mat.roughness = 0.95
	
	var concrete_mat = StandardMaterial3D.new()
	concrete_mat.albedo_color = Color(0.7, 0.7, 0.72) # city floor
	concrete_mat.roughness = 0.6
	
	# A. Spawn Huge Road Networks (High-contrast racetrack lanes)
	var roads = [
		{"pos": Vector3(0, 0.02, 0), "size": Vector3(10, 0.04, 180)}, # Central Avenue
		{"pos": Vector3(40, 0.02, 30), "size": Vector3(120, 0.04, 10)}, # Fast Ring Road South
		{"pos": Vector3(-40, 0.02, -30), "size": Vector3(120, 0.04, 10)}, # Fast Ring Road North
		{"pos": Vector3(60, 0.02, 0), "size": Vector3(10, 0.04, 120)}, # East Link
		{"pos": Vector3(-60, 0.02, 0), "size": Vector3(10, 0.04, 120)}, # West Link
	]
	for r in roads:
		var road = StaticBody3D.new()
		add_child(road)
		road.global_transform.origin = r["pos"]
		
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = r["size"]
		col.shape = shape
		road.add_child(col)
		
		var mesh_inst = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		box_mesh.size = r["size"]
		box_mesh.material = road_mat
		mesh_inst.mesh = box_mesh
		road.add_child(mesh_inst)

	# B. Spawn Uneven Mountain Range & Jumping Jumps
	var hills = [
		{"pos": Vector3(30, 2.0, 50), "size": Vector3(25, 6, 25), "col": Color(0.12, 0.5, 0.16)},
		{"pos": Vector3(-35, 3.5, 55), "size": Vector3(35, 9, 35), "col": Color(0.1, 0.45, 0.12)},
		{"pos": Vector3(70, 4.5, -45), "size": Vector3(40, 12, 40), "col": Color(0.3, 0.2, 0.1)}, # Muddy Hill
		{"pos": Vector3(-70, 5.0, -45), "size": Vector3(35, 14, 35), "col": Color(0.08, 0.4, 0.1)}, # Forest Ridge
		# Epic stunt jumps!
		{"pos": Vector3(0, 1.2, 45), "size": Vector3(8, 2.4, 16), "rot": Vector3(22, 0, 0), "col": Color(0.4, 0.4, 0.4)},
		{"pos": Vector3(0, 1.5, -45), "size": Vector3(8, 3.0, 16), "rot": Vector3(-22, 0, 0), "col": Color(0.4, 0.4, 0.4)},
		{"pos": Vector3(45, 1.0, 0), "size": Vector3(16, 2.0, 8), "rot": Vector3(0, 0, 20), "col": Color(0.45, 0.45, 0.45)},
	]
	for h in hills:
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
		m.roughness = 0.95
		box_mesh.material = m
		mesh_inst.mesh = box_mesh
		hill.add_child(mesh_inst)

	# C. Spawn Colossal Skyscrapers / Central City Towers
	var towers = [
		{"pos": Vector3(80, 15, 0), "size": Vector3(12, 30, 12), "col": Color(0.1, 0.1, 0.15)},
		{"pos": Vector3(-80, 20, 0), "size": Vector3(15, 40, 15), "col": Color(0.12, 0.12, 0.18)},
		{"pos": Vector3(0, 10, 80), "size": Vector3(10, 20, 10), "col": Color(0.08, 0.15, 0.2)}
	]
	for t in towers:
		var tower = StaticBody3D.new()
		add_child(tower)
		tower.global_transform.origin = t["pos"]
		
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = t["size"]
		col.shape = shape
		tower.add_child(col)
		
		var mesh_inst = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		box_mesh.size = t["size"]
		var m = StandardMaterial3D.new()
		m.albedo_color = t["col"]
		m.metallic = 0.9
		m.roughness = 0.1
		m.emission_enabled = true
		m.emission = Color(0, 0.6, 1, 0.15) # neon city windows effect
		box_mesh.material = m
		mesh_inst.mesh = box_mesh
		tower.add_child(mesh_inst)

	# D. Spawn 18+ Colorful Low-Poly Houses (Festival Town Village)
	var house_colors = [
		Color(0.9, 0.25, 0.25), # crimson red
		Color(0.2, 0.5, 0.9), # vibrant blue
		Color(1.0, 0.7, 0.1), # deep orange
		Color(0.15, 0.8, 0.4), # bright green
		Color(0.8, 0.15, 0.8), # hot violet
	]
	var house_positions = [
		# Center Village
		Vector3(-15, 0, -20), Vector3(-15, 0, -10), Vector3(15, 0, -20), Vector3(15, 0, -10),
		# East Side Suburb
		Vector3(45, 0, 15), Vector3(45, 0, 45), Vector3(35, 0, 15), Vector3(35, 0, 45),
		# West Side Lakeside
		Vector3(-45, 0, 15), Vector3(-45, 0, 45), Vector3(-35, 0, 15), Vector3(-35, 0, 45),
		# Northern Highlands
		Vector3(-15, 0, -50), Vector3(15, 0, -50), Vector3(-30, 0, -60), Vector3(30, 0, -60),
		Vector3(0, 0, -75), Vector3(-45, 0, -75)
	]
	
	for i in range(house_positions.size()):
		var p = house_positions[i]
		var house = StaticBody3D.new()
		add_child(house)
		house.global_transform.origin = p + Vector3(0, 2.0, 0)
		
		# Base wall
		var col_base = CollisionShape3D.new()
		var shape_base = BoxShape3D.new()
		shape_base.size = Vector3(6, 4, 6)
		col_base.shape = shape_base
		house.add_child(col_base)
		
		var mesh_base = MeshInstance3D.new()
		var box_base = BoxMesh.new()
		box_base.size = Vector3(6, 4, 6)
		var base_mat = StandardMaterial3D.new()
		base_mat.albedo_color = Color(0.9, 0.9, 0.92) # pristine white plaster
		base_mat.roughness = 0.65
		box_base.material = base_mat
		mesh_base.mesh = box_base
		house.add_child(mesh_base)
		
		# Roof
		var roof = MeshInstance3D.new()
		var prism = PrismMesh.new()
		prism.size = Vector3(7.2, 2.8, 7.2)
		var roof_mat = StandardMaterial3D.new()
		roof_mat.albedo_color = house_colors[i % house_colors.size()]
		roof_mat.roughness = 0.5
		prism.material = roof_mat
		roof.mesh = prism
		roof.transform.origin = Vector3(0, 3.4, 0)
		house.add_child(roof)

	# E. Spawn Over 100+ Scattered Gold Coins (Dense patterns!)
	# Golden coins along the Central Avenue
	for z in range(-80, 80, 10):
		if z != 5: # leave spawn clear
			var coin = coin_scene.instantiate()
			add_child(coin)
			coin.global_transform.origin = Vector3(0, 0.8, z)
			
	# Coins along North/South Ring Roads
	for x in range(-50, 50, 8):
		var coin_n = coin_scene.instantiate()
		add_child(coin_n)
		coin_n.global_transform.origin = Vector3(x, 0.8, -30)
		
		var coin_s = coin_scene.instantiate()
		add_child(coin_s)
		coin_s.global_transform.origin = Vector3(x, 0.8, 30)

	# Circular rings around the Central skyscrapers
	for angle in range(0, 360, 45):
		var rad = deg_to_rad(angle)
		var pos_e = Vector3(80 + cos(rad)*15.0, 0.8, sin(rad)*15.0)
		var coin_e = coin_scene.instantiate()
		add_child(coin_e)
		coin_e.global_transform.origin = pos_e
		
		var pos_w = Vector3(-80 + cos(rad)*15.0, 0.8, sin(rad)*15.0)
		var coin_w = coin_scene.instantiate()
		add_child(coin_w)
		coin_w.global_transform.origin = pos_w

	# F. Spawn Dense Beautiful 3D Grass Fields
	for i in range(250):
		var rx = randf_range(-90, 90)
		var rz = randf_range(-90, 90)
		# Skip roads
		if abs(rx) < 7 and abs(rz) < 95:
			continue
		if abs(rz) < 7 and abs(rx) < 95:
			continue
			
		var grass = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.04
		cyl.bottom_radius = 0.12
		cyl.height = 1.3
		
		var m = StandardMaterial3D.new()
		m.albedo_color = Color(0.12, randf_range(0.55, 0.9), 0.18)
		m.roughness = 1.0
		cyl.material = m
		
		grass.mesh = cyl
		add_child(grass)
		grass.global_transform.origin = Vector3(rx, 0.6, rz)

	# G. Spawn Highly Dynamic Physics Props (Bouncy balls and Crates)
	var prop_mat = StandardMaterial3D.new()
	prop_mat.albedo_color = Color(0.65, 0.45, 0.25)
	prop_mat.roughness = 0.75
	var prop_mesh = BoxMesh.new()
	prop_mesh.size = Vector3(1.6, 1.6, 1.6)
	prop_mesh.material = prop_mat
	
	var beach_ball_mesh = SphereMesh.new()
	beach_ball_mesh.radius = 1.4
	beach_ball_mesh.height = 2.8
	var ball_mat = StandardMaterial3D.new()
	ball_mat.albedo_color = Color(0.95, 0.15, 0.4) # Neon horizon pink ball!
	ball_mat.roughness = 0.25
	beach_ball_mesh.material = ball_mat
	
	var crates = [
		Vector3(0, 1.0, 30), Vector3(1, 1.0, 32), Vector3(-1, 1.0, 32), Vector3(0, 2.6, 31),
		Vector3(30, 1.0, -10), Vector3(32, 1.0, -10), Vector3(31, 2.6, -10),
		Vector3(-30, 1.0, 10), Vector3(-32, 1.0, 10), Vector3(-31, 2.6, 10),
		# Big beach balls
		Vector3(-10, 1.5, 18), Vector3(14, 1.5, -28), Vector3(50, 1.5, -5)
	]
	
	for i in range(crates.size()):
		var p = crates[i]
		var is_ball = (i >= 10)
		
		var prop = RigidBody3D.new()
		prop.mass = 5.0 if is_ball else 20.0
		prop.contact_monitor = true
		prop.max_contacts_reported = 2
		add_child(prop)
		prop.global_transform.origin = p
		
		var col = CollisionShape3D.new()
		if is_ball:
			var s = SphereShape3D.new()
			s.radius = 1.4
			col.shape = s
		else:
			var s = BoxShape3D.new()
			s.size = Vector3(1.6, 1.6, 1.6)
			col.shape = s
		prop.add_child(col)
		
		var mesh_inst = MeshInstance3D.new()
		mesh_inst.mesh = beach_ball_mesh if is_ball else prop_mesh
		prop.add_child(mesh_inst)

func _spawn_fuel_stations():
	var station_positions = [
		Vector3(18, 0, 8), 
		Vector3(-18, 0, -18)
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
