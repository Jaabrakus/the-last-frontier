class_name AdvancementNode
extends Button
## One pick of a tree, drawn in the reference's way: a round plate for a number trade (enhance, synergy, passive), a
## square one for something that changes what a move does or adds one (twist, technique, new skill, skill set), an
## octagon with gold side tabs for a CHOICE (one of a twist's, a passive's or a new skill's alternatives), and a
## double-edged gold square for a ROOT (a move you already have, with its key as the badge). A plate in colour (worn, can be
## worn, root) is a deep jewel (2026-10-10 repair of "flat node art"): its hue led by the kind (gold for a number trade,
## orange for a twist, violet for a technique, teal for a new skill, green for a passive; a skill set's picks its own hue)
## and tinted by the element, turned a little per pick so no two neighbours are one colour, bright at the middle and dark at
## the edge, with the kind's motif behind the picture (light rays for what changes a move, rings for a number trade), a
## gloss, a lit rim and a glow; the picture is the HUD's own line art in near-white with a dark halo, the brightest thing on
## the plate. Worn is the full jewel, can-be-worn the same dimmer; a blocked or held plate is grey slate, dimmed. The
## border is its state:
##   worn gold, can be worn green, blocked grey (a gate's: rust), held dashed with a '?', pending on gold with a green ring
##   inside, pending off grey with a red ring.
## The marks sit on the corners, half on the plate, so none reaches a neighbour on the lattice: the kind top left, the skill
## set top right, the rank (0/1, 1/1) in a small plate inside the lower right corner (a newcomer gate's padlock and number
## there instead when a gate holds it: gate_num), a green dot lower left when the pick plays in matches (AdvancementData.is_live).
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
var gate_num := 0          ## > 0: a newcomer gate holds it shut (the gate's number: 1 = the first win, else the lessons left)
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
## technique violet, a new skill teal, a passive green) so a tree is not one brown, turned a little by the pick's own id (each
## pick its own jewel, as the reference's icons are each their own picture); then made rich (saturated, a deep middle value
## so the light picture stands out on it).
func _hue() -> Color:
	var base: Color = hue
	if hue == Color.WHITE:
		base = AdvancementData.element_color(element)
		if kind != "" and shape != "root":
			# the kind leads the hue (a number trade gold, a twist orange, a technique violet, a new skill teal, a passive
			# green), the element tints it: a tree reads in several jewels, as the reference's does
			var kc := AdvancementData.color("kind_" + kind)
			base = Color.from_hsv(kc.h, maxf(kc.s, 0.5), 1.0).lerp(base, 0.35)
	var turn := 0.0
	if shape != "root" and shown_id != "":
		turn = float(int(absi(shown_id.hash())) % 7 - 3) * 0.014
	return Color.from_hsv(fposmod(base.h + turn, 1.0), clampf(maxf(base.s * 1.5, 0.62), 0.0, 0.88), 0.9)


## [middle, edge] of the plate. Lit (worn, pending on, a root): the jewel, deep and saturated, so the light picture is the
## brightest thing on it. Can be worn: the same jewel, dimmer (in colour, as the reference shows a pick you can take). Shut,
## held, taking off: grey slate, no colour.
func _plate_colours() -> Array:
	var h := _hue()
	match state:
		"worn", "pending_on", "root":
			return [Color.from_hsv(h.h, h.s, 0.56), Color.from_hsv(h.h, minf(1.0, h.s * 1.05), 0.09)]
		"available":
			return [Color.from_hsv(h.h, h.s * 0.8, 0.38), Color.from_hsv(h.h, h.s * 0.8, 0.07)]
		"pending_off":
			return [Color(0.27, 0.28, 0.31), Color(0.1, 0.105, 0.125)]
		"held":
			return [Color(0.22, 0.23, 0.26), Color(0.09, 0.095, 0.11)]
	return [Color(0.2, 0.21, 0.235), Color(0.07, 0.075, 0.09)]


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
	if gate_num > 0:
		return AdvancementData.color("gate_line").darkened(0.1)
	return AdvancementData.color("blocked").darkened(0.2)


## The picture's colour: near-white with a breath of the plate's hue on a lit plate (it is the brightest thing on it), a little
## softer on a plate that can be worn, grey on the rest.
func _ink() -> Color:
	var h := _hue()
	var lit_ink := Color(1.0, 0.99, 0.96).lerp(Color.from_hsv(h.h, 0.3, 1.0), 0.22)
	match state:
		"worn", "pending_on", "root":
			return lit_ink
		"available":
			return lit_ink.darkened(0.12)
		"pending_off":
			return Color(0.66, 0.68, 0.72, 0.8)
		"held":
			return Color(0.6, 0.63, 0.68, 0.6)
	return Color(0.55, 0.58, 0.63, 0.7)


func _lit_state() -> bool:
	return state == "worn" or state == "pending_on" or state == "root"


## The kind's motif behind the picture on a plate in colour: light rays for what changes a move (a twist, a technique, a new
## skill, a skill set), a soft ring for a number trade (enhance, synergy, passive); none on a root (its key badge speaks).
func _draw_motif(s: Vector2, strength: float) -> void:
	var c := s * 0.5
	var r := minf(s.x, s.y) * 0.5
	var light := Color.from_hsv(_hue().h, 0.25, 1.0)
	if kind in ["variation", "mastery", "new_skill", "skill_set", "world_only"]:
		var n := 12 if kind == "mastery" else (8 if kind == "new_skill" else 10)
		var off := float(absi(shown_id.hash()) % 100) * 0.0628
		for i in n:
			var a := off + TAU * float(i) / float(n)
			var w := 0.11 if kind != "mastery" else 0.08
			var p := PackedVector2Array([c, c + Vector2.from_angle(a - w) * r * 1.3, c + Vector2.from_angle(a + w) * r * 1.3])
			draw_colored_polygon(p, Color(light, 0.075 * strength))
	elif kind != "":
		draw_arc(c, r * 0.72, 0.0, TAU, 36, Color(light, 0.14 * strength), 2.0, true)
		draw_arc(c, r * 0.52, 0.0, TAU, 32, Color(light, 0.08 * strength), 1.4, true)


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
		draw_polyline(closed, Color(gc, 0.22 + (0.14 if _hover else 0.0)), 10.0, true)
	var back := poly.duplicate()
	back.append(poly[0])
	draw_polyline(back, Color(0, 0, 0, 0.7), 6.5, true)
	# the plate: a deep jewel bright at the middle and dark at the edge, clipped to the shape
	var cols := _plate_colours()
	var pt := AdvancementTheme.plate_tex(cols[0], cols[1])
	var uvs := PackedVector2Array()
	for p in poly:
		uvs.append((p - r.position) / r.size)
	draw_colored_polygon(poly, Color.WHITE, uvs, pt)
	if lit and shape != "root":
		_draw_motif(s, 1.0 if _lit_state() else 0.6)
	var isz := minf(s.x, s.y) * (0.8 if shape != "octagon" else 0.74)
	var ir := Rect2((s - Vector2(isz, isz)) * 0.5, Vector2(isz, isz))
	if lit:
		# a glow of the plate's light behind the picture (brighter when worn), a gloss on the upper half
		var gk := 0.34 if _lit_state() else 0.18
		draw_texture_rect(AdvancementTheme.glow_tex(), ir.grow(2.0), false, Color(Color.from_hsv(_hue().h, 0.7, 1.0), gk + 0.18 * _pulse))
		var gl := AdvancementTheme.ellipse_poly(Vector2(s.x * 0.5, s.y * 0.26), Vector2(s.x * 0.36, s.y * 0.15))
		draw_colored_polygon(gl, Color(1, 1, 1, 0.11 if _lit_state() else 0.06))
	# the picture, with a dark drop so its light lines read on the glow
	if pic != null:
		if lit:
			# a dark halo round the light lines (four nudges) and a drop below them
			for o: Vector2 in [Vector2(1.3, 0.0), Vector2(-1.3, 0.0), Vector2(0.0, 1.3), Vector2(0.0, -1.3)]:
				draw_texture_rect(pic, Rect2(ir.position + o, ir.size), false, Color(0.02, 0.01, 0.0, 0.32))
			draw_texture_rect(pic, Rect2(ir.position + Vector2(0.0, 2.0), ir.size), false, Color(0.02, 0.01, 0.0, 0.6))
		draw_texture_rect(pic, ir, false, _ink())
	else:
		var fnt := AdvancementTheme.font("head")
		var txt := badge if badge != "" else "?"
		draw_string(fnt, Vector2(0, s.y * 0.5 + 9), txt, HORIZONTAL_ALIGNMENT_CENTER, s.x, 26, _ink())
	# a shut or held plate is dimmed over its picture, so a pick you cannot take reads grey at a glance
	if not lit and state != "pending_off":
		draw_colored_polygon(poly, Color(0.03, 0.035, 0.05, 0.28))
	# the border
	var edge := poly.duplicate()
	edge.append(poly[0])
	if state == "held":
		AdvancementTheme.dashed_outline(self, poly, bc, 2.4)
	else:
		draw_polyline(edge, bc, 3.0 if lit or gate_num > 0 else 2.4, true)
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
	var pl := PackedVector2Array([Vector2(-1.5, cy - 8.0), Vector2(-9.5, cy), Vector2(-1.5, cy + 8.0)])
	var pr := PackedVector2Array([Vector2(size.x + 1.5, cy - 8.0), Vector2(size.x + 9.5, cy), Vector2(size.x + 1.5, cy + 8.0)])
	draw_colored_polygon(pl, tc)
	draw_colored_polygon(pr, tc)
	draw_polyline(PackedVector2Array([pl[0], pl[1], pl[2], pl[0]]), Color(0, 0, 0, 0.55), 1.0, true)
	draw_polyline(PackedVector2Array([pr[0], pr[1], pr[2], pr[0]]), Color(0, 0, 0, 0.55), 1.0, true)


## The marks sit on the plate's corners, half on it, so nothing reaches a neighbour: the kind top left, the skill set top
## right, the rank (or a gate's padlock) in a small plate on the lower right corner, the green "plays in matches" dot lower left.
func _draw_marks(bc: Color) -> void:
	var fnt := AdvancementTheme.font("head2")
	var mr := 9.5
	if kind != "" and shape != "root":
		var km := AdvancementTheme.kind_mark(kind)
		if km != null:
			var kc := Vector2(4.0, 4.0)
			draw_circle(kc, mr, Color(0.035, 0.04, 0.055, 0.94))
			draw_arc(kc, mr, 0, TAU, 20, Color(bc, 0.85), 1.3, true)
			draw_texture_rect(km, Rect2(kc - Vector2(mr - 2.5, mr - 2.5), Vector2(mr - 2.5, mr - 2.5) * 2.0), false,
					Color(1.0, 0.9, 0.55) if state in ["worn", "pending_on", "available"] else Color(0.65, 0.68, 0.74))
	if set_id != "" and shape != "root":
		var sm := AdvancementTheme.set_mark(set_id)
		if sm != null:
			var sc := Vector2(size.x - 4.0, 4.0)
			draw_circle(sc, mr, Color(0.035, 0.04, 0.055, 0.94))
			draw_arc(sc, mr, 0, TAU, 20, Color(AdvancementTheme.set_tint(set_id), 0.9), 1.3, true)
			draw_texture_rect(sm, Rect2(sc - Vector2(mr - 2.5, mr - 2.5), Vector2(mr - 2.5, mr - 2.5) * 2.0), false, AdvancementTheme.set_tint(set_id))
	if shape == "root":
		# a root's key sits in a small plate on its lower edge
		var px := 17
		var tw := fnt.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var pw := maxf(tw + 12.0, 28.0)
		var ph := 19.0
		var pr := Rect2((size.x - pw) * 0.5, size.y - ph * 0.5 - 1.0, pw, ph)
		var pp := AdvancementTheme.rounded_poly(pr, 6.0, 3)
		draw_colored_polygon(pp, Color(0.035, 0.04, 0.055, 0.96))
		var pe := pp.duplicate()
		pe.append(pp[0])
		var tcol := AdvancementData.color("worn")
		draw_polyline(pe, Color(tcol, 0.85), 1.3, true)
		draw_string(fnt, Vector2(pr.position.x, pr.position.y + ph * 0.5 + 6.0), badge, HORIZONTAL_ALIGNMENT_CENTER, pw, px, tcol)
	elif gate_num > 0 or rank_text != "":
		# the rank (or the gate's padlock) in a small dark plate inside the lower right corner, as the reference prints it
		var px2 := 14
		var gate := gate_num > 0 and state == "blocked"
		var txt := "" if gate else rank_text
		var tcol2 := AdvancementData.color("worn") if state in ["worn", "pending_on"] else (AdvancementData.color("available") if state == "available" else AdvancementData.color("text_dim").lightened(0.15))
		var gtxt := str(gate_num)
		var tw2 := (12.0 + 2.0 + fnt.get_string_size(gtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, px2).x) if gate else fnt.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px2).x
		var pw2 := tw2 + 8.0
		var ph2 := 16.0
		var pr2 := Rect2(size.x - pw2 - 1.0, size.y - ph2 - 1.0, pw2, ph2)
		var pp2 := AdvancementTheme.rounded_poly(pr2, 4.0, 2)
		draw_colored_polygon(pp2, Color(0.025, 0.028, 0.04, 0.92))
		if gate:
			var gc := AdvancementData.color("gate").lightened(0.2)
			var pe2 := pp2.duplicate()
			pe2.append(pp2[0])
			draw_polyline(pe2, Color(gc, 0.85), 1.2, true)
			var lock := AdvancementTheme.tex("res://assets/ui/advancement/padlock.svg")
			if lock != null:
				draw_texture_rect(lock, Rect2(pr2.position + Vector2(3.0, 2.0), Vector2(12, 12)), false, gc)
			draw_string(fnt, Vector2(pr2.position.x + 17.0, pr2.position.y + ph2 - 3.5), gtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, px2, gc)
		else:
			draw_string(fnt, Vector2(pr2.position.x, pr2.position.y + ph2 - 3.5), txt, HORIZONTAL_ALIGNMENT_CENTER, pw2, px2, tcol2)
	if live and shape != "root":
		# plays in matches: a small green dot with a dark play mark at the lower left corner
		var dc := Vector2(4.0, size.y - 4.0)
		draw_circle(dc, 7.5, Color(0.02, 0.03, 0.03, 0.95))
		draw_circle(dc, 5.8, AdvancementData.color("live"))
		draw_colored_polygon(PackedVector2Array([dc + Vector2(-1.9, -3.0), dc + Vector2(3.2, 0.0), dc + Vector2(-1.9, 3.0)]), Color(0.03, 0.12, 0.06))
