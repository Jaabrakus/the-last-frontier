extends SceneTree
## Round 4 VIRAL: the Splash Cam (RingReplay, data/ring/replay.json) in the % ring (rules stock; earth against a water bot,
## held), headless:
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_ring_replay.gd -- mode=ring element=earth foe=water
##   records      the buffer fills each tick for both competitors; its bytes are fixed after the warm-up (the same 8 s on)
##   a fall       the foe launched off the deck by the player (a scripted launch): the fall queues a replay (RingReplay.force
##                "on": a script run asks for it), it starts after its wait and pauses the tree, hides the live bodies and
##                the screens' layers, makes the replay camera current; its ghosts at sampled ticks stand where the live
##                skeletons stood at those ticks (their transforms, a hand bone's place, and every bone's place, the body's
##                driven twist helpers too: within 1 cm)
##   resumes      when it ends, every competitor's transform, %, lives, and the player's lock (state, fill, lock time) and
##                camera (current, transform) are exactly as when it started; the tree goes on
##   skip         a second fall's replay ends at a key press (after the grace)
##   off          with the setting "off" a third fall plays none
##   the gate     with no stock rules (the classic ring) nothing is recorded
## METRIC replay_resume_exact, replay_buffer_bytes. Watchdog LIMIT_S; last line "RING REPLAY PASSED" or "RING REPLAY FAILED".

const NAME := "RING REPLAY"
const LIMIT_S := 380.0
const OWN_CFG := "user://ring_replay_test.cfg"

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var ring: RingArena
var player: FrontierPlayer
var mode: RingMode
var rules: RingRules
var rp: RingReplay
var kos: Array = []
var metrics := {}
## Live poses by absolute tick: {foe: {xf, hand}, player: {...}}.
var live := {}
var _hand := -1
var _logging := false


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	MatchSetup._aim_help = "strong"
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	RingRules.rule_set_override = "stock"
	SwayCaster.free_override = true
	InputSetup.ensure()
	MatchSetup.incoming = true
	MatchSetup.element = "earth"
	MatchSetup.foes = ["water"]
	RingReplay.force = "on"
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit:
		if cond.call():
			return t
		await process_frame
		t += 1.0 / 60.0
	return INF


func _end() -> void:
	for k: String in metrics:
		print("METRIC %s=%s" % [k, str(metrics[k])])
	RingRules.rule_set_override = ""
	RingReplay.force = ""
	GameSettings.path = GameSettings.PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


func foe() -> NpcFighter:
	return mode.foe if mode != null and is_instance_valid(mode.foe) else null


func _scene() -> bool:
	for i in 10:
		await process_frame
	lvl = current_scene as RingLevel
	if lvl == null:
		return false
	ring = lvl.ring
	player = lvl.player
	player.ignore_mouse_capture = true
	mode = RingMode.find(self)
	if mode == null:
		return false
	rules = mode.rules
	await _until(func() -> bool: return mode.phase == "COUNTDOWN" and foe() != null, 6.0)
	mode.phase_t = RingRules.num("countdown_s", 3.0) - 0.02
	await _until(func() -> bool: return mode.phase == "FIGHT", 2.0)
	foe().held = true
	return true


func _run() -> void:
	var ok := await _scene()
	_expect(ok and RingRules.stock_on(), "the stock ring under way")
	if not ok:
		return _end()
	rp = RingReplay.install(mode)
	_expect(rp != null and RingReplay.find(self) == rp and RingHighlights.find(self) != null and Callouts.find(self) != null
			and PhotoMode.find(self) != null and BendClash.find(self) != null, "install: the Splash Cam and the round's other parts under the mode")
	rules.ko.connect(func(b: Node3D, _by: Node, _p: float, _t: String, _l: int) -> void: kos.append(b))
	await _record_checks()
	await _fall_and_replay()
	await _skip_check()
	await _off_check()
	await _gate_check()
	_end()


## The foe at deck place x (from end 1's middle), still, in play.
func _place_foe(x: float, pct := 0.0) -> void:
	var f := foe()
	mode._respawns.clear()
	mode._hide(f, false)
	var st := rules._sk(f)
	st["away"] = false
	st["gone"] = false
	st["stocks"] = 3
	st["safe_until"] = -INF
	var kn := BendKnock.peek(f)
	if kn != null:
		kn.reset()
	f.velocity = Vector3.ZERO
	f.global_position = ring.to_global(Vector3(x, ring.top() + 0.05, 0.0))
	await _ticks(3)
	rules.reset_pct(f, pct)


func _record_checks() -> void:
	await _ticks(90)
	_expect(rp.slot_index(player) >= 0 and rp.slot_index(foe()) >= 0, "both competitors have a slot in the buffer")
	var b1 := rp.bytes()
	await _ticks(int(RingReplay.num("buffer_s", 8.0) * 60.0) + 60)
	var b2 := rp.bytes()
	metrics["replay_buffer_bytes"] = b2
	_expect(b1 == b2 and b2 > 0, "the buffer's bytes are fixed after the warm-up (%d, then %d after the buffer's length on)" % [b1, b2])
	var t := rp.newest_tick()
	var s := rp.buffer_at(foe(), t)
	var sk := RingReplay._skeleton_of(foe())
	_expect(not s.is_empty() and (s.xf as Transform3D).origin.distance_to(sk.global_transform.origin) < 0.01,
			"the newest tick holds the foe's skeleton where it stands")
	var held_ok := true
	for si in rp._slots.size():
		var sl := rp._slots[si] as RingReplay.Slot
		var good := 0
		for i in sl.ptick.size():
			if sl.ptick[i] >= 0:
				good += 1
		print("  slot %d: %s, %d bones (%d with places), %d pose samples of %d" % [si, sl.sk.get_path(), sl.bones, sl.pos_idx.size(), good, sl.pcap])
		held_ok = held_ok and good >= sl.pcap / 2
	_expect(held_ok, "every competitor's pose ring holds most of the buffer's length (a pose every %d ticks at %d Hz, as frames are drawn)" % [rp._pose_every, rp.tps])


## The live skeletons' transforms and a hand bone's place logged by tick (the test's own reading: the skeleton's update).
func _log_live() -> void:
	var fs := RingReplay._skeleton_of(foe())
	_hand = fs.find_bone("mixamorig_RightHand")
	if _hand < 0:
		_hand = fs.find_bone("RightHand")
	if _hand < 0:
		_hand = mini(fs.get_bone_count() - 1, 40)
	var ps := RingReplay._skeleton_of(player)
	for pair: Array in [["foe", fs], ["player", ps]]:
		var key: String = pair[0]
		var sk: Skeleton3D = pair[1]
		# (as the skeleton finishes its update (as drawn): its place, the hand in its own space; the newest tick's)
		sk.skeleton_updated.connect(func() -> void:
			if not _logging or Engine.is_in_physics_frame():
				return
			var t := rp.newest_tick()
			var rec := live.get(t, {}) as Dictionary
			var r := rec.get(key, {}) as Dictionary
			if not r.has("hand"):
				r["hand"] = sk.get_bone_global_pose(_hand).origin
				var all := PackedVector3Array()
				all.resize(sk.get_bone_count())
				for b in sk.get_bone_count():
					all[b] = sk.get_bone_global_pose(b).origin
				r["bones"] = all                     # (every bone, the body's driven twist helpers too)
			r["xf"] = sk.global_transform
			rec[key] = r
			live[t] = rec)


func _fall_and_replay() -> void:
	_log_live()
	_logging = true
	await _ticks(int(RingReplay.num("replay_s", 3.5) * Engine.physics_ticks_per_second) + 30)
	await _place_foe(ring.half_l() - 2.5, 120.0)
	player.global_position = ring.to_global(Vector3(ring.half_l() - 7.0, ring.top() + 0.05, 1.0))
	await _ticks(20)
	kos.clear()
	var kn := BendKnock.of(foe())
	rules.launched.emit(foe(), ring.global_basis * Vector3(16.0, 7.0, 0.0), 0.8, player, "stone_form/spike")
	kn.knock(Vector3.ZERO, player, {"_launch": {"v": ring.global_basis * Vector3(16.0, 7.0, 0.0), "hitstun_s": 0.8, "tumble": true}})
	await _until(func() -> bool: return not kos.is_empty(), 6.0)
	_expect(not kos.is_empty() and rp.pending() == 1, "the scripted fall: in the water, a replay queued")
	# (the player begins a lock while the replay waits: it must be held exactly through the replay)
	Input.action_press(&"aim")
	var state := {}
	rp.started.connect(func(_c: RingReplay.Clip) -> void: state["start"] = _state(), CONNECT_ONE_SHOT)
	rp.finished.connect(func(skipped: bool) -> void:
		state["end"] = _state()
		state["skipped"] = skipped, CONNECT_ONE_SHOT)
	var waited := await _until(func() -> bool: return rp.is_playing(), 6.0)
	_logging = false
	_expect(rp.is_playing() and waited >= RingReplay.num("wait_s", 0.6) - 0.05,
			"the replay starts after its wait (%.2f s; wait_s %.2f, no RingMoment)" % [waited, RingReplay.num("wait_s", 0.6)])
	_expect(paused and get_root().get_viewport().get_camera_3d() == rp.camera() and not foe().visible and not player.visible
			and player.hud != null and not player.hud.visible, "it holds the tree, its own camera is current, the live bodies and the HUD hidden")
	var c := rp.clip()
	_expect(c != null and c.faller == rp.slot_index(foe()) and c.thrower == rp.slot_index(player) and c.hit_t >= 0
			and c.n >= int(RingReplay.num("replay_s", 3.5) * 60.0), "its clip: the foe's fall sent by the player, %d ticks, the hit at %d" % [c.n if c != null else 0, c.hit_t if c != null else -1])
	_expect(absf(rp.rate_at(float(c.hit_t)) - RingReplay.sub("slow", "rate", 0.4)) < 1e-4 and is_equal_approx(rp.rate_at(0.0), 1.0),
			"slowed to %.2f at the decisive hit, full speed away from it" % RingReplay.sub("slow", "rate", 0.4))
	# ghosts at sampled ticks against the live log
	var worst := 0.0
	var worst_hand := 0.0
	var worst_bone := 0.0
	var worst_name := ""
	var n := 0
	var fi := c.faller
	var pi := rp.slot_index(player)
	rp.held = true
	var pts := (c.bodies[fi] as Dictionary).pticks as PackedInt32Array
	var picks: Array = []
	for k in pts:
		# (k >= 0: the sample just before the clip's first tick is in it, but a seek there is held at 0)
		if k >= 0 and live.has(c.t0 + k) and k <= c.splash_t and ((live[c.t0 + k] as Dictionary).get("foe", {}) as Dictionary).has("hand"):
			picks.append(k)
	var step := maxi(picks.size() / 10, 1)
	for ii in range(0, picks.size(), step):
		var t: int = picks[ii]
		var abs_t := c.t0 + t
		rp.seek(float(t))
		await process_frame
		for pair: Array in [["foe", fi], ["player", pi]]:
			var rec := (live[abs_t] as Dictionary).get(pair[0], {}) as Dictionary
			var g := rp.ghost(int(pair[1]))
			if not rec.has("xf") or not rec.has("hand") or g == null:
				continue
			var gsk := g.get_child(0) as Skeleton3D
			worst = maxf(worst, g.global_transform.origin.distance_to((rec.xf as Transform3D).origin))
			worst_hand = maxf(worst_hand, gsk.get_bone_global_pose(_hand).origin.distance_to(rec.hand as Vector3))
			var all := rec.get("bones", PackedVector3Array()) as PackedVector3Array
			for b in mini(all.size(), gsk.get_bone_count()):
				var e := gsk.get_bone_global_pose(b).origin.distance_to(all[b])
				if e > worst_bone:
					worst_bone = e
					worst_name = gsk.get_bone_name(b)
			n += 1
	_expect(n >= 8 and worst <= 0.01 and worst_hand <= 0.01,
			"the ghosts stand where the live skeletons stood at %d sampled ticks: worst %.4f m (the skeleton's place), %.4f m (a hand bone in the skeleton)" % [n, worst, worst_hand])
	# (2026-10-11, the owner: "the replay element it shoulds body parts like rubberbands": the body's twist helpers, driven to
	# new places every frame several bones deep, were replayed at their rest places, up to 0.87 m off: every bone's place now)
	_expect(n >= 8 and worst_bone <= 0.01,
			"...every bone of them too, the body's driven twist helpers with them: worst %.4f m (%s)" % [worst_bone, worst_name])
	rp.seek(0.0)
	rp.held = false
	await _until(func() -> bool: return not rp.is_playing(), 12.0)
	Input.action_release(&"aim")
	var same := state.has("start") and state.has("end") and _same(state.start, state.end)
	metrics["replay_resume_exact"] = same
	_expect(same and not bool(state.get("skipped", true)), "it plays to its end; then every competitor's transform, %, lives, the lock and the camera are exactly as at its start")
	_expect(not paused and get_root().get_viewport().get_camera_3d() == player.camera and player.visible and player.hud.visible,
			"the tree goes on, the player's camera current, the bodies and the HUD shown")


func _state() -> Dictionary:
	var sc := SwayCaster.of(player)
	var cam := get_root().get_viewport().get_camera_3d()
	return {"p_xf": player.global_transform, "f_xf": foe().global_transform, "p_pct": rules.pct_of(player), "f_pct": rules.pct_of(foe()),
			"p_lives": rules.stocks_of(player), "f_lives": rules.stocks_of(foe()), "lock": [int(sc.state), sc.fill, sc.lock_s, sc.hold_t],
			"cam": player.camera.global_transform, "cam_cur": cam if cam != rp.camera() else player.camera,
			"p_v": player.velocity, "f_v": foe().velocity}


func _same(a: Dictionary, b: Dictionary) -> bool:
	for k in a:
		if a[k] != b[k]:
			print("    differs: %s %s -> %s" % [k, str(a[k]), str(b[k])])
			return false
	return true


func _skip_check() -> void:
	await _place_foe(ring.half_l() - 2.5, 120.0)
	await _ticks(10)
	kos.clear()
	BendKnock.of(foe()).knock(Vector3.ZERO, player, {"_launch": {"v": ring.global_basis * Vector3(16.0, 7.0, 0.0), "hitstun_s": 0.8, "tumble": true}})
	await _until(func() -> bool: return rp.is_playing(), 8.0)
	var skipped := [false]
	rp.finished.connect(func(s: bool) -> void: skipped[0] = s, CONNECT_ONE_SHOT)
	await _ticks(1)
	for i in 30:
		await process_frame
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SPACE
	ev.keycode = KEY_SPACE
	ev.pressed = true
	Input.parse_input_event(ev)
	var t := await _until(func() -> bool: return not rp.is_playing(), 3.0)
	var up := InputEventKey.new()
	up.physical_keycode = KEY_SPACE
	up.keycode = KEY_SPACE
	up.pressed = false
	Input.parse_input_event(up)
	_expect(t < 0.5 and bool(skipped[0]) and not paused, "a key skips the replay (it ended %.2f s after the press)" % t)


func _off_check() -> void:
	RingReplay.set_setting("off")
	_expect(RingReplay.setting() == "off" and RingReplay.row_text().contains(RingReplay.word("row", "off")), "the Esc row reads Off")
	var started := rp.replays_started
	await _place_foe(ring.half_l() - 2.5, 120.0)
	await _ticks(10)
	kos.clear()
	BendKnock.of(foe()).knock(Vector3.ZERO, player, {"_launch": {"v": ring.global_basis * Vector3(16.0, 7.0, 0.0), "hitstun_s": 0.8, "tumble": true}})
	await _until(func() -> bool: return not kos.is_empty(), 6.0)
	await _until(func() -> bool: return rp.is_playing(), 2.0)
	_expect(not kos.is_empty() and rp.replays_started == started and rp.pending() == 0, "with Replays: Off a fall plays none")
	RingReplay.set_setting("every")


func _gate_check() -> void:
	RingRules.rule_set_override = "classic"
	change_scene_to_file("res://scenes/ring.tscn")
	await process_frame
	var ok := await _scene()
	if not ok:
		_expect(false, "the classic ring")
		return
	rp = RingReplay.install(mode)
	await _ticks(60)
	_expect(not RingRules.stock_on() and rp.newest_tick() < 0 and rp.bytes() == RingReplay.num("max_props", 24.0) * rp.cap * 48 + rp._ev_k.size() * 44,
			"the classic ring (the gate off): nothing recorded")
