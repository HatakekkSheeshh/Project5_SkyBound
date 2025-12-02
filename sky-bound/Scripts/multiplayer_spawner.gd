extends MultiplayerSpawner

@export var network_player: PackedScene

func _ready() -> void:
	# single mode
	print("Spawner ready, network_player =", network_player)
	if  NetworkConnection.is_multiplayer == false:
		print("Running in Single Player mode")
		_spawn_single_player()
		return
	
	# multi mode
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(spawn_player)
		spawn_player(multiplayer.get_unique_id())
	
func spawn_player(id: int) -> void:
	if !multiplayer.is_server(): return
	
	var player: Node = network_player.instantiate()
	player.name = str(id)
	
	var spawn_point := $"../SpawnPoint"
	player.global_position = spawn_point.global_position
	player.set_multiplayer_authority(id)
	
	# if id == 1: return
	get_node(spawn_path).call_deferred("add_child", player)
	
func _spawn_single_player():
	var player: Node = network_player.instantiate()
	player.name = "1"
	
	var spawn_point := $"../SpawnPoint"
	player.global_position = spawn_point.global_position
	player.set_multiplayer_authority(1)
	get_node(spawn_path).call_deferred("add_child", player)
