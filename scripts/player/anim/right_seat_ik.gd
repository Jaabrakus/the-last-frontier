class_name RightSeatIK
extends SkeletonModifier3D
## The right hand seated on the wrist of the musket's stock (the user 2026-09-29: "the right hand on the rifle is off,
## not gripping the stock"): the source's clips hold the prop bone, and so the gun, about 3 cm past the palm (the palm
## 4.3 cm off the wood carried, 3.3 aimed: tests/anim hand_grip_meter rhand_gap). After the arms, the aim and the left
## hand's grip (PlayerAnim adds it after them, before TriggerFinger; CharacterBodyMesh stays last), the right wrist
## moves SEAT toward the gun while the gun stays where the clip put it: the shoulder and the elbow re-solved for the new
## wrist, the prop bone put back where it was. The left hand, which holds to the gun, and the aim are untouched.
## PlayerAnim sets `wanted` as for the trigger finger (the musket held as the gun); eased in and out over EASE_S.
## The wrist straightened as well (the user 2026-09-29: "the wrist still bends in weird ways, not natural": the clips'
## hand off its forearm's line by 45 degrees carried, 54 aimed): the hand turned about the wrist of the stock (its
## palm stays on the wood) by up to ROLL_MAX_DEG (further, 50, it cupped the stock from under, the fist open) and the elbow swung about the shoulder -> wrist line by up to
## SWING_MAX_DEG, together, for the least bend of the hand off its forearm (the rest pose's straight wrist) past
## WRIST_EASY_DEG; each dearer the further it goes from the clip's; the elbow kept out of the chest; the index's knuckle
## kept within reach of the trigger (TriggerFinger); eased over TURN_EASE_S.

## How far the gun sits further into the right hand, in the musket model's frame (+X the lock side, +Y up): toward the
## palm, which stood out on the lock side and above the wrist of the stock (the palm then 1.2 cm off the wood: its own
## flesh). The hand moves by the opposite.
const SEAT := Vector3(0.016, 0.026, 0.0)
const EASE_S := 0.15
const WRIST_EASY_DEG := 10.0
const ROLL_MAX_DEG := 20.0
const SWING_MAX_DEG := 70.0
## The search: a coarse grid (ROLL_STEP_DEG, SWING_STEP_DEG), then the best's neighbours at a third of the steps.
const ROLL_STEP_DEG := 5.0
const SWING_STEP_DEG := 10.0
const TURN_EASE_S := 0.08
## The index's knuckle no further than this from the trigger (m).
const TRIGGER_REACH_M := 0.075

var wanted := false
## The model on the right hand's prop bone (FrontierPlayer.musket_offset).
var offset := Transform3D()

var _w := 0.0
var _last_us := 0
var _b := PackedInt32Array()   ## shoulder, elbow, wrist, prop, index knuckle
var _f_local := Vector3.ZERO   ## the forearm's line (elbow -> wrist) in the wrist's frame, the wrist straight (at rest)
var _turn := Vector2.ZERO      ## the hand's roll about the stock and the elbow's swing off the clip's (rad), eased


func _setup(sk: Skeleton3D) -> bool:
	if _b.size() == 5:
		return true
	_b.clear()
	for nm: String in ["r_shoulder", "r_elbow", "r_wrist", "r_hand_prop_attachment", "r_indexa"]:
		var i := sk.find_bone(nm)
		if i < 0:
			return false
		_b.append(i)
	var er := sk.get_bone_global_rest(_b[1])
	var wr := sk.get_bone_global_rest(_b[2])
	_f_local = wr.basis.orthonormalized().inverse() * (wr.origin - er.origin).normalized()
	return true


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or not _setup(sk):
		return
	var now := Time.get_ticks_usec()
	var dt := clampf(float(now - _last_us) / 1e6, 0.0, 0.1) if _last_us > 0 else 0.0
	_last_us = now
	_w = move_toward(_w, 1.0 if wanted else 0.0, dt / EASE_S if dt > 0.0 else 1.0)
	if _w <= 0.0:
		return
	var s := sk.get_bone_global_pose(_b[0])
	var e := sk.get_bone_global_pose(_b[1])
	var w := sk.get_bone_global_pose(_b[2])
	var prop := sk.get_bone_global_pose(_b[3])
	var knuckle := w.affine_inverse() * sk.get_bone_global_pose(_b[4]).origin
	var model := prop * offset
	var stock_p := model.origin
	var stock_d := model.basis.z.normalized()
	var t0: Vector3 = model * (TriggerFinger.TRIGGER[0] as Vector3)
	var t1: Vector3 = model * (TriggerFinger.TRIGGER[1] as Vector3)
	# the hand moves the other way from the gun's seat: the gun (and the prop bone) stay
	var seated := Transform3D(w.basis, w.origin - (prop.basis.orthonormalized() * offset.basis * SEAT) * _w)
	var la := s.origin.distance_to(e.origin)
	var lb := e.origin.distance_to(w.origin)
	var clip_elbow := e.origin - s.origin
	var n_local := _f_local
	var best_c := INF
	var goal := Vector2.ZERO
	for pass_i in 2:
		var rs := []
		var ss := []
		if pass_i == 0:
			var k := -ROLL_MAX_DEG
			while k <= ROLL_MAX_DEG + 1e-3:
				rs.append(deg_to_rad(k))
				k += ROLL_STEP_DEG
			k = -SWING_MAX_DEG
			while k <= SWING_MAX_DEG + 1e-3:
				ss.append(deg_to_rad(k))
				k += SWING_STEP_DEG
		else:
			for i: int in [-1, 0, 1]:
				rs.append(goal.x + deg_to_rad(ROLL_STEP_DEG / 3.0) * i)
				ss.append(goal.y + deg_to_rad(SWING_STEP_DEG / 3.0) * i)
		for r: float in rs:
			var wt := _rolled(seated, stock_p, stock_d, r)
			var kn := wt * knuckle
			var reach := kn.distance_to(Geometry3D.get_closest_point_to_segment(kn, t0, t1))
			var c0 := 0.25 * absf(rad_to_deg(r)) + 0.1 * absf(rad_to_deg(r - _turn.x))
			c0 += 400.0 * maxf(reach - TRIGGER_REACH_M, 0.0)
			var arm := _arm(s.origin, wt.origin, clip_elbow, la, lb)
			if arm.is_empty():
				continue
			var n := (wt.basis.orthonormalized() * n_local).normalized()
			var end: Vector3 = arm.end
			for sw: float in ss:
				var el := _elbow(arm, sw)
				var c := c0 + maxf(rad_to_deg((end - el).normalized().angle_to(n)) - WRIST_EASY_DEG, 0.0)
				c += 0.15 * absf(rad_to_deg(sw)) + 0.1 * absf(rad_to_deg(sw - _turn.y))
				c += 800.0 * maxf(el.x - s.origin.x - 0.02, 0.0)
				if c < best_c:
					best_c = c
					goal = Vector2(r, sw)
	_turn = _turn.lerp(goal, 1.0 - exp(-dt / TURN_EASE_S)) if dt > 0.0 else goal
	var hand := _rolled(seated, stock_p, stock_d, _turn.x * _w)
	var reach_arm := _arm(s.origin, hand.origin, clip_elbow, la, lb)
	if reach_arm.is_empty():
		return
	var elbow := _elbow(reach_arm, _turn.y * _w)
	var q1 := Quaternion((e.origin - s.origin).normalized(), (elbow - s.origin).normalized())
	sk.set_bone_global_pose(_b[0], Transform3D(Basis(q1) * s.basis, s.origin))
	var e2 := sk.get_bone_global_pose(_b[1])
	var w2 := sk.get_bone_global_pose(_b[2])
	var q2 := Quaternion((w2.origin - e2.origin).normalized(), ((reach_arm.end as Vector3) - e2.origin).normalized())
	sk.set_bone_global_pose(_b[1], Transform3D(Basis(q2) * e2.basis, e2.origin))
	# the wrist takes the hand's turn; the prop bone (the gun) goes back where the clip had it
	var w3 := sk.get_bone_global_pose(_b[2])
	sk.set_bone_global_pose(_b[2], Transform3D(hand.basis, w3.origin))
	sk.set_bone_global_pose(_b[3], prop)


## The wrist turned by `r` about the wrist of the stock (the line through `p` along `d`).
static func _rolled(wrist: Transform3D, p: Vector3, d: Vector3, r: float) -> Transform3D:
	var q := Basis(d, r)
	return Transform3D(q * wrist.basis, p + q * (wrist.origin - p))


## The two-bone reach from the shoulder `s` to `target`: {s, end, u, ca, sa, la, pole} (the elbow on the clip's side of
## the shoulder -> wrist line), or {} when the line leaves no side.
static func _arm(s: Vector3, target: Vector3, clip_elbow: Vector3, la: float, lb: float) -> Dictionary:
	var to := target - s
	var d := clampf(to.length(), absf(la - lb) + 1e-3, (la + lb) * 0.999)
	var u := to.normalized()
	var pole := clip_elbow - u * clip_elbow.dot(u)
	if pole.length_squared() < 1e-8:
		return {}
	var ca := clampf((la * la + d * d - lb * lb) / (2.0 * la * d), -1.0, 1.0)
	return {"s": s, "end": s + u * d, "u": u, "ca": ca, "sa": sqrt(1.0 - ca * ca), "la": la, "pole": pole.normalized()}


## The elbow for _arm()'s reach swung `sw` (rad) about the shoulder -> wrist line off the clip's side.
static func _elbow(arm: Dictionary, sw: float) -> Vector3:
	var u: Vector3 = arm.u
	return (arm.s as Vector3) + (u * float(arm.ca) + (arm.pole as Vector3).rotated(u, sw) * float(arm.sa)) * float(arm.la)
