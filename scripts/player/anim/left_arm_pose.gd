class_name LeftArmPose
extends SkeletonModifier3D
## Sets one arm (clavicle to fingertips; `side`) to a pose sampled from clips, over the animation tree's
## pose (user playtest 2026-09-25: "the rifle hold in the regular or run or jog ... the left shoulders or
## lats are messed up").
##
## Uses, chosen by PlayerAnim through the sources:
##  - GRIP (the left arm; walking, jogging, sprinting, crouch-walking with a long gun, not aiming): the
##    source's two-hand carry arm at FULL weight (standing actor_b-p-rifle-run-arms, crouched
##    actor_b-p-rifle-crouch-run-arms). The graph plays the carry arm layers at 0.8-0.9 over the
##    empty-handed arm swing (and walking it plays the one-hand carry actor_b-p-rifle-idle-arms), which
##    holds the left palm 13-35 cm off the gun; LeftGripIK, pulling that hovering hand onto the stock,
##    lifted the whole arm and turned the elbow (the crouch-walk's in across the chest). At full weight
##    the arm is the animators' own two-hand grip and LeftGripIK only closes the rest to where our gun is.
##  - FREE (the relaxed one-hand carry while crouch-moving, hands free): the plain locomotion clips
##    under the carry layer (their natural arm swing).
##  - The jump's take-off (both arms): the carry arms layer, both hands on the gun.
##  - The one-hand crouch-move hold (the right arm): the source's one-hand crouch-move rifle arm (the gun
##    held down at the side), at the stride's phase.
## Every other bone keeps the tree's pose. A source may be mirrored ("mirror": true, push n01c: the tomahawk's
## right-arm carry held in the left hand): each bone takes the other side's track. On Actor_B that is the whole
## mirror: the rig is symmetric at rest (a left bone sits at the right one's position mirrored across the character's
## middle) and a left arm bone's local rest rotation equals the right one's (its local offset is negated), so the
## mirrored arm pose is the other side's local rotations as they are, except the clavicle (its parent, spined, is the
## body's middle): a half turn about spined's X (the character's left-right axis) before it (MIRROR_CLAVICLE;
## tests/anim/test_hand_holds.gd checks both on the rest).
## A source may also be limited to the hand ("part": "hand", the palm and fingers: a grip) or to the arm
## ("part": "arm", clavicle to wrist). PlayerAnim sets `enabled` and the sources (set_sources(), with a
## key naming what they show) every frame; the weight fades over FADE_S, and a change of key cross-fades from
## the pose shown last over SOURCE_XFADE_S (push n01: the relaxed carry coming on during a crouch-walk
## switched the left arm from the grip arm to the free swing in one frame).
## take_over() brings the arm in at full weight at once, cross-fading from the arm as it was shown here last
## frame (push n09: at a jump's take-off the tree's own arm drops the carry's arm layer in one frame; a quick
## fade over it showed that drop and then pulled the arm back).
## Order: after PropFlipGuard and AimStabilizer, before GunCarryDamper, LeftGripIK and the body's modifier.

## Seconds for the free arm to come in or go.
const FADE_S := 0.25
## The fade in use (FADE_S unless the caller sets another).
var fade_s := FADE_S
## Arm chain and hand bones by name (prefixed with the side: "l" or "r").
const ARM := ["clavicle", "shoulder", "elbow", "wrist"]
const FINGER_KEYS := ["palm", "index", "middle", "ring", "pinky", "thumb"]
## Which arm: "l" (the long-gun carries' left arm) or "r" (hands free, the take-off, the one-hand hold).
var side := "l"
## A mirrored clavicle rotation is this times the other side's (see the header).
const MIRROR_CLAVICLE := Quaternion(1.0, 0.0, 0.0, 0.0)
## Seconds to cross-fade from one source set to the next (set_sources() with another key).
const SOURCE_XFADE_S := 0.2

## Free arm wanted (PlayerAnim, every frame).
var enabled := false
## Current weight 0..1 (after the fade).
var weight := 0.0
## [{anim: Animation, time: float, w: float, mirror: bool (optional), part: "hand" / "arm" (optional)}]: the clips
## to take the arm from.
var sources: Array = []
## What `sources` shows ("" = unnamed); see set_sources().
var source_key := ""

var _lin := 0.0
var _ids := PackedInt32Array()
var _names := PackedStringArray()
var _mirror_names := PackedStringArray()   ## the other side's bone of each (mirrored sources)
var _is_arm: Array[bool] = []               ## clavicle .. wrist (not the palm or a finger)
var _tracks := {}     ## Animation -> {bone name: rotation track index (-1: none)}
var _last := {}       ## bone index -> the source pose shown last frame (Quaternion)
var _from := {}       ## bone index -> the pose a source change cross-fades from
var _xf := 1.0        ## cross-fade progress 0..1 (1 = done)
var _xf_s := SOURCE_XFADE_S
var _shown := {}      ## bone index -> the arm's rotation after this modifier last frame (the tree's while off)


## Sets the sources and names what they show; a new key while the arm is shown cross-fades from the pose
## shown last to the new sources over `xfade_s`.
func set_sources(key: String, p_sources: Array, xfade_s := SOURCE_XFADE_S) -> void:
	if key != source_key:
		source_key = key
		_xf_s = maxf(xfade_s, 1e-3)
		if weight > 0.0 and not _last.is_empty():
			_from = _last.duplicate()
			_xf = 0.0
		else:
			_from = {}
			_xf = 1.0
	sources = p_sources


func advance(dt: float) -> void:
	_lin = move_toward(_lin, 1.0 if enabled else 0.0, dt / maxf(fade_s, 1e-3))
	weight = smoothstep(0.0, 1.0, _lin)
	_xf = move_toward(_xf, 1.0, dt / _xf_s)
	if weight <= 0.0:
		_last = {}


## Comes in at full weight at once and cross-fades over `xfade_s` from the arm as it was shown at this
## modifier's place last frame (after it; the tree's arm while it was off) to the sources, instead of fading
## in over the tree's pose of this frame: where that pose snaps (a jump's take-off drops the carry's arm
## layer), a fade shows the snap and then pulls the arm back. Call after set_sources(). No effect while the
## arm is fully in (a new key cross-fades by itself) or before it has run once.
func take_over(xfade_s: float) -> void:
	if _lin >= 1.0 or _shown.is_empty():
		return
	_lin = 1.0
	weight = 1.0
	_from = _shown.duplicate()
	_xf = 0.0
	_xf_s = maxf(xfade_s, 1e-3)


## Takes the wanted weight at once (no fade, no cross-fade).
func snap() -> void:
	_lin = 1.0 if enabled else 0.0
	weight = _lin
	_xf = 1.0
	_from = {}
	if weight <= 0.0:
		_last = {}


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if _ids.is_empty():
		var pre := side + "_"
		for i in sk.get_bone_count():
			var n := sk.get_bone_name(i)
			var keep := n.begins_with(pre) and n.substr(2) in ARM
			if not keep and n.begins_with(pre) and not n.contains("helper") and not n.contains("twist") \
					and not n.contains("prop"):
				for k: String in FINGER_KEYS:
					if n.substr(2).begins_with(k):
						keep = true
						break
			if keep:
				_ids.append(i)
				_names.append(n)
				_mirror_names.append(("r_" if side == "l" else "l_") + n.substr(2))
				_is_arm.append(n.substr(2) in ARM)
	if weight <= 0.0 or sources.is_empty():
		# (the arm as shown here, for take_over())
		for b in _ids:
			_shown[b] = sk.get_bone_pose_rotation(b)
		return
	for k in _ids.size():
		var q := Quaternion.IDENTITY
		var total := 0.0
		for s: Dictionary in sources:
			var part := String(s.get("part", ""))
			if (part == "hand" and _is_arm[k]) or (part == "arm" and not _is_arm[k]):
				continue
			var anim: Animation = s.anim
			var mirror := bool(s.get("mirror", false))
			var ti := _track(anim, _mirror_names[k] if mirror else _names[k])
			if ti < 0:
				continue
			var w := float(s.w)
			if w <= 0.0:
				continue
			var qs := anim.rotation_track_interpolate(ti, float(s.time))
			if mirror and _names[k].ends_with("clavicle"):
				qs = MIRROR_CLAVICLE * qs
			if total <= 0.0:
				q = qs
				total = w
			else:
				total += w
				q = q.slerp(qs, w / total)
		var b := _ids[k]
		if total <= 0.0:
			_shown[b] = sk.get_bone_pose_rotation(b)
			continue
		if _xf < 1.0 and _from.has(b):
			q = (_from[b] as Quaternion).slerp(q, smoothstep(0.0, 1.0, _xf))
		_last[b] = q
		var out := sk.get_bone_pose_rotation(b).slerp(q, weight).normalized()
		_shown[b] = out
		sk.set_bone_pose_rotation(b, out)


func _track(anim: Animation, bone: String) -> int:
	if not _tracks.has(anim):
		var m := {}
		for t in anim.get_track_count():
			if anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
				m[String(anim.track_get_path(t)).get_slice(":", 1)] = t
		_tracks[anim] = m
	return int((_tracks[anim] as Dictionary).get(bone, -1))
