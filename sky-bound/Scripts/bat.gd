extends RigidBody3D
@onready var bat_model: Node3D = $bat_model
var player = null
@onready var timer: Timer = $Timer
@onready var hurt_sound: AudioStreamPlayer3D = $HurtSound
@onready var dead_sound: AudioStreamPlayer3D = $DeadSound

signal died

var health= 3
var speed= randf_range(2.0,4.0)
var target_switch_timer: float = 0.0
var target_switch_interval: float = 3.0  # Switch target every 3 seconds

func _ready() -> void:
	_select_random_player()

func _physics_process(delta) -> void:
	# Check if we need to switch target
	target_switch_timer += delta
	if target_switch_timer >= target_switch_interval:
		target_switch_timer = 0.0
		_select_random_player()
	
	# If current target is invalid, find a new one
	if player == null or not is_instance_valid(player) or not player.is_in_group("players"):
		_select_random_player()
	
	if player == null: 
		return
	
	var dir = global_position.direction_to(player.global_position)
	dir.y=0.0
	linear_velocity = dir*speed
	bat_model.rotation.y = Vector3.FORWARD.signed_angle_to(dir, Vector3.UP) + PI

func _select_random_player() -> void:
	var players = get_tree().get_nodes_in_group("players")
	if players.size() == 0:
		player = null
		return
	
	var random_index = randi() % players.size()
	player = players[random_index]

func take_damage():
	if player == null: return
	
	if health < 0:
		return
	
	bat_model.hurt()
	hurt_sound.play()
	health-=1
	if health ==0:
		set_physics_process(false)
		gravity_scale= 1.0
		var direction = -1.0 * global_position.direction_to(player.global_position)
		var random_upward_force = Vector3.UP * randf() * 5.0
		apply_central_impulse(direction.rotated(Vector3.UP, randf_range(-0.2, 0.2)) * 10.0 + random_upward_force)
		dead_sound.play()
		timer.start()

func _on_timer_timeout():
	queue_free()
	died.emit()
