class_name ThrowChain
extends RefCounted
## The thrown weapons' throw on the Actor_B rig (THROW work package; throwables_design.md 3.2-3.5):
## the graph's aimed throw chain played on the TU / TL chains TreeBuilder._build_throw adds for the
## pick-up weapon-base profiles (spear, tomahawk, atlatl). UpperBody owns one and forwards the
## weapon events; gameplay owns the timing (plan G7): Throwable's signals are unchanged.
##
## Wind-up (graph default): the graph's aim-in, the aim-idle crossfade. While the weapon winds up
## (Throwable.wants_aim()), UpperBody's aim tree (1h-aim-throw-idle: the cocked pose, with the pitch
## additives) comes in at Weapon.aim like every other weapon's raise and holds the cocked pose;
## this chain stays NONE (every TU input on "pass") until the throw request.
##
## States (graph records in the `transitions` table of actor_b_graph.json):
##   WINDUP     only with options.throw_windup_raise (off; on through the opt-in gameplay override
##              PlayerAnim.override_throw_windup_raise, Frontier-only): while the weapon winds up the
##              graph's raise clip (throw-object-aim, 1h-aim-throw^aim) plays on the upper body,
##              seeked by Weapon.charge_amount() (TimeScale 0), so the arm draws back into the cocked
##              aim pose as power builds; it fades in over tuning throw_windup_fade_s. Full charge
##              hands over to the aim tree (the aim loop) over throw_aim_to_aimidle's 0.2 s (HOLD). A
##              let-down (RMB / R, sprint: Weapon.action_cancelled, or the wind-up ending without a
##              throw) fades it out over aimidle_to_idle's 0.6 s.
##   RAISE_OUT  (only after WINDUP) the running throw's graph path: a throw released while moving
##              with the raise not finished plays the rest of the raise at the throw rate (aim-run ->
##              throw-object-aim, throw_raise_from_aimrun) and enters the release at its end with
##              fade 0 (throw_raise_to_start, auto at phase 1).
##   START      release-start (0.2 s), entered from the aim pose over 0.2 s (request "throw":
##              throw_from_aimidle 0x00037fb0 standing, throw_from_aimrun 0x00030930 moving).
##   END        release-end (0.6 s), entered at the start's end with fade 0 (throw_start_to_end). The
##              object leaves the hand throw.release.clip_s (0.05 s at 1x) into it: `released` fires
##              on the first frame at or past it and PlayerAnim calls Throwable.release_from_animation().
##              Exits in the graph's record order: phase >= 0.8, request idle -> RECOVER over 0.2 s
##              (throw_end_to_recover), or, winding again, request aim -> the aim tree over 0.2 s
##              (throw_end_to_aim: the ^aim clip has no Actor_B action); from phase 0 a crouch toggle
##              -> out over 0.5 s (throw_end_crouch_change) or movement starting (run-fw /
##              change-move-mode requests) -> out over 0.4 s (throw_end_to_move).
##   RECOVER    release-end^idle, back to the carry (with its graph layers: the 1h carry arm). Exits:
##              from phase 0.1 a crouch toggle -> 0.5 s (throw_recover_crouch_change) or movement
##              starting -> 0.4 s (throw_recover_to_move); phase >= 0.6 -> out over 0.4 s
##              (throw_recover_auto_idle).
##   EXIT       fading back to the pose below (the aim tree / carry), NONE once there.
## Held requests: a crouch toggle (the graph's crouch_change_pending with its change-move-mode
## request) or a movement start during RAISE_OUT, START or RECOVER before phase 0.1 (states with no
## such exit) is held until the first state that has the exit takes it: END at once, RECOVER at
## phase 0.1, as the graph keeps crouch_change_pending and its requests until a record consumes them
## (LocoBrain holds them the same way). A held movement start lapses when the body stops before then
## (the graph's move exits need move_speed > 0).
## Full body vs upper body: the graph's throw states are full-body states. A throw that starts while
## the lower body stands (IDLE / AIM_IDLE / TURN, not moving) plays the throw clips on the legs and
## root too (TL at the TU weights); a throw started while moving keeps the locomotion legs (TU only:
## the masked upper body over the aim-walk / run locomotion, Frontier requirement: the feet stay
## planted). Movement starting during a standing throw leaves the throw over the graph's 0.4 s
## (from release-end on, held until then; the state has no earlier exit). The legs' part leaves at
## once whenever the body moves or leaves the ground (over the move exit's 0.4 s / take-off's
## 0.1 s) or the stance changes (over the crouch-change exit's 0.5 s): Frontier moves and crouches
## the body by physics (capsule and camera at once), so standing throw legs on a moving or crouched
## body would slide or stand tall (the source game's body follows the clip); the lower body's own
## crouch change shows through as they fade.
## Rate: gameplay's throw action lasts release_time + follow_time; release-start + release-end play
## over it (Throwable.throw_anim_rate()), so the release frame lands on release_time. The recover
## plays at 1x (outside the action). The weapon's `fired` is not a gun shot here: no fire additive.
##
## States, records and asset ids stay in actor_b_graph.json (throw, transitions).

## The release frame: weapon_key is the graph key of the weapon that throws.
signal released(weapon_key: StringName)

const NONE := &"NONE"
const WINDUP := &"WINDUP"
const HOLD := &"HOLD"
const RAISE_OUT := &"RAISE_OUT"
const START := &"START"
const END := &"END"
const RECOVER := &"RECOVER"
const EXIT := &"EXIT"
const PASS := &"pass"
const STILL_STATES := [&"IDLE", &"AIM_IDLE", &"TURN"]
const RATE_MIN := 0.25
const RATE_MAX := 4.0
const TRACE_MAX := 32

var data: AnimGraphData
var tree: AnimationTree
var index: TreeIndex
## The TU selector (TreeIndex.throw.inputs_u); TL amounts are written from it (x lower_w).
var U: XFadeSelector
var weapon := &""
var stance := "stand"
var state: StringName = NONE
## Graph weight of the full-body (lower) part: 1 for a throw started standing, else 0.
var lower_w := 0.0
var _lower_target := 0.0
var _lower_rate := INF
## Throw playback rate (release-start + release-end over the action's duration).
var rate := 1.0
## The release event of the current throw fired (or was suppressed: cancel, death, switch).
var released_done := true
## Off: no wind-up raise whatever options.throw_windup_raise says (tests). The option itself is read
## live (off by default: the graph's aim-in; PlayerAnim.override_throw_windup_raise turns it on).
var windup_raise := true
var time_in_state := 0.0

var _parts := {}                 ## "<w>/<st>/<part>" -> TreeIndex.throw.parts record
var _cur := {}                   ## part -> record of the throw in progress (fixed at its start)
var _cur_w := &""
var _cur_stance := ""
var _moving_prev := false
var _stance_prev := ""
## Held requests of the throw in progress (see the header): a crouch toggle / a movement start not
## yet taken by a state with that exit.
var _stance_pending := false
var _move_pending := false
var _end_entered := false
var _roots := {}                 ## TU node -> {anim: Animation, track: int}
## TU node -> normalized position sought this frame: a TimeSeek applies at the next advance, so
## until then the input's current_position is stale (the last throw's).
var _sought := {}
var _l_written := PackedFloat64Array()
var _trace: Array = []
var _time := 0.0


func _init(p_data: AnimGraphData, p_tree: AnimationTree, p_index: TreeIndex) -> void:
	data = p_data
	tree = p_tree
	index = p_index
	var th: Dictionary = index.throw
	_parts = th.get("parts", {})
	U = XFadeSelector.new(tree, "TU", th.get("inputs_u", PackedStringArray()), th.get("seek_u", {}))
	_l_written.resize(maxi(th.get("inputs_l", PackedStringArray()).size(), 1))
	_l_written.fill(NAN)
	var ap := _anim_player()
	for k in _parts:
		var r: Dictionary = _parts[k]
		var node: String = r.u.node
		if _roots.has(node) or ap == null:
			continue
		var p := data.godot_anim(String(r.clip))
		if ap.has_animation(p):
			var a := ap.get_animation(p)
			var tr := a.find_track(NodePath("%s:root" % index.skeleton_path), Animation.TYPE_ROTATION_3D)
			if tr >= 0:
				_roots[node] = {"anim": a, "track": tr}


## True when the tree has the throw chain for graph weapon `w`.
func handles(w: StringName) -> bool:
	return _parts.has("%s/stand/start" % w) or _parts.has("%s/crouch/start" % w)


func set_weapon(w: StringName) -> void:
	if w == weapon:
		return
	weapon = w
	if state != NONE and state != EXIT:
		_out(float(data.tuning("weapon_fade_s", 0.25)), "weapon_change", "")
		released_done = true


## Weapon.action_started("throw", duration) of weapon `w`. lower_state / moving: LocoBrain's.
func on_throw(w: StringName, duration: float, lower_state: StringName, moving: bool) -> bool:
	if not handles(w):
		return false
	var st := stance
	var cur := {}
	for part in ["raise", "start", "end", "recover"]:
		var r: Dictionary = _parts.get("%s/%s/%s" % [w, st, part], {})
		if not r.is_empty():
			cur[part] = r
	if not cur.has("start") or not cur.has("end"):
		return false
	var chain_len := float(cur.start.length) + float(cur.end.length)
	rate = clampf(chain_len / maxf(duration, 1e-3), RATE_MIN, RATE_MAX)
	var standing := not moving and lower_state in STILL_STATES
	lower_w = 1.0 if standing else 0.0
	_lower_target = lower_w
	var raise_w := U.weight(StringName(cur.raise.u.node)) if cur.has("raise") else 0.0
	var raise_pos := _pos(cur.raise) if cur.has("raise") else 1.0
	_cur = cur
	_cur_w = w
	_cur_stance = st
	_end_entered = false
	released_done = false
	_stance_pending = false
	_move_pending = false
	if not standing and state == WINDUP and raise_w > 0.05 and raise_pos < 0.999 and cur.has("raise"):
		# The running throw's graph path: finish the raise (throw-object-aim) at the throw rate, then
		# the release (fade 0 at its phase 1).
		_set_ts(cur.raise, rate / maxf(float(cur.raise.length), 1e-3))
		_go(RAISE_OUT, "throw_raise_from_aimrun", {"raise_pos": raise_pos})
		return true
	var key := "throw_from_aimidle" if standing else "throw_from_aimrun"
	_enter(cur.start, float(data.transition_use(key).get("fade_s", 0.2)), 0.0)
	_go(START, key, {"standing": standing, "rate": rate})
	return true


## Weapon.action_cancelled: a let-down during the wind-up, or the weapon put away mid-throw.
func on_cancel(w: StringName) -> void:
	if state == NONE or state == EXIT:
		return
	if state in [WINDUP, HOLD, RAISE_OUT]:
		_out(float(data.transition_use("aimidle_to_idle").get("fade_s", 0.6)), "aimidle_to_idle", "cancel")
	else:
		_out(float(data.tuning("weapon_fade_s", 0.25)), "", "cancel_mid_throw")
	released_done = true


## A heavy hit (the full-body hit reaction is entered by code from any state): the throw goes over
## any_to_hit's fade. A release not reached yet falls back to the weapon's timer.
func on_heavy_hit() -> void:
	if state != NONE and state != EXIT:
		_out(float(data.transition_use("any_to_hit").get("fade_s", 0.1)), "any_to_hit", "heavy_hit")


func on_died() -> void:
	if state != NONE:
		_out(float(data.transition_use("any_to_death").get("fade_s", 0.2)), "any_to_death", "died")
	released_done = true


## Per frame, before advance(). inp.wants_aim / charge come from the weapon (Throwable: winding or
## releasing / the wind-up charge).
func tick(inp: AnimInputs, st: String, lower_state: StringName, moving: bool, dt: float) -> void:
	_time += dt
	time_in_state += dt
	stance = st
	var thr := handles(weapon)
	# Winding up: Throwable.wants_aim() also covers the release, charge_amount() only the wind-up.
	var winding := thr and inp != null and inp.wants_aim and inp.alive and inp.charge > 0.0
	var charge := clampf(inp.charge, 0.0, 1.0) if inp != null else 0.0
	var move_edge := moving and not _moving_prev
	var stance_edge := _stance_prev != "" and st != _stance_prev
	# Held requests (header): a crouch toggle or a movement start in a throw state waits for the
	# first state with that exit.
	if state in [RAISE_OUT, START, END, RECOVER]:
		if stance_edge and not _stance_pending:
			_stance_pending = true
			_trace_add("held", {"request": "crouch_change", "in": String(state)})
		if move_edge and not _move_pending:
			_move_pending = true
			_trace_add("held", {"request": "move", "in": String(state)})
	if _move_pending and not moving:
		_move_pending = false    # the graph's move exits need move_speed > 0
	var airborne := inp != null and not inp.on_floor
	var restance := _cur_stance != "" and st != _cur_stance
	if _lower_target > 0.0 and state != NONE and (moving or airborne or restance):
		_lower_target = 0.0
		var lk := "throw_end_to_move" if moving else ("ground_to_takeoff" if airborne else "throw_end_crouch_change")
		_lower_rate = 1.0 / maxf(float(data.transition_use(lk).get("fade_s", 0.4)), 1e-3)
		_trace_add("legs_out", {"key": lk})
	if lower_w != _lower_target:
		lower_w = _lower_target if is_inf(_lower_rate) else move_toward(lower_w, _lower_target, dt * _lower_rate)
	match state:
		NONE, EXIT, RECOVER:
			if winding and windup_raise and bool(data.option("throw_windup_raise", false)) and charge < 1.0:
				var r: Dictionary = _parts.get("%s/%s/raise" % [weapon, st], {})
				if not r.is_empty():
					_set_ts(r, 0.0)
					U.request(StringName(r.u.node), float(data.tuning("throw_windup_fade_s", 0.2)), charge)
					U.seek(StringName(r.u.node), charge)
					_sought[String(r.u.node)] = charge
					_cur = {"raise": r}
					_cur_w = weapon
					_cur_stance = st
					_go(WINDUP, "", {"charge": charge})
			if state == RECOVER:
				var p := _pos(_cur.get("recover", {}))
				var gate := float(data.transition_use("throw_recover_to_move").get("gate_phase", 0.1))
				if p >= gate and (_move_pending or _stance_pending):
					if _stance_pending:
						_out(float(data.transition_use("throw_recover_crouch_change").get("fade_s", 0.5)), "throw_recover_crouch_change", "")
					else:
						_out(float(data.transition_use("throw_recover_to_move").get("fade_s", 0.4)), "throw_recover_to_move", "")
				elif p >= float(data.transition_use("throw_recover_auto_idle").get("gate_phase", 0.6)):
					_out(float(data.transition_use("throw_recover_auto_idle").get("fade_s", 0.4)), "throw_recover_auto_idle", "")
			elif state == EXIT and U.weight(PASS) >= 1.0:
				_go(NONE, "", {})
		WINDUP:
			var r: Dictionary = _cur.get("raise", {})
			if not winding or r.is_empty():
				_out(float(data.transition_use("aimidle_to_idle").get("fade_s", 0.6)), "aimidle_to_idle", "let_down")
			elif st != _cur_stance:
				var r2: Dictionary = _parts.get("%s/%s/raise" % [weapon, st], {})
				if not r2.is_empty():
					_set_ts(r2, 0.0)
					U.request(StringName(r2.u.node), float(data.tuning("stance_fade_s", 0.25)), charge)
					U.seek(StringName(r2.u.node), charge)
					_sought[String(r2.u.node)] = charge
					_cur = {"raise": r2}
					_cur_stance = st
			elif charge >= 1.0:
				U.request(PASS, float(data.transition_use("throw_aim_to_aimidle").get("fade_s", 0.2)))
				_go(HOLD, "throw_aim_to_aimidle", {})
			else:
				U.seek(StringName(r.u.node), charge)
				_sought[String(r.u.node)] = charge
		HOLD:
			if not winding:
				_go(NONE, "", {})
		RAISE_OUT:
			var r: Dictionary = _cur.get("raise", {})
			var nxt := _pos(r) + dt * _ts(r)
			if r.is_empty() or nxt >= 1.0:
				var over := maxf(nxt - 1.0, 0.0) * float(r.get("length", 0.2)) / maxf(float(_cur.start.length), 1e-3)
				_enter(_cur.start, float(data.transition_use("throw_raise_to_start").get("fade_s", 0.0)), minf(over, 0.99))
				_go(START, "throw_raise_to_start", {})
		START:
			var nxt := _pos(_cur.start) + dt * _ts(_cur.start)
			if nxt >= 1.0:
				var over := (nxt - 1.0) * float(_cur.start.length) / maxf(float(_cur.end.length), 1e-3)
				_enter(_cur.end, float(data.transition_use("throw_start_to_end").get("fade_s", 0.0)), minf(over, 0.99))
				_end_entered = true
				_go(END, "throw_start_to_end", {})
		END:
			# The graph's record order: request aim / idle at phase >= 0.8 first, then (phase >= 0)
			# the movement / crouch-change exits, then the auto exit at 0.9.
			var p := _pos(_cur.end)
			var gated := p >= float(data.transition_use("throw_end_to_recover").get("gate_phase", 0.8))
			if gated and winding:
				# throw-object-aim^aim has no Actor_B clip: back into the aim tree over its 0.2 s.
				_out(float(data.transition_use("throw_end_to_aim").get("fade_s", 0.2)), "throw_end_to_aim", "missing_clip_fallback")
			elif gated and _cur.has("recover"):
				_set_ts(_cur.recover, 1.0 / maxf(float(_cur.recover.length), 1e-3))
				U.seek(StringName(_cur.recover.u.node), 0.0)
				U.request(StringName(_cur.recover.u.node), float(data.transition_use("throw_end_to_recover").get("fade_s", 0.2)), 0.0)
				_sought[String(_cur.recover.u.node)] = 0.0
				_go(RECOVER, "throw_end_to_recover", {})
			elif _stance_pending:
				_out(float(data.transition_use("throw_end_crouch_change").get("fade_s", 0.5)), "throw_end_crouch_change", "")
			elif _move_pending:
				_out(float(data.transition_use("throw_end_to_move").get("fade_s", 0.4)), "throw_end_to_move", "")
			elif p >= float(data.transition_use("throw_end_auto_idle").get("gate_phase", 0.9)):
				_out(float(data.transition_use("throw_end_auto_idle").get("fade_s", 0.4)), "throw_end_auto_idle", "")
	_moving_prev = moving
	_stance_prev = st
	U.update(dt)
	U.write()
	_write_lower()


## After advance(): the release frame.
func post_advance() -> void:
	_sought.clear()
	if released_done or not _end_entered or _cur.is_empty() or not _cur.has("end"):
		return
	var rel: Dictionary = index.throw.get("release", {})
	var at := float(rel.get("clip_s", 0.05)) / maxf(float(_cur.end.length), 1e-3)
	if _pos(_cur.end) >= at - 1e-4:
		released_done = true
		_trace_add("release", {"weapon": String(_cur_w), "phase": _pos(_cur.end)})
		released.emit(_cur_w)


## Summed weight of the throw inputs on the upper body (0 = only the pose below).
func weight() -> float:
	return clampf(1.0 - U.weight(PASS), 0.0, 1.0)


## Root rotation of the weighted throw clips at their live positions (the AimStabilizer's reference
## while they cover the upper body: their upper body is authored over their own root).
func root_ref() -> Quaternion:
	var acc := Vector4.ZERO
	var ref := Quaternion.IDENTITY
	var have := false
	var ws := U.weights()
	for id in ws:
		var w := float(ws[id])
		if w <= 0.0 or id == PASS or not _roots.has(String(id)):
			continue
		var r: Dictionary = _roots[String(id)]
		var a: Animation = r.anim
		var pos := _pos_node(String(id))
		var q: Quaternion = a.rotation_track_interpolate(r.track, clampf(pos, 0.0, 1.0) * a.length)
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


## Normalized phase of the current throw's part ("raise", "start", "end", "recover"); -1 when none.
func part_phase(part: String) -> float:
	var r: Dictionary = _cur.get(part, {})
	return _pos(r) if not r.is_empty() else -1.0


func snapshot() -> Dictionary:
	return {"state": String(state), "weapon": String(weapon), "throw_weapon": String(_cur_w), "stance": _cur_stance,
			"rate": rate, "lower_w": lower_w, "weight": weight(), "released": released_done, "U": U.snapshot(),
			"held": {"crouch_change": _stance_pending, "move": _move_pending},
			"windup_raise": windup_raise and bool(data.option("throw_windup_raise", false)),
			"phases": {"raise": part_phase("raise"), "start": part_phase("start"), "end": part_phase("end"),
					"recover": part_phase("recover")}, "time_in_state": time_in_state, "trace": _trace.duplicate()}


# --- internals ---------------------------------------------------------------------------------

func _enter(r: Dictionary, fade: float, seek_to: float) -> void:
	_set_ts(r, rate / maxf(float(r.length), 1e-3))
	var id := StringName(r.u.node)
	U.seek(id, seek_to)
	U.request(id, fade, seek_to)
	_sought[String(r.u.node)] = seek_to


func _out(fade: float, key: String, why: String) -> void:
	U.request(PASS, fade)
	_stance_pending = false
	_move_pending = false
	_go(EXIT, key, {"why": why, "fade": fade})


func _go(s: StringName, key: String, info: Dictionary) -> void:
	info["from"] = String(state)
	info["to"] = String(s)
	info["key"] = key
	if key != "":
		var tr := data.transition(key)
		var g: Variant = tr.get("graph")
		info["record"] = String(g.get("record", "")) if g is Dictionary else ""
	_trace_add("state", info)
	state = s
	time_in_state = 0.0


func _set_ts(r: Dictionary, scale: float) -> void:
	if r.is_empty():
		return
	tree.set(r.u.ts, scale)
	if r.has("l"):
		tree.set(r.l.ts, scale)


func _ts(r: Dictionary) -> float:
	return float(tree.get(r.u.ts)) if not r.is_empty() else 0.0


func _pos(r: Dictionary) -> float:
	if r.is_empty():
		return 0.0
	if _sought.has(String(r.u.node)):
		return float(_sought[String(r.u.node)])
	return float(tree.get(r.u.position_node))


func _pos_node(node: String) -> float:
	if _sought.has(node):
		return float(_sought[node])
	for k in _parts:
		if String(_parts[k].u.node) == node:
			return float(tree.get(_parts[k].u.position_node))
	return 0.0


## TL amounts: each full-body input at its TU weight x lower_w, "pass" the rest (XFadeSelector's
## chain formula amount_k = w_k / sum_{j<=k} w_j).
func _write_lower() -> void:
	var th: Dictionary = index.throw
	var names: PackedStringArray = th.get("inputs_l", PackedStringArray())
	var chain: Array = th.get("chain_l", [])
	if names.size() < 2:
		return
	var ws := PackedFloat64Array()
	ws.resize(names.size())
	var sum := 0.0
	for k in range(1, names.size()):
		var w := 0.0
		for pk in _parts:
			var r: Dictionary = _parts[pk]
			if r.has("l") and String(r.l.node) == names[k]:
				w = U.weight(StringName(r.u.node)) * lower_w
				break
		ws[k] = w
		sum += w
	ws[0] = maxf(1.0 - sum, 0.0)
	var cum := ws[0]
	for k in range(1, ws.size()):
		cum += ws[k]
		var a := 0.0 if cum < 1e-9 else clampf(ws[k] / cum, 0.0, 1.0)
		var last := _l_written[k]
		if is_nan(last) or absf(a - last) > 1e-5 or (a != last and (a == 0.0 or a == 1.0)):
			tree.set(chain[k - 1], a)
			_l_written[k] = a


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
