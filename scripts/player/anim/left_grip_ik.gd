class_name LeftGripIK
extends ReachIK
## Keeps the left hand on a long gun's forestock (user playtest 2026-09-24/25: "crouch left hand rifle
## holding is off", "the left hand raises higher than where the gun is"; 2026-09-25 night: "the gun
## bounces in the left hand when we move").
##
## Why: where the source animation holds the long gun with both hands (aim, idle carry, crouch idle,
## reload), its two hand prop bones coincide: l_hand_prop_attachment sits exactly on
## r_hand_prop_attachment, the gun's origin, and the left palm lands on our musket's forestock
## (tests/anim/test_hand_grips.gd: 0-1.6 cm). The moving carries play the carry arm layers at 0.8-0.9
## over the locomotion clip (actor_b-p-rifle-idle-arms walking, actor_b-p-rifle-run-arms jogging and
## sprinting, actor_b-p-rifle-crouch-run-arms crouch-walking): a fifth of the empty-handed arm swing
## mixes into both arms, so the left hand floats off the gun and slides along it with every step (in
## the level, before push n01: the left palm 13-35 cm off its grip point walking, jogging, sprinting,
## turning and stopping; tests/anim/test_weapon_holds.gd). This IK keeps the hand on the gun
## during those moving carries.
##
## How: with weight w, the left wrist turns so that the left prop bone takes the right prop bone's
## rotation, then the arm (shoulder, elbow) is solved so the left prop origin reaches the right prop
## origin. Where the clip already has both hands on the gun (the idles) this moves nothing. The weight
## follows `enabled` over FADE_S (smoothstep), so the hand leaves and returns without a pop when an aim,
## a reload, a draw or the one-hand carry takes it off the gun.
## Elbow: the arm is solved in its bend plane (the upper arm's own twist kept, the forearm hinging), the
## elbow on the clip's own side carried over to the new shoulder -> hand line, held inside a band that hangs
## down and out (user playtest 2026-09-25: "the 2 hand holding of the crouch move the left elbow is inward and
## not out ward": the crouch-walk clip's elbow swung round in front of the chest, and the earlier "out and
## down" grip pole used Godot's Vector3.LEFT, which is the character's RIGHT on this rig: it faces skeleton
## +Z, its left is skeleton +X). The side turns at most SIDE_RATE, so it never flips.
## Order: after PropFlipGuard, AimStabilizer, the arm poses and GunCarryDamper (they move the gun or the
## arm), before CharacterBodyMesh (it keeps itself last).

## Seconds for the grip to come on or off.
const FADE_S := 0.2
## Fraction of the left arm's straight length (shoulder -> elbow -> wrist) it may reach; beyond
## it the right arm brings the gun in (the standing crouch change and the start of the aim raise hold
## the gun 0.6 m from the left shoulder, 13 cm past the left hand's reach).
const REACH_FRAC := 0.97
## The right arm's pull starts this far (m) inside the left arm's reach and grows without a corner.
const REACH_SOFT_M := 0.05
## The left elbow's bend side about the shoulder -> hand line (deg), in the chest's frame: 0 = toward the
## hips, +90 = out to the character's left, away from the body; -90 = in across the chest. Inside this band
## the clip's own side is kept (the source's two-hand holds: the standing carries 18-40, the crouch-walk carry
## arm 24-38, the crouch idle 38-54); outside it the nearer edge, blending over ELBOW_SIDE_SOFT_DEG into the
## preferred side (down and a little out, as the source's own carries hold it).
const ELBOW_SIDE_MIN_DEG := -10.0
const ELBOW_SIDE_MAX_DEG := 60.0
const ELBOW_SIDE_PREF_DEG := 30.0
const ELBOW_SIDE_SOFT_DEG := 25.0
## Walking and jogging the gun is carried this far further out before the chest (m, the chest's forward; added to
## the gun's target through pull_in(), so GunCarryDamper's spring carries it out and back): with the hand close
## before the chest the left elbow sat at the torso's side, in the shirt (the hand 10-27 cm before the shoulder);
## reaching forward to the stock, the elbow comes level with the torso's front or before it, still pointing out
## (user 2026-09-29: "the elbow does need to point out but the elbow arm need to be forward align torso or in front
## of torso"). Standing holds (`moving` 0) are as they were.
const CARRY_FORWARD_M := 0.12
## Fastest turn of the grip's bend side about the shoulder-target line (rad/s).
const SIDE_RATE := 6.0
## The wrist correction at full weight up to this turn (deg), none from WRIST_TURN_NONE.
const WRIST_TURN_FULL := 110.0
const WRIST_TURN_NONE := 160.0

## Grip wanted (set every frame by PlayerAnim).
var enabled := false
## 0 standing .. 1 walking or jogging (set every frame by PlayerAnim, eased): the gun carried CARRY_FORWARD_M out.
var moving := 0.0
## Current grip weight 0..1 (after the fade).
var grip_weight := 0.0
## The elbow side used last frame and the clip's own carried over (deg, see ELBOW_SIDE_MIN_DEG), for tests
## and the debug view.
var elbow_side_deg := 0.0
var elbow_clip_deg := 0.0
## How far the right arm brought the gun in last frame for the left hand to reach it (m).
var reach_pull := 0.0

var _lin := 0.0
var _ids := PackedInt32Array()
var _dt := 1.0 / 60.0
## The bend side and the shoulder -> target line kept between frames (in the chest's frame).
var _side_chest := Vector3.ZERO
var _dir_chest := Vector3.FORWARD
var _have_side := false
## The chest's (spined) left and down axes in its own frame (from the rest pose).
var _chest_left := Vector3.RIGHT
var _chest_down := Vector3.DOWN
var _chest_fwd := Vector3.BACK


func advance(dt: float) -> void:
	# the swivel's rate limit steps once per animation step (see _grip_side())
	_dt = maxf(dt, 0.0)
	_lin = move_toward(_lin, 1.0 if enabled else 0.0, dt / FADE_S)
	grip_weight = smoothstep(0.0, 1.0, _lin)


## Takes the wanted weight at once (no fade).
func snap() -> void:
	_lin = 1.0 if enabled else 0.0
	grip_weight = _lin
	_have_side = false


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if grip_weight <= 0.0:
		_have_side = false
		return
	var g := _grip(sk)
	if g.is_empty():
		return
	sk.set_bone_global_pose(_ids[0], Transform3D(Basis(g.q as Quaternion), sk.get_bone_global_pose(_ids[0]).origin))
	_solve_left(sk, sk.get_bone_global_pose(_ids[2]).origin, grip_weight)


## How far the gun must come toward the left shoulder for the left hand to reach it (the right arm, see
## REACH_FRAC) with this frame's grip weight (skeleton space, m; sets reach_pull), without moving it:
## GunCarryDamper adds it to the gun's target, so the pull is smoothed with the rest of the gun's motion and
## the right arm is solved once. Whatever is left (the smoothed gun lags) this modifier pulls in itself.
func pull_in(sk: Skeleton3D) -> Vector3:
	if grip_weight <= 0.0:
		return Vector3.ZERO
	var g := _grip(sk, false)
	var pull: Vector3 = g.get("pull", Vector3.ZERO)
	if moving > 0.0 and not _ids.is_empty():
		var fwd := sk.get_bone_global_pose(_ids[5]).basis.orthonormalized() * _chest_fwd
		fwd.y = 0.0
		if fwd.length() > 1e-3:
			pull += fwd.normalized() * CARRY_FORWARD_M * smoothstep(0.0, 1.0, moving) * grip_weight
	return pull


## The left wrist's grip rotation {q} (the left prop takes the right prop's rotation) and the gun's pull
## {pull} within the left arm's reach: beyond it (shoulder -> elbow -> wrist, REACH_FRAC) the right arm brings
## the gun (its rotation unchanged) toward the left shoulder, moved there when `apply`. {} when a bone is
## missing.
func _grip(sk: Skeleton3D, apply := true) -> Dictionary:
	if _ids.is_empty():
		for bn in ["l_wrist", "l_hand_prop_attachment", "r_hand_prop_attachment", "l_shoulder", "l_elbow", "spined"]:
			var b := sk.find_bone(bn)
			if b < 0:
				return {}
			_ids.append(b)
		var rest := sk.get_bone_global_rest(_ids[5]).basis.orthonormalized()
		_chest_left = (rest.inverse() * Vector3.RIGHT).normalized()
		_chest_down = (rest.inverse() * Vector3.DOWN).normalized()
		_chest_fwd = (rest.inverse() * Vector3.BACK).normalized()
	var gw := sk.get_bone_global_pose(_ids[0])
	var gl := sk.get_bone_global_pose(_ids[1])
	var gr := sk.get_bone_global_pose(_ids[2])
	# Wrist rotation that gives the left prop the right prop's rotation (the prop is rigid under the wrist).
	var rel := gw.affine_inverse() * gl
	var want := (gr * rel.affine_inverse()).basis.orthonormalized()
	# A wrist turn near half a turn is no grip (its shortest way round flips side as it passes 180 deg: a
	# 250 rad/s wrist snap standing up while running backward); the turn fades out from WRIST_TURN_FULL.
	var q0 := gw.basis.orthonormalized().get_rotation_quaternion()
	var q1 := want.get_rotation_quaternion()
	var turn_deg := rad_to_deg(q0.angle_to(q1))
	var wq := grip_weight * (1.0 - smoothstep(WRIST_TURN_FULL, WRIST_TURN_NONE, turn_deg))
	var q := q0.slerp(q1, wq)
	# Where the wrist must be for the left prop to reach the gun; the pull comes in over the last
	# REACH_SOFT_M with no corner (a hard `d - reach` jolted the gun 0.4-2.3 m/s in a frame as it came and went).
	var sh := sk.get_bone_global_pose(_ids[3]).origin
	var el := sk.get_bone_global_pose(_ids[4]).origin
	var reach := (sh.distance_to(el) + el.distance_to(gw.origin)) * REACH_FRAC
	var wrist_at := gr.origin - Basis(q) * rel.origin
	var over := sh.distance_to(wrist_at) - (reach - REACH_SOFT_M)
	reach_pull = 0.0
	if over > 0.0:
		reach_pull = over - REACH_SOFT_M * (1.0 - exp(-over / REACH_SOFT_M))
	var pull := Vector3.ZERO
	if reach_pull > 1e-5:
		pull = (sh - wrist_at).normalized() * reach_pull * grip_weight
		if apply:
			apply_side(sk, "r", gr.origin + pull, 1.0)
	return {"q": q, "pull": pull}


## Two-bone solve of the left arm (shoulder, elbow; the wrist keeps its rotation) so the left prop
## origin goes `w` of the way to `target` (skeleton space), the elbow turned by `w` from the clip's bend
## side to the grip's (the clip's side kept inside the ELBOW_SIDE band).
func _solve_left(sk: Skeleton3D, target: Vector3, w: float) -> void:
	var sh := _ids[3]
	var el := _ids[4]
	var wr := _ids[0]
	var gs := sk.get_bone_global_pose(sh)
	var ge := sk.get_bone_global_pose(el)
	var gw := sk.get_bone_global_pose(wr)
	var gp := sk.get_bone_global_pose(_ids[1])
	var a := gs.origin
	var b := ge.origin
	var c := gw.origin
	var tw := c + (target - gp.origin) * w
	var la := a.distance_to(b)
	var lb := b.distance_to(c)
	var ac := tw - a
	var lt := clampf(ac.length(), absf(la - lb) + 1e-4, (la + lb) * MAX_REACH)
	var dir := ac.normalized() if ac.length() > 1e-6 else (c - a).normalized()
	tw = a + dir * lt
	var chest := sk.get_bone_global_pose(_ids[5]).basis.orthonormalized()
	var pole := _grip_side(chest, dir, (c - a).normalized(), b - a, w)
	var cos_a := clampf((la * la + lt * lt - lb * lb) / (2.0 * la * lt), -1.0, 1.0)
	var b_new := a + dir * la * cos_a + pole * la * sqrt(maxf(1.0 - cos_a * cos_a, 0.0))
	# The upper arm turns so that its direction AND its bend plane go where the solve puts them (the arm's
	# own twist about the bend plane kept), then the forearm hinges in that plane. The shortest-arc turns
	# used before twisted the arm by whatever the arc's axis happened to be: where the grip moves the hand far
	# from the animation's (a sprint, a reversal with the gun swung), the arc neared half a turn and the elbow
	# spun 1.5 rad in a frame (test_continuity's storm: 170-180 rad/s).
	var u0 := (b - a).normalized()
	var f0 := (c - b).normalized()
	var u1 := (b_new - a).normalized()
	var f1 := (tw - b_new).normalized()
	var n0 := u0.cross(f0)
	var n1 := u1.cross(f1)
	if n0.length() > 0.05 and n1.length() > 0.05:
		n0 = n0.normalized()
		n1 = n1.normalized()
		var rot := Basis(u1, n1, u1.cross(n1)) * Basis(u0, n0, u0.cross(n0)).transposed()
		sk.set_bone_global_pose(sh, Transform3D(rot * gs.basis, a))
		var ge2 := sk.get_bone_global_pose(el)
		var fr := (rot * f0).normalized()
		var hinge := Basis(n1, fr.signed_angle_to(f1, n1))
		sk.set_bone_global_pose(el, Transform3D(hinge * ge2.basis, ge2.origin))
	else:
		# a straight arm has no bend plane: the shortest arcs
		var q1 := _arc(u0, u1)
		sk.set_bone_global_pose(sh, Transform3D(Basis(q1) * gs.basis, a))
		var ge2 := sk.get_bone_global_pose(el)
		var c2 := sk.get_bone_global_pose(wr).origin
		var q2 := _arc((c2 - ge2.origin).normalized(), (tw - ge2.origin).normalized())
		sk.set_bone_global_pose(el, Transform3D(Basis(q2) * ge2.basis, ge2.origin))
	sk.set_bone_global_pose(wr, Transform3D(gw.basis, sk.get_bone_global_pose(wr).origin))


## The grip's bend side (unit, perpendicular to `dir`, the shoulder -> target line). The clip's own elbow side
## (`clip_elbow` = elbow - shoulder, about the clip's shoulder -> wrist line `clip_dir`) carried over to `dir`
## by the shortest turn between the two lines: it stays the clip's side however far the grip moves the hand
## (measured about the new line it turned up to 180 deg when the hand moved 15-35 cm). Turned by `w` into the
## ELBOW_SIDE band where the band's frame is sound, then from last frame's side (itself carried along as the
## line moves) at most SIDE_RATE. No angle is kept in a frame: every frame built on a body axis has a pole
## some carry reaches (the chest's left at a sprint's take-off, the chest's down in the crouch-walk, down-and-
## out at a landing), and an angle kept in it spun the elbow 30-45 cm in a frame there.
func _grip_side(chest: Basis, dir: Vector3, clip_dir: Vector3, clip_elbow: Vector3, w: float) -> Vector3:
	var v := clip_elbow - clip_dir * clip_elbow.dot(clip_dir)
	var goal := Vector3.ZERO
	if v.length() > 0.02 and clip_dir.dot(dir) > -0.9:
		goal = Quaternion(clip_dir, dir) * v.normalized()
	elif _have_side:
		goal = chest * _side_chest
	goal = goal - dir * goal.dot(dir)
	var ax := side_axes(chest * _chest_left, chest * _chest_down, dir)
	if goal.length() < 1e-4:
		goal = (ax[1] as Vector3) if not ax.is_empty() else dir.cross(Vector3.UP)
	goal = goal.normalized()
	if not ax.is_empty():
		var kb: float = ax[2]
		var phi := rad_to_deg(atan2(goal.dot(ax[0]), goal.dot(ax[1])))
		elbow_clip_deg = phi
		var lo := ELBOW_SIDE_MIN_DEG
		var hi := ELBOW_SIDE_MAX_DEG
		var phi_c := phi
		if phi < lo or phi > hi:
			# Outside the band: the nearer edge, blending into the preferred side as the clip's side goes further
			# out (continuous everywhere: an edge-to-edge switch flipped the grip's elbow 50 deg in a frame).
			var d_lo := fposmod(lo - phi, 360.0)
			var d_hi := fposmod(phi - hi, 360.0)
			var edge := lo if d_lo <= d_hi else hi
			phi_c = lerpf(edge, ELBOW_SIDE_PREF_DEG, clampf(minf(d_lo, d_hi) / ELBOW_SIDE_SOFT_DEG, 0.0, 1.0))
		# the grip's weight (and the frame's soundness) turn the elbow from the clip's side into the band
		goal = goal.rotated(dir, deg_to_rad(wrapf(phi_c - phi, -180.0, 180.0)) * w * kb).normalized()
	# continuity: last frame's side, carried along with the line, turned toward the goal at most SIDE_RATE
	var side := goal
	if _have_side:
		var prev := chest * _side_chest
		var pdir := chest * _dir_chest
		if pdir.dot(dir) > -0.9:
			prev = Quaternion(pdir.normalized(), dir) * prev
		prev = prev - dir * prev.dot(dir)
		if prev.length() > 1e-4:
			prev = prev.normalized()
			var stepmax := SIDE_RATE * _dt
			side = prev.rotated(dir, clampf(prev.signed_angle_to(goal, dir), -stepmax, stepmax)).normalized()
	_side_chest = chest.inverse() * side
	_dir_chest = chest.inverse() * dir
	_have_side = true
	_dt = 0.0
	if not ax.is_empty():
		elbow_side_deg = rad_to_deg(atan2(side.dot(ax[0]), side.dot(ax[1])))
	return side


## The frame the elbow's side is measured in, about the shoulder -> hand line `dir`: [out, down, sound].
## `down` (0 deg) is toward the hips and `out` (+90 deg) toward the character's left, both perpendicular to
## `dir`: the preferred side (ELBOW_SIDE_PREF_DEG from the chest's `down` toward its `left`) without its part
## along `dir`, turned back about `dir` by ELBOW_SIDE_PREF_DEG, and out = dir x down. `sound` (0..1) fades the
## band out near the frame's pole (the arm along the preferred side: the hand down and out from the shoulder,
## as in the crouch idle, where the clip's own side is inside the band anyway). [] at the pole.
## (review n01: the frame was built on the chest's left alone, with down = out x dir, which points UP whenever
## the hand is behind the shoulder's frontal plane: the walk start's upright gun and the jog's grip at the
## shoulder had the band hold the elbow up to 24 cm over the shoulder.)
static func side_axes(left: Vector3, down: Vector3, dir: Vector3) -> Array:
	var r := deg_to_rad(ELBOW_SIDE_PREF_DEG)
	var pref := (down * cos(r) + left * sin(r)).normalized()
	var p := pref - dir * pref.dot(dir)
	if p.length() < 0.05:
		return []
	var d := p.normalized().rotated(dir, -r).normalized()
	return [dir.cross(d).normalized(), d, smoothstep(0.2, 0.4, p.length())]
