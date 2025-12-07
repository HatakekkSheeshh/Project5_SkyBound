extends Panel
func _on_retry_button_pressed():
	if NetworkConnection.is_multiplayer:
		return
	
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_quit_button_pressed():
	if NetworkConnection.is_multiplayer:
		return
	
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ui/menu.tscn")
