extends TileMap

# Declare member variables here. Examples:
# var a = 2
# var b = "text"
var tileset = get_tileset()
export (PoolStringArray) var special_tiles
var tiles = []
var tiles_in_use = {}
var doors_dict = {"door_base_blue": null, "door_base_yellow": null, "door_base_red": null}
const DOOR_RES = preload("res://objects/doors/door.tscn")


func _ready():
	tiles = get_used_cells()
	setup_doors()


func setup_doors():
	for door_base_name in doors_dict.keys():
		var tid = tileset.find_tile_by_name(door_base_name)
		assert(tid != -1)
		doors_dict[door_base_name] = tid
	
	var doors_container = get_node("/root/world/doors")
	for door in doors_dict.keys():
		var cells = get_used_cells_by_id(doors_dict[door])
		for cell in cells:
			var wspace_pos = map_to_world(cell)
			wspace_pos.x += get_cell_size().x * 0.5
			wspace_pos.y += get_cell_size().y
			var door_node = DOOR_RES.instance()
			door_node.set_global_position(wspace_pos)
			doors_container.add_child(door_node)
			if door == "door_base_blue":
				door_node.call_deferred("set_type", door_node.BLUE)
			elif door == "door_base_yellow":
				door_node.call_deferred("set_type", door_node.YELLOW)
			elif door == "door_base_red":
				door_node.call_deferred("set_type", door_node.RED)



func get_tiles_from_name(tile_name):
	var id = tileset.find_tile_by_name(tile_name)
	return get_used_cells_by_id(id)


func get_tile_name(tile):
	return tileset.tile_get_name(get_cellv(tile))


func lock_tile(user, tile):
	if tile in tiles_in_use:
		return false
	tiles_in_use[tile] = user
	return true


func unlock_tile(user, tile):
	tiles_in_use.erase(tile)

