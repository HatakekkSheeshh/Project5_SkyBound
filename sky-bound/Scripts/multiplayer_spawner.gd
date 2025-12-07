extends MultiplayerSpawner

@export var network_player: PackedScene
@export var spawn_offset_x: float = 5

var spawn_points: Array = []
var spawned_players: Dictionary = {}  # player_id -> position

func _ready() -> void:
	spawned.connect(_on_player_spawned)
	spawned_players.clear()
	
	await get_tree().process_frame
	_initialize_spawn_points()
	_initialize_spawner()

func _on_player_spawned(node: Node) -> void:
	print("Player spawned: ", node)
	if node and node.is_in_group("players"):
		print("Position: ", node.spawn_position)
		# Wait for RPC to set position, or use already set spawn_position
		if node.spawn_position != Vector3.ZERO:
			node.call_deferred("_apply_spawn_position", node.spawn_position)
			if node.is_multiplayer_authority():
				node.call_deferred("_set_camera_delayed")

func _initialize_spawn_points() -> void:
	spawn_points = [$"../SpawnPoint", $"../SpawnPoint2", $"../SpawnPoint3", $"../SpawnPoint4"]
	if spawn_points.is_empty():
		print("Failed to initialize spawn points")
	else:
		print("Initialized spawn points")

func _initialize_spawner() -> void:
	if not multiplayer.multiplayer_peer:
		await get_tree().create_timer(0.1).timeout
		if not multiplayer.multiplayer_peer:
			return
	
	if not NetworkConnection.is_multiplayer:
		_spawn_single_player()
		return
	
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_on_peer_connected_spawn)
		rpc("_request_client_id")
		
		for peer_id in multiplayer.get_peers():
			spawn_player(peer_id)
		for player_id in spawned_players.keys():
			var spawn_index = spawned_players[player_id]
			print("Spawn index: ", spawn_index)
			var spawn_position = Vector3(spawn_index * spawn_offset_x, 0, 0)
			
			print("Spawn position for ", spawn_index, ": ", spawn_position)
			
			var player = _find_player_node(player_id)
			if player:
				player.spawn_position = spawn_position
				player.call_deferred("_apply_spawn_position", spawn_position)
				_sync_spawn_position(player_id, spawn_position)
				
				if player.is_multiplayer_authority():
					player.call_deferred("_set_camera_delayed")
	else:
		rpc_id(1, "_receive_client_id", multiplayer.get_unique_id())

func _on_peer_connected_spawn(id: int) -> void:
	rpc_id(id, "_request_client_id")

@rpc("any_peer", "call_local", "unreliable")
func _request_client_id() -> void:
	if not multiplayer.is_server():
		rpc_id(1, "_receive_client_id", multiplayer.get_unique_id())

@rpc("any_peer", "call_local", "unreliable")
func _receive_client_id(client_unique_id: int) -> void:
	if not multiplayer.is_server():
		return
	spawn_player(client_unique_id)

func spawn_player(id: int) -> void:
	if not multiplayer.is_server():
		return
	
	var server_id = multiplayer.get_unique_id()
	if id == server_id:
		return
	
	if network_player == null:
		return
	
	if spawned_players.has(id):
		return
	
	if spawn_points.is_empty():
		print("[SPAWNER] ERROR: No spawn points available!")
		return
	
	if spawned_players.size() >= spawn_points.size():
		print("[SPAWNER] WARNING: Max players reached (", spawn_points.size(), ")")
		return
	
	# Get the next available spawn point index
	var spawn_index = spawned_players.size()
	
	# Store the player's spawn point index
	spawned_players[id] = spawn_index
	
	# Create and configure the new player
	var player: Node = network_player.instantiate()
	if player == null:
		spawned_players.erase(id)
		return
	
	player.name = str(id)
	player.add_to_group("players")
	player.set_multiplayer_authority(id)
	
	var spawn_path_node = get_node(spawn_path)
	if spawn_path_node == null:
		spawned_players.erase(id)
		return
	
	spawn_path_node.add_child(player)
	
	print("Spawned player ", id, " at spawn index ", spawn_index)
	print("Current players: ", spawned_players)
func _get_player_index(player_id: int) -> int:
	var keys = spawned_players.keys()
	for i in range(keys.size()):
		if keys[i] == player_id:
			print(i)
			return i
	return -1

func _find_player_node(player_id: int) -> Node:
	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		if player.name == str(player_id):
			print("Found player: ", player_id)
			return player
	return null

func _sync_spawn_position(player_id: int, position: Vector3) -> void:
	rpc("_set_spawn_position", player_id, position)

@rpc("any_peer", "call_local", "reliable")
func _set_spawn_position(target_player_id: int, position: Vector3) -> void:
	if multiplayer.is_server():
		return
	
	var player = _find_player_node(target_player_id)
	if player:
		player.call_deferred("_apply_spawn_position", position)
		
		if player.is_multiplayer_authority():
			player.call_deferred("_set_camera_delayed")

func _spawn_single_player():
	var player: Node = network_player.instantiate()
	player.name = "1"
	player.add_to_group("players")
	player.set_multiplayer_authority(1)
	
	if spawn_points.is_empty():
		player.spawn_position = $"../SpawnPoint".global_position
	else:
		player.spawn_position = spawn_points[0].global_position
	get_node(spawn_path).call_deferred("add_child", player)
