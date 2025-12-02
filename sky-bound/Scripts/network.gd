extends Control

func _on_server_pressed() -> void:
	print("Server Button pressed")
	NetworkConnection.start_server()
	get_tree().change_scene_to_file("res://Character/Scene/main.tscn")

func _on_client_pressed() -> void:
	print("Client Button pressed")
	NetworkConnection.start_client()
	NetworkConnection.connected.connect(on_connected)
	
func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/menu.tscn")

func on_connected():
	print(">>> network.gd: on_connected() -> change_scene_to_file")
	get_tree().change_scene_to_file("res://Character/Scene/main.tscn")
