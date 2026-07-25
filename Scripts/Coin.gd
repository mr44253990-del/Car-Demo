extends Area3D

@export var coin_value: int = 15
@export var rotate_speed: float = 3.0
@export var respawn_time: float = 12.0 # Respawn after 12 seconds

@onready var mesh = $MeshInstance3D
@onready var collision_shape = $CollisionShape3D

var is_collected: bool = false

func _ready():
	add_to_group("coins")

func _process(delta):
	if not is_collected:
		rotation.y += rotate_speed * delta

func _on_body_entered(body):
	if is_collected:
		return
		
	if body is VehicleBody3D or body.is_in_group("player_car"):
		_collect_coin()

func _collect_coin():
	is_collected = true
	GameManager.coins += coin_value
	GameManager.save_game_settings()
	
	# Play a clean gold coin collect sound/tween locally
	var tween = create_tween()
	tween.set_parallel(true)
	# Animate the coin scaling up and fading out ("ফর্সা হয়ে যাবে" / fading away beautifully)
	tween.tween_property(mesh, "scale", Vector3(1.6, 1.6, 1.6), 0.3)
	tween.parallel().tween_property(mesh, "modulate", Color(1.5, 1.5, 1.5, 0.0), 0.3) # glowing white fade-out
	
	# Disable collisions immediately so it can't be re-collected
	collision_shape.set_deferred("disabled", true)
	
	# Start respawn timer
	await get_tree().create_timer(respawn_time).timeout
	_respawn_coin()

func _respawn_coin():
	is_collected = false
	mesh.scale = Vector3(1.0, 1.0, 1.0)
	mesh.modulate = Color(1, 1, 1, 1) # reset opacity and colors
	collision_shape.set_deferred("disabled", false)
