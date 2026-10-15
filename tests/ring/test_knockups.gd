extends SceneTree
## Knock-ups, the air prison and the soaking (2026-10-11, the owner: "we need knockups like the column hitting a player ... where
## they float for a time period also the fissure", "air should have air prisons where they can catch someone mid flight", "water
## should be able slowdown"; his answers: a helpless float, teammates may free him, walls placed before him; the regular Kick
## too, the High Kick a speedy blast; the prison and the slow as skill tree twists; and "for the jump left click for fire it
## should shoot a fire ball", the drop kick kept: "the fire air jab was like a drop kick right") in a real 2v2 ring match (fire,
## a fire mate, against earth), headless:
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_knockups.gd
##   the data       the Column, the Geyser and the tapped Fissure and Kick float (their held ones throw as before); the High Kick
##                  straight and fast; fire's air jab a fireball (its pose the drop kick, from the foot); Wind Prison and
##                  Drenching Wave live
##   as cast        the player casts each knock-up at the foe held still, the crosshair on his chest (BendEffects.apply, as the
##                  game does): each adds its % and floats him; the Column's pillar carries him onto its top and its throw finds
##                  him there (the owner: "i dont think the knock column knocks someone up right?": it had looked for him within
##                  3 m of the deck only, the pillar 3 m tall)
##   the float      a Column hit on the foe: he floats, no escape, held near the top sinking 0.5 m/s, then falls; again within
##                  6 s 0.48, 0.29, then none
##   the rescue     the mate floated by the foe: the player's bolt through him frees him (his hitstun ends); a wall raised before
##                  a floating mate stands tall enough to cover him
##   the prison     the twist worn: its wall 4.5 m; raised under the foe floating near the top of a Column's launch, it
##                  holds him where he is, still
##   the soaking    Drenching Wave's hit: he runs at 0.7 for 1.5 s; again 0.9, 0.54, 0.32, then none
##   the fireball   the left button in the air: the Flare Kick's drop kick plays and throws a fire bolt from the foot
## Ends with "KNOCKUPS TEST PASSED (n checks)" or "... FAILED"; exit 0 only on a pass.

const NAME := "KNOCKUPS TEST"
const LIMIT_S := 240.0

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var player: FrontierPlayer
var mode: RingMode
## The crosshair held on this one's chest every physics frame while set (_aim).
var aim_on: Node3D
var pitch_sign := 1.0


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	seed(1752)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	_run.call_deferred()


func _end() -> void:
	Engine.time_scale = 1.0
	BendLoadout.config_override = {}
	MatchSetup.format = "1v1"
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


## Game seconds of physics frames (physics_ticks_per_second a second).
func _secs(s: float) -> void:
	await _ticks(ceili(s * float(Engine.physics_ticks_per_second)))


func _near(a: float, b: float, tol := 0.03) -> bool:
	return absf(a - b) <= tol


func _held_s(n: Node) -> float:
	if not n.has_meta(BendStatus.FLOAT_META):
		return 0.0
	var f: Dictionary = n.get_meta(BendStatus.FLOAT_META)
	return float(f.until) - float(f.from)


func _clear(n: Node) -> void:
	for k: StringName in [BendStatus.FLOAT_META, BendStatus.FLOAT_MEMO_META, &"bend_drench", &"bend_drench_memo"]:
		if n.has_meta(k):
			n.remove_meta(k)


## The player's crosshair on aim_on's chest (his camera's yaw and pitch), as FxStage.aim.
func _aim() -> void:
	if aim_on == null or not is_instance_valid(aim_on) or player == null or player.camera == null:
		return
	var d := (NpcSenses.chest_of(aim_on) - player.camera.global_position).normalized()
	player.yaw = atan2(-d.x, -d.z)
	player.pitch = asin(clampf(d.y, -1.0, 1.0)) * pitch_sign


## Waits (3 s at most) till `n` may be hit: not in a moment no one reaches him (his fall broken, standing up).
func _tangible(n: Node, by: Node = null) -> void:
	for i in ceili(3.0 * Engine.physics_ticks_per_second):
		if BendStatus.can_take(n, by if by != null else player):
			return
		await physics_frame


## Every bot held still (`on`: no thinking, so none casts) or let go.
func _hold_bots(on: bool) -> void:
	for e: Dictionary in mode.extras:
		if e.get("bot") is NpcFighter:
			(e.bot as NpcFighter).held = on
	if mode.foe != null and is_instance_valid(mode.foe):
		mode.foe.held = on


## The player, as `el`, casts `m`'s `md` at `foe` from 6 m (the foe still at `home`, his % 0, no float memory, the deck cleared;
## the other bots, held by the caller, put off the line between them) with the crosshair on his chest: {top: the highest he goes
## over the deck (m), float_s: how long he floats, pct: the % it adds} over 3 s.
func _cast_at(foe: NpcFighter, home: Vector3, el: String, m: String, md: String) -> Dictionary:
	mode.ring.clear_dropped()
	_clear(foe)
	# (along the deck's long way from him, his side's: on the 2v2 deck drawn in (2026-10-12) the diagonal from the player's spawn
	# ran beside the Ruins' middle wall, and a ground wave on it met the wall, the cover it is)
	var ax := mode.ring.axis()
	var way := ax * signf((player.global_position - home).dot(ax))
	way.y = 0.0
	way = way.normalized()
	player.global_position = home + way * 6.0
	player.velocity = Vector3.ZERO
	var side := Vector3.UP.cross(way).normalized()
	var k := 0
	for e: Dictionary in mode.extras:
		if e.get("bot") is NpcFighter and e.bot != foe:
			(e.bot as NpcFighter).global_position = home + way * 3.0 + side * (4.0 if k == 0 else -4.0)
			(e.bot as NpcFighter).velocity = Vector3.ZERO
			k += 1
	foe.global_position = home
	foe.velocity = Vector3.ZERO
	var kn := BendKnock.peek(foe)
	if kn != null:
		kn.reset()
		kn.stun_t = 0.0
	RingRules.current().reset_pct(foe, 0.0)
	Bending.of(player).element = el
	aim_on = foe
	await _secs(1.5)
	var deck := FormEffects.ground_at(foe, foe.global_position).y
	var pct0 := RingRules.current().pct_of(foe)
	BendEffects.apply(BendCaster.of(player), m, md, SwayMoves.move(m).bend[md])
	var top := 0.0
	var fl := 0
	for i in ceili(3.0 * Engine.physics_ticks_per_second):
		await physics_frame
		top = maxf(top, foe.global_position.y - deck)
		if BendStatus.floating(foe):
			fl += 1
	aim_on = null
	return {"top": top, "float_s": float(fl) / Engine.physics_ticks_per_second, "pct": RingRules.current().pct_of(foe) - pct0}


func _run() -> void:
	# ---------------------------------------------------------------- the data
	var cls: Dictionary = RingRules.stock_block("classes") if RingRules.data().has("stock") else {}
	if cls.is_empty():
		cls = (JSON.parse_string(FileAccess.get_file_as_string("res://data/ring/rules.json")) as Dictionary).stock.classes
	for tag: String in ["earth_shove/column", "wave/spout", "earth_shove/push", "fire_kick/kick"]:
		_expect(_near(float((cls[tag] as Dictionary).get("float_s", 0.0)), 0.8) and int((cls[tag] as Dictionary).angle) >= 80,
				"%s knocks up and floats 0.8 s" % tag)
	for tag: String in ["earth_shove/push.grown", "fire_kick/kick.grown"]:
		_expect(float((cls[tag] as Dictionary).get("float_s", 0.0)) == 0.0 and int((cls[tag] as Dictionary).angle) == 40,
				"%s (held) throws at 40 degrees as before" % tag)
	var hk: Dictionary = SwayMoves.move("fire_kick").bend.high_kick
	_expect(_near(float(hk.mps), 40.0) and is_zero_approx(float(hk.gravity)) and bool(hk.get("straight", false)),
			"the High Kick flies straight at 40 m/s with no drop")
	var ah: Dictionary = SwayMoves.move("fire_jab").bend.air_hit
	_expect(String(ah.do) == "bolt" and String(ah.kind) == "fire", "fire's air jab is a fire bolt (%s)" % ah.do)
	var ap := BendPoses.pick("fire_jab", "air_hit", "fire")
	_expect(String(ap.get("clip", "")) == "own-bend-air-hit-fire" and String(ap.get("hand", "")) == "r_foot",
			"...thrown by the Flare Kick's drop kick, from the foot (%s, %s)" % [ap.get("clip", ""), ap.get("hand", "")])
	for id: String in ["air.wall.prison", "water.wave.drench"]:
		_expect(BendLoadout.why_not(id) == "", "%s is live (%s)" % [id, BendLoadout.why_not(id)])

	# ---------------------------------------------------------------- the ring: 2v2, fire with a fire mate, against earth
	MatchSetup.format = "2v2"
	MatchSetup.incoming = true
	MatchSetup.element = "fire"
	MatchSetup.foes = ["earth"]
	MatchSetup.mates = ["fire"]
	MatchSetup.round_s = 120.0
	MatchSetup.rounds_to_win = 1
	MatchSetup.difficulty = "normal"
	InputSetup.ensure()
	SwayCaster.free_override = true
	change_scene_to_file("res://scenes/ring.tscn")
	for i in 20:
		await process_frame
	lvl = current_scene as RingLevel
	player = lvl.player if lvl != null else null
	mode = RingMode.find(self)
	var mate: NpcFighter = null
	for e: Dictionary in (mode.extras if mode != null else []):
		if int(e.get("team", -1)) == 0 and e.get("bot") is NpcFighter:
			mate = e.bot
	_expect(mode != null and player != null and mode.foe != null and mate != null and RingRules.stock_on(),
			"a 2v2 % ring: the player, a mate and the foe")
	if mode == null or player == null or mode.foe == null or mate == null:
		return _end()
	var foe: NpcFighter = mode.foe
	var rules := RingRules.current()
	rules.stale_off = true
	_expect(BendCaster.same_team(mate, player) and not BendCaster.same_team(foe, player), "the mate is on the player's side")
	await _secs(4.5)                                 # (past the countdown and the start's safety)

	# as cast: each knock-up by the player at the foe, every bot held still (none of them casts meanwhile), the crosshair on his
	# chest
	_hold_bots(true)
	player.pitch = 0.3
	await _ticks(3)
	pitch_sign = 1.0 if (-player.camera.global_basis.z).y > 0.0 else -1.0
	player.pitch = 0.0
	physics_frame.connect(_aim)
	var home := foe.global_position
	for c: Array in [["earth", "earth_shove", "column", 4.5], ["water", "wave", "spout", 2.0], ["earth", "earth_shove", "push", 1.8],
			["fire", "fire_kick", "kick", 1.8]]:
		var got: Dictionary = await _cast_at(foe, home, String(c[0]), String(c[1]), String(c[2]))
		_expect(float(got.pct) > 0.0 and float(got.float_s) > 1.0 and float(got.top) > float(c[3]),
				"%s/%s as cast: it hits (+%.1f%%), knocks him up %.1f m over the deck and floats him %.2f s" % [c[1], c[2], got.pct,
				got.top, got.float_s])
	physics_frame.disconnect(_aim)
	Bending.of(player).element = "fire"
	mode.ring.clear_dropped()
	rules.reset_pct(foe, 0.0)
	await _secs(1.0)                                 # (the bots stay held to the end: no one's own fight in the checks below)

	# the High Kick's blast to the crosshair: aimed 4 degrees over the foe's chest under the strong aim help (whose 6-degree cone
	# takes him), it goes where the crosshair points, never bent onto his chest. Where it points: its line at his depth
	# (flight_point, since 2026-10-12 every cast's: from the foot to where the ray stops on the deck far behind him crossed the
	# dot's line only there)
	var help0 := MatchSetup._aim_help
	MatchSetup._aim_help = "strong"
	var pc := BendCaster.of(player)
	var dc := (NpcSenses.chest_of(foe) - player.camera.global_position).normalized()
	player.yaw = atan2(-dc.x, -dc.z)
	player.pitch = (asin(clampf(dc.y, -1.0, 1.0)) + deg_to_rad(4.0)) * pitch_sign
	await _ticks(4)
	var cross := pc.flight_point()
	var helped := pc.aim_target()
	var known := {}
	for n in get_nodes_in_group(BendBolt.GROUP):
		known[n.get_instance_id()] = true
	BendEffects.apply(pc, "fire_kick", "high_kick", SwayMoves.move("fire_kick").bend.high_kick)
	var blast: BendBolt = null
	for n in get_nodes_in_group(BendBolt.GROUP):
		if n is BendBolt and not known.has(n.get_instance_id()) and (n as BendBolt).caster == player:
			blast = n
	MatchSetup._aim_help = help0
	var to_cross := Vector3.ZERO
	var to_chest := Vector3.ZERO
	var bdir := Vector3.ZERO
	if blast != null:
		var b0 := blast.global_position - blast.velocity.normalized() * blast.travelled
		bdir = blast.velocity.normalized()
		to_cross = (cross - b0).normalized()
		to_chest = (NpcSenses.chest_of(foe) - b0).normalized()
	_expect(helped == foe and blast != null and rad_to_deg(bdir.angle_to(to_cross)) < 1.5 and rad_to_deg(bdir.angle_to(to_chest)) > 2.0,
			"the High Kick's blast goes to the crosshair 4 degrees over the foe the aim help takes (%.1f deg off the crosshair, %.1f off his chest)"
			% [rad_to_deg(bdir.angle_to(to_cross)), rad_to_deg(bdir.angle_to(to_chest))])
	mode.ring.clear_dropped()
	await _secs(0.5)

	# the float
	_clear(foe)
	var col := {"tag": "earth_shove/column", "move": "earth_shove", "mode": "column", "from": foe.global_position}
	await _tangible(foe)
	BendR3.deliver(foe, 10.0, foe.global_position + Vector3.UP, Vector3.UP, player, 0.5, Vector3.UP * 11.0, col)
	var kn := BendKnock.peek(foe)
	_expect(BendStatus.floating(foe) and kn != null and not kn.can_escape() and _near(_held_s(foe), 0.8),
			"a Column hit floats him 0.8 s, no escape (%.2f)" % _held_s(foe))
	var f: Dictionary = foe.get_meta(BendStatus.FLOAT_META, {})
	var rise := float(f.get("from", 0.0)) - BendStatus.now()
	_expect(rise > 0.2 and rise < 0.8 and kn.stun_t >= rise + 0.75, "his hitstun runs through the rise and the float (rise %.2f s, stun %.2f s)" % [rise, kn.stun_t])
	await _secs(rise + 0.25)
	_expect(_near(BendStatus.float_fall(foe), 0.5) and absf(foe.velocity.y + 0.5) < 0.35,
			"near the top he sinks only 0.5 m/s (%.2f)" % foe.velocity.y)
	await _secs(0.8)
	_expect(not BendStatus.floating(foe), "the float ends after its 0.8 s")
	await _secs(1.5)
	var helds: Array[float] = []
	_clear(foe)
	for i in 4:
		rules.on_hit(foe, player, col)
		helds.append(_held_s(foe) if BendStatus.floating(foe) else 0.0)
		BendStatus.unfloat(foe)
	_expect(_near(helds[0], 0.8) and _near(helds[1], 0.48) and _near(helds[2], 0.288) and is_zero_approx(helds[3]),
			"again within 6 s: 0.8, 0.48, 0.29, then none (%s)" % [helds])
	BendStatus.unfloat(foe, true)
	await _secs(1.5)

	# the rescue: the mate floated by the foe, the player's bolt through him
	_clear(mate)
	var col2 := col.duplicate()
	col2["from"] = mate.global_position
	await _tangible(mate, foe)
	BendR3.deliver(mate, 10.0, mate.global_position + Vector3.UP, Vector3.UP, foe, 0.5, Vector3.UP * 11.0, col2)
	_expect(BendStatus.floating(mate), "the foe's Column floats the mate")
	await _secs(0.3)
	_expect(BendStatus.float_cover(player, Vector3(mate.global_position.x, 0.0, mate.global_position.z) + Vector3.UP * player.global_position.y) > 2.0,
			"a wall raised before the floating mate rises to cover him (%.2f m)" % BendStatus.float_cover(player, mate.global_position - Vector3.UP * 2.0))
	var from := player.global_position + Vector3.UP * 1.2
	var to := mate.global_position + Vector3.UP * 0.9
	var spec: Dictionary = SwayMoves.move("fire_blast").bend.punch.duplicate()
	BendBolt.launch(player, from, (to - from).normalized(), spec)
	var freed := false
	for i in 120:
		await physics_frame
		if not BendStatus.floating(mate):
			freed = true
			break
	var mk := BendKnock.peek(mate)
	_expect(freed and mk != null and mk.stun_t <= 0.0, "the player's bolt through his floating mate frees him: his hitstun over")
	await _secs(1.5)

	# the prison: the foe floating near the top of a Column's launch, the twist's own wall (worn: 4.5 m) raised under him
	BendLoadout.wear(player, ["air.wall.prison"], "", "air")
	var ws := BendLoadout.spec(player, "air_wall", "wall", SwayMoves.move("air_wall").bend.wall)
	BendLoadout.clear(player)
	_expect(_near(float(ws.get("prison_s", 0.0)), 1.0) and _near(float(ws.get("height_m", 0.0)), 4.5),
			"Wind Prison worn: its wall holds 1 s and stands 4.5 m (%s, %s)" % [ws.get("prison_s"), ws.get("height_m")])
	_clear(foe)
	await _tangible(foe)
	BendR3.deliver(foe, 10.0, foe.global_position + Vector3.UP, Vector3.UP, player, 0.5, Vector3.UP * 11.0, col)
	var top := float((foe.get_meta(BendStatus.FLOAT_META, {}) as Dictionary).get("from", 0.0)) - BendStatus.now()
	await _secs(top + 0.1)
	var deck := FormEffects.ground_at(foe, foe.global_position)
	var up_m := foe.global_position.y - deck.y
	var way := (foe.global_position - player.global_position)
	way.y = 0.0
	var z := BendZone.make(player, "wind_wall", deck, ws, way.normalized())
	var caught := false
	for i in 30:
		await physics_frame
		if BendStatus.floating(foe) and float((foe.get_meta(BendStatus.FLOAT_META) as Dictionary).get("from", INF)) <= BendStatus.now() + 0.01 \
				and _near(_held_s(foe), 0.6, 0.05):
			caught = true
			break
	_expect(z != null and caught and up_m > 2.5,
			"a Wind Prison raised under the foe floating %.1f m up holds him (0.6 s: his Column float counts)" % up_m)
	_expect(foe.velocity.length() < 0.7, "...held where he is (%.2f m/s)" % foe.velocity.length())
	if z != null and is_instance_valid(z):
		z.queue_free()
	await _secs(2.0)

	# the soaking
	_clear(foe)
	var wave := {"tag": "wave/push", "move": "wave", "mode": "push", "from": player.global_position, "drench_s": 1.5}
	await _tangible(foe)
	var r0 := rules.on_hit(foe, player, wave)
	_expect(_near(float(r0.get("drench_s", -1.0)), 1.5) and _near(BendStatus.drench_mult(foe), 0.7) and BendStatus.drench_left(foe) > 1.3,
			"Drenching Wave's hit: he runs at 0.7 for 1.5 s")
	var ds: Array[float] = []
	for i in 4:
		ds.append(float(rules.on_hit(foe, player, wave).get("drench_s", -1.0)))
	_expect(_near(ds[0], 0.9) and _near(ds[1], 0.54) and _near(ds[2], 0.324) and is_zero_approx(ds[3]),
			"again within 6 s: 0.9, 0.54, 0.32, then none (%s)" % [ds])

	# fire's air jab: the left button in the air (held there), the drop kick, a fireball from its foot
	var c := SwayCaster.of(player)
	c._quick["fire"] = MatchSetup.jab_of("fire")    # (the left button the jab, whatever a test run's settings file kept)
	var hover_y := player.global_position.y + 2.5
	var pin := func() -> void:
		if is_instance_valid(player):
			player.global_position.y = hover_y
			player.velocity.y = 0.0
	physics_frame.connect(pin)
	var sk := player.skeleton
	var rb := sk.find_bone("r_ball")
	var feet := [Vector3.INF]                       # (the right foot as drawn: read once the clips have posed the skeleton)
	var on_sk := func() -> void:
		feet[0] = sk.global_transform * sk.get_bone_global_pose(rb).origin
	sk.skeleton_updated.connect(on_sk)
	await _ticks(6)
	var before := {}
	for n in get_nodes_in_group(BendBolt.GROUP):
		before[n.get_instance_id()] = true
	c.quick_override = true                         # (pressed, held till it is full, let go: the cast)
	var kicked := false
	for i in 150:
		await physics_frame
		kicked = kicked or String(c.pose.current_clip()) in ["own-bend-air-hit-fire", "own-bend-air-hit-fire-l"]
		if c.state == SwayCaster.State.FULL:
			break
	c.quick_override = false
	var fb: BendBolt = null
	var origin := Vector3.INF
	var foot := Vector3.INF
	var chest := Vector3.INF
	for i in 120:
		await physics_frame
		kicked = kicked or String(c.pose.current_clip()) in ["own-bend-air-hit-fire", "own-bend-air-hit-fire-l"]
		for n in get_nodes_in_group(BendBolt.GROUP):
			if n is BendBolt and not before.has(n.get_instance_id()) and (n as BendBolt).caster == player:
				fb = n
		if fb != null:
			origin = fb.global_position - fb.velocity.normalized() * fb.travelled
			foot = feet[0]
			chest = BendCaster.of(player).chest()
			break
	physics_frame.disconnect(pin)
	sk.skeleton_updated.disconnect(on_sk)
	_expect(kicked, "the left button in the air plays the Flare Kick's drop kick")
	_expect(fb != null and fb.kind == "fire", "...and the kick throws a fire bolt")
	_expect(fb != null and origin.distance_to(foot) < 0.4 and origin.y < chest.y - 0.3,
			"...from the kicking foot (%.2f m from it, %.2f m below the chest)" % [origin.distance_to(foot), chest.y - origin.y])
	_end()
