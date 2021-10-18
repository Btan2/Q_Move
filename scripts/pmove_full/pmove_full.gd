extends KinematicBody

"""
pmove_full.gd

- Complete player movement controller in one script
- Player will slowly slide down slopes
- Ladder climbing and dismount
- Leading edge drop off check
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
const MAXHANG : float = 0.2          # default: 0.2
const PLAYER_HEIGHT : float = 3.6    # default: 3.6
const CROUCH_HEIGHT : float = 2.0    # default: 2.0
const LADDER_LAYER = 2

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
var ladder_normal : Vector3 = Vector3.UP

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
	
	crouch()
	categorize_position()
	ladder_check()
	jump_button()
	check_state()

"""
===============
check_state
===============
"""
func check_state():
	match(state):
		LADDER:
			ladder_move()
		GROUNDED:
			ground_move()
		FALLING:
			air_move()

"""
===============
crouch
===============
"""
func crouch():
	var crouch_speed = 20.0 * deltaTime
	
	if crouch_press:
		# snap crouch height while falling
		if state == FALLING:
			collider.shape.height = CROUCH_HEIGHT
		else:
			collider.shape.height -= crouch_speed 
	else:
		if collider.shape.height < PLAYER_HEIGHT:
			var up = transform.origin + Vector3.UP * crouch_speed
			var trace = Trace.new()
			trace.motion(transform.origin, up, collider.shape, self)
			if trace.fraction == 1:
				collider.shape.height += crouch_speed
	
	collider.shape.height = clamp(collider.shape.height, CROUCH_HEIGHT, PLAYER_HEIGHT)
	head.y_offset = collider.shape.height * 0.35

"""
===============
categorize_position

Check if the player is touching the ground
===============
"""
func categorize_position():
	var down  : Vector3
	var trace : Trace
	
	trace = Trace.new()
	
	# Check for ground 0.1 units below the player
	down = global_transform.origin + Vector3.DOWN * 0.1
	trace.full(global_transform.origin, down, collider.shape, self)
	
	ground_plane = false
	
	if trace.fraction == 1:
		state = FALLING
		ground_normal = Vector3.UP
	else: 
		ground_plane = true
		ground_normal = trace.normal
		sfx.set_ground_type(trace.type)
		
		if ground_normal[1] < 0.7:
			state = FALLING # Too steep!
		else:
			if state == FALLING:
				calc_fall_damage()
			
			global_transform.origin = trace.endpos # Clamp to ground
			prev_y = global_transform.origin[1]
			impact_velocity = 0
			
			state = GROUNDED

"""
===============
calc_fall_damage
===============
"""
func calc_fall_damage():
	var fall_dist : int
	
	fall_dist = int(round(abs(prev_y - global_transform.origin[1])))
	if fall_dist >= 20 && impact_velocity >= 45: 
		jump_press = false
		sfx.play_land_hurt()
		head.parse_damage(Vector3.ONE * float(impact_velocity / 6))
	else:
		if fall_dist > PLAYER_HEIGHT:
			sfx.play_land()
		if fall_dist >= 6:
			head.parse_damage(Vector3.ONE * float(impact_velocity / 8))

"""
===============
jump_button
===============
"""
func jump_button():
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
		
		# Make sure jump velocity is positive if moving down
		if state == FALLING or velocity[1] < 0.0:
			velocity[1] = JUMPFORCE
		else:
			velocity[1] += JUMPFORCE

"""
===============
ground_move
===============
"""
func ground_move():
	var wishdir : Vector3
	
	wishdir = (global_transform.basis.x * smove + -global_transform.basis.z * fmove).normalized()
	wishdir = wishdir.slide(ground_normal)
	
	ground_accelerate(wishdir, slope_speed(ground_normal[1]))
	#var original_velocity = velocity
	
	var ccd_max = 5
	for _i in range(ccd_max):
		var ccd_step = velocity / ccd_max
		var collision = move_and_collide(ccd_step * deltaTime)
		if collision:
			var normal = collision.get_normal()
			if normal[1] < 0.7 and !is_dead:
				var stepped = step_move(global_transform.origin, velocity.normalized() * 10)
				if !stepped and velocity.dot(normal) < 0:
					velocity = velocity.slide(normal)
			else:
				velocity = velocity.slide(normal)

"""
===============
step_move
===============
"""
func step_move(original_pos : Vector3, vel : Vector3):
	var dest  : Vector3
	var down  : Vector3
	var up    : Vector3
	var trace : Trace
	
	trace = Trace.new()
	
	# Get destination position that is one step-size above the intended move
	dest = original_pos
	dest[0] += vel[0] * deltaTime
	dest[1] += STEPSIZE
	dest[2] += vel[2] * deltaTime
	
	# 1st Trace: check for collisions one stepsize above the original position
	up = original_pos + Vector3.UP * STEPSIZE
	trace.standard(original_pos, up, collider.shape, self)
	
	dest[1] = trace.endpos[1]
	
	# 2nd Trace: Check for collisions one stepsize above the original position
	# and along the intended destination
	trace.standard(trace.endpos, dest, collider.shape, self)
	
	# 3rd Trace: Check for collisions below the stepsize until 
	# level with original position
	down = Vector3(trace.endpos[0], original_pos[1], trace.endpos[2])
	trace.standard(trace.endpos, down, collider.shape, self)
	
	# Move to trace collision position if step is higher than original position 
	# and not steep 
	if trace.endpos[1] > original_pos[1] and trace.normal[1] >= 0.7: 
		global_transform.origin = trace.endpos
		#velocity = velocity.slide(trace.normal)
		return true
	
	return false

"""
===============
ladder_check
===============
"""
func ladder_check():
	var shape : CylinderShape
	var trace : Trace
	
	if crouch_press: 
		return
	
	# Use a slightly thicker version of player cylinder for ladder detection
	shape = CylinderShape.new()
	shape.radius = float(collider.shape.radius + 0.05)
	shape.height = float(collider.shape.height)
	shape.margin = float(collider.shape.margin)
	
	# Check if touching a ladder
	trace = Trace.new()
	trace.intersect_groups(global_transform.origin, shape, self, LADDER_LAYER)
	
	if !trace.hit:
		return
	
#	# Set ladder type
#	for g in trace.groups:
#		if str(g) == "[LADDER_METAL]":
#			pass
#			#sfx.set_ground_type("LADDER_METAL")
#		elif str(g) == "[LADDER_WOOD]":
#			pass
#			#sfx.set_ground_type("LADDER_WOOD")
	
	# Get ladder normal
	trace.rest(global_transform.origin, shape, self, LADDER_LAYER)
	if trace.hit:
		ladder_normal = trace.normal
	
	# Check if moving away from the ladder
	var dir = (transform.basis.x * smove + -transform.basis.z * fmove).normalized()
	var move_off = dir.dot(ladder_normal) > 0
	
	# Move off ladder if touching stable ground
	if move_off and state == GROUNDED: 
		return
	
	# Jump away from ladder
	if move_off and jump_press:
		velocity = dir * 10.0
		ground_normal = Vector3.UP
		return
	
	state = LADDER

"""
===============
ladder_move
===============
"""
func ladder_move():
	var wishdir = (global_transform.basis.x * smove + -head.camera.global_transform.basis.z * fmove).normalized()
	var forward_dir = wishdir.slide(Vector3.UP)
	wishdir = wishdir.slide(ladder_normal)
	
	ground_accelerate(wishdir, movespeed/2.0)
	
	var ccd_max = 5
	for _i in range(ccd_max):
		var ccd_step = velocity / ccd_max
		var collision = move_and_collide(ccd_step * deltaTime)
		if collision:
			velocity = velocity.slide(collision.get_normal())
	
	# Check if we can move up and over the tip of the ladder
	step_move(global_transform.origin, forward_dir * 4.0)
	
	prev_y = transform.origin[1]
	impact_velocity = 0

"""
===============
ground_accelerate
===============
"""
func ground_accelerate(wishdir : Vector3, wishspeed : float):
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
		stop[1] = start[1] - 3.6
		stop[2] = start[2]
		var trace = Trace.new()
		trace.motion(start, stop, collider.shape, self)
		if trace.fraction == 1:
			friction *= 2.0
	
	# Friction applied after move release
	if wishdir != Vector3.ZERO:
		velocity = velocity.linear_interpolate(wishdir * wishspeed, ACCELERATE * deltaTime) 
	else:
		velocity = velocity.linear_interpolate(Vector3.ZERO, friction * deltaTime) 

"""
===============
slope_speed

Change velocity while moving up/down sloped ground
===============
"""
func slope_speed(y_normal : float):
	if y_normal <= 0.97:
		var multiplier = y_normal if velocity[1] > 0.0 else 2.0 - y_normal
		return clamp(movespeed * multiplier, 5.0, movespeed * 1.2)
	return movespeed

"""
===============
air_move
===============
"""
func air_move():
	var wishdir : Vector3
	
	wishdir = (global_transform.basis.x * smove + -global_transform.basis.z * fmove).normalized()
	wishdir = wishdir.slide(ground_normal)
	#wishdir[1] = 0.0
	
	air_accelerate(wishdir, STOPSPEED if velocity.dot(wishdir) < 0 else AIRACCELERATE)
	
	if !ground_plane:
		if (AIRCONTROL > 0.0): 
			air_control(wishdir)
	
	velocity[1] -= GRAVITY * deltaTime
	
	# Cache Y position if moving/jumping up
	if global_transform.origin[1] >= prev_y: 
		prev_y = global_transform.origin[1]
	
	impact_velocity = abs(int(round(velocity[1])))
	
	var ccd_max = 5
	for _i in range(ccd_max):
		var ccd_step = velocity / ccd_max
		var collision = move_and_collide(ccd_step * deltaTime)
		if collision:
			var normal = collision.get_normal()
			if velocity.dot(normal) < 0:
				velocity = velocity.slide(normal)

"""
===============
air_accelerate
===============
"""
func air_accelerate(wishdir : Vector3, accel : float):
	var addspeed     : float
	var accelspeed   : float
	var currentspeed : float
	
	var wishspeed = slope_speed(ground_normal[1])
	
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
air_control
===============
"""
func air_control(wishdir : Vector3):
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
==================
push

Can be used for rocket jumps, impact damage etc.
==================
"""
func push(force : float, dir : Vector3, mass : float):
	for i in range(3):
		velocity[i] += force * dir[i] / mass

#"""
#==================
#ClipVelocity
#==================
#"""
#func ClipVelocity(vel : Vector3, normal : Vector3, overbounce : float):
#	var backoff : float
#	var change  : float
#	var out     : Vector3
#
#	out = vel
#	backoff = vel.dot(normal) * overbounce
#
#	for i in range(3):
#		change = normal[i] * backoff
#		out[i] -= - change
#		if out[i] > -0.1 and out[i] < 0.1:
#			out[i] = 0
#
#	return out
