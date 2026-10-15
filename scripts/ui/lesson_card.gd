class_name LessonCard
extends CanvasLayer
## A lesson's card in Tidebreak's practice (RingLessons; the owner, 2026-10-05: switching moves was hard and nothing taught
## the controls): one line at a time at the right of the screen, out of the way of the crosshair, the dummy, the HUD's strip
## and the first-time panel (HowTo, top left). The keys in the line are drawn as caps (HowToKey: a key, or the mouse with its
## button) and light while held; the line wraps word by word. A done lesson turns the bar and its kicker green.
##   show_lesson(n, total, title, spec)   "LESSON 3 OF 11 · SWITCH YOUR MOVE", the line, the skip line under it
##   mark_done()                          the bar and kicker green, "Done"
##   show_finished(kicker, spec)          the last card (no skip line); hide_card() fades it out
##   shown_text()                         the line as shown, each cap as [its label] (tests)
## The specs: text with [action] tokens (resolve(): each the action's first binding now, from InputMap: "W", "Tab", "RMB",
## "Wheel"; so the line is right whatever the player rebound; a token that is no action is drawn as written). FirstHints
## builds its rows with the same statics (glyph, resolve, fill).

const FADE_S := 0.3
const DONE_GREEN := Color(0.55, 0.82, 0.45)
const GOLD := Color(0.95, 0.74, 0.36)
const INK := Color(0.97, 0.94, 0.87)
const DIM := Color(0.8, 0.77, 0.7)
## A cap's text for each mouse button (HowToKey draws these as the mouse).
const MOUSE_GLYPHS := {MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_MIDDLE: "MMB",
		MOUSE_BUTTON_WHEEL_UP: "Wheel", MOUSE_BUTTON_WHEEL_DOWN: "Wheel"}

var _s := 1.0
var _panel: PanelContainer
var _bar: ColorRect
var _kicker: Label
var _line: HFlowContainer
var _foot: HFlowContainer
var _sans: SystemFont
var _sans_b: SystemFont
## glyph -> the actions it stands for in the line now (the caps light while one is held).
var _acts := {}
## The caps in the line and the skip line now (fill's), redrawn each frame to light while held.
var _caps: Array[HowToKey] = []
var _shown := ""
var _a := 0.0
var _want := 0.0
var done := false


static func install(parent: Node) -> LessonCard:
	var c := LessonCard.new()
	c.name = "LessonCard"
	parent.add_child(c)
	return c


func _ready() -> void:
	layer = 13
	_build()


# --- the keys as the player has them --------------------------------------------------------------------------------

## Action `a`'s first binding as a cap's label: a key's name ("W", "Tab", "Enter", "1"), "LMB" / "RMB" / "MMB" / "Wheel" for
## the mouse; a pad's button while a pad plays (PadInput.active); "" when it has none (unbound, or no such action).
static func glyph(a: StringName) -> String:
	if not InputMap.has_action(a):
		return ""
	if PadInput.active:
		var pn := PadInput.button_name(a)       # (a pad playing: its button, "LT", "D-pad up": PadInput)
		if pn != "":
			return pn
	for e in InputMap.action_get_events(a):
		var k := e as InputEventKey
		if k != null:
			var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
			return OS.get_keycode_string(code)
		var mb := e as InputEventMouseButton
		if mb != null:
			return String(MOUSE_GLYPHS.get(mb.button_index, mb.as_text()))
		if e != null:
			return e.as_text()
	return ""


## `spec` with each [action] turned into [its glyph] (an action with no binding: "(no key)"; a token that is no action is
## kept as written): {text, acts: {glyph: [actions]}}.
static func resolve(spec: String) -> Dictionary:
	var acts := {}
	var re := RegEx.create_from_string("\\[([^\\]]+)\\]")
	var out := ""
	var at := 0
	for m in re.search_all(spec):
		out += spec.substr(at, m.get_start() - at)
		var tok := m.get_string(1)
		var g := tok
		if InputMap.has_action(StringName(tok)):
			g = glyph(StringName(tok))
			if g == "":
				g = "(no key)"
			var l: Array = acts.get(g, [])
			if not l.has(StringName(tok)):
				l.append(StringName(tok))
			acts[g] = l
		out += "[%s]" % g if not g.begins_with("(") else g
		at = m.get_end()
	out += spec.substr(at)
	return {"text": out, "acts": acts}


## The resolved `text` laid into `flow` as words (Labels) and caps (HowToKey for each [glyph]), at scale `s`; a word
## that follows a cap with no space ("[Q]:", "[LMB].") kept with it, so the line never breaks or gaps between them. The caps
## made, returned (their owner redraws just those each frame, as HowTo keeps its own: no walk of the tree a frame).
static func fill(flow: Container, text: String, s: float, font: Font, bold: Font, color: Color, size: int, lit: Callable) -> Array[HowToKey]:
	for c in flow.get_children():
		flow.remove_child(c)
		c.queue_free()
	var caps: Array[HowToKey] = []
	var re := RegEx.create_from_string("\\[([^\\]]+)\\]")
	var at := 0
	for m in re.search_all(text):
		var before := text.substr(at, m.get_start() - at)
		_words(flow, before, s, font, color, size)
		var cap := HowToKey.new(m.get_string(1), lit, s, bold)
		caps.append(cap)
		at = m.get_end()
		var tail := ""
		while at < text.length() and text[at] != " " and text[at] != "[":
			tail += text[at]
			at += 1
		if tail == "":
			flow.add_child(cap)
			continue
		var glue := HBoxContainer.new()
		glue.add_theme_constant_override("separation", maxi(1, int(2 * s)))
		glue.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glue.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		glue.add_child(cap)
		_words(glue, tail, s, font, color, size)
		flow.add_child(glue)
	_words(flow, text.substr(at), s, font, color, size)
	return caps


static func _words(flow: Container, t: String, s: float, font: Font, color: Color, size: int) -> void:
	for w in t.split(" ", false):
		var l := text_label(font, int(size * s), color)
		l.text = w
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		flow.add_child(l)


static func text_label(font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_x", maxi(1, size / 16))
	l.add_theme_constant_override("shadow_offset_y", maxi(1, size / 16))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## The sans faces the cards and hints use (HowTo's).
static func sans(weight: int) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Avenir Next", "Helvetica Neue", "Arial", "sans-serif"])
	f.font_weight = weight
	return f


# --- the card ---------------------------------------------------------------------------------------------------------

func show_lesson(n: int, total: int, title: String, spec: String, skip_spec := "") -> void:
	done = false
	_kicker.text = "%s   ·   %s" % [String(RingLessons.word("kicker")) % [n, total], title.to_upper()]
	_kicker.add_theme_color_override("font_color", GOLD)
	_bar.color = GOLD
	_set_line(spec, skip_spec)
	_want = 1.0


func mark_done() -> void:
	done = true
	_kicker.text = RingLessons.word("done").to_upper() + "   ·   " + _kicker.text.get_slice("·", _kicker.text.count("·")).strip_edges()
	_kicker.add_theme_color_override("font_color", DONE_GREEN)
	_bar.color = DONE_GREEN
	_line.modulate.a = 0.6


func show_finished(kicker: String, spec: String) -> void:
	done = true
	_kicker.text = kicker
	_kicker.add_theme_color_override("font_color", DONE_GREEN)
	_bar.color = DONE_GREEN
	_set_line(spec, "")
	_want = 1.0


## Round 3: a hint of the % ring's hint queue on the card's place (RingLessons.HintQueue): its kicker in gold, the line.
func show_hint(kicker: String, spec: String) -> void:
	done = false
	_kicker.text = kicker
	_kicker.add_theme_color_override("font_color", GOLD)
	_bar.color = GOLD
	_set_line(spec, "")
	_want = 1.0


func hide_card() -> void:
	_want = 0.0


func is_showing() -> bool:
	return _want > 0.0


## The line as shown, each cap as [its label] (the tests read the keys in it).
func shown_text() -> String:
	return _shown


func kicker_text() -> String:
	return _kicker.text


func _set_line(spec: String, skip_spec: String) -> void:
	var r := resolve(spec)
	_acts = r.acts
	_shown = String(r.text)
	_caps = fill(_line, _shown, _s, _sans, _sans_b, INK, 26, _lit)
	_line.modulate.a = 1.0
	_foot.visible = skip_spec != ""
	if skip_spec != "":
		var f := resolve(skip_spec)
		(_acts as Dictionary).merge(f.acts)
		_caps.append_array(fill(_foot, String(f.text), _s * 0.62, _sans, _sans_b, DIM, 26, _lit))


func _lit(label: String) -> bool:
	for a: StringName in _acts.get(label, []):
		if InputMap.has_action(a) and Input.is_action_pressed(a):
			return true
	return false


func _process(dt: float) -> void:
	_a = move_toward(_a, _want, dt / FADE_S)
	_panel.modulate.a = _a
	_panel.visible = _a > 0.001
	if not _panel.visible:
		return
	var vp := get_viewport().get_visible_rect().size
	_panel.reset_size()
	# (under the plates down the right when they reach lower: a team format's stack; RingRules' PercentBar.right_bottom)
	var y := vp.y * 0.24
	if PercentBar.right_bottom >= 0.0:
		y = maxf(y, PercentBar.right_bottom + 14.0 * _s)
	_panel.position = Vector2(vp.x - _panel.size.x - 36.0 * _s, minf(y, vp.y - _panel.size.y - 140.0 * _s))
	for c in _caps:
		if is_instance_valid(c):
			c.queue_redraw()


func _build() -> void:
	_s = maxf(get_viewport().get_visible_rect().size.y / 1080.0, 0.6)
	var s := _s
	_sans = sans(500)
	_sans_b = sans(700)
	_panel = PanelContainer.new()
	_panel.name = "Card"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.035, 0.04, 0.66)
	sb.set_corner_radius_all(int(8 * s))
	sb.content_margin_left = 26 * s
	sb.content_margin_right = 26 * s
	sb.content_margin_top = 16 * s
	sb.content_margin_bottom = 18 * s
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(16 * s))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)
	_bar = ColorRect.new()
	_bar.color = GOLD
	_bar.custom_minimum_size = Vector2(4 * s, 0)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_bar)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(10 * s))
	vb.custom_minimum_size = Vector2(600 * s, 0)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(vb)
	_kicker = text_label(_sans_b, int(17 * s), GOLD)
	vb.add_child(_kicker)
	_line = HFlowContainer.new()
	_line.name = "Line"
	_line.add_theme_constant_override("h_separation", int(8 * s))
	_line.add_theme_constant_override("v_separation", int(6 * s))
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_line)
	_foot = HFlowContainer.new()
	_foot.name = "Skip"
	_foot.add_theme_constant_override("h_separation", int(6 * s))
	_foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_foot)
