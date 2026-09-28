class_name AimStabilizer
extends SkeletonModifier3D
## Keeps the masked aim upper body in the aim clip's model-space orientation (plan section 6.11,
## decision D6; WP5).
##
## Aiming while the lower body plays locomotion, air, landing or hit clips puts the aim tree
## (A__<w>__<s>) on the upper-body bones (U_aim, filtered to metrics bone_sets.upper) over a
## lower-body root that is not the aim clip's root. The upper body hangs off `root` through
## `upper_base` and the 14 `*_offset` arm drivers, all root children (siblings of the pelvis
## chain), so rotating exactly those bones by
##
##   c = root_L^-1 * root_A        (root_L: the animated root, root_A: the aim clip's root)
##
## gives them the aim clip's model-space orientation without moving the legs. UpperBody sets
## `aim_root_q` (the aim clip's root rotation sampled at the aim input's live position, so the
## breathing of the aim idle is kept) and `weight` = upper aim weight after each advance().
## In AIM_IDLE the lower root is the aim root and c = I.
##
## Aim trim (Frontier requirement, not graph data; on by default because today's game keeps the
## weapon on the crosshair): the aim clips bake a stance in which the barrel sits a few degrees
## off the body's facing (bow about 11 deg right standing, more when aiming up), and the pitch
## additives leave a small residual. After c, the trim turns the same bones about the hips (the
## root origin) by a yaw about the vertical and a pitch about the horizontal axis across the
## barrel (the weapon's prop bone, +Z = barrel, the Frontier weapon convention). It is
##   trim = trim_ff + residual
## trim_ff: UpperBody's feed-forward from the calibration table (the aim pose's barrel yaw at the
##   solved pitch weight, and any elevation the additives cannot reach);
## residual: closed loop. Each frame the trim that puts the barrel on the aim target is solved in
##   closed form (3 fixed-point steps for the lever arm); while trim_learn (UpperBody: the weapon
##   is fully raised and no authored motion plays on top) the residual moves toward
##   (solved - trim_ff) at trim_rate_deg_s, so parallax, breathing and the table's error are
##   absorbed without chasing the pose of a half-raised weapon. Otherwise it is held.
## `weight` (= upper aim weight, set by UpperBody) ramps the whole correction in and out with the
## raise: the modifier applies c^weight and trim x weight itself, and Godot's influence must stay
## 1. Godot's influence blend is not used for this: measured on 4.7.2, once the trim also sets the
## bones, an influence < 1 no longer scales anything (influence 0.05 applied the whole 60 deg
## correction; the full correction appeared on the first raise frame and vanished on the last
## lower frame, 22-88 deg in one frame), and it would move the E bones' positions along a chord
## instead of rotating them. While 0 < weight < 1 the sign of c follows the previous frame, so a
## correction that passes 180 deg mid-raise does not flip to the other way round.
## It replaces the per-weapon aim_yaw_offset / aim_pitch_offset calibration (and the player's
## visual yaw, which must then be 0). `trim_weight` scales the trim (1 - blocked weight).
##
## Runs after the AnimationTree's pose (a child of the Skeleton3D, after any existing modifier);
## code outside Skeleton3D.skeleton_updated reads the pre-modifier pose, BoneAttachment3D (the
## weapon sockets) the corrected one (engine contract ec_modifier_order).

## metrics bone_sets.stabilized: upper_base + the root children in the upper mask (E set).
@export var bone_names := PackedStringArray()
## Frontier aim trim (see the header). Off = the plan's pure orientation correction.
@export var aim_trim := true
## Trim clamps (proposed values, owner to confirm): within the plan's +-40 deg of aim elevation
## the trim stays inside them; toward the camera limit (+-80) they saturate (bow standing from
## +50, bow / pistol crouched at -80) and the barrel leaves the crosshair by up to 12 deg
## (test_aim_pitch reports it). The yaw part turns the torso against the legs in AIM_IDLE.
@export var trim_max_yaw_deg := 25.0
@export var trim_max_pitch_deg := 12.0
## How fast the closed-loop residual follows (deg/s).
@export var trim_rate_deg_s := 60.0

## The aim clip's root rotation (root-local = model space; root has no parent). Set by UpperBody.
var aim_root_q := Quaternion.IDENTITY
## How much of the correction and the trim is applied (UpperBody: the upper aim weight). 0 also
## forgets the sign of the last correction.
var weight := 1.0:
	set(v):
		weight = v
		if v <= 0.0:
			_have_c = false
## Phase-2 option (WP10): spread the correction over the spine. Not implemented here. With the
## skinned body this matters: aimed movement turns the upper body against the pelvis by the whole
## correction c at the waist (measured in the level: 67 deg bow forward, 85 deg musket and 122 deg
## bow strafing left), so visual acceptance of aimed movement on the skinned body depends on it.
var twist_distribution := false
## Barrel bone of the current weapon (&"" = no trim).
var trim_bone := &""
## World point the barrel should aim at (non-finite = no trim).
var trim_target := Vector3.INF
## 0..1 scale of the trim (1 - blocked weight).
var trim_weight := 1.0
## Feed-forward trim (yaw, pitch) in radians (UpperBody, from the calibration table).
var trim_ff := Vector2.ZERO
## Update the closed-loop residual this frame (weapon fully raised, nothing authored on top).
var trim_learn := false
## Freeze the closed-loop residual (debug; UpperBody drives trim_learn instead).
var trim_hold := false
## Seconds since the last modification (UpperBody sets the frame's dt), for trim_rate_deg_s.
var step_dt := 1.0 / 60.0

var _sk_id := 0
var _root := -1
var _bones := PackedInt32Array()
var _names_key := ""
var _trim_bi := -1
var _trim_name := &""
var _last_c := 0.0
var _trim := Vector2.ZERO      ## trim (yaw, pitch) in radians, before trim_weight
var _res := Vector2.ZERO       ## closed-loop residual (radians)
var _need := Vector2.ZERO      ## last solved trim that puts the barrel on the target
var _applied := Vector2.ZERO   ## applied trim after trim_weight and weight
var _prev_c := Quaternion.IDENTITY   ## last full correction c (sign continuity while 0 < weight < 1)
var _have_c := false
var _last_applied := 0.0       ## angle of the applied correction c^weight (radians)


## Adds a stabilizer as the last child of `sk` (after any existing modifier).
static func create(sk: Skeleton3D, bones: PackedStringArray) -> AimStabilizer:
	var s := AimStabilizer.new()
	s.name = "AimStabilizer"
	s.bone_names = bones if not bones.is_empty() else default_bones(sk)
	s.influence = 1.0
	s.weight = 0.0
	s.active = false
	sk.add_child(s)
	return s


## upper_base plus every root child named *_offset (the metrics rule, for rigs without metrics).
static func default_bones(sk: Skeleton3D) -> PackedStringArray:
	var out := PackedStringArray()
	var ub := sk.find_bone("upper_base")
	if ub < 0:
		return out
	out.append("upper_base")
	var root := sk.get_bone_parent(ub)
	if root < 0:
		return out
	for c in sk.get_bone_children(root):
		var n := sk.get_bone_name(c)
		if n.contains("_offset"):
			out.append(n)
	return out


## Angle of the last orientation correction c (degrees), before `weight`.
func last_correction_deg() -> float:
	return rad_to_deg(_last_c)


## Angle of the last applied correction c^weight (degrees).
func last_applied_deg() -> float:
	return rad_to_deg(_last_applied)


## Last applied trim (yaw, pitch) in degrees (after trim_weight).
func last_trim_deg() -> Vector2:
	return Vector2(rad_to_deg(_applied.x), rad_to_deg(_applied.y))


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	_resolve(sk)
	if _root < 0 or _bones.is_empty():
		return
	var w := clampf(weight, 0.0, 1.0)
	if w <= 0.0:
		_last_applied = 0.0
		_applied = Vector2.ZERO
		return
	var c := (sk.get_bone_pose_rotation(_root).inverse() * aim_root_q).normalized()
	_last_c = PoseMath.angle(c)
	if w < 1.0 and _have_c:
		if _prev_c.dot(c) < 0.0:
			c = -c
	elif c.w < 0.0:
		c = -c
	_prev_c = c
	_have_c = true
	# c^w along the arc c's sign gives (the shortest one unless continuity chose the other).
	var cw := c if w >= 1.0 else Quaternion.IDENTITY.slerpni(c, w).normalized()
	_last_applied = PoseMath.angle(cw)
	for b in _bones:
		sk.set_bone_pose_rotation(b, (cw * sk.get_bone_pose_rotation(b)).normalized())
		sk.set_bone_pose_position(b, cw * sk.get_bone_pose_position(b))
	if aim_trim:
		_apply_trim(sk, w)
	else:
		_applied = Vector2.ZERO


## Yaw about +Y and pitch about the horizontal axis across the barrel, about the root origin.
## w: the modifier weight (the trim is applied x w).
func _apply_trim(sk: Skeleton3D, w := 1.0) -> void:
	if _trim_name != trim_bone:
		_trim_name = trim_bone
		_trim_bi = sk.find_bone(String(trim_bone)) if trim_bone != &"" else -1
	if _trim_bi < 0:
		_trim = Vector2.ZERO
		_applied = Vector2.ZERO
		return
	var rootg := sk.get_bone_global_pose(_root)
	var pivot := rootg.origin
	var g := sk.get_bone_global_pose(_trim_bi)
	var f := (g.basis * Vector3.BACK).normalized()
	var h0 := Vector3(f.x, 0.0, f.z)
	if h0.length_squared() < 1e-8:
		return
	h0 = h0.normalized()
	if trim_target.is_finite():
		var tgt := sk.global_transform.affine_inverse() * trim_target
		var yaw := 0.0
		var pitch := 0.0
		for i in 3:
			var q := _trim_q(yaw, pitch, h0)
			var o := pivot + q * (g.origin - pivot)
			var fq := q * f
			var d := tgt - o
			if d.length_squared() < 1e-4:
				break
			d = d.normalized()
			yaw += wrapf(atan2(d.x, d.z) - atan2(fq.x, fq.z), -PI, PI)
			pitch += asin(clampf(d.y, -1.0, 1.0)) - asin(clampf(fq.y, -1.0, 1.0))
		_need = Vector2(yaw, pitch)
		if trim_learn and not trim_hold:
			var want := _need - trim_ff
			var mx := deg_to_rad(trim_rate_deg_s) * maxf(step_dt, 0.0)
			_res = Vector2(move_toward(_res.x, want.x, mx), move_toward(_res.y, want.y, mx))
	var t := trim_ff + _res
	_trim = Vector2(clampf(t.x, -deg_to_rad(trim_max_yaw_deg), deg_to_rad(trim_max_yaw_deg)),
			clampf(t.y, -deg_to_rad(trim_max_pitch_deg), deg_to_rad(trim_max_pitch_deg)))
	_applied = _trim * clampf(trim_weight, 0.0, 1.0) * w
	if _applied.length_squared() < 1e-12:
		return
	var qt := _trim_q(_applied.x, _applied.y, h0)
	var rq := rootg.basis.get_rotation_quaternion()
	var ql := (rq.inverse() * qt * rq).normalized()      # the trim in root-local space
	for b in _bones:
		sk.set_bone_pose_rotation(b, (ql * sk.get_bone_pose_rotation(b)).normalized())
		sk.set_bone_pose_position(b, ql * sk.get_bone_pose_position(b))


## Forget the learned residual (weapon change: another weapon's pose).
func reset_trim() -> void:
	_res = Vector2.ZERO


## Last solved trim (yaw, pitch) in degrees that would put the barrel on the target.
func solved_trim_deg() -> Vector2:
	return Vector2(rad_to_deg(_need.x), rad_to_deg(_need.y))


## Pitch first (about UP x heading; + raises the barrel), then yaw about UP.
static func _trim_q(yaw: float, pitch: float, heading: Vector3) -> Quaternion:
	var axis := Vector3.UP.cross(heading).normalized()
	return (Quaternion(Vector3.UP, yaw) * Quaternion(axis, -pitch)).normalized()


func _resolve(sk: Skeleton3D) -> void:
	var key := ",".join(bone_names)
	if _sk_id == sk.get_instance_id() and _names_key == key:
		return
	_sk_id = sk.get_instance_id()
	_names_key = key
	_bones = PackedInt32Array()
	_root = -1
	var names := bone_names if not bone_names.is_empty() else default_bones(sk)
	for n in names:
		var bi := sk.find_bone(n)
		if bi < 0:
			continue
		var p := sk.get_bone_parent(bi)
		if _root < 0:
			_root = p
		if p != _root or p < 0:
			push_warning("AimStabilizer: %s is not a child of the root bone; skipped" % n)
			continue
		_bones.append(bi)
	_trim_name = &""
	_have_c = false


class PoseMath:
	## Rotation angle of a unit quaternion (accurate near 0, where acos loses precision).
	static func angle(q: Quaternion) -> float:
		var v := Vector3(q.x, q.y, q.z).length()
		return 2.0 * atan2(v, absf(q.w))
