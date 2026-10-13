extends SceneTree
## THE FIRST FIVE MINUTES (Tidebreak round 4, SIMPLE: "simple like runescape but hard to master like runescape"): a scripted
## NEWCOMER (tools/ring/newcomer_sim.gd: walks at the foe, clicks in range, taps 1 and right-clicks when the foe is far, taps
## E late and imperfectly when something flies at him, HOLDS Space whenever thrown) plays the Basic controls in a % ring
## match (rules stock, one game of 3 lives) against the EASY bot, seeded runs, each up to 5 minutes of game time (a lost
## game: a new one, the same five minutes):
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_first_five.gd -- [runs=20] [from=0] [model=newcomer]
##         [controls=basic] [difficulty=easy] [limit_s=300] [full_runs=2] [full_s=40] [gate=on]
##   the gate (model newcomer, controls basic, difficulty easy, runs 20 from 0; gate=off: numbers only)
##     newcomer_win_rate     a game won within limit_s in >= 60% of the runs
##     newcomer_recover_rate of the launches that took him off the deck and that he could survive (RingPredict.flight: the
##                           model's recovery comes back), >= 70% back on the deck or the edge
##     unused falls          never a fall with the double jump or the Rise unused (free 0.3 s or more off the deck first)
##     full_unchanged        Full untouched: full_runs seeds played full_s s with controls=full and RingAssist on the player:
##                           every frame the keys as the game reads them (RingMoves.intent_from_keys) through the helper's
##                           wrapper and straight from his own controls are the same, and the helper presses nothing (so
##                           controls=full gives round 3's numbers: run it with gate=off for the Full table)
## Each run: the player's element ELS[i % 4], the foe's ELS[(i / 4) % 4] (every pairing over 16 runs), the bot's dice the
## run's (RingMode's seed 7300 + 31 i), the sim's 9000 + i. RingAssist is installed here (RingMode's set-up does it once the
## merge applies SIMPLE's hook; installing twice is one). model=expert difficulty=normal controls=full: the expert-ish model's
## numbers against the normal bot (gate=off).
## The numbers table: one line per run, then METRIC newcomer_win_rate, newcomer_recover_rate, full_unchanged.
## The 20 runs take about 14 minutes of wall time headless (some 3.6 times game speed), past the runner's GODOT_TIMEOUT 420:
## under it the gate runs in parts, each a run of its own: part=1 .. part=4 (five runs each, kept in user://first_five_*.json)
## then part=sum (the four parts' rows read back, the Full check played, the gate). With no part= every run in one go
## (GODOT_TIMEOUT 1200). The in-test watchdog counts game seconds (LIMIT_S plus each run's limit_s and the Full check's). Last line "FIRST FIVE PASSED" or
## "FIRST FIVE FAILED"; exit 0 only on a pass.

const NAME := "FIRST FIVE"
const LIMIT_S := 410.0
const OWN_CFG := "user://first_five_test.cfg"
const Sim := preload("res://tools/ring/newcomer_sim.gd")
const ELS := ["earth", "water", "fire", "air"]

var checks := 0
var fails: Array[String] = []
var runs := 20
var from := 0
var model := "newcomer"
var controls := "basic"
var difficulty := "easy"
var limit_s := 300.0
var full_runs := 2
var full_s := 40.0
var gate := true
var rows: Array = []
## "" all in one go, "1".."4" a quarter of the 20 each, "sum" the parts' rows read back and gated.
var part := ""
const PARTS := 4


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	MatchSetup._aim_help = "light"
	seed(1750)
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		var k := kv.get_slice("=", 0)
		var v := kv.get_slice("=", 1)
		match k:
			"runs":
				runs = int(v)
			"from":
				from = int(v)
			"model":
				model = v
			"controls":
				controls = v
			"difficulty":
				difficulty = v
			"limit_s":
				limit_s = float(v)
			"full_runs":
				full_runs = int(v)
			"full_s":
				full_s = float(v)
			"gate":
				gate = v in ["on", "true", "1"]
			"part":
				part = v
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	InputSetup.ensure()
	RingRules.rule_set_override = "stock"
	# (the watchdog in the game's own seconds: with --fixed-fps every frame is 1/60 s whatever the wall clock; the runs'
	# five minutes each, the Full check, a margin; GODOT_TIMEOUT is the wall's guard)
	var per := runs if part == "" else int(ceil(float(runs) / PARTS))
	if part == "sum":
		per = 0
	var limit := LIMIT_S + per * (limit_s + 20.0) + full_runs * (full_s + 20.0)
	create_timer(limit, true, false, true).timeout.connect(func() -> void:
		_table()
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	_run.call_deferred()


func _end() -> void:
	RingRules.rule_set_override = ""
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		print("%s FAILED (%d of %d: %s)" % [NAME, fails.size(), checks, "; ".join(fails)])
		quit(1)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


## Full's check, between the sim's hands (-20) and the helper (-8) and the player (0): the intent through the wrapper and
## straight from the wrapped controls, compared every frame.
class SameKeys:
	extends Node
	var p: FrontierPlayer
	var frames := 0
	var differ := 0
	var first := ""

	func _ready() -> void:
		process_physics_priority = -4

	func _physics_process(_dt: float) -> void:
		var rm := RingMoves.of(p)
		var w := p.controls as RingAssist.AssistControls
		if rm == null or w == null:
			return
		var a := rm.intent_from_keys()
		p.controls = w.inner
		var b := rm.intent_from_keys()
		p.controls = w
		frames += 1
		if var_to_str(a) != var_to_str(b):
			differ += 1
			if first == "":
				first = "%s / %s" % [var_to_str(a), var_to_str(b)]


## One seeded run: {won, t_win, games, launches, falls, presses, same: [frames, differ]}.
func _one(i: int, ctl: String, mdl: String, diff: String, limit: float, assist := true, check_same := false) -> Dictionary:
	seed(1750 + i)
	MatchSetup.reload_scheme()
	MatchSetup.set_controls(ctl)
	MatchSetup._aim_help = "light"
	MatchSetup.incoming = true
	MatchSetup.kind = "match"
	MatchSetup.element = String(ELS[i % 4])
	MatchSetup.foes = [String(ELS[(i / 4) % 4])]
	MatchSetup.difficulty = diff
	MatchSetup.games_n = 1
	# (the ring loaded once (a load is most of a run's wall time on a busy machine); each run a restart with its own
	# elements and dice, as the Esc menu's restart takes MatchSetup's choices)
	var mode: RingMode = RingMode.find(self)
	if mode == null or mode.player == null or not is_instance_valid(mode.player):
		change_scene_to_file("res://scenes/ring.tscn")
		for f in 900:
			await physics_frame
			mode = RingMode.find(self)
			var p0: FrontierPlayer = mode.player if mode != null else null
			if p0 != null and p0.arena_element != "" and mode.rules != null and SwayCaster.of(p0) != null:
				break
	if mode == null or mode.player == null:
		return {"error": "no ring"}
	var p: FrontierPlayer = mode.player
	mode.set(&"_seed", 7300 + 31 * i)
	(mode.get(&"_rng") as RandomNumberGenerator).seed = 7300 + 31 * i
	p.controls = PlayerControls.new(false)
	mode.restart()
	await physics_frame
	p.ignore_mouse_capture = true
	var a: RingAssist = RingAssist.install(p) if assist else null
	var st0: Dictionary = a.stats.duplicate(true) if a != null else {}
	var sim: Node = Sim.new()
	sim.call(&"setup", p, mode, mdl, 9000 + i)
	current_scene.add_child(sim)
	var same: SameKeys = null
	if check_same:
		await physics_frame                 # (the helper's wrapper on first)
		same = SameKeys.new()
		same.p = p
		current_scene.add_child(same)
	var t := 0.0
	var dt := 1.0 / Engine.physics_ticks_per_second
	var won := false
	var games := 1
	while t < limit:
		await physics_frame
		t += dt
		if mode.phase == "DONE":
			if mode.winner == 0:
				won = true
				break
			games += 1
			mode.restart()
	var pr := {}
	if a != null:
		for k: String in (a.stats.presses as Dictionary):
			var dk := int(a.stats.presses[k]) - int((st0.get("presses", {}) as Dictionary).get(k, 0))
			if dk != 0:
				pr[k] = dk
	sim.call(&"_let_go")
	var out := {"won": won, "t": t, "games": games, "launches": (sim.get(&"launches") as Array).duplicate(true),
			"falls": (sim.get(&"falls") as Array).duplicate(true), "presses": pr,
			"desperate": int(a.stats.desperate) - int(st0.get("desperate", 0)) if a != null else 0, "casts": int(sim.get(&"casts")), "clicks": int(sim.get(&"clicks")),
			"guards": int(sim.get(&"guards")), "el": MatchSetup.element, "foe": String(MatchSetup.foes[0]),
			"same": [same.frames, same.differ, same.first] if same != null else []}
	sim.queue_free()
	if same != null:
		same.queue_free()
	return out


func _part_path(k: int) -> String:
	return "user://first_five_%s_%s_%s_part%d.json" % [model, controls, difficulty, k]


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	var keep := ""
	if part == "sum":
		runs = 0                             # (the rows to come: every part's)
		for k in range(1, PARTS + 1):
			var txt := FileAccess.get_file_as_string(_part_path(k))
			var got: Variant = JSON.parse_string(txt) if txt != "" else null
			_expect(got is Array and (got as Array).size() > 0, "part %d's rows read back (%s)" % [k, _part_path(k)])
			if got is Array:
				rows.append_array(got as Array)
		from = 0
	elif part != "":
		var k := int(part)
		var per := int(ceil(float(runs) / PARTS))
		from = from + (k - 1) * per
		runs = per
		full_runs = 0
		keep = _part_path(k)
	for i in range(from, from + runs):
		var r := await _one(i, controls, model, difficulty, limit_s)
		r["i"] = i
		rows.append(r)
		var off := 0
		var back := 0
		for l: Dictionary in (r.get("launches", []) as Array):
			if bool(l.off) and bool(l.survivable) and String(l.result) in ["back", "out"]:
				off += 1
				back += 1 if String(l.result) == "back" else 0
		var unused := 0
		for f: Dictionary in (r.get("falls", []) as Array):
			unused += 1 if bool(f.unused) else 0
		print("  run %2d  %-5s v %-5s  %s at %5.1f s  games %d  falls %d (unused %d)  off-deck launches %d, back %d  presses %s  desperate %d  casts %d clicks %d guards %d  (%.1f s wall)" % [
				i, r.get("el", "?"), r.get("foe", "?"), "WON " if bool(r.get("won", false)) else "lost", float(r.get("t", 0.0)),
				int(r.get("games", 0)), (r.get("falls", []) as Array).size(), unused, off, back, r.get("presses", {}),
				int(r.get("desperate", 0)), int(r.get("casts", 0)), int(r.get("clicks", 0)), int(r.get("guards", 0)),
				(Time.get_ticks_msec() - t0) / 1000.0])
		for f: Dictionary in (r.get("falls", []) as Array):
			print("        fall at %s s: unused %s, free off the deck %s s, jumps %s, rise %s, launch %s, helper %s" % [f.get("at"),
					f.get("unused"), f.get("free_off_s"), f.get("jumps"), f.get("rise"), f.get("launch"), f.get("assist", {}).get("presses", {})])
	var full_ok := true
	var full_done := 0
	if full_runs > 0:
		for j in range(full_runs):
			var i2 := from + j
			var fr := await _one(i2, "full", model, difficulty, full_s, true, true)
			var sm: Array = fr.get("same", [])
			var ok := sm.size() == 3 and int(sm[0]) > int(full_s * 50.0) and int(sm[1]) == 0 and (fr.get("presses", {}) as Dictionary).is_empty()
			print("  full run %d: %s frames, the keys through the helper and straight %s; its presses %s" % [i2,
					sm[0] if sm.size() == 3 else "?", "the same every frame" if ok else "DIFFER (%s: %s)" % [sm[1] if sm.size() == 3 else "?", sm[2] if sm.size() == 3 else ""],
					fr.get("presses", {})])
			full_ok = full_ok and ok
			full_done += 1
	_table()
	if keep != "":
		var f := FileAccess.open(keep, FileAccess.WRITE)
		f.store_string(JSON.stringify(rows))
		f.close()
		_expect(rows.size() == runs, "part %s: %d runs played, kept for part=sum (%s)" % [part, rows.size(), keep])
		print("METRIC full_unchanged=n/a")
		_end()
		return
	if gate:
		var s := _sums()
		_expect(float(s.win_rate) >= 0.6, "the newcomer wins a game within %.0f s in %.0f%% of %d runs (>= 60%%)" % [limit_s, 100.0 * float(s.win_rate), rows.size()])
		_expect(float(s.recover_rate) >= 0.7, "he comes back from %.0f%% of the %d off-deck launches he could survive (>= 70%%)" % [100.0 * float(s.recover_rate), int(s.off)])
		_expect(int(s.unused) == 0, "never a fall with a recovery unused (%d)" % int(s.unused))
		if full_runs > 0:
			_expect(full_ok, "Full untouched: %d seeds, the keys the game reads the same every frame with the helper on, no press of its" % full_done)
	else:
		_expect(rows.size() == runs if part != "sum" else rows.size() > 0, "%d runs played (numbers only)" % rows.size())
	print("METRIC full_unchanged=%s" % ("n/a" if full_runs <= 0 else str(full_ok)))
	_end()


func _sums() -> Dictionary:
	var won := 0
	var off := 0
	var back := 0
	var unused := 0
	var falls := 0
	for r: Dictionary in rows:
		won += 1 if bool(r.get("won", false)) else 0
		for l: Dictionary in (r.get("launches", []) as Array):
			if bool(l.off) and bool(l.survivable) and String(l.result) in ["back", "out"]:
				off += 1
				back += 1 if String(l.result) == "back" else 0
		for f: Dictionary in (r.get("falls", []) as Array):
			falls += 1
			unused += 1 if bool(f.unused) else 0
	return {"won": won, "win_rate": float(won) / maxf(rows.size(), 1), "off": off, "back": back,
			"recover_rate": float(back) / maxf(off, 1), "unused": unused, "falls": falls}


func _table() -> void:
	var s := _sums()
	print("  %s %s v %s, %d runs from %d: won %d (%.0f%%), off-deck survivable launches %d, back %d (%.0f%%), falls %d, unused %d" % [
			model, controls, difficulty, rows.size(), from, int(s.won), 100.0 * float(s.win_rate), int(s.off), int(s.back),
			100.0 * float(s.recover_rate), int(s.falls), int(s.unused)])
	var tag := "newcomer" if model == "newcomer" else model
	print("METRIC %s_win_rate=%.3f runs=%d won=%d controls=%s difficulty=%s" % [tag, float(s.win_rate), rows.size(), int(s.won), controls, difficulty])
	print("METRIC %s_recover_rate=%.3f off=%d back=%d falls=%d unused=%d" % [tag, float(s.recover_rate), int(s.off), int(s.back), int(s.falls), int(s.unused)])
