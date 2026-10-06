extends SceneTree
## Round 3's stage overlay (smash_r3 spec v2 §5.1-5.2, §15 PERCENT; RingArena, RingWater, data/ring/ring.json modes.stock), the
## ring scene with a stock-rules match (RingRules.rule_set_override "stock"; earth against a water bot, held), then the
## classic ring for the ropes:
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_ring_stage.gd -- mode=ring element=earth foe=water
##   the water   at -6 (floor -9, the tank 10 m round the deck); feet in it anywhere off the deck: out; nothing out hanging at
##               lip -0.6; a body thrown over the curtain at +6 m is out the frame it crosses (and the curtain splashes)
##   the lip     nearest_lip on all four sides and outside two corners; the coping's collider is flush (a ray down at the
##               lip meets the deck top; a slide over the lip keeps its height and speed)
##   ropes       none in the stock ring (no rope rails), present in the classic ring
##   walls       wall_place_ok clamps a wall 3.5 m inside every lip; the classic ring leaves it as given
##   lanterns    eight lantern spots just outside the lip (corners and mid-sides), none in classic
##   the KO      (in-engine, recovery off until MOVE merges) a water body at the deck's middle, no inputs, launched toward an end
##               by a Boulder, a Spike, a Punch and a Gust grown cast from 8 m: the lowest % that puts it in the water,
##               against the same flight worked out here (gravity 20, decel 8, vy cap 16, the lip 17 m out) within +-10%;
##               METRIC ko_calibration prints the engine %, the no-recovery prediction and the spec table's (with recovery)
## Watchdog LIMIT_S; last line "RING STAGE PASSED" or "RING STAGE FAILED" (exit 0 only on a pass).

const NAME := "RING STAGE"
const LIMIT_S := 400.0
const OWN_CFG := "user://ring_stage_test.cfg"
## The spec table's KO % from the deck's middle toward an end (with recovery) for the classes the engine checks.
const LEAD := {"stone_form/cannonball": 115.0, "stone_form/spike": 159.0, "fire_blast/punch": 231.0, "air_gust/gust.grown": 125.0}

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var ring: RingArena
var player: FrontierPlayer
var mode: RingMode
var rules: RingRules
var metrics := {}
var kos: Array = []


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	MatchSetup._aim_help = "strong"
	GameSettings.path = OWN_CFG
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
	for k: String in ["respawn_ok", "classic_pinned_ok"]:
		if metrics.has(k):
			print("METRIC %s=%s" % [k, str(bool(metrics[k])).to_lower()])
	RingRules.rule_set_override = ""
	RingArena.set_mode("classic")
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


func _scene() -> bool:
	for i in 10:
		await process_frame
	lvl = current_scene as RingLevel
	if lvl == null:
		return false
	ring = lvl.ring
	player = lvl.player
	mode = RingMode.find(self)
	if mode == null:
		return false
	rules = mode.rules
	await _go_fight()
	return true


## The foe back mid-deck (s from end 1's centre), in play, still, % set.
func _reset_foe(x := 0.0, pct := 0.0) -> void:
	var f := foe()
	mode._respawns.clear()
	mode._hide(f, false)
	var st := rules._sk(f)
	st["away"] = false
	st["gone"] = false
	st["stocks"] = 3
	st["safe_until"] = -INF
	var kn := BendKnock.peek(f)
	if kn != null:
		kn.reset()
	f.velocity = Vector3.ZERO
	f.global_position = ring.to_global(Vector3(x, ring.top() + 0.05, 0.0))
	rules._stale.clear()                      # (the same move again and again: no staling between trials)
	await _ticks(3)
	rules.reset_pct(f, pct)


func _run() -> void:
	var ok := await _scene()
	_expect(ok and RingRules.stock_on() and RingArena.stock(), "the stock ring: its rules and its stage overlay on")
	if not ok:
		return _end()
	rules.ko.connect(func(b: Node3D, _by: Node, _p: float, _t: String, _l: int) -> void: kos.append([b, BendStatus.now()]))
	await _water_checks()
	await _lip_checks()
	_wall_checks()
	await _ko_calibration()
	await _classic_checks()
	_end()


func _water_checks() -> void:
	var f := foe()
	_expect(RingArena.num("water_y", 0.0) == -6.0 and RingArena.num("floor_y", 0.0) == -9.0 and ring.water.level_y == -6.0
			and ring.tank_half() == Vector2(27.0, 17.0), "the water at -6 (floor -9), the tank 10 m round the deck (27 x 17 half)")
	var hl := ring.half_l()
	_expect(ring.is_out(ring.to_global(Vector3(hl + 3.0, -6.05, 0.0))) and ring.is_out(ring.to_global(Vector3(0.0, -6.05, ring.half_w() + 4.0))),
			"feet in the water anywhere off the deck: out")
	_expect(not ring.is_out(ring.to_global(Vector3(hl + 0.3, -0.6, 0.0))) and not ring.is_out(ring.to_global(Vector3(hl + 0.3, -2.0, 2.0))),
			"nothing out hanging at lip -0.6 (or at the hang's -2.0)")
	# thrown over the curtain at +6 m: out the frame it crosses (its place at each frame's start recorded: the frame of the
	# fall began this side of the plane, and the fall's own place is past it)
	await _reset_foe(4.0)
	kos.clear()
	var falls0 := rules.falls.size()
	f.global_position = ring.to_global(Vector3(26.0, 6.0, 0.0))
	var kn := BendKnock.of(f)
	var splashes0 := ring.water.curtain_splashes
	kn.knock(Vector3.ZERO, player, {"_launch": {"v": ring.global_basis * Vector3(14.0, 4.0, 0.0), "hitstun_s": 0.6, "tumble": true}})
	var xs: Array = []
	for i in 40:
		await physics_frame
		if kos.is_empty():
			xs.append(ring.to_local(f.global_position).x)
		else:
			break
	var t := ring.tank_half().x
	var fall_x := ring.to_local(rules.falls[falls0].pos as Vector3).x if rules.falls.size() > falls0 else 0.0
	var before := float(xs.back()) if not xs.is_empty() else INF
	var same := not kos.is_empty() and before <= t and fall_x > t and fall_x - before < 14.0 / 60.0 + 0.05
	_expect(same, "a body thrown over the curtain at +6 m is out the frame its centre crosses the curtain's plane (x %.3f at the frame's start, %.3f at the fall; the plane %.1f)"
			% [before, fall_x, t])
	_expect(ring.water.curtain_splashes > splashes0, "the curtain splashes where he went through")


func _lip_checks() -> void:
	var hl := ring.half_l()
	var hw := ring.half_w()
	var cases := [[Vector3(-hl + 1.0, 0.0, 0.5), RingArena.LIP_END_0, Vector3(-1, 0, 0)], [Vector3(hl - 1.0, 0.0, -0.5), RingArena.LIP_END_1, Vector3(1, 0, 0)],
			[Vector3(2.0, 0.0, -hw + 0.8), RingArena.LIP_LONG_NEG, Vector3(0, 0, -1)], [Vector3(-3.0, 0.0, hw - 0.6), RingArena.LIP_LONG_POS, Vector3(0, 0, 1)],
			[Vector3(hl + 2.0, -1.0, hw + 1.0), RingArena.LIP_END_1, Vector3(1, 0, 0)], [Vector3(-hl - 1.0, -2.0, -hw - 3.0), RingArena.LIP_LONG_NEG, Vector3(0, 0, -1)]]
	var ok := true
	for c: Array in cases:
		var lip := ring.nearest_lip(ring.to_global(c[0] as Vector3))
		var good := int(lip.side) == int(c[1]) and (lip.normal as Vector3).is_equal_approx(ring.global_basis * (c[2] as Vector3)) \
				and absf((lip.point as Vector3).y - ring.lip_y()) < 1e-4
		if not good:
			print("    lip case %s -> %s" % [str(c[0]), str(lip)])
		ok = ok and good
	_expect(ok, "nearest_lip on all four sides and outside two corners: the side, its outward normal, the point at the lip's height")
	# the coping's collider is flush: a ray down at the lip meets the deck top
	var space := ring.get_world_3d().direct_space_state
	var flush := true
	for p: Vector3 in [Vector3(hl - 0.1, 2.0, 1.0), Vector3(-hl + 0.12, 2.0, -2.0), Vector3(3.0, 2.0, hw - 0.1)]:
		var q := PhysicsRayQueryParameters3D.create(ring.to_global(p), ring.to_global(Vector3(p.x, -2.0, p.z)), 1)
		var hit := space.intersect_ray(q)
		flush = flush and not hit.is_empty() and absf(ring.to_local(hit.position).y - ring.top()) < 1e-3
	_expect(flush, "the coping's collider is flush: a ray down 0.1 m inside each lip meets the deck top (no 4 cm step)")
	# a slide over the lip: speed and height kept to the lip
	var f := foe()
	await _reset_foe(-12.0)
	f.global_position = ring.to_global(Vector3(-hl + 3.0, ring.top() + 0.05, 1.0))
	await _ticks(3)
	BendKnock.of(f).knock(Vector3.ZERO, player, {"_launch": {"v": ring.global_basis * Vector3(-7.0, 0.0, 0.0), "hitstun_s": 0.3, "tumble": false}})
	var y_max := -INF
	var worst_drop := 0.0
	var last := BendKnock.of(f).kv.length()
	var dt := 1.0 / Engine.physics_ticks_per_second
	for i in 160:
		await physics_frame
		var l := ring.to_local(f.global_position)
		var k := BendKnock.of(f).kv.length()
		if f.is_on_floor() and l.x > -hl + 0.02 and k > 0.05:
			y_max = maxf(y_max, l.y)
			worst_drop = maxf(worst_drop, last - k)
		last = k
		if l.x < -hl - 0.5:
			break
	_expect(y_max < ring.top() + 0.02 and worst_drop <= 8.0 * dt + 1e-3,
			"a slide over the lip keeps its height (%.3f m over the deck at most: no 4 cm step) and its carry decays no faster than the ring's own rates there (the most in a frame %.3f m/s, 8 m/s2 is %.3f): nothing trips it"
			% [y_max - ring.top(), worst_drop, 8.0 * dt])
	_expect(ring.lantern_spots().size() == 8, "eight lantern spots just outside the lip (the corners and the middle of each side)")
	var ropes := ring.get_node_or_null(^"Ropes")
	_expect(ropes == null or ropes.get_child_count() == 0, "no ropes in the stock ring: all four sides open")
	await _reset_foe(4.0)


func _wall_checks() -> void:
	var hl := ring.half_l()
	var hw := ring.half_w()
	var a := ring.to_local(ring.wall_place_ok(ring.to_global(Vector3(hl - 0.5, 0.0, hw - 0.2))))
	var b := ring.to_local(ring.wall_place_ok(ring.to_global(Vector3(-hl + 1.0, 0.0, -1.0))))
	var c := ring.to_local(ring.wall_place_ok(ring.to_global(Vector3(0.0, 0.0, 0.0))))
	var ok := absf(a.x - (hl - 3.5)) < 1e-3 and absf(a.z - (hw - 3.5)) < 1e-3 and absf(b.x + (hl - 3.5)) < 1e-3 and absf(b.z + 1.0) < 1e-3 \
			and c.is_equal_approx(Vector3.ZERO)
	_expect(ok, "walls clamp 3.5 m inside every lip (%s, %s); mid-deck as given" % [str(a), str(b)])


## The flight worked out (no recovery): out when it is past the lip (17 m on) when it falls back to the deck's height, or
## past the curtain.
static func predict_out(v: float, ang_deg: float, from_lip_m: float) -> bool:
	var g := RingRules.stock_num("gravity", 20.0)
	var dec := RingRules.stock_num("decel_air", 8.0)
	var a := deg_to_rad(ang_deg)
	var kv := v * cos(a)
	var vy := minf(v * sin(a), RingRules.stock_num("vy_cap", 16.0))
	var t_land := 2.0 * vy / g
	var t_stop := kv / dec
	var t := minf(t_land, t_stop)
	var x := kv * t - 0.5 * dec * t * t
	return x > from_lip_m


## The lowest % at which `tag` from 8 m puts the water foe at the deck's middle in the water: [engine (by trials), worked out].
func _ko_pct(tag: String) -> Array:
	var c := RingRules.class_of(tag)
	var lo := 0.0
	var hi := 300.0
	var pl := 0.0
	var ph := 300.0
	for i in 18:
		var mid := (pl + ph) * 0.5
		var p_after := mid + float(c.d)
		if predict_out(RingRules.launch_v(c, p_after, float(c.d), 1.0, 8.0), float(c.angle), ring.half_l()):
			ph = mid
		else:
			pl = mid
	for i in 7:
		var mid := (lo + hi) * 0.5
		if await _trial(tag, mid):
			hi = mid
		else:
			lo = mid
	return [hi, ph]


func _trial(tag: String, pct: float) -> bool:
	var f := foe()
	await _reset_foe(0.0, pct)
	kos.clear()
	var from := ring.to_global(Vector3(-8.0, ring.top() + 1.0, 0.0))
	var way := ring.global_basis * Vector3(1.0, 0.0, 0.0)
	var info := {"tag": tag, "from": from}
	BendStatus.hurt(f, 10.0, f.global_position + Vector3.UP, way, player, -1.0, info)
	BendStatus.knock(f, way * 6.0, player, info)
	await _until(func() -> bool: return not kos.is_empty() or (f.is_on_floor() and not BendKnock.of(f).is_launched()
			and BendKnock.of(f).kv.length() < 0.05), 6.0)
	return not kos.is_empty()


func _ko_calibration() -> void:
	player.global_position = ring.to_global(Vector3(-8.0, ring.top() + 0.05, 5.0))
	var all_ok := true
	var parts := PackedStringArray()
	for tag: String in LEAD:
		var r := await _ko_pct(tag)
		var eng := float(r[0])
		var pred := float(r[1])
		var ok := absf(eng - pred) <= maxf(pred * 0.1, 2.5)
		all_ok = all_ok and ok
		parts.append("%s engine %d%% / no-recovery %d%% / table (recovery) %d%%" % [tag, roundi(eng), roundi(pred), roundi(float(LEAD[tag]))])
		print("METRIC ko_calibration %s engine=%.1f predicted_no_recovery=%.1f lead_table_with_recovery=%.0f" % [tag, eng, pred, float(LEAD[tag])])
	_expect(all_ok, "the in-engine KO % (recovery off: MOVE's) matches the same flight worked out within 10%%: %s" % "; ".join(parts))
	await _reset_foe(4.0)


func _classic_checks() -> void:
	RingRules.rule_set_override = "classic"
	change_scene_to_file("res://scenes/ring.tscn")
	await process_frame
	var ok := await _scene()
	_expect(ok and not RingRules.stock_on() and not RingArena.stock() and rules.rule_set == "classic",
			"the classic ring: its rules classic, the gate off, no overlay")
	if not ok:
		return
	var rails := 0
	var ropes := ring.get_node_or_null(^"Ropes")
	if ropes != null:
		for n in ropes.get_children():
			if n is StaticBody3D and n.has_meta(&"ring_rope"):
				rails += 1
	_expect(rails == 2 and RingArena.num("water_y", 0.0) == -1.4 and ring.tank_half() == Vector2(23.0, 13.0),
			"the classic ring keeps today's stage: the ropes (%d rails), the water at -1.4, the 6 m tank" % rails)
	var p := ring.to_global(Vector3(ring.half_l() - 0.5, 0.0, 1.0))
	_expect(ring.wall_place_ok(p).is_equal_approx(p) and ring.lantern_spots().is_empty(), "the classic ring: walls as given, no lanterns")
