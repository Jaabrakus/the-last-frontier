class_name AdvancementStore
extends RefCounted
## The Character Advancement window's save (artifacts/ui_audit/advancement/plan.md section 5): user://advancement.json,
## three loadout slots per element, each remembering its class (style) and its picks, and which one is worn.
##   {"format": "tidebreak-advancement", "version": 1, "tree_version": 1,
##    "elements": {"earth": {"style": "hung_gar", "worn": 0,
##       "slots": [{"name": "Rally", "style": "hung_gar", "nodes": [...], "from": "earth.preset.rally",
##                  "saved_unix": 1760032000, "keep": false}, ...]}},
##    "world": {}}
## worn is -1 for Classic (no picks; the element's own "style" is its class then). On every read: unknown ids and ids of
## another element are dropped, held and world-only ids are dropped from the (ring) slots, and every slot is checked again
## (AdvancementLoadout.valid): one that breaks a rule is kept but marked "invalid": "<reason>" and read as Classic
## (worn_loadout) until it is saved again. "world" is kept for the open world's unlocks (Phase C).
## The window saves it; a match reads it only through BendLoadout (RingMode.restart, read only: docs/tidebreak/loadouts_live.md),
## which makes live the seven number picks and the Boxing class that data/bending/loadout_apply.json names. Every other pick is
## saved and shown but plays as Classic (the window's ribbon says so; AdvancementData.is_live names the live ones).
## A tool or test run (-s) reads and writes TEST_PATH while `path` is still PATH (the GameSettings rule); a test may point
## `path` at its own file.
##   slot(el, i) / slot_info(el, i) / slots(el)      a slot as a loadout (a copy) / its record / all three records
##   worn_index(el) / worn_loadout(el) / wear(el, i) which is worn (-1 Classic) / the loadout worn / wear one (-1: Classic)
##   save_slot(el, i, loadout, name, from)          checks the loadout (valid) and writes it; "" or the reason
##   rename / set_keep / keep / clear_slot          a slot's name, its padlock (kept from edits), emptied
##   style_of(el) / set_style(el, style)            the class worn now / the class worn with Classic
##   slot_name / slot_state / menu_line             "Loadout 2" or its name / worn|saved|empty|invalid / the menu's line

const PATH := "user://advancement.json"
## Where a tool or test run (-s) reads and writes while `path` is still PATH (never the player's own file).
const TEST_PATH := "user://advancement_test_runs.json"
const FORMAT := "tidebreak-advancement"
const VERSION := 1

## The file read and written: PATH (a test points it at a file of its own).
static var path := PATH
## What the last read dropped: ["earth/0: earth.slot.shell (held)", ...] (tests and the log).
static var dropped: Array = []
static var _doc := {}
static var _doc_file := ""


## The file read and written now: `path`, except PATH in a tool or test run (-s), which is TEST_PATH.
static func file() -> String:
	if path == PATH:
		var args := OS.get_cmdline_args()
		if "-s" in args or "--script" in args:
			return TEST_PATH
	return path


## Forget what was read (the next call reads the file again). Not named reload: called on the class, that name is
## the script's own Script.reload, which would reset `path`.
static func reload_file() -> void:
	_doc = {}
	_doc_file = ""


static func _data() -> Dictionary:
	if _doc.is_empty() or _doc_file != file():
		_load()
	return _doc


static func _load() -> void:
	var f := file()
	var d: Variant = null
	if FileAccess.file_exists(f):
		d = JSON.parse_string(FileAccess.get_file_as_string(f))
	var raw: Dictionary = d if d is Dictionary and String((d as Dictionary).get("format", "")) == FORMAT else {}
	dropped = []
	var out := {"format": FORMAT, "version": VERSION, "tree_version": AdvancementData.tree_version(), "elements": {},
			"world": raw.get("world", {}) if raw.get("world") is Dictionary else {}}
	var els: Dictionary = raw.get("elements", {}) if raw.get("elements") is Dictionary else {}
	for el: String in AdvancementData.ELEMENTS:
		out.elements[el] = _clean_element(el, els.get(el, {}) if els.get(el) is Dictionary else {})
	_doc = out
	_doc_file = f


static func _clean_element(el: String, e: Dictionary) -> Dictionary:
	var canon := AdvancementData.canon_style(el)
	var st := String(e.get("style", canon))
	if not AdvancementData.style_fits(el, st):
		st = canon
	var slots: Array = []
	var raw: Array = e.get("slots", []) if e.get("slots") is Array else []
	for i in AdvancementData.slot_count():
		slots.append(_clean_slot(el, i, raw[i] if i < raw.size() and raw[i] is Dictionary else {}, st))
	var worn := int(e.get("worn", -1))
	if worn < -1 or worn >= slots.size():
		worn = -1
	return {"style": st, "worn": worn, "slots": slots}


static func _clean_slot(el: String, i: int, s: Dictionary, el_style: String) -> Dictionary:
	var st := String(s.get("style", el_style))
	if not AdvancementData.style_fits(el, st):
		st = el_style
	var nodes: Array = []
	for v: Variant in (s.get("nodes", []) if s.get("nodes") is Array else []):
		var id := String(v)
		var n := AdvancementData.node(id)
		var why := ""
		if n.is_empty() or String(n.el) != el:
			why = "unknown"
		elif bool(n.held):
			why = "held"
		elif bool(n.world_only):
			why = "world only"
		elif id in nodes:
			why = "twice"
		if why != "":
			dropped.append("%s/%d: %s (%s)" % [el, i, id, why])
			continue
		nodes.append(id)
	var out := {"name": String(s.get("name", "")), "style": st, "nodes": nodes, "from": String(s.get("from", "")),
			"saved_unix": int(s.get("saved_unix", 0)), "keep": bool(s.get("keep", false))}
	var lo := AdvancementLoadout.new(el, st, nodes)
	var why_bad := lo.valid()
	if why_bad != "":
		out["invalid"] = why_bad
	return out


## Writes the file (true when written).
static func save() -> bool:
	var d := _data()
	d["tree_version"] = AdvancementData.tree_version()
	var fa := FileAccess.open(file(), FileAccess.WRITE)
	if fa == null:
		push_warning("AdvancementStore: cannot write %s" % file())
		return false
	fa.store_string(JSON.stringify(d, "\t"))
	fa.close()
	return true


## The element's record ({style, worn, slots}); do not change it (use the functions below).
static func element_doc(el: String) -> Dictionary:
	return (_data().elements as Dictionary).get(el, {})


static func _slot_rec(el: String, i: int) -> Dictionary:
	var ss: Array = element_doc(el).get("slots", [])
	return ss[i] if i >= 0 and i < ss.size() else {}


## Slot `i`'s record (a copy): {name, style, nodes, from, saved_unix, keep, invalid?}; {} when there is no such slot.
static func slot_info(el: String, i: int) -> Dictionary:
	return _slot_rec(el, i).duplicate(true)


static func slots(el: String) -> Array:
	var out: Array = []
	for i in AdvancementData.slot_count():
		out.append(slot_info(el, i))
	return out


## Slot `i` as a loadout to edit (a copy: its class and its picks as saved, even when marked invalid); Classic of the
## element's class for i = -1 or no such slot.
static func slot(el: String, i: int) -> AdvancementLoadout:
	var s := _slot_rec(el, i)
	if s.is_empty():
		return AdvancementLoadout.classic(el, String(element_doc(el).get("style", "")))
	return AdvancementLoadout.new(el, String(s.style), s.nodes)


## The slot worn (-1: Classic).
static func worn_index(el: String) -> int:
	return int(element_doc(el).get("worn", -1))


## The loadout worn: the worn slot's, or Classic (of the element's class) when Classic is worn or the slot is invalid.
static func worn_loadout(el: String) -> AdvancementLoadout:
	var i := worn_index(el)
	var s := _slot_rec(el, i)
	if i < 0 or s.is_empty() or s.has("invalid"):
		return AdvancementLoadout.classic(el, String(element_doc(el).get("style", "")))
	return AdvancementLoadout.new(el, String(s.style), s.nodes)


## Wears slot `i` (-1: Classic) and writes the file; false for no such slot.
static func wear(el: String, i: int) -> bool:
	if i < -1 or i >= AdvancementData.slot_count():
		return false
	var e := element_doc(el)
	e["worn"] = i
	return save()


## Saves `lo` into slot `i` when it keeps every rule (AdvancementLoadout.valid; the gates do not count): its class and
## picks, the time, `slot_name` (null keeps the slot's name) and `from` (the premade it came from, "" none). Returns "" or
## the reason it was not saved (a kept slot: its padlock is on).
static func save_slot(el: String, i: int, lo: AdvancementLoadout, slot_name: Variant = null, from := "") -> String:
	var s := _slot_rec(el, i)
	if s.is_empty() or lo == null or lo.element != el:
		return AdvancementData.word("reasons.unknown")
	if bool(s.get("keep", false)):
		return AdvancementData.word("slot_state.kept")
	var why := lo.valid()
	if why != "":
		return why
	s["style"] = lo.style
	s["nodes"] = lo.picks.duplicate()
	s["from"] = from
	s["saved_unix"] = int(Time.get_unix_time_from_system())
	if slot_name != null:
		s["name"] = String(slot_name).substr(0, int(AdvancementData.tree_cfg().get("name_max", 24)))
	s.erase("invalid")
	save()
	return ""


## Empties slot `i` (no picks, the element's class; a kept slot stays). Classic is worn when it was the worn one.
static func clear_slot(el: String, i: int) -> bool:
	var s := _slot_rec(el, i)
	if s.is_empty() or bool(s.get("keep", false)):
		return false
	s["nodes"] = []
	s["name"] = ""
	s["from"] = ""
	s["saved_unix"] = 0
	s.erase("invalid")
	if worn_index(el) == i:
		var e := element_doc(el)
		e["worn"] = -1
	return save()


static func rename(el: String, i: int, slot_name: String) -> bool:
	var s := _slot_rec(el, i)
	if s.is_empty():
		return false
	s["name"] = slot_name.strip_edges().substr(0, int(AdvancementData.tree_cfg().get("name_max", 24)))
	return save()


## The padlock: a kept slot is not changed by save_slot or clear_slot.
static func set_keep(el: String, i: int, on: bool) -> bool:
	var s := _slot_rec(el, i)
	if s.is_empty():
		return false
	s["keep"] = on
	return save()


static func keep(el: String, i: int) -> bool:
	return bool(_slot_rec(el, i).get("keep", false))


## The class worn now: the worn slot's style (a valid slot), else the element's own choice for Classic.
static func style_of(el: String) -> String:
	var i := worn_index(el)
	var s := _slot_rec(el, i)
	if i >= 0 and not s.is_empty() and not s.has("invalid"):
		return String(s.style)
	return String(element_doc(el).get("style", AdvancementData.canon_style(el)))


## The class worn with Classic (and given to empty slots); "" or the reason it was refused (not a pickable style of el).
static func set_style(el: String, style_id: String) -> String:
	if not AdvancementData.style_fits(el, style_id) or not AdvancementData.pickable(style_id):
		return AdvancementData.word("reasons.style")
	var e := element_doc(el)
	e["style"] = style_id
	save()
	return ""


## A slot's name on the screen: its own, else "Loadout 2".
static func slot_name(el: String, i: int) -> String:
	if i < 0:
		return AdvancementData.word("loadout.classic")
	var n := String(_slot_rec(el, i).get("name", ""))
	return n if n != "" else AdvancementData.word("loadout.slot") % (i + 1)


## "worn", "saved", "empty" or "invalid".
static func slot_state(el: String, i: int) -> String:
	var s := _slot_rec(el, i)
	if s.has("invalid"):
		return "invalid"
	if worn_index(el) == i:
		return "worn"
	return "saved" if not (s.get("nodes", []) as Array).is_empty() else "empty"


## The main menu's line for `el`: "Ember · Boxing · Loadout 1: Blaze, 10 of 10" (Classic: "Stone · Hung Gar · Classic").
static func menu_line(el: String) -> String:
	var st := AdvancementData.style(style_of(el))
	var i := worn_index(el)
	var lo := worn_loadout(el)
	var what := AdvancementData.word("loadout.classic")
	if i >= 0 and not _slot_rec(el, i).has("invalid"):
		what = AdvancementData.word("menu_loadout") % [i + 1, slot_name(el, i), lo.cost(), AdvancementData.budget()]
	return AdvancementData.word("menu_line") % [MatchSetup.competitor(el), String(st.get("label", "")), what]
