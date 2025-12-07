extends Control

func _on_single_pressed() -> void:
	get_tree().change_scene_to_file("res://Character/Scene/main.tscn")

func _on_multi_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/network_ui.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
