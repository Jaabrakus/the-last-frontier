class_name AdvancementSlots
extends Control
## The Loadouts panel (the reference's "Available Specializations" list): Classic, then the element's three saved loadouts
## as cards. A card shows its class emblem, its name, its class and points, its state (Worn gold, Saved green, Empty dim,
## Needs a fix red) and the padlock that keeps it from edits. Clicking a card makes it the loadout being edited; the
## selected one opens to show its picks and a Wear button. The panel only reports (edit / wear / rename / keep); the
## window changes the store and calls refresh().

signal edit_requested(slot: int)
signal wear_requested(slot: int)
signal rename_requested(slot: int, text: String)
signal keep_toggled(slot: int, on: bool)
signal close_requested
signal hint(c: Control, text: String, on: bool)

var element := ""
var selected := 0
var _list: VBoxContainer
var _title: Label
var _name_edit: LineEdit


func setup(el: String) -> void:
	element = el
	mouse_filter = Control.MOUSE_FILTER_STOP
	var back := Panel.new()
	back.add_theme_stylebox_override("panel", AdvancementTheme.stone(Color(0.085, 0.095, 0.12, 0.97), Color(0.05, 0.055, 0.07, 0.97)))
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	var head := Control.new()
	head.position = Vector2(0, 0)
	head.size = Vector2(size.x, 46)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(head)
	_title = AdvancementTheme.label(AdvancementData.word("loadout.panel_title"), AdvancementTheme.S_TIP_TITLE, AdvancementData.color("frame_trim"), "head")
	_title.position = Vector2(16, 6)
	_title.size = Vector2(size.x - 70, 36)
	head.add_child(_title)
	var x := AdvancementTheme.GlyphButton.new("close")
	x.position = Vector2(size.x - 46, 7)
	x.size = Vector2(32, 32)
	x.mouse_entered.connect(func() -> void: hint.emit(x, AdvancementData.word("buttons.close"), true))
	x.mouse_exited.connect(func() -> void: hint.emit(x, "", false))
	x.pressed.connect(func() -> void: close_requested.emit())
	head.add_child(x)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10, 50)
	scroll.size = Vector2(size.x - 20, size.y - 60)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.custom_minimum_size = Vector2(size.x - 24, 0)
	scroll.add_child(_list)
	refresh(selected)


## Rebuild the cards; `sel` is the slot being edited.
func refresh(sel: int) -> void:
	selected = sel
	_name_edit = null
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_list.add_child(_card(-1))
	for i in AdvancementData.slot_count():
		_list.add_child(_card(i))


func _state_word(i: int) -> Array:
	var st := "worn" if AdvancementStore.worn_index(element) == -1 else ""
	if i >= 0:
		st = AdvancementStore.slot_state(element, i)
	var col := AdvancementData.color("text_dim")
	match st:
		"worn":
			col = AdvancementData.color("worn")
		"saved":
			col = AdvancementData.color("available")
		"invalid":
			col = AdvancementData.color("reason")
	return [AdvancementData.word("slot_state." + st) if st != "" else "", col, st]


func _card(i: int) -> Control:
	var w := size.x - 28.0
	var sel := i == selected
	var info: Dictionary = AdvancementStore.slot_info(element, i) if i >= 0 else {}
	var style_id := String(info.get("style", AdvancementStore.style_of(element)))
	var lo: AdvancementLoadout = AdvancementStore.slot(element, i)
	var sw := _state_word(i)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(w, 0)
	var edge := AdvancementData.color("frame_gold")
	var sb := AdvancementTheme.box(Color(0.12, 0.135, 0.17), Color(0.075, 0.085, 0.11), AdvancementData.color("worn") if sel else Color(edge, 0.5), 2.5 if sel else 2.0, 6.0)
	AdvancementTheme.with_margins(sb, 10, 10, 10, 10)
	pc.add_theme_stylebox_override("panel", sb)
	if i >= 0:
		pc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		pc.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				edit_requested.emit(i))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var em := TextureRect.new()
	em.texture = AdvancementTheme.emblem(element, style_id)
	em.custom_minimum_size = Vector2(44, 44)
	em.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	em.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var has_picks := i < 0 or not (info.get("nodes", []) as Array).is_empty()
	em.modulate = AdvancementData.element_color(element).lightened(0.2) if has_picks else Color(0.55, 0.58, 0.64)
	em.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(em)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(col)
	if sel and i >= 0:
		_name_edit = LineEdit.new()
		_name_edit.text = String(info.get("name", ""))
		_name_edit.placeholder_text = AdvancementData.word("loadout.slot") % (i + 1)
		_name_edit.max_length = int(AdvancementData.tree_cfg().get("name_max", 24))
		AdvancementTheme.style_line_edit(_name_edit, AdvancementTheme.S_LABEL + 2)
		var ne := _name_edit
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(0, 0, 0, 0.28)
		flat.set_border_width_all(0)
		flat.border_width_bottom = 2
		flat.border_color = Color(AdvancementData.color("frame_gold"), 0.8)
		flat.content_margin_left = 6
		flat.content_margin_right = 6
		flat.content_margin_top = 1
		flat.content_margin_bottom = 1
		var flat_f := flat.duplicate() as StyleBoxFlat
		flat_f.border_color = AdvancementData.color("frame_trim")
		_name_edit.add_theme_stylebox_override("normal", flat)
		_name_edit.add_theme_stylebox_override("read_only", flat)
		_name_edit.add_theme_stylebox_override("focus", flat_f)
		_name_edit.add_theme_font_override("font", AdvancementTheme.font("head2"))
		_name_edit.text_submitted.connect(func(t: String) -> void: rename_requested.emit(i, t))
		_name_edit.focus_exited.connect(func() -> void:
			if is_instance_valid(ne):
				rename_requested.emit(i, ne.text))
		_name_edit.editable = not AdvancementStore.keep(element, i)
		col.add_child(_name_edit)
	else:
		var nm := AdvancementTheme.label(AdvancementStore.slot_name(element, i), AdvancementTheme.S_LABEL + 2, AdvancementTheme.INK if i < 0 or not (info.get("nodes", []) as Array).is_empty() else AdvancementData.color("text_dim"), "head2")
		nm.clip_text = true
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(nm)
	var sub_text := AdvancementData.word("loadout.class_line") % String(AdvancementData.style(style_id).get("label", ""))
	if i >= 0:
		sub_text = "%s · %s" % [String(AdvancementData.style(style_id).get("label", "")), AdvancementData.word("loadout.points") % [lo.cost(), AdvancementData.budget()]]
	col.add_child(AdvancementTheme.label(sub_text, AdvancementTheme.S_SMALL + 1, AdvancementData.color("text_dim"), "body"))
	if String(sw[0]) != "":
		col.add_child(AdvancementTheme.label(String(sw[0]), AdvancementTheme.S_BODY, sw[1], "body2"))
	if i >= 0:
		var lock := AdvancementTheme.GlyphButton.new("lock")
		lock.custom_minimum_size = Vector2(34, 34)
		lock.toggle_mode = true
		lock.button_pressed = AdvancementStore.keep(element, i)
		lock.mouse_entered.connect(func() -> void: hint.emit(lock, AdvancementData.word("buttons.keep"), true))
		lock.mouse_exited.connect(func() -> void: hint.emit(lock, "", false))
		lock.tint = AdvancementData.color("worn") if lock.button_pressed else Color(0.5, 0.52, 0.58, 0.8)
		lock.tint_hover = Color(1.0, 0.93, 0.7)
		lock.toggled.connect(func(on: bool) -> void: keep_toggled.emit(i, on))
		top.add_child(lock)
	if i < 0:
		# Classic is a one-line card with its Wear button beside the name
		if String(sw[2]) != "worn":
			var cb := AdvancementTheme.button(AdvancementData.word("buttons.wear"), "plate", AdvancementTheme.S_BODY)
			cb.custom_minimum_size = Vector2(84, 34)
			cb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			cb.pressed.connect(func() -> void: wear_requested.emit(-1))
			top.add_child(cb)
		return pc
	if sel:
		var picks := ", ".join(PackedStringArray(lo.names())) if not lo.is_empty() else AdvancementData.word("loadout.picks_none")
		var pl := AdvancementTheme.label(picks, AdvancementTheme.S_SMALL, AdvancementData.color("text"), "body")
		pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pl.custom_minimum_size = Vector2(w - 26.0, 0)
		v.add_child(pl)
		var worn_now := String(sw[2]) == "worn"
		var empty := String(sw[2]) == "empty"
		var wb := AdvancementTheme.button(AdvancementData.word("slot_state.worn") if worn_now else AdvancementData.word("buttons.wear"), "plate", AdvancementTheme.S_BUTTON)
		wb.disabled = worn_now or empty
		wb.custom_minimum_size = Vector2(0, 36)
		wb.pressed.connect(func() -> void: wear_requested.emit(i))
		v.add_child(wb)
	return pc
