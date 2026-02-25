class_name Player extends CharacterBody3D

## Character maximum run speed on the ground.
@export var move_speed := 8.0
## Movement acceleration (how fast character achieve maximum speed)
@export var acceleration := 4.0
## Jump impulse
@export var jump_initial_impulse := 12.0
## Jump impulse when player keeps pressing jump
@export var jump_additional_force := 4.5

@export var number_of_jumps = 2
## Player model rotation speed
@export var rotation_speed := 12.0
## Minimum horizontal speed on the ground. This controls when the character's animation tree changes
## between the idle and running states. STEPHEN NOTE: we probably won't ever get this far lol
@export var stopping_speed := 1.0

@export var dash_speed = 30


#@export_category("Globe stuff?") #currently not worth the effort but maybe worth revisiting
#@export var globe := StaticBody3D

@onready var _camera_controller = $CameraController
@onready var _rotation_root: Node3D = $"Rotation root"

@onready var animation_player = $"character-oopi/AnimationPlayer"

@onready var _move_direction := Vector3.ZERO
@onready var _last_strong_direction := Vector3.FORWARD #not sure what this does yet
@onready var _gravity: float = -30.0
@onready var _ground_height: float = 0.0
@onready var _start_position := global_transform.origin
@onready var _ground_shapecast: ShapeCast3D = $GroundShapeCast

@onready var _is_on_floor_buffer := false
@onready var can_jump := true #not currently used
@onready var can_dash := true


@onready var jump_1_sound = $Jump1
@onready var jump_2_sound = $Jump2
@onready var dash_sound = $Dash1


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_camera_controller.setup(self)
	


func _physics_process(delta: float) -> void:
	#up_direction = globe.position - position
	# Calculate ground height for camera controller (SN: Not sure how this works yet)
	if _ground_shapecast.get_collision_count() > 0:
		for collision_result in _ground_shapecast.collision_result:
			_ground_height = max(_ground_height, collision_result.point.y)
	else:
		_ground_height = global_position.y + _ground_shapecast.target_position.y
	if global_position.y < _ground_height:
		_ground_height = global_position.y
	if is_on_floor():
		number_of_jumps = 2
		can_dash = true
	# Get input and movement state
	var is_just_jumping := Input.is_action_just_pressed("accept") and number_of_jumps > 0
	var is_air_boosting := Input.is_action_pressed("accept") and not is_on_floor() and velocity.y > 0.0
	var is_just_on_floor := is_on_floor() and not _is_on_floor_buffer
	var is_just_dashing := Input.is_action_just_pressed("dash") and can_dash == true
	
	_is_on_floor_buffer = is_on_floor()
	_move_direction = _get_camera_oriented_input() #one sec...
	
		# To not orient quickly to the last input, we save a last strong direction,
	# this also ensures a good normalized value for the rotation basis.
	if _move_direction.length() > 0.2:
		_last_strong_direction = _move_direction.normalized()
		
	_orient_character_to_direction(_last_strong_direction, delta)
	# We separate out the y velocity to not interpolate on the gravity SN: No clue what this means yet either
	var y_velocity := velocity.y
	velocity.y = 0.0
	velocity = velocity.lerp(_move_direction * move_speed, acceleration * delta)
	if _move_direction.length() == 0 and velocity.length() < stopping_speed:
		velocity = Vector3.ZERO
	velocity.y = y_velocity
	 #there's some stuff in here about aiming but since we're not using that this ^ line might be redundant
	_camera_controller.set_pivot(_camera_controller.CAMERA_PIVOT.THIRD_PERSON)
	velocity.y += _gravity * delta
	
	if is_just_jumping:
		velocity.y += jump_initial_impulse
		number_of_jumps -= 1
	if is_just_dashing:
		velocity += _last_strong_direction * dash_speed
		can_dash = false
		dash_sound.play()
	elif is_air_boosting:
		velocity.y += jump_additional_force * delta
		
	#can set animations at this point
	if is_just_jumping:
		if number_of_jumps >= 1:
			animation_player.play("jump")
			jump_1_sound.play()
		if number_of_jumps <1:
			animation_player.play("fall")
			jump_2_sound.play()
	elif is_on_floor():
		var xz_velocity := Vector3(velocity.x, 0, velocity.z)
		if xz_velocity.length() > stopping_speed:
			animation_player.play("sprint")
		else:
			animation_player.play("idle")

	
	var position_before := global_position
	move_and_slide()
	var position_after := global_position
	#here's an interesting section worth thinking more about
	# If velocity is not 0 but the difference of positions after move_and_slide is,
	# character might be stuck somewhere!
	var delta_position := position_after - position_before
	var epsilon := 0.001
	if delta_position.length() < epsilon and velocity.length() > epsilon:
		global_position += get_wall_normal() * 0.1

func reset_position() -> void:
	transform.origin = _start_position
	
func _get_camera_oriented_input() -> Vector3:
	#inputs need renaming
	var raw_input := Input.get_vector("left", "right", "up", "down")

	var input := Vector3.ZERO
	# This is to ensure that diagonal input isn't stronger than axis aligned input
	input.x = -raw_input.x * sqrt(1.0 - raw_input.y * raw_input.y / 2.0)
	input.z = -raw_input.y * sqrt(1.0 - raw_input.x * raw_input.x / 2.0)

	input = _camera_controller.global_transform.basis * input
	input.y = 0.0
	return input

#idk how this shit works

func _orient_character_to_direction(direction: Vector3, delta: float) -> void:
	var left_axis := Vector3.UP.cross(direction)
	var rotation_basis := Basis(left_axis, Vector3.UP, direction).get_rotation_quaternion()
	#var model_scale := _rotation_root.transform.basis.get_scale()
	var model_scale = $"character-oopi".transform.basis.get_scale()
	#_rotation_root.transform.basis = Basis(_rotation_root.transform.basis.get_rotation_quaternion().slerp(rotation_basis, delta * rotation_speed)).scaled(
		#model_scale,
	#)
	$"character-oopi".transform.basis = Basis($"character-oopi".transform.basis.get_rotation_quaternion().slerp(rotation_basis, delta * rotation_speed)).scaled(
		model_scale,
	)
