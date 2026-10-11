extends SceneTree
## Cheese hunt, lens "bots": real % ring matches (scenes/ring.tscn, the default Lives rules, the real bots at a difficulty)
## against a scripted player (cheese_input.gd: ordinary key and mouse inputs; nothing of the game written), seeded runs,
## the numbers per run and summed:
##   zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path <wt> -s tools/ring/cheese/bots/probe_bots.gd -- \
##       strat=expert|idle|perch|hop|crouch|jab pel=earth pfoe=water diff=normal fmt=1v1 seeds=5 from=0 game_s=150 [full=1]
##       [plight=noon] [mates=fire] [film=1 film_s=20 film_after=perch|fight|<s>] [character_look=soft]
## game_s: the seconds of FIGHT each run plays (full=1: to the match's end, game_s the cap). Per run: the player's % dealt and
## taken, falls each way, the enemy bots' falls by themselves, their casts, their time per mind state, their time standing
## still on the deck with nothing begun, time up on a piece, their seen share, the targets the coach gave them.

const Driver := preload("res://tools/ring/cheese/bots/cheese_input.gd")
const OWN_CFG := "user://cheese_bots_probe.cfg"

var args := {}
var strat := "expert"
var pel := "earth"
var pfoe := "water"
var diff := "normal"
var fmt := "1v1"
var seeds := 5
var from := 0
var game_s := 150.0
var full := false
var film := false
var film_s := 20.0
var film_after := "fight"
var rows: Array = []
var mode: RingMode
var player: FrontierPlayer
var sim: Node
var M := {}
var _hooked: RingRules = null


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		if kv.contains("="):
			args[kv.get_slice("=", 0)] = kv.get_slice("=", 1)
	strat = String(args.get("strat", strat))
	pel = String(args.get("pel", pel))
	pfoe = String(args.get("pfoe", pfoe))
	diff = String(args.get("diff", diff))
	fmt = String(args.get("fmt", fmt))
	seeds = int(args.get("seeds", seeds))
	from = int(args.get("from", from))
	game_s = float(args.get("game_s", game_s))
	full = String(args.get("full", "0")) in ["1", "on", "true"]
	film = String(args.get("film", "0")) in ["1", "on", "true"]
	film_s = float(args.get("film_s", film_s))
	film_after = String(args.get("film_after", film_after))
	if film:
		seeds = 1
		# (a film: a normal window that never takes the focus from what the owner has in front)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
		DisplayServer.window_set_title("Cheese hunt (bots): recording, no input needed")
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	InputSetup.ensure()
	KitWords.ensure_guard_action()
	MatchSetup.reload_scheme()
	MatchSetup.set_controls("full")
	MatchSetup._aim_help = "light"
	RingRules.rule_set_override = "stock"
	RingReplay.force = "off" if not film else "off"
	MatchSetup.format = fmt
	MatchSetup.light = String(args.get("plight", "noon"))
	MatchSetup.element = pel
	MatchSetup.foes = pfoe.split(",") if pfoe != "" else []
	MatchSetup.mates = String(args.get("mates", "")).split(",") if String(args.get("mates", "")) != "" else []
	MatchSetup.difficulty = diff
	MatchSetup.games_n = 1
	MatchSetup.kind = "match"
	MatchSetup.incoming = true
	var combos := String(args.get("strats", strat)).split(",").size() * String(args.get("diffs", diff)).split(",").size() \
			* String(args.get("pfoes", pfoe)).split(";").size()
	var cap := (game_s * (4.0 if full else 1.0) + 60.0) * (seeds * combos + 1) + 120.0
	create_timer(cap, true, false, true).timeout.connect(func() -> void:
		print("PROBE watchdog")
		_summary()
		quit(2))
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	for f in 1200:
		await physics_frame
		mode = RingMode.find(self)
		var p0: FrontierPlayer = mode.player if mode != null else null
		if p0 != null and p0.arena_element != "" and mode.rules != null and SwayCaster.of(p0) != null:
			break
	if mode == null or mode.player == null:
		print("PROBE no ring")
		quit(1)
		return
	player = mode.player
	player.ignore_mouse_capture = true
	if film:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		for action in InputMap.get_actions():
			Input.action_release(action)
	print("PROBE ring up: format %s deck %.0f x %.0f pieces %d" % [RingArena.format, mode.ring.half_l() * 2.0,
			mode.ring.half_w() * 2.0, mode.ring.pieces().size()])
	var strats: Array = String(args.get("strats", strat)).split(",")
	var diffs: Array = String(args.get("diffs", diff)).split(",")
	var foes_list: Array = String(args.get("pfoes", pfoe)).split(";")
	for fl: String in foes_list:
		pfoe = fl
		for dd: String in diffs:
			diff = dd
			for sname: String in strats:
				strat = sname
				rows = []
				for i in range(from, from + seeds):
					var r := await _one(i)
					rows.append(r)
					print("PROBE RUN " + JSON.stringify(r))
				_summary()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	quit(0)


func _hook() -> void:
	var r := mode.rules
	if r == _hooked:
		return
	_hooked = r
	r.pct_dealt.connect(func(by: Node, b: Node3D, delta: float) -> void:
		if M.is_empty():
			return
		if by == player and mode.rules.team_of(b) == 1:
			M.p_dealt = float(M.p_dealt) + delta
			M.hits_by_p = int(M.hits_by_p) + 1
		if b == player:
			M.p_taken = float(M.p_taken) + delta
			M.hits_on_p = int(M.hits_on_p) + 1)
	r.ko.connect(func(b: Node3D, by: Node, pct: float, tag: String, _left: int) -> void:
		if M.is_empty():
			return
		var tb := mode.rules.team_of(b)
		if b == player:
			M.p_falls = int(M.p_falls) + 1
			(M.p_fall_pct as Array).append(snappedf(pct, 1.0))
		elif tb == 0:
			M.mate_falls = int(M.mate_falls) + 1
		else:
			M.bot_falls = int(M.bot_falls) + 1
			(M.bot_fall_pct as Array).append(snappedf(pct, 1.0))
			if by == player:
				M.p_kos = int(M.p_kos) + 1
			if by == null or not is_instance_valid(by) or by == b or mode.rules.team_of(by) == tb:
				M.bot_self = int(M.bot_self) + 1
				(M.self_at as Array).append({"t": snappedf(float(M.t), 0.1), "tag": tag, "pct": snappedf(pct, 1.0),
						"at": _local_str(b)})
		M.fall_log.append({"t": snappedf(float(M.t), 0.1), "who": _who(b), "by": _who(by), "tag": tag, "pct": snappedf(pct, 1.0)}))


func _who(n: Variant) -> String:
	if n == null or not is_instance_valid(n):
		return "-"
	if n == player:
		return "P"
	var t := mode.rules.team_of(n as Node)
	var nm := RingMode.name_of(n)
	return ("A" if t == 0 else "B") + ":" + (nm if nm != "" else String((n as Node).name))


func _local_str_v(p: Vector3) -> String:
	var l := mode.ring.to_local(p)
	return "(%.1f, %.1f)" % [l.x, l.z]


func _local_str(b: Node3D) -> String:
	var l := mode.ring.to_local(b.global_position)
	return "(%.1f, %.1f, %.1f)" % [l.x, l.y - mode.ring.top(), l.z]


func _enemy_bots() -> Array[NpcFighter]:
	var out: Array[NpcFighter] = []
	for b in mode.bots():
		if mode.rules.team_of(b) == 1:
			out.append(b)
	return out


func _one(i: int) -> Dictionary:
	seed(1750 + i)
	MatchSetup.element = pel
	MatchSetup.foes = pfoe.split(",") if pfoe != "" else []
	MatchSetup.difficulty = diff
	MatchSetup.games_n = 1
	mode.set(&"_seed", 7300 + 31 * i)
	(mode.get(&"_rng") as RandomNumberGenerator).seed = 7300 + 31 * i
	player.controls = PlayerControls.new(false)
	mode.restart()
	await physics_frame
	_hook()
	player.ignore_mouse_capture = true
	if sim != null and is_instance_valid(sim):
		sim.call(&"_let_go")
		sim.queue_free()
	sim = Driver.new()
	sim.call(&"setup", player, mode, "expert", 9000 + i)
	sim.set(&"strat", strat)
	current_scene.add_child(sim)
	# (the countdown played as it is)
	for f in 600:
		await physics_frame
		if mode.phase == "FIGHT":
			break
	M = {"seed": i, "strat": strat, "el": pel, "foes": ",".join(PackedStringArray(mode.foe_elements)), "mates":
			",".join(PackedStringArray(mode.mate_elements)), "diff": diff, "fmt": fmt, "t": 0.0, "p_dealt": 0.0, "p_taken": 0.0,
			"hits_by_p": 0, "hits_on_p": 0, "p_kos": 0, "p_falls": 0, "bot_falls": 0, "bot_self": 0, "mate_falls": 0,
			"p_fall_pct": [], "bot_fall_pct": [], "self_at": [], "fall_log": []}
	var bots := _enemy_bots()
	var casts0 := {}
	var by0 := {}
	var tin0 := {}
	for b in bots:
		var bd: NpcBending = b.brain.bending
		casts0[b.get_instance_id()] = bd.casts
		by0[b.get_instance_id()] = bd.casts_by.duplicate()
		tin0[b.get_instance_id()] = bd.ring_mind.time_in.duplicate() if bd.ring_mind != null else {}
	var still_s := 0.0
	var piece_s := 0.0
	var seen_s := 0.0
	var on_p_s := 0.0
	var bot_s := 0.0
	var far_s := 0.0
	var d_sum := 0.0
	var dt := 1.0 / Engine.physics_ticks_per_second
	var film_on := false
	var film_t0 := 0.0
	var pos_log: Array = []
	var pstreak := {}
	var pmax := {}
	var sstreak := {}
	var smax := {}
	var bstreak := {}
	var bmax := {}
	var blocked_s := 0.0
	while true:
		await physics_frame
		M.t = float(M.t) + dt
		if mode.phase == "DONE" or (not full and float(M.t) >= game_s) or float(M.t) >= maxf(game_s, 30.0) * (4.0 if full else 1.0):
			break
		if mode.phase != "FIGHT":
			continue
		for b in mode.bots():
			var idb := b.get_instance_id()
			var onp := mode.in_play(b) and mode.ring.floor_at(b.global_position) >= 0.5 and b.global_position.y > mode.ring.top() + 0.4
			var ps := (float(pstreak.get(idb, 0.0)) + dt) if onp else 0.0
			pstreak[idb] = ps
			if ps > float(pmax.get(idb, [0.0])[0]):
				var pcd := mode.ring.piece_at(b.global_position)
				pmax[idb] = [ps, String(pcd.get("id", "?")), _who(b), _local_str(b)]
			var bd0: NpcBending = b.brain.bending
			var st0 := bd0.ring_mind.state if bd0.ring_mind != null else 0
			var vv := b.velocity
			var stl := mode.in_play(b) and Vector2(vv.x, vv.z).length() < 0.3 and bd0.casting == "" and st0 == NpcRingMind.S.NEUTRAL
			var ss := (float(sstreak.get(idb, 0.0)) + dt) if stl else 0.0
			sstreak[idb] = ss
			if ss > float(smax.get(idb, [0.0])[0]):
				smax[idb] = [ss, _who(b), _local_str(b), _who(b.brain.target), b.brain.seen_now]
			# (blocked: a walk order more than 1.2 m off, the body not moving, nothing begun, its feet on something)
			var goal: Variant = b.get(&"_goal")
			var blk: bool = mode.in_play(b) and goal is Vector3 and goal != Vector3.INF and Vector2((goal as Vector3).x - b.global_position.x,
					(goal as Vector3).z - b.global_position.z).length() > 1.2 and Vector2(vv.x, vv.z).length() < 0.3 \
					and bd0.casting == "" and b.is_on_floor()
			var bs := (float(bstreak.get(idb, 0.0)) + dt) if blk else 0.0
			bstreak[idb] = bs
			if blk:
				blocked_s += dt
			if bs > float(bmax.get(idb, [0.0])[0]):
				bmax[idb] = [bs, _who(b), _local_str(b), _who(b.brain.target), NpcRingMind.STATE_NAMES[st0], _local_str_v(goal as Vector3)]
		for b in _enemy_bots():
			if not mode.in_play(b):
				continue
			bot_s += dt
			var bd: NpcBending = b.brain.bending
			var tgt := b.brain.target
			if tgt == player:
				on_p_s += dt
				if b.brain.seen_now:
					seen_s += dt
				d_sum += b.global_position.distance_to(player.global_position) * dt
			var v := b.velocity
			var flat := Vector2(v.x, v.z).length()
			var st := bd.ring_mind.state if bd.ring_mind != null else 0
			if flat < 0.3 and bd.casting == "" and st == NpcRingMind.S.NEUTRAL and b.is_on_floor():
				still_s += dt
			if mode.ring.floor_at(b.global_position) >= 0.5:
				piece_s += dt
		if int(round(float(M.t) * 60.0)) % 60 == 0 and String(args.get("trace", "0")) == "1":
			var prm := RingMoves.of(player)
			var line := "t=%.0f P%s %.0f%% mode=%s off=%s air=%s safe=%.1f" % [float(M.t), _local_str(player), mode.rules.pct_of(player),
					prm.mode if prm != null else "-", prm.off_deck() if prm != null else false, prm.airborne() if prm != null else false,
					minf(mode.rules.safe_until(player) - BendStatus.now(), 99.0)]
			for b in mode.bots():
				var bd2: NpcBending = b.brain.bending
				var g2: Variant = b.get(&"_goal")
				line += " | %s%s %s/%s c=%s act=%s held=%s tg=%s seen=%s goal=%s %.0f%%" % [_who(b), _local_str(b),
						NpcRingMind.STATE_NAMES[bd2.ring_mind.state] if bd2.ring_mind != null else "-", b.brain.state_name(),
						bd2.casting, b.action, b.held, _who(b.brain.target), b.brain.seen_now,
						_local_str_v(g2 as Vector3) if g2 is Vector3 and g2 != Vector3.INF else "-", mode.rules.pct_of(b)]
			print("TRACE " + line)
		if film:
			if not film_on:
				var go := false
				match film_after:
					"fight":
						go = true
					"perch":
						go = bool(sim.call(&"on_perch"))
					_:
						go = float(M.t) >= float(film_after)
				if go:
					film_on = true
					film_t0 = float(M.t)
					print("FILM start frame=%d t=%.2f" % [Engine.get_frames_drawn(), float(M.t)])
			elif float(M.t) - film_t0 >= film_s:
				print("FILM end frame=%d t=%.2f" % [Engine.get_frames_drawn(), float(M.t)])
				break
	M["done"] = mode.phase == "DONE"
	M["winner"] = mode.winner if mode.phase == "DONE" else -9
	M["p_lives"] = mode.rules.stocks_of(player)
	var bl := 0
	for b in _enemy_bots():
		bl += mode.rules.stocks_of(b)
	M["bot_lives"] = bl
	var casts := 0
	var by := {}
	var tin := {}
	for b in _enemy_bots():
		var bd: NpcBending = b.brain.bending
		casts += bd.casts - int(casts0.get(b.get_instance_id(), 0))
		var b0: Dictionary = by0.get(b.get_instance_id(), {})
		for k: String in bd.casts_by:
			var n := int(bd.casts_by[k]) - int(b0.get(k, 0))
			if n > 0:
				by[k] = int(by.get(k, 0)) + n
		if bd.ring_mind != null:
			var t0: Dictionary = tin0.get(b.get_instance_id(), {})
			for k: String in bd.ring_mind.time_in:
				var dd := float(bd.ring_mind.time_in[k]) - float(t0.get(k, 0.0))
				if dd > 0.05:
					tin[k] = snappedf(float(tin.get(k, 0.0)) + dd, 0.1)
	var pm: Array = []
	for k in pmax:
		if float(pmax[k][0]) >= 2.0:
			pm.append([snappedf(float(pmax[k][0]), 0.1), pmax[k][1], pmax[k][2], pmax[k][3]])
	var sm: Array = []
	for k in smax:
		if float(smax[k][0]) >= 2.0:
			sm.append([snappedf(float(smax[k][0]), 0.1), smax[k][1], smax[k][2], smax[k][3], smax[k][4]])
	var bm: Array = []
	for k in bmax:
		if float(bmax[k][0]) >= 1.5:
			bm.append([snappedf(float(bmax[k][0]), 0.1), bmax[k][1], bmax[k][2], bmax[k][3], bmax[k][4], bmax[k][5]])
	M["blocked_streaks"] = bm
	M["blocked_s"] = snappedf(blocked_s, 0.1)
	M["piece_streaks"] = pm
	M["still_streaks"] = sm
	M["bot_casts"] = casts
	M["bot_casts_by"] = by
	M["bot_states"] = tin
	M["bot_still_s"] = snappedf(still_s, 0.1)
	M["bot_piece_s"] = snappedf(piece_s, 0.1)
	M["bot_in_play_s"] = snappedf(bot_s, 0.1)
	M["bot_on_p_s"] = snappedf(on_p_s, 0.1)
	M["bot_seen_p_s"] = snappedf(seen_s, 0.1)
	M["bot_d_to_p"] = snappedf(d_sum / maxf(on_p_s, 0.01), 0.1)
	M["p_dealt"] = snappedf(float(M.p_dealt), 0.1)
	M["p_taken"] = snappedf(float(M.p_taken), 0.1)
	M["t"] = snappedf(float(M.t), 0.1)
	M["casts_p"] = int(sim.get(&"casts"))
	M["clicks_p"] = int(sim.get(&"clicks"))
	M["perch_top_s"] = snappedf(float(sim.get(&"perch_top_s")), 0.1)
	var out := M.duplicate(true)
	M = {}
	return out


func _summary() -> void:
	var n := rows.size()
	if n == 0:
		print("PROBE SUMMARY none")
		return
	var s := {"t": 0.0, "p_dealt": 0.0, "p_taken": 0.0, "p_kos": 0, "p_falls": 0, "bot_falls": 0, "bot_self": 0, "won": 0,
			"done": 0, "bot_casts": 0, "bot_still_s": 0.0, "bot_piece_s": 0.0, "bot_in_play_s": 0.0, "bot_on_p_s": 0.0,
			"bot_seen_p_s": 0.0, "perch_top_s": 0.0, "mate_falls": 0}
	for r: Dictionary in rows:
		for k: String in s:
			if k == "won":
				s.won = int(s.won) + (1 if int(r.get("winner", -9)) == 0 else 0)
			elif k == "done":
				s.done = int(s.done) + (1 if bool(r.get("done", false)) else 0)
			else:
				s[k] = s[k] + r.get(k, 0)
	var t := maxf(float(s.t), 0.01)
	print("PROBE SUMMARY strat=%s el=%s foe=%s diff=%s fmt=%s runs=%d game_s=%.0f | won %d/%d done | p_dealt/s %.2f p_taken/s %.2f | KOs by P %d, P falls %d, bot falls %d (by themselves %d), mate falls %d | bot casts/min %.1f | bot still %.0f%% of in-play, on pieces %.0f%%, seen P %.0f%% of time on P | P on perch %.0f%%" % [
			strat, pel, pfoe, diff, fmt, n, t, int(s.won), int(s.done), float(s.p_dealt) / t, float(s.p_taken) / t, int(s.p_kos),
			int(s.p_falls), int(s.bot_falls), int(s.bot_self), int(s.mate_falls), float(s.bot_casts) / t * 60.0,
			100.0 * float(s.bot_still_s) / maxf(float(s.bot_in_play_s), 0.01), 100.0 * float(s.bot_piece_s) / maxf(float(s.bot_in_play_s), 0.01),
			100.0 * float(s.bot_seen_p_s) / maxf(float(s.bot_on_p_s), 0.01), 100.0 * float(s.perch_top_s) / t])
