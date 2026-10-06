class_name WorldRegion
extends RefCounted
## The region the world is built from (Thủy Vân's region loader; plan phase 1, T5): "" is today's world, the frontier's
## squares, baked ground and year layers, exactly as before; a region id reads its own from data/world/maps/<id>/:
##   squares.json   the grid, the river (with its "reaches") and the region block ({name, latitude_deg, season, ...})
##   layers/        its year layers (StoryLayer: S0, S1 ...)
##   terrain        the region block's "terrain_dir" (a res:// folder) when it has one, else today's baked ground
## The world's readers ask for their path here (WorldSquares.PATH, FrontierTerrain.DATA_DIR and StoryLayer.DIR are today's
## and stay the fallback). Set the region before anything of the world loads (the level's first line); a change bumps
## `generation`, which the readers' caches compare against.
##
##   WorldRegion.set_region("r1_grey")      # ThuyVanLevel, before the terrain or the river are read
##   WorldRegion.squares_path()             # "res://data/world/maps/r1_grey/squares.json" ("" region: today's)
##   WorldRegion.info()                     # the region block ({} today)
## It names no other world class, so the readers preload it (no load cycle, and no need of the global class cache).

const MAPS_DIR := "res://data/world/maps/"
## Today's paths (the frontier's: WorldSquares.PATH, FrontierTerrain.DATA_DIR, StoryLayer.DIR; tests/thuyvan checks they agree).
const TODAY_SQUARES := "res://data/world/squares.json"
const TODAY_TERRAIN := "res://assets/environment/terrain/"
const TODAY_LAYERS := "res://data/world/layers/"

static var _id := ""
static var _info := {}
## Bumped by every change of region: a reader's cache made under another generation is stale.
static var generation := 0


## The region now ("" today's world).
static func id() -> String:
	return _id


static func set_region(region_id: String) -> void:
	if region_id == _id:
		return
	_id = region_id
	_info = {}
	generation += 1


## This region's folder ("" today's world).
static func dir() -> String:
	return "" if _id == "" else MAPS_DIR + _id + "/"


static func squares_path() -> String:
	return TODAY_SQUARES if _id == "" else dir() + "squares.json"


static func layers_dir() -> String:
	return TODAY_LAYERS if _id == "" else dir() + "layers/"


## The baked ground's folder: the region block's terrain_dir, else today's (the greybox keeps today's valley).
static func terrain_dir() -> String:
	var t := String(info().get("terrain_dir", ""))
	return t if t != "" else TODAY_TERRAIN


## The region block of its squares.json ({} today, or when it has none).
static func info() -> Dictionary:
	if _id == "":
		return {}
	if _info.is_empty():
		var p := squares_path()
		if FileAccess.file_exists(p):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
			if d is Dictionary and (d as Dictionary).get("region") is Dictionary:
				_info = ((d as Dictionary).region as Dictionary).duplicate(true)
	return _info
