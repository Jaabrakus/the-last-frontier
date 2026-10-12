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
##   Crescent Burn     a real High Kick's crescent leaves a 2 m patch of flame for 1.5 s where it ends: a foe standing in it
##                     gains 1% each 0.5 s, 3 at most; jumped (his feet 1 m up) nothing; its owner never; Classic none
##   Ignite Step       a real Step leaves a 2 m line of fire for 1.5 s: the same ticks; Classic none
##   Blazing Fireball  a grown Punch ending on the deck before the foe bursts 2 m: he gains its 6%, knocked away; a wall
##                     between covers him; the core spares the burst; Classic no burst
##   Scald             his Punch through steam (and his Breath over it) makes the cloud scald 1.5 s: a foe in it gains 1%
##                     each 0.5 s, 3 at most; Classic none
##   Curved Curtain    a real Fire Wall: 4 pieces along a 120 deg arc, 5 m of curtain round the point aimed at, 4 s (Classic:
##                     one 4 m wall, 5 s); a piece burns who walks in; the next wall ends them all
##   Forked Lightning  a strike that misses: its fork makes the puddle within 6 m of its line live 0.5 s: the foe in it takes
##                     half the strike's % (11 of 22), no launch; its caster in live water too; Classic nothing
##   Hold the Storm    the foe's Lightning perfectly Parried with E held: nothing goes back while E is held; let go, it strikes
##                     him at x1.2 (as Classic's at once); held past 0.8 s it leaves by itself; his fire sent back x1.1 (1.2)
##   Magma (the set)   a real Kick's wave dying on a wall leaves a 1.5 m seam for 3 s: a foe on it gains 1% each 0.5 s, 4 at
##                     most; never its owner; two at once (a third cools the oldest); water over it leaves a loose obsidian
##                     stone of his; the Axe Kick's wave too; a bot wearing it the same; Classic none
##   Lava Kick         the Kick's last 4 m one seam; its knock base 10.5 (9.5: the tree's from fixed to today's data)
##   Magma Fist        a seam where the grown Punch lands; its core 22% (20)
##   Magma Landing     a real Jets dash: a 2 m seam where it lands; with the set alone none
##   Forge             standing on his own seam his fill x1.15; his seams last 2.5 s (3)
##   Cauterize         Patch's key tapped twice readies Cauterize (Classic: Patch again); a real Cauterize with 20% fresh
##                     leaves 10% (2% cost, 12% back), with 6% fresh leaves 2% (the cost is never taken back); its lock 1.2 s,
##                     his Patch's 1.7 s (Classic 1.5 s)
##   Flashfire         gas (the Sulphur set's cloud, earth's: a round BendZone of kind gas, made here as earth's lane will
##                     make it) lit by fire burns (anyone's fire: the set's rule): a real Embers cast through a cloud round the
##                     foe bursts it, the burst his: 8% and a set 8 m/s (Classic 6 and 6); 1 m farther (a foe 3 m from a 2.5 m
##                     cloud's middle burnt only worn); never on the lighter standing in it; whoever made the gas, the lighter
##                     owns it; it stales as the Embers; his Embers 6% (7); the Breath and a fire wall light it too, water does
##                     not; a bot wearing it lights the player's gas bigger and wants its Embers at a foe in gas
##   each              resolves whole and is live (BendLoadout.why_not), and Classic (nothing worn) reads the game's own
## Last line "TALENTS FIRE PASSED (n checks)" or "... FAILED".

const BUILT := ["fire.parry.hot_hands", "fire.punch.rhythm", "fire.kick.chain", "fire.lightning.grounded",
		"fire.passive.dancing_feet", "fire.passive.hot_feet", "fire.fireball.blazing", "fire.highkick.crescent_burn",
		"fire.step.ignite", "fire.breath.scald", "fire.wall.curved", "fire.lightning.forked", "fire.parry.hold_storm",
		"fire.set.magma", "fire.magma.fist", "fire.magma.lava_kick", "fire.magma.landing", "fire.magma.forge",
		"fire.slot.cauterize", "fire.embers.flashfire"]
const WATCHDOG_S := 460.0

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
	# (a user arg only=<part> plays that part alone, e.g. only=flashfire: a quicker run while working on one talent)
	var only := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5)
	for part: String in ["hot_hands", "rhythm", "chain", "grounded", "feet", "bot", "crescent", "ignite", "blazing", "scald",
			"curved", "forked", "hold_storm", "magma", "magma_nodes", "cauterize", "flashfire"]:
		if only == "" or only == part:
			await call("_" + part)
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


# ---------------------------------------------------------------- floor fire
## The matter ticks (`tag`) on `n` since `t0` (BendR3.hits_log).
func _ticks_on(n: Node, tag: String, t0: float) -> int:
	var k := 0
	for h: Dictionary in BendR3.hits_log:
		if h.n == n and String(h.tag) == tag and float(h.at) >= t0:
			k += 1
	return k


## The newest matter zone (a tick_tag) of `owner`'s.
func _matter_of(owner: Node) -> BendZone:
	var out: BendZone = null
	for z in get_nodes_in_group(BendZone.GROUP):
		if z is BendZone and (z as BendZone).owner_node == owner and (z as BendZone).tick_tag != "" and not z.is_queued_for_deletion():
			out = z as BendZone
	return out


## The foe pinned at `at` for `s` s: the matter ticks he took and his % gained.
func _foe_in(at: Vector3, s: float) -> Array:
	var keep := _foe_at
	_foe_at = at
	foe.global_position = at
	var rr := RingRules.current()
	var p0 := rr.pct_of(foe)
	var t0 := BendStatus.now()
	await _secs(s)
	var out := [_ticks_on(foe, "matter/burn", t0), rr.pct_of(foe) - p0]
	_foe_at = keep
	return out


func _crescent() -> void:
	var got := {}
	for id: String in ["", "fire.highkick.crescent_burn"]:
		await _calm()
		_wear(id)
		await _tap(1)
		await _tap(1)
		var hk := c.readied_spell == "fire_kick" and c.mode_of("fire_kick") == "high_kick"
		var n0 := casts.size()
		var began := await _begin("fire_kick")
		var cast_ok := await _cast_at(0.0)
		await _until(func() -> bool: return _matter_of(p) != null, 1.5)
		var z := _matter_of(p)
		got[id] = {"ok": hk and began and cast_ok and casts.size() > n0, "z": z != null}
		if z == null:
			continue
		var zd := {"r": z.radius, "life": z.life_s, "cap": z.tick_cap, "tag": z.tick_tag}
		var on := await _foe_in(z.global_position + Vector3(0.6, 0.0, 0.0), 1.6)
		got[id]["zd"] = zd
		got[id]["ticks"] = on
	_expect(bool(got[""].ok) and bool(got["fire.crescent_burn" if false else "fire.highkick.crescent_burn"].ok), "High Kick: real casts")
	var cb: Dictionary = got["fire.highkick.crescent_burn"]
	_expect(not bool(got[""].z), "Crescent Burn: not worn, the crescent leaves no flame")
	var zd: Dictionary = cb.get("zd", {})
	_expect(bool(cb.z) and is_equal_approx(float(zd.get("r", 0.0)), 2.0) and is_equal_approx(float(zd.get("life", 0.0)), 1.5)
			and int(zd.get("cap", 0)) == 3 and String(zd.get("tag", "")) == "matter/burn",
			"Crescent Burn: the crescent lands as a patch of flame %.1f m, %.1f s, %d ticks at most (%s)" % [float(zd.get("r", 0.0)),
			float(zd.get("life", 0.0)), int(zd.get("cap", 0)), String(zd.get("tag", ""))])
	var tk: Array = cb.get("ticks", [0, 0.0])
	var d := float(RingRules.class_of("matter/burn").d) * RingRules.stock_num("pct_scale", 1.0)
	_expect(int(tk[0]) == 3 and absf(float(tk[1]) - 3.0 * d) < 0.05,
			"Crescent Burn: a foe who stays in it gains %.2f%% in %d ticks (1%% each 0.5 s, 3%% at most)" % [tk[1], tk[0]])
	# jumped (his feet 1 m over it) and its own caster: nothing
	await _calm()
	_wear("fire.highkick.crescent_burn")
	var probe := p.global_position + (-p.global_basis.z) * 4.0
	var pz := FireTalents.patch(p, probe, 2.0, 1.5, "burn", "matter/burn", 3, "fire_kick")
	var made := pz != null
	var pat := pz.global_position if made else probe
	var up := await _foe_in(pat + Vector3.UP * 1.0, 1.0)
	var pz2 := FireTalents.patch(p, probe, 2.0, 1.5, "burn", "matter/burn", 3, "fire_kick")
	RingLevel.place(p, Transform3D(p.global_basis, pat))
	var t0 := BendStatus.now()
	await _secs(1.0)
	_expect(made and pz2 != null and int(up[0]) == 0 and _ticks_on(p, "matter/burn", t0) == 0,
			"floor fire: a foe whose feet are 1 m over it takes no tick (%d), its own caster none (%d)" % [up[0], _ticks_on(p, "matter/burn", t0)])


func _ignite() -> void:
	var got := {}
	for id: String in ["", "fire.step.ignite"]:
		await _calm()
		_wear(id)
		var n0 := casts.size()
		await _tap(2)
		var cast_ok := await _until(func() -> bool: return casts.size() > n0, 1.5) < INF
		await _ticks(3)
		var z := _matter_of(p)
		got[id] = {"ok": cast_ok, "z": z != null}
		if z != null:
			got[id]["zd"] = {"len": z.size.z, "life": z.life_s, "cap": z.tick_cap, "tag": z.tick_tag, "kind": z.kind}
			got[id]["ticks"] = await _foe_in(z.global_position, 1.6)
	var ig: Dictionary = got["fire.step.ignite"]
	var zd: Dictionary = ig.get("zd", {})
	_expect(bool(got[""].ok) and bool(ig.ok), "Step: real casts")
	_expect(not bool(got[""].z) and bool(ig.z) and is_equal_approx(float(zd.get("len", 0.0)), 2.0) and is_equal_approx(float(zd.get("life", 0.0)), 1.5)
			and int(zd.get("cap", 0)) == 3 and String(zd.get("kind", "")) == "burn",
			"Ignite Step: the Step leaves a %.1f m line of fire for %.1f s (Classic none)" % [float(zd.get("len", 0.0)), float(zd.get("life", 0.0))])
	var tk: Array = ig.get("ticks", [0, 0.0])
	_expect(int(tk[0]) == 3, "Ignite Step: a foe standing in it gains %d ticks (%.2f%%), 3 at most" % [tk[0], tk[1]])


## A grown Punch of the player's (the cast's own spec and info) launched from his chest at `to`.
func _fireball_at(to: Vector3, from := Vector3.INF) -> BendBolt:
	var spec: Dictionary = ((SwayMoves.move("fire_blast").bend as Dictionary).punch as Dictionary).duplicate(true)
	spec = BendLoadout.spec(p, "fire_blast", "punch", spec)
	spec.merge(spec.grow as Dictionary, true)
	spec["_info"] = BendR3.info_for(bc, "fire_blast", "punch", true, spec)
	if from == Vector3.INF:
		from = p.global_position + Vector3.UP * 1.3
	return BendBolt.launch(p, from, (to - from).normalized(), spec)


func _blazing() -> void:
	var rr := RingRules.current()
	var got := {}
	for id: String in ["", "fire.fireball.blazing"]:
		await _calm()
		_wear(id)
		rr._stale.clear()
		var fp := _foe_at
		var flat := Vector3(fp.x - p.global_position.x, 0.0, fp.z - p.global_position.z).normalized()
		var ground := FormEffects.ground_at(p, fp - flat * 1.3)
		var p0 := rr.pct_of(foe)
		var t0 := BendStatus.now()
		var b := _fireball_at(ground, ground + Vector3.UP * 3.0)       # (it lands on the deck from above)
		await _until(func() -> bool: return not is_instance_valid(b), 2.0)
		await _ticks(3)
		var hits := BendR3.hits_log.filter(func(h: Dictionary) -> bool: return h.n == foe and float(h.at) >= t0)
		got[id] = [rr.pct_of(foe) - p0, hits.map(func(h: Dictionary) -> String: return String(h.tag))]
	var bl: Array = got["fire.fireball.blazing"]
	var d := 6.0 * RingRules.stock_num("pct_scale", 1.0)
	_expect(float(got[""][0]) < 0.01 and absf(float(bl[0]) - d) < 0.05 and (bl[1] as Array) == ["fire_blast/punch.grown+burst"],
			"Blazing Fireball: a Fireball on the deck 1.3 m before him bursts: he gains %.2f%% (%s; Classic %.2f%%)" % [bl[0], bl[1], got[""][0]])
	# a wall between: the burst stays on its side
	await _calm()
	_wear("fire.fireball.blazing")
	var fp2 := _foe_at
	var flat2 := Vector3(fp2.x - p.global_position.x, 0.0, fp2.z - p.global_position.z).normalized()
	var wat := FormEffects.ground_at(p, fp2 - flat2 * 1.0)
	var w := BendEffects._wall(p, Transform3D(Basis.looking_at(-flat2, Vector3.UP), wat), "stone", 6.0, 3.0)
	await _secs(1.0)
	var p1 := rr.pct_of(foe)
	var b2 := _fireball_at(wat + Vector3.UP * 1.0)
	await _until(func() -> bool: return not is_instance_valid(b2), 2.0)
	await _ticks(3)
	_expect(is_instance_valid(w) and rr.pct_of(foe) - p1 < 0.01, "Blazing Fireball: into a wall 1 m before him, the burst stays on its side (he gains %.2f%%)" % (rr.pct_of(foe) - p1))
	if is_instance_valid(w):
		w.queue_free()
	# the core: his class 16 (from 20); the one it strikes takes no burst
	var core := BendLoadout.hit_class(p, RingRules.class_of("fire_blast/punch.grown"))
	await _calm()
	_wear("fire.fireball.blazing")
	rr._stale.clear()
	var t1 := BendStatus.now()
	var b3 := _fireball_at(_foe_at + Vector3.UP * 1.0)
	await _until(func() -> bool: return not is_instance_valid(b3), 2.0)
	await _ticks(3)
	var tags: Array = BendR3.hits_log.filter(func(h: Dictionary) -> bool: return h.n == foe and float(h.at) >= t1).map(func(h: Dictionary) -> String: return String(h.tag))
	_expect(is_equal_approx(float(core.get("d", 0.0)), 16.0) and tags == ["fire_blast/punch.grown"],
			"Blazing Fireball: its core adds %.0f%% (from 20); the one it strikes takes the core only (%s)" % [float(core.get("d", 0.0)), tags])


func _scald() -> void:
	var got := {}
	for id: String in ["", "fire.breath.scald"]:
		await _calm()
		_wear(id)
		var st := BendBolt.steam(foe, _foe_at)
		await _ticks(2)
		var from := _foe_at + Vector3.UP * 1.2 + (p.global_position - _foe_at).normalized() * 4.0
		var spec: Dictionary = ((SwayMoves.move("fire_blast").bend as Dictionary).punch as Dictionary).duplicate()
		spec["_info"] = BendR3.info_for(bc, "fire_blast", "punch", false, spec)
		var t0 := BendStatus.now()
		BendBolt.launch(p, from, (_foe_at + Vector3.UP * 1.0 - from).normalized(), spec)
		await _secs(0.3)
		var scalded := is_instance_valid(st) and st.has_meta(&"talent_scalded")
		await _secs(1.3)
		got[id] = [_ticks_on(foe, "matter/burn", t0), scalded]
	_expect(int(got[""][0]) == 0 and not bool(got[""][1]) and int(got["fire.breath.scald"][0]) == 3 and bool(got["fire.breath.scald"][1]),
			"Scald: his Punch through steam: a foe in the cloud gains %d ticks, 3 at most (Classic %d)" % [got["fire.breath.scald"][0], got[""][0]])
	# the Breath over steam before him
	var br := {}
	for id: String in ["", "fire.breath.scald"]:
		await _calm()
		_wear(id)
		var fwd := -p.global_basis.z
		fwd.y = 0.0
		var st2 := BendBolt.steam(p, p.global_position + fwd.normalized() * 3.0)
		await _ticks(2)
		BendEffects.apply(bc, "fire_breath", "breath", ((SwayMoves.move("fire_breath").bend as Dictionary).breath as Dictionary))
		await _ticks(3)
		br[id] = is_instance_valid(st2) and st2.has_meta(&"talent_scalded")
	_expect(not bool(br[""]) and bool(br["fire.breath.scald"]), "Scald: his Breath over a steam cloud makes it scald (Classic: steam)")
	var cls := BendLoadout.hit_class(p, RingRules.class_of("fire_breath/breath"))
	_expect(is_equal_approx(float(cls.get("d", 0.0)), 11.0), "Scald: his Breath adds %.0f%% (from 12)" % float(cls.get("d", 0.0)))


# ---------------------------------------------------------------- Curved Curtain, Forked Lightning, Hold the Storm
func _walls_of(owner: Node) -> Array:
	return get_nodes_in_group(BendZone.GROUP).filter(func(z: Node) -> bool:
		return z is BendZone and (z as BendZone).owner_node == owner and (z as BendZone).kind == "fire_wall" and not z.is_queued_for_deletion())


func _curved() -> void:
	var got := {}
	for id: String in ["", "fire.wall.curved"]:
		await _calm()
		_wear(id)
		await _tap(3)
		var began := await _begin("fire_wall")
		var cast_ok := await _cast_at(0.0)
		await _ticks(4)
		var ws := _walls_of(p)
		var pieces: Array = []
		for w: BendZone in ws:
			pieces.append({"at": w.global_position, "way": w.way, "w": w.size.x, "life": w.life_s})
		got[id] = {"ok": began and cast_ok, "pieces": pieces}
		if id != "" and not ws.is_empty():
			# a piece burns who walks in (its entry pop); the next wall ends every piece
			var t0 := BendStatus.now()
			await _foe_in((ws[0] as BendZone).global_position, 0.6)
			got[id]["burned"] = BendR3.hits_log.filter(func(h: Dictionary) -> bool:
				return h.n == foe and float(h.at) >= t0 and String(h.tag).begins_with("fire_wall/")).size()
			await _secs(0.3)
			await _tap(3)
			await _begin("fire_wall")
			await _cast_at(0.0)
			await _ticks(4)
			got[id]["left"] = ws.filter(func(w: Node) -> bool: return is_instance_valid(w) and not w.is_queued_for_deletion()).size()
			got[id]["now"] = _walls_of(p).size()
	var c0: Array = got[""].pieces
	var cv: Array = got["fire.wall.curved"].pieces
	_expect(bool(got[""].ok) and bool(got["fire.wall.curved"].ok), "Fire Wall: real casts")
	_expect(c0.size() == 1 and is_equal_approx(float(c0[0].w), 4.0) and is_equal_approx(float(c0[0].life), 5.0),
			"Fire Wall (Classic): one wall %.1f m, %.1f s" % [float(c0[0].w) if c0.size() > 0 else -1.0, float(c0[0].life) if c0.size() > 0 else -1.0])
	var r := FireTalents.ARC_M / deg_to_rad(FireTalents.ARC_DEG)
	var ok_arc := cv.size() == 4
	var span := 0.0
	var curtain := 0.0
	if ok_arc:
		var c1: Vector3 = (cv[0].at as Vector3) - (cv[0].way as Vector3) * r
		for pc: Dictionary in cv:
			var cc: Vector3 = (pc.at as Vector3) - (pc.way as Vector3) * r
			ok_arc = ok_arc and Vector2(cc.x - c1.x, cc.z - c1.z).length() < 0.05 and is_equal_approx(float(pc.life), 4.0)
			curtain += float(pc.w)
		for i in cv.size():
			for j in cv.size():
				span = maxf(span, rad_to_deg((cv[i].way as Vector3).angle_to(cv[j].way as Vector3)))
	_expect(ok_arc and absf(span + 30.0 - 120.0) < 1.0 and absf(curtain - 4 * 0.15 - 2.0 * r * sin(deg_to_rad(15.0)) * 4.0) < 0.05,
			"Curved Curtain: %d pieces round one point, spanning %.0f deg edge to edge, %.2f m of curtain, 4 s" % [cv.size(), span + 30.0, curtain - 4 * 0.15])
	_expect(int(got["fire.wall.curved"].get("burned", 0)) >= 1, "Curved Curtain: a piece burns who walks in (%d hits)" % int(got["fire.wall.curved"].get("burned", 0)))
	_expect(int(got["fire.wall.curved"].get("left", -1)) == 0 and int(got["fire.wall.curved"].get("now", -1)) == 4,
			"Curved Curtain: the next wall ends every piece of the last (%d left, %d now)" % [int(got["fire.wall.curved"].get("left", -1)), int(got["fire.wall.curved"].get("now", -1))])


## A Lightning strike of `by`'s from his chest along `dir` (its spec as cast for him, no flash: it strikes at once).
func _strike(by: Node3D, dir: Vector3) -> Dictionary:
	var spec: Dictionary = ((SwayMoves.move("fire_arc").bend as Dictionary).lightning as Dictionary).duplicate()
	spec = BendLoadout.spec(by, "fire_arc", "lightning", spec)
	spec["flash_s"] = 0.0
	spec["_info"] = BendR3.info_for(by, "fire_arc", "lightning", false, spec)
	spec["_lock_s"] = BendEffects.lock_of("fire_arc", "lightning")
	var from := NpcSenses.chest_of(by)
	BendEffects.record(by, {"do": "lightning"})
	BendEffects.lightning(by, {"from": from, "dir": dir.normalized(), "flat": Vector3(dir.x, 0.0, dir.z).normalized()}, spec)
	return BendEffects.last_of(by)


func _forked() -> void:
	var rr := RingRules.current()
	var got := {}
	for id: String in ["", "fire.lightning.forked"]:
		await _calm()
		_wear(id)
		rr._stale.clear()
		var pud := BendZone.make(foe, "puddle", FormEffects.ground_at(foe, _foe_at), {"radius_m": 1.6, "life_s": 6.0}, Vector3.FORWARD)
		var to_foe := Vector3(_foe_at.x - p.global_position.x, 0.0, _foe_at.z - p.global_position.z).normalized()
		var p0 := rr.pct_of(foe)
		var t0 := BendStatus.now()
		var rec := _strike(p, to_foe.rotated(Vector3.UP, deg_to_rad(28.0)))
		await _secs(0.7)
		var tags: Array = BendR3.hits_log.filter(func(h: Dictionary) -> bool: return h.n == foe and float(h.at) >= t0).map(func(h: Dictionary) -> String: return String(h.tag))
		got[id] = [rr.pct_of(foe) - p0, tags, int(rec.get("hit", -1))]
		if is_instance_valid(pud):
			pud.queue_free()
	var d := 0.5 * 22.0 * RingRules.stock_num("pct_scale", 1.0)
	var fk: Array = got["fire.lightning.forked"]
	_expect(int(got[""][2]) == 0 and int(fk[2]) == 0, "Lightning: the strike misses the foe (hit %d, %d)" % [got[""][2], fk[2]])
	_expect(float(got[""][0]) < 0.01 and absf(float(fk[0]) - d) < 0.05 and (fk[1] as Array) == ["reaction/live"],
			"Forked Lightning: the fork makes his puddle live: he takes %.2f%% (%s; half the strike's 22%% is %.2f; Classic %.2f%%)" % [fk[0], fk[1], d, got[""][0]])
	var cls := BendLoadout.hit_class(p, RingRules.class_of("fire_arc/lightning"))
	_expect(is_equal_approx(float(cls.get("d", 0.0)), 22.0), "Forked Lightning: the strike adds %.0f%% (from 25)" % float(cls.get("d", 0.0)))
	# its caster in live water: anyone in it
	await _calm()
	_wear("fire.lightning.forked")
	rr._stale.clear()
	var own := BendZone.make(foe, "puddle", FormEffects.ground_at(p, p.global_position), {"radius_m": 1.6, "life_s": 6.0}, Vector3.FORWARD)
	var pp0 := rr.pct_of(p)
	var away := Vector3(p.global_position.x - _foe_at.x, 0.0, p.global_position.z - _foe_at.z).normalized()
	_strike(p, away)
	await _secs(0.7)
	_expect(absf(rr.pct_of(p) - pp0 - d) < 0.05, "Forked Lightning: its caster standing in the water it makes live takes it too (%.2f%%)" % (rr.pct_of(p) - pp0))
	if is_instance_valid(own):
		own.queue_free()


func _back_hits(t0: float) -> int:
	return BendR3.hits_log.filter(func(h: Dictionary) -> bool: return h.n == foe and float(h.at) >= t0 and String(h.tag) == "fire_arc/lightning.return").size()


func _hold_storm() -> void:
	var rr := RingRules.current()
	var got := {}
	for id: String in ["", "fire.parry.hold_storm", "past"]:
		await _calm()
		_wear("fire.parry.hold_storm" if id == "past" else id)
		rr._stale.clear()
		c.guard_override = true
		await _until(func() -> bool: return _zone_of(p, "parry") != null, 1.0)
		var to_p := (p.global_position + Vector3.UP * 1.2) - NpcSenses.chest_of(foe)
		var p0 := rr.pct_of(foe)
		var t0 := BendStatus.now()
		_strike(foe, to_p)
		await _ticks(3)
		var at_once := _back_hits(t0)
		await _secs(0.4)
		var while_held := _back_hits(t0)
		if id == "past":
			await _secs(0.6)
		var before_let_go := _back_hits(t0)
		c.guard_override = false
		await _ticks(4)
		got[id] = [at_once, while_held, before_let_go, _back_hits(t0), rr.pct_of(foe) - p0]
	var c0: Array = got[""]
	var hs: Array = got["fire.parry.hold_storm"]
	var past: Array = got["past"]
	_expect(int(c0[0]) == 1, "Parry (Classic): the foe's Lightning goes back at once (%d)" % c0[0])
	_expect(int(hs[0]) == 0 and int(hs[1]) == 0 and int(hs[3]) == 1,
			"Hold the Storm: held in his arms while E is held (%d, %d), it strikes the foe when he lets go (%d)" % [hs[0], hs[1], hs[3]])
	_expect(absf(float(hs[4]) - float(c0[4])) < 0.05 and float(c0[4]) > 1.0,
			"Hold the Storm: the held Lightning strikes at x1.2 as before (%.2f%%, Classic %.2f%%)" % [hs[4], c0[4]])
	_expect(int(past[1]) == 0 and int(past[2]) == 1, "Hold the Storm: held past 0.8 s it leaves by itself (%d at 0.4 s, %d at 1.0 s)" % [past[1], past[2]])
	# his fire sent back: x1.1 (Classic x1.2)
	var rm := {}
	for id: String in ["", "fire.parry.hold_storm"]:
		await _calm()
		_wear(id)
		c.guard_override = true
		await _until(func() -> bool: return _zone_of(p, "parry") != null, 1.0)
		var b := _foe_punch(2.0)
		await _ticks(3)
		rm[id] = float(b.info.get("ret_mult", -1.0)) if is_instance_valid(b) else -1.0
		c.guard_override = false
	_expect(is_equal_approx(float(rm[""]), 1.2) and is_equal_approx(float(rm["fire.parry.hold_storm"]), 1.1),
			"Hold the Storm: a perfect Parry sends fire back x%.1f (Classic x%.1f)" % [rm["fire.parry.hold_storm"], rm[""]])


# ---------------------------------------------------------------- the Magma set
## `ids` worn together by `who` (the player by default) as a fire caster.
func _wear_all(ids: Array, on: Node = null) -> void:
	var who: Node = p if on == null else on
	BendLoadout.clear(who)
	var ov := BendLoadout.wear(who, ids, "", "fire")
	if (ov.ids as Array).size() != ids.size():
		_expect(false, "%s worn (refused: %s)" % [ids, str(ov.refused)])


func _seams_of(owner: Node) -> Array:
	return FireTalents.seams_of(owner)


## A stone wall `ahead` m along `dir` from `from` (on the deck), across the way.
func _wall_at(from: Vector3, dir: Vector3, ahead: float) -> FormRaised:
	var at := FormEffects.ground_at(p, from + dir * ahead)
	return BendEffects._wall(p, Transform3D(Basis.looking_at(-dir, Vector3.UP), at), "stone", 8.0, 4.0)


## A real Kick (key 2) let go at its click into a wall `ahead` m before him: the seams of his after it (and the wall's place).
func _kick_into_wall(ahead := 5.0) -> Array:
	await _calm()
	var dir := bc.facing()
	var w := _wall_at(p.global_position, dir, ahead)
	await _secs(0.8)
	await _tap(1)
	var began := await _begin("fire_kick")
	var cast_ok := await _cast_at(0.0)
	await _secs(1.0)
	var seams := _seams_of(p)
	var out := [began and cast_ok, seams.size(), seams[0] if not seams.is_empty() else null, w.global_position if is_instance_valid(w) else Vector3.INF]
	return out


func _magma() -> void:
	# Classic: the Kick into a wall leaves nothing
	_wear("")
	var c0: Array = await _kick_into_wall()
	_wear_all(["fire.set.magma"])
	var m0: Array = await _kick_into_wall()
	_expect(bool(c0[0]) and bool(m0[0]), "Kick: real casts into a wall")
	var sz: BendZone = m0[2]
	var wall_at: Vector3 = m0[3]
	_expect(int(c0[1]) == 0 and int(m0[1]) == 1 and sz != null and sz.kind == "seam" and is_equal_approx(sz.size.x, 1.5)
			and is_equal_approx(sz.life_s, 3.0) and sz.tick_cap == 4 and sz.tick_tag == "matter/magma"
			and Vector2(sz.global_position.x - wall_at.x, sz.global_position.z - wall_at.z).length() < 1.6,
			"Magma: the Kick's wave dying on a wall leaves a seam %.1f m wide, %.1f s, 4 ticks at most, before the wall (Classic %d)"
			% [sz.size.x if sz else -1.0, sz.life_s if sz else -1.0, int(c0[1])])
	if sz == null:
		return
	var seam_at := sz.global_position
	var on := await _foe_in(seam_at, 2.6)
	_expect(_ticks_on(foe, "matter/magma", BendStatus.now() - 2.7) == 4, "Magma: a foe on the seam gains %d ticks (%.2f%%), 4 at most" % [_ticks_on(foe, "matter/magma", BendStatus.now() - 2.7), on[1]])
	# its owner never; two at once (a third cools the oldest)
	await _calm()
	_wear_all(["fire.set.magma"])
	var a := FireTalents.seam(p, p.global_position, Vector3.FORWARD, {"width_m": 1.5, "thick_m": 1.5})
	var t0 := BendStatus.now()
	await _secs(1.0)
	var own := _ticks_on(p, "matter/magma", t0)
	var b := FireTalents.seam(p, p.global_position + Vector3(0, 0, 3), Vector3.FORWARD, {"width_m": 1.5, "thick_m": 1.5})
	await _ticks(2)
	var c := FireTalents.seam(p, p.global_position + Vector3(0, 0, -3), Vector3.FORWARD, {"width_m": 1.5, "thick_m": 1.5})
	await _ticks(2)
	var mine := _seams_of(p)
	_expect(own == 0 and mine.size() == 2 and not mine.has(a) and mine.has(b) and mine.has(c),
			"Magma: his own seam never burns him (%d); two at once, a third cools the oldest (%d standing)" % [own, mine.size()])
	# water over it: a loose obsidian stone of his
	var loose0 := FormStone.loose_of(p).size()
	var bz: BendZone = c
	var wspec := {"do": "bolt", "kind": "water", "mps": 20.0, "damage": 4.0, "knock_mps": 1.0, "radius_m": 0.2, "range_m": 6.0}
	BendBolt.launch(foe, bz.global_position + Vector3.UP * 1.5, Vector3.DOWN, wspec)
	await _secs(0.5)
	var stones := FormStone.loose_of(p).filter(func(s: Node) -> bool: return s.has_meta(&"talent_obsidian"))
	_expect((not is_instance_valid(bz) or bz.is_queued_for_deletion()) and stones.size() >= 1 and FormStone.loose_of(p).size() > loose0,
			"Magma: water on a seam cools it to a loose obsidian stone of his (%d)" % stones.size())
	# the Axe Kick's wave into a wall: a seam too
	await _calm()
	_wear_all(["fire.set.magma"])
	var dir := bc.facing()
	var w := _wall_at(p.global_position, dir, 3.5)
	await _secs(0.8)
	var ws: Dictionary = ((((SwayMoves.move("fire_kick").bend as Dictionary).slam as Dictionary).wave) as Dictionary).duplicate()
	var wsp := BendLoadout.spec(p, "fire_kick", "slam", (SwayMoves.move("fire_kick").bend as Dictionary).slam as Dictionary)
	var winfo := BendR3.info_for(bc, "fire_kick", "slam", false, wsp)
	winfo["tag"] = String(winfo.tag) + "_wave"
	ws["_info"] = winfo
	ws["mps"] = float(((wsp.wave) as Dictionary).mps)
	var wb := BendBolt.launch(p, p.global_position + dir * 0.5, dir, ws)
	await _secs(0.8)
	_expect(_seams_of(p).size() == 1 and is_equal_approx(ws.mps, 14.2), "Magma: the Axe Kick's wave (%.1f m/s) dying on a wall leaves a seam too (%d)" % [ws.mps, _seams_of(p).size()])
	if is_instance_valid(w):
		w.queue_free()
	# a bot wearing the set: its own Kick's wave into a wall
	var nb: NpcBending = (foe.get(&"brain") as NpcBrain).bending if foe.get(&"brain") != null else null
	if nb != null:
		await _calm()
		_wear_all(["fire.set.magma"], foe)
		var to_p := Vector3(p.global_position.x - foe.global_position.x, 0.0, p.global_position.z - foe.global_position.z).normalized()
		var bw := BendEffects._wall(foe, Transform3D(Basis.looking_at(-to_p, Vector3.UP), FormEffects.ground_at(foe, foe.global_position + to_p * 4.0)), "stone", 8.0, 4.0)
		await _secs(0.8)
		nb.begin("fire_kick", "kick")
		nb.lock_t = nb.lock_s
		nb._release()
		await _secs(1.5)
		_expect(FireTalents.seams_of(foe).size() == 1, "Magma: a bot wearing the set leaves a seam where its Kick's wave dies (%d)" % FireTalents.seams_of(foe).size())
		nb._cancel()
		BendLoadout.clear(foe)
		if is_instance_valid(bw):
			bw.queue_free()


func _magma_nodes() -> void:
	# Lava Kick: the Kick's last 4 m one seam
	_wear_all(["fire.set.magma", "fire.magma.lava_kick"])
	var lk: Array = await _kick_into_wall(6.0)
	var lz: BendZone = lk[2]
	var cls := BendLoadout.hit_class(p, RingRules.class_of("fire_kick/kick"))
	_expect(lz != null and is_equal_approx(lz.size.z, 4.0) and is_equal_approx(lz.size.x, 1.5) and is_equal_approx(float(cls.get("base", 0.0)), 10.5),
			"Lava Kick: the wave's last %.1f m one seam; its knock base %.1f (9.5)" % [lz.size.z if lz else -1.0, float(cls.get("base", 0.0))])
	# Magma Fist: a seam where the grown Punch lands
	var fist := {}
	for ids: Array in [["fire.set.magma"], ["fire.set.magma", "fire.magma.fist"]]:
		await _calm()
		_wear_all(ids)
		var dir := bc.facing()
		var g := FormEffects.ground_at(p, p.global_position + dir * 4.0)
		var b := _fireball_at(g, g + Vector3.UP * 3.0)
		await _until(func() -> bool: return not is_instance_valid(b), 2.0)
		await _ticks(3)
		var s := _seams_of(p)
		fist[ids.size()] = [s.size(), (s[0] as BendZone).global_position.distance_to(g) if not s.is_empty() else -1.0]
	var fc := BendLoadout.hit_class(p, RingRules.class_of("fire_blast/punch.grown"))
	_expect(int(fist[1][0]) == 0 and int(fist[2][0]) == 1 and float(fist[2][1]) < 0.6 and is_equal_approx(float(fc.get("d", 0.0)), 22.0),
			"Magma Fist: a seam where the ball of magma lands (%d, %.2f m off; the set alone %d); its core %.0f%% (20)" % [fist[2][0], fist[2][1], fist[1][0], float(fc.get("d", 0.0))])
	# Magma Landing: a real Jets dash
	var land := {}
	for ids: Array in [["fire.set.magma"], ["fire.set.magma", "fire.magma.landing"]]:
		await _calm()
		_wear_all(ids)
		var n0 := casts.size()
		await _tap(2)
		await _tap(2)                       # (key 3 tapped twice: the Jets)
		var cast_ok := await _until(func() -> bool: return casts.size() > n0, 1.5) < INF
		var jets := cast_ok and String(casts[-1][0]) == "fire_jets"
		var ended := await _until(func() -> bool: return p.has_meta(&"bend_dash_end"), 3.0) < INF
		await _ticks(3)
		var s := _seams_of(p)
		land[ids.size()] = [jets and ended, s.size(), (s[0] as BendZone).radius if not s.is_empty() else -1.0,
				Vector2((s[0] as BendZone).global_position.x - p.global_position.x, (s[0] as BendZone).global_position.z - p.global_position.z).length() if not s.is_empty() else -1.0]
	_expect(bool(land[1][0]) and bool(land[2][0]), "Jets: real dashes cast and landed")
	_expect(int(land[1][1]) == 0 and int(land[2][1]) == 1 and is_equal_approx(float(land[2][2]), 1.0) and float(land[2][3]) < 1.0,
			"Magma Landing: a %.1f m seam where the Jets land (%.2f m from him; the set alone %d)" % [float(land[2][2]) * 2.0, land[2][3], land[1][1]])
	# Forge: his fill x1.15 on his own seam; his seams 2.5 s
	var forge := {}
	for ids: Array in [["fire.set.magma"], ["fire.set.magma", "fire.magma.forge"]]:
		await _calm()
		_wear_all(ids)
		var s := FireTalents.seam(p, FormEffects.ground_at(p, p.global_position), Vector3.FORWARD, {"width_m": 1.5, "thick_m": 1.5})
		await _tap(3)
		c.speed_override = 0.0
		var began := await _begin("fire_wall")
		await _ticks(2)
		var f0 := c.fill
		await _ticks(18)
		forge[ids.size()] = [began, c.fill - f0, s.life_s if s != null else -1.0]
		c.held_override = false
		c.speed_override = null
	_expect(absf(float(forge[2][1]) / maxf(float(forge[1][1]), 1e-4) - 1.15) < 0.03 and is_equal_approx(float(forge[2][2]), 2.5)
			and is_equal_approx(float(forge[1][2]), 3.0),
			"Forge: on his own seam the fill x%.2f; his seams last %.1f s (the set alone %.1f s)" % [float(forge[2][1]) / maxf(float(forge[1][1]), 1e-4), forge[2][2], forge[1][2]])


# ---------------------------------------------------------------- Cauterize
## Key 5 (Patch's) tapped `taps` times, then held until its lock casts (Patch goes at full): [mode, lock_s, % before, after].
func _patch_with(fresh: float, taps: int) -> Array:
	var rr := RingRules.current()
	await _calm()
	rr.reset_pct(p, 0.0)
	rr.add_pct(p, fresh, foe, "fire_blast/punch")
	for i in taps:
		await _tap(4)
	var md := c.mode_of("patch")
	c.speed_override = 0.0
	var n0 := casts.size()
	var began := await _begin("patch", 1.0)
	var lk := c.lock_s
	var before := rr.pct_of(p)
	await _until(func() -> bool: return casts.size() > n0, 3.0)
	await _ticks(3)
	c.held_override = false
	c.speed_override = null
	return [md if began else "none", lk, before, rr.pct_of(p)]


func _cauterize() -> void:
	_wear("")
	var cp: Array = await _patch_with(20.0, 2)
	_wear("fire.slot.cauterize")
	var wp: Array = await _patch_with(20.0, 1)
	var wc: Array = await _patch_with(20.0, 2)
	var w6: Array = await _patch_with(6.0, 2)
	_expect(String(cp[0]) == "patch" and String(wp[0]) == "patch" and String(wc[0]) == "cauterize",
			"Cauterize: Patch's key tapped twice readies it (%s; once %s; Classic twice %s)" % [wc[0], wp[0], cp[0]])
	_expect(is_equal_approx(float(cp[1]), 1.5) and is_equal_approx(float(wp[1]), 1.7) and is_equal_approx(float(wc[1]), 1.2),
			"Cauterize: its lock %.1f s, his Patch's %.1f s (Classic %.1f s)" % [wc[1], wp[1], cp[1]])
	_expect(absf(float(cp[3]) - 10.0) < 0.05 and absf(float(wc[3]) - 10.0) < 0.05 and absf(float(w6[3]) - 2.0) < 0.05,
			"Cauterize: with 20%% fresh it leaves %.1f%% (2%% cost, 12%% back; Classic Patch %.1f%%), with 6%% fresh %.1f%% (the cost kept)"
			% [wc[3], cp[3], w6[3]])
	# a bot wearing it: its Patch with 12% or more fresh goes as Cauterize (its own begin and release)
	var nb: NpcBending = (foe.get(&"brain") as NpcBrain).bending if foe.get(&"brain") != null else null
	if nb == null:
		return
	var rr := RingRules.current()
	var bot := {}
	for id: String in ["", "fire.slot.cauterize"]:
		await _calm()
		_wear(id, foe)
		rr.reset_pct(foe, 0.0)
		rr.add_pct(foe, 20.0, p, "fire_blast/punch")
		nb.begin("patch", "patch")
		var lk := nb.lock_s
		nb.lock_t = nb.lock_s
		nb._release()
		await _ticks(3)
		bot[id] = [String(BendEffects.last_of(foe).get("mode", "")), lk, rr.pct_of(foe), rr.fresh_pct(foe)]
		nb._cancel()
		BendLoadout.clear(foe)
	_expect(String(bot[""][0]) == "patch" and String(bot["fire.slot.cauterize"][0]) == "cauterize"
			and absf(float(bot["fire.slot.cauterize"][1]) / float(bot[""][1]) - 1.2 / 1.5) < 0.01
			and absf(float(bot["fire.slot.cauterize"][2]) - 10.0) < 0.05 and absf(float(bot["fire.slot.cauterize"][3]) - 8.0) < 0.05
			and absf(float(bot[""][3]) - 10.0) < 0.05,
			"a bot wearing Cauterize: with 20%% fresh its Patch goes as %s (lock x%.2f), leaving %.1f%% with %.1f%% fresh (Classic %s, %.1f fresh)"
			% [bot["fire.slot.cauterize"][0], float(bot["fire.slot.cauterize"][1]) / float(bot[""][1]), bot["fire.slot.cauterize"][2],
			bot["fire.slot.cauterize"][3], bot[""][0], bot[""][3]])


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


# ---------------------------------------------------------------- Flashfire (fire lighting gas)
var _dealt: Array = []                 ## [by, on, tag, %]: each % a hit added (RingRules.pct_dealt, its tag the rules' last_tag)
var _launch: Array = []                ## [on, launch v, by, tag] (RingRules.launched)


## A gas cloud of `owner`'s, `r` m round, on the deck under `at`: the Sulphur set's matter as earth's lane makes it (a round
## BendZone of kind gas; earth's set is not built in fire's lane). It lasts 6 s (the set's cloud 3 s): the test's time to cast.
func _gas(owner: Node3D, at: Vector3, r := 2.5) -> BendZone:
	return BendZone.make(owner, "gas", FormEffects.ground_at(owner, at), {"radius_m": r, "round": true, "life_s": 6.0}, Vector3.FORWARD)


## The player turned to face `at` (his yaw: the camera's and the crosshair's).
func _face(at: Vector3) -> void:
	var f := Vector3(at.x - p.global_position.x, 0.0, at.z - p.global_position.z).normalized()
	p.yaw = atan2(-f.x, -f.z)
	p.rotation.y = p.yaw


## The player's Embers as his cast makes them (his worn numbers, the cast's info and volley: BendEffects.apply's) from his chest,
## level, toward `to`, through the game's own volley (BendEffects.bolts): the test's aim, not the crosshair's.
func _embers_at(to: Vector3) -> void:
	var spec: Dictionary = ((SwayMoves.move("fire_jab").bend as Dictionary).embers as Dictionary).duplicate(true)
	spec = BendLoadout.spec(p, "fire_jab", "embers", spec)
	var info := BendR3.info_for(bc, "fire_jab", "embers", false, spec)
	info["volley_id"] = BendR3.new_volley()
	info["volley_n"] = int(spec.count)
	spec["_info"] = info
	spec["_lock_s"] = BendEffects.lock_of("fire_jab", "embers")
	var from := p.global_position + Vector3.UP * 1.3
	var dir := Vector3(to.x - from.x, 0.0, to.z - from.z).normalized()
	BendEffects.bolts(bc, {"from": from, "dir": dir, "flat": dir, "point": from + dir * 10.0, "target": null}, spec)


## The burst's share on `on` since record indices `d0` (_dealt) and `l0` (_launch): [its %, its launch's flat speed (-1 none), by].
func _burst_on(on: Node, d0: int, l0: int) -> Array:
	var pct := 0.0
	var by: Node = null
	for e: Array in _dealt.slice(d0):
		if e[1] == on and String(e[2]) == FireTalents.IGNITE_TAG:
			pct += float(e[3])
			by = e[0]
	var v := -1.0
	for e: Array in _launch.slice(l0):
		if e[0] == on and String(e[3]) == FireTalents.IGNITE_TAG:
			v = Vector2((e[1] as Vector3).x, (e[1] as Vector3).z).length()
	return [pct, v, by]


func _burnt(g: Variant) -> bool:
	return not is_instance_valid(g) or (g as Node).is_queued_for_deletion()


func _flashfire() -> void:
	var rr := RingRules.current()
	rr.pct_dealt.connect(func(by: Node, b: Node3D, delta: float) -> void:
		_dealt.append([by, b, String(rr._sk(b).get("last_tag", "")), delta]))
	rr.launched.connect(func(b: Node3D, v: Vector3, _s: float, by: Node, tag: String) -> void: _launch.append([b, v, by, tag]))
	var moments: Array = []
	var hl := RingHighlights.find(self)
	if hl != null:
		hl.moment.connect(func(kind: String, body: Node, _i: Dictionary) -> void: moments.append([kind, body]))
	var scale := RingRules.stock_num("pct_scale", 1.0)
	var k45 := cos(deg_to_rad(45.0))
	var home := _foe_at
	var ff_id := "fire.embers.flashfire"
	# a real Embers (the quick key, his crosshair on the foe 5.5 m before him) through a 2.5 m cloud of the foe's round the foe
	# (the quick key's spell is fire's own jab, Embers, for this run only: the settings file may hold another, never written)
	var q_was: Variant = c._quick.get("fire")
	c._quick["fire"] = {"id": "fire_jab", "mode": "embers"}
	var real := {}
	for id: String in ["", ff_id]:
		await _calm()
		_wear(id)
		rr._stale.clear()
		var fwd := -p.global_basis.z
		fwd.y = 0.0
		_foe_at = p.global_position + fwd.normalized() * 5.5
		await _ticks(2)
		_face(_foe_at)
		await _ticks(2)
		var gas := _gas(foe, _foe_at)
		var d0 := _dealt.size()
		var l0 := _launch.size()
		var m0 := moments.size()
		var n0 := casts.size()
		c.quick_override = true
		await _until(func() -> bool: return c.state == SwayCaster.State.FULL or casts.size() > n0, 1.5)
		c.quick_override = false
		var cast_ok := await _until(func() -> bool: return casts.size() > n0, 1.0) < INF
		await _secs(0.6)
		var b := _burst_on(foe, d0, l0)
		var called: bool = moments.slice(m0).any(func(m: Array) -> bool: return m[0] == "ignited" and m[1] == p)
		real[id] = {"cast": cast_ok and String(casts[-1][0]) == "fire_jab", "lit": _burnt(gas) and called, "pct": b[0], "v": b[1],
				"by": b[2], "called": called}
		c.quick_override = null
	if q_was is Dictionary:
		c._quick["fire"] = q_was
	else:
		c._quick.erase("fire")
	var r0: Dictionary = real[""]
	var r1: Dictionary = real[ff_id]
	_expect(bool(r0.cast) and bool(r1.cast) and bool(r0.lit) and bool(r1.lit),
			"Embers (the quick key) through a gas cloud round the foe: real casts, and the cloud burns, worn and not (fire lights gas)")
	_expect(absf(float(r1.pct) - 8.0 * scale) < 0.05 and absf(float(r0.pct) - 6.0 * scale) < 0.05,
			"Flashfire: the burst adds %.2f%% to the foe in it (Classic %.2f%%; 8 and 6 x pct_scale)" % [r1.pct, r0.pct])
	_expect(absf(float(r1.v) - 8.0 * k45) < 0.05 and absf(float(r0.v) - 6.0 * k45) < 0.05,
			"Flashfire: the burst knocks him a set 8 m/s at 45 deg (flat %.2f; Classic 6: %.2f)" % [r1.v, r0.v])
	_expect(r1.by == p and r0.by == p and bool(r1.called) and bool(r0.called),
			"the burst is the lighter's though the gas was the foe's, and called out IGNITED! (%s, %s)" % [str(r1.by), str(r0.by)])
	# 1 m farther: the foe 3 m from the middle of a 2.5 m cloud (outside it), the Embers through its middle and on past him
	var reach := {}
	for id: String in ["", ff_id]:
		await _calm()
		_wear(id)
		rr._stale.clear()
		var fwd := -p.global_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var mid := p.global_position + fwd * 5.0
		_foe_at = mid + fwd.cross(Vector3.UP).normalized() * 3.0
		await _ticks(2)
		var gas := _gas(foe, mid)
		var d0 := _dealt.size()
		var l0 := _launch.size()
		var t0 := BendStatus.now()
		_embers_at(mid + Vector3.UP * 1.3)
		await _secs(0.6)
		var b := _burst_on(foe, d0, l0)
		var embers_on := BendR3.hits_log.filter(func(h: Dictionary) -> bool: return (h.n == foe and float(h.at) >= t0
				and String(h.tag) == "fire_jab/embers")).size()
		reach[id] = {"lit": _burnt(gas), "pct": b[0], "embers": embers_on, "stale_e": rr.stale_count(p, "fire_jab/embers"),
				"stale_r": rr.stale_count(p, FireTalents.IGNITE_TAG)}
	var e0: Dictionary = reach[""]
	var e1: Dictionary = reach[ff_id]
	_expect(bool(e0.lit) and bool(e1.lit) and int(e0.embers) == 0 and int(e1.embers) == 0 and float(e0.pct) < 0.01
			and absf(float(e1.pct) - 8.0 * scale) < 0.05,
			"Flashfire: 1 m farther: a foe 3 m from the burning cloud's middle takes %.2f%% (Classic, 2.5 m: %.2f%%); no ember touched him"
			% [e1.pct, e0.pct])
	_expect(int(e1.stale_e) == 1 and int(e1.stale_r) == 0,
			"the burst stales as the Embers that lit it (his stale queue: %d Embers, %d bursts)" % [int(e1.stale_e), int(e1.stale_r)])
	# the lighter standing in the cloud he lights: the foe beside him burns, he never does
	await _calm()
	_wear(ff_id)
	rr._stale.clear()
	var fwd2 := -p.global_basis.z
	fwd2.y = 0.0
	var side2 := fwd2.normalized().cross(Vector3.UP).normalized()
	_foe_at = p.global_position + side2 * 1.5
	await _ticks(2)
	var gas2 := _gas(foe, p.global_position)
	var pp0 := rr.pct_of(p)
	var d2 := _dealt.size()
	var l2 := _launch.size()
	_embers_at(p.global_position - side2 * 6.0 + Vector3.UP * 1.3)
	await _secs(0.5)
	var b2 := _burst_on(foe, d2, l2)
	_expect(_burnt(gas2) and absf(float(b2[0]) - 8.0 * scale) < 0.05 and absf(rr.pct_of(p) - pp0) < 0.01,
			"Flashfire: lit from inside the cloud, the foe in it takes %.2f%%, its lighter nothing (%.2f%%)" % [b2[0], rr.pct_of(p) - pp0])
	# his Embers: 6% (7) over the seven embers, each that lands its share
	var share := {}
	for id: String in ["", ff_id]:
		await _calm()
		_wear(id)
		rr._stale.clear()
		var fwd3 := -p.global_basis.z
		fwd3.y = 0.0
		_foe_at = p.global_position + fwd3.normalized() * 3.5
		await _ticks(2)
		var d3 := _dealt.size()
		_embers_at(_foe_at + Vector3.UP * 1.3)
		await _secs(0.5)
		var each: Array = _dealt.slice(d3).filter(func(e: Array) -> bool: return e[1] == foe and String(e[2]) == "fire_jab/embers") \
				.map(func(e: Array) -> float: return float(e[3]))
		share[id] = [each.size(), (each.reduce(func(a: float, x: float) -> float: return a + x, 0.0) / maxf(each.size(), 1.0))]
	var ec := BendLoadout.hit_class(p, RingRules.class_of("fire_jab/embers"))
	_expect(is_equal_approx(float(ec.get("d", 0.0)), 6.0) and is_equal_approx(float(RingRules.class_of("fire_jab/embers").d), 7.0)
			and int(share[""][0]) > 0 and int(share[ff_id][0]) > 0 and absf(float(share[ff_id][1]) - 6.0 / 7.0 * scale) < 0.01
			and absf(float(share[""][1]) - 7.0 / 7.0 * scale) < 0.01,
			"Flashfire: his Embers add 6%% (7): each ember that lands %.3f%% (%d landed; Classic %.3f%%, %d)"
			% [float(share[ff_id][1]), int(share[ff_id][0]), float(share[""][1]), int(share[""][0])])
	# other fire lights it too (the Breath's cone, a fire wall raised over it); water does not
	await _calm()
	_wear("")
	_foe_at = home
	await _ticks(2)
	var fwd4 := -p.global_basis.z
	fwd4.y = 0.0
	fwd4 = fwd4.normalized()
	var g_breath := _gas(foe, p.global_position + fwd4 * 3.0)
	var m4 := moments.size()
	BendEffects.apply(bc, "fire_breath", "breath", ((SwayMoves.move("fire_breath").bend as Dictionary).breath as Dictionary))
	await _ticks(3)
	var by_breath := moments.slice(m4).any(func(m: Array) -> bool: return m[0] == "ignited" and m[1] == p)
	var g_wall := _gas(foe, p.global_position + fwd4 * 6.0)
	var g_water := _gas(foe, p.global_position - fwd4 * 5.0)
	var wall := BendZone.make(p, "fire_wall", FormEffects.ground_at(p, p.global_position + fwd4 * 6.0 + fwd4.cross(Vector3.UP) * 2.0),
			{"width_m": 4.0, "height_m": 2.0, "thick_m": 0.6, "life_s": 2.0}, fwd4)
	var wspec: Dictionary = ((SwayMoves.move("water_jet").bend as Dictionary).splash as Dictionary).duplicate()
	wspec["_info"] = BendR3.info_for(bc, "water_jet", "splash", false, wspec)
	var wfrom := p.global_position + Vector3.UP * 1.3
	BendBolt.launch(p, wfrom, (p.global_position - fwd4 * 5.0 + Vector3.UP * 1.0 - wfrom).normalized(), wspec)
	await _secs(0.6)
	_expect(_burnt(g_breath) and by_breath, "a Breath (Classic) over a gas cloud lights it, his")
	_expect(wall != null and _burnt(g_wall), "a fire wall raised reaching into a gas cloud lights it")
	_expect(not _burnt(g_water), "water through a gas cloud does not light it")
	if is_instance_valid(g_water):
		g_water.end()
	# a bot wearing it: its Embers at the player standing in a cloud of his own (as an earth player's) burn him bigger
	var nb: NpcBending = (foe.get(&"brain") as NpcBrain).bending if foe.get(&"brain") != null else null
	var bot := {}
	for id: String in ["", ff_id]:
		await _calm()
		_wear(id, foe)
		rr._stale.clear()
		var fwd5 := -p.global_basis.z
		fwd5.y = 0.0
		_foe_at = p.global_position + fwd5.normalized() * 6.0
		await _ticks(2)
		if foe.has_method(&"face_point"):
			foe.call(&"face_point", p.global_position)
		var gas5 := _gas(p, p.global_position)
		var d5 := _dealt.size()
		var l5 := _launch.size()
		if nb != null:
			nb.begin("fire_jab", "embers")
			nb.lock_t = nb.lock_s
			nb._release()
		await _secs(0.7)
		var b5 := _burst_on(p, d5, l5)
		bot[id] = {"lit": _burnt(gas5), "pct": b5[0], "by": b5[2]}
		if nb != null:
			nb._cancel()
	_expect(nb != null and bool(bot[""].lit) and bool(bot[ff_id].lit) and bot[ff_id].by == foe
			and absf(float(bot[ff_id].pct) - 8.0 * scale) < 0.05 and absf(float(bot[""].pct) - 6.0 * scale) < 0.05,
			"a bot wearing Flashfire: its Embers light the player's own gas round him: he takes %.2f%% (a Classic bot's %.2f%%)"
			% [bot[ff_id].pct, bot[""].pct])
	# ...and wants its Embers more at a foe standing in gas
	await _calm()
	_wear(ff_id, foe)
	var g6 := _gas(p, p.global_position)
	var w_in := FireTalents.bot_weight(foe, {"key": "fire_jab/embers"}, p)
	var w_punch := FireTalents.bot_weight(foe, {"key": "fire_blast/punch"}, p)
	g6.end()
	await _ticks(2)
	var w_out := FireTalents.bot_weight(foe, {"key": "fire_jab/embers"}, p)
	var g7 := _gas(p, p.global_position)
	BendLoadout.clear(foe)
	var w_classic := FireTalents.bot_weight(foe, {"key": "fire_jab/embers"}, p)
	g7.end()
	_expect(is_equal_approx(w_in, 2.0) and is_equal_approx(w_punch, 1.0) and is_equal_approx(w_out, 1.0) and is_equal_approx(w_classic, 1.0),
			"a bot wearing Flashfire wants its Embers x%.1f at a foe in gas (another move x%.1f, no gas x%.1f, Classic x%.1f)"
			% [w_in, w_punch, w_out, w_classic])
	_foe_at = home
	await _ticks(2)
