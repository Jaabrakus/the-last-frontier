class_name BuildSnap
extends RefCounted
## Where a piece goes and whether it can go there (scripts/building/).
##
## Sockets: every placed piece offers sockets (a kind and a frame, sockets_local()): a floor its four edges
## (walls), four corners (posts) and four sides (the next floor); a wall its two ends (the next wall in line or
## round a corner, a post), its top (a gable, a roof bay, a wall above) and its two faces (a hearth); a post its
## four sides (walls); a roof bay its two ends along the ridge (the next bay); a palisade section or gate its
## two ends (the next section, in line or round a corner). attach() says which socket kinds a piece takes and
## where it sits in the socket's frame (several choices: in line, round the corner either way). R flips a
## snapped wall, gable, roof or palisade end for end (the door opens the other way).
## Grid: a piece that can stand on its own and finds no socket goes on the ground under the crosshair, on a
## 0.25 m grid, turned to face the camera in 15 degree steps (R adds 90 degrees).
##
## check() then says whether it can be built: the ground under it (a floor's footing reaches 1 m down, a wall's
## 0.7 m, a palisade's stakes follow the ground), nothing in the way (inner boxes of the pieces against each
## other, SAT; the world's trees, rocks, buildings, the player and the horse by a physics query of the same
## boxes), and the logs and stone in the pack.

const G := preload("res://scripts/building/build_geometry.gd")
const WALLS := ["wall", "wall_window", "wall_door"]
## Pieces R flips end for end when snapped.
const FLIPS := ["wall", "wall_window", "wall_door", "gable", "roof", "palisade", "palisade_gate", "walkway"]
## Pieces that may pass through each other (a chimney stack through the roof).
const OVERLAP_OK := {"hearth": ["roof", "gable"], "roof": ["hearth"], "gable": ["hearth"],
		"drying_rack": ["campfire"], "campfire": ["drying_rack"]}
## The furniture and stations (BuildGeometry's beds, racks and stations): footprint half extents (x, z) and the most
## the ground may fall away under them.
const FOOT := {"bough_bed": [Vector2(0.5, 1.0), 0.3], "pole_bed": [Vector2(0.48, 0.98), 0.25],
		"musket_rack": [Vector2(0.9, 0.25), 0.3], "spear_barrel": [Vector2(0.24, 0.24), 0.2],
		"drying_rack": [Vector2(1.05, 0.45), 0.5], "tanning_frame": [Vector2(1.3, 0.7), 0.45],
		"alchemy_table": [Vector2(0.64, 0.29), 0.2], "workbench": [Vector2(0.8, 0.3), 0.2],
		"stretching_hoop": [Vector2(0.4, 0.35), 0.5], "storage_chest": [Vector2(0.42, 0.22), 0.15], "cradle": [Vector2(0.27, 0.48), 0.15],
		"woodpile": [Vector2(0.95, 0.28), 0.3], "boat_stand": [Vector2(0.9, 2.9), 0.5], "smokehouse": [Vector2(1.0, 0.9), 0.35]}
## Socket kinds a snapped piece rests on: taking the socket's piece down needs this one gone first.
const SUPPORTING := ["edge", "corner", "wall_top", "roof_end"]
## Socket kinds whose piece stands on the ground like the socket's own piece.
const SAME_GROUND := ["wall_end", "post_side", "pal_end", "pal_inside", "walk_end", "walk_front"]
## Candidates check() is tried on per frame (best first; the first that can be built wins).
const MAX_CANDIDATES := 6
## Score bias per socket kind: where two sockets put a piece in the same place (a wall on a floor's edge or at the
## end of the wall round the corner), the floor's wins (it faces the wall out and the wall rests on the floor).
const KIND_BIAS := {"edge": -0.1, "corner": -0.1}


# --- Sockets, attachments, boxes --------------------------------------------------------------------------

## A piece's sockets in its own frame: [[kind, Transform3D]] (the frame's +Z points away from the piece).
static func sockets_local(type: String) -> Array:
	var out: Array = []
	var h := G.L * 0.5
	match type:
		"floor":
			for k in 4:
				var b := Basis(Vector3.UP, k * PI * 0.5)
				out.append(["edge", Transform3D(b, b.z * h + Vector3.UP * G.FLOOR_H)])
				out.append(["floor_side", Transform3D(b, b.z * h)])
				out.append(["corner", Transform3D(b, (b.z + b.x) * h + Vector3.UP * G.FLOOR_H)])
		"wall", "wall_window", "wall_door":
			out.append(["wall_end", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(h, 0, 0))])
			out.append(["wall_end", Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-h, 0, 0))])
			out.append(["wall_top", Transform3D(Basis(), Vector3(0, G.WALL_H, 0))])
			out.append(["wall_face", Transform3D(Basis(), Vector3(0, 0, G.T * 0.5))])
			out.append(["wall_face", Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -G.T * 0.5))])
		"post":
			for k in 4:
				out.append(["post_side", Transform3D(Basis(Vector3.UP, k * PI * 0.5), Vector3.ZERO)])
		"roof":
			out.append(["roof_end", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(h, 0, 0))])
			out.append(["roof_end", Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-h, 0, 0))])
		"palisade", "palisade_gate":
			out.append(["pal_end", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(h, 0, 0))])
			out.append(["pal_end", Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-h, 0, 0))])
	out.append_array(FortPieces.sockets(type))
	return out


## The socket kinds a piece takes: {kind: [Transform3D of the piece in the socket's frame]}.
static func attach(type: String) -> Dictionary:
	if FortPieces.is_fort_piece(type):
		return FortPieces.attach(type)
	var h := G.L * 0.5
	var inline := Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0, 0, h))
	var round_a := Transform3D(Basis(), Vector3(h, 0, 0))
	var round_b := Transform3D(Basis(), Vector3(-h, 0, 0))
	var here := Transform3D.IDENTITY
	match type:
		"floor":
			return {"floor_side": [Transform3D(Basis(), Vector3(0, 0, h))]}
		"wall", "wall_window", "wall_door":
			return {"edge": [here], "wall_end": [inline, round_a, round_b], "post_side": [inline], "wall_top": [here]}
		"post":
			return {"corner": [here], "wall_end": [here]}
		"gable":
			return {"wall_top": [here]}
		"roof":
			return {"wall_top": [Transform3D(Basis(), Vector3(0, 0, h)), Transform3D(Basis(), Vector3(0, 0, -h))], "roof_end": [inline]}
		"hearth":
			return {"wall_face": [here]}
		"palisade", "palisade_gate":
			return {"pal_end": [inline, round_a, round_b]}
	return {}


## Boxes well inside a piece (its frame): [[Transform3D centre, Vector3 half extents]]. Two pieces overlap when
## these do; sockets put pieces side by side without it (walls at a corner, a wall on a floor, a post at a wall's
## end, a gable beside a roof bay).
static func inner_local(type: String) -> Array:
	if FortPieces.is_fort_piece(type):
		return FortPieces.inner(type)
	match type:
		"floor":
			return [[Transform3D(Basis(), Vector3(0, G.FLOOR_H * 0.5, 0)), Vector3(1.4, G.FLOOR_H * 0.5 - 0.03, 1.4)]]
		"wall", "wall_window", "wall_door":
			return [[Transform3D(Basis(), Vector3(0, G.WALL_H * 0.5, 0)), Vector3(1.3, G.WALL_H * 0.5 - 0.1, 0.1)]]
		"post":
			return [[Transform3D(Basis(), Vector3(0, G.WALL_H * 0.5, 0)), Vector3(0.1, G.WALL_H * 0.5 - 0.1, 0.1)]]
		"gable":
			return [[Transform3D(Basis(), Vector3(0, 0.35, 0)), Vector3(1.0, 0.25, 0.1)]]
		"roof":
			# the ridge, and over each eave's wall top (a gable or a wall standing there is in the way)
			return [[Transform3D(Basis(), Vector3(0, 0.85, 0)), Vector3(1.3, 0.3, 0.25)],
					[Transform3D(Basis(), Vector3(0, 0.25, G.L * 0.5)), Vector3(1.2, 0.12, 0.08)],
					[Transform3D(Basis(), Vector3(0, 0.25, -G.L * 0.5)), Vector3(1.2, 0.12, 0.08)]]
		"hearth":
			return [[Transform3D(Basis(), Vector3(0, 0.75, 0.47)), Vector3(0.65, 0.6, 0.38)],
					[Transform3D(Basis(), Vector3(0, 3.6, 0.47)), Vector3(0.3, 1.4, 0.25)]]
		"campfire":
			return [[Transform3D(Basis(), Vector3(0, 0.25, 0)), Vector3(0.55, 0.25, 0.55)]]
		"lean_to":
			# under the slope (open at the front, +Z) and the two posts
			return [[Transform3D(Basis(), Vector3(0, 0.6, -G.LEAN_D * 0.5)), Vector3(G.LEAN_W * 0.5 - 0.1, 0.5, G.LEAN_D * 0.5 - 0.15)],
					[Transform3D(Basis(), Vector3(0, G.LEAN_H * 0.5, 0)), Vector3(G.LEAN_W * 0.5 - 0.1, G.LEAN_H * 0.5 - 0.1, 0.08)]]
		"bough_bed":
			return [[Transform3D(Basis(), Vector3(0, 0.16, 0)), Vector3(G.BOUGH_W * 0.5 + 0.08, 0.1, G.BED_L * 0.5)]]
		"pole_bed":
			return [[Transform3D(Basis(), Vector3(0, 0.3, 0)), Vector3(G.POLE_BED_W * 0.5, 0.24, G.BED_L * 0.5)]]
		"musket_rack":
			return [[Transform3D(Basis(), Vector3(0, 0.66, -0.05)), Vector3(WeaponRack.rack_span(G.RACK_SLOTS) * 0.5, 0.58, 0.16)]]
		"spear_barrel":
			return [[Transform3D(Basis(), Vector3(0, 0.34, 0)), Vector3(G.BARREL_R, 0.28, G.BARREL_R)]]
		"drying_rack":
			# the four posts (a fire may burn under it)
			var out: Array = []
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					out.append([Transform3D(Basis(), Vector3(sx * (G.DRY_W * 0.5 - 0.05), 0.8, sz * (G.DRY_D * 0.5 - 0.05))), Vector3(0.06, 0.7, 0.06)])
			return out
		"boat_stand":
			return [[Transform3D(Basis(), Vector3(0, 0.1, 0)), Vector3(0.8, 0.1, G.BOAT_L * 0.5)]]
		"tanning_frame":
			return [[Transform3D(Basis(), Vector3(0, 1.0, -0.2)), Vector3(G.TAN_W * 0.5, 0.9, 0.45)],
					[Transform3D(Basis(), Vector3(G.TAN_W * 0.5 + 0.45, 0.5, 0.25)), Vector3(0.14, 0.42, 0.6)]]
		"alchemy_table":
			return [[Transform3D(Basis(), Vector3(0, 0.5, 0)), Vector3(G.TABLE_W * 0.5, 0.45, G.TABLE_D * 0.5)]]
		"workbench":
			return [[Transform3D(Basis(), Vector3(0, 0.45, 0)), Vector3(G.BENCH_W * 0.5, 0.4, G.BENCH_D * 0.5)]]
		"stretching_hoop":
			return [[Transform3D(Basis(), Vector3(0, 0.9, -0.1)), Vector3(G.HOOP_R, 0.7, 0.3)]]
		"storage_chest":
			return [[Transform3D(Basis(), Vector3(0, 0.26, 0)), Vector3(G.CHEST_W * 0.5, 0.22, G.CHEST_D * 0.5)]]
		"cradle":
			return [[Transform3D(Basis(), Vector3(0, 0.22, 0)), Vector3(G.CRADLE_W * 0.5, 0.2, G.CRADLE_L * 0.5)]]
		"woodpile":
			return [[Transform3D(Basis(), Vector3(0, 0.5, 0)), Vector3(G.WOOD_L * 0.5 + 0.05, 0.45, G.WOOD_D * 0.5)]]
		"smokehouse":
			return [[Transform3D(Basis(), Vector3(0, 1.1, 0)), Vector3(G.SMOKE_W * 0.5, 1.0, G.SMOKE_D * 0.5)]]
		"palisade":
			return [[Transform3D(Basis(), Vector3(0, 1.8, 0)), Vector3(1.3, 1.2, 0.12)]]
		"palisade_gate":
			return [[Transform3D(Basis(), Vector3(-G.GATE_POST_X, 2.0, 0)), Vector3(0.12, 1.4, 0.12)],
					[Transform3D(Basis(), Vector3(G.GATE_POST_X, 2.0, 0)), Vector3(0.12, 1.4, 0.12)],
					[Transform3D(Basis(), Vector3(0, 1.8, 0)), Vector3(0.95, 1.2, 0.1)]]
	return []


## A point in the middle of the piece (its frame): what the crosshair is matched against.
static func center_local(type: String) -> Vector3:
	if FortPieces.is_fort_piece(type):
		return FortPieces.center(type)
	match type:
		"floor":
			return Vector3(0, 0.2, 0)
		"gable":
			return Vector3(0, 0.5, 0)
		"roof":
			return Vector3(0, 0.6, 0)
		"hearth":
			return Vector3(0, 1.0, 0.5)
		"campfire":
			return Vector3(0, 0.2, 0)
		"lean_to":
			return Vector3(0, 0.9, -G.LEAN_D * 0.4)
		"bough_bed":
			return Vector3(0, 0.15, 0)
		"pole_bed":
			return Vector3(0, 0.35, 0)
		"musket_rack":
			return Vector3(0, 0.7, -0.05)
		"spear_barrel":
			return Vector3(0, 0.35, 0)
		"drying_rack":
			return Vector3(0, 1.0, 0)
		"boat_stand":
			return Vector3(0, 0.6, 0)
		"tanning_frame":
			return Vector3(0, 1.0, 0)
		"alchemy_table":
			return Vector3(0, 0.6, 0)
		"workbench":
			return Vector3(0, 0.75, 0)
		"stretching_hoop":
			return Vector3(0, 1.05, 0)
		"storage_chest":
			return Vector3(0, 0.35, 0)
		"cradle":
			return Vector3(0, 0.25, 0)
		"woodpile":
			return Vector3(0, 0.5, 0)
		"smokehouse":
			return Vector3(0, 1.2, G.SMOKE_D * 0.5)
		"palisade":
			return Vector3(0, 1.5, 0)
		"palisade_gate":
			return Vector3(0, 1.8, 0)
	return Vector3(0, 1.3, 0)


## Separating-axis test of two oriented boxes (centre frames `a` / `b`, half extents `ha` / `hb`).
static func obb_overlap(a: Transform3D, ha: Vector3, b: Transform3D, hb: Vector3) -> bool:
	var ax := [a.basis.x.normalized(), a.basis.y.normalized(), a.basis.z.normalized()]
	var bx := [b.basis.x.normalized(), b.basis.y.normalized(), b.basis.z.normalized()]
	var d := b.origin - a.origin
	var axes: Array = []
	axes.append_array(ax)
	axes.append_array(bx)
	for i in 3:
		for j in 3:
			var c: Vector3 = (ax[i] as Vector3).cross(bx[j])
			if c.length_squared() > 1e-8:
				axes.append(c.normalized())
	for n: Vector3 in axes:
		var ra := absf(n.dot(ax[0])) * ha.x + absf(n.dot(ax[1])) * ha.y + absf(n.dot(ax[2])) * ha.z
		var rb := absf(n.dot(bx[0])) * hb.x + absf(n.dot(bx[1])) * hb.y + absf(n.dot(bx[2])) * hb.z
		if absf(n.dot(d)) > ra + rb:
			return false
	return true


# --- Where it goes ------------------------------------------------------------------------------------------

## The snapped placements near the crosshair point `aim`, best first: [{xf, kind, support (piece id), grounded,
## score}], only those within `radius` (score: horizontal distance of the piece's middle from `aim` plus half
## the height difference; a roof bay with a wall under its far eave too scores 1 better).
static func candidates(type: String, world: BuildWorld, aim: Vector3, radius: float, flip := false) -> Array:
	var att := attach(type)
	var out: Array = []
	if world == null or att.is_empty():
		return out
	var c_local := center_local(type)
	for p: BuiltPiece in world.near(aim, radius + G.L * 2.0):
		var pxf := p.global_transform
		for s: Array in sockets_local(p.type):
			var kind := String(s[0])
			if not att.has(kind):
				continue
			var sxf: Transform3D = pxf * (s[1] as Transform3D)
			for off: Transform3D in att[kind]:
				var xf := sxf * off
				xf.basis = xf.basis.orthonormalized()
				# in line off either end: the same way round as the piece it continues (the socket frames of the
				# two ends face opposite ways, so off the -X end the in-line frame comes out turned end for end)
				if off.origin.z > 0.0 and kind in ["wall_end", "pal_end", "roof_end", "walk_end"] and xf.basis.z.dot(pxf.basis.z) < 0.0:
					xf.basis = xf.basis * Basis(Vector3.UP, PI)
				var ref := xf * c_local
				var dd := Vector2(ref.x - aim.x, ref.z - aim.z).length() + 0.5 * absf(ref.y - aim.y) + float(KIND_BIAS.get(kind, 0.0))
				# a roof bay over the side of the wall where another wall carries its far eave
				if type == "roof" and kind == "wall_top" and world.has_wall_top(sxf * Vector3(0, 0, 2.0 * off.origin.z), sxf.basis.x):
					dd -= 1.0
				if dd > radius:
					continue
				if flip and type in FLIPS:
					xf.basis = xf.basis * Basis(Vector3.UP, PI)
				var grounded := true if kind == "floor_side" else (p.grounded if kind in SAME_GROUND else false)
				out.append({"xf": xf, "kind": kind, "support": p.piece_id if kind in SUPPORTING else -1,
						"grounded": grounded, "score": dd})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.score) < float(y.score))
	return out


## The placement on the ground at `aim` (no socket): on the grid, facing the camera (`view_yaw`: the camera's
## yaw), plus `steps` quarter turns. A grid or yaw step of 0: exactly there, at any angle (BuildMode without Alt).
static func free_xf(aim: Vector3, view_yaw: float, steps: int, grid: float, yaw_step: float) -> Transform3D:
	var yaw := snappedf(view_yaw + steps * PI * 0.5, yaw_step)
	var p := Vector3(snappedf(aim.x, grid), aim.y, snappedf(aim.z, grid))
	return Transform3D(Basis(Vector3.UP, yaw), p)


# --- Whether it can be built ------------------------------------------------------------------------------

## Whether `type` can be built at candidate `cand` ({xf, kind ("" on the ground), grounded, ...}):
## {ok, reason, xf (height settled on the ground), ground (a palisade's stake heights over its origin), grounded}.
## `have`: {item: count} in the pack; `exclude`: RIDs the physics queries skip (the player is NOT among them: the
## player standing where the piece goes is in the way).
static func check(type: String, cand: Dictionary, world: BuildWorld, space: PhysicsDirectSpaceState3D, have: Dictionary,
		data: BuildData, exclude: Array[RID] = []) -> Dictionary:
	var xf: Transform3D = cand.xf
	var kind := String(cand.get("kind", ""))
	var grounded := bool(cand.get("grounded", true))
	var res := {"ok": false, "reason": "", "xf": xf, "ground": PackedFloat32Array(), "grounded": grounded}
	if kind == "" and not data.free_standing(type):
		res.reason = "Needs a wall to sit on" if type in ["gable", "roof"] else "Needs something to stand on"
		return res
	# Rays for the ground skip the pieces round it (a hearth stands on a floor, the rest on the ground).
	var skip: Array[RID] = exclude.duplicate()
	if type != "hearth" and world:
		for p: BuiltPiece in world.near(xf.origin, G.L * 3.0):
			if p.type == "floor" and data.on_floor(type):
				continue                                   # furniture stands on a floor too
			skip.append_array(p.body_rids())
	var g := _ground(type, xf, kind, grounded, space, skip)
	if g.has("reason"):
		res.reason = g.reason
		return res
	xf = g.xf
	res.xf = xf
	res.ground = g.get("ground", PackedFloat32Array())
	# Pieces in the way (their inner boxes).
	var mine := inner_local(type)
	if world:
		for p: BuiltPiece in world.near(xf.origin, G.L * 2.5):
			var pt := p.type
			if (OVERLAP_OK.get(type, []) as Array).has(pt):
				continue
			for a: Array in mine:
				for b: Array in inner_local(pt):
					if obb_overlap(xf * (a[0] as Transform3D), a[1], p.global_transform * (b[0] as Transform3D), b[1]):
						res.reason = "The %s is in the way" % data.name_of(pt).to_lower()
						return res
	# The world in the way: trees, rocks, the fort, the player, the horse.
	for a: Array in mine:
		var hit := _blocker(space, xf * (a[0] as Transform3D), a[1], exclude)
		if hit != "":
			res.reason = hit
			return res
	# The pack.
	var c := data.cost(type)
	for k: String in c:
		var short := int(c[k]) - int(have.get(k, 0))
		if short > 0:
			res.reason = "Needs %d more %s" % [short, _item_word(k, short)]
			return res
	res.ok = true
	return res


## The ground under the piece: {xf (height settled), ground} or {reason}.
static func _ground(type: String, xf: Transform3D, kind: String, grounded: bool, space: PhysicsDirectSpaceState3D,
		skip: Array[RID]) -> Dictionary:
	var free := kind == ""
	var o := xf.origin
	match type:
		"floor":
			var pts: Array = []
			for sx: float in [-1.25, 0.0, 1.25]:
				for sz: float in [-1.25, 0.0, 1.25]:
					pts.append(Vector3(sx, 0, sz))
			var ys := _samples(xf, pts, space, skip, 2.0 if free else 1.2, G.FLOOR_FOOTING + 1.0)
			if ys.is_empty():
				return {"reason": "No ground under it"}
			var hi: float = ys.max()
			var lo: float = ys.min()
			if free:
				o.y = hi
			if hi > o.y + G.FLOOR_H - 0.05:
				return {"reason": "The ground rises into the floor"}
			if lo < o.y - G.FLOOR_FOOTING + 0.1:
				return {"reason": "Too steep: the footing would not reach the ground"}
		"wall", "wall_window", "wall_door", "post":
			if not grounded:
				return {"xf": xf}
			var pts: Array = [Vector3.ZERO] if type == "post" else [Vector3(-1.35, 0, 0), Vector3(0, 0, 0), Vector3(1.35, 0, 0)]
			var ys := _samples(xf, pts, space, skip, 2.0 if free else 1.0, G.FOOTING + 1.0)
			if ys.is_empty():
				return {"reason": "No ground under it"}
			var hi: float = ys.max()
			var lo: float = ys.min()
			var depth := G.POST_SINK if type == "post" else G.FOOTING
			if free:
				o.y = hi
			if hi > o.y + 0.3:
				return {"reason": "The ground rises too high here"}
			if lo < o.y - depth + 0.1:
				return {"reason": "Too steep: the footing would not reach the ground"}
		"hearth":
			var pts: Array = [Vector3(-0.7, 0, 0.1), Vector3(0.7, 0, 0.1), Vector3(-0.7, 0, 1.4), Vector3(0.7, 0, 1.4)]
			var ys := _samples(xf, pts, space, skip, 2.0 if free else 0.6, G.HEARTH_SINK + 1.0)
			if ys.is_empty():
				return {"reason": "No ground under it"}
			var hi: float = ys.max()
			var lo: float = ys.min()
			if free:
				o.y = hi
			if hi > o.y + 0.15:
				return {"reason": "The ground rises too high here"}
			if lo < o.y - G.HEARTH_SINK + 0.1:
				return {"reason": "Too steep here"}
		"campfire", "lean_to":
			# the ring's stones, or the lean-to's two posts and the foot of its slope, on the ground; the piece sits at
			# the highest (a stone or a post end a little into lower ground)
			var pts: Array
			if type == "campfire":
				pts = [Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0), Vector3(0, 0, -0.5), Vector3(0, 0, 0.5), Vector3.ZERO]
			else:
				pts = [Vector3(-G.LEAN_W * 0.45, 0, 0), Vector3(G.LEAN_W * 0.45, 0, 0), Vector3(-G.LEAN_W * 0.45, 0, -G.LEAN_D),
						Vector3(G.LEAN_W * 0.45, 0, -G.LEAN_D)]
			var ys := _samples(xf, pts, space, skip, 2.0 if free else 0.6, 2.0)
			if ys.is_empty():
				return {"reason": "No ground under it"}
			var hi: float = ys.max()
			var lo: float = ys.min()
			o.y = hi
			if hi - lo > (0.3 if type == "campfire" else 0.6):
				return {"reason": "Needs flatter ground"}
		"bough_bed", "pole_bed", "musket_rack", "spear_barrel", "drying_rack", "tanning_frame", "boat_stand", "alchemy_table", "workbench", \
				"stretching_hoop", "storage_chest", "cradle", "woodpile", "smokehouse", "walkway", "walkway_ramp", "ladder", "blockhouse", "flagpole":
			# the corners of its footprint and the middle on the ground (or a floor); it sits at the highest
			var f: Array = FOOT[type] if FOOT.has(type) else FortPieces.foot(type)
			var e: Vector2 = f[0]
			var pts: Array = [Vector3(-e.x, 0, -e.y), Vector3(e.x, 0, -e.y), Vector3(-e.x, 0, e.y), Vector3(e.x, 0, e.y), Vector3.ZERO]
			var ys := _samples(xf, pts, space, skip, 2.0 if free else 0.6, 2.0)
			if ys.is_empty():
				return {"reason": "No ground under it"}
			var hi: float = ys.max()
			var lo: float = ys.min()
			o.y = hi
			if hi - lo > float(f[1]):
				return {"reason": "Needs flatter ground"}
			if type == "boat_stand" and not _water_near(o):
				return {"reason": "Build it by the water"}
		"palisade", "palisade_gate":
			var pts: Array = []
			var dx := G.L / G.STAKES
			if type == "palisade":
				for i in G.STAKES:
					pts.append(Vector3(-G.L * 0.5 + dx * (i + 0.5), 0, 0))
			else:
				pts = [Vector3(-G.GATE_POST_X, 0, 0), Vector3(G.GATE_POST_X, 0, 0), Vector3(0, 0, 0)]
			var mid := _samples(xf, [Vector3.ZERO], space, skip, 2.5, 3.0)
			if mid.is_empty():
				return {"reason": "No ground under it"}
			o.y = float(mid[0])
			var probe := Transform3D(xf.basis, o)
			var ys := _samples(probe, pts, space, skip, 2.0, 3.0)
			if ys.is_empty():
				return {"reason": "No ground under it"}
			var rel := PackedFloat32Array()
			var lim := 0.35 if type == "palisade_gate" else 1.0
			for y: float in ys:
				if absf(y - o.y) > lim:
					return {"reason": "Needs level ground" if type == "palisade_gate" else "Too steep here"}
				rel.append(snappedf(y - o.y, 0.01))
			return {"xf": Transform3D(xf.basis, o), "ground": rel}
	return {"xf": Transform3D(xf.basis, o)}


## An item's name for "Needs 3 more logs" (log / logs, stone, firewood, pole / poles, branches).
static func _item_word(k: String, n: int) -> String:
	match k:
		"log":
			return "log" if n == 1 else "logs"
		"pole":
			return "pole" if n == 1 else "poles"
		"stone", "firewood", "branches":
			return k
	return InventoryState.name_of(k).to_lower()


## Ground heights (world y) under the points `pts` (the piece's frame): rays from `up` over to `down` under the
## origin's height; [] when one of them finds nothing (or a slope over 63 degrees).
static func _samples(xf: Transform3D, pts: Array, space: PhysicsDirectSpaceState3D, skip: Array[RID], up: float, down: float) -> Array:
	var out: Array = []
	for p: Vector3 in pts:
		var w := xf * p
		var q := PhysicsRayQueryParameters3D.create(Vector3(w.x, xf.origin.y + up, w.z), Vector3(w.x, xf.origin.y - down, w.z))
		var ex: Array[RID] = skip.duplicate()
		q.exclude = ex
		var hit := space.intersect_ray(q)
		# the player, the horse, a dropped item are not ground: look past them
		for k in 3:
			if hit.is_empty() or not (hit.collider is CharacterBody3D or hit.collider is RigidBody3D):
				break
			ex.append(hit.rid)
			q.exclude = ex
			hit = space.intersect_ray(q)
		if hit.is_empty() or (hit.normal as Vector3).y < 0.45:
			return []
		out.append(float((hit.position as Vector3).y))
	return out


## What in the world (not the ground, not a built piece, not a loose item) is inside the box: "" or the reason.
static func _blocker(space: PhysicsDirectSpaceState3D, xf: Transform3D, half: Vector3, exclude: Array[RID]) -> String:
	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = half * 2.0
	q.shape = box
	q.transform = xf
	q.exclude = exclude
	q.collide_with_areas = false
	for r: Dictionary in space.intersect_shape(q, 16):
		var c: Object = r.get("collider")
		if c == null or not (c is Node):
			continue
		var n := c as Node
		if n.is_in_group(&"terrain") or n.is_in_group(BuiltPiece.BODY_GROUP) or n is RigidBody3D:
			continue
		if n.is_in_group(&"trees"):
			return "A tree is in the way"
		if n.is_in_group(&"rocks") or String(n.name).begins_with("Rocks"):
			return "A rock is in the way"
		if n is Horse:
			return "The horse is in the way"
		if n is CharacterBody3D:
			return "You are standing in the way" if n.is_in_group(&"player") else "Someone is in the way"
		if n is StaticBody3D or n is AnimatableBody3D:
			return "Something is in the way"
	return ""


## Whether there is water deep enough for a boat within reach of `o` (a boat stand's launch: 3 to 14 m round it).
static func _water_near(o: Vector3) -> bool:
	for r in [3.0, 6.0, 9.0, 12.0, 14.0]:
		for k in 16:
			var a := TAU * float(k) / 16.0
			if WaterSurface.depth_at(o.x + sin(a) * float(r), o.z + cos(a) * float(r)) >= 0.5:
				return true
	return false
