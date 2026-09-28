extends RefCounted
## WP0 rig suite: the Actor_B rest is the game's bind pose `null-add` (plan section 4).
##
## Checks
##   - rest == null-add@t0 on every channel null-add keys (1e-6 rad / 1e-6 m), via BindRest.verify
##   - RESET == rest (1e-3 rad, 1e-4 m)
##   - Skeleton3D "bind_rest" stamp from build_libraries.gd (missing = warning)
##   - BindRest.ensure: no-op on the shipped rig (and < 1 ms); repairs a corrupted rest; idempotent
##     (a second call changes 0 bones)
##   - Add2(clip, null-add) == clip for 4 clips (2 mm)
##   - additive-reference audit: additive clips referenced by animations/actor_b_graph.json (or, until
##     WP1 lands, the plan's additive list) key no channel null-add lacks by more than 5 mm / 0.02 rad
##   - skin check when assets/character/actor_b_body.glb exists (binds == inverse(global rest) 1e-4,
##     skinned-at-rest vertices == bind-space vertices 1 mm), else SKIP
##   - Actor_B.res animation content (names, metadata incl. native_asset_id / source_attribution,
##     tracks, keys) hashes to the pinned value: no work package may alter the extracted data.
##
## Suite contract (plan section 10): `func run(ctx)` using ctx.check(cond, msg) and, when present,
## ctx.skip(msg) / ctx.warn(msg) / ctx.allow_error(substring). It is a duck-typed suite (extends
## RefCounted, which tests/anim/run_all.gd accepts) so that it also runs without the WPT harness:
## tools/anim_graph/sync_rig.sh runs it through standalone(), i.e. a SceneTree script doing
##   quit(await load("res://tests/anim/test_rig.gd").standalone(self))
## Optional user args: body=<glb> (skin-check another body), graph=<json>.

const RIG := "res://characters/Actor_B.tscn"
const LIB := &"actor_b"
const GRAPH := "res://animations/actor_b_graph.json"
const BODY := "res://assets/character/actor_b_body.glb"
## Content hash of res://animations/Actor_B.res (2490 animations) as extracted and converted.
## Update only when the rig is deliberately re-exported from the source libraries.
const CONTENT_SHA256 := "5d025429dd007cb1f768b2cc3d566b88b663e2e17e3cb6693d02c0c9b87f0324"
const ADD2_CLIPS := ["actor_b-p-stealth-idle", "actor_b-p-run-fw", "actor_b-p-rifle-idle-aim", "actor_b-p-bow-aim-idle"]
## Additive clips the plan uses (plan section 2, probe F2); audited until actor_b_graph.json exists.
const PLAN_ADDITIVES := [
	"actor_b-p-rifle-idle-aim-up--add", "actor_b-p-rifle-idle-aim-down--add",
	"actor_b-p-rifle-idle-crouch-aim-up--add", "actor_b-p-rifle-idle-crouch-aim-down--add",
	"actor_b-p-bow-aim-up--add", "actor_b-p-bow-aim-down--add",
	"actor_b-p-bow-crouch-aim-up--add", "actor_b-p-bow-crouch-aim-down--add",
	"actor_b-p-pistol-aim-up", "actor_b-p-pistol-aim-down",
	"actor_b-p-pistol-aim-crouch-up", "actor_b-p-pistol-aim-crouch-down",
	"actor_b-p-rifle-idle-aim-fire--add", "actor_b-p-rifle-idle-crouch-aim-fire--add",
	"actor_b-p-pistol-fire--add", "actor_b-p-bow-fire--add", "actor_b-p-crouch-bow-fire--add",
	"actor_b-p-bow-aim-charge--add", "actor_b-p-bow-crouch-aim-charge--add",
	"actor_b-p-rifle-run-arms--add", "actor_b-p-rifle-idle-spine--add", "actor_b-p-rifle-crouch-run-arms--add",
	"actor_b-p-rifle-idle-arms--add", "actor_b-r-arm-gun-crouch-idle--add",
	"actor_b-p-hr-bliz-fw--add", "actor_b-p-hr-bliz-bw--add", "actor_b-p-hr-bliz-lt--add", "actor_b-p-hr-bliz-rt--add",
	"actor_b-p-hr-fw--add", "actor_b-p-hr-bw--add", "actor_b-p-hr-lt--add", "actor_b-p-hr-rt--add",
	"actor_b-lg-stealth-draw^idle--add", "actor_b-p-bow-draw-grab^idle--add",
	"actor_b-p-bow-reload--add", "actor_b-p-rifle-idle-aim-reload-begin--add", "actor_b-p-rifle-idle-aim-reload-mid--add",
	"actor_b-p-rifle-idle-aim-reload-over--add", "actor_b-p-pistol-rev-reload-begin--add",
	"actor_b-p-pistol-rev-reload-mid--add", "actor_b-p-pistol-rev-reload-over--add",
]

var _args := {}


func describe() -> String:
	return "WP0: rest == null-add bind pose, RESET, stamp, BindRest.ensure, Add2 identity, additive audit, skin, content hash"


func timeout_s() -> float:
	return 300.0


func run(ctx) -> void:
	if ctx.has_method("allow_error"):
		ctx.allow_error("BindRest.ensure")    # the deliberate-corruption case below warns once
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			_args[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	var tree := Engine.get_main_loop() as SceneTree
	var inst: Node3D = (load(RIG) as PackedScene).instantiate()
	tree.root.add_child(inst)
	var sk: Skeleton3D = inst.get_node("Skeleton3D")
	var ap: AnimationPlayer = inst.get_node("AnimationPlayer")
	var lib := ap.get_animation_library(LIB)
	ctx.check(sk.get_bone_count() == 291, "Actor_B skeleton has 291 bones (%d)" % sk.get_bone_count())

	# rest == null-add
	var v := BindRest.verify(sk, ap)
	ctx.check(v.ok, "BindRest.verify ok: rest == null-add on %d channels (rot %s rad, pos %s m)%s" % [
			v.channels, BindRest.sci(v.max_rot), BindRest.sci(v.max_pos), "" if v.ok else " -- " + v.reason])
	ctx.check(v.channels == 358, "null-add keys 358 rest channels (190 rotations + 168 positions): %d" % v.channels)
	ctx.check(v.max_rot <= 1e-6 and v.max_pos <= 1e-6, "rest == null-add within 1e-6 rad / 1e-6 m")

	# RESET == rest
	_check_reset(ctx, sk, lib)

	# stamp
	if v.stamped:
		var s: Dictionary = sk.get_meta(BindRest.STAMP)
		var want := str(lib.get_animation(BindRest.REF).get_meta("native_asset_id", ""))
		ctx.check(str(s.get("native_asset_id", "")) == want and int(s.get("channels", -1)) == v.channels,
				"bind_rest stamp matches null-add (native_asset_id %s, %s channels): %s" % [want, v.channels, s])
	else:
		_warn(ctx, "Actor_B.tscn Skeleton3D has no 'bind_rest' stamp (re-run build_libraries.gd + sync_rig.sh)")

	# ensure(): no-op on the shipped rig, repair on a corrupted copy, idempotent
	var e0 := {}
	var us := 1 << 30
	for i in 3:    # best of 3, so a busy machine does not fail the timing check
		var t0 := Time.get_ticks_usec()
		e0 = BindRest.ensure(sk, ap)
		us = mini(us, Time.get_ticks_usec() - t0)
	ctx.check(e0.ok and e0.changed == 0, "ensure() on the shipped rig is a no-op (changed %d bones, %d us)" % [e0.changed, us])
	ctx.check(us < 1000, "ensure() no-op costs < 1 ms (%d us)" % us)
	await _check_repair(ctx, tree, sk)

	# Add2 identity
	var at := AnimationTree.new()
	inst.add_child(at)
	at.anim_player = at.get_path_to(ap)
	at.root_node = at.get_path_to(inst)
	for clip: String in ADD2_CLIPS:
		var base := _pose(at, sk, clip, "", 0.0)
		var ident := _pose(at, sk, clip, String(BindRest.REF), 1.0)
		var err := 0.0
		for b in sk.get_bone_count():
			err = maxf(err, (base[b] as Transform3D).origin.distance_to((ident[b] as Transform3D).origin))
		ctx.check(err <= 0.002, "Add2(%s, null-add) == %s (max joint error %.5f m)" % [clip, clip, err])
	at.active = false
	at.queue_free()
	sk.reset_bone_poses()

	# additive-reference audit
	_audit(ctx, sk, lib)

	# skin check
	await _skin_check(ctx, tree, sk)

	# animation data unchanged: the file, loaded afresh. The cached library is not the file once a level
	# ran in this process: the player's traversal smooths the key interpolation of the clips its moves
	# play, in memory (TravInertializer.smooth_clip_tracks / resample_hermite, by design), so hashing
	# it failed this check whenever a level suite ran before this one.
	var path := lib.resource_path if lib.resource_path != "" else "res://animations/Actor_B.res"
	var disk := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as AnimationLibrary
	var h := content_sha256(disk) if disk else "(load failed)"
	ctx.check(h == CONTENT_SHA256, "Actor_B.res animation content sha256 unchanged (%s, %s)" % [path, h])
	var hm := content_sha256(lib)
	if ctx.has_method("info"):
		ctx.info("the library in memory %s the file%s" % ["matches" if hm == h else "differs from",
				"" if hm == h else " (clips smoothed in memory by the traversal of a level loaded earlier in this process)"])

	inst.queue_free()
	await tree.process_frame


func _check_reset(ctx, sk: Skeleton3D, lib: AnimationLibrary) -> void:
	if not lib.has_animation(&"RESET"):
		ctx.check(false, "library has RESET")
		return
	var reset := lib.get_animation(&"RESET")
	var wr := 0.0
	var wp := 0.0
	var bones := {}
	for t in reset.get_track_count():
		var b := sk.find_bone(str(reset.track_get_path(t).get_concatenated_subnames()))
		if b == -1:
			continue
		bones[b] = true
		var rest := sk.get_bone_rest(b)
		match reset.track_get_type(t):
			Animation.TYPE_ROTATION_3D:
				wr = maxf(wr, BindRest.quat_angle(rest.basis.get_rotation_quaternion(), reset.rotation_track_interpolate(t, 0.0).normalized()))
			Animation.TYPE_POSITION_3D:
				wp = maxf(wp, BindRest.vec_dist(rest.origin, reset.position_track_interpolate(t, 0.0)))
	ctx.check(bones.size() == sk.get_bone_count() and wr <= 1e-3 and wp <= 1e-4,
			"RESET == rest on %d/%d bones (max %s rad, %s m)" % [bones.size(), sk.get_bone_count(), BindRest.sci(wr), BindRest.sci(wp)])


## A second rig instance with its rest pushed off null-add (rotations, positions, and all
## keyed channels reset to identity on a few bones) must be repaired by ensure(), which then
## changes nothing on a second call. Channels null-add does not key are left alone.
func _check_repair(ctx, tree: SceneTree, ref_sk: Skeleton3D) -> void:
	var inst: Node3D = (load(RIG) as PackedScene).instantiate()
	tree.root.add_child(inst)
	var sk: Skeleton3D = inst.get_node("Skeleton3D")
	var ap: AnimationPlayer = inst.get_node("AnimationPlayer")
	var corrupt := {"spinea": Transform3D(Basis(Vector3.UP, 0.3), Vector3(0, 0.05, 0)),
			"l_knee": Transform3D(Basis(Vector3.RIGHT, -0.4), Vector3(0.02, 0, 0)),
			"r_wrist": Transform3D(), "heada": Transform3D()}
	for nm: String in corrupt:
		var b := sk.find_bone(nm)
		var r := sk.get_bone_rest(b)
		sk.set_bone_rest(b, Transform3D() if corrupt[nm] == Transform3D() else r * corrupt[nm])
	var bad := BindRest.verify(sk, ap)
	ctx.check(not bad.ok, "verify() detects a corrupted rest (%s)" % bad.reason)
	print("  (expected: one BindRest.ensure WARNING for this deliberately corrupted rig)")
	var e1 := BindRest.ensure(sk, ap)
	ctx.check(e1.ok and e1.changed == corrupt.size(), "ensure() repairs the corrupted rest (changed %d bones, post rot %s rad)" % [
			e1.changed, BindRest.sci(e1.max_rot)])
	var e2 := BindRest.ensure(sk, ap)
	ctx.check(e2.ok and e2.changed == 0, "ensure() is idempotent (second call changed %d bones)" % e2.changed)
	var d := 0.0
	for b in sk.get_bone_count():
		d = maxf(d, BindRest.vec_dist(sk.get_bone_rest(b).origin, ref_sk.get_bone_rest(b).origin))
		d = maxf(d, BindRest.quat_angle(sk.get_bone_rest(b).basis.get_rotation_quaternion(), ref_sk.get_bone_rest(b).basis.get_rotation_quaternion()))
	ctx.check(d <= 1e-6, "repaired rest equals the shipped rest on all bones (max %s)" % BindRest.sci(d))
	var p := sk.get_bone_pose(sk.find_bone("spinea"))
	ctx.check(p.is_equal_approx(sk.get_bone_rest(sk.find_bone("spinea"))), "ensure() resets bone poses to the new rest")
	inst.queue_free()
	await tree.process_frame


func _pose(at: AnimationTree, sk: Skeleton3D, clip: String, add: String, amount: float) -> Array:
	var bt := AnimationNodeBlendTree.new()
	var a := AnimationNodeAnimation.new()
	a.animation = "actor_b/" + clip
	bt.add_node("base", a)
	var n := AnimationNodeAnimation.new()
	n.animation = "actor_b/" + (add if add != "" else String(BindRest.REF))
	bt.add_node("add", n)
	bt.add_node("sum", AnimationNodeAdd2.new())
	bt.connect_node("sum", 0, "base")
	bt.connect_node("sum", 1, "add")
	bt.connect_node("output", 0, "sum")
	at.tree_root = bt
	at.active = true
	at.set("parameters/sum/add_amount", amount)
	at.advance(0.0)
	at.advance(0.0)
	var out := []
	for b in sk.get_bone_count():
		out.append(sk.get_bone_global_pose(b))
	return out


## Additive clips that key a channel null-add does not key are composed against the imported rest
## there, which is not the game's bind pose; the clips the graph uses must stay within 5 mm / 0.02 rad.
func _audit(ctx, sk: Skeleton3D, lib: AnimationLibrary) -> void:
	var bind_ch := {}
	var bind := lib.get_animation(BindRest.REF)
	for t in bind.get_track_count():
		bind_ch["%s|%d" % [bind.track_get_path(t).get_concatenated_subnames(), bind.track_get_type(t)]] = true
	var graph_path: String = _args.get("graph", GRAPH)
	var names := []
	var source := ""
	if FileAccess.file_exists(graph_path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(graph_path))
		ctx.check(data != null, "%s parses as JSON" % graph_path)
		var found := {}
		_collect(data, lib, found)
		names = found.keys()
		source = graph_path
	else:
		names = PLAN_ADDITIVES
		source = "plan list (%s not generated yet)" % graph_path
	var n := 0
	var over := []
	var worst := [0.0, ""]
	for nm: String in names:
		if not lib.has_animation(nm):
			continue
		var a := lib.get_animation(nm)
		if not a.get_meta("additive_source", false):
			continue
		n += 1
		for t in a.get_track_count():
			var ty := a.track_get_type(t)
			var bone_name := str(a.track_get_path(t).get_concatenated_subnames())
			var b := sk.find_bone(bone_name)
			if b == -1 or bind_ch.has("%s|%d" % [bone_name, ty]):
				continue
			if ty != Animation.TYPE_ROTATION_3D and ty != Animation.TYPE_POSITION_3D:
				continue
			var rest := sk.get_bone_rest(b)
			var m := 0.0
			for k in a.track_get_key_count(t):
				var tm := a.track_get_key_time(t, k)
				if ty == Animation.TYPE_ROTATION_3D:
					m = maxf(m, BindRest.quat_angle(rest.basis.get_rotation_quaternion(), a.rotation_track_interpolate(t, tm).normalized()))
				else:
					m = maxf(m, BindRest.vec_dist(rest.origin, a.position_track_interpolate(t, tm)))
			var tol := 0.02 if ty == Animation.TYPE_ROTATION_3D else 0.005
			if m / tol > worst[0]:
				worst = [m / tol, "%s %s|%s %.4f" % [nm, bone_name, "r" if ty == Animation.TYPE_ROTATION_3D else "p", m]]
			if m > tol:
				over.append(worst[1])
	ctx.check(over.is_empty(), "additive audit on %d additive clips from %s: %d channel(s) null-add lacks deviate > 5 mm / 0.02 rad%s%s" % [
			n, source, over.size(), (" (worst in tolerance: %s)" % worst[1]) if worst[1] != "" and over.is_empty() else "",
			(": " + ", ".join(over)) if not over.is_empty() else ""])


func _collect(v: Variant, lib: AnimationLibrary, out: Dictionary) -> void:
	if v is Dictionary:
		for k: Variant in v:
			_collect(k, lib, out)
			_collect(v[k], lib, out)
	elif v is Array:
		for e: Variant in v:
			_collect(e, lib, out)
	elif v is String:
		var s: String = v
		if s.begins_with("actor_b/"):
			s = s.substr(8)
		if s != "" and lib.has_animation(s):
			out[s] = true


func _skin_check(ctx, tree: SceneTree, sk: Skeleton3D) -> void:
	var path: String = _args.get("body", BODY)
	var scene: Node = null
	if ResourceLoader.exists(path) and path.begins_with("res://"):
		var ps := load(path) as PackedScene
		if ps:
			scene = ps.instantiate()
	if scene == null:
		var abs_path := ProjectSettings.globalize_path(path)
		if not FileAccess.file_exists(abs_path):
			_skip(ctx, "skin check: no body glb at %s (the skinned-body workflow has not delivered it yet)" % path)
			return
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if "use_named_skin_binds" in st:
			st.set("use_named_skin_binds", true)
		var err := doc.append_from_file(abs_path, st)
		scene = doc.generate_scene(st) if err == OK else null
		if scene == null:
			ctx.check(false, "skin check: %s loads (%s)" % [path, error_string(err)])
			return
	tree.root.add_child(scene)
	await tree.process_frame
	var r := skin_report(sk, scene)
	scene.queue_free()
	await tree.process_frame
	print("  skin check %s: %d skinned mesh(es), %d binds, %d vertices, weight sums %.4f..%.4f" % [
			path, r.meshes, r.binds, r.vertices, r.min_wsum, r.max_wsum])
	ctx.check(r.meshes > 0 and r.missing.is_empty(), "skin check: every bind names a bone of the game skeleton%s" % (
			"" if r.missing.is_empty() else " (missing: %s)" % [r.missing]))
	ctx.check(r.meshes > 0 and r.max_bind <= 1e-4, "skin check: bind == inverse(global rest) (max %s, worst %s)" % [BindRest.sci(r.max_bind), r.worst_bind])
	ctx.check(r.meshes > 0 and r.max_vertex <= 0.001, "skin check: skinned at rest == bind-space vertices (max %.3f mm)" % (r.max_vertex * 1000.0))


## Re-parents (copies of) the skinned meshes under `body_root` to `skel` the way the body
## pipeline does (identity transform, skeleton = "..", named binds), compares every bind with
## inverse(global rest) and CPU-skins every vertex with the skeleton at rest.
static func skin_report(skel: Skeleton3D, body_root: Node) -> Dictionary:
	var out := {"meshes": 0, "binds": 0, "vertices": 0, "missing": [], "max_bind": 0.0, "worst_bind": "",
			"max_vertex": 0.0, "min_wsum": INF, "max_wsum": 0.0}
	skel.reset_bone_poses()
	for node in body_root.find_children("*", "MeshInstance3D", true, false):
		var src := node as MeshInstance3D
		if src.skin == null or src.mesh == null:
			continue
		var gsk := src.get_node_or_null(src.skeleton) as Skeleton3D
		var skin: Skin = src.skin.duplicate()
		var bind_bone := PackedInt32Array()
		for i in skin.get_bind_count():
			var nm := String(skin.get_bind_name(i))
			if nm == "" and gsk != null and skin.get_bind_bone(i) >= 0:
				nm = gsk.get_bone_name(skin.get_bind_bone(i))
				skin.set_bind_name(i, nm)
			var b := skel.find_bone(nm)
			bind_bone.append(b)
			if b == -1:
				out.missing.append(nm)
				continue
			var d := _tdiff(skin.get_bind_pose(i), skel.get_bone_global_rest(b).affine_inverse())
			if d > out.max_bind:
				out.max_bind = d
				out.worst_bind = nm
		out.binds += skin.get_bind_count()
		var mi := MeshInstance3D.new()
		mi.mesh = src.mesh
		mi.skin = skin
		skel.add_child(mi)
		mi.skeleton = NodePath("..")
		out.meshes += 1
		var mats := []
		for i in skin.get_bind_count():
			var b := bind_bone[i]
			mats.append(skel.get_bone_global_pose(b) * skin.get_bind_pose(i) if b >= 0 else Transform3D())
		var mesh := src.mesh
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES] if arr[Mesh.ARRAY_BONES] != null else PackedInt32Array()
			var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS] if arr[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
			if verts.is_empty() or weights.size() != bones.size() or weights.size() % verts.size() != 0:
				out.missing.append("surface %d of %s has no usable weights" % [s, src.name])
				continue
			var per := int(weights.size() / verts.size())
			out.vertices += verts.size()
			for v in verts.size():
				var p := Vector3.ZERO
				var wsum := 0.0
				for k in per:
					var w := weights[v * per + k]
					if w == 0.0:
						continue
					wsum += w
					p += (mats[bones[v * per + k]] as Transform3D) * verts[v] * w
				out.min_wsum = minf(out.min_wsum, wsum)
				out.max_wsum = maxf(out.max_wsum, wsum)
				out.max_vertex = maxf(out.max_vertex, p.distance_to(verts[v]))
		mi.queue_free()
	return out


static func _tdiff(a: Transform3D, b: Transform3D) -> float:
	var d := a.origin.distance_to(b.origin)
	for i in 3:
		d = maxf(d, (a.basis[i] - b.basis[i]).length())
	return d


## sha256 over the sorted animations: name, metadata, length / loop / step, and every track's
## path, type, interpolation and keys. Same digest as godot_export/tools/verify_bind_rest.gd.
static func content_sha256(lib: AnimationLibrary) -> String:
	var names := Array(lib.get_animation_list()).map(func(x): return String(x))
	names.sort()
	var all := HashingContext.new()
	all.start(HashingContext.HASH_SHA256)
	for nm: String in names:
		var a := lib.get_animation(nm)
		var hc := HashingContext.new()
		hc.start(HashingContext.HASH_SHA256)
		hc.update(nm.to_utf8_buffer())
		var metas := Array(a.get_meta_list()).map(func(m): return String(m))
		metas.sort()
		for m: String in metas:
			hc.update(("%s=%s;" % [m, var_to_str(a.get_meta(m))]).to_utf8_buffer())
		hc.update(var_to_bytes([a.length, a.loop_mode, a.step, a.get_track_count()]))
		for t in a.get_track_count():
			hc.update(var_to_bytes([str(a.track_get_path(t)), a.track_get_type(t), a.track_get_interpolation_type(t),
					a.track_get_interpolation_loop_wrap(t), a.track_is_enabled(t), a.track_get_key_count(t)]))
			var times := PackedFloat64Array()
			var vals := []
			for k in a.track_get_key_count(t):
				times.append(a.track_get_key_time(t, k))
				vals.append(a.track_get_key_value(t, k))
			hc.update(times.to_byte_array())
			hc.update(var_to_bytes(vals))
		all.update(hc.finish())
	return all.finish().hex_encode()


func _skip(ctx, msg: String) -> void:
	if ctx.has_method("skip"):
		ctx.skip(msg)
	else:
		print("  SKIP " + msg)


func _warn(ctx, msg: String) -> void:
	if ctx.has_method("warn"):
		ctx.warn(msg)
	else:
		print("  WARN " + msg)


# --- standalone runner (used until the WPT harness tests/anim/run_all.gd exists) -----------------

class _Ctx extends RefCounted:
	var fails := 0
	var checks := 0
	func check(ok: bool, msg: String) -> void:
		checks += 1
		if not ok:
			fails += 1
		print(("  ok   " if ok else "  FAIL ") + msg)
	func near(a: float, b: float, tol: float, msg: String) -> void:
		check(absf(a - b) <= tol, "%s (%f vs %f, tol %f)" % [msg, a, b, tol])
	func skip(msg: String) -> void:
		print("  SKIP " + msg)
	func warn(msg: String) -> void:
		print("  WARN " + msg)
	func frames(n: int) -> void:
		for i in n:
			await (Engine.get_main_loop() as SceneTree).process_frame


## Runs this suite without the WPT harness; returns the process exit code.
static func standalone(_tree: SceneTree) -> int:
	var ctx := _Ctx.new()
	var suite: RefCounted = load("res://tests/anim/test_rig.gd").new()
	await suite.run(ctx)
	print("TEST_RIG %s (%d checks, %d failed)" % ["PASSED" if ctx.fails == 0 else "FAILED", ctx.checks, ctx.fails])
	return 0 if ctx.fails == 0 else 1
