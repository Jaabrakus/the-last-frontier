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
##   MatchSetup.parse(args)       the setup's user args, as take() reads them:
##       mode=ring element=fire foe=water[,earth,...] mates=air[,...] difficulty=hard to_win=2 round_s=90 spectate=on

const DATA_PATH := "res://data/ring/elements.json"
## GameSettings' section the last setup is kept in.
const SECTION := "match"
## The opponent drawn by lot (the menu's "Any").
const ANY := "any"
const DIFFICULTIES := ["easy", "normal", "hard"]
## The round wins the menu offers (best of 1, 3 and 5).
const ROUNDS := [1, 2, 3]

## Set by the main menu's Begin for the scene it loads (taken once: take()).
static var incoming := false
static var element := "earth"
static var foes: Array = ["earth"]
static var mates: Array = []
static var difficulty := "normal"
static var rounds_to_win := 2
static var round_s := 180.0
static var spectate := false

static var _on := false
static var _data := {}


# --- The request ----------------------------------------------------------------------------------------------

## Whether a ring match is asked for: the main menu's Begin (incoming) or the user arg mode=ring.
static func requested() -> bool:
	if incoming:
		return true
	for a in OS.get_cmdline_user_args():
		if a.trim_prefix("--") == "mode=ring":
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
				ring = ring or v == "ring"
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
	GameSettings.set_section(SECTION, {"element": element, "foe": ",".join(PackedStringArray(foes)),
			"difficulty": difficulty, "rounds": rounds_to_win})


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


## "best of 3" for 2 round wins.
static func rounds_label(to_win: int) -> String:
	return "best of %d" % (to_win * 2 - 1)


## The setup in a line: "Fire vs Water  ·  normal  ·  best of 3" (the menu's Quick match).
static func summary() -> String:
	var them: Array = []
	for f in foes:
		them.append(label(String(f)))
	return "%s vs %s  ·  %s  ·  %s" % [label(element), " and ".join(PackedStringArray(them)), difficulty, rounds_label(rounds_to_win)]
