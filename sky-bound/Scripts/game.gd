extends Node3D
@onready var label: Label = $Label
@onready var death_panel: Panel = $CanvasLayer/DeathPanel
@onready var timer_label: Label = $CanvasLayer/TimerLabel
@onready var game_timer: Timer = $GameTimer

var player_score = 0
@export var scores_per_step := 5

# Timer for multiplayer
@export var game_duration: float = 10.0  # 5 minutes in seconds
var time_remaining: float = 0.0

func _ready() -> void:
	death_panel.hide()
	if multiplayer.is_server() and multiplayer.multiplayer_peer:
		_setup_server_observer_camera()
	
	# Setup timer for multiplayer
	if NetworkConnection.is_multiplayer:
		_setup_multiplayer_timer()
func increase_score(score):
	player_score += score # or += scores_per_step if you want to use that export
	label.text = "Score: " + str(player_score)

func get_current_score():
	return player_score

func _on_mob_spawner_3d_mob_spawned(mob):
	mob.died.connect(func():
		increase_score(1)
	)

func _on_boss_mob_spawner_3d_mob_spawned(mob):
	mob.died.connect(func():
		increase_score(5)
	)
func end_game():
	# Make sure the panel processes while paused
	$CanvasLayer.process_mode = Node.PROCESS_MODE_ALWAYS
	death_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var score_label := death_panel.get_node("FinalScoreLabel") as Label
	if score_label:
		score_label.text = "Score: " + str(player_score)
	# Show the panel and pause gameplay
	death_panel.show()
	get_tree().paused = true

func _on_killplane_body_entered(body: Node3D) -> void:
	# Only handle if the player hits the kill plane
	if body.is_in_group("player") or body.name == "Player":
		# In multiplayer, reset player to spawn position
		if NetworkConnection.is_multiplayer:
			_reset_player_position(body)
		else:
			# In single player, show death panel
			call_deferred("end_game")

func _reset_player_position(player: Node3D) -> void:
	if player.has_method("_apply_spawn_position") and player.spawn_position != Vector3.ZERO:
		player.call_deferred("_apply_spawn_position", player.spawn_position)
		print("[GAME] Resetting player ", player.name, " to spawn position: ", player.spawn_position)

func _setup_multiplayer_timer() -> void:
	if not timer_label or not game_timer:
		print("[GAME] ERROR: TimerLabel or GameTimer not found in scene!")
		return
	
	# Setup timer
	game_timer.wait_time = 1.0  # Update every second
	game_timer.timeout.connect(_on_timer_tick)
	
	# Initialize timer
	if multiplayer.is_server():
		time_remaining = game_duration
		game_timer.start()
		_sync_timer_to_clients()
	else:
		# Request timer from server
		rpc_id(1, "_request_timer")
		game_timer.start()
	
	# Hide timer label initially, show when game starts
	timer_label.visible = true
	_update_timer_display()
	
	print("[GAME] Multiplayer timer setup - Duration: ", game_duration, " seconds")

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
		var minutes: int = total_seconds / 60
		var seconds: int = total_seconds % 60
		timer_label.text = "Time: %02d:%02d" % [minutes, seconds]
		
		# Change color when time is running out
		if time_remaining <= 30:
			timer_label.modulate = Color.RED
		elif time_remaining <= 60:
			timer_label.modulate = Color.YELLOW
		else:
			timer_label.modulate = Color.WHITE

func _end_multiplayer_game() -> void:
	# End game for all players
	rpc("_show_death_panel")
	_show_death_panel()

@rpc("any_peer", "call_local", "reliable")
func _show_death_panel() -> void:
	end_game()

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

func _setup_server_observer_camera() -> void:
	var camera = Camera3D.new()
	camera.name = "ServerObserverCamera"
	camera.position = Vector3(-19, 30, 15)
	camera.rotation_degrees.x = -90
	camera.current = true
	camera.far = 1000.0
	add_child(camera)
	print("[GAME] Server observer camera setup at position: ", camera.position)
