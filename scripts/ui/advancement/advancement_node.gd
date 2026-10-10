class_name AdvancementNode
extends Button
## One pick of a tree, drawn in the reference's way: a round plate for a number trade (enhance, synergy, passive), a
## square one for something that changes what a move does or adds one (twist, technique, new skill, skill set), an
## octagon with gold side tabs for a CHOICE (one of a twist's, a passive's or a new skill's alternatives), and a
## double-edged gold square for a ROOT (a move you already have, with its key as the badge). A lit plate (worn, can be worn,
## root) is a jewel: the element's colour (a skill set's own hue for its picks) bright at the middle and dark at the edge, a
## gloss at the top, a lit rim at the top left and a glow behind the picture; the picture is the HUD's own line art tinted
## by the kind (gold for a number trade, orange for a twist, violet for a technique, aqua for a new skill, green for a
## passive). A blocked or held plate stays grey slate. The border is its state:
##   worn gold, can be worn green, blocked grey, held dashed with a '?', pending on gold with a green ring inside,
##   pending off grey with a red ring.
## A corner mark says the kind (twist, technique, ...), the other corner the skill set, outlined digits the rank (0/1, 1/1) and
## a green dot that the pick plays in matches (AdvancementData.is_live).
##
## A left click or Enter / A emits `wear`; a right click, Delete or X (pad) emits `take_off`. Hover and focus emit `tip`.

signal wear(node: AdvancementNode)
signal take_off(node: AdvancementNode)
signal tip(node: AdvancementNode, on: bool)

var item := {}             ## the layout item (key, type, ids, chip, move, mode, passive)
var element := ""
var shape := "circle"      ## circle | square | octagon | root
var ids: Array = []        ## the node ids it stands for (several for a choice)
var state := "blocked"     ## worn | pending_on | pending_off | available | blocked | held | root
var shown_id := ""         ## the id whose picture it wears (a choice: the worn one, else the first)
var pic: Texture2D
var badge := ""            ## a root's key ("LMB", "E", "1")
var rank_text := ""
var kind := ""
var set_id := ""
var hue := Color.WHITE     ## the plate's colour (white: the element's)
var live := false          ## wearing it changes a real match
var dim := false           ## a search non-match
var match_glow := false    ## a search match
var popped := false        ## a choice with its options out
var home := Vector2.ZERO
var _hover := false
var _pulse := 0.0
var _pulse_tween: Tween
var _shake_tween: Tween


func setup(it: Dictionary, el: String, px: float, shape_name: String) -> void:
	item = it
	element = el
	ids = (it.get("ids", []) as Array).duplicate()
	shape = shape_name
	custom_minimum_size = Vector2(px, px)
	size = Vector2(px, px)
	flat = true
	focus_mode = Control.FOCUS_ALL
	action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(s, empty)
	pressed.connect(func() -> void: wear.emit(self))
	gui_input.connect(_on_gui_input)
	pivot_offset = Vector2(px, px) * 0.5
	mouse_entered.connect(func() -> void: _hover = true; scale = Vector2.ONE * 1.07; queue_redraw(); tip.emit(self, true))
	mouse_exited.connect(func() -> void: _hover = false; scale = Vector2.ONE; queue_redraw(); tip.emit(self, false))
	focus_entered.connect(func() -> void: queue_redraw(); tip.emit(self, true))
	focus_exited.connect(func() -> void: queue_redraw(); tip.emit(self, false))


func _on_gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			take_off.emit(self)
			accept_event()
	elif e is InputEventKey:
		var k := e as InputEventKey
		if k.pressed and not k.echo and (k.keycode == KEY_DELETE or k.keycode == KEY_BACKSPACE or k.keycode == KEY_X):
			take_off.emit(self)
			accept_event()
	elif e is InputEventJoypadButton:
		var j := e as InputEventJoypadButton
		if j.pressed and j.button_index == JOY_BUTTON_X:
			take_off.emit(self)
			accept_event()


## The first id (a single node's id; a choice's first member).
func first_id() -> String:
	return String(ids[0]) if not ids.is_empty() else ""


func is_choice() -> bool:
	return shape == "octagon"


## Set what the node shows. `st` is its state, `pic` its picture.
func show_as(st: String, tex: Texture2D, rank := "", sid := "") -> void:
	state = st
	pic = tex
	rank_text = rank
	shown_id = sid
	var pending := st == "pending_on" or st == "pending_off"
	if pending and _pulse_tween == null:
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.tween_method(_set_pulse, 0.0, 1.0, 0.9)
		_pulse_tween.tween_method(_set_pulse, 1.0, 0.0, 0.9)
	elif not pending and _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
		_pulse = 0.0
	queue_redraw()


func _set_pulse(v: float) -> void:
	_pulse = v
	queue_redraw()


func set_dim(on: bool, glow := false) -> void:
	dim = on
	match_glow = glow
	modulate.a = AdvancementData.layout_num("search_dim", 0.35) if on else 1.0
	queue_redraw()


## A short shake: the node was asked for and cannot be worn.
func shake() -> void:
	if _shake_tween != null:
		_shake_tween.kill()
	position = home
	_shake_tween = create_tween()
	for dx in [5.0, -5.0, 3.0, -3.0, 0.0]:
		_shake_tween.tween_property(self, "position", home + Vector2(dx, 0), 0.04)


# --- drawing ------------------------------------------------------------------------------------------------------------

func _poly(r: Rect2) -> PackedVector2Array:
	match shape:
		"octagon":
			return AdvancementTheme.octagon_poly(r)
		"circle":
			return AdvancementTheme.circle_poly(r.get_center(), minf(r.size.x, r.size.y) * 0.5)
		_:
			return AdvancementTheme.rounded_poly(r, 7.0, 4)


## The plate's colour: a skill set's own hue for its picks, else the element's pulled toward the kind's tint (a twist warmer, a
## technique violet, a new skill teal, a passive green) so a tree is not one brown; then made rich (saturated and bright).
func _hue() -> Color:
	var base: Color = hue
	if hue == Color.WHITE:
		base = AdvancementData.element_color(element)
		if kind != "" and shape != "root":
			base = base.lerp(AdvancementData.color("kind_" + kind), 0.4)
	return Color.from_hsv(base.h, clampf(maxf(base.s * 1.25, 0.52), 0.0, 0.92), clampf(maxf(base.v, 0.86), 0.0, 1.0))


func _plate_colours() -> Array:
	var h := _hue()
	match state:
		"worn", "pending_on", "root":
			return [h.darkened(0.1), h.darkened(0.74)]
		"available":
			return [h.darkened(0.46), h.darkened(0.82)]
		"pending_off":
			return [Color(0.27, 0.28, 0.31), Color(0.1, 0.105, 0.125)]
		"held":
			return [Color(0.25, 0.26, 0.29), Color(0.1, 0.105, 0.125)]
	return [Color(0.23, 0.245, 0.28), Color(0.085, 0.095, 0.115)]


func _border_colour() -> Color:
	match state:
		"worn", "pending_on", "root":
			return AdvancementData.color("worn")
		"available":
			return AdvancementData.color("available")
		"pending_off":
			return AdvancementData.color("blocked")
		"held":
			return AdvancementData.color("held")
	return AdvancementData.color("blocked").darkened(0.15)


## The picture's colour: its kind's tint on a lit plate, light grey-green on a plate that can be worn, grey on the rest.
func _ink() -> Color:
	var tint := Color(1.0, 0.97, 0.88)
	if kind != "" and shape != "root":
		tint = AdvancementData.color("kind_" + kind).lerp(Color.WHITE, 0.5)
	match state:
		"worn", "pending_on", "root":
			return tint
		"available":
			return tint.lerp(Color(0.9, 1.0, 0.92), 0.55)
		"pending_off":
			return Color(0.66, 0.68, 0.72, 0.8)
		"held":
			return Color(0.62, 0.66, 0.72, 0.62)
	return Color(0.56, 0.6, 0.67, 0.72)


func _lit_state() -> bool:
	return state == "worn" or state == "pending_on" or state == "root"


func _draw() -> void:
	var s := size
	var r := Rect2(Vector2.ZERO, s)
	if shape == "root":
		r = r.grow(-1.0)
	var poly := _poly(r)
	var bc := _border_colour()
	var lit := _lit_state() or state == "available"
	# a soft glow outside, then a dark backing line so the edge reads on any painting
	if lit or _hover or match_glow:
		var gc := bc if not match_glow else AdvancementData.color("title")
		var closed := poly.duplicate()
		closed.append(poly[0])
		draw_polyline(closed, Color(gc, 0.2 + (0.12 if _hover else 0.0)), 9.0, true)
	var back := poly.duplicate()
	back.append(poly[0])
	draw_polyline(back, Color(0, 0, 0, 0.6), 6.0, true)
	# the plate: the colour bright at the middle fading to dark at the edge, clipped to the shape
	var cols := _plate_colours()
	var pt := AdvancementTheme.plate_tex(cols[0], cols[1])
	var uvs := PackedVector2Array()
	for p in poly:
		uvs.append((p - r.position) / r.size)
	draw_colored_polygon(poly, Color.WHITE, uvs, pt)
	var isz := minf(s.x, s.y) * (0.84 if shape != "octagon" else 0.78)
	var ir := Rect2((s - Vector2(isz, isz)) * 0.5, Vector2(isz, isz))
	if _lit_state():
		# a gloss on the upper half and a glow behind the picture
		var gl := AdvancementTheme.ellipse_poly(Vector2(s.x * 0.5, s.y * 0.27), Vector2(s.x * 0.34, s.y * 0.15))
		draw_colored_polygon(gl, Color(1, 1, 1, 0.13))
		draw_texture_rect(AdvancementTheme.glow_tex(), ir.grow(5.0), false, Color(_hue().lightened(0.45), 0.55 + 0.2 * _pulse))
	# the picture (a lit plate gives it a dark shadow so it reads on the bright middle)
	if pic != null:
		if _lit_state():
			draw_texture_rect(pic, Rect2(ir.position + Vector2(0.0, 1.6), ir.size), false, Color(0.04, 0.02, 0.0, 0.55))
		draw_texture_rect(pic, ir, false, _ink())
	else:
		var fnt := AdvancementTheme.font("head")
		var txt := badge if badge != "" else "?"
		draw_string(fnt, Vector2(0, s.y * 0.5 + 9), txt, HORIZONTAL_ALIGNMENT_CENTER, s.x, 26, _ink())
	# the border
	var edge := poly.duplicate()
	edge.append(poly[0])
	if state == "held":
		AdvancementTheme.dashed_outline(self, poly, bc, 2.4)
	else:
		draw_polyline(edge, bc, 3.0, true)
	if lit and state != "held":
		# a lit rim just inside the border, brightest at the top left
		var rim := _poly(r.grow(-3.4))
		for i in rim.size():
			var a := rim[i]
			var b := rim[(i + 1) % rim.size()]
			var mid := (a + b) * 0.5 - s * 0.5
			var up_left := clampf(-(mid.x + mid.y) / maxf(mid.length() * 1.4142, 1.0), 0.0, 1.0)
			draw_line(a, b, Color(1.0, 1.0, 1.0, 0.08 + 0.5 * up_left * up_left), 1.6, true)
	if shape == "root":
		var inner := _poly(r.grow(-4.5))
		var ie := inner.duplicate()
		ie.append(inner[0])
		draw_polyline(ie, Color(bc, 0.55), 1.2, true)
	if state == "pending_on" or state == "pending_off":
		var ring := _poly(r.grow(-5.0))
		var re := ring.duplicate()
		re.append(ring[0])
		var rc := AdvancementData.color("pending_on" if state == "pending_on" else "pending_off")
		draw_polyline(re, Color(rc, 0.55 + 0.45 * _pulse), 2.4, true)
	if shape == "octagon":
		_draw_tabs(bc)
	_draw_marks(bc)
	if has_focus():
		var fo := _poly(r.grow(3.5))
		var fe := fo.duplicate()
		fe.append(fo[0])
		draw_polyline(fe, AdvancementData.color("title"), 2.0, true)


## The gold side tabs of a choice octagon (they point out, as the reference's do).
func _draw_tabs(col: Color) -> void:
	var cy := size.y * 0.5
	var tc := col
	var pl := PackedVector2Array([Vector2(-1.5, cy - 8.5), Vector2(-10.5, cy), Vector2(-1.5, cy + 8.5)])
	var pr := PackedVector2Array([Vector2(size.x + 1.5, cy - 8.5), Vector2(size.x + 10.5, cy), Vector2(size.x + 1.5, cy + 8.5)])
	draw_colored_polygon(pl, tc)
	draw_colored_polygon(pr, tc)
	draw_polyline(PackedVector2Array([pl[0], pl[1], pl[2], pl[0]]), Color(0, 0, 0, 0.55), 1.0, true)
	draw_polyline(PackedVector2Array([pr[0], pr[1], pr[2], pr[0]]), Color(0, 0, 0, 0.55), 1.0, true)


func _draw_marks(bc: Color) -> void:
	var fnt := AdvancementTheme.font("head2")
	# the kind mark, top left; the skill set's, top right
	if kind != "" and shape != "root":
		var km := AdvancementTheme.kind_mark(kind)
		if km != null:
			var kr := Rect2(Vector2(-8, -8), Vector2(22, 22))
			draw_circle(kr.get_center(), 11.0, Color(0.04, 0.045, 0.06, 0.88))
			draw_arc(kr.get_center(), 11.0, 0, TAU, 20, Color(bc, 0.8), 1.4, true)
			draw_texture_rect(km, kr.grow(-3.0), false, Color(1.0, 0.9, 0.55) if state in ["worn", "pending_on", "available"] else Color(0.65, 0.68, 0.74))
	if set_id != "" and shape != "root":
		var sm := AdvancementTheme.set_mark(set_id)
		if sm != null:
			var sr := Rect2(Vector2(size.x - 14, -8), Vector2(22, 22))
			draw_circle(sr.get_center(), 11.0, Color(0.04, 0.045, 0.06, 0.88))
			draw_arc(sr.get_center(), 11.0, 0, TAU, 20, Color(AdvancementTheme.set_tint(set_id), 0.9), 1.4, true)
			draw_texture_rect(sm, sr.grow(-3.0), false, AdvancementTheme.set_tint(set_id))
	# a root's key sits in a small plate on its lower edge; a node's rank is bare outlined digits in its lower right corner
	var txt := ""
	var tcol := bc
	if shape == "root":
		txt = badge
		tcol = AdvancementData.color("worn")
	elif rank_text != "":
		txt = rank_text
		tcol = AdvancementData.color("worn") if state in ["worn", "pending_on"] else (AdvancementData.color("available") if state == "available" else AdvancementData.color("text_dim").lightened(0.2))
	if txt != "":
		var px := 18
		var tw := fnt.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		if shape == "root":
			var pw := maxf(tw + 12.0, 30.0)
			var ph := 20.0
			var pr := Rect2((size.x - pw) * 0.5, size.y - ph * 0.5 - 1.0, pw, ph)
			var pp := AdvancementTheme.rounded_poly(pr, 6.0, 3)
			draw_colored_polygon(pp, Color(0.04, 0.045, 0.06, 0.94))
			var pe := pp.duplicate()
			pe.append(pp[0])
			draw_polyline(pe, Color(tcol, 0.85), 1.4, true)
			draw_string(fnt, Vector2(pr.position.x, pr.position.y + ph * 0.5 + 6.5), txt, HORIZONTAL_ALIGNMENT_CENTER, pw, px, tcol)
		else:
			var at := Vector2(size.x - tw + 9.0, size.y + 9.0)
			draw_string_outline(fnt, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 6, Color(0.02, 0.022, 0.03, 0.96))
			draw_string(fnt, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px, tcol)
	if live and shape != "root":
		# plays in matches: a small green dot with a white play mark at the lower left
		var dc := Vector2(1.0, size.y - 1.0)
		draw_circle(dc, 8.5, Color(0.02, 0.03, 0.03, 0.95))
		draw_circle(dc, 6.6, AdvancementData.color("live"))
		draw_colored_polygon(PackedVector2Array([dc + Vector2(-2.2, -3.4), dc + Vector2(3.6, 0.0), dc + Vector2(-2.2, 3.4)]), Color(0.03, 0.12, 0.06))
