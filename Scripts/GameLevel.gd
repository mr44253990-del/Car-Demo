extends Node3D

@onready var default_car = $car
@onready var car_resetter = %CarResetter

var coin_scene = preload("res://Scenes/Coin.tscn")
var fuel_station_scene = preload("res://Scenes/FuelStation.tscn")
var hud_scene = preload("res://Scenes/MobileHUD.tscn")
var car_scene = preload("res://cars/BaseCar.tscn")

var active_paint_color: Color = Color.WHITE
var has_custom_paint: bool = false

# --- Dynamic Day-Night & Weather Cycle ---
var time_of_day: float = 8.0
var day_speed: float = 0.15
var directional_light: DirectionalLight3D = null
var world_environment: WorldEnvironment = null

var current_weather: String = "sunny"
var weather_timer: float = 0.0
var rain_particles: CPUParticles3D = null

# --- AI Pedestrians & Traffic ---
var ai_citizens: Array = []
var ai_traffic_cars: Array = []
var houses_nodes: Array = []
var light_poles_nodes: Array = []

# --- Speed Trap & Stunt Rings ---
var speed_trap_light: PointLight3D = null
var speed_trap_active: bool = true

func _ready():
	get_tree().paused = false
	
	directional_light = get_node_or_null("DirectionalLight3D")
	world_environment = get_node_or_null("WorldEnvironment")
	
	if has_node("Hud"):
		get_node("Hud").visible = false
		
	var hud_inst = hud_scene.instantiate()
	add_child(hud_inst)
	
	_load_custom_paint()
	
	# Procedurally Generate Giant Map
	_generate_horizon_map()
	_spawn_fuel_stations()
	_spawn_speed_trap()
	_spawn_aerial_stunt_rings()
	
	# Setup Rain Particles
	_setup_rain_system()
	
	# Spawn AI Pedestrians & Traffic
	_spawn_ai_citizens()
	_spawn_ai_traffic()
	
	# Setup Local Player Car
	if GameManager.is_multiplayer:
		setup_multiplayer_game()
	else:
		if is_instance_valid(default_car):
			default_car.add_to_group("player_car")
			
			# Apply persistent tuning upgrades
			_apply_performance_upgrades(default_car)
			
			if has_custom_paint:
				_apply_car_paint(default_car, active_paint_color)
				
			# Apply persistent Underglow
			_apply_car_underglow(default_car, GameManager.underglow_color)
			
			_attach_rain_to_car(default_car)

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

# --- APPLY PERFORMANCE UPGRADES ---
func _apply_performance_upgrades(car_node: BaseCar):
	# Level 1-5 Engine Upgrades (up to +45% acceleration)
	var speed_boost = 1.0 + (float(GameManager.upgrade_engine - 1) * 0.11)
	car_node.engine_force_value = int(car_node.engine_force_value * speed_boost)
	
	# Level 1-5 Handling Upgrades (up to +28% steering agility)
	var turn_boost = 1.0 + (float(GameManager.upgrade_handling - 1) * 0.07)
	car_node.STEER_SPEED = car_node.STEER_SPEED * turn_boost
	
	print("Tuning applied! Max Engine force: ", car_node.engine_force_value, " Steer Speed: ", car_node.STEER_SPEED)

# --- APPLY NEON UNDERGLOW TUBE ---
func _apply_car_underglow(car_node: Node, color_name: String):
	var glow = OmniLight3D.new()
	glow.name = "UnderglowLight"
	car_node.add_child(glow)
	glow.transform.origin = Vector3(0, -0.3, 0) # place underneath
	glow.light_energy = 8.0
	glow.omni_range = 3.5
	
	var color = Color(0, 0.85, 1) # cyan default
	match color_name:
		"cyan": color = Color(0, 0.85, 1)
		"pink": color = Color(1, 0, 0.45) # neon pink
		"gold": color = Color(1, 0.85, 0.2)
		"red": color = Color(1, 0.15, 0.15)
		
	glow.light_color = color

# --- PROCEDURAL MAP GENERATION ---
func _generate_horizon_map():
	var road_mat = StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.12, 0.12, 0.15)
	road_mat.roughness = 0.85
	
	var house_colors = [
		Color(0.95, 0.2, 0.3),
		Color(0.2, 0.5, 0.95),
		Color(1.0, 0.65, 0.0),
		Color(0.1, 0.85, 0.3),
		Color(0.8, 0.1, 0.8)
	]
	
	# Spawn Roads
	var roads = [
		{"pos": Vector3(0, 0.02, 0), "size": Vector3(10, 0.04, 180)},
		{"pos": Vector3(40, 0.02, 30), "size": Vector3(120, 0.04, 10)},
		{"pos": Vector3(-40, 0.02, -30), "size": Vector3(120, 0.04, 10)},
		{"pos": Vector3(60, 0.02, 0), "size": Vector3(10, 0.04, 120)},
		{"pos": Vector3(-60, 0.02, 0), "size": Vector3(10, 0.04, 120)},
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

	# Spawn Uneven Hills & Jumps
	var hills = [
		{"pos": Vector3(30, 2.0, 50), "size": Vector3(25, 6, 25), "col": Color(0.12, 0.5, 0.16)},
		{"pos": Vector3(-35, 3.5, 55), "size": Vector3(35, 9, 35), "col": Color(0.1, 0.45, 0.12)},
		{"pos": Vector3(70, 4.5, -45), "size": Vector3(40, 12, 40), "col": Color(0.3, 0.2, 0.1)},
		{"pos": Vector3(-70, 5.0, -45), "size": Vector3(35, 14, 35), "col": Color(0.08, 0.4, 0.1)},
		# Ramps
		{"pos": Vector3(0, 1.2, 45), "size": Vector3(8, 2.4, 16), "rot": Vector3(22, 0, 0), "col": Color(0.4, 0.4, 0.4)},
		{"pos": Vector3(0, 1.5, -45), "size": Vector3(8, 3.0, 16), "rot": Vector3(-22, 0, 0), "col": Color(0.4, 0.4, 0.4)},
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

	# Spawn Central Skyscrapers
	var towers = [
		{"pos": Vector3(80, 15, 0), "size": Vector3(12, 30, 12), "col": Color(0.1, 0.1, 0.15)},
		{"pos": Vector3(-80, 20, 0), "size": Vector3(15, 40, 15), "col": Color(0.12, 0.12, 0.18)},
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
		m.emission = Color(0, 0.6, 1, 0.15)
		box_mesh.material = m
		mesh_inst.mesh = box_mesh
		tower.add_child(mesh_inst)

	# Spawn 18+ Houses
	var house_positions = [
		Vector3(-15, 0, -20), Vector3(-15, 0, -10), Vector3(15, 0, -20), Vector3(15, 0, -10),
		Vector3(45, 0, 15), Vector3(45, 0, 45), Vector3(35, 0, 15), Vector3(35, 0, 45),
		Vector3(-45, 0, 15), Vector3(-45, 0, 45), Vector3(-35, 0, 15), Vector3(-35, 0, 45),
		Vector3(-15, 0, -50), Vector3(15, 0, -50), Vector3(-30, 0, -60), Vector3(30, 0, -60),
		Vector3(0, 0, -75), Vector3(-45, 0, -75)
	]
	for i in range(house_positions.size()):
		var p = house_positions[i]
		var house = StaticBody3D.new()
		add_child(house)
		house.global_transform.origin = p + Vector3(0, 2.0, 0)
		houses_nodes.append(house)
		
		var col_base = CollisionShape3D.new()
		var shape_base = BoxShape3D.new()
		shape_base.size = Vector3(6, 4, 6)
		col_base.shape = shape_base
		house.add_child(col_base)
		
		var mesh_base = MeshInstance3D.new()
		var box_base = BoxMesh.new()
		box_base.size = Vector3(6, 4, 6)
		var base_mat = StandardMaterial3D.new()
		base_mat.albedo_color = Color(0.9, 0.9, 0.92)
		base_mat.roughness = 0.65
		box_base.material = base_mat
		mesh_base.mesh = box_base
		house.add_child(mesh_base)
		
		# Windows
		var window_mesh = MeshInstance3D.new()
		var w_mesh = BoxMesh.new()
		w_mesh.size = Vector3(6.05, 1.2, 3.2)
		var w_mat = StandardMaterial3D.new()
		w_mat.albedo_color = Color(0.2, 0.2, 0.2)
		w_mat.roughness = 0.1
		w_mesh.material = w_mat
		window_mesh.mesh = w_mesh
		house.add_child(window_mesh)
		
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

	# Spawn Streetlights
	var light_positions = [
		Vector3(12, 0, 12), Vector3(-12, 0, -12),
		Vector3(12, 0, -35), Vector3(-12, 0, 35)
	]
	for lp in light_positions:
		var pole = StaticBody3D.new()
		add_child(pole)
		pole.global_transform.origin = lp
		light_poles_nodes.append(pole)
		
		var mesh = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.15
		cyl.bottom_radius = 0.15
		cyl.height = 6.0
		mesh.mesh = cyl
		mesh.transform.origin = Vector3(0, 3.0, 0)
		pole.add_child(mesh)
		
		var bulb = OmniLight3D.new()
		bulb.light_color = Color(1.0, 0.95, 0.7)
		bulb.light_energy = 5.0
		bulb.omni_range = 15.0
		bulb.visible = false
		bulb.transform.origin = Vector3(0, 5.8, 0)
		pole.add_child(bulb)

	# Spawn 100+ Coins
	for z in range(-80, 80, 8):
		if z != 5:
			var coin = coin_scene.instantiate()
			add_child(coin)
			coin.global_transform.origin = Vector3(0, 0.8, z)
			
	for x in range(-50, 50, 8):
		var coin_n = coin_scene.instantiate()
		add_child(coin_n)
		coin_n.global_transform.origin = Vector3(x, 0.8, -30)
		
		var coin_s = coin_scene.instantiate()
		add_child(coin_s)
		coin_s.global_transform.origin = Vector3(x, 0.8, 30)

	# Spawn Grass
	for i in range(250):
		var rx = randf_range(-90, 90)
		var rz = randf_range(-90, 90)
		if abs(rx) < 7 and abs(rz) < 95: continue
		if abs(rz) < 7 and abs(rx) < 95: continue
			
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

	# Spawn Physics Objects (Beach balls and wooden crates)
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
	ball_mat.albedo_color = Color(0.95, 0.15, 0.4)
	ball_mat.roughness = 0.25
	beach_ball_mesh.material = ball_mat
	
	var crates = [
		Vector3(0, 1.0, 30), Vector3(1, 1.0, 32), Vector3(-1, 1.0, 32), Vector3(0, 2.6, 31),
		Vector3(30, 1.0, -10), Vector3(32, 1.0, -10), Vector3(31, 2.6, -10),
		Vector3(-10, 1.5, 18), Vector3(14, 1.5, -28)
	]
	for i in range(crates.size()):
		var p = crates[i]
		var is_ball = (i >= 7)
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

# --- SPEED TRAP SYSTEM ---
func _spawn_speed_trap():
	# Create a Speed Trap post next to Central Avenue
	var trap = Area3D.new()
	add_child(trap)
	trap.global_transform.origin = Vector3(0, 1.0, -25)
	trap.collision_mask = 1
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(8, 4, 3)
	col.shape = shape
	trap.add_child(col)
	
	# Speed Trap visual post
	var post = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.3, 4.0, 0.3)
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.6, 0.0) # Speed orange
	box.material = m
	post.mesh = box
	post.transform.origin = Vector3(4.5, 1.0, 0)
	trap.add_child(post)
	
	# Glowing flash light
	speed_trap_light = PointLight3D.new()
	speed_trap_light.light_color = Color.WHITE
	speed_trap_light.light_energy = 0.0
	speed_trap_light.omni_range = 10.0
	speed_trap_light.transform.origin = Vector3(0, 3.5, 0)
	trap.add_child(speed_trap_light)
	
	# Signal connect
	trap.body_entered.connect(_on_speed_trap_entered)

func _on_speed_trap_entered(body):
	if not speed_trap_active:
		return
		
	if body is VehicleBody3D or body.is_in_group("player_car"):
		var speed_kmh = round(body.linear_velocity.length() * 3.6)
		if speed_kmh >= 80.0:
			speed_trap_active = false
			
			# Flash speed camera
			speed_trap_light.light_energy = 15.0
			var tween = create_tween()
			tween.tween_property(speed_trap_light, "light_energy", 0.0, 0.3)
			
			# Award speed bonus!
			GameManager.coins += 50
			GameManager.save_game_settings()
			
			# Notify HUD to display Speed Trap message
			var hud = get_tree().get_first_node_in_group("mobile_hud")
			if hud and hud.has_node("DriftLabel"):
				var dl = hud.get_node("DriftLabel")
				dl.visible = true
				dl.text = "⚡ SPEED TRAP FLASHED!\n" + str(speed_kmh) + " KMPH! +50 Coins 🪙"
				dl.add_theme_color_override("font_color", Color.YELLOW)
				get_tree().create_timer(3.0).timeout.connect(func(): dl.visible = false)
				
			# Reactivate speed trap after 10 seconds
			await get_tree().create_timer(10.0).timeout
			speed_trap_active = true

# --- AERIAL STUNT NEON RINGS ---
func _spawn_aerial_stunt_rings():
	var ring_coords = [
		{"pos": Vector3(0, 4.2, 45), "rot": Vector3(0, 0, 90)}, # Above first ramp
		{"pos": Vector3(0, 4.6, -45), "rot": Vector3(0, 0, 90)} # Above second ramp
	]
	
	for r in ring_coords:
		var ring = Area3D.new()
		add_child(ring)
		ring.global_transform.origin = r["pos"]
		ring.rotation_degrees = r["rot"]
		ring.collision_mask = 1
		
		# Torus shape collision / sensor
		var col = CollisionShape3D.new()
		var s = SphereShape3D.new()
		s.radius = 2.5
		col.shape = s
		ring.add_child(col)
		
		# Torus representation (using CylinderMesh rotated or Tube)
		var visual = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 2.5
		cyl.bottom_radius = 2.45
		cyl.height = 0.2
		
		var m = StandardMaterial3D.new()
		m.albedo_color = Color(0, 0.85, 1) # Glowing Electric Cyan
		m.emission_enabled = true
		m.emission = Color(0, 0.85, 1, 2.0) # High neon glow
		cyl.material = m
		visual.mesh = cyl
		ring.add_child(visual)
		
		ring.body_entered.connect(_on_stunt_ring_entered.bind(ring))

func _on_stunt_ring_entered(body, ring_node: Node3D):
	if body is VehicleBody3D or body.is_in_group("player_car"):
		# Trigger explosion of color / hide ring
		ring_node.visible = false
		
		# Award coins
		GameManager.coins += 100
		GameManager.save_game_settings()
		
		var hud = get_tree().get_first_node_in_group("mobile_hud")
		if hud and hud.has_node("DriftLabel"):
			var dl = hud.get_node("DriftLabel")
			dl.visible = true
			dl.text = "🔥 AERIAL STUNT CLEAR!\nJump Ring Bonus! +100 Coins 🪙"
			dl.add_theme_color_override("font_color", Color(1, 0, 0.45))
			get_tree().create_timer(3.0).timeout.connect(func(): dl.visible = false)
			
		# Respawn ring after 15 seconds
		await get_tree().create_timer(15.0).timeout
		ring_node.visible = true

# --- DYNAMIC WEATHER & RAIN SYSTEMS ---
func _setup_rain_system():
	rain_particles = CPUParticles3D.new()
	rain_particles.emitting = false
	rain_particles.amount = 350
	rain_particles.lifetime = 1.2
	rain_particles.direction = Vector3(0, -1, 0)
	rain_particles.spread = 5.0
	rain_particles.initial_velocity_min = 18.0
	rain_particles.initial_velocity_max = 28.0
	
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.02
	cyl.bottom_radius = 0.02
	cyl.height = 1.2
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.6, 0.95, 0.45)
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	cyl.material = mat
	rain_particles.mesh = cyl
	
	rain_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain_particles.emission_box_extents = Vector3(25, 1, 25)
	
	add_child(rain_particles)

func _attach_rain_to_car(car_node: Node):
	if is_instance_valid(rain_particles) and is_instance_valid(car_node):
		rain_particles.reparent(car_node)
		rain_particles.transform.origin = Vector3(0, 15, 0)

# --- AI PEDESTRIANS SIMULATOR ---
func _spawn_ai_citizens():
	var ai_spawn_spots = [
		Vector3(-10, 0.5, -15), Vector3(10, 0.5, -15),
		Vector3(-30, 0.5, 20), Vector3(30, 0.5, 20),
		Vector3(-25, 0.5, 35), Vector3(25, 0.5, 35)
	]
	
	for i in range(ai_spawn_spots.size()):
		var citizen = Node3D.new()
		add_child(citizen)
		citizen.global_transform.origin = ai_spawn_spots[i]
		ai_citizens.append(citizen)
		
		var head = MeshInstance3D.new()
		var sph = SphereMesh.new()
		sph.radius = 0.25
		sph.height = 0.5
		var m_head = StandardMaterial3D.new()
		m_head.albedo_color = Color(0.85, 0.65, 0.5)
		sph.material = m_head
		head.mesh = sph
		head.transform.origin = Vector3(0, 1.6, 0)
		citizen.add_child(head)
		
		var body = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.3
		cyl.bottom_radius = 0.3
		cyl.height = 1.1
		var m_body = StandardMaterial3D.new()
		m_body.albedo_color = Color(randf(), randf(), randf())
		cyl.material = m_body
		body.mesh = cyl
		body.transform.origin = Vector3(0, 0.8, 0)
		citizen.add_child(body)
		
		citizen.set_meta("start_pos", ai_spawn_spots[i])
		citizen.set_meta("walk_dir", Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)).normalized())
		citizen.set_meta("walk_dist", randf_range(8.0, 18.0))

# --- AI TRAFFIC CARS ---
func _spawn_ai_traffic():
	var traffic_spawn_pos = [
		Vector3(0, 0.5, -50),
		Vector3(40, 0.5, 30)
	]
	
	for i in range(traffic_spawn_pos.size()):
		var tc = CharacterBody3D.new()
		add_child(tc)
		tc.global_transform.origin = traffic_spawn_pos[i]
		ai_traffic_cars.append(tc)
		
		# Simple colored box mesh for traffic cars
		var body = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(1.8, 1.2, 3.6)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.3, 0.3, 0.35) # solid grey traffic car
		box.material = mat
		body.mesh = box
		body.transform.origin = Vector3(0, 0.6, 0)
		tc.add_child(body)
		
		# Collision shape
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = box.size
		col.shape = shape
		tc.add_child(col)
		
		# Traffic settings
		tc.set_meta("speed", 6.0)
		tc.set_meta("dir", Vector3(0, 0, 1) if i == 0 else Vector3(-1, 0, 0))

func _physics_process(delta):
	time_of_day = fmod(time_of_day + day_speed * delta, 24.0)
	_update_day_night_lighting()
	
	weather_timer += delta
	if weather_timer >= 45.0:
		weather_timer = 0.0
		_change_weather()
		
	_process_ai_patrol(delta)
	_process_traffic_patrol(delta)

func _update_day_night_lighting():
	var is_night = time_of_day > 18.5 or time_of_day < 5.5
	
	if is_instance_valid(directional_light):
		var angle = (time_of_day / 24.0) * 360.0
		directional_light.rotation_degrees.x = angle - 90.0
		
		if is_night:
			directional_light.light_energy = move_toward(directional_light.light_energy, 0.0, 0.35)
		else:
			directional_light.light_energy = move_toward(directional_light.light_energy, 1.2, 0.35)
			
	for pole in light_poles_nodes:
		var bulb = pole.get_child(1)
		if bulb:
			bulb.visible = is_night
			
	for house in houses_nodes:
		var window = house.get_child(2)
		if window:
			var mat = window.material_override
			if not mat:
				mat = StandardMaterial3D.new()
				window.material_override = mat
			if is_night:
				mat.albedo_color = Color(1.0, 0.9, 0.4)
				mat.emission_enabled = true
				mat.emission = Color(1.0, 0.9, 0.4, 1.0)
			else:
				mat.albedo_color = Color(0.2, 0.2, 0.2)
				mat.emission_enabled = false

func _change_weather():
	var rand = randi() % 3
	if rand == 0:
		current_weather = "sunny"
		GameManager.current_weather = "sunny"
		if rain_particles: rain_particles.emitting = false
	elif rand == 1:
		current_weather = "cloudy"
		GameManager.current_weather = "cloudy"
		if rain_particles: rain_particles.emitting = false
	else:
		current_weather = "rainy"
		GameManager.current_weather = "rainy"
		if rain_particles: rain_particles.emitting = true

func _process_ai_patrol(delta):
	var is_night = time_of_day > 18.5 or time_of_day < 5.5
	
	for citizen in ai_citizens:
		if not is_instance_valid(citizen):
			continue
			
		if is_night:
			citizen.visible = false
		else:
			citizen.visible = true
			var start = citizen.get_meta("start_pos")
			var dir = citizen.get_meta("walk_dir")
			var dist = citizen.get_meta("walk_dist")
			
			citizen.global_transform.origin += dir * 1.5 * delta
			
			var current_dist = citizen.global_transform.origin.distance_to(start)
			if current_dist >= dist:
				var new_dir = -dir + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
				new_dir = new_dir.normalized()
				citizen.set_meta("walk_dir", new_dir)
				citizen.set_meta("start_pos", citizen.global_transform.origin)

func _process_traffic_patrol(delta):
	# Guide AI Traffic vehicles smoothly along the streets
	for tc in ai_traffic_cars:
		if not is_instance_valid(tc):
			continue
			
		var speed_val = tc.get_meta("speed")
		var dir = tc.get_meta("dir")
		
		# Simple movement
		tc.velocity = dir * speed_val
		tc.move_and_slide()
		
		# Reset path bounds at boundaries
		var p = tc.global_transform.origin
		if abs(p.z) > 85.0:
			tc.set_meta("dir", -dir)
		if abs(p.x) > 85.0:
			tc.set_meta("dir", -dir)

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
	var my_car = spawn_player_car(my_id)
	_attach_rain_to_car(my_car)
	
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
	
	# Apply upgrades to multiplayer car
	_apply_performance_upgrades(new_car)
	
	if has_custom_paint:
		_apply_car_paint(new_car, active_paint_color)
		
	_apply_car_underglow(new_car, GameManager.underglow_color)
		
	return new_car
