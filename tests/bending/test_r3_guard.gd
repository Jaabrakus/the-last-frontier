extends SceneTree
## Round 3's guard as a shield (AIR; smash_r3 spec §2.5, §4.4, §15 "test_r3_guard"), in Tidebreak's ring (scenes/ring.tscn;
## the foe held where he stands and used as the one who shoots). The % rules stood in by FakeRules (a RingRules with
## rule_set "stock", made the current one: the gate on). What gets through is read from BendR3's delivered hits (the info the
## % rules take): none is 0%, one with slide_only is the late half.
##   the shield  the four guards (Catch, Turn, Parry, Wind Guard) each met by a stone, a water, a fire, an air shot and the Air
##               Lance (an air spear: water's Turn swings it back as ice, the owner's 2026-10-11; the Wind Guard bounces it; a
##               Parry sends air and the Lance back as fire, a Wind Guard fire back, each circling once, 2026-10-12; then
##               every cell answered, the return made of both elements: earth holds only earth, air, fire and water flowing
##               back on their own as pebbles, a magma ball or mud (a wave along the deck as its swing ends); water's Turn
##               sends air back as mini ice spears and
##               a stone as a mud spear; fire's
##               Parry a stone as a magma ball, water boiled to steam; the Wind Guard everything as it was) timed to arrive
##               0.2 s after it stands (perfect: nothing through, the cell's reward) and 0.6 s (late: half the knock through
##               as a slide; earth's catch of stone a full catch within its window); a cone (the Wave), a Column and a
##               flying Spike the same
##   lightning   only fire's Parry on the beat sends it back; every other guard, and a late Parry, takes it late
##   earth       its catch within 1.0 s of standing a full catch; the guard held past it: a stone late (half through) and
##               dropped loose at his feet
##   the player  E's guard stands when its lock fills (E still held); held it stays up to 2.5 s; a tap keeps its window
##               (earth 1.0 s); a guard that took nothing makes the next guard's lock 0.5 s; E mid-lock drops the lock; a
##               cast key drops the guard; in the classic ring round 2's stand-at-release, unchanged
##   the reward  (2026-10-11) a perfect guard: the guarder's next cast's lock 0.85 of its time, the shooter's (a bot's) 1.15;
##               one cast, spent by it (a dropped lock keeps it); a late guard nothing; unused, gone after 3 s
## METRIC lines (guard_stand_at_fill_ok, shield_all_ok). Last line "R3 GUARD PASSED" or "R3 GUARD FAILED"; exit 0 only on a
## pass; a watchdog quits with 2.
##   Godot --headless --fixed-fps 60 --path . -s tests/bending/test_r3_guard.gd

const NAME := "R3 GUARD"
const WATCHDOG_S := 600.0
const OWN_CFG := "user://r3_guard_test.cfg"
## The guards by element (kind, move, mode).
const GUARDS := {"earth": ["catch", "stone_catch", "catch"], "water": ["redirect", "water_redirect", "redirect"],
		"fire": ["parry", "fire_parry", "parry"], "air": ["air_shield", "air_shield", "shield"]}
## A shot of each element's kind.
const SHOTS := {"earth": {"kind": "stone", "mps": 40.0, "damage": 20.0, "knock_mps": 6.0, "up_mps": 0.0, "radius_m": 0.25, "range_m": 30.0},
		"water": {"kind": "water", "mps": 40.0, "damage": 20.0, "knock_mps": 6.0, "up_mps": 0.0, "radius_m": 0.2, "range_m": 30.0},
		"fire": {"kind": "fire", "mps": 40.0, "damage": 20.0, "knock_mps": 6.0, "up_mps": 0.0, "radius_m": 0.2, "range_m": 30.0},
		"air": {"kind": "air", "mps": 40.0, "damage": 20.0, "knock_mps": 6.0, "up_mps": 0.0, "radius_m": 0.2, "range_m": 30.0},
		"air_lance": {"kind": "air", "shape": "spear", "flight": "point_first", "mps": 40.0, "gravity": 0.0, "damage": 20.0,
				"knock_mps": 6.0, "up_mps": 0.0, "radius_m": 0.18, "range_m": 30.0, "long": true}}
## The reward each guard gives in its own cells (round 2's matrix): the shot's element -> what becomes of the shot.
## (2026-10-12, the owner: a Parry counters air too, as fire; a Wind Guard counters fire: each circles its guard once, the
## moon, BendZone._moon_back. Then every cell answered, where two elements meet the return made of both: earth catches and
## holds only earth, "everything else is flow": air, fire and water circle him and come back as pebbles, a magma ball, mud
## slapped down as a wave along the deck; water's Turn swings air back as mini ice spears and a stone as a mud spear; fire's
## Parry sends a stone back as a
## magma ball and boils water to steam; the Wind Guard sends everything back)
const REWARD := {"earth": {"earth": "caught", "water": "back", "fire": "back", "air": "back", "air_lance": "back"},
		"water": {"water": "swing", "fire": "steam", "air_lance": "swing", "air": "swing", "earth": "swing"},
		"fire": {"fire": "back", "air": "back", "air_lance": "back", "earth": "back", "water": "steam"},
		"air": {"air": "back", "earth": "back", "air_lance": "back", "fire": "back", "water": "back"}}
## The shape each shot flows back from earth's catch as (BendZone.EARTH_FLOWS).
const FLOWED := {"air": "pebbles", "air_lance": "pebbles", "fire": "magma", "water": "mud"}


class FakeRules:
	extends RingRules


var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var p: FrontierPlayer
var c: SwayCaster
var rm: RingMode
var foe: NpcFighter
var fbc: BodyBendCaster
var fr: FakeRules
var was_rules: RingRules
var metrics := {}
var _foe_at := Vector3.INF
var _ends := {}


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
	MatchSetup.incoming = true
	MatchSetup.element = "earth"
	# (the merge: rules.json plays stock by default; AIR's stand-ins (FakeRules) are this test's gate, the ring itself classic)
	RingRules.rule_set_override = "classic"
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


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


func _hold() -> void:
	if foe != null and is_instance_valid(foe):
		foe.held = true
		if _foe_at == Vector3.INF:
			_foe_at = foe.global_position
		foe.global_position = _foe_at
		foe.velocity = Vector3.ZERO
		foe.health = foe.health_max                  # (whole: the test's blows never end him)


func _run() -> void:
	for i in 10:
		await process_frame
	lvl = current_scene as RingLevel
	p = lvl.player if lvl != null else null
	_expect(p != null, "the ring and its player")
	if p == null:
		return _end()
	p.ignore_mouse_capture = true
	c = SwayCaster.of(p)
	await _until(func() -> bool: return p.arena_element == "earth" and p.hotbar.spell != "", 6.0)
	rm = RingMode.find(self)
	if rm != null:
		await _until(func() -> bool: return rm.phase == "FIGHT", 10.0)
		foe = rm.foe
		rm.rules.soft_walls = false
	_expect(foe != null, "the foe")
	if foe == null:
		return _end()
	fbc = BendCaster.of(foe) as BodyBendCaster
	fbc.scatter_deg = 0.0
	fbc.lead = 0.0
	physics_frame.connect(_hold)
	await _secs(0.4)
	_stock(true)
	await _shield()
	await _other_shapes()
	await _lightning()
	await _earth_window()
	await _player_guard()
	await _parry_reward()
	await _classic()
	_end()


func _end() -> void:
	if c != null:
		c.held_override = null
		c.guard_override = null
	_stock(false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	RingRules.rule_set_override = ""
	GameSettings.path = GameSettings.PATH
	for k: String in metrics:
		print("METRIC %s=%s" % [k, str(metrics[k])])
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


func _stock(on: bool) -> void:
	if on:
		was_rules = RingRules.current()
		fr = FakeRules.new()
		fr.rule_set = "stock"
		RingRules._current = fr
	elif fr != null:
		RingRules._current = was_rules
		fr.free()
		fr = null


## The player whole and still 9 m before the foe facing him, as `el`, nothing bent about.
func _calm(el := "") -> void:
	c.held_override = false
	c.guard_override = false
	if el != "" and p.arena_element != el:
		Bending.of(p).element = el
		await _until(func() -> bool: return p.arena_element == el, 3.0)
	await _ticks(2)
	c._wait_release = false
	c.drop_all()
	for g: StringName in [BendBolt.GROUP, BendZone.GROUP, FormRaised.GROUP, FormStone.GROUP, GustLift.GROUP, FormEffects.Throw.GROUP]:
		for x in get_nodes_in_group(g):
			if is_instance_valid(x):
				x.queue_free()
	for b: Node in [p, foe]:
		for k: StringName in BendStatus.ROUND_METAS:
			if b.has_meta(k):
				b.remove_meta(k)
		for k: StringName in [&"bend_whiff_until", &"bend_last_guard"]:
			if b.has_meta(k):
				b.remove_meta(k)
		var kn := BendKnock.peek(b)
		if kn != null:
			kn.reset()
	var axis := rm.ring.axis()
	var at := _foe_at - axis * signf(axis.dot(_foe_at - rm.ring.center())) * 9.0
	at.y = rm.ring.deck_y()
	var face := _foe_at - at
	face.y = 0.0
	RingLevel.place(p, Transform3D(Basis.looking_at(face.normalized(), Vector3.UP), at))
	p.velocity = Vector3.ZERO
	p.health = p.max_health
	p.pitch = -0.05
	foe.health = foe.health_max
	if rm.phase == "FIGHT":
		rm.phase_t = 0.0
	fbc.target = p
	BendR3.hits_log.clear()
	await _secs(0.35)


func _chest() -> Vector3:
	return p.global_position + Vector3.UP * 1.2


func _hits_on(who: Node) -> Array:
	return BendR3.hits_log.filter(func(e: Dictionary) -> bool: return e.n == who)


## A shot of `spec` from the foe arriving at the player's chest from `d` m off, its info tagged `tag`; its end reason is kept.
## The last shot's bolt (_shoot), for a check of what a guard made of it.
var _last_bolt: BendBolt


func _shoot(spec: Dictionary, d: float, tag := "test/shot") -> BendBolt:
	var s := spec.duplicate()
	s["_info"] = {"tag": tag, "from": NpcSenses.chest_of(foe), "air": false}
	var dir := (_chest() - NpcSenses.chest_of(foe)).normalized()
	var b := BendBolt.launch(foe, _chest() - dir * d, dir, s)
	var id := b.get_instance_id()
	b.ended.connect(func(why: String) -> void: _ends[id] = why)
	_last_bolt = b
	return b


## Guard `el` made on the player now (its move's spec): the zone.
func _guard(el: String) -> BendZone:
	var g: Array = GUARDS[el]
	var spec: Dictionary = (SwayMoves.move(String(g[1])).bend as Dictionary)[String(g[2])]
	return BendZone.make(p, String(g[0]), p.global_position, spec, BendCaster.of(p).facing())


## Shot `shot_el` met by guard `el` made `wait` s before it arrives (`el` "" none): [the hits on the player, the zone's
## results, the bolt's end, the zone].
func _met(el: String, shot_el: String, wait: float) -> Array:
	await _calm(el if el != "" else "earth")
	var z: BendZone = _guard(el) if el != "" else null
	var res: Array[String] = z.results if z != null else ([] as Array[String])
	await _secs(wait)
	var b := _shoot(SHOTS[shot_el], (z.radius if z != null else 2.0) + 0.6, "%s_shot/test" % shot_el)
	var id := b.get_instance_id()
	await _secs(0.3)
	return [_hits_on(p), res, String(_ends.get(id, "")), z]


# ---------------------------------------------------------------- the shield (spec §2.5)
func _shield() -> void:
	var base := {}
	for se: String in SHOTS:
		var r := await _met("", se, 0.0)
		var hs: Array = r[0]
		base[se] = (hs[0].kv as Vector3).length() if not hs.is_empty() else 0.0
	_expect(not base.values().has(0.0), "every shot hits the unguarded player (%s)" % [base])
	var all_ok := true
	for el: String in GUARDS:
		for se: String in SHOTS:
			var pf := await _met(el, se, 0.2)
			var reward := String((REWARD.get(el, {}) as Dictionary).get(se, ""))
			var through: Array = pf[0]
			var end := String(pf[2])
			var rok := true
			match reward:
				"caught":
					rok = BendZone.held_stone(p) != null
				"swing", "back":
					rok = end == "" or end in ["hit", "world", "range"]      # (sent on: it flies off again, not at him)
				"steam":
					rok = end == "steam"
				_:
					rok = end == "blocked"                                  # (a cell round 2 let pass: stopped, no reward)
			if el == "earth" and se != "earth":
				# (earth's other elements flow back on their own, nothing held: pebbles, a magma ball, a mud spear, the catcher's)
				rok = rok and BendZone.held_stone(p) == null and is_instance_valid(_last_bolt) and _last_bolt.kind == "stone" \
						and _last_bolt.shape == String(FLOWED.get(se, "")) and _last_bolt.caster == p
			if el == "water" and se == "air_lance":
				# (the Turn's Lance leaves as an ice lance, the turner's)
				rok = rok and is_instance_valid(_last_bolt) and _last_bolt.kind == "ice" and _last_bolt.caster == p
			if el == "fire" and se in ["air", "air_lance"]:
				# (a Parry's air leaves as fire, the parrier's)
				rok = rok and is_instance_valid(_last_bolt) and _last_bolt.kind == "fire" and _last_bolt.caster == p
			if el == "water" and se == "air":
				# (the Turn's air leaves as mini ice spears, the turner's)
				rok = rok and is_instance_valid(_last_bolt) and _last_bolt.kind == "ice" and _last_bolt.shape == "shards" \
						and _last_bolt.caster == p
			if el == "water" and se == "earth":
				# (the Turn's stone leaves as a spear of mud that drenches, the turner's)
				rok = rok and is_instance_valid(_last_bolt) and _last_bolt.shape == "mud_spear" and _last_bolt.caster == p \
						and float(_last_bolt.info.get("mud_s", 0.0)) > 0.0
			if el == "fire" and se == "earth":
				# (the Parry's stone leaves as a magma ball, burning, the parrier's)
				rok = rok and is_instance_valid(_last_bolt) and _last_bolt.shape == "magma" and _last_bolt.heated \
						and _last_bolt.caster == p
			if el == "air" and se in ["earth", "water"]:
				# (the Wind Guard sends it back as it was, his)
				rok = rok and is_instance_valid(_last_bolt) and _last_bolt.kind == String((SHOTS[se] as Dictionary).kind) \
						and _last_bolt.caster == p
			var ok_p := through.is_empty() and (pf[1] as Array).has("perfect") and rok
			_expect(ok_p, "%s's guard, a %s shot on the beat: nothing through, %s (%s, %s)" % [el, se, reward if reward != "" else "no reward", pf[1], end])
			var lt := await _met(el, se, 0.6)
			var lth: Array = lt[0]
			var ok_l := false
			if el == "earth" and se == "earth":
				ok_l = lth.is_empty() and BendZone.held_stone(p) != null    # (a late catch inside its window: still a full catch)
			else:
				var k := (lth[0].kv as Vector3).length() / maxf(float(base[se]), 0.01) if lth.size() == 1 else -1.0
				ok_l = lth.size() == 1 and bool(lth[0].info.get("slide_only", false)) and absf(k - 0.5) < 0.05
			_expect(ok_l, "%s's guard, a %s shot late: %s (%s)" % [el, se, "a full catch" if el == "earth" and se == "earth" else "half through as a slide",
					lth.map(func(e: Dictionary) -> String: return "%.2f slide %s" % [(e.kv as Vector3).length(), e.info.get("slide_only", false)])])
			all_ok = all_ok and ok_p and ok_l
	metrics["shield_all_ok"] = all_ok


## A cone, a Column and a flying Spike against a guard: perfect nothing, late half as a slide.
func _other_shapes() -> void:
	var wave: Dictionary = ((SwayMoves.move("wave").bend as Dictionary).push as Dictionary).duplicate()
	for wait: float in [0.2, 0.6]:
		await _calm("earth")
		var foot := p.global_position
		RingLevel.place(foe, Transform3D(Basis.IDENTITY, foot + (_foe_at - foot).normalized() * 3.0))
		_foe_at = foe.global_position
		var z := _guard("earth")
		await _secs(wait)
		var s := wave.duplicate()
		s["_info"] = {"tag": "wave/push"}
		var flat := (p.global_position - foe.global_position)
		flat.y = 0.0
		BendEffects.cone(foe, foe.global_position + Vector3.UP, flat.normalized(), s)
		await _ticks(2)
		var hs := _hits_on(p)
		if wait < 0.3:
			_expect(hs.is_empty() and z.results.has("perfect"), "a Wave met by earth's guard on the beat: nothing through (%s)" % [z.results])
		else:
			_expect(hs.size() == 1 and bool(hs[0].info.get("slide_only", false)), "a Wave met late: half through as a slide (%d)" % hs.size())
		_foe_at = Vector3.INF
		RingLevel.place(foe, rm.ring.spawn(1 - rm.player_end))
		await _ticks(2)
	# a Column under him, met by fire's guard
	for wait: float in [0.2, 0.6]:
		await _calm("fire")
		var z2 := _guard("fire")
		await _secs(wait)
		BendEffects.status_at(foe, p.global_position, {"radius_m": 1.3, "up_mps": 11.0, "damage": 10.0, "kind": "stone", "_info": {"tag": "earth_shove/column"}})
		await _ticks(2)
		var hs2 := _hits_on(p)
		var kv: Vector3 = hs2[0].kv if hs2.size() == 1 else Vector3.ZERO
		if wait < 0.3:
			_expect(hs2.is_empty() and z2.results.has("perfect"), "a Column met by fire's guard on the beat: nothing through")
		else:
			_expect(hs2.size() == 1 and bool(hs2[0].info.get("slide_only", false)) and absf(kv.y - 5.5) < 0.1,
					"a Column met late: half its throw (%.1f m/s) as a slide" % kv.y)
	# a flying Spike met by water's guard (a cell round 2 let pass): on the beat it drops, late half through
	for beat: bool in [true, false]:
		await _calm("water")
		var z3: BendZone = null
		if not beat:
			z3 = _guard("water")                      # (stood as he throws: it arrives past the beat)
		BendCast.cast(fbc, "stone_form", "spike")
		if beat:
			# (stood as the stone comes within 0.15 s of the guard's reach: it arrives on the beat)
			await _until(func() -> bool:
				for l in get_nodes_in_group(GustLift.GROUP):
					var gl := l as GustLift
					if gl.phase == GustLift.Phase.FLIGHT and gl.stone.global_position.distance_to(_chest()) <= 2.2 + gl.velocity.length() * 0.15:
						return true
				return false, 3.0)
			z3 = _guard("water")
		var res: Array[String] = z3.results
		await _until(func() -> bool: return not _hits_on(p).is_empty() or not res.is_empty(), 3.0)
		await _secs(0.3)
		var hs3 := _hits_on(p)
		if beat:
			_expect(res.has("perfect") and hs3.is_empty(), "a Spike met by water's guard on the beat drops: nothing through (%s)" % [res])
		else:
			_expect(res.has("late") and hs3.size() == 1 and bool(hs3[0].info.get("slide_only", false)),
					"a Spike met late by water's guard: half through as a slide (%s, %d)" % [res, hs3.size()])


# ---------------------------------------------------------------- lightning (spec §2.5)
func _lightning() -> void:
	var spec: Dictionary = ((SwayMoves.move("fire_arc").bend as Dictionary).lightning as Dictionary).duplicate()
	spec["flash_s"] = 0.0
	var base := 0.0
	await _calm("earth")
	BendEffects.apply(fbc, "fire_arc", "lightning", spec)
	await _ticks(2)
	var hb := _hits_on(p)
	base = (hb[0].kv as Vector3).length() if not hb.is_empty() else 0.0
	_expect(base > 0.0, "Lightning hits the unguarded player (%.2f)" % base)
	for el: String in GUARDS:
		for wait: float in [0.15, 0.6]:
			await _calm(el)
			_guard(el)
			await _secs(wait)
			BendEffects.apply(fbc, "fire_arc", "lightning", spec)
			await _ticks(2)
			var hs := _hits_on(p)
			var rec := BendEffects.last_of(fbc)
			if el == "fire" and wait < 0.3:
				_expect(hs.is_empty() and bool(rec.get("redirected", false)), "Lightning on the beat into fire's Parry goes back (%s)" % [rec.get("redirected", false)])
			else:
				var k := (hs[0].kv as Vector3).length() / base if hs.size() == 1 else -1.0
				_expect(hs.size() == 1 and bool(hs[0].info.get("slide_only", false)) and absf(k - 0.5) < 0.05,
						"Lightning into %s's guard %s: late, half through as a slide (%.2f)" % [el, "on the beat" if wait < 0.3 else "late", k])


# ---------------------------------------------------------------- earth's window (spec §2.5)
func _earth_window() -> void:
	await _calm("earth")
	var z := _guard("earth")
	z.life_s = 2.5                                   # (held: the player's held guard keeps it up)
	await _secs(0.6)
	_shoot(SHOTS.earth, z.radius + 0.6, "stone_form/spike")
	await _secs(0.3)
	var first := _hits_on(p).is_empty() and BendZone.held_stone(p) != null
	_expect(first, "earth's guard 0.6 s after standing catches a stone whole (held %s)" % [BendZone.held_stone(p)])
	await _calm("earth")
	var z2 := _guard("earth")
	z2.life_s = 2.5
	await _secs(1.4)
	_shoot(SHOTS.earth, z2.radius + 0.6, "stone_form/spike")
	await _secs(0.3)
	var hs := _hits_on(p)
	var loose := 0
	for s in get_nodes_in_group(FormStone.GROUP):
		if (s as Node).has_meta(FormStone.LOOSE_META) and (s as Node3D).global_position.distance_to(p.global_position) < 2.0:
			loose += 1
	_expect(hs.size() == 1 and bool(hs[0].info.get("slide_only", false)) and BendZone.held_stone(p) == null and loose >= 1,
			"held past its 1.0 s window, a stone is late: half through (%d), dropped loose at his feet (%d), not held" % [hs.size(), loose])


# ---------------------------------------------------------------- the player's guard (spec §4.4)
func _player_guard() -> void:
	await _calm("earth")
	c.guard_override = true
	var t_up := await _until(func() -> bool: return c.guard_up(), 1.0)
	var held_when_up := c._guard_down()
	var lock := float(SwayMoves.move("stone_catch").get("lock_s", 0.2)) * c.tier_mult("stone_catch")
	_expect(t_up < INF and held_when_up and t_up <= lock + 0.05, "E's guard stands when its lock fills (%.2f s, the lock %.2f), E still held" % [t_up, lock])
	metrics["guard_stand_at_fill_ok"] = t_up < INF and held_when_up
	await _secs(2.0)
	var still := c.guard_up()
	await _secs(0.7)
	var gone := not c.guard_up()
	c.guard_override = false
	await _ticks(3)
	_expect(still and gone, "held, it stays up to 2.5 s (%s at 2.2 s) and no longer (%s at 2.9 s)" % [still, gone])
	# a tap: its window (earth 1.0 s)
	await _calm("earth")
	c.guard_override = true
	await _ticks(3)
	c.guard_override = false
	var t0 := BendStatus.now()
	await _until(func() -> bool: return c.guard_up(), 1.0)
	var up_at := BendStatus.now()
	await _until(func() -> bool: return not c.guard_up(), 3.0)
	var lasted := BendStatus.now() - up_at
	_expect(absf(lasted - 1.0) < 0.1 and up_at - t0 < 0.3, "a tap of E stands it for its window (%.2f s)" % lasted)
	# the whiff: the next guard's lock 0.5 s
	await _secs(0.2)
	c.guard_override = true
	await _until(func() -> bool: return c.state != SwayCaster.State.IDLE or c.guard_up(), 1.0)
	var wl := c.lock_s
	await _until(func() -> bool: return c.guard_up(), 1.5)
	c.guard_override = false
	await _ticks(3)
	_expect(absf(wl - Bending.rule("whiff_lock_s", 0.5)) < 0.02, "a guard that took nothing makes the next one's lock 0.5 s (%.2f)" % wl)
	# E mid-lock drops the lock
	await _calm("earth")
	await _secs(1.6)
	p.hotbar.select(0)
	await _ticks(2)
	c.held_override = true
	await _secs(0.3)
	var locking := c.state != SwayCaster.State.IDLE and c.lock_src == SwayCaster.SRC_AIM
	c.guard_override = true
	await _ticks(2)
	var dropped := c.last_break == "guard"
	var up := await _until(func() -> bool: return c.guard_up(), 1.0) < INF
	c.guard_override = false
	c.held_override = false
	await _ticks(3)
	_expect(locking and dropped and up, "E mid-lock drops the lock (%s) and guards (%s)" % [c.last_break, up])
	# a cast key drops the guard
	await _calm("earth")
	await _secs(1.6)
	c.guard_override = true
	await _until(func() -> bool: return c.guard_up(), 1.0)
	c.held_override = true
	var dt := await _until(func() -> bool: return not c.guard_up(), 1.0)
	var lock_on := c.state != SwayCaster.State.IDLE and c.lock_src == SwayCaster.SRC_AIM
	c.guard_override = false
	c.held_override = false
	await _ticks(3)
	_expect(dt <= 0.15 and lock_on, "a cast key drops the guard in 0.1 s (%.2f) and starts its lock (%s)" % [dt, lock_on])


# ---------------------------------------------------------------- the perfect guard's cast reward (2026-10-11)
## The lock time key 1's move takes the player now: its lock begun by the aim held, read, then dropped (no cast).
func _key1_lock() -> float:
	p.hotbar.select(0)
	await _ticks(2)
	c.held_override = true
	await _until(func() -> bool: return c.state != SwayCaster.State.IDLE and c.lock_src == SwayCaster.SRC_AIM, 1.0)
	var ls := c.lock_s
	c.held_override = false
	c.drop_all()
	await _ticks(3)
	return ls


## The owner: "if the user E a spell the it has to have that perfect thing they get one faster move cast buff", "the person
## that got parried ... has a slightly slower cast time" (15% for 3 s; rules.json stock.parry): a perfect guard makes the
## guarder's next cast's lock 0.85 of its time and the shooter's 1.15, one cast each, spent by it; late, nothing; unused, gone
## after 3 s; a bot's lock the same.
func _parry_reward() -> void:
	await _calm("fire")
	await _secs(1.6)
	var base_lock := await _key1_lock()
	var fb := foe.brain.bending as NpcBending
	var bot_move := "fire_blast"
	fb.begin(bot_move, "punch")
	var bot_base := fb.lock_s
	fb._cancel()
	await _met("fire", "fire", 0.2)                  # (fire's Parry on the beat: the shot sent back)
	var got := BendStatus.cast_mult(p)
	var owed := BendStatus.cast_mult(foe)
	_expect(absf(got - 0.85) < 0.001 and absf(owed - 1.15) < 0.001,
			"a perfect guard: the guarder's next cast 15%% quicker (x%.2f), the shooter's 15%% slower (x%.2f)" % [got, owed])
	await _secs(0.3)
	var quick := await _key1_lock()
	_expect(absf(quick - base_lock * 0.85) < 0.02 and absf(BendStatus.cast_mult(p) - 0.85) < 0.001,
			"...his next lock 0.85 of its time (%.2f s from %.2f), not spent by a lock dropped" % [quick, base_lock])
	fb.begin(bot_move, "punch")
	var slow := fb.lock_s
	fb._cancel()
	_expect(absf(slow - bot_base * 1.15) < 0.02, "...the shooter bot's next lock 1.15 of its time (%.2f s from %.2f)" % [slow, bot_base])
	p.hotbar.select(0)
	await _ticks(2)
	c.held_override = true
	await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 2.0)
	c.held_override = false
	await _secs(0.5)
	_expect(not p.has_meta(BendStatus.CAST_MULT_META) and foe.has_meta(BendStatus.CAST_MULT_META),
			"...one cast: his cast spends it (the shooter's still owed)")
	await _met("fire", "fire", 0.6)
	_expect(is_equal_approx(BendStatus.cast_mult(p), 1.0) and is_equal_approx(BendStatus.cast_mult(foe), 1.0),
			"a late guard: no reward, no penalty")
	await _met("fire", "fire", 0.2)
	await _secs(3.1)
	_expect(is_equal_approx(BendStatus.cast_mult(p), 1.0) and is_equal_approx(BendStatus.cast_mult(foe), 1.0),
			"unused, both are gone after 3 s")


# ---------------------------------------------------------------- the classic ring (round 2's guard kept)
func _classic() -> void:
	_stock(false)
	await _calm("earth")
	await _secs(1.6)
	_expect(not RingRules.stock_on(), "the classic ring: the gate off")
	c.guard_override = true
	await _secs(0.5)
	var during := c.guard_up()
	c.guard_override = false
	var after := await _until(func() -> bool: return c.guard_up(), 0.5) < INF
	_expect(not during and after, "in the classic ring the guard stands at E's release as round 2 (held %s, after %s)" % [during, after])
	# (round 2's matrix since 2026-10-12: earth's catch sends fire on the beat back on its own as a magma ball, nothing held, as
	# in the % ring)
	var r := await _met("earth", "fire", 0.2)
	var held := BendZone.held_stone(p)
	var magma := is_instance_valid(_last_bolt) and _last_bolt.shape == "magma" and _last_bolt.heated and _last_bolt.caster == p
	_expect((r[0] as Array).is_empty() and (r[1] as Array) == ["perfect"] and held == null and magma,
			"and its catch sends fire back on its own as a burning magma ball, nothing held, as round 2 (%s, %d hits, magma %s)"
			% [r[1], (r[0] as Array).size(), magma])
	_stock(true)
