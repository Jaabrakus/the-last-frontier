class_name BuildData
extends RefCounted
## Read-only access to the building data (data/building/building.json, loaded once, cached): the pieces in the
## build menu's order, their names and costs (logs and stone from the pack), the take-down refund, the reach, the
## snap radius and the ground grid.
##
##   var d := BuildData.get_default()
##   d.order                      # ["floor", "wall", ...]
##   d.cost("wall")               # {"log": 6}
##   d.refund("wall", 0.0)        # {"log": 3}: what taking it down gives back at a refund share of 0 (Novice)

const PATH := "res://data/building/building.json"
## The pseudo piece at the end of the menu that takes pieces down again.
const TAKE_DOWN := "take_down"

static var _default: BuildData

var raw := {}
var pieces := {}
var order: Array[String] = []
var take_down := {}
var reach := 8.0
var snap_radius := 2.2
var grid := 0.25
var yaw_step := deg_to_rad(15.0)


static func get_default() -> BuildData:
	if _default == null:
		_default = BuildData.new()
		_default.load_all()
	return _default


func load_all() -> void:
	var f := FileAccess.open(PATH, FileAccess.READ)
	var d: Variant = JSON.parse_string(f.get_as_text()) if f else null
	raw = d if d is Dictionary else {}
	pieces = raw.get("pieces", {})
	order.clear()
	for id: Variant in raw.get("order", pieces.keys()):
		if pieces.has(String(id)):
			order.append(String(id))
	take_down = raw.get("take_down", {})
	reach = float(raw.get("reach", reach))
	snap_radius = float(raw.get("snap_radius", snap_radius))
	grid = float(raw.get("grid", grid))
	yaw_step = deg_to_rad(float(raw.get("yaw_step_deg", 15.0)))


func has(id: String) -> bool:
	return pieces.has(id)


func name_of(id: String) -> String:
	if id == TAKE_DOWN:
		return String(take_down.get("name", "Take down"))
	return String(pieces.get(id, {}).get("name", id.capitalize()))


## The menu group a piece is listed under ("Cabin", "Fort", "Camp", "Furniture", "Crafting"; the data's "group").
func group_of(id: String) -> String:
	return String(pieces.get(id, {}).get("group", ""))


## {item kind: count} from the pack ("log", "stone"; "firewood", "pole", "branches", "deer_hide", ... for the camp,
## furniture and crafting pieces).
func cost(id: String) -> Dictionary:
	var out := {}
	var c: Dictionary = pieces.get(id, {}).get("cost", {})
	for k: String in c:
		out[k] = int(c[k])
	return out


## A piece that closes an opening chopped in a wall (WallCuts): "repair", "cover" or "door"; "" for a piece.
func opening(id: String) -> String:
	return String(pieces.get(id, {}).get("opening", ""))


## Whether the piece can also stand on a built floor (furniture: beds, racks, tables; the hearth and posts always can).
func on_floor(id: String) -> bool:
	return bool(pieces.get(id, {}).get("on_floor", false))


## Whether the piece can stand on the ground on its own (else it needs a socket: a gable, a roof).
func free_standing(id: String) -> bool:
	return bool(pieces.get(id, {}).get("free", true))


## The share of the cost taking a piece down gives back, for a refund bonus 0..1 (GatherSkills.yield_bonus of
## Building): refund_min at 0 to refund_max at 1.
func refund_share(bonus: float) -> float:
	return lerpf(float(take_down.get("refund_min", 0.5)), float(take_down.get("refund_max", 0.75)), clampf(bonus, 0.0, 1.0))


## What taking `id` down gives back: floor(count x share) of each item, at least 1 of an item it cost.
func refund(id: String, bonus: float) -> Dictionary:
	var share := refund_share(bonus)
	var out := {}
	var c := cost(id)
	for k: String in c:
		var n := int(c[k])
		if n > 0:
			out[k] = maxi(1, int(floor(n * share + 1e-4)))
	return out


## "6 logs", "4 logs, 6 stone", "5 poles, 10 branches": logs and stone first, then the rest as the cost lists them.
static func cost_text(c: Dictionary) -> String:
	var parts: PackedStringArray = []
	var keys: Array = ["log", "stone"]
	for k: String in c:
		if not keys.has(k):
			keys.append(k)
	for k: String in keys:
		if int(c.get(k, 0)) > 0:
			var n := int(c[k])
			parts.append("%d %s" % [n, BuildSnap._item_word(k, n)])
	return ", ".join(parts)
