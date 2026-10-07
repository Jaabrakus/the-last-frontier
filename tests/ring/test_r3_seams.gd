extends SceneTree
## Round 3's SEAMS (smash_r3 spec §14.3, §19): the API stubs every round-3 task builds against, and the gate off everywhere
## today. Headless:
##   symbols    every §14.3 symbol SEAMS stubbed exists with its argument count (RingRules, BendKnock, BendStatus, RingArena,
##              RingMoves, RingPredict, NpcPad, SwayCaster, MatchSetup, RingPractice): methods (static where the spec says),
##              static vars, vars and signals; the stubs answer today's behaviour (nothing, no %, casting allowed)
##   the gate   stock_on() false with no ring, in the open world and in the classic ring (pinned: RingRules.rule_set_override
##              "classic", since the merge rules.json plays "stock" by default); RingMoves.of(player) null in the open world
##              (scenes/main.tscn) and in the classic ring; BendStatus.take_filters empty
##   launch_v   the spec §2.2 formula for one class at range 0, 16 and 30 m and released in the air; a set class its base;
##              range_mult 1.0 to 10 m, 0.65 at 22 m and beyond
##   the lip    RingArena.nearest_lip right on each of the four sides, at two corners outside the deck and one inside;
##              spout_at on the s 12 m line at grate z; lip_y the deck top; wall_place_ok as given
##   the cast   one right-click cast in the ring (scenes/ring.tscn, earth, the foe held): SwayCaster.lock_started and
##              cast_released each fire once; guard_up() false, then true once E's guard stands
## Last line "R3 SEAMS PASSED" or "R3 SEAMS FAILED"; exit 0 only on a pass; a watchdog quits with 2.
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_r3_seams.gd

const NAME := "R3 SEAMS"
const WATCHDOG_S := 300.0
const OWN_CFG := "user://r3_seams_test.cfg"

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var c: SwayCaster
var rm: RingMode
var foe: NpcFighter
var _foe_at := Vector3.INF


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	MatchSetup._aim_help = "strong"             # (the test's player does not aim his camera at a target: the full help)
	seed(1750)
	create_timer(WATCHDOG_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	SwayCaster.free_override = true
	InputSetup.ensure()
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


func _run() -> void:
	_symbols()
	_stubs()
	_launch()
	_expect(not RingRules.stock_on() and RingRules.current() == null and BendStatus.take_filters.is_empty(),
			"no ring: the gate off (stock_on false, no RingRules installed, no take filters)")
	await _open_world()
	await _ring()
	_end()


func _end() -> void:
	if c != null:
		c.held_override = null
		c.guard_override = null
		c.quick_override = null
	SwayCaster.free_override = false
	RingRules.rule_set_override = ""
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


# ---------------------------------------------------------------- the symbols (spec §14.3)
## Script `s`'s method `m`: {args (count), static} ({} none).
func _method(s: Script, m: String) -> Dictionary:
	for d: Dictionary in s.get_script_method_list():
		if String(d.name) == m:
			return {"args": (d.args as Array).size(), "static": (int(d.flags) & METHOD_FLAG_STATIC) != 0}
	return {}


## Script `s`'s signal `sig`'s argument count (-1 none).
func _signal(s: Script, sig: String) -> int:
	for d: Dictionary in s.get_script_signal_list():
		if String(d.name) == sig:
			return (d.args as Array).size()
	return -1


## Each of `want` ({name: [args, static]}) a method of `s` with that count and kind.
func _methods(s: Script, label: String, want: Dictionary) -> void:
	var bad: Array = []
	for m: String in want:
		var got := _method(s, m)
		var w: Array = want[m]
		if got.is_empty() or int(got.args) != int(w[0]) or bool(got.static) != bool(w[1]):
			bad.append("%s %s (want %d%s)" % [m, str(got) if not got.is_empty() else "missing", int(w[0]), " static" if w[1] else ""])
	_expect(bad.is_empty(), "%s: %d methods with their argument counts%s" % [label, want.size(), "" if bad.is_empty() else " " + str(bad)])


## Each of `want` ({name: args}) a signal of `s` with that many arguments.
func _signals(s: Script, label: String, want: Dictionary) -> void:
	var bad: Array = []
	for sig: String in want:
		var n := _signal(s, sig)
		if n != int(want[sig]):
			bad.append("%s %d (want %d)" % [sig, n, int(want[sig])])
	_expect(bad.is_empty(), "%s: signals %s%s" % [label, str(want.keys()), "" if bad.is_empty() else " " + str(bad)])


## Each of `names` a property of `o`.
func _props(o: Object, label: String, names: Array) -> void:
	var have := {}
	for d: Dictionary in o.get_property_list():
		have[String(d.name)] = true
	var bad := names.filter(func(n: String) -> bool: return not have.has(n))
	_expect(bad.is_empty(), "%s: vars %s%s" % [label, str(names), "" if bad.is_empty() else " missing " + str(bad)])


func _symbols() -> void:
	_methods(RingRules, "RingRules", {"stock_on": [0, true], "class_of": [1, true], "launch_v": [6, true],
			"range_mult": [2, true], "weight_of": [1, true], "pct_of": [1, false], "stocks_of": [1, false],
			"safe_until": [1, false], "hitstun_left": [1, false], "stunned": [1, false], "can_escape": [1, false],
			"string_hits": [1, false], "stale_count": [2, false], "last_steer_deg": [1, false], "fresh_pct": [1, false],
			"heal_allowed": [1, false], "add_pct": [4, false], "reset_pct": [2, false], "patch": [1, false],
			"on_hit": [3, false], "note_lock_started": [1, false]})
	_signals(RingRules, "RingRules", {"pct_changed": 3, "launched": 5, "ko": 5, "respawned": 1, "string_ended": 4,
			"hit_safe": 3})
	_methods(BendKnock, "BendKnock", {"apply_di": [1, false], "press_break": [1, false], "getup": [1, false],
			"scale_carry": [1, false], "knock": [3, false]})
	_signals(BendKnock, "BendKnock", {"launched": 3, "broke_fall": 2})
	var kn := BendKnock.new()
	_props(kn, "BendKnock", ["stun_t", "tumble", "lying_t"])
	kn.kv = Vector3(4.0, 0.0, -2.0)
	kn.scale_carry(0.5)
	_expect(kn.kv.is_equal_approx(Vector3(2.0, 0.0, -1.0)), "BendKnock.scale_carry(0.5) halves the carry (%s)" % kn.kv)
	kn.free()
	_expect(is_zero_approx(BendKnock.gravity_override) and is_equal_approx(BendKnock.launch_gravity(),
			float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))),
			"BendKnock.gravity_override 0: the launch's gravity the world's, as today (%.2f)" % BendKnock.launch_gravity())
	_methods(BendStatus, "BendStatus", {"knock": [4, true], "hurt": [7, true], "can_take": [2, true]})
	_expect(BendStatus.take_filters is Array and BendStatus.take_filters.is_empty(), "BendStatus.take_filters: an empty list")
	_methods(RingArena, "RingArena", {"nearest_lip": [1, false], "lip_y": [0, false], "spout_at": [2, false],
			"is_out": [1, false], "wall_place_ok": [1, false]})
	_methods(RingMoves, "RingMoves", {"install": [1, true], "of": [1, true], "pre": [2, false], "intent_from_keys": [0, false],
			"profile": [0, false], "can_cast": [0, false], "airborne": [0, false], "off_deck": [0, false],
			"helpless": [0, false], "on_ledge": [0, false], "on_spout": [0, false], "intangible": [0, false],
			"in_landing_lag": [0, false], "ledge_safe_left": [0, false], "dodge": [1, false], "land_lag": [1, false],
			"ride_spout": [2, false], "leave_spout": [0, false], "cam_bias": [0, false], "simulate": [4, true]})
	_signals(RingMoves, "RingMoves", {"moved": 1, "left_spout": 0})
	var mv := RingMoves.new()
	_props(mv, "RingMoves", ["jumps_left", "dodge_ready", "rise_ready"])
	_expect(mv.can_cast() and not mv.airborne() and not mv.off_deck() and not mv.helpless() and not mv.on_ledge()
			and not mv.on_spout() and not mv.intangible() and not mv.in_landing_lag() and not mv.pre({}, 0.016)
			and mv.intent_from_keys().is_empty() and is_equal_approx(float(mv.profile().get("self_up_mult", 0.0)), 1.0)
			and mv.cam_bias().is_empty() and RingMoves.simulate({}, [], 0.1, 1.0).is_empty(),
			"RingMoves' stubs: casting allowed, on the deck, nothing moved, self_up_mult 1")
	mv.free()
	_methods(RingPredict, "RingPredict", {"flight": [4, true], "would_ko": [6, true], "ko_pct": [6, true]})
	var fl := RingPredict.flight(Vector3(10.0, 5.0, 0.0), 0.5, Vector3.ZERO, "earth")
	_expect(String(fl.get("lands", "")) == "deck" and not RingPredict.would_ko("x/y", null, Vector3.ZERO, Vector3.FORWARD)
			and RingPredict.ko_pct("x/y", null, Vector3.ZERO, Vector3.FORWARD) == INF,
			"RingPredict's stubs: it lands on the deck, nothing KOs (%s)" % fl)
	_methods(NpcPad, "NpcPad", {"press": [1, false], "hold": [2, false], "intent": [0, false]})
	var pad := NpcPad.new()
	_props(pad, "NpcPad", ["move", "di"])
	pad.press("jump")
	pad.hold("guard", true)
	pad.move = Vector3.FORWARD
	var it := pad.intent()
	var keys := ["move", "jump", "jump_short", "jump_held", "dodge", "dodge_dir", "fast_fall", "down_held", "guard_held",
			"guard_pressed", "ledge", "di"]
	_expect(keys.all(func(k: String) -> bool: return it.has(k)) and it.size() == keys.size() and bool(it.jump)
			and bool(it.guard_held) and Vector3(it.move) == Vector3.FORWARD and not bool(pad.intent().jump),
			"NpcPad.intent(): the twelve keys, a press read once, a hold kept (%s)" % it)
	_methods(SwayCaster, "SwayCaster", {"guard_up": [0, false], "ready_default": [0, false], "drop_all": [0, false]})
	_signals(SwayCaster, "SwayCaster", {"air_cast": 2, "lock_started": 2, "cast_released": 2})
	_methods(MatchSetup, "MatchSetup", {"rule_set": [0, true], "games": [0, true], "practice_pct": [0, true]})
	_expect(MatchSetup.rule_set() == String(RingRules.data().get("rule_set", "")) and MatchSetup.games() == 1
			and MatchSetup.practice_pct().is_empty(), "MatchSetup: rules.json's rule set with none chosen, 1 game, no practice %")
	_methods(RingPractice, "RingPractice", {"reset": [0, false], "step": [1, false], "set_way": [1, false], "paint": [0, false]})
	_expect(String(RingRules.data().get("rule_set", "")) == "stock", "rules.json rule_set \"stock\" (PERCENT's default since round 3)")
	for f: String in ["movement", "hud", "practice"]:
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/ring/%s.json" % f))
		_expect(d is Dictionary and String((d as Dictionary).get("_about", "")) != "", "data/ring/%s.json: its _about" % f)


## RingRules' per-competitor stubs on a RingRules not in the tree: no %, no lives, never stunned, heal allowed.
func _stubs() -> void:
	var r := RingRules.new()
	var b := Node3D.new()
	r.add_pct(b, 10.0, null, "x/y")
	r.reset_pct(b)
	r.note_lock_started(b)
	_expect(r.pct_of(b) == 0.0 and r.stocks_of(b) == 0 and r.safe_until(b) == -INF and r.hitstun_left(b) == 0.0
			and not r.stunned(b) and not r.can_escape(b) and r.string_hits(b) == 0 and r.stale_count(b, "x/y") == 0
			and r.last_steer_deg(b) == 0.0 and r.fresh_pct(b) == 0.0 and r.heal_allowed(b) and r.patch(b) == 0.0
			and r.on_hit(b, null, {}).is_empty() and not RingRules.class_of("stone_form/spike").is_empty()
			and absf(RingRules.weight_of("earth") - 2.0 / 2.25) < 1e-4 and r.rule_set == "classic",
			"RingRules' per-body answers off the books and with the gate off: no %, no lives, no stun, heal allowed, no launch (the classes filled)")
	b.free()
	r.free()


# ---------------------------------------------------------------- the launch (spec §2.2)
func _launch() -> void:
	var cls := {"tag": "test/launch", "base": 6.0, "growth": 30.0, "set": false}
	var p_after := 80.0
	var d := 10.0
	var w := 1.1
	# (the spec's numbers: R 1.0 to 10 m, linear to 0.65 at 22 m and beyond; A 0.85 in the air)
	var want := func(rr: float, a: float) -> float: return w * (6.0 + 30.0 * rr * a * p_after / 100.0 * (0.5 + d / 20.0))
	var r16 := 1.0 + (0.65 - 1.0) * (16.0 - 10.0) / (22.0 - 10.0)
	var got := [RingRules.launch_v(cls, p_after, d, w), RingRules.launch_v(cls, p_after, d, w, 16.0),
			RingRules.launch_v(cls, p_after, d, w, 30.0), RingRules.launch_v(cls, p_after, d, w, 0.0, true)]
	var wants := [want.call(1.0, 1.0), want.call(r16, 1.0), want.call(0.65, 1.0), want.call(1.0, 0.85)]
	var ok := true
	for i in got.size():
		ok = ok and absf(float(got[i]) - float(wants[i])) < 1e-4
	_expect(ok, "launch_v: the formula at 0, 16 and 30 m and in the air (%s; want %s)" % [str(got), str(wants)])
	_expect(is_equal_approx(RingRules.launch_v({"base": 7.5, "growth": 40.0, "set": true}, 150.0, 8.0, 1.2), 7.5),
			"a set class launches at its base, whatever the %% (%.2f)" % RingRules.launch_v({"base": 7.5, "set": true}, 150.0, 8.0, 1.2))
	_expect(is_equal_approx(RingRules.range_mult("x/y", 4.0), 1.0) and is_equal_approx(RingRules.range_mult("x/y", 10.0), 1.0)
			and is_equal_approx(RingRules.range_mult("x/y", 22.0), 0.65) and is_equal_approx(RingRules.range_mult("x/y", 60.0), 0.65)
			and is_equal_approx(RingRules.range_mult("x/y", 16.0), r16),
			"range_mult: 1.0 to 10 m, %.3f at 16 m, 0.65 at 22 m and beyond" % RingRules.range_mult("x/y", 16.0))


# ---------------------------------------------------------------- the open world
func _open_world() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 20:
		await process_frame
	var pl := current_scene.get_node_or_null("Player") as FrontierPlayer if current_scene != null else null
	_expect(pl != null, "the open world and its player")
	await _secs(1.0)
	_expect(pl != null and RingMoves.of(pl) == null and not RingRules.stock_on() and RingRules.current() == null
			and BendStatus.take_filters.is_empty(),
			"the open world: RingMoves.of(player) null, stock_on false, no RingRules, no take filters")


# ---------------------------------------------------------------- the classic ring and one right-click cast
## The foe held where he stands (no cast, no knock on the player).
func _hold_foe() -> void:
	if foe == null or not is_instance_valid(foe):
		return
	foe.held = true
	if _foe_at == Vector3.INF:
		_foe_at = foe.global_position
	foe.global_position = _foe_at
	foe.velocity = Vector3.ZERO


func _ring() -> void:
	MatchSetup.incoming = true
	MatchSetup.element = "earth"
	RingRules.rule_set_override = "classic"      # (the merge: rules.json plays stock by default; this checks the classic ring)
	change_scene_to_file("res://scenes/ring.tscn")
	for i in 10:
		await process_frame
	var lvl := current_scene as RingLevel
	p = lvl.player if lvl != null else null
	_expect(p != null, "the ring and its player")
	if p == null:
		return
	p.ignore_mouse_capture = true
	p.pitch = -0.1
	c = SwayCaster.of(p)
	var laid := await _until(func() -> bool: return p.arena_element == "earth" and p.hotbar.spell != "", 6.0)
	rm = RingMode.find(self)
	var up := INF
	if rm != null:
		up = await _until(func() -> bool: return rm.phase == "FIGHT", 10.0)
	_expect(laid < INF and c != null and up < INF, "the arena player, earth laid, the round on")
	if c == null or rm == null:
		return
	foe = rm.foe
	physics_frame.connect(_hold_foe)
	_expect(RingRules.current() == rm.rules and rm.rules.rule_set == "classic" and not RingRules.stock_on()
			and RingMoves.of(p) == null and (foe == null or RingMoves.of(foe) == null) and BendStatus.take_filters.is_empty(),
			"the classic ring: its RingRules installed, rule_set classic, stock_on false, no RingMoves on either")
	_lip(rm.ring)
	_expect(not c.guard_up(), "SwayCaster.guard_up(): no guard of his stands")
	await _secs(0.5)
	# one right-click cast: key 1's first move readied, the aim's button held to a full lock, let go
	var started: Array = []
	var released: Array = []
	c.lock_started.connect(func(m: String, _t: Node3D) -> void: started.append(m))
	c.cast_released.connect(func(m: String, md: String) -> void: released.append([m, md]))
	p.hotbar.select(0)
	await _secs(0.4)
	var ready := c.readied_spell
	c.held_override = true
	var full := await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 4.0)
	c.held_override = false
	await _secs(1.5)
	_expect(ready != "" and full < INF and started.size() == 1 and released.size() == 1 and String(released[0][0]) == ready
			and String(started[0]) == ready and String(released[0][1]) == c.base_mode_of(ready),
			"one right-click cast of %s: lock_started once (%s), cast_released once (%s)" % [ready, str(started), str(released)])
	# the guard (E): guard_up() true while its round-2 zone stands
	var zones := []
	c.cast.connect(func(m: String, _t: Node3D) -> void: zones.append(m))
	c.guard_override = true
	await _ticks(4)
	c.guard_override = false
	var g := await _until(func() -> bool: return c.guard_up(), 2.0)
	if g == INF:
		for z in get_nodes_in_group(BendZone.GROUP):
			var bz := z as BendZone
			print("    (zone %s r2 %s owner %s; casts %s)" % [bz.kind, bz.r2, bz.owner_node, zones])
	_expect(g < INF, "SwayCaster.guard_up(): true once the guard's zone stands (after %.2f s)" % g)
	await _secs(1.5)
	physics_frame.disconnect(_hold_foe)


## nearest_lip on each side, at two corners outside and one inside; spout_at, lip_y, wall_place_ok.
func _lip(a: RingArena) -> void:
	var hl := a.half_l()
	var hw := a.half_w()
	var top := a.top()
	var cases := [
		# [local point, side, out_m, local lip point, along]
		[Vector3(-hl + 2.0, top, 1.0), RingArena.LIP_END_0, -2.0, Vector3(-hl, top, 1.0), 1.0],
		[Vector3(hl - 2.0, top, -1.0), RingArena.LIP_END_1, -2.0, Vector3(hl, top, -1.0), -1.0],
		[Vector3(2.0, top, -hw + 1.0), RingArena.LIP_LONG_NEG, -1.0, Vector3(2.0, top, -hw), 2.0],
		[Vector3(-3.0, top, hw - 0.5), RingArena.LIP_LONG_POS, -0.5, Vector3(-3.0, top, hw), -3.0],
		[Vector3(hl + 1.0, top - 2.0, 3.0), RingArena.LIP_END_1, 1.0, Vector3(hl, top, 3.0), 3.0],
		# (corners: outside past both lips; the side the one it is further out past)
		[Vector3(hl + 1.0, top, hw + 1.0), RingArena.LIP_END_1, sqrt(2.0), Vector3(hl, top, hw), hw],
		[Vector3(hl + 0.5, top, -hw - 2.0), RingArena.LIP_LONG_NEG, sqrt(0.25 + 4.0), Vector3(hl, top, -hw), hl],
		# (inside the corner: the nearer lip)
		[Vector3(-hl + 0.5, top, hw - 0.2), RingArena.LIP_LONG_POS, -0.2, Vector3(-hl + 0.5, top, hw), -hl + 0.5],
	]
	var normals := {RingArena.LIP_END_0: Vector3(-1, 0, 0), RingArena.LIP_END_1: Vector3(1, 0, 0),
			RingArena.LIP_LONG_NEG: Vector3(0, 0, -1), RingArena.LIP_LONG_POS: Vector3(0, 0, 1)}
	var bad: Array = []
	for cs: Array in cases:
		var r := a.nearest_lip(a.to_global(cs[0]))
		var pt := a.to_local(Vector3(r.point))
		var n := a.global_basis.inverse() * Vector3(r.normal)
		var ok: bool = int(r.side) == int(cs[1]) and absf(float(r.out_m) - float(cs[2])) < 1e-3 \
				and pt.distance_to(cs[3]) < 1e-3 and absf(float(r.along) - float(cs[4])) < 1e-3 \
				and n.distance_to(normals[int(cs[1])]) < 1e-3
		if not ok:
			bad.append("%s -> %s" % [str(cs[0]), str(r)])
	_expect(bad.is_empty(), "nearest_lip: each of the four sides, two corners outside, one inside%s" % ("" if bad.is_empty() else " " + str(bad)))
	var sp := a.to_local(a.spout_at(0, 0))
	var sp1 := a.to_local(a.spout_at(1, 1))
	var zs: Array = RingArena.data().get("grate_z", [4.0, -4.0])
	_expect(sp.distance_to(Vector3(-12.0, top, float(zs[0]))) < 1e-3 and sp1.distance_to(Vector3(12.0, top, float(zs[1]))) < 1e-3,
			"spout_at: the s 12 m line on the grate's z (%s, %s)" % [sp, sp1])
	var q := a.to_global(Vector3(hl - 0.5, top, 0.0))
	_expect(is_equal_approx(a.lip_y(), a.deck_y()) and a.wall_place_ok(q).is_equal_approx(q),
			"lip_y the deck top (%.2f); wall_place_ok as given" % a.lip_y())
