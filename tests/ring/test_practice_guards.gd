extends SceneTree
## Each element's guard on E against Tidebreak's practice dummy (round 2's skills; the owner, 2026-10-05: "dont forget the
## other elements"), the way a player practises it: the ring scene asked for by the user args practice=throw element=<el>
## foe=<el> (the dummy of his own element throwing its strike every throw_every_s at him), his guard clicked on E
## (SwayCaster.guard_override, the button's stand-in) timed to the shot as it comes (tests/ring/guard_timing.gd):
##   on the beat   the shot reaches the guard early in its window: the guard says perfect (BendCaster.guarded), the player
##                 is not struck for the shot's full damage (water, fire, air: the shot sent back, doused, bounced; earth: held)
##   late          the shot reaches it past perfect_s: late (earth's stone still caught and held: it always catches stone)
##   whiff         a click with nothing coming: a whiff, and the next guard's lock is whiff_lock_s (BendZone.guard_lock_s)
##   earth         the stone caught is held (no slide), and E again throws it back at the dummy (its returns counted)
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_practice_guards.gd -- practice=throw element=water foe=water
## Watchdog LIMIT_S. Last line "PRACTICE GUARDS PASSED" or "PRACTICE GUARDS FAILED" (exit 0 only on a pass).

const NAME := "PRACTICE GUARDS"
const LIMIT_S := 240.0
const GuardTiming := preload("res://tests/ring/guard_timing.gd")
## Tries for the beat (the dummy's shots, one each), and the share of the window a late one aims at past perfect_s.
const TRIES := 4

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var mode: RingMode
var player: FrontierPlayer
var c: SwayCaster
var el := ""


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
	MatchSetup._aim_help = "strong"             # (the test's player does not aim his camera: the full help)
	SwayCaster.free_override = true
	InputSetup.ensure()
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(s: float) -> void:
	await _ticks(maxi(int(s * Engine.physics_ticks_per_second), 1))


func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit:
		if cond.call():
			return t
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return INF


func _end() -> void:
	if c != null:
		c.guard_override = null
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


func _run() -> void:
	for i in 10:
		await process_frame
	lvl = current_scene as RingLevel
	mode = RingMode.find(self)
	_expect(lvl != null and mode != null, "the ring with a match node")
	if mode == null:
		return _end()
	player = lvl.player
	await _until(func() -> bool: return mode.phase == "FIGHT" and foe() != null and player.arena_element != "", 12.0)
	c = SwayCaster.of(player)
	el = player.arena_element
	_expect(mode.practice and mode.dummy == "throw" and c != null and el != "" and mode.foe_element == el,
			"a practice against a %s dummy that throws (%s, %s, %s)" % [el, mode.practice, mode.dummy, mode.foe_element])
	if c == null or el == "":
		return _end()
	var g := Bending.guard(el)
	_expect(c.guard_ready() and String(c.guard_spell().get("id", "")) == String(g.get("id", "")),
			"E is the %s guard (%s/%s)" % [el, g.get("id", ""), g.get("mode", "")])
	# a whiff: E with nothing coming; the next guard's lock is the whiff's
	await _until(func() -> bool: return GuardTiming.shots(self, foe()).is_empty() and foe().brain.bending.casting == "", 6.0)
	var whiffed := [false]
	var bc := BendCaster.of(player)
	var on_g := func(r: String, _w: String) -> void:
		if r == "whiff":
			whiffed[0] = true
	bc.guarded.connect(on_g)
	c.guard_override = true
	await _ticks(2)
	c.guard_override = null
	await _until(func() -> bool: return whiffed[0], 3.0)
	var base := float(SwayMoves.move(String(g.id)).get("lock_s", 0.2)) * c.lock_mult * c.tier_mult(String(g.id))
	var wl := BendZone.guard_lock_s(player, base)
	_expect(whiffed[0] and wl >= Bending.rule("whiff_lock_s", 0.5) - 0.001,
			"a click with nothing coming: a whiff, the next guard's lock %.2f s (whiff_lock_s %.2f)" % [wl, Bending.rule("whiff_lock_s", 0.5)])
	bc.guarded.disconnect(on_g)
	await _until(func() -> bool: return BendStatus.until(player, &"bend_whiff_until") <= 0.0, 3.0)
	# on the beat
	var res: Array = []
	var perfect := false
	for i in TRIES:
		var r := await GuardTiming.on_beat(self, c, foe(), 0.12)
		res.append("%s (lead %.2f, due %.2f)" % [r.result, float(r.lead), float(r.enter)])
		if String(r.result) == "perfect":
			perfect = true
			break
		await _settle()
	_expect(perfect, "E on the beat of the dummy's shot: perfect (%s)" % [res])
	if el == "earth":
		await _earth_return()
	else:
		await _settle()
	# late: the shot reaches the guard past perfect_s
	var late := await GuardTiming.on_beat(self, c, foe(), Bending.rule("perfect_s", 0.3) + 0.2, 10.0, true)
	_expect(String(late.result) == "late", "E early, the shot past perfect_s: late (%s, lead %.2f)" % [late.result, float(late.lead)])
	if el == "earth":
		var held := BendZone.held_stone(player)
		_expect(held != null, "earth late: the stone still caught and held (%s)" % held)
		await _earth_return()
	_end()


## Between tries: the guard's zone gone, any caught stone thrown away, the whiff's slow lock run out.
func _settle() -> void:
	await _until(func() -> bool: return c.state == SwayCaster.State.IDLE, 2.0)
	await _until(func() -> bool: return BendStatus.until(player, &"bend_whiff_until") <= 0.0, 2.0)


## Earth: the caught stone held before him, not moved by it; E again throws it back toward the dummy.
func _earth_return() -> void:
	var held := BendZone.held_stone(player)
	_expect(held != null, "earth: the stone caught is held before him")
	if held == null:
		return
	await _until(func() -> bool: return c.state == SwayCaster.State.IDLE, 2.0)
	var d0 := held.global_position.distance_to(foe().global_position)
	c.guard_override = true
	await _ticks(2)
	c.guard_override = null
	var gone := await _until(func() -> bool: return BendZone.held_stone(player) == null, 2.0)
	await _secs(0.3)
	var live := is_instance_valid(held)
	var d1 := held.global_position.distance_to(foe().global_position) if live else 0.0
	var returns := int(held.get_meta(&"bend_returns", 0)) if live else -1
	_expect(gone < INF and live and returns >= 1 and d1 < d0,
			"E again: thrown back at the dummy (%.1f -> %.1f m, returns %d)" % [d0, d1, returns])
	await _settle()
