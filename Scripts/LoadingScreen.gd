extends Control

@onready var progress_bar = $ProgressBar
@onready var tip_label = $TipLabel
@onready var progress_label = $ProgressLabel
@onready var anim_player = $AnimationPlayer

var target_scene: String
var progress = []
var tips = [
	"Hold Space or touch DRIFT button to slide around corners!",
	"If your car gets damaged, visit the Garage or Game Menu to repair it.",
	"Keep an eye on your fuel! Drive to the nearest Fuel Station before it runs out.",
	"Play with friends offline! Host a WiFi or Hotspot room, no internet required.",
	"Optimize your game! Adjust Graphics Settings in the menu to match your device.",
	"Explore the map to find hidden gold coins and unlock secret features!"
]

func _ready():
	randomize()
	tip_label.text = "Tip: " + tips[randi() % tips.size()]
	
	if GameManager.target_scene_path != "":
		target_scene = GameManager.target_scene_path
	else:
		target_scene = "res://Scenes/MainMenu.tscn" # Default fallback
		
	var err = ResourceLoader.load_threaded_request(target_scene)
	if err != OK:
		print("Error launching threaded load: ", err)
		get_tree().change_scene_to_file(target_scene)

func _process(delta):
	if has_node("LoadingIcon/SpinningWheel"):
		$LoadingIcon/SpinningWheel.rotation += 5 * delta
		
	var status = ResourceLoader.load_threaded_get_status(target_scene, progress)
	
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var value = progress[0] * 100
			progress_bar.value = value
			progress_label.text = str(round(value)) + "%"
		ResourceLoader.THREAD_LOAD_LOADED:
			progress_bar.value = 100
			progress_label.text = "100%"
			anim_player.play("fade_out")
			set_process(false)
			await get_tree().create_timer(0.5).timeout
			var loaded_scene = ResourceLoader.load_threaded_get(target_scene)
			get_tree().change_scene_to_packed(loaded_scene)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			print("Error during loading scene: ", target_scene)
			get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _on_timer_timeout():
	pass
