extends SceneTree
## RINGOUT CHEESE PROBE (lens "ringout"): real Tidebreak matches (scenes/ring.tscn, the stock % rules, the real bot) with
## the player driven ONLY through his own keys: tools/ring/highlight_input.gd's expert (PlayerControls.set_held, the number
## keys as input events, the mouse as his camera's yaw and pitch). Nothing is injected: no damage, launches or results.
##   zsh tools/loop/run_test.sh <wt> <name> tools/ring/cheese/ringout/ringout_probe.gd policy=edgeslam el=earth \
##       foe=water difficulty=hard seeds=1,2 limit_s=240
## policy
##   base       the expert as he is (the baseline: normal good play)
##   edgeslam   the expert, plus: a foe off the deck under the lip, or hanging on it, gets the Slam (key 2 begun in the air)
##              from a hop at the lip right over him
##   spawncamp  edgeslam, plus: after the foe's fall he waits by the foe's spout (inside it, toward the middle) with Push
##              held to grow, and lets it go the moment the respawned foe can be hit, out toward the near lip
##   flee       never attacks: keeps away from the foe, guards what flies at him (the expert's guard)
## film=1: a normal window, the game's own camera and HUD (character_look=soft for the default look); quits film_after_s
## (6) after the first cheese event of the run ("EVENT CHEESE").
## Out: "EV {json}" per launch / fall / respawn, "MATCH {json}" per seed, "PROBE DONE".

const InputPlayer := preload("res://tools/ring/highlight_input.gd")
const OWN_CFG := "user://ringout_probe.cfg"

var policy := "base"
var policies: Array = []
var el := "earth"
var els: Array = []
var foe_el := "water"
var foes_list: Array = []
var difficulty := "hard"
var seeds: Array = [1]
var limit_s := 240.0
var film := false
var film_after_s := 6.0
var film_lead_s := 0.0
var mates := ""
var debug := false
var ff := 1.0
var lead_pct := 35.0
var near_m := 2.5
var _slow_from := -1.0

var lvl: Node
var mode: RingMode
var rules: RingRules
var player: FrontierPlayer
var drv: Driver
var t_fight := 0.0
var cur_seed := 0
var kos: Array = []
var launches: Array = []
var respawns: Array = []
var last_hit := {}          ## body id -> {t, tag, by, state, free, res}
var respawned_at := {}      ## body id -> game t
var left_spout_at := {}
var _cheese_at := -1.0
var _spout_hooked := {}
var _frames := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		var k := kv.get_slice("=", 0)
		var v := kv.get_slice("=", 1)
		match k:
			"policy", "policies":
				policies = []
				for x in v.split(",", false):
					policies.append(String(x))
				policy = String(policies[0])
			"el", "els":
				els = []
				for x in v.split(",", false):
					els.append(String(x))
				el = String(els[0])
			"foe", "foes":
				foes_list = []
				for x in v.split(",", false):
					foes_list.append(String(x))
				foe_el = String(foes_list[0])
			"difficulty":
				difficulty = v
			"seeds":
				seeds = []
				for s in v.split(",", false):
					seeds.append(int(s))
			"limit_s":
				limit_s = float(v)
			"film":
				film = v in ["1", "on", "true"]
			"film_after_s":
				film_after_s = float(v)
			"debug":
				debug = v in ["1", "on", "true"]
			"ff":
				ff = float(v)
			"lead_pct":
				lead_pct = float(v)
			"near_m":
				near_m = float(v)
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	InputSetup.ensure()
	KitWords.ensure_guard_action()
	MatchSetup.reload_scheme()
	MatchSetup.set_controls("full")
	MatchSetup._aim_help = "strong"
	MatchSetup.incoming = true
	MatchSetup.kind = "match"
	MatchSetup.element = el
	MatchSetup.foes = [foe_el]
	MatchSetup.difficulty = difficulty
	MatchSetup.games_n = 1
	MatchSetup.light = "noon"
	RingRules.rule_set_override = "stock"
	RingReplay.force = "off"
	if policies.is_empty():
		policies = [policy]
	if els.is_empty():
		els = [el]
	if foes_list.is_empty():
		foes_list = [foe_el]
	var total := (limit_s + 40.0) * seeds.size() * policies.size() * els.size() * foes_list.size() + 120.0
	create_timer(total, true, false, true).timeout.connect(func() -> void:
		print("PROBE WATCHDOG")
		_quit(2))
	node_added.connect(_on_node_added)
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _quit(code: int) -> void:
	Engine.time_scale = 1.0
	RingRules.rule_set_override = ""
	RingReplay.force = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	quit(code)


func _run() -> void:
	for i in 900:
		await physics_frame
		mode = RingMode.find(self)
		var p0: FrontierPlayer = mode.player if mode != null else null
		if p0 != null and p0.arena_element != "" and mode.rules != null and SwayCaster.of(p0) != null \
				and not (current_scene != null and current_scene.get_meta("loading_hold", false)):
			break
	if mode == null or mode.player == null:
		print("PROBE FAILED no ring")
		_quit(1)
		return
	player = mode.player
	lvl = current_scene
	player.ignore_mouse_capture = true
	if film:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		DisplayServer.window_set_title("Tidebreak probe (saved playback)")
	for e1: String in els:
		el = e1
		for f1: String in foes_list:
			foe_el = f1
			for pol: String in policies:
				policy = pol
				for sd: int in seeds:
					if not (film and _cheese_at >= 0.0):
						await _one(int(sd))
	print("PROBE DONE")
	_quit(0)


func _one(sd: int) -> void:
	cur_seed = sd
	kos = []
	launches = []
	respawns = []
	last_hit = {}
	respawned_at = {}
	left_spout_at = {}
	_ep = {}
	episodes = []
	_trail = {}
	_trail_t = -1.0
	seed(1750 + sd)
	MatchSetup.element = el
	MatchSetup.foes = [foe_el]
	MatchSetup.difficulty = difficulty
	mode.set(&"_seed", 7300 + 31 * sd)
	(mode.get(&"_rng") as RandomNumberGenerator).seed = 7300 + 31 * sd
	player.controls = PlayerControls.new(false)
	mode.restart()
	await physics_frame
	rules = mode.rules
	_hook_rules()
	while mode.phase != "FIGHT":
		await physics_frame
	t_fight = 0.0
	drv = Driver.new()
	drv.setup(player, mode, "expert", 9000 + sd)
	drv.set(&"policy", policy)
	drv.set(&"probe", self)
	drv.set(&"debug", debug)
	drv.m = drv.m.duplicate(true)
	current_scene.add_child(drv)
	var dt := 1.0 / Engine.physics_ticks_per_second
	while t_fight < limit_s:
		if film and ff > 1.0:
			# (the film's quiet stretches run fast so the window's movie stays short; the game's own speed whenever the
			# cheese may be near: the foe at lead_pct or more within 5 m of a lip or off the deck, the player on the lip,
			# after his fall for the spout's cheese, and from the cheese on: what the clip shows plays at 1x)
			var slow := _cheese_at >= 0.0
			var fo: Node3D = mode.foe
			if fo != null and is_instance_valid(fo) and not slow:
				var frm := RingMoves.of(fo)
				var near := float(mode.ring.nearest_lip(fo.global_position).out_m) > -near_m
				slow = (frm != null and (frm.off_deck() or frm.on_ledge())) or (near and rules.pct_of(fo) >= lead_pct)
				var prm := RingMoves.of(player)
				slow = slow or (prm != null and (prm.on_ledge() or prm.off_deck()))
				if policy == "spawncamp":
					slow = slow or (kos.size() > 0 and (rules.is_away(fo) or t_fight - float(respawned_at.get(fo.get_instance_id(), -99.0)) < 12.0))
			var want := 1.0 if slow else ff
			if Engine.time_scale < 0.999:
				want = Engine.time_scale          # (the game's own slow beat on a last fall: left as it is)
			if want != Engine.time_scale:
				print("FILM speed %.0fx at t=%.2f process_frame=%d video_s=%.2f" % [want, t_fight, Engine.get_process_frames(),
						Engine.get_process_frames() / 60.0])
			Engine.time_scale = want
		await physics_frame
		t_fight += dt * Engine.time_scale
		_frames += 1
		_track()
		if mode.phase == "DONE" or mode.phase == "OVER":
			break
		if film and _cheese_at >= 0.0 and t_fight >= _cheese_at + film_after_s:
			break
	var lives := [rules.stocks_of(player), rules.stocks_of(mode.foe) if mode.foe != null else -1]
	var row := {"seed": sd, "policy": policy, "el": el, "foe": foe_el, "difficulty": difficulty, "t": snappedf(t_fight, 0.01),
			"phase": mode.phase, "winner": mode.winner if mode.phase in ["DONE", "OVER"] else -2, "lives": lives,
			"pct": [snappedf(rules.pct_of(player), 0.1), snappedf(rules.pct_of(mode.foe), 0.1) if mode.foe != null else -1.0],
			"kos": kos, "drv": drv.call(&"books")}
	print("MATCH ", JSON.stringify(row))
	drv.call(&"_let_go")
	drv.queue_free()
	drv = null


var _hooked: RingRules = null


func _hook_rules() -> void:
	if rules == _hooked:
		return
	_hooked = rules
	rules.launched.connect(_on_launched)
	rules.ko.connect(_on_ko)
	rules.respawned.connect(_on_respawned)


func _who(b: Variant) -> String:
	if b == null or not is_instance_valid(b):
		return "none"
	if b == player:
		return "me"
	if mode != null and b == mode.foe:
		return "foe"
	return "other"


func _state_of(b: Node3D) -> Dictionary:
	var rm := RingMoves.of(b)
	if rm == null:
		return {}
	var lip := mode.ring.nearest_lip(b.global_position)
	return {"mode": rm.mode, "off": rm.off_deck(), "air": rm.airborne(), "hang": rm.mode == "hang", "jumps": rm.jumps_left,
			"rise": rm.rise_ready, "helpless": rm.helpless(), "out_m": snappedf(float(lip.out_m), 0.01),
			"under_m": snappedf(mode.ring.lip_y() - b.global_position.y, 0.01), "side": int(lip.side),
			"y": snappedf(b.global_position.y, 0.01)}


func _on_launched(b: Node3D, v: Vector3, hs: float, by: Node, tag: String) -> void:
	var st := _state_of(b)
	var e := {"ev": "launch", "seed": cur_seed, "t": snappedf(t_fight, 0.01), "who": _who(b), "by": _who(by), "tag": tag,
			"v": snappedf(v.length(), 0.01), "vy": snappedf(v.y, 0.01), "hs": snappedf(hs, 0.01),
			"pct": snappedf(rules.pct_of(b), 0.1), "st": st}
	launches.append(e)
	print("EV ", JSON.stringify(e))
	last_hit[b.get_instance_id()] = {"t": t_fight, "tag": tag, "by": _who(by), "st": st, "free": 0, "v": v.length(),
			"pct": rules.pct_of(b)}
	if _ep.has(b.get_instance_id()):
		var ep: Dictionary = _ep[b.get_instance_id()]
		ep["hits_on"] = int(ep.get("hits_on", 0)) + 1
		if tag.ends_with("/slam"):
			ep["slams_on"] = int(ep.get("slams_on", 0)) + 1
			ep["slam_pct"] = snappedf(rules.pct_of(b), 0.1)
	if drv != null:
		drv.call(&"on_launch", b, by, tag, v)


func _on_ko(b: Node3D, by: Node, pct: float, tag: String, left: int) -> void:
	var id := b.get_instance_id()
	var lh: Dictionary = last_hit.get(id, {})
	var e := {"ev": "ko", "seed": cur_seed, "t": snappedf(t_fight, 0.01), "who": _who(b), "by": _who(by), "pct": snappedf(pct, 0.1),
			"tag": tag, "left": left, "since_respawn_s": snappedf(t_fight - float(respawned_at.get(id, 0.0)), 0.01),
			"since_spout_s": snappedf(t_fight - float(left_spout_at.get(id, respawned_at.get(id, 0.0))), 0.01),
			"last_hit_tag": lh.get("tag", ""), "last_hit_by": lh.get("by", ""), "last_hit_t": snappedf(t_fight - float(lh.get("t", t_fight)), 0.01),
			"last_hit_v": snappedf(float(lh.get("v", 0.0)), 0.01), "pct_before_last": snappedf(float(lh.get("pct", -1.0)), 0.1),
			"free_frames_after_last_hit": int(lh.get("free", -1)), "st_at_last_hit": lh.get("st", {})}
	e["trail"] = (_trail.get(id, []) as Array).duplicate()
	e["ep_open"] = _ep.has(id)
	kos.append(e)
	last_hit.erase(id)
	print("EV ", JSON.stringify(e))
	if drv != null:
		drv.call(&"on_ko", b, by, pct, tag)
	if film and _cheese_at < 0.0 and drv != null and bool(drv.call(&"is_cheese_ko", e)):
		_cheese_at = t_fight
		print("EVENT CHEESE t=%.2f frame=%d process_frame=%d video_s=%.2f" % [t_fight, _frames, Engine.get_process_frames(),
				Engine.get_process_frames() / 60.0])


func _on_respawned(b: Node3D) -> void:
	respawned_at[b.get_instance_id()] = t_fight
	var e := {"ev": "respawn", "seed": cur_seed, "t": snappedf(t_fight, 0.01), "who": _who(b)}
	respawns.append(e)
	print("EV ", JSON.stringify(e))
	var rm := RingMoves.of(b)
	if rm != null and not _spout_hooked.has(b.get_instance_id()):
		_spout_hooked[b.get_instance_id()] = true
		rm.left_spout.connect(_on_left_spout.bind(b))
	if drv != null:
		drv.call(&"on_respawn", b)


func _on_left_spout(b: Node3D) -> void:
	left_spout_at[b.get_instance_id()] = t_fight


## Each frame: the free frames after each body's last hit (not in hitstun, not away).
func _track() -> void:
	for id: int in last_hit.keys():
		var o: Object = instance_from_id(id)
		if o == null or not is_instance_valid(o):
			last_hit.erase(id)
			continue
		var b := o as Node3D
		if rules.is_away(b):
			continue
		if not rules.stunned(b):
			var lh: Dictionary = last_hit[id]
			lh["free"] = int(lh.get("free", 0)) + 1
			# (back on the deck on his feet: that hit is over)
			var rm := RingMoves.of(b)
			if rm != null and not rm.airborne() and not rm.off_deck() and not rm.on_ledge() and (b as CharacterBody3D).is_on_floor():
				last_hit.erase(id)
	_episodes()


## Off-the-deck episodes of each fighter: from the frame he is off the deck in the air (or on the lip) until he stands on the
## deck again ("back") or falls ("out"): his % going off, how long, his grabs, the other's slams on him and the other hanging
## within the lip's 1.2 m of him (the hog) meanwhile.
var _ep := {}
var episodes: Array = []


## The last 2.5 s of each fighter's state, a sample every 0.1 s (dumped with each fall: how he got there).
var _trail := {}
var _trail_t := 0.0


func _sample_trail() -> void:
	if t_fight - _trail_t < 0.1:
		return
	_trail_t = t_fight
	for b: Node3D in [player, mode.foe]:
		if b == null or not is_instance_valid(b):
			continue
		var rm := RingMoves.of(b)
		if rm == null:
			continue
		var l := mode.ring.to_local(b.global_position)
		var v := (b as CharacterBody3D).velocity
		var sc := SwayCaster.of(b) if b is FrontierPlayer else null
		var casting := ""
		if b is NpcFighter and (b as NpcFighter).brain != null and (b as NpcFighter).brain.bending != null:
			casting = String((b as NpcFighter).brain.bending.get(&"casting"))
		elif sc != null:
			casting = sc.move if sc.state != SwayCaster.State.IDLE else ""
		var arr: Array = _trail.get(b.get_instance_id(), [])
		arr.append([snappedf(t_fight, 0.01), snappedf(l.x, 0.01), snappedf(l.y, 0.01), snappedf(l.z, 0.01),
				snappedf(v.length(), 0.1), rm.mode, rm.airborne(), rm.off_deck(), rules.stunned(b), casting,
				(b as CharacterBody3D).is_on_floor()])
		while arr.size() > 25:
			arr.pop_front()
		_trail[b.get_instance_id()] = arr


func _episodes() -> void:
	_sample_trail()
	for b: Node3D in [player, mode.foe]:
		if b == null or not is_instance_valid(b):
			continue
		var id := b.get_instance_id()
		var rm := RingMoves.of(b)
		if rm == null:
			continue
		var other: Node3D = mode.foe if b == player else player
		var orm := RingMoves.of(other) if other != null and is_instance_valid(other) else null
		var off := (rm.off_deck() and rm.airborne()) or rm.on_ledge()
		var away := rules.is_away(b)
		if not _ep.has(id):
			if off and not away:
				_ep[id] = {"who": _who(b), "t0": t_fight, "pct": snappedf(rules.pct_of(b), 0.1), "grabs": 0, "hang_s": 0.0,
						"near_hog_s": 0.0, "min_hog_m": 99.0, "slams_on": 0, "max_out": 0.0, "max_under": -99.0, "was_hang": false}
			continue
		var e: Dictionary = _ep[id]
		var lip := mode.ring.nearest_lip(b.global_position)
		e["max_out"] = maxf(float(e.max_out), float(lip.out_m))
		e["max_under"] = maxf(float(e.max_under), mode.ring.lip_y() - b.global_position.y)
		var dt := 1.0 / Engine.physics_ticks_per_second
		if rm.mode == "hang":
			if not bool(e.was_hang):
				e["grabs"] = int(e.grabs) + 1
			e["hang_s"] = float(e.hang_s) + dt
		e["was_hang"] = rm.mode == "hang"
		if orm != null and orm.mode == "hang":
			var hp: Vector3 = other.global_position
			var dd := Vector2(hp.x - b.global_position.x, hp.z - b.global_position.z).length()
			e["min_hog_m"] = minf(float(e.min_hog_m), dd)
			if dd < 2.5:
				e["near_hog_s"] = float(e.near_hog_s) + dt
		var res := ""
		if away:
			res = "out"
		elif not off and not rm.airborne() and (b as CharacterBody3D).is_on_floor():
			res = "back"
		if res != "":
			e["res"] = res
			e["dur"] = snappedf(t_fight - float(e.t0), 0.01)
			e["seed"] = cur_seed
			e["ev"] = "episode"
			e["policy"] = policy
			e["hang_s"] = snappedf(float(e.hang_s), 0.01)
			e["near_hog_s"] = snappedf(float(e.near_hog_s), 0.01)
			e["min_hog_m"] = snappedf(float(e.min_hog_m), 0.01)
			e["max_out"] = snappedf(float(e.max_out), 0.01)
			e["max_under"] = snappedf(float(e.max_under), 0.01)
			e.erase("was_hang")
			episodes.append(e)
			print("EV ", JSON.stringify(e))
			_ep.erase(id)


var walls: Array = []


## Walls raised (FormRaised walls, the fire and wind walls' zones): where they stand against the nearest lip (out_m: + past it).
func _on_node_added(nd: Node) -> void:
	if not (nd is FormRaised or nd is BendZone):
		return
	_wall_seen.call_deferred(nd)


func _wall_seen(nd: Node) -> void:
	if not is_instance_valid(nd) or mode == null or mode.ring == null or player == null:
		return
	var kind := String(nd.get(&"kind"))
	if nd is BendZone and not kind in ["fire_wall", "air_wall", "wind_wall", "wall"]:
		return
	if nd is FormRaised and kind != "wall":
		return
	var p := (nd as Node3D).global_position
	if nd is FormRaised:
		p = ((nd as FormRaised).base as Transform3D).origin     # (its base on the ground: the node itself sits elsewhere)
	var lip := mode.ring.nearest_lip(p)
	var e := {"ev": "wall", "seed": cur_seed, "t": snappedf(t_fight, 0.01), "el": el, "kind": kind,
			"cls": "FormRaised" if nd is FormRaised else "BendZone", "out_m": snappedf(float(lip.out_m), 0.01),
			"side": int(lip.side), "me_out_m": snappedf(float(mode.ring.nearest_lip(player.global_position).out_m), 0.01)}
	walls.append(e)
	print("EV ", JSON.stringify(e))


func _film_note(s: String) -> void:
	if film:
		print("FILM ", s)


# ------------------------------------------------------------------------------------------------ the player's hands
class Driver extends "res://tools/ring/highlight_input.gd":
	var policy := "base"
	var probe: Object = null
	## The policy's phase ("" the expert's own frame), its start, the spot, the books.
	var ph := ""
	var ph_t := 0.0
	var _cast_seen := false
	var _k2_at := -INF
	var bk := {"edge_tries": 0, "slam_hops": 0, "slams": 0, "slam_hits": 0, "slam_hit_pct": [], "camp_waits": 0,
			"camp_pushes": 0, "camp_hits": 0, "flee_frames": 0, "aborts": 0, "hog_tries": 0, "hog_hangs": 0, "hog_kos": 0,
			"hog_ko_pct": [], "hog_hit_off": 0}
	var _hog_spot := {}
	var _hog_hang_at := -INF
	var _hog_ff := false
	var _sc: SwayCaster
	var _foe_ko_at := -INF
	var _foe_respawn_at := -INF
	var debug := false
	var _dbg_tick := -1

	func books() -> Dictionary:
		return bk

	func on_launch(b: Node3D, by: Node, tag: String, _v: Vector3) -> void:
		if by == player and b == mode.foe and tag.ends_with("/slam"):
			bk.slam_hits += 1
			(bk.slam_hit_pct as Array).append(snappedf(mode.rules.pct_of(b), 0.1))
		if by == player and b == mode.foe and ph in ["camp_push", "camp"]:
			bk.camp_hits += 1

	func on_ko(b: Node3D, _by: Node, pct: float, _tag: String) -> void:
		if b == mode.foe:
			_foe_ko_at = _t
			if ph in ["hog_hang", "hog_step"] or _t - _hog_hang_at < 1.0:
				bk.hog_kos += 1
				(bk.hog_ko_pct as Array).append(snappedf(pct, 0.1))
		if b == player and ph in ["hog_hang", "hog_step"]:
			bk.hog_hit_off += 1

	func on_respawn(b: Node3D) -> void:
		if b == mode.foe:
			_foe_respawn_at = _t

	func is_cheese_ko(e: Dictionary) -> bool:
		if String(e.get("who", "")) != "foe" or String(e.get("by", "")) != "me":
			return false
		match policy:
			"edgeslam":
				return String(e.get("tag", "")).ends_with("/slam")
			"spawncamp":
				return float(e.get("since_respawn_s", 99.0)) < 15.0
			"edgehog":
				return ph in ["hog_hang", "hog_step"] or _t - _hog_hang_at < 1.0
		return true

	func _ready() -> void:
		super._ready()
		_sc = SwayCaster.of(player)
		if _sc != null:
			_sc.cast_released.connect(func(_mv: String, md: String) -> void:
				if md == "slam":
					bk.slams += 1
				_cast_seen = true)

	func _physics_process(dt: float) -> void:
		if policy == "base" or not _wants():
			if ph != "":
				ph = ""
			super._physics_process(dt)
			return
		_t += dt
		_hook()
		_untap()
		match policy:
			"edgeslam":
				_edge_frame(dt)
			"spawncamp":
				if not _edge_frame(dt):
					_camp_frame(dt)
			"flee":
				_flee_frame(dt)
			"edgehog":
				_hog_frame(dt)
			"wallcheck":
				_wall_frame(dt)

	# ---------------------------------------------------------------- common
	func _foe() -> Node3D:
		var f: Node3D = mode.foe if mode != null else null
		return f if f != null and is_instance_valid(f) else null

	func _live(rm: RingMoves) -> bool:
		if mode == null or not is_instance_valid(mode) or mode.phase != "FIGHT" or rm == null:
			return false
		if _rules != null and _rules.is_away(player):
			return false
		return true

	func _k2() -> Dictionary:
		var ks := Bending.keys(String(player.arena_element))
		return Bending.first_of(ks[1]) if ks.size() > 1 else {}

	## Key 2's first move readied (one tap; never two within double_tap_s).
	func _ready_k2() -> bool:
		var f := _k2()
		if f.is_empty() or _sc == null:
			return false
		if _sc.readied_spell == String(f.id) and _sc.mode_of(String(f.id)) == String(f.mode):
			return true
		if _t - _k2_at > 0.4:
			_k2_at = _t
			_key(&"weapon_2")
		return false

	func _aim_at(p: Vector3, dt: float, rate := 14.0) -> void:
		var to := p - player.camera.global_position
		var want_yaw := atan2(-to.x, -to.z)
		var want_pitch := atan2(to.y, maxf(Vector2(to.x, to.z).length(), 0.1))
		var k := 1.0 - exp(-rate * dt)
		player.yaw += wrapf(want_yaw - player.yaw, -PI, PI) * k
		player.pitch = lerpf(player.pitch, clampf(want_pitch, -1.2, 1.2), k)

	func _walk_to(p: Vector3, sprint := true) -> float:
		var to := p - player.global_position
		to.y = 0.0
		var d := to.length()
		if d > 0.25:
			_hold_world(to.normalized())
		else:
			for a: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
				_hold(a, false)
		_hold(&"sprint", sprint and d > 0.6)
		return d

	func _stop_feet() -> void:
		for a: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint"]:
			_hold(a, false)

	func _wants() -> bool:
		var rm := RingMoves.of(player)
		if not _live(rm):
			return false
		var foe := _foe()
		if foe == null:
			return false
		match policy:
			"edgeslam":
				return _edge_wants(rm, foe)
			"spawncamp":
				return _edge_wants(rm, foe) or _camp_wants(rm, foe)
			"flee":
				return not (rm.off_deck() and rm.airborne()) and not rm.on_ledge() and _launch.is_empty()
			"edgehog":
				return _hog_wants(rm, foe)
			"wallcheck":
				return not rm.off_deck() and _launch.is_empty()
		return false

	# ---------------------------------------------------------------- the Slam over the lip
	## The foe as a Slam target: off the deck under the lip (0.2-3.4 m) within 2.2 m out of it, or hanging. {} none.
	func _edge_target(foe: Node3D) -> Dictionary:
		var frm := RingMoves.of(foe)
		if frm == null or (_rules != null and _rules.is_away(foe)):
			return {}
		var lip: Dictionary = mode.ring.nearest_lip(foe.global_position)
		var under: float = mode.ring.lip_y() - foe.global_position.y
		var out := float(lip.out_m)
		var hanging := frm.mode == "hang"
		var off := frm.off_deck() and frm.airborne() and out < 9.0
		if not (hanging or off):
			return {}
		# (in the Slam's reach from a hop at the lip: under it 0.2-3.4 m and at most 2.2 m out, or hanging on it)
		var reach := hanging or (out > -0.3 and out < 2.2 and under > 0.2 and under < 3.4)
		return {"lip": lip, "hanging": hanging, "under": under, "out": out, "reach": reach}

	func _edge_wants(rm: RingMoves, foe: Node3D) -> bool:
		if ph == "hop":
			return _t - ph_t < 0.8
		if ph == "cast":
			# (the hop runs until the cast has gone; then the expert's own frame, his way back included)
			return not (_cast_seen and _sc != null and _sc.state == SwayCaster.State.IDLE) and _t - ph_t < 1.0
		if rm.off_deck() or rm.on_ledge() or not _launch.is_empty() or (_rules != null and _rules.stunned(player)):
			return false
		if _edge_target(foe).is_empty():
			return false
		# (near enough to get there while he is still down there)
		var lip: Dictionary = mode.ring.nearest_lip(foe.global_position)
		var d := Vector2(player.global_position.x - Vector3(lip.point).x, player.global_position.z - Vector3(lip.point).z).length()
		return d < 9.0

	## True when this frame was the Slam's.
	func _edge_frame(dt: float) -> bool:
		var foe := _foe()
		var rm := RingMoves.of(player)
		if foe == null or rm == null:
			return false
		if ph in ["hop", "cast"]:
			_aim_at(foe.global_position + Vector3.UP * 0.6, dt, 20.0)
			var tg := _edge_target(foe)
			var lipd: Dictionary = tg.get("lip", mode.ring.nearest_lip(foe.global_position))
			# (a small drift out over him when he is out past the lip; none when he hangs on it)
			var n: Vector3 = Vector3(lipd.normal)
			if not tg.is_empty() and not bool(tg.hanging) and float(tg.out) > 0.4 and float(tg.out) < 2.2:
				_hold_world(n * 0.4)
			else:
				_stop_feet()
			if ph == "hop" and rm.airborne() and _t - ph_t >= 0.03:
				_tap(&"aim", 0.08)
				ph = "cast"
				_cast_seen = false
			return true
		var tg := _edge_target(foe)
		if tg.is_empty():
			return false
		if ph == "":
			ph = "go"
			ph_t = _t
			bk.edge_tries += 1
		var lip: Dictionary = tg.lip
		var n: Vector3 = Vector3(lip.normal)
		var spot: Vector3 = Vector3(lip.point) - n * 0.45
		_aim_at(foe.global_position + Vector3.UP * 0.6, dt, 16.0)
		var d := _walk_to(spot)
		var k2 := _ready_k2()
		if _sc != null and _sc.state != SwayCaster.State.IDLE:
			if debug:
				print("DBG edge busy t=%.2f state=%s move=%s" % [_t, _sc.state, _sc.move])
			return true                              # (a lock of his still running: it goes first)
		if d > 0.55 or not k2:
			if debug and int(_t * 8.0) != _dbg_tick:
				_dbg_tick = int(_t * 8.0)
				print("DBG edge far t=%.2f d=%.2f k2=%s readied=%s/%s" % [_t, d, k2, _sc.readied_spell if _sc != null else "", _sc.mode_of(_sc.readied_spell) if _sc != null else ""])
			return true
		var frm := RingMoves.of(foe)
		if debug and int(_t * 8.0) != _dbg_tick:
			_dbg_tick = int(_t * 8.0)
			print("DBG edge t=%.2f d=%.2f k2=%s state=%s readied=%s/%s foe_mode=%s safe=%.2f out=%.2f under=%.2f" % [_t, d, k2,
					_sc.state if _sc != null else -1, _sc.readied_spell if _sc != null else "", _sc.mode_of(_sc.readied_spell) if _sc != null else "",
					frm.mode if frm != null else "", frm.ledge_safe_left() if frm != null else -1.0, float(tg.out), float(tg.under)])
		# (waiting at the lip over him until he is in the Slam's reach; his first grab's safety: the hop timed so the column
		# comes as it ends)
		if not bool(tg.reach) or (bool(tg.hanging) and frm != null and frm.ledge_safe_left() > 0.32):
			_stop_feet()
			return true
		_stop_feet()
		_tap(&"jump", 0.1)
		ph = "hop"
		ph_t = _t
		bk.slam_hops += 1
		return true

	# ---------------------------------------------------------------- waiting by his spout
	func _camp_wants(rm: RingMoves, foe: Node3D) -> bool:
		if rm.off_deck() or rm.on_ledge() or not _launch.is_empty() or (_rules != null and _rules.stunned(player)):
			return false
		# (from his fall until a few seconds after he is down off the spout)
		if _foe_ko_at < 0.0 or _t - _foe_ko_at > 14.0:
			return false
		var frm := RingMoves.of(foe)
		if frm != null and not frm.on_spout() and _foe_respawn_at > _foe_ko_at and _t - _foe_respawn_at > 9.0:
			return false
		return true

	func _camp_frame(dt: float) -> void:
		var foe := _foe()
		if foe == null:
			return
		var e: int = _rules.end_of(foe) if _rules != null else 1
		var ring: RingArena = mode.ring
		# (the line between his two spouts, 3 m in from it toward the middle; then at him)
		var s0 := ring.spout_at(e, 0)
		var s1 := ring.spout_at(e, 1)
		var away: bool = _rules != null and _rules.is_away(foe)
		var frm := RingMoves.of(foe)
		var on_spout := frm != null and frm.on_spout()
		var target: Vector3
		if away:
			target = (s0 + s1) * 0.5 - ring.axis() * RingArena.side_sign(e) * 2.0
		else:
			var sp := foe.global_position
			var lip: Dictionary = ring.nearest_lip(sp)
			# (stand inside him, so the Push sends him out over his nearest lip)
			target = sp - Vector3(lip.normal) * 3.0
		target.y = player.global_position.y
		var d := _walk_to(target, true)
		if ph != "camp" and ph != "camp_push":
			ph = "camp"
			ph_t = _t
			bk.camp_waits += 1
		_aim_at(foe.global_position + Vector3.UP * 1.0, dt, 14.0)
		if away:
			return
		# Push held to grow while he is safe (on the spout, or his 1.5 s after it); let go as his safety ends
		var safe: bool = _rules != null and _rules.is_safe(foe)
		var k2 := _ready_k2()
		if ph == "camp" and k2 and _sc != null and _sc.state == SwayCaster.State.IDLE and not on_spout and d < 2.5:
			player.controls.set_held(&"aim", true)
			ph = "camp_push"
			ph_t = _t
			bk.camp_pushes += 1
		elif ph == "camp_push":
			var dist := _flat_d(foe)
			if (not safe and _t - ph_t > 1.1 and dist < 5.5) or _t - ph_t > 2.4:
				player.controls.set_held(&"aim", false)
				ph = "camp"
				ph_t = _t

	# ---------------------------------------------------------------- keeping away
	func _flee_frame(dt: float) -> void:
		var foe := _foe()
		if foe == null:
			return
		bk.flee_frames += 1
		var ring: RingArena = mode.ring
		var best := player.global_position
		var best_d := -INF
		var hl := ring.half_l() - 3.0
		var hw := ring.half_w() - 2.5
		for i in 9:
			for j in 5:
				var l := Vector3(lerpf(-hl, hl, i / 8.0), ring.top(), lerpf(-hw, hw, j / 4.0))
				var p := ring.to_global(l)
				var dd := Vector2(p.x - foe.global_position.x, p.z - foe.global_position.z).length() \
						- 0.35 * Vector2(p.x - player.global_position.x, p.z - player.global_position.z).length()
				if dd > best_d:
					best_d = dd
					best = p
		_walk_to(best, true)
		_mouse(foe, dt)
		_guard(foe)

	# ---------------------------------------------------------------- hanging on his spot of the lip
	## The foe off the deck and on his way back (not away): the lip point he makes for (his nearest), {} none.
	func _hog_target(foe: Node3D) -> Dictionary:
		var frm := RingMoves.of(foe)
		if frm == null or (_rules != null and _rules.is_away(foe)):
			return {}
		if not (frm.off_deck() and frm.airborne()):
			return {}
		var lip: Dictionary = mode.ring.nearest_lip(foe.global_position)
		if float(lip.out_m) > 9.0:
			return {}
		return lip

	func _hog_wants(rm: RingMoves, foe: Node3D) -> bool:
		if not _launch.is_empty() or (_rules != null and _rules.stunned(player)):
			return false
		if ph == "hog_step":
			return _t - ph_t < 1.2 and not (rm.airborne() and rm.off_deck() and _t - ph_t > 0.9)
		if ph == "hog_hang":
			return rm.on_ledge()
		if ph == "hog_climb":
			return rm.on_ledge() and _t - ph_t < 1.0
		if rm.off_deck() or rm.on_ledge() or rm.airborne():
			return false
		var lip := _hog_target(foe)
		if lip.is_empty():
			return false
		var d := Vector2(player.global_position.x - Vector3(lip.point).x, player.global_position.z - Vector3(lip.point).z).length()
		return d < 8.0

	func _hog_frame(dt: float) -> void:
		var foe := _foe()
		var rm := RingMoves.of(player)
		if foe == null or rm == null:
			return
		var frm := RingMoves.of(foe)
		match ph:
			"", "go", "hog_go":
				var lip := _hog_target(foe)
				if lip.is_empty():
					return
				if ph != "hog_go":
					ph = "hog_go"
					ph_t = _t
					bk.hog_tries += 1
				_hog_spot = lip
				var n: Vector3 = Vector3(lip.normal)
				var spot: Vector3 = Vector3(lip.point) - n * 0.25
				_aim_at(foe.global_position + Vector3.UP * 0.5, dt, 10.0)
				var d := _walk_to(spot, true)
				if debug and int(_t * 4.0) != _dbg_tick:
					_dbg_tick = int(_t * 4.0)
					print("DBG hog go t=%.2f d=%.2f foe out %.2f under %.2f" % [_t, d, float(lip.out_m), mode.ring.lip_y() - foe.global_position.y])
				if d < 0.35:
					ph = "hog_step"
					ph_t = _t
					_hog_ff = false
			"hog_step":
				var n2: Vector3 = Vector3(_hog_spot.normal)
				_hold(&"sprint", false)
				if rm.on_ledge():
					_stop_feet()
					if debug:
						var fl: Dictionary = mode.ring.nearest_lip(foe.global_position)
						print("DBG hog hang t=%.2f after %.2f s; foe out %.2f under %.2f along-gap %.2f" % [_t, _t - ph_t,
								float(fl.out_m), mode.ring.lip_y() - foe.global_position.y,
								Vector2(Vector3(fl.point).x - player.global_position.x, Vector3(fl.point).z - player.global_position.z).length()])
					ph = "hog_hang"
					ph_t = _t
					_hog_hang_at = _t
					bk.hog_hangs += 1
					return
				# (on the deck: held toward the water, the teeter's 0.3 s steps him off; once off: held back toward the
				# deck's face, so his head drops into the grab box instead of drifting out past it)
				if rm.airborne():
					# (off: a tap of C, the fast fall, so the head drops into the grab box before the step's run carries
					# him past its 0.9 m; then held back toward the face)
					_hold_world(-n2)
					if not _hog_ff:
						_hog_ff = true
						_tap(&"crouch", 0.0)
				else:
					_hold_world(n2)
				if debug:
					var pl: Dictionary = mode.ring.nearest_lip(player.global_position)
					print("DBG hog step t=%.2f air=%s off=%s mode=%s out=%.2f feet_under=%.2f vy=%.2f teeter=%s" % [_t - ph_t, rm.airborne(),
							rm.off_deck(), rm.mode, float(pl.out_m), mode.ring.lip_y() - player.global_position.y, player.velocity.y,
							rm.get(&"_teeter_t")])
			"hog_hang":
				_stop_feet()
				_hog_hang_at = _t
				_aim_at(foe.global_position + Vector3.UP * 0.5, dt, 10.0)
				var gone: bool = _rules != null and _rules.is_away(foe)
				var back := frm != null and not frm.airborne() and not frm.off_deck()
				var hung := _t - ph_t
				if gone or back or hung > 3.4 or (frm != null and frm.on_ledge()):
					# (he is in the water, back on the deck, or the hang's time is nearly out: climb)
					ph = "hog_climb"
					ph_t = _t
					_hold(&"move_forward", true)
			"hog_climb":
				_hold(&"move_forward", true)

	# ---------------------------------------------------------------- a wall at the lip (key 4 aimed just past it)
	var _wall_n := 0
	var _wall_at := -INF

	func _wall_frame(dt: float) -> void:
		var ring: RingArena = mode.ring
		var l := ring.to_local(player.global_position)
		var sd := 1.0 if l.z >= 0.0 else -1.0
		var edge := ring.to_global(Vector3(l.x, ring.top(), sd * (ring.half_w() - 0.6)))
		var d := _walk_to(edge, false)
		var past := ring.to_global(Vector3(l.x, ring.top(), sd * (ring.half_w() + 0.8)))
		_aim_at(past, dt, 20.0)
		if d > 0.45 or _t - _wall_at < 2.5 or _wall_n >= 3:
			return
		if _sc != null and _sc.state != SwayCaster.State.IDLE:
			return
		_wall_at = _t
		_wall_n += 1
		_key(&"weapon_4")
		_tap(&"aim", 0.08)
