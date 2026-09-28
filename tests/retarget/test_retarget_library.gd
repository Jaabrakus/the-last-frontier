extends SceneTree
## Checks the Actor_A -> Actor_B retarget prototype library in the game project.
##
##   Godot --headless --path ~/Downloads/Frontier -s tests/retarget/test_retarget_library.gd
##
## Library  res://animations_extra/actor_a_rt_proto.res   (built by tools/retarget/build_library.gd)
## Manifest res://animations_extra/actor_a_rt_proto.json  (written by tools/retarget/retarget.py)
##
## 1. Provenance: every animation carries the source clip's native_asset_id (== manifest),
##    original_name and a `retarget` stamp naming its source clip.
## 2. Tracks only address bones of the game's Actor_B Skeleton3D.
## 3. Playback: the AnimationPlayer pose at the manifest's reference frames equals the
##    retarget tool's own forward kinematics (13 joints, 2 mm).
## 4. Additives: Add2(retargeted base, retargeted additive) in an AnimationTree equals the
##    tool's reference composition (2 mm), so the additive clips compose against the
##    Actor_B bind-pose rest as designed.
## 5. Floor: ground-profile clips keep heel and ball above -4 cm at every frame (report).
## Exit code 0 when every check passes.

const LIB_PATH := "res://animations_extra/actor_a_rt_proto.res"
const MANIFEST_PATH := "res://animations_extra/actor_a_rt_proto.json"
const LIB_NAME := "actor_a_rt"
const POS_TOL := 0.002
const FPS := 30.0

var sk: Skeleton3D
var ap: AnimationPlayer
var lib: AnimationLibrary
var man: Dictionary
var fails := 0
var checks := 0


func _initialize() -> void:
	var inst: Node3D = load("res://characters/Actor_B.tscn").instantiate()
	root.add_child(inst)
	sk = inst.get_node("Skeleton3D")
	ap = inst.get_node("AnimationPlayer")
	lib = load(LIB_PATH)
	man = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	_check(lib != null and man != null, "library and manifest load")
	if lib == null or man == null:
		_finish()
		return
	ap.add_animation_library(LIB_NAME, lib)
	await process_frame
	_check(lib.get_animation_list().size() == man["clips"].size(),
			"library has %d animations (manifest %d)" % [lib.get_animation_list().size(), man["clips"].size()])
	for name: String in man["clips"]:
		_check_clip(name, man["clips"][name])
	for ref: Dictionary in man.get("add2_reference", []):
		_check_add2(inst, ref)
	_finish()


func _check_clip(name: String, rec: Dictionary) -> void:
	if not lib.has_animation(name):
		_check(false, "%s present" % name)
		return
	var anim := lib.get_animation(name)
	var stamp: Dictionary = anim.get_meta("retarget", {})
	var prov_ok: bool = str(anim.get_meta("native_asset_id", "")) == str(rec["native_asset_id"]) \
			and str(anim.get_meta("original_name", "")) != "" \
			and stamp.get("source_clip", "") == name and stamp.get("source_actor", "") == "Actor_A"
	var bad_paths := []
	for t in anim.get_track_count():
		var bone := str(anim.track_get_path(t).get_concatenated_subnames())
		if sk.find_bone(bone) == -1:
			bad_paths.append(bone)
	var err := 0.0
	var worst := ""
	if rec.has("reference"):
		for i in rec["reference"]["frames"].size():
			var f: int = rec["reference"]["frames"][i]
			var pose := _sample(name, f / FPS)
			for j: String in rec["reference"]["joints"]:
				var v: Array = rec["reference"]["joints"][j][i]
				var e: float = (pose[sk.find_bone(j)] as Transform3D).origin.distance_to(Vector3(v[0], v[1], v[2]))
				if e > err:
					err = e
					worst = "%s@%d" % [j, f]
	var floor_msg := ""
	if rec.get("profile", "") == "ground" and not rec.get("additive", false) and rec.has("reference"):
		var lowest := 1e9
		for f in int(rec["frames"]):
			var pose := _sample(name, f / FPS)
			for b in ["l_heel", "l_ball", "r_heel", "r_ball"]:
				lowest = minf(lowest, (pose[sk.find_bone(b)] as Transform3D).origin.y)
		floor_msg = ", lowest heel/ball %.3f m" % lowest
		_check(lowest > -0.04, "%s: feet stay above the floor (%.3f m)" % [name, lowest])
	_check(prov_ok and bad_paths.is_empty() and err <= POS_TOL,
			"%s: provenance %s, %d tracks, bad paths %s, playback vs tool max %.5f m %s%s" % [
				name, "ok" if prov_ok else "MISSING", anim.get_track_count(), bad_paths, err, worst, floor_msg])


func _sample(name: String, t: float) -> Array:
	sk.reset_bone_poses()
	ap.play(LIB_NAME + "/" + name)
	ap.seek(t, true)
	ap.stop(true)
	var out := []
	for b in sk.get_bone_count():
		out.append(sk.get_bone_global_pose(b))
	return out


func _check_add2(inst: Node3D, ref: Dictionary) -> void:
	var tree := AnimationTree.new()
	inst.add_child(tree)
	tree.anim_player = tree.get_path_to(ap)
	tree.root_node = tree.get_path_to(inst)
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var err := 0.0
	var worst := ""
	for i in ref["frames"].size():
		var f: int = ref["frames"][i]
		var bt := AnimationNodeBlendTree.new()
		var a := AnimationNodeAnimation.new()
		a.animation = LIB_NAME + "/" + str(ref["base"])
		bt.add_node("base", a)
		var n := AnimationNodeAnimation.new()
		n.animation = LIB_NAME + "/" + str(ref["add"])
		bt.add_node("add", n)
		bt.add_node("sum", AnimationNodeAdd2.new())
		bt.connect_node("sum", 0, "base")
		bt.connect_node("sum", 1, "add")
		bt.connect_node("output", 0, "sum")
		sk.reset_bone_poses()
		tree.tree_root = bt
		tree.active = true
		tree.set("parameters/sum/add_amount", 1.0)
		tree.advance(0.0)
		tree.advance(f / FPS)
		for j: String in ref["joints"]:
			var v: Array = ref["joints"][j][i]
			var e: float = sk.get_bone_global_pose(sk.find_bone(j)).origin.distance_to(Vector3(v[0], v[1], v[2]))
			if e > err:
				err = e
				worst = "%s@%d" % [j, f]
		tree.active = false
	tree.queue_free()
	_check(err <= POS_TOL, "Add2(%s, %s) in an AnimationTree == tool reference (max %.5f m %s)" % [
			ref["base"], ref["add"], err, worst])


func _check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		fails += 1
	print(("  ok   " if ok else "  FAIL ") + msg)


func _finish() -> void:
	print("RETARGET LIBRARY %s (%d checks, %d failed)" % ["OK" if fails == 0 else "FAILED", checks, fails])
	quit(0 if fails == 0 else 1)
