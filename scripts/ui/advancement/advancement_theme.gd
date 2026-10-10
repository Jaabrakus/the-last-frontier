class_name AdvancementTheme
extends RefCounted
## The Character Advancement window's own look (artifacts/ui_audit/advancement/plan.md): the stone-and-gold frame of the
## owner's reference clip, set in the project's menu type (Barlow Condensed for the title, the tree headings and the
## numerals; Barlow Semi Condensed for labels, tooltips and buttons) with the element's colour as the accent. The look
## stays inside this one window: the fight HUD takes none of it.
##
## Everything is authored at 1600x900 and scaled by the window, so the sizes below are authored pixels: the smallest
## text, S_SMALL = 18, reads at 14.4 px at 1280x720.
##
##   font(kind) / spaced(kind, px)     the four faces: "head" (Condensed ExtraBold), "head2" (Condensed Bold), "body"
##                                      (Semi Condensed Medium), "body2" (Semi Condensed SemiBold)
##   label(...) / style_label(...)     a Label in one of them, with the shadow the painting needs
##   box(...)                          a nine-patch plate drawn once from a signed-distance shape (rounded, bordered,
##                                      a gradient fill, an inner trim line): buttons, tabs, the frame, the cards
##   button(text, kind) / style_button  the red-brown plates, the stone tabs and the quiet ghost buttons
##   tex(path) / node_icon(id) / ...    the pictures (assets/ui/advancement/art.json)

const FONT_DIR := "res://assets/fonts/barlow/"
const ART_PATH := "res://assets/ui/advancement/art.json"
const FILES := {
	"head": "BarlowCondensed-ExtraBold.ttf", "head2": "BarlowCondensed-Bold.ttf",
	"body": "BarlowSemiCondensed-Medium.ttf", "body2": "BarlowSemiCondensed-SemiBold.ttf",
}

## Sizes in authored pixels (see the header).
const S_SMALL := 18
const S_BODY := 20
const S_LABEL := 22
const S_BUTTON := 22
const S_TIP_TITLE := 28
const S_TITLE := 42
const S_POINTS := 34

const INK := Color(0.98, 0.95, 0.86)
const INK_DIM := Color(0.62, 0.65, 0.71, 0.82)
const SHADOW := Color(0, 0, 0, 0.85)

static var _fonts := {}
static var _art := {}
static var _tex := {}
static var _boxes := {}
static var _plates := {}


# --- type ---------------------------------------------------------------------------------------------------------------

static func font(kind: String) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var f := load(FONT_DIR + String(FILES.get(kind, FILES.body))) as FontFile
	if f != null:
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.hinting = TextServer.HINTING_LIGHT
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	var out: Font = f if f != null else ThemeDB.fallback_font
	_fonts[kind] = out
	return out


## A face with letters set apart (titles in capitals).
static func spaced(kind: String, spacing: int) -> Font:
	var k := "%s|%d" % [kind, spacing]
	if not _fonts.has(k):
		var v := FontVariation.new()
		v.base_font = font(kind)
		v.spacing_glyph = spacing
		_fonts[k] = v
	return _fonts[k]


static func c(name: String) -> Color:
	return AdvancementData.color(name)


## A Label set in `kind`'s face; `shadow` for text over the painting.
static func label(text: String, px: int, col: Color = INK, kind := "body", shadow := false) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_label(l, px, col, kind, shadow)
	return l


static func style_label(l: Label, px: int, col: Color = INK, kind := "body", shadow := false) -> void:
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	if shadow:
		l.add_theme_color_override("font_shadow_color", SHADOW)
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 2)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		l.add_theme_constant_override("outline_size", 4)


# --- plates -------------------------------------------------------------------------------------------------------------

## A nine-patch plate drawn once from a rounded-rectangle distance field: a gradient fill from `top` to `bottom`, a border
## `bw` thick in `border`, and (when `trim` has alpha) a thin second line `gap` inside it. Content margins are the
## caller's. Cached by its look.
static func box(top: Color, bottom: Color, border: Color, bw := 2.0, radius := 5.0, trim := Color(0, 0, 0, 0), gap := 3.0) -> StyleBoxTexture:
	var key := "%s|%s|%s|%s|%s|%s|%s" % [top, bottom, border, bw, radius, trim, gap]
	if not _boxes.has(key):
		var sz := 48
		var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
		var half := Vector2(sz, sz) * 0.5
		for y in sz:
			for x in sz:
				var p := (Vector2(x + 0.5, y + 0.5) - half).abs()
				var q := p - (half - Vector2(radius, radius))
				var sd := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - radius
				var d := -sd
				var cov := clampf(d + 0.5, 0.0, 1.0)
				if cov <= 0.0:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
					continue
				var col := top.lerp(bottom, float(y) / float(sz - 1))
				col = col.lerp(border, clampf(bw + 0.5 - d, 0.0, 1.0))
				if trim.a > 0.0:
					var t := clampf(1.0 - absf(d - (bw + gap + 0.5)), 0.0, 1.0) * trim.a
					col = col.lerp(Color(trim.r, trim.g, trim.b, 1.0), t)
				col.a = cov
				img.set_pixel(x, y, col)
		_boxes[key] = ImageTexture.create_from_image(img)
	var sb := StyleBoxTexture.new()
	sb.texture = _boxes[key]
	var m := ceilf(radius + bw + (gap + 2.0 if trim.a > 0.0 else 0.0)) + 2.0
	sb.texture_margin_left = m
	sb.texture_margin_right = m
	sb.texture_margin_top = m
	sb.texture_margin_bottom = m
	return sb


static func with_margins(sb: StyleBox, l: float, t: float, r: float, b: float) -> StyleBox:
	sb.content_margin_left = l
	sb.content_margin_top = t
	sb.content_margin_right = r
	sb.content_margin_bottom = b
	return sb


## The dark stone of the frame, bars and cards: a gold border and a fine trim inside it.
static func stone(top := Color(0.105, 0.12, 0.15), bottom := Color(0.075, 0.085, 0.11), border: Color = Color.TRANSPARENT, trim := true) -> StyleBoxTexture:
	var b: Color = border if border.a > 0.0 else c("frame_gold")
	return box(top, bottom, b, 2.0, 5.0, Color(c("frame_trim"), 0.45) if trim else Color(0, 0, 0, 0), 3.0)


## The window's frame: dark stone, a gold border and a lighter trim line inside.
static func frame_box() -> StyleBoxTexture:
	return box(Color(0.09, 0.105, 0.13), Color(0.06, 0.07, 0.09), c("frame_gold"), 3.0, 7.0, Color(c("frame_trim"), 0.7), 4.0)


static func plate_styles(kind: String) -> Dictionary:
	if _plates.has(kind):
		return _plates[kind]
	var gold := c("frame_gold")
	var gold_l := c("frame_trim")
	var out := {}
	match kind:
		"tab":
			out = {
				"normal": box(Color(0.12, 0.14, 0.18), Color(0.07, 0.08, 0.11), Color(gold, 0.55), 2.0, 5.0),
				"hover": box(Color(0.17, 0.19, 0.23), Color(0.1, 0.11, 0.14), gold, 2.0, 5.0),
				"pressed": box(Color(0.2, 0.17, 0.1), Color(0.12, 0.1, 0.06), gold_l, 2.0, 5.0, Color(gold_l, 0.5), 3.0),
				"disabled": box(Color(0.18, 0.15, 0.09), Color(0.1, 0.085, 0.05), gold_l, 2.0, 5.0, Color(gold_l, 0.5), 3.0),
			}
		"ghost":
			out = {
				"normal": box(Color(0.1, 0.115, 0.145), Color(0.07, 0.08, 0.1), Color(gold, 0.6), 2.0, 5.0),
				"hover": box(Color(0.16, 0.18, 0.22), Color(0.1, 0.11, 0.14), gold_l, 2.0, 5.0),
				"pressed": box(Color(0.06, 0.07, 0.09), Color(0.1, 0.11, 0.14), gold_l, 2.0, 5.0),
				"disabled": box(Color(0.08, 0.09, 0.11), Color(0.06, 0.065, 0.08), Color(0.3, 0.3, 0.32), 2.0, 5.0),
			}
		_:
			var rl := c("button")
			var rd := c("button_dark")
			out = {
				"normal": box(rl.lightened(0.1), rd, gold, 2.0, 5.0, Color(1.0, 0.82, 0.55, 0.22), 2.0),
				"hover": box(rl.lightened(0.28), rd.lightened(0.15), gold_l, 2.0, 5.0, Color(1.0, 0.86, 0.6, 0.32), 2.0),
				"pressed": box(rd, rl.darkened(0.1), gold_l, 2.0, 5.0),
				"disabled": box(Color(0.2, 0.15, 0.14), Color(0.12, 0.09, 0.09), Color(0.36, 0.33, 0.28), 2.0, 5.0),
			}
	_plates[kind] = out
	return out


static func focus_ring() -> StyleBoxFlat:
	var f := StyleBoxFlat.new()
	f.draw_center = false
	f.set_border_width_all(2)
	f.border_color = c("title")
	f.set_corner_radius_all(6)
	f.expand_margin_left = 2
	f.expand_margin_right = 2
	f.expand_margin_top = 2
	f.expand_margin_bottom = 2
	return f


## Dress a Button as one of the plates: "plate" (red-brown), "tab" (stone), "ghost" (quiet stone).
static func style_button(b: Button, kind := "plate", px := S_BUTTON) -> void:
	var st := plate_styles(kind)
	b.add_theme_stylebox_override("normal", with_margins((st.normal as StyleBox).duplicate(), 14, 4, 14, 4))
	b.add_theme_stylebox_override("hover", with_margins((st.hover as StyleBox).duplicate(), 14, 4, 14, 4))
	b.add_theme_stylebox_override("pressed", with_margins((st.pressed as StyleBox).duplicate(), 14, 4, 14, 4))
	b.add_theme_stylebox_override("disabled", with_margins((st.disabled as StyleBox).duplicate(), 14, 4, 14, 4))
	b.add_theme_stylebox_override("hover_pressed", with_margins((st.pressed as StyleBox).duplicate(), 14, 4, 14, 4))
	b.add_theme_stylebox_override("focus", focus_ring())
	b.add_theme_font_override("font", font("body2"))
	b.add_theme_font_size_override("font_size", px)
	var ink := INK if kind != "ghost" else c("text")
	b.add_theme_color_override("font_color", ink)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", c("worn"))
	b.add_theme_color_override("font_hover_pressed_color", c("worn"))
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", INK_DIM if kind != "tab" else c("worn"))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	b.add_theme_constant_override("outline_size", 3 if kind == "plate" else 0)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


static func button(text: String, kind := "plate", px := S_BUTTON) -> Button:
	var b := Button.new()
	b.text = text
	style_button(b, kind, px)
	return b


## A flat stone field for a LineEdit (the search box, a name).
static func style_line_edit(e: LineEdit, px := S_BODY) -> void:
	var gold := c("frame_gold")
	var n := with_margins(box(Color(0.05, 0.055, 0.07), Color(0.075, 0.085, 0.105), Color(gold, 0.7), 2.0, 5.0), 40, 3, 12, 3)
	var f := with_margins(box(Color(0.06, 0.065, 0.085), Color(0.09, 0.1, 0.125), c("frame_trim"), 2.0, 5.0), 40, 3, 12, 3)
	e.add_theme_stylebox_override("normal", n)
	e.add_theme_stylebox_override("focus", f)
	e.add_theme_stylebox_override("read_only", n)
	e.add_theme_font_override("font", font("body"))
	e.add_theme_font_size_override("font_size", px)
	e.add_theme_color_override("font_color", INK)
	e.add_theme_color_override("font_placeholder_color", Color(INK_DIM, 0.8))
	e.add_theme_color_override("caret_color", c("worn"))
	e.add_theme_color_override("selection_color", Color(c("worn"), 0.35))


# --- pictures -----------------------------------------------------------------------------------------------------------

static func art() -> Dictionary:
	if _art.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ART_PATH)) if FileAccess.file_exists(ART_PATH) else null
		_art = d if d is Dictionary else {"_empty": true}
	return _art


static func tex(path: String) -> Texture2D:
	if path == "":
		return null
	if not _tex.has(path):
		_tex[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _tex[path]


static func _art_path(group: String, key: String) -> String:
	var g: Variant = art().get(group, {})
	return String((g as Dictionary).get(key, "")) if g is Dictionary else ""


static func backdrop(el: String) -> Texture2D:
	return tex(_art_path("backdrops", el))


static func frame_tex(name: String) -> Texture2D:
	return tex(_art_path("frame", name))


## A node's picture: the one art.json holds for it (its own spell picture, else the passive's or the set's, else its move's).
static func node_icon(id: String) -> Texture2D:
	return tex(_art_path("node_icons", id))


static func passive_root_icon(el: String) -> Texture2D:
	return tex(_art_path("passive_roots", el))


static func kind_mark(kind: String) -> Texture2D:
	return tex(_art_path("kinds", kind))


static func set_mark(set_id: String) -> Texture2D:
	var s: Variant = (art().get("sets", {}) as Dictionary).get(set_id, {})
	return tex(String((s as Dictionary).get("mark", ""))) if s is Dictionary else null


static func set_tint(set_id: String) -> Color:
	var s: Variant = (art().get("sets", {}) as Dictionary).get(set_id, {})
	if s is Dictionary and Color.html_is_valid(String((s as Dictionary).get("tint", ""))):
		return Color.html(String((s as Dictionary).get("tint")))
	return c("set_" + set_id)


static func style_glyph(style_id: String) -> Texture2D:
	var s: Variant = (art().get("styles", {}) as Dictionary).get(style_id, {})
	return tex(String((s as Dictionary).get("glyph", ""))) if s is Dictionary else null


## The class emblem (element + style): a medallion ring, the style's glyph, the element's mark.
static func emblem(el: String, style_id: String) -> Texture2D:
	var e: Variant = (art().get("emblems", {}) as Dictionary).get(el, {})
	return tex(String((e as Dictionary).get(style_id, ""))) if e is Dictionary else null


## A radial plate: `inner` at the middle fading to `edge`, for a node's face (drawn through a polygon, so any shape).
static func plate_tex(inner: Color, edge: Color) -> Texture2D:
	var key := "plate|%s|%s" % [inner, edge]
	if not _tex.has(key):
		var g := Gradient.new()
		g.set_color(0, inner)
		g.set_color(1, edge)
		g.add_point(0.55, inner.lerp(edge, 0.45))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.44)
		t.fill_to = Vector2(1.0, 0.44)
		t.width = 64
		t.height = 64
		_tex[key] = t
	return _tex[key]


## A soft round glow: white at the middle fading to nothing at the edge (tint it with the draw colour).
static func glow_tex() -> Texture2D:
	var key := "glow"
	if not _tex.has(key):
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0.75), Color(1, 1, 1, 0.28), Color(1, 1, 1, 0.0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_tex[key] = t
	return _tex[key]


## A soft dark oval, strongest at the middle and gone at the edge: the shade under a gate's number so it reads on the painting.
static func stub_tex() -> Texture2D:
	var key := "stub"
	if not _tex.has(key):
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		g.colors = PackedColorArray([Color(0.02, 0.025, 0.04, 0.6), Color(0.02, 0.025, 0.04, 0.42), Color(0.02, 0.025, 0.04, 0.0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 64
		_tex[key] = t
	return _tex[key]


## A horizontal fade for the painting's shade: dark at the ends, clear in the middle gap.
static func shade_tex(edge_a: float, mid_a: float) -> Texture2D:
	var key := "shade|%s|%s" % [edge_a, mid_a]
	if not _tex.has(key):
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.2, 0.34, 0.42, 0.5, 0.58, 0.66, 0.8, 1.0])
		g.colors = PackedColorArray([
			Color(0.02, 0.025, 0.04, edge_a), Color(0.02, 0.025, 0.04, edge_a * 0.96), Color(0.02, 0.025, 0.04, edge_a * 0.82),
			Color(0.02, 0.025, 0.04, mid_a + (edge_a - mid_a) * 0.25), Color(0.02, 0.025, 0.04, mid_a),
			Color(0.02, 0.025, 0.04, mid_a + (edge_a - mid_a) * 0.25), Color(0.02, 0.025, 0.04, edge_a * 0.82),
			Color(0.02, 0.025, 0.04, edge_a * 0.96), Color(0.02, 0.025, 0.04, edge_a)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill_from = Vector2(0, 0)
		t.fill_to = Vector2(1, 0)
		t.width = 256
		t.height = 4
		_tex[key] = t
	return _tex[key]


## A thin line that fades out at both ends (the accent under a tree's title).
static func accent_tex(col: Color) -> Texture2D:
	var key := "accent|%s" % col
	if not _tex.has(key):
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
		g.colors = PackedColorArray([Color(col, 0.0), Color(col, 0.95), Color(col, 0.95), Color(col, 0.0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill_from = Vector2(0, 0)
		t.fill_to = Vector2(1, 0)
		t.width = 128
		t.height = 4
		_tex[key] = t
	return _tex[key]


## A vertical fade (a bar's top or bottom edge over the painting).
static func fade_tex(top_a: float, bottom_a: float) -> Texture2D:
	var key := "fade|%s|%s" % [top_a, bottom_a]
	if not _tex.has(key):
		var g := Gradient.new()
		g.set_color(0, Color(0.02, 0.025, 0.04, top_a))
		g.set_color(1, Color(0.02, 0.025, 0.04, bottom_a))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill_from = Vector2(0, 0)
		t.fill_to = Vector2(0, 1)
		t.width = 4
		t.height = 128
		_tex[key] = t
	return _tex[key]


# --- small shared drawing -------------------------------------------------------------------------------------------------

## A rounded rectangle as a polygon (corner radius `r`, `seg` points per corner).
static func rounded_poly(rect: Rect2, r: float, seg := 5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [
		[Vector2(rect.end.x - r, rect.position.y + r), -PI * 0.5],
		[Vector2(rect.end.x - r, rect.end.y - r), 0.0],
		[Vector2(rect.position.x + r, rect.end.y - r), PI * 0.5],
		[Vector2(rect.position.x + r, rect.position.y + r), PI],
	]
	for cn: Array in corners:
		for i in seg + 1:
			var a: float = float(cn[1]) + (PI * 0.5) * float(i) / float(seg)
			pts.append((cn[0] as Vector2) + Vector2(cos(a), sin(a)) * r)
	return pts


static func ellipse_poly(centre: Vector2, r: Vector2, n := 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(centre + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts


static func circle_poly(centre: Vector2, r: float, n := 40) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n) - PI * 0.5
		pts.append(centre + Vector2(cos(a), sin(a)) * r)
	return pts


## A flat-sided octagon filling `rect` (the choice node).
static func octagon_poly(rect: Rect2) -> PackedVector2Array:
	var k := minf(rect.size.x, rect.size.y) * 0.29
	var p := rect.position
	var e := rect.end
	return PackedVector2Array([
		Vector2(p.x + k, p.y), Vector2(e.x - k, p.y), Vector2(e.x, p.y + k), Vector2(e.x, e.y - k),
		Vector2(e.x - k, e.y), Vector2(p.x + k, e.y), Vector2(p.x, e.y - k), Vector2(p.x, p.y + k)])


## Draw a closed outline as dashes (a held node's border).
static func dashed_outline(ci: CanvasItem, pts: PackedVector2Array, col: Color, width: float, dash := 6.0, gap := 4.0) -> void:
	var n := pts.size()
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var len := a.distance_to(b)
		if len < 0.01:
			continue
		var dir := (b - a) / len
		var t := 0.0
		while t < len:
			var e := minf(t + dash, len)
			ci.draw_line(a + dir * t, a + dir * e, col, width, true)
			t += dash + gap


## A button whose face is a drawn glyph (the Loadouts panel icon, the code icon, undo, the close X, the padlock).
class GlyphButton extends Button:
	var glyph := ""
	var tint := Color(0.84, 0.7, 0.42)
	var tint_hover := Color(1.0, 0.93, 0.7)

	func _init(g := "") -> void:
		glyph = g
		flat = false
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		var empty := StyleBoxEmpty.new()
		for s in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(s, empty)
		add_theme_stylebox_override("focus", AdvancementTheme.focus_ring())

	func _draw() -> void:
		var col := tint
		if disabled:
			col = Color(tint, 0.3)
		elif is_hovered() or has_focus():
			col = tint_hover
		var s := size
		var ctr := s * 0.5
		var w := 2.4
		match glyph:
			"panel":
				var r := Rect2(ctr - Vector2(10, 9), Vector2(20, 18))
				draw_rect(r, col, false, w)
				draw_line(r.position + Vector2(7, 0), r.position + Vector2(7, 18), col, w)
				draw_line(ctr + Vector2(-2, 0), ctr + Vector2(5, 0), col, w)
			"code":
				draw_rect(Rect2(ctr + Vector2(-10, -6), Vector2(13, 16)), col, false, w)
				draw_rect(Rect2(ctr + Vector2(-3, -11), Vector2(13, 16)), col, false, w)
			"undo":
				draw_arc(ctr, 9.5, deg_to_rad(-60), deg_to_rad(230), 20, col, w, true)
				var tip := ctr + Vector2(cos(deg_to_rad(-60)), sin(deg_to_rad(-60))) * 9.5
				draw_colored_polygon(PackedVector2Array([tip + Vector2(-5, -4), tip + Vector2(6, -3), tip + Vector2(1, 7)]), col)
			"close":
				draw_line(ctr + Vector2(-7, -7), ctr + Vector2(7, 7), col, 3.0, true)
				draw_line(ctr + Vector2(-7, 7), ctr + Vector2(7, -7), col, 3.0, true)
			"lock":
				var tx := AdvancementTheme.tex("res://assets/ui/advancement/padlock.svg")
				if tx != null:
					draw_texture_rect(tx, Rect2(ctr - Vector2(11, 11), Vector2(22, 22)), false, col)
			"search":
				draw_arc(ctr + Vector2(-2, -2), 7.0, 0, TAU, 20, col, w, true)
				draw_line(ctr + Vector2(3, 3), ctr + Vector2(10, 10), col, 3.0, true)
