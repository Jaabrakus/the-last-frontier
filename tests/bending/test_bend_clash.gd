extends SceneTree
## Round 4 VIRAL: the clash (BendClash; data/ring/callouts.json "clash") in the % ring (rules stock; earth against a water
## bot, both held 7 m off the line the bolts fly), headless:
##   Godot --headless --fixed-fps 60 --path . -s tests/bending/test_bend_clash.gd -- mode=ring element=earth foe=water
##   each pair    two bolts flown at each other over the deck's middle (BendBolt.launch, the player's from one side, the
##                foe's from the other): stone + stone, water + fire (steam), water + water, fire + ice, air + fire, air +
##                water, stone + fire (the stone goes on), and a bolt meeting a flying stone (a GustLift's): exactly one clash
##                (BendClash.count + 1), one moment drawn (effects + 1), one sound (sounds + 1), at the meeting point (within
##                0.6 m of where the two met), clashed told once with both kinds and both casters
##   on no body   no node is added under either competitor by a clash
##   the gate     in the classic ring the same meeting makes no clash
## METRIC clash_pairs_covered. Watchdog LIMIT_S; last line "BEND CLASH PASSED" or "BEND CLASH FAILED".

const NAME := "BEND CLASH"
const LIMIT_S := 240.0
const OWN_CFG := "user://bend_clash_test.cfg"
const PAIRS := [["stone", "stone"], ["water", "fire"], ["water", "water"], ["fire", "ice"], ["air", "fire"], ["air", "water"],
		["stone", "fire"]]

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var ring: RingArena
var player: FrontierPlayer
var mode: RingMode
var clash: BendClash
var told: Array = []
var metrics := {}


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
	MatchSetup.element = "earth"
	MatchSetup.foes = ["water"]
	RingReplay.force = "off"
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit:
		if cond.call():
			return t
		await physics_frame
		t += 1.0 / 60.0
	return INF


func _end() -> void:
	for k: String in metrics:
		print("METRIC %s=%s" % [k, str(metrics[k])])
	RingRules.rule_set_override = ""
	RingReplay.force = ""
	GameSettings.path = GameSettings.PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
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
	var t := 0.0
	while not (mode.phase == "COUNTDOWN" and foe() != null) and t < 6.0:
		await process_frame
		t += 1.0 / 60.0
	mode.phase_t = RingRules.num("countdown_s", 3.0) - 0.02
	await _until(func() -> bool: return mode.phase == "FIGHT", 2.0)
	foe().held = true
	player.global_position = ring.to_global(Vector3(-4.0, ring.top() + 0.05, 7.0))
	foe().global_position = ring.to_global(Vector3(4.0, ring.top() + 0.05, -7.0))
	await _ticks(10)
	return true


func _run() -> void:
	var ok := await _scene()
	_expect(ok and RingRules.stock_on(), "the stock ring under way")
	if not ok:
		return _end()
	RingReplay.install(mode)
	clash = BendClash.find(self)
	_expect(clash != null, "the clash watcher installed")
	clash.clashed.connect(func(at: Vector3, ka: String, kb: String, _w: Vector3, a: Node, b: Node) -> void: told.append([at, ka, kb, a, b]))
	var covered := 0
	for pair: Array in PAIRS:
		if await _pair(String(pair[0]), String(pair[1])):
			covered += 1
	if await _lift_pair():
		covered += 1
	metrics["clash_pairs_covered"] = "%d/%d" % [covered, PAIRS.size() + 1]
	await _gate()
	_end()


func _kids() -> Array:
	return [player.get_child_count(), foe().get_child_count(), player.find_children("*", "", true, false).size(),
			foe().find_children("*", "", true, false).size()]


## Two bolts of kinds a (the player's) and b (the foe's) flown at each other 2 m over the deck's middle.
func _pair(a: String, b: String) -> bool:
	var y := ring.top() + 2.0
	var pa := ring.to_global(Vector3(-5.0, y, 0.0))
	var pb := ring.to_global(Vector3(5.0, y, 0.0))
	var dir := (pb - pa).normalized()
	var c0 := BendClash.count
	var e0 := BendClash.effects
	var s0 := BendClash.sounds
	var k0 := _kids()
	told.clear()
	var ba := BendBolt.launch(player, pa, dir, {"kind": a, "mps": 20.0, "radius_m": 0.3, "damage": 5.0, "range_m": 30.0})
	var bb := BendBolt.launch(foe(), pb, -dir, {"kind": b, "mps": 20.0, "radius_m": 0.3, "damage": 5.0, "range_m": 30.0})
	var met := [Vector3.INF]
	var mid := (pa + pb) * 0.5
	await _until(func() -> bool:
		if is_instance_valid(ba) and is_instance_valid(bb) and not ba.spent and not bb.spent:
			met[0] = (ba.global_position + bb.global_position) * 0.5
		return BendClash.count > c0 or ((not is_instance_valid(ba) or ba.spent) and (not is_instance_valid(bb) or bb.spent)), 2.0)
	await _ticks(4)
	var at: Vector3 = BendClash.last.get("at", Vector3.INF) if BendClash.count > c0 else Vector3.INF
	var ok: bool = BendClash.count == c0 + 1 and BendClash.effects == e0 + 1 and BendClash.sounds == s0 + 1 and told.size() == 1 \
			and at.distance_to(met[0] as Vector3) <= 0.6 and at.distance_to(mid) <= 1.2
	var who_ok: bool = told.size() == 1 and ((told[0][3] == player and told[0][4] == foe()) or (told[0][3] == foe() and told[0][4] == player))
	var kinds_ok: bool = told.size() == 1 and ([told[0][1], told[0][2]] == [a, b] or [told[0][1], told[0][2]] == [b, a])
	_expect(ok and who_ok and kinds_ok and _kids() == k0,
			"%s + %s: one clash, one moment, one sound at the meeting point (%d clash(es), at %s, met at %s), both kinds and casters told, nothing added to a body"
			% [a, b, BendClash.count - c0, str(at), str(met[0])])
	for bolt in [ba, bb]:
		if is_instance_valid(bolt) and not bolt.spent:
			bolt.end("test")
	await _ticks(30)
	return ok and who_ok and kinds_ok


## A bolt meeting a flying stone (a GustLift in its flight: the foe's stone hurled at the player's fire bolt; BendBolt's
## meet_lift).
func _lift_pair() -> bool:
	var y := ring.top() + 2.0
	var pa := ring.to_global(Vector3(-5.0, y, 0.0))
	var pb := ring.to_global(Vector3(5.0, y, 0.0))
	var dir := (pb - pa).normalized()
	var s := FormStone.ball(current_scene, pb - Vector3.UP * 0.26, {"radius_m": 0.26})
	var lift := GustLift.begin(foe(), s, {"hold": {"tear_s": 0.0, "rise_m": 0.0, "draw_s": 0.05, "strain_start_s": 1000.0,
			"break_s": 1001.0, "tremble_deg": 0.0}, "hurl": {"mps": [20.0, 20.0], "gravity": 0.0}, "mass_kg": 1000.0})
	if lift == null:
		_expect(false, "a flying stone for the bolt-vs-stone pair (GustLift.begin)")
		return false
	await _ticks(6)
	if is_instance_valid(s):
		s.global_position = pb
	lift.hurl(pa)
	var c0 := BendClash.count
	var e0 := BendClash.effects
	var s0 := BendClash.sounds
	var k0 := _kids()
	told.clear()
	var ba := BendBolt.launch(player, pa, dir, {"kind": "fire", "mps": 20.0, "radius_m": 0.3, "damage": 5.0, "range_m": 30.0})
	await _until(func() -> bool: return BendClash.count > c0 or not is_instance_valid(ba) or ba.spent, 2.0)
	await _ticks(4)
	var at: Vector3 = BendClash.last.get("at", Vector3.INF) if BendClash.count > c0 else Vector3.INF
	var ok: bool = BendClash.count == c0 + 1 and BendClash.effects == e0 + 1 and BendClash.sounds == s0 + 1 and told.size() == 1 \
			and at.distance_to((pa + pb) * 0.5) <= 3.0 and _kids() == k0
	var kinds_ok: bool = told.size() == 1 and "stone" in [told[0][1], told[0][2]] and "fire" in [told[0][1], told[0][2]]
	_expect(ok and kinds_ok, "fire + a flying stone (GustLift): one clash, one moment, one sound at the meeting point (%d, at %s; lift %s), nothing added to a body"
			% [BendClash.count - c0, str(at), str(lift.phase) if is_instance_valid(lift) else "gone"])
	if is_instance_valid(ba) and not ba.spent:
		ba.end("test")
	if is_instance_valid(lift):
		lift.drop(false)
	await _ticks(30)
	return ok and kinds_ok


func _gate() -> void:
	RingRules.rule_set_override = "classic"
	change_scene_to_file("res://scenes/ring.tscn")
	await process_frame
	var ok := await _scene()
	if not ok:
		_expect(false, "the classic ring")
		return
	RingReplay.install(mode)
	var c0 := BendClash.count
	var y := ring.top() + 2.0
	var pa := ring.to_global(Vector3(-5.0, y, 0.0))
	var pb := ring.to_global(Vector3(5.0, y, 0.0))
	var dir := (pb - pa).normalized()
	BendBolt.launch(player, pa, dir, {"kind": "stone", "mps": 20.0, "radius_m": 0.3, "damage": 5.0})
	BendBolt.launch(foe(), pb, -dir, {"kind": "stone", "mps": 20.0, "radius_m": 0.3, "damage": 5.0})
	await _ticks(60)
	_expect(BendClash.count == c0, "the classic ring (the gate off): the same meeting makes no clash")
