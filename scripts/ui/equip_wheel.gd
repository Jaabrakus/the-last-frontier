class_name EquipWheel
extends CanvasLayer
## The equip wheel (user 2026-09-26: "no wheel as in like a hud wheel we use our mouse to select a weapon or tool"):
## hold Q (the game runs on at full speed: user "no slow mo on the wheel"); the weapons, the tools, the torch and bare
## hands sit round a ring; the mouse picks one
## by the way it is moved (the camera does not turn meanwhile); a left click takes the one picked (user "its left
## click to equip right"), and so does letting go of Q. Moving the mouse less than PICK_MIN px picks nothing: letting
## go then changes nothing. The weapon in the hands takes no fire / aim input while the wheel is open, nor while the
## click that closed it is still held (blocks_fire()). 1-9 (the hotbar), T, H and the mouse wheel keep working as before.
##
##   EquipWheel.install(player)      # FrontierPlayer does it
##
## Slots, clockwise from the top: only what is on the hotbar (the owner, 2026-10-02: the wheel "lists only hotbar
## entries"; Hotbar), in its slots' order: a weapon "w:<key>", a tool "t:<kind>", a spell "s:<id>"; then bare hands (H).
## Taken through the hotbar (Hotbar.take: as its number key, never a toggle). A slot that cannot be taken now is shown
## dimmed and cannot be picked.

const ACTION := &"equip_wheel"
const KEY := KEY_Q
const RADIUS := 200.0
const INNER := 74.0
const ICON := 70.0
## Mouse travel (px) before a slot is picked.
const PICK_MIN := 36.0
const COL_BG := Color(0.07, 0.06, 0.05, 0.78)
const COL_SEL := Color(0.86, 0.66, 0.34, 0.55)
const COL_LINE := Color(0.9, 0.82, 0.66, 0.35)
const COL_TEXT := Color(0.96, 0.9, 0.78)
const COL_DIM := Color(0.6, 0.55, 0.5, 0.45)

var player: FrontierPlayer
## [{id: "w:<key>" | "t:<tool>" | "s:<spell>" | "hands", slot (the hotbar's, -1 for hands), kind (icon), name, usable, note}]
var slots: Array = []
var sel := -1
var is_open := false
var _dir := Vector2.ZERO
var _was_down := false
var _hold_fire := false         ## the click that took a slot is still held: the weapon ignores it
var _ring: Control
var _icons: Array = []
var _names: Array = []
var _title: Label
var _note: Label


static func install(p: FrontierPlayer) -> EquipWheel:
	ensure_input()
	var w := EquipWheel.new()
	w.name = "EquipWheel"
	w.player = p
	p.add_child(w)
	return w


static func ensure_input() -> void:
	if InputMap.has_action(ACTION):
		return
	InputMap.add_action(ACTION)
	var e := InputEventKey.new()
	e.physical_keycode = KEY
	InputMap.action_add_event(ACTION, e)


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ring = Control.new()
	_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	_title = _label(24)
	_note = _label(15)
	_note.add_theme_color_override("font_color", Color(0.85, 0.78, 0.66))
	_ring.add_child(_title)
	_ring.add_child(_note)
	visible = false


func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", COL_TEXT)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var down := InputMap.has_action(ACTION) and Input.is_action_pressed(ACTION)
	if down and not _was_down and _can_open():
		open()
	elif _was_down and not down and is_open:
		close(true)
	_was_down = down
	if is_open and (player.is_dead or player.riding != null):
		close(false)


func _can_open() -> bool:
	return not player.is_dead and player.riding == null and not get_tree().paused \
			and not (player.traversal != null and player.traversal.showing)


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	var mm := event as InputEventMouseMotion
	if mm:
		pick_toward(_dir + mm.relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		if sel >= 0:
			_hold_fire = true
			close(true)
	elif event.is_action("weapon_next") or event.is_action("weapon_prev") or event.is_action("fire") or event.is_action("aim"):
		get_viewport().set_input_as_handled()


## The weapon in the hands takes no fire / aim input now (Weapon._fire_input_enabled).
func blocks_fire() -> bool:
	if _hold_fire and not Input.is_action_pressed(&"fire"):
		_hold_fire = false
	return is_open or _hold_fire


# --- open, pick, take ------------------------------------------------------------------------------------------

func open() -> void:
	_build_slots()
	if slots.is_empty():
		return
	is_open = true
	sel = -1
	_dir = Vector2.ZERO
	_layout()
	visible = true
	_refresh()


## Closes the wheel; `take`: equips the picked slot.
func close(take: bool) -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	if take and sel >= 0 and sel < slots.size() and bool(slots[sel].usable):
		take_slot(slots[sel])


## Picks the slot in the direction of `d` (screen space, y down; the mouse travel since the wheel opened).
func pick_toward(d: Vector2) -> void:
	_dir = d.limit_length(RADIUS)
	if _dir.length() < PICK_MIN or slots.is_empty():
		sel = -1
	else:
		var n := slots.size()
		var ang := fposmod(atan2(_dir.x, -_dir.y), TAU)        # 0 at the top, clockwise
		var i := int(round(ang / (TAU / n))) % n
		sel = i if bool(slots[i].usable) else -1
	_refresh()


## Takes `s`: a hotbar slot's thing (Hotbar.take), or bare hands.
func take_slot(s: Dictionary) -> void:
	var hb: Hotbar = player.hotbar
	var i := int(s.get("slot", -1))
	if String(s.id) == "hands":
		if hb != null:
			hb.hands_free()
		else:
			var g: GatherTools = player.gather if player.get("gather") != null else null
			if g != null and g.in_hand() != "":
				g.put_away()
			if not player.hands_free:
				player.toggle_hands_free()
	elif hb != null and i >= 0:
		hb.take(i)


## The hotbar's filled slots in order, then bare hands.
func _build_slots() -> void:
	slots.clear()
	var hb: Hotbar = player.hotbar
	if hb != null:
		for i in Hotbar.SLOTS:
			var e := hb.entry(i)
			if e.is_empty():
				continue
			var id := String(e.id)
			var kind := hb.icon_kind(i)
			var note := "%d" % (i + 1)
			var ok := true
			match String(e.kind):
				Hotbar.WEAPON:
					var w: Weapon = player.weapons.get(id)
					if w is Throwable:
						note += "  x%d" % (w as Throwable).count
					ok = player.is_usable(id)
					slots.append({"id": "w:" + id, "slot": i, "kind": kind, "name": hb.label(i), "usable": ok, "note": note})
				Hotbar.TOOL:
					slots.append({"id": "t:" + id, "slot": i, "kind": kind, "name": hb.label(i), "usable": true, "note": note})
				Hotbar.SPELL:
					slots.append({"id": "s:" + id, "slot": i, "kind": "", "name": hb.label(i), "usable": true, "note": note})
	slots.append({"id": "hands", "slot": -1, "kind": "", "name": "Hands free", "usable": true, "note": "H"})


# --- drawing ---------------------------------------------------------------------------------------------------

func _center() -> Vector2:
	return _ring.get_viewport_rect().size * 0.5


func _slot_pos(i: int) -> Vector2:
	var n := maxi(slots.size(), 1)
	var a := i * TAU / n
	var r := (RADIUS + INNER) * 0.5
	return _center() + Vector2(sin(a), -cos(a)) * r


func _layout() -> void:
	for c in _icons:
		(c as Node).queue_free()
	for c in _names:
		(c as Node).queue_free()
	_icons.clear()
	_names.clear()
	var icons := ItemIcons.shared(get_tree())
	for i in slots.size():
		var s: Dictionary = slots[i]
		var tr := TextureRect.new()
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size = Vector2(ICON, ICON)
		tr.position = _slot_pos(i) - tr.size * 0.5
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if String(s.kind) != "":
			tr.texture = icons.get_icon(String(s.kind))
			if tr.texture == null and not icons.ready_icon.is_connected(_on_icon):
				icons.ready_icon.connect(_on_icon)
		_ring.add_child(tr)
		_icons.append(tr)
		var l := _label(13)
		l.text = String(s.name) if String(s.kind) == "" or tr.texture == null else ""
		l.size = Vector2(120, 20)
		l.position = _slot_pos(i) + Vector2(-60, -10)
		_ring.add_child(l)
		_names.append(l)
	_title.size = Vector2(320, 34)
	_title.position = _center() + Vector2(-160, -30)
	_note.size = Vector2(320, 24)
	_note.position = _center() + Vector2(-160, 6)


func _on_icon(_kind: String) -> void:
	if not is_open:
		return
	var icons := ItemIcons.shared(get_tree())
	for i in slots.size():
		if i < _icons.size() and String(slots[i].kind) != "" and (_icons[i] as TextureRect).texture == null:
			(_icons[i] as TextureRect).texture = icons.get_icon(String(slots[i].kind))
			if (_icons[i] as TextureRect).texture != null:
				(_names[i] as Label).text = ""


func _refresh() -> void:
	for i in _icons.size():
		var usable := bool(slots[i].usable)
		(_icons[i] as TextureRect).modulate = Color(1, 1, 1, 1) if usable else COL_DIM
		(_icons[i] as TextureRect).scale = Vector2.ONE * (1.18 if i == sel else 1.0)
		(_icons[i] as TextureRect).pivot_offset = Vector2(ICON, ICON) * 0.5
	if sel >= 0:
		_title.text = String(slots[sel].name)
		_note.text = String(slots[sel].note)
	else:
		_title.text = "Equip"
		_note.text = "move the mouse to pick, click to take"
	_ring.queue_redraw()


func _draw_ring() -> void:
	if not is_open:
		return
	var c := _center()
	var n := maxi(slots.size(), 1)
	var step := TAU / n
	_ring.draw_circle(c, RADIUS + 8.0, COL_BG)
	_ring.draw_circle(c, INNER - 6.0, Color(0.03, 0.03, 0.02, 0.85))
	if sel >= 0:
		var a0 := sel * step - step * 0.5 - PI * 0.5
		var pts := PackedVector2Array()
		for k in 17:
			var a := a0 + step * k / 16.0
			pts.append(c + Vector2(cos(a), sin(a)) * (RADIUS + 4.0))
		for k in range(16, -1, -1):
			var a := a0 + step * k / 16.0
			pts.append(c + Vector2(cos(a), sin(a)) * INNER)
		_ring.draw_colored_polygon(pts, COL_SEL)
	for i in n:
		var a := i * step - step * 0.5 - PI * 0.5
		var d := Vector2(cos(a), sin(a))
		_ring.draw_line(c + d * INNER, c + d * (RADIUS + 4.0), COL_LINE, 2.0, true)
	_ring.draw_arc(c, RADIUS + 8.0, 0.0, TAU, 96, COL_LINE, 2.0, true)
	if _dir.length() > 1.0:
		_ring.draw_line(c, c + _dir.normalized() * (INNER - 12.0), COL_SEL.lightened(0.3), 3.0, true)
