extends Spatial

"""
view.gd

- Controls the player view and view-model (i.e their weapon)
- Uses modified functions from Quake source code for weapon-bob, head-bob and so on.
- Lots of vars, so you might want to hard code some values before building
"""
onready var camera = $Camera
onready var viewmodel = $Camera/ViewModel
onready var viewmodel_origin = viewmodel.transform.origin
onready var player = get_parent()

var bobtimes = [0,0,0]
var Q_bobtime : float = 0.0
var Q_bob : float = 0.0
var bobRight : float = 0.0
var bobForward : float = 0.0
var bobUp : float = 0.0
var idleRight : float = 0.0
var idleForward : float = 0.0
var idleUp : float =  0.0
var shakecam = false
var shaketime : float = 0.0
var shakelength = 0.0
var deltaTime : float = 0.0
var idletime : float = 0.0
var mouse_move : Vector2 = Vector2.ZERO
var moved : bool  = false
var mouse_rotation_x : float = 0.0
var newbob : bool = false
var oldy : float = 0.0
var swayPos : Vector3 = Vector3.ZERO
var swayRoll : Vector3 = Vector3.ZERO
var v_dmg_time : float = 0.0
var v_dmg_roll : float = 0.0
var v_dmg_pitch : float = 0.0

#Bob
var cl_bob : float = 0.01             # default: 0.01
var cl_bobup : float = 0.5            # default: 0.5
var cl_bobcycle : float = 0.8         # default: 0.8
var ql_bob : float = 0.012             # default: 0.012
var ql_bobup : float = 0.5            # default: 0.5
var ql_bobcycle : float = 0.6         # default: 0.6

#Roll
var rollangles : float = 7.0          # default: 15.0
var rollspeed : float = 300.0         # default: 300.0
var tiltextra : float = 2.0           # default: 2.0

#Viewmodel Sway
var swayPos_offset : float = 0.12     # default: 0.12
var swayPos_max : float = 0.5        # default: 0.1
var swayPos_speed : float = 7.0       # default: 9.0
var swayRoll_angle : float = 5.0      # default: 5.0   (old default: Vector3(5.0, 5.0, 2.0))
var swayRoll_max : float = 10.0       # default: 15.0  (old default: Vector3(12.0, 12.0, 4.0))
var swayRoll_speed : float = 2.0     # default: 10.0

#View Idle
var idlescale : float= 1.6            # default: 1.6
var iyaw_cycle : float = 1.5          # default: 1.5
var iroll_cycle : float = 1.0         # default: 1.0
var ipitch_cycle : float = 2.0        # default: 2.0
var iyaw_level : float = 0.1          # default: 0.1
var iroll_level : float = 0.2         # default: 0.2
var ipitch_level : float = 0.15       # default: 0.15

# Viewmodel Idle
var idlePos_scale = 0.1                         #default: 0.1
var idleRot_scale = 0.5                         #default: 0.5
var idlePos_cycle = Vector3(2.0, 4.0, 0)        #default: Vector3(2.0, 4.0, 0) 
var idlePos_level = Vector3(0.02, 0.045, 0)     #default: Vector3(0.02, 0.045, 0) 
var idleRot_cycle = Vector3(1.0, 0.5, 1.25)     #default: Vector3(1.0, 0.5, 1.25)
var idleRot_level = Vector3(-1.5, 2, 1.5)       #default: Vector3(-1.5, 2, 1.5)

var mouse_sensitivity : float = 0.1

const kick_time : float = 0.5           # default: 0.5
const kick_amount : float = 0.6         # default: 0.6
var y_offset : float = 1.25           # default: 1.0

enum { VB_COS, VB_SIN, VB_COS2, VB_SIN2 }
const bob_mode = VB_SIN

"""
===============
_ready
===============
"""
func _ready():
	newbob = true
	swayPos = viewmodel_origin
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

"""
===============
_input
===============
"""
func _input(event):
	if event is InputEventMouseMotion:
		moved = true
		mouse_move = lerp(mouse_move, event.relative * mouse_sensitivity, 15 * deltaTime)
		mouse_rotation_x -= event.relative.y * mouse_sensitivity
		mouse_rotation_x = clamp(mouse_rotation_x, -90, 90)
		player.rotate_y(deg2rad(-event.relative.x * mouse_sensitivity))
	
	if Input.is_key_pressed(KEY_P):
		TriggerShake(5.0)

"""
===============
_process
===============
"""
func _physics_process(delta):
	deltaTime = delta
	
	# Player can still look around if dead
	camera.rotation_degrees = Vector3(mouse_rotation_x, 0, 0)
	
	if player.is_dead:
		camera.rotation_degrees.z = 80
		transform.origin = Vector3(0, -1.6, 0)
		return
	
	# Set points of origin
	transform.origin = Vector3(0, y_offset, 0)
	viewmodel.transform.origin = viewmodel_origin
	viewmodel.rotation_degrees = Vector3.ZERO
	
	VelocityRoll()
	ViewModelSway()
	
	if player.velocity.length() <= 0.1:
		bobtimes = [0,0,0]
		Q_bobtime = 0.0
		
		AddIdle()
		ViewIdle()
		ViewModelIdle()
	else:
		idletime = 0.0
		
		AddBob()
		if newbob:
			ViewBobModern()
		else:
			ViewBobClassic()
		
		ViewModelBob()
	
	# Smooth out stair step ups
	var current = player.global_transform.origin[1]
	if player.state == 0 and current - oldy > 0:
		oldy += delta * 15.0
		if oldy > current:
			oldy = current
		if current - oldy > 1.2:
			oldy = current - 1.2
		transform.origin[1] += oldy - current
	else:
		oldy = current
	
	# Apply damage/fall kicks
	if v_dmg_time > 0.0:
		camera.rotation_degrees.z += v_dmg_time / kick_time * v_dmg_roll
		camera.rotation_degrees.x += v_dmg_time / kick_time * v_dmg_pitch
		v_dmg_time -= delta
	
	if shakecam:
		Shake(1)

"""
===============
ViewModelSway
Lerp weapon origin & angle while moving the mouse
===============
"""
func ViewModelSway():
	var pos : Vector3
	var rot : Vector3
	
	if !moved:
		mouse_move = mouse_move.linear_interpolate(Vector2.ZERO, 1 * deltaTime)
	
	moved = false
	
	pos = Vector3.ZERO 
	pos.x = clamp(-mouse_move.x * swayPos_offset, -swayPos_max, swayPos_max)
	pos.y = clamp(mouse_move.y * swayPos_offset, -swayPos_max, swayPos_max)
	swayPos = lerp(swayPos, pos, swayPos_speed * deltaTime)
	viewmodel.transform.origin += swayPos
	
	#rot = Vector3.ZERO
	#rot.x = clamp(-mouse_move.y * swayRoll_angle, -swayRoll_max, swayRoll_max)
	##rot.z = clamp(mouse_move.x * swayRoll_angle, -swayRoll_max, swayRoll_max)
	#rot.y = clamp(-mouse_move.x * swayRoll_angle, -swayRoll_max, swayRoll_max)
	#swayRoll = lerp(swayRoll, rot, swayRoll_speed * deltaTime)
	#viewmodel.rotation_degrees += swayRoll

"""
===============
VelocityRoll
===============
"""
func VelocityRoll():
	var side : float
	
	side = CalcRoll(player.velocity, rollangles, rollspeed) * 4;
	camera.rotation_degrees.z += side
	viewmodel.rotation_degrees.z = side * tiltextra

"""
===============
CalcRoll
Roll angle left/right based on velocity
===============
"""
func CalcRoll (velocity, angle, speed):
	var _sign : float
	var side : float
	
	side = velocity.dot(-get_global_transform().basis.x)
	_sign = -1 if side < 0 else 1
	side = abs(side)
	
	if (side < speed):
		side = side * angle / speed;
	else:
		side = angle;
	return side * _sign

"""
==============
AddIdle
Calculate idle sinewaves
==============
"""
func AddIdle():
	idletime += deltaTime
	idleRight = idlescale * sin(idletime * ipitch_cycle) * ipitch_level
	idleUp = idlescale * sin(idletime * iyaw_cycle) * iyaw_level
	idleForward = idlescale * sin(idletime * iroll_cycle) * iroll_level

"""
===============
ViewIdle
===============
"""
func ViewIdle():
	camera.rotation_degrees.x += idleUp
	camera.rotation_degrees.y += idleRight
	camera.rotation_degrees.z += idleForward

"""
===============
ViewModelIdle
===============
"""
func ViewModelIdle():
	for i in range(3):
		viewmodel.transform.origin[i] += idlePos_scale * sin(idletime * idlePos_cycle[i]) * idlePos_level[i]
		viewmodel.rotation_degrees[i] += idleRot_scale * sin(idletime * idleRot_cycle[i]) * idleRot_level[i]

"""
===============
AddBob
===============
"""
func AddBob():
	bobRight = CalcBob(0.75, bob_mode, 0, bobRight)
	bobUp = CalcBob(1.50, bob_mode, 1, bobUp)
	bobForward = CalcBob(1.00, bob_mode, 2, bobForward)

"""
===============
ViewModelBob
Bob view model on xyz axes
===============
"""
func ViewModelBob():
	for i in range(3):
		viewmodel.transform.origin[i] += bobRight * 0.25 * transform.basis.x[i]
		viewmodel.transform.origin[i] += bobUp * 0.125 * transform.basis.y[i]
		viewmodel.transform.origin[i] += bobForward * 0.06125 * transform.basis.z[i]

"""
===============
ViewBobModern
Modern style head-bob
===============
"""
func ViewBobModern():
	camera.rotation_degrees.z += bobRight * 0.8
	camera.rotation_degrees.y -= bobUp * 0.8
	camera.rotation_degrees.x += bobRight * 1.2

"""
===============
ViewBob
Classic Quake head-bob
===============
"""
func ViewBobClassic():
	transform.origin[1] += CalcBobClassic()

"""
===============
CalcBobClassic
===============
"""
func CalcBobClassic():
	var vel : Vector3
	var cycle : float
	
	if player.state != 0: 
		return Q_bob
	
	Q_bobtime += deltaTime
	cycle = Q_bobtime - int(Q_bobtime / ql_bobcycle) * ql_bobcycle
	cycle /= ql_bobcycle
	if cycle < ql_bobup:
		cycle = PI * cycle / ql_bobup
	else:
		cycle = PI + PI * (cycle - ql_bobup) / (1.0 - ql_bobup)
	
	vel = player.velocity
	Q_bob = sqrt(vel[0] * vel[0] + vel[2] * vel[2]) * ql_bob
	Q_bob = Q_bob * 0.3 + Q_bob * 0.7 * sin(cycle)
	Q_bob = clamp(Q_bob, -7.0, 4.0)
	
	return Q_bob

"""
===============
CalcBob
===============
"""
func CalcBob (freqmod: float, mode, bob_i: int, bob: float):
	var cycle : float
	var vel : Vector3
	
	if player.state != 0:
		return bob
	
	bobtimes[bob_i] += deltaTime * freqmod
	cycle = bobtimes[bob_i] - int( bobtimes[bob_i] / cl_bobcycle ) * cl_bobcycle
	cycle /= cl_bobcycle
	
	if cycle < cl_bobup:
		cycle = PI * cycle / cl_bobup
	else:
		cycle = PI + PI * ( cycle - cl_bobup)/( 1.0 - cl_bobup)
	
	vel = player.velocity
	bob = sqrt(vel[0] * vel[0] + vel[2] * vel[2]) * cl_bob
	
	if mode == VB_SIN:
		bob = bob * 0.3 + bob * 0.7 * sin(cycle)
	elif mode == VB_COS:
		bob = bob * 0.3 + bob * 0.7 * cos(cycle)
	elif mode == VB_SIN2:
		bob = bob * 0.3 + bob * 0.7 * sin(cycle) * sin(cycle)
	elif mode == VB_COS2:
		bob = bob * 0.3 + bob * 0.7 * cos(cycle) * cos(cycle)
	bob = clamp(bob, -7, 4)
	
	return bob

"""
==============
TriggerShake
==============
"""
func TriggerShake(time):
	shakecam = true
	shaketime = 0.0
	shakelength = time
	yield(get_tree().create_timer(time),"timeout")
	shakecam = false

"""
==============
Shake
==============
"""
func Shake(easing):
	var cycle = Vector3(33, 44, 36)
	var m_level = Vector3(0.02, 0.06, 0.02)
	var v_level = Vector3(-1.5, 2, 1.25)
	var s_scale : float
	
	shaketime += deltaTime 
	
	easing = clamp(easing, 0, 2)
	if easing == 0: # No shake easing
		s_scale = 1.0
	elif easing == 1: # Ease off scaling towards the end of the shake
		var diff = shakelength - shaketime
		s_scale = diff if diff <= 1.0 else 1.0
	elif easing == 2: # Ease off scaling throughout the entire shake
		s_scale = 1.0 - shaketime/shakelength
	
	for i in range(3):
		viewmodel.transform.origin[i] += s_scale * sin(shaketime * cycle[i]) * m_level[i]
		camera.rotation_degrees[i] += s_scale * sin(shaketime * cycle[i]) * v_level[i]
	

"""
==============
ParseDamage
Trigger view kicks
==============
"""
func ParseDamage(from):
	var side : float
	
	side = from.dot(-get_global_transform().basis.z)
	v_dmg_roll = side * kick_amount
	side = from.dot(get_global_transform().basis.x)
	v_dmg_pitch = side * kick_amount
	v_dmg_time = kick_time
