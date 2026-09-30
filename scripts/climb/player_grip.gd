class_name PlayerGrip
extends Node
## Gripping and climbing on rock faces and moving bodies (user 2026-09-27: "Grab and attach to a bone of a moving
## object... Crawl in four directions, with grip stamina. Swing on the pendulum settings, and play the right 'being
## shaken' clip... Climb up onto flat parts, and fall off when the grip gives out"), with the Actor_C grip and hang clips
## on the player's own skeleton (animations_extra/Actor_B_from_C.res, library actor_b_from_c).
##
##   press G at a grippable surface (G again lets go) (GripSurface: a rock face, a giant's fur)   grab it: a catch ("hang") at a wall ahead,
##                     in the air as well, or a crouch onto it ("grip_start") when standing on it
##   W A S D           crawl over the surface: up / down the slope and to the sides (grip_move_f1 / f2, _b, _l, _r);
##                     the body moves as far as the clip's planted hands and feet (climb_clips.json "travel"), wraps
##                     round corners, and at the top edge pulls up onto a flat top (hang_up) and stands (grip_end)
##   G again           drop off (on a flat part: stand up)
##   stamina           drains while holding on, faster crawling, hanging on a steep face and when shaken; at zero the
##                     grip gives out (grip_fail1) and the player falls; refills on the ground (the ring by the crosshair)
##
## The clips turn the bones only (the source game moved the body itself), so this places the skeleton: the grip's
## anchor is a Node3D under the gripped collider (or the node it offers, GripSurface.parent_for) whose basis is the
## surface frame (Y the surface normal, Z the body's forward along it); a clip authored lying on the surface ("S") shows in
## that frame, a clip hanging upright ("H") in the frame turned 90 degrees about X, and a cross-fade between the two
## turns the frame with the pose so the body stays where it is. The pelvis sits the clip's measured standoff off the
## surface. A moving body carries the anchor, and the anchor's acceleration swings the body about the hands like a
## pendulum (gravity and the jolts; the climber pulls back in); the swing and the jolts pick the "being shaken" clips
## (grip2_float_<dir>_lo for a lurch of the surface toward <dir>, grip_float_u_md / _hi while the body is flung off the
## surface, grip_float_l_hi / r_hi for a big sideways swing).
##
## The cross-fades and the follow-on clips come from the source game's own tree (data/climb/climb_tree.json: the rows'
## blend frames at 30 fps). Its pendulum setup table is kept in that file but its fields are not decoded; the swing here
## uses its own constants (below).

signal grabbed(kind: String)
signal released(reason: String)          ## "let_go", "stamina", "stand", "dead", "lost"
signal climbed_up

enum { OFF, GRAB, HOLD, UP, STAND, FAIL }

const LIB := "actor_b_from_c"
const PRE := "actor_c-"
## Crouched on a branch the camera turns this far (rad) either side of the branch's way out, not round into the trunk.
const PERCH_YAW := 2.0
## Space held this long jumps off a branch (a tap does nothing: no falling off by mistake).
const PERCH_JUMP_S := 0.35
## The weapons one hand can use while the other holds on (user 2026-09-27: "for hanging i think being able to shoot
## pistols throw axes and spears should be okay", then "it should be like they are climbing up but one hand is free
## right? should only work in front of the user like on a tree", "so we can use that hang for the one hand free aim?
## with matching Ik"): RMB on a grip with one of them in the loadout plays the source's own one-hand draw from the hang
## (hang_atk_start: the left hand takes a lower, deeper hold, the body leans out, the right arm comes free) and holds
## there; a pistol is aimed from that pose by GripAimArm (the arm onto the crosshair); a throw winds up as the charged
## stab does (hang_atk_tame_a / _loop: the arm drawn far back) and is let go with its strike (hang_atk_drop, _a). The
## aim keeps in front of the climber (HANG_AIM_YAW either side of the way they face: past a trunk to the front and the
## sides, never round behind them).
const HANG_WEAPONS := ["pistol", "tomahawk", "spear"]
const HANG_AIM_YAW := 1.75
const LIB_PATH := "res://animations_extra/Actor_B_from_C.res"
const CLIPS_PATH := "res://data/climb/climb_clips.json"
const TREE_PATH := "res://data/climb/climb_tree.json"
## The pelvis in the clips (skeleton space; the clips never move it).
const PELVIS := Vector3(0.0, 0.90, 0.02)
## The contacts' bone centres are this far off the surface.
const SKIN := 0.035
## The hands hold this far ahead of the anchor (along the body's forward): the swing's pivot.
const HANDS_AHEAD := 0.78
## The body (capsule origin) under the pelvis while climbing: the camera follows it.
const BODY_BELOW_PELVIS := 0.95
## The frame of the upright ("H") clips from the surface frame.
const HROT := Basis(Vector3.RIGHT, PI * 0.5)
const MIN_FADE := 0.08
const DEFAULT_FADE := 0.15
## From the player's own placement into the grip's (seconds).
const CATCH_S := 0.28
## The rig back to the player's own placement after letting go.
const RETURN_S := 0.3
## Melee spends the same stamina (AxeMelee.pay, spend): none comes back for this long after each spend.
const REST_S := 1.0

@export var reach := 0.85                  ## m from the body to a surface it can grab
@export var stamina_max := 100.0           ## the source's player parameter is 100 (its meaning is not decoded)
@export var drain_hold := 2.0              ## stamina / s holding on
@export var drain_steep := 1.5             ## more on a vertical face
@export var drain_move := 2.5              ## more crawling
@export var drain_float_md := 5.0          ## more while flung off the surface
@export var drain_float_hi := 10.0
@export var drain_swing := 1.2             ## more per rad/s of swing
## The whole drain x this: an arm wound tires the grip sooner (the survival bridge sets it: LastingConditions).
var drain_mult := 1.0
@export var drain_jolt := 0.35             ## more per m/s2 the surface shakes
@export var regain := 30.0                 ## stamina / s back on the ground
@export var hang_idle_deg := 72.0          ## steeper than this the idle hangs (hang_loop), below 62 it clings (grip_loop)
@export var stand_up_max_deg := 40.0       ## letting go on a part flatter than this stands up
@export var turn_rate := 2.2               ## rad / s the body turns toward the stick on a gentle part
@export var perch_regain := 20.0           ## stamina / s crouched on a branch, not aiming
@export var drain_one_hand := 3.0          ## stamina / s more hanging one-handed with a weapon out
## The camera on a branch (user 2026-09-27: "zoom in the camera and make the player fade so we can see what we are
## looking at and shooting at"): nearer and over the right shoulder, nearer still aiming; the player's body fades out
## aiming there, and whenever the camera is right up against it.
@export var perch_cam_distance := 2.2
@export var perch_aim_distance := 1.3
@export var perch_shoulder := 0.45
@export var perch_aim_shoulder := 0.55
@export var aim_fade := 0.7                ## the body's transparency aiming from a branch
@export var near_fade_m := Vector2(0.55, 1.1)   ## the body fades as the camera comes within these (m, fully .. none)
## Up a tree the leaves and limbs of its crown this near the climber fade out (the ground shows through; user
## 2026-09-28: "when we are on a tree the branchs should fade so we can see the ground"); 0: only the line of sight.
@export var crown_clear_m := 4.5
## The swing (the climber hanging from the hands, 1 m to the body's centre; springs: the climber pulling back in).
@export var swing_len := 1.0
@export var swing_k_side := 18.0
@export var swing_k_lift := 30.0
@export var swing_damp := 4.5
@export var jolt_lo := 6.0                 ## m/s2 of the surface: a small lurch clip
@export var lift_md := 0.35                ## rad off the surface: flung (u_md), then u_hi
@export var lift_hi := 0.8
## The shaking (the surface's acceleration, smoothed over ~0.25 s, m/s2) that flings the legs off the surface: a big
## shake (u_md, then u_hi); small shakes stay under it and only jostle (the lurch clips). While flung the body hangs
## off the surface about the hands (float_lift_md / _hi rad).
@export var shake_md := 7.5
@export var shake_hi := 11.0
@export var shake_calm := 4.5
@export var float_lift_md := 0.08
@export var float_lift_hi := 0.15
## A body that says how hard it shakes (grip_shake() -> 0..1 on the gripped part or an ancestor, e.g. StandInGiant)
## flings the legs off only past these: its big shakes, not its small ones.
@export var body_shake_md := 0.5
@export var body_shake_hi := 0.85
@export var body_shake_calm := 0.25
## On a gentle part the body lies on the surface: the sideways swing is this much stiffer there than hanging on a steep
## face (it would spin the body about the hands).
@export var gentle_side_stiff := 5.0
## Shaken, the climber cannot pull in: the swing's springs drop to this share at a full shake (the body sways).
@export var shaken_stiff := 0.35
## Stamina / s more at a full shake.
@export var drain_shaken := 8.0
## The source's "flung off" loops (grip_float_u_md / _hi, grip_float_l_hi / r_hi) in the shakes. Off: the body's swing
## and the legs' own sway (GripLegSway) show the shaking instead (user 2026-09-27: "it was more sway and physics based").
@export var flail_clips := false
## Thrown clear when the grip gives out on a moving body: up and away from its middle (m/s).
@export var throw_up := 2.6
@export var throw_out := 3.4
## The share of the clips' leg bend shown while crawling (the source's crawl swings the legs too wide), and held still.
@export var crawl_leg_amount := 0.55
@export var side_hi := 0.6                 ## rad sideways: the big sideways swing clip

var player: FrontierPlayer
var state := OFF
var stamina := 100.0
var _rest := 0.0                 ## s till stamina comes back again after melee spent some (REST_S)
var anchor: Node3D
var gripped: CollisionObject3D
var kind := ""
## The clips (climb_clips.json) and the tree's cross-fades ("from>to" -> seconds; "from>" -> the follow-on clip).
var clips := {}
var fades := {}
var follow := {}

var _ap: AnimationPlayer
var _blend: HorsePhaseBlender
var _rig: Node3D
var _rig_local: Transform3D
var _sk_in_rig: Transform3D
var _clip := ""
var _t := 0.0
var _prev := ""
var _prev_t := 0.0
var _moving := ""                ## the crawl clip playing ("" idle)
var _f_next := "grip_move_f1"
var _hang_idle := false
var _react := ""                 ## a one-shot shaken clip playing
var _float := ""                 ## "", "md", "hi": flung off the surface
var _float_low_t := 0.0
var _react_cool := 0.0
var _swing := Vector2.ZERO       ## x about the normal (sideways), y about the body's left axis (off the surface)
var _swing_v := Vector2.ZERO
var _par_last: Node3D
var _par_xf: Transform3D
var _avel := Vector3.ZERO
var _aacc := Vector3.ZERO
var _jolt := Vector3.ZERO        ## the surface's acceleration in the frame (x left, y normal, z forward)
var shake_level := 0.0           ## |_jolt| smoothed (m/s2): how hard the surface shakes now
var _have_prev := false
var _cool := 0.0
var _catch_t := -1.0
var _catch_from: Transform3D     ## the skeleton's placement when the grab (or a wrap) started, in the anchor's frame
var _up := {}                    ## the climb onto a top
var _ret_t := -1.0
var _ret_from: Transform3D
var _grip_held_t := 0.0
var _latched := false            ## G toggled on: gripping until the next press
var _need_press := false         ## after standing up on a top: G must be let go and pressed again to grip
var _travel_last := Vector3.ZERO
var _prev_fade := DEFAULT_FADE
var _ring: GripRing
## The branches to sit on at the top of the trunks near the player.
var perch: PerchBranches
var _perch_from := {}            ## the bark the climber came up (back onto it when leaving the branch)
var _catch_s := CATCH_S
var perched := false             ## crouched on a branch (the player's own body, player.perch)
var _perch_up := false           ## the pull-up playing goes onto a branch
var _perch_dir := Vector3.FORWARD
var _perch_face := Vector3.FORWARD
var _jump_hold := 0.0
var _off_t := 0.0
var _clear_w := 0.0              ## the line-of-sight fade's strength (veg_clear_*)
var _crown_r := 0.0              ## the crown clear's radius now (kept while the fade goes out)
## Hanging one-handed with a weapon out (HANG_WEAPONS).
var hang_aim := false
var aim_arm: GripAimArm
var _arm_w := 0.0
var _anim_release := false       ## the throwable's wait_for_anim_release, put back after
var _cam_w := 0.0                ## 0 the player's own camera .. 1 the branch's
var _aim_w := 0.0                ## aiming from the branch
var _body_fade := 0.0            ## the body's transparency now
var _fade_meshes: Array = []
var _fade_scan := 0.0
## The legs' physical sway while gripping.
var legs: GripLegSway
## How hard the surface shakes the climber now, 0..1 (the body's own say, else the measured shaking).
var shake_amt := 0.0


static func install(p: FrontierPlayer) -> PlayerGrip:
	var g := PlayerGrip.new()
	g.name = "Grip"
	g.player = p
	p.add_child(g)
	g._setup()
	return g


func _setup() -> void:
	stamina = stamina_max
	_load_data()
	_ap = player.anim.get_node(player.anim.anim_player) as AnimationPlayer
	if not _ap.has_animation_library(LIB) and ResourceLoader.exists(LIB_PATH):
		_ap.add_animation_library(LIB, load(LIB_PATH) as AnimationLibrary)
	_rig = player.skeleton.get_parent() as Node3D
	while _rig != null and _rig.get_parent() != player.visual:
		_rig = _rig.get_parent() as Node3D
	if _rig == null:
		_rig = player.skeleton.get_parent() as Node3D
	_rig_local = _rig.transform
	_sk_in_rig = _rig.global_transform.affine_inverse() * player.skeleton.global_transform
	perch = PerchBranches.install(player)
	legs = GripLegSway.new()
	legs.name = "GripLegSway"
	legs.active = false
	legs.influence = 0.0
	var sk := player.skeleton
	sk.add_child(legs)
	aim_arm = GripAimArm.new()
	aim_arm.name = "GripAimArm"
	aim_arm.active = false
	aim_arm.influence = 0.0
	sk.add_child(aim_arm)
	for m: SkeletonModifier3D in [legs, aim_arm]:
		for i in sk.get_child_count():
			if sk.get_child(i) is CharacterBodyMesh:
				sk.move_child(m, i)
				break
	# (the ring is this machine's player's, on its screen; another player on the map has none)
	if not player.is_local:
		return
	var layer := CanvasLayer.new()
	layer.name = "GripHUD"
	layer.layer = 4
	add_child(layer)
	_ring = GripRing.new()
	_ring.grip = self
	layer.add_child(_ring)


func _load_data() -> void:
	var c = JSON.parse_string(FileAccess.get_file_as_string(CLIPS_PATH))
	if c is Dictionary:
		clips = (c as Dictionary).get("clips", {})
	var t = JSON.parse_string(FileAccess.get_file_as_string(TREE_PATH))
	if not (t is Dictionary):
		return
	var states: Dictionary = t.get("states", {})
	var fps := float(t.get("fps", 30))
	for e: Array in t.get("edges", []):
		var a := str((states.get(str(int(e[1])), {}) as Dictionary).get("clip", ""))
		var b := str((states.get(str(int(e[2])), {}) as Dictionary).get("clip", ""))
		if a == "" or b == "":
			continue
		var key := a + ">" + b
		var f := float(e[5]) / fps
		fades[key] = minf(float(fades.get(key, f)), f)
		if float(e[4]) < 0.0 and str(e[3]).begins_with("上記") and not follow.has(a):
			follow[a] = b


# --------------------------------------------------------------------------------------------------
# The player's hook
# --------------------------------------------------------------------------------------------------

## Spends `amount` of stamina on something else than holding on (a melee attack, a feint, a parry: AxeMelee.pay):
## false, and nothing spent, when there is not that much; none comes back for REST_S.
func spend(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if stamina < amount:
		return false
	stamina -= amount
	_rest = REST_S
	return true


## Per physics tick from the player, before its own movement: true while the grip owns the body.
func tick(dt: float) -> bool:
	_cool = maxf(_cool - dt, 0.0)
	_rest = maxf(_rest - dt, 0.0)
	var raw := player.controls.pressed(&"grip")
	var tapped := player.controls.just_pressed(&"grip")
	# G toggles (user 2026-09-28: "it should be toggle g not a hold"): a press grabs, the next press lets go
	if tapped and state != OFF:
		_latched = false
	var held := _latched
	if not raw:
		_need_press = false
	if state == OFF and _gear_on:
		_feed_gear()
	if state == OFF and perched:
		return _perch_tick(dt)
	if state == OFF:
		if player.is_on_floor() and _rest <= 0.0:
			stamina = move_toward(stamina, stamina_max, regain * dt)
		if tapped and not _need_press and _cool <= 0.0 and stamina > 5.0 and _can_grab():
			# beside a wild horse: its mane, and up onto its back (HorseBreaking); the player is on it now
			if HorseBreaking.try_grab(player):
				return true
			return _try_grab()
		return false
	if player.is_dead:
		_let_go(0.0, "dead")
		return false
	if not is_instance_valid(anchor) or not is_instance_valid(gripped):
		_let_go(0.0, "lost")
		return false
	_track_anchor(dt)
	var told := _body_shake()
	shake_amt = clampf(told if told >= 0.0 else shake_level / shake_hi, 0.0, 1.0)
	match state:
		GRAB, HOLD:
			_hold(dt, held)
		UP, STAND:
			_climb_up(dt)
		FAIL:
			_advance(dt)
			if _t >= _len(_clip) - 1e-3:
				_let_go(1.6, "stamina", _throw())
				_need_press = true
				return false
	if state == OFF:
		return false
	_blend.show_clip(_full(_clip), _t, _fade(_prev, _clip))
	_blend.update(dt)
	_place()
	_feed_legs(dt)
	_feed_gear()
	return true


# Climbing gear (user 2026-09-29: "stakes have 3 levels wood has less grip stamina stone more and iron the best, we
# can add grip claw feet stakes to allow hanging without using a lot of stamina", "bone stakes as well"): the loadout's
# climbing_stakes_* (data/loadout/loadout_items.json: climb.drain_mult, wood 0.85, bone 0.75, stone 0.65, iron 0.5) ride
# on the belt or sash behind the left hip and come into the hands while gripping, points into the surface; the
# climbing_claws_* (climb.hang_drain_mult: wood 0.6, bone 0.5, stone 0.42, iron 0.35) are strapped under the feet while
# gripping (user: "make it out of wood bone stone and iron", "have a leather strap").
# --------------------------------------------------------------------------------------------------

var _gear_on := false
var _gear_kind := ""             ## the stakes' kind the hand copies were built for
var _gear_nodes := {}            ## "l" / "r": a stake in that hand; "lf" / "rf": a claw under that foot
var _gear_stowed := ""           ## the stakes' item id whose belt copy is hidden
var _gear_n := Vector3.UP        ## the gripped surface's normal the stakes point into
var _claw_off := {}              ## "l" / "r": a claw in its ball bone's frame (from the rest pose)


## The loadout item id of the climbing stakes carried ("" = none).
func stakes_item() -> String:
	var lo: Loadout = player.get("loadout")
	if lo == null:
		return ""
	for it: Dictionary in lo.items:
		if String(it.kind).begins_with("climbing_stakes_"):
			return String(it.id)
	return ""


## The stakes' tier factor on the whole grip drain (1 without stakes).
func stakes_drain_mult() -> float:
	var id := stakes_item()
	if id == "":
		return 1.0
	var k := String((player.loadout as Loadout).item(id).kind)
	return float(LoadoutData.get_default().kind(k).get("climb", {}).get("drain_mult", 1.0))


## The kind of the climbing claws carried ("" = none).
func claws_kind() -> String:
	var lo: Loadout = player.get("loadout")
	if lo == null:
		return ""
	for it: Dictionary in lo.items:
		if String(it.kind).begins_with("climbing_claws_"):
			return String(it.kind)
	return ""


func has_claws() -> bool:
	return claws_kind() != ""


## The claws' tier factor on the drain of holding still (1 without claws).
func claws_hang_mult() -> float:
	var k := claws_kind()
	if k == "":
		return 1.0
	return float(LoadoutData.get_default().kind(k).get("climb", {}).get("hang_drain_mult", 1.0))


## Shows the gear while holding on (stakes in the hands and their belt copy hidden, claws under the feet) and puts it
## away otherwise.
func _feed_gear() -> void:
	var on := (state == GRAB or state == HOLD or state == FAIL) and is_instance_valid(anchor)
	var id := stakes_item()
	var kind := String((player.loadout as Loadout).item(id).kind) if id != "" else ""
	if kind != _gear_kind:
		for key in ["l", "r"]:
			if _gear_nodes.has(key):
				(_gear_nodes[key] as Node3D).queue_free()
				_gear_nodes.erase(key)
		_gear_kind = kind
	var gear_rig: SlingRig = player.get("gear")
	var hide_id := id if on else ""
	if hide_id != _gear_stowed and gear_rig:
		if _gear_stowed != "":
			gear_rig.hide_stowed(_gear_stowed, false)
		if hide_id != "":
			gear_rig.hide_stowed(hide_id, true)
		_gear_stowed = hide_id
	_gear_on = on
	var sk := player.skeleton
	_gear_n = anchor.global_basis.y if on else Vector3.UP
	for side in ["l", "r"]:
		var show := on and kind != ""
		var st: Node3D = _gear_nodes.get(side)
		if show and st == null:
			st = SlingModels.climbing_stake(kind.trim_prefix("climbing_stakes_"))
			st.top_level = true
			sk.add_child(st)
			_gear_nodes[side] = st
		if st != null:
			st.visible = show
		var key: String = side + "f"
		var ck := claws_kind()
		var claw := on and ck != ""
		var cl: Node3D = _gear_nodes.get(key)
		if cl != null and String(cl.get_meta("kind", "")) != ck:
			cl.queue_free()
			_gear_nodes.erase(key)
			cl = null
		if claw and cl == null:
			cl = SlingModels.climbing_claw(ck.trim_prefix("climbing_claws_"))
			cl.set_meta("kind", ck)
			cl.top_level = true
			sk.add_child(cl)
			_gear_nodes[key] = cl
		if cl != null:
			cl.visible = claw
	if on and not sk.skeleton_updated.is_connected(_place_gear):
		sk.skeleton_updated.connect(_place_gear)
	elif not on and sk.skeleton_updated.is_connected(_place_gear):
		sk.skeleton_updated.disconnect(_place_gear)
	if on:
		_place_gear()


## Puts the shown gear on the final pose (after the skeleton's modifiers: GripLegSway turns the legs, so a foot read
## before them is not where it is drawn).
func _place_gear() -> void:
	var sk := player.skeleton
	var n := _gear_n
	for side in ["l", "r"]:
		var st: Node3D = _gear_nodes.get(side)
		if st != null and st.visible:
			# held like a dagger, point out of the bottom of the fist into the surface at about 33 deg below its normal
			# plane's horizontal: the grip, the guard and the start of the spike stay in sight, the rest is in the
			# surface (the hands are on it; model: -Z = point, grip at z +0.068)
			var palm := sk.to_global(sk.get_bone_global_pose(sk.find_bone(side + "_palm")).origin) + n * 0.03
			var z := -(-n * 0.55 + Vector3.DOWN * 0.83).normalized()
			var y := (n - z * n.dot(z)).normalized()
			if y.length_squared() < 0.5:
				y = Vector3.UP
			var b := Basis(y.cross(z).normalized(), y, z).orthonormalized()
			st.global_transform = Transform3D(b, palm - b.z * 0.068)
		var cl: Node3D = _gear_nodes.get(side + "f")
		if cl != null and cl.visible:
			# on the sole under the forefoot, riding the ankle bone (the forefoot's skin follows it; the grip clips roll
			# the ball bone on its own): where that sole is in the rest pose (the character stands on y = 0, the toes to
			# +Z), carried by the bone's pose
			var bi := sk.find_bone(side + "_ankle")
			if not _claw_off.has(side):
				var r := sk.get_bone_global_rest(bi)
				var ball := sk.get_bone_global_rest(sk.find_bone(side + "_ball")).origin
				var at := Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3(ball.x, 0.0, ball.z - 0.035))
				_claw_off[side] = r.affine_inverse() * at
			cl.global_transform = sk.global_transform * sk.get_bone_global_pose(bi) * (_claw_off[side] as Transform3D)


## The legs' sway: the surface under them and how hard it shakes; faded out for the pull-up and standing (their clips
## stand on their own feet).
func _feed_legs(dt: float) -> void:
	var on := state == GRAB or state == HOLD or state == FAIL
	legs.active = true
	legs.shake = shake_amt if on else 0.0
	legs.plane_on = on and is_instance_valid(anchor)
	if legs.plane_on:
		legs.plane_point = anchor.global_position
		legs.plane_normal = anchor.global_basis.y
	legs.leg_amount = move_toward(legs.leg_amount, crawl_leg_amount if _moving != "" else 1.0, dt / 0.25)
	legs.influence = move_toward(legs.influence, 1.0 if on else 0.0, dt / 0.3)


## The leaves and limbs between the camera and the climber, and on along the aim, fade out while climbing or crouched
## on a branch (veg_clear_*, shaders/vegetation/near_fade.gdshaderinc): a clear view and a clear shot from a tree.
## In a tree (its bark gripped, or perched) the crown round the climber fades too (crown_clear_m), for the ground.
func _line_of_sight(delta: float) -> void:
	var on := (state != OFF or perched) and player.camera != null
	var w := move_toward(_clear_w, 1.0 if on else 0.0, delta / 0.35)
	if w <= 0.0 and _clear_w <= 0.0:
		return
	_clear_w = w
	var cam := player.camera.global_position
	var head := player.global_position + Vector3.UP * 1.45
	var aim := player.weapon != null and player.weapon.aim > 0.3 and (perched or hang_aim)
	var far := head + (-player.camera.global_basis.z) * (9.0 if aim else 1.2)
	if perched or (gripped != null and gripped.is_in_group(&"trees")):
		_crown_r = crown_clear_m
	elif on:
		_crown_r = 0.0
	var mid := player.global_position + Vector3.UP * 1.0
	RenderingServer.global_shader_parameter_set(&"veg_clear_a", Vector4(cam.x, cam.y, cam.z, 1.1))
	RenderingServer.global_shader_parameter_set(&"veg_clear_b", Vector4(far.x, far.y, far.z, _clear_w))
	RenderingServer.global_shader_parameter_set(&"veg_clear_c", Vector4(mid.x, mid.y, mid.z, _crown_r))


## The branch's camera and the body's fade (see perch_cam_distance).
func _perch_camera(delta: float) -> void:
	if player.spring_arm == null or player.riding != null:
		return
	var aiming := (perched or hang_aim) and player.weapon != null and player.weapon.aim > 0.3
	_cam_w = move_toward(_cam_w, 1.0 if perched else 0.0, delta / 0.5)
	_aim_w = move_toward(_aim_w, 1.0 if aiming else 0.0, delta / 0.25)
	if _cam_w > 0.0 or _aim_w > 0.0 or player.spring_arm.spring_length != player.camera_distance:
		var base := lerpf(player.camera_distance, perch_cam_distance, _cam_w)
		player.spring_arm.spring_length = lerpf(base, perch_aim_distance, _aim_w)
		var sh := lerpf(player.shoulder_offset, perch_shoulder, _cam_w)
		player.spring_arm.position.x = lerpf(sh, perch_aim_shoulder, _aim_w)
	# the body out of the way of the view
	var cam_d := player.camera.global_position.distance_to(player.global_position + Vector3.UP * 1.3)
	var target := maxf(aim_fade * _aim_w, (1.0 - smoothstep(near_fade_m.x, near_fade_m.y, cam_d)) * 0.85)
	var f := move_toward(_body_fade, target, delta / 0.2)
	if f == _body_fade and f <= 0.0:
		return
	_body_fade = f
	_fade_scan -= delta
	if _fade_scan <= 0.0 or _fade_meshes.is_empty():
		_fade_scan = 1.0
		_fade_meshes = player.find_children("*", "GeometryInstance3D", true, false)
	for m in _fade_meshes:
		if is_instance_valid(m):
			(m as GeometryInstance3D).transparency = _body_fade


func _can_grab() -> bool:
	return player.kneeling == null and player.riding == null and player.climbing == null \
			and not (player.traversal and player.traversal.showing) and not player.is_dead


func _process(delta: float) -> void:
	_line_of_sight(delta)
	_perch_camera(delta)
	if state != OFF:
		_place()                # after the bodies' physics this frame: no lag behind a moving giant
	else:
		if legs.active:
			legs.plane_on = false
			legs.shake = 0.0
			legs.influence = move_toward(legs.influence, 0.0, delta / 0.25)
			if legs.influence <= 0.0:
				legs.active = false
	if state == OFF and _ret_t >= 0.0:
		_ret_t += delta
		var u := smoothstep(0.0, 1.0, _ret_t / RETURN_S)
		if u >= 1.0:
			_rig.transform = _rig_local
			_ret_t = -1.0
		else:
			var to := player.visual.global_transform * _rig_local
			_rig.global_transform = _ret_from.interpolate_with(to, u)


# --------------------------------------------------------------------------------------------------
# Grabbing and letting go
# --------------------------------------------------------------------------------------------------

func _try_grab() -> bool:
	var up := Vector3.UP
	var base := player.global_position
	var fwd := -player.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 1e-4 else Vector3.FORWARD
	var dirs: Array[Vector3] = [fwd, fwd.rotated(up, 0.55), fwd.rotated(up, -0.55)]
	var air := not player.is_on_floor()
	if air:
		for k in 5:
			dirs.append(fwd.rotated(up, PI * 0.4 * float(k + 1) + 0.3))
	var best := {}
	var best_d := INF
	for h: float in [1.25, 0.85, 1.6, 2.0]:
		for d in dirs:
			var from := base + up * h
			var hit := _ray(from, from + d * reach)
			if hit.is_empty() or not GripSurface.is_grip(hit.collider) or (hit.normal as Vector3).y > 0.8:
				continue
			var dd := from.distance_to(hit.position)
			if dd < best_d:
				best_d = dd
				best = hit
	if not best.is_empty():
		var n: Vector3 = best.normal
		var pelvis := base + up * BODY_BELOW_PELVIS
		var g := pelvis - n * (pelvis - (best.position as Vector3)).dot(n)
		var at := _ray(g + n * 0.45, g - n * 0.6)
		if at.is_empty() or not GripSurface.is_grip(at.collider):
			at = best
		return _begin(at.collider, at.position, at.normal, fwd, "hang")
	if not air:
		var under := _ray(base + up * 0.5, base - up * 0.4)
		if not under.is_empty() and GripSurface.is_grip(under.collider):
			return _begin(under.collider, under.position, under.normal, fwd, "grip_start")
	return false


func _begin(col: Object, point: Vector3, n: Vector3, fwd: Vector3, clip: String) -> bool:
	var from := player.skeleton.global_transform
	if player.begin_climb(self) == null:
		return false
	_latched = true
	gripped = col as CollisionObject3D
	kind = GripSurface.kind_of(col)
	anchor = Node3D.new()
	anchor.name = "GripAnchor"
	GripSurface.parent_for(gripped, point).add_child(anchor)
	_set_frame(point, n, fwd)
	_have_prev = false
	_swing = Vector2.ZERO
	_swing_v = Vector2.ZERO
	_float = ""
	_react = ""
	_moving = ""
	_hang_idle = n.y < cos(deg_to_rad(hang_idle_deg))
	_ret_t = -1.0
	legs.reset()
	_perch_up = false
	if _blend == null or not is_instance_valid(_blend.tree):
		_blend = HorsePhaseBlender.new(_ap, player, "")
	_blend.tree.active = true
	_prev = ""
	_clip = clip
	_t = 0.0
	_blend.show_clip(_full(clip), 0.0, 0.0)
	_blend.update(0.0)
	_start_catch(from)
	state = GRAB
	player.velocity = Vector3.ZERO
	grabbed.emit(kind)
	return true


## Off the surface: the player's body where the climber is, moving as the surface moved plus `push` off it.
func _let_go(push: float, reason: String, extra := Vector3.ZERO) -> void:
	if state == OFF:
		return
	var pel := _rig.global_transform * _sk_in_rig * PELVIS
	var n := anchor.global_basis.y if is_instance_valid(anchor) else Vector3.UP
	_end_grip()
	player.global_position = pel - Vector3.UP * BODY_BELOW_PELVIS
	player.velocity = _avel + n * push + extra
	if player.velocity.y > 0.5:
		# (the body's floor state is from before the grip: one free step clears it, or the ground stop would eat the
		# throw on the first tick)
		player.move_and_slide()
	_cool = 0.45
	released.emit(reason)


## Where the grip giving out sends the climber: off a moving body, thrown clear of it (up and off the side it tilts
## toward, so the fall ends on the ground, not back on its back); off still rock, just away from the face.
func _throw() -> Vector3:
	if not is_instance_valid(anchor) or not is_instance_valid(gripped):
		return Vector3.ZERO
	if _avel.length() < 0.3 and shake_level < 2.0:
		return Vector3.ZERO
	# off the side the surface tilts toward (a roll throws you downhill), else away from the body's middle
	var out := anchor.global_basis.y
	out.y = 0.0
	if out.length_squared() < 0.0025:
		out = anchor.global_position - (gripped as Node3D).global_position
		out.y = 0.0
	out = out.normalized() if out.length_squared() > 1e-4 else Vector3.FORWARD
	# (the body's own swing is in the surface's velocity: the throw's sideways speed is capped)
	var h := _avel + out * throw_out
	h.y = 0.0
	h = h.limit_length(throw_out + 1.0)
	return Vector3.UP * throw_up + h - Vector3(_avel.x, 0.0, _avel.z)


## Standing on a top: the player's body on the anchor, moving with it.
func _stand_done() -> void:
	var at := anchor.global_position
	var v := _avel
	_end_grip()
	player.global_position = at + Vector3.UP * 0.02
	player.velocity = v
	_cool = 0.3
	_need_press = true
	released.emit("stand")


func _end_grip() -> void:
	_latched = false
	_end_hang_aim()
	_ret_from = _rig.global_transform
	_ret_t = 0.0
	state = OFF
	_moving = ""
	if _blend and is_instance_valid(_blend.tree):
		_blend.tree.active = false
	player.end_climb(0.35)
	if is_instance_valid(anchor):
		anchor.queue_free()
	anchor = null
	gripped = null
	_up = {}


# --------------------------------------------------------------------------------------------------
# Holding on: crawling, the swing, the shaken clips, stamina
# --------------------------------------------------------------------------------------------------

func _hold(dt: float, held: bool) -> void:
	var n := anchor.global_basis.y
	var slope := rad_to_deg(acos(clampf(n.y, -1.0, 1.0)))
	if _hang_idle and slope < hang_idle_deg - 10.0:
		_hang_idle = false
	elif not _hang_idle and slope > hang_idle_deg:
		_hang_idle = true
	_pendulum(dt)
	# stamina (the climbing claws ease holding still; the stakes' tier eases all of it: climb_gear_mult)
	var drain := drain_hold + drain_steep * clampf((slope - 45.0) / 45.0, 0.0, 1.0)
	if _moving == "":
		drain *= claws_hang_mult()
	if _moving != "":
		drain += drain_move
	if _float == "md":
		drain += drain_float_md
	elif _float == "hi":
		drain += drain_float_hi
	drain += drain_swing * _swing_v.length() + drain_jolt * _jolt.length() + drain_shaken * shake_amt
	if hang_aim:
		drain += drain_one_hand
	stamina = maxf(stamina - drain * drain_mult * stakes_drain_mult() * dt, 0.0)
	if stamina <= 0.0:
		_end_hang_aim()
		state = FAIL
		_moving = ""
		_play("grip_fail1")
		return
	if not held:
		if slope < stand_up_max_deg and _float == "":
			_start_stand(false)
		else:
			_let_go(0.8, "let_go")
		return
	_advance(dt)
	if state == GRAB:
		if _t >= _len(_clip) - 1e-3:
			state = HOLD
			_play(_idle_clip())
		return
	if hang_aim or (_moving == "" and _float == "" and player.controls.pressed(&"aim") and _hang_weapon() != ""):
		_hang_aim_step(dt)
		return
	if _shaken(dt):
		return
	var want := player.controls.move_vector()
	var d := _input_dir(Vector2(want.x, -want.y))
	if _moving != "":
		_crawl(dt)
		if state != HOLD:
			return
		if _t >= _len(_clip) - 1e-3:
			var nxt := _move_clip(d, dt)
			if nxt == "":
				_moving = ""
				_play(_idle_clip())
			else:
				_start_move(nxt)
	else:
		var nxt := _move_clip(d, dt)
		if nxt != "":
			_start_move(nxt)
		elif _clip != _idle_clip() and _react == "":
			_play(_idle_clip())


## The weapon in the loadout's hand that works one-handed from a grip ("" none).
func _hang_weapon() -> String:
	var k := player.weapon_key
	if k in HANG_WEAPONS and player.weapon != null and player.is_usable(k):
		return k
	return ""


## Hanging one-handed with a pistol, a tomahawk or a spear: the weapon's own aim, fire and throw (it reads the mouse as
## on foot), the right arm on the crosshair (GripAimArm), no crawling; RMB let go (and the throw done) hangs by both
## hands again, the weapon back on the body.
func _hang_aim_step(dt: float) -> void:
	var w := player.weapon
	if not hang_aim:
		hang_aim = true
		player.hands_free = false
		player.anim.hands_free = false
		w.equip_quick(0.3)
		if w is Throwable:
			_anim_release = (w as Throwable).wait_for_anim_release
			(w as Throwable).wait_for_anim_release = false
		aim_arm.active = true
		_play("hang_atk_start", 0.12)
	# in front of the climber only
	var face := -anchor.global_basis.y
	face.y = 0.0
	if face.length_squared() > 0.01:
		face = face.normalized()
		var look := Vector3(-sin(player.yaw), 0.0, -cos(player.yaw))
		var ang := face.signed_angle_to(look, Vector3.UP)
		if absf(ang) > HANG_AIM_YAW:
			var f := face.rotated(Vector3.UP, clampf(ang, -HANG_AIM_YAW, HANG_AIM_YAW))
			player.yaw = lerp_angle(player.yaw, atan2(-f.x, -f.z), 1.0 - exp(-14.0 * dt))
	w.tick(dt)
	player.camera.fov = lerpf(player.camera.fov, player.fov * w.fov_mult(), 1.0 - exp(-10.0 * dt))
	aim_arm.target = player.get_aim_point()
	aim_arm.muzzle = w.muzzle
	aim_arm.cock = 0.0
	var arm := clampf(w.aim * 1.4, 0.0, 1.0) if not w.is_equipping() else 0.0
	if w is Throwable:
		# the throw is the clips' own arm: drawn back while winding up and holding, the strike on the release
		arm = 0.0
		var st := (w as Throwable).state
		var ended := _t >= _len(_clip) - 1e-3
		if st == Throwable.State.WINDUP or st == Throwable.State.HOLDING:
			if _clip == "hang_atk_start" and ended or _clip == "hang_atk_a":
				_play("hang_atk_tame_a", 0.08)
			elif _clip == "hang_atk_tame_a" and ended:
				_play("hang_atk_tame_loop", 0.06)
		elif st == Throwable.State.RELEASING:
			if _clip == "hang_atk_tame_loop" or _clip == "hang_atk_tame_a" or _clip == "hang_atk_start":
				_play("hang_atk_drop", 0.04)
			elif _clip == "hang_atk_drop" and ended:
				_play("hang_atk_a", 0.03)
		elif _clip == "hang_atk_a" and ended or _clip.begins_with("hang_atk_tame"):
			_play("hang_atk_start", 0.2)
	_arm_w = move_toward(_arm_w, arm, dt / 0.2)
	aim_arm.influence = _arm_w
	var busy := w.is_busy() or (w is Throwable and (w as Throwable).state in [Throwable.State.RELEASING, Throwable.State.RECOVER])
	if not player.controls.pressed(&"aim") and w.aim <= 0.05 and not busy:
		_end_hang_aim()
		_play(_idle_clip(), 0.3)


func _end_hang_aim() -> void:
	if not hang_aim:
		return
	hang_aim = false
	var w := player.weapon
	if w != null:
		if w is Throwable:
			(w as Throwable).wait_for_anim_release = _anim_release
		if w.active:
			w.unequip()
	player.hands_free = true
	player.anim.hands_free = true
	player.camera.fov = player.fov
	_arm_w = 0.0
	aim_arm.influence = 0.0
	aim_arm.active = false
	aim_arm.cock = 0.0


func _idle_clip() -> String:
	return "hang_loop" if _hang_idle else "grip_loop"


## The stick on the surface (world, tangent): on a steep part up is up the slope and the sides are along it; on a
## gentle part it goes the way the camera looks. ZERO when the stick is centred.
func _input_dir(want: Vector2) -> Vector3:
	if want.length() < 0.3:
		return Vector3.ZERO
	var b := anchor.global_basis
	var n := b.y
	var fin: Vector3
	if n.y < 0.7:
		fin = _up_slope(n)
	else:
		var cam := -player.camera.global_basis.z
		fin = cam - n * cam.dot(n)
		fin = fin.normalized() if fin.length_squared() > 1e-4 else b.z
	var d := fin * want.y + fin.cross(n) * want.x
	return d.normalized() if d.length_squared() > 1e-6 else Vector3.ZERO


## The crawl clip for a way over the surface: forward / back along the body, or to its sides (the body's left is +X).
## On a gentle part the body turns toward it instead (up to turn_rate) and crawls forward.
func _move_clip(d: Vector3, dt: float) -> String:
	if d == Vector3.ZERO:
		return ""
	var b := anchor.global_basis
	if b.y.y >= 0.7:
		var ang := b.z.signed_angle_to(d, b.y)
		if absf(ang) < 2.4:
			_turn(clampf(ang, -turn_rate * dt, turn_rate * dt))
			return _f_next
	var lz := d.dot(b.z)
	var lx := d.dot(b.x)
	if absf(lz) >= absf(lx):
		return _f_next if lz > 0.0 else "grip_move_b"
	return "grip_move_l" if lx > 0.0 else "grip_move_r"


func _start_move(clip: String) -> void:
	_moving = clip
	if clip == "grip_move_f1":
		_f_next = "grip_move_f2"
	elif clip == "grip_move_f2":
		_f_next = "grip_move_f1"
	if clip == _clip:
		_t = 0.0                # the cycle again (its end pose is its start pose)
	else:
		_play(clip)
	_travel_last = Vector3.ZERO


## The body goes as far as the clip's planted hands and feet this tick.
func _crawl(_dt: float) -> void:
	var tr := _travel(_clip, _t)
	var dl := tr - _travel_last
	_travel_last = tr
	var b := anchor.global_basis
	var dw := b.x * dl.x + b.z * dl.z
	if dw.length_squared() < 1e-10:
		return
	var r := _move_on_surface(dw, _clip_way(b))
	if r == "edge" or (r == "crown" and not _start_perch()):
		_moving = ""
		_play(_idle_clip())
	elif r == "top":
		_start_climb_up()
	elif r == "drop":
		_let_go(0.3, "let_go")


## The way the crawl clip playing goes (world): forward, back or to a side of the body. The lead is checked that way
## (the clip's own step wobbles sideways from tick to tick).
func _clip_way(b: Basis) -> Vector3:
	match _moving:
		"grip_move_b":
			return -b.z
		"grip_move_l":
			return b.x
		"grip_move_r":
			return -b.x
	return b.z


## Moves the anchor over the surface by `dw` (the crawl going `way`): "ok", "edge" (nothing to hold there), "top" (a
## flat top to climb onto, in _up), "drop" (the ground just below: let go).
func _move_on_surface(dw: Vector3, way := Vector3.ZERO) -> String:
	var A := anchor.global_transform.orthonormalized()
	var n := A.basis.y
	var F := A.basis.z
	var dist := dw.length()
	var dir := dw / dist
	var c := A.origin + dw
	if way != Vector3.ZERO:
		dir = way.normalized()
	# climbing down near the ground: let go (the trunks' and the rocks' colliders go on into the ground)
	if dir.y < -0.5:
		var foot := _ray(c + n * 0.35, c + n * 0.35 + Vector3.DOWN * 1.0)
		if not foot.is_empty() and not GripSurface.is_grip(foot.collider):
			return "drop"
	# the lead: where the hands (going forward), the feet (back) or the side reach next
	var fwd := dir.dot(F)
	var lead := 0.3
	if fwd > 0.7:
		lead = HANDS_AHEAD
	elif fwd < -0.7:
		lead = 0.45
	# something grippable in the way along the surface (an inside corner)
	var hc := _ray(A.origin + n * 0.25, A.origin + n * 0.25 + dir * (dist + 0.3))
	if not hc.is_empty() and GripSurface.is_grip(hc.collider) and (hc.normal as Vector3).dot(n) < 0.9:
		_rehome(hc.collider, hc.position, hc.normal)
		return "ok"
	var L := c + dir * lead
	var hl := _ray(L + n * 0.45, L - n * 0.6)
	if hl.is_empty() or not GripSurface.is_grip(hl.collider):
		# round an outside corner, or onto a top
		var hw := _ray(L + dir * 0.45 - n * 0.35, L - dir * 0.45 - n * 0.35)
		if not hw.is_empty():
			var hn: Vector3 = hw.normal
			# (a tree's trunk ends where its crown starts: no standing on it, the climber stays up there)
			var crown := GripSurface.kind_of(hw.collider) == "bark" and hn.y > 0.75
			if hn.y > 0.75 and dir.y > 0.25 and not crown and _room_above(hw.position):
				_up = {"col": hw.collider, "point": hw.position, "n": hn, "dir": dir}
				return "top"
			if GripSurface.is_grip(hw.collider) and hn.dot(n) < 0.95 and not crown:
				_rehome(hw.collider, hw.position, hn)
				return "ok"
			if crown and dir.y > 0.25:
				return "crown"
		if dir.y < -0.5:
			var below := _ray(c, c + Vector3.DOWN * 1.9)
			if not below.is_empty() and not GripSurface.is_grip(below.collider):
				return "drop"
		# round a curved surface (a trunk): the lead is off it but the body's own spot is still on it
		if fwd <= 0.7:
			var hc2 := _ray(c + n * 0.45, c - n * 0.6)
			if not hc2.is_empty() and GripSurface.is_grip(hc2.collider) and (hc2.normal as Vector3).dot(n) > 0.6:
				if hc2.collider != gripped:
					_reparent(hc2.collider, hc2.position)
				_set_frame(hc2.position, hc2.normal, F)
				return "ok"
		return "edge"
	var h := _ray(c + n * 0.45, c - n * 0.6)
	if h.is_empty() or not GripSurface.is_grip(h.collider):
		return "edge"
	if h.collider != gripped:
		_reparent(h.collider, h.position)
	_set_frame(h.position, h.normal, F)
	return "ok"


## Onto another face (round a corner): the skeleton eases over from where it is.
func _rehome(col: Object, point: Vector3, n: Vector3) -> void:
	var from := _rig.global_transform * _sk_in_rig
	if col != gripped:
		_reparent(col, point)
	_set_frame(point, n, anchor.global_basis.z)
	_start_catch(from)


func _reparent(col: Object, point: Vector3) -> void:
	gripped = col as CollisionObject3D
	kind = GripSurface.kind_of(col)
	anchor.reparent(GripSurface.parent_for(gripped, point), true)


## The anchor at `point` with the surface frame for normal `n`: forward along `fwd` on a gentle part, up the slope on a
## steep one.
func _set_frame(point: Vector3, n: Vector3, fwd: Vector3) -> void:
	n = n.normalized()
	var f := fwd - n * fwd.dot(n)
	if f.length_squared() < 1e-6:
		f = _up_slope(n)
	f = f.normalized()
	var us := _up_slope(n)
	var steep := smoothstep(0.87, 0.64, n.y)
	if steep > 0.0 and us.length_squared() > 0.5:
		f = f.slerp(us, steep).normalized() if f.dot(us) > -0.99 else us
	var x := n.cross(f).normalized()
	f = x.cross(n).normalized()
	anchor.global_transform = Transform3D(Basis(x, n, f), point)


func _turn(a: float) -> void:
	var b := anchor.global_basis
	var f := b.z.rotated(b.y, a)
	_set_frame(anchor.global_position, b.y, f)


## Up the slope along a surface of normal n (any tangent when it is flat).
static func _up_slope(n: Vector3) -> Vector3:
	var u := Vector3.UP - n * n.y
	if u.length_squared() < 1e-4:
		u = Vector3.FORWARD - n * n.z
	return u.normalized()


func _room_above(p: Vector3) -> bool:
	return _ray(p + Vector3.UP * 0.1, p + Vector3.UP * 1.7).is_empty()


## How the surface moves under the hands: the velocity and acceleration (world) of the point the anchor holds, as the
## gripped body carries it (the climber's own crawling is not in it), and that acceleration in the frame.
func _track_anchor(dt: float) -> void:
	var par := anchor.get_parent() as Node3D
	var now := par.global_transform
	var held_at := anchor.position
	if not _have_prev or dt <= 0.0 or par != _par_last:
		_par_last = par
		_par_xf = now
		_avel = Vector3.ZERO
		_aacc = Vector3.ZERO
		_have_prev = true
		return
	var v := (now * held_at - _par_xf * held_at) / dt
	var a := (v - _avel) / dt
	_aacc = _aacc.lerp(a, 1.0 - exp(-25.0 * dt))
	_avel = v
	_par_xf = now
	var b := anchor.global_basis
	_jolt = Vector3(_aacc.dot(b.x), _aacc.dot(b.y), _aacc.dot(b.z))
	shake_level = lerpf(shake_level, _jolt.length(), 1.0 - exp(-4.0 * dt))


## The body hangs from the hands: gravity and the surface's acceleration swing it, the climber pulls back in, and it
## cannot swing into the surface.
func _pendulum(dt: float) -> void:
	var b := anchor.global_basis
	var ge := Vector3.DOWN * 9.8 - _aacc
	var gl := Vector3(ge.dot(b.x), ge.dot(b.y), ge.dot(b.z))
	var th := _swing.x
	var ph := _swing.y
	var d_th := Vector3(-cos(ph) * cos(th), 0.0, cos(ph) * sin(th))
	var d_ph := Vector3(sin(ph) * sin(th), cos(ph), sin(ph) * cos(th))
	var acc := Vector2(gl.dot(d_th), gl.dot(d_ph)) / swing_len
	var rest := float_lift_hi if _float == "hi" else (float_lift_md if _float == "md" else 0.0)
	var slack := lerpf(1.0, shaken_stiff, shake_amt)
	var ks := swing_k_side * lerpf(gentle_side_stiff, 1.0, smoothstep(0.85, 0.5, b.y.y)) * slack
	acc -= Vector2(ks * th, swing_k_lift * slack * (ph - rest)) + _swing_v * swing_damp
	# (on a gentle part gravity presses the body onto the surface: that does not swing it)
	_swing_v += acc * dt
	_swing += _swing_v * dt
	_swing.x = clampf(_swing.x, -1.1, 1.1)
	if _swing.y < 0.0:
		_swing.y = 0.0
		_swing_v.y = maxf(_swing_v.y, 0.0) * 0.3
	elif _swing.y > 1.3:
		_swing.y = 1.3
		_swing_v.y = minf(_swing_v.y, 0.0)


## How hard the gripped body says it shakes (0..1), or -1 when it does not say (then the measured shaking decides).
func _body_shake() -> float:
	var n: Node = gripped
	for i in 4:
		if n == null:
			break
		if n.has_method(&"grip_shake"):
			return float(n.call(&"grip_shake"))
		n = n.get_parent()
	return -1.0


## The shaken clips: true while one plays (no crawling meanwhile).
func _shaken(dt: float) -> bool:
	_react_cool = maxf(_react_cool - dt, 0.0)
	var lift := _swing.y
	var told := _body_shake()
	var md := told > body_shake_md if told >= 0.0 else shake_level > shake_md
	var hi := told > body_shake_hi and shake_level > shake_md if told >= 0.0 else shake_level > shake_hi
	var calm := told < body_shake_calm if told >= 0.0 else shake_level < shake_calm
	# flung off the surface: a big shake (or the body swung far off it)
	if flail_clips and _float == "" and (md or lift > lift_md):
		_float = "md"
		_moving = ""
		_react = ""
		_float_low_t = 0.0
		_play("grip_float_u_md_start")
		return true
	if _float != "":
		if _float == "md" and (hi or lift > lift_hi):
			_float = "hi"
			_play("grip_float_u_hi_start")
			return true
		_float_low_t = _float_low_t + dt if calm and lift < lift_md else 0.0
		var loop := "grip_float_u_%s_loop" % _float
		var start := "grip_float_u_%s_start" % _float
		var end := "grip_float_u_%s_end" % _float
		if _clip == start and _t >= _len(_clip) - 1e-3:
			_play(loop)
		elif _clip == loop and _float_low_t > 0.3:
			_play(end)
		elif _clip == end and _t >= _len(_clip) - 1e-3:
			_float = ""
			_play(_idle_clip())
			return false
		return true
	# a big sideways swing
	if flail_clips and _react == "" and absf(_swing.x) > side_hi and _react_cool <= 0.0:
		_react = "grip_float_l_hi" if _swing.x > 0.0 else "grip_float_r_hi"
		_moving = ""
		_play(_react)
		return true
	# a lurch of the surface (not while crawling)
	if _react == "" and _moving == "" and _jolt.length() > jolt_lo and _react_cool <= 0.0:
		var j := _jolt
		var ax := [absf(j.x), absf(j.y), absf(j.z)]
		var dir := ""
		if ax[0] >= ax[1] and ax[0] >= ax[2]:
			dir = "l" if j.x > 0.0 else "r"
		elif ax[1] >= ax[2]:
			dir = "u" if j.y > 0.0 else "d"
		else:
			dir = "f" if j.z > 0.0 else "b"
		_react = "grip2_float_%s_lo" % dir
		_play(_react)
		return true
	if _react != "":
		if _t >= _len(_clip) - 1e-3:
			_react = ""
			_react_cool = 0.25
			_play(_idle_clip())
			return false
		return true
	return false


# --------------------------------------------------------------------------------------------------
# Sitting on a branch at the top of a trunk (user 2026-09-27: "allow the ability to sit on branchs to regain stamina")
# --------------------------------------------------------------------------------------------------

## At a trunk's top: pulled up onto its branch (PerchBranches; the pull-up, hang_up), crouched across it, turned the
## least from the way the climber faced. False when the tree has no branch (a thin trunk).
func _start_perch() -> bool:
	if perch == null:
		return false
	var pr := perch.perch_at(anchor.global_position)
	if pr.is_empty():
		return false
	_perch_from = {"col": gripped, "point": anchor.global_position, "n": anchor.global_basis.y}
	var side: Vector3 = pr.side
	var face := -anchor.global_basis.y
	face.y = 0.0
	_perch_face = side if side.dot(face) >= 0.0 else -side
	_perch_dir = pr.dir
	_perch_up = true
	_up = {"col": pr.floor, "point": pr.seat, "n": Vector3.UP, "dir": Vector3.UP, "face": _perch_face}
	_start_climb_up()
	return true


## Up on the branch: the player's own body, crouched, standing on the branch's floor; the weapons are theirs again.
func _perch_done() -> void:
	var at := anchor.global_position
	_end_grip()
	player.global_position = at + Vector3.UP * 0.03
	player.velocity = Vector3.ZERO
	player.set_crouched(true)
	player.perch = self
	player.yaw = atan2(-_perch_face.x, -_perch_face.z)
	player.rotation.y = player.yaw
	perched = true
	_jump_hold = 0.0
	_off_t = 0.0
	_need_press = player.controls.pressed(&"grip")
	climbed_up.emit()


## Crouched on a branch (the player moves the body; the move keys do nothing there): the grip refills while not aiming;
## the camera stays on the open side; G again takes hold of the trunk; Space held jumps off. True when the grip took
## the body back.
func _perch_tick(dt: float) -> bool:
	if player.perch != self or player.is_dead:
		_unperch()
		return false
	var aiming := player.weapon != null and player.weapon.aim > 0.3
	if not aiming:
		stamina = move_toward(stamina, stamina_max, perch_regain * dt)
	# (not round into the trunk: the camera would be in it, the shots too)
	var look := Vector3(-sin(player.yaw), 0.0, -cos(player.yaw))
	var ang := _perch_dir.signed_angle_to(look, Vector3.UP)
	if absf(ang) > PERCH_YAW:
		var f := _perch_dir.rotated(Vector3.UP, clampf(ang, -PERCH_YAW, PERCH_YAW))
		player.yaw = atan2(-f.x, -f.z)
	if player.controls.just_pressed(&"grip"):
		return _leave_perch()
	_jump_hold = _jump_hold + dt if player.controls.pressed(&"jump") else 0.0
	if _jump_hold >= PERCH_JUMP_S:
		_unperch()
		player.set_crouched(false)
		player.velocity = _perch_dir * 2.4 + Vector3.UP * 3.0
		player.move_and_slide()
		released.emit("jump")
		return false
	_off_t = _off_t + dt if not player.is_on_floor() else 0.0
	if _off_t > 0.4:
		_unperch()
	return false


func _unperch() -> void:
	if player.perch == self:
		player.perch = null
	perched = false
	_jump_hold = 0.0


## Off the branch onto the trunk again, just under the crown where the climber came up.
func _leave_perch() -> bool:
	var col: Object = _perch_from.get("col")
	if col == null or not is_instance_valid(col):
		return false
	_unperch()
	var n: Vector3 = _perch_from.get("n", Vector3.FORWARD)
	var pt: Vector3 = (_perch_from.get("point", player.global_position) as Vector3) - Vector3.UP * 0.2
	return _begin(col, pt, n, Vector3.UP, "hang")


# --------------------------------------------------------------------------------------------------
# Onto a top: hang_up (the pull-up) and grip_end / grip_end_end (standing up)
# --------------------------------------------------------------------------------------------------

func _start_climb_up() -> void:
	var p: Dictionary = _up
	var shown := _rig.global_transform * _sk_in_rig
	var pel := shown * PELVIS
	var n_old := anchor.global_basis.y
	var ftop: Vector3 = -n_old
	ftop.y = 0.0
	ftop = ftop.normalized() if ftop.length_squared() > 1e-3 else anchor.global_basis.z
	var top: Vector3 = (p.point as Vector3) + ftop * 0.15
	if p.has("face"):
		ftop = p.face
		top = p.point
	if p.col != gripped:
		_reparent(p.col, top)
	_set_frame(top, p.n, ftop)
	var A := anchor.global_transform.orthonormalized()
	var ai := A.affine_inverse()
	_up = {"p0": ai * pel, "b0": ai.basis * shown.basis.orthonormalized(),
			"p1": Vector3(0.0, _standoff("hang_up", _len("hang_up")) + SKIN, 0.0)}
	_moving = ""
	_swing = Vector2.ZERO
	_swing_v = Vector2.ZERO
	_float = ""
	_react = ""
	_catch_t = -1.0
	state = UP
	_play("hang_up", 0.12)


## Standing up from gripping a gentle part (from_top: after the pull-up): the skeleton eases over from where it is.
func _start_stand(from_top: bool) -> void:
	if not from_top:
		_start_catch(_rig.global_transform * _sk_in_rig)
	_moving = ""
	_float = ""
	_react = ""
	_swing = Vector2.ZERO
	_swing_v = Vector2.ZERO
	state = STAND
	_play("grip_end", 0.15)


func _climb_up(dt: float) -> void:
	_advance(dt)
	if _t < _len(_clip) - 1e-3:
		return
	match _clip:
		"hang_up":
			if _perch_up:
				_perch_up = false
				_perch_done()
				return
			climbed_up.emit()
			_start_stand(true)
		"grip_end":
			_play("grip_end_end", MIN_FADE)
		"grip_end_end":
			_stand_done()


# --------------------------------------------------------------------------------------------------
# Clips and the placement
# --------------------------------------------------------------------------------------------------

func _play(clip: String, fade := -1.0) -> void:
	if clip == _clip and fade < 0.0:
		return
	_prev = _clip
	_prev_t = _t
	_prev_fade = fade if fade >= 0.0 else _fade(_clip, clip)
	_clip = clip
	_t = 0.0
	_blend.show_clip(_full(clip), 0.0, _prev_fade)


func _fade(a: String, b: String) -> float:
	if a == "" or a == b:
		return _prev_fade
	var k := a + ">" + b
	return maxf(float(fades[k]), MIN_FADE) if fades.has(k) else DEFAULT_FADE


func _advance(dt: float) -> void:
	_t += dt
	var L := _len(_clip)
	if _loops(_clip):
		_t = fposmod(_t, L)
	else:
		_t = minf(_t, L)
	if _prev != "":
		_prev_t = minf(_prev_t + dt, _len(_prev)) if not _loops(_prev) else fposmod(_prev_t + dt, _len(_prev))
	if _catch_t >= 0.0:
		_catch_t += dt
		if _catch_t >= _catch_s:
			_catch_t = -1.0


func _start_catch(from_skeleton: Transform3D, s := CATCH_S) -> void:
	_catch_from = anchor.global_transform.orthonormalized().affine_inverse() * from_skeleton
	_catch_t = 0.0
	_catch_s = s


## A clip's name on the AnimationPlayer: the Actor_C climbing clips by their short name, Actor_B's own by theirs.
func _full(c: String) -> String:
	return "actor_b/" + c if c.begins_with("actor_b-") else LIB + "/" + PRE + c


func _len(c: String) -> float:
	if clips.has(c):
		return float((clips[c] as Dictionary).get("length", 1.0))
	return _ap.get_animation(_full(c)).length if _ap.has_animation(_full(c)) else 1.0


func _loops(c: String) -> bool:
	if clips.has(c):
		return bool((clips[c] as Dictionary).get("loop", false))
	return _ap.has_animation(_full(c)) and _ap.get_animation(_full(c)).loop_mode != Animation.LOOP_NONE


func _is_h(c: String) -> bool:
	var f = (clips.get(c, {}) as Dictionary).get("frame", ["S"])
	return f is Array and (f as Array).size() > 0 and str(f[0]) == "H"


func _sample(c: String, key: String, t: float):
	var d: Dictionary = clips.get(c, {})
	var arr: Array = d.get(key, [])
	if arr.is_empty():
		return null
	var u := clampf(t / maxf(float(d.get("length", 1.0)), 1e-4), 0.0, 1.0) * float(arr.size() - 1)
	var i := mini(int(u), arr.size() - 2) if arr.size() > 1 else 0
	var f := u - float(i)
	var a = arr[i]
	var b = arr[mini(i + 1, arr.size() - 1)]
	if a is Array:
		var va := Vector3(float(a[0]), float(a[1]), float(a[2]))
		var vb := Vector3(float(b[0]), float(b[1]), float(b[2]))
		return va.lerp(vb, f)
	return lerpf(float(a), float(b), f)


func _standoff(c: String, t: float) -> float:
	var s = _sample(c, "standoff", t)
	return float(s) if s != null else 0.4


func _travel(c: String, t: float) -> Vector3:
	var s = _sample(c, "travel", t)
	return s if s is Vector3 else Vector3.ZERO


## The skeleton where the clip and the grip put it this frame; the rig and the player's body follow.
func _place() -> void:
	if not is_instance_valid(anchor):
		return
	var A := anchor.global_transform.orthonormalized()
	var w := _blend.active_weight() if _blend else 1.0
	var T: Transform3D
	if state == UP or state == STAND:
		T = _placement_up(A, w)
	else:
		var ba := A.basis * HROT if _is_h(_clip) else A.basis
		var bp := (A.basis * HROT if _is_h(_prev) else A.basis) if _prev != "" else ba
		var b := bp.slerp(ba, w) if w < 1.0 else ba
		var so := _standoff(_clip, _t)
		if _prev != "" and w < 1.0:
			so = lerpf(_standoff(_prev, _prev_t), so, w)
		var P := A.origin + A.basis.y * (so + SKIN)
		T = Transform3D(b, P - b * PELVIS)
		# the swing about the hands
		var K := A.origin + A.basis.z * HANDS_AHEAD
		var R := Basis(A.basis.y, _swing.x) * Basis(A.basis.x, _swing.y)
		T = Transform3D(R * T.basis, K + R * (T.origin - K))
	if _catch_t >= 0.0:
		var from := A * _catch_from
		T = from.interpolate_with(T, smoothstep(0.0, 1.0, _catch_t / _catch_s))
	var pel := T * PELVIS
	player.global_position = pel - Vector3.UP * BODY_BELOW_PELVIS
	_rig.global_transform = T * _sk_in_rig.affine_inverse()


## On a top: the pull-up from where the body hung (p0, b0 in the anchor's frame) to crouching on the top (p1), then
## standing up, turning upright (world up) as it rises.
func _placement_up(A: Transform3D, w: float) -> Transform3D:
	var upright := A.basis.inverse() * _upright_basis(A.basis)
	var p: Vector3
	var b: Basis
	if _clip == "hang_up":
		var u := clampf(_t / _len("hang_up"), 0.0, 1.0)
		var p0: Vector3 = _up.p0
		var p1: Vector3 = _up.p1
		var dv := p1.y - p0.y
		var dh := Vector3(p1.x - p0.x, 0.0, p1.z - p0.z)
		p = p0 + Vector3(0.0, dv * smoothstep(0.0, 0.75, u), 0.0) + dh * smoothstep(0.3, 1.0, u)
		b = (_up.b0 as Basis).slerp(Basis(), smoothstep(0.0, 0.8, u))
	else:
		var so := _standoff(_clip, _t)
		if _prev != "" and w < 1.0:
			so = lerpf(_standoff(_prev, _prev_t), so, w)
		var u2 := smoothstep(0.0, 1.0, _t / _len("grip_end")) if _clip == "grip_end" else 1.0
		b = Basis().slerp(upright, u2)
		p = b.y * (so + SKIN)
	return A * Transform3D(b, p - b * PELVIS)


## World up, facing along the frame's forward (levelled).
static func _upright_basis(fb: Basis) -> Basis:
	var f := fb.z
	f.y = 0.0
	if f.length_squared() < 1e-4:
		f = -fb.y
		f.y = 0.0
	f = f.normalized() if f.length_squared() > 1e-4 else Vector3.FORWARD
	var x := Vector3.UP.cross(f).normalized()
	return Basis(x, Vector3.UP, f)


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(q)
