class_name HitchLog
extends Node
## A recorder for freezes in play (user 2026-10-02: "fix the game freeze on first musket shot ... when i click fire
## instantly"; not reproduced in tool runs). Every frame's time is watched; a frame over HITCH_MS writes one line to
## user://logs/hitches.log with what happened just before it: the last NOTES things the game noted (HitchLog.note(): a
## shot, an effect, a sound or a resource loaded the first time, a save applied), the frame's time and the engine's
## counts. Costs a subtraction a frame. FrontierLevel adds it (not in tool or test runs).
##   HitchLog.note("musket fired")        # anywhere

const PATH := "user://logs/hitches.log"
const HITCH_MS := 150.0
const NOTES := 24

static var _notes: Array = []
var _last := 0
var _file: FileAccess


static func note(what: String) -> void:
	_notes.append("%.3f %s" % [Time.get_ticks_msec() / 1000.0, what])
	if _notes.size() > NOTES:
		_notes.pop_front()


static func install(level: Node) -> void:
	var args := OS.get_cmdline_args()
	if "-s" in args or "--script" in args or DisplayServer.get_name() == "headless":
		return
	var h := HitchLog.new()
	h.name = "HitchLog"
	h.process_mode = Node.PROCESS_MODE_ALWAYS
	level.add_child(h)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://logs")
	_file = FileAccess.open(PATH, FileAccess.READ_WRITE if FileAccess.file_exists(PATH) else FileAccess.WRITE)
	if _file:
		_file.seek_end()
		_file.store_line("=== session %s" % Time.get_datetime_string_from_system())
		_file.flush()
	_last = Time.get_ticks_usec()
	var p := get_tree().get_first_node_in_group(&"player")
	if p == null and get_parent():
		p = get_parent().get_node_or_null("Player")
	if p and "weapons" in p:
		for key: String in (p.weapons as Dictionary):
			var w: Object = p.weapons[key]
			if w and w.has_signal("fired"):
				w.connect("fired", func() -> void: HitchLog.note("%s fired" % key))


func _process(_dt: float) -> void:
	var now := Time.get_ticks_usec()
	var ms := (now - _last) / 1000.0
	_last = now
	if ms < HITCH_MS or _file == null:
		return
	_file.store_line("%.3f HITCH %.0f ms  nodes %d  objects %d  resources %d  draw calls %d  fps %d" % [now / 1e6, ms,
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT),
			Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.TIME_FPS)])
	for n: String in _notes:
		_file.store_line("    before: " + n)
	_file.flush()
