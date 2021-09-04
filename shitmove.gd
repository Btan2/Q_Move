extends KinematicBody

var speed = 32
const ACCEL_DEFAULT = 7
const ACCEL_AIR = 1
onready var accel = ACCEL_DEFAULT
var gravity = 9.8
var jump = 5

onready var collider : CollisionShape = $CollisionShape

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

var cam_accel = 40
var mouse_sense = 0.1
var snap
var deltaTime = 0.0

var direction = Vector3()
var velocity = Vector3()
var gravity_vec = Vector3()
var movement = Vector3()
var is_dead = false
var state = 0

#func _process(delta):
#	#camera physics interpolation to reduce physics jitter on high refresh-rate monitors
#	if Engine.get_frames_per_second() > Engine.iterations_per_second:
#		camera.set_as_toplevel(true)
#		camera.global_transform.origin = camera.global_transform.origin.linear_interpolate(head.global_transform.origin, cam_accel * delta)
#		camera.rotation.y = rotation.y
#		camera.rotation.x = head.rotation.x
#	else:
#		camera.set_as_toplevel(false)
#		camera.global_transform = head.global_transform

func _physics_process(delta):
	#get keyboard input
	direction = Vector3.ZERO
	var h_rot = global_transform.basis.get_euler().y
	var f_input = Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
	var h_input = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	direction = Vector3(h_input, 0, f_input).rotated(Vector3.UP, h_rot).normalized()
	
	#jumping and gravity
	if is_on_floor():
		snap = -get_floor_normal()
		accel = ACCELERATE
		gravity_vec = Vector3.ZERO
	else:
		snap = Vector3.DOWN
		accel = AIRACCELERATE
		gravity_vec += Vector3.DOWN * GRAVITY * delta
		
	
	#make it move
	velocity = velocity.linear_interpolate(direction * speed, accel * delta)
	movement = velocity + gravity_vec
	
	velocity = move_and_slide(movement, Vector3.UP)
	
#	for i in range(get_slide_count()):
#		if get_slide_collision(i).normal[1] < 0.7:
#			StepMove(global_transform.origin)
	
#	for i in range(get_slide_count()):
#		if get_slide_collision(i).normal[1] < 0.7:
#			StepMove(global_transform.origin, vel)


"""
===============
StepMove
===============
"""
func StepMove(original_pos):
	# Get destination position that is one step-size above the intended move
	var dest = original_pos
	dest[0] += movement[0] * deltaTime
	dest[1] += 1.8 #STEPSIZE
	dest[2] += movement[2] * deltaTime
	
#	dest[0] += velocity[0] * deltaTime
#	dest[1] += 1.8 #STEPSIZE
#	dest[2] += velocity[2] * deltaTime
	
	# 1st Trace: check for collisions one stepsize above the original position
	var up = original_pos + Vector3.UP * 1.8 #STEPSIZE
	var trace = Trace.normal(original_pos, up, collider.shape, self)
	dest[1] = trace[0][1]
	
	$Label.text = str(trace[0])
	$Label.text += str(trace[1])
	
	# 2nd Trace: Check for collisions from the 1st trace end position
	# towards the intended destination
	trace = Trace.normal(trace[0], dest, collider.shape, self)
	
	# 3rd Trace: Check for collisions below the 2nd trace end position
	var down = Vector3(trace[0][0], original_pos[1], trace[0][2])
	trace = Trace.normal(trace[0], down, collider.shape, self)
	

	
	
	
	# Move to trace collision position if step is higher than original position and not steep 
	if trace[0][1] > original_pos[1] and trace[1][1] >= 0.7: 
		print("SHOULD BE STEPPING")
		global_transform.origin = trace[0]
	
	#velocity = velocity.slide(trace[1])
