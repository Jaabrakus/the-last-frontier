class_name AdvancementData
extends RefCounted
## The Character Advancement window's data (artifacts/ui_audit/advancement/plan.md section 3), read once and kept:
##   data/sway/skill_tree.json         the nodes (133), the ring budget, costs and limits, the starter loadouts, kind_labels
##   data/sway/moves.json              (SwayMoves) the keys' moves in order, the modes and their labels, jabs, guards, passives
##   data/bending/fighting_styles.json the styles: a class is element + style (each element's 4 and Jeet Kune Do = 20)
##   data/ui/advancement.json          every word the window shows, the tree split, layout constants, colours, switches
## Every node comes out as one flat Dictionary (node(id)) holding only what the window shows or the rules read; the draft's
## effect references (visual.fx) never leave this file. Player text is the tree's, with advancement.json text_overrides
## over it.
##
## Phase A (the owner, 2026-10-09): display and save only; nothing here changes a number in play.
##   nodes(el) / node(id) / node_ids(el)     an element's nodes in tree order / one node ({} unknown) / their ids
##   tree_nodes(el, side, mode)              the nodes one tree shows ("left" | "right"; mode "ring" | "world")
##   visible(n, mode)                        a node is shown in that mode (ring: world-only and ring-illegal number swaps
##                                           hidden, held ones shown dashed when switches.show_held)
##   starters(el) / starter(id)              the premade builds ({id, name, line, nodes})
##   styles(el) / style(id) / style_ids(el)  the 5 classes' styles of an element (its 4 in roster order, then "any")
##   canon_style(el) / pickable(id)          the element's own style / a style a player may pick (canon or animated)
##   rail(style, el) / levers(style)         a style's traits with their icons' moves / its lever lines
##   title(el, side, style)                  "BOXING" (left: the style) / "MAGMA" (right: the element's skill set)
##   kind_word(kind) / chip_word(chip)       "Twist" / "Strike"
##   move_label(move, mode)                  "Boulder" (a mode's label, else the move's)
##   gate_state(el)                          {won, full_left, first_win, full_lessons}: the newcomer gates now
##   search(el, text, mode)                  ids whose name, effect, help, move or kind word holds `text`
##   word(path) / words(path)                a word ("buttons.save") / a block of words from advancement.json
##   layout() / zone(side) / window_rect(n)  layout constants / a tree's zone / a window part, in authored pixels
##   color(name) / switch(path, def)         a colour / a switch
##   budget() / cost(id) / limits()          the ring's 10 points / a node's cost / the ring limits
##   is_live(id) / is_live_style(style)      the pick / the class a worn loadout makes play in a real match (read only from
##                                           data/bending/loadout_apply.json, the live-loadout work's own switches)
##   player_text(text)                       a node's text as a player may read it (degrees as the sign; a sentence about
##                                           an engine id, a dormant move or a held question dropped)
##   first_sentence(text, max)               the text's first sentence, cut at a word under `max` characters
##   sentences_up_to(text, max)              the first sentences that stay under `max` characters

const APPLY_PATH := "res://data/bending/loadout_apply.json"
const TREE_PATH := "res://data/sway/skill_tree.json"
const UI_PATH := "res://data/ui/advancement.json"
const STYLES_PATH := "res://data/bending/fighting_styles.json"
const ELEMENTS := ["earth", "water", "fire", "air"]
const SIDES := ["left", "right"]
## The node fields a player reads (advancement.json text_overrides may replace any of them).
const PLAYER_FIELDS := ["name", "effect", "plus", "minus", "help", "answer"]
## The ring limits that cap a kind per loadout (skill_tree.json ring.limits keys).
const KIND_CAPS := {"skill_set": "skill_sets", "new_skill": "new_skills", "passive": "passives", "mastery": "masteries"}
## Kinds that never count toward a move-mode's points or its one twist (ring.limits.points_per_move_mode_counts).
const NOT_ON_MODE := ["passive", "skill_set", "synergy"]
## The six levers in the order the window lists them.
const LEVERS := ["speed", "power", "reach", "width", "mobility", "defence"]
## A loadout code's element letters (AdvancementLoadout.code).
const LETTERS := {"earth": "e", "water": "w", "fire": "f", "air": "a"}

static var _tree := {}
static var _ui := {}
static var _styles := {}
static var _nodes := {}          ## id -> the flat node
static var _ids := {}            ## element -> its node ids in tree order
static var _starters := {}       ## element -> its premade builds
static var _apply := {}          ## data/bending/loadout_apply.json (what a worn loadout makes live)
static var _rx := {}             ## compiled expressions of player_text
## Tests: a gate state used in place of gate_state()'s reading ({} reads the game).
static var gates_override := {}


## Every file read again on the next call (a test's change to the data, a hand-tuned file). Not named reload: on the
## class that name is Script.reload, which re-makes the script and drops gates_override.
static func reload_data() -> void:
	_tree = {}
	_ui = {}
	_styles = {}
	_nodes = {}
	_ids = {}
	_starters = {}
	_apply = {}


static func _read(path: String) -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return d if d is Dictionary else {}


static func tree() -> Dictionary:
	if _tree.is_empty():
		_tree = _read(TREE_PATH)
	return _tree


static func ui() -> Dictionary:
	if _ui.is_empty():
		_ui = _read(UI_PATH)
	return _ui


static func styles_data() -> Dictionary:
	if _styles.is_empty():
		_styles = _read(STYLES_PATH)
	return _styles


static func moves() -> Dictionary:
	return SwayMoves.data()


## The tree's own version (skill_tree.json "version"): a change re-validates every saved slot.
static func tree_version() -> int:
	return int(tree().get("version", 1))


# --- words, layout, colours, switches ------------------------------------------------------------------------------------

## The value at a dotted path under `root` (null when any step is missing).
static func _at(root: Variant, path: String) -> Variant:
	var v: Variant = root
	for k in path.split(".", false):
		if not v is Dictionary or not (v as Dictionary).has(k):
			return null
		v = (v as Dictionary)[k]
	return v


## A word of the window: advancement.json words.<path> ("buttons.save", "reasons.budget"); `def` (else the path) when absent.
static func word(path: String, def := "") -> String:
	var v: Variant = _at(ui().get("words", {}), path)
	if v is String:
		return v
	return def if def != "" else path


## A block of words (words.<path>, a Dictionary; {} when absent).
static func words(path: String) -> Dictionary:
	var v: Variant = _at(ui().get("words", {}), path)
	return v if v is Dictionary else {}


static func layout() -> Dictionary:
	var v: Variant = ui().get("layout", {})
	return v if v is Dictionary else {}


static func layout_num(key: String, def: float) -> float:
	return float(layout().get(key, def))


static func _rect(a: Variant) -> Rect2:
	if a is Array and (a as Array).size() >= 4:
		return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
	return Rect2()


## A tree's zone in authored pixels (1600x900): "left" or "right".
static func zone(side: String) -> Rect2:
	return _rect((layout().get("zones", {}) as Dictionary).get(side, []))


## A window part in authored pixels ([x, y, w, h]; a point [x, y] comes back as a zero-size Rect2 at it).
static func window_rect(part: String) -> Rect2:
	var a: Variant = (layout().get("window", {}) as Dictionary).get(part, [])
	if a is Array and (a as Array).size() == 2:
		return Rect2(float(a[0]), float(a[1]), 0.0, 0.0)
	if a is Array and (a as Array).size() == 3:
		return Rect2(float(a[0]) - float(a[2]), float(a[1]) - float(a[2]), 2.0 * float(a[2]), 2.0 * float(a[2]))
	return _rect(a)


## A colour from advancement.json colors (white when absent).
static func color(name: String) -> Color:
	var v: Variant = (ui().get("colors", {}) as Dictionary).get(name, "")
	return Color.html(String(v)) if v is String and Color.html_is_valid(String(v)) else Color.WHITE


## The element's own colour (MatchSetup.color, data/ring/elements.json).
static func element_color(el: String) -> Color:
	return MatchSetup.color(el)


## A switch: advancement.json switches.<path> ("show_held", "gates.first_win"); `def` when absent.
static func switch(path: String, def: Variant = null) -> Variant:
	var v: Variant = _at(ui().get("switches", {}), path)
	return def if v == null else v


static func tree_cfg() -> Dictionary:
	var v: Variant = ui().get("tree", {})
	return v if v is Dictionary else {}


static func left_chips() -> Array:
	return tree_cfg().get("left_chips", ["LMB", "E", "1", "2"])


static func chip_order() -> Array:
	return tree_cfg().get("chip_order", ["LMB", "E", "1", "2", "3", "4", "5", "passive", "set"])


static func slot_count() -> int:
	return int(tree_cfg().get("slots", 3))


# --- the ring's rules ------------------------------------------------------------------------------------------------------

static func ring() -> Dictionary:
	var v: Variant = tree().get("ring", {})
	return v if v is Dictionary else {}


## The ring's points for a loadout (10).
static func budget() -> int:
	return int(ring().get("budget", 10))


static func limits() -> Dictionary:
	var v: Variant = ring().get("limits", {})
	return v if v is Dictionary else {}


## A limit as a number (limits() has words in some keys; `def` for those).
static func limit(key: String, def: int) -> int:
	var v: Variant = limits().get(key, def)
	return int(v) if v is float or v is int else def


## A node's cost in points (its ring_cost, else ring.costs by kind); 0 for an unknown id.
static func cost(id: String) -> int:
	var n := node(id)
	return int(n.get("cost", 0)) if not n.is_empty() else 0


# --- the nodes ---------------------------------------------------------------------------------------------------------

static func _build() -> void:
	if not _nodes.is_empty():
		return
	var els: Dictionary = tree().get("elements", {})
	var over: Dictionary = (ui().get("text_overrides", {}) as Dictionary).get("nodes", {})
	var costs: Dictionary = ring().get("costs", {})
	for el: String in ELEMENTS:
		var ids: Array = []
		var e: Dictionary = els.get(el, {})
		for b: Dictionary in e.get("branches", []):
			for raw: Dictionary in b.get("nodes", []):
				var n := _flat(el, b, raw, ids.size(), costs, over.get(raw.get("id", ""), {}))
				_nodes[n.id] = n
				ids.append(n.id)
		_ids[el] = ids
		var st: Array = []
		var sover: Dictionary = (ui().get("text_overrides", {}) as Dictionary).get("starters", {})
		for s: Dictionary in e.get("starter_loadouts", []):
			var o: Dictionary = sover.get(s.get("id", ""), {})
			st.append({"id": String(s.get("id", "")), "name": String(o.get("name", s.get("name", ""))),
					"line": String(o.get("line", s.get("line", ""))), "nodes": (s.get("nodes", []) as Array).duplicate()})
		_starters[el] = st


static func _flat(el: String, b: Dictionary, raw: Dictionary, order: int, costs: Dictionary, over: Dictionary) -> Dictionary:
	var kind := String(raw.get("kind", ""))
	var move := String(raw.get("extends_move", ""))
	var md := String(raw.get("mode", ""))
	var held: Variant = raw.get("held")
	var n := {
		"id": String(raw.get("id", "")), "el": el, "kind": kind, "order": order,
		"chip": String(raw.get("chip", "passive")), "move": move, "mode": md,
		"cost": int(raw.get("ring_cost", costs.get(kind, 1))),
		"legal": bool(raw.get("ring_legal", true)),
		"held": held is Dictionary, "held_question": _num_text((held as Dictionary).get("question", "")) if held is Dictionary else "",
		"held_why": String((held as Dictionary).get("why", "")) if held is Dictionary else "",
		"requires": (raw.get("requires", []) as Array).duplicate() if raw.get("requires") is Array else [],
		"excludes": (raw.get("excludes", []) as Array).duplicate() if raw.get("excludes") is Array else [],
		"set": String(raw.get("set", "")) if raw.get("set") is String else "",
		"slot": (raw.get("slot") as Dictionary).duplicate() if raw.get("slot") is Dictionary else {},
		"extends_passive": String(raw.get("extends_passive", "")) if raw.get("extends_passive") is String else "",
		"ring_note": String(raw.get("ring_note", "")) if raw.get("ring_note") is String else "",
		"world_gate": (raw.get("world_gate", []) as Array).duplicate() if raw.get("world_gate") is Array else [],
		"look": String((raw.visual as Dictionary).get("look", "")) if raw.get("visual") is Dictionary else "",
		"branch": String(b.get("id", "")),
	}
	for f: String in PLAYER_FIELDS:
		var v: Variant = over.get(f, raw.get(f, ""))
		n[f] = player_text(String(v)) if v is String else ""
	n["kind_word"] = kind_word(kind)
	n["world_only"] = kind == "world_only" or not bool(n.legal)
	n["on_mode"] = move != "" and md != "" and not kind in NOT_ON_MODE
	n["move_mode"] = move + "/" + md
	n["slot_chip"] = "set" if kind == "skill_set" else ("passive" if kind == "passive" else String(n.chip))
	n["side"] = "left" if String(n.slot_chip) in left_chips() else "right"
	n["tap_twice"] = _tap_twice(el, n)
	n["move_label"] = move_label(move, md)
	return n


## A JSON number as text without a trailing ".0" (4.0 -> "4"); anything else as str().
static func _num_text(v: Variant) -> String:
	if v is float and float(v) == floorf(float(v)):
		return str(int(v))
	return str(v)


## The moves on chip `chip` for `el`, in key order (the first move, then the tap twice).
static func key_moves(el: String, chip: String) -> Array:
	var m := moves()
	if chip in ["1", "2", "3", "4", "5"]:
		var keys: Variant = (m.get("elements", {}) as Dictionary).get(el, [])
		var i := int(chip) - 1
		if keys is Array and i >= 0 and i < (keys as Array).size():
			var k: Variant = keys[i]
			return (k as Array).duplicate() if k is Array else [k]
		return []
	if chip == "LMB" or chip == "E":
		var p: Variant = (m.get("jabs" if chip == "LMB" else "guards", {}) as Dictionary).get(el)
		return [p[0]] if p is Array and not (p as Array).is_empty() else []
	return []


## Whether node `n` sits on a key's second move (the tap twice): a new skill, a node on a key's second move, or on a
## one-move key's second mode. First moves only and Direction reach none of these (ring.control_schemes).
static func _tap_twice(el: String, n: Dictionary) -> bool:
	var kind := String(n.kind)
	if kind == "new_skill":
		return true
	if kind in ["passive", "skill_set"]:
		return false
	var km := key_moves(el, String(n.chip))
	var move := String(n.move)
	if km.size() >= 2 and move == String(km[1]):
		return true
	if km.size() == 1 and move == String(km[0]) and String(n.mode) != "":
		var ms: Array = SwayMoves.move(move).get("modes", [])
		return ms.find(String(n.mode)) >= 1
	return false


## An element's nodes in tree order (flat Dictionaries; do not change them).
static func nodes(el: String) -> Array:
	_build()
	var out: Array = []
	for id: String in _ids.get(el, []):
		out.append(_nodes[id])
	return out


static func node_ids(el: String) -> Array:
	_build()
	return (_ids.get(el, []) as Array).duplicate()


## One node ({} for an unknown id).
static func node(id: String) -> Dictionary:
	_build()
	return _nodes.get(id, {})


static func has_node(id: String) -> bool:
	_build()
	return _nodes.has(id)


## A node's name on the screen (the id itself for an unknown one).
static func name_of(id: String) -> String:
	var n := node(id)
	return String(n.get("name", id)) if not n.is_empty() else id


## Whether node `n` (a node or its id) is shown in `mode`: ring mode hides world-only nodes and, when
## switches.hide_world_only_in_ring, the ring-illegal number swaps; held nodes show when switches.show_held (the plan's choice,
## the owner's review list: a held node is drawn dashed with a '?', never wearable, "Not ready yet", whether or not it is also
## ring-illegal; switch it off and they all go).
static func visible(n: Variant, mode := "ring") -> bool:
	var d: Dictionary = node(String(n)) if n is String else n
	if d.is_empty():
		return false
	if String(d.kind) == "world_only":
		return mode == "world"
	if bool(d.held):
		return bool(switch("show_held", true))
	if mode == "ring" and not bool(d.legal):
		return not bool(switch("hide_world_only_in_ring", true))
	return true


## The nodes one tree shows: `side` "left" (LMB, E, 1, 2: the moves a style shapes) or "right" (3, 4, 5, the passive, the
## skill set), in tree order.
static func tree_nodes(el: String, side: String, mode := "ring") -> Array:
	var out: Array = []
	for n: Dictionary in nodes(el):
		if String(n.side) == side and visible(n, mode):
			out.append(n)
	return out


## The premade builds of `el`: [{id, name, line, nodes}] (skill_tree.json starter_loadouts, text overrides applied).
static func starters(el: String) -> Array:
	_build()
	return (_starters.get(el, []) as Array).duplicate(true)


static func starter(id: String) -> Dictionary:
	_build()
	for el: String in _starters:
		for s: Dictionary in _starters[el]:
			if String(s.id) == id:
				return s.duplicate(true)
	return {}


## An element's skill set id ("sulphur"), its name ("Sulphur") and its root node ("earth.set.sulphur").
static func set_of(el: String) -> String:
	return String((tree().get("elements", {}) as Dictionary).get(el, {}).get("skill_set", ""))


static func set_label(el: String) -> String:
	var s: Variant = (tree().get("skill_sets", {}) as Dictionary).get(set_of(el), {})
	return String((s as Dictionary).get("name", set_of(el).capitalize())) if s is Dictionary else set_of(el).capitalize()


static func set_root(el: String) -> String:
	var s: Variant = (tree().get("skill_sets", {}) as Dictionary).get(set_of(el), {})
	return String((s as Dictionary).get("entry", "")) if s is Dictionary else ""


## The element's passive: {id, label, line} (moves.json passives).
static func passive_of(el: String) -> Dictionary:
	var p: Variant = (moves().get("passives", {}) as Dictionary).get(el, {})
	if not p is Dictionary:
		return {}
	return {"id": String((p as Dictionary).get("id", "")), "label": String((p as Dictionary).get("label", "")),
			"line": String((p as Dictionary).get("line", ""))}


## The player's word for a kind ("Twist"): advancement.json words.kinds, else skill_tree.json kind_labels.
static func kind_word(kind: String) -> String:
	var w := words("kinds")
	if w.has(kind):
		return String(w[kind])
	var k: Variant = (tree().get("kind_labels", {}) as Dictionary).get(kind, "")
	return String(k) if k is String and String(k) != "" else kind.capitalize()


## A chip's word ("Strike" for "1") and its badge ("1").
static func chip_word(chip: String) -> String:
	return String(words("keys").get(chip, chip))


static func key_badge(chip: String) -> String:
	return String(words("key_badges").get(chip, chip))


## A move's name on the screen: its mode's label ("Boulder"), else the move's label ("Mend"); "" for no move.
static func move_label(move: String, mode := "") -> String:
	if move == "":
		return ""
	var m := SwayMoves.move(move)
	var n := ""
	if mode != "":
		var ml: Variant = m.get("mode_labels", {})
		if ml is Dictionary and (ml as Dictionary).has(mode):
			n = String(ml[mode])
	if n == "":
		n = String(m.get("label", move.capitalize()))
	return n.substr(0, 1).to_upper() + n.substr(1)


# --- what a player may read, and what is live ---------------------------------------------------------------------------------

static func _regex(key: String, pattern: String) -> RegEx:
	if not _rx.has(key):
		_rx[key] = RegEx.create_from_string(pattern)
	return _rx[key]


## A node's text as a player may read it. The draft's text (data/sway/skill_tree.json, which other work owns) carries design
## notes and engine names: "10 deg" reads "10\u00b0", and a sentence that names an engine id (earth_shove), a dormant move, a
## held question or a date is dropped, so "Draws on the dormant earth_shove split." never reaches the screen. advancement.json
## text_overrides say it plainly for the nodes that need it; this is the net under them (tests/ring/test_player_words.gd).
static func player_text(text: String) -> String:
	if text == "":
		return text
	var t := _regex("deg", "(\\d) ?deg(?![A-Za-z])").sub(text, "$1\u00b0", true)
	var bad := _regex("bad", "(?i)\\bdormant\\b|\\b[a-z]+_[a-z_]+\\b|\\bheld for\\b|yours to rule|bring (it|them) back|\\bquestion \\d|\\bround \\d|\\d{4}-\\d{2}-\\d{2}")
	if bad.search(t) == null:
		return t
	var keep: Array = []
	for sentence: String in _sentences(t):
		if bad.search(sentence) == null:
			keep.append(sentence)
	if keep.is_empty():
		return t.replace("_", " ")
	return " ".join(PackedStringArray(keep))


## The sentences of `text` ("0.8 s (from 1.0) is late." stays one: a stop splits only before a capital after a space).
static func _sentences(text: String) -> Array:
	var out: Array = []
	var from := 0
	for m in _regex("split", "(?<=[.!?)])\\s+(?=[A-Z])").search_all(text):
		out.append(text.substr(from, m.get_start() - from))
		from = m.get_end()
	out.append(text.substr(from))
	return out


## The first sentence of `text`; one longer than `max_chars` is cut at the last word that fits, with "...".
static func first_sentence(text: String, max_chars := 110) -> String:
	var ss := _sentences(text.strip_edges())
	var first: String = String(ss[0]) if not ss.is_empty() else ""
	if first.length() <= max_chars:
		return first
	var cut := first.substr(0, max_chars)
	var sp := cut.rfind(" ")
	if sp > max_chars / 2:
		cut = cut.substr(0, sp)
	return cut.rstrip(" ,;:") + "..."


## The first sentences of `text` that together stay under `max_chars` (the first alone when it is longer): the full tip of a
## node whose draft text runs to a paragraph (a skill set's) still fits the painting.
static func sentences_up_to(text: String, max_chars := 560) -> String:
	var out := ""
	for sentence: String in _sentences(text.strip_edges()):
		var next := sentence if out == "" else out + " " + sentence
		if out != "" and next.length() > max_chars:
			break
		out = next
	return out


## The switches of the live loadouts (data/bending/loadout_apply.json), read only.
static func apply_cfg() -> Dictionary:
	if _apply.is_empty():
		_apply = _read(APPLY_PATH)
		if _apply.is_empty():
			_apply = {"enabled": false}
	return _apply


## Whether wearing node `id` changes a real match now: the live-loadout work's master switch on, the id in its `live` list and
## its own switch not off.
static func is_live(id: String) -> bool:
	var c := apply_cfg()
	if not bool(c.get("enabled", false)):
		return false
	if not id in (c.get("live", []) as Array):
		return false
	var nodes: Variant = c.get("nodes", {})
	return bool((nodes as Dictionary).get(id, true)) if nodes is Dictionary else true


## Whether a worn loadout plays this class's clips in a match (Boxing today: animation only).
static func is_live_style(style_id: String) -> bool:
	var c := apply_cfg()
	return bool(c.get("enabled", false)) and style_id in (c.get("styles_live", []) as Array)


# --- the styles (classes) ----------------------------------------------------------------------------------------------------

## A style's flat Dictionary: {id, element, label, canon, state, known, levers, rail, library, poses, pickable}; {} unknown.
static func style(id: String) -> Dictionary:
	var s: Variant = (styles_data().get("styles", {}) as Dictionary).get(id)
	if not s is Dictionary:
		return {}
	var d := (s as Dictionary).duplicate(true)
	d["id"] = id
	d["pickable"] = String(d.get("state", "coming")) in (switch("pickable_states", ["canon", "animated"]) as Array)
	return d


## The ids of the styles an element's classes use: its own four (canon first), then the any-element ones.
static func style_ids(el: String) -> Array:
	var order: Dictionary = styles_data().get("order", {})
	var out: Array = (order.get(el, []) as Array).duplicate()
	out.append_array(order.get("any", []))
	return out


static func styles(el: String) -> Array:
	var out: Array = []
	for id: String in style_ids(el):
		var s := style(id)
		if not s.is_empty():
			out.append(s)
	return out


## The element's own style (its canon one: today's clips).
static func canon_style(el: String) -> String:
	for id: String in style_ids(el):
		if bool(style(id).get("canon", false)) and String(style(id).get("element", "")) == el:
			return id
	var ids := style_ids(el)
	return String(ids[0]) if not ids.is_empty() else ""


## Whether `id` is one of `el`'s classes' styles.
static func style_fits(el: String, id: String) -> bool:
	return id in style_ids(el)


static func pickable(id: String) -> bool:
	return bool(style(id).get("pickable", false))


## A style's state word ("Ready to play", "Coming").
static func style_state_word(id: String) -> String:
	return word("class.states." + String(style(id).get("state", "coming")))


## A style's rail for element `el`: [{id, label, line, perfect, chip, move, mode, move_label}] (a trait with no move of
## its own takes the element's: the jab on LMB, the guard on E).
static func rail(style_id: String, el: String) -> Array:
	var s := style(style_id)
	var out: Array = []
	for r: Dictionary in s.get("rail", []):
		var e := r.duplicate()
		var chip := String(e.get("chip", ""))
		var move := String(e.get("move", ""))
		var md := String(e.get("mode", ""))
		if move == "" and (chip == "LMB" or chip == "E"):
			var p: Variant = (moves().get("jabs" if chip == "LMB" else "guards", {}) as Dictionary).get(el)
			if p is Array and (p as Array).size() >= 2:
				move = String(p[0])
				md = String(p[1])
		e["move"] = move
		e["mode"] = md
		e["move_label"] = move_label(move, md)
		var id := String(e.get("id", ""))
		var lab := word("rail." + id, id.capitalize())
		e["label"] = lab % String(s.get("label", "")) if id == "stance" else lab
		e["line"] = String(e.get("line", ""))
		e["perfect"] = String(e.get("perfect", ""))
		out.append(e)
	return out


## A style's lever lines, its strengths first: [{lever, sign (+1/-1), label, text, line}] ("Speed+: quick casts ...").
static func levers(style_id: String) -> Array:
	var lv: Dictionary = style(style_id).get("levers", {})
	var out: Array = []
	for sg: int in [1, -1]:
		for k: String in LEVERS:
			if int(lv.get(k, 0)) != sg:
				continue
			var w := words("levers." + k)
			var text := String(w.get("up" if sg > 0 else "down", ""))
			var lab := String(w.get("label", k.capitalize()))
			out.append({"lever": k, "sign": sg, "label": lab, "text": text,
					"line": word("levers.line_up" if sg > 0 else "levers.line_down") % [lab, text]})
	return out


## A tree's title: the left one the style's name, the right one the element's skill set (advancement.json tree.titles),
## in upper case when tree.title_case is "upper".
static func title(el: String, side: String, style_id := "") -> String:
	var rule := String((tree_cfg().get("titles", {}) as Dictionary).get(side, "style" if side == "left" else "set"))
	var t := ""
	if rule == "style":
		var sid := style_id if style_id != "" else canon_style(el)
		t = String(style(sid).get("label", sid))
	else:
		t = set_label(el)
	return t.to_upper() if String(tree_cfg().get("title_case", "upper")) == "upper" else t


# --- the gates ---------------------------------------------------------------------------------------------------------

## The newcomer gates now for `el` (skill_tree.json ring.defaults; switches.gates):
##   won           the player has won a ring match (RingAssist.won_once)
##   full_left     Full lessons not yet done under the keys scheme (RingLessons: every lesson that is not a Basics one,
##                 for this element and the rules played now; a skipped one counts as done when gates.skipped_counts)
##   first_win     the first-win gate is on (everything locked until won)
##   full_lessons  the lessons gate is on (switches.full_lessons_kinds locked while full_left > 0)
## The user arg adv_gates=off (switches.dev_gates_arg) or the switches turn a gate off; gates_override replaces it all.
static func gate_state(el: String) -> Dictionary:
	if not gates_override.is_empty():
		return gates_override.duplicate()
	var off := String(switch("dev_gates_arg", "adv_gates=off")) in OS.get_cmdline_user_args()
	var fw := bool(switch("gates.first_win", true)) and not off
	var fl := bool(switch("gates.full_lessons", true)) and not off
	return {"won": RingAssist.won_once(), "full_left": full_lessons_left(el) if fl else 0, "first_win": fw, "full_lessons": fl}


## The Full lessons `el` has not done yet (see gate_state).
static func full_lessons_left(el: String) -> int:
	var skipped_ok := bool(switch("gates.skipped_counts", true))
	var rs := RingLessons.rules_now()
	var left := 0
	for l: Dictionary in RingLessons.data().get("lessons", []):
		if String(l.get("track", "")) == "basics":
			continue
		if l.has("schemes") and not "keys" in (l.schemes as Array):
			continue
		if l.has("rules") and not rs in (l.rules as Array):
			continue
		if l.has("elements") and not el in (l.elements as Array):
			continue
		var st := RingLessons.state_of("keys", el, l)
		if st == "done" or (st == "skipped" and skipped_ok):
			continue
		left += 1
	return left


## The control scheme now, as AdvancementLoadout.scheme takes it ("keys", "first_moves", "direction", "radial").
static func scheme_now() -> String:
	return KitWords.scheme_id()


# --- search --------------------------------------------------------------------------------------------------------------

## The ids of `el`'s nodes shown in `mode` whose name, effect, help, move label or kind word holds `text` (any case); every
## shown id for an empty text.
static func search(el: String, text: String, mode := "ring") -> Array:
	var q := text.strip_edges().to_lower()
	var out: Array = []
	for n: Dictionary in nodes(el):
		if not visible(n, mode):
			continue
		if q == "":
			out.append(n.id)
			continue
		for f: String in ["name", "effect", "help", "move_label", "kind_word", "plus", "minus"]:
			if String(n.get(f, "")).to_lower().contains(q):
				out.append(n.id)
				break
	return out
