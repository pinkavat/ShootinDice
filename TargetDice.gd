extends RigidBody

class_name TargetDice

# TargetDice.gd
#
#	RigidBody Cube that is "thrown" along an arc, then "plugged" with shots by the player.
#	Shots become bullet holes in the cube, which is then rolled like a die to produce a score.
const HOLE_RADIUS = 0.2
var holeMesh
var holePulseTween

var size
var isEnemy
var isDead

const DEATH_THROE_TARGET = Vector3(24, 42, -50)

# ========== SOUNDS ==========
# Hit by bullet
# Pwinged off
# Whooshed up
# Contact sound
var soundPlayer
var collisionSoundPool
var launchSoundPool
var throughShotSoundPool
var pwingShotSoundPool
func playSoundFromPool(var soundPool):
	soundPlayer.stream = soundPool[randi() % len(soundPool)]
	soundPlayer.play()

# Number of bullet holes per face.
# Faces are ordered as follows:
# +X, +Y, +Z, -X, -Y, -Z
var holes = [0, 0, 0, 0, 0, 0]

# Lookup table for constant values of Enemy Dice, in same order
const foeHoles = [1, 5, 4, 6, 2, 3]

# Bullet hole mesh refs, in same order (prob redun but hey, jam!)
var holeMeshes = [[],[],[],[],[],[]]


func _init(var _size : float, var motion : Vector3, var angularMotion : Vector3, var _isEnemy : bool = false):
	isEnemy = _isEnemy
	isDead = false
	size = _size
	var collider = CollisionShape.new()
	collider.shape = BoxShape.new()
	collider.shape.extents = Vector3(size, size, size) / 2
	add_child(collider)
	
	contact_monitor = true
	contacts_reported = 1
	connect("body_entered", self, "_on_body_entered")
	
	apply_central_impulse(motion)
	apply_torque_impulse(angularMotion)
	
	gravity_scale = 1.0
	# TODO: global static phys for dice, perhaps
	var physicsMat = PhysicsMaterial.new()
	physicsMat.friction = 1.0
	physicsMat.rough = true
	physics_material_override = physicsMat
	
	var meshInst = MeshInstance.new()
	
	meshInst.scale_object_local(Vector3(size, size, size))
	
	if isEnemy:
		meshInst.mesh = load("res://Assets/EnemyDice/EnemyDieMesh.tres")
		meshInst.scale_object_local(Vector3(0.5, 0.5, 0.5))
	else:
		meshInst.mesh = load("res://Assets/DieMesh.tres")
		meshInst.set_surface_material(0, load("res://Assets/DieMaterial.material"))
	add_child(meshInst)
	
	soundPlayer = AudioStreamPlayer.new()
	add_child(soundPlayer)
	collisionSoundPool = [
		load("res://Assets/Sound/Ed_Allsounds/Dice_Collide_01.wav"),
		load("res://Assets/Sound/Ed_Allsounds/Dice_Collide_02.wav"),
		load("res://Assets/Sound/Ed_Allsounds/Dice_Collide_03.wav")
	]
	launchSoundPool = [
		load("res://Assets/Sound/Ed_Allsounds/Dice_Throw_01.wav"),
		load("res://Assets/Sound/Ed_Allsounds/Dice_Throw_02.wav"),
		load("res://Assets/Sound/Ed_Allsounds/Dice_Throw_03.wav"),
		load("res://Assets/Sound/Ed_Allsounds/Dice_Throw_04.wav"),
		load("res://Assets/Sound/Ed_Allsounds/Dice_Throw_05.wav")
	]
	throughShotSoundPool = [
		load("res://Assets/Sound/Ed_Allsounds/Dice_ShotHole_01.wav"),
		load("res://Assets/Sound/Ed_Allsounds/Dice_ShotHole_02.wav"),
		load("res://Assets/Sound/Ed_Allsounds/Dice_ShotHole_03.wav"),
		load("res://Assets/Sound/Ed_Allsounds/Dice_ShotHole_04.wav"),
		load("res://Assets/Sound/Ed_Allsounds/Dice_ShotHole_05.wav"),
		load("res://Assets/Sound/Ed_Allsounds/Dice_ShotHole_06.wav")
	]
	pwingShotSoundPool = [
		load("res://Assets/Sound/Ed_Allsounds/Dice_ShotAway_01.wav"),
		load("res://Assets/Sound/Ed_Allsounds/Dice_ShotAway_02.wav"),
		load("res://Assets/Sound/Ed_Allsounds/Dice_ShotAway_03.wav"),
		load("res://Assets/Sound/Ed_Allsounds/Dice_ShotAway_04.wav")
	]
	
	var holeMaterial = SpatialMaterial.new()
	holeMaterial.albedo_texture = load("res://Assets/TempHoleTexture.png")
	holeMaterial.flags_transparent = true
	holeMesh = QuadMesh.new()
	holeMesh.size = Vector2(HOLE_RADIUS, HOLE_RADIUS) * 2
	holeMesh.surface_set_material(0, holeMaterial)
	
	holePulseTween = Tween.new()
	add_child(holePulseTween)


func _ready():
	playSoundFromPool(launchSoundPool)


# Signal callback for collision
func _on_body_entered(var body):
	#var relativeVelocity = linear_velocity.length_squared() 	#TODO idea
	#soundPlayer.pitch_scale = relativeVelocity / 20.0
	
	# Hideously overengineered, but hey.
	var camera = get_viewport().get_camera()
	var cameraToObject = global_transform.origin - camera.global_transform.origin
	var cameraFacing = camera.global_transform.basis.z * Vector3(-1,-1,-1)
	var angleToCamera = cameraFacing.angle_to(cameraToObject)
	if linear_velocity.length_squared() > 8.0 and angleToCamera < 0.6:
		playSoundFromPool(collisionSoundPool)



# Face-clamping function for holes: repositions holes to sit comfortably within 
# indicated face. Faces are ordered as defined above.
func clampHoleToFace(var position : Vector3, var closestFace : int):
	var scaleFactor = (size - 2 * HOLE_RADIUS) / size
	# TODO prob more efficient way but what the heck.
	position.x = (sign(position.x) * (size/2)) if (closestFace == 0 or closestFace == 3) else (position.x * scaleFactor)
	position.y = (sign(position.y) * (size/2)) if (closestFace == 1 or closestFace == 4) else (position.y * scaleFactor)
	position.z = (sign(position.z) * (size/2)) if (closestFace == 2 or closestFace == 5) else (position.z * scaleFactor)
	return position


# Stopgap bad-hole prune step: if more than one dimension of hole is greater than inner cube, cull.
func isValidPoint(var position : Vector3):
	var greaters = 0
	var miniDim = (size - 2 * HOLE_RADIUS) / 2
	if abs(position.x) > miniDim:
		greaters += 1
	if abs(position.y) > miniDim:
		greaters += 1
	if abs(position.z) > miniDim:
		greaters += 1
	return false if greaters > 1 else true



# Helper function for below funcs: establishes which face a local-space point is closest to.
# Faces are ordered as defined above.
func closestFace(var point : Vector3):
	var xDot = point.dot(Vector3(1, 0, 0))
	var yDot = point.dot(Vector3(0, 1, 0))
	var zDot = point.dot(Vector3(0, 0, 1))
	
	if abs(xDot) > abs(yDot):
		if abs(xDot) > abs(zDot):
			# X
			return 0 if xDot > 0 else 3
		else:
			# Z
			return 2 if zDot > 0 else 5
	else:
		if abs(yDot) > abs(zDot):
			# Y
			return 1 if yDot > 0 else 4
		else:
			# Z
			return 2 if zDot > 0 else 5




# Helper function for plug below; makes a new quad for hole visualization
func newHoleQuad(var position : Vector3, var closestFace : int):
	var newHoleMesh = MeshInstance.new()
	newHoleMesh.mesh = holeMesh
	
	var targetAxis = [
		Vector3(-1, 0, 0),	# +X
		Vector3(0, -1, 0),	# +Y
		Vector3(0, 0, -1),	# +Z
		Vector3(1, 0, 0),	# -X
		Vector3(0, 1, 0),	# -Y
		Vector3(0, 0, 1)		# -Z
	][closestFace]	# TODO inefficient!
	newHoleMesh.look_at(targetAxis, to_local(Vector3.UP))
	newHoleMesh.transform.origin = position + (newHoleMesh.transform.basis.z * 0.01)
	
	return newHoleMesh



# Callback for getting shot; invoked by whatever is handling mouse ray
# Coordinates are reported in global space
func plug(var entryPoint : Vector3, var exitPoint : Vector3):
	if isEnemy:
		# Enemy Die, bullet destroys die...
		playSoundFromPool(pwingShotSoundPool)
		isDead = true
		collision_layer = 0
		collision_mask = 0
		
		# ...and whacks it out of the park
		#apply_central_impulse( * Vector3(-1, -1, -1) * Vector3(20, 20, 20))
		gravity_scale = 0.0
		#apply_central_impulse((global_transform.origin - get_viewport().get_camera().global_transform.origin).normalized() * Vector3(30, 50, 60))
		var deathTarget = DEATH_THROE_TARGET
		deathTarget.x = rand_range(0 - DEATH_THROE_TARGET.x, DEATH_THROE_TARGET.x)
		apply_central_impulse((deathTarget - global_transform.origin).normalized() * Vector3(100, 200, 100))
		apply_impulse(to_local(entryPoint), (entryPoint - get_viewport().get_camera().global_transform.origin).normalized() * Vector3(30, 30, 30))
	else:
		# Friendly Die, bullet goes through
		playSoundFromPool(throughShotSoundPool)
		
		entryPoint = to_local(entryPoint)
		exitPoint = to_local(exitPoint)
		
		# Correct the hole positions to sit them unambiguously within a face
		var entryClosestFace = closestFace(entryPoint)
		entryPoint = clampHoleToFace(entryPoint, entryClosestFace)
		
		var exitClosestFace = closestFace(exitPoint)
		exitPoint = clampHoleToFace(exitPoint, exitClosestFace)
		
		# Emergency culling step for holes lying outside the die
		var entryValid = isValidPoint(entryPoint)
		var exitValid = isValidPoint(exitPoint)
		
		# Add the holes to each face's score
		if entryValid:
			holes[entryClosestFace] += 1
			var newHoleMesh = newHoleQuad(entryPoint, entryClosestFace)
			add_child(newHoleMesh)
			holeMeshes[entryClosestFace].append(newHoleMesh)
		if exitValid:
			holes[exitClosestFace] += 1
			var newHoleMesh = newHoleQuad(exitPoint, exitClosestFace)
			add_child(newHoleMesh)
			holeMeshes[exitClosestFace].append(newHoleMesh)



# Returns the number of holes on the upper die face
func getRolledValue():
	if isEnemy:
		return foeHoles[closestFace(to_local(global_transform.origin + Vector3.UP))]
	else:
		return holes[closestFace(to_local(global_transform.origin + Vector3.UP))]

# Animates a flash of the dots on the upper face for the given number of seconds
func pulseDots(var time):
	for hole in holeMeshes[closestFace(to_local(global_transform.origin + Vector3.UP))]:
		holePulseTween.interpolate_property(hole, "scale", Vector3.ONE, Vector3.ZERO, time, Tween.TRANS_BACK, Tween.EASE_OUT)
	#holePulseTween.start()
