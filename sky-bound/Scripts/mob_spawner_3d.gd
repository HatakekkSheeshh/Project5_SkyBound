extends Node3D
signal mob_spawned(mob)
signal boss_mob_spawned(mob)
@export var mob_to_spawn: PackedScene =null
@export var boss_mob_to_spawn: PackedScene =null
@export_range(0.0, 1.0) var boss_bat_spawn_chance: float = 0.2
@onready var marker_3d: Marker3D = $Marker3D
@onready var timer: Timer = $Timer
@onready var timer_2: Timer = $Timer2

func _on_timer_timeout():
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	
	var spawn_pos = marker_3d.global_position
	rpc("_spawn_mob_on_all_clients", spawn_pos)
	_spawn_mob_on_all_clients(spawn_pos)

@rpc("any_peer", "call_local", "reliable")
func _spawn_mob_on_all_clients(spawn_pos: Vector3) -> void:
	if mob_to_spawn == null:
		return
	
	var new_mob = mob_to_spawn.instantiate()
	add_child(new_mob)
	new_mob.global_position = spawn_pos
	mob_spawned.emit(new_mob)
	

func _on_timer_2_timeout() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	
	var spawn_pos = marker_3d.global_position
	rpc("_spawn_boss_mob_on_all_clients", spawn_pos)
	_spawn_boss_mob_on_all_clients(spawn_pos)

@rpc("any_peer", "call_local", "reliable")
func _spawn_boss_mob_on_all_clients(spawn_pos: Vector3) -> void:
	if boss_mob_to_spawn == null:
		return
	
	var new_boss_mob = boss_mob_to_spawn.instantiate()
	add_child(new_boss_mob)
	new_boss_mob.global_position = spawn_pos
	boss_mob_spawned.emit(new_boss_mob)
