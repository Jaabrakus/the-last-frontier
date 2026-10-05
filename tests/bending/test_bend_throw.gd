extends SceneTree
## Throw-style bending moves (BendThrow, BendBolt's flights, BendLooks' disc and spear) and what the bots now do about what
## flies and what hides (NpcBending's opening grace and its catch answered with a shove; clouds, steam and the flare's
## dazzle against a bot), in the duel's level on a flat slab SLAB_Y over the arena, the duel's own watch off:
##   the strike    the player's Stone disc on a synthetic clip (hold_s 0.2, strike_s 0.3): no bolt at the release, the disc
##                 0.08..0.16 s after it (the one deferral, SwayCaster's, not two: BendThrow launches at once)
##   the flights   a disc spins (its body's basis turns frame to frame); a disc thrown with gravity 6 at a point 20 m off lands
##                 within 1 m of it (the arc that lands it: Weapon.ballistic_dir); an ice spear's point (-Z) keeps within 5
##                 degrees of its flight; pebbles are three bolts; a body's cast (BodyBendCaster) launches the same frame
##   the meeting   the player's Catch takes a thrown stone disc (a stone held); the player's air shield sends back an ice
##                 spear (its caster now the player)
##   the bots      a hard earth bot catches at least one of the discs thrown at it and shoves the caught stone back (Earth
##                 Shove push); a hard air bot let go begins no attack before its grace_s and knocks no one in the first
##                 second
##   sight         the player's smoke between them: a hard fire bot sends no bolt while it hangs; water and fire meeting leave
##                 a steam cloud that hides him from a bot, gone in 2 s; the player's flare dazzles a bot (its aim wider)
## Last line "BEND THROW PASSED" or "BEND THROW FAILED"; exit 0 only on a pass; the watchdog (LIMIT_S) under the runner's
## GODOT_TIMEOUT.
##   Godot --headless --fixed-fps 60 --path . -s tests/bending/test_bend_throw.gd -- mode=duel

const NAME := "BEND THROW"
const LIMIT_S := 380.0
const SLAB_Y := 200.0
const SLAB := Vector2(70.0, 30.0)
const FACTION := "ring_team_b"
const DISCS := 6


## A caster that aims at a fixed point (no target): the landing and the spear's flight.
class FixedAim:
	extends BodyBendCaster
	var point := Vector3.ZERO

	func aim_point(_ex: Array = [], _from := Vector3.INF) -> Vector3:
		return point

	func aim_target() -> Node3D:
		return null

	func has_target() -> bool:
		return false


var fails := 0
var p: FrontierPlayer
var c: SwayCaster
var duel: DuelMode
var n: NpcFighter
var mid := Vector3.ZERO
var _seed := 1750
var _anchor := true


func _expect(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	MatchSetup._aim_help = "strong"             # (this test's player does not aim his camera: the full help, as before the 2026-10-05 setting)
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print(NAME + " FAILED (watchdog)")
		quit(2))
	DuelMode.incoming = true
	change_scene_to_file("res://scenes/main.tscn")
	_go.call_deferred()


func _end() -> void:
	BendPoses.override = {}
	BendPoses.extra_library = null
	if c != null and is_instance_valid(c):
		c.held_override = null
	print(NAME + (" PASSED" if fails == 0 else " FAILED"))
	quit(0 if fails == 0 else 1)


## The player kept whole where he stands (anchored unless a section watches his knocks).
func _keep() -> void:
	if p == null or not is_instance_valid(p):
		return
	p.health = p.max_health
	p.drag_speed_cap = 0.0
	if _anchor:
		BendStatus.anchor(p, 0.5)


func _secs(s: float, each: Callable = Callable()) -> void:
	for i in int(s * Engine.physics_ticks_per_second):
		_keep()
		if each.is_valid():
			each.call()
		await physics_frame


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _go() -> void:
	for i in 20:
		await process_frame
	p = current_scene.get_node_or_null("Player") as FrontierPlayer
	duel = DuelMode.find(self)
	c = SwayCaster.of(p) if p != null else null
	_expect(p != null and duel != null and c != null and c.pose != null, "the duel, its player, his caster and pose")
	if c == null or c.pose == null:
		return _end()
	p.ignore_mouse_capture = true
	p.no_death = true
	await _secs(Hotbar.KIT_S + DuelMode.COUNTDOWN_S + 1.0)
	n = duel.npc
	_expect(n != null and is_instance_valid(n), "the duel's bot")
	if n == null:
		return _end()
	n.held = true
	n.no_death = true
	duel.set_physics_process(false)          # (the duel's watch off: no round ends meanwhile)
	BendKnock.ragdoll_mps = 50.0
	mid = duel.arena.center()
	mid.y = SLAB_Y
	_slab()
	await _strike()
	await _flights()
	await _meetings()
	await _bots()
	await _sight()
	_end()


# ---------------------------------------------------------------- the stage
func _slab() -> void:
	var sb := StaticBody3D.new()
	sb.name = "ThrowSlab"
	sb.collision_layer = 1
	sb.collision_mask = 0
	sb.set_meta(&"form_matter", "earth")
	sb.set_meta(&"surface", "stone")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(SLAB.x, 1.0, SLAB.y)
	cs.shape = box
	sb.add_child(cs)
	current_scene.add_child(sb)
	sb.global_position = Vector3(mid.x, SLAB_Y - 0.5, mid.z)


func _clear() -> void:
	for g: StringName in [BendBolt.GROUP, BendZone.GROUP, FormRaised.GROUP, FormStone.GROUP, GustLift.GROUP, FormEffects.Throw.GROUP]:
		for x in get_nodes_in_group(g):
			if is_instance_valid(x):
				x.queue_free()


## The player at mid - gap/2 facing +x, the duel's bot at mid + gap/2 facing him, both still, whole and unknocked; the bot
## held.
func _stage(gap := 9.0) -> void:
	_clear()
	await physics_frame
	p.global_position = mid + Vector3(-gap * 0.5, 0.05, 0.0)
	p.velocity = Vector3.ZERO
	p.yaw = -PI / 2.0
	p.rotation.y = p.yaw
	p.pitch = 0.0
	p.health = p.max_health
	n.held = true
	n.global_position = mid + Vector3(gap * 0.5, 0.05, 0.0)
	n.velocity = Vector3.ZERO
	n.rotation.y = PI / 2.0
	n.health = n.health_max
	n.action = ""
	for b: Node in [p, n]:
		var k := BendKnock.peek(b)
		if k != null:
			k.reset()
			k.last_knocker = null
	Bending.of(p).water = 100.0
	Bending.of(n).water = 100.0
	await _secs(0.4)


func _ready_spell(id: String, mode: String) -> bool:
	var hb := p.hotbar
	if hb != null and hb.slot_of(Hotbar.SPELL, id) < 0:
		hb.assign(Hotbar.SLOTS - 1, Hotbar.make(Hotbar.SPELL, id))
	var ok := c.ready_spell(id)
	c.set_mode(id, mode)
	return ok and c.readied_spell == id and c.mode_of(id) == mode


## The camera's aim on `pt`.
func _aim(pt: Vector3) -> void:
	var d := pt - p.camera.global_position
	p.yaw = atan2(-d.x, -d.z)
	p.rotation.y = p.yaw
	p.pitch = atan2(d.y, Vector2(d.x, d.z).length())


func _bolts_of(by: Node) -> Array:
	var out: Array = []
	for x in get_nodes_in_group(BendBolt.GROUP):
		if is_instance_valid(x) and (x as BendBolt).caster == by and not (x as BendBolt).spent:
			out.append(x)
	return out


func _spec(id: String, mode: String) -> Dictionary:
	return ((SwayMoves.move(id).get("bend", {}) as Dictionary).get(mode, {}) as Dictionary).duplicate(true)


# ---------------------------------------------------------------- the strike
func _strike() -> void:
	var a := Animation.new()
	a.length = 0.6
	a.set_meta(&"hold_s", 0.2)
	a.set_meta(&"strike_s", 0.3)
	a.set_meta(&"back_s", 0.4)
	a.set_meta(&"hand", "r_palm")
	a.set_meta(&"authored", "tests/bending/test_bend_throw.gd: a synthetic clip with no tracks")
	var lib := AnimationLibrary.new()
	lib.add_animation(&"own-test-throw", a)
	BendPoses.extra_library = lib
	BendPoses.override = {"moves": {"stone_form": {"modes": {"disc": "own-test-throw"}}}}
	DuelMode.element = "earth"
	await _stage(14.0)
	var ok := _ready_spell("stone_form", "disc")
	c.held_override = true
	var t := 0.0
	while t < 3.0 and c.state != SwayCaster.State.FULL:
		_aim(NpcSenses.chest_of(n))
		_keep()
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	await _secs(0.1)
	var wait := c.pose.strike_wait()
	var rec := {"cast_f": -1, "at_cast": 0}
	c.cast.connect(func(_m: String, _t: Node3D) -> void:
		rec.cast_f = Engine.get_physics_frames()
		rec.at_cast = _bolts_of(p).size(), CONNECT_ONE_SHOT)
	c.held_override = false
	var first: BendBolt = null
	t = 0.0
	while t < 1.0 and first == null:
		_keep()
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		var bs := _bolts_of(p)
		if not bs.is_empty():
			first = bs[0]
	var dt := float(Engine.get_physics_frames() - int(rec.cast_f)) / Engine.physics_ticks_per_second if first != null else INF
	_expect(ok and absf(wait - 0.1) < 0.02 and int(rec.cast_f) >= 0 and int(rec.at_cast) == 0 and dt >= 0.08 and dt <= 0.16,
			"the player's Stone disc on a strike clip (wait %.3f s): no bolt at the release (%d), the disc %.3f s after it (one deferral, not two)"
			% [wait, int(rec.at_cast), dt])
	_expect(first != null and first.flight == "spinning" and first.shape == "disc" and first.kind == "stone" and first.spin != null,
			"it flies as a thrown disc (%s, %s, %s)" % [first.flight if first else "-", first.shape if first else "-", first.kind if first else "-"])
	BendPoses.override = {}
	BendPoses.extra_library = null
	c.held_override = null
	await _secs(0.6)


# ---------------------------------------------------------------- the flights
func _flights() -> void:
	await _stage(20.0)
	n.global_position = mid + Vector3(0.0, 0.05, -12.0)        # (the bot out of the line: the player throws)
	await _secs(0.2)
	# --- a disc with gravity 6 at a point 20 m off (a man's knees, 0.6 m over the deck) comes down on it, spinning: its arc
	# passes within half a metre of the point, and it comes down on the deck a few metres on (its arc is shallow)
	var fa := FixedAim.new(p, null, 0.0, 0.0)
	var target := mid + Vector3(10.0, 0.6, 0.0)
	fa.point = target
	var spec := _spec("stone_form", "disc")
	spec["gravity"] = 6.0
	var b := BendThrow.throw(fa, BendEffects.aim(fa, spec), spec)
	var end_at := [Vector3.INF, ""]
	var turned := [0, 0]
	var near := [INF, Vector3.INF]
	var made := b != null
	if made:
		b.ended.connect(func(why: String) -> void:
			end_at[0] = b.global_position
			end_at[1] = why)
	var prev := b.spin.global_basis if made and b.spin != null else Basis.IDENTITY
	var last := b.global_position if made else Vector3.INF
	var t := 0.0
	while t < 3.0 and is_instance_valid(b) and not b.spent:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		if is_instance_valid(b) and b.spin != null and not b.spent:
			var now := b.spin.global_basis
			turned[1] += 1
			if not now.is_equal_approx(prev):
				turned[0] += 1
			prev = now
		if is_instance_valid(b):
			var q := Geometry3D.get_closest_point_to_segment(target, last, b.global_position)
			if q.distance_to(target) < float(near[0]):
				near[0] = q.distance_to(target)
				near[1] = q
			last = b.global_position
	var land: Vector3 = end_at[0]
	_expect(made and float(near[0]) <= 0.5 and land.is_finite() and land.y < SLAB_Y + 0.8 and _flat(land, target) <= 4.0,
			"a disc thrown with gravity 6 at a point 20 m off comes down on it: its arc %.2f m from the point, down %.2f m on (%s, %.2f m up)"
			% [near[0], _flat(land, target) if land.is_finite() else INF, end_at[1], land.y - SLAB_Y if land.is_finite() else INF])
	_expect(turned[1] > 10 and turned[0] >= turned[1] - 1, "the disc's body turns frame to frame (%d of %d frames)" % [turned[0], turned[1]])
	# --- an ice spear keeps its point along its flight
	var fs := FixedAim.new(p, null, 0.0, 0.0)
	fs.point = mid + Vector3(22.0, 1.3, 0.0)
	var ss := _spec("ice", "spear")
	var sp := BendThrow.throw(fs, BendEffects.aim(fs, ss), ss)
	var sp_ok := sp != null and sp.shape == "spear" and sp.flight == "point_first"
	var worst := 0.0
	var frames := 0
	t = 0.0
	while t < 2.0 and is_instance_valid(sp) and not sp.spent:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		if is_instance_valid(sp) and not sp.spent and sp.velocity.length() > 1.0:
			frames += 1
			worst = maxf(worst, rad_to_deg((-sp.global_basis.z).angle_to(sp.velocity)))
	_expect(sp_ok and frames > 5 and worst <= 5.0,
			"an ice spear's point keeps to its flight (worst %.2f deg over %d frames)" % [worst, frames])
	# --- pebbles: three bolts; a body's cast launches at once
	await _stage(9.0)
	var bc := BodyBendCaster.new(n, p, 0.0, 0.0)
	bc.bind()
	var before := _bolts_of(n).size()
	var cast_ok := BendCast.cast(bc, "stone_form", "disc", p)
	var at_once := _bolts_of(n).size() - before
	_expect(cast_ok and at_once == 1, "a body's Stone disc (BodyBendCaster) launches the same frame (%d bolt)" % at_once)
	await _secs(0.8)
	var seen := {}
	var old := {}
	for x in _bolts_of(n):
		old[x.get_instance_id()] = true
	BendCast.cast(bc, "rock_jab", "pebbles", p)
	await _secs(0.3, func() -> void:
		for x in _bolts_of(n):
			if not old.has(x.get_instance_id()):
				seen[x.get_instance_id()] = (x as BendBolt).flight)
	var flicks := 0
	for k in seen:
		flicks += 1 if String(seen[k]) == "flick" else 0
	_expect(seen.size() == 3 and flicks == 3, "pebbles: three flicked stones (%d bolts, %d flicked)" % [seen.size(), flicks])
	await _secs(0.6)


# ---------------------------------------------------------------- what meets them
func _held_by(who: Node) -> FormStone:
	for st in get_nodes_in_group(FormStone.GROUP):
		if is_instance_valid(st) and int((st as Node).get_meta(&"bend_held_by", -1)) == who.get_instance_id():
			return st as FormStone
	return null


func _meetings() -> void:
	# --- the player's Catch takes a thrown disc
	await _stage(9.0)
	var bc := BodyBendCaster.new(n, p, 0.0, 0.0)
	bc.bind()
	c.set_mode("stone_catch", "catch")
	var caught := BendCast.cast(c, "stone_catch", "catch")
	await physics_frame
	BendCast.cast(bc, "stone_form", "disc", p)
	var got: FormStone = null
	var t := 0.0
	while t < 1.5 and got == null:
		_keep()
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		got = _held_by(p)
	_expect(caught and got != null, "the player's Catch takes a thrown stone disc (held %s, %.2f s)" % [got != null, t])
	# --- the player's air shield sends back an ice spear
	await _stage(12.0)
	DuelMode.element = "air"
	c.set_mode("air_shield", "shield")
	var shielded := BendCast.cast(c, "air_shield", "shield")
	await physics_frame
	var zone: BendZone = null
	for z in get_nodes_in_group(BendZone.GROUP):
		if (z as BendZone).kind == "air_shield" and (z as BendZone).owner_node == p:
			zone = z
	BendCast.cast(bc, "ice", "spear", p)
	var spear: BendBolt = null
	for x in _bolts_of(n):
		spear = x
	var back := false
	t = 0.0
	while t < 1.2 and spear != null and is_instance_valid(spear) and not back:
		_keep()
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		back = is_instance_valid(spear) and spear.caster == p
	_expect(shielded and zone != null and spear != null and back and zone.took >= 1,
			"the player's air shield sends an ice spear back (its caster now the player: %s; took %d)" % [back, zone.took if zone else -1])
	DuelMode.element = "earth"
	await _secs(0.8)


# ---------------------------------------------------------------- the bots
## A bot of `el` and `preset` at `at`, facing the player, its mind on him, its deck's callables set.
func _bot(el: String, at: Vector3, preset := "hard") -> NpcFighter:
	_seed += 1
	var sq := NpcSquad.spawn(current_scene, FACTION, 1, at, {"element": el, "tactics": "bend", "weapon": "", "sidearm": "",
			"skill": preset, "seed": _seed, "y": SLAB_Y, "face": p.global_position})
	var f: NpcFighter = sq.members[0] if not sq.members.is_empty() else null
	if f == null:
		return null
	f.no_death = true
	f.flees = false
	f.calm_s = INF
	var b := f.brain.bending
	if b != null:
		b.bounds_fn = _bound
		b.edge_fn = _edge_m
	f.brain.told(p, p.global_position)
	return f


func _free_bot(f: NpcFighter) -> void:
	if f != null and is_instance_valid(f) and f.squad != null and is_instance_valid(f.squad):
		f.squad.get_parent().remove_child(f.squad)
		f.squad.queue_free()


func _edge_m(pos: Vector3, dir: Vector3) -> float:
	var hx := SLAB.x * 0.5
	var hz := SLAB.y * 0.5
	var lx := pos.x - mid.x
	var lz := pos.z - mid.z
	var t := INF
	if absf(dir.x) > 1e-5:
		t = minf(t, ((hx if dir.x > 0.0 else -hx) - lx) / dir.x)
	if absf(dir.z) > 1e-5:
		t = minf(t, ((hz if dir.z > 0.0 else -hz) - lz) / dir.z)
	return maxf(t, 0.0)


func _bound(pos: Vector3) -> Vector3:
	var hx := SLAB.x * 0.5 - 1.0
	var hz := SLAB.y * 0.5 - 1.0
	return Vector3(clampf(pos.x, mid.x - hx, mid.x + hx), pos.y, clampf(pos.z, mid.z - hz, mid.z + hz))


func _bots() -> void:
	await _stage(9.0)
	n.global_position = mid + Vector3(0.0, 0.05, SLAB.y * 0.5 - 2.0)        # (the duel's bot out of the way)
	p.global_position = mid + Vector3(-8.0, 0.05, 0.0)
	await _catch_back()
	await _grace()


## Discs thrown at a hard earth bot 16 m off: it catches one or more, and a caught stone is shoved back.
func _catch_back() -> void:
	var f := _bot("earth", mid + Vector3(8.0, 0.0, 0.0))
	if f == null:
		_expect(false, "an earth bot")
		return
	var b := f.brain.bending
	await _secs(2.5)
	var pbc := BodyBendCaster.new(p, f, 0.0, 0.0)
	var shoves_after := 0
	for i in DISCS:
		for w in get_nodes_in_group(FormRaised.GROUP):
			w.queue_free()                     # (a wall it raised would hide him: the catch is what is looked at)
		f.global_position = p.global_position + Vector3(16.0, 0.05, 0.0)
		f.velocity = Vector3.ZERO
		await _secs(0.5)
		var c0 := b.catches
		var s0 := int(b.casts_by.get("earth_shove/push", 0))
		_aim(NpcSenses.chest_of(f))
		BendCast.cast(pbc, "stone_form", "disc", f)
		await _secs(2.0)
		if b.catches > c0 and int(b.casts_by.get("earth_shove/push", 0)) > s0:
			shoves_after += 1
	print("  earth bot: %d catches of %d discs, %d shoved back (reactions %s, casts %s)" % [b.catches, DISCS, shoves_after, b.reactions_by, b.casts_by])
	_expect(b.catches >= 1, "a hard earth bot catches a thrown disc (%d of %d)" % [b.catches, DISCS])
	_expect(shoves_after >= 1, "and shoves the caught stone back (Earth Shove push within 2 s: %d)" % shoves_after)
	_free_bot(f)
	await _secs(0.3)


## A hard air bot 8 m off let go: no attack begun before its grace, no knock on the player in the first second.
func _grace() -> void:
	_clear()
	var f := _bot("air", p.global_position + Vector3(8.0, 0.0, 0.0))
	if f == null:
		_expect(false, "an air bot")
		return
	f.held = true
	await _secs(0.6)
	var b := f.brain.bending
	var grace := float(b.preset().get("grace_s", 0.0))
	_anchor = false
	var k := BendKnock.peek(p)
	var k0 := k.knocks if k != null else 0
	var h0 := p.health
	f.held = false
	var first := [INF]
	var knocked_1s := [false]
	var t := [0.0]
	await _secs(3.0, func() -> void:
		t[0] += 1.0 / Engine.physics_ticks_per_second
		if b.casting != "" and first[0] == INF:
			var role := String((b._option(b.casting + "/" + b.mode).get("hint", {}) as Dictionary).get("role", ""))
			if role in ["offence", "control"]:
				first[0] = t[0]
		if t[0] <= 1.0:
			var kk := BendKnock.peek(p)
			if (kk != null and kk.knocks > k0) or p.health < h0:
				knocked_1s[0] = true)
	_anchor = true
	print("  air bot (hard, grace %.1f s): first attack begun %.2f s after it was let go; casts %s" % [grace, first[0], b.casts_by])
	_expect(grace >= 1.0 and first[0] >= grace - 1.0 / 30.0, "a hard air bot begins no attack in its opening grace (%.2f s >= %.2f s)" % [first[0], grace])
	_expect(not knocked_1s[0], "nor knocks the player in the first second")
	_free_bot(f)
	await _secs(0.3)


# ---------------------------------------------------------------- sight
func _sight() -> void:
	await _stage(9.0)
	n.global_position = mid + Vector3(0.0, 0.05, SLAB.y * 0.5 - 2.0)
	p.global_position = mid + Vector3(-8.0, 0.05, 0.0)
	await _smoke()
	await _steam()
	await _dazzle()


## The player's smoke (Breath smoke) between him and a hard fire bot 10 m off: no bolt of its own while it hangs.
func _smoke() -> void:
	_clear()
	var f := _bot("fire", p.global_position + Vector3(10.0, 0.0, 0.0))
	if f == null:
		_expect(false, "a fire bot")
		return
	f.held = true
	await _secs(0.5)
	_aim(NpcSenses.chest_of(f))
	c.set_mode("fire_breath", "smoke")
	var made := BendCast.cast(c, "fire_breath", "smoke")
	await physics_frame
	var hid := NpcBendCaster.hidden(f, p)
	var b := f.brain.bending
	f.held = false
	var bolts := {}
	var hidden_frames := [0, 0]
	await _secs(4.0, func() -> void:
		hidden_frames[1] += 1
		if is_instance_valid(f) and NpcBendCaster.hidden(f, p):
			hidden_frames[0] += 1
		for x in _bolts_of(f):
			bolts[x.get_instance_id()] = true)
	print("  smoke: hidden %d of %d frames; the fire bot's casts %s" % [hidden_frames[0], hidden_frames[1], b.casts_by])
	_expect(made and hid and hidden_frames[0] >= hidden_frames[1] * 0.8 and bolts.is_empty(),
			"the player's smoke hides him from a fire bot: no bolt of its own while it hangs (%d)" % bolts.size())
	_free_bot(f)
	await _secs(1.5)


## Water and fire meeting: a steam cloud there that hides him from a bot behind it, gone within 2 s.
func _steam() -> void:
	_clear()
	var f := _bot("water", p.global_position + Vector3(10.0, 0.0, 0.0))
	if f == null:
		_expect(false, "a water bot")
		return
	f.held = true
	await _secs(0.3)
	var a := NpcSenses.chest_of(p)
	var e := NpcSenses.chest_of(f)
	var dir := (e - a).normalized()
	BendBolt.launch(p, a + dir * 0.8, dir, {"kind": "water", "mps": 20.0, "radius_m": 0.2, "range_m": 30.0, "damage": 0.0, "knock_mps": 0.0})
	BendBolt.launch(f, e - dir * 0.8, -dir, {"kind": "fire", "mps": 20.0, "radius_m": 0.2, "range_m": 30.0, "damage": 0.0, "knock_mps": 0.0})
	var steam: BendZone = null
	var t := 0.0
	while t < 1.0 and steam == null:
		_keep()
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		for z in get_nodes_in_group(BendZone.GROUP):
			if (z as BendZone).kind == "steam":
				steam = z
	var found := steam != null
	var hid := found and NpcBendCaster.hidden(f, p)
	await _secs(2.0)
	var gone := not found or not is_instance_valid(steam) or steam.is_queued_for_deletion()
	_expect(found and hid and gone, "water meeting fire leaves a steam cloud that hides him from a bot (%s, hidden %s), gone in 2 s (%s)"
			% [found, hid, gone])
	_free_bot(f)
	await _secs(0.3)


## The player's flare at a bot 3 m off: it is dazzled (its aim's scatter doubled).
func _dazzle() -> void:
	_clear()
	var f := _bot("earth", p.global_position + Vector3(3.0, 0.0, 0.0))
	if f == null:
		_expect(false, "a bot for the flare")
		return
	f.held = true
	await _secs(0.3)
	_aim(NpcSenses.chest_of(f))
	c.set_mode("fire_parry", "flare")
	var made := BendCast.cast(c, "fire_parry", "flare")
	await physics_frame
	var bc := f.brain.bending.caster
	var mult := bc._scatter_mult()
	_expect(made and NpcBendCaster.dazzled(f) and mult >= 2.0, "the player's flare dazzles a bot (dazzled %s, its scatter x%.1f)" % [NpcBendCaster.dazzled(f), mult])
	_free_bot(f)
