class_name JogAimArm
extends SkeletonModifier3D
## The pistol's arm on the crosshair while it is aimed on the move (user 2026-10-01: "the pistol shooting while moving doesnt
## aim at cross hair or the right arm doesnt point to the aim"): the torso is the jog's then (UpperBody.torso_free: the
## upper-body aim and its AimStabilizer eased out), so nothing turned the arm onto the aim. After the arm poses and the hands'
## modifiers, the right arm is turned about its shoulder so the barrel points from the muzzle at the aim point (FrontierPlayer
## get_aim_point(), the crosshair's), in PASSES passes (the muzzle moves as the arm turns), by up to MAX_DEG; `weight` (PlayerAnim:
## the jog aim's own) eases it in and out. Off (weight 0) it does nothing.
## The head looks at the aim point too (user 2026-10-02: "pistol standing aim head needs to follow the aim or cursor"): the face's
## way turned onto it, NECK_SHARE of the turn in the neck and the rest in the head, by up to HEAD_MAX_DEG.

const MAX_DEG := 75.0
## Passes a frame: the muzzle moves as the arm turns (it is off the shoulder's line), so each pass aims it again.
const PASSES := 4
## The muzzle in the pistol model's frame (tools/models/pistol.py: the bore at y 0.05, its face at z -0.31; -Z ahead).
const MUZZLE := Vector3(0.0, 0.05, -0.31)

var weight := 0.0
## The aim point in the skeleton's space (PlayerAnim sets it each frame).
var target := Vector3.ZERO
## The model on the right hand's prop bone (FrontierPlayer.pistol_offset).
var offset := Transform3D()
var _shoulder := -1
var _prop := -1
var _neck := -1
var _head := -1
var _face_local := Vector3.BACK     ## the face's way in the head bone's frame (the rig faces +Z at rest)
const HEAD_MAX_DEG := 70.0
const NECK_SHARE := 0.4


func _process_modification() -> void:
	if weight <= 0.0:
		return
	var sk := get_skeleton()
	if sk == null:
		return
	if _shoulder < 0:
		_shoulder = sk.find_bone("r_shoulder")
		_prop = sk.find_bone("r_hand_prop_attachment")
		if _shoulder < 0 or _prop < 0:
			return
		_neck = sk.find_bone("neck")
		_head = sk.find_bone("headb")
		if _head >= 0:
			_face_local = (sk.get_bone_global_rest(_head).basis.orthonormalized().inverse() * Vector3(0, 0, 1)).normalized()
	for i in PASSES:
		var model := sk.get_bone_global_pose(_prop) * offset
		var muzzle := model * MUZZLE
		var d := (-model.basis.z).normalized()
		var want := target - muzzle
		if want.length_squared() < 0.04:
			break
		want = want.normalized()
		var axis := d.cross(want)
		if axis.length_squared() < 1e-10:
			break
		var ang := minf(d.angle_to(want), deg_to_rad(MAX_DEG)) * weight
		var s := sk.get_bone_global_pose(_shoulder)
		var turn := Basis(axis.normalized(), ang)
		sk.set_bone_global_pose(_shoulder, Transform3D(turn * s.basis, s.origin))
	_look(sk)


## The head turned toward the aim point (the neck and the head sharing the turn).
func _look(sk: Skeleton3D) -> void:
	if _head < 0:
		return
	for pair: Array in [[_neck, NECK_SHARE], [_head, 1.0]]:
		var b: int = pair[0]
		if b < 0:
			continue
		var hg := sk.get_bone_global_pose(_head)
		var face := (hg.basis.orthonormalized() * _face_local).normalized()
		var want := target - hg.origin
		if want.length_squared() < 0.04:
			return
		want = want.normalized()
		var axis := face.cross(want)
		if axis.length_squared() < 1e-10:
			return
		var ang := minf(face.angle_to(want), deg_to_rad(HEAD_MAX_DEG)) * weight * float(pair[1])
		var g := sk.get_bone_global_pose(b)
		sk.set_bone_global_pose(b, Transform3D(Basis(axis.normalized(), ang) * g.basis, g.origin))
