extends SceneTree
## The quick spell on LMB (SwayCaster's quick spell, MatchSetup.quick_of / set_quick, BendStrip's LMB chip; the owner,
## 2026-10-05: "the user needs to be able to put hot spells on left click somehow, like they can assign when it is on this,
## this action can be right after"), in Tidebreak's ring (scenes/ring.tscn, MatchSetup.incoming, element earth), the foe held:
##   defaults   each element's quick spell before any is set (earth rock_jab/pebbles, water water_jet/splash, fire
##              fire_jab/jab, air air_palm/palm); the strip's LMB chip says it, the help line says the set key
##   bind       Q (the action bend_quick_bind) with Rock Jab readied at kick-up: the quick spell is rock_jab/kick_up, said on
##              the screen; the wheel stepping the key on to stomp leaves it (frozen)
##   cast       LMB held ("fire"): a lock of the quick spell (lock_src quick, the same lock time as RMB's, the circle and the
##              pose), let go: cast at kick-up; the readied key and its variation (stomp) never changed, the strip's pip too
##   after      an RMB lock with LMB pressed meanwhile: the RMB lock goes on as it was (stomp); the moment it is cast, the held
##              LMB starts its own lock; RMB pressed during it is ignored; let go: kick-up cast
##   kept       per element: fire's own (its default, then set to Fire Blast punch), earth's still kick-up; read back from
##              the settings file (a new caster's cache); the test keeps its own settings file (GameSettings.path)
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_quick_spell.gd
## The last line "QUICK SPELL TEST PASSED" or "QUICK SPELL TEST FAILED"; exit 0 only on a pass; a watchdog quits with 2.

const NAME := "QUICK SPELL TEST"
const LIMIT_S := 240.0
const OWN_CFG := "user://quick_spell_test.cfg"

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var p: FrontierPlayer
var c: SwayCaster
var hud: FrontierHUD
var casts: Array = []
var _foe_at := Vector3.INF


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
	SwayCaster.free_override = true
	InputSetup.ensure()
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
	c.cast.connect(func(m: String, _t: Node3D) -> void: casts.append(m))
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
	await _kept()
	_end()


func _end() -> void:
	Input.action_release(&"fire")
	Input.action_release(&"aim")
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
	var want := {"earth": _q("rock_jab", "pebbles"), "water": _q("water_jet", "splash"), "fire": _q("fire_jab", "jab"),
			"air": _q("air_palm", "palm")}
	var ok := true
	for el: String in want:
		ok = ok and MatchSetup.quick_of(el) == want[el]
	_expect(ok, "each element's default quick spell (%s)" % [Bending.ELEMENTS.map(func(e: String) -> Dictionary: return MatchSetup.quick_of(e))])
	_expect(c.quick_element() == "earth" and c.quick_spell() == want.earth and c.quick_ready(),
			"the player's: earth, Rock Jab (pebbles), ready (%s)" % [c.quick_spell()])
	await _ticks(3)
	var strip := hud.bend_strip
	_expect(strip != null and strip.quick_line() == "Rock Jab (pebbles)" and (strip._quick as Label).text == "Rock Jab (pebbles)"
			and strip._quick_box.is_visible_in_tree() and (strip._chip as Label).text == "LMB",
			"the strip's LMB chip: \"%s\"" % (strip.quick_line() if strip != null else "-"))
	_expect(strip != null and strip.help_line().begins_with("Q: set left click") and (strip._help as Label).visible,
			"the strip's help line: \"%s\"" % (strip.help_line() if strip != null else "-"))
	_expect(InputMap.has_action(SwayCaster.QUICK_BIND) and SwayCaster.quick_bind_key() == "Q",
			"the set key is an action of its own, Q by default (%s)" % SwayCaster.quick_bind_key())


# ---------------------------------------------------------------- Q binds the readied move as it is
func _bind() -> void:
	var bar := p.hotbar
	bar.take(0)
	await _ticks(2)
	if c.readied_spell != "rock_jab":
		bar.select(0)                            # (key 1 again: its other skill)
		await _ticks(2)
	c.set_mode("rock_jab", "kick_up")
	await _ticks(2)
	_expect(c.readied_spell == "rock_jab" and c.base_mode_of("rock_jab") == "kick_up", "Rock Jab readied at kick-up")
	await _action(SwayCaster.QUICK_BIND)
	_expect(c.quick_spell() == _q("rock_jab", "kick_up") and MatchSetup.quick_of("earth") == _q("rock_jab", "kick_up"),
			"Q: the quick spell is Rock Jab (kick-up), kept (%s, %s)" % [c.quick_spell(), MatchSetup.quick_of("earth")])
	var note := p.interactor._notice.text if p.interactor != null else ""
	_expect(note == "Left click: Rock Jab (kick-up)", "said on the screen: \"%s\"" % note)
	await _action(&"weapon_next")
	await _ticks(3)
	_expect(c.base_mode_of("rock_jab") == "stomp" and c.quick_spell() == _q("rock_jab", "kick_up")
			and hud.bend_strip.quick_line() == "Rock Jab (kick-up)",
			"the wheel steps the key on to stomp; the quick spell stays kick-up (%s; %s)" % [c.base_mode_of("rock_jab"),
			hud.bend_strip.quick_line()])


# ---------------------------------------------------------------- LMB: lock, let go, cast
func _cast() -> void:
	casts.clear()
	var pip0 := int(hud.bend_strip.column(0).mode_i)
	Input.action_press(&"fire")
	var t := await _until(func() -> bool: return c.state != SwayCaster.State.IDLE, 1.0)
	var d := SwayMoves.move("rock_jab")
	var want_s := maxf(float((d.get("mode_lock_s", {}) as Dictionary).get("kick_up", d.get("lock_s", 1.0))) * c.lock_mult
			* c.tier_mult("rock_jab"), 0.05)
	_expect(t < INF and c.lock_src == SwayCaster.SRC_QUICK and c.move == "rock_jab" and c.mode_of("rock_jab") == "kick_up",
			"LMB held: a lock of the quick spell (%s, %s at %s)" % [c.lock_src, c.move, c.mode_of("rock_jab")])
	_expect(absf(c.lock_s - want_s) < 0.02, "the same lock time as RMB's (%.2f s, %.2f wanted)" % [c.lock_s, want_s])
	await _ticks(4)
	_expect(c.form.circle != null and is_instance_valid(c.form.circle) and c.pose.posing(), "the circle drawn, the pose on")
	_expect(c.readied_spell == "rock_jab" and c.base_mode_of("rock_jab") == "stomp" and int(hud.bend_strip.column(0).mode_i) == pip0
			and p.hotbar.spell == "rock_jab", "meanwhile the key is as it was: Rock Jab at stomp, the strip's pip unmoved")
	var full := await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 3.0)
	Input.action_release(&"fire")
	var cast_t := await _until(func() -> bool: return not casts.is_empty(), 1.0)
	await _secs(0.6)
	var last := BendEffects.last_of(c)
	_expect(full < INF and cast_t < INF and casts == ["rock_jab"] and String(last.get("do", "")) == "kick_up"
			and String(last.get("mode", "")) == "kick_up",
			"let go: Rock Jab cast at kick-up (full in %.2f s; %s; %s)" % [full, casts, last.get("do", "-")])
	_expect(c.readied_spell == "rock_jab" and c.base_mode_of("rock_jab") == "stomp" and c.mode_of("rock_jab") == "stomp"
			and p.hotbar.spell == "rock_jab", "after: the readied key and its variation untouched (%s at %s)" % [c.readied_spell,
			c.mode_of("rock_jab")])


# ---------------------------------------------------------------- right after: one lock at a time
func _after() -> void:
	await _secs(0.4)
	casts.clear()
	Input.action_press(&"aim")
	var t := await _until(func() -> bool: return c.state != SwayCaster.State.IDLE, 1.0)
	_expect(t < INF and c.lock_src == SwayCaster.SRC_AIM and c.move == "rock_jab" and c.mode_of("rock_jab") == "stomp",
			"RMB: a lock of the readied key (stomp)")
	await _ticks(3)
	Input.action_press(&"fire")
	await _ticks(4)
	_expect(c.lock_src == SwayCaster.SRC_AIM and c.state != SwayCaster.State.IDLE and c.mode_of("rock_jab") == "stomp",
			"LMB pressed meanwhile: ignored, the RMB lock goes on at stomp")
	await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 3.0)
	Input.action_release(&"aim")
	var cast_t := await _until(func() -> bool: return not casts.is_empty(), 1.0)
	_expect(cast_t < INF and casts == ["rock_jab"], "RMB let go: cast (%s)" % [casts])
	var next := await _until(func() -> bool: return c.state != SwayCaster.State.IDLE and c.lock_src == SwayCaster.SRC_QUICK, 0.5)
	_expect(next < 0.2 and c.move == "rock_jab" and c.mode_of("rock_jab") == "kick_up",
			"LMB still held: its lock (kick-up) starts right after the cast (%.3f s)" % next)
	# (the RMB cast's stomp lands on its strike, the LMB lock running by then: at its own variation, not the quick one's)
	var landed := await _until(func() -> bool: return String(BendEffects.last_of(c).get("do", "")) == "ring", 1.0)
	_expect(landed < INF and String(BendEffects.last_of(c).get("mode", "")) == "stomp",
			"the RMB cast lands as stomp while the LMB lock runs (%s)" % [BendEffects.last_of(c).get("mode", "-")])
	await _ticks(4)
	Input.action_press(&"aim")
	await _ticks(4)
	_expect(c.lock_src == SwayCaster.SRC_QUICK and c.state != SwayCaster.State.IDLE and c.mode_of("rock_jab") == "kick_up",
			"RMB pressed during the LMB lock: ignored (%s, %s)" % [c.lock_src, c.mode_of("rock_jab")])
	Input.action_release(&"aim")
	await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 3.0)
	casts.clear()
	Input.action_release(&"fire")
	var c2 := await _until(func() -> bool: return not casts.is_empty(), 1.0)
	await _secs(0.6)
	_expect(c2 < INF and String(BendEffects.last_of(c).get("mode", "")) == "kick_up" and c.base_mode_of("rock_jab") == "stomp",
			"LMB let go: kick-up cast, the key still at stomp (%s)" % BendEffects.last_of(c).get("mode", "-"))
	await _ticks(5)
	_expect(c.state == SwayCaster.State.IDLE and c.lock_src == SwayCaster.SRC_AIM, "both let go: no lock, the aim's again")


# ---------------------------------------------------------------- kept per element
func _kept() -> void:
	MatchSetup.element = "fire"
	var t := await _until(func() -> bool: return p.arena_element == "fire" and p.hotbar.spell == "fire_blast", 3.0)
	_expect(t < INF and c.quick_spell() == _q("fire_jab", "jab"), "fire: its own default, Fire Jab (jab) (%s)" % [c.quick_spell()])
	c.set_mode("fire_blast", "punch")
	await _action(SwayCaster.QUICK_BIND)
	_expect(c.quick_spell() == _q("fire_blast", "punch"), "fire: Q sets Fire Blast (punch) (%s)" % [c.quick_spell()])
	MatchSetup.element = "earth"
	t = await _until(func() -> bool: return p.arena_element == "earth", 3.0)
	_expect(t < INF and c.quick_spell() == _q("rock_jab", "kick_up"), "earth again: still Rock Jab (kick-up) (%s)" % [c.quick_spell()])
	c._quick.clear()
	_expect(c.quick_spell() == _q("rock_jab", "kick_up") and MatchSetup.quick_of("fire") == _q("fire_blast", "punch")
			and String(GameSettings.get_value(MatchSetup.QUICK_SECTION, "earth")) == "rock_jab/kick_up",
			"read back from the settings file: earth kick-up, fire punch")
	_expect(GameSettings.file() == OWN_CFG, "kept in the test's own file (%s), never the player's" % GameSettings.file())
	_expect(not MatchSetup.set_quick("earth", "fire_blast", "punch") and not MatchSetup.set_quick("earth", "rock_jab", "nope"),
			"another element's move, or a variation it has not, cannot be earth's quick spell")
