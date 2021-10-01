extends KinematicBody

"""
pmove.gd

- Player movement controller
- Player will still slide down slopes
- Only tested with simple 3D shapes such as boxes and spheres
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
const PLAYER_HEIGHT : float = 3.6
const CROUCH_HEIGHT : float = 2.0

var deltaTime : float = 0.0
var movespeed : float = 32.0
var fmove : float = 0.0
var smove : float = 0.0
var ground_normal : Vector3 = Vector3.UP
var hangtime : float = 0.2
var impact_velocity : float = 0.0
var is_dead : bool = false
var jump_press : bool = false
var crouch_press : bool = false
var ground_plane : bool = false
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
	
	if Input.is_action_pressed("crouch"):
		crouch_press = true
		if movespeed == MAXSPEED:
			movespeed = WALKSPEED
		else:
			movespeed = WALKSPEED / 2.0
	else:
		crouch_press = false
	

"""
===============
_physics_process
===============
"""
func _physics_process(delta):
	deltaTime = delta
	
	Crouch()
	CategorizePosition()
	JumpButton()
	CheckState()

"""
===============
CheckState
===============
"""
func CheckState():
	if state == GROUNDED:
		GroundMove()
	elif state == FALLING:
		AirMove()

"""
===============
Crouch
===============
"""
func Crouch():
	var crouch_speed = 20.0 * deltaTime
	
	if crouch_press:
		# snap crouch height while falling
		if state == FALLING:
			collider.shape.height = CROUCH_HEIGHT
		else:
			collider.shape.height -= crouch_speed 
	else:
		if collider.shape.height < PLAYER_HEIGHT:
			var dest = transform.origin + Vector3.UP * crouch_speed
			var trace = Trace.motion(transform.origin, dest, collider.shape, self)
			if trace[0] == 1:
				collider.shape.height += crouch_speed
	
	collider.shape.height = clamp(collider.shape.height, CROUCH_HEIGHT, PLAYER_HEIGHT)
	head.y_offset = collider.shape.height * 0.35

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
	
	ground_plane = false
	
	if trace[0] == 1:
		state = FALLING
		ground_normal = Vector3.UP
	else: 
		ground_plane = true
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
		if fall_dist > PLAYER_HEIGHT:
			sfx.PlayLand()
		if fall_dist >= 8:
			head.ParseDamage(Vector3.ONE * float(impact_velocity / 8))

"""
===============
JumpButton
===============
"""
func JumpButton():
	if is_dead: 
		return
	
	# Allow jump for a few frames if just ran off platform
	if state != FALLING:
		hangtime = MAXHANG
	else:
		hangtime -= deltaTime if hangtime > 0.0 else 0.0
	
	# Moving up too fast, don't jump
	if velocity[1] > 54.0: 
		return
	
	if hangtime > 0.0 and jump_press:
		state = FALLING
		jump_press = false
		hangtime = 0.0
		
		sfx.PlayJump()
		
		# Make sure jump velocity is positive if falling
		if state == FALLING or velocity[1] < 0.0:
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
	
	wishdir = (global_transform.basis.x * smove + -global_transform.basis.z * fmove).normalized()
	wishdir = wishdir.slide(ground_normal)
	
	GroundAccelerate(wishdir, SlopeSpeed(ground_normal[1]))
	
	var ccd_max = 5
	for _i in range(ccd_max):
		var ccd_step = velocity / ccd_max
		var collision = move_and_collide(ccd_step * deltaTime)
		if collision:
			var normal = collision.get_normal()
			var stepped = false
			if normal[1] < 0.7 and !is_dead:
				stepped = StepMove(global_transform.origin, ccd_step.normalized() * ccd_max)
			if !stepped and velocity.dot(normal) < 0:
				velocity = velocity.slide(normal)

"""
===============
GroundAccelerate
===============
"""
func GroundAccelerate(wishdir, wishspeed):
	var friction : float
	
	friction = MOVEFRICTION
	
	# Friction applied after move release
	if wishdir != Vector3.ZERO:
		velocity = velocity.linear_interpolate(wishdir * wishspeed, ACCELERATE * deltaTime) 
	else:
		velocity = velocity.linear_interpolate(Vector3.ZERO, friction * deltaTime) 

"""
===============
SlopeSpeed
===============
"""
func SlopeSpeed(y_normal):
	if y_normal <= 0.97:
		var multiplier = y_normal if velocity[1] > 0.0 else 2.0 - y_normal
		return clamp(movespeed * multiplier, 5.0, movespeed * 1.2)
	return movespeed

"""
===============
StepMove
===============
"""
func StepMove(original_pos : Vector3, vel : Vector3):
	var dest : Vector3
	var down : Vector3
	var up   : Vector3
	var trace
	
	# Get destination position that is one step-size above the intended move
	dest = original_pos
	dest[0] += vel[0] * deltaTime
	dest[1] += STEPSIZE
	dest[2] += vel[2] * deltaTime
	
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
		return true
	
	return false

"""
===============
AirMove
===============
"""
func AirMove():
	var wishdir : Vector3
	var collision
	
	wishdir = (global_transform.basis.x * smove + -global_transform.basis.z * fmove).normalized()
	wishdir = wishdir.slide(ground_normal)
	#wishdir[1] = 0.0
	
	AirAccelerate(wishdir, STOPSPEED if velocity.dot(wishdir) < 0 else AIRACCELERATE)
	
	if !ground_plane:
		if (AIRCONTROL > 0.0): 
			AirControl(wishdir)
	
	velocity[1] -= GRAVITY * deltaTime
	
	# Cache Y position if moving/jumping up
	if global_transform.origin[1] >= prev_y: 
		prev_y = global_transform.origin[1]
	
	impact_velocity = abs(int(round(velocity[1])))
	
	var ccd_max = 5
	for _i in range(ccd_max):
		var ccd_step = velocity / ccd_max
		collision = move_and_collide(ccd_step * deltaTime)
		if collision:
			var normal = collision.get_normal()
			velocity = velocity.slide(normal)

"""
===============
AirAccelerate
===============
"""
func AirAccelerate(wishdir, accel):
	var addspeed     : float
	var accelspeed   : float
	var currentspeed : float
	
	var wishspeed = SlopeSpeed(ground_normal[1])
	
	currentspeed = velocity.dot(wishdir)
	addspeed = wishspeed - currentspeed
	if addspeed <= 0.0: 
		return
	
	accelspeed = accel * deltaTime * wishspeed
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
	var dot        : float
	var speed      : float
	var original_y : float
	
	if fmove == 0.0: 
		return
	
	original_y = velocity[1]
	velocity[1] = 0.0
	speed = velocity.length()
	velocity = velocity.normalized()
	
	# Change direction while slowing down
	dot = velocity.dot(wishdir)
	if dot > 0.0 :
		var k = 32.0 * AIRCONTROL * dot * dot * deltaTime
		velocity[0] = velocity[0] * speed + wishdir[0] * k
		velocity[1] = velocity[1] * speed + wishdir[1] * k
		velocity[2] = velocity[2] * speed + wishdir[2] * k
		velocity = velocity.normalized()
	
	velocity[0] *= speed
	velocity[1] = original_y
	velocity[2] *= speed
