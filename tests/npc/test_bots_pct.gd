extends SceneTree
## Round 4 BOTS2: the bots finish the % game (NpcRingMind's air play and shield, data/npc/bend_ai.json pct.air and the
## presets' "air"), in the ring scene's stock match with the real RingRules, RingMoves and RingPredict (no stand-ins):
##   the Slam       a bot of each preset at its end, the player scripted recovering under the lip just out from it (a slow
##                  rise and fall, his double jump and Rise spent): the bot hops at the lip and Slams him down at least once
##                  (key 2's first move begun in the air: "<move>/slam"), each element in turn until it does
##   the air hit    a bot of each preset 4 m from the player standing on the deck: it hops in and lets go of its element's air
##                  close hit (LMB in the air: Stone Knee, Spin Splash, Flare Kick, Whirl: "<jab>/air_hit") at least once
##   the shield     a bot of each preset (water, earth, air in turn) facing a hard fire bot that locks Lightning again and
##                  again: it raises its guard, holds it while the Lightning is held at it (the guard kept up past its window),
##                  drops it once the strike has passed and punishes (an attack begun within its punish window); counted
##                  in its mind's stats (shield_holds, shield_drops, punishes)
##   no self-falls  a normal bot against the match's normal foe, the player out of the rules (the soak's spectate), to the
##                  match's end or SELF_S: self-falls per life <= 0.05 (the soak's per-game gate), every fall into the water
## METRIC lines: slams_<preset>, air_hits_<preset>, shield_holds_<preset> (with the drops and punishes), self_falls_per_life.
## Watchdog LIMIT_S (it counts frames: game seconds under --fixed-fps 60); seed(1750); MatchSetup._aim_help pinned;
## GameSettings.path isolated. Last line "BOTS PCT PASSED" / "BOTS PCT FAILED".
##   Godot --headless --fixed-fps 60 --path . -s tests/npc/test_bots_pct.gd
## The owner's review images (windowed, it draws; a side camera on each moment, the player's own camera untouched):
##   Godot --fixed-fps 60 --resolution 1280x720 --path . -s tests/npc/test_bots_pct.gd -- shots=<dir>
## writes r4_bots2_slam_<preset>[_b].png, r4_bots2_air_hit_<preset>[_b].png, r4_bots2_shield_<preset>[_b].png.

const NAME := "BOTS PCT"
const LIMIT_S := 1100.0
const OWN_CFG := "user://test_bots_pct.cfg"
const PRESETS := ["easy", "normal", "hard"]
## Game seconds a scenario runs for one element before the next is tried (a preset passes on its first success).
const TRY_S := 40.0
const SELF_S := 300.0
const PARK := Vector3(0.0, 60.0, 400.0)

var checks := 0
var fails: Array[String] = []
var lvl: RingLevel
var ring: RingArena
var player: FrontierPlayer
var mode: RingMode
var _seed := 5300
## The review images' folder ("" none: headless) and its side camera.
var shots := ""
var _cam: Camera3D


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	seed(1750)
	MatchSetup._aim_help = "light"
	GameSettings.path = OWN_CFG
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shots="):
			shots = a.substr(6)
			DirAccess.make_dir_recursive_absolute(shots)
	SwayCaster.free_override = true
	InputSetup.ensure()
	MatchSetup.incoming = true
	MatchSetup.kind = "match"
	MatchSetup.element = "water"
	MatchSetup.foes = ["earth"]
	MatchSetup.difficulty = "normal"
	MatchSetup.round_s = 60.0
	MatchSetup.rounds_to_win = 2
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _end() -> void:
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


## A review image (shots= only): a side camera off the line between `a` and `b`, a little above, on their middle (`behind`:
## over `a`'s shoulder toward `b` instead, for two far apart along the deck); `name` and, `later` frames on, `name`_b; the
## player's camera current again after.
func _snap(name: String, a: Node3D, b: Node3D, later := 8, behind := false) -> void:
	if shots == "" or a == null or b == null or not is_instance_valid(a) or not is_instance_valid(b):
		return
	if _cam == null:
		_cam = Camera3D.new()
		_cam.fov = 55.0
		current_scene.add_child(_cam)
	var keep := root.get_viewport().get_camera_3d()
	for k in 2:
		var mid := (a.global_position + b.global_position) * 0.5 + Vector3.UP * 1.0
		var line := b.global_position - a.global_position
		line.y = 0.0
		var side := line.normalized().cross(Vector3.UP) if line.length_squared() > 0.01 else Vector3.RIGHT
		_cam.global_position = mid + side * maxf(6.0, line.length() * 1.1) + Vector3.UP * 1.6
		if behind:
			var back := -line.normalized() if line.length_squared() > 0.01 else Vector3.BACK
			_cam.global_position = a.global_position + back * 3.5 + side * 1.6 + Vector3.UP * 2.4
		_cam.look_at(mid, Vector3.UP)
		_cam.make_current()
		for i in 3:
			RenderingServer.force_draw(true)
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		var nm := name if k == 0 else name + "_b"
		img.save_png(shots.path_join(nm + ".png"))
		print("  wrote %s.png" % nm)
		if k == 0:
			await _ticks(later)
	if keep != null and is_instance_valid(keep):
		keep.make_current()


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


## A live bot of `el` at `preset` at `at` on team `team`, fighting `foe` (its RingMoves on: RingMode.join).
func bot(el: String, preset: String, at: Vector3, foe: Node3D, team := 1) -> NpcFighter:
	_seed += 1
	var sq := NpcSquad.spawn(current_scene, RingMode.FACTIONS[team], 1, at, {"element": el, "tactics": "bend", "weapon": "",
			"sidearm": "", "skill": preset, "seed": _seed, "y": ring.deck_y(), "face": foe.global_position})
	var f: NpcFighter = sq.members[0] if not sq.members.is_empty() else null
	if f == null:
		return null
	f.no_death = true
	f.flees = false
	f.calm_s = INF
	f.set(&"element", el)
	Bending.of(f).element = el
	mode.join(f, team)
	var b := f.brain.bending
	b.bounds_fn = mode.rules.bounds_fn_for(f)
	b.edge_fn = mode.rules.edge_along
	b._grace_until = 0.0
	f.brain.told(foe, foe.global_position)
	f.brain.target = foe
	f.brain.seen_now = true
	return f


func free_bot(f: NpcFighter) -> void:
	if f == null or not is_instance_valid(f):
		return
	var r := mode.rules
	var id := f.get_instance_id()
	if r.state.has(id):
		r.state.erase(id)
	for k in r.state.keys():
		# (a string it began on someone ends after it is gone: its "by" let go first)
		var st: Dictionary = r._sk((r.state[k] as Dictionary).get("body"))
		var sd: Variant = st.get("string")
		if sd is Dictionary and (sd as Dictionary).get("by") == f:
			(sd as Dictionary)["by"] = null
	for t in 2:
		(r.sides[t] as Array).erase(f)
	var sq: Node = f.squad
	f.queue_free()
	if sq != null and is_instance_valid(sq):
		sq.queue_free()


func _run() -> void:
	for i in 10:
		await process_frame
	lvl = current_scene as RingLevel
	mode = RingMode.find(self)
	_expect(lvl != null and mode != null, "the ring with a match")
	if mode == null:
		return _end()
	ring = lvl.ring
	player = lvl.player
	player.no_death = true
	await _until(func() -> bool: return mode.phase == "FIGHT", 12.0)
	_expect(RingRules.stock_on() and NpcBending.stock(), "the stock rules (the % ring) on: the real RingRules")
	if not RingRules.stock_on():
		return _end()
	_park_foe(true)
	player.set_physics_process(false)
	await _slams()
	await _air_hits()
	await _shields()
	await _self_falls()
	_end()


## The match's own foe held far off (the scenarios bring their own bots), or let go again.
func _park_foe(on: bool) -> void:
	var f := mode.foe
	if f == null or not is_instance_valid(f):
		return
	f.held = on
	if on:
		f.global_position = ring.global_position + Vector3(0.0, 40.0, 60.0)


## The player held at `p` (still, free of any knock), his % kept at `pct`.
func _pin(p: Vector3, v := Vector3.ZERO, pct := 60.0) -> void:
	player.global_position = p
	player.velocity = v
	player.health = player.max_health
	var kn := BendKnock.peek(player)
	if kn != null:
		kn.kv = Vector3.ZERO
	var st := mode.rules._sk(player) if mode.rules.has_method(&"_sk") else {}
	if not st.is_empty():
		st["pct"] = pct


# ---------------------------------------------------------------- the Slam on a man under the lip
func _slams() -> void:
	var e := 1 - mode.player_end
	var dir := (ring.axis() * RingArena.side_sign(e)).normalized()
	for preset: String in PRESETS:
		var n := 0
		var tried: Array = []
		for el: String in Bending.ELEMENTS:
			tried.append(el)
			var f := bot(el, preset, at_s(e, ring.half_l() - 3.0, 0.3), player)
			var m := f.brain.bending.mind()
			var t := 0.0
			var ct := 0.0
			while t < TRY_S and int(m.stats.get("slams", 0)) == 0:
				# (his way back, slowed: 0.9-1.4 m out, rising from 2.4 m under the lip to 0.8 under and sinking back, 2.4 s a
				# loop: a man hanging on his Rise's end, the time a Slam needs; then 0.6 s back on the deck 2 m in, so each
				# loop is a new time he is off: the bot's once-a-time roll made again)
				ct = fmod(ct + 1.0 / 60.0, 3.0)
				if ct >= 2.4:
					_pin(at_s(e, ring.half_l() - 2.0, 0.3), Vector3.ZERO, 110.0)
				else:
					var k := absf(ct / 1.2 - 1.0)
					var out := lerpf(0.9, 1.4, k)
					var p := ring.global_position + dir * (ring.half_l() + out)
					p.y = ring.lip_y() - lerpf(0.8, 2.4, k)
					_pin(p, Vector3.UP * (1.0 if ct < 1.2 else -1.0), 110.0)
				await physics_frame
				t += 1.0 / 60.0
				if shots != "" and (f.brain.bending.mode == "slam" and f.brain.bending.fill > 0.8):
					await _snap("r4_bots2_slam_%s" % preset, f, player, 10)
			n = int(m.stats.get("slams", 0))
			var self_out := int(m.stats.get("self_falls", 0))
			print("  %s %s: slams %d, hops at the lip %d, its own falls %d (%.1f s)" % [preset, el, n,
					int(m.stats.get("slam_hops", 0)), self_out, t])
			free_bot(f)
			await _ticks(2)
			if n > 0:
				break
		print("METRIC slams_%s=%d (elements tried %s)" % [preset, n, tried])
		_expect(n >= 1, "%s: a bot Slams a man recovering under the lip (%d; %s)" % [preset, n, tried])


# ---------------------------------------------------------------- the air close hit
func _air_hits() -> void:
	var e := 1 - mode.player_end
	for preset: String in PRESETS:
		var n := 0
		var tried: Array = []
		for el: String in Bending.ELEMENTS:
			tried.append(el)
			var spot := at_s(e, 2.0, 0.0)
			var f := bot(el, preset, at_s(e, 6.0, 0.4), player)
			var b := f.brain.bending
			var m := b.mind()
			var jb := NpcBending.jab_of(el)
			var key := "%s/air_hit" % jb[0]
			var t := 0.0
			while t < TRY_S and int(b.casts_by.get(key, 0)) == 0:
				_pin(spot, Vector3.ZERO, 40.0)
				await physics_frame
				t += 1.0 / 60.0
				if shots != "" and b.mode == "air_hit" and b.fill > 0.8:
					await _snap("r4_bots2_air_hit_%s" % preset, f, player, 8)
			n = int(b.casts_by.get(key, 0))
			print("  %s %s: air hits %d (hops %d, strings into the air %d, %.1f s)" % [preset, el, n, int(m.stats.get("hops", 0)),
					int(m.stats.get("air_follows", 0)), t])
			free_bot(f)
			await _ticks(2)
			if n > 0:
				break
		print("METRIC air_hits_%s=%d (elements tried %s)" % [preset, n, tried])
		_expect(n >= 1, "%s: a bot lets go of its air close hit in the air (%d; %s)" % [preset, n, tried])


# ---------------------------------------------------------------- the held guard: a shield against a held Lightning
func _shields() -> void:
	var e := 1 - mode.player_end
	_pin(PARK)
	for preset: String in PRESETS:
		var holds := 0
		var drops := 0
		var punish := 0
		var tried: Array = []
		for el: String in ["water", "earth", "air"]:
			tried.append(el)
			var v := bot(el, preset, at_s(e, 3.0, 0.0), player, 1)
			var a := bot("fire", "hard", at_s(e, -9.0, 0.0), v, 0)
			v.brain.told(a, a.global_position)
			v.brain.target = a
			var vb := v.brain.bending
			var ab := a.brain.bending
			var m := vb.mind()
			var t := 0.0
			var lat := 0
			while t < TRY_S * 1.6 and (int(m.stats.get("shield_holds", 0)) == 0 or int(m.stats.get("punishes", 0)) == 0):
				if ab.casting == "" and ab._follow <= 0.0:
					ab._next["fire_arc/lightning"] = 0.0
					ab._cool.erase("fire_arc/lightning")
				# (both kept on the deck and apart: the scenario is the shield, not the fall)
				for f: NpcFighter in [v, a]:
					var rm := RingMoves.of(f)
					if rm != null and rm.off_deck():
						f.global_position = at_s(e, 3.0 if f == v else -9.0, 0.0)
						f.velocity = Vector3.ZERO
				await physics_frame
				t += 1.0 / 60.0
				if shots != "" and m.shield.get("zone") != null and ab.casting == "fire_arc" and ab.fill > 0.85:
					await _snap("r4_bots2_shield_%s" % preset, v, a, 20, true)
			holds = int(m.stats.get("shield_holds", 0))
			drops = int(m.stats.get("shield_drops", 0))
			punish = int(m.stats.get("punishes", 0))
			lat = vb.lates
			print("  %s %s: shield holds %d, drops %d, punishes %d, late takes %d, lightning casts %d (%.1f s)" % [preset, el, holds,
					drops, punish, lat, int(ab.casts_by.get("fire_arc/lightning", 0)), t])
			free_bot(a)
			free_bot(v)
			await _ticks(2)
			if holds > 0 and punish > 0:
				break
		print("METRIC shield_holds_%s=%d drops=%d punishes=%d (elements tried %s)" % [preset, holds, drops, punish, tried])
		_expect(holds >= 1 and drops >= 1, "%s: a bot holds its guard up against a held Lightning and drops it after (%d held, %d dropped; %s)"
				% [preset, holds, drops, tried])
		_expect(punish >= 1, "%s: and punishes after it drops it (%d)" % [preset, punish])


# ---------------------------------------------------------------- no self-falls (the soak's per-game gate)
func _self_falls() -> void:
	# (the soak's spectate: the player out of the rules and parked; a normal bot of his element against the match's foe)
	var r := mode.rules
	var pid := player.get_instance_id()
	if r.state.has(pid):
		r.state.erase(pid)
	(r.sides[0] as Array).erase(player)
	player.is_dead = true
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = PARK
	var foe := mode.foe
	_park_foe(false)
	foe.global_position = at_s(1 - mode.player_end, 8.0)
	var mate := bot("water", "normal", at_s(mode.player_end, 8.0), foe, 0)
	foe.brain.told(mate, mate.global_position)
	foe.brain.target = mate
	var falls := [0]
	var selfs := [0]
	var water := [0]
	var cb := func(b: Node3D, by: Node, _pct: float, _tag: String, _left: int) -> void:
		if b != mate and b != foe:
			return
		falls[0] += 1
		if by == null or by == b or r.team_of(by) == r.team_of(b):
			selfs[0] += 1
		var at := b.global_position
		if not r.falls.is_empty() and (r.falls.back() as Dictionary).get("who") == b:
			at = (r.falls.back() as Dictionary).get("pos", at)
		if ring.is_out(at) or at.y < ring.lip_y() - 1.0:
			water[0] += 1
	r.ko.connect(cb)
	mode.phase_t = 0.0                            # (the match's clock from the top: the scenarios before spent some of it)
	var t := 0.0
	while t < SELF_S and mode.phase != "DONE":
		await physics_frame
		t += 1.0 / 60.0
	r.ko.disconnect(cb)
	var per := float(selfs[0]) / maxf(float(falls[0]), 1.0)
	print("METRIC self_falls_per_life=%.3f (%d of %d falls, %.0f s, phase %s)" % [per, selfs[0], falls[0], t, mode.phase])
	for f: Variant in [mate, foe]:
		if f != null and is_instance_valid(f) and (f as NpcFighter).brain.bending.ring_mind != null:
			var ms: Dictionary = (f as NpcFighter).brain.bending.ring_mind.stats
			print("  %s: casts %d, air casts %d, hops %d, air hits %d, slams %d, shield holds %d, follow-ups %d" % [
					"the mate" if f == mate else "the foe", int(ms.get("casts_all", 0)), int(ms.get("air_casts", 0)),
					int(ms.get("hops", 0)), int(ms.get("air_hits", 0)), int(ms.get("slams", 0)), int(ms.get("shield_holds", 0)),
					int(ms.get("follow_ups", 0))])
	_expect(falls[0] >= 1, "the bots' game has falls (%d)" % falls[0])
	_expect(per <= 0.05 + 1e-6 or falls[0] < 4, "self-falls per life %.3f (<= 0.05)" % per)
	_expect(water[0] == falls[0], "every fall into the water (%d of %d)" % [water[0], falls[0]])
