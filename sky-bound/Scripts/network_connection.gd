extends Node

signal connected
signal connection_failed

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
	# ENetMultiplayerPeer.create_server() binds to all interfaces by default
	# This allows external connections through ngrok
	var error = peer.create_server(port, 4)
	if error != OK:
		print("ERROR: Failed to create server on port %d. Error code: %d" % [port, error])
		return
	multiplayer.multiplayer_peer = peer
	print("Server started on port %d (listening on all interfaces)" % port)

func close_server() -> void:
	peer.close()
	
func start_client() -> void:
	is_multiplayer = true
	peer = ENetMultiplayerPeer.new()
	
	print("Attempting to connect to %s:%d" % [ip_addr, port])
	
	var error = peer.create_client(ip_addr, port)
	if error != OK:
		print("ERROR: Failed to create client. Error code: %d" % error)
		emit_signal("connection_failed")
		return
	
	multiplayer.multiplayer_peer = peer 
	
	# Disconnect before connecting to avoid duplicate connections
	if multiplayer.connected_to_server.is_connected(_on_connected):
		multiplayer.connected_to_server.disconnect(_on_connected)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)
	
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	
	print("Client created, waiting for connection...")
	
func _on_connected():
	print("Successfully connected to server!")
	emit_signal("connected")	

func _on_connection_failed():
	print("Connection failed to %s:%d" % [ip_addr, port])
	print("Possible causes:")
	print("  - Server is not running")
	print("  - Wrong IP address or port")
	print("  - Firewall blocking connection")
	print("  - Ngrok tunnel not active")
	emit_signal("connection_failed")
