extends Control

@onready var progress_bar = $CenterPanel/ProgressBar
@onready var tip_label = $CenterPanel/TipLabel
@onready var progress_label = $CenterPanel/ProgressLabel
@onready var anim_player = $AnimationPlayer

var target_scene: String
var tips = [
	"Hold Space or touch DRIFT button to slide around corners!",
	"If your car gets damaged, visit the Garage or Game Menu to repair it.",
	"Keep an eye on your fuel! Drive to the nearest Fuel Station before it runs out.",
	"Play with friends offline! Host a WiFi or Hotspot room, no internet required.",
	"Optimize your game! Adjust Graphics Settings in the menu to match your device.",
	"Explore the map to find hidden gold coins and unlock secret features!",
	"Double-tap the DRIFT button on mobile to lock handbrake for tight turns!"
]

func _ready():
	# Explicitly unpause game to prevent any freeze/black screen lockups
	get_tree().paused = false
	
	randomize()
	tip_label.text = "Tip: " + tips[randi() % tips.size()]
	
	if GameManager.target_scene_path != "":
		target_scene = GameManager.target_scene_path
	else:
		target_scene = "res://Scenes/MainMenu.tscn" # Default fallback
		
	_start_smooth_loading()

func _start_smooth_loading():
	progress_bar.value = 0
	progress_label.text = "0%"
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	
	tween.tween_property(progress_bar, "value", 100.0, 1.8)
	tween.parallel().tween_method(func(val): progress_label.text = str(round(val)) + "%", 0.0, 100.0, 1.8)
	
	tween.tween_callback(_on_loading_complete)

func _process(delta):
	if has_node("CenterPanel/LoadingIcon/SpinningWheel"):
		$CenterPanel/LoadingIcon/SpinningWheel.rotation += 4 * delta

func _on_loading_complete():
	anim_player.play("fade_out")
	await get_tree().create_timer(0.4).timeout
	
	var err = get_tree().change_scene_to_file(target_scene)
	if err != OK:
		print("Failed to change scene to: ", target_scene, " Error: ", err)
		get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
