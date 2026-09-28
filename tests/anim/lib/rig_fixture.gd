class_name RigFixture
extends RefCounted
## Test rig: a skeleton, its AnimationPlayer and a scratch AnimationTree driven by hand
## (callback MANUAL, deterministic = true, as the plan's PlayerAnim). Two flavours:
##
##   RigFixture.actor_b(parent)           characters/Actor_B.tscn with library `actor_b`
##                                        (Actor_B.res; extracted and converted from The Last of
##                                        Us, PS3; see CREDITS.md). BindRest.ensure() runs first
##                                        when scripts/player/anim/bind_rest.gd is present.
##   RigFixture.synthetic(parent, bones, anims)
##                                        a few bones and generated yaw / position ramps, for
##                                        exact engine-contract checks.
##
## Clip names are library-relative ("actor_b-p-run-fw"); "lib/name" is accepted as is.
## Node helpers build AnimationNodeAnimation / filters from clips; play() installs a tree root
## and runs the two warm-up advance(0) calls (P12). Nothing here mutates an Animation.

const SCENE := "res://characters/Actor_B.tscn"
const LIB := "actor_b"

var root: Node3D
var sk: Skeleton3D
var ap: AnimationPlayer
var tree: AnimationTree
var lib_name := ""
## BindRest.ensure() result for Actor_B ({} when BindRest is unavailable), else the fixture's
## own rest-vs-null-add measurement {ok, max_rot, max_pos, channels, source}.
var rest_report := {}

static var _scene: PackedScene


## Instantiates Actor_B under parent. opts: {bind_rest: bool = true, tree: bool = true}.
static func actor_b(parent: Node, opts := {}) -> RigFixture:
	if not parent.is_inside_tree():
		push_warning("RigFixture: parent is not inside the SceneTree yet (await a frame first)")
	if _scene == null:
		_scene = load(SCENE) as PackedScene
	if _scene == null:
		push_error("RigFixture: cannot load " + SCENE)
		return null
	var r := RigFixture.new()
	r.lib_name = LIB
	r.root = _scene.instantiate() as Node3D
	r.root.name = "RigFixture_Actor_B"
	parent.add_child(r.root)
	r.sk = r.root.find_children("*", "Skeleton3D", true, false)[0]
	r.ap = r.root.find_children("*", "AnimationPlayer", true, false)[0]
	r.ap.stop()
	if opts.get("bind_rest", true):
		r.rest_report = r._ensure_bind_rest()
	if opts.get("tree", true):
		r._make_tree()
	return r


## bones: Array of "name" or [name, parent_name, rest: Transform3D (optional)].
## anims: {name: {len: float, loop: bool, yaw: {bone: [[t, deg], ...]},
##                pos: {bone: [[t, Vector3], ...]}, scale: {bone: [[t, Vector3], ...]}}}
## Rotation keys are yaw (about +Y) in degrees; keys are linear.
static func synthetic(parent: Node, bones: Array, anims: Dictionary) -> RigFixture:
	if not parent.is_inside_tree():
		push_warning("RigFixture: parent is not inside the SceneTree yet (await a frame first)")
	var r := RigFixture.new()
	r.root = Node3D.new()
	r.root.name = "RigFixture_Synthetic"
	parent.add_child(r.root)
	r.sk = Skeleton3D.new()
	r.sk.name = "Skeleton3D"
	r.root.add_child(r.sk)
	for b in bones:
		var spec: Array = b if b is Array else [b, ""]
		var i := r.sk.add_bone(spec[0])
		if spec.size() > 1 and String(spec[1]) != "":
			r.sk.set_bone_parent(i, r.sk.find_bone(spec[1]))
		if spec.size() > 2:
			r.sk.set_bone_rest(i, spec[2])
	r.sk.reset_bone_poses()
	r.ap = AnimationPlayer.new()
	r.ap.name = "AnimationPlayer"
	r.root.add_child(r.ap)
	var lib := AnimationLibrary.new()
	for n in anims:
		lib.add_animation(n, make_animation(anims[n]))
	r.ap.add_animation_library("", lib)
	r._make_tree()
	return r


## Builds an Animation from a synthetic spec (see synthetic()).
static func make_animation(spec: Dictionary) -> Animation:
	var a := Animation.new()
	a.length = float(spec.get("len", 1.0))
	a.loop_mode = Animation.LOOP_LINEAR if spec.get("loop", false) else Animation.LOOP_NONE
	for bone in spec.get("pos", {}):
		var t := a.add_track(Animation.TYPE_POSITION_3D)
		a.track_set_path(t, NodePath("Skeleton3D:" + bone))
		for k in spec.pos[bone]:
			a.position_track_insert_key(t, k[0], k[1])
	for bone in spec.get("yaw", {}):
		var t := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(t, NodePath("Skeleton3D:" + bone))
		for k in spec.yaw[bone]:
			a.rotation_track_insert_key(t, k[0], Quaternion(Vector3.UP, deg_to_rad(k[1])))
	for bone in spec.get("scale", {}):
		var t := a.add_track(Animation.TYPE_SCALE_3D)
		a.track_set_path(t, NodePath("Skeleton3D:" + bone))
		for k in spec.scale[bone]:
			a.scale_track_insert_key(t, k[0], k[1])
	return a


# --- clips ---------------------------------------------------------------------------------

## Library-qualified animation name ("actor_b/<clip>"; synthetic rigs use the default library).
func qualified(clip: String) -> StringName:
	if "/" in clip or lib_name == "":
		return StringName(clip)
	return StringName(lib_name + "/" + clip)


func has_clip(clip: String) -> bool:
	return ap.has_animation(qualified(clip))


func anim(clip: String) -> Animation:
	var q := qualified(clip)
	return ap.get_animation(q) if ap.has_animation(q) else null


## Callable(name_or_animation) -> Animation, for PoseOracle.
func clip_resolver() -> Callable:
	return func(c: Variant) -> Animation:
		if c is Animation:
			return c
		return anim(String(c))


## Bone names the clip keys (any track type), in track order.
func keyed_bones(clip: String) -> PackedStringArray:
	var out := PackedStringArray()
	var a := anim(clip)
	if a == null:
		return out
	for t in a.get_track_count():
		var bn := String(a.track_get_path(t).get_concatenated_subnames())
		if bn != "" and not out.has(bn):
			out.append(bn)
	return out


func track_paths(clip: String) -> Array[NodePath]:
	var out: Array[NodePath] = []
	var a := anim(clip)
	if a:
		for t in a.get_track_count():
			if not out.has(a.track_get_path(t)):
				out.append(a.track_get_path(t))
	return out


## AnimationNodeAnimation for clip. opts: {custom_timeline: bool, length: float (timeline),
## stretch: bool, loop: Animation.LoopMode, start_offset: float}.
func node(clip: String, opts := {}) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = qualified(clip)
	if opts.get("custom_timeline", false) or opts.has("length"):
		n.use_custom_timeline = true
		n.timeline_length = float(opts.get("length", anim(clip).length if anim(clip) else 1.0))
		n.stretch_time_scale = bool(opts.get("stretch", true))
		n.loop_mode = int(opts.get("loop", Animation.LOOP_LINEAR))
		n.start_offset = float(opts.get("start_offset", 0.0))
	return n


## Enables node's filter on every track path of the given clips (plan D5: filters per clip).
func filter_from_clips(filtered: AnimationNode, clips: Array) -> void:
	filtered.filter_enabled = true
	for c in clips:
		for p in track_paths(c):
			filtered.set_filter_path(p, true)


## Enables node's filter on the given bone names.
func filter_bones(filtered: AnimationNode, bones: Array) -> void:
	filtered.filter_enabled = true
	for b in bones:
		filtered.set_filter_path(NodePath("Skeleton3D:" + String(b)), true)


# --- tree ----------------------------------------------------------------------------------

## Installs tree_root, applies params ({"parameters/...": value} or {"x/blend_amount": v}),
## activates the tree and runs two warm-up advance(0) calls.
## A fresh AnimationTree is used for every play(): AnimationTree keeps parameter values (fade
## state, positions, amounts) across tree_root changes when node paths repeat.
## advance_expression_base_node and deterministic carry over.
func play(tree_root: AnimationRootNode, params := {}) -> void:
	_make_tree()
	tree.tree_root = tree_root
	tree.active = true
	for k in params:
		set_param(k, params[k])
	tree.advance(0.0)
	tree.advance(0.0)


func set_param(path: String, value: Variant) -> void:
	tree.set(path if path.begins_with("parameters/") else "parameters/" + path, value)


func get_param(path: String) -> Variant:
	return tree.get(path if path.begins_with("parameters/") else "parameters/" + path)


func advance(dt: float, steps := 1) -> void:
	for i in steps:
		tree.advance(dt)


## A single-clip tree at time t (TimeSeek), for reading one pose.
func pose_of(clip: String, t := 0.0) -> PoseOracle.Pose:
	var bt := AnimationNodeBlendTree.new()
	bt.add_node("clip", node(clip))
	bt.add_node("seek", AnimationNodeTimeSeek.new())
	bt.connect_node("seek", 0, "clip")
	bt.connect_node("output", 0, "seek")
	play(bt)
	set_param("seek/seek_request", t)
	advance(0.0)
	return capture()


## Filtered Blend2 of `over` onto `base` (over's keyed bones), like the game's hands layers.
func layer_tree(base: String, over: String, amount := 1.0) -> AnimationNodeBlendTree:
	var bt := AnimationNodeBlendTree.new()
	bt.add_node("base", node(base))
	bt.add_node("over", node(over))
	var b2 := AnimationNodeBlend2.new()
	filter_from_clips(b2, [over])
	bt.add_node("mix", b2)
	bt.connect_node("mix", 0, "base")
	bt.connect_node("mix", 1, "over")
	bt.connect_node("output", 0, "mix")
	play(bt, {"mix/blend_amount": amount})
	return bt


## Add2(base, add) at amount.
func add_tree(base: String, add: String, amount := 1.0) -> AnimationNodeBlendTree:
	var bt := AnimationNodeBlendTree.new()
	bt.add_node("base", node(base))
	bt.add_node("add", node(add))
	bt.add_node("add2", AnimationNodeAdd2.new())
	bt.connect_node("add2", 0, "base")
	bt.connect_node("add2", 1, "add")
	bt.connect_node("output", 0, "add2")
	play(bt, {"add2/add_amount": amount})
	return bt


# --- pose ----------------------------------------------------------------------------------

func bone(bone_name: String) -> int:
	return sk.find_bone(bone_name)


func bone_rot(bone_name: String) -> Quaternion:
	return sk.get_bone_pose_rotation(sk.find_bone(bone_name))


func bone_pos(bone_name: String) -> Vector3:
	return sk.get_bone_pose_position(sk.find_bone(bone_name))


## Skeleton-space pose of a bone (post-modifier only inside Skeleton3D.skeleton_updated, P13).
func global_pose(bone_name: String) -> Transform3D:
	return sk.get_bone_global_pose(sk.find_bone(bone_name))


## Yaw (degrees about +Y) of a bone's local rotation; for synthetic rigs.
func yaw_deg(bone_name: String) -> float:
	var q := bone_rot(bone_name)
	if absf(q.x) + absf(q.z) < 1e-6:
		return wrapf(rad_to_deg(2.0 * atan2(q.y, q.w)), -180.0, 180.0)
	return rad_to_deg(q.get_euler().y)


## Current local pose of every bone.
func capture() -> PoseOracle.Pose:
	return PoseOracle.capture(sk)


## Frees the rig's nodes (the context also does this after the suite).
func dispose() -> void:
	if is_instance_valid(root):
		root.queue_free()


func _make_tree() -> void:
	var expr := NodePath()
	var det := true
	if is_instance_valid(tree):
		expr = tree.advance_expression_base_node
		det = tree.deterministic
		tree.active = false
		root.remove_child(tree)
		tree.queue_free()
	tree = AnimationTree.new()
	tree.name = "FixtureTree"
	root.add_child(tree)
	tree.anim_player = tree.get_path_to(ap)
	tree.root_node = tree.get_path_to(root)
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.deterministic = det
	tree.advance_expression_base_node = expr


## Calls BindRest.ensure() when the WP0 class is available (looked up at runtime so this
## fixture never depends on it at parse time); otherwise measures rest vs null-add itself.
func _ensure_bind_rest() -> Dictionary:
	for c in ProjectSettings.get_global_class_list():
		if c["class"] == &"BindRest":
			var s: Script = load(c["path"])
			if s and s.can_instantiate():
				var d: Dictionary = s.call("ensure", sk, ap, StringName(LIB))
				d["source"] = "BindRest.ensure"
				return d
	var out := {"ok": false, "max_rot": 0.0, "max_pos": 0.0, "channels": 0, "source": "RigFixture"}
	var ref := anim("null-add")
	if ref == null:
		return out
	for t in ref.get_track_count():
		var bi := sk.find_bone(String(ref.track_get_path(t).get_concatenated_subnames()))
		if bi < 0:
			continue
		var rest := sk.get_bone_rest(bi)
		match ref.track_get_type(t):
			Animation.TYPE_ROTATION_3D:
				out.max_rot = maxf(out.max_rot, PoseOracle.qdist(rest.basis.get_rotation_quaternion(),
						ref.rotation_track_interpolate(t, 0.0)))
				out.channels += 1
			Animation.TYPE_POSITION_3D:
				out.max_pos = maxf(out.max_pos, rest.origin.distance_to(ref.position_track_interpolate(t, 0.0)))
				out.channels += 1
	out.ok = out.max_rot <= 1e-6 and out.max_pos <= 1e-6
	if not out.ok:
		push_warning("RigFixture: Actor_B rest differs from null-add (rot %.2e rad, pos %.2e m)" % [out.max_rot, out.max_pos])
	return out
