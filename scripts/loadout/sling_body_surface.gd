class_name SlingBodySurface
extends RefCounted
## The outer torso / hip / thigh surface of the skinned body (CharacterBodyMesh), for the sling rig:
##
##  - anchors: pick a surface vertex at the bind pose (nearest to a point, or the outermost one at an
##    angle and height around the torso axis) and follow it with its skin weights every frame
##    (two-anchor items, strap anchors);
##  - the penetration test: skin the whole subset and take signed distances (the survey's method,
##    tools/loadout/measure_body_fit.gd _collect_surface / _sdist, with the same filters).
##
## Space: skeleton space (+Y up, the character faces +Z, character right = -X); angles about the torso
## axis: 0 front, 90 character right, 180 back, 270 left. Bone globals `g` are skeleton-space bone
## poses: body.skinning_globals() (tests, helper bones driven) or, inside Skeleton3D.skeleton_updated,
## skeleton.get_bone_global_pose() (the driven helpers are visible there).
##
## Surface = the Clothes and Gear meshes of the body (the outfit, not the skin under it), torso rows
## only (y 0.42-1.58 at the bind pose), vertices whose dominant bone is not an arm, hand, head or lower
## leg bone, outward normals only; belt and strap edge vertices are dropped (their split normals spoil
## the plane distance). Material labels in `skip` (default: the legacy horn) are left out.

const SURF_Y := Vector2(0.42, 1.58)
const CELL := 0.05
const MESHES := ["Clothes", "Gear"]
const DEFAULT_SKIP := ["horn", "wood", "horn_tip"]
## Beyond this distance from the nearest outer vertex the signed distance takes its side from the mean
## normal of the 5 nearest vertices (see sdist()).
const FAR_M := 0.05
const LIMB_PREFIX := ["l_shoulder", "r_shoulder", "l_elbow", "r_elbow", "l_forarm", "r_forarm", "l_wrist", "r_wrist",
		"l_palm", "r_palm", "l_index", "r_index", "l_middle", "r_middle", "l_ring", "r_ring", "l_pinky", "r_pinky",
		"l_thumb", "r_thumb", "heada", "headb", "neck", "wrinklemaps", "l_knee", "r_knee", "l_ankle", "r_ankle",
		"l_heel", "r_heel", "l_ball", "r_ball"]
const AXIS_CHAIN := ["pelvis", "spinea", "spineb", "spinec", "spined", "neck"]

var skeleton: Skeleton3D
var bind_g: Array = []
var sv := PackedVector3Array()     ## bind positions
var sn := PackedVector3Array()     ## bind normals
var sbo := PackedInt32Array()      ## 4 skin bind indices per vertex
var sw := PackedFloat32Array()     ## 4 weights per vertex
var slab := PackedStringArray()    ## material label per vertex
var sskin_i := PackedInt32Array()  ## index into skins per vertex
var skins: Array[Skin] = []
## posed surface (skin_all)
var pv := PackedVector3Array()
var pn := PackedVector3Array()
var _hash := {}
var _axis_pts: Array[Vector3] = []


## Collects the surface of `body` (null when the body has no Clothes / Gear meshes).
static func from_body(body: CharacterBodyMesh, skip: Array = DEFAULT_SKIP) -> SlingBodySurface:
	if body == null or body.skeleton == null:
		return null
	var s := SlingBodySurface.new()
	s.skeleton = body.skeleton
	var ap: AnimationPlayer = null
	var aps := body.skeleton.get_parent().find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		ap = aps[0]
	var clip: Animation = null
	if ap and ap.has_animation("actor_b/null-add"):
		clip = ap.get_animation("actor_b/null-add")
	if clip:
		s.bind_g = CharacterBodyMesh.bind_pose_globals(body.skeleton, clip)
	else:
		for b in body.skeleton.get_bone_count():
			s.bind_g.append(body.skeleton.get_bone_global_rest(b))
	for bn: String in AXIS_CHAIN:
		var b := body.skeleton.find_bone(bn)
		s._axis_pts.append((s.bind_g[b] as Transform3D).origin if b >= 0 else Vector3.ZERO)
	s._collect(body, skip)
	return s if s.sv.size() > 0 else null


func _collect(body: CharacterBodyMesh, skip: Array) -> void:
	for mi in body.meshes:
		if not is_instance_valid(mi) or not String(mi.name) in MESHES or not (mi.mesh is ArrayMesh) or mi.skin == null:
			continue
		var am := mi.mesh as ArrayMesh
		var skin_idx := skins.find(mi.skin)
		if skin_idx < 0:
			skins.append(mi.skin)
			skin_idx = skins.size() - 1
		for s in am.get_surface_count():
			var mat := am.surface_get_material(s)
			var label: String = mat.resource_name if mat and not mat.resource_name.is_empty() else "%s_%d" % [mi.name, s]
			if skip.has(label):
				continue
			var arr := am.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var bo: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			if bo.is_empty() or w.is_empty():
				continue
			var nb := bo.size() / maxi(v.size(), 1)
			var skin: Skin = mi.skin
			for i in v.size():
				var p := v[i]
				if p.y < SURF_Y.x or p.y > SURF_Y.y:
					continue
				var best := 0
				for k in nb:
					if w[i * nb + k] > w[i * nb + best]:
						best = k
				var dom := skeleton.get_bone_name(skin.get_bind_bone(bo[i * nb + best]))
				if _is_limb_bone(dom):
					continue
				var c := axis_at(p.y)
				var rad := Vector3(p.x - c.x, 0.0, p.z - c.z)
				if rad.length() > 0.01 and nr[i].dot(rad.normalized()) < -0.2:
					continue
				if label in ["belt", "strap"] and rad.length() > 0.01 and absf(nr[i].dot(rad.normalized())) < 0.5:
					continue
				sv.append(p)
				sn.append(nr[i])
				slab.append(label)
				sskin_i.append(skin_idx)
				var ws := 0.0
				for k in 4:
					if k < nb:
						sbo.append(bo[i * nb + k])
						sw.append(w[i * nb + k])
						ws += w[i * nb + k]
					else:
						sbo.append(0)
						sw.append(0.0)
				if ws > 0.0 and absf(ws - 1.0) > 1e-3:
					for k in 4:
						sw[sw.size() - 4 + k] /= ws
	pv.resize(sv.size())
	pn.resize(sv.size())


static func _is_limb_bone(bn: String) -> bool:
	for p: String in LIMB_PREFIX:
		if bn.begins_with(p):
			return true
	return false


## Torso axis point at height y (bind pose), from the pelvis-spine-neck joints.
func axis_at(y: float) -> Vector3:
	if _axis_pts.is_empty():
		return Vector3(0, y, 0)
	if y <= _axis_pts[0].y:
		return _axis_pts[0]
	for i in range(1, _axis_pts.size()):
		if y <= _axis_pts[i].y:
			var a := _axis_pts[i - 1]
			var b := _axis_pts[i]
			return a.lerp(b, (y - a.y) / maxf(b.y - a.y, 1e-6))
	return _axis_pts[_axis_pts.size() - 1]


static func angle_of(d: Vector3) -> float:
	return fposmod(rad_to_deg(atan2(-d.x, d.z)), 360.0)


static func dir_of(angle_deg: float) -> Vector3:
	var a := deg_to_rad(angle_deg)
	return Vector3(-sin(a), 0.0, cos(a))


## Outward horizontal normal (bind) at a bind point: from the torso axis to the point.
func radial_normal(p: Vector3) -> Vector3:
	var c := axis_at(p.y)
	var d := Vector3(p.x - c.x, 0.0, p.z - c.z)
	return d.normalized() if d.length() > 1e-4 else Vector3.BACK


# --- anchors ----------------------------------------------------------------------------------

## Index of the surface vertex nearest to bind point p (optionally with a normal within 70 deg of n).
func nearest(p: Vector3, n := Vector3.ZERO) -> int:
	var best := -1
	var bd := INF
	for i in sv.size():
		if n != Vector3.ZERO and sn[i].dot(n) < 0.34:
			continue
		var d := sv[i].distance_squared_to(p)
		if d < bd:
			bd = d
			best = i
	return best


## Index of the surface vertex of material `label` nearest to bind point p (-1 when none within 8 cm).
func nearest_label(p: Vector3, label: String) -> int:
	var best := -1
	var bd := 0.08 * 0.08
	for i in sv.size():
		if slab[i] != label:
			continue
		var d := sv[i].distance_squared_to(p)
		if d < bd:
			bd = d
			best = i
	return best


## Outermost surface vertex around the torso at (angle, y) (within +/- 7.5 deg and 2.5 cm).
func outer_at(angle_deg: float, y: float) -> int:
	var c := axis_at(y)
	var best := -1
	var br := -1.0
	for i in sv.size():
		var p := sv[i]
		if absf(p.y - y) > 0.025:
			continue
		var dd := Vector3(p.x - c.x, 0.0, p.z - c.z)
		if dd.length() < 1e-4 or absf(wrapf(angle_of(dd) - angle_deg, -180.0, 180.0)) > 7.5:
			continue
		if dd.length() > br:
			br = dd.length()
			best = i
	return best


## Highest surface vertex over a shoulder (side 1 = left, -1 = right), for strap anchors.
func shoulder_top(side: float) -> int:
	var best := -1
	var by := -INF
	for i in sv.size():
		var p := sv[i]
		if p.x * side < 0.075 or p.x * side > 0.14 or p.z < -0.07 or p.z > 0.05:
			continue
		if p.y > by:
			by = p.y
			best = i
	return best


## Skinning matrices (bind bone global x inverse bind) per skin for bone globals g, only for the bones
## listed (all when empty).
func skin_mats(g: Array) -> Array:
	var res: Array = []
	for skin: Skin in skins:
		var m: Array[Transform3D] = []
		m.resize(skin.get_bind_count())
		for b in skin.get_bind_count():
			var bi := skin.get_bind_bone(b)
			if bi >= 0 and bi < g.size() and g[bi] != null:
				m[b] = (g[bi] as Transform3D) * skin.get_bind_pose(b)
			else:
				m[b] = Transform3D.IDENTITY
		res.append(m)
	return res


## Skeleton bone indices the vertex vi is skinned to (for a lazy bone-global lookup).
func bones_of(vi: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var skin: Skin = skins[sskin_i[vi]]
	for k in 4:
		if sw[4 * vi + k] > 0.0:
			out.append(skin.get_bind_bone(sbo[4 * vi + k]))
	return out


## Bind point p carried by the skin weights of vertex vi, with bone globals from `gl` (a Callable
## bone -> Transform3D, or an Array of globals).
func skin_point(vi: int, p: Vector3, gl: Variant) -> Vector3:
	var skin: Skin = skins[sskin_i[vi]]
	var acc := Vector3.ZERO
	for k in 4:
		var wk := sw[4 * vi + k]
		if wk <= 0.0:
			continue
		var bind_i := sbo[4 * vi + k]
		var bi := skin.get_bind_bone(bind_i)
		var gb: Transform3D = (gl as Callable).call(bi) if gl is Callable else (gl as Array)[bi]
		acc += (gb * skin.get_bind_pose(bind_i) * p) * wk
	return acc


## Normal (bind n) carried by vertex vi's weights.
func skin_normal(vi: int, n: Vector3, gl: Variant) -> Vector3:
	var skin: Skin = skins[sskin_i[vi]]
	var acc := Vector3.ZERO
	for k in 4:
		var wk := sw[4 * vi + k]
		if wk <= 0.0:
			continue
		var bind_i := sbo[4 * vi + k]
		var bi := skin.get_bind_bone(bind_i)
		var gb: Transform3D = (gl as Callable).call(bi) if gl is Callable else (gl as Array)[bi]
		acc += ((gb * skin.get_bind_pose(bind_i)).basis * n) * wk
	return acc.normalized() if acc.length() > 1e-6 else n


## A copy holding only the vertices `idx` (the rig's local surface around the hanging items).
func subset(idx: PackedInt32Array) -> SlingBodySurface:
	var o := SlingBodySurface.new()
	o.skeleton = skeleton
	o.bind_g = bind_g
	o.skins = skins
	o._axis_pts = _axis_pts
	for i in idx:
		o.sv.append(sv[i])
		o.sn.append(sn[i])
		o.slab.append(slab[i])
		o.sskin_i.append(sskin_i[i])
		for k in 4:
			o.sbo.append(sbo[4 * i + k])
			o.sw.append(sw[4 * i + k])
	o.pv.resize(o.sv.size())
	o.pn.resize(o.sv.size())
	return o


## Skeleton bone indices any vertex is skinned to.
func used_bones() -> PackedInt32Array:
	var seen := {}
	for i in sv.size():
		var skin: Skin = skins[sskin_i[i]]
		for k in 4:
			if sw[4 * i + k] > 0.0:
				seen[skin.get_bind_bone(sbo[4 * i + k])] = true
	return PackedInt32Array(seen.keys())


# --- whole-surface skinning and signed distance (tests) ---------------------------------------

func skin_all(g: Array) -> void:
	var mats := skin_mats(g)
	_hash.clear()
	for i in sv.size():
		var m: Array = mats[sskin_i[i]]
		var acc := Vector3.ZERO
		var an := Vector3.ZERO
		for k in 4:
			var wk := sw[4 * i + k]
			if wk > 0.0:
				var mk: Transform3D = m[sbo[4 * i + k]]
				acc += (mk * sv[i]) * wk
				an += (mk.basis * sn[i]) * wk
		pv[i] = acc
		pn[i] = an.normalized()
		var key := Vector3i(floori(acc.x / CELL), floori(acc.y / CELL), floori(acc.z / CELL))
		if _hash.has(key):
			(_hash[key] as Array).append(i)
		else:
			_hash[key] = [i]


## [signed distance to the posed outer surface (median plane distance of the 5 nearest vertices),
## label of the nearest vertex]. Positive = outside. After skin_all().
func sdist(p: Vector3, skip: Array = []) -> Array:
	var c := Vector3i(floori(p.x / CELL), floori(p.y / CELL), floori(p.z / CELL))
	for ring in [1, 2, 3, 5]:
		var near_i: Array = []
		var near_d: Array = []
		for dx in range(-ring, ring + 1):
			for dy in range(-ring, ring + 1):
				for dz in range(-ring, ring + 1):
					var key := c + Vector3i(dx, dy, dz)
					if not _hash.has(key):
						continue
					for i: int in _hash[key]:
						if not skip.is_empty() and slab[i] in skip:
							continue
						var d := p.distance_squared_to(pv[i])
						if near_d.size() < 5 or d < float(near_d[near_d.size() - 1]):
							var at := near_d.bsearch(d)
							near_d.insert(at, d)
							near_i.insert(at, i)
							if near_d.size() > 5:
								near_d.pop_back()
								near_i.pop_back()
		if not near_i.is_empty() and sqrt(float(near_d[0])) <= ring * CELL:
			var dn := sqrt(float(near_d[0]))
			if dn > FAR_M:
				# far from the surface the plane distances of split-normal seams (a coat ledge whose
				# normals point up) can flip the median; the side comes from the mean normal instead
				var cen := Vector3.ZERO
				var nsum := Vector3.ZERO
				for i: int in near_i:
					cen += pv[i]
					nsum += pn[i]
				cen /= near_i.size()
				return [dn if (p - cen).dot(nsum) >= 0.0 else -dn, slab[near_i[0]]]
			var pd: Array = []
			for i: int in near_i:
				pd.append((p - pv[i]).dot(pn[i]))
			pd.sort()
			return [float(pd[pd.size() / 2]), slab[near_i[0]]]
	return [9.99, ""]
