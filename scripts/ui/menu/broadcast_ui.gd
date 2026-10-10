class_name BroadcastUI
extends RefCounted
## THE BROADCAST MENUS' KIT (the owner chose "Arena broadcast" from four mock-ups, 2026-10-10): the one place for the menus'
## look. A deep navy base, white type, one league accent (tide teal) and the four elements' own colours (MatchSetup.color)
## on plates that lean like a sports graphic; numbered rows with a clear focus state, segmented choices, key caps, soft
## shading. Used by the main menu (the lobby), the match setup, the ring's Esc menu and the match-end board; the fight HUD
## takes nothing from it (no plates, no cards over the match).
##
## TYPE. Barlow Condensed (ExtraBold for headlines and numerals, Bold for small spaced capitals) and Barlow Semi Condensed
## (Medium and SemiBold for lines), bundled in assets/fonts/barlow (SIL Open Font License; Vietnamese diacritics covered);
## headlines lean a little through a FontVariation. Every size is a DESIGN size at 1600 x 900, none under MIN_PX (16). The
## layouts are drawn at 1600 x 900 and scaled to a smaller window by a Layout (as the main menu always fitted itself); the
## type is then raised by `boost` so that nothing is under 14 px on screen at 1280 x 720 (16 px x 0.8 x 1.094 = 14).
##   BroadcastUI.lab(text, font, px, colour, align)   a Label at design size px (retyped when the window's fit changes)
##   BroadcastUI.row(num, title, sub, el)             a numbered, focusable row of the rundown (a Row: Text and Sub labels)
##   BroadcastUI.segments(options, chosen, el)        a segmented choice of chips (Segments: picked(i), set_chosen(i))
##   BroadcastUI.item / label / heading               MenuUI's drop-ins for a sub-screen in the broadcast look
##   BroadcastUI.Layout                               the 1600 x 900 design space fitted to the window (refit())
## The element marks (Glyph) are our own vector drawings: two peaks, three waves, a flame, three winds, four diamonds.

const NAVY0 := Color("060c17")
const NAVY1 := Color("0b1525")
const NAVY2 := Color("12213a")
const NAVY3 := Color("1b2e4d")
const LINE := Color("2a4064")
const WHITE := Color("f4f7fb")
const DIM := Color("b4c1d3")
const FAINT := Color("8396b0")
const TEAL := Color("21d4c2")
const INK := Color("07101d")
## The slant of every plate (x per unit of height) and of the oblique headline type.
const LEAN := 0.26
const SLANT := 0.16
## The design space the layouts are drawn in, and the smallest type in it.
const DESIGN := Vector2(1600.0, 900.0)
const MIN_PX := 16
## The least a design size may come to on screen when the window is smaller than the design (the audit's floor at 1280 x 720).
const MIN_SCREEN_PX := 14.0
## How far a layout is scaled up for a window larger than the design (a 1080p window draws it 1.2 times, a 1440p one 1.5 times).
const MAX_UP := 1.5
## The smallest window the menus are drawn for (a main menu sets it as its window's least size).
const MIN_WINDOW := Vector2i(1280, 720)
const HEAD_XB := "res://assets/fonts/barlow/BarlowCondensed-ExtraBold.ttf"
const HEAD_B := "res://assets/fonts/barlow/BarlowCondensed-Bold.ttf"
const HEAD_SB := "res://assets/fonts/barlow/BarlowCondensed-SemiBold.ttf"
const BODY_M := "res://assets/fonts/barlow/BarlowSemiCondensed-Medium.ttf"
const BODY_SB := "res://assets/fonts/barlow/BarlowSemiCondensed-SemiBold.ttf"
const BLUR_SHADER := "res://assets/ui/menu/blur.gdshader"

## How much the type is raised for a window smaller than the design, and the fit the layouts are scaled by now.
static var boost := 1.0
static var fit := 1.0
static var _fonts := {}
## The pointer over a row chooses it (a tool that takes screenshots turns this off: the owner's own pointer is over the window).
static var hover_focus := true
static var _pointer := Vector2(-1.0e6, -1.0e6)


## Whether this motion is the pointer really moving (it differs from the last seen by a pixel): a row that opens or closes under
## a resting pointer, or a window that redraws, makes motion events of its own that must not choose another row.
static func pointer_moved(e: InputEventMouseMotion) -> bool:
	var moved := e.global_position.distance_to(_pointer) >= 1.0
	_pointer = e.global_position
	return moved and hover_focus


# ================================================================ type
static func _font(path: String) -> Font:
	if not _fonts.has(path):
		_fonts[path] = load(path) as Font if ResourceLoader.exists(path) else ThemeDB.fallback_font
	return _fonts[path]


static func _variation(base: Font, key: String, slant: float, spacing: int) -> Font:
	if slant == 0.0 and spacing == 0:
		return base
	var k := "%s|%.2f|%d" % [key, slant, spacing]
	if not _fonts.has(k):
		var v := FontVariation.new()
		v.base_font = base
		if slant != 0.0:
			v.variation_transform = Transform2D(Vector2(1, 0), Vector2(-slant, 1), Vector2.ZERO)
		v.spacing_glyph = spacing
		_fonts[k] = v
	return _fonts[k]


## The headline and numeral face: Barlow Condensed, ExtraBold by default (`weight` 1 Bold, 2 SemiBold), leaning when `oblique`.
static func head(oblique := false, spacing := 0, weight := 0) -> Font:
	var path := [HEAD_XB, HEAD_B, HEAD_SB][clampi(weight, 0, 2)] as String
	return _variation(_font(path), "head%d" % weight, SLANT if oblique else 0.0, spacing)


## The text face: Barlow Semi Condensed, Medium (SemiBold when `bold`).
static func body(bold := false, spacing := 0) -> Font:
	return _variation(_font(BODY_SB if bold else BODY_M), "body%d" % int(bold), 0.0, spacing)


## A design size on screen now: raised for a small window so that the smallest type stays readable.
static func scaled(px: int) -> int:
	return ceili(float(maxi(px, MIN_PX)) * boost)


## The window's fit (the layouts' scale: under 1 below 1600 x 900, up to MAX_UP above it) taken: the type's boost with it (a window
## smaller than the design raises the type; a larger one scales the whole layout up, so 16 px text is not 16 px on a 4K screen).
static func set_fit(f: float) -> void:
	fit = clampf(f, 0.01, MAX_UP)
	boost = maxf(1.0, (MIN_SCREEN_PX / float(MIN_PX)) / fit)


## Every Label, Button and chip under `root` set to its design size at the boost now (after a window's fit changed).
static func retype(root: Node) -> void:
	for n in root.find_children("*", "Control", true, false):
		if n.has_meta(&"dsz") and (n is Label or n is Button):
			n.add_theme_font_size_override("font_size", scaled(int(n.get_meta(&"dsz"))))
		if n is Row:
			(n as Row).relayout()
	# (a layout that depends on the type's size: the match card's rows, its lines wrapping)
	for n in root.find_children("*", "Control", true, false):
		if n.has_meta(&"on_retype"):
			var cb: Callable = n.get_meta(&"on_retype")
			if cb.is_valid():
				cb.call()


static func style_text(c: Control, font: Font, px: int, col: Color) -> void:
	c.add_theme_font_override("font", font)
	c.set_meta(&"dsz", maxi(px, MIN_PX))
	c.add_theme_font_size_override("font_size", scaled(px))
	c.add_theme_color_override("font_color", col)


## A one-line Label: `text` in `font` at design size `px`.
static func lab(text: String, font: Font, px: int, c := WHITE, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	style_text(l, font, px, c)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A Label shown in capitals (its `text` kept as given).
static func caps(text: String, font: Font, px: int, c := WHITE, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := lab(text, font, px, c, align)
	l.uppercase = true
	return l


## A wrapped paragraph `w` px wide.
static func para(text: String, font: Font, px: int, c: Color, w: float) -> Label:
	var l := lab(text, font, px, c)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(w, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	return l


## `l`'s design size lowered until its text is no wider than `max_w` (a long name in a big plate), to `min_px` at the least.
static func fit_text(l: Label, max_w: float, min_px := 30) -> void:
	var px := int(l.get_meta(&"dsz", MIN_PX))
	var f := l.get_theme_font("font")
	while px > min_px and f.get_string_size(l.text.to_upper() if l.uppercase else l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > max_w:
		px -= 2
	l.set_meta(&"dsz", px)
	l.add_theme_font_size_override("font_size", scaled(px))


# ================================================================ the plates
## A flat or leaning plate's style.
static func box(c: Color, lean := LEAN, border := 0, border_c := Color.TRANSPARENT, pad := Vector4(16, 6, 16, 6)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.skew = Vector2(lean, 0)
	s.anti_aliasing = true
	s.anti_aliasing_size = 0.8
	if border > 0:
		s.set_border_width_all(border)
		s.border_color = border_c
	s.content_margin_left = pad.x
	s.content_margin_top = pad.y
	s.content_margin_right = pad.z
	s.content_margin_bottom = pad.w
	return s


static func plate(parent: Control, r: Rect2, c: Color, lean := LEAN, border := 0, border_c := Color.TRANSPARENT) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", box(c, lean, border, border_c))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	put(parent, p, r)
	return p


## A plate that holds `inside` (a container sized by its content): a PanelContainer.
static func chip(inside: Control, c: Color, lean := LEAN, pad := Vector4(14, 4, 14, 4), border := 0, border_c := Color.TRANSPARENT) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(c, lean, border, border_c, pad))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(inside)
	return p


## A chip of text: `text` in capitals in the headline face on plate `bg`.
static func tag(text: String, px: int, fg: Color, bg: Color, spacing := 2, pad := Vector4(12, 2, 12, 0)) -> PanelContainer:
	var l := caps(text, head(false, spacing, 1), px, fg, HORIZONTAL_ALIGNMENT_CENTER)
	return chip(l, bg, LEAN, pad)


## A key cap ("ENTER", "ESC", "E"): its name in a bordered box.
static func key_cap(key: String, px := 16) -> PanelContainer:
	var k := lab(key, head(false, 1, 1), px, WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	var kc := chip(k, Color(NAVY3, 0.9), 0.0, Vector4(8, 3, 8, 1), 1, Color(DIM, 0.55))
	(kc.get_theme_stylebox("panel") as StyleBoxFlat).set_corner_radius_all(3)
	return kc


## A key hint: a cap, then what it does in capitals.
static func key_hint(key: String, what: String, px := 18) -> HBoxContainer:
	var h := hbox(8)
	h.add_child(key_cap(key, maxi(px - 2, MIN_PX)))
	if what != "":
		h.add_child(caps(what, head(false, 2, 1), px, DIM))
	return h


static func put(parent: Control, c: Control, r: Rect2) -> Control:
	parent.add_child(c)
	c.position = r.position
	c.size = r.size
	return c


static func hbox(sep := 0) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


static func vbox(sep := 0) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


static func gap(w: float, h: float) -> Control:
	var g := Control.new()
	g.custom_minimum_size = Vector2(w, h)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


static func rect(parent: Control, r: Rect2, c: Color) -> ColorRect:
	var cr := ColorRect.new()
	cr.color = c
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	put(parent, cr, r)
	return cr


## A gradient over the whole of `parent` (anchored to `anchors`, 0..1 of it): `stops` [[offset, Color]...] from `from` to `to`.
static func grad(parent: Control, stops: Array, from: Vector2, to: Vector2, anchors := Rect2(0, 0, 1, 1)) -> TextureRect:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for s: Array in stops:
		offs.append(float(s[0]))
		cols.append(s[1])
	g.offsets = offs
	g.colors = cols
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = from
	t.fill_to = to
	t.width = 256
	t.height = 256
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	r.anchor_left = anchors.position.x
	r.anchor_top = anchors.position.y
	r.anchor_right = anchors.position.x + anchors.size.x
	r.anchor_bottom = anchors.position.y + anchors.size.y
	r.offset_left = 0
	r.offset_top = 0
	r.offset_right = 0
	r.offset_bottom = 0
	return r


## A picture covering `parent`.
static func picture(parent: Control, tex: Texture2D, cover := true) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if cover else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return r


## A group anchored to `anchor` of `parent` (0..1 each way) with its top-left at `pos` from that anchor point, `sz` big: a
## screen's parts keep to their corner or edge as the window's shape changes.
static func group(parent: Control, anchor: Vector2, pos: Vector2, sz: Vector2) -> Control:
	var g := Control.new()
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(g)
	g.anchor_left = anchor.x
	g.anchor_right = anchor.x
	g.anchor_top = anchor.y
	g.anchor_bottom = anchor.y
	g.offset_left = pos.x
	g.offset_top = pos.y
	g.offset_right = pos.x + sz.x
	g.offset_bottom = pos.y + sz.y
	return g


## A leaning slab from the top of `p` down to `h`, `x0`..`x1` at its foot, fading from `top` to `foot` alpha.
static func slab(p: Control, x0: float, x1: float, h: float, c: Color, top: float, foot: float, lean := LEAN) -> Polygon2D:
	var d := h * lean
	var g := Polygon2D.new()
	g.polygon = PackedVector2Array([Vector2(x0 + d, 0), Vector2(x1 + d, 0), Vector2(x1, h), Vector2(x0, h)])
	g.vertex_colors = PackedColorArray([Color(c, top), Color(c, top), Color(c, foot), Color(c, foot)])
	g.antialiased = true
	p.add_child(g)
	return g


## An element's colour (data/ring/elements.json through MatchSetup), Any the gold of Any.
static func ec(el: String) -> Color:
	return MatchSetup.color(el)


## The element's colour for a big fill (the light Air reads as a plate, not a glare).
static func plate_c(el: String) -> Color:
	if el == "air":
		return Color("bfe3f5")
	return ec(el)


## A section's label: "PLAY" in the accent, spaced, a hairline after it to `w`.
static func section(parent: Control, at: Vector2, text: String, w: float, c := TEAL) -> Label:
	var l := caps(text, head(false, 5, 1), 18, c)
	put(parent, l, Rect2(at, Vector2(200, 24)))
	var tw := l.get_minimum_size().x
	rect(parent, Rect2(at + Vector2(tw + 14, 11), Vector2(maxf(w - tw - 14, 8.0), 1)), Color(LINE, 0.9))
	return l


## A blurred and dimmed copy of what is drawn under it (the ring behind an overlay, softened by mip level): over the whole of
## `parent`. `dim` how far to the navy tint, `blur` the mip level.
static func backdrop_blur(parent: Control, blur := 2.6, dim := 0.45) -> ColorRect:
	var r := ColorRect.new()
	r.name = "Blur"
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(BLUR_SHADER):
		var m := ShaderMaterial.new()
		m.shader = load(BLUR_SHADER) as Shader
		m.set_shader_parameter("blur", blur)
		m.set_shader_parameter("dim", dim)
		r.material = m
	else:
		r.color = Color(NAVY0, 0.7)
	parent.add_child(r)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return r


# ================================================================ marks and hatching
## Hatching: thin diagonal lines across its rect (clipped to it); a fade to nothing toward the bottom when `fade` > 0.
class Stripes extends Control:
	var color := Color(1, 1, 1, 0.06)
	var gap := 14.0
	var width := 3.0
	var lean := 1.0
	var fade := 0.0

	func _draw() -> void:
		var h := size.y
		var x := -h * absf(lean) - gap
		while x < size.x + h * absf(lean) + gap:
			if fade <= 0.0:
				draw_line(Vector2(x + h * lean, 0), Vector2(x, h), color, width, true)
			else:
				var steps := 8
				for i in steps:
					var y0 := h * i / steps
					var y1 := h * (i + 1) / steps
					var k := clampf(1.0 - fade * float(i) / steps, 0.0, 1.0)
					draw_line(Vector2(x + (h - y0) * lean, y0), Vector2(x + (h - y1) * lean, y1), Color(color, color.a * k), width, true)
			x += gap


static func stripes(parent: Control, r: Rect2, c: Color, g := 14.0, w := 3.0, fade := 0.0) -> Control:
	var s := Stripes.new()
	s.color = c
	s.gap = g
	s.width = w
	s.fade = fade
	s.clip_contents = true
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	put(parent, s, r)
	return s


## The marks, drawn in vectors (our own: no font icons, no third-party art): earth two peaks, water three waves, fire a flame
## with its core, air three curling winds, any the four elements' diamonds, diamond, play (Watch), next and prev (chevrons).
## `color` the mark, `cut` the colour its inner lines are cut in (the plate under it).
class Glyph extends Control:
	var kind := "fire"
	var color := Color.WHITE
	var cut := Color(0.04, 0.07, 0.12)
	var palette := {}

	func _p(x: float, y: float) -> Vector2:
		var s := minf(size.x, size.y)
		var o := (size - Vector2(s, s)) * 0.5
		return o + Vector2(x, y) * s

	func _poly(pts: Array, c: Color) -> void:
		var v := PackedVector2Array()
		for p: Vector2 in pts:
			v.append(_p(p.x, p.y))
		draw_colored_polygon(v, c)

	func _line(pts: Array, c: Color, w: float) -> void:
		var v := PackedVector2Array()
		for p: Vector2 in pts:
			v.append(_p(p.x, p.y))
		draw_polyline(v, c, w * minf(size.x, size.y), true)

	func _arc(cx: float, cy: float, r: float, a0: float, a1: float, n := 14) -> Array:
		var out: Array = []
		for i in n + 1:
			var a := lerpf(a0, a1, float(i) / n)
			out.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
		return out

	func _draw() -> void:
		match kind:
			"fire":
				_poly([Vector2(0.50, 1.00), Vector2(0.29, 0.95), Vector2(0.15, 0.80), Vector2(0.12, 0.62), Vector2(0.19, 0.44),
						Vector2(0.30, 0.30), Vector2(0.33, 0.47), Vector2(0.41, 0.53), Vector2(0.43, 0.36), Vector2(0.51, 0.18),
						Vector2(0.62, 0.00), Vector2(0.65, 0.19), Vector2(0.75, 0.33), Vector2(0.86, 0.51), Vector2(0.89, 0.70),
						Vector2(0.83, 0.86), Vector2(0.70, 0.96)], color)
				_poly([Vector2(0.51, 0.95), Vector2(0.39, 0.90), Vector2(0.34, 0.79), Vector2(0.38, 0.66), Vector2(0.46, 0.57),
						Vector2(0.51, 0.68), Vector2(0.57, 0.59), Vector2(0.65, 0.71), Vector2(0.67, 0.83), Vector2(0.61, 0.92)], cut)
			"water":
				for row in 3:
					var y := 0.28 + row * 0.23
					var pts: Array = []
					for i in 25:
						var x := 0.06 + 0.88 * i / 24.0
						pts.append(Vector2(x, y + sin((x - 0.06) / 0.88 * TAU * 1.5) * 0.065))
					_line(pts, color, 0.10)
			"air":
				var a: Array = [Vector2(0.06, 0.30), Vector2(0.62, 0.30)]
				a.append_array(_arc(0.62, 0.17, 0.13, PI * 0.5, -PI * 0.75))
				_line(a, color, 0.085)
				var b: Array = [Vector2(0.06, 0.52), Vector2(0.80, 0.52)]
				b.append_array(_arc(0.80, 0.65, 0.13, -PI * 0.5, PI * 0.75))
				_line(b, color, 0.085)
				var c: Array = [Vector2(0.20, 0.76), Vector2(0.52, 0.76)]
				c.append_array(_arc(0.52, 0.86, 0.10, -PI * 0.5, PI * 0.6))
				_line(c, color, 0.085)
			"earth":
				_poly([Vector2(0.04, 0.90), Vector2(0.42, 0.14), Vector2(0.80, 0.90)], color)
				_poly([Vector2(0.42, 0.14), Vector2(0.50, 0.30), Vector2(0.44, 0.40), Vector2(0.36, 0.34), Vector2(0.30, 0.38)], cut)
				_poly([Vector2(0.48, 0.90), Vector2(0.71, 0.46), Vector2(0.96, 0.90)], cut)
				_poly([Vector2(0.56, 0.90), Vector2(0.71, 0.60), Vector2(0.88, 0.90)], color)
			"any":
				var cs: Array = [palette.get("earth", color), palette.get("water", color), palette.get("fire", color), palette.get("air", color)]
				var at := [Vector2(0.5, 0.2), Vector2(0.8, 0.5), Vector2(0.5, 0.8), Vector2(0.2, 0.5)]
				for i in 4:
					var q: Vector2 = at[i]
					_poly([q + Vector2(0, -0.17), q + Vector2(0.17, 0), q + Vector2(0, 0.17), q + Vector2(-0.17, 0)], cs[i])
			"diamond":
				_poly([Vector2(0.5, 0.0), Vector2(1.0, 0.5), Vector2(0.5, 1.0), Vector2(0.0, 0.5)], color)
			"play":
				_poly([Vector2(0.22, 0.10), Vector2(0.90, 0.50), Vector2(0.22, 0.90)], color)
			"next":
				_line([Vector2(0.32, 0.12), Vector2(0.70, 0.50), Vector2(0.32, 0.88)], color, 0.16)
			"prev":
				_line([Vector2(0.68, 0.12), Vector2(0.30, 0.50), Vector2(0.68, 0.88)], color, 0.16)
			"up":
				_line([Vector2(0.12, 0.68), Vector2(0.50, 0.30), Vector2(0.88, 0.68)], color, 0.16)
			"down":
				_line([Vector2(0.12, 0.32), Vector2(0.50, 0.70), Vector2(0.88, 0.32)], color, 0.16)


static func glyph(kind: String, c: Color, px: float, under := NAVY1) -> Control:
	var g := Glyph.new()
	g.kind = kind
	g.color = c
	g.cut = under
	g.custom_minimum_size = Vector2(px, px)
	g.size = Vector2(px, px)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if kind == "any":
		g.palette = {"earth": ec("earth"), "water": ec("water"), "fire": ec("fire"), "air": ec("air")}
	return g


# ================================================================ the design space fitted to the window
## The size of the window `c` is drawn in: its viewport's, but never under 480 x 270 (a headless run's viewport is 64 x 64: its
## screens are then laid at the design size, so a test measures what a player sees, not a type 20 times too big).
static func view_size(c: Control) -> Vector2:
	var v := c.get_viewport_rect().size
	if v.x < 480.0 or v.y < 270.0:
		return DESIGN
	return v


## The design space (1600 x 900) as a Control, fitted to the window as the main menu always fitted its layout: scaled down so that
## it fits whole, and up (to MAX_UP) in a window larger than the design, its size the window's over the scale (so a wider window
## gives it more room at its right and foot, the parts anchored to their edges). Set the fit before the parts are made (refit() in
## _ready: the type's boost).
class Layout extends Control:
	func _init() -> void:
		name = "Layout"
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		refit()
		var vp := get_viewport()
		if vp != null and not vp.size_changed.is_connected(refit):
			vp.size_changed.connect(refit)

	var _last := -1.0

	func refit() -> void:
		var view := BroadcastUI.view_size(self)
		# (up to MAX_UP as well as down: capped at 1, a 1920 x 1080 window drew the 1600 x 900 design at its own size, the setup's
		# fighter cards and every plate about 30% smaller on screen than the approved mock-up, a band of empty deck under them)
		var f := maxf(minf(BroadcastUI.MAX_UP, minf(view.x / BroadcastUI.DESIGN.x, view.y / BroadcastUI.DESIGN.y)), 0.01)
		scale = Vector2.ONE * f
		size = view / f
		position = Vector2.ZERO
		if not is_equal_approx(f, _last):
			_last = f
			BroadcastUI.set_fit(f)
			BroadcastUI.retype(self)


## The design space covering the window, as a picture of 16 : 9 does (the deck plate and the fighter drawn over it): scaled to
## cover, centred, so what is placed on it stays on the picture's own places whatever the window's shape.
class CoverLayout extends Control:
	func _init() -> void:
		name = "CoverLayout"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = BroadcastUI.DESIGN

	func _ready() -> void:
		refit()
		var vp := get_viewport()
		if vp != null and not vp.size_changed.is_connected(refit):
			vp.size_changed.connect(refit)

	func refit() -> void:
		var view := BroadcastUI.view_size(self)
		var s := maxf(view.x / BroadcastUI.DESIGN.x, view.y / BroadcastUI.DESIGN.y)
		scale = Vector2.ONE * s
		size = BroadcastUI.DESIGN
		position = (view - BroadcastUI.DESIGN * s) * 0.5


static func cover(parent: Control) -> CoverLayout:
	var l := CoverLayout.new()
	parent.add_child(l)
	l.refit()
	return l


static func layout(parent: Control) -> Layout:
	var l := Layout.new()
	parent.add_child(l)
	l.refit()
	return l


# ================================================================ the rundown's rows
## A numbered row of a rundown (the lobby's, the Esc menu's): rests as a number and a title; focused it opens into a plate, the
## number on the element's colour, its line under it, a chevron and the accent's underline. Text and Sub are its labels.
class Row extends Button:
	var w := 560.0
	var rest_h := 52.0
	var open_h := 90.0
	var open_h_bare := 68.0
	var element := "fire"
	var badge := ""
	## Drawn open as if focused while its panel is open at the right (the Esc menu's row that opened Match setup or Options).
	var held := false
	var _plate: Panel
	var _num_plate: Panel
	var _num: Label
	var _text: Label
	var _sub: Label
	var _chev: Control
	var _under: Panel
	var _tag: Control

	func setup(num: String, title: String, sub: String, el: String, width: float, tag_text: String) -> Row:
		w = width
		element = el
		badge = tag_text
		flat = true
		focus_mode = Control.FOCUS_ALL
		text = ""
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(st, empty)
		var pc := BroadcastUI.plate_c(el)
		_plate = Panel.new()
		_plate.name = "Plate"
		_plate.add_theme_stylebox_override("panel", BroadcastUI.box(Color(BroadcastUI.NAVY2, 0.95)))
		_num_plate = Panel.new()
		_num_plate.name = "NumPlate"
		_num_plate.add_theme_stylebox_override("panel", BroadcastUI.box(pc))
		_under = Panel.new()
		_under.name = "Under"
		_under.add_theme_stylebox_override("panel", BroadcastUI.box(BroadcastUI.TEAL, BroadcastUI.LEAN))
		for p: Control in [_plate, _num_plate, _under]:
			p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			p.visible = false
			add_child(p)
		_num = BroadcastUI.lab(num, BroadcastUI.head(), 28, BroadcastUI.FAINT, HORIZONTAL_ALIGNMENT_CENTER)
		_num.name = "Num"
		add_child(_num)
		_text = BroadcastUI.lab(title, BroadcastUI.head(true, 1, 2), 38, BroadcastUI.WHITE)
		_text.name = "Text"
		_text.uppercase = true
		add_child(_text)
		_sub = BroadcastUI.lab(sub, BroadcastUI.body(true), 18, BroadcastUI.DIM)
		_sub.name = "Sub"
		add_child(_sub)
		_chev = BroadcastUI.glyph("next", pc, 26)
		_chev.name = "Chevron"
		_chev.visible = false
		add_child(_chev)
		if tag_text != "":
			_tag = BroadcastUI.tag(tag_text, 16, BroadcastUI.INK, BroadcastUI.TEAL, 2)
			_tag.name = "Badge"
			add_child(_tag)
		relayout()
		return self

	func _notification(what: int) -> void:
		if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
			relayout()

	func _gui_input(event: InputEvent) -> void:
		# the mouse over a row chooses it, but only by moving: a row that opens under a resting pointer must not steal the focus
		if event is InputEventMouseMotion and BroadcastUI.pointer_moved(event) and not has_focus():
			grab_focus()

	func _ready() -> void:
		relayout()

	## Everything laid for the state now (focused or resting): called as the focus changes and as the type's size does.
	func relayout() -> void:
		if _text == null:
			return
		var on := has_focus() or held
		var k := BroadcastUI.boost                  # (the type is raised in a small window: the room it needs with it)
		var has_sub := _sub.text != ""
		var sub_y := 4.0 + 50.0 * k
		var rest := rest_h * k
		var h := rest
		if on:
			h = maxf(open_h, sub_y + 26.0 * k + 10.0) if has_sub else maxf(open_h_bare, 18.0 + 50.0 * k)
		custom_minimum_size = Vector2(w, h)
		_plate.visible = on
		_num_plate.visible = on
		_under.visible = on
		_chev.visible = on
		_plate.position = Vector2(-14, 0)
		_plate.size = Vector2(w, h)
		_num_plate.position = Vector2(-14, 0)
		_num_plate.size = Vector2(70, h)
		_under.position = Vector2(62, h - 4)
		_under.size = Vector2(w - 76, 4)
		_chev.position = Vector2(w - 56, h * 0.5 - 13.0 - (6.0 if has_sub else 0.0))
		BroadcastUI.style_text(_num, BroadcastUI.head(), 46 if on else 28, BroadcastUI.INK if on else BroadcastUI.FAINT)
		_num.position = Vector2(-12, 3 if on else 4)
		_num.size = Vector2(70, (h - 6.0) if on else (rest - 8.0))
		# (a resting row is a weight lighter and a little dimmer than the focused one: the plate is the hierarchy, not the type's weight)
		BroadcastUI.style_text(_text, BroadcastUI.head(true, 1, 1 if on else 2), 46 if on else 38,
				BroadcastUI.WHITE if on else BroadcastUI.WHITE.lerp(BroadcastUI.NAVY0, 0.15))
		var ty := 6.0 if on else 3.0
		_text.position = Vector2(78, ty)
		_text.size = Vector2(w - 130, 50.0 * k if on else rest - 6.0)
		if on and has_sub:
			_sub.visible = true
			_sub.position = Vector2(80, sub_y)
			_sub.size = Vector2(w - 110, 26.0 * k)
		else:
			_sub.visible = false
			_sub.position = Vector2(80, 2)
			_sub.size = Vector2(1, 1)
		if _tag != null:
			var tx := 78.0 + _text.get_minimum_size().x + 14.0
			_tag.position = Vector2(tx, ty + (12.0 if on else 11.0) * k)
			_tag.size = _tag.get_combined_minimum_size()

	func set_num(num: String) -> void:
		_num.text = num

	## Held open (or let go) while its panel stands at the right.
	func hold(on: bool) -> void:
		if held != on:
			held = on
			relayout()

	## The element's colour taken (the number's plate and the chevron): a row made before the match knew its element.
	func set_element(el: String) -> void:
		element = el
		var pc := BroadcastUI.plate_c(el)
		_num_plate.add_theme_stylebox_override("panel", BroadcastUI.box(pc))
		(_chev as Glyph).color = pc
		_chev.queue_redraw()

	func retitle(title: String, sub := "") -> void:
		_text.text = title
		if sub != "":
			_sub.text = sub
		relayout()


## A row of the rundown. `opts`: w (560), badge ("NEW"), open_h, rest_h.
static func row(num: String, title: String, sub := "", el := "fire", opts := {}) -> Row:
	var r := Row.new()
	r.rest_h = float(opts.get("rest_h", 52.0))
	r.open_h = float(opts.get("open_h", 90.0))
	r.setup(num, title, sub, el, float(opts.get("w", 560.0)), String(opts.get("badge", "")))
	r.name = String(opts.get("name", title.replace(" ", "")))
	return r


## A small row of the foot of a rundown ("07 SETTINGS"): its number and its word, the accent's underline when focused.
class Util extends Button:
	var _num: Label
	var _text: Label
	var _under: ColorRect

	func setup(num: String, title: String) -> Util:
		flat = true
		focus_mode = Control.FOCUS_ALL
		text = ""
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(st, empty)
		var h := BroadcastUI.hbox(8)
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 4
		h.offset_right = -4
		add_child(h)
		_num = BroadcastUI.lab(num, BroadcastUI.head(), 22, BroadcastUI.FAINT)
		h.add_child(_num)
		_text = BroadcastUI.lab(title, BroadcastUI.head(false, 2, 1), 26, BroadcastUI.DIM)
		_text.name = "Text"
		_text.uppercase = true
		h.add_child(_text)
		_under = ColorRect.new()
		_under.color = BroadcastUI.TEAL
		_under.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_under.visible = false
		add_child(_under)
		_under.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_under.offset_top = -3
		_under.offset_left = 4
		_under.offset_right = -4
		_hold = h
		h.minimum_size_changed.connect(_fit)
		_fit()
		return self

	var _hold: HBoxContainer

	func _fit() -> void:
		custom_minimum_size = Vector2(_hold.get_combined_minimum_size().x + 8.0, 38.0)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
			var on := has_focus()
			_under.visible = on
			_text.add_theme_color_override("font_color", BroadcastUI.WHITE if on else BroadcastUI.DIM)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion and BroadcastUI.pointer_moved(event) and not has_focus():
			grab_focus()


static func util(num: String, title: String) -> Util:
	var u := Util.new()
	u.setup(num, title)
	u.name = title.replace(" ", "")
	return u


# ================================================================ segmented choices
## A chip of a segmented choice: its words (and a mark) on a leaning plate; the chosen one filled, the focused one outlined.
class Chip extends Button:
	var _box: HBoxContainer
	var _text: Label
	var _mark: Control
	var fill := BroadcastUI.TEAL
	var chosen := false
	var pad := Vector2(14, 5)
	var value: Variant = null

	func setup(label_text: String, px: int, col: Color, mark_kind := "", val: Variant = null) -> Chip:
		flat = false
		focus_mode = Control.FOCUS_ALL
		text = ""
		fill = col
		value = val
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_box = BroadcastUI.hbox(7)
		_box.alignment = BoxContainer.ALIGNMENT_CENTER
		_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_box.offset_left = pad.x
		_box.offset_right = -pad.x
		_box.offset_top = pad.y
		_box.offset_bottom = -pad.y
		add_child(_box)
		if mark_kind != "":
			_mark = BroadcastUI.glyph(mark_kind, col, float(px) * 0.82, BroadcastUI.NAVY3)
			_box.add_child(_mark)
		_text = BroadcastUI.caps(label_text, BroadcastUI.head(false, 2, 1), px, BroadcastUI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
		_text.name = "Text"
		_box.add_child(_text)
		_box.minimum_size_changed.connect(_fit)
		_fit()
		paint()
		return self

	func _fit() -> void:
		custom_minimum_size = _box.get_combined_minimum_size() + pad * 2.0

	## The height the chip comes to for its type now: the container's own minimum is only right a frame after the chip was made or its
	## type raised (a layout that stacks things under chips reads this).
	func natural_h() -> float:
		var f := _text.get_theme_font("font")
		return f.get_height(_text.get_theme_font_size("font_size")) + pad.y * 2.0

	func _notification(what: int) -> void:
		if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT or what == NOTIFICATION_MOUSE_ENTER \
				or what == NOTIFICATION_MOUSE_EXIT:
			paint()

	func paint() -> void:
		if _text == null:
			return
		var lit := has_focus() or is_hovered()
		var bg := fill if chosen else (BroadcastUI.NAVY3.lightened(0.12) if lit else Color(BroadcastUI.NAVY3, 0.95))
		var sb := BroadcastUI.box(bg, BroadcastUI.LEAN, 3 if has_focus() else 0, BroadcastUI.WHITE, Vector4.ZERO)
		for st in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(st, sb)
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		_text.add_theme_color_override("font_color", BroadcastUI.INK if chosen else (BroadcastUI.WHITE if lit else BroadcastUI.DIM))
		if _mark != null:
			(_mark as Glyph).color = BroadcastUI.INK if chosen else fill
			(_mark as Glyph).cut = bg
			_mark.queue_redraw()

	func set_chosen(on: bool) -> void:
		chosen = on
		paint()



## A segmented choice (a row of chips): `options` Strings or {text, color, glyph, value}; `chosen` the index lit. A chip pressed
## (a click, Enter, the pad's accept) lights itself and emits picked(index) (the owner of the choice stores it).
class Segments extends HBoxContainer:
	signal picked(index: int)
	var chosen := 0
	var chips: Array = []

	func _init() -> void:
		add_theme_constant_override("separation", 6)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func add(c: Chip) -> void:
		var i := chips.size()
		chips.append(c)
		add_child(c)
		c.pressed.connect(func() -> void:
			set_chosen(i)
			picked.emit(i))

	func set_chosen(i: int) -> void:
		chosen = i
		for k in chips.size():
			(chips[k] as Chip).set_chosen(k == i)

	func chip(i: int) -> Chip:
		return chips[i] if i >= 0 and i < chips.size() else null


static func segments(options: Array, chosen := 0, px := 20, pad_x := 14.0) -> Segments:
	var s := Segments.new()
	for i in options.size():
		var o: Variant = options[i]
		var d: Dictionary = o if o is Dictionary else {"text": String(o)}
		var col: Color = d.get("color", TEAL)
		var c := Chip.new()
		c.pad = Vector2(pad_x, 5.0)
		c.setup(String(d.get("text", "")), px, col, String(d.get("glyph", "")), d.get("value", d.get("text", "")))
		c.name = String(d.get("name", "Chip%d" % i))
		s.add(c)
	s.set_chosen(chosen)
	return s


# ================================================================ an option of the Esc menu
## A row of the Esc menu's Match setup and Options panels: the option's name in capitals at the left, its values as chips at the
## right (the one in force lit), its line under them. A Button: pressed (Enter, a click on the row) it steps to the next value
## (the owner of the row's own cycle); Left and Right, and a click on a chip, ask `picker` for that value (an index). Its
## `Text` label (hidden: the old "Aim help:  light" words, kept for what reads them) and `Sub` label (the line) as the other rows'.
class OptionRow extends Button:
	var picker := Callable()
	var count := 0
	var chosen := 0
	var chips: Segments
	var _plate: Panel
	var _bar: ColorRect
	var _title: Label
	var _text: Label
	var _sub: Label

	func setup(title: String, options: Array, px: int, width: float) -> OptionRow:
		flat = true
		focus_mode = Control.FOCUS_ALL
		text = ""
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(st, empty)
		count = options.size()
		custom_minimum_size = Vector2(width, 76.0)
		_plate = Panel.new()
		_plate.name = "Plate"
		_plate.add_theme_stylebox_override("panel", BroadcastUI.box(Color(BroadcastUI.NAVY3, 0.8), 0.0))
		_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_plate.visible = false
		add_child(_plate)
		_plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_bar = ColorRect.new()
		_bar.name = "Rule"
		_bar.color = BroadcastUI.TEAL
		_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bar.visible = false
		add_child(_bar)
		_bar.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		_bar.offset_right = 4
		# (the words whole, hidden: the first `Text` under the row, ahead of the chips' own)
		_text = BroadcastUI.lab("", BroadcastUI.body(), 16, BroadcastUI.DIM)
		_text.name = "Text"
		_text.visible = false
		add_child(_text)
		var top := BroadcastUI.hbox(10)
		top.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(top)
		top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		top.offset_left = 14
		top.offset_right = -10
		top.offset_top = 6
		top.offset_bottom = 44
		_title = BroadcastUI.caps(title, BroadcastUI.head(false, 2), 26, BroadcastUI.WHITE)
		_title.name = "Title"
		_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(_title)
		chips = BroadcastUI.segments(options, 0, px, 11.0)
		chips.mouse_filter = Control.MOUSE_FILTER_PASS
		for c: Chip in chips.chips:
			c.focus_mode = Control.FOCUS_NONE
		chips.picked.connect(func(i: int) -> void:
			if picker.is_valid():
				picker.call(i))
		top.add_child(chips)
		if options.is_empty():
			# (a link to a panel of its own: Photo, Controls: a chevron where the chips would be)
			var chev := BroadcastUI.glyph("next", BroadcastUI.DIM, 20.0)
			chev.name = "Chevron"
			top.add_child(chev)
		_sub = BroadcastUI.lab("", BroadcastUI.body(), 16, BroadcastUI.DIM)
		_sub.name = "Sub"
		BroadcastUI.put(self, _sub, Rect2(14, 46, width - 28, 26))
		return self

	## The row as the option stands: its words whole (Text), the value in force, the line under it.
	func paint(words: String, index: int, line: String) -> void:
		_text.text = words
		chosen = clampi(index, 0, maxi(count - 1, 0))
		chips.set_chosen(chosen)
		if line != "":
			_sub.text = line

	func _notification(what: int) -> void:
		if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
			var on := has_focus()
			_plate.visible = on
			_bar.visible = on

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion and BroadcastUI.pointer_moved(event) and not has_focus():
			grab_focus()
		elif has_focus() and picker.is_valid() and count > 1:
			# (Left and Right go round, as Enter does: the last value's Right is the first, the first's Left the last)
			if event.is_action_pressed(&"ui_left", true):
				picker.call(posmod(chosen - 1, count))
				accept_event()
			elif event.is_action_pressed(&"ui_right", true):
				picker.call(posmod(chosen + 1, count))
				accept_event()


static func option_row(title: String, options: Array, width := 648.0, px := 18) -> OptionRow:
	return OptionRow.new().setup(title, options, px, width)


## A row that opens a screen of its own (Controls, Photo): its name in capitals, a chevron, its line under it. Its `Text` label
## holds the name whole.
static func link_row(title: String, line: String, width := 648.0) -> OptionRow:
	var r := OptionRow.new().setup(title, [], 18, width)
	r.paint(title, 0, line)
	return r


# ================================================================ an action of the match-end board
## A leaning plate along the foot of the match-end board: its name (Title, in capitals), its line under it (Sub) and, for the
## choices (your element, the opponent), the value in force as a chip with arrows. Focused it fills with the element's colour.
## Its `Text` label (hidden) holds the whole words ("Your element:  Fire") for what reads them; press it (Enter, a click).
class Action extends Button:
	var w := 330.0
	var element := "fire"
	var value_element := ""
	var _plate: Panel
	var _title: Label
	var _text: Label
	var _sub: Label
	var _value: HBoxContainer

	func setup(title: String, line: String, el: String, width: float, value_el := "") -> Action:
		w = width
		element = el
		value_element = value_el
		flat = true
		focus_mode = Control.FOCUS_ALL
		text = ""
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(st, empty)
		custom_minimum_size = Vector2(width, 70.0)
		_plate = Panel.new()
		_plate.name = "Plate"
		_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_plate)
		_plate.position = Vector2.ZERO
		_plate.size = Vector2(width - 14.0, 66.0)
		_title = BroadcastUI.caps(title, BroadcastUI.head(true, 2), 32, BroadcastUI.WHITE)
		_title.name = "Title"
		BroadcastUI.put(self, _title, Rect2(22, 3, width - 40, 38))
		_text = BroadcastUI.lab("", BroadcastUI.body(), 16, BroadcastUI.DIM)
		_text.name = "Text"
		_text.visible = false
		add_child(_text)
		_sub = BroadcastUI.lab(line, BroadcastUI.body(true), 16, BroadcastUI.DIM)
		_sub.name = "Sub"
		BroadcastUI.put(self, _sub, Rect2(24, 40, width - 50, 24))
		if value_el != "":
			_value = BroadcastUI.hbox(6)
			_value.name = "Value"
			add_child(_value)
		paint()
		return self

	func _notification(what: int) -> void:
		if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
			paint()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion and BroadcastUI.pointer_moved(event) and not has_focus():
			grab_focus()

	## The value shown (an element's chip with arrows) and the words whole (Text).
	func set_value(el: String, words := "") -> void:
		value_element = el
		if words != "":
			_text.text = words
		paint()

	func paint() -> void:
		if _plate == null:
			return
		var on := has_focus()
		var pc := BroadcastUI.plate_c(element)
		_plate.add_theme_stylebox_override("panel", BroadcastUI.box(pc if on else Color(BroadcastUI.NAVY1, 0.94), BroadcastUI.LEAN,
				3 if on else 0, BroadcastUI.WHITE))
		_title.add_theme_color_override("font_color", BroadcastUI.INK if on else BroadcastUI.WHITE)
		_sub.add_theme_color_override("font_color", Color(BroadcastUI.INK, 0.8) if on else BroadcastUI.DIM)
		if _value != null:
			for c in _value.get_children():
				_value.remove_child(c)
				c.queue_free()
			if value_element != "":
				var vc := BroadcastUI.plate_c(value_element)
				if value_element == "air" and not on:
					vc = Color("9fd4ee")
				var fg := BroadcastUI.INK if on else vc
				_value.add_child(BroadcastUI.glyph("prev", Color(BroadcastUI.INK, 0.6) if on else BroadcastUI.DIM, 12.0))
				_value.add_child(BroadcastUI.glyph(value_element, fg, 20.0, pc if on else BroadcastUI.NAVY1))
				_value.add_child(BroadcastUI.caps(MatchSetup.label(value_element), BroadcastUI.head(false, 2), 24, fg))
				_value.add_child(BroadcastUI.glyph("next", Color(BroadcastUI.INK, 0.6) if on else BroadcastUI.DIM, 12.0))
				_value.position = Vector2(32.0 + _title.get_minimum_size().x, 9.0)
				_value.size = _value.get_combined_minimum_size()


static func action(title: String, line: String, el: String, width: float, value_el := "") -> Action:
	return Action.new().setup(title, line, el, width, value_el)


# ================================================================ the sub-screens' rows (MenuUI's drop-ins)
## MenuUI.label's drop-in: the text in the body face (never under MIN_PX), in `color` (the accent for MenuUI.GOLD).
static func label(text: String, size: int, color := WHITE, wrap := false) -> Label:
	var l := lab(text, body(true) if size >= 20 else body(), size, color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP if wrap else VERTICAL_ALIGNMENT_CENTER
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## MenuUI.heading's drop-in: a headline with the accent's rule under it.
static func heading(text: String, size := 34) -> VBoxContainer:
	var v := vbox(6)
	var l := caps(text, head(true, 2), maxi(size + 8, 40), WHITE)
	v.add_child(l)
	var r := ColorRect.new()
	r.color = Color(TEAL, 0.75)
	r.custom_minimum_size = Vector2(0, 3)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(r)
	return v


## A row of a sub-screen (MenuUI.item's drop-in): its text (Text) and a line under it (Sub), the accent's bar and a plate when
## chosen; `off` greys it and says why. Returns the Button; connect `pressed`.
class Item extends Button:
	var _bar: ColorRect
	var _main: Label
	var _sub: Label
	var _plate: Panel
	var _off := false

	func setup(text_in: String, size: int, sub_text: String, off_text: String) -> Item:
		flat = true
		focus_mode = Control.FOCUS_ALL
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		text = ""
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(st, empty)
		_off = off_text != ""
		_plate = Panel.new()
		_plate.name = "Plate"
		_plate.add_theme_stylebox_override("panel", BroadcastUI.box(Color(BroadcastUI.NAVY3, 0.85), 0.0))
		_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_plate.visible = false
		add_child(_plate)
		_plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var row := BroadcastUI.hbox(14)
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(row)
		_bar = ColorRect.new()
		_bar.name = "Rule"
		_bar.color = Color(BroadcastUI.TEAL, 0.0)
		_bar.custom_minimum_size = Vector2(4, 0)
		_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(_bar)
		var col := BroadcastUI.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(col)
		_main = BroadcastUI.lab(text_in, BroadcastUI.body(true), size, BroadcastUI.WHITE if not _off else BroadcastUI.FAINT)
		_main.name = "Text"
		col.add_child(_main)
		if sub_text != "" or _off:
			_sub = BroadcastUI.lab(sub_text if not _off else off_text, BroadcastUI.body(), maxi(int(size * 0.72), MIN_PX), BroadcastUI.DIM if not _off else BroadcastUI.FAINT)
			_sub.name = "Sub"
			col.add_child(_sub)
		custom_minimum_size = Vector2(0, float(size) * (2.1 if _sub != null else 1.55))
		disabled = _off
		return self

	func _notification(what: int) -> void:
		if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
			if _off:
				return
			var on := has_focus()
			_bar.color = Color(BroadcastUI.TEAL, 1.0 if on else 0.0)
			_plate.visible = on
			_main.add_theme_color_override("font_color", BroadcastUI.TEAL if on else BroadcastUI.WHITE)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion and BroadcastUI.pointer_moved(event) and not has_focus() and not _off:
			grab_focus()

	## The line under the text may run to a second line (the setup's Controls row).
	func wrap_sub() -> Item:
		if _sub != null:
			_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_sub.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		return self


static func item(text: String, size := 30, sub := "", off := "") -> Button:
	return Item.new().setup(text, size, sub, off)


## A slider row (the settings): the label, a thin slider in the accent, the value in words from `fmt`.
static func slider(text: String, lo: float, hi: float, step: float, value: float, fmt: Callable, changed: Callable) -> HBoxContainer:
	var h := hbox(18)
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	var l := lab(text, body(true), 22, WHITE)
	l.custom_minimum_size = Vector2(240, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(240, 28)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var line := StyleBoxLine.new()
	line.color = Color(DIM, 0.5)
	line.thickness = 3
	s.add_theme_stylebox_override("slider", line)
	var fill := StyleBoxLine.new()
	fill.color = TEAL
	fill.thickness = 3
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	h.add_child(s)
	var v := lab(String(fmt.call(value)), body(), 20, DIM)
	v.custom_minimum_size = Vector2(90, 0)
	h.add_child(v)
	s.value_changed.connect(func(x: float) -> void:
		v.text = String(fmt.call(x))
		changed.call(x))
	return h


## A yes / no row (the settings): the label and the two words as a segmented choice.
static func toggle(text: String, on: bool, changed: Callable) -> HBoxContainer:
	var h := hbox(18)
	var l := lab(text, body(true), 22, WHITE)
	l.custom_minimum_size = Vector2(240, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var s := segments(["On", "Off"], 0 if on else 1, 18)
	s.picked.connect(func(i: int) -> void: changed.call(i == 0))
	h.add_child(s)
	return h


## The fighter's name for the screens: the saved look's own name, else "You".
static func fighter_name() -> String:
	return FighterWorld.fighter_name()
