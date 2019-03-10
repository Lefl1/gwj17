extends KinematicBody2D

const SPEED = 75
var is_input_blocked

var is_lunging = false
var lunge_dir = Vector2()
const LUNGE_SPEED = 200
const LUNGE_MAX_TIME = 1
var lunge_time = 0
const LUNGE_COOLDOWN_TIME = 2
var lunge_cooldown = LUNGE_COOLDOWN_TIME

var host

func _physics_process(delta):
	if not is_input_blocked:
		move(delta)

	if is_lunging and lunge_time < LUNGE_MAX_TIME:
		lunge_move(delta)
		lunge_time += delta
	else:
		if is_lunging:
			stop_lunge()
		lunge_cooldown += delta



func lunge():
	if lunge_cooldown < LUNGE_COOLDOWN_TIME:
		return
	is_input_blocked = true
	is_lunging = true
	lunge_dir = get_input_dir()


func lunge_move(delta):
	if lunge_dir == Vector2.ZERO:
		stop_lunge()
		return
	var vel = lunge_dir * LUNGE_SPEED * delta
	var col = move_and_collide(vel)
	if col:
		stop_lunge()
		if col.collider.is_in_group("crew"):
			host = col.collider
			get_node("col").set_disabled(true)
			set_visible(false)
			set_global_transform(host.get_global_transform())


func stop_lunge():
	is_input_blocked = false
	is_lunging = false
	lunge_time = 0
	lunge_cooldown = 0
	set_collision_mask_bit(1, true)


func release_host():
	lunge()
	set_collision_mask_bit(1, false)
	var htform = host.get_global_transform()
	set_global_transform(htform)
	lunge_dir = htform.y
	host = null
	get_node("col").set_disabled(false)
	set_visible(true)


func _input(event):
	if event is InputEventKey and event.is_pressed():
		if event.scancode == KEY_SPACE:
			print(is_behind_crew())
			if host and is_behind_crew():
				print("Stabby time")
				host.get_node("front").get_overlapping_bodies()[0].die()
			elif host:
				release_host()
			else:
				lunge()


func is_behind_crew():
	if not host:
		return
	var bodies = host.get_node("front").get_overlapping_bodies()
	for body in bodies:
		if body == host:
			continue
		if body.is_in_group("crew"):
			if not body.is_dead():
				return true

func move(delta):
	var dir = get_input_dir()

	if host:
		host.move_and_slide(dir.normalized() * SPEED)
	else:
		move_and_slide(dir.normalized() * SPEED)


func get_input_dir():
	var dir = Vector2()
	if Input.is_key_pressed(KEY_A):
		dir.x += -1
	if Input.is_key_pressed(KEY_D):
		dir.x += 1
	if Input.is_key_pressed(KEY_W):
		dir.y += -1
	if Input.is_key_pressed(KEY_S):
		dir.y += 1
	return dir	