class_name TravPreviewActor
extends Node3D
## Standalone traversal preview (design 17, TW0): an Actor_B instance that plays what the
## TraversalController publishes, without the rebuilt LocoBrain / TreeBuilder. It implements the
## seam rules the rebuilt animation system must follow (hooks, traversal_source_moves.md):
##
##  - Crossfades with the graph's fades: a fade stack of 4 contents in an AnimationTree (the
##    clocks of design 10.1: the incoming content is SEEKED to the controller's move time, the
##    outgoing ones keep their own clocks until the incoming one is fully in; a fade that starts
##    during another fade blends over it instead of dropping the older content).
##  - Inertialization (TravInertializer, user complaint 2026-09-24 "snapping / teleporting"):
##      * every content switch inertializes the ROOT (position, velocity, yaw, yaw rate);
##      * a PART JOIN inside a move (the graph's 0 s joins) keeps the running entry fade on the
##        new part's clip and inertializes the pose and the root over the same time; the path's
##        root carries the opposite of the clip's root-bone jump (the world body is continuous),
##        so the two offsets cancel, and the joins neither pop nor cut the fade (planted hands
##        and feet are held by TraversalIK);
##      * a switch whose outgoing clip has ENDED (a chained segment, a ladder cycle, an exit, a
##        drop's clip into the fall loop) or that has no fade is an instant switch with pose
##        inertialization: a crossfade would blend in the finished clip's frozen last frame;
##      * a landing (AIR -> landing clip) is inertialized too (the fall's arm swing decays);
##      * other switches (locomotion into a move) crossfade with the graph's fade, except a move
##        whose entry asks for inertialization (traversal_moves.json fade_in.inertialize: the
##        squeeze, whose root bone starts 0.63 m from the walk's): pose and root over the same time.
##  - Locomotion phase: on the approach to a planned move the loop's phase is steered (rate within
##    +-25 %) to the phase whose pose is closest to the move's first pose (traversal_runtime.json
##    loco_match.entry); after a hand-back the loop starts at the phase closest to the move's last
##    pose (loco_match.exit).
##  - Skeleton order: animation -> TravInertializer -> TraversalIK -> CharacterBodyMesh (last).
##
##   var actor := TravPreviewActor.new(); add_child(actor); actor.build()
##   actor.show_state(controller.anim_state(), body, delta)       # every physics tick
##   actor.teleport()                                              # after placing the body elsewhere

const RIG := "res://characters/Actor_B.tscn"
const LIB := &"actor_b"
const INERT_JOIN_S := 0.2        ## pose (and root) inertialization at a part join / instant switch (at least)
const INERT_LAND_S := 0.15       ## landing (AIR -> landing clip)
const ROOT_MIN_S := 0.2          ## root inertialization (at least)
const LAND_CARRY := 0.25         ## landing: share of the fall's root velocity that follows through
## ... of its vertical velocity: none (fix round 3, 2026-09-25: carried at 0.5 over a root time
## shorter than the pose's, the root sank faster than the fall's extended legs drew in and the
## landing's feet went 10 cm under the ground before the IK; the landing clips compress themselves).
const LAND_CARRY_V := 0.0
const ENDED_INERT_MAX_S := 0.3   ## a fade out of an ended clip up to this long is inertialized instead
const TURN_RATE_MAX := 9.0       ## rad/s: the preview's locomotion facing turns at most this fast
## The landing's root offset decays over the same time as its pose offset (they cancel: the falling
## pose was lifted so its soles meet the ground, see show_state).
const LAND_ROOT_S := INERT_LAND_S

var fades := true
## Entries from locomotion into a move: pose inertialization over the graph's fade (true) or a
## crossfade (false, the default: measured on the 20 routes 2026-09-24, inertialized entries
## popped more hands than the crossfade: the vault and long jump entries swing the arms through
## the decaying offset, 13 route failures against 11).
var entry_inertialize := false
## Optional: the clips' key-reduced tracks (about 10 keys a second, linear) played with cubic
## interpolation (TravInertializer.smooth_clip_tracks()). Off: the runtime table's references and
## the test's natural maxima were measured with the clips as stored (linear); with it on, the
## 10 Hz velocity kinks go (the tall vault's entry "pop" at its 0.2 s key), but the contacts drift
## from their references by a few mm to 2 cm (checked 2026-09-24: 14 route failures, from 13).
## null = the runtime table's settings.clip_interpolation ("cubic" -> on).
var smooth_keys: Variant = null
var use_body_mesh := true
var ik_enabled := true
var rig: Node3D
var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var tree: AnimationTree
var ik: TraversalIK
var inert: TravInertializer
var body_mesh: CharacterBodyMesh
var lib: TravMoveLibrary
var last := {}                  ## the last applied content {clip, t, key, w_in, stack, switch}
var pending_plan: TravMovePlan  ## set by the runner: the controller's planned move (phase sync)
var approach := {}              ## set by the runner: controller.approach() (facing on the approach)
var loco_rate := 1.0
## The move clock's rate of the content being shown (TravMomentum: a vault entered faster than its clip
## runs its clock faster, TraversalController anim_state "rate"): the move's fades, inertializations
## and plant ramps are times of the move's clock, so they run 1 / time_scale as long in real time (at
## least TIME_SCALED_MIN_S); a 0.2 s entry at 3x otherwise spanned the first 0.6 s of the move, the
## hand plant included, with the plants still ramping in.
var time_scale := 1.0
const TIME_SCALED_MIN_S := 0.06

var _stack: Array = []           ## fade stack, oldest first: {clip, t, rate, loop, fade, w_t, key}
var _slot_clip := ["", "", "", ""]
var _key := ""
var _loco_phase := 0.0
var _loco_clip := ""
var _yaw := 0.0
var _inc_w := 1.0                       ## incoming weight of the running fade (1 when none)
var _ramp_t := 1.0                      ## time since the last entry switch (pins ramp in over _ramp_len)
var _fade_pins: Array = []              ## the plants of the content before, fading out over the ramp
var _ramp_len := 0.0
var _entry_fade := false
var _move_key := ""
var _last_exit_key := ""
const EXIT_MOVING_INERT_S := 0.3
const AIR_LIFT_DROP_V := 0.8
const AIR_CUSHION_M := 0.08
const CUSHION_V := 6.0
var _join_contact := false
var _landing_now := false
const JOIN_CONTACT_INERT_S := 0.1
var _legs := PackedInt32Array()

## The leg bones (their velocity is not carried at a part join where a foot comes down).
func _leg_bones() -> Array:
	if _legs.is_empty() and skeleton != null:
		for side in ["l_", "r_"]:
			for bn in ["upper_leg", "knee", "ankle", "heel", "ball"]:
				var b := skeleton.find_bone(side + bn)
				if b >= 0:
					_legs.append(b)
	return Array(_legs)
var _loco_key := ""
var _last_mode := "OFF"
var _loco_gait := ""
var _air_lift := 0.0                     ## the falling pose's lift (see show_state)
var _air_root_y := 0.0
const GAIT_LOOPS := ["walk", "run", "sprint"]


func build() -> void:
	lib = TravMoveLibrary.shared()
	rig = (load(RIG) as PackedScene).instantiate() as Node3D
	rig.name = "Actor_B"
	add_child(rig)
	skeleton = rig.find_children("*", "Skeleton3D", true, false)[0]
	anim_player = rig.find_children("*", "AnimationPlayer", true, false)[0]
	anim_player.stop()
	BindRest.ensure(skeleton, anim_player, LIB)
	_add_own_libraries()
	anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if use_body_mesh:
		body_mesh = CharacterBodyMesh.attach(skeleton, anim_player)
		if body_mesh == null:
			var mq := BoneMannequin.new()
			rig.add_child(mq)
			mq.build(skeleton)
	inert = TravInertializer.new()
	inert.name = "TravInertializer"
	skeleton.add_child(inert)
	var names := PackedStringArray()
	for c in lib.clips():
		names.append(_anim_name(c))
	inert.set_bones_from_clips(skeleton, anim_player, names)
	if smooth_keys == null:
		smooth_keys = str(lib.setting("clip_interpolation", "linear")) == "cubic"
	if bool(smooth_keys):
		TravInertializer.smooth_clip_tracks(anim_player, names)
	else:
		# The moves that opt in (traversal_runtime.json move clip_interpolation "cubic": the table
		# was sampled that way).
		var cub := PackedStringArray()
		var her := PackedStringArray()
		for id: String in lib.moves:
			var ci := str((lib.moves[id] as Dictionary).get("clip_interpolation", ""))
			if ci == "cubic" or ci == "hermite":
				for p: Dictionary in (lib.moves[id] as Dictionary).get("parts", []):
					(cub if ci == "cubic" else her).append(_anim_name(str(p.clip)))
		if not cub.is_empty():
			TravInertializer.smooth_clip_tracks(anim_player, cub)
		# (clip_interpolation "hermite": the landing clips, resampled velocity-continuous through
		# their keys, TravInertializer.resample_hermite.)
		if not her.is_empty():
			TravInertializer.resample_player_hermite(anim_player, her)
	TravMomentum.measure(lib, anim_player, str(LIB) + "/", skeleton)
	ik = TraversalIK.new()
	ik.name = "TraversalIK"
	skeleton.add_child(ik)       # CharacterBodyMesh moves itself behind both (it stays last)
	if fades:
		_build_tree()


## fades off: the AnimationPlayer is seeked directly (exact clip pose, no blending).
func set_fades(on: bool) -> void:
	fades = on
	if on and tree == null:
		_build_tree()
	if tree:
		tree.active = on
	if not on:
		anim_player.active = true


## The body was placed elsewhere (a station, a respawn): no inertialization from the old place.
func teleport(yaw := NAN) -> void:
	if inert:
		inert.reset()
		inert.root_reset(rig.global_transform if rig else Transform3D.IDENTITY)
	if ik:
		ik.reset()
	_stack.clear()
	_key = ""
	# A fresh start (the course's stations: every route starts the same way, whatever ran before).
	_loco_phase = 0.0
	_loco_clip = ""
	_loco_gait = ""
	_move_key = ""
	_ramp_t = 1.0
	_ramp_len = 0.0
	_fade_pins = []
	_last_mode = "OFF"
	if not is_nan(yaw):
		_yaw = yaw


const SLOTS := 4


## A fade stack of SLOTS contents (oldest first) chained through Blend2 nodes: a content that
## arrives while an older fade is still running fades in over the current blend instead of
## dropping the older content in one frame.
func _build_tree() -> void:
	var bt := AnimationNodeBlendTree.new()
	for i in SLOTS:
		var an := AnimationNodeAnimation.new()
		bt.add_node("anim%d" % i, an)
		var sk := AnimationNodeTimeSeek.new()
		bt.add_node("seek%d" % i, sk)
		bt.connect_node("seek%d" % i, 0, "anim%d" % i)
	var prev := "seek0"
	for i in range(1, SLOTS):
		var bl := AnimationNodeBlend2.new()
		bt.add_node("blend%d" % i, bl)
		bt.connect_node("blend%d" % i, 0, prev)
		bt.connect_node("blend%d" % i, 1, "seek%d" % i)
		prev = "blend%d" % i
	bt.connect_node("output", 0, prev)
	tree = AnimationTree.new()
	tree.name = "PreviewTree"
	tree.tree_root = bt
	rig.add_child(tree)
	tree.anim_player = tree.get_path_to(anim_player)
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.active = true


func _anim_name(clip: String) -> String:
	var own := TravPreviewActor.own_clips()
	if not own.is_empty() and (own.get("clips", {}) as Dictionary).has(clip):
		return String(own.clips[clip])
	return str(LIB) + "/" + clip


## Our own authored traversal clips in place of the source's (tools/anim_author/blender/install_traversal.gd writes OWN_CLIPS): on by
## default (user 2026-09-30: "lets use ours"); the user argument --source-traversal plays the source clips instead. {libraries: {name: path}, clips: {source clip:
## "library/clip"}}; the moves' timing, world paths and contact windows stay the table's (the clips are authored on them).
const OWN_CLIPS := "res://data/anim_author/traversal_clips.json"
static var _own: Dictionary = {}
static var _own_read := false


static func own_clips() -> Dictionary:
	if not _own_read:
		_own_read = true
		if not ("--source-traversal" in OS.get_cmdline_user_args()) and FileAccess.file_exists(OWN_CLIPS):
			_own = JSON.parse_string(FileAccess.get_file_as_string(OWN_CLIPS))
	return _own


## Adds the own clips' libraries to the AnimationPlayer the moves play on (unless --source-traversal), and the mirrored moves' clips.
func _add_own_libraries() -> void:
	var own := TravPreviewActor.own_clips()
	for name: String in own.get("libraries", {}):
		if not anim_player.has_animation_library(name):
			anim_player.add_animation_library(name, load(String(own.libraries[name])) as AnimationLibrary)
	# and the mirrored moves' clips (TravMoveMirror), from whatever plays for the originals
	TravMoveMirror.ensure_clips(anim_player, skeleton, lib, _anim_name, LIB)


func _set_slot_clip(slot: int, clip: String) -> void:
	if _slot_clip[slot] == clip:
		return
	_slot_clip[slot] = clip
	var an := (tree.tree_root as AnimationNodeBlendTree).get_node("anim%d" % slot) as AnimationNodeAnimation
	an.animation = StringName(_anim_name(clip))


## "move:serial" of a move content key "move:serial:part" ("" for other keys: locomotion, air,
## exit and lane keys never join).
static func _move_prefix(key: String) -> String:
	var s := key.split(":")
	if s.size() != 3 or s[0] in ["loco", "air", "exit", "graph"] or not s[1].is_valid_int() or not s[2].is_valid_int():
		return ""
	return s[0] + ":" + s[1]


## Plays `clip` at clip time `t` on the rig transform `root`. A new `key` is a content switch:
##   part join (same move and serial, next part): the top slot's clip is replaced in place (a
##     running entry fade continues), the pose and the root are inertialized over the same time;
##   instant switch (fade 0, pose_fade 0, or the outgoing clip has ended): pose inertialization
##     over max(fade, INERT_JOIN_S) and root inertialization;
##   otherwise a crossfade of `fade` seconds (the older contents keep their clocks) and root
##     inertialization.
## `inert_s` > 0 forces an instant switch with that inertialization time.
func play_content(clip: String, t: float, key: String, fade: float, root: Transform3D, rate := 1.0, delta := 0.0, looped := false,
		root_vel := Vector3.ZERO, pose_fade := -1.0, inert_s := 0.0, root_carry := 1.0, root_s := -1.0, root_carry_v := -1.0) -> void:
	if clip == "":
		return
	var a := anim_player.get_animation(_anim_name(clip))
	if a == null:
		push_warning("TravPreviewActor: missing clip " + clip)
		return
	t = clampf(t, 0.0, a.length)
	var k_ts := 1.0 / maxf(time_scale, 1.0)
	var join_s := maxf(INERT_JOIN_S * k_ts, TIME_SCALED_MIN_S)
	var root_min_s := maxf(ROOT_MIN_S * k_ts, TIME_SCALED_MIN_S)
	var contact_s := maxf(JOIN_CONTACT_INERT_S * k_ts, TIME_SCALED_MIN_S)
	var new_key := key != _key
	var switch := ""
	if new_key:
		var old_key := _key
		_key = key
		var mk := _move_prefix(key)
		var part_join := mk != "" and mk == _move_prefix(old_key) and not _stack.is_empty()
		# Plants scale with the incoming weight when new content comes in (not at part seams), while
		# the plants of the content before fade out (below: the IK targets crossfade; a planted
		# foot released in one frame at the beam enter -> loop switch threw the knee 7.7 cm).
		var mkey := mk if mk != "" else key
		_entry_fade = mkey != _move_key
		_move_key = mkey
		# The outgoing clip ends before the fade would be over (a chained segment switches on the
		# tick its clip ends): a crossfade would hold its frozen last frame.
		var top: Dictionary = _stack[_stack.size() - 1] if not _stack.is_empty() else {}
		var ended := false
		if not top.is_empty() and not bool(top.loop):
			var ao := anim_player.get_animation(_anim_name(str(top.clip)))
			ended = ao != null and float(top.t) + maxf(fade, delta) * float(top.rate) >= ao.length - 1e-3
		if _stack.is_empty():
			switch = "first"
			inert.root_reset(root)
		elif part_join:
			switch = "join"
		elif inert_s > 0.0 or pose_fade == 0.0 or fade <= 0.0 or (ended and fade <= ENDED_INERT_MAX_S) \
				or (entry_inertialize and mk != "" and old_key.begins_with("loco:")):
			# (An entry from locomotion into a move is inertialized over the graph's fade as well:
			# the move's own pose shows at once, e.g. a standing mantle's hands reaching over the
			# top, instead of a blend that drags them down along the walking arm; the offsets of
			# the old pose and its velocity decay; seam fix 2026-09-24.)
			# (A long graph fade out of a finished clip, the shimmy's 0.5 s stop -> exit, stays a
			# crossfade of the graph: its last pose is a rest pose, and a long inertialization of
			# a 90 deg turn bends the legs through odd poses.)
			switch = "inertialize"
		else:
			switch = "crossfade"
		if _entry_fade and switch in ["inertialize", "crossfade"]:
			# The new content's plants apply in proportion while its pose is still coming in (a
			# full correction of a half-blended or inertialized pose would jerk): over the fade,
			# or over the inertialization.
			_fade_pins = []
			if ik:
				for p0: Dictionary in ik.pins:
					if float(p0.get("weight", 0.0)) > 0.0:
						_fade_pins.append(p0.duplicate())
			_ramp_t = 0.0
			_ramp_len = fade if switch == "crossfade" else maxf(maxf(fade, inert_s), join_s)
			# (A landing's plants come in over the landing's own inertialization: over 0.2 s the stance
			# foot was not held yet while the fall pose's offset slid it the last 5 cm; fix round 3. The
			# soft landing into a run keeps the longer ramp: its first plant is a 0.08 s touch, pressed
			# 1 cm into the ground at full weight.)
			if _landing_now and not key.begins_with("land_soft"):
				_ramp_len = maxf(fade, inert_s)
		match switch:
			"join":
				# Same slot, same fade weight: a part join inside a running entry fade must not cut
				# the fade (the long jump's 0.1 s first part: a 45 cm palm pop at 172 rad/s).
				# The pose and the root are inertialized over the SAME time. The move's path is
				# built for its joins: the root carries the opposite of the clip's root-bone jump
				# (position and velocity), so the WORLD body is continuous across the join (the
				# table's part joins, TravMotionWarper._rise_catch; _smooth_root smooths the world
				# pelvis and keeps that compensation exact). Then the two offsets cancel and the
				# body follows the path; where the path itself bends at the join (a take-off right
				# after it) the carried velocity smooths the bend over the inertialization. (With
				# the ROOT low-passed the compensation was spread over the filter and the offsets
				# did not cancel: the 3 m climb's body rose 17 cm too little after the begin -> mid
				# join and 23 cm too high after the mid -> end join.)
				top.clip = clip
				top.t = t
				top.rate = rate
				top.loop = looped
				top.key = key
				# (A join where a foot comes down: over JOIN_CONTACT_INERT_S, the legs' velocity not
				# carried; over 0.2 s the interpolated leg took the landing foot 6-10 cm into the
				# ground, the standing vault's and the gap jump's landings; fix round 3.)
				var tj := maxf(maxf(fade, inert_s), join_s) if not _join_contact else maxf(inert_s, contact_s)
				inert.start(tj, TravInertializer.FULL, _leg_bones() if _join_contact else [])
				inert.root_transition(root, root_vel, tj, delta)
			"inertialize":
				_stack.append({"clip": clip, "t": t, "rate": rate, "loop": looped, "fade": 0.0, "w_t": 0.0, "key": key})
				inert.start(maxf(maxf(fade, inert_s), join_s))
				inert.root_transition(root, root_vel, root_s if root_s > 0.0 else maxf(fade, root_min_s), delta, root_carry, root_carry_v)
			"crossfade":
				_stack.append({"clip": clip, "t": t, "rate": rate, "loop": looped, "fade": fade, "w_t": 0.0, "key": key})
				inert.root_transition(root, root_vel, maxf(fade, root_min_s), delta, root_carry)
			"first":
				_stack.append({"clip": clip, "t": t, "rate": rate, "loop": looped, "fade": 0.0, "w_t": 0.0, "key": key})
		if _stack.size() > SLOTS:
			# The oldest content leaves the tree in one frame: inertialize the pose over it.
			while _stack.size() > SLOTS:
				_stack.pop_front()
			if switch == "crossfade":
				inert.start(join_s)
	if not new_key:
		_ramp_t += delta
	if not fades:
		if anim_player.current_animation != _anim_name(clip):
			anim_player.play(_anim_name(clip), 0.0)
		anim_player.seek(t, true, true)
		_inc_w = 1.0
		rig.global_transform = inert.root_place(root, delta)
		last = {"clip": clip, "t": t, "key": key, "switch": switch}
		return
	# Older contents advance on their own clocks (design 10.1); the top one is the new content.
	for i in _stack.size() - 1:
		var e: Dictionary = _stack[i]
		var ao := anim_player.get_animation(_anim_name(str(e.clip)))
		e.t = fposmod(float(e.t) + delta * float(e.rate), ao.length) if bool(e.loop) else minf(float(e.t) + delta * float(e.rate), ao.length)
		e.w_t = float(e.w_t) + delta
	var top2: Dictionary = _stack[_stack.size() - 1]
	if not new_key or switch == "join":
		top2.w_t = float(top2.w_t) + delta
	top2.clip = clip
	top2.t = t
	top2.rate = rate
	top2.loop = looped
	var ws := []
	for e: Dictionary in _stack:
		ws.append(1.0 if float(e.fade) <= 0.0 else smoothstep(0.0, 1.0, clampf(float(e.w_t) / float(e.fade), 0.0, 1.0)))
	# Drop what the newest fully-in content covers.
	var k := ws.size() - 1
	while k > 0 and float(ws[k]) < 1.0:
		k -= 1
	if k > 0:
		_stack = _stack.slice(k)
		ws = ws.slice(k)
	for i in SLOTS:
		var e: Dictionary = _stack[mini(i, _stack.size() - 1)]
		_set_slot_clip(i, str(e.clip))
		tree.set("parameters/seek%d/seek_request" % i, float(e.t))
		if i > 0:
			tree.set("parameters/blend%d/blend_amount" % i, float(ws[i]) if i < _stack.size() else 0.0)
	tree.advance(0.0)
	_inc_w = float(ws[ws.size() - 1])
	rig.global_transform = inert.root_place(root, delta)
	last = {"clip": clip, "t": t, "key": key, "w_in": _inc_w, "stack": _stack.size(), "switch": switch if new_key else ""}


## Heading of a (yaw-only) basis; Basis.get_euler() is unreliable at 180 deg.
static func yaw_of(b: Basis) -> float:
	return TravInertializer.yaw_of(b)


## One preview step from the controller's anim_state (or locomotion when it is OFF).
func show_state(st: Dictionary, body: CharacterBody3D, delta: float) -> void:
	global_transform = Transform3D.IDENTITY
	var mode := str(st.get("mode", "OFF"))
	var was := _last_mode
	_last_mode = mode
	if mode != "OFF" and st.has("clip") and str(st.clip) != "":
		var root: Transform3D = st.root
		_yaw = yaw_of(root.basis)
		# A falling body close to the ground: its pose is lifted so the lowest sole (measured by the
		# IK last frame, before its corrections) stays on the ground, instead of reaching it 2-9 cm
		# before the capsule and being inertialized into the landing from under the ground (fix
		# round 3: the soft landing's feet 3 cm under the ground, held out by the guard). The
		# landing's root inertialization takes the lift out.
		if mode == "AIR" and (st.has("ground_below") or _air_lift > 0.0) and ik != null:
			ik.measure_soles = true
			# (A lift that is no longer needed goes at AIR_LIFT_DROP_V, not in one frame: stepping
			# off a branch's end, the ground under the body fell away by 2.9 m and the 15 cm lift
			# over the branch dropped the pelvis in one frame; fix round 3.)
			var want_lift := 0.0
			if st.has("ground_below") and ik.sole_min_y < INF:
				var rel := ik.sole_min_y - _air_root_y
				# (A soft contact after a high fall: over the last AIR_CUSHION_M the soles decelerate onto
				# the ground instead of stopping on it in one frame: off a 2.9 m branch the feet met the
				# ground at 7.5 m/s, a 5.2 cm one-frame jump of the ball at the landing. Only above
				# CUSHION_V: at the tall vault's fall exit it lifted a body just leaving the wall's top.)
				var hh := (root.origin.y + rel) - float(st.ground_below)
				var vy := (st.get("root_vel", Vector3.ZERO) as Vector3).y
				var c := AIR_CUSHION_M * clampf(-vy - CUSHION_V, 0.0, 1.0)
				var shown := hh if hh >= c else (0.0 if hh <= -c else (hh + c) * (hh + c) / (4.0 * c))
				want_lift = maxf(0.0, shown - hh)
			_air_lift = maxf(want_lift, _air_lift - AIR_LIFT_DROP_V * delta)
			root.origin.y += _air_lift
			_air_root_y = root.origin.y
		else:
			if ik != null:
				ik.measure_soles = false
			_air_lift = 0.0
		# A landing: the fall's pose is inertialized into the landing clip (an impact, not a blend
		# of two held poses).
		var inert_s := 0.0
		var carry := 1.0
		var carry_v := -1.0
		var root_s := -1.0
		if was == "AIR" and mode != "AIR":
			# An impact: the feet stop, the body follows through a little (a quarter of the fall's
			# velocity, over 0.1 s) instead of stopping dead in one frame or carrying the whole
			# momentum past the landing pose and back; a landing clip that runs on as fast as the
			# body came in (the soft landing into a run) keeps the horizontal momentum.
			inert_s = INERT_LAND_S
			var rv: Vector3 = st.get("root_vel", Vector3.ZERO)
			var bv := inert.root_velocity()
			var runs_on := Vector2(rv.x, rv.z).length() > 0.5 * Vector2(bv.x, bv.z).length()
			carry = 1.0 if runs_on else LAND_CARRY
			carry_v = LAND_CARRY_V
			root_s = LAND_ROOT_S
			_landing_now = true
		elif st.has("inertialize"):
			# The pose and the root over the same time (their offsets cancel where the clip's root
			# bone stands away from its align: the squeeze's entry, traversal_moves.json).
			inert_s = float(st.get("inertialize_real", st.inertialize))
			root_s = inert_s
		_join_contact = bool(st.get("join_contact", false))
		# (A move on a faster clock: its fades in move time, see time_scale.)
		time_scale = maxf(float(st.get("rate", 1.0)), 1.0)
		var fast_entry := time_scale > 1.0 and int(st.get("part", -1)) == 0 and was == "OFF" and not entry_inertialize
		if fast_entry:
			# (A crossfaded entry does not carry the locomotion's root velocity: the move's clock is set to
			# the body's speed at its pelvis, whose own root starts slower (the sprint vault's first pose
			# stands 14 cm behind its align); carried, the root ran 3 m/s ahead of its path and put the
			# hands 10-15 cm into the wall's top edge. The root's offset decays with the blend. An
			# inertialized entry, the player's, keeps it: the pose's offsets decay from the same motion.)
			carry = 0.0
		var k_ts := 1.0 / time_scale
		var fade_c := float(st.get("fade_s", 0.1))
		if time_scale > 1.0:
			# (the content's fade as the real time its move-time window takes, TraversalController)
			if st.has("fade_real") and fade_c > 0.0:
				fade_c = maxf(float(st.fade_real), TIME_SCALED_MIN_S)
			else:
				fade_c = maxf(fade_c * k_ts, TIME_SCALED_MIN_S) if fade_c > 0.0 else 0.0
			if not st.has("inertialize_real"):
				inert_s = maxf(inert_s * k_ts, TIME_SCALED_MIN_S) if inert_s > 0.0 else 0.0
				root_s = maxf(root_s * k_ts, TIME_SCALED_MIN_S) if root_s > 0.0 else root_s

		play_content(str(st.clip), float(st.clip_t), str(st.get("key", "")), fade_c, root, time_scale, delta,
				str(st.get("key", "")).begins_with("loco:") or bool(st.get("loop", false)), st.get("root_vel", Vector3.ZERO), -1.0, inert_s, carry, root_s, carry_v)
		_landing_now = false
		# The plants correct the move's pose: while it is still fading in over the previous
		# content they apply in proportion (a full correction of a half-blended pose would jerk).
		var pins: Array = []
		var pw := smoothstep(0.0, 1.0, _ramp_t / _ramp_len) if _entry_fade and _ramp_len > 0.0 else 1.0
		# A content whose plants continue the ones before (the ladder lane's clip switches: a hand or
		# foot held across the join stays held, one that the next clip moves is released by its own
		# windows; crossfaded, an old plant dragged a foot the new clip lifted: a 5 cm knee pop).
		if bool(st.get("pins_continue", false)):
			pw = 1.0
			_fade_pins = []
		for p0: Dictionary in st.get("pins", []):
			var q := p0.duplicate()
			q.weight = float(q.get("weight", 1.0)) * pw
			pins.append(q)
		# ... while the plants of the content before fade out the same way (the IK targets
		# crossfade: dropped at once, a foot's 5 cm correction threw the knee 10 cm at a ladder's
		# cycle -> hub switch).
		if pw < 1.0:
			for p1: Dictionary in _fade_pins:
				var q1 := p1.duplicate()
				q1.weight = float(q1.get("weight", 1.0)) * (1.0 - pw)
				if float(q1.weight) > 0.0:
					pins.append(q1)
		elif not _fade_pins.is_empty():
			_fade_pins = []
		_apply_ik(pins, st.get("guards", []))
		return
	# Locomotion / air: loops at a speed-matched rate, facing the velocity (or, stopping on the
	# approach to a move, turning to the move's facing).
	time_scale = 1.0
	var v := body.velocity
	var speed := Vector2(v.x, v.z).length()
	# (The facing turns at most TURN_RATE_MAX: a 180 deg turn after the ladder's bottom exit
	# spun every bone at 37 rad/s.)
	if speed > 0.3:
		_yaw = _turn_toward(_yaw, atan2(v.x, v.z), 12.0, delta)
	if approach.has("yaw") and float(approach.get("dist", INF)) < 1.2:
		_yaw = _turn_toward(_yaw, float(approach.yaw), 6.0, delta)
	var loco := "idle"
	if not body.is_on_floor() and v.y < -1.0:
		loco = "fall"
	elif speed > 4.2:
		loco = "sprint"
	elif speed > 2.2 or (speed > 1.8 and approach.has("speed") and float(approach.speed) > 1.8):
		# (On the approach to a move entered at a jog, e.g. the sprint vault's 2.4 m/s, the run
		# loop is kept down to the entry speed: a walk right before a sprint vault read as a stop.)
		loco = "run"
	elif speed > 0.4:
		loco = "walk"
	var ld: Dictionary = lib.loco.get(loco, lib.loco.get("idle", {}))
	var clip := str(ld.get("clip", "actor_b-p-relax-idle"))
	var bank := float(ld.get("bank_speed", 0.0))
	var a := anim_player.get_animation(_anim_name(clip))
	if a == null:
		return
	var r := speed / bank if bank > 0.1 else 1.0
	var ex: Dictionary = st.get("exit", {})
	var fade := 0.2
	var inert_s := 0.0
	var ek := str(st.get("key", ""))
	if ek.begins_with("exit:") and ek != _last_exit_key:
		# After a hand-back: the graph's exit fade, the loop at the phase closest to the move's
		# last pose.
		_last_exit_key = ek
		_loco_key = ek
		_loco_clip = clip
		_loco_gait = loco
		var lm: Dictionary = (ex.get("loco_match", {}) as Dictionary).get(loco, {})
		if not lm.is_empty():
			_loco_phase = float(lm.phase) * a.length
		fade = float(ex.get("fade_s", 0.2))
		# (Into a moving loop, at most EXIT_MOVING_INERT_S: the ladder top's 0.6 s graph fade into a
		# run left the offset of the mismatched pose decaying over three run stances, every planted
		# foot sliding 5-10 cm under it; fix round 3.)
		if speed > 0.5:
			fade = minf(fade, EXIT_MOVING_INERT_S)
		# The move's clip has ended: a crossfade would blend in its frozen last frame (the body's
		# motion stops for a frame); the pose is inertialized instead (offset and velocity of
		# every bone decay over the exit fade), the root keeps its own inertialization.
		if str(ex.get("exit", "")) != "fall":
			inert_s = fade
	elif clip != _loco_clip:
		# A gait change keeps the gait's normalized phase (the same foot forward): carried in
		# seconds, a run -> sprint crossfade blended two different strides (a 7 cm knee pop).
		var old_a := anim_player.get_animation(_anim_name(_loco_clip)) if _loco_clip != "" else null
		if old_a != null and old_a.length > 0.0 and _loco_gait in GAIT_LOOPS and loco in GAIT_LOOPS:
			_loco_phase = fposmod(_loco_phase / old_a.length, 1.0) * a.length
		else:
			_loco_phase = fposmod(_loco_phase, a.length)
		_loco_clip = clip
		_loco_gait = loco
		_loco_key = "loco:%s:%d" % [loco, Time.get_ticks_usec()]
	if _key == _loco_key:
		fade = 0.2
	var key := _loco_key
	# On the approach to a planned move: steer the phase to the move's entry phase.
	r *= _phase_sync(loco, a, body, speed)
	loco_rate = r
	_loco_phase = fposmod(_loco_phase + delta * r, a.length)
	# (A body stopped dead by a wall, the tree stand's trunk: the rendered root does not carry its
	# old velocity on into the wall; carried, it overshot the stopped capsule 21 cm into the trunk.)
	var carry_l := 0.0 if body.is_on_wall() else 1.0
	play_content(clip, _loco_phase, key, fade, Transform3D(Basis(Vector3.UP, _yaw), body.global_position), r, delta, true,
			Vector3(v.x, 0.0 if body.is_on_floor() else v.y, v.z), -1.0, inert_s, carry_l)
	_apply_ik(st.get("pins", []), st.get("guards", []))


static func _turn_toward(yaw: float, target: float, rate: float, delta: float) -> float:
	var d := wrapf(target - yaw, -PI, PI) * clampf(rate * delta, 0.0, 1.0)
	var lim := TURN_RATE_MAX * delta
	return yaw + clampf(d, -lim, lim)


## Rate factor (0.75-1.25) that brings the loop's phase to the pending move's entry phase when
## the body reaches its start point.
func _phase_sync(loco: String, a: Animation, body: CharacterBody3D, speed: float) -> float:
	if pending_plan == null or pending_plan.move.is_empty() or speed < 1.0:
		return 1.0
	var lm: Dictionary = (pending_plan.move.get("loco_match", {}) as Dictionary).get("entry", {})
	if not lm.has(loco):
		return 1.0
	var to_s := Vector3(pending_plan.start.x - body.global_position.x, 0, pending_plan.start.z - body.global_position.z).length()
	var t_arr := to_s / maxf(speed, 0.5)
	if t_arr < 0.05 or t_arr > 1.5:
		return 1.0
	var want := float(lm[loco].phase)
	var now := _loco_phase / a.length
	var rate_c := speed / maxf(float((lib.loco.get(loco, {}) as Dictionary).get("bank_speed", 1.0)), 0.1)
	var at := now + t_arr * rate_c / a.length
	var err := wrapf(want - at, -0.5, 0.5)
	return clampf(1.0 + err * a.length / maxf(t_arr * rate_c, 1e-3), 0.75, 1.25)


func _apply_ik(pins: Array, guards: Array) -> void:
	if ik == null:
		return
	ik.time_scale = time_scale
	ik.pins = pins if ik_enabled else []
	ik.guards = guards if ik_enabled else []
