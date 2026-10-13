extends SceneTree
## Round 3's HUD in the % ring (smash_r3 spec v2 §10, §15 PERCENT; PercentBar, BendStrip, MatchScreen, data/ring/hud.json), the
## ring scene with a stock-rules match (RingRules.rule_set_override "stock"; earth against a water bot, held), the window at
## 1280x720 then 1920x1080:
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_percent_hud.gd -- mode=ring element=earth foe=water
##   the plates  the PercentBar shown in place of the MatchBar; a plate a side; layout A at the top corners (yours at (24, 16)
##               x the scale, 270 x 84, theirs mirrored), B at the bottom corners, at 1280x720 and 1920x1080
##   a hit       a 12% hit: the digits move within a frame and read 12 by the roll's end (0.15 s); the pop and the shake over
##               by 0.35 s
##   the ramp    0/40/80/120/180% give the table's colours; 60% an OKLab blend between gold and orange; throbbing over 200
##   a fall      a white flash at 0.1 s, the digits risen and gone by 0.35 s, a life glyph dropping by 0.5 s (the row one
##               shorter after), "0" at 1.0 s; the last life's glyph flagged to pulse
##   yours only  the pips (jump, dodge, Rise) and the fresh band on your plate, never on theirs; the clock top centre
##   no cues     a bot moved 10 m in 1 s with no hits moves, shows or hides no CanvasItem; percent_bar.gd reads no position
##   the flags   hud.json launch_wake and respawn_drip both false by default
##   the strip   in the air: key 2 the Slam (Hammer), key 3 "Dodge", keys 4 and 5 grey with "lands", key 3 never lit; the
##               move names a shade dimmer at 2 stale copies; "safe" for 0.5 s after the player's hit on a safe body
##   the screen  the match screen after a game: a line per fall ("0:0x  ·  the Tide into the water at N%  ·  Spike") and the
##               tally (falls, % dealt, the highest % survived, the % healed, the longest string, catches, guards, breaks)
## Prints METRIC plates_no_cue_ok. Watchdog LIMIT_S; last line "PERCENT HUD PASSED" or "PERCENT HUD FAILED" (exit 0 only on a
## pass).

const NAME := "PERCENT HUD"
const LIMIT_S := 300.0
const OWN_CFG := "user://percent_hud_test.cfg"

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var ring: RingArena
var player: FrontierPlayer
var mode: RingMode
var rules: RingRules
var hud: FrontierHUD
var bar: PercentBar
var no_cue := false


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
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(s: float) -> void:
	await _ticks(maxi(int(round(s * Engine.physics_ticks_per_second)), 1))


func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit:
		if cond.call():
			return t
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return INF


func _end() -> void:
	print("METRIC plates_no_cue_ok=%s" % str(no_cue).to_lower())
	RingRules.rule_set_override = ""
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


func _run() -> void:
	for i in 10:
		await process_frame
	lvl = current_scene as RingLevel
	mode = RingMode.find(self)
	if lvl == null or mode == null or not RingRules.stock_on():
		_expect(false, "a stock-rules match")
		return _end()
	ring = lvl.ring
	player = lvl.player
	rules = mode.rules
	hud = player.hud
	await _until(func() -> bool: return mode.phase == "COUNTDOWN" and foe() != null, 6.0)
	mode.phase_t = RingRules.num("countdown_s", 3.0) - 0.02
	await _until(func() -> bool: return mode.phase == "FIGHT", 2.0)
	foe().held = true
	await process_frame
	await process_frame
	bar = hud.percent_bar if hud != null else null
	_expect(bar != null and bar.visible and not hud.match_bar.visible, "the % plates shown in place of the match bar")
	if bar == null:
		return _end()
	_layout()
	await _hit()
	_ramp()
	await _fall()
	_yours()
	await _no_cues()
	_flags()
	await _strip()
	await _screen()
	_end()


func _layout() -> void:
	var ok := true
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		var k := float(size.y) / 720.0
		bar.layout_override = "A"
		var a0 := bar.plate_rect(0, 0)
		var a1 := bar.plate_rect(1, 0)
		bar.layout_override = "B"
		var b0 := bar.plate_rect(0, 0)
		var b1 := bar.plate_rect(1, 0)
		var good := a0.position.is_equal_approx(Vector2(24, 16) * k) and a0.size.is_equal_approx(Vector2(270, 84) * k) \
				and is_equal_approx(a1.end.x, float(size.x) - 24.0 * k) and is_equal_approx(a1.position.y, a0.position.y) \
				and b0.end.y > float(size.y) * 0.7 and is_equal_approx(b1.end.x, a1.end.x) and is_equal_approx(b0.position.y, b1.position.y)
		if not good:
			print("    layout %s: A %s / %s, B %s / %s" % [size, a0, a1, b0, b1])
		ok = ok and good
	bar.layout_override = ""
	root.size = Vector2i(1280, 720)
	var l := bar.lines()
	_expect(ok and (l.plates[0] as Array).size() == 1 and (l.plates[1] as Array).size() == 1 and String(l.clock).contains(":"),
			"layout A (top corners, 270 x 84 at (24, 16) x the scale, mirrored) and B (bottom corners) at 1280x720 and 1920x1080; a plate a side; the clock '%s'" % l.clock)


func _info(t: int) -> Dictionary:
	return bar.plate_info(t, 0)


func _hit() -> void:
	var f := foe()
	await process_frame
	var before := float(_info(1).pct)
	BendStatus.hurt(f, 10.0, f.global_position + Vector3.UP, Vector3.FORWARD, player, -1.0, {"tag": "earth_shove/push.grown", "from": player.global_position})
	BendStatus.knock(f, Vector3.FORWARD * 6.0, player, {"tag": "earth_shove/push.grown"})
	var d := rules.pct_of(f) - before
	await process_frame
	var mid := float(_info(1).pct)
	var s: Dictionary = bar._pl[f.get_instance_id()]
	var popping := float(s.pop_t) > 0.0 and float(s.shake_t) > 0.0 and float(s.shake_a) >= 2.0
	await _secs(0.16)
	var after := float(_info(1).pct)
	await _secs(0.2)
	var settled := float(s.pop_t) == 0.0 and float(s.shake_t) == 0.0
	# (round 4: earth's 2 grown, its class's d (the Fissure's 17 since 2026-10-11, the Shove's 16 before) x rules.json
	# stock.pct_scale, BOTS2's pace)
	var want_d := float(RingRules.class_of("earth_shove/push.grown").d)
	_expect(absf(d - want_d * RingRules.stock_num("pct_scale", 1.0)) < 0.01 and mid > before and absf(after - rules.pct_of(f)) < 0.01 and popping and settled,
			"a %.0f%% hit: the digits move within a frame (%.1f), read %.0f by 0.16 s; the pop and the shake (%.1f px) over by 0.35 s"
			% [d, mid, after, float(s.shake_a)])
	rules.reset_pct(f, 0.0)
	await _secs(0.3)


func _ramp() -> void:
	var stops := {0: Color(0.96, 0.94, 0.88), 40: Color(1, 0.86, 0.45), 80: Color(1, 0.58, 0.2), 120: Color(0.92, 0.22, 0.15), 180: Color(0.55, 0.06, 0.08)}
	var ok := true
	for p: int in stops:
		ok = ok and PercentBar.ramp(float(p)).is_equal_approx(stops[p])
	var m := PercentBar.ramp(60.0)
	var between := m.r >= 0.99 and m.g < 0.86 and m.g > 0.58 and m.b < 0.45 and m.b > 0.2
	var naive := Color(1, 0.86, 0.45).lerp(Color(1, 0.58, 0.2), 0.5)
	_expect(ok and between and not m.is_equal_approx(naive), "the ramp: 0/40/80/120/180%% the table's colours; 60%% an OKLab blend (%s, not the plain mix %s)" % [m, naive])


func _fall() -> void:
	var f := foe()
	rules.reset_pct(f, 120.0)
	await _secs(0.3)
	var lives0 := int(_info(1).lives)
	var s: Dictionary = bar._st(f)
	f.global_position = ring.to_global(Vector3(ring.half_l() + 2.0, -6.4, 0.0))
	await _until(func() -> bool: return float(s.get("fall_t", -1.0)) >= 0.0, 1.0)
	await _secs(0.05)
	var t1 := float(s.fall_t)
	var flash_ok := t1 < 0.18 and int(float(_info(1).pct)) == 120
	await _until(func() -> bool: return float(s.get("fall_t", 9.0)) >= 0.36, 1.0)
	var gone := float(s.fall_t) >= 0.35 and float(_info(1).pct) == 0.0
	await _until(func() -> bool: return float(s.get("fall_t", 9.0)) >= 0.81, 1.0)
	var row_short := int(_info(1).lives) == lives0 - 1
	await _until(func() -> bool: return float(s.get("fall_t", 9.0)) >= 1.05 or float(s.get("fall_t", -1.0)) < 0.0, 1.0)
	var zero := String(_info(1).pct_text) == "0"
	_expect(flash_ok and gone and row_short and zero, "a fall: the flash with the old %% at %.2f s (%s), the digits gone by 0.35 s (%s), a life fewer after (%d -> %d), \"0\" at 1.0 s (%s)"
			% [t1, flash_ok, gone, lives0, int(_info(1).lives), zero])
	await _until(func() -> bool: return not rules.is_away(f), 3.0)
	var had := rules.stocks_of(f)
	rules._sk(f)["stocks"] = 1
	_expect(bool(_info(1).last), "the last life: its glyph flagged to pulse")
	rules._sk(f)["stocks"] = had
	(rules._sk(f) as Dictionary)["safe_until"] = -INF


func _yours() -> void:
	var mine := _info(0)
	var theirs := _info(1)
	_expect(bool(mine.mine) and (mine.pips as Array).size() == 3 and float(mine.fresh) >= 0.0 and (theirs.pips as Array).is_empty()
			and float(theirs.fresh) < 0.0, "the pips (jump, dodge, Rise) and the fresh band on your plate only")
	var p0 := float(mine.fresh)
	BendStatus.hurt(player, 10.0, player.global_position + Vector3.UP, Vector3.FORWARD, foe(), -1.0, {"tag": "air_palm/palm", "from": foe().global_position})
	_expect(float(_info(0).fresh) >= p0 + 2.99 * RingRules.stock_num("pct_scale", 1.0), "the fresh band grows with your %% just taken (%.1f -> %.1f)" % [p0, float(_info(0).fresh)])
	var src := FileAccess.get_file_as_string("res://scripts/ui/percent_bar.gd")
	var code := "\n".join(Array(src.split("\n")).filter(func(ln: String) -> bool: return not ln.strip_edges().begins_with("#")))
	var reads := code.contains("global_position") or code.contains("unproject") or code.contains("global_transform") \
			or code.contains("to_local(") or code.contains("nearest_lip") or code.contains("NpcSenses")
	_expect(not reads, "percent_bar.gd reads no body's position (no global_position, unproject, global_transform, to_local)")
	no_cue = not reads


func _canvas_items() -> Dictionary:
	var out := {}
	for n in root.find_children("*", "CanvasItem", true, false):
		var ci := n as CanvasItem
		var at := Vector2.INF
		if ci is Control:
			at = (ci as Control).global_position
		elif ci is Node2D:
			at = (ci as Node2D).global_position
		out[ci.get_instance_id()] = [at, ci.is_visible_in_tree(), String(ci.get_path())]
	return out


static func _moved(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := {}
	for k: int in b:
		if not a.has(k):
			out[k] = "new " + String(b[k][2])
		elif Vector2(a[k][0]).distance_to(Vector2(b[k][0])) > 0.5 or bool(a[k][1]) != bool(b[k][1]):
			out[k] = String(b[k][2])
	return out


func _no_cues() -> void:
	var n := foe()
	var still := ring.to_global(Vector3(6.0, ring.top() + 0.05, -3.0))
	n.global_position = still
	var hold := func() -> void:
		if is_instance_valid(n):
			n.global_position = still
			n.velocity = Vector3.ZERO
	physics_frame.connect(hold)
	await _secs(1.0)
	var a := _canvas_items()
	var draws0 := bar.lines()
	await _secs(1.0)
	var b := _canvas_items()
	physics_frame.disconnect(hold)
	var steady := _moved(a, b)
	var t := 0.0
	while t < 1.0:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		n.global_position = still + Vector3(0.0, 0.0, 6.0) * clampf(t, 0.0, 1.0) + Vector3(4.0, 0.0, 0.0) * clampf(t, 0.0, 1.0)
		n.velocity = Vector3.ZERO
	await _ticks(2)
	var c2 := _canvas_items()
	var tracking: Array = []
	var changed := _moved(b, c2)
	for k: int in changed:
		if not steady.has(k):
			tracking.append(changed[k])
	var draws1 := bar.lines()
	var same_plates := str(draws0.plates) == str(draws1.plates)
	_expect(tracking.is_empty() and same_plates, "the bot moved 7.2 m in 1 s with no hits: no CanvasItem moved, showed or hid with it, the plates the same (%s)" % [tracking])
	no_cue = no_cue and tracking.is_empty() and same_plates


func _flags() -> void:
	_expect(not bool(PercentBar.hud_cfg().get("launch_wake", true)) and not bool(PercentBar.hud_cfg().get("respawn_drip", true)),
			"hud.json launch_wake and respawn_drip both off by default")


func _strip() -> void:
	var st := hud.bend_strip
	st.air_override = true
	var c1 := st.column(1)
	var c2 := st.column(2)
	var c3 := st.column(3)
	var c4 := st.column(4)
	_expect(String(c1.label) == "Hammer" and String(c2.label) == "Dodge" and bool(c3.grey) and String(c3.sub) == "lands"
			and bool(c4.grey) and String(c4.sub) == "lands", "in the air: key 2 the Slam (%s), key 3 \"%s\", keys 4 and 5 grey with \"%s\""
			% [c1.label, c2.label, c3.sub])
	st.air_override = false
	SwayCaster.of(player).ready_default()
	var any3 := false
	for i in 3:
		any3 = any3 or bool(st.column(2).readied)
	_expect(not any3, "key 3 never takes the readied highlight in the % ring")
	# stale copies dim the name
	var id := String(st.column(0).id)
	var md := String(st.column(0).mode)
	rules._stale[player.get_instance_id()] = ["%s/%s" % [id, md], "%s/%s" % [id, md]]
	var c0 := st.column(0)
	_expect(int(c0.stale) == 2 and BendStrip.stale_alpha(2) < 1.0 and BendStrip.stale_alpha(4) < BendStrip.stale_alpha(2)
			and BendStrip.stale_alpha(6) < BendStrip.stale_alpha(4) and BendStrip.stale_alpha(1) == 1.0,
			"your move's name a shade dimmer at 2, 4 and 6 stale copies (%d copies of %s)" % [int(c0.stale), id])
	rules._stale.clear()
	# "safe" after a hit of the player's on a safe body
	var f := foe()
	(rules._sk(f) as Dictionary)["safe_until"] = BendStatus.now() + 1.0
	BendStatus.hurt(f, 10.0, f.global_position + Vector3.UP, Vector3.FORWARD, player, -1.0, {"tag": "stone_form/spike"})
	await process_frame
	var shown := st.safe_shown()
	await _secs(0.6)
	_expect(shown and not st.safe_shown() and rules.pct_of(f) == 0.0, "\"safe\" on your own strip for 0.5 s after your hit on a safe body (no %)")
	(rules._sk(f) as Dictionary)["safe_until"] = -INF


func _screen() -> void:
	var f := foe()
	var fe := mode.end_of(f)
	for i in 2:
		BendStatus.hurt(f, 10.0, f.global_position + Vector3.UP, Vector3.FORWARD, player, -1.0, {"tag": "stone_form/spike", "from": player.global_position})
		await _ticks(2)
		f.global_position = ring.to_global(Vector3(RingArena.side_sign(fe) * (ring.half_l() + 2.0), -6.4, 0.0))
		await _until(func() -> bool: return mode.phase != "FIGHT" or rules.is_away(f), 2.0)
		if mode.phase == "FIGHT":
			await _until(func() -> bool: return not rules.is_away(f), 3.0)
			await _ticks(2)
	await _until(func() -> bool: return mode.phase == "DONE", 5.0)
	var ms := mode.match_screen as MatchScreen
	var l := ms.lines()
	var rows: Array = l.rounds
	var fall_ok := false
	for r: String in rows:
		fall_ok = fall_ok or (r.contains("the Tide into the water at") and r.ends_with("Spike"))
	var tl := String(l.totals)
	_expect(mode.phase == "DONE" and ms.is_open() and fall_ok and tl.contains("Falls") and tl.contains("dealt") and tl.contains("Longest string")
			and tl.contains("healed") and tl.contains("perfect guards"), "the match screen: a line per fall (%s) and the tally (%s)" % [rows, tl.replace("\n", " / ")])
