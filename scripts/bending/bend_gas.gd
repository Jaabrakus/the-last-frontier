extends RefCounted
## Earth's Sulphur set (data/sway/skill_tree.json skill_sets.sulphur: earth.set.sulphur and its nodes; the owner, 2026-10-11:
## "we need to make sure all the talents work and they work in game right"): gas, a BendZone of kind "gas" that only a set
## wearer's stones make, so Classic (no picks) never meets any of it (the tree's reaction rules).
##   the clouds   cloud (cloud_radius_m 2.5, cloud_life_s 3, cap_per_cloud_pct 6) and puff (puff_radius_m 1.5, puff_life_s 2.5,
##                cap_per_puff_pct 3) from the tree's skill_sets.sulphur.zone; a wearer's own set rules over them (Flint Pebbles'
##                life, Sulphur Heart's radius: BendLoadout tune set:sulphur.<key>); at most zones_per_caster (4) of one caster's
##                stand (his oldest ends); made on the deck under where they rise
##   the ticks    the tree's tick_contract: a foe inside gains pct_per_tick (the matter/gas class's d, rules.json) each every_s,
##                one matter tick a body each every_s however many clouds he stands in, at most the cloud's cap from one cloud;
##                % only (RingRules.add_pct: no knock, no stun, no lock set-back, no string, never staled); his own gas never
##                hurts its owner, allies never (BendStatus.can_take)
##   reactions    a bolt through a cloud (BendZone.on_bolt): fire lights it (the Ignited Sulphur burst: reaction/ignited_gas, a
##                set knock away from its middle on everyone within BURST_K of its round but the lighter's side, owned by the
##                lighter; the cloud gone; IGNITED! at the callouts' spot), water washes it (gone), wind carries it (moved on
##                along the bolt, CARRY_M 4 m, the mover's now); the wearer's own Pebbles light his own gas with Flint Pebbles
##                (his gas only). Pass 2: a cone that reaches it the same by its kind (cone: Breath, a fire Sweep or ring, the
##                Lash, the Wave); a Fire Wall or burning ground on it lights it, a Wind Wall on it carries it away from its
##                face once (every: its own look round, each 0.25 s); lightning through it charges it (live, Live Gas: everyone
##                inside takes LIVE_K of the strike's %, % only; the gas stays)
##   the sources  the set: his Boulder's end (a cloud where it bursts) and a stone clash with a foe's (a cloud where they met);
##                Sulphur Spike: a puff where his Spike stops; Sulphur Boulder: three puffs along its flight; Fuming Column:
##                a plume where his pillar rose; Brimstone Wall: a cloud 1 m out on the shooter's side of his wall shot down;
##                Sulphur Vent: a new skill (4 tapped twice: moves.json earth_wall.talent_bend.vent, BendLoadout's new skills),
##                the deck cracked where he aims (2-6 m, placed like a wall) breathing a cloud of the spec's 3 m for 4 s (one
##                gas cloud's cap, 6%; his set's cloud rules are the set's clouds', the vent's numbers its own); one vent of
##                his at a time (his old one ends, his other gas stays); it counts among his zones_per_caster
##   home ground  Sulphur Heart: standing in his own gas his locks fill x HEART_MULT (the higher of it and Rooted; never times)
##   the bots     a bot standing in a foe's gas steps out of it (way_out, as smoke's rule asks: NpcBending._move); a bot
##                wearing the Vent places it on its foe (its spec's ai hint, NpcBending.hint_of: control, 1-8.5 m (6 m out and
##                3 m round), on him on the deck, not while its gas already stands on him: in_gas_of)
## Loaded by its path (preload), no class name: a class new to the project is unknown to a run of a checkout the editor has not
## scanned (the FissureFx lesson, 2026-10-11).

const SET := "earth.set.sulphur"
const SPIKE := "earth.sulphur.spike"
const BOULDER := "earth.sulphur.boulder"
const COLUMN := "earth.sulphur.fuming_column"
const WALL := "earth.sulphur.brimstone_wall"
const VENT := "earth.sulphur.vent"
const FLINT := "earth.sulphur.flint_pebbles"
const HEART := "earth.sulphur.heart"
const TICK_TAG := "matter/gas"
const IGNITE_TAG := "reaction/ignited_gas"
const TICK_META := &"bend_matter_tick_at"
## The gas's colour (its smoke puffs tinted: a yellow-green haze).
const COLOR := Color(0.78, 0.84, 0.3, 0.85)
## Wind carries a cloud this far along its way (m; the tree's world rule Wind Carries Clouds: 4 m), over CARRY_S.
const CARRY_M := 4.0
const CARRY_S := 0.4
## The Ignited Sulphur burst reaches this far past the cloud's middle, a share of its round (the tree's world rule Ignited
## Sulphur: "a burst 1.5x the cloud's size").
const BURST_K := 1.5
## Live Gas (the tree's world rule: lightning through a cloud charges it): everyone inside takes this share of the strike's %
## (proposed_classes reaction/live d_of_strike), % only; the gas stays.
const LIVE_K := 0.5
const LIVE_TAG := "reaction/live"
## Sulphur Heart's fill in his own gas, and the plume (Fuming Column) and the Boulder's trail puffs' numbers from the nodes.
const HEART_MULT := 1.15
const PLUME_R := 2.0
const PLUME_S := 3.0
const TRAIL_PUFFS := 3

## Gas zones made and not yet ended (a quick "none" for every reader while there is none: Classic never makes one).
static var live_n := 0
static var _made_n := 0


## Sulphur's zone rule `key` (skill_sets.sulphur.zone), the wearer's own for the set rules a node changes (`body`).
static func num(key: String, def: float, body: Node = null) -> float:
	var v: Variant = BendLoadout.set_rule("sulphur", key)
	var base := float(v) if v != null else def
	if body != null and ("set:sulphur." + key) in BendLoadout.TUNE_PATHS:
		return BendLoadout.tune_f(body, "set:sulphur." + key, base)
	return base


## The tick contract's number `key` (skill_tree.json tick_contract).
static func tick_num(key: String, def: float) -> float:
	BendLoadout._node("_")
	var v: Variant = BendLoadout._dig(BendLoadout._tree_root, ["tick_contract", key])
	return float(v) if (v is float or v is int) else def


## A gas cloud of `by`'s rising at `at` (the deck under it): `kind` "cloud" or "puff" (the set's numbers), or a radius `r`, a
## life `life` and a cap `cap` of its own (a plume). Null when `by` does not wear the set (or a ghost online: the host's).
static func make(by: Node3D, at: Vector3, kind := "cloud", r := -1.0, life := -1.0, cap := -1.0) -> BendZone:
	if by == null or not is_instance_valid(by) or not by.is_inside_tree() or not BendLoadout.wears(by, SET) or not NetSpells.decides():
		return null
	var puff := kind == "puff"
	var rad := r if r > 0.0 else (num("puff_radius_m", 1.5) if puff else num("cloud_radius_m", 2.5, by))
	var lf := life if life > 0.0 else (num("puff_life_s", 2.5) if puff else num("cloud_life_s", 3.0, by))
	var cp := cap if cap > 0.0 else num("cap_per_puff_pct" if puff else "cap_per_cloud_pct", 3.0 if puff else 6.0)
	var foot := FormEffects.ground_at(by, at)
	if absf(at.y - foot.y) > 3.0:
		foot = at                                  # (no deck near under it: where it is)
	var keep := BendR3.cur
	BendR3.cur = {}
	var z := BendZone.make(by, "gas", foot, {"radius_m": rad, "life_s": lf})
	BendR3.cur = keep
	_made_n += 1
	live_n += 1
	z.set_meta(&"gas_cap", cp)
	z.set_meta(&"gas_kind", kind)
	z.set_meta(&"gas_n", _made_n)
	_cap(by)
	return z


## At most zones_per_caster of `by`'s gas standing: his oldest end.
static func _cap(by: Node3D) -> void:
	var cap := int(num("zones_per_caster", 4.0))
	var mine: Array = gas_of(by)
	mine.sort_custom(func(a: BendZone, b: BendZone) -> bool: return int(a.get_meta(&"gas_n", 0)) < int(b.get_meta(&"gas_n", 0)))
	while mine.size() > cap:
		(mine.pop_front() as BendZone).end("capped")


## Every gas zone standing (owned by `by` when given).
static func gas_of(by: Node = null) -> Array:
	var out: Array = []
	if live_n <= 0:
		return out
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return out
	for z in tree.get_nodes_in_group(BendZone.GROUP):
		var bz := z as BendZone
		if bz != null and bz.kind == "gas" and not bz.is_queued_for_deletion() and (by == null or bz.owner_node == by):
			out.append(bz)
	if out.is_empty() and by == null:
		live_n = 0
	return out


## A gas zone ended (BendZone.end).
static func ended(_z: BendZone) -> void:
	live_n = maxi(live_n - 1, 0)


## The gas's tick on `n` inside zone `z` (BendZone._every, the host's): see the header.
static func tick(z: BendZone, n: Node3D) -> void:
	var by := z.owner_node
	if n == by or not BendStatus.can_take(n, by):
		return                                         # (his own gas never hurts him; allies never)
	var now := BendStatus.now()
	if now - float(n.get_meta(TICK_META, -INF)) < tick_num("every_s", 0.5) - 1e-3:
		return                                         # (one matter tick a body each every_s)
	var d := float(RingRules.class_of(TICK_TAG).get("d", tick_num("pct_per_tick", 1.0)))
	var dealt: Dictionary = z.get_meta(&"gas_dealt", {})
	var id := n.get_instance_id()
	if float(dealt.get(id, 0.0)) + d > float(z.get_meta(&"gas_cap", 6.0)) + 1e-4:
		return                                         # (at most its cap from one cloud)
	n.set_meta(TICK_META, now)
	dealt[id] = float(dealt.get(id, 0.0)) + d
	z.set_meta(&"gas_dealt", dealt)
	var rr := RingRules.current()
	if rr != null and RingRules.stock_on():
		rr.add_pct(n, d * RingRules.stock_num("pct_scale", 1.0), by, TICK_TAG)


## Bolt `b` passing through gas zone `z` (BendZone.on_bolt, before its own rules): fire lights it, water washes it, wind
## carries it; the owner's own Pebbles light it with Flint Pebbles. True when it acted (the bolt goes on).
static func react(z: BendZone, b: BendBolt) -> bool:
	if z.is_queued_for_deletion() or bool(z.get_meta(&"gas_reacted_%d" % b.get_instance_id(), false)):
		return false
	var by := b._by()
	var flint := b.kind == "stone" and by == z.owner_node and String(b.info.get("tag", "")) == "rock_jab/pebbles" \
			and BendLoadout.wears(by, FLINT)
	if b.kind == "fire" or b.burning or flint:
		ignite(z, by, b.global_position)
		return true
	if b.kind == "water":
		wash(z)
		return true
	if b.kind == "air":
		z.set_meta(&"gas_reacted_%d" % b.get_instance_id(), true)
		carry(z, Vector3(b.velocity.x, 0.0, b.velocity.z), by)
		return true
	return false


## The Ignited Sulphur burst (the tree's reaction/ignited_gas class: a set knock away from the cloud's middle) on everyone in
## gas zone `z` whom the lighter's blows may reach, owned by `lighter` (his % and KO credit); the cloud burnt away.
static func ignite(z: BendZone, lighter: Node3D, at: Vector3) -> void:
	var c := z.global_position
	var hit: Array = []
	var reach := z.radius * BURST_K
	for e in BendCaster.near(lighter if lighter != null else z.owner_node, c, reach + 1.0):
		var n: Node3D = e[0]
		var l := n.global_position - c
		if Vector2(l.x, l.z).length() > reach or l.y < -1.0 or l.y > 3.5 or not BendStatus.can_take(n, lighter):
			continue
		var away := n.global_position - c
		away.y = 0.0
		away = away.normalized() if away.length_squared() > 1e-4 else Vector3.FORWARD
		var cls := RingRules.class_of(IGNITE_TAG)
		var kv := BendR3.set_v(away, float(cls.get("base", 6.0)), float(cls.get("angle", 45.0)))
		BendR3.deliver(n, 10.0, n.global_position + Vector3.UP, away, lighter, -1.0, kv,
				{"tag": IGNITE_TAG, "move": "reaction", "mode": "ignited_gas", "from": c})
		hit.append(n)
	z.set_meta(&"gas_ignited", hit.size())
	BendLooks.burst(c + Vector3.UP * 0.8, "fire", 40, Vector3.UP, 180.0, 5.0 * BURST_K, 0.5)
	BendLooks.burst(c + Vector3.UP * 0.4, "fire", 20, Vector3.UP, 120.0, 3.0 * BURST_K, 0.15)
	BendSounds.play(&"fire_whoomph", c, 2.0)
	BendSounds.play(&"fire_crackle", c, 2.0)
	# (the reaction called out at the callouts' own spot, IGNITED!, the lighter's colour: RingHighlights' moment; nothing on anyone)
	var hl := RingHighlights.find(z.get_tree()) if z.is_inside_tree() else null
	if hl != null:
		hl.moment.emit("ignited", lighter, {"at": c, "hit": hit.size()})
	z.end("ignited")


## Water through gas zone `z`: washed away.
static func wash(z: BendZone) -> void:
	BendLooks.burst(z.global_position + Vector3.UP * 0.6, "water", 16, Vector3.UP, 120.0, 2.0, 0.2)
	z.end("washed")


## Wind through gas zone `z` along `way`: the cloud moved on CARRY_M that way (over CARRY_S), the mover's now.
static func carry(z: BendZone, way: Vector3, mover: Node3D) -> void:
	if way.length_squared() < 1e-4:
		return
	var to := FormEffects.ground_at(z, z.global_position + way.normalized() * CARRY_M)
	if mover != null and is_instance_valid(mover):
		z.owner_node = mover
	z.set_meta(&"gas_carried", true)
	var tw := z.create_tween()
	tw.tween_property(z, "global_position", to, CARRY_S).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## A cone of `kind` cast by `p` along `flat`, `r` long and `deg` wide (`ring`: all round him; BendEffects.cone: Breath, a fire
## Sweep, the Lash, the Wave's push, a fire ring) over the gas it reaches: fire lights it (his burst), water washes it, wind
## carries it on away from him (his now). A cloud is reached when its round comes within the cone. Classic never has gas.
static func cone(p: Node3D, flat: Vector3, r: float, deg: float, kind: String, ring: bool) -> void:
	if live_n <= 0 or p == null or not is_instance_valid(p) or not kind in ["fire", "water", "air"]:
		return
	for z: BendZone in gas_of():
		if z.is_queued_for_deletion():
			continue
		var to := z.global_position - p.global_position
		if absf(to.y) > 3.0:
			continue
		to.y = 0.0
		var d := to.length()
		if d - z.radius > r:
			continue
		if not ring and d > z.radius:
			var slack := rad_to_deg(asin(clampf(z.radius / d, 0.0, 1.0)))
			if rad_to_deg(to.normalized().angle_to(flat)) > deg * 0.5 + slack:
				continue
		var way := to.normalized() if d > 0.3 else flat
		match kind:
			"fire":
				ignite(z, p, z.global_position - way * minf(z.radius, d))
			"water":
				wash(z)
			"air":
				carry(z, way, p)


## Gas zone `z`'s look round (BendZone._every, each 0.25 s, the host's): a Fire Wall or burning ground on it lights it (its
## owner the lighter: a fire wall raised on a cloud, a cloud carried into one); a Wind Wall standing on it carries it on away
## from the wall's face, once a wall (its owner the mover now).
static func every(z: BendZone) -> void:
	if z.is_queued_for_deletion() or not z.is_inside_tree():
		return
	for o in z.get_tree().get_nodes_in_group(BendZone.GROUP):
		var w := o as BendZone
		if w == null or w == z or w.is_queued_for_deletion() or not (w.kind in BendZone.KILN_FIRES or w.kind == "wind_wall"):
			continue
		var at := _touch(w, z)
		if not at.is_finite():
			continue
		if w.kind != "wind_wall":
			ignite(z, w.owner_node as Node3D, at)
			return
		var key := "gas_blown_%d" % w.get_instance_id()
		if z.has_meta(key):
			continue
		z.set_meta(key, true)
		var side := signf((w.global_transform.affine_inverse() * z.global_position).z)
		carry(z, w.global_basis.z.normalized() * (side if absf(side) > 0.0 else 1.0), w.owner_node as Node3D)
		return


## Where zone `w` (a Fire Wall's, burning ground's or a Wind Wall's box: BendZone.inside's box, its width by its thickness and
## the same 0.3 m of slack) stands on gas zone `z`'s round: the box's nearest point to the cloud's middle when that is within
## its round (INF none).
static func _touch(w: BendZone, z: BendZone) -> Vector3:
	var l := w.global_transform.affine_inverse() * z.global_position
	if l.y < -1.5 or l.y > w.size.y + 0.5:
		return Vector3.INF
	var hx := w.size.x * 0.5
	var hz := w.size.z * 0.5 + 0.3
	var near := Vector3(clampf(l.x, -hx, hx), l.y, clampf(l.z, -hz, hz))
	if Vector2(l.x - near.x, l.z - near.z).length() > z.radius:
		return Vector3.INF
	return w.global_transform * near


## Live Gas (see the header): `by`'s lightning from `from` to `to` (BendEffects._strike) through gas charges each cloud it
## crosses: everyone inside whom his blows reach takes LIVE_K of the strike's % (its class's d, his own numbers: info's tag),
## % only (RingRules.add_pct: no launch, no stun, no set-back); the gas stays, crackling.
static func live(by: Node3D, from: Vector3, to: Vector3, info: Dictionary) -> void:
	if live_n <= 0 or by == null or not is_instance_valid(by):
		return
	var cls := BendLoadout.hit_class(by, RingRules.class_of(String(info.get("tag", ""))), info)
	var d := float(cls.get("d", 0.0)) * LIVE_K * RingRules.stock_num("pct_scale", 1.0)
	var rr := RingRules.current()
	for z: BendZone in gas_of():
		if z.is_queued_for_deletion() or not _crosses(z, from, to):
			continue
		var hit := 0
		for e in BendCaster.near(by, z.global_position, z.radius + 1.0):
			var n: Node3D = e[0]
			if not z.inside(n.global_position) or not BendStatus.can_take(n, by):
				continue
			if rr != null and RingRules.stock_on() and d > 0.0:
				rr.add_pct(n, d, by, LIVE_TAG)
			hit += 1
		z.set_meta(&"gas_live", int(z.get_meta(&"gas_live", 0)) + 1)
		z.set_meta(&"gas_live_hit", hit)
		_live_look(z)


## Whether the line `from` -> `to` passes through gas zone `z` (its round, from the deck to 3.5 m over it).
static func _crosses(z: BendZone, from: Vector3, to: Vector3) -> bool:
	var seg := to - from
	var l2 := seg.length_squared()
	var t := clampf((z.global_position - from).dot(seg) / l2, 0.0, 1.0) if l2 > 1e-6 else 0.0
	var q := from + seg * t
	var l := q - z.global_position
	if Vector2(l.x, l.z).length() > z.radius:
		return false
	if l.y >= -1.0 and l.y <= 3.5:
		return true
	# (a strike from high: the nearest flat point may sit above it; the line's height where it is over the round's middle)
	var flat := Vector2(seg.x, seg.z)
	if flat.length_squared() < 1e-6:
		return false
	var tf := clampf(Vector2(z.global_position.x - from.x, z.global_position.z - from.z).dot(flat) / flat.length_squared(), 0.0, 1.0)
	var y := from.y + seg.y * tf - z.global_position.y
	return y >= -1.0 and y <= 3.5


## A charged cloud's look: arcs crackling through it and sparks, a charge heard (nothing on anyone).
static func _live_look(z: BendZone) -> void:
	var c := z.global_position
	BendSounds.play(&"lightning_charge", c, 0.0)
	BendLooks.burst(c + Vector3.UP * 0.9, "lightning", 16, Vector3.UP, 180.0, 3.0, 0.15)
	if not BendLooks.live():
		return
	for i in 3:
		var a := c + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * z.radius * 0.7 + Vector3.UP * randf_range(0.3, 1.4)
		var b := c + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * z.radius * 0.7 + Vector3.UP * randf_range(0.3, 1.4)
		BendLooks.lightning(a, b)


## Whether `body` stands in a gas zone of `by`'s.
static func in_gas_of(body: Node3D, by: Node) -> bool:
	if live_n <= 0 or body == null or not is_instance_valid(body):
		return false
	for z: BendZone in gas_of(by):
		if z.inside(body.global_position):
			return true
	return false


## The Sulphur Vent (see the header): `by`'s vent cast at `at` (BendEffects.zone, its spec a zone of kind gas placed like a
## wall): his old vent ends, the deck cracks there and breathes a cloud of `spec`'s radius_m and life_s. Null when he does not
## wear it (or a ghost online: the host's).
static func vent(by: Node3D, at: Vector3, spec: Dictionary) -> BendZone:
	if by == null or not is_instance_valid(by) or not BendLoadout.wears(by, VENT):
		return null
	for old: BendZone in gas_of(by):
		if String(old.get_meta(&"gas_kind", "")) == "vent":
			old.end("capped")
	var z := make(by, at, "vent", float(spec.get("radius_m", 3.0)), float(spec.get("life_s", 4.0)), num("cap_per_cloud_pct", 6.0))
	if z != null:
		_vent_look(z)
	return z


## The vent's own look over the cloud's haze (BendGas.look): the deck cracked at its mouth for its life, a puff of dust as it
## opens, a crack of stone heard, and a column of thicker yellow-green puffs bubbling up from its middle. On the deck only.
static func _vent_look(z: BendZone) -> void:
	BendSounds.play(&"earth_cast_crack", z.global_position, -2.0)
	if not BendLooks.live() or not z.is_inside_tree():
		return
	var pool := ToonFxPool.of(z.get_tree().current_scene)
	if pool != null:
		pool.mark("cracks", z.global_position, Vector3.UP, 1.8, z.life_s + 0.6)
		pool.shoot("puff_dust", z.global_position + Vector3.UP * 0.1, 12, Vector3.UP, 70.0, Vector2(0.5, 1.4), Vector2(0.3, 0.6),
				0.7, Vector3.ZERO, 1.5, {"r": 0.6})
	var g := BendLooks.emitter(z, "smoke", Vector3(0.35, 0.1, 0.35), 26, 1.3, 1.6, 0.55)
	if g != null:
		(g.process_material as ParticleProcessMaterial).color = COLOR.darkened(0.12)
		g.position = Vector3.UP * 0.15


## Whether `body` stands in a gas zone of his own.
static func in_own_gas(body: Node3D) -> bool:
	if live_n <= 0 or body == null:
		return false
	for z: BendZone in gas_of(body):
		if z.inside(body.global_position):
			return true
	return false


## Sulphur Heart (see the header): the fill rate `body`'s locks take at home in his own gas (HEART_MULT), else 1.
static func home_mult(body: Node3D) -> float:
	if live_n <= 0 or not BendLoadout.wears(body, HEART):
		return 1.0
	return HEART_MULT if in_own_gas(body) else 1.0


## A bot standing in a foe's gas: a point out of it (the cloud's edge, a step past, straight away from its middle); INF none.
static func way_out(body: Node3D) -> Vector3:
	if live_n <= 0 or body == null:
		return Vector3.INF
	for z: BendZone in gas_of():
		if z.owner_node == body or BendCaster.same_team(body, z.owner_node) or not z.inside(body.global_position):
			continue
		var away := body.global_position - z.global_position
		away.y = 0.0
		away = away.normalized() if away.length_squared() > 1e-4 else body.global_basis.x
		return z.global_position + away * (z.radius + 1.2)
	return Vector3.INF


## A thrown stone of `by`'s stopped at `at` (GustLift: burst on a body, the deck, a wall; `kind` spike or cannonball; `from`
## where its flight began): the set's sources (see the header).
static func stone_end(by: Node3D, kind: String, at: Vector3, from: Vector3) -> void:
	if by == null or not is_instance_valid(by) or not BendLoadout.wears(by, SET):
		return
	if kind == "spike":
		if BendLoadout.wears(by, SPIKE):
			make(by, at, "puff")
		return
	if kind != "cannonball":
		return
	make(by, at, "cloud")
	if BendLoadout.wears(by, BOULDER) and from.is_finite():
		for i in TRAIL_PUFFS:
			make(by, from.lerp(at, float(i + 1) / float(TRAIL_PUFFS + 1)), "puff")


## Two casters' stones met at `at` (BendBolt.meet, meet_lift, GustLift._meet_lifts): a cloud for each side wearing the set (his
## stones clashing with a foe's).
static func clash(a: Node, b: Node, at: Vector3) -> void:
	if a == null or b == null or a == b or not is_instance_valid(a) or not is_instance_valid(b) or BendCaster.same_team(a, b):
		return
	for n: Node in [a, b]:
		if n is Node3D and BendLoadout.wears(n, SET):
			make(n as Node3D, at, "cloud")


## The look of gas zone `z` (BendZone._look): a slow rolling haze of yellow-green puffs over its round, low on the deck.
static func look(z: BendZone) -> GPUParticles3D:
	var g := BendLooks.emitter(z, "smoke", Vector3(z.radius * 0.75, 0.5, z.radius * 0.75), int(30.0 * z.radius), 2.0, 0.35, 1.4)
	if g != null:
		(g.process_material as ParticleProcessMaterial).color = COLOR
		g.position = Vector3.UP * 0.5
	return g
