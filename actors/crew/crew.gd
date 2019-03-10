extends KinematicBody2D

var dead = false
var alarmed = false

enum {IDLE, MOVING, INTERACTING}
var status = IDLE
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

func die():
	get_node("Sprite").set_modulate(Color(0, 0, 0))
	print("IM DEAD")

func is_dead():
	return dead

func _on_view_body_entered(body):
	# If we se a dead body, be alarmed bout it if we have not seen it before
	if body.is_in_group("crew") and body.is_dead():
		if not body in known_casualties:
			alarmed = true
			known_casualties.append()


func _process(delta):
	# Get the distance we have to travel this frame
	var cs = status
	if path and not path.size() == 0:
		var walk_distance = SPEED * delta
		move(walk_distance)
		status = MOVING
	else:
		if int_tile and not status == INTERACTING:
			status = INTERACTING
			# TODO: randomize this
			time_to_interact = interaction_times[int_object]
			print(status)
		elif not int_tile:
			status = IDLE

	if status == IDLE:
		get_interaction_tile()
		idle_time += delta
	elif status == INTERACTING:
		idle_time = 0
		int_time += delta
		if int_time >= time_to_interact:
			reset_interact_vars()
			status = IDLE

	if cs != status:
		get_node("status").set_text("STATUS: %s" % status)


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
				print(self.name + " " + str(tile))
				# If the tile is currently in use by another npc we can not use it.
				if tile in tilemap.tiles_in_use:
					print("tile in use")
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
	status == IDLE
	int_time = 0
	int_object = null
	# do not use the same tile twice
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


func _update_navigation_path(from, to):
	path = navigation.get_simple_path(from, to, true)
	path[path.size() - 1] = to
	path.remove(0)