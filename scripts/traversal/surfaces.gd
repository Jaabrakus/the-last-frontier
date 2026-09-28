class_name TravSurfaces
extends RefCounted
## Contact surfaces for the traversal IK and the contact checks (design 8.4): the exact collision
## geometry a move touches, as small dictionaries (world space):
##   {type: "box",   xform: Transform3D (centre, rotation), half: Vector3, name}
##   {type: "plane", y: float, name}                      (flat ground / a probed top without a box)
##   {type: "plane", y, name, p: Vector3, n: Vector3}     (sloped ground: a height-field or mesh
##                                                         support under a move, its local plane)
##   {type: "cyl",   a: Vector3, b: Vector3, r: float, name}   (logs, rungs, cylinder / capsule shapes)
## from_shape() reads a CollisionShape3D (BoxShape3D, CylinderShape3D, CapsuleShape3D; anything
## else gives null and the caller uses a plane at the probed height).
##
## Measures on a set of points (the limb's mesh probes, or every skinned vertex in the tests):
##   top_gap(s, pts)     how far the lowest point that lies over the surface's top is above it
##                       (negative: below). A hand gripping a lip counts only the points over the
##                       top, not the fingers that curl over the edge.
##   penetration(s, pts) the deepest point inside the solid (0 when none) and the push-out direction.

const FOOT_MARGIN := 0.0


static func from_shape(cs: Node) -> Variant:
	if cs == null or not cs is CollisionShape3D:
		return null
	var sh: Shape3D = (cs as CollisionShape3D).shape
	var xf: Transform3D = (cs as Node3D).global_transform
	var sc := xf.basis.get_scale()
	xf.basis = xf.basis.orthonormalized()
	if sh is BoxShape3D:
		return {"type": "box", "xform": xf, "half": (sh as BoxShape3D).size * 0.5 * sc, "name": str(cs.get_parent().name)}
	if sh is CylinderShape3D or sh is CapsuleShape3D:
		var h := 0.0
		var r := 0.0
		if sh is CylinderShape3D:
			h = (sh as CylinderShape3D).height
			r = (sh as CylinderShape3D).radius
		else:
			h = (sh as CapsuleShape3D).height - 2.0 * (sh as CapsuleShape3D).radius
			r = (sh as CapsuleShape3D).radius
		var up := xf.basis.y
		return {"type": "cyl", "a": xf.origin - up * h * 0.5, "b": xf.origin + up * h * 0.5, "r": r * sc.x,
				"capsule": sh is CapsuleShape3D, "name": str(cs.get_parent().name)}
	return null


static func plane(y: float, name := "plane") -> Dictionary:
	return {"type": "plane", "y": y, "name": name}


## The local plane of sloped ground through `p` with normal `n` (horizontal when n is nearly
## vertical). Review 2026-09-24: a flat plane at the start's height under a move on an 8 deg
## terrain slope put the planted feet up to 14 cm inside the ground ahead.
static func ground_plane(p: Vector3, n: Vector3, name := "plane") -> Dictionary:
	var d := {"type": "plane", "y": p.y, "name": name}
	n = n.normalized()
	if n.y > 0.5 and n.y < 0.9995:
		d["p"] = p
		d["n"] = n
	return d


static func box(center: Vector3, size: Vector3, yaw := 0.0, name := "box") -> Dictionary:
	return {"type": "box", "xform": Transform3D(Basis(Vector3.UP, yaw), center), "half": size * 0.5, "name": name}


## Signed distance of p to the solid (negative inside) and the outward gradient.
static func sdf(s: Dictionary, p: Vector3) -> Array:
	match str(s.type):
		"plane":
			if s.has("n"):
				return [(p - (s.p as Vector3)).dot(s.n), s.n]
			return [p.y - float(s.y), Vector3.UP]
		"box":
			var xf: Transform3D = s.xform
			var h: Vector3 = s.half
			var q := xf.affine_inverse() * p
			var d := q.abs() - h
			if d.x > 0.0 or d.y > 0.0 or d.z > 0.0:
				var o := Vector3(maxf(d.x, 0.0) * signf(q.x), maxf(d.y, 0.0) * signf(q.y), maxf(d.z, 0.0) * signf(q.z))
				var l := o.length()
				return [l, (xf.basis * (o / maxf(l, 1e-9))).normalized()]
			# inside: the nearest face
			var ax := 0
			if d.y > d[ax]:
				ax = 1
			if d.z > d[ax]:
				ax = 2
			var n := Vector3.ZERO
			n[ax] = signf(q[ax]) if q[ax] != 0.0 else 1.0
			return [d[ax], (xf.basis * n).normalized()]
		"cyl":
			var a: Vector3 = s.a
			var b: Vector3 = s.b
			var ab := b - a
			if not bool(s.get("capsule", true)):
				return _capped_cyl_sdf(a, ab, float(s.r), p)
			var u := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
			var c := a + ab * u
			var rv := p - c
			var dist := rv.length() - float(s.r)
			var g := rv / maxf(rv.length(), 1e-9)
			if rv.length() < 1e-6:
				g = Vector3.UP
			return [dist, g]
	return [INF, Vector3.UP]


## A cylinder with flat end caps (CylinderShape3D; fix round 3, review 2026-09-25: measured as a
## capsule, a fallen log reached a hemisphere of its radius past each end, and feet stepping off
## the log's end read up to 0.2 m inside it). Rungs and dictionaries without "capsule" keep the
## capsule measure.
static func _capped_cyl_sdf(a: Vector3, ab: Vector3, r: float, p: Vector3) -> Array:
	var l := ab.length()
	if l < 1e-9:
		return [(p - a).length() - r, (p - a).normalized() if (p - a).length() > 1e-9 else Vector3.UP]
	var ax := ab / l
	var t := (p - a).dot(ax)
	var radial := (p - a) - ax * t
	var rl := radial.length()
	var rdir := radial / rl if rl > 1e-9 else (Vector3.UP if absf(ax.y) < 0.9 else Vector3.RIGHT)
	var dr := rl - r
	var cap_dir := -ax if t < l * 0.5 else ax
	var dh := maxf(-t, t - l)
	if dr > 0.0 or dh > 0.0:
		var o := rdir * maxf(dr, 0.0) + cap_dir * maxf(dh, 0.0)
		var ol := o.length()
		return [ol, o / maxf(ol, 1e-9)]
	if dr > dh:
		return [dr, rdir]
	return [dh, cap_dir]


const CYL_FROM_ABOVE_R := 0.06     ## top_gap(cyl_vertical): rungs, not logs

## Height of the lowest point lying over the surface's top (box: inside the top face's footprint
## in box space; cylinder: within its length, above its axis; plane: all). Returns
## {gap, n (surface normal, world), i (index), over (count of points over the top)}.
## cyl_vertical: a thin lying cylinder (a rung, radius under CYL_FROM_ABOVE_R) is seen from
## above, as a height field (its top at a point's horizontal offset from the axis; points beyond
## the radius are not over it; normal up), not radially (the nearest point of its whole upper
## half, radial normal).
static func top_gap(s: Dictionary, pts: PackedVector3Array, margin := 0.0, cyl_vertical := false) -> Dictionary:
	var best := INF
	var bi := -1
	var over := 0
	var n := Vector3.UP
	match str(s.type):
		"plane":
			var sloped := s.has("n")
			if sloped:
				n = s.n
			for i in pts.size():
				var g := (pts[i] - (s.p as Vector3)).dot(n) if sloped else pts[i].y - float(s.y)
				over += 1
				if g < best:
					best = g
					bi = i
		"box":
			var xf: Transform3D = s.xform
			var inv := xf.affine_inverse()
			var h: Vector3 = s.half
			n = xf.basis.y.normalized()
			for i in pts.size():
				var q := inv * pts[i]
				if absf(q.x) > h.x - margin or absf(q.z) > h.z - margin:
					continue
				over += 1
				var g := (q.y - h.y)
				if g < best:
					best = g
					bi = i
		"cyl":
			var a: Vector3 = s.a
			var b: Vector3 = s.b
			var ab := b - a
			# (From above only for a thin lying cylinder, a rung: a log's broad top keeps the radial
			# measure, which its feet plants were tuned on.)
			var from_above := cyl_vertical and absf(ab.normalized().y) < 0.5 and float(s.r) < CYL_FROM_ABOVE_R
			for i in pts.size():
				var u := (pts[i] - a).dot(ab) / maxf(ab.length_squared(), 1e-9)
				if u < 0.0 or u > 1.0:
					continue
				var c := a + ab * u
				var rv := pts[i] - c
				if from_above:
					var hs := Vector2(rv.x, rv.z).length()
					var r := float(s.r)
					if hs >= r:
						continue
					over += 1
					var gv := rv.y - sqrt(r * r - hs * hs)
					if gv < best:
						best = gv
						bi = i
						n = Vector3.UP
					continue
				if rv.y < 0.0:
					continue
				over += 1
				var g := rv.length() - float(s.r)
				if g < best:
					best = g
					bi = i
					n = rv.normalized()
	return {"gap": best, "i": bi, "over": over, "n": n}


## Deepest point inside the solid: {depth (>= 0), i, n (push-out direction)}.
static func penetration(s: Dictionary, pts: PackedVector3Array) -> Dictionary:
	var worst := 0.0
	var wi := -1
	var wn := Vector3.UP
	if str(s.type) == "box":
		# Inlined (the per-point affine_inverse of sdf() dominated the IK guards' cost): only
		# points inside the box can penetrate; the normal is that of sdf() for the deepest one.
		var xf: Transform3D = s.xform
		var inv := xf.affine_inverse()
		var h: Vector3 = s.half
		for i in pts.size():
			var q := inv * pts[i]
			var d := q.abs() - h
			if d.x > 0.0 or d.y > 0.0 or d.z > 0.0:
				continue
			var m := maxf(d.x, maxf(d.y, d.z))
			if -m > worst:
				worst = -m
				wi = i
		if wi >= 0:
			wn = sdf(s, pts[wi])[1]
		return {"depth": worst, "i": wi, "n": wn}
	if str(s.type) == "cyl" and bool(s.get("capsule", true)):
		# Inlined as the box (perf 2026-09-25: the ladder's rungs are guards of every limb): the
		# distance to the axis segment against the radius; the normal of sdf() for the deepest.
		var a: Vector3 = s.a
		var ab: Vector3 = (s.b as Vector3) - a
		var inv_l2 := 1.0 / maxf(ab.length_squared(), 1e-9)
		var r2 := float(s.r) * float(s.r)
		var best2 := r2
		for i in pts.size():
			var ap := pts[i] - a
			var u := clampf(ap.dot(ab) * inv_l2, 0.0, 1.0)
			var d2 := (ap - ab * u).length_squared()
			if d2 < best2:
				best2 = d2
				wi = i
		if wi >= 0:
			var rr := sdf(s, pts[wi])
			worst = -float(rr[0])
			wn = rr[1]
		return {"depth": maxf(worst, 0.0), "i": wi, "n": wn}
	for i in pts.size():
		var r := sdf(s, pts[i])
		if float(r[0]) < -worst:
			worst = -float(r[0])
			wi = i
			wn = r[1]
	return {"depth": worst, "i": wi, "n": wn}


## Penetration pushed out through the face a limb ENTERED by (review 2026-09-24): for a box, the
## face the segment from `from` (the limb's shoulder / hip, outside the box) to the inside points'
## centroid crosses first; the depth is the deepest point's distance behind that face. The nearest
## face (penetration()) flips when a point gets deeper behind the front face than below the top,
## which made the guard throw a hand 10-20 cm in one frame (a vault's hand arriving over a wall
## taller than authored, the squeeze's hand swinging into the rock). Other shapes, or a `from`
## inside the box: penetration().
static func penetration_from(s: Dictionary, pts: PackedVector3Array, from: Vector3) -> Dictionary:
	if str(s.type) != "box":
		return penetration(s, pts)
	var xf: Transform3D = s.xform
	var inv := xf.affine_inverse()
	var h: Vector3 = s.half
	var inside := PackedVector3Array()
	var cen := Vector3.ZERO
	for i in pts.size():
		var q := inv * pts[i]
		var d := q.abs() - h
		if d.x > 0.0 or d.y > 0.0 or d.z > 0.0:
			continue
		inside.append(q)
		cen += q
	if inside.is_empty():
		return {"depth": 0.0, "i": -1, "n": Vector3.UP}
	cen /= float(inside.size())
	var a := inv * from
	var da := a.abs() - h
	if da.x <= 0.0 and da.y <= 0.0 and da.z <= 0.0:
		return penetration(s, pts)
	# Slab entry of the segment a -> cen: the axis with the largest entering t.
	var dir := cen - a
	var t_in := -INF
	var ax := -1
	for k in 3:
		if absf(dir[k]) < 1e-9:
			continue
		var t0 := (-h[k] - a[k]) / dir[k]
		var t1 := (h[k] - a[k]) / dir[k]
		var te := minf(t0, t1)
		if te > t_in:
			t_in = te
			ax = k
	if ax < 0:
		return penetration(s, pts)
	var sgn := -signf(dir[ax])
	var worst := 0.0
	for q in inside:
		worst = maxf(worst, h[ax] - q[ax] * sgn)
	var nl := Vector3.ZERO
	nl[ax] = sgn
	return {"depth": worst, "i": 0, "n": (xf.basis * nl).normalized()}


## The shallowest way out of a box for all the points inside it: the face (world outward normal)
## whose depth for the deepest point is the smallest, {depth, n} (depth 0: none inside). Where a
## limb's push STARTS, this is the face it just crossed (it moved a few cm since the last frame);
## the entry face seen from the shoulder picked the far face of a top when the shoulder was below
## it (a palm dipping 1 cm into a block's top was thrown 7 cm out of the front; seam fix
## 2026-09-24).
static func min_exit(s: Dictionary, pts: PackedVector3Array) -> Dictionary:
	if str(s.type) != "box":
		return penetration(s, pts)
	var xf: Transform3D = s.xform
	var best := INF
	var bn := Vector3.UP
	for k in 3:
		for sg in [-1.0, 1.0]:
			var nl := Vector3.ZERO
			nl[k] = sg
			var n := (xf.basis * nl).normalized()
			var d := depth_along(s, pts, n)
			if d >= 0.0 and d < best:
				best = d
				bn = n
	return {"depth": best if best < INF else 0.0, "i": 0, "n": bn}


## The depth of the deepest point behind the face of a box whose outward normal is n (world), or
## -1 (not a box face, or no point inside). penetration_from() with a given face. For a cylinder
## (a rung, a log; contact pass 2026-09-25): how far the points inside must move along n (across
## the axis) to be out of it, so a push can keep one direction instead of flipping to the nearest
## side as a limb crosses the axis.
static func depth_along(s: Dictionary, pts: PackedVector3Array, n: Vector3) -> float:
	if str(s.type) == "cyl":
		var a: Vector3 = s.a
		var ab: Vector3 = (s.b as Vector3) - a
		var L2 := maxf(ab.length_squared(), 1e-9)
		var axn := ab / sqrt(L2)
		var nn := n - axn * n.dot(axn)
		if nn.length() < 0.5:
			if bool(s.get("capsule", true)) or absf(n.dot(axn)) < 0.9:
				return -1.0
			# (Out through a flat end cap, fix round 3: a foot pushed back out of a log's end keeps
			# that push as it rises past the log's top, instead of the push turning to the top's
			# radial one in a frame, 1.6 cm inside while the IK's added motion caught up.)
			var L := sqrt(L2)
			var r2 := float(s.r) * float(s.r)
			var worst_a := -1.0
			for p in pts:
				var t := (p - a).dot(axn)
				if t < 0.0 or t > L or ((p - a) - axn * t).length_squared() >= r2:
					continue
				worst_a = maxf(worst_a, (L - t) if n.dot(axn) > 0.0 else t)
			return worst_a
		nn = nn.normalized()
		var r := float(s.r)
		var worst_c := -1.0
		for p in pts:
			var u := (p - a).dot(ab) / L2
			if u < 0.0 or u > 1.0:
				continue
			var q := p - (a + ab * u)
			if q.length_squared() >= r * r:
				continue
			var qn := q.dot(nn)
			worst_c = maxf(worst_c, -qn + sqrt(maxf(qn * qn - (q.length_squared() - r * r), 0.0)))
		return worst_c
	if str(s.type) != "box":
		return -1.0
	var xf: Transform3D = s.xform
	var inv := xf.affine_inverse()
	var h: Vector3 = s.half
	var nl := xf.basis.inverse() * n
	var ax := 0
	if absf(nl.y) > absf(nl[ax]):
		ax = 1
	if absf(nl.z) > absf(nl[ax]):
		ax = 2
	if absf(nl[ax]) < 0.9:
		return -1.0
	var sgn := signf(nl[ax])
	var worst := -1.0
	for p in pts:
		var q := inv * p
		var d := q.abs() - h
		if d.x > 0.0 or d.y > 0.0 or d.z > 0.0:
			continue
		worst = maxf(worst, h[ax] - q[ax] * sgn)
	return worst


## Anticipated lift of points arriving at a box's top from the side (seam fix 2026-09-24): a
## point in front of a side face (within `reach` of it, inside the face's extent) and below the
## top needs lift b * smoothstep(1 - dist / reach) (b: its depth below the top), so it reaches
## the top's height as it crosses the face. The largest such lift (0 = none), in world units along
## the box's up axis. The side is the one `from` (the limb's shoulder) is on. Used by TraversalIK
## for a hand being planted on the box: pushing it up only once it was inside threw the hand up
## by its whole depth below the top in one frame (3 cm, the standing mantle's palm pop).
static func arrival_lift(s: Dictionary, pts: PackedVector3Array, from: Vector3, reach: float) -> float:
	if str(s.type) != "box" or reach <= 0.0:
		return 0.0
	var xf: Transform3D = s.xform
	var inv := xf.affine_inverse()
	var h: Vector3 = s.half
	var a := inv * from
	# The side face the shoulder is in front of (the horizontal axis it is farthest out on).
	var ax := 0 if absf(a.x) - h.x >= absf(a.z) - h.z else 2
	var sg := signf(a[ax]) if a[ax] != 0.0 else 1.0
	var other := 2 if ax == 0 else 0
	var lift := 0.0
	for p in pts:
		var q := inv * p
		var b := h.y - q.y
		if b <= 0.0 or q.y < -h.y or absf(q[other]) > h[other]:
			continue
		var dist := q[ax] * sg - h[ax]
		if dist < 0.0 or dist >= reach:
			continue
		lift = maxf(lift, b * smoothstep(0.0, 1.0, 1.0 - dist / reach))
	return lift * xf.basis.y.length()


## Sideways push of a set of points (a sole) onto the walkable band of a narrow top: the offset,
## horizontal and across the top's long axis, that brings the points' centre within `band` of the
## top's centre line (a box's long horizontal axis through its centre; a lying cylinder's axis).
## Zero when the centre is within the band, or for other shapes (contact pass 2026-09-25: the
## balance-beam clips step up to 0.2 m beside their line; on a log that foot stood on the flank).
static func band_push(s: Dictionary, pts: PackedVector3Array, band: float) -> Vector3:
	if pts.is_empty() or band == INF:
		return Vector3.ZERO
	var c := Vector3.ZERO
	for p in pts:
		c += p
	c /= float(pts.size())
	match str(s.type):
		"box":
			var xf: Transform3D = s.xform
			var h: Vector3 = s.half
			var q := xf.affine_inverse() * c
			var ax := 0 if h.x <= h.z else 2
			var off := q[ax]
			if absf(off) <= band:
				return Vector3.ZERO
			var d := Vector3.ZERO
			d[ax] = -signf(off) * (absf(off) - band)
			var w := xf.basis * d
			w.y = 0.0
			return w
		"cyl":
			var a: Vector3 = s.a
			var b: Vector3 = s.b
			var ab := b - a
			var dh := Vector3(ab.x, 0.0, ab.z)
			if dh.length() < 1e-4 or absf(ab.normalized().y) > 0.5:
				return Vector3.ZERO
			var perp := Vector3.UP.cross(dh.normalized()).normalized()
			var off := (c - a).dot(perp)
			if absf(off) <= band:
				return Vector3.ZERO
			return -perp * signf(off) * (absf(off) - band)
	return Vector3.ZERO


## Horizontal clamp of a point into a box's top footprint (margin m): the world offset that
## moves it inside (zero when inside or for non-box surfaces).
static func footprint_push(s: Dictionary, p: Vector3, m: float) -> Vector3:
	if str(s.type) != "box":
		return Vector3.ZERO
	var xf: Transform3D = s.xform
	var h: Vector3 = s.half
	var q := xf.affine_inverse() * p
	var qx := clampf(q.x, -h.x + m, h.x - m) if h.x > m else 0.0
	var qz := clampf(q.z, -h.z + m, h.z - m) if h.z > m else 0.0
	return xf.basis * Vector3(qx - q.x, 0.0, qz - q.z)
