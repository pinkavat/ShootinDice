extends Node

# SalvoGenerator.gd
# 
#	Generates a dice salvo based on some parameters
#	TODO what parameters

const EXPECTED_FOE_SHOTAWAY = 3

onready var diceGunCenter = $DiceGunCenter

func randomLaunchPosition():
	return Vector3(rand_range(-5.0, 5.0), 0, 0) + diceGunCenter.global_transform.origin

const LAUNCH_FIELD_WIDTH = 15.0
var launchLateralVariation = 3.0
func distributeLaunchPositions(var numPositions):
	var step = LAUNCH_FIELD_WIDTH / numPositions
	var position = Vector3((0 - (LAUNCH_FIELD_WIDTH / 2)) + (step / 2), 0, 0) + diceGunCenter.global_transform.origin
	var launchPositions = []
	for i in range(numPositions):
		launchPositions.append(position)
		position = position + Vector3(step, 0, 0)
	launchLateralVariation = step / 2
	return launchPositions

func randomLinearVelocity():
	return Vector3(rand_range(-0.5, 0.5), rand_range(15.5, 18), 4)

func randomAngularVelocity():
	return Vector3(rand_range(0.5, 1.5), rand_range(0.5, 2), 0)

# Param type: 0 if player salvo, 1 if foe salvo
func generateSalvo(var type : int, var playerSetScore : int, var foeSetScore, var setNumber):
	var salvo = []
	
	if type:
		# Foe Salvo
		var foeDiceCount = max(2, playerSetScore / 3) + EXPECTED_FOE_SHOTAWAY + setNumber
		print("Launching ", foeDiceCount, " playerscore: ", playerSetScore, " set: ", setNumber)
		var launchPositions = distributeLaunchPositions(6)
		launchPositions.shuffle()
		for i in range(foeDiceCount):
			salvo.append([1, launchPositions[i % len(launchPositions)] + Vector3(rand_range(0 - launchLateralVariation, launchLateralVariation), 0, 0) * 2.0, randomLinearVelocity(), randomAngularVelocity(), rand_range(0.0, 0.4)])
	else:
		# Player Salvo
		var launchPositions = distributeLaunchPositions(3)
		launchPositions.shuffle()
		for i in range(3):
			salvo.append([2, launchPositions[i % len(launchPositions)] + Vector3(rand_range(0 - launchLateralVariation, launchLateralVariation), 0, 0), randomLinearVelocity(), randomAngularVelocity(), 1.0])
		
	return salvo
	
#	var samplePlayerSalvo = []
#	var launchPositions = distributeLaunchPositions(3)
#	for i in range(3):
#		samplePlayerSalvo.append([2, launchPositions[i % len(launchPositions)] + Vector3(rand_range(0 - launchLateralVariation, launchLateralVariation), 0, 0), randomLinearVelocity(), randomAngularVelocity(), 1.0])
#
#	var sampleFoeSalvo = []
#	for i in range(6):
#		sampleFoeSalvo.append([1, launchPositions[i % len(launchPositions)] + Vector3(rand_range(0 - launchLateralVariation, launchLateralVariation), 0, 0) * 2.0, randomLinearVelocity(), randomAngularVelocity(), rand_range(0.0, 0.3)])
#
#
#	return sampleFoeSalvo if type else samplePlayerSalvo
