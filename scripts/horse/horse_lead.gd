class_name HorseLead
extends Node
## Leading a horse on foot (user 2026-09-26): E at the horse's head -- "Lead horse" -- and it follows the player
## on a lead rope from its bit to the player's right hand: at a walk, a trot when the player runs (a canter only
## to catch up from far behind), coming up on the player's right and stopping when the player stops, and
## steering round trees, rocks and walls in its way. E at its head again -- "Stay" -- and it stands where it is.
## Mounting it, or the player's death, ends the lead. It drives the horse through Horse.drive() as a rider does,
## so the gaits, the hills (HorseTerrain) and a load on its chain (HorseHaul) hold as when it is ridden.
## Every rideable horse has one (HorseMount.attach_to).
##
## Steering: the heading to the place beside the leader, plus three feelers (rays at chest height, ahead and
## WHISKER_DEG either side, LOOK_M plus a second at the current speed): something ahead turns it to the freer
## side and slows it; something on one side turns it away. A horse held up (wanting to go, not moving) for
## STUCK_S turns toward the freer side before it goes on.

## The head stops this far from the place it follows to (m).
const FOLLOW_M := 1.6
## The rope from the bit to the hand; farther apart it hangs from the bit (the horse follows on its own).
const ROPE_M := 2.8
## Catch-up speed per metre behind (1/s).
const GAIN := 0.9
## The horse walks at the leader's right, its head this far out from his line.
const SIDE_M := 0.9
const WHISKER_DEG := 32.0
const LOOK_M := 2.2
const STUCK_S := 1.2
## Trot at most, unless this far behind (m): then a canter to catch up.
const CANTER_GAP := 4.5

var horse: Horse
var leading := false
var leader: Node3D = null
var interact_reach := 2.4
## Last steering (tests): toward the place, and the feelers' share.
var steer_goal := 0.0
var steer_avoid := 0.0
var want_speed := 0.0

var _dir := Vector3.ZERO
var _moving := false
var _stuck_t := 0.0
var _unstick_t := 0.0
var _unstick_dir := 1.0
var _feel := [INF, INF, INF]
var _tick := 0
var _rope: MeshInstance3D
var _rope_mesh: ImmediateMesh
var _ray: PhysicsRayQueryParameters3D


static func attach_to(h: Horse) -> HorseLead:
	var l := HorseLead.new()
	l.name = "Lead"
	l.horse = h
	h.add_child(l)
	return l


func _ready() -> void:
	add_to_group(PlacedWeapon.GROUP)
	_rope_mesh = ImmediateMesh.new()
	_rope = MeshInstance3D.new()
	_rope.name = "LeadRope"
	_rope.mesh = _rope_mesh
	_rope.top_level = true
	_rope.visible = false
	_rope.material_override = HorseHaul._mat("rope", Color(0.46, 0.38, 0.26), 0.0, 0.9)
	add_child(_rope)


## Takes the lead: the horse follows `p`.
func start(p: Node3D) -> void:
	leader = p
	leading = true
	_moving = false
	_stuck_t = 0.0
	_dir = Vector3.ZERO


## "Stay": the horse stops and stands.
func stop() -> void:
	leading = false
	leader = null
	_moving = false
	want_speed = 0.0
	if horse:
		horse.drive(0.0, 0.0)
	if _rope:
		_rope.visible = false


func _mount_rider() -> Variant:
	var m := horse.get_node_or_null("Mount")
	return m.get("rider") if m else null


func _physics_process(delta: float) -> void:
	if not leading:
		return
	if leader == null or not is_instance_valid(leader) or (leader.get("is_dead") == true) or leader.get("riding") != null \
			or _mount_rider() != null:
		stop()
		return
	_follow(delta)
	_draw_rope()


func _follow(delta: float) -> void:
	var me := horse.global_position
	var fwd := -horse.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var head := bit_point()
	var lp := leader.global_position
	var lv: Vector3 = leader.get("velocity") if leader.get("velocity") != null else Vector3.ZERO
	lv.y = 0.0
	var lspeed := lv.length()
	if lspeed > 0.4:
		var d := lv / lspeed
		_dir = d if _dir == Vector3.ZERO else _dir.lerp(d, 1.0 - exp(-4.0 * delta)).normalized()
	# the place the head goes to: at the leader's right while he walks, up to him when he stands
	var spot := lp
	if _dir != Vector3.ZERO:
		spot += _dir.cross(Vector3.UP).normalized() * SIDE_M * clampf(lspeed, 0.0, 1.0)
	var to := spot - head
	to.y = 0.0
	var dist := to.length()
	var gap := dist - FOLLOW_M
	var away := maxf(lv.dot(to / maxf(dist, 1e-3)), 0.0)
	# go when he walks off or is well ahead; halt when the head is up with him and he stands
	if not _moving and (gap > 0.8 or (away > 0.4 and gap > 0.0)):
		_moving = true
	elif _moving and gap < 0.25 and lspeed < 0.3:
		_moving = false
	var want := 0.0
	if _moving:
		want = maxf(away + GAIN * gap, 0.0)
		want = minf(want, Horse.CRUISE[Horse.Gait.CANTER] if gap > CANTER_GAP else 3.3)
	# heading: toward the spot from the body (the head swings round as the body turns)
	var goal := spot - me
	goal.y = 0.0
	var ang := fwd.signed_angle_to(goal.normalized(), Vector3.UP) if goal.length() > 0.3 else 0.0
	var steer := clampf(ang / deg_to_rad(40.0), -1.0, 1.0)
	steer_goal = steer
	if _moving and absf(ang) > deg_to_rad(100.0) and want < 1.0:
		want = 1.0                       # behind it: walk round rather than a slow turn in place
	elif not _moving and absf(ang) > deg_to_rad(70.0) and gap > 0.3:
		pass                             # standing off from him: turn in place toward him (no throttle)
	elif not _moving:
		steer = 0.0
	# feelers
	_tick += 1
	if _tick % 2 == 0:
		_feelers(me, fwd)
	var look := LOOK_M + horse.speed
	var avoid := 0.0
	var left: float = _feel[0]
	var centre: float = _feel[1]
	var right: float = _feel[2]
	if centre < look:
		var dirn := 1.0 if left > right else -1.0
		if absf(left - right) < 0.3:
			dirn = signf(ang) if absf(ang) > 0.05 else 1.0
		avoid += dirn * (1.2 - centre / look) * 1.6
		want = minf(want, maxf(centre - 0.6, 0.4))
	var side_look := look * 0.75
	if left < side_look:
		avoid -= (1.0 - left / side_look) * 0.9
	if right < side_look:
		avoid += (1.0 - right / side_look) * 0.9
	steer_avoid = avoid if _moving else 0.0
	if _moving:
		steer = clampf(steer + avoid, -1.0, 1.0)
	# held up: turn toward the freer side a while
	var real := Vector2(horse.get_real_velocity().x, horse.get_real_velocity().z).length()
	if _moving and want > 0.3 and real < 0.15:
		_stuck_t += delta
	else:
		_stuck_t = maxf(_stuck_t - delta * 2.0, 0.0)
	if _stuck_t > STUCK_S:
		_stuck_t = 0.0
		_unstick_t = 1.0
		_unstick_dir = 1.0 if left >= right else -1.0
	if _unstick_t > 0.0:
		_unstick_t -= delta
		steer = _unstick_dir
		want = 0.0
	want_speed = want
	horse.set_cruise_gait(Horse.Gait.CANTER)
	horse.drive(want / Horse.CRUISE[Horse.Gait.CANTER], steer)


## Rays ahead of the chest: [left, ahead, right] distances (INF: clear). The ground, stumps and logs (the
## horse steps over them), people and the load do not count.
func _feelers(me: Vector3, fwd: Vector3) -> void:
	var space := horse.get_world_3d().direct_space_state
	if _ray == null:
		_ray = PhysicsRayQueryParameters3D.new()
	var from := me + Vector3.UP * 0.95 + fwd * 0.8
	var look := LOOK_M + horse.speed
	var angs := [WHISKER_DEG, 0.0, -WHISKER_DEG]
	for i in 3:
		var d := fwd.rotated(Vector3.UP, deg_to_rad(angs[i]))
		_ray.from = from
		_ray.to = from + d * look
		var ex: Array[RID] = [horse.get_rid()]
		_feel[i] = INF
		for _try in 3:
			_ray.exclude = ex
			var hit := space.intersect_ray(_ray)
			if hit.is_empty():
				break
			var col := hit.collider as Node
			if col == null or col is CharacterBody3D or col is AnimatableBody3D or col.is_in_group(&"terrain") \
					or col.is_in_group(FrontierVegetation.LOW_GROUP):
				ex.append(hit.rid)
				continue
			_feel[i] = from.distance_to(hit.position)
			break


## The bit (the rope's end on the horse, global).
func bit_point() -> Vector3:
	var socks: Dictionary = horse.meta.get("sockets", {})
	var a: Array = socks.get("rein_r", [-0.0694, 1.2665, 1.3669])
	var hb := horse.skeleton.get_bone_global_rest(horse.skeleton.find_bone("head"))
	return horse.get_bone_global("head") * (hb.affine_inverse() * Vector3(a[0], a[1], a[2]))


## The leader's right hand (the rope's other end), or his chest when the rig has no hand bone.
func hand_point() -> Vector3:
	var sk: Skeleton3D = leader.get("skeleton") as Skeleton3D if leader else null
	if sk:
		var b := sk.find_bone("r_palm")
		if b >= 0:
			return sk.global_transform * sk.get_bone_global_pose(b).origin
	return leader.global_position + Vector3.UP * 1.0


func _draw_rope() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_rope.visible = true
	_rope_mesh.clear_surfaces()
	var a := bit_point()
	var b := hand_point()
	var pts: PackedVector3Array
	if a.distance_to(b) <= ROPE_M + 0.3:
		pts = HorseHaul.sag(a, b, ROPE_M, 14)
	else:
		# let go: it hangs from the bit and trails on the ground
		var fwd := -horse.global_basis.z
		var g := horse.global_position.y + 0.03
		pts = HorseHaul.sag(a, Vector3(a.x, g, a.z) - fwd * 0.3, (a.y - g) * 1.15, 8)
		pts.append(Vector3(a.x, g, a.z) - fwd * 1.0)
	_rope_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	HorseHaul.ribbon(_rope_mesh, pts, 0.016, 0.008)
	_rope_mesh.surface_end()


# --- E ---------------------------------------------------------------------------------------------------

func interact_point() -> Vector3:
	return bit_point()


func distance_from(p: Vector3) -> float:
	return p.distance_to(bit_point())


func interact_prompt(p: Node) -> String:
	if p == null or p.get("riding") != null or (p.get("is_dead") == true) or _mount_rider() != null:
		return ""
	return "Stay" if leading and leader == p else "Lead horse"


func highlight_targets() -> Array:
	return horse.visual.find_children("*", "GeometryInstance3D", true, false) if horse.visual else []


func interact(p: Node) -> bool:
	if p == null or not (p is Node3D):
		return false
	if leading and leader == p:
		stop()
	else:
		start(p as Node3D)
	return true
