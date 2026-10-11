extends SceneTree
## Cheese hunt, lens "team" (2v2 / 4v4 only). A real team match (scenes/ring.tscn, the default Lives rules, the real bots of
## both sides under their team coach); the player is played by team_driver.gd (the film's expert input model: key and mouse
## actions only) in one WAY (see team_driver.gd: deck = the baseline, perch, perch_idle, hide, focus). Nothing of the match is
## written: no damage, launch or result is injected. One or more games a run, each from a restart with its own seed.
##   zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . -s tools/ring/cheese/team/team_probe.gd -- \
##       format=2v2 way=perch el=earth s0=1 n=2 [difficulty=normal] [foes=any] [mates=] [aim=light] [out=<jsonl>]
##   film=1 (windowed, the game's own camera and HUD): plays until the cheese shows, prints "FILM MARK <movie s>", then
##   film_s more seconds and quits.
## Prints a "TEAMPROBE {json}" line per game and "TEAMPROBE DONE".

const Driver := preload("res://tools/ring/cheese/team/team_driver.gd")
const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
const OWN_CFG := "user://cheese_team_probe.cfg"

var a := {}
var fmt := "2v2"
var way := "deck"
var n := 1
var s0 := 1
var film := false
var film_s := 20.0
var out := ""
var mode: RingMode
var player: FrontierPlayer
var sim: Node
var g := {}
var _t0 := 0


func _initialize() -> void:
	_t0 = Time.get_ticks_msec()
	a = CaptureKit.args({"format": "2v2", "way": "deck", "el": "earth", "s0": "1", "n": "1", "difficulty": "normal",
			"foes": "any", "mates": "", "aim": "light", "film": "0", "film_s": "20", "out": "", "limit_s": "900",
			"max_s": "700", "dbg": "0", "driver": "res://tools/ring/cheese/team/team_driver.gd"})
	fmt = String(a.format) if String(a.format) in ["2v2", "4v4"] else "2v2"
	way = String(a.way)
	n = maxi(int(a.n), 1)
	s0 = int(a.s0)
	film = String(a.film) == "1"
	film_s = float(a.film_s)
	out = String(a.out)
	create_timer(float(a.limit_s), true, false, true).timeout.connect(func() -> void:
		print("TEAMPROBE WATCHDOG")
		_quit(2))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = OWN_CFG
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
	MatchSetup.light = "noon"
	RingRules.rule_set_override = "stock"
	RingReplay.force = "off"
	if film:
		CaptureKit.window()
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _run() -> void:
	for f in 1800:
		await physics_frame
		mode = RingMode.find(self)
		var p0: FrontierPlayer = mode.player if mode != null else null
		if p0 != null and p0.arena_element != "" and mode.rules != null and SwayCaster.of(p0) != null \
				and not LoadingScreen.covering():
			break
	if mode == null or mode.player == null:
		print("TEAMPROBE FAILED: no ring")
		return _quit(1)
	player = mode.player
	player.controls = PlayerControls.new(false)
	player.ignore_mouse_capture = true
	var rules := mode.rules
	rules.ko.connect(_on_ko)
	rules.pct_changed.connect(_on_pct)
	rules.pct_dealt.connect(_on_dealt)
	rules.launched.connect(_on_launched)
	for k in n:
		var sd := s0 + k
		mode.set(&"_seed", 7300 + 31 * sd)
		(mode.get(&"_rng") as RandomNumberGenerator).seed = 7300 + 31 * sd
		mode.restart()
		await physics_frame
		sim = (load(String(a.driver)) as Script).new()
		sim.call(&"setup", player, mode, "expert", 9000 + sd)
		sim.set(&"camera_aim", true)
		sim.set(&"way", way)
		current_scene.add_child(sim)
		await _game(sd)
		sim.call(&"_let_go")
		sim.queue_free()
		await physics_frame
	print("TEAMPROBE DONE wall_s=%.0f" % ((Time.get_ticks_msec() - _t0) / 1000.0))
	_quit(0)


func _game(sd: int) -> void:
	g = {"seed": sd, "format": fmt, "way": way, "el": String(a.el), "difficulty": String(a.difficulty),
			"mates": mode.mate_elements.duplicate(), "foes": mode.foe_elements.duplicate(),
			"fight_s": 0.0, "top_s": 0.0, "p_pct_taken": 0.0, "p_pct_taken_top": 0.0, "p_hits": 0, "p_hits_top": 0,
			"p_falls": 0, "p_falls_top": 0, "p_pct_dealt": 0.0, "p_kos": 0, "mate_kos": 0, "foe_kos": 0, "falls": [],
			"bot_s_on_player": 0.0, "bot_s_on_player_top": 0.0, "foe_near_s_top": 0.0, "foe_on_perch_s": 0.0,
			"p_stun_s": 0.0, "climbs": 0, "knocked_off": 0}
	var dt := 1.0 / Engine.physics_ticks_per_second
	var film_mark := -1.0
	var top_run := 0.0
	var game_t := 0.0
	var max_s := float(a.max_s)
	var dbg := String(a.dbg) == "1"
	var next_dbg := 0.0
	while mode.phase != "DONE" and game_t < 700.0 and float(g.fight_s) < max_s:
		await physics_frame
		game_t += dt
		if mode.phase != "FIGHT":
			continue
		g.fight_s += dt
		if dbg and float(g.fight_s) >= next_dbg:
			next_dbg += 1.0
			var pl := mode.ring.to_local(player.global_position)
			var tg: Variant = sim.get(&"target")
			print("DBG t=%.0f p=(%.1f,%.1f,%.1f) top=%s tgt=%s pct=%.0f lives=%d held=%s" % [float(g.fight_s), pl.x, pl.y, pl.z,
					str(sim.get(&"on_top")), RingMode.name_of(tg) if tg != null else "-", mode.rules.pct_of(player),
					mode.rules.stocks_of(player), str([player.controls.pressed(&"move_forward"), player.controls.pressed(&"move_back"),
					player.controls.pressed(&"move_left"), player.controls.pressed(&"move_right")])])
		var top := bool(sim.get(&"on_top"))
		top_run = top_run + dt if top else 0.0
		if top:
			g.top_s += dt
		if mode.rules.stunned(player):
			g.p_stun_s += dt
		var near := false
		for b in mode.rules.sides[1]:
			if not (b is NpcFighter) or not is_instance_valid(b) or not mode.in_play(b):
				continue
			var nf := b as NpcFighter
			if nf.brain != null and nf.brain.target == player:
				g.bot_s_on_player += dt
				if top:
					g.bot_s_on_player_top += dt
			var d := Vector2(nf.global_position.x - player.global_position.x, nf.global_position.z - player.global_position.z).length()
			if top and d < 8.0:
				near = true
			var pc: Dictionary = sim.get(&"perch")
			if not pc.is_empty():
				var l := mode.ring.to_local(nf.global_position)
				if (pc.rect as Rect2).has_point(Vector2(l.x, l.z)) and l.y > mode.ring.top() + float(pc.h) - 0.5:
					g.foe_on_perch_s += dt
		if near:
			g.foe_near_s_top += dt
		if film and film_mark < 0.0 and (way not in ["perch", "perch_idle"] or (top_run > 4.0 and near)) and g.fight_s > 6.0:
			film_mark = Engine.get_frames_drawn() / 60.0
			print("FILM MARK %.2f" % film_mark)
		if film and film_mark >= 0.0 and Engine.get_frames_drawn() / 60.0 - film_mark > film_s:
			break
	g["climbs"] = int(sim.get(&"climbs"))
	g["knocked_off"] = int(sim.get(&"knocked_off"))
	g["winner"] = mode.winner
	g["why"] = mode.last_why
	g["phase"] = mode.phase
	g["end_at_s"] = float((mode.history.back() as Dictionary).get("at_s", -1.0)) if not mode.history.is_empty() else -1.0
	g["lives_end"] = (mode.history.back() as Dictionary).get("lives", []) if not mode.history.is_empty() else []
	g["p_lives_left"] = mode.rules.stocks_of(player)
	for k: String in ["alone_s", "near_min", "cover_s", "shots_clear"]:
		if sim.get(k) != null:
			var kv := float(sim.get(k))
			g[k] = snappedf(kv, 0.1) if is_finite(kv) else -1.0
	g["casts"] = int(sim.get(&"casts"))
	g["clicks"] = int(sim.get(&"clicks"))
	g["guards"] = int(sim.get(&"guards"))
	for k: String in ["fight_s", "top_s", "p_pct_taken", "p_pct_taken_top", "p_pct_dealt", "bot_s_on_player",
			"bot_s_on_player_top", "foe_near_s_top", "foe_on_perch_s", "p_stun_s"]:
		g[k] = snappedf(float(g[k]), 0.1)
	var line := JSON.stringify(g)
	print("TEAMPROBE " + line)
	if out != "":
		var f := FileAccess.open(out, FileAccess.READ_WRITE) if FileAccess.file_exists(out) else FileAccess.open(out, FileAccess.WRITE)
		if f != null:
			f.seek_end()
			f.store_line(line)
			f.close()


func _who(b: Variant) -> String:
	if b == null or not is_instance_valid(b):
		return "self"
	if b == player:
		return "player"
	var t := mode.rules.team_of(b as Node)
	return "mate" if t == 0 else ("foe" if t == 1 else "?")


func _on_ko(b: Node3D, by: Node, pct: float, tag: String, left: int) -> void:
	if g.is_empty():
		return
	var top := sim != null and is_instance_valid(sim) and bool(sim.get(&"on_top"))
	var w := _who(b)
	var who_by := _who(by) if by != null else "self"
	(g.falls as Array).append({"t": snappedf(float(g.fight_s), 0.1), "who": w, "by": who_by, "pct": snappedf(pct, 1.0),
			"tag": tag, "left": left})
	if b == player:
		g.p_falls += 1
		if top or float(g.get("_last_top_t", -99.0)) > float(g.fight_s) - 3.0:
			g.p_falls_top += 1
	if by == player:
		g.p_kos += 1
	elif who_by == "mate":
		g.mate_kos += 1
	elif who_by == "foe":
		g.foe_kos += 1


func _on_pct(b: Node3D, _pct: float, delta: float) -> void:
	if g.is_empty() or b != player or delta <= 0.0 or mode.phase != "FIGHT":
		return
	g.p_pct_taken += delta
	if sim != null and is_instance_valid(sim) and bool(sim.get(&"on_top")):
		g.p_pct_taken_top += delta
		g["_last_top_t"] = float(g.fight_s)


func _on_dealt(by: Node, _b: Node3D, delta: float) -> void:
	if g.is_empty() or by != player:
		return
	g.p_pct_dealt += delta


func _on_launched(b: Node3D, _v: Vector3, _hs: float, _by: Node, _tag: String) -> void:
	if g.is_empty() or b != player:
		return
	g.p_hits += 1
	if sim != null and is_instance_valid(sim) and bool(sim.get(&"on_top")):
		g.p_hits_top += 1


func _quit(code: int) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	RingReplay.force = ""
	RingRules.rule_set_override = ""
	quit(code)
