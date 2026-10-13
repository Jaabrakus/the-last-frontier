extends "res://scripts/player/anim/jog_aim_arm.gd"
## Lightning's arm on the crosshair (the owner, 2026-10-11: Lightning on the pistol's standing aim, "use our musket and pistol
## tech that we built in frontiers over"): the pistol's own JogAimArm (the right arm turned about its shoulder onto the aim point
## in passes, by up to MAX_DEG, the head toward it), with the two fingers for the muzzle: their way from the knuckles to the
## tips (the index's and the middle's, averaged), from the tips. SwayPose puts it right after its cast pose (a pick's "aim":
## "pistol": tools/anim_author/bake_bend_aim.gd) and sets its weight (the cast's, by the clip's aim: raised over aim_in_s,
## lowered from back_s) and its target each frame. The kick (deg, `kick_deg`: the clip's own at its time) is put back after the
## turn, which takes out the clip's own: the arm tipped up at the shoulder and `wrist_share` of it more at the wrist, about the
## level axis across the arm (the bake's own kick).
## No class_name: loaded by its path (SwayPose.BEND_AIM_ARM), so a checkout the editor has not scanned still compiles.

var kick_deg := 0.0
var wrist_share := 0.6
var _tips := PackedInt32Array()     ## r_indexa, r_indexc, r_middlea, r_middlec (-1 missing)
var _wrist := -1


func _process_modification() -> void:
	super()
	if weight <= 0.0 or absf(kick_deg) < 0.01:
		return
	var sk := get_skeleton()
	if sk == null or _shoulder < 0:
		return
	if _wrist < 0:
		_wrist = sk.find_bone("r_wrist")
		if _wrist < 0:
			return
	var s := sk.get_bone_global_pose(_shoulder)
	var d := (sk.get_bone_global_pose(_wrist).origin - s.origin).normalized()
	var axis := d.cross(Vector3.UP)
	if axis.length_squared() < 1e-6:
		return
	axis = axis.normalized()
	var rad := deg_to_rad(kick_deg)
	for pair: Array in [[_shoulder, rad], [_wrist, rad * wrist_share]]:
		var b: int = pair[0]
		var g := sk.get_bone_global_pose(b)
		sk.set_bone_global_pose(b, Transform3D(Basis(axis, float(pair[1])) * g.basis, g.origin))


## The kick's size (deg) at clip time `t` for a strike at `strike`: in over `in_s` (eased), back over `back_s` (eased), 0 before
## and after (and with no strike). The bake's own (tools/anim_author/bake_bend_aim.gd) and the one put back after the turn.
static func kick_curve(t: float, strike: float, deg: float, in_s: float, back_s: float) -> float:
	var d := t - strike
	if strike < 0.0 or d <= 0.0 or d >= in_s + back_s:
		return 0.0
	if d < in_s:
		return deg * smoothstep(0.0, in_s, d)
	return deg * (1.0 - smoothstep(0.0, back_s, d - in_s))


## The two fingers: from their tips along their way (the knuckle to the tip; -Z), else the pistol's muzzle.
func _pointer(sk: Skeleton3D) -> Transform3D:
	if _tips.is_empty():
		for bn: String in ["r_indexa", "r_indexc", "r_middlea", "r_middlec"]:
			_tips.append(sk.find_bone(bn))
	if _tips[0] < 0 or _tips[1] < 0:
		return super(sk)
	var base := sk.get_bone_global_pose(_tips[0]).origin
	var tip := sk.get_bone_global_pose(_tips[1]).origin
	if _tips[2] >= 0 and _tips[3] >= 0:
		base = (base + sk.get_bone_global_pose(_tips[2]).origin) * 0.5
		tip = (tip + sk.get_bone_global_pose(_tips[3]).origin) * 0.5
	var way := tip - base
	if way.length_squared() < 1e-8:
		return super(sk)
	way = way.normalized()
	var up := Vector3.UP if absf(way.dot(Vector3.UP)) < 0.98 else Vector3.BACK
	return Transform3D(Basis.looking_at(way, up), tip)
