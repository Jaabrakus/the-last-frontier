class_name BackgroundLoad
extends RefCounted
## Resources the game needs soon, loaded on a worker thread while the main thread builds something
## else (faster-loading push, 2026-09-26). The level asks for the player's rig first (Actor_B.tscn
## with the 77 MB Actor_B animation library, about 1 s to load) and then builds the sky, terrain,
## fort and forest; the player takes the rig when it builds its character and only waits for what
## is left of the load. Nothing changes but the order: the same file, loaded once.
##
##   BackgroundLoad.request(path)   starts the load (once; nothing when it is cached or requested)
##   BackgroundLoad.take(path)      the resource: the threaded result, or a plain load() when it
##                                  was not requested or the threaded load failed
## A resource taken stays loaded for the rest of the run, as the preload() it replaces did, so a
## level loaded again (tests, a restart) does not read it again.

static var _requested := {}
static var _kept := {}


static func request(path: String, type_hint := "") -> void:
	if _requested.has(path) or ResourceLoader.has_cached(path):
		return
	if ResourceLoader.load_threaded_request(path, type_hint) == OK:
		_requested[path] = true


static func take(path: String) -> Resource:
	var r: Resource = null
	if _requested.has(path):
		_requested.erase(path)
		r = ResourceLoader.load_threaded_get(path)
	if r == null:
		r = load(path)
	if r != null:
		_kept[path] = r
	return r
