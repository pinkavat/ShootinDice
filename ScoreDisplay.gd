extends Node2D

class_name ScoreDisplay

# ScoreDisplay.gd
#
#	Faculty for displaying the result of the dice roll, as 2D projection.
#	Concept is to be a bit Wii-Sports-ish, with "slam" sounds and kinetic numbercrunch.
#
#	Use: instantiate, then invoke "display" method.
#	Node will emit signal when display is complete.
signal displayDone


# Control handles
const TIME_BETWEEN_SCORE_LAUNCHES = 0.3	# same as interp., time bug.
const TIME_FOR_SCORE_INTERPOLATION = 0.3
const DOT_PULSE_DELAY = 0.2
const TIME_SMALL_SCORE_HOLD = 0.1
const TIME_FOR_SCORE_COLLATION = 0.5
const TIME_LARGE_SCORE_HOLD = 0.3
const TIME_LARGE_SCORE_MOVE = 0.3

# State machine
enum {
	STATE_IDLE,
	STATE_DISPLAYING_SMALL_SCORES,
	STATE_COLLATING_SCORES,
	STATE_SHOWING_LARGE_SCORE,
	STATE_HOLDING_LARGE_SCORE,
	STATE_MOVING_LARGE_SCORE,
	STATE_POST
	}
var state = STATE_IDLE

var tween : Tween
var hitTimer : Timer
var soundPlayer
var superHitPlayer
var goodHitPool = [
	load("res://Assets/Sound/Ed_Allsounds/SumScales/DiceSumGood_01.wav"),
	load("res://Assets/Sound/Ed_Allsounds/SumScales/DiceSumGood_02.wav"),
	load("res://Assets/Sound/Ed_Allsounds/SumScales/DiceSumGood_03.wav"),
	load("res://Assets/Sound/Ed_Allsounds/SumScales/DiceSumGood_04.wav"),
	load("res://Assets/Sound/Ed_Allsounds/SumScales/DiceSumGood_05.wav"),
	load("res://Assets/Sound/Ed_Allsounds/SumScales/DiceSumGood_06.wav"),
	load("res://Assets/Sound/Ed_Allsounds/SumScales/DiceSumGood_07.wav"),
	load("res://Assets/Sound/Ed_Allsounds/SumScales/DiceSumGood_08.wav")
]
var goodHitIndex = 0
func playHit():
	soundPlayer.stream = goodHitPool[goodHitIndex]
	goodHitIndex = min(goodHitIndex + 1, len(goodHitPool) - 1)
	soundPlayer.play()
	
var screenCenter
var scoreSprites = []
var dice = []		# In same order as scores, naturally (TODO semiredundant but ah well; Game jam!)
var scoreLabelTheme
var mainScore
var type

var scoreTarget = Vector2.ZERO	# Main score will be moved here; externally set to player pos or foe pos

func _ready():
	hitTimer = Timer.new()
	add_child(hitTimer)
	hitTimer.one_shot = false
	hitTimer.wait_time = TIME_FOR_SCORE_INTERPOLATION
	hitTimer.connect("timeout", self, "_on_hitTimer_timeout")
	
	tween = Tween.new()
	add_child(tween)
	
	soundPlayer = AudioStreamPlayer.new()
	add_child(soundPlayer)
	superHitPlayer = AudioStreamPlayer.new()
	add_child(superHitPlayer)
	
	scoreLabelTheme = load("res://ScoreLabelTheme.tres")

func _on_hitTimer_timeout():
	playHit()

# TODO: emit callback that makes dice dots "pulse" (polish)

# Display function: plays the score-displaying animation.
# Parameter is a list of scores to display (one per die), as sublist tuples.
# First element of tuple is score, second element is 3D global position.
# Other parameter is zero for player, 1 for foe (used in sound calc)
func display(var scores : Array, var _dice : Array, var _type : int):
	type = _type
	goodHitIndex = 0
	dice = _dice
	var camera = get_viewport().get_camera()
	screenCenter = Vector2.ZERO
	var totalScore = 0
	for score in scores:
		var newNumber = Node2D.new()
		var newNumberLabel = Label.new()
		newNumberLabel.theme = scoreLabelTheme
		newNumberLabel.text = str(score[0])
		newNumber.add_child(newNumberLabel)
		newNumberLabel.rect_global_position = newNumberLabel.get_minimum_size() / -2
		newNumber.global_position = camera.unproject_position(score[1])
		newNumber.scale = Vector2.ZERO
		screenCenter += newNumber.global_position
		scoreSprites.append(newNumber)
		add_child(newNumber)
		totalScore += score[0]
	screenCenter /= len(scores)
	
	mainScore = Node2D.new()
	var mainScoreLabel = Label.new()
	mainScoreLabel.theme = scoreLabelTheme
	mainScoreLabel.text = str(totalScore)
	mainScoreLabel.rect_global_position = mainScoreLabel.get_minimum_size() / -2
	mainScore.global_position = screenCenter
	mainScore.scale = Vector2.ZERO
	mainScore.add_child(mainScoreLabel)
	add_child(mainScore)
	
	# Emit multiple tween signals
	currentIndex = 0
	state = STATE_DISPLAYING_SMALL_SCORES
	hitTimer.start()



var timeUntilNext = 0.0
var currentIndex = 0
func _process(delta):
	timeUntilNext -= delta
	
	if timeUntilNext <= 0:
		match state:
			STATE_DISPLAYING_SMALL_SCORES:
				if currentIndex >= len(scoreSprites):
					hitTimer.stop()
					state = STATE_COLLATING_SCORES
					currentIndex = 0
					timeUntilNext = TIME_SMALL_SCORE_HOLD
				else:
					tween.interpolate_property(scoreSprites[currentIndex], "scale", Vector2.ZERO, Vector2(0.5, 0.5), TIME_FOR_SCORE_INTERPOLATION, Tween.TRANS_BACK, Tween.EASE_OUT, DOT_PULSE_DELAY)
					tween.resume_all()
					# assume dice array is of dice, no safeties
					dice[currentIndex].pulseDots(DOT_PULSE_DELAY + TIME_FOR_SCORE_INTERPOLATION / 2)
					currentIndex += 1
					timeUntilNext = TIME_BETWEEN_SCORE_LAUNCHES
					
			STATE_COLLATING_SCORES:
				for scoreSprite in scoreSprites:
					tween.interpolate_property(scoreSprite, "global_position", scoreSprite.global_position, screenCenter, TIME_FOR_SCORE_COLLATION, Tween.TRANS_QUAD, Tween.EASE_IN)
					tween.resume_all()
				timeUntilNext = TIME_FOR_SCORE_COLLATION
				state = STATE_SHOWING_LARGE_SCORE
				superHitPlayer.stream = load("res://Assets/Sound/Ed_Allsounds/SumScales/DiceSumBad_FULLHIT.wav") if type else load("res://Assets/Sound/Ed_Allsounds/SumScales/DiceSumGood_FULLHIT.wav")
				superHitPlayer.play()
			STATE_SHOWING_LARGE_SCORE:
				tween.interpolate_property(mainScore, "scale", Vector2.ZERO, Vector2(1, 1), TIME_FOR_SCORE_INTERPOLATION, Tween.TRANS_BACK, Tween.EASE_OUT)
				tween.resume_all()
				timeUntilNext = TIME_FOR_SCORE_INTERPOLATION
				for scoreSprite in scoreSprites:
					scoreSprite.queue_free()
				scoreSprites.clear()
				state = STATE_HOLDING_LARGE_SCORE
			STATE_HOLDING_LARGE_SCORE:
				timeUntilNext = TIME_LARGE_SCORE_HOLD
				state = STATE_MOVING_LARGE_SCORE
			STATE_MOVING_LARGE_SCORE:
				tween.interpolate_property(mainScore, "global_position" , mainScore.global_position, scoreTarget, TIME_LARGE_SCORE_MOVE, Tween.TRANS_QUAD, Tween.EASE_IN)
				tween.interpolate_property(mainScore, "scale", mainScore.scale, Vector2(0.2, 0.2), TIME_LARGE_SCORE_MOVE, Tween.TRANS_QUAD, Tween.EASE_IN)
				tween.resume_all()
				timeUntilNext = TIME_LARGE_SCORE_MOVE
				state = STATE_POST
			STATE_POST:
				mainScore.queue_free()
				emit_signal("displayDone")
				state = STATE_IDLE
