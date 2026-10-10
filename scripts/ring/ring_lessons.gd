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
## ROUND 3, the % ring (smash_r3 spec §11.2; only under its rules: rules_now() "stock"; the classic ring's run is unchanged):
##   the cards    lessons.json's "rules" keeps a card to its rule set (the zones' cards classic only, the six core cards
##                and the three more stock only); the guard and catch cards take stock_by's line (round 2's guard card in
##                the % ring's words); the String card its element's line (element_lines: earth keeps the Pop's stone and
##                throws it with E, the others right-click their 1). A card may set each side's % (dummy_pct, player_pct:
##                RingRules.reset_pct) and a place (player_off: you put off an end; dummy_near_end). Each done by doing it,
##                heard from RingRules (pct_changed, ko, launched: string_hits, last_steer_deg) and the player's RingMoves
##                (moved: double_jump, dodge, grab, climb, ledge_jump, ledge_roll, ledge_attack)
##   the hints    ONE hint queue (HintQueue; lessons.json hint_queue) on the same card's place, in a % ring match or a
##                practice without the cards (ensure_hints, from RingPractice.arm): at most one every gap_s; the edge and
##                recovery hints always shown at once (they pre-empt); the stale-move hint only after the first fall; each
##                once a match; none while a first match's key hints stand (FirstHints: one hint system at a time, the UI
##                audit 2026-10-09): they wait in the queue until the key hints are gone

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
## Round 3: only the hint queue (a % ring match, a practice without the cards: ensure_hints), and the queue.
var hints_only := false
var hints: HintQueue
var _hint_until := -1.0
var _r3_rules: RingRules = null
var _r3_moves: RingMoves = null
var _steer_at := -1.0
var _placed := false
var _off_seen := false


## Round 3's one hint queue: at most one hint every gap_s; those in pre_empt shown at once; those in after_fall only after the
## first fall; each once.
class HintQueue:
	extends RefCounted
	var gap_s := 20.0
	var pre_empt: Array = []
	var after_fall: Array = []
	var seen := {}
	var waiting: Array = []
	var shown_at := -INF
	var current := ""
	var falls := 0
	## [[id, at]] in order (the tests).
	var shown: Array = []

	func _init(d: Dictionary = {}) -> void:
		gap_s = float(d.get("gap_s", 20.0))
		pre_empt = d.get("pre_empt", ["edge", "recover"])
		after_fall = d.get("after_fall", ["stale"])

	## Hint `id` asked for (once ever, and not twice in the line).
	func push(id: String) -> void:
		if seen.has(id) or id in waiting:
			return
		waiting.append(id)

	## The hint to show now ("" none): a pre-empting one at once, else one when gap_s has passed (an after-fall one only
	## after the first fall).
	func next(now: float) -> String:
		for id: String in waiting:
			if id in pre_empt:
				return _take(id, now)
		if now - shown_at < gap_s:
			return ""
		for id: String in waiting:
			if id in after_fall and falls == 0:
				continue
			return _take(id, now)
		return ""

	func _take(id: String, now: float) -> String:
		waiting.erase(id)
		seen[id] = true
		shown_at = now
		current = id
		shown.append([id, now])
		return id


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


## Round 3: the hint queue over a % ring match or a practice without the cards (RingPractice.arm at each go): the lessons'
## node in hints_only (the one system), once; null outside the % ring.
static func ensure_hints(m: RingMode) -> RingLessons:
	if m == null or not m.is_inside_tree() or not RingRules.stock_on():
		return null
	var had := find(m.get_tree())
	if had != null:
		return had
	var l := RingLessons.new()
	l.name = NODE_NAME
	l.mode = m
	l.hints_only = true
	m.add_child(l)
	return l


## The rule set the cards are for: the ring's (RingRules.stock_on()) inside one, else the menu's (MatchSetup.rule_set()).
static func rules_now() -> String:
	if RingRules.current() != null:
		return "stock" if RingRules.stock_on() else "classic"
	return MatchSetup.rule_set()


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
	var rs := rules_now()
	# (round 4 SIMPLE: under the Basic controls the Basics track only (its cards' schemes: ["basic"]), else never it)
	var basics := MatchSetup.basic()
	for l: Dictionary in data().get("lessons", []):
		if (String(l.get("track", "")) == "basics") != basics:
			continue
		if l.has("schemes") and not KitWords.scheme_id(sch) in (l.schemes as Array) and not basics:
			continue
		if l.has("rules") and not rs in (l.rules as Array):
			continue
		if l.has("elements") and not el in (l.elements as Array):
			continue
		out.append(l)
	return out


## Lesson `l`'s line and its completion under `sch`: {line, do}.
static func by_of(l: Dictionary, sch: String) -> Dictionary:
	var by: Dictionary = l.get("by", {})
	if l.has("stock_by") and rules_now() == "stock":
		by = l.stock_by
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
	hints = HintQueue.new(data().get("hint_queue", {}))
	if hints_only:
		finished = true
		return
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
	_stock_set(l)
	_spec = line_spec(l)
	card.show_lesson(at + 1, list.size(), String(l.get("title", "")), _spec, word("skip"))


## Round 3: a card's % for each side (dummy_pct, player_pct: RingRules.reset_pct) and its place (player_off: the player put
## place_m out from his end and place_below_m under the lip, facing the deck; dummy_near_end: the dummy place_m in from its
## end).
func _stock_set(l: Dictionary) -> void:
	_placed = false
	_steer_at = -1.0
	if mode == null or not RingRules.stock_on():
		return
	var r := RingRules.current()
	if r != null and l.has("dummy_pct") and mode.foe != null and is_instance_valid(mode.foe):
		r.reset_pct(mode.foe, float(l.dummy_pct))
	if r != null and l.has("player_pct") and mode.player != null and is_instance_valid(mode.player):
		r.reset_pct(mode.player, float(l.player_pct))
	var a := mode.ring
	match String(l.get("place", "")):
		"player_off":
			if a != null and mode.player != null:
				var sgn := signf(mode.ring.spawn(mode.player_end).origin.x - a.global_position.x)
				mode.practice_ctl.place_at(mode.player, sgn if sgn != 0.0 else -1.0, float(l.get("place_m", 4.0)),
						float(l.get("place_below_m", 0.5)), 0.0)
				_placed = true
		"dummy_near_end":
			if a != null and mode.foe != null and is_instance_valid(mode.foe):
				var sgn2 := signf(mode.ring.spawn(1 - mode.player_end).origin.x - a.global_position.x)
				var p := a.to_global(Vector3((sgn2 if sgn2 != 0.0 else 1.0) * (a.half_l() - float(l.get("place_m", 6.0))), 0.0, 0.0))
				p.y = a.lip_y()
				RingLevel.place(mode.foe, Transform3D(Basis.looking_at(NpcRingMind.flat_dir(p, a.global_position), Vector3.UP), p))


## The dummy as lesson `l` wants it ({}: standing, its own throw at its own pace): its way, slow throws through the guard
## drill and the jump, the card's own throw where it names one.
func _dummy_way(l: Dictionary) -> void:
	if mode == null:
		return
	var way := String(l.get("dummy", "stand"))
	mode.dummy = way if way in mode.practice_ctl.ways() else "stand"
	mode.slow_throws = bool(l.get("slow", false))
	mode.throw_override = throw_of(l)
	if mode.dummy == "throw":
		_clear_own_walls()
	if RingRules.stock_on():
		mode.practice_ctl._tell_way()            # (round 3: the bot told its way; the recover drill's dummy off an end)
		if mode.dummy == "recover" and mode.foe != null and is_instance_valid(mode.foe):
			mode.practice_ctl.place_off(mode.foe)


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
	var el_lines: Dictionary = l.get("element_lines", {})
	if el_lines.has(element) and rules_now() == "stock":
		t = String(el_lines[element])           # (round 3: the String card's own line for earth)
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
	if hints_only:
		_hook_r3()
		_hint_step()
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
		"pct":
			var r := RingRules.current()
			if r != null and mode.foe != null and is_instance_valid(mode.foe) and r.pct_of(mode.foe) >= float(current().get("do_pct", 40.0)):
				complete()
		"back":
			var p2 := mode.player
			if p2 != null and is_instance_valid(p2) and p2.is_on_floor() and not _off_deck(p2) and _placed:
				complete()
		"steer":
			var r2 := RingRules.current()
			if _steer_at > 0.0 and BendStatus.now() >= _steer_at and r2 != null:
				_steer_at = -1.0
				var most := RingRules.stock_num("di_deg", 15.0)
				if absf(r2.last_steer_deg(mode.player)) >= most * num("steer_frac", 0.5):
					complete()
		"jump":
			var p := mode.player
			if InputMap.has_action(&"jump") and Input.is_action_just_pressed(&"jump"):
				_jumped = true
			if _jumped and p != null and is_instance_valid(p) and not p.is_on_floor() and p.velocity.y > 0.5:
				complete()


## Round 3: the rules' signals and the player's RingMoves.moved heard (once each).
func _hook_r3() -> void:
	if not RingRules.stock_on():
		return
	var r := RingRules.current()
	if r != null and r != _r3_rules:
		_r3_rules = r
		r.pct_changed.connect(_on_pct)
		r.ko.connect(_on_ko)
		r.launched.connect(_on_launched)
	var m := RingMoves.of(mode.player) if mode.player != null and is_instance_valid(mode.player) else null
	if m != null and m != _r3_moves:
		_r3_moves = m
		m.moved.connect(_on_moved)


## Whether `b` is over the water (RingMoves', else the deck's rectangle).
func _off_deck(b: Node3D) -> bool:
	var m := RingMoves.of(b)
	if m != null:
		return m.off_deck()
	var a := mode.ring
	return a != null and (float(a.nearest_lip(b.global_position).out_m) > 0.0 or b.global_position.y < a.lip_y() - 0.3)


func _on_pct(b: Node3D, pct: float, _delta: float) -> void:
	if b == mode.foe and current_do() == "pct" and pct >= float(current().get("do_pct", 40.0)) and _hold < 0.0 and not finished:
		complete()


func _on_ko(b: Node3D, _by: Node, _pct: float, _tag: String, _left: int) -> void:
	hints.falls += 1
	if b == mode.foe and current_do() in ["out", "keep_off"] and _hold < 0.0 and not finished:
		complete()


func _on_launched(b: Node3D, v: Vector3, _s: float, by: Node, tag: String) -> void:
	var r := RingRules.current()
	if b == mode.player:
		if v.length() >= float((data().get("hint_queue", {}) as Dictionary).get("thrown_mps", 10.0)):
			hints.push("steer")
		if current_do() == "steer":
			_steer_at = BendStatus.now() + 0.15        # (the steer is read at 0.1 s)
	elif b == mode.foe and by == mode.player:
		if r != null and r.stale_count(mode.player, tag) >= int((data().get("hint_queue", {}) as Dictionary).get("stale_n", 2)):
			hints.push("stale")
		if current_do() == "string" and r != null and r.string_hits(b) >= int(num("string_n", 3.0)) and _hold < 0.0 and not finished:
			complete()


func _on_moved(kind: String) -> void:
	if kind == "grab":
		hints.push("edge")
	if finished or _hold > 0.0 or hints_only:
		return
	match current_do():
		"double_jump":
			if kind == "double_jump":
				complete()
		"air_dodge":
			if kind == "dodge":
				complete()
		"edge":
			if kind in ["climb", "ledge_jump", "ledge_roll", "ledge_attack"]:
				complete()
		"back":
			if kind in ["grab", "scramble"]:
				complete()


## The hint queue's frame (a % ring match): what the player's body shows pushed (off the deck: recover; lying: break_fall),
## the next hint shown on the card for show_s.
func _hint_step() -> void:
	var p := mode.player
	if p == null or not is_instance_valid(p):
		return
	if not _off_seen and _off_deck(p) and not p.is_on_floor():
		_off_seen = true
		hints.push("recover")
	var kn := BendKnock.peek(p)
	if kn != null and kn.lying_t > 0.0:
		hints.push("break_fall")
	var now := BendStatus.now()
	if FirstHints.find(get_tree()) != null:
		# (a first match's key hints up: the hints wait in the queue, and a card already up goes)
		if _hint_until > 0.0:
			_hint_until = -1.0
			card.hide_card()
		return
	var id := hints.next(now)
	var hq: Dictionary = data().get("hint_queue", {})
	if id != "":
		var hl := String((hq.get("lines", {}) as Dictionary).get(id, id))
		if MatchSetup.basic():
			# (round 4 SIMPLE: under the Basic controls the hints say Basic's keys: lessons.json basics_hints)
			hl = String((data().get("basics_hints", {}) as Dictionary).get(id, hl))
		card.show_hint(String(hq.get("kicker", word("hint_kicker"))), hl)
		_hint_until = now + float(hq.get("show_s", 6.0))
	elif _hint_until > 0.0 and now >= _hint_until:
		_hint_until = -1.0
		card.hide_card()


## The player's caster hooked (again after a reset made it anew).
func _hook() -> void:
	_hook_r3()
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
		"guarded":
			complete()                           # (round 4 SIMPLE's Basics: any guard that took one, on the beat or late)
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
