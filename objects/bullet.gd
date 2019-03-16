extends Area2D

const SPEED = 250
var move_dir = Vector2()
var source


func _process(delta):
	translate(move_dir * SPEED * delta)


func _on_Area2D_body_entered(body):
	print(body.get_name())
	if body.get_name() == "object_layer" or body == source:
		return
	elif (body.is_in_group("player") and not body.host) or (body.is_in_group("crew") and body.status == body.POSSESSED):
		body.get_hit()
	queue_free()