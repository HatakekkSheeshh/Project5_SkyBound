extends Node3D
signal mob_spawned(mob)
signal boss_mob_spawned(mob)
@export var mob_to_spawn: PackedScene =null
@export var boss_mob_to_spawn: PackedScene =null
@onready var marker_3d: Marker3D = $Marker3D
@onready var timer: Timer = $Timer
@onready var timer_2: Timer = $Timer2

func _on_timer_timeout():
	var new_mob=mob_to_spawn.instantiate()
	add_child(new_mob)
	new_mob.global_position=marker_3d.global_position
	mob_spawned.emit(new_mob)
	var new_boss_mob=boss_mob_to_spawn.instantiate()
	add_child(new_boss_mob)
	new_boss_mob.global_position=marker_3d.global_position
	boss_mob_spawned.emit(new_boss_mob)
	



func _on_timer_2_timeout() -> void:
	var new_boss_mob=boss_mob_to_spawn.instantiate()
	add_child(new_boss_mob)
	new_boss_mob.global_position=marker_3d.global_position
	boss_mob_spawned.emit(new_boss_mob)
