extends RefCounted
## Menu style B, "Arena broadcast": its vocabulary. A deep navy broadcast base, white type, one league accent (tide
## teal) and the four elements' own colours (data/ring/elements.json through MatchSetup.color) on plates that lean like a
## sports graphic. Type: a bold condensed sans with big numerals (here the Mac's DIN Condensed Bold and Avenir Next
## Condensed through SystemFont; the real build would bundle Barlow Condensed and Barlow Semi Condensed, both SIL OFL).

const Glyph := preload("res://tools/ui_audit/menu_variants/b_broadcast/glyph.gd")
const Stripes := preload("res://tools/ui_audit/menu_variants/b_broadcast/stripes.gd")

const NAVY0 := Color("060c17")
const NAVY1 := Color("0b1525")
const NAVY2 := Color("12213a")
const NAVY3 := Color("1b2e4d")
const LINE := Color("2a4064")
const WHITE := Color("f4f7fb")
const DIM := Color("b4c1d3")
const FAINT := Color("7488a3")
const TEAL := Color("21d4c2")
const INK := Color("07101d")
## The slant of every plate (x per unit of height) and of the oblique headline type.
const LEAN := 0.26
const SLANT := 0.16

static var _fonts := {}


static func _sys(names: PackedStringArray, weight: int) -> SystemFont:
	var key := "%s/%d" % [",".join(names), weight]
	if not _fonts.has(key):
		var f := SystemFont.new()
		f.font_names = names
		f.font_weight = weight
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.hinting = TextServer.HINTING_LIGHT
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		f.allow_system_fallback = true
		_fonts[key] = f
	return _fonts[key]


static func _var(base: Font, key: String, slant: float, spacing: int) -> Font:
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


## The headline and numeral face: DIN Condensed Bold (the bundle: Barlow Condensed ExtraBold).
static func head(oblique := false, spacing := 0) -> Font:
	return _var(_sys(PackedStringArray(["DIN Condensed", "Avenir Next Condensed", "Helvetica Neue"]), 700), "head",
			SLANT if oblique else 0.0, spacing)


## The text face: Avenir Next Condensed at `weight` (the bundle: Barlow Semi Condensed).
static func body(weight := 500, spacing := 0) -> Font:
	return _var(_sys(PackedStringArray(["Avenir Next Condensed", "Avenir Next", "Helvetica Neue"]), weight), "body%d" % weight,
			0.0, spacing)


static func lab(text: String, font: Font, px: int, c := WHITE, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", c)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A wrapped paragraph `w` px wide.
static func para(text: String, font: Font, px: int, c: Color, w: float) -> Label:
	var l := lab(text, font, px, c)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(w, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	return l


## Outlined display type (the giant word behind the fighter): only its outline, `c`, `line` px.
static func outline(text: String, px: int, c: Color, line := 3) -> Label:
	var l := lab(text, head(true, 4), px, Color(c, 0.0))
	l.add_theme_color_override("font_outline_color", c)
	l.add_theme_constant_override("outline_size", line)
	return l


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


## A plate (Panel) at x, y, w, h under `parent`.
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


## A chip of text: `text` in the headline face on plate `c`.
static func tag(text: String, px: int, fg: Color, bg: Color, spacing := 2, pad := Vector4(12, 2, 12, 0)) -> PanelContainer:
	var l := lab(text, head(false, spacing), px, fg, HORIZONTAL_ALIGNMENT_CENTER)
	return chip(l, bg, LEAN, pad)


## A key cap ("ENTER", "ESC", "E", "LMB"): its name in a bordered box, then what it does.
static func key_hint(key: String, what: String, px := 18) -> HBoxContainer:
	var h := hbox(8)
	var k := lab(key, head(false, 1), px - 2, WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	var kc := chip(k, Color(NAVY3, 0.9), 0.0, Vector4(8, 3, 8, 0), 1, Color(DIM, 0.55))
	(kc.get_theme_stylebox("panel") as StyleBoxFlat).set_corner_radius_all(3)
	h.add_child(kc)
	h.add_child(lab(what.to_upper(), head(false, 2), px, DIM))
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


## A gradient overlay over the whole of `parent`: `stops` [[offset, Color]...] from `from` to `to` (0..1 of the rect).
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
	t.width = 512
	t.height = 512
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


## A group anchored to `anchor` of `parent` (0..1 each way) with its top-left at `pos` from that anchor point, `sz` big:
## the screens' parts keep to their corner or edge as the window's shape changes.
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


## An element's colour (elements.json), "any" the gold of Any.
static func ec(el: String) -> Color:
	return MatchSetup.color(el)


## The element's colour made a little deeper for big fills (the light Air reads as a plate, not a glare).
static func plate_c(el: String) -> Color:
	var c := ec(el)
	if el == "air":
		return Color("bfe3f5")
	return c


## An image file (a render) as a texture; `blur` > 1 softens it by that factor, `dark` multiplies it.
static func tex(path: String, blur := 1, dark := 1.0, fit := Vector2i.ZERO) -> ImageTexture:
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	if fit != Vector2i.ZERO and img.get_size() != fit:
		img.resize(fit.x, fit.y, Image.INTERPOLATE_LANCZOS)
	if blur > 1:
		var w := img.get_width()
		var h := img.get_height()
		img.resize(maxi(w / blur, 8), maxi(h / blur, 8), Image.INTERPOLATE_LANCZOS)
		img.resize(maxi(w / (blur * 2), 4), maxi(h / (blur * 2), 4), Image.INTERPOLATE_BILINEAR)
		img.resize(w, h, Image.INTERPOLATE_CUBIC)
	if dark != 1.0:
		img.adjust_bcs(dark, 1.0, 1.0)
	return ImageTexture.create_from_image(img)


## A region of a texture (a head-and-shoulders crop of a cut-out).
static func crop(t: Texture2D, r: Rect2) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = t
	a.region = r
	return a


static func glyph(kind: String, c: Color, px: float, under := NAVY1) -> Control:
	var g := Glyph.make(kind, c, px, under)
	if kind == "any":
		g.set("palette", {"earth": ec("earth"), "water": ec("water"), "fire": ec("fire"), "air": ec("air")})
	return g


static func stripes(parent: Control, r: Rect2, c: Color, g := 14.0, w := 3.0, fade := 0.0) -> Control:
	var s := Stripes.make(c, g, w)
	s.set("fade", fade)
	put(parent, s, r)
	return s


## A section's label: "PLAY" in the accent, spaced, with a hairline after it to `w`.
static func section(parent: Control, at: Vector2, text: String, w: float, c := TEAL) -> void:
	var l := lab(text, head(false, 5), 19, c)
	put(parent, l, Rect2(at, Vector2(200, 24)))
	var tw := l.get_minimum_size().x
	rect(parent, Rect2(at + Vector2(tw + 14, 11), Vector2(w - tw - 14, 1)), Color(LINE, 0.9))
