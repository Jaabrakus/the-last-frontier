class_name HuntAim
extends SkeletonModifier3D
## A household hunter's aim (user 2026-09-29: "why does he aim the weapon not normal?"): the weapon held in the aim clip's
## own two-hand hold and the upper body turned so that the barrel (or the arrow, or the spear) lies on the animal, as the
## player's aim puts his weapon on the crosshair (AimStabilizer's trim: a yaw about the vertical and a pitch across the
## barrel, over the upper body; here over the spine, chest and upper chest, a share each).
##
## The hold: the rifle aim clips put the right hand's prop bone at the wrist of the stock and the left hand's on the fore-end
## (actor_b-p-rifle-idle-aim: the left 0.31 m ahead of the right, level, the right hand under the cheek); the bow aim clips
## the right hand at the string by the cheek and the left hand on the bow's grip out in front. So the weapon lies along the
## line from the right hand's prop point to the left's: the gun's grip (WeaponModels' origin: the wrist of the stock) in the
## right hand, the barrel out through the left hand on the fore-end, the butt back at the shoulder; the bow's grip in the left
## hand, the arrow on the line from the drawing hand. The one-hand throw aim (the spear) has no such line: the spear is held
## in the right hand along the chest's facing, point forward.
## Each frame, after the clip: the turn from the weapon's line to the line from the right hand to `target` (the animal's
## chest), split over SPINE (at most MAX_YAW / MAX_PITCH, and faded in and out over FADE_S), solved twice (turning the chest
## moves the hands), then the weapon model (`gun`) is laid on the solved line. HuntRun sets want / target / gun / mode.

const SPINE := [["spineb", 0.3], ["spinec", 0.35], ["spined", 0.35]]
const R_PROP := "r_hand_prop_attachment"
const L_PROP := "l_hand_prop_attachment"
const MAX_YAW := deg_to_rad(70.0)
const MAX_PITCH := deg_to_rad(40.0)
const FADE_S := 0.25

## Aim on (the turn fades in), and the world point the weapon is put on.
var want := false
var target := Vector3.INF
## The weapon model laid on the line (top-level while aimed), or null.
var gun: Node3D = null
## "line": a two-hand weapon along the hands (rifle, bow: `grip_left` for the bow held in the left hand); "body": a thrown
## weapon along the chest's facing, in the right hand.
var mode := "line"
var grip_left := false
var weight := 0.0
## The barrel's error to the target after the solve (deg; tests and the look-check log).
var error_deg := 0.0
var _bones: Array = []


static func attach(sk: Skeleton3D) -> HuntAim:
	var a := HuntAim.new()
	a.name = "HuntAim"
	sk.add_child(a)
	return a


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var dt := get_process_delta_time()
	weight = move_toward(weight, 1.0 if want and target != Vector3.INF else 0.0, dt / FADE_S)
	if weight <= 0.0:
		return
	if _bones.is_empty():
		for e: Array in SPINE:
			var i := sk.find_bone(String(e[0]))
			if i >= 0:
				_bones.append([i, float(e[1])])
	var ri := sk.find_bone(R_PROP)
	var li := sk.find_bone(L_PROP)
	if ri < 0 or li < 0 or _bones.is_empty() or not target.is_finite():
		return                               # (no target: the quarry gone while the aim fades out)
	var t := sk.global_transform.affine_inverse() * target
	var w := smoothstep(0.0, 1.0, weight)
	for _pass in 2:
		var line := _line(sk, ri, li)
		var from: Vector3 = line[0]
		var d0: Vector3 = line[1]
		var d1 := (t - from).normalized()
		var q := _limited(d0, d1)
		if q.is_equal_approx(Quaternion.IDENTITY):
			break
		for b: Array in _bones:
			var qi := Quaternion.IDENTITY.slerp(q, float(b[1]) * w)
			_turn(sk, int(b[0]), qi)
	var fin := _line(sk, ri, li)
	error_deg = rad_to_deg((fin[1] as Vector3).angle_to((t - (fin[0] as Vector3)).normalized()))
	if gun != null and is_instance_valid(gun) and gun.visible:
		var up := sk.global_basis * (sk.get_bone_global_pose(int(_bones.back()[0])).basis.y)
		var dir := sk.global_basis * ((t - (fin[0] as Vector3)) if mode == "body" else (fin[1] as Vector3))
		if absf(dir.normalized().dot(up.normalized())) > 0.98:
			up = Vector3.UP
		gun.global_transform = Transform3D(Basis.looking_at(dir.normalized(), up.normalized()), sk.global_transform * (fin[2] as Vector3))


## [where the line starts (skeleton space), its direction, the weapon's grip point] of the weapon's line now.
func _line(sk: Skeleton3D, ri: int, li: int) -> Array:
	var r := sk.get_bone_global_pose(ri).origin
	var l := sk.get_bone_global_pose(li).origin
	if mode == "body":
		var chest := sk.get_bone_global_pose(int(_bones.back()[0]))
		var f := chest.basis.z
		f.y = 0.0
		return [r, f.normalized() if f.length() > 0.01 else Vector3.BACK, r]
	var d := l - r
	if d.length() < 0.05:
		var chest2 := sk.get_bone_global_pose(int(_bones.back()[0]))
		d = chest2.basis.z
	return [r, d.normalized(), l if grip_left else r]


## The turn from `a` to `b` as a yaw about the vertical and a pitch across, each held inside its limit.
static func _limited(a: Vector3, b: Vector3) -> Quaternion:
	var ah := Vector2(a.x, a.z)
	var bh := Vector2(b.x, b.z)
	if ah.length() < 1e-3 or bh.length() < 1e-3:
		return Quaternion.IDENTITY
	var yaw := clampf(-ah.angle_to(bh), -MAX_YAW, MAX_YAW)
	var pa := atan2(a.y, ah.length())
	var pb := atan2(b.y, bh.length())
	var pitch := clampf(pb - pa, -MAX_PITCH, MAX_PITCH)
	var qy := Quaternion(Vector3.UP, yaw)
	var a2 := qy * a
	var axis := Vector3.UP.cross(Vector3(a2.x, 0.0, a2.z)).normalized()
	if axis.length() < 1e-3:
		return qy
	return Quaternion(axis, -pitch) * qy


## Turns bone `i` by `q` (skeleton space) about its own origin.
func _turn(sk: Skeleton3D, i: int, q: Quaternion) -> void:
	var g := sk.get_bone_global_pose(i)
	var ng := Transform3D(Basis(q) * g.basis, g.origin)
	var p := sk.get_bone_parent(i)
	var pg := sk.get_bone_global_pose(p) if p >= 0 else Transform3D()
	var local := pg.affine_inverse() * ng
	sk.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())
