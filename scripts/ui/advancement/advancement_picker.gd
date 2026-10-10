class_name AdvancementPicker
extends Control
## "Change class": the element's five classes side by side (its four styles and Jeet Kune Do), each with its emblem, its
## state (ready to play, parked, coming), its two strengths and two weaknesses and the traits of its rail. A class that is
## ready can be picked; the others are shown, greyed, so the owner can see what is coming. The pick is a pending change of
## the loadout being edited (the window decides); this panel only reports `picked(style_id)`.

signal picked(style_id: String)
signal close_requested

var element := ""
var current := ""
var _cards: Array = []


func setup(el: String, cur: String, area: Vector2) -> void:
	element = el
	current = cur
	size = area
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.012, 0.02, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			close_requested.emit())
	add_child(dim)
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", AdvancementTheme.frame_box())
	panel.position = Vector2(70, 82)
	panel.size = Vector2(area.x - 140.0, area.y - 164.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var title := AdvancementTheme.label(AdvancementData.word("class.title").to_upper(), AdvancementTheme.S_TITLE - 6, AdvancementTheme.INK, "head")
	title.add_theme_font_override("font", AdvancementTheme.spaced("head", 3))
	title.position = Vector2(34, 18)
	title.size = Vector2(500, 52)
	panel.add_child(title)
	var line := AdvancementTheme.label(AdvancementData.word("class.line"), AdvancementTheme.S_BODY, AdvancementData.color("text"), "body")
	line.position = Vector2(34, 68)
	line.clip_text = true
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.size = Vector2(panel.size.x - 160.0, 28)
	panel.add_child(line)
	var x := AdvancementTheme.GlyphButton.new("close")
	x.position = Vector2(panel.size.x - 62, 20)
	x.size = Vector2(40, 40)
	x.pressed.connect(func() -> void: close_requested.emit())
	panel.add_child(x)
	var styles := AdvancementData.styles(el)
	var cw := (panel.size.x - 68.0 - 14.0 * float(styles.size() - 1)) / float(styles.size())
	for i in styles.size():
		var card := _card(styles[i], cw, panel.size.y - 120.0)
		card.position = Vector2(34.0 + float(i) * (cw + 14.0), 108)
		panel.add_child(card)
		_cards.append(card)


func first_button() -> Button:
	for c: Control in _cards:
		var b := c.find_child("PickButton", true, false) as Button
		if b != null and not b.disabled:
			return b
	return null


func _card(st: Dictionary, w: float, h: float) -> Control:
	var id := String(st.id)
	var pickable := bool(st.pickable)
	var is_cur := id == current
	var pc := Panel.new()
	pc.name = "Card_" + id
	pc.size = Vector2(w, h)
	var edge := AdvancementData.color("worn") if is_cur else (AdvancementData.color("frame_gold") if pickable else Color(0.4, 0.4, 0.44))
	pc.add_theme_stylebox_override("panel", AdvancementTheme.box(Color(0.12, 0.135, 0.17), Color(0.07, 0.078, 0.1), edge, 2.5 if is_cur else 2.0, 6.0))
	pc.modulate.a = 1.0 if pickable else 0.78
	var ec := AdvancementData.element_color(element)
	var em := TextureRect.new()
	em.texture = AdvancementTheme.emblem(element, id)
	em.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	em.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	em.size = Vector2(76, 76)
	em.position = Vector2((w - 76.0) * 0.5, 10)
	em.modulate = ec.lightened(0.2) if pickable else Color(0.55, 0.58, 0.64)
	pc.add_child(em)
	var nm := AdvancementTheme.label(String(st.label), 32, AdvancementTheme.INK, "head")
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.position = Vector2(8, 90)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.size = Vector2(w - 16.0, 38)
	pc.add_child(nm)
	var state_col := AdvancementData.color("available") if pickable else AdvancementData.color("text_dim")
	var sl := AdvancementTheme.label(AdvancementData.style_state_word(id), AdvancementTheme.S_SMALL + 1, state_col, "body2")
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	sl.position = Vector2(10, 126)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sl.max_lines_visible = 2
	sl.clip_text = true
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sl.size = Vector2(w - 20.0, 48)          # (two lines wrap inside the card, never into the next one)
	pc.add_child(sl)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.position = Vector2(14, 176)
	v.size = Vector2(w - 28.0, h - 240.0)
	pc.add_child(v)
	for lv: Dictionary in AdvancementData.levers(id):
		var up := int(lv.sign) > 0
		var l := AdvancementTheme.label(String(lv.line), AdvancementTheme.S_SMALL, AdvancementData.color("plus") if up else AdvancementData.color("minus"), "body")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(w - 28.0, 0)
		v.add_child(l)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	v.add_child(gap)
	v.add_child(AdvancementTheme.label(AdvancementData.word("class.rail_head").to_upper(), AdvancementTheme.S_SMALL, AdvancementData.color("frame_trim"), "head2"))
	for tr: Dictionary in AdvancementData.rail(id, element):
		var t := String(tr.label)
		if String(tr.get("move_label", "")) != "" and String(tr.id) != "stance":
			t += " · " + String(tr.move_label)
		var tl := AdvancementTheme.label(t, AdvancementTheme.S_SMALL, AdvancementData.color("text"), "body")
		tl.clip_text = true
		tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tl.custom_minimum_size = Vector2(w - 28.0, 0)
		v.add_child(tl)
	var b := AdvancementTheme.button(AdvancementData.word("class.picked") if is_cur else AdvancementData.word("class.pick"), "plate", AdvancementTheme.S_BUTTON)
	b.name = "PickButton"
	b.position = Vector2(14, h - 52.0)
	b.size = Vector2(w - 28.0, 40)
	b.disabled = not pickable or is_cur
	b.pressed.connect(func() -> void: picked.emit(id))
	pc.add_child(b)
	return pc
