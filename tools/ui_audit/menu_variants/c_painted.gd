extends SceneTree
## SUPERSEDED 2026-10-10: the owner chose style B (scripts/ui/menu/broadcast_ui.gd); kept as a reference mock-up, not wired into the game.
## Main-menu style lineup, variant C: "Painted river" (Thủy Vân). A MOCKUP for the owner to judge by eye, not the game's
## menu: it builds the main menu, the Tidebreak match panel, the ring's Esc menu and the match-end screen in this style,
## with the game's own rows and words (data/ring/*.json, MatchSetup, KitWords) plus the new Fighter rows, over our own
## ring at night painted with the game's oil-paint shader (shaders/ui/oil_paint.gdshader) and a lacquer grade
## (c_painted/grade.gdshader), and saves screenshots. Windowed (it draws):
##   zsh tools/loop/godot_run.sh --path . --resolution 1600x900 -s tools/ui_audit/menu_variants/c_painted.gd --
##       [render [light=night] [views=a,b]] [only=main,pause] [main=<view>:<light>] [pause=..] [end=..]
##       [cands=<view>:<light>,.. cand_dir=<abs dir>]
## render  loads the ring first (a practice, the dummy standing; the HUD is never in the off-window render) and saves its
##         views to c_painted/raw_<view>_<light>.png; without it the cached views are used
## cands   only paints those views as the menu's backdrop would be, to cand_<view>_<light>.png, to compare them
## Writes artifacts/ui_audit/menu_variants/c_painted/{main,match,pause,end,main_720,pause_720}.png and the painted
## backdrops (backdrop_<screen>.png); ends with "C PAINTED DONE". The pieces it draws with (brush glyphs, seals, paper,
## lacquer, rods, the ink-wash landscape) are painted from code by c_painted/make_ink.py; c_painted/SOURCE.md. Fonts: the
## Mac's own (SystemFont), each checked for all 134 Vietnamese letters at the start. No class_name: nothing to register.

const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const HERE := "res://tools/ui_audit/menu_variants/c_painted/"
const OUT := "res://artifacts/ui_audit/menu_variants/c_painted/"
const OWN_CFG := "user://ui_audit_c_painted.cfg"
const HOWTO := "user://how_to.cfg"
const W := 1600
const H := 900

## The ring's views: [from, at, fov] in the ring's own space (x along the deck, the player's end at -x); "play" is the
## player's own camera.
const VIEWS := {
	"hero_a": [Vector3(30.0, 7.0, -10.0), Vector3(-10.0, 0.0, 9.0), 55.0],
	"hero_b": [Vector3(32.0, 9.0, -16.0), Vector3(-8.0, 0.0, 8.0), 52.0],
	"gate_view_r": [Vector3(30.0, 7.0, -10.0), Vector3(-10.0, 0.0, 2.0), 55.0],
	"stands_view": [Vector3(6.0, 9.0, -24.0), Vector3(-6.0, 0.0, 6.0), 55.0],
	"over_deck": [Vector3(-22.0, 5.5, 0.0), Vector3(20.0, 2.5, 0.0), 55.0],
	"behind": [Vector3(-16.5, 2.6, 3.4), Vector3(8.0, 1.2, -0.8), 58.0],
}
## Which view backs which screen ("<view>:<light>"); main=, pause=, end= override them.
var BACK := {"main": "hero_b:night", "pause": "play:night", "end": "hero_a:night"}

# --- the palette: lacquer, paper, ink, gold (the Thủy Vân look's lacquer red, lacquer black and court gold)
const INK := Color("21180f")
const INK_SOFT := Color("54402f")
const EGGSHELL := Color("f3e8cf")
const EGG_DIM := Color("dccdab")
const VERMILION := Color("b23a2b")
const SEAL_RED := Color("b8302a")
const GOLD := Color("d9b46c")
const SHADOW := Color(0.04, 0.02, 0.015, 0.8)
## Each element's ink on paper: its data colour darkened, the hue kept.
const EL_INK := {"earth": Color(0.56, 0.38, 0.18), "water": Color(0.16, 0.36, 0.64), "fire": Color(0.76, 0.28, 0.11),
		"air": Color(0.26, 0.48, 0.56)}
const ELS := ["earth", "water", "fire", "air"]

const SERIF := ["Baskerville", "Georgia", "Times New Roman"]
const ITALIC := ["Georgia", "Times New Roman"]
const SANS := ["Helvetica Neue", "Arial"]
const CAPS := ["Avenir Next", "Helvetica Neue", "Arial"]
## The 134 precomposed Vietnamese letters (tests/thuyvan/test_vietnamese_glyphs.gd's list).
const VIET := "àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬÈÉẺẼẸÊỀẾỂỄỆÌÍỈĨỊÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢÙÚỦŨỤƯỪỨỬỮỰỲÝỶỸỴĐ"

var out_dir := ""
var light := "night"
var do_render := false
var only: Array = []
var views: Array = []
var cands: Array = []
var cand_dir := ""
var _texs := {}
var _shaders := {}
var _fonts := {}
var _backs := {}
var _seed := 0

# the game's words
var EL: Dictionary
var RW: Dictionary
var SC: Dictionary
var PRM: Dictionary
var HL: Dictionary


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		var k := kv.get_slice("=", 0)
		var v := kv.get_slice("=", 1) if "=" in kv else ""
		match k:
			"render": do_render = true
			"light": light = v
			"only": only = Array(v.split(",", false))
			"views": views = Array(v.split(",", false))
			"cands": cands = Array(v.split(",", false))
			"cand_dir": cand_dir = v
			"main", "pause", "end": BACK[k] = v
	out_dir = ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(out_dir)
	CaptureKit.window()
	CaptureKit.keep([HOWTO])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = OWN_CFG
	MatchSetup.reload_scheme()
	EL = _json("res://data/ring/elements.json")
	RW = _json("res://data/ring/rules.json").get("words", {})
	SC = _json("res://data/ring/screens.json")
	PRM = _json("res://data/ring/practice.json").get("menu", {})
	HL = _json("res://data/ring/highlights.json")
	create_timer(600.0, true, false, true).timeout.connect(func() -> void:
		print("C PAINTED watchdog")
		_end(2))
	_run.call_deferred()


func _end(code := 0) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	CaptureKit.restore([HOWTO])
	print("C PAINTED DONE code=%d" % code)
	quit(code)


func _json(path: String) -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


func _frames(n: int) -> void:
	await CaptureKit.frames(self, n)


## A few frames with the drawing forced (a window the Mac stops drawing still renders its sub-viewports).
func _drawn(n := 4) -> void:
	for i in n:
		await process_frame
		RenderingServer.force_draw(false)


func _want(name: String) -> bool:
	return only.is_empty() or name in only


# ======================================================================================================== the run
func _run() -> void:
	_check_fonts()
	if do_render:
		var ok := await _render_ring()
		if not ok:
			return _end(1)
	if not cands.is_empty():
		for c: String in cands:
			var img := Image.load_from_file(ProjectSettings.globalize_path(HERE + "raw_%s_%s.png" % [c.get_slice(":", 0),
					c.get_slice(":", 1)]))
			if img == null or img.is_empty():
				continue
			var painted := await _paint(img, [7, 3], {"amount": 0.6, "vignette": 0.4})
			painted.save_png((cand_dir if cand_dir != "" else out_dir).path_join("cand_%s.png" % c.replace(":", "_")))
			print("  cand ", c)
		return _end(0)
	await _paint_backs()
	var shots := [["main", Vector2i(W, H), _main_screen], ["match", Vector2i(W, H), _match_screen],
			["pause", Vector2i(W, H), _pause_screen], ["end", Vector2i(W, H), _end_screen],
			["main_720", Vector2i(1280, 720), _main_screen], ["pause_720", Vector2i(1280, 720), _pause_screen]]
	for s: Array in shots:
		if _want(String(s[0])):
			await _shoot(String(s[0]), s[1], s[2])
	_end(0)


func _check_fonts() -> void:
	for key in ["title", "serif", "serif_semi", "serif_it", "sans", "sans_demi"]:
		var f := _font(key)
		var sf: SystemFont = (f as FontVariation).base_font as SystemFont if f is FontVariation else f as SystemFont
		var bare := SystemFont.new()
		bare.font_names = sf.font_names
		bare.font_italic = sf.font_italic
		bare.allow_system_fallback = false
		var miss := ""
		for i in VIET.length():
			if not bare.has_char(VIET.unicode_at(i)):
				miss += VIET[i]
		print("FONT %s: %s %s: Vietnamese letters missing: %s" % [key, bare.get_font_name(), bare.get_font_style_name(),
				"none" if miss == "" else miss])


# ======================================================================================================== the ring
func _render_ring() -> bool:
	InputSetup.ensure()
	MatchSetup.incoming = true
	MatchSetup.element = "earth"
	MatchSetup.light = light
	MatchSetup.set_practice("water", "stand")
	change_scene_to_file("res://scenes/ring.tscn")
	await _frames(4)
	var lvl := current_scene as RingLevel
	if lvl == null:
		print("C PAINTED: no ring")
		return false
	await CaptureKit.wait_loaded(self, lvl)
	var view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(W, H))
	root.disable_3d = true
	if lvl.environment_rig != null:
		lvl.environment_rig.follow_camera = view.camera
	var p := lvl.player
	if p != null:
		p.ignore_mouse_capture = true
		if p.hud != null:
			p.hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _frames(150)
	var ring := lvl.ring
	for v: String in VIEWS:
		if not views.is_empty() and not (v in views):
			continue
		var spec: Array = VIEWS[v]
		var from: Vector3 = ring.to_global(spec[0]) if ring != null else spec[0]
		var at: Vector3 = ring.to_global(spec[1]) if ring != null else spec[1]
		view.camera.fov = float(spec[2])
		view.camera.global_transform = Transform3D(Basis.looking_at(at - from, Vector3.UP), from)
		await _frames(50)
		await _drawn(8)
		_save_raw(view, v)
	# the player's own camera, as in a match
	if p != null and p.camera != null and (views.is_empty() or "play" in views):
		view.source = p.camera
		await _frames(60)
		await _drawn(8)
		_save_raw(view, "play")
	view.source = null
	root.disable_3d = false
	view.queue_free()
	unload_current_scene()
	await _frames(10)
	return true


func _save_raw(view: SubViewport, v: String) -> void:
	var img: Image = view.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(ProjectSettings.globalize_path(HERE + "raw_%s_%s.png" % [v, light]))
	print("  raw ", v)


# ======================================================================================================== the paint
## Each backdrop: its raw view painted with the game's oil shader (broad masses, then strokes and canvas) and toned like
## lacquer; the menu's vista the most, the in-match frames lighter (the moment held as a painting).
func _paint_backs() -> void:
	var specs := {
		"main": {"brushes": [7, 3], "amount": 0.6, "vignette": 0.4},
		"pause": {"brushes": [5, 2], "amount": 0.5, "vignette": 0.42},
		"end": {"brushes": [6, 3], "amount": 0.6, "vignette": 0.45},
	}
	for key: String in specs:
		var bk := String(BACK[key])
		var raw := HERE + "raw_%s_%s.png" % [bk.get_slice(":", 0), bk.get_slice(":", 1) if ":" in bk else light]
		var img := Image.load_from_file(ProjectSettings.globalize_path(raw))
		if img == null or img.is_empty():
			print("C PAINTED: no raw view %s (run with render)" % raw)
			continue
		var s: Dictionary = specs[key]
		var painted := await _paint(img, s.brushes, s)
		painted.save_png(out_dir.path_join("backdrop_%s.png" % key))
		_backs[key] = ImageTexture.create_from_image(painted)


func _paint(src: Image, brushes: Array, s: Dictionary) -> Image:
	var size := src.get_size()
	var t: Texture2D = ImageTexture.create_from_image(src)
	var oil := load("res://shaders/ui/oil_paint.gdshader") as Shader
	for i in brushes.size():
		var m := ShaderMaterial.new()
		m.shader = oil
		m.set_shader_parameter("noise_a", _tex("noise_a.png"))
		m.set_shader_parameter("noise_b", _tex("noise_b.png"))
		m.set_shader_parameter("noise_c", _tex("noise_c.png"))
		m.set_shader_parameter("brush", int(brushes[i]))
		m.set_shader_parameter("finish", i == brushes.size() - 1)
		m.set_shader_parameter("vignette", 0.15)
		# (the varnish's ends: lacquer black and eggshell instead of the shader's umber and ivory, so the water and the
		# night keep their blues)
		m.set_shader_parameter("umber", Vector3(0.035, 0.022, 0.022))
		m.set_shader_parameter("ivory", Vector3(0.99, 0.95, 0.87))
		m.set_shader_parameter("lift", float(s.get("lift", 0.9)))
		var img := await _pass(t, size, m)
		t = ImageTexture.create_from_image(img)
	var g := ShaderMaterial.new()
	g.shader = _shader("grade.gdshader")
	g.set_shader_parameter("grain", _tex("paper_tile.png"))
	g.set_shader_parameter("amount", float(s.get("amount", 0.6)))
	g.set_shader_parameter("vignette", float(s.get("vignette", 0.4)))
	g.set_shader_parameter("darken", float(s.get("darken", 0.0)))
	return await _pass(t, size, g)


func _pass(tex: Texture2D, size: Vector2i, mat: Material) -> Image:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var rect := TextureRect.new()
	rect.texture = tex
	rect.size = Vector2(size)
	rect.material = mat
	vp.add_child(rect)
	root.add_child(vp)
	await _drawn(4)
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	vp.queue_free()
	return img


# ======================================================================================================== the pieces
func _tex(name: String) -> Texture2D:
	if not _texs.has(name):
		var img := Image.load_from_file(ProjectSettings.globalize_path(HERE + name))
		if img != null and not img.is_empty():
			img.generate_mipmaps()
			_texs[name] = ImageTexture.create_from_image(img)
		else:
			push_error("c_painted: no " + name)
			_texs[name] = null
	return _texs[name]


func _shader(name: String) -> Shader:
	if not _shaders.has(name):
		var s := Shader.new()
		s.code = FileAccess.get_file_as_string(ProjectSettings.globalize_path(HERE + name))
		_shaders[name] = s
	return _shaders[name]


## The mock's faces, from the Mac's own fonts (SystemFont). This engine opens only the first face of a font collection
## (.ttc): Baskerville gives its Regular (the semibold is it emboldened), Avenir Next its Bold (the tracked capitals),
## Helvetica Neue its Regular (the small lines); the italic is Georgia's own Italic file. All write every Vietnamese
## letter. The real build bundles OFL faces instead (the report: Spectral and Be Vietnam Pro).
func _font(key: String) -> Font:
	if not _fonts.has(key):
		var spec: Array = {"title": [SERIF, false, 0.12], "serif": [SERIF, false, 0.0], "serif_semi": [SERIF, false, 0.32],
				"serif_it": [ITALIC, true, 0.0], "serif_semi_it": [ITALIC, true, 0.25], "sans": [SANS, false, 0.12],
				"sans_reg": [SANS, false, 0.0], "sans_demi": [CAPS, false, 0.0]}.get(key, [SERIF, false, 0.0])
		var f := SystemFont.new()
		f.font_names = PackedStringArray(spec[0])
		f.font_italic = bool(spec[1])
		f.fallbacks = [ThemeDB.fallback_font]
		f.hinting = TextServer.HINTING_LIGHT
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		if float(spec[2]) > 0.0:
			var v := FontVariation.new()
			v.base_font = f
			v.variation_embolden = float(spec[2])
			_fonts[key] = v
		else:
			_fonts[key] = f
	return _fonts[key]


func _spaced(key: String, px: float) -> Font:
	var v := FontVariation.new()
	v.base_font = _font(key)
	v.spacing_glyph = int(px)
	return v


## A label at `pos` (its top left) in `parent`; `width` > 0 wraps it there (`wrap`) or aligns it within.
func _label(parent: Control, text: String, font: Variant, size: int, color: Color, pos: Vector2, width := 0.0,
		align := HORIZONTAL_ALIGNMENT_LEFT, shadow := false, wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font if font is Font else _font(String(font)))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if shadow:
		l.add_theme_color_override("font_shadow_color", SHADOW)
		l.add_theme_constant_override("shadow_offset_x", 1)
		l.add_theme_constant_override("shadow_offset_y", 2)
		l.add_theme_constant_override("shadow_outline_size", 7)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if width > 0.0 and wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	l.position = pos
	if width > 0.0:
		l.custom_minimum_size = Vector2(width, 0)
		l.size = Vector2(width, 0)
	return l


## Gold-leaf lettering (gold_text.gdshader): the label drawn white, turned to gold by its material.
func _gold(parent: Control, text: String, font: Variant, size: int, pos: Vector2, width := 0.0,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := _label(parent, text, font, size, Color.WHITE, pos, width, align, true, false)
	l.add_theme_color_override("font_shadow_color", Color(0.06, 0.02, 0.01, 0.85))
	l.add_theme_constant_override("shadow_outline_size", 12)
	l.add_theme_constant_override("shadow_offset_y", 3)
	var m := ShaderMaterial.new()
	m.shader = _shader("gold_text.gdshader")
	m.set_shader_parameter("flake", _tex("flake_noise.png"))
	m.set_shader_parameter("top", size * 0.28)
	m.set_shader_parameter("height", size * 0.82)
	l.material = m
	return l


func _img(parent: Control, name: String, rect: Rect2, tint := Color.WHITE, rot := 0.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = _tex(name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.position = rect.position
	r.size = rect.size
	r.pivot_offset = rect.size * 0.5
	r.rotation_degrees = rot
	r.modulate = tint
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


## A soft shadow under a panel.
func _shadow(parent: Control, rect: Rect2, a := 0.45, size := 18, off := Vector2(0, 8), radius := 6) -> void:
	var sh := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, a * 0.7)
	sb.shadow_color = Color(0, 0, 0, a)
	sb.shadow_size = size
	sb.shadow_offset = off
	sb.set_corner_radius_all(radius)
	sh.add_theme_stylebox_override("panel", sb)
	sh.position = rect.position + Vector2(5, 5)
	sh.size = rect.size - Vector2(10, 10)
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(sh)


## A sheet or slip of rice paper (paper.gdshader); returns the holder its contents go into (it turns with `rot`).
func _paper(parent: Control, rect: Rect2, deckle := 6.0, age := 0.35, shadow := 0.42, rot := 0.0) -> Control:
	var holder := Control.new()
	holder.position = rect.position
	holder.size = rect.size
	holder.pivot_offset = rect.size * 0.5
	holder.rotation_degrees = rot
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	if shadow > 0.0:
		_shadow(holder, Rect2(Vector2.ZERO, rect.size), shadow)
	var p := ColorRect.new()
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = _shader("paper.gdshader")
	m.set_shader_parameter("paper", _tex("paper_tile.png"))
	m.set_shader_parameter("edge_noise", _tex("edge_noise.png"))
	m.set_shader_parameter("rect_size", rect.size)
	m.set_shader_parameter("deckle", deckle)
	m.set_shader_parameter("age", age)
	_seed += 1
	m.set_shader_parameter("seed", Vector2(fmod(_seed * 0.37, 1.0), fmod(_seed * 0.61, 1.0)))
	p.material = m
	holder.add_child(p)
	return holder


## A lacquer board (lacquer.gdshader).
func _lacquer(parent: Control, rect: Rect2, band := 8.0, gold_inset := 13.0, radius := 5.0, shadow := 0.5,
		red := 0.0) -> Control:
	var holder := Control.new()
	holder.position = rect.position
	holder.size = rect.size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	if shadow > 0.0:
		_shadow(holder, Rect2(Vector2.ZERO, rect.size), shadow, 22, Vector2(0, 10))
	var p := ColorRect.new()
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = _shader("lacquer.gdshader")
	m.set_shader_parameter("lacquer", _tex("lacquer_tile.png"))
	m.set_shader_parameter("flake", _tex("flake_noise.png"))
	m.set_shader_parameter("rect_size", rect.size)
	m.set_shader_parameter("band", band)
	m.set_shader_parameter("gold_inset", gold_inset)
	m.set_shader_parameter("radius", radius)
	m.set_shader_parameter("base_mix", red)
	if red > 0.0:
		m.set_shader_parameter("band_col", Vector3(0.16, 0.05, 0.035))
	_seed += 1
	m.set_shader_parameter("seed", Vector2(fmod(_seed * 0.29, 1.0), fmod(_seed * 0.53, 1.0)))
	p.material = m
	holder.add_child(p)
	return holder


## A scroll rod (a nine-patch whose margins are its gold knobs): the thin top stick or the heavier foot roller.
func _rod(parent: Control, x: float, y: float, w: float, foot := false) -> void:
	var r := NinePatchRect.new()
	r.texture = _tex("rod_foot.png" if foot else "rod_top.png")
	var m := 56 if foot else 40
	r.patch_margin_left = m
	r.patch_margin_right = m
	r.position = Vector2(x, y)
	r.size = Vector2(w, 42.0 if foot else 28.0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)


## A thin gold hairline round `rect`.
func _hairline(parent: Control, rect: Rect2, color := Color(GOLD, 0.85), width := 1.2) -> void:
	var line := ReferenceRect.new()
	line.border_color = color
	line.border_width = width
	line.editor_only = false
	line.position = rect.position
	line.size = rect.size
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)


## A hanging scroll: a lacquer mount (wider at its head and foot), the paper inside it with a gold hairline, the ink-wash
## river at the paper's foot (`wash` its height, 0: none), the stick at its head and the roller at its foot, and, with
## `cord`, the cord it hangs by. Returns the paper's rect.
func _scroll(parent: Control, rect: Rect2, wash := 150.0, cord := false, wash_right := false) -> Rect2:
	if cord:
		var l := Line2D.new()
		l.points = PackedVector2Array([rect.position + Vector2(46, -2), rect.position + Vector2(rect.size.x * 0.5, -64),
				rect.position + Vector2(rect.size.x - 46, -2)])
		l.width = 2.4
		l.default_color = Color(0.36, 0.10, 0.07)
		l.antialiased = true
		l.joint_mode = Line2D.LINE_JOINT_ROUND
		parent.add_child(l)
		_img(parent, "ink_life.png", Rect2(rect.position + Vector2(rect.size.x * 0.5 - 7, -71), Vector2(14, 14)), GOLD)
	_lacquer(parent, rect, 6.0, 11.0, 2.0, 0.6, 0.85)
	var inner := Rect2(rect.position + Vector2(17, 34), rect.size - Vector2(34, 34 + 44))
	_paper(parent, inner, 0.0, 0.1, 0.0)
	_hairline(parent, inner.grow(3.0))
	if wash > 0.0:
		# the whole river, or (beside rows that reach the foot) only its boat and towers at the right
		var region := Rect2(260, 0, 740, 380) if wash_right else Rect2(0, 0, 1000, 380)
		var wh := wash
		var ww := minf(wh * region.size.x / region.size.y, inner.size.x - 8.0)
		wh = ww * region.size.y / region.size.x
		var at := Vector2(inner.end.x - ww - 4.0, inner.end.y - wh - 4.0)
		var tr := _img(parent, "wash_karst.png", Rect2(at, Vector2(ww, wh)), Color(INK, 0.32))
		var atlas := AtlasTexture.new()
		atlas.atlas = _tex("wash_karst.png")
		atlas.region = region
		tr.texture = atlas
		# a vermilion sun over the tallest tower (not beside rows: it would read as a mark on one)
		var sun := (820.0 - region.position.x) / region.size.x
		if not wash_right:
			_img(parent, "ink_life.png", Rect2(at + Vector2(ww * sun - wh * 0.30, wh * 0.02), Vector2(wh * 0.15, wh * 0.15)),
					Color(VERMILION, 0.6))
	_rod(parent, rect.position.x - 20, rect.position.y - 13, rect.size.x + 40)
	_rod(parent, rect.position.x - 28, rect.end.y - 22, rect.size.x + 56, true)
	return inner


## A brush rule under a heading (ink_rule.png, or the short one).
func _rule(parent: Control, pos: Vector2, w: float, tint := INK, thick := 1.0) -> void:
	_img(parent, "ink_rule.png", Rect2(pos, Vector2(w, 22.0 * thick)), tint)


## How tall a row is: its text in the serif at `size`, its line under it.
func _row_h(size: int, sub: String) -> float:
	return float(size) * 1.32 + (float(_sub_size(size)) * 1.35 if sub != "" else 0.0)


func _sub_size(size: int) -> int:
	return maxi(13, int(round(size * 0.52)))


## A menu row on paper or on the dark: the text in the serif, its line under it in the sans; `focused` lays the
## vermilion brush swash under it and turns the text to eggshell. Returns the row's height.
func _row(parent: Control, x: float, y: float, w: float, text: String, sub := "", focused := false, size := 27,
		dark := false) -> float:
	var h := _row_h(size, sub)
	if focused:
		var ih := (h + 16.0) / 0.72
		_img(parent, "ink_swash.png", Rect2(x - 30, y + h * 0.5 - ih * 0.52, w + 46, ih), VERMILION)
	var tc := EGGSHELL if (focused or dark) else INK
	var sc := Color(EGGSHELL, 0.9) if focused else (EGG_DIM if dark else INK_SOFT)
	var tl := _label(parent, text, "serif_semi" if focused else "serif", size, tc, Vector2(x, y), 0.0, HORIZONTAL_ALIGNMENT_LEFT,
			dark or focused)
	if focused:
		tl.add_theme_color_override("font_shadow_color", Color(0.22, 0.04, 0.02, 0.7))
		tl.add_theme_constant_override("shadow_outline_size", 4)
	if sub != "":
		_label(parent, sub, "sans", _sub_size(size), sc, Vector2(x + 1, y + size * 1.24), 0.0, HORIZONTAL_ALIGNMENT_LEFT,
				dark and not focused)
	return h


## Small capitals (Avenir, tracked) in vermilion or gold.
func _caps(parent: Control, text: String, pos: Vector2, color := VERMILION, size := 12, track := 4.0, shadow := false) -> Label:
	return _label(parent, text, _spaced("sans_demi", track), size, color, pos, 0.0, HORIZONTAL_ALIGNMENT_LEFT, shadow)


## An element's seal: the ensō, the element's brush glyph in its ink; chosen: a wash of its ink, a darker ensō and the
## red chop at its foot.
func _seal(parent: Control, el: String, center: Vector2, d: float, chosen: bool, faint := false) -> void:
	var ink: Color = EL_INK[el]
	if chosen:
		_img(parent, "ink_life.png", Rect2(center - Vector2(d, d) * 0.45, Vector2(d, d) * 0.9), Color(ink, 0.2))
	var turn: float = [-8.0, 24.0, 61.0, 140.0][ELS.find(el)]
	_img(parent, "ink_enso.png", Rect2(center - Vector2(d, d) * 0.5, Vector2(d, d)),
			Color(ink.darkened(0.35), 0.95) if chosen else Color(INK, 0.38 if faint else 0.6), turn)
	var g := d * 0.6
	_img(parent, "ink_%s.png" % el, Rect2(center - Vector2(g, g) * 0.5, Vector2(g, g)), ink if not faint else Color(ink, 0.8))
	if chosen:
		var c := d * 0.26
		_img(parent, "chop_square.png", Rect2(center + Vector2(d * 0.27, d * 0.22), Vector2(c, c)), SEAL_RED, -9.0)


## A vermilion lacquer plaque with a gold line and the word on it (Begin, Watch).
func _plaque(parent: Control, rect: Rect2, text: String, size := 32, track := 2.0) -> void:
	var b := _lacquer(parent, rect, 0.0, 0.0, 4.0, 0.45)
	var tint := ColorRect.new()
	tint.color = Color(0.62, 0.15, 0.10, 0.84)
	tint.position = Vector2(2, 2)
	tint.size = rect.size - Vector2(4, 4)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(tint)
	var inset := clampf(rect.size.y * 0.11, 4.0, 7.0)
	_hairline(b, Rect2(Vector2(inset, inset), rect.size - Vector2(inset, inset) * 2.0), Color(GOLD, 0.9), 1.3)
	var l := _label(b, text, _spaced("serif_semi", track), size, EGGSHELL, Vector2.ZERO, rect.size.x,
			HORIZONTAL_ALIGNMENT_CENTER, true, false)
	l.position.y = (rect.size.y - l.get_combined_minimum_size().y) * 0.5


## The backdrop: `key`'s painting covering the view.
func _backdrop(base: Control, key: String, view: Vector2, dim := 1.0) -> void:
	var bg := ColorRect.new()
	bg.color = Color("120c0a")
	bg.size = view
	base.add_child(bg)
	var t: Texture2D = _backs.get(key)
	if t == null:
		return
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.size = view
	r.self_modulate = Color(dim, dim, dim)
	base.add_child(r)


## A soft shade from the left (lacquer brown) so the scroll and the title sit on the painting.
func _left_shade(base: Control, view: Vector2, a := 0.7, reach := 0.55) -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0.06, 0.03, 0.02, a))
	g.set_color(1, Color(0.06, 0.03, 0.02, 0.0))
	g.add_point(0.45, Color(0.06, 0.03, 0.02, a * 0.75))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0.5)
	t.fill_to = Vector2(1, 0.5)
	t.width = 256
	t.height = 4
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.size = Vector2(view.x * reach, view.y)
	base.add_child(r)


func _veil(base: Control, view: Vector2, a: float) -> void:
	var v := ColorRect.new()
	v.color = Color(0.05, 0.025, 0.02, a)
	v.size = view
	base.add_child(v)


## The 1600 x 900 design space, scaled down to fit a smaller view (as MainMenu._fit_menu_layout).
func _layout(base: Control, view: Vector2) -> Control:
	var fit := maxf(minf(1.0, minf(view.x / float(W), view.y / float(H))), 0.01)
	var lay := Control.new()
	lay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.add_child(lay)
	lay.scale = Vector2.ONE * fit
	lay.size = view / fit
	return lay


func _shoot(name: String, size: Vector2i, build: Callable) -> void:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var base := Control.new()
	base.size = Vector2(size)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.add_child(base)
	_seed = 0
	build.call(base, Vector2(size))
	await _drawn(6)
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(out_dir.path_join(name + ".png"))
	print("  shot %s %dx%d" % [name, img.get_width(), img.get_height()])
	vp.queue_free()
	await _frames(2)


# ======================================================================================================== the words
func _el_label(el: String) -> String:
	return String(((EL.get("elements", {}) as Dictionary).get(el, {}) as Dictionary).get("label", el.capitalize()))


func _competitor(el: String) -> String:
	return String(((EL.get("elements", {}) as Dictionary).get(el, {}) as Dictionary).get("competitor", el.capitalize()))


func _style(el: String) -> String:
	return String(((EL.get("elements", {}) as Dictionary).get(el, {}) as Dictionary).get("style", ""))


func _rw(key: String) -> String:
	return String(RW.get(key, key))


func _mw(key: String) -> String:
	return String((SC.get("match", {}) as Dictionary).get(key, key))


# ======================================================================================================== main menu
## The title, the hanging scroll with the rows (`focus` the focused one's key) and the caption slip. Returns the layout.
func _menu_base(base: Control, view: Vector2, focus: String, dim := 1.0, caption := true) -> Control:
	_backdrop(base, "main", view, dim)
	_left_shade(base, view, 0.62, 0.48)
	var lay := _layout(base, view)
	# the title: the world's name over it, the game's seal after it
	_caps(lay, "THỦY VÂN", Vector2(95, 38), GOLD, 14, 8.0, true)
	_gold(lay, "TIDEBREAK", _spaced("title", 8), 84, Vector2(86, 48))
	_img(lay, "seal_tidebreak.png", Rect2(682, 68, 76, 76), Color(1.25, 1.12, 1.08), -5.0)
	_caps(lay, "ELEMENTAL ARENA COMBAT", Vector2(93, 150), EGGSHELL, 15, 5.0, true)
	_caps(lay, "EARLY PLAYABLE DEMO  ·  IN DEVELOPMENT", Vector2(94, 175), EGG_DIM, 11, 3.0, true)
	# the scroll and its rows
	var sport: Dictionary = EL.get("sport", {})
	var top := [
		["tidebreak", String(sport.get("name", "Tidebreak")), String(sport.get("menu_line", ""))],
		["start", "Start here", "learn at your own pace, or play an easy match"],
		["quick", "Quick match", MatchSetup.quick_line()],
		["practice", "Practice", "a %s dummy that %s" % [_competitor("water"), MatchSetup.dummy_line("stand")]],
	]
	var fighter := [
		["talents", "Class & talents", "your class, its talents and your loadouts"],
		["look", "Your look", "the character creator: face, build and dress"],
	]
	var paper := _scroll(lay, Rect2(84, 222, 504, 650), 170.0, false, true)
	var x := paper.position.x + 30.0
	var w := paper.size.x - 58.0
	var y := paper.position.y + 18.0
	for r: Array in top:
		y += _row(lay, x, y, w, String(r[1]), String(r[2]), focus == r[0]) + 11.0
	y += 3.0
	_caps(lay, "FIGHTER", Vector2(x, y), VERMILION, 12, 5.0)
	_rule(lay, Vector2(x + 98, y + 1), 190, Color(VERMILION, 0.75), 0.75)
	y += 26.0
	for r: Array in fighter:
		y += _row(lay, x, y, w, String(r[1]), String(r[2]), focus == r[0]) + 11.0
	y += 1.0
	_rule(lay, Vector2(x - 6, y - 4), w * 0.62, Color(INK, 0.5), 0.8)
	y += 14.0
	for r in ["Settings", "Credits", "Quit"]:
		y += _row(lay, x, y, w, String(r), "", focus == String(r).to_lower(), 24) + 1.0
	if caption:
		var cap := _paper(lay, Rect2(lay.size.x - 534, lay.size.y - 160, 446, 112), 5.0, 0.4, 0.55, -0.8)
		_img(cap, "seal_tidebreak.png", Rect2(22, 28, 42, 42), Color.WHITE, 4.0)
		_label(cap, "Four elements. One arena.", "serif_semi", 22, INK, Vector2(80, 16))
		_label(cap, "Choose Earth, Water, Fire or Air. Build pressure, earn your opening and send your opponent into the water.",
				"sans_reg", 13, INK_SOFT, Vector2(81, 47), 340.0)
	return lay


func _main_screen(base: Control, view: Vector2) -> void:
	_menu_base(base, view, "tidebreak")


# ======================================================================================================== match panel
func _match_screen(base: Control, view: Vector2) -> void:
	var lay := _menu_base(base, view, "tidebreak", 0.5, false)
	var sheet_r := Rect2(lay.size.x - 952, 50, 884, 812)
	var s := _paper(lay, sheet_r, 6.0, 0.3, 0.6)
	_rod(lay, sheet_r.position.x - 20, sheet_r.position.y - 16, sheet_r.size.x + 40)
	var x := 50.0
	var cw := sheet_r.size.x - 100.0
	var sport: Dictionary = EL.get("sport", {})
	_label(s, String(sport.get("name", "Tidebreak")), "serif_semi", 44, INK, Vector2(x, 26))
	_caps(s, "MATCH SETUP", Vector2(x + 252, 49), VERMILION, 12, 5.0)
	_rule(s, Vector2(x - 6, 82), 620, Color(INK, 0.85), 0.9)
	_label(s, String(sport.get("line", "")), "sans_reg", 15, INK_SOFT, Vector2(x, 104), cw)
	_caps(s, "YOUR ELEMENT", Vector2(x, 168), VERMILION, 12, 5.0)
	var chosen := "earth"
	var cell := cw / 4.0
	for i in ELS.size():
		var el: String = ELS[i]
		var cx := x + cell * (i + 0.5)
		_seal(s, el, Vector2(cx, 232), 100.0, el == chosen)
		_label(s, _el_label(el), "serif_semi" if el == chosen else "serif", 26, INK, Vector2(cx - cell * 0.5, 284), cell,
				HORIZONTAL_ALIGNMENT_CENTER, false, false)
		_label(s, (_competitor(el) + ("  ·  chosen" if el == chosen else "")).to_upper(), _spaced("sans_demi", 2), 11,
				EL_INK[el], Vector2(cx - cell * 0.5, 318), cell, HORIZONTAL_ALIGNMENT_CENTER, false, false)
	# the chosen element: its style in a line, its passive, its buttons in two columns
	var y := 348.0
	_rule(s, Vector2(x - 6, y), cw, Color(EL_INK[chosen], 0.55), 0.7)
	y += 22.0
	_label(s, "%s  ·  %s" % [_competitor(chosen), _style(chosen)], "serif_it", 19, Color(EL_INK[chosen]).darkened(0.35),
			Vector2(x, y), cw)
	y += 30.0
	_label(s, KitWords.passive_line(chosen), "sans", 14, INK, Vector2(x, y), cw)
	y += 26.0
	var kl: Array = KitWords.kit_lines(chosen, "", true)
	var rows := ceili(kl.size() / 2.0)
	for i in kl.size():
		var col := i / rows
		_label(s, String(kl[i]).replace("      ", "   ·   "), "sans_reg", 13, INK_SOFT,
				Vector2(x + col * (cw * 0.5 + 10.0), y + (i % rows) * 20.0))
	y += rows * 20.0 + 18.0
	# the setup in three columns: a press steps each
	var grid := [
		["OPPONENT", "Any", String((EL.get("any", {}) as Dictionary).get("style", ""))],
		["DIFFICULTY", "normal", String((EL.get("difficulties", {}) as Dictionary).get("normal", ""))],
		["LIGHT", light, String((EL.get("lights", {}) as Dictionary).get(light, ""))],
		["RULES", String(PRM.get("stock", "Lives")), String(PRM.get("rules_line_stock", ""))],
		["GAMES", String(PRM.get("games_3", "best of 3")), "the first to 2 games takes the match"],
		["FORMAT", "1 v 1", "3 v 3 teams: coming"],
	]
	_rule(s, Vector2(x - 6, y - 10), cw, Color(INK, 0.35), 0.6)
	var gw := (cw - 2 * 28.0) / 3.0
	for i in grid.size():
		var g: Array = grid[i]
		var gx := x + (gw + 28.0) * (i % 3)
		var gy := y + 6.0 + 92.0 * float(i / 3)
		_caps(s, String(g[0]), Vector2(gx, gy), VERMILION, 11, 4.0)
		_label(s, String(g[1]), "serif_semi", 24, INK, Vector2(gx, gy + 15))
		_img(s, "ink_prev.png", Rect2(gx + gw - 58, gy + 20, 24, 24), Color(INK, 0.65))
		_img(s, "ink_next.png", Rect2(gx + gw - 30, gy + 20, 24, 24), Color(INK, 0.65))
		_label(s, String(g[2]), "sans_reg", 12, INK_SOFT, Vector2(gx + 1, gy + 48), gw - 6.0)
	# Controls and Begin
	var by := sheet_r.size.y - 92.0
	_rule(s, Vector2(x - 6, by - 16), cw, Color(INK, 0.35), 0.6)
	_label(s, KitWords.w("controls", "Controls"), "serif", 24, INK, Vector2(x, by + 6))
	_img(s, "ink_next.png", Rect2(x + 108, by + 12, 22, 22), Color(INK, 0.6))
	_label(s, KitWords.w("controls_line"), "sans_reg", 13, INK_SOFT, Vector2(x + 1, by + 42), cw - 330.0)
	_plaque(s, Rect2(sheet_r.size.x - 50 - 250, by - 2, 250, 70), "Begin", 34, 3)


# ======================================================================================================== pause
func _pause_screen(base: Control, view: Vector2) -> void:
	_backdrop(base, "pause", view)
	_veil(base, view, 0.24)
	_left_shade(base, view, 0.6, 0.48)
	var lay := _layout(base, view)
	var rows := [
		[_rw("resume"), "", true],
		[_rw("restart"), _rw("restart_line_game"), false],
		[_rw("element") % _el_label("earth"), _rw("element_line"), false],
		[_rw("opponent") % _competitor("water"), _rw("opponent_line"), false],
		[_rw("options"), _rw("options_line"), false],
		[KitWords.w("controls", "Controls"), KitWords.w("controls_line"), false],
		[_rw("main_menu"), "", false],
		[_rw("quit"), "", false],
	]
	var size := 25
	var content := 16.0 + 52.0 + 18.0 + 24.0
	for r: Array in rows:
		content += _row_h(size, String(r[1])) + (9.0 if String(r[1]) != "" else 3.0)
	var wash := 150.0
	var mount_h := content + wash + 34.0 + 44.0 + 6.0
	var top := maxf(96.0, (lay.size.y - mount_h) * 0.5 + 18.0)
	var paper := _scroll(lay, Rect2(96, top, 492, mount_h), wash, true)
	var x := paper.position.x + 30.0
	var w := paper.size.x - 58.0
	var y := paper.position.y + 16.0
	_label(lay, _rw("menu_title"), "serif_semi", 40, INK, Vector2(x, y))
	y += 52.0
	var note := _rw("menu_note_game") % [2, 5, 41, _rw("score") % [_rw("you"), 1, 0, _competitor("water")]]
	_caps(lay, note.to_upper(), Vector2(x + 1, y), VERMILION, 11, 2.5)
	y += 18.0
	_rule(lay, Vector2(x - 6, y), w * 0.9, Color(INK, 0.8), 0.8)
	y += 24.0
	for r: Array in rows:
		y += _row(lay, x, y, w, String(r[0]), String(r[1]), bool(r[2]), size) + (9.0 if String(r[1]) != "" else 3.0)
	# lives, on a slip at the right
	var slip := _paper(lay, Rect2(lay.size.x - 396, 96, 300, 172), 5.0, 0.4, 0.55, 0.8)
	_caps(slip, "LIVES LEFT", Vector2(28, 22), VERMILION, 11, 4.0)
	var who := [[_rw("you"), "earth", 3], ["The " + _competitor("water"), "water", 2]]
	for i in who.size():
		var wv: Array = who[i]
		var yy := 52.0 + i * 54.0
		_label(slip, String(wv[0]), "serif_semi", 22, INK, Vector2(28, yy))
		for k in 3:
			var full := k < int(wv[2])
			var c := Vector2(170 + k * 42, yy + 16)
			if full:
				_img(slip, "ink_life.png", Rect2(c - Vector2(19, 19), Vector2(38, 38)), EL_INK[String(wv[1])], k * 23.0)
				_img(slip, "ink_%s.png" % String(wv[1]), Rect2(c - Vector2(13, 13), Vector2(26, 26)), Color(EGGSHELL, 0.92))
			else:
				_img(slip, "ink_life_empty.png", Rect2(c - Vector2(19, 19), Vector2(38, 38)), Color(INK, 0.5), k * 23.0)


# ======================================================================================================== match end
func _end_screen(base: Control, view: Vector2) -> void:
	_backdrop(base, "end", view)
	_veil(base, view, 0.30)
	_left_shade(base, view, 0.66, 0.62)
	var lay := _layout(base, view)
	var them := _competitor("water")
	# the result
	_img(lay, "seal_tidebreak.png", Rect2(80, 50, 120, 120), Color.WHITE, -6.0)
	_gold(lay, _mw("head_win"), _spaced("title", 4), 98, Vector2(222, 26))
	_label(lay, _mw("line_win"), "serif_it", 27, EGGSHELL, Vector2(230, 148), 0.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	var score := _label(lay, _rw("score") % [_rw("you"), 2, 1, them], "serif_semi", 46, EGGSHELL, Vector2(88, 192), 0.0,
			HORIZONTAL_ALIGNMENT_LEFT, true)
	score.add_theme_color_override("font_color", EGGSHELL)
	# the falls and the tally, on a sheet
	var sheet := _paper(lay, Rect2(84, 270, 660, 318), 6.0, 0.32, 0.55, -0.4)
	# who fought: your seal against theirs, at the sheet's head
	_seal(sheet, "earth", Vector2(470, 50), 58.0, true)
	_label(sheet, "vs", "serif_it", 18, INK_SOFT, Vector2(510, 38))
	_seal(sheet, "water", Vector2(566, 50), 58.0, false)
	var x := 38.0
	_caps(sheet, "THE MATCH", Vector2(x, 26), VERMILION, 12, 5.0)
	var lives := _mw("lives_line") % [2, them, 0]
	_label(sheet, lives, "serif_semi", 20, INK, Vector2(x, 46))
	var y := 84.0
	var falls := [
		["Game 1  ·  1:48", "the %s" % them, 131, "Boulder"],
		["Game 1  ·  3:02", "you", 118, "Splash"],
		["Game 2  ·  0:57", "the %s" % them, 142, "Spike"],
		["Game 2  ·  2:31", "the %s" % them, 109, "Boulder"],
	]
	for f: Array in falls:
		_label(sheet, _mw("fall_line") % [f[0], f[1], int(f[2]), f[3]], "sans_reg", 14, INK_SOFT, Vector2(x, y))
		y += 22.0
	y += 8.0
	_rule(sheet, Vector2(x - 6, y), 460, Color(INK, 0.5), 0.6)
	y += 18.0
	for line in [_mw("tally_falls") % [7, 4, 0], _mw("tally_pct") % [612, 151, 0], _mw("tally_string") % [5, 64],
			_mw("tally_guards") % [6, 4, 3, 2, 1]]:
		_label(sheet, String(line), "sans", 14, INK, Vector2(x, y))
		y += 22.0
	# the rows, on the dark
	var ry := 624.0
	var rows := [
		[_mw("rematch"), _mw("rematch_line"), true],
		[_mw("element") % _el_label("earth"), _mw("element_line"), false],
		[_mw("opponent") % them, _mw("opponent_line"), false],
		[_mw("main_menu"), _mw("main_menu_line"), false],
	]
	for r: Array in rows:
		ry += _row(lay, 118, ry, 420, String(r[0]), String(r[1]), bool(r[2]), 25, true) + 8.0
	# the highlights: three slips at the right
	var hx := lay.size.x - 572
	_caps(lay, String(HL.get("head", "Highlights")).to_upper(), Vector2(hx + 4, 56), GOLD, 13, 6.0, true)
	_rule(lay, Vector2(hx + 168, 58), 200, Color(GOLD, 0.7), 0.7)
	var plays: Dictionary = HL.get("plays", {})
	var cards := [["launch", "air", "%d m/s" % 31], ["catch", "earth", "%.2f s" % 0.12], ["comeback", "water", "%d lives down" % 2]]
	for i in cards.size():
		var c: Array = cards[i]
		var p: Dictionary = plays.get(String(c[0]), {})
		var card := _paper(lay, Rect2(hx, 90 + i * 176, 484, 152), 5.0, 0.38, 0.55, [0.6, -0.5, 0.4][i])
		_seal(card, String(c[1]), Vector2(66, 76), 88.0, false)
		_label(card, String(p.get("title", "")), "serif_semi", 25, INK, Vector2(128, 20))
		var line := String(p.get("line", "")).replace("{who}", _rw("you")).replace("{whom}", "the " + them)
		_label(card, line, "sans_reg", 14, INK_SOFT, Vector2(129, 58), 330.0)
		_label(card, String(c[2]), "serif_semi", 30, VERMILION, Vector2(128, 90))
		_plaque(card, Rect2(484 - 140, 96, 110, 36), String(HL.get("watch", "Watch")), 17, 2)
