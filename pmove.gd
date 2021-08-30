extends KinematicBody

"""
pmove.gd

- Controls player movement
- Player may still slide down slopes!
- Not yet tested with complex geometry, only simple box shapes
"""

onready var collider : CollisionShape = $CollisionShape

const MOVESPEED : float = 32.0       # default: 32.0
#const MAXSPEED : float = 32.0       # default: 32.0
const STOPSPEED : float = 10.0       # default: 10.0
const GRAVITY : float = 80.0         # default: 80.0
const ACCELERATE : float = 10.0      # default: 10.0
const AIRACCELERATE : float = 0.25   # default: 0.7
const MOVEFRICTION : float = 6.0     # default: 6.0
const JUMPFORCE : float = 27.0       # default: 27.0
const AIRCONTROL : float = 0.9       # default: 0.9
#const WALKSPEED : float = 12.0      # default: 16.0
const STEPSIZE : float = 1.8         # default: 1.8
const MAXHANG : float = 0.2          # defualt: 0.2

var deltaTime : float = 0.0
var fmove : float = 0.0
var ground_normal : Vector3 = Vector3.UP
var hangtime : float = 0.2
var is_dead : bool = false
var jump_press : bool = false
var smove : float = 0.0
var velocity : Vector3 = Vector3.ZERO

enum {GROUNDED, FALLING, LADDER, SWIMMING, NOCLIP}
var state = GROUNDED

"""
===============
_input
===============
"""
func _input(_event):
	fmove = Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward")
	smove = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	
	if Input.is_action_just_pressed("jump") and !jump_press:
		jump_press = true
	elif Input.is_action_just_released("jump"):
		jump_press = false
	

"""
===============
_physics_process
===============
"""
func _physics_process(delta):
	deltaTime = delta
	
	CategorizePosition()
	JumpButton()
	
	if state == GROUNDED:
		GroundMove()
	else:
		AirMove()
	

"""
===============
CategorizePosition
Check if the player is touching the ground
===============
"""
func CategorizePosition():
	# Check for ground 0.1 units below the player
	var down = global_transform.origin + Vector3.DOWN * 0.1
	var trace = Trace.normalfrac(global_transform.origin, down, collider.shape, self)
	
	if trace[0] == 1:
		state = FALLING
		ground_normal = Vector3.UP
	else: 
		ground_normal = trace[2]
		
		if ground_normal[1] < 0.7:
			state = FALLING # Too steep!
		else:
			global_transform.origin = trace[1] # Clamp to ground
			state = GROUNDED

"""
===============
JumpButton
===============
"""
func JumpButton():
	if is_dead: return
	
	# Allow jump for a few frames if just ran off platform
	if state != FALLING:
		hangtime = MAXHANG
	else:
		hangtime -= deltaTime if hangtime > 0.0 else 0.0
	
	if velocity[1] > 54.0: return
	
	if hangtime > 0.0 and jump_press:
		state = FALLING
		jump_press = false
		hangtime = 0.0
		
		# Make sure jump velocity is positive if falling
		if state == FALLING || velocity[1] < 0.0:
			velocity[1] = JUMPFORCE
		else:
			velocity[1] += JUMPFORCE

"""
===============
GroundMove
===============
"""
func GroundMove():
	var wishdir = transform.basis.x.slide(ground_normal) * smove + -transform.basis.z.slide(ground_normal) * fmove
	wishdir = wishdir.normalized()
	GroundAccelerate(wishdir, MOVESPEED)
	# warning-ignore:return_value_discarded
	move_and_slide(velocity, ground_normal, true, 5) 
	
	#$Label.text = str(get_slide_count())
	for i in range(get_slide_count()):
		if get_slide_collision(i).normal[1] < 0.7:
			StepMove(global_transform.origin)

"""
===============
GroundAccelerate
===============
"""
func GroundAccelerate(wishdir, wishspeed):
	
	# Friction applied after move release
	if wishdir != Vector3.ZERO:
		velocity = velocity.linear_interpolate(wishdir * wishspeed, ACCELERATE * deltaTime) 
	else:
		velocity = velocity.linear_interpolate(Vector3.ZERO, MOVEFRICTION * deltaTime) 
	
	# Don't bother with tiny velocities
	if velocity.length() < 0.1:
		velocity = Vector3.ZERO

"""
===============
StepMove
===============
"""
func StepMove(original_pos):
	# Get destination position that is one step-size above the intended move
	var dest = original_pos
	dest[0] += velocity[0] * deltaTime
	dest[1] += STEPSIZE
	dest[2] += velocity[2] * deltaTime
	
	# 1st Trace: check for collisions one stepsize above the original position
	var up = original_pos + Vector3.UP * STEPSIZE
	var trace = Trace.normal(original_pos, up, collider.shape, self)
	dest[1] = trace[0][1]
	
	# 2nd Trace: Check for collisions from the 1st trace end position
	# towards the intended destination
	trace = Trace.normal(trace[0], dest, collider.shape, self)
	
	# 3rd Trace: Check for collisions below the 2nd trace end position
	var down = Vector3(trace[0][0], original_pos[1], trace[0][2])
	trace = Trace.normal(trace[0], down, collider.shape, self)
	
	# Move to trace collision position if higher than original position and not steep 
	if trace[0][1] > original_pos[1] and trace[1][1] >= 0.7: 
		global_transform.origin = trace[0]
	
	# Slide along trace normal
	velocity = velocity.slide(trace[1])

"""
===============
AirMove
===============
"""
func AirMove():
	var wishdir = transform.basis.x.slide(ground_normal) * smove + -transform.basis.z.slide(ground_normal) * fmove
	wishdir = wishdir.normalized()
	
	AirAccelerate(wishdir, STOPSPEED if velocity.dot(wishdir) < 0 else AIRACCELERATE)
	if (AIRCONTROL > 0.0): 
		AirControl(wishdir)
	
	velocity[1] -= GRAVITY * deltaTime
	
	var collision = move_and_collide(velocity * deltaTime) 
	if collision:
		velocity = velocity.slide(collision.get_normal())

"""
===============
AirAccelerate
===============
"""
func AirAccelerate(wishdir, accel):
	var addspeed : float
	var accelspeed : float
	var currentspeed : float
	
	currentspeed = velocity.dot(wishdir)
	addspeed = MOVESPEED - currentspeed
	if addspeed <= 0.0: return
	
	accelspeed = accel * deltaTime * MOVESPEED
	if accelspeed > addspeed: accelspeed = addspeed
	
	velocity[0] += accelspeed * wishdir[0]
	velocity[1] += accelspeed * wishdir[1]
	velocity[2] += accelspeed * wishdir[2]

"""
===============
AirControl
===============
"""
func AirControl(wishdir):
	if fmove == 0.0: return
	
	var original_y = velocity[1]
	velocity[1] = 0.0
	var speed = velocity.length()
	velocity = velocity.normalized()
	
	# Change direction while slowing down
	var dot = velocity.dot(wishdir)
	if dot > 0.0 :
		var k = 32.0 * AIRCONTROL * dot * dot * deltaTime
		velocity[0] = velocity[0] * speed + wishdir[0] * k
		velocity[1] = velocity[1] * speed + wishdir[1] * k
		velocity[2] = velocity[2] * speed + wishdir[2] * k
		velocity = velocity.normalized()
	
	velocity[0] *= speed
	velocity[1] = original_y
	velocity[2] *= speed
	
