class_name FirstHints
extends CanvasLayer
## A first Quick match's key hints (the owner, 2026-10-05: switching moves was hard, nothing taught the keys): small rows at
## the top left with the keys of the player's control scheme as he has them bound (data/ring/lessons.json "hints": keys,
## first_moves, direction, radial; each [action] its binding now, LessonCard.resolve), each fading once one of its actions is
## pressed; when all have gone (or the match is over) they are turned off for good. They REPLACE the ring's first-time panel
## (HowTo; the owner, 2026-10-05: not stacked under it): as they come up the ring's topics count as seen and one up goes
## (HowTo.yield_to_hints), and none comes up while they stand. Nothing is drawn on or near the opponent.
##   on() / set_on(v)     GameSettings' "hints" section, key key_hints (on until a first Quick match has shown them); the
##                        ring's Esc menu's row (RingMenu) turns them on or off: on, they show at once in the match under way
##   install(mode, now)   RingMode's (a Quick match with them on; null otherwise), the menu's (now: whatever the match)
##   rows_left()          the rows not yet used (the tests)
## Round 3: a row with "rules" shows only under those rule sets (RingLessons.rules_now(): the % ring's "[jump] twice ·
## [weapon_3] in the air").
## Off when a script drives the game (the tests, the films) unless FirstHints.force or the user arg hints=on.

const SECTION := "hints"
const KEY := "key_hints"
const NODE_NAME := "FirstHints"
const GROUP := &"first_hints"
const FADE_S := 0.6

## Tests: shown in a script run too.
static var force := false

var mode: RingMode
var scheme := ""
## Per row: {box, caps (its HowToKeys, redrawn each frame), uses: [StringName], used, a}.
var rows: Array = []
var _panel: PanelContainer
var _vb: VBoxContainer
var _s := 1.0
var _sans: SystemFont
var _sans_b: SystemFont
var _acts := {}
var _closing := false
var _a := 0.0


## Whether the hints are on (GameSettings' hints section; on until a first Quick match has shown them).
static func on() -> bool:
	var cf := ConfigFile.new()
	cf.load(GameSettings.file())
	return bool(cf.get_value(SECTION, KEY, true))


static func set_on(v: bool) -> void:
	GameSettings.set_value(SECTION, KEY, v)


## The Esc menu's row: "Key hints:  on".
static func row_text() -> String:
	return String(_hints_data().get("row", "Key hints:  %s")) % ("on" if on() else "off")


static func row_line() -> String:
	return String(_hints_data().get("row_line", ""))


static func _hints_data() -> Dictionary:
	return RingLessons.data().get("hints", {})


## A Quick match (not a practice) with the hints on, and the game not driven by a script (unless asked).
static func wanted(m: RingMode) -> bool:
	return m != null and MatchSetup.quick and not MatchSetup.practice() and on() and _allowed(m)


static func _allowed(m: Node) -> bool:
	return force or "hints=on" in OS.get_cmdline_user_args() or m.get_tree().get_script() == null


## The hints over match `m` (null when not wanted; `now`: the Esc menu turned them on, whatever the match). One at a time.
static func install(m: RingMode, now := false) -> FirstHints:
	if m == null or not m.is_inside_tree():
		return null
	var had := find(m.get_tree())
	if had != null:
		return had
	if not (wanted(m) or (now and _allowed(m))):
		return null
	var h := FirstHints.new()
	h.name = NODE_NAME
	h.mode = m
	m.add_child(h)
	return h


static func find(tree: SceneTree) -> FirstHints:
	return tree.get_first_node_in_group(GROUP) as FirstHints if tree != null else null


func _ready() -> void:
	add_to_group(GROUP)
	layer = 12
	KitWords.ensure_guard_action()          # (the guard's row names its key)
	_build()
	_lay()
	var ht := _how_to()
	if ht != null:
		ht.yield_to_hints()
	if mode != null:
		mode.match_over.connect(func(_w: int) -> void: close())


## The rows not yet used.
func rows_left() -> int:
	var n := 0
	for r: Dictionary in rows:
		if not bool(r.used):
			n += 1
	return n


## Gone for good: turned off (the Esc menu's row says so), faded out.
func close() -> void:
	if _closing:
		return
	_closing = true
	set_on(false)


## The rows for the scheme now (again when it changes).
func _lay() -> void:
	scheme = MatchSetup.scheme()
	for c in _vb.get_children():
		if c.name != "Kicker":
			_vb.remove_child(c)
			c.queue_free()
	rows.clear()
	_acts.clear()
	var rs := RingLessons.rules_now()
	for h: Dictionary in _hints_data().get(KitWords.scheme_id(scheme), []):
		if h.has("rules") and not rs in (h.rules as Array):
			continue                             # (round 3: a row for one rule set only: the % ring's "[jump] twice")
		var r := LessonCard.resolve(String(h.get("line", "")))
		_acts.merge(r.acts)
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", int(6 * _s))
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var caps := LessonCard.fill(box, String(r.text), _s * 0.85, _sans, _sans_b, LessonCard.INK, 24, _lit)
		_vb.add_child(box)
		var uses: Array = []
		for u in h.get("uses", []):
			uses.append(StringName(String(u)))
		rows.append({"box": box, "caps": caps, "uses": uses, "used": false, "a": 1.0})


func _lit(label: String) -> bool:
	for a: StringName in _acts.get(label, []):
		if InputMap.has_action(a) and Input.is_action_pressed(a):
			return true
	return false


func _input(e: InputEvent) -> void:
	if e.is_echo() or not e.is_pressed() or _closing:
		return
	for r: Dictionary in rows:
		if bool(r.used):
			continue
		for a: StringName in r.uses:
			if InputMap.has_action(a) and e.is_action_pressed(a):
				r.used = true
				break


func _process(dt: float) -> void:
	if MatchSetup.scheme() != scheme and not _closing:
		_lay()
	var left := 0
	for r: Dictionary in rows:
		var box := r.box as Control
		if bool(r.used):
			r.a = move_toward(float(r.a), 0.0, dt / FADE_S)
			box.modulate.a = float(r.a)
			box.visible = float(r.a) > 0.001
		else:
			left += 1
		for c in r.caps:
			if is_instance_valid(c) and box.visible:
				(c as HowToKey).queue_redraw()
	if left == 0 and not rows.is_empty():
		close()                                  # (every key used: the first match's hints are done)
	_a = move_toward(_a, 0.0 if _closing else 1.0, dt / FADE_S)
	_panel.modulate.a = _a
	_panel.reset_size()
	if _closing and _a <= 0.0:
		queue_free()
		return
	# (the first-time panel's place, top left: it gave way as these came up)
	_panel.position = Vector2(36.0 * _s, 36.0 * _s)


## The player's first-time panel (HowTo), if he has one.
func _how_to() -> HowTo:
	var p: Node = mode.player if mode != null else null
	return p.get_node_or_null(^"HowTo") as HowTo if p != null and is_instance_valid(p) else null


func _build() -> void:
	_s = maxf(get_viewport().get_visible_rect().size.y / 1080.0, 0.6)
	var s := _s
	_sans = LessonCard.sans(500)
	_sans_b = LessonCard.sans(700)
	_panel = PanelContainer.new()
	_panel.name = "Hints"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.035, 0.04, 0.42)
	sb.set_corner_radius_all(int(6 * s))
	sb.border_width_left = int(3 * s)
	sb.border_color = Color(0.85, 0.62, 0.3, 0.8)
	sb.content_margin_left = 14 * s
	sb.content_margin_right = 16 * s
	sb.content_margin_top = 8 * s
	sb.content_margin_bottom = 10 * s
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.modulate.a = 0.0
	add_child(_panel)
	_vb = VBoxContainer.new()
	_vb.add_theme_constant_override("separation", int(5 * s))
	_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_vb)
	var k := LessonCard.text_label(_sans_b, int(15 * s), LessonCard.GOLD)
	k.name = "Kicker"
	k.text = String(_hints_data().get("kicker", "YOUR KEYS"))
	_vb.add_child(k)
