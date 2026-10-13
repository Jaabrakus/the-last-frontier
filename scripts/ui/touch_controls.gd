class_name TouchControls
extends CanvasLayer
## Touch controls for the web build on a phone or a tablet (the owner, 2026-10-13: "if you want to build touch controls do it
## now as well"): the arena played with the thumbs through the same actions as the keys and the mouse, sent as action events
## (Input.parse_input_event: the hotbar, the caster and RingMoves see a press as they see a key's).
##   left thumb   a stick where it lands on the left of the screen: move_forward / back / left / right, by how far it is pushed
##   right thumb  dragged anywhere free: the look (the player's yaw and pitch, as the mouse turns them)
##   1-5          (the owner, 2026-10-13: "tap once to highlight it and then if highlighted tap again to change it ... a skill
##                selector pops out"; no double tap)
##                  tap          the key readied and lit, and its forms beside it (the selector: chips, the one readied lit;
##                               a chip tapped readies that form)
##                  tap it again the key's next form (its moves and their ways in turn, as a wheel: Fissure, Column, Column
##                               throw right, ...; KitWords.key_moves x BendVariants)
##                  hold         the key's form readied and aim held: the finger dragged aims while the lock fills; let go:
##                               cast (early: called off). The stick pushed meanwhile picks the way, as W, A, S or D with
##                               the key held (Hotbar._key_dir)
##                Key 3 where it acts at once (the movement spell: no move of its own, Bending.key3) is the key as pressed.
##                Each key's button names what it casts now (the strip's column label); held, the lock's fill runs round it
##                (gold: full, let go)
##   JAB          fire (the left button's quick spell)        GUARD  bend_guard (E)        JUMP  jump (Space)
##   DASH         sprint (Shift) with the stick's way        II     ui_cancel (Esc: the menu)
## Shown only on a touch-first device (a coarse pointer and touch points: a phone or a tablet), or with ?touch=1 in the page's
## address (the mouse then acts as one finger: Input.emulate_touch_from_mouse, for trying it at a desk). In play (the game
## holding the mouse: tools/web/shell.html stands in for the lock on a touch screen) the layer is up, Godot's mouse made from
## touches is off and the mouse buttons are taken off fire, aim and the wheel (a finger is not a click); in the menus (the
## mouse let go) it is hidden and the touches work the menus as clicks.
##   TouchControls.attach(player)   by FrontierPlayer for the local arena player; null when not wanted

## The stick's reach (of the screen's height) and where the left thumb's stick may start (of the width).
const STICK_R := 0.12
const STICK_ZONE := 0.42
## The look: a drag across the whole screen's width turns this far (degrees), its height this far up or down.
const LOOK_W_DEG := 170.0
const LOOK_H_DEG := 80.0
## A touch this far outside a button's circle (of its radius) still takes it.
const HIT_SLACK := 1.2
## A key's touch let go within this (s) and moved less than TAP_PX (of the screen's height) is a tap, not a cast.
const TAP_S := 0.25
const TAP_PX := 0.03
## The selector stays this long (s) after the last tap or pick.
const SELECTOR_S := 5.0
## The actions the mouse's buttons are taken off while the layer is up.
const MOUSE_ACTIONS := [&"fire", &"aim", &"weapon_next", &"weapon_prev"]

var player: FrontierPlayer
var forced := false

var _pad: Control
var _font: Font
var _active := false
## touch index -> what it holds: {"kind": "stick" | "look" | "button" | "chip", "b": the button, ...}
var _touch := {}
var _stick_at := Vector2.ZERO
var _stick_v := Vector2.ZERO
var _move := {&"move_left": 0.0, &"move_right": 0.0, &"move_forward": 0.0, &"move_back": 0.0}
## The mouse buttons taken off MOUSE_ACTIONS while up: action -> [events].
var _unbound := {}
## The selector: the key it is open for (-1 none) and until when (s, Time).
var _sel_key := -1
var _sel_until := 0.0


static func wanted() -> bool:
	if not OS.has_feature("web"):
		return false
	return bool(JavaScriptBridge.eval(
			"(matchMedia('(pointer: coarse)').matches && navigator.maxTouchPoints > 0) || /[?&]touch=1/.test(location.search)",
			true))


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
		if _sel_key >= 0 and _now() > _sel_until and not _holds("chip"):
			_sel_key = -1
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
		_sel_key = -1
		for a: StringName in _unbound:
			if InputMap.has_action(a):
				for e in _unbound[a]:
					InputMap.action_add_event(a, e)
		_unbound.clear()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


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


## Key i as the strip shows it (BendStrip.column: label, the move it casts now with its way; readied), {} without a strip.
func _key_column(i: int) -> Dictionary:
	if not is_instance_valid(player) or player.hud == null or player.hud.bend_strip == null:
		return {}
	return player.hud.bend_strip.column(i)


# ---------------------------------------------------------------- a key's forms (the selector)
func _hotbar() -> Hotbar:
	return player.hotbar if is_instance_valid(player) else null


func _element() -> String:
	var b := Bending.of(player) if is_instance_valid(player) else null
	return b.element if b != null else ""


## Key 3 where it acts at once (the % ring's movement spell: an element with no key-3 move of its own).
func _acts_at_once(i: int) -> bool:
	return i == 2 and RingRules.stock_on() and Bending.key3(_element()).is_empty()


## Key i's forms in turn: each of its moves (KitWords.key_moves), a move with ways (BendVariants) once per way:
## [{id, mode, way ("" none), label}].
func _forms(i: int) -> Array:
	var out := []
	var ms := KitWords.key_moves(_element(), i, player)
	if i == 2 and RingRules.stock_on() and not Bending.key3(_element()).is_empty():
		ms = [Bending.first_of(Bending.key3(_element()))]     # (key 3's own move: water's Ice Tomahawk, as the strip shows)
	for m: Dictionary in ms:
		var id := String(m.get("id", ""))
		var md := String(m.get("mode", ""))
		if id == "":
			continue
		var name := KitWords.move_name(id, md)
		var ways := BendVariants.list(id, md)
		if ways.is_empty():
			out.append({"id": id, "mode": md, "way": "", "label": name})
		for w: String in ways:
			out.append({"id": id, "mode": md, "way": w,
					"label": name if w == "up" else "%s · %s" % [name, BendVariants.WORDS.get(w, w)]})
	return out


## The form of key i readied now (its index in _forms), -1 when the key is not the readied one.
func _form_now(i: int, forms: Array) -> int:
	var hb := _hotbar()
	var c := SwayCaster.of(player) if is_instance_valid(player) else null
	if hb == null or c == null or hb.readied_key() != i or c.readied_spell == "":
		return -1
	var id := c.readied_spell
	var md := c.mode_of(id)
	var way := BendVariants.of(player, id, md)
	for j in forms.size():
		var f: Dictionary = forms[j]
		if String(f.id) == id and String(f.mode) == md and (String(f.way) == "" or String(f.way) == way):
			return j
	for j in forms.size():
		if String((forms[j] as Dictionary).id) == id:
			return j
	return -1


## Form f of key i readied (the move, its mode and its way), as the key and the wheel would.
func _choose(i: int, f: Dictionary) -> void:
	var hb := _hotbar()
	if hb == null:
		return
	hb.ready_move(i, String(f.id), String(f.mode))
	if String(f.way) != "":
		BendVariants.set_to(player, String(f.id), String(f.mode), String(f.way))
	if hb.has_method(&"_dirty_strip"):
		hb.call(&"_dirty_strip")


## Key i readied in the form it was last left in (else its first), when it is not readied already.
func _ready_key(i: int) -> void:
	var forms := _forms(i)
	if forms.is_empty() or _form_now(i, forms) >= 0:
		return
	var c := SwayCaster.of(player)
	var pick: Dictionary = forms[0]
	for f: Dictionary in forms:
		if c != null and c.base_mode_of(String(f.id)) == String(f.mode) and String(f.way) in ["", BendVariants.of(player, String(f.id), String(f.mode))]:
			pick = f                          # (the move's own last way and mode: what the key had)
			break
	_choose(i, pick)


func _open_selector(i: int) -> void:
	_sel_key = i
	_sel_until = _now() + SELECTOR_S


## The selector's chips for key _sel_key, laid out left of the keys: [{at (rect), form, index}].
func _chips() -> Array:
	if _sel_key < 0:
		return []
	var forms := _forms(_sel_key)
	if forms.size() < 2:
		return []
	var u := _pad.size.y / 100.0
	var w := 30.0 * u
	var h := 7.0 * u
	var x := _pad.size.x - 58.0 * u - w
	var y0 := _pad.size.y - 12.0 * u - forms.size() * (h + 1.5 * u)
	var out := []
	for j in forms.size():
		out.append({"rect": Rect2(x, y0 + j * (h + 1.5 * u), w, h), "form": forms[j], "index": j})
	return out


func _chip_at(pos: Vector2) -> Dictionary:
	for c: Dictionary in _chips():
		if (c.rect as Rect2).grow(_pad.size.y * 0.005).has_point(pos):
			return c
	return {}


# ---------------------------------------------------------------- the touches
func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_down(t.index, t.position)
		else:
			_up(t.index, t.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_drag(d.index, d.position, d.relative)
		get_viewport().set_input_as_handled()


func _down(i: int, pos: Vector2) -> void:
	if _touch.has(i):
		_up(i, pos)
	var chip := _chip_at(pos)
	if not chip.is_empty():
		_touch[i] = {"kind": "chip"}
		_choose(_sel_key, chip.form)
		_open_selector(_sel_key)
		return
	var b := _button_at(pos)
	if not b.is_empty():
		_touch[i] = {"kind": "button", "b": b, "t0": _now(), "at": pos, "moved": 0.0}
		if b.has("key"):
			var k := int(b.key)
			if _acts_at_once(k):
				_send(StringName("weapon_%d" % (k + 1)), true)
				return
			var hb := _hotbar()
			_touch[i]["was"] = hb != null and hb.readied_key() == k
			_ready_key(k)
			# (the key held as the finger is, so the stick pushed now picks the way (Hotbar._key_dir); aim held: a hold casts)
			_send(StringName("weapon_%d" % (k + 1)), true, 1.0, false)
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
				t.moved = maxf(float(t.moved), pos.distance_to(t.at))
				_look(rel)                          # (a held key's finger aims the lock)


func _up(i: int, pos := Vector2.ZERO) -> void:
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
			if not b.has("key"):
				_send(StringName(b.action), false)
				return
			var k := int(b.key)
			if _acts_at_once(k):
				_send(StringName("weapon_%d" % (k + 1)), false)
				return
			var tap := _now() - float(t.t0) < TAP_S and float(t.moved) < _pad.size.y * TAP_PX
			_send(&"aim", false)                    # (a tap: let go early, called off; a hold: cast)
			_send(StringName("weapon_%d" % (k + 1)), false, 1.0, false)
			if tap:
				if bool(t.get("was", false)):
					var forms := _forms(k)
					if forms.size() > 1:
						_choose(k, forms[(_form_now(k, forms) + 1) % forms.size()])
				_open_selector(k)
			elif _sel_key == k:
				_sel_key = -1                       # (cast: the selector goes)


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


## `action` pressed or let go. `as_event` false: the action's state only (Input.action_press / action_release), no event:
## a key held for Hotbar._key_dir without its press readying the key again (the key's tap: _ready_key does that).
func _send(action: StringName, pressed: bool, strength := 1.0, as_event := true) -> void:
	if not InputMap.has_action(action):
		return
	if not as_event:
		if pressed:
			Input.action_press(action, strength)
		else:
			Input.action_release(action)
		return
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	e.strength = strength if pressed else 0.0
	Input.parse_input_event(e)


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
		if b.has("key") and held.has(String(b.id)):
			_fill_ring(b.at, r)
		if b.has("key"):
			var col := _key_column(int(b.key))
			if bool(col.get("readied", false)):
				_pad.draw_arc(b.at, r + maxf(2.0, u * 0.6), 0.0, TAU, 40, Color(0.5, 0.83, 0.9, 0.95), maxf(2.0, u * 0.6), true)
			var n := String(col.get("label", ""))
			if n != "":
				var fs2 := int(maxf(9.0, u * 2.0))
				var sz2 := _font.get_string_size(n, HORIZONTAL_ALIGNMENT_CENTER, -1, fs2)
				_label(b.at + Vector2(-sz2.x * 0.5, r + fs2 * 1.1), n, fs2, Color(1, 1, 1, 0.9))
	var chips := _chips()
	if not chips.is_empty():
		var now_i := _form_now(_sel_key, _forms(_sel_key))
		for c: Dictionary in chips:
			var rr: Rect2 = c.rect
			var on := int(c.index) == now_i
			_pad.draw_rect(rr, Color(0.5, 0.83, 0.9, 0.75) if on else Color(0.05, 0.09, 0.12, 0.7))
			_pad.draw_rect(rr, rim, false, maxf(1.0, u * 0.25))
			var fs3 := int(maxf(9.0, u * 2.6))
			_label(rr.position + Vector2(u * 1.5, rr.size.y * 0.5 + fs3 * 0.35), String((c.form as Dictionary).label), fs3,
					Color.WHITE)
	if _holds("stick"):
		var reach := _pad.size.y * STICK_R
		_pad.draw_circle(_stick_at, reach, fill)
		_pad.draw_arc(_stick_at, reach, 0.0, TAU, 48, rim, maxf(1.5, u * 0.3), true)
		_pad.draw_circle(_stick_at + _stick_v * reach, reach * 0.42, lit)


## The lock's fill round a held key (SwayCaster.fill), gold once full: let go then, or it fizzles (moves fill at their own
## pace: the Column slower than the Fissure).
func _fill_ring(at: Vector2, r: float) -> void:
	var c := SwayCaster.of(player) if is_instance_valid(player) else null
	if c == null or c.state == SwayCaster.State.IDLE:
		return
	var u := _pad.size.y / 100.0
	var full := c.state != SwayCaster.State.LOCKING
	var k := 1.0 if full else clampf(c.fill, 0.0, 1.0)
	var col := Color(1.0, 0.82, 0.3, 0.95) if full else Color(1, 1, 1, 0.9)
	_pad.draw_arc(at, r + maxf(4.0, u * 1.4), -PI * 0.5, -PI * 0.5 + TAU * k, 48, col, maxf(3.0, u * 0.9), true)


## A label with a dark outline (it reads on the bright deck as on the water).
func _label(at: Vector2, text: String, fs: int, col: Color) -> void:
	_pad.draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(3, fs / 5), Color(0, 0, 0, 0.75))
	_pad.draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
