extends RefCounted
## Timing the player's guard (E, round 2: SwayCaster.SRC_GUARD) to a shot of the practice dummy's, for the tests that guard by
## the button as a player does (tests/ring/test_practice_guards.gd, tests/ring/test_lessons.gd):
##   shots(tree, foe)          the dummy's shots in flight: its BendBolts, its thrown stones (GustLift in flight) and its old
##                             spikes (NpcBending.Flight), each {node, at, v}
##   enter_s(shot, body, r)    seconds until the shot is within r (flat) of the body (-1: it never comes that near)
##   radius_of(el)             the element's guard's reach (its spec's radius_m; BendZone's flat circle round its owner)
##   on_beat(tree, c, foe, ..) waits for the next shot and clicks the guard so the shot reaches the guard `at` s after it
##                             stands (the press's lead: the guard's own lock, measured on the caster; `windup`: read
##                             off the dummy's lock before the shot leaves, windup_s, for an aim later than its flight); the result
##                             (BendCaster.guarded: perfect, late, whiff; "" none told) and the click's lead
##   const GuardTiming := preload("res://tests/ring/guard_timing.gd")


static func shots(tree: SceneTree, foe: Node) -> Array:
	var out: Array = []
	if foe == null or not is_instance_valid(foe):
		return out
	for n in tree.get_nodes_in_group(BendBolt.GROUP):
		var b := n as BendBolt
		if b != null and not b.spent and b.caster == foe:
			out.append({"node": b, "at": b.global_position, "v": b.velocity})
	for n in tree.get_nodes_in_group(GustLift.GROUP):
		var g := n as GustLift
		if g != null and g.phase == GustLift.Phase.FLIGHT and g.caster != null and g.caster.body == foe \
				and g.stone != null and is_instance_valid(g.stone):
			out.append({"node": g, "at": g.stone.global_position, "v": g.velocity})
	for n in tree.get_nodes_in_group(NpcBending.FLIGHT_GROUP):
		var f := n as NpcBending.Flight
		if f != null and f.shooter == foe and f.stone != null and is_instance_valid(f.stone):
			out.append({"node": f, "at": f.stone.global_position, "v": f.velocity})
	return out


static func enter_s(shot: Dictionary, body: Node3D, r: float) -> float:
	var at: Vector3 = shot.at
	var v: Vector3 = shot.v
	var rel := Vector2(at.x - body.global_position.x, at.z - body.global_position.z)
	var vf := Vector2(v.x, v.z)
	var a := vf.length_squared()
	if a < 0.01:
		return -1.0
	if rel.length() <= r:
		return 0.0
	# |rel + vf t| = r: the smaller root ahead
	var b := 2.0 * rel.dot(vf)
	var cc := rel.length_squared() - r * r
	var disc := b * b - 4.0 * a * cc
	if disc < 0.0:
		return -1.0
	var t := (-b - sqrt(disc)) / (2.0 * a)
	return t if t > 0.0 else -1.0


static func radius_of(el: String) -> float:
	var g := Bending.guard(el)
	var b: Variant = SwayMoves.move(String(g.get("id", ""))).get("bend", {})
	var s: Variant = (b as Dictionary).get(String(g.get("mode", "")), {}) if b is Dictionary else {}
	return float((s as Dictionary).get("radius_m", 2.0)) if s is Dictionary else 2.0


## The next shot of `foe` met by caster `c`'s guard clicked `lead` s before the shot is due within the guard's reach, so it
## arrives `at` s into the guard's window. `lead`: the press to the guard standing (the guard's lock and a frame). Returns
## {result ("perfect" | "late" | "whiff" | "": nothing told within `limit`), lead (s), enter (the shot's due time at the press)}.
static func on_beat(tree: SceneTree, c: SwayCaster, foe: Node, at := 0.12, limit := 8.0, windup := false) -> Dictionary:
	var p := c.player
	var el := c.quick_element()
	var r := radius_of(el)
	var bc := BendCaster.of(p)
	var got := [""]
	var cb := func(result: String, _what: String) -> void:
		if got[0] == "" or got[0] == "whiff":
			got[0] = result
	if bc != null:
		bc.guarded.connect(cb)
	var lead := guard_lead(c)
	var t := 0.0
	var pressed := -1.0
	var due := -1.0
	var seen := {}
	var dt := 1.0 / Engine.physics_ticks_per_second
	while t < limit:
		if pressed < 0.0 and windup:
			# (a late aim needs more time than a shot's flight gives: read off the dummy's own lock, as a bot reads a man's)
			var e := windup_s(foe, p, r)
			if e >= 0.0 and e <= lead + at:
				c.guard_override = true
				pressed = t
				due = e
		if pressed < 0.0:
			for s: Dictionary in shots(tree, foe):
				var nid := (s.node as Node).get_instance_id()
				if not seen.has(nid):
					seen[nid] = t                     # (read from its third frame: a slowed practice shot is slowed as it leaves)
				if t - float(seen[nid]) < 2.5 * dt:
					continue
				var e := enter_s(s, p, r)
				if e >= 0.0 and e <= lead + at:
					c.guard_override = true          # (a click: down for two frames, the lock goes when full)
					pressed = t
					due = e
					break
		elif t - pressed >= 2.0 * dt:
			c.guard_override = false
		if pressed >= 0.0 and got[0] in ["perfect", "late"]:
			break
		if pressed >= 0.0 and t - pressed > 2.0:
			break
		await tree.physics_frame
		t += dt
	c.guard_override = null                     # (the button's own state again)
	if bc != null and bc.guarded.is_connected(cb):
		bc.guarded.disconnect(cb)
	return {"result": got[0], "lead": lead, "enter": due}


## Seconds until the shot the bot `foe` is locking now is due within `r` of `body` (its lock's rest, its strike, its flight:
## NpcBending.shot_of), -1 when it locks no shot.
static func windup_s(foe: Node, body: Node3D, r: float) -> float:
	var f := foe as NpcFighter
	if f == null or f.brain == null or f.brain.bending == null:
		return -1.0
	var nb: NpcBending = f.brain.bending
	if nb.casting == "":
		return -1.0
	var shot := NpcBending.shot_of(nb.casting, nb.mode, nb.grown)
	if shot.is_empty():
		return -1.0
	var d := Vector2(f.global_position.x - body.global_position.x, f.global_position.z - body.global_position.z).length()
	return maxf(nb.lock_s - nb.lock_t, 0.0) + NpcBending.READ_STRIKE_S + maxf(d - r, 0.0) / float(shot.mps)


## The press-to-standing time of caster `c`'s guard now: its lock (SwayCaster._lock_time's own reckoning for the guard, the
## element's lock_mult and tier) and two frames.
static func guard_lead(c: SwayCaster) -> float:
	var g := Bending.guard(c.quick_element())
	var id := String(g.get("id", ""))
	var base := float(SwayMoves.move(id).get("lock_s", 0.2))
	return BendZone.guard_lock_s(c.player, base * c.lock_mult * c.tier_mult(id)) + 3.0 / Engine.physics_ticks_per_second
