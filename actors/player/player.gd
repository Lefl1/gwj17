extends KinematicBody2D

const SPEED = 75
var is_input_blocked = false

enum {NORTH, NORTHEAST, EAST, SOUTHEAST, SOUTH, SOUTHWEST, WEST, NORTHWEST}
const MAX_CARDDIR = 7
const directions_dict = {
	NORTH: 0, NORTHEAST: 45,
	EAST: 90, SOUTHEAST: 135,
	SOUTH: 180, SOUTHWEST: 225,
	WEST: 270, NORTHWEST: 315}
const cardinal_margin = 0.2

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



func lunge(dir = null):
	if lunge_cooldown < LUNGE_COOLDOWN_TIME:
		return
	lunge_time = 0
	is_lunging = true
	if not dir == null:
		lunge_dir = dir
	else:
		lunge_dir = get_input_dir()
	is_input_blocked = true


func lunge_move(delta):
	if not lunge_dir or lunge_dir == Vector2.ZERO:
		stop_lunge()
		return
	var vel = lunge_dir * LUNGE_SPEED * delta
	var col = move_and_collide(vel)
	if col:
		print("hit something")
		stop_lunge()
		if col.collider.is_in_group("crew"):
			host = col.collider
			host.change_state(host.POSSESSED)
			get_node("col").set_disabled(true)
			set_visible(false)
			set_global_transform(host.get_global_transform())


func stop_lunge():
	print("stopped")
	is_lunging = false
	lunge_time = 0
	lunge_cooldown = 0
	set_collision_mask_bit(2, true)
	is_input_blocked = false


func release_host():
	lunge_cooldown = LUNGE_COOLDOWN_TIME
	set_collision_mask_bit(2, false)
	var htform = host.get_global_transform()
	set_global_transform(htform)
	lunge()
	print("STARTED TO LUNGE")
	print(is_lunging)
	host.change_state(host.STUNNED)
	host = null
	get_node("col").set_disabled(false)
	set_visible(true)


func _input(event):
	if event is InputEventKey and event.is_pressed():
		if event.scancode == KEY_SPACE:
			if host and is_behind_crew() and not is_input_blocked:
				print("Stabby time")
				host.get_node("front").get_overlapping_bodies()[0].die()
			elif host and not is_input_blocked:
				release_host()
			elif not is_input_blocked:
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
	return false


func move(delta):
	var dir = get_input_dir()

	if host:
		if dir != Vector2.ZERO:
			host.rotate_to_vdir(dir)
		host.move_and_slide(dir.normalized() * SPEED)
	else:
		# Also rotate!
		move_and_slide(dir.normalized() * SPEED)


func get_rotation_from_dir(dir):
	var cardinal_margin = 0.2
	var direction = 0

	if dir.y > 0 and dir.y > cardinal_margin:
		if dir.x < cardinal_margin and dir.x > -cardinal_margin:
			direction = SOUTH
		elif dir.x > cardinal_margin:
			direction = SOUTHEAST
		elif dir.x < -cardinal_margin:
			direction = SOUTHWEST

	elif dir.y < 0 and dir.y < -cardinal_margin:
		if dir.x < cardinal_margin and dir.x > -cardinal_margin:
			direction = NORTH
		elif dir.x > cardinal_margin:
			direction = NORTHEAST
		elif dir.x < -cardinal_margin:
			direction = NORTHWEST
	elif dir.x > 0:
		direction = EAST
	elif dir.x < 0:
		direction = WEST

	return direction

func get_input_dir():
	if is_input_blocked:
		return

	var dir = Vector2()
	if Input.is_key_pressed(KEY_A):
		dir.x += -1
	if Input.is_key_pressed(KEY_D):
		dir.x += 1
	if Input.is_key_pressed(KEY_W):
		dir.y += -1
	if Input.is_key_pressed(KEY_S):
		dir.y += 1
	return dir.normalized()