extends SceneTree
## Water's talents in a real ring match (the owner, 2026-10-11: "we need to make sure all the talents work and they work in game
## right"): a 1v1 % ring, the player water against a fire bot; each talent worn by one fighter alone, played through the game's own
## code (BendEffects.apply's casts, the bolts' flight, the zones, the walls), worn and not worn, and a bot wearing it:
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_talents_water.gd
##   each             live (BendLoadout.why_not ""), every water id of loadout_apply.json's behaviour map
##   Thick Ice        the Ice Wall raised and shot with ice: worn it takes 4 hits and rises in 0.8 s (Classic 3, 0.7 s); a bot
##                    wearing it raises the same; switched on in loadout_apply.json
##   Washout          a gas cloud (the Sulphur set's interface: a BendZone of kind gas, made here) between them: the wearer's
##                    Splash and Lash wash it out and fly on to hit; not worn it stays; a bot's too; his Splash adds 3.5 for 4
##   Splashdown       the wearer's Lash on him (and into a wall) leaves a 1.2 m puddle of his for 6 s where it stopped, his
##                    Geyser's source there (the grates out of the pools meanwhile); not worn none; a bot's own; Lash 8 for 9
##   Steamcraft       his Lash met head-on by fire: the steam is his, hangs 2.5 s and drifts 1.2 m a second toward his aim; not
##                    worn 1.5 s and still; a bot's drifts toward its foe
##   Cleanse          his Turn washes out a gas cloud 1 m off, not one 7 m off; not worn none; a bot's too; the Turn's lock on E
##                    (SwayCaster's guard lock) and a bot's x1.2
##   Whirl Turn       a perfect Turn on a water bolt: E held the water circles him 0.6 s, a tap 0.3 s; not worn 0.3 s; a late
##                    Turn lets 0.6 through (0.5); a bot holds it while its foe guards
##   Eddy             after a perfect Turn the Lash's real lock (key 1, the aim held) starts 0.4 full, 1.6 s after or not worn
##                    from nothing; his Turn's beat 0.25 s; a bot's next Lash lock begins 0.4 full
## Last line "TALENTS WATER PASSED (n checks)" or "... FAILED"; exit 0 only on a pass.

const NAME := "TALENTS WATER"
const LIMIT_S := 400.0

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var player: FrontierPlayer
var mode: RingMode
var foe: NpcFighter
var pc: BendCaster
var fc: BendCaster
var home := Vector3.ZERO


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	seed(1757)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	_run.call_deferred()


func _end() -> void:
	Engine.time_scale = 1.0
	for b: Node in [player, foe]:
		if b != null and is_instance_valid(b):
			BendLoadout.clear(b)
	BendLoadout.config_override = {}
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


## Game seconds of physics frames.
func _secs(s: float) -> void:
	await _ticks(ceili(s * float(Engine.physics_ticks_per_second)))


func _near(a: Variant, b: Variant, tol := 0.001) -> bool:
	return a != null and b != null and absf(float(a) - float(b)) <= tol


## `body` wears `ids` alone (nothing else) as an `el` caster ([]: nothing worn, Classic).
func _wear(body: Node, ids: Array, el := "water") -> void:
	BendLoadout.clear(body)
	if ids.is_empty():
		return
	var ov := BendLoadout.wear(body, ids, "", el)
	for id: Variant in ids:
		if not (ov.ids as Array).has(id):
			_expect(false, "%s worn (refused: %s)" % [id, str(ov.refused)])


## The two fighters set `d` m apart on the deck, facing each other (the player looking at the foe's chest), still.
func _face_off(d := 10.0) -> void:
	mode.ring.clear_dropped()
	var way := Vector3(0, 0, 1)
	foe.global_position = home + way * d * 0.5
	player.global_position = home - way * d * 0.5
	for b: CharacterBody3D in [player, foe]:
		b.velocity = Vector3.ZERO
	foe.look_at(Vector3(player.global_position.x, foe.global_position.y, player.global_position.z), Vector3.UP)
	player.yaw = atan2(-way.x, -way.z)
	player.pitch = 0.0
	aim_on = foe                                     # (the player's crosshair on the foe's chest: his casts aim there)
	await _ticks(3)


## The newest raised wall `body` raised (null none).
func _newest_wall(body: Node) -> FormRaised:
	var found: FormRaised = null
	for n in get_nodes_in_group(FormRaised.GROUP):
		var w := n as FormRaised
		if w != null and is_instance_valid(w) and int(w.get_meta(&"bend_by", 0)) == body.get_instance_id() and not w.is_queued_for_deletion():
			if found == null or int(w.get_meta(&"wall_n", 0)) > int(found.get_meta(&"wall_n", 0)):
				found = w
	return found


## An ice bolt of `by`'s flown into wall `w` from 3 m before its face (its own flight: BendBolt meets the raised wall, BendBolt.wear).
func _shoot_wall(by: Node3D, w: FormRaised) -> void:
	var face := w.global_basis.z.normalized()
	var mid := w.global_position + Vector3.UP * 1.0
	var side := 1.0 if (by.global_position - w.global_position).dot(face) >= 0.0 else -1.0
	var from := mid + face * side * 3.0
	BendBolt.launch(by, from, mid - from, {"kind": "ice", "mps": 30.0, "damage": 12.0, "radius_m": 0.15, "range_m": 12.0})
	await _ticks(20)


## The player's crosshair on aim_on's chest each frame (his camera's yaw and pitch), as test_knockups.
var aim_on: Node3D = null
var pitch_sign := 1.0
func _aim() -> void:
	if aim_on == null or not is_instance_valid(aim_on) or player == null or player.camera == null:
		return
	var d := (NpcSenses.chest_of(aim_on) - player.camera.global_position).normalized()
	player.yaw = atan2(-d.x, -d.z)
	player.pitch = asin(clampf(d.y, -1.0, 1.0)) * pitch_sign


## The zones of `kind` in the scene now, by instance id.
func _zones(kind: String) -> Dictionary:
	var out := {}
	for z in get_nodes_in_group(BendZone.GROUP):
		var bz := z as BendZone
		if bz != null and bz.kind == kind and not bz.is_queued_for_deletion():
			out[bz.get_instance_id()] = bz
	return out


## A zone of `kind` made since `before` (_zones), owned by `by` (null any); null none.
func _new_zone(kind: String, before: Dictionary, by: Node = null) -> BendZone:
	for z: BendZone in _zones(kind).values():
		if not before.has(z.get_instance_id()) and (by == null or z.owner_node == by):
			return z
	return null


## The bolts of `by` in flight, by instance id.
func _bolts(by: Node) -> Dictionary:
	var out := {}
	for n in get_nodes_in_group(BendBolt.GROUP):
		var b := n as BendBolt
		if b != null and b.caster == by and not b.spent:
			out[b.get_instance_id()] = b
	return out


## A bolt of `by`'s launched since `before` (_bolts); null none.
func _new_bolt(by: Node, before: Dictionary) -> BendBolt:
	for b: BendBolt in _bolts(by).values():
		if not before.has(b.get_instance_id()):
			return b
	return null


## `who` casts `m`'s `md` (the game's own cast: BendEffects.apply, its aim on the other fighter); the bolt it sent (null none).
func _cast(who: Node3D, m: String, md: String) -> BendBolt:
	var before := _bolts(who)
	BendEffects.apply(BendCaster.of(who), m, md, (SwayMoves.move(m).bend as Dictionary)[md])
	return _new_bolt(who, before)


## A gas cloud of `by`'s at `at` (the Sulphur set's interface: a BendZone of kind gas; that set is earth's and not built here).
func _gas(by: Node3D, at: Vector3, r := 2.5) -> BendZone:
	return BendZone.make(by, "gas", FormEffects.ground_at(by, at), {"radius_m": r, "life_s": 20.0})


## The % a hit by `who`'s cast adds to `on` (the cast through BendEffects.apply, aimed at him; RingRules counts it).
func _pct_of_cast(who: Node3D, on: Node3D, m: String, md: String) -> float:
	await _face_off(8.0)
	RingRules.current().reset_pct(on, 0.0)
	var kn := BendKnock.peek(on)
	if kn != null:
		kn.reset()
		kn.stun_t = 0.0
	await _ticks(2)
	_cast(who, m, md)
	await _secs(0.8)
	var got := RingRules.current().pct_of(on)
	RingRules.current().reset_pct(on, 0.0)
	return got


func _run() -> void:
	MatchSetup.format = "1v1"
	MatchSetup.incoming = true
	MatchSetup.element = "water"
	MatchSetup.foes = ["fire"]
	MatchSetup.mates = []
	MatchSetup.round_s = 600.0
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
	_expect(mode != null and player != null and mode.foe != null and RingRules.stock_on(), "a 1v1 % ring: the player (water) and a fire bot")
	if mode == null or player == null or mode.foe == null:
		return _end()
	foe = mode.foe
	RingRules.current().stale_off = true
	pc = BendCaster.of(player)
	fc = BendCaster.of(foe)
	await _secs(4.5)                                 # (past the countdown and the start's safety)
	foe.held = true                                  # (the bot still: none of its own casts in the checks; it casts when a check says)
	await _secs(0.5)
	home = foe.global_position
	home.y = player.global_position.y
	Bending.of(player).element = "water"
	player.pitch = 0.3
	await _ticks(3)
	pitch_sign = 1.0 if (-player.camera.global_basis.z).y > 0.0 else -1.0
	player.pitch = 0.0
	physics_frame.connect(_aim)
	for id: String in BendLoadout.behaviour():
		if id.begins_with("water."):
			_expect(BendLoadout.why_not(id) == "", "%s is live (%s)" % [id, BendLoadout.why_not(id)])
	await _thick_ice()
	await _washout()
	await _splashdown()
	await _steamcraft()
	await _cleanse()
	await _whirl()
	await _eddy()
	_end()


# ---------------------------------------------------------------- Thick Ice
## The Ice Wall raised by `who` (its own cast: BendEffects.apply water_shield/ice_wall, placed at its aim) and shot with ice until
## it falls: {hits_max, rise, up_after (hits it still stood after), fell_at (the hit it fell at; -1 none)}.
func _ice_wall_shot(who: Node3D, by: Node3D) -> Dictionary:
	await _face_off(10.0)
	var bc := BendCaster.of(who)
	BendEffects.apply(bc, "water_shield", "ice_wall", SwayMoves.move("water_shield").bend.ice_wall)
	var w := _newest_wall(who)
	if w == null:
		return {"hits_max": -1, "rise": -1.0, "fell_at": -1}
	var out := {"hits_max": w.hits_max, "rise": w.rise_s, "fell_at": -1}
	await _secs(1.0)
	for i in 6:
		if not is_instance_valid(w) or not w.is_up():
			break
		await _shoot_wall(by, w)
		if not is_instance_valid(w) or not w.is_up():
			out.fell_at = i + 1
			break
	if is_instance_valid(w):
		w.crumble("test")
	await _ticks(10)
	return out


func _thick_ice() -> void:
	_expect(BendLoadout.why_not("water.wall.thick_ice") == "", "Thick Ice is switched on (%s)" % BendLoadout.why_not("water.wall.thick_ice"))
	_wear(player, ["water.wall.thick_ice"])
	var worn: Dictionary = await _ice_wall_shot(player, foe)
	_wear(player, [])
	var classic: Dictionary = await _ice_wall_shot(player, foe)
	_expect(int(worn.hits_max) == 4 and _near(worn.rise, 0.8) and int(worn.fell_at) == 4,
			"Thick Ice: the wearer's Ice Wall rises in %.2f s and falls at the 4th ice hit (%d)" % [float(worn.rise), int(worn.fell_at)])
	_expect(int(classic.hits_max) == 3 and _near(classic.rise, 0.7) and int(classic.fell_at) == 3,
			"Thick Ice not worn: the Ice Wall rises in %.2f s and falls at the 3rd (%d)" % [float(classic.rise), int(classic.fell_at)])
	# a bot wearing it raises the same wall (its own cast, the same builder)
	_wear(foe, ["water.wall.thick_ice"])
	var bot: Dictionary = await _ice_wall_shot(foe, player)
	_wear(foe, [])
	var bot0: Dictionary = await _ice_wall_shot(foe, player)
	_expect(int(bot.hits_max) == 4 and _near(bot.rise, 0.8) and int(bot.fell_at) == 4 and int(bot0.hits_max) == 3 and int(bot0.fell_at) == 3,
			"Thick Ice on a bot: its Ice Wall takes 4 (%d), not worn 3 (%d)" % [int(bot.fell_at), int(bot0.fell_at)])


# ---------------------------------------------------------------- Washout
## A gas cloud of the other's between them (the Sulphur set's: earth's, built elsewhere; its interface a BendZone of kind gas), a
## Splash or a Lash of the shooter's through it: {washed (the cloud gone), on (the bolt flew on: a hit on the other)}.
func _through_gas(shooter: Node3D, other: Node3D, m: String, md: String) -> Dictionary:
	await _face_off(10.0)
	RingRules.current().reset_pct(other, 0.0)
	var g := _gas(other, home)
	await _ticks(2)
	_cast(shooter, m, md)
	await _secs(0.7)
	var out := {"washed": not is_instance_valid(g) or g.is_queued_for_deletion(), "on": RingRules.current().pct_of(other) > 0.0}
	if is_instance_valid(g):
		g.end()
	RingRules.current().reset_pct(other, 0.0)
	await _ticks(2)
	return out


func _washout() -> void:
	for m: Array in [["water_jet", "splash"], ["water_whip", "whip"]]:
		_wear(player, ["water.splash.washout"])
		var w: Dictionary = await _through_gas(player, foe, String(m[0]), String(m[1]))
		_wear(player, [])
		var c: Dictionary = await _through_gas(player, foe, String(m[0]), String(m[1]))
		_expect(bool(w.washed) and bool(w.on) and not bool(c.washed) and bool(c.on),
				"Washout: the wearer's %s washes out the gas it crosses and flies on to hit (%s); not worn the cloud stays (%s)" % [m[1], w, c])
	_wear(foe, ["water.splash.washout"])
	var b: Dictionary = await _through_gas(foe, player, "water_jet", "splash")
	_wear(foe, [])
	_expect(bool(b.washed), "Washout on a bot: its Splash washes the gas out too (%s)" % b)
	_wear(player, ["water.splash.washout"])
	var pw: float = await _pct_of_cast(player, foe, "water_jet", "splash")
	_wear(player, [])
	var pn: float = await _pct_of_cast(player, foe, "water_jet", "splash")
	_expect(pn > 0.0 and absf(pw / pn - 3.5 / 4.0) < 0.01, "Washout's trade: the wearer's Splash adds %.2f%% for the %.2f (3.5 for 4)" % [pw, pn])


# ---------------------------------------------------------------- Splashdown
## A Lash of `who`'s at the other (an Ice Wall of the other's between them when `wall`): the puddle it left (null none); where the
## other stood as it was cast (_lash_at).
var _lash_at := Vector3.ZERO
func _lash_puddle(who: Node3D, other: Node3D, wall := false) -> BendZone:
	await _face_off(10.0 if wall else 8.0)
	var iw: FormRaised = null
	if wall:
		BendEffects.apply(BendCaster.of(other), "water_shield", "ice_wall", SwayMoves.move("water_shield").bend.ice_wall)
		iw = _newest_wall(other)
		await _secs(1.0)
	var before := _zones("puddle")
	_lash_at = other.global_position
	_cast(who, "water_whip", "whip")
	await _secs(0.6)
	var pd := _new_zone("puddle", before, who)
	if iw != null and is_instance_valid(iw):
		if pd != null and Vector2(pd.global_position.x - iw.global_position.x, pd.global_position.z - iw.global_position.z).length() > 1.5:
			pd = null
		iw.crumble("test")
	return pd


func _splashdown() -> void:
	_wear(player, ["water.lash.splashdown"])
	var pd := await _lash_puddle(player, foe)
	var on_him := pd != null and Vector2(pd.global_position.x - _lash_at.x, pd.global_position.z - _lash_at.z).length() < 1.5
	_expect(pd != null and on_him and _near(pd.radius, 1.2) and _near(pd.life_s, 6.0) and pd.is_in_group(Bending.POOLS),
			"Splashdown: the wearer's Lash on him leaves a 1.2 m puddle of his for 6 s at his feet, a pool (%s)" % ["%.1f m, %.1f s" % [pd.radius, pd.life_s] if pd != null else "none"])
	# his water: a source for his Geyser there (the foe put back on it; the ring's grates, everyone's sources, out of the pools
	# meanwhile so only his puddle can be one)
	var grates: Array = get_nodes_in_group(Bending.POOLS).filter(func(n: Node) -> bool: return not (n is BendZone))
	for g: Node in grates:
		g.remove_from_group(Bending.POOLS)
	await _secs(0.3)
	if pd != null:
		foe.global_position = Vector3(pd.global_position.x, foe.global_position.y, pd.global_position.z)
		foe.velocity = Vector3.ZERO
	aim_on = foe
	await _ticks(2)
	BendEffects.apply(pc, "wave", "spout", SwayMoves.move("wave").bend.spout)
	var src := bool(BendEffects.last_of(pc).get("source", false))
	if pd != null and is_instance_valid(pd):
		pd.end()
	await _secs(0.5)
	BendEffects.apply(pc, "wave", "spout", SwayMoves.move("wave").bend.spout)
	var src0 := bool(BendEffects.last_of(pc).get("source", false))
	for g: Node in grates:
		g.add_to_group(Bending.POOLS)
	aim_on = null
	_expect(src and not src0, "Splashdown: the puddle is his Geyser's source (with it %s, without %s)" % [src, src0])
	await _secs(1.0)
	var pw := await _lash_puddle(player, foe, true)
	_expect(pw != null, "Splashdown: the wearer's Lash into a wall leaves its puddle at the wall's foot")
	_wear(player, [])
	var p0 := await _lash_puddle(player, foe)
	var p1 := await _lash_puddle(player, foe, true)
	_expect(p0 == null and p1 == null, "Splashdown not worn: the Lash leaves no puddle")
	_wear(foe, ["water.lash.splashdown"])
	var pb := await _lash_puddle(foe, player)
	_wear(foe, [])
	_expect(pb != null and pb.owner_node == foe, "Splashdown on a bot: its Lash leaves its own puddle")
	_wear(player, ["water.lash.splashdown"])
	var lw: float = await _pct_of_cast(player, foe, "water_whip", "whip")
	_wear(player, [])
	var ln: float = await _pct_of_cast(player, foe, "water_whip", "whip")
	_expect(ln > 0.0 and absf(lw / ln - 8.0 / 9.0) < 0.01, "Splashdown's trade: the wearer's Lash adds %.2f%% for the %.2f (8 for 9)" % [lw, ln])
	for z: BendZone in _zones("puddle").values():
		z.end()


# ---------------------------------------------------------------- Steamcraft
## A Lash of `who`'s met head-on by a fire bolt of the other's: the steam they made ({} none): {owner, life, moved (m in 1 s),
## toward (its way against the way to the other fighter: 1 straight at him)}.
func _steam_of(who: Node3D, other: Node3D) -> Dictionary:
	await _face_off(10.0)
	var before := _zones("steam")
	var b := _cast(who, "water_whip", "whip")
	if b == null:
		return {}
	var from := b.global_position + b.velocity.normalized() * 6.0
	BendBolt.launch(other, from, -b.velocity, {"kind": "fire", "mps": 30.0, "damage": 10.0, "radius_m": 0.2, "range_m": 12.0})
	await _ticks(20)
	var st := _new_zone("steam", before)
	if st == null:
		return {}
	var p0 := st.global_position
	var to := other.global_position - p0
	await _secs(1.0)
	var moved := Vector2(st.global_position.x - p0.x, st.global_position.z - p0.z) if is_instance_valid(st) else Vector2.ZERO
	var out := {"owner": st.owner_node if is_instance_valid(st) else null, "life": st.life_s if is_instance_valid(st) else -1.0,
			"moved": moved.length(), "toward": moved.normalized().dot(Vector2(to.x, to.z).normalized()) if moved.length() > 0.01 else 0.0}
	await _secs(2.0)
	return out


func _steamcraft() -> void:
	_wear(player, ["water.lash.steamcraft"])
	var w: Dictionary = await _steam_of(player, foe)
	_wear(player, [])
	var c: Dictionary = await _steam_of(player, foe)
	_expect(not w.is_empty() and w.owner == player and _near(w.life, 2.5) and absf(float(w.moved) - 1.2) < 0.15 and float(w.toward) > 0.9,
			"Steamcraft: the steam the wearer's Lash makes with fire is his, hangs 2.5 s and drifts toward his aim (%.2f m in 1 s)" % [float(w.get("moved", -1.0))])
	_expect(not c.is_empty() and _near(c.life, 1.5) and float(c.moved) < 0.01, "Steamcraft not worn: the steam hangs 1.5 s where it was made (%s)" % [c])
	_wear(foe, ["water.lash.steamcraft"])
	var b: Dictionary = await _steam_of(foe, player)
	_wear(foe, [])
	_expect(not b.is_empty() and b.owner == foe and _near(b.life, 2.5) and float(b.toward) > 0.9,
			"Steamcraft on a bot: its steam drifts toward its foe, the one it aims at (%s)" % [b])


# ---------------------------------------------------------------- Cleanse
func _clear_whiff(n: Node) -> void:
	if n.has_meta(&"bend_whiff_until"):
		n.remove_meta(&"bend_whiff_until")


## The Turn of `who`'s (BendEffects.apply) with a gas cloud of the other's 1 m off him and one 7 m off: [near washed, far washed].
func _turn_gas(who: Node3D, other: Node3D) -> Array:
	await _face_off(10.0)
	var near := _gas(other, who.global_position + Vector3(1.0, 0.0, 0.0))
	var far := _gas(other, who.global_position + Vector3(-7.0, 0.0, 0.0), 1.5)
	await _ticks(2)
	BendEffects.apply(BendCaster.of(who), "water_redirect", "redirect", SwayMoves.move("water_redirect").bend.redirect)
	await _ticks(6)
	var out := [not is_instance_valid(near) or near.is_queued_for_deletion(), not is_instance_valid(far) or far.is_queued_for_deletion()]
	for g: BendZone in [near, far]:
		if is_instance_valid(g):
			g.end()
	await _secs(1.0)
	_clear_whiff(who)
	return out


func _cleanse() -> void:
	_wear(player, ["water.turn.cleanse"])
	var w: Array = await _turn_gas(player, foe)
	_wear(player, [])
	var c: Array = await _turn_gas(player, foe)
	_expect(bool(w[0]) and not bool(w[1]) and not bool(c[0]) and not bool(c[1]),
			"Cleanse: the wearer's Turn washes out the gas in its reach, not the cloud 7 m off; not worn none (%s, %s)" % [w, c])
	_wear(foe, ["water.turn.cleanse"])
	var b: Array = await _turn_gas(foe, player)
	_wear(foe, [])
	_expect(bool(b[0]), "Cleanse on a bot: its Turn clears the gas round it (%s)" % [b])
	# the Turn's lock, the player's real one on E (SwayCaster's guard lock) and a bot's
	var sc := SwayCaster.of(player)
	var keep := sc.lock_src
	sc.lock_src = SwayCaster.SRC_GUARD
	var got := {}
	for worn: bool in [true, false]:
		_wear(player, ["water.turn.cleanse"] if worn else [])
		_wear(foe, ["water.turn.cleanse"] if worn else [])
		_clear_whiff(player)
		_clear_whiff(foe)
		got[worn] = [sc._lock_time("water_redirect", null, 0.0, 10.0), NpcBending.lock_for("water_redirect", "redirect", "normal", 0.0, foe)]
	sc.lock_src = keep
	_wear(player, [])
	_wear(foe, [])
	_expect(absf(float(got[true][0]) / float(got[false][0]) - 1.2) < 0.001 and absf(float(got[true][1]) / float(got[false][1]) - 1.2) < 0.001,
			"Cleanse's trade: the Turn's lock 0.24 s for the 0.2 (the player's %.3f for %.3f, a bot's %.3f for %.3f)" % [got[true][0], got[false][0],
			got[true][1], got[false][1]])


# ---------------------------------------------------------------- Whirl Turn
## A perfect Turn of `turner`'s on a water bolt of `shooter`'s from 4 m; held on (`hold`: the player's E held; for a bot, the
## shooter guarding) or not: how long the bolt swung round him (s; -1 never caught).
func _swing_of(turner: Node3D, shooter: Node3D, hold: bool, settle := true) -> float:
	await _face_off(6.0)
	_clear_whiff(turner)
	BendEffects.apply(BendCaster.of(turner), "water_redirect", "redirect", SwayMoves.move("water_redirect").bend.redirect)
	var chest := NpcSenses.chest_of(turner)
	var from := chest + (shooter.global_position - turner.global_position).normalized() * 4.0
	var b := BendBolt.launch(shooter, from, chest - from, {"kind": "water", "mps": 30.0, "damage": 10.0, "radius_m": 0.2, "range_m": 10.0})
	var sc := SwayCaster.of(player)
	for i in 30:
		await physics_frame
		if not is_instance_valid(b) or b.swinging():
			break
	if not is_instance_valid(b) or not b.swinging():
		return -1.0
	if turner == player:
		sc.guard_override = hold
	elif hold:
		BendEffects.apply(BendCaster.of(shooter), "water_redirect", "redirect", SwayMoves.move("water_redirect").bend.redirect)
	for i in 90:
		await physics_frame
		if not is_instance_valid(b) or not b.swinging():
			break
	sc.guard_override = null
	var s := b.swing_held_s if is_instance_valid(b) else -1.0
	if settle:
		await _secs(1.2)
		_clear_whiff(turner)
		_clear_whiff(shooter)
	return s


## A late Turn of the player's (the bolt in after its beat): the share of the bolt's blow that goes on through.
func _late_share() -> float:
	await _face_off(6.0)
	BendEffects.apply(pc, "water_redirect", "redirect", SwayMoves.move("water_redirect").bend.redirect)
	await _secs(0.4)
	var chest := NpcSenses.chest_of(player)
	var from := chest + (foe.global_position - player.global_position).normalized() * 2.4
	var b := BendBolt.launch(foe, from, chest - from, {"kind": "water", "mps": 30.0, "damage": 10.0, "radius_m": 0.2, "range_m": 10.0})
	await _ticks(2)
	var share := b.damage / 10.0 if is_instance_valid(b) else -1.0
	await _secs(1.0)
	_clear_whiff(player)
	return share


func _whirl() -> void:
	_wear(player, ["water.turn.whirl"])
	var held: float = await _swing_of(player, foe, true)
	var tap: float = await _swing_of(player, foe, false)
	var late_w: float = await _late_share()
	_wear(player, [])
	var held0: float = await _swing_of(player, foe, true)
	var late_c: float = await _late_share()
	_expect(absf(held - 0.6) < 0.04 and absf(tap - 0.3) < 0.04, "Whirl Turn: E held through a perfect Turn, the water circles him %.2f s (0.6 at most); a tap swings %.2f s" % [held, tap])
	_expect(absf(held0 - 0.3) < 0.04, "Whirl Turn not worn: E held or not, the swing is %.2f s" % held0)
	_expect(_near(late_w, 0.6, 0.01) and _near(late_c, 0.5, 0.01), "Whirl Turn's trade: a late Turn lets %.2f through (Classic %.2f)" % [late_w, late_c])
	_wear(foe, ["water.turn.whirl"])
	var bh: float = await _swing_of(foe, player, true)
	var bt: float = await _swing_of(foe, player, false)
	_wear(foe, [])
	_expect(absf(bh - 0.6) < 0.04 and absf(bt - 0.3) < 0.04,
			"Whirl Turn on a bot: it holds the swing while its foe guards (%.2f s), sends it at once when he does not (%.2f s)" % [bh, bt])


# ---------------------------------------------------------------- Eddy
## After a perfect Turn of the player's (a water bolt of the foe's into it), `wait` s, then the Lash's lock begun on the foe (key 1,
## the aim held, the crosshair on him): its fill as it starts.
func _lash_fill_after_turn(wait: float) -> float:
	await _swing_of(player, foe, false, false)
	await _secs(wait)
	var sc := SwayCaster.of(player)
	sc._wait_release = false
	player.hotbar.select(0)
	aim_on = foe
	await _ticks(3)
	sc.held_override = true
	for i in 60:
		await physics_frame
		if sc.state != SwayCaster.State.IDLE:
			break
	var f := sc.fill if sc.state != SwayCaster.State.IDLE and sc.move == "water_whip" else -1.0
	sc.held_override = false
	await _ticks(2)
	sc.held_override = null
	aim_on = null
	await _secs(1.0)
	_clear_whiff(player)
	if player.has_meta(BendZone.EDDY_META):
		player.remove_meta(BendZone.EDDY_META)
	return f


func _eddy() -> void:
	_wear(player, ["water.turn.eddy"])
	var w: float = await _lash_fill_after_turn(0.0)
	var late: float = await _lash_fill_after_turn(1.6)
	_wear(player, [])
	var c: float = await _lash_fill_after_turn(0.0)
	_expect(w >= 0.4 and w < 0.5 and late >= 0.0 and late < 0.1 and c >= 0.0 and c < 0.1,
			"Eddy: the Lash's lock begun after a perfect Turn starts %.2f full; begun 1.6 s after, %.2f; not worn, %.2f" % [w, late, c])
	# the beat 0.25 s (stock and the Turn's own) for the wearer
	_wear(player, ["water.turn.eddy"])
	var z := BendZone.make(player, "redirect", player.global_position, BendLoadout.spec(player, "water_redirect", "redirect",
			SwayMoves.move("water_redirect").bend.redirect))
	var beat := z.perfect_s
	z.end("test")
	_expect(_near(beat, 0.25) and _near(BendLoadout.tune(player, "stock:guard_perfect_s", 0.3), 0.25), "Eddy's trade: the wearer's Turn's beat is %.2f s" % beat)
	_wear(player, [])
	_clear_whiff(player)
	# a bot wearing it: its Lash's lock after its perfect Turn begins 40% full
	_wear(foe, ["water.turn.eddy"])
	await _swing_of(foe, player, false, false)
	var nb: NpcBending = foe.brain.bending if foe.brain != null else null
	var bf := -1.0
	if nb != null:
		nb.begin("water_whip", "whip")
		bf = nb.lock_t / maxf(nb.lock_s, 0.001)
		nb._cancel()
	_wear(foe, [])
	_expect(absf(bf - 0.4) < 0.01, "Eddy on a bot: its Lash's lock after its perfect Turn begins %.2f full" % bf)
