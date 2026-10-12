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
##   the Beat           a held Slice let go within 0.2 s of its full lock is on the Beat (its hit info says so) only for a wearer
##                      of a technique that reads it; let go later, or clicked, it is not; Classic's casts never carry it
##   Carry the Edge     a Beat Slice with Carried wind charged is carried (x1.15) and leaves the wind charged; let go late, or not
##                      worn, it spends it; a bot wearing it (beat_rate 1) keeps it too
##   Carrying Wind      a Beat Gust takes a loose stone lying in its way and throws it on 6 m along its way, a pebble (+5%) at a
##                      foe standing there; a Gust let go late, or not worn, leaves the stone lying
##   Peak Wind          key 3 held through a Leap's full lock and let go on the Beat: his Carried wind charged fresh at the top
##                      (as high a Leap as ever); key 3 tapped (a click), or not worn, no fresh charge at the top
##   Near Miss          his Slip 8.5 m/s (9.5); a Slice passing 1.3 m off in his Slip charges his Carried wind (not worn: only
##                      within 1.2 m, a 0.9 m one does)
##   Second Wind        his Patch begun within 0.8 s of a dash's end (a real Slip) locks 1.25 s, later 1.6 (1.5); a bot's too
##   Dragon Fire        his Gust through his fire mate's Fire Wall sends one fire front on (not worn: none; a foe's wall: none,
##                      it takes the flame as ever); the front strikes a foe it runs into for 6% (the node's class, his alone)
##   Dust Cloud         not worn, 4 has one move; worn, 4 tapped twice readies it (the hotbar's own taps), named, the Wind
##                      Wall's pose, lock 0.9 s; cast through the real lock: a 3 m cloud for 2.5 s 2-6 m off where he aims, hiding
##                      him from the foe; a new one ends the old; his Wind Wall 3.5 s (4); a bot wearing it casts it (BendCast)
##   Frostwind          his Gust or Wind Ball over a puddle turns it to crust (a snow ridge 0.4 x 3 m across its way, 4 s; not
##                      worn: it stays a puddle); two of his at once; a floor wave stops at it; fire melts it back into the
##                      puddle; over a grate: no water source till a Fire Wall on it melts it; steam his Gust crosses clears;
##                      his Wind Wall drops water as shards; his Wind Wall 3.5 s; a bot wearing it freezes a puddle too
##   Hail Ball          (with the set) his Wind Ball onto the deck 1.2 m before the foe: a hailstone strikes him there for 2%,
##                      no knock, no hurt (not worn: nothing)
##   Frost Gust         his Gust puts out a foe's Fire Wall and burning ground (not worn: it takes the flame, they burn on);
##                      1.8 m wide
##   Rime Wall          his Wind Wall pushes at 3.2 m/s (4); as it ends a 3 m crust lies where it stood for 3 s
##   Blizzard           4 tapped twice; lock 0.9 s; through the real lock a 2.5 m snow column for 3 s where he aims: it hides
##                      him, freezes a puddle in it, the foe in it gains 1% each 0.5 s, 6 at most, no knock, no hurt; fire melts
##                      it out in about a second; one at a time; his Wind Wall 15% shorter; a bot wearing it casts it
##   Whiteout           his Patch 1.7 s (1.5); on his own crust or in his own snow his locks fill x1.15 (a Slice's real fill);
##                      a bot's on its own crust too
## Every talent here is live in data/bending/loadout_apply.json (BendLoadout.why_not ""), and a body that wears nothing reads the
## game's own numbers. Last line "TALENTS AIR PASSED (n checks)" or "... FAILED".

const NAME := "TALENTS AIR"
const LIMIT_S := 600.0
const MINE := ["air.gust.full_sail", "air.slice.tailwind", "air.guard.drift", "air.guard.eye", "air.guard.rebound",
		"air.slice.carry_edge", "air.gust.carrying", "air.leap.peak_wind", "air.slip.near_miss", "air.patch.second_wind",
		"air.gust.dragon_fire", "air.slot.dust", "air.set.frostwind", "air.frost.hail_ball", "air.frost.frost_gust",
		"air.frost.rime_wall", "air.frost.blizzard", "air.frost.whiteout"]

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
	Input.action_release(&"weapon_3")
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
	var way := Vector3.RIGHT                         # (along the deck's long way, on its middle line: 5 m from every grate)
	var mid := _home
	player.global_position = mid - way * gap * 0.5
	player.velocity = Vector3.ZERO
	foe.global_position = mid + way * gap * 0.5
	foe.velocity = Vector3.ZERO
	foe.face_point(player.global_position)
	var k := 0
	for e: Dictionary in mode.extras:
		if e.get("bot") is NpcFighter and e.bot != foe:
			# (the other bots off the line, still: 3 m to its side, between the grates)
			(e.bot as NpcFighter).global_position = mid + Vector3(-2.0 + 4.0 * k, 0.0, 3.0 if k % 2 == 0 else -3.0)
			(e.bot as NpcFighter).velocity = Vector3.ZERO
			k += 1
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
	_home = Vector3(4.0, FormEffects.ground_at(player, Vector3(4.0, player.global_position.y, 0.0)).y, 0.0)
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
	if _on("air.slice.carry_edge"):
		await _carry_edge()
	if _on("air.gust.carrying"):
		await _carrying()
	if _on("air.leap.peak_wind"):
		await _peak_wind()
	if _on("air.slip.near_miss"):
		await _near_miss()
	if _on("air.patch.second_wind"):
		await _second_wind()
	if _on("air.gust.dragon_fire"):
		await _dragon_fire()
	if _on("air.slot.dust"):
		await _dust()
	if _on("air.set.frostwind"):
		await _frostwind()
	if _on("air.frost.hail_ball"):
		await _hail_ball()
	if _on("air.frost.frost_gust"):
		await _frost_gust()
	if _on("air.frost.rime_wall"):
		await _rime_wall()
	if _on("air.frost.blizzard"):
		await _blizzard()
	if _on("air.frost.whiteout"):
		await _whiteout()
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


# ---------------------------------------------------------------- the Beat
## The player's `m` at `md` locked through the aim's button (the crosshair where _aim holds it) and let go `after_full` s after
## the lock filled (a negative: let go before full, a click); the cast's record once it landed (BendEffects.last_of) and
## whether its hit info was on the Beat.
func _held_cast(m: String, md: String, after_full: float) -> Dictionary:
	sc.ready_spell(m)
	sc.set_mode(m, md)
	await _ticks(2)
	var n0 := _casts
	sc.held_override = true
	if after_full < 0.0:
		await _ticks(3)
		sc.held_override = false                      # (a click: let go before full, it goes the moment it is)
	var full := await _until(func() -> bool: return sc.state == SwayCaster.State.FULL or _casts > n0, 3.0)
	if after_full >= 0.0:
		await _secs(after_full)
		sc.held_override = false
	await _until(func() -> bool: return _casts > n0, 1.0)
	await _secs(0.35)                                 # (its strike: the effect lands)
	var rec := BendEffects.last_of(pc)
	var inf: Dictionary = (rec.get("spec", {}) as Dictionary).get("_info", {})
	return {"full": full < INF, "rec": rec, "beat": bool(inf.get("beat", false)), "has_beat": inf.has("beat")}


var _casts := 0


func _count_cast(_m: String, _md: String) -> void:
	_casts += 1


func _carry_edge() -> void:
	if not sc.cast_released.is_connected(_count_cast):
		sc.cast_released.connect(_count_cast)
	var got := {}
	for k: Array in [["", 0.0, "c"], ["air.slice.carry_edge", 0.0, "w"], ["air.slice.carry_edge", 0.4, "late"], ["air.slice.carry_edge", -1.0, "click"]]:
		await _stage(8.0)
		_wear([k[0]] if String(k[0]) != "" else [])
		player.set_meta(&"bend_carry_until", BendStatus.now() + 3.0)     # (Carried wind charged, long enough for any release)
		var r := await _held_cast("air_blast", "slice", float(k[1]))
		var rec: Dictionary = r.rec
		got[String(k[2])] = {"full": r.full, "beat": r.beat, "has_beat": r.has_beat, "carried": bool(rec.get("carried", false)),
				"kept": BendStatus.until(player, &"bend_carry_until") > 0.0}
		await _secs(0.6)
	var c: Dictionary = got["c"]
	var w: Dictionary = got["w"]
	var late: Dictionary = got["late"]
	var click: Dictionary = got["click"]
	_expect(bool(c.full) and not bool(c.has_beat) and bool(c.carried) and not bool(c.kept),
			"the Beat, not worn: a Slice let go at its full lock carries no Beat in its hit info; carried, it spends the wind")
	_expect(bool(w.full) and bool(w.beat), "the Beat: a Carry the Edge wearer's Slice let go at its full lock is on the Beat")
	_expect(not bool(late.beat) and not bool(click.beat), "the Beat: let go 0.4 s after full, or clicked, it is not (%s, %s)" % [late.beat, click.beat])
	_expect(bool(w.carried) and bool(w.kept), "Carry the Edge: the Beat Slice is carried and leaves his Carried wind charged")
	_expect(bool(late.carried) and not bool(late.kept) and bool(click.carried) and not bool(click.kept),
			"Carry the Edge: a Slice let go late, or clicked, spends it as ever")
	# a bot wearing it: its Slice let go at its full lock, on the Beat at beat_rate 1 (a test's)
	await _stage(8.0)
	_wear([])
	BendLoadout.wear(foe, ["air.slice.carry_edge"], "", "air")
	var pr := NpcBending.preset_of("normal")
	pr["beat_rate"] = 1.0
	var nb := foe.brain.bending
	BendZone.carry_wind(foe)
	nb.begin("air_blast", "slice")
	nb.lock_t = nb.lock_s
	nb._release()
	var brec := BendEffects.last_of(BendCaster.of(foe))
	var bkept := BendStatus.until(foe, &"bend_carry_until") > 0.0
	BendLoadout.clear(foe)
	BendZone.carry_wind(foe)
	nb.begin("air_blast", "slice")
	nb.lock_t = nb.lock_s
	nb._release()
	var bkept0 := BendStatus.until(foe, &"bend_carry_until") > 0.0
	pr.erase("beat_rate")
	_expect(bool(brec.get("carried", false)) and bkept and not bkept0,
			"Carry the Edge on a bot: its Beat Slice keeps its Carried wind (not worn: spent)")
	await _clear_air()


## A loose stone lying on the deck at `at` (whoever's: the foe's here).
## The bolts made while it listens: [kind, tag] each (_on_added).
var _made: Array = []


func _on_added(n: Node) -> void:
	if n is BendBolt:
		_made.append([(n as BendBolt).kind, String((n as BendBolt).info.get("tag", ""))])


func _loose_stone(at: Vector3) -> FormStone:
	var g := FormEffects.ground_at(player, at)
	var s := FormStone.ball(current_scene, g, {"radius_m": 0.2, "mass_kg": 20.0, "rise_s": 0.01, "life_s": 30.0, "sink_s": 1.0}, 7, "stone")
	s.state = FormStone.State.RESTING
	s.base = Transform3D(Basis.IDENTITY, g + Vector3.UP * 0.22)
	s.global_transform = s.base
	s.freeze = false
	FormStone.make_loose(s, foe)
	return s


func _carrying() -> void:
	if not sc.cast_released.is_connected(_count_cast):
		sc.cast_released.connect(_count_cast)
	var got := {}
	for k: Array in [["", 0.0, "c"], ["air.gust.carrying", 0.0, "w"], ["air.gust.carrying", 0.3, "late"]]:
		await _stage(10.0)
		_wear([k[0]] if String(k[0]) != "" else [])
		var way := (foe.global_position - player.global_position)
		way.y = 0.0
		way = way.normalized()
		var st := _loose_stone(player.global_position + way * 3.0)
		foe.global_position = player.global_position + way * 8.0      # (the stone thrown on 6 m from 3 m: it reaches him)
		foe.velocity = Vector3.ZERO
		aim_at = NpcSenses.chest_of(foe)
		rules.reset_pct(foe, 0.0)
		await _secs(0.4)
		_made.clear()
		node_added.connect(_on_added)
		var log0 := BendR3.hits_log.size()
		var r := await _held_cast("air_gust", "gust", float(k[1]))
		await _secs(0.8)
		node_added.disconnect(_on_added)
		var peb_kind := ""
		for e0: Array in _made:
			if String(e0[1]) == "rock_jab/pebbles":
				peb_kind = String(e0[0])
		var peb_hit := false
		for i in range(mini(log0, BendR3.hits_log.size()), BendR3.hits_log.size()):
			var e: Dictionary = BendR3.hits_log[i]
			peb_hit = peb_hit or (e.get("n") == foe and e.get("by") == player and String(e.get("tag", "")) == "rock_jab/pebbles")
		got[String(k[2])] = {"beat": r.beat, "taken": not is_instance_valid(st) or st.is_queued_for_deletion(), "pebble": peb_kind != "",
				"kind": peb_kind, "pct": rules.pct_of(foe), "peb_hit": peb_hit}
		if is_instance_valid(st):
			st.queue_free()
		await _secs(0.4)
	var c: Dictionary = got["c"]
	var w: Dictionary = got["w"]
	var late: Dictionary = got["late"]
	_expect(not bool(c.taken) and not bool(c.pebble), "Carrying Wind not worn: the Gust passes the loose stone, it lies where it was")
	_expect(bool(w.beat) and bool(w.taken) and bool(w.pebble) and String(w.kind) == "stone",
			"Carrying Wind: the Beat Gust takes the loose stone and throws it on, a stone (%s)" % w.kind)
	var d := float(RingRules.class_of("rock_jab/pebbles").get("d", 5.0)) * RingRules.stock_num("pct_scale", 1.0)
	_expect(bool(w.peb_hit) and float(w.pct) >= d - 0.01,
			"Carrying Wind: the pebble reaches the foe 8 m off, a hit of his (rock_jab/pebbles: %.1f%%; +%.1f%% in all with the Gust's own)" % [d, w.pct])
	_expect(not bool(late.beat) and not bool(late.taken), "Carrying Wind: a Gust let go 0.3 s after full leaves the stone lying")


## The player leaps by key 3 (a second tap within key3_min_s: the Leap), key 3 held through the full lock and let go
## `after_full` s after it (negative: tapped, a click): {beat, top_left (s of Carried wind as he turns to fall), rise (m)}.
func _leap(after_full: float) -> Dictionary:
	var y0 := player.global_position.y
	Input.action_press(&"weapon_3")
	sc.key3_press()
	await _ticks(2)
	sc.key3_press()                                   # (the second tap: the travel move, the Leap)
	if after_full < 0.0:
		await _ticks(2)
		Input.action_release(&"weapon_3")
	var full := await _until(func() -> bool: return sc.state == SwayCaster.State.FULL or not player.is_on_floor(), 2.0)
	if after_full >= 0.0:
		await _secs(after_full)
		Input.action_release(&"weapon_3")
	var res := {"full": full < INF, "beat": false, "top_left": -1.0, "rise": 0.0, "move": ""}
	var rose := false
	var t := 0.0
	while t < 2.0:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		var inf: Dictionary = (BendEffects.last_of(pc).get("spec", {}) as Dictionary).get("_info", {})
		if String(inf.get("move", "")) == "air_jump":
			res.move = "air_jump"
			res.beat = bool(inf.get("beat", false))
		res.rise = maxf(float(res.rise), player.global_position.y - y0)
		if player.velocity.y > 0.5:
			rose = true
		elif rose and player.velocity.y <= 0.0:
			await physics_frame
			res.top_left = BendStatus.until(player, &"bend_carry_until")
			break
	Input.action_release(&"weapon_3")
	await _until(func() -> bool: return player.is_on_floor(), 3.0)
	await _secs(0.5)
	return res


func _peak_wind() -> void:
	var got := {}
	for k: Array in [["", 0.0, "c"], ["air.leap.peak_wind", 0.0, "w"], ["air.leap.peak_wind", -1.0, "tap"]]:
		await _stage(10.0)
		aim_at = Vector3.INF
		_wear([k[0]] if String(k[0]) != "" else [])
		got[String(k[2])] = await _leap(float(k[1]))
	var c: Dictionary = got["c"]
	var w: Dictionary = got["w"]
	var tap: Dictionary = got["tap"]
	_expect(String(c.move) == "air_jump" and String(w.move) == "air_jump" and String(tap.move) == "air_jump",
			"Peak Wind: key 3 tapped twice is the Leap (%s, %s, %s)" % [c.move, w.move, tap.move])
	_expect(bool(w.beat) and not bool(c.beat) and not bool(tap.beat), "Peak Wind: key 3 held through the full lock and let go is a Beat Leap; tapped it is not")
	_expect(_near(float(w.top_left), 0.8, 0.06) and float(c.top_left) < 0.7 and float(tap.top_left) < 0.7,
			"Peak Wind: at the top of the Beat Leap his Carried wind is fresh (%.2f s left; Classic %.2f, tapped %.2f)" % [w.top_left, c.top_left, tap.top_left])
	_expect(absf(float(w.rise) - float(c.rise)) < 0.15, "Peak Wind: the Leap rises as high as ever (%.2f m, Classic %.2f m)" % [w.rise, c.rise])


# ---------------------------------------------------------------- Near Miss
## The player Slips (the game's dash: back from the foe) and the foe's Slice passes `off` m beside him as he goes: {mps (the
## Slip's flat speed), charged (Carried wind charged within 0.15 s, before the Slip's own end could)}.
func _slip_past(off: float) -> Dictionary:
	await _stage(10.0)
	aim_at = NpcSenses.chest_of(foe)
	await _ticks(4)
	for k: StringName in [&"bend_carry_until", &"bend_slip_until"]:
		if player.has_meta(k):
			player.remove_meta(k)
	BendEffects.apply(pc, "evade", "slip", (SwayMoves.move("evade").bend as Dictionary).slip)
	var v: Vector3 = BendEffects.last_of(pc).get("v", Vector3.ZERO)
	var way := foe.global_position - player.global_position
	way.y = 0.0
	way = way.normalized()
	var side := Vector3.UP.cross(way).normalized()
	var b := _cast(BendCaster.of(foe), "air_blast", "slice")
	if b != null:
		var ch := NpcSenses.chest_of(player)
		b.global_position = ch + way * 3.0 + side * off
		b.velocity = -way * b.velocity.length()
	var charged := false
	for i in ceili(0.15 * Engine.physics_ticks_per_second):
		await physics_frame
		charged = charged or BendStatus.until(player, &"bend_carry_until") > 0.0
	if b != null and is_instance_valid(b):
		b.end("test")
	await _secs(0.6)
	return {"mps": Vector2(v.x, v.z).length(), "charged": charged}


func _near_miss() -> void:
	_wear([])
	var c := await _slip_past(1.3)
	var c_close := await _slip_past(0.9)
	_wear(["air.slip.near_miss"])
	var w := await _slip_past(1.3)
	_wear([])
	_expect(_near(float(c.mps), 9.5, 0.05) and _near(float(w.mps), 8.5, 0.05),
			"Near Miss: his Slip goes %.1f m/s (Classic %.1f)" % [w.mps, c.mps])
	_expect(bool(c_close.charged) and not bool(c.charged),
			"Near Miss not worn: a Slice 0.9 m off in his Slip charges his Carried wind, one 1.3 m off does not (1.2 m)")
	_expect(bool(w.charged), "Near Miss: a Slice 1.3 m off in his Slip charges it (1.44 m)")


# ---------------------------------------------------------------- Second Wind
func _second_wind() -> void:
	await _stage(10.0)
	sc.set_mode("patch", "patch")
	var got := {}
	for id: String in ["", "air.patch.second_wind"]:
		_wear([id] if id != "" else [])
		if player.has_meta(&"bend_dash_end"):
			player.remove_meta(&"bend_dash_end")
		# (a real Slip: its end is the dash's end the Patch counts from)
		BendEffects.apply(pc, "evade", "slip", (SwayMoves.move("evade").bend as Dictionary).slip)
		var ended := await _until(func() -> bool: return player.has_meta(&"bend_dash_end"), 1.5)
		var quick := sc._lock_time("patch", null, 0.0, 0.0)
		await _secs(1.0)
		var later := sc._lock_time("patch", null, 0.0, 0.0)
		got[id] = {"ended": ended < INF, "quick": quick, "later": later,
				"bot": NpcBending.lock_for("patch", "patch", "normal", 0.0, player)}
		await _secs(0.4)
	var c: Dictionary = got[""]
	var w: Dictionary = got["air.patch.second_wind"]
	_expect(bool(c.ended) and bool(w.ended) and _near(float(c.quick), float(c.later), 0.001),
			"Second Wind not worn: Patch locks the same right after a dash and later (%.2f s)" % c.quick)
	_expect(_near(float(w.quick) / float(c.quick), 1.25 / 1.5, 0.002) and _near(float(w.later) / float(c.later), 1.6 / 1.5, 0.002),
			"Second Wind: Patch begun within 0.8 s of a dash locks %.2f s, later %.2f s (Classic %.2f: 1.25, 1.6 for 1.5)" % [w.quick, w.later, c.quick])
	# (a bot wearing it: its own Patch lock read the same way)
	BendLoadout.wear(foe, ["air.patch.second_wind"], "", "air")
	foe.set_meta(&"bend_dash_end", BendStatus.now())
	var bq := NpcBending.lock_for("patch", "patch", "normal", 0.0, foe)
	foe.set_meta(&"bend_dash_end", BendStatus.now() - 5.0)
	var bl := NpcBending.lock_for("patch", "patch", "normal", 0.0, foe)
	BendLoadout.clear(foe)
	var b0 := NpcBending.lock_for("patch", "patch", "normal", 0.0, foe)
	_expect(b0 > 0.0 and _near(bq / b0, 1.25 / 1.5, 0.002) and _near(bl / b0, 1.6 / 1.5, 0.002),
			"Second Wind on a bot: its Patch lock %.2f s after a dash, %.2f s later (not worn %.2f: x1.25/1.5, x1.6/1.5)" % [bq, bl, b0])
	_wear([])


# ---------------------------------------------------------------- Dragon Fire
## The fire mate's Fire Wall across the line from the player to the foe, `at` m from the player (BendZone.make, as his cast
## makes it); `own`: the foe's own instead (a foe's wall).
func _fire_wall_at(m: float, owner: NpcFighter) -> BendZone:
	var way := foe.global_position - player.global_position
	way.y = 0.0
	way = way.normalized()
	var at := FormEffects.ground_at(player, player.global_position + way * m)
	var spec: Dictionary = (SwayMoves.move("fire_wall").bend as Dictionary).wall
	return BendZone.make(owner, "fire_wall", at, spec, way)


func _gust_through(owner: NpcFighter) -> Dictionary:
	await _stage(10.0)
	var z := _fire_wall_at(3.5, owner)
	await _ticks(4)
	_made.clear()
	node_added.connect(_on_added)
	var g := _cast(pc, "air_gust", "gust")
	await _secs(0.5)
	node_added.disconnect(_on_added)
	var fronts := 0
	var kind := ""
	for e0: Array in _made:
		if String(e0[1]) == AirTalents.FRONT_TAG:
			fronts += 1
			kind = String(e0[0])
	var burning := g != null and is_instance_valid(g) and g.burning
	if is_instance_valid(z):
		z.queue_free()
	await _secs(0.5)
	return {"fronts": fronts, "kind": kind, "burning": burning}


func _dragon_fire() -> void:
	var mate: NpcFighter = null
	for e: Dictionary in mode.extras:
		if e.get("bot") is NpcFighter and BendCaster.same_team(e.bot, player):
			mate = e.bot
	_expect(mate != null and BendPoses.element_of(mate) == "fire", "Dragon Fire: a fire mate on the player's side")
	if mate == null:
		return
	mate.global_position = _home + Vector3(0.0, 0.0, 6.0)
	_wear([])
	var c := await _gust_through(mate)
	_wear(["air.gust.dragon_fire"])
	var w := await _gust_through(mate)
	var f := await _gust_through(foe)
	_wear([])
	_expect(int(c.fronts) == 0, "Dragon Fire not worn: his Gust through his mate's Fire Wall passes it as ever (no front)")
	_expect(int(w.fronts) == 1 and String(w.kind) == "fire",
			"Dragon Fire: his Gust through his mate's Fire Wall sends one fire front on (%d, %s)" % [w.fronts, w.kind])
	_expect(int(f.fronts) == 0, "Dragon Fire: a foe's fire wall makes no front (his Gust takes its flame as ever)")
	# the front's hit: 6% and a set knock of 6, his (the class the node adds), at the foe 3 m on, the deck clear
	await _stage(8.0)
	_wear(["air.gust.dragon_fire"])
	var way := foe.global_position - player.global_position
	way.y = 0.0
	var log0 := BendR3.hits_log.size()
	var pct0 := rules.pct_of(foe)
	AirTalents.fire_front(player, foe.global_position - way.normalized() * 3.0, way)
	await _secs(0.6)
	var hit := false
	for i in range(mini(log0, BendR3.hits_log.size()), BendR3.hits_log.size()):
		var e: Dictionary = BendR3.hits_log[i]
		hit = hit or (e.get("n") == foe and e.get("by") == player and String(e.get("tag", "")) == AirTalents.FRONT_TAG)
	var d := 6.0 * RingRules.stock_num("pct_scale", 1.0)
	_expect(hit and _near(rules.pct_of(foe) - pct0, d, 0.05),
			"Dragon Fire: the front strikes the foe it runs into, his, +%.2f%% (its class: 6 x the scale = %.2f)" % [rules.pct_of(foe) - pct0, d])
	_expect(BendLoadout.worn_class(foe, AirTalents.FRONT_TAG).is_empty() and RingRules.class_of(AirTalents.FRONT_TAG).is_empty(),
			"Dragon Fire: the front's class is the wearer's alone (none in the data, none for a body that wears nothing)")
	_wear([])


# ---------------------------------------------------------------- Dust Cloud
## The player's dust zones standing now.
func _dusts(by: Node) -> Array:
	var out: Array = []
	for z in get_nodes_in_group(BendZone.GROUP):
		var bz := z as BendZone
		if bz != null and bz.kind == "dust" and bz.owner_node == by and not bz.is_queued_for_deletion():
			out.append(bz)
	return out


func _dust() -> void:
	if not sc.cast_released.is_connected(_count_cast):
		sc.cast_released.connect(_count_cast)
	var hb := Hotbar.find(player)
	var key4: Array = Bending.keys("air")[3]
	# not worn: 4 has one move, a double tap is nothing new
	await _stage(10.0)
	_wear([])
	_expect(sc.my_modes("air_wall") == ["wall"] and Bending.other_move(key4, "air_wall", "wall", player).is_empty(),
			"Dust Cloud not worn: the Wind Wall's key has one move (%s)" % [sc.my_modes("air_wall")])
	var w0 := _wall_life()
	# worn: 4 tapped twice readies the Dust Cloud
	_wear(["air.slot.dust"])
	var other := Bending.other_move(key4, "air_wall", "wall", player)
	var tapped := ""
	if hb != null:
		hb._key_tap(3)
		await _ticks(2)
		hb._key_tap(3)
		await _ticks(2)
		tapped = sc.base_mode_of("air_wall")
	_expect(String(other.get("mode", "")) == "dust" and (hb == null or (sc.readied_spell == "air_wall" and tapped == "dust")),
			"Dust Cloud: 4 tapped twice readies it (%s, %s)" % [other, tapped])
	_expect(SwayCaster.mode_label("air_wall", "dust") == "Dust Cloud" and sc.spell_label("air_wall").contains("Dust"),
			"Dust Cloud: named on the bar (%s)" % sc.spell_label("air_wall"))
	_expect(BendPoses.pick("air_wall", "dust", "air", player) == BendPoses.pick("air_wall", "wall", "air", player),
			"Dust Cloud: cast with the Wind Wall's own pose")
	# cast through the real lock (the aim's button held to full, let go)
	sc.set_mode("air_wall", "dust")
	var lock_d := sc._lock_time("air_wall", null, 0.0, 0.0)
	sc.set_mode("air_wall", "wall")
	var lock_w := sc._lock_time("air_wall", null, 0.0, 0.0)
	_expect(_near(lock_d / lock_w, 0.9 / 0.8, 0.002), "Dust Cloud: its lock 0.9 s (%.3f; the Wind Wall's %.3f)" % [lock_d, lock_w])
	await _held_cast("air_wall", "dust", 0.05)
	var dz := _dusts(player)
	var z: BendZone = dz[0] if dz.size() == 1 else null
	var off := Vector2(z.global_position.x - player.global_position.x, z.global_position.z - player.global_position.z).length() if z != null else -1.0
	_expect(z != null and _near(z.radius, 3.0) and _near(z.life_s, 2.5) and off >= 1.9 and off <= 6.1,
			"Dust Cloud: a 3 m dust cloud for 2.5 s placed %.1f m off where he aims (2-6 m, never round him)" % off)
	_expect(NpcBendCaster.hidden(foe, player), "Dust Cloud: it hides him from the foe behind it (a bot's aim scatters there)")
	await _held_cast("air_wall", "dust", 0.05)
	await _ticks(3)
	_expect(_dusts(player).size() == 1 and (z == null or not is_instance_valid(z) or z.is_queued_for_deletion() or z.life_s <= z.t + 0.6),
			"Dust Cloud: a new one ends his old one (%d standing)" % _dusts(player).size())
	var w1 := _wall_life()
	_expect(_near(w0, 4.0) and _near(w1, 3.5), "Dust Cloud: his Wind Wall stands %.1f s (Classic %.1f)" % [w1, w0])
	sc.set_mode("air_wall", "wall")
	_wear([])
	_expect(sc.my_modes("air_wall") == ["wall"] and sc.base_mode_of("air_wall") == "wall", "Dust Cloud taken off: the key has its one move again")
	# a bot wearing it casts it through its own path (BendCast)
	BendLoadout.wear(foe, ["air.slot.dust"], "", "air")
	var ok := BendCast.cast(BendCaster.of(foe), "air_wall", "dust", player, player.global_position)
	var fd := _dusts(foe).size()
	BendLoadout.clear(foe)
	var ok0 := BendCast.cast(BendCaster.of(foe), "air_wall", "dust", player, player.global_position)
	_expect(ok and fd == 1 and not ok0, "Dust Cloud on a bot: it casts it through its own path (not worn: nothing)")
	await _clear_air()


## The player's Wind Wall's life now (cast through BendEffects, as his release does).
func _wall_life() -> float:
	var known := {}
	for z in get_nodes_in_group(BendZone.GROUP):
		known[z.get_instance_id()] = true
	BendEffects.apply(pc, "air_wall", "wall", (SwayMoves.move("air_wall").bend as Dictionary).wall)
	var life := -1.0
	for z in get_nodes_in_group(BendZone.GROUP):
		if not known.has(z.get_instance_id()) and (z as BendZone).kind == "wind_wall":
			life = (z as BendZone).life_s
			(z as BendZone).queue_free()
	return life


# ---------------------------------------------------------------- Frostwind (the skill set)
## The crusts of `by` standing (rising or up).
func _crusts(by: Node) -> Array:
	var out: Array = []
	for w in get_nodes_in_group(FormRaised.GROUP):
		var fr := w as FormRaised
		if fr != null and fr.state != FormRaised.State.CRUMBLING and int(fr.get_meta(AirTalents.CRUST_META, 0)) == by.get_instance_id():
			out.append(fr)
	return out


## A puddle of the mate's `m` m ahead of the player toward the foe (as a Parry's melt or a Downpour leaves one).
func _puddle_ahead(m: float) -> BendZone:
	var way := foe.global_position - player.global_position
	way.y = 0.0
	return BendZone.make(foe, "puddle", FormEffects.ground_at(player, player.global_position + way.normalized() * m),
			{"radius_m": 0.9, "life_s": 8.0}, way)


## The player's `m` `md` cast at the foe (the game's own cast) over a puddle 3 m ahead: {puddle (still there), crusts (his),
## crust (the newest: its height, width, life, across the way)}.
func _over_puddle(m: String, md: String) -> Dictionary:
	await _stage(9.0)
	var pz := _puddle_ahead(3.0)
	await _ticks(3)
	var b := _cast(pc, m, md)
	var dir := b.velocity if b != null else Vector3.FORWARD
	await _secs(0.5)
	var cs := _crusts(player)
	var c: FormRaised = cs[-1] if not cs.is_empty() else null
	var res := {"puddle": is_instance_valid(pz) and not pz.is_queued_for_deletion() and pz.is_in_group(Bending.POOLS),
			"crusts": cs.size(), "h": c.size.y if c != null else -1.0, "w": c.size.x if c != null else -1.0,
			"life": c.life_s if c != null else -1.0, "matter": c.matter if c != null else "",
			"across": absf(c.global_basis.x.normalized().dot(Vector3(dir.x, 0.0, dir.z).normalized())) if c != null else 1.0,
			"at": c.global_position if c != null else Vector3.INF}
	if is_instance_valid(pz):
		pz.queue_free()
	return res


func _clear_crusts() -> void:
	for w in get_nodes_in_group(FormRaised.GROUP):
		if (w as FormRaised).has_meta(AirTalents.CRUST_META):
			(w as FormRaised).queue_free()
	await _ticks(2)


func _frostwind() -> void:
	_wear([])
	var c := await _over_puddle("air_gust", "gust")
	_expect(bool(c.puddle) and int(c.crusts) == 0, "Frostwind not worn: his Gust crosses a puddle and it stays a puddle")
	_wear(["air.set.frostwind"])
	var w := await _over_puddle("air_gust", "gust")
	_expect(not bool(w.puddle) and int(w.crusts) == 1 and String(w.matter) == "snow" and _near(float(w.h), 0.4) and _near(float(w.w), 3.0)
			and _near(float(w.life), 4.0) and float(w.across) < 0.1,
			"Frostwind: his Gust over a puddle turns it to crust: an ice ridge 0.4 m high, 3 m long across its way, 4 s (%s)" % [w])
	var wb := await _over_puddle("air_blast", "ball")
	_expect(not bool(wb.puddle) and int(wb.crusts) == 2, "Frostwind: his Wind Ball over a puddle does too (%d of his)" % wb.crusts)
	var w3 := await _over_puddle("air_gust", "gust")
	_expect(int(w3.crusts) == 2, "Frostwind: two crusts of his at once, the oldest goes (%d)" % w3.crusts)
	await _clear_crusts()

	# a floor wave stops at a crust; fire melts it back into the puddle it was
	var w4 := await _over_puddle("air_gust", "gust")
	var crust: FormRaised = (_crusts(player) as Array)[-1] if not _crusts(player).is_empty() else null
	var way := foe.global_position - player.global_position
	way.y = 0.0
	way = way.normalized()
	var at: Vector3 = w4.at
	var stone_w := BendEffects.floor_wave(BendCaster.of(foe), {}, {"do": "floor_wave", "kind": "stone", "mps": 18.0, "range_m": 8.0, "width_m": 1.6,
			"height_m": 0.9, "damage": 8.0, "knock_mps": 4.0})
	if stone_w != null:
		stone_w.global_position = Vector3(at.x, stone_w.global_position.y, at.z) + way * 3.0
		stone_w.velocity = -way * 18.0
		stone_w.deck_y = at.y
	var stopped := {"why": ""}
	if stone_w != null:
		stone_w.ended.connect(func(why: String) -> void:
			stopped.why = why
			stopped["at"] = stone_w.global_position)
	await _secs(0.6)
	_expect(String(stopped.why) == "wall", "Frostwind: a floor wave running into the crust stops at it (%s; at %s, crust %s)" % [stopped.why,
			stone_w.global_position if stone_w != null and is_instance_valid(stone_w) else stopped.get("at", "-"), at])
	var puddles0 := _puddles_near(at)
	var fire_w := BendBolt.launch(mate_of(), at + way * 3.0 + Vector3.UP * 0.25, -way, {"kind": "fire", "mps": 20.0, "radius_m": 0.2,
			"range_m": 8.0, "damage": 6.0, "knock_mps": 2.0, "_info": {"tag": "fire_blast/fireball"}})
	var fire_end := {"why": ""}
	fire_w.ended.connect(func(w0: String) -> void: fire_end.why = w0)
	await _secs(0.5)
	var melted := crust == null or not is_instance_valid(crust) or crust.state == FormRaised.State.CRUMBLING
	_expect(melted and _puddles_near(at) > puddles0, "Frostwind: fire melts the crust back into a puddle")
	await _clear_crusts()

	# a grate: frozen it is no water source; melted, it is again
	var g := _nearest_grate()
	_expect(g != null, "the ring has grates")
	if g != null:
		await _stage(9.0)
		# (from the deck's middle out across the grate, level: the grates lie by the lips)
		var gw := Vector3(0.0, 0.0, signf(g.global_position.z) if absf(g.global_position.z) > 0.01 else 1.0)
		player.global_position = Vector3(g.global_position.x, player.global_position.y, g.global_position.z) - gw * 3.5
		player.velocity = Vector3.ZERO
		foe.global_position = _home + Vector3(5.0, 0.0, 0.0)
		foe.velocity = Vector3.ZERO
		aim_at = NpcSenses.chest_of(player) + gw * 12.0
		await _ticks(12)
		aim_at = NpcSenses.chest_of(player) + gw * 12.0
		await _ticks(6)
		var src0 := BendEffects._source_near(player, g.global_position, 0.5)
		_cast(pc, "air_blast", "ball")
		await _secs(0.4)
		var frozen := not g.is_in_group(Bending.POOLS) and not BendEffects._source_near(player, g.global_position, 0.5)
		var gc: Array = _crusts(player)
		_expect(src0 and frozen and gc.size() == 1, "Frostwind: his Wind Ball over a grate freezes it: no water source while the crust stands (%s, %s, %d)"
				% [src0, frozen, gc.size()])
		var fz := BendZone.make(mate_of(), "fire_wall", g.global_position, (SwayMoves.move("fire_wall").bend as Dictionary).wall, gw)
		await _secs(0.6)
		_expect(g.is_in_group(Bending.POOLS) and BendEffects._source_near(player, g.global_position, 0.5),
				"Frostwind: a Fire Wall on the crust melts it: the grate is a source again")
		if is_instance_valid(fz):
			fz.queue_free()
	await _clear_crusts()

	# steam his wind crosses falls as snow and clears
	var st := {}
	for id: String in ["", "air.set.frostwind"]:
		await _stage(9.0)
		_wear([id] if id != "" else [])
		var sway := foe.global_position - player.global_position
		sway.y = 0.0
		var sz := BendBolt.steam(foe, player.global_position + sway.normalized() * 3.0 + Vector3.UP * 1.2)
		await _ticks(2)
		_cast(pc, "air_gust", "gust")
		await _secs(0.3)
		st[id] = sz != null and is_instance_valid(sz) and not sz.is_queued_for_deletion()
		if sz != null and is_instance_valid(sz):
			sz.queue_free()
	_expect(bool(st[""]) and not bool(st["air.set.frostwind"]), "Frostwind: steam his Gust crosses falls as snow and clears (not worn: it stays)")

	# his Wind Wall drops water and ice as shards (not worn: blown up and aside)
	var sh := {}
	for id: String in ["", "air.set.frostwind"]:
		await _stage(9.0)
		_wear([id] if id != "" else [])
		var known := {}
		for z in get_nodes_in_group(BendZone.GROUP):
			known[z.get_instance_id()] = true
		sc.ready_spell("air_wall")
		sc.set_mode("air_wall", "wall")
		BendEffects.apply(pc, "air_wall", "wall", (SwayMoves.move("air_wall").bend as Dictionary).wall)
		var wz: BendZone = null
		for z in get_nodes_in_group(BendZone.GROUP):
			if not known.has(z.get_instance_id()) and (z as BendZone).kind == "wind_wall":
				wz = z
		await _ticks(3)
		var wb2: BendBolt = null
		if wz != null:
			var into := wz.global_position - foe.global_position
			into.y = 0.0
			wb2 = BendBolt.launch(foe, foe.global_position + Vector3.UP * 1.3 + into.normalized() * 0.8, into.normalized(),
					{"kind": "water", "mps": 26.0, "radius_m": 0.2, "range_m": 20.0, "damage": 8.0, "knock_mps": 3.0, "_info": {"tag": "water_jet/splash"}})
		var why := {"why": ""}
		if wb2 != null:
			wb2.ended.connect(func(w0: String) -> void: why.why = w0)
		await _secs(0.5)
		sh[id] = String(why.why)
		if wz != null and is_instance_valid(wz):
			wz.queue_free()
		if wb2 != null and is_instance_valid(wb2):
			wb2.end("test")
	_expect(String(sh[""]) != "shards" and String(sh["air.set.frostwind"]) == "shards",
			"Frostwind: water his Wind Wall meets falls as shards (%s; not worn: %s)" % [sh["air.set.frostwind"], sh[""]])
	_wear(["air.set.frostwind"])
	var wl := _wall_life()
	_expect(_near(wl, 3.5), "Frostwind: his Wind Wall stands %.1f s (4)" % wl)
	# a bot wearing it: its Wind Ball freezes a puddle too
	_wear([])
	await _stage(9.0)
	BendLoadout.wear(foe, ["air.set.frostwind"], "", "air")
	var bway := player.global_position - foe.global_position
	bway.y = 0.0
	var bp := BendZone.make(player, "puddle", FormEffects.ground_at(foe, foe.global_position + bway.normalized() * 3.0), {"radius_m": 0.9, "life_s": 8.0}, bway)
	await _ticks(2)
	_cast(BendCaster.of(foe), "air_blast", "ball")
	await _secs(0.4)
	var bc := _crusts(foe).size()
	BendLoadout.clear(foe)
	_expect(bc == 1 and (not is_instance_valid(bp) or bp.is_queued_for_deletion()), "Frostwind on a bot: its Wind Ball freezes a puddle (%d crust)" % bc)
	await _clear_crusts()
	await _clear_air()


func mate_of() -> NpcFighter:
	for e: Dictionary in mode.extras:
		if e.get("bot") is NpcFighter and BendCaster.same_team(e.bot, player):
			return e.bot
	return foe


func _puddles_near(at: Vector3) -> int:
	var n := 0
	for z in get_nodes_in_group(BendZone.GROUP):
		var bz := z as BendZone
		if bz != null and bz.kind == "puddle" and not bz.is_queued_for_deletion() and Vector2(bz.global_position.x - at.x, bz.global_position.z - at.z).length() < 1.5:
			n += 1
	return n


func _nearest_grate() -> Node3D:
	var best: Node3D = null
	var bd := INF
	for g in mode.ring.grates:
		var d := g.global_position.distance_to(_home)
		if d < bd:
			bd = d
			best = g
	return best


# ---------------------------------------------------------------- Hail Ball
func _hits_on(n: Node, by: Node, tag: String, from_i: int) -> Array:
	var out: Array = []
	for i in range(mini(from_i, BendR3.hits_log.size()), BendR3.hits_log.size()):
		var e: Dictionary = BendR3.hits_log[i]
		if e.get("n") == n and e.get("by") == by and String(e.get("tag", "")) == tag:
			out.append(e)
	return out


func _hail_ball() -> void:
	var help0 := MatchSetup._aim_help
	MatchSetup._aim_help = "off"                      # (the crosshair's own point: the Wind Ball onto the deck before him)
	var got := {}
	var end_at := Vector3.INF
	for ids: Array in [["air.set.frostwind"], ["air.set.frostwind", "air.frost.hail_ball"]]:
		await _stage(9.0)
		_wear(ids)
		var way := Vector3.RIGHT
		var spot := FormEffects.ground_at(foe, player.global_position + way * 2.5)
		if end_at.is_finite():
			foe.global_position = end_at + way * AirTalents.HAIL_R     # (where the first hailstone falls: 1.2 m on from the ball's end)
			foe.velocity = Vector3.ZERO
		else:
			foe.global_position += way * 3.0          # (out of the way of the first ball)
		aim_at = spot
		await _ticks(12)
		aim_at = spot
		await _ticks(4)
		var log0 := BendR3.hits_log.size()
		var pct0 := rules.pct_of(foe)
		var ball := _cast(pc, "air_blast", "ball")
		var ends := {"at": Vector3.INF}
		if ball != null:
			ball.ended.connect(func(_w: String) -> void: ends.at = FormEffects.ground_at(ball, ball.global_position))
		await _secs(0.8)
		if not end_at.is_finite():
			end_at = ends.at
		var hail := _hits_on(foe, player, AirTalents.HAIL_TAG, log0)
		got[ids.size()] = {"end": last_end, "hail": hail.size(), "pct": rules.pct_of(foe) - pct0,
				"no_hurt": hail.size() > 0 and bool((hail[0].info as Dictionary).get("no_hurt", false)),
				"kv": (hail[0].kv as Vector3).length() if hail.size() > 0 else -1.0}
	MatchSetup._aim_help = help0
	var c: Dictionary = got[1]
	var w: Dictionary = got[2]
	var hail_cls := BendLoadout.worn_class(player, AirTalents.HAIL_TAG)
	_wear([])
	var d := 2.0 * RingRules.stock_num("pct_scale", 1.0)
	_expect(String(c.end) in ["world", "range"] and int(c.hail) == 0 and _near(float(c.pct), 0.0),
			"Hail Ball not worn: a Wind Ball onto the deck 1.2 m before the foe leaves him be (%s)" % c.end)
	_expect(int(w.hail) == 1 and _near(float(w.pct), d, 0.02) and bool(w.no_hurt) and _near(float(w.kv), 0.0),
			"Hail Ball: where the ball ends, hail falls 1.2 m on: one hailstone strikes the foe there, +%.2f%% (2 x the scale), no knock, no hurt (%s)" % [w.pct, w])
	_expect(not hail_cls.is_empty() and BendLoadout.worn_class(player, AirTalents.HAIL_TAG).is_empty() and RingRules.class_of(AirTalents.HAIL_TAG).is_empty(),
			"Hail Ball: the hail's class is the wearer's; taken off, nobody's (none in the data)")


# ---------------------------------------------------------------- Frost Gust
func _frost_gust() -> void:
	var got := {}
	for ids: Array in [["air.set.frostwind"], ["air.set.frostwind", "air.frost.frost_gust"]]:
		for zk: String in ["fire_wall", "burn"]:
			await _stage(9.0)
			_wear(ids)
			var at := FormEffects.ground_at(player, player.global_position + Vector3.RIGHT * 3.5)
			var spec: Dictionary = (SwayMoves.move("fire_wall").bend as Dictionary).wall if zk == "fire_wall" else (SwayMoves.move("fire_wall").bend as Dictionary).inferno
			var z := BendZone.make(foe, zk, at, spec, Vector3.LEFT)
			await _ticks(3)
			var g := _cast(pc, "air_gust", "gust")
			var w_m := g.radius * 2.0 if g != null else -1.0
			await _secs(0.4)
			got["%d|%s" % [ids.size(), zk]] = {"stands": is_instance_valid(z) and not z.is_queued_for_deletion(),
					"burning": g != null and is_instance_valid(g) and g.burning, "w": w_m}
			if is_instance_valid(z):
				z.queue_free()
			await _ticks(3)
	_wear([])
	_expect(bool(got["1|fire_wall"].stands) and bool(got["1|burn"].stands),
			"Frost Gust not worn: his Gust through a foe's Fire Wall or burning ground leaves it burning (takes its flame)")
	_expect(not bool(got["2|fire_wall"].stands) and not bool(got["2|burn"].stands),
			"Frost Gust: his Gust puts out a foe's Fire Wall and his burning ground (%s)" % [got])
	_expect(_near(float(got["2|fire_wall"].w), 1.8) and _near(float(got["1|fire_wall"].w), 2.0),
			"Frost Gust: his Gust %.1f m wide (2)" % got["2|fire_wall"].w)


# ---------------------------------------------------------------- Rime Wall
func _rime_wall() -> void:
	var got := {}
	for ids: Array in [["air.set.frostwind"], ["air.set.frostwind", "air.frost.rime_wall"]]:
		await _stage(9.0)
		_wear(ids)
		await _clear_crusts()
		var known := {}
		for z0 in get_nodes_in_group(BendZone.GROUP):
			known[z0.get_instance_id()] = true
		BendEffects.apply(pc, "air_wall", "wall", (SwayMoves.move("air_wall").bend as Dictionary).wall)
		var wz: BendZone = null
		for z0 in get_nodes_in_group(BendZone.GROUP):
			if not known.has(z0.get_instance_id()) and (z0 as BendZone).kind == "wind_wall":
				wz = z0
		var push := -1.0
		if wz != null:
			var log0 := BendR3.hits_log.size()
			foe.global_position = wz.global_position + wz.global_basis.z * 0.2
			foe.velocity = Vector3.ZERO
			await _ticks(3)
			for i in range(mini(log0, BendR3.hits_log.size()), BendR3.hits_log.size()):
				var e: Dictionary = BendR3.hits_log[i]
				if e.get("n") == foe and e.get("by") == player:
					var kv: Vector3 = e.kv
					push = Vector2(kv.x, kv.z).length()
			var wat := wz.global_position
			var wx := wz.global_basis.x
			wz.end("life")
			await _ticks(3)
			var cs := _crusts(player)
			var cr: FormRaised = cs[0] if cs.size() == 1 else null
			got[ids.size()] = {"push": push, "crusts": cs.size(),
					"at": Vector2(cr.global_position.x - wat.x, cr.global_position.z - wat.z).length() if cr != null else -1.0,
					"along": absf(cr.global_basis.x.normalized().dot(wx.normalized())) if cr != null else 0.0,
					"life": cr.life_s if cr != null else -1.0, "w": cr.size.x if cr != null else -1.0}
		else:
			got[ids.size()] = {"push": -1.0, "crusts": -1}
		await _stage(9.0)
	_wear([])
	await _clear_crusts()
	var c: Dictionary = got[1]
	var w: Dictionary = got[2]
	_expect(_near(float(c.push), 4.0, 0.01) and _near(float(w.push), 3.2, 0.01),
			"Rime Wall: his Wind Wall pushes back at %.1f m/s (Classic %.1f)" % [w.push, c.push])
	_expect(int(c.crusts) == 0, "Rime Wall not worn: his Wind Wall ends and leaves nothing")
	_expect(int(w.crusts) == 1 and float(w.at) < 0.3 and float(w.along) > 0.99 and _near(float(w.life), 3.0) and _near(float(w.w), 3.0),
			"Rime Wall: as his Wind Wall ends, a 3 m crust lies where it stood, along it, for 3 s (%s)" % [w])


# ---------------------------------------------------------------- Blizzard
func _snows(by: Node) -> Array:
	var out: Array = []
	for z in get_nodes_in_group(BendZone.GROUP):
		var bz := z as BendZone
		if bz != null and bz.kind == "snow" and bz.owner_node == by and not bz.is_queued_for_deletion():
			out.append(bz)
	return out


func _blizzard() -> void:
	if not sc.cast_released.is_connected(_count_cast):
		sc.cast_released.connect(_count_cast)
	var key4: Array = Bending.keys("air")[3]
	await _stage(8.0)
	_wear(["air.set.frostwind"])
	var w0 := _wall_life()
	_expect(sc.my_modes("air_wall") == ["wall"], "Blizzard not worn: the Wind Wall's key has one move")
	_wear(["air.set.frostwind", "air.frost.blizzard"])
	var other := Bending.other_move(key4, "air_wall", "wall", player)
	_expect(String(other.get("mode", "")) == "blizzard" and SwayCaster.mode_label("air_wall", "blizzard") == "Blizzard",
			"Blizzard: 4 tapped twice readies it (%s)" % [other])
	sc.set_mode("air_wall", "blizzard")
	var lock_b := sc._lock_time("air_wall", null, 0.0, 0.0)
	sc.set_mode("air_wall", "wall")
	var lock_w := sc._lock_time("air_wall", null, 0.0, 0.0)
	_expect(_near(lock_b / lock_w, 0.9 / 0.8, 0.002), "Blizzard: its lock 0.9 s")
	var w1 := _wall_life()
	_expect(_near(w0, 3.5) and _near(w1, 3.5 * 0.85, 0.01), "Blizzard: his Wind Wall stands %.2f s (the set's %.1f, 15%% shorter)" % [w1, w0])
	# cast through the real lock at the foe 8 m off: a snow column on him
	var pz := BendZone.make(foe, "puddle", FormEffects.ground_at(foe, foe.global_position + Vector3.LEFT * 1.0), {"radius_m": 0.8, "life_s": 8.0}, Vector3.LEFT)
	var log0 := BendR3.hits_log.size()
	var pct0 := rules.pct_of(foe)
	await _held_cast("air_wall", "blizzard", 0.05)
	var sn := _snows(player)
	var z: BendZone = sn[0] if sn.size() == 1 else null
	var off := Vector2(z.global_position.x - player.global_position.x, z.global_position.z - player.global_position.z).length() if z != null else -1.0
	_expect(z != null and _near(z.radius, 2.5) and _near(z.life_s, 3.0) and off >= 1.9 and off <= 10.1 and z.inside(foe.global_position),
			"Blizzard: a 2.5 m snow column for 3 s where he aims (%.1f m off), the foe in it" % off)
	await _ticks(20)
	_expect(NpcBendCaster.hidden(foe, player) and (not is_instance_valid(pz) or pz.is_queued_for_deletion()) and not _crusts(player).is_empty(),
			"Blizzard: it hides him from the foe, and the puddle in it froze to crust")
	if z != null:
		z.life_s = 9.0                                # (left standing: the cold's cap)
	await _secs(4.0)
	var cold := _hits_on(foe, player, AirTalents.COLD_TAG, log0)
	var per := 1.0 * RingRules.stock_num("pct_scale", 1.0)
	_expect(cold.size() == AirTalents.COLD_CAP and _near(rules.pct_of(foe) - pct0, per * AirTalents.COLD_CAP, 0.05)
			and (cold[0].kv as Vector3).length() < 0.01 and bool((cold[0].info as Dictionary).get("no_hurt", false)),
			"Blizzard: the foe in it gains 1%% a tick, 6 ticks at most (%d, +%.2f%%), no knock, no hurt" % [cold.size(), rules.pct_of(foe) - pct0])
	if cold.size() >= 2:
		_expect(float(cold[1].at) - float(cold[0].at) >= AirTalents.MATTER_EVERY_S - 0.01, "Blizzard: one tick each 0.5 s (%.2f s)" % [float(cold[1].at) - float(cold[0].at)])
	# fire melts it out in a second
	if z != null and is_instance_valid(z):
		var fz := BendZone.make(foe, "fire_wall", z.global_position, (SwayMoves.move("fire_wall").bend as Dictionary).wall, Vector3.LEFT)
		var gone := await _until(func() -> bool: return not is_instance_valid(z) or z.is_queued_for_deletion(), 3.0)
		_expect(gone <= 1.4, "Blizzard: fire on it melts it out in about a second (%.2f s)" % gone)
		if is_instance_valid(fz):
			fz.queue_free()
	# one at a time
	await _held_cast("air_wall", "blizzard", 0.05)
	await _held_cast("air_wall", "blizzard", 0.05)
	await _ticks(3)
	_expect(_snows(player).size() == 1, "Blizzard: a new one ends his old one (%d)" % _snows(player).size())
	sc.set_mode("air_wall", "wall")
	# a bot wearing it casts it
	BendLoadout.wear(foe, ["air.set.frostwind", "air.frost.blizzard"], "", "air")
	var ok := BendCast.cast(BendCaster.of(foe), "air_wall", "blizzard", player, player.global_position)
	var fb := _snows(foe).size()
	BendLoadout.clear(foe)
	_expect(ok and fb == 1, "Blizzard on a bot: it casts it through its own path")
	_wear([])
	await _clear_crusts()
	await _clear_air()


# ---------------------------------------------------------------- Whiteout
func _whiteout() -> void:
	await _stage(9.0)
	sc.set_mode("patch", "patch")
	_wear(["air.set.frostwind"])
	var patch0 := sc._lock_time("patch", null, 0.0, 0.0)
	_wear(["air.set.frostwind", "air.frost.whiteout"])
	var patch1 := sc._lock_time("patch", null, 0.0, 0.0)
	_expect(_near(patch1 / patch0, 1.7 / 1.5, 0.002), "Whiteout: his Patch locks %.2f s (%.2f: 1.7 for 1.5)" % [patch1, patch0])
	var off := AirTalents.home_fill(player)
	var cr := AirTalents.make_crust(player, FormEffects.ground_at(player, player.global_position + Vector3.RIGHT * 2.0), Vector3.RIGHT, 6.0)
	await _secs(0.3)
	player.global_position = cr.global_position + Vector3.UP * (cr.size.y + 0.05)
	player.velocity = Vector3.ZERO
	await _ticks(6)
	var on := AirTalents.home_fill(player)
	# the real fill on it: a Slice lock's share after 0.2 s, on his crust and off it
	var f_on := await _fill_after(0.2)
	player.global_position = cr.global_position + Vector3.LEFT * 3.0 + Vector3.UP * 0.05
	await _ticks(10)
	var f_off := await _fill_after(0.2)
	_expect(_near(off, 1.0) and _near(on, AirTalents.HOME_FILL), "Whiteout: on his own crust his locks fill x%.2f (off it x%.2f)" % [on, off])
	_expect(f_off > 0.0 and _near(f_on / f_off, AirTalents.HOME_FILL, 0.06), "Whiteout: a Slice lock fills %.3f on it, %.3f off it" % [f_on, f_off])
	var sz := BendZone.make(player, "snow", player.global_position, {"radius_m": 2.5, "life_s": 3.0}, Vector3.RIGHT)
	await _ticks(2)
	var in_snow := AirTalents.home_fill(player)
	sz.queue_free()
	_wear(["air.set.frostwind"])
	var not_worn := AirTalents.home_fill(player)
	_expect(_near(in_snow, AirTalents.HOME_FILL) and _near(not_worn, 1.0), "Whiteout: in his own snow x%.2f; not worn x%.2f" % [in_snow, not_worn])
	# a bot wearing it: its own lock fill on its own crust
	BendLoadout.wear(foe, ["air.set.frostwind", "air.frost.whiteout"], "", "air")
	var fcr := AirTalents.make_crust(foe, FormEffects.ground_at(foe, foe.global_position + Vector3.LEFT * 2.0), Vector3.RIGHT, 6.0)
	await _secs(0.3)
	foe.global_position = fcr.global_position + Vector3.UP * (fcr.size.y + 0.05)
	foe.velocity = Vector3.ZERO
	await _ticks(6)
	var fon := AirTalents.home_fill(foe)
	BendLoadout.clear(foe)
	_expect(_near(fon, AirTalents.HOME_FILL), "Whiteout on a bot: on its own crust its locks fill x%.2f" % fon)
	_wear([])
	await _clear_crusts()


## The share of a Slice lock filled `s` s after it began (the aim's button held; let go after, no cast).
func _fill_after(s: float) -> float:
	sc.ready_spell("air_blast")
	sc.set_mode("air_blast", "slice")
	aim_at = NpcSenses.chest_of(foe)
	await _ticks(4)
	sc.held_override = true
	await _until(func() -> bool: return sc.state != SwayCaster.State.IDLE, 1.0)
	var f0 := sc.fill
	await _secs(s)
	var f := sc.fill - f0
	sc.held_override = false
	await _secs(0.8)
	return f
