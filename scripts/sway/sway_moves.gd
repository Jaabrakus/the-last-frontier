class_name SwayMoves
extends RefCounted
## The Sway's data (data/sway/moves.json; docs/main_story.md 11.8): the lock's rules, the motes, the arts' colours and ring
## shapes, and each move's lock time, cost, range, targets and effect numbers. Read once, kept; reload() reads it again.
##
##   SwayMoves.move("gust")          # {} when there is none
##   SwayMoves.lock_rule("grace_s", 0.15)
##   SwayMoves.art_color("breath")

const PATH := "res://data/sway/moves.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		reload()
	return _data


static func reload() -> void:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
	_data = d if d is Dictionary else {"lock": {}, "motes": {}, "arts": {}, "moves": {}}


static func move(id: String) -> Dictionary:
	return (data().get("moves", {}) as Dictionary).get(id, {})


## The moves in the file's order (the order a target's move is picked in).
static func ids() -> Array:
	return (data().get("moves", {}) as Dictionary).keys()


static func lock_rule(key: String, def: float) -> float:
	return float((data().get("lock", {}) as Dictionary).get(key, def))


static func motes_rule(key: String, def: float) -> float:
	return float((data().get("motes", {}) as Dictionary).get(key, def))


static func art(id: String) -> Dictionary:
	return (data().get("arts", {}) as Dictionary).get(id, {})


static func art_color(id: String) -> Color:
	var c: Variant = art(id).get("color", [])
	if c is Array and (c as Array).size() >= 3:
		return Color(float(c[0]), float(c[1]), float(c[2]))
	return Color(0.9, 0.92, 1.0)


## The ring's shape for the art (colour-blind players): "open", "dotted", "notched" or "doubled".
static func ring_shape(id: String) -> String:
	return String(art(id).get("ring", "open"))


static func one_hand_weapons() -> Array:
	return data().get("one_hand_weapons", ["pistol"])


static func sfx(key: String) -> StringName:
	return StringName(String((data().get("sfx", {}) as Dictionary).get(key, "")))
