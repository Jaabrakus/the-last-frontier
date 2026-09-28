extends RefCounted
## GripGauge (push n01c; user 2026-09-26: "for the one hand hold the left hand doesn grip it properly"): how the LEFT
## hand really holds the long gun in the middle grip, measured on the skinned skin against the gun's own meshes.
## Read-only (bone reads and mesh data); used by tests/anim/test_hand_holds.gd and tests/torch/tools/hold_shots.gd.
##
##  - The pose: the skeleton's FINAL pose (read in Skeleton3D.skeleton_updated, after every SkeletonModifier3D:
##    get_bone_global_pose outside the modifier pass returns the pose before the modifiers), cached every update
##    (final_pose()).
##  - The hand: every skin vertex of the player's body mesh (CharacterBodyMesh "Body", its skin surfaces) whose strongest
##    bone is a left-hand bone, skinned on the CPU
##    each measure() from the FINAL pose (Skeleton3D.get_bone_global_pose after the modifiers: call it from
##    skeleton_updated or after a rendered frame) with the body's own Skin (bind * vertex, as CharacterBodyMesh builds
##    it; blend shapes are left out: none moves the hands). Each vertex is labelled by its bone: palm (l_palm and the
##    metacarpals), index / middle / ring / pinky (the finger's phalanges; the pinky's first bone is its metacarpal),
##    thumb.
##  - The gun: its model's triangles (every MeshInstance3D of Weapon.model except the ramrod, which slides) sliced
##    across the barrel every SLICE_M over SPAN_M round the grip into 2D outlines per mesh part; a point's signed
##    distance is the distance to the nearest outline edge of its slice, negative inside a part (ray parity per part).
##  - Per frame: palm_gap (the palm vertex nearest the gun; <= 0.01 m wanted), depth (the deepest hand vertex inside
##    the gun: fingers through the wood), the gap of each finger and the thumb (its nearest vertex), closed (the
##    fingers index..pinky within FINGER_TOUCH_M of the wood), wrap (the share of the outline's circumference that hand
##    vertices within WRAP_M of the surface cover, in 10-degree sectors round its middle), grip_z (m along the barrel
##    from the wrist of the stock to the palm's nearest point) and far_side (whether the thumb and the fingertips are
##    on opposite sides of the gun).

const SLICE_M := 0.005
const SPAN_M := 0.14
const FINGER_TOUCH_M := 0.012
const WRAP_M := 0.012
const SECTORS := 36
const HAND_BONES := {"l_palm": "palm", "l_index_metacarpal": "palm", "l_middle_metacarpal": "palm",
		"l_ring_metacarpal": "palm", "l_pinkya": "palm", "l_indexa": "index", "l_indexb": "index", "l_indexc": "index",
		"l_middlea": "middle", "l_middleb": "middle", "l_middlec": "middle", "l_ringa": "ring", "l_ringb": "ring",
		"l_ringc": "ring", "l_pinkyb": "pinky", "l_pinkyc": "pinky", "l_pinkyd": "pinky", "l_thumba": "thumb",
		"l_thumbb": "thumb", "l_thumbc": "thumb"}
## The distal phalanges (the fingertips' side).
const TIP_BONES := ["l_indexc", "l_middlec", "l_ringc", "l_pinkyd", "l_thumbc"]
const FINGERS := ["index", "middle", "ring", "pinky"]

var sk: Skeleton3D
var model: Node3D
var ok := false
var info := ""
## The hand: per vertex the bone indices, weights and bind-space positions (flattened, `per` entries each), region, tip.
var _vb := PackedInt32Array()
var _vw := PackedFloat32Array()
var _vl := PackedVector3Array()
var _region: PackedStringArray = []
var _tip: Array[bool] = []
var _per := 0
var _n := 0
## The gun's slices: z0 (model space), then per slice [ {part: [PackedVector2Array segs (pairs)]} ], centre (2D).
var _z0 := 0.0
var _slices: Array = []
var _centres: Array = []


## The final pose of the bones the hand uses (bone -> Transform3D, skeleton space), refreshed every skeleton update.
var _final := {}
var _want := {}


## Sets up for `player`'s body and the gun `gun_model` (Weapon.model) gripped round `grip_z` (model z, the barrel -Z).
func setup(player: Node, gun_model: Node3D, grip_z: float) -> bool:
	watch(player.skeleton)
	model = gun_model
	ok = _hand(player) and _gun(grip_z)
	for b in _vb:
		_want[b] = true
	return ok


## Caches the final pose of the skeleton's bones on every update (also usable without setup(): final_pose()).
func watch(p_sk: Skeleton3D) -> void:
	if sk == p_sk:
		return
	sk = p_sk
	for bn in ["l_palm", "l_hand_prop_attachment", "r_hand_prop_attachment", "l_wrist", "r_palm"]:
		_want[sk.find_bone(bn)] = true
	sk.skeleton_updated.connect(_on_updated)


func _on_updated() -> void:
	if _want.size() <= 5:
		for i in sk.get_bone_count():
			_final[i] = sk.get_bone_global_pose(i)
		return
	for b: int in _want:
		if b >= 0:
			_final[b] = sk.get_bone_global_pose(b)


## A bone's final global pose (skeleton space) at the last skeleton update.
func final_pose(bone_name: String) -> Transform3D:
	var b := sk.find_bone(bone_name)
	return _final.get(b, sk.get_bone_global_pose(b))


func _hand(_player: Node) -> bool:
	var body := sk.get_node_or_null("Body") as CharacterBodyMesh
	var meshes: Array = body.meshes if body != null else []
	var names := {}
	for bn: String in HAND_BONES:
		var b := sk.find_bone(bn)
		if b >= 0:
			names[b] = bn
	for mi: MeshInstance3D in meshes:
		if mi.skin == null or mi.mesh == null or not mi.visible:
			continue
		if "body" not in String(mi.name).to_lower():
			continue
		var skin := mi.skin
		var bind_bone := PackedInt32Array()
		var bind_xf: Array[Transform3D] = []
		for i in skin.get_bind_count():
			var bb := skin.get_bind_bone(i)
			if bb < 0:
				bb = sk.find_bone(skin.get_bind_name(i))
			bind_bone.append(bb)
			bind_xf.append(skin.get_bind_pose(i))
		var skin_only := false
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if m != null and m.resource_name.to_lower().contains("skin"):
				skin_only = true
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			if skin_only and (mat == null or not mat.resource_name.to_lower().contains("skin")):
				continue
			var arr := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones = arr[Mesh.ARRAY_BONES]
			var weights = arr[Mesh.ARRAY_WEIGHTS]
			if bones == null or weights == null or verts.is_empty():
				continue
			var per: int = bones.size() / verts.size()
			if _per == 0:
				_per = per
			info = "%s%s " % [info, mi.name]
			for vi in verts.size():
				var top_b := -1
				var top_w := 0.0
				for k in per:
					var w: float = weights[vi * per + k]
					if w > top_w:
						top_w = w
						top_b = bind_bone[bones[vi * per + k]]
				if not names.has(top_b):
					continue
				for k in _per:
					var w: float = weights[vi * per + k] if k < per else 0.0
					var bi: int = bones[vi * per + k] if k < per else 0
					_vb.append(bind_bone[bi])
					_vw.append(w)
					_vl.append(bind_xf[bi] * verts[vi])
				var bn: String = names[top_b]
				_region.append(String(HAND_BONES[bn]))
				_tip.append(bn in TIP_BONES)
				_n += 1
	if _n == 0:
		info = "no left-hand vertices on the body mesh"
		return false
	return true


func _gun(grip_z: float) -> bool:
	if model == null:
		info = "no gun model"
		return false
	_z0 = grip_z - SPAN_M * 0.5
	var count := int(SPAN_M / SLICE_M) + 1
	_slices.clear()
	_centres.clear()
	for i in count:
		_slices.append({})
	var parts := 0
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or String(mi.name).to_lower().contains("ramrod"):
			continue
		var xf := _local_to(model, mi)
		parts += 1
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx = arr[Mesh.ARRAY_INDEX]
			var pts := PackedVector3Array()
			pts.resize(verts.size())
			for vi in verts.size():
				pts[vi] = xf * verts[vi]
			var tri_n: int = (idx.size() if idx != null and idx.size() > 0 else verts.size()) / 3
			var key := "%d:%d" % [mi.get_instance_id(), s]
			for t in tri_n:
				var a: Vector3
				var b: Vector3
				var c: Vector3
				if idx != null and idx.size() > 0:
					a = pts[idx[t * 3]]
					b = pts[idx[t * 3 + 1]]
					c = pts[idx[t * 3 + 2]]
				else:
					a = pts[t * 3]
					b = pts[t * 3 + 1]
					c = pts[t * 3 + 2]
				var zmin := minf(a.z, minf(b.z, c.z))
				var zmax := maxf(a.z, maxf(b.z, c.z))
				var i0 := maxi(int(ceil((zmin - _z0) / SLICE_M)), 0)
				var i1 := mini(int(floor((zmax - _z0) / SLICE_M)), count - 1)
				for i in range(i0, i1 + 1):
					var zc := _z0 + i * SLICE_M
					var seg := _cut(a, b, c, zc)
					if seg.is_empty():
						continue
					var sl: Dictionary = _slices[i]
					if not sl.has(key):
						sl[key] = PackedVector2Array()
					var ps: PackedVector2Array = sl[key]
					ps.append(seg[0])
					ps.append(seg[1])
					sl[key] = ps
	for i in count:
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for key: String in _slices[i]:
			for v: Vector2 in (_slices[i][key] as PackedVector2Array):
				lo = lo.min(v)
				hi = hi.max(v)
		_centres.append((lo + hi) * 0.5 if lo.x < INF else Vector2(0.0, 0.03))
	var mid: int = count / 2
	var lo2 := Vector2(INF, INF)
	var hi2 := Vector2(-INF, -INF)
	for key: String in _slices[mid]:
		for v: Vector2 in (_slices[mid][key] as PackedVector2Array):
			lo2 = lo2.min(v)
			hi2 = hi2.max(v)
	info = "gun %s: %d parts; at z %.3f the outline spans x %.3f..%.3f y %.3f..%.3f" % [model.name, parts, _z0 + mid * SLICE_M,
			lo2.x, hi2.x, lo2.y, hi2.y]
	return lo2.x < INF


## The segment where triangle abc crosses the plane z = zc (x, y), or [] when it does not.
static func _cut(a: Vector3, b: Vector3, c: Vector3, zc: float) -> Array:
	var pts: Array[Vector2] = []
	var vs := [a, b, c]
	for k in 3:
		var p: Vector3 = vs[k]
		var q: Vector3 = vs[(k + 1) % 3]
		var sp := p.z - zc
		var sq := q.z - zc
		if (sp < 0.0 and sq >= 0.0) or (sp >= 0.0 and sq < 0.0):
			var t := sp / (sp - sq)
			var r := p.lerp(q, t)
			pts.append(Vector2(r.x, r.y))
	if pts.size() < 2:
		return []
	return [pts[0], pts[1]]


static func _local_to(root: Node3D, n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var c: Node = n
	while c != root and c != null:
		if c is Node3D:
			xf = (c as Node3D).transform * xf
		c = c.get_parent()
	return xf


## Signed distance (m) of a model-space point to the gun's surface (negative inside), and its sector round the
## outline's middle: [d, sector] ([INF, -1] outside the sliced span).
func distance(q: Vector3) -> Array:
	var i := int(round((q.z - _z0) / SLICE_M))
	if i < 0 or i >= _slices.size():
		return [INF, -1]
	var p := Vector2(q.x, q.y)
	var best := INF
	var inside := false
	for key: String in _slices[i]:
		var segs: PackedVector2Array = _slices[i][key]
		var crossings := 0
		for k in range(0, segs.size(), 2):
			var a := segs[k]
			var b := segs[k + 1]
			var ab := b - a
			var l2 := ab.length_squared()
			var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0) if l2 > 1e-12 else 0.0
			best = minf(best, p.distance_squared_to(a + ab * t))
			if (a.y > p.y) != (b.y > p.y):
				var xi := a.x + (p.y - a.y) / (b.y - a.y) * (b.x - a.x)
				if xi > p.x:
					crossings += 1
		if crossings % 2 == 1:
			inside = true
	var d := sqrt(best)
	var c: Vector2 = _centres[i]
	var ang := atan2(p.y - c.y, p.x - c.x)
	var sector := int(floor((ang + PI) / TAU * SECTORS)) % SECTORS
	return [-d if inside else d, sector]


## The hand's grip on the gun now (see the header). Empty when not set up.
func measure() -> Dictionary:
	if not ok or not is_instance_valid(model) or not is_instance_valid(sk):
		return {}
	var poses := {}
	var to_model := model.global_transform.affine_inverse() * sk.global_transform
	var gaps := {"palm": INF, "index": INF, "middle": INF, "ring": INF, "pinky": INF, "thumb": INF}
	var tip_gap := {"index": INF, "middle": INF, "ring": INF, "pinky": INF, "thumb": INF}
	var depth := 0.0
	var inside_n := 0
	var sectors := {}
	var palm_q := Vector3.ZERO
	var palm_best := INF
	var thumb_sec := []
	var tip_sec := []
	for v in _n:
		var p := Vector3.ZERO
		for k in _per:
			var w := _vw[v * _per + k]
			if w <= 0.0:
				continue
			var b := _vb[v * _per + k]
			if not poses.has(b):
				poses[b] = _final.get(b, sk.get_bone_global_pose(b))
			p += ((poses[b] as Transform3D) * _vl[v * _per + k]) * w
		var q := to_model * p
		var r := distance(q)
		var d: float = r[0]
		if d == INF:
			continue
		var reg := _region[v]
		if d < gaps[reg]:
			gaps[reg] = d
		if reg == "palm" and d < palm_best:
			palm_best = d
			palm_q = q
		if _tip[v] and d < tip_gap[reg]:
			tip_gap[reg] = d
		if d < -depth:
			depth = -d
		if d < -0.003:
			inside_n += 1
		if d < WRAP_M:
			sectors[int(r[1])] = true
			if _tip[v] and reg == "thumb":
				thumb_sec.append(int(r[1]))
			elif _tip[v] and reg in FINGERS:
				tip_sec.append(int(r[1]))
	var closed := 0
	for f: String in FINGERS:
		if float(gaps[f]) <= FINGER_TOUCH_M:
			closed += 1
	var far := false
	if not thumb_sec.is_empty() and not tip_sec.is_empty():
		var a := _mean_sector(thumb_sec)
		var b := _mean_sector(tip_sec)
		far = absf(wrapf(a - b, -PI, PI)) > deg_to_rad(90.0)
	return {"palm_gap": gaps.palm, "index": gaps.index, "middle": gaps.middle, "ring": gaps.ring, "pinky": gaps.pinky,
			"thumb": gaps.thumb, "tips": tip_gap, "closed": closed, "depth": depth, "inside_n": inside_n,
			"wrap": float(sectors.size()) / SECTORS, "grip_z": -palm_q.z, "far_side": far}


static func _mean_sector(secs: Array) -> float:
	var s := Vector2.ZERO
	for k: int in secs:
		var a := (k + 0.5) / SECTORS * TAU - PI
		s += Vector2(cos(a), sin(a))
	return s.angle()


## One line for logs.
static func line(m: Dictionary) -> String:
	if m.is_empty():
		return "grip: -"
	var t: Dictionary = m.tips
	return "grip: palm %.1f cm | fingers i %.1f m %.1f r %.1f p %.1f thumb %.1f cm | tips %.1f %.1f %.1f %.1f %.1f | closed %d/4 | depth %.1f cm (%d in) | wrap %.0f%% | at %.2f m | far side %s" % [
			float(m.palm_gap) * 100.0, float(m.index) * 100.0, float(m.middle) * 100.0, float(m.ring) * 100.0,
			float(m.pinky) * 100.0, float(m.thumb) * 100.0, float(t.index) * 100.0, float(t.middle) * 100.0,
			float(t.ring) * 100.0, float(t.pinky) * 100.0, float(t.thumb) * 100.0, int(m.closed), float(m.depth) * 100.0,
			int(m.inside_n), float(m.wrap) * 100.0, float(m.grip_z), m.far_side]
