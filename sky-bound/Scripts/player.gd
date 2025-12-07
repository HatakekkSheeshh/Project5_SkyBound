extends CharacterBody3D

@onready var camera = %PlayerCamera
@onready var gun = %PlayerGun
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer

@export var synced_position: Vector3
var spawn_position: Vector3 = Vector3.ZERO

const BULLET = preload("uid://bm1y0p1m7eepn")

const MOUSE_SEN_SCALE = 0.2
const CAMERA_MAX_UP = 90
const CAMERA_MAX_DOWN = -80
const SPEED = 5

func _enter_tree() -> void:
	var authority_id = name.to_int()
	set_multiplayer_authority(authority_id)

func _ready() -> void:
	add_to_group("players")
	
	if is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		
		# Apply spawn position if set
		if spawn_position != Vector3.ZERO:
			_apply_spawn_position(spawn_position)
		
		# Set camera after a delay to ensure server observer camera doesn't override
		call_deferred("_set_camera_delayed")
	else:
		_set_camera_current(false)
		
		# Apply spawn position if set
		if spawn_position != Vector3.ZERO:
			_apply_spawn_position(spawn_position)

func _apply_spawn_position(spawn_pos: Vector3) -> void:
	print("Applying spawn position ", spawn_pos, "for ", name)
	if spawn_pos == Vector3.ZERO:
		return
	
	velocity = Vector3.ZERO
	global_position = spawn_pos
	synced_position = spawn_pos
	spawn_position = spawn_pos
	
	# Force position update in next physics frame to prevent physics from moving player
	await get_tree().physics_frame
	velocity = Vector3.ZERO
	global_position = spawn_pos

func _set_camera_current(value: bool) -> void:
	if camera:
		camera.current = value
		if value:
			print("[PLAYER] Camera set to current for player: ", name)

func _set_camera_delayed() -> void:
	# Wait a frame to ensure server observer camera doesn't override
	await get_tree().process_frame
	_set_camera_current(true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		move_camera(event)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		# Only process physics if spawn position is set
		if spawn_position == Vector3.ZERO:
			return
		
		process_gravity(delta)
		handle_move_input()
		
		if Input.is_action_just_pressed("jump") and is_on_floor():
			handle_jumping()
		elif Input.is_action_just_released("jump") and velocity.y > 0:
			velocity.y = 0.0
		
		if Input.is_action_just_pressed("shoot"):
			shoot_bullet()
		
		move_and_slide()
		synced_position = global_position
		
		var player_id = name.to_int()
		rpc("_update_position", player_id, synced_position)
	else:
		if synced_position != Vector3.ZERO:
			global_position = synced_position

func move_camera(event) -> void:
	if not is_multiplayer_authority():
		return
	
	rotation_degrees.y -= event.relative.x * MOUSE_SEN_SCALE
	camera.rotation_degrees.x -= event.relative.y * MOUSE_SEN_SCALE
	camera.rotation_degrees.x = clamp(camera.rotation_degrees.x, CAMERA_MAX_DOWN, CAMERA_MAX_UP)

func handle_move_input() -> void:
	if !is_multiplayer_authority():
		return
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
	audio_stream_player.play()

@rpc("any_peer", "call_local", "unreliable")
func _update_position(player_id: int, new_pos: Vector3) -> void:
	var my_id = name.to_int()
	if player_id == my_id and not is_multiplayer_authority():
		synced_position = new_pos
