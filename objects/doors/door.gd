extends StaticBody2D

enum {BLUE, YELLOW, RED}

var type
var is_closed = true
var sprites
var col


func _ready():
	sprites = get_node("sprites")
	col = get_node("col")
	print(sprites)

func toggle(crew_type):
	if crew_type == type:
		is_closed = !is_closed
		print(is_closed)
		set_type()


func set_type(t = null):
	if not t == null:
		type = t
	if t == BLUE or (t == null and type == BLUE):
		sprites.get_node("blue_closed").set_visible(is_closed)
		sprites.get_node("blue_open").set_visible(!is_closed)
	elif t == YELLOW or (t == null and type == YELLOW):
		sprites.get_node("yellow_closed").set_visible(is_closed)
		sprites.get_node("yellow_open").set_visible(!is_closed)
	elif t == RED or (t == null and type == RED):
		sprites.get_node("red_closed").set_visible(is_closed)
		sprites.get_node("red_open").set_visible(!is_closed)
	
	col.set_disabled(!is_closed)