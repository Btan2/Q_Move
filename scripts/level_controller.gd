extends Spatial

"""
level_controller.gd

- Teleport player if they move out of game bounds
"""

onready var player = $Player
onready var player_head = $Player/Head
onready var player_camera = $Player/Head/Camera

func _process(_delta):
	if player.global_transform.origin[1] < -75.0:
		reset_player_pos(Vector3(0, 38.0, -120.0))

"""
===============
reset_player_pos
===============
"""
func reset_player_pos(reset_pos : Vector3):
	player.global_transform.origin = reset_pos
	player.velocity = Vector3.ZERO
	player.rotation_degrees[1] = 0
	player_camera.rotation_degrees = Vector3.ZERO
	player_head.mouse_rotation_x = 0.0
