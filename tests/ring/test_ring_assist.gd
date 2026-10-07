extends SceneTree
## The Basic controls' helpers (RingAssist, round 4 SIMPLE; data/ring/assist.json) in a % ring match (rules stock), the
## player's keys driven through his own PlayerControls (set_held), the bot held still at its end:
##   recovery   each element put 4 m out off an end, 0.5 m under the lip, facing the deck: Space HELD brings him back (the
##              helper's double jump and Rise, the grab or the deck, never the water); mashing Space (a tap every 0.1 s) too;
##              nothing held: no help (he falls); thrown off the deck by a launch with Space held from the hit: back
##   toggles    recovery off: no press is his but his own (the raw double jump at once); steer on: a launch across the deck
##              with nothing held is steered toward the centre (BendKnock.steer_deg's sign), off: not at all; edge: the hang
##              climbs by itself at climb_after_s, held there with E, Space climbs (never the edge's jump)
##   never      under Full: no press, no steer, Space is his own; a bot: no helper can go on it (install refuses), none on any
##   untouched  through an assisted recovery the camera's yaw and pitch and its look are what they were (facing the deck:
##              MOVE's own recovery turn never starts), and no lock starts or changes
## Watchdog LIMIT_S; seed(1750); MatchSetup._aim_help pinned; GameSettings.path its own. Last line "RING ASSIST PASSED" or
## "RING ASSIST FAILED"; exit 0 only on a pass.
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_ring_assist.gd

const NAME := "RING ASSIST"
const LIMIT_S := 300.0
const OWN_CFG := "user://ring_assist_test.cfg"

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var rm: RingMoves
var a: RingAssist
var mode: RingMode
var ring: RingArena
var foe: NpcFighter
var c: SwayCaster
var moved: Array = []
var kos := 0
var _foe_at := Vector3.INF


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	MatchSetup._aim_help = "light"
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	InputSetup.ensure()
	MatchSetup.reload_scheme()
	MatchSetup.set_controls("basic")
	MatchSetup.incoming = true
	MatchSetup.kind = "match"
	MatchSetup.element = "earth"
	MatchSetup.foes = ["water"]
	MatchSetup.difficulty = "easy"
	RingRules.rule_set_override = "stock"
	physics_frame.connect(_hold_foe)
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _end() -> void:
	RingRules.rule_set_override = ""
	RingAssist.reload_data()
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		print("%s FAILED (%d of %d: %s)" % [NAME, fails.size(), checks, "; ".join(fails)])
		quit(1)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(s: float) -> void:
	await _ticks(int(round(s * Engine.physics_ticks_per_second)))


func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit:
		if cond.call():
			return t
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return INF


func _hold_foe() -> void:
	if foe != null and is_instance_valid(foe):
		foe.held = true
		if _foe_at == Vector3.INF:
			_foe_at = foe.global_position
		foe.global_position = _foe_at
		foe.velocity = Vector3.ZERO


func _run() -> void:
	for i in 600:
		await physics_frame
		mode = RingMode.find(self)
		p = mode.player if mode != null else null
		if p != null and p.arena_element != "" and mode.rules != null and SwayCaster.of(p) != null and mode.foe != null:
			break
	_expect(p != null and RingRules.stock_on(), "the % ring and its player")
	if p == null:
		return _end()
	await _until(func() -> bool: return mode.phase == "FIGHT", 8.0)
	foe = mode.foe
	ring = mode.ring
	c = SwayCaster.of(p)
	p.ignore_mouse_capture = true
	p.controls = PlayerControls.new(false)
	a = RingAssist.install(p)
	rm = RingMoves.of(p)
	await _ticks(2)
	rm.moved.connect(func(k: String) -> void: moved.append(k))
	mode.rules.ko.connect(func(b: Node3D, _by: Node, _pct: float, _tag: String, _left: int) -> void:
		if b == p:
			kos += 1)
	_expect(a != null and p.controls is RingAssist.AssistControls and a.active(), "RingAssist on the player, his keys wrapped, active under Basic")
	await _bots()
	await _recovery()
	await _launch_back()
	await _toggles()
	await _edge()
	await _full()
	_end()


# ---------------------------------------------------------------- places
func _geo() -> Dictionary:
	return RingMoves.arena_geo(ring)


## Off the -X end: `out` m past the lip, `under` m under it (feet), still, facing the deck.
func _put_off(out: float, under: float) -> void:
	var g := _geo()
	var xf: Transform3D = g.xf
	var lip: Vector3 = xf * Vector3(-float(g.hl), float(g.top), 0.0)
	var n: Vector3 = (xf.basis * Vector3(-1.0, 0.0, 0.0)).normalized()
	_place(lip + n * out - Vector3.UP * under, atan2(n.x, n.z))


func _place(pos: Vector3, yaw: float) -> void:
	p.controls.release_all()
	p.global_position = pos
	p.yaw = yaw
	p.rotation.y = yaw
	p.pitch = 0.0
	p.velocity = Vector3.ZERO
	var kn := BendKnock.peek(p)
	if kn != null:
		kn.reset()
		kn.stun_t = 0.0
		kn.lying_t = 0.0
	rm.placed()


func _back_on() -> void:
	var g := _geo()
	var xf: Transform3D = g.xf
	_place(xf * Vector3(-float(g.hl) + 6.0, float(g.top) + 0.05, 0.0), atan2(-1.0, 0.0))
	await _secs(0.6)
	await _until(func() -> bool: return mode.phase == "FIGHT" and not mode.rules.is_away(p), 8.0)
	p.controls.release_all()
	await _secs(0.3)


## Back on the deck or the edge (true), or the water / still falling (false), within `s`.
func _comes_back(s: float) -> bool:
	var k0 := kos
	var t := await _until(func() -> bool:
		return kos > k0 or rm.on_ledge() or (p.is_on_floor() and not rm.off_deck() and not rm.airborne()), s)
	return t < INF and kos == k0


func _presses() -> Dictionary:
	return (a.stats.presses as Dictionary).duplicate()


func _n(d: Dictionary, k: String) -> int:
	return int(d.get(k, 0))


# ---------------------------------------------------------------- cases
func _bots() -> void:
	var none := true
	for b in get_nodes_in_group(NpcFighter.GROUP):
		none = none and RingAssist.of(b) == null and RingAssist.install(b) == null
	_expect(none and foe != null, "a bot never takes a helper: none on any, install refuses one")


func _recovery() -> void:
	for el: String in ["earth", "water", "fire", "air"]:
		p.arena_element = el
		Bending.of(p).element = el
		await _back_on()
		var pr0 := _presses()
		_put_off(4.0, 0.5)
		moved.clear()
		var at0 := p.global_position
		var yaw0 := p.yaw
		var pitch0 := p.pitch
		var look0 := -p.camera.global_basis.z
		var still := true
		var lock0 := c.state
		var ready0 := c.readied_spell
		p.controls.set_held(&"jump", true)
		var back := false
		var k0 := kos
		for f in int(4.0 * Engine.physics_ticks_per_second):
			await physics_frame
			still = still and is_equal_approx(p.yaw, yaw0) and is_equal_approx(p.pitch, pitch0) \
					and (-p.camera.global_basis.z).angle_to(look0) < 0.01 and c.state == lock0 and c.readied_spell == ready0
			if kos > k0:
				break
			if rm.on_ledge() or (p.is_on_floor() and not rm.off_deck() and not rm.airborne()):
				back = true
				break
		p.controls.set_held(&"jump", false)
		var pr := _presses()
		var used := _n(pr, "double_jump") - _n(pr0, "double_jump") + _n(pr, "rise") - _n(pr0, "rise")
		_expect(back and kos == k0 and used >= 1, "%s: 4 m out, 0.5 m under the lip, Space held: back (%s), the helper pressed %d (%s; moved %s; from %s to %s)" % [
				el, "the edge" if rm.on_ledge() else ("the deck" if back else "NOT back"), used, pr, moved, at0, p.global_position])
		_expect(still, "%s: the camera's yaw, pitch and look and the caster's lock untouched through it" % el)
	# mashing: a tap every 0.1 s
	p.arena_element = "water"
	Bending.of(p).element = "water"
	await _back_on()
	_put_off(4.0, 0.5)
	var k1 := kos
	var back2 := false
	for f in int(4.0 * Engine.physics_ticks_per_second):
		p.controls.set_held(&"jump", f % 6 == 0)
		await physics_frame
		if kos > k1:
			break
		if rm.on_ledge() or (p.is_on_floor() and not rm.off_deck() and not rm.airborne()):
			back2 = true
			break
	p.controls.set_held(&"jump", false)
	_expect(back2, "water: mashing Space (a tap every 0.1 s) brings him back too")
	# nothing held: no help
	await _back_on()
	var pr1 := _presses()
	_put_off(4.0, 0.5)
	var k2 := kos
	await _until(func() -> bool: return kos > k2 or rm.on_ledge(), 4.0)
	var pr2 := _presses()
	_expect(kos > k2 and pr2.hash() == pr1.hash(), "nothing held: no press of the helper's, he falls in (%d)" % (kos - k2))


## Thrown off the deck by a launch, Space held from the hit: back.
func _launch_back() -> void:
	p.arena_element = "earth"
	Bending.of(p).element = "earth"
	await _back_on()
	var g := _geo()
	var xf: Transform3D = g.xf
	_place(xf * Vector3(-float(g.hl) + 3.0, float(g.top) + 0.05, 0.0), atan2(-1.0, 0.0))
	await _secs(0.3)
	var n: Vector3 = (xf.basis * Vector3(-1.0, 0.0, 0.0)).normalized()
	var k0 := kos
	BendKnock.of(p).knock(Vector3.ZERO, foe, {"_launch": {"v": n * 13.0 + Vector3.UP * 7.0, "hitstun_s": 0.55, "tumble": true}})
	p.controls.set_held(&"jump", true)
	await _secs(0.4)
	var off := rm.off_deck()
	var back := await _comes_back(5.0)
	p.controls.set_held(&"jump", false)
	_expect(off and back and kos == k0, "launched off the end at 14.8 m/s, Space held from the hit: off the deck (%s), back (%s)" % [off, back])


func _toggles() -> void:
	# recovery off: no press of the helper's; Space is his own (the double jump at once)
	await _back_on()
	(RingAssist.data().recovery as Dictionary)["on"] = false
	var pr0 := _presses()
	moved.clear()
	_put_off(4.0, 0.5)
	await _ticks(3)
	p.controls.set_held(&"jump", true)
	await _ticks(2)
	var dj := moved.has("double_jump")
	await _secs(0.5)
	p.controls.set_held(&"jump", false)
	_expect(_presses().hash() == pr0.hash() and dj, "recovery off: no press of the helper's; Space is his own again (the double jump at once: %s)" % dj)
	(RingAssist.data().recovery as Dictionary)["on"] = true
	await _until(func() -> bool: return kos > 0 and not rm.off_deck(), 6.0)
	# the steer: a launch along the deck's length with a sideways part, nothing held
	var degs := {}
	for st: String in ["on", "off"]:
		(RingAssist.data().steer as Dictionary)["on"] = st == "on"
		await _back_on()
		var g := _geo()
		var xf: Transform3D = g.xf
		_place(xf * Vector3(0.0, float(g.top) + 0.05, -4.0), 0.0)
		await _secs(0.3)
		var v: Vector3 = xf.basis * Vector3(9.0, 6.0, 0.0)
		BendKnock.of(p).knock(Vector3.ZERO, foe, {"_launch": {"v": v, "hitstun_s": 0.5, "tumble": true}})
		await _secs(0.25)
		degs[st] = BendKnock.peek(p).steer_deg
		await _until(func() -> bool: return p.is_on_floor() and not rm.airborne(), 4.0)
	(RingAssist.data().steer as Dictionary)["on"] = true
	# toward the centre from z = -4 along +x: the centre is to the launch's left (+z side): a positive yaw of the flat way
	var sign_ok := absf(float(degs.on)) > 1.0 and signf(float(degs.on)) == signf(_toward_centre_sign())
	_expect(sign_ok and absf(float(degs.off)) < 1e-3, "steer on: a launch across the deck with nothing held is steered toward the centre (%.1f deg); off: %.1f deg" % [float(degs.on), float(degs.off)])


## The sign of steer_deg that turns the flat way +x (deck frame) toward the centre from z = -4: the cross of the launch's
## way and the way to the centre (BendKnock.apply_di's own sign rule).
func _toward_centre_sign() -> float:
	var xf: Transform3D = _geo().xf
	var f: Vector3 = (xf.basis * Vector3(1.0, 0.0, 0.0)).normalized()
	var d: Vector3 = (xf.basis * Vector3(0.0, 0.0, 1.0)).normalized()
	return signf(f.cross(d).y)


func _edge() -> void:
	# grab: put where the grab box takes him, falling
	for case: String in ["auto", "held", "space"]:
		await _back_on()
		moved.clear()
		_put_off(0.45, 1.55)
		var t_grab := await _until(func() -> bool: return rm.on_ledge(), 2.0)
		if t_grab == INF:
			_expect(false, "edge %s: he grabs the edge" % case)
			continue
		match case:
			"auto":
				var t := await _until(func() -> bool: return moved.has("climb"), 1.5)
				_expect(t < INF and absf(t - RingAssist.num("edge", "climb_after_s", 0.4)) < 0.1 and not moved.has("ledge_jump"),
						"edge: it climbs by itself %.2f s after the grab (climb_after_s %.2f)" % [t, RingAssist.num("edge", "climb_after_s", 0.4)])
			"held":
				p.controls.set_held(InputSetup.GUARD_ACTION, true)
				await _secs(1.0)
				var hanging := rm.on_ledge() and not moved.has("ledge_roll") and not moved.has("climb")
				p.controls.set_held(InputSetup.GUARD_ACTION, false)
				var t2 := await _until(func() -> bool: return moved.has("climb"), 1.0)
				_expect(hanging and t2 < INF, "edge: E held keeps him hanging (no roll in: %s), let go he climbs" % hanging)
			"space":
				await _secs(0.17)
				p.controls.set_held(&"jump", true)
				var t3 := await _until(func() -> bool: return moved.has("climb") or moved.has("ledge_jump"), 0.5)
				p.controls.set_held(&"jump", false)
				_expect(t3 < 0.15 and moved.has("climb") and not moved.has("ledge_jump"), "edge: Space climbs at once (%.2f s), never the edge's jump" % t3)
		await _secs(0.8)


func _full() -> void:
	MatchSetup.set_controls("full")
	await _back_on()
	var pr0 := _presses()
	moved.clear()
	_put_off(4.0, 0.5)
	await _ticks(3)
	p.controls.set_held(&"jump", true)
	await _ticks(2)
	var dj := moved.has("double_jump")
	await _secs(1.0)
	p.controls.set_held(&"jump", false)
	_expect(not a.active() and _presses().hash() == pr0.hash() and dj, "Full: no helper (active %s), no press of its, Space is his own (the double jump at once: %s)" % [a.active(), dj])
	await _until(func() -> bool: return kos > 0 and not rm.off_deck(), 6.0)
	# the steer under Full: none
	await _back_on()
	var g := _geo()
	var xf: Transform3D = g.xf
	_place(xf * Vector3(0.0, float(g.top) + 0.05, -4.0), 0.0)
	await _secs(0.3)
	BendKnock.of(p).knock(Vector3.ZERO, foe, {"_launch": {"v": xf.basis * Vector3(9.0, 6.0, 0.0), "hitstun_s": 0.5, "tumble": true}})
	await _secs(0.25)
	_expect(absf(BendKnock.peek(p).steer_deg) < 1e-3, "Full: no steer with nothing held (%.2f deg)" % BendKnock.peek(p).steer_deg)
	await _until(func() -> bool: return p.is_on_floor() and not rm.airborne(), 4.0)
	# Full's edge: nothing climbs by itself
	await _back_on()
	moved.clear()
	_put_off(0.45, 1.55)
	await _until(func() -> bool: return rm.on_ledge(), 2.0)
	await _secs(1.0)
	_expect(rm.on_ledge() and not moved.has("climb"), "Full: the hang never climbs by itself (still hanging after 1 s)")
	p.controls.set_held(&"jump", true)
	await _secs(0.3)
	p.controls.set_held(&"jump", false)
	_expect(moved.has("ledge_jump"), "Full: Space on the edge is the edge's jump")
	MatchSetup.set_controls("basic")
