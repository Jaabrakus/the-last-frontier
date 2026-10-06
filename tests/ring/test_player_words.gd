extends SceneTree
## The words a player sees in Tidebreak, held to the owner's rule (2026-10-04: an elemental ring sport with no words from the
## show on the screen): none of WORDS, each matched as a whole word in any case (as tests/customizer/deny_words.gd matches
## the creator's deny-list), headless, no level:
##
##   Godot --headless --path . -s tests/ring/test_player_words.gd
##
##   held (a hit fails the test)
##     data/ring/*.json       every string value (not the "_..." doc keys, not the files' "summary" doc line)
##     the menu's code        the string literals of scripts/ui/menu/main_menu.gd and scripts/ring/match_setup.gd
##     the menu on screen     every line of the main menu: its rows, the Tidebreak panel with each element's keys shown in
##                            turn, the Practice and Controls panels, the Open world panel
##     round 2's words        every new label, tip, lesson card, key hint, wheel name, F1 and first-time line and the kit's
##                            lines (KitWords.every_line), held to ROUND2_WORDS too (Water Whip, Air Ball, Air Shield,
##                            Spout, redirect lightning, "bend" in any form); KitWords, BendStrip and RingLessons' strings
##     round 3's values   screens.json, rules.json's words, hud.json, lessons.json, practice.json, movement.json's words and
##                            moves.json's labels: no show words and no Smash names (stock, blast zone, DI, tech, edge-guard,
##                            meteor, smash, Final Smash), values only (never keys or ids)
##   reported (NOTE lines, not failures: files other tasks of the build own, to clean in their own work)
##     data/sway/moves.json   each move's label and its variations' labels (the HUD's ready line shows them)
##     the HUD and the ring   the string literals of the HUD, the duel's and the ring's scripts, the first-time help, the
##                            loading screen's pictures and the bending bot
## Ends with "PLAYER WORDS TEST PASSED" or "PLAYER WORDS TEST FAILED" (exit 0 only on a pass; a watchdog quits with 2).

const NAME := "PLAYER WORDS TEST"
const LIMIT_S := 100.0
## The show's words and its sport's, its peoples', places' and people's names (whole words, any case).
const WORDS := ["avatar", "benders?", "bending", "pro-?bend\\w*", "korra", "aang", "airbend\\w*", "firebend\\w*",
		"earthbend\\w*", "waterbend\\w*", "air scooters?", "fire nation", "water tribes?", "earth kingdom", "air nomads?",
		"republic city", "ba sing se", "omashu"]
## Round 2's too, held on every new label, tip and lesson card (skills_r2 spec §11 q16: the names the kits left behind).
const ROUND2_WORDS := ["water whip", "air balls?", "air shields?", "spouts?", "redirect lightning", "bend\\w*"]
const R2Layout := preload("res://tests/ring/r2_layout.gd")
const HELD_CODE := ["res://scripts/ui/menu/main_menu.gd", "res://scripts/ring/match_setup.gd", "res://scripts/ui/kit_words.gd",
		"res://scripts/ui/bend_strip.gd", "res://scripts/ring/ring_lessons.gd"]
## Reported only: owned by the build's other tasks (the HUD, the ring's rules and screens, the bots, the moves' data).
const NOTED_CODE := ["res://scripts/ui/hud.gd", "res://scripts/ui/how_to.gd", "res://scripts/duel/duel_mode.gd",
		"res://scripts/duel/duel_menu.gd", "res://scripts/ui/menu/menu_paintings.gd", "res://scripts/ui/menu/loading_screen.gd",
		"res://scripts/npc/npc_bending.gd"]
const NOTED_DIRS := ["res://scripts/ring", "res://scripts/ui"]

var checks := 0
var fails: Array[String] = []
var notes := 0
var _re := RegEx.create_from_string("(?i)\\b(?:%s)\\b" % "|".join(PackedStringArray(WORDS)))


func _initialize() -> void:
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	checks += 1
	if ok:
		print("  ok   ", what)
	else:
		fails.append(what)
		print("  FAIL ", what)


func note(what: String) -> void:
	notes += 1
	print("  NOTE ", what)


func frames(n: int) -> void:
	for i in n:
		await process_frame


## The show's words in `text` (lower case, each once).
func hits(text: String) -> Array:
	var out: Array = []
	for m in _re.search_all(text):
		var w := m.get_string().to_lower()
		if not w in out:
			out.append(w)
	return out


func _run() -> void:
	# the patterns themselves: whole words, not parts of others
	check(hits("Bending the pro-bending rules, a Bender's airbending and Earthbenders") == ["bending", "pro-bending", "bender", "airbending", "earthbenders"],
			"the patterns catch the words (%s)" % [hits("Bending the pro-bending rules, a Bender's airbending and Earthbenders")])
	check(hits("a bend in the river; bend_pools; docs/bending_design.md; bendy; Tidebreak; the air scooters") == ["air scooters"],
			"and not words that only hold them (%s)" % [hits("a bend in the river; bend_pools; docs/bending_design.md; bendy; Tidebreak; the air scooters")])
	var laid := R2Layout.apply()
	print("  info round 2's key layout %s" % ("put in for this run (the kits' data not merged here)" if laid else "from the data"))
	_ring_data()
	_held_code()
	await _menu()
	_round2()
	_moves()
	_values_r3()
	_noted_code()
	_end()


## Round 3 (smash_r3 spec v2 §15 PERCENT): every player-facing VALUE (words, labels, card and hint text; never keys or ids:
## a value with no space that reads as an id, a path or a tag is left out) of screens.json, rules.json's words, hud.json,
## lessons.json, practice.json, movement.json's words and moves.json's labels, free of the show's words AND Smash's own
## names (stock, blast zone, DI, tech, edge-guard, meteor, smash, Final Smash).
func _values_r3() -> void:
	var smash := RegEx.create_from_string("(?i)\\b(?:stocks?|blast ?zones?|tech(?:s|ed|ing)?|edge-?guard\\w*|meteor\\w*|smash\\w*|final smash)\\b")
	var di := RegEx.create_from_string("\\bDI\\b")
	var idlike := RegEx.create_from_string("^[A-Za-z0-9_./:%-]*$")
	var sources := {}
	var screens: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/ring/screens.json"))
	sources["screens.json"] = screens
	var rules: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/ring/rules.json"))
	sources["rules.json words"] = (rules as Dictionary).get("words", {}) if rules is Dictionary else {}
	for f: String in ["hud.json", "lessons.json", "practice.json"]:
		var p := "res://data/ring/" + f
		sources[f] = JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else {}
	var mv: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/ring/movement.json"))
	sources["movement.json words"] = (mv as Dictionary).get("words", {}) if mv is Dictionary else {}
	var labels: Array = []
	var moves: Dictionary = SwayMoves.data().get("moves", {})
	for id: String in moves:
		if moves[id] is Dictionary:
			labels.append(String((moves[id] as Dictionary).get("label", "")))
			var ml: Variant = (moves[id] as Dictionary).get("mode_labels", {})
			if ml is Dictionary:
				for k in ml:
					labels.append(String(ml[k]))
	sources["moves.json labels"] = labels
	var all_ok := true
	var count := 0
	for name: String in sources:
		var vals: Array = []
		_values(sources[name], vals)
		var found: Array = []
		for v: String in vals:
			if v.strip_edges() == "" or (not v.contains(" ") and idlike.search(v) != null and not v.contains("%")):
				continue                                   # (an id, a tag, a path: not words on the screen)
			count += 1
			for w in hits(v):
				found.append("'%s': %s" % [v.left(50), w])
			for mt in smash.search_all(v):
				found.append("'%s': %s" % [v.left(50), mt.get_string()])
			for mt in di.search_all(v):
				found.append("'%s': %s" % [v.left(50), mt.get_string()])
		check(found.is_empty(), "%s: no show words and no Smash names in its player-facing values (%s)" % [name, found])
		all_ok = all_ok and found.is_empty()
	check(count > 200, "round 3's player-facing values read (%d)" % count)
	check(smash.search("Lives and the water's edge: steer, break your fall") == null and smash.search("three stocks") != null
			and di.search("hold DI") != null and smash.search("a technique") == null, "the Smash names' patterns catch them, not their neighbours")


## Every string value under `v` (the "_..." doc keys and "summary" skipped), into `out`.
func _values(v: Variant, out: Array) -> void:
	if v is Dictionary:
		for k in v:
			var ks := String(k)
			if ks.begins_with("_") or ks == "summary":
				continue
			_values(v[k], out)
	elif v is Array:
		for x in v:
			_values(x, out)
	elif v is String:
		out.append(v)


## Round 2's words (skills_r2: every new label, tip and lesson card): none of WORDS nor ROUND2_WORDS (the show's names the
## kit's moves left: Water Whip, Air Ball, Air Shield, Spout, redirect lightning, air scooter, and "bend" in any form; an
## [action] token of a lesson line is its key, not a word, and is left out).
func _round2() -> void:
	var re2 := RegEx.create_from_string("(?i)\\b(?:%s)\\b" % "|".join(PackedStringArray(WORDS + ROUND2_WORDS)))
	var tok := RegEx.create_from_string("\\[[a-z_0-9]+\\]")
	var texts: Array = KitWords.every_line()
	texts.append_array(MatchSetup.screens().get("tips", []))
	texts.append(FrontierHUD.ARENA_HELP)
	for k: String in FrontierHUD.ARENA_KEYS:
		texts.append(String(FrontierHUD.ARENA_KEYS[k]))
	for id: String in HowTo.ARENA_TOPICS:
		texts.append(String(HowTo.TOPICS[id].title))
		texts.append_array(HowTo.TOPICS[id].steps)
	var ld: Dictionary = MatchSetup.screens().get("loading", {})
	texts.append(String(ld.get("title", "")))
	texts.append_array(ld.get("captions", []))
	var cards := 0
	for l: Dictionary in RingLessons.data().get("lessons", []):
		texts.append(String(l.get("title", "")))
		for s: String in (l.get("by", {}) as Dictionary):
			texts.append(String((l.by[s] as Dictionary).get("line", "")))
			cards += 1
	for s: String in (RingLessons.data().get("hints", {}) as Dictionary):
		if s.begins_with("_") or not RingLessons.data().hints[s] is Array:
			continue
		for h: Dictionary in RingLessons.data().hints[s]:
			texts.append(String(h.get("line", "")))
	for el: String in Bending.ELEMENTS:
		for it: Dictionary in RadialWheel.items_for(el):
			texts.append(String(it.label))
	var found: Array = []
	for t in texts:
		var plain := tok.sub(String(t), "", true)
		for mt in re2.search_all(plain):
			found.append("'%s': %s" % [String(t).left(60), mt.get_string()])
	check(found.is_empty() and texts.size() > 200 and cards >= 20,
			"round 2's labels, tips, lesson cards (%d), hints, wheel names and help: no show words, no old names (%d lines%s)"
			% [cards, texts.size(), "" if found.is_empty() else ": %s" % [found]])


## data/ring/*.json: every string value but the doc keys.
func _ring_data() -> void:
	var d := DirAccess.open("res://data/ring")
	check(d != null, "data/ring is there")
	if d == null:
		return
	var n := 0
	for f in d.get_files():
		if not f.ends_with(".json"):
			continue
		n += 1
		var path := "res://data/ring/" + f
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		check(v != null, "%s parses" % path)
		var found: Array = []
		_strings(v, "", found)
		check(found.is_empty(), "%s: no show words (%s)" % [path, found])
	check(n >= 1, "data/ring has its files (%d)" % n)


## The show's words in the string values under `v`, as "key.path: word" in `out` (keys "_..." and "summary" skipped: docs).
func _strings(v: Variant, at: String, out: Array) -> void:
	if v is Dictionary:
		for k in v:
			var ks := String(k)
			if ks.begins_with("_") or ks == "summary":
				continue
			for w in hits(ks):
				out.append("%s%s (key): %s" % [at, ks, w])
			_strings(v[k], at + ks + ".", out)
	elif v is Array:
		for i in (v as Array).size():
			_strings(v[i], "%s%d." % [at, i], out)
	elif v is String:
		for w in hits(v):
			out.append("%s: %s" % [at.trim_suffix("."), w])


func _held_code() -> void:
	for path: String in HELD_CODE:
		var found := _code_hits(path)
		check(found.is_empty(), "%s: no show words in its strings (%s)" % [path, found])


## The show's words in a script's string literals (not its comments; not StringNames &"" or NodePaths ^""), as
## "line N: word".
func _code_hits(path: String) -> Array:
	var out: Array = []
	if not FileAccess.file_exists(path):
		return out
	var lines := FileAccess.get_file_as_string(path).split("\n")
	for i in lines.size():
		for s: String in literals(lines[i]):
			for w in hits(s):
				out.append("line %d: %s" % [i + 1, w])
	return out


## The string literals of one line of GDScript ("..." and '...', escapes kept as written), up to a comment.
static func literals(line: String) -> Array:
	var out: Array = []
	var i := 0
	var n := line.length()
	while i < n:
		var c := line[i]
		if c == "#":
			break
		if c == "\"" or c == "'":
			var skip := i > 0 and (line[i - 1] == "&" or line[i - 1] == "^")
			var j := i + 1
			var s := ""
			while j < n and line[j] != c:
				if line[j] == "\\" and j + 1 < n:
					s += line[j] + line[j + 1]
					j += 2
					continue
				s += line[j]
				j += 1
			if not skip:
				out.append(s)
			i = j + 1
			continue
		i += 1
	return out


## The main menu on the screen: its rows, the Tidebreak panel (each element's keys in turn) and the Open world panel.
func _menu() -> void:
	var own_cfg := "user://test_player_words_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(own_cfg))
	GameSettings.path = own_cfg
	change_scene_to_file("res://scenes/main_menu.tscn")
	await frames(6)
	var m := current_scene as MainMenu
	check(m != null, "the menu scene")
	if m == null:
		return
	var seen: Array = _labels(m._items)
	m._open_match()
	await frames(2)
	for el: String in Bending.ELEMENTS:
		m._show_keys(el)
		await frames(1)
		seen.append_array(_labels(m._panel))
	m._open_practice()
	await frames(2)
	seen.append_array(_labels(m._panel))
	m._open_controls()
	await frames(2)
	seen.append_array(_labels(m._panel))
	m._open_world()
	await frames(2)
	seen.append_array(_labels(m._panel))
	check(seen.size() > 40, "the menu's lines read (%d)" % seen.size())
	var found: Array = []
	for t: String in seen:
		for w in hits(t):
			found.append("'%s': %s" % [t, w])
	check(found.is_empty(), "the main menu on screen: no show words (%s)" % [found])
	m._close_panel()
	GameSettings.path = GameSettings.PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(own_cfg))


func _labels(under: Node) -> Array:
	var out: Array = []
	for n in under.find_children("*", "Label", true, false):
		if not n.is_queued_for_deletion() and (n as Label).text != "":
			out.append((n as Label).text)
	return out


## moves.json's labels and variation labels (reported: the moves' data is another task's).
func _moves() -> void:
	var moves: Dictionary = SwayMoves.data().get("moves", {})
	check(moves.size() > 20, "moves.json's moves read (%d)" % moves.size())
	var found := 0
	for id: String in moves:
		var mv: Variant = moves[id]
		if not mv is Dictionary:
			continue
		for w in hits(String((mv as Dictionary).get("label", ""))):
			note("moves.json %s.label: '%s'" % [id, w])
			found += 1
		var ml: Variant = (mv as Dictionary).get("mode_labels", {})
		if ml is Dictionary:
			for k in ml:
				for w in hits(String(ml[k])):
					note("moves.json %s.mode_labels.%s: '%s' (for T10's move data)" % [id, k, w])
					found += 1
	print("    moves.json: %d show word(s) in labels" % found)


## The other player-facing scripts' string literals (reported: the HUD, the ring, the duel, the bot, the pictures).
func _noted_code() -> void:
	var paths: Array = NOTED_CODE.duplicate()
	for dir: String in NOTED_DIRS:
		var d := DirAccess.open(dir)
		if d == null:
			continue
		for f in d.get_files():
			var p := dir + "/" + f
			if f.ends_with(".gd") and not p in paths and not p in HELD_CODE:
				paths.append(p)
	var found := 0
	for path: String in paths:
		for h: String in _code_hits(path):
			note("%s %s" % [path, h])
			found += 1
	print("    other screens' scripts: %d show word(s) in strings across %d files" % [found, paths.size()])


func _end() -> void:
	print("%d checks, %d failed, %d notes" % [checks, fails.size(), notes])
	for x in fails:
		printerr("FAIL: ", x)
	print("%s %s" % [NAME, "PASSED" if fails.is_empty() else "FAILED"])
	quit(0 if fails.is_empty() else 1)
