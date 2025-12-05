extends Control
@onready var le_input: LineEdit = $ip_address_enter
@onready var lb_alert: Label = $alert

func _ready() -> void:
	lb_alert.visible = false

func _on_server_pressed() -> void:
	print("Server Button pressed")
	NetworkConnection.start_server()
	get_tree().change_scene_to_file("res://ui/waiting.tscn")

func _on_client_pressed() -> void:
	print("Client Button pressed")
	NetworkConnection.start_client()
	NetworkConnection.connected.connect(on_connected)

func on_connected():
	print("[NETWORK UI] connected -> change to [WAITING] mode")
	get_tree().change_scene_to_file("res://ui/waiting.tscn")
	
func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/menu.tscn")

func _on_ip_address_enter_text_submitted(new_text: String) -> void:
	print("[NETWORK UI] ", new_text)
	
	lb_alert.visible = true 
	lb_alert.text = "Connecting to %s" % le_input.text
	
	NetworkConnection.set_ip(new_text)

func _on_take_df_ip_pressed() -> void:
	var default_ip: String = get_default_ipv4()
	le_input.text = default_ip
	
func _on_submit_pressed() -> void:
	print("[NETWORK UI] ", le_input.text)
	
	if le_input.text != "" or le_input.text:
		lb_alert.visible = true 
		lb_alert.text = "Connecting to %s" % le_input.text
		
	NetworkConnection.set_ip(le_input.text)

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
