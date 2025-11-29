extends CharacterBody3D

@onready var camera = %PlayerCamera
@onready var gun = %PlayerGun

const BULLET = preload("uid://bm1y0p1m7eepn")

const MOUSE_SEN_SCALE = 0.2
const CAMERA_MAX_UP = 90
const CAMERA_MAX_DOWN = -80
const SPEED = 5 # m/s


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		move_camera(event)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _physics_process(delta: float) -> void:
	process_gravity(delta)
	
	handle_move_input()
	if Input.is_action_just_pressed("jump") and is_on_floor():
		handle_jumping()
	elif Input.is_action_just_released("jump") and velocity.y > 0:
		velocity.y = 0.0
	
	if Input.is_action_just_pressed("shoot"):
		shoot_bullet()
	
	move_and_slide()


func move_camera(event) -> void:
	rotation_degrees.y -= event.relative.x * MOUSE_SEN_SCALE
	camera.rotation_degrees.x -= event.relative.y * MOUSE_SEN_SCALE
	camera.rotation_degrees.x = clamp(camera.rotation_degrees.x, CAMERA_MAX_DOWN, CAMERA_MAX_UP)


func handle_move_input() -> void:
	var input_direction_2d = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var input_direction_3d = Vector3(input_direction_2d.x, 0.0, input_direction_2d.y)
	var direction = transform.basis * input_direction_3d
	
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED


func handle_jumping() -> void:
	velocity.y = 10


func process_gravity(delta) -> void:
	if is_on_floor():
		velocity.y = 0
	else:
		velocity.y -= 20 * delta


func shoot_bullet() -> void:
	var new_bullet: Area3D = BULLET.instantiate()
	%Marker3D.add_child(new_bullet)
	
	new_bullet.global_transform = %Marker3D.global_transform
