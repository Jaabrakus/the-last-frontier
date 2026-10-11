extends "res://tools/ring/cheese/team/team_probe.gd"
## Cheese hunt, lens "team": fire's Lightning on a bot that is busy with someone else. A bot reads only ITS OWN target's
## wind-up (NpcBending._threats: the Lightning's charge is a threat only when its target charges it), so in a team format a
## player the bot is not coached onto charges unseen. Same real match as team_probe.gd; the player is snipe_driver.gd
## (way=snipe: Lightning only, at a bot not on him; snipe_any: at the nearest bot; deck: the expert baseline), key and mouse
## actions only. Per game, besides the TEAMPROBE line: "SNIPE {json}": each released Lightning matched to its strike (a
## Lightning hit by the player within 0.6 s of it), split by whether its bot was on the player at the release.
##   zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . -s tools/ring/cheese/team/snipe_probe.gd -- \
##       format=2v2 way=snipe el=fire s0=1 n=1 [difficulty=normal] [out=<jsonl>]

const Snipe := preload("res://tools/ring/cheese/team/snipe_driver.gd")

var lt_hits: Array = []
var _last_dealt := {}


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
	rules.pct_dealt.connect(func(by: Node, b: Node3D, d: float) -> void:
		if by == player and b != null:
			_last_dealt[b.get_instance_id()] = d)
	rules.launched.connect(_on_lt_hit)
	for k in n:
		var sd := s0 + k
		mode.set(&"_seed", 7300 + 31 * sd)
		(mode.get(&"_rng") as RandomNumberGenerator).seed = 7300 + 31 * sd
		mode.restart()
		await physics_frame
		sim = Snipe.new()
		sim.call(&"setup", player, mode, "expert", 9000 + sd)
		sim.set(&"camera_aim", true)
		sim.set(&"way", way)
		current_scene.add_child(sim)
		lt_hits = []
		await _game(sd)
		_snipe_books(sd)
		sim.call(&"_let_go")
		sim.queue_free()
		await physics_frame
	print("TEAMPROBE DONE wall_s=%.0f" % ((Time.get_ticks_msec() - _t0) / 1000.0))
	_quit(0)


func _on_lt_hit(b: Node3D, _v: Vector3, _hs: float, by: Node, tag: String) -> void:
	if by != player or not tag.begins_with("fire_arc/lightning") or sim == null or not is_instance_valid(sim):
		return
	var watching := b is NpcFighter and (b as NpcFighter).brain != null and (b as NpcFighter).brain.target == player
	lt_hits.append({"t": float(sim.get(&"_t")), "watching": watching, "pct": mode.rules.pct_of(b),
			"d": float(_last_dealt.get(b.get_instance_id(), 0.0))})


func _snipe_books(sd: int) -> void:
	var rel: Array = sim.get(&"lt") if sim != null and is_instance_valid(sim) else []
	var used := {}
	var n_w := 0
	var n_b := 0
	var h_w := 0
	var h_b := 0
	var f_w := 0
	var f_b := 0
	var d_w := 0.0
	var d_b := 0.0
	var ally_n := 0
	var ally_hit := 0
	for r: Dictionary in rel:
		var hit := false
		var full := false
		var dd := 0.0
		for i in lt_hits.size():
			if used.has(i):
				continue
			var dt := float((lt_hits[i] as Dictionary).t) - float(r.t)
			if dt >= 0.0 and dt <= 0.6:
				used[i] = true
				hit = true
				dd = float((lt_hits[i] as Dictionary).d)
				full = dd >= 13.0
				break
		if bool(r.get("ally_in_line", false)):
			ally_n += 1
			ally_hit += 1 if hit else 0
		if bool(r.watching):
			n_w += 1
			h_w += 1 if hit else 0
			f_w += 1 if full else 0
			d_w += dd
		else:
			n_b += 1
			h_b += 1 if hit else 0
			f_b += 1 if full else 0
			d_b += dd
	var row := {"seed": sd, "format": fmt, "way": way, "lt_released": rel.size(), "lt_hits": lt_hits.size(),
			"watched_n": n_w, "watched_hit": h_w, "blind_n": n_b, "blind_hit": h_b,
			"hit_rate_watched": snappedf(float(h_w) / maxf(n_w, 1), 0.01), "hit_rate_blind": snappedf(float(h_b) / maxf(n_b, 1), 0.01),
			"full_watched": f_w, "full_blind": f_b, "pct_per_shot_watched": snappedf(d_w / maxf(n_w, 1), 0.1),
			"pct_per_shot_blind": snappedf(d_b / maxf(n_b, 1), 0.1), "ally_in_line_n": ally_n, "ally_in_line_hit": ally_hit,
			"p_kos": g.get("p_kos", 0), "p_falls": g.get("p_falls", 0), "p_pct_dealt": g.get("p_pct_dealt", 0.0),
			"fight_s": g.get("fight_s", 0.0), "winner": g.get("winner", -1), "why": g.get("why", ""),
			"lives_end": g.get("lives_end", [])}
	var line := JSON.stringify(row)
	print("SNIPE " + line)
	if out != "":
		var p := out.get_basename() + "_snipe.jsonl"
		var f := FileAccess.open(p, FileAccess.READ_WRITE) if FileAccess.file_exists(p) else FileAccess.open(p, FileAccess.WRITE)
		if f != null:
			f.seek_end()
			f.store_line(line)
			f.close()
