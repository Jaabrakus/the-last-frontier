class_name MatchSetup
extends RefCounted
## THE MATCH'S SETUP for Tidebreak, the elemental ring sport (the owner, 2026-10-04: the sport is called Tidebreak; a 1 v 1
## first, the team lists kept for a 3 v 3 later): what the main menu chose, or the user args gave, for the ring scene
## (scenes/ring.tscn) to take at its start. Statics, so they outlive the scene change (the menu fills them, LoadingScreen
## loads the ring, the ring's level takes them).
##   element        the player's element (Bending.ELEMENTS)
##   foes           the other side's elements, one per competitor (["water"] in a 1 v 1, three in a 3 v 3 later); ANY is
##                  drawn by lot when the match begins (resolved())
##   mates          the player's team-mates' elements ([] in a 1 v 1)
##   difficulty     the bots' (DIFFICULTIES: easy, normal, hard)
##   rounds_to_win  round wins that take the match (2: best of 3)
##   round_s        a round's length (s)
##   spectate       the player off the deck while two bots play (soak tests, stills)
##   light          the ring's light (LIGHTS: "noon", "golden", "night"; RingLook and RingDressing at the ring's load)
##   kind           "match" (rounds, a score) or "practice" (KINDS: a dummy of foes[0]'s element, no timer, no rounds; RingMode)
##   dummy          the practice dummy's way (DUMMIES: "stand" still, "block" its guards and cover, "throw" a stone every
##                  few seconds; data/ring/screens.json "practice")
##   format         "1v1" (FORMATS; "3v3" is the structure only, shown as coming: format_ready)
## The words a player sees come from data/ring/elements.json (info, label, competitor, style, color, sport): each element's
## name, the name its competitors go by (Stone, Tide, Ember, Gale) and its one-line style; no word from any show
## (tests/ring/test_player_words.gd holds them to that).
##
##   MatchSetup.requested()       the menu's request (incoming) or the user arg mode=ring
##   MatchSetup.take()            the ring at its start: the user args applied, the request taken; active() from then on
##   MatchSetup.active()          a ring match asked for or under way (PlayerAppearance: no creator over the countdown)
##   MatchSetup.leave()           the main menu again: no match
##   MatchSetup.save() / load()   the last setup in GameSettings' "match" section (the menu's panel and Quick match)
##   MatchSetup.quick_of(el) / set_quick(el, id, mode)   each element's quick spell on LMB (GameSettings' "quick" section)
##   MatchSetup.quick_match(rng)  Quick match from the main menu: your last element and the rest of the last setup, the
##                                opponent's element drawn at random (the kept setup's opponent is not overwritten by it)
##   MatchSetup.set_practice(foe, dummy) / set_match()   what the next Begin plays (the menu's Practice and Begin)
##   MatchSetup.practice()        a practice asked for (kind)
##   MatchSetup.parse(args)       the setup's user args, as take() reads them:
##       mode=ring element=fire foe=water[,earth,...] mates=air[,...] difficulty=hard to_win=2 round_s=90 spectate=on
##       light=golden practice=throw (or mode=practice: a practice with the kept dummy)

const DATA_PATH := "res://data/ring/elements.json"
## The match's screens' words, the loading tips and the practice dummy's numbers.
const SCREENS_PATH := "res://data/ring/screens.json"
## GameSettings' section the last setup is kept in.
const SECTION := "match"
## The opponent drawn by lot (the menu's "Any").
const ANY := "any"
const DIFFICULTIES := ["easy", "normal", "hard"]
## The round wins the menu offers (best of 1, 3 and 5).
const ROUNDS := [1, 2, 3]
## The ring's light moods the menu offers (RingLook.PRESETS), the first the default.
const LIGHTS := ["noon", "golden", "night"]
## What the ring plays: a match, or a practice against a dummy.
const KINDS := ["match", "practice"]
## The practice dummy's ways, the first the default.
const DUMMIES := ["stand", "block", "throw"]
## The match formats; only those in FORMATS_READY can be played (the rest are shown as coming).
const FORMATS := ["1v1", "3v3"]
const FORMATS_READY := ["1v1"]

## Set by the main menu's Begin for the scene it loads (taken once: take()).
static var incoming := false
static var element := "earth"
static var foes: Array = ["earth"]
static var mates: Array = []
static var difficulty := "normal"
static var rounds_to_win := 2
static var round_s := 180.0
static var spectate := false
static var light := "noon"
static var kind := "match"
static var dummy := "stand"
static var format := "1v1"
## Quick match's draw: the opponent is this match's own, the kept setup's left as it was (save()).
static var quick := false

static var _on := false
static var _data := {}
static var _screens := {}


# --- The request ----------------------------------------------------------------------------------------------

## Whether a ring match is asked for: the main menu's Begin (incoming) or the user arg mode=ring.
static func requested() -> bool:
	if incoming:
		return true
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		if kv in ["mode=ring", "mode=practice"] or kv.begins_with("practice="):
			return true
	return false


## The ring takes the setup once at its start: the user args (tests, tools) applied over what the menu chose, the menu's
## request taken (the next scene from the menu is not a match unless asked again). Returns whether a match was asked for.
static func take() -> bool:
	var asked := requested()
	parse(OS.get_cmdline_user_args())
	incoming = false
	_on = true
	return asked


## A ring match asked for or under way (from the menu's Begin until the main menu again).
static func active() -> bool:
	return _on or requested()


## Back at the main menu: no match under way (its open-world games are not matches).
static func leave() -> void:
	_on = false
	incoming = false
	quick = false
	kind = "match"


## The setup's user args in `args` applied; an unknown key or a bad value leaves the setup as it was. True when mode=ring
## is among them.
static func parse(args: PackedStringArray) -> bool:
	var ring := false
	for raw: String in args:
		var a := raw.trim_prefix("--")
		if not a.contains("="):
			continue
		var k := a.get_slice("=", 0)
		var v := a.get_slice("=", 1).strip_edges()
		match k:
			"mode":
				ring = ring or v in ["ring", "practice"]
				if v == "practice":
					kind = "practice"
			"practice":
				ring = true
				kind = "practice"
				if v in DUMMIES:
					dummy = v
			"dummy":
				if v in DUMMIES:
					dummy = v
			"format":
				if v in FORMATS:
					format = v
			"element":
				if v in Bending.ELEMENTS:
					element = v
			"foe", "foes":
				var l := elements_in(v, true)
				if not l.is_empty():
					foes = l
			"mate", "mates":
				mates = elements_in(v, false)
			"difficulty":
				if v in DIFFICULTIES:
					difficulty = v
			"to_win", "rounds":
				if v.is_valid_int() and int(v) >= 1:
					rounds_to_win = int(v)
			"round_s":
				if v.is_valid_float() and float(v) > 0.0:
					round_s = float(v)
			"spectate":
				spectate = v in ["on", "true", "yes", "1"]
			"light", "mood":
				if v in LIGHTS:
					light = v
	return ring


## The elements named in a comma list ("water,earth"), in order; `any_ok` lets ANY through. Unknown names are dropped.
static func elements_in(list: String, any_ok: bool) -> Array:
	var out: Array = []
	for e in list.split(",", false):
		var s := e.strip_edges().to_lower()
		if s in Bending.ELEMENTS or (any_ok and s == ANY):
			out.append(s)
	return out


## The first foe's element (ANY until resolved).
static func foe() -> String:
	return String(foes[0]) if not foes.is_empty() else "earth"


## `list` with each ANY drawn by lot from the elements (`rng`: a match seeded for a test or a replay).
static func resolved(list: Array, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for e in list:
		out.append(String(Bending.ELEMENTS[rng.randi_range(0, Bending.ELEMENTS.size() - 1)]) if String(e) == ANY else String(e))
	return out


# --- The last setup, kept --------------------------------------------------------------------------------------

## The setup kept in GameSettings' "match" section (the element, the foes, the difficulty, the round wins). A test points
## GameSettings.path at a file of its own first (and GameSettings keeps -s runs off the player's own file in any case).
static func save() -> void:
	var f := ",".join(PackedStringArray(foes))
	if quick or kind == "practice":
		# (Quick match's drawn opponent and a practice's dummy are not the panel's choice: the kept opponent stays)
		var kept := String(GameSettings.get_value(SECTION, "foe"))
		if not elements_in(kept, true).is_empty():
			f = kept
	GameSettings.set_section(SECTION, {"element": element, "foe": f, "difficulty": difficulty, "rounds": rounds_to_win,
			"light": light, "dummy": dummy})


## The kept setup read back over the statics (each value only when it is a good one).
static func load() -> void:
	var el := String(GameSettings.get_value(SECTION, "element"))
	if el in Bending.ELEMENTS:
		element = el
	var f := elements_in(String(GameSettings.get_value(SECTION, "foe")), true)
	if not f.is_empty():
		foes = f
	var d := String(GameSettings.get_value(SECTION, "difficulty"))
	if d in DIFFICULTIES:
		difficulty = d
	var r := int(GameSettings.get_value(SECTION, "rounds"))
	if r >= 1:
		rounds_to_win = r
	var l := String(GameSettings.get_value(SECTION, "light"))
	if l in LIGHTS:
		light = l
	var dm := str(_kept("dummy", DUMMIES[0]))
	if dm in DUMMIES:
		dummy = dm


## A kept value of the "match" section that GameSettings.DEFAULTS may not list (the practice dummy): read from its file as
## get_value reads, `def` when it is not there.
static func _kept(key: String, def: Variant) -> Variant:
	if ((GameSettings.DEFAULTS.get(SECTION, {})) as Dictionary).has(key):
		return GameSettings.get_value(SECTION, key)
	var cf := ConfigFile.new()
	cf.load(GameSettings.file())
	return cf.get_value(SECTION, key, def)


# --- Quick match and practice: the menu's entry points ------------------------------------------------------------

## Quick match (the main menu's): the last setup (load()), your last element, the opponent's element drawn at random (from
## `rng`, a test's; else a fresh one), a match (not a practice). The menu then plays it as Begin does; the kept setup's own
## opponent is left as it was (save() while quick). Returns the drawn element.
static func quick_match(rng: RandomNumberGenerator = null) -> String:
	MatchSetup.load()
	var r := rng
	if r == null:
		r = RandomNumberGenerator.new()
		r.randomize()
	var el := String(Bending.ELEMENTS[r.randi_range(0, Bending.ELEMENTS.size() - 1)])
	foes = [el]
	kind = "match"
	format = "1v1"
	quick = true
	return el


## Quick match's line under its row: "Earth against a random opponent  ·  normal  ·  best of 3" (the kept setup's).
static func quick_line() -> String:
	return String(screens().get("quick_line", "%s against a random opponent  ·  %s  ·  %s")) % [label(element), difficulty,
			rounds_label(rounds_to_win)]


## The next Begin plays a practice against a dummy of element `foe_el` (ANY drawn by lot) standing, blocking or throwing
## (`way`: DUMMIES; "" keeps the last).
static func set_practice(foe_el := "", way := "") -> void:
	kind = "practice"
	quick = false
	if foe_el in Bending.ELEMENTS or foe_el == ANY:
		foes = [foe_el]
	if way in DUMMIES:
		dummy = way


## The next Begin plays a match (the panel's Begin after a practice).
static func set_match() -> void:
	kind = "match"
	quick = false


## A practice asked for.
static func practice() -> bool:
	return kind == "practice"


## Whether format `f` can be played now ("1v1"); the others are shown as coming.
static func format_ready(f: String) -> bool:
	return f in FORMATS_READY


## The practice dummy's way in words ("throws a stone every few seconds"; data/ring/screens.json practice.ways).
static func dummy_line(way: String) -> String:
	var p: Dictionary = screens().get("practice", {})
	return String((p.get("ways", {}) as Dictionary).get(way, way))


## data/ring/screens.json (the round and match screens' words, the loading tips, the practice dummy), read once.
static func screens() -> Dictionary:
	if _screens.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCREENS_PATH)) if FileAccess.file_exists(SCREENS_PATH) else null
		_screens = d if d is Dictionary else {"_": true}
	return _screens


# --- The quick spell (LMB), per element --------------------------------------------------------------------------

## Each element's quick spell on the left button (SwayCaster's quick spell: one move at one variation, frozen), kept in
## GameSettings' QUICK_SECTION as "move/variation" (its DEFAULTS there are the element's first: earth rock_jab/pebbles,
## water water_jet/splash, fire fire_jab/jab, air air_palm/palm). A test points GameSettings.path at a file of its own.
const QUICK_SECTION := "quick"


## Element `el`'s quick spell: {id, mode} (the one kept, else its default; {} for no element).
static func quick_of(el: String) -> Dictionary:
	if not el in Bending.ELEMENTS:
		return {}
	var kept := _quick_parse(el, String(GameSettings.get_value(QUICK_SECTION, el)))
	if not kept.is_empty():
		return kept
	return quick_default(el)


## Element `el`'s default quick spell ({id, mode}; {} for no element).
static func quick_default(el: String) -> Dictionary:
	var d: Dictionary = GameSettings.DEFAULTS.get(QUICK_SECTION, {})
	return _quick_parse(el, String(d.get(el, "")))


## Element `el`'s quick spell kept as `id` in `mode` (false, nothing kept, when it is not one of the element's moves).
static func set_quick(el: String, id: String, mode: String) -> bool:
	if not quick_ok(el, id, mode):
		return false
	GameSettings.set_value(QUICK_SECTION, el, "%s/%s" % [id, mode])
	return true


## Whether `id` in `mode` can be element `el`'s quick spell: one of its keys' moves (Bending.keys), `mode` one of its
## variations ("" for a move with none).
static func quick_ok(el: String, id: String, mode: String) -> bool:
	if not el in Bending.ELEMENTS or id == "":
		return false
	var mine := false
	for pair in Bending.keys(el):
		if id in (pair as Array):
			mine = true
	if not mine:
		return false
	var ms := SwayCaster.modes_of(id)
	return mode in ms if not ms.is_empty() else mode == ""


static func _quick_parse(el: String, s: String) -> Dictionary:
	var id := s.get_slice("/", 0).strip_edges()
	var mode := s.get_slice("/", 1).strip_edges() if s.contains("/") else ""
	return {"id": id, "mode": mode} if quick_ok(el, id, mode) else {}


# --- The words -------------------------------------------------------------------------------------------------

## data/ring/elements.json, read once (reload_data() reads it again).
static func data() -> Dictionary:
	if _data.is_empty():
		reload_data()
	return _data


static func reload_data() -> void:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
	_data = d if d is Dictionary else {"elements": {}}


## An element's words: {label, competitor, art, style, color (a Color)}; ANY the lot's; {} for an unknown one.
static func info(el: String) -> Dictionary:
	var e: Variant = data().get("any", {}) if el == ANY else (data().get("elements", {}) as Dictionary).get(el, {})
	if not e is Dictionary or (e as Dictionary).is_empty():
		return {}
	var out := (e as Dictionary).duplicate(true)
	var c: Variant = out.get("color", [])
	out["color"] = Color(float(c[0]), float(c[1]), float(c[2])) if c is Array and (c as Array).size() >= 3 else Color(0.9, 0.92, 1.0)
	return out


## The element's name on the screen ("Fire").
static func label(el: String) -> String:
	return String(info(el).get("label", el.capitalize()))


## The name the element's competitors go by ("Ember": "You 1 : 0 Ember").
static func competitor(el: String) -> String:
	return String(info(el).get("competitor", label(el)))


## The element's one-line style ("pure offence: the fastest damage, the weakest defence").
static func style(el: String) -> String:
	return String(info(el).get("style", ""))


static func color(el: String) -> Color:
	return info(el).get("color", Color(0.9, 0.92, 1.0))


## The sport's name ("Tidebreak").
static func sport() -> String:
	return String((data().get("sport", {}) as Dictionary).get("name", "Tidebreak"))


## The sport's rule in a line (the menu's panel).
static func sport_line() -> String:
	return String((data().get("sport", {}) as Dictionary).get("line", ""))


## The sport's row's line in the main menu.
static func menu_line() -> String:
	return String((data().get("sport", {}) as Dictionary).get("menu_line", ""))


## What a difficulty means for the bot, in a line.
static func difficulty_line(d: String) -> String:
	return String((data().get("difficulties", {}) as Dictionary).get(d, ""))


## What a light mood looks like, in a line (the menu's panel).
static func light_line(l: String) -> String:
	return String((data().get("lights", {}) as Dictionary).get(l, ""))


## "best of 3" for 2 round wins.
static func rounds_label(to_win: int) -> String:
	return "best of %d" % (to_win * 2 - 1)


## The setup in a line: "Fire vs Water  ·  normal  ·  best of 3" (the menu's Quick match).
static func summary() -> String:
	var them: Array = []
	for f in foes:
		them.append(label(String(f)))
	return "%s vs %s  ·  %s  ·  %s" % [label(element), " and ".join(PackedStringArray(them)), difficulty, rounds_label(rounds_to_win)]
