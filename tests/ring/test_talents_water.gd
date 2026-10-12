extends SceneTree
## Water's talents in a real ring match (the owner, 2026-10-11: "we need to make sure all the talents work and they work in game
## right"): a 1v1 % ring, the player water against a fire bot; each talent worn by one fighter alone, played through the game's own
## code (BendEffects.apply's casts, the bolts' flight, the zones, the walls), worn and not worn, and a bot wearing it:
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_talents_water.gd [-- only=<name>[,<name>...]]
##                    (only: those checks alone, by their function's name without the underscore: mire, delta, mud_set ...)
##   each             live (BendLoadout.why_not ""), every water id of loadout_apply.json's behaviour map; Washout and Cleanse wait
##                    for earth's Sulphur set (their switch names it: the only gas in the game is its), live once it is
##   Thick Ice        the Ice Wall raised and shot with ice: worn it takes 4 hits and rises in 0.8 s (Classic 3, 0.7 s); a bot
##                    wearing it raises the same; switched on in loadout_apply.json
##   Washout          (switched on here as it will be with the Sulphur set live) a gas cloud (the Sulphur set's interface: a
##                    BendZone of kind gas, made here) between them: the wearer's Splash and Lash wash it out and fly on to hit;
##                    not worn it stays; a bot's too; his Splash adds 3.5 for 4; anyone's Geyser rising in gas washes it
##   Splashdown       the wearer's Lash on him (and into a wall) leaves a 1.2 m puddle of his for 6 s where it stopped, his
##                    Geyser's source there (the grates out of the pools meanwhile); not worn none; a bot's own; Lash 8 for 9
##   Steamcraft       his Lash met head-on by fire: the steam is his, hangs 2.5 s and drifts 1.2 m a second toward his aim; not
##                    worn 1.5 s and still; a bot's drifts toward its foe
##   Cleanse          (switched on as Washout) his Turn washes out a gas cloud 1 m off, not one 7 m off; not worn none; a bot's
##                    too; the Turn's lock on the player's real E (0.24 s for 0.2) and a bot's x1.2
##   Whirl Turn       a perfect Turn on a water bolt: E held the water circles him 0.6 s, a tap 0.3 s; not worn 0.3 s; a late
##                    Turn lets 0.6 through (0.5); a bot holds it while its foe guards
##   Eddy             after a perfect Turn the Lash's real lock (key 1, the aim held) starts 0.4 full, 1.6 s after or not worn
##                    from nothing; his Turn's beat 0.25 s; a bot's next Lash lock begins 0.4 full
##   Pooling Wave     his Wave leaves a 1.2 m puddle of his for 6 s on the deck where its cone ends; not worn none; a bot's
##                    own; his Wave hits launch exactly as its class says (base 6.8 for 7.5, grown 7.6 for 8.4: RingRules.on_hit)
##   Ride the Wave    the player's real Wave (key 2, the aim held to the click): let go on the Beat it carries him 3 m on
##                    behind the water, the Beat's flash on his own hands; 0.3 s after the click, or not worn, none; its lock
##                    0.65 s (0.6); hit sideways 3 frames into the ride he is knocked as far as one standing (the ride ends);
##                    the Beat flag only for a wearer (Classic never); a bot rides its Wave in from 10 m, not from 4, at its
##                    difficulty's beat_rate (1: always, 0: never)
##   Wet Trail        his Skate travels 10.8 m/s and leaves 4 puddles of his for 7.2 s spread along its slide (each 0.6 m on
##                    at least, 2.4 m from first to last); not worn 12 m/s, none; a bot's own
##   Wellspring       Patch's ring lock (the player's real key 5 held: SwayCaster's lock as it begins; a bot's lock_for): 1.25 s
##                    in his own puddle or at a grate, 1.6 s dry or in another's puddle (1.5)
##   the Mud set      his Downpour leaves a mud pool of his for 8 s (a puddle for 6 not worn), still a pool; a Kick's floor fire
##                    dies in his mud and hits across a puddle; a Fire Wall over it burns 2 s and dries it in about 1 s; a
##                    rolling stone stops in it; a seam (the fire set's interface, a stand-in) is quenched; four pools of his at
##                    most; his Splash 25.2 and Lash 30.6 m/s (28, 34); a bot's Downpour its own mud
##   Mud Lash         (with the set) the Lash flies 28 m/s; fire it meets is smothered, no steam (the set alone: steam); it adds
##                    10 for 9 and launches harder; a bot's smothers too
##   Mudslide         (with the set) the Wave reaches 7.5 m (9), grown 10 m (12), and leaves a 2 m mud pool of his where it
##                    ends; its hits launch as its class says (8.6 for 7.5, grown 9.7 for 8.4); a bot's own pool
##   Mud Mound        (with the set) his Geyser leaves a mud mound 1.5 x 0.7 m for 3 s where it rose, never one of his walls: a
##                    Kick's fire stops at it, a body stands on it, two at once, nobody's wall (no bend_by: Mend's target,
##                    a bot's own wall); the Geyser launches as its class says (9.3 for 10.9); a bot's own
##   Delta            (with the set) his mud lasts 6.5 s; in his own mud his locks fill x1.15 (another's or dry x1): the Lash's
##                    real lock 0.400 s for 0.467; a bot's tick takes the same
##   Mire             (with the set) the player's real 4 tapped twice readies it (the strip shows it); its lock (0.9 for the Ice
##                    Wall's 0.85) let go lays a 3 m mud pool of his for 8 s 6 m on where he aims (2-6), a pool, cast with the Ice
##                    Wall's pose; one at a time beside his four other pools; a Kick's floor fire dies in it; his Geyser's source;
##                    his Ice Wall rises in 0.8 s; Delta's 6.5 s; not worn 4 twice is the Ice Wall; a bot's lock and its own Mire,
##                    laid against a foe with floor fire (never a water foe, never unworn)
##   stacking         worn together as the tree's stacking says (BendLoadout._fold_n): Splashdown and Steamcraft's Lash 8 for 9
##                    each, both paid (9 x 8/9 x 8/9); Mud Lash's 28 m/s final over the set's 30.6 in either order; Drench beside
##                    Mudslide (6.5 and 8.6 from 7.5: opposite pulls) refused; Thick Ice beside Mire: Mire's rise final
## Last line "TALENTS WATER PASSED (n checks)" or "... FAILED"; exit 0 only on a pass.

const NAME := "TALENTS WATER"
## The talents that only wash gas (their switch waits for earth's Sulphur set: loadout_apply.json nodes).
const GAS_TALENTS := ["water.splash.washout", "water.turn.cleanse"]
const LIMIT_S := 520.0

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


## Whether check `name` runs (every one, unless the user args say only=...).
func _on(name: String) -> bool:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			return name in a.substr(5).split(",")
	return true


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
		BendStatus.spend_cast_mult(b)             # (a perfect guard's cast reward from a check before: every lock its own)
		var kn := BendKnock.peek(b)
		if kn != null:
			kn.reset()                            # (no knock, hitstun or tumble left from a check before)
			kn.stun_t = 0.0
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
	var sulphur := BendLoadout.why_not("earth.set.sulphur") == ""
	for id: String in BendLoadout.behaviour():
		if id.begins_with("water."):
			if id in GAS_TALENTS and not sulphur:
				_expect(BendLoadout.why_not(id).begins_with("waits for earth.set.sulphur") and not AdvancementData.is_live(id),
						"%s waits for the Sulphur set's gas, the window's dot too (%s)" % [id, BendLoadout.why_not(id)])
			else:
				_expect(BendLoadout.why_not(id) == "", "%s is live (%s)" % [id, BendLoadout.why_not(id)])
	if _on("thick_ice"):
		await _thick_ice()
	if _on("washout"):
		await _washout()
	if _on("splashdown"):
		await _splashdown()
	if _on("steamcraft"):
		await _steamcraft()
	if _on("cleanse"):
		await _cleanse()
	if _on("whirl"):
		await _whirl()
	if _on("eddy"):
		await _eddy()
	if _on("pooling"):
		await _pooling()
	if _on("ride"):
		await _ride()
	if _on("wet_trail"):
		await _wet_trail()
	if _on("wellspring"):
		await _wellspring()
	if _on("mud_set"):
		await _mud_set()
	if _on("mud_lash"):
		await _mud_lash()
	if _on("mudslide"):
		await _mudslide()
	if _on("mud_mound"):
		await _mud_mound()
	if _on("delta"):
		await _delta()
	if _on("mire"):
		await _mire()
	if _on("stacking"):
		_stacking()
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


## The gas talents' switches on, as they will be with the Sulphur set live (its gas the only gas in the game: stand-in clouds here).
func _gas_on(on: bool) -> void:
	var nd := {}
	for id: String in GAS_TALENTS:
		nd[id] = true
	BendLoadout.config_override = {"nodes": nd} if on else {}


func _washout() -> void:
	_gas_on(true)
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
	# the Washed Ground synergy's base, for everyone (the node's "the Wave and Geyser already do"): a Geyser rising in gas washes
	# it; nothing worn
	await _face_off(8.0)
	var g := _gas(foe, foe.global_position, 2.0)
	var far := _gas(foe, foe.global_position + Vector3(6.0, 0.0, 0.0), 1.0)
	await _ticks(2)
	BendEffects.apply(pc, "wave", "spout", SwayMoves.move("wave").bend.spout)
	await _secs(0.8)
	var gw := not is_instance_valid(g) or g.is_queued_for_deletion()
	var fw := not is_instance_valid(far) or far.is_queued_for_deletion()
	for z: BendZone in [g, far]:
		if is_instance_valid(z):
			z.end()
	_expect(gw and not fw, "Washed Ground: anyone's Geyser (nothing worn) washes the gas it rises in, not a cloud 6 m off (%s, %s)" % [gw, fw])
	_gas_on(false)
	BendLoadout.wear(player, ["water.splash.washout"], "", "water")
	_expect(not BendLoadout.wears(player, "water.splash.washout") or BendLoadout.why_not("earth.set.sulphur") == "",
			"Washout with no Sulphur set live: refused, nothing of it applies (no trade with nothing to wash)")
	_wear(player, [])


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


## The player's real Turn on E (a tap: SwayCaster's guard lock as it begins, the Turn cast when it fills): its lock (s).
func _turn_lock_by_e() -> float:
	var sc := SwayCaster.of(player)
	for i in 120:
		if sc.state == SwayCaster.State.IDLE and not sc._cast_wait():
			break
		await physics_frame
	_clear_whiff(player)
	sc.guard_override = true
	var lock := -1.0
	for i in 30:
		await physics_frame
		if sc.state != SwayCaster.State.IDLE and sc.lock_src == SwayCaster.SRC_GUARD:
			lock = sc.lock_s
			break
	sc.guard_override = false
	await _secs(1.2)
	sc.guard_override = null
	_clear_whiff(player)
	return lock


func _cleanse() -> void:
	_gas_on(true)
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
	# the Turn's lock, the player's real one on E (SwayCaster's guard lock as it begins) and a bot's
	var got := {}
	for worn: bool in [true, false]:
		_wear(player, ["water.turn.cleanse"] if worn else [])
		_wear(foe, ["water.turn.cleanse"] if worn else [])
		await _face_off(10.0)
		_clear_whiff(foe)
		got[worn] = [await _turn_lock_by_e(), NpcBending.lock_for("water_redirect", "redirect", "normal", 0.0, foe)]
	_wear(player, [])
	_wear(foe, [])
	_gas_on(false)
	_expect(float(got[false][0]) > 0.0 and absf(float(got[true][0]) / float(got[false][0]) - 1.2) < 0.001
			and absf(float(got[true][1]) / float(got[false][1]) - 1.2) < 0.001,
			"Cleanse's trade: the Turn's lock on E %.3f s for the %.3f (0.24 for 0.2), a bot's %.3f for %.3f" % [got[true][0], got[false][0],
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


# ---------------------------------------------------------------- Pooling Wave
## A Wave of `who`'s at the other from 8 m (BendEffects.apply): the puddle of his it left (null none), and where the cone ended.
var _wave_from := Vector3.ZERO
func _wave_puddle(who: Node3D) -> BendZone:
	await _face_off(8.0)
	_wave_from = who.global_position
	var before := _zones("puddle")
	_cast(who, "wave", "push")
	await _ticks(3)
	var pd := _new_zone("puddle", before, who)
	await _secs(0.8)
	return pd


## The launch (m/s) a hit of `by`'s with `tag` gives `on` at 0% (RingRules.on_hit, the class of the tag for the hitter), `on` first
## still on the deck (no knock, hitstun, tumble or lying left from a check before), his % back after. Checked exact against the
## launch formula (RingRules.launch_v) with the stock class's numbers and the node text's own `want_base` (and `want_d`: -1 the
## class's), read from no loadout code.
func _wave_launch(by: Node3D, on: Node3D, tag: String, want_base := -1.0, want_d := -1.0) -> float:
	var rules := RingRules.current()
	var kn := BendKnock.peek(on)
	if kn != null:
		kn.reset()
		kn.stun_t = 0.0
	(on as CharacterBody3D).velocity = Vector3.ZERO
	await _ticks(4)
	for i in 90:
		if (on as CharacterBody3D).is_on_floor():
			break                                    # (back on the deck from a knock before: the hit's own rule for the feet)
		await physics_frame
	var floored := (on as CharacterBody3D).is_on_floor()
	rules.reset_pct(on, 0.0)
	var r := rules.on_hit(on, by, {"tag": tag, "at": (on as Node3D).global_position + Vector3.UP})
	rules.reset_pct(on, 0.0)
	if kn == null:
		kn = BendKnock.peek(on)
	if kn != null:
		kn.reset()
		kn.stun_t = 0.0
	var v := (r.get("v", Vector3.ZERO) as Vector3).length()
	var cls := RingRules.class_of(tag).duplicate()
	if want_base >= 0.0:
		cls["base"] = want_base
	if want_d >= 0.0:
		cls["d"] = want_d
	var d := float(cls.get("d", 0.0)) * RingRules.stock_num("pct_scale", 1.0)
	var want := RingRules.launch_v(cls, d, d, RingRules.weight_of(BendPoses.element_of(on)))
	var ang := float(cls.get("angle", 30.0))
	if floored and want < RingRules.stock_num("tumble_mps", 9.0) and absf(ang) < RingRules.stock_num("tumble_deg", 60.0):
		want *= cos(deg_to_rad(ang))               # (no tumble on the feet: a flinch-slide, its up part dropped: RingRules.on_hit)
	_expect(absf(v - want) < 0.02, "%s by %s: launches %.3f m/s, the formula with base %.2f says %.3f" % [tag,
			"the player" if by == player else "the bot", v, float(cls.get("base", 0.0)), want])
	return v


func _pooling() -> void:
	_wear(player, ["water.wave.pooling"])
	var pd := await _wave_puddle(player)
	var reach := float((SwayMoves.move("wave").bend.push as Dictionary).range_m)
	var d := Vector2(pd.global_position.x - _wave_from.x, pd.global_position.z - _wave_from.z).length() if pd != null else -1.0
	_expect(pd != null and _near(pd.radius, 1.2) and _near(pd.life_s, 6.0) and d <= reach + 0.3 and d >= reach - 2.0
			and absf(pd.global_position.y - _wave_from.y) < 0.5 and pd.is_in_group(Bending.POOLS),
			"Pooling Wave: the wearer's Wave leaves a 1.2 m puddle of his for 6 s on the deck where its cone ends, %.1f m on (its reach %.0f, kept off the lip)" % [d, reach])
	var lw: float = await _wave_launch(player, foe, "wave/push", 6.8)
	var lgw: float = await _wave_launch(player, foe, "wave/push.grown", 7.6)
	_wear(player, [])
	var p0 := await _wave_puddle(player)
	var lc: float = await _wave_launch(player, foe, "wave/push", 7.5)
	var lgc: float = await _wave_launch(player, foe, "wave/push.grown", 8.4)
	_expect(p0 == null, "Pooling Wave not worn: the Wave leaves no puddle")
	_expect(lw > 0.0 and lw < lc and lgw < lgc, "Pooling Wave's trade: his Wave launches %.2f m/s for the %.2f (grown %.2f for %.2f)" % [lw, lc, lgw, lgc])
	_wear(foe, ["water.wave.pooling"])
	var pb := await _wave_puddle(foe)
	_wear(foe, [])
	_expect(pb != null and pb.owner_node == foe, "Pooling Wave on a bot: its Wave leaves its own puddle")
	for z: BendZone in _zones("puddle").values():
		z.end()


# ---------------------------------------------------------------- Ride the Wave
## The player's own Wave (key 2, the aim held on the foe till the click, let go `late` s after it): {lock (s), moved (m along the
## way to the foe in 0.6 s), ride (the cast's record)}.
func _ride_wave(late: float) -> Dictionary:
	await _face_off(10.0)
	var sc := SwayCaster.of(player)
	for i in 180:
		if sc.state == SwayCaster.State.IDLE and not sc._cast_wait() and player.is_on_floor():
			break                                     # (on the deck: key 2 in the air is the Downpour)
		await physics_frame
	sc._wait_release = false
	player.hotbar.select(1)
	await _ticks(3)
	var from := player.global_position
	var way := (foe.global_position - from)
	way.y = 0.0
	way = way.normalized()
	sc.held_override = true
	var lock := -1.0
	for i in 120:
		await physics_frame
		if sc.state != SwayCaster.State.IDLE and lock < 0.0:
			lock = sc.lock_s
		if sc.state == SwayCaster.State.FULL:
			break
	await _secs(late)
	var at := player.global_position
	sc.held_override = false
	await _secs(0.6)
	sc.held_override = null
	var out := {"lock": lock, "moved": (player.global_position - at).dot(way), "ride": bool(BendEffects.last_of(pc).get("ride", false)),
			"move": String(BendEffects.last_of(pc).get("move", "")),
			"beat": bool(((BendEffects.last_of(pc).get("spec", {}) as Dictionary).get("_info", {}) as Dictionary).get("beat", false))}
	await _secs(0.8)
	return out


## The player hit sideways (an 8 m/s launch, as RingRules.on_hit sets one) `riding`: 3 frames into his ride (the real Wave on the
## Beat), else standing: how far the knock took him sideways and on along the Wave's way in 1.2 s.
func _ride_hit(riding: bool) -> Dictionary:
	await _face_off(10.0)
	var way := (foe.global_position - player.global_position)
	way.y = 0.0
	way = way.normalized()
	var side := way.cross(Vector3.UP).normalized()
	var rode := false
	if riding:
		var sc := SwayCaster.of(player)
		for i in 180:
			if sc.state == SwayCaster.State.IDLE and not sc._cast_wait() and player.is_on_floor():
				break
			await physics_frame
		sc._wait_release = false
		player.hotbar.select(1)
		await _ticks(3)
		sc.held_override = true
		for i in 120:
			await physics_frame
			if sc.state == SwayCaster.State.FULL:
				break
		sc.held_override = false
		var bm := BendMotion.of(player)
		for i in 20:
			await physics_frame
			if bm.riding():
				rode = true
				break
		await _ticks(3)
		sc.held_override = null
	var at := player.global_position
	var v := side * 8.0
	BendKnock.of(player).knock(v, foe, {"_launch": {"v": v, "hitstun_s": RingRules.hitstun_of(8.0), "tumble": false}})
	await _secs(1.2)
	var d := player.global_position - at
	var out := {"rode": rode, "side": d.dot(side), "on": d.dot(way)}
	var kn := BendKnock.peek(player)
	if kn != null:
		kn.reset()
		kn.stun_t = 0.0
	await _secs(0.5)
	return out


func _ride() -> void:
	_wear(player, ["water.wave.ride"])
	var beat: Dictionary = await _ride_wave(0.0)
	var late: Dictionary = await _ride_wave(0.3)
	_wear(player, [])
	var c: Dictionary = await _ride_wave(0.0)
	_expect(beat.move == "wave" and bool(beat.ride) and absf(float(beat.moved) - 3.0) < 0.6,
			"Ride the Wave: his Wave let go on the Beat carries him %.2f m on behind it (3)" % float(beat.moved))
	_expect(late.move == "wave" and not bool(late.ride) and absf(float(late.moved)) < 0.5, "Ride the Wave: let go 0.3 s after the click, no ride (%.2f m)" % float(late.moved))
	_expect(c.move == "wave" and not bool(c.ride) and absf(float(c.moved)) < 0.5, "Ride the Wave not worn: on the Beat or not, the Wave carries no one (%.2f m)" % float(c.moved))
	_expect(bool(beat.beat) and not bool(late.beat) and not bool(c.beat),
			"the Beat: its hits say beat only for the wearer let go on it (worn on the Beat %s, 0.3 s late %s, nothing worn on the click %s: Classic as ever)"
			% [beat.beat, late.beat, c.beat])
	_expect(float(c.lock) > 0.0 and absf(float(beat.lock) / float(c.lock) - 0.65 / 0.6) < 0.01, "Ride the Wave's trade: the Wave's lock %.3f s for the %.3f (0.65 for 0.6)" % [float(beat.lock), float(c.lock)])
	# hit while riding: the hit's motion, as for anyone (the ride ends; no knock lost)
	_wear(player, ["water.wave.ride"])
	var hr: Dictionary = await _ride_hit(true)
	_wear(player, [])
	var hs: Dictionary = await _ride_hit(false)
	_expect(bool(hr.rode) and float(hs.side) > 2.0 and absf(float(hr.side) - float(hs.side)) < 0.35 and float(hr.on) < 1.5,
			"Ride the Wave: hit sideways 3 frames into the ride he is knocked %.2f m, as far as standing (%.2f m), and the ride ends (%.2f m on)"
			% [float(hr.side), float(hs.side), float(hr.on)])
	# a bot wearing it rides its Wave in from afar, not from close by (NpcBending's release: _on_beat)
	var nb: NpcBending = foe.brain.bending if foe.brain != null else null
	var pre: Dictionary = NpcBending.preset_of(nb._preset_name()) if nb != null else {}
	var rate_keep: Variant = pre.get("beat_rate")
	var got := {}
	for c2: Array in [[10.0, 1.0], [4.0, 1.0], [10.0, 0.0]]:
		pre["beat_rate"] = float(c2[1])              # (its difficulty's beat_rate: 1 always, 0 never)
		var d := float(c2[0])
		_wear(foe, ["water.wave.ride"])
		await _face_off(d)
		var at := foe.global_position
		var way := (player.global_position - at)
		way.y = 0.0
		way = way.normalized()
		if nb != null:
			nb.begin("wave", "push")
			nb._release()
		await _secs(0.6)
		got["%d/%d" % [int(d), int(c2[1])]] = (foe.global_position - at).dot(way)
		_wear(foe, [])
		await _secs(0.6)
	if rate_keep == null:
		pre.erase("beat_rate")
	else:
		pre["beat_rate"] = rate_keep
	_expect(nb != null and absf(float(got["10/1"]) - 3.0) < 0.6 and absf(float(got["4/1"])) < 0.5 and absf(float(got["10/0"])) < 0.5,
			"Ride the Wave on a bot: from 10 m its Wave rides it %.2f m in; from 4 m it stays (%.2f m); at a beat_rate of 0 never (%.2f m)"
			% [float(got.get("10/1", -1.0)), float(got.get("4/1", -1.0)), float(got.get("10/0", -1.0))])
	var rates := [float(NpcBending.preset_of("easy").get("beat_rate", -1.0)), float(NpcBending.preset_of("normal").get("beat_rate", -1.0)),
			float(NpcBending.preset_of("hard").get("beat_rate", -1.0))]
	_expect(_near(rates[0], 0.0) and _near(rates[1], 0.2) and _near(rates[2], 0.5), "the Beat's bot rate by difficulty (bend_ai.json): %s (0, 0.2, 0.5)" % [rates])


# ---------------------------------------------------------------- Wet Trail
## A Skate of `who`'s (BendEffects.apply flow/skate): {n (the puddles of his it left), life, radius, spread (m from the first to the
## last), mps (its travel)}.
func _skate_trail(who: Node3D) -> Dictionary:
	await _face_off(10.0)
	# (room to slide: the skater at the deck's middle, the other 5 m on; nothing held, so the Skate goes back across the deck)
	var other: Node3D = foe if who == player else player
	var way := (other.global_position - who.global_position)
	way.y = 0.0
	way = way.normalized()
	who.global_position = Vector3(home.x, who.global_position.y, home.z)
	other.global_position = Vector3(home.x, other.global_position.y, home.z) + way * 5.0
	await _ticks(3)
	var before := _zones("puddle")
	BendEffects.apply(BendCaster.of(who), "flow", "skate", SwayMoves.move("flow").bend.skate)
	var v: Vector3 = BendEffects.last_of(BendCaster.of(who)).get("v", Vector3.ZERO)
	await _secs(0.8)
	var mine: Array = []
	for z: BendZone in _zones("puddle").values():
		if not before.has(z.get_instance_id()) and z.owner_node == who:
			mine.append(z)
	var spread := 0.0
	var gap := INF                                   # (the nearest two: each puddle new ground)
	for a: BendZone in mine:
		for b: BendZone in mine:
			spread = maxf(spread, a.global_position.distance_to(b.global_position))
			if a != b:
				gap = minf(gap, a.global_position.distance_to(b.global_position))
	var out := {"n": mine.size(), "life": (mine[0] as BendZone).life_s if not mine.is_empty() else -1.0,
			"radius": (mine[0] as BendZone).radius if not mine.is_empty() else -1.0, "spread": spread, "gap": gap,
			"mps": Vector2(v.x, v.z).length()}
	for z: BendZone in mine:
		z.end()
	await _secs(0.5)
	return out


func _wet_trail() -> void:
	_wear(player, ["water.skate.wet_trail"])
	var w: Dictionary = await _skate_trail(player)
	_wear(player, [])
	var c: Dictionary = await _skate_trail(player)
	_expect(int(w.n) == 4 and _near(w.life, 7.2) and _near(w.radius, 1.2) and float(w.spread) >= 2.4 and float(w.gap) >= 0.6
			and _near(w.mps, 10.8, 0.01),
			"Wet Trail: the wearer's Skate travels %.1f m/s and leaves 4 puddles of his for 7.2 s spread along %.1f m, %.1f m apart at least (%s)"
			% [float(w.mps), float(w.spread), float(w.gap), w])
	_expect(int(c.n) == 0 and _near(c.mps, 12.0, 0.01), "Wet Trail not worn: the Skate travels %.1f m/s and leaves no puddle (%d)" % [float(c.mps), int(c.n)])
	_wear(foe, ["water.skate.wet_trail"])
	var b: Dictionary = await _skate_trail(foe)
	_wear(foe, [])
	_expect(int(b.n) == 4 and float(b.spread) >= 2.4, "Wet Trail on a bot: its Skate leaves its own 4 puddles along %.1f m (%d)" % [float(b.spread), int(b.n)])


# ---------------------------------------------------------------- Wellspring
## Patch's ring lock for the player (his real key 5 held: SwayCaster's lock as it begins, let go before it fills: called off, nothing
## spent) and for the bot (NpcBending.lock_for), each standing where it is now.
func _patch_locks() -> Array:
	var sc := SwayCaster.of(player)
	var at := player.global_position
	for i in 120:
		if sc.state == SwayCaster.State.IDLE and not sc._cast_wait() and player.is_on_floor():
			break
		await physics_frame
	sc._wait_release = false
	RingRules.current().add_pct(player, 6.0, foe, "water_jet/splash")     # (a fresh pool to take back: Patch may begin)
	await _secs(Bending.rule("double_tap_s", 0.3) + 0.1)   # (a key 5 again within double_tap_s would be Mend, its other)
	player.hotbar.select(4)
	await _ticks(2)
	sc.held_override = true
	var l := -1.0
	for i in 30:
		await physics_frame
		if sc.state != SwayCaster.State.IDLE and sc.move == "patch":
			l = sc.lock_s
			break
	sc.held_override = false
	await _ticks(3)
	sc.held_override = null
	RingRules.current().reset_pct(player, 0.0)
	player.global_position = at
	player.velocity = Vector3.ZERO
	await _ticks(2)
	return [l, NpcBending.lock_for("patch", "patch", "normal", 0.0, foe)]


func _wellspring() -> void:
	await _face_off(10.0)
	var grates: Array = get_nodes_in_group(Bending.POOLS).filter(func(n: Node) -> bool: return not (n is BendZone))
	var got := {}
	for worn: bool in [true, false]:
		_wear(player, ["water.patch.wellspring"] if worn else [])
		_wear(foe, ["water.patch.wellspring"] if worn else [])
		await _face_off(10.0)
		for g: Node in grates:
			g.remove_from_group(Bending.POOLS)        # (out of the pools while dry and puddle are read: no grate in reach then)
		var dry: Array = await _patch_locks()
		var pp := BendZone.make(player, "puddle", FormEffects.ground_at(player, player.global_position), {"radius_m": 1.2, "life_s": 6.0})
		var pf := BendZone.make(foe, "puddle", FormEffects.ground_at(foe, foe.global_position), {"radius_m": 1.2, "life_s": 6.0})
		var other := BendZone.make(foe, "puddle", FormEffects.ground_at(player, player.global_position), {"radius_m": 1.2, "life_s": 6.0})
		await _ticks(2)
		var wet: Array = await _patch_locks()
		pp.end()
		pf.end()
		await _ticks(2)
		var theirs: Array = await _patch_locks()     # (in the foe's puddle only: not his own water)
		other.end()
		for g: Node in grates:
			g.add_to_group(Bending.POOLS)
		var grate := [-1.0, -1.0]
		if not grates.is_empty():
			var g3 := grates[0] as Node3D
			var keep_at := player.global_position
			player.global_position = Vector3(g3.global_position.x, player.global_position.y, g3.global_position.z)
			await _ticks(2)
			grate = await _patch_locks()
			player.global_position = keep_at
		got[worn] = {"dry": dry, "wet": wet, "theirs": theirs, "grate": grate}
		await _ticks(2)
	_wear(player, [])
	_wear(foe, [])
	var w: Dictionary = got[true]
	var c: Dictionary = got[false]
	var k := func(a: Array, b: Array, i: int) -> float: return float(a[i]) / maxf(float(b[i]), 0.001)
	_expect(absf(k.call(w.wet, c.wet, 0) - 1.25 / 1.5) < 0.01 and absf(k.call(w.dry, c.dry, 0) - 1.6 / 1.5) < 0.01
			and absf(k.call(w.theirs, c.theirs, 0) - 1.6 / 1.5) < 0.01 and (grates.is_empty() or absf(k.call(w.grate, c.grate, 0) - 1.25 / 1.5) < 0.01),
			"Wellspring: his Patch locks %.2f s in his own puddle%s, %.2f s anywhere else, in another's puddle too (Classic %.2f s)" % [float(w.wet[0]),
			" and at a grate" if not grates.is_empty() else "", float(w.dry[0]), float(c.dry[0])])
	_expect(absf(k.call(w.wet, c.wet, 1) - 1.25 / 1.5) < 0.01 and absf(k.call(w.dry, c.dry, 1) - 1.6 / 1.5) < 0.01,
			"Wellspring on a bot: its Patch lock x%.3f in its own puddle, x%.3f out of it" % [k.call(w.wet, c.wet, 1), k.call(w.dry, c.dry, 1)])


# ---------------------------------------------------------------- the Mud set
## A puddle of `by`'s at `at` (BendZone.make: every puddle source's own path; the Mud set's wearer's comes out a mud pool).
func _pool_at(by: Node3D, at: Vector3, r := 2.0) -> BendZone:
	return BendZone.make(by, "puddle", FormEffects.ground_at(by, at), {"radius_m": r, "life_s": 6.0})


func _end_pools() -> void:
	for k: String in ["puddle", "mud", "fire_wall", "seam", "gas"]:
		for z: BendZone in _zones(k).values():
			z.end("test")
	await _ticks(2)


## The player's Downpour on the deck (BendEffects.apply wave/slam): the pool it left, read at once ({} none: a zone the next
## _face_off clears reads as null after).
func _downpour_pool() -> Dictionary:
	await _face_off(10.0)
	BendEffects.apply(pc, "wave", "slam", SwayMoves.move("wave").bend.slam)
	var z: Variant = BendEffects.last_of(pc).get("puddle")
	await _ticks(2)
	if not (z is BendZone) or not is_instance_valid(z):
		return {}
	var bz := z as BendZone
	return {"kind": bz.kind, "owner": bz.owner_node, "life": bz.life_s, "pool": bz.is_in_group(Bending.POOLS)}


## The foe's Kick (a floor wave of fire) at the player across a pool of the player's midway: the % it added to him.
func _kick_through_pool() -> float:
	await _face_off(10.0)
	RingRules.current().reset_pct(player, 0.0)
	_pool_at(player, home, 2.0)
	await _ticks(2)
	BendEffects.apply(fc, "fire_kick", "kick", SwayMoves.move("fire_kick").bend.kick)
	await _secs(1.0)
	var got := RingRules.current().pct_of(player)
	RingRules.current().reset_pct(player, 0.0)
	await _end_pools()
	return got


## The foe's Fire Wall raised over a pool of the player's (where it places it, 6 m on toward him): {wall_life, pool_gone_s (how
## long the pool lasted after the wall rose; -1 it stayed 1.5 s)}.
func _fire_over_pool() -> Dictionary:
	await _face_off(10.0)
	var way := (player.global_position - foe.global_position).normalized()
	var pool := _pool_at(player, foe.global_position + way * 6.0, 2.0)
	await _ticks(2)
	var before := _zones("fire_wall")
	BendEffects.apply(fc, "fire_wall", "wall", SwayMoves.move("fire_wall").bend.wall)
	var fw := _new_zone("fire_wall", before)
	var gone := -1.0
	for i in ceili(1.5 * Engine.physics_ticks_per_second):
		await physics_frame
		if not is_instance_valid(pool) or pool.is_queued_for_deletion():
			gone = float(i + 1) / Engine.physics_ticks_per_second
			break
	var out := {"wall_life": fw.life_s if fw != null and is_instance_valid(fw) else -1.0, "pool_gone_s": gone}
	await _end_pools()
	return out


## A stone rolled at 5 m/s into a pool of the player's 3 m off: {speed (m/s) and inside (whether it is in the pool) 1 s on}.
func _roll_into_pool() -> Dictionary:
	await _face_off(10.0)
	var side := Vector3(1, 0, 0)
	var pool := _pool_at(player, home + side * 3.0, 2.0)
	var foot := FormEffects.ground_at(player, home)
	var s := FormStone.ball(current_scene, foot, {"radius_m": 0.3, "mass_kg": 20.0, "rise_s": 0.01, "life_s": 30.0}, 7, "stone")
	s.state = FormStone.State.RESTING
	s.base = Transform3D(Basis.IDENTITY, foot + Vector3.UP * 0.32)
	s.global_transform = s.base
	s.freeze = false
	s.linear_velocity = side * 5.0
	await _secs(1.0)
	var out := {"speed": Vector2(s.linear_velocity.x, s.linear_velocity.z).length(), "inside": is_instance_valid(pool) and pool.inside(s.global_position)}
	s.queue_free()
	await _end_pools()
	return out


func _mud_set() -> void:
	var mud := ["water.set.mud"]
	_wear(player, mud)
	var dp: Dictionary = await _downpour_pool()
	_expect(not dp.is_empty() and dp.kind == "mud" and dp.owner == player and _near(dp.life, 8.0) and bool(dp.pool),
			"the Mud set: the wearer's Downpour leaves a mud pool of his for 8 s, still his source (%s)" % [dp])
	var kick_w: float = await _kick_through_pool()
	var fire_w: Dictionary = await _fire_over_pool()
	var roll_w: Dictionary = await _roll_into_pool()
	# a magma seam (the fire set's, built elsewhere: a BendZone of kind seam) over his mud is quenched
	await _face_off(10.0)
	_pool_at(player, home, 2.0)
	var seam := BendZone.make(foe, "seam", FormEffects.ground_at(foe, home), {"width_m": 1.5, "height_m": 0.4, "thick_m": 4.0, "life_s": 3.0})
	await _secs(0.4)
	var seam_w := not is_instance_valid(seam) or seam.is_queued_for_deletion()
	await _end_pools()
	# four pools of his at once
	await _face_off(10.0)
	for i in 5:
		_pool_at(player, home + Vector3(float(i) * 1.0 - 2.0, 0.0, 0.0), 1.2)
	await _ticks(2)
	var n_mud := 0
	for z: BendZone in _zones("mud").values():
		n_mud += 1 if z.owner_node == player else 0
	await _end_pools()
	# the trade: heavy water
	await _face_off(10.0)
	var sp := _cast(player, "water_jet", "splash")
	var lp := _cast(player, "water_whip", "whip")
	var sw := [sp.velocity.length() if sp != null else -1.0, lp.velocity.length() if lp != null else -1.0]
	await _secs(1.0)
	_wear(player, [])
	var dp0: Dictionary = await _downpour_pool()
	var kick_c: float = await _kick_through_pool()
	var fire_c: Dictionary = await _fire_over_pool()
	var roll_c: Dictionary = await _roll_into_pool()
	await _face_off(10.0)
	_pool_at(player, home, 2.0)
	var seam0 := BendZone.make(foe, "seam", FormEffects.ground_at(foe, home), {"width_m": 1.5, "height_m": 0.4, "thick_m": 4.0, "life_s": 3.0})
	await _secs(0.4)
	var seam_c := not is_instance_valid(seam0) or seam0.is_queued_for_deletion()
	await _end_pools()
	await _face_off(10.0)
	var sp0 := _cast(player, "water_jet", "splash")
	var lp0 := _cast(player, "water_whip", "whip")
	var sc0 := [sp0.velocity.length() if sp0 != null else -1.0, lp0.velocity.length() if lp0 != null else -1.0]
	await _secs(1.0)
	_expect(not dp0.is_empty() and dp0.kind == "puddle" and _near(dp0.life, 6.0), "the Mud set not worn: the Downpour's puddle as ever (%s)" % [dp0])
	_expect(is_zero_approx(kick_w) and kick_c > 0.0, "the Mud set: a Kick's floor fire dies in his mud (+%.1f%%); across a plain puddle it hits (+%.1f%%)" % [kick_w, kick_c])
	_expect(_near(fire_w.wall_life, 2.0) and float(fire_w.pool_gone_s) > 0.0 and float(fire_w.pool_gone_s) <= 1.3 and float(fire_c.wall_life) > 2.0
			and float(fire_c.pool_gone_s) < 0.0, "the Mud set: a Fire Wall over his mud burns %.1f s and dries it in %.2f s; over a puddle %.1f s, the puddle stays" % [
			float(fire_w.wall_life), float(fire_w.pool_gone_s), float(fire_c.wall_life)])
	_expect(float(roll_w.speed) < 0.5 and bool(roll_w.inside) and (float(roll_c.speed) > 0.5 or not bool(roll_c.inside)),
			"the Mud set: a rolling stone stops in his mud (%s); through a puddle it rolls on (%s)" % [roll_w, roll_c])
	_expect(seam_w and not seam_c, "the Mud set: a magma seam over his mud is quenched (a stand-in seam: the fire set is built elsewhere); not over a puddle")
	_expect(n_mud == 4, "the Mud set: four mud pools of his at most (%d)" % n_mud)
	_expect(absf(float(sw[0]) - 25.2) < 0.05 and absf(float(sw[1]) - 30.6) < 0.05 and absf(float(sc0[0]) - 28.0) < 0.05 and absf(float(sc0[1]) - 34.0) < 0.05,
			"the Mud set's trade: his Splash flies %.1f m/s and his Lash %.1f (28, 34 not worn)" % [float(sw[0]), float(sw[1])])
	_wear(foe, mud)
	await _face_off(10.0)
	BendEffects.apply(fc, "wave", "slam", SwayMoves.move("wave").bend.slam)
	var bz: Variant = BendEffects.last_of(fc).get("puddle")
	_expect(bz is BendZone and is_instance_valid(bz) and (bz as BendZone).kind == "mud" and (bz as BendZone).owner_node == foe,
			"the Mud set on a bot: its Downpour leaves its own mud")
	_wear(foe, [])
	await _end_pools()


# ---------------------------------------------------------------- Mud Lash
func _mud_lash() -> void:
	var ml := ["water.set.mud", "water.mud.lash"]
	_wear(player, ml)
	await _face_off(10.0)
	var b := _cast(player, "water_whip", "whip")
	var v := b.velocity.length() if b != null else -1.0
	await _secs(1.0)
	var w: Dictionary = await _steam_of(player, foe)
	var pw: float = await _pct_of_cast(player, foe, "water_whip", "whip")
	_wear(player, ["water.set.mud"])
	var c: Dictionary = await _steam_of(player, foe)
	var pc0: float = await _pct_of_cast(player, foe, "water_whip", "whip")
	_wear(player, [])
	_expect(absf(v - 28.0) < 0.05, "Mud Lash: the Lash flies %.1f m/s (the set's heavier water included)" % v)
	_expect(w.is_empty() and not c.is_empty(), "Mud Lash: fire it meets is smothered, no steam (with the set alone, steam: %s)" % [c])
	_expect(pc0 > 0.0 and absf(pw / pc0 - 10.0 / 9.0) < 0.01, "Mud Lash: it adds %.2f%% for the %.2f (10 for 9)" % [pw, pc0])
	_wear(player, ml)
	var lw: float = await _wave_launch(player, foe, "water_whip/whip", 5.3, 10.0)
	_wear(player, ["water.set.mud"])
	var lc: float = await _wave_launch(player, foe, "water_whip/whip", 4.6, 9.0)
	_wear(player, [])
	_expect(lw > lc, "Mud Lash: it knocks harder, base 5.3 for 4.6 (launch %.2f m/s for %.2f)" % [lw, lc])
	_wear(foe, ml)
	var b2: Dictionary = await _steam_of(foe, player)
	_wear(foe, [])
	_expect(b2.is_empty(), "Mud Lash on a bot: the fire its Lash meets is smothered too")


# ---------------------------------------------------------------- Mudslide
func _mudslide() -> void:
	var ms := ["water.set.mud", "water.mud.mudslide"]
	_wear(player, ms)
	await _face_off(8.0)
	_wave_from = player.global_position
	var before := _zones("mud")
	_cast(player, "wave", "push")
	await _ticks(3)
	var pool := _new_zone("mud", before, player)
	var d := Vector2(pool.global_position.x - _wave_from.x, pool.global_position.z - _wave_from.z).length() if pool != null else -1.0
	var pool_r := pool.radius if pool != null else -1.0
	var pool_life := pool.life_s if pool != null else -1.0
	var reach := float((BendEffects.last_of(pc).get("spec", {}) as Dictionary).get("range_m", -1.0))
	await _secs(0.8)
	var lw: float = await _wave_launch(player, foe, "wave/push", 8.6)
	var lgw: float = await _wave_launch(player, foe, "wave/push.grown", 9.7)
	# (the grown Wave: its reach 10 m from 12, the grow merged as a held lock grows it: BendCaster.grown)
	await _face_off(8.0)
	pc.grown = true
	_cast(player, "wave", "push")
	pc.grown = false
	var greach := float((BendEffects.last_of(pc).get("spec", {}) as Dictionary).get("range_m", -1.0))
	var grew := bool(BendEffects.last_of(pc).get("grown", false))
	await _secs(0.8)
	_wear(player, ["water.set.mud"])
	await _face_off(8.0)
	var before0 := _zones("mud")
	_cast(player, "wave", "push")
	await _ticks(3)
	var pool0_made := _new_zone("mud", before0, player) != null
	var reach0 := float((BendEffects.last_of(pc).get("spec", {}) as Dictionary).get("range_m", -1.0))
	await _secs(0.8)
	var lc: float = await _wave_launch(player, foe, "wave/push", 7.5)
	var lgc: float = await _wave_launch(player, foe, "wave/push.grown", 8.4)
	await _face_off(8.0)
	pc.grown = true
	_cast(player, "wave", "push")
	pc.grown = false
	var greach0 := float((BendEffects.last_of(pc).get("spec", {}) as Dictionary).get("range_m", -1.0))
	await _secs(0.8)
	_wear(player, [])
	_expect(_near(pool_r, 2.0) and _near(pool_life, 8.0) and d <= 7.5 + 0.3 and d >= 7.5 - 2.0 and _near(reach, 7.5),
			"Mudslide: the Wave reaches %.1f m (9 not worn) and leaves a 2 m mud pool of his where it ends, %.1f m on" % [reach, d])
	_expect(not pool0_made and _near(reach0, 9.0), "Mudslide not worn (the set alone): the Wave reaches %.1f m and leaves no pool" % reach0)
	_expect(lw > lc and lgw > lgc, "Mudslide: it knocks 15%% harder, base 8.6 for 7.5 (launch %.2f m/s for %.2f; grown %.2f for %.2f)" % [lw, lc, lgw, lgc])
	_expect(grew and _near(greach, 10.0) and _near(greach0, 12.0), "Mudslide grown: the Wave reaches %.1f m (12 not worn: %.1f)" % [greach, greach0])
	_wear(foe, ms)
	await _face_off(8.0)
	var bb := _zones("mud")
	_cast(foe, "wave", "push")
	await _ticks(3)
	var bp := _new_zone("mud", bb, foe)
	_wear(foe, [])
	_expect(bp != null, "Mudslide on a bot: its Wave leaves its own mud pool")
	await _end_pools()


# ---------------------------------------------------------------- stacking
## Water's picks worn together as the tree's stacking says (same_answer_gate.stacking): same way from the same base, the ratios
## multiply; a set twist's number final; opposite pulls refused.
func _stacking() -> void:
	_gas_on(false)
	var sp := BendLoadout.overlay_for(["water.lash.splashdown", "water.lash.steamcraft"], "water")
	var wd: Variant = ((sp["class"] as Dictionary).get("water_whip/whip", {}) as Dictionary).get("d")
	_expect((sp.ids as Array).size() == 2 and _near(wd, 9.0 * 8.0 / 9.0 * 8.0 / 9.0),
			"stacking: Splashdown and Steamcraft worn together both pay their Lash trade, 9 x 8/9 x 8/9 = %.2f%% (%s)" % [float(wd if wd != null else -1.0), sp.refused])
	for order: Array in [["water.set.mud", "water.mud.lash"], ["water.mud.lash", "water.set.mud"]]:
		var ml := BendLoadout.overlay_for(order, "water")
		var mps: Variant = ((ml.spec as Dictionary).get("water_whip/whip", {}) as Dictionary).get("mps")
		_expect((ml.ids as Array).size() == 2 and _near(mps, 28.0), "stacking: Mud Lash's 28 m/s is final over the set's 30.6 (%s first: %s)" % [order[0], str(mps)])
	var dm := BendLoadout.overlay_for(["water.wave.drench", "water.set.mud", "water.mud.mudslide"], "water")
	_expect((dm.ids as Array).has("water.wave.drench") and not (dm.ids as Array).has("water.mud.mudslide")
			and (dm.refused as Dictionary).has("water.mud.mudslide"),
			"stacking: Drench (base 6.5) and Mudslide (8.6) pull the Wave's base 7.5 opposite ways: the later one is refused (%s)" % [dm.refused])
	var tm := BendLoadout.overlay_for(["water.wall.thick_ice", "water.set.mud", "water.mud.mire"], "water")
	var rise: Variant = (tm.ice as Dictionary).get("rise_s")
	_expect((tm.ids as Array).size() == 3 and _near(rise, 0.8) and int((((tm.ice as Dictionary).get("materials", {}) as Dictionary).get("snow", {}) as Dictionary).get("hits", 0)) == 4,
			"stacking: Thick Ice beside Mire: the Ice Wall rises in %s s (Mire's, a set twist's, final), takes Thick Ice's 4 hits" % str(rise))


# ---------------------------------------------------------------- Mud Mound
## The mounds of `by`'s standing now.
func _mounds(by: Node) -> Array:
	var out: Array = []
	for n in get_nodes_in_group(FormRaised.GROUP):
		var w := n as FormRaised
		if w != null and int(w.get_meta(BendEffects.MOUND_META, 0)) == by.get_instance_id() \
				and w.state != FormRaised.State.CRUMBLING and not w.is_queued_for_deletion():
			out.append(w)
	return out


func _mud_mound() -> void:
	var mm := ["water.set.mud", "water.mud.mound"]
	_wear(player, mm)
	await _face_off(8.0)
	BendEffects.apply(pc, "wave", "spout", SwayMoves.move("wave").bend.spout)
	var at: Vector3 = BendEffects.last_of(pc).get("spout_at", Vector3.INF)
	await _secs(0.8)
	var ms := _mounds(player)
	var m: FormRaised = ms[0] if not ms.is_empty() else null
	var ok := m != null and m.matter == "mud" and _near(m.size.x, 1.5) and _near(m.size.y, 0.7) and _near(m.life_s, 3.0) \
			and not m.has_meta(&"wall_n") and Vector2(m.global_position.x - at.x, m.global_position.z - at.z).length() < 1.0
	_expect(ok, "Mud Mound: the wearer's Geyser leaves a low mud mound 1.5 m across, 0.7 m high, for 3 s where it rose, never one of his walls (%s)"
			% ["%s %.1f x %.1f, %.1f s" % [m.matter, m.size.x, m.size.y, m.life_s] if m != null else "none"])
	_expect(m != null and not m.has_meta(&"bend_by") and not FormEffects.own(pc, m),
			"Mud Mound: nobody's raised wall (no bend_by: Mend never targets it, a bot's own wall, Brace and the lessons never count it)")
	# floor fire stops at it: the foe's Kick at the player with the mound between them
	if m != null:
		player.global_position = m.global_position + (m.global_position - foe.global_position).normalized() * 3.0
		player.velocity = Vector3.ZERO
		foe.look_at(Vector3(player.global_position.x, foe.global_position.y, player.global_position.z), Vector3.UP)
		RingRules.current().reset_pct(player, 0.0)
		await _ticks(2)
		BendEffects.apply(fc, "fire_kick", "kick", SwayMoves.move("fire_kick").bend.kick)
		await _secs(0.8)
	var kick_pct := RingRules.current().pct_of(player)
	RingRules.current().reset_pct(player, 0.0)
	_expect(m != null and is_zero_approx(kick_pct), "Mud Mound: a Kick's floor fire stops at the mound (+%.1f%%)" % kick_pct)
	# anyone can jump onto it: the foe stood on its top stays there
	if m != null and is_instance_valid(m):
		foe.global_position = m.global_position + Vector3.UP * 1.0
		foe.velocity = Vector3.ZERO
		await _secs(0.5)
	var on_top := m != null and is_instance_valid(m) and foe.global_position.y - m.global_position.y > 0.5
	_expect(on_top, "Mud Mound: a body set on it stands on its top (%.2f m up)" % [foe.global_position.y - (m.global_position.y if m != null and is_instance_valid(m) else 0.0)])
	await _secs(2.5)
	_expect(_mounds(player).is_empty(), "Mud Mound: gone after its 3 s")
	# two of his at once (one face-off: it clears the deck)
	await _face_off(8.0)
	var foe0 := foe.global_position
	for i in 3:
		foe.global_position = foe0 + Vector3(float(i) * 2.5 - 2.5, 0.0, 0.0)
		foe.velocity = Vector3.ZERO
		await _ticks(4)
		BendEffects.apply(pc, "wave", "spout", SwayMoves.move("wave").bend.spout)
		await _secs(0.5)
	_expect(_mounds(player).size() == 2, "Mud Mound: two of his at once (%d)" % _mounds(player).size())
	var lw: float = await _wave_launch(player, foe, "wave/spout", 9.3)
	_wear(player, ["water.set.mud"])
	var lc: float = await _wave_launch(player, foe, "wave/spout", 10.9)
	await _secs(3.0)
	await _face_off(8.0)
	BendEffects.apply(pc, "wave", "spout", SwayMoves.move("wave").bend.spout)
	await _secs(0.8)
	var none := _mounds(player).size()
	_wear(player, [])
	_expect(lw < lc, "Mud Mound's trade: the Geyser launches %.2f m/s for the %.2f (base 9.3 for 10.9)" % [lw, lc])
	_expect(none == 0, "Mud Mound not worn (the set alone): the Geyser leaves no mound (%d)" % none)
	await _secs(3.0)
	_wear(foe, mm)
	await _face_off(8.0)
	BendEffects.apply(fc, "wave", "spout", SwayMoves.move("wave").bend.spout)
	await _secs(0.8)
	_expect(_mounds(foe).size() == 1, "Mud Mound on a bot: its Geyser leaves its own mound")
	_wear(foe, [])
	await _secs(3.0)


# ---------------------------------------------------------------- Delta
## The player's Lash lock (key 1, the aim held on the foe) from its start to its click (s), standing where he is.
func _lash_lock_s() -> float:
	var sc := SwayCaster.of(player)
	for i in 120:
		if sc.state == SwayCaster.State.IDLE and not sc._cast_wait() and player.is_on_floor():
			break
		await physics_frame
	sc._wait_release = false
	player.hotbar.select(0)
	await _ticks(3)
	sc.held_override = true
	var n := 0
	var began := false
	for i in 120:
		await physics_frame
		if sc.state != SwayCaster.State.IDLE:
			began = true
		if began:
			n += 1
		if sc.state == SwayCaster.State.FULL:
			break
	sc.held_override = false
	await _ticks(2)
	sc.held_override = null
	await _secs(0.8)
	return float(n) / Engine.physics_ticks_per_second


func _delta() -> void:
	var dl := ["water.set.mud", "water.mud.delta"]
	_wear(player, dl)
	await _face_off(10.0)
	var pool := _pool_at(player, player.global_position, 2.0)
	await _ticks(2)
	var life := pool.life_s
	var pf := SwayCaster.of(player).passive_fill()
	var t_mud: float = await _lash_lock_s()
	pool.end("test")
	var theirs := BendZone.make(foe, "mud", FormEffects.ground_at(player, player.global_position), {"radius_m": 2.0, "life_s": 8.0})
	await _ticks(2)
	var pf_theirs := SwayCaster.of(player).passive_fill()
	theirs.end("test")
	await _ticks(2)
	var t_dry: float = await _lash_lock_s()
	_wear(player, ["water.set.mud"])
	await _face_off(10.0)
	var pool0 := _pool_at(player, player.global_position, 2.0)
	await _ticks(2)
	var pf0 := SwayCaster.of(player).passive_fill()
	var life0 := pool0.life_s
	await _end_pools()
	_wear(player, [])
	_expect(_near(life, 6.5) and _near(life0, 8.0), "Delta's trade: his mud pools last %.1f s (8 with the set alone)" % life)
	_expect(_near(pf, 1.15) and _near(pf_theirs, 1.0) and _near(pf0, 1.0), "Delta: in his own mud his locks fill x%.2f; in another's x%.2f; not worn x%.2f" % [pf, pf_theirs, pf0])
	_expect(t_dry > 0.0 and absf(t_mud / t_dry - 1.0 / 1.15) < 0.06, "Delta: his Lash's real lock fills in %.3f s standing in his mud, %.3f s out of it" % [t_mud, t_dry])
	_wear(foe, dl)
	await _face_off(10.0)
	var bp := _pool_at(foe, foe.global_position, 2.0)
	for i in ceili(1.0 * Engine.physics_ticks_per_second):
		if foe.is_on_floor():
			break
		await physics_frame
	var bf := BendZone.home_fill(foe)
	bp.end("test")
	await _ticks(2)
	var bf0 := BendZone.home_fill(foe)
	_wear(foe, [])
	_expect(_near(bf, 1.15) and _near(bf0, 1.0), "Delta on a bot: its lock fills x%.2f in its own mud, x%.2f out of it (NpcBending.tick)" % [bf, bf0])


# ---------------------------------------------------------------- Mire
## The player's real key 4 tapped twice (Hotbar.select twice: the double tap, Bending.other_move), then the aim held to the click
## and let go (SwayCaster's own lock and cast; the crosshair on the foe 10 m off): {mode (what the double tap readied), lock (s),
## mud (the mud pool of his it made, read at once: radius, life, along (m from him toward the foe), pool, mire), wall (an Ice Wall
## of his rose)}.
func _mire_by_keys() -> Dictionary:
	await _face_off(10.0)
	var sc := SwayCaster.of(player)
	for i in 180:
		if sc.state == SwayCaster.State.IDLE and not sc._cast_wait() and player.is_on_floor():
			break
		await physics_frame
	sc._wait_release = false
	player.hotbar.select(3)
	player.hotbar.select(3)                          # (the same key again within double_tap_s: its other move)
	await _ticks(3)
	var out := {"mode": sc.base_mode_of("water_shield") if sc.readied_spell == "water_shield" else "", "lock": -1.0, "mud": {}, "wall": false}
	var before := _zones("mud")
	var w0 := _newest_wall(player)
	var from := player.global_position
	var way := foe.global_position - from
	way.y = 0.0
	way = way.normalized()
	sc.held_override = true
	for i in 240:
		await physics_frame
		if sc.state != SwayCaster.State.IDLE and float(out.lock) < 0.0:
			out.lock = sc.lock_s
		if sc.state == SwayCaster.State.FULL:
			break
	sc.held_override = false
	await _ticks(3)
	sc.held_override = null
	var z := _new_zone("mud", before, player)
	if z != null:
		out.mud = {"radius": z.radius, "life": z.life_s, "along": (z.global_position - from).dot(way), "pool": z.is_in_group(Bending.POOLS),
				"mire": z.has_meta(BendZone.MIRE_META)}
	var w := _newest_wall(player)
	out.wall = w != null and w != w0
	if w != null and w != w0:
		w.crumble("test")
	await _secs(0.8)
	return out


func _flat(a: Node3D, b: Node3D) -> float:
	return Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()


## The wearer's Mire cast as the game casts it (BendEffects.apply of his new mode's spec), aimed at the foe: the pool it made.
func _mire_now(by: Node3D) -> BendZone:
	var before := _zones("mud")
	BendEffects.apply(BendCaster.of(by), "water_shield", "mire", BendLoadout.new_spec(by, "water_shield", "mire"))
	return _new_zone("mud", before, by)


func _mire() -> void:
	var mi := ["water.set.mud", "water.mud.mire"]
	_wear(player, mi)
	var hud := KitWords.key_moves("water", 3, player)
	var w: Dictionary = await _mire_by_keys()
	_wear(player, ["water.set.mud"])
	var hud0 := KitWords.key_moves("water", 3, player)
	var set_refused := not SwayCaster.of(player).set_mode("water_shield", "mire")
	var c: Dictionary = await _mire_by_keys()
	_wear(player, [])
	var m: Dictionary = w.mud
	_expect(String(w.mode) == "mire" and not m.is_empty() and _near(m.get("radius"), 3.0) and _near(m.get("life"), 8.0)
			and absf(float(m.get("along", -1.0)) - 6.0) < 0.6 and bool(m.get("pool", false)) and bool(m.get("mire", false)),
			"Mire: 4 tapped twice readies it; its lock let go lays a 3 m mud pool of his for 8 s where he aims (%.1f m on, 2-6), a source (%s)"
			% [float(m.get("along", -1.0)), w])
	_expect(String(c.mode) == "ice_wall" and (c.mud as Dictionary).is_empty() and bool(c.wall) and set_refused,
			"Mire not worn (the set alone): 4 tapped twice is the Ice Wall, no mud (%s); the mode cannot be set" % [c])
	_expect(float(c.lock) > 0.0 and absf(float(w.lock) / float(c.lock) - 0.9 / 0.85) < 0.01,
			"Mire's lock %.3f s for the Ice Wall's %.3f (0.9 for 0.85)" % [float(w.lock), float(c.lock)])
	_expect(hud.size() == 2 and String(hud[1].mode) == "mire" and KitWords.move_name("water_shield", "mire") == "Mire" and hud0.size() == 1,
			"Mire: the strip and the wheel show 4's tap twice as Mire for the wearer (%s), nothing for another (%s)" % [hud, hud0])
	# the Ice Wall's pose for it, the wearer's alone
	_wear(player, mi)
	var clip := String(BendPoses.pick("water_shield", "mire", "water", player).get("clip", ""))
	var iw := String(BendPoses.pick("water_shield", "ice_wall", "water", player).get("clip", ""))
	_wear(player, ["water.set.mud"])
	var clip0 := String(BendPoses.pick("water_shield", "mire", "water", player).get("clip", ""))
	_expect(clip != "" and clip == iw and clip0 == "", "Mire is cast with the Ice Wall's pose (%s); not worn there is no such cast (%s)" % [clip, clip0])
	# one at a time; his other mud pools stay and the Mire is not one of the set's four
	_wear(player, mi)
	await _face_off(10.0)
	for i in 4:
		_pool_at(player, home + Vector3(float(i) * 1.5 - 2.0, 0.0, -3.0), 1.0)
	var first := _mire_now(player)
	await _ticks(2)
	var first_up := first != null and is_instance_valid(first) and not first.is_queued_for_deletion()
	var second := _mire_now(player)
	await _ticks(2)
	var n_mire := 0
	var n_mud := 0
	for z: BendZone in _zones("mud").values():
		if z.owner_node == player:
			n_mud += 1
			n_mire += 1 if z.has_meta(BendZone.MIRE_META) else 0
	var first_gone := first == null or not is_instance_valid(first) or first.is_queued_for_deletion()
	_expect(first_up and second != null and first_gone and n_mire == 1 and n_mud == 5,
			"Mire: one at a time (a second dries the first: %s), his four other mud pools stay beside it (%d of his)" % [first_gone, n_mud])
	await _end_pools()
	# floor fire dies in it: the foe's Kick at him across his Mire
	await _face_off(10.0)
	RingRules.current().reset_pct(player, 0.0)
	_mire_now(player)
	await _ticks(2)
	BendEffects.apply(fc, "fire_kick", "kick", SwayMoves.move("fire_kick").bend.kick)
	await _secs(1.0)
	var kick_w := RingRules.current().pct_of(player)
	RingRules.current().reset_pct(player, 0.0)
	await _end_pools()
	await _face_off(10.0)
	BendEffects.apply(fc, "fire_kick", "kick", SwayMoves.move("fire_kick").bend.kick)
	await _secs(1.0)
	var kick_c := RingRules.current().pct_of(player)
	RingRules.current().reset_pct(player, 0.0)
	_expect(is_zero_approx(kick_w) and kick_c > 0.0, "Mire: a Kick's floor fire dies in it (+%.1f%%); with none it hits (+%.1f%%)" % [kick_w, kick_c])
	# his water: the Geyser's source there (the grates out of the pools meanwhile)
	await _face_off(10.0)
	var grates: Array = get_nodes_in_group(Bending.POOLS).filter(func(n: Node) -> bool: return not (n is BendZone))
	for g: Node in grates:
		g.remove_from_group(Bending.POOLS)
	var mz := _mire_now(player)
	var made := mz != null
	await _ticks(2)
	if mz != null:
		foe.global_position = Vector3(mz.global_position.x, foe.global_position.y, mz.global_position.z)
		foe.velocity = Vector3.ZERO
	await _ticks(3)
	BendEffects.apply(pc, "wave", "spout", SwayMoves.move("wave").bend.spout)
	var src := bool(BendEffects.last_of(pc).get("source", false))
	if mz != null and is_instance_valid(mz):
		mz.end("test")
	await _secs(0.5)
	BendEffects.apply(pc, "wave", "spout", SwayMoves.move("wave").bend.spout)
	var src0 := bool(BendEffects.last_of(pc).get("source", false))
	for g: Node in grates:
		g.add_to_group(Bending.POOLS)
	_expect(made and src and not src0, "Mire: his Geyser's source (over it %s, without it %s)" % [src, src0])
	await _secs(1.0)
	# the trade: his Ice Wall rises in 0.8 s; with Delta his Mire lasts 6.5 s
	await _face_off(10.0)
	BendEffects.apply(pc, "water_shield", "ice_wall", SwayMoves.move("water_shield").bend.ice_wall)
	var iwall := _newest_wall(player)
	var rise := iwall.rise_s if iwall != null else -1.0
	if iwall != null:
		iwall.crumble("test")
	_wear(player, ["water.set.mud", "water.mud.delta", "water.mud.mire"])
	var dz := _mire_now(player)
	var dlife := dz.life_s if dz != null else -1.0
	_wear(player, [])
	await _end_pools()
	_expect(_near(rise, 0.8) and _near(dlife, 6.5), "Mire's trade: his Ice Wall rises in %.2f s (0.7); with Delta his Mire lasts %.1f s" % [rise, dlife])
	await _secs(1.0)
	# a bot wearing it: its lock (lock_for), its own Mire toward its foe, and it lays one against a foe whose kit has floor fire only
	var nb: NpcBending = foe.brain.bending if foe.brain != null else null
	_wear(foe, mi)
	var bl := NpcBending.lock_for("water_shield", "mire", "normal", 0.0, foe)
	var bl0 := NpcBending.lock_for("water_shield", "ice_wall", "normal", 0.0, foe)
	await _face_off(10.0)
	var bz: BendZone = null
	var b_along := -1.0
	if nb != null:
		var before := _zones("mud")
		var bfrom := foe.global_position
		nb.begin("water_shield", "mire")
		nb._release()
		bz = _new_zone("mud", before, foe)
		if bz != null:
			var bway := player.global_position - bfrom
			bway.y = 0.0
			b_along = (bz.global_position - bfrom).dot(bway.normalized())
	_expect(absf(bl / maxf(bl0, 0.001) - 0.9 / 0.85) < 0.01 and bz != null and bz.has_meta(BendZone.MIRE_META) and b_along >= 1.9 and b_along <= 6.1,
			"Mire on a bot: its lock x%.3f the Ice Wall's, its own Mire %.1f m on toward its foe" % [bl / maxf(bl0, 0.001), b_along])
	await _end_pools()
	var picks: Array = []                            # [vs a fire foe, vs a water foe, not worn vs fire]
	var loose: Array = [0, false]                    # [its Mires let loose on a fire foe, one of its lay there]
	if nb != null:
		var keep_el := [nb.element, foe.get(&"element"), Bending.of(foe).element, Bending.of(player).element]
		nb.element = "water"
		foe.set(&"element", "water")
		Bending.of(foe).element = "water"
		var seen_was: bool = foe.brain.seen_now
		for run: Array in [[mi, "fire"], [mi, "water"], [[], "fire"]]:
			_wear(foe, run[0] as Array)
			nb._build_options()
			Bending.of(player).element = String(run[1])
			await _face_off(8.0)
			var n := 0
			for i in 300:
				nb._cool.clear()
				foe.brain.seen_now = true
				var pk := nb._choose(player, 8.0)
				n += 1 if String(pk.get("key", "")) == "water_shield/mire" else 0
			picks.append(n)
		# its own play, let loose on him (a fire foe) for up to 20 s: it lays a Mire of its own (his % kept at 0 meanwhile)
		_wear(foe, mi)
		nb._build_options()
		Bending.of(player).element = "fire"
		await _face_off(9.0)
		var n0 := int(nb.casts_by.get("water_shield/mire", 0))
		var all0 := nb.casts_by.duplicate()
		var before_l := _zones("mud")
		foe.held = false
		for i in ceili(20.0 * Engine.physics_ticks_per_second):
			await physics_frame
			RingRules.current().reset_pct(player, 0.0)
			if int(nb.casts_by.get("water_shield/mire", 0)) > n0:
				break
		foe.held = true
		var laid := _new_zone("mud", before_l, foe)
		var others := {}
		for k: String in nb.casts_by:
			if int(nb.casts_by[k]) > int(all0.get(k, 0)):
				others[k] = int(nb.casts_by[k]) - int(all0.get(k, 0))
		loose = [int(nb.casts_by.get("water_shield/mire", 0)) - n0, laid != null and laid.has_meta(BendZone.MIRE_META), others,
				"brain %d mind %d seen %s d %.1f" % [foe.brain.state, nb.mind().state, foe.brain.seen_now, _flat(foe, player)]]
		nb._cancel()
		await _secs(0.5)
		foe.brain.seen_now = seen_was
		nb.element = String(keep_el[0])
		foe.set(&"element", keep_el[1])
		Bending.of(foe).element = String(keep_el[2])
		Bending.of(player).element = String(keep_el[3])
		_wear(foe, [])
		nb._build_options()
	_expect(picks.size() == 3 and int(picks[0]) > 0 and int(picks[1]) == 0 and int(picks[2]) == 0,
			"Mire on a bot: it lays one against a foe with floor fire (%s of 300 picks), never against a water foe or unworn" % [picks])
	_expect(int(loose[0]) >= 1 and bool(loose[1]), "Mire on a bot let loose on a fire foe: its own play lays one (%s)" % [loose])
	await _end_pools()
	await _face_off(10.0)
