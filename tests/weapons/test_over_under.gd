extends SceneTree
## Over-under turnover gun (weapons_balance_design.md 4.6): the barrel logic, the model's node
## contract and muzzle positions, the balance row, and the gun driven through the real player in
## scenes/main.tscn with Input.action_press, as tests/smoke_test.gd drives the musket.
##
##   Godot --headless --fixed-fps 120 --path . -s tests/weapons/test_over_under.gd -- --no-capture quality=low
##
## --fixed-fps 120 runs one physics tick per frame, faster than real time and reproducible
## (without it the run takes about a minute of real time). Kill it after 180 s: a script error
## leaves Godot running. Times are checked to +-2 physics ticks (1/120 s). The anim / audio
## routing part is reported "pending" until hooks H6 / H7 / H9 are in; before them the kit's dev
## bridge (the musket's rows and sounds) is checked instead.

const TOL := 2                    ## ticks
const HZ := 120.0

var failures := PackedStringArray()
var pending := PackedStringArray()
var checks := 0
var player: FrontierPlayer
var w: OverUnderMusket
var tick := 0
var ev: Array = []                ## [{t, k, a, d, ...}]


func _initialize() -> void:
	seed(1750)
	physics_frame.connect(func() -> void: tick += 1)
	print("== logic")
	_test_logic()
	print("== model")
	await _test_model()
	print("== balance row")
	_test_balance_row()
	if not await _boot():
		_finish()
		return
	print("== 12 handling (aim-in)")
	await _test_aim_in()
	print("== 1 fire the top barrel")
	await _test_fire_top()
	print("== 2 snapped second barrel")
	await _test_snapped_second()
	print("== 4 reload both barrels")
	await _test_reload_both()
	print("== 3 settled second barrel")
	await _test_settled_second()
	print("== 5 emergency, bottom in place")
	await _test_emergency_bottom()
	print("== 6 emergency, top reload")
	await _test_emergency_top()
	print("== 7 turnover cancel and finish")
	await _test_cancel_finish()
	print("== 8 chain turnover cancel")
	await _test_chain_cancel()
	print("== 9 out of loads")
	await _test_out_of_loads()
	print("== 10 crouched turnover")
	await _test_crouched()
	print("== 12 handling (brace, hold fatigue)")
	await _test_handling()
	print("== 14 full cycle (fire top, turn, fire bottom, empty, reload one, fire, reload both)")
	await _test_full_cycle()
	print("== 15 no shortcut: a turnover cut after its latch leaves the cock at half cock")
	await _test_cut_half_cock()
	print("== 13 animation and audio routing")
	await _test_routing()
	print("== ballistics")
	await _test_ballistics()
	_finish()


func _finish() -> void:
	for p in pending:
		print("PENDING: ", p)
	if failures.is_empty():
		print("OVER-UNDER TEST PASSED (%d checks, %d pending)" % [checks, pending.size()])
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("OVER-UNDER TEST FAILED (%d of %d)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)


func _check(cond: bool, msg: String) -> bool:
	checks += 1
	if not cond:
		failures.append(msg)
	print(("  ok   " if cond else "  FAIL ") + msg)
	return cond


func _near_ticks(got: int, want_s: float, what: String) -> void:
	var want := want_s * HZ
	_check(absf(float(got) - want) <= TOL + 0.5, "%s: %.3f s (want %.3f +- %d ticks)" % [what, got / HZ, want_s, TOL])


# --- Logic (OverUnderBarrels) ------------------------------------------------------------

func _test_logic() -> void:
	var b := OverUnderBarrels.new()
	_check(b.barrels_loaded() == [true, true] and b.glyphs() == "▲● ▼●", "starts with both barrels ready (▲● ▼●)")
	_check(b.fire() == 0 and b.barrels_loaded() == [false, true], "fire: barrel A fired, [○, ●]")
	_check(b.glyphs() == "▲○ ▼●", "glyphs after the shot: ▲○ ▼●")
	_check(b.fire() == -1, "a spent top barrel cannot fire")
	b.flip()
	_check(b.top == 1 and b.barrels_loaded() == [true, false], "flip: B on top, [●, ○]")
	b.flip()
	# next_work for every start of the chain table (design 2.4).
	var r := 10
	_check(_nw(b, r) == "step:0:0", "[○, ●]: charge the top in place from step 0")
	var took := b.begin_step(0)
	_check(took and b.load_in[0], "a load is taken when step 0 begins")
	_check(not b.begin_step(0), "an interrupted step 0 does not take a second load")
	for i in 4:
		b.finish_step(0)
	_check(b.stage[0] == 4 and b.glyph(0) == "◑", "after steps 0-3 the top is charged, not primed (◑)")
	_check(_nw(b, 0) == "step:0:4", "[◑, ●] with no loads: priming still goes (powder from the horn)")
	b.finish_step(0)
	_check(_nw(b, r) == "done", "[●, ●]: nothing to do")
	b.stage = PackedInt32Array([5, 0])
	b.load_in = [true, false]
	_check(_nw(b, r) == "step:1:0", "[●, ○]: charge the bottom in place")
	_check(_nw(b, 0) == "done", "[●, ○] with no loads: nothing to do")
	b.stage = PackedInt32Array([5, 2])
	b.load_in = [true, true]
	_check(_nw(b, 0) == "step:1:2", "a partly charged bottom resumes at its own step (load already in)")
	b.stage = PackedInt32Array([5, 4])
	_check(_nw(b, r) == "turn", "[●, ◑]: turn over, then prime on top")
	_check(not b.can_step(1, 4) and not b.can_work(1, r), "priming is refused underneath")
	b.stage = PackedInt32Array([0, 0])
	b.load_in = [false, false]
	_check(_nw(b, r) == "step:0:0", "[○, ○]: the top first")
	_check(_nw(b, 0) == "done", "[○, ○] with no loads: nothing to do")
	b.stage = PackedInt32Array([0, 4])
	b.load_in = [false, true]
	_check(_nw(b, 0) == "turn", "[○, ◑] with no loads: turn the charged one up to prime it")
	b.stage = PackedInt32Array([2, 5])
	b.load_in = [true, true]
	_check(b.glyph(0) == "◐" and _nw(b, 0) == "step:0:2", "a partly charged top (◐) resumes at its step")
	var steps := [["a", 1.3], ["b", 1.8], ["c", 2.2], ["d", 1.3], ["e", 1.6]]
	b.stage = PackedInt32Array([0, 0])
	_check(is_equal_approx(b.work_seconds(0, steps), 8.2) and is_equal_approx(b.work_seconds(1, steps), 6.6),
			"work left: 8.2 s on top (charge + prime), 6.6 s below (charge only)")
	var snap := b.snapshot()
	var c := OverUnderBarrels.new()
	c.restore(snap)
	_check(c.snapshot() == snap, "snapshot / restore round trip")


func _nw(b: OverUnderBarrels, reserve: int) -> String:
	var n := b.next_work(reserve)
	match String(n.do):
		"step":
			return "step:%d:%d" % [int(n.barrel), int(n.step)]
	return String(n.do)


# --- Model --------------------------------------------------------------------------------

func _test_model() -> void:
	_check(OverUnderModel.has_glb(), "assets/weapons/over_under.glb is imported")
	for fb: bool in [false, true]:
		var tag := "fallback" if fb else "glb"
		var m := OverUnderModel.build(fb)
		_check(OverUnderModel.check(m).is_empty(), "%s: node contract %s" % [tag, OverUnderModel.check(m)])
		root.add_child(m)
		await process_frame
		var g := func(p: String) -> Vector3: return (m.get_node(p) as Node3D).global_position
		_check(g.call("Muzzle").distance_to(Vector3(0, 0.035, -1.042)) < 1e-4, "%s: Muzzle on the top bore at the muzzle face" % tag)
		_check(g.call("Muzzle_bottom").distance_to(Vector3(0, 0.008, -1.042)) < 1e-4, "%s: Muzzle_bottom 27 mm below" % tag)
		_check(g.call("Barrels/MuzzleA").distance_to(g.call("Muzzle_top")) < 1e-4
				and g.call("Barrels/MuzzleB").distance_to(g.call("Muzzle_bottom")) < 1e-4, "%s: at rest A is on top, B below" % tag)
		_check(g.call("Barrels/PanA").distance_to(g.call("Pan")) < 1e-4, "%s: barrel A's pan under the cock" % tag)
		_check(g.call("LeftGrip").distance_to(Vector3(-0.012, -0.002, -0.270)) < 1e-4, "%s: LeftGrip at the musket's left palm" % tag)
		var rig := OverUnderRig.new()
		rig.bind(m)
		(m.get_node("Barrels") as Node3D).basis = Basis(Vector3.BACK, PI)
		await process_frame
		_check(g.call("Barrels/MuzzleB").distance_to(g.call("Muzzle_top")) < 1e-4
				and g.call("Barrels/MuzzleA").distance_to(g.call("Muzzle_bottom")) < 1e-4, "%s: turned over, B's muzzle is the top muzzle" % tag)
		_check(g.call("Barrels/PanB").distance_to(g.call("Pan_top")) < 1e-4
				and g.call("Barrels/PanA").distance_to(g.call("Pan_bottom")) < 1e-4, "%s: turned over, B's pan is under the cock" % tag)
		var fa := m.get_node("Barrels/FrizzenA") as Node3D
		var fbz := m.get_node("Barrels/FrizzenB") as Node3D
		(m.get_node("Barrels") as Node3D).basis = Basis.IDENTITY
		await process_frame
		var fa_turned := Transform3D(Basis(Vector3.BACK, PI), Vector3(0, 0.0215, 0)) * Transform3D(Basis.IDENTITY, Vector3(0, -0.0215, 0))
		_check(fbz.global_position.distance_to(fa_turned * fa.global_position) < 1e-3, "%s: FrizzenB is FrizzenA turned about the swivel" % tag)
		m.queue_free()
		await process_frame


# --- Balance row --------------------------------------------------------------------------

func _test_balance_row() -> void:
	var bal: Variant = null
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if String(c.get("class", "")) == "WeaponBalance":
			bal = load(String(c.path))
	if bal == null:
		pending.append("WeaponBalance not present: row equality not checked")
		return
	var row: Dictionary = bal.call("row", "over_under")
	if not _check(not row.is_empty(), "ballistics.json has the over_under row"):
		return
	var g := OverUnderMusket.new()
	var bad := PackedStringArray()
	for k: String in row.get("set", {}):
		var want := float(row.set[k])
		var got: Variant = g.get(k)
		if got == null or absf(float(got) - want) > 1e-6:
			bad.append("%s %s != %s" % [k, str(got), str(want)])
	_check(bad.is_empty(), "OverUnderMusket defaults equal the JSON row's set %s" % [bad])
	var steps: Array = row.get("mechanism", {}).get("steps", [])
	var same := steps.size() == g.reload_stages.size()
	for i in mini(steps.size(), g.reload_stages.size()):
		var a: Array = steps[i]
		var s: Array = g.reload_stages[i]
		same = same and String(a[0]) == String(s[0]) and is_equal_approx(float(a[1]), float(s[1])) \
				and String(a[2]) == String(s[2]) and String(a[3]) == String(s[3])
	_check(same, "reload_stages equal mechanism.steps")
	var mech: Dictionary = row.get("mechanism", {})
	var mech_ok := true
	for k in ["turnover_s", "full_cock_s", "finish_after_commit_max_s", "start_reserve"]:
		mech_ok = mech_ok and is_equal_approx(float(mech.get(k, -1)), float(g.mechanism.get(k, -2)))
	for k in ["commit_s", "turn_window_s"]:
		mech_ok = mech_ok and str(mech.get(k)) == str(g.mechanism.get(k))
	_check(mech_ok, "mechanism timings equal the script's")
	var mk := Musket.new()
	_check(g is Musket and g.clips.get("aim") == mk.clips.get("aim") and g.relaxed == mk.relaxed
			and g.aim_yaw_offset_deg == mk.aim_yaw_offset_deg, "OverUnderMusket is a Musket (clips, carry, aim offsets inherited)")
	mk.free()
	var r: Dictionary = bal.call("apply", g, "over_under")
	_check(bool(r.get("ok")) and (r.get("skipped") as PackedStringArray).is_empty(), "WeaponBalance.apply(w, \"over_under\") applies every property")
	g.free()


# --- Level --------------------------------------------------------------------------------

func _boot() -> bool:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	player = current_scene.get_node_or_null("Player") if current_scene else null
	if not _check(player != null, "level and player load"):
		return false
	player.ignore_mouse_capture = true
	await _frames(30)
	# (a weapon gained goes to the pack, never onto the hotbar by itself: put on its last slot, as the player would drag it;
	# Hotbar, the owner 2026-10-02: "pickups shouldnt auto fill")
	OverUnderKit.install(player, true)
	var hb := Hotbar.find(player)
	if hb != null:
		hb.assign(Hotbar.SLOTS - 1, Hotbar.make("weapon", "over_under"))
	w = OverUnderKit.select(player)
	_check(w != null and player.weapons.get("over_under") == w and "over_under" in player.weapon_order,
			"OverUnderKit.install: in player.weapons and weapon_order")
	_check(OverUnderKit.install(player) == w and player.weapon_order.count("over_under") == 1, "install is idempotent")
	_check(InputMap.has_action("weapon_%d" % player.weapon_order.size()), "its number key exists (weapon_%d)" % player.weapon_order.size())
	_check(w.model.get_parent() is BoneAttachment3D and (w.model.get_parent() as BoneAttachment3D).bone_name == "r_hand_prop_attachment"
			and w.model.transform.is_equal_approx(player.musket_offset), "model on the right prop bone with the musket's attach transform")
	w.action_started.connect(func(k: String, d: float) -> void:
		ev.append({"t": tick, "k": "action", "a": k, "d": d, "reserve": w.reserve, "barrel": w.work_barrel, "step": w.work_step}))
	w.action_cancelled.connect(func() -> void: ev.append({"t": tick, "k": "cancel"}))
	w.barrels_turned.connect(func(top: int) -> void: ev.append({"t": tick, "k": "latch", "a": top}))
	w.sfx.connect(func(id: StringName, _at: Vector3) -> void: ev.append({"t": tick, "k": "sfx", "a": String(id)}))
	w.shot_cancelled.connect(func() -> void: ev.append({"t": tick, "k": "shot_cancelled"}))
	w.fired.connect(_on_fired)
	# the graph switch (holster, finish, grab, draw) takes longer than the draw alone
	await _until(func() -> bool: return player.weapon == w and not player.is_switching() and not w.is_equipping(), 900)
	_check(player.weapon == w and not w.is_equipping(), "over-under drawn (equip %.1f s)" % w.equip_time)
	_check(w.reserve == 10 and w.barrels_loaded() == [true, true], "starts with both barrels loaded and 10 loads")
	return true


func _on_fired() -> void:
	var top := w.barrels.top
	var m := w.rig.muzzle_of(top)
	ev.append({"t": tick, "k": "fired", "spread": w.spread, "barrel": top,
			"origin_err": w.launch_origin().distance_to(w.muzzle.global_position),
			"muzzle": String(m.name) if m else ""})


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _until(cond: Callable, max_ticks: int) -> bool:
	for i in max_ticks:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func _release_all() -> void:
	for a in ["fire", "aim", "reload", "sprint", "move_forward", "crouch"]:
		Input.action_release(a)


## Puts the barrels in a known state: top / bottom stages (5 = ready), `top` physical barrel.
func _load_state(top_stage: int, bottom_stage: int, reserve := 10, top := 0) -> void:
	_release_all()
	await _frames(2)
	w.turning = false
	w.chain = false
	w.work_barrel = -1
	w.work_step = -1
	w._turn_queued = false
	w._fire_intent = false
	w._release_queued = false
	w.half_cocked = false
	var b := w.barrels
	b.top = top
	var st := PackedInt32Array([0, 0])
	st[top] = top_stage
	st[1 - top] = bottom_stage
	b.stage = st
	b.load_in = [st[0] > 0, st[1] > 0]
	w.reserve = reserve
	w.state = Firearm.State.READY if b.is_ready(b.top) else Firearm.State.EMPTY
	w._mirror()
	w._hold_t = 0.0
	w.rig.update(w, 0.0, true)
	await _frames(70)          # settle: aim back to the carry, spread to its carry cone


func _events(kind: String, since: int) -> Array:
	return ev.filter(func(e: Dictionary) -> bool: return e.k == kind and int(e.t) >= since)


func _first(kind: String, since: int, a: Variant = null) -> Dictionary:
	for e: Dictionary in ev:
		if e.k == kind and int(e.t) >= since and (a == null or e.get("a") == a):
			return e
	return {}


## Holds LMB until the gun is fully up, releases, and returns the tick of the discharge.
func _shoot_settled(hold_after_full := 0) -> int:
	var t0 := tick
	Input.action_press("fire")
	await _until(func() -> bool: return w.aim >= 1.0, 240)
	await _frames(hold_after_full)
	Input.action_release("fire")
	await _until(func() -> bool: return not _first("fired", t0).is_empty(), 60)
	return int(_first("fired", t0).get("t", -1))


# --- Sequences ----------------------------------------------------------------------------

func _test_aim_in() -> void:
	await _load_state(5, 5)
	var t0 := tick
	Input.action_press("fire")
	await _until(func() -> bool: return w.aim >= w.ready_aim, 120)
	_near_ticks(tick - t0, 0.85 * 0.45, "aim reaches ready_aim (0.85) from the carry")
	await _tap("aim")
	_check(w.state == Firearm.State.READY and w.barrels_loaded() == [true, true], "RMB while holding LMB lowers without firing")
	Input.action_release("fire")
	await _frames(20)


func _tap(action: String, hold := 2) -> void:
	Input.action_press(action)
	await _frames(hold)
	Input.action_release(action)
	await _frames(1)


func _test_fire_top() -> void:
	await _load_state(5, 5)
	var d := await _shoot_settled()
	_check(d > 0, "the top barrel fires")
	var f := _first("fired", d)
	_check(int(f.get("barrel", -1)) == 0 and String(f.get("muzzle", "")) == "MuzzleA", "barrel A fired from its own muzzle")
	_check(float(f.get("origin_err", 1.0)) < 0.002, "shot leaves at the Muzzle marker (%.4f m)" % float(f.get("origin_err", 1.0)))
	_check(w.ammo_text().begins_with("▲○ ▼●"), "HUD after the shot: %s" % w.ammo_text())
	await _frames(int(0.35 * HZ) + 4)
	_check(w.barrels_loaded() == [false, true] and w.state == Firearm.State.EMPTY, "[○, ●], state EMPTY after the recoil")
	_check(w.status_text().begins_with("Top barrel fired"), "status: %s" % w.status_text())


func _test_snapped_second() -> void:
	await _load_state(5, 5)
	var t0 := tick
	var d1 := await _shoot_settled()
	await _frames(10)
	Input.action_press("fire")               # during the recoil
	await _frames(2)
	var turn: Dictionary = {}
	await _until(func() -> bool: return not _first("action", t0, "turnover").is_empty(), 90)
	turn = _first("action", t0, "turnover")
	_check(not turn.is_empty() and is_equal_approx(float(turn.get("d", 0.0)), 1.3), "action_started(\"turnover\", 1.3) after the recoil")
	var ts := int(turn.get("t", 0))
	_near_ticks(ts - d1, 0.35, "turnover starts when the recoil ends")
	await _frames(20)
	var p := w.progress()
	_check(p.size() == 2 and String(p[0]) == "Turning" and float(p[1]) > 0.0 and float(p[1]) < 1.0, "progress during the turnover: %s" % [p])
	_check(w.status_text() == "Turning barrels" and w.wants_aim() and w.is_busy(), "turning: aim held up, busy")
	Input.action_release("fire")             # during the turnover: a queued release
	await _until(func() -> bool: return _events("fired", t0).size() >= 2, 300)
	var latch := _first("latch", t0)
	_near_ticks(int(latch.get("t", 0)) - ts, 0.467, "latch (barrels flip)")
	_check(int(latch.get("a", -1)) == 1, "barrel B came up")
	var shots := _events("fired", t0)
	if _check(shots.size() >= 2, "the queued release fired the second barrel"):
		var d2 := int(shots[1].t)
		_near_ticks(d2 - d1, 1.77, "discharge to discharge, snapped")
		_check(absf(float(shots[1].spread) - 1.26) <= 0.05, "second barrel cone %.3f deg (want 1.26 +- 0.05: the turnover bloom)" % float(shots[1].spread))
		_check(int(shots[1].barrel) == 1 and String(shots[1].muzzle) == "MuzzleB" and float(shots[1].origin_err) < 0.002,
				"barrel B fired from its own muzzle, at the Muzzle marker")
	var sfx := _events("sfx", ts).map(func(e: Dictionary) -> String: return String(e.a))
	_check(sfx.slice(0, 4) == ["half_cock", "catch", "latch", "full_cock"], "turnover sounds in order: %s" % [sfx.slice(0, 4)])
	await _frames(int(0.35 * HZ) + 4)
	_check(w.barrels_loaded() == [false, false], "both barrels fired")
	_check(w.status_text() == "Both barrels fired - press R", "status: %s" % w.status_text())


func _test_reload_both() -> void:
	# Continues from test 2: [○, ○] with B on top.
	if w.barrels_loaded() != [false, false]:
		await _load_state(0, 0, 10, 1)
	var top0 := w.barrels.top
	var r0 := w.reserve
	var t0 := tick
	await _tap("reload", 1)
	var t_top := -1
	var t_bottom := -1
	var t_both := -1
	var top_at_bottom := -1
	var saw_bottom_progress := false
	var lost_before_turn := false
	for i in int(18.5 * HZ):
		if t_top < 0 and w.loaded:
			t_top = tick
		if t_top >= 0 and t_bottom < 0 and w.barrels.is_charged(w.barrels.bottom()):
			t_bottom = tick
			top_at_bottom = w.barrels.top
		if w.state == Firearm.State.RELOADING and w.work_barrel == w.barrels.bottom() and not saw_bottom_progress:
			var p := w.progress()
			saw_bottom_progress = p.size() == 2 and String(p[0]) == "Bottom barrel"
		if t_top >= 0 and not w.loaded and not w.turning and _first("action", t0, "turnover").is_empty():
			lost_before_turn = true
		if w.barrels_loaded() == [true, true] and not w.turning:
			t_both = tick
			break
		await physics_frame
	var keys := _events("action", t0).map(func(e: Dictionary) -> String: return String(e.a))
	var want := ["reload_begin", "reload_mid", "reload_mid", "reload_end", "reload_mid",
			"reload_begin", "reload_mid", "reload_mid", "reload_end", "turnover", "reload_mid"]
	_check(keys == want, "action keys in order: %s" % [keys])
	_near_ticks(t_top - t0, 8.2, "top barrel ready")
	_check(not lost_before_turn, "the fresh top barrel stays ready (an emergency shot) while the bottom is charged")
	_near_ticks(t_bottom - t0, 14.8, "bottom charged in place")
	_check(top_at_bottom == top0, "the bottom was charged without turning")
	var turn := _first("action", t0, "turnover")
	_near_ticks(int(turn.get("t", 0)) + int(1.3 * HZ) - t0, 16.1, "turnover ends")
	_near_ticks(t_both - t0, 17.7, "both barrels ready")
	var begins := _events("action", t0).filter(func(e: Dictionary) -> bool: return e.a == "reload_begin")
	_check(w.reserve == r0 - 2 and begins.size() == 2 and int(begins[0].reserve) == r0 - 1 and int(begins[1].reserve) == r0 - 2,
			"one load taken at each barrel's step 0 (%d -> %d)" % [r0, w.reserve])
	_check(saw_bottom_progress, "progress shows \"Bottom barrel\" while it is charged in place")
	_check(w.state == Firearm.State.READY and not w.chain, "chain ends READY")


func _test_settled_second() -> void:
	await _load_state(5, 5)
	var t0 := tick
	await _shoot_settled()
	await _frames(10)
	Input.action_press("fire")               # during the recoil, held through the turnover
	await _until(func() -> bool: return not _first("action", t0, "turnover").is_empty(), 90)
	var ts := int(_first("action", t0, "turnover").t)
	await _until(func() -> bool: return tick >= ts + int(1.3 * HZ), 200)
	await _frames(1)
	_check(w.state == Firearm.State.AIMING and not w.turning, "LMB held through the turnover: shouldered, not fired")
	await _frames(int(0.4 * HZ) - 1)
	Input.action_release("fire")
	await _until(func() -> bool: return _events("fired", t0).size() >= 2, 60)
	var shots := _events("fired", t0)
	if _check(shots.size() >= 2, "second barrel fired on the release"):
		_check(float(shots[1].spread) <= 0.46, "settled second barrel cone %.3f deg (want <= 0.46)" % float(shots[1].spread))
	await _frames(50)


func _test_emergency_bottom() -> void:
	await _load_state(5, 0)
	var t0 := tick
	await _tap("reload", 1)
	_check(w.state == Firearm.State.RELOADING and w.work_barrel == w.barrels.bottom(), "R with [●, ○]: the bottom is charged in place")
	await _until(func() -> bool: return w.work_step == 2, int(4.0 * HZ))
	await _frames(12)
	var p := w.progress()
	_check(p.size() == 2 and String(p[0]) == "Bottom barrel", "progress: %s" % [p])
	_check(w.status_text() == "Bottom barrel: Ramming", "status: %s" % w.status_text())
	var t1 := tick
	Input.action_press("fire")
	await _frames(2)
	_check(not _first("cancel", t1).is_empty() and w.state == Firearm.State.AIMING, "LMB interrupts and shoulders at once")
	_check(_first("action", t1, "turnover").is_empty() and w.barrels.stage[w.barrels.bottom()] == 2, "no turnover; the bottom keeps step 2")
	await _until(func() -> bool: return w.aim >= 1.0, 120)
	Input.action_release("fire")
	await _until(func() -> bool: return not _first("fired", t1).is_empty(), 60)
	_check(int(_first("fired", t1).get("barrel", -1)) == w.barrels.top, "the release fires the top barrel")
	await _frames(int(0.35 * HZ) + 4)
	# Resume: with the top ready again, R resumes the bottom at its own step (Ramming).
	w.barrels.stage[w.barrels.top] = OverUnderBarrels.READY
	w.state = Firearm.State.READY
	w._mirror()
	await _frames(5)
	var t2 := tick
	var r0 := w.reserve
	await _tap("reload", 1)
	var a := _first("action", t2)
	_check(w.work_barrel == w.barrels.bottom() and a.get("a") == "reload_mid" and is_equal_approx(float(a.get("d", 0.0)), 2.2)
			and int(a.get("step", -1)) == 2 and w.reserve == r0, "R resumes the bottom at step 2 (Ramming), no new load")
	await _load_state(5, 5)


func _test_emergency_top() -> void:
	await _load_state(0, 5)
	await _tap("reload", 1)
	_check(w.work_barrel == w.barrels.top, "R with [○, ●]: charges the top in place")
	await _until(func() -> bool: return w.work_step == 2, int(4.0 * HZ))
	await _frames(12)
	var fired_barrel := w.barrels.top
	var t1 := tick
	Input.action_press("fire")
	await _frames(2)
	_check(not _first("cancel", t1).is_empty() and w.turning and not _first("action", t1, "turnover").is_empty(),
			"LMB interrupts and turns over")
	await _until(func() -> bool: return not _first("latch", t1).is_empty(), 90)
	_check(w.barrels.top != fired_barrel and w.loaded and w.barrels.stage[fired_barrel] == 2,
			"the loaded barrel came up; the fired one keeps step 2 underneath")
	Input.action_release("fire")
	await _until(func() -> bool: return not _first("fired", t1).is_empty(), 200)
	_check(not _first("fired", t1).is_empty(), "the emergency shot fires after the turnover")
	await _frames(50)


func _test_cancel_finish() -> void:
	await _load_state(0, 5)
	var top0 := w.barrels.top
	var t1 := tick
	await _tap("fire", 1)
	_check(w.turning, "LMB with [○, ●] turns over")
	await _frames(2)                           # about 0.03 s into the clip: before the commit
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(2)
	_check(not w.turning and w.barrels.top == top0 and not _first("cancel", t1).is_empty(), "sprint before the commit cancels: no flip")
	_check(absf(w.rig.barrels_angle - top0 * PI) < 1e-4, "barrels back at rest")
	_release_all()
	await _frames(90)
	var t2 := tick
	await _tap("fire", 1)
	var ts := int(_first("action", t2, "turnover").get("t", tick))
	await _until(func() -> bool: return tick >= ts + int(0.2 * HZ), 60)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var t3 := tick
	await _until(func() -> bool: return not w.turning, 60)
	var latch := _first("latch", t2)
	_check(not latch.is_empty() and int(latch.t) - t3 <= int(0.2 * HZ) + TOL, "sprint after the commit: latched within 0.2 s (%d ticks)" % (int(latch.get("t", 0)) - t3))
	_check(w.barrels.top == 1 - top0 and w.loaded, "the loaded barrel is up")
	var ang := rad_to_deg(w.rig.barrels_node.transform.basis.get_euler().z)
	_check(absf(absf(ang) - 180.0) <= 1.0, "Barrels node turned 180 deg (%.1f)" % ang)
	var mk := w.rig.muzzle_of(w.barrels.top)
	_check(mk.global_position.distance_to(w.muzzle.global_position) < 0.001, "the physical top muzzle is at the Muzzle marker")
	_release_all()
	await _frames(90)


func _test_chain_cancel() -> void:
	await _load_state(5, 4)
	var t1 := tick
	await _tap("reload", 1)
	_check(w.turning and w.turn_why == OverUnderMusket.Why.CHAIN, "R with [●, ◑]: the chain turns over to prime")
	Input.action_press("fire")                 # before the commit (0.067 s)
	await _frames(2)
	_check(not w.turning and not w.chain and w.state == Firearm.State.AIMING and w.barrels.top == 0,
			"LMB before the commit: turnover cancelled, chain ended, ready barrel shouldered")
	await _tap("aim")
	Input.action_release("fire")
	await _frames(20)
	_check(w.state == Firearm.State.READY and w.loaded and _first("fired", t1).is_empty(), "lowered without firing")


func _test_out_of_loads() -> void:
	await _load_state(0, 0, 0)
	var t1 := tick
	await _tap("fire", 1)
	_check(not _first("sfx", t1, "dry").is_empty() and w.state == Firearm.State.EMPTY, "[○, ○], no loads: LMB clicks dry")
	await _tap("reload", 1)
	await _frames(5)
	_check(w.state == Firearm.State.EMPTY and _first("action", t1).is_empty(), "R does nothing")
	_check(w.status_text() == "Out of loads", "status: %s" % w.status_text())
	await _load_state(4, 0, 0)
	var t2 := tick
	await _tap("reload", 1)
	var a := _first("action", t2)
	_check(a.get("a") == "reload_mid" and int(a.get("step", -1)) == 4, "charged, unprimed top with no loads: R primes it")
	await _until(func() -> bool: return w.loaded, int(2.0 * HZ))
	_near_ticks(tick - t2, 1.6, "priming")
	await _load_state(5, 5)


func _test_crouched() -> void:
	await _load_state(0, 5)
	await _tap("crouch", 1)
	await _frames(20)
	_check(player.is_crouching, "crouched")
	var t1 := tick
	await _tap("fire", 1)
	var ts := int(_first("action", t1, "turnover").get("t", tick))
	await _until(func() -> bool: return not _first("latch", t1).is_empty(), 90)
	_check(w.turn_crouched, "crouched turnover (the crouch pump row)")
	_near_ticks(int(_first("latch", t1).get("t", 0)) - ts, 0.433, "crouched latch")
	var commit := _first("sfx", t1, "catch")
	_near_ticks(int(commit.get("t", 0)) - ts, 0.033, "crouched commit (catch)")
	await _until(func() -> bool: return not _first("fired", t1).is_empty(), 200)
	await _frames(60)
	await _tap("crouch", 1)
	await _frames(30)


func _test_handling() -> void:
	await _load_state(5, 5)
	Input.action_press("aim")
	var t0 := tick
	await _until(func() -> bool: return w.aim >= 1.0, 120)
	var sm := w.speed_mult()
	_check(is_equal_approx(snappedf(sm, 1e-4), snappedf(0.88 * 0.45 * 0.9, 1e-4)), "braced at full aim: speed_mult %.4f = 0.88 x 0.45 x 0.9" % sm)
	await _until(func() -> bool: return tick >= t0 + int(2.4 * HZ), 400)
	_check(w._extra_spread() == 0.0, "hold fatigue: nothing before 2.5 s")
	await _until(func() -> bool: return tick >= t0 + int(7.05 * HZ), 700)
	_check(absf(w._extra_spread() - 0.3) < 1e-3, "hold fatigue: +0.3 deg at 7 s (%.3f)" % w._extra_spread())
	_check(w.tremble_offset().length() > 0.0, "the heavy muzzle wanders (tremble_offset)")
	var full := w._extra_spread()
	Input.action_release("aim")
	await _frames(int(1.2 * HZ))
	_check(w._extra_spread() < full - 0.05, "decays after lowering (%.3f)" % w._extra_spread())
	await _frames(int(3.0 * HZ))


## The user's cycle end to end, each shot checked against its own physical barrel's muzzle:
## fire the top (A), turn over, fire the bottom (B), empty, R reloads one barrel (B, on top) in
## 8.2 s, fire it while the chain is charging A underneath (A keeps its finished step), then R
## reloads both: B on top (8.2 s), A resumed in place (5.3 s), turn (1.3 s), prime A (1.6 s).
func _test_full_cycle() -> void:
	await _load_state(5, 5)
	var r0 := w.reserve
	var t0 := tick
	await _shoot_settled()
	var s1 := _first("fired", t0)
	_check(int(s1.get("barrel", -1)) == 0 and String(s1.get("muzzle", "")) == "MuzzleA" and float(s1.get("origin_err", 1.0)) < 0.002,
			"shot 1: barrel A, from its own muzzle at the Muzzle marker")
	await _frames(int(0.35 * HZ) + 4)
	var t1 := tick
	await _tap("fire", 2)
	_check(w.turning and not _first("action", t1, "turnover").is_empty(), "LMB with [○, ●]: the barrels turn over")
	await _until(func() -> bool: return not _first("fired", t1).is_empty(), int(2.0 * HZ))
	var s2 := _first("fired", t1)
	_check(int(s2.get("barrel", -1)) == 1 and String(s2.get("muzzle", "")) == "MuzzleB" and float(s2.get("origin_err", 1.0)) < 0.002,
			"shot 2: barrel B turned up, from its own muzzle at the Muzzle marker")
	await _frames(int(0.35 * HZ) + 4)
	_check(w.barrels_loaded() == [false, false] and w.state == Firearm.State.EMPTY and w.ammo_text().begins_with("▲○ ▼○"),
			"empty: %s, %s" % [w.ammo_text(), w.status_text()])
	# Reload one barrel.
	var t2 := tick
	await _tap("reload", 1)
	await _until(func() -> bool: return w.loaded, int(9.0 * HZ))
	_near_ticks(tick - t2, 8.2, "one barrel reloaded (B, on top)")
	var b_begin := _first("action", t2, "reload_begin")
	_check(w.barrels.top == 1 and w.barrels_loaded() == [true, false] and int(b_begin.get("barrel", -1)) == 1
			and int(b_begin.get("reserve", -1)) == r0 - 1, "B ready on top, one load used for it")
	await _until(func() -> bool: return w.work_barrel == w.barrels.bottom() and w.work_step == 1, int(2.0 * HZ))
	_check(w.state == Firearm.State.RELOADING and w.work_barrel == 0 and w.reserve == r0 - 2,
			"the chain charges A underneath (its load taken at step 0)")
	await _frames(6)
	# Fire it: LMB drops the work below (A keeps its finished step) and shoulders at once.
	var t3 := tick
	await _shoot_settled()
	var s3 := _first("fired", t3)
	_check(int(s3.get("barrel", -1)) == 1 and String(s3.get("muzzle", "")) == "MuzzleB" and float(s3.get("origin_err", 1.0)) < 0.002
			and _first("action", t3, "turnover").is_empty(), "shot 3: the reloaded barrel B, no turnover")
	await _frames(int(0.35 * HZ) + 4)
	_check(w.barrels.stage[0] == 1 and w.ammo_text().begins_with("▲○ ▼◐"), "A kept its step underneath: %s" % w.ammo_text())
	# Reload both.
	var t4 := tick
	await _tap("reload", 1)
	var t_top := -1
	var t_both := -1
	for i in int(17.5 * HZ):
		if t_top < 0 and w.loaded:
			t_top = tick
		if w.barrels_loaded() == [true, true] and not w.turning:
			t_both = tick
			break
		await physics_frame
	var keys := _events("action", t4).map(func(e: Dictionary) -> String: return String(e.a))
	var want := ["reload_begin", "reload_mid", "reload_mid", "reload_end", "reload_mid",
			"reload_mid", "reload_mid", "reload_end", "turnover", "reload_mid"]
	_check(keys == want, "reload both, action keys: %s" % [keys])
	_near_ticks(t_top - t4, 8.2, "reload both: B on top first")
	_near_ticks(t_both - t4, 8.2 + 5.3 + 1.3 + 1.6, "reload both: A resumed in place, turned, primed")
	_check(w.reserve == r0 - 3 and w.barrels.top == 0 and w.state == Firearm.State.READY and not w.chain,
			"both ready, A on top, 3 loads for 3 charges (%d -> %d)" % [r0, w.reserve])
	var mk := w.rig.muzzle_of(w.barrels.top)
	_check(mk.global_position.distance_to(w.muzzle.global_position) < 0.001
			and w.rig.muzzle_of(1).global_position.distance_to((w.model.get_node("Muzzle_bottom") as Node3D).global_position) < 0.001,
			"muzzles after the cycle: A at Muzzle_top, B at Muzzle_bottom")
	await _frames(30)


func _test_routing() -> void:
	var alias: Variant = (player.anim.get_script() as Script).get_script_constant_map().get("GRAPH_ALIAS") if player.anim else null
	var anim_ready := player.anim != null and player.anim.is_ready()
	if not anim_ready:
		pending.append("PlayerAnim not ready: animation routing not checked")
	elif alias is Dictionary:
		var up: Object = player.anim.upper
		var row: Dictionary = up.resolve_action("musket", "stand", "turnover")
		var row_c: Dictionary = up.resolve_action("musket", "crouch", "turnover")
		_check(String(row.get("partial", "")) == "actor_b-p-shotgun-idle-aim-reload-pump--part", "H6/H7: stand turnover plays the shotgun pump clip")
		_check(String(row_c.get("partial", "")) == "actor_b-p-shotgun-idle-crouch-aim-reload-pump--part", "H6/H7: crouch turnover plays the crouch pump clip")
	else:
		pending.append("H6/H7 (PlayerAnim alias + pinned musket/<stance>/turnover rows) not in: dev bridge checked instead")
		_check(OverUnderKit.anim_needs_alias(player) and String(player.anim.get("_weapon")) == "musket",
				"dev bridge: PlayerAnim plays the musket's rows for the over-under")
	if anim_ready:
		# The events themselves must carry a key the graph has rows for: PlayerAnim.setup binds
		# the roster key "over_under" when hook H4 installs the gun before it (and H6 is not in).
		var gk := OverUnderKit.graph_key(player)
		var bad := _anim_binds_other_than(gk)
		_check(bad.is_empty(), "fired / action_started / action_cancelled reach PlayerAnim bound to '%s' %s" % [gk, bad])
	var wa := player.get_node_or_null("WeaponAudio")
	if wa == null:
		pending.append("no WeaponAudio in the level: audio routing not checked")
	else:
		var key: String = (wa.get("_key_of") as Dictionary).get(w, "")
		_check(key == "musket", "WeaponAudio voices the over-under with the musket's sounds (key %s)" % key)
		if not "reload_cues" in (wa.get_script() as Script).source_code:
			pending.append("H9 (WeaponAudio reads reload_cues, four sfx arms) not in: the reload uses the musket's cue list")
	# Hook H4 ahead of H6 / H9: PlayerAnim.setup and WeaponAudio._ready then connect the gun under
	# "over_under" (no graph rows, no sounds). Recreate that and check the kit re-binds it.
	if anim_ready and alias == null and wa != null:
		for pair: Array in [[w.fired, "_on_fired"], [w.action_started, "_on_action"],
				[w.action_cancelled, "_on_action_cancelled"]]:
			var sig: Signal = pair[0]
			for c: Dictionary in sig.get_connections():
				if (c.callable as Callable).get_object() == player.anim and (c.callable as Callable).get_method() == pair[1]:
					sig.disconnect(c.callable)
			sig.connect(Callable(player.anim, pair[1]).bind("over_under"))
		(wa.get("_key_of") as Dictionary)[w] = "over_under"
		OverUnderKit.ensure_routing(player, w)
		var bad2 := _anim_binds_other_than("musket")
		_check(bad2.is_empty() and String((wa.get("_key_of") as Dictionary).get(w, "")) == "musket",
				"H4 before H6/H9 (setup bound 'over_under'): ensure_routing re-binds PlayerAnim and WeaponAudio to the musket %s" % bad2)
		var n := 0
		for sig: Signal in [w.fired, w.action_started, w.action_cancelled]:
			for c: Dictionary in sig.get_connections():
				if (c.callable as Callable).get_object() == player.anim:
					n += 1
		_check(n == 3, "one PlayerAnim connection per signal after re-binding (%d)" % n)


## Review finding: a sprint tap after the commit latched the barrels within 0.2 s and ended the
## action, so the second shot came 0.98 s after the first (honest 1.77 s), without the turnover
## bloom and from half cock. Now the rest of the turnover is owed and LMB plays it first.
func _test_cut_half_cock() -> void:
	for how: String in ["sprint", "switch"]:
		await _load_state(5, 5)
		var t0 := await _shoot_settled()
		_check(t0 > 0, "%s: first shot" % how)
		Input.action_press("fire")
		await _frames(1)
		Input.action_release("fire")
		await _until(func() -> bool: return w.turning, 90)
		await _until(func() -> bool: return w.turn_clock >= 0.1, 30)
		if how == "sprint":
			Input.action_press("move_forward")
			Input.action_press("sprint")
			await _until(func() -> bool: return not w.turning, 60)
			Input.action_release("sprint")
			Input.action_release("move_forward")
		else:
			player.switch_weapon("pistol")
			await _frames(1)
			player.switch_weapon(OverUnderKit.KEY)
			await _until(func() -> bool: return player.weapon == w and not player.is_switching() and not w.is_equipping(), 900)
		var owed := w.turnover_s() - w._owed_clock
		_check(w.half_cocked and w.loaded and w.barrels.top == 1, "%s after the latch: loaded barrel up, at half cock (%.2f s of the turnover owed)" % [how, owed])
		await _frames(2)
		_check(absf(w.rig.cock_angle - OverUnderRig.COCK_HALF) < 1e-3, "%s: the cock stays at half cock" % how)
		_check(w.status_text().begins_with("Half cock"), "%s: status '%s'" % [how, w.status_text()])
		var t1 := tick
		await _tap("fire", 1)
		_check(w.turning and not _first("action", t1, "turnover").is_empty(), "%s: LMB plays the owed rest of the turnover" % how)
		await _until(func() -> bool: return not _first("fired", t1).is_empty(), 360)
		var f := _first("fired", t1)
		var dt_s := (int(f.get("t", tick)) - t0) / HZ
		var from_lmb := (int(f.get("t", tick)) - t1) / HZ
		_check(not f.is_empty() and from_lmb >= owed + w.hang_fire - 2.0 / HZ,
				"%s: the shot waits for the owed %.2f s + hang-fire (%.3f s after LMB; %.3f s after the first shot, honest snapped 1.77 s)" % [how, owed, from_lmb, dt_s])
		_check(not f.is_empty() and float(f.spread) >= w.turnover_bloom_deg * 0.5,
				"%s: the turnover bloom applies (cone %.2f deg)" % [how, float(f.get("spread", 0.0))])
		_check(not w.half_cocked and not _first("sfx", t1, "full_cock").is_empty(), "%s: full cock heard, half cock cleared" % how)
	# A Priming step clears it too (it cocks), and a fresh turnover does not owe anything.
	await _load_state(4, 5)
	w.half_cocked = true
	var t2 := tick
	await _tap("reload", 1)
	await _until(func() -> bool: return w.state == Firearm.State.READY and not w.chain, int(3.0 * HZ))
	_check(not w.half_cocked and w.loaded, "a Priming step ends at full cock: half cock cleared")
	_release_all()
	await _frames(30)


## PlayerAnim connections of the over-under's three action signals bound to anything but `key`.
func _anim_binds_other_than(key: String) -> PackedStringArray:
	var bad := PackedStringArray()
	for pair: Array in [[w.fired, "_on_fired"], [w.action_started, "_on_action"],
			[w.action_cancelled, "_on_action_cancelled"]]:
		var b: Variant = OverUnderKit.bound_key(pair[0], player.anim, pair[1])
		if not (b is String and b == key):
			bad.append("%s=%s" % [pair[1], b])
	return bad


func _test_ballistics() -> void:
	# Real Projectiles at a 0.5 m disc 50 m away, far above the level: hit rate and damage.
	var n := 200
	var origin := Vector3(0, 400, 0)
	var target := origin + Vector3(0, 0, -50)
	var disc := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.25
	cyl.height = 0.05
	cs.shape = cyl
	cs.rotation.x = PI / 2
	disc.add_child(cs)
	var s := GDScript.new()
	s.source_code = "extends StaticBody3D\nvar dmg: Array = []\nfunc apply_hit(d, _p, _dir, _src, _part):\n\tdmg.append(d)\n"
	s.reload()
	disc.set_script(s)
	current_scene.add_child(disc)
	disc.global_position = target
	await _frames(2)
	var cone := deg_to_rad(w.spread_base)
	for i in n:
		var dir := Weapon.apply_spread(Weapon.ballistic_dir(origin, target, w.muzzle_speed, w.ball_gravity, w.ball_drag), cone)
		var p := Projectile.new()
		p.kind = Projectile.Kind.BALL
		p.velocity = dir * w.muzzle_speed
		p.gravity = w.ball_gravity
		p.drag = w.ball_drag
		p.damage = w.damage
		current_scene.add_child(p)
		p.global_position = origin
		if i % 20 == 19:
			await _frames(1)
	await _frames(40)
	var dmg: Array = disc.get("dmg")
	var ph := float(dmg.size()) / n
	var want := 0.69
	var tol := 3.0 * sqrt(want * (1.0 - want) / n) + 0.02
	_check(absf(ph - want) <= tol, "50 m torso disc, settled cone %.2f deg: hit rate %.2f (want %.2f +- %.2f)" % [w.spread_base, ph, want, tol])
	var ok := not dmg.is_empty()
	for d in dmg:
		ok = ok and absf(float(d) - 101.0) <= 1.0
	_check(ok, "damage at 50 m = 110 x speed falloff = 101 (got %s)" % (str(dmg[0]) if not dmg.is_empty() else "none"))
	disc.queue_free()
