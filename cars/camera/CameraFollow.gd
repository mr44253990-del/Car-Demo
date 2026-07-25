extends Camera3D

@export var target_distance = 6.0
@export var target_height = 2.2
@export var speed := 20.0
var follow_this = null
var last_lookat: Vector3

# Camera modes
enum CameraMode { NORMAL, HOOD, FIRSTPERSON, CINEMATIC, TOPDOWN }
var current_mode: CameraMode = CameraMode.NORMAL

# Cinematic orbiting angle
var orbit_angle: float = 0.0
@export var orbit_speed: float = 0.5

func _ready():
	add_to_group("game_camera")
	
	follow_this = get_parent()
	if follow_this:
		last_lookat = follow_this.global_transform.origin
	else:
		last_lookat = Vector3.ZERO

func toggle_camera_mode():
	current_mode = (current_mode + 1) % 5 as CameraMode
	match current_mode:
		CameraMode.NORMAL:
			target_distance = 6.0
			target_height = 2.2
			print("Camera mode: Normal")
		CameraMode.HOOD:
			target_distance = 1.5
			target_height = 1.0
			print("Camera mode: Hood")
		CameraMode.FIRSTPERSON:
			# Placed inside the cockpit
			target_distance = 0.2
			target_height = 0.95
			print("Camera mode: First-Person")
		CameraMode.CINEMATIC:
			# Slowly orbits the car
			target_distance = 8.0
			target_height = 2.8
			print("Camera mode: Cinematic")
		CameraMode.TOPDOWN:
			target_distance = 12.0
			target_height = 8.0
			print("Camera mode: Topdown")

func _physics_process(delta):
	if not is_instance_valid(follow_this):
		return
		
	# Increase orbit angle for Cinematic Mode
	if current_mode == CameraMode.CINEMATIC:
		orbit_angle += orbit_speed * delta
		
	var delta_v = global_transform.origin - follow_this.global_transform.origin
	var target_pos = global_transform.origin

	if current_mode == CameraMode.CINEMATIC:
		# Calculate orbit position around the car basis
		var offset = Vector3(cos(orbit_angle), 0, sin(orbit_angle)) * target_distance
		offset.y = target_height
		target_pos = follow_this.global_transform.origin + offset
	else:
		# Standard follow
		delta_v.y = 0.0
		if (delta_v.length() > target_distance):
			delta_v = delta_v.normalized() * target_distance
			delta_v.y = target_height
			target_pos = follow_this.global_transform.origin + delta_v
		else:
			target_pos.y = follow_this.global_transform.origin.y + target_height
	
	global_transform.origin = global_transform.origin.lerp(target_pos, delta * speed)
	
	last_lookat = last_lookat.lerp(follow_this.global_transform.origin, delta * speed)
	
	var lookat_target = last_lookat + Vector3(0, 0.5, 0)
	
	if current_mode == CameraMode.HOOD or current_mode == CameraMode.FIRSTPERSON:
		# Look directly forward relative to the car's basis
		var target_look = follow_this.global_transform.origin + (-follow_this.global_transform.basis.z * 10.0)
		look_at(target_look, Vector3.UP)
	else:
		look_at(lookat_target, Vector3.UP)
