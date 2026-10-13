extends SceneTree
## The quick spell on LMB (SwayCaster's quick spell, MatchSetup.quick_of / set_quick, BendStrip's LMB chip; the owner,
## 2026-10-05: "the user needs to be able to put hot spells on left click somehow, like they can assign when it is on this,
## this action can be right after"), in Tidebreak's ring (scenes/ring.tscn, MatchSetup.incoming, element earth), the foe held:
##   defaults   each element's quick spell before any is set: its jab (round 2: Bending.jab, earth rock_jab/pebbles, water
##              water_jet/splash, fire fire_jab/embers, air air_palm/palm); the strip's JAB chip says it ("Pebbles") and
##              what the next Q does ("Q: put Spike on left click")
##   bind       Q (the action bend_quick_bind) with Stone Form readied at Boulder (key 1 tapped twice: round 2's keys have
##              no memory): the quick spell is stone_form/cannonball, said on the screen; the key's variation set back to
##              Spike leaves it (frozen)
##   cast       LMB held ("fire"): a lock of the quick spell (lock_src quick, the same lock time as RMB's, the circle and the
##              pose), let go: cast as the Boulder; the readied key and its variation (Spike) never changed
##   after      an RMB lock with LMB pressed meanwhile: the RMB lock goes on as it was (Spike); the moment it is cast, the
##              held LMB starts its own lock; RMB pressed during it is ignored; let go: the Boulder cast
##   kept       per element: fire's own (its jab, Embers, then set to Punch), earth's still the Boulder; read back from
##              the settings file (a new caster's cache); the test keeps its own settings file (GameSettings.path)
##   guards     (the QA pass on tb/QUICK) the readied key's line (HUD, spell_label) keeps the key's variation while a quick
##              lock of the same move runs; a click while the mouse is free, or one that ran into a free mouse, starts no
##              lock until it is let go; nor the equip wheel's pick click; Q with nothing readied says to ready a move; the
##              set key unbound or rebound: the JAB chip's Q line says so at once; no show words in any move's label or
##              variation (the LMB chip can show them all: Wind Run's whirl ride)
##   mode=duel  the same in the duel (scenes/main.tscn, DuelMode.incoming): LMB casts the jab; the world HUD's LMB row
##              under the hotbar and F1's Q, LMB and E lines; Q binds, the wheel stays shut; the readied line during a quick
##              lock; Q with hands free; the set key on F: Q opens the wheel again and its pick click starts no lock;
##              the element changed: its own quick spell
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_quick_spell.gd [-- mode=duel]
## The last line "QUICK SPELL TEST PASSED" or "QUICK SPELL TEST FAILED"; exit 0 only on a pass; a watchdog quits with 2.

const NAME := "QUICK SPELL TEST"
const LIMIT_S := 240.0
const OWN_CFG := "user://quick_spell_test.cfg"
## The show's words (as tests/ring/test_player_words.gd holds them).
const WORDS := ["avatar", "benders?", "bending", "pro-?bend\\w*", "korra", "aang", "airbend\\w*", "firebend\\w*",
		"earthbend\\w*", "waterbend\\w*", "air scooters?", "fire nation", "water tribes?", "earth kingdom", "air nomads?"]

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var p: FrontierPlayer
var c: SwayCaster
var hud: FrontierHUD
var casts: Array = []
var cast_modes: Array = []
var _foe_at := Vector3.INF
var duel_mode := false
var duel: DuelMode


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	MatchSetup._aim_help = "strong"             # (this test's player does not aim his camera: the full help, as before the 2026-10-05 setting)
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	SwayCaster.free_override = true
	InputSetup.ensure()
	for a in OS.get_cmdline_user_args():
		if a == "mode=duel":
			duel_mode = true
	if duel_mode:
		DuelMode.incoming = true
		DuelMode.element = "earth"
		change_scene_to_file("res://scenes/main.tscn")
		_run_duel.call_deferred()
		return
	MatchSetup.incoming = true
	MatchSetup.element = "earth"
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(s: float) -> void:
	await _ticks(int(s * Engine.physics_ticks_per_second))


func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit:
		if cond.call():
			return t
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return INF


func _action(a: StringName) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = a
		e.pressed = down
		Input.parse_input_event(e)
		await _ticks(3)


## The foe held where it stands (no cast, no knock on the player: a hit taken would break a lock).
func _hold_foe() -> void:
	var rm := RingMode.find(self)
	var foe: NpcFighter = rm.foe if rm != null else null
	if foe == null or not is_instance_valid(foe):
		return
	foe.held = true
	if _foe_at == Vector3.INF:
		_foe_at = foe.global_position
	foe.global_position = _foe_at
	foe.velocity = Vector3.ZERO


func _run() -> void:
	for i in 10:
		await process_frame
	lvl = current_scene as RingLevel
	p = lvl.player if lvl != null else null
	_expect(p != null, "the ring and its player")
	if p == null:
		return _end()
	p.ignore_mouse_capture = true
	p.pitch = -0.15
	physics_frame.connect(_hold_foe)
	c = SwayCaster.of(p)
	hud = p.hud
	c.cast.connect(func(m: String, _t: Node3D) -> void:
		casts.append(m)
		cast_modes.append(c.mode_of(m)))           # (the variation it went at: a Stone Form cast is no BendEffects record)
	var laid := await _until(func() -> bool: return p.arena_element == "earth" and p.hotbar.spell != "", 4.0)
	_expect(laid < INF and c != null, "the arena player, earth laid, a move readied")
	var rm := RingMode.find(self)
	if rm != null:
		var up := await _until(func() -> bool: return rm.phase == "FIGHT", 8.0)
		_expect(up < INF, "the round is on (%s)" % rm.phase)
		await _secs(0.3)
	await _defaults()
	await _bind()
	await _cast()
	await _after()
	await _guards()
	await _kept()
	_end()


func _end() -> void:
	Input.action_release(&"fire")
	Input.action_release(&"aim")
	_restore_bind()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


static func _q(id: String, mode: String) -> Dictionary:
	return {"id": id, "mode": mode}


# ---------------------------------------------------------------- the defaults
func _defaults() -> void:
	var want := {"earth": _q("rock_jab", "pebbles"), "water": _q("water_jet", "splash"), "fire": _q("fire_jab", "embers"),
			"air": _q("air_palm", "palm")}
	var ok := true
	for el: String in want:
		ok = ok and MatchSetup.quick_of(el) == want[el] and Bending.jab(el) == want[el]
	_expect(ok, "each element's default quick spell, its jab (%s)" % [Bending.ELEMENTS.map(func(e: String) -> Dictionary: return MatchSetup.quick_of(e))])
	_expect(c.quick_element() == "earth" and c.quick_spell() == want.earth and c.quick_ready(),
			"the player's: earth, Pebbles, ready (%s)" % [c.quick_spell()])
	await _ticks(3)
	p.hotbar.select(0)                           # (Stone Form readied at Spike: the next Q would put it on)
	await _secs(0.4)
	var strip := hud.bend_strip
	_expect(strip != null and strip.quick_line() == "Pebbles" and (strip._quick as Label).text == "Pebbles"
			and strip._quick_box.is_visible_in_tree() and (strip._chip as Label).text.begins_with("LMB"),
			"the strip's JAB chip: \"%s\" (\"%s\")" % [strip.quick_line() if strip != null else "-", (strip._chip as Label).text if strip != null else "-"])
	_expect(strip != null and strip.q_line() == "Q: put Spike on left click",
			"the JAB chip's Q line: \"%s\"" % (strip.q_line() if strip != null else "-"))
	_expect(InputMap.has_action(SwayCaster.QUICK_BIND) and SwayCaster.quick_bind_key() == "Q",
			"the set key is an action of its own, Q by default (%s)" % SwayCaster.quick_bind_key())


# ---------------------------------------------------------------- Q binds the readied move as it is
func _bind() -> void:
	var bar := p.hotbar
	await _secs(0.4)
	bar.select(0)
	await _ticks(2)
	bar.select(0)                                # (key 1 tapped twice: its other move, the Boulder)
	await _ticks(2)
	_expect(c.readied_spell == "stone_form" and c.base_mode_of("stone_form") == "cannonball", "Stone Form readied at Boulder")
	await _action(SwayCaster.QUICK_BIND)
	_expect(c.quick_spell() == _q("stone_form", "cannonball") and MatchSetup.quick_of("earth") == _q("stone_form", "cannonball"),
			"Q: the quick spell is the Boulder, kept (%s, %s)" % [c.quick_spell(), MatchSetup.quick_of("earth")])
	var note := p.interactor._notice.text if p.interactor != null else ""
	_expect(note == "Left click: Stone Form (Boulder)", "said on the screen: \"%s\"" % note)
	c.set_mode("stone_form", "spike")
	await _secs(0.3)
	_expect(c.base_mode_of("stone_form") == "spike" and c.quick_spell() == _q("stone_form", "cannonball")
			and hud.bend_strip.quick_line() == "Boulder",
			"the key's variation set back to Spike; the quick spell stays the Boulder (%s; %s)" % [c.base_mode_of("stone_form"),
			hud.bend_strip.quick_line()])
	_expect(hud.bend_strip.q_line().contains("hold Q: Pebbles back"), "and the JAB chip says how the jab comes back (\"%s\")"
			% hud.bend_strip.q_line())


# ---------------------------------------------------------------- LMB: lock, let go, cast
func _cast() -> void:
	casts.clear()
	cast_modes.clear()
	Input.action_press(&"fire")
	var t := await _until(func() -> bool: return c.state != SwayCaster.State.IDLE, 1.0)
	var d := SwayMoves.move("stone_form")
	var want_s := maxf(float((d.get("mode_lock_s", {}) as Dictionary).get("cannonball", d.get("lock_s", 1.0))) * c.lock_mult
			* c.tier_mult("stone_form"), 0.05)
	_expect(t < INF and c.lock_src == SwayCaster.SRC_QUICK and c.move == "stone_form" and c.mode_of("stone_form") == "cannonball",
			"LMB held: a lock of the quick spell (%s, %s at %s)" % [c.lock_src, c.move, c.mode_of("stone_form")])
	_expect(absf(c.lock_s - want_s) < 0.02, "the same lock time as RMB's (%.2f s, %.2f wanted)" % [c.lock_s, want_s])
	await _ticks(4)
	# (in the ring a bending lock gathers its element round the body instead of the circle: BendCharge, 2026-10-12)
	_expect(c.form.charge != null and is_instance_valid(c.form.charge) and c.form.charge.element == "earth"
			and (c.form.circle == null or not is_instance_valid(c.form.circle)) and c.pose.posing(),
			"earth gathered round the body (no circle), the pose on")
	_expect(c.readied_spell == "stone_form" and c.base_mode_of("stone_form") == "spike" and String(hud.bend_strip.column(0).mode) == "spike"
			and p.hotbar.spell == "stone_form", "meanwhile the key is as it was: Stone Form at Spike, the strip's column too")
	_expect(c.spell_label("stone_form") == "Stone Form (Spike)" and hud._spell_mode("stone_form") == "spike",
			"meanwhile the readied key's line keeps Spike (%s; %s)" % [c.spell_label("stone_form"), hud._spell_mode("stone_form")])
	var full := await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 3.0)
	Input.action_release(&"fire")
	var cast_t := await _until(func() -> bool: return not casts.is_empty(), 1.0)
	await _secs(0.6)
	_expect(full < INF and cast_t < INF and casts == ["stone_form"] and cast_modes == ["cannonball"],
			"let go: Stone Form cast as the Boulder (full in %.2f s; %s; %s)" % [full, casts, cast_modes])
	_expect(c.readied_spell == "stone_form" and c.base_mode_of("stone_form") == "spike" and c.mode_of("stone_form") == "spike"
			and p.hotbar.spell == "stone_form", "after: the readied key and its variation untouched (%s at %s)" % [c.readied_spell,
			c.mode_of("stone_form")])


# ---------------------------------------------------------------- right after: one lock at a time
func _after() -> void:
	await _secs(0.4)
	casts.clear()
	cast_modes.clear()
	Input.action_press(&"aim")
	var t := await _until(func() -> bool: return c.state != SwayCaster.State.IDLE, 1.0)
	_expect(t < INF and c.lock_src == SwayCaster.SRC_AIM and c.move == "stone_form" and c.mode_of("stone_form") == "spike",
			"RMB: a lock of the readied key (Spike)")
	await _ticks(3)
	Input.action_press(&"fire")
	await _ticks(4)
	_expect(c.lock_src == SwayCaster.SRC_AIM and c.state != SwayCaster.State.IDLE and c.mode_of("stone_form") == "spike",
			"LMB pressed meanwhile: ignored, the RMB lock goes on at Spike")
	await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 3.0)
	Input.action_release(&"aim")
	var cast_t := await _until(func() -> bool: return not casts.is_empty(), 1.0)
	var rmb := String(cast_modes[0]) if not cast_modes.is_empty() else ""
	_expect(cast_t < INF and casts == ["stone_form"] and rmb == "spike", "RMB let go: cast as the Spike (%s, %s)" % [casts, rmb])
	var next := await _until(func() -> bool: return c.state != SwayCaster.State.IDLE and c.lock_src == SwayCaster.SRC_QUICK, 0.5)
	_expect(next < 0.2 and c.move == "stone_form" and c.mode_of("stone_form") == "cannonball",
			"LMB still held: its lock (the Boulder) starts right after the cast (%.3f s)" % next)
	await _ticks(4)
	Input.action_press(&"aim")
	await _ticks(4)
	_expect(c.lock_src == SwayCaster.SRC_QUICK and c.state != SwayCaster.State.IDLE and c.mode_of("stone_form") == "cannonball",
			"RMB pressed during the LMB lock: ignored (%s, %s)" % [c.lock_src, c.mode_of("stone_form")])
	Input.action_release(&"aim")
	await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 3.0)
	casts.clear()
	cast_modes.clear()
	Input.action_release(&"fire")
	var c2 := await _until(func() -> bool: return not casts.is_empty(), 1.0)
	await _secs(0.6)
	_expect(c2 < INF and cast_modes == ["cannonball"] and c.base_mode_of("stone_form") == "spike",
			"LMB let go: the Boulder cast, the key still at Spike (%s)" % [cast_modes])
	await _ticks(5)
	_expect(c.state == SwayCaster.State.IDLE and c.lock_src == SwayCaster.SRC_AIM, "both let go: no lock, the aim's again")


# ---------------------------------------------------------------- kept per element
func _kept() -> void:
	MatchSetup.element = "fire"
	var t := await _until(func() -> bool: return p.arena_element == "fire" and p.hotbar.spell == "fire_blast", 3.0)
	_expect(t < INF and c.quick_spell() == _q("fire_jab", "embers"), "fire: its own jab, Embers (%s)" % [c.quick_spell()])
	await _action(SwayCaster.QUICK_BIND)
	_expect(c.quick_spell() == _q("fire_blast", "punch"), "fire: Q sets the Punch (%s)" % [c.quick_spell()])
	MatchSetup.element = "earth"
	t = await _until(func() -> bool: return p.arena_element == "earth", 3.0)
	_expect(t < INF and c.quick_spell() == _q("stone_form", "cannonball"), "earth again: still the Boulder (%s)" % [c.quick_spell()])
	c._quick.clear()
	_expect(c.quick_spell() == _q("stone_form", "cannonball") and MatchSetup.quick_of("fire") == _q("fire_blast", "punch")
			and String(GameSettings.get_value(MatchSetup.QUICK_SECTION, "earth")) == "stone_form/cannonball",
			"read back from the settings file: earth the Boulder, fire the Punch")
	_expect(GameSettings.file() == OWN_CFG, "kept in the test's own file (%s), never the player's" % GameSettings.file())
	_expect(not MatchSetup.set_quick("earth", "fire_blast", "punch") and not MatchSetup.set_quick("earth", "stone_form", "nope"),
			"another element's move, or a variation it has not, cannot be earth's quick spell")


# ---------------------------------------------------------------- guards (the QA pass)
## Whether a lock starts within `n` ticks (the state off IDLE).
func _locks_within(n: int) -> bool:
	for i in n:
		await physics_frame
		if c.state != SwayCaster.State.IDLE:
			return true
	return false


## Lets go of LMB and waits the lock out (a lock let go before it fills breaks; one full casts).
func _let_go() -> void:
	Input.action_release(&"fire")
	await _until(func() -> bool: return c.state == SwayCaster.State.IDLE, 2.0)
	await _secs(0.5)


func _guards() -> void:
	await _secs(0.4)
	await _mouse_free()
	await _wheel_click()
	await _nothing_readied()
	await _rebind()
	_words()


## Esc's free mouse: a click then is the one that takes the mouse back, never a lock (Weapon._fire_input_enabled's rule).
func _mouse_free() -> void:
	p.ignore_mouse_capture = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _ticks(3)
	Input.action_press(&"fire")
	var locked := await _locks_within(20)
	_expect(not locked, "the mouse free: an LMB press starts no lock (%s)" % c.state)
	p.ignore_mouse_capture = true              # (the click took the mouse back; LMB still held)
	locked = await _locks_within(20)
	_expect(not locked, "the mouse taken back by that click, LMB still held: still no lock (%s)" % c.state)
	Input.action_release(&"fire")
	await _ticks(3)
	Input.action_press(&"fire")
	locked = await _locks_within(10)
	_expect(locked and c.lock_src == SwayCaster.SRC_QUICK, "let go and pressed again on the game: the quick lock (%s)" % c.lock_src)
	await _let_go()


## The equip wheel's pick click (EquipWheel: the click that takes a slot, held after it closes: blocks_fire).
func _wheel_click() -> void:
	var w := p.equip_wheel
	if w == null:
		print("  (the arena has no equip wheel: mode=duel holds its pick click)")
		return
	w.is_open = true                           # (open: the click comes on it)
	await _ticks(2)
	Input.action_press(&"fire")
	await _ticks(1)
	w._hold_fire = true                        # (it took a slot and closed: the click still held)
	w.is_open = false
	var locked := await _locks_within(20)
	_expect(not locked, "the click that picks on the equip wheel starts no quick lock (%s)" % c.state)
	Input.action_release(&"fire")
	await _ticks(3)
	_expect(not w.blocks_fire(), "the wheel's click let go: LMB the game's again")
	Input.action_press(&"fire")
	locked = await _locks_within(10)
	_expect(locked and c.lock_src == SwayCaster.SRC_QUICK, "the next click: the quick lock")
	await _let_go()


## Q with nothing readied: a line saying to ready a move; the quick spell left as it was.
func _nothing_readied() -> void:
	var was := c.quick_spell().duplicate()
	var r := c.readied_spell                   # (the arena keeps a move readied: put down here for the one call)
	c.readied_spell = ""
	var bound := c.bind_quick()
	c.readied_spell = r
	var note := p.interactor._notice.text if p.interactor != null else ""
	_expect(not bound and note.begins_with("Ready a move first") and c.quick_spell() == was,
			"Q with nothing readied: \"%s\" (%s)" % [note, c.quick_spell()])
	await _ticks(4)


## The set key unbound, then rebound to F: the JAB chip's Q line (and F1) follow at once.
func _rebind() -> void:
	var strip := hud.bend_strip
	InputMap.action_erase_events(SwayCaster.QUICK_BIND)
	await _secs(0.4)
	_expect(SwayCaster.quick_bind_key() == "" and strip.q_line().contains("(no key)") and not strip.q_line().contains("Q:")
			and not hud.help_text().contains("Q: the readied move"),
			"the set key unbound: \"%s\"" % strip.q_line())
	var k := InputEventKey.new()
	k.physical_keycode = KEY_F
	InputMap.action_add_event(SwayCaster.QUICK_BIND, k)
	await _secs(0.4)
	_expect(SwayCaster.quick_bind_key() == "F" and strip.q_line().contains("F: put") and (strip._chips.jab.other as Label).text == strip.q_line()
			and hud.help_text().contains("F: the readied move onto LMB"),
			"rebound to F: \"%s\"" % strip.q_line())
	_restore_bind()
	await _secs(0.4)
	_expect(strip.q_line().contains("Q: put"), "back on Q: \"%s\"" % strip.q_line())


func _restore_bind() -> void:
	if not InputMap.has_action(SwayCaster.QUICK_BIND):
		return
	InputMap.action_erase_events(SwayCaster.QUICK_BIND)
	var k := InputEventKey.new()
	k.physical_keycode = SwayCaster.QUICK_BIND_KEY
	InputMap.action_add_event(SwayCaster.QUICK_BIND, k)


## No show words in what the LMB chip can show: every spell's name at each of its variations.
func _words() -> void:
	var re := RegEx.create_from_string("(?i)\\b(?:%s)\\b" % "|".join(PackedStringArray(WORDS)))
	var bad: Array[String] = []
	for sp: Dictionary in SwayCaster.spells():
		var id := String(sp.id)
		var ms: Array = SwayCaster.modes_of(id)
		for m: Variant in (ms if not ms.is_empty() else [""]):
			var lb := SwayCaster.label_with(id, String(m))
			if re.search(lb) != null:
				bad.append(lb)
	_expect(bad.is_empty() and SwayCaster.label_with("wind_run", "air_scooter") == "Wind Run (whirl ride)",
			"no show words in any move at any variation (%s; %s)" % [bad, SwayCaster.label_with("wind_run", "air_scooter")])


# ---------------------------------------------------------------- mode=duel
func _note() -> String:
	return p.interactor._notice.text if p.interactor != null and p.interactor._notice != null else ""


func _hold_npc() -> void:
	if duel == null or duel.npc == null or not is_instance_valid(duel.npc):
		return
	duel.npc.held = true
	if _foe_at == Vector3.INF:
		_foe_at = duel.npc.global_position
	duel.npc.global_position = _foe_at
	duel.npc.velocity = Vector3.ZERO


func _key_down(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)


func _key(code: Key) -> void:
	_key_down(code, true)
	await _ticks(3)
	_key_down(code, false)
	await _ticks(3)


func _run_duel() -> void:
	for i in 20:
		await process_frame
	p = current_scene.get_node_or_null("Player") as FrontierPlayer
	duel = DuelMode.find(self)
	_expect(p != null and duel != null, "the duel and its player")
	if p == null or duel == null:
		return _end()
	p.ignore_mouse_capture = true
	p.pitch = -0.15
	physics_frame.connect(_hold_npc)
	hud = p.hud
	await _secs(Hotbar.KIT_S + 1.0)
	await _until(func() -> bool: return duel.phase == DuelMode.Phase.FIGHT, 8.0)
	await _secs(0.3)
	c = SwayCaster.of(p)
	c.cast.connect(func(m: String, _t: Node3D) -> void: casts.append(m))
	_expect(c.quick_element() == "earth" and c.quick_spell() == _q("rock_jab", "pebbles") and c.quick_ready(),
			"the duel: earth's quick spell ready (%s)" % [c.quick_spell()])
	# LMB: the default
	casts.clear()
	Input.action_press(&"fire")
	await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 3.0)
	Input.action_release(&"fire")
	await _until(func() -> bool: return not casts.is_empty(), 1.0)
	await _secs(0.5)
	_expect(casts == ["rock_jab"] and String(BendEffects.last_of(c).get("mode", "")) == "pebbles",
			"the duel: LMB casts Pebbles (%s)" % [casts])
	# the screen: the world HUD's LMB row, F1's lines
	await _ticks(3)
	_expect(not hud.arena and hud.quick_row.is_visible_in_tree() and hud.quick_name.text == "Pebbles"
			and hud.quick_help.visible and hud.quick_help.text.begins_with("Q: put "),
			"the duel shows the LMB row: \"%s\" / \"%s\"" % [hud.quick_name.text, hud.quick_help.text])
	var help := hud.help_text()
	_expect(not help.contains("hold Q: equip wheel") and not help.contains(FrontierHUD.WORLD_LMB)
			and help.contains("Q: the readied move onto LMB") and help.contains("hold LMB") and not help.contains(FrontierHUD.WORLD_E)
			and help.contains("E guard"),
			"the duel's F1: Q, LMB and E as the element has them")
	await _key(KEY_F1)
	_expect(hud._help_label.text == help and hud._help_box.visible, "F1 shows it")
	await _key(KEY_F1)
	# Q binds; the wheel stays shut
	var w := p.equip_wheel
	var id := c.readied_spell
	var ms := SwayCaster.modes_of(id)
	if ms.size() > 1:
		c.set_mode(id, String(ms[1]))
	await _ticks(2)
	var want := _q(id, c.base_mode_of(id))
	_key_down(KEY_Q, true)
	await _ticks(4)
	var wheel_open := w != null and w.is_open
	_key_down(KEY_Q, false)
	await _ticks(4)
	_expect(c.quick_spell() == want and not wheel_open and _note().begins_with("Left click: "),
			"the duel: Q binds %s, the wheel stays shut (%s, \"%s\")" % [want, c.quick_spell(), _note()])
	await _ticks(3)
	_expect(hud.quick_name.text == KitWords.move_name(String(want.id), String(want.mode)), "the LMB row follows: \"%s\"" % hud.quick_name.text)
	# the readied line while a quick lock of the same move at another variation runs
	if ms.size() > 1:
		c.set_mode(id, String(ms[0]))
		await _ticks(3)
		var before := hud._spell_line(id)
		Input.action_press(&"fire")
		await _until(func() -> bool: return c.state != SwayCaster.State.IDLE, 1.0)
		await _ticks(3)
		var during := hud._spell_line(id)
		var src := c.lock_src
		await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 3.0)
		Input.action_release(&"fire")
		await _secs(0.6)
		_expect(src == SwayCaster.SRC_QUICK and before == during,
				"the readied key's line holds during the quick lock (\"%s\" -> \"%s\")" % [before, during])
	# hands free: Q says to ready a move
	await _secs(0.4)
	p.hotbar.hands_free()
	await _ticks(5)
	await _key(KEY_Q)
	_expect(c.readied_spell == "" and _note().begins_with("Ready a move first"),
			"Q with nothing readied in the duel: \"%s\"" % _note())
	p.hotbar.take(0)
	await _secs(0.5)
	# the set key on F: Q opens the wheel again; its pick click starts no lock
	InputMap.action_erase_events(SwayCaster.QUICK_BIND)
	var k := InputEventKey.new()
	k.physical_keycode = KEY_F
	InputMap.action_add_event(SwayCaster.QUICK_BIND, k)
	_expect(hud.help_text().contains("hold Q: equip wheel · F: the readied move onto LMB"),
			"F1 with the set key on F: the wheel keeps Q")
	_key_down(KEY_Q, true)
	await _ticks(4)
	var open3 := w != null and w.is_open
	_expect(open3, "the set key on F: Q opens the wheel again")
	if open3:
		w.pick_toward(Vector2(0, -200))
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = true
		Input.parse_input_event(mb)
		var locked := await _locks_within(10)
		mb = mb.duplicate()
		mb.pressed = false
		Input.parse_input_event(mb)
		_key_down(KEY_Q, false)
		await _ticks(4)
		_expect(not locked, "the click that picks on the wheel starts no quick lock (%s)" % c.state)
	else:
		_key_down(KEY_Q, false)
	_restore_bind()
	await _secs(0.5)
	# another element in the duel: its own quick spell
	duel.choose("fire")
	await _secs(Hotbar.KIT_S + 0.5)
	await _until(func() -> bool: return duel.phase == DuelMode.Phase.FIGHT, 8.0)
	await _ticks(3)
	_expect(c.quick_element() == "fire" and c.quick_spell() == _q("fire_jab", "embers") and hud.quick_name.text == "Embers",
			"the duel's element fire: its jab, Embers (%s; \"%s\")" % [c.quick_spell(), hud.quick_name.text])
	_end()
