extends PanelContainer

# Splash.gd
#
#	Faculty for displaying splash text in the middle of the screen
#
signal done
signal victoryStarCallback

onready var bigLabel = get_node("VBoxContainer/SplashBigText")
onready var smallLabel = get_node("VBoxContainer/SplashSmallText")
onready var background = get_node("SplashBackground")
onready var tween = get_node("Tween")
var soundPlayer

const SWOOSH_TIME = 0.6

func _ready():
	hide()
	tween.connect("tween_all_completed", self, "_on_tween_all_completed")
	
	soundPlayer = AudioStreamPlayer.new()
	add_child(soundPlayer)
	soundPlayer.stream = load("res://Assets/Sound/Ed_Allsounds/Dice_Throw_05.wav")

var mode = 0
var bigText
var smallText
var holdTime
func showText(var _bigText : String, var _smallText : String, var time : float):
	holdTime = time
	bigText = _bigText
	smallText = _smallText
	bigLabel.text = "   "
	smallLabel.text = "   "
	
	mode = 0
	tween.interpolate_property(background, "margin_right", 0, get_viewport_rect().size.x, SWOOSH_TIME, Tween.TRANS_QUAD, Tween.EASE_IN)
	tween.start()
	soundPlayer.play()
	show()

var throwaway
func _on_tween_all_completed():
	if mode == 0:
		bigLabel.text = bigText
		smallLabel.text = smallText
		tween.interpolate_property(self, "throwaway", 0, 10, holdTime, Tween.TRANS_LINEAR, Tween.EASE_IN)
		tween.start()
		emit_signal("victoryStarCallback")
		mode = 1
	elif mode == 1:
		bigLabel.text = "  "
		smallLabel.text = "  "
		tween.interpolate_property(background, "margin_left", 0, get_viewport_rect().size.x, SWOOSH_TIME, Tween.TRANS_QUAD, Tween.EASE_IN)
		tween.start()
		mode = 2
	else:
		hide()
		background.margin_left = 0
		emit_signal("done")
