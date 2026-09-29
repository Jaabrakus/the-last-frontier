class_name BuildWorld
extends Node3D
## Everything the player has built (scripts/building/): the BuiltPiece nodes under one "Building" node of the
## level, their ids, lookups round a point, what rests on what, and the context each piece's look depends on
## (ctx_for). Adding or taking down a piece re-dresses its neighbours (a corner notches, a floor edge becomes
## shared, a roof end loses its overhang) and keeps the grass out from under the new floors and walls (BuildGrass).
##
##   var w := BuildWorld.of(get_tree())                  # made under the current scene on first use
##   var p := w.add_piece("wall", xf, true, -1)          # on the ground, resting on nothing
##   w.dependents(p)                                     # pieces resting on it
##   w.remove_piece(p)
##
## Saved with the game (SaveParts.save_building / load_building).

signal changed

const NODE_NAME := "Building"
const G := preload("res://scripts/building/build_geometry.gd")
const WALLS := ["wall", "wall_window", "wall_door"]

var next_id := 1
## Riven-shingle courses on the roofs (off: the flat shingle deck of the low preset, like the fort).
var detail := true
var grass := BuildGrass.new()
## The fort's furnishing (FortPlan) has been built into this world (saved: a loaded game is not given it twice).
var stamped := false
## The fort's structure (FortPlan: palisade, gate, firing step, ramps, ladders, blockhouses, flag pole) has been built into
## this world (saved: a loaded game is not given it twice; a save from before it existed is given it).
var fort_built := false
## Strokes done on the palisade pieces being cut (PalisadeCuts): key -> work.
var cut_work := {}


## The level's building node (made under the current scene when `create`).
static func of(tree: SceneTree, create := true) -> BuildWorld:
	var scene := tree.current_scene if tree else null
	if scene == null:
		return null
	var w := scene.get_node_or_null(NODE_NAME) as BuildWorld
	if w == null and create:
		w = BuildWorld.new()
		w.name = NODE_NAME
		var st: Node = scene.get_node_or_null("Structures")
		if st and st.get("detail") != null:
			w.detail = bool(st.get("detail"))
		scene.add_child(w)
	return w


func _exit_tree() -> void:
	BuildGeometry.release()
	PalisadeCuts.release()


func _process(_delta: float) -> void:
	grass.flush(self)


func pieces() -> Array[BuiltPiece]:
	var out: Array[BuiltPiece] = []
	for c in get_children():
		if c is BuiltPiece and not c.is_queued_for_deletion():
			out.append(c)
	return out


## Pieces whose origin is within `r` (m) of `p`.
func near(p: Vector3, r: float) -> Array[BuiltPiece]:
	var out: Array[BuiltPiece] = []
	var r2 := r * r
	for c in get_children():
		if c is BuiltPiece and not c.is_queued_for_deletion() and (c as BuiltPiece).global_position.distance_squared_to(p) <= r2:
			out.append(c)
	return out


func by_id(id: int) -> BuiltPiece:
	for p in pieces():
		if p.piece_id == id:
			return p
	return null


## Pieces resting on `piece` (its dependents must come down first).
func dependents(piece: BuiltPiece) -> Array[BuiltPiece]:
	var out: Array[BuiltPiece] = []
	for p in pieces():
		if p != piece and p.supports.has(piece.piece_id):
			out.append(p)
	return out


## Whether a wall's top runs through `point` along `dir` (a roof bay's far eave has something under it).
func has_wall_top(point: Vector3, dir: Vector3) -> bool:
	return wall_top_at(point, dir) != null


## The wall whose top's middle is at `point`, running along `dir` (null: none).
func wall_top_at(point: Vector3, dir: Vector3) -> BuiltPiece:
	for p in near(point, G.L):
		if not p.type in WALLS:
			continue
		var top := p.global_transform * Vector3(0, G.WALL_H, 0)
		if top.distance_to(point) < 0.3 and absf(p.global_transform.basis.x.normalized().dot(dir.normalized())) > 0.9:
			return p
	return null


## What a `type` at `xf` rests on: the piece of the socket it snapped to (`support`, -1: none) and, for a roof
## bay, the walls under both its eaves.
func supports_for(type: String, xf: Transform3D, support: int) -> Array[int]:
	var out: Array[int] = []
	if support >= 0:
		out.append(support)
	if type == "roof":
		for sz: float in [-1.0, 1.0]:
			var w := wall_top_at(xf * Vector3(0, 0, sz * G.L * 0.5), xf.basis.x)
			if w and not out.has(w.piece_id):
				out.append(w.piece_id)
	return out


# --- Adding and taking down ---------------------------------------------------------------------------------

## Builds `type` at `xf` (`support`: the id of the piece whose socket it snapped to, -1 none; see supports_for).
func add_piece(type: String, xf: Transform3D, grounded: bool, support: int, ground := PackedFloat32Array()) -> BuiltPiece:
	var p := BuiltPiece.new()
	p.type = type
	p.piece_id = next_id
	next_id += 1
	p.variant = p.piece_id % 3
	p.grounded = grounded
	p.ground = ground
	p.supports = supports_for(type, xf, support)
	p.name = "%s_%d" % [type, p.piece_id]
	add_child(p)
	p.global_transform = xf
	p.dress(ctx_for(type, xf, grounded, p.piece_id, ground), detail)
	_redress_near(xf.origin, p)
	grass.mark()
	changed.emit()
	return p


func remove_piece(p: BuiltPiece) -> void:
	if p == null or not is_instance_valid(p):
		return
	var at := p.global_position
	remove_child(p)
	p.queue_free()
	_redress_near(at, null)
	grass.mark()
	changed.emit()


## Re-dresses the pieces round `at` whose context changed (not `skip`, just dressed).
func _redress_near(at: Vector3, skip: BuiltPiece) -> void:
	for q in near(at, G.L * 1.6):
		if q == skip or not (q.type in WALLS or q.type in ["floor", "roof"]):
			continue
		var c := ctx_for(q.type, q.global_transform, q.grounded, q.piece_id, q.ground)
		if c != q.ctx:
			q.dress(c, detail)


# --- Context ------------------------------------------------------------------------------------------------

## What the look of `type` at `xf` depends on (see BuildGeometry): `self_id` is the piece's own id (-1 for a
## ghost: it is the newest), `ground` a palisade's heights under its stakes.
func ctx_for(type: String, xf: Transform3D, grounded: bool, self_id := -1, ground := PackedFloat32Array()) -> Dictionary:
	match type:
		"wall", "wall_window", "wall_door":
			var c := {"p": G.parity_of(xf.basis.get_euler().y), "e0": _end_state(xf, -1.0, self_id),
					"e1": _end_state(xf, 1.0, self_id), "g": grounded}
			if type == "wall_door":
				c["st"] = [_step_down(xf, 1.0), _step_down(xf, -1.0)]
			return c
		"post":
			return {"g": grounded}
		"floor":
			var sill: Array = []
			var foot: Array = []
			for d: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
				var n := _floor_at(xf * (d * G.L), self_id)
				foot.append(n == null)
				sill.append(n == null or (self_id >= 0 and n.piece_id > self_id))
			return {"sill": sill, "foot": foot}
		"roof":
			var o := G.T * 0.5 + G.GABLE_OVER
			return {"o0": 0.0 if _roof_at(xf * Vector3(-G.L, 0, 0), xf.basis.x, self_id) else o,
					"o1": 0.0 if _roof_at(xf * Vector3(G.L, 0, 0), xf.basis.x, self_id) else o}
		"palisade":
			if ground.size() < 2:
				return {"gy": [0.0, 0.0], "gmin": 0.0}
			var lo := INF
			for v in ground:
				lo = minf(lo, v)
			return {"gy": [ground[0], ground[ground.size() - 1]], "gmin": lo}
		"palisade_gate":
			if ground.size() < 2:
				return {"gy": [0.0, 0.0]}
			return {"gy": [ground[0], ground[1]]}
	return {}


## A wall end's state (`sx` -1: the -X end, 1: the +X end): "post", "inline", "corner", "tee" or "free".
func _end_state(xf: Transform3D, sx: float, self_id: int) -> String:
	var e := xf * Vector3(sx * G.L * 0.5, 0, 0)
	var dir := xf.basis.x.normalized()
	var inline := 0
	var perp := 0
	var tee := false
	for p in near(e, G.L):
		if p.piece_id == self_id:
			continue
		var q := p.global_transform
		if absf(q.origin.y - e.y) > 0.15:
			continue
		if p.type == "post":
			if Vector2(q.origin.x - e.x, q.origin.z - e.z).length() < 0.12:
				return "post"
			continue
		if not p.type in WALLS:
			continue
		var at_end := false
		for s: float in [-1.0, 1.0]:
			if (q * Vector3(s * G.L * 0.5, 0, 0)).distance_to(e) < 0.12:
				at_end = true
				if absf(q.basis.x.normalized().dot(dir)) > 0.9:
					inline += 1
				else:
					perp += 1
		if not at_end:
			var loc := q.affine_inverse() * e
			if absf(loc.x) < G.L * 0.5 - 0.1 and absf(loc.z) < G.T:
				tee = true
	if inline > 0:
		return "inline"
	if perp == 1 and not tee:
		return "corner"
	if perp > 1 or tee:
		return "tee"
	return "free"


## How far the ground in front of a doorway (the `side` +1 / -1 face) lies below its threshold: 0 over a floor at
## the threshold's height, else the terrain's drop (to 5 cm, at most FLOOR_FOOTING + FLOOR_H): the door's steps.
func _step_down(xf: Transform3D, side: float) -> float:
	var q := xf * Vector3(0, 0, side * 0.9)
	for p in near(q, G.L):
		if p.type != "floor":
			continue
		var loc := p.global_transform.affine_inverse() * q
		if absf(loc.x) <= G.L * 0.5 + G.T * 0.5 and absf(loc.z) <= G.L * 0.5 + G.T * 0.5 and absf(loc.y - G.FLOOR_H) < 0.1:
			return 0.0
	var h := xf.origin.y - FrontierTerrain.height_at(q.x, q.z)
	return clampf(snappedf(h, 0.05), 0.0, G.FLOOR_FOOTING + G.FLOOR_H)


func _floor_at(c: Vector3, self_id: int) -> BuiltPiece:
	for p in near(c, 0.25):
		if p.type == "floor" and p.piece_id != self_id and absf(p.global_position.y - c.y) < 0.06:
			return p
	return null


func _roof_at(c: Vector3, ridge: Vector3, self_id: int) -> bool:
	for p in near(c, 0.25):
		if p.type == "roof" and p.piece_id != self_id and absf(p.global_transform.basis.x.normalized().dot(ridge.normalized())) > 0.9:
			return true
	return false
