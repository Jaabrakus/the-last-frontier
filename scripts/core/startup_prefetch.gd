class_name StartupPrefetch
extends RefCounted
## The level's resources requested on worker threads as the level starts (faster-loading push,
## 2026-09-26). The level's _ready() builds everything on the main thread (sky, terrain, fort,
## forest, player, sounds) and each part load()s its meshes, textures, shaders and sounds when it
## gets there: ~0.4-0.5 s of file reads and decoding, one after the other. start() hands the same
## paths to ResourceLoader.load_threaded_request() first, in the order the level needs them, so
## they load on the worker threads while the main thread builds; each part's own load() then finds
## the resource cached (or waits for the rest of its load). Same files, same data, loaded once.
##
## The list: data/startup/prefetch.json ("paths"), recorded from a --verbose windowed run by
## tools/perf/startup_prefetch_list.py (every resource the level loaded between its first line and
## its first frame, minus scripts, the rig BackgroundLoad already loads and what the game requests
## threaded itself). A path that no longer exists is skipped; one the game stopped using only costs
## a worker-thread load. Re-record it after big content changes.
##
## Windowed only: the list is the windowed level's (headless runs build colliders, not meshes).
## User arg startup_prefetch=0 turns it off (A/B, tools/perf/startup_times.py).
## The threaded loads hold their resources until load_threaded_get(); release() takes them back
## once they are done, from the first frame on (the level has its own references by then).

const LIST := "res://data/startup/prefetch.json"

static var _pending: PackedStringArray = []
static var _tree: SceneTree


## Requests the list (once per level start). Returns the number of loads started.
static func start(tree: SceneTree) -> int:
	if DisplayServer.get_name() == "headless" or _arg() == "0" or not FileAccess.file_exists(LIST):
		return 0
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(LIST))
	if not data is Dictionary:
		return 0
	var n := 0
	var held := {}
	for p in _pending:
		held[p] = true
	for p: String in (data as Dictionary).get("paths", []):
		if held.has(p) or ResourceLoader.has_cached(p) or not ResourceLoader.exists(p):
			continue
		if ResourceLoader.load_threaded_request(p) == OK:
			_pending.append(p)
			held[p] = true
			n += 1
	if n > 0 and tree and not tree.process_frame.is_connected(StartupPrefetch.release):
		_tree = tree
		tree.process_frame.connect(StartupPrefetch.release)
	return n


## Collects the finished loads (called each frame until none is left).
static func release() -> void:
	var left: PackedStringArray = []
	for p in _pending:
		var st := ResourceLoader.load_threaded_get_status(p)
		if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			left.append(p)
		elif st != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_get(p)
	_pending = left
	if _pending.is_empty() and is_instance_valid(_tree) and _tree.process_frame.is_connected(StartupPrefetch.release):
		_tree.process_frame.disconnect(StartupPrefetch.release)


## Loads still held (tests).
static func pending() -> int:
	return _pending.size()


## Paths still held (tests).
static func pending_paths() -> PackedStringArray:
	return _pending.duplicate()


static func _arg() -> String:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if s.begins_with("startup_prefetch="):
			return s.get_slice("=", 1)
	return ""
