extends Spatial

const SQRT_3 = 1.732	# Square root of three, used in reverse-ray length selection

onready var salvoGenerator = $SalvoGenerator
onready var screenShaker = get_node("CameraAnchor/Camera/ScreenShaker")
onready var cameraAnchor = get_node("CameraAnchor")
onready var diceBucketTopY = get_node("DiceBucketTop").global_transform.origin.y
onready var salvoStopHeight = get_node("SalvoStopHeightTrigger").global_transform.origin.y
onready var muzzleFlashTexture = load("res://Assets/TempMuzzleFlash.png") 
onready var muzzleFlasher = get_node("MuzzleFlasher")

onready var soundPlayer = get_node("SoundPlayer")
onready var shotSoundPool = [
	load("res://Assets/Sound/Ed_Allsounds/GunshotB_01.wav"),
	load("res://Assets/Sound/Ed_Allsounds/GunshotB_02.wav"),
	load("res://Assets/Sound/Ed_Allsounds/GunshotB_03.wav")
]
onready var gunOnSoundPool = [
	load("res://Assets/Sound/Ed_Allsounds/RoundStart.wav")
]
onready var gunOffSoundPool = [
	load("res://Assets/Sound/Ed_Allsounds/RoundEnd.wav")
]
onready var goodStarSoundPool = [
	load("res://Assets/Sound/Ed_Allsounds/STAR_GOOD_01.wav"),
	load("res://Assets/Sound/Ed_Allsounds/STAR_GOOD_02.wav"),
	load("res://Assets/Sound/Ed_Allsounds/STAR_GOOD_03.wav")
]
onready var badStarSoundPool = [
	load("res://Assets/Sound/Ed_Allsounds/STAR_BAD_01.wav"),
	load("res://Assets/Sound/Ed_Allsounds/STAR_BAD_02.wav"),
	load("res://Assets/Sound/Ed_Allsounds/STAR_BAD_03.wav")
]

func playRandomSoundFromPool(var soundPool):
	soundPlayer.stream = soundPool[randi() % len(soundPool)]
	soundPlayer.play()
func playIndexedSoundFromPool(var soundPool, var index):
	soundPlayer.stream = soundPool[index]
	soundPlayer.play()

onready var splash = get_node("PlayGUI/Splash")
var afterSplashState = STATE_IDLE
func _on_Splash_Done():
	state = afterSplashState
var awaitingVictoryStar = false # whoof.
func _on_Splash_victoryStarCallback():
	if awaitingVictoryStar:
		awaitingVictoryStar = false
		
		# Create victory star
		var victoryStarTarget = GUI.getPlayerStarPosition(playerGameScore) if setVictor == 0 else GUI.getFoeStarPosition(foeGameScore)
		var victoryStar = VictoryStar.new(get_viewport().size / 2, victoryStarTarget, setVictor)
		add_child(victoryStar)
		victoryStar.connect("done", self, "_on_victoryStar_done")
		if setVictor == 0:
			victoryStar.connect("done", GUI, "illuminatePlayerStar", [playerGameScore])
		else:
			victoryStar.connect("done", GUI, "illuminateFoeStar", [foeGameScore])
		playIndexedSoundFromPool(goodStarSoundPool if setVictor == 0 else badStarSoundPool, min(playerGameScore if setVictor == 0 else foeGameScore, 2))


onready var GUI = get_node("PlayGUI")
var guiTotUpDone = false
func _on_GUI_TotUpDone():
	guiTotUpDone = true

var scoreDisplay
var scoreDisplayDone = false
func _on_scoreDisplay_displayDone():
	scoreDisplayDone = true
static func sortForDisplay(var a, var b):
	return a.global_transform.origin.x < b.global_transform.origin.x
static func sortByHeight(var a, var b):
	return a.global_transform.origin.y > b.global_transform.origin.y

var setResultDisplayDone = false
func _on_victoryStar_done():
	setResultDisplayDone = true


onready var crosshairLiveTexture = load("res://Assets/crosshairs.png")
onready var crosshairDeadTexture = load("res://Assets/crosshairs_inactive.png")
var crosshairsAlive = true setget setCrosshairLive
func setCrosshairLive(var _newAlive):
	crosshairsAlive = _newAlive
	if _newAlive:
		Input.set_custom_mouse_cursor(crosshairLiveTexture, Input.CURSOR_ARROW, Vector2(42, 42))
		playRandomSoundFromPool(gunOnSoundPool)
	else:
		Input.set_custom_mouse_cursor(crosshairDeadTexture, Input.CURSOR_ARROW, Vector2(42, 42))
		playRandomSoundFromPool(gunOffSoundPool)



# ========== GAME STATE ==========

const BEST_OF_N = 5
const ROUNDS_PER_SET = 3		# Last round is the enemy's round

var playerSetScore = 0	# Total value of points for all rounds so far in this set
var playerGameScore = 0	# Number of sets won
var foeSetScore = 0
var foeGameScore = 0
var roundNumber = 0
var setNumber = 0

var samplePlayerSalvo
var sampleFoeSalvo

func _ready():
	randomize()
	
	# Initialize scoreDisplayer
	scoreDisplay = ScoreDisplay.new()
	add_child(scoreDisplay)
	scoreDisplay.connect("displayDone", self, "_on_scoreDisplay_displayDone")
	GUI.connect("doneTottingScore", self, "_on_GUI_TotUpDone")
	
	# Hook up splash text callback (TODO: this pattern is repeated THREE TIMES NOW.)
	# Make yer own state machine system when dust settles.
	splash.connect("done", self, "_on_Splash_Done")
	splash.connect("victoryStarCallback", self, "_on_Splash_victoryStarCallback")
	
	GUI.prepGame(BEST_OF_N)
	
	afterSplashState = STATE_START_LAUNCH
	splash.showText("Shoot the dice", "Make your own luck!", 2.0)



# ========== CAMERA CONTROLS ==========

const CAMERA_PITCH_DOWN_TIME = 0.8
const CAMERA_PITCH_UP_TIME = 0.5
const CAMERA_DIETRACK_SPEED = 6.0
# The below should really be pitch angles but what the heck
const CAMERA_TARGET_STAGE = Vector3(0.0, 28.7, -200.0)
const CAMERA_TARGET_BUCKET = Vector3(0.0, 0.0, 0.0)


# ========== MUZZLE FLASH ==========

func _on_MuzzleFlasher_tween_completed(object, key):
	object.queue_free()

func muzzleFlash(var position : Vector2):
	var flasher = Sprite.new()
	add_child(flasher)
	flasher.texture = muzzleFlashTexture
	flasher.hframes = 4
	flasher.global_position = position
	muzzleFlasher.interpolate_property(flasher, "frame", 0, 4, 0.1, Tween.TRANS_LINEAR, Tween.EASE_IN)
	muzzleFlasher.resume_all()

# ========== STATE MACHINE ==========

enum {
	STATE_IDLE,				# Dumping state for extra-loop state controllers
	STATE_LOOKING_UP,		# Camera is tracking to play orientation
	STATE_START_LAUNCH,		# State in which dice salvo is prepped
	STATE_LAUNCHING,			# State of launching a dice salvo, terminated by launch of last die
	STATE_AWAITING_LASTDIE,	# State of waiting for last die in salvo to pass drop-trigger
	STATE_TRACKING_LASTDIE,	# Looking at the last die
	STATE_LOOKING_DOWN,		# Camera is tracking to score view
	STATE_AWAITING_SETTLE,	# Waiting for dice to become still in tray
	STATE_SHOWING_SCORE,		# Displaying score, activated once all dice are still
	STATE_AWAITING_GUI,		# Waiting for GUI to tot up set score (Christ, the states are bloated!)
	STATE_DISPLAYING_SET_VICTORY,	# Displaying the winner of a set
	STATE_AWAITING_VICTORY_STAR,		# Waiting for victory star for set to do its animation
	STATE_TERMINAL,			# State reached once game is won or lost, after splash reports the fact.
}
var state = STATE_IDLE

const AWAITING_SETTLE_TIMEOUT = 10.0	# How long the state machine is willing to wait for
									# dice to settle before calling a halt
const AWAITING_LASTDIE_TIMEOUT = 10.0	# Ditto for the last die falling below trigger
const TRACKING_LASTDIE_TIMEOUT = 10.0	# Ditto for direct tracking of lastide

const SPLASH_TEXT_TIME = 3.0


# ========== DICE SALVO CONTROL ==========

var liveDice = []	# The set of all dice either airborne or lying rolled.

# Launch a salvo of dice. Salvo parametrized by array, each element of which is subarray "tuple"
# as follows [Size, Start Position, Linear Velocity, Angular Velocity, Delay until next launch]
# Launching performed by physics tick.
var salvo = []
var currentSalvoMember
func launchDiceSalvo(var _salvo : Array):
	salvo = _salvo.duplicate(true)	# Deep copy
	currentSalvoMember = 0
	state = STATE_LAUNCHING
	stateTimer = 0
	setCrosshairLive(true)

# Clears up all dice on the board
func clearUpDice():
	for die in liveDice:
		die.queue_free()
	liveDice.clear()


# ========== PHYSICS TICK (most state logic handled here) ==========

# Housekeeping data
var wasPressed = false	# Flag variable for firing
var stateTimer = 0.0		# Delay variable for salvo, timeout for settle, interpolator kickout, etc.
var cameraTarget = Vector3.ZERO	# global position to which camera is tracking
var CAMERA_PITCH_DOWN_SPEED = 1.0 / CAMERA_PITCH_DOWN_TIME
var CAMERA_PITCH_UP_SPEED = 1.0 / CAMERA_PITCH_UP_TIME
var totalInterpolation = 0	# Housekeeping variable for interpolation percentage
var lastDie = null	# object ref for last die in salvo
var obtainedScore	# storage for score won by roll, whether foe or player
var setVictor		# winner of set: 0 is player, 1 is foe
var isFoeRound = false		# whether the round is a foe round
var skipLookUp = false		# whether or not we need to look up (if we skipped looking down)
var terminalInvoked = false
var bestRoll = 0


func _physics_process(delta):
	
	# Handle state machine
	match state:
		STATE_TERMINAL:
			
			# Terminal state; switch to menu scene
			if not terminalInvoked:
				terminalInvoked = true
				$Transitioner.transitionToScene("res://MenuScreen.tscn")
			
		STATE_IDLE:
			pass
		STATE_LOOKING_UP:
			stateTimer -= delta
			
			# Camera tracks up to playfield (SOME CODE REDUNDANT WITH DOWNTRACK; REFACTOR?)
			
			if stateTimer <= 0:
				cameraAnchor.global_transform = cameraAnchor.global_transform.looking_at(cameraTarget, Vector3.UP).orthonormalized()
				
				# TODO: reset mode improvments/control feedback
				clearUpDice()
				isFoeRound = false
				if(roundNumber == 0):
					# Refresher text
					afterSplashState = STATE_START_LAUNCH
					splash.showText("Shoot the dice", "Make your own luck!", 1.5)
					state = STATE_IDLE
				elif(roundNumber == ROUNDS_PER_SET - 1):
					# Enemy state text
					isFoeRound = true
					afterSplashState = STATE_START_LAUNCH
					splash.showText("Opponent's Dice", "Shoot down his cheatin' dice!", 1.5)
					state = STATE_IDLE
				else:
					# Immediately go to salvo
					state = STATE_START_LAUNCH
				
			else:
				var targetTransform = cameraAnchor.global_transform.looking_at(cameraTarget, Vector3.UP)
				totalInterpolation += delta * CAMERA_PITCH_UP_SPEED
				cameraAnchor.global_transform = cameraAnchor.global_transform.interpolate_with(targetTransform, totalInterpolation)
			
		STATE_START_LAUNCH:
			
			# State in which Dice Salvo is prepped
			
			launchDiceSalvo(salvoGenerator.generateSalvo(isFoeRound, playerSetScore, foeSetScore, setNumber))
			
		STATE_LAUNCHING:
			stateTimer -= delta
			
			# Launching state; decrement salvo launch timer and launch if possible
			
			if stateTimer <= 0.0:
				# Launch next die in salvo
				if currentSalvoMember >= len(salvo):
					
					state = STATE_AWAITING_LASTDIE
					stateTimer = AWAITING_LASTDIE_TIMEOUT
				else:
					var launchParams = salvo[currentSalvoMember]
					var newDie = TargetDice.new(launchParams[0], launchParams[2], launchParams[3], isFoeRound)
					newDie.transform.origin = launchParams[1]
					add_child(newDie)
					liveDice.append(newDie)
					lastDie = newDie
					stateTimer = launchParams[4]
					currentSalvoMember += 1
			
			
		STATE_AWAITING_LASTDIE:
			stateTimer -= delta
			
			# Waiting for last die to fall below trigger
			
			
			if stateTimer <= 0.0 or (lastDie and lastDie.transform.origin.y < salvoStopHeight):
				state = STATE_TRACKING_LASTDIE
				stateTimer = TRACKING_LASTDIE_TIMEOUT
				setCrosshairLive(false)
			elif (lastDie and lastDie.isDead):
				# If the last Die is dead, find most elevated extant die.
				# If it's above salvoStopHeight, it becomes our new lastDie (which puts us
				# in bucket if it's already there)
				# Otherwise, we track it.
				# If all dice are dead, ???
				var foundLivingDice = false
				# Sort live dice by y-axis height
				liveDice.sort_custom(self, "sortByHeight")
				for die in liveDice:
					if not die.isDead:
						lastDie = die
						foundLivingDice = true
						break
				if not foundLivingDice:
					# No living dice: skip lookdown
					skipLookUp = true
					guiTotUpDone = true
					afterSplashState = STATE_AWAITING_GUI
					splash.showText("Got 'em all", "Well done!", 1.0)
					state = STATE_IDLE
					setCrosshairLive(false)
				
		STATE_TRACKING_LASTDIE:
			stateTimer -= delta
			
			# Following the last die
			
			# Interpolate the x-axis rotation
			
			var lockedTarget = lastDie.global_transform.origin * Vector3(0, 1, 1)
			var xRotTransform = cameraAnchor.global_transform.looking_at(lockedTarget, Vector3.UP).orthonormalized()
			cameraAnchor.global_transform = cameraAnchor.global_transform.interpolate_with(xRotTransform, delta * CAMERA_DIETRACK_SPEED)
			
			if stateTimer <= 0.0 or (lastDie and lastDie.transform.origin.y < diceBucketTopY):
				state = STATE_LOOKING_DOWN
				cameraTarget = CAMERA_TARGET_BUCKET
				stateTimer = CAMERA_PITCH_DOWN_TIME
				totalInterpolation = 0
			
		STATE_LOOKING_DOWN:
			lastDie = null
			stateTimer -= delta
			
			# Camera tracks down to bucket
			
			if stateTimer <= 0:
				cameraAnchor.global_transform = cameraAnchor.global_transform.looking_at(cameraTarget, Vector3.UP).orthonormalized()
				
				state = STATE_AWAITING_SETTLE
				stateTimer = AWAITING_SETTLE_TIMEOUT
				
			else:
				var targetTransform = cameraAnchor.global_transform.looking_at(cameraTarget, Vector3.UP)
				totalInterpolation += delta * CAMERA_PITCH_DOWN_SPEED
				cameraAnchor.global_transform = cameraAnchor.global_transform.interpolate_with(targetTransform, totalInterpolation)
			
		STATE_AWAITING_SETTLE:
			stateTimer -= delta
			
			# Awaiting settle state; query all live dice to see if they've settled.
			
			var settled = true
			for die in liveDice:
				if not ((die.linear_velocity.length_squared() < 0.01 and die.transform.origin.y < diceBucketTopY) or die.isDead):
					settled = false
			if settled or stateTimer <= 0:
				
				scoreDisplayDone = false
				var scoresToDisplay = []
				obtainedScore = 0
				# Create secondary set of undead live die (should really have thought of our metaphors...!)
				var stillLiveDice = []
				for die in liveDice:
					if not die.isDead:
						stillLiveDice.append(die)
				# sort liveDice by x position
				stillLiveDice.sort_custom(self, "sortForDisplay")
				for die in stillLiveDice:
					var rolledValue = die.getRolledValue()
					scoresToDisplay.append([rolledValue, die.global_transform.origin])
					obtainedScore += rolledValue
				scoreDisplay.display(scoresToDisplay, stillLiveDice, isFoeRound)
				
				if isFoeRound:
					scoreDisplay.scoreTarget = GUI.getFoeScorePosition()
				else:
					scoreDisplay.scoreTarget = GUI.getPlayerScorePosition()
					if obtainedScore > bestRoll:
						bestRoll = obtainedScore
				
				state = STATE_SHOWING_SCORE
				
		STATE_SHOWING_SCORE:
			
			# State in which score-reporting animation is displayed; timing held by other object
			
			if scoreDisplayDone:
				state = STATE_AWAITING_GUI
				guiTotUpDone = false
				if isFoeRound:
					GUI.setFoeSetScore(foeSetScore, foeSetScore + obtainedScore)
					foeSetScore += obtainedScore
				else:
					GUI.setPlayerSetScore(playerSetScore, playerSetScore + obtainedScore)
					playerSetScore += obtainedScore
				
		STATE_AWAITING_GUI:
			
			# State in which GUI score tots up (potentiall other FX); timing held by other object
			
			if guiTotUpDone:
				roundNumber += 1
				# TODO ROUND INDICATOR GUI
				if roundNumber == ROUNDS_PER_SET:
					# Set is done; player with highest score wins set.
					state = STATE_DISPLAYING_SET_VICTORY
				else:
					# Move to the next round.
					state = STATE_LOOKING_UP
					stateTimer = CAMERA_PITCH_UP_TIME
					cameraTarget = CAMERA_TARGET_STAGE
					totalInterpolation = 0
			
		STATE_DISPLAYING_SET_VICTORY:
			
			# State in which victor of set is displayed
			
			# Establish victor
			setVictor = 0 if playerSetScore >= foeSetScore else 1
			
			# Increment set number here (may as well; it's only for the salvo generator)
			setNumber += 1
			
			if playerSetScore == foeSetScore:
				# Splash but no victory star
				awaitingVictoryStar = false
				afterSplashState = STATE_AWAITING_VICTORY_STAR
				splash.showText("Draw", "Even odds!", 2.0)
				setResultDisplayDone = true
				state = STATE_IDLE
				setVictor = 2
			else:
				# Victory star created by callback
				awaitingVictoryStar = true
				afterSplashState = STATE_AWAITING_VICTORY_STAR
				splash.showText("Set Lost!" if setVictor else "Set Won!", "Best of "+str(BEST_OF_N)+"!", 2.0)
				
				setResultDisplayDone = false
				state = STATE_IDLE
			
		STATE_AWAITING_VICTORY_STAR:
			
			# State in which victor of set is displayed; timing held by victory star
			
			if setResultDisplayDone:
				# Update game state with new set values
				if setVictor == 0:
					playerGameScore += 1
				elif setVictor == 1:
					foeGameScore += 1
				
				# Check set count to see if best-of has been attained yet
				if playerGameScore >= (BEST_OF_N + 1) / 2:
					# Player wins game!
					afterSplashState = STATE_TERMINAL
					state = STATE_IDLE
					splash.showText("YOU WIN", "Your best roll: " + str(bestRoll), 4.0)
					soundPlayer.stop()
					$FadeSoundOut.interpolate_property($BackgroundMusic, "volume_db", null, -60, 2.0, Tween.TRANS_QUAD, Tween.EASE_IN)
					$FadeSoundOut.start()
					soundPlayer.stream = load("res://Assets/Sound/Ed_Allsounds/YouWin.wav")
					soundPlayer.play()
				elif foeGameScore >= (BEST_OF_N + 1) / 2:
					# Foe wins game!
					afterSplashState = STATE_TERMINAL
					state = STATE_IDLE
					splash.showText("YOU LOSE", "Better luck next time?", 3.0)
					soundPlayer.stop()
					$FadeSoundOut.interpolate_property($BackgroundMusic, "volume_db", null, -60, 2.0, Tween.TRANS_QUAD, Tween.EASE_IN)
					$FadeSoundOut.start()
					soundPlayer.stream = load("res://Assets/Sound/Ed_Allsounds/YouLose.wav")
					soundPlayer.play()
				else:
					# If no game victor yet, move to next set.
					roundNumber = 0
					playerSetScore = 0
					foeSetScore = 0
					GUI.setPlayerSetScoreInstant(0)
					GUI.setFoeSetScoreInstant(0)
					
					state = STATE_LOOKING_UP
					stateTimer = CAMERA_PITCH_UP_TIME
					cameraTarget = CAMERA_TARGET_STAGE
					totalInterpolation = 0
					if skipLookUp:
						skipLookUp = false
						stateTimer = 0	# Some of that setup reaaally should be elsewhere!
	
	
	
	# Handle player input
	if Input.is_mouse_button_pressed(BUTTON_LEFT) and crosshairsAlive:
		if not wasPressed:
			wasPressed = true	# TODO replace with fire delay
			
			# FIRE!
			
			playRandomSoundFromPool(shotSoundPool)
			
			
			var camera = get_viewport().get_camera()				# Obtain current camera
			var space_state = get_world().direct_space_state		# Obtain handle into the Physics Engine (for arbitrary ray query)
			
			var mouse_screen_pos = get_viewport().get_mouse_position()	# The mouse's position on the 2D screen
			muzzleFlash(mouse_screen_pos)
			screenShaker.shake()
			
			# ...the camera helpfully projects this into a 3D worldspace coordinate...
			var mouse_ray_origin = camera.project_ray_origin(mouse_screen_pos)
			
			# ...and it'll do the same for the direction, which we can scale out to create a ray
			var mouse_ray_end = mouse_ray_origin + camera.project_ray_normal(mouse_screen_pos) * 200
			
			# Launch a ray along this path, and see if it hits anything
			# The weird params are due to the fact that Godot doesn't yet allow keyword args like Python, so we have to manually
			# specify intermediate args on our way to clarify that we DO want body collisons but we DON'T want area collisions
			# Collision Masked to level 1 only; only things on level 1 are the target dice.
			var mouse_ray_intersection = space_state.intersect_ray(mouse_ray_origin, mouse_ray_end, [], 1, true, false)
			
			if not mouse_ray_intersection.empty():
				# We've struck a die; collision is bullet's entry point.
				var entry_point = mouse_ray_intersection.position
				
				# Compute exit point with a backwards raycast. This MAYBE isn't safe if two dice
				# overlap on the gun axis. (TODO: FIX WITH GEOMETRIC SOL'N)
				# Improvement with reverse sphere, though it becomes a param.
				# OR have some jiggery-pokery with the collision layers.
				#if mouse_ray_intersection.collider.get_script.has_variable("size"):
				# We're just going to unsafely assume everything hittable has size variable
				var reverse_ray_length = SQRT_3 * mouse_ray_intersection.collider.size + 0.1
				
				var exit_ray_end = entry_point + camera.project_ray_normal(mouse_screen_pos) * 0.01
				var exit_ray_start = entry_point + camera.project_ray_normal(mouse_screen_pos) * reverse_ray_length
				var exit_ray_intersection = space_state.intersect_ray(exit_ray_start, exit_ray_end, [], 1, true, false)
				var exit_point = Vector3.ZERO
				if not exit_ray_intersection.empty():
					exit_point = exit_ray_intersection.position
				
				if mouse_ray_intersection.collider.has_method("plug"):
					mouse_ray_intersection.collider.plug(entry_point, exit_point)
	else:
		wasPressed = false
