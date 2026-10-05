class_name KitWords
extends RefCounted
## What the player reads about his element's kit (Tidebreak, round 2 of the skills: the owner, 2026-10-05, "make the skills
## easy hard to master ... think human made think avg IQ"; skills_r2 spec §2, §6, §9): the same buttons for every element,
## one job each, said the same way on the strip (BendStrip), the move wheel (RadialWheel), F1 and the first-time panels
## (FrontierHUD, HowTo), the element pick and the Controls panels (MainMenu, RingMenu, DuelMenu) and the lessons
## (RingLessons). Every word from data/ring/screens.json "kit" (tests/ring/test_player_words.gd holds them to the owner's
## rule: no word from the show); the moves' plain names from moves.json's mode labels (Spike, Boulder, Shove ...).
##   the buttons   LMB JAB · E GUARD · 1 STRIKE · 2 PUSH ▲ · 3 DASH · 4 WALL · 5 HEAL (role(i), ROLE_JAB, ROLE_GUARD)
##   a key         Bending.keys(el)[i]: [id] (one move, or one move with two modes) or [id, id] (two moves): key_moves(el, i)
##                 -> its first move and, tapped twice, its second ({id, mode} each; spec §10's other_move)
##   the jab       moves.json "jabs" (else the element's first quick spell, MatchSetup.quick_default); the guard "guards"
##                 (else the four of spec §8.1); the passive's words screens.json kit.passives
##   lines         kit_lines(el, scheme): the element pick's and the Controls panel's; rule_lines(): F1's and the
##                 first-time panels' four rules; help_line(scheme): the strip's one help line
## The control schemes as the data names them: "first_moves" (round 2; "simple" before it) is read as one (scheme_id).

const ROLES := ["STRIKE", "PUSH", "DASH", "WALL", "HEAL"]
const ROLE_JAB := "JAB"
const ROLE_GUARD := "GUARD"
## The grow mark (▲: held past the second click the move grows; key 2 for every element, fire's 1 too).
const GROW := "▲"
const GUARD_ACTION := &"bend_guard"
## The guard's keys when the bindings have none yet (round 2's E and the fourth mouse button; CORE makes the action).
const GUARD_KEY := KEY_E
## Each element's guard and jab when moves.json has no "guards" / "jabs" block (spec §8.1).
const GUARDS := {"earth": ["stone_catch", "catch"], "water": ["water_redirect", "redirect"], "fire": ["fire_parry", "parry"],
		"air": ["air_shield", "shield"]}
const JABS := {"earth": ["rock_jab", "pebbles"], "water": ["water_jet", "splash"], "fire": ["fire_jab", "embers"],
		"air": ["air_palm", "palm"]}


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
static func key_moves(el: String, i: int) -> Array:
	var keys := Bending.keys(el)
	if i < 0 or i >= keys.size():
		return []
	var k: Array = keys[i]
	if k.size() >= 2:
		return [{"id": String(k[0]), "mode": _first_mode(String(k[0]))}, {"id": String(k[1]), "mode": _first_mode(String(k[1]))}]
	if k.is_empty():
		return []
	var id := String(k[0])
	var ms := SwayCaster.modes_of(id)
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


static func _pair(v: Variant) -> Dictionary:
	if v is Array and (v as Array).size() >= 1:
		return {"id": String(v[0]), "mode": String(v[1]) if (v as Array).size() > 1 else ""}
	if v is String and String(v) != "":
		return {"id": String(v).get_slice("/", 0), "mode": String(v).get_slice("/", 1) if String(v).contains("/") else ""}
	return {}


## Element `el`'s jab (LMB): {id, mode} (moves.json "jabs"; else its default quick spell; else JABS).
static func jab(el: String) -> Dictionary:
	var d: Variant = (SwayMoves.data().get("jabs", {}) as Dictionary).get(el)
	var p := _pair(d)
	if p.is_empty():
		p = MatchSetup.quick_default(el)
	if p.is_empty():
		p = _pair(JABS.get(el))
	return p


## Element `el`'s guard (E): {id, mode} (moves.json "guards"; else GUARDS).
static func guard(el: String) -> Dictionary:
	var p := _pair((SwayMoves.data().get("guards", {}) as Dictionary).get(el))
	return p if not p.is_empty() else _pair(GUARDS.get(el))


## Whether key `i` grows when held past the second click (▲: key 2 for every element; fire's 1 too, the owner 2026-10-05:
## Punch held grows into the Fireball; or a first move whose spec carries "grow").
static func grows(el: String, i: int) -> bool:
	if i == 1 or (el == "fire" and i == 0):
		return true
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

## The guard's action, made when missing (E; round 2's CORE makes it with the fourth mouse button too). Safe to call again.
static func ensure_guard_action() -> void:
	if InputMap.has_action(GUARD_ACTION):
		return
	InputMap.add_action(GUARD_ACTION)
	var k := InputEventKey.new()
	k.physical_keycode = GUARD_KEY
	InputMap.action_add_event(GUARD_ACTION, k)


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
			.replace("{fire}", key(&"fire")).replace("{wheel}", key(RadialWheel.ACTION)).replace("{jump}", key(&"jump"))


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
static func kit_lines(el: String, s := "") -> Array:
	var k := scheme_id(s)
	var out: Array = []
	var j := jab(el)
	out.append("%s   %s   %s" % [key(&"fire"), w("role_jab", ROLE_JAB), move_name(String(j.get("id", "")), String(j.get("mode", "")))])
	var g := guard(el)
	out.append("%s   %s   %s" % [key(GUARD_ACTION), w("role_guard", ROLE_GUARD), move_name(String(g.get("id", "")), String(g.get("mode", "")))])
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
	var c := SwayCaster.of(p)
	if c != null and c.has_method(&"held_stone"):
		return c.call(&"held_stone") != null
	var me := p.get_instance_id()
	for s in p.get_tree().get_nodes_in_group(FormStone.GROUP):
		if int((s as Node).get_meta(&"bend_held_by", -1)) == me:
			return true
	return false
