class_name KitWords
extends RefCounted
## What the player reads about his element's kit (Tidebreak, round 2 of the skills: the owner, 2026-10-05, "make the skills
## easy hard to master ... think human made think avg IQ"; skills_r2 spec §2, §6, §9): the same buttons for every element,
## one job each, said the same way on the strip (BendStrip), the move wheel (RadialWheel), F1 and the first-time panels
## (FrontierHUD, HowTo), the element pick and the Controls panels (MainMenu, RingMenu, DuelMenu) and the lessons
## (RingLessons). Every word from data/ring/screens.json "kit" (tests/ring/test_player_words.gd holds them to the owner's
## rule: no word from the show); the moves' plain names from moves.json's mode labels (Spike, Boulder, Fissure ...).
##   the buttons   LMB JAB · E GUARD · 1 STRIKE · 2 PUSH ▲ · 3 DASH · 4 WALL · 5 HEAL (role(i), ROLE_JAB, ROLE_GUARD)
##   a key         Bending.keys(el)[i]: [id] (one move, or one move with two modes) or [id, id] (two moves): key_moves(el, i)
##                 -> its first move and, tapped twice, its second ({id, mode} each; spec §10's other_move)
##   the jab       Bending.jab (moves.json "jabs", else spec §8.1's; then the element's first quick spell,
##                 MatchSetup.quick_default); the guard Bending.guard ("guards"); the passive's words screens.json kit.passives
##   lines         kit_lines(el, scheme): the element pick's and the Controls panel's; rule_lines(): F1's and the
##                 first-time panels' four rules; help_line(scheme): the duel's help line; strip_help(scheme): the
##                 strip's one help line (round 4: one line of 64 characters or fewer)
## The control schemes as the data names them: "first_moves" (round 2; "simple" before it) is read as one (scheme_id).

const ROLES := ["STRIKE", "PUSH", "DASH", "WALL", "HEAL"]
const ROLE_JAB := "JAB"
const ROLE_GUARD := "GUARD"
## The grow mark (▲: held past the second click the move grows; key 2 for every element, fire's 1 too).
const GROW := "▲"
## The jab's button as the lines name it (the left button: the quick spell's, never rebound).
const JAB_KEY := "LMB"
const GUARD_ACTION := InputSetup.GUARD_ACTION


## data/ring/screens.json "kit" (the words).
static func words() -> Dictionary:
	return MatchSetup.screens().get("kit", {})


static func w(key: String, def := "") -> String:
	return String(words().get(key, def))


## The scheme as one name: "simple" (before round 2) is "first_moves".
static func scheme_id(s := "") -> String:
	var k := s if s != "" else MatchSetup.scheme()
	return "first_moves" if k == "simple" else k


# --- the moves ---------------------------------------------------------------------------------------------------

## A move's plain name: its mode's label ("Spike", "Ice Wall"), the move's label when it has no modes ("Mend").
static func move_name(id: String, mode := "") -> String:
	if id == "":
		return ""
	var n := ""
	if mode != "":
		n = SwayCaster.mode_label(id, mode).replace("_", " ")
	if n == "":
		n = String(SwayMoves.move(id).get("label", id.capitalize()))
	return n.substr(0, 1).to_upper() + n.substr(1)


static func _first_mode(id: String) -> String:
	var ms := SwayCaster.modes_of(id)
	return String(ms[0]) if not ms.is_empty() else ""


## Key `i` (0-based) of element `el`: its moves, the first then the one a second tap readies ([{id, mode}], one or two).
## `body` (the player's, for his own strip and wheel): a one-move key's second is the mode a worn talent adds on its empty
## double tap (SwayCaster.modes_of: the Sulphur Vent on earth's 4, Mire on water's 4); null or wearing nothing, the static kit.
static func key_moves(el: String, i: int, body: Object = null) -> Array:
	var keys := Bending.keys(el)
	if i < 0 or i >= keys.size():
		return []
	var k: Array = keys[i]
	if k.size() >= 2:
		return [{"id": String(k[0]), "mode": _first_mode(String(k[0]))}, {"id": String(k[1]), "mode": _first_mode(String(k[1]))}]
	if k.is_empty():
		return []
	var id := String(k[0])
	var ms := SwayCaster.modes_of(id, body)
	if ms.size() >= 2:
		return [{"id": id, "mode": String(ms[0])}, {"id": id, "mode": String(ms[1])}]
	return [{"id": id, "mode": _first_mode(id)}]


## The key (0-based) that holds move `id` (at `mode`, any of its two when ""), and which of its moves it is: {key, at}
## ({key: -1} none).
static func key_of(el: String, id: String, mode := "") -> Dictionary:
	for i in Bending.keys(el).size():
		var ms := key_moves(el, i)
		for j in ms.size():
			if String(ms[j].id) == id and (mode == "" or String(ms[j].mode) == mode or ms.size() == 1 or String(ms[0].id) != String(ms[ms.size() - 1].id)):
				return {"key": i, "at": j}
	return {"key": -1, "at": -1}


## Element `el`'s jab (LMB): {id, mode} (Bending.jab, the caster's own; else its default quick spell).
static func jab(el: String) -> Dictionary:
	var p := Bending.jab(el)
	return p if not p.is_empty() else MatchSetup.quick_default(el)


## Element `el`'s guard (E): {id, mode} (Bending.guard, the caster's own).
static func guard(el: String) -> Dictionary:
	return Bending.guard(el)


## Whether key `i` grows when held past the second click (▲: its first move's spec carries "grow", as the caster reads it:
## key 2 for every element, fire's 1 too, the owner 2026-10-05: Punch held grows into the Fireball).
static func grows(el: String, i: int) -> bool:
	var ms := key_moves(el, i)
	if ms.is_empty():
		return false
	var spec: Variant = (SwayMoves.move(String(ms[0].id)).get("bend", {}) as Dictionary).get(String(ms[0].mode))
	return spec is Dictionary and (spec as Dictionary).has("grow")


## What key `i`'s first move grows into, when it has a name of its own ("Fireball"; "" none).
static func grown_name(el: String, i: int) -> String:
	var ms := key_moves(el, i)
	if ms.is_empty():
		return ""
	return String((words().get("grown", {}) as Dictionary).get("%s/%s" % [ms[0].id, ms[0].mode], ""))


## Key `i`'s role word ("STRIKE"), with ▲ when it grows.
static func role(el: String, i: int) -> String:
	if i < 0 or i >= ROLES.size():
		return ""
	var words_roles: Variant = words().get("roles")
	var r := String(words_roles[i]) if words_roles is Array and (words_roles as Array).size() > i else String(ROLES[i])
	return r + (" " + GROW if grows(el, i) else "")


# --- the keys as bound ---------------------------------------------------------------------------------------------

## The guard's action, made when missing (InputSetup.ensure_guard: E and the fourth mouse button). Safe to call again.
static func ensure_guard_action() -> void:
	InputSetup.ensure_guard()


## Action `a`'s first binding as the player sees it, "(no key)" when it has none; the mouse's buttons as words.
static func key(a: StringName) -> String:
	if a == GUARD_ACTION:
		ensure_guard_action()
	elif a == SwayCaster.QUICK_BIND:
		SwayCaster.ensure_input()            # (before any caster made it: the menus, F1 at the start)
	if InputMap.has_action(a):
		for e in InputMap.action_get_events(a):
			var mb := e as InputEventMouseButton
			if mb != null:
				match mb.button_index:
					MOUSE_BUTTON_LEFT:
						return "left click"
					MOUSE_BUTTON_RIGHT:
						return "right click"
	var k := SwayCaster.key_name(a)
	return k if k != "" else "(no key)"


## `t` with {guard}, {quick}, {aim}, {fire}, {wheel} and {jump} as bound now.
static func keyed(t: String) -> String:
	if not t.contains("{"):
		return t
	RadialWheel.ensure_input()
	return t.replace("{guard}", key(GUARD_ACTION)).replace("{quick}", key(SwayCaster.QUICK_BIND)).replace("{aim}", key(&"aim")) \
			.replace("{fire}", key(&"fire")).replace("{wheel}", key(RadialWheel.ACTION)).replace("{jump}", key(&"jump")) \
			.replace("{swap}", key(Hotbar.SWAP_ACTION))


# --- the lines -----------------------------------------------------------------------------------------------------

## "tap twice: Boulder" for key `i` (the other move's name; "" when it has one move, or under first_moves).
static func tap_twice(el: String, i: int, s := "") -> String:
	var ms := key_moves(el, i)
	if ms.size() < 2 or scheme_id(s) == "first_moves":
		return ""
	return w("tap_twice", "tap twice: %s") % move_name(String(ms[1].id), String(ms[1].mode))


## Element `el`'s passive: {name, line} (screens.json kit.passives).
static func passive(el: String) -> Dictionary:
	var p: Variant = (words().get("passives", {}) as Dictionary).get(el, {})
	return p if p is Dictionary else {}


## "Rooted: stand still and your locks fill faster, and you are pushed less." ("" none).
static func passive_line(el: String) -> String:
	var p := passive(el)
	return "%s: %s" % [p.get("name", ""), p.get("line", "")] if not p.is_empty() else ""


## What the element's guard does, in a line ("E catches stones; E again throws them back.").
static func guard_line(el: String) -> String:
	return keyed(String((words().get("guards", {}) as Dictionary).get(el, "")))


## The strip's one help line under the scheme now (or `s`).
static func help_line(s := "") -> String:
	var h: Dictionary = words().get("help", {})
	var k := scheme_id(s)
	return keyed(String(h.get(k, h.get("keys", ""))))


## The strip's one help line under scheme `s` (round 4, HUD: screens.json kit.help_strip; one line, 64 characters or fewer,
## its first letter a capital; round 2's longer help_line stays the duel's and F1's).
static func strip_help(s := "") -> String:
	var h: Dictionary = words().get("help_strip", {})
	var k := scheme_id(s)
	var t := keyed(String(h.get(k, h.get("keys", ""))))
	return t.substr(0, 1).to_upper() + t.substr(1) if t != "" else help_line(s)


## F1's and the first-time panels' four rules: the lock, the guard, the counters, the floor and the air.
static func rule_lines() -> Array:
	var r: Dictionary = words().get("rules", {})
	var out: Array = []
	for k in ["lock", "guard", "web", "dodge"]:
		if r.has(k):
			out.append(keyed(String(r[k])))
	return out


## An element's buttons as lines for the element pick and the Controls panels, under scheme `s`:
##   "LMB  JAB  Pebbles", "E  GUARD  Catch", "1  STRIKE  Spike  ·  tap twice: Boulder", ... "5  HEAL  Patch  ·  tap twice: Mend"
## (first_moves: no "tap twice"; direction: W, S and A D before the keys they stand for).
static func kit_lines(el: String, s := "", compact := false) -> Array:
	var k := scheme_id(s)
	var out: Array = []
	var j := jab(el)
	var g := guard(el)
	# (the jab is the left button's whatever the bindings: LMB; the guard's key as bound)
	var jl := "%s   %s   %s" % [JAB_KEY, w("role_jab", ROLE_JAB), move_name(String(j.get("id", "")), String(j.get("mode", "")))]
	var gl := "%s   %s   %s" % [key(GUARD_ACTION), w("role_guard", ROLE_GUARD), move_name(String(g.get("id", "")), String(g.get("mode", "")))]
	if compact:
		out.append(jl + "      " + gl)              # (the element pick: one line for both, the panel kept in view)
	else:
		out.append(jl)
		out.append(gl)
	var dir_heads := {0: "W / 1", 2: "A D / 3", 3: "S / 4"}
	for i in Bending.keys(el).size():
		var ms := key_moves(el, i)
		if ms.is_empty():
			continue
		var head := String(dir_heads.get(i, str(i + 1))) if k == "direction" else str(i + 1)
		var line := "%s   %s   %s" % [head, role(el, i), move_name(String(ms[0].id), String(ms[0].mode))]
		var gn := grown_name(el, i)
		if gn != "":
			line += "  ·  " + w("grow_into", "hold to grow it: %s") % gn
		var tt := tap_twice(el, i, k)
		if tt != "":
			line += "  ·  " + tt
		out.append(line)
	return out


## The element pick's head lines: the passive, then what the guard does.
static func pick_lines(el: String) -> Array:
	var out: Array = []
	for l in [passive_line(el), guard_line(el)]:
		if String(l) != "":
			out.append(String(l))
	return out


## The Controls panels' scheme row: "Other ways to pick moves:  Keys" (the scheme now), and its line.
static func other_ways_row() -> String:
	return w("other_ways_row", "Other ways to pick moves:  %s") % MatchSetup.scheme_label()


static func other_ways_line() -> String:
	return w("other_ways_line") if scheme_id() == "keys" else MatchSetup.scheme_row_line()


## Every word the player can read from this file's lines, for every element and scheme (tests/ring/test_player_words.gd).
static func every_line() -> Array:
	var out: Array = rule_lines()
	for s in ["keys", "first_moves", "direction", "radial"]:
		out.append(help_line(s))
		out.append(strip_help(s))
	for el: String in Bending.ELEMENTS:
		out.append_array(pick_lines(el))
		for s in ["keys", "first_moves", "direction", "radial"]:
			out.append_array(kit_lines(el, s))
	return out


# --- the player's own state ------------------------------------------------------------------------------------------

## Whether body `p` holds a stone it caught (earth's catch: E again throws it back). Its own only: never anyone else's.
static func holds_stone(p: Node) -> bool:
	if p == null or not is_instance_valid(p) or not p.is_inside_tree():
		return false
	return BendZone.held_stone(p) != null
