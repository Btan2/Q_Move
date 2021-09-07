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
const PLAYER_HEIGHT : float = 3.6
const CROUCH_HEIGHT : float = 2.0

var deltaTime : float = 0.0
var movespeed : float = 32.0
var fmove : float = 0.0
var smove : float = 0.0
var ground_normal : Vector3 = Vector3.UP
var ladder_normal : Vector3 = Vector3.UP
var hangtime : float = 0.2
var impact_velocity : float = 0.0
var is_dead : bool = false
var jump_press : bool = false
var crouch_press : bool = false
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
	$Label.text = ""
	
	deltaTime = delta
	
	Crouch()
	CategorizePosition()
	LadderCheck()
	JumpButton()
	
	match(state):
		LADDER:
			$Label.text += "Ladder"
			LadderMove()
		GROUNDED:
			$Label.text += "Grounded"
			GroundMove()
		FALLING:
			$Label.text += "Falling"
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
			var fraction = Trace.fraction(transform.origin, dest, collider.shape, self)
			if fraction == 1:
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
	var collision
	
	wishdir = transform.basis.x.slide(ground_normal) * smove + -transform.basis.z.slide(ground_normal) * fmove
	wishdir = wishdir.normalized()
	
	GroundAccelerate(wishdir, movespeed)
	
	var ccd_max = 5
	for _i in range(ccd_max):
		var ccd_step = velocity / ccd_max
		collision = move_and_collide(ccd_step * deltaTime)
		if collision:
			var normal = collision.get_normal()
			var stepped = false
			if normal[1] < 0.7 and !is_dead:
				stepped = StepMove(global_transform.origin, velocity)
			if !stepped:
				velocity = velocity.slide(normal)

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
	
	# Step is too steep or level with current position
	return false

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
	
#	var ccd_max = 5
#	for _i in range(ccd_max):
#		var ccd_step = velocity / ccd_max
	collision = move_and_collide(velocity * deltaTime) 
	if collision:
		velocity = velocity.slide(collision.get_normal())

"""
===============
AirAccelerate
===============
"""
func AirAccelerate(wishdir, accel):
	var addspeed     : float
	var accelspeed   : float
	var currentspeed : float
	
	currentspeed = velocity.dot(wishdir)
	addspeed = movespeed - currentspeed
	if addspeed <= 0.0: 
		return
	
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

"""
===============
GroundAccelerate
===============
"""
func GroundAccelerate(wishdir, wishspeed):
	var friction : float
	var speed    : float 
	
	friction = MOVEFRICTION
	speed = velocity.length()
	
	if state == LADDER:
		friction = 30.0
	elif speed > 0.0:
		# If the leading edge is over a dropoff, increase friction
		var start = global_transform.origin
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
		velocity = velocity.linear_interpolate(wishdir * wishspeed, ACCELERATE * deltaTime) 
	else:
		velocity = velocity.linear_interpolate(Vector3.ZERO, friction * deltaTime) 

"""
===============
LadderCheck
===============
"""
func LadderCheck():
	var groups
	var colliders
	var ladder_obj
	var on_ladder : bool
	var shape : CylinderShape
	var trace
	
	if crouch_press: 
		return
	
	on_ladder = false
	
	# Use a slightly thicker version of player cylinder for ladder detection
	shape = CylinderShape.new()
	shape.radius = float(collider.shape.radius + 0.05)
	shape.height = float(collider.shape.height)
	shape.margin = float(collider.shape.margin)
	
	trace = Trace.group(global_transform.origin, shape, self)
	groups = trace[0]
	colliders = trace[1]
	
	if len(groups) > 0:
		for i in range(len(groups)):
			for g in groups[i]:
				if (g == "LADDER_METAL" or g == "LADDER_WOOD") and !on_ladder:
					on_ladder = true
					ladder_obj = colliders[i].get_parent()
					break
	
	if on_ladder:
		ladder_normal = -ladder_obj.global_transform.basis.z.normalized()
		
		# Get closest point on player's cylinder to ladder plane
		var ladder_edge = ladder_obj.global_transform.origin + ladder_normal * ladder_obj.scale.z
		var player_edge = global_transform.origin - ladder_normal * 1.0
		player_edge[1] = ladder_edge[1] 
		
		# Normal movement if standing on the tip of ladder
		var dir_to_edge = (player_edge - ladder_edge).normalized()
		if ladder_normal.dot(dir_to_edge) < 0:
			return
		
		# Check if moving away from ladder
		var dir = (transform.basis.x * smove + -transform.basis.z * fmove).normalized()
		var moving_off = dir.dot(ladder_normal) > 0
		
		# Move away while touching stable ground
		if moving_off and state == GROUNDED: 
			return
		
		# Jump away from ladder
		if moving_off and jump_press:
			velocity = dir * 10.0
			ground_normal = Vector3.UP
			return
		
		state = LADDER

"""
===============
LadderMove
===============
"""
func LadderMove():
	var wishdir = (transform.basis.x * smove + -head.camera.global_transform.basis.z * fmove).normalized()
	wishdir = wishdir.slide(ladder_normal)
	GroundAccelerate(wishdir, movespeed/2.0)
	
	# warning-ignore:return_value_discarded
	move_and_slide(velocity)
#	var collision = move_and_collide(velocity * deltaTime) 
#	if collision:
#		velocity = velocity.slide(collision.get_normal())
	
	prev_y = transform.origin[1]
	impact_velocity = 0
