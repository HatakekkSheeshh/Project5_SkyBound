extends RigidBody3D
@onready var bat_model: Node3D = $bat_model
var player = null
@onready var timer: Timer = $Timer
@onready var hurt_sound: AudioStreamPlayer3D = $HurtSound
@onready var dead_sound: AudioStreamPlayer3D = $DeadSound

signal died(killer_id: int)

var health= 3
var speed= randf_range(2.0,4.0)
var target_switch_timer: float = 0.0
var target_switch_interval: float = 3.0
var killer_id: int = -1

func _ready() -> void:
	_select_random_player()

func _physics_process(delta) -> void:
	target_switch_timer += delta
	if target_switch_timer >= target_switch_interval:
		target_switch_timer = 0.0
		_select_random_player()
	
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

func take_damage(from_player_id: int = -1):
	if player == null: 
		return
	
	if health < 0:
		return
	
	if from_player_id != -1:
		killer_id = from_player_id
	
	bat_model.hurt()
	hurt_sound.play()
	health-=1
	
	if health ==0:
		if multiplayer.has_multiplayer_peer():
			if multiplayer.is_server():
				_handle_death()
			else:
				var game_node = get_tree().get_first_node_in_group("game")
				if game_node and game_node.has_method("_increase_local_score_optimistic"):
					game_node._increase_local_score_optimistic(killer_id, 1)
				
				rpc_id(1, "_bat_died_on_server", killer_id)
				_handle_death_visuals()
		else:
			_handle_death()

func _handle_death() -> void:
	set_physics_process(false)
	gravity_scale= 1.0
	var direction = -1.0 * global_position.direction_to(player.global_position)
	var random_upward_force = Vector3.UP * randf() * 5.0
	apply_central_impulse(direction.rotated(Vector3.UP, randf_range(-0.2, 0.2)) * 10.0 + random_upward_force)
	dead_sound.play()
	timer.start()

func _handle_death_visuals() -> void:
	set_physics_process(false)
	gravity_scale= 1.0
	if player:
		var direction = -1.0 * global_position.direction_to(player.global_position)
		var random_upward_force = Vector3.UP * randf() * 5.0
		apply_central_impulse(direction.rotated(Vector3.UP, randf_range(-0.2, 0.2)) * 10.0 + random_upward_force)
	dead_sound.play()
	timer.start()

@rpc("any_peer", "call_local", "reliable")
func _bat_died_on_server(reported_killer_id: int) -> void:
	if not multiplayer.is_server():
		return
	
	killer_id = reported_killer_id
	
	var game_node = get_tree().get_first_node_in_group("game")
	
	if game_node:
		if game_node.has_method("_increase_player_score"):
			game_node._increase_player_score(reported_killer_id, 1)
		else:
			died.emit(reported_killer_id)
	else:
		died.emit(reported_killer_id)
	
	if is_instance_valid(self):
		_handle_death()

func _on_timer_timeout():
	var final_killer_id = killer_id if killer_id != -1 else 1
	queue_free()
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		died.emit(final_killer_id)
