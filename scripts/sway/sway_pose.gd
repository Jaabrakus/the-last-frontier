class_name SwayPose
extends Node
## The body of a Sway cast (the Sway v2; SwayCaster's child `pose`; docs/main_story.md 11.10, the owner's rules): every spell is
## cast with our own clips (animations_extra/Frontier_Form.res: tools/anim_author/blender/form_clips.py, install_form.gd), the
## clip by the caster's mastery of the spell (SwayCaster.tier; data/sway/moves.json mastery.clips):
##   untrained  the floor cast, for every spell (Gust too): the hands clap at the chest, the body sinks into a deep squat and the
##              palms press flat to the ground (own-form-clap-press, held at its end while the lock fills); the cast: the palms
##              push down and the body stands (own-form-release). A circle on an upright (mend on a wall): the palms onto it
##              (own-form-press-wall, held at hold_s; its shove on the cast)
##   practised  a two-handed standing push (own-sway-push-two): the wind-up (both palms drawn back to the chest) held while the
##              lock fills, the push from the chest on the cast, a beat, and back to the stand
##   expert     the same with the left palm alone (own-sway-push-one), played without the right arm (ToolPose "reach_l"): the
##              right hand keeps what it holds (a pistol, a tomahawk, a saber)
## A hold (Gust's stone held up, Gust in a sail) keeps the held part of the clip until it is let go (the push) or broken.
## Played over the game's pose by a ToolPose of our own, after every other modifier but the body (put_last: CharacterBodyMesh's
## helpers follow the clip's pose): "upper" always and "full" (the squat, the root's place) as far as the player stands still;
## an untrained caster is held still while the floor cast plays (SwayCaster roots them), so the squat is whole; the one-handed
## push "reach_l" only. A lock broken or fizzled: the body stands (the release from its up_s; a push eased out from back_s).
## The first lock (the wreck's scripted lock, no spell) plays none: SwayArm points the arm.
##
## ELEMENT MODE (the bending game; the user, 2026-10-04: "switch to a elemental avatar the last airbender type of game"):
## when the player casts as an element (BendPoses.element_of: a duel's or a ring's chosen element; never in the open world,
## whose tier clips above stay exactly as they are) each move plays its own pose (BendPoses.pick(move, mode, element):
## data/bending/poses.json, our own clips only), its mask, its limb and whether it roots the caster (rooting(); SwayCaster
## holds them still as for the floor cast) from the pick, then the clip's metas, then the rule above; a meta legs_always
## keeps the "full" layer while moving. A move with no pose keeps its tier clip.
## THE STRIKE: `struck(move)` once per cast, in the release, as the clip passes its strike_s (the pick's, else the clip's
## meta; at once when it has none); strike_wait() says how far off it is as a cast lets go (SwayCaster lands a bolt, a
## throw, a cone, a ring or a shove then: one mechanism, nothing else waits on it), strike_point() where it leaves from (the
## pose's limb, "hand": l_palm, r_palm, both, l_foot, r_foot; INF when no clip plays or it names none). A lock let go
## before its wind-up is drawn releases from where the clip is (not the hold's moment). current_clip() the clip on the body.
##
## THE KNOCK (Tidebreak's knock reactions, the player's; the owner's own clips, animations_extra/Frontier_Bend.res): while
## his BendKnock says he is knocked (its reaction window with a carry of KNOCK_MIN_MPS or more) own-bend-knock-slide plays
## on the full layer, over the cast's (a hit breaks the lock anyway): braced, the feet sliding apart, held at its hold_s
## while the knock lasts, then on from its back_s to the stand. Launched (a knock-up), own-bend-knock-air: held at its
## hold_s in the air, the landing played from its up_s once he is down. Not while down (the ragdoll, kneeling) or dead:
## the body is not the pose's then. knock_clip() / knock_weight() say what plays.
##
## THE STANCE (element mode only; data/bending/poses.json "stance": the element's own idle loop, our own clips,
## own-bend-stance-<element>): while he casts as an element and stands still on the ground with his hands free, the stance
## loops on the full layer under the cast's and the knock's, eased in over STANCE_IN_S as he comes to rest and out as he
## moves (STILL_MPS: the legs and the root are his locomotion's again), crouches, climbs, rides, kneels or dies. No gait:
## a stance idle only (the owner rejected an authored gait library on 2026-10-01). stance_clip() / stance_weight() say
## what plays. The open world (no element) never plays one.
## THE % RING (round 3, smash_r3 spec §13; only while the player has a RingMoves, a stock-rules ring): his body-state clip
## (RingMoves.clip_state: the tumble, the flinch, the double jump, the falls, helpless, the air dodge, the edge's grab, hang,
## climb, roll, jump, attack and scramble, the rolls and the duck, the landings, the four Rises, breaking the fall and the
## getups, the teeter, the spout) plays over the cast's layers on its own layer (movement.json clips: its clip, else its
## stand-in while CLIPS has not landed it; loops looped, one-shots held at their end), in place of the knock layer above; under
## a cast released in the air (SwayCaster.air_cast) the air legs (own-bend-air-legs) play under the cast's upper body; the
## steer's lean is RingMoves.LeanMod's (a bone tilt, not a clip). ring_clip() / ring_weight() say what plays.
## ROUND 5 (CLIPWIRE): the hit-stop holds this pose too (_process's dt by BendImpact.pose_rate, as PlayerAnim's graph: a
## held pose stands still, then catches up), and through the hold the struck contact pose shows over every layer
## (own-bend-hit-impact-<front|back|left|right> by where the hit came from; _tick_struck), its recoil then easing into the
## tumble or the flinch under it. Off the spout with no cast on the body the step-off plays once
## (movement.json clips spout_step_off).
## THE COMBO: a pose with an "alt" (the next hand: a throw's or a punch's mirrored twin) takes its alt when the same move
## in the same variation locks again within BendPoses.combo_window_s() of its last cast, and its first clip the time after
## (left, right, left); combo_alt says which the pose now is.

## Once per cast: the release's clip passed its strike (or it has none: at once).
signal struck(move: String)

const KNOCK_SLIDE := &"own-bend-knock-slide"
const KNOCK_AIR := &"own-bend-knock-air"
## A knock carrying the body slower than this (m/s) plays no slide (a nudge).
const KNOCK_MIN_MPS := 1.5
const KNOCK_IN_S := 0.08

const CLIPS := "res://animations_extra/Frontier_Form.res"
const CLAP_PRESS := &"own-form-clap-press"
const RELEASE := &"own-form-release"
const PRESS_WALL := &"own-form-press-wall"
const PUSH_TWO := &"own-sway-push-two"
const PUSH_ONE := &"own-sway-push-one"
const BLEND_IN_S := 0.12
const BLEND_OUT_S := 0.22
## Replacing an active cast or skipping to its recovery carries the displayed pose briefly. The clip and strike
## clocks keep advancing normally; a release's strike is the latest this handoff may finish.
const CAST_HANDOFF_S := 0.08
## Body speeds (m/s) over which the squat ("full") gives way to the upper body alone (the legs the player's).
const STILL_MPS := Vector2(0.35, 1.2)

var caster: SwayCaster
## The clip playing: "" none, "press" (the clap and press, or the wind-up: held), "release" (the push, or the push down and
## stand), "up" (the stand after a broken lock).
var phase := ""
var clip_t := 0.0
var weight := 0.0
## The clip's name ("" none) and the tier it was chosen for (-1 none).
var anim_name := ""
var tier := -1
## The palms (world; after every modifier: the clip's pose): their midpoint, or the left palm for the one-handed push. INF
## before.
var palms := Vector3.INF
## The palms pressed to the ground (or the wall), the clap heard: the floor cast's moments.
var pressed := false
var clapped := false
## The move posing ("" none) and its pose in element mode (BendPoses.pick; {} the tier clip).
var move := ""
var pick := {}

var _lib: AnimationLibrary
var _pose: ToolPose
var _anim: Animation
var _hold := 0.0
var _from_t := 0.0
var _w0 := 0.0
var _floor := false
var _palm_ids := Vector2i(-2, -2)
## The strike: its moment on the release's clip (-1 none known), whether it was told, the limb it leaves from ("" none),
## that limb (world; INF none) and the limbs' bones.
var _strike := -1.0
var _struck := true
var _hand := ""
var _strike_at := Vector3.INF
var _limb_ids := {}
## The cast's layers this frame (the knock's go over them).
var _cast_layers: Array = []
var _cast_from: Array = []
var _cast_mix_t := 0.0
var _cast_mix_s := 0.0
## The knock playing: "" none, "slide" or "air"; its stage ("hold": in and held, "out": the recovery), clip time, weight.
var knock := ""
var _k_stage := ""
var _k_t := 0.0
var _k_w := 0.0
var _k_anim: Animation
## The stance: its clip (null none), time in its loop and weight; the element it was taken for.
const STANCE_IN_S := 0.35
const STANCE_OUT_S := 0.18
var _st_anim: Animation
var _st_el := ""
var _st_style := ""
var _st_t := 0.0
var _st_w := 0.0
## The % ring's state layer: its state key, clip, time, weight, mask, loop; the air legs' clip, time, weight.
const RING_IN_S := 0.08
const RING_OUT_S := 0.15
const AIR_LEGS_S := 0.6
## Landing plants the lower body immediately; its upper body recovers from the airborne pose over this interval.
const LAND_UPPER_S := 0.08
## Ordinary airborne movement supports a cast; reactions/recoveries still take the body away from it.
const RING_UNDER_CAST := ["fall", "fall_fast", "double_jump", "spout_step_off"]
## These clips establish contact in their first frame or two; the spout is a respawn. Keep contact on time and clear
## the outgoing pose when the fighter is placed on the spout. Flinch takes only the upper body, so it must also release
## the outgoing state's legs immediately instead of holding them underneath an upper-only handoff.
const RING_CONTACT := ["edge_grab", "edge_hang", "edge_scramble", "tech", "tech_wall", "land_light", "land_heavy",
		"knock_bounce", "spout_ride", "flinch"]
var ring_state := ""
var _r_anim: Animation
var _r_name := ""
var _r_t := 0.0
var _r_w := 0.0
var _r_mask := "full"
var _r_loop := false
var _r_over_cast := true
## Sampled outgoing layers survive a state change while the incoming clip blends in.
var _r_from: Array = []
var _r_from_w := 1.0
var _r_mix := 1.0
var _land_from: Array = []
var _land_t := 0.0
var _land_s := 0.0
var _al_anim: Animation
var _al_t := 0.0
var _al_w := 0.0
var _ring_lean := false
## Round 5: the spout's step-off plays until this (this node's clock; -INF none).
var _off_until := -INF
## The combo: this pose took its alt; the last cast's move/mode, whether it was the alt, and when (this node's clock, s).
var combo_alt := false
var _clock := 0.0
var _last_key := ""
var _last_alt := false
var _last_at := -INF


func _ready() -> void:
	if caster == null:
		caster = get_parent() as SwayCaster
	if caster == null:
		return
	caster.lock_started.connect(_on_started)
	caster.cast.connect(_on_cast)
	caster.lock_broken.connect(func(_m: String, _t: Node3D, _why: String) -> void: _on_end())
	caster.fizzled.connect(func(_m: String, _t: Node3D) -> void: _on_end())
	if caster.player != null and caster.player.skeleton != null:
		caster.player.skeleton.skeleton_updated.connect(_on_skeleton_updated)


## The clips (null until they load; null when the library is missing).
func clips() -> AnimationLibrary:
	if _lib == null and ResourceLoader.exists(CLIPS):
		_lib = load(CLIPS) as AnimationLibrary
	return _lib


## A clip is on the body now (the lock's press or wind-up, or the push and the stand after it).
func posing() -> bool:
	return phase != ""


## The clip a spell's lock plays at mastery tier `t` (0 untrained, 1 practised, 2 expert); on an upright (the floor cast only).
static func clip_for(t: int, on_wall := false) -> StringName:
	match t:
		1:
			return PUSH_TWO
		2:
			return PUSH_ONE
	return PRESS_WALL if on_wall else CLAP_PRESS


## The clip on the body now (&"" none).
func current_clip() -> StringName:
	return StringName(anim_name)


## The caster held still while this clip plays: the untrained floor cast, or a pose that says root. A pose whose root is
## "strike" (fire's kicks: the owner, 2026-10-10, "after the spell is cast let the player move") holds him through the
## wind-up and up to the strike, and lets him go once the move has left (the recovery walked out of).
func rooting() -> bool:
	if not posing():
		return false
	if pick.is_empty():
		return tier == 0
	var r: Variant = pick.get("root", false)
	if r is String:
		return String(r) == "strike" and not (phase == "release" and _struck)
	return bool(r)


## Where the move leaves from (world): the pose's limb as the clip has it after every modifier. INF when no clip plays or
## it names none (the tier clips: the caster's chest is used).
func strike_point() -> Vector3:
	return _strike_at if phase != "" else Vector3.INF


## Seconds from now to the strike of the release a cast now would play (-1: no strike time known; the effect lands at once).
func strike_wait() -> float:
	if phase != "press" or _anim == null:
		return -1.0
	var s := _release_strike()
	if s < 0.0:
		return -1.0
	var from := clip_time() if _release_clip() == StringName(anim_name) else 0.0
	return maxf(s - from, 0.0)


## The release's clip: the pose's "then", the floor cast's stand, else the clip itself (on from where it is).
func _release_clip() -> StringName:
	var nxt := String(pick.get("then", ""))
	if nxt != "":
		return StringName(nxt)
	return RELEASE if anim_name == String(CLAP_PRESS) else StringName(anim_name)


## The strike's moment on the release's clip: the pick's, else that clip's meta strike_s; -1 none.
func _release_strike() -> float:
	if not pick.is_empty() and pick.has("strike_s"):
		return float(pick.strike_s)
	var a := _animation(_release_clip())
	return float(a.get_meta(&"strike_s", -1.0)) if a != null else -1.0


func _on_skeleton_updated() -> void:
	if phase == "":
		return
	var sk := caster.player.skeleton
	if _palm_ids.x == -2:
		_palm_ids = Vector2i(sk.find_bone("l_palm"), sk.find_bone("r_palm"))
	if _palm_ids.x < 0 or _palm_ids.y < 0:
		return
	var l := sk.get_bone_global_pose(_palm_ids.x).origin
	var r := sk.get_bone_global_pose(_palm_ids.y).origin
	var mid := (l + r) * 0.5
	if anim_name == String(PUSH_ONE) or _hand == "l_palm":
		mid = l
	elif _hand == "r_palm":
		mid = r
	palms = sk.global_transform * mid
	_strike_at = _limb(sk, _hand) if _hand != "" else Vector3.INF


## Limb `which` (l_palm, r_palm, both, l_foot, r_foot) in the world (INF unknown).
func _limb(sk: Skeleton3D, which: String) -> Vector3:
	if which == "both":
		var a := _limb(sk, "l_palm")
		var b := _limb(sk, "r_palm")
		return (a + b) * 0.5 if a != Vector3.INF and b != Vector3.INF else Vector3.INF
	if not _limb_ids.has(which):
		var bone: String = {"l_foot": "l_ball", "r_foot": "r_ball"}.get(which, which)
		_limb_ids[which] = sk.find_bone(bone)
	var i := int(_limb_ids[which])
	return sk.global_transform * sk.get_bone_global_pose(i).origin if i >= 0 else Vector3.INF


# ---------------------------------------------------------------- the caster's lock
func _on_started(m: String, _t: Node3D) -> void:
	if not caster.is_spell(m):
		return                              # (the first lock: the pointing arm)
	_strike_now()                           # (the last cast's strike, not yet come: it leaves as the next lock begins)
	move = m
	tier = caster.tier(m)
	var el := BendPoses.element_of(caster.player)
	pick = BendPoses.pick(m, caster.mode_of(m), el, caster.player) if el != "" else {}
	combo_alt = false
	if not pick.is_empty() and pick.has("alt"):
		# (the same move again within the combo window: the other hand, then back)
		var again := _last_key == m + "/" + caster.mode_of(m) and _clock - _last_at <= BendPoses.combo_window_s()
		if again and not _last_alt:
			var alt := BendPoses._as_pose(pick.alt)
			if not alt.is_empty() and BendPoses.usable(String(alt.clip)) and _animation(StringName(String(alt.clip))) != null:
				alt["from"] = pick.get("from", "mode")
				pick = BendPoses._filled(alt, BendPoses.data())
				combo_alt = true
	var clip: StringName
	if not pick.is_empty() and _animation(StringName(String(pick.clip))) != null:
		clip = StringName(String(pick.clip))
	else:
		pick = {}
		var wall := caster.form != null and caster.form.on_wall and FormCast.is_form(m)
		clip = clip_for(tier, wall)
	_floor = clip == CLAP_PRESS
	_hand = String(pick.get("hand", ""))
	_strike_at = Vector3.INF
	_struck = true
	_begin(clip, "press")


func _on_cast(m: String, _t: Node3D) -> void:
	if phase == "" or not caster.is_spell(m):
		return
	_strike = _release_strike()
	_last_key = m + "/" + caster.mode_of(m)
	_last_alt = combo_alt
	_last_at = _clock
	_struck = false
	var nxt := _release_clip()
	if nxt != StringName(anim_name):
		_begin(nxt, "release", 0.0)                    # (the floor cast: the palms push down and the body stands)
	else:
		_begin(nxt, "release", clip_time())            # (the wall's shove, the push: on from the held moment, or from
		                                               # where the wind-up is when the lock let go before it was drawn)
	if phase != "release" or _strike < 0.0:
		_strike_now()                                  # (no clip, or no strike time: the strike is now)


## The strike told (once a cast).
func _strike_now() -> void:
	if _struck:
		return
	_struck = true
	struck.emit(move)


func _on_end() -> void:
	if phase != "press":
		return
	if clips() == null and pick.is_empty():
		return
	var nxt := _release_clip()
	if nxt != StringName(anim_name):
		var r := _animation(nxt)
		_begin(nxt, "up", float(r.get_meta(&"up_s", 0.2)) if r else 0.2)
		return
	match anim_name:
		String(PRESS_WALL):
			_begin(PRESS_WALL, "up", float(pick.get("back_s", _anim.get_meta(&"push_s", _hold))))
		_:
			_begin(StringName(anim_name), "up", float(pick.get("back_s", _anim.get_meta(&"back_s", _hold))))


# ---------------------------------------------------------------- the clip
## Clip `clip`: the Form library's, else BendPoses' (our own libraries; a test's injected clips). Null none.
func _animation(clip: StringName) -> Animation:
	var lib := clips()
	if lib != null and lib.has_animation(clip):
		return lib.get_animation(clip)
	return BendPoses.animation(String(clip))


func _begin(clip: StringName, p_phase: String, from_t := 0.0) -> void:
	var a := _animation(clip)
	if a == null:
		phase = ""
		_cast_from = []
		return
	var continuing := a == _anim and is_equal_approx(from_t, clip_time()) and p_phase != "press"
	if not continuing:
		_cast_from = ToolPose.collapse_layers(_cast_layers) if weight > 0.0 else []
		_cast_mix_t = 0.0
		_cast_mix_s = CAST_HANDOFF_S
	if p_phase == "release" and _strike >= 0.0:
		_cast_mix_s = minf(_cast_mix_s, _cast_mix_t + maxf(_strike - from_t, 0.0))
	if _cast_mix_s <= _cast_mix_t:
		_cast_from = []
	_anim = a
	anim_name = String(clip)
	phase = p_phase
	clip_t = 0.0
	_from_t = from_t
	_w0 = weight
	if p_phase == "press":
		_hold = float(pick.get("hold_s", _anim.get_meta(&"hold_s", _anim.length)))
		clapped = false
		pressed = false
	_ensure_pose()


## The ToolPose on the skeleton, last but the body, on (false: no skeleton).
func _ensure_pose() -> bool:
	var sk := caster.player.skeleton
	if sk == null:
		return false
	if _pose == null or not is_instance_valid(_pose):
		_pose = ToolPose.new()
		_pose.name = "SwayCastPose"
	if _pose.get_parent() != sk:
		if _pose.get_parent():
			_pose.get_parent().remove_child(_pose)
		sk.add_child(_pose)
	put_last(sk, _pose)
	_pose.active = true
	return true


## `pose` moved over the tree and every other modifier, but the body (CharacterBodyMesh) put back behind it: its helpers (the
## shoulder and forearm twist, the armpit, the skirt) follow the final pose. Moving a child does not tell the body (it sorts
## itself last only as a modifier enters the tree), so a second cast would otherwise run after it: the skin stretched from
## the pose before the cast (the forearm a noodle, the sleeve a sheet). ForagePick's grab does the same.
static func put_last(sk: Skeleton3D, pose: Node) -> void:
	sk.move_child(pose, -1)
	for n in sk.get_children():
		if n is CharacterBodyMesh and n != pose:
			sk.move_child(n, -1)


## The clip's time now (s).
func clip_time() -> float:
	if _anim == null:
		return 0.0
	match phase:
		"press":
			return minf(clip_t, _hold)
		"release", "up":
			return minf(_from_t + clip_t, _end())
	return 0.0


func _process(dt: float) -> void:
	if caster == null or caster.player == null or not is_instance_valid(caster.player):
		return
	dt *= BendImpact.pose_rate(caster.player, dt)        # (round 4, IMPACT: the hit-stop holds his visible pose too)
	_clock += dt
	_cast_layers = []
	_tick(dt)
	var rm := caster.player.ring_moves
	if rm != null:
		_tick_ring(dt, rm)
	else:
		_tick_knock(dt)
	_tick_stance(dt)
	_tick_struck(dt)
	_apply()
	_aim_follow(dt)


## Round 2 (skills_r2 spec §2.3: "the upper body, hips and hands turn with the aim during the hold, so you and he both see it
## steer"): with an element, while a lock is held its spine bends toward the crosshair's height (ToolPose.lean, AIM_LEAN of
## the aim's pitch, at most AIM_LEAN_MAX), eased in and back out after (the body's yaw already follows the camera).
const AIM_LEAN := 0.6
const AIM_LEAN_MAX := 0.45
var aim_lean := 0.0
func _aim_follow(dt: float) -> void:
	var want := 0.0
	var cam: Camera3D = caster.player.camera if caster.player != null else null
	if phase == "press" and caster.elem() and caster.state in [SwayCaster.State.LOCKING, SwayCaster.State.FULL] \
			and cam != null and cam.is_inside_tree():
		var pitch := asin(clampf(-cam.global_basis.z.y, -1.0, 1.0))
		want = clampf(-pitch * AIM_LEAN, -AIM_LEAN_MAX, AIM_LEAN_MAX)
	aim_lean = move_toward(aim_lean, want, dt * 2.5)
	if _pose != null and is_instance_valid(_pose):
		_pose.lean = aim_lean


## The stance's layer, the cast's over it, then the knock's over them, onto the ToolPose (off when there are none).
func _apply() -> void:
	var stance := _st_anim != null and _st_w > 0.0
	var ring := _r_anim != null and _r_w > 0.0
	var legs := _al_anim != null and _al_w > 0.0
	var hit := _s_anim != null and _s_w > 0.0
	if _pose == null or not is_instance_valid(_pose):
		if (knock == "" and not stance and not ring and not legs and not hit) or not _ensure_pose():
			return
	var ls: Array = []
	if stance:
		ls.append({"anim": _st_anim, "time": _st_t, "weight": _st_w, "mask": "full"})
	var ring_layers := _ring_layers() if ring else []
	for layer: Dictionary in ring_layers:
		if not bool(layer.get("over_cast", true)):
			ls.append(layer)
	if legs:
		# (the air legs over ordinary falling, under the cast: the arms remain the upper-body cast's)
		ls.append({"anim": _al_anim, "time": _al_t, "weight": _al_w, "mask": "full"})
	ls.append_array(_cast_layers)
	if knock != "" and _k_anim != null and _k_w > 0.0:
		ls.append({"anim": _k_anim, "time": _k_t, "weight": _k_w, "mask": "full"})
	for layer: Dictionary in ring_layers:
		if bool(layer.get("over_cast", true)):
			ls.append(layer)
	if not _land_from.is_empty():
		ls.append({"blend_from": _land_from, "blend_to": [], "blend_weight": _land_t / _land_s, "blend_mask": "upper"})
	if hit:
		ls.append({"anim": _s_anim, "time": _s_t, "weight": _s_w, "mask": "full"})
	_pose.layers = ls
	if ls.is_empty() and phase == "":
		_pose.active = false
	elif not _pose.active:
		_ensure_pose()


func _tick(dt: float) -> void:
	if phase == "" or _anim == null:
		return
	clip_t += dt
	var t := clip_time()
	var w := 1.0
	match phase:
		"press":
			w = lerpf(_w0, 1.0, clampf(clip_t / BLEND_IN_S, 0.0, 1.0))
			if _floor or anim_name == String(PRESS_WALL):
				if not clapped and t >= float(_anim.get_meta(&"clap_s", 0.23)):
					clapped = true
					FormEffects.sfx("clap", caster.hand_point(), -8.0, 1.5)
				var press_at := float(_anim.get_meta(&"press_s", _anim.get_meta(&"hold_s", 0.66)))
				if not pressed and t >= press_at:
					pressed = true
					FormEffects.sfx("press", caster.hand_point(), -4.0, 0.9)
			elif not pressed and t >= _hold:
				pressed = true                                          # (the wind-up drawn: the palms ready)
		"release", "up":
			var end := _end()
			var run := _from_t + clip_t
			w = minf(lerpf(_w0, 1.0, clampf(clip_t / 0.06, 0.0, 1.0)), clampf((end - run) / BLEND_OUT_S, 0.0, 1.0))
			if phase == "release" and not _struck and (t >= _strike or run >= end):
				_strike_now()                                       # (the strike's moment: the move leaves the hand)
			if run >= end:
				_stop()
				return
	weight = w
	if _pose == null or not is_instance_valid(_pose):
		return
	var mask := _mask()
	var st := _sample_t(t)                                          # (a fighting style's clip is shown on the element's timeline)
	if mask != "upper":
		_cast_layers = [{"anim": _anim, "time": st, "weight": w, "mask": mask}]
	else:
		var still := 1.0 if _legs_always() else 1.0 - smoothstep(STILL_MPS.x, STILL_MPS.y, caster.player.horizontal_speed())
		_cast_layers = [{"anim": _anim, "time": st, "weight": w, "mask": "upper"}, {"anim": _anim, "time": st, "weight": w * still, "mask": "full"}]
	if not _cast_from.is_empty():
		_cast_mix_t += dt
		if _cast_mix_t >= _cast_mix_s:
			_cast_from = []
		else:
			_cast_layers = [{"blend_from": _cast_from, "blend_to": _cast_layers, "blend_weight": _cast_mix_t / _cast_mix_s}]


## Where the pose ends on its own timeline (s): the pick's end_s (a fighting style's cast ends when the element's own would, so
## the caster stays rooted as long), else the clip's length.
func _end() -> float:
	return float(pick.get("end_s", _anim.length)) if _anim != null else 0.0


## The clip's own time for the pose's time `t`: the pick's warp ([[pose s, clip s], ...] by pose time: a fighting style's clip
## put on the element's hold, strike and back, BendPoses._timed_as), linear between them and at the clip's own pace after the
## last; `t` itself without one (every element clip).
func _sample_t(t: float) -> float:
	var w: Variant = pick.get("warp") if not pick.is_empty() else null
	if not (w is Array) or (w as Array).size() < 2:
		return t
	var pts := w as Array
	for i in range(1, pts.size()):
		var a: Array = pts[i - 1]
		var b: Array = pts[i]
		if t <= float(b[0]):
			var span := maxf(float(b[0]) - float(a[0]), 0.0001)
			return minf(lerpf(float(a[1]), float(b[1]), clampf((t - float(a[0])) / span, 0.0, 1.0)), _anim.length)
	var last: Array = pts[pts.size() - 1]
	return minf(float(last[1]) + (t - float(last[0])), _anim.length)


## The clip's mask: the pose's, the clip's meta, else the rule (the one-handed push "reach_l"; else "upper", with "full" as
## far as the caster stands still).
func _mask() -> String:
	if pick.has("mask"):
		return String(pick.mask)
	if _anim != null and _anim.has_meta(&"mask"):
		return String(_anim.get_meta(&"mask"))
	return "reach_l" if anim_name == String(PUSH_ONE) else "upper"


## The legs' clip kept while moving (a kick, a stomp: the pose's or the clip's legs_always). Not once a pose rooted up to its
## strike has struck: the caster walks out of the recovery on the walk's own legs (no kick's legs sliding along the deck).
func _legs_always() -> bool:
	var r: Variant = pick.get("root", false)
	if r is String and String(r) == "strike" and phase == "release" and _struck:
		return false
	return bool(pick.get("legs_always", _anim.get_meta(&"legs_always", false) if _anim != null else false))


func _stop() -> void:
	_struck = true                  # (told already as the clip ran out; leaving the tree untold: SwayCaster's fallback lands it)
	phase = ""
	anim_name = ""
	weight = 0.0
	tier = -1
	move = ""
	pick = {}
	_hand = ""
	_strike_at = Vector3.INF
	_cast_layers = []
	_cast_from = []
	_cast_mix_t = 0.0
	_cast_mix_s = 0.0
	if _pose != null and is_instance_valid(_pose) and knock == "":
		_pose.layers = []
		_pose.active = false


# ---------------------------------------------------------------- the stance
## The element's stance clip playing (&"" none), and its weight now.
func stance_clip() -> StringName:
	return StringName(stance_name(_st_el, caster.player)) if _st_anim != null and _st_w > 0.0 else &""


func stance_weight() -> float:
	return _st_w if _st_anim != null else 0.0


## The stance clip poses.json names for `element` ("" none, or not one of our own usable clips).
static func stance_name(element: String, body: Node = null) -> String:
	if element == "":
		return ""
	var v: Variant = BendPoses.stance_pose(element, body)          # (a fighting style's own stance, else the element's)
	var nm := String(BendPoses._as_pose(v).get("clip", ""))
	return nm if nm != "" and BendPoses.usable(nm) else ""


## How much the stance should show now (0..1): casting as an element, on the ground, still, hands free, upright.
func stance_wanted() -> float:
	var p := caster.player
	if p.is_dead or p.kneeling != null or p.riding != null or p.climbing != null or p.is_crouching:
		return 0.0
	if not p.is_on_floor() or not (p.hands_free or p.weapon == null):
		return 0.0
	return 1.0 - smoothstep(STILL_MPS.x * 0.5, STILL_MPS.x * 1.6, p.horizontal_speed())


func _tick_stance(dt: float) -> void:
	var el := BendPoses.element_of(caster.player)
	var sty := BendPoses.style_of(caster.player, el)
	if el != _st_el or sty != _st_style:
		_st_el = el
		_st_style = sty
		var nm := stance_name(el, caster.player)
		var a := BendPoses.animation(nm) if nm != "" else null
		if a != _st_anim:
			_st_anim = a
			_st_w = 0.0
			_st_t = 0.0
	if _st_anim == null:
		_st_w = 0.0
		return
	var want := stance_wanted()
	_st_w = move_toward(_st_w, want, dt / (STANCE_IN_S if want > _st_w else STANCE_OUT_S))
	if _st_w > 0.0:
		_st_t = fmod(_st_t + dt, maxf(_st_anim.length, 0.01))
	else:
		_st_t = 0.0


func _exit_tree() -> void:
	knock = ""
	_stop()


# ---------------------------------------------------------------- the % ring's body state (round 3)
## The ring's state clip playing (&"" none), and its weight now.
func ring_clip() -> StringName:
	return StringName(_r_name) if _r_anim != null and _r_w > 0.0 else &""


func ring_weight() -> float:
	return _r_w if _r_anim != null else 0.0


## The sampled ring pose, including an interrupted handoff. ToolPose blends rotations and root/pelvis positions together.
func _ring_layers() -> Array:
	var layers: Array = []
	if _r_anim == null or _r_w <= 0.0:
		return layers
	if _r_mix < 1.0:
		# ToolPose composes layers in order: retain the outgoing pose, then lerp the incoming one over it.
		var fade := _r_w / maxf(_r_from_w, 0.001)
		for from: Dictionary in _r_from:
			var layer := from.duplicate()
			layer["weight"] = float(layer.weight) * fade
			if float(layer.weight) > 0.0:
				layers.append(layer)
	layers.append({"anim": _r_anim, "time": _r_t, "weight": _r_w * _r_mix, "mask": _r_mask,
			"over_cast": _r_over_cast})
	return layers


func _clear_ring() -> void:
	ring_state = ""
	_r_anim = null
	_r_name = ""
	_r_t = 0.0
	_r_w = 0.0
	_r_from.clear()
	_r_mix = 1.0
	_land_from = []
	_land_t = 0.0
	_land_s = 0.0
	_off_until = -INF


## The ring's state layer from RingMoves.clip_state (its clip or stand-in, eased in and out; a loop looped, a one-shot held at
## its end), the air legs under an airborne cast, the steer's lean put on the skeleton once.
func _tick_ring(dt: float, rm: RingMoves) -> void:
	knock = ""
	var p := caster.player
	if not _ring_lean and p.skeleton != null:
		_ring_lean = true
		RingMoves.lean_on(p.skeleton, rm)
	if p.is_dead:
		_clear_ring()
		_al_w = 0.0
		return
	var st := rm.clip_state()
	var nm := ""
	if st != "":
		nm = String(RingMoves.clip_for(st)[0])
	elif caster.guard_held():
		# (AIR's held guard: its own loop per element while E keeps it up, SwayCaster.guard_hold_clip, else its stand-in)
		st = "guard_hold"
		nm = caster.guard_hold_clip()
	elif phase == "":
		# (round 5: off the spout, no cast on the body: the step off, once through, until another state takes over)
		if ring_state == "spout_ride":
			var so := BendPoses.animation(String(RingMoves.clip_for("spout_step_off")[0]))
			_off_until = _clock + so.length if so != null else -INF
		if _clock < _off_until:
			st = "spout_step_off"
			nm = String(RingMoves.clip_for(st)[0])
	if st != "spout_step_off":
		_off_until = -INF
	# Once recovery travel ends, its fading pose goes under the first follow-up attack. Active recoveries still own the body.
	if ring_state.begins_with("rise_") and rm.can_cast():
		_r_over_cast = false
		for layer: Dictionary in _r_from:
			layer["over_cast"] = false
	if nm != "" and (nm != _r_name or st != ring_state):
		var a := BendPoses.animation(nm)
		if a != null:
			_land_from = []
			if st in ["land_light", "land_heavy"] and _pose != null and is_instance_valid(_pose):
				_land_from = ToolPose.collapse_layers(_pose.layers)
				_land_t = 0.0
				_land_s = LAND_UPPER_S
				if phase == "release" and not _struck and _strike >= 0.0:
					_land_s = minf(_land_s, maxf(_strike - clip_time(), 0.0))
				if _land_s <= 0.0:
					_land_from = []
			var switching := _r_anim != null and _r_w > 0.0 and nm != _r_name
			if switching and not st in RING_CONTACT:
				_r_from = _ring_layers()
				_r_from_w = _r_w
				_r_mix = 0.0
			elif not switching or st in RING_CONTACT:
				_r_from.clear()
				_r_mix = 1.0
			if _r_anim == null or _r_w <= 0.0 or nm != _r_name:
				_r_t = 0.0
			_r_anim = a
			_r_name = nm
			var spec := RingMoves.clip_spec(st) if st != "guard_hold" else {"mask": "full", "loop": true}
			_r_mask = String(spec.get("mask", "full"))
			_r_loop = bool(spec.get("loop", false))
			_r_over_cast = not st in RING_UNDER_CAST
			if st in RING_CONTACT:
				_r_w = 1.0
	ring_state = st if nm != "" else ""
	_r_mix = minf(_r_mix + dt / RING_IN_S, 1.0)
	if _r_mix >= 1.0:
		_r_from.clear()
	if not _land_from.is_empty():
		_land_t += dt
		if _land_t >= _land_s:
			_land_from = []
	if ring_state != "" and _r_anim != null:
		_r_t += dt
		if _r_loop and _r_anim.length > 0.0:
			_r_t = fposmod(_r_t, _r_anim.length)
		else:
			_r_t = minf(_r_t, _r_anim.length)
		_r_w = minf(_r_w + dt / RING_IN_S, 1.0)
	else:
		_r_w = maxf(_r_w - dt / RING_OUT_S, 0.0)
		if _r_w <= 0.0:
			_clear_ring()
	# the air legs: under a cast let go in the air, while he is still in the air
	var legs_on := rm.looks != null and rm.airborne() and rm.looks.air_legs_at > -INF \
			and rm.mode_t >= 0.0 and _clock_ok(rm)
	if legs_on and _al_anim == null:
		var ln := String(RingMoves.clip_for("air_legs")[0])
		_al_anim = BendPoses.animation(ln) if ln != "" else null
		_al_t = 0.0
	if legs_on and _al_anim != null:
		_al_t = minf(_al_t + dt, _al_anim.length)
		_al_w = minf(_al_w + dt / RING_IN_S, 1.0)
	else:
		_al_w = maxf(_al_w - dt / RING_OUT_S, 0.0)
		if _al_w <= 0.0:
			_al_anim = null


## The struck contact pose (round 5, CLIPWIRE; BendImpact's STRUCK_META, recorded at a held hit): a new one goes on over
## every layer at once, at its clip's hold_s (the contact), and stays there while the hit-stop holds the pose (dt is nothing
## then); after the hold its recoil plays on (at the hold's catch-up rate) and fades out by the clip's end into what is under
## it (the ring's tumble or flinch, eased in meanwhile). struck_clip() / struck_weight() say what shows.
var _s_anim: Animation
var _s_name := ""
var _s_t := 0.0
var _s_w := 0.0
var _s_from := 0.0
var _s_at := -INF


func struck_clip() -> StringName:
	return StringName(_s_name) if _s_anim != null and _s_w > 0.0 else &""


func struck_weight() -> float:
	return _s_w if _s_anim != null else 0.0


func _tick_struck(dt: float) -> void:
	var p := caster.player
	var s := BendImpact.struck_of(p)
	if s.is_empty():
		_s_anim = null
		_s_name = ""
		_s_w = 0.0
		_s_at = -INF
		return
	if not s.is_empty() and float(s.get("at", -INF)) != _s_at:
		_s_at = float(s.get("at", -INF))
		var a := BendPoses.animation(String(s.get("clip", "")))
		if a != null:
			_s_anim = a
			_s_name = String(s.clip)
			_s_from = clampf(float(a.get_meta(&"hold_s", a.length * 0.5)), 0.0, a.length)
			_s_t = _s_from
			_s_w = 1.0
	if _s_anim == null:
		return
	if p.is_dead:
		_s_anim = null
		_s_name = ""
		_s_w = 0.0
		return
	_s_t = minf(_s_t + dt, _s_anim.length)
	_s_w = clampf((_s_anim.length - _s_t) / maxf(_s_anim.length - _s_from, 0.01), 0.0, 1.0)
	if _s_t >= _s_anim.length:
		_s_anim = null
		_s_name = ""
		_s_w = 0.0


## The airborne cast was let go within AIR_LEGS_S (on RingMoves' clock).
func _clock_ok(rm: RingMoves) -> bool:
	return rm._t - rm.looks.air_legs_at <= AIR_LEGS_S


# ---------------------------------------------------------------- the knock
## The knock clip playing (&"" none), and its weight now.
func knock_clip() -> StringName:
	match knock:
		"air":
			return KNOCK_AIR
		"slide":
			return KNOCK_SLIDE
	return &""


func knock_weight() -> float:
	return _k_w if knock != "" else 0.0


## What the player's knock asks for now: "air" launched, "slide" reeling with a carry, "" none (or down, or dead).
func knock_wanted() -> String:
	var p := caster.player
	if p.is_dead or p.kneeling != null or p.riding != null or p.climbing != null:
		return ""
	var kn := BendKnock.peek(p)
	if kn == null:
		return ""
	if kn.is_launched():
		return "air"
	if kn.knock_t > 0.0 and kn.kv.length() >= KNOCK_MIN_MPS:
		return "slide"
	return ""


func _tick_knock(dt: float) -> void:
	var want := knock_wanted()
	var p := caster.player
	if p.is_dead or p.kneeling != null or p.riding != null or p.climbing != null:
		knock = ""                              # (down or dead: the body is not the pose's; nothing eased)
		_k_w = 0.0
		return
	if want != "" and (want != knock or _k_stage == "out"):
		var a := BendPoses.animation(String(KNOCK_AIR if want == "air" else KNOCK_SLIDE))
		if a != null:
			if knock == "":
				_k_w = 0.0
			knock = want
			_k_anim = a
			_k_stage = "hold"
			_k_t = 0.0
	if knock == "" or _k_anim == null:
		return
	var hold := float(_k_anim.get_meta(&"hold_s", 0.3))
	if _k_stage == "hold":
		_k_t = minf(_k_t + dt, hold)
		_k_w = minf(_k_w + dt / KNOCK_IN_S, 1.0)
		if want != knock:
			# (over: the slide from its back_s, the air's landing from its up_s, on to the stand)
			_k_stage = "out"
			_k_t = maxf(_k_t, float(_k_anim.get_meta(&"up_s" if knock == "air" else &"back_s", hold)))
		return
	_k_t += dt
	_k_w = minf(_k_w, clampf((_k_anim.length - _k_t) / BLEND_OUT_S, 0.0, 1.0))
	if _k_t >= _k_anim.length:
		knock = ""
		_k_stage = ""
		_k_w = 0.0
