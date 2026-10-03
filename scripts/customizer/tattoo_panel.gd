class_name TattooPanel
extends PanelContainer
## The character creator's tattoo editor (CharacterCreator: a click on the Tattoos row's value opens it over the
## people panel). In the creator's style (its panels, rows and buttons):
##   the look's tattoos, one button each (the chosen one in gold), and Add (up to Tattoos.max_count());
##   for the chosen tattoo: "<  Design  >", "<  Place  >", "<  Ink  >" rows, a Fade slider (fresh .. old), Move
##   (left, right, up, down as seen, and back to the place's centre), Size (smaller, larger), Turn (each way);
##   the design's period note; Remove and Done.
## Every change edits the creator's look in place (Tattoos) and emits `changed` with the chosen tattoo's place (the
## creator re-dresses the stage and frames that place); `closed` when Done is pressed.

signal changed(place_id: String)
signal closed

const W := 372

var look_of: Callable
var selected := -1
var _list_box: VBoxContainer
var _count: Label
var _add: Button
var _editor: VBoxContainer
var _design_value: Label
var _place_value: Label
var _ink_value: Label
var _ink_chip: ColorRect
var _fade: HSlider
var _note: Label
var _quiet := false


## A panel editing the look `look_of` returns (the creator's current look; it changes with the people and the dice).
static func create(look_getter: Callable) -> TattooPanel:
	var p := TattooPanel.new()
	p.look_of = look_getter
	return p


func _look() -> Dictionary:
	return look_of.call() if look_of.is_valid() else {}


func _ready() -> void:
	name = "TattooPanel"
	add_theme_stylebox_override("panel", CharacterCreator._panel_style(Color(0.04, 0.045, 0.05, 0.92), CharacterCreator.GOLD))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	var title := CharacterCreator._label("Tattoos", 22, CharacterCreator.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_count = CharacterCreator._label("", 13, CharacterCreator.DIM)
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_count)
	var intro := CharacterCreator._label("Our own sailors' and sky crews' marks, for anyone. A tattoo is skin: clothes cover it.",
			12, CharacterCreator.DIM)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(W - 24, 0)
	vb.add_child(intro)
	_list_box = VBoxContainer.new()
	_list_box.name = "List"
	_list_box.add_theme_constant_override("separation", 3)
	vb.add_child(_list_box)
	_add = _button("Add a tattoo", Vector2(0, 32), _on_add, 14)
	_add.name = "Add"
	vb.add_child(_add)
	_editor = VBoxContainer.new()
	_editor.name = "Editor"
	_editor.add_theme_constant_override("separation", 4)
	vb.add_child(_editor)
	var r := _step_row("Design", func(d: int) -> void: _edit(func(lk: Dictionary) -> void: Tattoos.step_design(lk, selected, d)))
	_design_value = r
	r = _step_row("Place", func(d: int) -> void: _edit(func(lk: Dictionary) -> void: Tattoos.step_place(lk, selected, d)))
	_place_value = r
	r = _step_row("Ink", func(d: int) -> void: _edit(func(lk: Dictionary) -> void: Tattoos.step_ink(lk, selected, d)), true)
	_ink_value = r
	var fh := HBoxContainer.new()
	fh.add_theme_constant_override("separation", 8)
	_editor.add_child(fh)
	var fl := CharacterCreator._label("Fade", 13, CharacterCreator.DIM)
	fl.custom_minimum_size = Vector2(64, 0)
	fh.add_child(fl)
	fh.add_child(CharacterCreator._label("fresh", 11, CharacterCreator.DIM))
	_fade = HSlider.new()
	_fade.name = "Fade"
	_fade.min_value = 0.0
	_fade.max_value = 1.0
	_fade.step = 0.05
	_fade.focus_mode = Control.FOCUS_NONE
	_fade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fade.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_fade.value_changed.connect(func(v: float) -> void:
		if not _quiet:
			_edit(func(lk: Dictionary) -> void: Tattoos.set_fade(lk, selected, v)))
	fh.add_child(_fade)
	fh.add_child(CharacterCreator._label("old", 11, CharacterCreator.DIM))
	var step := Tattoos.MOVE_STEP
	_tool_row("Move", [["Left", func(lk: Dictionary) -> void: Tattoos.move(lk, selected, -step, 0.0)],
			["Right", func(lk: Dictionary) -> void: Tattoos.move(lk, selected, step, 0.0)],
			["Up", func(lk: Dictionary) -> void: Tattoos.move(lk, selected, 0.0, step)],
			["Down", func(lk: Dictionary) -> void: Tattoos.move(lk, selected, 0.0, -step)],
			["Centre", func(lk: Dictionary) -> void:
				var t: Dictionary = Tattoos.list(lk)[selected]
				t["x"] = 0.0
				t["y"] = 0.0]])
	_tool_row("Size", [["Smaller", func(lk: Dictionary) -> void: Tattoos.resize(lk, selected, 1.0 / Tattoos.SCALE_STEP)],
			["Larger", func(lk: Dictionary) -> void: Tattoos.resize(lk, selected, Tattoos.SCALE_STEP)]])
	_tool_row("Turn", [["Left", func(lk: Dictionary) -> void: Tattoos.turn(lk, selected, Tattoos.TURN_STEP)],
			["Right", func(lk: Dictionary) -> void: Tattoos.turn(lk, selected, -Tattoos.TURN_STEP)]])
	_note = CharacterCreator._label("", 12, CharacterCreator.DIM)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(W - 24, 0)
	_note.max_lines_visible = 3
	_editor.add_child(_note)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(sp)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	vb.add_child(bottom)
	var rm := _button("Remove", Vector2(110, 34), _on_remove, 14)
	rm.name = "Remove"
	bottom.add_child(rm)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(gap)
	var done := _button("Done", Vector2(110, 34), func() -> void: closed.emit(), 14)
	done.name = "Done"
	bottom.add_child(done)
	var a := Tattoos.list(_look())
	selected = a.size() - 1
	refresh()


func _button(text: String, min_size: Vector2, cb: Callable, size := 14) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", CharacterCreator.TEXT)
	b.add_theme_color_override("font_hover_color", CharacterCreator.GOLD)
	b.add_theme_color_override("font_disabled_color", CharacterCreator.DIM)
	var n := CharacterCreator._panel_style(Color(0.1, 0.1, 0.1, 0.85), CharacterCreator.PANEL_EDGE, 5.0)
	var h := CharacterCreator._panel_style(Color(0.18, 0.15, 0.1, 0.9), CharacterCreator.GOLD, 5.0)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("disabled", CharacterCreator._panel_style(Color(0.07, 0.07, 0.07, 0.6), Color(0, 0, 0, 0), 5.0))
	b.pressed.connect(cb)
	return b


## "<  Title / value  >" in the creator's row style; returns the value label.
func _step_row(title: String, step: Callable, chip := false) -> Label:
	var panel := PanelContainer.new()
	panel.name = "Row_" + title
	panel.add_theme_stylebox_override("panel", CharacterCreator._panel_style(CharacterCreator.ROW_BG, Color(0, 0, 0, 0), 3.0))
	_editor.add_child(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	panel.add_child(hb)
	var prev := _button("<", Vector2(30, 34), func() -> void: step.call(-1), 16)
	prev.name = "Prev"
	hb.add_child(prev)
	if chip:
		_ink_chip = ColorRect.new()
		_ink_chip.custom_minimum_size = Vector2(16, 16)
		_ink_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(_ink_chip)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", -2)
	hb.add_child(texts)
	texts.add_child(CharacterCreator._label(title, 11, CharacterCreator.DIM))
	var value := CharacterCreator._label("", 14, CharacterCreator.TEXT)
	value.clip_text = true
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(value)
	var nxt := _button(">", Vector2(30, 34), func() -> void: step.call(1), 16)
	nxt.name = "Next"
	hb.add_child(nxt)
	return value


func _tool_row(title: String, tools: Array) -> void:
	var hb := HBoxContainer.new()
	hb.name = "Tools_" + title
	hb.add_theme_constant_override("separation", 4)
	_editor.add_child(hb)
	var l := CharacterCreator._label(title, 13, CharacterCreator.DIM)
	l.custom_minimum_size = Vector2(64, 0)
	hb.add_child(l)
	for t: Array in tools:
		var fn: Callable = t[1]
		var b := _button(String(t[0]), Vector2(0, 28), func() -> void: _edit(fn), 12)
		b.name = title + "_" + String(t[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(b)


## Applies `fn(look)` to the chosen tattoo and tells the creator.
func _edit(fn: Callable) -> void:
	var lk := _look()
	if selected < 0 or selected >= Tattoos.list(lk).size():
		return
	fn.call(lk)
	refresh()
	changed.emit(String(Tattoos.list(lk)[selected].get("place", "")))


func _on_add() -> void:
	var lk := _look()
	# the next design the look does not wear yet, at its own place (Tattoos.default_place)
	var worn := Tattoos.list(lk).map(func(t: Dictionary) -> String: return String(t.get("design", "")))
	var id := "anchor"
	for d: Dictionary in Tattoos.designs():
		if not String(d.id) in worn:
			id = String(d.id)
			break
	var i := Tattoos.add(lk, id)
	if i < 0:
		return
	selected = i
	refresh()
	changed.emit(String(Tattoos.list(lk)[i].place))


func _on_remove() -> void:
	var lk := _look()
	if not Tattoos.remove(lk, selected):
		return
	selected = mini(selected, Tattoos.list(lk).size() - 1)
	refresh()
	changed.emit(String(Tattoos.list(lk)[selected].place) if selected >= 0 else "")


func select(i: int) -> void:
	selected = i
	refresh()
	var a := Tattoos.list(_look())
	changed.emit(String(a[i].place) if i >= 0 and i < a.size() else "")


## The chosen tattoo's place ("" with none).
func selected_place() -> String:
	var a := Tattoos.list(_look())
	return String(a[selected].get("place", "")) if selected >= 0 and selected < a.size() else ""


func refresh() -> void:
	if _list_box == null:
		return
	var lk := _look()
	var a := Tattoos.list(lk)
	if selected >= a.size():
		selected = a.size() - 1
	if selected < 0 and not a.is_empty():
		selected = a.size() - 1
	for c in _list_box.get_children():
		_list_box.remove_child(c)
		c.queue_free()
	for i in a.size():
		var idx := i
		var b := _button("%d   %s" % [i + 1, Tattoos.label_of(a[i])], Vector2(0, 30), func() -> void: select(idx), 13)
		b.name = "Tattoo_%d" % i
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if i == selected:
			b.add_theme_stylebox_override("normal", CharacterCreator._panel_style(CharacterCreator.ROW_FOCUS, CharacterCreator.GOLD, 5.0))
			b.add_theme_color_override("font_color", CharacterCreator.GOLD)
		_list_box.add_child(b)
	_count.text = "%d/%d" % [a.size(), Tattoos.max_count()]
	_add.disabled = a.size() >= Tattoos.max_count()
	_editor.visible = selected >= 0
	if selected < 0:
		return
	var t: Dictionary = a[selected]
	var d := Tattoos.design(String(t.get("design", "")))
	var ik := Tattoos.ink(String(t.get("ink", "")))
	_design_value.text = String(d.get("label", t.get("design", "")))
	_place_value.text = String(Tattoos.place(String(t.get("place", ""))).get("label", t.get("place", "")))
	_ink_value.text = String(ik.get("label", t.get("ink", "")))
	_ink_chip.color = Color(String(ik.get("swatch", "#2c3442")))
	_quiet = true
	_fade.value = float(t.get("fade", 0.15))
	_quiet = false
	_note.text = String(d.get("note", ""))
