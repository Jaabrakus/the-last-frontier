extends SceneTree
## Zones' tug of war (RingRules' header; the owner, 2026-10-12: "we cant have 2 teams pushed back then they are to far is a give
## and take like a tug of war"), in a 1v1 Zones ring (fire against a held water bot), the knocks set up by hand (a body set
## past a line under a hitstun, as a launch leaves him) and RingRules judging them in its own frame:
##   the start    front 0: both at zone 1, the neutral strip open to both (each limit the other side's line 0)
##   take         the foe carried back past his own line 1: the front to 1, he at zone 2, the player free up to that same
##                line (the two limits one place on the deck), knocked_back told
##   give back    the player then carried back past the foe's line 0: the front back to 0, both at zone 1 again (never both
##                pushed back)
##   and on       the player carried back past his own line 1: the front to -1, he at zone 2, the foe free into his zone 1;
##                the time-out the foe's (territory)
##   eased        the front moving under one of the losing side stood 7 m forward: two frames on he has not been snapped
##                back, 2 s on he stands at his new line
##   winded       the foe winded at his last zone already (front 2): out of the round
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_zones_tug.gd
## The last line "ZONES TUG PASSED (<n> checks)" or "ZONES TUG FAILED (<f> of <n>)".

const LIMIT_S := 120.0

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var foe: NpcFighter
var rm: RingMode
var rules: RingRules
var told: Array = []


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("ZONES TUG FAILED (watchdog)")
		quit(2))
	MatchSetup.set_match()
	MatchSetup.incoming = true
	MatchSetup.format = "1v1"
	MatchSetup.element = "fire"
	MatchSetup.foes = ["water"]
	MatchSetup.round_s = 600.0
	RingRules.rule_set_override = "zones"
	SwayCaster.free_override = true
	InputSetup.ensure()
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _end() -> void:
	RingRules.rule_set_override = ""
	if fails.is_empty() and checks > 0:
		print("ZONES TUG PASSED (%d checks)" % checks)
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("ZONES TUG FAILED (%d of %d)" % [fails.size(), checks])
		quit(1)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _until(cond: Callable, s: float) -> bool:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await physics_frame
	return bool(cond.call())


## `b` set down at `s` (from the centre toward his own end), mid-deck across.
func _place(b: CharacterBody3D, s: float) -> void:
	var ar := rm.ring
	var e := rules.end_of(b)
	b.global_position = ar.center() + ar.axis() * RingArena.side_sign(e) * s + Vector3.UP * 0.05
	b.velocity = Vector3.ZERO


## `b` carried back to `s` past a line, under a launch's hitstun (RingRules._knocked), then judged a few frames.
func _knock_to(b: CharacterBody3D, s: float) -> void:
	_place(b, s)
	var kn := BendKnock.of(b)
	kn.stun_t = 0.4
	await _ticks(4)
	kn.stun_t = 0.0
	await _ticks(2)


## The world x of `b`'s forward limit along the deck's axis.
func _lim_at(b: Node3D) -> float:
	return (rm.ring.axis() * RingArena.side_sign(rules.end_of(b)) * rules.forward_limit(b)).dot(rm.ring.axis())


func _run() -> void:
	for i in 20:
		await process_frame
	var lvl := current_scene as RingLevel
	p = lvl.player if lvl != null else null
	rm = RingMode.find(self)
	foe = rm.foe as NpcFighter if rm != null else null
	rules = rm.rules if rm != null else null
	_expect(p != null and foe != null and rules != null, "the ring, the player and the foe")
	if rules == null or foe == null:
		return _end()
	var fight := await _until(func() -> bool: return rm.phase == "FIGHT" and rules.live, 12.0)
	_expect(fight and rules.rule_set == "zones" and rules.tug(), "a Zones fight on (%s)" % rules.rule_set)
	foe.held = true
	rules.knocked_back.connect(func(w: Node3D, a: int, b: int) -> void: told.append([w, a, b]))
	var ar := rm.ring
	var line := func(k: int) -> float: return ar.line_s(0, k)
	_place(p, 6.0)
	_place(foe, 6.0)
	await _ticks(10)
	# ---- the start
	_expect(rules.front == 0 and rules.confined_of(p) == 1 and rules.confined_of(foe) == 1
			and is_equal_approx(rules.forward_limit(p), -float(line.call(0))) and is_equal_approx(rules.forward_limit(foe), -float(line.call(0))),
			"front 0: both at zone 1, each free to the other's line 0 (%.1f, %.1f)" % [rules.forward_limit(p), rules.forward_limit(foe)])
	# ---- take
	await _knock_to(foe, float(line.call(1)) + 0.6)
	_expect(rules.front == 1 and rules.confined_of(foe) == 2 and rules.confined_of(p) == 1 and rules.may_enter(0, 1),
			"the foe carried back past his line 1: the front to 1, he at zone 2, the player may enter his zone 1 (front %d)" % rules.front)
	_expect(absf(_lim_at(p) - _lim_at(foe)) < 0.01, "both held to one line on the deck (%.2f, %.2f)" % [_lim_at(p), _lim_at(foe)])
	_expect(not told.is_empty() and told[-1][0] == foe and int(told[-1][2]) == 2, "knocked_back told (%s)" % str(told.map(func(x: Array) -> String: return "%s %d>%d" % [(x[0] as Node).name, x[1], x[2]])))
	# ---- give back
	await _knock_to(p, -float(line.call(0)) + 1.0)
	_expect(rules.front == 0 and rules.confined_of(p) == 1 and rules.confined_of(foe) == 1,
			"the player then carried back off the foe's ground: the front back to 0, both at zone 1, never both pushed back (front %d)" % rules.front)
	# ---- and on
	await _knock_to(p, float(line.call(1)) + 0.6)
	_expect(rules.front == -1 and rules.confined_of(p) == 2 and rules.confined_of(foe) == 1 and rules.may_enter(1, 1) and not rules.may_enter(0, 1),
			"the player carried back past his line 1: the front to -1, he at zone 2, the foe free into his zone 1 (front %d)" % rules.front)
	_expect(rules.territory() == 1, "the time-out now the foe's (%d)" % rules.territory())
	# ---- eased
	_place(foe, 2.0)
	await _ticks(3)
	_place(p, -1.0)
	await _ticks(2)
	rules._give(0, 1)                                  # (the front a zone further toward the player's end under him)
	var want := rules.forward_limit(p)
	await _ticks(2)
	var s2 := rules.s_of(p)
	await _until(func() -> bool: return absf(rules.s_of(p) - want) < 0.3, 3.0)
	var s_end := rules.s_of(p)
	_expect(rules.front == -2 and want - s2 > 3.0 and absf(s_end - want) < 0.3,
			"the front moved under him: two frames on still %.1f m short of his new line (no snap), then at it (%.2f vs %.2f)" % [want - s2, s_end, want])
	# ---- winded at the last zone
	rules._give(1, 4)
	_expect(rules.front == ar.num("zones", 3.0) - 1, "the front kept short of the far side (front %d)" % rules.front)
	rules._zones_wind(foe, p)
	_expect(rules.is_out(foe), "the foe winded at his last zone: out of the round")
	_end()
