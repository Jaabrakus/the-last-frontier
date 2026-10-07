class_name Callouts
extends CanvasLayer
## THE CALLOUTS (round 4 VIRAL): big short words on the player's own screen for the match's big moments, centred above the
## strip, one at a time. Every number and word in data/ring/callouts.json; the moments are RingHighlights' (moment signal).
##   the words    SPLASH! (a fall), CAUGHT! (an earth catch within 0.15 s), PERFECT! (a perfect guard), RISE! (a recovery
##                from the deepest third), CLASH! (two attacks meeting), COMEBACK! (a game won from two lives down), LAST LIFE
##                (sudden death, or every side on its last life). Each call's `who`: "mine" shows only the player's side's
##                moments, "any" either side's (with bots on both sides: all of them)
##   one at a time a call shows show_s; a higher priority one takes its place at once, a lower one waits (at most queue_n,
##                dropped when older than stale_s)
##   the look     the HUD's serif made bold and slanted, in the element's colour (the one whose moment it is) with a dark
##                outline, a scale punch (punch -> overshoot -> 1 over punch_s), a slight tilt, a streak behind it, a fade at
##                its end. Fixed on the screen: never on or over anyone
##   the switch   Esc "Callouts: On / Off" (GameSettings section "ring", key "callouts"; RingMenu's row from row_text())
## Only while RingRules.stock_on(). shown: every word shown (tests, the metric).

const NODE_NAME := "Callouts"
const GROUP := &"ring_callouts"
const DATA_PATH := "res://data/ring/callouts.json"

static var _data := {}
static var _font: Font = null
## Every word shown since the start (tests: what was called, in order).
static var shown: Array = []

var _root: Control
var _word: Label
var _streak: ColorRect
var _cur := {}
var _t := 0.0
var _t_was := 0.0
var _queue: Array = []
var _hooked: Object = null


static func install(m: Node) -> Callouts:
	if m == null:
		return null
	var have := m.get_node_or_null(NODE_NAME) as Callouts
	if have != null:
		return have
	var c := Callouts.new()
	c.name = NODE_NAME
	m.add_child(c)
	return c


static func find(tree: SceneTree) -> Callouts:
	return tree.get_first_node_in_group(GROUP) as Callouts if tree != null else null


static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
		_data = d if d is Dictionary else {}
	return _data


static func look(key: String, def := 0.0) -> float:
	return float((data().get("look", {}) as Dictionary).get(key, def))


static func call_cfg(kind: String) -> Dictionary:
	var c: Variant = (data().get("calls", {}) as Dictionary).get(kind, {})
	return c if c is Dictionary else {}


## On or off (GameSettings [ring] callouts; on by default).
static func on() -> bool:
	return bool(RingReplay.ring_setting("callouts", true)) and bool(data().get("enabled", true))


static func set_on(v: bool) -> void:
	RingReplay.set_ring_setting("callouts", v)


static func toggle() -> bool:
	set_on(not on())
	return on()


## "Callouts: On".
static func row_text() -> String:
	var r := data().get("row", {}) as Dictionary
	return String(r.get("label", "Callouts: %s")) % String(r.get("on" if on() else "off", "On" if on() else "Off"))


static func row_line() -> String:
	return String((data().get("row", {}) as Dictionary).get("line", ""))


## Every call's word (the words test).
static func words() -> Array:
	var out: Array = []
	for k in (data().get("calls", {}) as Dictionary):
		out.append(String(call_cfg(k).get("word", "")))
	return out


static func color_of(el: String) -> Color:
	var c := data().get("colors", {}) as Dictionary
	return Color.html(String(c.get(el, c.get("none", "#ffffff"))))


## The HUD's serif, bold and slanted (the callouts' own variation of it: our own lettering).
static func font() -> Font:
	if _font == null:
		var f := FontVariation.new()
		f.base_font = FrontierHUD.serif()
		f.variation_embolden = 1.1
		f.spacing_glyph = 3
		f.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(0.22, 1.0), Vector2.ZERO)
		_font = f
	return _font


func _ready() -> void:
	add_to_group(GROUP)
	layer = 30
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_streak = ColorRect.new()
	_streak.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_streak.visible = false
	_root.add_child(_streak)
	_word = Label.new()
	_word.name = "Word"
	_word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_word.add_theme_font_override("font", font())
	_word.add_theme_font_size_override("font_size", int(look("size", 76.0)))
	_word.add_theme_constant_override("outline_size", int(look("outline", 14.0)))
	_word.add_theme_color_override("font_outline_color", Color(0.05, 0.035, 0.02, 0.95))
	_word.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	_word.add_theme_constant_override("shadow_offset_x", int(look("shadow", 6.0)))
	_word.add_theme_constant_override("shadow_offset_y", int(look("shadow", 6.0)))
	_word.add_theme_constant_override("shadow_outline_size", int(look("outline", 14.0)))
	_word.visible = false
	_root.add_child(_word)


func _hook() -> void:
	var h := RingHighlights.find(get_tree())
	if h != null and h != _hooked:
		_hooked = h
		h.moment.connect(_on_moment.bind(h))


## A moment told (RingHighlights): called out when its call shows for this body's side.
func _on_moment(kind: String, body: Node, info: Dictionary, h: RingHighlights) -> void:
	var call_kind := kind
	var c := call_cfg(call_kind)
	if c.is_empty():
		return
	var mine_team := h.my_team()
	if String(c.get("who", "any")) == "mine" and mine_team >= 0:
		var r := RingRules.current()
		if body == null or r == null or r.team_of(body) != mine_team:
			return
	var el := "none"
	if body != null and is_instance_valid(body):
		el = RingReplay._element_of(body)
	if kind == "clash":
		el = String({"stone": "earth"}.get(String(info.get("a", "")), String(info.get("a", "none"))))
		if not (el in ["earth", "water", "fire", "air"]):
			el = "none"
	say(call_kind, el)


## Calls out `kind` (calls.<kind>) in element `el`'s colour: now, or after the one showing (by priority).
func say(kind: String, el := "none") -> void:
	if not on() or not RingRules.stock_on():
		return
	var c := call_cfg(kind)
	if c.is_empty():
		return
	var e := {"kind": kind, "word": String(c.get("word", kind)), "prio": int(c.get("priority", 0)), "el": el, "age": 0.0}
	if _cur.is_empty():
		_show(e)
		return
	if int(e.prio) > int(_cur.prio):
		# (the one showing gives way; just begun, it waits its turn again)
		var was := _cur
		_show(e)
		if _t_was < float(data().get("show_s", 0.9)) * 0.5:
			_enqueue(was)
		return
	_enqueue(e)


func _enqueue(e: Dictionary) -> void:
	_queue.append(e)
	_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.prio) > int(b.prio))
	while _queue.size() > int(data().get("queue_n", 3)):
		_queue.pop_back()


func showing() -> String:
	return String(_cur.get("word", "")) if not _cur.is_empty() else ""


func _show(e: Dictionary) -> void:
	_t_was = _t if not _cur.is_empty() else 0.0
	_cur = e
	_t = 0.0
	shown.append(String(e.word))
	if shown.size() > 64:
		shown.remove_at(0)                     # (round 4's merge: the tests' record kept short; a static lives all session)
	_word.text = String(e.word)
	var col := color_of(String(e.el))
	_word.add_theme_color_override("font_color", col)
	_streak.color = Color(col.r, col.g, col.b, 0.32)
	_word.visible = true
	_streak.visible = true
	_lay()


func _lay() -> void:
	var vs := _root.get_viewport_rect().size
	var h := look("size", 76.0) * 1.6
	var y := vs.y * look("anchor_y", 0.63)
	_word.position = Vector2(0.0, y - h * 0.5)
	_word.size = Vector2(vs.x, h)
	_word.pivot_offset = Vector2(vs.x * 0.5, h * 0.5)
	_streak.size = Vector2(vs.x * 0.42, h * 0.16)
	_streak.position = Vector2(vs.x * 0.29, y - _streak.size.y * 0.5 + h * 0.08)
	_streak.pivot_offset = _streak.size * 0.5
	_streak.rotation = deg_to_rad(look("tilt_deg", -5.0))


func _process(delta: float) -> void:
	_hook()
	for q: Dictionary in _queue:
		q["age"] = float(q.age) + delta
	if _cur.is_empty():
		return
	_t += delta
	var show_s := float(data().get("show_s", 0.9))
	if _t >= show_s:
		_cur = {}
		_word.visible = false
		_streak.visible = false
		while not _queue.is_empty():
			var e := _queue.pop_front() as Dictionary
			if float(e.age) <= float(data().get("stale_s", 1.2)):
				_show(e)
				break
		return
	# (the punch: from `punch` past 1 to `overshoot`, then settling at 1; a drift up; the fade at the end)
	var ps := look("punch_s", 0.14)
	var s := 1.0
	if _t < ps:
		var k := _t / ps
		s = lerpf(look("punch", 1.7), look("overshoot", 1.12), 1.0 - pow(1.0 - k, 3.0))
	elif _t < ps * 2.0:
		s = lerpf(look("overshoot", 1.12), 1.0, (_t - ps) / ps)
	_word.scale = Vector2.ONE * s
	_word.rotation = deg_to_rad(look("tilt_deg", -5.0)) * (0.6 + 0.4 * s)
	_word.position.y = _root.get_viewport_rect().size.y * look("anchor_y", 0.63) - look("size", 76.0) * 0.8 \
			- look("drift_px", 14.0) * (_t / show_s)
	var fade := look("fade_s", 0.22)
	var a := clampf((show_s - _t) / fade, 0.0, 1.0)
	_word.modulate.a = a
	_streak.scale = Vector2(clampf(_t / (ps * 1.5), 0.05, 1.0) * (1.0 + 0.3 * _t), 1.0)
	_streak.modulate.a = a * 0.9
