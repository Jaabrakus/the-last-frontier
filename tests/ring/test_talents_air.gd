extends SceneTree
## Air's talents in a real % ring match (the owner, 2026-10-11: "we need to make sure all the talents work and they work in game
## right"): each node of the skill tree's air tree worn by one fighter (the player, or a bot where it says), through the game's own
## code path (BendEffects' casts, SwayCaster's locks and E, BendZone's guards, RingRules' %), against the same done by a fighter who
## wears nothing (Classic: as before). A 2v2 match: the player air with a fire mate, against an air foe (and his mate); every bot
## held still (no thinking) unless a check says. Headless:
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_talents_air.gd -- [only=<id>,<id>...]
##   Full Sail          its Gust 2.4 m wide (2) and its lock 0.5 s (0.45); a foe standing just past the plain Gust's reach of the
##                      line is hit by the worn one only; a bot wearing it casts the wide Gust too; live (switched on)
##   Tailwind           a Slice that lands charges his Carried wind (not worn: none), adds 10% for the 11 it was; the next Slice
##                      is a carried one (knock x1.15)
##   Drift Guard        with his Wind Guard up (E held) he walks at 1.5 m/s (not worn: he stands); its beat 0.25 s (0.3)
##   Eye of the Gale    E held through a perfect Wind Guard: the bounced Slice circles him while E is held and leaves along his
##                      aim when it is let go (x1.2); not worn, straight back at once; its Carried wind lasts 0.4 s (0.8)
##   Rebound            after a perfect Wind Guard his next Slice lock begins 40% full (not worn: empty), once; his held guard
##                      drops at 2.0 s (2.5); a bot wearing it takes the same head start
## Every talent here is live in data/bending/loadout_apply.json (BendLoadout.why_not ""), and a body that wears nothing reads the
## game's own numbers. Last line "TALENTS AIR PASSED (n checks)" or "... FAILED".

const NAME := "TALENTS AIR"
const LIMIT_S := 600.0
const MINE := ["air.gust.full_sail", "air.slice.tailwind", "air.guard.drift", "air.guard.eye", "air.guard.rebound"]

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var player: FrontierPlayer
var mode: RingMode
var foe: NpcFighter
var rules: RingRules
var pc: BendCaster
var sc: SwayCaster
var only: Array = []
var pitch_sign := 1.0
## The crosshair held on this point every physics frame while finite (_aim).
var aim_at := Vector3.INF


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	seed(1757)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = Array(a.substr(5).split(",", false))
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	_run.call_deferred()


func _end() -> void:
	Engine.time_scale = 1.0
	Input.action_release(&"move_forward")
	if sc != null and is_instance_valid(sc):
		sc.held_override = null
		sc.guard_override = null
	if player != null and is_instance_valid(player):
		BendLoadout.clear(player)
	BendLoadout.config_override = {}
	MatchSetup.format = "1v1"
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(s: float) -> void:
	await _ticks(ceili(s * float(Engine.physics_ticks_per_second)))


## Seconds till `cond` holds (INF: not within `limit`).
func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit:
		if cond.call():
			return t
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return INF


func _near(a: float, b: float, tol := 0.01) -> bool:
	return absf(a - b) <= tol


func _on(id: String) -> bool:
	return only.is_empty() or id in only


## The player's crosshair on aim_at (his camera's yaw and pitch), as FxStage.aim.
func _aim() -> void:
	if not aim_at.is_finite() or player == null or player.camera == null:
		return
	var d := (aim_at - player.camera.global_position).normalized()
	player.yaw = atan2(-d.x, -d.z)
	player.pitch = asin(clampf(d.y, -1.0, 1.0)) * pitch_sign


## `ids` worn by the player as an air caster (nothing: Classic), his Carried wind and guard memory cleared.
func _wear(ids: Array) -> void:
	Bending.of(player).element = "air"
	BendLoadout.clear(player)
	for k: StringName in [&"bend_carry_until", AirTalents.REBOUND_META]:
		if player.has_meta(k):
			player.remove_meta(k)
	if not ids.is_empty():
		var ov := BendLoadout.wear(player, ids, "", "air")
		_expect((ov.ids as Array).size() == ids.size(), "%s worn (refused: %s)" % [ids, ov.refused])


## The newest bolt `by` sent (null none).
func _newest(by: Node, known: Dictionary) -> BendBolt:
	var b: BendBolt = null
	for n in get_nodes_in_group(BendBolt.GROUP):
		if n is BendBolt and not known.has(n.get_instance_id()) and (n as BendBolt).caster == by:
			b = n
	return b


func _known() -> Dictionary:
	var k := {}
	for n in get_nodes_in_group(BendBolt.GROUP):
		k[n.get_instance_id()] = true
	return k


## `c` casts `m`'s `md` through the game's own path (BendEffects.apply, as SwayEffects does on a release); the bolt it sent.
func _cast(c: BendCaster, m: String, md: String) -> BendBolt:
	var known := _known()
	BendEffects.apply(c, m, md, (SwayMoves.move(m).bend as Dictionary)[md])
	var b := _newest(c.body, known)
	last_end = "flying"
	if b != null:
		b.ended.connect(func(why: String) -> void: last_end = why)
	return b


## How the last bolt _cast sent ended ("flying": not yet; "none": none sent).
var last_end := "none"


## Clears every bolt and zone in flight (between checks).
func _clear_air() -> void:
	for n in get_nodes_in_group(BendBolt.GROUP):
		(n as BendBolt).end("test")
	for z in get_nodes_in_group(BendZone.GROUP):
		(z as BendZone).queue_free()
	await _ticks(2)


## The player at `at` and the foe `gap` m ahead of him along the deck's long way, both still, his % 0, the crosshair on the
## foe's chest.
func _stage(gap := 7.0) -> void:
	await _clear_air()
	var way := Vector3(foe.global_position.x - player.global_position.x, 0.0, foe.global_position.z - player.global_position.z)
	way = way.normalized() if way.length_squared() > 1e-4 else Vector3.FORWARD
	var mid := _home
	player.global_position = mid - way * gap * 0.5
	player.velocity = Vector3.ZERO
	foe.global_position = mid + way * gap * 0.5
	foe.velocity = Vector3.ZERO
	foe.face_point(player.global_position)
	for b: Node in [player, foe]:
		rules.note_lock_started(b)                  # (his spawn safety over: a lock ends it, spec §7.2)
		var kn := BendKnock.peek(b)
		if kn != null:
			kn.reset()
			kn.stun_t = 0.0
		rules.reset_pct(b, 0.0)
	aim_at = NpcSenses.chest_of(foe)
	await _ticks(20)
	aim_at = NpcSenses.chest_of(foe)


var _home := Vector3.ZERO


func _run() -> void:
	# ---------------------------------------------------------------- live
	for id: String in MINE:
		_expect(BendLoadout.why_not(id) == "", "%s is live (%s)" % [id, BendLoadout.why_not(id)])
		_expect(id in BendLoadout.behaviour() or bool(BendLoadout.resolve(id).ok), "%s resolves whole (%s)" % [id, BendLoadout.resolve(id).why])

	# ---------------------------------------------------------------- the ring: 2v2, air with a fire mate, against air
	MatchSetup.format = "2v2"
	MatchSetup.incoming = true
	MatchSetup.element = "air"
	MatchSetup.foes = ["air"]
	MatchSetup.mates = ["fire"]
	MatchSetup.round_s = 600.0
	MatchSetup.rounds_to_win = 1
	MatchSetup.difficulty = "normal"
	InputSetup.ensure()
	SwayCaster.free_override = true
	change_scene_to_file("res://scenes/ring.tscn")
	for i in 20:
		await process_frame
	lvl = current_scene as RingLevel
	player = lvl.player if lvl != null else null
	mode = RingMode.find(self)
	foe = mode.foe if mode != null else null
	rules = RingRules.current()
	_expect(mode != null and player != null and foe != null and RingRules.stock_on(), "a 2v2 % ring: the player (air), a mate, an air foe")
	if mode == null or player == null or foe == null:
		return _end()
	rules.stale_off = true
	pc = BendCaster.of(player)
	sc = SwayCaster.of(player)
	await _secs(4.5)                                 # (past the countdown and the start's safety)
	_hold_bots(true)
	player.pitch = 0.3
	await _ticks(3)
	pitch_sign = 1.0 if (-player.camera.global_basis.z).y > 0.0 else -1.0
	player.pitch = 0.0
	_home = (player.global_position + foe.global_position) * 0.5
	physics_frame.connect(_aim)
	var fc := BendCaster.of(foe) as NpcBendCaster
	if fc != null:
		fc.scatter_deg = 0.0                         # (the foe's shots at the player's chest exactly: the guards' checks)
		fc.lead = 0.0
	foe.brain.target = player
	await _stage(7.0)                                # (a first staging settles the bodies and the camera)
	await _secs(1.0)

	if _on("air.gust.full_sail"):
		await _full_sail()
	if _on("air.slice.tailwind"):
		await _tailwind()
	if _on("air.guard.drift"):
		await _drift()
	if _on("air.guard.eye"):
		await _eye()
	if _on("air.guard.rebound"):
		await _rebound()
	physics_frame.disconnect(_aim)
	_end()


## Every bot held still (`on`: no thinking, so none casts) or let go.
func _hold_bots(on: bool) -> void:
	for e: Dictionary in mode.extras:
		if e.get("bot") is NpcFighter:
			(e.bot as NpcFighter).held = on
	if mode.foe != null and is_instance_valid(mode.foe):
		mode.foe.held = on


# ---------------------------------------------------------------- Full Sail
func _full_sail() -> void:
	await _stage(7.0)
	# its width and its lock, worn and not
	var got := {}
	for id: String in ["", "air.gust.full_sail"]:
		_wear([id] if id != "" else [])
		var g := _cast(pc, "air_gust", "gust")
		sc.set_mode("air_gust", "gust")
		got[id] = [g.radius * 2.0 if g != null else -1.0, sc._lock_time("air_gust", null, 0.0, 0.0),
				g.global_position if g != null else Vector3.ZERO, g.velocity if g != null else Vector3.ZERO]
		await _clear_air()
	_expect(_near(float(got[""][0]), 2.0) and _near(float(got["air.gust.full_sail"][0]), 2.4),
			"Full Sail: the Gust cast is %.1f m wide (Classic %.1f)" % [got["air.gust.full_sail"][0], got[""][0]])
	_expect(_near(float(got[""][1]), 0.45, 0.002) and _near(float(got["air.gust.full_sail"][1]), 0.5, 0.002),
			"Full Sail: the Gust's lock %.2f s (Classic %.2f)" % [got["air.gust.full_sail"][1], got[""][1]])
	# a foe standing 1.1 m + his body's width off the Gust's line: the plain Gust passes him, the wide one takes him
	var from: Vector3 = got[""][2]
	var dir: Vector3 = (got[""][3] as Vector3).normalized()
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	var side := Vector3.UP.cross(flat).normalized()
	var cap := _capsule_r(foe)
	var hit := {}
	for id: String in ["", "air.gust.full_sail"]:
		_wear([id] if id != "" else [])
		await _clear_air()
		var spot := from + flat * 6.0 + side * (1.1 + cap)
		spot.y = FormEffects.ground_at(foe, spot).y
		foe.global_position = spot
		foe.velocity = Vector3.ZERO
		rules.reset_pct(foe, 0.0)
		await _ticks(6)
		var aim_keep := aim_at
		aim_at = Vector3.INF
		var g := _cast(pc, "air_gust", "gust")
		if g != null:
			g.global_position = from                  # (the same line both times: the plain cast's own)
			g.velocity = dir * g.velocity.length()
		await _secs(0.8)
		aim_at = aim_keep
		hit[id] = rules.pct_of(foe)
	_expect(float(hit[""]) <= 0.0 and float(hit["air.gust.full_sail"]) > 0.0,
			"Full Sail: a foe %.2f m off the Gust's line is missed by the plain Gust (+%.1f%%) and hit by the wide one (+%.1f%%)"
			% [1.1 + cap, hit[""], hit["air.gust.full_sail"]])
	# a bot wearing it (a test's: bots never wear loadouts in a match) casts the wide Gust through its own caster
	await _stage(7.0)
	_wear([])
	BendLoadout.wear(foe, ["air.gust.full_sail"], "", "air")
	var bg := _cast(BendCaster.of(foe), "air_gust", "gust")
	var bot_l := NpcBending.lock_for("air_gust", "gust", "normal", 0.0, foe)
	BendLoadout.clear(foe)
	var bot_l0 := NpcBending.lock_for("air_gust", "gust", "normal", 0.0, foe)
	_expect(bg != null and _near(bg.radius * 2.0, 2.4) and absf(bot_l / bot_l0 - 0.5 / 0.45) < 0.001,
			"Full Sail on a bot: its Gust %.1f m wide, its lock %.3f s for %.3f" % [bg.radius * 2.0 if bg != null else -1.0, bot_l, bot_l0])
	await _clear_air()


## The radius of `n`'s body's capsule (m; 0.35 when none is found).
func _capsule_r(n: Node) -> float:
	for c in n.find_children("*", "CollisionShape3D", true, false):
		var s := (c as CollisionShape3D).shape
		if s is CapsuleShape3D:
			return (s as CapsuleShape3D).radius
	return 0.35


# ---------------------------------------------------------------- Tailwind
func _tailwind() -> void:
	var got := {}
	for id: String in ["", "air.slice.tailwind"]:
		await _stage(7.0)
		_wear([id] if id != "" else [])
		var b := _cast(pc, "air_blast", "slice")
		var sent := b != null
		var carry_t := INF
		var t := 0.0
		while t < 1.0:
			await physics_frame
			t += 1.0 / Engine.physics_ticks_per_second
			if BendStatus.until(player, &"bend_carry_until") > 0.0:
				carry_t = t
				break
		var left := BendStatus.until(player, &"bend_carry_until")
		var pct := rules.pct_of(foe)
		# (the next Slice: carried while the wind lasts)
		var b2 := _cast(pc, "air_blast", "slice")
		var rec := BendEffects.last_of(pc)
		got[id] = {"bolt": sent, "carry_t": carry_t, "left": left, "pct": pct, "carried": bool(rec.get("carried", false)),
				"k": float((rec.get("spec", {}) as Dictionary).get("knock_mps", 0.0)) / float(SwayMoves.move("air_blast").bend.slice.knock_mps)}
		if b2 != null:
			b2.end("test")
		await _secs(0.6)
	var c: Dictionary = got[""]
	var w: Dictionary = got["air.slice.tailwind"]
	_expect(bool(c.bolt) and float(c.pct) > 0.0 and c.carry_t == INF and not bool(c.carried),
			"Tailwind not worn: the Slice lands (+%.1f%%) and charges no Carried wind (%s, %s)" % [c.pct, c.bolt, c.carry_t])
	_expect(bool(w.bolt) and float(w.pct) > 0.0 and w.carry_t < 0.5 and _near(float(w.left), 0.8, 0.05),
			"Tailwind: the Slice lands (+%.1f%%) and charges his Carried wind (%.2f s of it at the hit, %.2f s after the cast; %s)"
			% [w.pct, w.left, w.carry_t, w.bolt])
	_expect(_near(float(w.pct) / float(c.pct), 10.0 / 11.0, 0.01),
			"Tailwind: the Slice adds 10%% for the 11 it was (%.2f vs %.2f)" % [w.pct, c.pct])
	_expect(bool(w.carried) and _near(float(w.k), 1.15, 0.01), "Tailwind: the next Slice is a carried one (knock x%.2f)" % w.k)


# ---------------------------------------------------------------- Drift Guard
func _drift() -> void:
	var got := {}
	for id: String in ["", "air.guard.drift"]:
		await _stage(9.0)
		_wear([id] if id != "" else [])
		# (walking first, then E held: a direction pressed fresh with the guard up is the guard's roll, as ever)
		Input.action_press(&"move_forward")
		await _secs(0.4)
		sc.guard_override = true
		var up := await _until(func() -> bool: return sc.guard_up(), 2.0)
		var z: BendZone = sc._gzone
		var ps := z.perfect_s if z != null else -1.0
		await _secs(0.3)
		var p0 := player.global_position
		await _secs(0.5)
		var spd := Vector2(player.global_position.x - p0.x, player.global_position.z - p0.z).length() / 0.5
		var still_up := sc.guard_up()
		Input.action_release(&"move_forward")
		sc.guard_override = false
		got[id] = {"up": up < INF and still_up, "ps": ps, "mps": spd}
		await _secs(0.8)
	var c: Dictionary = got[""]
	var w: Dictionary = got["air.guard.drift"]
	_expect(bool(c.up) and float(c.mps) < 0.1, "Drift Guard not worn: with his Wind Guard up he stands (%.2f m/s)" % c.mps)
	_expect(bool(w.up) and _near(float(w.mps), AirTalents.DRIFT_MPS, 0.15),
			"Drift Guard: with his Wind Guard up (E held) he walks at %.2f m/s" % w.mps)
	_expect(_near(float(c.ps), 0.3) and _near(float(w.ps), 0.25), "Drift Guard: the Wind Guard's beat %.2f s (Classic %.2f)" % [w.ps, c.ps])


# ---------------------------------------------------------------- Eye of the Gale
## The foe's Slice at the player's raised Wind Guard (E held while `hold`): {perfect, swing (it circled him), circled_s, near
## (its farthest from him while circling), left (its speed when it left / its speed sent), along (deg off his aim as it left),
## carry (s of Carried wind right after the bounce)}.
func _bounce(hold_s: float, settle := 1.0) -> Dictionary:
	await _stage(8.0)
	sc.guard_override = true
	await _until(func() -> bool: return sc.guard_up(), 2.0)
	var z: BendZone = sc._gzone
	var b := _cast(BendCaster.of(foe), "air_blast", "slice")
	var v0 := b.velocity.length() if b != null else 0.0
	var res := {"perfect": false, "swing": false, "circled_s": 0.0, "near": 0.0, "left": 0.0, "along": 180.0, "carry": 0.0}
	var t := 0.0
	var bounced_at := INF
	while t < 2.0 and b != null and is_instance_valid(b) and not b.spent:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		if bounced_at == INF and z != null and is_instance_valid(z) and not z.results.is_empty():
			bounced_at = t
			res.perfect = z.results[0] == "perfect"
			res.carry = BendStatus.until(player, &"bend_carry_until")
		if bounced_at < INF and not is_instance_valid(b):
			break
		if bounced_at < INF and b.swinging():
			res.swing = true
			res.circled_s = float(res.circled_s) + 1.0 / Engine.physics_ticks_per_second
			res.near = maxf(float(res.near), Vector2(b.global_position.x - player.global_position.x,
					b.global_position.z - player.global_position.z).length())
		if bounced_at < INF and t - bounced_at >= hold_s and bool(sc.guard_override):
			sc.guard_override = false                 # (E let go)
		if bounced_at < INF and not b.swinging() and b.caster == player:
			var aim := BendZone.guard_aim(player, b.global_position)
			res.left = b.velocity.length() / maxf(v0, 0.01)
			res.along = rad_to_deg(b.velocity.angle_to(aim - b.global_position))
			break
	sc.guard_override = false
	if b != null and is_instance_valid(b):
		b.end("test")
	await _secs(settle)
	return res


func _eye() -> void:
	_wear([])
	var c := await _bounce(0.3)
	_wear(["air.guard.eye"])
	var w := await _bounce(0.3)
	var w_full := await _bounce(2.0)
	_wear([])
	_expect(bool(c.perfect) and not bool(c.swing) and _near(float(c.left), 1.2, 0.02) and float(c.along) < 5.0,
			"Eye of the Gale not worn: a perfect Wind Guard sends the Slice straight back along his aim at once (x%.2f, %.1f deg off)" % [c.left, c.along])
	_expect(bool(w.perfect) and bool(w.swing) and float(w.circled_s) >= 0.25 and float(w.circled_s) <= 0.4 and float(w.near) < 2.5,
			"Eye of the Gale: E held through the perfect guard, the Slice circles him (%.2f s, within %.1f m) till E is let go" % [w.circled_s, w.near])
	_expect(_near(float(w.left), 1.2, 0.02) and float(w.along) < 5.0,
			"Eye of the Gale: let go, it leaves along his aim at x%.2f (%.1f deg off)" % [w.left, w.along])
	_expect(bool(w_full.swing) and float(w_full.circled_s) <= AirTalents.EYE_S + 0.05 and float(w_full.circled_s) >= AirTalents.EYE_S - 0.05,
			"Eye of the Gale: held on, it circles %.2f s at most and leaves by itself" % w_full.circled_s)
	_expect(_near(float(c.carry), 0.8, 0.04) and _near(float(w.carry), 0.4, 0.04),
			"Eye of the Gale: the perfect guard's Carried wind lasts %.2f s (Classic %.2f)" % [w.carry, c.carry])


# ---------------------------------------------------------------- Rebound
func _rebound() -> void:
	var got := {}
	for id: String in ["", "air.guard.rebound"]:
		_wear([id] if id != "" else [])
		var bres := await _bounce(0.0, 0.2)
		# (the Slice readied and locked at once, the aim's button held, within 1 s of the perfect guard)
		sc.ready_spell("air_blast")
		sc.set_mode("air_blast", "slice")
		player.pitch = -0.25 * pitch_sign
		aim_at = Vector3.INF
		sc.held_override = true
		var began := await _until(func() -> bool: return sc.state != SwayCaster.State.IDLE, 1.0)
		var f0 := sc.fill
		sc.held_override = false
		await _secs(0.4)
		# (and the next one after it: the head start spent)
		sc.held_override = true
		await _until(func() -> bool: return sc.state != SwayCaster.State.IDLE, 1.0)
		var f1 := sc.fill
		sc.held_override = false
		await _secs(0.4)
		got[id] = {"perfect": bres.perfect, "began": began < INF, "f0": f0, "f1": f1}
	var c: Dictionary = got[""]
	var w: Dictionary = got["air.guard.rebound"]
	_expect(bool(c.perfect) and bool(c.began) and float(c.f0) < 0.1, "Rebound not worn: the Slice after a perfect Wind Guard begins empty (%.2f)" % c.f0)
	_expect(bool(w.perfect) and bool(w.began) and _near(float(w.f0), 0.4, 0.06) and float(w.f1) < 0.1,
			"Rebound: the Slice after a perfect Wind Guard begins %.2f full, the next one empty (%.2f)" % [w.f0, w.f1])
	# the held guard's longest stand
	var hold := {}
	for id: String in ["", "air.guard.rebound"]:
		await _stage(9.0)
		_wear([id] if id != "" else [])
		sc.guard_override = true
		await _until(func() -> bool: return sc.guard_up(), 2.0)
		var stood := await _until(func() -> bool: return not sc.guard_up(), 4.0)
		sc.guard_override = false
		hold[id] = stood
		await _secs(0.6)
	_expect(_near(float(hold[""]), 2.5, 0.15) and _near(float(hold["air.guard.rebound"]), 2.0, 0.15),
			"Rebound: E held, his Wind Guard drops after %.2f s (Classic %.2f)" % [hold["air.guard.rebound"], hold[""]])
	# a bot wearing it: its next Slice lock after a perfect Wind Guard of its own begins part full
	await _stage(8.0)
	_wear([])
	BendLoadout.wear(foe, ["air.guard.rebound"], "", "air")
	var nb := foe.brain.bending
	foe.set_meta(AirTalents.REBOUND_META, BendStatus.now())
	nb.begin("air_blast", "slice")
	var bf := nb.lock_t / maxf(nb.lock_s, 0.001)
	nb._cancel()
	BendLoadout.clear(foe)
	foe.set_meta(AirTalents.REBOUND_META, BendStatus.now())
	nb.begin("air_blast", "slice")
	var bf0 := nb.lock_t / maxf(nb.lock_s, 0.001)
	nb._cancel()
	if foe.has_meta(AirTalents.REBOUND_META):
		foe.remove_meta(AirTalents.REBOUND_META)
	_expect(_near(bf, 0.4, 0.01) and bf0 < 0.01, "Rebound on a bot: its Slice lock after a perfect guard begins %.2f full (not worn %.2f)" % [bf, bf0])
