extends Sprite

class_name VictoryStar

# VictoryStar.gd
#
#	Visualizer for winning a set: a little star materializes in splash message, then flies off
#	to GUI position, then pulses, then selfdestructs, emitting the following signal
signal done

const TRAVEL_TIME = 0.65
const PULSE_TIME = 0.3


var tween
var mode = 0

# Type parameter is side who won star. 0 for player, 1 for foe.
func _init(var _startPos : Vector2, var _targetPos : Vector2, var type : int):
	texture = load("res://Assets/StarBlue.png") if type == 0 else load("res://Assets/StarRed.png")
	global_position = _startPos
	
	tween = Tween.new()
	add_child(tween)
	tween.connect("tween_all_completed", self, "_on_tween_all_completed")
	tween.interpolate_property(self, "global_position", global_position, _targetPos, TRAVEL_TIME, Tween.TRANS_QUAD, Tween.EASE_IN)
	#tween.interpolate_property(self, "scale", Vector2.ONE, Vector2(0.5, 0.5), TRAVEL_TIME, Tween.TRANS_LINEAR, Tween.EASE_IN)

func _ready():
	tween.start()

func _on_tween_all_completed():
	if mode == 0:
		# Begin pulse
		tween.interpolate_property(self, "scale", null, Vector2(2, 2), PULSE_TIME / 2, Tween.TRANS_BACK, Tween.EASE_OUT)
		tween.start()
		mode = 1
	elif mode == 1:
		# withdraw pulse
		tween.interpolate_property(self, "scale", null, Vector2.ONE, PULSE_TIME / 2, Tween.TRANS_BACK, Tween.EASE_OUT)
		tween.start()
		mode = 2
	else:
		# Selfdestruct
		emit_signal("done")
		queue_free()
