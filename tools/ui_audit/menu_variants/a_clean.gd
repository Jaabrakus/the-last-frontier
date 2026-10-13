extends SceneTree
## SUPERSEDED 2026-10-10: the owner chose style B (scripts/ui/menu/broadcast_ui.gd); kept as a reference mock-up, not wired into the game.
## Menu style mock A, "Clean gold serif" (UI audit, 2026-10-09; the owner picks one of four by eye). Read-only on the game:
## it builds its own mock screens from the game's real words (data/ring/*.json through MatchSetup, the menu rows of
## MainMenu, RingMenu and MatchScreen) over frames of our own ring, and saves PNGs. No class_name: nothing to refresh in the
## global class cache, nothing other runs can trip over.
##
##   part=bg   loads scenes/ring.tscn (fire against water) once per light, holds it at the countdown with every CanvasLayer
##             (the HUD) hidden, and renders the backdrops through an off-window SubViewport to
##             tools/ui_audit/menu_variants/a_clean/bg_<light>_<shot>.png (provenance: a_clean/SOURCE.md). By default
##             the three the screens use (BG_USED); lights=... only=... render other candidates.
##   part=ui   builds the four screens over those backdrops at 1600 x 900 (and main + pause at 1280 x 720) in its own 2D
##             SubViewport and writes artifacts/ui_audit/menu_variants/a_clean/<screen>.png
##
##   GODOT_TIMEOUT=400 zsh tools/loop/godot_run.sh --path . --resolution 1600x900 -s tools/ui_audit/menu_variants/a_clean.gd -- part=bg
##   GODOT_TIMEOUT=200 zsh tools/loop/godot_run.sh --path . --resolution 1600x900 -s tools/ui_audit/menu_variants/a_clean.gd -- part=ui

const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const HELP_DIR := "res://tools/ui_audit/menu_variants/a_clean/"
const OUT_DIR := "res://artifacts/ui_audit/menu_variants/a_clean/"
const OWN_CFG := "user://ui_variant_a_clean.cfg"
const HOWTO := "user://how_to.cfg"
const LIMIT_S := 380.0

## The backdrops the screens use: the night light's fighter at the right (main, match), the noon light from behind the
## player (pause) and the noon fighter at the right (end).
const BG_USED := {"night": ["hero_r"], "noon": ["behind", "hero_r"]}

var part := "ui"
var lights: Array = []
var only := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		var v := kv.get_slice("=", 1)
		match kv.get_slice("=", 0):
			"part": part = v
			"lights": lights = Array(v.split(",", false))
			"only": only = v
	CaptureKit.window()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(HELP_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("A_CLEAN watchdog")
		_end(2))
	if part == "bg":
		_bg.call_deferred()
	elif part == "probe":
		_probe.call_deferred()
	else:
		_ui.call_deferred()


func _end(code := 0) -> void:
	Engine.time_scale = 1.0
	paused = false
	if part == "bg":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
		GameSettings.path = GameSettings.PATH
		CaptureKit.restore([HOWTO])
	print("A_CLEAN DONE part=%s code=%d" % [part, code])
	quit(code)


func _frames(k: int) -> void:
	await CaptureKit.frames(self, k)


func _until(cond: Callable, limit_s: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(limit_s * 1000.0):
		if cond.call():
			return true
		await process_frame
	return false


# =================================================================================================== the backdrops
var _lvl: RingLevel
var _view: SubViewport


func _bg() -> void:
	CaptureKit.keep([HOWTO])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = OWN_CFG
	seed(1750)
	MatchSetup._aim_help = "strong"
	RingRules.rule_set_override = "stock"
	InputSetup.ensure()
	for light: String in (lights if not lights.is_empty() else BG_USED.keys()):
		if not await _bg_light(light):
			return _end(1)
	_end(0)


## Ring-local point (x along the deck from its middle, z across, y over the deck's top) as a world point.
func _at(x: float, z := 0.0, y := 0.0) -> Vector3:
	return _lvl.ring.to_global(Vector3(x, _lvl.ring.top() + y, z))


func _bg_light(light: String) -> bool:
	paused = false
	Engine.time_scale = 1.0
	root.disable_3d = false
	if _view != null and is_instance_valid(_view):
		_view.queue_free()
	MatchSetup.incoming = true
	MatchSetup.kind = "match"
	MatchSetup.element = "fire"
	MatchSetup.foes = ["water"]
	MatchSetup.light = light
	change_scene_to_file("res://scenes/ring.tscn")
	await _frames(12)
	_lvl = current_scene as RingLevel
	if _lvl == null:
		print("A_CLEAN no ring level")
		return false
	var mode := RingMode.find(self)
	if not await _until(func() -> bool: return mode != null and mode.phase == "COUNTDOWN" and mode.foe != null, 60.0):
		print("A_CLEAN no countdown")
		return false
	await _until(func() -> bool: return not bool(_lvl.get_meta(&"loading_hold", false)), 30.0)
	var player := _lvl.player
	player.ignore_mouse_capture = true
	var foe: Node3D = mode.foe
	# (a quiet moment: both at their ends in the countdown, the camera settled behind the player)
	# (the countdown held short of its end, so nobody fights, until the entrance effects have played out)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3200:
		mode.phase_t = minf(mode.phase_t, 1.0)
		await process_frame
	for layer: Node in root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("A_CLEAN %s player %s foe %s cam %s" % [light, _lvl.ring.to_local(player.global_position),
			_lvl.ring.to_local(foe.global_position), _lvl.ring.to_local(player.camera.global_position)])
	var game_xf := player.camera.global_transform
	var game_fov := player.camera.fov
	_view = OffscreenView.new()
	_view.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_view)
	_view.setup(root, Vector2i(1600, 900))
	root.disable_3d = true
	var rig := _lvl.environment_rig
	rig.follow_camera = _view.camera
	rig.process_mode = Node.PROCESS_MODE_ALWAYS
	if _lvl.look != null:
		_lvl.look.process_mode = Node.PROCESS_MODE_ALWAYS
	paused = true
	Engine.time_scale = 0.0
	var pp := _lvl.ring.to_local(player.global_position)
	# [from, to, fov, yaw: degrees turned left after aiming, which moves the subject right in the frame]
	var shots := {
		"game": [],
		"behind": [_at(-10.5, 0.0, 3.35), _at(4.5, 0.0, 1.0), 66.0, 0.0],
		"wide": [_at(-9.0, 2.8, 2.4), _at(9.0, -2.4, 2.6), 60.0, 0.0],
		"wide_r": [_at(-9.5, 2.2, 2.2), _at(9.0, -2.4, 2.8), 60.0, 15.0],
		"deck_r": [_at(-13.0, 7.0, 8.5), _at(4.0, -2.0, 0.0), 54.0, 13.0],
		"hero_r": [_at(pp.x + 3.6, pp.z - 1.0, 1.5), _at(pp.x - 0.4, pp.z + 0.4, 1.2), 50.0, 15.0],
		"front": [_at(pp.x + 3.4, pp.z - 1.2, 1.55), _at(pp.x - 0.4, pp.z + 0.5, 1.15), 50.0, 0.0],
	}
	for shot: String in shots:
		if only != "" and shot not in only.split(","):
			continue
		if only == "" and shot not in BG_USED.get(light, []):
			continue
		var sh: Array = shots[shot]
		if sh.is_empty():
			_view.camera.global_transform = game_xf
			_view.camera.fov = game_fov
		else:
			_view.camera.fov = sh[2]
			_view.camera.look_at_from_position(sh[0], sh[1])
			_view.camera.global_rotate(Vector3.UP, deg_to_rad(float(sh[3])))
		for settle in 40:
			await process_frame
			RenderingServer.force_draw(false)
		var img: Image = _view.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		var path := ProjectSettings.globalize_path(HELP_DIR + "bg_%s_%s.png" % [light, shot])
		img.save_png(path)
		print("A_CLEAN BG ", path)
	return true


func _probe() -> void:
	InputSetup.ensure()
	MatchSetup.element = "fire"
	MatchSetup.foes = ["water"]
	for el: String in ["fire", "water", "earth", "air"]:
		print("PASSIVE %s | %s" % [el, KitWords.passive_line(el)])
		print("GUARD %s | %s" % [el, KitWords.guard_line(el)])
		for l in KitWords.kit_lines(el, "", true):
			print("KIT %s | %s" % [el, l])
	print("CONTROLS_LINE | ", KitWords.w("controls_line"))
	print("QUICK | ", MatchSetup.quick_line())
	print("SPORT_LINE | ", MatchSetup.sport_line())
	print("RULES_LINE | ", MatchSetup.menu_word("rules_line"))
	print("AIM | ", MatchSetup.aim_row(), " | ", MatchSetup.aim_row_line())
	print("CAMERA | ", RingCamera.row_text(), " | ", RingCamera.row_line())
	print("HINTS | ", FirstHints.row_text(), " | ", FirstHints.row_line())
	print("REPLAYS | ", RingReplay.row_text(), " | ", RingReplay.row_line())
	print("OTHER WAYS | ", KitWords.other_ways_row(), " | ", KitWords.other_ways_line())
	print("CTRL ROW | ", MatchSetup.controls_row(), " | ", MatchSetup.controls_row_line())
	_end(0)


# =================================================================================================== the mock screens
## The style's one system: one serif (names, rows, headings) and one sans (lines, labels, keys), five sizes and nothing
## under 16 px at 1600 x 900, ink and gold over soft navy shade (no boxes), the focused row marked by a bar and a soft glow
## in the accent: the player's element colour (MatchSetup.color).
## The mock uses fonts installed on this Mac (SystemFont: Baskerville, Avenir Next); a real build would bundle the OFL pair
## named first in each list's fallbacks (Libre Baskerville, Nunito Sans).
const SERIF_NAMES := ["Baskerville", "Libre Baskerville", "Georgia", "serif"]
const SANS_NAMES := ["Avenir Next", "Nunito Sans", "Helvetica Neue", "sans-serif"]
const INK := Color("ece5d3")
const INK_HI := Color("fffaf0")
const DIM := Color("c6ccd0")
const FAINT := Color("9aa6b0")
const GOLD := Color("d6c08e")
const NAVY := Color("0c131e")
const T_DISPLAY := 72
const T_HEAD := 44
const T_ROW := 28
const T_BODY := 20
const T_SMALL := 16
const X0 := 104.0
const RIGHT := 1504.0
const DESIGN := Vector2(1600, 900)

const SPOT_SHADER := """
shader_type canvas_item;
// A soft shade with no edges: tint fading out from `center` over `radius` (both in the rect's UV).
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 0.8);
uniform vec2 center = vec2(0.0, 0.5);
uniform vec2 radius = vec2(1.0, 0.5);
uniform float power = 1.0;
uniform float left_scale = 1.0;
void fragment() {
	vec2 q = (UV - center) / radius;
	if (q.x < 0.0) { q.x *= left_scale; }
	float d = length(q);
	float a = pow(1.0 - smoothstep(0.0, 1.0, d), power);
	COLOR = vec4(tint.rgb, tint.a * a);
}
"""

const BACKDROP_SHADER := """
shader_type canvas_item;
// The ring frame behind a menu: softly out of focus where the words sit (left and/or right), a little darker and greyer
// there, sharp where the picture is left to show.
uniform vec2 texel = vec2(0.000625, 0.00111);
uniform float blur_l = 0.0;
uniform float blur_r = 0.0;
uniform vec2 left_mask = vec2(0.3, 0.62);
uniform vec2 right_mask = vec2(0.42, 0.72);
uniform float dark = 0.0;
uniform float desat = 0.0;
uniform vec4 spot = vec4(0.0, 0.0, 0.01, 0.01);
uniform float blur_s = 0.0;
void fragment() {
	float ml = 1.0 - smoothstep(left_mask.x, left_mask.y, UV.x);
	float mr = blur_r > 0.0 ? smoothstep(right_mask.x, right_mask.y, UV.x) : 0.0;
	float ms = blur_s > 0.0 ? 1.0 - smoothstep(0.45, 1.0, length((UV - spot.xy) / spot.zw)) : 0.0;
	float r = max(max(blur_l * ml, blur_r * mr), blur_s * ms);
	vec3 c;
	if (r < 0.6) {
		c = texture(TEXTURE, UV).rgb;
	} else {
		vec3 acc = vec3(0.0);
		float ws = 0.0;
		for (int i = 0; i < 72; i++) {
			float fi = float(i);
			float rad = sqrt((fi + 0.5) / 72.0) * r * 1.7;
			float ang = fi * 2.39996323;
			float w = exp(-(rad * rad) / (r * r));
			acc += texture(TEXTURE, UV + vec2(cos(ang), sin(ang)) * rad * texel).rgb * w;
			ws += w;
		}
		c = acc / ws;
	}
	float m = max(max(ml, mr), ms);
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(g), desat * m);
	COLOR = vec4(c * (1.0 - dark), 1.0);
}
"""

var accent := Color(1.0, 0.5, 0.22)
var _fonts := {}
var _spot_shader: Shader
var _bd_shader: Shader
var _labels: Array = []


func _ui() -> void:
	InputSetup.ensure()
	MatchSetup.element = "fire"
	MatchSetup.foes = ["water"]
	MatchSetup.difficulty = "normal"
	MatchSetup.light = "night"
	MatchSetup.dummy = "stand"
	MatchSetup.games_n = 3
	RingRules.rule_set_override = "stock"
	accent = MatchSetup.color(MatchSetup.element)
	_spot_shader = Shader.new()
	_spot_shader.code = SPOT_SHADER
	_bd_shader = Shader.new()
	_bd_shader.code = BACKDROP_SHADER
	var shots := [["main", Vector2i(1600, 900)], ["match", Vector2i(1600, 900)], ["pause", Vector2i(1600, 900)],
			["end", Vector2i(1600, 900)], ["main_720", Vector2i(1280, 720)], ["pause_720", Vector2i(1280, 720)]]
	for sh: Array in shots:
		if only != "" and not (String(sh[0]) in only.split(",")):
			continue
		await _shot(String(sh[0]), sh[1])
	RingRules.rule_set_override = ""
	_end(0)


func _shot(shot: String, px: Vector2i) -> void:
	_labels.clear()
	var vp := SubViewport.new()
	vp.size = px
	vp.msaa_2d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if px != Vector2i(DESIGN):
		vp.size_2d_override = Vector2i(DESIGN)
		vp.size_2d_override_stretch = true
	root.add_child(vp)
	var c := Control.new()
	c.size = DESIGN
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.add_child(c)
	match shot.trim_suffix("_720"):
		"main": _screen_main(c)
		"match": _screen_match(c)
		"pause": _screen_pause(c)
		"end": _screen_end(c)
	var mirror := TextureRect.new()
	mirror.texture = vp.get_texture()
	mirror.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mirror.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mirror.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(mirror)
	for i in 10:
		await process_frame
		RenderingServer.force_draw(false)
	var img: Image = vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := ProjectSettings.globalize_path(OUT_DIR + shot + ".png")
	img.save_png(path)
	# the check: every word's size (design px) and whether it leaves the screen or runs into another
	var least := 999
	var out := 0
	var rects: Array = []
	for l: Label in _labels:
		if l.autowrap_mode != TextServer.AUTOWRAP_OFF and l.text.length() > 80:
			print("A_CLEAN WRAP '%s' mode=%d size=%s min=%s lines=%d" % [l.text.left(20), l.autowrap_mode, l.size,
					l.get_combined_minimum_size(), l.get_line_count()])
		least = mini(least, l.get_theme_font_size("font_size"))
		var r := Rect2(l.global_position, l.size)
		if not Rect2(Vector2.ZERO, DESIGN).encloses(r):
			out += 1
			print("A_CLEAN OFF %s '%s' %s" % [shot, l.text.left(30), r])
		rects.append([r, l])
	var hits := 0
	for a in rects.size():
		for b in range(a + 1, rects.size()):
			var ra: Rect2 = rects[a][0]
			var rb: Rect2 = rects[b][0]
			if ra.grow(-3).intersects(rb.grow(-3)) and rects[a][1].get_parent() == rects[b][1].get_parent():
				hits += 1
				print("A_CLEAN OVERLAP %s '%s' / '%s'" % [shot, (rects[a][1] as Label).text.left(24), (rects[b][1] as Label).text.left(24)])
	print("A_CLEAN SHOT %s %s labels=%d least_px=%d off=%d overlaps=%d" % [path, px, _labels.size(), least, out, hits])
	mirror.queue_free()
	vp.queue_free()
	await process_frame


# ---------------------------------------------------------------- the pieces
func serif(weight := 400, spacing := 0, italic := false) -> Font:
	return _font(SERIF_NAMES, weight, spacing, italic)


func sans(weight := 400, spacing := 0) -> Font:
	return _font(SANS_NAMES, weight, spacing, false)


func _font(names: Array, weight: int, spacing: int, italic: bool) -> Font:
	var key := "%s|%d|%d|%s" % [names[0], weight, spacing, italic]
	if _fonts.has(key):
		return _fonts[key]
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.font_weight = weight
	f.font_italic = italic
	f.fallbacks = [ThemeDB.fallback_font]
	var out: Font = f
	if spacing != 0:
		var fv := FontVariation.new()
		fv.base_font = f
		fv.spacing_glyph = spacing
		out = fv
	_fonts[key] = out
	return out


func w_of(font: Font, size: int, t: String) -> float:
	return font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func text(parent: Control, t: String, font: Font, size: int, col: Color, pos: Vector2, width := 0.0,
		align := HORIZONTAL_ALIGNMENT_LEFT, shadow := 0.5) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if shadow > 0.0:
		var big := size >= T_ROW
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, shadow if big else shadow * 0.7))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 2 if big else 1)
		l.add_theme_constant_override("shadow_outline_size", 7 if big else 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = pos
	if width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = width
		l.size = Vector2(width, 0)
		l.horizontal_alignment = align
	parent.add_child(l)
	if width > 0.0:
		l.size = Vector2(width, 0)          # (again once in the tree: before it, a wrapped label grows to its one line)
		l.size = Vector2(width, wrapped_h(l))
	_labels.append(l)
	return l


## A label set by its right edge.
func text_r(parent: Control, t: String, font: Font, size: int, col: Color, right_x: float, y: float, shadow := 0.5) -> Label:
	return text(parent, t, font, size, col, Vector2(right_x - w_of(font, size, t), y), 0.0, HORIZONTAL_ALIGNMENT_LEFT, shadow)


## A wrapped label's height from its shaped lines (its minimum size is only brought up to date a frame later).
func wrapped_h(l: Label) -> float:
	var n := l.get_line_count()
	return n * l.get_line_height() + maxi(0, n - 1) * l.get_theme_constant("line_spacing")


func line_h(font: Font, size: int) -> float:
	return font.get_height(size)


func spot(parent: Control, rect: Rect2, tint: Color, center := Vector2(0, 0.5), radius := Vector2(1, 0.5), power := 1.0,
		left_scale := 1.0) -> ColorRect:
	var r := ColorRect.new()
	r.position = rect.position
	r.size = rect.size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = _spot_shader
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("center", center)
	m.set_shader_parameter("radius", radius)
	m.set_shader_parameter("power", power)
	m.set_shader_parameter("left_scale", left_scale)
	r.material = m
	parent.add_child(r)
	return r


## A shade from the left edge (`reach`: how far across, 0..1) or from the right (`from_right`).
func side_shade(parent: Control, a: float, reach: float, from_right := false, power := 1.25) -> void:
	spot(parent, Rect2(Vector2.ZERO, DESIGN), Color(NAVY, a), Vector2(1.0 if from_right else 0.0, 0.5),
			Vector2(reach, 1000.0), power)


## A thin rule fading out to the right.
func hairline(parent: Control, x: float, y: float, w: float, col := GOLD, a := 0.5) -> void:
	spot(parent, Rect2(x, y, w, 1), Color(col, a), Vector2(0, 0.5), Vector2(1, 1000), 1.0)


func backdrop(parent: Control, file: String, blur_l := 0.0, blur_r := 0.0, dark := 0.0, desat := 0.0,
		lmask := Vector2(0.28, 0.6), rmask := Vector2(0.42, 0.7), spot_uv := Vector4(0, 0, 0.01, 0.01), blur_s := 0.0) -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(HELP_DIR + file))
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = DESIGN
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = _bd_shader
	m.set_shader_parameter("texel", Vector2(1.0 / img.get_width(), 1.0 / img.get_height()))
	m.set_shader_parameter("blur_l", blur_l)
	m.set_shader_parameter("blur_r", blur_r)
	m.set_shader_parameter("left_mask", lmask)
	m.set_shader_parameter("right_mask", rmask)
	m.set_shader_parameter("dark", dark)
	m.set_shader_parameter("desat", desat)
	m.set_shader_parameter("spot", spot_uv)
	m.set_shader_parameter("blur_s", blur_s)
	tr.material = m
	parent.add_child(tr)


func kicker(parent: Control, t: String, pos: Vector2, col := GOLD, a := 0.85) -> Label:
	return text(parent, t.to_upper(), sans(600, 3), T_SMALL, Color(col, a), pos)


func bar(parent: Control, rect: Rect2, col: Color) -> void:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(minf(rect.size.x, rect.size.y) * 0.5))
	sb.anti_aliasing = true
	p.add_theme_stylebox_override("panel", sb)
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)


## A key drawn as a small outlined cap ("Esc", "LMB", "1"); returns its width.
func keycap(parent: Control, t: String, pos: Vector2, col := INK) -> float:
	var f := sans(600)
	var w := maxf(26.0, w_of(f, T_SMALL, t) + 16.0)
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(NAVY, 0.5)
	sb.border_color = Color(col, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.anti_aliasing = true
	p.add_theme_stylebox_override("panel", sb)
	p.position = pos
	p.size = Vector2(w, 27)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	var l := text(p, t, f, T_SMALL, col, Vector2(0, 2), w, HORIZONTAL_ALIGNMENT_CENTER, 0.0)
	_labels.erase(l)        # (inside its cap: checked with the cap)
	return w


## The keys' line at the lower right: [[key, word], ...].
func hints(parent: Control, items: Array, y := 838.0) -> void:
	var f := sans(500)
	var total := 0.0
	for it: Array in items:
		total += maxf(26.0, w_of(sans(600), T_SMALL, String(it[0])) + 16.0) + 10.0 + w_of(f, T_SMALL, String(it[1])) + 28.0
	var x := RIGHT - total + 28.0
	var sr := Rect2(x - 100, y - 50, DESIGN.x - x + 100, DESIGN.y - y + 50)     # (open to the screen's edges: no seam)
	spot(parent, sr, Color(NAVY, 0.6), Vector2(0.75, 0.75), Vector2(0.75, 0.75), 0.8)
	for it: Array in items:
		x += keycap(parent, String(it[0]), Vector2(x, y - 2), INK) + 10.0
		text(parent, String(it[1]), f, T_SMALL, DIM, Vector2(x, y))
		x += w_of(f, T_SMALL, String(it[1])) + 28.0


## A small word in a thin outline after a row's name ("NEW").
func tagmark(parent: Control, t: String, pos: Vector2, col: Color) -> void:
	var f := sans(600, 2)
	var w := w_of(f, T_SMALL, t) + 16.0
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, 0.14)
	sb.border_color = Color(col, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.anti_aliasing = true
	p.add_theme_stylebox_override("panel", sb)
	p.position = pos
	p.size = Vector2(w, 24)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	var l := text(p, t, f, T_SMALL, col.lerp(INK_HI, 0.2), Vector2(1, 0), w, HORIZONTAL_ALIGNMENT_CENTER, 0.0)
	_labels.erase(l)


## A menu row at `pos`: its name in the serif (and `value` after it in `value_col`: "Element:  Fire"), its line under it
## in the sans. state: "" | "focus" (the soft glow and the bar in the accent) | "open" (its panel open: the bar, the name in
## gold) | "dim" (another row's panel open). Returns its height.
func row(parent: Control, pos: Vector2, name: String, sub := "", state := "", value := "", value_col := INK, tag := "",
		width := 540.0, size := T_ROW) -> float:
	var fs := serif(400)
	var lh := line_h(fs, size)
	var sh := line_h(sans(400), T_SMALL) if sub != "" else 0.0
	var h := lh + sh
	var lit := state == "focus"
	if lit:
		var gx := maxf(0.0, pos.x - 170.0)
		var gw := pos.x + width + 40.0 - gx
		spot(parent, Rect2(gx, pos.y - 18, gw, h + 36), Color(accent, 0.36), Vector2((pos.x - 22.0 - gx) / gw, 0.5),
				Vector2(0.9, 0.5), 1.15, 6.0)
	if lit or state == "open":
		bar(parent, Rect2(pos.x - 22, pos.y + 6, 3, h - 10), accent if lit else Color(accent, 0.8))
	var a := 0.5 if state == "dim" else 1.0
	var ncol := INK_HI if lit else (GOLD if state == "open" else Color(INK, 0.9))
	text(parent, name, fs, size, Color(ncol, ncol.a * a), pos)
	var x := pos.x + w_of(fs, size, name)
	if value != "":
		text(parent, value, fs, size, Color(value_col, a), Vector2(x + 12, pos.y))
		x += 12 + w_of(fs, size, value)
	if tag != "":
		tagmark(parent, tag, Vector2(x + 16, pos.y + lh * 0.5 - 13), accent)
	if sub != "":
		text(parent, sub, sans(400), T_SMALL, Color(INK if lit else DIM, a * (0.95 if lit else 0.85)),
				Vector2(pos.x + 1, pos.y + lh - 3), width)
	return h


## An element's mark, drawn (our own shapes, no art from anywhere): a flame, a drop, two peaks, three winds.
class Glyph extends Control:
	var el := "fire"
	var col := Color.WHITE

	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.5
		var c := size * 0.5
		var lw := maxf(1.5, r * 0.15)
		match el:
			"fire":
				var outer := _drop(c + Vector2(-r * 0.08, r * 0.06), r * 0.94, 0.66, 0.34)
				_fill(outer, col)
				var inner := _drop(c + Vector2(r * 0.0, r * 0.4), r * 0.5, 0.62, 0.2)
				_fill(inner, col.lerp(Color(1.0, 0.93, 0.78), 0.6))
			"water":
				var d := _drop(c + Vector2(0, r * 0.04), r * 0.94, 0.76, 0.0)
				_fill(d, col)
				draw_arc(c + Vector2(0, r * 0.3), r * 0.42, deg_to_rad(105.0), deg_to_rad(165.0), 12,
						Color(1, 1, 1, 0.6), lw * 0.8, true)
			"earth":
				var small := PackedVector2Array([c + Vector2(-0.02, 0.74) * r, c + Vector2(0.5, -0.2) * r, c + Vector2(1.0, 0.74) * r])
				var big := PackedVector2Array([c + Vector2(-0.98, 0.74) * r, c + Vector2(-0.16, -0.82) * r, c + Vector2(0.62, 0.74) * r])
				_fill(small, col.darkened(0.28))
				_fill(big, col)
				draw_polyline(PackedVector2Array([c + Vector2(-0.16, -0.82) * r, c + Vector2(-0.02, -0.3) * r,
						c + Vector2(-0.26, 0.12) * r]), col.lightened(0.4), lw * 0.6, true)
			"air":
				for k in 3:
					var y := (float(k) - 1.0) * r * 0.56
					var x0 := (-0.98 + 0.22 * float(k % 2)) * r
					var x1 := (0.42 - 0.16 * float(k)) * r
					var rc := r * (0.3 - 0.04 * float(k))
					var pts := PackedVector2Array([c + Vector2(x0, y)])
					pts.append(c + Vector2(x1, y))
					for i in range(1, 19):
						var t := float(i) / 18.0
						var ang := PI * 0.5 - t * PI * 1.45
						var rr := rc * (1.0 - 0.35 * t)
						pts.append(c + Vector2(x1, y - rc) + Vector2(cos(ang), sin(ang)) * rr)
					draw_polyline(pts, col, lw, true)

	func _fill(pts: PackedVector2Array, k: Color) -> void:
		draw_colored_polygon(pts, k)
		var loop := pts.duplicate()
		loop.append(pts[0])
		draw_polyline(loop, k, 1.0, true)

	## A drop with its point at the top; `bend` leans the point to the right (a flame).
	static func _drop(c: Vector2, a: float, wide: float, bend: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		var n := 56
		for i in n:
			var t := TAU * float(i) / float(n)
			var x := a * wide * sin(t) * sin(t * 0.5)
			var y := -a * cos(t)
			var k := (a - y) / (2.0 * a)
			x += bend * a * pow(k, 3.0)
			pts.append(c + Vector2(x, y))
		return pts


func glyph(parent: Control, el: String, rect: Rect2, col: Color) -> void:
	var g := Glyph.new()
	g.el = el
	g.col = col
	g.position = rect.position
	g.size = rect.size
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(g)


# ---------------------------------------------------------------- the main menu's column (main, and match with its panel open)
func _main_rows() -> Array:
	var me := MatchSetup.element
	return [
		[MatchSetup.sport(), MatchSetup.menu_line(), "Play", ""],
		["Start here", "learn at your own pace, or play an easy match", "Play", ""],
		["Quick match", MatchSetup.quick_line(), "Play", ""],
		["Practice", MainMenu._practice_line(), "Play", ""],
		["Class & talents", "%s  ·  Boxing  ·  pick your class and spend your talents" % MatchSetup.label(me), "Fighter", "NEW"],
		["Your look", "the character creator: face, build and dress", "Fighter", ""],
		["Settings", "", "", ""],
		["Credits", "", "", ""],
		["Quit", "", "", ""],
	]


func _left_menu(c: Control, focus: String, open: String) -> void:
	var y := 56.0
	var tf := serif(400, 10)
	text(c, MainMenu.TITLE, tf, T_DISPLAY, INK, Vector2(X0 - 5, y), 0.0, HORIZONTAL_ALIGNMENT_LEFT, 0.6)
	y += line_h(tf, T_DISPLAY) - 6
	text(c, MainMenu.SUBTITLE, sans(500, 4), T_SMALL, GOLD, Vector2(X0, y))
	y += 30
	hairline(c, X0, y, 460, GOLD, 0.55)
	y += 30
	var group := "-"
	var footer: Array = []
	for r: Array in _main_rows():
		if String(r[2]) == "":
			footer.append(String(r[0]))
			continue
		if String(r[2]) != group:
			if group != "-":
				y += 14
			group = String(r[2])
			kicker(c, group, Vector2(X0, y), GOLD, 0.6 if open != "" else 0.8)
			y += 32
		var nm := String(r[0])
		var state := "focus" if nm == focus else ("open" if nm == open else ("dim" if open != "" else ""))
		y += row(c, Vector2(X0, y), nm, String(r[1]), state, "", INK, String(r[3])) + 12.0
	# Settings, Credits and Quit on one quiet line under a rule
	y += 10
	hairline(c, X0, y, 420, GOLD, 0.3)
	y += 22
	var x := X0
	for nm: String in footer:
		var state := "focus" if nm == focus else ("dim" if open != "" else "")
		row(c, Vector2(x, y), nm, "", state, "", INK, "", w_of(serif(400), T_ROW, nm) + 10.0)
		x += w_of(serif(400), T_ROW, nm) + 46.0


# ---------------------------------------------------------------- 1. the main menu
func _screen_main(c: Control) -> void:
	backdrop(c, "bg_night_hero_r.png", 10.0, 0.0, 0.04, 0.65)
	side_shade(c, 0.9, 0.64)
	spot(c, Rect2(0, 560, 1600, 340), Color(NAVY, 0.55), Vector2(0.5, 1.0), Vector2(1000, 1.0), 1.4)
	_left_menu(c, MatchSetup.sport(), "")
	text_r(c, "EARLY PLAYABLE DEMO  ·  IN DEVELOPMENT", sans(500, 2), T_SMALL, Color(FAINT, 0.9), RIGHT, 64)
	hints(c, [["↑ ↓", "Choose"], ["Enter", "Select"], ["Esc", "Back"]])


# ---------------------------------------------------------------- 2. the Tidebreak panel (match setup)
func _screen_match(c: Control) -> void:
	backdrop(c, "bg_night_hero_r.png", 10.0, 9.0, 0.08, 0.6, Vector2(0.28, 0.6), Vector2(0.4, 0.62))
	side_shade(c, 0.9, 0.6)
	side_shade(c, 0.9, 0.62, true, 1.0)
	_left_menu(c, "", MatchSetup.sport())
	var px := 820.0
	var pw := RIGHT - px
	var y := 62.0
	kicker(c, "The ring sport", Vector2(px, y))
	y += 26
	text(c, MatchSetup.sport(), serif(400), T_HEAD, INK, Vector2(px, y))
	y += line_h(serif(400), T_HEAD) + 4
	var lead := text(c, MatchSetup.sport_line(), sans(400), T_SMALL, DIM, Vector2(px, y), pw)
	y += lead.size.y + 26
	kicker(c, "Your element", Vector2(px, y), GOLD, 0.8)
	y += 40
	var tw := pw / 4.0
	for i in Bending.ELEMENTS.size():
		var el := String(Bending.ELEMENTS[i])
		_element_tile(c, el, Vector2(px + tw * i, y), tw, el == MatchSetup.element)
	y += 92
	var me := MatchSetup.element
	var mc := MatchSetup.color(me)
	text(c, "%s  ·  %s" % [MatchSetup.competitor(me), MatchSetup.style(me)], sans(500), T_SMALL, mc.lerp(INK, 0.3), Vector2(px, y), pw)
	y += 25
	text(c, KitWords.passive_line(me), sans(400), T_SMALL, INK, Vector2(px, y), pw)
	y += 38
	_kit_strip(c, me, Vector2(px, y), pw)
	y += 56
	# the match's settings: a press steps each (the focused one's line in the help line below)
	var cells := [
		["Opponent", MatchSetup.label(MatchSetup.foe()), MatchSetup.color(MatchSetup.foe())],
		["Difficulty", MatchSetup.difficulty, INK],
		["Rules", MatchSetup.rule_label(), INK],
		["Games", MatchSetup.games_label(), INK],
		["Light", MatchSetup.light, INK],
		["Controls", MatchSetup.controls_label(), INK],
	]
	var cw := pw / 3.0
	for i in cells.size():
		var cell: Array = cells[i]
		var cx := px + cw * (i % 3)
		var cy := y + 76.0 * (i / 3)
		text(c, String(cell[0]).to_upper(), sans(600, 2), T_SMALL, Color(FAINT, 0.95), Vector2(cx, cy))
		text(c, String(cell[1]), serif(400), T_ROW, cell[2], Vector2(cx, cy + 20))
		var vw := w_of(serif(400), T_ROW, String(cell[1]))
		text(c, "›", serif(400), T_ROW, Color(FAINT, 0.7), Vector2(cx + vw + 10, cy + 20))
	y += 160
	var summary := "%s against %s  ·  %s  ·  %s, %s  ·  %s" % [MatchSetup.label(me), MatchSetup.label(MatchSetup.foe()),
			MatchSetup.difficulty, MatchSetup.rule_label().to_lower(), MatchSetup.games_label(), MatchSetup.light]
	row(c, Vector2(px, y), "Begin", summary, "focus", "", INK, "", pw - 40, T_HEAD)
	keycap(c, "Enter", Vector2(px + w_of(serif(400), T_HEAD, "Begin") + 22, y + line_h(serif(400), T_HEAD) * 0.5 - 11), INK)
	hints(c, [["↑ ↓ ← →", "Choose"], ["Enter", "Change"], ["Esc", "Back"]])


func _element_tile(c: Control, el: String, pos: Vector2, w: float, chosen: bool) -> void:
	var col := MatchSetup.color(el)
	if chosen:
		spot(c, Rect2(pos.x - 40, pos.y - 34, 150, 120), Color(col, 0.42), Vector2(0.5, 0.5), Vector2(0.5, 0.5), 1.6)
	glyph(c, el, Rect2(pos.x, pos.y + 4, 44, 44), col if chosen else Color(col, 0.7))
	text(c, MatchSetup.label(el), serif(400), T_ROW, INK_HI if chosen else Color(INK, 0.78), Vector2(pos.x + 58, pos.y - 2))
	text(c, MatchSetup.competitor(el), sans(500), T_SMALL,
			Color(col.lerp(INK, 0.3), 1.0 if chosen else 0.75), Vector2(pos.x + 59, pos.y + 31))
	if chosen:
		bar(c, Rect2(pos.x, pos.y + 66, w - 26, 2), col)
	else:
		bar(c, Rect2(pos.x, pos.y + 66, w - 26, 1), Color(INK, 0.16))


## The element's buttons in a line: each key in its cap and the move's plain name (KitWords.kit_lines, the keys scheme).
func _kit_strip(c: Control, el: String, pos: Vector2, w: float) -> void:
	var pairs: Array = []
	for line: String in KitWords.kit_lines(el, "", true):
		for half: String in line.split("      ", false):
			var bits := Array(half.split("   ", false)).map(func(s: String) -> String: return s.replace("▲", "").strip_edges())
			if bits.size() >= 3:
				pairs.append([bits[0], String(bits[2]).get_slice("  ·  ", 0)])
	var f := sans(500)
	var total := 0.0
	for pr: Array in pairs:
		total += maxf(26.0, w_of(sans(600), T_SMALL, pr[0]) + 16.0) + 8.0 + w_of(f, T_SMALL, pr[1])
	var gap := clampf((w - total) / maxf(1.0, pairs.size() - 1.0), 12.0, 30.0)
	var x := pos.x
	for pr: Array in pairs:
		x += keycap(c, pr[0], Vector2(x, pos.y - 2), GOLD) + 8.0
		text(c, pr[1], f, T_SMALL, INK, Vector2(x, pos.y))
		x += w_of(f, T_SMALL, pr[1]) + gap


# ---------------------------------------------------------------- 3. the Esc menu in the ring
func _screen_pause(c: Control) -> void:
	backdrop(c, "bg_noon_behind.png", 11.0, 0.0, 0.36, 0.35, Vector2(0.24, 0.56))
	side_shade(c, 0.88, 0.6)
	var y := 80.0
	kicker(c, "Paused", Vector2(X0, y))
	y += 26
	text(c, RingMode.words("menu_title"), serif(400), T_HEAD, INK, Vector2(X0, y))
	y += line_h(serif(400), T_HEAD) + 2
	var score := RingMode.words("score") % [RingMode.words("you"), 1, 0, MatchSetup.competitor(MatchSetup.foe())]
	text(c, RingMode.words("menu_note") % [1, 6, 42, score], sans(500), T_BODY, GOLD, Vector2(X0, y))
	y += 58
	var me := MatchSetup.element
	var fo := MatchSetup.foe()
	var rows := [
		[RingMode.words("resume"), "", "", INK],
		[RingMode.words("restart"), RingMode.words("restart_line"), "", INK],
		["Element:", RingMode.words("element_line"), MatchSetup.label(me), MatchSetup.color(me).lerp(INK, 0.15)],
		["Opponent:", RingMode.words("opponent_line"), MatchSetup.label(fo), MatchSetup.color(fo).lerp(INK, 0.15)],
		["Options", "difficulty, rules, games, aim help, key hints, camera, screen jolt and replays", "", INK],
		[RingMode.words("controls"), KitWords.w("controls_line"), "", INK],
		[RingMode.words("main_menu"), "back to the title; a match is not saved", "", INK],
		[RingMode.words("quit"), "", "", INK],
	]
	for r: Array in rows:
		var st := "focus" if String(r[0]) == RingMode.words("resume") else ""
		y += row(c, Vector2(X0, y), String(r[0]), String(r[1]), st, String(r[2]), r[3], "", 640.0) + (12.0 if String(r[1]) != "" else 8.0)
	hints(c, [["Esc", "Resume"], ["↑ ↓", "Choose"], ["Enter", "Select"]])


# ---------------------------------------------------------------- 4. the match's end
func _screen_end(c: Control) -> void:
	backdrop(c, "bg_noon_hero_r.png", 10.0, 0.0, 0.14, 0.25, Vector2(0.28, 0.6), Vector2(0.42, 0.7),
			Vector4(0.87, 0.15, 0.22, 0.26), 9.0)
	side_shade(c, 0.9, 0.62)
	spot(c, Rect2(900, -80, 760, 560), Color(NAVY, 0.88), Vector2(0.86, 0.3), Vector2(0.62, 0.62), 0.9)
	var fo := MatchSetup.foe()
	var them := MatchSetup.competitor(fo)
	var y := 60.0
	kicker(c, "%s  ·  %s  ·  %s" % [MatchSetup.sport(), MatchSetup.rule_label(), MatchSetup.games_label()], Vector2(X0, y))
	y += 22
	text(c, MatchScreen.w("head_win"), serif(400, 2), T_DISPLAY, INK_HI, Vector2(X0 - 4, y), 0.0, HORIZONTAL_ALIGNMENT_LEFT, 0.6)
	y += line_h(serif(400), T_DISPLAY) - 2
	text(c, MatchScreen.w("line_win"), sans(500), T_BODY, DIM, Vector2(X0, y))
	y += 40
	# the score: You 2 : 1 Tide
	var sf := serif(400)
	var x := X0
	var base := y + line_h(sf, T_HEAD) - line_h(sf, T_ROW) - 4
	text(c, RingMode.words("you"), sf, T_ROW, INK, Vector2(x, base))
	x += w_of(sf, T_ROW, RingMode.words("you")) + 18
	text(c, "2", sf, T_HEAD, GOLD, Vector2(x, y))
	x += w_of(sf, T_HEAD, "2") + 14
	text(c, ":", sf, T_HEAD, Color(GOLD, 0.6), Vector2(x, y - 2))
	x += w_of(sf, T_HEAD, ":") + 14
	text(c, "1", sf, T_HEAD, Color(INK, 0.8), Vector2(x, y))
	x += w_of(sf, T_HEAD, "1") + 18
	text(c, them, sf, T_ROW, MatchSetup.color(fo).lerp(INK, 0.2), Vector2(x, base))
	y += line_h(sf, T_HEAD) + 16
	# a line for each game: whose, and the fall that ended it
	var games := [
		[1, "yours", "2:41", "the %s" % them, 131, "Fireball"],
		[2, "the %s's" % them, "4:05", "you", 104, "Geyser"],
		[3, "yours", "1:58", "the %s" % them, 118, "High Kick"],
	]
	var gf := sans(500)
	for g: Array in games:
		text(c, ("Game %d" % g[0]).to_upper(), sans(600, 2), T_SMALL, Color(FAINT, 0.95), Vector2(X0, y))
		text(c, String(g[1]), gf, T_SMALL, GOLD if String(g[1]) == "yours" else DIM, Vector2(X0 + 96, y))
		text(c, "%s  ·  %s into the water at %d%%  ·  %s" % [g[2], g[3], g[4], g[5]], sans(400), T_SMALL, DIM, Vector2(X0 + 196, y))
		y += 28
	y += 22
	# the tally in four numbers
	var stats := [["7", "falls dealt"], ["612%", "dealt in all"], ["6 hits", "longest string"], ["5", "catches, 3 clean"]]
	var sx := X0
	for st: Array in stats:
		text(c, String(st[0]), sf, T_ROW, INK_HI, Vector2(sx, y))
		text(c, String(st[1]), sans(400), T_SMALL, DIM, Vector2(sx + 1, y + line_h(sf, T_ROW) - 2))
		sx += 142
	y += 92
	var rows := [
		[MatchScreen.w("rematch"), MatchScreen.w("rematch_line"), "", INK, "focus"],
		["Your element:", MatchScreen.w("element_line"), MatchSetup.label(MatchSetup.element), MatchSetup.color(MatchSetup.element).lerp(INK, 0.15), ""],
		["Opponent:", MatchScreen.w("opponent_line"), MatchSetup.label(fo), MatchSetup.color(fo).lerp(INK, 0.15), ""],
		[MatchScreen.w("main_menu"), MatchScreen.w("main_menu_line"), "", INK, ""],
	]
	for r: Array in rows:
		y += row(c, Vector2(X0, y), String(r[0]), String(r[1]), String(r[4]), String(r[2]), r[3]) + 12
	_highlights(c, them)
	hints(c, [["↑ ↓", "Choose"], ["Enter", "Select"], ["W", "Watch"]])


## The match's best plays at the upper right, unboxed: what, who, the number, Watch.
func _highlights(c: Control, them: String) -> void:
	var x := 1130.0
	var w := RIGHT - x
	var y := 64.0
	kicker(c, "Highlights", Vector2(x, y))
	y += 36
	var plays := [
		["Biggest launch", "You sent the %s flying" % them, "17 m/s"],
		["Closest catch", "You caught it with no time to spare", "0.08 s"],
		["Fastest fall", "You put the %s in the water" % them, "4.8 s"],
	]
	var sf := serif(400)
	for i in plays.size():
		var p: Array = plays[i]
		text(c, String(p[0]), sf, T_ROW, INK, Vector2(x, y))
		text_r(c, String(p[2]), sf, T_ROW, GOLD, RIGHT, y)
		y += line_h(sf, T_ROW) - 2
		text(c, String(p[1]), sans(400), T_SMALL, DIM, Vector2(x + 1, y))
		text_r(c, "Watch", sans(600), T_SMALL, Color(GOLD, 0.9), RIGHT, y)
		_play_mark(c, Vector2(RIGHT - w_of(sans(600), T_SMALL, "Watch") - 16, y + 6), Color(GOLD, 0.9))
		y += 44
		if i < plays.size() - 1:
			hairline(c, x, y - 14, w, INK, 0.16)


func _play_mark(c: Control, pos: Vector2, col: Color) -> void:
	var g := Polygon2D.new()
	g.polygon = PackedVector2Array([Vector2(0, 0), Vector2(9, 5.5), Vector2(0, 11)])
	g.color = col
	g.position = pos
	c.add_child(g)
