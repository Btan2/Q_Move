extends "res://scripts/pmove.gd"

"""
pmove_extended.gd

- Extends pmove.gd
- Ladder climbing and dismount
- Leading edge drop off check
- Sets footstep sfx ground type
"""

var ladder_normal : Vector3 = Vector3.UP
const LADDER_LAYER = 2

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
	
	ladder_check()

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
ladder_check
===============
"""
func ladder_check():
	var shape : CylinderShape
	var trace : Trace
	
	if crouch_press: 
		return
	
	# Use a slightly thicker cylinder shape for ladder detection
	shape = CylinderShape.new()
	shape.radius = float(collider.shape.radius + 0.05)
	shape.height = float(collider.shape.height)
	shape.margin = float(collider.shape.margin)
	
	# Check if touching a ladder
	trace = Trace.new()
	trace.intersect_groups(global_transform.origin, shape, self, LADDER_LAYER)
	
	if !trace.hit:
		return
	
	# Set ladder type
	#for g in trace.groups:
		#if str(g) == "[LADDER_METAL]":
			#pass
			##sfx.set_ground_type("LADDER_METAL")
		#elif str(g) == "[LADDER_WOOD]":
			#pass
			##sfx.set_ground_type("LADDER_WOOD")
	
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

