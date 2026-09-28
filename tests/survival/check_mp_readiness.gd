extends SceneTree
## ADVISORY multiplayer-readiness check for the survival core. It measures what
## graph_analysis/survival/multiplayer_readiness.md (section 8) reports and always exits 0: it is a probe for the
## refactors that plan schedules before co-op, not a gate. Refactor P0-1 (the fixed-quantum driver in
## SurvivalCore.update, with the job-boundary quantum of 2b) landed with the v4 redesign, so check 1 reports OK. P0-2 is
## partial: the v4 systems draw from named streams (SurvivalStreams: caches, curing, the craft half-input roll), but the
## v3 systems still share SurvivalCore.rng, so check 3 stays KNOWN until they move.
##
##   1. update(delta) and frame slicing. The same state is driven for the same real time at 30, 60 and 144 frames a
##      second with a per-step chance draw active (rain on stretched green pelts, a slice mechanic:
##      SurvivalInventory.tick). Before P0-1 the random stream, and the weather after it, depended on the frame rate.
##   2. The fixed-quantum driver the plan proposes: real seconds accumulate into game minutes and the core advances only
##      in whole SurvivalCore.STEP_MIN steps. The same number of steps must give bit-identical states at any frame rate.
##  2b. Short jobs (a dram, eating, gathering) under that driver finish late, because a whole 10-minute quantum must
##      build up first. The corrected P0-1 driver ends a quantum at min(STEP_MIN, job left, passed-out left); it must
##      finish each job within a frame of its screen time and stay bit-identical across frame rates.
##   3. One shared stream. A single extra draw on the character's side (one more skill check) changes the weather two
##      game days later, which in co-op would be every player's weather.
##   4. Sizes: the serialized state of a character 20 game days into the trapper's credit year, per section, as JSON
##      and zstd (bandwidth and persistence estimates), and the HUD view a client needs.
##   5. CPU: one advance(STEP_MIN) step, and update() at 60 frames a second.
##
##   Godot --headless --path . -s tests/survival/check_mp_readiness.gd       (about 20-40 s; run under a time limit)

const FPS := [30, 60, 144]
const REAL_S := 120.0
const QUANTUM_STEPS := 120

var notes := PackedStringArray()


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	_check_slicing()
	_check_quantum()
	_check_short_jobs()
	_check_shared_stream()
	_sizes_and_cpu()
	print("")
	for n in notes:
		print(n)
	print("check_mp_readiness: advisory, %d notes, %.1f s" % [notes.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	quit(0)


## A character at the line camp in the rain with two stretched green pelts drying: every simulation step draws
## the hair-slip chance.
func _rain_on_pelts_state() -> Dictionary:
	var core := SurvivalCore.new_game("bg.backcountry_hunter", {"seed": 7, "start_day": "nov_early", "start_hour": 10.0})
	core.go_to("poi.fort.woods_camp")
	SurvivalInventory.add(core, "item.pelt.marten", 2.0, {"grade": "good", "prime": 1.0, "condition": 1.0, "green": true,
			"stretched": true, "species": "marten", "dry_h": 0.0, "dry_need_h": 60.0})
	core.state.weather["state"] = "rain"
	core.state.weather["hours_to_tick"] = 48.0
	return core.to_dict()


func _drive_update(d: Dictionary, fps: int, real_s: float) -> SurvivalCore:
	var c := SurvivalCore.from_state(SurvivalState.from_dict(d))
	var dt := 1.0 / float(fps)
	for i in int(real_s * fps):
		c.update(dt)
	return c


func _drive_quantum(d: Dictionary, fps: int, steps: int) -> SurvivalCore:
	var c := SurvivalCore.from_state(SurvivalState.from_dict(d))
	var dt := 1.0 / float(fps)
	var acc := 0.0
	var done := 0
	var guard := 0
	while done < steps and guard < 5000000:
		guard += 1
		acc += dt * maxf(SurvivalClock.game_minutes_per_real_second(c), SurvivalJobs.speed_game_min_per_real_s(c))
		while acc >= SurvivalCore.STEP_MIN and done < steps:
			acc -= SurvivalCore.STEP_MIN
			c.advance(SurvivalCore.STEP_MIN)
			done += 1
	return c


func _fingerprint(c: SurvivalCore) -> String:
	return "%s|%s|%.9f|%.9f|%.9f" % [str(c.rng.state), SurvivalWeather.state_id(c), c.state.minutes,
			SurvivalUtil.num(c.state.needs.get("warmth"), 0.0), SurvivalUtil.num(c.state.needs.get("stomach"), 0.0)]


func _check_slicing() -> void:
	var d := _rain_on_pelts_state()
	var prints := {}
	for fps in FPS:
		prints[fps] = _drive_update(d, fps, REAL_S)
	var same := true
	for fps in FPS:
		if str(prints[fps].rng.state) != str(prints[FPS[0]].rng.state):
			same = false
	var detail := PackedStringArray()
	for fps in FPS:
		var c: SurvivalCore = prints[fps]
		detail.append("%d fps: rng %s, %.4f game min" % [fps, str(c.rng.state), c.state.minutes - float(d.minutes)])
	if same:
		notes.append("1 OK      update(delta) no longer depends on frame slicing (%s)" % "; ".join(detail))
	else:
		notes.append("1 KNOWN   update(delta) depends on frame slicing: per-step chance draws follow the frame count (%s). Plan refactor P0-1" % "; ".join(detail))


func _check_quantum() -> void:
	for label in ["rain on pelts", "fresh camp"]:
		var d: Dictionary
		if label == "rain on pelts":
			d = _rain_on_pelts_state()
		else:
			var core := SurvivalCore.new_game("bg.backcountry_hunter", {"seed": 5, "start_day": "dec_early"})
			core.go_to("poi.fort.sutler_store")
			d = core.to_dict()
		var fp := {}
		for fps in FPS:
			fp[fps] = _fingerprint(_drive_quantum(d, fps, QUANTUM_STEPS))
		var same: bool = str(fp[30]) == str(fp[60]) and str(fp[60]) == str(fp[144])
		if same:
			notes.append("2 OK      fixed quantum (%d x advance(%.0f)) is bit-identical at 30/60/144 fps (%s)" % [QUANTUM_STEPS, SurvivalCore.STEP_MIN, label])
		else:
			notes.append("2 ISSUE   fixed quantum differs by frame rate (%s): %s" % [label, str(fp)])


## 2b. Short jobs under a quantum driver. The whole-quantum driver of check 2 advances only when a full STEP_MIN has
## built up at job speed, so a 1-minute dram or a 4-6-minute trap check finishes several real seconds late. The
## corrected driver (multiplayer_readiness.md P0-1) ends each quantum at min(STEP_MIN, the running job's minutes left,
## the passed-out minutes left): the boundaries come from the state, so the steps stay frame-rate independent.
func _drive_boundary(c: SurvivalCore, fps: int, until_done: bool, max_calls: int, max_real_s: float) -> Dictionary:
	var dt := 1.0 / float(fps)
	var acc := 0.0
	var calls := 0
	var real := 0.0
	var seq0 := int(SurvivalUtil.num(c.state.jobs.get("seq"), 0.0))
	while real < max_real_s and calls < max_calls:
		real += dt
		var rate := maxf(SurvivalClock.game_minutes_per_real_second(c), SurvivalJobs.speed_game_min_per_real_s(c))
		acc += dt * rate
		while calls < max_calls:
			var b := SurvivalCore.STEP_MIN
			var jl := SurvivalJobs.minutes_left(c)
			if SurvivalJobs.is_running(c) and jl > 0.00001:
				b = minf(b, jl)
			var po := SurvivalUtil.num(c.state.flags.get("passed_out_until"), -1.0)
			if po > c.state.minutes:
				b = minf(b, po - c.state.minutes)
			if acc < b - 0.000001:
				break
			var had := SurvivalJobs.is_running(c)
			var old_rate := rate
			acc -= b
			c.advance(b)
			calls += 1
			if had and not SurvivalJobs.is_running(c):
				# The job ended: the surplus built at job speed is re-expressed at the clock's rate.
				rate = SurvivalClock.game_minutes_per_real_second(c)
				acc = acc / maxf(0.0001, old_rate) * rate
		if until_done and int(SurvivalUtil.num(c.state.jobs.get("seq"), 0.0)) != seq0:
			break
	return {"real_s": real, "calls": calls}


func _drive_whole(c: SurvivalCore, fps: int, max_real_s: float) -> float:
	var dt := 1.0 / float(fps)
	var acc := 0.0
	var real := 0.0
	var seq0 := int(SurvivalUtil.num(c.state.jobs.get("seq"), 0.0))
	while real < max_real_s:
		real += dt
		acc += dt * maxf(SurvivalClock.game_minutes_per_real_second(c), SurvivalJobs.speed_game_min_per_real_s(c))
		while acc >= SurvivalCore.STEP_MIN:
			acc -= SurvivalCore.STEP_MIN
			c.advance(SurvivalCore.STEP_MIN)
		if int(SurvivalUtil.num(c.state.jobs.get("seq"), 0.0)) != seq0:
			break
	return real


func _check_short_jobs() -> void:
	var base := SurvivalCore.new_game("bg.backcountry_hunter", {"seed": 9, "start_day": "nov_early", "start_hour": 10.0})
	base.go_to("poi.fort.woods_camp")
	var d := base.to_dict()
	var rows := PackedStringArray()
	var late := false
	for id in ["drink.item", "eat", "fire.gather"]:
		var cells := PackedStringArray()
		for fps in FPS:
			var cw := SurvivalCore.from_state(SurvivalState.from_dict(d))
			var r1 := cw.start_job(id)
			if not bool(r1.get("ok", false)):
				cells.append("%d fps: could not start (%s)" % [fps, str(r1.get("reasons", r1.get("reason", "")))])
				continue
			var screen := SurvivalUtil.num(cw.current_job().get("screen_s"), 0.0)
			var t_whole := _drive_whole(cw, fps, 60.0)
			var cb := SurvivalCore.from_state(SurvivalState.from_dict(d))
			cb.start_job(id)
			var t_bound: float = _drive_boundary(cb, fps, true, 100000, 60.0).real_s
			if t_bound > screen + 2.0 / float(fps) + 0.001:
				late = true
			cells.append("%d fps: screen %.2f s, whole quanta %.2f s, boundary quanta %.2f s" % [fps, screen, t_whole, t_bound])
		rows.append("%s (%s)" % [id, "; ".join(cells)])
	# Frame-rate independence of the boundary driver: the same number of advance() calls from a state with a job running.
	var fp := {}
	for fps in FPS:
		var c := SurvivalCore.from_state(SurvivalState.from_dict(d))
		c.start_job("fire.gather")
		_drive_boundary(c, fps, false, 150, 100000.0)
		fp[fps] = _fingerprint(c)
	var same: bool = str(fp[30]) == str(fp[60]) and str(fp[60]) == str(fp[144])
	notes.append("2b %s short jobs: the boundary driver finishes each job within a frame of its screen time; whole quanta finish late: %s" % ["OK   " if not late else "ISSUE", " | ".join(rows)])
	notes.append("2b %s boundary driver (quantum = min(STEP_MIN, job left, passed-out left)), 150 calls with a job running, bit-identical at 30/60/144 fps" % ("OK   " if same else "ISSUE"))


func _check_shared_stream() -> void:
	var base := SurvivalCore.new_game("bg.backcountry_hunter", {"seed": 21, "start_day": "dec_early"})
	base.go_to("poi.fort.sutler_store")
	var d := base.to_dict()
	var a := SurvivalCore.from_state(SurvivalState.from_dict(d))
	var b := SurvivalCore.from_state(SurvivalState.from_dict(d))
	b.rng.randf()   # one extra draw on the character's side, as one more skill check would make
	var wa := PackedStringArray()
	var wb := PackedStringArray()
	for i in 12:
		a.advance(240.0)
		b.advance(240.0)
		wa.append(SurvivalWeather.state_id(a))
		wb.append(SurvivalWeather.state_id(b))
	if wa == wb:
		notes.append("3 OK?     one extra character-side draw left 2 game days of weather unchanged (try another seed; the stream is still shared unless P0-2 landed)")
	else:
		notes.append("3 KNOWN   one shared stream: one extra character-side draw changes the weather within 2 game days (%s vs %s). Plan refactor P0-2" % [",".join(wa), ",".join(wb)])


func _sizes_and_cpu() -> void:
	var sim := SurvivalSim.new()
	sim.setup({"background": "bg.backcountry_hunter", "policy": "trapper", "days": 20, "seed": 3})
	sim.simulate(20)
	var core: SurvivalCore = sim.core
	var d := core.to_dict()
	var whole := JSON.stringify(d).to_utf8_buffer()
	notes.append("4 SIZE    character state at %s (%d traps, %d stacks): %d B JSON, %d B zstd" % [SurvivalClock.date_string(core),
			SurvivalTrapLine.traps(core).size(), core.state.inventory.size(), whole.size(), whole.compress(FileAccess.COMPRESSION_ZSTD).size()])
	var parts := []
	for k in d.keys():
		parts.append([JSON.stringify(d[k]).length(), str(k)])
	parts.sort_custom(func(x, y) -> bool: return int(x[0]) > int(y[0]))
	var top := PackedStringArray()
	for p in parts.slice(0, 7):
		top.append("%s %d" % [p[1], p[0]])
	notes.append("4 SIZE    largest sections (B JSON): " + ", ".join(top))
	var view := {"stages": core.need_stages(), "needs": core.state.needs, "icons": core.icons(), "mods": core.get_modifiers(),
			"health": core.health(), "job": str(core.current_job().get("action", ""))}
	var vb := JSON.stringify(view).to_utf8_buffer()
	notes.append("4 SIZE    HUD view (stages, meters, icons, modifiers): %d B JSON, %d B zstd" % [vb.size(), vb.compress(FileAccess.COMPRESSION_ZSTD).size()])
	var c1 := SurvivalCore.from_state(SurvivalState.from_dict(d))
	var t0 := Time.get_ticks_usec()
	for i in 144:
		c1.advance(SurvivalCore.STEP_MIN)
	var per_step := float(Time.get_ticks_usec() - t0) / 144.0
	var c2 := SurvivalCore.from_state(SurvivalState.from_dict(d))
	t0 = Time.get_ticks_usec()
	for i in 1200:
		c2.update(1.0 / 60.0)
	var per_frame := float(Time.get_ticks_usec() - t0) / 1200.0
	notes.append("5 CPU     advance(%.0f game min): %.0f us a step; update() at 60 fps: %.0f us a frame (one step each frame)" % [SurvivalCore.STEP_MIN, per_step, per_frame])
