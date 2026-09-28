class_name TravMoveLibrary
extends RefCounted
## Loads data/traversal/traversal_runtime.json (built by tools/traversal/build_runtime_table.gd
## from traversal_moves.json, the graph extract, the clip survey and the rig). Shared, loaded
## once: TravMoveLibrary.shared().

const TABLE := "res://data/traversal/traversal_runtime.json"

static var _shared: TravMoveLibrary

var data := {}
var moves := {}
var settings := {}
var loco := {}
var hub_records: Array = []
var hang_requests := {}
var transitions: Array = []
var ok := false
var error := ""


static func shared() -> TravMoveLibrary:
	if _shared == null:
		_shared = TravMoveLibrary.new()
		_shared.load_table(TABLE)
	return _shared


func load_table(path: String) -> bool:
	if not FileAccess.file_exists(path):
		error = "missing " + path + " (run tools/traversal/build_runtime_table.gd)"
		push_error("TravMoveLibrary: " + error)
		return false
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary):
		error = "cannot parse " + path
		push_error("TravMoveLibrary: " + error)
		return false
	data = d
	moves = data.get("moves", {})
	settings = data.get("settings", {})
	loco = data.get("loco", {})
	hub_records = data.get("hub_records", [])
	hang_requests = data.get("hang_requests", {})
	transitions = data.get("transitions", [])
	ok = true
	return true


func move(id: String) -> Dictionary:
	return moves.get(id, {})


func has(id: String) -> bool:
	return moves.has(id) and bool((moves[id] as Dictionary).get("enabled", true))


func setting(path: String, def: Variant) -> Variant:
	var cur: Variant = settings
	for k in path.split("."):
		if cur is Dictionary and (cur as Dictionary).has(k):
			cur = cur[k]
		else:
			return def
	return cur


## The graph's hub record for a request (ledge navigation): {record, target, fade_s, ...} or {}.
func hub_record(request: String) -> Dictionary:
	for r: Dictionary in hub_records:
		if str(r.request) == request:
			return r
	return {}


## A reference point of a move's track (move frame: +Z fwd, +X left, +Y up at t = 0) at time t
## (linear between the 60 Hz samples). `name` is a track (align, l_hand, r_hand, l_foot, ...).
func track_point(id: String, name: String, t: float) -> Vector3:
	var m := move(id)
	if m.is_empty():
		return Vector3.ZERO
	var tr: Dictionary = m.track
	var arr: Array = tr.get(name, tr.align)
	var n := int(tr.n)
	var hz := float(tr.hz)
	var x := clampf(t * hz, 0.0, float(n - 1))
	var i := mini(int(floor(x)), n - 1)
	var j := mini(i + 1, n - 1)
	var u := x - i
	if j == n - 1 and i == n - 2:
		# The last sample is at the move's end time, not on the uniform grid.
		var span := float(m.get("duration", (n - 1) / hz)) - i / hz
		u = clampf((t - i / hz) / span, 0.0, 1.0) if span > 1e-4 else 1.0
	var a := Vector3(float(arr[3 * i]), float(arr[3 * i + 1]), float(arr[3 * i + 2]))
	var b := Vector3(float(arr[3 * j]), float(arr[3 * j + 1]), float(arr[3 * j + 2]))
	return a.lerp(b, u)


## The first clip of a move and its length.
func first_clip(id: String) -> Dictionary:
	var parts: Array = move(id).get("parts", [])
	if parts.is_empty():
		return {"clip": "", "length": 0.0}
	var p: Dictionary = parts[0]
	return {"clip": str(p.clip), "length": float(p.get("clip_length", p.get("length", 0.0))), "state": str(p.get("state", ""))}


## Every clip the moves and loops play (the preview loads these).
func clips() -> PackedStringArray:
	var out := PackedStringArray()
	for id: String in moves:
		for p: Dictionary in (moves[id] as Dictionary).get("parts", []):
			if not out.has(str(p.clip)):
				out.append(str(p.clip))
	for k: String in loco:
		var c := str((loco[k] as Dictionary).get("clip", ""))
		if c != "" and not out.has(c):
			out.append(c)
	return out
