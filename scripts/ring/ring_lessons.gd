class_name RingLessons
extends Node
## TIDEBREAK'S LESSONS in Practice (the owner, 2026-10-05, after playing: "still difficult for a human to switch spells,
## there's a lot of things going on"; nothing in the game taught the controls): a short run of cards (LessonCard, one line
## each) over a practice against a dummy, each done by DOING it, never by reading it. Every word and rule in
## data/ring/lessons.json; the keys in a line are the actions' bindings now (LessonCard.resolve), and the line is the one for
## the player's control scheme (MatchSetup.scheme(): keys, direction, radial, simple) and element, so it is always right.
##   the run      move (walk a few steps), cast (hold RMB, let go), switch (keys: the same key again, its other move;
##                direction: W as RMB is let go; radial: the move wheel; simple: the next of the four), form (the wheel steps
##                the readied move's forms; simple: a near cast), dodge (the element's dodge as the scheme reaches it), the
##                quick spell (Q, then a cast from LMB), Mend and Patch (5; not under simple: 5 does nothing there), answer its
##                throw (the dummy throws: earth catches a stone, water a bubble against fire, fire a parry, air its shield;
##                simple a cast of its cover), send it back (earth: Shove), the zones (the dummy knocked back a zone) and the
##                water (it knocked in). Done: the card goes green, a click, the next after done_hold_s
##   listened     SwayCaster's cast (the move, its variation, the button: lock_src), mode_changed; the Hotbar's
##                spell_selected; the move wheel open (RadialWheel.is_open); RingMode's knocked_back and rang_out; the
##                player's guards (BendZone.took on a zone he owns) and the dummy's bolts ended by one (BendBolt.ended:
##                caught, steam in a bubble ...); the bind key (bend_quick_bind) pressed
##   the dummy    the practice's (RingMode.dummy): it stands through the lessons and throws through the two that answer a
##                throw (lessons.json dummy per lesson); its element the player's element's (lessons.json "dummy": earth
##                against earth's stones, the rest against fire)
##   skip, resume Enter (the action lesson_skip, rebindable) skips a lesson; each lesson's end is kept in GameSettings'
##                "lessons" section (done or skipped, per scheme, and per element where its words differ: per_element); the
##                next run begins at the first neither and goes on through those left (all done: every one again, in order;
##                a skip then keeps a done lesson done). A test points GameSettings.path at a file of its own
##   the entry    the main menu's Practice panel, its Lessons row (ask: RingMode.lessons_asked, MatchSetup.set_practice
##                with dummy_for(el)); the user arg lessons=on with practice= for a run. RingMode installs it then
## Never a cue on the dummy and no line on the deck: the card says it all, at the right of the screen.

const DATA_PATH := "res://data/ring/lessons.json"
const NODE_NAME := "RingLessons"
const GROUP := &"ring_lessons"
## GameSettings' section the lessons' ends are kept in.
const SECTION := "lessons"
const SKIP_KEY := KEY_ENTER
## A dummy's bolt ended for one of these was taken by a guard of the player's (a bubble's steam, a catch, ...).
const GUARD_ENDS := ["steam", "bubble", "caught", "cushioned", "drunk", "absorbed"]

static var _data := {}

var mode: RingMode
var card: LessonCard
## This run's lessons (lessons_for the scheme and element), the one at `at` (-1 before the first; size: finished).
var list: Array = []
var at := -1
var scheme := ""
var element := ""
var finished := false
## Each lesson done (ids) and skipped this run, in order (the tests read them).
var completed: Array = []
var skipped: Array = []
var _hold := -1.0
var _fin_t := -1.0
var _spec := ""
var _walked := 0.0
var _last_pos := Vector3.INF
var _last_ready := ""
var _wheel_seen := false
var _quick_bound := false
var _guarded := false
var _took := {}
var _bolts := {}
var _caster: SwayCaster
var _bar: Hotbar
var _el_seen := ""
## A run begun with every lesson done or skipped already: all of them again in order (else those left, in order).
var _replay := false
var _refresh_t := 0.0


## The lessons under `m` (a practice) when they are asked for (the menu's Lessons row, or lessons=on); null otherwise.
static func install(m: RingMode) -> RingLessons:
	if not wanted():
		return null
	RingMode.lessons_asked = false              # (taken once)
	var l := RingLessons.new()
	l.name = NODE_NAME
	l.mode = m
	m.add_child(l)
	return l


## Whether the next practice runs the lessons: asked by the menu or by the user arg lessons=on, and a practice.
static func wanted() -> bool:
	return MatchSetup.practice() and (RingMode.lessons_asked or "lessons=on" in OS.get_cmdline_user_args())


static func find(tree: SceneTree) -> RingLessons:
	return tree.get_first_node_in_group(GROUP) as RingLessons if tree != null else null


# --- the data ----------------------------------------------------------------------------------------------------------

## data/ring/lessons.json, read once.
static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
		_data = d if d is Dictionary else {"lessons": []}
	return _data


static func word(key: String) -> String:
	return String((data().get("words", {}) as Dictionary).get(key, key))


static func num(key: String, def: float) -> float:
	return float(data().get(key, def))


## The dummy's element for a player of element `el` (earth against earth's stones, the rest against fire).
static func dummy_for(el: String) -> String:
	var d := String((data().get("dummy", {}) as Dictionary).get(el, el))
	return d if d in Bending.ELEMENTS else el


## The lessons for `sch` and `el`, in order (those only for other schemes or elements left out).
static func lessons_for(sch: String, el: String) -> Array:
	var out: Array = []
	for l: Dictionary in data().get("lessons", []):
		if l.has("schemes") and not sch in (l.schemes as Array):
			continue
		if l.has("elements") and not el in (l.elements as Array):
			continue
		out.append(l)
	return out


## Lesson `l`'s line and its completion under `sch`: {line, do}.
static func by_of(l: Dictionary, sch: String) -> Dictionary:
	var by: Dictionary = l.get("by", {})
	return by.get(sch, by.get("*", {}))


# --- kept: each lesson done or skipped -----------------------------------------------------------------------------------

static func key_of(sch: String, el: String, l: Dictionary) -> String:
	return "%s_%s%s" % [sch, String(l.id), ("_" + el) if bool(l.get("per_element", false)) else ""]


## "done", "skipped" or "" (not yet) for lesson `l` under `sch` and `el` (GameSettings' file: a test's own when it set one).
static func state_of(sch: String, el: String, l: Dictionary) -> String:
	var cf := ConfigFile.new()
	cf.load(GameSettings.file())
	return str(cf.get_value(SECTION, key_of(sch, el, l), ""))


static func mark(sch: String, el: String, l: Dictionary, state: String) -> void:
	GameSettings.set_value(SECTION, key_of(sch, el, l), state)


## The first lesson neither done nor skipped (lessons_for's size when every one is).
static func resume_index(sch: String, el: String) -> int:
	var ls := lessons_for(sch, el)
	for i in ls.size():
		if state_of(sch, el, ls[i]) == "":
			return i
	return ls.size()


## Every lesson's end forgotten (all of them again from the first).
static func forget() -> void:
	var cf := ConfigFile.new()
	var f := GameSettings.file()
	cf.load(f)
	if cf.has_section(SECTION):
		cf.erase_section(SECTION)
		cf.save(f)


## The main menu's line under its Lessons row: new, where they resume, or all done.
static func menu_line(sch: String, el: String) -> String:
	var ls := lessons_for(sch, el)
	var i := resume_index(sch, el)
	var how := MatchSetup.scheme_label(sch).to_lower()
	if i >= ls.size():
		return word("menu_line_done") % [ls.size(), how]
	if i == 0:
		return word("menu_line_new") % [ls.size(), MatchSetup.label(el), how]
	return word("menu_line_resume") % [i + 1, ls.size(), String(ls[i].get("title", ""))]


## The lessons asked for from the menu: a practice against the element's dummy (its way kept as it was: the lessons set it).
static func ask(el: String) -> void:
	RingMode.lessons_asked = true
	MatchSetup.set_practice(dummy_for(el))


# --- the run -------------------------------------------------------------------------------------------------------------

func _ready() -> void:
	add_to_group(GROUP)
	_ensure_keys()
	card = LessonCard.install(self)
	if mode != null:
		mode.knocked_back.connect(_on_knocked)
		mode.rang_out.connect(_on_rang_out)


## The skip key (Enter), made when missing (the player may rebind it).
static func _ensure_keys() -> void:
	var a := StringName(String(data().get("skip_action", "lesson_skip")))
	if InputMap.has_action(a):
		return
	InputMap.add_action(a)
	var k := InputEventKey.new()
	k.physical_keycode = SKIP_KEY
	InputMap.action_add_event(a, k)


## The run begun (again) for the scheme and element now, at the first lesson not yet done or skipped (every one done:
## all of them again, unless `quiet`: a scheme or element changed after the run was over leaves it over).
func start(quiet := false) -> void:
	scheme = MatchSetup.scheme()
	element = _element()
	list = lessons_for(scheme, element)
	finished = false
	_fin_t = -1.0
	_hold = -1.0
	at = resume_index(scheme, element)
	_replay = at >= list.size()
	if _replay and quiet:
		finished = true
		card.hide_card()
		return
	if _replay:
		at = 0
	_begin()


func current() -> Dictionary:
	return list[at] if at >= 0 and at < list.size() else {}


func current_id() -> String:
	return String(current().get("id", ""))


## What the lesson now waits for ("walk", "cast", "partner" ...; "" none).
func current_do() -> String:
	return String(by_of(current(), scheme).get("do", "")) if not current().is_empty() else ""


## The card's line as shown (each key as [its cap]).
func lesson_line() -> String:
	return card.shown_text() if card != null else ""


func _begin() -> void:
	var l := current()
	if l.is_empty():
		_finish()
		return
	_walked = 0.0
	_last_pos = Vector3.INF
	_wheel_seen = false
	_quick_bound = false
	_took.clear()
	_last_ready = _caster.readied_spell if _caster != null else ""
	if mode != null:
		mode.dummy = String(l.get("dummy", "stand")) if String(l.get("dummy", "stand")) in MatchSetup.DUMMIES else "stand"
	_spec = line_spec(l)
	card.show_lesson(at + 1, list.size(), String(l.get("title", "")), _spec, word("skip"))


## The lesson's line as a spec for the card: its scheme's line with {press}, {name}, {form}, {what} and {thing} put in.
func line_spec(l: Dictionary) -> String:
	var t := String(by_of(l, scheme).get("line", ""))
	var role := String(l.get("role", ""))
	var rm := role_move(role) if role != "" else {}
	var id := String(rm.get("id", ""))
	var ew: Dictionary = (data().get("elements", {}) as Dictionary).get(element, {})
	var what := String(ew.get("dodge_what", "")) if role == "dodge" else String(ew.get("guard_what", ""))
	if role == "guard" and scheme == "simple":
		what = String(ew.get("simple_what", what))
	if bool(l.get("needs_forms", false)) and scheme != "simple" and _caster != null \
			and SwayCaster.modes_of(_caster.readied_spell).size() < 2:
		t = word("form_first") + t                # (Patch readied: the wheel has no form to step)
	t = t.replace("{press}", press_spec(id)).replace("{name}", _label(id)).replace("{form}", form_spec(rm))
	return t.replace("{what}", what).replace("{thing}", String(ew.get("thing", "")))


## The move a lesson's `role` teaches for the element under the scheme: {id, mode} ({} none). attack, dodge and guard are
## the direction scheme's forward, side and back moves (data/bending/schemes.json), which the other schemes reach by their
## keys; the simple scheme's dodge its third move, its guard lessons.json simple_guard; send_back lessons.json's.
func role_move(role: String) -> Dictionary:
	match role:
		"attack":
			return MatchSetup.direction_move(element, "forward")
		"dodge":
			if scheme == "simple":
				var sk := MatchSetup.simple_skills(element)
				return {"id": String(sk[2].id), "mode": ""} if sk.size() > 2 else {}
			return MatchSetup.direction_move(element, "side")
		"guard":
			if scheme == "simple":
				return {"id": String((data().get("simple_guard", {}) as Dictionary).get(element, "")), "mode": ""}
			return MatchSetup.direction_move(element, "back")
		"send_back":
			var s := String((data().get("send_back", {}) as Dictionary).get(element, ""))
			return {"id": s.get_slice("/", 0), "mode": s.get_slice("/", 1) if s.contains("/") else ""} if s != "" else {}
		"patch":
			return {"id": "patch", "mode": "patch"}
	return {}


## The key(s) that ready move `id` from the bar as it is now: "[weapon_3]", "[weapon_3] twice" (its key holds the other move,
## not readied), "readied" when it is the readied one already; under the simple scheme its place among the four.
func press_spec(id: String) -> String:
	if id == "":
		return ""
	if _caster != null and _caster.readied_spell == id:
		return word("readied")
	if scheme == "simple":
		var sk := MatchSetup.simple_skills(element)
		for i in sk.size():
			if String(sk[i].id) == id:
				return "[weapon_%d]" % (i + 1)
		return ""
	var keys := Bending.keys(element)
	for i in keys.size():
		var pair: Array = keys[i]
		if not id in pair:
			continue
		var key := "[weapon_%d]" % (i + 1)
		var on: Variant = _bar.entry(i).get("id", "") if _bar != null else pair[0]
		if String(on) == id:
			return key
		# (the key holds the other move: once to take it, again for this one; once when that other is readied)
		var other_ready := _caster != null and _caster.readied_spell == String(on)
		return key if other_ready else "%s %s" % [key, word("twice")]
	return ""


## ", roll [weapon_next] to bubble" when move `rm` wants a form its key is not on now ("" otherwise).
func form_spec(rm: Dictionary) -> String:
	var id := String(rm.get("id", ""))
	var md := String(rm.get("mode", ""))
	if id == "" or md == "" or _caster == null or _caster.base_mode_of(id) == md or SwayCaster.modes_of(id).size() < 2:
		return ""
	return word("roll_to") % SwayCaster.mode_label(id, md)


static func _label(id: String) -> String:
	return String(SwayMoves.move(id).get("label", id.capitalize())) if id != "" else ""


func _element() -> String:
	var el := _caster.quick_element() if _caster != null else ""
	if el == "" and mode != null:
		el = mode.element
	return el


func _physics_process(dt: float) -> void:
	if mode == null or mode.phase != "FIGHT":
		return
	_hook()
	if MatchSetup.element != _el_seen:
		# (the element changed in the Esc menu: the next restart brings its own dummy)
		_el_seen = MatchSetup.element
		MatchSetup.foes = [dummy_for(MatchSetup.element)]
	if at < 0 or MatchSetup.scheme() != scheme or _element() != element:
		start(at >= 0 and finished)
		return
	if finished:
		if _fin_t > 0.0:
			_fin_t -= dt
			if _fin_t <= 0.0:
				card.hide_card()
		return
	if _hold > 0.0:
		_hold -= dt
		if _hold <= 0.0:
			_next()
		return
	_refresh_t -= dt
	if _refresh_t <= 0.0:
		_refresh_t = 0.2
		_refresh()
	match current_do():
		"walk":
			_walk()
		"wheel_ready":
			if _caster != null and _caster.radial != null and _caster.radial.is_open:
				_wheel_seen = true
	_scan_guards()


## The player's caster and bar hooked (again after a reset made them anew).
func _hook() -> void:
	var p := mode.player
	if p == null or not is_instance_valid(p):
		return
	var c := SwayCaster.of(p)
	if c != null and c != _caster:
		_caster = c
		c.cast.connect(_on_cast)
		c.mode_changed.connect(_on_mode)
		_last_ready = c.readied_spell
	var b := Hotbar.of(p)
	if b != null and b != _bar:
		_bar = b
		b.spell_selected.connect(_on_selected)


## The line again when what it says has changed (a key pressed: "twice" becomes once, the form reached, a key rebound).
func _refresh() -> void:
	var s := line_spec(current())
	if s != _spec or String(LessonCard.resolve(s).text) != card.shown_text():
		_spec = s
		var l := current()
		card.show_lesson(at + 1, list.size(), String(l.get("title", "")), _spec, word("skip"))


func _walk() -> void:
	var p := mode.player
	if p == null or not is_instance_valid(p):
		return
	var pos := p.global_position
	if _last_pos != Vector3.INF:
		var d := Vector2(pos.x - _last_pos.x, pos.z - _last_pos.z).length()
		if d < 1.0:                              # (a reset's jump back to the end is no walk)
			_walked += d
	_last_pos = pos
	if _walked >= num("walk_m", 3.0):
		complete()


## The player's guards (a zone of his that took something) and the dummy's bolts (ended by one of his guards).
func _scan_guards() -> void:
	var p := mode.player
	for z in get_tree().get_nodes_in_group(BendZone.GROUP):
		var bz := z as BendZone
		if bz == null or bz.owner_node != p:
			continue
		var id := bz.get_instance_id()
		if bz.took > int(_took.get(id, 0)):
			_took[id] = bz.took
			_on_guarded()
	if mode.foe == null or not is_instance_valid(mode.foe):
		return
	for b in get_tree().get_nodes_in_group(BendBolt.GROUP):
		var bb := b as BendBolt
		if bb == null or bb.caster != mode.foe or _bolts.has(bb.get_instance_id()):
			continue
		_bolts[bb.get_instance_id()] = true
		if not bb.ended.is_connected(_on_bolt_end):   # (a bolt still flying when the book was cleared is hooked already)
			bb.ended.connect(_on_bolt_end)
	if _bolts.size() > 64:
		_bolts.clear()


func _on_bolt_end(why: String) -> void:
	if why in GUARD_ENDS:
		_on_guarded()


func _on_guarded() -> void:
	_guarded = true
	if current_do() == "guard" and _hold < 0.0:
		complete()


func _on_cast(m: String, _t: Node3D) -> void:
	if mode == null or mode.phase != "FIGHT" or finished or _hold > 0.0 or _caster == null:
		return
	var src := _caster.lock_src
	var md := _caster.mode_of(m)
	match current_do():
		"cast":
			var want := role_move(String(current().get("role", "")))
			if src == SwayCaster.SRC_AIM and (want.is_empty() or String(want.id) == m):
				complete()
		"quick":
			if src == SwayCaster.SRC_QUICK and _quick_bound:
				complete()
		"near":
			var e := MatchSetup.simple_entry(element, m)
			if not e.is_empty() and md == String(e.get("near", "")):
				complete()


func _on_selected(id: String) -> void:
	if mode == null or mode.phase != "FIGHT" or finished or _hold > 0.0:
		if id != "":
			_last_ready = id
		return
	var was := _last_ready
	if id != "":
		_last_ready = id
	if id == "" or id == was:
		return
	match current_do():
		"partner":
			if was != "" and Bending.partner_of(was) == id:
				complete()
		"ready":
			complete()
		"wheel_ready":
			if _wheel_seen:
				complete()


func _on_mode(id: String, _m: String) -> void:
	if mode == null or mode.phase != "FIGHT" or finished or _hold > 0.0 or _caster == null:
		return
	if current_do() == "form" and id == _caster.readied_spell:
		complete()


func _on_knocked(who: Node3D, _from: int, _to: int) -> void:
	if who == mode.foe and current_do() == "knocked" and _hold < 0.0 and not finished:
		complete()


func _on_rang_out(who: Node3D, _by: Node) -> void:
	if who == mode.foe and current_do() in ["knocked", "out"] and _hold < 0.0 and not finished:
		complete()


func _input(e: InputEvent) -> void:
	if e.is_echo() or not e.is_pressed() or mode == null or mode.phase != "FIGHT":
		return
	if InputMap.has_action(SwayCaster.QUICK_BIND) and e.is_action_pressed(SwayCaster.QUICK_BIND):
		_quick_bound = true
	var a := StringName(String(data().get("skip_action", "lesson_skip")))
	if InputMap.has_action(a) and e.is_action_pressed(a) and not finished:
		skip()
		get_viewport().set_input_as_handled()


## The lesson now done: kept, the card green, a click; the next after done_hold_s.
func complete() -> void:
	var l := current()
	if l.is_empty() or _hold > 0.0:
		return
	mark(scheme, element, l, "done")
	completed.append(String(l.id))
	card.mark_done()
	_sound("done")
	_hold = num("done_hold_s", 1.2)


## The lesson now skipped (kept as skipped, unless it was done before: the next run goes past it), the next at once.
func skip() -> void:
	var l := current()
	if l.is_empty():
		return
	if _hold <= 0.0:
		if state_of(scheme, element, l) == "":
			mark(scheme, element, l, "skipped")
		skipped.append(String(l.id))
	_next()


## The next lesson: in a replay the next in order; else the next not yet done or skipped (a resumed run goes past them).
func _next() -> void:
	_hold = -1.0
	at += 1
	while not _replay and at < list.size() and state_of(scheme, element, list[at]) != "":
		at += 1
	if at >= list.size():
		_finish()
	else:
		_begin()


func _finish() -> void:
	finished = true
	at = list.size()
	if mode != null:
		mode.dummy = "stand"
	card.show_finished(word("finished_kicker"), word("finished"))
	_sound("finished")
	_fin_t = num("finished_s", 5.0)


func _sound(key: String) -> void:
	var s: Variant = (data().get("sounds", {}) as Dictionary).get(key)
	if not (s is Array) or (s as Array).size() < 3 or not Sfx.has(StringName(String(s[0]))):
		return
	Sfx.play_2d(StringName(String(s[0])), float(s[1]), float(s[2]))
