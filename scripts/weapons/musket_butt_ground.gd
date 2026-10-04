class_name MusketButtGround
extends SkeletonModifier3D
## The musket's butt on the real ground while it rests there in the reload (user 2026-10-01: "we need IK on the rifle where it
## sticks to the ground on crouch movements, or drags"): the reload clips (MusketReload) set the butt down behind the player for
## the ramrod; posed on flat ground, it went through a slope or floated over a dip, and slid along with the body when the player
## moved. Here, while the reload has the butt down (MusketReload: from the gun cast about into the ramming place until it is
## raised again, whatever height the game's own crouch or walk puts the clip's butt at):
##   - the butt is planted where it came down (world space) and stays there while the body moves, until the body has gone
##     DRAG_M from it; then it is dragged along behind at that distance (a butt on the ground, not on skates);
##   - its height is the ground's under it (a ray down), so it sits on slopes and steps;
##   - the gun turns about the right fist (the hand holding the barrel while the left works the ramrod, user 2026-10-01; while
##     the powder is poured it is at the muzzle): a ball joint, to put the butt there; the left hand, on the barrel or the
##     ramrod (in the gun's frame), is carried round with it.
## After MusketReloadPose (the reload's ToolPose); MusketReload feeds it each frame (feed()).

## The butt plate's toe in the musket model's frame (tools/anim_author/author_reload.gd BUTT).
const BUTT := Vector3(0.0, -0.07, 0.29)
## The most the gun is turned to reach the ground (deg): further (a ledge, a deep hollow) and the hold lets go.
const MAX_TURN_DEG := 40.0
## How far (m, along the ground) the body may move from the planted butt before it drags.
const DRAG_M := 0.18
## How fast the hold comes in and lets go (s).
const FADE_S := 0.12

var weight := 0.0                 ## the reload pose's weight times how much the reload has the butt down
var model_offset := Transform3D() ## the gun model on the right hand's prop bone (Player.musket_offset)
var body: CollisionObject3D

var _ids := {}
var _w := 0.0
var _planted := false
var _at := Vector3.ZERO           ## the planted butt, world


func feed(p_weight: float, p_offset: Transform3D, p_body: CollisionObject3D) -> void:
	weight = p_weight
	model_offset = p_offset
	body = p_body


func _bone(sk: Skeleton3D, n: String) -> int:
	if not _ids.has(n):
		_ids[n] = sk.find_bone(n)
	return int(_ids[n])


func _dt() -> float:
	return get_physics_process_delta_time() if Engine.is_in_physics_frame() else get_process_delta_time()


## The ground's height under a world point (NAN: none within reach).
func _ground(p: Vector3) -> float:
	if body == null or not body.is_inside_tree():
		return NAN
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.6, p + Vector3.DOWN * 1.2)
	q.exclude = [body.get_rid()]
	var hit := body.get_world_3d().direct_space_state.intersect_ray(q)
	return NAN if hit.is_empty() else float((hit.position as Vector3).y)


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var prop := _bone(sk, "r_hand_prop_attachment")
	var rw := _bone(sk, "r_wrist")
	if prop < 0 or rw < 0:
		return
	var gx := sk.global_transform
	var inv := gx.affine_inverse()
	var pg := sk.get_bone_global_pose(prop)
	var butt := gx * (pg * model_offset * BUTT)          # the clip's butt, world
	var gy := _ground(butt)
	var engage := weight if not is_nan(gy) else 0.0
	_w = move_toward(_w, engage, _dt() / FADE_S)
	if _w <= 0.001:
		_planted = false
		return
	# the planted point: where it came down, dragged behind once the body is DRAG_M away, on the ground under it
	var want := Vector3(butt.x, gy, butt.z)
	if not _planted:
		# (no ground under the clip's butt while the hold fades out, the gun coming up as a sprint ends the reload: nothing to
		# plant it on. Planted there, the point was NaN and the solve below logged errors every frame until the hold was gone;
		# found 2026-10-03 with the reload on the jog's legs, user: "the current reload legs for pistol and guns need to be
		# replaced with the jog ones", and as it was at the aim walk's pace)
		if is_nan(gy):
			return
		_at = want
		_planted = true
	var d := Vector2(_at.x - want.x, _at.z - want.z)
	if d.length() > DRAG_M:
		d = d.normalized() * DRAG_M
		_at = Vector3(want.x + d.x, _at.y, want.z + d.y)
	var g2 := _ground(_at)
	if not is_nan(g2):
		_at.y = g2
	# the gun turned about the left fist to put the butt there (blended by the hold's weight). The butt is a fixed reach from
	# the fist (the gun is rigid), so it goes where that reach meets the ground, on the planted point's side of the fist;
	# that is where it is planted from now on (it slides only in and out from the fist as the hand rises and falls)
	var piv := gx * (sk.get_bone_global_pose(rw) * MusketReload.FIST_HOLE).origin
	var va := butt - piv
	var reach := va.length()
	var drop := piv.y - _at.y
	if reach < 0.05 or drop >= reach:
		_planted = false
		return
	var side := Vector2(_at.x - piv.x, _at.z - piv.z)
	if side.length() < 1e-3:
		side = Vector2(va.x, va.z)
	side = side.normalized() * sqrt(reach * reach - drop * drop)
	_at = Vector3(piv.x + side.x, _at.y, piv.z + side.y)
	var vd := _at - piv
	var turn := Quaternion(va.normalized(), vd.normalized())
	var over := 1.0 - smoothstep(MAX_TURN_DEG * 0.75, MAX_TURN_DEG, rad_to_deg(turn.get_angle()))
	if over <= 0.0:
		_planted = false
		return
	turn = Quaternion.IDENTITY.slerp(turn, _w * over)
	var turn_s := Basis(inv.basis.orthonormalized() * Basis(turn) * gx.basis.orthonormalized())   # in the skeleton's space
	var piv_s := inv * piv
	var new_prop := Transform3D(turn_s * pg.basis, piv_s + turn_s * (pg.origin - piv_s))
	# the left hand round with it (on the barrel or the rod, in the gun's frame), then the gun set on the right hand
	var sh := _bone(sk, "l_shoulder")
	var el := _bone(sk, "l_elbow")
	var wr := _bone(sk, "l_wrist")
	if sh >= 0 and el >= 0 and wr >= 0:
		var hw := sk.get_bone_global_pose(wr).origin
		TraversalIK.solve_live(sk, sh, el, wr, hw, piv_s + turn_s * (hw - piv_s), 1.0)
	var par := sk.get_bone_parent(prop)
	var parg := sk.get_bone_global_pose(par) if par >= 0 else Transform3D.IDENTITY
	var loc := parg.affine_inverse() * new_prop
	sk.set_bone_pose_rotation(prop, loc.basis.orthonormalized().get_rotation_quaternion())
	sk.set_bone_pose_position(prop, loc.origin)
