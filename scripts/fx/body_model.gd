class_name BodyModel
extends RefCounted
## The body a shot goes through (the user, 2026-10-03, of another game's body viewer: "i want that to be how our game detects
## hits and etc they have a perfect skeleton mesh"): an anatomically fitted body under every person and animal, kept as data:
## the shapes of its bones, organs, vessels, spinal cord and flesh, each in the frame of the bone it rides, sized as the real
## one (BodyBuild fits them to the rig and to the body's own skin). Nothing runs per frame: a model is built once for a kind of
## body (shared by every body on the same rig and skin: of()) and read only when a hit is worked out (trace()) or a view of it
## is open (Anatomy's map, InspectView).
##
## The shapes, cheap to test a line against, each in its own frame (Y its long axis), sizes in metres:
##   cap    a capsule: radius s.x, half the length of its middle s.y (a long bone's shaft, a vessel, a rib's piece, the cord)
##   cyl    an elliptic cylinder, flat ended: radii s.x across, s.z front to back, half height s.y (a slab of the trunk's flesh)
##   ell    an ellipsoid, radii s (an organ, a joint's end of a bone, the head's flesh)
##   shell  an ellipsoid's shell, outer radii s, `th` thick (the skull round the brain: a ball crosses bone twice)
##   box    a box tapered along Y: half widths s.x, s.z at its foot, top.x, top.y at its head, half height s.y (the pelvis, a
##          shoulder blade, the sternum, a hand, a foot)
##
## A shot's path (trace): the line from where the round met the coarse hit collider (a little before it: what was in front
## counts), through every shape it crosses in order (one pass over the shapes near the line, a bounding sphere per bone
## first). Each tissue takes energy from the round, dE/dx = -(a + b E) (a: the tissue's strength, b: its drag; a ball's worked
## out from its size and mass, SHOTS), times the tissue's own (TISSUE: a lung little, bone most); a bone also costs its break
## (brk, J) and a lead ball flattens on it (FLATTEN); the skin costs its own going in and out. The round goes on until it
## leaves the body (an exit) or has nothing left (it stops inside: in a bone, an organ, under the skin). The record says where
## it went in, where it came out or stopped, and what it crossed in order with what it did to each ("fractured", "punctured",
## "cut"), the energy at each, and every point anchored on the bone it rides (so it moves with the body after: anchor()).

## The rounds (Hit.shot's kind): its mass when the shot does not say (kg), its radius (m: a ball's from its mass, lead), the
## soft tissue's strength `a` (J/m) and drag `b` (1/m; a ball's from its size), the skin's cost going in (J; a ball's from
## SKIN_MPS), what a bone's break costs it against a ball (`bone`: an arrow's or a blade's edge bites into bone, it does not
## shatter it), and the energy a point of damage stands for when the shot gives no speed (`j`, J: the musket's ball 120
## damage at 320 m/s, a strong bow's arrow 90 at 62 m/s, a spear 130 at 20 m/s ...). "blunt" (a haft, a club) has no path.
const SHOTS := {
	"ball": {"mass": 0.032, "bone": 1.0, "j": 13.6},
	"arrow": {"mass": 0.03, "r": 0.011, "a": 90.0, "b": 0.4, "skin": 2.0, "bone": 1.0, "j": 0.65},
	"dart": {"mass": 0.12, "r": 0.012, "a": 120.0, "b": 0.5, "skin": 3.0, "bone": 1.0, "j": 0.6},
	"spear": {"mass": 1.2, "r": 0.02, "a": 400.0, "b": 0.5, "skin": 5.0, "bone": 0.8, "j": 1.85},
	"tomahawk": {"mass": 0.6, "r": 0.03, "a": 500.0, "b": 1.0, "skin": 4.0, "bone": 0.7, "j": 0.7},
	"blade": {"mass": 1.0, "r": 0.02, "a": 500.0, "b": 1.0, "skin": 4.0, "bone": 0.7, "j": 1.5},
}
## A lead ball in soft tissue (the Poncelet terms): the tissue's density (kg/m3), the ball's drag coefficient in it, the
## tissue's strength (Pa), lead's density; the speed it needs to go through the skin (m/s).
const RHO := 1060.0
const CD := 0.5
const SIGMA := 2.0e6
const LEAD := 11340.0
const SKIN_MPS := 55.0
## Going out costs this much more than going in (the skin from inside, nothing behind it).
const SKIN_OUT := 1.3
## A ball's terms after a bone it broke (it flattens).
const FLATTEN := 1.4
## Each tissue against soft tissue's terms: [a x, b x].
const TISSUE := {
	"muscle": [1.0, 1.0],
	"lung": [0.3, 0.4],
	"organ": [0.8, 1.0],
	"gut": [0.5, 0.8],
	"brain": [0.3, 0.95],
	"vessel": [0.3, 1.0],
	"cord": [0.3, 0.95],
	"bone": [10.0, 1.8],
}
## Which tissue a stretch of the path is where shapes overlap: the highest.
const PRIORITY := {"bone": 6, "organ": 5, "gut": 4, "brain": 4, "cord": 3, "vessel": 2, "lung": 1, "muscle": 0}

## Kinds of body built (shared: their shapes are read only).
static var _cache := {}

var human := false
## The skeleton's scale when built (the animals' armature is 38x); the shapes' frames take it out.
var k := 1.0
## [{name, kind ("flesh" "bone" "organ" "vessel" "cord"), sub, bone (index), t (shape), xf (in the bone's frame), s, top, th,
##   br (bounding radius, m), brk (J), tis (TISSUE key), col, lvl, mortal, side, limb, vessel ("artery" "vein")}]
var shapes: Array[Dictionary] = []
## bone index -> {c: the bone's shapes' middle in its frame, r: their bounding radius (m), list: shape indices (an Array: a
## packed array in a dictionary is a copy)}
var groups := {}
## The longest line through the body (m): how far past the struck point a trace looks.
var reach := 2.0
## How far before the struck point a trace starts (m).
var back := 0.35
var build_ms := 0.0
## The skin meshes it was fitted to (their names; InspectView draws them as the outline).
var skin_names: PackedStringArray = []
## The body's own axes in the skeleton's rest frame (up: feet to head, an animal's to its back; fwd: where it faces; left),
## and the bone they turn with (the chest's): InspectView's front, back and sides.
var up := Vector3.UP
var fwd := Vector3.BACK
var left := Vector3.RIGHT
var chest_bone := 0
## (while a trace runs: the pose's overrides and their cache, for the points it anchors)
var _ov := {}
var _memo := {}


## The model for the body on `sk` (built the first time a body of its kind is asked for; null when the rig is not known).
static func of(sk: Skeleton3D) -> BodyModel:
	if sk == null:
		return null
	var key := _key(sk)
	if _cache.has(key):
		return _cache[key]
	var t0 := Time.get_ticks_usec()
	var m := BodyBuild.make(sk)
	if m == null:
		return null
	m.build_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	m._group()
	_cache[key] = m
	return m


## A kind of body: its rig (its bones and their rest) and the skin it wears.
static func _key(sk: Skeleton3D) -> String:
	var parts: PackedStringArray = [str(sk.get_bone_count())]
	for bn: String in ["root", "spined", "heada", "Back", "Torso3", "Head", "l_knee", "BackUpperLeg.L"]:
		var i := sk.find_bone(bn)
		if i >= 0:
			parts.append("%s%s" % [bn, sk.get_bone_global_rest(i).origin.snapped(Vector3.ONE * 0.001)])
	for mi in sk.find_children("*", "MeshInstance3D", true, false):
		var g := mi as MeshInstance3D
		if g.mesh != null and g.skin != null and BodyBuild.is_skin(g, sk):
			parts.append(String(g.name) + ":" + str(g.mesh.get_rid().get_id()))
	return "|".join(parts).sha1_text()


## Forgets the built kinds (tests: a fresh build).
static func clear_cache() -> void:
	_cache.clear()


func _group() -> void:
	groups.clear()
	for i in shapes.size():
		var s := shapes[i]
		var b := int(s.bone)
		if not groups.has(b):
			groups[b] = {"c": Vector3.ZERO, "r": 0.0, "list": []}
		(groups[b].list as Array).append(i)
	for b: int in groups:
		var g: Dictionary = groups[b]
		var c := Vector3.ZERO
		for i: int in g.list:
			c += (shapes[i].xf as Transform3D).origin
		c /= float((g.list as Array).size())
		var r := 0.0
		for i: int in g.list:
			# (the frames' origins are in the skeleton's units: k of them a metre... the other way: a unit is k metres)
			r = maxf(r, ((shapes[i].xf as Transform3D).origin - c).length() * k + float(shapes[i].br))
		g.c = c
		g.r = r


## The index of the first shape named `nm` (-1 none).
func find(nm: String) -> int:
	for i in shapes.size():
		if String(shapes[i].name) == nm:
			return i
	return -1


## Shape `i`'s frame in the world now, on `sk` as the body shows it (Y its long axis; its sizes in metres when the skeleton is at
## the scale it was built at). `ov`, `memo`: overrides() and a cache, for many looks at one pose.
func shape_world(sk: Skeleton3D, i: int, ov := {}, memo := {}) -> Transform3D:
	var s := shapes[i]
	return sk.global_transform * pose(sk, int(s.bone), ov, memo) * (s.xf as Transform3D)


## A world point as {b: the bone, p: the point in its frame} (it rides the bone: where() gives it back as the body moves).
static func anchor(sk: Skeleton3D, bone: int, world: Vector3, ov := {}, memo := {}) -> Dictionary:
	var w := sk.global_transform * pose(sk, bone, ov, memo)
	return {"b": bone, "p": w.affine_inverse() * world}


## An anchored point where it is now.
static func where(sk: Skeleton3D, a: Dictionary, ov := {}, memo := {}) -> Vector3:
	if a.is_empty() or sk == null:
		return Vector3.INF
	return sk.global_transform * pose(sk, int(a.b), ov, memo) * (a.p as Vector3)


## What puts the bones elsewhere than get_bone_global_pose() says (a SkeletonModifier3D's work is not in it, only in what is
## drawn): a BoneRagdoll's bodies, or the pose it froze where the carcass lies; a PhysicalBoneSimulator3D's bones while it
## simulates (the player's ragdoll). {bone index: its pose in the skeleton's frame}; {} none (the pose is the skeleton's own).
static func overrides(sk: Skeleton3D) -> Dictionary:
	var out := {}
	if sk == null:
		return out
	var inv := sk.global_transform.affine_inverse()
	for c in sk.get_children():
		if c is BoneRagdoll.RagdollDriver:
			var rag: BoneRagdoll = (c as BoneRagdoll.RagdollDriver).rag
			if rag == null or not is_instance_valid(rag):
				continue
			if rag.frozen:
				for bi: int in rag._held:
					out[bi] = rag._held[bi]
			else:
				for bi: int in rag._order:
					var l := inv * rag.bone_world(bi)
					out[bi] = Transform3D(l.basis.orthonormalized(), l.origin)
		elif c is PhysicalBoneSimulator3D and (c as PhysicalBoneSimulator3D).active and (c as PhysicalBoneSimulator3D).is_simulating_physics():
			for pb in c.get_children():
				if pb is PhysicalBone3D:
					var p := pb as PhysicalBone3D
					out[p.get_bone_id()] = inv * (p.global_transform * p.body_offset.affine_inverse())
	return out


## Bone `b`'s pose as the body shows it (the skeleton's frame): the override's (overrides()) or its parent's with its own local
## pose; with no overrides simply the skeleton's. `memo` keeps what was worked out for one pose.
static func pose(sk: Skeleton3D, b: int, ov: Dictionary, memo: Dictionary) -> Transform3D:
	if ov.is_empty():
		return sk.get_bone_global_pose(b)
	if memo.has(b):
		return memo[b]
	var t: Transform3D
	if ov.has(b):
		t = ov[b]
	else:
		var p := sk.get_bone_parent(b)
		t = (pose(sk, p, ov, memo) if p >= 0 else Transform3D.IDENTITY) * sk.get_bone_pose(b)
	memo[b] = t
	return t


# ---------------------------------------------------------------------------------------------------------------------
# The round


## A shot's terms: {kind, mass, speed, energy (J), r (m), a, b, skin (J), bone} from Hit's `shot` ({kind, speed, mass}); without
## a speed, the energy of its damage (SHOTS j); no kind: a ball. A "blunt" shot: {kind: "blunt"} (no path through the body).
static func round_of(shot: Dictionary, damage: float) -> Dictionary:
	var kind := String(shot.get("kind", "ball"))
	if kind == "blunt":
		return {"kind": "blunt", "energy": 0.0, "speed": 0.0, "mass": 0.0}
	if not SHOTS.has(kind):
		kind = "ball"
	var p: Dictionary = SHOTS[kind]
	var mass := float(shot.get("mass", 0.0))
	if mass <= 0.0:
		mass = float(p.mass)
	var speed := float(shot.get("speed", 0.0))
	var energy := 0.0
	if speed > 0.0:
		energy = 0.5 * mass * speed * speed
	else:
		energy = maxf(damage, 1.0) * float(p.j)
		speed = sqrt(2.0 * energy / mass)
	var out := {"kind": kind, "mass": mass, "speed": speed, "energy": energy, "bone": float(p.get("bone", 1.0))}
	if kind == "ball":
		var r := pow(3.0 * mass / (4.0 * PI * LEAD), 1.0 / 3.0)
		var area := PI * r * r
		out.r = r
		out.a = SIGMA * area
		out.b = RHO * CD * area / mass
		out.skin = 0.5 * mass * SKIN_MPS * SKIN_MPS
	else:
		out.r = float(p.r)
		out.a = float(p.a)
		out.b = float(p.b)
		out.skin = float(p.skin)
	return out


# ---------------------------------------------------------------------------------------------------------------------
# The trace


## The path of a round (round_of) that struck the body at `point` (world) going `dir`: {
##   missed      the line does not meet the body (past the waist, between the legs: the round flies on)
##   entry       where it went in (world); exit: where it came out (Vector3.INF none); stop: where it stopped (INF none)
##   holes       [{at (world), out (false in, true out), a (anchored)}] every hole in the skin, in order
##   crossed     [{i (shape), name, kind, sub, t0, t1 (m along the line from the entry), e_in, e_out (J), res, lvl, at (world,
##               where it entered it), a (anchored), d (vessels and the cord: the line's distance from its axis, m)}] in order
##   path        [anchored points along it, the entry to its end]
##   energy0, energy_left (J), deposited (J), round (round_of), stopped_in (the name it stopped in, "" none), us (the cost) }
func trace(sk: Skeleton3D, point: Vector3, dir: Vector3, rnd: Dictionary) -> Dictionary:
	var t_start := Time.get_ticks_usec()
	var d := dir.normalized() if dir.length_squared() > 1e-10 else Vector3.DOWN
	var kscale := sk.global_transform.basis.get_scale().x / maxf(k, 1e-6)   # (this body against the one it was built on)
	var from := point - d * back * kscale
	var seg := (back + reach) * kscale
	var to := from + d * seg
	var grow := float(rnd.r)
	var crossings: Array = []         # [t0 (m), t1 (m), shape, d_axis]
	var bone_w := {}
	var skw := sk.global_transform
	var ov := overrides(sk)
	var memo := {}
	for b: int in groups:
		var g: Dictionary = groups[b]
		var bw := skw * pose(sk, b, ov, memo)
		var c := bw * (g.c as Vector3)
		if _seg_point_dist(from, to, c) > float(g.r) * kscale + grow:
			continue
		bone_w[b] = bw
		for i: int in g.list:
			var s := shapes[i]
			var w := bw * (s.xf as Transform3D)
			if _seg_point_dist(from, to, w.origin) > float(s.br) * kscale + grow:
				continue
			var inv := w.affine_inverse()
			var la := inv * from
			var lb := inv * to
			var iv := _hit_shape(s, la, lb, grow / kscale)
			var j := 0
			while j + 1 < iv.size():
				var da := -1.0
				if s.kind == "vessel" or s.kind == "cord":
					da = _seg_dist(la, lb, Vector3(0, -float(s.s.y), 0), Vector3(0, float(s.s.y), 0)) * kscale
				crossings.append([iv[j] * seg, iv[j + 1] * seg, i, da])
				j += 2
	var rec := {"missed": true, "entry": Vector3.INF, "exit": Vector3.INF, "stop": Vector3.INF, "holes": [], "crossed": [],
			"path": [], "energy0": float(rnd.energy), "energy_left": float(rnd.energy), "deposited": 0.0, "round": rnd,
			"stopped_in": "", "from": from, "dir": d, "us": 0}
	if crossings.is_empty():
		rec.us = Time.get_ticks_usec() - t_start
		return rec
	crossings.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	rec.missed = false
	_ov = ov
	_memo = memo
	_walk(sk, rec, crossings, from, d, rnd, kscale)
	_ov = {}
	_memo = {}
	rec.us = Time.get_ticks_usec() - t_start
	return rec


## The round along the sorted crossings: the body's stretches (the union of everything crossed), the skin at each end of
## them, the tissue of each piece between the shapes' edges, energy off each, until it is out or has stopped.
func _walk(sk: Skeleton3D, rec: Dictionary, crossings: Array, from: Vector3, d: Vector3, rnd: Dictionary, ks: float) -> void:
	# the body's stretches along the line
	var spans: Array = []
	for c: Array in crossings:
		if spans.is_empty() or float(c[0]) > float(spans[-1][1]) + 1e-4:
			spans.append([float(c[0]), float(c[1])])
		else:
			spans[-1][1] = maxf(float(spans[-1][1]), float(c[1]))
	var e := float(rnd.energy)
	var a := float(rnd.a)
	var b := float(rnd.b)
	var skin := float(rnd.skin)
	var is_ball := String(rnd.kind) == "ball"
	var entered := {}                   # crossing index -> its entry in rec.crossed
	var t_end := -1.0
	var stop_shape := -1
	var first := true
	for sp: Array in spans:
		var s0 := float(sp[0])
		var s1 := float(sp[1])
		# in through the skin
		var at_in := from + d * s0
		var hole_bone := _bone_at(crossings, s0, true)
		rec.holes.append({"at": at_in, "out": false, "a": anchor(sk, hole_bone, at_in, _ov, _memo)})
		if first:
			rec.entry = at_in
			rec.path.append(anchor(sk, hole_bone, at_in, _ov, _memo))
			first = false
		e -= skin
		if e <= 0.0:
			# (it did not go in: a bruise where it struck)
			t_end = s0 + 0.003
			stop_shape = _shape_at(crossings, s0)
			e = 0.0
			break
		# the edges of the shapes in this stretch
		var edges: Array[float] = [s0, s1]
		for c: Array in crossings:
			if float(c[0]) > s0 - 1e-5 and float(c[0]) < s1 + 1e-5:
				edges.append(float(c[0]))
			if float(c[1]) > s0 - 1e-5 and float(c[1]) < s1 + 1e-5:
				edges.append(float(c[1]))
		edges.sort()
		var stopped := false
		var ta := s0
		for ei in edges.size():
			var tb := edges[ei]
			if tb <= ta + 1e-6:
				continue
			# what starts here
			for ci in crossings.size():
				var c: Array = crossings[ci]
				if entered.has(ci) or float(c[0]) > ta + 1e-5 or float(c[1]) < ta + 1e-6:
					continue
				var shp := shapes[int(c[2])]
				var at := from + d * maxf(float(c[0]), s0)
				var row := {"i": int(c[2]), "name": String(shp.name), "kind": String(shp.kind), "sub": String(shp.get("sub", "")),
						"t0": float(c[0]), "t1": float(c[1]), "e_in": e, "e_out": e, "res": "", "lvl": int(shp.get("lvl", 0)),
						"at": at, "a": anchor(sk, int(shp.bone), at, _ov, _memo), "d": float(c[3]), "path_m": 0.0}
				if row.kind == "cord" and int(row.lvl) > 1:
					# (a stretch of the cord runs from the canal of the level above to its own: named for the nearer)
					if ((shape_world(sk, int(c[2]), _ov, _memo).affine_inverse() * at) as Vector3).y < 0.0:
						row.lvl = int(row.lvl) - 1
				entered[ci] = rec.crossed.size()
				rec.crossed.append(row)
				if row.kind != "flesh":
					rec.path.append(row.a)
				if row.kind == "bone":
					var brk := float(shp.get("brk", 30.0)) * float(rnd.bone)
					if e < brk:
						# it stops in the bone (cracked when it had near the bone's worth, chipped when it had little)
						row.res = "lodged"
						row.e_out = 0.0
						t_end = ta + minf(0.004, (tb - ta) * 0.4)
						stop_shape = int(c[2])
						e = 0.0
						stopped = true
						_close_rows(rec, crossings, entered, t_end, 0.0)
						break
					e -= brk
					if is_ball and brk >= 30.0:
						a *= FLATTEN
						b *= FLATTEN
			if stopped:
				break
			# the tissue of this piece: the highest of what covers it
			var tis := "muscle"
			var pr := -1
			for c: Array in crossings:
				if float(c[0]) <= ta + 1e-5 and float(c[1]) >= tb - 1e-5:
					var shp2 := shapes[int(c[2])]
					var tk := String(shp2.get("tis", "muscle"))
					if int(PRIORITY.get(tk, 0)) > pr:
						pr = int(PRIORITY.get(tk, 0))
						tis = tk
			var f: Array = TISSUE.get(tis, TISSUE.muscle)
			var a2 := a * float(f[0])
			var b2 := b * float(f[1])
			var len_m := tb - ta
			var e2 := (e + a2 / b2) * exp(-b2 * len_m) - a2 / b2
			if e2 <= 0.0:
				var x := log((e + a2 / b2) / (a2 / b2)) / b2
				t_end = ta + clampf(x, 0.0, len_m)
				stop_shape = _innermost(crossings, ta, tb)
				e = 0.0
				stopped = true
				_close_rows(rec, crossings, entered, t_end, 0.0)
				break
			e = e2
			_close_rows(rec, crossings, entered, tb, e)
			ta = tb
		if stopped:
			break
		# out through the skin
		var at_out := from + d * s1
		if e < skin * SKIN_OUT:
			# (lodged under the skin on the far side)
			t_end = s1 - 0.004
			stop_shape = _shape_at(crossings, s1 - 0.004)
			e = 0.0
			break
		e -= skin * SKIN_OUT
		var ob := _bone_at(crossings, s1, false)
		rec.holes.append({"at": at_out, "out": true, "a": anchor(sk, ob, at_out, _ov, _memo)})
		t_end = s1
	var t_entry := float(spans[0][0])
	for row: Dictionary in rec.crossed:
		row.t0 = maxf(float(row.t0) - t_entry, 0.0)
		row.t1 = float(row.t1) - t_entry
	if e <= 0.0 and t_end >= 0.0:
		var at_stop := from + d * t_end
		rec.stop = at_stop
		var sb := int(shapes[stop_shape].bone) if stop_shape >= 0 else _bone_at(crossings, t_end, true)
		rec.path.append(anchor(sk, sb, at_stop, _ov, _memo))
		rec.stopped_in = String(shapes[stop_shape].name) if stop_shape >= 0 else ""
		rec.stop_a = anchor(sk, sb, at_stop, _ov, _memo)
	else:
		var last: Dictionary = rec.holes[-1]
		if bool(last.out):
			rec.exit = last.at
			rec.path.append(last.a)
	rec.energy_left = maxf(e, 0.0)
	rec.deposited = float(rec.energy0) - float(rec.energy_left)
	_results(rec, crossings)


## Rows whose shape ends by `t`: the energy they let out.
func _close_rows(rec: Dictionary, crossings: Array, entered: Dictionary, t: float, e: float) -> void:
	for ci: int in entered:
		var c: Array = crossings[ci]
		var row: Dictionary = rec.crossed[int(entered[ci])]
		if float(c[1]) <= t + 1e-5 and String(row.res) == "":
			row.e_out = e
			row.path_m = float(c[1]) - float(c[0])
			row.res = "_done"
		elif float(c[1]) > t + 1e-5 and e <= 0.0 and String(row.res) == "":
			row.e_out = 0.0
			row.path_m = maxf(t - float(c[0]), 0.0)
			row.res = "_stopped"


## What each crossed shape came to: a bone fractured (broke through, or cracked with near its worth), chipped (a round with
## little left); an organ punctured, or grazed (a few mm of it); a vessel cut (through its middle) or nicked (its edge); the
## cord badly injured (a round with 15 J or more in it) or bruised; flesh torn. `dep`: the energy it left there (J).
func _results(rec: Dictionary, crossings: Array) -> void:
	var rnd: Dictionary = rec.round
	for row: Dictionary in rec.crossed:
		var shp := shapes[int(row.i)]
		var was := String(row.res)
		var e_in := float(row.e_in)
		match String(row.kind):
			"bone":
				var brk := float(shp.get("brk", 30.0)) * float(rnd.bone)
				if was == "lodged":
					row.res = "fractured" if e_in >= brk * 0.4 else "chipped"
					row.lodged = true
				else:
					row.res = "fractured"
			"organ":
				row.res = "punctured" if float(row.path_m) >= 0.008 or was == "_stopped" else "grazed"
			"vessel":
				row.res = "cut" if float(row.d) <= float(shp.s.x) * 1.05 else "nicked"
			"cord":
				row.res = "injured" if e_in >= 15.0 else "bruised"
			_:
				row.res = "torn"
		row.dep = maxf(e_in - float(row.e_out), 0.0)


func _bone_at(crossings: Array, t: float, entering: bool) -> int:
	var best := -1
	var best_d := INF
	for c: Array in crossings:
		var dd := absf((float(c[0]) if entering else float(c[1])) - t)
		if dd < best_d:
			best_d = dd
			best = int(c[2])
	return int(shapes[best].bone) if best >= 0 else 0


func _shape_at(crossings: Array, t: float) -> int:
	var best := -1
	var pr := -1
	for c: Array in crossings:
		if float(c[0]) <= t + 1e-4 and float(c[1]) >= t - 1e-4:
			var p := int(PRIORITY.get(String(shapes[int(c[2])].get("tis", "muscle")), 0))
			if p > pr:
				pr = p
				best = int(c[2])
	return best


## The shape that holds the stretch ta..tb, the innermost (the highest tissue).
func _innermost(crossings: Array, ta: float, tb: float) -> int:
	return _shape_at(crossings, (ta + tb) * 0.5)


# ---------------------------------------------------------------------------------------------------------------------
# Lines against shapes


## Where segment a..b (the shape's own frame, metres) is inside shape `s` grown by `grow`: [t0, t1, ...] (0..1 along it; two
## pairs for a shell), [] when it misses.
static func _hit_shape(s: Dictionary, a: Vector3, b: Vector3, grow: float) -> PackedFloat32Array:
	var sz := s.s as Vector3
	match String(s.t):
		"cap":
			return _clip01(_capsule(a, b, sz.x + grow, sz.y))
		"cyl":
			return _clip01(_ecyl(a, b, sz.x + grow, sz.z + grow, sz.y + grow))
		"ell":
			return _clip01(_ellipsoid(a, b, sz + Vector3.ONE * grow))
		"shell":
			var outer := _ellipsoid(a, b, sz + Vector3.ONE * grow)
			if outer.is_empty():
				return PackedFloat32Array()
			var th := float(s.get("th", 0.007))
			var inner_r := sz - Vector3.ONE * (th + grow)
			if inner_r.x <= 0.0 or inner_r.y <= 0.0 or inner_r.z <= 0.0:
				return _clip01(outer)
			var inner := _ellipsoid(a, b, inner_r)
			if inner.is_empty():
				return _clip01(outer)
			var out := PackedFloat32Array()
			out.append_array(_clip01(PackedFloat32Array([outer[0], inner[0]])))
			out.append_array(_clip01(PackedFloat32Array([inner[1], outer[1]])))
			return out
		"box":
			var top := s.get("top", Vector2(sz.x, sz.z)) as Vector2
			return _tbox(a, b, sz.x + grow, sz.z + grow, top.x + grow, top.y + grow, sz.y + grow)
	return PackedFloat32Array()


static func _clip01(iv: PackedFloat32Array) -> PackedFloat32Array:
	if iv.size() < 2:
		return PackedFloat32Array()
	var t0 := maxf(iv[0], 0.0)
	var t1 := minf(iv[1], 1.0)
	if t1 <= t0:
		return PackedFloat32Array()
	return PackedFloat32Array([t0, t1])


## Segment against an ellipsoid at the origin with radii `r`: the unclipped [t0, t1] of the line, or [].
static func _ellipsoid(a: Vector3, b: Vector3, r: Vector3) -> PackedFloat32Array:
	var p := a / r
	var dd := (b - a) / r
	var qa := dd.dot(dd)
	if qa < 1e-12:
		return PackedFloat32Array()
	var qb := 2.0 * p.dot(dd)
	var qc := p.dot(p) - 1.0
	var disc := qb * qb - 4.0 * qa * qc
	if disc < 0.0:
		return PackedFloat32Array()
	var sq := sqrt(disc)
	return PackedFloat32Array([(-qb - sq) / (2.0 * qa), (-qb + sq) / (2.0 * qa)])


## Segment against a capsule along Y (its middle -h..h, radius r): the unclipped [t0, t1], or [].
static func _capsule(a: Vector3, b: Vector3, r: float, h: float) -> PackedFloat32Array:
	var dd := b - a
	var lo := INF
	var hi := -INF
	# the cylinder's side, between the ends
	var qa := dd.x * dd.x + dd.z * dd.z
	var qc := a.x * a.x + a.z * a.z - r * r
	var c0 := -INF
	var c1 := INF
	var side_ok := true
	if qa < 1e-12:
		side_ok = qc <= 0.0
	else:
		var qb := 2.0 * (a.x * dd.x + a.z * dd.z)
		var disc := qb * qb - 4.0 * qa * qc
		if disc < 0.0:
			side_ok = false
		else:
			var sq := sqrt(disc)
			c0 = (-qb - sq) / (2.0 * qa)
			c1 = (-qb + sq) / (2.0 * qa)
	if side_ok:
		var y0 := -INF
		var y1 := INF
		if absf(dd.y) < 1e-12:
			if absf(a.y) > h:
				side_ok = false
		else:
			var ta := (-h - a.y) / dd.y
			var tb := (h - a.y) / dd.y
			y0 = minf(ta, tb)
			y1 = maxf(ta, tb)
		if side_ok:
			var s0 := maxf(c0, y0)
			var s1 := minf(c1, y1)
			if s1 > s0:
				lo = minf(lo, s0)
				hi = maxf(hi, s1)
	for cy: float in [-h, h]:
		var e := _ellipsoid(a - Vector3(0, cy, 0), b - Vector3(0, cy, 0), Vector3(r, r, r))
		if not e.is_empty():
			lo = minf(lo, e[0])
			hi = maxf(hi, e[1])
	if hi <= lo:
		return PackedFloat32Array()
	return PackedFloat32Array([lo, hi])


## Segment against an elliptic cylinder along Y (radii rx, rz; flat ends at -h, h): [t0, t1] clipped to 0..1, or [].
static func _ecyl(a: Vector3, b: Vector3, rx: float, rz: float, h: float) -> PackedFloat32Array:
	var dd := b - a
	var px := a.x / rx
	var pz := a.z / rz
	var dx := dd.x / rx
	var dz := dd.z / rz
	var qa := dx * dx + dz * dz
	var qc := px * px + pz * pz - 1.0
	var t0 := 0.0
	var t1 := 1.0
	if qa < 1e-12:
		if qc > 0.0:
			return PackedFloat32Array()
	else:
		var qb := 2.0 * (px * dx + pz * dz)
		var disc := qb * qb - 4.0 * qa * qc
		if disc < 0.0:
			return PackedFloat32Array()
		var sq := sqrt(disc)
		t0 = maxf(t0, (-qb - sq) / (2.0 * qa))
		t1 = minf(t1, (-qb + sq) / (2.0 * qa))
	if absf(dd.y) < 1e-12:
		if absf(a.y) > h:
			return PackedFloat32Array()
	else:
		var ya := (-h - a.y) / dd.y
		var yb := (h - a.y) / dd.y
		t0 = maxf(t0, minf(ya, yb))
		t1 = minf(t1, maxf(ya, yb))
	if t1 <= t0:
		return PackedFloat32Array()
	return PackedFloat32Array([t0, t1])


## Segment against a box tapered along Y: half widths x0, z0 at y = -h and x1, z1 at y = h (each side a plane): [t0, t1]
## clipped to 0..1, or [].
static func _tbox(a: Vector3, b: Vector3, x0: float, z0: float, x1: float, z1: float, h: float) -> PackedFloat32Array:
	var dd := b - a
	var kx := (x1 - x0) / (2.0 * h)
	var kz := (z1 - z0) / (2.0 * h)
	var cx := x0 + kx * h
	var cz := z0 + kz * h
	var t0 := 0.0
	var t1 := 1.0
	# planes n.p <= c
	var planes := [[Vector3(0, 1, 0), h], [Vector3(0, -1, 0), h], [Vector3(1, -kx, 0), cx], [Vector3(-1, -kx, 0), cx],
			[Vector3(0, -kz, 1), cz], [Vector3(0, -kz, -1), cz]]
	for pl: Array in planes:
		var n: Vector3 = pl[0]
		var fa := n.dot(a) - float(pl[1])
		var fd := n.dot(dd)
		if absf(fd) < 1e-12:
			if fa > 0.0:
				return PackedFloat32Array()
			continue
		var t := -fa / fd
		if fd < 0.0:
			t0 = maxf(t0, t)
		else:
			t1 = minf(t1, t)
		if t1 <= t0:
			return PackedFloat32Array()
	return PackedFloat32Array([t0, t1])


static func _seg_point_dist(a: Vector3, b: Vector3, p: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-12), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Closest distance between segments a0-a1 and b0-b1.
static func _seg_dist(a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3) -> float:
	var u := a1 - a0
	var v := b1 - b0
	var w := a0 - b0
	var qa := u.dot(u)
	var qb := u.dot(v)
	var qc := v.dot(v)
	var qd := u.dot(w)
	var qe := v.dot(w)
	var den := qa * qc - qb * qb
	var s := 0.0
	if den > 1e-12:
		s = clampf((qb * qe - qc * qd) / den, 0.0, 1.0)
	var t := clampf((qb * s + qe) / maxf(qc, 1e-12), 0.0, 1.0)
	s = clampf((qb * t - qd) / maxf(qa, 1e-12), 0.0, 1.0)
	return (a0 + u * s).distance_to(b0 + v * t)
