extends AnimTestSuite
## WP8 (plan sections 9 and 10 test_overlay): AnimDebugOverlay and the debug input actions.
##   - keys: InputSetup registers the nine debug actions on F4..F12 (physical keys), and no game
##     control, Esc (ui_cancel) or the HUD's F3 shares a key with them (Godot's built-in
##     ui_filedialog_refresh F5 is reported: only a focused FileDialog reads it, and it takes the
##     key before the overlay's _unhandled_input);
##   - headless: the overlay instantiates with its panels hidden and renders a scripted plan
##     section 9 snapshot, an empty one and a refused-setup one without errors; panel 1 carries the
##     graph field labels (move_dir ... (f32@C0+144)) and lists unlabeled new fields, panel 2 the
##     selector bars, OneShot and slot rows and the trace entries (key, record, graph / used fade,
##     status; brackets escaped), panel 3 the chain record offsets, leaf ID and native_asset_id;
##   - on the facade rig (tests/anim/facade_rig.gd) with PlayerAnim running by itself (auto_process):
##     F4 toggles the three panels, which then show this frame's state, clips, gate countdown and
##     provenance; F5 freezes: the bone poses, playback positions and facade clock stay unchanged
##     for 10 frames; F6 steps exactly 1/60 s (clock + 1/60, frame + 1, clip position + rate/60),
##     also on key repeat; F5 resumes; F7 cycles Engine.time_scale 1 -> 0.25 -> 0.1 -> 1; F8 flips
##     one toggle at a time against the state it started from (graph defaults: every gameplay
##     override off) and ends there; F9 / F10 / F11 / F12 play a light hit, a heavy hit, death and
##     revive; with OS.is_debug_build() stubbed false (debug_build) F4..F12 and the buttons do
##     nothing; the buttons take no keyboard focus; freeing the overlay (or bind() while frozen)
##     undoes its freeze (auto_process and the AimStabilizer's trim_hold), time scale and F8 toggle;
##   - panel 3 at 1280x720 (layout_size): ends above the crosshair; an oversized entry is compacted
##     and then cut;
##   - in the level: the player has exactly one overlay (player.gd attach(); a second attach()
##     returns it), bound to its PlayerAnim; the
##     HUD's F3 still toggles its debug line while F4 does not, and F3 leaves the overlay alone;
##     freeze / step / resume and a light hit on the real player; F5 with the musket raised and the
##     body turned 25 deg: the weapon socket (post-modifier pose) holds relative to the body, F6
##     lets one frame of the stabilizer's aim trim learn, then holds it again; panel 3 fits above
##     the crosshair for every graph role with its aim base.

const FacadeRig := preload("res://tests/anim/facade_rig.gd")
## (Shift+F5 and Shift+F9 since the saves took F5 and F9: SaveGame's quick save and load, 2026-09-27.)
const KEYS := {"anim_debug": KEY_F4, "anim_freeze": KEY_F5 | KEY_MASK_SHIFT, "anim_step": KEY_F6, "anim_slowmo": KEY_F7,
		"anim_options": KEY_F8, "debug_hit_light": KEY_F9 | KEY_MASK_SHIFT, "debug_hit_heavy": KEY_F10, "debug_death": KEY_F11,
		"debug_respawn": KEY_F12}
## Built-in GUI actions that only a focused Control reads (FileDialog: F5 refresh). The focused
## dialog handles the key before _unhandled_input, so the overlay never sees it then.
const GUI_ONLY := ["ui_filedialog_refresh"]
const NATIVE_ID := "158f6f20eaa1ef61dcb68475f6b952833f4efa34e25dceafb85c4983f9a16d58"


func describe() -> String:
	return "AnimDebugOverlay: debug keys, stub render, F4 panels, Shift+F5 freeze, F6 1/60 s step, F7, F8, Shift+F9, F10-F12 (inert in release), HUD F3, level"


func timeout_s() -> float:
	return 300.0


func run(ctx: AnimTestContext) -> void:
	var ts0 := Engine.time_scale
	_keys(ctx)
	_stub(ctx)
	await _rig(ctx)
	Engine.time_scale = ts0
	await _level(ctx)
	Engine.time_scale = ts0


# --- keys -----------------------------------------------------------------------------------

func _keys(ctx: AnimTestContext) -> void:
	InputSetup.ensure()
	var bad := []
	for a in KEYS:
		var keys := _action_keys(a)
		if keys != [KEYS[a]]:
			bad.append("%s %s" % [a, keys])
	ctx.check(bad.is_empty(), "InputSetup registers the nine debug actions on F4..F12 %s" % [bad])
	var debug_keys := KEYS.values()
	var clash := []
	var gui := []
	for a in InputMap.get_actions():
		if KEYS.has(String(a)):
			continue
		for k in _action_keys(a):
			if k in debug_keys:
				if String(a) in GUI_ONLY:
					gui.append("%s %s" % [a, OS.get_keycode_string(k)])
				else:
					clash.append("%s %s" % [a, OS.get_keycode_string(k)])
	ctx.check(clash.is_empty(), "no other action shares a debug key (sprint Shift, walk Alt, crouch Ctrl/C, ui_cancel, ...) %s" % [clash])
	if not gui.is_empty():
		ctx.info("built-in GUI actions on a debug key, used only by a focused dialog that takes the key first: %s" % [gui])
	ctx.check(not KEY_F3 in debug_keys, "F3 stays the HUD's debug toggle")
	for a in InputSetup.KEYS:
		for k in InputSetup.KEYS[a]:
			ctx.check(not k in debug_keys, "game control %s (%s) is not a debug key" % [a, OS.get_keycode_string(k)])
	ctx.check(_action_keys("sprint") == [KEY_SHIFT] and _action_keys("walk") == [KEY_ALT],
			"game controls unchanged: Shift = sprint, Alt = walk (%s, %s)" % [_action_keys("sprint"), _action_keys("walk")])


static func _action_keys(action: StringName) -> Array:
	var out := []
	if not InputMap.has_action(action):
		return out
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			var k: int = (e as InputEventKey).physical_keycode
			k = k if k != 0 else (e as InputEventKey).keycode
			out.append(k | (KEY_MASK_SHIFT if (e as InputEventKey).shift_pressed else 0))
	return out


# --- stub snapshot --------------------------------------------------------------------------

func _stub(ctx: AnimTestContext) -> void:
	var o := AnimDebugOverlay.new()
	ctx.add_node(o)
	ctx.check(o.is_inside_tree() and o.panels().size() == 3, "instantiates headless with three panels")
	var hidden := true
	for p in o.panels():
		hidden = hidden and not p.visible
	ctx.check(hidden and not o.shown, "panels hidden until F4")
	o.render(stub_snapshot())
	var t := o.panel_texts()
	ctx.check(t.size() == 3, "three panel texts")
	var p1 := t[0]
	var p2 := t[1]
	var p3 := t[2]
	ctx.check(p1.contains("move_dir") and p1.contains("43.2") and p1.contains("(f32@C0+144)"),
			"panel 1: move_dir 43.2 with its graph field label (f32@C0+144)")
	for lab in ["f32@C0+120", "f32@C8+4", "i32@C0+128", "i32@C0+132", "i32@C0+136", "f32@C8+172", "f32@C8+248", "f32@C8+252",
			"calc-new-phase-from-speed", "calc-ankle-match-phase"]:
		ctx.check(p1.contains(lab), "panel 1 labels a field with %s" % lab)
	ctx.check(p1.contains("future_field"), "panel 1 lists a derived field that has no label yet")
	ctx.check(p1.contains("fallbacks") and p1.contains("wish_local"), "panel 1 lists the input fields that came from a fallback")
	ctx.check(p2.contains("LAND") and p2.contains("fall-land-soft-idle") and p2.contains("land__run__soft"),
			"panel 2: lower state, graph state and input")
	for s in ["move__run", "land__run__soft", "A__musket__stand", "hemi(move__run)", "musket", "stand"]:
		ctx.check(p2.contains(s), "panel 2 shows selector input %s" % s)
	ctx.check(p2.contains("█"), "panel 2 draws weight bars")
	ctx.check(p2.contains("actor_b-p-rifle-idle-aim-reload-mid--part") and p2.contains("x0.88") and p2.contains("reload_mid"),
			"panel 2: active OneShot with clip, position and rate")
	ctx.check(p2.contains("actor_b-p-run-fw") and p2.contains("0.30/0.73"), "panel 2: weighted slot with position / length")
	ctx.check(p2.contains("f1200 FALL -> LAND landed") and p2.contains("air_to_land - 0/0.1 proposed"),
			"panel 2: trace entry with its key, record, graph / used fade and status")
	ctx.check(p2.contains("[bracket]"), "panel 2: warning text with brackets kept")
	ctx.check(p3.contains("0x0000c468") and p3.contains("bbf6d71a") and p3.contains("0x0000410c") and p3.contains("574fa8b3"),
			"panel 3: state offset, leaf ID, chain record offset and to-ID")
	ctx.check(p3.contains(NATIVE_ID), "panel 3: native_asset_id in full")
	ctx.check(p3.contains("player-overlays:0x00021774") and p3.contains("0.80"), "panel 3: layer weight and lambda source")
	# Panel 3's height at 1280x720 (layout_size: the headless root viewport is 64x64): it ends
	# above the crosshair, compacting and then cutting an oversized entry.
	o.layout_size = Vector2(1280, 720)
	o.render(stub_snapshot())
	ctx.check(o.provenance_level == 0 and not o.provenance_clipped and _prov_bottom(o) <= o.provenance_limit() + 0.5,
			"1280x720: the stub's provenance fits in full above the crosshair (bottom %.0f px, limit %.0f)" % [_prov_bottom(o), o.provenance_limit()])
	o.render(oversized_snapshot())
	var p3b := o.panel_texts()[2]
	ctx.check(o.provenance_clipped and o.provenance_level == AnimDebugOverlay.PROV_LEVELS - 1 and _prov_bottom(o) <= o.provenance_limit() + 0.5,
			"1280x720: an oversized provenance is compacted, then cut to its height (level %d, clipped %s, bottom %.0f px, limit %.0f)"
			% [o.provenance_level, o.provenance_clipped, _prov_bottom(o), o.provenance_limit()])
	ctx.check(p3b.contains("(cut to fit)"), "a cut panel 3 says so in its header")
	o.render(stub_snapshot())
	ctx.check(o.provenance_level == 0 and not o.provenance_clipped, "the next snapshot is fitted afresh (full again)")
	o.layout_size = Vector2.ZERO
	o.render({})
	ctx.check(o.panel_texts()[0].contains("NOT READY"), "renders an empty snapshot")
	o.render({"ok": false, "setup": {"refused": "rest is not [null-add]"}, "warnings": ["w1"]})
	ctx.check(o.panel_texts()[0].contains("rest is not [null-add]"), "renders a refused setup with its reason")
	o.refresh()
	ctx.check(o.panel_texts()[0].contains("no PlayerAnim bound"), "refresh() without a PlayerAnim says so")
	o.free()   # its keys would reach it too (the rig part stubs the other overlay's debug_build)


## Bottom of panel 3 (provenance) in viewport pixels.
static func _prov_bottom(o: AnimDebugOverlay) -> float:
	var p: PanelContainer = o.panels()[2]
	return p.position.y + p.size.y


## The stub snapshot with two provenance entries far taller than the space above the crosshair.
static func oversized_snapshot() -> Dictionary:
	var s := stub_snapshot()
	var e: Dictionary = s.provenance["musket/run/fw"].duplicate(true)
	var chain := []
	var layers := []
	for i in 12:
		chain.append({"layer": "move", "set": "anim-overlay-player-move-run-extra-long-set-name-%d" % i, "record_offset": "0x%08x" % (0x4100 + i * 4),
				"from": "relaxed-quickstop^run-bkwd-right-%d" % i, "from_id": "%08x" % (0x11110000 + i), "to": "base-idle^walk-back-right-%d" % i,
				"to_id": "%08x" % (0x22220000 + i)})
		layers.append({"slot": "arms", "kind": "partial", "clip": "actor_b-p-rifle-crouch-idle-aim-reload-mid-arms-%d" % i, "weight": 0.5,
				"weight_source": "lambda const", "lambda": "player-overlays:0x%08x" % (0x21700 + i), "record_offset": "0x%08x" % (0xd000 + i),
				"superseded_by": null})
	e["chain"] = chain
	e["layers"] = layers
	s.provenance = {"musket/run/fw": e, "aim/musket/stand/base": e.duplicate(true)}
	return s


## A plan section 9 snapshot, scripted (keys and value types as PlayerAnim.debug_snapshot()).
static func stub_snapshot() -> Dictionary:
	var sel_l := {"prefix": "L", "inputs": 103, "weights": {"move__run": 0.25, "land__run__soft": 0.75}, "target": "land__run__soft",
			"rate": 10.0, "fade": 0.1, "since_s": 0.07}
	var hemi := {"prefix": "L__move__run/hemi", "inputs": 2, "weights": {"fw": 1.0}, "target": "fw", "rate": INF, "fade": 0.0, "since_s": 1.0}
	return {"ok": true, "frame": 1234, "time": 20.5,
		"inputs": {"frame": 1234, "dt": 1.0 / 60.0, "velocity_local": [0.5, 3.2], "wish_local": [0.0, 3.6], "target_speed": 3.6,
			"speed": 3.24, "vertical_speed": 0.0, "on_floor": true, "air_time": 0.0, "last_air_vy": -4.4,
			"events": [{"t": "landed", "impact": 4.4}], "crouched": false, "walking": false, "sprinting": false, "alive": true,
			"aim_pitch": 0.1, "aim_point": [0.0, 1.4, 25.0], "aim_elev_deg": 5.0, "weapon_key": "musket", "weapon_aim": 1.0,
			"wants_aim": true, "steady_aim": false, "busy": true, "charge": 0.0, "blocked_hit_m": -1.0, "yaw": 0.3, "yaw_rate": 0.0,
			"fallbacks": ["wish_local"]},
		"derived": {"moving": true, "move_speed": 3.24, "move_dir_deg": 43.2, "blend_deg": 40.0, "blend_pos_fw": 40.0,
			"blend_pos_bw": -90.0, "hemi": "fw", "anim_mode": "run", "ratio": 1.08, "rate_fw": 1.47, "rate_bw": 0.0,
			"gait_phase": 0.25, "upper_aim_w": 1.0, "aim_stance": true, "up_w": 0.1, "down_w": 0.0, "blocked_w": 0.0,
			"suppress": 0.0, "stabilizer_deg": 12.5, "loco_enabled": true, "use_transition_anims": true,
			"crouch_change_pending": false, "turn_delta_deg": 0.0, "idle_turn_deg": 0.0, "trim_deg": [0.1, -0.2],
			"future_field": 7},
		"lower": {"state": "LAND", "graph_state": "fall-land-soft-idle", "time_in_state": 0.2, "phase": 0.3,
			"input_id": "land__run__soft", "mode": "run", "hemi": "fw", "stance": "stand", "aimed": true,
			"selector": sel_l, "hemis": {"move__run": hemi}},
		"upper": {"weapon": "musket", "stance": "stand", "aim_key": "musket/stand",
			"A": {"prefix": "A", "inputs": 6, "weights": {"A__musket__stand": 1.0}, "target": "A__musket__stand", "rate": INF, "fade": 0.0, "since_s": 3.0},
			"G": {"prefix": "", "inputs": 2, "weights": {"stand": 1.0}, "target": "stand", "rate": INF, "fade": 0.0, "since_s": 3.0},
			"W": {"prefix": "", "inputs": 3, "weights": {"musket": 1.0}, "target": "musket", "rate": INF, "fade": 0.0, "since_s": 3.0},
			"active_oneshots": [{"node": "X__actor_b_p_rifle_idle_aim_reload_mid__part", "clip": "actor_b-p-rifle-idle-aim-reload-mid--part",
				"position": 0.35, "rate": 0.875, "ends_at": 21.2, "key": "reload_mid", "fading": false}]},
		"slots": [{"node": "L__move__run", "hemi": "fw", "clip": "actor_b-p-run-fw", "position": 0.3, "length": 0.7333, "rate": 1.08,
			"weight": 0.25, "role_key": "musket/run/fw"},
			{"node": "L__land__run__soft", "hemi": "", "clip": "actor_b-p-land-soft^run", "position": 0.1, "length": 0.4, "rate": 1.0,
			"weight": 0.75, "role_key": "musket/run/land_soft_run"}],
		"provenance": {"musket/run/fw": {"state": "run-fw", "state_offset": "0x0000c468", "leaf": "base-walk-fwd", "leaf_id": "bbf6d71a",
			"clip": "actor_b-p-run-fw", "status": "resolved", "native_asset_id": NATIVE_ID,
			"chain": [{"layer": "move", "set": "anim-overlay-player-move-run", "record_offset": "0x0000410c", "from": "base-walk-fwd",
				"from_id": "bbf6d71a", "to": "base-run-strafe-fwd", "to_id": "574fa8b3"}],
			"layers": [{"slot": "arms", "kind": "partial", "clip": "actor_b-p-rifle-run-arms", "weight": 0.8, "weight_source": "lambda const",
				"lambda": "player-overlays:0x00021774", "record_offset": "0x0000dadc", "superseded_by": null}]}},
		"trace": [{"frame": 1200, "t": 20.0, "from": "FALL", "to": "LAND", "reason": "landed", "key": "air_to_land", "record": "",
			"fade_graph": 0.0, "fade_used": 0.1, "status": "proposed"}],
		"trace_lines": ["[f 1200] FALL(run,fw) fall -> LAND fall-land-soft-idle  moving=true (wish 3.60 v 3.24) key=air_to_land graph - 0/0.1 proposed"],
		"options": {"overrides": {"override_fast_hemisphere_fade": false}, "options": {"blocked": true}},
		"warnings": ["TreeBuilder: something [bracket]"]}


# --- facade rig -----------------------------------------------------------------------------

func _rig(ctx: AnimTestContext) -> void:
	var h = FacadeRig.new()
	if not h.setup(ctx, {"weapon": "musket"}):
		return
	var a: PlayerAnim = h.anim
	h.run(60, Vector2(0, 1), 3.6)
	h.aiming = true
	h.run(40, Vector2(0, 1), 3.6)
	h.aiming = false
	h.run(20, Vector2(0, 1), 3.6)
	h.action("reload_begin", 1.3)
	h.run(10, Vector2(0, 1), 3.6)
	var o := AnimDebugOverlay.new()
	ctx.add_node(o)
	o.bind(a)
	ctx.check(o.anim == a and o.debug_build == OS.is_debug_build(), "bind(anim); debug_build follows OS.is_debug_build()")
	var focus_ok := true
	for b in o.find_children("*", "Button", true, false):
		focus_ok = focus_ok and (b as Button).focus_mode == Control.FOCUS_NONE
	ctx.check(focus_ok and o.find_children("*", "Button", true, false).size() == 8, "8 buttons, none takes keyboard focus (Space / Enter)")
	o.debug_build = true

	# F4: the three panels.
	_press(ctx, KEY_F4)
	await ctx.idle_frames(2)
	var vis := true
	for p in o.panels():
		vis = vis and p.visible and p.is_visible_in_tree()
	ctx.check(o.shown and vis, "F4 shows the three panels")
	var t := o.panel_texts()
	var snap := a.debug_snapshot()
	ctx.check(t[0].contains("GRAPH FIELDS") and t[0].contains("(f32@C0+144)") and t[0].contains("musket"), "panel 1 shows the rig's inputs and fields")
	ctx.check(t[1].contains(String(snap.lower.graph_state)) and t[1].contains(String(snap.lower.input_id)),
			"panel 2 shows the lower state %s / %s" % [snap.lower.graph_state, snap.lower.input_id])
	ctx.check(t[1].contains("gate"), "panel 2 has the exit-gate line")
	var shots: Array = snap.upper.active_oneshots
	ctx.check(not shots.is_empty() and t[1].contains(String(shots[0].clip)), "panel 2 lists the active OneShot %s" % [shots[0].clip if not shots.is_empty() else "-"])
	var len_ok := not shots.is_empty() and t[1].contains("/%s s" % AnimDebugOverlay._num(a.data.clip_length(String(shots[0].clip))))
	ctx.check(len_ok, "panel 2 shows the OneShot's position / clip length")
	var prov: Dictionary = snap.provenance
	var ids_ok := not prov.is_empty()
	for k in prov:
		ids_ok = ids_ok and t[2].contains(String(prov[k].native_asset_id)) and t[2].contains(String(prov[k].leaf_id))
	ctx.check(ids_ok, "panel 3 shows the native_asset_id and leaf ID of %s" % [prov.keys()])
	_press(ctx, KEY_F4)
	await ctx.idle_frames(1)
	vis = false
	for p in o.panels():
		vis = vis or p.visible
	ctx.check(not o.shown and not vis, "F4 again hides them")
	_press(ctx, KEY_F4)
	await ctx.idle_frames(1)

	# Gate countdown: a flat jump lands in jump-long-land-idle, whose auto record 0x0002fec0 exits
	# to idle at phase 0.9.
	h.run(60)
	h.step(Vector2.ZERO, 0.0, {"jump": true})
	for i in 150:
		h.step()
		if a.loco.state == &"LAND":
			break
	h.run(2)
	var gates := o.gate_countdown(a.debug_snapshot())
	var gs := String(a.loco.graph_state)
	ctx.check(a.loco.state == &"LAND" and not gates.is_empty(), "landing %s: the overlay finds its exit gates (%d)" % [gs, gates.size()])
	if not gates.is_empty():
		var g0: Dictionary = gates[0]
		var ph := a.loco.phase()
		var expect := INF
		if String(g0.kind) == "phase":
			var sl := AnimDebugOverlay._current_slot(a.debug_snapshot())
			expect = (float(g0.gate) - ph) * float(sl.length) / float(sl.rate)
		ctx.check(not bool(g0.open) and String(g0.record).begins_with("0x") and float(g0.gate) > 0.0,
				"soonest gate: %s >= %s -> %s (%s) record %s in %.3f s" % [g0.kind, g0.gate, g0.target, g0.request, g0.record, g0.left_s])
		if String(g0.kind) == "phase":
			ctx.near(float(g0.left_s), expect, 1e-4, "countdown = (gate - phase) x length / rate")
		o.refresh()
		ctx.check(o.panel_texts()[1].contains("gate ") and o.panel_texts()[1].contains(String(g0.record)), "panel 2 shows the countdown line")
		var left0 := float(g0.left_s)
		h.run(6)
		var g1: Array = o.gate_countdown(a.debug_snapshot())
		if a.loco.state == &"LAND" and not g1.is_empty() and String(g1[0].record) == String(g0.record):
			ctx.near(float(g1[0].left_s), left0 - 6.0 / 60.0, 0.02, "the countdown runs down with the clip (6 frames)")
	h.run(90)

	# F5 / F6: freeze and step, with the facade running by itself.
	a.auto_process = true
	var s0 := a.debug_snapshot()
	await ctx.idle_frames(3)
	var s1 := a.debug_snapshot()
	ctx.check(float(s1.time) > float(s0.time) and int(s1.frame) > int(s0.frame), "running: the facade advances by itself (%d frames)" % (int(s1.frame) - int(s0.frame)))
	_press(ctx, KEYS.anim_freeze)
	ctx.check(o.frozen and not a.auto_process, "F5 freezes (PlayerAnim auto_process off)")
	var hash0 := AnimRecorder.pose_hash(h.rig.sk)
	var f0 := a.debug_snapshot()
	var same := true
	for i in 10:
		await ctx.idle_frames(1)
		await ctx.frames(1)
		var fi := a.debug_snapshot()
		same = same and AnimRecorder.pose_hash(h.rig.sk) == hash0 and fi.time == f0.time and fi.frame == f0.frame \
				and _positions(fi) == _positions(f0)
	ctx.check(same, "frozen: bone poses, clip positions and the clock unchanged for 10 frames")
	ctx.check(o.status_text().contains("FROZEN"), "status line says FROZEN")
	_press(ctx, KEY_F6)
	var f1 := a.debug_snapshot()
	ctx.near(float(f1.time) - float(f0.time), 1.0 / 60.0, 1e-9, "F6 steps the clock by exactly 1/60 s")
	ctx.check(int(f1.frame) == int(f0.frame) + 1, "F6 runs exactly one frame (%d -> %d)" % [f0.frame, f1.frame])
	ctx.check(AnimRecorder.pose_hash(h.rig.sk) != hash0, "F6 changes the pose")
	var step_err := _step_error(f0, f1)
	ctx.at_most(step_err, 1e-4, "F6: every weighted clip advanced by rate x 1/60 s (max error, s)")
	var hash1 := AnimRecorder.pose_hash(h.rig.sk)
	same = true
	for i in 10:
		await ctx.idle_frames(1)
		same = same and AnimRecorder.pose_hash(h.rig.sk) == hash1 and a.debug_snapshot().frame == f1.frame
	ctx.check(same and o.frozen, "still frozen after the step")
	_press(ctx, KEY_F6, true)
	ctx.check(int(a.debug_snapshot().frame) == int(f1.frame) + 1, "F6 key repeat steps again")
	_press(ctx, KEYS.anim_freeze)
	ctx.check(not o.frozen and a.auto_process, "F5 resumes (auto_process restored)")
	var r0: int = a.frame
	await ctx.idle_frames(3)
	ctx.check(a.frame > r0, "resumed: the facade advances again")
	a.auto_process = false

	# F7: time scale.
	var ts0 := Engine.time_scale
	var seen := []
	for i in 3:
		_press(ctx, KEY_F7)
		seen.append(snappedf(Engine.time_scale, 1e-6))
	ctx.check(seen.size() == 3 and absf(seen[0] - 0.25) < 1e-6 and absf(seen[1] - 0.1) < 1e-6 and absf(seen[2] - ts0) < 1e-6,
			"F7 cycles Engine.time_scale 0.25 -> 0.1 -> back to %s (%s)" % [ts0, seen])
	Engine.time_scale = ts0

	# F8: one toggle at a time, back to the start.
	var base: Dictionary = a.debug_snapshot().options
	var items := o.option_items(base)
	var ov: Dictionary = base.overrides
	var all_off := true
	for f in PlayerAnim.OVERRIDE_FLAGS:
		all_off = all_off and ov.has(f) and ov[f] == false
	ctx.check(all_off, "graph-faithful defaults: every gameplay override is off")
	var names := []
	for it in items:
		names.append(it.name)
	var covered := true
	for f in PlayerAnim.OVERRIDE_FLAGS:
		covered = covered and f in names
	ctx.check(covered and not "aim_walk" in names, "F8 covers every override flag and leaves out aim_walk (%d toggles)" % items.size())
	var one_ok := true
	var worst := ""
	for k in items.size():
		_press(ctx, KEY_F8)
		h.run(1, Vector2(0, 1), 3.6)
		var diff := _option_diff(items, a.debug_snapshot().options)
		if diff != [items[k].name]:
			one_ok = false
			worst = "step %d: %s" % [k + 1, diff]
	ctx.check(one_ok, "F8 flips exactly the next toggle each press %s" % worst)
	_press(ctx, KEY_F8)
	h.run(1)
	ctx.check(_option_diff(items, a.debug_snapshot().options).is_empty() and o.option_index == 0, "F8 after the last toggle restores the start")
	h.run(30)

	# F9-F12 inert in release (OS.is_debug_build() stubbed false).
	o.debug_build = false
	var tr0: int = a.upper.snapshot().trace.size()
	var st0 := String(a.loco.state)
	var shown0 := o.shown
	for k in KEYS.values():
		_press(ctx, k)
	for b in o.find_children("*", "Button", true, false):
		(b as Button).pressed.emit()
	h.run(3)
	var kinds := _upper_kinds(a, tr0)
	ctx.check(not "hurt" in kinds and not "hurt_heavy" in kinds and not "died" in kinds and not "revive" in kinds,
			"release: F9-F12 and the buttons do nothing (upper trace %s)" % [kinds])
	ctx.check(not String(a.loco.state) in ["HIT", "DEATH"] and not bool(a.upper.snapshot().dead),
			"release: no hit or death in the lower body (%s -> %s)" % [st0, a.loco.state])
	ctx.check(o.shown == shown0 and not o.frozen and o.option_index == 0 and o.time_scale_index == 0 and absf(Engine.time_scale - ts0) < 1e-6,
			"release: F4-F8 do nothing either (shown %s/%s frozen %s options %d time %d x%s)" % [o.shown, shown0, o.frozen, o.option_index,
			o.time_scale_index, Engine.time_scale])
	o.debug_build = true

	# F9-F12 in debug builds (no player on the rig: straight to PlayerAnim).
	h.run(30)
	tr0 = a.upper.snapshot().trace.size()
	_press(ctx, KEYS.debug_hit_light)
	h.run(2)
	kinds = _upper_kinds(a, tr0)
	var ha := false
	for s in a.upper.snapshot().active_oneshots:
		ha = ha or String(s.node).begins_with("HA__")
	ctx.check("hurt" in kinds and ha, "F9: light hit (hr-bliz additive playing) [%s]" % o.last_action)
	h.run(40)
	_press(ctx, KEY_F10)
	h.run(2)
	ctx.check(a.loco.state == &"HIT", "F10: heavy hit, lower body HIT (%s) [%s]" % [a.loco.state, o.last_action])
	h.run(120)
	_press(ctx, KEY_F11)
	h.run(2)
	ctx.check(a.loco.state == &"DEATH" and bool(a.upper.snapshot().dead), "F11: death (%s) [%s]" % [a.loco.state, o.last_action])
	h.run(60)
	_press(ctx, KEY_F12)
	h.run(2)
	ctx.check(a.loco.state != &"DEATH" and not bool(a.upper.snapshot().dead), "F12: revive (%s) [%s]" % [a.loco.state, o.last_action])
	_press(ctx, KEY_F7)
	ctx.check(absf(Engine.time_scale - 0.25) < 1e-6, "F7 slow motion on before freeing the overlay")
	_press(ctx, KEYS.anim_freeze)
	ctx.check(o.frozen and not a.auto_process, "frozen before freeing the overlay")
	_press(ctx, KEY_F8)
	ctx.check(o.option_index == 1, "F8 mid-cycle before freeing the overlay (%s)" % o.option_label())
	o.queue_free()
	await ctx.idle_frames(1)
	h.run(1)
	ctx.check(_option_diff(items, a.debug_snapshot().options).is_empty(), "freeing the overlay mid-F8-cycle restores the flipped toggle")
	ctx.check(absf(Engine.time_scale - ts0) < 1e-6, "freeing the overlay restores the time scale (x%s)" % Engine.time_scale)
	ctx.check(a.auto_process == false and not is_instance_valid(o), "freeing a frozen overlay restores PlayerAnim.auto_process (rig: off)")
	var o2 := AnimDebugOverlay.new()
	ctx.add_node(o2)
	o2.bind(a)
	a.auto_process = true
	var hold0: bool = a.stabilizer.trim_hold if a.stabilizer != null else false
	o2.set_frozen(true)
	ctx.check(a.stabilizer == null or a.stabilizer.trim_hold, "freezing holds the AimStabilizer's aim-trim residual")
	o2.free()
	ctx.check(a.auto_process, "freeing a frozen overlay gives PlayerAnim its auto_process back (on)")
	ctx.check(a.stabilizer == null or a.stabilizer.trim_hold == hold0, "freeing a frozen overlay gives the stabilizer its trim_hold back (%s)" % hold0)
	var o3 := AnimDebugOverlay.new()
	ctx.add_node(o3)
	o3.bind(a)
	o3.set_frozen(true)
	o3.bind(a)
	ctx.check(not o3.frozen and a.auto_process and (a.stabilizer == null or a.stabilizer.trim_hold == hold0),
			"bind() while frozen resumes first (auto_process and trim_hold back)")
	o3.free()
	a.auto_process = false


## Every weighted clip's position (node, hemi) -> seconds.
static func _positions(snap: Dictionary) -> Dictionary:
	var out := {}
	for s: Dictionary in snap.get("slots", []):
		out["%s/%s" % [s.node, s.hemi]] = s.position
	return out


## Max |observed - expected| clip advance over one F6 step, expected = rate x 1/60 (mod length).
static func _step_error(a: Dictionary, b: Dictionary) -> float:
	var pa := {}
	for s: Dictionary in a.get("slots", []):
		pa["%s/%s" % [s.node, s.hemi]] = s
	var worst := 0.0
	var n := 0
	for s: Dictionary in b.get("slots", []):
		var k := "%s/%s" % [s.node, s.hemi]
		if not pa.has(k):
			continue
		var length := float(s.length)
		if length <= 0.0:
			continue
		n += 1
		var d := fposmod(float(s.position) - float(pa[k].position), length)
		var e := fposmod(float(s.rate) / 60.0, length)
		var err := absf(d - e)
		worst = maxf(worst, minf(err, length - err))
	return worst if n > 0 else INF


static func _option_diff(items: Array, opts: Dictionary) -> Array:
	var out := []
	for it: Dictionary in items:
		var v: Variant = opts.get("overrides", {}).get(it.name) if it.kind == "override" else opts.get("options", {}).get(it.name)
		if bool(v) != bool(it.base):
			out.append(it.name)
	return out


static func _upper_kinds(a: PlayerAnim, from: int) -> Array:
	var tr: Array = a.upper.snapshot().trace
	var out := []
	for i in range(mini(from, tr.size()), tr.size()):
		out.append(String(tr[i].get("kind", "")))
	return out


## One key press and release through the root viewport (InputMap, _unhandled_input).
static func _press(ctx: AnimTestContext, key: int, echo := false) -> void:
	var code := key & KEY_CODE_MASK
	var shift := (key & KEY_MASK_SHIFT) != 0
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.shift_pressed = shift
	e.pressed = true
	e.echo = echo
	ctx.tree.root.push_input(e)
	var r := InputEventKey.new()
	r.physical_keycode = code
	r.keycode = code
	r.shift_pressed = shift
	r.pressed = false
	ctx.tree.root.push_input(r)


# --- level ----------------------------------------------------------------------------------

func _level(ctx: AnimTestContext) -> void:
	var player = await ctx.level()
	if player == null:
		return
	var a: PlayerAnim = player.get("anim")
	var o := AnimDebugOverlay.attach(player)
	ctx.check(o != null and o.anim == a and o.get_parent() == player, "level: attach() puts the overlay on the player, bound to its PlayerAnim")
	ctx.check(AnimDebugOverlay.attach(player) == o, "level: a second attach() returns the same overlay")
	var n := 0
	for c in player.get_children():
		if c is AnimDebugOverlay:
			n += 1
	ctx.check(n == 1, "level: one overlay on the player (%d)" % n)
	o.debug_build = true
	var hud: FrontierHUD = player.get("hud")
	var hud0 := hud.show_debug
	_press(ctx, KEY_F3)
	ctx.check(hud.show_debug != hud0 and not o.shown, "level: F3 toggles the HUD's debug line, not the overlay")
	_press(ctx, KEY_F4)
	ctx.check(o.shown and hud.show_debug != hud0, "level: F4 toggles the overlay, not the HUD")
	_press(ctx, KEY_F3)
	ctx.check(hud.show_debug == hud0 and o.shown, "level: F3 again restores the HUD; the overlay stays")
	await ctx.frames(10)
	var t := o.panel_texts()
	ctx.check(t[0].contains("GRAPH FIELDS") and t[1].contains("LOWER") and t[2].contains("native_asset_id"),
			"level: the three panels render the player's snapshot")
	_press(ctx, KEYS.anim_freeze)
	var hash0 := AnimRecorder.pose_hash(player.skeleton)
	var f0: int = a.frame
	await ctx.frames(10)
	await ctx.idle_frames(2)
	ctx.check(o.frozen and a.frame == f0 and AnimRecorder.pose_hash(player.skeleton) == hash0,
			"level: F5 freezes the player's animation (pose and frame unchanged for 10 physics frames)")
	var t0 := float(a.debug_snapshot().time)
	_press(ctx, KEY_F6)
	ctx.check(a.frame == f0 + 1, "level: F6 steps one frame")
	ctx.near(float(a.debug_snapshot().time) - t0, 1.0 / 60.0, 1e-9, "level: F6 steps exactly 1/60 s")
	_press(ctx, KEYS.anim_freeze)
	await ctx.frames(10)
	ctx.check(not o.frozen and a.auto_process and a.frame > f0 + 1, "level: F5 resumes")
	await _level_aimed_freeze(ctx, player, o)
	await _level_provenance_fit(ctx, a, o)
	var tr0: int = a.upper.snapshot().trace.size()
	_press(ctx, KEYS.debug_hit_light)
	await ctx.frames(6)
	var kinds := _upper_kinds(a, tr0)
	ctx.check("hurt" in kinds or "hurt_skipped" in kinds, "level: F9 lands a light hit (%s) [%s]" % [kinds, o.last_action])
	# Timed at the game's 1280x720 layout (the 64x64 headless viewport would cut panel 3 each time).
	o.layout_size = Vector2(1280, 720)
	o.refresh()
	var us := []
	for i in 20:
		await ctx.frames(1)
		var t0u := Time.get_ticks_usec()
		o.refresh()
		us.append(Time.get_ticks_usec() - t0u)
	o.layout_size = Vector2.ZERO
	us.sort()
	var mean := 0.0
	for u in us:
		mean += float(u) / us.size()
	ctx.metric("refresh_ms_mean", mean / 1000.0)
	ctx.metric("refresh_ms_max", float(us[us.size() - 1]) / 1000.0)
	ctx.info("level: one panel refresh at 1280x720 (debug_snapshot + render) takes %.2f ms mean, %.2f ms max; at %.0f Hz while shown, nothing while hidden"
			% [mean / 1000.0, float(us[us.size() - 1]) / 1000.0, o.refresh_hz])
	_press(ctx, KEY_F4)
	ctx.check(not o.shown, "level: F4 hides the panels")
	if player.has_method("respawn"):
		player.call("respawn")
	await ctx.frames(10)


## F5 with the musket raised: the AimStabilizer runs after the frozen pose every frame, so the
## rendered (post-modifier) weapon socket must hold relative to the body while the body turns
## (the mouse turns it); F6 lets one frame of the aim-trim residual learn, then holds it again.
## The socket is a BoneAttachment3D, which sees the modified pose (AnimRecorder.pose_hash does not).
func _level_aimed_freeze(ctx: AnimTestContext, player: Node, o: AnimDebugOverlay) -> void:
	var a: PlayerAnim = player.get("anim")
	var stab := a.stabilizer
	var sock: Node3D = (player.get("skeleton") as Skeleton3D).get_node_or_null("%s_socket" % player.get("weapon_key"))
	if stab == null or sock == null or not "yaw" in player:
		ctx.fail("level: no AimStabilizer, weapon socket or player.yaw (%s, %s)" % [stab, sock])
		return
	Input.action_press("aim")
	await ctx.frames(120)
	ctx.check(stab.trim_learn and not stab.trim_hold and float(a.debug_snapshot().derived.get("upper_aim_w", 0.0)) >= 0.95,
			"level: %s raised, the stabilizer's aim-trim residual is learning" % player.get("weapon_key"))
	_press(ctx, KEYS.anim_freeze)
	ctx.check(o.frozen and stab.trim_hold, "level: F5 holds the stabilizer's aim-trim residual")
	await ctx.idle_frames(2)
	var ref := _rel(player, sock)
	var trim0 := stab.last_trim_deg()
	player.set("yaw", float(player.get("yaw")) + deg_to_rad(25.0))
	var worst := 0.0
	for i in 15:
		await ctx.frames(1)
		await ctx.idle_frames(1)
		worst = maxf(worst, _ang(ref, _rel(player, sock)))
	ctx.at_most(worst, 0.1, "level: frozen and aimed, body turned 25 deg over 15 frames: weapon socket vs the body (deg)")
	ctx.check(stab.last_trim_deg() == trim0, "level: frozen: the applied aim trim stays %s" % trim0)
	_press(ctx, KEY_F6)
	ctx.check(not stab.trim_hold, "level: F6 lets the stepped frame's stabilizer pass learn")
	await ctx.idle_frames(1)
	var d := (stab.last_trim_deg() - trim0).abs()
	ctx.check(stab.trim_hold, "level: F6: the residual is held again after that skeleton update")
	ctx.at_most(maxf(d.x, d.y), stab.trim_rate_deg_s / 60.0 + 0.05, "level: F6 moves the trim by at most one frame of learning (deg)")
	await ctx.idle_frames(1)
	ref = _rel(player, sock)
	player.set("yaw", float(player.get("yaw")) - deg_to_rad(25.0))
	worst = 0.0
	for i in 12:
		await ctx.frames(1)
		await ctx.idle_frames(1)
		worst = maxf(worst, _ang(ref, _rel(player, sock)))
	ctx.at_most(worst, 0.1, "level: still frozen after F6, body turned back 25 deg: weapon socket vs the body (deg)")
	_press(ctx, KEYS.anim_freeze)
	ctx.check(not o.frozen and a.auto_process and not stab.trim_hold, "level: F5 resumes; trim_hold back to its value before the freeze")
	Input.action_release("aim")
	await ctx.frames(60)


## Panel 3 at 1280x720 for every graph role with its weapon / stance aim base (the pairs
## debug_snapshot() shows): it ends above the crosshair, compacted where needed.
func _level_provenance_fit(ctx: AnimTestContext, a: PlayerAnim, o: AnimDebugOverlay) -> void:
	if not a.has_method("_prov_entry"):
		ctx.info("level: PlayerAnim._prov_entry is gone; the panel 3 sweep over every role is skipped")
		return
	var shown0 := o.shown
	o.toggle(true)
	o.layout_size = Vector2(1280, 720)
	var roles: Dictionary = a.data.graph.get("roles", {})
	var levels := {}
	var n := 0
	var over := []
	var worst := 0.0
	var worst_key := ""
	for key in roles:
		var parts := String(key).split("/")
		if parts.size() < 3:
			continue
		var st := "crouch" if parts[1] == "crouch" else "stand"
		var prov := {String(key): a.call("_prov_entry", roles[key])}
		var base: Dictionary = a.data.aim_tree(parts[0], st).get("base", {})
		if not base.is_empty():
			prov["aim/%s/%s/base" % [parts[0], st]] = a.call("_prov_entry", base)
		o.render({"ok": true, "provenance": prov, "attribution": a.data.attribution()})
		n += 1
		var tag := "%d%s" % [o.provenance_level, " cut" if o.provenance_clipped else ""]
		levels[tag] = int(levels.get(tag, 0)) + 1
		var b := _prov_bottom(o)
		if b > o.provenance_limit() + 0.5:
			over.append(String(key))
		if b > worst:
			worst = b
			worst_key = String(key)
	ctx.check(n > 100 and over.is_empty(), "level: 1280x720, panel 3 ends above the crosshair for all %d roles (worst %s at %.0f px, limit %.0f) %s"
			% [n, worst_key, worst, o.provenance_limit(), over.slice(0, 5)])
	ctx.info("level: panel 3 levels used (level: roles): %s" % [levels])
	o.layout_size = Vector2.ZERO
	o.toggle(shown0)
	o.refresh()


static func _rel(player: Node, n: Node3D) -> Transform3D:
	return (player as Node3D).global_transform.affine_inverse() * n.global_transform


## Rotation between two transforms (deg), as 2 atan2(|v|, |w|) of the relative quaternion:
## Quaternion.angle_to (acos) has a float32 floor of about 0.04 deg near identity.
static func _ang(x: Transform3D, y: Transform3D) -> float:
	var q := (x.basis.get_rotation_quaternion().inverse() * y.basis.get_rotation_quaternion()).normalized()
	return rad_to_deg(2.0 * atan2(Vector3(q.x, q.y, q.z).length(), absf(q.w)))
