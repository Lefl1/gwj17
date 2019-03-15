extends Control

# Declare member variables here. Examples:
# var a = 2
# var b = "text"
onready var menu = preload("res://menu/menu.tscn")
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_just_pressed("ui_accept"):
		$AnimationPlayer.play("fade")
		
	pass


func _on_AnimationPlayer_animation_finished(anim_name):
	if anim_name == 'fade':
		$Control.hide()
		$Label.hide()
		var s = menu.instance()
		add_child(s)
	pass
