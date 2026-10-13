class_name TouchControls
extends CanvasLayer
## Touch controls for the web build on a phone or a tablet (the owner, 2026-10-13: "if you want to build touch controls do it
## now as well"): the arena played with the thumbs through the same actions as the keys and the mouse, sent as action events
## (Input.parse_input_event: the hotbar, the caster and RingMoves see a press as they see a key's), nothing of the game changed.
##   left thumb   a stick where it lands on the left of the screen: move_forward / back / left / right, by how far it is pushed
##   right thumb  dragged anywhere free: the look (the player's yaw and pitch, as the mouse turns them)
##   1-5          the key pressed as it is touched (a second touch within the key's double tap: its other move, as the keys),
##                then aim held: the finger dragged turns the look while the lock fills; let go: cast (early: called off)
##   JAB          fire (the left button's quick spell)        GUARD  bend_guard (E)        JUMP  jump (Space)
##   DASH         sprint (Shift) with the stick's way        II     ui_cancel (Esc: the menu)
## Shown on a coarse pointer (a phone or a tablet) or with ?touch=1 in the page's address (the mouse then acts as one finger:
## Input.emulate_touch_from_mouse, for trying it at a desk). In play (the game holding the mouse: tools/web/shell.html stands in
## for the lock on a touch screen) the layer is up, Godot's mouse made from touches is off and the mouse buttons are taken off
## fire and aim (a finger is not a click: no jab with every touch, no look from the stick's thumb); in the menus (the mouse
## let go) it is hidden and the touches work the menus as clicks.
##   TouchControls.attach(player)   by FrontierPlayer for the local arena player; null when not wanted

## The stick's reach (of the screen's height) and where the left thumb's stick may start (of the width).
const STICK_R := 0.12
const STICK_ZONE := 0.42
## The look: a drag across the whole screen's width turns this far (degrees), its height this far up or down.
const LOOK_W_DEG := 170.0
const LOOK_H_DEG := 80.0
## A touch this far outside a button's circle (of its radius) still takes it.
const HIT_SLACK := 1.2
## The actions the mouse's buttons are taken off while the layer is up.
const MOUSE_ACTIONS := [&"fire", &"aim", &"weapon_next", &"weapon_prev"]

var player: FrontierPlayer
var forced := false

var _pad: Control
var _font: Font
var _active := false
## touch index -> what it holds: {"kind": "stick" | "look" | "button", "b": the button}
var _touch := {}
var _stick_at := Vector2.ZERO
var _stick_v := Vector2.ZERO
var _move := {&"move_left": 0.0, &"move_right": 0.0, &"move_forward": 0.0, &"move_back": 0.0}
## The mouse buttons taken off MOUSE_ACTIONS while up: action -> [events].
var _unbound := {}


static func wanted() -> bool:
	if not OS.has_feature("web"):
		return false
	return bool(JavaScriptBridge.eval(
			"matchMedia('(pointer: coarse)').matches || /[?&]touch=1/.test(location.search)", true))


static func attach(p: FrontierPlayer) -> TouchControls:
	if p == null or not wanted():
		return null
	var t := TouchControls.new()
	t.name = "TouchControls"
	t.player = p
	t.forced = bool(JavaScriptBridge.eval("/[?&]touch=1/.test(location.search)", true))
	p.add_child(t)
	return t


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	if forced:
		Input.emulate_touch_from_mouse = true
	_font = ThemeDB.fallback_font
	_pad = Control.new()
	_pad.name = "Pad"
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pad.draw.connect(_draw_pad)
	add_child(_pad)
	visible = false


func _exit_tree() -> void:
	_set_active(false)


func _process(_dt: float) -> void:
	var up := is_instance_valid(player) and not get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if up != _active:
		_set_active(up)
	if _active:
		_pad.queue_redraw()


func _set_active(on: bool) -> void:
	_active = on
	visible = on
	Input.emulate_mouse_from_touch = not on
	if on:
		for a: StringName in MOUSE_ACTIONS:
			if not InputMap.has_action(a):
				continue
			var gone := []
			for e in InputMap.action_get_events(a):
				if e is InputEventMouseButton:
					gone.append(e)
					InputMap.action_erase_event(a, e)
			_unbound[a] = gone
	else:
		_let_go_all()
		for a: StringName in _unbound:
			if InputMap.has_action(a):
				for e in _unbound[a]:
					InputMap.action_add_event(a, e)
		_unbound.clear()


# ---------------------------------------------------------------- the buttons
## The buttons where they stand now: [{id, at, r, label, action | key}], laid out by the screen's height (u: 1/100 of it).
func _buttons() -> Array:
	var s := _pad.size
	var w := s.x
	var u := s.y / 100.0
	var out := [
		{"id": "jab", "at": Vector2(w - 13 * u, s.y - 16 * u), "r": 9.0 * u, "label": "JAB", "action": &"fire"},
		{"id": "guard", "at": Vector2(w - 33 * u, s.y - 11 * u), "r": 6.5 * u, "label": "GUARD", "action": &"bend_guard"},
		{"id": "jump", "at": Vector2(w - 12 * u, s.y - 37 * u), "r": 6.5 * u, "label": "JUMP", "action": &"jump"},
		{"id": "dash", "at": Vector2(w - 30 * u, s.y - 30 * u), "r": 5.5 * u, "label": "DASH", "action": &"sprint"},
		# (under the opponent's score box at the top right)
		{"id": "menu", "at": Vector2(w - 6 * u, 21 * u), "r": 4.5 * u, "label": "II", "action": &"ui_cancel"},
	]
	var arc := [Vector2(50, 9), Vector2(49, 26), Vector2(43, 42), Vector2(29, 51), Vector2(13, 56)]
	for i in arc.size():
		out.append({"id": "k%d" % (i + 1), "at": Vector2(w - arc[i].x * u, s.y - arc[i].y * u), "r": 5.5 * u,
				"label": str(i + 1), "key": i})
	return out


func _button_at(pos: Vector2) -> Dictionary:
	for b: Dictionary in _buttons():
		if pos.distance_to(b.at) <= float(b.r) * HIT_SLACK:
			return b
	return {}


## The name of key i's first move (the strip's), "" when none.
func _key_name(i: int) -> String:
	var el := Bending.of(player).element if player != null and Bending.of(player) != null else ""
	var ks := Bending.keys(el) if el != "" else []
	if i >= ks.size():
		return ""
	var m := Bending.first_of(ks[i])
	return KitWords.move_name(String(m.get("id", "")), String(m.get("mode", ""))) if not m.is_empty() else ""


# ---------------------------------------------------------------- the touches
func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_down(t.index, t.position)
		else:
			_up(t.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_drag(d.index, d.position, d.relative)
		get_viewport().set_input_as_handled()


func _down(i: int, pos: Vector2) -> void:
	if _touch.has(i):
		_up(i)
	var b := _button_at(pos)
	if not b.is_empty():
		_touch[i] = {"kind": "button", "b": b}
		if b.has("key"):
			_tap(StringName("weapon_%d" % (int(b.key) + 1)))   # (the key, as pressed: a second touch is its other move)
			_send(&"aim", true)
		else:
			_send(b.action, true)
		return
	if pos.x < _pad.size.x * STICK_ZONE and not _holds("stick"):
		_touch[i] = {"kind": "stick"}
		_stick_at = pos
		_stick_v = Vector2.ZERO
		return
	_touch[i] = {"kind": "look"}


func _drag(i: int, pos: Vector2, rel: Vector2) -> void:
	if not _touch.has(i):
		return
	var t: Dictionary = _touch[i]
	match String(t.kind):
		"stick":
			_stick_v = ((pos - _stick_at) / maxf(_pad.size.y * STICK_R, 1.0)).limit_length(1.0)
			_set_move(_stick_v)
		"look":
			_look(rel)
		"button":
			if (t.b as Dictionary).has("key"):
				_look(rel)                          # (a held key's finger aims the lock)


func _up(i: int) -> void:
	if not _touch.has(i):
		return
	var t: Dictionary = _touch[i]
	_touch.erase(i)
	match String(t.kind):
		"stick":
			_stick_v = Vector2.ZERO
			_set_move(Vector2.ZERO)
		"button":
			var b: Dictionary = t.b
			_send(&"aim" if b.has("key") else StringName(b.action), false)


func _holds(kind: String) -> bool:
	for t: Dictionary in _touch.values():
		if String(t.kind) == kind:
			return true
	return false


func _let_go_all() -> void:
	for i in _touch.keys():
		_up(int(i))
	_touch.clear()
	_set_move(Vector2.ZERO)


# ---------------------------------------------------------------- what they do
func _look(rel: Vector2) -> void:
	if not is_instance_valid(player):
		return
	var s := _pad.size
	player.yaw -= rel.x / maxf(s.x, 1.0) * deg_to_rad(LOOK_W_DEG)
	var lim := deg_to_rad(player.pitch_limit_deg)
	player.pitch = clampf(player.pitch - rel.y / maxf(s.y, 1.0) * deg_to_rad(LOOK_H_DEG), -lim, lim)
	if player.ring_moves != null:
		player.ring_moves.note_mouse()             # (the recovery turn stops for the player's own look)


## The stick's way as the four move actions (x right, y down the screen = back), each by how far it is pushed.
func _set_move(v: Vector2) -> void:
	var want := {&"move_left": maxf(-v.x, 0.0), &"move_right": maxf(v.x, 0.0), &"move_forward": maxf(-v.y, 0.0),
			&"move_back": maxf(v.y, 0.0)}
	for a: StringName in want:
		var k := float(want[a])
		k = 0.0 if k < 0.12 else k                      # (a thumb at rest is still)
		if absf(k - float(_move[a])) > 0.02 or (k == 0.0) != (float(_move[a]) == 0.0):
			_move[a] = k
			_send(a, k > 0.0, k)


func _send(action: StringName, pressed: bool, strength := 1.0) -> void:
	if not InputMap.has_action(action):
		return
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	e.strength = strength if pressed else 0.0
	Input.parse_input_event(e)


## A press and its release, a frame apart (a key's tap).
func _tap(action: StringName) -> void:
	_send(action, true)
	get_tree().process_frame.connect(func() -> void: _send(action, false), CONNECT_ONE_SHOT)


# ---------------------------------------------------------------- drawing
func _draw_pad() -> void:
	var u := _pad.size.y / 100.0
	var rim := Color(1, 1, 1, 0.55)
	var fill := Color(0.05, 0.09, 0.12, 0.35)
	var lit := Color(0.5, 0.83, 0.9, 0.55)
	var held := {}
	for t: Dictionary in _touch.values():
		if String(t.kind) == "button":
			held[String((t.b as Dictionary).id)] = true
	for b: Dictionary in _buttons():
		var r := float(b.r)
		_pad.draw_circle(b.at, r, lit if held.has(String(b.id)) else fill)
		_pad.draw_arc(b.at, r, 0.0, TAU, 40, rim, maxf(1.5, u * 0.3), true)
		var fs := int(maxf(10.0, r * (0.62 if String(b.label).length() <= 2 else 0.4)))
		var label := String(b.label)
		var sz := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		_label(b.at + Vector2(-sz.x * 0.5, fs * 0.35), label, fs, Color.WHITE)
		if b.has("key"):
			var n := _key_name(int(b.key))
			if n != "":
				var fs2 := int(maxf(9.0, u * 2.0))
				var sz2 := _font.get_string_size(n, HORIZONTAL_ALIGNMENT_CENTER, -1, fs2)
				_label(b.at + Vector2(-sz2.x * 0.5, r + fs2 * 1.1), n, fs2, Color(1, 1, 1, 0.9))
	if _holds("stick"):
		var reach := _pad.size.y * STICK_R
		_pad.draw_circle(_stick_at, reach, fill)
		_pad.draw_arc(_stick_at, reach, 0.0, TAU, 48, rim, maxf(1.5, u * 0.3), true)
		_pad.draw_circle(_stick_at + _stick_v * reach, reach * 0.42, lit)


## A label with a dark outline (it reads on the bright deck as on the water).
func _label(at: Vector2, text: String, fs: int, col: Color) -> void:
	_pad.draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(3, fs / 5), Color(0, 0, 0, 0.75))
	_pad.draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
