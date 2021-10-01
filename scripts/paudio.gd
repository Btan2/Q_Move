extends Node

"""
paudio.gd

- Triggers player audio 
- Plays footsteps, jumping, landing, damage etc.
"""

export var plyr_audio_dir : String = "res://audio/"
onready var player: KinematicBody = get_parent()
onready var feet: AudioStreamPlayer = $FeetFX # Footstep sfx
onready var jump: AudioStreamPlayer = $JumpFX # Jump, fall damage sfx
onready var env: AudioStreamPlayer = $EnvFX # Environment sfx; falling, underwater etc.

var feet_concrete = []
var jump_concrete = []
var land_dirt = []
var land_arr = []
var feet_arr = []
var jump_arr = []
var footstep_volume : float = 0.25
var jump_volume : float = 0.5
var step_distance : float = 0.0
var last_position : Vector3 = Vector3.ZERO

#enum {CONCRETE, GRASS, CARPET, TILE, WOOD, PUDDLE, WATER, SAND, ROCK, LADDER_METAL, LADDER_WOOD, ROPE, METAL, AIRVENT}
var ground_type : String = "CONCRETE"

var landhurt
var r = RandomNumberGenerator.new()

"""
===============
_ready
===============
"""
func _ready() -> void:
	r.randomize()
	
	var dir = Directory.new()
	if dir.open(plyr_audio_dir) == OK:
		dir.list_dir_begin()
		var file = dir.get_next()
		while(file != ""):
			if file.begins_with("concrete") and file.ends_with("ogg"):
				feet_concrete.append(load(plyr_audio_dir + file))
			elif file.begins_with("jump_concrete") and file.ends_with("ogg"):
				jump_concrete.append(load(plyr_audio_dir + file))
			elif file.begins_with("land_concrete") and file.ends_with("ogg"):
				land_dirt.append(load(plyr_audio_dir + file))
			file = dir.get_next()
	
	feet_arr = feet_concrete
	jump_arr = jump_concrete
	land_arr = land_dirt
	
	landhurt = preload("res://audio/land_hurt.ogg")
	env.stream = preload("res://audio/windfall_1.ogg")
	
	last_position = player.global_transform.origin

"""
===============
_process
===============
"""
func _process(_delta):
	var vel = abs(player.velocity.length())
	
	PlayWindrush(vel)
	
	if player.state == 0 or player.state == 2:
		PlayFootstep(vel)

"""
===============
PlayWindrush
Air rush sfx while moving/falling at high speed
===============
"""
func PlayWindrush(vel):
	if vel > 55.0:
		if !env.playing:
			env.play()
		
		# Increase volume and pitch while falling
		var fallspeed = vel - 55.0
		env.pitch_scale = clamp(fallspeed / 150, 0.001, 1.5)
		var volume = clamp(fallspeed / 100 * 0.7, 0.1, 0.7)
		env.set_volume_db(linear2db(volume))
	else:
		if env.playing:
			env.stop()
			env.pitch_scale = 0.001
			env.set_volume_db(linear2db(0.0))

"""
===============
PlayFootstep
===============
"""
func PlayFootstep(vel):
	var position : Vector3
	var step_threshold : float
	var halfspeed : float
	var walk_threshold : float
	var run_threshold : float
	
	walk_threshold = 6.25
	run_threshold = 8.5
	
	# Get horizontal distance from move
	position = player.global_transform.origin
	position[1] = 0.0
	step_distance += position.distance_to(last_position)
	last_position = position
	
	halfspeed = player.WALKSPEED + (player.MAXSPEED - player.WALKSPEED) / 2
	step_threshold = run_threshold if vel > halfspeed else walk_threshold
	
	if step_distance > step_threshold:
		step_distance = 0.0
		
		# Don't play footstep if sneaking
		if player.crouch_press and player.movespeed < player.WALKSPEED:
			return
		
		var volume = clamp(vel / player.MAXSPEED * 1.0, 0.1, 1.0) * footstep_volume
		feet.set_volume_db(linear2db(volume))
		feet.stream = RandomFootstep()
		feet.play()

"""
===============
RandomFootstep
Picks a random footstep to play and specifically 
avoids picking duplicate footsteps
===============
"""
func RandomFootstep():
	var length : int
	var i : int
	
	length = feet_arr.size()
	i = r.randi() % length
	if feet_arr[i] == feet.stream:
		if i > 0 and i < length-1:
			i += (r.randi() & 2) - 1
		elif i == 0:
			i = r.randi_range(1, length-1)
		elif i == length-1:
			i = r.randi_range(0, length-2)
	
	return feet_arr[i]

"""
===============
PlayJump
===============
"""
func PlayJump() -> void:
	jump.set_volume_db(linear2db(jump_volume))
	jump.stream = jump_arr[r.randi_range(0,1)]
	jump.play()

"""
===============
PlayLand
===============
"""
func PlayLand() -> void:
	step_distance = 0.0
	
	jump.stop()
	jump.set_volume_db(linear2db(jump_volume))
	jump.stream = land_arr[r.randi_range(0,land_arr.size()-1)]
	jump.play()

"""
===============
PlayLandHurt
===============
"""
func PlayLandHurt() -> void:
	jump.stop()
	jump.set_volume_db(linear2db(jump_volume))
	jump.stream = landhurt
	jump.play()

"""
===============
SetGroundType
Change footstep sfx based on ground type
===============
"""
func SetGroundType(ground) -> void:
	if ground_type != ground:
		match(ground):
			"GRASS":
				pass
	#				feet_arr = feet_grass
	#				jump_arr = jump_grass
			"TILES":
				pass
	#				feet_arr = feet_tiles
	#				jump_arr = jump_tiles
			"CONCRETE":
				feet_arr = feet_concrete
				jump_arr = jump_concrete
			"DEFAULT":
				feet_arr = feet_concrete
				jump_arr = jump_concrete
			_:
				feet_arr = feet_concrete
				jump_arr = jump_concrete
				pass
		
		ground_type = ground

##################################################################################
# Works well but causes harsh audio pop/crack sound when first played
#################################################
#func PlayFootstep(vel, delta) -> void:
#	if vel < 0.01:
#		foot_timer = 0.0
#		played_foot = false
#		return
#
#	var volume = ScaleAudio(vel, 0.5, 0.2, player.MAXSPEED)
#	feet.set_volume_db(linear2db(volume * footstep_volume))
#
#	# Play footstep if just started moving, or landed from fall
#	if foot_timer == 0.0 and !feet.playing:
#		feet.stream = RandomFootstep()
#		feet.play()
#
#	var foot_velocity = clamp(vel/player.MAXSPEED, 0.0, 0.7)
#	foot_timer += delta * foot_velocity
#
#	var step = sign(sin(player.MAXSPEED * foot_timer))
#	if step > 0 and !played_foot:
#		played_foot = true
#		feet.stream = RandomFootstep()
#		feet.play()
#	elif step < 0:
#		played_foot = false
