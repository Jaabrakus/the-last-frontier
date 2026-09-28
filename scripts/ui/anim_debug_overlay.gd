class_name AnimDebugOverlay
extends CanvasLayer
## Animation debug overlay (plan section 9, WP8). Three panels over the game view, drawn from
## PlayerAnim.debug_snapshot() (the plan's pure-data contract); only the exit-gate countdown also
## reads the static graph table (graph_states records, transition rows with their overrides).
##
##   1 inputs and fields   every AnimInputs field of the frame (with the fields that came from a
##                         fallback), then the derived graph runtime fields, each with its graph field
##                         label: `move_dir 45.0 (f32@C0+144)`; fields without a label (added later)
##                         are listed after them
##   2 weights             lower state, graph state and input, a live countdown to the state's next
##                         exit gate (phase or frame gate of its graph records), bars per selector
##                         input (L, the hemi of each weighted bank, A, G, W), the active OneShots
##                         (clip, position / length, rate), the weighted lower slots and the last
##                         transitions (frame, states, transitions key, graph record, graph / used
##                         fade, status: the --anim-trace fields)
##   3 provenance          the dominant lower clip and the aim base: graph state and offset, leaf and
##                         leaf ID, overlay chain (set, record offset, from / to IDs), layers (weight and
##                         lambda source) and native_asset_id, with the source attribution; it ends
##                         above the crosshair (long entries are compacted, then cut, see
##                         format_provenance and _fit_provenance)
##
## Keys (InputSetup actions, rebindable in Project Settings > Input Map; function keys only, so
## they cannot collide with the game controls or the HUD's F3). They do nothing unless
## `debug_build` (OS.is_debug_build(); player.gd creates the overlay in debug builds only):
##   F4  anim_debug       show / hide the panels (F3 stays the HUD's debug line)
##   Shift+F5  anim_freeze      freeze / resume the animation: PlayerAnim stops sampling and advancing
##                        (auto_process off) and the AimStabilizer's aim-trim residual is held, so
##                        the rendered pose stays put relative to the body while it turns; the
##                        game itself keeps running
##   F6  anim_step        freeze and advance the animation by exactly 1/60 s (hold to repeat)
##   F7  anim_slowmo      Engine.time_scale 1 -> 0.25 -> 0.1 -> 1 (the whole game)
##   F8  anim_options     compare the gameplay overrides and runtime options with the graph
##                        defaults, one at a time: each press restores the previous item and flips
##                        the next; after the last item everything is back as it was (also when
##                        the overlay is freed or bound to another PlayerAnim mid-cycle)
##   Shift+F9  debug_hit_light  light hit on the player (from front, right, back, left in turn)
##   F10 debug_hit_heavy  heavy hit
##   F11 debug_death      death
##   F12 debug_respawn    respawn / revive
## The hits go through the player's apply_hit() / respawn() when it has them (WP7), else straight
## to PlayerAnim.play_hit / play_death / revive.
## macOS: function keys need fn unless "Use F1, F2, etc. keys as standard function keys" is on,
## and F11 is Show Desktop by default. The row of buttons under panel 2 does the same as the keys
## once the mouse is free (Esc); the buttons take no keyboard focus and ignore the mouse while it
## is captured, so Space / Enter and clicks at the crosshair never press them.
##
## The provenance panel shows the graph table's IDs and record offsets as stored.

const STEP_DT := 1.0 / 60.0
const TIME_SCALES := [1.0, 0.25, 0.1]
const ACTIONS := ["anim_debug", "anim_freeze", "anim_step", "anim_slowmo", "anim_options",
		"debug_hit_light", "debug_hit_heavy", "debug_death", "debug_respawn"]
## Options F8 leaves out: aim_walk changes the tree layout (it needs a new PlayerAnim setup; WP10
## adds an F8 item that re-runs setup with it flipped and restores it at the end of the cycle,
## plan WP10 acceptance), pistol_sub_type is not a toggle, holster is the instant_weapon_switch
## override.
const OPTION_SKIP := ["aim_walk", "holster", "pistol_sub_type"]
## Where a debug hit comes from, in turn (x right, y forward).
const HIT_DIRS := [["front", Vector2(0, 1)], ["right", Vector2(1, 0)], ["back", Vector2(0, -1)], ["left", Vector2(-1, 0)]]
const LIGHT_DAMAGE := 10.0
## Plan 8.1: the player's hit is heavy when amount >= 40.
const HEAVY_DAMAGE := 45.0
const DEATH_DAMAGE := 100000.0
const LAYER := 20
## Font size at 720 px viewport height (scaled with the height, up to x1.75).
const FONT_SIZE := 10
const BAR_N := 14
const MAX_ROWS := 6
const MAX_TRACE := 4

## AnimInputs lines of panel 1: each [field, short label]; unknown fields go to an "other" line.
const INPUT_LINES := [
	[["velocity_local", "vel"], ["wish_local", "wish"]],
	[["speed", "speed"], ["target_speed", "target"], ["vertical_speed", "vy"]],
	[["on_floor", "floor"], ["air_time", "air"], ["last_air_vy", "last_air_vy"]],
	[["crouched", "crouch"], ["walking", "walk"], ["sprinting", "sprint"], ["alive", "alive"]],
	[["weapon_key", ""], ["weapon_aim", "aim"], ["wants_aim", "wants"], ["steady_aim", "steady"], ["busy", "busy"]],
	[["charge", "charge"], ["aim_elev_deg", "aim_elev"], ["aim_pitch", "pitch"]],
	[["blocked_hit_m", "blocked_hit"], ["yaw", "yaw"], ["yaw_rate", "yaw_rate"]],
]
## Input fields panel 1 does not list (shown elsewhere or not scalar).
const INPUT_SKIP := ["frame", "dt", "events", "fallbacks", "aim_point"]
## Graph-field rows of panel 1: [label, [derived fields], graph field or note] (plan section 7).
const FIELD_ROWS := [
	["moving", ["moving"], "f32@C0+120 > 0"],
	["move_speed", ["move_speed"], "f32@C0+120"],
	["move_dir", ["move_dir_deg"], "f32@C0+144"],
	["blend_angle", ["blend_deg"], "f32@C8+4"],
	[" fw / bw chain", ["blend_pos_fw", "blend_pos_bw"], "lerp-scale input"],
	["hemi", ["hemi"], "97.5 / 82.5 deg"],
	["use_transition_anims", ["use_transition_anims"], "i32@C0+128"],
	["loco_enabled", ["loco_enabled"], "i32@C0+132"],
	["crouch_change", ["crouch_change_pending"], "i32@C0+136"],
	["turn_delta", ["turn_delta_deg"], "f32@C0+124"],
	["idle_turn", ["idle_turn_deg"], "f32@C0+160"],
	["weapon_blocked", ["blocked_w"], "f32@C8+172"],
	["aim_up / down", ["up_w", "down_w"], "f32@C8+248 / f32@C8+252"],
	["move_mode", ["anim_mode"], "mode record +0x40"],
	["walk/run split", ["mode_split_mps"], "m/s"],
	["speed_ratio", ["ratio"], "calc-new-phase-from-speed"],
	["rate fw / bw", ["rate_fw", "rate_bw"], "cycles/s"],
	["gait_phase", ["gait_phase"], "calc-ankle-match-phase"],
	["upper_aim_w", ["upper_aim_w"], "U_aim, Weapon.aim"],
	["aim_stance", ["aim_stance"], "aim-idle / aim-run"],
	["suppress", ["suppress"], "heavy hit, death"],
	["pitch_elev", ["elev_deg"], "deg"],
	["stabilizer", ["stabilizer_deg"], "deg"],
	["aim_trim", ["trim_deg"], "deg yaw, pitch"],
	["charge", ["charge"], "C_add, bow"],
]
## Panel widths in characters (fields, weights, provenance) at the base font size.
const PANEL_CHARS := [54, 56, 82]
## Overlay set names start with this; panel 3 shows them without it.
const SET_PREFIX := "anim-overlay-player-"
## Panel 3 ends this far above the screen centre (px at 720, scaled like the font): the crosshair
## dot and its hit marks (17 px diagonal) stay clear of the panel's background.
const CROSSHAIR_GAP := 28.0
## format_provenance levels tried, fullest first, before panel 3 is cut to its height.
const PROV_LEVELS := 4
## Chain steps and layers per compacted entry (format_provenance levels 2 and 3).
const PROV_COMPACT := 2

## Show the panels (F4).
var shown := false
## Stub for tests: the keys and buttons do nothing when false (release builds).
var debug_build := OS.is_debug_build()
## Panel refresh rate (Hz) while shown; a key press refreshes at once.
@export var refresh_hz := 15.0
## Test hook: lay the panels out for this viewport size instead of the real one (the headless
## root viewport is 64x64). Zero = the real viewport.
var layout_size := Vector2.ZERO
## Panel 3's fit: the format_provenance level in use and whether it was cut to its height.
var provenance_level := 0
var provenance_clipped := false

var anim: PlayerAnim
var player: Node
## F5 / F6: PlayerAnim's auto_process is off while frozen.
var frozen := false
## Index into TIME_SCALES (F7).
var time_scale_index := 0
## F8: 0 = the state the cycle started from, k = item k-1 flipped (see option_items()).
var option_index := 0
## Last debug key action, for the status line and tests.
var last_action := ""

var _root: Control
var _panels: Array[PanelContainer] = []
var _texts: Array[RichTextLabel] = []
var _status: Label
var _buttons: HBoxContainer
var _font: Font
var _bold: Font
var _snap: Dictionary = {}
var _since := 0.0
var _dirty := true
var _prev_auto := true
## The AimStabilizer held while frozen and its trim_hold before the freeze (see set_frozen).
var _held_stab: AimStabilizer
var _prev_hold := false
var _base_time_scale := 1.0
var _time_scale_set := false
var _opt_items: Array = []
var _hit_i := 0
var _scale := 0.0
var _captured := -1
var _prov_snap: Dictionary = {}
var _prov_fit := Vector3(-1, -1, -1)   ## (viewport w, h, scale) the provenance text was fitted for
var _prov_hash := 0                    ## hash of the snapshot parts panel 3 shows (refit on change)


## Creates the overlay on `p` (the player: a node with `anim`) in debug builds, or returns the one
## it already has; null in release builds.
static func attach(p: Node) -> AnimDebugOverlay:
	if p == null or not OS.is_debug_build():
		return null
	for c in p.get_children():
		if c is AnimDebugOverlay:
			return c
	var o := AnimDebugOverlay.new()
	o.name = "AnimDebugOverlay"
	p.add_child(o)
	var a: Variant = p.get("anim")
	if a is PlayerAnim:
		o.bind(a)
	return o


func _init() -> void:
	layer = LAYER
	process_priority = 200   # after PlayerAnim (100): the panels show this frame's step


func _ready() -> void:
	InputSetup.ensure()
	_build_ui()
	_apply_visibility()
	get_viewport().size_changed.connect(_layout)


func _exit_tree() -> void:
	_restore_option()
	if frozen:
		set_frozen(false)
	if _time_scale_set:
		Engine.time_scale = _base_time_scale
		_time_scale_set = false
		time_scale_index = 0


## The PlayerAnim to show and drive (the player's `anim`).
func bind(p_anim: PlayerAnim) -> void:
	_restore_option()
	if frozen:
		set_frozen(false)
	anim = p_anim
	player = anim.player if anim != null else null
	option_index = 0
	_opt_items = []
	_dirty = true


# --- keys and actions ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not debug_build or not (event is InputEventKey or event is InputEventJoypadButton):
		return
	for a in ACTIONS:
		if InputMap.has_action(a) and event.is_action_pressed(a, a == "anim_step"):
			get_viewport().set_input_as_handled()
			run_action(a)
			return


## Runs a debug action by its InputSetup name (keys and buttons). No-op unless debug_build.
func run_action(action: String) -> void:
	if not debug_build:
		return
	match action:
		"anim_debug":
			toggle()
		"anim_freeze":
			set_frozen(not frozen)
		"anim_step":
			step_once()
		"anim_slowmo":
			cycle_time_scale()
		"anim_options":
			cycle_options()
		"debug_hit_light":
			debug_hit(false)
		"debug_hit_heavy":
			debug_hit(true)
		"debug_death":
			debug_death()
		"debug_respawn":
			debug_respawn()
		_:
			return
	_dirty = true


func toggle(on: Variant = null) -> void:
	shown = (not shown) if on == null else bool(on)
	last_action = "panels %s" % ("on" if shown else "off")
	_dirty = true
	_apply_visibility()


## Freeze: PlayerAnim neither samples nor advances (tree speed 0); the pose holds. Resume
## restores its auto_process.
## The AimStabilizer (a SkeletonModifier3D) still runs every frame after the frozen pose. Its
## closed-loop aim trim solves toward a world-space target, so turning the body while frozen
## would swing the rendered upper body and weapon back toward the old aim point; the freeze
## therefore also holds its residual (trim_hold) and resume puts the previous value back.
func set_frozen(on: bool) -> void:
	if on == frozen:
		return
	if anim == null or not is_instance_valid(anim):
		frozen = false
		_release_stabilizer()
		return
	if on:
		_prev_auto = anim.auto_process
		anim.auto_process = false
		_hold_stabilizer()
	else:
		anim.auto_process = _prev_auto
		_release_stabilizer()
	frozen = on
	last_action = "frozen" if on else "resumed"
	_dirty = true


## One animation frame of exactly STEP_DT (freezes first when running): the physics sampler and
## the frame, as PlayerAnim's own _physics_process and _process would run them. The stabilizer's
## residual learns for that one frame too (its next modification), then is held again.
func step_once() -> void:
	if anim == null or not is_instance_valid(anim) or not anim.is_ready():
		return
	if not frozen:
		set_frozen(true)
	anim.sample_inputs(STEP_DT)
	anim.manual_step(STEP_DT)
	_step_stabilizer()
	last_action = "step %.4f s (frame %d)" % [STEP_DT, anim.frame]
	_dirty = true


## Freeze: hold the stabilizer's closed-loop residual (remembers its trim_hold for resume).
func _hold_stabilizer() -> void:
	_release_stabilizer()
	var s: AimStabilizer = anim.stabilizer if anim != null and is_instance_valid(anim) else null
	if s == null or not is_instance_valid(s):
		return
	_held_stab = s
	_prev_hold = s.trim_hold
	s.trim_hold = true


## Resume (also bind() and _exit_tree() through set_frozen(false)): the saved trim_hold back.
func _release_stabilizer() -> void:
	if _held_stab != null and is_instance_valid(_held_stab):
		var sk := _held_stab.get_skeleton()
		if sk != null and sk.skeleton_updated.is_connected(_rehold_stabilizer):
			sk.skeleton_updated.disconnect(_rehold_stabilizer)
		_held_stab.trim_hold = _prev_hold
	_held_stab = null


## F6: let the residual learn in the stepped frame's modification (the next skeleton update;
## UpperBody.post_advance has just set trim_learn and cleared trim_hold), then hold it again
## once that update has run.
func _step_stabilizer() -> void:
	var s: AimStabilizer = anim.stabilizer if anim != null and is_instance_valid(anim) else null
	if s == null or not is_instance_valid(s):
		return
	if s != _held_stab:
		_hold_stabilizer()   # PlayerAnim rebuilt its stabilizer while frozen
	var sk := s.get_skeleton()
	if sk == null:
		return   # no modification runs without a skeleton: stay held
	s.trim_hold = false
	if not sk.skeleton_updated.is_connected(_rehold_stabilizer):
		sk.skeleton_updated.connect(_rehold_stabilizer, CONNECT_ONE_SHOT)


func _rehold_stabilizer() -> void:
	if frozen and _held_stab != null and is_instance_valid(_held_stab):
		_held_stab.trim_hold = true


## Engine.time_scale 1 -> 0.25 -> 0.1 -> 1.
func cycle_time_scale() -> void:
	if time_scale_index == 0 and not _time_scale_set:
		_base_time_scale = Engine.time_scale
		_time_scale_set = true
	time_scale_index = (time_scale_index + 1) % TIME_SCALES.size()
	if time_scale_index == 0:
		Engine.time_scale = _base_time_scale
		_time_scale_set = false
	else:
		Engine.time_scale = float(TIME_SCALES[time_scale_index])
	last_action = "time scale x%s" % _num(Engine.time_scale)


## The toggles F8 cycles, from a debug_snapshot() "options" block: every bool gameplay override
## and facade option, then the bool graph options no override sets (minus OPTION_SKIP).
## [{name, base, kind: "override" | "option"}], base = the value now.
func option_items(opts: Dictionary) -> Array:
	var out: Array = []
	var by_override := {}
	if anim != null and is_instance_valid(anim) and anim.data != null:
		for flag in anim.data.override_flags():
			for k in anim.data.override_info(flag).get("sets_options", {}):
				by_override[String(k)] = true
	var ov: Dictionary = opts.get("overrides", {})
	var names := ov.keys()
	names.sort()
	for k in names:
		if ov[k] is bool:
			out.append({"name": String(k), "base": bool(ov[k]), "kind": "override"})
	var go: Dictionary = opts.get("options", {})
	names = go.keys()
	names.sort()
	for k in names:
		if go[k] is bool and not String(k) in OPTION_SKIP and not by_override.has(String(k)):
			out.append({"name": String(k), "base": bool(go[k]), "kind": "option"})
	return out


## F8: restore the previous item, flip the next one (applied by PlayerAnim at its next frame).
func cycle_options() -> void:
	if anim == null or not is_instance_valid(anim) or not anim.is_ready():
		return
	if option_index == 0:
		var snap := anim.debug_snapshot()
		_opt_items = option_items(snap.get("options", {}))
	elif option_index - 1 < _opt_items.size():
		var prev: Dictionary = _opt_items[option_index - 1]
		anim.set_option(StringName(prev.name), prev.base)
	option_index = (option_index + 1) % (_opt_items.size() + 1)
	if option_index > 0:
		var it: Dictionary = _opt_items[option_index - 1]
		anim.set_option(StringName(it.name), not bool(it.base))
	last_action = "options: %s" % option_label()


## Ends an F8 cycle: the flipped item back to its start value.
func _restore_option() -> void:
	if option_index > 0 and option_index - 1 < _opt_items.size() and anim != null and is_instance_valid(anim) and anim.is_ready():
		var it: Dictionary = _opt_items[option_index - 1]
		anim.set_option(StringName(it.name), it.base)
	option_index = 0


## Status of the F8 cycle.
func option_label() -> String:
	if option_index == 0 or option_index - 1 >= _opt_items.size():
		return "as set (%d toggles)" % _opt_items.size() if not _opt_items.is_empty() else "as set"
	var it: Dictionary = _opt_items[option_index - 1]
	return "%d/%d %s = %s" % [option_index, _opt_items.size(), it.name, "on" if not bool(it.base) else "off"]


## Light or heavy hit from the next direction in HIT_DIRS.
func debug_hit(heavy: bool) -> void:
	var d: Array = HIT_DIRS[_hit_i % HIT_DIRS.size()]
	_hit_i += 1
	var how := _deliver(HEAVY_DAMAGE if heavy else LIGHT_DAMAGE, d[1])
	if how == "":
		if anim == null or not is_instance_valid(anim):
			return
		anim.play_hit(d[1], heavy)
		how = "PlayerAnim.play_hit"
	last_action = "%s hit from %s (%s)" % ["heavy" if heavy else "light", d[0], how]


func debug_death() -> void:
	var d: Array = HIT_DIRS[_hit_i % HIT_DIRS.size()]
	var how := _deliver(DEATH_DAMAGE, d[1])
	if how == "":
		if anim == null or not is_instance_valid(anim):
			return
		anim.play_death(d[1])
		how = "PlayerAnim.play_death"
	last_action = "death from %s (%s)" % [d[0], how]


func debug_respawn() -> void:
	var how := ""
	if player != null and is_instance_valid(player) and player.has_method("respawn"):
		player.call("respawn")
		how = "player.respawn"
	elif anim != null and is_instance_valid(anim):
		anim.revive()
		how = "PlayerAnim.revive"
	else:
		return
	last_action = "respawn (%s)" % how


## The player's apply_hit(damage, point, direction, source, part) with a hit from local_dir;
## "" when the player has none.
func _deliver(damage: float, local_dir: Vector2) -> String:
	if player == null or not is_instance_valid(player) or not (player is Node3D) or not player.has_method("apply_hit"):
		return ""
	var p3 := player as Node3D
	var b := p3.global_basis
	var from := (b.x * local_dir.x - b.z * local_dir.y).normalized()
	var point := p3.global_position + Vector3.UP * 1.3 + from * 0.3
	player.call("apply_hit", damage, point, -from, self, "body")
	return "player.apply_hit"


# --- frame --------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	# The buttons take clicks only while the mouse is free: a captured mouse sits at the screen
	# centre, where a click is a shot, not a button press.
	var cap := 1 if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else 0
	if _buttons != null and cap != _captured:
		_captured = cap
		for b in _buttons.get_children():
			(b as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE if cap == 1 else Control.MOUSE_FILTER_STOP
	_since += delta / maxf(Engine.time_scale, 1e-3)
	if frozen and (anim == null or not is_instance_valid(anim)):
		frozen = false
		_release_stabilizer()
	_update_status()
	if not shown:
		return
	if _dirty or _since >= 1.0 / maxf(refresh_hz, 0.1):
		refresh()


## Takes a new snapshot and renders it (no-op without a PlayerAnim).
func refresh() -> void:
	_since = 0.0
	_dirty = false
	if anim == null or not is_instance_valid(anim):
		render({"ok": false, "warnings": ["no PlayerAnim bound (AnimDebugOverlay.bind)"]})
		return
	_snap = anim.debug_snapshot()
	render(_snap)


## Fills the three panels from a snapshot (plan section 9 layout). Pure: missing keys show as
## "-", so a stub or a refused setup renders too.
func render(snap: Dictionary) -> void:
	if _texts.is_empty():
		_build_ui()
	var g := gate_countdown(snap)
	_texts[0].text = format_fields(snap)
	_texts[1].text = format_weights(snap, g, _clip_lengths(snap))
	# Panel 3 changes with the lower input or aim base only: refit (format and measure) then.
	var ph := [snap.get("ok"), snap.get("provenance"), snap.get("attribution"), snap.get("authorization")].hash()
	if ph != _prov_hash or _prov_snap.is_empty():
		_prov_hash = ph
		_prov_snap = snap
		_prov_fit = Vector3(-1, -1, -1)
	_layout()


## The three panel containers (fields, weights, provenance).
func panels() -> Array[PanelContainer]:
	return _panels


## The three panels' text without markup.
func panel_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for t in _texts:
		out.append(t.get_parsed_text())
	return out


## The status line (frozen, time scale, F8 item, last action).
func status_text() -> String:
	return _status.text if _status != null else ""


# --- exit gates ---------------------------------------------------------------------------------

## The phase and frame gates of the current lower graph state's records, pending ones first,
## soonest first (a phase gate of 0 is no gate):
## [{kind: "phase" | "frames", gate, left_s, open, record, target, request, auto}]. Phase gates
## count down at the current input's playback rate; frame gates use their transition row's
## gate_s (gameplay overrides applied), else frames / gates.land_move_gate.fps.
func gate_countdown(snap: Dictionary) -> Array:
	var out: Array = []
	if anim == null or not is_instance_valid(anim) or anim.data == null or not bool(snap.get("ok", false)):
		return out
	var lower: Dictionary = snap.get("lower", {})
	var gs := String(lower.get("graph_state", ""))
	var st: Dictionary = anim.data.graph.get("graph_states", {}).get(gs, {})
	if st.is_empty():
		return out
	var ph := float(lower.get("phase", 0.0))
	var tis := float(lower.get("time_in_state", 0.0))
	var slot := _current_slot(snap)
	var length := float(slot.get("length", 0.0))
	var rate := float(slot.get("rate", 0.0))
	var fps := float(anim.data.graph.get("gates", {}).get("land_move_gate", {}).get("fps", 30.0))
	var seen := {}
	for r: Dictionary in st.get("transitions", []):
		var rec := String(r.get("record", ""))
		var key := anim.loco.key_for_record(rec) if anim.loco != null else "graph_record"
		var use: Dictionary = anim.data.transition_use(key, rec) if key != "graph_record" else {}
		for c: Dictionary in r.get("conditions", []):
			var v := String(c.get("variable", ""))
			if int(c.get("mode", 0)) != 2 or c.get("min") == null:
				continue
			var e := {"record": rec, "target": String(r.get("target", "")), "request": String(r.get("request", "")),
					"auto": String(r.get("request", "")) == "auto", "key": key}
			if v.begins_with("phase"):
				var gate := float(c.min)
				if gate <= 0.0:
					continue   # phase >= 0: no gate
				e["kind"] = "phase"
				e["gate"] = gate
				e["open"] = ph + 1e-5 >= gate
				e["left_s"] = 0.0 if e.open else ((gate - ph) * length / rate if rate > 1e-6 and length > 0.0 else INF)
			elif v.begins_with("frames"):
				var gate_s := float(c.min) / maxf(fps, 1.0)
				if use.has("gate_s"):
					gate_s = float(use.gate_s)
				e["kind"] = "frames"
				e["gate"] = gate_s
				e["frames"] = float(c.min)
				e["open"] = tis + 1e-6 >= gate_s
				e["left_s"] = maxf(gate_s - tis, 0.0)
			else:
				continue
			var sig := "%s|%s|%s" % [e.kind, e.gate, e.target]
			if seen.has(sig):
				continue
			seen[sig] = true
			out.append(e)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.open) != bool(b.open):
			return not bool(a.open)
		return float(a.left_s) < float(b.left_s))
	return out


static func _current_slot(snap: Dictionary) -> Dictionary:
	var lower: Dictionary = snap.get("lower", {})
	var node := "L__" + String(lower.get("input_id", ""))
	var hemi := String(lower.get("hemi", ""))
	var best := {}
	for s: Dictionary in snap.get("slots", []):
		if String(s.get("node", "")) == node and (String(s.get("hemi", "")) == "" or String(s.get("hemi", "")) == hemi):
			return s
		if best.is_empty() or float(s.get("weight", 0.0)) > float(best.get("weight", 0.0)):
			best = s
	return best


# --- formatting (static, pure) ------------------------------------------------------------------

## Panel 1: AnimInputs, then the graph fields.
static func format_fields(snap: Dictionary) -> String:
	var L := PackedStringArray()
	if not bool(snap.get("ok", false)):
		L.append("[b]PLAYER ANIM NOT READY[/b]")
		var setup: Dictionary = snap.get("setup", {})
		if setup.has("refused"):
			L.append(_esc("refused: %s" % setup.refused))
		for w in snap.get("warnings", []):
			L.append(_esc("- %s" % w))
		return "\n".join(L)
	L.append("[b]INPUTS[/b]  frame %s  t %s s" % [snap.get("frame", "-"), _num(snap.get("time", 0.0))])
	var inp: Dictionary = snap.get("inputs", {})
	var done := {}
	for line in INPUT_LINES:
		var parts := PackedStringArray()
		for f in line:
			done[f[0]] = true
			if inp.has(f[0]):
				parts.append(("%s %s" % [f[1], _val(inp[f[0]], f[0])]) if f[1] != "" else _val(inp[f[0]], f[0]))
		if not parts.is_empty():
			L.append(" " + "  ".join(parts))
	var other := PackedStringArray()
	var keys := inp.keys()
	keys.sort()
	for k in keys:
		if not done.has(k) and not String(k) in INPUT_SKIP:
			other.append("%s %s" % [k, _val(inp[k], String(k))])
	if not other.is_empty():
		L.append(" " + "  ".join(other))
	var fb: Array = inp.get("fallbacks", [])
	if not fb.is_empty():
		L.append(" [color=#ffb070]fallbacks: %s[/color]" % _esc(", ".join(PackedStringArray(fb))))
	var ev: Array = inp.get("events", [])
	if not ev.is_empty():
		L.append(" events %s" % _esc(JSON.stringify(ev)))
	L.append("[b]GRAPH FIELDS[/b]")
	var d: Dictionary = snap.get("derived", {})
	done = {}
	for row in FIELD_ROWS:
		var vals := PackedStringArray()
		for k in row[1]:
			done[k] = true
			if d.has(k):
				vals.append(_val(d[k], k))
		if not vals.is_empty():
			L.append(_row(row[0], " / ".join(vals), row[2]))
	other = PackedStringArray()
	keys = d.keys()
	keys.sort()
	for k in keys:
		if not done.has(k):
			other.append("%s %s" % [k, _val(d[k], String(k))])
	if not other.is_empty():
		L.append(" [color=#8a93a0]other:[/color] " + "  ".join(other))
	return "\n".join(L)


## Panel 2: lower state, gate countdown, selector bars, OneShots, slots, trace.
## gates: gate_countdown(); lengths: clip -> seconds (OneShot lengths).
static func format_weights(snap: Dictionary, gates: Array = [], lengths: Dictionary = {}) -> String:
	var L := PackedStringArray()
	if not bool(snap.get("ok", false)):
		L.append("[b]WEIGHTS[/b]  -")
		return "\n".join(L)
	var lo: Dictionary = snap.get("lower", {})
	L.append("[b]LOWER[/b]  %s  [color=#9fd7ff]%s[/color]" % [_esc(_str(lo.get("state"))), _esc(_str(lo.get("graph_state")))])
	L.append(" input %s  mode %s  hemi %s" % [_esc(_str(lo.get("input_id"))), _str(lo.get("mode")), _str(lo.get("hemi"))])
	L.append(" %s  aimed %s  t %s s  phase %s" % [_str(lo.get("stance")), _val(lo.get("aimed", false)),
			_num(lo.get("time_in_state", 0.0)), _num(lo.get("phase", 0.0), 3)])
	var n := 0
	for g: Dictionary in gates:
		n += 1
		if n > 2:
			break
		var what := ("phase>=%s" % _num(g.gate)) if g.kind == "phase" else ("%sf=%s s" % [_num(g.get("frames", 0.0), 0), _num(g.gate)])
		var via := "auto" if bool(g.auto) else String(g.request)
		var when := "[color=#8f8]open[/color]" if bool(g.open) else (("in [color=#ffd27f]%s s[/color]" % _num(g.left_s)) if not is_inf(float(g.left_s)) else "paused")
		L.append(" gate %s -> %s %s %s %s" % [what, _esc(String(g.target)), _esc(via), g.record, when])
	if gates.is_empty():
		L.append(" gate: none (no phase / frame gate in this state)")
	L.append_array(_selector("L", lo.get("selector", {}), "#7fc8ff"))
	var hemis: Dictionary = lo.get("hemis", {})
	for id in hemis:
		L.append_array(_selector("hemi(%s)" % id, hemis[id], "#9be8b0"))
	var up: Dictionary = snap.get("upper", {})
	for k in ["A", "G", "W"]:
		if up.has(k):
			L.append_array(_selector(k, up[k], "#e8c07f"))
	var shots: Array = up.get("active_oneshots", [])
	L.append("[b]ONESHOTS[/b] %d  (%s %s)" % [shots.size(), _str(up.get("weapon")), _str(up.get("stance"))])
	n = 0
	for s: Dictionary in shots:
		n += 1
		if n > MAX_ROWS:
			L.append("  ... %d more" % (shots.size() - MAX_ROWS))
			break
		var clip := String(s.get("clip", ""))
		var length := float(lengths.get(clip, 0.0))
		var pos := float(s.get("position", 0.0))
		var left := float(s.get("ends_at", INF)) - float(snap.get("time", 0.0))
		L.append(" " + _esc(clip))
		var line := "   %s/%s s x%s %s %s" % [_num(pos), _num(length) if length > 0.0 else "-", _num(s.get("rate", 1.0)),
				_bar(pos / length if length > 0.0 else 0.0, "#e89f7f", 8), _esc(String(s.get("key", "")))]
		if not is_inf(left) and left > -10.0:
			line += " end %s s" % _num(left)
		if bool(s.get("fading", false)):
			line += " fading"
		L.append(line)
	L.append("[b]SLOTS[/b] (weighted lower clips)")
	n = 0
	for s: Dictionary in snap.get("slots", []):
		n += 1
		if n > MAX_ROWS:
			break
		L.append(" %s %s %s/%s x%s %s %s" % [_esc(String(s.get("clip", ""))), _str(s.get("hemi")) if String(s.get("hemi", "")) != "" else "",
				_num(s.get("position", 0.0)), _num(s.get("length", 0.0)), _num(s.get("rate", 0.0)),
				_bar(float(s.get("weight", 0.0)), "#7fc8ff", 8), _num(s.get("weight", 0.0))])
	var tr: Array = snap.get("trace", [])
	L.append("[b]TRACE[/b] (last %d)" % mini(MAX_TRACE, tr.size()))
	for i in range(maxi(0, tr.size() - MAX_TRACE), tr.size()):
		var e: Dictionary = tr[i]
		L.append(" f%s %s -> %s %s" % [e.get("frame", "-"), _esc(_str(e.get("from"))), _esc(_str(e.get("to"))),
				_esc(String(e.get("to_graph", e.get("reason", ""))))])
		L.append("    %s %s %s/%s %s" % [_esc(_str(e.get("key"))), _str(e.get("record")) if String(e.get("record", "")) != "" else "-",
				_fade(e.get("fade_graph", 0.0)), _fade(e.get("fade_used", 0.0)), _str(e.get("status"))])
	var warns: Array = snap.get("warnings", [])
	if not warns.is_empty():
		L.append("[color=#ff9f7f]%d warning(s)[/color], last: %s" % [warns.size(), _esc(String(warns[warns.size() - 1]))])
	return "\n".join(L)


## Panel 3: provenance of the dominant lower input and the aim base (plan section 9): the
## attribution and authorization (first, so they stay visible when the panel is cut to its
## height), then per entry graph state and offset, leaf and leaf ID, clip, native_asset_id,
## overlay chain (set, record offset, from / to IDs; names for the lower input), layers (slot,
## clip, weight, weight source, lambda, record offset; ">hands" = superseded by the grip).
## level (PROV_LEVELS, for the panel's height limit above the crosshair): 0 everything, 1 without
## the lower chain's from / to names, 2 also at most PROV_COMPACT chain steps and layers for the
## aim base, 3 for the lower entry too. Every shown step and layer keeps its IDs, record offset,
## weight and lambda source, and each entry its native_asset_id.
static func format_provenance(snap: Dictionary, level := 0) -> String:
	var L := PackedStringArray()
	L.append("[b]PROVENANCE[/b]  [color=#8a93a0](sets: %s*)[/color]" % SET_PREFIX)
	if not bool(snap.get("ok", false)):
		L.append(" -")
		return "\n".join(L)
	var credit := PackedStringArray()
	if snap.has("attribution"):
		credit.append(String(snap.attribution))
	if snap.has("authorization"):
		credit.append("authorization: %s" % snap.authorization)
	if not credit.is_empty():
		L.append("[color=#aaaaaa]%s[/color]" % _esc("  ".join(credit)))
	var prov: Dictionary = snap.get("provenance", {})
	if prov.is_empty():
		L.append(" none")
	for key in prov:
		var p: Dictionary = prov[key]
		var lower := not String(key).begins_with("aim/")
		var compact := level >= 3 or (level >= 2 and not lower)
		var max_chain := PROV_COMPACT if compact else 4
		var max_layers := PROV_COMPACT if compact else 5
		L.append("[b][color=#9fd7ff]%s[/color][/b]  %s  clip %s" % [_esc(String(key)), "lower" if lower else "aim base",
				_esc(_str(p.get("clip")))])
		L.append("state %s @%s  leaf %s #%s  %s" % [_esc(_str(p.get("state"))), _str(p.get("state_offset")),
				_esc(_str(p.get("leaf"))), _str(p.get("leaf_id")), _str(p.get("status"))])
		L.append("native_asset_id %s" % _str(p.get("native_asset_id")))
		var chain: Array = p.get("chain", [])
		var n := 0
		for c: Dictionary in chain:
			n += 1
			if n > max_chain:
				L.append("  ... %d more" % (chain.size() - max_chain))
				break
			var line := "%s %s @%s #%s->#%s" % ["chain" if n == 1 else "     ", _esc(_set_name(_str(c.get("set")))),
					_str(c.get("record_offset")), _str(c.get("from_id")), _str(c.get("to_id"))]
			if lower and level < 1:
				line += "  %s->%s" % [_esc(_str(c.get("from"))), _esc(_str(c.get("to")))]
			L.append(line)
		var layers: Array = p.get("layers", [])
		n = 0
		for ly: Dictionary in layers:
			n += 1
			if n > max_layers:
				L.append("  ... %d more layers" % (layers.size() - max_layers))
				break
			var sup := String(ly.get("superseded_by")) if ly.get("superseded_by") != null else ""
			var src := _str(ly.get("weight_source"))
			if src.begins_with("lambda ") and ly.get("lambda") != null:
				src = src.substr(7)
			L.append("%s %s %s %s%s" % ["layer" if n == 1 else "     ", _str(ly.get("slot")), _esc(_str(ly.get("clip"))),
					_num(ly.get("weight", 0.0)), (" >%s" % sup) if sup != "" else ""])
			L.append("        %s%s @%s" % [_esc(src), (" " + _esc(String(ly.lambda))) if ly.get("lambda") != null else "",
					_str(ly.get("record_offset"))])
	return "\n".join(L)


## Selector bars; a settled selector (one input at weight 1, the target) takes one line.
static func _selector(name: String, s: Variant, color: String) -> PackedStringArray:
	var L := PackedStringArray()
	if not s is Dictionary or (s as Dictionary).is_empty():
		return L
	var sd: Dictionary = s
	var ws: Dictionary = sd.get("weights", {})
	var target := _str(sd.get("target"))
	if ws.size() == 1 and String(ws.keys()[0]) == target and float(ws.values()[0]) >= 1.0 - 1e-6:
		L.append("[b]%s[/b] %s %s %s" % [_esc(name), _esc(_pad(target, 24 - name.length())), _bar(1.0, color), _num(1.0)])
		return L
	L.append("[b]%s[/b] -> %s  fade %s s  %s s ago" % [_esc(name), _esc(target), _num(sd.get("fade", 0.0)), _num(sd.get("since_s", 0.0))])
	var keys := ws.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return float(ws[a]) > float(ws[b]))
	var n := 0
	for k in keys:
		n += 1
		if n > MAX_ROWS:
			L.append("  ... %d more" % (keys.size() - MAX_ROWS))
			break
		var w := float(ws[k])
		L.append("  %s %s %s" % [_esc(_pad(String(k), 24)), _bar(w, color), _num(w)])
	if keys.is_empty():
		L.append("  (no weight)")
	return L


static func _row(label: String, value: String, note: String) -> String:
	var lab := _pad(label, maxi(16, label.length() + 1))
	return " %s%s%s" % [lab, _pad(value, 9) if value.length() < 9 else value + " ",
			("[color=#8a93a0](%s)[/color]" % _esc(note)) if note != "" else ""]


static func _pad(s: String, n: int) -> String:
	return s + " ".repeat(n - s.length()) if s.length() < n else s.left(maxi(n, 1))


static func _bar(w: float, color: String, n := BAR_N) -> String:
	var k := clampi(roundi(clampf(w, 0.0, 1.0) * n), 0, n)
	return "[color=%s]%s[/color][color=#3a4048]%s[/color]" % [color, "█".repeat(k), "█".repeat(n - k)]


static func _set_name(s: String) -> String:
	return s.substr(SET_PREFIX.length()) if s.begins_with(SET_PREFIX) else s


static func _fade(v: Variant) -> String:
	var f := float(v) if v != null else 0.0
	return "0" if f == 0.0 else ("%.3f" % f).rstrip("0").rstrip(".")


static func _val(v: Variant, key := "") -> String:
	match typeof(v):
		TYPE_NIL:
			return "-"
		TYPE_BOOL:
			return "1" if v else "0"
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			return _num(v, 1 if key.ends_with("_deg") else 2)
		TYPE_VECTOR2:
			return "(%s, %s)" % [_num(v.x), _num(v.y)]
		TYPE_VECTOR3:
			return "(%s, %s, %s)" % [_num(v.x), _num(v.y), _num(v.z)]
		TYPE_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			var parts := PackedStringArray()
			for x in v:
				parts.append(_val(x, key))
			return "(%s)" % ", ".join(parts)
		TYPE_STRING, TYPE_STRING_NAME:
			return _esc(String(v)) if String(v) != "" else "-"
	return _esc(str(v))


static func _num(v: Variant, digits := 2) -> String:
	if v == null:
		return "-"
	var f := float(v)
	if is_nan(f):
		return "nan"
	if is_inf(f):
		return "inf" if f > 0.0 else "-inf"
	return ("%." + str(digits) + "f") % f


static func _str(v: Variant) -> String:
	if v == null:
		return "-"
	var s := str(v)
	return s if s != "" else "-"


## BBCode-escapes text ([ -> [lb]).
static func _esc(s: String) -> String:
	return s.replace("[", "[lb]")


# --- data lookups (bound PlayerAnim) ------------------------------------------------------------

func _clip_lengths(snap: Dictionary) -> Dictionary:
	var out := {}
	if anim == null or not is_instance_valid(anim) or anim.data == null:
		return out
	for s: Dictionary in snap.get("upper", {}).get("active_oneshots", []):
		var c := String(s.get("clip", ""))
		if c != "" and not out.has(c):
			out[c] = anim.data.clip_length(c)
	return out


# --- UI -----------------------------------------------------------------------------------------

func _build_ui() -> void:
	if _root != null:
		return
	_font = _mono(400)
	_bold = _mono(700)
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	for pname in ["Fields", "Weights", "Provenance"]:
		var pc := PanelContainer.new()
		pc.name = pname
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.05, 0.06, 0.76)
		sb.set_corner_radius_all(4)
		sb.set_content_margin_all(6)
		pc.add_theme_stylebox_override("panel", sb)
		var vb := VBoxContainer.new()
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pc.add_child(vb)
		var t := RichTextLabel.new()
		t.name = "Text"
		t.bbcode_enabled = true
		t.fit_content = true
		t.scroll_active = false
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.add_theme_font_override("normal_font", _font)
		t.add_theme_font_override("bold_font", _bold)
		t.add_theme_color_override("default_color", Color(0.9, 0.92, 0.95))
		vb.add_child(t)
		_panels.append(pc)
		_texts.append(t)
	# The provenance panel sits between the other two: add it first, so where a narrow window makes
	# them overlap the side panels stay on top.
	_root.add_child(_panels[2])
	_root.add_child(_panels[0])
	_root.add_child(_panels[1])
	# Buttons under panel 2: the same actions as the keys, for keyboards whose F-keys the OS takes.
	_buttons = HBoxContainer.new()
	_buttons.name = "Buttons"
	_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for spec in [["Freeze", "anim_freeze"], ["Step", "anim_step"], ["Slow", "anim_slowmo"], ["Opt", "anim_options"],
			["Hit", "debug_hit_light"], ["Heavy", "debug_hit_heavy"], ["Die", "debug_death"], ["Up", "debug_respawn"]]:
		var b := Button.new()
		b.name = String(spec[1])
		b.text = spec[0]
		b.tooltip_text = "%s (%s)" % [spec[1], OS.get_keycode_string(_key_of(String(spec[1])))]
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_theme_font_override("font", _font)
		b.pressed.connect(run_action.bind(String(spec[1])))
		_buttons.add_child(b)
	(_panels[1].get_child(0) as VBoxContainer).add_child(_buttons)
	_status = Label.new()
	_status.name = "Status"
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.add_theme_font_override("font", _bold)
	_status.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	_status.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_status.add_theme_constant_override("shadow_offset_x", 1)
	_status.add_theme_constant_override("shadow_offset_y", 1)
	_root.add_child(_status)
	_apply_scale(1.0)


## The first key bound to an InputSetup action (for the button tooltips).
static func _key_of(action: String) -> Key:
	if InputMap.has_action(action):
		for e in InputMap.action_get_events(action):
			if e is InputEventKey:
				var k := (e as InputEventKey).physical_keycode
				return k if k != KEY_NONE else (e as InputEventKey).keycode
	return KEY_NONE


static func _mono(weight: int) -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Menlo", "SF Mono", "Monaco", "Consolas", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
	f.font_weight = weight
	return f


## Font size and panel widths for a viewport height (FONT_SIZE at 720 px, up to x1.75).
func _apply_scale(k: float) -> void:
	_scale = k
	var fs := roundi(FONT_SIZE * k)
	var cw := 0.61 * fs   # monospace advance (Menlo / DejaVu Sans Mono 0.60 em); longer lines wrap
	for i in _texts.size():
		var t := _texts[i]
		t.add_theme_font_size_override("normal_font_size", fs)
		t.add_theme_font_size_override("bold_font_size", fs)
		t.custom_minimum_size = Vector2(ceilf(cw * float(PANEL_CHARS[i])) + 2.0, 0.0)
	for b in _buttons.get_children():
		(b as Button).add_theme_font_size_override("font_size", maxi(fs - 1, 8))
	_status.add_theme_font_size_override("font_size", fs + 2)


func _apply_visibility() -> void:
	for p in _panels:
		p.visible = shown
	_update_status()
	_layout()


func _update_status() -> void:
	if _status == null:
		return
	var parts := PackedStringArray()
	if frozen:
		parts.append("ANIM FROZEN (F5 resume, F6 step)")
	if time_scale_index != 0:
		parts.append("time x%s" % _num(TIME_SCALES[time_scale_index]))
	if option_index != 0:
		parts.append("F8 %s" % option_label())
	if shown or not parts.is_empty():
		if last_action != "":
			parts.append(last_action)
		if shown:
			parts.append("F4 hide")
	var text := "  |  ".join(parts)
	if text == _status.text:
		return
	_status.text = text
	_status.visible = text != ""
	_layout()


## Panel 1 top left, panel 2 top right (below the HUD's F3 line and weapon slots), panel 3 top
## centre, ending above the crosshair (see _fit_provenance); the status line at the bottom centre.
func _layout() -> void:
	if _root == null or _panels.size() < 3:
		return
	var vs := viewport_size()
	var k := clampf(vs.y / 720.0, 1.0, 1.75)
	if absf(k - _scale) > 0.01:
		_apply_scale(k)
	var fit := Vector3(vs.x, vs.y, k)
	if fit != _prov_fit:
		_prov_fit = fit
		_fit_provenance(vs, k)
	for p in _panels:
		p.reset_size()
	_status.reset_size()
	var m := 8.0 * k
	_status.position = Vector2(maxf((vs.x - _status.size.x) * 0.5, m), vs.y - _status.size.y - 10.0 * k)
	_panels[0].position = Vector2(m, 88.0 * k)
	_panels[1].position = Vector2(maxf(vs.x - _panels[1].size.x - m, m), 88.0 * k)
	_panels[2].position = Vector2(maxf((vs.x - _panels[2].size.x) * 0.5, m), m)


## The viewport size the panels are laid out for (layout_size when set).
func viewport_size() -> Vector2:
	if layout_size.x > 0.0 and layout_size.y > 0.0:
		return layout_size
	return _root.get_viewport_rect().size if _root != null and _root.is_inside_tree() else Vector2(1280, 720)


## Lowest y panel 3 may reach: CROSSHAIR_GAP (scaled) above the screen centre.
func provenance_limit() -> float:
	var vs := viewport_size()
	return vs.y * 0.5 - CROSSHAIR_GAP * clampf(vs.y / 720.0, 1.0, 1.75)


## Panel 3's text for the last rendered snapshot at the fullest PROV_LEVELS level whose panel
## ends above provenance_limit(); when even the most compact one does not, the text is cut to
## whole lines at that height (the attribution comes first and stays).
func _fit_provenance(vs: Vector2, k: float) -> void:
	var t := _texts[2]
	var pc := _panels[2]
	var sb := pc.get_theme_stylebox("panel")
	var pad := sb.get_minimum_size().y if sb != null else 0.0
	var room := provenance_limit() - 8.0 * k - pad   # panel 3 sits at y = the margin
	t.fit_content = true
	t.custom_minimum_size.y = 0.0
	# The height below depends on the wrap width: give the label its panel width now, not after the
	# container's deferred sort.
	if absf(t.size.x - t.custom_minimum_size.x) > 0.5:
		t.size = Vector2(t.custom_minimum_size.x, maxf(t.size.y, 1.0))
	provenance_clipped = false
	for level in PROV_LEVELS:
		provenance_level = level
		t.text = format_provenance(_prov_snap, level)
		if float(t.get_content_height()) <= room:
			return
	var h := float(t.get_content_height())
	var lines := maxi(t.get_line_count(), 1)
	var line_h := h / float(lines)
	t.fit_content = false
	t.custom_minimum_size.y = maxf(floorf(room / line_h), 1.0) * line_h
	provenance_clipped = true
	# Say so in the header (still one line at PANEL_CHARS: the wrap and line height are unchanged).
	t.text = t.text.replace("[b]PROVENANCE[/b]", "[b]PROVENANCE[/b] [color=#ffb070](cut to fit)[/color]")
