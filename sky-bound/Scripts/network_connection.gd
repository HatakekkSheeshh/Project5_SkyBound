extends Node

signal connected

var ip_addr: String = "localhost"
var port:int = 42069

var peer: ENetMultiplayerPeer
var is_multiplayer := false

func set_ip(addr: String) -> void:
	ip_addr = addr.strip_edges()

func set_port(pt: int) -> void:
	port = pt

func start_server() -> void:
	is_multiplayer = true
	peer = ENetMultiplayerPeer.new()
	peer.create_server(port, 4)
	multiplayer.multiplayer_peer = peer

func close_server() -> void:
	peer.close()
	
func start_client() -> void:
	is_multiplayer = true
	peer = ENetMultiplayerPeer.new()
	peer.create_client(ip_addr, port)
	multiplayer.multiplayer_peer = peer 
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	
func _on_connected():
	emit_signal("connected")	

func _on_connection_failed():
	pass
