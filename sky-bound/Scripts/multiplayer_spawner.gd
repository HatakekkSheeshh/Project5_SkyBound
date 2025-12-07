extends MultiplayerSpawner

@export var network_player: PackedScene
@export var spawn_offset_x: float = 5.0

var spawn_point: Node = null
var spawned_players: Dictionary = {}  # player_id -> position

func _ready() -> void:
	spawned.connect(_on_player_spawned)
	spawned_players.clear()
	
	await get_tree().process_frame
	_initialize_spawn_point()
	_initialize_spawner()

func _on_player_spawned(node: Node) -> void:
	if node and node.is_in_group("players"):
		# Wait for RPC to set position, or use already set spawn_position
		if node.spawn_position != Vector3.ZERO:
			node.call_deferred("_apply_spawn_position", node.spawn_position)
			if node.is_multiplayer_authority():
				node.call_deferred("_set_camera_delayed")

func _initialize_spawn_point() -> void:
	spawn_point = $"../SpawnPoint"
	if spawn_point == null:
		print("[SPAWNER] ERROR: SpawnPoint not found!")
	else:
		print("[SPAWNER] SpawnPoint at position: ", spawn_point.global_position)

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
	
	if spawned_players.size() >= 4:
		return
	
	if spawn_point == null:
		return
	
	# STEP 1: Move all existing players to create space
	var base_position = spawn_point.global_position
	var existing_players = spawned_players.duplicate()
	
	for existing_id in existing_players.keys():
		var player_index = _get_player_index(existing_id)
		var new_position = base_position + Vector3((player_index + 1) * spawn_offset_x, 0, 0)
		
		# Update stored position
		spawned_players[existing_id] = new_position
		
		# Move the actual player node
		var player_node = _find_player_node(existing_id)
		if player_node:
			player_node.spawn_position = new_position
			player_node.call_deferred("_apply_spawn_position", new_position)
			_sync_spawn_position(existing_id, new_position)
	
	# STEP 2: Spawn new player at base position
	spawned_players[id] = base_position
	
	var player: Node = network_player.instantiate()
	if player == null:
		spawned_players.erase(id)
		return
	
	player.name = str(id)
	player.add_to_group("players")
	player.set_multiplayer_authority(id)
	player.spawn_position = base_position
	
	var spawn_path_node = get_node(spawn_path)
	if spawn_path_node == null:
		spawned_players.erase(id)
		return
	
	spawn_path_node.add_child(player)
	player.call_deferred("_apply_spawn_position", base_position)
	
	_sync_spawn_position(id, base_position)

func _get_player_index(player_id: int) -> int:
	var keys = spawned_players.keys()
	for i in range(keys.size()):
		if keys[i] == player_id:
			return i
	return -1

func _find_player_node(player_id: int) -> Node:
	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		if player.name == str(player_id):
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
		player.spawn_position = position
		player.call_deferred("_apply_spawn_position", position)
		
		if player.is_multiplayer_authority():
			player.call_deferred("_set_camera_delayed")

func _spawn_single_player():
	var player: Node = network_player.instantiate()
	player.name = "1"
	player.add_to_group("players")
	player.set_multiplayer_authority(1)
	
	if spawn_point == null:
		spawn_point = $"../SpawnPoint"
	
	player.spawn_position = spawn_point.global_position
	get_node(spawn_path).call_deferred("add_child", player)
