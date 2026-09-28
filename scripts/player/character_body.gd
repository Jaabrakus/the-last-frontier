class_name CharacterBodyMesh
extends SkeletonModifier3D
## The player's skinned body and outfit (assets/character/actor_b_body.glb) on the
## game's Actor_B Skeleton3D.
##
##   var body := CharacterBodyMesh.attach(skeleton, anim_player)   # null if the asset is missing
##
## attach() adds this node as a child of the Skeleton3D (identity transform) with one
## MeshInstance3D per glb mesh under it. The meshes and materials are shared with the
## imported glb; only the Skin is built here.
##
## Multi-part (the customizer's body, hair and garments, assets/character/**):
##
##   var body := CharacterBodyMesh.attach_parts(skeleton, anim_player,
##           {"body": "res://assets/character/body/body.glb", "hair": "res://assets/character/hair/hair_queue_ribbon.glb"})
##   body.add_part("hat", "res://.../tricorn.glb")      # replaces a part with the same tag
##   body.remove_part("hat")
##   body.set_blend_shape("sex", 1.0)                   # on every mesh that has the shape
##   body.part_meshes("hair")                           # its MeshInstance3Ds
##
## Every character glb carries the same 291-joint armature in rig order, so all parts
## share one rebuilt Skin (keyed by the joint-name list; a glb with another list gets its
## own Skin). The helper driver covers the helpers bound by any part.
##
## Bind pose. The glb vertices are modeled in skeleton space (+Y up, facing +Z) at the
## game's bind pose, the one-frame clip `null-add` (the additive identity that the
## extracted clips are authored against). Each bind is therefore
## inverse(skeleton-space global transform of the bone in null-add). It is computed
## from the clip's track data: keyed channels at t = 0, and the Skeleton3D rest for the
## channels null-add does not key (root position, pelvis rotation, lower_base /
## upper_base, helper groups). The AnimationMixer uses the same rest values for those
## channels during play. The live skeleton pose is never read, so the result does not
## depend on what the AnimationTree is doing, and it is the same whether the rest of
## the keyed channels is null-add (BindRest) or the original import rest.
##
## Poses that must NOT be used for the binds (measured by the character probe):
##  - the Skeleton3D rest (get_bone_global_rest, create_skin_from_rest_transforms, the
##    glTF importer's defaults on another rig). The extracted clips use other bone-local
##    axes (up to 180 degrees per bone), so the mesh would land about 0.57 m off;
##  - bindpose-anim. It has the same shape, but its root has scale 1.0596 and a +0.10 m Z
##    offset, and it keys none of the channels null-add lacks, apart from those root values.
##
## Skin binds are mapped to bone indices of this skeleton by bone name. A bind whose bone
## is missing is attached rigidly to its nearest existing ancestor (from the glb rig), with
## a warning. The computed binds are compared with the binds stored in the glb, which
## tools/character/build_body.py also takes from null-add; `report.max_bind_diff` holds the
## difference. If the library has no null-add clip, the glb binds are used as they are.
##
## Helper bones. The rig's twist and leg helper bones are never animated by the clips
## (they are separate parentless groups that stay at the rest). This node is also a
## SkeletonModifier3D that drives some of them every frame from the animated pose, and
## the mesh is weighted to them (see HELPERS and tools/character/build_body.py):
##  - upper arm (l/r_shoulder_twist_a..d): the swing of the shoulder relative to the
##    clavicle, with none / 1/3 / 2/3 of its twist, and a half-swing armpit bone. Linear
##    blend skinning then never blends the torso with the full upper-arm twist (up to
##    155 degrees in the bow and musket reloads), which collapsed the armpit;
##  - forearm (l/r_forarm_twist_a..c): 30 / 60 / 90 % of the wrist's roll relative to
##    the elbow, so the roll (up to 142 degrees when aiming) is spread along the forearm
##    instead of pinching the wrist;
##  - coat skirt (l/r_upper_leg_front/thigh/rear_helper): the front, side and back skirt
##    panels of each leg hang toward world-down (gravity, at most SKIRT_GRAVITY_MAX_DEG from
##    the pelvis). The thigh only pushes them: the front panel lies on a raised thigh, the
##    back panel is pushed back by a thigh going back, the side panel sits between the two
##    and is pushed out by a spreading thigh. A panel whose hem would go below the feet
##    swings up away from the body (the tails rest behind the heels in a squat), so the
##    skirt never stands off the body like a board or a sail in a crouch or a knockdown;
##  - hair queue (wrinklemaps, an unused root-level bone): a pendulum hanging from the
##    back of the head, between the torso's down direction and world-down, never forward
##    into the neck and at most QUEUE_SIDE_MAX_DEG to the side.
## The modification happens inside the skeleton update only (Godot restores the animated
## pose afterwards), so game code that reads bone poses never sees it. The node moves
## itself behind every other SkeletonModifier3D of the skeleton so that it works on the
## final pose. skinning_globals() returns the same driven pose for CPU skinning in tests.

const DEFAULT_PATH := "res://assets/character/actor_b_body.glb"
const LIBRARY := &"actor_b"
const BIND_CLIP := &"null-add"
## Warn when a computed bind differs from the glb's by more than this (per basis
## column / metre). The regular difference is about 5e-6.
const BIND_WARN_TOL := 1e-3

enum Kind { UPPER_ARM, FOREARM, SKIRT, QUEUE }
## Driven helper bones, per side ("l_" / "r_" + name): [name, kind, a, b].
##  UPPER_ARM: a = fraction of the swing, b = fraction of the twist (pivot: shoulder joint).
##  FOREARM:   a = fraction of the wrist roll (pivot: elbow joint).
##  SKIRT:     a = panel: 0 front, 1 side, 2 back (pivot: hip joint; see SKIRT_HEMS).
## Plus the hair queue pendulum (QUEUE_HELPER).
## tools/character/build_body.py writes the same table into the sidecar json;
## tools/character/check_body_attach.gd checks that both agree.
const HELPERS := [
	["shoulder_twist_a", Kind.UPPER_ARM, 0.5, 0.0],
	["shoulder_twist_b", Kind.UPPER_ARM, 1.0, 0.0],
	["shoulder_twist_c", Kind.UPPER_ARM, 1.0, 1.0 / 3.0],
	["shoulder_twist_d", Kind.UPPER_ARM, 1.0, 2.0 / 3.0],
	["forarm_twist_a", Kind.FOREARM, 0.3, 0.0],
	["forarm_twist_b", Kind.FOREARM, 0.6, 0.0],
	["forarm_twist_c", Kind.FOREARM, 0.9, 0.0],
	["upper_leg_front_helper", Kind.SKIRT, 0, 0.0],
	["upper_leg_thigh_helper", Kind.SKIRT, 1, 0.0],
	["upper_leg_rear_helper", Kind.SKIRT, 2, 0.0],
]
## Coat skirt panels, per leg: 0 front, 1 side, 2 back (HELPERS column a). Each is a
## rotation about the hip joint relative to the pelvis, as flexion (about -X: down toward
## +Z, forward) and abduction (about +Z for the left leg: down toward +X, outward):
##  - gravity: the rotation that turns the panel's bind hang direction (down) to world-down,
##    at most SKIRT_GRAVITY_MAX_DEG, so the skirt never goes horizontal with the pelvis;
##  - front: flexion at least the thigh's (it lies on a raised thigh), with a gain ramping
##    from SKIRT_FRONT_GAIN.x to .y over 0..z degrees of thigh flexion (the bind gap to the
##    thigh: the front does not bell forward over a slightly bent leg); it follows the
##    thigh's abduction while the thigh holds it up;
##  - back: flexion at most the thigh's + SKIRT_REAR_CLEAR_DEG (a thigh going back pushes
##    it back; lying face down it rests on the back of the thighs), SKIRT_REAR_ABD of the
##    thigh's abduction while pushed;
##  - side: halfway between front and back (the cloth joins them), turned SKIRT_SIDE_GRAVITY
##    of the way to its gravity target (within the front..back range), pushed out by the
##    thigh's abduction beyond SKIRT_SIDE_CLEAR_DEG.
## Then the floor: when a panel's hem (SKIRT_HEMS, bind skeleton space, left leg; x mirrored
## for the right) would be lower than SKIRT_FLOOR_MARGIN above the lowest foot, the panel
## swings away from world-down about the hip joint until it is not (at most
## SKIRT_FLOOR_MAX_DEG): in a deep squat the tails flare back and rest behind the heels.
## Only while the pelvis is upright (SKIRT_FLOOR_TILT_DEG).
## tools/character/build_body.py mirrors these constants (json "helpers" -> "skirt").
const SKIRT_HEMS := [Vector3(0.12, 0.585, 0.145), Vector3(0.24, 0.555, -0.01), Vector3(0.12, 0.525, -0.18)]
const SKIRT_GRAVITY_MAX_DEG := 60.0
const SKIRT_FRONT_GAIN := Vector3(0.6, 1.0, 60.0)
const SKIRT_REAR_CLEAR_DEG := 6.0
const SKIRT_REAR_ABD := 0.5
const SKIRT_SIDE_CLEAR_DEG := 4.0
const SKIRT_SIDE_GRAVITY := 0.5
const SKIRT_FLOOR_MARGIN := 0.03
const SKIRT_FLOOR_MAX_DEG := 70.0
## The floor lift fades out as the pelvis tilts from x to y degrees off upright (lying).
const SKIRT_FLOOR_TILT_DEG := Vector2(35.0, 60.0)
## Foot joints for the floor height (their bind height is their height above the sole).
const SKIRT_FEET := ["l_heel", "l_ball", "r_heel", "r_ball"]
## The twist angles are wrapped into [center - 180, center + 180) degrees (left arm; the
## right arm mirrored). The centers keep every measured game pose away from the wrap,
## where the fractional twist bones would flip: over all 2490 clips (8 samples each) the
## upper-arm twist lies in about [-180, 140] and the forearm roll in about [-165, 175]
## with almost all samples in [-150, 130].
const UPPER_ARM_TWIST_CENTER_DEG := -35.0
const FOREARM_TWIST_CENTER_DEG := -25.0
## Hair queue: a pendulum on an unused root-level rig bone. Its root (the ribbon wrap at the
## nape, QUEUE_ROOT in bind skeleton space) is carried by headb. It hangs along the torso's
## down direction (spined) turned QUEUE_GRAVITY of the way toward world-down, but never
## forward of the torso's down direction (into the neck and collar) and at most
## QUEUE_SIDE_MAX_DEG to the side of it (over the collar); its twist is the torso's.
const QUEUE_HELPER := "wrinklemaps"
const QUEUE_GRAVITY := 0.6
const QUEUE_SIDE_MAX_DEG := 25.0
const QUEUE_ROOT := Vector3(0.0, 1.428, -0.072)

var skeleton: Skeleton3D
var meshes: Array[MeshInstance3D] = []
## Build stats: bind_source ("null-add" / "glb"), binds, missing (bone names),
## max_bind_diff (vs the glb binds), meshes, tris, helpers (driven bones).
var report := {}

## Parts added by attach_parts() / add_part(): tag -> Array of MeshInstance3D.
var parts := {}
## Skirt hems of a garment worn over the legacy coat (set_skirt_hems); empty = SKIRT_HEMS.
var skirt_hems: Array = []

## Bind globals (skeleton space) of the bones the skin uses: bone index -> Transform3D.
var _bind := {}
## null-add globals of the skeleton (bind_pose_globals), computed once per body.
var _bind_g: Array = []
var _bind_clip: Animation = null
## Rebuilt Skins by joint-name list (shared between parts).
var _skins_by_joints := {}
## One Dictionary per driven helper: bone, kind, a, b, sign (side), bind (its bind global),
## parent / child / joint (reference bones), axis (bind-space limb axis), center (twist
## wrap), panel / hem (skirt).
var _drivers: Array = []
## Foot joints (bone indices) for the skirt's floor height.
var _feet := PackedInt32Array()

## Soft tissue (body v4, 2026-09-28): each breast on the rig's own breast bone (l_breast / r_breast,
## a child of spined; tools/character/lib/helpers BREAST_BONES), a damped spring in the chest's bind
## frame driven by the chest's acceleration: it lags as the chest moves (the bounce of a run, a
## landing, a turn) and settles. `soft_tissue` (0..1+) scales the offset: BodyMaterials sets it from
## the build (a man's chest barely moves) and the bust (a fuller one moves more). `soft_support`
## (0..1) is what the clothes hold (the user: "clothes more stiff, no clothes less stiff"): bare (0)
## the spring is soft and bounces, a garment over the chest (a shift, a bodice: 1) makes it stiff,
## near critically damped and small (SOFT_HELD of the bare offset).
const BREAST_BONES := ["l_breast", "r_breast"]
const BREAST_STIFFNESS := Vector2(350.0, 1400.0)  # 1/s^2, bare / held (about 3 / 6 Hz)
const BREAST_DAMPING := Vector2(10.0, 45.0)       # 1/s, bare (a bounce that settles) / held (hardly any)
const BREAST_MAX := 0.04            # m: the shown offset approaches this softly (tanh); the state is held within 2x
const BREAST_ACCEL_MAX := 40.0      # m/s^2: a teleport or a cut is not a jolt
const SOFT_HELD := 0.5
const SOFT_SUBSTEP := 1.0 / 120.0   # s: the springs' longest step
## The male genitals (body v4): on an unused rig bone (GENITAL_HELPER: keyed by the clips, no mesh
## used it; like the queue's wrinklemaps), always carried by the pelvis. Bare (`genital_swing` 1:
## BodyMaterials, a man with nothing over the pelvis) they bounce on a small spring (the offset, pelvis
## bind frame, GENITAL_BOUNCE_MAX) and swing as a pendulum about their root (GENITAL_ROOT, bind
## skeleton space; the tip GENITAL_TIP), both driven by the tip's acceleration; covered (0) they stay
## still. tools/character/lib/helpers.py GENITAL_* writes the same values into body.json
## (helpers.genital), check_body_attach.gd compares.
const GENITAL_HELPER := "spinea_muscle"
const GENITAL_ROOT := Vector3(0.0, 0.787, 0.08)
const GENITAL_TIP := Vector3(0.0, 0.736, 0.128)
const GENITAL_STIFFNESS := Vector2(900.0, 220.0)  # 1/s^2: the bounce (offset), the swing (angle)
const GENITAL_DAMPING := Vector2(30.0, 12.0)      # 1/s
const GENITAL_BOUNCE_MAX := 0.012                 # m (tanh soft limit)
const GENITAL_SWING_MAX := 0.5                    # rad (tanh soft limit)
var soft_tissue := 1.0
var soft_support := 0.0
var genital_swing := 0.0
## > 0: the springs take this step (s) per update instead of the clock's (tools and tests stepping
## a clip frame by frame).
var soft_step := 0.0
## One Dictionary per breast: bone, x / v (the spring's offset and velocity, chest bind frame), pp / pv
## (the anchor's last world position and velocity), n (steps taken).
var _breasts: Array = []
var _chest := -1
var _soft_usec := 0
## The genitals: {bone, x / v (bounce), a / w (swing: rotation vector, pelvis bind frame, and its rate),
## pp / pv, n}; empty when the skin does not bind GENITAL_HELPER.
var _genital := {}
var _pelvis := -1


## Adds the body to `sk` and returns it, or null (with a warning) when the asset is
## missing or has no meshes. `ap` is the AnimationPlayer that holds `library`; without
## it (or without the bind clip) the glb's own binds are used.
static func attach(sk: Skeleton3D, ap: AnimationPlayer = null, path := DEFAULT_PATH,
		library := LIBRARY) -> CharacterBodyMesh:
	if sk == null or path.is_empty() or not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		push_warning("CharacterBodyMesh: %s is not a scene." % path)
		return null
	var clip := _bind_clip_of(ap, library)
	var body := CharacterBodyMesh.new()
	body.name = "Body"
	if not body.build(sk, scene, clip):
		body.free()
		return null
	sk.add_child(body)
	return body


## Instantiates `scene` once, copies its meshes and rebinds their skins to `sk`. Call
## before adding this node to the tree (attach() does both).
func build(sk: Skeleton3D, scene: PackedScene, bind_clip: Animation) -> bool:
	_begin(sk, bind_clip)
	_add_scene(scene, "")
	if meshes.is_empty():
		push_warning("CharacterBodyMesh: the body scene has no meshes.")
		return false
	_finish()
	return true


## Like attach() with several glbs: {tag: path}. Parts whose glb is missing are skipped
## with a warning; returns null when no part has meshes.
static func attach_parts(sk: Skeleton3D, ap: AnimationPlayer, paths: Dictionary,
		library := LIBRARY) -> CharacterBodyMesh:
	if sk == null:
		return null
	var body := CharacterBodyMesh.new()
	body.name = "Body"
	body._begin(sk, _bind_clip_of(ap, library))
	for tag: String in paths:
		var scene := _load_scene(String(paths[tag]))
		if scene != null:
			body._add_scene(scene, tag)
	if body.meshes.is_empty():
		body.free()
		return null
	body._finish()
	sk.add_child(body)
	return body


## Adds (or replaces) the part `tag` from a glb path or PackedScene. Returns its meshes.
func add_part(tag: String, source) -> Array:
	remove_part(tag)
	var scene: PackedScene = source if source is PackedScene else _load_scene(String(source))
	if scene == null:
		return []
	var n0 := meshes.size()
	_add_scene(scene, tag)
	_finish()
	return meshes.slice(n0)


## Removes the part `tag` (its meshes are freed).
func remove_part(tag: String) -> void:
	if not parts.has(tag):
		return
	for mi: MeshInstance3D in parts[tag]:
		meshes.erase(mi)
		if is_instance_valid(mi):
			mi.queue_free()
	parts.erase(tag)


func part_meshes(tag: String) -> Array:
	return parts.get(tag, [])


## Sets the blend shape `shape` (e.g. "sex", "face_long") on every mesh that has it.
## Returns the number of meshes changed.
func set_blend_shape(shape: String, value: float) -> int:
	var n := 0
	for mi in meshes:
		if not is_instance_valid(mi) or mi.mesh == null:
			continue
		var i := mi.find_blend_shape_by_name(shape)
		if i >= 0:
			mi.set_blend_shape_value(i, value)
			n += 1
	return n


static func _bind_clip_of(ap: AnimationPlayer, library: StringName) -> Animation:
	if ap != null and ap.has_animation_library(library):
		var lib := ap.get_animation_library(library)
		if lib.has_animation(BIND_CLIP):
			return lib.get_animation(BIND_CLIP)
	return null


static func _load_scene(path: String) -> PackedScene:
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("CharacterBodyMesh: part %s is missing." % path)
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		push_warning("CharacterBodyMesh: %s is not a scene." % path)
	return scene


func _begin(sk: Skeleton3D, bind_clip: Animation) -> void:
	skeleton = sk
	_bind_clip = bind_clip
	_bind_g = bind_pose_globals(sk, bind_clip) if bind_clip else []
	report = {"bind_source": String(BIND_CLIP) if bind_clip else "glb", "binds": 0,
			"missing": [], "max_bind_diff": 0.0, "meshes": 0, "tris": 0, "helpers": 0, "skins": 0}
	if bind_clip == null:
		push_warning("CharacterBodyMesh: no '%s' clip; using the binds stored in the glb." % BIND_CLIP)


func _finish() -> void:
	if report.max_bind_diff > BIND_WARN_TOL:
		push_warning("CharacterBodyMesh: binds from '%s' differ from the glb's by %.4f; rebuild the body (tools/character/build_body.sh) if the rig changed." % [BIND_CLIP, report.max_bind_diff])
	_setup_drivers()
	report.helpers = _drivers.size()


## Copies the meshes of `scene` under this node with rebound (shared) Skins.
func _add_scene(scene: PackedScene, tag: String) -> void:
	var tmp := scene.instantiate()
	var sources := tmp.find_children("*", "MeshInstance3D", true, false)
	var added: Array = []
	for n in sources:
		var src := n as MeshInstance3D
		if src.mesh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = src.name if tag.is_empty() else "%s_%s" % [tag, src.name]
		mi.mesh = src.mesh
		mi.cast_shadow = src.cast_shadow
		for i in src.get_surface_override_material_count():
			mi.set_surface_override_material(i, src.get_surface_override_material(i))
		_use_vertex_colors(mi)
		if src.skin:
			var glb_sk := src.get_node_or_null(src.skeleton) as Skeleton3D
			var key := _joint_key(src.skin, glb_sk)
			if not _skins_by_joints.has(key):
				_skins_by_joints[key] = _rebind(src.skin, glb_sk, _bind_g)
				report.skins += 1
			mi.skin = _skins_by_joints[key]
		else:
			push_warning("CharacterBodyMesh: mesh '%s' has no skin; it will not follow the bones." % src.name)
		# This node sits under the Skeleton3D with an identity transform (the default
		# skeleton path is empty in Godot 4.7, which leaves the mesh unskinned).
		mi.skeleton = NodePath("../..")
		add_child(mi)
		meshes.append(mi)
		added.append(mi)
		report.meshes += 1
		for s in src.mesh.get_surface_count():
			report.tris += _surface_tris(src.mesh, s)
	tmp.free()
	if not tag.is_empty():
		parts[tag] = added


## Identity of a skin's bind list (bone names in bind order, and the bind poses): parts
## with the same key share one rebuilt Skin.
static func _joint_key(sk: Skin, glb_sk: Skeleton3D) -> String:
	var names := PackedStringArray()
	for i in sk.get_bind_count():
		var bn := String(sk.get_bind_name(i))
		if bn.is_empty() and glb_sk and sk.get_bind_bone(i) >= 0:
			bn = glb_sk.get_bone_name(sk.get_bind_bone(i))
		names.append(bn)
	return ",".join(names)


## glTF multiplies the base colour by COLOR_0 (the coat's shading: darker lining, hem,
## vent and cuffs), but the importer does not flag every material for it. Surfaces with
## vertex colours get a copy of their material that uses them.
static func _use_vertex_colors(mi: MeshInstance3D) -> void:
	for s in mi.mesh.get_surface_count():
		if not (mi.mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_COLOR):
			continue
		var mat := mi.get_active_material(s) as BaseMaterial3D
		if mat and not mat.vertex_color_use_as_albedo:
			mat = mat.duplicate() as BaseMaterial3D
			mat.vertex_color_use_as_albedo = true
			mi.set_surface_override_material(s, mat)


## Skin with the same bind order as `src` (mesh bone indices refer to it), each bind
## resolved by name to a bone of `skeleton`, with inverse bind = bind_g[bone]^-1.
func _rebind(src: Skin, glb_sk: Skeleton3D, bind_g: Array) -> Skin:
	var out := Skin.new()
	for i in src.get_bind_count():
		var bone_name := String(src.get_bind_name(i))
		if bone_name.is_empty() and glb_sk and src.get_bind_bone(i) >= 0:
			bone_name = glb_sk.get_bone_name(src.get_bind_bone(i))
		var bone := skeleton.find_bone(bone_name)
		var pose := src.get_bind_pose(i)
		if bone < 0:
			# Rigid on the nearest ancestor that exists. The glb rig's rest is the bind
			# pose, so its global rest is the ancestor's bind when there is no clip.
			report.missing.append(bone_name)
			var anc := _nearest_existing_ancestor(bone_name, glb_sk)
			bone = anc[0] if not anc.is_empty() else 0
			if not bind_g.is_empty():
				pose = (bind_g[bone] as Transform3D).orthonormalized().affine_inverse()
			elif not anc.is_empty():
				pose = glb_sk.get_bone_global_rest(anc[1]).affine_inverse()
			push_warning("CharacterBodyMesh: bone '%s' is not in the skeleton; bound rigidly to '%s'." % [bone_name, skeleton.get_bone_name(bone)])
		else:
			if not bind_g.is_empty():
				var want := (bind_g[bone] as Transform3D).orthonormalized().affine_inverse()
				report.max_bind_diff = maxf(report.max_bind_diff, xform_diff(want, pose))
				pose = want
			# The helper driver works in the same bind space as the skin.
			_bind[bone] = pose.affine_inverse()
		out.add_bind(bone, pose)
		report.binds += 1
	return out


## [skeleton bone, glb bone] of the nearest ancestor (in the glb rig) of `bone_name`
## that also exists in `skeleton`, or [] when there is none.
func _nearest_existing_ancestor(bone_name: String, glb_sk: Skeleton3D) -> Array:
	if glb_sk == null:
		return []
	var b := glb_sk.get_bone_parent(glb_sk.find_bone(bone_name)) if glb_sk.find_bone(bone_name) >= 0 else -1
	while b >= 0:
		var mine := skeleton.find_bone(glb_sk.get_bone_name(b))
		if mine >= 0:
			return [mine, b]
		b = glb_sk.get_bone_parent(b)
	return []


## Skeleton-space global transform of every bone of `sk` in the pose `clip` holds at
## t = 0. Channels the clip does not key use the rest, as the AnimationMixer does.
static func bind_pose_globals(sk: Skeleton3D, clip: Animation) -> Array[Transform3D]:
	var n := sk.get_bone_count()
	var pos := PackedVector3Array()
	var scl := PackedVector3Array()
	var rot: Array[Quaternion] = []
	for b in n:
		var r := sk.get_bone_rest(b)
		pos.append(r.origin)
		rot.append(r.basis.get_rotation_quaternion())
		scl.append(r.basis.get_scale())
	for t in clip.get_track_count():
		if not clip.track_is_enabled(t):
			continue
		var b := sk.find_bone(str(clip.track_get_path(t).get_concatenated_subnames()))
		if b < 0:
			continue
		match clip.track_get_type(t):
			Animation.TYPE_POSITION_3D:
				pos[b] = clip.position_track_interpolate(t, 0.0)
			Animation.TYPE_ROTATION_3D:
				rot[b] = clip.rotation_track_interpolate(t, 0.0).normalized()
			Animation.TYPE_SCALE_3D:
				scl[b] = clip.scale_track_interpolate(t, 0.0)
	var local: Array[Transform3D] = []
	for b in n:
		local.append(Transform3D(Basis(rot[b]) * Basis.from_scale(scl[b]), pos[b]))
	# Parents before children, whatever the bone order.
	var g: Array[Transform3D] = []
	g.resize(n)
	var stack := Array(sk.get_parentless_bones())
	for b: int in stack:
		g[b] = local[b]
	while not stack.is_empty():
		var p: int = stack.pop_back()
		for c in sk.get_bone_children(p):
			g[c] = g[p] * local[c]
			stack.append(c)
	return g


## Largest difference between two transforms (per basis column / origin, in metres).
static func xform_diff(a: Transform3D, b: Transform3D) -> float:
	var d := (a.origin - b.origin).length()
	for c in 3:
		d = maxf(d, (a.basis[c] - b.basis[c]).length())
	return d


static func _surface_tris(mesh: Mesh, s: int) -> int:
	var am := mesh as ArrayMesh
	if am == null:
		return 0
	var idx := am.surface_get_array_index_len(s)
	return (idx if idx > 0 else am.surface_get_array_len(s)) / 3


# --- Helper bone driver --------------------------------------------------------

## Resolves HELPERS against the skeleton. A helper is driven only when it and all its
## reference bones are bound by the skin (so they share its bind space).
func _setup_drivers() -> void:
	_drivers.clear()
	_breasts.clear()
	_chest = skeleton.find_bone("spined")
	for bn: String in BREAST_BONES:
		var bb := skeleton.find_bone(bn)
		if bb >= 0 and _bind.has(bb) and _bind.has(_chest):
			_breasts.append({"bone": bb, "x": Vector3.ZERO, "v": Vector3.ZERO, "pp": Vector3.ZERO, "pv": Vector3.ZERO, "n": 0})
	_genital = {}
	_pelvis = skeleton.find_bone("pelvis")
	var gb := skeleton.find_bone(GENITAL_HELPER)
	if gb >= 0 and _bind.has(gb) and _bind.has(_pelvis):
		_genital = {"bone": gb, "x": Vector3.ZERO, "v": Vector3.ZERO, "a": Vector3.ZERO, "w": Vector3.ZERO,
				"pp": Vector3.ZERO, "pv": Vector3.ZERO, "n": 0}
	_feet = PackedInt32Array()
	for f: String in SKIRT_FEET:
		var fb := skeleton.find_bone(f)
		if fb >= 0 and _bind.has(fb):
			_feet.append(fb)
	for side in ["l", "r"]:
		var sg := 1.0 if side == "l" else -1.0
		var refs := {}
		for r in ["clavicle", "shoulder", "elbow", "wrist", "upper_leg", "knee"]:
			refs[r] = skeleton.find_bone(side + "_" + r)
		refs["pelvis"] = skeleton.find_bone("pelvis")
		for h: Array in HELPERS:
			var bone := skeleton.find_bone(side + "_" + String(h[0]))
			if bone < 0 or not _bind.has(bone):
				continue
			var need: Array = []
			match int(h[1]):
				Kind.UPPER_ARM:
					need = [refs.clavicle, refs.shoulder, refs.elbow]
				Kind.FOREARM:
					need = [refs.elbow, refs.wrist]
				Kind.SKIRT:
					need = [refs.pelvis, refs.upper_leg, refs.knee]
			if need.any(func(b: int) -> bool: return not _bind.has(b)):
				push_warning("CharacterBodyMesh: helper '%s_%s' is weighted but its reference bones are not bound; it stays at its rest." % [side, h[0]])
				continue
			var d := {"bone": bone, "kind": int(h[1]), "a": float(h[2]), "b": float(h[3]), "sign": sg,
					"bind": (_bind[bone] as Transform3D)}
			match d.kind:
				Kind.UPPER_ARM:
					d.parent = refs.clavicle
					d.joint = refs.shoulder
					d.axis = (_org(refs.elbow) - _org(refs.shoulder)).normalized()
					d.center = deg_to_rad(UPPER_ARM_TWIST_CENTER_DEG)
				Kind.FOREARM:
					d.parent = refs.elbow
					d.joint = refs.elbow
					d.child = refs.wrist
					d.axis = (_org(refs.wrist) - _org(refs.elbow)).normalized()
					d.center = deg_to_rad(FOREARM_TWIST_CENTER_DEG)
				Kind.SKIRT:
					d.parent = refs.pelvis
					d.joint = refs.upper_leg
					d.axis = (_org(refs.knee) - _org(refs.upper_leg)).normalized()
					d.panel = int(h[2])
					var hem: Vector3 = _hem(d.panel)
					d.hem = Vector3(hem.x * sg, hem.y, hem.z)
			if d.kind == Kind.UPPER_ARM:
				d.child = refs.shoulder
			elif d.kind == Kind.SKIRT:
				d.child = refs.upper_leg
			_drivers.append(d)
	var qb := skeleton.find_bone(QUEUE_HELPER)
	var spined := skeleton.find_bone("spined")
	var headb := skeleton.find_bone("headb")
	if qb >= 0 and _bind.has(qb) and _bind.has(spined) and _bind.has(headb):
		_drivers.append({"bone": qb, "kind": Kind.QUEUE, "a": QUEUE_GRAVITY, "b": 0.0, "sign": 1.0,
				"bind": (_bind[qb] as Transform3D), "parent": spined, "child": headb, "joint": headb,
				"axis": Vector3.UP})


## The skirt panels' hems (SKIRT_HEMS layout) of the longest coat worn over the legacy one
## (PlayerOutfit: a catalog garment's skirt.hems_godot); empty = SKIRT_HEMS. Only the floor lift
## reads them: a longer skirt lifts off the floor earlier in a squat.
func set_skirt_hems(hems: Array) -> void:
	skirt_hems = hems.duplicate() if hems.size() == 3 else []
	for d: Dictionary in _drivers:
		if int(d.kind) == Kind.SKIRT:
			var hem := _hem(int(d.panel))
			d.hem = Vector3(hem.x * float(d.sign), hem.y, hem.z)


func _hem(panel: int) -> Vector3:
	return skirt_hems[panel] if skirt_hems.size() == 3 else SKIRT_HEMS[panel]


func _org(bone: int) -> Vector3:
	return (_bind[bone] as Transform3D).origin


## Skinning transform (bind space -> posed skeleton space) of `bone` for the globals `g`.
func _skinning(g: Array, bone: int) -> Transform3D:
	return (g[bone] as Transform3D) * (_bind[bone] as Transform3D).affine_inverse()


## Global poses of the driven helper bones for the bone globals `g` (skeleton space,
## indexed by bone; the skirt also reads SKIRT_FEET). `down` is world-down in skeleton
## space. Returns [bone indices, transforms]. With an Array `diag`, one Dictionary per skirt
## panel is appended for the checks: bone, panel, hang (its hang direction's angle to
## world-down), pushed (the thigh holds it away from its gravity target), floored (the floor
## lifts it).
func _drive(g: Array, down := Vector3.DOWN, diag = null) -> Array:
	var bones := PackedInt32Array()
	var out: Array[Transform3D] = []
	var floor_h := -INF
	if not _feet.is_empty():
		floor_h = INF
		for f in _feet:
			floor_h = minf(floor_h, -(g[f] as Transform3D).origin.dot(down) - _org(f).y)
	for d: Dictionary in _drivers:
		var mp := _skinning(g, d.parent)
		var qp := mp.basis.get_rotation_quaternion()
		var qc := _skinning(g, d.child).basis.get_rotation_quaternion()
		var rel := (qp.inverse() * qc).normalized()
		var axis: Vector3 = d.axis
		var r := Quaternion.IDENTITY
		# Rotation `r` about the joint (bind position jb -> posed position jp).
		var jb: Vector3 = _org(d.joint)
		var jp := (g[d.joint] as Transform3D).origin
		match int(d.kind):
			Kind.UPPER_ARM:
				var tw := _twist(rel, axis, d.sign, d.center)
				var swing := rel * Quaternion(axis, tw).inverse()
				r = qp * Quaternion.IDENTITY.slerp(swing, float(d.a)) * Quaternion(axis, tw * float(d.b))
			Kind.FOREARM:
				r = qp * Quaternion(axis, _twist(rel, axis, d.sign, d.center) * float(d.a))
			Kind.SKIRT:
				r = _skirt(d, qp, rel, down, jb, jp, floor_h, diag)
			Kind.QUEUE:
				r = _queue(qp, down)
				jb = QUEUE_ROOT
				jp = _skinning(g, d.child) * QUEUE_ROOT
		var rb := Basis(r.normalized())
		var m := Transform3D(rb, jp - rb * jb)
		bones.append(d.bone)
		out.append(m * (d.bind as Transform3D))
	return [bones, out]


## Rotation (bind -> posed skeleton space) of a skirt panel. `qp`: the pelvis's skinning
## rotation, `rel`: the thigh's relative to it. See SKIRT_HEMS for the rules.
func _skirt(d: Dictionary, qp: Quaternion, rel: Quaternion, down: Vector3, jb: Vector3, jp: Vector3,
		floor_h: float, diag) -> Quaternion:
	var fx := Vector3(-1, 0, 0)                 # flexion axis: down toward +Z (forward)
	var ax := Vector3(0, 0, float(d.sign))      # abduction axis: down toward outward
	var axis: Vector3 = d.axis
	# The thigh's swing in the pelvis frame as a rotation vector.
	var tv := _rotvec(Quaternion(axis, (rel * axis).normalized()))
	var tf := tv.dot(fx)
	var ta := tv.dot(ax)
	# Gravity: bind hang direction (down) -> world-down, in the pelvis frame, limited.
	var dl := (qp.inverse() * down).normalized()
	var gv := _rotvec(Quaternion(Vector3.DOWN, dl)) if dl.dot(Vector3.DOWN) > -0.9999 else fx * PI
	var gmax := deg_to_rad(SKIRT_GRAVITY_MAX_DEG)
	if gv.length() > gmax:
		gv *= gmax / gv.length()
	var gf := gv.dot(fx)
	var ga := gv.dot(ax)
	var push := deg_to_rad(15.0)
	# front: lies on a raised thigh
	var lo := tf
	if tf > 0.0:
		lo = tf * lerpf(SKIRT_FRONT_GAIN.x, SKIRT_FRONT_GAIN.y, smoothstep(0.0, deg_to_rad(SKIRT_FRONT_GAIN.z), tf))
	var ff := maxf(gf, lo)
	var fa := lerpf(ga, ta, smoothstep(0.0, push, lo - gf))
	# back: pushed back by a thigh going back
	var hi := tf + deg_to_rad(SKIRT_REAR_CLEAR_DEG)
	var bf := minf(gf, hi)
	var ba := lerpf(ga, ta * SKIRT_REAR_ABD, smoothstep(0.0, push, gf - hi))
	var pf: float
	var pa: float
	var pushed := false
	match int(d.panel):
		0:
			pf = ff
			pa = fa
			pushed = lo > gf
		2:
			pf = bf
			pa = ba
			pushed = gf > hi
		_:
			# between front and back (the cloth joins them), leaning to gravity
			var mid := 0.5 * (ff + bf)
			pf = lerpf(mid, clampf(gf, minf(ff, bf), maxf(ff, bf)), SKIRT_SIDE_GRAVITY)
			pa = maxf(0.5 * (fa + ba), ta - deg_to_rad(SKIRT_SIDE_CLEAR_DEG))
			pushed = absf(pf - gf) > 1e-4 or pa > 0.5 * (fa + ba)
	var rv := fx * pf + ax * pa
	var r := qp * (Quaternion(rv.normalized(), rv.length()) if rv.length() > 1e-9 else Quaternion.IDENTITY)
	# Floor: swing the panel up (front / back: about the pelvis's lateral axis, side:
	# outward about its forward axis) until the hem is above the lowest foot.
	# Only while the pelvis is upright (a squat); lying down the hem cannot clear the
	# floor anyway, and lifting the panels there only tears the skirt apart.
	var floored := false
	var u := qp * (Vector3(1, 0, 0) if int(d.panel) != 1 else Vector3(0, 0, 1))
	var upright := 1.0 - smoothstep(deg_to_rad(SKIRT_FLOOR_TILT_DEG.x), deg_to_rad(SKIRT_FLOOR_TILT_DEG.y),
			(qp * Vector3.UP).angle_to(-down))
	var lift := upright * _lift(r * ((d.hem as Vector3) - jb), u.normalized(), -down,
			floor_h + SKIRT_FLOOR_MARGIN + jp.dot(down), deg_to_rad(SKIRT_FLOOR_MAX_DEG))
	if lift != 0.0:
		r = Quaternion(u.normalized(), lift) * r
		floored = true
	if diag is Array:
		(diag as Array).append({"bone": d.bone, "panel": d.panel, "pushed": pushed, "floored": floored,
				"hang": rad_to_deg((r * Vector3.DOWN).angle_to(down))})
	return r


## Smallest rotation angle about the unit axis `u`, in the direction that raises `v`
## along `up` at first, that brings v's height (v . up) to at least `need`; at most `limit`
## (and the highest reachable when `need` cannot be reached). 0 when v is high enough.
static func _lift(v: Vector3, u: Vector3, up: Vector3, need: float, limit: float) -> float:
	var par := u * v.dot(u)
	var perp := v - par
	var base := par.dot(up)
	var a := perp.dot(up)
	var b := u.cross(perp).dot(up)
	if a >= need - base:
		return 0.0
	var sg := 1.0 if b >= 0.0 else -1.0
	var rr := sqrt(a * a + b * b)
	if rr < 1e-9:
		return 0.0
	var t0 := atan2(absf(b), a)                  # angle of the highest point, in (0, pi]
	var c := (need - base) / rr
	var t := t0 if c >= 1.0 else maxf(t0 - acos(clampf(c, -1.0, 1.0)), 0.0)
	return sg * minf(t, limit)


## Rotation (bind -> posed skeleton space) of the hair queue for the torso's (spined)
## skinning rotation `qs`: see QUEUE_GRAVITY.
func _queue(qs: Quaternion, down: Vector3) -> Quaternion:
	var td := qs * Vector3.DOWN
	var h := (td * (1.0 - QUEUE_GRAVITY) + down * QUEUE_GRAVITY)
	h = h.normalized() if h.length() > 1e-6 else td
	var fwd := qs * Vector3(0, 0, 1)
	var f := h.dot(fwd)
	if f > 0.0:
		h = (h - fwd * f).normalized()      # never forward of the torso's down (into the neck)
	var right := qs * Vector3(1, 0, 0)
	var sd := h.dot(right)
	var sm := sin(deg_to_rad(QUEUE_SIDE_MAX_DEG))
	if absf(sd) > sm:
		h = (h - right * (sd - signf(sd) * sm)).normalized()
	return (Quaternion(td, h) * qs) if td.dot(h) > -0.9999 else qs


## Twist of `q` about `axis` in radians, wrapped around `center` (left-side convention;
## `sign` = -1 mirrors it for the right side).
static func _twist(q: Quaternion, axis: Vector3, sign: float, center: float) -> float:
	var a := 2.0 * atan2(Vector3(q.x, q.y, q.z).dot(axis), q.w)
	return wrapf(a * sign, center - PI, center + PI) * sign


## Rotation vector (axis * angle) of a unit quaternion, angle in [0, pi].
static func _rotvec(q: Quaternion) -> Vector3:
	if q.w < 0.0:
		q = -q
	var v := Vector3(q.x, q.y, q.z)
	var s := v.length()
	if s < 1e-9:
		return v * 2.0
	return v * (2.0 * atan2(s, q.w) / s)


## Bone globals of the skeleton's current (animated) pose with the helper bones driven:
## what the skin shows. For CPU skinning in tools and tests; the live update uses the
## same code in _process_modification().
func skinning_globals() -> Array[Transform3D]:
	var g: Array[Transform3D] = []
	for b in skeleton.get_bone_count():
		g.append(skeleton.get_bone_global_pose(b))
	var down := Vector3.DOWN
	if skeleton.is_inside_tree():
		down = skeleton.global_basis.orthonormalized().inverse() * Vector3.DOWN
	var res := _drive(g, down)
	for i in (res[0] as PackedInt32Array).size():
		g[res[0][i]] = res[1][i]
	for d: Dictionary in _breasts:
		g[d.bone] = _breast_global(g[_chest], d)
	if not _genital.is_empty():
		g[_genital.bone] = _genital_global(g[_pelvis])
	return g


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	_soft(sk)
	if _drivers.is_empty():
		return
	var g := []
	g.resize(sk.get_bone_count())
	for d: Dictionary in _drivers:
		for k in ["parent", "child", "joint"]:
			var b: int = d[k]
			if g[b] == null:
				g[b] = sk.get_bone_global_pose(b)
	for f in _feet:
		if g[f] == null:
			g[f] = sk.get_bone_global_pose(f)
	var res := _drive(g, sk.global_basis.orthonormalized().inverse() * Vector3.DOWN)
	var bones: PackedInt32Array = res[0]
	for i in bones.size():
		sk.set_bone_global_pose(bones[i], res[1][i])


## The soft tissue springs: one step (the time since the last) and the breast and genital bones' poses.
func _soft(sk: Skeleton3D) -> void:
	if _breasts.is_empty() and _genital.is_empty():
		return
	var now := Time.get_ticks_usec()
	var dt := clampf(float(now - _soft_usec) / 1e6, 0.0, 0.05) if _soft_usec > 0 else 0.0
	_soft_usec = now
	if soft_step > 0.0:
		dt = soft_step
	if not _genital.is_empty():
		_genital_step(sk, dt)
	if _breasts.is_empty():
		return
	var gc := sk.get_bone_global_pose(_chest)
	var world := sk.global_transform * gc * (_bind[_chest] as Transform3D).affine_inverse()
	var to_local := world.basis.orthonormalized().inverse()
	var held := clampf(soft_support, 0.0, 1.0)
	var k := lerpf(BREAST_STIFFNESS.x, BREAST_STIFFNESS.y, held)
	var c := lerpf(BREAST_DAMPING.x, BREAST_DAMPING.y, held)
	for d: Dictionary in _breasts:
		var p: Vector3 = world * (_bind[d.bone] as Transform3D).origin
		if dt > 0.0:
			var vel := (p - (d.pp as Vector3)) / dt
			if int(d.n) >= 2:
				var acc := (vel - (d.pv as Vector3)) / dt
				if acc.length() > BREAST_ACCEL_MAX:
					acc = acc.normalized() * BREAST_ACCEL_MAX
				var xv := _spring(d.x, d.v, k, c, -(to_local * acc), dt)
				d.x = xv[0]
				d.v = xv[1]
				if (d.x as Vector3).length() > 2.0 * BREAST_MAX:
					d.x = (d.x as Vector3).normalized() * 2.0 * BREAST_MAX
					d.v = (d.v as Vector3) * 0.5
			d.pv = vel
			d.n = int(d.n) + 1
		d.pp = p
		sk.set_bone_global_pose(d.bone, _breast_global(gc, d))


## A damped spring x'' = -k x - c x' + f over `dt`, in steps of at most SOFT_SUBSTEP (stable at any
## frame rate, however stiff). Returns [x, v].
static func _spring(x: Vector3, v: Vector3, k: float, c: float, f: Vector3, dt: float) -> Array:
	var n := maxi(1, ceili(dt / SOFT_SUBSTEP))
	var h := dt / n
	for i in n:
		v += (f - k * x - c * v) * h
		x += v * h
	return [x, v]


## The breast bone's global pose: carried by the chest, moved by the spring (scaled by soft_tissue,
## and by what the clothes hold).
func _breast_global(chest_global: Transform3D, d: Dictionary) -> Transform3D:
	var sc := chest_global * (_bind[_chest] as Transform3D).affine_inverse()
	var x: Vector3 = d.x
	var L := x.length()
	if L > 1e-6:
		x *= BREAST_MAX * tanh(L / BREAST_MAX) / L        # a soft limit, no hard stop
	var off: Vector3 = x * clampf(soft_tissue, 0.0, 1.5) * lerpf(1.0, SOFT_HELD, clampf(soft_support, 0.0, 1.0))
	return sc * Transform3D(Basis(), off) * (_bind[d.bone] as Transform3D)


## The genital springs, one step: the bounce (an offset, like a breast's) and the swing (a pendulum
## about GENITAL_ROOT: the tip's acceleration across the root -> tip arm turns it); both still (and
## at rest) while covered.
func _genital_step(sk: Skeleton3D, dt: float) -> void:
	var d := _genital
	var gp := sk.get_bone_global_pose(_pelvis)
	if genital_swing <= 0.0:
		d.x = Vector3.ZERO
		d.v = Vector3.ZERO
		d.a = Vector3.ZERO
		d.w = Vector3.ZERO
		d.n = 0
		sk.set_bone_global_pose(d.bone, _genital_global(gp))
		return
	var world := sk.global_transform * gp * (_bind[_pelvis] as Transform3D).affine_inverse()
	var to_local := world.basis.orthonormalized().inverse()
	var p: Vector3 = world * GENITAL_TIP
	if dt > 0.0:
		var vel := (p - (d.pp as Vector3)) / dt
		if int(d.n) >= 2:
			var acc: Vector3 = to_local * ((vel - (d.pv as Vector3)) / dt)
			if acc.length() > BREAST_ACCEL_MAX:
				acc = acc.normalized() * BREAST_ACCEL_MAX
			var xv := _spring(d.x, d.v, GENITAL_STIFFNESS.x, GENITAL_DAMPING.x, -acc, dt)
			d.x = xv[0]
			d.v = xv[1]
			var arm := GENITAL_TIP - GENITAL_ROOT
			var ax := arm.normalized()
			var alpha := arm.cross(-acc) / arm.length_squared()
			alpha -= ax * alpha.dot(ax)            # no twist about the arm
			var aw := _spring(d.a, d.w, GENITAL_STIFFNESS.y, GENITAL_DAMPING.y, alpha, dt)
			d.a = aw[0]
			d.w = aw[1]
			if (d.x as Vector3).length() > 2.0 * GENITAL_BOUNCE_MAX:
				d.x = (d.x as Vector3).normalized() * 2.0 * GENITAL_BOUNCE_MAX
				d.v = (d.v as Vector3) * 0.5
			if (d.a as Vector3).length() > 2.0 * GENITAL_SWING_MAX:
				d.a = (d.a as Vector3).normalized() * 2.0 * GENITAL_SWING_MAX
				d.w = (d.w as Vector3) * 0.5
		d.pv = vel
		d.n = int(d.n) + 1
	d.pp = p
	sk.set_bone_global_pose(d.bone, _genital_global(gp))


## The genital bone's global pose: carried by the pelvis, bounced and swung by the springs (scaled by
## genital_swing).
func _genital_global(pelvis_global: Transform3D) -> Transform3D:
	var d := _genital
	var sc := pelvis_global * (_bind[_pelvis] as Transform3D).affine_inverse()
	var s := clampf(genital_swing, 0.0, 1.0)
	var x: Vector3 = d.x
	var L := x.length()
	if L > 1e-6:
		x *= GENITAL_BOUNCE_MAX * tanh(L / GENITAL_BOUNCE_MAX) / L
	var a: Vector3 = d.a
	var A := a.length()
	var rot := Basis()
	if A > 1e-6 and s > 0.0:
		rot = Basis(a / A, GENITAL_SWING_MAX * tanh(A / GENITAL_SWING_MAX) * s)
	var swing := Transform3D(rot, GENITAL_ROOT - rot * GENITAL_ROOT)
	return sc * Transform3D(Basis(), x * s) * swing * (_bind[d.bone] as Transform3D)


func _enter_tree() -> void:
	var p := get_parent()
	if p and not p.child_entered_tree.is_connected(_on_sibling_entered):
		p.child_entered_tree.connect(_on_sibling_entered)
	_keep_last.call_deferred()


func _exit_tree() -> void:
	var p := get_parent()
	if p and p.child_entered_tree.is_connected(_on_sibling_entered):
		p.child_entered_tree.disconnect(_on_sibling_entered)


func _on_sibling_entered(n: Node) -> void:
	if n != self and n is SkeletonModifier3D:
		_keep_last.call_deferred()


## Modifiers run in child order: stay behind the others so the helpers follow the final
## pose (an aim stabiliser or IK added later would otherwise move the arm after them).
func _keep_last() -> void:
	var p := get_parent()
	if p == null or not is_inside_tree():
		return
	var last := p.get_child_count() - 1
	for i in range(last, -1, -1):
		if p.get_child(i) is SkeletonModifier3D:
			if p.get_child(i) != self:
				p.move_child(self, i)
			return
