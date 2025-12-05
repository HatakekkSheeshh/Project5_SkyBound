extends Node

signal connected

var ip_addr: String = "localhost"
const PORT:int = 42069

var peer: ENetMultiplayerPeer
var is_multiplayer := false

func set_ip(addr: String) -> void:
	ip_addr = addr.strip_edges()

func start_server() -> void:
	is_multiplayer = true
	peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT, 4)
	multiplayer.multiplayer_peer = peer
	
func start_client() -> void:
	is_multiplayer = true
	peer = ENetMultiplayerPeer.new()
	peer.create_client(ip_addr, PORT)
	multiplayer.multiplayer_peer = peer 
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	
func _on_connected():
	print(">>> NetworkConnection: connected_to_server fired")
	emit_signal("connected")	

func _on_connection_failed():
	print(">>> NetworkConnection: connection_failed")
