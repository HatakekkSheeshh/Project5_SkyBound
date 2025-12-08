extends Control
@onready var le_input: LineEdit = $ip_address_enter
@onready var lep_input: LineEdit = $port_enter
@onready var lb_alert: Label = $alert

func _ready() -> void:
	lb_alert.visible = false

func _on_server_pressed() -> void:
	NetworkConnection.start_server()
	get_tree().change_scene_to_file("res://ui/waiting.tscn")

func _on_client_pressed() -> void:
	# Set IP and port from input fields before connecting
	if le_input.text != "":
		NetworkConnection.set_ip(le_input.text)
	if lep_input.text != "":
		NetworkConnection.set_port(lep_input.text.to_int())
	
	# Show connecting message
	lb_alert.visible = true
	lb_alert.text = "Connecting to %s with port: %d..." % [NetworkConnection.ip_addr, NetworkConnection.port]
	lb_alert.modulate = Color.WHITE
	
	# Disconnect before connecting to avoid duplicate connections
	if NetworkConnection.connected.is_connected(on_connected):
		NetworkConnection.connected.disconnect(on_connected)
	if NetworkConnection.connection_failed.is_connected(on_connection_failed):
		NetworkConnection.connection_failed.disconnect(on_connection_failed)
	
	NetworkConnection.connected.connect(on_connected)
	NetworkConnection.connection_failed.connect(on_connection_failed)
	
	NetworkConnection.start_client()

func on_connected():
	lb_alert.text = "Connected successfully!"
	lb_alert.modulate = Color.GREEN
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://ui/waiting.tscn")

func on_connection_failed():
	lb_alert.text = "Connection failed! Check IP and port."
	lb_alert.modulate = Color.RED
	print("Failed to connect to %s:%d" % [NetworkConnection.ip_addr, NetworkConnection.port])
	
func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/menu.tscn")

func _on_ip_address_enter_text_submitted(new_text: String) -> void:
	NetworkConnection.set_ip(new_text)
	if lep_input.text != "":
		NetworkConnection.set_port(lep_input.text.to_int())
	
	lb_alert.visible = true 
	lb_alert.text = "IP set to: %s, Port set to: %d" % [NetworkConnection.ip_addr, NetworkConnection.port]
	lb_alert.modulate = Color.WHITE

func _on_take_df_ip_pressed() -> void:
	var default_ip: String = get_default_ipv4()
	le_input.text = default_ip
	
func _on_submit_pressed() -> void:
	if le_input.text != "":
		NetworkConnection.set_ip(le_input.text)
	if lep_input.text != "":
		NetworkConnection.set_port(lep_input.text.to_int())
	
	lb_alert.visible = true 
	lb_alert.text = "IP set to: %s, Port set to: %d" % [NetworkConnection.ip_addr, NetworkConnection.port]
	lb_alert.modulate = Color.WHITE

func get_default_ipv4() -> String:
	var candidates: Array[String] = []
	for addr in IP.get_local_addresses():
		if addr.find(":") != -1: 
			continue
		if addr.begins_with("127."):
			continue
		candidates.append(addr)	
	for addr in candidates:
		if addr.begins_with("192.168."):
			return addr
	if candidates.size() > 0:
		return candidates[0]
	return "127.0.0.1"


func _on_port_enter_text_submitted(_new_text: String) -> void:
	if lep_input.text != "":
		NetworkConnection.set_port(lep_input.text.to_int())
	if le_input.text != "":
		NetworkConnection.set_ip(le_input.text)
	
	lb_alert.visible = true 
	lb_alert.text = "IP set to: %s, Port set to: %d" % [NetworkConnection.ip_addr, NetworkConnection.port]
	lb_alert.modulate = Color.WHITE
