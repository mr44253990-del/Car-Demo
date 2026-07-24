extends Control

@onready var progress_bar = $ProgressBar
@onready var tip_label = $TipLabel
@onready var progress_label = $ProgressLabel
@onready var anim_player = $AnimationPlayer

var target_scene: String
var progress = []
var tips = [
	"ড্রিফ্ট করার জন্য Space বা Drift বোতাম চেপে ধরুন!",
	"গাড়ির ক্ষতি হলে গ্যারেজ অথবা গেম মেনু থেকে মেরামত করতে পারেন।",
	"ফুয়েল শেষ হওয়ার আগে ফুয়েল স্টেশনে গিয়ে ফুয়েল কিনে নিন!",
	"মাল্টিপ্লেয়ারে বন্ধুদের সাথে খেলতে WiFi অথবা Hotspot দিয়ে হোস্ট করুন।",
	"সেটিংস থেকে আপনার ফোনের ক্ষমতা অনুযায়ী গ্রাফিক্স পরিবর্তন করতে পারেন।",
	"কয়েন সংগ্রহ করতে পুরো ম্যাপ ঘুরে দেখুন এবং মিশন কমপ্লিট করুন!"
]

func _ready():
	# Randomize tips
	randomize()
	tip_label.text = "পরামর্শ: " + tips[randi() % tips.size()]
	
	# Determine target scene
	if GameManager.target_scene_path != "":
		target_scene = GameManager.target_scene_path
	else:
		target_scene = "res://Scenes/MainMenu.tscn" # Default fallback
		
	# Start threaded loading
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
