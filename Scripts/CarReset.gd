extends Node

var init_transform : Transform3D
var has_init : bool = false

func init():
	var car = get_active_car()
	if car:
		init_transform = car.transform
		has_init = true
		print("Initialized reset transform: ", init_transform)

func get_active_car() -> BaseCar:
	# Safely fetch local player car
	var cars = get_tree().get_nodes_in_group("player_car")
	for c in cars:
		if c is BaseCar and c.is_local_player():
			return c
	return null

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		var car = get_active_car()
		if car and is_instance_valid(car):
			if not has_init:
				init()
			
			PhysicsServer3D.body_set_state(
				car.get_rid(),
				PhysicsServer3D.BODY_STATE_TRANSFORM,
				init_transform if has_init else car.transform
			)
			
			car.linear_velocity = Vector3.ZERO
			car.angular_velocity = Vector3.ZERO
			print("Car respawned/reset successfully.")
