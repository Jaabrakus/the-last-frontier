extends SceneTree
## The skill tree's tuning talents in a real ring (the owner, 2026-10-11: "we need to make sure all the talents work and they work
## in game right"): each node whose numbers are a guard rule, a passive, a % ring rule or Stone Form's own (BendLoadout's tune part)
## worn on the player alone, and the game's own code, where it reads that number for him, read worn and not worn:
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_talents_tune.gd -- mode=ring practice=stand element=earth foe=earth
##   Clean Return      a clean stone's throw-back factor 1.3 (Classic 1.2); the next guard's lock with a stone held 0.42 s (0.35)
##   Open Hands        a return's rally step 0.08 (0.1)
##   Steady Point      Stone Form's release window 1.2 s (1.0); the Spike's lock x1.2/1.1
##   Swift Lance       the raised Spike hurled at 40 m/s (34)
##   Heavy Boulder     the Boulder 0.31 m (0.26), hurled at 20 m/s (22), its lock x1.25/1.1
##   Deep / Swift Roots    Rooted's knock share 0.8 / 0.92 (0.85) and its fill 1.1 / 1.3 (1.2), standing still on the deck
##   Patient Turn      the Turn's zone: perfect 0.36 s (0.3), a late guard's share 0.6 (0.5)
##   Reaching Parry    the Parry's zone: 3.0 m (2.5), perfect 0.25 s (0.3)
##   Lazy River / Rapids   a water bolt's steer: 36 / 54 deg/s (45), at most 18 / 12 deg (15), steering 0.3 s (0.25)
##   Long Carry / Gale Force   Carried wind lasts 0.96 / 0.64 s (0.8); a carried Slice's knock x1.1 / x1.2 (x1.15)
##   each              live in BendLoadout's resolve (no node refused), and Classic (nothing worn) reads the game's own number
## Last line "TALENTS TUNE PASSED (n checks)" or "... FAILED".

var checks := 0
var fails: Array[String] = []
var player: FrontierPlayer
var pc: BendCaster
var sc: SwayCaster
var mode: RingMode
const TUNE := ["earth.catch.clean_return", "earth.catch.open_hands", "earth.spike.steady_point", "earth.spike.swift_lance",
		"earth.boulder.heavy", "earth.passive.deep_roots", "earth.passive.swift_roots", "water.turn.patient",
		"water.passive.lazy_river", "water.passive.rapids", "fire.parry.reaching", "air.passive.long_carry", "air.passive.gale_force"]


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	InputSetup.ensure()
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _end() -> void:
	if player != null and is_instance_valid(player):
		BendLoadout.clear(player)
	BendLoadout.config_override = {}
	if fails.is_empty() and checks > 0:
		print("TALENTS TUNE PASSED (%d checks)" % checks)
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("TALENTS TUNE FAILED (%d of %d)" % [fails.size(), checks])
		quit(1)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	for i in 12:
		await process_frame
	var lvl := current_scene as RingLevel
	player = lvl.player if lvl != null else null
	mode = RingMode.find(self)
	_expect(player != null and mode != null, "a practice ring")
	if player == null or mode == null:
		return _end()
	await _ticks(240)
	pc = BendCaster.of(player)
	sc = SwayCaster.of(player)
	# (worn as the live list will hold them: loadout_apply.json's live list and these, whatever the file says today)
	var live: Array = (BendLoadout.config().get("live", []) as Array).duplicate()
	live.append_array(TUNE)
	BendLoadout.config_override = {"live": live}
	for id: String in ["earth.catch.clean_return", "earth.catch.open_hands", "earth.spike.steady_point", "earth.spike.swift_lance",
			"earth.boulder.heavy", "earth.passive.deep_roots", "earth.passive.swift_roots", "water.turn.patient",
			"water.passive.lazy_river", "water.passive.rapids", "fire.parry.reaching", "air.passive.long_carry",
			"air.passive.gale_force"]:
		var r := BendLoadout.resolve(id)
		_expect(bool(r.ok), "%s resolves whole (%s)" % [id, String(r.why)])
	await _catch_return()
	await _stones()
	await _roots()
	await _zones()
	await _steer()
	await _carry()
	_end()


## `id` worn alone by the player as an `el` caster (element set), or nothing worn ("").
func _wear(id: String, el: String) -> void:
	Bending.of(player).element = el
	BendLoadout.clear(player)
	if id != "":
		var ov := BendLoadout.wear(player, [id], "", el)
		if not (ov.ids as Array).has(id):
			_expect(false, "%s worn (refused: %s)" % [id, str(ov.refused)])


func _held_stone() -> FormStone:
	var at := player.global_position + -player.global_basis.z * 0.6 + Vector3.UP * 1.25
	var s := FormStone.ball(current_scene, at, {"radius_m": 0.26, "rise_s": 0.01, "life_s": 30.0}, 3, "stone")
	s.state = FormStone.State.RESTING
	s.base = Transform3D(Basis.IDENTITY, at)
	s.global_transform = s.base
	s.freeze = true
	s.set_meta(&"bend_held_by", player.get_instance_id())
	s.set_meta(&"bend_stone_d", {"mps": 34.0, "damage": 30.0, "knock_mps": 6.0})
	return s


func _catch_return() -> void:
	var res := {}
	for id: String in ["", "earth.catch.clean_return"]:
		_wear(id, "earth")
		var s := _held_stone()
		s.set_meta(&"bend_clean", true)
		var clean_k := BendZone.return_mult(s, player)
		s.remove_meta(&"bend_clean")
		var lk := BendZone.guard_lock_s(player, 0.5)
		res[id] = [clean_k, lk]
		s.queue_free()
		await _ticks(2)
	_expect(is_equal_approx(float(res[""][0]), 1.2) and is_equal_approx(float(res["earth.catch.clean_return"][0]), 1.3),
			"Clean Return: a clean stone's throw-back factor %.2f (Classic %.2f)" % [res["earth.catch.clean_return"][0], res[""][0]])
	_expect(is_equal_approx(float(res[""][1]), 0.35) and is_equal_approx(float(res["earth.catch.clean_return"][1]), 0.42),
			"Clean Return: the next guard's lock with a stone held %.2f s (Classic %.2f)" % [res["earth.catch.clean_return"][1], res[""][1]])
	var rally := {}
	for id: String in ["", "earth.catch.open_hands"]:
		_wear(id, "earth")
		var s := _held_stone()
		await _ticks(2)
		BendZone.return_stone(pc, s, player.global_position - player.global_basis.z * 20.0)
		rally[id] = float(s.get_meta(&"bend_rally", -1.0)) if is_instance_valid(s) else -1.0
		await _ticks(30)
	_expect(is_equal_approx(float(rally[""]), 0.1) and is_equal_approx(float(rally["earth.catch.open_hands"]), 0.08),
			"Open Hands: a return's rally step %.2f (Classic %.2f)" % [rally["earth.catch.open_hands"], rally[""]])


func _stones() -> void:
	var got := {}
	for id: String in ["", "earth.spike.steady_point", "earth.spike.swift_lance", "earth.boulder.heavy"]:
		_wear(id, "earth")
		var md := "cannonball" if id == "earth.boulder.heavy" else "spike"
		sc.set_mode("stone_form", md)
		var lock := sc._lock_time("stone_form", null, 0.0, 10.0)
		var rel := sc.rule_of("stone_form", "release_s", 1.0)
		var th := FormEffects.raise_stone(player, "stone_form", md) as FormEffects.Throw
		await _ticks(20)
		var mps := float((th.lift._hurl_d().get("mps", [0.0]) as Array)[-1]) if th != null else 0.0
		var rad := th.stone.radius if th != null else 0.0
		if th != null:
			FormEffects.drop_raised(th)
		got[id] = {"lock": lock, "rel": rel, "mps": mps, "rad": rad}
		# (the classic Boulder too, for its own numbers)
		if id == "":
			sc.set_mode("stone_form", "cannonball")
			var lock_b := sc._lock_time("stone_form", null, 0.0, 10.0)
			var thb := FormEffects.raise_stone(player, "stone_form", "cannonball") as FormEffects.Throw
			await _ticks(20)
			got["boulder"] = {"lock": lock_b, "mps": float((thb.lift._hurl_d().get("mps", [0.0]) as Array)[-1]), "rad": thb.stone.radius}
			FormEffects.drop_raised(thb)
		await _ticks(5)
	sc.set_mode("stone_form", "spike")
	var c: Dictionary = got[""]
	var sp: Dictionary = got["earth.spike.steady_point"]
	_expect(is_equal_approx(float(c.rel), 1.0) and is_equal_approx(float(sp.rel), 1.2), "Steady Point: Stone Form's release window %.1f s (Classic %.1f)" % [sp.rel, c.rel])
	_expect(absf(float(sp.lock) / float(c.lock) - 1.2 / 1.1) < 0.01, "Steady Point: the Spike's lock %.2f s (Classic %.2f: x1.2/1.1)" % [sp.lock, c.lock])
	_expect(is_equal_approx(float(c.mps), 34.0) and is_equal_approx(float(got["earth.spike.swift_lance"].mps), 40.0),
			"Swift Lance: the Spike hurled at %.0f m/s (Classic %.0f)" % [got["earth.spike.swift_lance"].mps, c.mps])
	var b0: Dictionary = got["boulder"]
	var hb: Dictionary = got["earth.boulder.heavy"]
	_expect(is_equal_approx(float(b0.rad), 0.26) and is_equal_approx(float(hb.rad), 0.31) and is_equal_approx(float(b0.mps), 22.0)
			and is_equal_approx(float(hb.mps), 20.0) and absf(float(hb.lock) / float(b0.lock) - 1.25 / 1.1) < 0.01,
			"Heavy Boulder: %.2f m at %.0f m/s, lock %.2f s (Classic %.2f m at %.0f m/s, %.2f s)" % [hb.rad, hb.mps, hb.lock, b0.rad, b0.mps, b0.lock])


func _roots() -> void:
	var got := {}
	for id: String in ["", "earth.passive.deep_roots", "earth.passive.swift_roots"]:
		_wear(id, "earth")
		player.velocity = Vector3.ZERO
		await _ticks(10)
		got[id] = [BendStatus.rooted_mult(player), sc.passive_fill()]
	var c: Array = got[""]
	_expect(is_equal_approx(float(c[0]), 0.85) and is_equal_approx(float(got["earth.passive.deep_roots"][0]), 0.8)
			and is_equal_approx(float(got["earth.passive.swift_roots"][0]), 0.92),
			"Deep / Swift Roots: Rooted's knock share %.2f / %.2f (Classic %.2f)" % [got["earth.passive.deep_roots"][0], got["earth.passive.swift_roots"][0], c[0]])
	_expect(is_equal_approx(float(c[1]), 1.2) and is_equal_approx(float(got["earth.passive.deep_roots"][1]), 1.1)
			and is_equal_approx(float(got["earth.passive.swift_roots"][1]), 1.3),
			"Deep / Swift Roots: Rooted's fill %.2f / %.2f (Classic %.2f)" % [got["earth.passive.deep_roots"][1], got["earth.passive.swift_roots"][1], c[1]])


## The newest guard zone the player's cast made.
func _zone_after(m: String, md: String, el: String, id: String) -> BendZone:
	_wear(id, el)
	var known := {}
	for z in get_nodes_in_group(BendZone.GROUP):
		known[z.get_instance_id()] = true
	BendEffects.apply(pc, m, md, (SwayMoves.move(m).bend as Dictionary)[md])
	await _ticks(2)
	for z in get_nodes_in_group(BendZone.GROUP):
		if not known.has(z.get_instance_id()) and z is BendZone:
			return z as BendZone
	return null


func _zones() -> void:
	var t0 := await _zone_after("water_redirect", "redirect", "water", "")
	var t1 := await _zone_after("water_redirect", "redirect", "water", "water.turn.patient")
	_expect(t0 != null and t1 != null and is_equal_approx(t0.perfect_s, 0.3) and is_equal_approx(t1.perfect_s, 0.36)
			and is_equal_approx(t0.late_mult, 0.5) and is_equal_approx(t1.late_mult, 0.6),
			"Patient Turn: the Turn's perfect %.2f s and late share %.2f (Classic %.2f, %.2f)" % [t1.perfect_s if t1 else -1.0,
			t1.late_mult if t1 else -1.0, t0.perfect_s if t0 else -1.0, t0.late_mult if t0 else -1.0])
	await _ticks(60)
	var p0 := await _zone_after("fire_parry", "parry", "fire", "")
	var p1 := await _zone_after("fire_parry", "parry", "fire", "fire.parry.reaching")
	_expect(p0 != null and p1 != null and is_equal_approx(p0.radius, 2.5) and is_equal_approx(p1.radius, 3.0)
			and is_equal_approx(p0.perfect_s, 0.3) and is_equal_approx(p1.perfect_s, 0.25),
			"Reaching Parry: the Parry's zone %.1f m, perfect %.2f s (Classic %.1f m, %.2f s)" % [p1.radius if p1 else -1.0,
			p1.perfect_s if p1 else -1.0, p0.radius if p0 else -1.0, p0.perfect_s if p0 else -1.0])
	await _ticks(60)


func _steer() -> void:
	var got := {}
	for id: String in ["", "water.passive.lazy_river", "water.passive.rapids"]:
		_wear(id, "water")
		var known := {}
		for n in get_nodes_in_group(BendBolt.GROUP):
			known[n.get_instance_id()] = true
		BendEffects.apply(pc, "water_jet", "splash", (SwayMoves.move("water_jet").bend as Dictionary).splash)
		await _ticks(2)
		var b: BendBolt = null
		for n in get_nodes_in_group(BendBolt.GROUP):
			if n is BendBolt and not known.has(n.get_instance_id()) and (n as BendBolt).caster == player:
				b = n
		got[id] = [b.steer_dps, b.steer_max_deg, b.steer_s] if b != null else [-1.0, -1.0, -1.0]
		await _ticks(30)
	var c: Array = got[""]
	var lr: Array = got["water.passive.lazy_river"]
	var ra: Array = got["water.passive.rapids"]
	_expect(is_equal_approx(float(c[0]), 45.0) and is_equal_approx(float(lr[0]), 36.0) and is_equal_approx(float(ra[0]), 54.0)
			and is_equal_approx(float(c[1]), 15.0) and is_equal_approx(float(lr[1]), 18.0) and is_equal_approx(float(ra[1]), 12.0)
			and is_equal_approx(float(c[2]), 0.25) and is_equal_approx(float(lr[2]), 0.3),
			"Lazy River / Rapids: a water bolt steers %.0f / %.0f deg/s, at most %.0f / %.0f deg, %.2f s (Classic %.0f, %.0f, %.2f)"
			% [lr[0], ra[0], lr[1], ra[1], lr[2], c[0], c[1], c[2]])


func _carry() -> void:
	var got := {}
	for id: String in ["", "air.passive.long_carry", "air.passive.gale_force"]:
		_wear(id, "air")
		if player.has_meta(&"bend_carry_until"):
			player.remove_meta(&"bend_carry_until")
		var now := BendStatus.now()
		BendZone.carry_wind(player)
		var last := BendStatus.until(player, &"bend_carry_until")
		var base := float((SwayMoves.move("air_blast").bend as Dictionary).slice.knock_mps)
		BendEffects.apply(pc, "air_blast", "slice", (SwayMoves.move("air_blast").bend as Dictionary).slice)
		var rec := BendEffects.last_of(pc)
		var k := float((rec.get("spec", {}) as Dictionary).get("knock_mps", 0.0)) / base if base > 0.0 else -1.0
		got[id] = [last, k, bool(rec.get("carried", false))]
		await _ticks(30)
	var c: Array = got[""]
	var lc: Array = got["air.passive.long_carry"]
	var gf: Array = got["air.passive.gale_force"]
	_expect(absf(float(c[0]) - 0.8) < 0.03 and absf(float(lc[0]) - 0.96) < 0.03 and absf(float(gf[0]) - 0.64) < 0.03,
			"Long Carry / Gale Force: Carried wind lasts %.2f / %.2f s (Classic %.2f)" % [lc[0], gf[0], c[0]])
	_expect(bool(c[2]) and bool(lc[2]) and bool(gf[2]) and absf(float(c[1]) - 1.15) < 0.01 and absf(float(lc[1]) - 1.1) < 0.01
			and absf(float(gf[1]) - 1.2) < 0.01,
			"Long Carry / Gale Force: a carried Slice knocks x%.2f / x%.2f (Classic x%.2f)" % [lc[1], gf[1], c[1]])
