extends KinematicBody2D

var dead = false

enum Roles {CAPTAIN, ENGINEER, ANALYST}
export (Roles) var role
enum {IDLE, MOVING, INTERACTING, HUNTING, POSSESSED, STUNNED, DEAD, ALARMED}
var alarmed_time = 0
const MAX_ALARMED_TIME = 10
var status = IDLE
const MAX_STUN_TIME = 3
var stun_time = 0
var idle_time = 0
var time_to_interact
var int_time = 0
var int_object
var int_tile = Vector2()
# Do not use the same tile twice
var int_blacklist

# Maybe put this into the scene root and make the bodies known to everybody
var known_casualties = []
export (PoolStringArray) var usable_tiles
const interaction_times = preload("res://objects/object_vars.gd").interaction_times

# Movement
const SPEED = 100
onready var navigation = get_node("/root/world/navigation")
onready var tilemap = navigation.get_node("object_layer")
var path
enum {NORTH, NORTHEAST, EAST, SOUTHEAST, SOUTH, SOUTHWEST, WEST, NORTHWEST}
const MAX_CARDDIR = 7
const directions_dict = {
	NORTH: 0, NORTHEAST: 45,
	EAST: 90, SOUTHEAST: 135,
	SOUTH: 180, SOUTHWEST: 225,
	WEST: 270, NORTHWEST: 315}
const cardinal_margin = 0.2
const MAX_TURN_TIME = .5
var turn_time = 0
var turns = 0
var turn_dir = null
var current_direction = NORTH

onready var player = get_node("/root/world/player")
onready var view = get_node("view")
var sprite
var last_player_pos = Vector2()
onready var fire_node_r = get_node("firing_r")
onready var fire_node_l = get_node("firing_l")
var current_fire_position

var fire_time = 0
const MAX_FIRE_TIME = 2

onready var sound_area = get_node("sound_area")
const BULLET_RES = preload("res://objects/bullet.tscn")
var alert_pos
var is_suspicious = false
var suspicious_time = 0
const MAX_SUSPICIOUS_TIME = 2.5

func _ready():
	if role == 0:
		sprite = get_node("blue")
	elif role == 1:
		sprite = get_node("yellow")
	elif role == 2:
		sprite = get_node("red")
	sprite.set_visible(true)


func get_hit():
	if status == POSSESSED:
		if player.host:
			player.release_host_proxy()


func die():
	alert_crew()
	get_node("/root/world/crew_death").play()
	dead = true
	change_state(DEAD)
	set_collision_layer_bit(2, false)
	set_collision_layer_bit(3, true)
	set_collision_mask_bit(0, false)
	set_z_index(-1)
	set_process(false)
	sprite.play("dying")
	sprite.connect("animation_finished", self, "death_anim_finished")


func death_anim_finished():
	sprite.stop()
	sprite.set_frame(3)


func is_dead():
	return dead


func change_state(state):
	if status == DEAD:
		return
	if not ((status == HUNTING and state == ALARMED) or (status == POSSESSED and state == ALARMED)):
		status = state
	if state == IDLE or state == HUNTING or state == STUNNED or state == POSSESSED or state == DEAD or state == ALARMED:
		reset_interact_vars()
	if state == STUNNED:
		sprite.set_frame(0)
		sprite.stop()

	get_node("ColorRect/status").set_text("STATUS: %s" % status)


func _on_view_body_entered(body):
	#print(body.get_name())
	if status == POSSESSED:
		return
	# If we se a dead body, be alarmed bout it if we have not seen it before
	if body.is_in_group("crew") and body.is_dead() and has_line_of_sight(body) and not (status == STUNNED or status == POSSESSED):
		if body == self:
			return
		if not body in known_casualties:
			change_state(ALARMED)
			alert_crew()
			known_casualties.append(body)

	elif body.is_in_group("crew") and body.is_suspicious:
		if has_line_of_sight(body):
			change_state(HUNTING)
			_update_navigation_path(get_global_position(), body.get_global_position())

	elif body.is_in_group("player") and not body.host and not (status == STUNNED or status == POSSESSED):
		if has_line_of_sight(body):
			change_state(HUNTING)
			_update_navigation_path(get_global_position(), body.get_global_position())


func _process(delta):
	if status == POSSESSED:
		return
	elif status == STUNNED:
		stun_time += delta
		if stun_time >= MAX_STUN_TIME:
			stun_time = 0
		else:
			return

	last_player_pos = player.get_global_position()

	# Get the distance we have to travel this frame
	var last_position = get_global_position()

	if path and not path.size() == 0:
		var walk_distance = SPEED * delta
		if not (status == HUNTING or status == ALARMED and get_global_position().distance_to(player.get_global_position()) < 200):
			move(walk_distance)
			if not sprite.is_playing():
				sprite.play()
		elif status == HUNTING:
			var dtp = (player.get_global_position() - get_global_position()).normalized()
			if turn_dir == null:
				rotate_to_vdir(dtp)
			sprite.stop()
			sprite.set_frame(0)
		if not (status == HUNTING or status == ALARMED):
			change_state(MOVING)
	else:
		if not status == POSSESSED:
			sprite.stop()
			sprite.set_frame(0)
		if int_tile and not status == INTERACTING:
			# TODO: randomize this
			time_to_interact = interaction_times[int_object]
			change_state(INTERACTING)
		elif not int_tile and not (status == HUNTING or status == ALARMED):
			change_state(IDLE)

	var current_position = get_global_position()
	var dir = (current_position -last_position).normalized()

	var cardinal_dir = get_rotation_from_dir(dir)
	if dir and turn_dir == null:
		rotate_to_direction(cardinal_dir)
	elif status == INTERACTING:
		rotate_to_direction(NORTH)

	if status == IDLE:
		get_interaction_tile()
		idle_time += delta
	elif status == INTERACTING:
		idle_time = 0
		int_time += delta
		if int_time >= time_to_interact:
			reset_interact_vars()
			change_state(IDLE)

	elif status == HUNTING:
		var bodies = view.get_overlapping_bodies()
		if (player in bodies) or (player.host in bodies):
			if has_line_of_sight(player) or has_line_of_sight(player.host):
				_update_navigation_path(get_global_position(), player.get_global_position())
				turn_time = 0
				turns = 0
		else:
			if turn_time >= MAX_TURN_TIME:
				turn_time = 0
				if turns == 0:
					var right = view.get_global_transform().x
					var dtp = (player.get_global_position() - get_global_position()).normalized()
					turn_dir = sign(dtp.dot(right))
				rotate_to_direction(current_direction + turn_dir)
				turns += 1
				if turns >= 8:
					turn_dir = null
					turns = 0
					change_state(IDLE)


	if is_suspicious:
		suspicious_time += delta
		if suspicious_time >= MAX_SUSPICIOUS_TIME:
			is_suspicious = false


	fire_time += delta
	if status == HUNTING and fire_time >= MAX_FIRE_TIME:
		fire_time = 0
		fire()

	turn_time += delta
	if status == ALARMED:
		alarmed_time += delta
		if alarmed_time >= MAX_ALARMED_TIME:
			alarmed_time = 0
			change_state(IDLE)


func alert(pos):
	alert_pos = pos
	var dir = (pos - get_global_position()).normalized()
	rotate_to_vdir(dir)
	change_state(ALARMED)

func alert_crew():
	var bodies = sound_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("crew") and not body == self:
			body.alert(get_global_position())


func fire():
	var bodies = view.get_overlapping_bodies()
	if ((player in bodies) or (player.host in bodies)) and (has_line_of_sight(player) or has_line_of_sight(player.host)):
		var bullet = BULLET_RES.instance()
		var b_pos = current_fire_position.get_global_position()
		var m_dir = (player.get_global_position() - b_pos).normalized()
		bullet.move_dir = m_dir
		bullet.set_global_position(b_pos + m_dir * 20)
		bullet.source = self
		get_node("/root/world").add_child(bullet)

func rotate_to_vdir(vdir):
	var cdir = get_rotation_from_dir(vdir)
	rotate_to_direction(cdir)


func rotate_to_direction(dir):
	if dir < 0:
		dir = MAX_CARDDIR + dir
	elif dir > MAX_CARDDIR:
		dir = dir - MAX_CARDDIR

	sprite.set_flip_h(false)
	if dir == NORTH:
		current_fire_position = fire_node_r
		sprite.set_animation("walk_up")
	elif dir == EAST:
		current_fire_position = fire_node_r
		sprite.set_animation("walk_right")
	elif dir == SOUTH:
		current_fire_position = fire_node_r
		sprite.set_animation("walk_down")
	elif dir == WEST:
		current_fire_position = fire_node_l
		sprite.set_flip_h(true)
		sprite.set_animation("walk_right")

	# WTF why is this being converted to a string???.
	var rot = directions_dict[int(dir)]
	view.set_rotation_degrees(rot)
	current_direction = dir


func get_rotation_from_dir(dir):
	var direction = SOUTH
	if abs(dir.x) > abs(dir.y):
		if dir.x > 0:
			direction = EAST
		else:
			direction = WEST
	elif abs(dir.x) < abs(dir.y):
		if dir.y < 0:
			direction = NORTH
		else:
			direction = SOUTH
	elif abs(dir.x) == abs(dir.y):
		if dir.y > 0:
			direction = SOUTH
		else:
			direction = NORTH
	
	return direction

#	var cardinal_margin = 0.2
#	var direction = 0
#
#	if dir.y > 0 and dir.y > cardinal_margin:
#		if dir.x < cardinal_margin and dir.x > -cardinal_margin:
#			direction = SOUTH
#		elif dir.x > cardinal_margin:
#			direction = SOUTHEAST
#		elif dir.x < -cardinal_margin:
#			direction = SOUTHWEST
#
#	elif dir.y < 0 and dir.y < -cardinal_margin:
#		if dir.x < cardinal_margin and dir.x > -cardinal_margin:
#			direction = NORTH
#		elif dir.x > cardinal_margin:
#			direction = NORTHEAST
#		elif dir.x < -cardinal_margin:
#			direction = NORTHWEST
#	elif dir.x > 0:
#		direction = EAST
#	elif dir.x < 0:
#		direction = WEST




func get_interaction_tile():
	var tile = find_closest_interaction_tile()
	if tile:
		if not tilemap.lock_tile(self, tile):
			return
		int_tile = tile
		int_object = tilemap.get_tile_name(tile)
		var tile_pos = tilemap.map_to_world(tile + Vector2(0, 1)) + tilemap.get_cell_size() / 2
		_update_navigation_path(get_position(), tile_pos)


func find_closest_interaction_tile():
		var interaction_tiles = []
		# Gets all tile vectors that we can use
		for tname in usable_tiles:
			interaction_tiles += tilemap.get_tiles_from_name(tname)

		for tile in interaction_tiles:
			if tile in tilemap.tiles_in_use or tile == int_blacklist:
				interaction_tiles.erase(tile)

		if not interaction_tiles.empty():
			var current_position = get_global_position()
			var best_tile
			var bd
			for tile in interaction_tiles:
				# If the tile is currently in use by another npc we can not use it.
				if tile in tilemap.tiles_in_use:
					continue

				# If best tile_is null choose the first that is available
				if not best_tile:
					print("BEST TILE")
					best_tile = tile
					var p = navigation.get_simple_path(current_position, tilemap.map_to_world(best_tile), true)
					bd = get_path_distance(p)
					continue
				else:
					var p = navigation.get_simple_path(current_position, tilemap.map_to_world(tile), true)
					var d = get_path_distance(p)
					if d < bd:
						best_tile = tile
						bd = d
			print(best_tile)
			return best_tile
		return


func reset_interact_vars():
	tilemap.unlock_tile(self, int_tile)
	int_time = 0
	int_time = 0
	int_object = null
	# do not use the same tile twice
	if int_tile:
		int_blacklist = int_tile
	int_tile = Vector2()


func move(distance):
	var current_position = get_position()
	for i in range(path.size()): # ??? For schleife?
		# Get the distance to the next point.
		var d = current_position.distance_to(path[0])
		if distance <= d and distance >= 0:
			var n_pos = current_position.linear_interpolate(path[0], distance / d)
			set_position(n_pos)
			break
		elif distance < 0.0:
			set_position(path[0])
			set_process(false)
			break
		distance -= d
		current_position = path[0]
		path.remove(0)


func has_line_of_sight(entity):
	if not is_instance_valid(entity):
		return false
	var cpos = get_global_position()
	var epos = entity.get_global_position()
	var res = cast_ray(cpos, epos)
	if res and res.collider == entity:
		return true


func cast_ray(from, to):
	var space_state = get_world_2d().get_direct_space_state()
	return space_state.intersect_ray(from, to, [self.get_rid()])


func get_path_distance(path_array):
	print(path_array)
	var distance = 0
	var p_point = path_array[0]
	for point in path_array:
		distance += p_point.distance_to(point)
		p_point = point
	return distance

func _update_navigation_path(from, to):
	path = navigation.get_simple_path(from, to, true)
	print(path)
	path[path.size() - 1] = to
	path.remove(0)