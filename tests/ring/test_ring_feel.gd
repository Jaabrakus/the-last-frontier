extends SceneTree
## Round 4 IMPACT: hits with weight (BendImpact, RingMoment, CameraShake.jolt, RingWater.ko_splash; data/ring/feel.json), in
## the ring scene with a stock-rules match (earth against a water bot, held), then Practice, then the classic ring:
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_ring_feel.gd -- mode=ring element=earth foe=water
##   the bot     a launch of 12 m/s: its pose holds about hold_s (its animation does not advance), its motion starts hold_s
##               later, its stun ends on the same physics frame as with the feel off
##   the player  a real hit of about 12 m/s on him (a Spike, his lock filling, Space pressed in the hitstun): his pose holds;
##               his camera's basis, his yaw and pitch, his aim's ray, his lock's fill and state and the buffered jump (when
##               it fires) are identical to the feel off, frame by frame (his aim POINT is the camera's ray from where the
##               camera is: it follows his body, whose flight starts hold_s later; printed, not gated)
##   the hitter  his pose holds when he struck from 2 m, not from 10 m
##   the KO %    PERCENT's in-engine check with the feel on and off: a water body at the middle in the water at the first %, not
##               at the second (Boulder 125/100, Spike 170/145, Punch 245/215, Gust grown 135/115)
##   the jolt    moves h_offset / v_offset, never the camera's basis; the aim point (the player still) bit-identical
##   the beat    a perfect guard holds both poses ~0.07 s (the sender within 6 m), a late one does not; a perfect Catch's
##               stone, its catch frame, its E-return frame and the stone's flight are the same frames with the feel off
##   feel off    feel.json enabled false: no hold, no jolt, no moment
##   the moment  a game's last fall sets time_scale 0.35 and it is back to 1.0 within 1.0 s real (the frames' unscaled time);
##               put back by RingMode.restart mid-moment, an Esc pause, a second fall and the scene's exit
##   Practice    a fall: no moment and no jolt (the hit-stop stays)
##   the gate    the classic ring: a knock holds nothing, a quake jolts the view as before (offsets, no turn), a rang_out gets
##               the KO splash and nothing else
## METRIC lines: hold_ms at 6/12/18 m/s, stun_end_unchanged_ok, player_cam_aim_lock_unchanged_ok, ko_calibration_unchanged_ok,
## perfect_hold_ms, catch_unchanged_ok, jolt_basis_unchanged_ok, timescale_restored_ok, open_world_unchanged_ok.
## Watchdog LIMIT_S; last line "RING FEEL PASSED" or "RING FEEL FAILED" (exit 0 only on a pass).

const NAME := "RING FEEL"
const LIMIT_S := 400.0
const OWN_CFG := "user://ring_feel_test.cfg"
const STONE := {"kind": "stone", "mps": 40.0, "gravity": 0.0, "damage": 20.0, "knock_mps": 6.0, "up_mps": 0.0, "radius_m": 0.25,
		"range_m": 30.0}
## PERCENT's in-engine KO check: tag -> [in the water at, not at] (%).
const KO_CHECK := {"stone_form/cannonball": [125.0, 100.0], "stone_form/spike": [170.0, 145.0],
		"fire_blast/punch": [245.0, 215.0], "air_gust/gust.grown": [135.0, 115.0]}

var checks := 0
var fails: Array[String] = []
var metrics := {}
var lvl: RingLevel
var ring: RingArena
var player: FrontierPlayer
var mode: RingMode
var rules: RingRules
var c: SwayCaster
var kos: Array = []
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
		Engine.time_scale = 1.0
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	MatchSetup._aim_help = "strong"
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	RingRules.rule_set_override = "stock"
	SwayCaster.free_override = true
	InputSetup.ensure()
	MatchSetup.incoming = true
	MatchSetup.kind = "match"
	BendImpact.jolt_override = true
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
	mode = RingMode.find(self)
	if mode == null or player == null:
		return false
	rules = mode.rules
	player.ignore_mouse_capture = true
	c = SwayCaster.of(player)
	rules.ko.connect(func(b: Node3D, _by: Node, _p: float, _t: String, _l: int) -> void: kos.append(b))
	rules.launched.connect(func(b: Node3D, v: Vector3, _hs: float, _by: Node, _tag: String) -> void:
		if b == player or b == foe():
			last_v = v)
	await _go_fight()
	return true


func _go_fight() -> void:
	await _until(func() -> bool: return mode.phase == "COUNTDOWN" and foe() != null, 6.0)
	mode.phase_t = RingRules.num("countdown_s", 3.0) - 0.02
	await _until(func() -> bool: return mode.phase == "FIGHT", 2.0)
	if foe() != null:
		foe().held = true
	await _ticks(25)                           # (BendImpact's ring hooks: every 20 steps)


## Both still at x (ring frame, along its length), in play, % nil, no holds, no stun.
func _fresh(px := -4.0, fx := 4.0, fz := 0.0) -> void:
	var f := foe()
	c.held_override = false
	c.guard_override = false
	for b: Node3D in [player, f]:
		var kn := BendKnock.peek(b)
		if kn != null:
			kn.reset()
		(b as CharacterBody3D).velocity = Vector3.ZERO
		if b.has_meta(BendImpact.HOLD_META):
			b.remove_meta(BendImpact.HOLD_META)
		for k: StringName in BendStatus.ROUND_METAS:
			if b.has_meta(k):
				b.remove_meta(k)
	for g: StringName in [BendBolt.GROUP, BendZone.GROUP, FormStone.GROUP, GustLift.GROUP]:
		for x in get_nodes_in_group(g):
			if is_instance_valid(x):
				x.queue_free()
	mode._respawns.clear()
	mode._hide(player, false)
	mode._hide(f, false)
	rules.reset_game()
	rules._stale.clear()
	RingLevel.place(player, Transform3D(Basis.looking_at(ring.global_basis * Vector3(1.0, 0.0, 0.0), Vector3.UP),
			ring.to_global(Vector3(px, ring.top() + 0.05, 0.0))))
	f.global_position = ring.to_global(Vector3(fx, ring.top() + 0.05, fz))
	player.pitch = -0.05
	await _ticks(8)
	# (the same phase every time: the first physics step of a drawn frame; at 120 ticks and 60 frames a frame has two, and
	# what runs per frame (the lock's fill) would see the hit one step apart from run to run)
	await process_frame
	await physics_frame


func _way() -> Vector3:
	return ring.global_basis * Vector3(1.0, 0.0, 0.0)


func _run() -> void:
	var ok := await _scene()
	_expect(ok and RingRules.stock_on(), "the stock ring, its match and its player")
	if not ok:
		return _end()
	for v: float in [6.0, 12.0, 18.0]:
		var hs := RingRules.hitstun_of(v)
		print("METRIC hold_ms_%d=%.1f (hitstun %.0f ms)" % [int(v), BendImpact.hold_for(v, hs) * 1000.0, hs * 1000.0])
	_expect(absf(BendImpact.hold_for(18.0, 0.81) - 0.11) < 1e-6 and absf(BendImpact.hold_for(5.0, 0.12) - 0.045) < 1e-3
			and BendImpact.hold_for(3.9, 0.5) == 0.0 and absf(BendImpact.hold_for(18.0, 0.12) - 0.048) < 1e-6,
			"the hold: 0.11 s at 18 m/s, capped at 0.4 of a 0.12 s stun (0.048), none under 4 m/s")
	await _bot_checks()
	await _player_checks()
	await _hitter_checks()
	await _ko_checks()
	await _jolt_checks()
	await _perfect_checks()
	await _catch_checks()
	await _off_checks()
	await _moment_checks()
	await _practice_checks()
	await _classic_checks()
	_end()


# ---------------------------------------------------------------- the bot hit at 12 m/s
func _launch12(b: Node3D, by: Node3D) -> float:
	var a := deg_to_rad(35.0)
	var v := _way() * 12.0 * cos(a) + Vector3.UP * 12.0 * sin(a)
	var hs := RingRules.hitstun_of(12.0)
	BendKnock.of(b).knock(v, by, {"_launch": {"v": v, "hitstun_s": hs, "tumble": true}})
	return hs


func _bot_run(feel: bool) -> Dictionary:
	BendImpact.enabled_override = feel
	await _fresh(-6.0, 0.0)
	var f := foe()
	var kn := BendKnock.of(f)
	var p0 := f.global_position
	_launch12(f, player)
	var hold := BendImpact.last_hold_s if feel else 0.0
	var move_i := -1
	var stun_i := -1
	var held_n := 0
	var frozen := true
	var pos0 := f.body.ap.current_animation_position if f.body != null and f.body.ap != null else 0.0
	var t_start := BendStatus.now()
	for i in 70:
		await physics_frame
		await process_frame
		if move_i < 0 and f.global_position.distance_to(p0) > 0.01:
			move_i = i
		if stun_i < 0 and kn.stun_t <= 0.0:
			stun_i = i
		if BendImpact.held(f):
			held_n += 1
			var pos := f.body.ap.current_animation_position if f.body != null and f.body.ap != null else 0.0
			frozen = frozen and is_equal_approx(pos, pos0)
		elif f.body != null and f.body.ap != null:
			pos0 = f.body.ap.current_animation_position
	var iter_s := (BendStatus.now() - t_start) / 70.0
	await _until(func() -> bool: return f.is_on_floor() and not kn.is_launched(), 3.0)
	return {"move_i": move_i, "stun_i": stun_i, "held_n": held_n, "hold": hold, "frozen": frozen, "iter_s": iter_s}


func _bot_checks() -> void:
	var off := await _bot_run(false)
	var on := await _bot_run(true)
	var want := roundi(float(on.hold) / maxf(float(on.iter_s), 1e-4))     # (in drawn frames: each step of the loop is one)
	var late := int(on.move_i) - int(off.move_i)
	var stun_same := int(on.stun_i) == int(off.stun_i) and int(on.stun_i) > 0
	_expect(absf(int(on.held_n) - want) <= 1 and bool(on.frozen) and int(off.held_n) == 0,
			"a bot launched at 12 m/s: its pose holds %d frames (hold %.0f ms: %d), its animation still meanwhile (%s)"
			% [on.held_n, float(on.hold) * 1000.0, want, on.frozen])
	_expect(absf(late - want) <= 1, "its motion starts %d frames later than with the feel off (want %d)" % [late, want])
	_expect(stun_same, "its stun ends on the same physics frame (%d on, %d off)" % [on.stun_i, off.stun_i])
	_metric("stun_end_unchanged_ok", stun_same)


# ---------------------------------------------------------------- the player hit
## The % before a hit of `tag` from `range_m` that launches a body of `el` at `mps`.
func _pct_for(tag: String, el: String, mps: float, range_m: float) -> float:
	var cls := RingRules.class_of(tag)
	var lo := 0.0
	var hi := 400.0
	for i in 40:
		var mid := (lo + hi) * 0.5
		if RingRules.launch_v(cls, mid + float(cls.get("d", 0.0)), float(cls.get("d", 0.0)), RingRules.weight_of(el), range_m) < mps:
			lo = mid
		else:
			hi = mid
	return lo


func _player_run(feel: bool) -> Array:
	BendImpact.enabled_override = feel
	await _fresh(-10.0, -14.0, 0.0)
	var f := foe()
	var rm := RingMoves.of(player)
	var cam := player.camera
	rules.reset_pct(player, _pct_for("stone_form/spike", "earth", 12.0, 4.0))
	c.held_override = true                         # (a lock filling as he is struck)
	await _ticks(9)
	var w := _way()
	var info := {"tag": "stone_form/spike", "from": f.global_position}
	BendStatus.hurt(player, 10.0, player.global_position + Vector3.UP, w, f, -1.0, info)
	BendStatus.knock(player, w * 6.0 + Vector3.UP, f, info)
	var rows: Array = []
	var held_n := 0
	var aim_pts: Array = []
	for i in 70:
		if i == 6:
			Input.action_press(&"jump")
		elif i == 8:
			Input.action_release(&"jump")
		await physics_frame
		await process_frame
		if BendImpact.held(player):
			held_n += 1
		rows.append([cam.global_basis, player.yaw, player.pitch, -cam.global_basis.z, c.fill, int(c.state), rm._buffer,
				rm.jumps_left, rules.stunned(player)])
		aim_pts.append(player.get_aim_point())
	c.held_override = false
	await _until(func() -> bool: return player.is_on_floor(), 3.0)
	return [rows, held_n, BendImpact.last_hold_s, last_v.length(), aim_pts]


## A run's rows with the lock's fill as its change since the hit (the fill before the hit is per drawn frame and so lands a
## step apart from run to run), and only while he is in hitstun: after it the lock fills slower while he moves
## (SwayCaster's moving rate) and his carry, released hold_s later, is hold_s younger then (printed, not gated).
static func _norm(rows: Array) -> Array:
	var out: Array = []
	var f0 := float((rows[0] as Array)[4]) if not rows.is_empty() else 0.0
	for r: Array in rows:
		var q := r.duplicate()
		q[4] = snappedf(float(r[4]) - f0, 1e-9) if bool(r[8]) else -1.0
		out.append(q)
	return out


## [frames the same, the first differing frame and field (-1: none)].
static func _cmp(a: Array, b: Array) -> Array:
	var n := 0
	var first := [-1, -1]
	for i in mini(a.size(), b.size()):
		if a[i] == b[i]:
			n += 1
		elif first[0] < 0:
			for k in (a[i] as Array).size():
				if (a[i] as Array)[k] != (b[i] as Array)[k]:
					first = [i, k]
					print("  (frame %d, field %d: %s / %s)" % [i, k, (a[i] as Array)[k], (b[i] as Array)[k]])
					break
	return [n, first]


func _player_checks() -> void:
	var off := await _player_run(false)
	var on := await _player_run(true)
	var off2 := await _player_run(false)
	var ro := _norm(off[0])
	var rn := _norm(on[0])
	var noise: Array = _cmp(ro, _norm(off2[0]))
	print("  (the feel off twice: %d of %d frames the same)" % [noise[0], ro.size()])
	var c: Array = _cmp(ro, rn)
	var same := int(c[0]) == ro.size() and ro.size() == rn.size()
	var buffered := false
	for r: Array in on[0]:
		buffered = buffered or String(r[6]) == "jump"
	var pt := 0.0
	for i in mini((off[4] as Array).size(), (on[4] as Array).size()):
		pt = maxf(pt, ((off[4] as Array)[i] as Vector3).distance_to((on[4] as Array)[i] as Vector3))
	_expect(int(on[1]) >= 2 and int(off[1]) == 0, "the player struck at %.1f m/s: his pose holds %d frames (hold %.0f ms)"
			% [float(on[3]), on[1], float(on[2]) * 1000.0])
	_expect(same and buffered, "his camera's basis, yaw, pitch, aim ray, lock fill (its change from the hit) and state and the buffered jump: identical to the feel off, every frame of %d (first difference %s; the jump buffered %s)"
			% [ro.size(), c[1], buffered])
	var fd := 0.0
	for i in mini((off[0] as Array).size(), (on[0] as Array).size()):
		fd = maxf(fd, absf(float(((off[0] as Array)[i] as Array)[4]) - float(((on[0] as Array)[i] as Array)[4])))
	print("METRIC player_aim_point_max_diff_m=%.3f (the camera's same ray from where it follows his body; not gated)" % pt)
	print("METRIC player_lock_fill_after_stun_max_diff=%.4f (the lock fills slower while he moves; his carry is hold_s younger; not gated)" % fd)
	_metric("player_cam_aim_lock_unchanged_ok", same and buffered)


# ---------------------------------------------------------------- the hitter
func _hitter_checks() -> void:
	BendImpact.enabled_override = true
	var res := []
	for gap: float in [2.0, 10.0]:
		await _fresh(-gap * 0.5, gap * 0.5)
		var f := foe()
		rules.reset_pct(f, 120.0)
		var info := {"tag": "stone_form/spike", "from": player.global_position}
		var n0 := BendImpact.hitter_holds
		BendStatus.hurt(f, 10.0, f.global_position + Vector3.UP, _way(), player, -1.0, info)
		BendStatus.knock(f, _way() * 6.0, player, info)
		res.append([BendImpact.held(player), BendImpact.hitter_holds - n0, BendImpact.held(f)])
		await _until(func() -> bool: return f.is_on_floor() and not BendKnock.of(f).is_launched(), 4.0)
	_expect(bool(res[0][0]) and int(res[0][1]) == 1 and bool(res[0][2]) and not bool(res[1][0]) and int(res[1][1]) == 0 and bool(res[1][2]),
			"the hitter's pose holds from 2 m (%s), not from 10 m (%s); the struck one's in both" % [res[0], res[1]])


# ---------------------------------------------------------------- PERCENT's in-engine KO check
func _trial(tag: String, pct: float) -> bool:
	await _fresh(-8.0, 0.0, 5.0)
	var f := foe()
	player.global_position = ring.to_global(Vector3(-8.0, ring.top() + 0.05, 5.0))
	f.global_position = ring.to_global(Vector3(0.0, ring.top() + 0.05, 0.0))
	await _ticks(3)
	rules.reset_pct(f, pct)
	kos.clear()
	var info := {"tag": tag, "from": ring.to_global(Vector3(-8.0, ring.top() + 1.0, 0.0))}
	BendStatus.hurt(f, 10.0, f.global_position + Vector3.UP, _way(), player, -1.0, info)
	BendStatus.knock(f, _way() * 6.0, player, info)
	await _until(func() -> bool: return not kos.is_empty() or (f.is_on_floor() and not BendKnock.of(f).is_launched()
			and BendKnock.of(f).kv.length() < 0.05 and not BendKnock.of(f).pending()), 6.0)
	return not kos.is_empty()


## The lowest % (by trials, 7 halvings of 0-300) at which `tag` from 8 m puts the held water foe at the middle in the water.
func _engine_ko(tag: String) -> float:
	var lo := 0.0
	var hi := 300.0
	for i in 7:
		var mid := (lo + hi) * 0.5
		if await _trial(tag, mid):
			hi = mid
		else:
			lo = mid
	return hi


func _ko_checks() -> void:
	var all := true
	var parts := PackedStringArray()
	for tag: String in KO_CHECK:
		BendImpact.enabled_override = false
		var off := await _engine_ko(tag)
		BendImpact.enabled_override = true
		var on := await _engine_ko(tag)
		# (PERCENT's pairs are the table's, with the bot's recovery; the model's read of them with the hold)
		var pin := float(KO_CHECK[tag][0])
		var pout := float(KO_CHECK[tag][1])
		var mp := RingPredict.ko_pct_el(tag, "water", ring.to_global(Vector3(0.0, ring.top() + 0.05, 0.0)), _way(), 8.0)
		var ok := absf(on - off) <= 2.4
		all = all and ok
		parts.append("%s engine (no recovery) %.1f%% off / %.1f%% on; the model with recovery %.0f%% (pair %d/%d)"
				% [tag, off, on, mp, roundi(pin), roundi(pout)])
		print("METRIC ko_engine_pct %s off=%.1f on=%.1f model_recovery=%.1f" % [tag, off, on, mp])
	_expect(all, "PERCENT's in-engine KO check (the held water foe from the middle, 7 halvings): the same %% with the feel on and off: %s" % "; ".join(parts))
	_metric("ko_calibration_unchanged_ok", all)


# ---------------------------------------------------------------- the jolt
func _jolt_checks() -> void:
	BendImpact.enabled_override = true
	await _fresh(-4.0, 6.0)
	await _secs(0.5)
	var cam := player.camera
	var b0 := cam.global_basis
	var a0 := player.get_aim_point()
	var sh := CameraShake.of(cam)
	sh.jolt(0.35, 0.3, Vector2(0.6, -0.8))
	var moved := 0.0
	var same := true
	for i in 24:
		await process_frame
		moved = maxf(moved, Vector2(cam.h_offset, cam.v_offset).length())
		same = same and cam.global_basis == b0 and player.get_aim_point() == a0
	await _ticks(10)
	var back := cam.h_offset == 0.0 and cam.v_offset == 0.0
	var ok := moved > 0.2 and same and back
	_expect(ok, "a jolt of 0.35 m: the offsets moved %.3f m and came back to 0 (%s); the camera's basis and the aim point bit-identical throughout (%s)"
			% [moved, back, same])
	_metric("jolt_basis_unchanged_ok", ok)


# ---------------------------------------------------------------- the perfect guard's beat
func _perfect_checks() -> void:
	BendImpact.enabled_override = true
	await _fresh(-2.5, 2.5)
	var f := foe()
	var j0 := BendImpact.jolts
	BendZone.report(player, "perfect", "stone", "earth")
	var n := 0
	var both := BendImpact.held(player) and BendImpact.held(f)
	for i in 12:
		await physics_frame
		if BendImpact.held(player) and BendImpact.held(f):
			n += 1
	var jolted := BendImpact.jolts - j0
	await _ticks(5)
	BendZone.report(player, "late", "stone", "earth")
	var late := BendImpact.held(player) or BendImpact.held(f)
	var tps := float(Engine.physics_ticks_per_second)
	print("METRIC perfect_hold_ms=%.0f" % ((n + 1) * 1000.0 / tps))
	var ok := both and absf((n + 1) - BendImpact.num("perfect", "hold_s", 0.07) * tps) <= 1.0 and jolted == 1 and not late
	_expect(ok, "a perfect guard holds both poses %d frames (~0.07 s), the guarder's view jolted (%d); a late one holds nothing (%s)"
			% [n + 1, jolted, late])


## A perfect Catch of a stone shot from 4.1 m, then its E-return: [catch frame, result, return frame, the stone's positions].
func _catch_run(feel: bool) -> Array:
	BendImpact.enabled_override = feel
	Bending.of(player).element = "earth"
	await _fresh(-3.0, 2.0)
	var f := foe()
	var cspec: Dictionary = (SwayMoves.move("stone_catch").bend as Dictionary).catch
	var z := BendZone.make(player, "catch", player.global_position, cspec, BendCaster.of(player).facing())
	var res: Array[String] = z.results
	await _secs(0.1)
	var chest := player.global_position + Vector3.UP * 1.2
	var dir := (chest - NpcSenses.chest_of(f)).normalized()
	BendBolt.launch(f, chest - dir * 4.1, dir, STONE)
	var caught_i := -1
	var ret_i := -1
	var path: Array = []
	for i in 80:
		await physics_frame
		var hs := BendZone.held_stone(player)
		if caught_i < 0 and hs != null:
			caught_i = i
		if caught_i >= 0 and i == caught_i + 12:
			c.guard_override = true
		if caught_i >= 0 and i == caught_i + 14:
			c.guard_override = false
		var fl: GustLift = null
		for l in get_nodes_in_group(GustLift.GROUP):
			if (l as GustLift).phase == GustLift.Phase.FLIGHT:
				fl = l as GustLift
		if fl != null and ret_i < 0:
			ret_i = i
		if fl != null and is_instance_valid(fl.stone):
			path.append(fl.stone.global_position)
		elif hs != null:
			path.append(hs.global_position)
	c.guard_override = false
	return [caught_i, res.duplicate(), ret_i, path]


func _catch_checks() -> void:
	var off := await _catch_run(false)
	var g0 := BendImpact.guard_holds
	var on := await _catch_run(true)
	var beat := BendImpact.guard_holds - g0
	var off2 := await _catch_run(false)
	var noise := 0.0
	for i in mini((off[3] as Array).size(), (off2[3] as Array).size()):
		noise = maxf(noise, ((off[3] as Array)[i] as Vector3).distance_to((off2[3] as Array)[i] as Vector3))
	print("  (the feel off twice: the stone's paths within %.6f m; frames %d / %d, %d / %d)" % [noise, off[0], off2[0], off[2], off2[2]])
	var same := int(off[0]) == int(on[0]) and int(off[2]) == int(on[2]) and int(off2[0]) == int(off[0]) and int(off2[2]) == int(off[2])
	var held_dev := 0.0
	var fly_dev := 0.0
	var held_noise := 0.0
	var fly_noise := 0.0
	var ret := int(off[2])
	for i in mini((off[3] as Array).size(), mini((on[3] as Array).size(), (off2[3] as Array).size())):
		var d := ((off[3] as Array)[i] as Vector3).distance_to((on[3] as Array)[i] as Vector3)
		var dn := ((off[3] as Array)[i] as Vector3).distance_to((off2[3] as Array)[i] as Vector3)
		if d > 0.05 and fly_dev <= 0.05 and i + int(off[0]) >= ret:
			print("  (the flight parts at sample %d: off %s on %s again %s; the foe at %s)" % [i, (off[3] as Array)[i], (on[3] as Array)[i],
					(off2[3] as Array)[i], foe().global_position])
		if i + int(off[0]) < ret:
			held_dev = maxf(held_dev, d)
			held_noise = maxf(held_noise, dn)
		else:
			fly_dev = maxf(fly_dev, d)
			fly_noise = maxf(fly_noise, dn)
	print("METRIC catch_held_dev_m=%.4f (the feel off twice %.4f) catch_flight_dev_m=%.3f (the feel off twice %.3f)"
			% [held_dev, held_noise, fly_dev, fly_noise])
	var ok := same and held_dev <= maxf(held_noise * 2.0, 0.01) and fly_dev <= maxf(fly_noise * 3.0, 0.05) and int(on[0]) >= 0 and int(on[2]) > int(on[0]) \
			and (on[1] as Array).has("perfect") and beat >= 1
	_expect(ok, "a perfect Catch (%s; the beat given %d): caught at frame %d (feel off %d, again %d), sent back at %d (%d, %d); the held stone within %.4f m of the feel off (the feel off twice: %.4f), its flight back within %.3f m (%.3f)"
			% [on[1], beat, on[0], off[0], off2[0], on[2], off[2], off2[2], held_dev, held_noise, fly_dev, fly_noise])
	_metric("catch_unchanged_ok", ok)


# ---------------------------------------------------------------- feel.json enabled false
func _off_checks() -> void:
	BendImpact.enabled_override = false
	await _fresh(-6.0, 0.0)
	var f := foe()
	var j0 := BendImpact.jolts
	var h0 := BendImpact.holds
	_launch12(player, f)
	var pend := BendKnock.of(player).pending() or BendImpact.held(player)
	await _until(func() -> bool: return player.is_on_floor() and not BendKnock.of(player).is_launched(), 3.0)
	var s0 := ring.water.ko_splashes
	var m := RingMoment.current()
	var m0 := m.moments if m != null else 0
	rules._sk(f)["stocks"] = 1
	rules._ko(f)
	await _ticks(10)
	var ok := not pend and BendImpact.holds == h0 and BendImpact.jolts == j0 and not RingMoment.busy() \
			and (m == null or m.moments == m0) and ring.water.ko_splashes == s0 and Engine.time_scale == 1.0
	_expect(ok, "feel.json enabled false: no hold (%s), no jolt, no moment, no KO splash" % pend)
	BendImpact.enabled_override = true
	await _restart()


func _restart() -> void:
	Engine.time_scale = 1.0
	mode.restart()
	await _go_fight()


# ---------------------------------------------------------------- the moment
## The foe's last fall now (one life left, KO): the moment's run.
func _final_ko() -> void:
	await _fresh(-6.0, 0.0)
	var f := foe()
	(f as CharacterBody3D).velocity = Vector3(6.0, -12.0, 0.0)
	rules._sk(f)["stocks"] = 1
	rules._ko(f)


func _moment_checks() -> void:
	BendImpact.enabled_override = true
	var restored := true
	# the whole moment: down to 0.35, back to 1 within 1.0 s real (frames / 60)
	var s0 := ring.water.ko_splashes
	await _final_ko()
	var m := RingMoment.current()
	var busy0 := RingMoment.busy()
	var lo := 1.0
	var frames := 0
	var screen_early := false
	while RingMoment.busy() and frames < 200:
		await process_frame
		frames += 1
		lo = minf(lo, Engine.time_scale)
		screen_early = screen_early or (mode.match_screen != null and bool(mode.match_screen.call(&"is_open")))
	var real := float(frames) / 60.0
	var big := ring.water.ko_splashes == s0 + 1 and is_equal_approx(float(ring.water.last_ko.get("k", 0.0)), 2.0)
	var ok1 := busy0 and absf(lo - 0.35) < 0.01 and real <= 1.0 and Engine.time_scale == 1.0 and big and not screen_early
	_expect(ok1, "a game's last fall: the slow beat (lowest %.3f), back to 1.0 after %.2f s real, the splash twice its size (%s), no screen over it (%s)"
			% [lo, real, big, not screen_early])
	restored = restored and ok1
	await _until(func() -> bool: return mode.phase == "DONE", 6.0)
	_expect(mode.match_screen != null and bool(mode.match_screen.call(&"is_open")), "the match screen opens after the moment")
	await _restart()
	# RingMode.restart mid-moment
	await _final_ko()
	for i in 10:
		await process_frame
	var mid := Engine.time_scale
	mode.restart()
	var after := Engine.time_scale
	var ok2 := mid < 0.9 and after == 1.0 and not RingMoment.busy()
	_expect(ok2, "RingMode.restart mid-moment (time scale %.2f): put back at once (%.2f)" % [mid, after])
	restored = restored and ok2
	await _go_fight()
	# an Esc pause
	await _final_ko()
	for i in 10:
		await process_frame
	mid = Engine.time_scale
	paused = true
	await process_frame
	await process_frame
	after = Engine.time_scale
	paused = false
	var ok3 := mid < 0.9 and after == 1.0 and not RingMoment.busy()
	_expect(ok3, "an Esc pause mid-moment (%.2f): put back (%.2f)" % [mid, after])
	restored = restored and ok3
	await _restart()
	# a second fall during it
	await _final_ko()
	for i in 6:
		await process_frame
	mid = Engine.time_scale
	rules._ko(player)
	after = Engine.time_scale
	await process_frame
	var ok4 := mid < 0.9 and after == 1.0 and Engine.time_scale == 1.0 and not RingMoment.busy()
	_expect(ok4, "a second fall during the moment (%.2f): put back (%.2f), no new one" % [mid, after])
	restored = restored and ok4
	await _restart()
	# every fall that is not the last: the splash and the jolt, play goes on
	await _fresh(-6.0, 0.0)
	var j0 := BendImpact.jolts
	var s1 := ring.water.ko_splashes
	rules._ko(foe())
	await _ticks(3)
	var ok5 := not RingMoment.busy() and Engine.time_scale == 1.0 and ring.water.ko_splashes == s1 + 1 and BendImpact.jolts == j0 + 1
	_expect(ok5, "a fall that is not the last: the splash (%d) and the jolt (%d), no slow beat"
			% [ring.water.ko_splashes - s1, BendImpact.jolts - j0])
	await _restart()
	# the scene's exit mid-moment (into Practice)
	await _final_ko()
	for i in 6:
		await process_frame
	mid = Engine.time_scale
	MatchSetup.kind = "practice"
	change_scene_to_file("res://scenes/ring.tscn")
	await process_frame
	await process_frame
	after = Engine.time_scale
	var ok6 := mid < 0.9 and after == 1.0
	_expect(ok6, "the scene's exit mid-moment (%.2f): put back (%.2f)" % [mid, after])
	restored = restored and ok6
	_metric("timescale_restored_ok", restored)


# ---------------------------------------------------------------- Practice
func _practice_checks() -> void:
	kos.clear()
	var ok := await _scene()
	_expect(ok and mode.practice, "Practice")
	if not ok:
		return
	await _fresh(-3.0, 0.0)
	var f := foe()
	var h0 := BendImpact.holds
	var j0 := BendImpact.jolts
	rules.reset_pct(f, 120.0)
	var info := {"tag": "stone_form/spike", "from": player.global_position}
	BendStatus.hurt(f, 10.0, f.global_position + Vector3.UP, _way(), player, -1.0, info)
	BendStatus.knock(f, _way() * 6.0, player, info)
	var held := BendImpact.holds > h0
	await _until(func() -> bool: return f.is_on_floor() and not BendKnock.of(f).is_launched(), 4.0)
	var m := RingMoment.current()
	var m0 := m.moments if m != null else 0
	rules._ko(f)
	var lo := 1.0
	for i in 30:
		await process_frame
		lo = minf(lo, Engine.time_scale)
	var ok2 := held and lo == 1.0 and (m == null or m.moments == m0) and BendImpact.jolts == j0 and not RingMoment.busy()
	_expect(ok2, "Practice: the hit-stop stays (%s); a fall: no moment (lowest time scale %.2f), no jolt (%d)" % [held, lo, BendImpact.jolts - j0])
	MatchSetup.kind = "match"


# ---------------------------------------------------------------- the gate: the classic ring
func _classic_checks() -> void:
	RingRules.rule_set_override = "classic"
	change_scene_to_file("res://scenes/ring.tscn")
	await process_frame
	kos.clear()
	var ok := await _scene()
	_expect(ok and not RingRules.stock_on(), "the classic ring")
	if not ok:
		return
	var f := foe()
	var h0 := BendImpact.holds
	BendStatus.knock(f, _way() * 8.0 + Vector3.UP * 3.0, player, {})
	var kn := BendKnock.peek(f)
	var none := BendImpact.holds == h0 and (kn == null or not kn.pending()) and not f.has_meta(BendImpact.HOLD_META) \
			and not player.has_meta(BendImpact.HOLD_META)
	await _secs(1.0)
	var cam := player.camera
	var b0 := cam.global_basis
	CameraShake.quake(self, player.global_position, 0.8, 20.0, 0.6)
	var moved := 0.0
	var turned := false
	for i in 20:
		await process_frame
		moved = maxf(moved, Vector2(cam.h_offset, cam.v_offset).length())
		turned = turned or cam.rotation.x != 0.0 or cam.rotation.y != 0.0
	var s0 := ring.water.ko_splashes
	rules.rang_out.emit(f, player)
	var splash := ring.water.ko_splashes == s0 + 1 and not RingMoment.busy() and Engine.time_scale == 1.0
	var ok2 := none and moved > 0.01 and not turned and splash
	_expect(ok2, "the classic ring: a knock holds nothing (%s), a quake jolts the view's offsets (%.3f m) with no turn (%s), a rang_out the KO splash only (%s)"
			% [none, moved, not turned, splash])
	_metric("open_world_unchanged_ok", ok2)
	RingRules.rule_set_override = ""


func _end() -> void:
	Engine.time_scale = 1.0
	paused = false
	BendImpact.enabled_override = null
	BendImpact.jolt_override = null
	MatchSetup.kind = "match"
	RingRules.rule_set_override = ""
	for k: String in ["stun_end_unchanged_ok", "player_cam_aim_lock_unchanged_ok", "ko_calibration_unchanged_ok",
			"catch_unchanged_ok", "jolt_basis_unchanged_ok", "timescale_restored_ok", "open_world_unchanged_ok"]:
		print("METRIC %s=%s" % [k, str(bool(metrics.get(k, false))).to_lower()])
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)
