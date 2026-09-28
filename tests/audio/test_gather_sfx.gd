extends SceneTree
## Headless tests of the gathering sounds (push n12s: scripts/audio/gather_sfx.gd, audio/sfx/gathering_rec/,
## tools/sfx/gathering_rec.py):
##   ids        every id GatherSfx can play is in the Sfx manifest with loadable variants (at least 3, 44.1 kHz
##              16-bit PCM WAVs, uncompressed import), on the World bus with sound travel and a sane 3D range
##   events     each gathering event plays its own ids and no other event's: a mining strike a pick id (the hard
##              stroke more often with skill), a piece breaking off rock_split, the last one rock_depleted, a chop
##              into a thin / thick trunk axe_chop / axe_chop_big, a sapling axe_chop_sapling, bucking buck, the
##              tree going over tree_crack + tree_fall, its landing tree_land
##   fall       fall_time (when the swish is started) against the pole fall FelledTree integrates; if the
##              gathering push (FelledTree) is in the project, against a real FelledTree's fall on the level's
##              terrain
##   play       the sounds go out through Sfx (headless, Dummy audio driver: the voices start, nothing is heard):
##              a chop starts a World-bus voice on a gather_rec_axe_chop file with the manifest's range, level
##              and a little random pitch; a tree going over 30 m away starts its crack after the sound's travel
##              time and its swish (fall_s - 1.6 s + travel) later, before the landing
##   files      the recordings' provenance travels with the sounds: SOURCE.md names every pack, author, URL and
##              the CC0 licence, CREDITS.md credits the packs; no id or file shares a name with the gathering
##              push's own synthesized sounds (audio/sfx/gathering/)
##
##   Godot --headless --path . -s tests/audio/test_gather_sfx.gd [-- only=ids,events,fall,play,files]

const REC_DIR := "res://audio/sfx/gathering_rec/"
const PACK_AUTHORS := ["Kenney", "kheetor", "rubberduck"]
const PACK_URLS := ["https://kenney.nl/assets/impact-sounds", "https://kenney.nl/assets/rpg-audio",
		"https://opengameart.org/content/tree-chop-fall-thud",
		"https://opengameart.org/content/75-cc0-breaking-falling-hit-sfx",
		"https://opengameart.org/content/100-cc0-metal-and-wood-sfx", "https://opengameart.org/content/100-cc0-sfx-2"]

var failures := PackedStringArray()
var checks := 0
var only := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.get_slice("=", 1)
	var t0 := Time.get_ticks_msec()
	for part in ["ids", "events", "fall", "play", "files"]:
		if only != "" and not part in only.split(","):
			continue
		var n0 := failures.size()
		await call("_test_" + part)
		print("  %s %s" % ["ok  " if failures.size() == n0 else "FAIL", part])
	print("gather sfx: %d checks, %d failed (%d ms)" % [checks, failures.size(), Time.get_ticks_msec() - t0])
	for f in failures:
		printerr("  FAIL " + f)
	print("GATHER SFX TEST %s" % ("PASSED" if failures.is_empty() else "FAILED"))
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func _all_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for ev: String in GatherSfx.EVENTS:
		for id: StringName in GatherSfx.EVENTS[ev]:
			if not out.has(id):
				out.append(id)
	return out


# --- ids ------------------------------------------------------------------------------------------------

func _test_ids() -> void:
	var ids := _all_ids()
	_check(ids.size() == 11, "11 gathering ids (%d)" % ids.size())
	for id in ids:
		_check(String(id).begins_with("gather_rec_"), "%s has the gather_rec_ prefix" % id)
		_check(Sfx.has(id), "%s is in the Sfx manifest with playable files" % id)
		var vs := Sfx.variants(id)
		_check(vs.size() >= 3, "%s has %d variants (want 3 or more: no machine-gun repetition)" % [id, vs.size()])
		for s in vs:
			var w := s as AudioStreamWAV
			_check(w != null and w.mix_rate == 44100 and w.format == AudioStreamWAV.FORMAT_16_BITS and not w.stereo,
					"%s: a 44.1 kHz 16-bit mono PCM WAV (uncompressed import) (%s)" % [id, s.resource_path])
			if w:
				_check(w.get_length() > 0.1 and w.get_length() < 3.2, "%s: %.2f s long" % [s.resource_path, w.get_length()])
		var c := Sfx.config(id)
		_check(String(c.get("bus", "")) == "World", "%s on the World bus (outdoor reverb) (%s)" % [id, c.get("bus", "")])
		_check(bool(c.get("travel", false)), "%s is heard late from afar (travel)" % id)
		_check(float(c.get("unit", 0.0)) >= 3.0 and float(c.get("maxd", 0.0)) >= 60.0 and float(c.get("maxd", 0.0)) <= 500.0,
				"%s: unit %.1f m, max distance %.0f m" % [id, float(c.get("unit", 0.0)), float(c.get("maxd", 0.0))])
		_check(float(c.get("rp", 1.0)) > 1.0 and float(c.get("rp", 1.0)) <= 1.08, "%s: a small random pitch (%.3f)" % [id, float(c.get("rp", 1.0))])
		_check(float(c.get("vol", 99.0)) > -14.0 and float(c.get("vol", 99.0)) <= 1.0, "%s: volume %.1f dB" % [id, float(c.get("vol", 99.0))])
	# the ones heard from farthest carry farthest
	_check(float(Sfx.config(&"gather_rec_tree_land").get("maxd", 0.0)) > float(Sfx.config(&"gather_rec_axe_chop").get("maxd", 0.0)),
			"a tree landing carries farther than a chop")
	_check(float(Sfx.config(&"gather_rec_axe_chop_sapling").get("maxd", 0.0)) < float(Sfx.config(&"gather_rec_axe_chop").get("maxd", 0.0)),
			"a sapling cut carries less far than a chop into a trunk")


# --- events ---------------------------------------------------------------------------------------------

## Runs `fn` with a fresh log and returns the ids it played.
func _ids_of(fn: Callable) -> Array[StringName]:
	GatherSfx.reset_log()
	fn.call()
	return GatherSfx.played.duplicate()


func _test_events() -> void:
	GatherSfx.rng.seed = 1765
	var at := Vector3(3.0, 0.0, -20.0)
	var own := {}          # event -> ids it played
	var hard := [0, 0]     # hard strokes at level 0 / level 100, of 60 each
	own["mining_strike"] = _ids_of(func() -> void:
		for k in 60:
			hard[0] += 1 if GatherSfx.mining_strike(at, 1.0) == &"gather_rec_pick_rock_hard" else 0)
	own["mining_strike"] += _ids_of(func() -> void:
		for k in 60:
			hard[1] += 1 if GatherSfx.mining_strike(at, 1.8) == &"gather_rec_pick_rock_hard" else 0)
	_check(hard[0] >= 2 and hard[0] <= 20, "at level 0 about 15 %% of the strokes bite deep (%d of 60)" % hard[0])
	_check(hard[1] >= 40 and hard[1] <= 58, "at level 100 about 85 %% do (%d of 60)" % hard[1])
	own["stone_breaks"] = _ids_of(func() -> void:
		_check(GatherSfx.stone_breaks(at, false) == &"gather_rec_rock_split", "a piece breaking off plays rock_split")
		_check(GatherSfx.stone_breaks(at, true) == &"gather_rec_rock_depleted", "the last piece plays rock_depleted"))
	own["chop"] = _ids_of(func() -> void:
		_check(GatherSfx.chop(at, 0.35) == &"gather_rec_axe_chop", "a chop into a 35 cm trunk plays axe_chop")
		_check(GatherSfx.chop(at, 0.9) == &"gather_rec_axe_chop_big", "a chop into a 90 cm trunk plays axe_chop_big"))
	own["sapling"] = _ids_of(func() -> void:
		_check(GatherSfx.sapling(at) == &"gather_rec_axe_chop_sapling", "a sapling stroke plays axe_chop_sapling"))
	own["buck"] = _ids_of(func() -> void:
		_check(GatherSfx.buck(at, 0.4) == &"gather_rec_buck", "bucking plays buck"))
	own["tree_falls"] = _ids_of(func() -> void:
		_check(GatherSfx.tree_falls(at, Vector3(1, 0, 0), 18.0, 4.0) == &"gather_rec_tree_fall", "the fall returns the swish"))
	_check(own["tree_falls"] == [&"gather_rec_tree_crack", &"gather_rec_tree_fall"],
			"a tree going over plays the hinge crack, then the swish: %s" % [own["tree_falls"]])
	own["tree_lands"] = _ids_of(func() -> void:
		_check(GatherSfx.tree_lands(at, 18.0) == &"gather_rec_tree_land", "the landing plays tree_land"))
	# each event's ids are its own, and each of them can be heard
	for ev: String in own:
		var allowed: Array = GatherSfx.EVENTS[ev]
		for id: StringName in own[ev]:
			_check(allowed.has(id), "%s played %s, not one of its own %s" % [ev, id, allowed])
		for id: StringName in allowed:
			_check((own[ev] as Array).has(id), "%s can be heard playing %s" % [ev, id])
	var seen := {}
	for ev: String in GatherSfx.EVENTS:
		for id: StringName in GatherSfx.EVENTS[ev]:
			_check(not seen.has(id), "%s belongs to %s and %s" % [id, seen.get(id, ""), ev])
			seen[id] = ev
	# the log keeps the latest MAX_LOG ids
	_ids_of(func() -> void:
		for k in GatherSfx.MAX_LOG + 10:
			GatherSfx.buck(at))
	_check(GatherSfx.played.size() == GatherSfx.MAX_LOG, "the log keeps %d ids" % GatherSfx.MAX_LOG)
	_check(int(GatherSfx.counts.get(&"gather_rec_buck", 0)) == GatherSfx.MAX_LOG + 10, "counts keeps every play")
	GatherSfx.reset_log()
	_check(GatherSfx.played.is_empty() and GatherSfx.counts.is_empty(), "reset_log clears both")


# --- fall -----------------------------------------------------------------------------------------------

func _test_fall() -> void:
	var t12 := GatherSfx.fall_time(12.0)
	var t18 := GatherSfx.fall_time(18.0)
	var t25 := GatherSfx.fall_time(25.0)
	print("    fall_time: 12 m %.2f s, 18 m %.2f s, 25 m %.2f s" % [t12, t18, t25])
	_check(t12 < t18 and t18 < t25, "taller trees take longer to come down")
	_check(t18 > 2.5 and t25 < 6.5, "a 15-25 m tree comes down in about 3-5 s (FelledTree's own figure): %.2f / %.2f s" % [t18, t25])
	_check(t12 > GatherSfx.FALL_PEAK_S, "even a small tree falls longer than the swish's lead-in (%.2f s)" % t12)
	var fast := GatherSfx.fall_time(18.0, {"fall_push": 0.4})
	_check(fast < t18, "a harder push brings it down sooner (%.2f < %.2f s)" % [fast, t18])
	# against the real fall, once the gathering push is in the project
	if not ResourceLoader.exists("res://scripts/gathering/felled_tree.gd"):
		print("    (no FelledTree in this project yet: the real-fall comparison runs after the gathering push merges)")
		return
	var FT: GDScript = load("res://scripts/gathering/felled_tree.gd")
	var felling := {}
	var gd_path := "res://data/gathering/gathering.json"
	if FileAccess.file_exists(gd_path):
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(gd_path))
		if j is Dictionary:
			felling = (j as Dictionary).get("felling", {})
	for h: float in [12.0, 18.0, 26.0]:
		var x := 40.0 + h
		var z := -60.0
		var ground := FrontierTerrain.height_at(x, z)
		var d := {"i": 0, "pos": Vector3(x, ground, z), "height": h, "radius": 0.25, "crown_bottom": h * 0.4,
				"crown_radius": 3.0, "kind": 0, "variant": 0}
		var ft: Node3D = FT.call("create", d, Vector3(1, 0, 0), felling, false)
		var landed := [false]
		ft.connect("landed", func(_f: Node3D) -> void: landed[0] = true)
		var t := 0.0
		while not landed[0] and t < 20.0:
			ft.call("_physics_process", 1.0 / 120.0)
			t += 1.0 / 120.0
		var length := float(ft.get("length"))
		var pred := GatherSfx.fall_time(length, felling)
		print("    FelledTree %.0f m: lands after %.2f s, fall_time %.2f s" % [h, t, pred])
		_check(landed[0] and absf(t - pred) < 0.25, "fall_time within 0.25 s of a real %.0f m FelledTree's fall (%.2f vs %.2f s)" % [h, pred, t])
		ft.free()


# --- play -------------------------------------------------------------------------------------------------

func _voices(id: StringName) -> Array[AudioStreamPlayer3D]:
	var out: Array[AudioStreamPlayer3D] = []
	var r := Sfx._get_runner()
	if r == null:
		return out
	for p in r.voices3:
		if p.playing and p.stream and p.stream.resource_path.get_file().begins_with(String(id) + "_"):
			out.append(p)
	return out


func _test_play() -> void:
	var level := Node3D.new()
	level.name = "GatherSfxPlay"
	root.add_child(level)
	var cam := Camera3D.new()
	level.add_child(cam)
	cam.current = true
	Sfx.setup(level)
	await process_frame
	GatherSfx.audible_headless = true
	GatherSfx.rng.seed = 11
	GatherSfx.reset_log()
	# a chop 4 m away: at once (inside Sfx's 10 m, no travel delay)
	GatherSfx.chop(Vector3(0, 0, -4), 0.4)
	var v := _voices(&"gather_rec_axe_chop")
	_check(v.size() == 1, "a chop starts one voice (%d)" % v.size())
	if v.size() == 1:
		var p := v[0]
		var c := Sfx.config(&"gather_rec_axe_chop")
		_check(p.stream.resource_path.begins_with(REC_DIR), "from gathering_rec/ (%s)" % p.stream.resource_path)
		_check(p.bus == &"World", "on the World bus (%s)" % p.bus)
		_check(is_equal_approx(p.unit_size, float(c.unit)) and is_equal_approx(p.max_distance, float(c.maxd)),
				"the manifest's range (unit %.1f, max %.0f m)" % [p.unit_size, p.max_distance])
		var vol := float(c.vol)
		_check(absf(p.volume_db - vol) <= 1.0 + float(c.rv) * 0.5 + 0.01, "its level %.1f dB near the manifest's %.1f" % [p.volume_db, vol])
		_check(p.pitch_scale > 0.9 and p.pitch_scale < 1.12 and not is_equal_approx(p.pitch_scale, 1.0),
				"a little random pitch (%.3f)" % p.pitch_scale)
	# ten more strokes: different variants, never the same file twice running
	var files: Array[String] = []
	for k in 10:
		GatherSfx.mining_strike(Vector3(0, 0, -3), 1.0)
		var r := Sfx._get_runner()
		var newest: AudioStreamPlayer3D = null
		for p in r.voices3:
			if p.playing and (newest == null or int(p.get_meta(&"serial", 0)) > int(newest.get_meta(&"serial", 0))):
				newest = p
		files.append(newest.stream.resource_path.get_file() if newest and newest.stream else "")
	var repeats := 0
	for k in range(1, files.size()):
		repeats += 1 if files[k] == files[k - 1] else 0
	var distinct := {}
	for f in files:
		distinct[f] = true
	_check(repeats == 0 and distinct.size() >= 4, "strokes vary: %d files over 10 strokes, %d repeats in a row" % [distinct.size(), repeats])
	# a tree 30 m away: the crack after the travel time, the swish so its peak meets the landing 2 s from now.
	# Sfx counts a pending play down by whole frame deltas, so the times are measured from the start of a frame
	var stump := Vector3(0, 0, -30)
	await process_frame
	await process_frame
	var t0 := Time.get_ticks_msec()
	GatherSfx.tree_falls(stump, Vector3(1, 0, 0), 18.0, 2.0)
	var crack_ms := -1
	var swish_ms := -1
	while Time.get_ticks_msec() - t0 < 1500 and (crack_ms < 0 or swish_ms < 0):
		await process_frame
		if crack_ms < 0 and not _voices(&"gather_rec_tree_crack").is_empty():
			crack_ms = Time.get_ticks_msec() - t0
		if swish_ms < 0 and not _voices(&"gather_rec_tree_fall").is_empty():
			swish_ms = Time.get_ticks_msec() - t0
	var travel_ms := Sfx.travel_delay(stump + Vector3.UP) * 1000.0
	var want_gap := (2.0 - GatherSfx.FALL_PEAK_S) * 1000.0 + Sfx.travel_delay(stump + Vector3(1, 1, 0) * 8.1) * 1000.0 - travel_ms
	print("    tree 30 m away: crack after %d ms (travel %.0f ms), swish %d ms after it (want %.0f)" % [crack_ms, travel_ms,
			swish_ms - crack_ms, want_gap])
	_check(crack_ms >= travel_ms - 40.0 and crack_ms < travel_ms + 120.0, "the crack arrives after the sound's travel from 30 m (%d ms)" % crack_ms)
	_check(swish_ms > 0 and absf(swish_ms - crack_ms - want_gap) < 60.0, "the swish starts %.0f ms after the crack (%d ms)"
			% [want_gap, swish_ms - crack_ms])
	GatherSfx.audible_headless = false
	level.queue_free()
	await process_frame
	await process_frame
	Sfx._cache.clear()
	Sfx._last.clear()


# --- files ----------------------------------------------------------------------------------------------

func _test_files() -> void:
	var src := FileAccess.get_file_as_string(REC_DIR + "SOURCE.md")
	_check(src != "", "audio/sfx/gathering_rec/SOURCE.md is there")
	_check(src.contains("CC0 1.0"), "SOURCE.md names the CC0 1.0 licence")
	for a in PACK_AUTHORS:
		_check(src.contains(a), "SOURCE.md names %s" % a)
	for u in PACK_URLS:
		_check(src.contains(u), "SOURCE.md links %s" % u)
	var man: Variant = JSON.parse_string(FileAccess.get_file_as_string(REC_DIR + "MANIFEST.json"))
	_check(man is Dictionary and (man as Dictionary).get("takes", []).size() > 10,
			"MANIFEST.json lists the source takes")
	if man is Dictionary:
		for t: Dictionary in (man as Dictionary).get("takes", []):
			_check(String(t.get("license", "")).begins_with("CC0") and String(t.get("url", "")).begins_with("https://")
					and String(t.get("sha256", "")).length() == 64, "take %s: licence, URL and hash" % t.get("file", "?"))
	var credits := FileAccess.get_file_as_string("res://CREDITS.md")
	_check(credits.contains("audio/sfx/gathering_rec/") and credits.contains("CC0"), "CREDITS.md credits the recordings")
	# nothing shares a name with the gathering push's synthesized sounds
	for f in DirAccess.get_files_at(REC_DIR):
		_check(f.begins_with("gather_rec_") or f in ["SOURCE.md", "MANIFEST.json", "gathering_rec_manifest.json"]
				or f.ends_with(".import"), "only gather_rec_ files in gathering_rec/ (%s)" % f)
	for id in _all_ids():
		for s in Sfx.variants(id):
			_check(s.resource_path.begins_with(REC_DIR), "%s plays from gathering_rec/ (%s)" % [id, s.resource_path])
