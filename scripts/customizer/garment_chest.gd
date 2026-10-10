extends RefCounted
## A garment's cloth over the breasts' apex made smooth (PlayerOutfit.dress, for the garments over the chest): a tight
## top cut on the female body and kept a few millimetres off the skin (the ring dress, tools/asset_author: the fire side
## top) followed the nipples, and on body type 2 they showed through it as two points (2026-10-09 creator audit,
## zoom_bt2_chest.png; the owner 2026-09-29: "just hide nipples or apply a nipple smoothneed on cloths"). The cloth may
## not sink there (the nipple is drawn under it: the chest_side region, which a sleeveless top does not hide), so it is
## stretched over it instead, as cloth over a point does: round each apex the cloth is lifted onto a smooth cap from its
## top (a paraboloid through the cloth's highest point that meets the cloth again CAP_R out: the hollow ring round the
## nipple's base, which made it read as a nipple, is filled), joined to the old cloth by a smooth maximum (no crease).
## The cloth only ever moves outward. The base shape and each of its blend shapes (sex, breast_large, breast_small: their
## positions are absolute) are capped round their own apex (the body's apex under that shape, body.glb), and the normals
## there are made again from the new triangles (welded across the UV seams). A garment with no hollow there (nothing
## moves more than MIN_MOVE) is returned as it is. Made once a mesh (cached).
##
##   const GarmentChest := preload("res://scripts/customizer/garment_chest.gd")
##   mi.mesh = GarmentChest.smoothed(mi.mesh)

## The cap's reach round the apex (the cloth's mean height this far out sets its curve; the cloth beyond R is left as it
## is), how near the body's apex the cloth's top is looked for, the smooth maximum's width, and the least move that counts
## (m).
const CAP_R := 0.017
const R := 0.026
const TOP_R := 0.01
const BLEND := 0.0008
const MIN_MOVE := 0.0005
## The body's apex is searched this far (m, across) round its nominal place (the female base: x +-0.104, y 1.166).
const APEX_NOMINAL := Vector2(0.104, 1.166)
const APEX_SEARCH := 0.05
## Points are one when this close (m): a UV seam's copies of a point.
const WELD := 0.00005

## Off: smoothed() returns every mesh as it is (tools comparing the cloth before and after).
static var enabled := true
static var _done := {}
static var _apexes := {}
## The apex search done (apexes() / warm_step), and its state while it runs a slice at a time.
static var _searched := false
static var _search := {}


## `mesh` with the cloth over the breasts' apex smoothed (a new mesh), or `mesh` itself when it has no point there.
static func smoothed(mesh: Mesh) -> Mesh:
	var am := mesh as ArrayMesh
	if am == null or not enabled:
		return mesh
	var key := am.resource_path if not am.resource_path.is_empty() else str(am.get_instance_id())
	if _done.has(key):
		var m: Variant = _done[key]
		return m if m is Mesh else mesh
	var out := ArrayMesh.new()
	out.blend_shape_mode = am.blend_shape_mode
	var names: Array[String] = [""]
	for b in am.get_blend_shape_count():
		out.add_blend_shape(am.get_blend_shape_name(b))
		names.append(String(am.get_blend_shape_name(b)))
	var changed := false
	for s in am.get_surface_count():
		var arrays := am.surface_get_arrays(s)
		var blends := am.surface_get_blend_shape_arrays(s)
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if am.surface_get_primitive_type(s) == Mesh.PRIMITIVE_TRIANGLES and not idx.is_empty():
			# (the blend shapes' arrays are the same Array objects as in `blends`: smoothed in place)
			var geoms: Array = [arrays] + blends
			for g in geoms.size():
				var ap: Array = apexes(names[g] if g < names.size() else "")
				for a: Vector3 in ap:
					if _cap(geoms[g], idx, a):
						changed = true
		out.add_surface_from_arrays(am.surface_get_primitive_type(s), arrays, blends, {}, am.surface_get_format(s))
		out.surface_set_material(s, am.surface_get_material(s))
		out.surface_set_name(s, am.surface_get_name(s))
	_done[key] = out if changed else null
	return out if changed else mesh


## The body's two breast apexes (the female base's, or under blend shape `shape` at full weight): the skin's most forward
## point near each one's nominal place (body.glb). [left, right]; [] when the body has none (or not that shape).
static func apexes(shape := "") -> Array:
	while not warm_step(1 << 62):
		pass
	return _apexes.get(shape, [])


## The apex search above, a slice at a time (the menus' figures are dressed while the lobby is shown: the whole search is about
## 0.35 s, 38 shapes of a 90 000-point body, which in one frame froze the lobby; FighterWorld calls this once a frame until it
## says true, each call doing about `budget_usec` of work, the arrays' read the longest step at about 50 ms). The same search,
## the same order and the same results as one call of apexes() (which runs it to the end). true when it is done.
static func warm_step(budget_usec := 25000) -> bool:
	if _searched:
		return true
	var t0 := Time.get_ticks_usec()
	if _search.is_empty():
		# the skin surfaces of the body, mesh by mesh, in the order of the body's nodes
		var jobs: Array = []
		var sc := load(BodyMaterials.BODY_GLB) as PackedScene if ResourceLoader.exists(BodyMaterials.BODY_GLB) else null
		var inst := sc.instantiate() if sc else null
		if inst:
			for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
				var m := mi.mesh as ArrayMesh
				if m == null:
					continue
				var surfs: Array = []
				for s in m.get_surface_count():
					var mat := m.surface_get_material(s)
					if mat != null and mat.resource_name == "skin":
						surfs.append(s)
				jobs.append({"mesh": m, "surfs": surfs})
			inst.free()
		_search = {"out": {"": []}, "jobs": jobs, "j": 0, "k": 0, "verts": null, "blends": null, "b": -1}
		if Time.get_ticks_usec() - t0 >= budget_usec:
			return false
	var st := _search
	var out: Dictionary = st.out
	while int(st.j) < (st.jobs as Array).size():
		var job: Dictionary = st.jobs[int(st.j)]
		# (a mesh after one that found the apex is passed over, as the one-call search did)
		if int(st.k) == 0 and st.verts == null and not (out[""] as Array).is_empty():
			st.j = int(st.j) + 1
			continue
		if int(st.k) >= (job.surfs as Array).size():
			st.j = int(st.j) + 1
			st.k = 0
			continue
		var m := job.mesh as ArrayMesh
		var s := int(job.surfs[int(st.k)])
		if st.verts == null:
			st.verts = m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		elif int(st.b) < 0:
			out[""] = _most_forward(st.verts)
			st.b = 0
		elif st.blends == null:
			st.blends = m.surface_get_blend_shape_arrays(s)
		elif int(st.b) < (st.blends as Array).size():
			var b := int(st.b)
			out[String(m.get_blend_shape_name(b))] = _most_forward(st.blends[b][Mesh.ARRAY_VERTEX])
			st.b = b + 1
		else:
			st.k = int(st.k) + 1
			st.verts = null
			st.blends = null
			st.b = -1
		if Time.get_ticks_usec() - t0 >= budget_usec:
			return false
	_apexes = out
	_searched = true
	_search = {}
	return true


static func _most_forward(p: PackedVector3Array) -> Array:
	var out := []
	for sx in [1.0, -1.0]:
		var best := Vector3(0.0, 0.0, -INF)
		for v in p:
			if Vector2(v.x - sx * APEX_NOMINAL.x, v.y - APEX_NOMINAL.y).length() < APEX_SEARCH and v.z > best.z:
				best = v
		if best.z > -INF:
			out.append(best)
	return out


static func _near(v: Vector3, apex: Vector3, reach: float) -> bool:
	return Vector2(v.x - apex.x, v.y - apex.y).length() < reach and v.z > apex.z - 0.04


## Caps one geometry's cloth (a surface's arrays or one of its blend shapes': ARRAY_VERTEX, ARRAY_NORMAL) round `apex`
## (see the header). True when it changed.
static func _cap(arrays: Array, idx: PackedInt32Array, apex: Vector3) -> bool:
	var p: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	# the cloth's outer face round the apex (its normal forward: never a lining behind it), its top, and its mean height
	# about CAP_R out
	var near: Array[int] = []
	var top := Vector3(0.0, 0.0, -INF)
	for i in p.size():
		if _near(p[i], apex, R) and (nrm.is_empty() or nrm[i].z > 0.3):
			near.append(i)
			if Vector2(p[i].x - apex.x, p[i].y - apex.y).length() < TOP_R and p[i].z > top.z:
				top = p[i]
	if near.size() < 8 or top.z == -INF:
		return false
	var ring := 0.0
	var n_ring := 0
	for i in near:
		var r := Vector2(p[i].x - top.x, p[i].y - top.y).length()
		if absf(r - CAP_R) < 0.003:
			ring += p[i].z
			n_ring += 1
	if n_ring < 3:
		return false
	var k := (top.z - ring / float(n_ring)) / (CAP_R * CAP_R)
	if k <= 0.0:
		return false
	var moved := 0.0
	for i in near:
		var r := Vector2(p[i].x - top.x, p[i].y - top.y).length()
		var cap := top.z - k * r * r
		# (a smooth maximum of the cloth and the cap: equal far from where they cross, no crease where they do)
		var z := 0.5 * (p[i].z + cap + sqrt((p[i].z - cap) * (p[i].z - cap) + 4.0 * BLEND * BLEND)) - BLEND \
				if r < R else p[i].z
		z = maxf(z, p[i].z)
		# (eased back to the old cloth over the last third of R)
		z = lerpf(z, p[i].z, smoothstep(0.66 * R, R, r))
		moved = maxf(moved, z - p[i].z)
		p[i] = Vector3(p[i].x, p[i].y, z)
	if moved < MIN_MOVE:
		return false
	arrays[Mesh.ARRAY_VERTEX] = p
	if not nrm.is_empty():
		arrays[Mesh.ARRAY_NORMAL] = _normals(p, nrm, idx, apex)
	return true


## The normals within R of `apex` made again from the triangles round them, welded by position (a UV seam's copies of a
## point get one normal; a face wound either way counts toward the front); the rest as they were.
static func _normals(p: PackedVector3Array, nrm: PackedVector3Array, idx: PackedInt32Array, apex: Vector3) -> PackedVector3Array:
	var acc := {}
	for t in range(0, idx.size() - 2, 3):
		var a := p[idx[t]]
		var b := p[idx[t + 1]]
		var c := p[idx[t + 2]]
		if not (_near(a, apex, R + 0.01) or _near(b, apex, R + 0.01) or _near(c, apex, R + 0.01)):
			continue
		var fn := (b - a).cross(c - a)
		if fn.z < 0.0:
			fn = -fn
		for v: Vector3 in [a, b, c]:
			var k := Vector3i((v / WELD).round())
			acc[k] = (acc.get(k, Vector3.ZERO) as Vector3) + fn
	var out := nrm.duplicate()
	for i in p.size():
		if not _near(p[i], apex, R) or nrm[i].z <= 0.3:
			continue
		var n: Vector3 = acc.get(Vector3i((p[i] / WELD).round()), Vector3.ZERO)
		if n.length() > 1e-12:
			out[i] = n.normalized()
	return out
