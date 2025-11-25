extends RigidBody3D
@onready var bat_model: Node3D = $bat_model
#@onready var player = get_node("")
#
#var speed= randf_range(2.0,4.0)

func _physics_process(delta) -> void:
	#var dir=global_position.direction_to(player.global_position)
	#dir.y=0.0
	#linear_velocity=dir*speed
	#bat_model.rotation.y=Vector3.FORWARD.signed_angle_to(dir,Vector3.UP)+PI
	pass
func take_damage():
	bat_model.hurt()
