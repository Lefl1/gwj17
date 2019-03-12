extends KinematicBody2D

var dead = false

enum Roles {CAPTAIN, ENGINEER, COOK, ANALYST}
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
onready var tilemap = navigation.get_node("tilemap")
var path
enum {NORTH, NORTHEAST, EAST, SOUTHEAST, SOUTH, SOUTHWEST, WEST, NORTHWEST}
const MAX_CARDDIR = 7
const directions_dict = {
	NORTH: 0, NORTHEAST: 45,
	EAST: 90, SOUTHEAST: 135,
	SOUTH: 180, SOUTHWEST: 225,
	WEST: 270, NORTHWEST: 315}
const cardinal_margin = 0.2
const MAX_TURN_TIME = 0.5
var turn_time = 0
var turns = 0
var turn_dir = 1
var current_direction = NORTH

onready var player = get_node("/root/world/player")
onready var view = get_node("view")
var last_player_pos = Vector2()


func die():
	dead = true
	get_node("Sprite").set_modulate(Color(0, 0, 0))
	change_state(DEAD)
	set_collision_layer_bit(2, false)
	set_collision_layer_bit(3, true)
	set_z_index(-1)
	set_process(false)

func is_dead():
	return dead

func change_state(state):
	if status == DEAD:
		return
	status = state
	if state == IDLE or state == HUNTING or state == STUNNED or state == POSSESSED or state == DEAD or ALARMED:
		reset_interact_vars()
	get_node("status").set_text("STATUS: %s" % status)
	if state == ALARMED:
		path = null

func _on_view_body_entered(body):
	# If we se a dead body, be alarmed bout it if we have not seen it before
	if body.is_in_group("crew") and body.is_dead():
		if body == self:
			return
		if not body in known_casualties:
			change_state(ALARMED)
			known_casualties.append(body)

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
		elif status == HUNTING:
			var dtp = (player.get_global_position() - get_global_position()).normalized()
			rotate_to_vdir(dtp)
		if not (status == HUNTING or status == ALARMED):
			change_state(MOVING)
	else:
		if int_tile and not status == INTERACTING:
			change_state(INTERACTING)
			# TODO: randomize this
			time_to_interact = interaction_times[int_object]
		elif not int_tile and not (status == HUNTING or status == ALARMED):
			change_state(IDLE)

	var current_position = get_global_position()
	var dir = (current_position -last_position).normalized()

	var cardinal_dir = get_rotation_from_dir(dir)
	if dir:
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
		if player in bodies and not player.host:
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
				if turns >= 4:
					turns = 0
					change_state(IDLE)

	turn_time += delta
	if status == ALARMED:
		alarmed_time += delta
		if alarmed_time >= MAX_ALARMED_TIME:
			alarmed_time = 0
			change_state(IDLE)


func rotate_to_vdir(vdir):
	var cdir = get_rotation_from_dir(vdir)
	rotate_to_direction(cdir)


func rotate_to_direction(dir):
	if dir < 0:
		dir = MAX_CARDDIR + dir
	elif dir > MAX_CARDDIR:
		dir = dir - MAX_CARDDIR

	# WTF why is this being converted to a string???.
	var rot = directions_dict[int(dir)]
	view.set_rotation_degrees(rot)
	current_direction = dir


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
			var current_position = tilemap.world_to_map(get_position())
			var best_tile
			var bd

			for tile in interaction_tiles:
				# If the tile is currently in use by another npc we can not use it.
				if tile in tilemap.tiles_in_use:
					continue

				# If best tile_is null choose the first that is available
				if not best_tile:
					best_tile = tile
					bd = current_position.distance_to(best_tile)
					continue
				else:
					var d = current_position.distance_to(best_tile)
					best_tile = tile
					bd = d

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
	var cpos = get_global_position()
	var epos = entity.get_global_position()
	var res = cast_ray(cpos, epos)
	if res and res.collider == entity:
		return true


func cast_ray(from, to):
	var space_state = get_world_2d().get_direct_space_state()
	return space_state.intersect_ray(from, to, [self.get_rid()])


func _update_navigation_path(from, to):
	path = navigation.get_simple_path(from, to, true)
	path[path.size() - 1] = to
	path.remove(0)