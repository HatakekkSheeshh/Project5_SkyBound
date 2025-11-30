extends RigidBody3D
@onready var bat_model: Node3D = $bat_model
@onready var player = get_parent().get_parent().get_node("Player") #Add player's node
@onready var timer: Timer = $Timer
@onready var hurt_sound: AudioStreamPlayer3D = $HurtSound
@onready var dead_sound: AudioStreamPlayer3D = $DeadSound

signal died

var health= 3
var speed= randf_range(2.0,4.0)

func _physics_process(delta) -> void:
	var dir=global_position.direction_to(player.global_position)
	dir.y=0.0
	linear_velocity=dir*speed
	bat_model.rotation.y=Vector3.FORWARD.signed_angle_to(dir,Vector3.UP)+PI



func take_damage():
	if health<0:
		return
	
	bat_model.hurt()
	hurt_sound.play()
	health-=1
	if health ==0:
		set_physics_process(false)
		gravity_scale= 1.0
		var direction = -1.0 * global_position.direction_to(player.global_position)
		var random_upward_force = Vector3.UP * randf() * 5.0
		apply_central_impulse(direction.rotated(Vector3.UP, randf_range(-0.2, 0.2)) * 10.0 + random_upward_force)
		dead_sound.play()
		timer.start()


func _on_timer_timeout():
	queue_free()
	died.emit()
