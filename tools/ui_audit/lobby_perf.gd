extends SceneTree
## The lobby's frame times as the menu appears (the 2026-10-10 critic's "~1.1 s frozen frame about 1.1 s after the menu shows"):
## the main menu scene as the game opens it (change_scene_to_file; boot=first is the game's first menu, its figure built before
## the first frame; boot=after is a menu after a match, its figure built in steps), every frame's time for `secs` seconds from the
## first frame, the hitches over 25 ms with what changed in that frame (pipeline compilations, the figure's fade, the figures
## built), and a verdict against the target (no frame over 100 ms after the menu shows). Windowed (the figure is not drawn
## headless), a normal window (never on top); never opens the character creator; the look is a made-up one.
##   zsh tools/loop/godot_run.sh --path . --resolution 1600x900 --max-fps 0 -s tools/ui_audit/lobby_perf.gd -- [boot=first|after]
##       [secs=8] [music=on] [from=ring] [out=FILE.json]
## from=ring plays the ring scene for a few seconds first (a quick match, the fighters held), then opens the menu as the game does after
## a match: what the ring loaded and compiled is warm then, as it is for a player.
## music=on starts the menu theme as a normal run does (a script run has none), on a muted bus.

const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
const TARGET_MS := 100.0

var opts := {}
var _look_stash := {}


func _initialize() -> void:
	opts = CaptureKit.args({"boot": "first", "secs": "8", "music": "off", "out": "", "from": ""})
	if not CaptureKit.begin(self, "lobby_perf", "", false, true):
		return
	MainMenu._look_offered = true               # (never the character creator)
	MainMenu.creator_hook = func(_first: bool) -> Object: return null
	var look := AppearanceStore.default_look()
	look["name"] = "Rowan"
	FighterWorld.look_override = AppearanceStore.validate(look)
	MainMenu._booted = opts.boot != "first"
	_run.call_deferred()


func _pipes() -> PackedInt32Array:
	return PackedInt32Array([Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS),
			Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH),
			Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),
			Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),
			Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)])


func _run() -> void:
	for i in 4:
		await process_frame
	if opts.music == "on" or opts.from == "ring":
		AudioServer.set_bus_mute(0, true)
	if opts.from == "ring":
		MatchSetup.quick = true
		MatchSetup.set_match()
		change_scene_to_file(MainMenu.RING_SCENE)
		var t := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t < 30000 and not (current_scene is RingLevel and RingMode.find(self) != null):
			await process_frame
		var t2 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t2 < 8000:
			await process_frame
		print("LOBBY PERF the ring played %.1f s" % ((Time.get_ticks_msec() - t) / 1000.0))
		MatchSetup.leave()
	var t_load := Time.get_ticks_usec()
	change_scene_to_file("res://scenes/main_menu.tscn")
	await process_frame
	var m := current_scene as MainMenu
	if m == null:
		await process_frame
		m = current_scene as MainMenu
	if m == null:
		print("LOBBY PERF: no main menu")
		quit(1)
		return
	if opts.music == "on":
		MusicDirector.play_menu(m)
	await RenderingServer.frame_post_draw
	var t0 := Time.get_ticks_usec()
	print("LOBBY PERF boot=%s first frame drawn %.1f ms after the scene change" % [opts.boot, (t0 - t_load) / 1000.0])
	var frames: Array = []
	var hitches: Array = []
	var last := t0
	var pp := _pipes()
	var was_alpha := m._fighter.modulate.a
	var was_figs := 0
	var seen_steps := FighterWorld.step_log.size()
	if seen_steps > 0:
		print("  steps before the first frame: %s" % str(FighterWorld.step_log))
	var limit := int(float(opts.secs) * 1e6)
	while Time.get_ticks_usec() - t0 < limit:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := (now - last) / 1000.0
		last = now
		var p := _pipes()
		var dp: Array = []
		for k in p.size():
			dp.append(p[k] - pp[k])
		pp = p
		var figs := m._fw._figs.size() if m._fw != null else 0
		var a := m._fighter.modulate.a
		var what: Array = []
		if dp != [0, 0, 0, 0, 0]:
			what.append("pipelines canvas/mesh/surface/draw/spec %s" % str(dp))
		if was_alpha == 0.0 and a > 0.0:
			what.append("the figure's fade starts")
		if figs != was_figs:
			what.append("figures %d" % figs)
		if m._fw != null and m._fw.building():
			what.append("building " + ",".join(m._fw._building.keys()))
		while seen_steps < FighterWorld.step_log.size():
			var st: Array = FighterWorld.step_log[seen_steps]
			seen_steps += 1
			what.append("%s step %d %.1f ms" % [st[0], st[1], st[2]])
		was_alpha = a
		was_figs = figs
		var at := (now - t0) / 1e6
		frames.append(dt)
		if dt > 25.0:
			hitches.append({"at_s": snappedf(at, 0.01), "ms": snappedf(dt, 0.1), "what": what})
			print("  hitch at %.2f s: %.1f ms  %s" % [at, dt, "; ".join(what)])
		elif not what.is_empty() and not (what.size() == 1 and String(what[0]).begins_with("building")):
			print("  at %.2f s: %.1f ms  %s" % [at, dt, "; ".join(what)])
	var s := frames.duplicate()
	s.sort()
	var worst: float = s.back() if not s.is_empty() else 0.0
	var res := {"boot": opts.boot, "music": opts.music, "window": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
			"frames": s.size(), "median_ms": snappedf(s[s.size() / 2], 0.01), "p99_ms": snappedf(s[int(s.size() * 0.99)], 0.01),
			"max_ms": snappedf(worst, 0.1), "hitches_over_25ms": hitches, "target_ms": TARGET_MS, "ok": worst <= TARGET_MS}
	print("LOBBY PERF %s: frames %d median %.2f ms p99 %.2f ms max %.1f ms (%d hitches over 25 ms)" % ["OK" if worst <= TARGET_MS else "OVER",
			s.size(), res.median_ms, res.p99_ms, worst, hitches.size()])
	if String(opts.out) != "":
		var f := FileAccess.open(String(opts.out), FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(res, " "))
			f.close()
	FighterWorld.look_override = {}
	MainMenu.creator_hook = Callable()
	AudioServer.set_bus_mute(0, false)
	quit(0)
