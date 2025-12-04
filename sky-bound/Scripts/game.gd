extends Node3D
@onready var label: Label = $Label
@onready var death_panel: Panel = $CanvasLayer/DeathPanel


var player_score = 0
@export var scores_per_step := 5

func _ready() -> void:
	death_panel.hide()
func increase_score(score):
	player_score += score # or += scores_per_step if you want to use that export
	label.text = "Score: " + str(player_score)

func get_current_score():
	return player_score

func _on_mob_spawner_3d_mob_spawned(mob):
	mob.died.connect(func():
		increase_score(1)
	)

func _on_boss_mob_spawner_3d_mob_spawned(mob):
	mob.died.connect(func():
		increase_score(5)
	)
func end_game():
	# Make sure the panel processes while paused
	$CanvasLayer.process_mode = Node.PROCESS_MODE_ALWAYS
	death_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var score_label := death_panel.get_node("FinalScoreLabel") as Label
	if score_label:
		score_label.text = "Score: " + str(player_score)
	# Show the panel and pause gameplay
	death_panel.show()
	get_tree().paused = true

func _on_killplane_body_entered(body: Node3D) -> void:
	# Only end the game if the player hits the kill plane
	if body.is_in_group("player") or body.name == "Player":
		call_deferred("end_game")
