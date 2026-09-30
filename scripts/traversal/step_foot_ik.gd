class_name StepFootIK
extends SkeletonModifier3D
## Our own step over, the legs (user 2026-09-30: "make our own like IK ... just for the lower half where it doesn't affect the
## users in an animation lock ... it needs to be fluid"): while the step assist lifts the body onto a low step
## (TravStepAssist, design 7.9: no clip, nothing owns the pose) each foot is carried to the ground it is over: the foot about to
## cross the step face is lifted over it and set on the top, the foot behind stays on the ground the body has risen from, the
## upper body is the locomotion's and the aim's. A SkeletonModifier3D after the animation; its weight comes in and goes out over
## FADE_S so nothing pops when a step begins or ends.
##
##   var ik := StepFootIK.new(); skeleton.add_child(ik); ik.player = body; ik.stepping = Callable(assist, "stepping")
##
## The feet's end bones keep the animation's rotation (TraversalIK.solve_live); the knees bend the way the body faces.

const LEGS := {
	"l": ["l_upper_leg", "l_knee", "l_ankle"],
	"r": ["r_upper_leg", "r_knee", "r_ankle"],
}
const FADE_S := 0.12
## How fast a foot's lift follows a change of the ground under it (m/s: a step face is 0.4 m).
const FOLLOW_MPS := 5.0
const RAY_UP := 0.6
const RAY_DOWN := 1.0
## The ground this far ahead of the foot (along the body's way) also counts: the swinging foot clears the face before it is over it.
const LOOK_AHEAD_M := 0.2
const MAX_LIFT_M := 0.6

var player: CharacterBody3D
## Callable() -> bool: the step assist is lifting the body.
var stepping := Callable()

var _w := 0.0
var _lift := {"l": 0.0, "r": 0.0}


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or player == null or not is_instance_valid(player):
		return
	var dt := get_process_delta_time()
	var on := stepping.is_valid() and bool(stepping.call())
	_w = move_toward(_w, 1.0 if on else 0.0, dt / FADE_S)
	if _w <= 0.0:
		_lift["l"] = 0.0
		_lift["r"] = 0.0
		return
	var space := player.get_world_3d().direct_space_state
	var floor_y := player.global_position.y
	var fwd := Vector3(player.velocity.x, 0.0, player.velocity.z)
	if fwd.length() < 0.3:
		fwd = -player.global_transform.basis.z
	fwd = fwd.normalized()
	var to_skel := sk.global_transform.affine_inverse()
	for side: String in LEGS:
		var chain: Array = LEGS[side]
		var ua := sk.find_bone(chain[0])
		var lb := sk.find_bone(chain[1])
		var ec := sk.find_bone(chain[2])
		if ua < 0 or lb < 0 or ec < 0:
			continue
		var ga := sk.get_bone_global_pose(ec)
		var wpos := sk.global_transform * ga.origin
		var ground := -INF
		for ahead: float in [0.0, LOOK_AHEAD_M]:
			var o := wpos + fwd * ahead
			var q := PhysicsRayQueryParameters3D.create(Vector3(o.x, wpos.y + RAY_UP, o.z), Vector3(o.x, floor_y - RAY_DOWN, o.z), player.collision_mask)
			q.exclude = [player.get_rid()]
			var hit := space.intersect_ray(q)
			if not hit.is_empty() and float((hit.normal as Vector3).y) > 0.5:
				ground = maxf(ground, float(hit.position.y))
		if ground == -INF:
			ground = floor_y
		var want := clampf(ground - floor_y, -MAX_LIFT_M, MAX_LIFT_M)
		_lift[side] = move_toward(float(_lift[side]), want, FOLLOW_MPS * dt)
		var lift: float = float(_lift[side]) * _w
		if absf(lift) < 0.002:
			continue
		var target_world := wpos + Vector3(0.0, lift, 0.0)
		# the knee bends the way the body faces
		var pole := to_skel.basis * fwd
		TraversalIK.solve_live(sk, ua, lb, ec, ga.origin, to_skel * target_world, 1.0, pole)
