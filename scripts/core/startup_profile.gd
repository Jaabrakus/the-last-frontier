class_name StartupProfile
extends Node
## Startup timing (faster-loading push, 2026-09-26). The level marks each build phase with
## StartupProfile.mark("<phase>"); the times are ms since the engine started
## (Time.get_ticks_usec()), so the first mark also holds the engine boot, the main scene load
## and the script compile before the level's _ready().
##
## Nothing is printed unless the user arg startup_profile is given:
##   Godot --path . -- startup_profile=1       print the table once the game has settled
##   Godot --path . -- startup_profile=quit    print it and quit (tools/perf/startup_times.py)
## With --verbose each mark is also printed when it happens (STARTUP_MARK <phase>), between the
## engine's "Loading resource" lines (tools/perf/startup_prefetch_list.py reads them).
## Marks after the level's own: first_frame = the first process frame (the level is built, the
## deferred calls and the first physics steps have run; this frame is drawn next), settled = the
## first of SETTLE_FRAMES frames in a row shorter than SETTLE_MS (the first drawn frames compile
## shaders and pipelines). The frame list has the slowest frames in between (#n = frame number).
## Meant for the first level load of a run (the marks are static and keep adding up).
##
## Output (one greppable line per phase, then a total):
##   STARTUP <phase> at_ms=<since engine start> ms=<since the previous mark>

const SETTLE_FRAMES := 5
const SETTLE_MS := 50.0
const MAX_FRAMES := 600

static var _marks: Array[Array] = []
static var _last_us := 0

var _frames := 0
var _calm := 0
var _frame_us := 0
var _worst: Array[Array] = []


## Records a phase end: time since the previous mark (or the engine start).
static func mark(phase: String) -> void:
	var now := Time.get_ticks_usec()
	_marks.append([phase, now, now - _last_us])
	_last_us = now
	if OS.is_stdout_verbose() and enabled():
		print("STARTUP_MARK %s at_ms=%.1f" % [phase, now / 1000.0])


## Whether the user asked for the profile (startup_profile=1 / quit).
static func enabled() -> bool:
	return _arg() != ""


## Adds the frame watcher to `parent` when the profile is on (the level calls this last).
static func watch(parent: Node) -> void:
	if not enabled():
		return
	var w := StartupProfile.new()
	w.name = "StartupProfile"
	parent.add_child(w)


## Measured phases so far: [[phase, at_us, ms], ...] (tests and tools).
static func marks() -> Array[Array]:
	return _marks


static func _arg() -> String:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if s.begins_with("startup_profile="):
			return s.get_slice("=", 1)
	return ""


func _ready() -> void:
	process_priority = -1000
	_frame_us = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := (now - _frame_us) / 1000.0
	_frame_us = now
	_frames += 1
	if _frames == 1:
		mark("first_frame")
		return
	_worst.append([dt, _frames])
	_calm = _calm + 1 if dt < SETTLE_MS else 0
	if _calm >= SETTLE_FRAMES or _frames >= MAX_FRAMES:
		mark("settled")
		_report()
		set_process(false)
		if _arg() == "quit":
			get_tree().quit()


func _report() -> void:
	var prev := 0
	for m in _marks:
		print("STARTUP %s at_ms=%.1f ms=%.1f" % [m[0], m[1] / 1000.0, (int(m[1]) - prev) / 1000.0])
		prev = int(m[1])
	_worst.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var top := PackedStringArray()
	for w in _worst.slice(0, 5):
		top.append("#%d %.0f" % [w[1], w[0]])
	print("STARTUP frames=%d slowest_ms=[%s] display=%s prefetch_held=%d" % [_frames, ", ".join(top),
			DisplayServer.get_name(), StartupPrefetch.pending()])
	print("STARTUP total at_ms=%.1f" % (int(_marks[-1][1]) / 1000.0))
