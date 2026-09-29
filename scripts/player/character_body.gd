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
## A closed skirt (a petticoat; `skirt_closed`, PlayerOutfit sets it from the catalog's skirt.closed; the user
## 2026-09-29: "fix skirts from animations glitch out of the skirt", "it is like a bell that flies and looks too
## stiff", "maybe it should have like fluid properties in a confined space"). The six panels are one piece of cloth
## round both legs, not a coat's flaps on each thigh, and it flows inside set bounds:
##  - it hangs toward world-down (gravity about the hip joints, at most SKIRT_CLOSED_GRAVITY_MAX_DEG: bent over, it
##    falls from the hips);
##  - the legs are walls inside it: the knees, shins, heels and toes of BOTH legs within SKIRT_CLOSED_REACH_DEG of a
##    panel's place round the body push that panel's cloth out, SKIRT_CLOSED_CLEAR past them. Low on the legs (where
##    the skirt is all the panel's: its weights, SKIRT_CLOSED_SHARE_Y) the panel is moved out, not turned, so the
##    cloth below a knee hangs straight down instead of the hem swinging out; only a thigh raised high (a squat, a
##    seat) turns the panel up about the hip joint, at most SKIRT_CLOSED_MAX_DEG. A panel takes SKIRT_CLOSED_SPREAD of
##    its neighbours' push (the cloth between them), so the skirt gives round a knee instead of splitting;
##  - it flows: each panel's move out is a damped spring (SKIRT_CLOSED_SPRING) that a leg pushes at once and that falls
##    back softly, and the whole hem trails the hips as they speed up, slow and turn (their acceleration, the same
##    spring, at most SKIRT_CLOSED_SWAY_M); never further out than SKIRT_CLOSED_OUT_M;
##  - on the floor (a squat, sitting) it pools: a panel shortens to rest SKIRT_CLOSED_FLOOR_SINK into the ground (to
##    SKIRT_CLOSED_BUNCH at most), then swings out at most SKIRT_CLOSED_FLOOR_MAX_DEG; turned up above the level (knees
##    drawn up) it bunches the same way (SKIRT_CLOSED_BUNCH_DEG), so it lies over the knees instead of standing out.
## Its hems (bind skeleton space, left leg) default to SKIRT_CLOSED_HEMS (the petticoat's at the panels' places: 40,
## 90 and 140 degrees round from the front; tools/character/cloth2/skirt_hang.py prints them).
const SKIRT_CLOSED_HEMS := [Vector3(0.163, 0.26, 0.262), Vector3(0.255, 0.26, 0.066), Vector3(0.163, 0.26, -0.13)]
const SKIRT_CLOSED_SHARE_Y := Vector2(0.88, 0.62)
## The panels' places round the body in the skirt's weights (degrees from the front, left leg; skirt_hang.py PANELS),
## and the skirt's round at bind (skirt_hang.py prints it): its distance from the body's axis (m) at the heights
## SKIRT_CLOSED_ROUND_Y, each row every 30 degrees from the front (0) round to the back (180), the same both sides.
const SKIRT_CLOSED_PANEL_AZ := Vector3(40.0, 90.0, 140.0)
const SKIRT_CLOSED_ROUND_Y := [0.88, 0.8, 0.72, 0.64, 0.56, 0.48, 0.4, 0.33, 0.26]
const SKIRT_CLOSED_ROUND := [
	[0.143, 0.152, 0.176, 0.188, 0.172, 0.148, 0.128], [0.159, 0.166, 0.186, 0.205, 0.187, 0.167, 0.14],
	[0.175, 0.181, 0.2, 0.208, 0.19, 0.166, 0.144], [0.196, 0.202, 0.217, 0.221, 0.202, 0.171, 0.155],
	[0.222, 0.226, 0.236, 0.236, 0.216, 0.189, 0.173], [0.236, 0.238, 0.246, 0.244, 0.222, 0.198, 0.182],
	[0.252, 0.256, 0.258, 0.253, 0.23, 0.204, 0.193], [0.268, 0.269, 0.27, 0.264, 0.24, 0.214, 0.206],
	[0.284, 0.283, 0.282, 0.275, 0.253, 0.226, 0.221]]
## A raised thigh's turn reaches the neighbouring panels less than a push out does.
const SKIRT_CLOSED_TURN_SPREAD := 0.25
const SKIRT_CLOSED_CLEAR := 0.02
const SKIRT_CLOSED_REACH_DEG := Vector2(30.0, 75.0)
const SKIRT_CLOSED_SPREAD := 0.35
const SKIRT_CLOSED_MAX_DEG := 100.0
const SKIRT_CLOSED_GRAVITY_MAX_DEG := 110.0
const SKIRT_CLOSED_SPRING := Vector2(90.0, 11.0)    # 1/s^2 (about 1.5 Hz), 1/s (a little sway that settles)
const SKIRT_CLOSED_SWAY_M := 0.1
const SKIRT_CLOSED_OUT_M := 0.26
const SKIRT_CLOSED_FLOOR_MAX_DEG := 35.0
const SKIRT_CLOSED_FLOOR_SINK := 0.1
const SKIRT_CLOSED_BUNCH_DEG := Vector2(55.0, 100.0)
const SKIRT_CLOSED_BUNCH := 0.62
## Tucked up (`skirt_tuck` 1: climbing a ladder, a trunk, a giant; FrontierPlayer sets it; the user 2026-09-29: "for
## climbing and ladder ... the skirt rolls up at the front", "the front half is tucked in above the knee with physics
## but the back half is not rolled up", "maybe it has to roll up to the navel"): the front panels roll up to
## SKIRT_CLOSED_TUCK of their length and SKIRT_CLOSED_TUCK_LIFT_M up (gathered at the waist; what the pelvis holds of
## the cloth there stays), the sides half as much, the back not at all (panels front, side, back:
## SKIRT_CLOSED_TUCK_SHARE); the legs below a tucked hem no longer push it, and it flows as ever. The lift is along
## the pelvis's up, toward the waist. `skirt_tuck_back` rolls the back up the same way (on all fours in the crawl: up
## toward the lower back; the user 2026-09-29), the front not at all (SKIRT_CLOSED_TUCK_BACK_SHARE).
const SKIRT_CLOSED_TUCK := 0.08
const SKIRT_CLOSED_TUCK_LIFT_M := 0.14
const SKIRT_CLOSED_TUCK_SHARE := Vector3(1.0, 0.5, 0.0)
const SKIRT_CLOSED_TUCK_BACK_SHARE := Vector3(0.0, 0.5, 1.0)
## The leg joints that push a closed skirt (per side, "l_" / "r_"), plus points along the thigh and the shin, and how
## thick the leg is there (m from the bone: the cloth clears the leg's surface, not its bone).
const SKIRT_LEG_JOINTS := ["upper_leg", "knee", "ankle", "heel", "ball"]
const SKIRT_LEG_RADII := [0.0, 0.06, 0.04, 0.045, 0.035]
const SKIRT_THIGH_RADII := Vector2(0.085, 0.07)   # half and four fifths of the way to the knee
const SKIRT_SHIN_RADII := Vector2(0.055, 0.045)   # half and four fifths of the way to the ankle
## How far each of those points may push the cloth out (m): a heel kicked up behind in a run slips out under the hem
## instead of holding the back of the skirt out like a bustle.
const SKIRT_LEG_PUSH_M := [0.0, 1.0, 0.1, 0.05, 0.04]
const SKIRT_SHIN_PUSH_M := Vector2(0.2, 0.14)
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
## A closed skirt is worn (set_skirt_closed): the panels are driven as one (SKIRT_CLOSED_*).
var skirt_closed := false
## 0..1: how far a closed skirt is tucked up at the front, and at the back (SKIRT_CLOSED_TUCK).
var skirt_tuck := 0.0
var skirt_tuck_back := 0.0

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
## The leg joints (bone indices, SKIRT_LEG_JOINTS) of each leg, left then right, for a closed skirt.
var _legs: Array[PackedInt32Array] = []
var _leg_radii: Array[PackedFloat32Array] = []
var _leg_push: Array[PackedFloat32Array] = []
## A closed skirt's flow (the live update only; tools and tests see it at rest): per panel bone [x, v] (its move out,
## m, and its speed), the hem's sway and its speed (pelvis frame), the hips' last position and velocity (skeleton
## space), and what the next _drive steps: _skirt_dt (s; 0 = no flow) with the hips' acceleration _skirt_acc.
var _skirt_flow := {}
var _skirt_sway := Vector3.ZERO
var _skirt_sway_v := Vector3.ZERO
var _skirt_pp := Vector3.INF
var _skirt_pv := Vector3.ZERO
var _skirt_usec := 0
var _skirt_dt := 0.0
var _skirt_acc := Vector3.ZERO

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
	_legs.clear()
	_leg_radii.clear()
	_leg_push.clear()
	for side in ["l_", "r_"]:
		var leg := PackedInt32Array()
		var rad := PackedFloat32Array()
		var push := PackedFloat32Array()
		for k in SKIRT_LEG_JOINTS.size():
			var jb := skeleton.find_bone(side + String(SKIRT_LEG_JOINTS[k]))
			if jb >= 0 and _bind.has(jb):
				leg.append(jb)
				rad.append(float(SKIRT_LEG_RADII[k]))
				push.append(float(SKIRT_LEG_PUSH_M[k]))
		_legs.append(leg)
		_leg_radii.append(rad)
		_leg_push.append(push)
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


## A closed skirt worn (`on`) or not, with its hems (SKIRT_HEMS layout; empty = SKIRT_CLOSED_HEMS when closed).
func set_skirt_closed(on: bool, hems: Array = []) -> void:
	skirt_closed = on
	set_skirt_hems(hems)


func _hem(panel: int) -> Vector3:
	if skirt_hems.size() == 3:
		return skirt_hems[panel]
	return SKIRT_CLOSED_HEMS[panel] if skirt_closed else SKIRT_HEMS[panel]


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
	var closed := _closed_skirt(g, down, floor_h, diag) if skirt_closed else {}
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
				r = _skirt(d, qp, rel, down, jb, jp, floor_h, diag) if not closed.has(d.bone) else Quaternion.IDENTITY
			Kind.QUEUE:
				r = _queue(qp, down)
				jb = QUEUE_ROOT
				jp = _skinning(g, d.child) * QUEUE_ROOT
		var rb := Basis(r.normalized())
		var m: Transform3D = closed[d.bone] if closed.has(d.bone) else Transform3D(rb, jp - rb * jb)
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


## The time since the last live update and the hips' acceleration, for the closed skirt's flow (_skirt_dt, _skirt_acc).
func _skirt_step(sk: Skeleton3D, g: Array) -> void:
	var now := Time.get_ticks_usec()
	var dt := clampf(float(now - _skirt_usec) / 1e6, 0.0, 0.05) if _skirt_usec > 0 else 0.0
	_skirt_usec = now
	if soft_step > 0.0:
		dt = soft_step
	var p := sk.global_transform * (g[_pelvis] as Transform3D).origin
	var basis_inv := sk.global_basis.orthonormalized().inverse()
	if dt <= 0.0 or not _skirt_pp.is_finite() or p.distance_to(_skirt_pp) > 2.0:
		_skirt_pp = p
		_skirt_pv = Vector3.ZERO
		_skirt_acc = Vector3.ZERO
		_skirt_dt = dt
		return
	var v := (p - _skirt_pp) / dt
	_skirt_acc = basis_inv * ((v - _skirt_pv) / dt).limit_length(BREAST_ACCEL_MAX)
	_skirt_pp = p
	_skirt_pv = v
	_skirt_dt = dt


## The skinning transforms (bind -> posed skeleton space) of a closed skirt's panels, by bone (see SKIRT_CLOSED_HEMS).
## `g`: the bone globals (the pelvis, the hips and the SKIRT_LEG_JOINTS at least), `down`: world-down in skeleton
## space. Flows by _skirt_dt when a live update set it; at rest otherwise.
func _closed_skirt(g: Array, down: Vector3, floor_h: float, diag) -> Dictionary:
	var panels: Array = []
	for d: Dictionary in _drivers:
		if int(d.kind) == Kind.SKIRT:
			panels.append(d)
	if panels.is_empty():
		return {}
	var qp := _skinning(g, int(panels[0].parent)).basis.get_rotation_quaternion()
	var qi := qp.inverse()
	# gravity: the bind hang direction (down) -> world-down in the pelvis frame, limited
	var dl := (qi * down).normalized()
	var gv := _rotvec(Quaternion(Vector3.DOWN, dl)) if dl.dot(Vector3.DOWN) > -0.9999 else Vector3(-PI, 0.0, 0.0)
	var gmax := deg_to_rad(SKIRT_CLOSED_GRAVITY_MAX_DEG)
	if gv.length() > gmax:
		gv *= gmax / gv.length()
	# the hem's sway: trails the hips' acceleration (pelvis frame, across the hang), a damped spring
	var dt := _skirt_dt
	var kk := SKIRT_CLOSED_SPRING.x
	var cc := SKIRT_CLOSED_SPRING.y
	if dt > 0.0:
		var ap := qi * _skirt_acc
		ap.y = 0.0
		var steps := ceili(dt / SOFT_SUBSTEP)
		var h := dt / steps
		for i in steps:
			_skirt_sway_v += (-kk * _skirt_sway - cc * _skirt_sway_v - ap) * h
			_skirt_sway += _skirt_sway_v * h
		_skirt_sway = _skirt_sway.limit_length(SKIRT_CLOSED_SWAY_M)
	# the legs inside: the knee, ankle, heel and toes, and along the thigh and the shin, with their thickness
	var pts: Array[Vector3] = []
	var prad := PackedFloat32Array()
	var pmax := PackedFloat32Array()
	for li in _legs.size():
		var leg := _legs[li]
		for k in leg.size():
			var p := (g[leg[k]] as Transform3D).origin
			if k > 0:
				pts.append(p)
				prad.append(_leg_radii[li][k])
				pmax.append(_leg_push[li][k])
			if k == 1 or k == 2:
				var q := (g[leg[k - 1]] as Transform3D).origin
				var rr := SKIRT_THIGH_RADII if k == 1 else SKIRT_SHIN_RADII
				var pm := Vector2(1.0, 1.0) if k == 1 else SKIRT_SHIN_PUSH_M
				pts.append(q.lerp(p, 0.5))
				prad.append(rr.x)
				pmax.append(pm.x)
				pts.append(q.lerp(p, 0.8))
				prad.append(rr.y)
				pmax.append(pm.y)
	var n := panels.size()
	var turn := PackedFloat32Array()        # how far past its gravity hang a raised thigh turns each panel (rad)
	turn.resize(n)
	var out_m := PackedFloat32Array()       # how far out the legs push its cloth (m)
	out_m.resize(n)
	var azs := PackedFloat32Array()
	azs.resize(n)
	var info: Array = []
	var reach := Vector2(deg_to_rad(SKIRT_CLOSED_REACH_DEG.x), deg_to_rad(SKIRT_CLOSED_REACH_DEG.y))
	var sy := SKIRT_CLOSED_SHARE_Y
	for i in n:
		var d: Dictionary = panels[i]
		var jb := _org(d.joint)
		var jp := (g[d.joint] as Transform3D).origin
		var hem: Vector3 = d.hem
		var e0 := hem - jb
		var u := Vector3(e0.x, 0.0, e0.z).normalized()     # outward, where the panel hangs round the body
		var ax := Vector3.DOWN.cross(u)                     # turns it from down toward u
		var th0 := atan2(e0.dot(u), -e0.y)                  # its flare at the bind
		var gs := gv.dot(ax)                                # gravity's turn (from the bind) in its plane
		azs[i] = atan2(hem.x, hem.z)
		# tucked up: its length (share of the bind's), its lift and the lowest the cloth then reaches (bind height)
		var tuck := maxf(clampf(skirt_tuck, 0.0, 1.0) * SKIRT_CLOSED_TUCK_SHARE[int(d.panel)],
				clampf(skirt_tuck_back, 0.0, 1.0) * SKIRT_CLOSED_TUCK_BACK_SHARE[int(d.panel)])
		var tk := lerpf(1.0, SKIRT_CLOSED_TUCK, tuck)
		var lift_m := SKIRT_CLOSED_TUCK_LIFT_M * tuck
		var low := jb.y + e0.y * tk + lift_m - 0.03
		var best := 0.0
		for pi in pts.size():
			var v := qi * (pts[pi] - jp)                    # pelvis bind frame, from the panel's hip joint
			var pa := v + jb
			if Vector2(pa.x, pa.z).length() < 0.05:
				continue
			var w := 1.0 - smoothstep(reach.x, reach.y, absf(angle_difference(azs[i], atan2(pa.x, pa.z))))
			if w <= 0.0 or pa.y < low:
				continue
			var a := v.dot(u)
			var b := -v.y
			var l := sqrt(a * a + b * b)
			if l < 0.08 or l > e0.length() * tk + 0.05:      # (beyond the cloth's reach: out from under it)
				continue
			# high on the body (little of the cloth there is the panel's) a raised thigh turns the panel up
			if smoothstep(sy.x, sy.y, pa.y) < 0.35:
				best = maxf(best, w * (atan2(a, b) + asin(minf((SKIRT_CLOSED_CLEAR + prad[pi]) / l, 1.0)) - th0 - gs))
		turn[i] = best
		info.append([ax, th0, jb, jp, gs, e0, tk, lift_m])
	var order := range(n)
	order.sort_custom(func(x: int, y: int) -> bool: return azs[x] < azs[y])
	turn = _skirt_spread(turn, order, SKIRT_CLOSED_TURN_SPREAD)
	# the rotations (gravity, the turn), then how far out the legs lower down push the cloth: the skirt at bind is a
	# cone round its axis; a leg point outside it (seen as the two panels either side of it see it, turned) needs
	# those panels moved out by its depth past the cloth, over the share of the cloth there that is theirs
	var paz := PackedFloat32Array()              # each panel's place in the weights (rad from the front, + left)
	for i in n:
		var d: Dictionary = panels[i]
		var az := deg_to_rad(SKIRT_CLOSED_PANEL_AZ[int(d.panel)])
		paz.append(az * float(d.sign))
	var rots: Array[Quaternion] = []
	for i in n:
		var ax: Vector3 = info[i][0]
		var th0: float = info[i][1]
		var gs: float = info[i][4]
		var sw := minf(gs + turn[i], deg_to_rad(SKIRT_CLOSED_MAX_DEG) - th0)
		var rv := ax * sw + (gv - ax * gs)                 # (gravity's sideways part as it is: the skirt sways as one)
		rots.append(Quaternion(rv.normalized(), rv.length()) if rv.length() > 1e-9 else Quaternion.IDENTITY)
	for i in n:
		out_m[i] = 0.0
	var jb0: Vector3 = info[0][2]
	var jp0: Vector3 = info[0][3]
	for pi in pts.size():
		var pb := qi * (pts[pi] - jp0) + jb0               # the point in the pelvis's bind frame
		var az := atan2(pb.x, pb.z)
		# the two panels nearest round the body: the ones whose cloth is there in the weights
		var near := [-1, -1]
		var dist := [INF, INF]
		for i in n:
			var da := absf(angle_difference(az, paz[i]))
			if da < dist[0]:
				near = [i, near[0]]
				dist = [da, dist[0]]
			elif da < dist[1]:
				near[1] = i
				dist[1] = da
		for i: int in near:
			if i < 0:
				continue
			var jb: Vector3 = info[i][2]
			var e0: Vector3 = info[i][5]
			var pa := rots[i].inverse() * (pb - jb) + jb      # as this panel sees it (turned back to its bind)
			# (tucked up, the cloth at the point's height is what hung lower at the bind)
			var yb := jb.y + (pa.y - float(info[i][7]) - jb.y) / float(info[i][6])
			var share := smoothstep(SKIRT_CLOSED_SHARE_Y.x, SKIRT_CLOSED_SHARE_Y.y, yb)
			if share < 0.35 or yb < jb.y + e0.y - 0.05:
				continue
			var rel := Vector2(pa.x, pa.z)
			var depth := rel.length() + prad[pi] + SKIRT_CLOSED_CLEAR - _skirt_round(yb, absf(atan2(pa.x, pa.z)))
			if depth <= 0.0:
				continue
			var ui := Vector2(sin(paz[i]), cos(paz[i]))
			out_m[i] = maxf(out_m[i], minf(depth / (share * maxf(ui.dot(rel.normalized()), 0.7)), pmax[pi]))
	out_m = _skirt_spread(out_m, order)
	var upright := 1.0 - smoothstep(deg_to_rad(SKIRT_FLOOR_TILT_DEG.x), deg_to_rad(SKIRT_FLOOR_TILT_DEG.y),
			(qp * Vector3.UP).angle_to(-down))
	var res := {}
	for i in n:
		var d: Dictionary = panels[i]
		var ax: Vector3 = info[i][0]
		var jb: Vector3 = info[i][2]
		var jp: Vector3 = info[i][3]
		var e0: Vector3 = info[i][5]
		var u := Vector3(sin(paz[i]), 0.0, cos(paz[i]))
		# the flow: a spring toward the hem's sway, pushed out at once by the legs, never past the bounds
		var x := out_m[i]
		if dt > 0.0:
			var st: Array = _skirt_flow.get(d.bone, [x, 0.0])
			var fx: float = st[0]
			var fv: float = st[1]
			var target := _skirt_sway.dot(u)
			var steps := ceili(dt / SOFT_SUBSTEP)
			var h := dt / steps
			for j in steps:
				fv += (-kk * (fx - target) - cc * fv) * h
				fx += fv * h
			if fx < out_m[i]:
				fx = out_m[i]
				fv = maxf(fv, 0.0)
			fx = clampf(fx, -SKIRT_CLOSED_CLEAR, SKIRT_CLOSED_OUT_M)
			_skirt_flow[d.bone] = [fx, fv]
			x = fx
		x = minf(x, SKIRT_CLOSED_OUT_M)
		var r := qp * rots[i]
		# bunched: lifted above the level it shortens; on the ground it pools (shortens to rest SKIRT_CLOSED_FLOOR_SINK
		# into it); what is still below then swings out (about its own axis) as a coat skirt's does
		var e := r * e0
		var k := lerpf(1.0, SKIRT_CLOSED_BUNCH, smoothstep(deg_to_rad(SKIRT_CLOSED_BUNCH_DEG.x),
				deg_to_rad(SKIRT_CLOSED_BUNCH_DEG.y), e.angle_to(down)))
		k = minf(k, float(info[i][6]))
		var drop := e.dot(down)
		var room := -jp.dot(down) - floor_h + SKIRT_CLOSED_FLOOR_SINK
		if drop > 1e-4 and drop * k > room:
			k = minf(k, maxf(room / drop, SKIRT_CLOSED_BUNCH))
		var axp := (qp * ax).normalized()
		var lift := upright * _lift(e * k, axp, -down, floor_h - SKIRT_CLOSED_FLOOR_SINK + jp.dot(down),
				deg_to_rad(SKIRT_CLOSED_FLOOR_MAX_DEG))
		if lift != 0.0:
			r = Quaternion(axp, lift) * r
		var dir := (r * e0).normalized()
		var bunch := Basis(Vector3.RIGHT - dir * ((1.0 - k) * dir.x), Vector3.UP - dir * ((1.0 - k) * dir.y),
				Vector3.BACK - dir * ((1.0 - k) * dir.z))
		var bb := bunch * Basis(r.normalized())
		res[d.bone] = Transform3D(bb, jp - bb * jb + (r * u) * x + (qp * Vector3.UP) * float(info[i][7]))
		if diag is Array:
			(diag as Array).append({"bone": d.bone, "panel": d.panel, "pushed": turn[i] > 0.0 or out_m[i] > 0.0,
					"floored": lift != 0.0, "hang": rad_to_deg((r * Vector3.DOWN).angle_to(down)), "bunch": k, "out": x})
	return res


## The closed skirt's distance from the body's axis at bind height `y`, `az` radians round from the front (0..PI).
static func _skirt_round(y: float, az: float) -> float:
	var ys: Array = SKIRT_CLOSED_ROUND_Y
	var fy := 0.0
	var iy := 0
	if y >= float(ys[0]):
		iy = 0
	elif y <= float(ys[ys.size() - 1]):
		iy = ys.size() - 2
		fy = 1.0
	else:
		while iy < ys.size() - 2 and y < float(ys[iy + 1]):
			iy += 1
		fy = (float(ys[iy]) - y) / (float(ys[iy]) - float(ys[iy + 1]))
	var t := clampf(rad_to_deg(az) / 30.0, 0.0, 6.0)
	var ia := mini(int(t), 5)
	var fa := t - ia
	var r0: Array = SKIRT_CLOSED_ROUND[iy]
	var r1: Array = SKIRT_CLOSED_ROUND[iy + 1]
	return lerpf(lerpf(float(r0[ia]), float(r0[ia + 1]), fa), lerpf(float(r1[ia]), float(r1[ia + 1]), fa), fy)


## `v` (one value per panel) with each panel taking `share` of its neighbours' round the body (`order`:
## the panels by their angle round it), twice.
static func _skirt_spread(v: PackedFloat32Array, order: Array, share := SKIRT_CLOSED_SPREAD) -> PackedFloat32Array:
	var n := v.size()
	for pass_i in 2:
		var nxt := v.duplicate()
		for k in n:
			var nb := maxf(v[order[(k + n - 1) % n]], v[order[(k + 1) % n]])
			nxt[order[k]] = maxf(v[order[k]], share * nb)
		v = nxt
	return v


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
	if skirt_closed:
		for leg in _legs:
			for b in leg:
				if g[b] == null:
					g[b] = sk.get_bone_global_pose(b)
		_skirt_step(sk, g)
	var res := _drive(g, sk.global_basis.orthonormalized().inverse() * Vector3.DOWN)
	_skirt_dt = 0.0
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
