extends Node3D

var player_score = 0
@onready var label: Label = $Label

@export var scores_per_step:=5

func increase_score():
	player_score += 1
	label.text = "Score: " + str(player_score)


func get_current_score():
	return player_score


func _on_mob_spawner_3d_mob_spawned(mob):
	mob.died.connect(func():
		increase_score()
	)


func _on_kill_plane_body_entered(body):
	get_tree().reload_current_scene.call_deferred()
