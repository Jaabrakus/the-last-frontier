extends SceneTree
## Cheese hunt, lens "team": GANG-UPS. Real matches (scenes/ring.tscn, Lives rules, the real bots and their team coach), and
## for every fighter every physics frame whether he is in hitstun (RingRules.stunned): his hit-lock streaks (seconds with no
## free frame), the hits and the distinct attackers in each, the free windows between; the life lengths; the % he takes per
## second while two or more foes are hitting him (each landed within the last 2 s) against one. Nothing is written into the
## match.
##   way=bots   the player parked off the deck and a bot of his element in his slot (as tests/ring/test_team_formats.gd)
##   way=deck | focus   the player played by team_driver.gd (the expert input model; focus: always his team-mate's target)
##   zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . -s tools/ring/cheese/team/team_gang.gd -- \
##       format=4v4 way=bots s0=1 n=1 [difficulty=normal] [el=earth] [out=<jsonl>]
## Prints "GANG {json}" per game and "GANG DONE".

const Driver := preload("res://tools/ring/cheese/team/team_driver.gd")
const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
const OWN_CFG := "user://cheese_team_gang.cfg"
const PARK := Vector3(0.0, 60.0, 400.0)
const GANG_S := 2.0

var a := {}
var fmt := "4v4"
var way := "bots"
var mode: RingMode
var player: FrontierPlayer
var lvl: RingLevel
var sim: Node
var mate: NpcFighter
var mate_squad: NpcSquad
var g := {}
## per body id: {streak_s, hits, by: {}, free_s, life_t, last: {attacker id -> fight time of his last landed hit}}
var bk := {}
var _t0 := 0


func _initialize() -> void:
	_t0 = Time.get_ticks_msec()
	a = CaptureKit.args({"format": "4v4", "way": "bots", "el": "earth", "s0": "1", "n": "1", "difficulty": "normal",
			"foes": "any", "mates": "", "aim": "light", "out": "", "limit_s": "900", "max_s": "700"})
	fmt = String(a.format) if String(a.format) in MatchSetup.FORMATS else "4v4"
	way = String(a.way)
	create_timer(float(a.limit_s), true, false, true).timeout.connect(func() -> void:
		print("GANG WATCHDOG")
		_quit(2))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = OWN_CFG
	SwayCaster.free_override = way == "bots"
	InputSetup.ensure()
	KitWords.ensure_guard_action()
	MatchSetup.reload_scheme()
	MatchSetup.set_controls("full")
	MatchSetup._aim_help = String(a.aim)
	MatchSetup.incoming = true
	MatchSetup.set_match()
	MatchSetup.format = fmt
	MatchSetup.element = String(a.el)
	MatchSetup.foes = Array(String(a.foes).split(",", false))
	MatchSetup.mates = Array(String(a.mates).split(",", false))
	MatchSetup.difficulty = String(a.difficulty)
	MatchSetup.games_n = 1
	RingRules.rule_set_override = "stock"
	RingReplay.force = "off"
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _run() -> void:
	for f in 1800:
		await physics_frame
		mode = RingMode.find(self)
		var p0: FrontierPlayer = mode.player if mode != null else null
		if p0 != null and p0.arena_element != "" and mode.rules != null and SwayCaster.of(p0) != null:
			break
	if mode == null or mode.player == null:
		print("GANG FAILED: no ring")
		return _quit(1)
	lvl = current_scene as RingLevel
	player = mode.player
	player.controls = PlayerControls.new(false)
	player.ignore_mouse_capture = true
	mode.rules.ko.connect(_on_ko)
	mode.rules.launched.connect(_on_launched)
	mode.rules.respawned.connect(_on_respawned)
	mode.rules.pct_changed.connect(_on_pct)
	if way == "bots":
		mode.phase_changed.connect(_on_phase)
	for k in int(a.n):
		var sd := int(a.s0) + k
		mode.set(&"_seed", 7300 + 31 * sd)
		(mode.get(&"_rng") as RandomNumberGenerator).seed = 7300 + 31 * sd
		mode.restart()
		await physics_frame
		if way != "bots":
			sim = Driver.new()
			sim.call(&"setup", player, mode, "expert", 9000 + sd)
			sim.set(&"camera_aim", true)
			sim.set(&"way", way)
			current_scene.add_child(sim)
		await _game(sd)
		if sim != null and is_instance_valid(sim):
			sim.call(&"_let_go")
			sim.queue_free()
			sim = null
		await physics_frame
	print("GANG DONE wall_s=%.0f" % ((Time.get_ticks_msec() - _t0) / 1000.0))
	_quit(0)


func _game(sd: int) -> void:
	bk = {}
	g = {"seed": sd, "format": fmt, "way": way, "difficulty": String(a.difficulty), "fight_s": 0.0,
			"mates": mode.mate_elements.duplicate(), "foes": mode.foe_elements.duplicate(),
			"streaks": [], "lives": [], "stun_s": [0.0, 0.0], "pct_gang": 0.0, "s_gang": 0.0, "pct_solo": 0.0, "s_solo": 0.0,
			"pct_player": 0.0, "p_stun_s": 0.0, "p_kos": 0, "falls": [], "blocked_s": 0.0, "blocked_piece_s": 0.0,
			"blocked_piece_run_max": 0.0, "bot_s": 0.0}
	var dt := 1.0 / Engine.physics_ticks_per_second
	var game_t := 0.0
	var wall_t := 0.0
	g["walls_max"] = [0, 0]
	g["wall_cover_max_m"] = [0.0, 0.0]
	while mode.phase != "DONE" and game_t < 760.0 and float(g.fight_s) < float(a.max_s):
		await physics_frame
		game_t += dt
		if way == "bots" and player.global_position.distance_to(PARK) > 1.0:
			player.global_position = PARK
			player.velocity = Vector3.ZERO
		if mode.phase != "FIGHT":
			continue
		g.fight_s += dt
		wall_t -= dt
		if wall_t <= 0.0:
			wall_t = 0.25
			_walls()
		var now := float(g.fight_s)
		for b in mode.competitors():
			if not is_instance_valid(b) or not mode.in_play(b):
				continue
			var id := (b as Node).get_instance_id()
			var e: Dictionary = bk.get(id, {})
			if e.is_empty():
				e = {"streak_s": 0.0, "hits": 0, "by": {}, "life_t": now, "last": {}, "side": mode.rules.team_of(b)}
				bk[id] = e
			var stun := mode.rules.stunned(b)
			# (a bot that wants to walk and cannot: its pad's way held, its feet on the floor, no hitstun, under 0.5 m/s)
			if b is NpcFighter and (b as NpcFighter).pad != null and not stun and (b as NpcFighter).is_on_floor():
				var nf := b as NpcFighter
				var hv := Vector2(nf.velocity.x, nf.velocity.z).length()
				var bend: Variant = nf.brain.bending if nf.brain != null else null
				var casting := bend != null and String((bend as Object).get(&"casting")) != ""
				if nf.pad.move.length() > 0.5 and hv < 0.5 and not casting:
					g.blocked_s += dt
					var at_piece := not mode.ring.piece_at(nf.global_position, 1.0).is_empty()
					if at_piece:
						g.blocked_piece_s += dt
						e["bp_run"] = float(e.get("bp_run", 0.0)) + dt
						g.blocked_piece_run_max = maxf(float(g.blocked_piece_run_max), float(e.bp_run))
					else:
						e["bp_run"] = 0.0
				else:
					e["bp_run"] = 0.0
				g.bot_s += dt
			if stun:
				e.streak_s = float(e.streak_s) + dt
				(g.stun_s as Array)[int(e.side)] = float((g.stun_s as Array)[int(e.side)]) + dt
				if b == player:
					g.p_stun_s += dt
			elif float(e.streak_s) > 0.0:
				_close(e)
			# (the foes hitting him: each with a hit landed in the last GANG_S)
			var n := 0
			for at: Variant in (e.last as Dictionary).values():
				if now - float(at) <= GANG_S:
					n += 1
			if n >= 2:
				g.s_gang += dt
			elif n == 1:
				g.s_solo += dt
			e["n_on"] = n
	for e: Dictionary in bk.values():
		if float(e.streak_s) > 0.0:
			_close(e)
	var st: Array = g.streaks
	var longest := 0.0
	var ge2 := 0
	var ge3 := 0
	var multi := 0
	for s: Dictionary in st:
		longest = maxf(longest, float(s.s))
		ge2 += 1 if float(s.s) >= 2.0 else 0
		ge3 += 1 if float(s.s) >= 3.0 else 0
		multi += 1 if int(s.by) >= 2 else 0
	g["streak_n"] = st.size()
	g["streak_longest_s"] = snappedf(longest, 0.01)
	g["streak_ge2"] = ge2
	g["streak_ge3"] = ge3
	g["streak_multi"] = multi
	var top: Array = st.duplicate()
	top.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.s) > float(y.s))
	g["streak_top"] = top.slice(0, 5)
	g.erase("streaks")
	var lv: Array = g.lives
	var ls := 0.0
	for x: float in lv:
		ls += x
	g["life_mean_s"] = snappedf(ls / maxf(lv.size(), 1.0), 0.1)
	var srt: Array = lv.duplicate()
	srt.sort()
	g["life_min_s"] = snappedf(float(srt[0]), 0.1) if not srt.is_empty() else -1.0
	g["life_lt20"] = srt.filter(func(x: float) -> bool: return x < 20.0).size()
	g["life_lt40"] = srt.filter(func(x: float) -> bool: return x < 40.0).size()
	g["life_n"] = lv.size()
	g.erase("lives")
	g["pct_per_s_gang"] = snappedf(float(g.pct_gang) / maxf(float(g.s_gang), 0.01), 0.01)
	g["pct_per_s_solo"] = snappedf(float(g.pct_solo) / maxf(float(g.s_solo), 0.01), 0.01)
	g["winner"] = mode.winner
	g["why"] = mode.last_why
	g["end_at_s"] = float((mode.history.back() as Dictionary).get("at_s", -1.0)) if not mode.history.is_empty() else -1.0
	g["lives_end"] = (mode.history.back() as Dictionary).get("lives", []) if not mode.history.is_empty() else []
	for k: String in ["fight_s", "pct_gang", "s_gang", "pct_solo", "s_solo", "pct_player", "p_stun_s", "blocked_s",
			"blocked_piece_s", "blocked_piece_run_max", "bot_s"]:
		g[k] = snappedf(float(g[k]), 0.1)
	g["stun_s"] = [snappedf(float(g.stun_s[0]), 0.1), snappedf(float(g.stun_s[1]), 0.1)]
	var line := JSON.stringify(g)
	print("GANG " + line)
	var out := String(a.out)
	if out != "":
		var f := FileAccess.open(out, FileAccess.READ_WRITE) if FileAccess.file_exists(out) else FileAccess.open(out, FileAccess.WRITE)
		if f != null:
			f.seek_end()
			f.store_line(line)
			f.close()


## The walls (key 4's earth and ice walls: FormRaised kind "wall", standing) of each side now: the most at once, and the
## most metres of the deck's width they cover together (their spans across the deck, joined; an upper bound of a barrier).
func _walls() -> void:
	var per: Array = [[], []]
	var cnt := [0, 0]
	for n in get_nodes_in_group(FormRaised.GROUP):
		var w := n as FormRaised
		if w == null or w.kind != "wall" or w.state == FormRaised.State.CRUMBLING or not w.has_meta(&"bend_by"):
			continue
		var by: Object = instance_from_id(int(w.get_meta(&"bend_by")))
		if by == null or not is_instance_valid(by) or not (by is Node):
			continue
		var t := mode.rules.team_of(by as Node)
		if t < 0:
			continue
		cnt[t] += 1
		var half := w.base.basis.x.normalized() * w.size.x * 0.5
		var pa := mode.ring.to_local(w.base.origin - half)
		var pb := mode.ring.to_local(w.base.origin + half)
		(per[t] as Array).append(Vector2(minf(pa.z, pb.z), maxf(pa.z, pb.z)))
	for t in 2:
		(g.walls_max as Array)[t] = maxi(int((g.walls_max as Array)[t]), int(cnt[t]))
		var iv: Array = per[t]
		iv.sort_custom(func(x: Vector2, y: Vector2) -> bool: return x.x < y.x)
		var cov := 0.0
		var cur := Vector2(INF, -INF)
		for v: Vector2 in iv:
			if v.x > cur.y:
				if cur.y > cur.x:
					cov += cur.y - cur.x
				cur = v
			else:
				cur.y = maxf(cur.y, v.y)
		if cur.y > cur.x:
			cov += cur.y - cur.x
		(g.wall_cover_max_m as Array)[t] = maxf(float((g.wall_cover_max_m as Array)[t]), snappedf(cov, 0.1))


func _close(e: Dictionary) -> void:
	(g.streaks as Array).append({"s": snappedf(float(e.streak_s), 0.01), "hits": int(e.hits), "by": (e.by as Dictionary).size(),
			"side": int(e.side)})
	e.streak_s = 0.0
	e.hits = 0
	e.by = {}


func _on_launched(b: Node3D, _v: Vector3, _hs: float, by: Node, _tag: String) -> void:
	if g.is_empty() or b == null or not is_instance_valid(b):
		return
	var e: Dictionary = bk.get(b.get_instance_id(), {})
	if e.is_empty():
		return
	e.hits = int(e.hits) + 1
	if by != null and is_instance_valid(by) and by != b:
		(e.by as Dictionary)[by.get_instance_id()] = true
		(e.last as Dictionary)[by.get_instance_id()] = float(g.fight_s)
		if by == player:
			pass


func _on_pct(b: Node3D, _pct: float, delta: float) -> void:
	if g.is_empty() or delta <= 0.0 or mode.phase != "FIGHT":
		return
	var e: Dictionary = bk.get(b.get_instance_id(), {})
	if e.is_empty():
		return
	var n := int(e.get("n_on", 0))
	# (the hit that brought this % counts its own attacker too: launched comes first, so n is up to date next frame; count
	# it by the attackers whose last hit is within GANG_S now)
	var now := float(g.fight_s)
	n = 0
	for at: Variant in (e.last as Dictionary).values():
		if now - float(at) <= GANG_S:
			n += 1
	if n >= 2:
		g.pct_gang += delta
	else:
		g.pct_solo += delta
	if b == player:
		g.pct_player += delta


func _on_respawned(b: Node3D) -> void:
	var e: Dictionary = bk.get(b.get_instance_id(), {})
	if not e.is_empty():
		e.life_t = float(g.get("fight_s", 0.0))
		e.last = {}


func _on_ko(b: Node3D, by: Node, pct: float, tag: String, left: int) -> void:
	if g.is_empty():
		return
	var e: Dictionary = bk.get(b.get_instance_id(), {})
	if not e.is_empty():
		(g.lives as Array).append(float(g.fight_s) - float(e.life_t))
		if float(e.streak_s) > 0.0:
			_close(e)
		e.last = {}
	if by == player:
		g.p_kos += 1
	(g.falls as Array).append({"t": snappedf(float(g.fight_s), 0.1), "side": mode.rules.team_of(b), "pct": snappedf(pct, 1.0),
			"by_side": mode.rules.team_of(by) if by != null and is_instance_valid(by) else -1, "tag": tag, "left": left,
			"player": b == player})


# ---------------------------------------------------------------- bots only (tests/ring/test_team_formats.gd's spectate)
func _on_phase(ph: String) -> void:
	match ph:
		"COUNTDOWN":
			_spectate()
		"FIGHT":
			if mate != null and is_instance_valid(mate):
				mate.held = false


func _spectate() -> void:
	var rules := mode.rules
	var pid := player.get_instance_id()
	if rules.state.has(pid):
		rules.state.erase(pid)
	(rules.sides[0] as Array).erase(player)
	player.is_dead = true
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = PARK
	if mate_squad != null and is_instance_valid(mate_squad):
		mate_squad.get_parent().remove_child(mate_squad)
		mate_squad.queue_free()
	var ring := mode.ring
	var xf := ring.spawn(mode.player_end, 0)
	var opts := {"face": xf.origin - xf.basis.z * 10.0, "tag": "ring", "tactics": "bend", "element": mode.element,
			"weapon": "", "sidearm": "", "skill": mode.difficulty, "seed": int(mode.get(&"_seed")) + mode.round * 13, "y": ring.deck_y()}
	mate_squad = NpcSquad.spawn(lvl, RingMode.FACTIONS[0], 1, xf.origin, opts)
	mate = mate_squad.members[0] if mate_squad != null and not mate_squad.members.is_empty() else null
	if mate == null:
		return
	mate.flees = false
	mate.calm_s = INF
	mate.held = true
	mate.no_death = true
	mate.set(&"element", mode.element)
	Bending.of(mate).element = mode.element
	mode.join(mate, 0)
	var bend := mate.brain.bending
	if bend != null:
		bend.bounds_fn = rules.bounds_fn_for(mate)
		bend.edge_fn = rules.edge_along


func _quit(code: int) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	RingReplay.force = ""
	RingRules.rule_set_override = ""
	SwayCaster.free_override = false
	quit(code)
