extends SceneTree
## BendCast.cast, the one way in for any caster (the owner, 2026-10-04: the ring's bots cast the same moves as the player), the
## old modes cast by the duel's earthbender held still (his mind off) and wrapped in a BodyBendCaster aimed at the player, on a
## flat slab of earth raised 200 m over the duel's ground (no terrain, no cover, nothing in the way), after the countdown:
##   earth_wall  wall: one more FormRaised, between them, marked his (bend_by); last_of(his caster) {do "old", made}
##   stone_form  spike and cannonball (boulder): a Throw of his flies at the player and strikes him (not himself: his hit
##               parts left out), knocking him (BendKnock: last_knocker the bot) at least 0.6 m along its flight within
##               0.8 s, against no move at all without it
##   pillar      self: a pillar under the bot's feet; free: one at the aim's ground (near the player)
##   gust        push and pull: the player knocked away from / toward the bot (last_knocker the bot); lift on the player:
##               thrown up (launched); lift on a placed stone (a liftable rigid stone): a GustLift of his tears it free and
##               hurls it at the player within 2 s (it comes 3 m nearer him or strikes him)
##   mend        his own wall worn by a shot: packed again (no wood: a bot pays none); a wall the player raised, worn: not his,
##               left worn
##   shove       Earth Shove push (a bend spec, BendEffects) with no stone on his line (round 2's order, spec §2.6: the held
##               stone, else the crosshair's, else one kicked up and pushed at the kick-up's strike): a Throw of his (not a
##               stone bolt), that strikes or nears the player
##   the player  his earth wall and stone form through BendCast too (PlayerBendCaster), BendEffects.last his
##   water       a wall raised across the edge of a deck over water (a tank's floor 3.4 m down, a water node over it, as the
##               ring's) is cut to the deck (narrower, both ends over the deck); one raised wholly over the water is not raised
##               (drowned, in no group); FormRaised.floor_under over the water is the tank's floor, not the terrain under it
## Last line "BEND CAST PASSED" or "BEND CAST FAILED"; exit 0 only on a pass. User args: seed=<n> (1750).
##   Godot --headless --fixed-fps 60 --path . -s tests/bending/test_bend_cast.gd -- mode=duel

const WATCHDOG_S := 330.0
const SLAB_Y := 200.0
## The deck's half size (m), the tank floor's depth under it (the ring's water_y and floor_y).
const DECK_HALF := 30.0
const WATER_DY := -1.4
const FLOOR_DY := -3.4

var fails := 0
var p: FrontierPlayer
var c: SwayCaster
var duel: DuelMode
var n: NpcFighter
var bc: BodyBendCaster
var mid := Vector3.ZERO
var water: Water
var opts := {"seed": 1750}


## The tank's water over its floor round the deck (as RingWater.is_under_water): in the group "water".
class Water extends Node3D:
	var mid := Vector3.ZERO

	func is_under_water(pos: Vector3) -> bool:
		var l := pos - mid
		if l.y >= WATER_DY or l.y < FLOOR_DY - 0.5:
			return false
		return absf(l.x) > DECK_HALF or absf(l.z) > DECK_HALF


func _expect(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	MatchSetup._aim_help = "strong"             # (this test's player does not aim his camera: the full help, as before the 2026-10-05 setting)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):
			opts.seed = int(a.substr(5))
	seed(int(opts.seed))
	create_timer(WATCHDOG_S, true, false, true).timeout.connect(func() -> void:
		print("BEND CAST FAILED (watchdog)")
		quit(2))
	DuelMode.incoming = true
	change_scene_to_file("res://scenes/main.tscn")
	_go.call_deferred()


func _secs(s: float) -> void:
	for i in int(s * Engine.physics_ticks_per_second):
		await physics_frame


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## A slab of `half` m each way, its top `top` m over mid, meta form_matter earth (the ring's deck's).
func _slab(nm: String, half: float, top: float) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.name = nm
	sb.collision_layer = 1
	sb.collision_mask = 0
	sb.set_meta(&"form_matter", "earth")
	sb.set_meta(&"surface", "stone")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(half * 2.0, 1.0, half * 2.0)
	cs.shape = box
	sb.add_child(cs)
	current_scene.add_child(sb)
	sb.global_position = Vector3(mid.x, mid.y + top - 0.5, mid.z)
	return sb


func _clear() -> void:
	for g: StringName in [BendBolt.GROUP, BendZone.GROUP, FormRaised.GROUP, FormStone.GROUP, GustLift.GROUP, FormEffects.Throw.GROUP]:
		for x in get_nodes_in_group(g):
			if is_instance_valid(x):
				x.queue_free()


## The player `d` m before the bot (the bot at mid, the player at -x facing +x), both still, whole, unknocked; the bot held.
func _stage(d := 9.0) -> void:
	_clear()
	await physics_frame
	p.global_position = mid + Vector3(-d, 0.05, 0.0)
	p.velocity = Vector3.ZERO
	p.yaw = -PI / 2.0
	p.rotation.y = p.yaw
	p.pitch = 0.0
	p.health = p.max_health
	n.held = true
	n.global_position = mid + Vector3(0.0, 0.05, 0.0)
	n.velocity = Vector3.ZERO
	n.rotation.y = PI / 2.0
	n.health = n.health_max
	n.action = ""
	n.arm_broken = ""
	n.limp = 1.0
	n.pool = 0.0
	n.mortal_left = 0.0
	for b: Node in [p, n]:
		var k := BendKnock.peek(b)
		if k != null:
			k.reset()
			k.last_knocker = null
		for m: StringName in [&"bend_anchor", &"bend_root", &"bend_slow"]:
			if b.has_meta(m):
				b.remove_meta(m)
	n.feet_held = false
	await _secs(0.4)


func _go() -> void:
	for i in 20:
		await process_frame
	p = current_scene.get_node_or_null("Player") as FrontierPlayer
	duel = DuelMode.find(self)
	c = SwayCaster.of(p) if p != null else null
	_expect(p != null and duel != null and c != null, "the duel, its player and his caster")
	if c == null:
		return _end()
	p.ignore_mouse_capture = true
	await _secs(Hotbar.KIT_S + DuelMode.COUNTDOWN_S + 1.0)
	n = duel.npc
	_expect(n != null and is_instance_valid(n), "the bot")
	if n == null:
		return _end()
	n.held = true
	# (the duel's watch off: no round ends and no reset of the two while the casts land; neither killed, only winded)
	duel.set_physics_process(false)
	p.no_death = true
	n.no_death = true
	mid = n.global_position
	mid.y = SLAB_Y
	_slab("CastDeck", DECK_HALF, 0.0)
	_slab("CastTankFloor", DECK_HALF + 20.0, FLOOR_DY)
	BendKnock.ragdoll_mps = 50.0                            # (as the ring: a lift throws him up, not off his feet)
	bc = BodyBendCaster.new(n, p, 0.0, 0.0)
	bc.side = 1.0
	bc.bind()
	_expect(BendCaster.of(n) == bc, "the bot's caster bound (BendCaster.of)")
	await _wall()
	await _stone("spike")
	await _stone("cannonball")
	await _pillar()
	await _gust_people()
	await _gust_stone()
	await _mend()
	await _shove()
	await _player()
	await _water()
	_end()


func _end() -> void:
	print("BEND CAST " + ("PASSED" if fails == 0 else "FAILED"))
	quit(0 if fails == 0 else 1)


## Nodes of `g` made since snapshot `before`.
func _new_in(g: StringName, before: Array) -> Array:
	var out: Array = []
	for x in get_nodes_in_group(g):
		if not before.has(x):
			out.append(x)
	return out


# ---------------------------------------------------------------- earth wall
func _wall() -> void:
	await _stage()
	var before := get_nodes_in_group(FormRaised.GROUP)
	var ok := BendCast.cast(bc, "earth_wall", "wall")
	var made := _new_in(FormRaised.GROUP, before)
	var rec := BendEffects.last_of(bc)
	var w: FormRaised = made[0] if made.size() == 1 else null
	var between := w != null and w.base.origin.x < n.global_position.x and w.base.origin.x > p.global_position.x
	_expect(ok and made.size() == 1 and w.kind == "wall" and between and FormEffects.own(bc, w) and String(rec.get("do", "")) == "old"
			and rec.get("made") == w, "earth wall: one more wall, between them, his (bend_by), recorded (%d, %s; x %s between %.1f and %.1f; his %s)"
			% [made.size(), str(rec.get("do", "-")), str(w.base.origin.x - mid.x) if w else "-", p.global_position.x - mid.x,
			n.global_position.x - mid.x, str(FormEffects.own(bc, w))])


# ---------------------------------------------------------------- stone form
func _stone(mode: String) -> void:
	await _stage()
	var ths0 := get_nodes_in_group(FormEffects.Throw.GROUP)
	var p0 := p.global_position
	var ok := BendCast.cast(bc, "stone_form", mode)
	var ths := _new_in(FormEffects.Throw.GROUP, ths0)
	var th: FormEffects.Throw = ths[0] if ths.size() == 1 else null
	_expect(ok and th != null and th.caster == bc, "stone form %s: a Throw of the bot's (%d)" % [mode, ths.size()])
	if th == null:
		return
	var struck: Array = []
	th.lift.struck.connect(func(who: Node, _d: float) -> void: struck.append(who))
	var dir := Vector3.ZERO
	var hit_at := -1.0
	var t := 0.0
	while t < 2.0 and (hit_at < 0.0 or t - hit_at < 0.8):
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		if is_instance_valid(th) and th.lift != null and is_instance_valid(th.lift) and th.lift.velocity.length_squared() > 1.0:
			dir = Vector3(th.lift.velocity.x, 0.0, th.lift.velocity.z).normalized()
		if hit_at < 0.0 and struck.has(p):
			hit_at = t
			p0 = p.global_position
	var k := BendKnock.peek(p)
	var along := (p.global_position - p0).dot(dir)
	_expect(struck.has(p) and not struck.has(n), "stone form %s: it strikes the player, never the bot (%s)" % [mode, str(struck)])
	_expect(k != null and k.last_knocker == n and along >= 0.6, "stone form %s: the player knocked %.2f m along its flight in 0.8 s, by the bot (%s)"
			% [mode, along, str(k.last_knocker if k else null)])


# ---------------------------------------------------------------- pillar
func _pillar() -> void:
	await _stage()
	var before := get_nodes_in_group(FormRaised.GROUP)
	var ok := BendCast.cast(bc, "pillar", "self")
	var made := _new_in(FormRaised.GROUP, before)
	var r: FormRaised = made[0] if made.size() == 1 else null
	_expect(ok and r != null and r.kind == "pillar" and _flat(r.base.origin, n.global_position) < 0.6,
			"pillar self: a pillar under the bot's feet (%s)" % (str(_flat(r.base.origin, n.global_position)) if r else "none"))
	await _stage()
	before = get_nodes_in_group(FormRaised.GROUP)
	ok = BendCast.cast(bc, "pillar", "free")
	made = _new_in(FormRaised.GROUP, before)
	r = made[0] if made.size() == 1 else null
	_expect(ok and r != null and r.kind == "pillar" and _flat(r.base.origin, p.global_position) < 1.5,
			"pillar free: a pillar at the aim's ground, by the player (%s m off)" % (str(_flat(r.base.origin, p.global_position)) if r else "none"))


# ---------------------------------------------------------------- gust
func _gust_people() -> void:
	for mode: String in ["push", "pull"]:
		await _stage()
		var p0 := p.global_position
		var ok := BendCast.cast(bc, "gust", mode)
		await _secs(1.2)
		var k := BendKnock.peek(p)
		var dx := p.global_position.x - p0.x                 # (the bot is at +x: a push sends him -x, a pull +x)
		var right := dx < -0.5 if mode == "push" else dx > 0.5
		_expect(ok and right and k != null and k.last_knocker == n, "gust %s: the player knocked %+.2f m along x, by the bot" % [mode, dx])
	await _stage()
	var ok := BendCast.cast(bc, "gust", "lift")
	var k := BendKnock.peek(p)
	var up := k != null and k.is_launched()
	await _secs(0.3)
	_expect(ok and up and p.global_position.y > SLAB_Y + 0.3, "gust lift on the player: thrown up (%.2f m)" % (p.global_position.y - SLAB_Y))
	await _secs(1.5)


func _gust_stone() -> void:
	await _stage()
	var s := RigidBody3D.new()
	s.name = "TestStone"
	s.mass = 20.0
	s.set_meta(&"sway_stone", true)
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.25
	cs.shape = sp
	s.add_child(cs)
	current_scene.add_child(s)
	s.global_position = n.global_position + Vector3(-1.5, 0.3, 1.0)
	await _secs(0.4)
	_expect(GustLift.is_stone(s) and GustLift.liftable(s), "a liftable stone laid by the bot")
	var lifts0 := get_nodes_in_group(GustLift.GROUP)
	var d0 := s.global_position.distance_to(p.global_position)
	var ok := BendCast.cast(bc, "gust", "lift", s)
	var lifts := _new_in(GustLift.GROUP, lifts0)
	var l: GustLift = lifts[0] if lifts.size() == 1 else null
	_expect(ok and l != null and l.caster == bc and l.stone == s, "gust lift on the stone: a GustLift of the bot's on it")
	if l == null:
		s.queue_free()
		return
	var struck: Array = []
	l.struck.connect(func(who: Node, _d: float) -> void: struck.append(who))
	var held_up := false
	var best := d0
	var t := 0.0
	while t < 2.6:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		if t < 1.0 and is_instance_valid(l) and l.phase == GustLift.Phase.HELD and s.global_position.y > SLAB_Y + 0.8:
			held_up = true
		if is_instance_valid(s):
			best = minf(best, s.global_position.distance_to(p.global_position))
	_expect(held_up and (d0 - best >= 3.0 or struck.has(p)), "the stone torn free, held up, hurled at the player (%.1f m nearer, struck %s)"
			% [d0 - best, str(struck.has(p))])
	if is_instance_valid(s):
		s.queue_free()


# ---------------------------------------------------------------- mend
func _mend() -> void:
	await _stage()
	BendCast.cast(bc, "earth_wall", "wall")
	var w := BendEffects.last_of(bc).get("made") as FormRaised
	await _secs(1.0)
	if w == null or not w.is_up():
		_expect(false, "mend: the bot's wall stands (%s)" % str(w))
		return
	w.apply_hit(w.hit_min + 1.0, w.global_position + Vector3.UP, Vector3.LEFT)
	_expect(w.worn(), "mend: the bot's wall worn by a shot (%d hits)" % w.hits)
	var ok := BendCast.cast(bc, "mend", "")
	_expect(ok and w.hits == 0 and String(BendEffects.last_of(bc).get("move", "")) == "mend", "mend: the bot packs its own wall again, no wood (%d hits)" % w.hits)
	# a wall the player raised: not the bot's
	var pw := FormEffects.earth_wall(c, p.global_position + Vector3(2.0, 0.0, 4.0), SwayMoves.move("earth_wall"), "earth")
	await _secs(1.0)
	if pw == null or not pw.is_up():
		_expect(false, "mend: the player's wall stands")
		return
	pw.apply_hit(pw.hit_min + 1.0, pw.global_position + Vector3.UP, Vector3.LEFT)
	var ok2 := BendCast.cast(bc, "mend", "", pw)
	_expect(not ok2 and pw.hits == 1, "mend: the player's worn wall is not the bot's to mend (%d hits)" % pw.hits)


# ---------------------------------------------------------------- shove
func _shove() -> void:
	await _stage()
	var ths0 := get_nodes_in_group(FormEffects.Throw.GROUP)
	var bolts0 := get_nodes_in_group(BendBolt.GROUP)
	var ok := BendCast.cast(bc, "earth_shove", "push")
	var rec := BendEffects.last_of(bc)
	var st: FormStone = rec.get("stone") as FormStone
	_expect(String(rec.get("how", "")) == "kick_up" and st != null, "Earth Shove with no stone on his line kicks one up (%s)" % rec.get("how"))
	var d0 := st.global_position.distance_to(p.global_position) if st != null else 0.0
	await _secs(0.45)                         # (pushed at the kick-up's strike: kick_s)
	var ths := _new_in(FormEffects.Throw.GROUP, ths0)
	var th: FormEffects.Throw = ths[0] if ths.size() == 1 else null
	_expect(ok and th != null and th.caster == bc and th.stone == st and _new_in(BendBolt.GROUP, bolts0).is_empty(),
			"Earth Shove (the bot's): the stone thrown by a Throw of his, no stone bolt (%d throws)" % ths.size())
	var struck: Array = []
	if th != null:
		th.lift.struck.connect(func(who: Node, _d: float) -> void: struck.append(who))
	var best := d0
	for i in int(1.5 * Engine.physics_ticks_per_second):
		await physics_frame
		if is_instance_valid(st):
			best = minf(best, st.global_position.distance_to(p.global_position))
	_expect(struck.has(p) or d0 - best >= 3.0, "and it flies at the player (%.1f m nearer, struck %s)" % [d0 - best, str(struck.has(p))])


# ---------------------------------------------------------------- the player
func _player() -> void:
	await _stage()
	BendStatus.anchor(n, 100.0)
	var before := get_nodes_in_group(FormRaised.GROUP)
	var last0 := BendEffects.last
	var ok := BendCast.cast(c, "earth_wall", "wall")
	var made := _new_in(FormRaised.GROUP, before)
	_expect(ok and made.size() == 1 and BendEffects.last != last0 and BendEffects.last.get("made") == made[0] and FormEffects.own(BendCaster.of(p), made[0]),
			"the player's earth wall through BendCast: one wall, his, BendEffects.last his")
	await _stage()
	BendStatus.anchor(n, 100.0)
	var ths0 := get_nodes_in_group(FormEffects.Throw.GROUP)
	ok = BendCast.cast(c, "stone_form", "spike")
	var ths := _new_in(FormEffects.Throw.GROUP, ths0)
	_expect(ok and ths.size() == 1 and (ths[0] as FormEffects.Throw).caster is PlayerBendCaster and (ths[0] as FormEffects.Throw).cam_off != Vector3.INF,
			"the player's stone form through BendCast: his Throw, from his aim camera's view")
	await _secs(1.2)
	n.remove_meta(&"bend_anchor")


# ---------------------------------------------------------------- water
func _water() -> void:
	await _stage()
	water = Water.new()
	water.name = "CastWater"
	water.mid = mid
	water.add_to_group(TorchState.WATER_GROUP)
	current_scene.add_child(water)
	# the bot by the deck's +x edge, looking along it (+z): a wall across his line crosses the edge
	n.global_position = mid + Vector3(DECK_HALF - 1.0, 0.05, -3.0)
	bc.target = null
	n.rotation.y = PI                                       # (facing +z)
	await _secs(0.3)
	var before := get_nodes_in_group(FormRaised.GROUP)
	var at := mid + Vector3(DECK_HALF - 0.6, 0.0, 0.0)
	BendCast.cast(bc, "earth_wall", "wall", null, at)
	var made := _new_in(FormRaised.GROUP, before)
	var w: FormRaised = made[0] if made.size() == 1 else null
	var edge := mid.x + DECK_HALF
	var ok := false
	var ends := Vector2.ZERO
	if w != null:
		var a := w.base * Vector3(-w.size.x * 0.5, 0.0, 0.0)
		var b := w.base * Vector3(w.size.x * 0.5, 0.0, 0.0)
		ends = Vector2(a.x, b.x)
		ok = w.size.x < w.asked_w - 0.3 and maxf(a.x, b.x) <= edge + 0.15 and absf(w.base.origin.y - SLAB_Y) < 0.1
	_expect(ok, "a wall across the deck's edge cut to the deck (%s m of %s; its ends at x %s, the edge %.2f)"
			% [str(w.size.x) if w else "-", str(w.asked_w) if w else "-", str(ends - Vector2(mid.x, mid.x)), DECK_HALF])
	# wholly over the water: not raised
	var drowned0 := get_nodes_in_group(FormRaised.GROUP)
	var dok := BendCast.cast(bc, "earth_wall", "wall", null, mid + Vector3(DECK_HALF + 4.0, 0.0, 2.0))
	var rec := BendEffects.last_of(bc)
	var dw := rec.get("made") as FormRaised
	_expect(not dok and _new_in(FormRaised.GROUP, drowned0).is_empty() and dw != null and dw.drowned,
			"a wall wholly over the water: not raised (drowned, in no group)")
	await _secs(0.2)
	_expect(not is_instance_valid(dw), "and gone the next step")
	var off := mid + Vector3(DECK_HALF + 3.0, 1.0, 0.0)
	var on := mid + Vector3(DECK_HALF - 3.0, 1.0, 0.0)
	var fy := FormRaised.floor_under(current_scene, off)
	var fy_on := FormRaised.floor_under(current_scene, on)
	_expect(absf(fy - (SLAB_Y + FLOOR_DY)) < 0.1 and absf(fy_on - SLAB_Y) < 0.1,
			"rubble falling over the water drops into it, onto its bed (%.2f, the bed %.2f; on the deck %.2f), not the terrain"
			% [fy - SLAB_Y, FLOOR_DY, fy_on - SLAB_Y])
	water.queue_free()
	bc.target = p
