extends SceneTree
## The Ice Spear on the game's own standing pistol aim (the owner, 2026-10-12: "the lightning pistol... we dont have that skill
## and use that animation for the ice or water rifle spear for water? and we keep the orignal lightning animation"; first
## built 2026-10-11 for the Lightning Pistol twist on "use our musket and pistol tech that we built in frontiers over"):
## frontier-pistol-ice in animations_extra/Frontier_Bend_Aim.res, on the timeline of the Ice Spear's rifle clip
## (own-bend-water-ice-rifle: its length, hold_s, strike_s and back_s, so the cast takes the time it always did); the old
## frontier-pistol-lightning taken out of the library (REMOVED):
##   the body   the pistol's standing aim as PlayerAnim builds it: the twisted stance (Frontier_Downgraded.res
##              actor_b-p-pistol-aim-idle, mocap_downgrade_all._twisted_stance), its right arm the bow's aim mirrored
##              (PlayerAnim.STAND_AIM_ARM own-pistol-bow-arm at its start, as PlayerAnim takes it), its left arm the plain idle's
##              hanging at the side (Actor_B.res actor_b-p-relax-idle at phase 0: PlayerAnim.one_hand_left_arm), each arm's
##              clavicle-to-fingertips turns as LeftArmPose sets them
##   the hand   our own two fingers out (own-bend-fire-lightning-duel's right hand at its strike), turned at the wrist so they go
##              straight on along the forearm (_straight_hand: the bow's grip cocks the wrist)
##   the time   raised from water's stance (own-bend-stance-water) over RAISE_S, held on the aim through the lock and the
##              strike, the kick at the strike (KICK_DEG up at the shoulder, the wrist a share of it, in over KICK_IN_S and back
##              over KICK_BACK_S), lowered from back_s to the stance by the end
## In the game SwayPose plays it (the pick's "aim": "pistol": standing the whole body, moving the right arm alone over the jog's
## body, as the pistol's own aims) and BendAimArm turns the arm onto the crosshair and the head toward it after it (the jog aim's
## JogAimArm, the two fingers for the muzzle), the kick put back after the turn from the clip's kick metas. The water spear
## (BendLooks.HeldSpear, its row's "held") forms out from the pointing hand. A bot plays the clip as it is (its body faces its
## mark).
## Provenance: the body and both arms come from the Frontier pistol aim's clips (the base library's lineage: animations/SOURCE.md);
## the hand and the timing are ours. Named frontier- (not own-) in a library of its own: BendPoses plays it as Frontier tech the
## owner picked (poses.json "frontier_tech").
##   Godot --headless --path . -s tools/anim_author/bake_bend_aim.gd

const OUT_LIB := "res://animations_extra/Frontier_Bend_Aim.res"
const NAME := "frontier-pistol-ice"
## Taken out of the library as this bake saves it (the Lightning Pistol twist, gone 2026-10-12).
const REMOVED := ["frontier-pistol-lightning"]
const DOWN_LIB := "res://animations_extra/Frontier_Downgraded.res"
const NATIVE_LIB := "res://animations/Actor_B.res"
const BEND_LIB := "res://animations_extra/Frontier_Bend.res"
## The standing aim's body (PlayerAnim.JOG_AIM_ARM.pistol, the graph's clip as the downgraded library has it: the twisted stance).
const STANCE := "actor_b-p-pistol-aim-idle"
const LEFT_ARM := "actor_b-p-relax-idle"
const FROM_STANCE := "own-bend-stance-water"
const TIMING := "own-bend-water-ice-rifle"
const HAND := "own-bend-fire-lightning-duel"
const FPS := 30.0
const RAISE_S := 0.3
const KICK_DEG := 11.0
const WRIST_KICK := 0.6
const KICK_IN_S := 0.04
const KICK_BACK_S := 0.22
## LeftArmPose's arm (clavicle to wrist) and hand bones.
const ARM := ["clavicle", "shoulder", "elbow", "wrist"]
const HAND_KEYS := ["palm", "index", "middle", "ring", "pinky", "thumb"]
const FINGERS := ["index", "middle", "ring", "pinky", "thumb"]
## The kick's curve (BendAimArm.kick_curve: the game puts the same back after its turn).
const BEND_AIM_ARM := preload("res://scripts/bending/bend_aim_arm.gd")
const AUTHORED := "Frontier tech composite (tools/anim_author/bake_bend_aim.gd): the pistol's standing aim (Frontier_Downgraded.res actor_b-p-pistol-aim-idle twisted stance and own-pistol-bow-arm, built from the base library animations/Actor_B.res; Actor_B.res actor_b-p-relax-idle for the hanging left arm) with our own two-finger hand (own-bend-fire-lightning-duel) on our own Ice Spear's timing (own-bend-water-ice-rifle), raised from our water stance (own-bend-stance-water)"


func _initialize() -> void:
	var down := load(DOWN_LIB) as AnimationLibrary
	var native := load(NATIVE_LIB) as AnimationLibrary
	var bend := load(BEND_LIB) as AnimationLibrary
	for need: Array in [[down, STANCE], [down, PlayerAnim.STAND_AIM_ARM], [native, LEFT_ARM], [bend, FROM_STANCE], [bend, TIMING],
			[bend, HAND]]:
		if need[0] == null or not (need[0] as AnimationLibrary).has_animation(String(need[1])):
			push_error("bake_bend_aim: missing %s" % need[1])
			quit(1)
			return
	var stance := down.get_animation(STANCE)
	var bow_arm := down.get_animation(PlayerAnim.STAND_AIM_ARM)
	var left := native.get_animation(LEFT_ARM)
	var fire := bend.get_animation(FROM_STANCE)
	var timing := bend.get_animation(TIMING)
	var hand := bend.get_animation(HAND)
	var ch := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(ch)
	var sk := ch.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var hold := float(timing.get_meta(&"hold_s"))
	var strike := float(timing.get_meta(&"strike_s"))
	var back := float(timing.get_meta(&"back_s"))
	var length := timing.length
	# the bones our own clips key (the stance's tracks: every body bone, the fingers, the root's place)
	var bones: Array[String] = []
	for ti in fire.get_track_count():
		if fire.track_get_type(ti) == Animation.TYPE_ROTATION_3D:
			bones.append(String(fire.track_get_path(ti).get_concatenated_subnames()))
	var prefix := String(fire.track_get_path(0)).get_slice(":", 0)
	var right_arm := _arm_bones(sk, "r")
	var left_arm := _arm_bones(sk, "l")
	var two_fingers: Array[String] = []
	for bn in right_arm:
		for f: String in FINGERS:
			if bn.substr(2).begins_with(f):
				two_fingers.append(bn)
	var hand_t := float(hand.get_meta(&"strike_s"))
	var root_i := sk.find_bone("root")
	var shoulder := sk.find_bone("r_shoulder")
	var wrist := sk.find_bone("r_wrist")
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_NONE
	var tr := {}
	for bn in bones:
		var t := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(t, NodePath(prefix + ":" + bn))
		tr[bn] = t
	var rp := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(rp, NodePath(prefix + ":root"))
	var last := {}
	var n := int(round(length * FPS))
	for f in n + 1:
		var t := minf(f / FPS, length)
		# the stance he raises it from and lowers it to
		_pose(sk, fire, fmod(t, fire.length))
		var from := _local(sk, bones)
		var from_root := sk.get_bone_pose_position(root_i)
		# the pistol's standing aim: the twisted stance, the bow's arm on the right, the idle's hanging arm on the left, our hand
		_pose(sk, stance, fmod(t, stance.length))
		_arm(sk, bow_arm, 0.0, right_arm)
		_arm(sk, left, 0.0, left_arm)
		_arm(sk, hand, hand_t, two_fingers)
		_straight_hand(sk)
		var aim := _local(sk, bones)
		var aim_root := sk.get_bone_pose_position(root_i)
		var k := smoothstep(0.0, RAISE_S, t) * (1.0 - smoothstep(back, length, t))
		sk.reset_bone_poses()
		for bn in bones:
			var b := sk.find_bone(bn)
			sk.set_bone_pose_rotation(b, (from[bn] as Quaternion).slerp(aim[bn], k).normalized())
		sk.set_bone_pose_position(root_i, from_root.lerp(aim_root, k))
		# the kick: the arm tipped up at the shoulder (the wrist a share of it), about the arm's own level axis
		var kick := BEND_AIM_ARM.kick_curve(t, strike, KICK_DEG, KICK_IN_S, KICK_BACK_S) * k
		if kick > 0.0:
			_kick(sk, shoulder, wrist, deg_to_rad(kick), WRIST_KICK)
		for bn in bones:
			var q := sk.get_bone_pose_rotation(sk.find_bone(bn)).normalized()
			if last.has(bn) and (last[bn] as Quaternion).dot(q) < 0.0:
				q = -q
			last[bn] = q
			a.rotation_track_insert_key(tr[bn], t, q)
		a.position_track_insert_key(rp, t, sk.get_bone_pose_position(root_i))
	a.set_meta(&"authored", AUTHORED)
	a.set_meta(&"lineage", "Frontier tech: the body and both arms from the base library's pistol aim (animations/SOURCE.md); the hand and the timing ours")
	a.set_meta(&"hold_s", hold)
	a.set_meta(&"strike_s", strike)
	a.set_meta(&"back_s", back)
	a.set_meta(&"hand", "r")
	a.set_meta(&"mask", "upper")
	a.set_meta(&"root", false)
	a.set_meta(&"aim", "pistol")
	a.set_meta(&"aim_in_s", RAISE_S)
	a.set_meta(&"kick_deg", KICK_DEG)
	a.set_meta(&"wrist_kick", WRIST_KICK)
	a.set_meta(&"kick_in_s", KICK_IN_S)
	a.set_meta(&"kick_back_s", KICK_BACK_S)
	var lib := AnimationLibrary.new()
	if ResourceLoader.exists(OUT_LIB):
		lib = (load(OUT_LIB) as AnimationLibrary).duplicate(true) as AnimationLibrary
	for old: String in REMOVED + [NAME]:
		if lib.has_animation(old):
			lib.remove_animation(old)
	lib.add_animation(NAME, a)
	var err := ResourceSaver.save(lib, OUT_LIB, ResourceSaver.FLAG_COMPRESS)
	print("BEND AIM saved %d -> %s: %s %.3f s, hold %.3f strike %.3f back %.3f, %d bones" % [err, OUT_LIB, NAME, length, hold,
			strike, back, bones.size()])
	quit(0 if err == OK else 1)


## The right arm tipped up by `rad` at the shoulder and `share` of it more at the wrist, about the level axis across the arm.
static func _kick(sk: Skeleton3D, shoulder: int, wrist: int, rad: float, share: float) -> void:
	sk.force_update_all_bone_transforms()
	var s := sk.get_bone_global_pose(shoulder)
	var w := sk.get_bone_global_pose(wrist)
	var d := (w.origin - s.origin).normalized()
	var axis := d.cross(Vector3.UP)
	if axis.length_squared() < 1e-6:
		return
	axis = axis.normalized()
	for pair: Array in [[shoulder, rad], [wrist, rad * share]]:
		sk.force_update_all_bone_transforms()
		var b: int = pair[0]
		var g := sk.get_bone_global_pose(b)
		var p := sk.get_bone_parent(b)
		var pg := sk.get_bone_global_pose(p).basis.orthonormalized() if p >= 0 else Basis()
		var turned := Basis(axis, float(pair[1])) * g.basis.orthonormalized()
		sk.set_bone_pose_rotation(b, (pg.inverse() * turned).get_rotation_quaternion().normalized())


## The right hand turned at the wrist so the two fingers go straight on along the forearm (a pointing hand). The bow's grip
## cocks the wrist down and in; with the fingers turned onto the crosshair in the game (BendAimArm) that cocked wrist raised
## the whole arm some 35 degrees off the aim (seen 2026-10-11 in the first stills).
static func _straight_hand(sk: Skeleton3D) -> void:
	sk.force_update_all_bone_transforms()
	var wi := sk.find_bone("r_wrist")
	var e := sk.get_bone_global_pose(sk.find_bone("r_elbow")).origin
	var w := sk.get_bone_global_pose(wi)
	var g := func(bn: String) -> Vector3: return sk.get_bone_global_pose(sk.find_bone(bn)).origin
	var base: Vector3 = (g.call("r_indexa") + g.call("r_middlea")) * 0.5
	var tip: Vector3 = (g.call("r_indexc") + g.call("r_middlec")) * 0.5
	var fore := (w.origin - e).normalized()
	var fing := (tip - base).normalized()
	if fore.length_squared() < 1e-6 or fing.length_squared() < 1e-6 or fing.dot(fore) > 0.9999:
		return
	var turn := Quaternion(fing, fore)
	var pb := sk.get_bone_global_pose(sk.get_bone_parent(wi)).basis.orthonormalized()
	var turned := Basis(turn) * w.basis.orthonormalized()
	sk.set_bone_pose_rotation(wi, (pb.inverse() * turned).get_rotation_quaternion().normalized())


## The skeleton posed by `a` at `t` (from rest: what it leaves out is at rest).
static func _pose(sk: Skeleton3D, a: Animation, t: float) -> void:
	sk.reset_bone_poses()
	for ti in a.get_track_count():
		var b := sk.find_bone(String(a.track_get_path(ti).get_concatenated_subnames()))
		if b < 0:
			continue
		match a.track_get_type(ti):
			Animation.TYPE_ROTATION_3D:
				sk.set_bone_pose_rotation(b, a.rotation_track_interpolate(ti, t))
			Animation.TYPE_POSITION_3D:
				if b == sk.find_bone("root"):
					sk.set_bone_pose_position(b, a.position_track_interpolate(ti, t))


## Bones `names` turned as `a` has them at `t` (their local turns, as LeftArmPose sets an arm's), the rest left.
static func _arm(sk: Skeleton3D, a: Animation, t: float, names: Array[String]) -> void:
	for ti in a.get_track_count():
		if a.track_get_type(ti) != Animation.TYPE_ROTATION_3D:
			continue
		var bn := String(a.track_get_path(ti).get_concatenated_subnames())
		if bn in names:
			sk.set_bone_pose_rotation(sk.find_bone(bn), a.rotation_track_interpolate(ti, t))


## Each bone's local turn now.
static func _local(sk: Skeleton3D, bones: Array[String]) -> Dictionary:
	var d := {}
	for bn in bones:
		d[bn] = sk.get_bone_pose_rotation(sk.find_bone(bn)).normalized()
	return d


## LeftArmPose's bones of side `s`: the clavicle to the wrist, the palm and the fingers (no helper, twist or prop bone).
static func _arm_bones(sk: Skeleton3D, s: String) -> Array[String]:
	var out: Array[String] = []
	var pre := s + "_"
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		if not n.begins_with(pre) or n.contains("helper") or n.contains("twist") or n.contains("prop"):
			continue
		var keep := n.substr(2) in ARM
		for k: String in HAND_KEYS:
			if n.substr(2).begins_with(k):
				keep = true
		if keep:
			out.append(n)
	return out
