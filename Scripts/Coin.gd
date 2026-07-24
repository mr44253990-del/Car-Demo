extends Area3D

@export var coin_value: int = 15
@export var rotate_speed: float = 3.0

func _ready():
	add_to_group("coins")

func _process(delta):
	# Spin the coin
	rotation.y += rotate_speed * delta

func _on_body_entered(body):
	# Check if the colliding body is the player car
	if body is VehicleBody3D or body.is_in_group("player_car"):
		GameManager.coins += coin_value
		GameManager.save_game_settings()
		
		# Optional: Add small collect sound or visual effect here
		# For now, print to console and free the coin
		print("Coin collected! Value: ", coin_value)
		
		# Free across network if multiplayer
		if GameManager.is_multiplayer:
			remove_coin_rpc.rpc()
		else:
			queue_free()

@rpc("any_peer", "call_local", "reliable")
func remove_coin_rpc():
	queue_free()
