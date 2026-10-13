extends SceneTree
## Tidebreak's own score (round 4 SHOW; MusicDirector's ring mode, RingMusic, data/ring/music.json), in the ring scene with
## a stock-rules match asked for (the foe held), its own MusicDirector under the level (a script run makes none without
## music=on):
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_ring_music.gd -- mode=ring element=earth foe=water
##   the cues     the manifest has ring_fight_base, _drive and _peak (one length, one loop, 4/4 at 120-132 BPM, 32 bars), the
##                go, and every stinger music.json names (each a one-shot WAV as long as the manifest says)
##   the score    the go starts the ring score (the go struck, the base heard, drive and peak silent), never giant_battle
##                (play_story("giant_battle") in the ring changes nothing)
##   levels       stock: 0 at the start; 1 at 60 %, at 2:00 left, after 2 falls; 2 on a last life at 80 %, at 0:30 left, in
##                sudden death; each change on a bar line (the level asked for waits for it), down one step at a time
##   stingers     a KO dealt and a KO taken each play their stinger and duck the loop 9 dB, back after; a bigger one cuts
##                in within 1.5 s, a smaller one is dropped; a side's last life starting plays last_life
##   Practice     the base at -6 dB, the level held at 0, no stingers
##   the end      RingMode's restart (a countdown mid-game) and its leaving stop the score
##   classic      1 with a side in zone 2 or 60 s left; 2 with a side in its last zone or 30 s left
## METRIC ring_cue_ok, no_giant_battle_ok, stems_equal_ok, levels_ok, stingers_ok. Watchdog LIMIT_S; last line
## "RING MUSIC PASSED" or "RING MUSIC FAILED" (exit 0 only on a pass).

const NAME := "RING MUSIC"
const LIMIT_S := 400.0
const OWN_CFG := "user://ring_music_test.cfg"

var checks := 0
var fails: Array[String] = []
var metrics := {}
var lvl: RingLevel
var ring: RingArena
var player: FrontierPlayer
var mode: RingMode
var rules: RingRules
var md: MusicDirector


func _expect(ok: bool, what: String, metric := "") -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)
	if metric != "":
		metrics[metric] = bool(metrics.get(metric, true)) and ok


func _initialize() -> void:
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	MatchSetup._aim_help = "strong"
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	RingRules.rule_set_override = "stock"
	SwayCaster.free_override = true
	InputSetup.ensure()
	MatchSetup.incoming = true
	_cues()
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


## Process frames (the tweens' time; physics runs at 120 a second).
func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _until(cond: Callable, limit: float) -> float:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(limit * 1000.0):
		if cond.call():
			return (Time.get_ticks_msec() - t0) / 1000.0
		await process_frame
	return INF


func _real(s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(s * 1000.0):
		await process_frame


func _end() -> void:
	for k: String in ["ring_cue_ok", "no_giant_battle_ok", "stems_equal_ok", "levels_ok", "stingers_ok"]:
		print("METRIC %s=%s" % [k, str(bool(metrics.get(k, false))).to_lower()])
	RingRules.rule_set_override = ""
	MatchSetup.kind = "match"
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


# ---------------------------------------------------------------- the cues
func _cues() -> void:
	var cues: Dictionary = MusicDirector.M.CUES
	var d := MusicDirector.ring_data()
	var stems: Array = d.get("stems", [])
	_expect(stems == ["ring_fight_base", "ring_fight_drive", "ring_fight_peak"], "music.json names the three stems", "ring_cue_ok")
	_expect(MusicDirector.has_ring_score(), "the manifest has the three stems and the go", "ring_cue_ok")
	var lens: Array[float] = []
	var loops: Array[float] = []
	for id: Variant in stems:
		var c: Dictionary = cues.get(String(id), {})
		if c.is_empty():
			_expect(false, "%s in the manifest" % id, "stems_equal_ok")
			continue
		var w := load(String(c.path)) as AudioStreamWAV
		_expect(w != null and w.mix_rate == 44100 and w.stereo, "%s loads, 44.1 kHz stereo" % id, "stems_equal_ok")
		if w != null:
			_expect(absf(w.get_length() - float(c.length)) < 0.05, "%s: %.3f s as the manifest's %.3f" % [id, w.get_length(), float(c.length)],
					"stems_equal_ok")
		lens.append(float(c.length))
		loops.append(float(c.loop_start))
		var bar := 60.0 / float(c.bpm) * int(c.beats)
		_expect(float(c.bpm) >= 120.0 and float(c.bpm) <= 132.0 and int(c.beats) == 4, "%s: 4/4 at %.0f BPM" % [id, float(c.bpm)],
				"ring_cue_ok")
		_expect(absf(float(c.length) / bar - 32.0) < 0.01 and float(c.loop_start) == 0.0, "%s: 32 bars, looped whole" % id,
				"ring_cue_ok")
	_expect(lens.size() == 3 and lens.max() - lens.min() < 0.001 and loops.max() == loops.min(),
			"the stems: one length (%s) and one loop (%s)" % [str(lens), str(loops)], "stems_equal_ok")
	_expect(cues.has("ring_fight") and float(cues.ring_fight.loop_start) < 0.0, "the go: a one-shot cue", "ring_cue_ok")
	var stings: Dictionary = d.get("stings", {})
	for id: String in ["ko_dealt", "ko_taken", "last_life", "sudden_death", "game_won", "game_lost", "match_won", "match_lost",
			"countdown"]:
		var st: Dictionary = stings.get(id, {})
		var cue := String(st.get("cue", ""))
		var c: Dictionary = cues.get(cue, {})
		var w := load(String(c.get("path", ""))) as AudioStreamWAV if not c.is_empty() else null
		_expect(w != null and float(c.loop_start) < 0.0 and absf(w.get_length() - float(c.length)) < 0.05,
				"stinger %s: %s, a one-shot WAV" % [id, cue], "stingers_ok")


# ---------------------------------------------------------------- the match
func _run() -> void:
	await _ticks(5)
	lvl = current_scene as RingLevel
	ring = lvl.ring if lvl != null else null
	player = lvl.player if lvl != null else null
	mode = RingMode.find(self)
	rules = mode.rules if mode != null else null
	if mode == null or rules == null or not RingRules.stock_on():
		_expect(false, "a stock ring match stands")
		_end()
		return
	md = lvl.music as MusicDirector
	if md == null:
		md = MusicDirector.new()
		md.name = "MusicDirector"
		md.player = player
		lvl.add_child(md)
	await _until(func() -> bool: return md.ring_music != null, 3.0)
	_expect(md.ring_music != null and md.ring_music.mode == mode, "MusicDirector made a RingMusic for the match")
	await _fight()
	await _score()
	await _levels()
	await _stingers()
	await _restart()
	await _practice()
	await _exit()
	await _classic()
	_end()


func foe() -> NpcFighter:
	return mode.foe if mode != null and is_instance_valid(mode.foe) else null


func _fight() -> void:
	await _until(func() -> bool: return mode.phase == "COUNTDOWN" and foe() != null, 8.0)
	mode.phase_t = mode.countdown_s() - 0.6
	await _until(func() -> bool: return mode.phase == "FIGHT", 3.0)
	if foe() != null:
		foe().held = true


func _score() -> void:
	_expect(md.ring_stings.has("countdown"), "the countdown's bed played under the count (%s)" % str(md.ring_stings), "stingers_ok")
	await _ticks(2)
	_expect(md.cue == "ring_fight" and md.ring_playing() and md.mode == MusicDirector.Mode.STORY,
			"the go: the ring score plays (cue %s, mode %d)" % [md.cue, md.mode], "ring_cue_ok")
	_expect(md.started.has("ring_fight") and md.get_node_or_null(^"Sting_ring_fight") != null or md.started.count("ring_fight") >= 2,
			"the go struck once over it (%s)" % str(md.started), "ring_cue_ok")
	_expect(md.ring_stem_db(0) > -1.0 and md.ring_stem_db(1) < -40.0 and md.ring_stem_db(2) < -40.0,
			"level 0: the base heard, drive and peak silent (%.0f / %.0f / %.0f dB)" % [md.ring_stem_db(0), md.ring_stem_db(1), md.ring_stem_db(2)],
			"levels_ok")
	md.play_story("giant_battle")
	await _ticks(2)
	_expect(md.cue == "ring_fight" and md.ring_playing() and not md.started.has("giant_battle"),
			"giant_battle refused in the ring (cue %s)" % md.cue, "no_giant_battle_ok")
	_expect(not md.started.has("giant_battle"), "giant_battle never started", "no_giant_battle_ok")


## Waits for the level heard to reach `want`; returns [seconds into its bar when it landed, the wanted level a frame before].
func _lands(want: int, limit: float) -> Array:
	var bar_s := 60.0 / MusicDirector.ring_bpm() * 4.0
	var t0 := Time.get_ticks_msec()
	var waited_wanted := false
	while Time.get_ticks_msec() - t0 < int(limit * 1000.0):
		if md.ring_level == want:
			return [fmod(md.position(), bar_s), waited_wanted]
		if md.ring_level_wanted() == want:
			waited_wanted = true
		await process_frame
	return [INF, waited_wanted]


func _reset_books() -> void:
	for b: Node3D in mode.competitors():
		rules.reset_pct(b, 0.0)
		var st := rules._sk(b)
		if not st.is_empty():
			st["stocks"] = 3
	rules.falls.clear()
	rules.sudden = false
	mode.phase_t = 1.0


func _levels() -> void:
	var rm := md.ring_music
	var bar_s := 60.0 / MusicDirector.ring_bpm() * 4.0
	_reset_books()
	await _real(0.4)
	_expect(rm.compute_level() == 0 and md.ring_level == 0, "level 0 at the start (%d)" % rm.compute_level(), "levels_ok")
	# 60 % on the foe: 1, on a bar line
	rules.reset_pct(foe(), 62.0)
	await _real(0.3)
	_expect(rm.compute_level() == 1, "62 %% on a competitor: level 1 (%d)" % rm.compute_level(), "levels_ok")
	var l := await _lands(1, bar_s * 2.0 + 1.0)
	_expect(float(l[0]) < 0.2, "level 1 landed on a bar line (%.3f s into its bar)" % float(l[0]), "levels_ok")
	_expect(md.ring_stem_db(1) > -45.0, "the drive comes in (%.1f dB)" % md.ring_stem_db(1), "levels_ok")
	# the last life at 80 %: 2
	rules.reset_pct(foe(), 84.0)
	rules._sk(foe())["stocks"] = 1
	await _real(0.3)
	_expect(rm.compute_level() == 2, "a last life at 84 %%: level 2 (%d)" % rm.compute_level(), "levels_ok")
	l = await _lands(2, bar_s * 2.0 + 1.0)
	_expect(float(l[0]) < 0.2, "level 2 landed on a bar line (%.3f s into its bar)" % float(l[0]), "levels_ok")
	# back to nothing: down one step on a bar line, the next not within 8 bars
	_reset_books()
	await _real(0.3)
	_expect(rm.compute_level() == 0, "the books cleared: level 0 asked (%d)" % rm.compute_level(), "levels_ok")
	l = await _lands(1, bar_s * 2.0 + 1.0)
	var down_bar := md.ring_bar()
	_expect(float(l[0]) < 0.2 and md.ring_level == 1, "down one step to 1 on a bar line (%.3f s)" % float(l[0]), "levels_ok")
	await _real(bar_s * 3.0)
	_expect(md.ring_level == 1, "not down again within 8 bars (level %d, %d bars on)" % [md.ring_level, md.ring_bar() - down_bar],
			"levels_ok")
	# the other conditions, read straight
	mode.phase_t = mode.round_s - 115.0
	_expect(rm.compute_level() == 1, "2:00 or less left (1:55): level 1 (%d)" % rm.compute_level(), "levels_ok")
	mode.phase_t = mode.round_s - 25.0
	_expect(rm.compute_level() == 2, "0:30 or less left (0:25): level 2 (%d)" % rm.compute_level(), "levels_ok")
	mode.phase_t = 1.0
	rules.falls.append({"who": foe(), "by": player, "pct": 0.0, "tag": "", "at": 0.0, "team": 1, "left": 2, "pos": Vector3.ZERO})
	_expect(rm.compute_level() == 0, "one fall: still 0 (%d)" % rm.compute_level(), "levels_ok")
	rules.falls.append({"who": player, "by": foe(), "pct": 0.0, "tag": "", "at": 0.0, "team": 0, "left": 2, "pos": Vector3.ZERO})
	_expect(rm.compute_level() == 1, "two falls: level 1 (%d)" % rm.compute_level(), "levels_ok")
	rules.falls.clear()
	rules.reset_pct(foe(), 84.0)
	_expect(rm.compute_level() == 1, "84 %% with lives to spare: 1, not 2 (%d)" % rm.compute_level(), "levels_ok")
	rules.sudden = true
	_expect(rm.compute_level() == 2, "sudden death: level 2 (%d)" % rm.compute_level(), "levels_ok")
	rules.sudden = false
	_reset_books()


func _stingers() -> void:
	var rm := md.ring_music
	md._sting_at = -1e9
	rm._on_ko(foe(), player, 70.0, "x", 2)
	_expect(md.ring_stings.back() == "ko_dealt", "the foe's fall: ko_dealt (%s)" % str(md.ring_stings.back()), "stingers_ok")
	await _ticks(12)
	_expect(md.ring_duck_db() < -8.0, "the loop ducked under it (%.1f dB)" % md.ring_duck_db(), "stingers_ok")
	await _frames(int(60 * (2.0 + 0.6)))
	_expect(md.ring_duck_db() > -0.5, "and back after (%.1f dB)" % md.ring_duck_db(), "stingers_ok")
	md._sting_at = -1e9
	rm._on_ko(player, foe(), 90.0, "y", 2)
	_expect(md.ring_stings.back() == "ko_taken", "the player's fall: ko_taken (%s)" % str(md.ring_stings.back()), "stingers_ok")
	await _ticks(12)
	_expect(md.ring_duck_db() < -8.0, "the loop ducked (%.1f dB)" % md.ring_duck_db(), "stingers_ok")
	# within 1.5 s: a smaller one dropped, a bigger one cuts in
	var n := md.ring_stings.size()
	_expect(not md.ring_sting("last_life") and md.ring_stings.size() == n, "last_life within 1.5 s of a KO: dropped", "stingers_ok")
	_expect(md.ring_sting("sudden_death") and md.ring_stings.back() == "sudden_death", "sudden_death within 1.5 s: it cuts in",
			"stingers_ok")
	# a side's last life starting
	md._sting_at = -1e9
	rules._sk(foe())["stocks"] = 1
	rm._on_respawned(foe())
	_expect(md.ring_stings.back() == "last_life", "a last life starting: last_life (%s)" % str(md.ring_stings.back()), "stingers_ok")
	rules._sk(foe())["stocks"] = 3
	await _frames(int(60 * 3.5))


func _restart() -> void:
	_expect(md.ring_playing(), "the score plays before the restart")
	mode.restart()
	await _ticks(3)
	_expect(not md.ring_playing() and md.cue != "ring_fight", "RingMode's restart stops the score (cue %s)" % md.cue, "ring_cue_ok")
	await _fight()
	await _ticks(3)
	_expect(md.ring_playing(), "the next go starts it again", "ring_cue_ok")


func _practice() -> void:
	MatchSetup.kind = "practice"
	mode.restart()
	await _ticks(3)
	await _fight()
	await _until(func() -> bool: return md.ring_playing(), 3.0)
	_expect(mode.practice and md.ring_playing() and md.ring_practice, "Practice: the ring score plays", "levels_ok")
	var lv := int(MusicDirector.ring_num("practice_level", 0.0))
	var db := MusicDirector.LEVEL_DB + MusicDirector.ring_num("practice_base_db", -6.0)
	_expect(absf(md._ring.volume_db - db) < 0.6, "Practice: the base at %.1f dB (%.1f)" % [db, md._ring.volume_db], "levels_ok")
	md.set_ring_level(2)
	await _real(60.0 / MusicDirector.ring_bpm() * 4.0 + 0.5)
	_expect(md.ring_level == lv, "Practice: the level held at %d (%d)" % [lv, md.ring_level], "levels_ok")
	md._sting_at = -1e9
	var n := md.ring_stings.size()
	_expect(not md.ring_sting("ko_dealt") and md.ring_stings.size() == n, "Practice: no stingers", "stingers_ok")
	MatchSetup.kind = "match"
	mode.restart()
	await _ticks(3)
	await _fight()
	await _ticks(3)


func _exit() -> void:
	_expect(md.ring_playing(), "the score plays before RingMode leaves")
	mode.queue_free()
	await _ticks(3)
	_expect(not md.ring_playing(), "RingMode leaving stops the score", "ring_cue_ok")
	await _ticks(10)
	_expect(md.ring_music == null or not is_instance_valid(md.ring_music), "its RingMusic goes with it")


func _classic() -> void:
	RingRules.rule_set_override = "classic"
	MatchSetup.incoming = true
	change_scene_to_file("res://scenes/ring.tscn")
	await _ticks(6)
	lvl = current_scene as RingLevel
	mode = RingMode.find(self)
	rules = mode.rules if mode != null else null
	if mode == null or rules == null or RingRules.stock_on():
		_expect(false, "a classic ring match stands")
		return
	md = MusicDirector.new()
	md.name = "MusicDirector"
	lvl.add_child(md)
	await _until(func() -> bool: return md.ring_music != null, 3.0)
	await _fight()
	var rm := md.ring_music
	mode.phase_t = 1.0
	await _ticks(2)
	_expect(rm.compute_level() == 0, "classic: 0 at the start (%d)" % rm.compute_level(), "levels_ok")
	var st: Dictionary = rules._st(foe())
	st["confined"] = 2
	_expect(rm.compute_level() == 1, "classic: a side in zone 2: level 1 (%d)" % rm.compute_level(), "levels_ok")
	st["confined"] = rules.zones()
	_expect(rm.compute_level() == 2, "classic: a side in its last zone: level 2 (%d)" % rm.compute_level(), "levels_ok")
	st["confined"] = 1
	mode.phase_t = mode.round_s - 55.0
	_expect(rm.compute_level() == 1, "classic: 55 s left: level 1 (%d)" % rm.compute_level(), "levels_ok")
	mode.phase_t = mode.round_s - 25.0
	_expect(rm.compute_level() == 2, "classic: 25 s left: level 2 (%d)" % rm.compute_level(), "levels_ok")
	mode.phase_t = 1.0
	await _ticks(3)
	_expect(md.cue == "ring_fight" and not md.started.has("giant_battle"), "classic: the ring score too, never giant_battle",
			"no_giant_battle_ok")
