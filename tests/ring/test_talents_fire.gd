extends SceneTree
## Fire's behaviour talents in a real ring (the owner, 2026-10-11: "we need to make sure all the talents work and they work in
## game right"; FireTalents, loadout_apply.json `behaviour`): each node worn on the player alone, played through the game's own
## code (his SwayCaster's locks held and let go, real casts, guards and hits), worn and not worn; a bot wearing one where it
## has a bot side (NpcBending's lock):
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_talents_fire.gd -- mode=ring practice=stand element=fire foe=fire
##   Hot Hands         a perfect Parry: the next Punch's lock begun within 1 s starts half full (Classic: empty); the Parry's
##                     late share 0.6 (0.5)
##   Two-Hand Rhythm   a Punch let go on the Beat: the next Punch starts 30% full; let go late, nothing; a bot's too
##   Chain Kicks       a Kick let go on the Beat: the next Kick starts 40% full; the Kick's lock 0.65 s (0.6)
##   Grounded Charge   a hit breaks the Lightning charge; the next Lightning begun within 1 s starts half full
##   Hot Feet          standing still the fill x0.9, on the move x1.1 (Classic x1.0 both); a bot's standing fill x0.9
##   Dancing Feet      on the move x0.9; within 0.6 s of a real Step's end x1.15
##   each              resolves whole and is live (BendLoadout.why_not), and Classic (nothing worn) reads the game's own
## Last line "TALENTS FIRE PASSED (n checks)" or "... FAILED".

const BUILT := ["fire.parry.hot_hands", "fire.punch.rhythm", "fire.kick.chain", "fire.lightning.grounded",
		"fire.passive.dancing_feet", "fire.passive.hot_feet"]
const WATCHDOG_S := 400.0

var checks := 0
var fails: Array[String] = []
var p: FrontierPlayer
var c: SwayCaster
var bc: BendCaster
var mode: RingMode
var foe: Node3D
var starts: Array = []                 ## [move, fill at its lock's start, at]
var casts: Array = []                  ## [move, mode, at]
var _foe_at := Vector3.INF


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	create_timer(WATCHDOG_S, true, false, true).timeout.connect(func() -> void:
		print("TALENTS FIRE FAILED (watchdog)")
		quit(2))
	InputSetup.ensure()
	SwayCaster.free_override = true
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _end() -> void:
	if p != null and is_instance_valid(p):
		BendLoadout.clear(p)
		if c != null:
			c.held_override = null
			c.quick_override = null
			c.guard_override = null
			c.speed_override = null
	if foe != null and is_instance_valid(foe):
		BendLoadout.clear(foe)
	BendLoadout.config_override = {}
	if fails.is_empty() and checks > 0:
		print("TALENTS FIRE PASSED (%d checks)" % checks)
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("TALENTS FIRE FAILED (%d of %d)" % [fails.size(), checks])
		quit(1)


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


func _hold_foe() -> void:
	if foe == null or not is_instance_valid(foe):
		return
	if _foe_at == Vector3.INF:
		_foe_at = foe.global_position
	foe.global_position = _foe_at
	(foe as CharacterBody3D).velocity = Vector3.ZERO


func _run() -> void:
	for i in 12:
		await process_frame
	var lvl := current_scene as RingLevel
	p = lvl.player if lvl != null else null
	mode = RingMode.find(self)
	_expect(p != null and mode != null, "a practice ring")
	if p == null or mode == null:
		return _end()
	await _until(func() -> bool: return mode.phase == "FIGHT", 12.0)
	await _secs(0.5)
	p.ignore_mouse_capture = true
	p.pitch = -0.1
	c = SwayCaster.of(p)
	bc = BendCaster.of(p)
	foe = mode.foe
	physics_frame.connect(_hold_foe)
	c.lock_started.connect(func(m: String, _t: Node3D) -> void: starts.append([m, c.fill, BendStatus.now()]))
	c.cast.connect(func(m: String, _t: Node3D) -> void: casts.append([m, c.mode_of(m), BendStatus.now()]))
	Bending.of(p).element = "fire"
	await _until(func() -> bool: return p.arena_element == "fire", 3.0)
	# (worn as the live list will hold them, whatever the file says today)
	var live: Array = (BendLoadout.config().get("live", []) as Array).duplicate()
	for id: String in BUILT:
		if not id in live:
			live.append(id)
	BendLoadout.config_override = {"live": live}
	for id: String in BUILT:
		var r := BendLoadout.resolve(id)
		_expect(bool(r.ok) and BendLoadout.why_not(id) == "" and id in BendLoadout.behaviour(),
				"%s resolves whole and is live (%s)" % [id, String(r.why) if not bool(r.ok) else BendLoadout.why_not(id)])
	await _hot_hands()
	await _rhythm()
	await _chain()
	await _grounded()
	await _feet()
	await _bot()
	_end()


# ---------------------------------------------------------------- helpers
## `id` worn alone by the player as a fire caster ("" nothing worn: Classic).
func _wear(id: String, on: Node = null) -> void:
	var who: Node = p if on == null else on
	BendLoadout.clear(who)
	if id != "":
		var ov := BendLoadout.wear(who, [id], "", "fire")
		if not (ov.ids as Array).has(id):
			_expect(false, "%s worn (refused: %s)" % [id, str(ov.refused)])


## Every button let go, the deck cleared of bending, his talent marks gone, the player whole facing the foe.
func _calm() -> void:
	c.held_override = false
	c.quick_override = false
	c.guard_override = false
	c.speed_override = null
	await _ticks(2)
	c._wait_release = false
	for g: StringName in [BendBolt.GROUP, BendZone.GROUP]:
		for x in get_nodes_in_group(g):
			if is_instance_valid(x):
				x.queue_free()
	for k: StringName in [FireTalents.HEAD_META, FireTalents.STEP_META, &"talent_beat_at", &"bend_dash_end"] + BendStatus.ROUND_METAS:
		if p.has_meta(k):
			p.remove_meta(k)
	var kn := BendKnock.peek(p)
	if kn != null:
		kn.reset()
	if mode.ring != null:
		RingLevel.place(p, mode.ring.spawn(mode.player_end))
	p.velocity = Vector3.ZERO
	p.pitch = -0.1
	await _secs(0.5)


func _tap(i: int) -> void:
	p.hotbar.select(i)
	await physics_frame


## The aim's button held until a lock of `m` begins (true) or `limit` s: its fill at the start is starts[-1][1].
func _begin(m: String, limit := 1.0) -> bool:
	var n0 := starts.size()
	c.held_override = true
	return await _until(func() -> bool: return starts.size() > n0 and String(starts[-1][0]) == m, limit) < INF


func _start_fill() -> float:
	return float(starts[-1][1]) if not starts.is_empty() else -1.0


## Held until full, then let go `late` s after the click: its cast made (true).
func _cast_at(late: float, limit := 3.0) -> bool:
	var full := await _until(func() -> bool: return c.state == SwayCaster.State.FULL, limit) < INF
	if not full:
		c.held_override = false
		return false
	if late > 0.0:
		await _secs(late)
	var n0 := casts.size()
	c.held_override = false
	return await _until(func() -> bool: return casts.size() > n0, 1.0) < INF


## A fire bolt of the foe's (his Punch, through BendR3's info and BendBolt.launch as his cast makes it) from `ahead` m before
## the player straight at his chest.
func _foe_punch(ahead := 3.0) -> BendBolt:
	var fbc := BendCaster.of(foe)
	var spec: Dictionary = ((SwayMoves.move("fire_blast").bend as Dictionary).punch as Dictionary).duplicate()
	spec["_info"] = BendR3.info_for(fbc if fbc != null else foe, "fire_blast", "punch", false, spec)
	spec["_lock_s"] = BendEffects.lock_of("fire_blast", "punch")
	var chest := p.global_position + Vector3.UP * 1.2
	var fwd := -p.global_basis.z
	fwd.y = 0.0
	var from := chest + fwd.normalized() * ahead
	return BendBolt.launch(foe, from, (chest - from).normalized(), spec)


# ---------------------------------------------------------------- Hot Hands
func _hot_hands() -> void:
	var got := {}
	for id: String in ["", "fire.parry.hot_hands"]:
		await _calm()
		_wear(id)
		# a real Parry (E): its zone up, the foe's Punch into it at once (inside perfect_s)
		c.guard_override = true
		var z_up := await _until(func() -> bool: return _zone_of(p, "parry") != null, 1.0) < INF
		var z := _zone_of(p, "parry")
		var lm := z.late_mult if z != null else -1.0
		_foe_punch(2.0)
		var res := await _until(func() -> bool: return z != null and is_instance_valid(z) and not z.results.is_empty(), 1.0)
		var result: String = String(z.results[0]) if res < INF and is_instance_valid(z) else "none"
		c.guard_override = false
		await _secs(0.25)
		await _tap(0)
		var began := await _begin("fire_blast")
		got[id] = {"z": z_up, "result": result, "fill": _start_fill() if began else -1.0, "late": lm}
		c.held_override = false
	var c0: Dictionary = got[""]
	var hh: Dictionary = got["fire.parry.hot_hands"]
	_expect(c0.result == "perfect" and hh.result == "perfect", "a perfect Parry of the foe's Punch, worn and not (%s, %s)" % [c0.result, hh.result])
	_expect(absf(float(c0.fill)) < 0.02 and absf(float(hh.fill) - 0.5) < 0.02,
			"Hot Hands: the Punch begun after a perfect Parry starts %.2f full (Classic %.2f)" % [hh.fill, c0.fill])
	_expect(is_equal_approx(float(c0.late), 0.5) and is_equal_approx(float(hh.late), 0.6),
			"Hot Hands: the Parry's zone lets %.2f through late (Classic %.2f)" % [hh.late, c0.late])
	# a real late Parry: the foe's Punch into the zone after its perfect window, the % it adds to him
	var pct := {}
	for id: String in ["", "fire.parry.hot_hands"]:
		await _calm()
		_wear(id)
		var rr := RingRules.current()
		rr._stale.clear()
		c.guard_override = true
		await _until(func() -> bool: return _zone_of(p, "parry") != null, 1.0)
		var z := _zone_of(p, "parry")
		await _secs(0.4)
		var before := rr.pct_of(p)
		_foe_punch(2.0)
		await _until(func() -> bool: return z != null and is_instance_valid(z) and not z.results.is_empty(), 1.0)
		await _ticks(20)
		pct[id] = [String(z.results[0]) if is_instance_valid(z) and not z.results.is_empty() else "none", rr.pct_of(p) - before]
		c.guard_override = false
	var d := float(RingRules.class_of("fire_blast/punch").d) * RingRules.stock_num("pct_scale", 1.0)
	_expect(pct[""][0] == "late" and pct["fire.parry.hot_hands"][0] == "late" and absf(float(pct[""][1]) - d * 0.5) < 0.05
			and absf(float(pct["fire.parry.hot_hands"][1]) - d * 0.6) < 0.05,
			"Hot Hands: a late Parry lets %.2f%% of the Punch's %.1f%% through (Classic %.2f%%; %s, %s)" % [pct["fire.parry.hot_hands"][1], d, pct[""][1], pct[""][0], pct["fire.parry.hot_hands"][0]])
	# (and the head start waits no longer than 1 s)
	await _calm()
	_wear("fire.parry.hot_hands")
	FireTalents.guarded(p, "perfect", "fire", "fire")
	await _secs(1.2)
	await _tap(0)
	var late_ok := await _begin("fire_blast")
	_expect(late_ok and absf(_start_fill()) < 0.02, "Hot Hands: a Punch begun 1.2 s after starts empty (%.2f)" % _start_fill())
	c.held_override = false


func _zone_of(owner: Node, kind: String) -> BendZone:
	for z in get_nodes_in_group(BendZone.GROUP):
		if z is BendZone and (z as BendZone).owner_node == owner and (z as BendZone).kind == kind and not z.is_queued_for_deletion():
			return z as BendZone
	return null


# ---------------------------------------------------------------- Two-Hand Rhythm, Chain Kicks
## Key `key`'s move locked and let go `late` s after its click, then the same move again at once: the second lock's start fill.
func _again(key: int, m: String, late: float) -> Array:
	await _calm()
	await _tap(key)
	if not await _begin(m):
		return [false, -1.0]
	var cast_ok := await _cast_at(late)
	await _ticks(3)
	if c.readied_spell != m:
		await _tap(key)
	var began := await _begin(m)
	var f := _start_fill() if began else -1.0
	c.held_override = false
	return [cast_ok and began, f]


func _rhythm() -> void:
	_wear("")
	var c0: Array = await _again(0, "fire_blast", 0.0)
	_wear("fire.punch.rhythm")
	var on: Array = await _again(0, "fire_blast", 0.0)
	var beat_seen := p.has_meta(&"talent_beat_at")
	var late: Array = await _again(0, "fire_blast", 0.32)
	_expect(bool(c0[0]) and bool(on[0]) and bool(late[0]), "Punch, let go, Punch again: real casts and locks")
	_expect(absf(float(c0[1])) < 0.02 and absf(float(on[1]) - 0.3) < 0.02 and absf(float(late[1])) < 0.02 and beat_seen,
			"Two-Hand Rhythm: a Punch let go on the Beat, the next starts %.2f full; let go 0.32 s late %.2f (Classic %.2f)"
			% [on[1], late[1], c0[1]])
	var cls := BendLoadout.hit_class(p, RingRules.class_of("fire_blast/punch"))
	_expect(is_equal_approx(float(cls.get("d", 0.0)), 14.0) and is_equal_approx(float(RingRules.class_of("fire_blast/punch").d), 15.0),
			"Two-Hand Rhythm: his Punch adds %.0f%% (the class's %.0f)" % [float(cls.get("d", 0.0)), float(RingRules.class_of("fire_blast/punch").d)])


func _chain() -> void:
	_wear("")
	var c0: Array = await _again(1, "fire_kick", 0.0)
	var lk0 := c.lock_s
	_wear("fire.kick.chain")
	var on: Array = await _again(1, "fire_kick", 0.0)
	var lk1 := c.lock_s
	_expect(bool(c0[0]) and bool(on[0]), "Kick, let go, Kick again: real casts and locks")
	_expect(absf(float(c0[1])) < 0.02 and absf(float(on[1]) - 0.4) < 0.02,
			"Chain Kicks: a Kick let go on the Beat, the next starts %.2f full (Classic %.2f)" % [on[1], c0[1]])
	_expect(absf(lk1 / maxf(lk0, 0.001) - 0.65 / 0.6) < 0.01, "Chain Kicks: the Kick's lock %.3f s (Classic %.3f: x0.65/0.6)" % [lk1, lk0])


# ---------------------------------------------------------------- Grounded Charge
func _grounded() -> void:
	var got := {}
	for id: String in ["", "fire.lightning.grounded"]:
		await _calm()
		_wear(id)
		await _tap(0)
		await _tap(0)
		var ready := c.readied_spell == "fire_arc"
		var began := await _begin("fire_arc")
		await _secs(0.5)
		# a hit (a Fire Wall's burn: % only, no launch) breaks the charge
		BendR3.deliver(p, 1.0, p.global_position + Vector3.UP, Vector3.FORWARD, foe, -1.0, Vector3.ZERO,
				{"tag": "fire_wall/wall", "wall_tick": true, "move": "fire_wall"})
		await physics_frame
		var broke := c.state == SwayCaster.State.IDLE and c.last_break == "hit"
		c.held_override = false
		await _ticks(3)
		var again := await _begin("fire_arc")
		got[id] = [ready and began and broke and again, _start_fill() if again else -1.0]
		c.held_override = false
	_expect(bool(got[""][0]) and bool(got["fire.lightning.grounded"][0]), "Lightning charged, broken by a hit, charged again (real locks)")
	_expect(absf(float(got[""][1])) < 0.02 and absf(float(got["fire.lightning.grounded"][1]) - 0.5) < 0.02,
			"Grounded Charge: the Lightning begun after the break starts %.2f full (Classic %.2f)" % [got["fire.lightning.grounded"][1], got[""][1]])


# ---------------------------------------------------------------- Hot Feet, Dancing Feet
## The Fire Wall's (key 4) fill gained over 18 frames from 2 frames after its lock began, at `speed` (an override: >moving_mps
## is on the move).
func _fill_rate(speed: float) -> float:
	await _calm()
	await _tap(3)
	c.speed_override = speed
	if not await _begin("fire_wall"):
		return -1.0
	await _ticks(2)
	var f0 := c.fill
	await _ticks(18)
	var f1 := c.fill
	c.held_override = false
	c.speed_override = null
	return f1 - f0


func _feet() -> void:
	var run := c.moving_mps + 2.0
	var got := {}
	for id: String in ["", "fire.passive.hot_feet", "fire.passive.dancing_feet"]:
		_wear(id)
		got[id] = [await _fill_rate(0.0), await _fill_rate(run)]
	var cl: Array = got[""]
	var hf: Array = got["fire.passive.hot_feet"]
	var df: Array = got["fire.passive.dancing_feet"]
	_expect(absf(float(cl[1]) / float(cl[0]) - 1.0) < 0.02, "Footwork (Classic): the fill on the move as standing (%.3f / %.3f)" % [cl[1], cl[0]])
	_expect(absf(float(hf[0]) / float(cl[0]) - 0.9) < 0.02 and absf(float(hf[1]) / float(cl[1]) - 1.1) < 0.02,
			"Hot Feet: standing still the fill x%.2f, on the move x%.2f (Classic x1.0)" % [float(hf[0]) / float(cl[0]), float(hf[1]) / float(cl[1])])
	_expect(absf(float(df[0]) / float(cl[0]) - 1.0) < 0.02 and absf(float(df[1]) / float(cl[1]) - 0.9) < 0.02,
			"Dancing Feet: on the move the fill x%.2f, standing x%.2f (Classic x1.0)" % [float(df[1]) / float(cl[1]), float(df[0]) / float(cl[0])])
	# a real Step (key 3), then the Fire Wall locked within 0.6 s of its end
	var step := {}
	for id: String in ["", "fire.passive.dancing_feet"]:
		await _calm()
		_wear(id)
		var n0 := casts.size()
		await _tap(2)                       # (key 3: its lock begins at the press and goes when full, SwayCaster.key3_press)
		var began := starts.size() > 0 and String(starts[-1][0]) == "footwork"
		var cast_ok := await _until(func() -> bool: return casts.size() > n0, 1.5) < INF
		var ended := await _until(func() -> bool: return p.has_meta(&"bend_dash_end"), 2.0) < INF
		await _tap(3)
		c.speed_override = 0.0
		var b2 := await _begin("fire_wall")
		await _ticks(2)
		var f0 := c.fill
		await _ticks(18)
		var rate := c.fill - f0
		c.held_override = false
		c.speed_override = null
		step[id] = [began and cast_ok and ended and b2, rate]
	_expect(bool(step[""][0]) and bool(step["fire.passive.dancing_feet"][0]), "a real Step cast and ended, the Fire Wall locked after it")
	_expect(absf(float(step[""][1]) / float(cl[0]) - 1.0) < 0.03 and absf(float(step["fire.passive.dancing_feet"][1]) / float(cl[0]) - 1.15) < 0.03,
			"Dancing Feet: within 0.6 s of a Step's end the fill x%.2f (Classic x%.2f)" % [float(step["fire.passive.dancing_feet"][1]) / float(cl[0]),
			float(step[""][1]) / float(cl[0])])


# ---------------------------------------------------------------- a bot wearing them
func _bot() -> void:
	await _calm()
	var nb: NpcBending = (foe.get(&"brain") as NpcBrain).bending if foe.get(&"brain") != null else null
	_expect(nb != null, "the foe has a bending mind")
	if nb == null:
		return
	# (its own begin and release, as its tick calls them: the lock full, let go at once and late)
	var got := {}
	for id: String in ["", "fire.punch.rhythm"]:
		_wear(id, foe)
		if foe.has_meta(FireTalents.HEAD_META):
			foe.remove_meta(FireTalents.HEAD_META)
		nb.begin("fire_blast", "punch")
		var f0 := nb.fill
		nb.lock_t = nb.lock_s
		nb._release()
		nb.begin("fire_blast", "punch")
		var f1 := nb.fill
		nb.lock_t = nb.lock_s + 0.4
		nb._release()
		nb.begin("fire_blast", "punch")
		got[id] = [f0, f1, nb.fill]
		nb._cancel()
		await _ticks(30)
	_expect(absf(float(got[""][1])) < 0.02 and absf(float(got["fire.punch.rhythm"][0])) < 0.02 and absf(float(got["fire.punch.rhythm"][1]) - 0.3) < 0.02
			and absf(float(got["fire.punch.rhythm"][2])) < 0.02,
			"a bot wearing Two-Hand Rhythm: its Punch let go at full, the next starts %.2f full; let go 0.4 s late %.2f (Classic %.2f)"
			% [got["fire.punch.rhythm"][1], got["fire.punch.rhythm"][2], got[""][1]])
	# Hot Feet on a bot: the fill its tick multiplies by, standing still
	_wear("fire.passive.hot_feet", foe)
	var hf := FireTalents.fill_mult(foe, false)
	BendLoadout.clear(foe)
	_expect(is_equal_approx(hf, 0.9) and is_equal_approx(FireTalents.fill_mult(foe, false), 1.0),
			"a bot wearing Hot Feet: its fill standing still x%.2f (Classic x%.2f)" % [hf, FireTalents.fill_mult(foe, false)])
