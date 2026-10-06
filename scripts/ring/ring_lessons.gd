class_name RingLessons
extends Node
## TIDEBREAK'S LESSONS in Practice (the owner, 2026-10-05, after playing: "still difficult for a human to switch spells,
## there's a lot of things going on"; nothing in the game taught the controls): a short run of cards (LessonCard, one line
## each) over a practice against a dummy, each done by DOING it, never by reading it. Every word and rule in
## data/ring/lessons.json; the keys in a line are the actions' bindings now (LessonCard.resolve), and the line is the one for
## the player's control scheme (KitWords.scheme_id: keys, first_moves, direction, radial) and element, so it is always right.
## Round 2 of the skills (skills_r2 spec §9; the same buttons for every element, KitWords):
##   the run      move (walk a few steps), jab (a click of the left button), strike (key 1, held and let go; let go early and
##                nothing is spent; fire's grows into the Fireball), push ▲ (key 2, held past the second click it grows), dash
##                (key 3), wall (key 4, where you aim; two each), then the guard drill against the practice dummy's throws on
##                E (earth: catch it and throw it back with E again; water Turn, fire Parry, air Wind Guard: on the beat), fire
##                along the floor (jump it; a fire player's dummy kicks it along the deck), the quick spell (Q, then a cast
##                from LMB), heal (5), the zones (the dummy knocked back a zone) and the water (it knocked in). Done: the card
##                goes green, a click, the next after done_hold_s
##   listened     SwayCaster's cast (the move, its variation, the button: lock_src); RingMode's knocked_back and rang_out;
##                the player's guards' results (BendCaster.guarded, round 2's CORE: perfect, late, whiff; the water, fire
##                and air drills are done only on the beat, earth's by a stone caught, perfect or late, then thrown back);
##                the bind key and the jump pressed
##   the dummy    the practice's (RingMode.dummy): it stands through the lessons and throws through the guard drill and the
##                jump (lessons.json dummy per lesson), SLOWLY there (slow: RingMode.slow_throws; the owner's answer to round
##                1: a beginner's time to read the throw and guard on the beat), its throw the card's own where it names one
##                (throws: a fire player's dummy kicks fire along the deck); its element the player's own (lessons.json
##                "dummy": each guard drilled against its own element's strike)
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
var _quick_bound := false
var _guarded := false              ## a guard of the player's took something this lesson (perfect or late)
var _caught := false                ## the earth drill: a stone of its caught (the throw back is next)
var _jumped := false                ## the jump pressed during the card (a jump off the deck does it)
var _caster: SwayCaster
var _guard_caster: BendCaster
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


## The dummy's element for a player of element `el` (his own: each guard drilled against its own element's strike).
static func dummy_for(el: String) -> String:
	var d := String((data().get("dummy", {}) as Dictionary).get(el, el))
	return d if d in Bending.ELEMENTS else el


## The lessons for `sch` and `el`, in order (those only for other schemes or elements left out).
static func lessons_for(sch: String, el: String) -> Array:
	var out: Array = []
	for l: Dictionary in data().get("lessons", []):
		if l.has("schemes") and not KitWords.scheme_id(sch) in (l.schemes as Array):
			continue
		if l.has("elements") and not el in (l.elements as Array):
			continue
		out.append(l)
	return out


## Lesson `l`'s line and its completion under `sch`: {line, do}.
static func by_of(l: Dictionary, sch: String) -> Dictionary:
	var by: Dictionary = l.get("by", {})
	return by.get(KitWords.scheme_id(sch), by.get("*", {}))


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


## The skip key (Enter) and the guard's (E), made when missing (the player may rebind them).
static func _ensure_keys() -> void:
	KitWords.ensure_guard_action()
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
		_dummy_way({})
		return
	if _replay:
		at = 0
	_begin()


func current() -> Dictionary:
	return list[at] if at >= 0 and at < list.size() else {}


func current_id() -> String:
	return String(current().get("id", ""))


## What the lesson now waits for ("walk", "cast", "guard" ...; "" none).
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
	_quick_bound = false
	_jumped = false
	_caught = false
	_guarded = false
	_dummy_way(l)
	_spec = line_spec(l)
	card.show_lesson(at + 1, list.size(), String(l.get("title", "")), _spec, word("skip"))


## The dummy as lesson `l` wants it ({}: standing, its own throw at its own pace): its way, slow throws through the guard
## drill and the jump, the card's own throw where it names one.
func _dummy_way(l: Dictionary) -> void:
	if mode == null:
		return
	var way := String(l.get("dummy", "stand"))
	mode.dummy = way if way in MatchSetup.DUMMIES else "stand"
	mode.slow_throws = bool(l.get("slow", false))
	mode.throw_override = throw_of(l)
	if mode.dummy == "throw":
		_clear_own_walls()


## The player's own walls taken down as a drill against the dummy's throws begins: the Wall card's walls stand 2-6 m before
## him, in the throws' way (the merge gate: the earth catch drill's stones all struck his own wall and none came to be caught).
func _clear_own_walls() -> void:
	var p := mode.player
	if p == null or not is_instance_valid(p) or not is_inside_tree():
		return
	var id := p.get_instance_id()
	for n in get_tree().get_nodes_in_group(FormRaised.GROUP):
		var w := n as FormRaised
		if w != null and w.kind == "wall" and int(w.get_meta(&"bend_by", 0)) == id and w.state != FormRaised.State.CRUMBLING:
			w.crumble("lesson")
	for z in get_tree().get_nodes_in_group(BendZone.GROUP):
		var bz := z as BendZone
		if bz != null and bz.owner_node == p and bz.kind in ["fire_wall", "wind_wall"]:
			bz.end()


## The lesson's line as a spec for the card: its scheme's line with {press}, {name}, {jab}, {grow}, {what} and {thing} put in.
func line_spec(l: Dictionary) -> String:
	var t := String(by_of(l, scheme).get("line", ""))
	var role := String(l.get("role", ""))
	var rm := role_move(role) if role != "" else {}
	var id := String(rm.get("id", ""))
	var ew: Dictionary = (data().get("elements", {}) as Dictionary).get(element, {})
	var what := String(ew.get("dash_what", "")) if role == "dash" else String(ew.get("guard_what", ""))
	var jb := KitWords.jab(element)
	var gn := KitWords.grown_name(element, 0) if role == "strike" else ""
	t = t.replace("{press}", press_spec(rm)).replace("{name}", KitWords.move_name(id, String(rm.get("mode", ""))))
	t = t.replace("{jab}", KitWords.move_name(String(jb.get("id", "")), String(jb.get("mode", ""))))
	t = t.replace("{grow}", (".  " + KitWords.w("grow_into", "hold to grow it: %s") % gn) if gn != "" else "")
	return t.replace("{what}", what).replace("{thing}", String(ew.get("thing", "")))


## The move a lesson's `role` teaches for the element (the same buttons for every element, KitWords): {id, mode} ({} none):
## strike, push, dash, wall and heal the first move of keys 1-5; jab the left button's, guard E's.
func role_move(role: String) -> Dictionary:
	var keyed := {"strike": 0, "push": 1, "dash": 2, "wall": 3, "heal": 4}
	if keyed.has(role):
		var ms := KitWords.key_moves(element, int(keyed[role]))
		return ms[0] if not ms.is_empty() else {}
	match role:
		"jab":
			return KitWords.jab(element)
		"guard":
			return KitWords.guard(element)
	return {}


## The key(s) that ready move `rm` ({id, mode}): "[weapon_3]", "[weapon_3] twice" (the key's second move); the guard
## "[bend_guard]" (its own key: nothing to ready). Always the key, readied or not (round 2: a tap always readies the key's
## first move, so the key is the lesson).
func press_spec(rm: Dictionary) -> String:
	var id := String(rm.get("id", ""))
	if id == "":
		return ""
	var md := String(rm.get("mode", ""))
	if id == String(KitWords.guard(element).get("id", "")):
		return "[%s]" % KitWords.GUARD_ACTION
	var k := KitWords.key_of(element, id, md)
	if int(k.key) < 0:
		return ""
	var key := "[weapon_%d]" % (int(k.key) + 1)
	return key if int(k.at) == 0 else "%s %s" % [key, word("twice")]


## The dummy's throw through lesson `l` ("id/mode"; "" its element's strike): the card's for the player's element, when the
## move is one the game has.
func throw_of(l: Dictionary) -> String:
	var t := String((l.get("throws", {}) as Dictionary).get(element, ""))
	return t if t.contains("/") and not SwayMoves.move(t.get_slice("/", 0)).is_empty() else ""


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
		"jump":
			var p := mode.player
			if InputMap.has_action(&"jump") and Input.is_action_just_pressed(&"jump"):
				_jumped = true
			if _jumped and p != null and is_instance_valid(p) and not p.is_on_floor() and p.velocity.y > 0.5:
				complete()


## The player's caster hooked (again after a reset made it anew).
func _hook() -> void:
	var p := mode.player
	if p == null or not is_instance_valid(p):
		return
	var c := SwayCaster.of(p)
	if c != null and c != _caster:
		_caster = c
		c.cast.connect(_on_cast)
	var bc := BendCaster.of(p)
	if bc != null and bc != _guard_caster:
		_guard_caster = bc
		bc.guarded.connect(_on_guard_result)


## The line again when what it says has changed (a key pressed: "Readied", a key rebound).
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


## A guard of the player's told its result (BendCaster.guarded; BendZone's: perfect, late, whiff). The guard drill (water
## Turn, fire Parry, air Wind Guard) is done on the beat only; earth's (catch, then E again) by a stone caught, perfect or
## late: earth always catches stone.
func _on_guard_result(result: String, what: String) -> void:
	if mode == null or mode.phase != "FIGHT" or finished or _hold > 0.0 or result == "whiff":
		return
	_guarded = true
	match current_do():
		"guard":
			if result == "perfect":
				complete()
		"return":
			if what == "stone":
				_caught = true                   # (caught: now E again throws it back)


func _on_cast(m: String, _t: Node3D) -> void:
	if mode == null or mode.phase != "FIGHT" or finished or _hold > 0.0 or _caster == null:
		return
	var src := _caster.lock_src
	var md := _caster.mode_of(m)
	match current_do():
		"cast":
			if src != SwayCaster.SRC_QUICK and _is_role_move(m, md):
				complete()
		"jab":
			if src == SwayCaster.SRC_QUICK:
				complete()
		"quick":
			if src == SwayCaster.SRC_QUICK and _quick_bound:
				complete()
		"return":
			# (a stone caught, then sent back: E again, the guard cast again; or the push key, which throws what is held)
			if _caught and (m == String(KitWords.guard(element).get("id", "")) or m == String(role_move("push").get("id", ""))):
				complete()


## Whether a cast of `m` at `md` is the lesson's move (its mode too where its key holds two of the same move's).
func _is_role_move(m: String, md: String) -> bool:
	var want := role_move(String(current().get("role", "")))
	if want.is_empty():
		return true
	if String(want.id) != m:
		return false
	var k := KitWords.key_of(element, m)
	var ms := KitWords.key_moves(element, int(k.key)) if int(k.key) >= 0 else []
	var two_modes := ms.size() == 2 and String(ms[0].id) == String(ms[1].id)
	return not two_modes or String(want.get("mode", "")) == md


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
	if InputMap.has_action(&"jump") and e.is_action_pressed(&"jump"):
		_jumped = true
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
	_dummy_way({})
	card.show_finished(word("finished_kicker"), word("finished"))
	_sound("finished")
	_fin_t = num("finished_s", 5.0)


func _sound(key: String) -> void:
	var s: Variant = (data().get("sounds", {}) as Dictionary).get(key)
	if not (s is Array) or (s as Array).size() < 3:
		return
	var id := StringName(String(s[0]))
	if BendSounds.has(id):
		BendSounds.play(id, Vector3.INF, float(s[1]), float(s[2]))
	elif Sfx.has(id):
		Sfx.play_2d(id, float(s[1]), float(s[2]))
