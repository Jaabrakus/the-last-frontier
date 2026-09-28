class_name AnimRecorder
extends RefCounted
## JSONL recorder of the player animation inputs (plan section 9, WP6), for deterministic replay.
##
## PlayerAnim writes one line per animation frame (PlayerAnim.manual_step) while recording:
##
##   {"f": frame, "dt": process dt, "in": AnimInputs.to_dict() (its "events" = the physics edge
##    events consumed this frame), "ev": [facade events applied this frame], "h": pose hash}
##
## Facade events are the queued weapon / player / option events, in the order they were applied:
##   {"t": "weapon", "w"}                         PlayerAnim.set_weapon
##   {"t": "fired", "w"}                          Weapon.fired
##   {"t": "action", "k", "d", "w"}               Weapon.action_started(key, duration)
##   {"t": "cancel", "w"}                         Weapon.action_cancelled
##   {"t": "holster", "w", "d"}                   PlayerAnim.play_holster
##   {"t": "hurt", "dir": [x, y], "a", "heavy"}   player hurt / PlayerAnim.play_hit
##   {"t": "died", "dir": [x, y]}                 player died / PlayerAnim.play_death
##   {"t": "revive"}                              player respawned / PlayerAnim.revive
##   {"t": "option", "name", "value"}             PlayerAnim.set_option (gameplay overrides too)
## The first line is a header {"header": {...}} (format, frame the recording started at, graph
## table hash, attribution). Numbers are written with full precision, so a replay feeds the
## controllers bit-identical inputs.
##
## pose_hash(): sha1 over every bone's local pose (rotation, position, scale) right after the
## tree's advance (the animated pose, before SkeletonModifier3Ds), each component quantized to
## 1e-4. A replay through PlayerAnim.set_input_source(AnimRecorder.replay_source(lines)) from a
## fresh PlayerAnim must reproduce every "h" when the recording started at setup (header
## "from_setup": true); a recording started mid-session depends on the state it started from.

const FORMAT := 1
const QUANT := 1e4

var path := ""
var lines := 0
var _file: FileAccess


## Opens `path` for writing (truncates) and writes the header line. Returns false on failure.
func start(p_path: String, header := {}) -> bool:
	stop()
	path = p_path
	lines = 0
	var dir := p_path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	_file = FileAccess.open(p_path, FileAccess.WRITE)
	if _file == null:
		push_error("AnimRecorder: cannot open %s (%s)" % [p_path, error_string(FileAccess.get_open_error())])
		return false
	var h := header.duplicate()
	h["format"] = FORMAT
	_file.store_line(JSON.stringify({"header": h}, "", false, true))
	return true


func is_recording() -> bool:
	return _file != null


## One animation frame. `inputs` is written with `edges` as its events (the physics edge events
## consumed this frame); `events` are the facade events applied this frame.
func record(frame: int, inputs: AnimInputs, events: Array, pose_hash: String, dt := 0.0, edges: Variant = null) -> void:
	if _file == null:
		return
	var d := inputs.to_dict() if inputs != null else {}
	if edges is Array:
		d["events"] = (edges as Array).duplicate(true)
	_file.store_line(JSON.stringify({"f": frame, "dt": dt, "in": d, "ev": events.duplicate(true), "h": pose_hash},
			"", false, true))
	lines += 1
	if lines % 600 == 0:
		_file.flush()


func stop() -> void:
	if _file != null:
		_file.flush()
		_file.close()
	_file = null


## Frame lines of a recording (the header is skipped; see load_header()).
static func load(p_path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var f := FileAccess.open(p_path, FileAccess.READ)
	if f == null:
		push_error("AnimRecorder: cannot read %s" % p_path)
		return out
	while not f.eof_reached():
		var line := f.get_line()
		if line.strip_edges() == "":
			continue
		var v: Variant = JSON.parse_string(line)
		if v is Dictionary and not (v as Dictionary).has("header"):
			out.append(v)
	return out


static func load_header(p_path: String) -> Dictionary:
	var f := FileAccess.open(p_path, FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = JSON.parse_string(f.get_line())
	return (v as Dictionary).get("header", {}) if v is Dictionary else {}


## Input source for PlayerAnim.set_input_source(): frame k (1-based, PlayerAnim's frame counter
## since setup) -> {"in": AnimInputs, "ev": [facade events], "dt": float}, or null past the end.
## `first_frame` = the "f" of lines[0] (default: taken from it).
static func replay_source(p_lines: Array, first_frame := -1) -> Callable:
	var base := first_frame if first_frame >= 0 else (int(p_lines[0].get("f", 1)) if not p_lines.is_empty() else 1)
	return func(frame: int) -> Variant:
		var i := frame - base
		if i < 0 or i >= p_lines.size():
			return null
		var l: Dictionary = p_lines[i]
		return {"in": AnimInputs.from_dict(l.get("in", {})), "ev": l.get("ev", []), "dt": float(l.get("dt", 0.0))}


## sha1 of every bone's local pose, components quantized to 1e-4 (see the header).
static func pose_hash(sk: Skeleton3D) -> String:
	if sk == null:
		return ""
	var n := sk.get_bone_count()
	var q := PackedInt32Array()
	q.resize(n * 10)
	var k := 0
	for i in n:
		var r := sk.get_bone_pose_rotation(i)
		if r.w < 0.0:
			r = -r
		var p := sk.get_bone_pose_position(i)
		var s := sk.get_bone_pose_scale(i)
		for v in [r.x, r.y, r.z, r.w, p.x, p.y, p.z, s.x, s.y, s.z]:
			q[k] = roundi(float(v) * QUANT)
			k += 1
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA1)
	ctx.update(q.to_byte_array())
	return ctx.finish().hex_encode()
