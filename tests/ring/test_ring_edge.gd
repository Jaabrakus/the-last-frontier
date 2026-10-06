extends SceneTree
## Round 3 MOVE (smash_r3 spec §5.3-5.4, §15): the deck's edge, headless, on the rig's test deck (tests/ring/r3_move_rig.gd: the
## bare ring's player, far off a % ring-shaped deck with a RingMoves on him; bots with theirs).
##   the grab     inside the box (0.5 m out) he grabs; 1.3 m out, with C held, in hitstun he does not; the snap faces the deck
##                (feet 2.0 m under the lip, 0.35 m off its face), the camera's yaw unchanged
##   three grabs  three grabs without the deck (a ledge jump and back each time), the fourth fails: a slide down the face
##   the hang     0.6 s intangible on the first grab, none on a regrab; let go at 4 s; no regrab for 0.4 s after letting go
##   the keys     deck-relative: with the camera at 0, 90 and 180 degrees to the lip each of W/A/S/D climbs, none lets go;
##                C lets go
##   the options  climb (0.6 m in), roll in (3.0 m in), jump (the feet to about lip +1.5, the double jump kept), the edge
##                attack (strikes a body 1.5 m in); each intangible window exact to a physics frame
##   occupancy    no grab within 1.2 m of a hanger (a bot), a grab at 1.5 m; a corner's grab slides 0.5 m along
##   the wave     a floor wave across the lip strikes a hanger only once his 0.6 s is over
## METRIC lines: edge_keys_deck_relative_ok, grab_limit_ok, edge_occupancy_ok, edge_windows. Last line "RING EDGE PASSED" or
## "RING EDGE FAILED".
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_ring_edge.gd

const NAME := "RING EDGE"
const WATCHDOG_S := 600.0
const OWN_CFG := "user://ring_edge_test.cfg"
const Rig := preload("res://tests/ring/r3_move_rig.gd")
## Facing the deck from the -X lip (+X).
const TO_DECK := -PI * 0.5

var checks := 0
var fails: Array[String] = []
var rig: Rig
var p: FrontierPlayer
var rm: RingMoves
var bot: NpcFighter
var seen: Array[String] = []


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	MatchSetup._aim_help = "strong"
	seed(1750)
	create_timer(WATCHDOG_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	SwayCaster.free_override = true
	InputSetup.ensure()
	_run.call_deferred()


func _run() -> void:
	rig = Rig.new(self)
	var ok: bool = await rig.setup("water")
	_expect(ok, "the rig")
	if not ok:
		_end()
		return
	p = rig.p
	rm = rig.pm
	rm.moved.connect(func(k: String) -> void: seen.append(k))
	await _grab()
	await _three()
	await _hang()
	await _keys()
	await _options()
	await _occupancy()
	await _wave()
	_end()


func _end() -> void:
	RingMoves.geo_override = {}
	SwayCaster.free_override = false
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


# ---------------------------------------------------------------- helpers
## `b` dropped from 0.3 m over the lip, `out` m past the -X lip at `z`, facing `yaw`; the frames until he hangs (INF: never,
## within `limit`).
func _drop(b: Node3D, out: float, z := 0.0, yaw := TO_DECK, limit := 1.0) -> float:
	if b == p:
		rig.release_all()
	rig.place(b, Vector3(rig.lip(z).x - out, Rig.D.y + 0.3, rig.lip(z).z), yaw)
	var m := RingMoves.of(b)
	return await rig.until(func() -> bool: return m.on_ledge(), limit)


## Back on the deck, still.
func _reset() -> void:
	rig.release_all()
	rig.place(p, rig.at(8.0), TO_DECK)
	p.pitch = 0.0
	await rig.secs(0.2)


## When `cond` holds, frame by frame, for `s` seconds from now: [first, last] (s from now; [-1, -1] never).
func _window(cond: Callable, s: float) -> Array:
	var first := -1.0
	var last := -1.0
	var hz := float(Engine.physics_ticks_per_second)
	for i in int(round(s * hz)):
		await physics_frame
		var t := float(i + 1) / hz
		if cond.call():
			if first < 0.0:
				first = t
			last = t
	return [first, last]


# ---------------------------------------------------------------- the grab
func _grab() -> void:
	var yaw0 := TO_DECK
	var g := await _drop(p, 0.5)
	var lip := rig.lip(0.0)
	var feet := p.global_position - lip
	_expect(g < INF and seen.has("grab") and absf(feet.y + 2.0) < 0.01 and absf(feet.x + 0.35) < 0.01,
			"0.5 m out, falling: he grabs, his feet snapped 2.0 m under the lip, 0.35 m off its face (%s)" % feet)
	_expect(absf(wrapf(p.rotation.y - rm.body_yaw(), -PI, PI)) < 0.01 and absf(rm.body_yaw() - (-PI * 0.5)) < 0.01
			and absf(p.yaw - yaw0) < 1e-5, "the snap faces the deck; the camera's yaw unchanged")
	await _reset()
	_expect(await _drop(p, 1.3, 0.0, TO_DECK, 0.8) == INF, "1.3 m out: no grab")
	await _reset()
	rig.place(p, Vector3(rig.lip(0.0).x - 0.5, Rig.D.y + 0.3, Rig.D.z), TO_DECK)
	rig.hold(&"crouch", true)
	var with_c := await rig.until(func() -> bool: return rm.on_ledge(), 0.8)
	rig.hold(&"crouch", false)
	_expect(with_c == INF, "C held: no grab")
	await _reset()
	rig.place(p, Vector3(rig.lip(0.0).x - 0.5, Rig.D.y + 0.3, Rig.D.z), TO_DECK)
	BendKnock.of(p).stun_t = 1.5
	var stunned := await rig.until(func() -> bool: return rm.on_ledge(), 0.8)
	BendKnock.of(p).stun_t = 0.0
	_expect(stunned == INF, "in hitstun: no grab")
	await _reset()


## From the hang: let go (C), wait out the regrab block, and fall into the grab box again from just over it (the planker's
## drop and regrab; never on the deck between): true when he hangs again.
func _jump_back() -> bool:
	rig.tap(&"crouch")
	await rig.secs(0.42)
	# (his head just over the lip, in the box: within physics.teleport_m of where he fell to, so his state is his own)
	rig.place_keep(p, Vector3(rig.lip(0.0).x - 0.5, Rig.D.y - 1.3, Rig.D.z))
	return await rig.until(func() -> bool: return rm.on_ledge(), 0.8) < INF


func _three() -> void:
	await _reset()
	var g1 := await _drop(p, 0.5) < INF
	await rig.secs(0.3)
	var g2: bool = await _jump_back()
	await rig.secs(0.3)
	var g3: bool = await _jump_back()
	await rig.secs(0.3)
	var safe3 := rm.ledge_safe_left()
	var g4: bool = await _jump_back()
	var grabs := rm._grabs
	print("METRIC grab_limit_ok %s (grabs %s %s %s, the fourth %s; grabs counted %d)" % [g1 and g2 and g3 and not g4, g1, g2, g3, g4, grabs])
	_expect(g1 and g2 and g3 and not g4 and grabs == 3 and safe3 == 0.0,
			"three grabs without the deck (regrabs not safe: %.2f s), the fourth fails (%s %s %s %s)" % [safe3, g1, g2, g3, g4])
	await _reset()
	_expect(rm._grabs == 0, "the deck clears the count")


# ---------------------------------------------------------------- the hang
func _hang() -> void:
	await _reset()
	await _drop(p, 0.5)
	var safe := rm.ledge_safe_left()
	var w: Array = await _window(func() -> bool: return rm.intangible(), 1.0)
	_expect(absf(safe - 0.6) < 0.02 and w[0] > 0.0 and absf(float(w[1]) - 0.6) < 0.02,
			"the first grab: intangible 0.6 s (%.2f; %s)" % [safe, str(w)])
	var held := await rig.until(func() -> bool: return not rm.on_ledge(), 4.0)
	_expect(absf(held + 1.0 - 4.0) < 0.05 and rm.mode == "", "let go at 4 s (%.2f s after the window)" % (held + 1.0))
	# no regrab for 0.4 s after letting go (C), a grab after
	await _reset()
	await _drop(p, 0.5)
	await rig.secs(0.3)
	rig.tap(&"crouch")
	await rig.secs(0.15)
	var hang_feet := rig.lip(0.0) + Vector3(-0.35, -2.0, 0.0)
	rig.place_keep(p, hang_feet + Vector3(0.0, 0.3, 0.0))
	var early := await rig.until(func() -> bool: return rm.on_ledge(), 0.12)
	await rig.secs(0.2)
	rig.place_keep(p, hang_feet + Vector3(0.0, 0.3, 0.0))
	var later := await rig.until(func() -> bool: return rm.on_ledge(), 0.4)
	_expect(early == INF and later < INF, "letting go (C): no regrab within 0.4 s, a grab after")
	await _reset()


# ---------------------------------------------------------------- the keys: deck-relative
func _keys() -> void:
	var all_ok := true
	var bad: Array = []
	for deg: float in [0.0, 90.0, 180.0]:
		for key: StringName in [&"move_forward", &"move_left", &"move_back", &"move_right"]:
			await _reset()
			if await _drop(p, 0.5, 0.0, TO_DECK + deg_to_rad(deg)) == INF:
				bad.append("%d %s: no grab" % [deg, key])
				all_ok = false
				continue
			await rig.secs(0.2)
			seen.clear()
			rig.tap(key)
			await rig.secs(0.7)
			var climbed := seen.has("climb") and p.is_on_floor() and p.global_position.x > rig.lip(0.0).x
			if not climbed:
				all_ok = false
				bad.append("%d %s: %s" % [deg, key, str(seen)])
	await _reset()
	await _drop(p, 0.5, 0.0, TO_DECK + PI)
	await rig.secs(0.2)
	rig.tap(&"crouch")
	await rig.secs(0.05)
	var let_go := not rm.on_ledge() and rm.mode == ""
	print("METRIC edge_keys_deck_relative_ok %s" % (all_ok and let_go))
	_expect(all_ok, "the camera at 0, 90 and 180 degrees to the lip: each of W/A/S/D climbs, none lets go%s" % ("" if bad.is_empty() else " " + str(bad)))
	_expect(let_go, "C lets go")
	await _reset()


# ---------------------------------------------------------------- the options
func _options() -> void:
	var report := {}
	# climb: 0.6 m in, intangible 0-0.35
	await _reset()
	await _drop(p, 0.5)
	await rig.secs(0.7)
	rig.tap(&"move_forward")
	var wc: Array = await _window(func() -> bool: return rm.intangible(), 0.8)
	var cin := p.global_position.x - rig.lip(0.0).x
	report["climb"] = [wc, snappedf(cin, 0.01)]
	_expect(absf(cin - 0.6) < 0.02 and p.is_on_floor() and absf(float(wc[1]) - 0.35) < 0.01 and float(wc[0]) <= 0.01,
			"climb: stands 0.6 m in (%.2f), intangible to 0.35 s (%s)" % [cin, str(wc)])
	# roll in: 3.0 m in, intangible 0-0.55
	await _reset()
	await _drop(p, 0.5)
	await rig.secs(0.7)
	rig.tap(InputSetup.GUARD_ACTION)
	var wr: Array = await _window(func() -> bool: return rm.intangible(), 1.0)
	var rin := p.global_position.x - rig.lip(0.0).x
	report["roll"] = [wr, snappedf(rin, 0.01)]
	_expect(absf(rin - 3.0) < 0.02 and absf(float(wr[1]) - 0.55) < 0.01, "roll in: 3.0 m in (%.2f), intangible to 0.55 s (%s)" % [rin, str(wr)])
	# jump: the feet to about lip +1.5, the double jump kept, intangible 0-0.12
	await _reset()
	await _drop(p, 0.5)
	await rig.secs(0.7)
	rig.tap(&"jump")
	var top := -INF
	var wj := [-1.0, -1.0]
	var hz := float(Engine.physics_ticks_per_second)
	for i in int(1.2 * hz):
		await physics_frame
		top = maxf(top, p.global_position.y - Rig.D.y)
		if rm.intangible():
			if float(wj[0]) < 0.0:
				wj[0] = float(i + 1) / hz
			wj[1] = float(i + 1) / hz
		if i > 20 and p.is_on_floor():
			break
	report["jump"] = [wj, snappedf(top, 0.01)]
	_expect(absf(top - 1.5) < 0.1 and rm.jumps_left == 1 and absf(float(wj[1]) - 0.12) < 0.01,
			"ledge jump: the feet to %.2f m over the lip (about 1.5), the double jump kept, intangible to 0.12 s (%s)" % [top, str(wj)])
	# the edge attack: strikes a body 1.5 m in, intangible 0-0.30
	await _reset()
	if bot == null:
		bot = await rig.bot("earth", rig.at(12.0, 4.0), 0.0)
	await _drop(p, 0.5)
	rig.place(bot, rig.at(1.5, 0.0), PI * 0.5)
	await rig.secs(0.7)
	var bk := BendKnock.of(bot)
	var n0 := bk.knocks
	rig.tap(&"fire")
	var wa: Array = await _window(func() -> bool: return rm.intangible(), 0.8)
	report["attack"] = [wa, bk.knocks - n0]
	_expect(bk.knocks > n0 and absf(float(wa[1]) - 0.30) < 0.01 and p.is_on_floor(),
			"the edge attack strikes a body 1.5 m in, intangible to 0.30 s (%s), on the deck after" % str(wa))
	print("METRIC edge_windows %s" % str(report))
	rig.place(bot, rig.at(12.0, 4.0), 0.0)
	await _reset()


# ---------------------------------------------------------------- occupancy and corners
func _occupancy() -> void:
	if bot == null:
		bot = await rig.bot("earth", rig.at(12.0, 4.0), 0.0)
	await _reset()
	var bg := await _drop(bot, 0.5, 0.0, TO_DECK)
	var near := await _drop(p, 0.5, 1.0, TO_DECK, 0.8)
	await _reset()
	var at15 := await _drop(p, 0.5, 1.5, TO_DECK, 0.8)
	var ok := bg < INF and near == INF and at15 < INF
	print("METRIC edge_occupancy_ok %s" % ok)
	_expect(ok, "a bot hangs; the player can't grab 1.0 m from him, can at 1.5 m (no trumping)")
	rig.place(bot, rig.at(12.0, 4.0), 0.0)
	await _reset()
	# a corner: the grab slides corner_m along
	var hw := float(rig.geo.hw)
	var cg := await _drop(p, 0.5, hw - 0.2, TO_DECK)
	var z := p.global_position.z - Rig.D.z
	_expect(cg < INF and absf(z - (hw - 0.5)) < 0.01, "near a corner the grab slides to 0.5 m from it (z %.2f)" % z)
	await _reset()


# ---------------------------------------------------------------- the floor wave over the lip
func _wave() -> void:
	if bot == null:
		bot = await rig.bot("earth", rig.at(12.0, 4.0), 0.0)
	rig.place(bot, rig.at(12.0, 4.0), 0.0)
	var res: Array = []
	for at_s: float in [0.3, 0.9]:
		await _reset()
		await _drop(p, 0.5)
		var kn := BendKnock.of(p)
		var n0 := kn.knocks
		var from := rig.at(4.0, 0.0)
		var mps := 12.0
		var fly := 4.35 / mps
		await rig.secs(maxf(at_s - fly, 0.0))
		BendBolt.launch(bot, from, Vector3(-1.0, 0.0, 0.0), {"do": "floor_wave", "kind": "fire", "mps": mps, "width_m": 2.2,
				"height_m": 0.9, "miss_above_m": 0.6, "range_m": 8.0, "damage": 10.0, "knock_mps": 4.0, "up_mps": 2.0})
		await rig.secs(fly + 0.25)
		res.append(kn.knocks > n0)
	_expect(not bool(res[0]) and bool(res[1]), "a floor wave over the lip: no hit at 0.3 s into the hang, a hit at 0.9 s (%s)" % str(res))
	await _reset()
