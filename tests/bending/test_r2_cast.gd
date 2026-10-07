extends SceneTree
## Round 2's shared cast rules (skills_r2 spec §2.1-2.4, §2.7, §2.10, §8.2; the owner's answers 2026-10-05), in Tidebreak's
## ring (scenes/ring.tscn, MatchSetup.incoming, element earth; the foe held where he stands), the player's own lock driven
## through his SwayCaster (held_override, quick_override, guard_override) and his hotbar's keys (Hotbar.select), the key layout
## round 2's shape (Bending.set_test_data: a key is [id] or [id, id]):
##   keys      a tap readies its key's first move, a double tap the second, for a one-id key (its modes) and a two-id key
##             (its partner); 4, cast, 4: the same wall; E, cast, E: the guard again
##   click     a 0.1 s click on LMB casts Pebbles the moment its lock is full; a 0.3 s hold let go before full casts nothing;
##             a hold past raise_at_fill let go early leaves its spike lying loose (FormStone.make_loose)
##   mid-lock  the same key: the lock moves to the other move with its time kept and goes only switch_hold_s after the
##             switch; a double tap switches once; another key restarts from nothing; E drops the lock and guards
##   grow      let go before grow_after_s: the base spec, after it the grown one; held to release_s it casts itself grown;
##             a move that does not grow sputters and fizzles at release_s
##   setback   a 0.35 s hitter pushes a lock back 0.35 s (not to nothing); a light one at least hit_setback_min_s; a dash's
##             and a guard's lock untouched; lightning's charge breaks; its charge plays on the hands while it locks
##   Q         held quick_reset_s: the left button is the jab again; the equip wheel never opens with an element
##   jump      Space jumps while a lock is held, and the lock keeps filling
##   walls     a third wall crumbles the oldest; Column and Lift never count and sink sink_s after; fire and wind walls one
##             at a time; walls rise 2-6 m off; the earth wall's lock survives the crosshair moving
##   shove     the held stone first; a loose stone 8 m off is not taken (a stone is kicked up); a fourth loose stone sinks the
##             oldest; another's held stone is never taken
##   dashes    nothing held: back; a back dash from 1 m inside the open end and a side Step into the ropes end on the deck
##   carried   air's Carried wind: x knock_mult 0.5 s after a dash's end, nothing at 1.0 s
##   fire      the owner's "keep them all": Punch held past its second click is the Fireball (fire's Strike grows); 1 tapped
##             twice is Lightning; Embers is fire's jab, its reach the jab's (jab_max_m); 4 tapped twice is Breath, its smoke
##             left where it burned hiding the player from the bot, no slow on anyone
##   no slows  no element-mode spec of moves.json roots or slows the player (BendStatus.held_off)
## METRIC lines: click_casts_ok, dash_edge_safe_ok, no_player_slow_ok. Last line "R2 CAST PASSED" or "R2 CAST FAILED"; exit 0
## only on a pass; a watchdog quits with 2.
##   Godot --headless --fixed-fps 60 --path . -s tests/bending/test_r2_cast.gd

const NAME := "R2 CAST"
const WATCHDOG_S := 420.0
const OWN_CFG := "user://r2_cast_test.cfg"
## The key layout of round 2's shape for the test (earth's: a one-id key of two modes, a two-id key, the wall's key; Rock Jab
## on 5 so it is a valid left button under today's quick-spell rule).
const EARTH_KEYS := [["stone_form"], ["earth_shove"], ["earth_skate", "pillar"], ["earth_wall"], ["patch", "rock_jab"]]
const AIR_KEYS := [["air_blast"], ["air_palm"], ["evade", "air_jump"], ["air_shield"], ["patch"]]
## Fire's (the owner's answers 2026-10-05: Punch with Lightning its partner on 1, the Fire Wall with Breath on 4).
const FIRE_KEYS := [["fire_blast", "fire_arc"], ["fire_jets"], ["footwork", "fire_jets"], ["fire_wall", "fire_breath"], ["patch"]]
## Fire's Strike grown (the Fireball: today's fireball numbers) and the Breath's smoke (KITS writes them in moves.json).
const FIREBALL := {"mps": 22.0, "damage": 34.0, "knock_mps": 9.0, "up_mps": 2.0, "radius_m": 0.5, "range_m": 35.0}
const BREATH := {"do": "cone", "kind": "fire", "range_m": 4.5, "deg": 45.0, "damage": 16.0, "knock_mps": 2.0, "melt": true,
		"smoke_s": 4.0}

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var p: FrontierPlayer
var c: SwayCaster
var rm: RingMode
var foe: NpcFighter
var casts: Array = []
var metrics := {}
var _foe_at := Vector3.INF
var _hold_y := -INF                      ## the player held this high over the deck while not INF (the floor-wave tests' kin)


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
	var els: Dictionary = (SwayMoves.data().get("elements", {}) as Dictionary).duplicate(true)
	els["earth"] = EARTH_KEYS
	els["air"] = AIR_KEYS
	els["fire"] = FIRE_KEYS
	Bending.set_test_data({"elements": els})
	# (the specs round 2 reads, given here: KITS writes them in moves.json)
	var mv: Dictionary = SwayMoves.data().moves
	(mv["stone_form"] as Dictionary)["raise_at_fill"] = 0.6
	var shove: Dictionary = (mv["earth_shove"] as Dictionary).bend
	(shove["push"] as Dictionary)["grow"] = {"knock_mult": 1.5, "grew_mark": true}
	((mv["fire_blast"] as Dictionary).bend.punch as Dictionary)["grow"] = FIREBALL.duplicate()
	MatchSetup.incoming = true
	MatchSetup.element = "earth"
	# (the merge: rules.json plays the % ring by default; this test is the classic ring's, pinned)
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


## The foe held where he stands (no cast, no knock on the player).
func _hold_foe() -> void:
	if foe == null or not is_instance_valid(foe):
		return
	foe.held = true
	if _foe_at == Vector3.INF:
		_foe_at = foe.global_position
	foe.global_position = _foe_at
	foe.velocity = Vector3.ZERO
	if _hold_y > -INF and p != null:
		p.global_position.y = _hold_y
		p.velocity.y = 0.0


func _run() -> void:
	for i in 10:
		await process_frame
	lvl = current_scene as RingLevel
	p = lvl.player if lvl != null else null
	_expect(p != null, "the ring and its player")
	if p == null:
		return _end()
	p.ignore_mouse_capture = true
	p.pitch = -0.1
	c = SwayCaster.of(p)
	c.cast.connect(func(m: String, _t: Node3D) -> void: casts.append([m, c.mode_of(m), BendStatus.now()]))
	var laid := await _until(func() -> bool: return p.arena_element == "earth" and p.hotbar.spell != "", 6.0)
	_expect(laid < INF and c != null, "the arena player, earth laid (%s)" % [p.hotbar.slots.map(func(e: Dictionary) -> String: return String(e.get("id", "")))])
	rm = RingMode.find(self)
	if rm != null:
		var up := await _until(func() -> bool: return rm.phase == "FIGHT", 10.0)
		_expect(up < INF, "the round is on (%s)" % rm.phase)
		foe = rm.foe
		rm.rules.soft_walls = false
	physics_frame.connect(_hold_foe)
	await _secs(0.4)
	await _keys()
	await _click()
	await _mid_lock()
	await _grow()
	await _setback()
	await _q_and_wheel()
	await _jump()
	await _walls()
	await _shove()
	await _dashes()
	await _carried()
	await _fire_kit()
	await _no_slows()
	_end()


func _end() -> void:
	c.held_override = null if c != null else null
	if c != null:
		c.quick_override = null
		c.guard_override = null
	Bending.set_test_data({})
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


## Every button let go, nothing waiting, the deck cleared of bending, the player whole at his spawn facing the foe, the
## taps far enough apart that the next is a first tap.
func _calm(at_spawn := true) -> void:
	c.held_override = false
	c.quick_override = false
	c.guard_override = false
	_hold_y = -INF
	await _ticks(2)
	c._wait_release = false
	for g: StringName in [BendBolt.GROUP, BendZone.GROUP, FormRaised.GROUP, FormStone.GROUP, GustLift.GROUP, FormEffects.Throw.GROUP]:
		for x in get_nodes_in_group(g):
			if is_instance_valid(x) and not (x is BendZone and (x as BendZone).kind == "puddle" and false):
				x.queue_free()
	for k: StringName in BendStatus.ROUND_METAS:
		if p.has_meta(k):
			p.remove_meta(k)
	if p.has_meta(FormEffects.RAISED_META):
		p.remove_meta(FormEffects.RAISED_META)
	var kn := BendKnock.peek(p)
	if kn != null:
		kn.reset()
	if at_spawn and rm != null:
		RingLevel.place(p, rm.ring.spawn(rm.player_end))
	p.velocity = Vector3.ZERO
	p.health = p.max_health
	p.pitch = -0.1
	(BendCaster.of(p) as PlayerBendCaster).held_override = null
	await _secs(0.45)


func _tap(i: int) -> void:
	p.hotbar.select(i)
	await physics_frame


## The readied move and its key's variation now ("stone_form/spike").
func _ready_now() -> String:
	return "%s/%s" % [c.readied_spell, c.base_mode_of(c.readied_spell)]


## The aim's button held until the lock is full (or `limit` s): true when it is.
func _lock_full(limit := 3.0) -> bool:
	c.held_override = true
	return await _until(func() -> bool: return c.state == SwayCaster.State.FULL, limit) < INF


# ---------------------------------------------------------------- keys (spec §2.2)
func _keys() -> void:
	await _calm()
	await _tap(0)
	var one := _ready_now()
	await _tap(0)
	var two := _ready_now()
	_expect(one == "stone_form/spike" and two == "stone_form/cannonball",
			"a one-id key: a tap readies its first mode, a double tap its second (%s, %s)" % [one, two])
	await _secs(0.4)
	await _tap(0)
	_expect(_ready_now() == "stone_form/spike", "no memory: a tap later readies the first again (%s)" % _ready_now())
	await _secs(0.4)
	await _tap(2)
	var a := _ready_now()
	await _tap(2)
	var b := _ready_now()
	_expect(a.begins_with("earth_skate/") and b.begins_with("pillar/") and p.hotbar.slot_of(Hotbar.SPELL, "pillar") == 2,
			"a two-id key: a tap its first move, a double tap its partner on the same key (%s, %s)" % [a, b])
	await _secs(0.4)
	await _tap(2)
	_expect(c.readied_spell == "earth_skate", "and a tap later its first move again (%s)" % _ready_now())
	# 4, cast, 4: the same wall
	await _secs(0.4)
	await _tap(3)
	var w1 := _ready_now()
	casts.clear()
	await _lock_full(4.0)
	c.held_override = false
	await _ticks(3)
	await _secs(0.5)
	await _tap(3)
	var w2 := _ready_now()
	_expect(w1 == "earth_wall/wall" and w2 == "earth_wall/wall" and not casts.is_empty() and String(casts[0][0]) == "earth_wall",
			"4, cast, 4: the same wall (%s, %s; cast %s)" % [w1, w2, casts])
	# E, cast, E: the guard again
	await _calm()
	casts.clear()
	c.guard_override = true
	await _ticks(4)
	c.guard_override = false
	var g1 := await _until(func() -> bool: return not casts.is_empty(), 2.0)
	await _secs(0.6)
	var first: Array = casts.duplicate()
	c.guard_override = true
	await _ticks(4)
	c.guard_override = false
	await _until(func() -> bool: return casts.size() >= 2, 2.0)
	_expect(g1 < INF and casts.size() >= 2 and String(casts[0][0]) == "stone_catch" and String(casts[1][0]) == "stone_catch"
			and String(casts[1][1]) == "catch", "E, cast, E: the guard again, no readying (%s)" % [casts])
	_expect(c.readied_spell == "earth_wall", "and the readied move never changed by E (%s)" % c.readied_spell)


# ---------------------------------------------------------------- the click (spec §2.3)
func _click() -> void:
	await _calm()
	await _tap(0)
	casts.clear()
	var before := FormStone.loose_of(p).size()
	# a 0.1 s click on LMB: Pebbles, the moment the lock is full
	c.quick_override = true
	await _secs(0.1)
	c.quick_override = false
	var went := await _until(func() -> bool: return not casts.is_empty(), 2.0)
	var ok := went < INF and String(casts[0][0]) == "rock_jab" and String(casts[0][1]) == "pebbles"
	_expect(ok, "a 0.1 s click on LMB casts Pebbles when the lock fills (%s after %.2f s)" % [casts, went])
	metrics["click_casts_ok"] = ok
	# a 0.3 s hold let go before full: nothing
	await _calm()
	await _tap(0)
	casts.clear()
	c.held_override = true
	await _secs(0.3)
	c.held_override = false
	await _secs(0.8)
	_expect(casts.is_empty() and c.state == SwayCaster.State.IDLE and c.last_break == "let go",
			"a 0.3 s hold let go before full casts nothing (%s; %s)" % [casts, c.last_break])
	# held past raise_at_fill, let go early: the spike drops loose
	await _calm()
	await _tap(0)
	casts.clear()
	c.held_override = true
	var raised := await _until(func() -> bool: return c.raised != null, 2.0)
	var stone: FormStone = (c.raised as FormEffects.Throw).stone if c.raised != null else null
	var fill_at := c.fill
	c.held_override = false
	await _secs(0.5)
	_expect(raised < INF and fill_at >= 0.59 and fill_at < 1.0 and stone != null and is_instance_valid(stone) and casts.is_empty()
			and int(stone.get_meta(FormStone.LOOSE_META, -1)) == p.get_instance_id() and FormStone.loose_of(p).size() == before + 1,
			"the spike rises at raise_at_fill (fill %.2f) and, let go early, lies loose, nothing cast (%s)" % [fill_at, casts])


# ---------------------------------------------------------------- mid-lock (spec §2.3)
func _mid_lock() -> void:
	# the same key: the other move, the time kept; it goes switch_hold_s after the switch
	await _calm()
	await _tap(0)
	casts.clear()
	var full := await _lock_full()
	var spent := c.fill * c.lock_s
	await _tap(0)
	var after := c.fill * c.lock_s
	var at := BendStatus.now()
	var switched := c.move == "stone_form" and c.mode_of("stone_form") == "cannonball"
	c.held_override = false
	await _ticks(2)
	var early := casts.size()
	var went := await _until(func() -> bool: return not casts.is_empty(), 1.0)
	var wait := float(casts[0][2]) - at if not casts.is_empty() else INF
	_expect(full and switched and absf(after - spent) < 0.02, "a same-key tap mid-lock: the other move, the time kept (%.2f -> %.2f s)" % [spent, after])
	_expect(early == 0 and went < INF and wait >= Bending.rule("switch_hold_s", 0.2) - 0.02 and String(casts[0][1]) == "cannonball",
			"its release waits switch_hold_s (it went %.2f s after the switch, as %s)" % [wait, casts])
	# a double tap mid-lock switches once
	await _calm()
	await _tap(0)
	c.held_override = true
	await _secs(0.3)
	await _tap(0)
	await _tap(0)
	_expect(c.move == "stone_form" and c.mode_of("stone_form") == "cannonball" and c.state != SwayCaster.State.IDLE,
			"a double tap mid-lock switches once (%s/%s)" % [c.move, c.mode_of(c.move)])
	# another key: from nothing
	await _calm()
	await _tap(0)
	c.held_override = true
	await _secs(0.5)
	var f0 := c.fill
	await _tap(3)
	await _ticks(2)
	_expect(f0 > 0.3 and c.readied_spell == "earth_wall" and c.move == "earth_wall" and c.fill < 0.1,
			"another key mid-lock: its first move, its lock from nothing (%.2f -> %s at %.2f)" % [f0, c.move, c.fill])
	# E: the lock dropped, the guard at once
	await _calm()
	await _tap(0)
	c.held_override = true
	await _secs(0.5)
	c.guard_override = true
	await _ticks(2)
	_expect(c.lock_src == SwayCaster.SRC_GUARD and c.move == "stone_catch" and c.last_break == "guard",
			"E mid-lock drops the lock and starts the guard (%s %s, broke %s)" % [c.lock_src, c.move, c.last_break])
	c.guard_override = false
	await _secs(0.5)
	_expect(c.lock_src != SwayCaster.SRC_AIM or c.state == SwayCaster.State.IDLE, "and the held aim does not lock again until let go (%s)" % c.state)


# ---------------------------------------------------------------- grow (spec §2.3)
func _grow() -> void:
	await _calm()
	await _tap(1)
	await _lock_full()
	c.held_override = false
	await _secs(0.6)                             # (a shove lands on its pose's strike)
	var base := BendEffects.last_of(p)
	_expect(String(base.get("move", "")) == "earth_shove" and not bool(base.get("grown", true))
			and not (base.get("spec", {}) as Dictionary).has("grew_mark"), "let go before grow_after_s: the base spec (%s)" % base.get("grown"))
	await _calm()
	await _tap(1)
	await _lock_full()
	await _secs(Bending.rule("grow_after_s", 0.45) + 0.1)
	var grew := c.grown
	c.held_override = false
	await _secs(0.6)
	var g := BendEffects.last_of(p)
	_expect(grew and bool(g.get("grown", false)) and (g.get("spec", {}) as Dictionary).has("grew_mark")
			and float((g.get("spec", {}) as Dictionary).get("knock_mult", 1.0)) == 1.5,
			"let go after grow_after_s: the grown spec (%s)" % g.get("grown"))
	await _calm()
	await _tap(1)
	casts.clear()
	await _lock_full()
	await _secs(1.5)
	var self_cast := casts.size() == 1 and c.state == SwayCaster.State.IDLE and bool(BendEffects.last_of(p).get("grown", false))
	_expect(self_cast, "a grow move held to release_s casts itself grown, still held (%s, %s)" % [casts, c.last_break])
	c.held_override = false
	await _ticks(3)
	# a move that does not grow: it sputters, then fizzles at release_s
	await _calm()
	await _tap(0)
	casts.clear()
	await _lock_full()
	await _secs(0.8)
	var sputtered := c._sputtered
	await _secs(0.35)
	_expect(sputtered and casts.is_empty() and c.last_break == "fizzled", "a move that does not grow sputters at sputter_s and fizzles at release_s (%s)" % c.last_break)


# ---------------------------------------------------------------- the hit's setback (spec §2.3)
func _setback() -> void:
	await _calm()
	await _tap(0)
	c.held_override = true
	await _secs(0.7)
	var spent := c.fill * c.lock_s
	BendStatus.hurt(p, 2.0, p.global_position + Vector3.UP, Vector3.FORWARD, foe, 0.35)
	await physics_frame
	var after := c.fill * c.lock_s
	_expect(c.state != SwayCaster.State.IDLE and absf((spent - after) - 0.35) < 0.04,
			"a 0.35 s hitter pushes the lock back 0.35 s, not to nothing (%.2f -> %.2f s)" % [spent, after])
	spent = c.fill * c.lock_s
	BendStatus.hurt(p, 2.0, p.global_position + Vector3.UP, Vector3.FORWARD, foe, 0.1)
	await physics_frame
	after = c.fill * c.lock_s
	_expect(absf((spent - after) - Bending.rule("hit_setback_min_s", 0.25)) < 0.04,
			"a light hitter: at least hit_setback_min_s (%.2f -> %.2f s)" % [spent, after])
	# a dash's lock and a guard's: untouched
	await _calm()
	await _tap(2)
	c.held_override = true
	await _secs(0.15)
	spent = c.fill * c.lock_s
	BendStatus.hurt(p, 2.0, p.global_position + Vector3.UP, Vector3.FORWARD, foe, 0.9)
	await physics_frame
	var dash_ok := c.move == "earth_skate" and c.fill * c.lock_s >= spent - 0.001
	c.held_override = false
	await _calm()
	c.guard_override = true
	await _ticks(5)
	spent = c.fill * c.lock_s
	BendStatus.hurt(p, 2.0, p.global_position + Vector3.UP, Vector3.FORWARD, foe, 0.9)
	await physics_frame
	var guard_ok := c.lock_src == SwayCaster.SRC_GUARD and (c.state == SwayCaster.State.FULL or c.fill * c.lock_s >= spent - 0.001)
	_expect(dash_ok and guard_ok, "a dash's and a guard's lock are never pushed back (dash %s, guard %s)" % [dash_ok, guard_ok])
	c.guard_override = false
	# (lightning's charge breaking on a hit: _fire_kit, on fire's own Lightning)


# ---------------------------------------------------------------- Q and the wheel
func _q_and_wheel() -> void:
	await _calm()
	await _tap(0)
	c.bind_quick()
	_expect(c.quick_id() == "stone_form", "Q binds the readied move (%s)" % c.quick_label())
	_expect(String(c.next_q().get("do", "")) == "back", "and the next Q puts the jab back (%s)" % c.next_q())
	Input.action_press(SwayCaster.QUICK_BIND)
	await _secs(Bending.rule("quick_reset_s", 0.5) + 0.15)
	var wheel := p.equip_wheel
	var opened := wheel != null and wheel.is_open
	Input.action_release(SwayCaster.QUICK_BIND)
	await _ticks(2)
	_expect(c.quick_id() == "rock_jab" and c.quick_mode() == "pebbles", "Q held quick_reset_s: the jab back on the left button (%s)" % c.quick_label())
	_expect(not opened, "and the equip wheel never opened with an element")
	# the wheel: the readied move's other
	await _calm()
	await _tap(0)
	p.hotbar.wheel(1)
	await physics_frame
	_expect(_ready_now() == "stone_form/cannonball", "a wheel step: the key's other move (%s)" % _ready_now())


# ---------------------------------------------------------------- jumping mid-lock (spec §2.1)
func _jump() -> void:
	await _calm()
	await _tap(3)
	c.held_override = true
	await _secs(0.3)
	var f0 := c.fill
	Input.action_press(&"jump")
	await _ticks(3)
	Input.action_release(&"jump")
	var up := await _until(func() -> bool: return not p.is_on_floor() and p.velocity.y > 0.5, 0.5)
	await _secs(0.2)
	_expect(up < INF and c.state in [SwayCaster.State.LOCKING, SwayCaster.State.FULL] and c.fill > f0,
			"Space jumps while a lock is held and the lock keeps filling (%.2f -> %.2f, %s)" % [f0, c.fill, c.state])
	c.held_override = false
	await _secs(0.8)


# ---------------------------------------------------------------- walls (spec §2.7)
func _my_walls() -> Array:
	return get_nodes_in_group(FormRaised.GROUP).filter(func(w: Node) -> bool:
		return w is FormRaised and (w as FormRaised).kind == "wall" and (w as FormRaised).state != FormRaised.State.CRUMBLING \
				and int(w.get_meta(&"bend_by", -1)) == p.get_instance_id())


func _walls() -> void:
	await _calm()
	var bc := BendCaster.of(p)
	var made: Array = []
	for i in 3:
		p.yaw += 0.35
		await _ticks(2)
		BendCast.cast(bc, "earth_wall", "wall")
		made.append(BendEffects.last_of(p).get("made"))
		await _secs(0.8)
	var mine := _my_walls()
	_expect(mine.size() == 2 and not mine.has(made[0]) and mine.has(made[2]), "a third wall crumbles the oldest (%d standing)" % mine.size())
	# placed 2-6 m off, facing the caster
	var ok := true
	var dists: Array = []
	for w: FormRaised in mine:
		var d := Vector2(w.global_position.x - p.global_position.x, w.global_position.z - p.global_position.z).length()
		dists.append(snappedf(d, 0.01))
		ok = ok and d >= 1.9 and d <= 6.2
	_expect(ok, "walls rise 2-6 m off (%s)" % [dists])
	# Column and Lift: not walls, and sink sink_s after
	await _calm()
	var col := BendEffects.column(bc, FormEffects.ground_at(p, p.global_position + bc.facing() * 5.0),
			{"radius_m": 1.3, "up_mps": 11.0, "damage": 10.0, "rise_s": 0.35, "sink_s": 1.5})
	FormRaised.count_wall(col)
	await _secs(0.1)
	var lift := FormEffects.pillar(c, p.global_position, SwayMoves.move("pillar"), "self")
	if lift != null:
		lift.life_s = 1.5                        # (Lift's sink_s: KITS' data; the rule read here is the life it gives)
	var counted := col.has_meta(&"wall_n") or (lift != null and lift.has_meta(&"wall_n"))
	await _secs(0.35 + 1.5 + 0.9)
	var col_gone := not is_instance_valid(col) or col.state == FormRaised.State.CRUMBLING
	var lift_gone := lift == null or not is_instance_valid(lift) or lift.state == FormRaised.State.CRUMBLING
	_expect(not counted and col_gone and lift_gone, "Column and Lift never count as walls and sink after sink_s (%s %s %s)" % [counted, col_gone, lift_gone])
	# fire walls and wind walls: one at a time
	await _calm()
	var fw := {"do": "zone", "zone": "fire_wall", "at": "front", "ahead_m": 3.0, "width_m": 4.0, "height_m": 2.0, "life_s": 5.0,
			"damage_s": 18.0, "place": {"min_m": 2.0, "max_m": 6.0}, "kind": "fire"}
	BendEffects.apply(bc, "fire_wall", "wall", fw)
	await _ticks(3)
	BendEffects.apply(bc, "fire_wall", "wall", fw)
	await _ticks(3)
	var ww := {"do": "wind_wall", "width_m": 3.0, "height_m": 2.5, "life_s": 4.0, "place": {"min_m": 2.0, "max_m": 6.0}, "kind": "air"}
	BendEffects.apply(bc, "air_shield", "shield", ww)
	await _ticks(3)
	BendEffects.apply(bc, "air_shield", "shield", ww)
	await _ticks(3)
	var fires := get_nodes_in_group(BendZone.GROUP).filter(func(z: Node) -> bool: return (z as BendZone).kind == "fire_wall" and (z as BendZone).owner_node == p)
	var winds := get_nodes_in_group(BendZone.GROUP).filter(func(z: Node) -> bool: return (z as BendZone).kind == "wind_wall" and (z as BendZone).owner_node == p)
	_expect(fires.size() == 1 and winds.size() == 1, "fire walls and wind walls stand one at a time (%d, %d)" % [fires.size(), winds.size()])
	var wz: BendZone = winds[0] if not winds.is_empty() else null
	var wd := Vector2(wz.global_position.x - p.global_position.x, wz.global_position.z - p.global_position.z).length() if wz != null else -1.0
	_expect(wz != null and wd >= 1.9 and wd <= 6.2 and wz.size.is_equal_approx(Vector3(3.0, 2.5, 0.6)),
			"the wind wall: 3 x 2.5 m, 2-6 m off (%.2f m, %s)" % [wd, wz.size if wz != null else Vector3.ZERO])
	# the earth wall's lock survives the crosshair moving
	await _calm()
	await _tap(3)
	c.held_override = true
	var swung := true
	for i in 40:
		p.yaw += 0.08
		p.pitch = -0.1 + 0.3 * sin(i * 0.4)
		await physics_frame
		swung = swung and c.state != SwayCaster.State.IDLE
		if c.state == SwayCaster.State.FULL:
			break
	await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 2.0)
	_expect(swung and c.state == SwayCaster.State.FULL and c.move == "earth_wall", "the earth wall's lock survives the crosshair moving (%s)" % c.state)
	c.held_override = false
	await _secs(0.4)


# ---------------------------------------------------------------- shove (spec §2.10)
## The player's crosshair on `at` (his camera turned until its ray meets it within 0.2 m, a few tries).
func _aim_at(at: Vector3) -> void:
	for i in 6:
		await _ticks(2)
		var cam := p.camera
		var to := at - cam.global_position
		var flat := Vector2(to.x, to.z)
		p.yaw = atan2(-to.x, -to.z)
		p.pitch = clampf(atan2(to.y, flat.length()), -1.3, 1.3)
		await _ticks(2)


func _stone_at(at: Vector3) -> FormStone:
	var s := FormStone.ball(current_scene, FormEffects.ground_at(p, at), {"radius_m": 0.3, "rise_s": 0.01, "life_s": 60.0}, 3, "stone")
	s.state = FormStone.State.RESTING
	s.global_transform = s.base
	s.freeze = true
	return s


func _shove() -> void:
	await _calm()
	var bc := BendCaster.of(p)
	var fwd := bc.facing()
	var held := _stone_at(p.global_position + fwd * 1.3 + Vector3.UP * 1.1)
	held.set_meta(&"bend_held_by", p.get_instance_id())
	var loose := _stone_at(p.global_position + fwd * 4.0)
	FormStone.make_loose(loose, p)
	await _aim_at(loose.global_position)
	BendEffects.apply(bc, "earth_shove", "push", (SwayMoves.move("earth_shove").bend as Dictionary).push)
	var r := BendEffects.last_of(p)
	_expect(String(r.get("how", "")) == "held" and r.get("stone") == held, "Shove: the held stone goes first (%s)" % r.get("how"))
	await _secs(0.6)
	# a loose stone at 8 m: not taken, one kicked up instead
	await _calm()
	fwd = bc.facing()
	var far := _stone_at(p.global_position + fwd * 8.0)
	FormStone.make_loose(far, p)
	await _aim_at(far.global_position + Vector3.UP * 0.1)
	BendEffects.apply(bc, "earth_shove", "push", (SwayMoves.move("earth_shove").bend as Dictionary).push)
	r = BendEffects.last_of(p)
	_expect(String(r.get("how", "")) == "kick_up" and is_instance_valid(far) and not GustLift.busy(far),
			"a loose stone at 8 m is not taken: a stone kicked up instead (%s)" % r.get("how"))
	await _secs(0.8)
	_expect(r.get("throw") != null, "the kicked-up stone pushed at the kick-up's strike (%s)" % r.get("throw"))
	# within 6 m: taken
	await _calm()
	fwd = bc.facing()
	var near := _stone_at(p.global_position + fwd * 4.5)
	FormStone.make_loose(near, p)
	await _aim_at(near.global_position + Vector3.UP * 0.1)
	BendEffects.apply(bc, "earth_shove", "push", (SwayMoves.move("earth_shove").bend as Dictionary).push)
	r = BendEffects.last_of(p)
	_expect(String(r.get("how", "")) == "loose" and r.get("stone") == near, "a loose stone within 6 m is shoved (%s)" % r.get("how"))
	await _secs(0.6)
	# the fourth loose stone sinks the oldest
	await _calm()
	var four: Array = []
	for i in 4:
		var s := _stone_at(p.global_position + Vector3(i * 0.8 - 1.2, 0.0, 3.0))
		FormStone.make_loose(s, p)
		four.append(s)
	await _ticks(2)
	_expect((four[0] as FormStone).state == FormStone.State.SINKING and (four[3] as FormStone).state != FormStone.State.SINKING
			and FormStone.loose_of(p).size() == Bending.stones().get("loose_max", 3),
			"a fourth loose stone sinks the oldest (%d lying)" % FormStone.loose_of(p).size())
	# another's held stone: never taken
	await _calm()
	fwd = bc.facing()
	var theirs := _stone_at(p.global_position + fwd * 3.0 + Vector3.UP * 1.0)
	theirs.set_meta(&"bend_held_by", foe.get_instance_id())
	await _aim_at(theirs.global_position)
	BendEffects.apply(bc, "earth_shove", "push", (SwayMoves.move("earth_shove").bend as Dictionary).push)
	r = BendEffects.last_of(p)
	_expect(String(r.get("how", "")) != "loose" and r.get("stone") != theirs and int(theirs.get_meta(&"bend_held_by", -1)) == foe.get_instance_id(),
			"the other side's held stone is never shoved (%s)" % r.get("how"))
	await _secs(0.6)


# ---------------------------------------------------------------- dashes and the edge (spec §2.1, §10)
func _dashes() -> void:
	await _calm()
	var bc := BendCaster.of(p) as PlayerBendCaster
	var spec := {"do": "dash", "kind": "stone", "dir": "held", "none": "back", "fwd_mps": 14.0, "up_mps": 0.0}
	bc.held_override = Vector2.ZERO
	var fwd := bc.facing()
	BendEffects.dash(bc, fwd, spec)
	var v := p.velocity
	_expect(Vector2(v.x, v.z).normalized().dot(Vector2(-fwd.x, -fwd.z)) > 0.95, "a dash with nothing held goes back (%s)" % v)
	bc.held_override = Vector2(1.0, 0.0)
	BendEffects.dash(bc, fwd, spec)
	var right := fwd.cross(Vector3.UP).normalized()
	_expect(Vector2(p.velocity.x, p.velocity.z).normalized().dot(Vector2(right.x, right.z)) > 0.95, "D held: to the right (%s)" % p.velocity)
	await _secs(0.8)
	# a back dash from 1 m inside the open end: still on the deck
	await _calm()
	var ring := rm.ring
	var e := rm.player_end
	var axis := ring.axis() * RingArena.side_sign(e)
	var at := ring.center() + axis * (ring.half_l() - 1.0)
	RingLevel.place(p, Transform3D(Basis.looking_at(-Vector3(axis.x, 0.0, axis.z).normalized(), Vector3.UP), at))
	await _secs(0.3)
	bc.held_override = Vector2.ZERO
	BendEffects.dash(bc, bc.facing(), spec)
	await _secs(1.5)
	var end_ok := ring.on_deck(p.global_position) and not ring.is_ring_out(p)
	_expect(end_ok, "a back dash from 1 m inside the open end ends on the deck (s %.2f of %.2f)" % [ring.s_of(p.global_position, e), ring.half_l()])
	# a side Step into the ropes: still on the deck
	await _calm()
	var side := ring.global_basis.z.normalized()
	RingLevel.place(p, Transform3D(Basis.looking_at(-axis, Vector3.UP), ring.center() + side * (ring.half_w() - 1.0)))
	await _secs(0.3)
	var rt := bc.facing().cross(Vector3.UP).normalized()
	bc.held_override = Vector2(1.0 if rt.dot(side) > 0.0 else -1.0, 0.0)
	BendEffects.dash(bc, bc.facing(), {"do": "dash", "kind": "fire", "dir": "held", "none": "back", "fwd_mps": 9.0, "up_mps": 3.0,
			"side": {"fwd_mps": 9.0, "up_mps": 3.0}})
	await _secs(1.5)
	var side_ok := ring.on_deck(p.global_position) and not ring.is_ring_out(p)
	_expect(side_ok, "a side Step into the ropes ends on the deck (%s)" % ring.to_local(p.global_position))
	metrics["dash_edge_safe_ok"] = end_ok and side_ok
	bc.held_override = null


# ---------------------------------------------------------------- Carried wind (spec §2.4)
func _carried() -> void:
	await _calm()
	Bending.of(p).element = "air"
	var relaid := await _until(func() -> bool: return p.arena_element == "air", 3.0)
	_expect(relaid < INF, "the player air for Carried wind")
	var bc := BendCaster.of(p) as PlayerBendCaster
	bc.held_override = Vector2.ZERO
	var spec := {"do": "bolt", "kind": "air", "carry": true, "mps": 28.0, "damage": 1.0, "knock_mps": 10.0, "radius_m": 0.3, "range_m": 3.0}
	BendEffects.dash(bc, bc.facing(), {"do": "dash", "kind": "air", "dir": "held", "none": "back", "fwd_mps": 9.0, "up_mps": 0.5})
	var ended := await _until(func() -> bool: return p.has_meta(&"bend_dash_end"), 2.0)
	await _secs(0.5)
	BendEffects.apply(bc, "air_blast", "ball", spec)
	var k1 := float((BendEffects.last_of(p).get("spec", {}) as Dictionary).get("knock_mps", 0.0))
	BendEffects.dash(bc, bc.facing(), {"do": "dash", "kind": "air", "dir": "held", "none": "back", "fwd_mps": 9.0, "up_mps": 0.5})
	p.remove_meta(&"bend_dash_end")
	await _until(func() -> bool: return p.has_meta(&"bend_dash_end"), 2.0)
	await _secs(1.0)
	BendEffects.apply(bc, "air_blast", "ball", spec)
	var k2 := float((BendEffects.last_of(p).get("spec", {}) as Dictionary).get("knock_mps", 0.0))
	var mult := float(Bending.passive("air").get("knock_mult", 1.15))
	_expect(ended < INF and absf(k1 - 10.0 * mult) < 0.01 and absf(k2 - 10.0) < 0.01,
			"Carried wind: x%.2f 0.5 s after a dash's end (%.2f), none at 1.0 s (%.2f)" % [mult, k1, k2])
	bc.held_override = null
	Bending.of(p).element = "earth"
	await _until(func() -> bool: return p.arena_element == "earth", 3.0)


# ---------------------------------------------------------------- no roots and slows (spec §8.2 "Removed paths")
func _no_slows() -> void:
	await _calm()
	var fbc := BendCaster.of(foe)
	if fbc is BodyBendCaster:
		(fbc as BodyBendCaster).target = p
	var held0 := BendStatus.held_off
	var specs := 0
	var reached: Array = []
	for id: String in SwayMoves.ids():
		var bd: Variant = SwayMoves.move(id).get("bend", {})
		if not (bd is Dictionary):
			continue
		for md: String in (bd as Dictionary):
			var sp: Dictionary = bd[md]
			if float(sp.get("root_s", 0.0)) <= 0.0 and float(sp.get("slow_s", 0.0)) <= 0.0 and not String(sp.get("zone", "")) in ["ice_patch", "vacuum"]:
				continue
			specs += 1
			p.global_position = foe.global_position + (p.global_position - foe.global_position).normalized() * 3.0
			BendEffects.apply(fbc, id, md, sp)
			await _secs(0.5)
			for k: StringName in [&"bend_root", &"bend_slow"]:
				if p.has_meta(k) and BendStatus.until(p, k) > 0.0:
					reached.append("%s/%s" % [id, md])
			for z in get_nodes_in_group(BendZone.GROUP):
				(z as BendZone).end()
			for b in get_nodes_in_group(BendBolt.GROUP):
				(b as BendBolt).end("test")
			await _ticks(2)
	var ok := specs > 0 and reached.is_empty() and p.bend_speed_cap == INF
	_expect(ok, "no element-mode spec roots or slows the player (%d specs; reached by %s; held off %d)" % [specs, reached, BendStatus.held_off - held0])
	metrics["no_player_slow_ok"] = ok


# ---------------------------------------------------------------- fire's kit (the owner's answers 2026-10-05)
func _fire_kit() -> void:
	await _calm()
	Bending.of(p).element = "fire"
	var relaid := await _until(func() -> bool: return p.arena_element == "fire", 3.0)
	_expect(relaid < INF, "the player fire for his kit")
	await _secs(0.4)
	# the Fireball: Punch held past its second click
	await _tap(0)
	var one := _ready_now()
	await _lock_full()
	await _secs(Bending.rule("grow_after_s", 0.45) + 0.1)
	var grew := c.grown
	c.held_override = false
	await _secs(0.6)
	var g := BendEffects.last_of(p)
	var gs: Dictionary = g.get("spec", {})
	_expect(one == "fire_blast/punch" and grew and bool(g.get("grown", false)) and float(gs.get("damage", 0.0)) == FIREBALL.damage
			and float(gs.get("radius_m", 0.0)) == FIREBALL.radius_m,
			"Punch held past its second click goes as the Fireball (%s, grew %s, %.0f dmg)" % [one, grew, float(gs.get("damage", 0.0))])
	await _calm(false)
	await _tap(0)
	await _lock_full()
	c.held_override = false
	await _secs(0.6)
	var b := BendEffects.last_of(p)
	var punch_dmg := float((((SwayMoves.move("fire_blast").get("bend", {}) as Dictionary).get("punch", {})) as Dictionary).get("damage", -1.0))
	_expect(not bool(b.get("grown", true)) and float((b.get("spec", {}) as Dictionary).get("damage", 0.0)) == punch_dmg,
			"and let go at its first click, the plain Punch (grown %s, %.0f dmg, the data's %.0f)" % [b.get("grown"),
			float((b.get("spec", {}) as Dictionary).get("damage", 0.0)), punch_dmg])
	await _calm(false)
	await _tap(0)
	await _tap(0)
	_expect(c.readied_spell == "fire_arc", "1 tapped twice: Lightning, Punch's partner (%s)" % _ready_now())
	# lightning's charge on the hands while it locks, and broken by any hit (a light one: no setback, the charge is lost)
	c.held_override = true
	await _secs(0.4)
	var ch := c.charge
	var humming := ch != null and is_instance_valid(ch) and bool(ch.call(&"humming"))
	BendStatus.hurt(p, 2.0, p.global_position + Vector3.UP, Vector3.FORWARD, foe, 0.35)
	await physics_frame
	_expect(c.state == SwayCaster.State.IDLE and c.last_break == "hit", "lightning's charge breaks on any hit (%s)" % c.last_break)
	_expect(humming, "lightning's charge hums on the hands while it locks (%s)" % ch)
	c.held_override = false
	# Embers: fire's jab, the jab's reach
	await _calm(false)
	var jb := Bending.jab("fire")
	var bc := BendCaster.of(p)
	var em: Dictionary = ((SwayMoves.move("fire_jab").get("bend", {}) as Dictionary).get("embers", {}) as Dictionary).duplicate()
	em["range_m"] = 14.0
	BendEffects.apply(bc, "fire_jab", "embers", em)
	var mine := get_nodes_in_group(BendBolt.GROUP).filter(func(n: Node) -> bool: return (n as BendBolt).caster == p)
	var reach := (mine[0] as BendBolt).range_m if not mine.is_empty() else -1.0
	_expect(String(jb.get("id", "")) == "fire_jab" and String(jb.get("mode", "")) == "embers" and mine.size() == int(em.get("count", 7))
			and is_equal_approx(reach, Bending.rule("jab_max_m", 10.0)),
			"Embers is fire's jab: %d small bolts from the fist, reaching %.1f m (the jab's %.0f)" % [mine.size(), reach, Bending.rule("jab_max_m", 10.0)])
	# Breath: 4 tapped twice, its smoke where it burned
	await _calm()
	await _tap(3)
	var w := _ready_now()
	await _tap(3)
	var br := _ready_now()
	_expect(w.begins_with("fire_wall/") and br.begins_with("fire_breath/"), "4: the Fire Wall, tapped twice Breath (%s, %s)" % [w, br])
	BendEffects.apply(bc, "fire_breath", "breath", BREATH)
	var smoke: BendZone = BendEffects.last_of(p).get("smoke")
	await _ticks(3)
	var hid := NpcBendCaster.hidden(foe, p) if smoke != null else false
	var slowed := BendStatus.until(foe, &"bend_slow") > 0.0 or BendStatus.until(p, &"bend_slow") > 0.0 or p.bend_speed_cap != INF
	_expect(smoke != null and is_instance_valid(smoke) and smoke.kind == "smoke" and hid and not slowed,
			"Breath leaves smoke where it burned: the bot cannot see him through it, no one slowed (hidden %s, slowed %s)" % [hid, slowed])
	Bending.of(p).element = "earth"
	await _until(func() -> bool: return p.arena_element == "earth", 3.0)
