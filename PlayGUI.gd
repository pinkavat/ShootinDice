extends Control

# PlayGUI.gd
#
#	Accessor functions for the overhead score and round display, so that
#	we can deal with Godot's bizarre GUI system cleanly (Testworld is already
#	doing too much of the heavy lifting)

signal doneTottingScore	# emitted when the score counter is done totting up

const SCORE_UPDATE_TIME = 0.5
const SICK_OF_GODOT_UI_BULLSHIT_VALUE = Vector2(0, -5.0)

onready var blueStarTexture = load("res://Assets/StarBlue.png")
onready var redStarTexture = load("res://Assets/StarRed.png")
onready var blankStarTexture = load("res://Assets/StarBlank.png")

onready var leftStarHolder = get_node("HBoxContainer/LeftStars")
onready var rightStarHolder = get_node("HBoxContainer/RightStars")

onready var playerScoreLabel = get_node("HBoxContainer/Center/ScoreLabelCenterer/PlayerScoreLabel")
onready var foeScoreLabel = get_node("HBoxContainer/Center/ScoreLabelCenterer/FoeScoreLabel")

var tween : Tween
func _ready():
	tween = Tween.new()
	tween.connect("tween_all_completed", self, "_tween_all_completed")
	add_child(tween)


# Called to perform setup of a blank, new game, best-of-n.
# Could in theory reset an existing gamestate, but it's probably better to create a new scene per game
func prepGame(var bestOfN):
	
	# Create n empty stars in each player's set victory counter
	for node in leftStarHolder.get_children():
		node.queue_free()
	for i in range(bestOfN):
		var newStar = TextureRect.new()
		newStar.texture = blankStarTexture
		leftStarHolder.add_child(newStar)
	
	for node in rightStarHolder.get_children():
		node.queue_free()
	for i in range(bestOfN):
		var newStar = TextureRect.new()
		newStar.texture = blankStarTexture
		rightStarHolder.add_child(newStar)
	
	# Reset the round score counter
	setPlayerSetScoreInstant(0)
	setFoeSetScoreInstant(0)



# ========== SCORE LABEL ANIMATION ==========

# Signal callback from interpolation tween
func _tween_all_completed():
	emit_signal("doneTottingScore")

# Sets the set score to the new values, with animation.
func setPlayerSetScore(var oldPlayerScore : int, var newPlayerScore : int):
	tween.interpolate_method(self, "setPlayerSetScoreInstant", oldPlayerScore, newPlayerScore, SCORE_UPDATE_TIME, Tween.TRANS_LINEAR, Tween.EASE_IN)
	tween.start()

func setFoeSetScore(var oldFoeScore: int, var newFoeScore : int):
	tween.interpolate_method(self, "setFoeSetScoreInstant", oldFoeScore, newFoeScore, SCORE_UPDATE_TIME, Tween.TRANS_LINEAR, Tween.EASE_IN)
	tween.start()

func setPlayerSetScoreInstant(var playerScore : int):
	playerScoreLabel.text = str(playerScore)

func setFoeSetScoreInstant(var foeScore : int):
	foeScoreLabel.text = str(foeScore)


# ========== SET VICTORY STARS ==========

func illuminatePlayerStar(var starIndex : int):
	if starIndex >= leftStarHolder.get_child_count():
		return
	leftStarHolder.get_children()[starIndex].texture = blueStarTexture

func illuminateFoeStar(var starIndex : int):
	if starIndex >= rightStarHolder.get_child_count():
		return
	rightStarHolder.get_children()[rightStarHolder.get_child_count() - 1 - starIndex].texture = redStarTexture


# ========== SCREEN POSITION ACCESSORS ==========

func getPlayerScorePosition():
	return playerScoreLabel.rect_global_position + (playerScoreLabel.rect_size / 2)

func getFoeScorePosition():
	return foeScoreLabel.rect_global_position + (foeScoreLabel.rect_size / 2)

func getPlayerStarPosition(var starIndex : int):
	if starIndex >= leftStarHolder.get_child_count():
		return Vector2.ZERO
	var star = leftStarHolder.get_children()[starIndex]
	return star.rect_global_position + (star.rect_size / 2) + SICK_OF_GODOT_UI_BULLSHIT_VALUE

func getFoeStarPosition(var starIndex : int):
	if starIndex >= rightStarHolder.get_child_count():
		return Vector2.ZERO
	var star = rightStarHolder.get_children()[rightStarHolder.get_child_count() - 1 - starIndex]
	return star.rect_global_position + (star.rect_size / 2) + SICK_OF_GODOT_UI_BULLSHIT_VALUE
