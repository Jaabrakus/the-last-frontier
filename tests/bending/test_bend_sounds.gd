extends SceneTree
## The ring's own sounds (improvement round 1, 2026-10-05: BendSounds, audio/sfx/bend/, tools/sfx/bend/bend_sfx.py).
## Headless:
##   Godot --headless --fixed-fps 60 --path . -s tests/bending/test_bend_sounds.gd [-- only=table,moves,...]
##   table     every id of BendSounds.TABLE has its files (at least 3 variants, the murmur's 2 loops), each a 44.1 kHz
##             16-bit mono WAV imported uncompressed, no sample at full scale; a bus the game has, a sane 3D range;
##             levels.json lists every file under -0.9 dBFS
##   moves     every mode of every move with a bend spec (data/sway/moves.json) casts a sound with files, of its own
##             element's family (a zone's too: a zone's spec has no kind, BendEffects hands "stone"); every hit kind
##             (BendLooks.KINDS and steam) and every moment (EVENTS) resolves to a sound with files
##   borrowed  nothing of the frontier game's sounds is left in the bending's table: no TABLE id is an Sfx manifest id of
##             the frontier game's files (the few Sfx plays for form_sfx are these same files) or one of the ids BendLooks
##             borrowed, every file is under audio/sfx/bend/, BendLooks has no SOUNDS table
##   route     BendLooks.sound hands on to BendSounds: a cast is told by BendEffects' current cast (a water bubble zone
##             handed in as "stone" sloshes), a stone hit where a caught stone is held is the catch, a water hit at a
##             ring pool's surface the ring-out splash, else the kind's hit
##   voices    (voices made headless for this) one id never more than its cap at once, all of them never more than
##             MAX_VOICES; the same id again within SAME_S at the same place is dropped; the jitter never moves the
##             game's global dice
##   crowd     the ring's dressing (visuals forced on) loops the murmur at four places in the stands; the mood rising to a
##             knock-back's cheers or gasps, falling back says nothing, rising to a ring-out's roars and groans
##   words     no show words in the ids or the events' names
## The last line: "BEND SOUNDS TEST PASSED" or "BEND SOUNDS TEST FAILED". Exit 0 only on a pass.

const OLD_IDS := ["gather_rec_rock_split", "gather_rec_pick_rock_hard", "arrow_whoosh", "land_dirt", "torch_ignite",
		"torch_toss", "musket_shot", "pan_flash", "torch_snuff"]
const FAMILY := {"earth": ["earth_", "stone_", "mend"], "water": ["water_", "ice_", "heal"],
		"fire": ["fire_", "lightning_"], "air": ["air_"]}
const SHOW_WORDS := ["avatar", "bender", "bending", "korra", "aang", "katara", "toph", "zuko", "nation", "airbender",
		"firebend", "waterbend", "earthbend"]
const SfxManifest := preload("res://scripts/audio/sfx_manifest.gd")

var checks := 0
var fails: Array[String] = []
var only := ""


func _expect(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		print("  FAIL " + what)
		fails.append(what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	seed(1750)
	create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("BEND SOUNDS TEST FAILED (watchdog)")
		quit(2))
	MatchSetup._aim_help = "light"              # (the ring is loaded below; nothing here aims)
	GameSettings.path = "user://test_bend_sounds.cfg"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.get_slice("=", 1)
	InputSetup.ensure()
	_run.call_deferred()


func _run() -> void:
	await _frames(2)
	var t0 := Time.get_ticks_msec()
	for part in ["table", "moves", "borrowed", "route", "voices", "crowd", "words"]:
		if only != "" and not part in only.split(","):
			continue
		var n0 := fails.size()
		await call("_test_" + part)
		print("  %s %s" % ["ok  " if fails.size() == n0 else "FAIL", part])
	print("bend sounds: %d checks, %d failed (%d ms)" % [checks, fails.size(), Time.get_ticks_msec() - t0])
	GameSettings.path = GameSettings.PATH
	print("BEND SOUNDS TEST %s" % ("PASSED" if fails.is_empty() else "FAILED"))
	quit(0 if fails.is_empty() else 1)


# ---------------------------------------------------------------- table
func _test_table() -> void:
	var files := 0
	for id: StringName in BendSounds.TABLE:
		var n := BendSounds.count(id)
		_expect(n >= (2 if id == &"crowd_murmur" else 3), "%s has %d variants (3 or more; the murmur's loops 2)" % [id, n])
		var c: Dictionary = BendSounds.TABLE[id]
		_expect(String(c.bus) in ["World", "SFX", "Ambience"], "%s on a bus of Sfx's (%s)" % [id, c.bus])
		_expect(float(c.unit) >= 4.0 and (float(c.maxd) == 0.0 or float(c.maxd) >= 50.0) and int(c.cap) >= 1,
				"%s has a sane 3D range (unit %s, maxd %s, cap %s)" % [id, c.unit, c.maxd, c.cap])
		var list := BendSounds.streams(id)
		_expect(list.size() == n, "%s loads every variant (%d of %d)" % [id, list.size(), n])
		for k in list.size():
			var w := list[k] as AudioStreamWAV
			_expect(w != null and w.mix_rate == 44100 and w.format == AudioStreamWAV.FORMAT_16_BITS and not w.stereo,
					"%s: 44.1 kHz 16-bit mono PCM (%s)" % [id, list[k]])
			if k == 0 and w != null and w.format == AudioStreamWAV.FORMAT_16_BITS:       # (the rest: levels.json)
				var pk := _peak(w)
				_expect(pk < 32700, "%s: no sample at full scale (peak %d)" % [id, pk])
			files += 1
	var lv: Variant = JSON.parse_string(FileAccess.get_file_as_string(BendSounds.DIR + "levels.json"))
	_expect(lv is Dictionary, "levels.json reads")
	if lv is Dictionary:
		var listed := 0
		for f: String in lv:
			if not ResourceLoader.exists(BendSounds.DIR + f):
				continue
			listed += 1
			_expect(float((lv[f] as Dictionary).get("peak_dbfs", 0.0)) <= -0.9, "%s peaks under -0.9 dBFS" % f)
		_expect(listed == files, "levels.json lists every file (%d of %d)" % [listed, files])
	print("    %d ids, %d files" % [BendSounds.TABLE.size(), files])


func _peak(w: AudioStreamWAV) -> int:
	var d := w.data
	var m := 0
	for i in range(0, d.size() - 1, 2):
		m = maxi(m, absi(d.decode_s16(i)))
	return m


# ---------------------------------------------------------------- moves
func _test_moves() -> void:
	var moves: Dictionary = SwayMoves.data().get("moves", {})
	var n := 0
	var by_id := {}
	for move: String in moves:
		var bend: Variant = (moves[move] as Dictionary).get("bend")
		if not (bend is Dictionary):
			continue
		var el := Bending.element_of(move)
		for mode: String in bend:
			var spec: Variant = bend[mode]
			if not (spec is Dictionary):
				continue
			var id := BendSounds.cast_id(String((spec as Dictionary).get("kind", "stone")), spec, move, mode)
			n += 1
			by_id[id] = int(by_id.get(id, 0)) + 1
			_expect(BendSounds.TABLE.has(id) and BendSounds.has(id), "%s %s casts %s, with files" % [move, mode, id])
			if FAMILY.has(el):
				var ok := false
				for pre: String in FAMILY[el]:
					ok = ok or String(id).begins_with(pre)
				_expect(ok, "%s %s (%s) casts a sound of its element: %s" % [move, mode, el, id])
	_expect(n >= 80, "every bend spec checked (%d)" % n)
	_expect(by_id.size() >= 18, "the casts use many sounds (%d: %s)" % [by_id.size(), by_id])
	for kind: String in BendLooks.KINDS + ["steam"]:
		var id := BendSounds.hit_id(kind)
		_expect(BendSounds.TABLE.has(id) and BendSounds.has(id), "a %s hit is %s, with files" % [kind, id])
	for ev: String in BendSounds.EVENTS:
		var id: StringName = BendSounds.EVENTS[ev]
		_expect(BendSounds.TABLE.has(id) and BendSounds.has(id), "the moment %s is %s, with files" % [ev, id])
	print("    %d casts over %d sounds" % [n, by_id.size()])


# ---------------------------------------------------------------- borrowed
func _test_borrowed() -> void:
	for id: StringName in BendSounds.TABLE:
		# (Sfx may play a few of the ring's own too, for moves.json form_sfx: tools/sfx/gen_manifest.py BEND_IDS; their
		# files are these, never the frontier game's)
		var sfx_files: Array = SfxManifest.FILES.get(String(id), [])
		_expect(sfx_files.all(func(p: String) -> bool: return p.begins_with("res://audio/sfx/bend/")),
				"%s is not one of Sfx's (the frontier game's) ids" % id)
		_expect(not String(id) in OLD_IDS, "%s is not a borrowed id" % id)
		for i in BendSounds.count(id):
			_expect(BendSounds.path_of(id, i + 1).begins_with("res://audio/sfx/bend/"), "%s's files are the ring's own" % id)
	var consts := (load("res://scripts/bending/bend_looks.gd") as Script).get_script_constant_map()
	_expect(not consts.has("SOUNDS"), "BendLooks keeps no borrowed SOUNDS table")
	var src := FileAccess.get_file_as_string("res://scripts/bending/bend_looks.gd")
	for old: String in OLD_IDS:
		_expect(not ("&\"%s\"" % old) in src, "BendLooks names no borrowed sound (%s)" % old)


# ---------------------------------------------------------------- route
func _test_route() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	BendEffects._cur = {"do": "zone", "mode": "bubble", "move": "water_shield"}
	BendLooks.sound("stone", "cast", Vector3(0, 1, 0))
	_expect(_last() == &"water_slosh", "a water bubble handed in as stone sloshes (%s)" % _last())
	BendEffects._cur = {"do": "lightning", "mode": "lightning", "move": "fire_arc"}
	BendLooks.sound("lightning", "cast", Vector3(0, 1, 0))
	_expect(_last() == &"lightning_crack", "lightning cracks (%s)" % _last())
	BendEffects._cur = {"do": "throw", "mode": "disc", "move": "stone_form"}
	BendLooks.sound("stone", "cast", Vector3(0, 1, 0))
	_expect(_last() == &"earth_cast_crack", "the stone disc cracks off (%s)" % _last())
	BendEffects._cur = {"do": "something else", "mode": "disc", "move": "stone_form"}
	BendLooks.sound("fire", "cast", Vector3(0, 1, 0))
	_expect(_last() == &"fire_whoomph", "a stale record falls back on the kind (%s)" % _last())
	BendEffects._cur = {}
	# a caught stone held at its place
	var stone := Node3D.new()
	stone.add_to_group(FormStone.GROUP)
	holder.add_child(stone)
	stone.global_position = Vector3(3, 1.1, 2)
	stone.set_meta(&"bend_held_by", 1)
	BendLooks.sound("stone", "hit", Vector3(3, 1.1, 2), -2.0)
	_expect(_last() == &"stone_catch", "a stone hit where a caught stone is held is the catch (%s)" % _last())
	BendLooks.sound("stone", "hit", Vector3(9, 1.1, 2))
	_expect(_last() == &"earth_hit", "a stone hit elsewhere is a stone landing (%s)" % _last())
	stone.remove_meta(&"bend_held_by")
	BendLooks.sound("stone", "hit", Vector3(3, 1.1, 2))
	_expect(_last() == &"earth_hit", "a stone lying there, not held, is a stone landing (%s)" % _last())
	# a ring pool (RingWater's own reading of its water)
	var pool := RingWater.new()
	pool.level_y = -1.4
	pool.floor_y = -3.4
	pool.tank_half = Vector2(23.0, 13.0)
	pool.deck_half = Vector2(17.0, 7.0)
	pool.add_to_group(TorchState.WATER_GROUP)
	holder.add_child(pool)
	BendLooks.sound("water", "hit", Vector3(20.0, -1.35, 0.0), 3.0)
	_expect(_last() == &"ringout_splash", "water thrown up at the pool is the ring-out splash (%s)" % _last())
	BendLooks.sound("water", "hit", Vector3(5.0, 0.3, 0.0))
	_expect(_last() == &"water_hit", "water landing on the deck is a splash (%s)" % _last())
	BendLooks.sound("steam", "hit", Vector3(5.0, 1.0, 0.0))
	_expect(_last() == &"steam_hiss", "steam hisses (%s)" % _last())
	var before := BendSounds.played
	BendLooks.sound("nothing", "hit", Vector3.ZERO)
	_expect(BendSounds.played == before, "an unknown kind plays nothing")
	holder.queue_free()
	await _frames(1)


func _last() -> StringName:
	return BendSounds.recent.back() if not BendSounds.recent.is_empty() else &""


# ---------------------------------------------------------------- voices
func _test_voices() -> void:
	BendSounds.voices_headless = true
	BendSounds.play(&"earth_hit", Vector3(100, 0, 0))        # (the pool comes into the tree a frame later)
	await _frames(2)
	seed(1750)
	var a := randf()
	seed(1750)
	var cap := int((BendSounds.TABLE[&"earth_hit"] as Dictionary).cap)
	for i in 12:
		BendSounds.play(&"earth_hit", Vector3(i * 4.0, 0, 0))
	var b := randf()
	_expect(is_equal_approx(a, b), "the sounds' jitter leaves the game's dice alone (%f, %f)" % [a, b])
	await _frames(1)
	_expect(_playing(&"earth_hit") <= cap and _playing(&"earth_hit") >= 1,
			"one id at most its cap at once (%d of %d)" % [_playing(&"earth_hit"), cap])
	var ids := BendSounds.TABLE.keys()
	for i in 80:
		BendSounds.play(ids[i % ids.size()], Vector3(i * 3.0, 0, 50))
	await _frames(1)
	var n3 := 0
	for p: Node in BendSounds._runner.voices3:
		n3 += 1 if (p as AudioStreamPlayer3D).playing else 0
	_expect(BendSounds._runner.voices3.size() <= BendSounds.MAX_VOICES and n3 <= BendSounds.MAX_VOICES,
			"never more than %d voices (%d made, %d playing)" % [BendSounds.MAX_VOICES, BendSounds._runner.voices3.size(), n3])
	var first := BendSounds.play(&"air_whoosh", Vector3(0, 0, -40))
	var again := BendSounds.play(&"air_whoosh", Vector3(0.5, 0, -40))
	var elsewhere := BendSounds.play(&"air_whoosh", Vector3(10, 0, -40))
	_expect(first != null and again == null and elsewhere != null,
			"the same id again at once at the same place is dropped, elsewhere it plays (%s %s %s)" % [first, again, elsewhere])
	var gong := BendSounds.play(&"round_gong")
	_expect(gong is AudioStreamPlayer and (gong as AudioStreamPlayer).bus == &"SFX", "a moment not placed plays 2D on SFX")
	var p3 := BendSounds.play(&"fire_hit", Vector3(0, 0, 60)) as AudioStreamPlayer3D
	_expect(p3 != null and p3.bus == &"World" and is_equal_approx(p3.unit_size, 7.0) and p3.playing,
			"an element's hit plays 3D on World with its range (%s)" % p3)
	if p3 != null:
		var pv := p3.pitch_scale
		var rp := float((BendSounds.TABLE[&"fire_hit"] as Dictionary).rp)
		_expect(pv >= 1.0 / rp - 0.001 and pv <= rp + 0.001, "its pitch within its jitter (%.3f)" % pv)
	BendSounds.voices_headless = false


func _playing(id: StringName) -> int:
	var n := 0
	for p: AudioStreamPlayer3D in BendSounds._runner.voices3:
		if p.playing and StringName(p.get_meta(&"id", &"")) == id:
			n += 1
	return n


# ---------------------------------------------------------------- crowd
func _test_crowd() -> void:
	change_scene_to_file("res://scenes/ring.tscn")
	await _frames(10)
	var lvl := current_scene as RingLevel
	_expect(lvl != null and lvl.ring != null, "the ring's level loads")
	if lvl == null or lvl.ring == null:
		return
	var old := RingDressing.find_in(lvl)
	if old != null:
		old.get_parent().remove_child(old)
		old.free()
	lvl.ring.visuals = true
	lvl.ring.call(&"_materials")
	var d := RingDressing.build(lvl, "noon")
	_expect(d != null, "the dressing builds with visuals on")
	if d == null:
		return
	var loops := d.find_children("CrowdMurmur*", "AudioStreamPlayer3D", true, false)
	_expect(loops.size() == 4, "the murmur loops at four places in the stands (%d)" % loops.size())
	var looping := true
	for p: AudioStreamPlayer3D in loops:
		var w := p.stream as AudioStreamWAV
		looping = looping and p.playing and w != null and w.loop_mode == AudioStreamWAV.LOOP_FORWARD \
				and absf(p.position.z) > 15.0 and p.bus == &"Ambience"
	_expect(looping, "each loop plays forward, in the stands, on the Ambience bus")
	var n0 := BendSounds.recent.size()
	BendSounds.recent.clear()
	d.set_cheer(0.75)
	_expect(BendSounds.recent.has(&"crowd_cheer") or BendSounds.recent.has(&"crowd_ooh"),
			"a knock-back's mood: a stand cheers or gasps (%s)" % [BendSounds.recent])
	BendSounds.recent.clear()
	d.set_cheer(0.25)
	_expect(BendSounds.recent.is_empty(), "the mood falling back says nothing (%s)" % [BendSounds.recent])
	d.set_cheer(1.0)
	_expect(BendSounds.recent.has(&"crowd_roar") and BendSounds.recent.has(&"crowd_groan"),
			"a ring-out's mood: one stand roars, the other groans (%s; %d before)" % [BendSounds.recent, n0])
	await _frames(2)


# ---------------------------------------------------------------- words
func _test_words() -> void:
	var names: Array = BendSounds.TABLE.keys() + BendSounds.EVENTS.keys()
	for nm: Variant in names:
		var low := String(nm).to_lower()
		for w: String in SHOW_WORDS:
			_expect(not w in low, "no show word in %s" % nm)
