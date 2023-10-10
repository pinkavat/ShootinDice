extends Node

# ScreenShaker.gd
#
#	Modification of old screenshaker code for use in 3D

const TRANS = Tween.TRANS_SINE
const EASE = Tween.EASE_OUT_IN

var totalTimer : Timer
var subTimer : Timer
var interpolator : Tween
onready var camera = get_parent()

var magnitude = 0

func shake(duration = 0.05, count = 5, _magnitude = 0.5):
	if _magnitude >= self.magnitude:
		# Large shakes dominate small ones
		self.magnitude = _magnitude

		totalTimer.wait_time = duration
		totalTimer.start()
		subTimer.wait_time = 1 / float(count)
		subTimer.start()

		_subshake()




func _subshake():
	var shakeDest = Vector3(rand_range(-magnitude, magnitude), rand_range(-magnitude, magnitude), 0) + camera.transform.origin
	interpolator.interpolate_property(camera, "transform:origin", camera.transform.origin, shakeDest, subTimer.wait_time, TRANS, EASE)
	interpolator.start()


func _stopShake():
	subTimer.stop()
	magnitude = 0
	
	# Reset the camera
	interpolator.interpolate_property(camera, "transform:origin", camera.transform.origin, Vector3.ZERO, subTimer.wait_time, TRANS, EASE)
	interpolator.start()


func _on_subTimer_timeout():
	_subshake()

func _on_totalTimer_timeout():
	_stopShake()

func _ready():
	# Set up shake timers and interpolation tween
	totalTimer = Timer.new()
	totalTimer.connect("timeout", self, "_on_totalTimer_timeout")
	add_child(totalTimer)
	subTimer = Timer.new()
	subTimer.connect("timeout", self, "_on_subTimer_timeout")
	add_child(subTimer)
	interpolator = Tween.new()
	add_child(interpolator)
