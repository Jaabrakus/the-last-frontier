class_name HorseTerrain
extends RefCounted
## Hills for the Horse (user 2026-09-25: "have horses be able to go up hills and have a animation for
## going down hills"): a runtime pose layer over the gait clips, which are authored on flat ground.
##
##   var terrain := HorseTerrain.new(horse)   # Horse._ready()
##   terrain.update(delta)                    # every tick, after the gait blender posed the clips
##   terrain.speed_cap()                      # slope speed limit (m/s) the controller obeys
##   terrain.body_pitch_deg                   # + = nose up; HorseRiderLink leans the rider with it
##
## Ground. Rays down onto the world (not onto the horse, the tree trunks' tops or the low obstacles
## the horse steps over) under the shoulders and the hips (two each, left and right), under every
## hoof, and ahead of the forehand. The body pitch follows the line from the hind to the fore
## support; the heights are smoothed (SMOOTH_RATE), so a stone or a root does not jolt the body.
##
## Posture (weights up / down = slope / SLOPE_FULL, blended by speed):
##   - body: pitched about the middle of the shoulder and hip joints so that both sit their clip
##     height above their support (legs stay near vertical, as a real horse on a slope stands);
##   - downhill: the body lower (FORE_DROP; the forelegs reach down the slope), the croup lowered
##     further (CROUP_DROP) and the pelvis tucked (TUCK_DOWN), hind hooves further
##     under the belly (HIND_UNDER), fore hooves planted a little ahead (braced forelegs, FORE_BRACE),
##     neck and head raised (NECK_DOWNHILL), a lower speed cap (DOWN_CAP: a shorter, careful stride);
##   - uphill: neck and head low and forward (NECK_UPHILL, HEAD_UPHILL), the hind hooves pushing
##     further back (HIND_DRIVE), the pelvis engaged (TUCK_UP), the speed capped (UP_CAP);
##   - the neck partly undoes the body pitch (NECK_COMP), so the head keeps its carriage.
## Feet. Each leg is solved again from its girdle: two-bone IK of the upper leg (humerus-radius /
## femur-tibia) puts the end joint (carpus / hock) where the clip's lower leg (cannon, pastern,
## hoof, orientation kept) lands its coronet at the clip's height above the ground under it. While
## the clip has the hoof down (coronet below PLANT_Y) its sole turns with the ground with the toe
## on it, and the toe is locked where it met the ground (held until the clip's toe lifts, at most
## LOCK_MAX off the clip's; a standing horse settles back at LOCK_SETTLE), so a planted hoof
## neither slides nor sinks while the body moves over it (on flat ground too: turning skids go).
## The skinning helpers at the leg joints (horse_meta.json "helpers": shoulder, elbow, knee, hip,
## hock and fetlocks) are posed again after the IK as the gait solver poses them (each turns its
## fraction of the distal bone's turn against the proximal one). A leg on or near the ground that
## cannot reach its ground from the body's place lowers that girdle (predicted each tick).
## Limits. Slope along the heading (the steeper of under the horse and the ground ahead): full
## speed below ~8 deg, then the cap tables; the horse refuses (stops) above UP_LIMIT uphill and
## DOWN_LIMIT downhill, so it never climbs a wall (Horse.floor_max_angle 40 deg stays the physics
## limit behind that).
## Low obstacles: the vegetation's stumps and logs (group LOW_GROUP, at most 0.6 m high) do not
## block the horse (collision exceptions); its legs step over them (the hoof rays see them).
##
## The layer fades out in the jump and the rear (their clips own the legs) and is the identity on
## flat ground. Bone names are the only rig contract (BONES / LEGS, and the asset's "helpers"), so
## the layer survives a rig rebuild that keeps them; lengths and joint positions are read from the
## skeleton.

const BONES := {"body": "body", "hips": "hips", "neck": ["neck_1", "neck_2", "neck_3"], "head": "head"}
## Per leg: upper, lower (the IK pair), then the rigid lower leg (end joint first) down to the hoof.
const LEGS := {
	"LF": ["humerus_l", "radius_l", "cannon_l", "pastern_l", "hoof_l"],
	"RF": ["humerus_r", "radius_r", "cannon_r", "pastern_r", "hoof_r"],
	"LH": ["femur_l", "tibia_l", "hcannon_l", "hpastern_l", "hhoof_l"],
	"RH": ["femur_r", "tibia_r", "hcannon_r", "hpastern_r", "hhoof_r"],
}
## Group of static bodies a horse steps over (FrontierVegetation: stumps and logs).
const LOW_GROUP := &"horse_step_over"

const SLOPE_FULL := 30.0          ## deg: the posture weights reach 1 here
const SMOOTH_RATE := 7.0          ## 1/s: ground heights under the body
const WEIGHT_RATE := 5.0          ## 1/s: fade in / out of the layer (one-shots)
const PLANT_Y := 0.075            ## m: a clip coronet below this is on the ground
const RAY_UP := 1.25              ## m above the root where the ground rays start
const RAY_DOWN := 2.5             ## m below the root where they end
const MIN_NORMAL_Y := 0.5         ## ground steeper than 60 deg is a wall, not ground
## Downhill (m, deg at SLOPE_FULL).
const CROUP_DROP := 0.15
## The forehand comes down too: the forelegs reach down the slope ahead of the shoulders.
const FORE_DROP := 0.11
const TUCK_DOWN := 9.0
const HIND_UNDER := 0.14
const FORE_BRACE := 0.03
const NECK_DOWNHILL := 14.0
## Legs whose clip coronet is below this (m) must reach their ground (on it or about to land).
const REACH_Y := 0.2
## Girdle drop for legs that cannot reach: attack / release rates (1/s) and the most (m).
const DROP_RATE := Vector2(14.0, 1.0)
const MAX_DROP := 0.2
## Uphill.
const TUCK_UP := 4.0
const HIND_DRIVE := 0.07
const FORE_REACH := 0.03
const HIND_SQUAT := 0.02
const NECK_UPHILL := 20.0
const HEAD_UPHILL := 6.0
## Neck raise per degree of body pitch (it partly undoes the pitch) and the head's share of what
## the neck and body turn it (it keeps its carriage).
const NECK_COMP := 0.55
const HEAD_KEEP := 0.6
## Hoof sole turns with the ground at most this far (deg), fully while the clip's coronet is below
## TILT_Y.x (the hoof down, flat), none above TILT_Y.y (m).
const HOOF_TILT_MAX := 32.0
const TILT_Y := Vector2(0.058, 0.085)
## A planted hoof keeps the ground height under it while it stays within this (m) of where that was
## sampled (a hoof still settling in is sampled again).
const LATCH_REACH := 0.01
## Largest correction of a leg's end joint (m); more means no usable ground under the hoof.
const MAX_CORRECTION := 0.45
## s over which a toe lock lets go after lift-off; the most it holds a toe off the clip's (m); how
## fast a standing horse's locked toes settle back onto the clip's (m/s).
const LOCK_FADE := 0.12
const LOCK_MAX := 0.05
## The lock holds until the clip's toe is this high (m) off its ground.
const LOCK_TOE_UP := 0.015
const LOCK_SETTLE := 0.08
## Speed caps (m/s) by slope along the heading (deg): [slope, cap] pairs, linear between them.
const UP_CAP := [[8.0, 13.0], [13.0, 6.2], [19.0, 3.3], [25.0, 1.4], [30.0, 1.0], [34.0, 0.6]]
const DOWN_CAP := [[6.0, 13.0], [10.0, 6.2], [15.0, 3.3], [20.0, 1.4], [26.0, 0.9], [30.0, 0.6]]
const UP_LIMIT := 34.0            ## deg: steeper uphill the horse refuses
const DOWN_LIMIT := 31.0          ## deg: steeper downhill the horse refuses
## Ground ahead of the forehand for the limits: [near, far] m in front of the shoulders.
## The far point moves out with the speed (s), so a fast horse slows in time.
const AHEAD := Vector2(0.4, 2.0)
const AHEAD_PER_SPEED := 0.35
## Their rays start this far (m) above the ground the present slope leads to; without a hit they
## look again from AHEAD_RETRY m above the root, for the terrain only.
const AHEAD_CLEAR := 1.3
const AHEAD_RETRY := 6.0

var horse: Horse
var sk: Skeleton3D
var enabled := true
## Layer weight (0 in the jump / rear, else 1), smoothed.
var weight := 0.0
## Ground slope along the heading under the horse (deg, + = uphill) and ahead of it.
var slope_deg := 0.0
var grade_ahead_deg := 0.0
## Body pitch the layer applies (deg, + = nose up).
var body_pitch_deg := 0.0
## Posture weights 0..1.
var up := 0.0
var down := 0.0
## Body lowered for legs that could not reach their ground (m).
var reach_drop := 0.0
## Per leg (LEGS order): planted flag, world coronet target, IK miss (m, target not reached).
var planted := {}
var target := {}
var ik_miss := {}
## Low obstacles the horse ignores (their RIDs, also left out of the body rays).
var low_rids: Array[RID] = []
## CPU time of the last update (microseconds), for tests.
var cost_us := 0

var _b := {}                     ## name -> bone index
var _legs := {}                  ## leg -> Array[int] bone indices
var _helpers := {}               ## leg -> Array of [helper, distal bone, fraction, helper rest rotation,
                                 ## distal rest rotation] (bone indices), from horse_meta.json "helpers"
var _neck: Array[int] = []
var _z_shoulder := 0.6
var _z_hip := -0.5
var _x_side := 0.15
var _g_s := 0.0                  ## smoothed support heights (skeleton space, m)
var _g_h := 0.0
var _started := false
var _drop := Vector2.ZERO        ## shoulders / hips lowered for legs that cannot reach (m), smoothed
var _reach := {}                 ## leg -> upper-leg reach (m): girdle joint to end joint, straight
var _last_beta_deg := 0.0
var _latch := {}                 ## leg -> latched ground [y, normal, sampled at (world)] while planted
var _lock := {}                  ## leg -> toe lock {on, w, pos (world)}
var _toe_local := {}             ## leg -> the toe (front of the sole) in its hoof bone's frame
var _normal := {}                ## leg -> ground normal under the hoof last tick (skeleton space)
var _except_t := 0.0
var _excepted := {}


func _init(h: Horse) -> void:
	horse = h
	sk = h.skeleton
	for k in ["body", "hips", "head"]:
		_b[k] = sk.find_bone(BONES[k])
	for n: String in BONES.neck:
		_neck.append(sk.find_bone(n))
	for leg: String in LEGS:
		var arr: Array[int] = []
		for n: String in LEGS[leg]:
			arr.append(sk.find_bone(n))
		_legs[leg] = arr
		planted[leg] = false
		target[leg] = Vector3.ZERO
		ik_miss[leg] = 0.0
	# skinning helpers: those whose distal bone belongs to the leg (the shoulder helper follows the
	# humerus, the hip's the femur, ...)
	var hdef: Dictionary = h.meta.get("helpers", {})
	for leg: String in LEGS:
		var arr := []
		for hn: String in hdef:
			var d: Array = hdef[hn]
			var hb := sk.find_bone(hn)
			var db := sk.find_bone(String(d[1]))
			if hb < 0 or db < 0 or not (String(d[1]) in LEGS[leg]):
				continue
			arr.append([hb, db, float(d[2]), sk.get_bone_rest(hb).basis.get_rotation_quaternion(),
					sk.get_bone_rest(db).basis.get_rotation_quaternion()])
		_helpers[leg] = arr
	# toes: the asset's sockets (horse_meta.json hoof_toes, model space at rest), else a hoof's length
	# ahead of the coronet at the ground
	var toes: Dictionary = h.meta.get("sockets", {}).get("hoof_toes", {})
	for leg: String in LEGS:
		_lock[leg] = {"on": false, "w": 0.0, "pos": Vector3.ZERO}
		var hb: int = _legs[leg][4]
		if hb < 0:
			_toe_local[leg] = Vector3.ZERO
			continue
		var rest := sk.get_bone_global_rest(hb)
		var toe := rest.origin + Vector3(0.0, -rest.origin.y, 0.09)
		if toes.has(leg) and (toes[leg] as Array).size() >= 2:
			var t: Array = toes[leg][1]
			toe = Vector3(float(t[0]), float(t[1]), float(t[2]))
		_toe_local[leg] = rest.affine_inverse() * toe
	if _legs.LF[0] >= 0 and _legs.LH[0] >= 0:
		_z_shoulder = sk.get_bone_global_rest(_legs.LF[0]).origin.z
		_z_hip = sk.get_bone_global_rest(_legs.LH[0]).origin.z
		_x_side = absf(sk.get_bone_global_rest(_legs.LF[4]).origin.x)
	for leg: String in LEGS:
		var ids: Array[int] = _legs[leg]
		_reach[leg] = 1.0
		if ids[0] >= 0 and ids[1] >= 0 and ids[2] >= 0:
			var a := sk.get_bone_global_rest(ids[0]).origin
			var b := sk.get_bone_global_rest(ids[1]).origin
			var e := sk.get_bone_global_rest(ids[2]).origin
			_reach[leg] = a.distance_to(b) + b.distance_to(e)


func ok() -> bool:
	return _b.body >= 0 and _b.hips >= 0 and _legs.LF[0] >= 0 and _legs.RH[4] >= 0


# ---------------------------------------------------------------------------
# Limits
# ---------------------------------------------------------------------------
## Highest speed (m/s) the slope allows (0 = the horse refuses to go on).
func speed_cap() -> float:
	if not enabled or weight <= 0.0:
		return INF
	var cap := INF
	for s in [slope_deg, grade_ahead_deg]:
		cap = minf(cap, cap_for(s))
	return cap


static func cap_for(s: float) -> float:
	if s >= UP_LIMIT or s <= -DOWN_LIMIT:
		return 0.0
	var tab: Array = UP_CAP if s >= 0.0 else DOWN_CAP
	var a := absf(s)
	if a <= float(tab[0][0]):
		return INF
	for i in range(1, tab.size()):
		if a <= float(tab[i][0]):
			var t := (a - float(tab[i - 1][0])) / (float(tab[i][0]) - float(tab[i - 1][0]))
			return lerpf(float(tab[i - 1][1]), float(tab[i][1]), t)
	return float(tab[tab.size() - 1][1])


## True when the slope ahead or under the horse is too steep to go on.
func refusing() -> bool:
	return speed_cap() <= 0.0


# ---------------------------------------------------------------------------
# Update
# ---------------------------------------------------------------------------
func update(delta: float) -> void:
	if not ok():
		return
	var t0 := Time.get_ticks_usec()
	_update(delta)
	cost_us = Time.get_ticks_usec() - t0


func _update(delta: float) -> void:
	_except_t -= delta
	if _except_t <= 0.0:
		_except_t = 2.0
		except_low_obstacles()
	var want := 1.0 if enabled and horse.one_shot.is_empty() and not horse.airborne else 0.0
	weight = want if not _started else move_toward(weight, want, WEIGHT_RATE * delta)
	var G := sk.global_transform
	var Gi := G.affine_inverse()
	var space := horse.get_world_3d().direct_space_state
	# --- ground under the shoulders and the hips (skeleton space heights)
	var gs := _support(space, G, Gi, _z_shoulder)
	var gh := _support(space, G, Gi, _z_hip)
	if is_nan(gs):
		gs = _g_s if _started else 0.0
	if is_nan(gh):
		gh = _g_h if _started else 0.0
	var k := 1.0 - exp(-SMOOTH_RATE * delta)
	if not _started:
		_g_s = gs
		_g_h = gh
		_started = true
	else:
		_g_s = lerpf(_g_s, gs, k)
		_g_h = lerpf(_g_h, gh, k)
	var span := _z_shoulder - _z_hip
	slope_deg = rad_to_deg(atan2(_g_s - _g_h, span))
	# ground ahead of the forehand, for the limits
	# (the rays start AHEAD_CLEAR over the ground the present slope leads to, under a walkway or a
	# gate beam, which then does not read as ground)
	var slope_t := tan(deg_to_rad(clampf(slope_deg, -40.0, 40.0)))
	var far := AHEAD.y + AHEAD_PER_SPEED * horse.speed
	var za := _z_shoulder + AHEAD.x
	var zb := _z_shoulder + far
	var ga := _support(space, G, Gi, za, maxf(RAY_UP, _g_s + AHEAD.x * slope_t + AHEAD_CLEAR), true)
	if is_nan(ga):
		ga = _g_s + AHEAD.x * slope_t
	var gb := _support(space, G, Gi, zb, maxf(RAY_UP, _g_s + far * slope_t + AHEAD_CLEAR), true)
	if is_nan(gb):
		gb = ga + (zb - za) * slope_t
	var ahead := rad_to_deg(atan2(gb - ga, zb - za))
	grade_ahead_deg = lerpf(grade_ahead_deg, ahead, k)
	if weight <= 1e-4:
		body_pitch_deg = 0.0
		up = 0.0
		down = 0.0
		reach_drop = 0.0
		_drop = Vector2.ZERO
		for leg: String in LEGS:
			planted[leg] = false
			_latch.erase(leg)
			_lock[leg] = {"on": false, "w": 0.0, "pos": Vector3.ZERO}
		return
	var fast := clampf((horse.speed - 1.5) / 5.0, 0.0, 1.0)
	up = clampf(slope_deg / SLOPE_FULL, 0.0, 1.0) * lerpf(0.85, 1.0, fast) * weight
	down = clampf(-slope_deg / SLOPE_FULL, 0.0, 1.0) * lerpf(1.0, 0.8, fast) * weight
	# --- clip pose (flat ground) of the bones we move
	var P0 := {}
	for leg: String in LEGS:
		for bi: int in _legs[leg]:
			P0[bi] = sk.get_bone_global_pose(bi)
	P0[_b.body] = sk.get_bone_global_pose(_b.body)
	# --- where each hoof goes: its ground, the posture offsets, the toe locks
	var tg := {}
	for leg: String in LEGS:
		tg[leg] = _leg_target(leg, P0, G, Gi, space, delta)
	# --- body: pitched about the middle of the girdle joints, so that the shoulder and the hip
	# joints sit their clip height above their supports (the legs stay near vertical)
	var sup_s := (_g_s - FORE_DROP * down) * weight
	var sup_h := (_g_h - CROUP_DROP * down - HIND_SQUAT * up) * weight
	var S0 := ((P0[_legs.LF[0]] as Transform3D).origin + (P0[_legs.RF[0]] as Transform3D).origin) * 0.5
	var H0 := ((P0[_legs.LH[0]] as Transform3D).origin + (P0[_legs.RH[0]] as Transform3D).origin) * 0.5
	var c := (S0 + H0) * 0.5
	c.x = 0.0
	# a leg that cannot reach its ground from there (the foreleg reaching down a slope at touchdown,
	# the hind leg pushing off uphill, the downhill side on a traverse) lowers its girdle; legs that
	# are about to land count, so the body goes down before the hoof arrives
	var need := _reach_need(_body_transform(c, S0, H0, sup_s, sup_h), tg, P0)
	var ka := 1.0 - exp(-DROP_RATE.x * delta)
	var kr := 1.0 - exp(-DROP_RATE.y * delta)
	_drop.x = lerpf(_drop.x, need.x, ka if need.x > _drop.x else kr)
	_drop.y = lerpf(_drop.y, need.y, ka if need.y > _drop.y else kr)
	reach_drop = maxf(_drop.x, _drop.y)
	var M := _body_transform(c, S0, H0, sup_s - _drop.x * weight, sup_h - _drop.y * weight)
	body_pitch_deg = _last_beta_deg
	sk.set_bone_global_pose(_b.body, M * (P0[_b.body] as Transform3D))
	sk.set_bone_pose_scale(_b.body, Vector3.ONE)     # (the clips key no scale: keep float noise out)
	# --- pelvis tuck (the croup and point of buttock go down and under)
	var tuck := deg_to_rad(TUCK_DOWN * down + TUCK_UP * up)
	if absf(tuck) > 1e-4:
		_set_rot(_b.hips, Basis(Vector3.RIGHT, -tuck) * sk.get_bone_global_pose(_b.hips).basis)
	# --- neck and head
	var neck_raise := -NECK_COMP * body_pitch_deg + NECK_DOWNHILL * down - NECK_UPHILL * up
	var head_raise := -HEAD_KEEP * (body_pitch_deg + neck_raise) + HEAD_UPHILL * up
	var shares := [0.55, 0.3, 0.15]
	for i in _neck.size():
		_raise(_neck[i], neck_raise * shares[i])
	_raise(_b.head, head_raise)
	# --- legs
	for leg: String in LEGS:
		_leg_solve(leg, tg[leg], P0)


## Body transform (skeleton space) that pitches the body about c so that the shoulder joints (S0)
## and the hip joints (H0) of the clip sit their clip height above the support line through
## sup_s (under the shoulders) and sup_h (under the hips). Sets _last_beta_deg.
func _body_transform(c: Vector3, S0: Vector3, H0: Vector3, sup_s: float, sup_h: float) -> Transform3D:
	var beta := atan2(sup_s - sup_h, _z_shoulder - _z_hip)
	var dy := 0.0
	for it in 3:
		var R := Basis(Vector3.RIGHT, -beta)
		var s1 := c + R * (S0 - c)
		var h1 := c + R * (H0 - c)
		var es := _line(s1.z, sup_s, sup_h) + S0.y - s1.y
		var eh := _line(h1.z, sup_s, sup_h) + H0.y - h1.y
		dy = (es + eh) * 0.5
		beta += atan2(es - eh, maxf(s1.z - h1.z, 0.1))
	_last_beta_deg = rad_to_deg(beta)
	return Transform3D(Basis(), Vector3(0.0, dy, 0.0)) * _about(c, Basis(Vector3.RIGHT, -beta))


## How far (m) the shoulders (x) and the hips (y) must come down for the legs on or near the
## ground to reach their targets with the body placed by M.
func _reach_need(M: Transform3D, tg: Dictionary, P0: Dictionary) -> Vector2:
	var need := Vector2.ZERO
	for leg: String in LEGS:
		var t: Dictionary = tg[leg]
		if float(t.c0y) > REACH_Y:
			continue
		var a := M * (P0[_legs[leg][0]] as Transform3D).origin
		var et: Vector3 = t.et
		var mx: float = _reach[leg] * 0.995
		if a.distance_to(et) <= mx:
			continue
		var h := Vector2(et.x - a.x, et.z - a.z).length()
		var d := (a.y - et.y) - sqrt(maxf(mx * mx - h * h, 0.0))
		if leg.ends_with("F"):
			need.x = maxf(need.x, d)
		else:
			need.y = maxf(need.y, d)
	return need.clamp(Vector2.ZERO, Vector2(MAX_DROP, MAX_DROP))


## Support line height (skeleton space) at model z, through the hind and fore supports.
func _line(z: float, sup_s: float, sup_h: float) -> float:
	return sup_h + (z - _z_hip) * (sup_s - sup_h) / (_z_shoulder - _z_hip)


## Ground height (skeleton space) under the body line at model z (mean of left and right).
## NAN when neither ray finds ground. `above`: ray start above the root (m); `retry`: without a hit,
## look again from AHEAD_RETRY m up, for the terrain only (a rise steeper than the rays expected).
func _support(space: PhysicsDirectSpaceState3D, G: Transform3D, Gi: Transform3D, z: float, above := RAY_UP,
		retry := false) -> float:
	var s := 0.0
	var n := 0
	for x in [_x_side, -_x_side]:
		var w := G * Vector3(x, 0.0, z)
		var hit := _ground(space, w, false, above)
		if hit.is_empty() and retry:
			hit = _ground(space, w, false, AHEAD_RETRY, true)
		if not hit.is_empty():
			s += (Gi * (hit[0] as Vector3)).y
			n += 1
	return s / n if n > 0 else NAN


## First ground below world point w (its x, z) within the ray range: [position, normal], or []
## when there is none. Trunk tops and walls are skipped; low obstacles only for the hooves.
func _ground(space: PhysicsDirectSpaceState3D, w: Vector3, hooves: bool, above := RAY_UP, terrain_only := false) -> Array:
	var y0 := horse.global_position.y
	var excl: Array[RID] = [horse.get_rid()]
	if not hooves:
		excl.append_array(low_rids)
	for attempt in 4:
		var q := PhysicsRayQueryParameters3D.create(Vector3(w.x, y0 + above, w.z), Vector3(w.x, y0 - RAY_DOWN, w.z))
		q.exclude = excl
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return []
		var col: Object = hit.collider
		var n: Vector3 = hit.normal
		var node := col as Node
		if (node and node.is_in_group(&"trees")) or n.y < MIN_NORMAL_Y \
				or (terrain_only and not (node and node.is_in_group(&"terrain"))):
			excl.append(hit.rid)
			continue
		return [hit.position, n]
	return []


## Rotates bone b about its head by `deg` in the sagittal plane (+ = its tip up).
func _raise(b: int, deg: float) -> void:
	if b < 0 or absf(deg) < 1e-3:
		return
	_set_rot(b, Basis(Vector3.RIGHT, -deg_to_rad(deg)) * sk.get_bone_global_pose(b).basis)


static func _about(p: Vector3, b: Basis) -> Transform3D:
	return Transform3D(Basis(), p) * Transform3D(b, Vector3.ZERO) * Transform3D(Basis(), -p)


## Where one hoof goes this tick: {c0y (clip coronet height), ct (coronet target), et (end joint
## target), hoof (hoof bone orientation)}, skeleton space. Samples the ground, runs the toe lock.
func _leg_target(leg: String, P0: Dictionary, G: Transform3D, Gi: Transform3D, space: PhysicsDirectSpaceState3D,
		delta: float) -> Dictionary:
	var ids: Array[int] = _legs[leg]
	var fore := leg.ends_with("F")
	var c0: Transform3D = P0[ids[4]]                  # clip coronet (hoof bone head)
	var e0: Transform3D = P0[ids[2]]                  # clip end joint (carpus / hock)
	var on := c0.origin.y < PLANT_Y
	# where the hoof goes: the clip's place, moved by the posture, at its height above the ground
	var off := (FORE_BRACE * down + FORE_REACH * up) if fore else (HIND_UNDER * down - HIND_DRIVE * up)
	var ct := c0.origin + Vector3(0.0, 0.0, off * weight)
	var tw := 1.0 - smoothstep(TILT_Y.x, TILT_Y.y, c0.origin.y)
	# toe lock: from the moment the hoof comes down its toe stays where it met the ground (the clip's
	# last centimetres of approach and the breakover roll over the toe do not skid it); released
	# over LOCK_FADE s once the clip's toe is off the ground (so the hoof catches up in the air).
	# (The sole's tilt here is last tick's ground.)
	var toe_l: Vector3 = _toe_local[leg]
	var toe_sk := ct + _hoof_tilt(_normal.get(leg, Vector3.UP), tw) * c0.basis * toe_l
	var lk: Dictionary = _lock[leg]
	var hold: bool = on or (bool(lk.on) and (c0.origin + c0.basis * toe_l).y < LOCK_TOE_UP)
	if hold:
		if not lk.on:
			lk.on = true
			lk.pos = G * toe_sk
		lk.w = 1.0
		# the lock holds a few centimetres, not a clip that moves the hoof on purpose (a cross-fade
		# into the idle, a shuffle): beyond LOCK_MAX the hoof follows, and a standing horse settles
		# its hooves back onto the clip's (LOCK_SETTLE m/s)
		var cw := G * toe_sk
		var dv: Vector3 = (lk.pos as Vector3) - cw
		dv.y = 0.0
		if dv.length() > LOCK_MAX:
			lk.pos = cw + dv.normalized() * LOCK_MAX
		elif horse.speed < 0.05:
			lk.pos = cw + dv.move_toward(Vector3.ZERO, LOCK_SETTLE * delta)
	else:
		lk.on = false
		lk.w = move_toward(float(lk.w), 0.0, delta / LOCK_FADE)
	if float(lk.w) > 0.0:
		var d := ((Gi * (lk.pos as Vector3)) - toe_sk) * float(lk.w) * weight
		ct.x += d.x
		ct.z += d.z
	# the ground under the hoof
	var wxz := G * ct
	var gy: float
	var gn: Vector3
	var latch: Array = _latch.get(leg, [])
	if on and planted[leg] and not latch.is_empty() \
			and Vector2(wxz.x - latch[2].x, wxz.z - latch[2].z).length() < LATCH_REACH:
		# the hoof is standing: it keeps the ground of where it stands
		gy = latch[0]
		gn = latch[1]
	else:
		var hit := _ground(space, wxz, true)
		gy = (hit[0] as Vector3).y if not hit.is_empty() else horse.global_position.y
		gn = hit[1] if not hit.is_empty() else Vector3.UP
		if on:
			_latch[leg] = [gy, gn, wxz]
	if not on:
		_latch.erase(leg)
	planted[leg] = on
	# the sole turns with the ground while the hoof stands on it (not while it comes down)
	var n_sk := (Gi.basis * gn).normalized()
	_normal[leg] = n_sk
	var hoof_b := _hoof_tilt(n_sk, tw) * c0.basis
	# the coronet at its clip height above the ground; while the hoof stands, its toe on the ground
	# plane (at the clip toe's own height above the flat ground: 0, or its breakover lift)
	var g_sk := (Gi * Vector3(wxz.x, gy, wxz.z)).y
	var y := c0.origin.y + g_sk
	var toe_now := Vector3(ct.x, y, ct.z) + hoof_b * toe_l
	var plane_y := g_sk - (n_sk.x * (toe_now.x - ct.x) + n_sk.z * (toe_now.z - ct.z)) / maxf(n_sk.y, 0.5)
	y += (plane_y + (c0.origin + c0.basis * toe_l).y - toe_now.y) * tw
	ct.y = lerpf(c0.origin.y, y, weight)
	target[leg] = G * ct
	# the lower leg keeps its clip orientation: the end joint goes where it lands the coronet on ct
	return {"c0y": c0.origin.y, "ct": ct, "et": ct + (e0.origin - c0.origin), "hoof": hoof_b}


## Solves one leg onto its target (two-bone IK of the upper leg, the lower leg in its clip
## orientation, the hoof turned with the ground). Returns how far the end joint stays off (m).
func _leg_solve(leg: String, t: Dictionary, P0: Dictionary) -> float:
	var ids: Array[int] = _legs[leg]
	var et: Vector3 = t.et
	var A := sk.get_bone_global_pose(ids[0])
	var B := sk.get_bone_global_pose(ids[1])
	var E := sk.get_bone_global_pose(ids[2])
	# no ground within a leg's reach (a cliff edge, a teleport): the correction is limited
	if et.distance_to(E.origin) > MAX_CORRECTION:
		et = E.origin + (et - E.origin).limit_length(MAX_CORRECTION)
	var miss := _two_bone(ids[0], ids[1], A, B, E.origin, et)
	ik_miss[leg] = miss
	for i in range(2, 4):
		_set_rot(ids[i], (P0[ids[i]] as Transform3D).basis)
	_set_rot(ids[4], t.hoof)
	_pose_helpers(leg)
	return miss


## The leg's skinning helpers after the IK: each turns its fraction of its distal bone's turn
## (against the rest, in the proximal bone's frame), as tools/horse/gaits.py poses them.
func _pose_helpers(leg: String) -> void:
	for hd: Array in _helpers.get(leg, []):
		var q: Quaternion = sk.get_bone_pose_rotation(hd[1]) * (hd[4] as Quaternion).inverse()
		sk.set_bone_pose_rotation(hd[0], Quaternion.IDENTITY.slerp(q.normalized(), hd[2]) * (hd[3] as Quaternion))


## Rotation that turns the hoof's sole onto ground of normal n (skeleton space), limited.
func _hoof_tilt(n: Vector3, w: float) -> Basis:
	n = n.normalized()
	var ang := acos(clampf(n.y, -1.0, 1.0))
	if ang < 1e-3:
		return Basis()
	var ax := Vector3.UP.cross(n).normalized()
	return Basis(ax, minf(ang, deg_to_rad(HOOF_TILT_MAX)) * weight * w)


## Two-bone IK: bones u (head A) and l (head B) so that l's tail (the end joint, now at E) reaches
## `goal`; the knee stays in its current plane. Returns the miss (m).
func _two_bone(u: int, l: int, A_: Transform3D, B_: Transform3D, E: Vector3, goal: Vector3) -> float:
	var A := A_.origin
	var B := B_.origin
	if goal.distance_to(E) < 5e-4:
		return 0.0
	var l1 := A.distance_to(B)
	var l2 := B.distance_to(E)
	var axis := goal - A
	var want := axis.length()
	var d := clampf(want, absf(l1 - l2) + 1e-4, (l1 + l2) * 0.999)
	axis = axis.normalized()
	var pole := (B - A) - axis * (B - A).dot(axis)
	if pole.length() < 1e-5:
		pole = B_.basis.z
	pole = pole.normalized()
	var ca := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var al := acos(ca)
	var B2 := A + l1 * (cos(al) * axis + sin(al) * pole)
	var E2 := A + axis * d
	var q1 := _arc((B - A).normalized(), (B2 - A).normalized())
	_set_rot(u, Basis(q1) * A_.basis)
	var shin := Basis(q1) * (E - B)
	var q2 := _arc(shin.normalized(), (E2 - B2).normalized())
	_set_rot(l, Basis(q2) * Basis(q1) * B_.basis)
	return maxf(want - d, 0.0)


## Turns bone b to the global (skeleton space) orientation `bas`, rotation only: the clips key
## the rotations of every bone this layer moves (re-applied every tick), but not their positions
## or scales, which must stay at rest (a written position or scale would persist and drift).
func _set_rot(b: int, bas: Basis) -> void:
	var p := sk.get_bone_parent(b)
	var pb := sk.get_bone_global_pose(p).basis.orthonormalized() if p >= 0 else Basis()
	sk.set_bone_pose_rotation(b, (pb.inverse() * bas.orthonormalized()).get_rotation_quaternion())


## Shortest rotation from unit vector a to b (normalized; identity when they are opposite, which
## a leg never needs).
static func _arc(a: Vector3, b: Vector3) -> Quaternion:
	if a.dot(b) < -0.999 or not a.is_finite() or not b.is_finite():
		return Quaternion.IDENTITY
	return Quaternion(a, b).normalized()


# ---------------------------------------------------------------------------
# Low obstacles
# ---------------------------------------------------------------------------
## The horse ignores the bodies in LOW_GROUP (stumps and logs: it steps over them). Called every
## 2 s, so bodies built later (streamed vegetation) are picked up.
func except_low_obstacles() -> void:
	if not horse.is_inside_tree():
		return
	for n in horse.get_tree().get_nodes_in_group(LOW_GROUP):
		var body := n as PhysicsBody3D
		if body == null or _excepted.has(body.get_instance_id()):
			continue
		_excepted[body.get_instance_id()] = true
		horse.add_collision_exception_with(body)
		low_rids.append(body.get_rid())
