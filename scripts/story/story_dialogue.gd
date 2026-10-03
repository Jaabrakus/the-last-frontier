class_name StoryDialogue
extends CanvasLayer
## The game's talk, all of it text (user 2026-10-01: "all text"; docs/research/codebase_story_audit.md item 3): a box at
## the foot of the screen with who speaks and what they say. The line types itself out quickly; any key or a click shows
## it whole, the next one goes on. At a turn there are 2 to 4 answers to pick (1-4, the arrows or W/S and Enter, or the
## mouse). An answer can need something (a story flag, standing with a faction, a thing in the pack) and is not shown
## without it, and can do something (set a flag, change standing, give or take a thing, start a mission). The talk ends
## with an outcome, a word handed back to whoever opened it ("warned", "left").
##   StoryDialogue.open(tree, "two_fires/rumours", func(outcome: String) -> void: ...)
##   StoryDialogue.bark(person, "Halloo the house!")       # a line over someone in the world (StoryBark): no box, no pause
##   StoryDialogue.is_open(tree)
## Conversations are data: data/story/dialogue/<storyline>.json, its "conversations" (the format is written out in the
## file's "_format"; read from under StoryDirector.dir first, so a test's own story has its own talk). A convo_id is
## "<storyline>/<conversation>", or the conversation's name alone (looked for in the storyline at hand first, then in
## every file). One talk plays at a time; another opened meanwhile waits its turn.
##
## Alone, the game waits under it (paused), as under the story cards. In a shared world (NetSession at /root/Net in a
## session) nothing stops: the player only stands still (its controls let go, its E interactor stopped, so a key
## pressed in the talk does nothing in the world) while the box is up. The mouse is free while it is open and given
## back after as it was (caught in play, free in the command view). Esc opens the pause menu over the talk (save,
## settings, quit); shut, the talk is there again. The key or click that ends the talk does nothing in the world: the
## box goes at once, the game waits until that key is let go (a Space would jump, a click fire, an E tap the barrow
## beside the neighbour). Answers by number and W/S go by where the keys sit, so 1-4 work on any keyboard layout.
##
## The look is StoryHUD's and the menus': the HUD's serif (FrontierHUD.serif: Baskerville on a Mac) over a soft shade
## rising from the bottom edge, nothing boxed; the speaker's name in gold capitals over a thin gold rule, the line in
## ink (narration, with no speaker, in the plainer text colour), the chosen answer gold with a gold rule at its left
## (MenuUI.item's mark).
## The flags are the StoryDirector's `flags` (kept in the save with the storyline); with no director, flags_alone.

const GROUP := &"story_dialogue"
const DIR := "res://data/story/dialogue/"
const MAX_CHOICES := 4
const CHARS_S := 55.0          ## letters a second the line types out at
const MAX_TYPE_S := 1.6        ## s: a long line types out faster, never longer than this
const OPEN_GUARD_S := 0.3      ## s: a key still down from what opened it (E at a contact) does not skip the first line
const PICK_GUARD_S := 0.35     ## s: Enter mashed through the lines does not take an answer the moment it shows
const MAX_HOPS := 32           ## nodes passed through without a line before the graph is taken for a loop
const END_WAIT_S := 2.0        ## s at most the game waits, after the talk, for the key that ended it to come up
## An "if" dictionary's own keys (see _format.if), and the director's `when` keys taken in it as its `when`.
const IF_KEYS := ["flag", "not_flag", "flag_is", "standing", "min", "max", "item", "n", "no_item", "any", "not", "when"]
const WHEN_KEYS := ["flags", "done", "not_done", "outcome", "window", "hours", "year"]
const WIDTH := 760.0
const INK := FrontierHUD.INK
const TEXT := FrontierHUD.TEXT
const DIM := FrontierHUD.DIM
const GOLD := FrontierHUD.GOLD

## The flags when there is no StoryDirector (tools, a scene without the story).
static var flags_alone := {}
## The mouse mode the last talk gave back as it shut (tests: a headless run's mouse has no capture to read back).
static var mouse_given_back := -1
## Tests: the talk behaves as in a shared world (nothing paused) without hosting one (that would open a port).
static var force_shared := false
static var _warned := {}         ## condition keys already warned of (once each)

var convo_id := ""
var convo := {}                  ## the conversation (its "speakers" merged from the file's)
var node_id := ""
var node := {}
var outcome := ""                ## set by an effect's "outcome"; an "end" gives the last word
var choices: Array = []          ## the answers shown now: [{i: index in the node's list, c: the answer}]
var sel := 0                     ## the chosen answer (keys, hover)
var _done: Callable
var _queue: Array = []           ## [convo_id, on_done] opened while this one was up
var _missions: Array = []        ## missions the answers started: begun once the box is shut
var _picked := {}                ## "node:i" of "once" answers already taken in this talk
var _shown := 0.0                ## letters of the line shown
var _typing := false
var _guard_t := 0.0
var _pick_t := 0.0
var _hops := 0
var _closed := false             ## the talk is over (the box gone); the game may still wait for the key to come up
var _gone := false               ## the game let go and the caller told
var _paused_by_us := false
var _was_mouse := Input.MOUSE_MODE_CAPTURED
var _held: PlayerControls = null  ## the player's controls let go of in a shared world
var _interactor: Node = null      ## the player's E interactor stopped in a shared world, and how it ran before
var _interactor_mode := Node.PROCESS_MODE_INHERIT
var _prompts: CanvasLayer = null  ## the E prompts' layer put away under the box
var _pm: PauseMenu = null
var _menu_up := false             ## the pause menu is open over the talk (the box hidden, the keys the menu's)
var _ev_phys := KEY_NONE          ## the key or button being handled now (a talk it ends waits for it to come up)
var _ev_code := KEY_NONE
var _ev_button := MOUSE_BUTTON_NONE
var _end_phys := KEY_NONE         ## the key or button that ended the talk
var _end_code := KEY_NONE
var _end_button := MOUSE_BUTTON_NONE
var _end_wait := 0.0

var _root: Control
var _shade: TextureRect
var _box: VBoxContainer
var _name: Label
var _rule: ColorRect
var _line: Label
var _choice_box: VBoxContainer
var _more: Label


# --- The calls -----------------------------------------------------------------------------------------------

## Opens the conversation `convo_id`; `on_done.call(outcome)` once it ends. With one already open it waits its turn.
## A conversation that is not there is an error; on_done still hears "" (on the next frame).
static func open(tree: SceneTree, convo_id: String, on_done: Callable) -> void:
	if tree == null:
		return
	var cur := _current(tree)
	if cur != null:
		cur._queue.append([convo_id, on_done])       # (also behind one shut but still waiting for its key)
		return
	var c := conversation(convo_id, tree)
	if c.is_empty():
		push_error("StoryDialogue: no conversation %s" % convo_id)
		if on_done.is_valid():
			on_done.call_deferred("")
		return
	var d := StoryDialogue.new()
	d.name = "StoryDialogue"
	d.convo_id = convo_id
	d.convo = c
	d._done = on_done
	(tree.current_scene if tree.current_scene != null else tree.root).add_child(d)


## A line said over `speaker` in the world for `seconds` (StoryBark: a subtitle over the person, no box, no pause).
static func bark(speaker: Node3D, text: String, seconds := 3.0) -> void:
	StoryBark.say(speaker, text, seconds)


static func is_open(tree: SceneTree) -> bool:
	return find(tree) != null


## The talk open now (null none).
static func find(tree: SceneTree) -> StoryDialogue:
	if tree == null:
		return null
	for n in tree.get_nodes_in_group(GROUP):
		var d := n as StoryDialogue
		if d != null and not d._closed:
			return d
	return null


## The talk that has the game now: open, or shut and waiting for its key to come up (null none).
static func _current(tree: SceneTree) -> StoryDialogue:
	if tree == null:
		return null
	for n in tree.get_nodes_in_group(GROUP):
		var d := n as StoryDialogue
		if d != null and not d._gone:
			return d
	return null


## Where the story's files are: StoryDirector.dir (tests point it at a story of their own), else the game's.
static func story_dir() -> String:
	var v: Variant = (StoryDirector as Script).get("dir")
	return String(v) if v is String and String(v) != "" else StoryDirector.STORY_DIR


## Where the dialogue files are read from: under the story's folder first, then the game's own.
static func dirs() -> Array[String]:
	var out: Array[String] = [story_dir() + "dialogue/"]
	if not out.has(DIR):
		out.append(DIR)
	return out


## A storyline's dialogue file ({} none).
static func load_file(storyline: String) -> Dictionary:
	for d in dirs():
		var path := d + "%s.json" % storyline
		if FileAccess.file_exists(path):
			return StoryDirector.load_json(path)
	return {}


## The conversation `convo_id` ({} none), its speakers the file's with its own over them.
static func conversation(convo_id: String, tree: SceneTree = null) -> Dictionary:
	var file := convo_id.get_slice("/", 0) if convo_id.contains("/") else ""
	var key := convo_id.get_slice("/", 1) if convo_id.contains("/") else convo_id
	var files: Array[String] = []
	if file != "":
		files.append(file)
	else:
		var sd := StoryDirector.find(tree)
		if sd != null and sd.storyline_id != "":
			files.append(sd.storyline_id)
		for dir in dirs():
			if not DirAccess.dir_exists_absolute(dir):
				continue
			for f in DirAccess.get_files_at(dir):
				if f.ends_with(".json") and not files.has(f.get_basename()):
					files.append(f.get_basename())
	for f in files:
		var doc := load_file(f)
		var all: Variant = doc.get("conversations")
		var c: Variant = (all as Dictionary).get(key) if all is Dictionary else null
		if c is Dictionary and not (c as Dictionary).is_empty():
			var out := (c as Dictionary).duplicate(true)
			var sp: Dictionary = (doc.get("speakers", {}) as Dictionary).duplicate(true) if doc.get("speakers") is Dictionary else {}
			if out.get("speakers") is Dictionary:
				sp.merge(out.get("speakers") as Dictionary, true)
			out["speakers"] = sp
			return out
	return {}


## The story's flags (StoryDirector.flags; flags_alone with no director). The dictionary itself: changes stay.
static func flags_of(tree: SceneTree) -> Dictionary:
	var sd := StoryDirector.find(tree)
	if sd != null:
		var f: Variant = sd.get("flags")
		if f is Dictionary:
			return f
	return flags_alone


## Alone (no shared world): the game waits under the talk.
static func alone(tree: SceneTree) -> bool:
	if force_shared:
		return false
	var n := tree.root.get_node_or_null("Net") as NetSession if tree != null else null
	return n == null or not n.in_session()


## This machine's player (null none; the others in a shared world are in the "player" group too).
static func local_player(tree: SceneTree) -> FrontierPlayer:
	if tree == null:
		return null
	for n in tree.get_nodes_in_group(&"player"):
		var p := n as FrontierPlayer
		if p != null and p.is_local:
			return p
	return null


static func _core(tree: SceneTree) -> SurvivalCore:
	var b := SurvivalBridge.find(tree)
	return b.core if b != null else null


# --- Conditions ----------------------------------------------------------------------------------------------

## Does `cond` hold now (the format's "if": null or "" always; "name" a flag set, "!name" not set; [..] all of them;
## a dictionary: every key it has must hold, see _format.if in the dialogue files). A mission `when`'s own keys in it
## (flags, done, not_done, outcome, window, hours, year, standing as {faction: limit}) are that `when`; a key that is
## neither (a typo) is warned of once and does not hold, so what it guards stays hidden rather than always shown.
static func holds(tree: SceneTree, cond: Variant) -> bool:
	if cond == null:
		return true
	if cond is String or cond is StringName:
		var s := String(cond).strip_edges()
		if s == "":
			return true
		if s.begins_with("!"):
			return not _truthy(flags_of(tree).get(s.substr(1)))
		return _truthy(flags_of(tree).get(s))
	if cond is Array:
		for c: Variant in cond:
			if not holds(tree, c):
				return false
		return true
	if not (cond is Dictionary):
		return true
	var d := cond as Dictionary
	var fl := flags_of(tree)
	var when := {}                                   # (the director's own keys, checked as its `when`)
	for key: Variant in d:
		var ks := String(key)
		if ks.begins_with("_") or (IF_KEYS.has(ks) and not (ks == "standing" and d[key] is Dictionary)):
			continue
		if WHEN_KEYS.has(ks) or ks == "standing":
			when[ks] = d[key]
			continue
		if not _warned.has(ks):
			_warned[ks] = true
			push_warning("StoryDialogue: no condition \"%s\" (in %s): it does not hold" % [ks, JSON.stringify(d)])
		return false
	if not when.is_empty() and not _director_holds(tree, when):
		return false
	if d.has("flag"):
		for k in _names(d.get("flag")):
			if not _truthy(fl.get(k)):
				return false
	if d.has("not_flag"):
		for k in _names(d.get("not_flag")):
			if _truthy(fl.get(k)):
				return false
	if d.get("flag_is") is Dictionary:
		var fi := d.get("flag_is") as Dictionary
		for k: Variant in fi:
			if not _same(fl.get(String(k)), fi[k]):
				return false
	if d.has("standing") and not (d.get("standing") is Dictionary):
		var v := standing_of(tree, String(d.get("standing")))
		if d.has("min") and v < float(d.get("min")):
			return false
		if d.has("max") and v > float(d.get("max")):
			return false
	if d.has("item") and item_count(tree, String(d.get("item"))) < int(d.get("n", 1)):
		return false
	if d.has("no_item") and item_count(tree, String(d.get("no_item"))) > 0:
		return false
	if d.has("any"):
		var any_of: Array = d.get("any") if d.get("any") is Array else [d.get("any")]
		var ok := false
		for c: Variant in any_of:
			if holds(tree, c):
				ok = true
				break
		if not ok:
			return false
	if d.has("not") and holds(tree, d.get("not")):
		return false
	if d.has("when") and not _director_holds(tree, d.get("when")):
		return false
	return true


## The story director's own condition form (a mission's `when`: missions done, their outcomes, the date), when the
## director has one (StoryDirector.condition; with no director running, on flags_alone); without it the condition is
## let pass, with a warning.
static func _director_holds(tree: SceneTree, when: Variant) -> bool:
	var ds: Script = StoryDirector
	var os: Script = StoryObjectives
	if StoryDirector.find(tree) == null and when is Dictionary and os.has_method("holds"):
		return bool(os.call("holds", when, tree, {"flags": flags_alone}))
	if ds.has_method("condition"):
		return bool(ds.call("condition", tree, when))
	push_warning("StoryDialogue: the story has no `when` conditions yet; let pass")
	return true


static func _names(v: Variant) -> Array[String]:
	var out: Array[String] = []
	if v is Array:
		for k: Variant in v:
			out.append(String(k))
	elif v != null:
		out.append(String(v))
	return out


static func _truthy(v: Variant) -> bool:
	match typeof(v):
		TYPE_NIL:
			return false
		TYPE_BOOL:
			return v
		TYPE_INT, TYPE_FLOAT:
			return float(v) != 0.0
		TYPE_STRING, TYPE_STRING_NAME:
			return String(v) != ""
	return true


static func _same(a: Variant, b: Variant) -> bool:
	if a == null:
		a = false
	if (typeof(a) == TYPE_INT or typeof(a) == TYPE_FLOAT) and (typeof(b) == TYPE_INT or typeof(b) == TYPE_FLOAT):
		return is_equal_approx(float(a), float(b))
	if (typeof(a) == TYPE_STRING or typeof(a) == TYPE_STRING_NAME) and (typeof(b) == TYPE_STRING or typeof(b) == TYPE_STRING_NAME):
		return String(a) == String(b)
	return typeof(a) == typeof(b) and a == b


## The player's standing with `faction` (SurvivalEconomy; 0, neutral, when there is no survival game).
static func standing_of(tree: SceneTree, faction: String) -> float:
	var c := _core(tree)
	return SurvivalEconomy.standing(c, faction) if c != null else 0.0


## How many `kind` the player has: an "item." id in the survival kit (SurvivalInventory), else a pack kind (InventoryState).
static func item_count(tree: SceneTree, kind: String) -> int:
	if kind.begins_with("item."):
		var c := _core(tree)
		return int(SurvivalInventory.count(c, kind)) if c != null else 0
	var p := local_player(tree)
	return TreeHarvest.pack_count(p, kind) if p != null else 0


# --- Effects -------------------------------------------------------------------------------------------------

## Does the format's "do" (one effect or a list; see _format.do in the dialogue files). Returns what is for the talk
## itself: {missions: [ids to start], outcome?}.
static func apply(tree: SceneTree, ops: Variant) -> Dictionary:
	var out := {"missions": []}
	if ops == null:
		return out
	var fl := flags_of(tree)
	for op: Variant in (ops if ops is Array else [ops]):
		if op is String or op is StringName:
			fl[String(op)] = true                    # (a bare name: that flag set)
			continue
		if not (op is Dictionary):
			continue
		var d := op as Dictionary
		if d.has("set"):
			var s: Variant = d.get("set")
			if s is Dictionary:
				for k: Variant in s:
					fl[String(k)] = (s as Dictionary)[k]
			else:
				for k in _names(s):
					fl[k] = d.get("to", true)
		if d.has("clear"):
			for k in _names(d.get("clear")):
				fl.erase(k)
		if d.has("standing"):
			add_standing(tree, String(d.get("standing")), float(d.get("by", 0.0)), String(d.get("source", "")))
		if d.has("give"):
			give(tree, String(d.get("give")), int(d.get("n", 1)))
		if d.has("take"):
			take(tree, String(d.get("take")), int(d.get("n", 1)))
		if d.has("mission"):
			(out.missions as Array).append(String(d.get("mission")))
		if d.has("outcome"):
			out["outcome"] = String(d.get("outcome"))
	return out


## Standing with `faction` changed by `by` (SurvivalEconomy.add_standing: a named source keeps its monthly cap). Nothing
## without a survival game.
static func add_standing(tree: SceneTree, faction: String, by: float, source := "") -> void:
	var c := _core(tree)
	if c == null or not (c.state.economy.get("standing") is Dictionary):
		return
	SurvivalEconomy.add_standing(c, faction, by, source)


## `n` of `kind` into the player's keeping (an "item." id into the survival kit, else the pack), said on the HUD.
static func give(tree: SceneTree, kind: String, n: int) -> void:
	if n <= 0:
		return
	if kind.begins_with("item."):
		var c := _core(tree)
		if c == null:
			return
		SurvivalInventory.add(c, kind, float(n))
	else:
		var p := local_player(tree)
		if p == null:
			return
		TreeHarvest.pack_add(p, kind, n)
	_toast(tree, "Received %d %s" % [n, _item_name(tree, kind)])


## Up to `n` of `kind` taken from the player; how many there were to take.
static func take(tree: SceneTree, kind: String, n: int) -> int:
	var got := 0
	if kind.begins_with("item."):
		var c := _core(tree)
		if c == null:
			return 0
		got = mini(n, int(SurvivalInventory.count(c, kind)))
		if got > 0:
			SurvivalInventory.remove(c, kind, float(got))
	else:
		var p := local_player(tree)
		if p == null:
			return 0
		got = TreeHarvest.pack_take(p, kind, n)
	if got > 0:
		_toast(tree, "Gave %d %s" % [got, _item_name(tree, kind)])
	return got


static func _item_name(tree: SceneTree, kind: String) -> String:
	if kind.begins_with("item."):
		var c := _core(tree)
		return c.data.item_name(kind) if c != null else kind.get_slice(".", kind.get_slice_count(".") - 1).capitalize()
	return InventoryState.name_of(kind)


static func _toast(tree: SceneTree, text: String) -> void:
	var p := local_player(tree)
	if p != null and p.hud != null:
		p.hud.toast(text)


## A mission of the storyline at hand begun (an answer's "mission"): the director's start_mission_id(id) when it has
## one, else the mission found by its id and started in its place.
static func start_mission(tree: SceneTree, id: String) -> void:
	var sd := StoryDirector.find(tree)
	if sd == null:
		push_warning("StoryDialogue: no story to start %s in" % id)
		return
	if sd.has_method("start_mission_id"):
		sd.call("start_mission_id", id)
		return
	for i in sd.missions.size():
		if String((sd.missions[i] as Dictionary).get("id", "")) == id:
			sd.call("_start_mission", i)
			return
	push_warning("StoryDialogue: no mission %s in the storyline at hand" % id)


# --- The box -------------------------------------------------------------------------------------------------

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUP)
	_build()
	_was_mouse = Input.mouse_mode
	_hold_game()
	_guard_t = OPEN_GUARD_S
	_goto(String(convo.get("start", "start")))


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP    # (a click is the talk's, not the world's: it does not catch the mouse)
	_root.gui_input.connect(_on_click)
	var th := Theme.new()
	th.default_font = FrontierHUD.serif()
	_root.theme = th
	add_child(_root)
	# the foot of the screen darkened: a soft shade rising from the bottom edge (no box, as the HUD)
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.015, 0.01, 0.0))
	g.set_color(1, Color(0.02, 0.015, 0.01, 0.84))
	g.add_point(0.5, Color(0.02, 0.015, 0.01, 0.55))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 8
	gt.height = 128
	_shade = TextureRect.new()
	_shade.texture = gt
	_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shade.stretch_mode = TextureRect.STRETCH_SCALE
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.anchor_right = 1.0
	_shade.anchor_top = 0.48
	_shade.anchor_bottom = 1.0
	_root.add_child(_shade)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.anchor_left = 0.5
	_box.anchor_right = 0.5
	_box.anchor_top = 1.0
	_box.anchor_bottom = 1.0
	_box.offset_left = -WIDTH * 0.5
	_box.offset_right = WIDTH * 0.5
	_box.offset_top = -64.0
	_box.offset_bottom = -64.0
	_box.grow_vertical = Control.GROW_DIRECTION_BEGIN   # (a long line or more answers push it up, never off the bottom)
	_root.add_child(_box)
	_name = _label(20, GOLD)
	_box.add_child(_name)
	_rule = ColorRect.new()
	_rule.color = Color(GOLD, 0.45)
	_rule.custom_minimum_size = Vector2(WIDTH * 0.32, 1)
	_rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_rule)
	_line = _label(23, INK)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# the whole line laid out (wrapped) before it types, the letters only shown: the box keeps its height and a word
	# does not jump to the next line as it is typed
	_line.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_line.custom_minimum_size = Vector2(WIDTH, 0)
	_box.add_child(_line)
	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 2)
	_choice_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_choice_box)
	_more = _label(15, DIM)
	_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_box.add_child(_more)


func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Alone the game waits (paused); in a shared world the player only stands, and the E interactor (which reads E from
## the keyboard itself, not from the controls) is stopped: E said in the talk taps nothing in the world, and a held
## E opens no list under the box. The mouse is let free, and the E prompt at the foot of the screen
## (PlayerInteractor's layer: "E  Talk to ...", left from the press that opened the talk) is put away under the box.
func _hold_game() -> void:
	var p := local_player(get_tree())
	var it: Node = p.interactor if p != null else null
	if alone(get_tree()):
		if not get_tree().paused:
			get_tree().paused = true
			_paused_by_us = true
	elif p != null:
		if p.controls != null and p.controls.from_input:
			p.controls.from_input = false
			p.controls.release_all()
			_held = p.controls
		if it != null and it.process_mode != Node.PROCESS_MODE_DISABLED:
			_interactor = it
			_interactor_mode = it.process_mode
			it.process_mode = Node.PROCESS_MODE_DISABLED
	var lay: Variant = it.get("_layer") if it != null else null
	if lay is CanvasLayer and (lay as CanvasLayer).visible:
		(lay as CanvasLayer).visible = false
		_prompts = lay
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _let_go() -> void:
	if _paused_by_us:
		get_tree().paused = false
		_paused_by_us = false
	if _held != null:
		_held.from_input = true
		_held = null
	if _interactor != null and is_instance_valid(_interactor):
		_interactor.process_mode = _interactor_mode
	_interactor = null
	if _prompts != null and is_instance_valid(_prompts):
		_prompts.visible = true
	_prompts = null
	# the mouse as the talk found it: caught in play, free in the command view (a headless run reads it free always)
	mouse_given_back = _was_mouse
	Input.mouse_mode = _was_mouse


func _exit_tree() -> void:
	if not _gone:                                      # (the level went with it: a load; leave the game as it was)
		_closed = true
		_gone = true
		_let_go()


func nodes() -> Dictionary:
	return convo.get("nodes", {}) if convo.get("nodes") is Dictionary else {}


## The name over the line for a node's "speaker": the speakers' name for a key, the text itself otherwise ("" narration).
func speaker_name(key: String) -> String:
	var sp: Variant = (convo.get("speakers", {}) as Dictionary).get(key)
	if sp is Dictionary:
		return String((sp as Dictionary).get("name", key))
	if sp is String:
		return String(sp)
	return "" if key == "narrator" else key


func _goto(id: String) -> void:
	_hops += 1
	if _hops > MAX_HOPS:
		push_error("StoryDialogue: %s goes round without a line (at %s)" % [convo_id, id])
		_finish(outcome)
		return
	if id == "" or not nodes().has(id):
		if id != "":
			push_error("StoryDialogue: %s has no node %s" % [convo_id, id])
		_finish(outcome)
		return
	node_id = id
	node = nodes()[id] if nodes()[id] is Dictionary else {}
	_apply(node.get("do"))
	if _closed:
		return
	var text := String(node.get("text", ""))
	if text == "":
		# a turn with no words of its own: its answers under the line already said, or straight on
		if _visible_choices().is_empty():
			_follow(node)
		else:
			_typing = false
			_line.visible_characters = -1
			_show_choices()
		return
	_hops = 0
	_say(String(node.get("speaker", "")), text)


func _say(who: String, text: String) -> void:
	var nm := speaker_name(who)
	_name.text = nm.to_upper()
	_name.visible = nm != ""
	_rule.visible = nm != ""
	_line.text = text
	_line.add_theme_color_override("font_color", INK if nm != "" else TEXT)
	_clear_choices()
	choices = []
	_more.text = ""
	_shown = 0.0
	_line.visible_characters = 0
	_typing = true


func _end_typing() -> void:
	_typing = false
	_line.visible_characters = -1
	if not _visible_choices().is_empty():
		_show_choices()
	elif _leads_to_answers():
		_hops = 0
		_follow(node)                                # (its questions come up under this line, no key between)
	else:
		_more.text = "Enter  close" if _ends_here() else "Enter  continue"


## The node goes on to a turn with no words of its own but answers that can be given now (the way back to a list of
## questions). One whose answers are all hidden (taken "once", or their "if" not holding) is not: the line waits for a
## key rather than the talk running on past it.
func _leads_to_answers() -> bool:
	if node.has("end"):
		return false
	var nx_id := String(_resolve(node.get("goto")).get("goto", ""))
	var nx: Variant = nodes().get(nx_id)
	return nx is Dictionary and String((nx as Dictionary).get("text", "")) == "" and not _choices_of(nx_id, nx as Dictionary).is_empty()


## The node goes nowhere after its line (an "end", or no goto that leads to a node, or only through turns with no
## words and no answers to give that end it).
func _ends_here() -> bool:
	var from := node
	for i in MAX_HOPS:
		if from.has("end"):
			return true
		var to := _resolve(from.get("goto"))
		var id := String(to.get("goto", ""))
		if to.has("end") or not nodes().has(id):
			return true
		var nx: Variant = nodes()[id]
		if not (nx is Dictionary) or String((nx as Dictionary).get("text", "")) != "" or not _choices_of(id, nx as Dictionary).is_empty():
			return false
		from = nx
	return true


## The node's answers that can be given now: not taken already if "once", their "if" holding; MAX_CHOICES at most.
func _visible_choices() -> Array:
	return _choices_of(node_id, node)


## The answers of node `id` that can be given now ([{i, c}]).
func _choices_of(id: String, n: Dictionary) -> Array:
	var out: Array = []
	var list: Array = n.get("choices", []) if n.get("choices") is Array else []
	for i in list.size():
		if not (list[i] is Dictionary):
			continue
		var c := list[i] as Dictionary
		if bool(c.get("once", false)) and _picked.has("%s:%d" % [id, i]):
			continue
		if not holds(get_tree(), c.get("if")):
			continue
		out.append({"i": i, "c": c})
		if out.size() >= MAX_CHOICES:
			break
	return out


func _show_choices() -> void:
	choices = _visible_choices()
	_clear_choices()
	for k in choices.size():
		_choice_box.add_child(_choice_row(k, String((choices[k].c as Dictionary).get("text", ""))))
	sel = 0
	_restyle()
	_pick_t = PICK_GUARD_S
	_more.text = "1  answer" if choices.size() == 1 else "1-%d  answer" % choices.size()


## An answer's row: a gold rule at its left when chosen (MenuUI's mark), its number, its words.
func _choice_row(k: int, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var rule := ColorRect.new()
	rule.name = "Rule"
	rule.custom_minimum_size = Vector2(3, 0)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rule)
	var num := _label(18, DIM)
	num.name = "Num"
	num.text = str(k + 1)
	num.custom_minimum_size = Vector2(16, 0)
	row.add_child(num)
	var t := _label(21, TEXT)
	t.name = "Text"
	t.text = text
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	row.mouse_entered.connect(func() -> void: _select(k))
	row.gui_input.connect(_on_row_input.bind(row, k))
	return row


func _on_row_input(e: InputEvent, row: Control, k: int) -> void:
	var mb := e as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	row.accept_event()
	if mb.button_index == MOUSE_BUTTON_LEFT:
		_ev_button = mb.button_index
		choose(k)
		_ev_button = MOUSE_BUTTON_NONE
	elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		_select(sel - 1)
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_select(sel + 1)


func _clear_choices() -> void:
	for c in _choice_box.get_children():
		_choice_box.remove_child(c)
		c.queue_free()


func _select(k: int) -> void:
	if choices.is_empty():
		return
	sel = wrapi(k, 0, choices.size())
	_restyle()


func _restyle() -> void:
	for k in _choice_box.get_child_count():
		var row := _choice_box.get_child(k)
		var on := k == sel
		(row.get_node("Rule") as ColorRect).color = Color(GOLD, 1.0 if on else 0.0)
		(row.get_node("Text") as Label).add_theme_color_override("font_color", GOLD if on else TEXT)
		(row.get_node("Num") as Label).add_theme_color_override("font_color", GOLD if on else DIM)


## Any key or a click: the line shown whole, or (shown) on to what follows it. Not while answers wait.
func advance() -> void:
	if _closed:
		return
	if _typing:
		_end_typing()
		return
	if not choices.is_empty():
		return
	_hops = 0
	_follow(node)


## Gives the `k`th answer shown: its effects, then where it leads.
func choose(k: int) -> void:
	if _closed or _typing or k < 0 or k >= choices.size():
		return
	var e: Dictionary = choices[k]
	var c := e.c as Dictionary
	_picked["%s:%d" % [node_id, int(e.i)]] = true
	choices = []
	_clear_choices()
	_apply(c.get("do"))
	if _closed:
		return
	_hops = 0
	_follow(c)


## On from a node or an answer: its "end" (the talk ends, that the outcome), else its "goto".
func _follow(from: Dictionary) -> void:
	if from.has("end"):
		_finish(String(from.get("end")))
		return
	var to := _resolve(from.get("goto"))
	if to.has("end"):
		_finish(String(to.get("end")))
		return
	_goto(String(to.get("goto", "")))


## A "goto": a node's id, or a list of {if, goto | end} taken at the first whose "if" holds.
func _resolve(g: Variant) -> Dictionary:
	if g is String or g is StringName:
		return {"goto": String(g)}
	if g is Array:
		for e: Variant in g:
			if e is String:
				return {"goto": String(e)}
			if e is Dictionary and holds(get_tree(), (e as Dictionary).get("if")):
				return e
	elif g is Dictionary and holds(get_tree(), (g as Dictionary).get("if")):
		return g
	return {}


func _apply(ops: Variant) -> void:
	var r := apply(get_tree(), ops)
	if r.has("outcome"):
		outcome = String(r.outcome)
	_missions.append_array(r.missions as Array)


## The talk is over: the box goes at once. The game is let go of (and the caller hears the outcome) once the key or
## click that ended it is up again, so it does nothing in the world as the game runs on (END_WAIT_S at most).
func _finish(result: String) -> void:
	if _closed:
		return
	_closed = true
	if result == "":
		result = outcome
	outcome = result
	visible = false
	_typing = false
	choices = []
	_end_phys = _ev_phys
	_end_code = _ev_code
	_end_button = _ev_button
	_end_wait = END_WAIT_S
	if not _end_held():
		_release()


## The key or button that ended the talk (or E, the interact key, whatever ended it) is still down.
func _end_held() -> bool:
	if _end_phys != KEY_NONE and Input.is_physical_key_pressed(_end_phys):
		return true
	if _end_code != KEY_NONE and Input.is_key_pressed(_end_code):
		return true
	if _end_button != MOUSE_BUTTON_NONE and Input.is_mouse_button_pressed(_end_button):
		return true
	return InputMap.has_action(ThrownPickup.INTERACT) and Input.is_action_pressed(ThrownPickup.INTERACT)


## The game let go of, the missions the answers started begun, the caller told, then the next talk waiting.
func _release() -> void:
	if _gone:
		return
	_gone = true
	remove_from_group(GROUP)
	_let_go()
	var tree := get_tree()
	var done := _done
	var queue := _queue
	var missions := _missions
	var result := outcome
	queue_free()
	for m: String in missions:
		start_mission(tree, m)
	if done.is_valid():
		done.call(result)
	for q: Array in queue:
		open(tree, String(q[0]), q[1] as Callable)


func _process(delta: float) -> void:
	if _gone:
		return
	# the pause menu over the talk (Esc): it has the game, the keys and the mouse until it shuts; then the talk takes
	# them back (the menu's Resume lets the game go and catches the mouse: both are put right below)
	var menu_up := _menu_open()
	if menu_up != _menu_up:
		_menu_up = menu_up
		visible = not menu_up and not _closed
	if menu_up:
		return
	# alone the game stays waiting under the talk (another screen let go of the pause meanwhile)
	if alone(get_tree()) and not get_tree().paused:
		get_tree().paused = true
		_paused_by_us = true
	if _closed:
		_end_wait -= delta
		if not _end_held() or _end_wait <= 0.0:
			_release()
		return
	_guard_t -= delta
	_pick_t -= delta
	if _typing:
		var total := _line.get_total_character_count()
		_shown += maxf(CHARS_S, float(total) / MAX_TYPE_S) * delta
		if _shown >= float(total):
			_end_typing()
		else:
			_line.visible_characters = int(_shown)
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _pause_menu() -> PauseMenu:
	if _pm == null or not is_instance_valid(_pm):
		var s := get_tree().current_scene if is_inside_tree() else null
		_pm = s.get_node_or_null("PauseMenu") as PauseMenu if s != null else null
	return _pm


func _menu_open() -> bool:
	var pm := _pause_menu()
	return pm != null and pm.is_open()


## Esc: the pause menu over the talk (its own check refuses while the game is paused, as the talk has it). False when
## there is none (a tool or test level) or it is open already.
func _open_pause_menu() -> bool:
	var pm := _pause_menu()
	if pm == null or pm.is_open():
		return false
	pm.open()
	return true


func _input(event: InputEvent) -> void:
	if _closed or not (event is InputEventKey) or _menu_open():
		return                                       # (the pause menu over the talk has the keys)
	var k := event as InputEventKey
	var code := k.keycode if k.keycode != KEY_NONE else k.physical_keycode
	var phys := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode   # (where the key sits)
	if code == KEY_ESCAPE or phys == KEY_ESCAPE:
		if k.pressed and not k.echo and _open_pause_menu():
			get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()            # (every other key is the talk's: no weapon switch, no build mode under it)
	if not k.pressed or k.echo or _guard_t > 0.0:
		return
	if code in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK]:
		return
	_ev_phys = k.physical_keycode
	_ev_code = k.keycode
	_on_key(k, code, phys)
	_ev_phys = KEY_NONE
	_ev_code = KEY_NONE


## A key in the talk. Numbers and W/A/S/D by where they sit (physical: AZERTY's 1 is "&"), E by the interact binding.
func _on_key(k: InputEventKey, code: Key, phys: Key) -> void:
	if choices.is_empty():
		advance()
		return
	var interact := InputMap.has_action(ThrownPickup.INTERACT) and k.is_action(ThrownPickup.INTERACT, true)
	if phys >= KEY_1 and phys <= KEY_9:
		choose(phys - KEY_1)
	elif phys >= KEY_KP_1 and phys <= KEY_KP_9:
		choose(phys - KEY_KP_1)
	elif code in [KEY_UP, KEY_LEFT] or phys in [KEY_W, KEY_A]:
		_select(sel - 1)
	elif code in [KEY_DOWN, KEY_RIGHT, KEY_TAB] or phys in [KEY_S, KEY_D]:
		_select(sel + 1)
	elif (code in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] or interact) and _pick_t <= 0.0:
		choose(sel)


## A click anywhere but on an answer: as any key. The wheel moves along the answers.
func _on_click(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	_root.accept_event()
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		_select(sel - 1)
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_select(sel + 1)
	elif mb.button_index == MOUSE_BUTTON_LEFT and _guard_t <= 0.0:
		_ev_button = mb.button_index
		advance()
		_ev_button = MOUSE_BUTTON_NONE


# --- For tests and tools -------------------------------------------------------------------------------------

func line_text() -> String:
	return _line.text


func speaker_text() -> String:
	return _name.text if _name.visible else ""


func choice_texts() -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in choices:
		out.append(String((e.c as Dictionary).get("text", "")))
	return out


func typing() -> bool:
	return _typing


## Shut, the game still waiting for the key that ended it to come up.
func waiting_for_key() -> bool:
	return _closed and not _gone


## The answer whose words begin with `start` (-1 none shown): tests pick by words, not by place.
func choice_index(start: String) -> int:
	var t := choice_texts()
	for k in t.size():
		if t[k].begins_with(start):
			return k
	return -1
