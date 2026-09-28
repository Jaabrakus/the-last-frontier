class_name ChestScreen
extends CanvasLayer
## A storage chest open (StorageChest.interact): the pack on the left, the chest on the right, each thing with its
## icon (ItemIcons) and how many. A click moves one across, a right-click all of that kind. The game is paused while it
## is open (as the pack screen); Esc, Tab or E closes it (when the key is let go, and the game goes on a frame later,
## so the key does not reach the player).
## In the other menus' lettering (user 2026-09-27: yes to the serif here too): FrontierHUD.serif(), Title Case headings
## in the Tab screen's gold.

const INK := Color(1.0, 0.95, 0.85)
const DIM := Color(0.66, 0.62, 0.56)
const HEAD := Color(0.93, 0.8, 0.52)

var player: Node
## What it shows beside the pack: a StorageChest, or anything with its container side (items, open, title(),
## accepts(kind), put(inv, kind, n), take(inv, kind, n)): the Wheelbarrow's bed.
var chest: Node
var icons: ItemIcons
var _was_mouse := Input.MOUSE_MODE_CAPTURED
var _pack_box: VBoxContainer
var _chest_box: VBoxContainer
var _pack_head: Label
var _chest_head: Label
var _note: Label
var _done := false
var _icon_t := 0.0


static func open_for(p: Node, c: Node) -> ChestScreen:
	var s := ChestScreen.new()
	s.player = p
	s.chest = c
	p.get_tree().root.add_child(s)
	return s


func _ready() -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	chest.open = true
	icons = ItemIcons.shared(get_tree())
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.05, 0.92)
	sb.border_color = Color(0.55, 0.45, 0.3, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	for m in ["content_margin_left", "content_margin_right", "content_margin_top", "content_margin_bottom"]:
		sb.set(m, 16)
	panel.add_theme_stylebox_override("panel", sb)
	var th := Theme.new()
	th.default_font = FrontierHUD.serif()
	panel.theme = th
	panel.set_anchors_preset(Control.PRESET_CENTER)
	add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)
	outer.add_child(_label(String(chest.title()).capitalize(), 26, HEAD))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	outer.add_child(cols)
	var left := _column()
	_pack_head = left[0]
	_pack_box = left[1]
	cols.add_child(left[2])
	var right := _column()
	_chest_head = right[0]
	_chest_box = right[1]
	cols.add_child(right[2])
	# everything at once, either way (user 2026-09-27: "add a button to unload everything")
	var all := HBoxContainer.new()
	all.add_theme_constant_override("separation", 24)
	outer.add_child(all)
	for pair in [["Load everything", true], ["Unload everything", false]]:
		var b := Button.new()
		b.text = String(pair[0])
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 17)
		b.custom_minimum_size = Vector2(300, 36)
		var from_pack: bool = pair[1]
		b.pressed.connect(func() -> void: move_all(from_pack))
		all.add_child(b)
	_note = _label("Click: move one     Right-click: move them all     Esc: close", 15, DIM)
	outer.add_child(_note)
	# centred on the screen, growing both ways from its middle (setting position to -size / 2 put it in the top-left
	# corner, mostly off the screen)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	refresh()


func _column() -> Array:
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(300, 0)
	var head := _label("", 21, HEAD)
	v.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 3)
	scroll.add_child(box)
	return [head, box, v]


func _label(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


## The pack's things that can go in a chest ([kind, count]).
func pack_rows() -> Array:
	var out: Array = []
	var inv := InventoryState.from_player(player)
	for e: Dictionary in inv.pack:
		var k := String(e.kind)
		if chest.accepts(k) and int(e.count) > 0:
			out.append([k, int(e.count)])
	return out


func refresh() -> void:
	for box: VBoxContainer in [_pack_box, _chest_box]:
		for c in box.get_children():
			box.remove_child(c)
			c.queue_free()
	var pr := pack_rows()
	_pack_head.text = "Pack"
	for r: Array in pr:
		_pack_box.add_child(_row(String(r[0]), int(r[1]), true))
	if pr.is_empty():
		_pack_box.add_child(_label("No food in the pack" if chest is Smokehouse else "Nothing loose in the pack", 16, DIM))
	_chest_head.text = (String(chest.call(&"column_name")) if chest.has_method(&"column_name") else "Chest").capitalize()
	for e: Dictionary in chest.items:
		_chest_box.add_child(_row(String(e.kind), int(e.count), false))
	if chest.items.is_empty():
		_chest_box.add_child(_label("Empty", 16, DIM))


func _row(kind: String, n: int, from_pack: bool) -> Button:
	var b := Button.new()
	b.text = "  %s   ×%d" % [InventoryState.name_of(kind), n]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.icon = icons.get_icon(kind) if icons else null
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", 32)
	b.add_theme_font_size_override("font_size", 18)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 38)
	b.set_meta(&"kind", kind)
	b.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			move(kind, from_pack, 1 if ev.button_index == MOUSE_BUTTON_LEFT else 1 << 30)
			b.accept_event())
	return b


## Moves `n` of `kind` from the pack into the chest (`from_pack`) or back.
func move(kind: String, from_pack: bool, n: int) -> int:
	var inv := InventoryState.from_player(player)
	var got: int = chest.put(inv, kind, n) if from_pack else chest.take(inv, kind, n)
	player.set("inventory_pack", inv.pack.duplicate(true))
	refresh.call_deferred()
	return got


## Everything the pack has that goes in, into the chest (`from_pack`), or everything in the chest back into the pack.
## How many things moved.
func move_all(from_pack: bool) -> int:
	var kinds: Array = []
	if from_pack:
		for r: Array in pack_rows():
			kinds.append(String(r[0]))
	else:
		for e: Dictionary in chest.items:
			kinds.append(String(e.kind))
	var n := 0
	for k: String in kinds:
		n += move(k, from_pack, 1 << 30)
	return n


func _process(dt: float) -> void:
	# the icons paint a few frames after they are asked for
	_icon_t -= dt
	if _icon_t <= 0.0:
		_icon_t = 0.4
		for box: VBoxContainer in [_pack_box, _chest_box]:
			for c in box.get_children():
				if c is Button and (c as Button).icon == null and c.has_meta(&"kind"):
					(c as Button).icon = icons.get_icon(String(c.get_meta(&"kind")))


func _input(event: InputEvent) -> void:
	if _done or not (event is InputEventKey) or event.echo:
		return
	var k := (event as InputEventKey).physical_keycode
	if k in [KEY_ESCAPE, KEY_TAB, KEY_E]:
		get_viewport().set_input_as_handled()
		if not event.pressed:
			close()


func close() -> void:
	if _done:
		return
	_done = true
	visible = false
	chest.open = false
	Input.mouse_mode = _was_mouse if _was_mouse != Input.MOUSE_MODE_VISIBLE else Input.MOUSE_MODE_CAPTURED
	await get_tree().process_frame
	get_tree().paused = false
	queue_free()
