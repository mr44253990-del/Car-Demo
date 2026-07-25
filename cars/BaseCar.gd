extends VehicleBody3D
class_name BaseCar

@export var STEER_SPEED = 1.5
@export var STEER_LIMIT = 0.6
var steer_target = 0
@export var engine_force_value = 220

# Auto Gear transmission variables
var gearshift = 1
var gear_multiplicator = 0.3
var last_shift_time = 0.0

var fwd_mps : float
var speed: float

# --- Sound Synthesis ---
var sound_synth: SoundSynth = null
var is_horn_triggered: bool = false

# --- Headlights & Brake Lights ---
var headlight_l: SpotLight3D = null
var headlight_r: SpotLight3D = null
var brakelight_l: OmniLight3D = null
var brakelight_r: OmniLight3D = null

var headlights_active: bool = false

# --- Nitro Boost System ---
var nitro_active: bool = false
var nitro_fuel: float = 100.0
var nitro_max: float = 100.0
var nitro_particles: CPUParticles3D = null

# --- Drift Score System ---
var drift_points: float = 0.0
var is_currently_drifting: bool = false

# --- Damage, Particles & Crash Debris ---
var smoke_particles: CPUParticles3D = null
var previous_velocity: Vector3 = Vector3.ZERO

func _ready():
	add_to_group("player_car")
	
	sound_synth = SoundSynth.new()
	add_child(sound_synth)
	
	_setup_lights()
	_setup_nitro_system()
	
	if is_local_player():
		GameManager.reset_car_state()
		
		var root_scene = get_tree().current_scene
		if root_scene and root_scene.has_node("CarResetter"):
			var resetter = root_scene.get_node("CarResetter")
			if resetter.has_method("init"):
				resetter.init()
		
		contact_monitor = true
		max_contacts_reported = 4
		body_entered.connect(_on_car_body_entered)
		
		_setup_smoke_particles()

func is_local_player() -> bool:
	if not GameManager.is_multiplayer:
		return true
	return is_multiplayer_authority()

func _setup_lights():
	# Front Headlights
	headlight_l = SpotLight3D.new()
	headlight_r = SpotLight3D.new()
	add_child(headlight_l)
	add_child(headlight_r)
	
	headlight_l.transform.origin = Vector3(0.7, 0.5, -1.8)
	headlight_r.transform.origin = Vector3(-0.7, 0.5, -1.8)
	
	headlight_l.rotation_degrees = Vector3(0, 180, 0)
	headlight_r.rotation_degrees = Vector3(0, 180, 0)
	
	headlight_l.spot_range = 35.0
	headlight_r.spot_range = 35.0
	headlight_l.light_energy = 4.0
	headlight_r.light_energy = 4.0
	headlight_l.visible = false
	headlight_r.visible = false
	
	# Rear Brake Lights
	brakelight_l = OmniLight3D.new()
	brakelight_r = OmniLight3D.new()
	add_child(brakelight_l)
	add_child(brakelight_r)
	
	brakelight_l.transform.origin = Vector3(0.7, 0.6, 1.8)
	brakelight_r.transform.origin = Vector3(-0.7, 0.6, 1.8)
	
	brakelight_l.light_color = Color.RED
	brakelight_r.light_color = Color.RED
	brakelight_l.light_energy = 3.0
	brakelight_r.light_energy = 3.0
	brakelight_l.omni_range = 1.5
	brakelight_r.omni_range = 1.5
	brakelight_l.visible = false
	brakelight_r.visible = false

func _setup_nitro_system():
	# Cyan Fire/Spark particle effects from rear exhaust on boost
	nitro_particles = CPUParticles3D.new()
	add_child(nitro_particles)
	nitro_particles.transform.origin = Vector3(0.0, 0.3, 1.7) # exhaust pipe
	nitro_particles.emitting = false
	nitro_particles.amount = 40
	nitro_particles.lifetime = 0.6
	
	# Small glowing cyan sphere particle
	nitro_particles.mesh = SphereMesh.new()
	nitro_particles.mesh.radius = 0.08
	nitro_particles.mesh.height = 0.16
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 0.9, 1.0) # Electric cyan
	mat.emission_enabled = true
	mat.emission = Color(0.0, 0.9, 1.0, 1.5) # Glowing fire
	nitro_particles.material_override = mat
	
	nitro_particles.direction = Vector3(0, 0, 1) # shoot backwards
	nitro_particles.spread = 15.0
	nitro_particles.gravity = Vector3(0, 1, 0)
	nitro_particles.initial_velocity_min = 4.0
	nitro_particles.initial_velocity_max = 8.0

func _setup_smoke_particles():
	smoke_particles = CPUParticles3D.new()
	add_child(smoke_particles)
	smoke_particles.transform.origin = Vector3(0, 0.5, 1.5)
	smoke_particles.emitting = false
	smoke_particles.amount = 30
	smoke_particles.lifetime = 1.5
	smoke_particles.mesh = SphereMesh.new()
	smoke_particles.mesh.radius = 0.2
	smoke_particles.mesh.height = 0.4
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.2, 0.2, 0.6)
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	smoke_particles.material_override = mat
	
	smoke_particles.gravity = Vector3(0, 2, 0)
	smoke_particles.initial_velocity_min = 0.5
	smoke_particles.initial_velocity_max = 1.5

func toggle_headlights(on: bool):
	headlights_active = on
	if headlight_l and headlight_r:
		headlight_l.visible = on
		headlight_r.visible = on

func trigger_horn(active: bool):
	is_horn_triggered = active
	if sound_synth:
		sound_synth.set_horn(active)

func trigger_nitro(active: bool):
	if active and nitro_fuel > 5.0:
		nitro_active = true
	else:
		nitro_active = false

func _physics_process(delta):
	if GameManager.is_multiplayer:
		if is_multiplayer_authority():
			sync_state.rpc(global_transform, linear_velocity, angular_velocity, gearshift)
		else:
			return

	speed = linear_velocity.length() * Engine.get_frames_per_second() * delta
	fwd_mps = transform.basis.x.x
	
	_process_auto_gear()
	
	traction(speed)
	process_accel(delta)
	process_steer(delta)
	process_brake(delta)
	
	# --- Sound Synthesis ---
	if sound_synth:
		# Nitro speeds up pitch scale
		var speed_factor = (speed / 45.0) * (1.5 if nitro_active else 1.0)
		sound_synth.set_engine_pitch(speed_factor)
		var is_skidding = Input.is_action_pressed("ui_select") and speed > 10.0
		sound_synth.set_skid(is_skidding)
	
	# --- Brake Lights Trigger ---
	var is_braking = Input.is_action_pressed("backward") or Input.is_action_pressed("ui_select")
	if brakelight_l and brakelight_r:
		brakelight_l.visible = is_braking
		brakelight_r.visible = is_braking
	
	# --- Headlights and Keyboard Horn/Nitro Inputs ---
	if is_local_player():
		if Input.is_action_pressed("ui_focus_next"): # Shift can act as Keyboard nitro
			trigger_nitro(true)
		else:
			# Check keyboard release of nitro
			if not Input.is_action_pressed("ui_focus_next") and not is_local_player_using_hud_nitro():
				trigger_nitro(false)
				
	# --- Process Nitro Fuel & Particles ---
	_process_nitro_system(delta)
	
	# --- Process Drift Score System ---
	_process_drift_score(delta)
	
	_process_fuel_consumption(delta)
	_process_damage_effects()
	
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
		
	previous_velocity = linear_velocity

func is_local_player_using_hud_nitro() -> bool:
	var hud = get_tree().get_first_node_in_group("mobile_hud")
	if hud and "is_nitro_held" in hud and hud.is_nitro_held:
		return true
	return false

# --- NITRO SYSTEM CORE ---
func _process_nitro_system(delta):
	if nitro_active:
		nitro_fuel -= 22.0 * delta # drain fuel
		if is_instance_valid(nitro_particles):
			nitro_particles.emitting = true
			
		if nitro_fuel <= 0.0:
			nitro_fuel = 0.0
			nitro_active = false
	else:
		nitro_fuel += 8.0 * delta # regenerate slowly
		nitro_fuel = clamp(nitro_fuel, 0.0, nitro_max)
		if is_instance_valid(nitro_particles):
			nitro_particles.emitting = false

# --- DRIFT SCORE CORE ---
func _process_drift_score(delta):
	if not is_local_player():
		return
		
	# Sideways speed / slide calculation
	var sideways_speed = abs(global_transform.basis.x.dot(linear_velocity))
	
	if sideways_speed > 2.8 and speed > 12.0:
		is_currently_drifting = true
		# Gain drift points proportional to sideways slide speed and current speed
		drift_points += sideways_speed * 12.0 * delta
		
		# Notify HUD to display the current drift points
		var hud = get_tree().get_first_node_in_group("mobile_hud")
		if hud and hud.has_method("update_drift_score"):
			hud.update_drift_score(round(drift_points), true)
	else:
		if is_currently_drifting:
			is_currently_drifting = false
			# Finalize drift score, award to account
			var earned_coins = int(drift_points / 40.0)
			if earned_coins > 0:
				GameManager.coins += earned_coins
				GameManager.save_game_settings()
				
			# Notify HUD that drift ended
			var hud = get_tree().get_first_node_in_group("mobile_hud")
			if hud and hud.has_method("update_drift_score"):
				hud.update_drift_score(round(drift_points), false, earned_coins)
				
			drift_points = 0.0

func _process_auto_gear():
	var time_now = Time.get_ticks_msec() / 1000.0
	if time_now - last_shift_time < 0.6:
		return
		
	var kmh = speed * 3.6
	var old_gear = gearshift
	
	if kmh < 15:
		gearshift = 1
		gear_multiplicator = 0.35
	elif kmh >= 15 and kmh < 40:
		gearshift = 2
		gear_multiplicator = 0.7
	elif kmh >= 40 and kmh < 75:
		gearshift = 3
		gear_multiplicator = 1.0
	elif kmh >= 75 and kmh < 110:
		gearshift = 4
		gear_multiplicator = 1.35
	else:
		gearshift = 5
		gear_multiplicator = 1.85
		
	if gearshift != old_gear:
		last_shift_time = time_now

func _process_fuel_consumption(delta):
	if not is_local_player():
		return
		
	if GameManager.selected_mission_id == 0:
		GameManager.car_fuel = 100.0
		return
		
	var fuel_drain_rate = 0.5
	if GameManager.selected_mission_id == 2:
		fuel_drain_rate = 1.8
		
	if speed > 2.0:
		GameManager.car_fuel -= fuel_drain_rate * delta * (1.0 + (speed / 100.0))
	else:
		GameManager.car_fuel -= (fuel_drain_rate * 0.1) * delta
		
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
	
	if impact_speed > 4.0:
		var damage_amount = (impact_speed - 4.0) * 1.5
		GameManager.car_damage = clamp(GameManager.car_damage + damage_amount, 0.0, GameManager.car_max_damage)
		GameManager.save_game_settings()
		
		_spawn_crash_debris()
		
		print("Crash detected! Damage added: ", damage_amount, " Total damage: ", GameManager.car_damage)

func _spawn_crash_debris():
	for i in range(randi_range(2, 3)):
		var debris = RigidBody3D.new()
		debris.mass = 2.0
		get_tree().current_scene.add_child(debris)
		
		var front_offset = -transform.basis.z * 1.6 + transform.basis.y * 0.4
		debris.global_transform.origin = global_transform.origin + front_offset
		
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(randf_range(0.2, 0.5), randf_range(0.1, 0.3), randf_range(0.2, 0.5))
		col.shape = shape
		debris.add_child(col)
		
		var mesh_inst = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		box_mesh.size = shape.size
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(randf(), randf(), randf()) if randf() > 0.5 else Color(1.0, 0.4, 0)
		mat.metallic = 0.8
		mat.roughness = 0.2
		box_mesh.material = mat
		mesh_inst.mesh = box_mesh
		debris.add_child(mesh_inst)
		
		var eject_dir = (transform.basis.z + transform.basis.x * randf_range(-1.0, 1.0)).normalized()
		debris.apply_central_impulse(eject_dir * randf_range(8.0, 18.0))
		
		get_tree().create_timer(6.0).timeout.connect(func(): debris.queue_free())

func process_accel(delta):
	if GameManager.car_fuel <= 0.0:
		engine_force = 0
		return
		
	var damage_penalty = 1.0 - (GameManager.car_damage / 110.0)
	damage_penalty = clamp(damage_penalty, 0.08, 1.0)
	
	# Apply massive Nitro boost multiplier!
	var nitro_multiplier = 2.25 if nitro_active else 1.0
	var adjusted_engine_force = engine_force_value * damage_penalty * nitro_multiplier

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

func process_steer(delta):
	steer_target = Input.get_action_strength("left") - Input.get_action_strength("right")
	steer_target *= STEER_LIMIT
	steering = move_toward(steering, steer_target, STEER_SPEED * delta)

func process_brake(_delta):
	if Input.is_action_pressed("ui_select"):
		brake = 0.8
		$wheel_rear_left.wheel_friction_slip = 1.8
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
