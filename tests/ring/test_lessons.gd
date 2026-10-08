extends SceneTree
## Tidebreak's lessons in Practice (RingLessons, LessonCard, data/ring/lessons.json) and a first Quick match's key hints
## (FirstHints, the ring's Esc row), round 2 of the skills (skills_r2 spec §9: the same buttons for every element; the key
## layout of spec §8.1 put in by tests/ring/r2_layout.gd while the kits' data is not merged), the test's own settings file
## (GameSettings.path):
##   the entry   the main menu's Practice panel: its Lessons row (its line: the lessons for your element and scheme) asks
##               for them (RingMode.lessons_asked, a practice against your element's own dummy) and plays into the ring
##               through the loading screen; RingMode installs the lessons, the card shows lesson 1
##   keys, earth every lesson of the run completed by its action as the player does it (a walk, a click of LMB, keys 1-5
##               pressed and RMB held and let go, E as the dummy's slowed stone comes and E again, a jump, Q then LMB, the
##               dummy knocked back and into the water), and only by it; the card's line holds each of its keys as bound
##               now ([W] [A] [S] [D], [RMB], [LMB], [1]-[5], [E], [Space], [Q]); a rebound key shows in the line. E is
##               clicked as the dummy's shot comes, timed to its beat (tests/ring/guard_timing.gd); nothing is stood in
##   the drill   through the guard drill the dummy throws slowly (RingMode.slow_throws: a throw each slow_every_s, its shots
##               at slow_speed of their speed), and back to its own pace after it; fire's jump card throws fire's Kick
##   elements    water, fire and air under the keys scheme (a restart brings each one's own dummy): the run resumes at its
##               own strike (the element's words: Lash, Punch, Slice), its guard card names its guard (Turn, Parry, Wind
##               Guard) on E and is done only by a guard on the beat (perfect; a late one leaves it open)
##   schemes     first moves (when the data has it), direction and radial: their runs and every card's line with its keys
##   skip/resume Enter skips (kept as skipped), a lesson done is kept as done; a new run begins at the first neither and goes
##               past the rest; the menu's line says where; all done: from the start again, and a skip then keeps done
##   the hints   installed over the match (the Esc row turns them on and off; on, shown at once), the scheme's rows with its
##               keys; each fades once its key is used, all gone turns them off (kept); wanted only for a Quick match with
##               them on
##   words       no show word in any line shown, the menu's lines, the hints; nothing put on the dummy (its children as before)
##   ROUND 3     the % ring's cards (smash_r3 spec §11.2) with the gate on by a stand-in RingRules (tests/npc/r3_standins.gd;
##               the signals PERCENT's RingRules and MOVE's RingMoves send, sent by the test): the zones' cards gone, the six
##               core cards and the three more in order, each done by its own doing (the dummy's % at 40, it into the water,
##               a double jump, an air dodge, back on the edge, an edge option, a 3-hit string, a launch steered, it kept off),
##               each card's % and place set as it begins; one skipped by Enter and kept as skipped, the run resumed past it;
##               the stock guard card's line; the String card's earth line (E throws the stone) and the others' (right-click
##               your 1); the hint queue: one hint per gap_s, the edge hint pre-empts, the stale hint only after a fall
##               (hint_queue_ok)
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_lessons.gd
## The last line "LESSONS TEST PASSED" or "LESSONS TEST FAILED"; exit 0 only on a pass; a watchdog quits with 2.

const NAME := "LESSONS TEST"
const LIMIT_S := 400.0
const OWN_CFG := "user://lessons_test.cfg"
const R2Layout := preload("res://tests/ring/r2_layout.gd")
const GuardTiming := preload("res://tests/ring/guard_timing.gd")
const WORDS := ["avatar", "benders?", "bending", "pro-?bend\\w*", "korra", "aang", "airbend\\w*", "firebend\\w*",
		"earthbend\\w*", "waterbend\\w*", "air scooters?", "fire nation", "water tribes?", "earth kingdom", "air nomads?",
		"water whip", "air balls?", "air shields?", "spouts?", "redirect lightning"]
## Each element's guard and strike by its plain name (spec §3).
const GUARD_NAME := {"earth": "Catch", "water": "Turn", "fire": "Parry", "air": "Wind Guard"}
const STRIKE_NAME := {"earth": "Spike", "water": "Lash", "fire": "Punch", "air": "Slice"}

var checks := 0
var fails: Array[String] = []
var m: MainMenu
var lvl: RingLevel
var mode: RingMode
var p: FrontierPlayer
var c: SwayCaster
var ls: RingLessons
var casts: Array = []
var seen_lines: Array = []
var stood_in: Array = []
var _home := Vector3.INF
var _re := RegEx.create_from_string("(?i)\\b(?:%s)\\b" % "|".join(PackedStringArray(WORDS)))


## FirstHints' rows for `sch` under the rule set now (a row with "rules" only under those: round 3).
func _hint_rows(sch: String) -> Array:
	var out: Array = []
	for h: Dictionary in RingLessons.data()["hints"][sch]:
		if not h.has("rules") or RingLessons.rules_now() in (h.rules as Array):
			out.append(h)
	return out


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
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	MatchSetup.reload_scheme()
	MatchSetup._aim_help = "strong"             # (this test's player does not aim his camera: the full help)
	SwayCaster.free_override = true
	InputSetup.ensure()
	KitWords.ensure_guard_action()
	var laid := R2Layout.apply()
	print("  info round 2's key layout %s" % ("put in for this run (the kits' data not merged here)" if laid else "from the data"))
	RingMode.lessons_asked = false
	FirstHints.force = false
	MatchSetup.element = "earth"
	# (the merge: rules.json plays the % ring by default; the classic run pinned (RingRules.rule_set_override), the % ring's
	# lessons by the stand-in rules in _stock)
	RingRules.rule_set_override = "classic"
	change_scene_to_file("res://scenes/main_menu.tscn")
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(s: float) -> void:
	await _ticks(maxi(int(s * Engine.physics_ticks_per_second), 1))


func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit:
		if cond.call():
			return t
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return INF


func _end() -> void:
	for a: StringName in [&"fire", &"aim", &"move_forward", &"jump", RadialWheel.ACTION]:
		if InputMap.has_action(a):
			Input.action_release(a)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	RingRules.rule_set_override = ""
	MatchSetup.reload_scheme()
	FirstHints.force = false
	_expect(stood_in.is_empty(), "every lesson done by the player's own input, nothing stood in (%s)" % [stood_in])
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


func _action(a: StringName) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = a
		e.pressed = down
		Input.parse_input_event(e)
		await _ticks(3)


func _key(code: Key) -> void:
	for down in [true, false]:
		var k := InputEventKey.new()
		k.physical_keycode = code
		k.keycode = code
		k.pressed = down
		Input.parse_input_event(k)
		await process_frame


## Action `a`'s cap as this test reads its binding (the card's own reading is LessonCard.glyph).
static func cap(a: StringName) -> String:
	for e in InputMap.action_get_events(a):
		if e is InputEventKey:
			var k := e as InputEventKey
			return "[%s]" % OS.get_keycode_string(k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)
		if e is InputEventMouseButton:
			var b := (e as InputEventMouseButton).button_index
			return "[%s]" % {MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_WHEEL_DOWN: "Wheel",
					MOUSE_BUTTON_WHEEL_UP: "Wheel"}.get(b, "?")
	return "[?]"


func foe() -> NpcFighter:
	return mode.foe if mode != null and is_instance_valid(mode.foe) else null


# ---------------------------------------------------------------- the run
func _run() -> void:
	for i in 6:
		await process_frame
	m = current_scene as MainMenu
	_expect(m != null, "the main menu")
	if m == null:
		return _end()
	await _menu()
	var t := await _until(func() -> bool: return current_scene is RingLevel and RingMode.find(self) != null, 60.0)
	_expect(t < INF, "the ring loaded from the menu (%.1f s)" % t)
	if t == INF:
		return _end()
	lvl = current_scene as RingLevel
	mode = RingMode.find(self)
	p = lvl.player
	await _until(func() -> bool: return not LoadingScreen.covering() and p.arena_element == "earth" and p.hotbar.spell != "", 30.0)
	p.ignore_mouse_capture = true
	p.pitch = -0.15
	c = SwayCaster.of(p)
	c.cast.connect(func(mv: String, _t: Node3D) -> void: casts.append([mv, c.mode_of(mv)]))
	await _until(func() -> bool: return mode.phase == "FIGHT" and foe() != null, 10.0)
	ls = RingLessons.find(self)
	_expect(ls != null and mode.practice and mode.foe_element == "earth" and ls.get_parent() == mode,
			"the practice with its lessons under the match (%s, a %s dummy)" % [mode.practice, mode.foe_element])
	if ls == null:
		return _end()
	RingLessons.data()["done_hold_s"] = 0.3      # (the run quicker: the green card held a moment only)
	await _until(func() -> bool: return ls.at >= 0, 2.0)
	_expect(ls.at == 0 and ls.current_id() == "move" and ls.card.is_showing()
			and ls.card.kicker_text().begins_with(RingLessons.word("kicker") % [1, ls.list.size()]),
			"the card: lesson 1 of %d, %s (%s)" % [ls.list.size(), ls.current_id(), ls.card.kicker_text()])
	_home = p.global_position.lerp(foe().global_position, 0.3)
	await _keys_run()
	await _elements()
	await _schemes()
	await _resume()
	await _hints()
	await _stock()
	_words()
	var bad: Array = []
	for n in ls.find_children("*", "", true, false):
		if not (n is CanvasLayer or n is Control):
			bad.append(n.name)
	_expect(bad.is_empty() and ls.card.get_parent() == ls, "the lessons draw on a screen layer only, nothing in the ring (%s)" % [bad])
	_end()


# ---------------------------------------------------------------- round 3: the % ring's cards and the hint queue
func _stock() -> void:
	const Standins := preload("res://tests/npc/r3_standins.gd")
	# the hint queue, by itself
	var q := RingLessons.HintQueue.new(RingLessons.data().get("hint_queue", {}))
	q.push("steer")
	var a := q.next(0.0)
	q.push("break_fall")
	var b := q.next(5.0)
	var c2 := q.next(20.5)
	q.push("stale")
	q.push("edge")
	var d := q.next(22.0)
	var e := q.next(60.0)
	q.falls = 1
	var f := q.next(60.0)
	var ok := a == "steer" and b == "" and c2 == "break_fall" and d == "edge" and e == "" and f == "stale"
	print("METRIC hint_queue_ok=%s (%s)" % [ok, q.shown])
	_expect(ok, "the hint queue: steer, nothing 5 s later, break_fall at 20.5 s, edge pre-empts at 22 s, stale only after a fall (%s)" % [q.shown])
	# the cards, under the % ring's rules
	var rules := Standins.install_rules()
	_expect(RingLessons.rules_now() == "stock", "round 3: the % ring's rules (a stand-in RingRules)")
	var sch := MatchSetup.scheme()
	var el := ls.element
	var ids: Array = []
	for l: Dictionary in RingLessons.lessons_for(sch, el):
		ids.append(String(l.id))
	var core := ["pct", "out", "jumps", "dodge", "back", "edge", "string", "steer", "keep_off"]
	var at_core := ids.find("pct")
	_expect(not "zones" in ids and not "water" in ids and at_core >= 0 and ids.slice(at_core, at_core + 9) == core,
			"the zones' cards gone, the nine in order (%s)" % [ids])
	var guard_l := {}
	var str_l := {}
	for l: Dictionary in RingLessons.data().lessons:
		if String(l.id) == "guard":
			guard_l = l
		if String(l.id) == "string":
			str_l = l
	_expect(String(RingLessons.by_of(guard_l, sch).line).begins_with("[bend_guard]: up as soon as it's ready, and it stays while you hold it"),
			"the stock guard card: \"%s\"" % RingLessons.by_of(guard_l, sch).line)
	var keep_el := ls.element
	ls.element = "earth"
	var earth_line := ls.line_spec(str_l)
	ls.element = "water"
	var water_line := ls.line_spec(str_l)
	ls.element = keep_el
	_expect(earth_line.contains("you keep a stone") and earth_line.contains("[bend_guard]: throw it")
			and water_line.contains("right-click your [weapon_1]") and not water_line.contains("stone"),
			"the String card: earth \"%s\", water \"%s\"" % [earth_line, water_line])
	# the run under the % rules: a fake RingMoves on the player for its moved(kind)
	var fm := Standins.FakeMoves.put(p, mode.ring, {"pos": p.global_position, "element": el})
	fm.on_deck = true
	# (round 2's cards done already under this scheme: the run resumes at the first of the nine)
	for l: Dictionary in RingLessons.lessons_for(sch, el):
		if not String(l.id) in core:
			RingLessons.mark(sch, el, l, "done")
	ls.start()
	await _ticks(3)
	_expect(ls.current_id() == "pct", "the run resumes at the first new card (%s)" % ls.current_id())
	var fid := foe().get_instance_id()
	var pid := p.get_instance_id()
	var steps := {
		"pct": func() -> void: rules.pct_changed.emit(foe(), 45.0, 5.0),
		"out": func() -> void: rules.ko.emit(foe(), p, 118.0, "stone_form/spike", 2),
		"jumps": func() -> void: fm.moved.emit("double_jump"),
		"dodge": func() -> void: fm.moved.emit("dodge"),
		"back": func() -> void: fm.moved.emit("grab"),
		"edge": func() -> void: fm.moved.emit("climb"),
		"steer": _steer_emit.bind(rules, pid),
		"keep_off": func() -> void: rules.ko.emit(foe(), p, 95.0, "air_blast/slice", 2),
	}
	var done: Array = []
	for id: String in core:
		await _until(func() -> bool: return ls.current_id() == id, 3.0)
		if ls.current_id() != id:
			_expect(false, "the card %s up (%s)" % [id, ls.current_id()])
			break
		await _ticks(2)
		match id:
			"out":
				_expect([fid, 110.0] in rules.resets, "Out: the dummy at 110%% as it begins (%s)" % [rules.resets])
			"back":
				var out_m := float(mode.ring.nearest_lip(p.global_position).out_m)
				_expect(out_m > 3.0 and out_m < 5.0, "Back: you put 4 m out (%.1f)" % out_m)
				fm.s.p = NpcRingMind.standin_state({"pos": p.global_position}, fm.geo).p
			"string":
				# (skipped by Enter, kept as skipped; the run goes on past it)
				await _key(KEY_ENTER)
				await _ticks(3)
				_expect(ls.skipped.has("string") and RingLessons.state_of(ls.scheme, ls.element, str_l) == "skipped",
						"the String card skipped by Enter, kept as skipped")
				continue
		(steps[id] as Callable).call()
		var t := await _until(func() -> bool: return ls.completed.has(id), 2.0)
		if t < INF:
			done.append(id)
		_expect(t < INF, "%s: done by its own doing" % id)
	_expect(done.size() == 8, "eight cards done, one skipped (%s)" % [done])
	# the String card again, done by a 3-hit true string
	ls.start()
	await _ticks(3)
	var at_str := ls.list.find(str_l)
	ls.at = at_str
	ls._begin()
	await _ticks(2)
	rules.f_string[fid] = 3
	rules.launched.emit(foe(), Vector3(3.0, 2.0, 0.0), 0.5, p, "rock_jab/pebbles")
	var ts := await _until(func() -> bool: return ls.completed.has("string"), 2.0)
	_expect(ts < INF, "the String card: done by 3 true hits")
	p.remove_child(fm)
	fm.free()
	Standins.uninstall(rules)
	await _ticks(2)


## Steer's doing: a launch of the player's, steered 9° (more than half of the most, 15°).
func _steer_emit(rules: Object, pid: int) -> void:
	(rules.get(&"f_steer") as Dictionary)[pid] = 9.0
	(rules as RingRules).launched.emit(p, Vector3(12.0, 5.0, 0.0), 0.6, foe(), "water_whip/whip")


func _menu() -> void:
	var pr: Button = null
	for b in m._items.get_children():
		var tl := b.find_child("Text", true, false) as Label
		if tl and tl.text == "Practice":
			pr = b as Button
	_expect(pr != null, "the menu's Practice row")
	if pr == null:
		return
	pr.pressed.emit()
	await process_frame
	var row := m._panel.find_child("Lessons", true, false) as Button
	var sub := row.find_child("Sub", true, false) as Label if row != null else null
	var want := RingLessons.menu_line(MatchSetup.scheme(), "earth")
	_expect(row != null and sub != null and sub.text == want and want.contains("Earth"),
			"the Practice panel's Lessons row, its line \"%s\"" % (sub.text if sub != null else "?"))
	_expect(m._panel.find_child("Scheme", true, false) == null and m._panel.find_child("Controls", true, false) != null,
			"the Practice panel: no scheme row; Controls holds the other ways")
	seen_lines.append(want)
	MatchSetup.foes = ["water"]                    # (the panel's dummy: the lessons take the element's own)
	if row != null:
		row.pressed.emit()
	_expect(RingMode.lessons_asked and MatchSetup.incoming and MatchSetup.practice() and MatchSetup.foe() == "earth",
			"Lessons: a practice against the earth lesson dummy asked for (%s)" % MatchSetup.foe())


## One cast of the button `a` (RMB: &"aim"; LMB: &"fire"): held until the lock is full, let go; the cast ([move, variation];
## [] none).
func _cast(a: StringName = &"aim", limit := 3.0) -> Array:
	casts.clear()
	Input.action_press(a)
	var full := await _until(func() -> bool: return c.state == SwayCaster.State.FULL, limit)
	Input.action_release(a)
	var t := await _until(func() -> bool: return not casts.is_empty(), 1.0)
	await _secs(0.3)
	if full == INF or t == INF:
		await _until(func() -> bool: return c.state == SwayCaster.State.IDLE, 1.0)
		return []
	return casts[0]


## A cast of `id` on `src` stood in by the caster's own signal (this branch's caster cannot make it yet: round 2's CORE).
func _stand_in(id: String, src: String, why: String) -> void:
	stood_in.append(why)
	var was := c.lock_src
	c.lock_src = src
	c.cast.emit(id, null)
	c.lock_src = was
	await _ticks(2)


func _home_player() -> void:
	p.global_position = _home
	p.velocity = Vector3.ZERO
	await _ticks(3)


## Waits for lesson `id` to be done (it is in completed) and the run moved on from it.
func _done(id: String, what: String, limit := 3.0) -> bool:
	var t := await _until(func() -> bool: return ls.completed.has(id), limit)
	_expect(t < INF, what)
	await _until(func() -> bool: return ls.current_id() != id or ls.finished, 2.0)
	return t < INF


func _skip_now() -> void:
	if not ls.finished:
		ls.skip()
	await _ticks(2)


## The line's keys checked against the bindings now (each [action] of its spec as its cap).
func _line_keys(sch: String, id: String) -> void:
	await _ticks(2)
	var line := ls.lesson_line()
	seen_lines.append(line)
	var raw := String(RingLessons.by_of(ls.current(), sch).get("line", ""))
	var re := RegEx.create_from_string("\\[([a-z_0-9]+)\\]")
	var miss: Array = []
	for mt in re.search_all(raw + " " + ls.line_spec(ls.current())):
		var cp := cap(StringName(mt.get_string(1)))
		if not line.contains(cp):
			miss.append(cp)
	_expect(miss.is_empty() and line != "" and not line.contains("{"), "%s %s: the line has its keys as bound: \"%s\"%s" % [sch, id, line,
			"" if miss.is_empty() else " (missing %s)" % [miss]])


# ---------------------------------------------------------------- the keys scheme, earth: every lesson by doing it
func _keys_run() -> void:
	MatchSetup.set_scheme("keys")
	await _until(func() -> bool: return ls.scheme == "keys" and ls.at >= 0, 2.0)
	ls.completed.clear()
	var ids: Array = ls.list.map(func(l: Dictionary) -> String: return String(l.id))
	print("  info keys: %s" % [ids])
	_expect(ids == ["move", "jab", "strike", "push", "dash", "wall", "catch", "jump", "quick", "heal", "zones", "water"],
			"keys, earth: the run of round 2 (%s)" % [ids])
	# (the jab on left click: the element's, as round 2's data keeps it, whatever this branch's quick spell validation says)
	c._quick["earth"] = KitWords.jab("earth")
	for id: String in ids:
		if ls.finished or ls.current_id() != id:
			_expect(false, "keys: lesson %s is the one up (%s)" % [id, ls.current_id()])
			return
		await _lesson(id)
	_expect(ls.finished and ls.card.is_showing() and ls.card.kicker_text() == RingLessons.word("finished_kicker"),
			"keys: the run finished, its last card up")
	_expect(not mode.slow_throws and mode.throw_override == "" and mode.dummy == "stand", "and the dummy back to standing at its own pace")
	for l: Dictionary in ls.list:
		if RingLessons.state_of("keys", "earth", l) != "done":
			_expect(false, "keys: %s kept as done (%s)" % [l.id, RingLessons.state_of("keys", "earth", l)])
			return
	_expect(true, "keys: every lesson kept as done in the settings file")


## The line's keys checked, then the lesson done by doing it.
func _lesson(id: String) -> void:
	await _line_keys("keys", id)
	# (not done by idling: a moment with nothing pressed leaves it up)
	await _secs(0.4)
	_expect(not ls.completed.has(id) or id in ["move", "zones", "water"], "keys %s: not done by waiting" % id)
	await _home_player()
	match id:
		"move":
			Input.action_press(&"move_forward")
			var ok := await _done(id, "keys move: walking %.0f m does it" % RingLessons.num("walk_m", 3.0), 4.0)
			Input.action_release(&"move_forward")
			if not ok:
				await _skip_now()
		"jab":
			_expect(ls.lesson_line().contains("Pebbles") and ls.lesson_line().contains(cap(&"fire")), "keys jab: \"%s\"" % ls.lesson_line())
			var got := await _cast(&"fire")
			if not await _done(id, "keys jab: a click of LMB casts Pebbles (%s)" % [got]):
				await _skip_now()
		"strike", "push", "dash", "wall", "heal":
			await _role(id)
		"catch":
			await _catch()
		"jump":
			await _jump()
		"quick":
			await _quick()
		"zones":
			await _knock(false)
		"water":
			await _knock(true)
		_:
			_expect(false, "keys: an unknown lesson %s" % id)
			await _skip_now()


## Key 1-5's lesson: its key as the line says, RMB held and let go.
func _role(id: String) -> void:
	var keyed := {"strike": 1, "push": 2, "dash": 3, "wall": 4, "heal": 5}
	var want := ls.role_move(id)
	var line := ls.lesson_line()
	var k := int(keyed[id])
	_expect(line.contains(cap(StringName("weapon_%d" % k))) and line.contains(KitWords.move_name(String(want.id), String(want.mode))),
			"keys %s: \"%s\" names key %d and %s" % [id, line, k, KitWords.move_name(String(want.id), String(want.mode))])
	if id == "strike" and ls.element == "fire":
		_expect(line.contains("Fireball"), "fire's strike says it grows into the Fireball")
	if c.readied_spell != String(want.id):
		await _action(StringName("weapon_%d" % k))   # (a tap: the key's first move; already readied, left as it is)
	var ok := c.readied_spell == String(want.id)
	if id == "dash":
		Input.action_press(&"move_left")
	var got := await _cast()
	Input.action_release(&"move_left")
	if got.is_empty():
		await _stand_in(String(want.id), SwayCaster.SRC_AIM, "%s: %s took no lock here" % [id, want.id])
	if not await _done(id, "keys %s: key %d (%s readied: %s), RMB held and let go (%s)" % [id, k, want.id, ok, got]):
		await _skip_now()
	await _home_player()


## Earth's guard drill: the dummy's stones slowed; E as one comes (caught), E again (thrown back).
func _catch() -> void:
	_expect(mode.dummy == "throw" and mode.slow_throws and is_equal_approx(mode.throw_every_s(), RingLessons.num("slow_every_s", 5.0)),
			"keys catch: the dummy throws, slowly (a throw each %.1f s)" % mode.throw_every_s())
	_expect(ls.lesson_line().contains(cap(KitWords.GUARD_ACTION)) and ls.lesson_line().contains("Catch"), "the card: \"%s\"" % ls.lesson_line())
	# (its next shot leaves slowed: a stone of the dummy's in flight at slow_speed of its speed)
	var slowed := await _until(func() -> bool:
		for n in get_nodes_in_group(GustLift.GROUP):
			if (n as GustLift).has_meta(&"ring_slowed"):
				return true
		for n in get_nodes_in_group(BendBolt.GROUP):
			if (n as BendBolt).caster == foe() and (n as BendBolt).has_meta(&"ring_slowed"):
				return true
		return false, 7.0)
	_expect(slowed < INF, "a shot of the dummy's slowed as it leaves (%.1f s)" % slowed)
	var g := {}
	for i in 3:
		g = await GuardTiming.on_beat(self, c, foe(), 0.12, 12.0)
		if bool(ls.get(&"_caught")):
			break
	_expect(bool(ls.get(&"_caught")) and BendZone.held_stone(p) != null and not ls.completed.has("catch"),
			"E as it came: caught (%s) and held, not yet done: the throw back is next" % g.get("result", ""))
	casts.clear()
	await _until(func() -> bool: return c.state == SwayCaster.State.IDLE, 2.0)
	c.guard_override = true                      # (E again: a click)
	await _ticks(2)
	c.guard_override = null
	if not await _done("catch", "keys catch: E as it came, E again: thrown back"):
		await _skip_now()


func _jump() -> void:
	_expect(mode.slow_throws and ls.lesson_line().contains(cap(&"jump")), "keys jump: \"%s\"; the dummy slow" % ls.lesson_line())
	await _until(func() -> bool: return p.is_on_floor(), 2.0)
	await _action(&"jump")
	if not await _done("jump", "keys jump: a jump off the deck does it"):
		await _skip_now()
	await _until(func() -> bool: return p.is_on_floor(), 2.0)


func _quick() -> void:
	# (a rebound key shows in the line)
	var keep := InputMap.action_get_events(SwayCaster.QUICK_BIND)
	InputMap.action_erase_events(SwayCaster.QUICK_BIND)
	var f := InputEventKey.new()
	f.physical_keycode = KEY_F
	InputMap.action_add_event(SwayCaster.QUICK_BIND, f)
	await _secs(0.4)
	_expect(ls.lesson_line().contains("[F]"), "keys quick: the bind key rebound to F, the line says [F] (%s)" % ls.lesson_line())
	InputMap.action_erase_events(SwayCaster.QUICK_BIND)
	for e in keep:
		InputMap.action_add_event(SwayCaster.QUICK_BIND, e)
	await _secs(0.4)
	# (LMB alone, before the bind key, is not it)
	var first := await _cast(&"fire")
	_expect(not ls.completed.has("quick") and not first.is_empty(), "keys quick: a left click cast before Q is not it (%s)" % [first])
	await _action(&"weapon_1")
	await _action(SwayCaster.QUICK_BIND)
	var got := await _cast(&"fire")
	if not await _done("quick", "keys quick: Q, then LMB held and let go (%s)" % [got]):
		await _skip_now()
	c._quick["earth"] = KitWords.jab("earth")


## The dummy knocked back a zone (or into the water: `out`).
func _knock(out: bool) -> void:
	var id := "water" if out else "zones"
	var f := foe()
	if f == null:
		_expect(false, "%s: the dummy" % id)
		return
	if not out:
		await _key(KEY_R)                        # (R: both back at their ends, the dummy mid its first zone)
		await _secs(0.4)
		f = foe()
	var e := mode.end_of(f)
	var back := mode.ring.axis() * RingArena.side_sign(e)
	back.y = 0.0
	back = back.normalized()
	var done := false
	for i in 6:
		f = foe()
		if f == null:
			break
		if out:
			f.global_position = mode.ring.to_global(Vector3(RingArena.side_sign(e) * 15.6, mode.ring.top() + 0.05, 0.0))
			await _ticks(2)
		BendStatus.knock(f, back * (12.0 if out else 9.0) + Vector3.UP * 2.0, p)
		var t := await _until(func() -> bool: return ls.completed.has(id), 1.5)
		if t < INF:
			done = true
			break
	_expect(done, "%s: the dummy knocked %s" % [id, "into the water" if out else "back a zone"])
	if not done:
		await _skip_now()
	await _until(func() -> bool: return ls.current_id() != id, 2.0)
	if out:
		await _until(func() -> bool: return foe() != null and not mode.rules.is_out(foe()), 4.0)


# ---------------------------------------------------------------- the other elements
func _elements() -> void:
	MatchSetup.set_scheme("keys")
	for el: String in ["water", "fire", "air"]:
		MatchSetup.element = el
		await _until(func() -> bool: return p.arena_element == el and p.hotbar.spell != "", 4.0)
		await _secs(0.2)
		_expect(MatchSetup.foe() == el, "%s: the element changed, the next restart's dummy its own (%s)" % [el, MatchSetup.foe()])
		mode.restart()
		await _until(func() -> bool: return mode.phase == "FIGHT" and foe() != null, 6.0)
		await _until(func() -> bool: return ls.element == el and not ls.finished, 2.0)
		ls.completed.clear()
		c._quick[el] = KitWords.jab(el)
		_home = p.global_position.lerp(foe().global_position, 0.3)
		_expect(mode.foe_element == el and ls.current_id() == "strike",
				"%s: its own dummy, the run resumed at its own strike (%s)" % [el, ls.current_id()])
		await _line_keys("keys", "strike")
		_expect(ls.lesson_line().contains(String(STRIKE_NAME[el])), "%s strike: the line names %s (%s)" % [el, STRIKE_NAME[el], ls.lesson_line()])
		await _role("strike")
		for i in 3:
			if ls.current_id() in ["push", "dash", "wall"]:
				seen_lines.append(ls.lesson_line())
				await _key(KEY_ENTER)
				await _ticks(2)
		_expect(ls.current_id() == "guard", "%s: past the lessons done before, to its guard drill (%s)" % [el, ls.current_id()])
		await _line_keys("keys", "guard")
		_expect(ls.lesson_line().contains(String(GUARD_NAME[el])) and ls.lesson_line().contains(cap(KitWords.GUARD_ACTION))
				and mode.slow_throws and mode.dummy == "throw",
				"%s guard: \"%s\" (the dummy throws, slowly)" % [el, ls.lesson_line()])
		_expect(ls.throw_of(RingLessons.lessons_for("keys", el).filter(func(l: Dictionary) -> bool: return l.id == "jump")[0])
				== ("fire_kick/kick" if el == "fire" else ""), "%s: the jump card's throw (fire: its Kick)" % el)
		var res: Array = []
		for i in 4:
			var g := await GuardTiming.on_beat(self, c, foe(), 0.12, 12.0)
			res.append(g.get("result", ""))
			if ls.completed.has("guard"):
				break
		if not await _done("guard", "%s guard: E on the beat of the dummy's shot, done (%s)" % [el, res]):
			await _skip_now()
		await _until(func() -> bool: return ls.finished, 2.0)
		_expect(ls.finished, "%s: the run finished after its own lessons" % el)
	MatchSetup.element = "earth"
	await _until(func() -> bool: return p.arena_element == "earth" and p.hotbar.spell != "", 4.0)
	mode.restart()
	await _until(func() -> bool: return mode.phase == "FIGHT" and foe() != null, 6.0)
	_home = p.global_position.lerp(foe().global_position, 0.3)


# ---------------------------------------------------------------- the other schemes: their runs and lines
func _schemes() -> void:
	var list: Array = ["direction", "radial"]
	if "first_moves" in MatchSetup.SCHEMES:
		list.push_front("first_moves")
	for sch: String in list:
		MatchSetup.set_scheme(sch)
		await _until(func() -> bool: return ls.scheme == sch and ls.at >= 0, 2.0)
		ls.completed.clear()
		var ids: Array = ls.list.map(func(l: Dictionary) -> String: return String(l.id))
		_expect(ls.at == 0 and ids.size() == 12, "%s: a fresh run of %d lessons (%s)" % [sch, ids.size(), ids])
		for i in ids.size():
			if ls.finished:
				break
			await _line_keys(sch, ls.current_id())
			await _key(KEY_ENTER)
			await _ticks(2)
		_expect(ls.finished, "%s: every card read, skipped through" % sch)
	MatchSetup.set_scheme("keys")
	await _ticks(3)


# ---------------------------------------------------------------- skip and resume
func _resume() -> void:
	RingLessons.forget()
	MatchSetup.set_scheme("direction")
	await _until(func() -> bool: return ls.scheme == "direction", 2.0)
	ls.start()
	ls.completed.clear()
	await _ticks(2)
	_expect(ls.at == 0 and ls.current_id() == "move", "forgotten: from the first again (%s)" % ls.current_id())
	await _key(KEY_ENTER)
	await _ticks(2)
	_expect(ls.current_id() == "jab" and ls.skipped.has("move") and RingLessons.state_of("direction", "earth", ls.list[0]) == "skipped",
			"Enter skips Move (kept as skipped; now %s)" % ls.current_id())
	await _home_player()
	c._quick["earth"] = KitWords.jab("earth")
	await _cast(&"fire")
	await _done("jab", "then Jab done")
	# a new run (the ring left and come back): the first neither done nor skipped
	ls.start()
	await _ticks(2)
	var line := RingLessons.menu_line("direction", "earth")
	seen_lines.append(line)
	_expect(ls.at == 2 and ls.current_id() == "strike" and line.contains("3 of 12"),
			"a new run resumes at lesson 3, Strike (%s; the menu: \"%s\")" % [ls.current_id(), line])
	await _home_player()
	c.dir_override = "forward"
	var got := await _cast()
	c.dir_override = null
	await _done("strike", "Strike done: W held as RMB is pressed (%s)" % [got])
	_expect(ls.current_id() == "push", "and on to Push (%s)" % ls.current_id())
	# every one done or skipped: the next run from the start again
	for i in 14:
		if ls.finished:
			break
		await _key(KEY_ENTER)
		await _ticks(2)
	_expect(ls.finished and RingLessons.resume_index("direction", "earth") == ls.list.size()
			and RingLessons.menu_line("direction", "earth").contains("from the start"), "the rest skipped: finished; the menu says from the start")
	ls.start()
	await _ticks(2)
	_expect(ls.at == 0 and ls._replay, "a run with all done or skipped: from the first again")
	for i in 3:
		await _key(KEY_ENTER)
		await _ticks(2)
	_expect(ls.current_id() == "push" and RingLessons.state_of("direction", "earth", ls.list[1]) == "done",
			"a replay's skip keeps a done lesson done (Jab: %s)" % RingLessons.state_of("direction", "earth", ls.list[1]))


# ---------------------------------------------------------------- the hints
func _hints() -> void:
	MatchSetup.set_scheme("keys")
	await _ticks(2)
	_expect(FirstHints.on(), "the key hints on with nothing kept")
	_expect(FirstHints.find(self) == null, "none over a practice")
	MatchSetup.kind = "match"
	MatchSetup.quick = true
	_expect(not FirstHints.wanted(mode), "a script run: not wanted unless forced")
	FirstHints.force = true
	_expect(FirstHints.wanted(mode), "a Quick match with them on: wanted")
	MatchSetup.quick = false
	_expect(not FirstHints.wanted(mode), "a match from the panel: not")
	MatchSetup.quick = true
	var h := FirstHints.install(mode)
	await _ticks(3)
	var want: Array = _hint_rows("keys")
	_expect(h != null and h.rows.size() == want.size() and h.rows_left() == want.size() and h.get_parent() == mode,
			"a Quick match: the hints up, %d rows for the keys scheme" % (h.rows.size() if h != null else -1))
	if h == null:
		return
	MatchSetup.set_controls("basic")
	await _ticks(3)
	var taught := []
	for r: Dictionary in h.rows:
		taught.append_array(r.uses)
	_expect(h.rows.size() == _hint_rows("basic").size() and not taught.has(&"weapon_4") and not taught.has(&"weapon_5")
			and taught.has(&"move_forward") and taught.has(&"jump"),
			"Basic hints teach movement and recovery without locked Wall/Heal keys")
	MatchSetup.set_controls("full")
	await _ticks(3)
	_expect(h.rows.size() == want.size() and h.scheme == "keys", "switching back to Full refreshes hints even with the same keys scheme")
	var texts := []
	for r: Dictionary in h.rows:
		var t := ""
		for n in (r.box as Control).find_children("*", "Control", true, false):
			if n is HowToKey:
				t += "[%s] " % (n as HowToKey).label
			elif n is Label:
				t += (n as Label).text + " "
		texts.append(t.strip_edges())
	seen_lines.append_array(texts)
	_expect(texts[0].contains(cap(&"fire")) and texts[1].contains(cap(&"aim")) and texts[2].contains(cap(&"weapon_1"))
			and texts[3].contains(cap(KitWords.GUARD_ACTION)) and texts[4].contains(cap(&"jump")), "the rows have the keys as bound (%s)" % [texts])
	# each fades once its key is used
	var n0 := h.rows_left()
	await _action(KitWords.GUARD_ACTION)
	await _secs(0.8)
	_expect(h.rows_left() == n0 - 1 and not ((h.rows[3].box as Control).visible), "the guard used: its row faded (%d left)" % h.rows_left())
	MatchSetup.set_scheme("direction")
	await _ticks(3)
	_expect(h.rows.size() == _hint_rows("direction").size() and h.rows_left() == h.rows.size(),
			"the scheme changed: the direction scheme's rows")
	MatchSetup.set_scheme("keys")
	await _ticks(3)
	for a: StringName in [&"fire", &"aim", &"weapon_1", KitWords.GUARD_ACTION, &"jump", &"weapon_5"]:
		await _action(a)
	await _secs(1.6)
	_expect(not FirstHints.on() and FirstHints.find(self) == null, "all used: turned off and gone")
	# the Esc menu's row
	var menu := mode.menu as RingMenu
	menu.open()
	await process_frame
	var row := menu.find_child("KeyHints", true, false) as Button
	_expect(row != null and (row.find_child("Text", true, false) as Label).text == FirstHints.row_text()
			and FirstHints.row_text().ends_with("off"), "the Esc menu's row: %s" % FirstHints.row_text())
	menu.toggle_hints()
	await process_frame
	_expect(FirstHints.on() and FirstHints.find(self) != null and (row.find_child("Text", true, false) as Label).text.ends_with("on"),
			"pressed: on, shown at once")
	menu.toggle_hints()
	await process_frame
	_expect(not FirstHints.on(), "pressed again: off")
	# its Controls panel holds the other ways to pick moves (round 2: not a row of its own)
	_expect(menu._items.find_child("Scheme", false, false) == null, "the Esc menu: no scheme row in its list")
	menu._controls()
	await process_frame
	_expect(menu._scheme.get_parent() == menu._panel and (menu._scheme.find_child("Text", true, false) as Label).text
			== KitWords.other_ways_row(), "its Controls panel: \"%s\"" % KitWords.other_ways_row())
	var before := MatchSetup.scheme()
	menu.cycle_scheme()
	await process_frame
	_expect(MatchSetup.scheme() != before and menu._scheme.get_parent() == menu._panel, "pressed: the next way (%s)" % MatchSetup.scheme())
	MatchSetup.set_scheme("keys")
	for l in menu._panel.find_children("*", "Label", true, false):
		seen_lines.append((l as Label).text)
	menu.close()
	await _secs(1.0)
	_expect(FirstHints.find(self) == null, "and gone")
	MatchSetup.kind = "practice"
	MatchSetup.quick = false


func _words() -> void:
	var lines: Array = seen_lines.duplicate()
	lines.append(RingLessons.word("finished"))
	lines.append(RingLessons.word("panel_line"))
	lines.append(FirstHints.row_line())
	var bad: Array = []
	for t: String in lines:
		for mt in _re.search_all(t):
			bad.append(mt.get_string())
	_expect(bad.is_empty() and lines.size() > 40, "no show word in %d lines shown (%s)" % [lines.size(), bad])
