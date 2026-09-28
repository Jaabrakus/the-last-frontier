extends SceneTree
## Independent geometry dump for the loadout review (tools/loadout/review_geometry.py analyses it).
##
##   Godot --headless --path . -s tools/loadout/review_geometry_dump.gd -- out=/abs/dir [presets=a,b] [quick=1]
##   (run it under a hard time limit; about 1-3 min)
##
## Unlike tests/loadout/test_stow_penetration.gd, which measures the design's capsules, this dumps the
## rendered geometry: the whole skinned body (every mesh of CharacterBodyMesh: skin, clothes, gear, face,
## hair, hat; the helper bones driven; surfaces the rig hides left out) and every visible mesh of the
## stowed copies and the in-hand model, in skeleton space, for a set of poses per preset:
##   - hands free (all stowed): idle, walk, run, sprint, crouch, crouch walk, run-bw diagonals, jump, and
##     the traversal moves in the rig's traversal state;
##   - each drawable item in the hand (the rest stowed): idle with its carry arms, crouch, sprint, aim.
## The rig runs its test path (update_now with dt = 0: every yield solved fully), like the tests.
##
## Output: <out>/index.json and <out>/*.f32 (little-endian float32: x y z nx ny nz per vertex).
##
## Provenance: the rig, clips and bind pose are Actor_B.

const STOWED_POSES := [
	["idle", "actor_b-p-stealth-idle", [0.0, 0.6], "stand", ""],
	["walk", "actor_b-p-walk-fw", [0.0, 0.25, 0.5, 0.75], "stand", ""],
	["run", "actor_b-p-run-fw", [0.0, 0.33, 0.66], "stand", ""],
	["sprint", "actor_b-p-sprint-fw", [0.0, 0.33, 0.66], "stand", ""],
	["run_bw_lt", "actor_b-p-run-bw-lt", [0.0, 0.33, 0.66], "stand", ""],
	["walk_fw_lt", "actor_b-p-walk-fw-lt", [0.0, 0.5], "stand", ""],
	["crouch", "actor_b-p-crouch-idle", [0.3], "stand", ""],
	["crouch_walk", "actor_b-p-crouch-walk-fw", [0.0, 0.5], "stand", ""],
	["jump", "actor_b-p-jump-long", [0.3, 0.6], "traversal", ""],
	["climb", "actor_b-p-ledge-hang-climb-up^ledge-knee", [0.15, 0.3, 0.5, 0.65, 0.85], "traversal", ""],
	["ledge_idle", "actor_b-p-ledge-idle", [0.5], "traversal", ""],
	["vault", "actor_b-p-idle^vault-over-1m", [0.25, 0.45, 0.65], "traversal", ""],
]
## Held poses: [name, base clip, t fraction, layer kind]  layer kind: carry | aim
const HELD_POSES := [
	["idle", "actor_b-p-stealth-idle", 0.3, "carry"],
	["crouch", "actor_b-p-crouch-idle", 0.3, "carry"],
	["sprint", "actor_b-p-sprint-fw", 0.4, "carry"],
	["aim", "", 0.5, "aim"],
]
const AIM := {"musket": "actor_b-p-rifle-idle-aim", "pistol": "actor_b-p-pistol-aim-idle", "bow": "actor_b-p-bow-aim-idle",
		"spear_pair": "actor_b-p-1h-aim-throw-idle", "tomahawk": "actor_b-p-1h-aim-throw-idle", "atlatl": "actor_b-p-1h-aim-throw-idle"}
const AIM_HANDS := {"musket": "actor_b-p-rifle-idle-aim--hands", "pistol": "actor_b-pistol-aim--hands", "bow": "actor_b-p-bow-aim-hands-idle"}
const CARRY := {"musket": ["actor_b-p-rifle-run-arms", "actor_b-p-rifle-crouch-idle-arms"],
		"bow": ["actor_b-p-bow-move--arms", "actor_b-p-bow-crouch-idle--arms"],
		"pistol": ["actor_b-r-arm-gun-idle", "actor_b-r-arm-gun-crouch-idle"],
		"throw": ["actor_b-p-1h-arm--part", "actor_b-p-1h-arm-crouch--part"]}
const DRAWABLE := ["musket", "bow", "pistol", "spear_pair", "tomahawk", "atlatl"]

var args := {}
var sk: Skeleton3D
var ap: AnimationPlayer
var body: CharacterBodyMesh
var poser: LoadoutClipPoser
var out_dir := ""
var index := {"poses": [], "body": {}, "samples": []}
var _n := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	out_dir = String(args.get("out", "/tmp/loadout_review_dump"))
	DirAccess.make_dir_recursive_absolute(out_dir)
	var inst := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate()
	root.add_child(inst)
	sk = inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	ap = inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	BindRest.ensure(sk, ap)
	body = CharacterBodyMesh.attach(sk, ap)
	poser = LoadoutClipPoser.new(sk, ap)
	await process_frame
	await process_frame
	var data := LoadoutData.get_default()
	var want: Array = String(args.get("presets", ",".join(data.preset_ids()))).split(",", false)
	_body_labels()
	var rigs := {}
	for pid: String in want:
		var rig := SlingRig.new()
		root.add_child(rig)
		rig.setup(sk, body, Loadout.from_preset(pid), {"auto": false})
		for it: Dictionary in rig.loadout.items:
			rig.snap_stowed(String(it.id))
		# the preview's in-hand models (SlingModels units on the holding hand's prop socket)
		for it: Dictionary in rig.loadout.items:
			if not String(it.kind) in DRAWABLE or rig.entries_of(String(it.id)).is_empty():
				continue
			var side: String = (rig.entries_of(String(it.id))[0] as SlingRig.Entry).hold
			var att := BoneAttachment3D.new()
			att.bone_name = SlingRig.PROPS[side]
			sk.add_child(att)
			var m := SlingModels.unit("spear" if String(it.kind) == "spear_pair" else String(it.kind))
			m.transform = SlingRig.HAND_OFFSET
			att.add_child(m)
			rig.set_hand_model(String(it.id), m)
		rigs[pid] = rig
	var quick := String(args.get("quick", "0")) == "1"
	# hands free
	for ps: Array in STOWED_POSES:
		var ts: Array = ps[2]
		if quick:
			ts = [ts[0]]
		for tf: float in ts:
			var L := poser.length(ps[1])
			poser.pose([[ps[1], L * tf]])
			var g := body.skinning_globals()
			var pose_id := "%s@%.2f" % [ps[0], tf]
			_dump_body(pose_id, g)
			for pid: String in rigs:
				var rig: SlingRig = rigs[pid]
				_set_all_stowed(rig)
				rig.set_state(ps[3])
				rig.update_now(0.0, g)
				_dump_items(pid, pose_id, "", rig, g)
	# each drawable in the hand
	for pid: String in rigs:
		var rig: SlingRig = rigs[pid]
		rig.set_state("stand")
		for it: Dictionary in rig.loadout.items:
			var k := String(it.kind)
			if not k in DRAWABLE or rig.entries_of(String(it.id)).is_empty():
				continue
			var fam := "throw" if k in ["spear_pair", "tomahawk", "atlatl"] else k
			for hp: Array in HELD_POSES:
				var layers: Array = []
				if hp[3] == "aim":
					var c := String(AIM.get(k, ""))
					layers.append([c, poser.length(c) * float(hp[2])])
					var hc := String(AIM_HANDS.get(k, ""))
					if hc != "" and poser.has_clip(hc):
						layers.append([hc, poser.length(hc) * float(hp[2]), "partial"])
				else:
					layers.append([hp[1], poser.length(hp[1]) * float(hp[2])])
					var cl: Array = CARRY.get(fam, ["", ""])
					var cc := String(cl[1] if hp[0] == "crouch" else cl[0])
					if cc != "" and poser.has_clip(cc):
						layers.append([cc, fmod(0.3, maxf(poser.length(cc), 0.01)), "partial"])
				poser.pose(layers)
				var g := body.skinning_globals()
				var pose_id := "held_%s_%s_%s" % [pid, it.id, hp[0]]
				_dump_body(pose_id, g)
				_set_all_stowed(rig)
				rig.snap_held(String(it.id))
				rig.update_now(0.0, g)
				_dump_items(pid, pose_id, String(it.id), rig, g)
	for pid: String in rigs:
		index.body["legacy_horn_hidden_" + pid] = (rigs[pid] as SlingRig).legacy_horn_hidden()
	var f := FileAccess.open(out_dir + "/index.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(index))
	f.close()
	print("REVIEW DUMP DONE: %d samples, %d files -> %s" % [index.samples.size(), _n, out_dir])
	for pid: String in rigs:
		(rigs[pid] as SlingRig).free()
	quit(0)


func _set_all_stowed(rig: SlingRig) -> void:
	for it: Dictionary in rig.loadout.items:
		rig.snap_stowed(String(it.id))


# --- body ---------------------------------------------------------------------------------------

## Per body vertex (in dump order): mesh name, material label, dominant bone name. Surfaces the legacy
## horn used ("horn", "wood", "horn_tip" of Gear) are tagged so the analysis can drop them where the rig
## hides them.
func _body_labels() -> void:
	var mesh_names: Array = []
	var labels: Array = []
	var bones: Array = []
	var counts: Array = []
	for mi in body.meshes:
		if not is_instance_valid(mi) or not (mi.mesh is ArrayMesh) or mi.skin == null:
			continue
		var am := mi.mesh as ArrayMesh
		for s in am.get_surface_count():
			var mat := am.surface_get_material(s)
			var lab: String = mat.resource_name if mat and mat.resource_name != "" else "%s_%d" % [mi.name, s]
			var arr := am.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bo: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var nb := bo.size() / maxi(v.size(), 1)
			mesh_names.append("%s/%s" % [mi.name, lab])
			counts.append(v.size())
			for i in v.size():
				var best := 0
				for k in nb:
					if w[i * nb + k] > w[i * nb + best]:
						best = k
				bones.append(sk.get_bone_name(_bind_bone(mi.skin, bo[i * nb + best])))
	index.body["surfaces"] = mesh_names
	index.body["counts"] = counts
	index.body["dominant_bone"] = bones


func _bind_bone(skin: Skin, i: int) -> int:
	var b := skin.get_bind_bone(i)
	if b < 0:
		b = sk.find_bone(skin.get_bind_name(i))
	return b


func _dump_body(pose_id: String, g: Array) -> void:
	var buf := PackedFloat32Array()
	for mi in body.meshes:
		if not is_instance_valid(mi) or not (mi.mesh is ArrayMesh) or mi.skin == null:
			continue
		var skin := mi.skin
		var mats: Array[Transform3D] = []
		for i in skin.get_bind_count():
			var b := _bind_bone(skin, i)
			mats.append((g[b] as Transform3D) * skin.get_bind_pose(i) if b >= 0 else Transform3D.IDENTITY)
		var am := mi.mesh as ArrayMesh
		for s in am.get_surface_count():
			var arr := am.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var bo: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var nb := bo.size() / maxi(v.size(), 1)
			for i in v.size():
				var p := Vector3.ZERO
				var n := Vector3.ZERO
				for k in nb:
					var wk := w[i * nb + k]
					if wk <= 0.0:
						continue
					var M: Transform3D = mats[bo[i * nb + k]]
					p += (M * v[i]) * wk
					n += (M.basis * nr[i]) * wk
				n = n.normalized()
				buf.append_array([p.x, p.y, p.z, n.x, n.y, n.z])
	var fn := "body_%d.f32" % _n
	_write(fn, buf)
	index.poses.append({"id": pose_id, "file": fn})


# --- items --------------------------------------------------------------------------------------

func _dump_items(pid: String, pose_id: String, held: String, rig: SlingRig, g: Array) -> void:
	var items: Array = []
	for e: SlingRig.Entry in rig.entries:
		if e.holder == null or not e.holder.visible:
			continue
		_collect(e.holder, "%s.%s" % [e.point, e.kind], e.item_id, g, items)
		if e.flyer and is_instance_valid(e.flyer) and e.flyer.visible:
			_collect(e.flyer, "flyer.%s" % e.kind, e.item_id, g, items)
	if held != "":
		var m: Node3D = rig.hand_models.get(held)
		if m and m.visible:
			_collect(m, "hand.%s" % held, held, g, items)
	var s := {"preset": pid, "pose": pose_id, "held": held, "items": items}
	var yl := {}
	for e: SlingRig.Entry in rig.entries:
		var L := rig.layering_of(e)
		yl[e.key] = {"layer_deg": L.x, "layer_shift_m": L.y, "yield_deg": rad_to_deg(e.yield_q.get_angle()), "shown": e.shown}
	s["entries"] = yl
	index.samples.append(s)


## Every visible MeshInstance3D under `node`, in skeleton space (the chain up to its BoneAttachment3D socket
## times that bone's pose in `g`). MultiMesh instances (the quiver's arrows) are read when the renderer
## keeps them (windowed); headless they are skipped.
func _collect(node: Node3D, name: String, item_id: String, g: Array, items: Array) -> void:
	var buf := PackedFloat32Array()
	var mesh_n := 0
	for n in node.find_children("*", "MeshInstance3D", true, false) + ([node] if node is MeshInstance3D else []):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not _visible_chain(mi):
			continue
		var X: Variant = _skel_xf(mi, g)
		if X == null:
			continue
		var vn := _mesh_points(mi.mesh)
		var v: PackedVector3Array = vn[0]
		var nr: PackedVector3Array = vn[1]
		var T: Transform3D = X
		var nb := T.basis.inverse().transposed()
		for i in v.size():
			var p := T * v[i]
			var nn := (nb * nr[i]).normalized()
			buf.append_array([p.x, p.y, p.z, nn.x, nn.y, nn.z])
		mesh_n += 1
	if buf.is_empty():
		return
	var fn := "item_%d.f32" % _n
	_write(fn, buf)
	items.append({"name": name, "item": item_id, "file": fn, "meshes": mesh_n})


var _mesh_cache := {}


## A mesh's vertices and normals (every surface), thinned to about MAX_PTS points (vertex order keeps
## neighbours together, so a stride keeps the shape).
const MAX_PTS := 2500


func _mesh_points(m: Mesh) -> Array:
	if _mesh_cache.has(m):
		return _mesh_cache[m]
	var total := 0
	for s in m.get_surface_count():
		total += m.surface_get_array_len(s)
	var stride := maxi(1, total / MAX_PTS)
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var k := 0
	for s in m.get_surface_count():
		var arr := m.surface_get_arrays(s)
		var sv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var sn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		for i in sv.size():
			if k % stride == 0:
				v.append(sv[i])
				n.append(sn[i] if i < sn.size() else Vector3.ZERO)
			k += 1
	_mesh_cache[m] = [v, n]
	return _mesh_cache[m]


func _visible_chain(n: Node) -> bool:
	var cur: Node = n
	while cur != null and cur != sk:
		if cur is Node3D and not (cur as Node3D).visible:
			return false
		cur = cur.get_parent()
	return true


func _skel_xf(n: Node3D, g: Array) -> Variant:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null:
		if cur is BoneAttachment3D:
			var b := sk.find_bone(String((cur as BoneAttachment3D).bone_name))
			return (g[b] as Transform3D) * xf
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
		if cur == sk:
			return xf
	return null


func _write(fn: String, buf: PackedFloat32Array) -> void:
	var f := FileAccess.open(out_dir + "/" + fn, FileAccess.WRITE)
	f.store_buffer(buf.to_byte_array())
	f.close()
	_n += 1
