class_name TravContactProbes
extends RefCounted
## Mesh-calibrated contact points of the hands, feet and knees (design 8.4, "contacts land on
## the real geometry"). data/traversal/contact_probes.json (tools/traversal/
## calibrate_contact_probes.gd) holds, per limb, the body-mesh vertices that ever carry the
## lowest point of that limb in the traversal clips (plus the limb's bind-pose extremes), with
## their skin weights and bind offsets. Evaluating them with linear blend skinning gives the
## rendered palm / shoe sole / kneecap surface, so the warp targets, the IK and the checks all
## use the surface the player sees instead of bone origins.
##
##   var cp := TravContactProbes.shared()
##   var pts := cp.eval_globals("l_hand", g)             # g: bone index -> Transform3D (Array or Dictionary)
##   var c := TravContactProbes.contact_of(pts)          # {y: lowest, xz: soft-min centre, i: argmin}
##
## Probe vertices weighted to the body's driven helper bones (forearm twist) are left out: the
## helpers are only driven by CharacterBodyMesh after every other modifier. The calibration
## reports the error of the probe set against the full CPU-skinned limb (a few mm).

const PATH := "res://data/traversal/contact_probes.json"
## Soft-min width for the contact's horizontal position (m): vertices within a few mm of the
## lowest one share the xz, so the contact point does not jump between vertices.
const SOFT := 0.004

static var _shared: TravContactProbes = null

var ok := false
var error := ""
var meta := {}
## limb -> {names: PackedStringArray (4 / vertex), weights: PackedFloat32Array, offs: PackedVector3Array}
var limbs := {}
var _index_cache := {}   ## skeleton-name signature -> {limb: PackedInt32Array}
var _world_cache := {}   ## "limb|skeleton id" -> the compacted influences of eval_world()


static func shared() -> TravContactProbes:
	if _shared == null:
		_shared = TravContactProbes.new()
		_shared.load_file(PATH)
	return _shared


static func reload() -> TravContactProbes:
	_shared = null
	return shared()


func load_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		error = "missing " + path
		return false
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not d is Dictionary:
		error = "cannot parse " + path
		return false
	meta = (d as Dictionary).get("meta", {})
	for limb: String in (d as Dictionary).get("limbs", {}):
		var L: Dictionary = d.limbs[limb]
		var names := PackedStringArray()
		var ws := PackedFloat32Array()
		var offs := PackedVector3Array()
		for v: Array in L.verts:
			# [n0, n1, n2, n3, w0, w1, w2, w3, o0x, o0y, o0z, ... o3z]
			for k in 4:
				names.append(str(v[k]))
				ws.append(float(v[4 + k]))
				offs.append(Vector3(float(v[8 + 3 * k]), float(v[9 + 3 * k]), float(v[10 + 3 * k])))
		limbs[limb] = {"names": names, "weights": ws, "offs": offs}
	# Dense guard sets for the IK (contact pass 2026-09-25): the guard set (one vertex per 2 cm cell
	# of the bind pose) together with the contact probes (the vertices that are ever the lowest).
	# The decimated set alone let a planted palm's lowest vertices stay 1.1 cm inside the block it
	# was pushed out of (the standing mantle's hand plant); the probes are exactly those vertices.
	# (Named "*_dense_guard": the clip sampler skips "*_guard" sets.)
	var src: Dictionary = (d as Dictionary).get("limbs", {})
	for limb: String in src.keys():
		var gk := limb + "_guard"
		if limb.ends_with("_guard") or not src.has(gk) or not limbs.has(gk):
			continue
		var seen := {}
		for vid in (src[gk] as Dictionary).get("vertex_ids", []):
			seen[int(vid)] = true
		var G: Dictionary = limbs[gk]
		var names2: PackedStringArray = (G.names as PackedStringArray).duplicate()
		var ws2: PackedFloat32Array = (G.weights as PackedFloat32Array).duplicate()
		var offs2: PackedVector3Array = (G.offs as PackedVector3Array).duplicate()
		var P: Dictionary = limbs[limb]
		var ids: Array = (src[limb] as Dictionary).get("vertex_ids", [])
		for i in ids.size():
			if seen.has(int(ids[i])):
				continue
			for k in 4:
				names2.append((P.names as PackedStringArray)[4 * i + k])
				ws2.append((P.weights as PackedFloat32Array)[4 * i + k])
				offs2.append((P.offs as PackedVector3Array)[4 * i + k])
		limbs[limb + "_dense_guard"] = {"names": names2, "weights": ws2, "offs": offs2}
	ok = not limbs.is_empty()
	return ok


func has_limb(limb: String) -> bool:
	return limbs.has(limb)


## Every bone name the probes use.
func bone_names() -> PackedStringArray:
	var seen := {}
	for limb: String in limbs:
		for i in (limbs[limb].names as PackedStringArray).size():
			if float(limbs[limb].weights[i]) > 0.0:
				seen[limbs[limb].names[i]] = true
	return PackedStringArray(seen.keys())


## Bone indices of a limb's probes for a skeleton (name -> index via `find`: Callable(String) -> int).
func indices(limb: String, find: Callable, key := "") -> PackedInt32Array:
	if key != "" and _index_cache.has(key) and (_index_cache[key] as Dictionary).has(limb):
		return _index_cache[key][limb]
	var names: PackedStringArray = limbs[limb].names
	var out := PackedInt32Array()
	out.resize(names.size())
	for i in names.size():
		out[i] = int(find.call(names[i]))
	if key != "":
		if not _index_cache.has(key):
			_index_cache[key] = {}
		_index_cache[key][limb] = out
	return out


## Probe positions for bone globals `g` (Array or Dictionary indexed by bone) and the limb's
## bone indices `idx` (indices()).
func eval_globals(limb: String, g, idx: PackedInt32Array) -> PackedVector3Array:
	var L: Dictionary = limbs[limb]
	var ws: PackedFloat32Array = L.weights
	var offs: PackedVector3Array = L.offs
	var n := ws.size() / 4
	var out := PackedVector3Array()
	out.resize(n)
	for i in n:
		var acc := Vector3.ZERO
		for k in 4:
			var j := 4 * i + k
			var wk := ws[j]
			if wk > 0.0:
				acc += ((g[idx[j]] as Transform3D) * offs[j]) * wk
		out[i] = acc
	return out


## Probe positions on a live skeleton (skeleton space; inside a modifier: the modified pose).
func eval_skeleton(limb: String, sk: Skeleton3D) -> PackedVector3Array:
	var key := "sk%d" % sk.get_instance_id()
	var idx := indices(limb, sk.find_bone, key)
	var cache := {}
	var L: Dictionary = limbs[limb]
	var ws: PackedFloat32Array = L.weights
	var offs: PackedVector3Array = L.offs
	var n := ws.size() / 4
	var out := PackedVector3Array()
	out.resize(n)
	for i in n:
		var acc := Vector3.ZERO
		for k in 4:
			var j := 4 * i + k
			var wk := ws[j]
			if wk > 0.0:
				var b := idx[j]
				var gb: Transform3D
				if cache.has(b):
					gb = cache[b]
				else:
					gb = sk.get_bone_global_pose(b)
					cache[b] = gb
				acc += (gb * offs[j]) * wk
		out[i] = acc
	return out


## Probe positions in WORLD space on a live skeleton whose global transform is gx (inside a
## modifier: the modified pose): eval_skeleton() then gx, with the influences compacted once per
## limb and skeleton (no zero weights; each bone's pose read once per call, gx folded in). The
## IK's guards skin their dense sets every frame (perf 2026-09-25: half the cost of the loop with
## a dictionary cache per call).
func eval_world(limb: String, sk: Skeleton3D, gx: Transform3D) -> PackedVector3Array:
	var ck := "%s|%d" % [limb, sk.get_instance_id()]
	var C: Dictionary = _world_cache.get(ck, {})
	if C.is_empty():
		var idx := indices(limb, sk.find_bone, "sk%d" % sk.get_instance_id())
		var L: Dictionary = limbs[limb]
		var ws: PackedFloat32Array = L.weights
		var offs: PackedVector3Array = L.offs
		var n0 := ws.size() / 4
		var slot := {}
		var bones := PackedInt32Array()
		var bi := PackedInt32Array()
		var cw := PackedFloat32Array()
		var co := PackedVector3Array()
		var cnt := PackedInt32Array()
		for i in n0:
			var c := 0
			for k in 4:
				var j := 4 * i + k
				if ws[j] <= 0.0 or idx[j] < 0:
					continue
				if not slot.has(idx[j]):
					slot[idx[j]] = bones.size()
					bones.append(idx[j])
				bi.append(int(slot[idx[j]]))
				cw.append(ws[j])
				co.append(offs[j])
				c += 1
			cnt.append(c)
		C = {"bones": bones, "bi": bi, "w": cw, "o": co, "cnt": cnt}
		_world_cache[ck] = C
	var bones2: PackedInt32Array = C.bones
	var T: Array[Transform3D] = []
	T.resize(bones2.size())
	for k in bones2.size():
		T[k] = gx * sk.get_bone_global_pose(bones2[k])
	var bi2: PackedInt32Array = C.bi
	var w2: PackedFloat32Array = C.w
	var o2: PackedVector3Array = C.o
	var cnt2: PackedInt32Array = C.cnt
	var out := PackedVector3Array()
	out.resize(cnt2.size())
	var j2 := 0
	for i in cnt2.size():
		var acc := Vector3.ZERO
		for k in cnt2[i]:
			acc += (T[bi2[j2]] * o2[j2]) * w2[j2]
			j2 += 1
		out[i] = acc
	return out


## The contact point of a set of surface points: y = the lowest point, xz = the soft-min
## (exp weights over the height above the lowest) so it moves continuously.
static func contact_of(pts: PackedVector3Array) -> Dictionary:
	if pts.is_empty():
		return {"p": Vector3.ZERO, "y": 0.0, "i": -1}
	var ymin := INF
	var imin := 0
	for i in pts.size():
		if pts[i].y < ymin:
			ymin = pts[i].y
			imin = i
	var sw := 0.0
	var sx := 0.0
	var sz := 0.0
	for i in pts.size():
		var dy := pts[i].y - ymin
		if dy > SOFT * 6.0:
			continue
		var w := exp(-dy / SOFT)
		sw += w
		sx += pts[i].x * w
		sz += pts[i].z * w
	return {"p": Vector3(sx / sw, ymin, sz / sw), "y": ymin, "i": imin}
