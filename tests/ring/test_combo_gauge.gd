extends SceneTree
## The combo and the guard's gauge (BendCombo; the owner, 2026-10-12: "a combo meter every successful parry", "successful hit
## adds to the combo meter", "cast faster ... with a limit", "the parry be power metter gauge each e press uses it and hold it
## drains it", "dont forget the E gauge so no one can spam it"; picked 5 stacks lost when hit, guard break), in a 1v1 Lives ring
## (earth against a held fire bot), E held through SwayCaster.guard_override:
##   the gauge   full at first, the crosshair's right bracket hidden until a guard stands (shown then); a tapped guard costs
##               tap; held past its window it drains; tapped over and over it breaks (the guard ended, the player in hitstun),
##               E raises nothing while broken, the bracket shown red;
##               it refills from refill_after_s and E works again at back_at; a bot whose gauge is broken starts no guard
##   the combo   a gauge: a hit that lands (RingRules.on_hit) a stack's worth of the hitter's, the struck one's emptied; never
##               past max; a tick (no_hurt) none; a perfect guard (BendStatus.parry_reward) a stack; after grace_s it drains
##               drain_s a second, down to none; each stack per off his locks (BendStatus.cast_mult, the level as it drains);
##               the crosshair's left bracket shown while there is any
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_combo_gauge.gd
## The last line "COMBO GAUGE PASSED (<n> checks)" or "COMBO GAUGE FAILED (<f> of <n>)".

const LIMIT_S := 150.0

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var c: SwayCaster
var foe: NpcFighter
var rm: RingMode
var ring: SwayRing


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("COMBO GAUGE FAILED (watchdog)")
		quit(2))
	MatchSetup.set_match()
	MatchSetup.incoming = true
	MatchSetup.format = "1v1"
	MatchSetup.element = "earth"
	MatchSetup.foes = ["fire"]
	MatchSetup.round_s = 600.0
	RingRules.rule_set_override = "stock"
	SwayCaster.free_override = true
	InputSetup.ensure()
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _end() -> void:
	RingRules.rule_set_override = ""
	if c != null:
		c.guard_override = null
	if fails.is_empty() and checks > 0:
		print("COMBO GAUGE PASSED (%d checks)" % checks)
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("COMBO GAUGE FAILED (%d of %d)" % [fails.size(), checks])
		quit(1)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(s: float) -> void:
	await _ticks(ceili(s * float(Engine.physics_ticks_per_second)))


func _until(cond: Callable, s: float) -> bool:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await physics_frame
	return bool(cond.call())


func _num(block: String, key: String) -> float:
	return float(RingRules.stock_block(block).get(key, 0.0))


## E tapped: held until its guard stands (or the gauge breaks: _stagger read the frame it does), then let go; true when it stood.
var _stagger := false
func _tap() -> bool:
	c.guard_override = true
	var was := BendCombo.broken(p)
	var up := await _until(func() -> bool:
		if not was and BendCombo.broken(p):
			var kn := BendKnock.peek(p)
			_stagger = kn != null and kn.stun_t > 0.0
			return true
		return c.guard_up(), 1.0)
	c.guard_override = false
	return up and c.guard_up()


## Every guard of his down, his hitstun over.
func _rest() -> void:
	c.guard_override = false
	await _until(func() -> bool: return not c.guard_up() and c.state == SwayCaster.State.IDLE, 4.0)
	var kn := BendKnock.peek(p)
	await _until(func() -> bool: return kn == null or kn.stun_t <= 0.0, 2.0)
	await _ticks(3)


func _hit(on: Node, by: Node, extra := {}) -> void:
	var info := {"tag": "stone_form/spike", "move": "stone_form", "at": (on as Node3D).global_position + Vector3.UP}
	info.merge(extra, true)
	rm.rules.on_hit(on, by, info)


func _run() -> void:
	for i in 20:
		await process_frame
	var lvl := current_scene as RingLevel
	p = lvl.player if lvl != null else null
	rm = RingMode.find(self)
	foe = rm.foe as NpcFighter if rm != null else null
	_expect(p != null and foe != null, "the ring, the player and the foe")
	if p == null or foe == null:
		return _end()
	p.ignore_mouse_capture = true
	c = SwayCaster.of(p)
	var fight := await _until(func() -> bool: return rm.phase == "FIGHT" and c.enabled, 12.0)
	_expect(fight and RingRules.stock_on() and BendCombo.on(), "a Lives fight on the new ring")
	foe.held = true
	ring = c.ring
	await _secs(3.5)                                   # (the spawn safety over)
	await _ticks(5)
	# ---- the gauge
	var m0: Dictionary = ring.meters() if ring != null else {}
	_expect(is_equal_approx(BendCombo.gauge(p), 1.0) and float(m0.get("gauge_a", 1.0)) < 0.05 and float(m0.get("combo_a", 1.0)) < 0.05,
			"the gauge full at first, nothing on the crosshair yet (%s)" % str(m0))
	c.guard_override = true
	await _until(func() -> bool: return c.guard_up(), 1.0)
	await _ticks(12)
	var m_up: Dictionary = ring.meters() if ring != null else {}
	_expect(float(m_up.get("gauge_a", 0.0)) > 0.5, "a guard up: its gauge on the crosshair (%s)" % str(m_up))
	c.guard_override = false
	await _rest()
	await _secs(4.0)
	var up := await _tap()
	await _rest()
	var g1 := BendCombo.gauge(p)
	var tap := _num("guard_gauge", "tap")
	_expect(up and g1 < 1.0 - tap + 0.03 and g1 > 1.0 - tap - 0.1, "a tapped guard costs %.2f (gauge %.2f)" % [tap, g1])
	await _secs(4.0)                                   # (refilled)
	var g_full := BendCombo.gauge(p)
	c.guard_override = true
	await _until(func() -> bool: return c.guard_up(), 1.0)
	await _secs(1.5)
	var g_held := BendCombo.gauge(p)
	c.guard_override = false
	await _rest()
	_expect(is_equal_approx(g_full, 1.0) and g_held < g_full - tap - 0.1,
			"refilled to %.2f; held 1.5 s (past its window) it drains to %.2f" % [g_full, g_held])
	# spammed: it breaks
	await _secs(4.0)
	var taps := 0
	var stunned := false
	var broke := false
	while taps < 12 and not broke:
		await _until(func() -> bool: return not c.guard_up() and c.state == SwayCaster.State.IDLE, 3.0)   # (E again as each falls)
		await _tap()
		taps += 1
		broke = BendCombo.broken(p)
		stunned = _stagger
		await _ticks(4)
	_expect(broke and taps <= 7 and stunned and not c.guard_up(),
			"E spammed: the gauge breaks after %d taps, the guard ended, he staggered (%s)" % [taps, stunned])
	await _ticks(10)
	var ms: Dictionary = ring.meters() if ring != null else {}
	c.guard_override = true
	await _secs(0.4)
	var raised := c.guard_up()
	c.guard_override = false
	_expect(not raised and bool(ms.get("broken", false)) and float(ms.get("gauge_a", 0.0)) > 0.5,
			"broken: E raises nothing, the crosshair's gauge shown red (%s)" % str(ms))
	var t0 := float(p.get_meta(BendCombo.BROKE_META, BendStatus.now()))     # (game time from the break: headless runs faster than the clock)
	var back := await _until(func() -> bool: return BendCombo.can_guard(p), 6.0)
	var took := BendStatus.now() - t0
	var want := _num("guard_gauge", "back_at") / _num("guard_gauge", "refill_s") + _num("guard_gauge", "refill_after_s")
	_expect(back and absf(took - want) <= 0.4 and BendCombo.gauge(p) >= _num("guard_gauge", "back_at") - 0.01,
			"it refills: E back after %.1f s (want about %.1f), at %.2f" % [took, want, BendCombo.gauge(p)])
	up = await _tap()
	await _rest()
	_expect(up, "and a guard rises again")
	# a bot's
	var bend: NpcBending = foe.brain.bending as NpcBending if foe.brain != null else null
	foe.set_meta(BendCombo.GAUGE_META, {"g": 0.0, "at": BendStatus.now(), "up": 0, "down_at": BendStatus.now(), "broken": true})
	var gd := NpcBending.guard_of(bend.element) if bend != null else []
	if bend != null and gd.size() >= 2:
		bend.begin(String(gd[0]), String(gd[1]))
	_expect(bend != null and gd.size() >= 2 and bend.casting == "", "a bot whose gauge is broken starts no guard (%s)" % (bend.casting if bend != null else "-"))
	BendCombo.reset(foe)
	# ---- the combo
	BendCombo.reset(p)
	_expect(BendCombo.stacks(p) == 0 and is_equal_approx(BendStatus.cast_mult(p), 1.0), "no combo at first")
	_hit(foe, p)
	_expect(BendCombo.stacks(p) == 1 and BendCombo.stacks(foe) == 0, "his hit lands: a stack (%d)" % BendCombo.stacks(p))
	for i in 6:
		_hit(foe, p)
	var mx := int(_num("combo", "max"))
	var per := _num("combo", "per")
	_expect(BendCombo.stacks(p) == mx and absf(BendStatus.cast_mult(p) - (1.0 - per * float(mx))) < 0.005,
			"seven hits: %d stacks, never past %d; his locks at %.2f of their time" % [BendCombo.stacks(p), mx, BendStatus.cast_mult(p)])
	await _ticks(12)
	var mc: Dictionary = ring.meters() if ring != null else {}
	_expect(float(mc.get("combo_a", 0.0)) > 0.5 and absf(float(mc.get("combo", 0.0)) - float(mx)) < 0.05,
			"the crosshair's combo bracket full (%s)" % str(mc))
	_hit(foe, p, {"no_hurt": true})
	_expect(BendCombo.stacks(p) == mx, "a tick (no_hurt) adds nothing and takes nothing")
	_hit(p, foe)
	_expect(BendCombo.stacks(p) == 0 and BendCombo.stacks(foe) == 1 and is_equal_approx(BendStatus.cast_mult(p), 1.0),
			"a hit taken: his combo gone, the hitter's a stack (%d, %d)" % [BendCombo.stacks(p), BendCombo.stacks(foe)])
	BendStatus.parry_reward(p, foe)
	BendStatus.spend_cast_mult(p)
	_expect(BendCombo.stacks(p) == 1, "a perfect guard: a stack (%d)" % BendCombo.stacks(p))
	for i in 4:
		_hit(foe, p)
	var full := BendCombo.level(p)
	await _secs(_num("combo", "grace_s") * 0.5)
	var held := BendCombo.level(p)
	await _secs(_num("combo", "grace_s") * 0.5 + 2.0)
	var drained := BendCombo.level(p)
	var want_lv := full - 2.0 * _num("combo", "drain_s")
	_expect(is_equal_approx(held, full) and absf(drained - want_lv) < 0.15 and BendStatus.cast_mult(p) > 1.0 - per * full,
			"it drains: %.2f held through its grace, %.2f two seconds after (want %.2f), his locks slower as it does" % [held, drained, want_lv])
	var cm: Dictionary = p.get_meta(BendCombo.COMBO_META)
	cm["at"] = BendStatus.now() - _num("combo", "grace_s") - float(mx) / _num("combo", "drain_s") - 0.1
	p.set_meta(BendCombo.COMBO_META, cm)
	_expect(BendCombo.stacks(p) == 0 and is_equal_approx(BendStatus.cast_mult(p), 1.0), "drained to none")
	await _secs(0.6)
	_expect(float((ring.meters() if ring != null else {}).get("combo_a", 1.0)) < 0.05, "and the crosshair's combo bracket gone")
	await _follow_up()
	_end()


## A knock-up's follow-up (BendCombo.knocked_up): his Spike's lock filled for 0.15 s before and after a Column knock-up of his
## lands, the window's moves, and its end.
func _follow_up() -> void:
	await _rest()
	BendCombo.reset(p)
	BendCombo.reset(foe)
	p.hotbar.ready_move(0, "stone_form", "spike")
	await _ticks(5)
	var fill_of := func() -> float:
		c.held_override = true
		await _secs(0.15)
		var f := c.fill
		c.held_override = false
		c.drop_all()
		await _until(func() -> bool: return c.state == SwayCaster.State.IDLE, 2.0)
		await _ticks(5)
		return f
	var f0: float = await fill_of.call()
	var kn := BendKnock.peek(foe)
	if kn != null:
		kn.reset()
	_hit(foe, p, {"tag": "earth_shove/column", "move": "earth_shove", "mode": "column"})
	var up := BendCombo.follow_on(p) and BendStatus.floating(foe)
	var k := _num("follow_up", "k")
	_expect(up and is_equal_approx(BendCombo.follow_share(p, "fire_blast", "punch"), 1.0 - k)
			and is_equal_approx(BendCombo.follow_share(p, "earth_shove", "column"), 1.0)
			and is_equal_approx(BendCombo.follow_share(p, "wave", "spout"), 1.0),
			"a Column knock-up of his lands: his other moves fill %.0f%% faster, his knock-ups never (the window %s)" % [k * 100.0, up])
	var f1: float = await fill_of.call()
	_expect(f0 > 0.0 and f1 / f0 > 1.0 / (1.0 - k) - 0.25, "his Spike fills %.2f in 0.15 s in the window (%.2f before)" % [f1, f0])
	await _until(func() -> bool: return not BendCombo.follow_on(p), 4.0)
	_expect(not BendCombo.follow_on(p) and is_equal_approx(BendCombo.follow_share(p, "fire_blast", "punch"), 1.0),
			"the window closes after the float")
