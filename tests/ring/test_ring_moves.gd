extends SceneTree
## Round 3 MOVE (smash_r3 spec §4, §5.4, §3.2-3.4's motion, §15): the % ring's movement set on the player and a bot, headless.
## The rig (tests/ring/r3_move_rig.gd): the bare ring's player (his caster), far off a test deck of the % ring's shape (34 x 14 m,
## its top at y 0, solid 9 m down; the water's level 6 m under the lip, the curtain 10 m out: RingMoves.geo_override), a
## RingMoves on him (the gate per body) and keyboard-free controls.
##   jumps     taps of 0.08 and 0.10 s and a 0.5 s hold all reach 2.0 +- 0.05 m; Space 0.03 s after a cast's release and a
##             release 0.03 s after Space both 0.8 +- 0.05 m; the double jump 1.6 m (earth 1.4, air 1.9) halving the launch's
##             carry; a third Space over the deck nothing; off it (0.2 s on) the Rise; walking off, the first Space the double
##   masher    Space every 60 ms against nothing at all, 12 launches off the deck at 120% (the Lash's speed x the weight, 25
##             and 40 degrees, 1-5 m inside two lips), each element: it comes back at least as often (RingMoves.simulate)
##   sim       the simulation and the engine trace the same jump, double jump and Rise within 2 cm
##   recovery  all four Rises return casting/full steering and an unused dodge; spent resources stay spent;
##             0.35 s of recovery landing lag remains, then resources refresh
##   refresh   a tumbling launch gives every air move back, a set knock nothing
##   dodge     3.2 +- 0.1 m; a bolt through him at 0.15 s flies on unspent, one at 0.40 s hits; a second 3 nothing; landing in it
##             0.3 s of lag
##   fast fall C after the apex: -17 m/s held with C let go; before the apex nothing; it ends the glide
##   roll/duck a fresh A rolls 3.5 m (facing kept); W held before E does not; from 1 m inside the end's and the side's lip it
##             ends 0.3 m inside; the duck intangible at 0.1 s; a repeat within 1.0 s 0.1 s longer
##   guard     with the guard held, Space jumps on that frame
##   teeter    running into the lip stops; 0.3 s toward the water steps off (an end, a long side); a knock carries over at once
##   rise      heights within 0.2 m (earth 5.5 along a 20 degree lean toward the lip, water 4.5, air 3.5; fire 7.5 along the aim,
##             a level aim lifted to +20); the scramble from 1.8 m under the grab box reaches the hang, from 2.4 m not; the
##             Pillar strikes a body over him; the glide no faster than 3 m/s; a self-launch from the deck uses up the Rise
##   hitstun   a press at 0.4 s waits for hitstun's end; a fresh press at 0.65 s ends it (the escape); the steer leans him
##   break     broken falls: stand (intangible), roll 2.5 m (never off the lip), wall (spring off); lying: up, roll, attack
##   sounds    the whoosh while in hitstun, cut on the free frame; the tick at 0.6 s; his own only (a bot's hears none)
##   parity    the player and a bot given the same intents trace the same path within 1 cm over 2 s
##   camera    deck arm 5.25 m (pivot +0.3) with the ring camera's variant on top (round 4, RingCamera); off the deck at lip -5 m, 4 m out facing the deck: body and lip in the viewport;
##             facing away with the mouse still: both in it within 1.2 s; with the mouse moving the yaw untouched; a knock
##             never moves yaw or pitch; the spout faces the deck's middle
##   spout     held there; a jump, a cast key or its time lets go (left_spout)
## METRIC lines (hop_apex_m, short_hop_apex_m, double_jump_m, dj_carry_keep, air_dodge_m, rise_m, masher_vs_idle, parity_cm,
## sim_vs_engine_cm, camera_ok, recover_turn_ok, deck_behind_m). Last line "RING MOVES PASSED" or "RING MOVES FAILED".
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_ring_moves.gd -- only=recovery,rises,refresh,hitstun,fast_fall

const NAME := "RING MOVES"
const WATCHDOG_S := 600.0
const OWN_CFG := "user://ring_moves_test.cfg"
const Rig := preload("res://tests/ring/r3_move_rig.gd")
const ELS := ["earth", "water", "fire", "air"]

var checks := 0
var fails: Array[String] = []
var rig: Rig
var p: FrontierPlayer
var rm: RingMoves
var moves_seen: Array[String] = []
var bot: NpcFighter
var _hold_at := Vector3.INF
var only: Array[String] = []


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			only.assign(arg.trim_prefix("only=").split(",", false))
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
	_expect(ok, "the rig: the bare ring's player on the test deck with a RingMoves (player.ring_moves set)")
	if not ok:
		_end()
		return
	p = rig.p
	rm = rig.pm
	_expect(p.ring_moves == rm and p.traversal == null and p.grip == null, "the arena player: ring_moves his, no traversal or grip")
	rm.moved.connect(func(k: String) -> void: moves_seen.append(k))
	physics_frame.connect(_hold_tick)
	var parts := {"jumps": _jumps, "masher": _masher, "sim": _sim_vs_engine, "recovery": _recovery_control,
			"refresh": _refresh, "dodge": _dodge, "fast_fall": _fast_fall, "roll_duck": _roll_duck,
			"guard_jump": _guard_jump, "teeter": _teeter, "rises": _rises, "hitstun": _hitstun,
			"breaks": _breaks, "sounds": _sounds, "parity": _parity, "camera": _camera, "spout": _spout}
	for name: String in only:
		_expect(parts.has(name), "known partition: " + name)
	for name: String in parts:
		if only.is_empty() or name in only:
			print("PART " + name)
			await (parts[name] as Callable).call()
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
## The player held at `_hold_at` each frame (an off-deck spot for the camera), INF: free.
func _hold_tick() -> void:
	if _hold_at != Vector3.INF and p != null:
		p.global_position = _hold_at
		p.velocity = Vector3.ZERO


func _el(el: String) -> void:
	MatchSetup.element = el
	await rig.until(func() -> bool: return p.arena_element == el, 2.0)


## The player standing at `x_in` m inside the -X lip (z across), facing `yaw` (default: the deck's middle, +X).
func _ground(x_in := 8.0, z := 0.0, yaw := -PI * 0.5) -> void:
	rig.release_all()
	rig.place(p, rig.at(x_in, z), yaw)
	p.pitch = 0.0
	await rig.secs(0.15)


## The player off the deck at `out` m past the -X lip, `y` from the deck's top, facing the deck; the double jump spent when
## `spent` (the Rise next).
func _air_at(out: float, y: float, spent := true, z := 0.0) -> void:
	rig.release_all()
	rig.place(p, rig.at(-out, z, y), -PI * 0.5)
	p.pitch = 0.0
	await physics_frame
	rm._air = true
	if spent:
		rm.jumps_left = 0
		rm._dj_at = -INF


## Max height over the start until he is back on the floor (or `limit_s`), with `during` called each frame (frame index).
func _track_top(limit_s: float, during := Callable()) -> float:
	var y0 := p.global_position.y
	var top := y0
	var n := int(limit_s * Engine.physics_ticks_per_second)
	for i in n:
		if during.is_valid():
			during.call(i)
		await physics_frame
		top = maxf(top, p.global_position.y)
		if i > 6 and p.is_on_floor():
			break
	return top - y0


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ---------------------------------------------------------------- jumps
func _jumps() -> void:
	var tops: Array = []
	for hold_s: float in [0.08, 0.10, 0.5]:
		await _ground()
		var fr := int(round(hold_s * Engine.physics_ticks_per_second))
		rig.hold(&"jump", true)
		var top := await _track_top(1.5, func(i: int) -> void:
			if i == fr:
				rig.hold(&"jump", false))
		rig.hold(&"jump", false)
		tops.append(snappedf(top, 0.001))
	print("METRIC hop_apex_m %s" % str(tops))
	_expect(tops.all(func(t: float) -> bool: return absf(t - 2.0) <= 0.05), "Space held 0.08 s, 0.10 s and 0.5 s: all the full jump, 2.0 m (%s)" % str(tops))
	# the hop-cast: Space within 0.05 s of a cast's release, either order
	var c := SwayCaster.of(p)
	var shorts: Array = []
	await _ground()
	c.cast_released.emit("test/hop", "hop")
	await rig.ticks(2)
	rig.tap(&"jump")
	shorts.append(snappedf(await _track_top(1.5), 0.001))
	await _ground()
	rig.tap(&"jump")
	shorts.append(snappedf(await _track_top(1.5, func(i: int) -> void:
		if i == 1:
			c.cast_released.emit("test/hop", "hop")), 0.001))
	await _ground()
	c.cast_released.emit("test/hop", "hop")
	await rig.ticks(6)
	rig.tap(&"jump")
	var late := await _track_top(1.5)
	print("METRIC short_hop_apex_m %s (a press 0.1 s after the release: %.3f)" % [str(shorts), late])
	_expect(shorts.all(func(t: float) -> bool: return absf(t - 0.8) <= 0.05) and absf(late - 2.0) <= 0.05,
			"the hop-cast: Space 0.03 s after a release and a release 0.03 s after Space both 0.8 m (%s); 0.1 s after: the full jump (%.2f)" % [str(shorts), late])
	# the double jump per element, and the carry it keeps
	var djs := {}
	var bad: Array = []
	for el: String in ELS:
		await _el(el)
		await _ground()
		rig.tap(&"jump")
		await rig.ticks(2)
		await rig.until(func() -> bool: return p.velocity.y <= 0.0, 1.0)
		var y1 := p.global_position.y
		rig.tap(&"jump")
		var top := y1
		for i in 60:
			await physics_frame
			top = maxf(top, p.global_position.y)
		var want := RingMoves.el_num("double_jump", "m", el, 1.6)
		djs[el] = snappedf(top - y1, 0.001)
		if absf(top - y1 - want) > 0.05:
			bad.append("%s %.3f (want %.1f)" % [el, top - y1, want])
		await rig.until(func() -> bool: return p.is_on_floor(), 2.0)
	print("METRIC double_jump_m %s" % str(djs))
	_expect(bad.is_empty(), "the double jump: 1.6 m, earth 1.4, air 1.9 (%s)%s" % [str(djs), "" if bad.is_empty() else " " + str(bad)])
	await _el("water")
	await _ground()
	rig.tap(&"jump")
	await rig.ticks(2)
	await rig.until(func() -> bool: return p.velocity.y <= 0.0, 1.0)
	var kn := BendKnock.of(p)
	kn.kv = Vector3(6.0, 0.0, 0.0)
	await physics_frame
	var k0 := kn.kv.length()
	rig.tap(&"jump")
	await physics_frame
	var k1 := kn.kv.length()
	var keep := k1 / maxf(k0 - BendKnock.AIR_DECEL / 60.0, 0.01)
	print("METRIC dj_carry_keep %.3f" % keep)
	_expect(absf(keep - 0.5) < 0.02 and rm.jumps_left == 0, "the double jump keeps half the launch's carry (%.2f -> %.2f: x%.3f)" % [k0, k1, keep])
	kn.kv = Vector3.ZERO
	await rig.until(func() -> bool: return p.is_on_floor(), 2.0)
	# a third Space over the deck: nothing; off it, 0.2 s after the double jump: the Rise
	await _ground()
	moves_seen.clear()
	rig.tap(&"jump")
	await rig.secs(0.3)
	rig.tap(&"jump")
	await rig.secs(0.3)
	rig.tap(&"jump")
	await rig.secs(0.1)
	_expect(moves_seen == ["jump", "double_jump"] and rm.rise_ready and rm.mode == "" and not rm.helpless(),
			"over the deck a third Space does nothing (%s)" % str(moves_seen))
	await rig.until(func() -> bool: return p.is_on_floor(), 3.0)
	await _air_at(2.0, 0.0, false)
	moves_seen.clear()
	rig.tap(&"jump")
	await rig.secs(0.1)
	rig.tap(&"jump")
	await rig.secs(0.15)
	rig.tap(&"jump")
	await rig.secs(0.05)
	_expect(moves_seen == ["double_jump", "rise"], "off the deck: the first Space the double jump, a press 0.1 s after it nothing, at 0.25 s the Rise (%s)" % str(moves_seen))
	await rig.secs(1.5)
	# walking off the deck: the first Space is the double jump
	await _ground(1.0, 0.0, PI * 0.5)
	moves_seen.clear()
	rig.hold(&"move_forward", true)
	var off := await rig.until(func() -> bool: return rm.airborne() and not p.is_on_floor(), 2.0)
	rig.hold(&"move_forward", false)
	await rig.ticks(3)
	rig.tap(&"jump")
	await rig.ticks(2)
	_expect(off < INF and moves_seen == ["double_jump"], "walked off the lip (after %.2f s), the first Space is the double jump (%s)" % [off, str(moves_seen)])
	await rig.secs(1.5)


# ---------------------------------------------------------------- the masher (RingMoves.simulate)
func _masher() -> void:
	var geo := RingMoves.box_geo(Vector3.ZERO, 6.0, 10.0)
	var hl := float(geo.hl)
	var hw := float(geo.hw)
	# (the Lash's launch at 120% after the hit, the spec's; and at 60%, where the outcomes are mixed)
	for set: Array in [["120%", 19.7], ["60%", 12.7]]:
		for el: String in ELS:
			var w: float = 2.0 / (1.0 + float({"earth": 1.25, "water": 1.0, "fire": 0.95, "air": 0.8}[el]))
			var v: float = float(set[1]) * w
			var hits := {"masher": 0, "idle": 0}
			for kind: String in ["masher", "idle"]:
				for side in 2:
					for d: float in [1.0, 3.0, 5.0]:
						for ang: float in [25.0, 40.0]:
							var a := deg_to_rad(ang)
							var pos := Vector3(-hl + d, 0.0, 0.0) if side == 0 else Vector3(0.0, 0.0, -hw + d)
							var out := Vector3(-1.0, 0.0, 0.0) if side == 0 else Vector3(0.0, 0.0, -1.0)
							var st := {"pos": pos, "vel": Vector3.UP * minf(v * sin(a), 16.0), "kv": out * v * cos(a),
									"stun_s": RingPredict.hitstun(v), "element": el, "air": true, "geo": geo}
							var r := RingMoves.simulate(st, kind, 1.0 / 60.0, 6.0)
							if String(r.result) in ["deck", "edge"]:
								hits[kind] = int(hits[kind]) + 1
			print("METRIC masher_vs_idle %s %s %d/12 vs %d/12" % [set[0], el, int(hits.masher), int(hits.idle)])
			_expect(int(hits.masher) >= int(hits.idle), "%s, the Lash at %s: Space every 60 ms comes back at least as often as doing nothing (%d vs %d of 12)" % [el, set[0], int(hits.masher), int(hits.idle)])


# ---------------------------------------------------------------- the simulation against the engine
func _sim_vs_engine() -> void:
	await _el("water")
	await _air_at(2.0, 0.0, false)
	var start := p.global_position
	var st := {"pos": start - Rig.D, "vel": Vector3.ZERO, "element": "water", "air": true, "geo": RingMoves.box_geo(Vector3.ZERO, 6.0, 10.0)}
	# the same inputs: the double jump at once, the Rise 0.3 s later, toward the deck all the way
	var plan := [{"t": 0.0, "move": Vector3(1.0, 0.0, 0.0), "jump": true}, {"t": 0.3, "jump": true}]
	var hz := float(Engine.physics_ticks_per_second)
	var sim := RingMoves.simulate(st, plan, 1.0 / hz, 0.9)
	rig.hold(&"move_forward", true)
	rig.tap(&"jump")
	for i in int(round(0.3 * hz)):
		await physics_frame
	rig.tap(&"jump")
	for i in int(round(0.9 * hz)) - int(round(0.3 * hz)):
		await physics_frame
	rig.hold(&"move_forward", false)
	var eng := p.global_position - Rig.D
	var cm := (eng - Vector3(sim.pos)).length() * 100.0
	print("METRIC sim_vs_engine_cm %.2f (engine %s, simulation %s)" % [cm, eng, sim.pos])
	_expect(cm < 2.0, "RingMoves.simulate and the engine: the double jump and the Rise, 0.9 s, within 2 cm (%.2f cm)" % cm)
	await rig.secs(1.5)


# ---------------------------------------------------------------- control after a completed recovery
func _recovery_control() -> void:
	for el: String in ELS:
		await _el(el)
		for dodge_spent in [false, true]:
			await _air_at(7.0, 4.0, true)
			if dodge_spent:
				rm.dodge(Vector3.ZERO)
				await rig.until(func() -> bool: return rm.mode == "", 1.0)
				_expect(not rm.dodge_ready, el + ": the earlier dodge was actually spent")
			if el == "fire":
				p.yaw = PI * 0.5
				p.rotation.y = p.yaw
			moves_seen.clear()
			rig.tap(&"jump")
			var started := await rig.until(func() -> bool: return rm.mode == "rise", 0.3)
			var ended := await rig.until(func() -> bool: return rm.mode != "rise", 1.5)
			var r := RingMoves.rise_of(el)
			var expected_vy := float(r.get("end_vy", 2.0))
			var vy_error := absf(p.velocity.y - expected_vy)
			_expect(started < INF and ended < INF and rm.mode == "" and not rm.helpless() and rm.can_cast(),
					"%s Rise returns controlled airborne casting (dodge spent=%s)" % [el, dodge_spent])
			_expect(vy_error <= RingMoves.gravity() / Engine.physics_ticks_per_second + 0.01 and (el != "air" or rm._glide),
					"%s keeps end velocity %.2f and its glide contract (actual %.3f)" % [el, expected_vy, p.velocity.y])
			_expect(rm.jumps_left == 0 and not rm.rise_ready and rm.dodge_ready != dodge_spent,
					el + ": recovery expiry grants no jump, Rise or dodge resource")
			var rise_count := moves_seen.count("rise")
			var jump_count := moves_seen.count("double_jump")
			rig.tap(&"jump")
			await rig.ticks(2)
			_expect(rm.mode == "" and moves_seen.count("rise") == rise_count and moves_seen.count("double_jump") == jump_count,
					el + ": another Space cannot create an endless Rise/jump chain")
			# Keep this a fixed-direction steering measurement: the outward-facing Fire trial otherwise auto-turns
			# its recovery camera while the key is held, rotating the target velocity during the acceleration check.
			rm.note_mouse()
			rig.hold(&"move_right", true)
			await rig.secs(0.4)
			rig.hold(&"move_right", false)
			var flat := Vector2(p.velocity.x, p.velocity.z).length()
			var drift := RingMoves.drift_of(el).x
			_expect(flat >= drift * 0.95 and flat <= drift + 0.02,
					"%s regains ordinary air steering (%.3f / %.3f m/s)" % [el, flat, drift])
			var dodge_count := moves_seen.count("dodge")
			SwayCaster.of(p).key3_press()
			await rig.ticks(1)
			_expect((rm.mode == "dodge" and moves_seen.count("dodge") == dodge_count + 1) if not dodge_spent
					else (rm.mode == "" and moves_seen.count("dodge") == dodge_count),
					"%s key 3 %s after recovery" % [el, "uses the remaining dodge" if not dodge_spent else "cannot reuse the spent dodge"])
	# Return naturally to the deck after a Water Rise; control in the air must not bypass the existing landing recovery.
	await _el("water")
	await _air_at(0.8, 0.5, true)
	rig.tap(&"jump")
	await rig.until(func() -> bool: return rm.mode == "rise", 0.3)
	await rig.until(func() -> bool: return rm.mode != "rise", 1.5)
	rig.hold(&"move_forward", true)
	var landed := await rig.until(func() -> bool: return p.is_on_floor() and not rm.airborne(), 3.0)
	rig.hold(&"move_forward", false)
	var lag0 := rm.in_landing_lag() and not rm.can_cast()
	await rig.secs(0.3)
	var lag1 := rm.in_landing_lag()
	await rig.secs(0.08)
	_expect(landed < INF and lag0 and lag1 and not rm.in_landing_lag() and not rm.helpless()
			and rm.jumps_left == 1 and rm.dodge_ready and rm.rise_ready and rm.can_cast(),
			"recovery landing retains 0.35 s lag, then every air resource and casting are available")


# ---------------------------------------------------------------- refreshes
func _refresh() -> void:
	await _air_at(3.0, 2.0, true)
	rm.dodge_ready = false
	rm.rise_ready = false
	var kn := BendKnock.of(p)
	kn.launched.emit(Vector3(4.0, 6.0, 0.0), 0.3, false)
	await physics_frame
	var after_set := rm.jumps_left == 0 and not rm.dodge_ready and not rm.rise_ready
	kn.launched.emit(Vector3(-8.0, 9.0, 0.0), 0.4, true)
	await physics_frame
	_expect(after_set and rm.jumps_left == 1 and rm.dodge_ready and rm.rise_ready,
			"a set knock refreshes nothing; a tumbling launch gives back the double jump, the dodge and the Rise")
	kn.stun_t = 0.0
	await rig.secs(1.2)


# ---------------------------------------------------------------- the air dodge
func _dodge() -> void:
	await _ground()
	rig.tap(&"jump")
	await rig.ticks(2)
	await rig.until(func() -> bool: return p.velocity.y <= 0.0, 1.0)
	var a := p.global_position
	rm.dodge(Vector3(1.0, 0.0, 0.0))
	await rig.until(func() -> bool: return rm.mode != "dodge" or rm.mode_t >= 0.22 - 1e-4, 1.0)
	var m := _flat(p.global_position, a)
	print("METRIC air_dodge_m %.3f" % m)
	_expect(absf(m - 3.2) <= 0.1 and absf(p.global_position.y - a.y) < 0.02, "the air dodge: %.3f m flat, gravity off" % m)
	var again := rm.dodge_ready
	rm.dodge(Vector3(-1.0, 0.0, 0.0))
	await physics_frame
	_expect(not again and rm.mode == "dodge" and rm.mode_t > 0.22, "a second 3 in the air does nothing")
	await rig.until(func() -> bool: return p.is_on_floor(), 2.0)
	await rig.secs(0.4)
	# the bolts: one through him at 0.15 s flies on, one at 0.40 s hits
	if bot == null:
		bot = await rig.bot("earth", rig.at(14.0, 5.0), 0.0)
	for case: Array in [[0.15, false], [0.40, true]]:
		await _ground()
		rig.tap(&"jump")
		await rig.ticks(2)
		await rig.until(func() -> bool: return p.velocity.y <= 0.5, 1.0)
		var kn := BendKnock.of(p)
		var n0 := kn.knocks
		rm.dodge(Vector3(1.0, 0.0, 0.0))
		var at_s: float = case[0]
		var fly := 1.2 / 40.0
		await rig.until(func() -> bool: return rm.mode == "dodge" and rm.mode_t >= at_s - fly - 0.5 / Engine.physics_ticks_per_second, 1.0)
		# (aimed at where he will be as it arrives: along +X at the dodge's speed during its travel)
		var lead := 14.545 * fly if at_s < 0.22 else 0.0
		var from := p.global_position + Vector3(lead, 1.0, 1.2)
		var b := BendBolt.launch(bot, from, Vector3(0.0, 0.0, -1.0), {"kind": "fire", "mps": 40.0, "damage": 10.0, "knock_mps": 3.0,
				"up_mps": 0.5, "radius_m": 0.2, "range_m": 20.0})
		await rig.secs(0.07)
		var hit := kn.knocks > n0
		var spent := not is_instance_valid(b) or b.spent
		var want_hit: bool = case[1]
		_expect(hit == want_hit and spent == want_hit,
				"a bolt through him at %.2f s into the dodge: %s (knocked %s, the bolt spent %s)" % [at_s, "hits" if want_hit else "flies on unspent", hit, spent])
		await rig.until(func() -> bool: return p.is_on_floor(), 2.0)
		await rig.secs(0.5)
	# landing in it: 0.3 s of lag
	await _ground()
	rig.tap(&"jump")
	await rig.ticks(3)
	rm.dodge(Vector3(1.0, 0.0, 0.0))
	var land := await rig.until(func() -> bool: return rm.in_landing_lag(), 1.0)
	var lag_from := rm._lag
	_expect(land < INF and absf(lag_from - 0.3) < 0.02, "a dodge that lands in its end: 0.3 s of landing lag (%.2f)" % lag_from)
	await rig.secs(0.5)


# ---------------------------------------------------------------- fast fall
func _fast_fall() -> void:
	await _ground()
	rig.tap(&"jump")
	await rig.ticks(6)
	rig.tap(&"crouch")
	await rig.ticks(2)
	var before_apex := p.velocity.y > 0.0 and not rm._ff
	await rig.until(func() -> bool: return p.velocity.y <= 0.0, 1.0)
	rig.tap(&"crouch")
	await rig.ticks(2)
	var v1 := p.velocity.y
	await rig.ticks(4)
	var v2 := p.velocity.y
	_expect(before_apex and absf(v1 + 17.0) < 0.01 and absf(v2 + 17.0) < 0.01 and not p.controls.pressed(&"crouch"),
			"C before the apex: nothing; after it: -17 m/s, kept with C let go (%.2f, %.2f)" % [v1, v2])
	await rig.secs(0.5)
	# it ends the glide (air's Updraft)
	await _el("air")
	await _air_at(4.0, 2.0, true)
	rig.tap(&"jump")
	await rig.until(func() -> bool: return rm.mode == "" and not rm.rise_ready and rm._glide, 1.5)
	await rig.secs(0.3)
	var glide_vy := p.velocity.y
	rig.tap(&"crouch")
	await rig.ticks(3)
	_expect(glide_vy >= -3.01 and absf(p.velocity.y + 14.0) < 0.01 and not rm._glide,
			"air's glide falls no faster than 3 m/s (%.2f); C ends it: -14 m/s (%.2f)" % [glide_vy, p.velocity.y])
	await rig.secs(1.0)
	await _el("water")


# ---------------------------------------------------------------- roll and duck
func _roll_duck() -> void:
	await _ground(8.0)
	moves_seen.clear()
	var a := p.global_position
	var yaw0 := p.rotation.y
	rig.tap(InputSetup.GUARD_ACTION)
	rig.tap(&"move_left")
	await rig.secs(0.7)
	var d := _flat(p.global_position, a)
	_expect(moves_seen.has("roll") and absf(d - 3.5) <= 0.1 and absf(wrapf(p.rotation.y - yaw0, -PI, PI)) < 0.01,
			"E and a fresh A: a 3.5 m roll (%.2f m), the facing kept" % d)
	await _ground(8.0)
	await rig.until(func() -> bool: return not rm._guard_zone(), 3.0)       # (the last E's guard down first)
	moves_seen.clear()
	rig.hold(&"move_forward", true)
	await rig.secs(0.2)
	rig.tap(InputSetup.GUARD_ACTION)
	await rig.secs(0.3)
	rig.hold(&"move_forward", false)
	_expect(not moves_seen.has("roll"), "W held before E: no roll (%s)" % str(moves_seen))
	# from 1 m inside a lip: the roll ends 0.3 m inside (the end's lip, then the long side's)
	await _ground(1.0, 0.0, -PI * 0.5)
	rig.tap(InputSetup.GUARD_ACTION)
	rig.tap(&"move_back")
	await rig.secs(0.7)
	var x_in := p.global_position.x - rig.lip(0.0).x
	await _ground(8.0, -6.0, 0.0)
	rig.tap(InputSetup.GUARD_ACTION)
	rig.tap(&"move_forward")
	await rig.secs(0.7)
	var z_in := p.global_position.z - (Rig.D.z - 7.0)
	_expect(absf(x_in - 0.3) < 0.03 and absf(z_in - 0.3) < 0.03 and p.is_on_floor(),
			"rolls toward a lip from 1 m inside stop 0.3 m inside (the end %.2f, the side %.2f)" % [x_in, z_in])
	# the duck, and the repeat cost
	await _ground(8.0)
	rig.tap(InputSetup.GUARD_ACTION)
	rig.tap(&"crouch")
	await rig.secs(0.1)
	var duck_int := rm.mode == "duck" and rm.intangible() and not BendStatus.can_take(p, bot)
	await rig.secs(0.25)
	_expect(duck_int and not rm.intangible(), "E and C: the duck, intangible at 0.1 s (no hurt, no knock), not at 0.35 s")
	await rig.secs(1.3)
	await rig.until(func() -> bool: return not rm._guard_zone(), 3.0)
	rig.tap(InputSetup.GUARD_ACTION)
	rig.tap(&"move_right")
	await physics_frame
	var len1 := float(rm._m.get("len", 0.0))
	await rig.until(func() -> bool: return rm.mode == "", 2.0)
	await rig.secs(0.2)
	rig.tap(InputSetup.GUARD_ACTION)
	rig.tap(&"move_left")
	await physics_frame
	var len2 := float(rm._m.get("len", 0.0))
	_expect(absf(len2 - len1 - 0.1) < 0.01, "a roll within 1.0 s of the last: 0.1 s more end lag (%.2f -> %.2f)" % [len1, len2])
	await rig.secs(1.5)


func _guard_jump() -> void:
	await _ground(8.0)
	var c := SwayCaster.of(p)
	c.guard_override = true
	rig.hold(InputSetup.GUARD_ACTION, true)
	await rig.secs(0.4)
	rig.tap(&"jump")
	await physics_frame
	var up := p.velocity.y > 5.0 and rm.airborne()
	c.guard_override = null
	rig.hold(InputSetup.GUARD_ACTION, false)
	_expect(up, "the guard held, Space jumps on that frame (vy %.2f)" % p.velocity.y)
	await rig.secs(1.5)


# ---------------------------------------------------------------- the teeter
func _teeter() -> void:
	for side: Array in [["the end", Vector3(2.0, 0.0, 0.0), PI * 0.5], ["a long side", Vector3(8.0, 0.0, -5.0), 0.0]]:
		var off: Vector3 = side[1]
		await _ground(off.x, off.z, float(side[2]))
		var lipv := func() -> float:
			return (p.global_position.x - rig.lip(0.0).x) if String(side[0]) == "the end" else (p.global_position.z - (Rig.D.z - 7.0))
		rig.hold(&"move_forward", true)
		await rig.until(func() -> bool: return rm._teetering, 2.0)
		await rig.secs(0.2)
		rig.hold(&"move_forward", false)
		await rig.secs(0.3)
		var stopped: float = lipv.call()
		var on1 := p.is_on_floor() and stopped > 0.0
		rig.hold(&"move_forward", true)
		await rig.secs(0.45)
		rig.hold(&"move_forward", false)
		var gone: float = lipv.call()
		_expect(on1 and gone < 0.0, "%s: a run into the lip stops (%.2f m inside after 0.2 s at it), 0.3 s toward the water steps off (%.2f)" % [side[0], stopped, gone])
		await rig.secs(1.0)
	await _ground(0.3, 0.0, PI * 0.5)
	BendStatus.knock(p, Vector3(-6.0, 0.0, 0.0), null)
	await rig.secs(0.15)
	_expect(p.global_position.x < rig.lip(0.0).x, "a knock at the lip carries him over at once")
	await rig.secs(1.0)


# ---------------------------------------------------------------- the Rise
func _rises() -> void:
	var r_m := {}
	for el: String in ELS:
		await _el(el)
		await _air_at(3.0, -1.0, true)
		if el == "fire":
			# (the Jet aimed level out over the water: its full 7.5 m with no face in the way to scramble up)
			p.yaw = PI * 0.5
			p.rotation.y = p.yaw
		rig.tap(&"jump")
		var r := RingMoves.rise_of(el)
		var su := float(r.startup_s)
		# (from the last frame of the startup to the travel's end)
		var a := p.global_position
		for i in 120:
			await physics_frame
			if rm.mode != "rise":
				break
			if rm.mode_t < su - 1e-4:
				a = p.global_position
		var d := p.global_position - a
		r_m[el] = snappedf(d.length() if el in ["earth", "fire"] else d.y, 0.01)
		match el:
			"earth":
				var lean := rad_to_deg(Vector3.UP.angle_to(d))
				_expect(absf(d.length() - 5.5) <= 0.2 and absf(lean - 20.0) < 1.5 and d.x > 0.0,
						"earth's Pillar: %.2f m along a %.1f degree lean toward the lip" % [d.length(), lean])
			"water":
				_expect(absf(d.y - 4.5) <= 0.2, "water's Fountain: %.2f m up" % d.y)
			"fire":
				var pitch := rad_to_deg(asin(d.normalized().y))
				_expect(absf(d.length() - 7.5) <= 0.2 and absf(pitch - 20.0) < 1.0, "fire's Jet, a level aim: %.2f m at %.1f degrees (lifted to +20)" % [d.length(), pitch])
			"air":
				_expect(absf(d.y - 3.5) <= 0.2 and not rm.helpless() and rm._glide and rm.can_cast(), "air's Updraft: %.2f m up, then a controlled glide" % d.y)
		await rig.secs(2.5)
	print("METRIC rise_m %s" % str(r_m))
	# the scramble: a Rise meeting the face with the head 1.8 m under the grab box reaches the hang; 2.4 m does not
	await _el("water")
	var lip_y := Rig.D.y
	var res := {}
	for under: float in [1.8, 2.4]:
		var head_top := lip_y - 0.5 - under
		var start_feet := head_top - 1.6 - 4.456
		rig.release_all()
		rig.place(p, Vector3(rig.lip(0.0).x - 0.31, start_feet, Rig.D.z), -PI * 0.5)
		await physics_frame
		rm._air = true
		rm.jumps_left = 0
		rm._dj_at = -INF
		moves_seen.clear()
		var g0 := rm._grabs
		var trial_at := rm._t
		rig.tap(&"jump")
		await rig.until(func() -> bool: return rm.on_ledge() or (rm._rise_end_at >= trial_at and rm._t - rm._rise_end_at > 0.2), 2.0)
		await rig.secs(0.4)
		res[under] = [moves_seen.has("scramble"), rm.mode, rm._grabs - g0, rm.can_cast()]
		rig.place(p, rig.at(8.0), -PI * 0.5)
		await rig.secs(0.3)
	_expect(bool(res[1.8][0]) and String(res[1.8][1]) == "hang" and int(res[1.8][2]) == 1 and not bool(res[2.4][0]),
			"the scramble: from 1.8 m under the grab box to the hang (a grab counted), from 2.4 m not (%s)" % str(res))
	_expect(String(res[1.8][1]) == "hang" and not bool(res[1.8][3]), "a successful recovery grab still gives the ledge priority over spell casting")
	# the Pillar strikes a body over him
	await _el("earth")
	if bot == null:
		bot = await rig.bot("earth", rig.at(14.0, 5.0), 0.0)
	await _air_at(3.0, -1.0, true)
	var bk := BendKnock.of(bot)
	var n0 := bk.knocks
	rig.place(bot, p.global_position + Vector3(0.0, 2.2, 0.0), 0.0)
	rig.tap(&"jump")
	await rig.secs(0.5)
	_expect(bk.knocks > n0, "earth's Pillar strikes a body over him (rise/pillar)")
	rig.place(bot, rig.at(14.0, 5.0), 0.0)
	await rig.secs(1.5)
	# a self-launch from the deck (Lift, Jets, Leap: BendMotion's up dash) uses up the Rise, not helpless
	await _ground()
	BendMotion.of(p).dash_began(6.0)
	p.velocity.y = 8.0
	await rig.secs(0.2)
	_expect(not rm.rise_ready and rm.jumps_left == 1 and not rm.helpless(), "a self-launch from the deck uses up the airtime's Rise, not helpless")
	await rig.secs(1.5)
	await _el("water")


# ---------------------------------------------------------------- hitstun: the buffer, the escape, the steer
func _hitstun() -> void:
	await _ground()
	var kn := BendKnock.of(p)
	kn.stun_t = 1.0
	await rig.secs(0.4)
	rig.tap(&"jump")
	await rig.secs(0.3)
	var held := p.is_on_floor() and kn.stun_t > 0.0
	await rig.until(func() -> bool: return kn.stun_t <= 0.0, 1.0)
	await rig.ticks(2)
	_expect(held and p.velocity.y > 5.0, "a press at 0.4 s of a 1.0 s hitstun waits, then jumps on the first free frame")
	await rig.until(func() -> bool: return p.is_on_floor(), 2.0)
	await rig.secs(0.3)
	kn.stun_t = 1.0
	await rig.secs(0.65)
	rig.tap(&"jump")
	await rig.ticks(2)
	_expect(kn.stun_t <= 0.0 and p.velocity.y > 5.0, "a fresh press at 0.65 s of a 1.0 s hitstun ends it (the escape) and jumps")
	await rig.until(func() -> bool: return p.is_on_floor(), 2.0)
	# the steer: held keys read 0.1 s after the launch; he leans toward the held side
	await _ground()
	rig.hold(&"move_left", true)
	kn.launched.emit(Vector3(8.0, 4.0, 0.0), 0.5, true)      # (thrown along his facing, +X: A holds across it)
	await rig.secs(0.2)
	var l := rm.lean()
	rig.hold(&"move_left", false)
	await rig.secs(0.3)
	_expect(absf(l.x) > 0.2 and rm.lean() == Vector2.ZERO, "the steer read at 0.1 s leans him toward the held side for 0.3 s (%s)" % str(l))
	kn.stun_t = 0.0
	await rig.secs(0.5)


# ---------------------------------------------------------------- breaking the fall, lying, getting up
func _breaks() -> void:
	var kn := BendKnock.of(p)
	await _ground(8.0)
	kn.broke_fall.emit("stand", Vector3.ZERO)
	await rig.secs(0.1)
	var st := rm.intangible()
	await rig.secs(0.2)
	_expect(st and not rm.intangible(), "a broken fall, standing: intangible for 0.25 s")
	await _ground(1.5, 0.0, -PI * 0.5)
	var a := p.global_position
	kn.broke_fall.emit("roll", Vector3(-1.0, 0.0, 0.0))
	await rig.secs(0.5)
	var x_in := p.global_position.x - rig.lip(0.0).x
	await _ground(8.0)
	var b := p.global_position
	kn.broke_fall.emit("roll", Vector3(0.0, 0.0, 1.0))
	await rig.secs(0.5)
	_expect(absf(_flat(p.global_position, b) - 2.5) < 0.05 and absf(x_in - 0.3) < 0.03 and _flat(a, a) == 0.0,
			"a broken fall's roll: 2.5 m (%.2f), never off the lip (%.2f m inside)" % [_flat(p.global_position, b), x_in])
	await _air_at(0.31, -1.5, false)
	kn.broke_fall.emit("wall", Vector3.ZERO)
	await rig.secs(0.05)
	var stuck := rm.mode == "wall"
	await rig.secs(0.08)
	_expect(stuck and rm.mode == "" and p.velocity.y > 0.0, "a broken fall on the face: stuck 0.1 s, then off it at +3 m/s")
	await rig.secs(1.5)
	# lying: Space stands (intangible), E + a direction rolls 2.5 m, a click is the getup attack
	await _ground(8.0)
	kn.lying_t = 2.0
	await rig.secs(0.2)
	var lying := rm.mode == "lie" and not rm.can_cast()
	rig.tap(&"jump")
	await rig.ticks(2)
	_expect(lying and rm.mode == "" and kn.lying_t <= 0.0 and rm.intangible() and p.is_on_floor(), "lying: Space stands, intangible")
	await rig.secs(0.5)
	kn.lying_t = 2.0
	await rig.secs(0.2)
	var c0 := p.global_position
	rig.hold(InputSetup.GUARD_ACTION, true)
	rig.tap(&"move_right")
	await rig.secs(0.6)
	rig.hold(InputSetup.GUARD_ACTION, false)
	_expect(absf(_flat(p.global_position, c0) - 2.5) < 0.05, "lying: E + a direction rolls 2.5 m (%.2f)" % _flat(p.global_position, c0))
	await rig.secs(0.5)
	if bot == null:
		bot = await rig.bot("earth", rig.at(14.0, 5.0), 0.0)
	rig.place(bot, p.global_position + Vector3(1.0, 0.0, 0.0), 0.0)
	await rig.ticks(2)
	var bk := BendKnock.of(bot)
	var n0 := bk.knocks
	kn.lying_t = 2.0
	await rig.secs(0.2)
	rig.tap(&"fire")
	await rig.secs(0.5)
	_expect(bk.knocks > n0, "lying: a click is the getup attack (it strikes a body 1 m away)")
	rig.place(bot, rig.at(14.0, 5.0), 0.0)
	await rig.secs(0.5)


# ---------------------------------------------------------------- his own sounds
func _sounds() -> void:
	await _ground()
	var kn := BendKnock.of(p)
	var h0 := rm.looks.heard.size()
	kn.stun_t = 1.0
	await rig.ticks(2)
	var on := rm.looks.whoosh_on
	await rig.secs(0.65)
	var ticked := rm.looks.heard.slice(h0).has("tick")
	await rig.until(func() -> bool: return kn.stun_t <= 0.0, 1.0)
	await rig.ticks(2)
	var heard := rm.looks.heard.slice(h0)
	_expect(on and ticked and not rm.looks.whoosh_on and heard.has("whoosh") and heard.has("whoosh_end") \
			and heard.find("tick") < heard.find("whoosh_end"),
			"his own hitstun sounds: the whoosh on, the tick at 0.6 s, the whoosh cut on the free frame (%s)" % str(heard))
	if bot == null:
		bot = await rig.bot("earth", rig.at(14.0, 5.0), 0.0)
	var bm := RingMoves.of(bot)
	BendKnock.of(bot).stun_t = 1.0
	await rig.secs(1.2)
	_expect(bm.looks != null and not bm.looks.own and bm.looks.heard.is_empty() and not bm.looks.whoosh_on,
			"a bot's hitstun: no sound of the player's own (his ears only)")


# ---------------------------------------------------------------- parity
func _parity() -> void:
	await _el("water")
	if bot == null:
		bot = await rig.bot("water", rig.at(8.0, 3.0), 0.0)
	bot.set(&"element", "water")
	Bending.of(bot).element = "water"
	rig.release_all()
	rig.place(p, rig.at(8.0, -3.0), 0.0)
	rig.place(bot, rig.at(8.0, 3.0), 0.0)
	bot.pad.clear()
	await rig.secs(0.3)
	var p0 := p.global_position
	var b0 := bot.global_position
	var worst := 0.0
	# the intents (world: the player faces -Z, so W is -Z and D is +X)
	# (at 60 frames a second, scaled to the physics rate; 2 s in all)
	var script60 := {0: ["hold", "move_forward", Vector3(0, 0, -1)], 18: ["tap", "jump"], 45: ["tap", "jump"],
			30: ["hold", "move_right", Vector3(1, 0, -1)], 60: ["release", "move_forward", Vector3(1, 0, 0)],
			75: ["release", "move_right", Vector3.ZERO], 80: ["tap", "crouch"], 100: ["hold", "move_left", Vector3(-1, 0, 0)],
			105: ["tap", "jump"]}
	var k := int(round(Engine.physics_ticks_per_second / 60.0))
	var script := {}
	for f: int in script60:
		script[f * k] = script60[f]
	for i in 120 * k:
		if script.has(i):
			var s: Array = script[i]
			match String(s[0]):
				"hold":
					rig.hold(StringName(s[1]), true)
					bot.pad.move = Vector3(s[2]).limit_length(1.0)
				"release":
					rig.hold(StringName(s[1]), false)
					bot.pad.move = Vector3(s[2]).limit_length(1.0)
				"tap":
					rig.tap(StringName(s[1]))
					bot.pad.press("fast_fall" if String(s[1]) == "crouch" else String(s[1]))
		await physics_frame
		var e := ((p.global_position - p0) - (bot.global_position - b0)).length()
		worst = maxf(worst, e)
	rig.release_all()
	bot.pad.clear()
	print("METRIC parity_cm %.3f" % (worst * 100.0))
	_expect(worst < 0.01 and bot._jump_v == 0.0, "the player and a bot given the same intents: the same path within 1 cm over 2 s (%.3f cm)" % (worst * 100.0))
	await rig.secs(1.0)


# ---------------------------------------------------------------- the camera
func _camera() -> void:
	await _el("water")
	await _ground(8.0)
	await rig.secs(0.8)
	var arm := p.spring_arm.spring_length
	var lift := p.camera_pivot.position.y - p.eye_height
	var behind0 := _deck_behind()
	p.pitch = deg_to_rad(-20.0)
	await rig.secs(0.3)
	var behind20 := _deck_behind()
	p.pitch = 0.0
	print("METRIC deck_behind_m pitch0 %.2f pitch-20 %.2f (today's 4.1 m arm at pitch 0: %.2f)" % [behind0, behind20, _deck_behind_for(4.1, 0.0, 0.0)])
	# (round 4, READ: the camera variant in use on top, RingCamera; the default C: the arm +0.75, the pivot +0.8)
	var cv := RingCamera.variant()
	var want_arm := 5.25 + float(cv.get("arm_add", 0.0))
	var want_lift := 0.3 + float(cv.get("pivot_add", 0.0))
	var deck_ok := absf(arm - want_arm) < 0.02 and absf(lift - want_lift) < 0.02 and behind0 > _deck_behind_for(4.1, 0.0, 0.0)
	_expect(deck_ok, "on the deck (camera %s): the arm %.2f m (%.2f), the pivot %.2f m higher (%.2f), more deck behind the feet in frame than today's (%.2f m at pitch 0)" % [
			RingCamera.key(), want_arm, arm, want_lift, lift, behind0])
	# off the deck: lip -5 m, 4 m out, facing the deck
	var spot := rig.at(-4.0, 0.0, -5.0)
	rig.place(p, spot, -PI * 0.5)
	_hold_at = spot
	await physics_frame
	rm._air = true
	await rig.secs(0.8)
	var both := _both_in_view()
	var fov_ok := absf(p.camera.fov - 65.0) < 1.0
	print("METRIC camera_offdeck arm %.2f fov %.1f both_in_view %s" % [p.spring_arm.spring_length, p.camera.fov, both])
	_expect(both and fov_ok and p.spring_arm.spring_length > 5.25, "off the deck at lip -5 m, 4 m out, facing the deck: his body and the lip in the viewport (arm %.2f, fov %.1f)" % [p.spring_arm.spring_length, p.camera.fov])
	# facing away, the mouse still: the recovery turn
	p.yaw = PI * 0.5
	p.rotation.y = p.yaw
	await physics_frame
	var yaw_a := p.yaw
	var t_in := await rig.until(func() -> bool: return _both_in_view(), 1.2)
	var turned := absf(wrapf(p.yaw - yaw_a, -PI, PI))
	print("METRIC recover_turn_ok %s (in view after %.2f s, turned %.0f deg)" % [t_in < 1.2, t_in, rad_to_deg(turned)])
	_expect(t_in <= 1.2 and absf(p.pitch) < 1e-4, "facing away with the mouse still: body and lip in view within 1.2 s (%.2f s), the pitch untouched" % t_in)
	# facing away, the mouse moving: the yaw untouched
	p.yaw = PI * 0.5
	p.rotation.y = p.yaw
	rm._turn_off = false
	rm._turning = false
	var yaw_b := p.yaw
	for i in 72:
		rm.note_mouse()
		await physics_frame
	_expect(absf(wrapf(p.yaw - yaw_b, -PI, PI)) < 1e-4, "facing away with the mouse moving: the yaw untouched")
	_hold_at = Vector3.INF
	# a knock never turns the camera
	await _ground(8.0)
	var y0 := p.yaw
	var pt0 := p.pitch
	BendStatus.knock(p, Vector3(5.0, 8.0, 3.0), null)
	await rig.secs(1.0)
	_expect(absf(p.yaw - y0) < 1e-5 and absf(p.pitch - pt0) < 1e-5, "a launch on the deck never moves yaw or pitch")
	await rig.until(func() -> bool: return p.is_on_floor(), 2.0)
	# the spout: the yaw toward the deck's middle, the pitch level
	p.pitch = deg_to_rad(-30.0)
	var sp := rig.at(5.0, 4.0, 3.0)
	rm.ride_spout(sp, 3.0)
	await physics_frame
	var want := Rig.yaw_to(sp, Rig.D)
	var camera_ok: bool = deck_ok and both and absf(wrapf(p.yaw - want, -PI, PI)) < 0.02 and absf(p.pitch) < 1e-4
	print("METRIC camera_ok %s" % camera_ok)
	_expect(absf(wrapf(p.yaw - want, -PI, PI)) < 0.02 and absf(p.pitch) < 1e-4, "on the spout: the yaw toward the deck's middle, the pitch level")
	rm.leave_spout()
	await rig.secs(1.0)


## How far behind his feet (toward the camera, m; negative: in front) the frame's bottom edge meets the deck now.
func _deck_behind() -> float:
	var cam := p.camera
	var fwd := -cam.global_basis.z
	var half := deg_to_rad(cam.fov * 0.5)
	var down := fwd.rotated(cam.global_basis.x, -half)
	if down.y >= -1e-4:
		return -INF
	var t := (Rig.D.y - cam.global_position.y) / down.y
	var hit := cam.global_position + down * t
	var back := Vector3(cam.global_position.x - p.global_position.x, 0.0, cam.global_position.z - p.global_position.z).normalized()
	return (hit - p.global_position).dot(back)


## The same for an arm `arm`, a pivot lift `lift` and a pitch (analytic, today's numbers).
func _deck_behind_for(arm: float, lift: float, pitch: float) -> float:
	var h := p.eye_height + lift + arm * sin(-pitch)
	var back := arm * cos(pitch)
	var ang := -pitch + deg_to_rad(p.fov * 0.5)
	return back - h / tan(ang)


func _both_in_view() -> bool:
	var chest := p.global_position + Vector3.UP * 1.2
	var lp := rig.lip(p.global_position.z - Rig.D.z)
	return p.camera.is_position_in_frustum(chest) and p.camera.is_position_in_frustum(lp)


# ---------------------------------------------------------------- the spout
func _spout() -> void:
	var sp := rig.at(5.0, 4.0, 3.0)
	var left := [0]
	rm.left_spout.connect(func() -> void: left[0] += 1)
	for how: String in ["jump", "fire", "time"]:
		rig.release_all()
		rm.ride_spout(sp, 3.0 if how != "time" else 0.5)
		await rig.secs(0.3)
		var held := rm.on_spout() and p.global_position.distance_to(sp) < 0.01
		var why := "on %s at %.3f m mode %s" % [rm.on_spout(), p.global_position.distance_to(sp), rm.mode]
		if how != "time":
			rig.tap(StringName(how))
		await rig.secs(0.4 if how != "time" else 0.3)
		_expect(held and not rm.on_spout() and left[0] >= 1, "the spout holds him; %s lets him go (left_spout; %s; then %s, %d)" % [how, why, rm.mode, left[0]])
		left[0] = 0
		await rig.until(func() -> bool: return p.is_on_floor(), 3.0)
