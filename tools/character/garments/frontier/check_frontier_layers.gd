extends SceneTree
## Layer check of the frontier garments over the gameplay clips (headless): skin against
## each garment, both body fits. For every garment glb of assets/character/garments/frontier
## (or items=id,id) it attaches body.glb + the garment to a fresh Actor_B, applies `sex`,
## and at every sample of the 44 clips of check_body_deform.gd (8 per clip):
##
##  1. poke-through: body vertices of regions the garment does NOT hide that lie under the
##     garment at bind (within 3 cm inside its surface) must stay inside it: the skin may
##     not come out through the cloth by more than POKE (signed distance to the nearest of
##     its bind-time garment neighbours, along that neighbour's skinned normal).
##  2. coverage of hidden regions: body vertices of the regions listed in hides_regions must
##     stay under the garment: the nearest garment neighbour may not move more than GAP
##     further away than at bind (a sleeve or hem sliding off the hidden skin would open a
##     hole, because hidden skin is not drawn).
##
## Card and fur surfaces are skipped (the main surface is the garment's body). Reports per
## body region the share of vertex-samples that fail and the worst clip; fails when a
## region exceeds MAX_SHARE (hidden regions: MAX_SHARE_HIDDEN).
##
##   Godot --headless --path . -s tools/character/garments/frontier/check_frontier_layers.gd -- [items=..] [sex=0,1] [samples=8]
## Prints LAYERS PASSED / LAYERS FAILED.

const GDIR := "res://assets/character/garments/frontier/"
const BODY := "res://assets/character/body/body.glb"
const POKE := 0.002
const GAP := 0.02
const NEAR := 0.03
const KNN := 8
const MAX_SHARE := 0.02
const MAX_SHARE_HIDDEN := 0.002
const CLIPS := [
	"actor_b-p-stealth-idle", "actor_b-p-walk-fw", "actor_b-p-walk-bw", "actor_b-p-walk-fw-lt",
	"actor_b-p-run-fw", "actor_b-p-run-bw-lt", "actor_b-p-run-fw-rt", "actor_b-p-sprint-fw",
	"actor_b-p-sprint-fw-lt", "actor_b-p-crouch-idle", "actor_b-p-crouch-walk-fw",
	"actor_b-p-crouch-walk-bw-lt", "actor_b-p-crouch-walk-fw-rt", "actor_b-p-crouch-hr-fw",
	"actor_b-p-hr-fw", "actor_b-p-fall", "actor_b-p-rifle-idle-aim", "actor_b-p-rifle-aim-walk-fw",
	"actor_b-p-rifle-aim-crouch-idle", "actor_b-p-rifle-aim-crouch-walk-fw",
	"actor_b-p-rifle-idle-aim-reload-begin--part", "actor_b-p-rifle-idle-aim-reload-mid--part",
	"actor_b-p-rifle-idle-aim-reload-over--part", "actor_b-p-rifle-idle-crouch-aim-reload-mid--part",
	"actor_b-p-rifle-run-arms", "actor_b-p-pistol-aim-idle", "actor_b-p-pistol-aim-walk-fw",
	"actor_b-p-pistol-aim-crouch-walk-fw", "actor_b-p-pistol-rev-reload-mid--part",
	"actor_b-p-bow-aim-idle", "actor_b-p-bow-aim-walk-fw", "actor_b-p-bow-aim-crouch-idle",
	"actor_b-p-bow-draw-grab^idle--part", "actor_b-p-bow-reload--part", "actor_b-p-crouch-bow-reload--part",
	"actor_b-p-bow-move--arms", "actor_b-lg-stealth-draw^idle--arm-r",
	"actor_b-p-idle-jump-up-2m^ledge-chest-end", "actor_b-p-idle-jump-up-3m^ledge-hang-mid",
	"actor_b-death-standing-generic", "actor_b-p-land-hard-damage^idle", "actor_b-p-death-front",
	"actor_b-p-death-back", "actor_b-p-death-crouch-generic",
]

var args := {}
var region_names := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	var info = JSON.parse_string(FileAccess.get_file_as_string("res://assets/character/body/body.json"))
	for n: String in info.regions.ids:
		region_names[int(info.regions.ids[n])] = n
	var ok := true
	var ids := []
	if args.has("items"):
		ids = Array(String(args.items).split(","))
	else:
		for f in DirAccess.get_files_at(GDIR):
			if f.ends_with(".json"):
				var e = JSON.parse_string(FileAccess.get_file_as_string(GDIR + f))
				if e is Dictionary and e.has("slot") and e.has("glb"):
					ids.append(f.get_basename())
		ids.sort()
	for id: String in ids:
		for sx in String(args.get("sex", "0,1")).split(","):
			ok = (await _check(id, float(sx))) and ok
	print("LAYERS PASSED" if ok else "LAYERS FAILED")
	quit(0 if ok else 1)


## Mesh data of the first mesh instance whose surface name matches `want` (or all surfaces
## except cards / fur when want is empty): vertices with blend shapes applied, normals,
## bones, weights, region per vertex.
func _mesh_data(mi: MeshInstance3D, skip_suffixes: Array) -> Dictionary:
	var am := mi.mesh as ArrayMesh
	var V := PackedVector3Array()
	var N := PackedVector3Array()
	var B := PackedInt32Array()
	var Wt := PackedFloat32Array()
	var R := PackedInt32Array()
	var nb := 4
	for s in am.get_surface_count():
		var mat := am.surface_get_material(s)
		var name := mat.resource_name if mat else ""
		var skip := false
		for suf: String in skip_suffixes:
			if name.ends_with(suf):
				skip = true
		if skip:
			continue
		var arr := am.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bs := am.surface_get_blend_shape_arrays(s)
		for b in bs.size():
			var bw := mi.get_blend_shape_value(b)
			if absf(bw) < 1e-6:
				continue
			var sv: PackedVector3Array = bs[b][Mesh.ARRAY_VERTEX]
			var base: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for i in v.size():
				v[i] += (sv[i] - base[i]) * bw
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var bo: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		nb = bo.size() / maxi(v.size(), 1)
		var uv2 = arr[Mesh.ARRAY_TEX_UV2]
		for i in v.size():
			V.append(v[i])
			N.append(n[i])
			R.append((roundi((uv2 as PackedVector2Array)[i].x) & 63) if uv2 != null else -1)
		B.append_array(bo)
		Wt.append_array(w)
	return {"v": V, "n": N, "bo": B, "w": Wt, "nb": nb, "r": R, "skin": mi.skin}


func _skin(d: Dictionary, m: Array, idx: PackedInt32Array, normals := false) -> Array:
	var v: PackedVector3Array = d.v
	var nn: PackedVector3Array = d.n
	var bo: PackedInt32Array = d.bo
	var w: PackedFloat32Array = d.w
	var nb: int = d.nb
	var P := PackedVector3Array()
	var N := PackedVector3Array()
	P.resize(idx.size())
	if normals:
		N.resize(idx.size())
	for j in idx.size():
		var i := idx[j]
		var acc := Vector3.ZERO
		var an := Vector3.ZERO
		for k in nb:
			var wk := w[i * nb + k]
			if wk > 0.0:
				var t: Transform3D = m[bo[i * nb + k]]
				acc += (t * v[i]) * wk
				if normals:
					an += (t.basis * nn[i]) * wk
		P[j] = acc
		if normals:
			N[j] = an.normalized()
	return [P, N]


func _check(id: String, sex: float) -> bool:
	var e = JSON.parse_string(FileAccess.get_file_as_string(GDIR + id + ".json"))
	var hides: Array = e.get("hides_regions", [])
	var inst := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate()
	root.add_child(inst)
	var sk := inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	BindRest.ensure(sk, ap)
	var body := CharacterBodyMesh.attach_parts(sk, ap, {"body": BODY, id: String(e.glb)})
	body.set_blend_shape("sex", sex)
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	ap.deterministic = true
	await process_frame
	var bd := {}
	var gd := {}
	for mi in body.part_meshes("body"):
		if String(mi.name).contains("Face"):
			continue
		bd = _mesh_data(mi, [])
	for mi in body.part_meshes(id):
		gd = _mesh_data(mi, ["_fur", "_fringe", "_cards"])
	# bind pose: pair body vertices with their garment neighbours
	var bv: PackedVector3Array = bd.v
	var gv: PackedVector3Array = gd.v
	var gn: PackedVector3Array = gd.n
	var hidden_ids := {}
	for r in hides:
		for k in region_names:
			if region_names[k] == r:
				hidden_ids[k] = true
	var sel := PackedInt32Array()
	var kind := PackedByteArray()        # 1 visible under the garment, 2 hidden
	var nbrs := []
	var bind_d := PackedFloat32Array()
	# coarse grid of the garment vertices for the neighbour search
	var cell := 0.03
	var grid := {}
	for i in gv.size():
		var key := Vector3i(floori(gv[i].x / cell), floori(gv[i].y / cell), floori(gv[i].z / cell))
		if not grid.has(key):
			grid[key] = PackedInt32Array()
		(grid[key] as PackedInt32Array).append(i)
	for i in bv.size():
		var reg: int = bd.r[i]
		var hid := hidden_ids.has(reg)
		var p := bv[i]
		var c := Vector3i(floori(p.x / cell), floori(p.y / cell), floori(p.z / cell))
		var cand := []
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					var key := c + Vector3i(dx, dy, dz)
					if grid.has(key):
						for j in grid[key]:
							cand.append([p.distance_squared_to(gv[j]), j])
		if cand.is_empty():
			continue
		cand.sort_custom(func(a, b) -> bool: return a[0] < b[0])
		var jn: int = cand[0][1]
		var sd := (p - gv[jn]).dot(gn[jn])
		if not hid and not (sd < 0.0 and sqrt(cand[0][0]) < NEAR):
			continue
		var ks := PackedInt32Array()
		for q in mini(KNN, cand.size()):
			ks.append(cand[q][1])
		sel.append(i)
		kind.append(2 if hid else 1)
		nbrs.append(ks)
		bind_d.append(sqrt(cand[0][0]))
	# the garment vertices that are someone's neighbour
	var gset := {}
	for ks: PackedInt32Array in nbrs:
		for j in ks:
			gset[j] = true
	var gidx := PackedInt32Array(gset.keys())
	var gpos := {}
	for q in gidx.size():
		gpos[gidx[q]] = q
	var fails := {}      # region -> [fail count, sample count, worst clip counts]
	var samples := int(args.get("samples", "8"))
	for clip: String in CLIPS:
		var anim := "actor_b/" + clip
		if not ap.has_animation(anim):
			continue
		var L := ap.get_animation(anim).length
		var n := 1 if L < 0.05 else samples
		for s in n:
			ap.play(anim)
			ap.seek(L * s / n, true)
			ap.advance(0.0)
			var g := body.skinning_globals()
			var mb: Array[Transform3D] = []
			for b in (bd.skin as Skin).get_bind_count():
				mb.append(g[(bd.skin as Skin).get_bind_bone(b)] * (bd.skin as Skin).get_bind_pose(b))
			var mg: Array[Transform3D] = []
			for b in (gd.skin as Skin).get_bind_count():
				mg.append(g[(gd.skin as Skin).get_bind_bone(b)] * (gd.skin as Skin).get_bind_pose(b))
			var BP: PackedVector3Array = _skin(bd, mb, sel)[0]
			var GS := _skin(gd, mg, gidx, true)
			var GP: PackedVector3Array = GS[0]
			var GN: PackedVector3Array = GS[1]
			for t in sel.size():
				var reg: int = bd.r[sel[t]]
				var best := 1e9
				var bsd := 0.0
				for j in nbrs[t]:
					var q: int = gpos[j]
					var d := BP[t].distance_to(GP[q])
					if d < best:
						best = d
						bsd = (BP[t] - GP[q]).dot(GN[q])
				var bad := false
				if kind[t] == 1:
					bad = bsd > POKE
				else:
					bad = best > bind_d[t] + GAP
				var key := "%s%s" % ["hidden:" if kind[t] == 2 else "", region_names.get(reg, str(reg))]
				if not fails.has(key):
					fails[key] = [0, 0, {}]
				fails[key][1] += 1
				if bad:
					fails[key][0] += 1
					fails[key][2][clip] = int(fails[key][2].get(clip, 0)) + 1
	inst.queue_free()
	await process_frame
	var ok := true
	var keys := fails.keys()
	keys.sort()
	var lines := PackedStringArray()
	for k: String in keys:
		var f: Array = fails[k]
		var share := float(f[0]) / maxf(f[1], 1)
		var lim := MAX_SHARE_HIDDEN if k.begins_with("hidden:") else MAX_SHARE
		var good := share <= lim
		ok = ok and good
		if not good or f[0] > 0:
			var wc: Dictionary = f[2]
			var worst := ""
			var wn := 0
			for c in wc:
				if wc[c] > wn:
					wn = wc[c]
					worst = c
			lines.append("    %s %-24s %6.3f %% of %d samples (limit %.1f %%) worst %s" % ["ok  " if good else "FAIL", k, 100.0 * share, f[1], 100.0 * lim, worst])
	print("%s %s sex %.0f: %d skin vertices under or hidden by it (%d hidden)" % ["ok  " if ok else "FAIL", id, sex, sel.size(), kind.count(2)])
	for l in lines:
		print(l)
	return ok
