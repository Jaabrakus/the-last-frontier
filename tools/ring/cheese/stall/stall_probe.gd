extends SceneTree
## STALL-LENS CHEESE PROBE (2026-10-10): real Tidebreak matches (scenes/ring.tscn, the stock rules, the real bot, the player
## driven only through his own keys by tools/ring/cheese/stall/stall_driver.gd) and their numbers. Nothing in the game is
## written: no damage, launches or results injected. Several matches run one after another in one ring (mode.restart(), as
## tests/ring/test_first_five.gd does), one STALL_ROW line each.
##   GODOT_TIMEOUT=600 zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . \
##       -s tools/ring/cheese/stall/stall_probe.gd -- model=hang el=earth foes=fire,earth diff=normal seeds=1,2 limit_s=150
## args: model=expert|idle|hang|run|turtle   after_lead=<model> (expert until his side leads on lives, then <model>)
##       el (the player's element), foes (a list: each a match), diff=easy|normal|hard, seeds (a list), limit_s (game
##       seconds of FIGHT a match; the match's own 8:00 clock and its end still rule), format=1v1|2v2|4v4,
##       film=1 (windowed: the game's own camera and HUD; one match, quits after film_s of FIGHT), caption=1, label=<text>,
##       hang_hold_s, debug=1
## Prints "STALL_ROW {json}" per match and "STALL_PROBE DONE".

const Driver := preload("res://tools/ring/cheese/stall/stall_driver.gd")
const SCRATCH := "/private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/84dd193e-59da-450f-a5ed-c6e1c2e9b538/scratchpad/cheese/stall"

var a := {}
var mode: RingMode
var player: FrontierPlayer
var drv: Node
var _t := 0.0
var _caption: Label
var _cfg := ""
var _st := {}
var _cur := {}


func _arg(k: String, def: String) -> String:
	return String(a.get(k, def))


func _list(k: String, def: String) -> Array:
	var out: Array = []
	for s in _arg(k, def).split(",", false):
		out.append(s.strip_edges())
	return out


func _initialize() -> void:
	for s in OS.get_cmdline_user_args():
		var kv := s.trim_prefix("--")
		var i := kv.find("=")
		if i < 0:
			a[kv] = "1"
		else:
			a[kv.substr(0, i)] = kv.substr(i + 1)
	if a.has("foe") and not a.has("foes"):
		a["foes"] = a["foe"]
	if a.has("seed") and not a.has("seeds"):
		a["seeds"] = a["seed"]
	seed(4200)
	_cfg = SCRATCH.path_join("cfg_%d.cfg" % OS.get_process_id())
	GameSettings.path = _cfg
	InputSetup.ensure()
	KitWords.ensure_guard_action()
	RingRules.rule_set_override = "stock"
	RingReplay.force = "off"
	MatchSetup.reload_scheme()
	MatchSetup.set_controls("full")
	MatchSetup._aim_help = "light"
	MatchSetup.incoming = true
	MatchSetup.kind = "match"
	MatchSetup.element = _arg("el", "earth")
	MatchSetup.foes = [String(_list("runs", "fire:1")[0]).get_slice(":", 0)] if a.has("runs") else [String(_list("foes", "fire")[0])]
	MatchSetup.mates = []
	MatchSetup.difficulty = _arg("diff", "normal")
	MatchSetup.games_n = 1
	MatchSetup.format = _arg("format", "1v1")
	MatchSetup.light = "noon"
	if _arg("film", "0") == "1":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false)
	var n := _list("runs", "x").size() if a.has("runs") else _list("foes", "fire").size() * _list("seeds", "1").size()
	var limit := (float(_arg("limit_s", "520")) + 40.0) * n + 200.0
	create_timer(limit, true, false, true).timeout.connect(func() -> void:
		print("STALL_PROBE watchdog")
		_quit())
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _run() -> void:
	for f in 1500:
		await physics_frame
		mode = RingMode.find(self)
		var p0: FrontierPlayer = mode.player if mode != null else null
		if p0 != null and p0.arena_element != "" and mode.rules != null and SwayCaster.of(p0) != null:
			break
	if mode == null or mode.player == null:
		print("STALL_PROBE FAILED: no ring")
		_quit()
		return
	player = mode.player
	_hook_rules()
	var film := _arg("film", "0") == "1"
	if film and _arg("caption", "1") == "1":
		_make_caption()
	var plan: Array = []
	if a.has("runs"):
		for p: String in _list("runs", ""):
			var dd: String = p.get_slice(":", 2) if p.get_slice_count(":") >= 3 else _arg("diff", "normal")
			var mm: String = p.get_slice(":", 3) if p.get_slice_count(":") >= 4 else _arg("model", "expert")
			plan.append([p.get_slice(":", 0), int(p.get_slice(":", 1)), dd, mm])
	else:
		for foe_el: String in _list("foes", "fire"):
			for sd_s: String in _list("seeds", "1"):
				plan.append([foe_el, int(sd_s), _arg("diff", "normal"), _arg("model", "expert")])
	for p: Array in plan:
		await _one(String(p[0]), int(p[1]), String(p[2]), String(p[3]))
		if film:
			break
	_quit()


func _one(foe_el: String, sd: int, diff: String, model: String) -> void:
	seed(4200 + sd)
	MatchSetup.element = _arg("el", "earth")
	MatchSetup.foes = [foe_el]
	MatchSetup.difficulty = diff
	mode.set(&"_seed", 7300 + 31 * sd)
	(mode.get(&"_rng") as RandomNumberGenerator).seed = 7300 + 31 * sd
	player.controls = PlayerControls.new(false)
	if drv != null and is_instance_valid(drv):
		drv.queue_free()
		drv = null
	mode.restart()
	await physics_frame
	player.ignore_mouse_capture = true
	drv = Driver.new()
	drv.call(&"setup", player, mode, "expert", 9000 + sd)
	drv.call(&"set_stall", model, _arg("after_lead", ""))
	if a.has("hang_hold_s"):
		drv.set(&"hang_hold_s", float(_arg("hang_hold_s", "3.85")))
	current_scene.add_child(drv)
	_cur = {"foe": foe_el, "seed": sd, "diff": diff, "model": model}
	_t = 0.0
	_st = {"p_pct_taken": 0.0, "p_hits": 0, "f_pct_taken": 0.0, "f_hits": 0, "p_kos": [], "f_kos": [],
			"p_launches": 0, "hang_s": 0.0, "ledge_s": 0.0, "offdeck_air_s": 0.0, "deck_s": 0.0, "intangible_s": 0.0,
			"safe_hits": 0, "p_max_pct": 0.0, "hang_hits": 0, "hang_pct": 0.0, "p_tags": {}, "deck_hits": 0,
			"deck_pct": 0.0}
	await _measure()
	_row()


func _hook_rules() -> void:
	var rules := mode.rules
	rules.pct_changed.connect(func(b: Node3D, _pct: float, delta: float) -> void:
		if delta <= 0.0 or _st.is_empty():
			return
		if b == player:
			_st.p_pct_taken = float(_st.p_pct_taken) + delta
			_st.p_hits = int(_st.p_hits) + 1
			var rm := RingMoves.of(player)
			if rm != null and (rm.on_ledge() or (rm.off_deck() and rm.airborne())):
				_st.hang_hits = int(_st.hang_hits) + 1
				_st.hang_pct = float(_st.hang_pct) + delta
			else:
				_st.deck_hits = int(_st.deck_hits) + 1
				_st.deck_pct = float(_st.deck_pct) + delta
			if _arg("debug", "0") == "1" and rm != null:
				print("H t=%.2f d=%.1f mode=%s mt=%.2f ledge=%s off=%s air=%s y=%.2f foe_state=%s" % [_t, delta, rm.mode, rm.mode_t,
						rm.on_ledge(), rm.off_deck(), rm.airborne(), player.global_position.y, _foe_state()])
		elif b == mode.foe:
			_st.f_pct_taken = float(_st.f_pct_taken) + delta
			_st.f_hits = int(_st.f_hits) + 1)
	rules.launched.connect(func(b: Node3D, _v: Vector3, _hs: float, _by: Node, tag: String) -> void:
		if b == player and not _st.is_empty():
			_st.p_launches = int(_st.p_launches) + 1
			var bt: Dictionary = _st.p_tags
			bt[tag] = int(bt.get(tag, 0)) + 1)
	rules.ko.connect(func(b: Node3D, _by: Node, pct: float, tag: String, left: int) -> void:
		if _st.is_empty():
			return
		var rec := {"t": snappedf(_t, 0.1), "pct": snappedf(pct, 0.1), "tag": tag, "left": left}
		if b == player:
			(_st.p_kos as Array).append(rec)
		else:
			(_st.f_kos as Array).append(rec))
	rules.hit_safe.connect(func(b: Node3D, _by: Node, _p: Vector3) -> void:
		if b == player and not _st.is_empty():
			_st.safe_hits = int(_st.safe_hits) + 1)


func _make_caption() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 120
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 18)
	_caption.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	_caption.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_caption.add_theme_constant_override("outline_size", 6)
	_caption.position = Vector2(16, 682)
	cl.add_child(_caption)
	current_scene.add_child(cl)


func _measure() -> void:
	var rules := mode.rules
	var limit := float(_arg("limit_s", "520"))
	var film := _arg("film", "0") == "1"
	var film_s := float(_arg("film_s", "40"))
	var dt := 1.0 / Engine.physics_ticks_per_second
	_st["why_end"] = "limit"
	var next_print := 60.0
	var started := false
	while true:
		await physics_frame
		if mode.phase == "DONE":
			_st["why_end"] = "done"
			break
		if mode.phase != "FIGHT":
			if started and mode.phase == "OVER":
				pass
			continue
		started = true
		_t += dt
		var rm := RingMoves.of(player)
		if rm != null and not rules.is_away(player):
			if rm.mode == "hang":
				_st.hang_s = float(_st.hang_s) + dt
			if rm.on_ledge():
				_st.ledge_s = float(_st.ledge_s) + dt
			elif rm.off_deck() and rm.airborne():
				_st.offdeck_air_s = float(_st.offdeck_air_s) + dt
			else:
				_st.deck_s = float(_st.deck_s) + dt
			if rm.intangible() or rules.is_safe(player):
				_st.intangible_s = float(_st.intangible_s) + dt
		_st.p_max_pct = maxf(float(_st.p_max_pct), rules.pct_of(player))
		if not _st.has("casts_at_switch") and drv != null and is_instance_valid(drv) and float(drv.get(&"switched_at")) >= 0.0:
			var fb0: Object = mode._foe_bending()
			_st["casts_at_switch"] = int(fb0.get(&"casts")) if fb0 != null else -1
			_st["hits_at_switch"] = int(_st.p_hits)
			_st["t_at_switch"] = snappedf(_t, 0.1)
		if _caption != null:
			var fb: Object = mode._foe_bending()
			var casts: int = int(fb.get(&"casts")) if fb != null else 0
			var stalling: bool = drv != null and is_instance_valid(drv) and String(drv.get(&"stall")) != "expert"
			var what: String = _arg("label_stall", "stalling") if stalling else _arg("label_play", "playing normally")
			_caption.text = "%s   |   hits taken %d   |   bot casts %d" % [what, int(_st.p_hits), casts]
		if _arg("debug", "0") == "1" and rm != null and int(round(_t * 60.0)) % 30 == 0:
			var g := RingMoves.arena_geo(mode.ring)
			var lp: Vector3 = (g.xf as Transform3D).affine_inverse() * player.global_position
			print("D t=%.1f mode=%s mt=%.2f air=%s floor=%s off=%s ledge=%s loc=(%.2f,%.2f,%.2f) grabs=%d foe_state=%s" % [_t,
					rm.mode, rm.mode_t, rm.airborne(), player.is_on_floor(), rm.off_deck(), rm.on_ledge(), lp.x, lp.y, lp.z,
					int(rm.get(&"_grabs")), _foe_state()])
		if _t >= next_print:
			next_print += 60.0
			print("T %.0f  p%%=%.0f lives %d-%d  hits_taken %d  ledge %.0fs" % [_t, rules.pct_of(player), rules.stocks_of(player),
					rules.stocks_of(mode.foe) if mode.foe != null else -1, int(_st.p_hits), float(_st.ledge_s)])
		if _t >= limit:
			break
		if film and _t >= film_s:
			break


func _foe_state() -> String:
	var fb: Object = mode._foe_bending() if mode != null else null
	if fb == null:
		return "?"
	var m: Variant = fb.get(&"ring_mind")
	if not (m is Object) or m == null:
		return "?"
	return String(NpcRingMind.STATE_NAMES[int((m as Object).get(&"state"))])


func _row() -> void:
	var row := _st.duplicate(true)
	row["model"] = _cur.get("model", _arg("model", "expert"))
	row["after_lead"] = _arg("after_lead", "")
	row["el"] = _arg("el", "earth")
	row["foe"] = _cur.get("foe", "")
	row["diff"] = _cur.get("diff", _arg("diff", "normal"))
	row["seed"] = _cur.get("seed", 0)
	row["format"] = _arg("format", "1v1")
	row["fight_s"] = snappedf(_t, 0.1)
	if mode != null and is_instance_valid(mode):
		row["phase"] = mode.phase
		row["winner"] = mode.winner if mode.phase == "DONE" else -9
		row["last_why"] = mode.last_why
		row["clock_left_s"] = snappedf(mode.round_left_s(), 0.1)
		if mode.rules != null:
			row["p_lives"] = mode.rules.stocks_of(player)
			row["f_lives"] = mode.rules.stocks_of(mode.foe) if mode.foe != null and is_instance_valid(mode.foe) else -1
		var fb: Object = mode._foe_bending()
		if fb != null:
			row["foe_casts"] = fb.get(&"casts")
			var m: Variant = fb.get(&"ring_mind")
			if m is Object and m != null:
				var ti: Dictionary = (m as Object).get(&"time_in")
				var tir := {}
				for k: String in ti:
					if float(ti[k]) > 0.0:
						tir[k] = snappedf(float(ti[k]), 0.1)
				row["foe_state_s"] = tir
				var sts: Dictionary = (m as Object).get(&"stats")
				for k: String in ["keep_off_casts", "safety_holds", "held_out", "chases", "slams", "slam_hops"]:
					row["foe_" + k] = sts.get(k, 0)
	if drv != null and is_instance_valid(drv):
		row["switched_at"] = snappedf(float(drv.get(&"switched_at")), 0.1)
		row["drops"] = drv.get(&"drops")
		row["climbs"] = drv.get(&"climbs")
		row["hops"] = drv.get(&"hops")
		row["coping_s"] = snappedf(float(drv.get(&"coping_s")), 0.1)
		row["perch_s"] = snappedf(float(drv.get(&"perch_s")), 0.1)
	for k: String in ["p_pct_taken", "f_pct_taken", "hang_s", "ledge_s", "offdeck_air_s", "deck_s", "intangible_s", "p_max_pct",
			"hang_pct", "deck_pct"]:
		if row.has(k):
			row[k] = snappedf(float(row[k]), 0.1)
	print("STALL_ROW " + JSON.stringify(row))


func _quit() -> void:
	print("STALL_PROBE DONE")
	RingRules.rule_set_override = ""
	DirAccess.remove_absolute(_cfg)
	GameSettings.path = GameSettings.PATH
	quit(0)
