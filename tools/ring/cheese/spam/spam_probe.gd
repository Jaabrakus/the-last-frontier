extends SceneTree
## Cheese hunt, lens "spam": real Tidebreak matches (scenes/ring.tscn, the default Lives rules: the % ring, 3 lives, the 8:00
## clock, sudden death), the player driven by spam_driver.gd through his own inputs against a real bot (MatchSetup.difficulty).
## Nothing in the match is injected: no %, no launch, no result. One process plays `matches` matches in a row (not "games": MatchSetup.parse reads games= as best-of) (mode.restart, the
## bot's dice from seed + 101 g), each to DONE or limit_s of fight.
##   zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . -s tools/ring/cheese/spam/spam_probe.gd -- \
##       element=fire foe=water difficulty=hard strat=punch matches=5 seed=500 [lo= hi= reach= hold= guard=1] [limit_s=600]
##   film=1 (windowed, --write-movie): one match, the game's own camera and HUD, quits film_s s into the fight (default 24);
##       prints FILM_START frame=<n> (the movie frame the fight began on) and FILM_END
## Lines: SPAM_GAME {json} per match, SPAM_SUMMARY {json} at the end, then SPAM PROBE DONE.

const Driver := preload("res://tools/ring/cheese/spam/spam_driver.gd")
const OWN_CFG := "user://cheese_spam_probe.cfg"

var args := {}
var lvl: RingLevel
var player: FrontierPlayer
var mode: RingMode
var sim: Node
var film := false
var games := 3
var seed0 := 500
var limit_s := 620.0
var strat := "expert"

var g := {}            ## this match's books
var all_games: Array = []
var _hooked_rules: RingRules = null
var _hooked_caster: SwayCaster = null
var _free_from := -1.0
var _stun_from := -1.0
var _fight_t := 0.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		if kv.contains("="):
			args[kv.get_slice("=", 0)] = kv.get_slice("=", 1)
	film = String(args.get("film", "0")) == "1"
	games = 1 if film else int(args.get("matches", "3"))
	seed0 = int(args.get("seed", "500"))
	limit_s = float(args.get("limit_s", "620"))
	strat = String(args.get("strat", "expert"))
	create_timer(float(args.get("watchdog_s", "3000")), true, false, true).timeout.connect(func() -> void:
		print("SPAM PROBE WATCHDOG")
		_summary()
		quit(2))
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	InputSetup.ensure()
	KitWords.ensure_guard_action()
	MatchSetup.reload_scheme()
	MatchSetup.set_controls("full")
	MatchSetup._aim_help = String(args.get("aim", "light"))
	MatchSetup.incoming = true
	MatchSetup.kind = "match"
	MatchSetup.format = "1v1"
	MatchSetup.element = String(args.get("element", "fire"))
	MatchSetup.foes = [String(args.get("foe", "water"))]
	MatchSetup.difficulty = String(args.get("difficulty", "hard"))
	MatchSetup.games_n = 1
	MatchSetup.light = "noon"
	RingRules.rule_set_override = "stock"
	RingReplay.force = "off"
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _run() -> void:
	for i in 10:
		await process_frame
	lvl = current_scene as RingLevel
	player = lvl.player if lvl != null else null
	mode = RingMode.find(self)
	if mode == null or player == null:
		print("SPAM PROBE no ring")
		quit(1)
		return
	player.ignore_mouse_capture = true
	if film:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# (the first match the ring started by itself: wait until it is fighting, then begin ours from a clean restart)
	for i in 1200:
		if mode.phase == "FIGHT" and not lvl.get_meta("loading_hold", false):
			break
		await physics_frame
	# (the schedule: for each seed, each foe of foes_cycle, each strat of strats: paired matches on the same bot dice)
	var strat_list: Array = String(args.get("strats", strat)).split(",", false)
	var foe_list: Array = String(args.get("foes_cycle", String(args.get("foe", "water")))).split(",", false)
	var gi := 0
	for si in games:
		for fe: String in foe_list:
			for st: String in strat_list:
				strat = st
				MatchSetup.foes = [fe]
				await _play(gi, seed0 + si * 101)
				gi += 1
	_summary()
	_cleanup()
	print("SPAM PROBE DONE")
	quit(0)


func _cleanup() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	Engine.time_scale = 1.0


func _play(gi: int, sd: int) -> void:
	if is_instance_valid(sim):
		sim._let_go()
		sim.queue_free()
		sim = null
	mode._seed = sd
	mode.restart()
	while mode.phase != "FIGHT":
		await physics_frame
	player.controls = PlayerControls.new(false)
	sim = Driver.new()
	sim.setup(player, mode, "expert", sd + 7)
	sim.configure(strat, args)
	lvl.add_child(sim)
	_hook()
	g = {"game": gi, "seed": sd, "strat": strat, "element": mode.element, "foe": mode.foe_element,
			"difficulty": mode.difficulty, "fight_s": 0.0, "winner": -1, "why": "", "falls_dealt": 0, "falls_taken": 0,
			"pct_dealt": 0.0, "pct_taken": 0.0, "ko_pct_foe": [], "ko_pct_me": [], "ko_tags": {}, "hits": 0, "hits_by": {},
			"hits_taken": 0, "foe_stun_s": 0.0, "foe_in_play_s": 0.0, "free_windows": [], "stun_windows": [],
			"strings": [], "longest_string": 0, "casts_me": 0, "foe_casts0": 0, "foe_guards0": 0, "first_ko_s": -1.0,
			"foe_casts": 0, "foe_guards": 0, "foe_perfects": 0, "foe_lates": 0, "foe_catches": 0, "foe_whiffs": 0,
			"my_launch_v": [], "sudden": false}
	var b := _foe_bend()
	if b != null:
		g.foe_casts0 = b.casts
		g.foe_guards0 = b.perfects + b.lates + b.whiffs + b.catches
		g["foe_perf0"] = b.perfects
		g["foe_late0"] = b.lates
		g["foe_catch0"] = b.catches
		g["foe_whiff0"] = b.whiffs
	_free_from = -1.0
	_stun_from = -1.0
	_fight_t = 0.0
	if film:
		print("FILM_START frame=%d physics=%d" % [Engine.get_frames_drawn(), Engine.get_physics_frames()])
	var film_s := float(args.get("film_s", "24"))
	while mode.phase != "DONE":
		await physics_frame
		if mode.phase == "FIGHT":
			_frame(1.0 / Engine.physics_ticks_per_second)
		if _fight_t >= limit_s:
			g.why = "limit"
			break
		if film and _fight_t >= film_s:
			g.why = "film_end"
			break
	_close_windows()
	g.fight_s = snappedf(_fight_t, 0.01)
	g.winner = mode.winner
	if g.why == "":
		g.why = mode.last_why
	g.sudden = mode.rules.sudden
	if b == null:
		b = _foe_bend()
	if b != null:
		g.foe_casts = b.casts - int(g.foe_casts0)
		g.foe_guards = b.perfects + b.lates + b.whiffs + b.catches - int(g.foe_guards0)
		g.foe_perfects = b.perfects - int(g.get("foe_perf0", 0))
		g.foe_lates = b.lates - int(g.get("foe_late0", 0))
		g.foe_catches = b.catches - int(g.get("foe_catch0", 0))
		g.foe_whiffs = b.whiffs - int(g.get("foe_whiff0", 0))
	g["spam"] = sim.spam.duplicate() if sim != null else {}
	g["driver_casts"] = sim.casts if sim != null else 0
	g["driver_clicks"] = sim.clicks if sim != null else 0
	g["driver_guards"] = sim.guards if sim != null else 0
	var fw: Array = g.free_windows
	var long_free := 0
	for w in fw:
		if float(w) >= 0.3:
			long_free += 1
	g["free_windows_n"] = fw.size()
	g["free_windows_ge_0_3"] = long_free
	g["foe_stun_share"] = snappedf(float(g.foe_stun_s) / maxf(float(g.foe_in_play_s), 0.01), 0.001)
	g["pct_dealt_per_s"] = snappedf(float(g.pct_dealt) / maxf(float(g.fight_s), 0.01), 0.01)
	g["pct_taken_per_s"] = snappedf(float(g.pct_taken) / maxf(float(g.fight_s), 0.01), 0.01)
	var sw: Array = g.stun_windows
	var longest_lock := 0.0
	for w in sw:
		longest_lock = maxf(longest_lock, float(w))
	g["longest_stunlock_s"] = snappedf(longest_lock, 0.01)
	var lv: Array = g.my_launch_v
	g["my_launch_v"] = []
	g["median_launch_v"] = _median(lv)
	g.free_windows = []
	g.stun_windows = []
	g["ko_pct_foe_median"] = _median(g.ko_pct_foe)
	g["ko_pct_me_median"] = _median(g.ko_pct_me)
	var strs: Array = g.strings
	g["strings_n"] = strs.size()
	g["strings_ge3"] = strs.filter(func(h: Variant) -> bool: return int(h) >= 3).size()
	g.strings = []
	g["pct_dealt"] = snappedf(float(g.pct_dealt), 0.1)
	g["pct_taken"] = snappedf(float(g.pct_taken), 0.1)
	g["foe_stun_s"] = snappedf(float(g.foe_stun_s), 0.01)
	g["foe_in_play_s"] = snappedf(float(g.foe_in_play_s), 0.01)
	print("SPAM_GAME " + JSON.stringify(g))
	all_games.append(g.duplicate(true))


static func _median(a: Array) -> float:
	if a.is_empty():
		return -1.0
	var s := a.duplicate()
	s.sort()
	return snappedf(float(s[s.size() / 2]), 0.1)


func _foe_bend() -> NpcBending:
	var f := mode.foe
	if f == null or not is_instance_valid(f) or f.brain == null:
		return null
	return f.brain.bending


func _hook() -> void:
	var r := mode.rules
	if r != _hooked_rules:
		_hooked_rules = r
		r.launched.connect(_on_launched)
		r.ko.connect(_on_ko)
		r.pct_dealt.connect(_on_pct_dealt)
		r.string_ended.connect(_on_string)
	var c := SwayCaster.of(player)
	if c != null and c != _hooked_caster:
		_hooked_caster = c
		c.cast_released.connect(func(_m: String, _md: String) -> void:
			if mode.phase == "FIGHT":
				g.casts_me = int(g.get("casts_me", 0)) + 1)


func _on_launched(b: Node3D, v: Vector3, _stun: float, by: Node, tag: String) -> void:
	if g.is_empty() or mode.phase != "FIGHT":
		return
	if b == mode.foe and by == player:
		g.hits = int(g.hits) + 1
		var hb: Dictionary = g.hits_by
		hb[tag] = int(hb.get(tag, 0)) + 1
		(g.my_launch_v as Array).append(v.length())
		g["last_v"] = snappedf(v.length(), 0.1)
		g["last_tag"] = tag
		g["last_pct"] = snappedf(mode.rules.pct_of(b), 0.1)
	elif b == player:
		g.hits_taken = int(g.hits_taken) + 1


func _on_ko(b: Node3D, _by: Node, pct: float, tag: String, _left: int) -> void:
	if g.is_empty():
		return
	if b == mode.foe:
		g.falls_dealt = int(g.falls_dealt) + 1
		(g.ko_pct_foe as Array).append(pct)
		if not g.has("kos"):
			g["kos"] = []
		(g.kos as Array).append({"t": snappedf(_fight_t, 0.1), "pct": snappedf(pct, 0.1), "tag": tag,
				"last_v": g.get("last_v", -1.0), "last_tag": g.get("last_tag", ""), "last_pct": g.get("last_pct", -1.0)})
		var kt: Dictionary = g.ko_tags
		kt[tag] = int(kt.get(tag, 0)) + 1
		if float(g.first_ko_s) < 0.0:
			g.first_ko_s = snappedf(_fight_t, 0.1)
	elif b == player:
		g.falls_taken = int(g.falls_taken) + 1
		(g.ko_pct_me as Array).append(pct)


func _on_pct_dealt(by: Node, b: Node3D, delta: float) -> void:
	if g.is_empty():
		return
	if by == player and b == mode.foe:
		g.pct_dealt = float(g.pct_dealt) + delta
	elif b == player:
		g.pct_taken = float(g.pct_taken) + delta


func _on_string(by: Node, victim: Node3D, hits: int, _pct: float) -> void:
	if g.is_empty():
		return
	if by == player and victim == mode.foe:
		(g.strings as Array).append(hits)
		g.longest_string = maxi(int(g.longest_string), hits)


## Each fight frame: the foe's hitstun and his free windows between stuns (while in play: not away, not respawning).
func _frame(dt: float) -> void:
	_fight_t += dt
	var f := mode.foe
	if f == null or not is_instance_valid(f):
		return
	var r := mode.rules
	if r.is_away(f):
		_close_windows()
		return
	g.foe_in_play_s = float(g.foe_in_play_s) + dt
	var st := r.stunned(f)
	if st:
		g.foe_stun_s = float(g.foe_stun_s) + dt
		if _free_from >= 0.0:
			(g.free_windows as Array).append(_fight_t - _free_from)
			_free_from = -1.0
		if _stun_from < 0.0:
			_stun_from = _fight_t
	else:
		if _stun_from >= 0.0:
			(g.stun_windows as Array).append(_fight_t - _stun_from)
			_stun_from = -1.0
		if _free_from < 0.0:
			_free_from = _fight_t


func _close_windows() -> void:
	if _stun_from >= 0.0:
		(g.stun_windows as Array).append(_fight_t - _stun_from)
	_stun_from = -1.0
	_free_from = -1.0


func _summary() -> void:
	if all_games.is_empty():
		print("SPAM_SUMMARY {}")
		return
	var s := {"strat": strat, "element": args.get("element", ""), "foe": args.get("foe", ""), "difficulty": args.get("difficulty", ""),
			"games": all_games.size(), "wins": 0, "losses": 0, "draws": 0, "falls_dealt": 0, "falls_taken": 0,
			"fight_s": [], "pct_dealt_per_s": [], "pct_taken_per_s": [], "foe_stun_share": [], "first_ko_s": [],
			"ko_pct_foe": [], "longest_string": 0, "longest_stunlock_s": 0.0, "foe_casts": 0, "foe_guards": 0, "hits": 0}
	for x: Dictionary in all_games:
		if int(x.winner) == 0:
			s.wins = int(s.wins) + 1
		elif int(x.winner) == 1:
			s.losses = int(s.losses) + 1
		else:
			s.draws = int(s.draws) + 1
		s.falls_dealt = int(s.falls_dealt) + int(x.falls_dealt)
		s.falls_taken = int(s.falls_taken) + int(x.falls_taken)
		(s.fight_s as Array).append(float(x.fight_s))
		(s.pct_dealt_per_s as Array).append(float(x.pct_dealt_per_s))
		(s.pct_taken_per_s as Array).append(float(x.pct_taken_per_s))
		(s.foe_stun_share as Array).append(float(x.foe_stun_share))
		if float(x.first_ko_s) >= 0.0:
			(s.first_ko_s as Array).append(float(x.first_ko_s))
		(s.ko_pct_foe as Array).append(float(x.ko_pct_foe_median))
		s.longest_string = maxi(int(s.longest_string), int(x.longest_string))
		s.longest_stunlock_s = maxf(float(s.longest_stunlock_s), float(x.longest_stunlock_s))
		s.foe_casts = int(s.foe_casts) + int(x.foe_casts)
		s.foe_guards = int(s.foe_guards) + int(x.foe_guards)
		s.hits = int(s.hits) + int(x.hits)
	for k in ["fight_s", "pct_dealt_per_s", "pct_taken_per_s", "foe_stun_share", "first_ko_s", "ko_pct_foe"]:
		s[k + "_median"] = _median(s[k])
	print("SPAM_SUMMARY " + JSON.stringify(s))
