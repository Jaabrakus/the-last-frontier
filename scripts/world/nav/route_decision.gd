class_name RouteDecision
extends RefCounted
## THE DECISION before a walk (user 2026-09-30: "the line should turn red or obstacle is in front then we need a decision
## engine to either have person go around, open door or you know"): for a worker and a place, what the ways there ask of her
## and which she takes by default, or why there is none.
##   RouteDecision.decide(worker, to) -> {ok, routes: [{kind, way, len, cost, over, doors, verdict}], pick, blocked}
## A route's verdict is what it asks: "clear" (open ground), "door" (through `doors` doors: she presses E at each), "over" (a
## mini-vault or a climb; only where her abilities allow it, WalkGrid's `can`). The default `pick` is the one with the least
## cost where a door counts DOOR_COST m and getting over counts OVER_COST m; "around" beats "over" unless it is OVER_COST
## longer. With no way at all `blocked` says where the straight line to the place is stopped, by what, and `ok` is false:
## the preview draws that in red and the order is not given.

## What a door and a climb count against a way (m of walking).
const DOOR_COST := 6.0
const OVER_COST := 25.0
const DOOR_ON_M := 1.6
## The straight line is tried at these heights over her feet (a knee, the chest).
const RAY_HEIGHTS: Array[float] = [0.45, 1.2]


static func decide(w: Spouse, to: Vector3, routes: Array = []) -> Dictionary:
	var rs := routes if not routes.is_empty() else WorkerOrders.routes_for(w, to)
	var out := {"ok": false, "routes": [], "pick": -1, "blocked": {}}
	if rs.is_empty():
		out.blocked = blocked_by(w, to)
		return out
	var g := WalkGrid.of(w.get_tree())
	var doors: Array = g._door_list() if g != null else []
	var best := INF
	for i in rs.size():
		var r: Dictionary = (rs[i] as Dictionary).duplicate()
		r["doors"] = _doors_on(r.way, doors)
		r["verdict"] = "over" if bool(r.over) else ("door" if not (r.doors as Array).is_empty() else "clear")
		var eff := float(r.len) + DOOR_COST * (r.doors as Array).size() + (OVER_COST if bool(r.over) else 0.0)
		r["effective"] = eff
		(out.routes as Array).append(r)
		if eff < best:
			best = eff
			out.pick = i
	out.ok = true
	return out


## The doors (BuildDoor) a way passes through.
static func _doors_on(way: PackedVector3Array, doors: Array) -> Array:
	var found := []
	for d: BuildDoor in doors:
		if not is_instance_valid(d):
			continue
		var c := d.global_position
		var nb := WalkPath._nearest(way, c)
		if Vector2((nb[1] as Vector3).x - c.x, (nb[1] as Vector3).z - c.z).length() <= DOOR_ON_M:
			found.append(d)
	return found


## Where the straight line from `w` to `to` is stopped and by what: {at: Vector3, why: String} (`at` is `to` when nothing
## solid is on the line: the water, or ground too steep, or her way shut in).
static func blocked_by(w: Spouse, to: Vector3) -> Dictionary:
	var space := w.get_world_3d().direct_space_state
	var from := w.global_position
	var best := {"at": to, "why": "deep water, steep ground or walled in", "d": INF}
	for h in RAY_HEIGHTS:
		var q := PhysicsRayQueryParameters3D.create(from + Vector3.UP * h, Vector3(to.x, from.y + h, to.z))
		q.exclude = [w.get_rid()]
		var player := w.get_tree().current_scene.get_node_or_null("Player") as CollisionObject3D
		if player != null:
			q.exclude.append(player.get_rid())
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var d: float = from.distance_to(hit.position)
		if d < float(best.d):
			best = {"at": hit.position, "why": _why(hit.collider as Node), "d": d}
	best.erase("d")
	return best


static func _why(n: Node) -> String:
	while n != null:
		if n is BuildDoor:
			return "a shut door"
		if n is Spouse or n is FrontierPlayer:
			return "someone in the way"
		var nm := String(n.name).to_lower()
		for k: String in ["tree", "trunk", "rock", "boulder", "wall", "palisade", "log", "cabin", "fence"]:
			if nm.contains(k):
				return "a " + k
		n = n.get_parent()
	return "something solid"
