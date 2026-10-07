extends SceneTree
## Round 3's % ledger and launch (smash_r3 spec v2 §2, §8, §15 PERCENT; RingRules, BendStatus, BendKnock), in the ring scene
## with a stock-rules match asked for (RingRules.rule_set_override "stock"), the foe held; every hit the test's own, through
## BendStatus.hurt / knock with round 3's hit info (AIR's tags):
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_ring_pct.gd -- mode=ring element=earth foe=water
##   launch_v    the formula for 10 classes at 0/60/120% within 0.01 m/s (and the spec table's v within 0.06); the range
##               falloff at 10/16/22/30 m (1.0/0.825/0.65/0.65); returns and Lightning exempt; the air factor 0.85, the Slam
##               and returns exempt
##   the curve   7/20/55/110 damage -> 2.4/5.6/10.2/12.4%; pct_scale scales every d; a stock hit leaves health whole
##   a volley    7 Embers landing give 4% in all, one knock, one string hit, one stale entry; 3 of 7 give 4 x 3/7
##   weights     x0.89 / x1.11; Rooted on the base only; Carried wind on all
##   stale       -8% a copy, floor -40%; returns never staled; the queue survives a fall; the Pop's stone stales
##   guards      every guard stops every attack (16 element pairs: perfect 0% and no launch, late half as a slide); Lightning
##               perfect only for fire; earth's catch full within 1.0 s of standing, late after; a return x1.2 owned by
##               the returner, the rally capped at x1.6; the Pop's stone is the Spike's class
##   Patch       the last 6 s of % only, at most 10%; refused with an empty pool, while a foe is out, in sudden death, in
##               the air
## Prints METRIC lines (launch_formula_ok, range_falloff_ok, volley_once_ok, stale_ok, shield_all_ok, patch_fresh_ok). Watchdog
## LIMIT_S; last line "RING PCT PASSED" or "RING PCT FAILED" (exit 0 only on a pass).

const NAME := "RING PCT"
const LIMIT_S := 300.0
const OWN_CFG := "user://ring_pct_test.cfg"

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var ring: RingArena
var player: FrontierPlayer
var mode: RingMode
var rules: RingRules
var metrics := {}


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _metric(key: String, ok: bool) -> void:
	metrics[key] = bool(metrics.get(key, true)) and ok


func _initialize() -> void:
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	MatchSetup._aim_help = "strong"
	GameSettings.path = OWN_CFG
	# (round 4's merge: BOTS2 set rules.json stock.pct_scale 0.86 for the match pace; this test checks the spec's ledger
	# and flights at scale 1, so it pins the scale at 1 for its run: RingRules.data() is read once and kept)
	(RingRules.data()["stock"] as Dictionary)["pct_scale"] = 1.0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	RingRules.rule_set_override = "stock"
	SwayCaster.free_override = true
	InputSetup.ensure()
	MatchSetup.incoming = true
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(s: float) -> void:
	await _ticks(maxi(int(round(s * Engine.physics_ticks_per_second)), 1))


func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit:
		if cond.call():
			return t
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return INF


func _end() -> void:
	for k: String in ["launch_formula_ok", "range_falloff_ok", "volley_once_ok", "stale_ok", "shield_all_ok", "patch_fresh_ok"]:
		print("METRIC %s=%s" % [k, str(bool(metrics.get(k, false))).to_lower()])
	RingRules.rule_set_override = ""
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


func foe() -> NpcFighter:
	return mode.foe if mode != null and is_instance_valid(mode.foe) else null


func _go_fight() -> void:
	await _until(func() -> bool: return mode.phase == "COUNTDOWN" and foe() != null, 6.0)
	mode.phase_t = RingRules.num("countdown_s", 3.0) - 0.02
	await _until(func() -> bool: return mode.phase == "FIGHT", 2.0)
	if foe() != null:
		foe().held = true


## Both back mid-deck, still, the books cleared (% 0, strings, stale queues, safety).
func _fresh() -> void:
	var f := foe()
	for b: Node3D in [player, f]:
		if b == null:
			continue
		var kn := BendKnock.peek(b)
		if kn != null:
			kn.reset()
		if b is CharacterBody3D:
			(b as CharacterBody3D).velocity = Vector3.ZERO
	player.global_position = ring.to_global(Vector3(-4.0, ring.top() + 0.05, 0.0))
	f.global_position = ring.to_global(Vector3(4.0, ring.top() + 0.05, 0.0))
	# (a fall earlier in the test: its respawn called off, both shown and solid again)
	mode._respawns.clear()
	mode._hide(player, false)
	mode._hide(foe(), false)
	rules.reset_game()
	await _ticks(3)


## A hit of `tag` by `by` on `n` the way AIR sends it: hurt then knock along `way`, the hit info with `extra`.
func _hit(n: Node3D, by: Node3D, tag: String, extra := {}, dmg := 10.0, way := Vector3.ZERO) -> void:
	var w := way
	if w == Vector3.ZERO:
		w = n.global_position - by.global_position
		w.y = 0.0
		w = w.normalized()
	var info := {"tag": tag, "from": by.global_position}
	info.merge(extra, true)
	BendStatus.hurt(n, dmg, n.global_position + Vector3.UP, w, by, -1.0, info)
	BendStatus.knock(n, w * 6.0 + Vector3.UP * 1.0, by, info)


func _run() -> void:
	for i in 10:
		await process_frame
	lvl = current_scene as RingLevel
	_expect(lvl != null, "the scene is the ring")
	if lvl == null:
		return _end()
	ring = lvl.ring
	player = lvl.player
	mode = RingMode.find(self)
	_expect(mode != null and mode.rules != null and mode.rules.rule_set == "stock" and RingRules.stock_on(),
			"a stock-rules match: RingRules installed with rule_set stock, the gate on")
	if mode == null or not RingRules.stock_on():
		return _end()
	rules = mode.rules
	await _go_fight()
	_static_checks()
	await _ledger_checks()
	await _volley_checks()
	await _weight_checks()
	await _stale_checks()
	await _guard_checks()
	await _patch_checks()
	_end()


# ---------------------------------------------------------------- the formula (static)
func _static_checks() -> void:
	# 10 classes at 0/60/120%: the formula, and the spec table's v (rounded to 0.1)
	var table := {"stone_form/spike": [7.8, 16.6, 25.4], "water_whip/whip": [5.8, 12.7, 19.7], "fire_blast/punch": [5.2, 11.7, 18.2],
			"air_blast/slice": [4.1, 11.1, 18.0], "stone_form/cannonball": [12.3, 23.9, 35.5], "ice/spear": [7.7, 17.3, 26.8],
			"fire_blast/punch.grown": [8.9, 19.3, 29.8], "fire_arc/lightning": [12.2, 24.9, 37.6], "air_blast/ball": [9.1, 18.6, 28.2],
			"earth_shove/push": [8.6, 16.9, 25.2]}
	var ok_f := true
	var ok_t := true
	var worst := 0.0
	for tag: String in table:
		var c := RingRules.class_of(tag)
		var d := float(c.d)
		for i in 3:
			var p := [0.0, 60.0, 120.0][i] as float
			var want := float(c.base) + float(c.growth) * (p + d) / 100.0 * (0.5 + d / 20.0)
			var got := RingRules.launch_v(c, p + d, d, 1.0)
			ok_f = ok_f and absf(got - want) <= 0.01
			worst = maxf(worst, absf(got - float(table[tag][i])))
			ok_t = ok_t and absf(got - float(table[tag][i])) <= 0.06
	_expect(ok_f, "launch_v is W (base + growth R A p/100 (0.5 + d/20)) for 10 classes at 0/60/120% (within 0.01 m/s)")
	_expect(ok_t, "the 10 classes match the spec table's v at 0/60/120%% (worst %.3f m/s)" % worst)
	_metric("launch_formula_ok", ok_f and ok_t)
	var rm := [RingRules.range_mult("stone_form/spike", 10.0), RingRules.range_mult("stone_form/spike", 16.0),
			RingRules.range_mult("stone_form/spike", 22.0), RingRules.range_mult("stone_form/spike", 30.0)]
	var ok_r := absf(rm[0] - 1.0) < 1e-4 and absf(rm[1] - 0.825) < 1e-4 and absf(rm[2] - 0.65) < 1e-4 and absf(rm[3] - 0.65) < 1e-4
	_expect(ok_r, "the range falloff at 10/16/22/30 m: 1.0/0.825/0.65/0.65 (%s)" % str(rm))
	var ex := RingRules.range_mult("fire_arc/lightning", 30.0) == 1.0 and RingRules.range_mult("stone_form/spike.return", 30.0) == 1.0
	_expect(ex, "Lightning and returns have no range falloff")
	_metric("range_falloff_ok", ok_r and ex)
	var sp := RingRules.class_of("stone_form/spike")
	var g_air := RingRules.launch_v(sp, 100.0, 14.0, 1.0, 0.0, true) - float(sp.base)
	var g_deck := RingRules.launch_v(sp, 100.0, 14.0, 1.0, 0.0, false) - float(sp.base)
	_expect(absf(g_air / g_deck - 0.85) < 1e-3, "the air factor: a launch class released airborne grows x0.85")
	var sl := RingRules.class_of("earth_shove/slam")
	var rt := RingRules.return_class("stone_form/spike")
	_expect(RingRules.launch_v(sl, 100.0, 12.0, 1.0, 0.0, true) == RingRules.launch_v(sl, 100.0, 12.0, 1.0, 0.0, false)
			and RingRules.launch_v(rt, 100.0, 16.8, 1.0, 0.0, true) == RingRules.launch_v(rt, 100.0, 16.8, 1.0, 0.0, false),
			"the Slam and returns are exempt from the air factor")
	var cv := [RingRules.curve_d(7.0), RingRules.curve_d(20.0), RingRules.curve_d(55.0), RingRules.curve_d(110.0)]
	var want_c := [2.4, 5.6, 10.2, 12.4]
	var ok_c := true
	for i in 4:
		ok_c = ok_c and absf(float(cv[i]) - float(want_c[i])) < 0.11       # (the spec's figures rounded)
	_expect(ok_c, "untagged damage 7/20/55/110 converts to 2.4/5.6/10.2/12.4%% (%s)" % str(cv))
	_expect(absf(RingRules.weight_of("earth") - 0.889) < 0.002 and absf(RingRules.weight_of("air") - 1.111) < 0.002
			and RingRules.weight_of("water") == 1.0 and absf(RingRules.weight_of("fire") - 1.026) < 0.002,
			"weights: earth x0.89, water x1.0, fire x1.03, air x1.11")
	var set_c := RingRules.class_of("air_palm/palm")
	_expect(RingRules.launch_v(set_c, 250.0, 3.0, 1.0) == 4.5, "a set class launches at its set speed at any % (Palm 4.5 m/s)")


# ---------------------------------------------------------------- the ledger
func _ledger_checks() -> void:
	await _fresh()
	var f := foe()
	var h0 := f.health
	var k0 := BendKnock.of(f).knocks
	_hit(f, player, "stone_form/spike")
	_expect(absf(rules.pct_of(f) - 14.0) < 0.01 and f.health == h0, "a Spike adds 14%% and never touches health (%.2f%%, health %.0f)" % [rules.pct_of(f), f.health])
	_expect(BendKnock.of(f).knocks == k0 + 1, "the hurt and its knock this frame are one hit (one knock)")
	await _ticks(2)
	# the untagged curve through a real blow
	await _fresh()
	BendStatus.hurt(f, 20.0, f.global_position, Vector3.FORWARD, player)
	_expect(absf(rules.pct_of(f) - RingRules.curve_d(20.0)) < 0.01 and f.health == f.health_max,
			"an untagged blow of 20 adds %.1f%% and leaves health whole" % RingRules.curve_d(20.0))
	# Hit.deliver's damage reaches health: taken back as % the same frame by the rules
	await _fresh()
	f.health = f.health_max - 55.0
	await _ticks(2)
	_expect(absf(rules.pct_of(f) - RingRules.curve_d(55.0)) < 0.05 and f.health == f.health_max,
			"damage that reached health (55) turns into %.1f%% and health is whole again" % RingRules.curve_d(55.0))
	# pct_scale scales every d
	await _fresh()
	var stk := RingRules.data()["stock"] as Dictionary
	stk["pct_scale"] = 2.0
	_hit(f, player, "stone_form/spike")
	stk["pct_scale"] = 1.0
	_expect(absf(rules.pct_of(f) - 28.0) < 0.01, "pct_scale 2 doubles a Spike's d (%.2f%%)" % rules.pct_of(f))
	await _ticks(2)


func _volley_checks() -> void:
	await _fresh()
	var f := foe()
	var k0 := BendKnock.of(f).knocks
	for i in 7:
		_hit(f, player, "fire_jab/embers", {"volley_id": 901, "volley_n": 7}, 2.0)
		await _ticks(1)
	var one_knock := BendKnock.of(f).knocks == k0 + 1
	var ok := absf(rules.pct_of(f) - 4.0) < 0.01 and one_knock and rules.string_hits(f) == 1 \
			and rules.stale_count(player, "fire_jab/embers") == 1
	_expect(ok, "7 Embers of one volley: 4%% in all (%.2f), one knock (%s), one string hit (%d), one stale entry (%d)"
			% [rules.pct_of(f), one_knock, rules.string_hits(f), rules.stale_count(player, "fire_jab/embers")])
	await _secs(0.5)
	await _fresh()
	for i in 3:
		_hit(f, player, "fire_jab/embers", {"volley_id": 902, "volley_n": 7}, 2.0)
		await _ticks(1)
	var ok2 := absf(rules.pct_of(f) - 4.0 * 3.0 / 7.0) < 0.01
	_expect(ok2, "3 of a volley of 7 landing give 4 x 3/7 = %.2f%% (%.2f)" % [4.0 * 3.0 / 7.0, rules.pct_of(f)])
	_metric("volley_once_ok", ok and ok2)


func _launch_speed(n: Node3D, by: Node3D, tag: String, extra := {}) -> float:
	var got := [0.0]
	var cb := func(b: Node3D, v: Vector3, _hs: float, _by: Node, _t: String) -> void:
		if b == n:
			got[0] = v.length()
	rules.launched.connect(cb)
	_hit(n, by, tag, extra)
	rules.launched.disconnect(cb)
	return float(got[0])


func _weight_checks() -> void:
	var f := foe()
	# the water foe: W 1.0 at 50%; the same hit on earth's numbers: x0.89 (a class's weight from the victim's element)
	await _fresh()
	rules.add_pct(f, 50.0, null, "")
	var v_w := _launch_speed(f, player, "stone_form/spike")
	var c := RingRules.class_of("stone_form/spike")
	var want := RingRules.launch_v(c, 64.0, 14.0, 1.0)
	_expect(absf(v_w - want) < 0.05, "a Spike at 50%% on the water foe launches at %.2f m/s (W 1.0; want %.2f)" % [v_w, want])
	# Carried wind: the attacker's charged wind x1.15 on the whole launch
	await _fresh()
	rules.add_pct(f, 50.0, null, "")
	player.set_meta(&"bend_carry_until", BendStatus.now() + 5.0)
	var v_c := _launch_speed(f, player, "stone_form/spike")
	player.remove_meta(&"bend_carry_until")
	_expect(absf(v_c - want * 1.15) < 0.05, "Carried wind: x1.15 on the whole launch (%.2f vs %.2f)" % [v_c, want * 1.15])
	# Rooted (an earth body standing still) on the base only: the player is earth; hit him standing still
	await _fresh()
	await _ticks(10)
	rules.add_pct(player, 50.0, null, "")
	var rooted := BendStatus.rooted_mult(player) < 1.0
	var v_r := _launch_speed(player, f, "stone_form/spike")
	var c2 := c.duplicate()
	c2["base_mult"] = 0.85
	var want_r := RingRules.launch_v(c2, 64.0, 14.0, RingRules.weight_of("earth"))
	_expect(rooted and absf(v_r - want_r) < 0.05,
			"Rooted on the base only and the earth weight: %.2f m/s (want %.2f = 0.89 (5.8 x 0.85 + growth...))" % [v_r, want_r])
	await _ticks(2)


func _stale_checks() -> void:
	var f := foe()
	await _fresh()
	var ds: Array = []
	for i in 7:
		var p0 := rules.pct_of(f)
		_hit(f, player, "stone_form/spike")
		ds.append(rules.pct_of(f) - p0)
		await _ticks(1)
	var want := [14.0, 14.0 * 0.92, 14.0 * 0.84, 14.0 * 0.76, 14.0 * 0.68, 14.0 * 0.6, 14.0 * 0.6]
	var ok := true
	for i in 7:
		ok = ok and absf(float(ds[i]) - float(want[i])) < 0.02
	_expect(ok, "stale: -8%% a copy, floor -40%% (%s)" % str(ds))
	# returns never staled, never queued
	var q0 := rules.stale_count(player, "stone_form/spike.return")
	var p1 := rules.pct_of(f)
	_hit(f, player, "stone_form/spike", {"returned": true, "origin_tag": "stone_form/spike"})
	var d_ret := rules.pct_of(f) - p1
	await _ticks(1)
	var p2 := rules.pct_of(f)
	_hit(f, player, "stone_form/spike", {"returned": true, "origin_tag": "stone_form/spike"})
	var ok_r := absf(d_ret - 16.8) < 0.02 and absf(rules.pct_of(f) - p2 - 16.8) < 0.02 and rules.stale_count(player, "stone_form/spike.return") == q0
	_expect(ok_r, "a return: x1.2 (16.8%%), never staled, never queued (%.2f, %.2f)" % [d_ret, rules.pct_of(f) - p2])
	# the Pop's stone: the Spike's class, its own tag, staled
	await _fresh()
	var pd: Array = []
	for i in 2:
		var p0 := rules.pct_of(f)
		_hit(f, player, "rock_jab/pop_stone")
		pd.append(rules.pct_of(f) - p0)
		await _ticks(1)
	var ok_p := absf(float(pd[0]) - 14.0) < 0.02 and absf(float(pd[1]) - 14.0 * 0.92) < 0.02
	_expect(ok_p, "the Pop's stone: the Spike's class (14%%), staled like any move (%s)" % str(pd))
	# the queue survives a fall (stale_count unchanged by a KO), clears at the game's start
	var before := rules.stale_count(player, "rock_jab/pop_stone")
	var t := rules.team_of(f)
	rules._ko(f)
	await _ticks(2)
	var kept := rules.stale_count(player, "rock_jab/pop_stone") == before and before == 2
	_expect(kept, "the stale queue survives a fall (%d copies kept)" % rules.stale_count(player, "rock_jab/pop_stone"))
	# (the foe back in play for what follows)
	mode._respawns.clear()
	mode._hide(f, false)
	rules.respawn(f, false)
	(rules._sk(f) as Dictionary)["safe_until"] = -INF
	_expect(t == 1, "the foe is team 1")
	rules.reset_game()
	_expect(rules.stale_count(player, "rock_jab/pop_stone") == 0, "the stale queue clears at the game's start")
	_metric("stale_ok", ok and ok_r and ok_p and kept)
	await _ticks(2)


func _guard_checks() -> void:
	var f := foe()
	var strikes := {"earth": "stone_form/spike", "water": "water_whip/whip", "fire": "fire_blast/punch", "air": "air_blast/slice"}
	var all_ok := true
	var pairs := 0
	for g_el: String in Bending.ELEMENTS:
		for a_el: String in Bending.ELEMENTS:
			var tag := String(strikes[a_el])
			var on_beat := RingRules.guard_outcome(g_el, tag, 0.2)
			var held := RingRules.guard_outcome(g_el, tag, 0.6 if not (g_el == "earth" and a_el == "earth") else 1.2)
			# perfect: 0%, no launch
			await _fresh()
			var k0 := BendKnock.of(f).knocks
			_hit(f, player, tag, {"guard": "perfect" if on_beat != "late" else "late"})
			var perfect_ok := on_beat in ["perfect", "catch"] and rules.pct_of(f) == 0.0 and BendKnock.of(f).knocks == k0
			# late: half the d, half the launch, a slide on the feet (no tumble)
			await _fresh()
			rules.add_pct(f, 60.0, null, "")
			var full := RingRules.launch_v(RingRules.class_of(tag), 60.0 + float(RingRules.class_of(tag).d), float(RingRules.class_of(tag).d), 1.0)
			var v := _launch_speed(f, player, tag, {"slide_only": true})
			var kn := BendKnock.of(f)
			var late_ok := held == "late" and absf(rules.pct_of(f) - 60.0 - float(RingRules.class_of(tag).d) * 0.5) < 0.02 \
					and v < full * 0.5 + 0.3 and not kn.tumble
			pairs += 1
			if not (perfect_ok and late_ok):
				all_ok = false
				print("    pair guard %s / attack %s: perfect %s (%s), late %s (%s, v %.2f of %.2f)" % [g_el, a_el, perfect_ok, on_beat,
						late_ok, held, v, full])
			await _ticks(1)
	_expect(all_ok and pairs == 16, "every guard stops every attack (16 element pairs): on the beat 0%% and no launch, late half %% and half launch as a slide")
	var light := true
	for g_el: String in Bending.ELEMENTS:
		var o := RingRules.guard_outcome(g_el, "fire_arc/lightning", 0.1)
		light = light and (o == "perfect") == (g_el == "fire")
	_expect(light, "Lightning: only fire's guard can be perfect; every other guard takes it late")
	var catch_ok := RingRules.guard_outcome("earth", "stone_form/cannonball", 0.9) == "catch" \
			and RingRules.guard_outcome("earth", "stone_form/cannonball", 1.2) == "late"
	_expect(catch_ok, "earth's catch: full within 1.0 s of standing, late after")
	# a return owned by the returner: x1.2 on d and growth; the rally capped at x1.6
	var r12 := RingRules.return_class("stone_form/spike")
	var r20 := RingRules.return_class("stone_form/spike", 2.0)
	var big := RingRules.return_class("stone_form/cannonball")
	var ret_ok := absf(float(r12.d) - 16.8) < 1e-3 and absf(float(r12.growth) - 14.64) < 1e-3 and absf(float(r20.d) - 22.4) < 1e-3 \
			and absf(float(big.d) - 26.4) < 1e-3 and absf(RingRules.rally_mult(9, 0) - 1.6) < 1e-4 and absf(RingRules.rally_mult(1, 1) - 1.4) < 1e-4
	_expect(ret_ok, "a return: the Spike's class (or the caught move's if higher) x1.2 on d and growth; the rally capped at x1.6")
	await _fresh()
	_hit(f, player, "stone_form/spike", {"returned": true, "origin_tag": "stone_form/spike"})
	var by_ok := BendKnock.of(f).last_knocker == player
	_expect(by_ok, "a return is owned by the returner (the credit is his)")
	_metric("shield_all_ok", all_ok and light and catch_ok and ret_ok and by_ok)
	await _ticks(2)


func _patch_checks() -> void:
	var f := foe()
	await _fresh()
	_expect(rules.patch(player) == 0.0 and not rules.heal_allowed(player), "Patch is refused with an empty fresh pool")
	_hit(player, f, "stone_form/spike")
	await _secs(1.0)
	await _until(func() -> bool: return player.is_on_floor(), 2.0)
	await _secs(5.4)
	_hit(player, f, "air_blast/slice")
	await _until(func() -> bool: return player.is_on_floor() and not rules.stunned(player), 3.0)
	var fresh := rules.fresh_pct(player)
	var p0 := rules.pct_of(player)
	var took := rules.patch(player)
	var ok1 := absf(fresh - 6.0) < 0.05 and absf(took - 6.0) < 0.05 and absf(rules.pct_of(player) - (p0 - 6.0)) < 0.05
	_expect(ok1, "Patch takes only the last 6 s of %% (the Spike 6.4+ s ago stays: pool %.2f, took %.2f)" % [fresh, took])
	await _fresh()
	_hit(player, f, "stone_form/cannonball")
	await _until(func() -> bool: return player.is_on_floor() and not rules.stunned(player), 3.0)
	await _secs(0.3)
	var took2 := rules.patch(player)
	_expect(absf(took2 - 10.0) < 0.05 and absf(rules.pct_of(player) - 12.0) < 0.05, "Patch takes at most 10%% (took %.2f of 22)" % took2)
	# refused while a foe is out (respawning), in sudden death, in the air
	await _fresh()
	_hit(player, f, "stone_form/spike")
	await _until(func() -> bool: return player.is_on_floor() and not rules.stunned(player), 3.0)
	(rules._sk(f) as Dictionary)["away"] = true
	var out_refused := not rules.heal_allowed(player) and rules.patch(player) == 0.0
	(rules._sk(f) as Dictionary)["away"] = false
	rules.sudden = true
	var sudden_refused := not rules.heal_allowed(player)
	rules.sudden = false
	player.velocity.y = 6.0
	await _ticks(4)
	var air_refused := not player.is_on_floor() and not rules.heal_allowed(player)
	await _until(func() -> bool: return player.is_on_floor(), 2.0)
	await _ticks(2)                               # (the merge: MOVE's RingMoves takes the landing on its next frame)
	var allowed_back := rules.heal_allowed(player)
	_expect(out_refused and sudden_refused and air_refused and allowed_back,
			"Patch refused while a foe is out (%s), in sudden death (%s), in the air (%s); allowed again on the deck (%s)"
			% [out_refused, sudden_refused, air_refused, allowed_back])
	_metric("patch_fresh_ok", ok1 and absf(took2 - 10.0) < 0.05 and out_refused and sudden_refused and air_refused)
