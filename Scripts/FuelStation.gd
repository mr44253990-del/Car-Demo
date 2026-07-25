extends Area3D

@onready var info_label = $InfoLabel3D
var player_inside: bool = false

func _ready():
	info_label.text = "⛽ FUEL STATION\nPark inside to refuel!"
	info_label.visible = false

func _on_body_entered(body):
	if body is VehicleBody3D or body.is_in_group("player_car"):
		player_inside = true
		info_label.visible = true
		
		# Open Refuel Menu Popup on the mobile HUD automatically
		var hud = get_tree().get_first_node_in_group("mobile_hud")
		if hud:
			var ref_menu = hud.get_node_or_null("RefuelMenu")
			if ref_menu:
				ref_menu.visible = true
				if hud.has_method("_on_refuel_prompt_pressed"):
					hud._on_refuel_prompt_pressed()

func _on_body_released(body):
	if body is VehicleBody3D or body.is_in_group("player_car"):
		player_inside = false
		info_label.visible = false
		
		# Close Refuel Menu automatically when the player drives away
		var hud = get_tree().get_first_node_in_group("mobile_hud")
		if hud:
			var ref_menu = hud.get_node_or_null("RefuelMenu")
			if ref_menu:
				ref_menu.visible = false
