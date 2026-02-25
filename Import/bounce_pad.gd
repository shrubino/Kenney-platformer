extends StaticBody3D


@export var bounce_power = 30
func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("PLayer"):
		body.velocity.y += bounce_power
		$AudioStreamPlayer3D.play()
