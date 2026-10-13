class_name GuardSpin
extends SkeletonModifier3D
## A guard's body turned with what it sends back (the owner, 2026-10-12: "when put parry i want it to loop around like a moon
## before it fires back"; then, of "a arm ik that guides the parry" or "a body spin", "do and add what u can so we can see what
## it looks like"): while a bolt or a flying stone his guard took swings round him (BendBolt.begin_swing, GustLift.begin_swing: a
## Parry's or a Wind Guard's moon, a water Turn's swing) his whole body turns with it, one full turn about his own upright (the
## swing's way round), and his lead hand reaches after it, open, as if he steered it round (the right; a "both" guard's left
## follows it at LEFT_W: air's and water's); as it leaves along his aim he faces his aim again, the hand thrown after it, eased
## back to the clip over BACK_S. A swing held on (Eye of the Gale, Whirl Turn) turns him on with it; let go, he turns on to the
## nearest whole turn over SETTLE_S.
## Visual only: the skeleton's bones after the cast's clip (SwayPose's ToolPose, a bot's AnimationPlayer, the aim) and before
## CharacterBodyMesh (its helpers follow: put_last); his body's facing, his aim, his camera and his colliders are untouched.
## follow(body, thing) at the swing's start on every machine (a ghost's swing begins on the host's word too).
##   GuardSpin.follow(guard_body, bolt_or_lift)     # thing: swing_u() 0..1 (-1 over), swing_point() world

const NODE_NAME := "GuardSpin"
## The lead hand's reach toward it (share of the arm's length from the shoulder: the elbow a little soft).
const REACH := 0.9
## The reach comes in over this long (s) from the swing's start.
const IN_S := 0.08
## After the swing: the hand thrown after it this long (s), then eased back to the clip over BACK_S.
const FOLLOW_S := 0.1
const BACK_S := 0.25
## A held swing let go part way round: the turn carried on (or back) to the nearest whole turn over this long (s).
const SETTLE_S := 0.12
## A "both" guard's trailing hand: this share of the lead's weight, after the same thing.
const LEFT_W := 0.6

## What swings round him now (a BendBolt or a GustLift; null none), and whether a swing is on.
var thing: Object = null
var on := false
## The turn put on him now (rad about his upright; the tests) and the hand's weight.
var turn := 0.0
var reach_w := 0.0
## Which hands reach: "r", or "both".
var hands := "r"
var _t := 0.0
var _after := -1.0
var _settle_from := 0.0
var _settle_to := 0.0
var _last_point := Vector3.INF
var _root := -2
var _ik: ReachIK


## Body `body`'s spin with `p_thing` swinging round him from now (see the header). Nothing without a skeleton.
static func follow(body: Node, p_thing: Object) -> void:
	if body == null or not is_instance_valid(body) or p_thing == null:
		return
	var sk := skeleton_of(body)
	if sk == null:
		return
	var gs := sk.get_node_or_null(NODE_NAME) as GuardSpin
	if gs == null:
		gs = GuardSpin.new()
		gs.name = NODE_NAME
		sk.add_child(gs)
	gs.thing = p_thing
	gs.on = true
	gs.active = true
	gs._t = 0.0
	gs._after = -1.0
	gs.hands = "r" if BendPoses.element_of(body) == "fire" else "both"
	SwayPose.put_last(sk, gs)


## The GuardSpin on `body` (null none yet).
static func of(body: Node) -> GuardSpin:
	var sk := skeleton_of(body)
	return sk.get_node_or_null(NODE_NAME) as GuardSpin if sk != null else null


## `body`'s skeleton: the player's (Player.skeleton), a fighter's body's (NpcBody.sk), else the first under it.
static func skeleton_of(body: Node) -> Skeleton3D:
	if body == null or not is_instance_valid(body):
		return null
	var v: Variant = body.get(&"skeleton")
	if v is Skeleton3D:
		return v as Skeleton3D
	var nb: Variant = body.get(&"body")
	if nb is Object and is_instance_valid(nb) and (nb as Object).get(&"sk") is Skeleton3D:
		return (nb as Object).get(&"sk") as Skeleton3D
	var found := body.find_children("*", "Skeleton3D", true, false)
	return found[0] as Skeleton3D if not found.is_empty() else null


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _ik != null:
		_ik.free()


func _process(dt: float) -> void:
	if not on:
		return
	_t += dt
	var u := -1.0
	if thing != null and is_instance_valid(thing) and thing.has_method(&"swing_u"):
		u = float(thing.call(&"swing_u"))
		var p: Vector3 = thing.call(&"swing_point")
		if p.is_finite():
			_last_point = p
	if u >= 0.0 and _after < 0.0:
		turn = -TAU * _ease(u)
		reach_w = smoothstep(0.0, IN_S, _t)
	else:
		if _after < 0.0:
			# (the swing over: on from where it was to the nearest whole turn, the way it was going when past half a turn)
			_after = 0.0
			_settle_from = fmod(turn, TAU)
			_settle_to = -TAU if _settle_from < -PI else 0.0
		_after += dt
		turn = lerpf(_settle_from, _settle_to, smoothstep(0.0, SETTLE_S, _after))
		reach_w = 1.0 - smoothstep(FOLLOW_S, FOLLOW_S + BACK_S, _after)
		if _after >= FOLLOW_S + BACK_S and _after >= SETTLE_S:
			on = false
			active = false
			turn = 0.0
			reach_w = 0.0
			thing = null
			return
	var sk := get_skeleton()
	if sk != null and _behind(sk):
		SwayPose.put_last(sk, self)            # (a cast's pose put after it meanwhile: back over it)


## Whether another modifier (but the body's own, CharacterBodyMesh) runs after this one on `sk` now.
func _behind(sk: Skeleton3D) -> bool:
	for i in range(get_index() + 1, sk.get_child_count()):
		var c := sk.get_child(i)
		if c is SkeletonModifier3D and not (c is CharacterBodyMesh):
			return true
	return false


## The swing's share of the turn at `u` (0..1, on past 1 while held): a little eased at both ends, linear past the first lap.
static func _ease(u: float) -> float:
	if u >= 1.0:
		return u
	return lerpf(u, smoothstep(0.0, 1.0, u), 0.5)


func _process_modification() -> void:
	if not on:
		return
	var sk := get_skeleton()
	if sk == null:
		return
	if _root == -2:
		_root = sk.find_bone("root")
	if _root < 0:
		return
	# the whole body turned about its root's upright (the hips' vertical: the feet pivot on the spot)
	if absf(turn) > 1e-5:
		var g := sk.get_bone_global_pose(_root)
		sk.set_bone_global_pose(_root, Transform3D(Basis(Vector3.UP, turn) * g.basis, g.origin))
	if reach_w <= 1e-3 or not _last_point.is_finite():
		return
	if _ik == null:
		_ik = ReachIK.new()
	var target := sk.global_transform.affine_inverse() * _last_point
	for side: String in (["r", "l"] if hands == "both" else ["r"]):
		var sh := sk.find_bone(side + "_shoulder")
		var el := sk.find_bone(side + "_elbow")
		var wr := sk.find_bone(side + "_wrist")
		if sh < 0 or el < 0 or wr < 0:
			continue
		var a := sk.get_bone_global_pose(sh).origin
		var arm := a.distance_to(sk.get_bone_global_pose(el).origin) + sk.get_bone_global_pose(el).origin.distance_to(
				sk.get_bone_global_pose(wr).origin)
		var to := target - a
		if to.length_squared() < 1e-6:
			continue
		var want := a + to.normalized() * arm * REACH
		_ik.apply_side(sk, side, want, reach_w * (1.0 if side == "r" else LEFT_W))
