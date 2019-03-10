extends TileMap

# Declare member variables here. Examples:
# var a = 2
# var b = "text"
var tileset = get_tileset()
export (PoolStringArray) var special_tiles
var tiles = []
var tiles_in_use = {}


func _ready():
	tiles = get_used_cells()


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

