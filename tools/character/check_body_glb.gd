extends SceneTree
## Checks assets/character/actor_b_body.glb against the game's Actor_B skeleton.
##
##   Godot --headless --path <Frontier> -s tools/character/check_body_glb.gd [-- glb=<path>[,<path>...]|customizer|all]
##
## glb=customizer: assets/character/body/body.glb and every hair style and garment glb
## of the catalog fragments (assets/character/hair/*.json, garments/**/*.json);
## glb=all: those and the legacy actor_b_body.glb (the default when no glb= is given).
##
## 1. Every skin bind names a bone of characters/Actor_B.tscn and equals
##    inverse(null-add global pose) evaluated on that skeleton (the probe's bind
##    method; unkeyed channels fall back to the rest, like the deterministic mixer).
## 2. CPU linear-blend skinning at the null-add pose reproduces the mesh, i.e. the
##    mesh is in skeleton space and weights/binds are consistent.
## 3. Weights: at most 4 influences, normalised.
## Customizer parts (tools/character/lib) also:
## 4. The skin has the full rig: all 291 joints, in the order of the Actor_B skeleton (so
##    every part can share one Skin at runtime).
## 5. Region codes (UV2.x = region + 64 * zone): exact integers, known region ids (body
##    0..37, hair zones 48..52), zones 0..3, and all three vertices of every triangle
##    carry the same code (region borders split), so a hidden region collapses whole
##    triangles only.
## 6. Blend shapes: named `sex`, `sex_head`, `blink`, `hat_fit`, `style`, `style_male`, `blink_style` or `face_*`, deltas at most MAX_SHAPE_DELTA; every part has
##    `sex`.
## Prints CHECK PASSED / CHECK FAILED. Loads the .glb directly (no import needed).

const BIND_CLIP := "null-add"
const TOL_BIND := 1e-4       # per matrix element / metre
const TOL_LBS := 1e-4        # metres
## 6 cm since hair v2 (2026-09-27): the MakeHuman ponytail lying on the male fit's fuller nape and
## back moves 5.4 cm with `sex`.
const MAX_SHAPE_DELTA := 0.06
## The body's own `sex` shape (body v4, 2026-09-28): the male genitals unfold from inside the female base;
## `breast_large` (the bust gauge at MakeHuman's max cup) moves as far
const MAX_BODY_SEX_DELTA := 0.10
## body v4's body shapes: the bust gauge and each man's size (BodyMaterials bust / genital)
const BODY_SHAPES := ["breast_large", "breast_small", "genital_small", "genital_large"]
const LEGACY := "res://assets/character/actor_b_body.glb"
const BODY := "res://assets/character/body/body.glb"

var args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	var ok := _run()
	print("CHECK PASSED" if ok else "CHECK FAILED")
	quit(0 if ok else 1)


func _run() -> bool:
	var sel: String = args.get("glb", "all")
	var paths: Array = []
	if sel in ["all", "customizer"]:
		if sel == "all":
			paths.append(LEGACY)
		paths.append(BODY)
		paths += _catalog_glbs()
	else:
		paths = Array(sel.split(","))
	var inst := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate()
	var sk := inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var lib := ap.get_animation_library("actor_b")
	var bind_g := _globals(sk, _clip_locals(sk, lib.get_animation(BIND_CLIP), 0.0))
	var ok := true
	for path: String in paths:
		print("== ", path)
		var good := _check_glb(path, sk, bind_g, path != LEGACY)
		if not good:
			print("   FAILED: ", path)
		ok = ok and good
	inst.free()
	return ok


func _catalog_glbs() -> Array:
	var out := []
	var dirs := ["res://assets/character/hair"]
	var gd := DirAccess.open("res://assets/character/garments")
	if gd:
		for d in gd.get_directories():
			dirs.append("res://assets/character/garments/" + d)
	for d: String in dirs:
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".json"):
				var e = JSON.parse_string(FileAccess.get_file_as_string(d + "/" + f))
				if e is Dictionary and e.has("glb") and e.has("slot"):
					out.append(String(e.glb))
	out.sort()
	return out


func _check_glb(path: String, sk: Skeleton3D, bind_g: Array, customizer: bool) -> bool:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_file(ProjectSettings.globalize_path(path), st)
	if err != OK:
		push_error("cannot read %s (%d)" % [path, err])
		return false
	var scene := doc.generate_scene(st)
	var gsk := scene.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D

	var ok := true
	var total_tris := 0
	var bones_used := {}
	var known := {}
	for r in 38:
		known[r] = true
	for r in range(48, 53):
		known[r] = true
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var skin := m.skin
		var mesh := m.mesh as ArrayMesh
		var rel: Transform3D = _to_scene(gsk).affine_inverse() * _to_scene(m)
		var bind_err := 0.0
		var names := PackedStringArray()
		for i in skin.get_bind_count():
			var bn := String(skin.get_bind_name(i))
			if bn.is_empty():
				bn = gsk.get_bone_name(skin.get_bind_bone(i))
			names.append(bn)
			var b := sk.find_bone(bn)
			if b < 0:
				push_error("%s: bind %d names unknown bone '%s'" % [m.name, i, bn])
				ok = false
				continue
			var want: Transform3D = (bind_g[b] as Transform3D).orthonormalized().affine_inverse()
			bind_err = maxf(bind_err, _xf_diff(skin.get_bind_pose(i), want))
		if customizer:
			var in_order := names.size() == sk.get_bone_count()
			for i in mini(names.size(), sk.get_bone_count()):
				in_order = in_order and names[i] == sk.get_bone_name(i)
			print("  %s: %d joints, rig order %s" % [m.name, names.size(), in_order])
			if not in_order:
				ok = false
		var lbs_err := 0.0
		var max_inf := 0
		var wsum_err := 0.0
		var tris := 0
		var code_bad := 0
		var split_bad := 0
		var codes := {}
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			var vtx: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bi: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var bw: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			tris += idx.size() / 3 if idx.size() > 0 else vtx.size() / 3
			var nb := bi.size() / maxi(vtx.size(), 1)
			for v in vtx.size():
				var p := Vector3.ZERO
				var ws := 0.0
				var cnt := 0
				for k in nb:
					var w := bw[v * nb + k]
					if w <= 0.0:
						continue
					cnt += 1
					ws += w
					var j := bi[v * nb + k]
					var b := sk.find_bone(names[j])
					bones_used[names[j]] = true
					p += (bind_g[b] as Transform3D).orthonormalized() * (skin.get_bind_pose(j) * (rel * vtx[v])) * w
				max_inf = maxi(max_inf, cnt)
				wsum_err = maxf(wsum_err, absf(ws - 1.0))
				lbs_err = maxf(lbs_err, p.distance_to(rel * vtx[v]))
			if customizer:
				var uv2 = arr[Mesh.ARRAY_TEX_UV2]
				if uv2 == null:
					print("  %s surface %d: no UV2 (region codes)" % [m.name, s])
					ok = false
				else:
					var u2: PackedVector2Array = uv2
					for v in u2.size():
						var c := roundi(u2[v].x)
						if absf(u2[v].x - c) > 1e-3 or not known.has(c & 63) or (c >> 6) > 3:
							code_bad += 1
						codes[c] = true
					for t in idx.size() / 3:
						var c0 := roundi(u2[idx[3 * t]].x)
						if roundi(u2[idx[3 * t + 1]].x) != c0 or roundi(u2[idx[3 * t + 2]].x) != c0:
							split_bad += 1
		total_tris += tris
		var line := "%s: surfaces %d, tris %d, binds %d, max bind error %.7f, LBS at bind max error %.7f m, max influences %d, weight-sum error %.6f, mesh->skeleton %s" % [
			m.name, mesh.get_surface_count(), tris, skin.get_bind_count(), bind_err, lbs_err, max_inf, wsum_err,
			"identity" if rel.is_equal_approx(Transform3D.IDENTITY) else str(rel)]
		print(line)
		if bind_err > TOL_BIND or lbs_err > TOL_LBS or max_inf > 4 or wsum_err > 1e-3:
			ok = false
		if customizer:
			var shapes_ok := true
			var has_sex := false
			var shape_line := PackedStringArray()
			for bsi in mesh.get_blend_shape_count():
				var bn := String(mesh.get_blend_shape_name(bsi))
				has_sex = has_sex or bn == "sex"
				var dmax := 0.0
				for s in mesh.get_surface_count():
					var base: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
					var sv: PackedVector3Array = mesh.surface_get_blend_shape_arrays(s)[bsi][Mesh.ARRAY_VERTEX]
					for v in base.size():
						dmax = maxf(dmax, sv[v].distance_to(base[v]))
				shape_line.append("%s %.4f" % [bn, dmax])
				# (style, style_male, blink_style: the Stylized face style, lib/stylize.py)
				# the body's own shapes (the bust gauge, each man's size, the wide `sex`) are also the cloth2 garments': they
				# follow the body by the same morph targets (lib_version 2 sidecar)
				var own := path.ends_with("body/body.glb") or _is_cloth2(path)
				if not (bn in ["sex", "sex_head", "blink", "hat_fit", "style", "style_male", "blink_style"] or bn.begins_with("face_")
						or (own and bn in BODY_SHAPES)) \
						or dmax > (MAX_BODY_SEX_DELTA if own and bn in ["sex", "breast_large"] else MAX_SHAPE_DELTA):
					shapes_ok = false
			var mats := PackedStringArray()
			for s in mesh.get_surface_count():
				var mat := mesh.surface_get_material(s)
				mats.append(mat.resource_name if mat else "?")
			print("  %s: surfaces %s, region codes %d distinct, %d invalid, %d triangles across a region border; shapes: %s" % [
					m.name, ", ".join(mats), codes.size(), code_bad, split_bad, ", ".join(shape_line)])
			if code_bad > 0 or split_bad > 0 or not shapes_ok or not has_sex or "?" in mats:
				ok = false
	print("total tris %d, deform bones used %d, glb skeleton bones %d" % [total_tris, bones_used.size(), gsk.get_bone_count()])
	scene.free()
	return ok


## A cloth2 garment (tools/character/cloth2): its sidecar json is a catalog entry of lib_version 2.
func _is_cloth2(path: String) -> bool:
	var j := path.get_basename() + ".json"
	if not FileAccess.file_exists(j):
		return false
	var e = JSON.parse_string(FileAccess.get_file_as_string(j))
	return e is Dictionary and int(e.get("lib_version", 1)) >= 2


## Transform of `n` relative to the root of its (out-of-tree) scene.
func _to_scene(n: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	while n != null:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func _xf_diff(a: Transform3D, b: Transform3D) -> float:
	var d := 0.0
	for c in 3:
		d = maxf(d, (a.basis[c] - b.basis[c]).length())
	return maxf(d, (a.origin - b.origin).length())


## Local transforms of `anim` at `t`; unkeyed channels use the skeleton rest.
func _clip_locals(sk: Skeleton3D, anim: Animation, t: float) -> Array:
	var n := sk.get_bone_count()
	var pos := []
	var rot := []
	var scl := []
	for b in n:
		var r := sk.get_bone_rest(b)
		pos.append(r.origin)
		rot.append(r.basis.get_rotation_quaternion())
		scl.append(r.basis.get_scale())
	for i in anim.get_track_count():
		var b := sk.find_bone(str(anim.track_get_path(i)).get_slice(":", 1))
		if b < 0:
			continue
		match anim.track_get_type(i):
			Animation.TYPE_POSITION_3D: pos[b] = anim.position_track_interpolate(i, t)
			Animation.TYPE_ROTATION_3D: rot[b] = anim.rotation_track_interpolate(i, t)
			Animation.TYPE_SCALE_3D: scl[b] = anim.scale_track_interpolate(i, t)
	var out := []
	for b in n:
		out.append(Transform3D(Basis(rot[b]).scaled(scl[b]), pos[b]))
	return out


func _globals(sk: Skeleton3D, locals: Array) -> Array:
	var g := []
	g.resize(sk.get_bone_count())
	for b in sk.get_bone_count():
		_glob(sk, b, locals, g)
	return g


func _glob(sk: Skeleton3D, b: int, locals: Array, g: Array) -> Transform3D:
	if g[b] != null:
		return g[b]
	var p := sk.get_bone_parent(b)
	var t: Transform3D = locals[b] if p < 0 else _glob(sk, p, locals, g) * locals[b]
	g[b] = t
	return t
