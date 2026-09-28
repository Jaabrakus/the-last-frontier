class_name HorseRiderLink
extends Node
## Stopgap rider coupling (horse.md 3.6) until PlayerAnim gets a ride mode: keeps an
## Actor_B rig on the horse's saddle socket and plays the matching actor_b-horse-* clip
## at the horse's phase and playback rate (rider phase = horse phase), cross-faded like
## the horse. The rider's palms become the rein targets.
##
##   var link := HorseRiderLink.new()
##   horse.add_child(link)                      # a child runs after the horse each tick
##   link.attach(horse, actor_b_root, actor_b_anim_player)
##
## Fit to the horse. The riding clips are saddle-relative: their origin is the saddle
## attach point, which the horse puts SEAT_DROP above its seat (tools/horse/anatomy.py),
## so the pelvis sits on the seat of any horse size (seat offset). The stirrup leathers
## have a fixed length (the rider's fit, leather_scale), hang from the stirrup bars and
## swing towards her feet; leg IK (two-bone, hip-knee-ankle, knee plane kept) then puts
## the ball of each foot on its tread (stirrup offset + foot IK). The hands hold the reins
## (the rein strips run from the bit to the palms) and are kept above the horse's crest and
## withers: where this horse's neck is fuller or higher than the horse the clip was authored
## on, arm IK moves the hand out of it (hand IK; the clip's hand orientation is kept).
##
## The rider root is made top_level and placed on Horse.get_saddle_transform() every
## physics tick (the Actor_B rig faces +z like the horse model, so no extra turn).
## Clips: "actor_b-..." names are looked up in the "actor_b" library; names with a
## library prefix (the retargeted "actor_a_rt/actor_a-horse-rear") are used as they are.
##
## Slopes: the rider leans forward uphill and back downhill with the source graph's incline
## additive (actor_b-horse-idle-incline--add-up-down, 3 frames: 0 leans forward, 1 neutral = rest,
## 2 leans back; horse.md 1.4 / 3.5), added over every riding clip at phase 0.5 - pitch / 60 with
## the horse's body pitch in degrees (HorseTerrain.body_pitch_deg).

const RT_LIBRARY := "actor_a_rt"
const RT_PATH := "res://animations_extra/actor_a_rt_proto.res"
## Seat correction per rider clip, in the saddle frame. The Actor_A -> Actor_B retarget
## keeps Actor_A's seat height, 5.5 cm lower than Actor_B's own riding clips (measured by
## tests/horse/test_horse.gd: seat gap -0.048 m mean without it).
const CLIP_OFFSET := {"actor_a_rt/actor_a-horse-rear": Vector3(0.0, 0.055, 0.0)}
## Ball of the foot above the stirrup tread (sole thickness), metres.
const SOLE := 0.03
## Rider clip time windows to cover with another clip: actor_b-horse-gallop^jump-over has
## corrupted frames 2-5 (15 Hz, 0.13-0.33 s: trunk roll -86 deg, head flips; horse.md
## 1.6), so the gallop clip stands in for them. [start s, end s, stand-in clip].
const STAND_IN := {"actor_b/actor_b-horse-gallop^jump-over": [0.09, 0.37, "actor_b/actor_b-horse-gallop-fw"]}
const STAND_IN_FADE := 0.08
## The incline additive (extracted Actor_B clip) and the slope (deg) that reaches its end frames.
const INCLINE := "actor_b/actor_b-horse-idle-incline--add-up-down"
const INCLINE_FULL := 60.0
## Foot IK fades out when the foot is further than this from its tread (m): [full, zero].
const FOOT_IK_REACH := Vector2(0.15, 0.25)
## Palm joint and finger joints at least this far outside the horse's skin (m).
const HAND_CLEAR := 0.03
const FINGER_CLEAR := 0.012
## Finger joints tested per hand (with the palm).
const FINGER_JOINTS := ["indexb", "indexc", "middleb", "middlec", "ringb", "ringc", "pinkyb", "pinkyc", "thumbb", "thumbc"]
## Horse bones whose skin makes the crest and withers the hands rest over.
const CREST_BONES := ["chest", "neck_1", "neck_2", "neck_3"]

var horse: Horse
var rider: Node3D
var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var blender: HorsePhaseBlender
var drive_reins := true
## Hang the stirrups from their bars towards the rider's feet and IK the feet onto them.
var follow_stirrups := true
var foot_ik := true
var hand_ik := true
## Stirrup leather length relative to the asset's fit (1 = Actor_B's riding length).
var leather_scale := 1.0
## Tests: switch clips without cross-fades (poses exactly at the requested phase).
var instant := false
## Last foot IK correction per side (m, before IK), for tests.
var foot_correction := [0.0, 0.0]
## Last hand lift per side (m), for tests.
var hand_correction := [0.0, 0.0]
var _palm := [-1, -1]
var _legs := []            ## per side: [upper_leg, knee, ankle, ball]
var _arms := []            ## per side: [shoulder, elbow, wrist, palm]
var _crest_bone := PackedInt32Array()      ## horse bone of each crest vertex
var _crest_local := PackedVector3Array()   ## crest vertex in its bone's frame
var _crest_normal := PackedVector3Array()  ## its normal in that frame
var _hand_pts := []        ## per side: [palm, finger joints...] bone indices
var _clip := ""


func attach(h: Horse, rider_root: Node3D, ap: AnimationPlayer) -> void:
	horse = h
	rider = rider_root
	anim_player = ap
	skeleton = rider.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	if not ap.has_animation_library(RT_LIBRARY) and ResourceLoader.exists(RT_PATH):
		ap.add_animation_library(RT_LIBRARY, load(RT_PATH))
	blender = HorsePhaseBlender.new(ap, rider, "", true)
	_palm = [skeleton.find_bone("l_palm"), skeleton.find_bone("r_palm")]
	_legs = []
	for s in ["l", "r"]:
		_legs.append([skeleton.find_bone(s + "_upper_leg"), skeleton.find_bone(s + "_knee"),
				skeleton.find_bone(s + "_ankle"), skeleton.find_bone(s + "_ball")])
	_arms = []
	_hand_pts = []
	for s in ["l", "r"]:
		_arms.append([skeleton.find_bone(s + "_shoulder"), skeleton.find_bone(s + "_elbow"),
				skeleton.find_bone(s + "_wrist"), skeleton.find_bone(s + "_palm")])
		var pts := [skeleton.find_bone(s + "_palm")]
		for f in FINGER_JOINTS:
			var b := skeleton.find_bone(s + "_" + f)
			if b >= 0:
				pts.append(b)
		_hand_pts.append(pts)
	_build_crest()
	rider.top_level = true
	sync(0.0)


## Skin vertices of the horse's crest and withers (top of the neck, in front of the saddle),
## each in the frame of the bone that moves it most.
func _build_crest() -> void:
	_crest_bone = PackedInt32Array()
	_crest_local = PackedVector3Array()
	_crest_normal = PackedVector3Array()
	var hs := horse.skeleton
	var want := {}
	for n in CREST_BONES:
		var b := hs.find_bone(n)
		if b >= 0:
			want[b] = true
	for mi: MeshInstance3D in horse.visual.find_children("*", "MeshInstance3D", true, false):
		if String(mi.name) != "HorseBody" or mi.skin == null:
			continue
		var arr := mi.mesh.surface_get_arrays(0)
		var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var NR: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var B: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var W: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var nb := B.size() / maxi(V.size(), 1)
		var bind := {}
		for k in mi.skin.get_bind_count():
			var bi := mi.skin.get_bind_bone(k)
			if bi < 0:
				bi = hs.find_bone(mi.skin.get_bind_name(k))
			bind[k] = [bi, mi.skin.get_bind_pose(k)]
		for i in V.size():
			var v := V[i]
			# the top of the neck and withers ahead of the saddle (model space: +z forward)
			if v.y < 0.95 or v.z < 0.1 or v.z > 1.3 or absf(v.x) > 0.22:
				continue
			var best := -1
			var bw := 0.0
			for k in nb:
				if W[i * nb + k] > bw:
					bw = W[i * nb + k]
					best = B[i * nb + k]
			if best < 0 or not bind.has(best) or not want.has(bind[best][0]):
				continue
			_crest_bone.append(bind[best][0])
			_crest_local.append((bind[best][1] as Transform3D) * v)
			_crest_normal.append(((bind[best][1] as Transform3D).basis * NR[i]).normalized())


static func full_clip(c: String) -> String:
	return c if "/" in c else "actor_b/" + c


func rider_clip_length(c: String) -> float:
	var n := full_clip(c)
	return anim_player.get_animation(n).length if anim_player.has_animation(n) else 1.0


func has_clip(c: String) -> bool:
	return anim_player.has_animation(full_clip(c))


func _physics_process(delta: float) -> void:
	if horse:
		sync(delta)


## Places the rider and poses it at the horse's phase. Call after the horse updated.
func sync(delta: float) -> void:
	var c := horse.rider_clip()
	if not has_clip(c):
		c = "actor_b-horse-idle"
	var n := full_clip(c)
	var L := rider_clip_length(c)
	var t := horse.rider_phase() * L
	var fade := horse.GAIT_FADE
	if STAND_IN.has(n):
		var si: Array = STAND_IN[n]
		if t >= si[0] and t <= si[1]:
			var sub: String = si[2]
			var Ls := anim_player.get_animation(sub).length
			n = sub
			t = fposmod(t, Ls)
		fade = STAND_IN_FADE
	if n != _clip:
		if _clip.is_empty():
			fade = 0.0
		_clip = n
	else:
		fade = 0.0
	if instant:
		fade = 0.0
	blender.show_clip(n, t, fade, horse.rider_rate())
	if anim_player.has_animation(INCLINE):
		blender.set_additive(INCLINE, incline_phase() * anim_player.get_animation(INCLINE).length, 1.0)
	blender.update(delta)
	# seat correction, cross-faded with the clips
	var off: Vector3 = CLIP_OFFSET.get(n, Vector3.ZERO)
	var pc := blender.previous_clip()
	if not pc.is_empty():
		off = (CLIP_OFFSET.get(pc, Vector3.ZERO) as Vector3).lerp(off, blender.active_weight())
	rider.global_transform = horse.get_saddle_transform() * Transform3D(Basis(), off)
	if follow_stirrups:
		_stirrups()
	if hand_ik:
		_hands()
	if drive_reins:
		var rt := skeleton.global_transform
		horse.set_rein_targets([rt * skeleton.get_bone_global_pose(_palm[0]).origin,
				rt * skeleton.get_bone_global_pose(_palm[1]).origin])


## Hangs each stirrup leather (fixed length) from its bar towards the rider's ball of the
## foot, hangs the iron from the leather's end, then moves the foot onto the tread with
## leg IK.
func _stirrups() -> void:
	var hs := horse.skeleton
	var inv := hs.global_transform.affine_inverse()
	var rt := skeleton.global_transform
	var up := (inv.basis * rt.basis.y).normalized()
	var iron_h: float = float(horse.meta.get("sockets", {}).get("stirrup_iron_height", 0.115))
	for si in 2:
		var side: String = ["l", "r"][si]
		var b := hs.find_bone("stirrup_" + side)
		var bi := hs.find_bone("stirrup_iron_" + side)
		if b < 0 or bi < 0:
			continue
		var leg: Array = _legs[si]
		var pg := hs.get_bone_global_pose(hs.get_bone_parent(b))
		var cur := pg * hs.get_bone_rest(b)
		var iron_rel := hs.get_bone_rest(bi)
		var L_leather := iron_rel.origin.length() * leather_scale
		var ball := inv * (rt * skeleton.get_bone_global_pose(leg[3]).origin)
		var target := ball - up * SOLE                      # where the tread would be under the foot
		var eye_want := target + up * iron_h
		var d := eye_want - cur.origin
		var nb := Basis(Quaternion(cur.basis.y.normalized(), d.normalized())) * cur.basis
		hs.set_bone_pose_rotation(b, (pg.basis.inverse() * nb).get_rotation_quaternion())
		hs.set_bone_pose_scale(b, Vector3(1.0, leather_scale, 1.0))
		var eye := cur.origin + nb.y.normalized() * L_leather
		var iron_rest := cur * iron_rel
		var idir := (target - eye).normalized()
		var ib := Basis(Quaternion(iron_rest.basis.y.normalized(), idir)) * iron_rest.basis.orthonormalized()
		hs.set_bone_global_pose(bi, Transform3D(ib, eye))
		# the tread hangs iron_h below the eye; the ball of the foot goes SOLE above it
		var tread := eye + idir * iron_h
		var foot_goal := hs.global_transform * (tread + up * SOLE)
		if foot_ik:
			foot_correction[si] = _leg_ik(leg, foot_goal)


## Two-bone IK of one leg (upper_leg -> knee -> ankle) so that the ball of the foot reaches
## `goal` (global): the foot moves rigidly and keeps its orientation, the knee stays in its
## clip plane. Fades out for corrections beyond FOOT_IK_REACH. Returns the correction (m).
func _leg_ik(leg: Array, goal: Vector3) -> float:
	var sk := skeleton
	var gi := sk.global_transform.affine_inverse()
	var H_ := sk.get_bone_global_pose(leg[0])
	var K_ := sk.get_bone_global_pose(leg[1])
	var A_ := sk.get_bone_global_pose(leg[2])
	var B_ := sk.get_bone_global_pose(leg[3])
	var g := gi * goal
	var delta := g - B_.origin
	var dist := delta.length()
	var w := 1.0 - smoothstep(FOOT_IK_REACH.x, FOOT_IK_REACH.y, dist)
	if w <= 0.0 or dist < 1e-4:
		return dist
	var H := H_.origin
	var K := K_.origin
	var A := A_.origin
	var A_goal := A + delta * w
	var l1 := H.distance_to(K)
	var l2 := K.distance_to(A)
	var axis := A_goal - H
	var d := clampf(axis.length(), absf(l1 - l2) + 1e-4, (l1 + l2) * 0.999)
	axis = axis.normalized()
	var pole := (K - H) - axis * (K - H).dot(axis)
	if pole.length() < 1e-5:
		pole = (K_.basis.z).normalized()
	pole = pole.normalized()
	var ca := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var al := acos(ca)
	var K2 := H + l1 * (cos(al) * axis + sin(al) * pole)
	var A2 := H + axis * d
	var q1 := Quaternion((K - H).normalized(), (K2 - H).normalized())
	var hip := Transform3D(Basis(q1) * H_.basis, H)
	sk.set_bone_global_pose(leg[0], hip)
	var shin_now := Basis(q1) * (A - K)
	var q2 := Quaternion(shin_now.normalized(), (A2 - K2).normalized())
	sk.set_bone_global_pose(leg[1], Transform3D(Basis(q2) * Basis(q1) * K_.basis, K2))
	sk.set_bone_global_pose(leg[2], Transform3D(A_.basis, A2))
	return dist


## Keeps each hand out of the horse's neck and withers: the palm and finger joints are
## tested against the crest skin (signed distance to the nearest skin vertex along its
## normal); a hand that would dip into it is moved out along that normal (arm IK), with
## HAND_CLEAR for the palm joint and FINGER_CLEAR for the finger joints. Hands that are
## clear already stay as the clip has them.
func _hands() -> void:
	if _crest_local.is_empty():
		return
	var hs := horse.skeleton
	var sad := horse.get_saddle_transform()
	var inv := sad.affine_inverse()
	var rt := skeleton.global_transform
	var bone_g := {}
	for si in 2:
		var arm: Array = _arms[si]
		hand_correction[si] = 0.0
		if arm[0] < 0 or arm[3] < 0:
			continue
		var palm := inv * (rt * skeleton.get_bone_global_pose(arm[3]).origin)
		# crest skin near this hand, in the saddle frame, now
		var P := PackedVector3Array()
		var N := PackedVector3Array()
		for i in _crest_local.size():
			var b := _crest_bone[i]
			if not bone_g.has(b):
				bone_g[b] = inv * hs.global_transform * hs.get_bone_global_pose(b)
			var t: Transform3D = bone_g[b]
			var p := t * _crest_local[i]
			if p.distance_squared_to(palm) < 0.04:
				P.append(p)
				N.append((t.basis * _crest_normal[i]).normalized())
		if P.is_empty():
			continue
		var moved := Vector3.ZERO
		for it in 3:
			var worst := 0.0
			var dir := Vector3.ZERO
			for k in (_hand_pts[si] as Array).size():
				var bi: int = _hand_pts[si][k]
				var q := inv * (rt * skeleton.get_bone_global_pose(bi).origin)
				var clear := HAND_CLEAR if k == 0 else FINGER_CLEAR
				var bd := 0.0064
				var bj := -1
				for j in P.size():
					var d2 := q.distance_squared_to(P[j])
					if d2 < bd:
						bd = d2
						bj = j
				if bj < 0:
					continue
				var pen := clear - (q - P[bj]).dot(N[bj])
				if pen > worst:
					worst = pen
					dir = N[bj]
			if worst <= 1e-4:
				break
			moved += dir * worst
			_arm_ik(arm, sad.basis * (dir * worst))
		hand_correction[si] = moved.length()


## Phase of the incline additive for the horse's body pitch (0.5 = level).
func incline_phase() -> float:
	var deg: float = horse.terrain.body_pitch_deg if horse.terrain else 0.0
	return clampf(0.5 - deg / INCLINE_FULL, 0.0, 1.0)


## Two-bone IK of one arm (shoulder -> elbow -> wrist): the wrist, and with it the hand,
## moves by `delta` (global) and keeps its orientation; the elbow stays in its clip plane.
func _arm_ik(arm: Array, delta: Vector3) -> void:
	var sk := skeleton
	var gi := sk.global_transform.affine_inverse()
	var S_ := sk.get_bone_global_pose(arm[0])
	var E_ := sk.get_bone_global_pose(arm[1])
	var W_ := sk.get_bone_global_pose(arm[2])
	var S := S_.origin
	var E := E_.origin
	var Wp := W_.origin
	var goal := Wp + gi.basis * delta
	var l1 := S.distance_to(E)
	var l2 := E.distance_to(Wp)
	var axis := goal - S
	var d := clampf(axis.length(), absf(l1 - l2) + 1e-4, (l1 + l2) * 0.999)
	axis = axis.normalized()
	var pole := (E - S) - axis * (E - S).dot(axis)
	if pole.length() < 1e-5:
		return
	pole = pole.normalized()
	var ca := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var al := acos(ca)
	var E2 := S + l1 * (cos(al) * axis + sin(al) * pole)
	var W2 := S + axis * d
	var q1 := Quaternion((E - S).normalized(), (E2 - S).normalized())
	sk.set_bone_global_pose(arm[0], Transform3D(Basis(q1) * S_.basis, S))
	var fore_now := Basis(q1) * (Wp - E)
	var q2 := Quaternion(fore_now.normalized(), (W2 - E2).normalized())
	sk.set_bone_global_pose(arm[1], Transform3D(Basis(q2) * Basis(q1) * E_.basis, E2))
	sk.set_bone_global_pose(arm[2], Transform3D(W_.basis, W2))


## Releases the stirrups (rest pose).
func release_stirrups() -> void:
	var hs := horse.skeleton
	for s in ["stirrup_l", "stirrup_r", "stirrup_iron_l", "stirrup_iron_r"]:
		var b := hs.find_bone(s)
		if b >= 0:
			hs.reset_bone_pose(b)
