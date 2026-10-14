class_name TouchControls
extends CanvasLayer
## Touch controls for the web build on a phone or a tablet (the owner, 2026-10-13: "if you want to build touch controls do it
## now as well"): the arena played with the thumbs through the same actions as the keys and the mouse, sent as action events
## (Input.parse_input_event: the hotbar, the caster and RingMoves see a press as they see a key's).
##   left thumb   a stick where it lands on the left of the screen: move_forward / back / left / right, by how far it is pushed
##   right thumb  dragged anywhere free: the look (the player's yaw and pitch, as the mouse turns them)
##   1-5          (the owner, 2026-10-13, with the tap style: "that is nice for drag to cast ... how are we changing the
##                spells on touch", then "lets implement"; 2026-10-14: "only hold and release cast"): each key's button
##                casts its own skill, no readying first, held and let go:
##                  hold, let go its skill cast; let go before its wind-up is full, it runs on to it (MatchSetup.cast_style
##                               "tap"); its cooldown's sweep over the button (SwayCaster.cooldown_share)
##                  tap          (let go within TAP_S, not dragged, its ring not yet full) nothing cast, nothing spent: its
##                               skill left readied
##                  drag         past DRAG_PX the finger aims (the look) while it winds up and while it is held; let go: cast.
##                               Dragged back onto its button and let go there: called off (SwayCaster.cancel_lock)
##                  hold still   a skill that grows grows (the Fireball, a grown Spike or Boulder; the stone held before him
##                               shields him meanwhile); let go: cast. The stick pushed meanwhile picks the way, as W, A, S or
##                               D with the key held (Hotbar._key_dir: the Column's throws, the Geyser's ways)
##                  the tag      a key with two skills (Spike and Boulder, Fissure and Column) wears a tag at its corner naming
##                               the other; tapped: that one is the key's now (no cast)
##                Key 3 where it acts at once (the movement spell: no move of its own, Bending.key3) is the key as pressed.
##                Each key's button names what it casts now (the strip's column label); held, the lock's fill runs round it
##                (gold: full); CastGuide draws where it will go
##   JAB          fire (the left button's quick spell); held, it fires again as each volley's lock fills (the tap style)
##   GUARD        bend_guard (E), beside the jab        JUMP  jump (Space)
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
## A key's touch let go within this (s), not dragged (DRAG_PX) and before its lock is full is a tap: nothing cast (only a hold
## and let go casts; a ring already full casts, as it shows).
const TAP_S := 0.25
## A key's finger moved this far (of the screen's height) aims (the look); less is a tap's wobble.
const DRAG_PX := 0.02
## A key's tag (its other skill): its place off the button's corner (of the button's radius) and its size.
const TAG_OFF := 1.05
const TAG_R := 0.42
## The actions the mouse's buttons are taken off while the layer is up.
const MOUSE_ACTIONS := [&"fire", &"aim", &"weapon_next", &"weapon_prev"]

var player: FrontierPlayer
var forced := false
## Up whatever holds the mouse (the tests: tests/ui/test_touch_cast.gd).
var force_up := false

var _pad: Control
var _font: Font
var _active := false
## touch index -> what it holds: {"kind": "stick" | "look" | "button" | "tag", "b": the button, ...}
var _touch := {}
var _stick_at := Vector2.ZERO
var _stick_v := Vector2.ZERO
var _move := {&"move_left": 0.0, &"move_right": 0.0, &"move_forward": 0.0, &"move_back": 0.0}
## The mouse buttons taken off MOUSE_ACTIONS while up: action -> [events].
var _unbound := {}
## The jab held (the tap style): let go as its lock fills, pressed again as the caster is free (_jab_cycle).
var _jab_again := false


static func wanted() -> bool:
	if not OS.has_feature("web"):
		return false
	return bool(JavaScriptBridge.eval(
			"(matchMedia('(pointer: coarse)').matches && navigator.maxTouchPoints > 0) || /[?&]touch=1/.test(location.search)",
			true))


## The touch layer up for `p` now (CastGuide's "touch").
static func up(p: Node) -> bool:
	var t := p.get_node_or_null(^"TouchControls") as TouchControls if p != null and is_instance_valid(p) else null
	return t != null and t._active


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
	var up := is_instance_valid(player) and not get_tree().paused and (force_up or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	if up != _active:
		_set_active(up)
	if _active:
		_jab_cycle()
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


## The game's clock (s): its physics frames, so that a tap's TAP_S is the frames the caster saw (the tests run them faster than
## the wall's clock).
func _now() -> float:
	return float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)


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


## Key i's own skills (its moves, KitWords.key_moves: one or two), not their ways (the stick picks a way as it casts).
func _skills(i: int) -> Array:
	var out := []
	for f: Dictionary in _forms(i):
		var dup := false
		for o: Dictionary in out:
			dup = dup or (String(o.id) == String(f.id) and String(o.mode) == String(f.mode))
		if not dup:
			out.append({"id": f.id, "mode": f.mode, "way": "", "label": KitWords.move_name(String(f.id), String(f.mode))})
	return out


## Key i's skill now (its index in _skills: the strip's column for it).
func _skill_now(i: int, skills: Array) -> int:
	var col := _key_column(i)
	for j in skills.size():
		var f: Dictionary = skills[j]
		if String(f.id) == String(col.get("id", "")) and String(f.mode) == String(col.get("mode", "")):
			return j
	return 0


## Key b's tag: {at, r, other (the skill it turns the key to), label}; {} for a key of one skill or one that acts at once.
func _tag(b: Dictionary) -> Dictionary:
	if not b.has("key") or _acts_at_once(int(b.key)):
		return {}
	var k := int(b.key)
	var skills := _skills(k)
	if skills.size() < 2:
		return {}
	var other: Dictionary = skills[(_skill_now(k, skills) + 1) % skills.size()]
	var r := float(b.r)
	var name := String(other.label).split(" ")[0]
	return {"at": (b.at as Vector2) + Vector2(-0.72, -0.72) * r * TAG_OFF, "r": r * TAG_R, "other": other,
			"label": name}


func _tag_at(pos: Vector2) -> Dictionary:
	for b: Dictionary in _buttons():
		var t := _tag(b)
		if not t.is_empty() and pos.distance_to(t.at) <= float(t.r) * HIT_SLACK:
			t["key"] = b.key
			return t
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
	var tag := _tag_at(pos)
	if not tag.is_empty():
		_touch[i] = {"kind": "tag"}
		_choose(int(tag.key), tag.other)            # (the key's other skill is its own now; nothing cast)
		return
	var b := _button_at(pos)
	if not b.is_empty():
		_touch[i] = {"kind": "button", "b": b, "t0": _now(), "at": pos, "moved": 0.0}
		if b.has("key"):
			var k := int(b.key)
			if _acts_at_once(k):
				_send(StringName("weapon_%d" % (k + 1)), true)
				return
			_ready_key(k)
			# (the key held as the finger is, so the stick pushed now picks the way (Hotbar._key_dir); the aim held: it locks,
			# a tap's let go runs on in the tap style, a hold grows, a drag aims)
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
				if float(t.moved) >= _pad.size.y * DRAG_PX:
					_look(rel)                      # (a held key's finger dragged aims the lock; a tap's wobble does not)


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
				if String(b.id) == "jab":
					_jab_again = false
				return
			var k := int(b.key)
			if _acts_at_once(k):
				_send(StringName("weapon_%d" % (k + 1)), false)
				return
			var c := SwayCaster.of(player) if is_instance_valid(player) else null
			var full := c != null and c.state in [SwayCaster.State.FULL, SwayCaster.State.HOLDING]
			var dragged := float(t.moved) >= _pad.size.y * DRAG_PX
			var tap := not dragged and not full and _now() - float(t.t0) < TAP_S
			var back := dragged and pos.distance_to(b.at) <= float(b.r) * HIT_SLACK
			if tap or back:
				# (a tap: only a hold and let go casts (the owner, 2026-10-14), its skill left readied; dragged out and back
				# onto its button: called off. Nothing spent either way)
				_send(&"aim", false, 1.0, false)
				if c != null:
					c.cancel_lock()
				_send(&"aim", false)
			else:
				_send(&"aim", false)                # (held and let go: cast; let go before its wind-up is full, it runs on)
			_send(StringName("weapon_%d" % (k + 1)), false, 1.0, false)


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


## The jab held under the tap style: let go the moment its lock is full (it casts), pressed again once the caster is free, so
## a held thumb fires volley after volley at the jab's own pace.
func _jab_cycle() -> void:
	var held := false
	for t: Dictionary in _touch.values():
		held = held or (String(t.kind) == "button" and String((t.b as Dictionary).id) == "jab")
	var c := SwayCaster.of(player) if is_instance_valid(player) else null
	if not held or c == null or not c.tap_on():
		_jab_again = false
		return
	if not _jab_again and c.lock_src == SwayCaster.SRC_QUICK and c.state in [SwayCaster.State.FULL, SwayCaster.State.HOLDING]:
		_send(&"fire", false)
		_jab_again = true
	elif _jab_again and c.state == SwayCaster.State.IDLE:
		_send(&"fire", true)
		_jab_again = false


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
			_cooldown(b.at, r, col)
			var tg := _tag(b)
			if not tg.is_empty():
				var tr := float(tg.r)
				_pad.draw_circle(tg.at, tr, Color(0.05, 0.09, 0.12, 0.7))
				_pad.draw_arc(tg.at, tr, 0.0, TAU, 28, rim, maxf(1.0, u * 0.25), true)
				var fs4 := int(maxf(9.0, tr * 0.62))
				var tl := String(tg.label)
				var sz4 := _font.get_string_size(tl, HORIZONTAL_ALIGNMENT_CENTER, -1, fs4)
				if sz4.x > tr * 1.9:                # (the word whole, its type made smaller to sit in the tag)
					fs4 = int(maxf(8.0, fs4 * tr * 1.9 / sz4.x))
					sz4 = _font.get_string_size(tl, HORIZONTAL_ALIGNMENT_CENTER, -1, fs4)
				_label(tg.at + Vector2(-sz4.x * 0.5, fs4 * 0.35), tl, fs4, Color(1, 1, 1, 0.95))
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


## Key's skill's cooldown (the tap style) as the strip's sweep over its button, the seconds left over it.
func _cooldown(at: Vector2, r: float, col: Dictionary) -> void:
	var c := SwayCaster.of(player) if is_instance_valid(player) else null
	if c == null or String(col.get("id", "")) == "":
		return
	var k := c.cooldown_share(String(col.id), String(col.get("mode", "")))
	if k <= 0.0:
		return
	var pts := PackedVector2Array([at])
	var n := maxi(int(40.0 * k), 2)
	for j in n + 1:
		var a := -PI * 0.5 + TAU * (1.0 - k) + TAU * k * float(j) / float(n)
		pts.append(at + Vector2(cos(a), sin(a)) * r)
	_pad.draw_colored_polygon(pts, Color(0.0, 0.0, 0.0, 0.55))
	var left := c.cooldown_left(String(col.id), String(col.get("mode", "")))
	var txt := ("%d" % ceili(left)) if left >= 1.0 else ("%.1f" % left)
	var fs := int(maxf(10.0, r * 0.5))
	var sz := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	_label(at + Vector2(-sz.x * 0.5, -r * 0.2), txt, fs, Color(1, 1, 1, 0.95))


## A label with a dark outline (it reads on the bright deck as on the water).
func _label(at: Vector2, text: String, fs: int, col: Color) -> void:
	_pad.draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(3, fs / 5), Color(0, 0, 0, 0.75))
	_pad.draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
