extends SceneTree
## Tidebreak's lessons in Practice (RingLessons, LessonCard, data/ring/lessons.json) and a first Quick match's key hints
## (FirstHints, the ring's Esc row), the test's own settings file (GameSettings.path):
##   the entry   the main menu's Practice panel: its Lessons row (its line: the lessons for your element and scheme) asks
##               for them (RingMode.lessons_asked, a practice against the element's lesson dummy) and plays into the ring through
##               the loading screen; RingMode installs the lessons, the card shows lesson 1
##   each scheme keys, direction, radial, simple in turn, earth against an earth dummy: every lesson of the scheme's run
##               completed by its action as the player does it (the keys as actions, RMB and LMB held and let go, the move
##               wheel opened and pointed, the direction held at the release, a guard cast as a stone comes, the dummy
##               knocked back and into the water), and only by it; the card's line holds each of its keys as bound now
##               ([W] [A] [S] [D], [RMB], [2], [Tab], [Wheel], [Q] and [LMB] ...); a rebound key shows in the line
##   elements    water, fire and air under the keys scheme (a restart brings each one's lesson dummy: fire): the dodge and
##               the answer to its throw, by element (the bubble against fire, the parry, the shield sending it back)
##   skip/resume Enter skips (kept as skipped), a lesson done is kept as done; a new run begins at the first neither and goes
##               past the rest; the menu's line says where; all done: from the start again, and a skip then keeps done
##   the hints   installed over the match (the Esc row turns them on and off; on, shown at once), the scheme's rows with its
##               keys; each fades once its key is used, all gone turns them off (kept); wanted only for a Quick match with
##               them on
##   words       no show word in any line shown, the menu's lines, the hints; nothing put on the dummy (its children as before)
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_lessons.gd
## The last line "LESSONS TEST PASSED" or "LESSONS TEST FAILED"; exit 0 only on a pass; a watchdog quits with 2.

const NAME := "LESSONS TEST"
const LIMIT_S := 400.0
const OWN_CFG := "user://lessons_test.cfg"
const WORDS := ["avatar", "benders?", "bending", "pro-?bend\\w*", "korra", "aang", "airbend\\w*", "firebend\\w*",
		"earthbend\\w*", "waterbend\\w*", "air scooters?", "fire nation", "water tribes?", "earth kingdom", "air nomads?"]
## The kind of bolt each element's lesson dummy throws (lessons.json dummy: earth stones, the rest fire).
const BOLT := {"earth": "stone", "water": "fire", "fire": "fire", "air": "fire"}

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
var _home := Vector3.INF
var _re := RegEx.create_from_string("(?i)\\b(?:%s)\\b" % "|".join(PackedStringArray(WORDS)))


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
	RingMode.lessons_asked = false
	FirstHints.force = false
	MatchSetup.element = "earth"
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
	for a: StringName in [&"fire", &"aim", &"move_forward", RadialWheel.ACTION]:
		if InputMap.has_action(a):
			Input.action_release(a)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	MatchSetup.reload_scheme()
	FirstHints.force = false
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
	for sch: String in ["keys", "direction", "radial", "simple"]:
		await _scheme_run(sch)
	await _elements()
	await _resume()
	await _hints()
	_words()
	var bad: Array = []
	for n in ls.find_children("*", "", true, false):
		if not (n is CanvasLayer or n is Control):
			bad.append(n.name)
	_expect(bad.is_empty() and ls.card.get_parent() == ls, "the lessons draw on a screen layer only, nothing in the ring (%s)" % [bad])
	_end()


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
	seen_lines.append(want)
	MatchSetup.foes = ["water"]                    # (the panel's dummy: the lessons take the element's own)
	if row != null:
		row.pressed.emit()
	_expect(RingMode.lessons_asked and MatchSetup.incoming and MatchSetup.practice() and MatchSetup.foe() == "earth",
			"Lessons: a practice against the earth lesson dummy asked for (%s)" % MatchSetup.foe())


## One RMB cast: held until the lock is full, let go; the cast ([move, variation]; [] none).
func _rmb_cast(limit := 3.0) -> Array:
	casts.clear()
	Input.action_press(&"aim")
	var full := await _until(func() -> bool: return c.state == SwayCaster.State.FULL, limit)
	Input.action_release(&"aim")
	var t := await _until(func() -> bool: return not casts.is_empty(), 1.0)
	await _secs(0.3)
	if full == INF or t == INF:
		await _until(func() -> bool: return c.state == SwayCaster.State.IDLE, 1.0)
		return []
	return casts[0]


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


## The readied move turned to `id` (at form `md`, "" any) the scheme's way: the keys its line says ({press}: once or
## twice), the wheel for the form; the radial scheme's move wheel; true when it is readied.
func _ready_move(sch: String, id: String, md := "") -> bool:
	if sch == "radial":
		await _wheel_pick(id, md)
		return c.readied_spell == id
	var ps := ls.press_spec(id)
	var n := 0 if ps == RingLessons.word("readied") else (2 if ps.contains(RingLessons.word("twice")) else 1)
	var k := ps.substr(ps.find("[") + 1, ps.find("]") - ps.find("[") - 1) if ps.contains("[") else ""
	for i in n:
		await _action(StringName(k))
	for i in 3:
		if md == "" or c.base_mode_of(id) == md:
			break
		await _action(&"weapon_next")
	return c.readied_spell == id and (md == "" or c.base_mode_of(id) == md)


## The move wheel held, the mouse toward `id`, its form stepped to `md`, let go.
func _wheel_pick(id: String, md := "") -> void:
	var w := c.radial
	Input.action_press(RadialWheel.ACTION)
	await _until(func() -> bool: return w.is_open, 0.5)
	var i := -1
	for j in w.items.size():
		if String(w.items[j].id) == id:
			i = j
	var mm := InputEventMouseMotion.new()
	mm.relative = w.dir_of(maxi(i, 0)) * 120.0
	Input.parse_input_event(mm)
	await _ticks(3)
	for k in 3:
		if md == "" or c.base_mode_of(id) == md:
			break
		w.step_form(1)
	Input.action_release(RadialWheel.ACTION)
	await _ticks(4)


## Every lesson of scheme `sch` done by its action.
func _scheme_run(sch: String) -> void:
	MatchSetup.set_scheme(sch)
	await _until(func() -> bool: return ls.scheme == sch and ls.at >= 0, 2.0)
	ls.completed.clear()
	var ids: Array = ls.list.map(func(l: Dictionary) -> String: return String(l.id))
	print("  info %s: %s" % [sch, ids])
	_expect(ls.scheme == sch and ls.at == 0 and ids.size() == (9 if sch == "simple" else 11),
			"%s: a fresh run of %d lessons from the first (%s)" % [sch, ids.size(), ls.current_id()])
	for id: String in ids:
		if ls.finished or ls.current_id() != id:
			_expect(false, "%s: lesson %s is the one up (%s)" % [sch, id, ls.current_id()])
			return
		await _lesson(sch, id)
	_expect(ls.finished and ls.card.is_showing() and ls.card.kicker_text() == RingLessons.word("finished_kicker"),
			"%s: the run finished, its last card up" % sch)
	for l: Dictionary in ls.list:
		if RingLessons.state_of(sch, "earth", l) != "done":
			_expect(false, "%s: %s kept as done (%s)" % [sch, l.id, RingLessons.state_of(sch, "earth", l)])
			return
	_expect(true, "%s: every lesson kept as done in the settings file" % sch)


## The line's keys checked, then the lesson done by doing it.
func _lesson(sch: String, id: String) -> void:
	await _ticks(2)
	var line := ls.lesson_line()
	seen_lines.append(line)
	var raw := String(RingLessons.by_of(ls.current(), sch).get("line", ""))
	var re := RegEx.create_from_string("\\[([a-z_0-9]+)\\]")
	var miss: Array = []
	for mt in re.search_all(raw):
		var cp := cap(StringName(mt.get_string(1)))
		if not line.contains(cp):
			miss.append(cp)
	_expect(miss.is_empty() and line != "", "%s %s: the line has its keys as bound: \"%s\"%s" % [sch, id, line,
			"" if miss.is_empty() else " (missing %s)" % [miss]])
	# (not done by idling: a moment with nothing pressed leaves it up)
	await _secs(0.4)
	# (the dummy may still be rocking from the last lesson's shove: the knock lessons are left out of it)
	_expect(not ls.completed.has(id) or id in ["move", "zones", "water"], "%s %s: not done by waiting" % [sch, id])
	await _home_player()
	match id:
		"move":
			Input.action_press(&"move_forward")
			var ok := await _done(id, "%s move: walking %.0f m does it" % [sch, RingLessons.num("walk_m", 3.0)], 4.0)
			Input.action_release(&"move_forward")
			if not ok:
				await _skip_now()
		"cast":
			var got := await _rmb_cast()
			if not await _done(id, "%s cast: RMB held and let go (%s)" % [sch, got]):
				await _skip_now()
		"switch":
			await _switch(sch)
		"form":
			if sch == "simple":
				c.dist_override = 3.0
				var got := await _rmb_cast()
				c.dist_override = null
				if not await _done(id, "simple form: a near cast takes the near form (%s)" % [got]):
					await _skip_now()
			else:
				var was := c.base_mode_of(c.readied_spell)
				await _action(&"weapon_next")
				if not await _done(id, "%s form: the wheel steps %s's form (%s -> %s)" % [sch, c.readied_spell, was,
						c.base_mode_of(c.readied_spell)]):
					await _skip_now()
		"dodge", "mend", "send_back":
			await _role_cast(sch, id)
		"quick":
			await _quick(sch)
		"guard":
			await _guard(sch, "earth")
		"zones":
			await _knock(false)
		"water":
			await _knock(true)
		_:
			_expect(false, "%s: an unknown lesson %s" % [sch, id])
			await _skip_now()


func _skip_now() -> void:
	if not ls.finished:
		ls.skip()
	await _ticks(2)


func _switch(sch: String) -> void:
	match sch:
		"keys":
			var was := c.readied_spell
			await _action(&"weapon_2")
			var mid := c.readied_spell
			_expect(not ls.completed.has("switch"), "keys switch: key 2 once (%s -> %s) is not yet it" % [was, mid])
			await _action(&"weapon_2")
			if not await _done("switch", "keys switch: key 2 again, %s -> %s, its partner" % [mid, c.readied_spell]):
				await _skip_now()
		"direction":
			c.dir_override = "forward"
			var got := await _rmb_cast()
			c.dir_override = null
			if not await _done("switch", "direction switch: W held at the release casts the attack (%s)" % [got]):
				await _skip_now()
		"radial":
			var other := "earth_wall" if c.readied_spell != "earth_wall" else "pillar"
			await _wheel_pick(other)
			if not await _done("switch", "radial switch: the wheel opened, %s readied from it (%s)" % [other, c.readied_spell]):
				await _skip_now()
		"simple":
			var was := c.readied_spell
			await _action(&"weapon_next")
			if not await _done("switch", "simple switch: the wheel, %s -> %s" % [was, c.readied_spell]):
				await _skip_now()


## The lesson's move readied the scheme's way and cast: dodge, Patch, Shove.
func _role_cast(sch: String, id: String) -> void:
	var rm := ls.role_move(String(ls.current().get("role", "")))
	var want := String(rm.get("id", ""))
	if sch == "direction" and id == "dodge":
		c.dir_override = "side"
	else:
		var ok := await _ready_move(sch, want)
		_expect(ok, "%s %s: %s readied as the line says (%s)" % [sch, id, want, c.readied_spell])
		if sch == "direction":
			c.dir_override = ""
	var got := await _rmb_cast()
	c.dir_override = null
	if not await _done(id, "%s %s: %s cast (%s)" % [sch, id, want, got]):
		await _skip_now()
	await _home_player()


func _quick(sch: String) -> void:
	# (a rebound key shows in the line)
	var keep := InputMap.action_get_events(SwayCaster.QUICK_BIND)
	InputMap.action_erase_events(SwayCaster.QUICK_BIND)
	var f := InputEventKey.new()
	f.physical_keycode = KEY_F
	InputMap.action_add_event(SwayCaster.QUICK_BIND, f)
	await _secs(0.4)
	_expect(ls.lesson_line().contains("[F]"), "%s quick: the bind key rebound to F, the line says [F] (%s)" % [sch, ls.lesson_line()])
	InputMap.action_erase_events(SwayCaster.QUICK_BIND)
	for e in keep:
		InputMap.action_add_event(SwayCaster.QUICK_BIND, e)
	await _secs(0.4)
	# (LMB alone, before the bind key, is not it)
	casts.clear()
	Input.action_press(&"fire")
	await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 3.0)
	Input.action_release(&"fire")
	await _until(func() -> bool: return not casts.is_empty(), 1.0)
	await _secs(0.3)
	_expect(not ls.completed.has("quick") and not casts.is_empty(), "%s quick: a left click cast before Q is not it" % sch)
	await _action(SwayCaster.QUICK_BIND)
	casts.clear()
	Input.action_press(&"fire")
	var full := await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 3.0)
	Input.action_release(&"fire")
	await _until(func() -> bool: return not casts.is_empty(), 1.0)
	if not await _done("quick", "%s quick: Q, then LMB held and let go (%s, full %s)" % [sch, casts, full < INF]):
		await _skip_now()


## The guard readied and cast, a bolt of the dummy's kind sent at the player from close by as it stands: taken.
func _guard(sch: String, el: String) -> void:
	var rm := ls.role_move("guard")
	var want := String(rm.get("id", ""))
	_expect(mode.dummy == "throw", "%s %s guard: the dummy throws through it (%s)" % [sch, el, mode.dummy])
	var done := false
	for attempt in 3:
		await _home_player()
		if sch == "direction":
			c.dir_override = "back"
		else:
			var ok := await _ready_move(sch, want, String(rm.get("mode", "")) if sch != "simple" else "")
			_expect(ok or attempt > 0, "%s %s guard: %s readied as the line says (%s, %s)" % [sch, el, want, c.readied_spell,
					c.base_mode_of(want)])
		if sch == "simple":
			c.dist_override = 3.0                 # (close in: the near form, the cover round you)
			# (the shell's 1.6 s lock begun just after one of its stones has come, as a player keeps the rhythm: begun at
			# random, a stone could land mid-lock each attempt and break it; R1 gate, once BALANCE's quicker Stone Form
			# moved the dummy's throws: its lock 1.4 s, a throw each 3 s)
			var fb: Variant = foe().brain.bending if foe() != null and foe().brain != null else null
			if fb != null:
				await _until(func() -> bool: return String(fb.casting) != "", 4.0)
				await _until(func() -> bool: return String(fb.casting) == "", 3.0)
				await _secs(0.5)
			await _home_player()                  # (back where he stands if the stone moved him)
			p.pitch = -0.35                       # (the shell's lock on the deck before him, not past the pillars an
			                                      # earlier near cast left by the dummy: a level aim met them, "off")
		var got := await _rmb_cast()
		p.pitch = -0.15
		c.dir_override = null
		c.dist_override = null
		if sch != "simple" and foe() != null:
			var to := p.global_position + Vector3.UP * 1.2
			var away := (foe().global_position - p.global_position)
			away.y = 0.0
			var from := to + away.normalized() * 5.0
			BendBolt.launch(foe(), from, to - from, {"kind": BOLT[el], "mps": 18.0, "damage": 1.0, "knock_mps": 0.0, "range_m": 20.0})
		var t := await _until(func() -> bool: return ls.completed.has("guard"), 1.5)
		print("  info %s %s guard attempt %d: cast %s, done %s" % [sch, el, attempt, got, t < INF])
		if t < INF:
			done = true
			break
	_expect(done, "%s %s guard: %s cast as its throw comes, taken" % [sch, el, want])
	if not done:
		await _skip_now()
	await _until(func() -> bool: return ls.current_id() != "guard", 2.0)


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
		_expect(MatchSetup.foe() == RingLessons.dummy_for(el), "%s: the element changed, the next restart's dummy %s"
				% [el, MatchSetup.foe()])
		mode.restart()
		await _until(func() -> bool: return mode.phase == "FIGHT" and foe() != null, 6.0)
		await _until(func() -> bool: return ls.element == el and not ls.finished, 2.0)
		ls.completed.clear()
		_home = p.global_position.lerp(foe().global_position, 0.3)
		_expect(mode.foe_element == "fire" and ls.current_id() == "dodge",
				"%s: a fire dummy, the run resumed at its own dodge (%s)" % [el, ls.current_id()])
		var line := ls.lesson_line()
		seen_lines.append(line)
		var want := String(ls.role_move("dodge").id)
		_expect(line.contains(SwayMoves.move(want).get("label", "?")), "%s dodge: the line names %s (%s)" % [el, want, line])
		await _role_cast("keys", "dodge")
		_expect(ls.current_id() == "guard", "%s: past the lessons done before, to its guard (%s)" % [el, ls.current_id()])
		seen_lines.append(ls.lesson_line())
		_expect(ls.lesson_line().contains(RingLessons.data()["elements"][el]["thing"]), "%s guard: \"%s\"" % [el, ls.lesson_line()])
		await _guard("keys", el)
		await _until(func() -> bool: return ls.finished, 2.0)
		_expect(ls.finished, "%s: the run finished after its two" % el)
	MatchSetup.element = "earth"
	await _until(func() -> bool: return p.arena_element == "earth" and p.hotbar.spell != "", 4.0)
	mode.restart()
	await _until(func() -> bool: return mode.phase == "FIGHT" and foe() != null, 6.0)
	_home = p.global_position.lerp(foe().global_position, 0.3)


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
	_expect(ls.current_id() == "cast" and ls.skipped.has("move") and RingLessons.state_of("direction", "earth", ls.list[0]) == "skipped",
			"Enter skips Move (kept as skipped; now %s)" % ls.current_id())
	await _key(KEY_ENTER)
	await _ticks(2)
	await _home_player()
	c.dir_override = "forward"
	await _rmb_cast()
	c.dir_override = null
	await _done("switch", "then Switch done")
	# a new run (the ring left and come back): the first neither done nor skipped
	ls.start()
	await _ticks(2)
	var line := RingLessons.menu_line("direction", "earth")
	seen_lines.append(line)
	_expect(ls.at == 3 and ls.current_id() == "form" and line.contains("4 of 11"),
			"a new run resumes at lesson 4, Its three forms (%s; the menu: \"%s\")" % [ls.current_id(), line])
	await _action(&"weapon_next")
	await _done("form", "Form done")
	_expect(ls.current_id() == "dodge", "and on to Dodge (%s)" % ls.current_id())
	# every one done or skipped: the next run from the start again
	for i in 12:
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
	_expect(ls.current_id() == "form" and RingLessons.state_of("direction", "earth", ls.list[2]) == "done",
			"a replay's skip keeps a done lesson done (Switch: %s)" % RingLessons.state_of("direction", "earth", ls.list[2]))


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
	var want: Array = RingLessons.data()["hints"]["keys"]
	_expect(h != null and h.rows.size() == want.size() and h.rows_left() == want.size() and h.get_parent() == mode,
			"a Quick match: the hints up, %d rows for the keys scheme" % (h.rows.size() if h != null else -1))
	if h == null:
		return
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
	_expect(texts[0].contains(cap(&"aim")) and texts[1].contains(cap(&"weapon_1")) and texts[2].contains("[Wheel]")
			and texts[3].contains(cap(SwayCaster.QUICK_BIND)), "the rows have the keys as bound (%s)" % [texts])
	# each fades once its key is used
	var n0 := h.rows_left()
	await _action(&"weapon_next")
	await _secs(0.8)
	_expect(h.rows_left() == n0 - 1 and not ((h.rows[2].box as Control).visible), "the wheel used: its row faded (%d left)" % h.rows_left())
	MatchSetup.set_scheme("direction")
	await _ticks(3)
	_expect(h.rows.size() == (RingLessons.data()["hints"]["direction"] as Array).size() and h.rows_left() == h.rows.size(),
			"the scheme changed: the direction scheme's rows")
	MatchSetup.set_scheme("keys")
	await _ticks(3)
	for a: StringName in [&"aim", &"weapon_1", &"weapon_next", SwayCaster.QUICK_BIND, &"weapon_5"]:
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
