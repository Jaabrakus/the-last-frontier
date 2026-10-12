class_name BendCast
extends RefCounted
## The one way in for any caster (the owner, 2026-10-04: "1v1 first", the ring's bots casting the same moves as the player;
## docs/bending_design.md): cast(c, id, mode, t, at) casts move `id` in `mode` for caster `c` (a BendCaster, a SwayCaster, a
## body: BendCaster.wrap), the lock already done by whoever calls (the player's SwayCaster, a bot's NpcBending, a test).
##   a bend spec   the move's "bend" has the mode: BendEffects.apply (bolts, cones, zones, Earth Shove, Patch, ...)
##   the old modes the spells of before the elements, on any caster:
##     gust        push / pull on `t` (a fighter, the player, a beast, a prop, a raised wall: SwayEffects.gust, by the
##                 caster); lift on a fighter or the player throws him up; lift on a stone (GustLift.is_stone, liftable, one
##                 caster's weight) tears it free, holds it while it draws (gust.stone.hold: tear_s + draw_s) and hurls it at
##                 the caster's aim (Hurl: a bot's target, led and scattered by its skill as it lets go)
##     stone_form  spike / cannonball (the boulder): FormEffects.stone_form, the stone thrown at the caster's aim (Throw)
##     earth_wall  wall: FormEffects.earth_wall at `at` (INF: on the line to the aim, WALL_SHARE of the move's reach out)
##     pillar      self (under the caster) / free (at `at`, INF: the aim's ground within mode_range_m.free): FormEffects.pillar
##     mend        `t` (null: the player's aim on it; a bot's nearest raised earth of its own that is worn, within MEND_M):
##                 FormEffects.mend; the player pays his pack's wood, a bot mends only its own raised earth and pays nothing
## `t` null: the caster's aim_target(); `at` INF: from the caster's aim. Every cast is written as the caster's last
## (BendEffects.last_of; the old modes: {do "old", move, mode, made, ok}). True when it did something.

## The old modes BendCast casts itself (the moves' modes with no bend spec).
const OLD := {"gust": ["push", "pull", "lift"], "stone_form": ["spike", "cannonball"], "earth_wall": ["wall"],
		"pillar": ["self", "free"], "mend": [""]}
## A bot's own worn raised earth is mended within this (m).
const MEND_M := 8.0
## The earth wall goes up this share of the move's reach (range_m) toward the aim (half the way at most).
const WALL_SHARE := 0.6


## Caster `c` casts move `id` in `mode` ("" the caster's mode of it) at `t` and `at` (see the header). True when it did
## something.
static func cast(c: Variant, id: String, mode: String, t: Node3D = null, at := Vector3.INF) -> bool:
	var bc := BendCaster.wrap(c)
	if bc == null or not bc.valid():
		return false
	var d := SwayMoves.move(id)
	if d.is_empty():
		return false
	if mode == "":
		mode = bc.mode_of(id)
	var bd: Dictionary = d.get("bend", {})
	if bd.has(mode):
		BendEffects.apply(bc, id, mode, bd[mode], t, at)
		return not String(BendEffects.last_of(bc).get("do", "")) in ["", "dry"]
	if FireTalents.any(bc.body):
		var own := FireTalents.own_spec(bc.body, id, mode)      # (a worn new skill's own spec: Cauterize; none in moves.json)
		if not own.is_empty():
			BendEffects.apply(bc, id, mode, own, t, at)
			return not String(BendEffects.last_of(bc).get("do", "")) in ["", "dry"]
	var made: Object = null
	var keep := BendR3.cur
	# (round 3: the hit info a stone thrown now carries; ".grown" for a Spike or Boulder held on: stone_form.grow)
	var grew := bc.grown and (d.get("grow", {}) as Dictionary).get(mode) is Dictionary
	BendR3.cur = BendR3.info_for(bc, id, mode, grew)
	match id:
		"gust":
			made = _gust(bc, d, mode, t, at)
		"stone_form":
			made = FormEffects.stone_form(bc, at if at != Vector3.INF else bc.aim_point(), d, mode if mode == "cannonball" else "spike")
		"earth_wall":
			var reach := float(d.get("range_m", 3.2))
			if at == Vector3.INF and BendStatus.element_mode(bc.body):
				# (round 2: where the aim is, 2-6 m off, facing the caster: FormEffects.place_point; its ahead_m taken back)
				var pt := FormEffects.place_point(bc, d.get("place", (d.get("wall", {}) as Dictionary).get("place", {})))
				at = pt - FormEffects.way_to(bc, pt) * float((d.get("wall", {}) as Dictionary).get("ahead_m", 0.75))
				if BendR3.stock():
					at = BendR3.off_lip(bc.body.get_tree(), at, BendR3.num("wall_lip_clear_m", 3.5))
			made = FormEffects.earth_wall(bc, at if at != Vector3.INF else toward(bc, reach * WALL_SHARE, 0.5), d)
		"pillar":
			if mode == "free":
				var reach := float((d.get("mode_range_m", {}) as Dictionary).get("free", d.get("range_m", 10.0)))
				made = FormEffects.pillar(bc, at if at != Vector3.INF else toward(bc, reach), d, "free")
			else:
				made = FormEffects.pillar(bc, bc.body.global_position, d, "self")
		"mend":
			made = _mend(bc, d, t)
		_:
			BendR3.cur = keep
			return false
	BendR3.cur = keep
	var ok := made != null and is_instance_valid(made) and not (made is FormRaised and (made as FormRaised).drowned)
	BendEffects.record(bc, {"do": "old", "move": id, "mode": mode, "made": made, "ok": ok})
	return ok


## Whether move `id`'s `mode` is one BendCast casts itself (no bend spec for it).
static func is_old(id: String, mode: String) -> bool:
	if ((SwayMoves.move(id).get("bend", {}) as Dictionary)).has(mode):
		return false
	return OLD.has(id) and (mode in (OLD[id] as Array) or id == "mend")


## The ground on the caster's flat line to its aim, `reach` m out (no farther than `share` of the way to the aim point).
static func toward(bc: BendCaster, reach: float, share := 1.0) -> Vector3:
	var p := bc.body.global_position
	var aim := bc.aim_point()
	var flat := (aim - p) if aim != Vector3.INF else bc.facing() * reach
	flat.y = 0.0
	var dist := flat.length()
	if dist < 0.05:
		flat = bc.facing()
		dist = reach
	var go := minf(reach, dist * share) if share < 1.0 else minf(reach, dist)
	return FormEffects.ground_at(bc, p + flat.normalized() * maxf(go, 0.5))


# ---------------------------------------------------------------- gust
## Gust's old modes on `t` (null: the caster's aim target): see the header. What it acted on (a Hurl for a stone), null none.
static func _gust(bc: BendCaster, d: Dictionary, mode: String, t: Node3D, at: Vector3) -> Object:
	if t == null:
		t = bc.aim_target()
	if t == null or not is_instance_valid(t) or not t.is_inside_tree():
		bc.notice("Nothing there for the gust", 1.4)
		return null
	if mode == "lift" and GustLift.is_stone(t):
		var sd: Dictionary = d.get("stone", {})
		if not GustLift.liftable(t) or GustLift.casters_needed(t, sd) > 1:
			bc.notice("Too heavy to lift alone" if GustLift.liftable(t) else "Held already", 1.4)
			return null
		if t.global_position.distance_to(bc.chest()) > float(sd.get("range_m", 14.0)) * 1.4:
			return null
		return Hurl.start(bc, t, sd)
	SwayEffects.gust(bc, t, at, mode)
	return t


# ---------------------------------------------------------------- mend
## Mend `t` (null: see the header). What it mended, null nothing.
static func _mend(bc: BendCaster, d: Dictionary, t: Node3D) -> Object:
	if t == null:
		t = _mend_target(bc, d)
	if t == null:
		bc.notice("Nothing to mend there", 1.4)
		return null
	return t if FormEffects.mend(bc, t, d) != "" else null


static func _mend_target(bc: BendCaster, d: Dictionary) -> Node3D:
	var p := bc.body
	if not p is FrontierPlayer:
		# (a bot: its own raised earth, worn, the nearest)
		var best: Node3D = null
		var bd := MEND_M
		for w in p.get_tree().get_nodes_in_group(FormRaised.GROUP):
			var fr := w as FormRaised
			if fr == null or not fr.worn() or not FormEffects.own(bc, fr):
				continue
			var dd := fr.global_position.distance_to(p.global_position)
			if dd < bd:
				bd = dd
				best = fr
		return best
	# (the player: what his aim's ray meets within the move's reach, a piece of it that can be mended)
	var ray := bc.aim_ray()
	var from: Vector3 = ray[0]
	var dir: Vector3 = ray[1]
	if dir.length_squared() < 1e-6:
		return null
	var reach := float(d.get("range_m", 3.0)) + from.distance_to(bc.chest()) + 2.0
	var h := p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir.normalized() * reach, 0xFFFFFFFF, bc.exclude()))
	var n: Node = h.collider as Node if not h.is_empty() else null
	for i in 5:
		if n == null:
			break
		if n is Node3D and FormEffects.mend_stage(n) != "":
			return n as Node3D
		n = n.get_parent()
	return null


## A stone Gust holds and hurls for a caster with no hands on the aim (a bot, a test: BendCast's gust lift): GustLift's hold
## begun now (torn free, risen, drawn), its aim the caster's (aim_target's chest, else aim_point) followed live, and hurled at
## full draw (tear_s + draw_s) at the target led by his pace and scattered by the caster's skill (BendCaster.target_point),
## raised for its drop on the way. Dropped where it hangs when the caster is gone. Group GROUP while it holds.
class Hurl:
	extends Node

	const GROUP := &"bend_hurls"

	var caster: BendCaster
	var lift: GustLift
	var hold_s := 1.25
	var t := 0.0

	static func start(bc: BendCaster, s: Node3D, md: Dictionary) -> Hurl:
		var l := GustLift.begin(bc, s, md)
		if l == null:
			return null
		var h := Hurl.new()
		h.name = "BendHurl"
		h.caster = bc
		h.lift = l
		var hd: Dictionary = md.get("hold", {})
		h.hold_s = float(hd.get("tear_s", 0.35)) + maxf(float(hd.get("draw_s", 0.9)), 0.05)
		h.add_to_group(GROUP)
		bc.body.get_tree().current_scene.add_child(h)
		l.aim = h._aim(false)
		return h

	func _physics_process(dt: float) -> void:
		if lift == null or not is_instance_valid(lift) or lift.phase != GustLift.Phase.HELD:
			queue_free()
			return
		if caster == null or not caster.valid():
			lift.drop()
			queue_free()
			return
		t += dt
		var aim := _aim(false)
		if aim != Vector3.INF:
			lift.aim = aim
		if t >= hold_s:
			lift.hurl(_arced(_aim(true)))
			queue_free()

	## The caster's aim now: its target's chest (`final`: led and scattered, target_point), else its aim point.
	func _aim(final: bool) -> Vector3:
		var who := caster.aim_target()
		var ex: Array = [(lift.stone as CollisionObject3D).get_rid()] if lift.stone is CollisionObject3D else []
		if who == null:
			return caster.aim_point(ex)
		if not final:
			return NpcSenses.chest_of(who)
		var hd := lift._hurl_d()
		var mps: Array = hd.get("mps", [20.0, 20.0])
		return caster.target_point(who, float(mps[mps.size() - 1]))

	## `p` raised by the drop its flight's gravity gives it on the way (so it arrives at `p`).
	func _arced(p: Vector3) -> Vector3:
		if p == Vector3.INF:
			return p
		var hd := lift._hurl_d()
		var mps: Array = hd.get("mps", [20.0, 20.0])
		var tf := lift.at().distance_to(p) / maxf(float(mps[mps.size() - 1]), 0.1)
		return p + Vector3.UP * 0.5 * float(hd.get("gravity", 6.0)) * tf * tf
