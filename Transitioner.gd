extends ColorRect

var tween
var newScenePath

const SCROLL_IN_TIME = 0.5
const SCROLL_OUT_TIME = 0.5

var mode = 0
func _ready():
	show()
	tween = $Tween
	tween.interpolate_property(self, "anchor_left", 0.0, 1.0, SCROLL_IN_TIME, Tween.TRANS_QUAD, Tween.EASE_IN)
	tween.start()
	mode = 0


func transitionToScene(var scenePath):
	newScenePath = scenePath
	mode = 1
	show()
	anchor_right = 0.0
	tween.interpolate_property(self, "anchor_right", 0.0, 1.0, SCROLL_OUT_TIME, Tween.TRANS_QUAD, Tween.EASE_IN)
	tween.start()

func _on_Tween_tween_all_completed():
	if mode == 1:
		# Change scene
		get_tree().change_scene(newScenePath)
	else:
		# Hide
		hide()
		anchor_left = 0.0
