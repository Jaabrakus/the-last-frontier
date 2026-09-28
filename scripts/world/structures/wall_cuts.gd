class_name WallCuts
extends Node3D
## Pieces chopped out of the palisade and the gate's leaves with the felling axe (user 2026-09-26: "i also want to be
## able to gate to be chopable where we can use the axe so it allows us to create a window to shoot weapons"; asked
## where, "Both"; then "i want a whole piece of the wall choped down where the user aims the axe"). With the axe in
## the hand, the camera's aim on a wall within reach is the gathering target ("Chop through the palisade"): the piece
## of CUT_LOGS logs (or gate planks) nearest the aim, CUT_H tall around the aim's height (down to the ground when the
## aim is low; aimed near the top, the top comes off, the points too: a notch to shoot over from the walkway, user
## 2026-09-26: "i want to be able to cut that top part as well"). WORK strokes of power 1 cut it out. Pieces add up:
## cut beside, over or under an opening to widen it, down to the ground to walk through.
##
## FrontierStructures registers each palisade collider (register_wall: a straight slab of logs, one StaticBody3D with
## one box) and each log (add_log, then its MultiMesh instance once the fort is dressed); FortGate registers its leaves
## (register_local: the wall's line in the leaf body's frame, it swings with the leaf; its callback rebuilds the leaf's
## planks). A cut rebuilds the wall's collider as boxes around its openings (columns between the openings' edges, the
## solid spans of each; shots, aim rays and bodies pass the openings; the no_traverse meta is kept) and a palisade
## log with openings is shown as pieces (StructureGeometry.palisade_log_piece between the openings, the cut faces hewn;
## each a one-instance MultiMesh with the log's own custom data) instead of its instance.
## Each opening can be closed again from build mode (BuildMode, user 2026-09-26: "each one hole we cut we need to
## either be able to build a doors there or cover it up with logs or repair it"): repair (the logs as they were),
## cover (horizontal logs across it: the collider closes, the cut logs stay), or a door (a hung plank door, BuildDoor,
## in an opening chopped open from the ground up to DOOR_MIN_H; the palisade only). Chopping into a cover knocks it
## out again.
## Openings are not saved (the level is rebuilt on every load).

const GROUP := &"wall_cuts"
const CUT_LOGS := 2                  ## logs (planks) a piece takes (two palisade logs: about 0.76 m)
const CUT_H := 0.7                   ## a piece's height
const GROUND_SNAP := 0.3             ## a piece whose foot comes this close to the ground reaches it
const TOP_SNAP := 0.6               ## a piece whose top comes this close to the wall's top takes the top off
const TOP_OVER := 0.6                ## ... up to this far over it (past the tallest log's point)
const WORK := 8.0                    ## strokes of power 1 to cut a piece
const REACH := 1.5                   ## the aim's point at most this far from the chest (horizontally)
const DOOR_MIN_H := 1.85             ## a door needs the opening this tall from the ground
const DOOR_MAX_H := 2.2              ## ... and is at most this tall (the logs over it stay)
const COVER_LOG_R := 0.1             ## the cover's horizontal logs
const AIM_PAST := 0.6                ## the camera's aim ray reaches this far past REACH from the chest (a third-person
                                     ## camera stands metres behind the chest)

var materials := {}                  ## StructureMaterials (the dressed fort's; empty headless)
## {body, a, dir (world; a static wall), a_local, dir_local (the body's frame), local (the line follows the body),
##  length, height, thick, unit (log or plank width), on_cut (Callable(holes) or null), name,
##  holes: [[u0, u1, h0, h1]] (h over the wall's foot)}
var walls: Array = []
var logs: Array = []                 ## per wall: [{u, p, variant, mm, i, pieces}] sorted by u
var windows: Array = []              ## the pieces cut: {wall, k, u0, u1, y0, y1}
## Covers and doors in openings: {kind "cover" / "door", wall, rect [u0, u1, h0, h1], nodes, door}
var fills: Array = []
var _work := {}                      ## key -> work done
var _by_body := {}                   ## body instance id -> wall


static func find(tree: SceneTree) -> WallCuts:
	return tree.get_first_node_in_group(GROUP) as WallCuts if tree else null


func _ready() -> void:
	add_to_group(GROUP)


## A straight wall of logs from a to b (ground points on its centre line), `height` tall and `thick` deep, whose
## collider is `body` (one box, centred, local X along a -> b).
func register_wall(body: StaticBody3D, a: Vector3, b: Vector3, height: float, thick: float, name := "palisade") -> int:
	var L := a.distance_to(b)
	walls.append({"body": body, "a": a, "dir": (b - a).normalized(), "a_local": Vector3(-L * 0.5, -height * 0.5, 0.0),
			"dir_local": Vector3(1, 0, 0), "local": false, "length": L, "height": height, "thick": thick, "unit": thick,
			"on_cut": null, "name": name, "holes": []})
	logs.append([])
	_by_body[body.get_instance_id()] = walls.size() - 1
	return walls.size() - 1


## A wall that moves with its body (a gate leaf): its foot line from a_local along dir_local (the body's frame, dir_local
## +-X), `units` the centres of its planks along it (width `unit`); a cut calls on_cut(holes) to rebuild its visual.
func register_local(body: CollisionObject3D, a_local: Vector3, dir_local: Vector3, length: float, height: float, thick: float,
		units: Array, unit: float, on_cut: Callable, name := "gate") -> int:
	walls.append({"body": body, "a": Vector3.ZERO, "dir": Vector3.RIGHT, "a_local": a_local, "dir_local": dir_local.normalized(),
			"local": true, "length": length, "height": height, "thick": thick, "unit": unit, "on_cut": on_cut, "name": name,
			"holes": []})
	var wl := []
	for u: float in units:
		wl.append({"u": u, "p": Vector3.ZERO, "variant": -1, "mm": null, "i": -1, "pieces": []})
	logs.append(wl)
	_by_body[body.get_instance_id()] = walls.size() - 1
	return walls.size() - 1


## A log of the wall standing at ground point p (its MultiMesh instance: set_log_visual, once dressed).
func add_log(wall: int, p: Vector3) -> void:
	var w: Dictionary = walls[wall]
	var u := (p - (w.a as Vector3)).dot(w.dir)
	(logs[wall] as Array).append({"u": u, "p": p, "variant": -1, "mm": null, "i": -1, "pieces": []})


## The static wall a ground point's log belongs to (-1: none within 5 cm of a wall's line).
func wall_of(p: Vector3) -> int:
	for wi in walls.size():
		var w: Dictionary = walls[wi]
		if bool(w.local):
			continue
		var d := p - (w.a as Vector3)
		var u := d.dot(w.dir)
		if u < -0.05 or u > float(w.length) + 0.05:
			continue
		if (d - (w.dir as Vector3) * u).length() < 0.05:
			return wi
	return -1


func set_log_visual(p: Vector3, variant: int, mm: MultiMesh, i: int) -> void:
	var wi := wall_of(p)
	if wi < 0:
		return
	for lg: Dictionary in logs[wi]:
		if (lg.p as Vector3).distance_to(p) < 0.02:
			lg.variant = variant
			lg.mm = mm
			lg.i = i
			return


func finish_registration() -> void:
	for wi in logs.size():
		(logs[wi] as Array).sort_custom(func(x, y): return float(x.u) < float(y.u))


## A wall's foot line in the world: [a, dir].
func frame(wi: int) -> Array:
	var w: Dictionary = walls[wi]
	if not bool(w.local):
		return [w.a, w.dir]
	var body: Node3D = w.body
	var xf := body.global_transform if body.is_inside_tree() else body.transform
	return [xf * (w.a_local as Vector3), (xf.basis * (w.dir_local as Vector3)).normalized()]


## The piece the camera's aim (from `eye` along `look`) points at on a wall within REACH of `chest`: {} or the
## gathering candidate {type "wall", key, wall, k, h0, h1, pos, point, normal, radius, dist, name}.
func aim(eye: Vector3, look: Vector3, chest: Vector3, exclude: Array[RID] = []) -> Dictionary:
	if not is_inside_tree():
		return {}
	var q := PhysicsRayQueryParameters3D.create(eye, eye + look.normalized() * (eye.distance_to(chest) + REACH + AIM_PAST))
	q.exclude = exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or hit.collider == null:
		return {}
	var wi := int(_by_body.get((hit.collider as Object).get_instance_id(), -1))
	if wi < 0:
		return {}
	var hp: Vector3 = hit.position
	if Vector2(hp.x - chest.x, hp.z - chest.z).length() > REACH:
		return {}
	var fr := frame(wi)
	var a: Vector3 = fr[0]
	var dir: Vector3 = fr[1]
	var u := (hp - a).dot(dir)
	var k := _nearest(wi, u)
	if k < 0:
		return {}
	var span := _span(wi, hp.y - a.y)
	if span.is_empty() or _covered(wi, k, float(span[0]), float(span[1])):
		return {}
	var nrm := dir.cross(Vector3.UP).normalized()
	var out := nrm * signf((chest - a).dot(nrm))
	return _candidate(wi, k, float(span[0]), float(span[1]), out, Vector2(hp.x - chest.x, hp.z - chest.z).length())


## The candidate `key` again ({} when it was cut meanwhile).
func describe(key: String, chest: Vector3) -> Dictionary:
	var parts := key.split(":")
	if parts.size() != 4:
		return {}
	var wi := int(parts[0])
	var k := int(parts[1])
	var h0 := float(parts[2]) / 100.0
	var h1 := float(parts[3]) / 100.0
	if wi < 0 or wi >= walls.size() or _covered(wi, k, h0, h1):
		return {}
	var fr := frame(wi)
	var nrm := (fr[1] as Vector3).cross(Vector3.UP).normalized()
	var out := nrm * signf((chest - (fr[0] as Vector3)).dot(nrm))
	var c := _candidate(wi, k, h0, h1, out, 0.0)
	c.dist = Vector2((c.pos as Vector3).x - chest.x, (c.pos as Vector3).z - chest.z).length()
	return c


## One stroke of `power` at a candidate: the work done so far over the work it takes (1: the piece is out).
func strike(c: Dictionary, power: float) -> float:
	var key := str(c.key)
	_work[key] = float(_work.get(key, 0.0)) + power
	if float(_work[key]) >= WORK:
		_work.erase(key)
		cut(int(c.wall), int(c.k), float(c.h0), float(c.h1))
		return 1.0
	return float(_work[key]) / WORK


func progress(key: String) -> float:
	return clampf(float(_work.get(key, 0.0)) / WORK, 0.0, 0.99)


## Cuts the piece of logs k .. k + CUT_LOGS - 1 of wall wi between h0 and h1 over the wall's foot.
func cut(wi: int, k: int, h0: float, h1: float) -> void:
	if _covered(wi, k, h0, h1):
		return
	var wl: Array = logs[wi]
	var w: Dictionary = walls[wi]
	var r := float(w.unit) * 0.5
	var u0 := float(wl[k].u) - r
	var u1 := float(wl[k + CUT_LOGS - 1].u) + r
	(w.holes as Array).append([u0, u1, h0, h1])
	# (chopping into a cover knocks it out: its opening is open again)
	for fi in range(fills.size() - 1, -1, -1):
		var f: Dictionary = fills[fi]
		if int(f.wall) == wi and str(f.kind) == "cover" and _overlap(f.rect, [u0, u1, h0, h1]):
			if not _same(f.rect, [u0, u1, h0, h1]):
				(w.holes as Array).append((f.rect as Array).duplicate())
			_free_fill(fi)
	_rebuild(wi)
	_refresh_visual(wi, u0, u1)
	var base := float((frame(wi)[0] as Vector3).y)
	windows.append({"wall": wi, "k": k, "u0": u0, "u1": u1, "y0": base + h0, "y1": base + h1})


func window_count() -> int:
	return windows.size()


## The removed height spans of the wall at u (sorted, merged): [[h0, h1], ...]; visual: with the covered ones (the
## logs cut there stay cut under the cover).
func removed_at(wi: int, u: float, visual := false) -> Array:
	var spans := []
	var rects: Array = (walls[wi].holes as Array).duplicate()
	if visual:
		for f: Dictionary in fills:
			if int(f.wall) == wi and str(f.kind) == "cover":
				rects.append(f.rect)
	for hl: Array in rects:
		if u > float(hl[0]) + 0.001 and u < float(hl[1]) - 0.001:
			spans.append([float(hl[2]), float(hl[3])])
	spans.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	var out := []
	for sp: Array in spans:
		if not out.is_empty() and float(sp[0]) <= float(out[out.size() - 1][1]) + 0.001:
			out[out.size() - 1][1] = maxf(float(out[out.size() - 1][1]), float(sp[1]))
		else:
			out.append([float(sp[0]), float(sp[1])])
	return out


## The opening the aim (from `eye` along `look`) passes through on a wall within reach of `chest`, for closing it:
## kind "repair", "cover" or "door". {ok, reason, wall, rect [u0, u1, h0, h1], xf (its centre: X along the wall, Z
## toward the viewer), size, away (the side a door swings to)}; ok false with the reason when it cannot be done.
func opening_at(eye: Vector3, look: Vector3, chest: Vector3, kind: String, exclude: Array[RID] = []) -> Dictionary:
	if not is_inside_tree():
		return {"ok": false, "reason": ""}
	look = look.normalized()
	var reach := eye.distance_to(chest) + REACH + AIM_PAST
	var q := PhysicsRayQueryParameters3D.create(eye, eye + look * reach)
	q.exclude = exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var d_hit := eye.distance_to(hit.position) if not hit.is_empty() else reach
	var best := {}
	var best_t := INF
	for wi in walls.size():
		var fr := frame(wi)
		var a: Vector3 = fr[0]
		var dir: Vector3 = fr[1]
		var nrm := dir.cross(Vector3.UP).normalized()
		var den := look.dot(nrm)
		if absf(den) < 0.05:
			continue
		var t := (a - eye).dot(nrm) / den
		if t <= 0.0 or t > d_hit + float(walls[wi].thick) * 0.5 + 0.05 or t >= best_t:
			continue
		var pt := eye + look * t
		if Vector2(pt.x - chest.x, pt.z - chest.z).length() > REACH + 0.5:
			continue
		var u := (pt - a).dot(dir)
		var h := pt.y - a.y
		var holes: Array = walls[wi].holes
		for hi in holes.size():
			var hl: Array = holes[hi]
			if u >= float(hl[0]) - 0.02 and u <= float(hl[1]) + 0.02 and h >= float(hl[2]) - 0.02 and h <= float(hl[3]) + 0.02:
				best = {"wall": wi, "hole": hi, "rect": (hl as Array).duplicate(), "a": a, "dir": dir, "nrm": nrm}
				best_t = t
				break
	if best.is_empty():
		return {"ok": false, "reason": "Look into an opening chopped in the wall"}
	var wi2 := int(best.wall)
	var rect: Array = best.rect
	for f: Dictionary in fills:
		if int(f.wall) == wi2 and str(f.kind) == "door" and _overlap(f.rect, rect):
			return {"ok": false, "reason": "A door hangs in it"}
	if kind == "door":
		if bool(walls[wi2].local):
			return {"ok": false, "reason": "No door in the gate"}
		var top := INF
		for u2: float in [float(rect[0]) + 0.05, 0.5 * (float(rect[0]) + float(rect[1])), float(rect[1]) - 0.05]:
			var col := 0.0
			for sp: Array in removed_at(wi2, u2):
				if float(sp[0]) <= 0.001:
					col = float(sp[1])
			top = minf(top, col)
		if top < DOOR_MIN_H:
			return {"ok": false, "reason": "Chop it open from the ground up (%.1f m of %.2f) for a door" % [top, DOOR_MIN_H]}
		rect = [float(rect[0]), float(rect[1]), 0.0, minf(top, DOOR_MAX_H)]
	var a2: Vector3 = best.a
	var dir2: Vector3 = best.dir
	var nrm2: Vector3 = best.nrm
	var toward := nrm2 if (chest - a2).dot(nrm2) > 0.0 else -nrm2
	var c := a2 + dir2 * (0.5 * (float(rect[0]) + float(rect[1]))) + Vector3.UP * (0.5 * (float(rect[2]) + float(rect[3])))
	var x := toward.cross(Vector3.UP).normalized() * -1.0
	var xf := Transform3D(Basis(x, Vector3.UP, toward), c)
	return {"ok": true, "reason": "", "wall": wi2, "hole": int(best.hole), "rect": rect, "xf": xf, "away": -toward,
			"size": Vector3(float(rect[1]) - float(rect[0]), float(rect[3]) - float(rect[2]), float(walls[wi2].thick))}


## Repairs an opening (opening_at's): the logs (or planks) stand there again.
func repair(op: Dictionary) -> void:
	var wi := int(op.wall)
	var rect: Array = op.rect
	_drop_hole(wi, rect)
	_rebuild(wi)
	_refresh_visual(wi, float(rect[0]), float(rect[1]))


## Covers an opening with horizontal logs: the collider closes, the cut logs stay under the cover.
func cover(op: Dictionary) -> void:
	var wi := int(op.wall)
	var rect: Array = op.rect
	_drop_hole(wi, rect)
	var nodes := _cover_visual(wi, rect)
	fills.append({"kind": "cover", "wall": wi, "rect": rect.duplicate(), "nodes": nodes, "door": null})
	_rebuild(wi)
	_refresh_visual(wi, float(rect[0]), float(rect[1]))


## Hangs a door in an opening (opening_at "door"): a BuildDoor leaf hinged at one side, swinging to op.away.
func add_door(op: Dictionary) -> BuildDoor:
	var wi := int(op.wall)
	var rect: Array = op.rect
	var fr := frame(wi)
	var a: Vector3 = fr[0]
	var dir: Vector3 = fr[1]
	var away: Vector3 = op.away
	var w := float(rect[1]) - float(rect[0])
	var h := float(rect[3]) - float(rect[2])
	# The door's frame: -Z the side it swings to, X along the wall from its hinge.
	var zb := -away
	var xb := Vector3.UP.cross(zb).normalized()
	var hinge_u := float(rect[0]) if xb.dot(dir) > 0.0 else float(rect[1])
	var d := BuildDoor.new()
	d.name = "WallDoor"
	d.kind = "door"
	d.interact_reach = 2.4
	d._center = Vector3(w * 0.5, 1.0, 0.0)
	d._add_leaf("door", Vector3.ZERO, BuildDoor.OPEN_ANGLE, Vector3(w * 0.5, h * 0.5, 0.0), Vector3(w - 0.03, h - 0.02, 0.07))
	# (the build door's leaf mesh is 0.94 x 2.02 m: fitted to the opening)
	var lm: Node3D = d._meshes[0]
	lm.scale = Vector3((w - 0.03) / (BuildGeometry.DOOR_HALF * 2.0 - 0.06), (h - 0.02) / (BuildGeometry.DOOR_TOP - 0.08), 1.0)
	# (placed before it enters the tree: its leaf is an AnimatableBody3D that follows only its own transform)
	d.transform = global_transform.affine_inverse() * Transform3D(Basis(xb, Vector3.UP, zb), a + dir * hinge_u + Vector3.UP * float(rect[2]))
	add_child(d)
	fills.append({"kind": "door", "wall": wi, "rect": rect.duplicate(), "nodes": [d], "door": d})
	return d


func _overlap(r1: Array, r2: Array) -> bool:
	return float(r1[0]) < float(r2[1]) - 0.01 and float(r2[0]) < float(r1[1]) - 0.01 \
			and float(r1[2]) < float(r2[3]) - 0.01 and float(r2[2]) < float(r1[3]) - 0.01


## Drops every opening of the wall inside rect (the one repaired or covered, and any the same cut left twice).
func _drop_hole(wi: int, rect: Array) -> void:
	var holes: Array = walls[wi].holes
	for hi in range(holes.size() - 1, -1, -1):
		var hl: Array = holes[hi]
		if float(hl[0]) >= float(rect[0]) - 0.01 and float(hl[1]) <= float(rect[1]) + 0.01 \
				and float(hl[2]) >= float(rect[2]) - 0.01 and float(hl[3]) <= float(rect[3]) + 0.01:
			holes.remove_at(hi)


func _same(r1: Array, r2: Array) -> bool:
	for i in 4:
		if absf(float(r1[i]) - float(r2[i])) > 0.01:
			return false
	return true


func _free_fill(fi: int) -> void:
	for n: Node in fills[fi].nodes:
		if is_instance_valid(n):
			n.queue_free()
	fills.remove_at(fi)


## The wall's visual between u0 and u1 after a change: a palisade's logs there, a gate leaf's planks (its callback,
## with the covered openings as cut).
func _refresh_visual(wi: int, u0: float, u1: float) -> void:
	var w: Dictionary = walls[wi]
	if w.on_cut is Callable and (w.on_cut as Callable).is_valid():
		var vis: Array = (w.holes as Array).duplicate()
		for f: Dictionary in fills:
			if int(f.wall) == wi and str(f.kind) == "cover":
				vis.append(f.rect)
		(w.on_cut as Callable).call(vis)
		return
	for lg: Dictionary in logs[wi]:
		if float(lg.u) > u0 + 0.01 and float(lg.u) < u1 - 0.01:
			_show_log(wi, lg)


## Horizontal logs across a covered opening (bark, hewn ends), a hand's width past its sides; children of the wall's
## body for a moving wall (they swing with it).
func _cover_visual(wi: int, rect: Array) -> Array:
	if materials.is_empty():
		return []
	var w: Dictionary = walls[wi]
	# (a cover over a notch in the top ends at the wall's top)
	var hgt := minf(float(rect[3]), float(w.height)) - float(rect[2])
	var n := maxi(2, int(ceil(hgt / (COVER_LOG_R * 2.0 * 0.95))))
	var length := float(rect[1]) - float(rect[0]) + 0.24
	var kit := StructureMeshKit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + wi * 31 + int(float(rect[0]) * 10.0)
	for i in n:
		var y := float(rect[2]) + (i + 0.5) * hgt / n
		var r := COVER_LOG_R * rng.randf_range(0.92, 1.05)
		var uc := 0.5 * (float(rect[0]) + float(rect[1])) + rng.randf_range(-0.04, 0.04)
		var c := (w.a_local as Vector3) + (w.dir_local as Vector3) * uc + Vector3.UP * y
		_log_across(kit, c, (w.dir_local as Vector3), length, r, rng)
	var mi := MeshInstance3D.new()
	mi.name = "Cover"
	mi.mesh = kit.commit(materials)
	# (built in the wall body's frame: a static wall's body stands at its centre)
	(w.body as Node).add_child(mi)
	return [mi]


## One round log across (axis `dir`, centre c, in the body's frame): bark round, hewn ends.
func _log_across(kit: StructureMeshKit, c: Vector3, dir: Vector3, length: float, r: float, rng: RandomNumberGenerator) -> void:
	const SEG := 10
	var ax := dir.normalized()
	var u := ax.cross(Vector3.UP).normalized()
	var v := u.cross(ax).normalized()
	var a := c - ax * length * 0.5
	var b := c + ax * length * 0.5
	var rows_p := []
	var rows_n := []
	var rows_u := []
	var rows_c := []
	var ph := rng.randf() * TAU
	for e: Vector3 in [a, b]:
		var P := PackedVector3Array()
		var N := PackedVector3Array()
		var U := PackedVector2Array()
		var C := PackedColorArray()
		for j in SEG + 1:
			var ang := ph + TAU * j / SEG
			var nr := u * cos(ang) + v * sin(ang)
			P.append(e + nr * r)
			N.append(nr)
			U.append(Vector2(float(j) / SEG, (e - a).length() / StructureGeometry.BARK_TILE))
			C.append(Color(1, 1, 1, 0.9))
		rows_p.append(P)
		rows_n.append(N)
		rows_u.append(U)
		rows_c.append(C)
	kit.grid(&"bark_mm", rows_p, rows_n, rows_u, rows_c)
	for e2: Array in [[a, -ax], [b, ax]]:
		var e: Vector3 = e2[0]
		for j in SEG:
			var a0 := ph + TAU * j / SEG
			var a1 := ph + TAU * (j + 1) / SEG
			var p0 := e + (u * cos(a0) + v * sin(a0)) * r
			var p1 := e + (u * cos(a1) + v * sin(a1)) * r
			kit.tri(&"hewn_mm", p0, p1, e, Vector2(cos(a0), sin(a0)) * 0.2 + Vector2(0.5, 0.5),
					Vector2(cos(a1), sin(a1)) * 0.2 + Vector2(0.5, 0.5), Vector2(0.5, 0.5), Color(1, 1, 1, 1), StructureMeshKit.KIND_TEX, 0.0, e2[1])


# --------------------------------------------------------------------------------------------------

func _candidate(wi: int, k: int, h0: float, h1: float, out: Vector3, dist: float) -> Dictionary:
	var w: Dictionary = walls[wi]
	var wl: Array = logs[wi]
	var fr := frame(wi)
	var uc := 0.5 * (float(wl[k].u) + float(wl[k + CUT_LOGS - 1].u))
	var c := (fr[0] as Vector3) + (fr[1] as Vector3) * uc
	var face := Vector3(c.x, (fr[0] as Vector3).y + 0.5 * (h0 + h1), c.z) + out * float(w.thick) * 0.5
	return {"type": "wall", "src": "wall", "key": "%d:%d:%d:%d" % [wi, k, roundi(h0 * 100.0), roundi(h1 * 100.0)],
			"wall": wi, "k": k, "h0": h0, "h1": h1, "i": wi * 10000 + k, "pos": face, "point": face, "normal": out,
			"radius": 0.0, "dist": dist, "name": str(w.name)}


## The first log of the CUT_LOGS neighbours centred nearest u (-1: the wall's end or a gap).
func _nearest(wi: int, u: float) -> int:
	var wl: Array = logs[wi]
	var best := -1
	var best_d := INF
	for k in range(0, wl.size() - CUT_LOGS + 1):
		var a: Dictionary = wl[k]
		var b: Dictionary = wl[k + CUT_LOGS - 1]
		if float(b.u) - float(a.u) > (CUT_LOGS - 1) * float(walls[wi].unit) * 1.3:
			continue
		var d := absf(0.5 * (float(a.u) + float(b.u)) - u)
		if d < best_d:
			best_d = d
			best = k
	return best if best_d <= float(walls[wi].unit) * CUT_LOGS * 0.75 else -1


## The piece's height span around the aim's height h (over the wall's foot): to the ground when low, under the
## points at the top; [] when no piece fits.
func _span(wi: int, h: float) -> Array:
	var w: Dictionary = walls[wi]
	var H := float(w.height)
	var h0 := h - CUT_H * 0.5
	var h1 := h + CUT_H * 0.5
	if h0 < GROUND_SNAP:
		h0 = 0.0
		h1 = maxf(h1, CUT_H)
	if h1 > H - TOP_SNAP:
		# the top off, points and all
		h1 = H + TOP_OVER
		h0 = clampf(h0, 0.0, H - CUT_H)
	return [h0, h1] if h1 - h0 > 0.2 else []


## Logs k .. k + CUT_LOGS - 1 are already open between h0 and h1.
func _covered(wi: int, k: int, h0: float, h1: float) -> bool:
	for j in CUT_LOGS:
		var inside := false
		for sp: Array in removed_at(wi, float(logs[wi][k + j].u)):
			if float(sp[0]) <= h0 + 0.02 and float(sp[1]) >= h1 - 0.02:
				inside = true
		if not inside:
			return false
	return true


## The wall's collider as boxes around its openings: columns between the openings' edges, the solid spans of each
## (the body's frame: from a_local along dir_local, h up from its foot).
func _rebuild(wi: int) -> void:
	var w: Dictionary = walls[wi]
	var body: CollisionObject3D = w.body
	var meta: Variant = null
	for ch in body.get_children():
		if ch is CollisionShape3D:
			if meta == null and (ch as CollisionShape3D).has_meta(&"trav"):
				meta = (ch as CollisionShape3D).get_meta(&"trav")
			body.remove_child(ch)
			ch.queue_free()
	var L := float(w.length)
	var H := float(w.height)
	var T := float(w.thick)
	var cuts := [0.0, L]
	for hl: Array in w.holes:
		cuts.append(clampf(float(hl[0]), 0.0, L))
		cuts.append(clampf(float(hl[1]), 0.0, L))
	cuts.sort()
	for ci in range(cuts.size() - 1):
		var c0 := float(cuts[ci])
		var c1 := float(cuts[ci + 1])
		if c1 - c0 < 0.005:
			continue
		var solid := [[0.0, H]]
		for sp: Array in removed_at(wi, 0.5 * (c0 + c1)):
			var nxt := []
			for so: Array in solid:
				if float(sp[1]) <= float(so[0]) or float(sp[0]) >= float(so[1]):
					nxt.append(so)
					continue
				if float(sp[0]) > float(so[0]):
					nxt.append([float(so[0]), float(sp[0])])
				if float(sp[1]) < float(so[1]):
					nxt.append([float(sp[1]), float(so[1])])
			solid = nxt
		for so: Array in solid:
			var sy := float(so[1]) - float(so[0])
			if sy < 0.01:
				continue
			var cs := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = Vector3(c1 - c0, sy, T)
			cs.shape = sh
			cs.position = (w.a_local as Vector3) + (w.dir_local as Vector3) * (0.5 * (c0 + c1)) + Vector3.UP * (0.5 * (float(so[0]) + float(so[1])))
			if meta != null:
				cs.set_meta(&"trav", (meta as Dictionary).duplicate())
			body.add_child(cs)


## A palisade log with openings: its instance hidden, its solid spans shown as pieces.
func _show_log(wi: int, lg: Dictionary) -> void:
	var mm: MultiMesh = lg.mm
	if mm == null or materials.is_empty():
		return
	for pc: Node in lg.pieces:
		if is_instance_valid(pc):
			pc.queue_free()
	lg.pieces = []
	var i := int(lg.i)
	if not lg.has("xf"):
		lg["xf"] = mm.get_instance_transform(i)
		lg["cd"] = mm.get_instance_custom_data(i)
	var t: Transform3D = lg.xf
	mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), t.origin))
	var sy := t.basis.y.length()
	var base := float((frame(wi)[0] as Vector3).y)
	# (mesh space: base -0.15, apex PALISADE_H; a world height y is (y - origin.y) / sy there)
	var spans := [[-0.15, StructureGeometry.PALISADE_H]]
	var removed := removed_at(wi, float(lg.u), true)
	if removed.is_empty():
		# (repaired: the log as it was)
		mm.set_instance_transform(i, t)
		return
	for sp: Array in removed:
		var m0 := (float(sp[0]) + base - t.origin.y) / sy
		var m1 := (float(sp[1]) + base - t.origin.y) / sy
		if float(sp[0]) <= 0.001:
			m0 = -0.2
		var nxt := []
		for so: Array in spans:
			if m1 <= float(so[0]) or m0 >= float(so[1]):
				nxt.append(so)
				continue
			if m0 > float(so[0]):
				nxt.append([float(so[0]), m0])
			if m1 < float(so[1]):
				nxt.append([m1, float(so[1])])
		spans = nxt
	for so: Array in spans:
		if float(so[1]) - float(so[0]) < 0.03:
			continue
		var mesh := StructureGeometry.palisade_log_piece(int(lg.variant), materials, float(so[0]), float(so[1]))
		var m := MultiMesh.new()
		m.transform_format = MultiMesh.TRANSFORM_3D
		m.use_custom_data = true
		m.mesh = mesh
		m.instance_count = 1
		m.set_instance_transform(0, t)
		m.set_instance_custom_data(0, lg.cd)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "CutLog"
		mmi.multimesh = m
		add_child(mmi)
		(lg.pieces as Array).append(mmi)
