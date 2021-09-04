# Here is all the code used for player movement.
# It's not yet complete (no going up steps and probably more features missing), and may be a bit messy
# See it in action here : https://www.youtube.com/watch?v=ALRW8pSbosE

extends KinematicBody

export var mouse_sensitivity: float = 0.01

export var max_speed: float = 64 # Meters per second
export var max_air_speed: float = 0.6
export var accel: float = 100 # or max_speed * 10 : Reach max speed in 1 / 10th of a second

# For now, the friction variable is not used, as the calculations are  not the same as quake's
# export var friction: float = 2 # Higher friction = less slippery. In quake-based games, usually between 1 and 5

export var gravity: float = 15
export var jump_impulse: float = 4.8
var terminal_velocity: float = gravity * -5 # When this is reached, we stop increasing falling speed

var snap: Vector3 # Needed for move_and_slide_wit_snap(), which enables to go down slopes without falling

onready var head: Spatial = $Head
onready var camera: Camera = $Head/Camera

var velocity: Vector3 = Vector3.ZERO # The current velocity vector
var wishdir: Vector3 = Vector3.ZERO # Desired travel direction of the player

var vertical_velocity: float = 0 # Vertical component of our velocity. 
# We separate it from 'velocity' to make calculations easier, then join both vectors before moving the player

var wish_jump: bool = false # If true, player has queued a jump : the jump key can be held down before hitting the ground to jump.
var auto_jump: bool = false # Auto bunnyhopping

# The next three variables are used to display corresponding vectors in game world.
# This is probably not the best solution and will be removed in the future.
var debug_horizontal_velocity: Vector3 = Vector3.ZERO
var accelerate_return: Vector3 = Vector3.ZERO

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

#func _ready() -> void:
#	# We tell our DebugOverlay to draw those vectors in the game world.
#	DebugOverlay.draw.add_vector(self, "wishdir", 1, 8, Color(0,1,0, 0.5)) # Green, WISHDIR
#	DebugOverlay.draw.add_vector(self, "accelerate_return", 0.2, 4, Color(0,0,1, 0.25)) # Blue, ACCEL
#	DebugOverlay.draw.add_vector(self, "debug_horizontal_velocity", 0.2, 8, Color(1,0,0, 1)) # Red, VELOCITY

func _input(event: InputEvent) -> void:
	# Camera rotation
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		head.rotate_x(event.relative.y * mouse_sensitivity * -1)
		self.rotate_y(event.relative.x * mouse_sensitivity * -1)
		
		var camera_rot = head.rotation_degrees
		camera_rot.x = clamp(camera_rot.x, -90, 90)
		head.rotation_degrees = camera_rot

func _physics_process(delta: float) -> void:
	var forward_input: float = Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
	var strafe_input: float = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	wishdir = Vector3(strafe_input, 0, forward_input).rotated(Vector3.UP, self.global_transform.basis.get_euler().y).normalized() 
	# wishdir is our normalized horizontal inpur
	
	queue_jump()
	
	if self.is_on_floor():
		if wish_jump: # If we're on the ground but wish_jump is still true, this means we've just landed
			snap = Vector3.ZERO #Set snapping to zero so we can get off the ground
			vertical_velocity = jump_impulse # Jump
			
			move_air(velocity, delta) # Mimic Quake's way of treating first frame after landing as still in the air
			
			wish_jump = false # We have jumped, the player needs to press jump key again
			
		else : # Player is on the ground. Move normally, apply friction
			vertical_velocity = 0
			snap = -get_floor_normal() #Turn snapping on, so we stick to slopes
			move_ground(velocity, delta)
	
	else: #We're in the air. Do not apply friction
		snap = Vector3.DOWN
		vertical_velocity -= gravity * delta if vertical_velocity >= terminal_velocity else 0 # Stop adding to vertical velocity once terminal velocity is reached
		move_air(velocity, delta)
	
	if self.is_on_ceiling(): #We've hit a ceiling, usually after a jump. Vertical velocity is reset to cancel any remaining jump momentum
		vertical_velocity = 0
	
	debug_horizontal_velocity = Vector3(velocity.x, 0, velocity.z) # Horizontal velocity to be displayed

# This is were we calculate the speed to add to current velocity
func accelerate(wishdir: Vector3, input_velocity: Vector3, accel: float, max_speed: float, delta: float)-> Vector3:
	# Current speed is calculated by projecting our velocity onto wishdir.
	# We can thus manipulate our wishdir to trick the engine into thinking we're going slower than we actually are, allowing us to accelerate further.
	var current_speed: float = input_velocity.dot(wishdir)
	
	# Next, we calculate the speed to be added for the next frame.
	# If our current speed is low enough, we will add the max acceleration.
	# If we're going too fast, our acceleration will be reduced (until it evenutually hits 0, where we don't add any more speed).
	var add_speed: float = clamp(max_speed - current_speed, 0, accel * delta)
	
	# Put the new velocity in a variable, so the vector can be displayed.
	accelerate_return = input_velocity + wishdir * add_speed
	return accelerate_return

# Scale down horizontal velocity
# For now, we're simply substracting 10% from our current velocity. This is not how it works in engines like idTech or Source !
func friction(input_velocity: Vector3)-> Vector3:
	var speed: float = input_velocity.length()
	var scaled_velocity: Vector3

	scaled_velocity = input_velocity * 0.9 # Reduce current velocity by 10%
	
	# If the player is moving too slowly, we stop them completely
	if scaled_velocity.length() < max_speed / 100:
		scaled_velocity = Vector3.ZERO

	return scaled_velocity

# Apply friction, then accelerate
func move_ground(input_velocity: Vector3, delta: float)-> void:
	# We first work on only on the horizontal components of our current velocity
	var nextVelocity: Vector3 = Vector3.ZERO
	nextVelocity.x = input_velocity.x
	nextVelocity.z = input_velocity.z
	nextVelocity = friction(nextVelocity) #Scale down velocity
	nextVelocity = accelerate(wishdir, nextVelocity, accel, max_speed, delta)
	
	# Then get back our vertical component, and move the player
	nextVelocity.y = vertical_velocity
	velocity = move_and_slide_with_snap(nextVelocity, snap, Vector3.UP)

# Accelerate without applying friction (with a lower allowed max_speed)
func move_air(input_velocity: Vector3, delta: float)-> void:
	# We first work on only on the horizontal components of our current velocity
	var nextVelocity: Vector3 = Vector3.ZERO
	nextVelocity.x = input_velocity.x
	nextVelocity.z = input_velocity.z
	nextVelocity = accelerate(wishdir, nextVelocity, accel, max_air_speed, delta)
	
	# Then get back our vertical component, and move the player
	nextVelocity.y = vertical_velocity
	velocity = move_and_slide_with_snap(nextVelocity, snap, Vector3.UP)

# Set wish_jump depending on player input.
func queue_jump()-> void:
	# If auto_jump is true, the player keeps jumping as long as the key is kept down
	if auto_jump:
		wish_jump = true if Input.is_action_pressed("jump") else false
		return
	
	if Input.is_action_just_pressed("jump") and !wish_jump:
		wish_jump = true
	if Input.is_action_just_released("jump"):
		wish_jump = false
