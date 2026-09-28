extends SceneTree
## Headless tests for the faster loading (push n06, 2026-09-26): the level's first frame comes in seconds, not
## after the 50-60 s stall of per-key `changed` signals (TravInertializer edits an animation quietly, one
## `changed` when done), the player's rig loads lazily / in the background (BackgroundLoad), the prefetch list
## is valid (StartupPrefetch), and the startup profile marks every phase.
##
##   Godot --headless --path . -s tests/perf/test_startup.gd [-- --only <name>]
##
## Timing numbers per phase: tools/perf/startup_times.py (windowed and headless, min of N runs).
## Failures are listed; exit code 1.

## The level's first frame, headless, must come within this (measured 2026-09-26: ~3.3 s after this push,
## 50-60 s before it on the same machine, under load from other runs).
const FIRST_FRAME_LIMIT_MS := 20000.0

var failures := PackedStringArray()
var passes := 0
var current := ""


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var only := ""
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and str(args[0]) == "--only":
		only = str(args[1])
	for name in ["test_quiet_resample", "test_quiet_keeps_blocked", "test_quiet_smooth", "test_background_load",
			"test_prefetch_list", "test_level_first_frame"]:
		if only != "" and not name.contains(only):
			continue
		current = name
		var n0 := failures.size()
		await call(name)
		print("  %s %s" % ["ok  " if failures.size() == n0 else "FAIL", name])
	print("")
	print("startup: %d checks passed, %d failed (%d ms)" % [passes, failures.size(), Time.get_ticks_msec() - t0])
	for f in failures:
		printerr("  FAIL " + f)
	print("STARTUP TEST %s" % ("PASSED" if failures.is_empty() else "FAILED"))
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures.append("%s: %s" % [current, what])


## A copy of a traversal clip that opts into the Hermite resample (traversal_runtime.json), in its own
## library on its own AnimationPlayer (the listeners the stall came from).
func _hermite_clip() -> Array:
	var lib := TravMoveLibrary.shared()
	var clip := ""
	for id: String in lib.moves:
		var m: Dictionary = lib.moves[id]
		if str(m.get("clip_interpolation", "")) == "hermite" and not (m.get("parts", []) as Array).is_empty():
			clip = str((m.parts as Array)[0].clip)
			break
	var rig := (load(FrontierPlayer.CHARACTER_SCENE) as PackedScene).instantiate()
	var ap := rig.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var src := ap.get_animation("%s/%s" % [TravPreviewActor.LIB, clip])
	rig.free()
	if src == null:
		return []
	var a := src.duplicate(true) as Animation
	a.remove_meta("trav_hermite")
	var al := AnimationLibrary.new()
	al.add_animation(&"clip", a)
	var holder := Node.new()
	var p := AnimationPlayer.new()
	holder.add_child(p)
	root.add_child(holder)
	p.add_animation_library(&"t", al)
	return [a, holder, clip]


func test_quiet_resample() -> void:
	var h := _hermite_clip()
	_check(not h.is_empty(), "a hermite traversal clip on the rig")
	if h.is_empty():
		return
	var a: Animation = h[0]
	var first := {}
	var last := {}
	var keys0 := 0
	for t in a.get_track_count():
		if a.track_get_type(t) == Animation.TYPE_POSITION_3D and a.track_get_key_count(t) >= 3:
			first[t] = a.track_get_key_value(t, 0)
			last[t] = a.track_get_key_value(t, a.track_get_key_count(t) - 1)
		keys0 += a.track_get_key_count(t)
	var n := [0]
	a.changed.connect(func() -> void: n[0] += 1)
	var t0 := Time.get_ticks_usec()
	var tracks := TravInertializer.resample_hermite(a)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	var keys1 := 0
	for t in a.get_track_count():
		keys1 += a.track_get_key_count(t)
	print("    %s: %d tracks resampled, keys %d -> %d, %.1f ms, changed x%d" % [h[2], tracks, keys0, keys1, ms, n[0]])
	_check(tracks > 0, "tracks resampled (%d)" % tracks)
	_check(n[0] == 1, "one `changed` for the whole resample (got %d)" % n[0])
	_check(keys1 > keys0, "denser keys (%d -> %d)" % [keys0, keys1])
	var ends_ok := true
	for t: int in first:
		var c := a.track_get_key_count(t)
		ends_ok = ends_ok and (a.track_get_key_value(t, 0) as Vector3).is_equal_approx(first[t]) \
				and (a.track_get_key_value(t, c - 1) as Vector3).is_equal_approx(last[t])
	_check(ends_ok, "every position track keeps its first and last key")
	_check(not a.is_blocking_signals(), "signals unblocked after the resample")
	n[0] = 0
	_check(TravInertializer.resample_hermite(a) == 0 and n[0] == 0, "a second resample is a no-op (meta trav_hermite)")
	# the deferred calls the per-key signals used to queue: two frames must pass quickly
	var f0 := Time.get_ticks_msec()
	await process_frame
	await process_frame
	_check(Time.get_ticks_msec() - f0 < 2000, "no deferred backlog after the resample (%d ms for 2 frames)" % (Time.get_ticks_msec() - f0))
	(h[1] as Node).queue_free()


func test_quiet_keeps_blocked() -> void:
	var a := Animation.new()
	var t := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(t, "Skeleton3D:root")
	for i in 4:
		a.position_track_insert_key(t, i * 0.1, Vector3(i, i * i, 0))
	a.length = 0.3
	var n := [0]
	a.changed.connect(func() -> void: n[0] += 1)
	a.set_block_signals(true)
	TravInertializer.resample_hermite(a)
	_check(a.is_blocking_signals(), "an animation blocked before stays blocked")
	_check(n[0] == 0, "and sends nothing (got %d)" % n[0])
	a.set_block_signals(false)


func test_quiet_smooth() -> void:
	var lib := AnimationLibrary.new()
	var a := Animation.new()
	var t := a.add_track(Animation.TYPE_ROTATION_3D)
	a.track_set_path(t, "Skeleton3D:root")
	for i in 5:
		a.rotation_track_insert_key(t, i * 0.1, Quaternion(Vector3.UP, i * 0.2))
	lib.add_animation(&"a", a)
	var n := [0]
	a.changed.connect(func() -> void: n[0] += 1)
	var c := TravInertializer.smooth_library_clips(lib, PackedStringArray(["a"]))
	_check(c == 1 and a.track_get_interpolation_type(t) == Animation.INTERPOLATION_CUBIC, "the track turned cubic")
	_check(n[0] == 1, "one `changed` (got %d)" % n[0])


func test_background_load() -> void:
	var fresh := FrontierPlayer.new()
	_check(fresh.character_scene == null, "the player does not preload its rig (character_scene empty = CHARACTER_SCENE)")
	fresh.free()
	_check(ResourceLoader.exists(FrontierPlayer.CHARACTER_SCENE), "CHARACTER_SCENE exists")
	var path := "res://assets/weapons/bow.glb"
	BackgroundLoad.request(path)
	var r := BackgroundLoad.take(path)
	_check(r is PackedScene and r == load(path), "take() returns the threaded load, the cached resource")
	var r2 := BackgroundLoad.take(path)
	_check(r2 == r, "take() without a request is a plain load()")


func test_prefetch_list() -> void:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(StartupPrefetch.LIST))
	_check(d is Dictionary and (d as Dictionary).get("paths", []) is Array, "%s parses" % StartupPrefetch.LIST)
	if not d is Dictionary:
		return
	var paths: Array = d.paths
	_check(paths.size() > 50, "the list has the level's loads (%d)" % paths.size())
	var missing := PackedStringArray()
	var bad := PackedStringArray()
	var seen := {}
	for p: String in paths:
		if not ResourceLoader.exists(p):
			missing.append(p)
		if p.get_extension() in ["gd", "gdshader", "gdshaderinc"] or p.begins_with("res://.godot") \
				or p in [FrontierPlayer.CHARACTER_SCENE, "res://animations/Actor_B.res", "res://scenes/main.tscn"] or seen.has(p):
			bad.append(p)
		seen[p] = true
	_check(missing.is_empty(), "every listed path exists (re-record with tools/perf/startup_prefetch_list.py): %s" % [missing])
	_check(bad.is_empty(), "no scripts, shaders, remaps, the rig or duplicates: %s" % [bad])
	_check(StartupPrefetch.start(self) == 0, "headless: no prefetch (the list is the windowed level's)")


func test_level_first_frame() -> void:
	var t0 := Time.get_ticks_msec()
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var ms := Time.get_ticks_msec() - t0
	var player := current_scene.get_node_or_null("Player") as FrontierPlayer if current_scene else null
	print("    level to its second frame: %d ms (limit %d)" % [ms, FIRST_FRAME_LIMIT_MS])
	_check(player != null, "the level has its player")
	_check(ms < FIRST_FRAME_LIMIT_MS, "the level's first frames within %d ms (%d)" % [FIRST_FRAME_LIMIT_MS, ms])
	if player == null:
		return
	_check(player.character_scene != null and player.skeleton != null, "the rig is built (BackgroundLoad)")
	_check(player.character_scene.resource_path == FrontierPlayer.CHARACTER_SCENE, "the default rig")
	var ap := player.anim.get_node(player.anim.anim_player) as AnimationPlayer if player.anim else null
	_check(ap != null and ap.has_animation("%s/%s" % [TravPreviewActor.LIB, "actor_b-p-relax-idle"]), "the rig's animation library is on the player")
	for i in 30:
		if player.traversal and player.traversal.world_ready:
			break
		await physics_frame
	_check(player.traversal != null and player.traversal.world_ready, "the traversal world is baked")
	var phases := PackedStringArray()
	for m in StartupProfile.marks():
		phases.append(str(m[0]))
	for p in ["boot", "environment", "terrain", "structures", "vegetation", "player", "audio"]:
		_check(p in phases, "startup mark %s" % p)
