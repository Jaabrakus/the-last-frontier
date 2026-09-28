class_name UpperBody
extends RefCounted
## Upper-body controller (plan sections 6.9 and 6.10, WP5): aim / carry split, the aim tree
## (A__<w>__<s>), pitch, blocked, hands (weapon-out fingers, exact-grip override), carry-layer
## weights, bow charge, weapon actions (draw, nock, grab, staged reloads), fire additives, light
## hits, heavy-hit / death suppression, crouch-change additive, and the AimStabilizer inputs.
## It only writes AnimationTree parameters and OneShot requests; the tree (TreeBuilder) is never
## changed (plan D5).
##
## Per frame (PlayerAnim._process, plan 3.1): queued events -> on_*(), LocoBrain.tick(),
## tick(inp, lower_state, dt, lower), advance(dt), post_advance(). tick() updates and writes this
## controller's selectors A (aim inputs), G (virtual stance weights) and W (virtual weapon
## weights); the caller updates only L.
##
## Graph behaviour (defaults; every gameplay override is a flag in the graph table, off by default):
##   - Carry vs aim follows Weapon.aim (plan G4 as redefined; Frontier requirement): U_aim =
##     upper_aim_w = clamp(weapon.aim) x (1 - suppress). The carry is the lower-body role's
##     graph layers (every layer, including its hands and move-set finger layers) at layer weight
##     x weapon weight, plus the code-entered weapon-out finger state idle-pistol-out-part
##     (weapon_layers.weapon_out, musket / pistol) at weapon weight x (1 - aim weight).
##   - Aim tree in the graph aim-idle order: base (+ its hands layer) -> aim-up add (C8+248) ->
##     aim-down add (C8+252) -> blocked (C8+172) -> arms-relaxed (C8+176, 0: lowering is U_aim).
##     A selector: aimidle_change fade (0x00038070, 0.25 s) on weapon or stance change.
##   - Pitch: aim elevation (chest -> crosshair point) filtered by a critically damped 30 ms
##     filter, solved through the measured calibration (metrics pitch.<w>/<s>) for the signed
##     up / down weight.
##   - Hands: the graph's hands layers place the weapon. override_exact_hands_grip (off) drives
##     the grip clips on the hands bones instead (H__ nodes, TreeIndex.grip_targets).
##   - Actions (G7, gameplay owns timing): action_started(key, dur) -> actions.<w>/<stance>/<key>
##     (by frontier_key; the bow's "grab" (R: take arrows into the bow hand) plays the nock clip,
##     the quiver reach, as today; a key no entry claims plays the graph action of that key, e.g.
##     holster). One OneShot per clip (X partial filtered to its bones, XA
##     additive twin). Clips end with their stage (rate = len / dur; the OneShot fades over its
##     last 0.15 s; a stage shorter than fade-in + fade-out plays its clip over that long plus 2
##     frames, see _timing()). Loop clips (reload mid) play n = round(dur / len) whole loops and fade out
##     when the next stage starts (or LOOP_GRACE_S after the stage end); a following stage on the
##     same loop clip is not re-fired: only its rate changes, so that it completes whole loops
##     by the new stage end from where it is. The graph's automatic stage chain (transitions with
##     request "auto" between action states: reload_begin_to_mid, fade 0 at phase 1) is played
##     too: the next state fades in on its first frame (the previous stage's last pose, as
##     authored) so that it is at full weight halfway through the stage OneShot's fade-out over
##     its last 0.15 s (chain_lead()), so begin -> mid does not dip to the carry pose and turns no
##     faster than the graph's own fade-0 cut; the gameplay's mid action then sets it playing.
##     The chain never replaces a stage the gameplay has already started. A OneShot that is still
##     playing (fading out) is never re-fired (a FIRE on an
##     active OneShot restarts it at once: a pop); the request waits until it is free and then
##     plays the rest of its stage. A replaced action keeps its weight until the new one has
##     faded in (hand-over), so the pose under the partials never shows through between stages;
##     so does an action cancelled in the same frame as a new one starts (a weapon switch:
##     the old weapon's action_cancelled, then the new weapon's draw).
##     The weapon prop bones are not in the partials' filters: PropFlipGuard plays the partials
##     on them (_guard_weights / _guard_entries hand it the clips and blend weights).
##     A OneShot is never told to fade out during its own fade-in (the engine would jump it to
##     full weight first, a pop): cancel, death and replacement wait for the fade-in to finish.
##   - Holster (options.holster, graph default on; off = today's instant switch): the graph's
##     idle-pistol-holster-part plays the weapon's draw clip backwards (start phase 1.0, cb
##     0x000155ac; negative rate, cb 0x0001b24c) over the holster phase, then holds its first frame
##     (hand at the holster) until the next action has faded in; then holster_finish
##     (idle-pistol-finish-part, hand back to idle) and the next weapon's grab (idle-pistol-grab-
##     part, draw step 1) before its draw. on_holster(), on_switch_stage(); timing: player.gd.
##   - Fire (graph +236): Weapon.fired -> runtime_clips.fire[<w>/<stance>] additive, rate 1.
##   - Light hit (G8): hit_add_by_stance[<stance>/<dir>] additive, gone by the graph's exit at
##     phase 0.9 (hit_add_exit). Heavy hit / death: suppress
##     goes to 1 in 0.1 s (LocoBrain plays the full-body clip) and back in 0.2 s after HIT.
##     Death fades every OneShot out.
##   - Crouch toggle: the crouch-change additive (crouch_change.<w>/<dir>.add, CC__ OneShot) when
##     options.crouch_change_add (graph default on; override_crouch_crossfade turns it off). A new
##     toggle replaces the additive still playing (it fades out as the new one fades in: the
##     graph's single crouch-change additive state re-entered), never adds a second one on top.
##   - Aim tree phase: only the first weapon (and snap()) seeks the aim input to 0; a weapon or
##     stance change resumes the new A input where it was frozen, the phase LocoBrain gives the
##     full-body aimidle input on entry (LocoBrain._entry_phase reads the A input's position
##     before this tick runs), and a seek of the current aimidle input by the lower body is
##     copied to the A input in the same frame (a TimeSeek does not advance in the frame it
##     seeks), so in AIM_IDLE the lower root equals the aim root (c = I).
##   - Bow charge (Frontier-only): C_add = shown draw x bow weight x aim weight, C_seek = shown
##     draw x len; the shown draw follows the draw amount up, unwinds over charge_let_down_s on a
##     let-down and hands over to the fire additive over its fade-in on a shot (tick()).
##   - Carry layers across a fade-0 lower join ramp from the outgoing input's amounts over
##     carry_join_s (_join_carry(); tuning status "approximation"; strict_graph_cuts cuts them).
##   - Thrown weapons (THROW): the graph's throw chain on the TU / TL chains (ThrowChain, `throw`):
##     Weapon.action_started("throw") plays release-start -> release-end -> recover (or back to aim)
##     at the throw rate, the wind-up is the aim tree (the graph's aim-in; the charge-seeked raise
##     only with override_throw_windup_raise), the release frame calls back through
##     `throw.released`; `fired` plays no fire additive for them, and the aim trim is off (the weapon
##     places the held object on the throw line itself).
##   - AimStabilizer: aim_root_q = the aim base clip's root at its live position (weighted over
##     the A inputs), weight = upper_aim_w, trim target = the crosshair point, trim bone = the
##     weapon's prop bone, trim feed-forward from the calibration table (the aim pose's barrel
##     yaw at the solved pitch), trim weight 1 - blocked; its closed-loop residual learns only
##     while the weapon is fully raised and no authored motion (action, fire, hit additive)
##     plays on top.
##
## Record offsets and asset IDs stay in the graph table (actions.*.state, transitions).

const STANCES := ["stand", "crouch"]
## Frontier action keys without a graph action of that frontier_key, mapped to the graph action
## whose clip plays them (today's behaviour).
const ACTION_ALIAS := {"grab": "nock"}
const REQ_FIRE := AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
const REQ_FADE_OUT := AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT
## Pitch fallback when a weapon / stance has no calibration table: degrees at full up / down add.
const PITCH_FALLBACK_DEG := 83.0
const RATE_MIN := 0.1
const RATE_MAX := 8.0
const TRACE_MAX := 32
## A looping stage keeps playing this long past its end, waiting for the next stage's
## action_started (it arrives on the next frame); then it fades out on its own.
const LOOP_GRACE_S := 0.1
## A replaced action fades out this long after the new action's fade-in (the FIRE lands one
## advance later).
const HANDOVER_EXTRA_S := 0.02
## Graph action keys played without a frontier_key (Weapon.action_started or on_holster()),
## gated by options.holster.
const HOLSTER_KEYS := ["holster", "holster_finish"]
## Reverse playback (holster): a OneShot ends at once when its clip is at its end, and its
## automatic fade-out starts (fade-in over) once (length - position) / |rate| <= fade-out, forward
## or backward (engine behaviour, measured on 4.7.2). The reversed clip therefore starts
## |rate| x (fade-out - fade-in + this) before its end; the fade-in covers the skipped frames
## (the draw's last frames = the carry pose the OneShot fades in from).
const REVERSE_MARGIN_S := 0.025
## A reversed clip is held (TimeScale 0) this far above its first frame (clip s) instead of
## reaching it (_hold_reversed(); WP7).
const REVERSE_HOLD_POS_S := 0.005
## A non-loop action clip plays over at least its fade-in + fade-out + this (see _timing()).
const MIN_FADE_MARGIN_S := 2.0 / 60.0

var data: AnimGraphData
var tree: AnimationTree
var index: TreeIndex
var A: XFadeSelector
## Virtual stance selector (inputs stand, crouch).
var G: XFadeSelector
## Virtual weapon selector (inputs = the tree's weapons).
var W: XFadeSelector
## Lower selector (optional): the carry weights default to its input weights.
var L: XFadeSelector
var stabilizer: AimStabilizer
## Plays the action partials on the weapon prop bones, which TreeBuilder leaves out of their
## filters (TreeBuilder.PROP_BONES; attach_stabilizer()).
var prop_guard: PropFlipGuard

## The thrown weapons' throw chain (null when the tree has none; THROW).
var throw: ThrowChain
## LocoBrain.moving of this frame (PlayerAnim sets it before tick(); the throw's movement exits).
var lower_moving := false

## Parameters this controller drives; turn one off when another controller owns it.
var drive_carry := true
var drive_crouch_change_add := true
## True: carry layers cut with the base clip at fade-0 lower joins (no carry_join_s ramp;
## PlayerAnim.strict_graph_cuts).
var strict_graph_cuts := false

var weapon := &""
var stance := "stand"

var _aim_w := 0.0
var _suppress := 0.0
var _heavy_t := INF
var _dead := false
var _time := 0.0
var _elev := 0.0
var _elev_v := 0.0
var _elev_set := false
var _pitch := {}               ## A input -> signed pitch weight written
var _blocked := 0.0
var _charge := 0.0
var _charge_on := 0.0          ## held-draw weight shown (the draw amount, unwound on let-down)
var _charge_release := 0.0     ## > 0: a shot hands the held draw to the fire additive over this long
var _grip_o := 0.0
var _crouched := false
var _stance_set := false
var _inp: AnimInputs
var _lower_state := &""
var _ww := {}                  ## weapon (String) -> W weight
var _written := {}
var _tables := {}
var _aim_key := {}             ## A input -> "<w>/<s>"
var _aim_roots := {}           ## A input -> {anim: Animation, track: int}
var _charge_weapons := PackedStringArray()
var _acts := {}                ## OneShot node -> play record (actions X / XA)
var _shots := {}               ## OneShot node -> play record (F, HA, CC)
var _pending := {}             ## OneShot node -> record waiting for the node to be free
var _fire_tick := {}           ## OneShot node -> tick of the last FIRE sent (not consumed before that tick's advance)
var _tick := 0                 ## ticks completed
var _fires := {}               ## OneShot node -> FIRE requests sent (tests, debug)
var _trace: Array = []
var _warned := {}
## "<w>/<stance>/<action>" -> the action the graph enters automatically at its end (transitions
## with request "auto" from its state into another action's state, e.g. reload_begin_to_mid).
var _auto_next := {}
var _last_dt := 0.0
var _grip_sig: Array = []
var _carry_sig: Array = []
## Scale on the carry's spine-lean additive layers (PlayerAnim.long_gun_spine_lean; 1 = the graph weights).
var spine_add_scale := 1.0:
	set(v):
		spine_add_scale = v
		_carry_sig = []
var _spine_params := {}              ## tree param -> true: the spine_add layers of the lower inputs
var _spine_params_built := false
## Carry layers across a fade-0 lower join (_join_carry): {input, seed: {param: start}, t, dur}.
var _join := {}
var _join_target := &""
## Lower input -> 1 (carry amounts depend on the direction weights) | 2 (on the phase: curves).
var _carry_dep := {}
## Weapon-out partials: [[param, [[weapon, stance StringName], ...]], ...] (keys that apply).
var _wo: Array = []
## "<w>/<stance>" -> [lower aimidle input's seek_request path, A input] (_sync_aim_seek).
var _aim_sync := {}
var _aim_sync_for: Array = [&"", "", []]
## OneShot node -> its fade_in_remaining parameter path (_fade_in_left).
var _fi_param := {}
## Prop bones (PropFlipGuard): action partial node -> {key, fi, fo (fade parameter paths), tracks:
## [[prop bone, Animation, rotation / position / scale track (-1: none), rest position, rest
## scale]]}, in chain order; and the blend weight of each in the coming advance (_guard_weights,
## _guard_entries).
var _guard_tracks := {}
var _guard_w := {}


## A / G / W may be null: A is then created on the tree's A chain, G and W as virtual selectors.
func _init(p_data: AnimGraphData, p_tree: AnimationTree, p_index: TreeIndex, p_A: XFadeSelector = null,
		p_G: XFadeSelector = null, p_W: XFadeSelector = null) -> void:
	data = p_data
	tree = p_tree
	index = p_index
	A = p_A if p_A != null else XFadeSelector.new(p_tree, "A", p_index.A_inputs, p_index.A_seek)
	G = p_G if p_G != null else XFadeSelector.new(null, "", PackedStringArray(STANCES))
	W = p_W if p_W != null else XFadeSelector.new(null, "", p_index.weapons)
	for key in index.aim:
		var rec: Dictionary = index.aim[key]
		if _aim_key.has(StringName(rec.input)):
			continue    # a clip-set member sharing its leader's aim input (TreeBuilder)
		_aim_key[StringName(rec.input)] = String(key)
		var clip: String = rec.clips.get("base", "")
		var ap := _anim_player()
		var p := data.godot_anim(clip)
		if ap and ap.has_animation(p):
			var a := ap.get_animation(p)
			var tr := a.find_track(NodePath("%s:root" % index.skeleton_path), Animation.TYPE_ROTATION_3D)
			if tr >= 0:
				_aim_roots[StringName(rec.input)] = {"anim": a, "track": tr}
	_index_auto_chain()
	for id in index.lower:
		var dep := 0
		for l: Dictionary in index.lower[id].get("layers", []):
			if l.has("leaf_weights"):
				var lw: Array = l.leaf_weights
				if not (is_equal_approx(float(lw[0]), float(lw[1])) and is_equal_approx(float(lw[0]), float(lw[2]))):
					dep |= 1
			if l.get("curve") is Array:
				dep |= 2
		_carry_dep[String(id)] = dep
	for clip in index.weapon_out:
		var r: Dictionary = index.weapon_out[clip]
		var ks: Array = []
		for key in r.keys:
			if bool(r.applies.get(key, false)):
				ks.append([String(key).get_slice("/", 0), StringName(String(key).get_slice("/", 1))])
		_wo.append([r.param, ks])
	for k in data.graph.get("runtime_clips", {}).get("charge", {}):
		var w := String(k).get_slice("/", 0)
		if not _charge_weapons.has(w):
			_charge_weapons.append(w)
	if not index.throw.is_empty():
		# The wind-up raise follows options.throw_windup_raise live (off: the graph's aim-in; on
		# through PlayerAnim.override_throw_windup_raise).
		throw = ThrowChain.new(data, tree, index)


## Adds the AimStabilizer (metrics bone_sets.stabilized) to `sk`, driven from post_advance().
func attach_stabilizer(sk: Skeleton3D) -> AimStabilizer:
	prop_guard = PropFlipGuard.create(sk)
	_index_guard(sk)
	stabilizer = AimStabilizer.create(sk, data.bone_set("stabilized"))
	return stabilizer


## Action partials (X) whose filter leaves out prop bones they key (TreeIndex record prop_bones).
func _index_guard(sk: Skeleton3D) -> void:
	_guard_tracks.clear()
	var ap := _anim_player()
	if ap == null or prop_guard == null:
		return
	var key := 0
	for n in index.oneshots:     # chain order (TreeBuilder builds them bottom first)
		var rec: Dictionary = index.oneshots[n]
		if String(rec.chain) != "X" or (rec.get("prop_bones", []) as Array).is_empty():
			continue
		var path := data.godot_anim(String(rec.clip))
		if not ap.has_animation(path):
			continue
		var a := ap.get_animation(path)
		var list := []
		for bn in rec.prop_bones:
			var b := sk.find_bone(String(bn))
			if b < 0 or not prop_guard.bones.has(b):
				continue
			var tp := NodePath("%s:%s" % [index.skeleton_path, bn])
			var rest := sk.get_bone_rest(b)
			list.append([b, a, a.find_track(tp, Animation.TYPE_ROTATION_3D), a.find_track(tp, Animation.TYPE_POSITION_3D),
					a.find_track(tp, Animation.TYPE_SCALE_3D), rest.origin, rest.basis.get_scale(),
					rest.basis.get_rotation_quaternion()])
		if not list.is_empty():
			_guard_tracks[n] = {"key": key, "tracks": list, "fi": index.param("%s/fade_in_remaining" % n),
					"fo": index.param("%s/fade_out_remaining" % n)}
			key += 1


## The blend weight each prop-keying action partial will have in the coming advance (Godot's
## OneShot: fading out = fade_out_remaining / fade-out; fading in = 1 - fade_in_remaining / fade-in;
## a FIRE / FADE_OUT request sent this frame gives 0 / 1), read before the advance.
func _guard_weights() -> void:
	_guard_w.clear()
	for n in _acts:
		if not _guard_tracks.has(n):
			continue
		var rec: Dictionary = index.oneshots[n]
		var req := int(tree.get(rec.request))
		var fade: Array = rec.fade
		var w := 1.0
		if req == REQ_FIRE:
			w = 0.0
		elif not bool(tree.get(rec.active)):
			continue
		elif not bool(tree.get(rec.internal_active)):
			# Fading out (a FADE_OUT request does not restart it; also the automatic fade-out
			# over a clip's last fade-out seconds).
			w = float(tree.get(_guard_tracks[n].fo)) / maxf(float(fade[1]), 1e-6)
		elif req != REQ_FADE_OUT:
			var fi := float(tree.get(_guard_tracks[n].fi))
			if fi > 0.0:
				w = (float(fade[0]) - fi) / maxf(float(fade[0]), 1e-6)
		_guard_w[n] = clampf(w, 0.0, 1.0)


## After advance(): the prop bones' entries for PropFlipGuard, per bone in chain order (lowest
## first): [key, the clip's local rotation / position / scale at the time the advance sampled
## (rest values for channels it does not key), the OneShot's blend weight in that advance].
func _guard_entries() -> void:
	if prop_guard == null:
		return
	var out := {}
	if not _guard_w.is_empty():
		for n in _guard_tracks:     # chain order
			var w := float(_guard_w.get(n, 0.0))
			if w <= 0.0:
				continue
			var g: Dictionary = _guard_tracks[n]
			var pos := float(tree.get(index.oneshots[n].position_node))
			for e: Array in g.tracks:
				var a: Animation = e[1]
				var t := clampf(pos, 0.0, a.length)
				var b: int = e[0]
				if not out.has(b):
					out[b] = []
				out[b].append([g.key, a.rotation_track_interpolate(e[2], t) if e[2] >= 0 else e[7],
						a.position_track_interpolate(e[3], t) if e[3] >= 0 else e[5],
						a.scale_track_interpolate(e[4], t) if e[4] >= 0 else e[6], w])
	prop_guard.entries = out


func set_lower_selector(p_L: XFadeSelector) -> void:
	L = p_L


## Current weapon (fades the weapon weights and the aim tree; instant the first time).
func set_weapon(key: StringName) -> void:
	key = StringName(key)
	if not W.has_input(key):
		_warn("weapon:" + key, "UpperBody: unknown weapon '%s'" % key)
		return
	var first := weapon == &""
	if key != weapon and stabilizer != null:
		stabilizer.reset_trim()
	weapon = key
	if throw != null:
		throw.set_weapon(key)
	if first:
		W.set_immediate(key)
	else:
		W.request(key, float(data.tuning("weapon_fade_s", 0.25)))
	_request_aim(first)
	_trace_add("weapon", {"weapon": String(key)})


## Jumps to the current weapon, the input's stance and aim elevation with no fade and no
## crouch-change additive (spawn, respawn, teleports, tests).
func snap(inp: AnimInputs) -> void:
	_inp = inp
	_stance_set = true
	_crouched = inp.crouched
	stance = "crouch" if inp.crouched else "stand"
	G.set_immediate(StringName(stance))
	if weapon != &"":
		W.set_immediate(weapon)
		_request_aim(true)
	_elev = inp.aim_elev_deg
	_elev_v = 0.0
	_elev_set = true


## Graph aim_stance: aim-idle is the lower state while the weapon is (being) raised.
func aim_stance(inp: AnimInputs) -> bool:
	return inp.alive and not _dead and inp.on_floor and not inp.sprinting \
			and (inp.wants_aim or inp.weapon_aim >= float(data.tuning("aim_stance_on", 0.5)))


func upper_aim_w() -> float:
	return _aim_w


## Normalized phase of the aim base clip of a weapon / stance (LocoBrain seeks the lower
## aimidle input to it on entry, so the full-body aim base and the aim tree play in step).
func aim_phase(w: String, st: String) -> float:
	var rec: Dictionary = index.aim.get("%s/%s" % [w, st], {})
	return float(tree.get(rec.position_node)) if rec.has("position_node") else 0.0


# --- per frame --------------------------------------------------------------------------------

## lower (optional; LocoBrain supplies it, else the L selector's weights are used):
##   {input_w: {id: weight}, hemi_w: {id: {fw, bw}}, dir_w: {id: {hemi: [w_neg, w_pos]}},
##    phase: {id: normalized phase}}   (see TreeIndex.carry_targets)
func tick(inp: AnimInputs, lower_state: StringName, dt: float, lower := {}) -> void:
	_inp = inp
	_lower_state = lower_state
	_last_dt = dt
	_time += dt
	_heavy_t += dt
	_update_stance(inp)
	_apply_cancels()
	_update_oneshots()
	_hold_reversed(dt)

	# Suppression (heavy hit / death) and the aim weight.
	var heavy := _heavy_t < 0.25 or lower_state == &"HIT"
	var sup_target := 1.0 if (_dead or not inp.alive or heavy) else 0.0
	var sf: Array = data.tuning("upper_suppress_fade_s", [0.1, 0.2])
	var sfs := float(sf[0]) if sup_target > _suppress else float(sf[1])
	_suppress = move_toward(_suppress, sup_target, dt / maxf(sfs, 1e-3)) if dt > 0.0 else _suppress
	_aim_w = clampf(inp.weapon_aim, 0.0, 1.0) * (1.0 - _suppress)

	# Pitch input: critically damped filter (pitch_smooth_s).
	var e := inp.aim_elev_deg
	if not _elev_set:
		_elev = e
		_elev_v = 0.0
		_elev_set = true
	elif dt > 0.0:
		var smooth := maxf(float(data.tuning("pitch_smooth_s", 0.03)), 1e-3)
		var omega := 2.0 / smooth
		var x := omega * dt
		var ex := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
		var change := _elev - e
		var temp := (_elev_v + omega * change) * dt
		_elev_v = (_elev_v - omega * temp) * ex
		_elev = e + (change + temp) * ex

	# Blocked (graph C8+172): chest ray along the camera, (L - hit) / (0.5 L), smoothed.
	var blk_target := 0.0
	if bool(data.option("blocked", true)) and is_finite(inp.blocked_hit_m):
		var bl: Dictionary = data.tuning("blocked_len_m", {})
		var length := float(bl.get(String(weapon), 0.0))
		if length > 0.0:
			blk_target = clampf((length - inp.blocked_hit_m) / (0.5 * length), 0.0, 1.0)
	var bs := maxf(float(data.tuning("blocked_smooth_s", 0.1)), 1e-3)
	_blocked = lerpf(_blocked, blk_target, 1.0 - exp(-dt / bs)) if dt > 0.0 else _blocked

	# Bow draw (Frontier-only layer). runtime_clips.charge is a held-draw pose (its first and last
	# frames are the same full draw, 1.5 rad from the bind pose at the drawing shoulder; only a
	# 0.05 rad tremble in between), not a draw motion: its weight is the draw amount, so the arm
	# draws over the gameplay's draw time (switching it on over 0.05 s snapped the arm at 30 rad/s).
	# A shot hands the held draw over to the fire additive, which starts from it, during the fire
	# clip's fade-in (on_fired); a let-down (the draw drops without a shot) unwinds over tuning
	# charge_let_down_s (proposed 0.25 s).
	_charge = clampf(inp.charge, 0.0, 1.0)
	if dt > 0.0:
		if _charge >= _charge_on:
			_charge_on = _charge
			_charge_release = 0.0
		else:
			var over := _charge_release if _charge_release > 0.0 else float(data.tuning("charge_let_down_s", 0.25))
			_charge_on = move_toward(_charge_on, _charge, dt / maxf(over, 1e-3))
			if _charge_on <= _charge:
				_charge_release = 0.0

	# Selectors.
	_sync_aim_seek()
	A.update(dt)
	A.write()
	G.update(dt)
	W.update(dt)
	_ww.clear()
	var wws := W.weights()
	for k in wws:
		_ww[String(k)] = float(wws[k])

	# Parameters.
	if index.params.has("U_aim"):
		_setp(index.params.U_aim, _aim_w)
	_write_aim()
	_write_grip(dt)
	_write_weapon_out()
	if drive_carry:
		_write_carry(lower)
	_write_charge()
	if throw != null:
		throw.tick(inp if not _dead else null, stance, lower_state, lower_moving, dt)
	_guard_weights()
	_tick += 1


## After advance(): the stabilizer inputs (the aim clips' live root, weights, trim).
func post_advance() -> void:
	_guard_entries()
	if throw != null:
		throw.post_advance()
	if stabilizer == null:
		return
	stabilizer.aim_root_q = aim_root_rotation()
	# The stabilizer applies the weight itself (c^w, trim x w); Godot's influence stays 1.
	stabilizer.weight = _aim_w
	var tw := throw.weight() if throw != null else 0.0
	if tw > 1e-4:
		# Throw clips over the upper body (THROW): their upper body is authored over their own root.
		var a := _aim_w * (1.0 - tw)
		var qa := stabilizer.aim_root_q
		var qt := throw.root_ref()
		if qa.dot(qt) < 0.0:
			qt = -qt
		var acc := Vector4(qa.x, qa.y, qa.z, qa.w) * a + Vector4(qt.x, qt.y, qt.z, qt.w) * tw
		acc = acc.normalized() if acc.length_squared() > 1e-12 else Vector4(qt.x, qt.y, qt.z, qt.w)
		stabilizer.aim_root_q = Quaternion(acc.x, acc.y, acc.z, acc.w)
		stabilizer.weight = clampf(a + tw, 0.0, 1.0)
	stabilizer.influence = 1.0
	stabilizer.active = stabilizer.weight > 1e-4
	stabilizer.trim_bone = StringName(data.prop_bone(String(weapon))) if weapon != &"" else &""
	stabilizer.trim_target = _inp.aim_point if _inp != null and not _inp.fallbacks.has("aim_point") else Vector3.INF
	stabilizer.trim_weight = 1.0 - _blocked
	stabilizer.trim_ff = _trim_ff()
	stabilizer.trim_learn = _aim_w >= 0.95 and _blocked < 0.05 and not _motion_on_top()
	if throw != null and throw.handles(weapon):
		# A thrown weapon has no barrel: the weapon lays the held object on the throw line itself
		# (Throwable._place_held); the body keeps the camera's facing.
		stabilizer.trim_weight = 0.0
		stabilizer.trim_ff = Vector2.ZERO
		stabilizer.trim_learn = false
	stabilizer.trim_hold = false
	stabilizer.step_dt = _last_dt


## The aim base clips' root rotation at their live positions, weighted over the A inputs.
func aim_root_rotation() -> Quaternion:
	var acc := Vector4.ZERO
	var ref := Quaternion.IDENTITY
	var have := false
	for id in A.weights():
		var w := A.weight(id)
		if w <= 0.0 or not _aim_roots.has(id):
			continue
		var r: Dictionary = _aim_roots[id]
		var a: Animation = r.anim
		var key: String = _aim_key[id]
		var u := float(tree.get(index.aim[key].position_node))
		var q: Quaternion = a.rotation_track_interpolate(r.track, clampf(u, 0.0, 1.0) * a.length)
		if not have:
			ref = q
			have = true
		if ref.dot(q) < 0.0:
			q = -q
		acc += Vector4(q.x, q.y, q.z, q.w) * w
	if not have or acc.length_squared() < 1e-12:
		return Quaternion.IDENTITY
	acc = acc.normalized()
	return Quaternion(acc.x, acc.y, acc.z, acc.w)


# --- events -------------------------------------------------------------------------------------

## Weapon.action_started(key, duration) of weapon `weapon_key`.
func on_action(key: String, duration: float, weapon_key: StringName) -> void:
	if _dead:
		return
	var w := String(weapon_key)
	if key == "throw" and throw != null and throw.handles(weapon_key):
		throw.stance = stance
		if throw.on_throw(weapon_key, maxf(duration, 0.05), _lower_state, lower_moving):
			_trace_add("throw", {"weapon": w, "dur": duration, "state": String(throw.state)})
		return
	if key in HOLSTER_KEYS and not holster_enabled():
		_trace_add("holster_off", {"key": key, "weapon": w})
		return
	var a := resolve_action(w, stance, key)
	if a.is_empty():
		_warn("action:%s/%s/%s" % [w, stance, key], "UpperBody: no graph action for %s/%s/%s; nothing played" % [w, stance, key])
		return
	_play_action(w, stance, a, maxf(duration, 0.05), false)


## Graph holster (options.holster; graph default on): the weapon's draw clip played backwards over
## `duration` (the holster phase), then held on its first frame (the hand at the holster) until
## the next action, normally the holster finish (or the next weapon's draw), has faded in
## (LOOP_GRACE_S after the phase at the latest). Returns false (nothing played) when the option is
## off (gameplay override: today's instant switch) or the weapon has no holster clip.
## Gameplay hook (WP7; player.gd switch_weapon(), FrontierPlayer.switch_stages()): the old weapon
## is unequipped, then on_holster(old, old.equip_time: its draw clip backwards at the speed its
## draw plays), on_switch_stage(old, "holster_finish", ..) (the hand back to idle; the old model
## is hidden and set_weapon(new) sent as it starts), on_switch_stage(new, "grab", ..) (draw step
## 1) and the new weapon's equip draw over its own equip_time; override_fast_weapon_switch
## (player.gd) instead fits the holster and the draw into the new weapon's equip_time.
## Weapon.action_cancelled does not end the holster.
func on_holster(weapon_key: StringName, duration: float) -> bool:
	return _play_graph_key(String(weapon_key), "holster", duration)


## The later stages of a graph weapon switch (see on_holster): "holster_finish" (the old weapon's
## idle-pistol-finish-part, the empty hand back to idle) and "grab" (the new weapon's
## idle-pistol-grab-part, draw step 1: the hand from idle to the weapon at its holster). Both play
## forward over `duration` and, like any replaced action, keep their weight until the next stage
## has faded in. Gated by options.holster. The bow's Frontier "grab" action (R, the quiver reach)
## is unaffected: it comes through on_action() and plays the nock clip (ACTION_ALIAS).
func on_switch_stage(weapon_key: StringName, stage: String, duration: float) -> bool:
	if not holster_enabled() or not stage in ["holster_finish", "grab"]:
		return false
	return _play_graph_key(String(weapon_key), stage, duration)


## Graph holster step 2 (idle-pistol-finish-part, entered by code): the hand returns to idle once
## the weapon is put away. Only for a holster with no draw after it (Frontier always draws the next
## weapon, whose draw replaces the held holster instead). Returns false when nothing played.
func on_holster_finish(weapon_key: StringName, duration: float) -> bool:
	return _play_graph_key(String(weapon_key), "holster_finish", duration)


## options.holster (graph default on). Off = the gameplay override "instant weapon switch".
func holster_enabled() -> bool:
	return bool(data.option("holster", false))


func _play_graph_key(w: String, key: String, duration: float) -> bool:
	if _dead or (key in HOLSTER_KEYS and not holster_enabled()):
		return false
	var a := resolve_graph_action(w, stance, key)
	if a.is_empty():
		_warn("graph_action:%s/%s/%s" % [w, stance, key], "UpperBody: no graph action %s/%s/%s; nothing played" % [w, stance, key])
		return false
	return _play_action(w, stance, a, maxf(duration, 0.05), false)


## Plays a resolved graph action for `dur` seconds (false: no OneShot for it). auto: started by the
## graph's automatic chain (a transition with request "auto" into this state, e.g.
## reload_begin_to_mid) near the end of the previous stage; the gameplay's own action_started for
## it then continues it. A graph action whose state starts at its end (start_phase, holster) with a
## negative rate callback plays its clip backwards.
func _play_action(w: String, st: String, a: Dictionary, dur: float, auto: bool) -> bool:
	var x := index.oneshot("X", String(a.partial)) if a.get("partial") is String else {}
	var xa := index.oneshot("XA", String(a.twin)) if a.get("twin") is String else {}
	if x.is_empty() and xa.is_empty():
		_warn("action_nodes:" + String(a.get("partial", "")), "UpperBody: action %s/%s/%s has no OneShot in the tree" % [w, st, a.key])
		return false
	var lead: Dictionary = x if not x.is_empty() else xa
	if auto and (_pending.has(lead.node) or (_acts.has(lead.node) and not bool(_acts[lead.node].fading))):
		# The gameplay already started (or queued) this stage: the graph chain does not replace it.
		return false
	var loop := bool(a.get("loop", false))
	var reverse := is_reverse(a)
	var length := float(lead.length)
	# A state the graph chain enters holds its first frame (the previous stage's last pose, as
	# authored) until the gameplay starts its stage, which sets the rate below.
	var tm := {"rate": 0.0, "seek": 0.0} if auto else _timing(lead, dur, loop, reverse)
	var rate := float(tm.rate)
	# Loops and reversed clips hold at their end (no automatic fade-out): they fade when the next
	# action has faded in (hand-over), else LOOP_GRACE_S after the stage end.
	var holds := loop or reverse
	var info := {"key": a.key, "weapon": w, "stance": st, "start": _time, "dur": dur, "end": _time + dur, "loop": loop,
			"reverse": reverse, "hold": holds, "rate": rate, "seek": float(tm.seek),
			"fade_out_at": _time + dur + LOOP_GRACE_S if holds else INF, "fading": false, "length": length,
			"chain": "X", "auto": auto, "next": _auto_next.get("%s/%s/%s" % [w, st, a.key], ""), "chained": false,
			"fadeout": float(lead.fade[1]), "keep_on_cancel": String(a.key) in HOLSTER_KEYS}
	if not auto:
		# The gameplay has taken over the sequence: no graph chain from an earlier stage replaces
		# (or merges into) this one.
		for n in _acts:
			_acts[n].chained = true
	# The same looping clip is already playing (consecutive mid stages, or a mid the graph chain
	# started): not re-fired. The rate is set so that the clip completes whole loops by the stage
	# end from where it is now.
	if loop and _acts.has(lead.node) and not bool(_acts[lead.node].fading) and not bool(_acts[lead.node].get("cancelled", false)) \
			and _is_playing(lead):
		var pos := float(tree.get(lead.position_node))
		if pos > 0.5 * length:
			pos -= length
		var n := maxi(1, roundi(dur / maxf(length, 1e-3)))
		rate = clampf((n * length - pos) / dur, 0.5 * n * length / dur, 2.0 * n * length / dur)
		info.rate = rate
		for rec in [x, xa]:
			if rec.is_empty() or not _acts.has(rec.node):
				continue
			var cur: Dictionary = _acts[rec.node]
			cur.merge(info, true)
			cur.chain = rec.chain
			if rec.scale != &"":
				tree.set(rec.scale, rate)
		_trace_add("action_continue", {"key": a.key, "clip": lead.clip, "rate": rate, "dur": dur})
		return true
	# WP7: a forward action on a clip that a reversed action (the holster) holds at its first frame
	# continues on that OneShot: the clip plays on from the held frame at the new rate. The stand
	# bow's and pistol's holster finish resolve to their draw clip, the holster's own clip (actor_b
	# overlay records 0x00003c08 / 0x00002330); re-firing the node would first fade the hold out
	# through the pose under it.
	if not auto and not reverse and not loop and _continue_reversed(x, xa, info, dur):
		_trace_add("action_continue_reversed", {"key": a.key, "clip": lead.clip, "rate": float(info.rate), "dur": dur})
		return true
	# WP7: a reversed action (the holster) on the clip a forward action (the same weapon's draw,
	# still playing: a switch during the draw) is playing reverses that OneShot where it is, back
	# to its first frame at the stage end, instead of re-firing it from the clip's end.
	if not auto and reverse and _reverse_in_place(x, xa, info, dur):
		_trace_add("action_reverse_in_place", {"key": a.key, "clip": lead.clip, "rate": float(info.rate), "dur": dur})
		return true
	if not auto:
		# Hand-over: an action still playing keeps its weight until the new one has faded in
		# (then fades out itself), so the carry / aim pose under them never shows through
		# between two stages; if the new one has to wait for its node, the old one goes now.
		# A cancelled action (this frame's action_cancelled) is handed over the same way; a
		# cancelled instance of the node about to play again fades out now (the new request
		# then waits for the node).
		for rec in [x, xa]:
			if not rec.is_empty() and _acts.has(rec.node) and bool(_acts[rec.node].get("cancelled", false)):
				_acts[rec.node].erase("cancelled")
				_fade_out(rec.node)
		var waits := _is_playing(lead)
		var hand := _time + float(lead.fade[0]) + HANDOVER_EXTRA_S
		for n in _acts.keys():
			_acts[n].erase("cancelled")
			if n == x.get("node", "") or n == xa.get("node", ""):
				continue
			if waits or bool(_acts[n].fading):
				_fade_out(n)
			elif bool(_acts[n].get("hold", false)):
				# A held pose (loop, reversed clip) stays until the new action has faded in.
				_acts[n].fade_out_at = hand
			else:
				_acts[n].fade_out_at = minf(float(_acts[n].fade_out_at), hand)
	for rec in [x, xa]:
		if rec.is_empty():
			continue
		var i := info.duplicate()
		i.chain = rec.chain
		if not auto and rec != lead:
			# The twin's own length (its rate and reverse start).
			var t2 := _timing(rec, dur, loop, reverse)
			i.rate = t2.rate
			i.seek = t2.seek
		_start(rec, i, _acts)
	_trace_add("action_auto" if auto else "action", {"key": a.key, "clip": lead.clip, "rate": rate, "dur": dur})
	return true


## Weapon.action_cancelled: every weapon action fades out (a holster keeps its hold until the next
## weapon's draw has faded in: Weapon.unequip() cancels right after the holster phase). The fade-out
## starts in this frame's tick() unless an action starts in the same frame's events: a weapon switch
## is the old weapon's action_cancelled (Weapon.unequip()) followed by the new weapon's equip, and
## then the cancelled actions are handed over to the new draw like a replaced stage (they keep
## their weight until it has faded in), instead of fading out through the carry pose while it fades
## in (WP6 review 2: a second switch during a draw turned the arm at up to 38 rad/s).
func on_action_cancelled(weapon_key: StringName = &"") -> void:
	for n in _acts.keys():
		if not bool(_acts[n].get("keep_on_cancel", false)):
			_acts[n]["cancelled"] = true
	for n in _pending.keys():
		if _pending[n].get("chain", "") in ["X", "XA"] and not bool(_pending[n].get("keep_on_cancel", false)):
			_pending.erase(n)
	if throw != null:
		throw.on_cancel(weapon_key)
	_trace_add("action_cancelled", {"weapon": String(weapon_key)})


## Weapon.fired: the fire additive of the weapon and stance (runtime clip, rate 1).
func on_fired(weapon_key: StringName) -> void:
	if _dead:
		return
	if throw != null and throw.handles(weapon_key):
		return    # a throw's release is part of its throw chain (ThrowChain), not a gun shot
	var clip := String(index.fire.get("%s/%s" % [weapon_key, stance], ""))
	var rec := index.oneshot("F", clip)
	if rec.is_empty():
		_warn("fire:%s/%s" % [weapon_key, stance], "UpperBody: no fire additive for %s/%s" % [weapon_key, stance])
		return
	_start(rec, {"key": "fire", "weapon": String(weapon_key), "start": _time, "end": _time + float(rec.length),
			"loop": false, "rate": 1.0, "fade_out_at": INF, "fading": false, "length": float(rec.length), "chain": "F"}, _shots)
	if _charge_weapons.has(String(weapon_key)):
		# The fire clip starts from the held draw: hand the draw over during its fade-in.
		_charge_release = maxf(float(rec.get("fade", [0.0])[0]), 1.0 / 60.0)
	_trace_add("fire", {"clip": clip})


## Player hurt. local_dir: where the hit came from (x right, y forward). Light: the hit additive
## (a direction already playing is not restarted); heavy: suppression (LocoBrain plays the clip).
func on_hurt(local_dir: Vector2, amount: float, heavy: bool) -> void:
	if _dead:
		return
	if heavy:
		_heavy_t = 0.0
		if throw != null:
			throw.on_heavy_hit()
		_trace_add("hurt_heavy", {"amount": amount})
		return
	var d := hit_dir(local_dir)
	var clip := String(index.hit_add.get("%s/%s" % [stance, d], index.hit_add.get(d, "")))
	var rec := index.oneshot("HA", clip)
	if rec.is_empty():
		return
	if _is_playing(rec):
		_trace_add("hurt_skipped", {"dir": d, "clip": clip})
		return
	# Graph hit-reaction-par exits at phase 0.9 (hit_add_exit, 0x000323b0, fade 0): the additive
	# has faded out (hit_add_fade) by then.
	var exit_phase := float(data.transition_use("hit_add_exit").get("gate_phase", data.threshold("hit_par_exit_phase", 0.9)))
	var fade_at := maxf(_time, _time + float(rec.length) * exit_phase - float(rec.fade[1]))
	_start(rec, {"key": "hit_" + d, "start": _time, "end": _time + float(rec.length) * exit_phase, "loop": false, "rate": 1.0,
			"fade_out_at": fade_at, "fading": false, "length": float(rec.length), "chain": "HA"}, _shots)
	_trace_add("hurt", {"dir": d, "clip": clip, "amount": amount})


func on_died(_local_dir: Vector2 = Vector2.ZERO) -> void:
	_dead = true
	_pending.clear()
	if throw != null:
		throw.on_died()
	for d in [_acts, _shots]:
		for n in d.keys():
			_fade_out(n)
	for n in index.oneshots:
		if not _acts.has(n) and not _shots.has(n) and _is_playing(index.oneshots[n]):
			tree.set(index.oneshots[n].request, REQ_FADE_OUT)
	_trace_add("died", {})


func on_revive() -> void:
	_dead = false
	_heavy_t = INF
	_trace_add("revive", {})


## 90 deg sector of the direction a hit came from: fw (front), bw, lt, rt.
static func hit_dir(local_dir: Vector2) -> String:
	if local_dir.length() < 1e-4:
		return "fw"
	var a := rad_to_deg(atan2(local_dir.x, local_dir.y))
	if absf(a) <= 45.0:
		return "fw"
	if absf(a) >= 135.0:
		return "bw"
	return "rt" if a > 0.0 else "lt"


## The graph action a Frontier action key plays for a weapon and stance: the entry whose
## frontier_key is `key`, else ACTION_ALIAS; {} when none. Adds `key` (the graph action key).
func resolve_action(w: String, st: String, key: String) -> Dictionary:
	var acts: Dictionary = data.graph.get("actions", {})
	var direct := "%s/%s/%s" % [w, st, key]
	var a: Dictionary = acts.get(direct, {})
	if not a.is_empty() and a.get("frontier_key") is String and String(a.frontier_key) == key and a.get("partial") != null:
		var out := a.duplicate()
		out["key"] = key
		return out
	for k in acts:
		var e: Dictionary = acts[k]
		if String(k).begins_with("%s/%s/" % [w, st]) and e.get("frontier_key") is String and String(e.frontier_key) == key \
				and e.get("partial") != null:
			var out := e.duplicate()
			out["key"] = String(k).get_slice("/", 2)
			return out
	if ACTION_ALIAS.has(key):
		return resolve_action(w, st, ACTION_ALIAS[key])
	return {}


## The graph action `key` itself ("<w>/<st>/<key>"), {} when absent or without a clip.
func resolve_graph_action(w: String, st: String, key: String) -> Dictionary:
	var a: Dictionary = data.graph.get("actions", {}).get("%s/%s/%s" % [w, st, key], {})
	if a.is_empty() or a.get("partial") == null:
		return {}
	var out := a.duplicate()
	out["key"] = key
	return out


## Feed-forward aim trim (yaw, pitch) in radians for the AimStabilizer: over the weighted aim
## inputs, minus the aim pose's barrel yaw at the solved pitch weight (metrics pitch.*.yaw_deg),
## and the elevation the pitch additives cannot reach (outside the table's solve range).
func _trim_ff() -> Vector2:
	var out := Vector2.ZERO
	var tw := 0.0
	for id in A.weights():
		var w := A.weight(id)
		var key: String = _aim_key.get(id, "")
		if w <= 0.0 or key == "":
			continue
		var t := _table(key)
		if t.is_empty():
			continue
		var pw := float(_pitch.get(id, 0.0))
		var yaw := _interp(t.w_all, t.yaw_all, pw)
		var elev := _interp(t.w_all, t.e_all, pw)
		out += Vector2(-deg_to_rad(yaw), deg_to_rad(_elev - elev)) * w
		tw += w
	return out / tw if tw > 0.0 else Vector2.ZERO


static func _interp(xs: PackedFloat64Array, ys: PackedFloat64Array, x: float) -> float:
	if xs.is_empty():
		return 0.0
	if x <= xs[0]:
		return ys[0]
	for i in range(1, xs.size()):
		if x <= xs[i]:
			return lerpf(ys[i - 1], ys[i], (x - xs[i - 1]) / maxf(xs[i] - xs[i - 1], 1e-9))
	return ys[ys.size() - 1]


## Signed pitch weight (+ up add, - down add) for an aim elevation, from the calibration table.
func solve_pitch(w: String, st: String, elev_deg: float) -> float:
	var t := _table("%s/%s" % [w, st])
	if t.is_empty():
		return clampf(elev_deg / PITCH_FALLBACK_DEG, -1.0, 1.0)
	var ws: PackedFloat64Array = t.w
	var el: PackedFloat64Array = t.e
	if elev_deg <= el[0]:
		return ws[0]
	if elev_deg >= el[el.size() - 1]:
		return ws[ws.size() - 1]
	var lo := 0
	var hi := el.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) >> 1
		if el[mid] <= elev_deg:
			lo = mid
		else:
			hi = mid
	return lerpf(ws[lo], ws[hi], (elev_deg - el[lo]) / maxf(el[hi] - el[lo], 1e-9))


## Debug / test view (plan section 9 "upper" and the derived fields).
## True while an action (reload stage, draw, holster, grab, ...) plays and is not fading out, or the
## player is dead: the left hand is the action's (LeftGripIK lets go of the forestock).
func action_playing() -> bool:
	if _dead:
		return true
	for n in _acts:
		var rec: Dictionary = index.oneshots.get(n, {})
		if not rec.is_empty() and _is_playing(rec) and not bool(_acts[n].fading):
			return true
	return false


func snapshot() -> Dictionary:
	var shots: Array = []
	for d in [_acts, _shots]:
		for n in d:
			var rec: Dictionary = index.oneshots.get(n, {})
			if rec.is_empty() or not _is_playing(rec):
				continue
			shots.append({"node": n, "clip": rec.clip, "position": float(tree.get(rec.position_node)), "rate": d[n].rate,
					"ends_at": d[n].end, "key": d[n].key, "fading": d[n].fading})
	var ak: String = _aim_key.get(_aim_input(String(weapon), stance), "")
	var pw := float(_pitch.get(_aim_input(String(weapon), stance), 0.0))
	return {"weapon": String(weapon), "stance": stance, "upper_aim_w": _aim_w, "suppress": _suppress, "dead": _dead,
			"elev_deg": _elev, "up_w": maxf(pw, 0.0), "down_w": maxf(-pw, 0.0), "aim_key": ak, "blocked_w": _blocked,
			"charge": _charge, "charge_on": _charge_on, "grip_override": _grip_o,
			"A": A.snapshot(), "G": G.snapshot(), "W": W.snapshot(), "active_oneshots": shots,
			"pending": _pending.keys(), "holster": holster_enabled(),
			"throw": throw.snapshot() if throw != null else {},
			"stabilizer_deg": stabilizer.last_correction_deg() if stabilizer else 0.0,
			"trim_deg": [stabilizer.last_trim_deg().x, stabilizer.last_trim_deg().y] if stabilizer else [0.0, 0.0],
			"trace": _trace.duplicate()}


## FIRE requests sent per OneShot node (tests).
func fire_counts() -> Dictionary:
	return _fires.duplicate()


## Play records of the weapon actions (node -> record; tests, debug).
func action_records() -> Dictionary:
	return _acts.duplicate(true)


## Forget cached parameter writes (after the tree was reset or re-installed).
func invalidate() -> void:
	_written.clear()
	_grip_sig = []
	_carry_sig = []
	index.reset_carry_cache()
	A.invalidate()


# --- internals --------------------------------------------------------------------------------

func _update_stance(inp: AnimInputs) -> void:
	var crouched := inp.crouched
	var st := "crouch" if crouched else "stand"
	if not _stance_set:
		_stance_set = true
		_crouched = crouched
		stance = st
		G.set_immediate(StringName(st))
		if weapon != &"":
			_request_aim(true)
		return
	if crouched == _crouched:
		return
	_crouched = crouched
	stance = st
	if stabilizer != null:
		stabilizer.reset_trim()
	G.request(StringName(st), float(data.tuning("stance_fade_s", 0.25)))
	_request_aim(false)
	if drive_crouch_change_add and not _dead and bool(data.option("crouch_change_add", true)):
		var dir := "stand_to_crouch" if crouched else "crouch_to_stand"
		var rec := index.oneshot("CC", String(index.crouch_add.get("%s/%s" % [weapon, dir], "")))
		if not rec.is_empty():
			# One crouch-change additive at a time (the graph re-enters its single additive state):
			# the one still playing (the other direction) fades out while this one fades in with the
			# same fade, a crossfade; this direction's node still fading out from an earlier toggle
			# plays once it is free (_start queues it; a FIRE on an active OneShot pops).
			# An additive still fading in fades out only once at full weight (_fade_out); this one
			# then starts in that same tick.
			var wait := 0.0
			for n in _shots.keys():
				if n != rec.node and String(_shots[n].get("chain", "")) == "CC" and not bool(_shots[n].fading):
					wait = maxf(wait, _fade_in_left(index.oneshots.get(n, {})))
					_fade_out(n)
			for n in _pending.keys():
				if n != rec.node and String(_pending[n].get("chain", "")) == "CC":
					_pending.erase(n)
			var info := {"key": dir, "start": _time, "end": _time + float(rec.length), "loop": false, "rate": 1.0,
					"fade_out_at": INF, "fading": false, "length": float(rec.length), "chain": "CC"}
			if wait > 1e-4:
				info["not_before"] = _time + wait
				_pending[rec.node] = info
			else:
				_start(rec, info, _shots)
			_trace_add("crouch_change_add", {"clip": rec.clip, "wait": wait})


func _index_auto_chain() -> void:
	var acts: Dictionary = data.graph.get("actions", {})
	var by_state := {}
	for k in acts:
		if String(acts[k].get("status", "")) == "frontier_pinned":
			continue    # a Frontier key pinned to another action's clips (THROW 'draw'): not a graph state
		var ctx := String(k).get_slice("/", 0) + "/" + String(k).get_slice("/", 1)
		by_state["%s|%s" % [ctx, acts[k].get("state", "")]] = String(k).get_slice("/", 2)
	for tk in data.graph.get("transitions", {}):
		var g: Variant = data.graph.transitions[tk].get("graph")
		if not g is Dictionary or String(g.get("request", "")) != "auto" or g.get("source") == g.get("target"):
			continue
		for k in acts:
			if String(acts[k].get("state", "")) != String(g.source) or acts[k].get("partial") == null \
					or String(acts[k].get("status", "")) == "frontier_pinned":
				continue
			var ctx := String(k).get_slice("/", 0) + "/" + String(k).get_slice("/", 1)
			var nk: String = by_state.get("%s|%s" % [ctx, g.target], "")
			if nk != "" and acts.get("%s/%s" % [ctx, nk], {}).get("partial") != null:
				_auto_next[k] = nk


## The full-body aim base (lower aimidle input) and the aim tree play in step: when the lower body
## (LocoBrain, earlier this frame) seeks the aimidle input of the current weapon / stance, the A
## input gets the same seek. LocoBrain enters it at the A input's position, but a TimeSeek does not
## advance in the frame it seeks, so without this the lower base would trail the aim tree by one
## frame (0.1 deg of correction c in AIM_IDLE).
func _sync_aim_seek() -> void:
	if weapon == &"":
		return
	if _aim_sync_for[0] != weapon or _aim_sync_for[1] != stance:
		var key := "%s/%s" % [weapon, stance]
		var s: Variant = _aim_sync.get(key)
		if s == null:
			var lid := index.input_for("%s/%s/aimidle" % [weapon, stance])
			var sp: Variant = index.lower_record(lid).get("seek", &"") if lid != &"" else &""
			var aid := _aim_input(String(weapon), stance)
			s = [sp if sp is StringName else &"", aid if A.has_input(aid) else &""]
			_aim_sync[key] = s
		_aim_sync_for = [weapon, stance, s]
	var cur: Array = _aim_sync_for[2]
	if cur[0] == &"" or cur[1] == &"":
		return
	var v := float(tree.get(cur[0]))
	if v >= 0.0:
		A.seek(cur[1], v)


func _request_aim(immediate: bool) -> void:
	if weapon == &"":
		return
	var id := _aim_input(String(weapon), stance)
	if not A.has_input(id):
		return
	if immediate:
		A.set_immediate(id, 0.0)
	else:
		# No seek: the input resumes where it was frozen, the phase LocoBrain seeks the full-body
		# aimidle input to (it reads the A input's position before this tick).
		A.request(id, float(data.transition_use("aimidle_change").get("fade_s", 0.25)), -1.0)


## action_cancelled with no action started after it in the same frame: the actions fade out.
func _apply_cancels() -> void:
	for n in _acts.keys():
		if bool(_acts[n].get("cancelled", false)):
			_acts[n].erase("cancelled")
			_fade_out(n)


## Scheduled fade-outs, finished records, and requests waiting for a free OneShot.
func _update_oneshots() -> void:
	for d in [_acts, _shots]:
		for n in d.keys():
			if not d.has(n):
				continue
			var r: Dictionary = d[n]
			var rec: Dictionary = index.oneshots.get(n, {})
			if not r.fading and _time >= float(r.fade_out_at) - 1e-6:
				_fade_out(n)
			elif not _is_playing(rec) and _time > float(r.start) + 1e-6:
				d.erase(n)
			elif d == _acts and String(r.get("next", "")) != "" and not bool(r.chained) and not r.fading \
					and r.chain == "X":
				# The graph's automatic chain (e.g. reload_begin_to_mid, fade 0 at phase 1): the next
				# state fades in on its first frame so that it is at full weight halfway through this
				# stage's OneShot fade-out (chain_lead).
				if not r.has("chain_at"):
					var nx := resolve_graph_action(String(r.weapon), String(r.stance), String(r.next))
					var nl := index.oneshot("X", String(nx.get("partial", ""))) if not nx.is_empty() else {}
					r["chain_next"] = nx
					r["chain_len"] = float(nl.get("length", 0.0))
					r["chain_at"] = float(r.end) - chain_lead(float(nl.fade[0]), float(r.fadeout)) if not nl.is_empty() else INF
				if _time >= float(r.chain_at) - 1e-6:
					r.chained = true
					_play_action(String(r.weapon), String(r.stance), r.chain_next, float(r.chain_len), true)
	for n in _pending.keys():
		var rec: Dictionary = index.oneshots.get(n, {})
		if _is_playing(rec) or _time < float(_pending[n].get("not_before", -INF)) - 1e-6:
			continue
		var p: Dictionary = _pending[n]
		_pending.erase(n)
		var remaining := float(p.end) - _time
		if remaining < 0.05:
			continue
		if rec.scale != &"":
			var tm := _timing(rec, remaining, bool(p.loop), bool(p.get("reverse", false)))
			p.rate = tm.rate
			p.seek = tm.seek
		else:
			p.rate = 1.0
		p.start = _time
		if bool(p.get("hold", p.loop)):
			p.fade_out_at = float(p.end) + LOOP_GRACE_S
		_start(rec, p, _acts if p.chain in ["X", "XA"] else _shots)


## _play_action(): continues a held reversed action on its own OneShots, forward over `dur` (see
## there). False (nothing changed) unless the lead OneShot plays a reversed action that is not
## fading out.
func _continue_reversed(x: Dictionary, xa: Dictionary, info: Dictionary, dur: float) -> bool:
	var lead: Dictionary = x if not x.is_empty() else xa
	if not _acts.has(lead.node) or not bool(_acts[lead.node].get("reverse", false)) or bool(_acts[lead.node].fading) \
			or not _is_playing(lead):
		return false
	for rec in [x, xa]:
		if rec.is_empty() or not _acts.has(rec.node):
			continue
		var cur: Dictionary = _acts[rec.node]
		var tm := _timing(rec, dur, false, false)
		var i := info.duplicate()
		i.chain = rec.chain
		i.rate = tm.rate
		i.seek = 0.0
		cur.merge(i, true)
		cur.erase("rev_held")
		cur.erase("rev_landing")
		if rec.scale != &"":
			tree.set(rec.scale, float(tm.rate))
		if rec == lead:
			info.rate = tm.rate
	return true


## _play_action(): reverses a playing forward action on its own OneShots, back to the first frame
## over `dur` (see there). False (nothing changed) unless the lead OneShot plays a forward action
## that is not fading out.
func _reverse_in_place(x: Dictionary, xa: Dictionary, info: Dictionary, dur: float) -> bool:
	var lead: Dictionary = x if not x.is_empty() else xa
	if not _acts.has(lead.node) or bool(_acts[lead.node].get("reverse", false)) or bool(_acts[lead.node].fading) \
			or not _is_playing(lead):
		return false
	for rec in [x, xa]:
		if rec.is_empty() or not _acts.has(rec.node) or rec.get("scale", &"") == &"":
			continue
		var cur: Dictionary = _acts[rec.node]
		var pos := float(tree.get(rec.position_node)) if rec.has("position_node") else 0.0
		var r := 0.0
		if pos > REVERSE_HOLD_POS_S + 1e-4:
			r = clampf((pos - REVERSE_HOLD_POS_S) / maxf(dur, 1e-3), RATE_MIN, RATE_MAX)
		var i := info.duplicate()
		i.chain = rec.chain
		i.rate = -r
		i.seek = pos
		cur.merge(i, true)
		cur.erase("cancelled")
		cur.erase("rev_held")
		cur.erase("rev_landing")
		tree.set(rec.scale, -r)
		if rec == lead:
			info.rate = -r
	return true


## Reversed actions (the holster) hold their first frame at TimeScale 0 instead of reaching it. A
## OneShot playing backwards that reaches its clip start while it is still fading in (a holster
## phase shorter than the fade-in: player.gd's override_fast_weapon_switch splits the new weapon's
## equip_time between the holster and the draw) fades itself out part-way (Godot 4.7.2, measured by WP7: weight 1 -> 0.67 in one
## frame at the hand-over to the next draw, the left wrist at 90 rad/s). Landing on
## REVERSE_HOLD_POS_S and stopping there keeps the hold at full weight until the hand-over's
## scheduled fade-out. WP7 (minimal addition).
func _hold_reversed(dt: float) -> void:
	if dt <= 0.0:
		return
	for n in _acts:
		var r: Dictionary = _acts[n]
		if not bool(r.get("reverse", false)) or bool(r.get("fading", false)) or bool(r.get("rev_held", false)):
			continue
		var rec: Dictionary = index.oneshots.get(n, {})
		if rec.is_empty() or rec.get("scale", &"") == &"" or int(_fire_tick.get(n, -1)) >= _tick:
			continue
		if bool(r.get("rev_landing", false)):
			tree.set(rec.scale, 0.0)
			r["rev_held"] = true
			continue
		var pos := float(tree.get(rec.position_node))
		var step := absf(float(r.get("rate", 0.0))) * dt
		if pos - step > REVERSE_HOLD_POS_S:
			continue
		if pos > REVERSE_HOLD_POS_S + 1e-4:
			tree.set(rec.scale, -(pos - REVERSE_HOLD_POS_S) / dt)
			r["rev_landing"] = true
		else:
			tree.set(rec.scale, 0.0)
			r["rev_held"] = true


## How long before a stage's end the graph chain fires the next state (seconds): its fade-in
## (fade_in) completes halfway through the stage OneShot's automatic fade-out (fadeout). A
## non-loop OneShot cannot hold its last frame at full weight (it fades out over the clip's last
## fadeout seconds), so the graph's fade-0 cut at phase 1 becomes a crossfade centred on that
## fade-out: the carry pose under the partials shows through by < 0.08, and the seam turns no
## faster than the graph's cut (test_actions measures both).
static func chain_lead(fade_in: float, fadeout: float) -> float:
	return fade_in + 0.5 * fadeout


## Plays `rec` now, or queues it while the node is still playing (a FIRE would restart it).
func _start(rec: Dictionary, info: Dictionary, into: Dictionary) -> void:
	if _is_playing(rec):
		_pending[rec.node] = info
		_trace_add("queued", {"node": rec.node})
		return
	if rec.scale != &"":
		tree.set(rec.scale, float(info.rate))
	if rec.seek != &"":
		tree.set(rec.seek, float(info.get("seek", 0.0)))
	tree.set(rec.request, REQ_FIRE)
	_fire_tick[rec.node] = _tick
	_fires[rec.node] = int(_fires.get(rec.node, 0)) + 1
	into[rec.node] = info


## Fades OneShot `n` out, or, while it is still fading in, once its fade-in is over: a FADE_OUT
## during the fade-in makes the engine jump the shot to full weight and fade from there (a pop;
## Godot 4.7.2, measured: weight 0.1 -> 1.0 in one frame).
func _fade_out(n: String) -> void:
	_pending.erase(n)
	var rec: Dictionary = index.oneshots.get(n, {})
	var playing := not rec.is_empty() and _is_playing(rec)
	var fi := _fade_in_left(rec) if playing else 0.0
	if fi > 1e-4:
		for d in [_acts, _shots]:
			if d.has(n):
				d[n].fading = false
				d[n].fade_out_at = _time + fi
		return
	for d in [_acts, _shots]:
		if d.has(n):
			d[n].fading = true
			d[n].fade_out_at = INF
	if playing:
		tree.set(rec.request, REQ_FADE_OUT)


## Seconds of fade-in a playing OneShot has left (0 when at full weight or fading out; -1 when
## its FIRE has not been consumed by an advance yet).
func _fade_in_left(rec: Dictionary) -> float:
	if rec.is_empty():
		return 0.0
	if int(_fire_tick.get(rec.node, -1)) >= _tick:
		return -1.0
	var p: Variant = _fi_param.get(rec.node)
	if p == null:
		p = index.param("%s/fade_in_remaining" % rec.node)
		_fi_param[rec.node] = p
	return maxf(float(tree.get(p)), 0.0)


## Active (including fading), or fired since the last tick (the request is consumed by the
## advance() that follows the tick).
func _is_playing(rec: Dictionary) -> bool:
	if rec.is_empty():
		return false
	if int(_fire_tick.get(rec.node, -1)) >= _tick:
		return true
	return bool(tree.get(rec.active))


## Loop clips: n = round(dur / len) whole loops per stage; other clips end with the stage.
static func _action_rate(length: float, dur: float, loop: bool) -> float:
	if loop:
		var n := maxi(1, roundi(dur / maxf(length, 1e-3)))
		return clampf(n * length / dur, RATE_MIN, RATE_MAX)
	return clampf(length / dur, RATE_MIN, RATE_MAX)


## {rate (signed), seek (clip seconds)} to play OneShot `rec` over `dur` seconds. Reverse: from
## near the clip's end (see REVERSE_MARGIN_S) back to its first frame at the stage end.
func _timing(rec: Dictionary, dur: float, loop: bool, reverse: bool) -> Dictionary:
	var length := maxf(float(rec.length), 1e-3)
	if not reverse:
		var d := dur
		if not loop:
			# Godot starts a OneShot's automatic fade-out only once its fade-in is over, and then
			# at (time left) / fade-out: an action shorter than fade-in + fade-out drops from full
			# weight to about half in one frame (measured on 4.7.2: the 0.3 s pistol draw with
			# fades 0.2 / 0.15 turned the arm at 70-94 rad/s). Such a clip plays over fade-in +
			# fade-out + 2 frames instead; the stage end (gameplay timing) is unchanged.
			d = maxf(dur, float(rec.fade[0]) + float(rec.fade[1]) + MIN_FADE_MARGIN_S)
		return {"rate": _action_rate(length, d, loop), "seek": 0.0}
	if rec.get("seek", &"") == &"":
		_warn("reverse_seek:" + String(rec.node), "UpperBody: %s has no TimeSeek; reversed from the clip start (nothing to play)" % rec.node)
	var m := maxf(float(rec.fade[1]) - float(rec.fade[0]), 0.0) + REVERSE_MARGIN_S
	var r := clampf(length / maxf(dur + m, 1e-3), RATE_MIN, RATE_MAX)
	return {"rate": -r, "seek": clampf(length - r * m, 0.0, length - 1e-3)}


## A graph action that starts at its clip's end (start-phase callback) with a negative rate
## callback (its unflagged branch multiplies the rate by a negative constant): the holster.
static func is_reverse(a: Dictionary) -> bool:
	if float(a.get("start_phase", 0.0)) < 0.5:
		return false
	var cb: Variant = a.get("rate_callback")
	if not cb is Dictionary or not cb.get("expr") is Array or cb.expr.is_empty():
		return true
	for e in cb.expr:
		var s := String(e)
		if s.begins_with("IF !i32[D4+36] & !i32[D4+40]"):
			return s.contains("* -")
	return true


## The A input of a weapon and stance (a clip-set member plays its leader's; TreeBuilder).
func _aim_input(w: String, st: String) -> StringName:
	var rec: Dictionary = index.aim.get("%s/%s" % [w, st], {})
	return StringName(rec.get("input", "A__%s__%s" % [w, st]))


## An authored motion plays on top of the aim (the trim must not cancel it).
func _motion_on_top() -> bool:
	if throw != null and throw.weight() > 1e-4:
		return true
	for d in [_acts, _shots]:
		for n in d:
			if _is_playing(index.oneshots.get(n, {})):
				return true
	return false


func _write_aim() -> void:
	var target := A.target()
	var blocked_on := bool(data.option("blocked", true))
	for id in A.weights():
		if A.weight(id) <= 0.0 and id != target:
			continue
		var key: String = _aim_key.get(id, "")
		if key == "":
			continue
		var rec: Dictionary = index.aim[key]
		var pw := solve_pitch(key.get_slice("/", 0), key.get_slice("/", 1), _elev)
		_pitch[id] = pw
		if rec.has("add_up"):
			_setp(rec.add_up, maxf(pw, 0.0))
		if rec.has("add_dn"):
			_setp(rec.add_dn, maxf(-pw, 0.0))
		if rec.has("blk"):
			_setp(rec.blk, _blocked if blocked_on else 0.0)
		if rec.has("rel"):
			_setp(rec.rel, 0.0)


func _write_grip(dt: float) -> void:
	if index.grip_sources.is_empty():
		return
	var o := 1.0 if data.override_enabled("override_exact_hands_grip") else 0.0
	var gf := maxf(float(data.tuning("grip_fade_s", 0.15)), 1e-3)
	_grip_o = move_toward(_grip_o, o, dt / gf) if dt > 0.0 else _grip_o
	if not _stance_set:
		_grip_o = o
	var crouch := G.weight(&"crouch")
	# Off (graph default) and already written as off: nothing to do.
	var sig := [_grip_o, _aim_w, crouch, _ww] if _grip_o > 0.0 else [0.0]
	if sig == _grip_sig:
		return
	_grip_sig = sig
	var aw := {}
	var cw := {}
	for w in _ww:
		aw[w] = _aim_w
		cw[w] = crouch
	index.write_grip(tree, index.grip_targets(_grip_o, _ww, aw, cw))


func _write_weapon_out() -> void:
	var on := bool(data.option("weapon_out_fingers", true))
	for wo: Array in _wo:
		var a := 0.0
		if on:
			for k: Array in wo[1]:
				a += float(_ww.get(k[0], 0.0)) * G.weight(k[1])
			a *= 1.0 - _aim_w
		_setp(wo[0], clampf(a, 0.0, 1.0))


func _write_carry(lower: Dictionary) -> void:
	if index.lower.is_empty():
		return
	var input_w: Dictionary = lower.get("input_w", {})
	if input_w.is_empty() and L != null:
		input_w = {}
		var lw := L.weights()
		for k in lw:
			if float(lw[k]) > 0.0:
				input_w[String(k)] = float(lw[k])
		var tg := String(L.target())
		if tg != "" and not input_w.has(tg):
			input_w[tg] = 1e-6
	if input_w.is_empty():
		return
	_join_carry(lower)
	# The per-input layer amounts depend on the weapon weights, and only for some inputs on the
	# direction weights (layers present on some bank leaves only) or the phase (curve weights);
	# skip the recomputation while none of those changed.
	var dir_w: Dictionary = lower.get("dir_w", {})
	var phase: Dictionary = lower.get("phase", {})
	var sig := [_ww.duplicate()]
	var shared := index.carry_mode == "shared"
	for id in input_w:
		var dep: int = _carry_dep.get(id, 0)
		sig.append(id)
		if shared:
			sig.append(input_w[id])
		if dep & 1:
			sig.append(dir_w.get(id))
		if dep & 2:
			sig.append(phase.get(id))
	if not _join.is_empty():
		sig.append(_join.t)
	if sig == _carry_sig:
		return
	_carry_sig = sig
	var t := index.carry_targets(input_w, _ww, lower.get("hemi_w", {}), dir_w, phase)
	if spine_add_scale != 1.0:
		if not _spine_params_built:
			_spine_params_built = true
			for id in index.lower:
				for la: Dictionary in index.lower[id].get("layers", []):
					if String(la.get("slot", "")) == "spine_add" and la.get("param", &"") != &"":
						_spine_params[la.param] = true
		for prm in t:
			if _spine_params.has(prm):
				t[prm] = float(t[prm]) * spine_add_scale
	if not _join.is_empty():
		var u := clampf(float(_join.t) / maxf(float(_join.dur), 1e-3), 0.0, 1.0)
		for prm in _join.seed:
			t[prm] = lerpf(float(_join.seed[prm]), float(t.get(prm, 0.0)), u)
		if u >= 1.0:
			_join = {}
	index.write_carry(tree, t)


## A fade-0 lower join (a one-shot's end into its successor, e.g. take-off -> jump, reversal ->
## run: the graph cuts the base clip, whose poses match there) also swaps the carry-layer stack,
## and the two inputs' stacks can differ (musket: the take-off and the reversals have no
## rifle-run-arms layer, the jump and run-bkwd do; cutting them snapped the left wrist at up to
## 131 rad/s). The base still cuts as authored; the incoming input's layer amounts start from the
## outgoing input's amounts of the same clip (0 where it had none) and reach their own over
## tuning carry_join_s (0.25 s, status "approximation": the decoded layer records give weights
## only, not how the layers change at such a cut; strict_graph_cuts turns the ramp off). Detected
## here: the lower target changed this frame with an infinite rate while another input is at full
## weight.
func _join_carry(lower: Dictionary) -> void:
	if L == null:
		_join = {}
		return
	if not _join.is_empty():
		_join.t = float(_join.t) + _last_dt
	var tgt := L.target()
	if tgt == _join_target:
		return
	_join_target = tgt
	var from := L.dominant()
	if from == tgt or L.weight(tgt) >= 1.0 or L.weight(from) < 0.999 or not is_inf(float(L.snapshot().get("rate", 0.0))):
		return
	var dur := 0.0 if strict_graph_cuts else float(data.tuning("carry_join_s", 0.25))
	if dur <= 0.0:
		return
	var from_rec := index.lower_record(from)
	var have := {}
	var hemi_w: Dictionary = lower.get("hemi_w", {}).get(String(from), {})
	for la: Dictionary in from_rec.get("layers", []):
		if la.param == &"" or la.shared:
			continue
		var hw := 1.0
		if la.hemi != "":
			hw = float(hemi_w.get(la.hemi, 1.0 if la.hemi == "fw" else 0.0))
		var key := "%s|%s|%s" % [la.weapon, la.clip, la.kind]
		have[key] = float(have.get(key, 0.0)) + float(tree.get(la.param)) * hw
	var seed := {}
	for lb: Dictionary in index.lower_record(tgt).get("layers", []):
		if lb.param == &"":
			continue
		if lb.shared:
			seed[lb.param] = float(tree.get(lb.param))
		else:
			seed[lb.param] = clampf(float(have.get("%s|%s|%s" % [lb.weapon, lb.clip, lb.kind], 0.0)), 0.0, 1.0)
	if seed.is_empty():
		return
	_join = {"input": String(tgt), "from": String(from), "seed": seed, "t": 0.0, "dur": dur}
	_trace_add("carry_join", {"from": String(from), "to": String(tgt), "layers": seed.size()})


func _write_charge() -> void:
	if index.charge.is_empty():
		return
	var cw := 0.0
	for w in _charge_weapons:
		cw += float(_ww.get(w, 0.0))
	var amt := clampf(_charge_on * cw * _aim_w, 0.0, 1.0)
	var was := float(_written.get(index.charge.add, 0.0))
	_setp(index.charge.add, amt)
	if amt > 0.0 or was > 0.0:
		for st in index.charge.seek:
			tree.set(index.charge.seek[st], _charge_on * float(index.charge.lengths[st]))
	if index.charge.has("st"):
		_setp(index.charge.st, G.weight(&"crouch"))


func _table(key: String) -> Dictionary:
	if _tables.has(key):
		return _tables[key]
	var t := data.pitch_table(key.get_slice("/", 0), key.get_slice("/", 1))
	var out := {}
	if not t.is_empty() and t.get("weights") is Array and t.get("elev_deg") is Array:
		var lo := -float(t.get("solve_down", t.get("max_valid_down", 1.0)))
		var hi := float(t.get("solve_up", t.get("max_valid_up", 1.0)))
		var ws := PackedFloat64Array()
		var el := PackedFloat64Array()
		for i in t.weights.size():
			var x := float(t.weights[i])
			var e := float(t.elev_deg[i])
			if x < lo - 1e-6 or x > hi + 1e-6:
				continue
			if not el.is_empty() and e <= el[el.size() - 1]:
				continue
			ws.append(x)
			el.append(e)
		if ws.size() >= 2:
			var wa := PackedFloat64Array()
			var ea := PackedFloat64Array()
			var ya := PackedFloat64Array()
			var yd: Array = t.get("yaw_deg", [])
			for i in t.weights.size():
				wa.append(float(t.weights[i]))
				ea.append(float(t.elev_deg[i]))
				ya.append(float(yd[i]) if i < yd.size() else 0.0)
			out = {"w": ws, "e": el, "w_all": wa, "e_all": ea, "yaw_all": ya}
	_tables[key] = out
	return out


func _setp(p: StringName, v: float) -> void:
	if p == &"":
		return
	var last: Variant = _written.get(p)
	if last == null or absf(float(last) - v) > 1e-6:
		tree.set(p, v)
		_written[p] = v


func _anim_player() -> AnimationPlayer:
	if tree == null or tree.anim_player.is_empty():
		return null
	return tree.get_node_or_null(tree.anim_player) as AnimationPlayer


func _trace_add(kind: String, info: Dictionary) -> void:
	info["t"] = _time
	info["kind"] = kind
	_trace.append(info)
	if _trace.size() > TRACE_MAX:
		_trace.pop_front()


func _warn(key: String, msg: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning(msg)
