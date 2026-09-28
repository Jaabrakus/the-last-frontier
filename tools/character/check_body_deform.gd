extends SceneTree
## Deformation scan of the player body over the gameplay clips (headless).
##
##   Godot --headless --path <Frontier> -s tools/character/check_body_deform.gd -- \
##       [clips=<file, one clip per line>] [samples=8] [verbose=1] [glb=res://...]
##       [parts=customizer|<path>,<path>...] [sex=0..1] [face=<preset id>]
##
## parts=customizer scans assets/character/body/body.glb and every hair style together
## (CharacterBodyMesh.attach_parts), with the `sex` and face blend shapes applied to the CPU
## skinning. The full-skin body is reported per region group ("skin:<group>" from the
## triangle's region code, limits SKIN_LIMITS), hair per style ("hair:<id>", class limits
## HAIR_LIMITS, cards "hair_cards"). The eyes and the Face mesh are rigid and skipped.
## parts=<glb>,<glb>... scans the listed parts together (e.g. body.glb, a hair style and a
## set's garments); a garment surface takes the limits its catalog fragment declares
## ("deform_limits", see _read_fragment_limits), else DEFAULT_LIMIT.
##
## A fresh Actor_B with the body (CharacterBodyMesh.attach, helper bones driven exactly as
## in game via skinning_globals()) plays every clip at `samples` evenly spaced times. Each
## vertex is skinned on the CPU and every triangle is compared with the bind pose. Per
## material it reports the share of triangles that at some sample
##   collapse  (area < COLLAPSE of the bind area: tears, candy-wrap, crushed ribbons),
##   flip      (the triangle turns over against its dominant bone: folds),
##   stretch   (an edge longer than STRETCH_EDGE times its bind length: smeared cloth),
## and the largest edge ratio of any triangle (max edge), with the worst clips and bones.
## Linear blend skinning always squeezes some triangles in deep joint folds (hip crease and
## crotch in a deep crouch, inner elbow, knee pit, the armpit crease when the arms come
## forward, closing fists, the skirt panels of a body lying on the ground); those are hidden
## inside the fold. So each material has limits (LIMITS: collapse share, flip share,
## stretch share, max edge ratio) and the check fails when one is exceeded. The cloth
## limits sit about 25 % above the scan of the current asset. Rigid parts (brass, pouch,
## horn, garters, the ribbon, the belt) must never stretch: max edge ratio RIGID_EDGE.
## The straps keep their cross-section rigid too (the whole width takes the weights of the
## strap's centre line), but along their length they follow the coat's back, which
## lengthens in a deep forward bend (about 1.6x on the lower back in crouches), so their
## max edge limit is STRAP_EDGE.
##
## Skirt: for every sample, each coat-skirt panel helper must hang within SKIRT_HANG_DEG of
## world-down unless the thigh pushes it or the floor lifts it (CharacterBodyMesh._drive
## diagnostics): the skirt never stands off the body like a board, a wing or a sail.
##
## The previous asset fails these limits: belt stretch>2x on 35 % of its triangles (max
## 3.8x, crouch-walk / sprint), straps 3.2x with 2.5 % collapsed, hair 1.6 % collapsed.
## Face and Hat are rigid on the head and skipped. Prints CHECK PASSED / CHECK FAILED.

const COLLAPSE := 0.2
const STRETCH_EDGE := 2.0
const RIGID_EDGE := 1.3
const STRAP_EDGE := 2.0
const SKIRT_HANG_DEG := 70.0
## [collapse share, flip share, stretch share, max edge ratio] per material.
const LIMITS := {
	"coat": [0.072, 0.125, 0.23, 27.0], "breeches": [0.080, 0.092, 0.10, 15.0],
	"skin": [0.023, 0.044, 0.041, 4.5], "leggings": [0.022, 0.031, 0.006, 2.8],
	"hair": [0.006, 0.009, 0.0095, 5.5], "linen": [0.005, 0.005, 0.04, 3.8],
	"waistcoat": [0.005, 0.005, 0.005, 2.4], "shoe": [0.0063, 0.0045, 0.005, 2.2],
	"garter": [0.005, 0.005, 0.0, RIGID_EDGE], "brass": [0.005, 0.005, 0.0, RIGID_EDGE],
	"ribbon": [0.005, 0.005, 0.0, RIGID_EDGE], "belt": [0.005, 0.005, 0.0, RIGID_EDGE],
	"strap": [0.005, 0.005, 0.0, STRAP_EDGE], "pouch": [0.005, 0.005, 0.0, RIGID_EDGE],
	"horn": [0.005, 0.005, 0.0, RIGID_EDGE], "wood": [0.005, 0.005, 0.0, RIGID_EDGE],
	"horn_tip": [0.005, 0.005, 0.0, RIGID_EDGE],
}
const DEFAULT_LIMIT := [0.01, 0.01, 0.01, 4.0]
## Full-skin body (customizer) per region group: [collapse, flip, stretch share, max edge],
## 25 % above the scan of body.glb (female and male fit, 44 clips x 8 samples, 2026-09-24).
## Linear blend skinning without correctives: the worst places are the lower back and the
## hip crease in deep crouches (torso_lower stretch 17 %, thighs collapse 9.5 %), the back
## of the neck in crouch walks with the head up (male neck 7 % collapse), the armpit and
## side chest with both arms overhead (ledge hang, torso_upper max edge 33x) and closing
## fists (hands). They are hidden by clothing in most looks; bare-skin looks show them.
const SKIN_LIMITS := {
	"head": [0.0065, 0.012, 0.0245, 5.8], "neck": [0.0875, 0.108, 0.149, 8.2],
	"torso_upper": [0.0655, 0.0925, 0.167, 40.8], "torso_lower": [0.043, 0.031, 0.2135, 12.0],
	"hips": [0.0145, 0.0235, 0.0955, 18.5], "arms_upper": [0.036, 0.105, 0.146, 10.7],
	"arms_lower": [0.038, 0.0345, 0.0175, 5.3], "hands": [0.043, 0.087, 0.0555, 16.6],
	"thighs": [0.119, 0.1425, 0.088, 8.2], "shins": [0.004, 0.004, 0.005, 2.8], "feet": [0.01, 0.023, 0.0085, 3.2],
}
## Hair styles, 25 % above their scan (both fits). Caps copy the head and neck (the nape
## folds when the head tilts back); a queue, club or braid is one rigid pendulum below a
## soft root, which stretches when the head turns hard against the torso (bow aim, crouch
## walk). Crown locks are rigid. New styles fall back to "hair_style"; cards are rigid per
## strand ("hair_cards").
const HAIR_LIMITS := {
	"hair_braid_f": [0.0175, 0.0235, 0.0185, 20.5], "hair_club_ribbon": [0.0195, 0.018, 0.0145, 13.7],
	"hair_club_wrapped_f": [0.0185, 0.022, 0.02, 9.3], "hair_cropped_1758": [0.0225, 0.0325, 0.03, 3.5],
	"hair_crown_lock_braided": [0.0005, 0.0005, 0.0005, 1.3], "hair_crown_lock_silver": [0.0005, 0.0005, 0.0005, 1.3],
	"hair_loose_tied": [0.015, 0.02, 0.015, 15.3], "hair_natural_short": [0.022, 0.025, 0.028, 3.2],
	"hair_pinned_capped": [0.024, 0.022, 0.0195, 3.3], "hair_queue_ribbon": [0.016, 0.0205, 0.0165, 8.0],
	"hair_siamese_crop": [0.0025, 0.002, 0.0025, 2.7], "hair_siamese_short_f": [0.015, 0.0085, 0.0155, 3.0],
	"hair_style": [0.025, 0.035, 0.03, 20.0], "hair_cards": [0.005, 0.005, 0.005, 1.3],
}
const GROUPS_JSON := "res://assets/character/body/body.json"
## Gameplay clips (locomotion, stances, weapons, reloads, climbing, falls) and the
## knockdown / landing / death clips the animation graph binds (tools/anim_graph).
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
const SKIP_MESHES := ["Face", "Hat", "body_Face"]

var args := {}
var _fragment_limits := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	var ok := await _run()
	print("CHECK PASSED" if ok else "CHECK FAILED")
	quit(0 if ok else 1)


func _run() -> bool:
	var inst := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate()
	root.add_child(inst)
	var sk := inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	BindRest.ensure(sk, ap)
	var body: CharacterBodyMesh = null
	var parts := {}
	if args.has("parts"):
		if args.parts == "customizer":
			parts["body"] = "res://assets/character/body/body.glb"
			for f in DirAccess.get_files_at("res://assets/character/hair"):
				if f.ends_with(".glb"):
					parts[f.get_basename()] = "res://assets/character/hair/" + f
		else:
			for p in String(args.parts).split(","):
				parts[p.get_file().get_basename()] = p
		body = CharacterBodyMesh.attach_parts(sk, ap, parts)
		for p: String in parts.values():
			_read_fragment_limits(p)
	else:
		body = CharacterBodyMesh.attach(sk, ap, args.get("glb", CharacterBodyMesh.DEFAULT_PATH))
	if body == null:
		push_error("no body asset")
		return false
	if not parts.is_empty():
		body.set_blend_shape("sex", float(args.get("sex", "0")))
		if args.has("face"):
			var info = JSON.parse_string(FileAccess.get_file_as_string(GROUPS_JSON))
			var fw: Dictionary = info.get("face_presets", {}).get(args.face, {})
			if fw.is_empty():
				fw = CharacterPeoples.preset(String(args.face)).get("face", {})   # a peoples.json preset
			for k: String in fw:
				body.set_blend_shape(k, float(fw[k]))
		print("parts: %s, sex %s, face %s" % [parts.keys(), args.get("sex", "0"), args.get("face", "-")])
	var region_group := {}
	if not parts.is_empty():
		var info = JSON.parse_string(FileAccess.get_file_as_string(GROUPS_JSON))
		var r: Dictionary = info.get("regions", {})
		for n: String in r.get("ids", {}):
			region_group[int(r.ids[n])] = String(r.groups[n])
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	ap.deterministic = true
	await process_frame

	var clips: Array = CLIPS.duplicate()
	if args.has("clips"):
		clips = []
		for line in FileAccess.get_file_as_string(args.clips).split("\n"):
			if not line.strip_edges().is_empty():
				clips.append(line.strip_edges())
	var samples := int(args.get("samples", "8"))
	var verbose: bool = args.get("verbose", "0") == "1"

	# One Dictionary per surface: label (material), vertices, indices, bones (skin bind
	# indices), weights, nb, skin, bind area / normal / dominant bind / edge lengths per
	# triangle, per-triangle flags and the worst edge ratio seen.
	var surfs: Array = []
	for mi in body.meshes:
		if String(mi.name) in SKIP_MESHES:
			continue
		var am := mi.mesh as ArrayMesh
		for s in am.get_surface_count():
			var arr := am.surface_get_arrays(s)
			var mat := am.surface_get_material(s)
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
			var idx_all: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var bo: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var nb := bo.size() / maxi(v.size(), 1)
			var mname := mat.resource_name if mat and not mat.resource_name.is_empty() else "%s_%d" % [mi.name, s]
			# label groups of triangles: skin by region group, hair by style
			var groups := {}
			var uv2 = arr[Mesh.ARRAY_TEX_UV2]
			for t in idx_all.size() / 3:
				var label := mname
				if not parts.is_empty():
					if mname == "skin" and uv2 != null:
						label = "skin:" + String(region_group.get(roundi((uv2 as PackedVector2Array)[idx_all[3 * t]].x) & 63, "?"))
					elif mname.begins_with("hair_"):
						label = ("hair_cards:" if mname.ends_with("_cards") else "hair:") + mname.trim_suffix("_cards")
				if not groups.has(label):
					groups[label] = []          # (Array: a reference; packed arrays copy)
				(groups[label] as Array).append(t)
			for label: String in groups:
				var idx := PackedInt32Array()
				for t: int in groups[label]:
					idx.append_array([idx_all[3 * t], idx_all[3 * t + 1], idx_all[3 * t + 2]])
				var area := PackedFloat32Array()
				var nrm := PackedVector3Array()
				var dom := PackedInt32Array()
				var elen := PackedFloat32Array()
				for t in idx.size() / 3:
					var a := v[idx[3 * t]]
					var c := (v[idx[3 * t + 1]] - a).cross(v[idx[3 * t + 2]] - a)
					area.append(c.length() * 0.5)
					nrm.append(c.normalized() if c.length() > 0.0 else Vector3.ZERO)
					for e in 3:
						elen.append(v[idx[3 * t + e]].distance_to(v[idx[3 * t + (e + 1) % 3]]))
					var i0 := idx[3 * t]
					var best := 0
					for k in nb:
						if w[i0 * nb + k] > w[i0 * nb + best]:
							best = k
					dom.append(bo[i0 * nb + best])
				var ntri := idx.size() / 3
				var sf := {"label": label, "mesh": String(mi.name), "vkey": "%s/%d" % [mi.name, s], "v": v, "idx": idx, "bo": bo, "w": w, "nb": nb,
						"skin": mi.skin, "area": area, "n": nrm, "dom": dom, "elen": elen, "worst": {},
						"edge": PackedFloat32Array(), "edge_at": {}}
				for key in ["collapse", "stretch", "flip"]:
					var flags := PackedByteArray()
					flags.resize(ntri)
					flags.fill(0)
					sf[key] = flags
				var er := PackedFloat32Array()
				er.resize(ntri)
				er.fill(0.0)
				sf.edge = er
				surfs.append(sf)

	var poses := 0
	var hang_bad := 0
	var hang_worst := [0.0, ""]
	var panels := 0
	for clip: String in clips:
		var anim := "actor_b/" + clip
		if not ap.has_animation(anim):
			print("  missing clip ", clip)
			continue
		var L := ap.get_animation(anim).length
		var n := 1 if L < 0.05 else samples
		for j in n:
			ap.play(anim)
			ap.seek(L * j / n, true)
			ap.advance(0.0)
			var g := body.skinning_globals()
			poses += 1
			# Skirt panels: hanging, pushed by the thigh or lifted by the floor.
			var gd := []
			for b in sk.get_bone_count():
				gd.append(sk.get_bone_global_pose(b))
			var diag := []
			var down := sk.global_basis.orthonormalized().inverse() * Vector3.DOWN
			body._drive(gd, down, diag)
			for dd: Dictionary in diag:
				panels += 1
				if dd.pushed or dd.floored:
					continue
				if float(dd.hang) > hang_worst[0]:
					hang_worst = [float(dd.hang), "%s %.2f %s" % [clip, float(j) / n, sk.get_bone_name(dd.bone)]]
				if float(dd.hang) > SKIRT_HANG_DEG:
					hang_bad += 1
			var mats := {}
			var skinned := {}
			for sf: Dictionary in surfs:
				var skin: Skin = sf.skin
				if not mats.has(skin):
					var m: Array[Transform3D] = []
					for b in skin.get_bind_count():
						m.append(g[skin.get_bind_bone(b)] * skin.get_bind_pose(b))
					mats[skin] = m
				var key: String = sf.vkey
				if not skinned.has(key):
					skinned[key] = _skin_positions(sf, mats[skin])
				_scan(sf, skinned[key], mats[skin], "%s@%.2f" % [clip, float(j) / n])
	print("scanned %d poses of %d clips" % [poses, clips.size()])

	# Per material totals.
	var totals := {}
	for sf: Dictionary in surfs:
		var lab: String = sf.label
		if not totals.has(lab):
			totals[lab] = {"tris": 0, "collapse": 0, "stretch": 0, "flip": 0, "clips": {}, "bones": {}, "edge": 0.0, "edge_at": ""}
		var tot: Dictionary = totals[lab]
		var bind_area: PackedFloat32Array = sf.area
		var er: PackedFloat32Array = sf.edge
		for t in bind_area.size():
			if bind_area[t] < 1e-9:
				continue
			tot.tris += 1
			for key in ["collapse", "stretch", "flip"]:
				if (sf[key] as PackedByteArray)[t]:
					tot[key] += 1
			if (sf.collapse as PackedByteArray)[t] or (sf.flip as PackedByteArray)[t] or (sf.stretch as PackedByteArray)[t]:
				var bn := sk.get_bone_name((sf.skin as Skin).get_bind_bone((sf.dom as PackedInt32Array)[t]))
				tot.bones[bn] = int(tot.bones.get(bn, 0)) + 1
			if er[t] > tot.edge:
				tot.edge = er[t]
				tot.edge_at = String((sf.edge_at as Dictionary).get(t, ""))
		for c: String in sf.worst:
			tot.clips[c] = int(tot.clips.get(c, 0)) + int(sf.worst[c])
	var ok := true
	var labels := totals.keys()
	labels.sort()
	for lab: String in labels:
		var tot: Dictionary = totals[lab]
		var lim: Array = _limit(lab)
		var fc := float(tot.collapse) / maxf(tot.tris, 1)
		var ff := float(tot.flip) / maxf(tot.tris, 1)
		var fs := float(tot.stretch) / maxf(tot.tris, 1)
		var good: bool = fc <= float(lim[0]) and ff <= float(lim[1]) and fs <= float(lim[2]) and float(tot.edge) <= float(lim[3])
		ok = ok and good
		print("  %s %-10s tris %5d  collapse %5.2f %% (%.1f)  flip %5.2f %% (%.1f)  stretch>%.0fx %5.2f %% (%.1f)  max edge %5.2fx (%.1f)" % [
				"ok  " if good else "FAIL", lab, tot.tris, 100 * fc, 100 * float(lim[0]), 100 * ff, 100 * float(lim[1]),
				STRETCH_EDGE, 100 * fs, 100 * float(lim[2]), float(tot.edge), float(lim[3])])
		if (verbose or not good) and (tot.collapse > 0 or tot.flip > 0 or tot.stretch > 0 or float(tot.edge) > float(lim[3])):
			print("         by clip (triangle-samples): ", _top(tot.clips, 5))
			print("         by bone: ", _top(tot.bones, 5))
			print("         max edge at ", tot.edge_at)
	var hang_ok := hang_bad == 0
	ok = ok and hang_ok
	print("  %s skirt     %d panel samples, %d hang more than %.0f deg off world-down without a push or the floor (worst %.0f deg: %s)" % [
			"ok  " if hang_ok else "FAIL", panels, hang_bad, SKIRT_HANG_DEG, hang_worst[0], hang_worst[1]])
	inst.queue_free()
	return ok


## Skins the surface with `m` (per skin bind) and flags its triangles.
## Positions of the surface's vertices skinned with `m` (per skin bind).
func _skin_positions(sf: Dictionary, m: Array[Transform3D]) -> PackedVector3Array:
	var v: PackedVector3Array = sf.v
	var bo: PackedInt32Array = sf.bo
	var w: PackedFloat32Array = sf.w
	var nb: int = sf.nb
	var p := PackedVector3Array()
	p.resize(v.size())
	for i in v.size():
		var acc := Vector3.ZERO
		var base := i * nb
		for k in nb:
			var wk := w[base + k]
			if wk > 0.0:
				acc += (m[bo[base + k]] * v[i]) * wk
		p[i] = acc
	return p


## Flags the surface's triangles for the skinned positions `p`.
func _scan(sf: Dictionary, p: PackedVector3Array, m: Array[Transform3D], clip: String) -> void:
	var idx: PackedInt32Array = sf.idx
	var area: PackedFloat32Array = sf.area
	var nrm: PackedVector3Array = sf.n
	var dom: PackedInt32Array = sf.dom
	var elen: PackedFloat32Array = sf.elen
	var col: PackedByteArray = sf.collapse
	var st: PackedByteArray = sf.stretch
	var fl: PackedByteArray = sf.flip
	var er: PackedFloat32Array = sf.edge
	var at: Dictionary = sf.edge_at
	var hits := 0
	for t in area.size():
		var a0 := area[t]
		if a0 < 1e-9:
			continue
		var a := p[idx[3 * t]]
		var c := (p[idx[3 * t + 1]] - a).cross(p[idx[3 * t + 2]] - a)
		var r := c.length() * 0.5 / a0
		var bad := false
		if r < COLLAPSE:
			col[t] = 1
			bad = true
		if c.dot(m[dom[t]].basis * nrm[t]) < 0.0:
			fl[t] = 1
			bad = true
		var mx := 0.0
		for e in 3:
			var l0 := elen[3 * t + e]
			if l0 > 1e-5:
				mx = maxf(mx, p[idx[3 * t + e]].distance_to(p[idx[3 * t + (e + 1) % 3]]) / l0)
		if mx > STRETCH_EDGE:
			st[t] = 1
			bad = true
		if mx > er[t]:
			er[t] = mx
			at[t] = clip
		if bad:
			hits += 1
	# (write back: packed arrays taken out of a Dictionary may be copies)
	sf.collapse = col
	sf.stretch = st
	sf.flip = fl
	sf.edge = er
	if hits > 0:
		var cn := clip.get_slice("@", 0)
		sf.worst[cn] = int(sf.worst.get(cn, 0)) + hits


func _limit(lab: String) -> Array:
	if lab.begins_with("skin:"):
		return SKIN_LIMITS.get(lab.substr(5), DEFAULT_LIMIT)
	if lab.begins_with("hair_cards:"):
		return HAIR_LIMITS.hair_cards
	if lab.begins_with("hair:"):
		return HAIR_LIMITS.get(lab.substr(5), HAIR_LIMITS.hair_style)
	return LIMITS.get(lab, _fragment_limits.get(lab, DEFAULT_LIMIT))


## Garment parts declare the limits of their surfaces in their catalog fragment (the .json
## next to the glb, written by tools/character/lib/pipeline.py): "deform_limits":
## {surface: [collapse, flip, stretch share, max edge]}, set by the garment's generator
## from its own scan (tools/character/garments/*). LIMITS above take precedence.
func _read_fragment_limits(glb: String) -> void:
	var js := glb.get_basename() + ".json"
	if not FileAccess.file_exists(js):
		return
	var e = JSON.parse_string(FileAccess.get_file_as_string(js))
	if e is Dictionary and e.get("deform_limits") is Dictionary:
		for k: String in e.deform_limits:
			var lim: Array = e.deform_limits[k]
			if lim.size() == 4:
				_fragment_limits[k] = lim


func _top(d: Dictionary, n: int) -> String:
	var keys := d.keys()
	keys.sort_custom(func(a, b) -> bool: return d[a] > d[b])
	var parts := PackedStringArray()
	for k in keys.slice(0, n):
		parts.append("%s %d" % [k, d[k]])
	return ", ".join(parts)
