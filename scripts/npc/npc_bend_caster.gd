class_name NpcBendCaster
extends BodyBendCaster
## An element bot's caster (NpcBending; Tidebreak, the ring sport: the owner, 2026-10-04, the bots cast the same moves as the
## player, through the same path: BendCast.cast, BendEffects): a BodyBendCaster on an NpcFighter, its target the one its mind
## fights (NpcBrain.target, live), its aim by its difficulty (data/npc/bend_ai.json presets):
##   chest           NpcSenses.chest_of(it) (crouched or not)
##   the aim         the foe's chest, led by his pace over the flight (lead: the preset's share) and scattered by the preset's
##                   scatter_deg through the fighter's own seeded rng (NpcFighter.scatter: the tests repeat)
##   what hides him  a cloud on the line from it to him (BendZone smoke, dust or spray; a steam cloud: HIDING): the scatter
##                   tripled (hidden()); the bot does not start an aimed move while he is hidden (NpcBending)
##   dazzled         a flare's meta bend_dazzle_until on the bot: the scatter doubled while it lasts
##   launch_point    the cast clip's strike limb (NpcBody.strike_point) when it is near the chest, else the chest a little on
##   side_sign       the side NpcBending picked (the one with room on a deck), else by its own chance
##   mode_of(id)     the mode NpcBending is casting (modes), its water Bending.of(it), its team its faction
## No camera, no keys, no notices; nothing drawn on anyone (the owner's no-target-cues rule).

## Clouds that hide a man from a bot's aim (BendZone kinds).
const HIDING := ["smoke", "dust", "spray", "steam"]

var me: NpcFighter


func _init(f: NpcFighter = null, p_lead := 0.8, p_scatter_deg := 1.8) -> void:
	super(f, null, p_lead, p_scatter_deg)
	me = f


## The foe its mind fights now (live: NpcBrain.target), else the target set by hand (a test's).
func _foe() -> Node3D:
	if me != null and is_instance_valid(me) and me.brain != null:
		var t := me.brain.target
		if t != null and is_instance_valid(t) and t.is_inside_tree():
			return t
	return target if has_target() else null


func has_target() -> bool:
	if me != null and is_instance_valid(me) and me.brain != null and me.brain.target != null:
		var t := me.brain.target
		if is_instance_valid(t) and t.is_inside_tree():
			target = t
	return target != null and is_instance_valid(target) and target.is_inside_tree()


func chest() -> Vector3:
	return NpcSenses.chest_of(body)


func aim_target() -> Node3D:
	var t := _foe()
	return t if t != null and NpcSenses.can_fight(t) else null


## The foe's chest now (live), scattered as target_point when he is hidden or the bot is dazzled.
func aim_point(ex: Array = [], from := Vector3.INF) -> Vector3:
	var t := _foe()
	if t == null:
		return super.aim_point(ex, from)
	var p := NpcSenses.chest_of(t)
	var m := _scatter_mult()
	if m > 1.0 and scatter_deg > 0.0:
		p = _scatter(chest(), p, scatter_deg * (m - 1.0))
	return p


## His chest, led by his pace over a flight of `mps` (times lead), scattered by scatter_deg (x _scatter_mult).
func target_point(t: Node3D, mps := 0.0) -> Vector3:
	var from := chest()
	var p := NpcSenses.chest_of(t)
	if mps > 0.1 and lead > 0.0:
		var v := NpcSenses.velocity_of(t)
		p += Vector3(v.x, 0.0, v.z) * (from.distance_to(p) / mps) * lead
	var sd := scatter_deg * _scatter_mult()
	if sd > 0.0:
		p = _scatter(from, p, sd)
	return p


func launch_point(flat := Vector3.ZERO) -> Vector3:
	var base := super.launch_point(flat)
	if me != null and is_instance_valid(me) and me.body != null and me.body.cast_clip != "" and me.body.sk != null:
		var sp := me.body.strike_point()
		if sp != Vector3.INF and sp.distance_to(chest()) < 1.1:
			var f := flat if flat.length_squared() > 1e-6 else facing()
			return sp + f * 0.35
	return base


func team() -> StringName:
	return StringName(me.faction) if me != null and is_instance_valid(me) else team_id


## How much the aim's scatter grows now: x3 with the foe hidden by a cloud on the line, x2 dazzled (both: x6).
func _scatter_mult() -> float:
	var m := 1.0
	var t := _foe()
	if t != null and hidden(body, t):
		m *= 3.0
	if dazzled(body):
		m *= 2.0
	return m


## Whether `t` is hidden from `from_body` by a cloud (HIDING) on the line between their chests.
static func hidden(from_body: Node3D, t: Node3D) -> bool:
	if from_body == null or t == null or not is_instance_valid(from_body) or not is_instance_valid(t) or not from_body.is_inside_tree():
		return false
	var a := NpcSenses.chest_of(from_body)
	var b := NpcSenses.chest_of(t)
	for z in from_body.get_tree().get_nodes_in_group(BendZone.GROUP):
		var bz := z as BendZone
		if bz == null or not bz.kind in HIDING or bz.is_queued_for_deletion():
			continue
		var c := bz.global_position + Vector3.UP * minf(bz.radius, 1.2)
		var q := Geometry3D.get_closest_point_to_segment(c, a, b)
		if q.distance_to(c) <= bz.radius + 0.3:
			return true
	return false


## A flare's dazzle on `n` (its meta bend_dazzle_until, BendStatus' clock).
static func dazzled(n: Node) -> bool:
	return BendStatus.until(n, &"bend_dazzle_until") > 0.0
