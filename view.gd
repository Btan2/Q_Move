extends Spatial

"""
view.gd

- Controls the player view and view-model (i.e their weapon)
- Uses modified functions from Quake source code for weapon-bob, head-bob and so on.
"""

onready var viewmodel = $ViewModel
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
var deltaTime : float = 0.0
var idletime : float = 0.0
var mouse_move : Vector2 = Vector2.ZERO
var moved : bool  = false
var mouse_rotation_x : float = 0.0
var newbob : bool = false # Use more modern head-bobbing otherwise uses Quake-style head-bobbing
var oldy : float = 0.0
var swayPos : Vector3 = Vector3.ZERO
var swayRoll : Vector3 = Vector3.ZERO
var v_dmg_time : float = 0.0
var v_dmg_roll : float = 0.0
var v_dmg_pitch : float = 0.0

#Bob
const cl_bob : float = 0.01             # default: 0.01
const cl_bobup : float = 0.5            # default: 0.5
const cl_bobcycle : float = 0.8         # default: 0.8
const ql_bob : float = 0.012             # default: 0.012
const ql_bobup : float = 0.5            # default: 0.5
const ql_bobcycle : float = 0.6         # default: 0.6

#Roll
const rollangles : float = 7.0          # default: 15.0
const rollspeed : float = 300.0         # default: 300.0
const tiltextra : float = 2.0           # default: 2.0

#Viewmodel Sway
const swayPos_offset : float = 0.5      # default: 0.12
const swayPos_max : float = 0.9         # default: 0.1
const swayPos_speed : float = 9.0       # default: 9.0
const swayRoll_angle : float = 5.0      # default: 5.0   (old default: Vector3(5.0, 5.0, 2.0))
const swayRoll_max : float = 15.0       # default: 15.0  (old default: Vector3(12.0, 12.0, 4.0))
const swayRoll_speed : float = 10.0     # default: 10.0

#View Idle
const idlescale : float= 1.6            # default: 1.6
const iyaw_cycle : float = 1.5          # default: 1.5
const iroll_cycle : float = 1.0         # default: 1.0
const ipitch_cycle : float = 2.0        # default: 2.0
const iyaw_level : float = 0.1          # default: 0.1
const iroll_level : float = 0.2         # default: 0.2
const ipitch_level : float = 0.15       # default: 0.15

# Viewmodel Idle
const idlePos_scale = 0.1                         #default: 0.1
const idleRot_scale = 0.5                         #default: 0.5
const idlePos_cycle = Vector3(2.0, 4.0, 0)        #default: Vector3(2.0, 4.0, 0) 
const idlePos_level = Vector3(0.02, 0.045, 0)     #default: Vector3(0.02, 0.045, 0) 
const idleRot_cycle = Vector3(1.0, 0.5, 1.25)     #default: Vector3(1.0, 0.5, 1.25)
const idleRot_level = Vector3(-1.5, 2, 1.5)       #default: Vector3(-1.5, 2, 1.5)

const kick_time : float = 0.5           # default: 0.5
const kick_amount : float = 0.6         # default: 0.6
const y_offset : float = 1.25           # default: 1.0
const sway_sensitivity : float = 0.01   # default: 0.01
const mouse_sensitivity : float = 0.1

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
		mouse_move = event.relative * sway_sensitivity
		
		mouse_rotation_x -= event.relative.y * mouse_sensitivity
		mouse_rotation_x = clamp(mouse_rotation_x, -90, 90)
		player.rotate_y(deg2rad(-event.relative.x * mouse_sensitivity))

"""
===============
_process
===============
"""
func _process(delta):
	deltaTime = delta
	
	if player.is_dead:
		rotation_degrees.z = 80
		transform.origin = Vector3(0, -1.6, 0)
		return
	
	transform.origin = Vector3(0, y_offset, 0)
	rotation_degrees = Vector3(mouse_rotation_x, 0, 0)
	
	ViewModelSway()
	ViewRoll()
	
	if player.velocity == Vector3.ZERO:
		bobtimes = [0,0,0]
		Q_bobtime = 0.0
		AddIdle()
		ViewModelIdle()
		ViewIdle()
	else:
		idletime = 0.0
		AddBob()
		ViewModelBob()
		
		if newbob:
			ViewBob1()
		else:
			ViewBob2()
	
	# Smooth out stair step ups
	if player.state == 0 and player.global_transform.origin[1] - oldy > 0:
		oldy += delta * 15.0
		if oldy > player.global_transform.origin[1]:
			oldy = player.global_transform.origin[1]
		if player.global_transform.origin[1] - oldy > 1.2:
			oldy = player.global_transform.origin[1] - 1.2
		transform.origin[1] += oldy - player.global_transform.origin[1]
	else:
		oldy = player.global_transform.origin[1]
	
	# Apply damage/fall kicks
	if v_dmg_time > 0.0:
		rotation_degrees.z += v_dmg_time / kick_time * v_dmg_roll
		rotation_degrees.x += v_dmg_time / kick_time * v_dmg_pitch
		v_dmg_time -= delta

"""
===============
ViewModelSway
Lerp weapon origin & angle while moving the mouse
===============
"""
func ViewModelSway():
	if !moved:
		mouse_move = mouse_move.linear_interpolate(Vector2.ZERO, 1 * deltaTime)
	
	var pos = Vector3.ZERO 
	pos.x = clamp(-mouse_move.x * swayPos_offset, -swayPos_max, swayPos_max)
	pos.y = clamp(mouse_move.y * swayPos_offset, -swayPos_max, swayPos_max)
	swayPos = lerp(swayPos, pos, swayPos_speed * deltaTime)
	
	var rot = Vector3.ZERO
	rot.x = clamp(-mouse_move.y * swayRoll_angle, -swayRoll_max, swayRoll_max)
	rot.y = clamp(-mouse_move.x * swayRoll_angle, -swayRoll_max, swayRoll_max)
	swayRoll = lerp(swayRoll, rot, swayRoll_speed * deltaTime)
	
	viewmodel.transform.origin = viewmodel_origin + swayPos
	viewmodel.rotation_degrees = swayRoll
	
	moved = false

"""
===============
CalcViewRoll
Roll view and viewmodel by movement
===============
"""
func ViewRoll():
	var side = CalcRoll(player.velocity, rollangles, rollspeed) * 4;
	rotation_degrees.z += side
	viewmodel.rotation_degrees.z = side * tiltextra

"""
===============
CalcRoll
Roll angle left/right based on velocity
===============
"""
func CalcRoll (velocity, rollangle, rollspeed):
	var _sign : float
	var side : float
	
	side = velocity.dot(-get_global_transform().basis.x)
	_sign = -1 if side < 0 else 1
	side = abs(side)
	
	if (side < rollspeed):
		side = side * rollangle / rollspeed;
	else:
		side = rollangle;
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
Idle view bob
===============
"""
func ViewIdle():
	rotation_degrees.x += idleUp
	rotation_degrees.y += idleRight
	rotation_degrees.z += idleForward

"""
===============
ViewModelIdle
Idle weapon bob
===============
"""
func ViewModelIdle():
	for i in range(3):
		viewmodel.transform.origin[i] += idlePos_scale * sin(idletime * idlePos_cycle[i]) * idlePos_level[i]
		viewmodel.rotation_degrees[i] += idleRot_scale * sin(idletime * idleRot_cycle[i]) * idleRot_level[i]

"""
===============
AddBob
Set bob sinewaves
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
		viewmodel.transform.origin[i] += bobRight * 0.5 * transform.basis.x[i]
		viewmodel.transform.origin[i] += bobUp * 0.25 * transform.basis.y[i]
		viewmodel.transform.origin[i] += bobForward * 0.125 * transform.basis.z[i]

"""
===============
ViewBob
Bob view up/down with slight z axis roll
===============
"""
func ViewBob1():
	rotation_degrees.z += bobRight * 0.8
	rotation_degrees.y -= bobUp * 0.8
	rotation_degrees.x += bobRight * 1.2

func ViewBob2():
	transform.origin[1] += Q_CalcBob()

func Q_CalcBob():
	var vel        : Vector3
	var cycle      : float
	
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
Quakeworld bob code
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
