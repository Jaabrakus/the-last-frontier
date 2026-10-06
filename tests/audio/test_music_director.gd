extends SceneTree
## Headless tests of the music (scripts/audio/music_director.gd, music_manifest.gd, audio/music/, tools/music/). Re-staged in
## the 2026-10-06 cleanup (owner answers O1/O2): loc_fort, loc_wreck, story_wonder, giant_upper_hand and giant_lament are not
## rendered (their cue sources stay), and of the peoples' themes only the Vietnamese, Thai and Malay ones:
##   cues      every cue in the manifest loads (a 44.1 kHz stereo WAV as long as the manifest says); the fight's two
##             loop (giant_battle from its third bar, giant_upper_hand whole) at 144 BPM, their loops on bar lines
##   fight     a giant (a stand-in with StandInGiant's fields, in group "giants") pacing near: nothing; its temper
##             threatening within ENGAGE_R: giant_battle from its start; a knee down: giant_upper_hand on the next
##             bar line, into its loop as far as the bar line was passed; up again: back to the battle's loop; calm
##             for calm_s: the fight fades out
##   lament    the giant dying mid-fight: giant_lament, once; the fight's player fades
##   places    where the player is: the fort (the story's flatts_fort, free play too), a woods square, home (a household's
##             home); what plays there: the night's Fullmetal-Alchemist-style pieces by turns (never the same twice running),
##             night_waltz at home at dusk, the lullaby by a sleeping baby at night, the place's own piece by day, and
##             coming home from away plays its piece after SETTLE_S
##   story     MusicDirector.story(): the cue once; a giant's fight over it; StoryEffects' "music" effect; the missions'
##             three cues (story_wonder, story_sorrow, story_home) are cues in the manifest
##   creator   the character creator open (a stand-in with its script path): the chosen people's theme, crossed to the
##             next people's as the choice changes, every people of peoples.json with a theme in the manifest (looped);
##             closed: the theme fades
##   settings  the Settings' Music slider is on the Music bus (GameSettings)
##   provenance  tools/music/SOURCE.md and audio/music/SOURCE.md credit VSCO 2 CE (Versilian Studios, CC0)
##   Godot --headless --path . -s tests/audio/test_music_director.gd


class FakeBaby extends Node3D:
	var asleep := true

	func state() -> Dictionary:
		return {"asleep": asleep}

	func baby_world() -> Vector3:
		return global_position


class FakeHousehold extends Node:
	var sc: Object = RefCounted.new()
	var home := Vector3(500.0, 0.0, 500.0)
	var baby: Node


class FakeGiant extends Node3D:
	signal died
	var down_leg := ""
	var dead_side := ""
	var on := false

	func carries(_p) -> bool:
		return on

	func where() -> Vector3:
		return global_position


var failures := PackedStringArray()
var checks := 0


func _initialize() -> void:
	_cues()
	await _fight()
	await _places()
	await _story()
	await _creator()
	_settings()
	_provenance()
	print("%d checks, %d failed" % [checks, failures.size()])
	for f in failures:
		print("  FAIL ", f)
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func _cues() -> void:
	var cues: Dictionary = MusicDirector.M.CUES
	for id in ["loc_fort", "loc_wreck", "story_wonder", "giant_upper_hand", "giant_lament"]:
		_check(not cues.has(id) and not ResourceLoader.exists("res://audio/music/%s.wav" % id)
				and FileAccess.file_exists("res://tools/music/cues/%s.py" % id),
				"%s: not rendered, its cue source kept (re-renderable)" % id)
	for id in ["main_theme", "explore_day", "explore_dusk", "explore_night", "giant_battle",
			"night_waltz", "lullaby", "night_elegy", "story_sorrow", "story_home",
			"loc_farms", "loc_river", "loc_woods", "loc_cliffs", "loc_marsh"]:
		_check(cues.has(id), "manifest has %s" % id)
		if not cues.has(id):
			continue
		var c: Dictionary = cues[id]
		var w := load(String(c.path)) as AudioStreamWAV
		_check(w != null, "%s loads as a WAV" % id)
		if w == null:
			continue
		_check(w.mix_rate == 44100 and w.stereo, "%s: 44.1 kHz stereo (%d, %s)" % [id, w.mix_rate, w.stereo])
		var secs := w.get_length()
		_check(absf(secs - float(c.length)) < 0.05, "%s: %.2f s as the manifest's %.2f" % [id, secs, float(c.length)])
	for id in ["giant_battle"]:
		var c: Dictionary = cues[id]
		var bar := 60.0 / float(c.bpm) * int(c.beats)
		_check(float(c.bpm) == 144.0, "%s at 144 BPM" % id)
		_check(float(c.loop_start) >= 0.0, "%s loops" % id)
		var ls := float(c.loop_start) / bar
		var le := float(c.length) / bar
		_check(absf(ls - round(ls)) < 0.01 and absf(le - round(le)) < 0.01,
				"%s loops on bar lines (%.3f to %.3f bars)" % [id, ls, le])
	_check(absf(float(cues.giant_battle.loop_start) - 2.0 * 60.0 / 144.0 * 4.0) < 0.01, "the battle loops from bar 2")
	for id in ["main_theme", "explore_day"]:
		_check(float(cues[id].loop_start) < 0.0, "%s plays once" % id)


func _fight() -> void:
	var level := Node3D.new()
	root.add_child(level)
	var player := Node3D.new()
	level.add_child(player)
	var g := FakeGiant.new()
	g.position = Vector3(20.0, 0.0, 0.0)
	g.add_to_group(&"giants")
	level.add_child(g)
	var temper := Node.new()
	temper.name = "Temper"
	temper.set_script(_temper_script())
	g.add_child(temper)
	var d := MusicDirector.new()
	d.player = player
	d.calm_s = 0.6
	level.add_child(d)
	await _wait(0.4)
	_check(d.cue == "" and d.mode == MusicDirector.Mode.QUIET, "a giant pacing: no music (%s)" % d.cue)

	temper.set("mood", "threat")
	await _wait(0.4)
	_check(d.mode == MusicDirector.Mode.FIGHT and d.cue == "giant_battle", "it threatens: the battle (%s)" % d.cue)
	var first := d.get_node_or_null(^"Cue_giant_battle") as AudioStreamPlayer
	_check(first != null and first.bus == MusicDirector.BUS, "on the Music bus")
	_check(AudioServer.get_bus_index(MusicDirector.BUS) != -1, "the Music bus is made")
	var w := first.stream as AudioStreamWAV if first else null
	_check(w != null and w.loop_mode == AudioStreamWAV.LOOP_FORWARD
			and w.loop_begin == int(round(float(MusicDirector.M.CUES.giant_battle.loop_start) * 44100.0)),
			"the battle's stream loops from its loop start")

	g.down_leg = "FL"
	await _wait(0.3 + 60.0 / 144.0 * 4.0)
	_check(d.mode == MusicDirector.Mode.FIGHT and d.cue == "giant_battle",
			"a knee down: the battle goes on (the upper hand not rendered) (%s)" % d.cue)
	g.down_leg = ""
	g.on = true
	await _wait(0.3)
	_check(d.mode == MusicDirector.Mode.FIGHT, "the player on it: still the battle")
	g.on = false
	temper.set("mood", "calm")
	g.position = Vector3(200.0, 0.0, 0.0)
	await _wait(1.3)
	_check(d.mode == MusicDirector.Mode.QUIET and d.cue == "", "calm and far: the fight fades (%s)" % d.cue)
	_check(d._hush_until > d._clock, "after the fight a hush before any place's piece")

	# a fight again, and the giant dies in it
	g.position = Vector3(20.0, 0.0, 0.0)
	temper.set("mood", "charge")
	await _wait(0.4)
	_check(d.mode == MusicDirector.Mode.FIGHT, "it charges: the battle again")
	g.dead_side = "L"
	g.died.emit()
	await _wait(0.1)
	_check(d.mode == MusicDirector.Mode.QUIET, "it dies: the fight fades out (the lament not rendered) (%s)" % d.mode)
	await _wait(1.2)
	_check(d.cue == "" or d.cue == "giant_battle", "and nothing new starts (%s)" % d.cue)
	level.queue_free()
	await _wait(0.1)


func _places() -> void:
	var level := Node3D.new()
	root.add_child(level)
	var player := Node3D.new()
	level.add_child(player)
	var d := MusicDirector.new()
	d.player = player
	level.add_child(d)
	await _wait(0.1)
	_check(d.locate(Vector3(10.0, 0.0, 10.0)) != "loc_fort", "at the fort: not loc_fort (not rendered): the square's (%s)" % d.locate(Vector3(10.0, 0.0, 10.0)))
	var woods := Vector2i(99, 99)
	for sq in WorldSquares.squares():
		if WorldSquares.type_id(sq) == "deep_woods":
			woods = sq
	if woods != Vector2i(99, 99):
		var at := WorldSquares.center_of(woods)
		_check(d.locate(at) == "loc_woods", "in the deep woods: loc_woods (%s)" % d.locate(at))
	# the night's pieces by turns, never the same twice running
	d.band_override = "night"
	d.where = ""
	var seen := {}
	var last := ""
	var repeats := 0
	for i in 30:
		d._last_piece = last
		var p := d.pick()
		seen[p] = true
		if p == last:
			repeats += 1
		last = p
	_check(seen.size() == 3 and seen.has("night_waltz") and seen.has("lullaby") and seen.has("night_elegy"),
			"night: the three night pieces (%s)" % str(seen.keys()))
	_check(repeats == 0, "night: never the same piece twice running (%d)" % repeats)
	d.band_override = "day"
	d.where = "loc_cliffs"
	_check(d.pick() == "loc_cliffs", "by day on the cliffs: their piece (%s)" % d.pick())
	d.where = ""
	_check(d.pick() == "explore_day", "by day nowhere in particular: explore_day (%s)" % d.pick())
	d.band_override = "dusk"
	_check(d.pick() in ["explore_dusk", "explore_night"], "dusk: a dusk piece (%s)" % d.pick())
	# home: a household's home; the waltz at dusk, the lullaby by a sleeping baby at night
	var h := FakeHousehold.new()
	h.add_to_group(&"household")
	level.add_child(h)
	var baby := FakeBaby.new()
	level.add_child(baby)
	baby.global_position = h.home + Vector3(3.0, 0.0, 0.0)
	h.baby = baby
	_check(d.locate(h.home + Vector3(5.0, 0.0, 0.0)) == "home", "by the household's home: home")
	player.global_position = h.home + Vector3(5.0, 0.0, 0.0)
	d.where = "home"
	_check(d.pick() == "night_waltz", "home at dusk: night_waltz (%s)" % d.pick())
	d.band_override = "night"
	_check(d.pick() == "lullaby", "home at night by the sleeping baby: the lullaby (%s)" % d.pick())
	baby.asleep = false
	_check(d.pick() == "night_waltz", "home at night, the baby awake: night_waltz (%s)" % d.pick())
	# coming home from away at dusk plays its piece once settled
	d.band_override = "dusk"
	player.global_position = Vector3(10.0, 0.0, 10.0)
	await _wait(0.4)
	d._clock += MusicDirector.AWAY_S + 1.0
	d._played.clear()
	player.global_position = h.home + Vector3(5.0, 0.0, 0.0)
	await _wait(0.4)
	_check(d.where == "home" and d.cue == "", "home: nothing before settling (%s)" % d.cue)
	d._where_t = MusicDirector.SETTLE_S
	await _wait(0.4)
	_check(d.cue == "night_waltz" and d.mode == MusicDirector.Mode.EXPLORE, "home after being away: night_waltz (%s)" % d.cue)
	level.queue_free()
	await _wait(0.1)


func _story() -> void:
	var level := Node3D.new()
	root.add_child(level)
	var player := Node3D.new()
	level.add_child(player)
	player.global_position = Vector3(3000.0, 0.0, 3000.0)
	var d := MusicDirector.new()
	d.player = player
	level.add_child(d)
	await _wait(0.1)
	MusicDirector.story(level.get_tree(), "story_sorrow")
	_check(d.mode == MusicDirector.Mode.STORY and d.cue == "story_sorrow", "a mission's cue plays (%s)" % d.cue)
	var g := FakeGiant.new()
	g.add_to_group(&"giants")
	level.add_child(g)
	g.global_position = player.global_position + Vector3(10.0, 0.0, 0.0)
	var t := Node.new()
	t.name = "Temper"
	t.set_script(_temper_script())
	g.add_child(t)
	t.set("mood", "charge")
	await _wait(0.4)
	_check(d.cue == "giant_battle", "a giant's fight over the story's cue (%s)" % d.cue)
	MusicDirector.story(level.get_tree(), "story_home")
	_check(d.cue == "giant_battle", "no story cue over the fight (%s)" % d.cue)
	g.queue_free()
	d.calm_s = 0.3
	await _wait(0.9)
	var sd := StoryDirector.new()
	level.add_child(sd)
	StoryEffects.do_one(sd, {"do": "music", "cue": "story_home"})
	_check(d.cue == "story_home", "StoryEffects' music effect plays its cue (%s)" % d.cue)
	StoryEffects.do_one(sd, {"do": "music", "cue": ""})
	_check(d.cue == "" and d.mode == MusicDirector.Mode.QUIET, "an empty cue fades the story's music")
	var txt := FileAccess.get_file_as_string("res://data/story/missions/two_fires.json")
	for id in ["story_sorrow", "story_home"]:
		_check(txt.contains("\"cue\": \"%s\"" % id), "the missions call %s" % id)
	level.queue_free()
	await _wait(0.1)


func _creator() -> void:
	var peoples: Array = (JSON.parse_string(FileAccess.get_file_as_string("res://assets/character/body/peoples.json"))
			as Dictionary).get("peoples", [])
	var themed := []
	for e in peoples:
		var pid := String((e as Dictionary).get("id", ""))
		var c: Dictionary = MusicDirector.M.CUES.get("people_" + pid, {})
		if not c.is_empty() and float(c.loop_start) >= 0.0:
			themed.append(pid)
	themed.sort()
	_check(themed == ["malay", "thai", "vietnamese"], "the Vietnamese, Thai and Malay peoples have looped themes, the others none (%s)" % [themed])
	var level := Node3D.new()
	root.add_child(level)
	var player := Node3D.new()
	level.add_child(player)
	var d := MusicDirector.new()
	d.player = player
	var fake := GDScript.new()
	fake.source_code = "extends CanvasLayer\nvar look := {}\n"
	fake.reload()
	fake.resource_path = "res://tests/audio/_stand_in_creator.gd"
	d.creator_script = fake.resource_path
	level.add_child(d)
	await _wait(0.1)
	var cc := CanvasLayer.new()
	cc.set_script(fake)
	cc.set("look", {"people": "vietnamese"})
	root.add_child(cc)
	await _wait(0.4)
	_check(d.mode == MusicDirector.Mode.CREATOR and d.cue == "people_vietnamese", "the creator open: the Vietnamese theme (%s)" % d.cue)
	cc.set("look", {"people": "thai"})
	await _wait(0.4)
	_check(d.cue == "people_thai", "another people chosen: its theme (%s)" % d.cue)
	cc.set("look", {"people": "japanese"})
	await _wait(0.4)
	_check(d.mode == MusicDirector.Mode.CREATOR and d.cue == "people_thai", "a people with no theme: the last one plays on (%s)" % d.cue)
	cc.queue_free()
	await _wait(0.5)
	_check(d.mode == MusicDirector.Mode.QUIET and d.cue == "", "the creator closed: the theme fades (%s)" % d.cue)
	level.queue_free()
	await _wait(0.1)


func _settings() -> void:
	_check(GameSettings.BUSES.get("music", &"") == MusicDirector.BUS, "the Music slider's bus")
	_check(GameSettings.DEFAULTS.audio.has("music"), "a Music volume in the settings")


func _provenance() -> void:
	var src := FileAccess.get_file_as_string("res://tools/music/SOURCE.md")
	_check(src.contains("VSCO") and src.contains("Versilian") and src.contains("CC0"), "tools/music/SOURCE.md")
	var here := FileAccess.get_file_as_string("res://audio/music/SOURCE.md")
	_check(here.contains("VSCO") and here.contains("Versilian") and here.contains("CC0"), "audio/music/SOURCE.md")


func _temper_script() -> GDScript:
	var s := GDScript.new()
	s.source_code = "extends Node\nvar mood := \"calm\"\n"
	s.reload()
	return s


func _wait(secs: float) -> void:
	await create_timer(secs).timeout
