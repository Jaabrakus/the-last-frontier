extends SceneTree
## Tidebreak's match setup (MatchSetup, data/ring/elements.json), the main menu's match panel and the compile check
## (tools/compile_check.gd), headless; no level is loaded (the menu's Begin goes to MainMenu.launch_hook, not the ring):
##
##   Godot --headless --path . -s tests/ring/test_match_setup.gd -- mode=ring element=air foe=earth difficulty=hard
##
##   words      the four elements' names, the names their competitors go by (Stone, Tide, Ember, Gale), their style lines
##              and colours (the arts' colours of data/sway/moves.json), the lot's ("Any"), the sport's name; none of the
##              show's words in the file
##   defaults   a 1 v 1 against earth, normal, best of 3, 180 s rounds, no spectating
##   take       the run's user args taken (mode=ring element=air foe=earth difficulty=hard), the request with them
##   parse      every key (foe lists with Any, mates, to_win, round_s, spectate), bad values left alone; Any drawn by lot
##              from a seed (the same seed, the same draw)
##   kept       save() then load() round-trips through GameSettings' "match" section, in a file of the test's own; a
##              tool or test run never reads or writes the player's own settings file (GameSettings.file)
##   quick      round 2's skills: each element's quick spell defaults to its jab (moves.json jabs), a quick spell though on
##              none of 1-4; cut moves are none; the scheme ids (first_moves; a kept or asked 'simple' reads as it); each
##              element's four first moves and its direction moves
##   compile    the checker's check(): a broken script of the test's own is bad, a good one and the setup's own are whole
##   menu       the sport's row first; its panel: the four element rows (each with its style), the keys block, Opponent,
##              Format, Difficulty, Rounds, Begin; Fire pressed, Opponent pressed round to Water, Begin: the setup is
##              fire against ["water"], incoming, kept, and the load asked for match_path() (the ring), no loading screen
## Ends with "MATCH SETUP TEST PASSED" or "MATCH SETUP TEST FAILED" (exit 0 only on a pass; a watchdog quits with 2).

const NAME := "MATCH SETUP TEST"
const LIMIT_S := 150.0
const CompileCheck := preload("res://tools/compile_check.gd")
const OWN_CFG := "user://test_match_settings.cfg"
## The franchise words (the plan's acceptance, as substrings in any case).
const SHOW_WORDS := "(?i)avatar|airbend|bender|bending|korra|republic city|fire nation|water tribe|earth kingdom|air nomad"

var checks := 0
var fails: Array[String] = []
var launched: Array = []
var _show_re := RegEx.create_from_string(SHOW_WORDS)


func _initialize() -> void:
	seed(1750)
	MatchSetup._aim_help = "light"              # (nothing here aims; the setting pinned, as the other MatchSetup tests do)
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


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var real_cfg := ProjectSettings.globalize_path(GameSettings.PATH)
	var real_t := FileAccess.get_modified_time(real_cfg) if FileAccess.file_exists(real_cfg) else 0
	_defaults()
	_words()
	_take()
	_parse()
	_kept()
	_quick()
	_compile()
	await _menu()
	var now_t := FileAccess.get_modified_time(real_cfg) if FileAccess.file_exists(real_cfg) else 0
	check(now_t == real_t, "the player's own settings file never written (%d -> %d)" % [real_t, now_t])
	_end()


func _defaults() -> void:
	check(MatchSetup.element == "earth" and MatchSetup.foes == ["earth"] and MatchSetup.mates.is_empty()
			and MatchSetup.difficulty == "normal" and MatchSetup.rounds_to_win == 2 and is_equal_approx(MatchSetup.round_s, 180.0)
			and not MatchSetup.spectate and not MatchSetup.incoming,
			"defaults: a 1 v 1 against earth, normal, best of 3, 180 s rounds")


func _words() -> void:
	var raw := FileAccess.get_file_as_string(MatchSetup.DATA_PATH)
	check(JSON.parse_string(raw) is Dictionary, "%s parses" % MatchSetup.DATA_PATH)
	var want := {"earth": ["Earth", "Stone", "earth"], "water": ["Water", "Tide", "tide"], "fire": ["Fire", "Ember", "ember"],
			"air": ["Air", "Gale", "gale"]}
	for el: String in Bending.ELEMENTS:
		var i := MatchSetup.info(el)
		var w: Array = want[el]
		check(MatchSetup.label(el) == w[0] and MatchSetup.competitor(el) == w[1] and String(i.get("art", "")) == w[2],
				"%s: '%s', its competitors '%s' (art %s)" % [el, MatchSetup.label(el), MatchSetup.competitor(el), i.get("art")])
		check(MatchSetup.style(el).length() > 20, "%s: a style line ('%s')" % [el, MatchSetup.style(el)])
		check(MatchSetup.color(el).is_equal_approx(SwayMoves.art_color(w[2])), "%s: its colour is its art's (%s)" % [el, MatchSetup.color(el)])
	check(MatchSetup.label(MatchSetup.ANY) == "Any" and MatchSetup.style(MatchSetup.ANY) != "", "the lot: 'Any', with its line")
	check(MatchSetup.info("lava").is_empty(), "an unknown element: no words")
	check(MatchSetup.sport() == "Tidebreak" and MatchSetup.sport_line().length() > 30, "the sport: '%s'" % MatchSetup.sport())
	for d: String in MatchSetup.DIFFICULTIES:
		check(MatchSetup.difficulty_line(d) != "", "difficulty %s: its line" % d)
	var hit := _show_re.search(raw)
	check(hit == null, "no show word in elements.json (%s)" % (hit.get_string() if hit else "none"))


func _take() -> void:
	var args := OS.get_cmdline_user_args()
	check("mode=ring" in args and "element=air" in args and "foe=earth" in args and "difficulty=hard" in args,
			"run with -- mode=ring element=air foe=earth difficulty=hard (%s)" % [args])
	check(MatchSetup.requested() and MatchSetup.active(), "mode=ring: a match requested")
	MatchSetup.incoming = true
	var asked := MatchSetup.take()
	check(asked and not MatchSetup.incoming and MatchSetup.active(), "take(): the request taken, the match under way")
	check(MatchSetup.element == "air" and MatchSetup.foes == ["earth"] and MatchSetup.difficulty == "hard",
			"take() parses the args: air against %s, %s" % [MatchSetup.foes, MatchSetup.difficulty])
	MatchSetup.leave()
	check(not MatchSetup._on and not MatchSetup.incoming, "leave(): no match under way")


func _parse() -> void:
	var r := MatchSetup.parse(PackedStringArray(["element=fire", "foe=water,any", "mates=air", "to_win=3", "round_s=90",
			"spectate=on", "difficulty=bogus", "element=lava", "foe=lava", "to_win=0", "round_s=x", "nonsense"]))
	check(not r, "parse: no mode=ring among them")
	check(MatchSetup.element == "fire" and MatchSetup.foes == ["water", "any"] and MatchSetup.mates == ["air"]
			and MatchSetup.rounds_to_win == 3 and is_equal_approx(MatchSetup.round_s, 90.0) and MatchSetup.spectate
			and MatchSetup.difficulty == "hard",
			"parse: every key, bad values left alone (%s %s %s %d %.0f %s %s)" % [MatchSetup.element, MatchSetup.foes,
			MatchSetup.mates, MatchSetup.rounds_to_win, MatchSetup.round_s, MatchSetup.spectate, MatchSetup.difficulty])
	check(MatchSetup.parse(PackedStringArray(["--mode=ring", "mates="])) and MatchSetup.mates.is_empty(), "parse: --mode=ring; mates= none")
	var a := RandomNumberGenerator.new()
	a.seed = 1750
	var b := RandomNumberGenerator.new()
	b.seed = 1750
	var ra := MatchSetup.resolved(MatchSetup.foes, a)
	var rb := MatchSetup.resolved(MatchSetup.foes, b)
	check(ra.size() == 2 and ra[0] == "water" and String(ra[1]) in Bending.ELEMENTS and ra == rb,
			"Any drawn by lot, the same from the same seed (%s)" % [ra])
	MatchSetup.spectate = false
	MatchSetup.round_s = 180.0


func _kept() -> void:
	check(GameSettings.file() == GameSettings.TEST_PATH, "a test run reads and writes %s, not the player's file" % GameSettings.file())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = OWN_CFG
	check(String(GameSettings.get_value("match", "element")) == "earth" and int(GameSettings.get_value("match", "rounds")) == 2,
			"the match section's defaults")
	MatchSetup.element = "water"
	MatchSetup.foes = ["fire"]
	MatchSetup.difficulty = "easy"
	MatchSetup.rounds_to_win = 3
	MatchSetup.save()
	MatchSetup.element = "earth"
	MatchSetup.foes = ["air"]
	MatchSetup.difficulty = "normal"
	MatchSetup.rounds_to_win = 1
	MatchSetup.load()
	check(MatchSetup.element == "water" and MatchSetup.foes == ["fire"] and MatchSetup.difficulty == "easy" and MatchSetup.rounds_to_win == 3,
			"save() then load() round-trips (%s %s %s %d)" % [MatchSetup.element, MatchSetup.foes, MatchSetup.difficulty, MatchSetup.rounds_to_win])
	var cf := ConfigFile.new()
	check(cf.load(OWN_CFG) == OK and String(cf.get_value("match", "foe", "")) == "fire", "kept in the test's own file's [match]")
	check(MatchSetup.summary() == "Water vs Fire  ·  easy  ·  best of 5", "its line: '%s'" % MatchSetup.summary())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))


## Round 2's skills: the quick spell's default and its check from moves.json "jabs" (the jab is a quick spell though it is on
## none of 1-4; fire's old fire_jab/jab kept gives the default, Embers); the scheme ids (first_moves, a kept or asked
## "simple" read as it), each element's four first moves and its direction moves (W key 1's first, S its wall, A/D key 3's).
func _quick() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = OWN_CFG
	var jabs := {"earth": ["rock_jab", "pebbles"], "water": ["water_jet", "splash"], "fire": ["fire_jab", "embers"],
			"air": ["air_palm", "palm"]}
	for el: String in jabs:
		var j: Array = jabs[el]
		var d := MatchSetup.quick_default(el)
		check(String(d.get("id", "")) == j[0] and String(d.get("mode", "")) == j[1] and MatchSetup.quick_ok(el, j[0], j[1])
				and MatchSetup.jab_of(el) == {"id": j[0], "mode": j[1]},
				"%s: the quick spell's default is its jab %s/%s, a quick spell though on none of 1-4 (%s)" % [el, j[0], j[1], d])
	check(MatchSetup.set_quick("earth", "stone_form", "cannonball") and MatchSetup.quick_of("earth") == {"id": "stone_form", "mode": "cannonball"},
			"a key's move set as earth's quick spell: kept (%s)" % [MatchSetup.quick_of("earth")])
	check(not MatchSetup.quick_ok("earth", "stone_form", "disc") and not MatchSetup.quick_ok("earth", "earth_grip", "trap")
			and not MatchSetup.quick_ok("fire", "fire_jab", "jab") and not MatchSetup.quick_ok("air", "fire_jab", "embers"),
			"a cut move or variation, or another element's jab, is no quick spell")
	GameSettings.set_value(MatchSetup.QUICK_SECTION, "fire", "fire_jab/jab")
	check(MatchSetup.quick_of("fire") == {"id": "fire_jab", "mode": "embers"}, "fire's old fire_jab/jab kept: its default, Embers (%s)" % [MatchSetup.quick_of("fire")])
	check(MatchSetup.SCHEMES == ["keys", "direction", "radial", "first_moves"] and not "simple" in MatchSetup.SCHEMES,
			"the schemes: %s" % [MatchSetup.SCHEMES])
	GameSettings.set_value(MatchSetup.SECTION, MatchSetup.SCHEME_KEY, "simple")
	MatchSetup.reload_scheme()
	check(MatchSetup.scheme() == "first_moves", "a kept 'simple' reads as first_moves (%s)" % MatchSetup.scheme())
	check(MatchSetup.set_scheme("simple") and MatchSetup.scheme() == "first_moves" and MatchSetup.scheme_label() == "First moves only",
			"set_scheme('simple') sets first_moves ('%s')" % MatchSetup.scheme_label())
	MatchSetup.parse(PackedStringArray(["scheme=simple"]))
	check(MatchSetup.scheme() == "first_moves", "scheme=simple asks for first_moves")
	var fm := {"earth": ["stone_form/spike", "earth_shove/push", "earth_skate/burrow", "earth_wall/wall"],
			"water": ["water_whip/whip", "wave/push", "flow/skate", "water_shield/ice_wall"],
			"fire": ["fire_blast/punch", "fire_kick/kick", "footwork/step", "fire_wall/wall"],
			"air": ["air_blast/slice", "air_gust/gust", "evade/slip", "air_wall/wall"]}
	var dirs := {"earth": ["stone_form/spike", "earth_wall/wall", "earth_skate/burrow"], "water": ["water_whip/whip",
			"water_shield/ice_wall", "flow/skate"], "fire": ["fire_blast/punch", "fire_wall/wall", "footwork/step"],
			"air": ["air_blast/slice", "air_wall/wall", "evade/slip"]}
	for el: String in Bending.ELEMENTS:
		var four: Array = []
		for e: Dictionary in MatchSetup.first_moves(el):
			four.append("%s/%s" % [e.id, e.mode])
		var ks := Bending.keys(el)
		var firsts: Array = []
		for i in 4:
			var id := String((ks[i] as Array)[0])
			firsts.append("%s/%s" % [id, SwayCaster.modes_of(id)[0]])
		check(four == fm[el] and four == firsts, "%s: the four first moves %s (the first of keys 1-4)" % [el, four])
		var dm: Array = []
		for d: String in MatchSetup.DIRS:
			var m := MatchSetup.direction_move(el, d)
			dm.append("%s/%s" % [m.get("id", "-"), m.get("mode", "-")])
		check(dm == dirs[el] and dm[0] == firsts[0] and dm[1] == firsts[3] and dm[2] == firsts[2],
				"%s: the direction moves W %s, S %s, A/D %s (key 1's first, its wall, key 3's first)" % [el, dm[0], dm[1], dm[2]])
		check(MatchSetup.scheme_key_lines(el, "first_moves").size() == 4, "%s: the first-moves lines, four" % el)
	MatchSetup.set_scheme("keys")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))


func _compile() -> void:
	var broken := "user://compile_check_broken.gd"
	var good := "user://compile_check_good.gd"
	var f := FileAccess.open(broken, FileAccess.WRITE)
	f.store_string("extends RefCounted\nfunc f(:\n\treturn\n")
	f.close()
	f = FileAccess.open(good, FileAccess.WRITE)
	f.store_string("extends RefCounted\n\nfunc f() -> int:\n\treturn 1\n")
	f.close()
	check(not CompileCheck.check(broken, true), "the compile check: a broken script is bad")
	check(CompileCheck.check(good, true), "the compile check: a good one is whole")
	check(CompileCheck.check("res://scripts/ring/match_setup.gd") and CompileCheck.check("res://scripts/ui/menu/main_menu.gd"),
			"the compile check: the setup and the menu are whole")
	check(CompileCheck.scripts_under("res://scripts/ring").has("res://scripts/ring/match_setup.gd"), "the compile check walks the folders")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(broken))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(good))


func _menu() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = OWN_CFG
	MainMenu.launch_hook = func(p: String) -> void: launched.append(p)
	MatchSetup.element = "earth"
	MatchSetup.foes = ["earth"]
	MatchSetup.difficulty = "normal"
	MatchSetup.rounds_to_win = 2
	change_scene_to_file("res://scenes/main_menu.tscn")
	await frames(6)
	var m := current_scene as MainMenu
	check(m != null, "the menu scene")
	if m == null:
		return
	var first := _row_text(m._items.get_child(0))
	check(first == MatchSetup.sport(), "the sport's row first (%s)" % first)
	(m._items.get_child(0) as Button).pressed.emit()
	await frames(2)
	check(m._panel_scroll.visible and root.find_children("*", "CharacterCreator", true, false).is_empty(),
			"its panel opens (no creator in a test run)")
	var rows := m._element_rows
	check(rows.size() == 4 and Bending.ELEMENTS.all(func(e: String) -> bool: return rows.has(e)), "the four element rows")
	for el: String in Bending.ELEMENTS:
		var b := rows.get(el) as Button
		check(b != null and _row_text(b) == MatchSetup.label(el) and _sub_text(b).begins_with(MatchSetup.competitor(el)),
				"%s's row: '%s', its competitors' name under it ('%s')" % [el, _row_text(b), _sub_text(b)])
	check(_sub_text(rows["earth"]) == "Stone  ·  chosen", "the chosen element says so (%s)" % _sub_text(rows["earth"]))
	var texts := _panel_texts(m)
	check(texts.has("Stone  ·  " + MatchSetup.style("earth")), "the chosen element's style under the rows")
	check(texts.has("1   Stone Form  ·  Rock Jab") and texts.has("5   Mend  ·  Patch"), "the keys block: earth's five keys (%s)" % [texts])
	for want: String in ["Opponent:  Earth", "Format:  1 v 1", "Difficulty:  normal", "Rounds:  best of 3", "Begin"]:
		check(texts.has(want), "the row '%s'" % want)
	var need := m._panel.get_combined_minimum_size().y
	check(need <= 900.0 - 110.0 - 80.0, "the whole panel in view at 1600 x 900, Begin too (%.0f of %.0f px)" % [need, 900.0 - 190.0])
	# Fire, then the opponent round to Water, then Begin
	(rows["fire"] as Button).pressed.emit()
	await frames(1)
	check(MatchSetup.element == "fire" and _sub_text(rows["fire"]) == "Ember  ·  chosen" and _sub_text(rows["earth"]) == "Stone",
			"Fire pressed: chosen (%s)" % _sub_text(rows["fire"]))
	check(_panel_texts(m).has("1   Fire Blast  ·  Fire Jab") and _panel_texts(m).has("Ember  ·  " + MatchSetup.style("fire")),
			"the block: fire's style and keys")
	(rows["water"] as Button).grab_focus()
	await frames(1)
	check(_panel_texts(m).has("1   Water Whip  ·  Water Jet") and MatchSetup.element == "fire", "Water focused: its keys shown, fire still chosen")
	(m._panel.find_child("Begin", true, false) as Button).grab_focus()
	await frames(1)
	check(_panel_texts(m).has("1   Fire Blast  ·  Fire Jab"), "focus gone from the elements: the chosen one's keys again")
	var opp := m._panel.find_child("Opponent", true, false) as Button
	var presses := 0
	while opp and _row_text(opp) != "Opponent:  Water" and presses < 6:
		opp.pressed.emit()
		presses += 1
		await frames(1)
	check(opp != null and _row_text(opp) == "Opponent:  Water" and MatchSetup.foes == ["water"],
			"Opponent pressed round to Water (%d presses: %s)" % [presses, MatchSetup.foes])
	var dif := m._panel.find_child("Difficulty", true, false) as Button
	if dif:
		dif.pressed.emit()
		await frames(1)
	check(MatchSetup.difficulty == "hard" and dif and _row_text(dif) == "Difficulty:  hard", "Difficulty steps: hard")
	if dif:
		dif.pressed.emit()
		dif.pressed.emit()
		await frames(1)
	check(MatchSetup.difficulty == "normal", "and round again to normal")
	var rnd := m._panel.find_child("Rounds", true, false) as Button
	if rnd:
		rnd.pressed.emit()
		await frames(1)
	check(MatchSetup.rounds_to_win == 3 and rnd and _row_text(rnd) == "Rounds:  best of 5", "Rounds steps: best of 5")
	if rnd:
		rnd.pressed.emit()
		rnd.pressed.emit()
		await frames(1)
	check(MatchSetup.rounds_to_win == 2, "and round again to best of 3")
	var shown := " ".join(PackedStringArray(_panel_texts(m)))
	var hit := _show_re.search(shown)
	check(hit == null, "no show word in the panel (%s)" % (hit.get_string() if hit else "none"))
	var begin := m._panel.find_child("Begin", true, false) as Button
	check(begin != null and not begin.disabled, "Begin")
	MatchSetup.incoming = false
	if begin:
		begin.pressed.emit()
	await frames(2)
	check(launched == [MainMenu.match_path()] and MainMenu.match_path() == "res://scenes/ring.tscn",
			"Begin: into %s" % [launched])
	check(MatchSetup.element == "fire" and MatchSetup.foes == ["water"] and MatchSetup.incoming and MatchSetup.active(),
			"Begin: fire against %s, incoming" % [MatchSetup.foes])
	check(String(GameSettings.get_value("match", "element")) == "fire" and String(GameSettings.get_value("match", "foe")) == "water",
			"Begin: the setup kept for next time")
	check(root.find_children("*", "LoadingScreen", true, false).is_empty(), "no loading screen (the hook stood in)")
	# the Quick match row's line is the kept setup
	m._build_items()
	await frames(1)
	var qm: Button = null
	for c in m._items.get_children():
		if not c.is_queued_for_deletion() and _row_text(c) == "Quick match":
			qm = c as Button
	var qs := qm.find_child("Sub", true, false) as Label if qm else null
	check(qs != null and qs.text == "Fire against a random opponent  ·  normal  ·  best of 3", "Quick match's line: '%s'" % (qs.text if qs else "none"))
	# Esc closes the panel
	m._open_match()
	await frames(1)
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	m._unhandled_input(esc)
	await frames(1)
	check(not m._panel_scroll.visible, "Esc closes the panel")
	MainMenu.launch_hook = Callable()
	MatchSetup.leave()
	GameSettings.path = GameSettings.PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))


func _row_text(b: Node) -> String:
	var t := b.find_child("Text", true, false) as Label if b else null
	return t.text if t else ""


func _sub_text(b: Node) -> String:
	var t := b.find_child("Sub", true, false) as Label if b else null
	return t.text if t else ""


## The texts of the open panel: its headings', labels' and rows' lines.
func _panel_texts(m: MainMenu) -> Array:
	var out: Array = []
	for n in m._panel.find_children("*", "Label", true, false):
		if not n.is_queued_for_deletion() and not (n as Label).text.is_empty():
			out.append((n as Label).text)
	return out


func _end() -> void:
	print("%d checks, %d failed" % [checks, fails.size()])
	for x in fails:
		printerr("FAIL: ", x)
	print("%s %s" % [NAME, "PASSED" if fails.is_empty() else "FAILED"])
	quit(0 if fails.is_empty() else 1)
