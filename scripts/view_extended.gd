extends "res://scripts/view.gd"

"""
view_extended.gd

- Extends view.gd
- Adds view-model bob and sway
- Adds view-model shake
"""

onready var viewmodel = $Camera/ViewModel

var viewmodel_origin = Vector3(0.5, -0.4, -0.75) # set this to the gun models local position
var swayPos : Vector3 = Vector3.ZERO
var swayPos_offset : float = 0.12               # default: 0.12
var swayPos_max : float = 0.5                   # default: 0.1
var swayPos_speed : float = 9.0                 # default: 9.0
var swayRot : Vector3 = Vector3.ZERO
var swayRot_angle : float = 5.0                 # default: 5.0   (old: Vector3(5.0, 5.0, 2.0))
var swayRot_max : float = 15.0                  # default: 15.0  (old: Vector3(12.0, 12.0, 4.0))
var swayRot_speed : float = 5.0                 # default: 10.0
var idlePos_scale = 0.1                         # default: 0.1
var idlePos_cycle = Vector3(2.0, 4.0, 0)        # default: Vector3(2.0, 4.0, 0) 
var idlePos_level = Vector3(0.02, 0.045, 0)     # default: Vector3(0.02, 0.045, 0) 
var idleRot_scale = 0.5                         # default: 0.5
var idleRot_cycle = Vector3(1.0, 0.5, 1.25)     # default: Vector3(1.0, 0.5, 1.25)
var idleRot_level = Vector3(-1.5, 2, 1.5)       # default: Vector3(-1.5, 2, 1.5)

"""
===============
_ready
===============
"""
func _ready():
	swayPos = viewmodel_origin

"""
===============
_physics_process
===============
"""
func _physics_process(_delta):
	if player.is_dead:
		return
	
	viewmodel.transform.origin = viewmodel_origin
	viewmodel.rotation_degrees = Vector3.ZERO
	
	view_model_sway()
	
	if player.velocity.length() <= 0.1:
		view_model_idle()
	else:
		view_model_bob()

"""
===============
view_model_sway

Lerp weapon origin & angle while moving the mouse
===============
"""
func view_model_sway():
	var pos : Vector3
	var rot : Vector3
	
	if mouse_move == null:
		mouse_move = mouse_move.linear_interpolate(Vector2.ZERO, 1 * deltaTime)
		return
	
	pos = Vector3.ZERO
	pos.x = clamp(-mouse_move.x * swayPos_offset, -swayPos_max, swayPos_max)
	pos.y = clamp(mouse_move.y * swayPos_offset, -swayPos_max, swayPos_max)
	swayPos = lerp(swayPos, pos, swayPos_speed * deltaTime)
	viewmodel.transform.origin += swayPos
	
	rot = Vector3.ZERO
	rot.x = clamp(-mouse_move.y * swayRot_angle, -swayRot_max, swayRot_max)
	rot.z = clamp(mouse_move.x * swayRot_angle, -swayRot_max/3, swayRot_max/3)
	rot.y = clamp(-mouse_move.x * swayRot_angle, -swayRot_max, swayRot_max)
	swayRot = lerp(swayRot, rot, swayRot_speed * deltaTime)
	viewmodel.rotation_degrees += swayRot

"""
===============
view_model_idle
===============
"""
func view_model_idle():
	for i in range(3):
		viewmodel.transform.origin[i] += idlePos_scale * sin(idletime * idlePos_cycle[i]) * idlePos_level[i]
		viewmodel.rotation_degrees[i] += idleRot_scale * sin(idletime * idleRot_cycle[i]) * idleRot_level[i]

"""
===============
view_model_bob

Bob view model on xyz axes
===============
"""
func view_model_bob():
	for i in range(3):
		viewmodel.transform.origin[i] += bobRight * 0.25 * transform.basis.x[i]
		viewmodel.transform.origin[i] += bobUp * 0.125 * transform.basis.y[i]
		viewmodel.transform.origin[i] += bobForward * 0.06125 * transform.basis.z[i]

"""
===============
velocity_roll
===============
"""
func velocity_roll():
	var side : float
	
	side = calc_roll(player.velocity, rollangles, rollspeed) * 4
	camera.rotation_degrees.z += side
	viewmodel.rotation_degrees.z += side * tiltextra

"""
==============
shake
==============
"""
func shake(easing : int):
	var cycle = Vector3(33, 44, 36)
	var m_level = Vector3(0.02, 0.06, 0.02)
	var v_level = Vector3(-1.5, 2, 1.25)
	var s_scale : float
	
	shaketime += deltaTime 
	
	easing = clamp(easing, 0, 2)
	if easing == 0: # No shake easing, shake ends abruptly
		s_scale = 1.0
	elif easing == 1: # Ease off scaling towards the end of the shake
		var diff = shakelength - shaketime
		s_scale = diff if diff <= 1.0 else 1.0
	elif easing == 2: # Ease off scaling throughout the entire shake
		s_scale = 1.0 - shaketime/shakelength
	
	for i in range(3):
		viewmodel.transform.origin[i] += s_scale * sin(shaketime * cycle[i]) * m_level[i]
		camera.rotation_degrees[i] += s_scale * sin(shaketime * cycle[i]) * v_level[i]
