## Drops the `source_attribution` metadata from an animation library and saves it back in place (compressed).
## sync_rig.sh runs it on animations/Actor_B.res after copying the rig in; the tracks and every other
## metadata key are left as they are.
##
##   $G --headless --path <Frontier> -s tools/anim_graph/strip_source_meta.gd -- <library.res>
##
## Prints STRIP SOURCE META OK (with the count removed) or exits 1.
extends SceneTree

const KEY := &"source_attribution"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		printerr("strip_source_meta: pass the library path")
		quit(1)
		return
	var path: String = args[0]
	var lib := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as AnimationLibrary
	if lib == null:
		printerr("strip_source_meta: cannot load an AnimationLibrary from %s" % path)
		quit(1)
		return
	var n := 0
	if lib.has_meta(KEY):
		lib.remove_meta(KEY)
		n += 1
	for name in lib.get_animation_list():
		var a := lib.get_animation(name)
		if a.has_meta(KEY):
			a.remove_meta(KEY)
			n += 1
	if n > 0:
		var err := ResourceSaver.save(lib, path, ResourceSaver.FLAG_COMPRESS)
		if err != OK:
			printerr("strip_source_meta: saving %s failed (%d)" % [path, err])
			quit(1)
			return
	print("STRIP SOURCE META OK (%d removed from %s)" % [n, path])
	quit(0)
