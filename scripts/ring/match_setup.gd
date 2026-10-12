class_name MatchSetup
extends RefCounted
## THE MATCH'S SETUP for Tidebreak, the elemental ring sport (the owner, 2026-10-04: the sport is called Tidebreak; a 1 v 1
## first; 2026-10-10: 2 v 2 and 4 v 4 on decks big enough, docs/tidebreak/team_formats_and_arenas.md): what the main menu chose, or the user args gave, for the ring scene
## (scenes/ring.tscn) to take at its start. Statics, so they outlive the scene change (the menu fills them, LoadingScreen
## loads the ring, the ring's level takes them).
##   element        the player's element (Bending.ELEMENTS): the character's own once it is chosen (AppearanceStore.element, read
##                  by load()), else the kept setup's; a match may play another, which is that match's only
##   foes           the other side's elements, one per competitor (["water"] in a 1 v 1); ANY is drawn by lot when the
##                  match begins (resolved()); a team format's side short of names is filled with ANY (lineup())
##   mates          the player's team-mates' elements ([] in a 1 v 1; a team format's short of names filled with ANY)
##   difficulty     the bots' (DIFFICULTIES: easy, normal, hard)
##   rounds_to_win  round wins that take the match (2: best of 3)
##   round_s        a round's length (s)
##   spectate       the player off the deck while two bots play (soak tests, stills)
##   light          the ring's light (LIGHTS: "noon", "golden", "night"; RingLook and RingDressing at the ring's load)
##   scheme         how the player chooses his moves (SCHEMES, data/bending/schemes.json; the owner, 2026-10-05: "still
##                  difficult for a human to switch spells" -> all three as options; round 2's skills: Keys the default,
##                  the others under Controls' other ways): "keys" (1-4 a key's first move, tapped twice its other; 5
##                  Patch, twice Mend), "direction" (the direction held as the right button is pressed picks key 1's
##                  first move, the wall or key 3's dash), "radial" (hold Tab: the moves round a wheel), "first_moves"
##                  (1-4 their first move only; it replaces "simple" and its distance band: a kept "simple" reads as it).
##                  Kept at once in GameSettings' "match" section (set_scheme; read lazily, scheme()); the user arg
##                  scheme= for a run. The ring and the duel alike; only the player's input (SwayCaster, Hotbar) reads it.
##   kind           "match" (rounds, a score) or "practice" (KINDS: a dummy of foes[0]'s element, no timer, no rounds; RingMode)
##   dummy          the practice dummy's way (DUMMIES: "stand" still, "block" its guards and cover, "throw" its element's
##                  strike every few seconds, so every guard can be practised: practice_move; data/ring/screens.json
##                  "practice")
##   format         "1v1", "2v2" or "4v4" (FORMATS; team_size(f) its fighters a side; RingArena's deck for it: ring.json
##                  formats). Practice and Quick match are 1v1's; kept with the setup
## The words a player sees come from data/ring/elements.json (info, label, competitor, style, color, sport): each element's
## name, the name its competitors go by (Stone, Tide, Ember, Gale) and its one-line style; no word from any show
## (tests/ring/test_player_words.gd holds them to that).
##
##   MatchSetup.requested()       the menu's request (incoming) or the user arg mode=ring
##   MatchSetup.take()            the ring at its start: the user args applied, the request taken; active() from then on
##   MatchSetup.active()          a ring match asked for or under way (PlayerAppearance: no creator over the countdown)
##   MatchSetup.leave()           the main menu again: no match
##   MatchSetup.save() / load()   the last setup in GameSettings' "match" section (the menu's panel and Quick match)
##   MatchSetup.quick_of(el) / set_quick(el, id, mode)   each element's quick spell on LMB (GameSettings' "quick" section;
##       its default the element's jab, moves.json "jabs": jab_of)
##   MatchSetup.scheme() / set_scheme(s) / next_scheme()   the control scheme (GameSettings' "match" section, key scheme);
##       scheme_label, scheme_text(field), scheme_row(_line), direction_move(el, dir), first_moves(el), scheme_keys_head /
##       scheme_key_lines(el): data/bending/schemes.json's (simple_skills / simple_entry / simple_mode: the old scheme's
##       names, answered from first_moves)
##   MatchSetup.controls() / basic() / set_controls(c) / next_controls()   round 4 SIMPLE: the Controls preset, "basic" (a
##       new player's default: the seven Basic keys, the game doing the hard parts, RingAssist; scheme() is then "keys") or
##       "full" (every key, every option, the schemes); controls_label, controls_row(_line); GameSettings' match section,
##       key controls; the user arg controls=basic|full
##   MatchSetup.practice_move(el, what)   the practice dummy's move for "throw" (key 1's first) or "cover" (its wall)
##   MatchSetup.quick_match(rng)  Quick match from the main menu: your last element and the rest of the last setup, the
##                                opponent's element drawn at random (the kept setup's opponent is not overwritten by it)
##   MatchSetup.set_practice(foe, dummy) / set_match()   what the next Begin plays (the menu's Practice and Begin)
##   MatchSetup.practice()        a practice asked for (kind)
##   MatchSetup.rule_set() / games() / practice_pct()   round 3 (smash_r3 spec §7.3-7.4, §11.1, §14.3; BOTS'): the rule set
##       the next ring plays ("stock" the % layer, "classic" today's zones; the Esc menu's Rules row "Lives" / "Zones", the
##       user arg rules=; rules.json rule_set until one is chosen), the games in a match (1 or 3: best of 3; games=), a
##       practice's % per side ({foe, player}: the Practice rows' values, a side left out grows as in a match; foe_pct=,
##       my_pct=). The Practice rows' other choices: steer (the dummy's steering), speed (Engine.time_scale), fresh (no stale
##       moves), throw_me (R puts you off an end); rule_label, games_label, pct_label; all kept in GameSettings' "match" section
##       (data/ring/practice.json: the rows' lists and words)
##   MatchSetup.parse(args)       the setup's user args, as take() reads them:
##       mode=ring element=fire foe=water[,earth,...] mates=air[,...] difficulty=hard to_win=2 round_s=90 spectate=on
##       light=golden scheme=direction practice=throw (or mode=practice: a practice with the kept dummy) rules=stock|classic
##       games=1|3 foe_pct=120|grows my_pct=60 steer=none|in|out|random speed=0.5 fresh=on throw_me=on

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
## The practice dummy's ways, the first the default (the classic ring's; the % ring's are STOCK_DUMMIES).
const DUMMIES := ["stand", "block", "throw"]
## Round 3: the % ring's Practice ways (data/ring/practice.json ways), B steps them.
const STOCK_DUMMIES := ["stand", "walk", "jump", "block", "guard_held", "guard_after", "recover", "throw", "fight"]
## Round 3: the rule sets the menu offers ("stock" the % layer, Lives; "zones" the zones on the new ring, Zones: the owner,
## 2026-10-11, "zones is still good ... it should have all the new bending movements") and the games of a match. Round 2's
## "classic" is a run's or a test's only (rules=classic, RingRules.rule_set_override).
const RULE_SETS := ["stock", "zones"]
const GAMES := [1, 3]
## Practice's rows (data/ring/practice.json).
const PRACTICE_PATH := "res://data/ring/practice.json"
## The match formats; only those in FORMATS_READY can be played (the rest are shown as coming).
const FORMATS := ["1v1", "2v2", "4v4"]
const FORMATS_READY := ["1v1", "2v2", "4v4"]

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
## Round 3: the rule set chosen ("" : rules.json rule_set), the games of a match (1, 3), Practice's rows: its % and yours (-1:
## grows), its steering, the speed, every move fresh, R throws you off.
static var rules_choice := ""
static var games_n := 1
static var foe_pct := -1.0
static var my_pct := -1.0
static var steer := "none"
static var speed := 1.0
static var fresh := false
static var throw_me := false
static var _practice := {}

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
				if v in DUMMIES or v in STOCK_DUMMIES:
					dummy = v
			"dummy":
				if v in DUMMIES or v in STOCK_DUMMIES:
					dummy = v
			"rules", "rule_set":
				var rs := String({"lives": "stock"}.get(v, v))
				if rs in RULE_SETS or rs == "classic":
					rules_choice = rs
			"games":
				if v.is_valid_int() and int(v) in GAMES:
					games_n = int(v)
			"foe_pct", "its_pct":
				foe_pct = _pct_arg(v, foe_pct)
			"my_pct", "your_pct":
				my_pct = _pct_arg(v, my_pct)
			"steer":
				if v in ["none", "in", "out", "random"]:
					steer = v
			"speed":
				if v.is_valid_float() and float(v) > 0.0:
					speed = clampf(float(v), 0.1, 1.0)
			"fresh":
				fresh = v in ["on", "true", "yes", "1"]
			"throw_me":
				throw_me = v in ["on", "true", "yes", "1"]
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
			"aim", "aim_help":
				if v in AIMS:
					_aim_help = v                # (for the run: not kept)
			"scheme", "controls":
				if k == "controls" and v in CONTROLS:
					_controls = v                # (round 4: the Controls preset for the run: not kept)
					continue
				v = String(SCHEME_ALIASES.get(v, v))
				if v in SCHEMES:
					_scheme = v                  # (for the run: not kept)
					_controls = "full"           # (a scheme is Full's)
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
	GameSettings.set_section(SECTION, {"element": element, "foe": f, "format": format if not quick else String(_kept("format", "1v1")),
			"difficulty": difficulty, "rounds": rounds_to_win,
			"light": light, "dummy": dummy, "rules": rules_choice, "games": games_n, "foe_pct": foe_pct, "my_pct": my_pct,
			"steer": steer, "speed": speed, "fresh": fresh, "throw_me": throw_me})


## The kept setup read back over the statics (each value only when it is a good one). The element is the character's own once it
## is chosen (AppearanceStore.element: the step after the character is made), else the kept one; a match may play another element,
## but that is that match's only (save() keeps it as the last setup's, the next read starts from the character's again).
static func load() -> void:
	var el := String(GameSettings.get_value(SECTION, "element"))
	if el in Bending.ELEMENTS:
		element = el
	var mine := AppearanceStore.element()
	if mine != "":
		element = mine
	var f := elements_in(String(GameSettings.get_value(SECTION, "foe")), true)
	if not f.is_empty():
		foes = f
	var fm := str(_kept("format", "1v1"))
	format = fm if fm in FORMATS else "1v1"
	var d := String(GameSettings.get_value(SECTION, "difficulty"))
	if d in DIFFICULTIES:
		difficulty = d
	var r := int(GameSettings.get_value(SECTION, "rounds"))
	if r >= 1:
		rounds_to_win = r
	var l := String(GameSettings.get_value(SECTION, "light"))
	if l in LIGHTS:
		light = l
	_scheme = ""                                 # (read again from the file on its next ask)
	var dm := str(_kept("dummy", DUMMIES[0]))
	if dm in DUMMIES or dm in STOCK_DUMMIES:
		dummy = dm
	# (round 3's rows)
	var rs := str(_kept("rules", ""))
	if rs == "classic":
		rs = "zones"                             # (kept before 2026-10-11: the menu's Zones was round 2's ring, now the new one's)
	rules_choice = rs if rs in RULE_SETS else ""
	var gm := int(_kept("games", 1))
	games_n = gm if gm in GAMES else 1
	foe_pct = _pct_arg(str(_kept("foe_pct", -1.0)), -1.0)
	my_pct = _pct_arg(str(_kept("my_pct", -1.0)), -1.0)
	var sr := str(_kept("steer", "none"))
	steer = sr if sr in ["none", "in", "out", "random"] else "none"
	speed = clampf(float(_kept("speed", 1.0)), 0.1, 1.0)
	fresh = bool(_kept("fresh", false))
	throw_me = bool(_kept("throw_me", false))


## A kept value of the "match" section that GameSettings.DEFAULTS may not list (the practice dummy): read from its file as
## get_value reads, `def` when it is not there.
static func _kept(key: String, def: Variant) -> Variant:
	if ((GameSettings.DEFAULTS.get(SECTION, {})) as Dictionary).has(key):
		return GameSettings.get_value(SECTION, key)
	var cf := ConfigFile.new()
	cf.load(GameSettings.file())
	return cf.get_value(SECTION, key, def)


# --- Quick match and practice: the menu's entry points ------------------------------------------------------------

## Quick match (the main menu's): the last setup (load()), your last element and team size (1v1, 2v2, 4v4), the opponent's
## element drawn at random (from `rng`, a test's; else a fresh one), a match (not a practice). The menu then plays it as Begin
## does; the kept setup's own opponent is left as it was (save() while quick). Returns the drawn element.
static func quick_match(rng: RandomNumberGenerator = null) -> String:
	MatchSetup.load()
	var r := rng
	if r == null:
		r = RandomNumberGenerator.new()
		r.randomize()
	var el := String(Bending.ELEMENTS[r.randi_range(0, Bending.ELEMENTS.size() - 1)])
	foes = [el]
	kind = "match"
	quick = true                                 # (the team size the setup last kept: 1v1, 2v2 or 4v4; the owner, 2026-10-11)
	return el


## Quick match's line under its row: "Earth against a random opponent  ·  normal  ·  best of 3" (the kept setup's; in the %
## ring its games, "one game" or "best of 3": the rounds are the zones' only).
static func quick_line() -> String:
	var length := rounds_label(rounds_to_win)
	if rule_set() == "stock":
		length = rounds_label(2) if games() >= 3 else String(screens().get("one_game", "one game"))
	var line := String(screens().get("quick_line", "%s against a random opponent  ·  %s  ·  %s")) % [label(element), difficulty, length]
	if team_size() > 1:
		var fm: Dictionary = (data().get("formats", {}) as Dictionary).get(format, {})
		line = String(fm.get("label", format)) + "  ·  " + line
	return line


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


## Round 3: the rule set the next ring plays ("stock": the % layer; "classic": today's zones): the menu's or the user arg's
## choice, else rules.json rule_set.
static func rule_set() -> String:
	if RingRules.rule_set_override in RingRules.RULE_SETS:
		return RingRules.rule_set_override       # (a test's or a tool's pin: what the next ring plays, RingRules.pick_rule_set)
	if rules_choice in RingRules.RULE_SETS:
		return rules_choice
	var d := String(RingRules.data().get("rule_set", "classic"))
	return d if d in RingRules.RULE_SETS else "classic"


## Round 3: the games in a match (1, or 3: best of 3, the first to two).
static func games() -> int:
	return games_n if games_n in GAMES else 1


## Round 3: a practice's % per side, from its rows: {foe, player} (a side left out grows as in a match). {} outside a
## practice.
static func practice_pct() -> Dictionary:
	if not practice():
		return {}
	var out := {}
	if foe_pct >= 0.0:
		out["foe"] = foe_pct
	if my_pct >= 0.0:
		out["player"] = my_pct
	return out


## A % row's value from text ("120", "grows": -1); `def` when it is neither.
static func _pct_arg(v: String, def: float) -> float:
	if v == "grows" or v == "-1" or v == "-1.0":
		return -1.0
	return clampf(float(v), 0.0, 999.0) if v.is_valid_float() else def


## data/ring/practice.json (round 3's Practice rows and words), read once.
static func practice_data() -> Dictionary:
	if _practice.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PRACTICE_PATH)) if FileAccess.file_exists(PRACTICE_PATH) else null
		_practice = d if d is Dictionary else {"_": true}
	return _practice


## A Practice word (practice.json words).
static func pword(key: String) -> String:
	return String((practice_data().get("words", {}) as Dictionary).get(key, key))


## A round-3 menu word (practice.json menu).
static func menu_word(key: String) -> String:
	return String((practice_data().get("menu", {}) as Dictionary).get(key, key))


## The Rules row's word for rule set `rs`: "Lives" or "Zones" (never the ids).
static func rule_label(rs := "") -> String:
	return menu_word(rs if rs != "" else rule_set())


## The Games row's word: "1" or "best of 3".
static func games_label(n := 0) -> String:
	return menu_word("games_%d" % (n if n > 0 else games()))


## A % row's value in words: "120%" or "grows".
static func pct_label(v: float) -> String:
	return pword("grows") if v < 0.0 else "%d%%" % roundi(v)


## The next value of a list after `v` (the rows step through theirs).
static func next_in(list: Array, v: Variant) -> Variant:
	var i := list.find(v)
	return list[(i + 1) % list.size()] if not list.is_empty() else v


## The dummy's ways B steps under the rule set now (the new ring's, Lives or Zones, or round 2's classic).
static func dummy_ways() -> Array:
	return STOCK_DUMMIES if rule_set() in RingRules.NEW_RING else DUMMIES


## The practice dummy's move for `what` as "id/variation" ("" none): "throw" its element's key 1 first move (earth Spike,
## water Lash, fire Punch, air Slice: every guard has something to take on the beat), "cover" its wall (key 4's first).
## From the element's keys (Bending.keys), so it follows the kit; screens.json practice's own table is the fallback.
static func practice_move(el: String, what: String) -> String:
	var ks := Bending.keys(el)
	var k := 0 if what == "throw" else 3 if what == "cover" else -1
	if k >= 0 and k < ks.size() and not (ks[k] as Array).is_empty():
		var id := String((ks[k] as Array)[0])
		var ms := SwayCaster.modes_of(id)
		return "%s/%s" % [id, String(ms[0]) if not ms.is_empty() else ""]
	return String((((screens().get("practice", {}) as Dictionary).get(what, {})) as Dictionary).get(el, ""))


## Whether format `f` can be played now; the others are shown as coming.
static func format_ready(f: String) -> bool:
	return f in FORMATS_READY


## The fighters a side in format `f` ("" the chosen one): 1, 2 or 4.
static func team_size(f := "") -> int:
	var x := f if f != "" else format
	return maxi(int(x.get_slice("v", 0)), 1) if x.get_slice("v", 0).is_valid_int() else 1


## The match's sides, `n` fighters a side (-1: the chosen format's; a practice 1), ANY drawn by lot from `rng`: {mates: the
## player's team-mates' elements (n - 1), foes: the other side's (n; foes[0] the chosen opponent, foe())}. Names short of a
## side are ANY. A 1v1 draws as resolved([foe()]) does.
static func lineup(rng: RandomNumberGenerator, n := -1) -> Dictionary:
	if n < 1:
		n = 1 if practice() else team_size()
	var m: Array = mates.slice(0, n - 1)
	while m.size() < n - 1:
		m.append(ANY)
	var f: Array = [foe()] + foes.slice(1, n)
	while f.size() < n:
		f.append(ANY)
	return {"mates": resolved(m, rng), "foes": resolved(f, rng)}


## The practice dummy's way in words ("throws a stone every few seconds"; data/ring/screens.json practice.ways, the % ring's
## own ways from practice.json way_lines).
static func dummy_line(way: String) -> String:
	var p: Dictionary = screens().get("practice", {})
	var ws: Dictionary = p.get("ways", {})
	if ws.has(way) and not (rule_set() == "stock" and (practice_data().get("way_lines", {}) as Dictionary).has(way)):
		return String(ws[way])
	return String((practice_data().get("way_lines", {}) as Dictionary).get(way, ws.get(way, way)))


## data/ring/screens.json (the round and match screens' words, the loading tips, the practice dummy), read once.
static func screens() -> Dictionary:
	if _screens.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCREENS_PATH)) if FileAccess.file_exists(SCREENS_PATH) else null
		_screens = d if d is Dictionary else {"_": true}
	return _screens


# --- The quick spell (LMB), per element --------------------------------------------------------------------------

## Each element's quick spell on the left button (SwayCaster's quick spell: one move at one variation, frozen), kept in
## GameSettings' QUICK_SECTION as "move/variation". Its default is the element's jab (data/sway/moves.json "jabs", round
## 2's skills: earth rock_jab/pebbles, water water_jet/splash, fire fire_jab/embers, air air_palm/palm), else GameSettings'
## DEFAULTS; the jab is a quick spell of its element though it is on none of 1-4. A kept one the kit no longer has (fire's
## old fire_jab/jab) gives the default. A test points GameSettings.path at a file of its own.
const QUICK_SECTION := "quick"


## Element `el`'s quick spell: {id, mode} (the one kept, else its default; {} for no element).
static func quick_of(el: String) -> Dictionary:
	if not el in Bending.ELEMENTS:
		return {}
	var kept := _quick_parse(el, String(GameSettings.get_value(QUICK_SECTION, el)))
	if not kept.is_empty():
		return kept
	return quick_default(el)


## Element `el`'s default quick spell ({id, mode}; {} for no element): its jab (jab_of), else GameSettings' default.
static func quick_default(el: String) -> Dictionary:
	var j := jab_of(el)
	if not j.is_empty():
		return j
	var d: Dictionary = GameSettings.DEFAULTS.get(QUICK_SECTION, {})
	return _quick_parse(el, String(d.get(el, "")))


## Element `el`'s jab on the left button (moves.json "jabs": {id, mode}; {} none or not a move of the data).
static func jab_of(el: String) -> Dictionary:
	var j: Variant = (SwayMoves.data().get("jabs", {}) as Dictionary).get(el, [])
	if not (j is Array) or (j as Array).size() < 2 or not el in Bending.ELEMENTS:
		return {}
	var id := String(j[0])
	var mode := String(j[1])
	var ms := SwayCaster.modes_of(id)
	return {"id": id, "mode": mode} if mode in ms or (ms.is_empty() and mode == "") else {}


## Element `el`'s quick spell kept as `id` in `mode` (false, nothing kept, when it is not one of the element's moves).
static func set_quick(el: String, id: String, mode: String) -> bool:
	if not quick_ok(el, id, mode):
		return false
	GameSettings.set_value(QUICK_SECTION, el, "%s/%s" % [id, mode])
	return true


## Whether `id` in `mode` can be element `el`'s quick spell: its jab, or one of its keys' moves (Bending.keys), `mode` one
## of its variations ("" for a move with none).
static func quick_ok(el: String, id: String, mode: String) -> bool:
	if not el in Bending.ELEMENTS or id == "":
		return false
	var j := jab_of(el)
	if not j.is_empty() and String(j.id) == id and String(j.mode) == mode:
		return true
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


# --- The control scheme (how moves are chosen) ---------------------------------------------------------------------

## (the file: SwayCaster.SCHEMES_DATA, data/.../schemes.json; its path is kept out of this file's words)
const SCHEMES_PATH := SwayCaster.SCHEMES_DATA
## The schemes, in the menus' order (data/bending/schemes.json "order"; the first is the default).
const SCHEMES := ["keys", "direction", "radial", "first_moves"]
## Old scheme ids a settings file or a user arg may still hold -> the scheme now ("simple" became "first_moves" in round 2:
## the same four first moves, no distance band).
const SCHEME_ALIASES := {"simple": "first_moves"}
## The key in GameSettings' SECTION the scheme is kept under.
const SCHEME_KEY := "scheme"
## The directions the direction scheme reads (SwayCaster.held_dir).
const DIRS := ["forward", "back", "side"]

static var _scheme := ""                 ## "" until read (scheme())
static var _schemes := {}


## data/bending/schemes.json, read once (reload_schemes() reads it again).
static func schemes_data() -> Dictionary:
	if _schemes.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCHEMES_PATH)) if FileAccess.file_exists(SCHEMES_PATH) else null
		_schemes = d if d is Dictionary else {"schemes": {}}
	return _schemes


static func reload_schemes() -> void:
	_schemes = {}


## The scheme now ("keys" until one is chosen): the run's (scheme= or set_scheme), else the one kept in the settings file.
## Under the Basic controls (round 4: controls()) always "keys": Basic's keys are the keys scheme's.
static func scheme() -> String:
	if basic():
		return "keys"
	if _scheme == "":
		var cf := ConfigFile.new()
		cf.load(GameSettings.file())
		var s := String(cf.get_value(SECTION, SCHEME_KEY, schemes_data().get("default", "keys")))
		s = String(SCHEME_ALIASES.get(s, s))
		_scheme = s if s in SCHEMES else "keys"
	return _scheme


## The scheme set to `s` and kept at once (GameSettings' match section); false (nothing changed) when it is no scheme.
## A scheme chosen is Full's: the Controls preset goes to "full" with it (round 4).
static func set_scheme(s: String) -> bool:
	s = String(SCHEME_ALIASES.get(s, s))
	if not s in SCHEMES:
		return false
	_scheme = s
	_controls = "full"
	GameSettings.set_section(SECTION, {SCHEME_KEY: s, CONTROLS_KEY: "full"})
	return true


## The scheme after `s` in the menus' order (a press on the menu's row).
static func next_scheme(s := "") -> String:
	var cur := s if s != "" else scheme()
	return String(SCHEMES[(SCHEMES.find(cur) + 1) % SCHEMES.size()])


## Forgets the scheme read (the next scheme() reads the settings file again: a test's own file).
static func reload_scheme() -> void:
	_scheme = ""
	_aim_help = ""
	_controls = ""


# --- The Controls preset (round 4 SIMPLE: "simple like runescape but hard to master like runescape") ---------------
## "basic" (a new player's: LMB jab, right-click casts, 1 Strike, 2 Push, E Guard, Space, 3 Dash; Wall and Heal after his
## first win; the game does the hard parts: RingAssist, data/ring/assist.json) or "full" (every key and option, and the
## control schemes: scheme()). Kept at once in GameSettings' match section (CONTROLS_KEY); the user arg controls=basic|full
## for a run. No preset kept: a kept scheme (one chosen before there were presets) reads "full", else "basic"; a script run
## (-s: the tests and tools) reads "full" unless it asks (controls=basic, set_controls), so every older test keeps its keys.
## The words: data/bending/schemes.json "controls".
const CONTROLS := ["basic", "full"]
const CONTROLS_KEY := "controls"
static var _controls := ""               ## "" until read (controls())


static func controls() -> String:
	if _controls == "":
		var cf := ConfigFile.new()
		cf.load(GameSettings.file())
		var c := String(cf.get_value(SECTION, CONTROLS_KEY, ""))
		if not c in CONTROLS:
			var scripted := "-s" in OS.get_cmdline_args() or "--script" in OS.get_cmdline_args()
			c = "full" if scripted or cf.has_section_key(SECTION, SCHEME_KEY) else _controls_default()
		_controls = c
	return _controls


static func _controls_default() -> String:
	var d := String((schemes_data().get("controls", {}) as Dictionary).get("default", "basic"))
	return d if d in CONTROLS else "basic"


## The Basic controls are on.
static func basic() -> bool:
	return controls() == "basic"


## The preset set to `c` and kept at once; false (nothing changed) when it is none.
static func set_controls(c: String) -> bool:
	if not c in CONTROLS:
		return false
	_controls = c
	GameSettings.set_value(SECTION, CONTROLS_KEY, c)
	return true


## The preset after `c` (a press on the menus' Controls row).
static func next_controls(c := "") -> String:
	var cur := c if c != "" else controls()
	return String(CONTROLS[(CONTROLS.find(cur) + 1) % CONTROLS.size()])


static func _controls_words() -> Dictionary:
	return schemes_data().get("controls", {})


## The preset's name ("Basic", "Full").
static func controls_label(c := "") -> String:
	var k := c if c != "" else controls()
	return String(((_controls_words().get("labels", {})) as Dictionary).get(k, k.capitalize()))


## The menus' row: "Controls:  Basic" and the line under it.
static func controls_row() -> String:
	return String(_controls_words().get("row", "Controls:  %s")) % controls_label()


static func controls_row_line(c := "") -> String:
	var k := c if c != "" else controls()
	return String(((_controls_words().get("lines", {})) as Dictionary).get(k, ""))


# --- The aim's help (the owner, 2026-10-05: "the auto aim is to strong yo") -----------------------------------------
## How much the player's casts are helped onto a fighter near the crosshair (PlayerBendCaster.assist_target and
## target_point): "light" (the default, everywhere, shown as Normal (the owner, 2026-10-12: "normal aim assist should be
## default everywhere"): a 2 deg cone, the shot pulled under half way from the crosshair toward his chest, no lead), "off"
## (the crosshair only), "strong" (the old help: a 6 deg cone, his chest, led for the flight). Kept at once in GameSettings'
## match section (AIM_KEY); the user arg aim= for a run. Bots are not helped by it.
const AIMS := ["light", "off", "strong"]
## The order the choices are shown and stepped in (least help to most: Off, Light, Strong); AIMS stays the data's (light first: the default).
const AIM_ORDER := ["off", "light", "strong"]
const AIM_KEY := "aim_help"
const AIM_CONE_DEG := {"off": 0.0, "light": 2.0, "strong": 6.0}
const AIM_PULL := {"off": 0.0, "light": 0.45, "strong": 1.0}
## The words a choice is shown by (the data's "light" is Normal to the player).
const AIM_NAMES := {"off": "Off", "light": "Normal", "strong": "Strong"}
static var _aim_help := ""


static func aim_help() -> String:
	if _aim_help == "":
		var cf := ConfigFile.new()
		cf.load(GameSettings.file())
		var a := String(cf.get_value(SECTION, AIM_KEY, AIMS[0]))
		_aim_help = a if a in AIMS else String(AIMS[0])
	return _aim_help


static func set_aim_help(a: String) -> bool:
	if not a in AIMS:
		return false
	_aim_help = a
	GameSettings.set_value(SECTION, AIM_KEY, a)
	return true


static func next_aim_help() -> String:
	return String(AIM_ORDER[(AIM_ORDER.find(aim_help()) + 1) % AIM_ORDER.size()])


static func aim_cone_deg() -> float:
	return float(AIM_CONE_DEG.get(aim_help(), 2.0))


static func aim_pull() -> float:
	return float(AIM_PULL.get(aim_help(), 0.45))


## The name the player sees for choice `a` (the one kept when "").
static func aim_name(a := "") -> String:
	var k := a if a != "" else aim_help()
	return String(AIM_NAMES.get(k, k.capitalize()))


static func aim_row() -> String:
	return "Aim help:  %s" % aim_name()


static func aim_row_line() -> String:
	match aim_help():
		"off":
			return "your casts go where the crosshair is"
		"strong":
			return "casts snap onto a foe near the crosshair and lead him"
	return "a light nudge toward a foe right by the crosshair"


static func _scheme_info(s: String) -> Dictionary:
	return (schemes_data().get("schemes", {}) as Dictionary).get(s, {})


## The scheme's name on the screen ("Direction").
static func scheme_label(s := "") -> String:
	var k := s if s != "" else scheme()
	return String(_scheme_info(k).get("label", k.capitalize()))


## A scheme's words with the wheel's key as bound put in (`field`: "line" the menus', "strip" the strip's help, "f1").
static func scheme_text(field: String, s := "") -> String:
	var k := s if s != "" else scheme()
	var t := String(_scheme_info(k).get(field, ""))
	if t.contains("%s"):
		RadialWheel.ensure_input()             # (the main menu says it before any player has made the action)
		var key := SwayCaster.key_name(RadialWheel.ACTION)
		t = t % (key if key != "" else "(no key)")
	return t


## The menus' row words: "Control scheme:  Direction" and the line under it.
static func scheme_row() -> String:
	return String((schemes_data().get("words", {}) as Dictionary).get("row", "Control scheme:  %s")) % scheme_label()


static func scheme_row_line() -> String:
	return scheme_text("line")


## The direction scheme's move for element `el` and direction `dir` (DIRS): {id, mode}; {} none (no element, no direction).
static func direction_move(el: String, dir: String) -> Dictionary:
	var m: Variant = ((schemes_data().get("direction", {}) as Dictionary).get(el, {}) as Dictionary).get(dir, [])
	if not m is Array or (m as Array).size() < 2:
		return {}
	var id := String(m[0])
	var mode := String(m[1])
	return {"id": id, "mode": mode} if quick_ok(el, id, mode) else {}


## How far the move keys must be held for a direction (0..1 of the stick; the keys give 1).
static func direction_dead_zone() -> float:
	return float((schemes_data().get("direction", {}) as Dictionary).get("dead_zone", 0.3))


## The first-moves scheme's four for `el`: [{id, mode}] in key order (schemes.json first_moves; else the first move of
## keys 1-4, Bending.keys, at its first variation), each one of the element's own (quick_ok).
static func first_moves(el: String) -> Array:
	var out: Array = []
	var l: Variant = (schemes_data().get("first_moves", {}) as Dictionary).get(el, [])
	if l is Array and not (l as Array).is_empty():
		for e: Variant in l:
			if e is Array and (e as Array).size() >= 2 and quick_ok(el, String(e[0]), String(e[1])):
				out.append({"id": String(e[0]), "mode": String(e[1])})
		return out
	var ks := Bending.keys(el)
	for i in mini(4, ks.size()):
		var id := String((ks[i] as Array)[0])
		var ms := SwayCaster.modes_of(id)
		out.append({"id": id, "mode": String(ms[0]) if not ms.is_empty() else ""})
	return out


## The old Simple scheme's names, answered from first_moves (a caller of before round 2): [{id, near, far, near_m}] with
## near and far both the move's first variation (no distance band any more).
static func simple_skills(el: String) -> Array:
	var out: Array = []
	for e: Dictionary in first_moves(el):
		out.append({"id": e.id, "near": e.mode, "far": e.mode, "near_m": 0.0})
	return out


## The first-moves entry for move `id` of `el` (simple_skills' shape; {} when it is not one of the four).
static func simple_entry(el: String, id: String) -> Dictionary:
	for e in simple_skills(el):
		if e is Dictionary and String((e as Dictionary).get("id", "")) == id:
			return e
	return {}


## The variation the first-moves scheme casts `id` at (its first; the distance no longer picks); "" when `id` is not one
## of `el`'s four.
static func simple_mode(el: String, id: String, _dist: float) -> String:
	return String(simple_entry(el, id).get("near", ""))


## The head over an element's moves as the scheme `s` has them (the main menu's keys block, the ring's Controls panel):
## "EARTH KEYS  ·  tap a key twice: its other move".
static func scheme_keys_head(el: String, s := "") -> String:
	var k := String(SCHEME_ALIASES.get(s, s)) if s != "" else scheme()
	RadialWheel.ensure_input()
	var heads := {"keys": "%s KEYS  ·  tap a key twice: its other move",
			"direction": "%s MOVES  ·  the direction held as you press the right button",
			"radial": "%s MOVES  ·  hold " + SwayCaster.key_name(RadialWheel.ACTION) + ": all of them round a wheel",
			"first_moves": "%s MOVES  ·  each key's first move"}
	return String(heads.get(k, heads["keys"])) % label(el).to_upper()


## An element's moves as lines under the scheme `s` ("" the scheme now): the keys ("1   Spike  ·  Boulder", the radial
## wheel's too: it holds them all), the direction scheme's ("W   Stone Form: Spike", ..., "1-5   nothing held: the key's
## move"), the first-moves scheme's four ("1   Spike").
static func scheme_key_lines(el: String, s := "") -> Array:
	var k := String(SCHEME_ALIASES.get(s, s)) if s != "" else scheme()
	var out: Array = []
	match k:
		"direction":
			var heads := {"forward": "W", "back": "S", "side": "A D"}
			for d: String in DIRS:
				var dm := direction_move(el, d)
				if not dm.is_empty():
					out.append("%s   %s: %s" % [heads[d], _move_label(String(dm.id)), SwayCaster.mode_label(String(dm.id), String(dm.mode))])
			out.append("1-5   nothing held: the key's move")
		"first_moves":
			var four := first_moves(el)
			for i in four.size():
				var e: Dictionary = four[i]
				out.append("%d   %s" % [i + 1, SwayCaster.mode_label(String(e.id), String(e.mode))])
		_:
			var keys := Bending.keys(el)
			for i in keys.size():
				out.append("%d   %s" % [i + 1, "  ·  ".join(PackedStringArray(key_names(keys[i] as Array)))])
	return out


## A key's moves by name, its first first ([id] with two variations: each variation's; [id, id]: each move's first): the
## plain names of the kits (Spike, Boulder; Patch, Mend).
static func key_names(key: Array) -> Array:
	var names: Array = []
	if key.size() == 1:
		var id := String(key[0])
		var ms := SwayCaster.modes_of(id)
		if ms.size() >= 2:
			for md: String in ms:
				names.append(SwayCaster.mode_label(id, md))
			return names
	for idv: Variant in key:
		var id2 := String(idv)
		var ms2 := SwayCaster.modes_of(id2)
		names.append(SwayCaster.mode_label(id2, String(ms2[0])) if not ms2.is_empty() else _move_label(id2))
	return names


static func _move_label(id: String) -> String:
	return String(SwayMoves.move(id).get("label", id.capitalize()))


## The radial wheel's numbers (data/bending/schemes.json "radial").
static func radial_num(key: String, def: float) -> float:
	return float((schemes_data().get("radial", {}) as Dictionary).get(key, def))


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


## The sport's rule in a line (the menu's panel): the rule set's own ("line_stock": the % ring's lives), else "line" (the zones).
static func sport_line() -> String:
	var sp: Dictionary = data().get("sport", {})
	var line := String(sp.get("line_" + rule_set(), sp.get("line", "")))
	return String(sp.get("line_" + rule_set() + "_team", line)) if team_size() > 1 else line


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
