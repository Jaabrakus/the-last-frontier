extends SceneTree
## The element round the body while a move charges, in place of the circle (BendCharge; the owner, 2026-10-12: "instead of
## the spell circle we need to animate like in avatar the element charging and bending around their body"), in Tidebreak's
## ring (scenes/ring.tscn, MatchSetup.incoming, earth against water), the foe held:
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_bend_charge.gd
##   the lock     key 2 (Fissure) held, a broken piece lying 2 m off: earth round the player's body (FormCast.charge, its
##                element, on him), no circle; the piece pulled in (RockDebris); channelled to the hand the clip strikes
##                with; its fill follows the lock's; full when the lock is
##   the cast     let go: it ends as a cast and is gone soon after, the piece used
##   a fizzle     let go early: it ends as a fizzle and is gone, the piece it took lying on the deck again
##   the wall     key 4 (Earth Wall, the Form art's move): earth round the body too, no circle anywhere; its cast ends it
##   a bot        the foe let go: its lock gathers its own element (water) round its own body, no circle, its clip's limb
##   a kick       the match again as fire: the Kick held channels fire to the kicking foot
## Out of the ring the open world's circles stay (tests/sway/test_form.gd, test_wall_matter.gd). Headless nothing is drawn
## (BendLooks.live); the fill, the ending and the freeing are what is checked.
## The last line "BEND CHARGE PASSED (<n> checks)" or "BEND CHARGE FAILED (<f> of <n>)".

const LIMIT_S := 150.0

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var c: SwayCaster
var rm: RingMode


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("BEND CHARGE FAILED (watchdog)")
		quit(2))
	MatchSetup.incoming = true
	MatchSetup.format = "1v1"
	MatchSetup.element = "earth"
	MatchSetup.foes = ["water"]
	SwayCaster.free_override = true
	RingReplay.force = "off"
	InputSetup.ensure()
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _until(cond: Callable, s: float) -> bool:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await physics_frame
	return bool(cond.call())


## Action `a` pressed and let go (through Input: the player's _unhandled_input hears it as a key's).
func _action(a: StringName) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = a
		e.pressed = down
		Input.parse_input_event(e)
		await _ticks(3)


func _charges() -> Array:
	return get_nodes_in_group(BendCharge.GROUP).filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())


func _circles() -> Array:
	return get_nodes_in_group(FormCircle.GROUP).filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())


func _run() -> void:
	for i in 20:
		await process_frame
	var lvl := current_scene as RingLevel
	p = lvl.player if lvl != null else null
	_expect(p != null, "the ring and its player")
	if p == null:
		return _end()
	p.ignore_mouse_capture = true
	c = SwayCaster.of(p)
	rm = RingMode.find(self)
	var fight := await _until(func() -> bool: return rm.phase == "FIGHT" and p.hotbar.spell != "", 10.0)
	_expect(fight and BendR3.on(p), "the fight on, the player in the ring (BendR3.on)")
	if rm.foe != null:
		rm.foe.held = true
	# ---- the lock (a broken piece lying near: the charge pulls it in)
	var deb := RockDebris.of(current_scene)
	_piece(deb, p.global_position + Vector3(2.0, 0.05, 0.0))
	_expect(deb.count() == 1, "a broken piece lies on the deck 2 m off (%d)" % deb.count())
	await _action(&"weapon_2")
	await _ticks(20)
	c.held_override = true
	var locking := await _until(func() -> bool: return c.state != SwayCaster.State.IDLE, 2.0)
	await _ticks(6)
	var ch: BendCharge = c.form.charge
	_expect(locking and c.move == "earth_shove" and ch != null and is_instance_valid(ch) and ch.element == "earth" and ch.body == p,
			"key 2 held: earth gathered round the player's body (%s, %s)" % [c.move, ch.element if ch != null else "none"])
	_expect(_circles().is_empty() and c.form.circle == null, "no circle on the ground (%d)" % _circles().size())
	_expect(ch != null and ch.claimed.size() == 1 and deb.count() == 0,
			"the charge pulled the piece in (%d taken, %d lying)" % [ch.claimed.size() if ch != null else -1, deb.count()])
	_expect(ch != null and ch.limb() in ["r_palm", "l_palm"],
			"channelled to the hand the Fissure's clip strikes with (%s)" % (ch.limb() if ch != null else "none"))
	await _ticks(10)
	_expect(ch != null and is_instance_valid(ch) and absf(ch.fill - c.fill) < 0.06 and ch.fill > 0.0,
			"its fill follows the lock's (%.2f, the lock %.2f)" % [ch.fill if ch != null else -1.0, c.fill])
	var full := await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 4.0)
	await _ticks(2)
	_expect(full and ch != null and is_instance_valid(ch) and ch.full, "full when the lock is")
	# ---- the cast
	c.held_override = false
	await _ticks(4)
	_expect(ch != null and is_instance_valid(ch) and ch.ending == "cast" and c.form.charge == null,
			"let go: it ends as a cast (%s)" % (ch.ending if ch != null and is_instance_valid(ch) else "gone"))
	var gone := await _until(func() -> bool: return _charges().is_empty(), 2.0)
	_expect(gone and deb.count() == 0, "and is gone soon after, the piece used (%d left, %d lying)" % [_charges().size(), deb.count()])
	await _ticks(40)
	# ---- a fizzle (its piece falls back to the deck)
	_piece(deb, p.global_position + Vector3(-1.5, 0.05, 1.0))
	c.held_override = true
	locking = await _until(func() -> bool: return c.state != SwayCaster.State.IDLE and c.fill > 0.15, 2.0)
	ch = c.form.charge
	var took := ch.claimed.size() if ch != null and is_instance_valid(ch) else -1
	c.held_override = false
	await _ticks(4)
	_expect(locking and ch != null and is_instance_valid(ch) and ch.ending in ["fizzle", "break"],
			"let go early: it ends as a fizzle (%s)" % (ch.ending if ch != null and is_instance_valid(ch) else "gone"))
	gone = await _until(func() -> bool: return _charges().is_empty(), 2.0)
	_expect(gone and took == 1 and deb.count() == 1,
			"and is gone, the piece it took lying again (%d taken, %d lying)" % [took, deb.count()])
	await _ticks(40)
	# ---- a raised piece (the Earth Wall: the Form art's move, its lock under the caster in the ring)
	await _action(&"weapon_4")
	await _ticks(20)
	c.held_override = true
	locking = await _until(func() -> bool: return c.state != SwayCaster.State.IDLE, 2.0)
	await _ticks(6)
	ch = c.form.charge
	_expect(locking and c.move == "earth_wall" and ch != null and is_instance_valid(ch) and ch.element == "earth"
			and _circles().is_empty() and _charges().size() == 1,
			"key 4 (Earth Wall): earth round the body, no circle anywhere (%d circles, %d charges)" % [_circles().size(), _charges().size()])
	await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 4.0)
	c.held_override = false
	await _ticks(4)
	_expect(ch != null and is_instance_valid(ch) and ch.ending == "cast", "its cast ends it")
	c.held_override = null
	await _until(func() -> bool: return _charges().is_empty(), 2.0)
	# ---- a bot
	var f := rm.foe as NpcFighter
	if f == null or f.brain == null or f.brain.bending == null:
		_expect(false, "the foe bends")
		return _end()
	var b := f.brain.bending
	f.held = false
	var cast := await _until(func() -> bool: return b.casting != "" and b.charge != null and is_instance_valid(b.charge), 12.0)
	var bc: BendCharge = b.charge
	_expect(cast and bc.element == "water" and bc.body == f and b.circle == null and bc.limb() in BendCharge.LIMBS,
			"the foe's lock: water gathered round its own body, no circle, its limb its clip's (%s, %s)"
			% [b.casting if cast else "no lock", bc.limb() if cast else "-"])
	f.held = true
	# ---- a kick: fire's Kick channelled to the kicking foot
	MatchSetup.element = "fire"
	rm.restart()
	var again := await _until(func() -> bool: return rm.phase == "FIGHT" and p.arena_element == "fire" and p.hotbar.spell != "", 10.0)
	if rm.foe != null:
		rm.foe.held = true
	await _action(&"weapon_2")
	await _ticks(20)
	c.held_override = true
	locking = await _until(func() -> bool: return c.state != SwayCaster.State.IDLE, 2.0)
	await _ticks(8)
	ch = c.form.charge
	_expect(again and locking and c.move == "fire_kick" and ch != null and is_instance_valid(ch) and ch.element == "fire"
			and ch.limb() in ["r_foot", "l_foot"],
			"fire's Kick held: fire channelled to the kicking foot (%s, %s)" % [c.move, ch.limb() if ch != null else "none"])
	c.held_override = false
	_end()


## A broken piece lying at `at` (as a burst stone leaves them: RockDebris).
func _piece(deb: RockDebris, at: Vector3) -> void:
	var m := MeshInstance3D.new()
	current_scene.add_child(m)
	m.global_position = at
	deb.lay(m)


func _end() -> void:
	if c != null:
		c.held_override = null
	if fails.is_empty() and checks > 0:
		print("BEND CHARGE PASSED (%d checks)" % checks)
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("BEND CHARGE FAILED (%d of %d)" % [fails.size(), checks])
		quit(1)
