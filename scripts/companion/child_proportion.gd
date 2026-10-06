class_name ChildProportion
extends SkeletonModifier3D
## A child's (or a baby's) proportions on the game's own body v4 and Actor_B skeleton, without shear or candy-wrapper twists: the
## proportions are BAKED into the child's own copies of the body meshes (the body, the head's eyes and brows, the hair, the
## garments) and into its own Skin binds, and this modifier moves the bones to the new joint positions after the animation. The bones
## keep their rotations and a scale of 1, so every clip, the twist helpers and the skirt panels (CharacterBodyMesh) work as on an adult.
##
## The bake (shape()): each part of the body is scaled in the bind pose (null-add) by its group's scale, the joints move with it:
##   "pelvis" "belly" "chest" "neck" "head"  [x across, y up, z front] in the skeleton's axes (the trunk, the short neck, the head)
##   "clavicle" "upper_arm" "forearm" "hand" "thigh" "shin" "foot"  [thickness, length] along the limb (or one number)
## (growth.json stage "form", baby.json body "form"; bones not named follow their parent: fingers the hand, the heel the foot). A
## vertex is moved by its own skin weights (the blend of its bones' scalings), so joints stay joined. Before that, three shape fields in
## the adult's space (data/companion/baby_body.json): the EYES larger about each eyeball (lids and lashes with them, the eyeball
## rigid), a young FACE (a smaller button nose, a smaller mouth, fuller cheeks, a shorter lower face: baby_body.json "face"), the HEAD
## ROUNDED toward a sphere round the cranium (HeadRound: the head's own radii by direction, fitted smooth, pulled toward the sphere of
## a little less than its volume, strong at the cranium and the jaw, light over the face; the head never gets bigger), and the TRUNK flattened to a soft round barrel (no chest
## or glute bulge, no waist-hip curve: the flat asexual child body; the garment follows it). The face shapes (the child's face from
## its parents, the flat `sex` fit) are baked in; `blink` stays a blend shape and two are made: `mouth_open` (the jaw dropped: crying,
## yawning, suckling) and `breath` (the chest and belly swelling).
## At run time the bones' offsets (their pose positions) are scaled by the parent's scale and the hips' height and sway by the legs'.
##   var p := ChildProportion.shape(body, Growth.form("toddler"))     # after PlayerAppearance.dress / BodyMaterials.apply_look
##   p.bind_global("headb")                                            # the new bind (skeleton space, before the model's scale)

const DATA := "res://data/companion/baby_body.json"
## The groups of the form and the bones they scale (the rest follow their parent).
const GROUPS := {
	"pelvis": ["root", "lower_base", "upper_base", "pelvis"], "belly": ["spinea", "spineb"], "chest": ["spinec", "spined"],
	"neck": ["neck"], "head": ["heada"],
	"clavicle": ["l_clavicle", "r_clavicle"], "upper_arm": ["l_shoulder", "r_shoulder"], "forearm": ["l_elbow", "r_elbow"],
	"hand": ["l_wrist", "r_wrist"], "thigh": ["l_upper_leg", "r_upper_leg"], "shin": ["l_knee", "r_knee"], "foot": ["l_ankle", "r_ankle"],
}
## A limb's axis: from the bone to this bone (or from the first to the second: the foot, heel to ball).
const AXIS := {
	"l_clavicle": "l_shoulder", "l_shoulder": "l_elbow", "l_elbow": "l_wrist", "l_wrist": "l_middle_metacarpal",
	"l_upper_leg": "l_knee", "l_knee": "l_ankle", "l_ankle": ["l_heel", "l_ball"],
}
const ARM_PARTS := ["shoulder", "elbow", "wrist", "forarm", "palm", "index", "middle", "ring", "pinky", "thumb", "deltoid"]
const TRUNK_BONES := ["root", "lower_base", "upper_base", "pelvis", "spinea", "spineb", "spinec", "spined", "l_breast", "r_breast",
		"l_chest", "r_chest", "spinea_muscle", "spinea_back_muscle", "spineb_muscle", "shirt_lift_a", "shirt_lift_b", "shirt_lift_c",
		"shirt_lift_d", "shirt_lift_e", "jacket_collider"]
const HEAD_BONES := ["heada", "headb", "jaw"]

## Legacy: a uniform head scale on top at run time (1: none).
var head_scale := 1.0
## The form it was shaped with, and the shape fields' strengths it used (round, eyes).
var form := {}
var round_k := 0.0
## This body's lips' middle height (adult bind space; 0 unknown): the made mouth_open's line.
var lip_y := 0.0
var body: CharacterBodyMesh
var _off := {}            ## bone -> Basis: the parent's scale on the bone's pose position (its local offset)
var _root := -1
var _root_bind := Vector3.ZERO
var _root_new := Vector3.ZERO
var _root_f := 1.0
var _g: Array = []        ## bone -> the new bind global (Transform3D, skeleton space)
var _head_bone := -2

static var _cfg := {}


static func cfg() -> Dictionary:
	if _cfg.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA)) if FileAccess.file_exists(DATA) else null
		_cfg = d if d is Dictionary else {}
	return _cfg


## The modifier on `sk` (made when missing). Old callers: head_scale only.
static func attach(sk: Skeleton3D) -> ChildProportion:
	if sk == null:
		return null
	for c in sk.get_children():
		if c is ChildProportion:
			return c
	var p := ChildProportion.new()
	p.name = "ChildProportion"
	sk.add_child(p)
	sk.move_child(p, 0)     # before every other modifier (the helper driver stays last by itself)
	return p


## The proportion shaped onto `b` (null when it has none).
static func of(b: CharacterBodyMesh) -> ChildProportion:
	if b == null or b.skeleton == null:
		return null
	for c in b.skeleton.get_children():
		if c is ChildProportion and (c as ChildProportion).body == b:
			return c
	return null


# ---------------------------------------------------------------------------------------------------- run time
func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _pending:
		return
	apply_offsets(sk)
	if not is_equal_approx(head_scale, 1.0):
		if _head_bone == -2:
			_head_bone = sk.find_bone("heada")
		if _head_bone >= 0:
			sk.set_bone_pose_scale(_head_bone, sk.get_bone_pose_scale(_head_bone) * head_scale)


## The bones' offsets and the hips as this body has them (tools call it on a skeleton without the modifier running).
func apply_offsets(sk: Skeleton3D) -> void:
	for i: int in _off:
		sk.set_bone_pose_position(i, (_off[i] as Basis) * sk.get_bone_pose_position(i))
	if _root >= 0:
		sk.set_bone_pose_position(_root, _root_new + (sk.get_bone_pose_position(_root) - _root_bind) * _root_f)


## A bone's global pose as this body shows it (skeleton space): the animated pose with the offsets applied (outside the skeleton's
## update the skeleton itself holds the pose without them).
func posed_global(bone: String) -> Transform3D:
	var sk := get_parent() as Skeleton3D
	var i := sk.find_bone(bone) if sk != null else -1
	var t := Transform3D()
	while i >= 0:
		var pos := sk.get_bone_pose_position(i)
		if _off.has(i):
			pos = (_off[i] as Basis) * pos
		elif i == _root:
			pos = _root_new + (pos - _root_bind) * _root_f
		t = Transform3D(Basis(sk.get_bone_pose_rotation(i)).scaled_local(sk.get_bone_pose_scale(i)), pos) * t
		i = sk.get_bone_parent(i)
	return t


## Every bone's global as the skin shows it now (skeleton space): the pose with the offsets, the body's driven helpers (twist, skirt)
## on top. For CPU skinning (the baby's fitted swaddle) outside the skeleton's update.
func skin_globals() -> Array:
	var sk := get_parent() as Skeleton3D
	var n := sk.get_bone_count()
	var g: Array = []
	g.resize(n)
	var stack := Array(sk.get_parentless_bones())
	for b: int in stack:
		g[b] = _local(sk, b)
	while not stack.is_empty():
		var p: int = stack.pop_back()
		for c in sk.get_bone_children(p):
			g[c] = (g[p] as Transform3D) * _local(sk, c)
			stack.append(c)
	if body != null:
		var res := body._drive(g, Vector3.DOWN)
		for i in (res[0] as PackedInt32Array).size():
			g[res[0][i]] = res[1][i]
	return g


func _local(sk: Skeleton3D, i: int) -> Transform3D:
	var pos := sk.get_bone_pose_position(i)
	if _off.has(i):
		pos = (_off[i] as Basis) * pos
	elif i == _root:
		pos = _root_new + (pos - _root_bind) * _root_f
	return Transform3D(Basis(sk.get_bone_pose_rotation(i)).scaled_local(sk.get_bone_pose_scale(i)), pos)


## The head's own frame as this body shows it (world, from the skeleton's): x its left, y up, z the way the face looks (the head bone's
## turn from the bind pose applied to the skeleton's axes).
func head_basis() -> Basis:
	var sk := get_parent() as Skeleton3D
	var hb := sk.find_bone("headb")
	var g := posed_global("headb").basis.orthonormalized()
	var b0 := (_g[hb] as Transform3D).basis.orthonormalized() if hb < _g.size() else Basis()
	return sk.global_basis.orthonormalized() * g * b0.inverse()


## The root's pose position that puts the hips at `want` after this modifier (tools keying a clip's height).
func root_key_for(want: Vector3) -> Vector3:
	return _root_bind + (want - _root_new) / maxf(_root_f, 0.001)


## The legs' length as a share of the adult's (a clip's stride: the foot speed of a walk is this x the model's scale).
func leg_scale() -> float:
	return _root_f


## A bone's new bind global (skeleton space before the model node's scale); identity when unknown.
func bind_global(bone: String) -> Transform3D:
	var sk := get_skeleton() if is_inside_tree() else (get_parent() as Skeleton3D)
	var i := sk.find_bone(bone) if sk != null else -1
	return _g[i] if i >= 0 and i < _g.size() else Transform3D()


## A point of the adult's bind space (on `bone`'s part of the body) where it is on this body.
func map_point(bone: String, p: Vector3) -> Vector3:
	var sk := get_parent() as Skeleton3D
	var i := sk.find_bone(bone) if sk != null else -1
	if i < 0 or i >= _a.size() or _o.is_empty():
		return p
	return (_g[i] as Transform3D).origin + (_a[i] as Basis) * (p - _o[i])


var _a: Array = []
var _o := PackedVector3Array()
var _ctx := {}


## A point of the adult's head (bind space) where this body's face has it: the face's fields (eyes, features, the rounding) and the
## head bone's scaling (a mouth, a jewel on the face).
func map_face(bone: String, p: Vector3) -> Vector3:
	if _ctx.is_empty():
		return map_point(bone, p)
	return map_point(bone, _field(p, 1.0, 0.0, _ctx))


# ---------------------------------------------------------------------------------------------------- the bake
## Bumped when the bake's output changes (the disk cache's older entries are then not used).
const BAKE_VERSION := 5
const CACHE_DIR := "user://child_bake"
## Entries kept in the disk cache (the oldest go beyond it) and bakes kept in memory.
const DISK_MAX := 40
const MEM_MAX := 6
## Main-thread time an async bake may take in one frame to put its meshes on (it always puts on at least one).
const FRAME_BUDGET_US := 6000

## The disk cache (user://child_bake: a bake done once is read back when the same child at the same stage is made again, a game loaded).
static var disk_cache := true
## The source meshes' data (body.glb, the garments): their arrays and blend shapes, read once a run (and the blend shapes' deltas kept
## on disk). Source mesh instance id -> {mesh, names, surfs: [{arrays, fmt, prim, mat, sname, sparse}], raw, mutex, path}.
static var _src := {}
static var _mem := {}          ## bake key -> {meshes: [ArrayMesh per mesh], ctx, t}
static var _jobs: Array = []
static var _poller: _Poll
static var _mem_n := 0

## An async bake is on its way: the offsets wait for the new meshes and binds.
var _pending := false


class _Poll extends RefCounted:
	func tick() -> void:
		ChildProportion._poll()


## A bake's worker side (the job's data only: no node is touched off the main thread).
class _Work extends RefCounted:
	var job: Dictionary
	func run() -> void:
		ChildProportion._compute(job)


## Shapes `b` (dressed: its blend shapes set by apply_look) to `f` (a form: the groups above; "round" the head's rounding 0..1,
## "eyes" the eyes' size, "trunk" the barrel {k, depth, belly}), with `round_override` >= -1 replacing the form's rounding. Shaped
## again from the same meshes when called again (a new round_override). Returns the modifier (null without the bind pose). All on the
## calling thread (a second or more for a new look and stage; at once from the caches): shape_async does the heavy part off it.
static func shape(b: CharacterBodyMesh, f: Dictionary, round_override := -9.0) -> ChildProportion:
	var job := _begin(b, f, round_override)
	if job.is_empty():
		return null
	if not job.has("hit"):
		_compute(job)
	while int(job.i) < (job.items as Array).size():
		_apply_item(job)
	_finish(job)
	return job.p


## shape() with the heavy work off the main thread (the game: a child made or grown, a baby born or loaded): the joints are solved at
## once (the returned modifier's bind_global, leg_scale), the meshes are mixed and baked on a WorkerThreadPool task and put on over
## the next frames (a few ms each), then `done` is called with the modifier. Until then the body shows its old meshes without the new
## offsets: the caller keeps it hidden (or shows the body it replaces). A bake in memory is on at once (done called before this returns).
static func shape_async(b: CharacterBodyMesh, f: Dictionary, round_override := -9.0, done := Callable()) -> ChildProportion:
	var job := _begin(b, f, round_override)
	if job.is_empty():
		return null
	job["done"] = done
	var p: ChildProportion = job.p
	if job.has("hit"):
		while int(job.i) < (job.items as Array).size():
			_apply_item(job)
		_finish(job)
		return p
	p._pending = true
	var w := _Work.new()
	w.job = job
	job["task"] = WorkerThreadPool.add_task(w.run, false, "child bake")
	job["work"] = w
	_jobs.append(job)
	var tree := Engine.get_main_loop() as SceneTree
	if _poller == null:
		_poller = _Poll.new()
	if tree != null and not tree.process_frame.is_connected(_poller.tick):
		tree.process_frame.connect(_poller.tick)
	return p


## This script's own source (a changed field changes every bake's key; empty where the source is not shipped: BAKE_VERSION then).
static var _code := ""
static func _code_sig() -> String:
	if _code == "":
		var sc := load("res://scripts/companion/child_proportion.gd") as GDScript
		_code = sc.source_code.sha256_text().substr(0, 16) if sc != null and not sc.source_code.is_empty() else "-"
	return _code


## Empties the caches in memory (tests; the disk cache stays).
static func clear_caches() -> void:
	_mem.clear()
	_src.clear()


## True while `b` waits for an async bake.
static func pending(b: CharacterBodyMesh) -> bool:
	var p := of(b)
	return p != null and p._pending


## The main thread's side of the async bakes, once a frame: a finished task's meshes put on within the frame's budget, then finished.
static func _poll() -> void:
	var t0 := Time.get_ticks_usec()
	for job: Dictionary in _jobs.duplicate():
		if int(job.stage) == 1:
			if not WorkerThreadPool.is_task_completed(int(job.task)):
				continue
			WorkerThreadPool.wait_for_task_completion(int(job.task))
			job.stage = 2
		if not _alive(job):
			_jobs.erase(job)
			continue
		var n := 0
		while int(job.i) < (job.items as Array).size() and (n == 0 or Time.get_ticks_usec() - t0 < FRAME_BUDGET_US):
			_apply_item(job)
			n += 1
		if int(job.i) >= (job.items as Array).size():
			_finish(job)
			_jobs.erase(job)
		if Time.get_ticks_usec() - t0 >= FRAME_BUDGET_US:
			break
	if _jobs.is_empty():
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null and _poller != null and tree.process_frame.is_connected(_poller.tick):
			tree.process_frame.disconnect(_poller.tick)


static func _alive(job: Dictionary) -> bool:
	return is_instance_valid(job.p) and is_instance_valid(job.b) and not (job.p as ChildProportion).is_queued_for_deletion()


## The main thread's start of a bake: the joints solved, each mesh's source data and blend weights gathered, the bake's key (a
## bake in memory is taken at once; the disk is read by the worker).
static func _begin(b: CharacterBodyMesh, f: Dictionary, round_override: float) -> Dictionary:
	if b == null or b.skeleton == null or b._bind_g.is_empty():
		return {}
	var t0 := Time.get_ticks_usec()
	var sk := b.skeleton
	var p := of(b)
	if p == null:
		p = attach(sk)
		p.body = b
	p.form = f.duplicate(true)
	p.round_k = float(f.get("round", 0.0)) if round_override < -1.5 else round_override
	var sol := p.rig(sk, b._bind_g, f)
	var n := sk.get_bone_count()
	var head := PackedFloat32Array()
	var trunk := PackedFloat32Array()
	head.resize(n)
	trunk.resize(n)
	for nm: String in HEAD_BONES:
		var i := sk.find_bone(nm)
		if i >= 0:
			head[i] = 1.0
	# the trunk's weight: everything but the arms and the head (the hips' sides are the thighs' bones: they belong to the barrel above
	# the crotch; below it the height band leaves the legs alone)
	for i in n:
		var nm := sk.get_bone_name(i)
		var arm := false
		for k: String in ARM_PARTS:
			if nm.contains(k):
				arm = true
				break
		trunk[i] = 0.0 if arm or head[i] > 0.0 or nm == "neck" else 1.0
	var heads := b.part_meshes("head")
	var items := []
	var sig := PackedStringArray([str(BAKE_VERSION), _code_sig(), JSON.stringify(cfg()), JSON.stringify(f), str(snappedf(p.round_k, 0.0001))])
	for mi: MeshInstance3D in b.meshes:
		if not is_instance_valid(mi) or not mi.visible or mi.mesh == null:
			continue
		var it := _gather(mi)
		it["head"] = mi in heads
		items.append(it)
		sig.append("%s|%s|%s" % [String((it.src as Mesh).resource_path), (it.src as Mesh).get_surface_count(), str(it.w)])
	var key := "|".join(sig).sha256_text().substr(0, 24)
	var job := {"p": p, "b": b, "sol": sol, "form": f, "round_k": p.round_k, "items": items, "key": key, "cfg": cfg(), "head": head,
			"trunk": trunk, "i": 0, "stage": 1, "t0": t0, "main_us": Time.get_ticks_usec() - t0}
	if _mem.has(key):
		job["hit"] = _mem[key]
		job.stage = 2
		_mem_n += 1
		(_mem[key] as Dictionary).t = _mem_n
	return job


## A mesh's part of the bake: its source mesh (the one it was dressed with: kept when the body is shaped again) and that mesh's
## data (read once a run), its blend weights (the face shapes; blink open), its skin's binds' bones, its surfaces' materials.
static func _gather(mi: MeshInstance3D) -> Dictionary:
	if not mi.has_meta("cp_src"):
		var wts := {}
		for i in mi.get_blend_shape_count():
			wts[String(mi.mesh.get_blend_shape_name(i))] = mi.get_blend_shape_value(i)
		mi.set_meta("cp_src", mi.mesh)
		mi.set_meta("cp_w", wts)
	var src: Mesh = mi.get_meta("cp_src")
	var wts: Dictionary = mi.get_meta("cp_w")
	var e := _source(src)
	var w := PackedFloat32Array()
	for nm: String in e.names:
		w.append(snappedf(float(wts.get(nm, 0.0)), 0.0001) if nm != "blink" else 0.0)
	var skin: Skin = mi.get_meta("cp_skin", mi.skin)
	if not mi.has_meta("cp_skin"):
		mi.set_meta("cp_skin", skin)
	var bb := PackedInt32Array()
	if skin != null:
		for k in skin.get_bind_count():
			bb.append(skin.get_bind_bone(k))
	return {"mi": mi, "src": src, "e": e, "w": w, "skin": skin, "bb": bb}


## The source mesh's data for the bake (main thread, once a run: its arrays; the blend shapes' own arrays are read here the first time
## ever and turned into sparse deltas by the worker, which keeps them on disk; later runs read the deltas from there on the worker).
static func _source(src: Mesh) -> Dictionary:
	var id := src.get_instance_id()
	if _src.has(id):
		return _src[id]
	var am := src as ArrayMesh
	var names := PackedStringArray()
	if am != null:
		for i in am.get_blend_shape_count():
			names.append(String(am.get_blend_shape_name(i)))
	var surfs := []
	var sig := PackedStringArray([str(BAKE_VERSION), src.resource_path, ",".join(names)])
	for s in src.get_surface_count():
		var arr := src.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var mat := src.surface_get_material(s)
		surfs.append({"arrays": arr, "fmt": src.surface_get_format(s), "prim": src.surface_get_primitive_type(s), "mat": mat,
				"mname": mat.resource_name if mat != null else "", "sname": am.surface_get_name(s) if am != null else ""})
		sig.append("%d:%s:%s" % [v.size(), str(v[0]) if not v.is_empty() else "", str(v[v.size() / 2]) if not v.is_empty() else ""])
	var e := {"mesh": src, "names": names, "surfs": surfs, "mutex": Mutex.new(),
			"path": CACHE_DIR.path_join("src_%s.bin" % "|".join(sig).sha256_text().substr(0, 24))}
	if not names.is_empty() and not (disk_cache and FileAccess.file_exists(String(e.path))):
		var raw := []
		for s in src.get_surface_count():
			raw.append(am.surface_get_blend_shape_arrays(s))
		e["raw"] = raw
	_src[id] = e
	return e


## The source's blend shapes as sparse deltas from its base (worker: made from the raw arrays and written to disk, or read from there).
static func _sparse(e: Dictionary) -> void:
	var m: Mutex = e.mutex
	m.lock()
	if e.has("sparse") or (e.names as PackedStringArray).is_empty():
		if not e.has("sparse"):
			e["sparse"] = []
			for s in (e.surfs as Array).size():
				(e.sparse as Array).append([])
		m.unlock()
		return
	if not e.has("raw") and disk_cache and FileAccess.file_exists(String(e.path)):
		var fa := FileAccess.open_compressed(String(e.path), FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
		if fa != null:
			var d: Variant = fa.get_var()
			fa.close()
			if d is Array and (d as Array).size() == (e.surfs as Array).size():
				e["sparse"] = d
				m.unlock()
				return
	if not e.has("raw"):
		m.unlock()
		push_warning("ChildProportion: no blend shape data for %s" % String((e.mesh as Mesh).resource_path))
		e["sparse"] = []
		return
	var out := []
	for s in (e.surfs as Array).size():
		var base: Array = (e.surfs[s] as Dictionary).arrays
		var bv: PackedVector3Array = base[Mesh.ARRAY_VERTEX]
		var bn: PackedVector3Array = base[Mesh.ARRAY_NORMAL] if base[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var bt: PackedFloat32Array = base[Mesh.ARRAY_TANGENT] if base[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
		var shapes := []
		for sa: Array in (e.raw as Array)[s]:
			var sv: PackedVector3Array = sa[Mesh.ARRAY_VERTEX]
			var sn: PackedVector3Array = sa[Mesh.ARRAY_NORMAL] if sa[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var stn: PackedFloat32Array = sa[Mesh.ARRAY_TANGENT] if sa[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
			var idx := PackedInt32Array()
			var dv := PackedVector3Array()
			var dn := PackedVector3Array()
			var dt := PackedFloat32Array()
			var hn := sn.size() == bn.size() and not bn.is_empty()
			var ht := stn.size() == bt.size() and not bt.is_empty()
			for i in bv.size():
				var d := sv[i] - bv[i]
				var nd := sn[i] - bn[i] if hn else Vector3.ZERO
				if d.length_squared() < 1e-14 and nd.length_squared() < 1e-10:
					continue
				idx.append(i)
				dv.append(d)
				if hn:
					dn.append(nd)
				if ht:
					dt.append(stn[i * 4] - bt[i * 4])
					dt.append(stn[i * 4 + 1] - bt[i * 4 + 1])
					dt.append(stn[i * 4 + 2] - bt[i * 4 + 2])
			shapes.append([idx, dv, dn, dt])
		out.append(shapes)
	e["sparse"] = out
	e.erase("raw")
	if disk_cache:
		DirAccess.make_dir_recursive_absolute(CACHE_DIR)
		var fa := FileAccess.open_compressed(String(e.path), FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
		if fa != null:
			fa.store_var(out)
			fa.close()
	m.unlock()


## A surface's positions, normals and tangents at the weights `w` (the blend shapes' deltas added, the normals made unit again).
static func _mix(e: Dictionary, s: int, w: PackedFloat32Array) -> Array:
	var base: Array = (e.surfs[s] as Dictionary).arrays
	var v: PackedVector3Array = (base[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
	var n: PackedVector3Array = (base[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate() if base[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var t: PackedFloat32Array = (base[Mesh.ARRAY_TANGENT] as PackedFloat32Array).duplicate() if base[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
	var sp: Array = (e.sparse as Array)[s] if s < (e.sparse as Array).size() else []
	var touched := PackedByteArray()
	touched.resize(v.size())
	for si in mini(sp.size(), w.size()):
		var ww := w[si]
		if ww == 0.0:
			continue
		var sh: Array = sp[si]
		var idx: PackedInt32Array = sh[0]
		var dv: PackedVector3Array = sh[1]
		var dn: PackedVector3Array = sh[2]
		var dt: PackedFloat32Array = sh[3]
		var hn := dn.size() == idx.size() and not n.is_empty()
		var ht := dt.size() == idx.size() * 3 and not t.is_empty()
		for k in idx.size():
			var i := idx[k]
			v[i] += dv[k] * ww
			if hn:
				n[i] += dn[k] * ww
			if ht:
				t[i * 4] += dt[k * 3] * ww
				t[i * 4 + 1] += dt[k * 3 + 1] * ww
				t[i * 4 + 2] += dt[k * 3 + 2] * ww
			touched[i] = 1
	for i in v.size():
		if touched[i] == 0:
			continue
		if not n.is_empty():
			n[i] = n[i].normalized()
		if not t.is_empty():
			var tv := Vector3(t[i * 4], t[i * 4 + 1], t[i * 4 + 2]).normalized()
			t[i * 4] = tv.x
			t[i * 4 + 1] = tv.y
			t[i * 4 + 2] = tv.z
	return [v, n, t]


## The heavy part (a WorkerThreadPool task, or inline for shape()): the bake read from disk, or each mesh mixed (open and shut), the
## fields' context measured on the head, every mesh baked (and written to disk). Only the job's data is touched.
static func _compute(job: Dictionary) -> void:
	var path := CACHE_DIR.path_join("%s.bin" % String(job.key))
	if disk_cache and FileAccess.file_exists(path):
		var fa := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
		if fa != null:
			var d: Variant = fa.get_var()
			fa.close()
			if d is Dictionary and int((d as Dictionary).get("v", 0)) == BAKE_VERSION and ((d as Dictionary).get("items", []) as Array).size() == (job.items as Array).size():
				job["ctx"] = d.ctx
				var outs := []
				for k in (job.items as Array).size():
					outs.append(_expand(job.items[k], d.items[k]))
				job["out"] = outs
				job["from_disk"] = true
				return
	var lc: Dictionary = (job.cfg as Dictionary).get("lids", {})
	var mixes := []
	for it: Dictionary in job.items:
		var e: Dictionary = it.e
		_sparse(e)
		var names: PackedStringArray = e.names
		var w0: PackedFloat32Array = it.w
		var bi := names.find("blink")
		var per := []
		for s in (e.surfs as Array).size():
			var m0 := _mix(e, s, w0)
			var m1: Array = []
			if bi >= 0:
				# shut: the lids' own face shapes left out (the blink's lids meet as on the neutral face), and further along the blink
				# than the game's (it leaves a slit at 1: a sleeping child's lids meet)
				var w1 := w0.duplicate()
				w1[bi] = 1.0
				for nm: Variant in (lc.get("shut_neutral", []) as Array):
					var si := names.find(String(nm))
					if si >= 0:
						w1[si] = 0.0
				m1 = _mix(e, s, w1)
				var gain := float(lc.get("shut_gain", 1.0))
				var v0: PackedVector3Array = m0[0]
				var v1: PackedVector3Array = m1[0]
				if gain != 1.0:
					for i in v1.size():
						if v1[i] != v0[i]:
							v1[i] = v0[i] + (v1[i] - v0[i]) * gain
					m1[0] = v1
			per.append([m0, m1])
		mixes.append(per)
	var ctx := _context(job, mixes)
	var outs := []
	var packs := []
	for k in (job.items as Array).size():
		var pk := _bake_item(job.items[k], mixes[k], ctx)
		packs.append(pk)
		outs.append(_expand(job.items[k], pk))
	job["ctx"] = ctx
	job["out"] = outs
	if disk_cache:
		DirAccess.make_dir_recursive_absolute(CACHE_DIR)
		var fa := FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
		if fa != null:
			fa.store_var({"v": BAKE_VERSION, "ctx": ctx, "items": packs})
			fa.close()
		_prune_disk()


## The disk cache kept to DISK_MAX bakes (the oldest removed).
static func _prune_disk() -> void:
	var files := []
	for fn in DirAccess.get_files_at(CACHE_DIR):
		if fn.ends_with(".bin") and not fn.begins_with("src_"):
			files.append([FileAccess.get_modified_time(CACHE_DIR.path_join(fn)), fn])
	if files.size() <= DISK_MAX:
		return
	files.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	for i in files.size() - DISK_MAX:
		DirAccess.remove_absolute(CACHE_DIR.path_join(String(files[i][1])))


## One mesh's surfaces baked: [shape names, per surface {v, n, t, shapes: [[idx, v, n, t] per made shape, sparse from v]}].
static func _bake_item(it: Dictionary, mixes: Array, ctx: Dictionary) -> Dictionary:
	var e: Dictionary = it.e
	var is_body := false
	for sd: Dictionary in e.surfs:
		if String(sd.mname) == "skin":
			is_body = true
	var shapes := []
	if (e.names as PackedStringArray).has("blink"):
		shapes.append("blink")
	if is_body:
		shapes.append("mouth_open")
	shapes.append("breath")
	var surfs := []
	for s in (e.surfs as Array).size():
		surfs.append(_bake_surface(it, s, mixes[s][0], mixes[s][1], ctx, shapes, is_body))
	return {"shapes": shapes, "surfs": surfs}


static func _bake_surface(it: Dictionary, s: int, m0: Array, m1: Array, ctx: Dictionary, shapes: Array, is_body: bool) -> Dictionary:
	var sd: Dictionary = (it.e.surfs as Array)[s]
	var base: Array = sd.arrays
	var surf := String(sd.mname)
	var bbones: PackedInt32Array = it.bb
	var head: PackedFloat32Array = ctx.head
	var trunk: PackedFloat32Array = ctx.trunk
	var A: Array = ctx.A
	var C: PackedVector3Array = ctx.C
	var v: PackedVector3Array = m0[0]
	var nrm: PackedVector3Array = m0[1]
	var tan: PackedFloat32Array = m0[2]
	var bo: PackedInt32Array = base[Mesh.ARRAY_BONES] if base[Mesh.ARRAY_BONES] != null else PackedInt32Array()
	var w: PackedFloat32Array = base[Mesh.ARRAY_WEIGHTS] if base[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
	var nv := v.size()
	var nb := bo.size() / maxi(nv, 1)
	var has1 := not m1.is_empty()
	var v1: PackedVector3Array = m1[0] if has1 else PackedVector3Array()
	var n1: PackedVector3Array = m1[1] if has1 else PackedVector3Array()
	var t1: PackedFloat32Array = m1[2] if has1 else PackedFloat32Array()
	var ov := PackedVector3Array()
	var on := PackedVector3Array()
	var ot := PackedFloat32Array()
	ov.resize(nv)
	on.resize(nrm.size())
	ot.resize(tan.size())
	var bv := PackedVector3Array()
	var bn := PackedVector3Array()
	var bt := PackedFloat32Array()
	if has1:
		bv = v.duplicate()
		bn = nrm.duplicate()
		bt = tan.duplicate()
	var eye := surf == "eye"
	var hw_arr := PackedFloat32Array()
	var tw_arr := PackedFloat32Array()
	var aw_arr: Array = []
	var cw_arr := PackedVector3Array()
	cw_arr.resize(nv)
	hw_arr.resize(nv)
	tw_arr.resize(nv)
	aw_arr.resize(nv)
	for i in nv:
		var aw := Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
		var cw := Vector3.ZERO
		var hw := 0.0
		var tw := 0.0
		var ws := 0.0
		for k in nb:
			var ww := w[i * nb + k]
			if ww <= 0.0:
				continue
			var bone := bbones[bo[i * nb + k]] if not bbones.is_empty() else 0
			var ab: Basis = A[bone]
			aw = Basis(aw.x + ab.x * ww, aw.y + ab.y * ww, aw.z + ab.z * ww)
			cw += C[bone] * ww
			hw += ww * head[bone]
			tw += ww * trunk[bone]
			ws += ww
		if ws <= 0.0:
			aw = Basis()
		elif absf(ws - 1.0) > 0.001:
			aw = Basis(aw.x / ws, aw.y / ws, aw.z / ws)
			cw /= ws
			hw /= ws
			tw /= ws
		if eye:
			hw = 1.0
		hw_arr[i] = hw
		tw_arr[i] = tw
		aw_arr[i] = aw
		cw_arr[i] = cw
		var res := _map(v[i], aw, cw, hw, tw, ctx, eye)
		ov[i] = res[0]
		var J: Basis = res[1]
		var jit := J.inverse().transposed()
		if not nrm.is_empty():
			on[i] = (jit * nrm[i]).normalized()
		if not tan.is_empty():
			var tv := (J * Vector3(tan[i * 4], tan[i * 4 + 1], tan[i * 4 + 2])).normalized()
			ot[i * 4] = tv.x
			ot[i * 4 + 1] = tv.y
			ot[i * 4 + 2] = tv.z
			ot[i * 4 + 3] = tan[i * 4 + 3]
		if has1:
			if v1[i] != v[i] or (not n1.is_empty() and n1[i] != nrm[i]):
				var r1 := _map(v1[i], aw, cw, hw, tw, ctx, eye)
				bv[i] = r1[0]
				var j1: Basis = r1[1]
				if not n1.is_empty():
					bn[i] = (j1.inverse().transposed() * n1[i]).normalized()
				if not t1.is_empty():
					var tv1 := (j1 * Vector3(t1[i * 4], t1[i * 4 + 1], t1[i * 4 + 2])).normalized()
					bt[i * 4] = tv1.x
					bt[i * 4 + 1] = tv1.y
					bt[i * 4 + 2] = tv1.z
					bt[i * 4 + 3] = t1[i * 4 + 3]
			else:
				bv[i] = ov[i]
				if not n1.is_empty():
					bn[i] = on[i]
				if not t1.is_empty():
					for q in 4:
						bt[i * 4 + q] = ot[i * 4 + q]
	# the trunk's skin a few millimetres in under the clothes (the flattened chest never pokes through a thin gown)
	if surf == "skin":
		var inset := float((ctx.tc as Dictionary).get("skin_inset", 0.004))
		var iy: Array = (ctx.tc as Dictionary).get("y", [0.8, 1.25])
		for i in nv:
			if tw_arr[i] > 0.3 and v[i].y > float(iy[0]) and v[i].y < float(iy[1]) + 0.03 and not on.is_empty():
				ov[i] -= on[i] * inset * tw_arr[i] * (aw_arr[i] as Basis).get_scale().x
				if has1:
					bv[i] = ov[i]
	# the made shapes: the jaw dropped (the head's skin) and the breath (the trunk and what lies on it), sparse from the baked mesh
	var out_shapes := []
	for nm: String in shapes:
		var idx := PackedInt32Array()
		var sv := PackedVector3Array()
		var sn := PackedVector3Array()
		var st := PackedFloat32Array()
		match nm:
			"blink":
				for i in nv:
					if bv[i] != ov[i] or (not bn.is_empty() and bn[i] != on[i]):
						idx.append(i)
						sv.append(bv[i])
						if not bn.is_empty():
							sn.append(bn[i])
						if not bt.is_empty():
							for q in 4:
								st.append(bt[i * 4 + q])
			"mouth_open":
				if surf == "skin":
					var mc: Dictionary = ctx.mouth
					for i in nv:
						if hw_arr[i] > 0.05:
							var q := _mouth(v[i], hw_arr[i], mc, nrm[i] if not nrm.is_empty() else Vector3.UP)
							if q != v[i]:
								idx.append(i)
								sv.append(_map(q, aw_arr[i], cw_arr[i], hw_arr[i], tw_arr[i], ctx, eye)[0])
			_:
				var bc: Dictionary = ctx.breath
				var bamt := float(bc.get("m", 0.012))
				var byr: Array = bc.get("y", [0.9, 1.28])
				for i in nv:
					if tw_arr[i] > 0.05 and v[i].y > float(byr[0]) and v[i].y < float(byr[1]):
						var hd := Vector3(v[i].x, 0.0, v[i].z).normalized()
						var band := smoothstep(float(byr[0]), float(byr[0]) + 0.08, v[i].y) * (1.0 - smoothstep(float(byr[1]) - 0.08, float(byr[1]), v[i].y))
						var fr := 0.4 + 0.6 * maxf(hd.z, 0.0)
						idx.append(i)
						sv.append(ov[i] + (aw_arr[i] as Basis) * (hd * bamt * band * fr * tw_arr[i]))
		out_shapes.append([idx, sv, sn, st])
	return {"v": ov, "n": on, "t": ot, "shapes": out_shapes}


## The arrays of one mesh for ArrayMesh.add_surface_from_arrays (worker): the source's arrays with the baked positions, normals and
## tangents, the adult position in CUSTOM1 on the skin (ChildSkin's shader), and the made blend shapes (whole, from the sparse ones).
static func _expand(it: Dictionary, pk: Dictionary) -> Dictionary:
	var e: Dictionary = it.e
	var surfs := []
	for s in (e.surfs as Array).size():
		var sd: Dictionary = (e.surfs as Array)[s]
		var bk: Dictionary = (pk.surfs as Array)[s]
		var arr: Array = (sd.arrays as Array).duplicate()
		var ov: PackedVector3Array = bk.v
		var on: PackedVector3Array = bk.n
		var ot: PackedFloat32Array = bk.t
		var flags_extra := 0
		if String(sd.mname) == "skin" and arr[Mesh.ARRAY_CUSTOM1] == null:
			var src_v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ap := PackedFloat32Array()
			ap.resize(src_v.size() * 3)
			for i in src_v.size():
				ap[i * 3] = src_v[i].x
				ap[i * 3 + 1] = src_v[i].y
				ap[i * 3 + 2] = src_v[i].z
			arr[Mesh.ARRAY_CUSTOM1] = ap
			flags_extra = Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT
		arr[Mesh.ARRAY_VERTEX] = ov
		if not on.is_empty():
			arr[Mesh.ARRAY_NORMAL] = on
		if not ot.is_empty():
			arr[Mesh.ARRAY_TANGENT] = ot
		var bsa := []
		for sh: Array in bk.shapes:
			var idx: PackedInt32Array = sh[0]
			var sv: PackedVector3Array = sh[1]
			var sn: PackedVector3Array = sh[2]
			var st: PackedFloat32Array = sh[3]
			var vv := ov.duplicate()
			var nn := on.duplicate()
			var tt := ot.duplicate()
			for k in idx.size():
				var i := idx[k]
				vv[i] = sv[k]
				if sn.size() == idx.size() and not nn.is_empty():
					nn[i] = sn[k]
				if st.size() == idx.size() * 4 and not tt.is_empty():
					for q in 4:
						tt[i * 4 + q] = st[k * 4 + q]
			var sa := []
			sa.resize(Mesh.ARRAY_MAX)
			sa[Mesh.ARRAY_VERTEX] = vv
			if not nn.is_empty():
				sa[Mesh.ARRAY_NORMAL] = nn
			if not tt.is_empty():
				sa[Mesh.ARRAY_TANGENT] = tt
			bsa.append(sa)
		var fmt := int(sd.fmt)
		var flags := (fmt & ~((1 << Mesh.ARRAY_FORMAT_CUSTOM_BASE) - 1) & ((1 << 35) - 1)) | flags_extra
		surfs.append({"arr": arr, "bsa": bsa, "flags": flags})
	return {"shapes": pk.shapes, "surfs": surfs}


## Main thread: the next mesh put on (made from the worker's arrays, or the bake in memory), with its own skin at the new binds.
static func _apply_item(job: Dictionary) -> void:
	var k := int(job.i)
	job.i = k + 1
	var it: Dictionary = (job.items as Array)[k]
	var mi: MeshInstance3D = it.mi
	if not is_instance_valid(mi):
		return
	var mesh: ArrayMesh
	if job.has("hit"):
		mesh = ((job.hit as Dictionary).meshes as Array)[k]
	else:
		var o: Dictionary = (job.out as Array)[k]
		var e: Dictionary = it.e
		mesh = ArrayMesh.new()
		mesh.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
		for nm: String in o.shapes:
			mesh.add_blend_shape(nm)
		for s in (o.surfs as Array).size():
			var so: Dictionary = (o.surfs as Array)[s]
			var sd: Dictionary = (e.surfs as Array)[s]
			mesh.add_surface_from_arrays(int(sd.prim), so.arr, so.bsa, {}, int(so.flags))
			mesh.surface_set_material(s, sd.mat)
			mesh.surface_set_name(s, String(sd.sname))
		if not job.has("meshes"):
			job["meshes"] = []
		(job.meshes as Array).append(mesh)
		(o as Dictionary).clear()           # (the arrays are in the mesh now)
	mi.mesh = mesh
	for i in mesh.get_blend_shape_count():     # (a new mesh keeps the old one's weights by index)
		mi.set_blend_shape_value(i, 0.0)
	var src_skin: Skin = it.skin
	if src_skin != null:
		if not job.has("skins"):
			job["skins"] = {}
		var p: ChildProportion = job.p
		if not (job.skins as Dictionary).has(src_skin):
			var ns := Skin.new()
			for q in src_skin.get_bind_count():
				var bone := src_skin.get_bind_bone(q)
				ns.add_bind(bone, (p._g[bone] as Transform3D).affine_inverse())
			job.skins[src_skin] = ns
		mi.skin = job.skins[src_skin]


## Main thread: the bake finished: the body's binds, drivers and skirt hems at the new joints, the fields' context kept (map_face), the
## bake kept in memory, `done` called.
static func _finish(job: Dictionary) -> void:
	var p: ChildProportion = job.p
	var b: CharacterBodyMesh = job.b
	var sk := b.skeleton
	var sol: Dictionary = job.sol
	var ctx: Dictionary = (job.hit as Dictionary).ctx if job.has("hit") else job.ctx
	p._ctx = ctx
	p.lip_y = float((ctx.mouth as Dictionary).get("lip_y", 0.0))
	for bone: int in b._bind.keys():
		b._bind[bone] = p._g[bone]
	b._setup_drivers()
	var hems: Array = b.skirt_hems if b.skirt_hems.size() == 3 else CharacterBodyMesh.SKIRT_HEMS
	var nh := []
	var li := sk.find_bone("l_upper_leg")
	for k in 3:
		var h: Vector3 = hems[k]
		nh.append(sol.n[li] + (sol.A[li] as Basis) * (h - (b._bind_g[li] as Transform3D).origin))
	b.set_skirt_hems(nh)
	b.soft_tissue = 0.0
	b.genital_swing = 0.0
	p._pending = false
	p.set_meta("bake_ms", (Time.get_ticks_usec() - int(job.t0)) / 1000)
	p.set_meta("bake_from", "memory" if job.has("hit") else ("disk" if job.has("from_disk") else "baked"))
	if not job.has("hit") and job.has("meshes"):
		_mem_n += 1
		_mem[job.key] = {"meshes": job.meshes, "ctx": ctx, "t": _mem_n}
		while _mem.size() > MEM_MAX:
			var old := ""
			var ot := 1 << 62
			for k: String in _mem:
				if int((_mem[k] as Dictionary).t) < ot:
					ot = int((_mem[k] as Dictionary).t)
					old = k
			_mem.erase(old)
	for fb in sk.get_parent().find_children("*", "FaceBlink", true, false) if sk.get_parent() != null else []:
		(fb as FaceBlink)._mesh_count = -1
	var done: Callable = job.get("done", Callable())
	if done.is_valid():
		done.call(p)


## The joints only (no meshes): the new binds and the run-time offsets for `f` on `sk` whose bind globals are `g` (tools: the baby's
## animations are keyed on a bare skeleton). Returns the solution (_solve).
func rig(sk: Skeleton3D, g: Array, f: Dictionary) -> Dictionary:
	form = f.duplicate(true)
	var sol := _solve(sk, g, f)
	_a = sol.A
	_o = sol.o
	_g = []
	for i in sk.get_bone_count():
		var g0: Transform3D = g[i]
		_g.append(Transform3D(g0.basis.orthonormalized(), sol.n[i]))
	# each hierarchy bone's local offset scaled by its parent's scale (in the parent's bind frame)
	_off.clear()
	for i: int in sol.hier:
		var par := sk.get_bone_parent(i)
		if par < 0:
			continue
		var rp := (g[par] as Transform3D).basis.orthonormalized()
		var k := rp.transposed() * (sol.A[par] as Basis) * rp
		if not k.is_equal_approx(Basis()):
			_off[i] = k
	_root = sk.find_bone("root")
	_root_bind = (g[_root] as Transform3D).origin
	_root_new = sol.n[_root]
	_root_f = float(sol.leg)
	return sol


## The new joints: {A: per-bone scale (Basis, skeleton space), n: per-bone new bind origin, hier: the skeleton's bones from the root
## (parents first), leg: the legs' length share}.
static func _solve(sk: Skeleton3D, g: Array, f: Dictionary) -> Dictionary:
	var n := sk.get_bone_count()
	var group_of := {}
	for gname: String in GROUPS:
		if f.has(gname):
			for bn: String in GROUPS[gname]:
				group_of[bn] = gname
	var o := PackedVector3Array()
	for i in n:
		o.append((g[i] as Transform3D).origin)
	var A: Array = []
	A.resize(n)
	var no := PackedVector3Array()
	no.resize(n)
	var hier: Array = []
	var inh := {}
	var root := sk.find_bone("root")
	var stack := [root]
	while not stack.is_empty():
		var i: int = stack.pop_front()
		hier.append(i)
		inh[i] = true
		var par := sk.get_bone_parent(i)
		var name := sk.get_bone_name(i)
		var a := Basis()
		if group_of.has(name):
			a = _group_basis(sk, o, name, f[group_of[name]])
		elif par >= 0 and A[par] != null:
			a = A[par]
		A[i] = a
		no[i] = o[i] if par < 0 else no[par] + (A[par] as Basis) * (o[i] - o[par])
		for c in sk.get_bone_children(i):
			stack.append(c)
	# the soles on the floor
	var low := INF
	for fb in ["l_heel", "r_heel"]:
		var fi := sk.find_bone(fb)
		if fi >= 0:
			low = minf(low, no[fi].y - o[fi].y)
	if low != INF:
		for i: int in hier:
			no[i].y -= low
	# the parts off the hierarchy (the twist and skirt helpers, the queue): with their owner
	for i in n:
		if inh.has(i):
			continue
		var ow := _owner(sk, i, o, inh)
		A[i] = A[ow]
		no[i] = no[ow] + (A[ow] as Basis) * (o[i] - o[ow])
	var hip := sk.find_bone("l_upper_leg")
	var heel := sk.find_bone("l_heel")
	var leg := (no[hip].y - no[heel].y) / maxf(o[hip].y - o[heel].y, 0.01) if hip >= 0 and heel >= 0 else 1.0
	return {"A": A, "n": no, "hier": hier, "leg": leg, "o": o}


static func _group_basis(sk: Skeleton3D, o: PackedVector3Array, name: String, v: Variant) -> Basis:
	if v is float or v is int:
		return Basis.from_scale(Vector3.ONE * float(v))
	var arr: Array = v
	if arr.size() >= 3:
		return Basis.from_scale(Vector3(float(arr[0]), float(arr[1]), float(arr[2])))
	var t := float(arr[0])
	var l := float(arr[1]) if arr.size() > 1 else t
	var key := name if name.begins_with("l_") else "l_" + name.substr(2)
	var ax: Variant = AXIS.get(key)
	var side := name.substr(0, 2)
	var d := Vector3.UP
	if ax is String:
		var ci := sk.find_bone(side + String(ax).substr(2))
		if ci >= 0:
			d = o[ci] - o[sk.find_bone(name)]
	elif ax is Array:
		var a0 := sk.find_bone(side + String(ax[0]).substr(2))
		var a1 := sk.find_bone(side + String(ax[1]).substr(2))
		if a0 >= 0 and a1 >= 0:
			d = o[a1] - o[a0]
	d = d.normalized()
	var k := l - t
	return Basis(Vector3(t, 0, 0) + d * (k * d.x), Vector3(0, t, 0) + d * (k * d.y), Vector3(0, 0, t) + d * (k * d.z))


## The hierarchy bone a helper moves with: by name (the arm's twist bones, the thigh's helpers, the queue), else the nearest.
static func _owner(sk: Skeleton3D, i: int, o: PackedVector3Array, inh: Dictionary) -> int:
	var nm := sk.get_bone_name(i)
	var side := nm.substr(0, 2) if nm.begins_with("l_") or nm.begins_with("r_") else ""
	var want := ""
	if nm.contains("shoulder_twist") or nm.contains("shoulder_helper") or nm.contains("shoulder_grp") or nm.contains("shoulder_a_offset") \
			or nm.contains("shoulder_b_offset") or nm.contains("shoulder_c_offset") or nm.contains("shoulder_d_offset"):
		want = side + "shoulder"
	elif nm.contains("forarm") or nm.contains("elbow_helper"):
		want = side + "elbow"
	elif nm.contains("wrist"):
		want = side + "wrist"
	elif nm.contains("upper_leg"):
		want = side + "upper_leg"
	elif nm.contains("knee"):
		want = side + "knee"
	elif nm == CharacterBodyMesh.QUEUE_HELPER:
		want = "headb"
	elif nm.begins_with("pelvis"):
		want = "pelvis"
	var w := sk.find_bone(want) if want != "" else -1
	if w >= 0 and inh.has(w):
		return w
	var best := sk.find_bone("root")
	var bd := INF
	for j: int in inh:
		var d := o[j].distance_squared_to(o[i])
		if d < bd:
			bd = d
			best = j
	return best


## What every mesh's bake needs (worker): the bones' scalings, the head and trunk bones, the fields' settings, and measured on the head's
## own mixed surfaces the eyeballs' centres, the trunk's section table, the head's radii and the lips' line.
static func _context(job: Dictionary, mixes: Array) -> Dictionary:
	var c: Dictionary = job.cfg
	var sol: Dictionary = job.sol
	var f: Dictionary = job.form
	var A: Array = sol.A
	var n := A.size()
	var C := PackedVector3Array()
	C.resize(n)
	for i in n:
		C[i] = sol.n[i] - (A[i] as Basis) * sol.o[i]
	var head: PackedFloat32Array = job.head
	var trunk: PackedFloat32Array = job.trunk
	var rc: Dictionary = c.get("round", {})
	var ec: Dictionary = c.get("eyes", {})
	var tc: Dictionary = (c.get("trunk", {}) as Dictionary).duplicate()
	var tf: Dictionary = f.get("trunk", {})
	for k in tf:
		tc[k] = tf[k]
	var ctx := {"A": A, "C": C, "head": head, "trunk": trunk, "round_k": clampf(float(job.round_k), -0.4, 1.0), "rc": rc,
			"eye_k": float(f.get("eyes", 1.0)), "ec": ec, "tc": tc, "eye_c": [], "table": {},
			"face_k": float(f.get("face", 0.0)), "face_fields": _face_fields(c.get("face", {})),
			"lower": (c.get("face", {}) as Dictionary).get("lower_face", {}), "lids": c.get("lids", {}),
			"breath": c.get("breath", {}), "mouth": c.get("mouth", {})}
	# the eyeballs' centres (after the face shapes: the child's own eyes) and the trunk's sections, from the body part
	for k in (job.items as Array).size():
		var it: Dictionary = job.items[k]
		if not bool(it.head):
			continue
		var e: Dictionary = it.e
		for s in (e.surfs as Array).size():
			var sd: Dictionary = (e.surfs as Array)[s]
			var mv: PackedVector3Array = ((mixes[k] as Array)[s] as Array)[0][0]
			if String(sd.mname) == "eye":
				ctx.eye_c = _eye_centres(mv)
			elif String(sd.mname) == "skin":
				var sa: Array = (sd.arrays as Array).duplicate()
				sa[Mesh.ARRAY_VERTEX] = mv
				ctx.table = _trunk_table(sa, it.bb, trunk, tc)
				ctx.rc = (ctx.rc as Dictionary).duplicate()
				ctx.rc["table"] = _head_table(sa, it.bb, head, ctx.rc)
				var ly := _lip_y(sa)
				if ly > 0.0:
					ctx.mouth = (ctx.mouth as Dictionary).duplicate()
					ctx.mouth["lip_y"] = ly
	if (ctx.eye_c as Array).is_empty():
		var e0: Array = ec.get("centre", [0.0311, 1.4836, 0.1002])
		ctx.eye_c = [Vector3(float(e0[0]), float(e0[1]), float(e0[2])), Vector3(-float(e0[0]), float(e0[1]), float(e0[2]))]
	return ctx


## The lips' middle height (the mucosa, COLOR.g, near the midline in front), 0 when none.
static func _lip_y(arr: Array) -> float:
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var col: Variant = arr[Mesh.ARRAY_COLOR]
	if not col is PackedColorArray:
		return 0.0
	var lo := INF
	var hi := -INF
	for i in v.size():
		if (col as PackedColorArray)[i].g > 0.5 and absf(v[i].x) < 0.012 and v[i].z > 0.09 and v[i].y > 1.3:
			lo = minf(lo, v[i].y)
			hi = maxf(hi, v[i].y)
	return (lo + hi) * 0.5 if lo < INF else 0.0


## The two eyeballs' centres from the eye surface's vertices (each a spherical cap: the middle of its extent across and up, its radius
## back from the front).
static func _eye_centres(v: PackedVector3Array) -> Array:
	var out := []
	for sg: float in [1.0, -1.0]:
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		for p in v:
			if p.x * sg > 0.0:
				lo = lo.min(p)
				hi = hi.max(p)
		if lo.x == INF:
			continue
		var r := (hi.x - lo.x) * 0.5
		out.append(Vector3((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, hi.z - r))
	return out


# ---------------------------------------------------------------------------------------------------- the head's radii
const H_AZ := 24
const H_EL := 12


## The head's own radius from the cranium's centre by direction (H_AZ azimuth bins round from the front, H_EL elevation bins from below):
## the median distance of the head's skin in each (the ears left out), empty bins from their neighbours; and the radius of the sphere
## of the same volume ("rs").
static func _head_table(arr: Array, bb: PackedInt32Array, head: PackedFloat32Array, rc: Dictionary) -> Dictionary:
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bo: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var nb := bo.size() / maxi(v.size(), 1)
	var ca: Array = rc.get("centre", [0.0, 1.5, 0.025])
	var c := Vector3(float(ca[0]), float(ca[1]), float(ca[2]))
	var bins: Array = []
	bins.resize(H_AZ * H_EL)
	for i in bins.size():
		bins[i] = PackedFloat32Array()
	for i in v.size():
		var p := v[i]
		var hw := 0.0
		for k in nb:
			hw += w[i * nb + k] * head[bb[bo[i * nb + k]]]
		if hw < 0.9 or p.y < 1.37:
			continue
		if absf(p.x) > 0.064 and p.y > 1.42 and p.y < 1.52 and p.z > -0.035 and p.z < 0.045:
			continue                     # an ear
		var d := p - c
		var bi := _hbin(d)
		var bin: PackedFloat32Array = bins[bi]
		bin.append(d.length())
		bins[bi] = bin
	var rad := PackedFloat32Array()
	rad.resize(H_AZ * H_EL)
	for i in bins.size():
		var b: PackedFloat32Array = bins[i]
		if b.size() < 3:
			rad[i] = NAN
			continue
		b.sort()
		rad[i] = b[b.size() / 2]
	for e in H_EL:
		var row := PackedFloat32Array()
		for a in H_AZ:
			row.append(rad[e * H_AZ + a])
		_fill(row, true)
		for a in H_AZ:
			rad[e * H_AZ + a] = row[a]
	for a in H_AZ:
		var col := PackedFloat32Array()
		for e in H_EL:
			col.append(rad[e * H_AZ + a])
		_fill(col)
		for e in H_EL:
			rad[e * H_AZ + a] = col[e]
	for pass_i in 2:
		var src := rad.duplicate()
		for e in H_EL:
			for a in H_AZ:
				var acc := src[e * H_AZ + a] * 2.0
				var wsum := 2.0
				for dd: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var e2 := e + dd.y
					if e2 < 0 or e2 >= H_EL:
						continue
					acc += src[e2 * H_AZ + posmod(a + dd.x, H_AZ)]
					wsum += 1.0
				rad[e * H_AZ + a] = acc / wsum
	var s3 := 0.0
	var ws := 0.0
	for e in H_EL:
		var el := (float(e) + 0.5) / H_EL * PI - PI * 0.5
		for a in H_AZ:
			var r := rad[e * H_AZ + a]
			s3 += r * r * r * cos(el)
			ws += cos(el)
	# a smooth fit of it (polynomials of the direction up to the 4th degree, least squares over the bins): no creases between bins
	var rows: Array = []
	var vals := PackedFloat32Array()
	var wts := PackedFloat32Array()
	for e in H_EL:
		var el := (float(e) + 0.5) / H_EL * PI - PI * 0.5
		for a in H_AZ:
			var az := (float(a) + 0.5) / H_AZ * TAU
			var u := Vector3(sin(az) * cos(el), sin(el), cos(az) * cos(el))
			rows.append(_poly(u))
			vals.append(rad[e * H_AZ + a])
			wts.append(cos(el))
	return {"rad": rad, "rs": pow(s3 / maxf(ws, 1e-6), 1.0 / 3.0), "c": c, "fit": _lsq(rows, vals, wts, 1e-5)}


## The monomials x^a y^b z^c (a + b + c <= 4) of a direction.
static func _poly(u: Vector3) -> PackedFloat32Array:
	var xp := [1.0, u.x, u.x * u.x, u.x * u.x * u.x, u.x * u.x * u.x * u.x]
	var yp := [1.0, u.y, u.y * u.y, u.y * u.y * u.y, u.y * u.y * u.y * u.y]
	var zp := [1.0, u.z, u.z * u.z, u.z * u.z * u.z, u.z * u.z * u.z * u.z]
	var out := PackedFloat32Array()
	out.resize(35)
	var i := 0
	for a in 5:
		for b in 5 - a:
			var xy: float = xp[a] * yp[b]
			for cc in 5 - a - b:
				out[i] = xy * zp[cc]
				i += 1
	return out


## Weighted ridge least squares: the coefficients c minimising sum w (row . c - val)^2 + lam |c|^2.
static func _lsq(rows: Array, vals: PackedFloat32Array, wts: PackedFloat32Array, lam: float) -> PackedFloat32Array:
	var n: int = (rows[0] as PackedFloat32Array).size()
	var m: Array = []
	for i in n:
		var r := PackedFloat64Array()
		r.resize(n + 1)
		m.append(r)
	for k in rows.size():
		var row: PackedFloat32Array = rows[k]
		var w := float(wts[k])
		for i in n:
			var ri: PackedFloat64Array = m[i]
			var wi := w * row[i]
			for j in n:
				ri[j] += wi * row[j]
			ri[n] += wi * vals[k]
			m[i] = ri
	for i in n:
		var ri: PackedFloat64Array = m[i]
		ri[i] += lam
		m[i] = ri
	# Gauss-Jordan with partial pivoting
	for col in n:
		var piv := col
		for r in range(col + 1, n):
			if absf((m[r] as PackedFloat64Array)[col]) > absf((m[piv] as PackedFloat64Array)[col]):
				piv = r
		var tmp: PackedFloat64Array = m[col]
		m[col] = m[piv]
		m[piv] = tmp
		var pr: PackedFloat64Array = m[col]
		var d := pr[col]
		if absf(d) < 1e-12:
			continue
		for j in n + 1:
			pr[j] /= d
		m[col] = pr
		for r in n:
			if r == col:
				continue
			var rr: PackedFloat64Array = m[r]
			var f := rr[col]
			if f == 0.0:
				continue
			for j in n + 1:
				rr[j] -= f * pr[j]
			m[r] = rr
	var out := PackedFloat32Array()
	for i in n:
		out.append((m[i] as PackedFloat64Array)[n])
	return out


static func _hbin(d: Vector3) -> int:
	var a := int(posmod(atan2(d.x, d.z) / TAU * H_AZ, float(H_AZ))) % H_AZ
	var e := clampi(int((asin(clampf(d.y / maxf(d.length(), 1e-6), -1.0, 1.0)) + PI * 0.5) / PI * H_EL), 0, H_EL - 1)
	return e * H_AZ + a


## The head's own radius toward `u` (a unit direction), bilinear over the table.
static func _hrad(t: Dictionary, u: Vector3) -> float:
	if t.has("fit"):
		var cf: PackedFloat32Array = t.fit
		var pv := _poly(u)
		var r := 0.0
		for i in cf.size():
			r += cf[i] * pv[i]
		return r
	var rad: PackedFloat32Array = t.rad
	var fa := posmod(atan2(u.x, u.z) / TAU * H_AZ - 0.5, float(H_AZ))
	var fe := clampf((asin(clampf(u.y, -1.0, 1.0)) + PI * 0.5) / PI * H_EL - 0.5, 0.0, float(H_EL) - 1.001)
	var a0 := int(fa)
	var at := fa - float(a0)
	var a1 := (a0 + 1) % H_AZ
	var e0 := int(fe)
	var et := fe - float(e0)
	var e1 := mini(e0 + 1, H_EL - 1)
	return lerpf(lerpf(rad[e0 * H_AZ + a0], rad[e0 * H_AZ + a1], at), lerpf(rad[e1 * H_AZ + a0], rad[e1 * H_AZ + a1], at), et)


# ---------------------------------------------------------------------------------------------------- the trunk's sections
const T_ANG := 24


## The body's own section radius of the trunk by height (1 cm bins) and angle (T_ANG bins, 0 = front, toward the left side first),
## and the smooth barrel it is pulled to: the section's centre, the side half-width smoothed along the height (no waist or hip curve),
## the depth from it (`depth` of the width), the belly's bulge in front.
static func _trunk_table(arr: Array, bb: PackedInt32Array, trunk: PackedFloat32Array, tc: Dictionary) -> Dictionary:
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bo: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var nb := bo.size() / maxi(v.size(), 1)
	var yr: Array = tc.get("y", [0.8, 1.26])
	var y0 := float(yr[0]) - 0.04
	var y1 := float(yr[1]) + 0.04
	var ny := int(ceil((y1 - y0) / 0.01)) + 1
	var zlo := PackedFloat32Array()
	var zhi := PackedFloat32Array()
	zlo.resize(ny)
	zhi.resize(ny)
	zlo.fill(INF)
	zhi.fill(-INF)
	var pts: Array = []
	for i in v.size():
		var p := v[i]
		if p.y < y0 or p.y > y1:
			continue
		var tw := 0.0
		for k in nb:
			tw += w[i * nb + k] * trunk[bb[bo[i * nb + k]]]
		if tw < 0.95:
			continue
		var yi := int((p.y - y0) / 0.01)
		zlo[yi] = minf(zlo[yi], p.z)
		zhi[yi] = maxf(zhi[yi], p.z)
		pts.append(p)
	var zc := PackedFloat32Array()
	zc.resize(ny)
	for yi in ny:
		zc[yi] = (zlo[yi] + zhi[yi]) * 0.5 if zlo[yi] != INF else NAN
	_fill(zc)
	zc = _smooth(zc, 4)
	var rad := PackedFloat32Array()
	rad.resize(ny * T_ANG)
	for p: Vector3 in pts:
		var yi := int((p.y - y0) / 0.01)
		var d := Vector2(p.x, p.z - zc[yi])
		var ai := _ang_bin(d)
		rad[yi * T_ANG + ai] = maxf(rad[yi * T_ANG + ai], d.length())
	# empty bins from their neighbours round the section, then along the height
	for yi in ny:
		var row := PackedFloat32Array()
		for ai in T_ANG:
			row.append(rad[yi * T_ANG + ai] if rad[yi * T_ANG + ai] > 0.0 else NAN)
		_fill(row, true)
		for ai in T_ANG:
			rad[yi * T_ANG + ai] = row[ai]
	for ai in T_ANG:
		var col := PackedFloat32Array()
		for yi in ny:
			col.append(rad[yi * T_ANG + ai])
		_fill(col)
		col = _smooth(col, 1)
		for yi in ny:
			rad[yi * T_ANG + ai] = col[yi]
	# the barrel: the side half-width (the sides' mean), smoothed hard along the height; the depth from it; the belly in front
	var side := PackedFloat32Array()
	side.resize(ny)
	for yi in ny:
		side[yi] = 0.5 * (rad[yi * T_ANG + T_ANG / 4] + rad[yi * T_ANG + 3 * T_ANG / 4])
	side = _smooth(side, int(float(tc.get("smooth_m", 0.1)) / 0.01))
	return {"y0": y0, "ny": ny, "zc": zc, "rad": rad, "side": side}


static func _ang_bin(d: Vector2) -> int:
	var a := atan2(d.x, d.y)                 # 0 at the front (+z), +PI/2 at the left (+x)
	return int(posmod(a / TAU * T_ANG + 0.5, float(T_ANG))) % T_ANG


static func _fill(a: PackedFloat32Array, wrap := false) -> void:
	var n := a.size()
	var any := false
	for x in a:
		if not is_nan(x):
			any = true
	if not any:
		a.fill(0.0)
		return
	var src := a.duplicate()
	for i in n:
		if not is_nan(src[i]):
			continue
		var l := -1
		var r := -1
		for k in range(1, n):
			var il := i - k
			var ir := i + k
			if wrap:
				il = posmod(il, n)
				ir = posmod(ir, n)
			if l < 0 and il >= 0 and il < n and not is_nan(src[il]):
				l = il
			if r < 0 and ir >= 0 and ir < n and not is_nan(src[ir]):
				r = ir
			if l >= 0 and r >= 0:
				break
		a[i] = src[l] if r < 0 else (src[r] if l < 0 else 0.5 * (src[l] + src[r]))


static func _smooth(a: PackedFloat32Array, rad: int) -> PackedFloat32Array:
	if rad <= 0:
		return a
	var out := PackedFloat32Array()
	out.resize(a.size())
	for i in a.size():
		var s := 0.0
		var wsum := 0.0
		for k in range(-rad, rad + 1):
			var j := clampi(i + k, 0, a.size() - 1)
			var ww := 1.0 - absf(float(k)) / float(rad + 1)
			s += a[j] * ww
			wsum += ww
		out[i] = s / wsum
	return out


# ---------------------------------------------------------------------------------------------------- the fields
## The shape fields at `p` (adult bind space): the eyes (hw: the head's weight; eye: an eyeball's vertex), the rounded head, the
## flattened trunk (tw: the trunk's weight).
static func _field(p: Vector3, hw: float, tw: float, ctx: Dictionary, eye := false) -> Vector3:
	if hw > 0.0 or p.y > 1.28:
		var ek: float = ctx.eye_k
		if ek != 1.0:
			var ec: Dictionary = ctx.ec
			var r0 := float(ec.get("r0", 0.016))
			var r1 := float(ec.get("r1", 0.036))
			for c: Vector3 in ctx.eye_c:
				var d := p - c
				var dl := d.length()
				if dl < r1:
					var t := clampf((dl - r0) / (r1 - r0), 0.0, 1.0)
					t = t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
					p = c + d * lerpf(1.0, lerpf(ek, 1.0, t), hw)
		var fk: float = ctx.face_k
		if fk > 0.0 and hw > 0.0 and not eye:
			p = _lids(p, hw * fk, ctx)
		if fk > 0.0 and (hw > 0.0 or p.y > 1.3):
			# (the fields reach into the neck's top as the rounding does: the under-chin's fullness has no fold at the neck)
			var hwn := maxf(hw, smoothstep(1.3, 1.37, p.y))
			for ff: Dictionary in ctx.face_fields:
				p = _feature(p, hwn * fk, ff)
			var lf: Dictionary = ctx.lower
			if not lf.is_empty() and p.y < float(lf.y):
				# the lower face shorter (the chin up toward the eyes' line), the front of the face only
				var lz: Array = lf.z
				var k := fk * hwn * smoothstep(float(lz[0]), float(lz[1]), p.z) * smoothstep(0.0, 0.03, float(lf.y) - p.y)
				p.y = float(lf.y) + (p.y - float(lf.y)) * lerpf(1.0, float(lf.scale), k)
		var rk: float = ctx.round_k
		if rk != 0.0:
			p = _round(p, hw, rk, ctx.rc)
	if tw > 0.0 and not (ctx.table as Dictionary).is_empty():
		p = _barrel(p, tw, ctx)
	return p


## The lids opened wider (baby_body.json "lids": a young face's round, open eyes): the skin, lids and lashes round each eyeball turned
## about the eyeball's centre across the face, the upper lid up by up_deg and the lower down by down_deg (the eyeball itself stays),
## fully within r[0] of the centre and fading out by r[1], toward the corners (half_w across) and behind the eye's front (z); the
## turn changes sign smoothly across the eye's middle (band m) so the corners and a shut lid's seam stay joined. `k` how much.
static func _lids(p: Vector3, k: float, ctx: Dictionary) -> Vector3:
	var lc: Dictionary = ctx.get("lids", {})
	if lc.is_empty():
		return p
	var up := deg_to_rad(float(lc.get("up_deg", 0.0)))
	var dn := deg_to_rad(float(lc.get("down_deg", 0.0)))
	var r: Array = lc.get("r", [0.015, 0.03])
	var hwid: Array = lc.get("half_w", [0.006, 0.016])
	var zr: Array = lc.get("z", [-0.004, 0.004])
	var band := float(lc.get("band", 0.003))
	var yc := float(lc.get("y_off", 0.0))
	for c: Vector3 in ctx.eye_c:
		var d := p - c
		var dl := d.length()
		if dl >= float(r[1]):
			continue
		var w := k * (1.0 - smoothstep(float(r[0]), float(r[1]), dl)) * smoothstep(float(zr[0]), float(zr[1]), d.z) \
				* (1.0 - smoothstep(float(hwid[0]), float(hwid[1]), absf(d.x)))
		if w <= 0.0:
			continue
		var s := clampf((d.y - yc) / band, -1.0, 1.0)
		s = s * (1.5 - 0.5 * s * s)                      # (smooth through the middle)
		var ang := (up if s > 0.0 else dn) * s * w
		p = c + d.rotated(Vector3.RIGHT, -ang)
	return p


## The face's local fields (baby_body.json "face": the nose smaller and flatter, the mouth smaller, the cheeks fuller), each mirrored
## to the other side when it has "mirror".
static func _face_fields(fc: Dictionary) -> Array:
	var out := []
	for k: String in fc:
		if not fc[k] is Dictionary or k == "lower_face":
			continue
		var d: Dictionary = fc[k]
		var at: Array = d.get("at", [0, 0, 0])
		var r: Array = d.get("r", [0.01, 0.03])
		var sc: Array = d.get("scale", [1, 1, 1])
		var pu: Array = d.get("push", [0, 0, 0])
		var one := {"at": Vector3(float(at[0]), float(at[1]), float(at[2])), "r": Vector2(float(r[0]), float(r[1])),
				"scale": Vector3(float(sc[0]), float(sc[1]), float(sc[2])), "push": Vector3(float(pu[0]), float(pu[1]), float(pu[2]))}
		out.append(one)
		if bool(d.get("mirror", false)):
			var two := one.duplicate()
			two.at = Vector3(-one.at.x, one.at.y, one.at.z)
			two.push = Vector3(-one.push.x, one.push.y, one.push.z)
			out.append(two)
	return out


## One local field: within r.x of `at` the point is scaled about it by `scale` and moved by `push`, fading out by r.y; `k` how much.
static func _feature(p: Vector3, k: float, ff: Dictionary) -> Vector3:
	var at: Vector3 = ff.at
	var d := p - at
	var r: Vector2 = ff.r
	var dl := d.length()
	if dl >= r.y:
		return p
	var w := (1.0 - smoothstep(r.x, r.y, dl)) * k
	var sc: Vector3 = ff.scale
	return at + d * Vector3.ONE.lerp(sc, w) + (ff.push as Vector3) * w


## The head toward a sphere round the cranium's centre: each direction from the centre scaled by the same factor (a point further
## out, the hair, keeps its distance in proportion), the factor pulling the ellipsoid's surface to the sphere of its smallest radius
## (never out: the head never grows), by the direction: strong below (the jaw and chin), less up (the crown) and behind, light in the
## band of the face (eyes, nose, mouth).
static func _round(p: Vector3, hw: float, rk: float, rc: Dictionary) -> Vector3:
	var ca: Array = rc.get("centre", [0.0, 1.49, 0.02])
	var ra: Array = rc.get("radii", [0.08, 0.12, 0.095])
	var c := Vector3(float(ca[0]), float(ca[1]), float(ca[2]))
	var r := Vector3(float(ra[0]), float(ra[1]), float(ra[2]))
	var d := p - c
	var dl := d.length()
	if dl < 1e-5:
		return p
	var u := d / dl
	var target := 1.0
	var ht: Variant = rc.get("table")
	if ht is Dictionary:
		# the head's own radius that way (the table of its skin) to the sphere of the same volume: the size is kept
		target = float(ht.rs) * float(rc.get("size", 0.97)) / maxf(_hrad(ht, u), 0.02)
	else:
		target = pow(r.x * r.y * r.z, 1.0 / 3.0) * (u / r).length()
	target = clampf(target, 0.6, 1.4)
	var kd := float(rc.get("k_mid", 0.6))
	if u.y > 0.0:
		kd = lerpf(kd, float(rc.get("k_crown", 0.35)), u.y)
	else:
		kd = lerpf(kd, float(rc.get("k_jaw", 1.0)), -u.y)
	if u.z < 0.0:
		kd = lerpf(kd, float(rc.get("k_back", 0.8)), -u.z * (1.0 - absf(u.y)))
	elif u.y > 0.0:
		kd = lerpf(kd, float(rc.get("k_forehead", kd)), clampf(2.2 * u.z * u.y, 0.0, 1.0))
	var fb: Array = rc.get("face_band", [1.35, 1.56])
	var fz: Array = rc.get("face_z", [0.0, 0.06])
	var face := smoothstep(float(fz[0]), float(fz[1]), d.z) * smoothstep(float(fb[0]) - 0.02, float(fb[0]) + 0.02, p.y) \
			* (1.0 - smoothstep(float(fb[1]) - 0.05, float(fb[1]) + 0.05, p.y))
	kd = lerpf(kd, float(rc.get("k_face", 0.2)), face)
	var ny: Array = rc.get("neck_y", [1.3, 1.37])
	var reach: Array = rc.get("reach", [0.17, 0.23])
	var k := clampf(rk * kd, -0.5, 1.0) * maxf(hw, smoothstep(float(ny[0]), float(ny[1]), p.y)) * (1.0 - smoothstep(float(reach[0]), float(reach[1]), dl))
	return c + d * lerpf(1.0, target, k)


## The trunk toward a smooth barrel (tc: y range, k, depth, belly {y, amount}): each direction of a section scaled by the barrel's
## radius over the body's own there, so a garment keeps its distance from the skin in proportion.
static func _barrel(p: Vector3, tw: float, ctx: Dictionary) -> Vector3:
	var t: Dictionary = ctx.table
	var tc: Dictionary = ctx.tc
	var yr: Array = tc.get("y", [0.8, 1.26])
	var fade := smoothstep(float(yr[0]), float(yr[0]) + 0.05, p.y) * (1.0 - smoothstep(float(yr[1]) - 0.05, float(yr[1]), p.y))
	var k := float(tc.get("k", 0.0)) * tw * fade
	if k <= 0.0:
		return p
	var fy := clampf((p.y - float(t.y0)) / 0.01, 0.0, float(int(t.ny) - 1) - 0.001)
	var yi := int(fy)
	var yt := fy - float(yi)
	var zc: PackedFloat32Array = t.zc
	var z0 := lerpf(zc[yi], zc[yi + 1], yt)
	var d := Vector2(p.x, p.z - z0)
	var dl := d.length()
	if dl < 1e-4:
		return p
	var a := atan2(d.x, d.y) / TAU * T_ANG
	var a0 := int(floor(a))
	var at := a - float(a0)
	var rad: PackedFloat32Array = t.rad
	var i0 := posmod(a0, T_ANG)
	var i1 := posmod(a0 + 1, T_ANG)
	var rb := lerpf(lerpf(rad[yi * T_ANG + i0], rad[yi * T_ANG + i1], at), lerpf(rad[(yi + 1) * T_ANG + i0], rad[(yi + 1) * T_ANG + i1], at), yt)
	var side: PackedFloat32Array = t.side
	var sa := lerpf(side[yi], side[yi + 1], yt)
	var sb := sa * float(tc.get("depth", 0.8))
	var u := d / dl
	var front := maxf(u.y, 0.0)
	var bl: Dictionary = tc.get("belly", {})
	var by: Array = bl.get("y", [0.9, 1.1])
	var bump := smoothstep(float(by[0]), lerpf(float(by[0]), float(by[1]), 0.4), p.y) * (1.0 - smoothstep(lerpf(float(by[0]), float(by[1]), 0.6), float(by[1]), p.y))
	sb *= 1.0 + float(bl.get("amount", 0.0)) * bump * front
	var rt := 1.0 / sqrt((u.x * u.x) / (sa * sa) + (u.y * u.y) / (sb * sb))
	var s := lerpf(1.0, clampf(rt / maxf(rb, 0.01), 0.7, 1.3), k)
	d *= s
	return Vector3(d.x, p.y, d.y + z0)


# ---------------------------------------------------------------------------------------------------- one mesh
static func _restore(mi: MeshInstance3D) -> void:
	if not mi.has_meta("cp_src"):
		var wts := {}
		for i in mi.get_blend_shape_count():
			wts[String(mi.mesh.get_blend_shape_name(i))] = mi.get_blend_shape_value(i)
		mi.set_meta("cp_src", mi.mesh)
		mi.set_meta("cp_w", wts)
		return
	if mi.mesh != mi.get_meta("cp_src"):
		mi.mesh = mi.get_meta("cp_src")
		for i in mi.get_blend_shape_count():
			mi.set_blend_shape_value(i, 0.0)
		var wts: Dictionary = mi.get_meta("cp_w")
		for k: String in wts:
			var i := mi.find_blend_shape_by_name(k)
			if i >= 0:
				mi.set_blend_shape_value(i, wts[k])


## [the mapped point, the map's Jacobian] of an adult bind-space point: the fields, then the bones' blended scaling.
static func _map(p: Vector3, aw: Basis, cw: Vector3, hw: float, tw: float, ctx: Dictionary, eye: bool) -> Array:
	var q := _field(p, hw, tw, ctx, eye)
	var J := aw
	if q != p or hw > 0.0 or tw > 0.0 or p.y > 1.28:
		const E := 0.0005
		var jx := (_field(p + Vector3(E, 0, 0), hw, tw, ctx, eye) - q) / E
		var jy := (_field(p + Vector3(0, E, 0), hw, tw, ctx, eye) - q) / E
		var jz := (_field(p + Vector3(0, 0, E), hw, tw, ctx, eye) - q) / E
		J = aw * Basis(jx, jy, jz)
	return [aw * q + cw, J]


## The jaw dropped: the lower lip, the chin and the jaw turned down about a hinge before the ears (baby_body.json "mouth": the hinge,
## the angle, the lip line), fading into the neck and the cheeks.
static func _mouth(p: Vector3, hw: float, mc: Dictionary, n := Vector3.UP) -> Vector3:
	var hg: Array = mc.get("hinge", [0.0, 1.445, 0.02])
	var h := Vector3(float(hg[0]), float(hg[1]), float(hg[2]))
	var lip := float(mc.get("lip_y", 1.411))
	var ang := deg_to_rad(float(mc.get("deg", 16.0)))
	# below the lips' line; at the line itself the lower lip's skin faces up (the upper lip's down): the mouth parts there
	var below := 1.0 if p.y < lip - 0.004 else (0.0 if p.y > lip + 0.004 else (1.0 if n.y > 0.1 else (0.0 if n.y < -0.1 else (1.0 if p.y < lip else 0.0))))
	if absf(p.y - lip) < 0.004 and absf(p.x) > 0.018:
		below = 1.0 - smoothstep(lip - 0.004, lip + 0.002, p.y)
	var front := smoothstep(h.z - 0.02, h.z + 0.04, p.z)
	var neck := smoothstep(float(mc.get("neck_y", 1.34)), float(mc.get("neck_y", 1.34)) + 0.035, p.y)
	var side := 1.0 - smoothstep(float(mc.get("half_w", 0.055)), float(mc.get("half_w", 0.055)) + 0.02, absf(p.x))
	var k := below * front * neck * side * hw
	if k <= 0.0:
		return p
	var d := p - h
	return h + d.rotated(Vector3.RIGHT, ang * k)
