extends SceneTree
## Round 3's cast layer in the air (AIR; smash_r3 spec §0, §4.5, §4.6, §6.1-6.3, §8, §15 "AIR"), in Tidebreak's ring
## (scenes/ring.tscn, earth; the foe held where he stands). The % rules and the movement set are stood in by the test, so
## AIR's part runs on its own before PERCENT and MOVE merge: FakeRules (a RingRules with rule_set "stock", made the current
## one: the gate on; its hitstun_left, heal_allowed and patch the test's) and FakeMoves (a RingMoves on the player: airborne,
## can_cast, landing lag, the spout as the test says; dodge and land_lag recorded). The player's lock driven through his
## SwayCaster (held_override, quick_override, guard_override) and his hotbar's keys (Hotbar.select):
##   forms     a key-2 lock started on the deck and let go airborne is the Push; one started airborne is the Slam; landing
##             before its release calls it off for free; LMB started airborne is the air hit; LMB started on the deck and let
##             go airborne is the jab (decided at release); key 1 the same move either way
##   key 3     in the air RingMoves.dodge at once; on the deck the Dash goes at max(lock, 0.22 s); a second tap inside that is
##             the travel move; neither changes the readied move; air dodge, land, RMB casts the move readied before the jump;
##             1 readied by ready_default (the start, a respawn)
##   the Slam  its tag, set 0.30 s and -70 deg knock; bounce_once (earth 0.55) on a grounded body; the same space at pitch
##             +30 and -60; Downpour's puddle (a Geyser source); the Axe Kick's wave; Down Gust's lift once an airtime; the
##             Hammer with a held stone throws it
##   air attacks  key-1 attacks and Fire Breath fill/release in the air; a held ground lock keeps its progress on takeoff
##   ground moves  walls and healing keep their ground requirement, regardless of their key
##   release gates  grown auto-release waits for can_cast; a queued airborne release spends once after hitstun
##   land lag  a Punch landing within 0.35 s of its release plants 0.20 (0.10 after a hit); after it, or still locking, none;
##             during it a lock fills, key 3 and E wait
##   air fill  a water Lash at 4.5 m/s of drift fills at moving_mult; fire's Punch at full
##   hit info  from, air, volley_id and volley_n on every hit (Pebbles 3, Embers 7)
##   air guard an airborne earth catches a stone and throws it along the 3D aim; no landing lag from E
##   walls     placed at least 3.5 m inside every lip; Column and Geyser never from the tank's water
##   frozen    a grow lock held past its growth and hit at 0.9 s does not self-cast in a 1.0 s hitstun; a sputtering lock
##             does not fizzle in it; both go on after
##   tumbling E never raises the guard (nor after the tumble while E stays held)
##   macOS     an RMB press with ctrl held reads as LMB with RingMoves on the player, as RMB without
##   Patch     its 1.5 s lock fills only standing still and calls RingRules.patch; refused when heal_allowed is false
##   a fall    drop_all clears the lock and drops the held stone loose; ready_default readies key 1
##   the spout a lock's start leaves it
##   the Kick  at ring gravity a jump (apex 2.0) is missed from 0.07 to 0.82 s after takeoff, a short hop (0.8) from 0.14 to
##             0.43 s; its wave runs 0.3 m past the lip and hits a hanger's hands there
##   Breath    one smoke a caster at a time
##   the gate  with the fakes gone (the classic ring) key 3 readies as round 2 did and nothing of the above runs
## METRIC lines (key3_keeps_ready_ok, key2_form_at_start_ok, walls_off_lip_ok, lock_frozen_in_hitstun_ok, air_release_share).
## Last line "R3 AIR PASSED" or "R3 AIR FAILED"; exit 0 only on a pass; a watchdog quits with 2.
##   Godot --headless --fixed-fps 60 --path . -s tests/bending/test_r3_air.gd [-- only=air_attacks,release_gates,...]

const NAME := "R3 AIR"
const WATCHDOG_S := 600.0
const OWN_CFG := "user://r3_air_test.cfg"


## The % rules stood in (the gate on, hitstun and the heal the test's).
class FakeRules:
	extends RingRules
	var stun_until := {}
	var heal_ok := true
	var patched := 0

	func hitstun_left(b: Node) -> float:
		return maxf(float(stun_until.get(b.get_instance_id(), -INF)) - BendStatus.now(), 0.0)

	func stunned(b: Node) -> bool:
		return hitstun_left(b) > 0.0

	func heal_allowed(_b: Node) -> bool:
		return heal_ok

	func patch(_b: Node) -> float:
		patched += 1
		return 5.0


## The movement set stood in on the player.
class FakeMoves:
	extends RingMoves
	var air: Variant = null
	var cast_ok := true
	var lag := false
	var spout := false
	var left_spout_n := 0
	var dodges: Array = []
	var lags: Array = []

	func airborne() -> bool:
		if air != null:
			return bool(air)
		return body != null and not body.is_on_floor()

	func can_cast() -> bool:
		return cast_ok and not lag

	func in_landing_lag() -> bool:
		return lag

	func on_spout() -> bool:
		return spout

	func leave_spout() -> void:
		spout = false
		left_spout_n += 1

	func dodge(dir: Vector3) -> void:
		dodges.append(dir)

	func land_lag(s: float) -> void:
		lags.append(s)

	func profile() -> Dictionary:
		return {"self_up_mult": 1.43}

	## (the merge: MOVE's real mover is this class's parent now; the stand-in leaves the body to its own controller, as the
	## SEAMS stub did)
	func pre(_intent: Dictionary, _dt: float) -> bool:
		return false


var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var p: FrontierPlayer
var c: SwayCaster
var rm: RingMode
var foe: NpcFighter
var fbc: BodyBendCaster
var fr: FakeRules
var fm: FakeMoves
var was_rules: RingRules
var metrics := {}
var released: Array = []                ## [move, mode, BendStatus.now()] at each cast_released
var air_casts: Array = []
var _foe_at := Vector3.INF
var _hold_y := -INF
var _hold_v := Vector3.INF
var _foe_y := -INF
var only := ""


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	MatchSetup._aim_help = "strong"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			only = arg.get_slice("=", 1)
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
	# (the merge: rules.json plays stock by default; AIR's stand-ins (FakeRules) are this test's gate, the ring itself classic)
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


func _hold() -> void:
	if foe != null and is_instance_valid(foe):
		foe.held = true
		if _foe_at == Vector3.INF:
			_foe_at = foe.global_position
		foe.global_position = _foe_at if _foe_y == -INF else Vector3(_foe_at.x, _foe_y, _foe_at.z)
		foe.velocity = Vector3.ZERO
		foe.health = foe.health_max                  # (whole: the test's blows never end him)
	if p != null and _hold_y > -INF:
		p.global_position.y = _hold_y
		p.velocity.y = 0.0
	if p != null and _hold_v != Vector3.INF:
		p.velocity = Vector3(_hold_v.x, p.velocity.y, _hold_v.z)


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
	c.air_cast.connect(func(m: String, md: String) -> void: air_casts.append([m, md]))
	await _until(func() -> bool: return p.arena_element == "earth" and p.hotbar.spell != "", 6.0)
	rm = RingMode.find(self)
	if rm != null:
		await _until(func() -> bool: return rm.phase == "FIGHT", 10.0)
		foe = rm.foe
		rm.rules.soft_walls = false
	_expect(foe != null, "the foe")
	if foe == null:
		return _end()
	fbc = BendCaster.of(foe) as BodyBendCaster
	fbc.scatter_deg = 0.0
	fbc.lead = 0.0
	physics_frame.connect(_hold)
	await _secs(0.4)
	_fakes(true)
	for part in ["forms", "key3", "slam", "slam_touches", "paused_45", "ground_spells", "air_attacks", "spike_follow", "air_timing", "air_hud", "release_gates", "land_lag",
			"air_fill", "hit_info", "air_guard", "walls", "deck_only", "frozen", "tumble_e", "macos", "patch", "fall",
			"spout", "kick_jumps", "kick_lip", "breath", "gate_off"]:
		if only != "" and not part in only.split(","):
			continue
		await call("_" + part)
	_end()


func _end() -> void:
	if c != null:
		c.held_override = null
		c.quick_override = null
		c.guard_override = null
		c.stun_override = null
		c.tumble_override = null
	_fakes(false)
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


## The stand-ins on (the gate on: FakeRules current, FakeMoves on the player) or off (the ring's own rules again).
func _fakes(on: bool) -> void:
	if on:
		was_rules = RingRules.current()
		fr = FakeRules.new()
		fr.rule_set = "stock"
		RingRules._current = fr
		var old := p.get_node_or_null(RingMoves.NODE_NAME)
		if old != null:
			p.remove_child(old)
			old.queue_free()
		fm = FakeMoves.new()
		fm.name = RingMoves.NODE_NAME
		fm.body = p
		p.add_child(fm)
		return
	if fm != null and is_instance_valid(fm):
		p.remove_child(fm)
		fm.queue_free()
	fm = null
	if fr != null:
		RingRules._current = was_rules
		fr.free()
		fr = null


## The player whole and still at his spawn facing the foe (or `at`/`face`), as `el`, nothing bent about, every button let
## go, on the deck.
func _calm(el := "earth", at := Vector3.INF, face := Vector3.INF) -> void:
	c.held_override = false
	c.quick_override = false
	c.guard_override = false
	c.stun_override = null
	c.tumble_override = null
	_hold_y = -INF
	_hold_v = Vector3.INF
	_foe_y = -INF
	if fm != null:
		fm.air = false
		fm.lag = false
		fm.cast_ok = true
		fm.dodges.clear()
		fm.lags.clear()
	if fr != null:
		fr.stun_until.clear()
		fr.heal_ok = true
	if el != "" and p.arena_element != el:
		Bending.of(p).element = el
		await _until(func() -> bool: return p.arena_element == el, 3.0)
	await _ticks(2)
	c._wait_release = false
	c.drop_all()
	for g: StringName in [BendBolt.GROUP, BendZone.GROUP, FormRaised.GROUP, FormStone.GROUP, GustLift.GROUP, FormEffects.Throw.GROUP,
			BendEffects.Strike.GROUP]:
		for x in get_nodes_in_group(g):
			if is_instance_valid(x):
				x.queue_free()
	for b: Node in [p, foe]:
		for k: StringName in BendStatus.ROUND_METAS:
			if b.has_meta(k):
				b.remove_meta(k)
		for k: StringName in [&"bend_slam_lift", &"bend_whiff_until", FormEffects.RAISED_META]:
			if b.has_meta(k):
				b.remove_meta(k)
		var kn := BendKnock.peek(b)
		if kn != null:
			kn.reset()
	if at == Vector3.INF:
		RingLevel.place(p, rm.ring.spawn(rm.player_end))
	else:
		var f := (face if face != Vector3.INF else _foe_at - at)
		f.y = 0.0
		RingLevel.place(p, Transform3D(Basis.looking_at(f.normalized(), Vector3.UP), at))
	p.velocity = Vector3.ZERO
	p.health = p.max_health
	p.pitch = -0.08
	foe.health = foe.health_max
	if rm.phase == "FIGHT":
		rm.phase_t = 0.0                           # (the round's clock kept from running out under the test)
	(BendCaster.of(p) as PlayerBendCaster).held_override = null
	BendR3.hits_log.clear()
	released.clear()
	air_casts.clear()
	await _secs(0.45)


## The player 9 m before the foe on the line between the ends, facing him.
func _near_foe(el := "earth", d := 9.0) -> void:
	var axis := rm.ring.axis()
	var at := _foe_at - axis * signf(axis.dot(_foe_at - rm.ring.center())) * d
	at.y = rm.ring.deck_y()
	await _calm(el, at)


func _tap(i: int) -> void:
	p.hotbar.select(i)
	await physics_frame


func _ready_now() -> String:
	return "%s/%s" % [c.readied_spell, c.base_mode_of(c.readied_spell)]


## The player put in the air `h` m over the deck (held there), the fake saying so.
func _lift(h := 2.0) -> void:
	_hold_y = rm.ring.deck_y() + h
	p.global_position.y = _hold_y
	fm.air = true
	await _ticks(2)


## The camera's pitch turned onto the foe's chest (a player in the air aims down at him).
func _aim_foe() -> void:
	await _ticks(2)
	var cam := p.camera
	var d := NpcSenses.chest_of(foe) - cam.global_position
	p.pitch = asin(clampf(d.normalized().y, -1.0, 1.0))
	await _ticks(3)


## The player down on the deck again (the fake says he landed).
func _land() -> void:
	_hold_y = -INF
	p.global_position.y = rm.ring.deck_y() + 0.05
	fm.air = false
	await _ticks(2)


## The aim's (RMB) lock held until full (or `limit`): true when it is.
func _rmb_full(limit := 3.0) -> bool:
	c.held_override = true
	return await _until(func() -> bool: return c.state == SwayCaster.State.FULL, limit) < INF


func _last_rel() -> Array:
	return released.back() if not released.is_empty() else ["", "", -INF]


## The hits BendR3 delivered to `who` since the log was cleared.
func _hits_on(who: Node) -> Array:
	return BendR3.hits_log.filter(func(e: Dictionary) -> bool: return e.n == who)


# ---------------------------------------------------------------- the forms (spec §6.1)
func _forms() -> void:
	# key 2 started on the deck, let go in the air: the Push
	await _near_foe("earth")
	await _tap(1)
	var full := await _rmb_full(3.0)
	await _lift(2.0)
	c.held_override = false
	await _ticks(3)
	var r1 := _last_rel()
	_expect(full and r1[0] == "earth_shove" and r1[1] == "push", "a key-2 lock started on the deck and let go in the air is the Push (%s)" % [r1])
	await _land()
	# key 2 started in the air: the Slam
	await _near_foe("earth")
	await _tap(1)
	await _lift(2.0)
	c.held_override = true
	await _ticks(2)
	var form_slam := c.mode_of("earth_shove")
	await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 2.0)
	c.held_override = false
	await _secs(0.4)
	var r2 := _last_rel()
	var slam_rec := BendEffects.last_of(BendCaster.of(p))
	_expect(form_slam == "slam" and r2[1] == "slam" and String(slam_rec.get("do", "")) == "slam",
			"a key-2 lock started in the air is the Slam (lock %s, released %s, cast %s)" % [form_slam, r2, slam_rec.get("do", "")])
	# started in the air, landed before the release: called off, nothing spent
	await _near_foe("earth")
	await _tap(1)
	await _lift(2.0)
	c.held_override = true
	await _secs(0.15)
	var n0 := released.size()
	await _land()
	var off := c.state == SwayCaster.State.IDLE and c.last_break == "landed"
	c.held_override = false
	await _ticks(3)
	_expect(off and released.size() == n0, "landing before its release calls the Slam off for free (%s, %d casts)" % [c.last_break, released.size() - n0])
	metrics["key2_form_at_start_ok"] = full and form_slam == "slam" and off
	# LMB: started in the air the air hit; started on the deck and let go in the air the jab
	await _near_foe("earth")
	await _lift(2.0)
	c.quick_override = true
	await _ticks(2)
	var lmb_air := c.mode_of("rock_jab")
	await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 2.0)
	c.quick_override = false
	await _secs(0.3)
	var r3 := _last_rel()
	_expect(lmb_air == "air_hit" and r3[1] == "air_hit", "LMB started in the air is the air hit (%s, %s)" % [lmb_air, r3])
	await _near_foe("earth")
	c.quick_override = true
	await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 2.0)
	await _lift(2.0)
	c.quick_override = false
	await _secs(0.3)
	var r4 := _last_rel()
	_expect(r4[0] == "rock_jab" and r4[1] == "pebbles" and air_casts.size() >= 1,
			"LMB started on the deck and let go in the air is the jab, an air cast (%s, air casts %s)" % [r4, air_casts])
	await _land()
	# 2 tapped twice in the air: fire's High Kick a crescent along the aim (its air form), no lob
	await _near_foe("fire")
	await _tap(1)
	await _tap(1)
	await _secs(0.35)
	await _lift(2.0)
	p.pitch = -0.3
	await _ticks(3)
	c.held_override = true
	await _ticks(2)
	var hk_form := c.mode_of("fire_kick")
	await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 2.0)
	c.held_override = false
	await _until(func() -> bool: return not get_nodes_in_group(BendBolt.GROUP).is_empty(), 1.0)
	var aim_dir: Vector3 = BendCaster.of(p).aim_ray()[1]
	var along := -1.0
	for b in get_nodes_in_group(BendBolt.GROUP):
		along = maxf(along, (b as BendBolt).velocity.normalized().dot((BendCaster.of(p).aim_point() - (b as Node3D).global_position).normalized()))
	_expect(hk_form == "air_kick" and _last_rel()[1] == "air_kick" and along > 0.95 and aim_dir.y < 0.0,
			"2 tapped twice in the air: the High Kick's crescent along the 3D aim, no lob (%s; along %.2f)" % [hk_form, along])
	await _land()
	# key 1 in the air: the same move
	await _near_foe("earth")
	await _tap(0)
	await _lift(2.0)
	await _rmb_full(3.0)
	c.held_override = false
	await _secs(0.4)
	var r5 := _last_rel()
	_expect(r5[0] == "stone_form" and r5[1] == "spike", "key 1 in the air is the same move (%s)" % [r5])
	await _land()


# ---------------------------------------------------------------- key 3 (spec §0, §4.5, §4.6)
func _key3() -> void:
	await _near_foe("earth")
	await _tap(0)
	var before := _ready_now()
	# in the air: the dodge at once, a running lock dropped, the readied move kept
	await _lift(2.0)
	c.held_override = true
	await _secs(0.2)
	var locking := c.state != SwayCaster.State.IDLE
	await _tap(2)
	var dodged := fm.dodges.size() == 1 and c.state == SwayCaster.State.IDLE and c.last_key3 == "dodge"
	_expect(locking and dodged and _ready_now() == before, "3 in the air: RingMoves.dodge at once, the running lock dropped, %s still readied (%s)" % [before, _ready_now()])
	c.held_override = false
	await _ticks(2)
	# air dodge, land, RMB casts the move readied before the jump
	await _land()
	await _rmb_full(3.0)
	c.held_override = false
	await _secs(0.4)
	var r := _last_rel()
	_expect(r[0] == "stone_form", "air dodge, land, right-click casts the move readied before the jump (%s)" % [r])
	# on the deck: the Dash at max(lock, 0.22)
	await _near_foe("earth")
	await _tap(0)
	var t0 := BendStatus.now()
	await _tap(2)
	var lock := c.lock_s / maxf(c.passive_fill(), 0.01)
	await _until(func() -> bool: return not released.is_empty(), 2.0)
	var rd := _last_rel()
	var dt := float(rd[2]) - t0
	_expect(rd[0] == "earth_skate" and dt >= 0.22 - 0.02 and absf(dt - maxf(lock, 0.22)) <= 0.05 and _ready_now() == "stone_form/spike",
			"3 on the deck: the Dash goes at max(lock %.2f, 0.22) = %.2f s after the press (%.2f), the readied move kept (%s)" % [lock, maxf(lock, 0.22), dt, _ready_now()])
	# air's short lock: no sooner than 0.22
	await _near_foe("air")
	await _tap(0)
	var ra0 := _ready_now()
	t0 = BendStatus.now()
	await _tap(2)
	await _until(func() -> bool: return not released.is_empty(), 2.0)
	var ra := _last_rel()
	var dta := float(ra[2]) - t0
	_expect(ra[0] == "evade" and dta >= 0.21 and dta <= 0.3 and _ready_now() == ra0,
			"air's Slip (lock 0.15) still waits 0.22 s (%.2f), the readied move kept (%s)" % [dta, _ready_now()])
	# a second tap inside 0.22: the travel move
	await _near_foe("earth")
	await _tap(0)
	await _tap(2)
	await _secs(0.08)
	await _tap(2)
	await _until(func() -> bool: return not released.is_empty(), 3.0)
	var rt := _last_rel()
	_expect(rt[0] == "pillar" and c.last_key3 == "travel" and _ready_now() == "stone_form/spike",
			"a second 3 inside 0.22 s is the travel move (%s), the readied move kept (%s)" % [rt, _ready_now()])
	metrics["key3_keeps_ready_ok"] = dodged and _ready_now() == "stone_form/spike"
	# 1 readied at the start and after a respawn: ready_default
	await _near_foe("earth")
	await _tap(1)
	var was := _ready_now()
	c.ready_default()
	await _ticks(2)
	_expect(was.begins_with("earth_shove") and _ready_now() == "stone_form/spike", "ready_default readies key 1's first move (%s, then %s)" % [was, _ready_now()])


# ---------------------------------------------------------------- the Slam (spec §6.2)
## The player 2 m over the foe, `el`, the Slam cast at him: [its hits on the foe, the cast's record].
func _slam_at_foe(el: String, up := 2.0, pitch := -0.3) -> Array:
	await _calm(el, _foe_at + Vector3(0.6, 0.0, 0.0), _foe_at - (_foe_at + Vector3(0.6, 0, 0)) + Vector3(-1, 0, 0))
	p.global_position = _foe_at + Vector3(0.4, 0.0, 0.0)
	await _lift(up)
	p.global_position = Vector3(_foe_at.x + 0.4, _hold_y, _foe_at.z)
	p.pitch = pitch
	await _tap(1)
	var t0 := BendStatus.now()
	c.held_override = true
	await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 2.0)
	c.held_override = false
	await _secs(0.45)
	return [_hits_on(foe), BendEffects.last_of(BendCaster.of(p)), BendStatus.now() - t0]


func _slam() -> void:
	var r := await _slam_at_foe("earth")
	var hits: Array = r[0]
	var ok := hits.size() == 1
	var inf: Dictionary = hits[0].info if ok else {}
	var kv: Vector3 = hits[0].kv if ok else Vector3.ZERO
	var ang := rad_to_deg(atan2(kv.y, Vector2(kv.x, kv.z).length())) if ok else 0.0
	_expect(ok and String(inf.get("tag", "")) == "earth_shove/slam" and is_equal_approx(float(inf.get("set_stun", 0.0)), 0.3) and absf(ang + 70.0) < 1.0,
			"the Hammer hits once: tag earth_shove/slam, set 0.30 s, launched at %.1f deg (%s)" % [ang, inf.get("tag", "-")])
	_expect(ok and bool(inf.get("bounce_once", false)) and is_equal_approx(float(inf.get("bounce_k", 0.0)), 0.55) and is_equal_approx(float(inf.get("bounce_add", 0.0)), 2.0),
			"on a grounded body bounce_once (earth 0.55 x down + 2) for the rules")
	var air_r := await _slam_at_foe("air")
	var ah: Array = air_r[0]
	_expect(ah.size() == 1 and is_equal_approx(float(ah[0].info.get("bounce_k", 0.0)), 0.45),
			"air's Down Gust bounces at 0.45 (%s)" % [ah.map(func(e: Dictionary) -> float: return float(e.info.get("bounce_k", 0.0)))])
	# the same space at pitch +30 and -60
	await _calm("earth")
	await _lift(2.0)
	var bc := BendCaster.of(p)
	var spec: Dictionary = (SwayMoves.move("earth_shove").bend as Dictionary).slam
	p.pitch = deg_to_rad(30.0)
	await _ticks(2)
	var b1 := BendEffects.slam_box(bc, BendEffects.aim(bc, spec), spec)
	p.pitch = deg_to_rad(-60.0)
	await _ticks(2)
	var b2 := BendEffects.slam_box(bc, BendEffects.aim(bc, spec), spec)
	_expect((b1.foot as Vector3).distance_to(b2.foot) < 0.05 and absf(float(b1.length) - float(b2.length)) < 0.01,
			"the Slam's space the same at pitch +30 and -60 (feet %s / %s)" % [b1.foot, b2.foot])
	await _land()


func _slam_touches() -> void:
	# Downpour over the deck: a puddle (a Geyser source of his)
	var w := await _slam_at_foe("water")
	var rec: Dictionary = w[1]
	var pud: Variant = rec.get("puddle")
	_expect(pud is BendZone and is_instance_valid(pud) and (pud as BendZone).is_in_group(Bending.POOLS) and BendEffects._source_near(p, (pud as BendZone).global_position, 1.0),
			"Downpour leaves a puddle on the deck, a Geyser source (%s)" % [pud])
	# the Axe Kick's wave
	var f := await _slam_at_foe("fire")
	var wave: Variant = (f[1] as Dictionary).get("wave")
	_expect(wave is BendBolt and (wave as BendBolt).floor_wave and is_equal_approx((wave as BendBolt).range_m, 6.0),
			"the Axe Kick runs on as a 6 m floor wave (%s)" % [wave])
	# Down Gust: the lift once an airtime
	await _calm("air", _foe_at + Vector3(4.0, 0, 0))
	await _lift(3.0)
	_hold_y = -INF                                   # (free: the lift is seen in his velocity)
	await _tap(1)
	var lifts := 0
	for i in 2:
		p.velocity.y = 0.0
		c.held_override = true
		await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 2.0)
		c.held_override = false
		await _secs(0.3)
		if bool(BendEffects.last_of(BendCaster.of(p)).get("lifted", false)):
			lifts += 1
		_hold_y = p.global_position.y
		await _ticks(2)
		_hold_y = -INF
	_expect(lifts == 1, "Down Gust lifts him once an airtime (%d lifts in two Slams)" % lifts)
	await _land()
	# the Hammer with a held stone throws it
	await _calm("earth", _foe_at + Vector3(4.0, 0, 0))
	var bc := BendCaster.of(p)
	var held := BendR3.pop_stone(bc)
	var had := held != null                  # (taken now: in the ring the thrown stone bursts on what it meets, gone after)
	await _lift(2.0)
	await _tap(1)
	await _rmb_full(2.0)
	c.held_override = false
	await _secs(0.35)
	var hr := BendEffects.last_of(bc)
	_expect(had and String(hr.get("how", "")) == "held" and hr.has("throw") and BendZone.held_stone(p) == null,
			"the Hammer holding a stone throws it instead (%s, throw %s, still held %s)" % [hr.get("how", "-"), hr.get("throw"), BendZone.held_stone(p)])
	await _land()


# ---------------------------------------------------------------- 4 and 5 (spec §6.1)
func _paused_45() -> void:
	await _near_foe("earth")
	await _tap(3)
	c.held_override = true
	await _secs(0.4)
	var f0 := c.fill
	await _lift(1.5)
	var f1 := c.fill
	await _secs(0.5)
	var f2 := c.fill
	await _land()
	await _secs(0.3)
	var f3 := c.fill
	_expect(f0 > 0.1 and absf(f2 - f1) < 0.02 and f3 > f2 + 0.05, "key 4's lock waits in the air and goes on from the same fill on landing (%.2f, %.2f..%.2f, %.2f)" % [f0, f1, f2, f3])
	c.held_override = false
	await _ticks(3)


# ---------------------------------------------------------------- airborne attack releases (the owner's jump-casting request)
func _ground_spells() -> void:
	for el: String in ["earth", "water", "fire", "air"]:
		await _near_foe(el)
		await _tap(3)
		var wanted := c.readied_spell
		var full := await _rmb_full(3.5)
		await _lift(1.5)
		c.held_override = false
		await _secs(0.3)
		var waiting := released.is_empty() and c.state == SwayCaster.State.FULL and c.fill == 1.0
		await _land()
		await _secs(0.2)
		_expect(full and waiting and released.size() == 1 and _last_rel()[0] == wanted and air_casts.is_empty(),
				"%s wall keeps a full airborne release queued until landing (%s, %s)" % [el, waiting, released])
	await _near_foe("earth")
	await _tap(4)
	await _lift(1.5)
	var patched_before := fr.patched
	c.held_override = true
	await _secs(0.4)
	_expect(c.state == SwayCaster.State.IDLE and fr.patched == patched_before and released.is_empty(),
			"Patch cannot start or heal in the air")
	c.held_override = false
	await _land()


func _air_attacks() -> void:
	for el: String in ["earth", "water", "fire", "air"]:
		await _near_foe(el, 5.0)
		await _tap(0)
		var wanted := c.readied_spell
		await _lift(1.5)
		await _aim_foe()
		var full := await _rmb_full(2.5)
		c.held_override = false
		await _secs(0.15)
		_expect(full and released.size() == 1 and _last_rel()[0] == wanted and air_casts.size() == 1,
				"%s key-1 attack fills and releases once airborne (%s)" % [el, released])
	# Breath shares key 4 with a wall, but is an aimed attack; its key must not require the floor.
	await _near_foe("fire", 3.0)
	await _tap(3)
	await _tap(3)
	var selected := c.readied_spell == "fire_breath"
	c.held_override = true
	await _secs(0.15)
	var before := c.fill
	await _lift(1.2)
	var after := c.fill
	var full := await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 1.0) < INF
	c.held_override = false
	await _secs(0.15)
	_expect(selected and before > 0.0 and after >= before and full and released.size() == 1
			and _last_rel()[0] == "fire_breath" and air_casts.size() == 1,
			"Fire Breath keeps its charge through takeoff and releases airborne (%.2f -> %.2f; %s)" % [before, after, released])
	await _secs(0.35)
	var rec := BendEffects.last_of(BendCaster.of(p))
	_expect(String(rec.get("do", "")) == "cone" and String(rec.get("move", "")) == "fire_breath",
			"airborne Breath reaches the attack effect (%s)" % [rec.get("move", "-")])
	c.held_override = true
	full = await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 1.0) < INF
	c.held_override = false
	await _secs(0.15)
	_expect(full and released.size() == 2 and air_casts.size() == 2,
			"a fresh Fire Breath lock also starts and releases entirely in the air (%s)" % [released])
	await _land()


func _spike_follow() -> void:
	for start_in_air: bool in [false, true]:
		await _near_foe("earth", 6.0)
		p.global_rotation.y += PI * 0.5
		p.pitch = 0.3
		await _tap(0)
		if start_in_air:
			await _lift(1.5)
		var full := await _rmb_full(2.0)
		var th := FormEffects.raised_of(p)
		if not start_in_air:
			await _lift(1.5)
		await _secs(0.1)
		var held_y := th.stone.global_position.y - p.global_position.y if is_instance_valid(th) and is_instance_valid(th.stone) else -INF
		_expect(full and absf(held_y - 1.3) < 0.15,
				"Spike raised %s follows the airborne caster's hands (stone %.3f m above feet)" % ["in air" if start_in_air else "before takeoff", held_y])
		c.held_override = false
		var launched := await _until(func() -> bool: return is_instance_valid(th) and th.is_thrown, 0.6) < INF
		var launch_at := th.stone.global_position if launched and is_instance_valid(th.stone) else Vector3.INF
		var in_flight := launched and is_instance_valid(th.lift) and th.lift.phase == GustLift.Phase.FLIGHT
		var direction := th.lift.velocity.normalized() if in_flight else Vector3.ZERO
		var aim := (th.target - launch_at).normalized() if launched else Vector3.ZERO
		await _secs(0.1)
		var traveled := launch_at.distance_to(th.stone.global_position) if launched and is_instance_valid(th) and is_instance_valid(th.stone) else 0.0
		_expect(in_flight and launch_at.y > rm.ring.deck_y() + 2.5 and direction.dot(aim) > 0.995 and traveled > 2.0,
				"Spike %s actually launches above deck toward its crosshair and travels (height %.3f, alignment %.4f, travel %.2f m)"
				% ["started in air" if start_in_air else "charged before jump", launch_at.y - rm.ring.deck_y(), direction.dot(aim), traveled])
		await _land()


func _air_timing() -> void:
	# Natural jump timing is checked separately with real inputs; here drift and charge accounting are isolated.
	await _near_foe("earth")
	await _tap(0)
	await _lift(1.5)
	c.speed_override = 4.5
	var started := BendStatus.now()
	var full := await _rmb_full(1.0)
	var elapsed := BendStatus.now() - started
	_expect(full and elapsed >= 0.5 and elapsed <= 0.68 and is_equal_approx(c.lock_s, 0.6),
			"moving airborne Spike completes in a usable jump window (%.3f s, lock %.3f)" % [elapsed, c.lock_s])
	# A completed short lock that lands owes the remaining ground time, but keeps its already elapsed release window.
	await _secs(0.2)
	c.stun_override = 1.0
	var timer := c.full_t
	var raised_before := c.raised
	var began := c.lock_began_at
	var source := c.lock_src
	var uses_before := c.uses_of("stone_form")
	c._queued = true
	fm.air = false
	c._r3_tick()
	_expect(c.state == SwayCaster.State.LOCKING and is_equal_approx(c.lock_s, 1.1)
			and is_equal_approx(c.fill * c.lock_s + c._air_charge_extra, 0.6) and is_equal_approx(c.full_t, timer)
			and c.raised == raised_before and c.lock_began_at == began and c.lock_src == source and c._queued
			and c.uses_of("stone_form") == uses_before,
			"landing keeps .60 earned seconds, pending release, stone, source and release-window timer without a free cast")
	var switched := c.step_other()
	_expect(switched and c.mode_of("stone_form") == "cannonball" and is_equal_approx(c.lock_s, 1.1)
			and is_equal_approx(c.fill * c.lock_s, 0.6),
			"landing then switching to Boulder cannot turn .60s of Spike charge into 1.10s")
	c.speed_override = null
	c.stun_override = null
	c.drop_all()
	c.held_override = false
	await _land()
	# If landing makes a full air lock incomplete, reaching full again must not grant a new release window.
	await _near_foe("earth")
	await _tap(0)
	await _lift(1.5)
	full = await _rmb_full(1.0)
	await _secs(0.2)
	timer = c.full_t
	fm.air = false
	c._r3_tick()
	var refilled := await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 1.0) < INF
	_expect(full and refilled and c.full_t >= timer and c.full_t <= timer + 0.03,
			"refilling after landing retains the elapsed release window (%.3f -> %.3f s)" % [timer, c.full_t])
	c.drop_all()
	c.held_override = false
	await _land()
	# A full ground charge is retained through repeated jumps; the shorter air lock must not discard its extra credit.
	await _near_foe("earth")
	await _tap(0)
	full = await _rmb_full(2.0)
	await _secs(0.2)
	timer = c.full_t
	c.stun_override = 1.0
	var same := full
	for i in 3:
		fm.air = true
		c._r3_tick()
		same = same and is_equal_approx(c.fill * c.lock_s + c._air_charge_extra, 1.1) and is_equal_approx(c.full_t, timer)
		fm.air = false
		c._r3_tick()
		same = same and c.state == SwayCaster.State.FULL and is_equal_approx(c.fill * c.lock_s, 1.1) and is_equal_approx(c.full_t, timer)
	_expect(same and released.is_empty(), "repeated takeoff/landing neither creates nor loses a full ground charge or resets its timer")
	c.stun_override = null
	c.drop_all()
	c.held_override = false
	# Boulder retains its moving penalty and lock in the air.
	await _near_foe("earth")
	await _tap(0)
	await _tap(0)
	await _lift(1.5)
	c.speed_override = 4.5
	c.held_override = true
	await _secs(0.3)
	_expect(c.mode_of("stone_form") == "cannonball" and is_equal_approx(c.lock_s, 1.1)
			and c.fill < 0.2 and is_equal_approx(c._moving_mult("stone_form"), 0.5),
			"Boulder keeps its original 1.10s lock and moving penalty in air (fill %.3f)" % c.fill)
	c.speed_override = null
	c.held_override = false
	c.drop_all()
	await _land()


func _air_hud() -> void:
	await _near_foe("fire")
	var strip := p.hud.bend_strip
	strip.air_override = true
	await _tap(3)
	strip.refresh()
	var wall := strip.column(3)
	_expect(wall.id == "fire_wall" and bool(wall.grey) and wall.sub == "lands" and not bool(wall.readied),
			"airborne HUD defers the actual Fire Wall")
	await _tap(3)
	strip.refresh()
	var breath := strip.column(3)
	var heal := strip.column(4)
	_expect(breath.id == "fire_breath" and not bool(breath.grey) and breath.sub != "lands" and bool(breath.readied),
			"airborne HUD keeps selected Breath usable and highlighted")
	_expect(bool(heal.grey) and heal.sub == "lands", "airborne HUD still defers healing")
	var instructions := " ".join(KitWords.rule_lines())
	_expect(instructions.contains("Attack while jumping") and instructions.contains("Walls and healing need ground"),
			"active kit help explains air attacks and the ground requirement")
	strip.air_override = null
	strip.refresh()


func _release_gates() -> void:
	# A held grow move's automatic release must use the same movement gate as a manual release.
	await _near_foe("fire")
	await _tap(0)
	var full := await _rmb_full(2.0)
	fm.cast_ok = false
	await _secs(1.5)
	var waiting := released.is_empty() and c.state == SwayCaster.State.FULL
	fm.cast_ok = true
	await _secs(0.15)
	var once := released.size() == 1
	await _secs(0.25)
	_expect(full and waiting and once and released.size() == 1,
			"grown automatic release waits for can_cast, then goes once without starting a free second lock (%s, %s)" % [waiting, released])
	# A release in hitstun remains queued and costs exactly one cast, even after taking off.
	await _near_foe("fire", 3.0)
	await _tap(3)
	await _tap(3)
	SwayCaster.free_override = false
	# The shipped ring attacks cost zero. Give this fixture one mote to verify the shared paid-cast path too.
	var breath_data := SwayMoves.move("fire_breath")
	var saved_cost: Variant = breath_data.get("motes", 0)
	breath_data["motes"] = 1
	var had_grant := c.granted.has("fire_breath")
	c.grant("fire_breath", false)
	c.set_uses("fire_breath", 100)
	c.set_motes(c.belt_max)
	var cost := SwayCaster.cost_of("fire_breath")
	var motes_before := c.motes
	var uses_before := c.uses_of("fire_breath")
	full = await _rmb_full(2.0)
	await _lift(1.2)
	c.stun_override = 0.5
	c.held_override = false
	await _secs(0.25)
	var untouched := released.is_empty() and c.motes == motes_before and c.uses_of("fire_breath") == uses_before
	c.stun_override = 0.0
	await _secs(0.15)
	var paid_once := c.motes == motes_before - cost and c.uses_of("fire_breath") == uses_before + 1
	await _secs(0.25)
	_expect(full and cost > 0 and untouched and paid_once and released.size() == 1 and air_casts.size() == 1,
			"airborne Breath waits through stun and spends/counts exactly once afterward (cost %d, unchanged %s, paid once %s, %s)"
			% [cost, untouched, paid_once, released])
	SwayCaster.free_override = true
	breath_data["motes"] = saved_cost
	if not had_grant:
		c.granted.erase("fire_breath")
	c.stun_override = null
	await _land()


# ---------------------------------------------------------------- landing lag (spec §6.3)
## Fire's Punch let go in the air, the landing `after` s later: the lag RingMoves was asked for (-1 none).
func _punch_land(after: float, aim_foe: bool) -> float:
	await _near_foe("fire", 3.0 if aim_foe else 9.0)
	if not aim_foe:
		p.global_rotation.y += PI * 0.5
		p.pitch = 0.6
	await _tap(0)
	await _lift(1.0)
	if aim_foe:
		await _aim_foe()
	await _rmb_full(2.0)
	c.held_override = false
	await _ticks(1)
	await _secs(after)
	await _land()
	return float(fm.lags.back()) if not fm.lags.is_empty() else -1.0


func _land_lag() -> void:
	var miss := await _punch_land(0.2, false)
	_expect(is_equal_approx(miss, 0.2), "a Punch landing within 0.35 s of its release plants 0.20 s (%.2f)" % miss)
	var hit := await _punch_land(0.3, true)
	_expect(is_equal_approx(hit, 0.1), "after a hit, 0.10 s (%.2f)" % hit)
	var late := await _punch_land(0.5, false)
	_expect(late < 0.0, "landing after its out window: no lag (%.2f)" % late)
	# still locking when he lands: none
	await _near_foe("fire")
	await _tap(0)
	await _lift(1.0)
	c.held_override = true
	await _secs(0.1)
	await _land()
	_expect(fm.lags.is_empty(), "landing while still locking: no lag (%s)" % [fm.lags])
	c.held_override = false
	await _ticks(3)
	# during it: a lock fills; 3 and E wait
	await _near_foe("earth")
	fm.lag = true
	await _tap(0)
	c.held_override = true
	await _secs(0.3)
	var filling := c.fill > 0.1
	c.held_override = false
	await _ticks(2)
	c.drop_all()
	await _tap(2)
	var waits3 := c.state == SwayCaster.State.IDLE and fm.dodges.is_empty() and c._buf3
	c.guard_override = true
	await _secs(0.3)
	var no_guard := not c.guard_up() and c.lock_src != SwayCaster.SRC_GUARD
	c.guard_override = false
	fm.lag = false
	await _secs(0.4)
	_expect(filling and waits3 and no_guard and c.last_key3 == "dash",
			"in landing lag a lock fills (%s), 3 waits and goes after (%s, %s), E waits (%s)" % [filling, waits3, c.last_key3, no_guard])


# ---------------------------------------------------------------- air fill (spec §6.1)
func _air_fill() -> void:
	await _near_foe("water")
	await _tap(0)
	await _lift(1.5)
	_hold_v = Vector3(4.5, 0.0, 0.0)
	c.held_override = true
	await _secs(0.2)
	var water_rate := c.fill / 0.2 * c.lock_s
	c.held_override = false
	await _ticks(2)
	c.drop_all()
	await _land()
	await _near_foe("fire")
	await _tap(0)
	await _lift(1.5)
	_hold_v = Vector3(4.5, 0.0, 0.0)
	c.held_override = true
	await _secs(0.15)
	var fire_rate := c.fill / 0.15 * c.lock_s
	c.held_override = false
	_hold_v = Vector3.INF
	await _ticks(2)
	c.drop_all()
	await _land()
	var mm := float(SwayMoves.move("water_whip").get("moving_mult", 0.75))
	_expect(absf(water_rate - mm) < 0.1 and absf(fire_rate - 1.0) < 0.1,
			"in the air at 4.5 m/s a water Lash fills at moving_mult %.2f (%.2f), fire's Punch at full (%.2f)" % [mm, water_rate, fire_rate])


# ---------------------------------------------------------------- the hit info (spec §14.3)
func _hit_info() -> void:
	await _near_foe("earth", 6.0)
	c.quick_override = true
	await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 2.0)
	c.quick_override = false
	await _secs(0.6)
	var hs := _hits_on(foe)
	var ok := not hs.is_empty()
	for e: Dictionary in hs:
		var inf: Dictionary = e.info
		ok = ok and inf.get("from") is Vector3 and inf.has("air") and int(inf.get("volley_id", 0)) > 0 and int(inf.get("volley_n", 0)) == 3 \
				and String(inf.get("tag", "")) == "rock_jab/pebbles"
	_expect(ok, "Pebbles: every hit carries from, air, its volley's id and n 3 (%d hits)" % hs.size())
	await _near_foe("fire", 5.0)
	c.quick_override = true
	await _until(func() -> bool: return c.state == SwayCaster.State.FULL, 2.0)
	c.quick_override = false
	await _secs(0.6)
	var he := _hits_on(foe)
	var vids := {}
	for e: Dictionary in he:
		vids[int(e.info.get("volley_id", 0))] = int(e.info.get("volley_n", 0))
	_expect(not he.is_empty() and vids.size() == 1 and vids.values()[0] == 7, "Embers: one volley id over its sparks, n 7 (%d hits, %s)" % [he.size(), vids])
	# let go in the air: air true
	await _near_foe("fire", 6.0)
	await _tap(0)
	await _lift(0.8)
	await _aim_foe()
	await _rmb_full(2.0)
	c.held_override = false
	await _secs(0.5)
	var ha := _hits_on(foe)
	_expect(not ha.is_empty() and bool(ha[0].info.get("air", false)) and String(ha[0].info.get("tag", "")) == "fire_blast/punch",
			"a Punch let go in the air carries air (%s)" % [ha.map(func(e: Dictionary) -> String: return "%s air %s" % [e.tag, e.info.get("air")])])
	await _land()


# ---------------------------------------------------------------- the air guard (spec §4.4)
func _air_guard() -> void:
	await _near_foe("earth", 9.0)
	await _lift(1.0)
	c.guard_override = true
	await _until(func() -> bool: return c.guard_up(), 1.0)
	c.guard_override = false
	var dir := (p.global_position + Vector3.UP * 1.2 - NpcSenses.chest_of(foe)).normalized()
	BendBolt.launch(foe, p.global_position + Vector3.UP * 1.2 - dir * 4.0, dir, {"kind": "stone", "mps": 30.0, "damage": 20.0,
			"knock_mps": 6.0, "radius_m": 0.25, "range_m": 30.0})
	var caught := await _until(func() -> bool: return BendZone.held_stone(p) != null, 1.0) < INF
	await _secs(0.3)
	p.pitch = -0.4
	await _ticks(2)
	var aim_y := (BendCaster.of(p).aim_ray()[1] as Vector3).y
	c.guard_override = true
	await _until(func() -> bool: return BendZone.held_stone(p) == null, 1.5)
	c.guard_override = false
	var rec := BendEffects.last_of(BendCaster.of(p))
	var th: Variant = rec.get("throw")
	var down := false
	if th is FormEffects.Throw and is_instance_valid(th):
		await _until(func() -> bool: return (th as FormEffects.Throw).is_thrown, 0.6)
		var lift: GustLift = (th as FormEffects.Throw).lift
		down = lift != null and is_instance_valid(lift) and lift.velocity.y < 0.0
	await _land()
	_expect(caught and String(rec.get("do", "")) == "return" and down and aim_y < 0.0 and fm.lags.is_empty(),
			"in the air earth catches a stone and E throws it along the 3D aim (down %s), no landing lag from E (%s)" % [down, fm.lags])


# ---------------------------------------------------------------- walls 3.5 m off every lip (spec §5.2)
func _walls() -> void:
	var ar := rm.ring
	var ok := true
	var worst := INF
	var hl := ar.half_l()
	var hw := ar.half_w()
	for spot: Vector3 in [Vector3(hl - 1.0, 0, 0), Vector3(-hl + 1.0, 0, 2.0), Vector3(0, 0, hw - 1.0), Vector3(5.0, 0, -hw + 1.0), Vector3(hl - 1.0, 0, hw - 1.0)]:
		var at := ar.to_global(Vector3(spot.x, ar.top(), spot.z))
		var lip := ar.nearest_lip(at)
		await _calm("earth", at, lip.normal as Vector3)
		var pt := FormEffects.place_point(BendCaster.of(p), {"min_m": 2.0, "max_m": 6.0})
		var l := ar.to_local(pt)
		var clear := minf(hl - absf(l.x), hw - absf(l.z))
		worst = minf(worst, clear)
		ok = ok and clear >= 3.5 - 0.01
	_expect(ok, "every wall's place stands at least 3.5 m inside every lip (the nearest %.2f m)" % worst)
	# a real one: earth's wall cast at the lip facing out
	var at2 := ar.to_global(Vector3(hl - 1.0, ar.top(), 0.0))
	await _calm("earth", at2, ar.nearest_lip(at2).normal as Vector3)
	await _tap(3)
	await _rmb_full(4.0)
	c.held_override = false
	await _secs(0.4)
	var wall: FormRaised = null
	for w in get_nodes_in_group(FormRaised.GROUP):
		wall = w as FormRaised
	var wl := ar.to_local(wall.global_position) if wall != null else Vector3(INF, 0, 0)
	var wclear := minf(hl - absf(wl.x), hw - absf(wl.z))
	_expect(wall != null and wclear >= 3.5 - 0.3, "an earth wall cast at the lip facing the water stands %.2f m inside" % wclear)
	metrics["walls_off_lip_ok"] = ok and wall != null and wclear >= 3.2


# ---------------------------------------------------------------- Column and Geyser on the deck (spec §6.1)
func _deck_only() -> void:
	var ar := rm.ring
	var at := ar.to_global(Vector3(ar.half_l() - 2.0, ar.top(), 0.0))
	await _calm("water", at, ar.nearest_lip(at).normal as Vector3)
	p.pitch = -0.25
	var bc := BendCaster.of(p)
	var spec: Dictionary = (SwayMoves.move("wave").bend as Dictionary).spout
	var a := BendEffects.aim(bc, spec)
	var raw := BendEffects._ground_at(p, a, spec)
	var kept := BendEffects._deck_at(p, raw)
	var l := ar.to_local(kept)
	var out_raw := BendR3.past_lip(self, raw)
	_expect(out_raw > 0.0 and ar.half_l() - absf(l.x) >= 0.59 and absf(l.y - ar.top()) < 0.05,
			"a Geyser aimed at the tank's water rises on the deck instead (aimed %.1f m out, kept %.2f m in)" % [out_raw, ar.half_l() - absf(l.x)])


# ---------------------------------------------------------------- the lock frozen in hitstun (spec §3.2)
func _frozen() -> void:
	# a grow lock (Shove ▲) held past its growth, hit at 0.9 s of full: no self-cast during a 1.0 s hitstun
	await _near_foe("earth")
	await _tap(1)
	await _rmb_full(2.0)
	await _secs(0.9)
	var grown := c.grown
	var n0 := released.size()
	fr.stun_until[p.get_instance_id()] = BendStatus.now() + 1.0
	await _secs(0.95)
	var during := released.size() == n0 and c.state == SwayCaster.State.FULL
	await _secs(0.4)
	var after := released.size() == n0 + 1
	c.held_override = false
	await _ticks(3)
	_expect(grown and during and after, "a grown lock held to 0.9 s and hit does not cast itself in a 1.0 s hitstun (%s), then does (%s)" % [during, after])
	# a sputtering lock does not fizzle in it
	await _near_foe("water")
	await _tap(0)
	await _rmb_full(2.0)
	await _secs(0.8)
	var sput := c._sputtered
	fr.stun_until[p.get_instance_id()] = BendStatus.now() + 1.0
	await _secs(0.95)
	var kept := c.state == SwayCaster.State.FULL and c.last_break != "fizzled"
	await _secs(0.4)
	var fizzled := c.last_break == "fizzled"
	c.held_override = false
	await _ticks(3)
	_expect(sput and kept and fizzled, "a sputtering lock waits through the hitstun (%s) and fizzles after (%s)" % [kept, fizzled])
	# the fill frozen; a release made in it goes on the first free frame
	await _near_foe("earth")
	await _tap(0)
	c.held_override = true
	await _secs(0.3)
	var f0 := c.fill
	fr.stun_until[p.get_instance_id()] = BendStatus.now() + 0.6
	await _secs(0.3)
	var f1 := c.fill
	c.held_override = false
	await _secs(0.2)
	var none_yet := released.is_empty() and c.state != SwayCaster.State.IDLE
	await _until(func() -> bool: return not released.is_empty(), 2.0)
	_expect(is_equal_approx(f0, f1) and none_yet and not released.is_empty(),
			"in hitstun the fill waits (%.2f, %.2f) and a release made then goes once he is free (%s)" % [f0, f1, released])
	metrics["lock_frozen_in_hitstun_ok"] = during and after and kept and is_equal_approx(f0, f1)


# ---------------------------------------------------------------- E while tumbling (spec §3.2)
func _tumble_e() -> void:
	await _near_foe("earth")
	c.tumble_override = true
	c.guard_override = true
	await _secs(0.4)
	var none := not c.guard_up() and c.state == SwayCaster.State.IDLE
	c.tumble_override = false
	await _secs(0.4)
	var still := not c.guard_up()
	c.guard_override = false
	await _ticks(3)
	c.guard_override = true
	var up := await _until(func() -> bool: return c.guard_up(), 1.0) < INF
	c.guard_override = false
	await _ticks(3)
	_expect(none and still and up, "E while tumbling never raises the guard (%s), nor after while held (%s); pressed fresh it does (%s)" % [none, still, up])


# ---------------------------------------------------------------- macOS ctrl + right click (spec §4.3)
func _press_rmb(on: bool, ctrl: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = on
	ev.ctrl_pressed = ctrl
	Input.parse_input_event(ev)
	await _ticks(2)


func _macos() -> void:
	await _near_foe("earth")
	c.held_override = null
	c.quick_override = null
	await _press_rmb(true, true)
	await _ticks(2)
	var as_lmb := c.lock_src == SwayCaster.SRC_QUICK and c.state != SwayCaster.State.IDLE and not c._held()
	await _press_rmb(false, false)
	await _ticks(3)
	c.drop_all()
	_fakes(false)
	await _press_rmb(true, true)
	await _ticks(2)
	var as_rmb := c.lock_src == SwayCaster.SRC_AIM and c._held()
	await _press_rmb(false, false)
	await _ticks(3)
	_fakes(true)
	_expect(as_lmb and as_rmb, "ctrl+right-click reads as LMB with RingMoves on the player (%s), as RMB without (%s)" % [as_lmb, as_rmb])
	await _calm("earth")


# ---------------------------------------------------------------- Patch (spec §8)
func _patch() -> void:
	await _near_foe("earth")
	await _tap(4)
	_expect(c.readied_spell == "patch", "5 readies Patch (%s)" % c.readied_spell)
	c.speed_override = 3.0
	c.held_override = true
	await _secs(0.5)
	var moving := c.fill
	c.speed_override = 0.0
	var p0 := fr.patched
	var want := c.lock_s / maxf(c.passive_fill(), 0.01) * (1.0 - moving)
	var t := await _until(func() -> bool: return fr.patched > p0, 3.0)
	c.speed_override = null
	c.held_override = false
	await _ticks(3)
	_expect(moving < 0.02 and absf(t - want) < 0.1, "Patch fills only standing still (%.2f moving) in its 1.5 s lock (x the tier and Rooted: %.2f; %.2f) and calls RingRules.patch" % [moving, want, t])
	_expect(absf(c.lock_s - 1.5 * c.tier_mult("patch")) < 0.01 or fr.patched > p0, "Patch's lock is ring_lock_s 1.5 x the tier")
	fr.heal_ok = false
	c.held_override = true
	await _secs(0.4)
	var refused := c.state == SwayCaster.State.IDLE
	c.held_override = false
	fr.heal_ok = true
	await _ticks(3)
	_expect(refused, "Patch refused while RingRules.heal_allowed is false (%s)" % c.state)


# ---------------------------------------------------------------- a fall (spec §7.2)
func _fall() -> void:
	await _near_foe("earth")
	var held := BendR3.pop_stone(BendCaster.of(p))
	await _tap(1)
	c.held_override = true
	await _secs(0.2)
	var locking := c.state != SwayCaster.State.IDLE
	c.drop_all()
	await _ticks(2)
	var loose := held != null and is_instance_valid(held) and not held.has_meta(&"bend_held_by") and held.has_meta(FormStone.LOOSE_META)
	_expect(locking and c.state == SwayCaster.State.IDLE and BendZone.held_stone(p) == null and loose,
			"drop_all clears the lock and drops the held stone loose (%s, %s)" % [c.state, loose])
	c.held_override = false
	await _ticks(3)


# ---------------------------------------------------------------- the spout (spec §7.2)
func _spout() -> void:
	await _near_foe("earth")
	fm.spout = true
	c.held_override = true
	await _secs(0.1)
	_expect(fm.left_spout_n == 1 and not fm.spout and c.state != SwayCaster.State.IDLE, "a lock's start leaves the spout and locks at once (%d)" % fm.left_spout_n)
	c.held_override = false
	await _ticks(3)
	c.drop_all()


# ---------------------------------------------------------------- the Kick at ring gravity (spec §4.1)
## Whether the Kick's wave strikes the foe held with his feet `h` m over the deck.
func _wave_hits(h: float) -> bool:
	await _near_foe("fire", 6.0)
	_foe_y = rm.ring.deck_y() + h
	await _ticks(2)
	var spec: Dictionary = (SwayMoves.move("fire_kick").bend as Dictionary).kick
	var s := spec.duplicate()
	s["_info"] = {"tag": "fire_kick/kick"}
	BendEffects.floor_wave(BendCaster.of(p), {}, s)
	await _secs(0.6)
	var hit := not _hits_on(foe).is_empty()
	_foe_y = -INF
	return hit


func _kick_jumps() -> void:
	var g := 20.0
	var v_jump := sqrt(2.0 * g * 2.0)
	var v_hop := sqrt(2.0 * g * 0.8)
	var h := func(v: float, t: float) -> float: return v * t - 0.5 * g * t * t
	var res := {}
	var ok := true
	for pair: Array in [["jump", v_jump, 0.05, true], ["jump", v_jump, 0.09, false], ["jump", v_jump, 0.80, false], ["jump", v_jump, 0.85, true],
			["hop", v_hop, 0.12, true], ["hop", v_hop, 0.16, false], ["hop", v_hop, 0.41, false], ["hop", v_hop, 0.45, true]]:
		var height: float = h.call(float(pair[1]), float(pair[2]))
		var hit := await _wave_hits(height)
		res["%s %.2f s (%.2f m)" % [pair[0], pair[2], height]] = hit
		ok = ok and hit == bool(pair[3])
	_expect(ok, "at ring gravity the Kick misses a jump from 0.07 to 0.82 s and a short hop from 0.14 to 0.43 s %s" % [res])


func _kick_lip() -> void:
	var ar := rm.ring
	var end := ar.to_global(Vector3(ar.half_l() - 5.0, ar.top(), 0.0))
	var lip := ar.nearest_lip(end)
	var n: Vector3 = lip.normal
	await _calm("fire", end, n)
	var out := [0.3, 1.6]
	var got := []
	for o: float in out:
		var hang := (lip.point as Vector3) + n * o
		_foe_y = ar.top() - 2.0
		_foe_at = Vector3(hang.x, _foe_at.y, hang.z)
		await _ticks(3)
		var spec: Dictionary = ((SwayMoves.move("fire_kick").bend as Dictionary).kick as Dictionary).duplicate()
		spec["_info"] = {"tag": "fire_kick/kick"}
		BendR3.hits_log.clear()
		BendEffects.floor_wave(BendCaster.of(p), {}, spec)
		await _secs(0.7)
		got.append(not _hits_on(foe).is_empty())
	_foe_y = -INF
	_foe_at = Vector3.INF
	foe.global_position = rm.ring.spawn(1 - rm.player_end).origin
	await _ticks(2)
	_foe_at = foe.global_position
	_expect(got == [true, false], "the Kick's wave runs 0.3 m past the lip: a hanger there is hit, one 1.6 m out is not (%s)" % [got])


# ---------------------------------------------------------------- Breath's smoke (AIR's round-3 rule)
func _breath() -> void:
	await _near_foe("fire")
	var spec: Dictionary = (SwayMoves.move("fire_breath").bend as Dictionary).breath
	var bc := BendCaster.of(p)
	BendEffects.apply(bc, "fire_breath", "breath", spec)
	await _secs(0.2)
	BendEffects.apply(bc, "fire_breath", "breath", spec)
	await _secs(0.2)
	var n := 0
	for z in get_nodes_in_group(BendZone.GROUP):
		if (z as BendZone).kind == "smoke" and (z as BendZone).owner_node == p and not (z as BendZone).is_queued_for_deletion():
			n += 1
	_expect(n == 1, "Breath: one smoke a caster at a time (%d)" % n)


# ---------------------------------------------------------------- the gate off (the classic ring)
func _gate_off() -> void:
	await _near_foe("earth")
	_fakes(false)
	await _ticks(2)
	_expect(not RingRules.stock_on() and not c.r3(), "the fakes gone: the gate off")
	await _tap(0)
	await _secs(0.4)
	await _tap(2)
	await _ticks(2)
	_expect(c.readied_spell == "earth_skate" and c.state == SwayCaster.State.IDLE and c.last_key3 != "x",
			"in the classic ring 3 readies its move as round 2 did (%s)" % _ready_now())
	_fakes(true)
	# a share of air releases (a scripted short fight of casts, half of them hopped)
	await _near_foe("earth")
	released.clear()
	air_casts.clear()
	for i in 6:
		rm.phase_t = 0.0
		foe.health = foe.health_max
		if i % 3 == 0:
			await _lift(1.0)
		await _tap(0)
		var got := await _rmb_full(2.0)
		c.held_override = false
		await _secs(0.3)
		if not got:
			print("    (cast %d not full: state %s, break %s, enabled %s)" % [i, c.state, c.last_break, c.enabled])
		if i % 3 == 0:
			await _land()
		await _secs(0.3)
	var share := float(air_casts.size()) / maxf(float(released.size()), 1.0)
	metrics["air_release_share"] = snappedf(share, 0.01)
	_expect(released.size() == 6 and air_casts.size() == 2, "a scripted string of 6 casts, 2 let go in the air: air_cast fired for those (%d of %d)" % [air_casts.size(), released.size()])
