class_name AdvancementDrop
extends Button
## A dropdown in the window's own look. The engine's PopupMenu is a separate window that would not follow the window's
## scale, so the list is a plate added to `host` (the scaled stage) instead: items {id, text, sub, disabled}, `picked(id)`
## when one is chosen, Esc or a click outside closes it. With `glyph` the button is a drawn icon instead of a caption.

signal picked(id: String)

var host: Control
var items: Array = []
var current := ""
var caption := ""
var glyph := ""
var open_up := true
var _catcher: Control
var _panel: Control
var _arrow: Control
var _rows: Array = []


func _init() -> void:
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	clip_text = true
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pressed.connect(toggle)


func setup(h: Control, kind_glyph := "") -> void:
	host = h
	glyph = kind_glyph
	if glyph == "":
		AdvancementTheme.style_button(self, "ghost", AdvancementTheme.S_BODY)
		for s in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
			var sb: StyleBox = get_theme_stylebox(s)
			sb.content_margin_left = 12
			sb.content_margin_right = 34
		_arrow = Control.new()
		_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
		_arrow.draw.connect(_draw_arrow)
		add_child(_arrow)
	else:
		var g := AdvancementTheme.GlyphButton.new(glyph)
		g.name = "Glyph"
		g.set_anchors_preset(Control.PRESET_FULL_RECT)
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.focus_mode = Control.FOCUS_NONE
		add_child(g)
		AdvancementTheme.style_button(self, "ghost", AdvancementTheme.S_BODY)
		text = ""


func _draw_arrow() -> void:
	var c := Vector2(size.x - 18.0, size.y * 0.5)
	var col := AdvancementData.color("frame_trim")
	_arrow.draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -3), c + Vector2(6, -3), c + Vector2(0, 5)]), col)


func set_items(list: Array, cur := "") -> void:
	items = list
	current = cur
	if glyph == "":
		text = caption
		for it: Dictionary in items:
			if String(it.id) == cur:
				text = String(it.text)


func toggle() -> void:
	if _panel != null:
		close()
	else:
		open()


func is_open() -> bool:
	return _panel != null


func open() -> void:
	if host == null or items.is_empty():
		return
	close()
	_catcher = Control.new()
	_catcher.size = Vector2(1600, 900)
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			close())
	host.add_child(_catcher)
	_panel = Control.new()
	var plate := Panel.new()
	plate.add_theme_stylebox_override("panel", AdvancementTheme.stone(Color(0.085, 0.095, 0.12, 0.98), Color(0.055, 0.062, 0.08, 0.98)))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(plate)
	var w := maxf(size.x, 400.0 if glyph == "" else 280.0)
	var sub_font := AdvancementTheme.font("body")
	var y := 6.0
	_rows.clear()
	for it: Dictionary in items:
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_ALL
		var has_sub := String(it.get("sub", "")) != ""
		# a line too long for the row wraps to a second line (two at most) instead of ending in "..."
		var sub_lines := 0
		if has_sub:
			var tw := sub_font.get_string_size(String(it.sub), HORIZONTAL_ALIGNMENT_LEFT, -1, AdvancementTheme.S_SMALL).x
			sub_lines = clampi(ceili(tw / (w - 44.0)), 1, 2)
		var h := 32.0 + 26.0 * float(sub_lines) if has_sub else 38.0
		b.position = Vector2(6, y)
		b.size = Vector2(w - 12.0, h)
		var hov := StyleBoxFlat.new()
		hov.bg_color = Color(AdvancementData.color("frame_gold"), 0.28)
		hov.set_corner_radius_all(4)
		var cur := StyleBoxFlat.new()
		cur.bg_color = Color(AdvancementData.color("worn"), 0.12)
		cur.set_corner_radius_all(4)
		b.add_theme_stylebox_override("normal", cur if String(it.id) == current else StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover", hov)
		b.add_theme_stylebox_override("pressed", hov)
		b.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("focus", hov)
		b.disabled = bool(it.get("disabled", false))
		_panel.add_child(b)
		var dis := b.disabled
		var l := AdvancementTheme.label(String(it.text), AdvancementTheme.S_LABEL, AdvancementData.color("text_dim") if dis else AdvancementTheme.INK, "body2")
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.position = Vector2(12, 3 if has_sub else 5)
		l.size = Vector2(w - 36.0, 28)
		b.add_child(l)
		if has_sub:
			var sl := AdvancementTheme.label(String(it.sub), AdvancementTheme.S_SMALL, AdvancementData.color("reason") if dis else AdvancementData.color("text_dim"), "body")
			sl.clip_text = true
			sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			sl.max_lines_visible = 2
			sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			sl.position = Vector2(12, 28)
			sl.size = Vector2(w - 36.0, 26.0 * float(sub_lines))
			b.add_child(sl)
		var id := String(it.id)
		b.pressed.connect(func() -> void:
			close()
			picked.emit(id))
		_rows.append(b)
		y += h + 2.0
	_panel.size = Vector2(w, y + 6.0)
	plate.size = _panel.size
	host.add_child(_panel)
	var inv := host.get_global_transform().affine_inverse()
	var tl: Vector2 = inv * global_position
	var sc := host.get_global_transform().get_scale()
	var bsz := size / sc
	var x := clampf(tl.x, 8.0, 1592.0 - w)
	var py := tl.y - _panel.size.y - 4.0 if open_up else tl.y + bsz.y + 4.0
	_panel.position = Vector2(x, maxf(py, 8.0))
	for b: Button in _rows:
		if not b.disabled:
			b.grab_focus()
			break


func close() -> void:
	if _panel != null:
		_panel.queue_free()
		_panel = null
	if _catcher != null:
		_catcher.queue_free()
		_catcher = null
	_rows.clear()


func _exit_tree() -> void:
	close()
