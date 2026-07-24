extends Area3D

@onready var info_label = $InfoLabel3D
var player_inside: bool = false
var refuel_timer: float = 0.0
const REFUEL_INTERVAL = 0.1 # Refuel every 0.1s
const REFUEL_COST = 2 # 2 coins per refuel step
const REFUEL_AMOUNT = 5.0 # 5% fuel per refuel step

func _ready():
	info_label.text = "⛽ FUEL STATION\nBuy fuel with coins!\n(Park your car here)"
	info_label.visible = false

func _on_body_entered(body):
	if body is VehicleBody3D or body.is_in_group("player_car"):
		player_inside = true
		info_label.visible = true

func _on_body_released(body):
	if body is VehicleBody3D or body.is_in_group("player_car"):
		player_inside = false
		info_label.visible = false

func _process(delta):
	if player_inside:
		if GameManager.car_fuel < GameManager.car_max_fuel:
			refuel_timer += delta
			if refuel_timer >= REFUEL_INTERVAL:
				refuel_timer = 0.0
				if GameManager.coins >= REFUEL_COST:
					GameManager.coins -= REFUEL_COST
					GameManager.car_fuel = clamp(GameManager.car_fuel + REFUEL_AMOUNT, 0.0, GameManager.car_max_fuel)
					GameManager.save_game_settings()
					info_label.text = "⛽ Refueling...\nFuel: " + str(round(GameManager.car_fuel)) + "%\n🪙 -" + str(REFUEL_COST)
				else:
					info_label.text = "⛽ FUEL STATION\nNot enough coins! 🪙"
		else:
			info_label.text = "⛽ Fuel Tank Full! 🔋\nReady to go!"
