extends KinematicBody

"""
pmove.gd

- Player movement controller
- Player will still slide down slopes. Please fix this issue Godot!
- Only tested with simple 3D shapes such as boxes and spheres.
- "move_and_slide" is causing buggy velocity clipping when moving against vertical walls and concave surfaces.
"""

onready var collider : CollisionShape = $CollisionShape
onready var head : Spatial = $Head
onready var sfx : Node = $Audio

const MAXSPEED : float = 32.0        # default: 32.0
const WALKSPEED : float = 12.0       # default: 16.0
const STOPSPEED : float = 10.0       # default: 10.0
const GRAVITY : float = 80.0         # default: 80.0
const ACCELERATE : float = 10.0      # default: 10.0
const AIRACCELERATE : float = 0.25   # default: 0.7
const MOVEFRICTION : float = 6.0     # default: 6.0
const JUMPFORCE : float = 27.0       # default: 27.0
const AIRCONTROL : float = 0.9       # default: 0.9
const STEPSIZE : float = 1.8         # default: 1.8
const MAXHANG : float = 0.2          # defualt: 0.2

var deltaTime : float = 0.0
var movespeed : float = 32.0
var fmove : float = 0.0
var smove : float = 0.0
var ground_normal : Vector3 = Vector3.UP
var hangtime : float = 0.2
var impact_velocity : float = 0.0
var is_dead : bool = false
var jump_press : bool = false
var prev_y : float = 0.0
var velocity : Vector3 = Vector3.ZERO

enum {GROUNDED, FALLING, LADDER, SWIMMING, NOCLIP}
var state = GROUNDED

"""
===============
_input
===============
"""
func _input(_event):
	
	if Input.is_key_pressed(KEY_K):
		is_dead = true if !is_dead else false
	
	# Ignore inputs if dead
	if is_dead:
		fmove = 0.0
		smove = 0.0
		jump_press = false
		return
	
	fmove = Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward")
	smove = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	
	movespeed = WALKSPEED if Input.is_action_pressed("shift") else MAXSPEED
	
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
	var down : Vector3
	var trace
	
	# Check for ground 0.1 units below the player
	down = global_transform.origin + Vector3.DOWN * 0.1
	trace = Trace.normalfrac(global_transform.origin, down, collider.shape, self)
	
	if trace[0] == 1:
		state = FALLING
		ground_normal = Vector3.UP
	else: 
		ground_normal = trace[2]
		
		if ground_normal[1] < 0.7:
			state = FALLING # Too steep!
		else:
			if state == FALLING:
				CalcFallDamage()
			
			global_transform.origin = trace[1] # Clamp to ground
			prev_y = global_transform.origin[1]
			impact_velocity = 0
			
			state = GROUNDED

"""
===============
CalcFallDamage
===============
"""
func CalcFallDamage():
	var fall_dist : int
	
	fall_dist = int(round(abs(prev_y - global_transform.origin[1])))
	if fall_dist >= 20 && impact_velocity >= 45: 
		jump_press = false
		sfx.PlayLandHurt()
		head.ParseDamage(Vector3.ONE * float(impact_velocity / 6))
	else:
		#sfx.play_land(impact_velocity)
		if fall_dist >= 8:
			head.ParseDamage(Vector3.ONE * float(impact_velocity / 8))

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
		
		sfx.PlayJump()
		
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
	var wishdir : Vector3
	
	wishdir = transform.basis.x.slide(ground_normal) * smove + -transform.basis.z.slide(ground_normal) * fmove
	wishdir = wishdir.normalized()
	
	GroundAccelerate(wishdir, movespeed)
	
	#var original_vel = velocity
	
	move_and_slide(velocity)
	
	# Don't move up steps if dead
	if is_dead : return 
	
	for i in range(get_slide_count()):
		if get_slide_collision(i).normal[1] < 0.7:
			StepMove(global_transform.origin)
	
	#velocity = original_vel

"""
===============
StepMove
===============
"""
func StepMove(original_pos):
	var dest : Vector3
	var up : Vector3
	var down : Vector3
	var trace
	
	# Get destination position that is one step-size above the intended move
	dest = original_pos
	dest[0] += velocity[0] * deltaTime
	dest[1] += STEPSIZE
	dest[2] += velocity[2] * deltaTime
	
	# 1st Trace: check for collisions one stepsize above the original position
	up = original_pos + Vector3.UP * STEPSIZE
	trace = Trace.normal(original_pos, up, collider.shape, self)
	dest[1] = trace[0][1]
	
	# 2nd Trace: Check for collisions from the 1st trace end position
	# towards the intended destination
	trace = Trace.normal(trace[0], dest, collider.shape, self)
	
	# 3rd Trace: Check for collisions below the 2nd trace end position
	down = Vector3(trace[0][0], original_pos[1], trace[0][2])
	trace = Trace.normal(trace[0], down, collider.shape, self)
	
	# Move to trace collision position if step is higher than original position and not steep 
	if trace[0][1] > original_pos[1] and trace[1][1] >= 0.7: 
		global_transform.origin = trace[0]
	
	velocity = velocity.slide(trace[1])

"""
===============
AirMove
===============
"""
func AirMove():
	var wishdir : Vector3
	var collision
	
	wishdir = transform.basis.x.slide(ground_normal) * smove + -transform.basis.z.slide(ground_normal) * fmove
	wishdir = wishdir.normalized()
	#wishdir[1] = 0.0
	
	AirAccelerate(wishdir, STOPSPEED if velocity.dot(wishdir) < 0 else AIRACCELERATE)
	if (AIRCONTROL > 0.0): 
		AirControl(wishdir)
	
	velocity[1] -= GRAVITY * deltaTime
	
	# Cache Y position if moving/jumping up
	if global_transform.origin[1] >= prev_y: 
		prev_y = global_transform.origin[1]
	
	impact_velocity = abs(int(round(velocity[1])))
	
	collision = move_and_collide(velocity * deltaTime) 
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
	addspeed = movespeed - currentspeed
	if addspeed <= 0.0: return
	
	accelspeed = accel * deltaTime * movespeed
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
	

"""
===============
GroundAccelerate
===============
"""
func GroundAccelerate(wishdir, wishspeed):
	var accel = ACCELERATE
	var friction = MOVEFRICTION
	var speed = velocity.length()
	
	if state == LADDER:
		friction = 30.0
	elif speed > 0.0:
		# If the leading edge is over a dropoff, increase friction
		var start = transform.origin
		start[0] += velocity[0] / speed * 1.6
		start[2] += velocity[2] / speed * 1.6
		var stop = Vector3.ZERO
		stop[0] = start[0]
		stop[1] = start[1] - 3.4
		stop[2] = start[2]
		var fraction = Trace.fraction(start, stop, collider.shape, self)
		if fraction == 1:
			friction *= 2.0
	
	# Friction applied after move release
	if wishdir != Vector3.ZERO:
		velocity = velocity.linear_interpolate(wishdir * wishspeed, accel * deltaTime) 
	else:
		velocity = velocity.linear_interpolate(Vector3.ZERO, friction * deltaTime) 

#"""
#===============
#Friction
#===============
#"""
#func Friction():
#	var speed : float
#	var newspeed : float
#	var control : float
#	var friction : float
#	var drop : float
#	var trace
#
#	speed = velocity.length()
#	if speed <= 0:
#		return
#
#	friction = MOVEFRICTION
#
#	# if the leading edge is over a dropoff, increase friction
#	if state == GROUNDED: 
#		var start = transform.origin
#		var stop = Vector3.ZERO
#		start[0] += velocity[0]/speed*1.6
#		stop[0] = start[0]
#		start[2] += velocity[2]/speed*1.6
#		stop[2] = start[2]
#		stop[1] = start[1] - 3.4
#
#		trace = Trace.fraction(start, stop, collider.shape, self)
#
#		if trace == 1:
#			friction *= 2
#
#	drop = 0
#	if state == GROUNDED:
#		if speed < STOPSPEED:
#			control = STOPSPEED
#		else:
#			control = speed
#
#		drop += control * friction * deltaTime
#
#	newspeed = speed - drop
#	if newspeed < 0:
#		newspeed = 0
#	newspeed /= speed
#
#	velocity[0] *= newspeed
#	velocity[1] *= newspeed
#	velocity[2] *= newspeed
#
#"""
#===============
#Accelerate
#===============
#"""
#func Accelerate(wishdir, wishspeed, accel):
#	var addspeed : float
#	var accelspeed : float
#	var currentspeed : float
#
#	currentspeed = velocity.dot(wishdir)
#	addspeed = wishspeed - currentspeed
#	if addspeed <= 0:
#		return
#
#	accelspeed = accel * deltaTime * wishspeed
#	if accelspeed > addspeed:
#		accelspeed = addspeed
#
#	velocity[0] += accelspeed * wishdir[0]
#	velocity[1] += accelspeed * wishdir[1]
#	velocity[2] += accelspeed * wishdir[2]
