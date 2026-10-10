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
##   menu       the lobby's row 01 is the sport's; its screen: the four element cards (each with its competitors' name; the style
##              and the keys as chips under them), Opponent, Difficulty, Rules, Games or Rounds, Light as chips, Controls, Begin;
##              Fire pressed, the Water chip pressed, Begin: the setup is fire against ["water"], incoming, kept, and the load
##              asked for match_path() (the ring), no loading screen
##   round 3    the rule set's Rules row reads "Lives" / "Zones" (never the ids), rules= lives|zones|stock|classic, its default
##              rules.json rule_set; games 1 or 3 ("best of 3"); a practice's % rows (foe_pct, my_pct, grows); steer, speed,
##              fresh, throw_me; all kept (save then load); the Practice words free of the show's words and of the other
##              game's names
##   character  the character's own element (AppearanceStore.element: chosen once, after the character is made) is the setup's
##              default: MatchSetup.load() over the kept setup, Quick match, the menu's chosen card; a match may play another
##              (Begin keeps it as the last setup, the character stays as chosen, the next read starts from the character's)
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
	_stash_look()
	_defaults()
	_words()
	_take()
	_parse()
	_kept()
	_character()
	_quick()
	_round3()
	_compile()
	await _menu()
	await _character_menu()
	_restore_look()
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


## The test run's own look file and offered flag put aside (AppearanceStore.TEST_CURRENT: the kept setup's element is read over by
## the character's, so a look with an element left there would change what these checks read), and put back at the end.
var _look_stash := {}


func _stash_look() -> void:
	for p: String in [AppearanceStore.current_path(), AppearanceStore.offered_path()]:
		_look_stash[p] = FileAccess.get_file_as_bytes(p) if FileAccess.file_exists(p) else null
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _restore_look() -> void:
	for p: String in _look_stash:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		if _look_stash[p] != null:
			var f := FileAccess.open(p, FileAccess.WRITE)
			if f != null:
				f.store_buffer(_look_stash[p])
				f.close()


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


## The character's element as the setup's default: read over the kept setup by load() (and Quick match), left to a match to change.
func _character() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = OWN_CFG
	GameSettings.set_section("match", {"element": "fire", "foe": "air"})
	MatchSetup.element = "earth"
	check(AppearanceStore.element() == "", "(no character element chosen)")
	MatchSetup.load()
	check(MatchSetup.element == "fire", "no element chosen: the kept setup's (%s)" % MatchSetup.element)
	AppearanceStore.save_current(AppearanceStore.validate(AppearanceStore.default_look()))
	AppearanceStore.set_element("water")
	MatchSetup.element = "earth"
	MatchSetup.load()
	check(MatchSetup.element == "water" and MatchSetup.foes == ["air"], "the character's element (Water) is the default over the kept Fire (%s)" % MatchSetup.element)
	MatchSetup.element = "air"
	MatchSetup.quick_match()
	check(MatchSetup.element == "water" and MatchSetup.quick, "Quick match plays the character's element (%s)" % MatchSetup.element)
	MatchSetup.quick = false
	MatchSetup.element = "earth"
	MatchSetup.save()
	check(String(GameSettings.get_value("match", "element")) == "earth" and AppearanceStore.element() == "water",
			"a match played as Earth keeps Earth as the last setup; the character stays Water")
	MatchSetup.load()
	check(MatchSetup.element == "water", "the next read starts from the character's again (%s)" % MatchSetup.element)
	# the args of a run (tools, tests) still choose the element
	MatchSetup.parse(PackedStringArray(["element=air"]))
	check(MatchSetup.element == "air", "element=air of the run's args is taken as given")
	MatchSetup.element = "earth"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(AppearanceStore.current_path()))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))


## The menu's setup screen starts on the character's element and a match's own choice leaves the character as chosen.
func _character_menu() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = OWN_CFG
	AppearanceStore.save_current(AppearanceStore.validate(AppearanceStore.default_look()))
	AppearanceStore.set_element("water")
	GameSettings.set_section("match", {"element": "earth", "foe": "earth"})
	launched.clear()
	MainMenu.launch_hook = func(p: String) -> void: launched.append(p)
	MatchSetup.element = "earth"
	change_scene_to_file("res://scenes/main_menu.tscn")
	await frames(6)
	var m := current_scene as MainMenu
	check(m != null and MatchSetup.element == "water", "the menu starts from the character's element (%s)" % MatchSetup.element)
	var which := m.find_child("Which", true, false) as Label
	check(which != null and which.text.to_lower().begins_with("water"), "the lobby's fighter card: Water ('%s')" % [which.text if which else ""])
	m._open_match()
	await frames(2)
	var rows := m._element_rows
	check(bool(rows["water"].get_meta(&"chosen", false)) and not bool(rows["earth"].get_meta(&"chosen", false)),
			"the setup opens with the character's card lit (water)")
	check(_chip_lines(m).has(_key_rows("water")[0]), "its keys under the cards")
	# a match of its own: Fire pressed, Begin keeps it as the last setup; the character stays Water
	(rows["fire"] as Button).pressed.emit()
	await frames(1)
	MatchSetup.incoming = false
	(m._panel.find_child("Begin", true, false) as Button).pressed.emit()
	await frames(2)
	check(MatchSetup.element == "fire" and String(GameSettings.get_value("match", "element")) == "fire" and AppearanceStore.element() == "water",
			"Begin as Fire: the match is Fire's, the last setup Fire, the character still Water")
	MatchSetup.incoming = false
	m._close_panel()
	await frames(2)
	check(MatchSetup.element == "water", "back at the lobby: the character's element again (%s)" % MatchSetup.element)
	MainMenu.launch_hook = Callable()
	MatchSetup.leave()
	GameSettings.path = GameSettings.PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))


## Round 3 (smash_r3 spec §7.3-7.4, §11.1, §14.3): MatchSetup.rule_set(), games(), practice_pct() and their words.
func _round3() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = OWN_CFG
	var def := String(RingRules.data().get("rule_set", "classic"))
	MatchSetup.rules_choice = ""
	check(MatchSetup.rule_set() == def, "the rule set by default rules.json's (%s)" % MatchSetup.rule_set())
	MatchSetup.parse(PackedStringArray(["rules=lives", "games=3", "foe_pct=120", "my_pct=grows", "steer=out", "speed=0.5",
			"fresh=on", "throw_me=on"]))
	check(MatchSetup.rule_set() == "stock" and MatchSetup.rule_label() == "Lives" and MatchSetup.games() == 3
			and MatchSetup.games_label() == "best of 3", "rules=lives games=3: %s \"%s\", %d \"%s\"" % [MatchSetup.rule_set(),
			MatchSetup.rule_label(), MatchSetup.games(), MatchSetup.games_label()])
	MatchSetup.parse(PackedStringArray(["rules=zones", "games=2", "speed=x", "steer=sideways"]))
	check(MatchSetup.rule_set() == "classic" and MatchSetup.rule_label() == "Zones" and MatchSetup.games() == 3
			and MatchSetup.speed == 0.5 and MatchSetup.steer == "out", "rules=zones: \"Zones\"; a bad games, speed, steer left alone")
	var was := MatchSetup.kind
	MatchSetup.kind = "match"
	check(MatchSetup.practice_pct().is_empty(), "a match: no practice %")
	MatchSetup.kind = "practice"
	check(MatchSetup.practice_pct() == {"foe": 120.0}, "a practice: its %% 120, yours grows (%s)" % [MatchSetup.practice_pct()])
	MatchSetup.my_pct = 60.0
	MatchSetup.save()
	MatchSetup.rules_choice = "stock"
	MatchSetup.games_n = 1
	MatchSetup.foe_pct = -1.0
	MatchSetup.my_pct = -1.0
	MatchSetup.steer = "none"
	MatchSetup.speed = 1.0
	MatchSetup.fresh = false
	MatchSetup.throw_me = false
	MatchSetup.load()
	check(MatchSetup.rule_set() == "classic" and MatchSetup.games() == 3 and MatchSetup.practice_pct() == {"foe": 120.0, "player": 60.0}
			and MatchSetup.steer == "out" and MatchSetup.speed == 0.5 and MatchSetup.fresh and MatchSetup.throw_me,
			"round 3's rows kept: save() then load() (%s %d %s %s %.2f %s %s)" % [MatchSetup.rule_set(), MatchSetup.games(),
			MatchSetup.practice_pct(), MatchSetup.steer, MatchSetup.speed, MatchSetup.fresh, MatchSetup.throw_me])
	check(MatchSetup.pct_label(-1.0) == "grows" and MatchSetup.pct_label(120.0) == "120%", "the % rows' words")
	check(MatchSetup.dummy_ways() == MatchSetup.DUMMIES, "zones: B steps the classic ways")
	MatchSetup.rules_choice = "stock"
	check(MatchSetup.dummy_ways() == MatchSetup.STOCK_DUMMIES and MatchSetup.dummy_line("guard_after") == "guards after a hit",
			"lives: B steps the %% ring's ways (%s)" % MatchSetup.dummy_line("guard_after"))
	# (every Practice and menu word clean of the show's words and of the other game's names)
	var other := RegEx.create_from_string("(?i)\\b(stock|blast zone|DI|tech|edge-?guard|meteor|smash|final smash)\\b")
	var bad: Array = []
	var walk := [MatchSetup.practice_data()]
	while not walk.is_empty():
		var v: Variant = walk.pop_back()
		if v is Dictionary:
			for k: Variant in v:
				if not String(k).begins_with("_"):
					walk.append((v as Dictionary)[k])
		elif v is Array:
			walk.append_array(v as Array)
		elif v is String:
			if _show_re.search(String(v)) != null or other.search(String(v)) != null:
				bad.append(v)
	check(bad.is_empty(), "practice.json's words: none of the show's, none of the other game's (%s)" % [bad])
	MatchSetup.kind = was
	MatchSetup.rules_choice = ""
	MatchSetup.games_n = 1
	MatchSetup.foe_pct = -1.0
	MatchSetup.my_pct = -1.0
	MatchSetup.steer = "none"
	MatchSetup.speed = 1.0
	MatchSetup.fresh = false
	MatchSetup.throw_me = false
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
	# (the broadcast lobby, 2026-10-10: the rundown's row 01 is the sport's; its setup is a screen of its own with the four
	# elements as fighter cards and the match's choices as chips)
	var sport := m._items.find_child("Sport", true, false) as Button
	var first := _row_text(sport)
	check(first == MatchSetup.sport(), "the sport's row first (%s)" % first)
	check(m._items.find_children("*", "Button", true, false)[0] == sport, "and first in the rundown")
	sport.pressed.emit()
	await frames(2)
	check(m._panel_scroll.visible and root.find_children("*", "CharacterCreator", true, false).is_empty(),
			"its screen opens (no creator in a test run)")
	var rows := m._element_rows
	check(rows.size() == 4 and Bending.ELEMENTS.all(func(e: String) -> bool: return rows.has(e)), "the four element cards")
	for el: String in Bending.ELEMENTS:
		var b := rows.get(el) as Button
		check(b != null and _row_text(b) == MatchSetup.label(el) and _sub_text(b) == MatchSetup.competitor(el),
				"%s's card: '%s', its competitors' name under it ('%s')" % [el, _row_text(b), _sub_text(b)])
	check(bool(rows["earth"].get_meta(&"chosen", false)) and not bool(rows["fire"].get_meta(&"chosen", false)),
			"the chosen element's card is lit (earth)")
	var texts := _panel_texts(m)
	check(texts.has("Earth  ·  Stone") and texts.has(MatchSetup.style("earth")), "the chosen element's style under the cards (its name and nickname, then its style)")
	# (round 2: the block is KitWords' lines, the same buttons for every element: LMB JAB and E GUARD, then 1-5 by role; each
	# a chip whose `line` is the whole line)
	var ek := _key_rows("earth")
	var chip_lines := _chip_lines(m)
	check(ek.size() == 5 and ek[0] == "1   STRIKE   Spike  ·  tap twice: Boulder" and ek[4] == "5   HEAL   Patch  ·  tap twice: Mend"
			and ek.all(func(l: String) -> bool: return chip_lines.has(l)), "the keys block: earth's five keys as chips (%s)" % [ek])
	var mc := m._panel.find_child("MatchCard", true, false)
	for want: String in ["Opponent", "Difficulty", "Rules", "Light"]:
		check(mc.find_child(want, true, false) is BroadcastUI.Segments, "the choice '%s' as chips" % want)
	check(texts.has(String(((MatchSetup.data().get("formats", {}) as Dictionary).get("1v1", {}) as Dictionary).get("label", "1 v 1")))
			and texts.has("Controls") and mc.find_child("Begin", true, false) != null, "the format, Controls and Begin")
	var box := m._panel.find_child("Match", true, false) as Control
	check(box.get_combined_minimum_size().y <= 900.0 and box.get_combined_minimum_size().x <= 1600.0,
			"the whole screen in the 1600 x 900 design space, Begin too (%s)" % box.get_combined_minimum_size())
	var begin_rect := (mc.find_child("Begin", true, false) as Control).get_global_rect()
	check(Rect2(Vector2.ZERO, Vector2(1600, 900)).encloses(begin_rect), "Begin in view at 1600 x 900 (%s)" % begin_rect)
	# Fire, then the opponent round to Water, then Begin
	(rows["fire"] as Button).pressed.emit()
	await frames(1)
	check(MatchSetup.element == "fire" and bool(rows["fire"].get_meta(&"chosen", false)) and not bool(rows["earth"].get_meta(&"chosen", false)),
			"Fire pressed: chosen (%s)" % MatchSetup.element)
	check(_chip_lines(m).has(_key_rows("fire")[0]) and _key_rows("fire")[0].begins_with("1   STRIKE ▲   Punch")
			and _panel_texts(m).has("Fire  ·  Ember") and _panel_texts(m).has(MatchSetup.style("fire")), "the block: fire's style and keys (%s)" % _key_rows("fire")[0])
	(rows["water"] as Button).grab_focus()
	await frames(1)
	check(_chip_lines(m).has("1   STRIKE   Lash  ·  tap twice: Spear") and MatchSetup.element == "fire", "Water focused: its keys shown, fire still chosen")
	(m._panel.find_child("Begin", true, false) as Button).grab_focus()
	await frames(1)
	check(_chip_lines(m).has(_key_rows("fire")[0]), "focus gone from the cards: the chosen one's keys again")
	var opp := mc.find_child("Opponent", true, false) as BroadcastUI.Segments
	opp.chip(1).pressed.emit()
	await frames(1)
	check(MatchSetup.foes == ["water"] and opp.chosen == 1 and _says(mc, "OpponentRow").begins_with("Tide"),
			"Opponent: the Water chip pressed (%s, line '%s')" % [MatchSetup.foes, _says(mc, "OpponentRow")])
	var dif := mc.find_child("Difficulty", true, false) as BroadcastUI.Segments
	dif.chip(2).pressed.emit()
	await frames(1)
	check(MatchSetup.difficulty == "hard" and dif.chosen == 2 and _says(mc, "DifficultyRow") == MatchSetup.difficulty_line("hard"),
			"Difficulty: Hard pressed (%s)" % MatchSetup.difficulty)
	dif.chip(1).pressed.emit()
	await frames(1)
	check(MatchSetup.difficulty == "normal", "and Normal again")
	# (the rules: the % ring's lives show Games, the zones show Rounds in its place)
	var rul := mc.find_child("Rules", true, false) as BroadcastUI.Segments
	var rnd_row := mc.find_child("RoundsRow", true, false) as Control
	var gms_row := mc.find_child("GamesRow", true, false) as Control
	rul.chip(0).pressed.emit()
	await frames(1)
	check(MatchSetup.rule_set() == "stock" and gms_row.visible and not rnd_row.visible and _says(mc, "RulesRow") == MatchSetup.menu_word("rules_line_stock"),
			"Lives: the Games row shown, no Rounds row (%s)" % MatchSetup.rule_set())
	var gms := mc.find_child("Games", true, false) as BroadcastUI.Segments
	var games_was := MatchSetup.games()
	var other := 1 if games_was == 1 else 0
	gms.chip(other).pressed.emit()
	await frames(1)
	check(MatchSetup.games() != games_was and gms.chosen == other, "Games: the other chip pressed (%d -> %d)" % [games_was, MatchSetup.games()])
	gms.chip(MatchSetup.GAMES.find(games_was)).pressed.emit()
	await frames(1)
	check(MatchSetup.games() == games_was, "and back to %d" % games_was)
	rul.chip(1).pressed.emit()
	await frames(1)
	check(MatchSetup.rule_set() == "classic" and rnd_row.visible and not gms_row.visible and MatchSetup.rule_label() == "Zones",
			"Zones: the Rounds row shown in its place (%s)" % MatchSetup.rule_set())
	var rnd := mc.find_child("Rounds", true, false) as BroadcastUI.Segments
	rnd.chip(2).pressed.emit()
	await frames(1)
	check(MatchSetup.rounds_to_win == 3 and rnd.chosen == 2, "Rounds: best of 5 pressed")
	rnd.chip(1).pressed.emit()
	await frames(1)
	check(MatchSetup.rounds_to_win == 2, "and best of 3 again")
	rul.chip(0).pressed.emit()
	await frames(1)
	var lit := mc.find_child("Light", true, false) as BroadcastUI.Segments
	lit.chip(2).pressed.emit()
	await frames(1)
	check(MatchSetup.light == "night" and lit.chosen == 2, "Light: Night pressed")
	lit.chip(0).pressed.emit()
	await frames(1)
	check(MatchSetup.light == "noon", "and Noon again")
	# the keys and the pad through the setup: Down from a chip to the chip of the same place in the next row, Right along a row and
	# no further (the engine's guess would carry the focus to another row's chip), Left from a row's first chip to the chosen card
	var o1 := mc.find_child("Opponent", true, false) as BroadcastUI.Segments
	var d1 := mc.find_child("Difficulty", true, false) as BroadcastUI.Segments
	o1.chip(1).grab_focus()
	await _key_action(&"ui_down")
	var at_d1 := root.gui_get_focus_owner() == d1.chip(1)
	d1.chip(2).grab_focus()
	await _key_action(&"ui_right")
	var stays := root.gui_get_focus_owner() == d1.chip(2)
	d1.chip(0).grab_focus()
	await _key_action(&"ui_left")
	var to_card: bool = root.gui_get_focus_owner() == rows[MatchSetup.element]
	check(at_d1 and stays and to_card, "the keys: Down to the same place in the next row (%s), Right stops at a row's end (%s), Left to the chosen card (%s)" % [at_d1, stays, to_card])
	# the number keys choose the element
	var key := InputEventKey.new()
	key.physical_keycode = KEY_1
	key.pressed = true
	m._unhandled_input(key)
	await frames(1)
	check(MatchSetup.element == "earth", "the number key 1 chooses the first element (%s)" % MatchSetup.element)
	(rows["fire"] as Button).pressed.emit()
	await frames(1)
	var shown := " ".join(PackedStringArray(_panel_texts(m)))
	var hit := _show_re.search(shown)
	check(hit == null, "no show word on the screen (%s)" % (hit.get_string() if hit else "none"))
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
	for c in m._items.find_children("*", "Button", true, false):
		if not c.is_queued_for_deletion() and _row_text(c) == "Quick match":
			qm = c as Button
	var qs := qm.find_child("Sub", true, false) as Label if qm else null
	# (under the % ring's lives its games: one game, or best of 3 with games 3; the rounds under the zone rules)
	var length := ("best of 3" if MatchSetup.games() >= 3 else "one game") if MatchSetup.rule_set() == "stock" else "best of 3"
	check(qs != null and qs.text == "Fire against a random opponent  ·  normal  ·  " + length, "Quick match's line: '%s'" % (qs.text if qs else "none"))
	# the lobby's bug says the next match
	var bug := m.find_child("BugLine", true, false) as Label
	m._paint_lobby()
	check(bug != null and bug.text.contains(MatchSetup.rule_label()) and bug.text.contains(MatchSetup.difficulty), "the lobby's bug: '%s'" % (bug.text if bug else "none"))
	# Esc closes the screen
	m._open_match()
	await frames(1)
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	m._unhandled_input(esc)
	await frames(1)
	check(not m._panel_scroll.visible, "Esc closes the screen")
	await _beginner_path(m)
	MainMenu.launch_hook = Callable()
	MatchSetup.leave()
	GameSettings.path = GameSettings.PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))


func _beginner_path(m: MainMenu) -> void:
	MatchSetup.set_controls("full")
	MatchSetup.set_aim_help("off")
	MatchSetup.difficulty = "hard"
	MatchSetup.rules_choice = "classic"
	MatchSetup.speed = 0.2
	MatchSetup.throw_me = true
	var start := m._items.find_child("StartHere", true, false) as Button
	check(start != null, "Start here remains reachable after the first-launch offer")
	if start == null:
		return
	start.pressed.emit()
	await frames(2)
	check(MatchSetup.controls() == "full" and MatchSetup.aim_help() == "off" and MatchSetup.difficulty == "hard",
			"opening Start here preserves the current settings")
	var learn := m._panel.find_child("Basics", true, false) as Button
	var easy := m._panel.find_child("EasyMatch", true, false) as Button
	check(learn != null and easy != null and m._panel.get_combined_minimum_size().y <= 710.0,
			"both beginner choices fit on screen (%.0f px)" % m._panel.get_combined_minimum_size().y)
	if learn == null or easy == null:
		return
	learn.pressed.emit()
	check(MatchSetup.basic() and MatchSetup.practice() and RingMode.lessons_asked and MatchSetup.rule_set() == "stock"
			and MatchSetup.aim_help() == "strong" and MatchSetup.difficulty == "easy",
			"Learn the basics uses Basic, strong aim help and the five-card Lives practice from a saved Full/Zones setup")
	check(is_equal_approx(MatchSetup.speed, 1.0) and not MatchSetup.throw_me and MatchSetup.dummy == "stand"
			and RingLessons.lessons_for(MatchSetup.scheme(), MatchSetup.element).size() == 5,
			"the guided practice clears earlier speed/throw settings and includes recovery")
	check(launched.back() == MainMenu.RING_SCENE and MatchSetup.element == "fire", "the beginner path keeps the chosen element and launches the ring")
	easy.pressed.emit()
	check(not MatchSetup.practice() and not RingMode.lessons_asked and MatchSetup.quick and FirstHints.on()
			and MatchSetup.basic() and MatchSetup.difficulty == "easy" and MatchSetup.games_n == 1,
			"Play an easy match launches one easy game with Basic helpers and key hints")
	check(String(GameSettings.get_value("match", "foe")) == "water", "the easy match keeps the custom opponent choice for later")


## A UI action as the keys or the pad send it, through the window.
func _key_action(a: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = a
	ev.pressed = true
	root.push_input(ev)
	await frames(2)


## The line under a match card's setting row `row` (its Line label).
func _says(mc: Node, row: String) -> String:
	var l := mc.find_child(row, true, false).find_child("Line", true, false) as Label
	return l.text if l else ""


## The whole lines of the chips under the cards (each chip's `line` meta).
func _chip_lines(m: MainMenu) -> Array:
	var out: Array = []
	for c in m._keys_box.find_children("Key_*", "Control", true, false):
		if not c.is_queued_for_deletion() and c.has_meta(&"line"):
			out.append(String(c.get_meta(&"line")))
	return out


func _row_text(b: Node) -> String:
	var t := b.find_child("Text", true, false) as Label if b else null
	return t.text if t else ""


func _sub_text(b: Node) -> String:
	var t := b.find_child("Sub", true, false) as Label if b else null
	return t.text if t else ""


## The texts of the open panel: its headings', labels' and rows' lines.
## Element `el`'s key rows 1-5 as the menu shows them (KitWords.kit_lines under the keys scheme, past its JAB and GUARD).
func _key_rows(el: String) -> Array:
	return KitWords.kit_lines(el, "keys").filter(func(l: String) -> bool: return l.length() > 0 and l[0] in "12345")


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
