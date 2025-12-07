extends Control

@onready var list_box := $VBoxContainer
@onready var peer_template := $VBoxContainer/peer
@onready var cur_pla_lb := $cur_pla_lb
@onready var animation := $waiting_animation
@onready var ip_addr := $ip_addr_lb

var peer_labels: = {}
var ready_peers: = {}
var peer_id_to_display: = {}
var next_display_number: int = 1

func _ready() -> void:
	if !multiplayer.is_server():
		$server_lb.visible = false	
		
	animation.play("new_animation")
	ip_addr.text = "Current IP Address: %s" % NetworkConnection.ip_addr
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		
		$waiting_lb.visible = false
		animation.play("server_run_anime")
	else:
		rpc_id(1, "_request_peer_list")

@rpc("any_peer", "call_local", "reliable")
func _request_peer_list() -> void:
	if !multiplayer.is_server():
		return
	var requester_id = multiplayer.get_remote_sender_id()

	var display_num = 1
	for peer_id in multiplayer.get_peers():
		if peer_id not in peer_id_to_display:
			peer_id_to_display[peer_id] = display_num
			display_num += 1
		rpc_id(requester_id, "_add_peer_label", peer_id, peer_id_to_display[peer_id])
		
		if ready_peers.get(peer_id, false):
			rpc_id(requester_id, "_set_peer_ready", peer_id, true, peer_id_to_display[peer_id])
	rpc_id(requester_id, "_refresh_count")

func _on_peer_connected(id: int) -> void:
	if id not in peer_id_to_display:
		peer_id_to_display[id] = next_display_number
		next_display_number += 1
	var display_num = peer_id_to_display[id]
	_add_peer_label(id, display_num)
	_refresh_count()

	rpc("_add_peer_label", id, display_num)
	rpc("_refresh_count")

func _on_peer_disconnected(id: int) -> void:
	_remove_peer_label(id)
	ready_peers.erase(id)  
	_refresh_count()

	rpc("_remove_peer_label", id)
	rpc("_refresh_count")
	_check_all_ready()  

func _on_back_lb_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/menu.tscn")

@rpc("any_peer", "call_local", "reliable")
func _add_peer_label(id: int, display_num: int = -1) -> void:
	if peer_labels.has(id):
		return
	
	if display_num == -1:
		if id not in peer_id_to_display:
			peer_id_to_display[id] = next_display_number
			next_display_number += 1
		display_num = peer_id_to_display[id]
	
	var lb := peer_template.duplicate()
	lb.visible = true
	lb.text = "Player %d" % display_num
	list_box.add_child(lb)
	peer_labels[id] = lb
	if ready_peers.get(id, false):
		_update_peer_label_ready(id, true)

@rpc("any_peer", "call_local", "reliable")
func _remove_peer_label(id: int) -> void:
	if !peer_labels.has(id):
		return
	peer_labels[id].queue_free()
	peer_labels.erase(id)

@rpc("any_peer", "call_local", "reliable")
func _refresh_count() -> void:
	var count := peer_labels.size()
	if cur_pla_lb:
		cur_pla_lb.text = "Current players waiting: %d/4" % count
		
func _on_ready_lb_pressed() -> void:
	if multiplayer.is_server():
		var server_id = multiplayer.get_unique_id()
		if server_id not in peer_id_to_display:
			peer_id_to_display[server_id] = next_display_number
			next_display_number += 1
		var display_num = peer_id_to_display[server_id]
		_set_peer_ready(server_id, true)
		rpc("_set_peer_ready", server_id, true, display_num)
		_check_all_ready()
	else:
		var client_id = multiplayer.get_unique_id()
		rpc_id(1, "_receive_ready", client_id)

@rpc("any_peer", "call_local", "reliable")
func _receive_ready(peer_id: int) -> void:
	if !multiplayer.is_server():
		return
	
	if peer_id not in peer_id_to_display:
		peer_id_to_display[peer_id] = next_display_number
		next_display_number += 1
	var display_num = peer_id_to_display[peer_id]
	
	_set_peer_ready(peer_id, true)
	rpc("_set_peer_ready", peer_id, true, display_num)
	_check_all_ready()

@rpc("any_peer", "call_local", "reliable")
func _set_peer_ready(peer_id: int, is_ready: bool, display_num: int = -1) -> void:
	ready_peers[peer_id] = is_ready
	
	if display_num != -1 and peer_id not in peer_id_to_display:
		peer_id_to_display[peer_id] = display_num
	
	_update_peer_label_ready(peer_id, is_ready)

func _update_peer_label_ready(peer_id: int, is_ready: bool) -> void:
	if !peer_labels.has(peer_id):
		return
	
	if peer_id not in peer_id_to_display:
		peer_id_to_display[peer_id] = next_display_number
		next_display_number += 1
	
	var display_num = peer_id_to_display[peer_id]
	var lb = peer_labels[peer_id]
	if is_ready:
		lb.text = "Player %d   READY" % display_num
		lb.modulate = Color.GREEN  
	else:
		lb.text = "Player %d" % display_num
		lb.modulate = Color.WHITE 

func _check_all_ready() -> void:
	if !multiplayer.is_server():
		return
	
	var all_peers = []
	for peer_id in multiplayer.get_peers():
		all_peers.append(peer_id)
	
	var all_ready = true
	for peer_id in all_peers:
		if !ready_peers.get(peer_id, false):
			all_ready = false
			break
	
	if all_ready and all_peers.size() > 0:
		rpc("_go_to_game")

@rpc("any_peer", "call_local", "reliable")
func _go_to_game() -> void:
	if multiplayer.multiplayer_peer:
		pass
	var timer = get_tree().create_timer(0.5)
	timer.timeout.connect(func():
		get_tree().change_scene_to_file("res://Character/Scene/main.tscn")
	)
