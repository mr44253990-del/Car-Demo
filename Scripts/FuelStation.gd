extends Area3D

@onready var info_label = $InfoLabel3D
var player_inside: bool = false

func _ready():
	info_label.text = "⛽ FUEL STATION\nStop here to buy fuel!"
	info_label.visible = false

func _on_body_entered(body):
	if body is VehicleBody3D or body.is_in_group("player_car"):
		player_inside = true
		info_label.visible = true
		
		# Show the Refuel Prompt on the mobile HUD
		var hud = get_tree().get_first_node_in_group("mobile_hud")
		if hud and hud.has_method("show_refuel_prompt"):
			hud.show_refuel_prompt(true)

func _on_body_released(body):
	if body is VehicleBody3D or body.is_in_group("player_car"):
		player_inside = false
		info_label.visible = false
		
		# Hide the Refuel Prompt on the mobile HUD
		var hud = get_tree().get_first_node_in_group("mobile_hud")
		if hud and hud.has_method("show_refuel_prompt"):
			hud.show_refuel_prompt(false)
