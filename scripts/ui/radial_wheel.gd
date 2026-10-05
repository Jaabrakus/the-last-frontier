class_name RadialWheel
extends CanvasLayer
## The move wheel: the radial control scheme (MatchSetup.scheme() "radial", data/bending/schemes.json; the owner, 2026-10-05:
## "still difficult for a human to switch spells, there's a lot of things going on" -> a wheel among the options). Hold the
## wheel key (the action ACTION, Tab by default and rebindable: Tab does nothing else in the ring; in the duel it takes
## Tab from the character screen while this scheme is on) and every move of the player's element sits round the screen's
## centre: each key's two skills, then Mend and Patch (Bending.keys: ten). The mouse moved toward one picks it (the camera
## does not turn meanwhile, as the equip wheel); the mouse wheel steps the picked move's form (SwayCaster.set_mode: the
## key's own variation, the strip's pips follow); letting go of the key (or a left click) readies it (Hotbar.ready_skill:
## its key turned to it). Moving the mouse less than pick_min_px picks nothing: letting go changes nothing. The game runs on
## at full speed (the equip wheel's rule: the owner wants no slow motion on a wheel). Casting stays the right button,
## once the wheel is shut (SwayCaster: no lock is held while it is open, and its pick click starts none).
## One per local player's caster (SwayCaster.radial: install). Only with an element and the radial scheme.
##   open() / close(take) / pick_toward(d) / step_form(dir) / items: [{id, label, key}] / sel / is_open

const ACTION := &"bend_wheel"
const KEY := KEY_TAB
const ICON_PX := 54.0
const COL_BG := Color(0.07, 0.06, 0.05, 0.78)
const COL_SEL := Color(0.86, 0.66, 0.34, 0.55)
const COL_LINE := Color(0.9, 0.82, 0.66, 0.35)
const COL_TEXT := Color(0.96, 0.9, 0.78)
const COL_DIM := Color(0.75, 0.7, 0.6)

var caster: SwayCaster
## The element's moves round the wheel, clockwise from the top: [{id, label, key (1-5)}].
var items: Array = []
var sel := -1
var is_open := false
## Tests only: not null stands for the wheel key held.
var held_override: Variant = null

var _dir := Vector2.ZERO
var _was_down := false
var _hold_fire := false
var _ring: Control
var _names: Array = []
var _title: Label
var _note: Label
var radius := 230.0
var inner := 80.0
var pick_min := 36.0


static func install(c: SwayCaster) -> RadialWheel:
	ensure_input()
	var w := RadialWheel.new()
	w.name = "RadialWheel"
	w.caster = c
	c.add_child(w)
	return w


## The wheel key: ACTION on Tab, made when missing (the player may rebind it). Safe to call again.
static func ensure_input() -> void:
	if InputMap.has_action(ACTION):
		return
	InputMap.add_action(ACTION)
	var e := InputEventKey.new()
	e.physical_keycode = KEY
	InputMap.action_add_event(ACTION, e)


func _ready() -> void:
	layer = 31
	radius = MatchSetup.radial_num("radius_px", radius)
	inner = MatchSetup.radial_num("inner_px", inner)
	pick_min = MatchSetup.radial_num("pick_min_px", pick_min)
	_ring = Control.new()
	_ring.name = "Ring"
	_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	_title = _label(24)
	_note = _label(15)
	_note.add_theme_color_override("font_color", COL_DIM)
	_ring.add_child(_title)
	_ring.add_child(_note)
	visible = false


func _player() -> FrontierPlayer:
	return caster.player if caster != null and is_instance_valid(caster) else null


func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", COL_TEXT)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _key_down() -> bool:
	if held_override != null:
		return bool(held_override)
	return InputMap.has_action(ACTION) and Input.is_action_pressed(ACTION)


func _process(_dt: float) -> void:
	var p := _player()
	if p == null:
		return
	var down := _key_down()
	if down and not _was_down and not is_open and can_open():
		open()
	elif not down and is_open:
		close(true)
	_was_down = down
	if is_open and (p.is_dead or not can_stay()):
		close(false)


## Whether the wheel may open now: the radial scheme with an element, the player up and the game not paused.
func can_open() -> bool:
	var p := _player()
	if p == null or p.is_dead or get_tree().paused or caster.quick_element() == "" or caster.scheme() != "radial":
		return false
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or p.ignore_mouse_capture


func can_stay() -> bool:
	return caster.quick_element() != "" and caster.scheme() == "radial" and not get_tree().paused


func _input(event: InputEvent) -> void:
	if not is_open:
		# (the key's press opens it here, taken from anything else on the key: the duel's character screen)
		if event.is_action_pressed(ACTION) and not event.is_echo() and can_open():
			open()
			_was_down = true
			get_viewport().set_input_as_handled()
		return
	var mm := event as InputEventMouseMotion
	if mm:
		pick_toward(_dir + mm.relative)
		get_viewport().set_input_as_handled()
	elif event.is_action_released(ACTION) and held_override == null:
		get_viewport().set_input_as_handled()
		_was_down = false
		close(true)                           # (let go: the pick readied at once, not a frame later)
	elif event.is_action_pressed(&"weapon_next"):
		step_form(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"weapon_prev"):
		step_form(-1)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		if sel >= 0:
			_hold_fire = true
			close(true)
	elif event.is_action(ACTION) or event.is_action(&"fire") or event.is_action(&"aim") or event.is_action(&"weapon_next") \
			or event.is_action(&"weapon_prev"):
		get_viewport().set_input_as_handled()


## LMB is not the quick spell's now: the wheel open, or the click that picked on it still held.
func blocks_fire() -> bool:
	if _hold_fire and not Input.is_action_pressed(&"fire"):
		_hold_fire = false
	return is_open or _hold_fire


# --- open, pick, ready ------------------------------------------------------------------------------------------

## The element's moves: each key's two skills in turn, then the last key's (Mend, Patch).
static func items_for(el: String) -> Array:
	var out: Array = []
	var keys := Bending.keys(el)
	for i in keys.size():
		for id in keys[i] as Array:
			out.append({"id": String(id), "label": Hotbar.spell_label(String(id)), "key": i + 1})
	return out


func open() -> void:
	var p := _player()
	if p == null:
		return
	items = items_for(caster.quick_element())
	if items.is_empty():
		return
	is_open = true
	sel = -1
	_dir = Vector2.ZERO
	_layout()
	visible = true
	_refresh()


## Shuts the wheel; `take`: the picked move readied (its key turned to it).
func close(take: bool) -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	if take and sel >= 0 and sel < items.size():
		ready_item(sel)


## Item `i` readied (Hotbar.ready_skill): true when it is the readied move now.
func ready_item(i: int) -> bool:
	var p := _player()
	if p == null or i < 0 or i >= items.size() or p.hotbar == null:
		return false
	return p.hotbar.ready_skill(String(items[i].id))


## Picks the item in the direction of `d` (screen space, y down; the mouse travel since it opened).
func pick_toward(d: Vector2) -> void:
	_dir = d.limit_length(radius)
	if _dir.length() < pick_min or items.is_empty():
		sel = -1
	else:
		var n := items.size()
		var ang := fposmod(atan2(_dir.x, -_dir.y), TAU)         # 0 at the top, clockwise
		sel = int(round(ang / (TAU / n))) % n
	_refresh()


## The direction (screen, y down) item `i` sits in: what pick_toward wants to pick it.
func dir_of(i: int) -> Vector2:
	var a := i * TAU / maxi(items.size(), 1)
	return Vector2(sin(a), -cos(a))


## The picked move's next (`dir` 1) or earlier form; "" none picked or it has fewer than two.
func step_form(dir: int) -> String:
	if sel < 0 or sel >= items.size():
		return ""
	var id := String(items[sel].id)
	var ms := SwayCaster.modes_of(id)
	if ms.size() < 2:
		return ""
	var nxt := String(ms[posmod(ms.find(caster.base_mode_of(id)) + dir, ms.size())])
	caster.set_mode(id, nxt)
	_refresh()
	return nxt


# --- drawing -----------------------------------------------------------------------------------------------------

func _center() -> Vector2:
	return _ring.get_viewport_rect().size * 0.5


func _item_pos(i: int) -> Vector2:
	return _center() + dir_of(i) * (radius + inner) * 0.5


func _layout() -> void:
	for c in _names:
		(c as Node).queue_free()
	_names.clear()
	for i in items.size():
		var l := _label(14)
		l.size = Vector2(130, 40)
		l.position = _item_pos(i) + Vector2(-65, -20)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.text = String(items[i].label)
		_ring.add_child(l)
		_names.append(l)
	_title.size = Vector2(320, 34)
	_title.position = _center() + Vector2(-160, -32)
	_note.size = Vector2(320, 24)
	_note.position = _center() + Vector2(-160, 4)


func _refresh() -> void:
	var readied := caster.readied_spell if caster != null else ""
	for i in _names.size():
		var l := _names[i] as Label
		var on := i == sel
		l.add_theme_color_override("font_color", MenuUI.GOLD if on or String(items[i].id) == readied else COL_TEXT)
		l.scale = Vector2.ONE * (1.12 if on else 1.0)
		l.pivot_offset = l.size * 0.5
	if sel >= 0 and sel < items.size():
		var id := String(items[sel].id)
		_title.text = String(items[sel].label)
		var ms := SwayCaster.modes_of(id)
		var m := caster.base_mode_of(id)
		_note.text = ("%s (%d/%d)  ·  scroll: its form" % [SwayCaster.mode_label(id, m), ms.find(m) + 1, ms.size()]) \
				if ms.size() > 1 else "key %d" % int(items[sel].key)
	else:
		_title.text = "Your moves"
		_note.text = "point at one, let go to ready it"
	_ring.queue_redraw()


func _draw_ring() -> void:
	if not is_open:
		return
	var c := _center()
	var n := maxi(items.size(), 1)
	var step := TAU / n
	var tint := MatchSetup.color(caster.quick_element()) if caster != null else MenuUI.GOLD
	_ring.draw_circle(c, radius + 8.0, COL_BG)
	_ring.draw_circle(c, inner - 6.0, Color(0.03, 0.03, 0.02, 0.85))
	if sel >= 0:
		var a0 := sel * step - step * 0.5 - PI * 0.5
		var pts := PackedVector2Array()
		for k in 17:
			var a := a0 + step * k / 16.0
			pts.append(c + Vector2(cos(a), sin(a)) * (radius + 4.0))
		for k in range(16, -1, -1):
			var a := a0 + step * k / 16.0
			pts.append(c + Vector2(cos(a), sin(a)) * inner)
		_ring.draw_colored_polygon(pts, Color(tint, 0.45))
	for i in n:
		var a := i * step - step * 0.5 - PI * 0.5
		var d := Vector2(cos(a), sin(a))
		_ring.draw_line(c + d * inner, c + d * (radius + 4.0), COL_LINE, 2.0, true)
	# the variation pips under each move's name (the one its key is on filled)
	for i in items.size():
		var id := String(items[i].id)
		var ms := SwayCaster.modes_of(id)
		if ms.size() < 2:
			continue
		var at := _item_pos(i) + Vector2(0, 26)
		var mi := ms.find(caster.base_mode_of(id))
		for j in ms.size():
			var p := at + Vector2((j - (ms.size() - 1) * 0.5) * 11.0, 0)
			if j == mi:
				_ring.draw_circle(p, 3.2, tint)
			else:
				_ring.draw_arc(p, 2.8, 0.0, TAU, 12, Color(tint, 0.8), 1.2, true)
	_ring.draw_arc(c, radius + 8.0, 0.0, TAU, 96, COL_LINE, 2.0, true)
	if _dir.length() > 1.0:
		_ring.draw_line(c, c + _dir.normalized() * (inner - 12.0), COL_SEL.lightened(0.3), 3.0, true)
