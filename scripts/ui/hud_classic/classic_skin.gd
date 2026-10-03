class_name ClassicSkin
extends RefCounted
## The classic HUD's look (the owner, 2026-10-03: "can the hud be similar to world of warcraft vanilla?"): the classic MMO
## frames in the game's own art and nothing taken from any other game. Dark tooled leather with a brass edge and a rivet at
## each corner, sockets sunk into it, bars with a lit top and a shaded foot, brass rings round the round things, the HUD's
## serif lettering (FrontierHUD.serif) and its ink and gold. Everything is drawn here with the canvas calls; the only
## texture is the leather's grain, made once from noise.
##   style()    "classic" or "minimal" (the old HUD of bare lettering over the world): the argument hud=classic|minimal,
##              else in tool and test runs (-s) "minimal" (the minimal HUD's own tests run as they did), else
##              user://settings.cfg [hud] style, default "classic". set_style() writes it, as the Settings row does
##              (GameSettings.hud_style_row, which switches a game's HUD at once: FrontierHUD.apply_style).
##   panel(ci, rect)     the leather plate: its drop shadow, the leather, the grain, the brass rule, the rivets
##   socket(ci, rect)    a square sunk into the leather (a button's or an icon's bed)
##   bar(ci, rect, frac, colour, ...)   a bar in its track, its text centred on it
##   ring(ci, centre, radius, width)    the brass ring round a portrait or the map
##   text(ci, at, s, size, colour)      lettering with a dark rim (it reads over anything)

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "hud"
const KEY := "style"
const CLASSIC := "classic"
const MINIMAL := "minimal"
const STYLES := [CLASSIC, MINIMAL]

const INK := FrontierHUD.INK
const TEXT := FrontierHUD.TEXT
const DIM := FrontierHUD.DIM
const GOLD := FrontierHUD.GOLD
const LEATHER := Color(0.165, 0.112, 0.074, 0.93)
const LEATHER_LO := Color(0.09, 0.062, 0.042, 0.95)
const SOCKET := Color(0.03, 0.024, 0.02, 0.9)
const BRASS := Color(0.7, 0.54, 0.3)
const BRASS_HI := Color(0.96, 0.83, 0.55)
const BRASS_LO := Color(0.27, 0.19, 0.09)
const HEALTH := Color(0.66, 0.15, 0.11)
const HEALTH_LOST := Color(0.34, 0.05, 0.04)
const MOTES := Color(0.9, 0.7, 0.3)
const HOSTILE := Color(0.8, 0.2, 0.14)
const NEUTRAL := Color(0.88, 0.72, 0.24)
const FRIENDLY := Color(0.36, 0.7, 0.3)
const BUFF := Color(0.42, 0.72, 0.36)
const WARN := FrontierHUD.BADGE_WARN
const BAD := FrontierHUD.BADGE_BAD

static var _grain: ImageTexture
static var _plate: StyleBoxFlat
static var _tooltip: StyleBoxFlat
static var _theme: Theme


## The HUD style for this run (see the header).
static func style() -> String:
	return resolve_style(OS.get_cmdline_user_args(), OS.get_cmdline_args(), SETTINGS_PATH)


static func is_classic() -> bool:
	return style() == CLASSIC


## style() from these arguments and settings file (the test calls it with its own).
static func resolve_style(user_args: PackedStringArray, args: PackedStringArray, path: String) -> String:
	for a in user_args:
		if a.begins_with("hud="):
			var s := a.substr(4)
			if s in STYLES:
				return s
	if "-s" in args or "--script" in args:
		return MINIMAL
	var cf := ConfigFile.new()
	if cf.load(path) == OK:
		var s := String(cf.get_value(SECTION, KEY, CLASSIC))
		if s in STYLES:
			return s
	return CLASSIC


## Keeps the style for the next level (the HUD is built with the level).
static func set_style(s: String, path := SETTINGS_PATH) -> void:
	if not s in STYLES:
		return
	var cf := ConfigFile.new()
	cf.load(path)
	cf.set_value(SECTION, KEY, s)
	cf.save(path)


static func font() -> Font:
	return FrontierHUD.serif()


## The frames' theme: the serif, and the tooltips on a leather plate in ink.
static func theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		_theme.default_font = font()
		_theme.default_font_size = 16
		if _tooltip == null:
			_tooltip = StyleBoxFlat.new()
			_tooltip.bg_color = Color(0.1, 0.07, 0.048, 0.96)
			_tooltip.border_color = BRASS
			_tooltip.set_border_width_all(1)
			_tooltip.set_corner_radius_all(3)
			_tooltip.set_content_margin_all(8)
			_tooltip.shadow_color = Color(0, 0, 0, 0.45)
			_tooltip.shadow_size = 4
		_theme.set_stylebox(&"panel", &"TooltipPanel", _tooltip)
		_theme.set_color(&"font_color", &"TooltipLabel", INK)
		_theme.set_font_size(&"font_size", &"TooltipLabel", 15)
		_theme.set_font(&"font", &"TooltipLabel", font())
	return _theme


## The leather's grain: dark creases and a few lighter scuffs, seamless, 64 px (made once).
static func grain() -> Texture2D:
	if _grain == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
		n.frequency = 0.09
		n.seed = 7
		n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
		var a := n.get_seamless_image(64, 64)
		var m := FastNoiseLite.new()
		m.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		m.frequency = 0.2
		m.seed = 3
		var b := m.get_seamless_image(64, 64)
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var crease := 1.0 - a.get_pixel(x, y).r
				var mottle := b.get_pixel(x, y).r
				var dark := clampf(pow(crease, 3.0) * 0.55 + (1.0 - mottle) * 0.18, 0.0, 0.6)
				if mottle > 0.82:
					img.set_pixel(x, y, Color(1.0, 0.9, 0.75, (mottle - 0.82) * 0.5))
				else:
					img.set_pixel(x, y, Color(0.0, 0.0, 0.0, dark))
		_grain = ImageTexture.create_from_image(img)
	return _grain


static func _plate_box() -> StyleBoxFlat:
	if _plate == null:
		_plate = StyleBoxFlat.new()
		_plate.bg_color = LEATHER
		_plate.border_color = BRASS_LO
		_plate.set_border_width_all(1)
		_plate.set_corner_radius_all(5)
		_plate.shadow_color = Color(0, 0, 0, 0.38)
		_plate.shadow_size = 5
		_plate.shadow_offset = Vector2(0, 2)
		_plate.anti_aliasing = true
	return _plate


## The leather plate in `r`: its shadow, the leather and its grain, a darker foot, the brass rule inside the edge and a
## rivet at each corner (`rivets` false: none).
static func panel(ci: CanvasItem, r: Rect2, rivets := true, alpha := 1.0) -> void:
	ci.draw_style_box(_plate_box(), r)
	var inner := r.grow(-2.0)
	ci.draw_texture_rect(grain(), inner, true, Color(1, 1, 1, 0.9 * alpha))
	ci.draw_rect(Rect2(inner.position + Vector2(0, inner.size.y * 0.6), Vector2(inner.size.x, inner.size.y * 0.4)),
			Color(0, 0, 0, 0.16 * alpha))
	ci.draw_rect(Rect2(inner.position, Vector2(inner.size.x, 1.0)), Color(1, 0.9, 0.7, 0.07 * alpha))
	edge(ci, r.grow(-2.5), alpha)
	if rivets and r.size.x > 24.0 and r.size.y > 24.0:
		for c: Vector2 in [r.position + Vector2(6, 6), Vector2(r.end.x - 6, r.position.y + 6),
				Vector2(r.position.x + 6, r.end.y - 6), r.end - Vector2(6, 6)]:
			rivet(ci, c, 2.2, alpha)


## The brass rule round `r`: a dark under-line, the brass, a lit top-left line.
static func edge(ci: CanvasItem, r: Rect2, alpha := 1.0, width := 1.4) -> void:
	ci.draw_rect(r.grow(0.6), Color(BRASS_LO.r, BRASS_LO.g, BRASS_LO.b, 0.9 * alpha), false, width + 1.4)
	ci.draw_rect(r, Color(BRASS.r, BRASS.g, BRASS.b, alpha), false, width)
	ci.draw_line(r.position + Vector2(1, 0.5), Vector2(r.end.x - 1, r.position.y + 0.5), Color(BRASS_HI.r, BRASS_HI.g, BRASS_HI.b, 0.55 * alpha), 1.0)
	ci.draw_line(r.position + Vector2(0.5, 1), Vector2(r.position.x + 0.5, r.end.y - 1), Color(BRASS_HI.r, BRASS_HI.g, BRASS_HI.b, 0.35 * alpha), 1.0)


static func rivet(ci: CanvasItem, c: Vector2, rad: float, alpha := 1.0) -> void:
	ci.draw_circle(c + Vector2(0.6, 0.8), rad + 0.6, Color(0, 0, 0, 0.5 * alpha))
	ci.draw_circle(c, rad, Color(BRASS.r, BRASS.g, BRASS.b, alpha))
	ci.draw_circle(c - Vector2(rad, rad) * 0.3, rad * 0.4, Color(BRASS_HI.r, BRASS_HI.g, BRASS_HI.b, 0.8 * alpha))


## A square sunk into the leather: the dark bed, its inner shadow along the top and left, a faint lit lip at the foot.
static func socket(ci: CanvasItem, r: Rect2, alpha := 1.0) -> void:
	ci.draw_rect(r, Color(SOCKET.r, SOCKET.g, SOCKET.b, SOCKET.a * alpha))
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 3.0)), Color(0, 0, 0, 0.35 * alpha))
	ci.draw_rect(Rect2(r.position, Vector2(3.0, r.size.y)), Color(0, 0, 0, 0.25 * alpha))
	ci.draw_line(Vector2(r.position.x, r.end.y - 0.5), Vector2(r.end.x, r.end.y - 0.5), Color(1, 0.85, 0.6, 0.12 * alpha), 1.0)
	ci.draw_rect(r, Color(BRASS_LO.r, BRASS_LO.g, BRASS_LO.b, 0.95 * alpha), false, 1.0)


## A bar in its track: `ghost` (0..1, -1 none) drawn behind the fill in `ghost_col` (the blood still to lose), `cap` (0..1
## from the end, 0 none) shaded grey at the end (what a lasting harm holds it under); `text` centred on it.
static func bar(ci: CanvasItem, r: Rect2, frac: float, col: Color, text_s := "", ghost := -1.0, ghost_col := HEALTH_LOST,
		cap := 0.0, font_size := 13) -> void:
	ci.draw_rect(r.grow(1.0), Color(0, 0, 0, 0.55))
	ci.draw_rect(r, Color(0.05, 0.035, 0.025, 0.92))
	if ghost > frac:
		ci.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(ghost, 0.0, 1.0), r.size.y)), ghost_col)
	var w := r.size.x * clampf(frac, 0.0, 1.0)
	if w > 0.5:
		var f := Rect2(r.position, Vector2(w, r.size.y))
		ci.draw_rect(f, col)
		ci.draw_rect(Rect2(f.position, Vector2(w, r.size.y * 0.42)), Color(1, 1, 1, 0.16))
		ci.draw_rect(Rect2(f.position + Vector2(0, r.size.y * 0.72), Vector2(w, r.size.y * 0.28)), Color(0, 0, 0, 0.2))
		ci.draw_line(Vector2(f.end.x - 0.5, f.position.y), Vector2(f.end.x - 0.5, f.end.y), Color(1, 1, 1, 0.25), 1.0)
	if cap > 0.005:
		var cw := r.size.x * clampf(cap, 0.0, 1.0)
		ci.draw_rect(Rect2(Vector2(r.end.x - cw, r.position.y), Vector2(cw, r.size.y)), Color(0.55, 0.53, 0.5, 0.5))
	ci.draw_rect(r.grow(1.0), Color(BRASS_LO.r, BRASS_LO.g, BRASS_LO.b, 1.0), false, 1.0)
	if text_s != "":
		text_centred(ci, r, text_s, font_size, INK)


## The brass ring round a round thing at `c`.
static func ring(ci: CanvasItem, c: Vector2, rad: float, width := 4.0, alpha := 1.0) -> void:
	ci.draw_arc(c + Vector2(0.5, 1.0), rad, 0.0, TAU, 64, Color(0, 0, 0, 0.5 * alpha), width + 3.0, true)
	ci.draw_arc(c, rad, 0.0, TAU, 64, Color(BRASS_LO.r, BRASS_LO.g, BRASS_LO.b, alpha), width + 1.6, true)
	ci.draw_arc(c, rad, 0.0, TAU, 64, Color(BRASS.r, BRASS.g, BRASS.b, alpha), width, true)
	ci.draw_arc(c, rad - width * 0.25, PI * 0.95, PI * 1.85, 32, Color(BRASS_HI.r, BRASS_HI.g, BRASS_HI.b, 0.6 * alpha), width * 0.35, true)
	ci.draw_arc(c, rad - width * 0.5 - 0.5, 0.0, TAU, 64, Color(0, 0, 0, 0.45 * alpha), 1.0, true)


## Lettering at `at` (the baseline's left) with a dark rim.
static func text(ci: CanvasItem, at: Vector2, s: String, size: int, col: Color, max_w := -1.0) -> void:
	var f := font()
	ci.draw_string_outline(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, max_w, size, 3, Color(0, 0, 0, 0.6 * col.a))
	ci.draw_string(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, max_w, size, col)


## Lettering centred in `r` (both ways).
static func text_centred(ci: CanvasItem, r: Rect2, s: String, size: int, col: Color) -> void:
	var f := font()
	var sz := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var at := Vector2(r.position.x + (r.size.x - sz.x) * 0.5, r.position.y + (r.size.y + f.get_ascent(size) - f.get_descent(size)) * 0.5)
	text(ci, at, s, size, col)


## Lettering ending at `at.x` (right-aligned) on the baseline `at.y`.
static func text_right(ci: CanvasItem, at: Vector2, s: String, size: int, col: Color) -> void:
	var w := font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text(ci, Vector2(at.x - w, at.y), s, size, col)


## A circle of `n` points round `c` (a portrait's or the map's disc) and its UVs over the unit square, for
## draw_colored_polygon with a texture.
static func disc(c: Vector2, rad: float, n := 40) -> Array:
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		var d := Vector2(cos(a), sin(a))
		pts.append(c + d * rad)
		uvs.append(Vector2(0.5, 0.5) + d * 0.5)
	return [pts, uvs]


## A texture drawn into the square `r` keeping its aspect, inset `pad` px (an icon in its socket).
static func fit_texture(ci: CanvasItem, tex: Texture2D, r: Rect2, pad := 3.0, mod := Color.WHITE) -> void:
	if tex == null:
		return
	var box := r.grow(-pad)
	var ts := tex.get_size()
	if ts.x <= 0.0 or ts.y <= 0.0:
		return
	var k := minf(box.size.x / ts.x, box.size.y / ts.y)
	var fit := Rect2(box.position + (box.size - ts * k) * 0.5, ts * k)
	ci.draw_texture_rect(tex, Rect2(fit.position + Vector2(1.2, 1.2), fit.size), false, Color(0, 0, 0, 0.45 * mod.a))
	ci.draw_texture_rect(tex, fit, false, mod)


## The colour of who a target is to the player.
static func stance_color(stance: String) -> Color:
	match stance:
		"hostile":
			return HOSTILE
		"friendly":
			return FRIENDLY
	return NEUTRAL
