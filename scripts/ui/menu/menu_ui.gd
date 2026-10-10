class_name MenuUI
extends RefCounted
## The menus' look (the main menu, the pause menu, the loading screen): the HUD's serif lettering in ink and gold on
## soft shade, no boxes (user 2026-09-27: "no big cards"), the chosen row marked with a gold rule at its left as in
## the Tab screen's pack list.

const INK := Color("e4e0ce")
const DIM := Color("bec8ce")
const FAINT := Color("8e9eac")
const GOLD := Color("c8b68a")
const BACKDROP := Color("1c2535")
const SHADOW := Color(0, 0, 0, 0.6)


static func label(text: String, size: int, color := INK, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FrontierHUD.serif())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", SHADOW)
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## A menu row: the text in the serif, ink, gold with a rule at its left when hovered or chosen (focus); `sub` a
## smaller line under it (a save's date); `off` greys it and says why ("coming"). Returns the Button; connect
## `pressed`.
static func item(text: String, size := 30, sub := "", off := "") -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = ""
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(st, empty)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	var rule := ColorRect.new()
	rule.name = "Rule"
	rule.color = Color(GOLD, 0.0)
	rule.custom_minimum_size = Vector2(3, 0)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rule)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var main := label(text, size, INK if off == "" else FAINT)
	main.name = "Text"
	col.add_child(main)
	if sub != "" or off != "":
		var s := label(sub if off == "" else off, int(size * 0.5), DIM if off == "" else FAINT)
		s.name = "Sub"
		col.add_child(s)
	row.add_child(col)
	b.add_child(row)
	b.custom_minimum_size = Vector2(0, size * (1.9 if (sub != "" or off != "") else 1.35))
	b.disabled = off != ""
	var lit := func(on: bool) -> void:
		if b.disabled:
			return
		rule.color = Color(GOLD, 1.0 if on else 0.0)
		main.add_theme_color_override("font_color", GOLD if on else INK)
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	b.focus_entered.connect(lit.bind(true))
	b.focus_exited.connect(lit.bind(false))
	return b


## A heading for a sub-screen, with a thin gold rule under it.
static func heading(text: String, size := 34) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(label(text, size, GOLD))
	var r := ColorRect.new()
	r.color = Color(GOLD, 0.45)
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(r)
	return v


## A soft shade from the left edge (for the menu over a painting): `a` its darkness, `w` how far it reaches (0..1).
static func left_shade(a := 0.82) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(BACKDROP, a))
	g.set_color(1, Color(BACKDROP, 0.0))
	g.add_point(0.55, Color(BACKDROP, a * 0.85))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0.5)
	t.fill_to = Vector2(1, 0.5)
	t.width = 256
	t.height = 8
	var r := TextureRect.new()
	r.texture = t
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## The fight's screens put away while an overlay stands over the ring (the ring's Esc menu, the round screen, the match
## screen; the UI audit, 2026-10-09: the plates, the clock, the strip and the hint boxes drawn under them, text over text):
## while `on` every CanvasLayer shown under `over` (a lower layer) is hidden, and the same ones are shown again after: the
## Splash Cam's way with its own (RingReplay._hide_layers). The wheels open and shut themselves, so they are left alone.
static func cover_hud(over: CanvasLayer, on: bool) -> void:
	if over == null:
		return
	if on:
		if over.has_meta(&"hud_cover") or not over.is_inside_tree():
			return
		var hid: Array = []
		for n in over.get_tree().root.find_children("*", "CanvasLayer", true, false):
			var cl := n as CanvasLayer
			if cl == over or not cl.visible or cl.layer >= over.layer or cl is EquipWheel or cl is RadialWheel:
				continue
			hid.append(cl)
			cl.visible = false
		over.set_meta(&"hud_cover", hid)
		if not over.has_meta(&"hud_cover_hook"):
			# (the overlay gone with them still put away, Main menu from it: a layer that outlives the scene is shown again)
			over.set_meta(&"hud_cover_hook", true)
			over.tree_exiting.connect(func() -> void: cover_hud(over, false))
		return
	if not over.has_meta(&"hud_cover"):
		return
	var had: Array = over.get_meta(&"hud_cover")
	over.remove_meta(&"hud_cover")
	for cl in had:
		if is_instance_valid(cl):
			(cl as CanvasLayer).visible = true


## A layer put away by someone else to show again (`cl`; F1's arena help closing, FrontierHUD._put_hints_away): while an
## overlay still covers the HUD over it (cover_hud), it joins that overlay's put-away layers and is shown as it goes;
## else it is shown now.
static func show_again(cl: CanvasLayer) -> void:
	if cl.is_inside_tree():
		for n in cl.get_tree().root.find_children("*", "CanvasLayer", true, false):
			if n != cl and n.has_meta(&"hud_cover") and (n as CanvasLayer).layer > cl.layer:
				(n.get_meta(&"hud_cover") as Array).append(cl)
				return
	cl.visible = true


## A slider row: the label, a thin slider in gold, the value in words from `fmt` (a Callable of the value).
static func slider(text: String, lo: float, hi: float, step: float, value: float, fmt: Callable, changed: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	var l := label(text, 20, INK)
	l.custom_minimum_size = Vector2(230, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(240, 24)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var line := StyleBoxLine.new()
	line.color = Color(DIM, 0.6)
	line.thickness = 2
	s.add_theme_stylebox_override("slider", line)
	var fill := StyleBoxLine.new()
	fill.color = GOLD
	fill.thickness = 2
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	h.add_child(s)
	var v := label(String(fmt.call(value)), 18, DIM)
	v.custom_minimum_size = Vector2(90, 0)
	h.add_child(v)
	s.value_changed.connect(func(x: float) -> void:
		v.text = String(fmt.call(x))
		changed.call(x))
	return h


## A yes / no row: the label and a toggle drawn as words ("On" / "Off"), gold when on.
static func toggle(text: String, on: bool, changed: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	var l := label(text, 20, INK)
	l.custom_minimum_size = Vector2(230, 0)
	h.add_child(l)
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = on
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", FrontierHUD.serif())
	b.add_theme_font_size_override("font_size", 20)
	var paint := func(v: bool) -> void:
		b.text = "On" if v else "Off"
		for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(st, GOLD if v else DIM)
	paint.call(on)
	b.toggled.connect(func(v: bool) -> void:
		paint.call(v)
		changed.call(v))
	h.add_child(b)
	return h
