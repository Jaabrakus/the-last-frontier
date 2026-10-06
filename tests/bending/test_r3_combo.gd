extends SceneTree
## Round 3's strings (AIR; smash_r3 spec §6.4-6.7, §15 "test_r3_combo"), in Tidebreak's ring (scenes/ring.tscn; the foe held
## 3 m before the player). The gate on through FakeRules (a RingRules with rule_set "stock", made the current one). The hits
## are BendR3's (the info the % rules take); whether a string is true is judged by the test's stand-in for PERCENT's hitstun
## (spec §3.1, §6.7: the set stuns, 0.045 s per m/s of a launch by RingRules.launch_v and the spec's classes, the decay
## 0.8 a hit to 0.4, the Pop exempt, a jab after the Pop 0.10 s, the 6th hit 0.10 s, the 0.4 s breather after a 4+ string,
## a stun counted to 0.6 s at most), so AIR's timing is checked before PERCENT merges; the merger re-runs it with PERCENT's own.
##   the jab     the step (the next jab ready 0.15 s after the last left the hand, decided at the hit); the third that hits the
##               Pop (tag jab/pop, a set 9 m/s at 80 deg, set_stun 0.60); one Pop a string; after it a plain lock; a miss
##               or a guard back to step 1; earth's Pop leaves a stone in the hand and E throws it (rock_jab/pop_stone, not a
##               return)
##   the probes  Embers, Embers, Pop, Punch at 0% and 150% true; Pebbles, Pebbles, Pop, E (the Pop's stone) true at both;
##               Palm, Palm, Pop, Slice true; a Spike after the Pop not
##   self-loops  Embers, Palm, Pebbles and Pull x12 at 0% and 150%: the longest true run (<= 4; Pull <= 2) and the gaps after
##   no Chain    a landed hit never shortens a lock other than the jab step
## METRIC lines (bnb_true_0pct_<element>, bnb_true_150pct_<element>, self_loop_max_run_<jab>, self_loop_min_gap_<jab>,
## jab_step_s, pop_once_ok, earth_pop_stone_ok, no_chain_ok). Last line "R3 COMBO PASSED" or "R3 COMBO FAILED"; exit 0 only
## on a pass; a watchdog quits with 2.
##   Godot --headless --fixed-fps 60 --path . -s tests/bending/test_r3_combo.gd [-- real=on]
## real=on (the merge's re-run, BOTS' and AIR's ask): no stand-in; the ring's own stock RingRules (PERCENT's) and RingMoves
## (MOVE's) judge the probes: a hit is true when PERCENT's string on the foe goes on through it (RingRules.string_hits at its
## launch is the probe's count so far), from 0% and 150% (RingRules.reset_pct). METRIC bnb_real_<pct>_<row>.

const NAME := "R3 COMBO"
const WATCHDOG_S := 700.0
const OWN_CFG := "user://r3_combo_test.cfg"
## The classes the probes need (spec §2.3: d, base, growth; tag "set" a set stun instead).
const CLASSES := {"fire_blast/punch": {"d": 11.0, "base": 4.0, "growth": 10.3}, "air_blast/slice": {"d": 6.0, "base": 3.4, "growth": 14.5},
		"stone_form/spike": {"d": 14.0, "base": 5.8, "growth": 12.2}, "rock_jab/pop_stone": {"d": 14.0, "base": 5.8, "growth": 12.2}}
const SET_STUN := {"jab": 0.3, "air_gust/pull": 0.4, "jab/pop": 0.6}


class FakeRules:
	extends RingRules


var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var p: FrontierPlayer
var c: SwayCaster
var rm: RingMode
var foe: NpcFighter
var fr: FakeRules
var was_rules: RingRules
var metrics := {}
var released: Array = []
var _foe_at := Vector3.INF
var real := false
## real=on: each launch of the foe as PERCENT counted it ([t, string_hits, tag]).
var real_hits: Array = []


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
	real = OS.get_cmdline_user_args().has("real=on")
	# (the merge: rules.json plays stock by default; AIR's stand-ins (FakeRules) are this test's gate, the ring itself classic;
	# real=on plays the stock ring itself)
	RingRules.rule_set_override = "stock" if real else "classic"
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
	c.cast_released.connect(func(m: String, md: String) -> void: released.append([m, md, BendStatus.now()]))
	await _until(func() -> bool: return p.arena_element == "earth" and p.hotbar.spell != "", 6.0)
	rm = RingMode.find(self)
	if rm != null:
		await _until(func() -> bool: return rm.phase == "FIGHT", 10.0)
		foe = rm.foe
		rm.rules.soft_walls = false
	_expect(foe != null, "the foe")
	if foe == null:
		return _end()
	physics_frame.connect(_hold)
	await _secs(0.4)
	if real:
		await _real_probes()
		return _end()
	was_rules = RingRules.current()
	fr = FakeRules.new()
	fr.rule_set = "stock"
	RingRules._current = fr
	await _jab_string()
	await _resets()
	await _pop_stone()
	await _probes()
	await _self_loops()
	await _no_chain()
	_end()


func _end() -> void:
	if c != null:
		c.held_override = null
		c.quick_override = null
		c.guard_override = null
	if fr != null:
		RingRules._current = was_rules
		fr.free()
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


## The player 3 m before the foe facing him, as `el`, nothing about, every button let go, the string's books clear.
func _calm(el: String, d := 3.0) -> void:
	c.held_override = false
	c.quick_override = false
	c.guard_override = false
	if p.arena_element != el:
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
		var kn := BendKnock.peek(b)
		if kn != null:
			kn.reset()
	var axis := rm.ring.axis()
	var at := _foe_at - axis * signf(axis.dot(_foe_at - rm.ring.center())) * d
	at.y = rm.ring.deck_y()
	var face := _foe_at - at
	face.y = 0.0
	RingLevel.place(p, Transform3D(Basis.looking_at(face.normalized(), Vector3.UP), at))
	p.velocity = Vector3.ZERO
	p.health = p.max_health
	p.pitch = -0.12
	foe.health = foe.health_max
	if rm.phase == "FIGHT":
		rm.phase_t = 0.0
	BendR3._reset(BendCaster.of(p))
	BendR3.hits_log.clear()
	released.clear()
	await _secs(0.4)


func _tap(i: int) -> void:
	p.hotbar.select(i)
	await physics_frame


## One cast on `src` ("quick" LMB, "aim" RMB, "guard" E) as fast as it may: held until full, let go: its release time.
func _cast(src: String, limit := 3.0) -> float:
	_press(src, true)
	await _until(func() -> bool: return c.state == SwayCaster.State.FULL, limit)
	var n := released.size()
	_press(src, false)
	await _until(func() -> bool: return released.size() > n, 0.5)
	return float(released.back()[2]) if released.size() > n else INF


func _press(src: String, on: bool) -> void:
	match src:
		"quick":
			c.quick_override = on
		"aim":
			c.held_override = on
		"guard":
			c.guard_override = on


## The hits on the foe as the rules count them: the first projectile of each volley; [{t, tag, info}] by time.
func _counted() -> Array:
	var seen := {}
	var out: Array = []
	for e: Dictionary in BendR3.hits_log:
		if e.n != foe:
			continue
		var vid := int(e.info.get("volley_id", 0))
		if vid != 0:
			if seen.has(vid):
				continue
			seen[vid] = true
		out.append({"t": float(e.at), "tag": String(e.tag), "info": e.info, "kv": e.kv})
	return out


# ---------------------------------------------------------------- the stand-in hitstun (PERCENT's, spec §3.1, §6.7)
## The stun of a hit of `tag` (jab tags as "jab") on a body at `pct` (before it): set stuns, else 0.045 s per m/s.
func _raw_stun(tag: String, info: Dictionary, pct: float) -> float:
	if String(info.get("tag", "")) == "jab/pop":
		return 0.6
	if bool(info.get("jab", false)):
		return float(SET_STUN.jab)
	if SET_STUN.has(tag):
		return float(SET_STUN[tag])
	var cls: Dictionary = CLASSES.get(tag, {})
	if cls.is_empty():
		return 0.3
	var d := float(cls.d)
	var v := RingRules.launch_v(cls, pct + d, d, 1.0)
	return clampf(0.045 * v, 0.12, 1.2)


## The string judged over `hits` (_counted) from `pct0`: {runs (true runs' lengths), longest, gaps (free time before each
## hit after the first string ended), trues (per hit: in his hitstun)}.
func _judge(hits: Array, pct0: float) -> Dictionary:
	var free_at := -INF
	var n := 0
	var popped := false
	var run := 0
	var longest := 0
	var breather := -INF
	var gaps: Array = []
	var trues: Array = []
	var pct := pct0
	var ended_once := false
	for h: Dictionary in hits:
		var t := float(h.t)
		var inside := t <= free_at
		trues.append(inside)
		if not inside:
			if n >= 4:
				breather = free_at + 0.4
			if n > 0:
				ended_once = true
				gaps.append(t - free_at)
			n = 0
			popped = false
			run = 0
		n += 1
		run += 1
		longest = maxi(longest, run)
		var info: Dictionary = h.info
		var tag := String(h.tag)
		var s := _raw_stun(tag, info, pct)
		if tag == "jab/pop":
			popped = true
		else:
			s *= maxf(pow(0.8, n - 1), 0.4)
			if popped and bool(info.get("jab", false)):
				s = 0.1 * maxf(pow(0.8, n - 1), 0.4)
		if n >= 6:
			s = minf(s, 0.1)
		if t < breather:
			s = minf(s, 0.1)
		free_at = t + minf(s, 0.6)
		pct += float((CLASSES.get(tag, {}) as Dictionary).get("d", 4.0))
	return {"longest": longest, "gaps": gaps, "trues": trues}


# ---------------------------------------------------------------- the jab string (spec §6.4)
func _jab_string() -> void:
	await _calm("earth")
	var bc := BendCaster.of(p)
	var t1 := await _cast("quick")
	await _until(func() -> bool: return _counted().size() >= 1, 1.0)
	var step := bc.jab_step_until - t1
	var t2 := await _cast("quick")
	await _until(func() -> bool: return _counted().size() >= 2, 1.0)
	var t3 := await _cast("quick")
	await _until(func() -> bool: return _counted().size() >= 3, 1.0)
	var t4 := await _cast("quick")
	await _until(func() -> bool: return _counted().size() >= 4, 1.0)
	await _secs(0.3)
	var hs := _counted()
	var hit1 := float(hs[0].t) if hs.size() > 0 else INF
	var base := c._lock_time("rock_jab", null, 0.0, 10.0) if false else float(SwayMoves.move("rock_jab").lock_s) * c.tier_mult("rock_jab")
	_expect(absf(step - 0.15) < 0.01, "a jab that hits owes the step: the next ready 0.15 s after the last left the hand (%.3f)" % step)
	metrics["jab_step_s"] = snappedf(step, 0.001)
	_expect(t2 - t1 <= maxf(0.15, hit1 - t1) + 0.07 and t2 - t1 < base * 0.9,
			"the second jab goes at the step (%.2f s after the first; its own lock %.2f; the hit at %.2f)" % [t2 - t1, base, hit1 - t1])
	var pop: Dictionary = hs[2] if hs.size() > 2 else {}
	var kv: Vector3 = pop.get("kv", Vector3.ZERO)
	var ang := rad_to_deg(atan2(kv.y, Vector2(kv.x, kv.z).length()))
	_expect(String(pop.get("tag", "")) == "jab/pop" and is_equal_approx(float((pop.get("info", {}) as Dictionary).get("set_stun", 0.0)), 0.6) \
			and absf(kv.length() - 9.0) < 0.05 and absf(ang - 80.0) < 0.5,
			"the third jab that hits is the Pop: jab/pop, set 0.60 s, %.2f m/s at %.1f deg (%s)" % [kv.length(), ang, pop.get("tag", "-")])
	var fourth: Dictionary = hs[3] if hs.size() > 3 else {}
	var once := String(fourth.get("tag", "")) == "rock_jab/pebbles"
	_expect(once, "one Pop a string: the fourth jab is a plain jab (%s)" % fourth.get("tag", "-"))
	_expect(t4 - t3 >= base * 0.95, "after the Pop the jab's own lock again, no step (%.2f, its lock %.2f)" % [t4 - t3, base])
	metrics["pop_once_ok"] = once
	var held := BendZone.held_stone(p)
	_expect(held != null and held.has_meta(BendR3.POP_STONE_META), "earth's Pop leaves a stone in the hand (%s)" % [held])


func _resets() -> void:
	# a miss: the string back to step 1
	await _calm("water")
	await _cast("quick")
	await _until(func() -> bool: return _counted().size() >= 1, 1.0)
	p.yaw += PI * 0.6
	await _ticks(3)
	await _cast("quick")
	await _secs(0.4)
	p.yaw -= PI * 0.6
	await _ticks(3)
	await _cast("quick")
	await _until(func() -> bool: return _counted().size() >= 2, 1.0)
	var st := BendCaster.of(p).jab
	_expect(_counted().size() == 2 and int(st.get("hits", 0)) == 1, "a jab that misses puts the string back to step 1 (%d hits counted, string %d)" % [_counted().size(), int(st.get("hits", 0))])
	# a guard: back to step 1
	await _calm("water")
	await _cast("quick")
	await _until(func() -> bool: return _counted().size() >= 1, 1.0)
	var spec: Dictionary = (SwayMoves.move("water_redirect").bend as Dictionary).redirect
	c.quick_override = true
	await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 2.0)
	var z := BendZone.make(foe, "redirect", foe.global_position, spec, -foe.global_basis.z)
	z.perfect_s = 2.0                                # (on the beat whenever it arrives: the test's)
	c.quick_override = false
	await _secs(0.5)
	var st2 := BendCaster.of(p).jab
	_expect(z.r2 and int(st2.get("hits", 0)) == 0, "a jab the foe's guard takes puts the string back to step 1 (%d)" % int(st2.get("hits", 0)))
	# the rules' string over (RingRules.string_ended): his jab string starts over (one Pop a string)
	await _calm("water")
	await _cast("quick")
	await _until(func() -> bool: return _counted().size() >= 1, 1.0)
	var before := int(BendCaster.of(p).jab.get("hits", 0))
	fr.string_ended.emit(p, foe, 1, 4.0)
	var after := int(BendCaster.of(p).jab.get("hits", 0))
	_expect(before == 1 and after == 0, "the rules' string_ended puts his jab string back to step 1 (%d, then %d)" % [before, after])


func _pop_stone() -> void:
	await _calm("earth")
	for i in 3:
		await _cast("quick")
		await _until(func() -> bool: return _counted().size() >= i + 1, 1.0)
	var held := BendZone.held_stone(p)
	BendR3.hits_log.clear()
	await _cast("guard")
	await _until(func() -> bool: return _counted().any(func(e: Dictionary) -> bool: return e.tag == "rock_jab/pop_stone"), 2.0)
	var hs := _counted().filter(func(e: Dictionary) -> bool: return not (e.tag in ["rock_jab/pebbles", "jab/pop"]))
	var ok := held != null and hs.size() == 1 and String(hs[0].tag) == "rock_jab/pop_stone" and not bool(hs[0].info.get("returned", false))
	_expect(ok, "E throws the Pop's stone: rock_jab/pop_stone, not a return (%s)" % [hs.map(func(e: Dictionary) -> String: return e.tag)])
	metrics["earth_pop_stone_ok"] = ok


# ---------------------------------------------------------------- the engine probes (spec §6.6)
## Jab, jab, Pop as `el`, then `follow` ("aim": key 1's readied move; "guard": E), from `pct`: whether the follow-up is true
## and the string's hits.
func _probe(el: String, follow: String, key1 := 0) -> Array:
	await _calm(el)
	if follow == "aim":
		await _tap(key1)
		await _secs(0.35)
		if c.readied_spell == "air_gust" or c.readied_spell == "air_blast":
			var d := NpcSenses.chest_of(foe) - p.camera.global_position
			p.pitch = asin(clampf(d.normalized().y, -1.0, 1.0))  # (a wave goes along the aim's own line: on him)
			await _ticks(3)
	for i in 3:
		await _cast("quick")
		if i < 2:
			await _until(func() -> bool: return _counted().size() >= i + 1, 1.0)
	# (its lock begun as the Pop leaves the hand, spec §6.6, and clicked: it goes the moment it is full, as a player who
	# knows the string presses it)
	_press(follow, true)
	await _ticks(3)
	_press(follow, false)
	await _until(func() -> bool: return _counted().size() >= 4, 2.5)
	await _secs(0.2)
	return _counted()


func _probes() -> void:
	# (spec §6.6: fire's Punch, earth's Pop stone with E, air's Slice or Gust; the air row is true when either is, and each
	# is printed with the time the Pop left it)
	var rows := [["fire", "aim", 0, "fire"], ["earth", "guard", 0, "earth"], ["air", "aim", 0, "air_slice"], ["air", "aim", 1, "air_gust"]]
	var air_any := {0.0: false, 150.0: false}
	for row: Array in rows:
		var el := String(row[0])
		var hs := await _probe(el, String(row[1]), int(row[2]))
		var ok := {}
		var spare := INF
		for pct: float in [0.0, 150.0]:
			var j := _judge(hs, pct)
			var tr: Array = j.trues
			ok[pct] = hs.size() >= 4 and tr.size() >= 4 and bool(tr[1]) and bool(tr[2]) and bool(tr[3])
			metrics["bnb_true_%dpct_%s" % [int(pct), String(row[3])]] = ok[pct]
			if el == "air":
				air_any[pct] = bool(air_any[pct]) or bool(ok[pct])
		if hs.size() >= 4:
			spare = 0.6 - (float(hs[3].t) - float(hs[2].t))
		metrics["bnb_spare_s_%s" % String(row[3])] = snappedf(spare, 0.01) if spare < INF else -1.0
		if el != "air":
			_expect(ok[0.0] and ok[150.0], "%s: jab, jab, Pop, %s true at 0%% and 150%% (%s)" % [el, hs[3].tag if hs.size() > 3 else "-",
					hs.map(func(e: Dictionary) -> String: return "%s@%.2f" % [e.tag, e.t])])
		else:
			print("    (air: jab, jab, Pop, %s: %s; spare %.3f s)" % [hs[3].tag if hs.size() > 3 else "-", "true" if ok[0.0] else "dropped", spare])
	metrics["bnb_true_0pct_air"] = air_any[0.0]
	metrics["bnb_true_150pct_air"] = air_any[150.0]
	_expect(bool(air_any[0.0]) and bool(air_any[150.0]), "air: jab, jab, Pop, then Slice or Gust true at 0%% and 150%% (Slice %s, Gust %s)" % [
			metrics.get("bnb_true_0pct_air_slice"), metrics.get("bnb_true_0pct_air_gust")])
	# a Spike after the Pop is not
	var sp := await _probe("earth", "aim", 0)
	var jt := _judge(sp, 0.0)
	var tr2: Array = jt.trues
	_expect(sp.size() >= 4 and not bool(tr2[3]), "earth: a Spike after the Pop is not true (%s)" % [sp.map(func(e: Dictionary) -> String: return "%s@%.2f" % [e.tag, e.t])])
	# Slice x4 (the same move, aerials_v1_prev's table): the hit it drops by, at 0% and 150%
	await _calm("air")
	await _tap(0)
	await _secs(0.35)
	for i in 4:
		await _cast("aim")
	await _secs(0.4)
	var sl := _counted()
	var drops := {}
	for pct: float in [0.0, 150.0]:
		var tr3: Array = _judge(sl, pct).trues
		var at := -1
		for k in range(1, tr3.size()):
			if not bool(tr3[k]):
				at = k + 1
				break
		drops[pct] = at
	metrics["slice4_drops_by_hit"] = "%d at 0%%, %d at 150%%" % [int(drops[0.0]), int(drops[150.0])]
	_expect(sl.size() == 4 and int(drops[0.0]) == 2, "Slice x4 drops by hit 2 at 0%% (%s; %d hits)" % [metrics.slice4_drops_by_hit, sl.size()])


# ---------------------------------------------------------------- real=on: PERCENT's own string on the probes
## The probes in the stock ring itself: jab, jab, Pop, then the follow-up, from 0% and 150%; each hit true when PERCENT's
## string goes on through it (string_hits at its launch = its place in the probe).
func _real_probes() -> void:
	var rr := RingRules.current()
	_expect(RingRules.stock_on() and rr != null and RingMoves.of(p) != null and RingMoves.of(foe) != null,
			"real=on: the stock ring's own RingRules and RingMoves (PERCENT's, MOVE's)")
	if rr == null:
		return
	rr.launched.connect(func(b: Node3D, _v: Vector3, _hs: float, _by: Node, tag: String) -> void:
		if b == foe:
			real_hits.append([BendStatus.now(), rr.string_hits(foe), tag]))
	var rows := [["fire", "aim", 0, "fire"], ["earth", "guard", 0, "earth"], ["air", "aim", 0, "air_slice"], ["air", "aim", 1, "air_gust"]]
	var air_any := {0.0: false, 150.0: false}
	for row: Array in rows:
		var el := String(row[0])
		for pct: float in [0.0, 150.0]:
			await _calm(el)
			await _secs(0.6)                          # (past any breather of the last probe's string)
			rr.reset_pct(foe, pct)
			rr.reset_pct(p, 0.0)
			real_hits.clear()
			await _probe(el, String(row[1]), int(row[2]))
			var hs := real_hits.duplicate()
			var ok := hs.size() >= 4 and int(hs[1][1]) == 2 and int(hs[2][1]) == 3 and int(hs[3][1]) == 4
			metrics["bnb_real_%dpct_%s" % [int(pct), String(row[3])]] = ok
			print("    (real %s from %d%%: %s)" % [String(row[3]), int(pct), hs.map(func(e: Array) -> String: return "%s@%.2f#%d" % [e[2], float(e[0]), int(e[1])])])
			if el == "air":
				air_any[pct] = bool(air_any[pct]) or ok
			else:
				_expect(ok, "real: %s jab, jab, Pop, %s true from %d%% (PERCENT's string through every hit)" % [el, hs[3][2] if hs.size() > 3 else "-", int(pct)])
	_expect(bool(air_any[0.0]) and bool(air_any[150.0]), "real: air jab, jab, Pop, then Slice or Gust true at 0%% and 150%% (Slice %s/%s, Gust %s/%s)" % [
			metrics.get("bnb_real_0pct_air_slice"), metrics.get("bnb_real_150pct_air_slice"), metrics.get("bnb_real_0pct_air_gust"),
			metrics.get("bnb_real_150pct_air_gust")])


# ---------------------------------------------------------------- self-loops (spec §6.6)
func _self_loops() -> void:
	var rows := {"embers": ["fire", "quick"], "palm": ["air", "quick"], "pebbles": ["earth", "quick"], "pull": ["air", "aim"]}
	for name: String in rows:
		var el := String(rows[name][0])
		var src := String(rows[name][1])
		await _calm(el)
		if name == "pull":
			await _tap(1)
			await _tap(1)
			await _secs(0.35)
			var d := NpcSenses.chest_of(foe) - p.camera.global_position
			p.pitch = asin(clampf(d.normalized().y, -1.0, 1.0))  # (Pull goes along the aim's own line: on him)
			await _ticks(3)
			_expect(c.readied_spell == "air_gust" and c.base_mode_of("air_gust") == "pull", "2 tapped twice readies Pull (%s)" % c.readied_spell)
		for i in 12:
			await _cast(src)
		await _secs(0.5)
		var hs := _counted()
		print("    (%s: %d released, hits %s)" % [name, released.size(), hs.map(func(e: Dictionary) -> String: return "%s@%.2f" % [e.tag, e.t])])
		var res := {}
		for pct: float in [0.0, 150.0]:
			var j := _judge(hs, pct)
			var gaps: Array = j.gaps
			var first_gap: float = float(gaps[0]) if not gaps.is_empty() else INF
			res[pct] = [int(j.longest), first_gap]
			print("    (%s at %d%%: the free gaps %s)" % [name, int(pct), gaps.map(func(g: float) -> String: return "%.2f" % g)])
		var cap := 2 if name == "pull" else 4
		var longest := maxi(int(res[0.0][0]), int(res[150.0][0]))
		var gap := minf(float(res[0.0][1]), float(res[150.0][1]))
		metrics["self_loop_max_run_%s" % name] = longest
		metrics["self_loop_first_gap_%s" % name] = snappedf(gap, 0.01) if gap < INF else -1.0
		_expect(hs.size() >= 8 and longest <= cap, "%s x12: %d hits, the longest true run %d (<= %d)" % [name, hs.size(), longest, cap])
		if name != "pull":
			# (the free gap once the string ends, lead_combos.out's measure; Pull's own there is 0.03 s, "a 2-hit string at
			# most": printed, not gated; the gaps after every later string are printed)
			_expect(gap >= 0.15 - 0.01, "%s x12: free at least 0.15 s before the hit after the string (%.3f)" % [name, gap])


# ---------------------------------------------------------------- no Chain (spec §1, §6.5)
func _no_chain() -> void:
	await _calm("fire", 6.0)
	await _tap(0)
	await _secs(0.35)
	c.held_override = true
	await _until(func() -> bool: return c.state != SwayCaster.State.IDLE, 1.0)
	var l0 := c.lock_s
	await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 2.0)
	c.held_override = false
	await _until(func() -> bool: return not _counted().is_empty(), 1.5)
	var hit := not _counted().is_empty()
	await _ticks(2)
	c.held_override = true
	await _until(func() -> bool: return c.state != SwayCaster.State.IDLE, 1.0)
	var l1 := c.lock_s
	await _ticks(2)
	var l2 := c.lock_s
	c.held_override = false
	await _ticks(3)
	var ok := hit and is_equal_approx(l0, l1) and is_equal_approx(l1, l2)
	_expect(ok, "a Punch that hits leaves the next Punch's lock its own (%.3f, %.3f, %.3f)" % [l0, l1, l2])
	metrics["no_chain_ok"] = ok
