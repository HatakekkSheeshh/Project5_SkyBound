extends Node3D
@onready var label: Label = $Label
@onready var death_panel: Panel = $CanvasLayer/DeathPanel
@onready var timer_label: Label = $CanvasLayer/TimerLabel
@onready var game_timer: Timer = $GameTimer

var player_score = 0
@export var scores_per_step := 5

var player_scores: Dictionary = {}
var player_names: Dictionary = {}
var next_player_number: int = 1

@export var game_duration: float = 10
var time_remaining: float = 0.0

var players_ready_to_retry: Dictionary = {}

func _ready() -> void:
	add_to_group("game")
	death_panel.hide()
	if multiplayer.is_server() and multiplayer.multiplayer_peer:
		_setup_server_observer_camera()
	
	if NetworkConnection.is_multiplayer:
		_initialize_player_scores()
		_setup_multiplayer_timer()

func increase_score(score):
	player_score += score
	label.text = "Score: " + str(player_score)

func _increase_local_score_optimistic(peer_id: int, score: int) -> void:
	if multiplayer.is_server():
		return
	
	var my_id = multiplayer.get_unique_id()
	if peer_id == my_id:
		if peer_id not in player_scores:
			player_scores[peer_id] = 0
		player_scores[peer_id] += score
		_update_score_display()

func _increase_player_score(peer_id: int, score: int) -> void:
	if not multiplayer.is_server():
		return
	
	if peer_id not in player_scores:
		player_scores[peer_id] = 0
		if peer_id not in player_names:
			player_names[peer_id] = "Player %d" % next_player_number
			next_player_number += 1
	
	player_scores[peer_id] += score
	
	_sync_scores_to_clients()
	_update_score_display()

func get_current_score():
	return player_score

func _on_mob_spawner_3d_mob_spawned(mob):
	if multiplayer.is_server():
		mob.died.connect(func(killer_id: int):
			_increase_player_score(killer_id, 1)
		)

func _on_boss_mob_spawner_3d_mob_spawned(mob):
	if multiplayer.is_server():
		mob.died.connect(func(killer_id: int):
			_increase_player_score(killer_id, 5)
		)

func end_game(winner_name: String = "", winner_score: int = 0):
	if NetworkConnection.is_multiplayer and multiplayer.is_server():
		return
	
	$CanvasLayer.process_mode = Node.PROCESS_MODE_ALWAYS
	death_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var score_label := death_panel.get_node("FinalScoreLabel") as Label
	if score_label:
		if NetworkConnection.is_multiplayer and winner_name != "":
			score_label.text = "Winner: %s\nScore: %d" % [winner_name, winner_score]
		else:
			score_label.text = "Score: " + str(player_score)
	
	if NetworkConnection.is_multiplayer:
		players_ready_to_retry.clear()
		_setup_retry_button()
		_setup_quit_button()
	
	death_panel.show()
	get_tree().paused = true

func _setup_retry_button() -> void:
	var retry_button = _find_retry_button()
	
	if retry_button:
		var connections = retry_button.pressed.get_connections()
		for connection in connections:
			retry_button.pressed.disconnect(connection.callable)
		
		retry_button.pressed.connect(_on_retry_button_pressed)
		retry_button.text = "RETRY"

func _setup_quit_button() -> void:
	var quit_button = _find_quit_button()
	
	if quit_button:
		var connections = quit_button.pressed.get_connections()
		for connection in connections:
			quit_button.pressed.disconnect(connection.callable)
		
		quit_button.pressed.connect(_on_quit_button_pressed)

func _find_quit_button() -> Button:
	var quit_button = death_panel.get_node_or_null("Quit") as Button
	if not quit_button:
		quit_button = death_panel.get_node_or_null("QuitButton") as Button
	if not quit_button:
		quit_button = death_panel.get_node_or_null("VBoxContainer/QuitButton") as Button
	if not quit_button:
		for child in death_panel.get_children():
			if child is Button:
				var btn_name = child.name.to_lower()
				if "quit" in btn_name:
					quit_button = child as Button
					break
	return quit_button

func _on_retry_button_pressed() -> void:
	if not NetworkConnection.is_multiplayer:
		_restart_game()
		return
	
	var my_id = multiplayer.get_unique_id()
	if my_id not in players_ready_to_retry:
		players_ready_to_retry[my_id] = true
		_update_local_retry_button_text()
	
	rpc_id(1, "_player_ready_to_retry", my_id)

func _on_quit_button_pressed() -> void:
	if not NetworkConnection.is_multiplayer:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://ui/menu.tscn")
		return
	
	var my_id = multiplayer.get_unique_id()
	rpc_id(1, "_player_quitting", my_id)
	_handle_player_quit()

func _handle_player_quit() -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ui/menu.tscn")

@rpc("any_peer", "call_local", "reliable")
func _player_quitting(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	
	if peer_id in player_scores:
		player_scores.erase(peer_id)
	if peer_id in player_names:
		player_names.erase(peer_id)
	if peer_id in players_ready_to_retry:
		players_ready_to_retry.erase(peer_id)
	
	if multiplayer.has_multiplayer_peer():
		var peer = multiplayer.multiplayer_peer
		if peer:
			if peer.has_method("disconnect_peer"):
				peer.disconnect_peer(peer_id)
			else:
				peer.close()
	
	var remaining_players = []
	for pid in player_scores.keys():
		if pid != 1:
			remaining_players.append(pid)
	
	if remaining_players.size() > 0:
		var ready_count = players_ready_to_retry.size()
		var total_count = remaining_players.size()
		rpc("_update_retry_status", ready_count, total_count)
		
		var all_ready = true
		for player_id in remaining_players:
			if player_id not in players_ready_to_retry or not players_ready_to_retry[player_id]:
				all_ready = false
				break
		
		if all_ready and remaining_players.size() > 0:
			await get_tree().process_frame
			await get_tree().process_frame
			rpc("_restart_game")
			call_deferred("_restart_game")

@rpc("any_peer", "call_local", "reliable")
func _player_ready_to_retry(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	
	players_ready_to_retry[peer_id] = true
	
	var players_in_game = []
	for peer_id_key in player_scores.keys():
		if peer_id_key != 1:
			players_in_game.append(peer_id_key)
	
	var players_to_remove = []
	for ready_player_id in players_ready_to_retry.keys():
		if ready_player_id not in players_in_game:
			players_to_remove.append(ready_player_id)
	
	for player_id in players_to_remove:
		players_ready_to_retry.erase(player_id)
	
	var ready_count = 0
	for player_id in players_in_game:
		if player_id in players_ready_to_retry and players_ready_to_retry[player_id]:
			ready_count += 1
	
	var total_count = players_in_game.size()
	rpc("_update_retry_status", ready_count, total_count)
	
	var all_ready = false
	if players_in_game.size() > 0:
		all_ready = true
		for player_id in players_in_game:
			if player_id not in players_ready_to_retry or not players_ready_to_retry[player_id]:
				all_ready = false
				break
	
	if all_ready:
		await get_tree().process_frame
		await get_tree().process_frame
		rpc("_restart_game")
		call_deferred("_restart_game")

func _update_local_retry_button_text() -> void:
	var retry_button = _find_retry_button()
	if not retry_button:
		return
	
	var players_in_game = []
	for peer_id_key in player_scores.keys():
		if peer_id_key != 1:
			players_in_game.append(peer_id_key)
	
	var ready_count = players_ready_to_retry.size()
	var total_count = players_in_game.size()
	
	if ready_count < total_count and total_count > 0:
		retry_button.text = "RETRY (%d/%d)" % [ready_count, total_count]
	else:
		retry_button.text = "RETRY"

func _find_retry_button() -> Button:
	var retry_button = death_panel.get_node_or_null("Retry") as Button
	if not retry_button:
		retry_button = death_panel.get_node_or_null("RetryButton") as Button
	if not retry_button:
		retry_button = death_panel.get_node_or_null("VBoxContainer/RetryButton") as Button
	if not retry_button:
		for child in death_panel.get_children():
			if child is Button:
				var btn_name = child.name.to_lower()
				if "retry" in btn_name:
					retry_button = child as Button
					break
	return retry_button

@rpc("any_peer", "call_local", "reliable")
func _update_retry_status(ready_count: int, total_count: int) -> void:
	var retry_button = _find_retry_button()
	if not retry_button:
		return
	
	if ready_count < total_count and total_count > 0:
		retry_button.text = "RETRY (%d/%d)" % [ready_count, total_count]
	else:
		retry_button.text = "RETRY"

@rpc("any_peer", "call_local", "reliable")
func _restart_game() -> void:
	var tree = get_tree()
	if not is_instance_valid(tree):
		return
	
	tree.paused = false
	
	if is_instance_valid(death_panel):
		death_panel.hide()
	
	player_scores.clear()
	player_names.clear()
	players_ready_to_retry.clear()
	next_player_number = 1
	time_remaining = game_duration
	
	call_deferred("_do_scene_reload")

func _do_scene_reload() -> void:
	var tree = get_tree()
	if is_instance_valid(tree):
		tree.reload_current_scene()

func _on_killplane_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		if NetworkConnection.is_multiplayer:
			_reset_player_position(body)
		else:
			call_deferred("end_game")

func _reset_player_position(player: Node3D) -> void:
	if player.has_method("_apply_spawn_position") and player.spawn_position != Vector3.ZERO:
		player.call_deferred("_apply_spawn_position", player.spawn_position)

func _setup_multiplayer_timer() -> void:
	if not timer_label or not game_timer:
		return
	
	game_timer.wait_time = 1.0
	game_timer.timeout.connect(_on_timer_tick)
	
	if multiplayer.is_server():
		time_remaining = game_duration
		game_timer.start()
		_sync_timer_to_clients()
	else:
		rpc_id(1, "_request_timer")
		game_timer.start()
	
	timer_label.visible = true
	_update_timer_display()

func _on_timer_tick() -> void:
	if not NetworkConnection.is_multiplayer:
		return
	
	if multiplayer.is_server():
		time_remaining -= 1.0
		if time_remaining <= 0:
			time_remaining = 0
			_end_multiplayer_game()
		else:
			_sync_timer_to_clients()
	
	_update_timer_display()

func _update_timer_display() -> void:
	if timer_label:
		var total_seconds = int(time_remaining)
		var minutes: int = int(total_seconds / 60.0)
		var seconds: int = total_seconds % 60
		timer_label.text = "Time: %02d:%02d" % [minutes, seconds]
		
		if time_remaining <= 30:
			timer_label.modulate = Color.RED
		elif time_remaining <= 60:
			timer_label.modulate = Color.YELLOW
		else:
			timer_label.modulate = Color.WHITE

func _end_multiplayer_game() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	
	_sync_scores_to_clients()
	await get_tree().process_frame
	
	var winner_id = _find_winner()
	var winner_name = player_names.get(winner_id, "Unknown")
	var winner_score = player_scores.get(winner_id, 0)
	
	rpc("_show_death_panel", winner_name, winner_score)
	_show_death_panel(winner_name, winner_score)

@rpc("any_peer", "call_local", "reliable")
func _show_death_panel(winner_name: String = "", winner_score: int = 0) -> void:
	end_game(winner_name, winner_score)

func _sync_timer_to_clients() -> void:
	if multiplayer.is_server():
		rpc("_update_timer", time_remaining)

@rpc("any_peer", "call_local", "reliable")
func _update_timer(new_time: float) -> void:
	if not multiplayer.is_server():
		time_remaining = new_time
		_update_timer_display()

@rpc("any_peer", "call_local", "unreliable")
func _request_timer() -> void:
	if multiplayer.is_server():
		_sync_timer_to_clients()

@rpc("any_peer", "call_local", "reliable")
func _request_scores() -> void:
	if multiplayer.is_server():
		_sync_scores_to_clients()

func _initialize_player_scores() -> void:
	if multiplayer.is_server():
		player_scores.clear()
		player_names.clear()
		next_player_number = 1
		
		var peers = multiplayer.get_peers()
		
		for peer_id in peers:
			if peer_id not in player_scores:
				player_scores[peer_id] = 0
				player_names[peer_id] = "Player %d" % next_player_number
				next_player_number += 1
		
		_sync_scores_to_clients()
		get_tree().node_added.connect(_on_node_added)
	else:
		rpc_id(1, "_request_scores")

func _on_node_added(node: Node) -> void:
	if node.is_in_group("players") and multiplayer.is_server():
		var peer_id = node.name.to_int()
		if peer_id not in player_scores:
			player_scores[peer_id] = 0
		if peer_id not in player_names:
			player_names[peer_id] = "Player %d" % next_player_number
			next_player_number += 1
		_sync_scores_to_clients()

@rpc("any_peer", "call_local", "reliable")
func _update_player_score(peer_id: int, score: int) -> void:
	if not multiplayer.is_server():
		return
	
	if peer_id not in player_names:
		player_names[peer_id] = "Player %d" % next_player_number
		next_player_number += 1
	
	player_scores[peer_id] = score
	_sync_scores_to_clients()
	_update_score_display()

func _sync_scores_to_clients() -> void:
	if multiplayer.is_server():
		rpc("_receive_scores", player_scores, player_names)

@rpc("any_peer", "call_local", "reliable")
func _receive_scores(scores: Dictionary, names: Dictionary) -> void:
	player_scores = scores.duplicate()
	player_names = names.duplicate()
	
	var max_num = 0
	for name_str in names.values():
		var num_str = name_str.replace("Player ", "")
		var num = num_str.to_int()
		if num > max_num:
			max_num = num
	next_player_number = max_num + 1
	
	if not multiplayer.is_server():
		var my_id = multiplayer.get_unique_id()
		if my_id in player_scores:
			player_score = player_scores[my_id]
	
	_update_score_display()

func _update_score_display() -> void:
	if not label:
		return
	
	if NetworkConnection.is_multiplayer:
		var score_text = ""
		var sorted_players = []
		
		for peer_id in player_scores.keys():
			sorted_players.append(peer_id)
		sorted_players.sort()
		
		for peer_id in sorted_players:
			var player_name = player_names.get(peer_id, "Player ?")
			var score = player_scores.get(peer_id, 0)
			score_text += "%s: %d\n" % [player_name, score]
		
		label.text = score_text.strip_edges()
	else:
		label.text = "Score: " + str(player_score)

func _find_winner() -> int:
	var winner_id = -1
	var highest_score = -1
	
	for peer_id in player_scores.keys():
		var score = player_scores.get(peer_id, 0)
		if score > highest_score:
			highest_score = score
			winner_id = peer_id
	
	return winner_id

func _setup_server_observer_camera() -> void:
	var camera = Camera3D.new()
	camera.name = "ServerObserverCamera"
	camera.position = Vector3(-19, 30, 15)
	camera.rotation_degrees.x = -90
	camera.current = true
	camera.far = 1000.0
	add_child(camera)
