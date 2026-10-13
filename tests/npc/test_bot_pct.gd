extends SceneTree
## Round 3 BOTS (smash_r3 spec §9, §15): the element bots' mind in the % ring (NpcRingMind), in the ring scene's practice
## with its own bots, the gate turned on by a stand-in RingRules (tests/npc/r3_standins.gd: FakeRules, rule_set "stock") and
## RingPredict stood in by FakePredict (a ballistic launch, the water 6 m down) until PERCENT and MOVE merge:
##   the KO read     the foe (the player) at 150% 2 m from his end: a hard bot of each element picks a killing option in
##                   >= 70% of 20 seeds; at 0% in <= 20%
##   finishers       a killing option x far_finisher_mult from past 15 m, and the bot's keep band brought inside it
##   true strings    every follow-up begun had hitstun_left >= lock + flight - 1/60 (200 hits at random hitstun); none begun
##                   when the foe is free; true_string_only_ok
##   steering        200 launches per preset at 140%: the steer's chance and its right way within 0.1 of bend_ai.json's;
##                   the hard bot's launches end no farther past the lip than the easy bot's (and printed: how much shorter)
##   break out, fall the escape's and the break-fall's chances within 0.1 over 200 launches; the confirm (a string begun) too
##   a safety        a full lock never let go into the foe's spawn safety: held, then called off at hold_max_s; let go once
##                   it ends
##   Patch           only with a fresh pool of 6% or more, the foe 12 m away and not winding up, heal_allowed
##   no velocity     600 frames of NpcBending.tick under the gate (running at an open end, reeling, recovering) never change
##                   the body's velocity (no_velocity_write_ok)
##   the Pop's stone an earth bot holding a stone when its Pop lands begins E (its guard: the throw) at once
##   hit rate        a hard bot keeping off a scripted recovering player (jump, jump, Rise from 6 m out) hits him at most
##                   0.6 of its casts (recovering_player_hit_rate_hard)
## METRIC lines: ko_read_rate_150, ko_read_rate_0, finisher_range_m (median), true_string_only_ok, steer_rate per preset,
## recovering_player_hit_rate_hard, no_velocity_write_ok. Watchdog LIMIT_S; last line "BOT PCT PASSED" / "BOT PCT FAILED".
##   Godot --headless --fixed-fps 60 --path . -s tests/npc/test_bot_pct.gd

const NAME := "BOT PCT"
const LIMIT_S := 380.0
const OWN_CFG := "user://test_bot_pct.cfg"
const Standins := preload("res://tests/npc/r3_standins.gd")
const FACTION := "ring_team_b"

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var ring: RingArena
var player: FrontierPlayer
var mode: RingMode
var rules: Standins.FakeRules
var predict: Standins.FakePredict
var _seed := 4100


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	seed(1750)
	MatchSetup._aim_help = "strong"
	GameSettings.path = OWN_CFG
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	SwayCaster.free_override = true
	InputSetup.ensure()
	MatchSetup.incoming = true
	MatchSetup.kind = "practice"
	MatchSetup.dummy = "stand"
	MatchSetup.element = "water"
	MatchSetup.foes = ["earth"]
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _end() -> void:
	NpcRingMind.predict_override = null
	Standins.uninstall(rules)
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


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit:
		if cond.call():
			return t
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	return INF


## A point on the deck `s` m from the middle toward end `e` (the deck's top), `z` across.
func at_s(e: int, s: float, z := 0.0) -> Vector3:
	return ring.to_global(Vector3(RingArena.side_sign(e) * s, ring.top() + 0.05, z))


## A bot of `el` at `preset` at `at`, facing the player, its ring callables set, its physics off (its mind called by hand).
func bot(el: String, preset: String, at: Vector3, live := false) -> NpcFighter:
	_seed += 1
	var sq := NpcSquad.spawn(current_scene, FACTION, 1, at, {"element": el, "tactics": "bend", "weapon": "", "sidearm": "",
			"skill": preset, "seed": _seed, "y": ring.deck_y(), "face": player.global_position})
	var f: NpcFighter = sq.members[0] if not sq.members.is_empty() else null
	if f == null:
		return null
	f.no_death = true
	f.flees = false
	f.calm_s = INF
	var b := f.brain.bending
	b.bounds_fn = mode.rules.bounds_fn_for(f)
	b.edge_fn = mode.rules.edge_along
	b._grace_until = 0.0
	f.brain.told(player, player.global_position)
	f.brain.target = player
	f.brain.seen_now = true
	if not live:
		f.set_physics_process(false)
	return f


func free_bot(f: NpcFighter) -> void:
	if f != null and is_instance_valid(f):
		var sq: Node = f.squad
		f.queue_free()
		if sq != null and is_instance_valid(sq):
			sq.queue_free()


func _run() -> void:
	for i in 10:
		await process_frame
	lvl = current_scene as RingLevel
	mode = RingMode.find(self)
	_expect(lvl != null and mode != null, "the ring with a practice")
	if mode == null:
		return _end()
	ring = lvl.ring
	player = lvl.player
	player.no_death = true
	await _until(func() -> bool: return mode.phase == "FIGHT", 10.0)
	mode.rules.live = false                       # (the classic judge off: the stand-in rules are the gate)
	if mode.foe != null:
		mode.foe.held = true
		mode.foe.global_position = ring.global_position + Vector3(0.0, 40.0, 60.0)
	rules = Standins.install_rules()
	predict = Standins.FakePredict.new(ring)
	NpcRingMind.predict_override = predict
	_expect(RingRules.stock_on() and NpcBending.stock(), "the gate on (a stand-in stock RingRules)")
	_ko_read()
	_finishers()
	_strings()
	_victim()
	_safety()
	_patch()
	_no_velocity()
	await _pop_stone()
	await _hit_rate()
	_end()


# ---------------------------------------------------------------- the KO read
func _ko_read() -> void:
	var e := 1 - mode.player_end
	var rates := {}
	for pct: float in [150.0, 0.0]:
		var kills := 0
		var n := 0
		for el: String in Bending.ELEMENTS:
			player.global_position = at_s(e, ring.half_l() - 2.0)
			player.velocity = Vector3.ZERO
			rules.f_pct[player.get_instance_id()] = pct
			var f := bot(el, "hard", at_s(e, ring.half_l() - 10.0, 0.5))
			var b := f.brain.bending
			for s in 20:
				f.rng.seed = 1750 + s * 31
				b._cool.clear()
				b.casts_by.clear()
				var d := b._flat_d(player)
				var o := b._choose(player, d)
				n += 1
				if not o.is_empty() and predict.would_ko(String(o.key), player, f.global_position,
						NpcRingMind.flat_dir(f.global_position, player.global_position)):
					kills += 1
			free_bot(f)
		rates[pct] = float(kills) / maxf(n, 1)
	print("METRIC ko_read_rate_150=%.2f ko_read_rate_0=%.2f" % [rates[150.0], rates[0.0]])
	_expect(float(rates[150.0]) >= 0.7, "the foe at 150%% 2 m from his end: a killing option in %.0f%% of the picks (>= 70%%)" % (100.0 * rates[150.0]))
	_expect(float(rates[0.0]) <= 0.2, "at 0%%: %.0f%% (<= 20%%)" % (100.0 * rates[0.0]))


func _finishers() -> void:
	var e := 1 - mode.player_end
	player.global_position = at_s(e, ring.half_l() - 2.0)
	# (the merge: PERCENT's real classes, with the range falloff: a Punch from 18 m kills only far up the %; 300% kills from
	# both, so the far multiplier is what tells them apart)
	rules.f_pct[player.get_instance_id()] = 300.0
	var f := bot("fire", "hard", at_s(e, ring.half_l() - 12.0))
	var b := f.brain.bending
	var m := b.mind()
	var o := b._option("fire_blast/punch")
	var w_near := m.weight(o, player, 10.0)
	f.global_position = at_s(e, ring.half_l() - 20.0)
	var w_far := m.weight(o, player, 18.0)
	var band := m.keep_band(Vector2(5.0, 11.0))
	var ratio := w_far / maxf(w_near, 1e-6)
	_expect(absf(ratio - NpcRingMind.pnum("far_finisher_mult", 0.6)) < 0.01 and w_near > 1.5,
			"a finisher that kills: x%.2f up close, x%.2f of that from 18 m" % [w_near, ratio])
	_expect(band.y <= NpcRingMind.pnum("far_finisher_m", 15.0), "it walks in: its keep band's far side %.1f m" % band.y)
	# (the finisher's range as it is let go: on_released counts it)
	f.global_position = at_s(e, ring.half_l() - 9.0)
	m.on_released(o, player)
	f.global_position = at_s(e, ring.half_l() - 7.0)
	m.on_released(o, player)
	var fm: Array = m.stats.finisher_m
	fm.sort()
	print("METRIC finisher_range_m=%.1f (median of %d)" % [float(fm[fm.size() / 2]) if not fm.is_empty() else -1.0, fm.size()])
	_expect(not fm.is_empty() and float(fm[fm.size() / 2]) <= 15.0, "its finishers let go within 15 m")
	free_bot(f)


# ---------------------------------------------------------------- strings
func _strings() -> void:
	var e := 1 - mode.player_end
	player.global_position = at_s(e, 4.0)
	rules.f_pct[player.get_instance_id()] = 0.0
	var f := bot("fire", "hard", at_s(e, -3.0))
	var b := f.brain.bending
	var m := b.mind()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1750
	var begun := 0
	var free_begun := 0
	for i in 200:
		b._cancel()
		b._cool.clear()
		m._end_string()
		var hs := rng.randf_range(0.0, 1.2)
		rules.stun_for(player, hs)
		var lead := "fire_kick/kick" if i % 2 == 0 else "fire_kick/high_kick"
		var before := int(m.stats.follow_ups)
		m._on_landed(lead, hs)
		if int(m.stats.follow_ups) > before:
			begun += 1
			if hs < 0.05:
				free_begun += 1
	var ok := int(m.stats.string_false) == 0 and free_begun == 0
	print("METRIC true_string_only_ok=%s (follow-ups %d of 200, margins min %.3f)" % [ok, begun,
			m.string_margins.min() if not m.string_margins.is_empty() else 0.0])
	_expect(ok and begun > 20, "strings only when hitstun_left >= lock + flight - 1/60: %d begun, %d not true" % [begun, int(m.stats.string_false)])
	# (the confirm: a string begun at string_chance)
	var go := 0
	for i in 200:
		m._end_string()
		rules.stun_for(player, 0.0)
		m._on_landed("fire_blast/punch", 0.0)
		if bool(m.string.get("go", false)):
			go += 1
	var want := float(NpcRingMind.pp_of("hard").get("string_chance", 0.85))
	_expect(absf(go / 200.0 - want) <= 0.1, "the confirm at %.2f (bend_ai.json %.2f)" % [go / 200.0, want])
	free_bot(f)


# ---------------------------------------------------------------- as the victim
func _victim() -> void:
	var e := 1 - mode.player_end
	var outs := {}
	for preset: String in ["easy", "normal", "hard"]:
		var f := bot("water", preset, at_s(e, ring.half_l() - 5.0, 1.0))
		var b := f.brain.bending
		var m := b.mind()
		rules.f_pct[f.get_instance_id()] = 140.0
		var out_sum := 0.0
		var v := (ring.axis() * RingArena.side_sign(e)).normalized() * 16.0 + Vector3.UP * 7.0
		for i in 200:
			m._launch = {}
			m._on_me_launched(v.rotated(Vector3.UP, deg_to_rad(float(i % 21) - 10.0)), 0.7, player)
			var di := b.pad().di
			var vv := v.rotated(Vector3.UP, deg_to_rad(float(i % 21) - 10.0))
			var left := Vector3(vv.x, 0.0, vv.z).normalized().rotated(Vector3.UP, PI * 0.5)
			var yaw := deg_to_rad(15.0) * signf(di.dot(left)) if di.length_squared() > 0.01 else 0.0
			var fl := predict.flight(vv.rotated(Vector3.UP, yaw), 0.7, f.global_position, "water")
			var land := f.global_position + Vector3(vv.x, 0.0, vv.z).normalized().rotated(Vector3.UP, yaw) * float(fl.travel_m)
			out_sum += maxf(float(ring.nearest_lip(land).out_m), 0.0)
		var pr := NpcRingMind.pp_of(preset)
		var di_w: Array = pr.get("di", [0.0, 0.0])
		var set_rate := float(m.stats.di_set) / 200.0
		var right_rate := float(m.stats.di_right) / maxf(float(m.stats.di_set), 1.0)
		print("METRIC steer_rate_%s=%.2f right=%.2f break_out=%.2f tech=%.2f" % [preset, set_rate, right_rate,
				float(m.stats.break_rolls) / 200.0, float(m.stats.tech_rolls) / 200.0])
		_expect(absf(set_rate - float(di_w[0])) <= 0.1 and (float(di_w[0]) == 0.0 or absf(right_rate - float(di_w[1])) <= 0.1),
				"%s: it steers %.2f of its launches (%.2f), the right way %.2f (%.2f)" % [preset, set_rate, float(di_w[0]), right_rate, float(di_w[1])])
		_expect(absf(float(m.stats.break_rolls) / 200.0 - float(pr.get("break_out", 0.0))) <= 0.1
				and absf(float(m.stats.tech_rolls) / 200.0 - float(pr.get("tech", 0.0))) <= 0.1,
				"%s: the escape and the break-fall at their chances" % preset)
		outs[preset] = out_sum / 200.0
		free_bot(f)
	var shorter := 1.0 - float(outs.hard) / maxf(float(outs.easy), 0.01)
	print("METRIC steered_out_m easy=%.2f hard=%.2f (hard %.0f%% shorter past the lip)" % [outs.easy, outs.hard, 100.0 * shorter])
	_expect(float(outs.hard) <= float(outs.easy), "the hard bot's launches at 140%% end no farther past the lip than the easy bot's (%.2f vs %.2f m)" % [outs.hard, outs.easy])


# ---------------------------------------------------------------- never into a safety
func _safety() -> void:
	var e := 1 - mode.player_end
	player.global_position = at_s(e, 4.0)
	var f := bot("water", "hard", at_s(e, -4.0))
	var b := f.brain.bending
	var m := b.mind()
	var o := b._option("water_whip/whip")
	rules.f_safe[player.get_instance_id()] = BendStatus.now() + 9.0
	var got := []
	for i in int(3.0 * 60.0):
		var r := m.allow_release(o, 1.0 / 60.0)
		if not r in got:
			got.append(r)
		if r < 0:
			break
	_expect(not 1 in got and -1 in got, "his spawn safety: the full lock held (0), then called off (-1), never let go (%s)" % [got])
	rules.f_safe.erase(player.get_instance_id())
	_expect(m.allow_release(o, 1.0 / 60.0) == 1, "his safety over: let go")
	free_bot(f)


func _patch() -> void:
	var e := 1 - mode.player_end
	var f := bot("earth", "normal", at_s(e, 10.0))
	var m := f.brain.bending.mind()
	var fm := Standins.FakeMoves.put(f, ring, {"pos": f.global_position, "element": "earth"})
	fm.on_deck = true
	var id := f.get_instance_id()
	player.global_position = at_s(e, -6.0)
	rules.f_fresh[id] = 4.0
	var low := m.heal_ok(player)
	rules.f_fresh[id] = 8.0
	var ok := m.heal_ok(player)
	player.global_position = at_s(e, 5.0)
	var close := m.heal_ok(player)
	player.global_position = at_s(e, -6.0)
	rules.f_heal = false
	var barred := m.heal_ok(player)
	rules.f_heal = true
	_expect(not low and ok and not close and not barred,
			"Patch by its rule: fresh 4%% %s, fresh 8%% 16 m away %s, 5 m away %s, not allowed %s" % [low, ok, close, barred])
	var patch := f.brain.bending._option("patch/patch")
	_expect(patch.is_empty() or m.allowed(patch, player) == m.heal_ok(player), "the chooser's Patch follows the rule")
	free_bot(f)


# ---------------------------------------------------------------- no velocity written
func _no_velocity() -> void:
	var e := 1 - mode.player_end
	var f := bot("air", "hard", at_s(e, ring.half_l() - 0.8, 0.0))
	var b := f.brain.bending
	var writes := 0
	var dirs := [ring.axis() * RingArena.side_sign(e), Vector3.UP * -3.0, Vector3(2.0, 1.0, 0.5)]
	for i in 600:
		var v0: Vector3 = (dirs[i % 3] as Vector3).normalized() * 4.0
		f.velocity = v0
		if i == 200:
			rules.stun_for(f, 0.8)
			b.mind()._on_me_launched(v0 * 4.0, 0.8, player)
		if i == 400:
			f.global_position = at_s(e, ring.half_l() + 4.0) + Vector3.DOWN * 2.0
		b.tick(1.0 / 60.0)
		if not f.velocity.is_equal_approx(v0):
			writes += 1
	print("METRIC no_velocity_write_ok=%s (%d of 600 ticks changed it)" % [writes == 0, writes])
	_expect(writes == 0, "under the gate NpcBending.tick never writes the body's velocity (%d)" % writes)
	free_bot(f)


# ---------------------------------------------------------------- the Pop's stone
func _pop_stone() -> void:
	var e := 1 - mode.player_end
	player.global_position = at_s(e, 1.0)
	rules.f_pct[player.get_instance_id()] = 30.0
	var f := bot("earth", "hard", at_s(e, -2.0))
	var b := f.brain.bending
	var m := b.mind()
	var stone := Node3D.new()
	stone.name = "PopStone"
	current_scene.add_child(stone)
	stone.add_to_group(FormStone.GROUP)
	stone.set_meta(&"bend_held_by", f.get_instance_id())
	stone.global_position = f.global_position + Vector3.UP * 1.5
	await _ticks(1)
	var ok_go := false
	for i in 30:
		m._end_string()
		b._cancel()
		b._cool.clear()
		rules.stun_for(player, 0.6)
		m._on_landed("jab/pop", 0.6)
		if b.casting == String(NpcBending.guard_of("earth")[0]):
			ok_go = true
			break
	_expect(ok_go and b._held_stone() != null, "earth: the Pop lands with a stone in hand, E (its guard: the throw) begun at once (%s)" % b.casting)
	b._cancel()
	stone.queue_free()
	free_bot(f)


# ---------------------------------------------------------------- hit rate on a recovering player
func _hit_rate() -> void:
	var e := mode.player_end
	var f := bot("fire", "hard", at_s(e, ring.half_l() - 4.0), true)
	var b := f.brain.bending
	player.set_physics_process(false)
	rules.f_pct[player.get_instance_id()] = 80.0
	var hits := [0]
	var last_hp := [player.health]
	var last_hit := [-INF]
	var casts0 := b.casts
	var t := 0.0
	var dir := (ring.axis() * RingArena.side_sign(e)).normalized()
	# (a scripted way back, the spec's numbers: from 6 m out and 2 m under the lip, drifting in at 4 m/s under gravity 20, a
	# double jump (vy 8) at 0.25 s, the Fountain (4.5 m up in 0.55 s) at 0.85 s, then a helpless fall; again from the start
	# once at the lip or after 2.4 s)
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var ct := 99.0
	while t < 36.0:
		if ct > 2.4 or (pos.x <= 0.3 and ct > 0.9):
			ct = 0.0
			pos = Vector3(6.0, -2.0, 0.0)
			vel = Vector3(-4.0, 0.0, 0.0)
		var dt := 1.0 / 60.0
		var was := ct
		ct += dt
		if was < 0.25 and ct >= 0.25:
			vel.y = 8.0
		if ct >= 0.85 and ct < 1.4:
			vel.y = 4.5 / 0.55
		else:
			vel.y -= 20.0 * dt
		pos += vel * dt
		var p := ring.global_position + dir * (ring.half_l() + pos.x)
		p.y = ring.lip_y() + pos.y
		player.global_position = p
		player.velocity = Vector3(dir.x * vel.x, vel.y, dir.z * vel.x)
		player.health = player.max_health
		await physics_frame
		if player.health < last_hp[0] - 0.01 and BendStatus.now() - float(last_hit[0]) > 0.25:
			hits[0] += 1
			last_hit[0] = BendStatus.now()
		last_hp[0] = player.health
		t += 1.0 / 60.0
	var casts := b.casts - casts0
	var rate := float(hits[0]) / maxf(float(casts), 1.0)
	print("METRIC recovering_player_hit_rate_hard=%.2f (%d hits of %d casts; keep-off casts %d)" % [rate, hits[0], casts,
			int(b.mind().stats.keep_off_casts)])
	_expect(casts >= 4 and rate <= 0.6, "a hard bot keeping off a scripted recovering player hits %.2f of its casts (<= 0.6; %d casts)" % [rate, casts])
	player.set_physics_process(true)
	free_bot(f)
