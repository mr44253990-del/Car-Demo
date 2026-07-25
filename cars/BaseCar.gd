extends VehicleBody3D
class_name BaseCar

@export var STEER_SPEED = 1.5
@export var STEER_LIMIT = 0.6
var steer_target = 0
@export var engine_force_value = 200

var gearshift = 3
var gear_multiplicator = 1
var gear_locked = false

var fwd_mps : float
var speed: float

# --- Damage and Fuel ---
var smoke_particles: CPUParticles3D = null
var previous_velocity: Vector3 = Vector3.ZERO

func _ready():
	# Add to groups for identification
	add_to_group("player_car")
	
	# Reset state if local
	if is_local_player():
		GameManager.reset_car_state()
		
		# Bulletproof initialization of legacy CarResetter if present in active level
		var root_scene = get_tree().current_scene
		if root_scene and root_scene.has_node("CarResetter"):
			var resetter = root_scene.get_node("CarResetter")
			if resetter.has_method("init"):
				resetter.init()
		
		# Enable collision detection for damage
		contact_monitor = true
		max_contacts_reported = 4
		body_entered.connect(_on_car_body_entered)
		
		# Create smoke particles for visual damage
		_setup_smoke_particles()

func is_local_player() -> bool:
	if not GameManager.is_multiplayer:
		return true
	return is_multiplayer_authority()

func _setup_smoke_particles():
	smoke_particles = CPUParticles3D.new()
	add_child(smoke_particles)
	smoke_particles.transform.origin = Vector3(0, 0.5, 1.5) # rear of the car
	smoke_particles.emitting = false
	smoke_particles.amount = 30
	smoke_particles.lifetime = 1.5
	smoke_particles.mesh = SphereMesh.new()
	smoke_particles.mesh.radius = 0.2
	smoke_particles.mesh.height = 0.4
	
	# Gray/dark smoke color
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.2, 0.2, 0.6)
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	smoke_particles.material_override = mat
	
	# Gravity upwards
	smoke_particles.gravity = Vector3(0, 2, 0)
	smoke_particles.initial_velocity_min = 0.5
	smoke_particles.initial_velocity_max = 1.5

func _physics_process(delta):
	# Multiplayer synchronization
	if GameManager.is_multiplayer:
		if is_multiplayer_authority():
			sync_state.rpc(global_transform, linear_velocity, angular_velocity, gearshift)
		else:
			return

	speed = linear_velocity.length() * Engine.get_frames_per_second() * delta
	fwd_mps = transform.basis.x.x
	
	traction(speed)
	process_gear_shift()
	process_accel(delta)
	process_steer(delta)
	process_brake(delta)
	
	# --- Fuel Consumption ---
	_process_fuel_consumption(delta)
	
	# --- Damage Smoke & Performance ---
	_process_damage_effects()
	
	# --- Update old HUD safely (Bulletproof) ---
	var root_scene = get_tree().current_scene
	if root_scene:
		var legacy_hud = root_scene.get_node_or_null("Hud")
		if legacy_hud:
			var s_label = legacy_hud.get_node_or_null("speed")
			if s_label:
				s_label.text = str(round(speed * 3.6)) + "  KMPH"
			var g_label = legacy_hud.get_node_or_null("gearshift_label")
			if g_label:
				g_label.text = "Gear: " + str(gearshift)
		
	# Keep track of previous velocity for crash speed check
	previous_velocity = linear_velocity

func _process_fuel_consumption(delta):
	if not is_local_player():
		return
		
	# Unlimited fuel in free roam (Mission 0)
	if GameManager.selected_mission_id == 0:
		GameManager.car_fuel = 100.0
		return
		
	# Base fuel rate
	var fuel_drain_rate = 0.5 # normal drain
	
	# Mission 3: Fuel Survivor (fast drain!)
	if GameManager.selected_mission_id == 2:
		fuel_drain_rate = 1.8
		
	# Drain fuel if car is moving or engine is on
	if speed > 2.0:
		GameManager.car_fuel -= fuel_drain_rate * delta * (1.0 + (speed / 100.0))
	else:
		GameManager.car_fuel -= (fuel_drain_rate * 0.1) * delta # idling
		
	GameManager.car_fuel = clamp(GameManager.car_fuel, 0.0, GameManager.car_max_fuel)

func _process_damage_effects():
	if not is_local_player():
		return
		
	if is_instance_valid(smoke_particles):
		if GameManager.car_damage > 70.0:
			smoke_particles.emitting = true
			smoke_particles.material_override.albedo_color = Color(0.1, 0.1, 0.1, 0.9)
		elif GameManager.car_damage > 40.0:
			smoke_particles.emitting = true
			smoke_particles.material_override.albedo_color = Color(0.5, 0.5, 0.5, 0.5)
		else:
			smoke_particles.emitting = false

func _on_car_body_entered(body):
	if not is_local_player():
		return
		
	if body is Area3D:
		return
		
	var impact_velocity = previous_velocity - linear_velocity
	var impact_speed = impact_velocity.length()
	
	if impact_speed > 4.0: # Significant crash
		var damage_amount = (impact_speed - 4.0) * 1.5
		GameManager.car_damage = clamp(GameManager.car_damage + damage_amount, 0.0, GameManager.car_max_damage)
		GameManager.save_game_settings()
		print("Crash detected! Damage added: ", damage_amount, " Total damage: ", GameManager.car_damage)

func process_accel(delta):
	# If out of fuel, car can't accelerate
	if GameManager.car_fuel <= 0.0:
		engine_force = 0
		return
		
	# Reduced performance based on damage
	var damage_penalty = 1.0 - (GameManager.car_damage / 150.0) # up to 33% reduction
	var adjusted_engine_force = engine_force_value * damage_penalty

	if Input.is_action_pressed("forward"):
		if fwd_mps >= -1:
			if speed < 30 and speed != 0:
				engine_force = clamp(adjusted_engine_force * 10 / speed, 0, adjusted_engine_force * 4.0)
			else:
				engine_force = adjusted_engine_force
		engine_force = engine_force * gear_multiplicator
		return
	
	if Input.is_action_pressed("backward"):
		if speed < 20 and speed != 0:
			engine_force = -clamp(adjusted_engine_force * 3 / speed, 0, adjusted_engine_force * 2.0)
		else:
			engine_force = -adjusted_engine_force
		return
	engine_force = 0
	brake = 0

func process_gear_shift():
	if Input.is_action_pressed("gear"):
		if gear_locked == false:
			gear_locked = true
			gearshift += 1
			if gearshift == 6: gearshift = 1
			if gearshift == 1: gear_multiplicator = 0.3
			elif gearshift == 2: gear_multiplicator = 0.7
			elif gearshift == 3: gear_multiplicator = 1
			elif gearshift == 4: gear_multiplicator = 1.3
			elif gearshift == 5: gear_multiplicator = 1.8
			await get_tree().create_timer(1.0).timeout
			gear_locked = false

func process_steer(delta):
	steer_target = Input.get_action_strength("left") - Input.get_action_strength("right")
	steer_target *= STEER_LIMIT
	steering = move_toward(steering, steer_target, STEER_SPEED * delta)

func process_brake(delta):
	if Input.is_action_pressed("ui_select"):
		brake = 0.8
		$wheel_rear_left.wheel_friction_slip = 1.8 # Drift slide effect!
		$wheel_rear_right.wheel_friction_slip = 1.8
	else:
		$wheel_rear_left.wheel_friction_slip = 2.9
		$wheel_rear_right.wheel_friction_slip = 2.9

func traction(speed):
	apply_central_force(Vector3.DOWN * speed)

# --- MULTIPLAYER RPC SYNCHRONIZATION ---
@rpc("any_peer", "unreliable")
func sync_state(srv_transform: Transform3D, srv_lin_vel: Vector3, srv_ang_vel: Vector3, srv_gear: int):
	global_transform = srv_transform
	linear_velocity = srv_lin_vel
	angular_velocity = srv_ang_vel
	gearshift = srv_gear
