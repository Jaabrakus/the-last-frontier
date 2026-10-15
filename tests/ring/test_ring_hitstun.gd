extends SceneTree
## Round 3's hitstun and its fairness (smash_r3 spec v2 §2.2, §3, §6.7, §15 PERCENT; RingRules, BendKnock), in the ring scene
## with a stock-rules match asked for (RingRules.rule_set_override "stock"), the foe held; every hit the test's own through
## BendStatus.hurt / knock with round 3's hit info:
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_ring_hitstun.gd -- mode=ring element=earth foe=water
##   hitstun     clamp(0.045 v, 0.12, 1.2); the set stuns (jab 0.30, Pull 0.40, Pop 0.60, Slam 0.30)
##   set, not add  6 Palms at 0.25 s spacing leave kv <= 4.5 m/s and the body on the deck; Pull x6 from 2 m never carries
##               him past the caster
##   untouched   during the player's hitstun his camera's basis, yaw and pitch are as before the hit (the hit never turns
##               them; the lock's freeze is AIR's)
##   the escape  hitstun_left counts the 0.6 s escape; the escape refused at 0.55, refused for a press made at 0.4, taken by
##               a fresh press at 0.6
##   steering    0.1 s after the hit the carry's yaw turns 15 deg, its pitch (vy) unchanged; held against the flight 0.6 +-
##               0.05 m/s less carry once its window (from the hit-stop's end) is over; the player and a bot alike;
##               last_steer_deg reports it
##   strings     decay on every hit (1, 0.8, 0.64, 0.512 ...), the Pop exempt (0.60), a jab after the Pop 0.10 s, the 6th
##               hit <= 0.10 s, the 0.4 s breather after a 4-hit string; counted on the victim across two attackers
##   refresh     a tumbling launch class refreshes the air moves (BendKnock.launched refresh); a jab, a flinch and the Slam
##               don't
##   the fall    E 0.2 s before the deck stands; with D held it rolls; E 0.4 s before spoils it; E 0.8 s before and again
##               0.1 s before stands; a missed fall lies >= 0.4 s; a hit on a lying body: a set 5 m/s, 0.2 s, he stands
##   tumble      at 9 m/s or 60 deg; under that a flinch on the feet
## Prints METRIC lines (set_not_add_ok, hitstun_fair_ok, escape_fresh_press_ok, steer_yaw_only_ok, break_fall_ok,
## string_decay_ok). Watchdog LIMIT_S; last line "RING HITSTUN PASSED" or "RING HITSTUN FAILED" (exit 0 only on a pass).

const NAME := "RING HITSTUN"
const LIMIT_S := 360.0
const OWN_CFG := "user://ring_hitstun_test.cfg"

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var ring: RingArena
var player: FrontierPlayer
var mode: RingMode
var rules: RingRules
var rival: Node3D
var metrics := {}
var last_stun := -1.0
var last_refresh := false
var last_v := Vector3.ZERO


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _metric(key: String, ok: bool) -> void:
	metrics[key] = bool(metrics.get(key, true)) and ok


func _initialize() -> void:
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	MatchSetup._aim_help = "strong"
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	RingRules.rule_set_override = "stock"
	# (the launch's own numbers: the combo's finisher, a full meter's next hit launched as the Pop is, off here: BendCombo)
	BendCombo.enabled = false
	SwayCaster.free_override = true
	InputSetup.ensure()
	MatchSetup.incoming = true
	# (the header's matchup without its args too, earth against water: the launch numbers below are the water foe's; the args,
	# when given, still apply over it: MatchSetup.take)
	MatchSetup.kind = "match"
	MatchSetup.element = "earth"
	MatchSetup.foes = ["water"]
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
	for k: String in ["set_not_add_ok", "hitstun_fair_ok", "escape_fresh_press_ok", "steer_yaw_only_ok", "break_fall_ok", "string_decay_ok"]:
		print("METRIC %s=%s" % [k, str(bool(metrics.get(k, false))).to_lower()])
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


func _go_fight() -> void:
	await _until(func() -> bool: return mode.phase == "COUNTDOWN" and foe() != null, 6.0)
	mode.phase_t = RingRules.num("countdown_s", 3.0) - 0.02
	await _until(func() -> bool: return mode.phase == "FIGHT", 2.0)
	if foe() != null:
		foe().held = true


func _fresh(foe_x := 4.0) -> void:
	var f := foe()
	for b: Node3D in [player, f]:
		var kn := BendKnock.peek(b)
		if kn != null:
			kn.reset()
		(b as CharacterBody3D).velocity = Vector3.ZERO
	player.global_position = ring.to_global(Vector3(-4.0, ring.top() + 0.05, 0.0))
	f.global_position = ring.to_global(Vector3(foe_x, ring.top() + 0.05, 0.0))
	rival.global_position = ring.to_global(Vector3(-4.0, ring.top() + 0.05, 3.0))
	# (a fall earlier in the test: its respawn called off, both shown and solid again)
	mode._respawns.clear()
	mode._hide(player, false)
	mode._hide(foe(), false)
	rules.reset_game()
	await _ticks(4)


func _hit(n: Node3D, by: Node3D, tag: String, extra := {}, way := Vector3.ZERO) -> void:
	var w := way
	if w == Vector3.ZERO:
		w = n.global_position - by.global_position
		w.y = 0.0
		w = w.normalized()
	var info := {"tag": tag, "from": by.global_position}
	info.merge(extra, true)
	BendStatus.hurt(n, 10.0, n.global_position + Vector3.UP, w, by, -1.0, info)
	BendStatus.knock(n, w * 6.0 + Vector3.UP, by, info)


func _on_launched(b: Node3D, v: Vector3, hs: float, _by: Node, _tag: String) -> void:
	if b == foe() or b == player:
		last_stun = hs
		last_v = v


func _run() -> void:
	for i in 10:
		await process_frame
	lvl = current_scene as RingLevel
	_expect(lvl != null, "the scene is the ring")
	if lvl == null:
		return _end()
	ring = lvl.ring
	player = lvl.player
	mode = RingMode.find(self)
	if mode == null or not RingRules.stock_on():
		_expect(false, "a stock-rules match")
		return _end()
	rules = mode.rules
	rules.launched.connect(_on_launched)
	rival = Node3D.new()
	rival.name = "Rival"
	lvl.add_child(rival)
	await _go_fight()
	BendKnock.of(foe()).launched.connect(func(_v: Vector3, _hs: float, refresh: bool) -> void: last_refresh = refresh)
	await _stun_checks()
	await _set_checks()
	await _untouched_checks()
	await _escape_checks()
	await _steer_checks()
	await _string_checks()
	await _refresh_checks()
	await _fall_checks()
	await _tumble_checks()
	_end()


func _stun_checks() -> void:
	var ok := absf(RingRules.hitstun_of(5.0) - 0.225) < 1e-4 and RingRules.hitstun_of(1.0) == 0.12 and RingRules.hitstun_of(40.0) == 1.2
	_expect(ok, "hitstun = clamp(0.045 v, 0.12, 1.2): 5 m/s 0.225 s, 1 m/s 0.12 s, 40 m/s 1.2 s")
	var f := foe()
	var got := {}
	for tag: String in ["air_palm/palm", "air_gust/pull", "jab/pop", "earth_shove/slam"]:
		await _fresh()
		if tag == "earth_shove/slam":
			f.velocity.y = 6.0
			await _ticks(5)
		_hit(f, player, tag)
		got[tag] = last_stun
		await _secs(0.8)
	var ok2 := absf(float(got["air_palm/palm"]) - 0.30) < 1e-3 and absf(float(got["air_gust/pull"]) - 0.40) < 1e-3 \
			and absf(float(got["jab/pop"]) - 0.60) < 1e-3 and absf(float(got["earth_shove/slam"]) - 0.30) < 1e-3
	_expect(ok2, "the set stuns: jab 0.30, Pull 0.40, Pop 0.60, the Slam 0.30 (%s)" % str(got))
	_metric("hitstun_fair_ok", ok and ok2)


func _set_checks() -> void:
	var f := foe()
	await _fresh(-1.0)
	var worst := 0.0
	var off := false
	for i in 6:
		_hit(f, player, "air_palm/palm")
		await _ticks(1)
		worst = maxf(worst, BendKnock.of(f).kv.length())
		await _secs(0.25)
		off = off or not ring.on_deck(f.global_position) or f.global_position.y < ring.top() - 0.3
		worst = maxf(worst, BendKnock.of(f).kv.length())
	_expect(worst <= 4.5 + 1e-3 and not off, "6 Palms at 0.25 s: the carry never over 4.5 m/s (%.2f), the body on the deck" % worst)
	# Pull x6 from 2 m: never past the caster
	await _fresh(-2.0)
	var way := (player.global_position - f.global_position)
	way.y = 0.0
	way = way.normalized()
	var past := false
	var min_gap := INF
	for i in 6:
		var to := player.global_position - f.global_position
		to.y = 0.0
		_hit(f, player, "air_gust/pull", {}, to.normalized())
		for k in 24:
			await physics_frame
			var d := (player.global_position - f.global_position)
			d.y = 0.0
			min_gap = minf(min_gap, d.dot(way))
			past = past or d.dot(way) < 0.0
	_expect(not past, "Pull x6 from 2 m never carries him past the caster (the nearest %.2f m short of him)" % min_gap)
	_metric("set_not_add_ok", worst <= 4.5 + 1e-3 and not off and not past)


func _untouched_checks() -> void:
	await _fresh()
	await _ticks(5)
	var cam := player.get_viewport().get_camera_3d()
	var yaw0 := player.yaw
	var pitch0 := player.pitch
	var b0 := cam.global_basis if cam != null else Basis()
	rules.add_pct(player, 80.0, null, "")
	_hit(player, foe(), "stone_form/spike")
	var same := true
	for i in 30:
		await physics_frame
		var cb := cam.global_basis if cam != null else Basis()
		same = same and player.yaw == yaw0 and player.pitch == pitch0 and cb.is_equal_approx(b0)
	_expect(same, "through the player's hitstun his camera's basis, yaw and pitch are untouched")
	await _until(func() -> bool: return player.is_on_floor(), 3.0)


func _escape_checks() -> void:
	var f := foe()
	await _fresh()
	rules.add_pct(f, 150.0, null, "")
	_hit(f, player, "stone_form/cannonball")
	var kn := BendKnock.of(f)
	var t0 := BendStatus.now()
	var hs := last_stun
	var left0 := rules.hitstun_left(f)
	await _until(func() -> bool: return BendStatus.now() - t0 >= 0.55 - 1e-4, 2.0)
	var early := kn.escape() == false and not rules.can_escape(f)
	await _until(func() -> bool: return BendStatus.now() - t0 >= 0.6 - 1e-4, 2.0)
	var buffered := kn.escape(t0 + 0.4) == false and rules.stunned(f)
	var fresh := rules.can_escape(f) and kn.escape(BendStatus.now()) and not rules.stunned(f)
	var ok := hs > 0.6 and absf(left0 - 0.6) < 0.02 and early and buffered and fresh
	_expect(ok, "the escape: a %.2f s hitstun reads %.2f s left (the escape counted); refused at 0.55 (%s), refused for a press made at 0.4 (%s), taken by a fresh press at 0.6 (%s)"
			% [hs, left0, early, buffered, fresh])
	_metric("escape_fresh_press_ok", ok)
	await _until(func() -> bool: return f.is_on_floor(), 3.0)


## A launch of the body `b` by `by` at 100% (a Spike), steered at 0.1 s by `dir` (ZERO: none): [yaw turn, vy change at the
## steer, carry once the steer's window is over].
func _steer_run(b: Node3D, by: Node3D, dir: Vector3) -> Array:
	await _fresh()
	rules.add_pct(b, 100.0, null, "")
	_hit(b, by, "stone_form/spike")
	var kn := BendKnock.of(b)
	await _secs(0.1)
	var f0 := Vector3(kn.kv.x, 0.0, kn.kv.z)
	var vy0 := (b as CharacterBody3D).velocity.y
	var w := dir
	if dir == Vector3.RIGHT:
		w = f0.normalized().cross(Vector3.UP)          # (across the flight)
	elif dir == Vector3.BACK:
		w = -f0.normalized()                          # (against it)
	# (the carry read the same game time after the hit-stop's hold in every run, once the steer's window is over: the window
	# counts from the hold's end (BendKnock.apply_di), and the hold grew to 0.2 s with the owner's "more impact" (2026-10-13,
	# feel.json hitstop), so a read 0.35 s after the steer came part way through it)
	var read_at := BendStatus.now() + kn.hold_left() + RingRules.stock_num("di_against_s", 0.3) + 0.05
	if dir != Vector3.ZERO:
		kn.apply_di(w)
	var f1 := Vector3(kn.kv.x, 0.0, kn.kv.z)
	var vy1 := (b as CharacterBody3D).velocity.y
	var turn := rad_to_deg(f0.signed_angle_to(f1, Vector3.UP))
	await _until(func() -> bool: return BendStatus.now() >= read_at, 2.0)
	var carry := kn.kv.length()
	await _until(func() -> bool: return (b as CharacterBody3D).is_on_floor(), 3.0)
	return [turn, vy1 - vy0, carry]


func _steer_checks() -> void:
	var f := foe()
	var across := await _steer_run(f, player, Vector3.RIGHT)
	var none := await _steer_run(f, player, Vector3.ZERO)
	var against := await _steer_run(f, player, Vector3.BACK)
	var p_across := await _steer_run(player, f, Vector3.RIGHT)
	var ok_yaw := absf(absf(float(across[0])) - 15.0) < 0.05 and absf(float(across[1])) < 1e-4
	var lost := float(none[2]) - float(against[2])
	var ok_against := absf(lost - 0.6) <= 0.05
	var ok_player := absf(absf(float(p_across[0])) - 15.0) < 0.05 and absf(float(p_across[1])) < 1e-4
	var rep := absf(rules.last_steer_deg(player) - 15.0) < 0.05
	_expect(ok_yaw, "steering 0.1 s after the hit turns the carry's yaw 15 deg (%.2f), its vy unchanged (%.4f)" % [across[0], across[1]])
	_expect(ok_against, "held against the flight: %.2f m/s less carry (0.6 +- 0.05)" % lost)
	_expect(ok_player and rep, "the player steers the same (%.2f deg); last_steer_deg reports it (%.2f)" % [p_across[0], rules.last_steer_deg(player)])
	_metric("steer_yaw_only_ok", ok_yaw and ok_against and ok_player and rep)


func _string_checks() -> void:
	var f := foe()
	# decay on every hit: Spikes landing inside the hitstun (at 150%: long stuns), from two attackers by turns
	await _fresh()
	rules.add_pct(f, 150.0, null, "")
	var stuns: Array = []
	var bys := [player, rival, player, rival, player]
	for i in 5:
		_hit(f, bys[i], "stone_form/spike")
		stuns.append(last_stun)
		await _ticks(6)
	var ok_d := true
	var ratios: Array = []
	for i in 5:
		ratios.append(snappedf(float(stuns[i]) / maxf(float(stuns[0]), 1e-4), 0.001))
	for i in 5:
		ok_d = ok_d and absf(float(ratios[i]) - pow(0.8, i)) < 0.03
	_expect(ok_d and rules.string_hits(f) == 5, "decay on every hit, counted on the victim across two attackers: %s (1, 0.8, 0.64, 0.51, 0.41)" % str(ratios))
	await _until(func() -> bool: return not rules.stunned(f), 3.0)
	await _until(func() -> bool: return f.is_on_floor(), 3.0)
	# the Pop exempt; a jab after it 0.10 s; the 6th hit <= 0.10
	await _fresh()
	var seq: Array = []
	for tag: String in ["air_palm/palm", "air_palm/palm", "jab/pop", "air_palm/palm", "air_palm/palm", "air_palm/palm"]:
		_hit(f, player, tag)
		seq.append(last_stun)
		await _ticks(4)
	var ok_p := absf(float(seq[0]) - 0.30) < 1e-3 and absf(float(seq[1]) - 0.24) < 1e-3 and absf(float(seq[2]) - 0.60) < 1e-3 \
			and float(seq[3]) <= 0.1 + 1e-4 and float(seq[5]) <= 0.1 + 1e-4
	_expect(ok_p, "jab 0.30, jab 0.24, the Pop 0.60 (exempt), a jab after the Pop 0.10, the 6th hit <= 0.10 (%s)" % str(seq))
	# the breather: a string of 4 ends; a hit within 0.4 s stuns <= 0.10
	await _until(func() -> bool: return not rules.stunned(f), 3.0)
	await _until(func() -> bool: return f.is_on_floor(), 3.0)
	await _fresh()
	var ended := [0]
	var cb := func(_by: Node, v: Node3D, hits: int, _p: float) -> void:
		if v == f:
			ended[0] = hits
	rules.string_ended.connect(cb)
	for i in 4:
		_hit(f, player, "air_palm/palm")
		await _ticks(4)
	await _until(func() -> bool: return not rules.stunned(f), 2.0)
	await _ticks(2)
	_hit(f, player, "air_palm/palm")
	var breather := last_stun
	rules.string_ended.disconnect(cb)
	await _secs(0.6)
	_hit(f, player, "air_palm/palm")
	var after := last_stun
	var ok_b := int(ended[0]) == 4 and breather <= 0.1 + 1e-4 and absf(after - 0.30) < 1e-3
	_expect(ok_b, "a string of 4 ends (string_ended 4); a hit 0.03 s later stuns %.2f s (<= 0.10), one 0.6 s later 0.30 again (%.2f)" % [breather, after])
	_metric("string_decay_ok", ok_d and ok_p and ok_b)
	await _secs(0.5)


func _refresh_checks() -> void:
	var f := foe()
	var got := {}
	for tag: String in ["stone_form/cannonball", "air_palm/palm", "stone_form/spike", "earth_shove/slam"]:
		await _fresh()
		if tag == "earth_shove/slam":
			f.velocity.y = 6.0
			await _ticks(5)
		last_refresh = false
		_hit(f, player, tag)
		got[tag] = [last_refresh, BendKnock.of(f).tumble]
		await _until(func() -> bool: return f.is_on_floor() and not rules.stunned(f), 3.0)
		await _secs(0.3)
	var ok := bool(got["stone_form/cannonball"][0]) and bool(got["stone_form/cannonball"][1]) and not bool(got["air_palm/palm"][0]) \
			and not bool(got["stone_form/spike"][0]) and not bool(got["stone_form/spike"][1]) and not bool(got["earth_shove/slam"][0])
	_expect(ok, "a tumbling launch class refreshes the air moves; a jab, a flinch (a Spike at 0%%) and the Slam don't (%s)" % str(got))


## The foe popped up (a Pop: set 9 m/s at 80 deg, tumbling); E pressed at each of `presses` (s before the contact, the
## contact frame measured first), D held with it when `dir`: {broke: kind or "", lying: lying_t at contact + 0.05}.
func _fall_run(contact_s: float, presses: Array, dir := Vector3.ZERO) -> Dictionary:
	var f := foe()
	await _fresh()
	var kn := BendKnock.of(f)
	var broke := [""]
	var cb := func(kind: String, _d: Vector3) -> void: broke[0] = kind
	kn.broke_fall.connect(cb)
	_hit(f, player, "jab/pop")
	var t0 := BendStatus.now()
	var ps := presses.duplicate()
	ps.sort()
	ps.reverse()
	while BendStatus.now() - t0 < contact_s + 0.08:
		var left := contact_s - (BendStatus.now() - t0)
		while not ps.is_empty() and left <= float(ps[0]) + 1e-4:
			kn.press_break(dir)
			ps.pop_front()
		await physics_frame
	var lying := kn.lying_t
	kn.broke_fall.disconnect(cb)
	return {"broke": broke[0], "lying": lying, "bounce": kn.is_launched()}


func _fall_checks() -> void:
	var f := foe()
	# the contact's moment (the first frame on the deck after the Pop)
	await _fresh()
	var kn := BendKnock.of(f)
	var landed := [INF]
	var t0 := [0.0]
	var cb := func() -> void:
		if is_inf(float(landed[0])):
			landed[0] = BendStatus.now() - float(t0[0])
	kn.landed.connect(cb)
	_hit(f, player, "jab/pop")
	t0[0] = BendStatus.now()
	await _until(func() -> bool: return not is_inf(float(landed[0])), 3.0)
	kn.landed.disconnect(cb)
	var contact := float(landed[0])
	await _until(func() -> bool: return kn.lying_t <= 0.0 and f.is_on_floor() and not kn.is_launched(), 4.0)
	await _secs(1.2)
	var a := await _fall_run(contact, [0.2])
	await _secs(1.4)
	var b := await _fall_run(contact, [0.2], Vector3.RIGHT)
	await _secs(1.4)
	var c := await _fall_run(contact, [0.4])
	await _until(func() -> bool: return f.is_on_floor() and not kn.is_launched(), 3.0)
	await _ticks(2)
	var lie_age_ok := kn.lying_t > 0.0 and not kn.getup("stand")
	await _until(func() -> bool: return kn.lying_age() >= 0.41, 2.0)
	var stood := kn.getup("stand")
	await _secs(1.4)
	var d := await _fall_run(contact, [0.8, 0.1])
	await _secs(1.4)
	# a missed fall: lying; a hit on the lying body: a set 5 m/s at 20 deg, a 0.2 s stun, he stands
	var e := await _fall_run(contact, [])
	await _until(func() -> bool: return f.is_on_floor() and not kn.is_launched() and kn.lying_t > 0.0, 3.0)
	var refused := not BendStatus.can_take(f, player)          # (the first 0.2 s lying: intangible)
	await _secs(0.25)
	var lying_now := kn.lying_t > 0.0 and refused and BendStatus.can_take(f, player)
	_hit(f, player, "stone_form/cannonball")
	var lying_hit := lying_now and absf(last_v.length() - 5.0) < 0.05 and absf(last_stun - 0.2) < 1e-3 and kn.lying_t <= 0.0
	_expect(String(a.broke) == "stand", "E 0.2 s before the deck: the fall broken, he stands (%s)" % a.broke)
	_expect(String(b.broke) == "roll", "E 0.2 s before with D held: he rolls (%s)" % b.broke)
	_expect(String(c.broke) == "", "E 0.4 s before the deck spoils it (%s)" % c.broke)
	_expect(lie_age_ok and stood, "a missed fall lies at least 0.4 s (no getting up before; up after: %s)" % stood)
	_expect(String(d.broke) == "stand", "E 0.8 s before and again 0.1 s before: stands (the early one counts for nothing) (%s)" % d.broke)
	_expect(String(e.broke) == "" and lying_hit, "lying: intangible his first 0.2 s; then a hit on him: a set 5 m/s (%.2f), a 0.2 s stun (%.2f), he stands" % [last_v.length(), last_stun])
	_metric("break_fall_ok", String(a.broke) == "stand" and String(b.broke) == "roll" and String(c.broke) == "" and lie_age_ok and stood
			and String(d.broke) == "stand" and lying_hit)
	await _secs(1.5)


func _tumble_checks() -> void:
	var f := foe()
	var cs := RingRules.data()["stock"]["classes"] as Dictionary
	cs["test/under"] = {"d": 0.0, "base": 8.9, "growth": 0.0, "angle": 30, "set": true}
	cs["test/at"] = {"d": 0.0, "base": 9.0, "growth": 0.0, "angle": 30, "set": true}
	cs["test/steep"] = {"d": 0.0, "base": 3.0, "growth": 0.0, "angle": 60, "set": true}
	var got := {}
	for tag: String in ["test/under", "test/at", "test/steep"]:
		await _fresh()
		_hit(f, player, tag)
		got[tag] = BendKnock.of(f).tumble
		await _until(func() -> bool: return f.is_on_floor() and not rules.stunned(f) and not BendKnock.of(f).is_launched(), 3.0)
		await _secs(1.2)
	for tag: String in ["test/under", "test/at", "test/steep"]:
		cs.erase(tag)
	var ok := not bool(got["test/under"]) and bool(got["test/at"]) and bool(got["test/steep"])
	_expect(ok, "a tumble at 9 m/s or 60 deg; 8.9 m/s at 30 deg flinches on the feet (%s)" % str(got))
	_metric("hitstun_fair_ok", ok)
