extends SceneTree
## Round 4 VIRAL: the highlight cards (RingHighlights, HighlightCards; data/ring/highlights.json) and the callouts
## (Callouts; data/ring/callouts.json) in the % ring (rules stock; earth against a water bot, held), headless:
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_ring_highlights.gd -- mode=ring element=earth foe=water
##   plays        scripted plays through the match's own signals and the tracker's offer(): a 31 m/s launch by the player
##                that ends in a fall (the fall's bonus), a catch 0.06 s after its guard stood, a 3-catch rally, a perfect
##                guard streak of 4, a fall 3 s after the faller came back: the top 3 are the right kinds in the right order
##                (by the data's scores), one per kind, each with its snapshot (before_s + after_s of the buffer, both
##                competitors in it); a lower play of a kind never replaces its best
##   the cards    HighlightCards on a match screen: three cards, each with its title, line and number, Watch plays its clip
##                through the Splash Cam (and it ends)
##   callouts     SPLASH! on a fall, CAUGHT! on a catch within 0.15 s, PERFECT! on the player's perfect guard, LAST LIFE once,
##                one at a time by priority; Callouts: Off says nothing
##   words        every word a player can see here (the cards, the callouts, the rows, the replay tag, photo mode) scans clean:
##                no show words, none of the genre's big game's words
## METRIC callouts_count. Watchdog LIMIT_S; last line "RING HIGHLIGHTS PASSED" or "RING HIGHLIGHTS FAILED".

const NAME := "RING HIGHLIGHTS"
const LIMIT_S := 300.0
const OWN_CFG := "user://ring_highlights_test.cfg"
const SHOW_WORDS := ["avatar", "benders?", "bending", "pro-?bend\\w*", "korra", "aang", "airbend\\w*", "firebend\\w*",
		"earthbend\\w*", "waterbend\\w*", "fire nation", "water tribes?", "earth kingdom", "air nomads?", "bend\\w*"]
const GAME_WORDS := ["stocks?", "blast ?zones?", "di", "tech", "edge-?guard\\w*", "meteor", "smash\\w*", "final smash"]

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var ring: RingArena
var player: FrontierPlayer
var mode: RingMode
var rules: RingRules
var rp: RingReplay
var hl: RingHighlights
var co: Callouts
var metrics := {}


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	MatchSetup._aim_help = "strong"
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	RingRules.rule_set_override = "stock"
	SwayCaster.free_override = true
	InputSetup.ensure()
	MatchSetup.incoming = true
	MatchSetup.element = "earth"
	MatchSetup.foes = ["water"]
	RingReplay.force = "off"
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit:
		if cond.call():
			return t
		await process_frame
		t += 1.0 / 60.0
	return INF


func _end() -> void:
	for k: String in metrics:
		print("METRIC %s=%s" % [k, str(metrics[k])])
	RingRules.rule_set_override = ""
	RingReplay.force = ""
	GameSettings.path = GameSettings.PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


func foe() -> NpcFighter:
	return mode.foe if mode != null and is_instance_valid(mode.foe) else null


func _run() -> void:
	for i in 10:
		await process_frame
	lvl = current_scene as RingLevel
	ring = lvl.ring
	player = lvl.player
	player.ignore_mouse_capture = true
	mode = RingMode.find(self)
	rules = mode.rules
	await _until(func() -> bool: return mode.phase == "COUNTDOWN" and foe() != null, 6.0)
	mode.phase_t = RingRules.num("countdown_s", 3.0) - 0.02
	await _until(func() -> bool: return mode.phase == "FIGHT", 2.0)
	foe().held = true
	rp = RingReplay.install(mode)
	hl = RingHighlights.find(self)
	co = Callouts.find(self)
	_expect(hl != null and co != null, "the tracker and the callouts installed")
	await _ticks(int(4.5 * Engine.physics_ticks_per_second))       # (the buffer holds a play's whole snapshot)
	await _plays()
	await _cards()
	await _callouts_off()
	_words()
	_end()


func _plays() -> void:
	var f := foe()
	Callouts.shown.clear()
	# a launch of 31 m/s by the player that ends in a fall within ko_after_s (through the rules' own signals)
	rules.launched.emit(f, Vector3(31.0, 0.0, 0.0), 0.8, player, "stone_form/cannonball")
	await _ticks(20)
	rules.ko.emit(f, player, 140.0, "stone_form/cannonball", 2)
	await _ticks(10)
	# a lower launch never replaces it
	rules.launched.emit(f, Vector3(14.0, 0.0, 0.0), 0.4, player, "stone_form/spike")
	# a catch 0.06 s after its guard stood (the tracker's offer: the guard's age is the play's number)
	_expect(hl.offer("catch", 0.06, player, null), "a catch 0.06 s after its guard stood is offered")
	# a rally of 3, a streak of 4 perfect guards (the foe's: not the player's side)
	hl.offer("rally", 3.0, player, f)
	for i in 4:
		BendCaster.of(f).guarded.emit("perfect", "water")
		await _ticks(2)
	# a fall dealt 3 s after the faller came back on
	await _ticks(60)
	var plays := {}
	for p: Dictionary in hl.plays():
		plays[p.kind] = p
	var lp := plays.get("launch", {}) as Dictionary
	var cfg := RingHighlights.play_cfg("launch")
	var want_launch := float(cfg.base) + float(cfg.per) * 31.0 + RingHighlights.num("ko_bonus", 18.0) + RingHighlights.num("mine_bonus", 6.0)
	_expect(not lp.is_empty() and absf(float(lp.score) - want_launch) < 0.01 and absf(float(lp.value) - 31.0) < 0.01,
			"the launch: 31 m/s, its fall's bonus and the player's (score %.1f, wanted %.1f)" % [float(lp.get("score", 0.0)), want_launch])
	var pp := plays.get("perfect", {}) as Dictionary
	_expect(not pp.is_empty() and int(pp.value) == 4 and not bool(pp.mine), "the foe's 4 perfect guards in a row (not the player's side)")
	var cp := plays.get("catch", {}) as Dictionary
	_expect(not cp.is_empty() and absf(float(cp.value) - 0.06) < 1e-4, "the closest catch: 0.06 s")
	# the top 3 by the data's scores
	var want: Array = plays.values()
	want.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.score) > float(b.score))
	await _ticks(int(RingReplay.sub("highlight", "after_s", 1.0) * Engine.physics_ticks_per_second) + 10)
	var cards := hl.cards()
	var kinds: Array = cards.map(func(c: Dictionary) -> String: return String(c.kind))
	var wk: Array = want.slice(0, 3).map(func(p: Dictionary) -> String: return String(p.kind))
	_expect(cards.size() == 3 and kinds == wk, "the top 3: %s (by score: %s)" % [str(kinds), str(wk)])
	var snaps_ok := true
	var want_n := int(round((RingReplay.sub("highlight", "before_s", 3.0) + RingReplay.sub("highlight", "after_s", 1.0)) * rp.tps)) + 1
	for c: Dictionary in cards:
		var clip: Variant = c.clip
		if not (clip is RingReplay.Clip):
			snaps_ok = false
			print("    no snapshot for %s" % c.kind)
			continue
		var cl := clip as RingReplay.Clip
		var both := cl.bodies.size() >= 2 and not (cl.bodies[0] as Dictionary).is_empty() and not (cl.bodies[1] as Dictionary).is_empty()
		if absi(cl.n - want_n) > 2 or not both:
			snaps_ok = false
			print("    %s: %d ticks (want %d), both %s" % [c.kind, cl.n, want_n, both])
	_expect(snaps_ok, "each card holds its snapshot: %d ticks (before_s + after_s), both competitors in it" % want_n)
	var shown := Callouts.shown.duplicate()
	_expect("SPLASH!" in shown, "SPLASH! on the fall (%s)" % str(shown))


func _cards() -> void:
	var ms := mode.match_screen as MatchScreen
	var hc := HighlightCards.make(mode)
	ms.get_node("Root").add_child(hc)
	hc.refresh()
	var ok := hc.shown.size() == 3
	for c: Dictionary in hc.shown:
		ok = ok and String(c.title) != "" and String(c.line) != "" and String(c.num) != "" and not String(c.line).contains("{")
	_expect(ok, "three cards on the match screen, each a title, a line and a number: %s" % str(hc.shown.map(func(c: Dictionary) -> String:
			return "%s | %s | %s" % [c.title, c.line, c.num])))
	var started := hc.watch_card(hc.shown[0])
	_expect(started and rp.is_playing() and paused, "Watch plays the card's clip through the Splash Cam")
	await _until(func() -> bool: return not rp.is_playing(), 10.0)
	_expect(not rp.is_playing() and not paused, "and it ends, the match going on")
	hc.queue_free()


func _callouts_off() -> void:
	Callouts.shown.clear()
	var c := co
	# CAUGHT within 0.15 s, PERFECT on the player's guard: one at a time, the higher first
	hl.moment.emit("perfect", player, {})
	hl.moment.emit("caught", player, {"t": 0.08})
	_expect(c.showing() == "CAUGHT!", "one at a time: CAUGHT! (priority %d) over PERFECT! (%d)" % [int(Callouts.call_cfg("caught").priority),
			int(Callouts.call_cfg("perfect").priority)])
	await _until(func() -> bool: return c.showing() == "PERFECT!", 3.0)
	_expect(c.showing() == "PERFECT!", "PERFECT! after it (it waited)")
	await _until(func() -> bool: return c.showing() == "", 3.0)
	hl.moment.emit("perfect", foe(), {})
	_expect(c.showing() == "", "the foe's perfect guard is not called out on the player's screen (who: mine)")
	hl._last_life_said = false
	hl._say_last_life()
	hl._say_last_life()
	_expect(Callouts.shown.count("LAST LIFE") == 1, "LAST LIFE once")
	metrics["callouts_count"] = Callouts.words().size()
	Callouts.set_on(false)
	await _until(func() -> bool: return c.showing() == "", 3.0)
	var n := Callouts.shown.size()
	hl.moment.emit("splash", player, {})
	_expect(Callouts.shown.size() == n and Callouts.row_text().contains("Off"), "Callouts: Off says nothing")
	Callouts.set_on(true)


func _words() -> void:
	var lines: Array = []
	for d: Dictionary in [RingHighlights.data(), Callouts.data(), RingReplay.data()]:
		_strings(d, lines)
	if hl != null:
		for c: Dictionary in hl.cards():
			lines.append_array([c.title, c.line, c.num])
	lines.append_array([RingReplay.row_text(), Callouts.row_text(), PhotoMode.row_text(), PhotoMode.row_line()])
	var bad: Array = []
	for w: String in SHOW_WORDS + GAME_WORDS:
		var re := RegEx.create_from_string("(?i)\\b(" + w + ")\\b")
		for l: Variant in lines:
			if re.search(String(l)) != null:
				bad.append("%s in \"%s\"" % [w, l])
	_expect(bad.is_empty(), "every word a player sees here scans clean (%d lines)%s" % [lines.size(), "" if bad.is_empty() else ": " + str(bad)])


## Every string value of `d` (never its "_..." doc keys or ids).
func _strings(v: Variant, out: Array, key := "") -> void:
	if key.begins_with("_") or key in ["dir", "keys", "sound", "sound_fallback", "colors"]:
		return
	if v is Dictionary:
		for k in v:
			_strings(v[k], out, String(k))
	elif v is Array:
		for x in v:
			_strings(x, out, key)
	elif v is String:
		out.append(v)
