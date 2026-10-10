extends SceneTree
## SUPERSEDED 2026-10-10: the owner chose style B (scripts/ui/menu/broadcast_ui.gd); kept as a reference mock-up, not wired into the game.
## UI audit, menu variant D: "Advancement-matched". A MOCK for the owner's lineup of four menu styles; nothing in the game
## loads it, and it edits no game file. The menus (the main menu, the Tidebreak match panel, the ring's Esc menu, the
## match-end screen) drawn in the family of the Character Advancement window the owner asked for (his reference clip:
## artifacts/ui_audit/reference): dark stone panels with a thin bronze trim and knot corners, red-brown button plates, a
## painted backdrop per element, so the menus and the skill tree read as one game. The fight HUD is out of scope.
##
## Our own art only:
##   backdrops  the ring itself (scenes/ring.tscn: RingLook's moods, RingDressing in the element's colours, the element's own
##              effect from BendZone / BendEffects / BendLooks), rendered off-window (tools/environment/offscreen_view.gd) and
##              oil-painted twice through shaders/ui/oil_paint.gdshader, as tools/menu/paint_views.gd paints the menu's
##              pictures; the in-match frames are the same renders unpainted, blurred and veiled
##   frame      hand-written SVG in tools/ui_audit/menu_variants/d_advancement/ (knot corners, the medallion, the red
##              plates, the crest, the row glyphs; SOURCE.md there) and the game's own icons (assets/ui/icons: the element
##              marks and the move glyphs)
##   type       fonts installed on this Mac through SystemFont (Optima, Copperplate, Gill Sans); the real build would bundle
##              Marcellus / Marcellus SC and Alegreya Sans (SIL OFL), the faces of the skill-tree mockup
## Every word is the game's own (MatchSetup, KitWords, RingCamera, RingReplay, Callouts, PhotoMode, FirstHints and
## data/ring/*.json, data/sway/skill_tree.json), plus the new entries: the Fighter area (Class & talents, Your look) and the
## Esc menu's Options group.
##
## Windowed (it draws), through the lock wrapper only:
##   GODOT_TIMEOUT=600 zsh tools/loop/godot_run.sh --path . --resolution 1600x900 \
##       -s tools/ui_audit/menu_variants/d_advancement.gd -- [backdrops=cache] [only=main,match,pause,end,sheet]
## Writes artifacts/ui_audit/menu_variants/d_advancement/: main.png, match.png, pause.png, end.png (1600 x 900),
## main_720.png and pause_720.png (1280 x 720), backdrops.png (the four painted backdrops) and backdrops/*.jpg (the renders,
## read back with backdrops=cache). The player's settings are not touched (its own settings file, deleted after; the
## user://how_to.cfg restored byte for byte). Ends with "D_ADVANCEMENT DONE".

const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const ART := "res://tools/ui_audit/menu_variants/d_advancement/"
const OUT := "res://artifacts/ui_audit/menu_variants/d_advancement/"
const OWN_CFG := "user://ui_audit_d_settings.cfg"
const HOWTO := "user://how_to.cfg"

# ---------------------------------------------------------------- the look's tokens (AdvancementTheme in the build plan)
const STONE_HI := Color("1f242e")
const STONE_LO := Color("0e1116")
const EDGE := Color("363d4a")
const BRONZE := Color("a8844a")
const BRONZE_HI := Color("d7b26a")
const GOLD := Color("e6c987")
const GOLD_HI := Color("fbe6b0")
const PLATE_TXT := Color("ffd98a")
const INK := Color("efeadc")
const MUTED := Color("a3aab4")
const FAINT := Color("737b87")
const GREEN := Color("62dd5a")
const MINUS := Color("f07d68")
const SHADE := Color("07090d")

## Which painting stands behind which screen (the main menu: the player's element; the match panel: the element in focus).
var main_bd := "fire_night"
var match_bd := "water_night"
var pause_bd := "ring_noon_behind"
var end_bd := "ring_night_corner"
## The four the sheet shows, one per element.
var sheet_bd := ["earth_golden", "water_night", "fire_night", "air_noon"]

## The element renders: name, element, RingLook mood.
## The element renders: name, element, RingLook mood, the painter's lift (under 1 lifts the midtones: the night's darks read;
## the bright moods keep theirs).
const EL_SHOTS := [
	["fire_night", "fire", "night", 0.8],
	["water_night", "water", "night", 0.8],
	["earth_golden", "earth", "golden", 1.0],
	["air_noon", "air", "noon", 1.15],
	["fire_golden", "fire", "golden", 1.0],
]
## Their camera (the ring's own space: x along the deck, the player's end at -x): low on the near deck looking down it, the
## effect some 13 m off in the middle gap between the menu's two panels, the far stands and the gate behind it.
const EL_FROM := Vector3(-11.5, 1.55, 3.1)
const EL_AT := Vector3(3.0, 2.45, -0.8)
const EL_FOV := 55.0
const EL_SPOT := Vector3(-1.2, 0.0, -0.3)
## The in-match frames: name, mood, from, at, fov (both competitors at their ends, the HUD not drawn).
const FRAMES := [
	["ring_noon_behind", "noon", Vector3(-16.5, 2.6, 3.4), Vector3(8.0, 1.2, -0.8), 58.0],
	["ring_golden_low", "golden", Vector3(-9.0, 1.1, 8.5), Vector3(3.0, 1.6, -1.0), 60.0],
	["ring_golden_stand", "golden", Vector3(-3.0, 6.2, 17.5), Vector3(0.5, 0.6, -1.0), 50.0],
	["ring_night_corner", "night", Vector3(-24.0, 9.0, 16.0), Vector3(1.0, 0.0, 0.0), 52.0],
]

const TITLE_SHADER := """
shader_type canvas_item;
// The carved gold of a title: the fill (drawn white) takes a metal ramp top to bottom with a bright band where the edge
// catches the light; the outline and the shadow keep their own colours.
uniform vec4 c_top : source_color = vec4(1.0, 0.96, 0.82, 1.0);
uniform vec4 c_mid : source_color = vec4(0.88, 0.72, 0.42, 1.0);
uniform vec4 c_bot : source_color = vec4(0.52, 0.37, 0.16, 1.0);
uniform float y0 = 0.0;
uniform float y1 = 100.0;
varying float vy;
void vertex() { vy = VERTEX.y; }
void fragment() {
	vec4 c = COLOR;
	if (c.r > 0.95 && c.g > 0.95 && c.b > 0.95) {
		float t = clamp((vy - y0) / max(y1 - y0, 1.0), 0.0, 1.0);
		vec3 g = t < 0.5 ? mix(c_top.rgb, c_mid.rgb, t * 2.0) : mix(c_mid.rgb, c_bot.rgb, (t - 0.5) * 2.0);
		g += vec3(0.20, 0.16, 0.08) * smoothstep(0.07, 0.0, abs(t - 0.46));
		c.rgb = g;
	}
	COLOR = c;
}
"""

const BLUR_SHADER := """
shader_type canvas_item;
// The ring behind an in-match menu: a little softened and darkened, so the window reads over it.
uniform float lod = 1.2;
uniform float spread = 2.5;
uniform float darken = 0.3;
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * spread;
	vec3 c = textureLod(TEXTURE, UV, lod).rgb * 0.28;
	c += textureLod(TEXTURE, UV + vec2(px.x, 0.0), lod).rgb * 0.12;
	c += textureLod(TEXTURE, UV - vec2(px.x, 0.0), lod).rgb * 0.12;
	c += textureLod(TEXTURE, UV + vec2(0.0, px.y), lod).rgb * 0.12;
	c += textureLod(TEXTURE, UV - vec2(0.0, px.y), lod).rgb * 0.12;
	c += textureLod(TEXTURE, UV + px, lod).rgb * 0.06;
	c += textureLod(TEXTURE, UV - px, lod).rgb * 0.06;
	c += textureLod(TEXTURE, UV + vec2(px.x, -px.y), lod).rgb * 0.06;
	c += textureLod(TEXTURE, UV + vec2(-px.x, px.y), lod).rgb * 0.06;
	COLOR = vec4(c * (1.0 - darken), 1.0);
}
"""

var out := ""
var render_bd := true
var repaint := false
var only: Array = []
var bd := {}                 ## name -> Image (the renders and the paintings)
var fonts := {}
var grain: Texture2D
var paint_noise: Array = []
var title_shader: Shader
var blur_shader: Shader
var k := 1.0                 ## the screen's scale against the 1600 x 900 design
var _svg_src := {}
var _tex := {}
var _grads := {}
var _made: Array[Node] = []
var _mirror: TextureRect


func _initialize() -> void:
	out = ProjectSettings.globalize_path(OUT)
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		var v := kv.get_slice("=", 1)
		match kv.get_slice("=", 0):
			"out": out = v
			"backdrops": render_bd = v != "cache"
			"repaint": repaint = v != "0"
			"only": only = Array(v.split(",", false))
	if not CaptureKit.begin(self, "d_advancement", out.path_join("backdrops"), true):
		return
	AudioServer.set_bus_mute(0, true)
	CaptureKit.keep([HOWTO])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = OWN_CFG
	MatchSetup.reload_scheme()
	InputSetup.ensure()
	MatchSetup.element = "fire"
	if render_bd:
		MatchSetup.incoming = true
		MatchSetup.light = "noon"
		MatchSetup.set_practice("water", "stand")
		change_scene_to_file("res://scenes/ring.tscn")
	create_timer(560.0, true, false, true).timeout.connect(func() -> void:
		print("D_ADVANCEMENT watchdog")
		_end(2))
	_run.call_deferred()


func _end(code := 0) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	CaptureKit.restore([HOWTO])
	print("D_ADVANCEMENT DONE code=%d" % code)
	quit(code)


func _frames(n: int) -> void:
	await CaptureKit.frames(self, n)


func _run() -> void:
	_load_art()
	if render_bd:
		if not await _render_ring():
			_end(1)
			return
	else:
		for f in DirAccess.get_files_at(out.path_join("backdrops")):
			if f.ends_with(".jpg"):
				var img := Image.load_from_file(out.path_join("backdrops").path_join(f))
				if img != null:
					bd[f.get_basename()] = img
		print("backdrops from the cache: ", bd.keys())
		if repaint:
			for s: Array in EL_SHOTS:
				var raw: Image = bd.get(String(s[0]) + "_raw", null)
				if raw != null:
					_keep(String(s[0]), await _paint(raw, float(s[3])))
	_mirror_layer()
	var jobs := [["main", 1600, 900], ["match", 1600, 900], ["pause", 1600, 900], ["end", 1600, 900],
			["main", 1280, 720], ["pause", 1280, 720], ["sheet", 1600, 900]]
	for j: Array in jobs:
		if not only.is_empty() and not (String(j[0]) in only):
			continue
		await _shot(String(j[0]), int(j[1]), int(j[2]))
	_end(0)


# ================================================================ the art: fonts, grain, SVG, gradients
func _font(names: Array, weight := 400, spacing := 0) -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.font_weight = weight
	f.fallbacks = [ThemeDB.fallback_font]
	if spacing == 0:
		return f
	var v := FontVariation.new()
	v.base_font = f
	v.spacing_glyph = spacing
	return v


func _load_art() -> void:
	var disp := ["Optima", "Marcellus", "Palatino", "Georgia"]
	var body := ["Seravek", "Alegreya Sans", "Gill Sans", "Avenir Next"]
	fonts = {
		"disp": _font(disp, 400),
		"disp_b": _font(disp, 700),
		"title": _font(["Optima", "Marcellus SC", "Palatino"], 700, 7),
		"strip": _font(["Optima", "Marcellus SC", "Palatino"], 700, 2),
		"caps": _font(["Copperplate", "Marcellus SC", "Optima"], 400, 2),
		"body": _font(body, 400),
		"body_sb": _font(body, 500),
	}
	# the stone's grain: a soft mottle laid over every panel
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = 1765
	n.frequency = 0.018
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 5
	var gi := n.get_seamless_image(256, 256)
	gi.convert(Image.FORMAT_RGBA8)
	grain = ImageTexture.create_from_image(gi)
	# the painter's noises (tools/menu/paint_views.gd: the hand's wobble twice, the canvas and the bristles)
	for i in 3:
		var fn := FastNoiseLite.new()
		fn.seed = 11 + i * 7
		fn.frequency = 0.02 if i < 2 else 0.09
		var im := fn.get_seamless_image(256, 256)
		im.convert(Image.FORMAT_RGBA8)
		paint_noise.append(ImageTexture.create_from_image(im))
	title_shader = Shader.new()
	title_shader.code = TITLE_SHADER
	blur_shader = Shader.new()
	blur_shader.code = BLUR_SHADER


## An SVG drawn at `px` wide: "i:<name>" a row glyph of ours, "m:<element>" the element's mark, "s:<move>__<mode>" a move's
## icon (assets/ui/icons), or a frame piece by its file name.
func _svg(spec: String, px: float) -> Texture2D:
	var key := "%s@%d" % [spec, roundi(px)]
	if _tex.has(key):
		return _tex[key]
	var path := ART + spec + ".svg"
	if spec.begins_with("i:"):
		path = ART + "icon_" + spec.substr(2) + ".svg"
	elif spec.begins_with("m:"):
		path = "res://assets/ui/icons/spell_mark__%s.svg" % spec.substr(2)
	elif spec.begins_with("s:"):
		path = "res://assets/ui/icons/spell_%s.svg" % spec.substr(2)
	if not _svg_src.has(path):
		_svg_src[path] = FileAccess.get_file_as_string(path)
	var src := String(_svg_src[path])
	var base := 64.0
	var rx := RegEx.create_from_string("width=\"([0-9.]+)\"")
	var m := rx.search(src)
	if m != null:
		base = float(m.get_string(1))
	var img := Image.new()
	if src == "" or img.load_svg_from_string(src, maxf(px, 4.0) / base) != OK:
		push_error("d_advancement: no svg " + path)
		img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t


## A gradient texture, cached: vertical (top to bottom), horizontal (left to right) or radial (centre out).
func _grad(kind: String, a: Color, b: Color, mid := -1.0, mid_col := Color.TRANSPARENT) -> Texture2D:
	var key := "%s|%s|%s|%.2f|%s" % [kind, a.to_html(), b.to_html(), mid, mid_col.to_html()]
	if _grads.has(key):
		return _grads[key]
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	if mid >= 0.0:
		g.add_point(mid, mid_col)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 128
	t.height = 128
	match kind:
		"v":
			t.fill_from = Vector2(0, 0)
			t.fill_to = Vector2(0, 1)
		"h":
			t.fill_from = Vector2(0, 0)
			t.fill_to = Vector2(1, 0)
		"r":
			t.fill = GradientTexture2D.FILL_RADIAL
			t.fill_from = Vector2(0.5, 0.5)
			t.fill_to = Vector2(1.0, 0.5)
	_grads[key] = t
	return t


func _p(v: float) -> float:
	return v * k


## A font size at this scale, never under 12 px for a size that was 12 or more.
func _fs(s: float) -> int:
	return maxi(roundi(s * k), mini(roundi(s), 12))


# ================================================================ the ring: the backdrops and the in-match frames
func _render_ring() -> bool:
	await _frames(4)
	var lvl := current_scene as RingLevel
	if lvl == null:
		print("D_ADVANCEMENT: no ring")
		return false
	await CaptureKit.wait_loaded(self, lvl)
	var view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(1600, 900))
	root.disable_3d = true
	if lvl.environment_rig != null:
		lvl.environment_rig.follow_camera = view.camera
		if lvl.environment_rig.get_camera_attributes() != null:
			lvl.environment_rig.get_camera_attributes().auto_exposure_speed = 30.0
	if lvl.player != null and lvl.player.hud != null:
		lvl.player.hud.visible = false
	await _frames(120)
	var ring: Node3D = lvl.ring
	var dressing := RingDressing.find_in(lvl)
	var foe: Node3D = lvl.mode.get("foe") as Node3D if lvl.mode != null else null
	if dressing != null:
		dressing.set_sides("fire", "water")
	for f: Array in FRAMES:
		RingLook.apply(lvl, String(f[1]))
		_aim(view, ring, f[2], f[3], float(f[4]))
		await _frames(75)
		var img: Image = await _grab(view)
		_keep(String(f[0]), img)
	# (both competitors out of sight and parked at the far end, out of the effects' way: nothing is hit, so no fall's slow
	# beat or replay starts under the shots)
	if foe != null:
		foe.visible = false
		foe.global_position = ring.to_global(Vector3(14.5, 0.1, -5.0)) if ring != null else foe.global_position
	if lvl.player != null:
		lvl.player.visible = false
		lvl.player.global_position = ring.to_global(Vector3(14.5, 0.1, 5.0)) if ring != null else lvl.player.global_position
		lvl.player.velocity = Vector3.ZERO
	for s: Array in EL_SHOTS:
		var el := String(s[1])
		Engine.time_scale = 1.0
		RingLook.apply(lvl, String(s[2]))
		if dressing != null:
			dressing.set_sides(el, el)
		_aim(view, ring, EL_FROM, EL_AT, EL_FOV)
		await _frames(60)
		await _effect(lvl, ring, el)
		var img: Image = _grab_now(view)
		_keep(String(s[0]) + "_raw", img)
		var painted: Image = await _paint(img, float(s[3]))
		_keep(String(s[0]), painted)
		await _clear()
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for c in root.get_children():
		if c is CanvasLayer and c.name == "OffscreenMirror":
			(c as CanvasLayer).visible = false
	lvl.process_mode = Node.PROCESS_MODE_DISABLED
	return true


func _aim(view: Variant, ring: Node3D, from: Vector3, at: Vector3, fov: float) -> void:
	var a: Vector3 = ring.to_global(from) if ring != null else from
	var b: Vector3 = ring.to_global(at) if ring != null else at
	var cam: Camera3D = view.camera
	cam.fov = fov
	cam.global_transform = Transform3D(Basis.looking_at(b - a, Vector3.UP), a)


func _grab(view: Variant) -> Image:
	# (a window the Mac stops drawing leaves the view stale: drawn by force, as tools/ring/ring_still.gd does)
	for i in 8:
		RenderingServer.force_draw(false)
		await process_frame
	var img: Image = (view as SubViewport).get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


## The view drawn now and read back at once (the effect's bolts where they are this instant; nothing is slowed or stopped).
func _grab_now(view: Variant) -> Image:
	RenderingServer.force_draw(false)
	var img: Image = (view as SubViewport).get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


func _keep(name: String, img: Image) -> void:
	bd[name] = img
	img.save_jpg(out.path_join("backdrops").path_join(name + ".jpg"), 0.92)
	print("  backdrop ", name, " ", img.get_size())


func _dummy(at: Vector3) -> Node3D:
	var d := Node3D.new()
	d.name = "MenuMockFxBy"
	current_scene.add_child(d)
	d.global_position = at
	_made.append(d)
	return d


## The element's own signature effect in the middle of the deck, facing the camera, with its bolts in the middle of the view
## when this returns (the caller grabs at once): fire a Fire Wall and a burning line,
## water a Water Wall with two streams across it, earth an arc of three raised slabs and a Column with a boulder over them,
## air a tornado with two gusts.
func _effect(lvl: RingLevel, ring: Node3D, el: String) -> void:
	var spot: Vector3 = ring.to_global(EL_SPOT) if ring != null else EL_SPOT
	var cam: Vector3 = ring.to_global(EL_FROM) if ring != null else EL_FROM
	var toward := Vector3(cam.x - spot.x, 0.0, cam.z - spot.z).normalized()
	var side := Vector3.UP.cross(toward).normalized()
	var by := _dummy(spot + toward * 3.0)
	var flying: Array = []          # [spec, offset across, height, distance ahead of the camera's side of the effect]
	match el:
		"fire":
			BendZone.make(by, "fire_wall", spot, {"width_m": 6.5, "height_m": 2.8, "thick_m": 0.6, "life_s": 60.0}, toward)
			BendZone.make(by, "burn", spot + toward * 4.2 - side * 2.2, {"width_m": 1.2, "height_m": 0.4, "thick_m": 4.5,
					"life_s": 60.0}, side)
			await _frames(70)
		"water":
			# the Geyser (BendLooks.spout: its column at its peak at once), a second smaller one behind, its splash, and two
			# streams of water across it
			BendLooks.spout(spot, 2.8, 0.02)
			BendLooks.spout(spot, 2.2, 0.2)
			BendLooks.spout(spot - toward * 2.5 + side * 2.8, 1.6, 0.25)
			BendLooks.burst(spot + toward * 0.4 + Vector3.UP * 0.2, "water", 30, Vector3.UP, 75.0, 4.5)
			flying = [[{"kind": "water", "mps": 30.0, "gravity": 0.0, "radius_m": 0.26, "range_m": 40.0}, 0.0, 2.0, 2.4],
					[{"kind": "water", "mps": 30.0, "gravity": 0.0, "radius_m": 0.18, "range_m": 40.0}, -3.0, 1.2, 3.2]]
			await create_timer(0.42, true, false, false).timeout
		"earth":
			# the Column in front, two slabs raised behind it, the dust of the rise, a boulder over them
			for i: int in [-1, 1]:
				var face := (toward - side * (0.45 * i)).normalized()
				var p := spot + side * (2.9 * i) - toward * 1.6
				var x := Vector3.UP.cross(face).normalized()
				BendEffects._wall(by, Transform3D(Basis(x, Vector3.UP, face), p), "earth", 60.0)
			if lvl.player != null:
				BendEffects.column(lvl.player, spot + toward * 0.6, {})
			BendLooks.burst(spot + toward * 1.2, "stone", 34, Vector3.UP, 80.0, 3.5)
			flying = [[{"kind": "stone", "mps": 26.0, "gravity": 0.0, "radius_m": 0.45, "range_m": 40.0}, 1.0, 3.4, 2.0]]
			await _frames(90)
		"air":
			BendZone.make(by, "tornado", spot, {"radius_m": 3.0, "life_s": 60.0, "mps": 0.0}, toward)
			var o2 := _dummy(spot - toward * 1.5 - side * 4.2 + Vector3.UP * 1.0)
			BendZone.make(o2, "air_shield", o2.global_position, {"radius_m": 1.6, "life_s": 60.0}, toward)
			flying = [[{"kind": "air", "mps": 28.0, "radius_m": 0.4, "range_m": 40.0}, 0.0, 1.8, 3.0],
					[{"kind": "air", "mps": 28.0, "radius_m": 0.2, "range_m": 40.0, "long": true}, -3.0, 1.1, 3.8]]
			await _frames(80)
	if not flying.is_empty():
		# left to right across the effect: each started `travel` back so it is in the middle when the scene stops
		var travel := 7.5
		var mps := float((flying[0][0] as Dictionary).mps)
		for f: Array in flying:
			var at := spot + toward * float(f[3]) + Vector3.UP * float(f[2]) - side * (travel - float(f[1]))
			BendBolt.launch(by, at, side, f[0])
		await create_timer(travel / mps, true, false, false).timeout


func _clear() -> void:
	for b in get_nodes_in_group(BendBolt.GROUP):
		(b as BendBolt).end("menu_mock")
	for z in get_nodes_in_group(BendZone.GROUP):
		(z as BendZone).end()
	for w in get_nodes_in_group(FormRaised.GROUP):
		(w as Node).queue_free()
	for n in _made:
		if is_instance_valid(n):
			n.queue_free()
	_made.clear()
	await _frames(150)


## The two passes of tools/menu/paint_views.gd: broad masses, then the strokes, the canvas and the varnish.
func _paint(img: Image, lift := 0.8) -> Image:
	var first: Image = await _pass(ImageTexture.create_from_image(img), img.get_size(), 6, false, lift)
	return await _pass(ImageTexture.create_from_image(first), img.get_size(), 3, true, lift)


func _pass(t: Texture2D, size: Vector2i, brush: int, finish: bool, lift := 0.8) -> Image:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var rect := TextureRect.new()
	rect.texture = t
	rect.size = Vector2(size)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ui/oil_paint.gdshader")
	mat.set_shader_parameter("noise_a", paint_noise[0])
	mat.set_shader_parameter("noise_b", paint_noise[1])
	mat.set_shader_parameter("noise_c", paint_noise[2])
	mat.set_shader_parameter("brush", brush)
	mat.set_shader_parameter("finish", finish)
	mat.set_shader_parameter("lift", lift)
	rect.material = mat
	vp.add_child(rect)
	root.add_child(vp)
	for i in 8:
		RenderingServer.force_draw(false)
		await process_frame
	var o := vp.get_texture().get_image()
	o.convert(Image.FORMAT_RGB8)
	vp.queue_free()
	return o


# ================================================================ a screen: built in its own viewport, then saved
func _mirror_layer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 127
	_mirror = TextureRect.new()
	_mirror.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mirror.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_mirror.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_mirror)
	root.add_child(layer)


func _shot(name: String, w: int, h: int) -> void:
	k = minf(w / 1600.0, h / 900.0)
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var ui := Control.new()
	ui.size = Vector2(w, h)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.add_child(ui)
	match name:
		"main": _build_main(ui)
		"match": _build_match(ui)
		"pause": _build_pause(ui)
		"end": _build_end(ui)
		"sheet": _build_sheet(ui)
	if _mirror != null:
		_mirror.texture = vp.get_texture()
	await _frames(6)
	for i in 4:
		RenderingServer.force_draw(false)
		await process_frame
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var file := ("backdrops" if name == "sheet" else name) + ("" if h == 900 else "_%d" % h) + ".png"
	img.save_png(out.path_join(file))
	print("shot ", file, " ", img.get_size())
	if _mirror != null:
		_mirror.texture = null
	vp.queue_free()
	await _frames(2)


# ================================================================ the pieces
func _box(parent: Control, x: float, y: float, w: float, h: float, draw: Callable = Callable()) -> Control:
	var c := Control.new()
	c.position = Vector2(_p(x), _p(y))
	c.size = Vector2(_p(w), _p(h))
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	if draw.is_valid():
		c.draw.connect(draw.bind(c))
	parent.add_child(c)
	return c


func _text(parent: Control, x: float, y: float, text: String, font: String, size: float, col: Color, w := 0.0,
		align := HORIZONTAL_ALIGNMENT_LEFT, wrap := false, shadow := true, clip := false) -> Label:
	var l := Label.new()
	# (wrap and clip before the text and the width: a label sized to its unwrapped text first never shrinks back)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if clip:
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.add_theme_font_override("font", fonts[font])
	l.add_theme_font_size_override("font_size", _fs(size))
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("line_spacing", roundi(_p(-1.0)))
	if shadow:
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", maxi(1, roundi(_p(2.0))))
		l.add_theme_constant_override("shadow_outline_size", maxi(1, roundi(_p(3.0))))
	l.horizontal_alignment = align
	l.text = text
	if w > 0.0:
		l.custom_minimum_size = Vector2(_p(w), 0)
	l.position = Vector2(_p(x), _p(y))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	if w > 0.0:
		l.size = Vector2(_p(w), 0)
	return l


## A line of runs in their own colours, one after another ("+ Speed" green, "- Reach" red): returns its width (design px).
func _runs(parent: Control, x: float, y: float, runs: Array, font: String, size: float, gap := 14.0) -> float:
	var f: Font = fonts[font]
	var cx := x
	for r: Array in runs:
		_text(parent, cx, y, String(r[0]), font, size, r[1])
		cx += f.get_string_size(String(r[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(size)).x / k + gap
	return cx - x - gap


## A title in carved gold (TIDEBREAK, VICTORY): the fill ramps like metal, a dark outline, a deep soft shadow.
func _carved(parent: Control, x: float, y: float, w: float, text: String, size: float) -> Label:
	var l := _text(parent, x, y, text, "title", size, Color.WHITE, w, HORIZONTAL_ALIGNMENT_CENTER, false, false)
	l.add_theme_color_override("font_outline_color", Color("2a1906"))
	l.add_theme_constant_override("outline_size", maxi(2, roundi(_p(5.0))))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", roundi(_p(5.0)))
	l.add_theme_constant_override("shadow_outline_size", roundi(_p(14.0)))
	var f: Font = fonts.title
	var fs := _fs(size)
	var asc := f.get_ascent(fs)
	var mat := ShaderMaterial.new()
	mat.shader = title_shader
	mat.set_shader_parameter("y0", asc - fs * 0.70)
	mat.set_shader_parameter("y1", asc)
	l.material = mat
	return l


func _diamond(c: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)])
	c.draw_colored_polygon(pts, col)
	var cl := pts.duplicate()
	cl.append(pts[0])
	c.draw_polyline(cl, Color(0, 0, 0, 0.9), 1.0, true)


func _glow(c: CanvasItem, r: Rect2, col: Color, size: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, 0.0)
	sb.shadow_color = col
	sb.shadow_size = maxi(1, roundi(size))
	sb.set_corner_radius_all(maxi(1, roundi(_p(3.0))))
	c.draw_style_box(sb, r)


func _knots(c: CanvasItem, r: Rect2, size: float) -> void:
	var s := _p(size)
	var t := _svg("knot_corner", s)
	var off := -3.5 * s / 96.0
	for i in 4:
		var fx := -1.0 if (i == 1 or i == 2) else 1.0
		var fy := -1.0 if i >= 2 else 1.0
		var org := Vector2(r.position.x + (r.size.x if fx < 0.0 else 0.0), r.position.y + (r.size.y if fy < 0.0 else 0.0))
		c.draw_set_transform(org, 0.0, Vector2(fx, fy))
		c.draw_texture_rect(t, Rect2(Vector2(off, off), Vector2(s, s)), false)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The title plate on a window's top edge: pointed ends, bronze-edged, the name in spaced gold capitals.
func _strip(c: CanvasItem, ctr: Vector2, text: String, size := 15.0) -> void:
	var f: Font = fonts.strip
	var fs := _fs(size)
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var h := _p(32.0)
	var w := tw + _p(84.0)
	var x0 := ctr.x - w * 0.5
	var x1 := ctr.x + w * 0.5
	var top := ctr.y - h * 0.5
	var bot := ctr.y + h * 0.5
	var pts := PackedVector2Array([Vector2(x0, ctr.y), Vector2(x0 + h * 0.55, top), Vector2(x1 - h * 0.55, top),
			Vector2(x1, ctr.y), Vector2(x1 - h * 0.55, bot), Vector2(x0 + h * 0.55, bot)])
	var cols := PackedColorArray([Color("1b1f27"), Color("2a303b"), Color("2a303b"), Color("1b1f27"), Color("0c0e12"),
			Color("0c0e12")])
	_glow(c, Rect2(x0 + h * 0.4, top, w - h * 0.8, h), Color(0, 0, 0, 0.6), _p(10.0))
	c.draw_polygon(pts, cols)
	var cl := pts.duplicate()
	cl.append(pts[0])
	c.draw_polyline(cl, Color(0, 0, 0, 0.95), maxf(2.0, _p(4.0)), true)
	c.draw_polyline(cl, BRONZE, maxf(1.0, _p(1.7)), true)
	var inner := PackedVector2Array()
	for p in cl:
		inner.append(ctr + (p - ctr) * Vector2((w - _p(10.0)) / w, (h - _p(8.0)) / h))
	c.draw_polyline(inner, Color(BRONZE_HI, 0.25), 1.0, true)
	_diamond(c, Vector2(x0 + _p(20.0), ctr.y), _p(3.6), BRONZE_HI)
	_diamond(c, Vector2(x1 - _p(20.0), ctr.y), _p(3.6), BRONZE_HI)
	var base := ctr.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5
	c.draw_string(f, Vector2(ctr.x - tw * 0.5, base + _p(1.5)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.8))
	c.draw_string(f, Vector2(ctr.x - tw * 0.5, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, GOLD)


# ---------------------------------------------------------------- a window: stone, bronze trim, knot corners, its title
func _panel(parent: Control, x: float, y: float, w: float, h: float, title := "", knot := 76.0, alpha := 0.95) -> Control:
	return _box(parent, x, y, w, h, _draw_panel.bind(title, knot, alpha))


func _draw_panel(c: Control, title: String, knot: float, alpha: float) -> void:
	var r := Rect2(Vector2.ZERO, c.size)
	_glow(c, Rect2(r.position + Vector2(0, _p(8.0)), r.size), Color(0, 0, 0, 0.55), _p(28.0))
	c.draw_texture_rect(_grad("v", STONE_HI, STONE_LO), r, false, Color(1, 1, 1, alpha))
	c.draw_texture_rect(grain, r, true, Color(1, 1, 1, 0.055))
	c.draw_texture_rect(_grad("v", Color(1, 1, 1, 0.045), Color(1, 1, 1, 0.0)), Rect2(r.position, Vector2(r.size.x,
			_p(60.0))), false)
	var lw := maxf(1.0, _p(2.0))
	c.draw_rect(r.grow(1.0), Color(0, 0, 0, 0.9), false, 1.5)
	c.draw_rect(r.grow(-lw * 0.5), BRONZE, false, lw)
	c.draw_rect(r.grow(-_p(6.0)), Color(BRONZE_HI, 0.2), false, 1.0)
	_knots(c, r, knot)
	if title != "":
		_strip(c, Vector2(r.size.x * 0.5, 0.0), title)


## A sunken inset inside a window (the kit's buttons, the falls): darker, its edge in shadow.
func _inset(parent: Control, x: float, y: float, w: float, h: float) -> Control:
	return _box(parent, x, y, w, h, func(c: Control) -> void:
		var r := Rect2(Vector2.ZERO, c.size)
		c.draw_rect(r, Color(0.02, 0.025, 0.035, 0.6))
		c.draw_texture_rect(_grad("v", Color(0, 0, 0, 0.5), Color(0, 0, 0, 0.0)), Rect2(r.position, Vector2(r.size.x, _p(14.0))),
				false)
		c.draw_rect(r, Color(0, 0, 0, 0.8), false, 1.0)
		c.draw_line(Vector2(0, r.size.y), r.size, Color(BRONZE, 0.35), 1.0))


## A heading inside a window: spaced small capitals, a thin bronze rule to the right with a diamond at its end; `right` a
## value at the right end in its own colour (the points).
func _rule(parent: Control, x: float, y: float, w: float, caps: String, right := "", right_col := GREEN) -> void:
	var f: Font = fonts.caps
	var fs := _fs(12.5)
	var tw := f.get_string_size(caps, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x / k
	_text(parent, x, y, caps, "caps", 12.5, BRONZE_HI)
	var rw := 0.0
	if right != "":
		var rf: Font = fonts.disp_b
		rw = rf.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(19.0)).x / k
		_text(parent, x + w - rw, y - 5.0, right, "disp_b", 19.0, right_col)
	var x0 := x + tw + 12.0
	var x1 := x + w - (rw + 14.0 if right != "" else 0.0)
	_box(parent, x0, y + 8.0, maxf(x1 - x0, 1.0), 2.0, func(c: Control) -> void:
		c.draw_texture_rect(_grad("h", Color(BRONZE, 0.85), Color(BRONZE, 0.15)), Rect2(Vector2(0, 0), Vector2(c.size.x,
				maxf(1.0, _p(1.0)))), false)
		_diamond(c, Vector2(c.size.x, _p(0.5)), _p(3.0), Color(BRONZE, 0.7)))


## A medallion: the gold ring and its dark well, the glyph in `col`; `lit` a soft gold halo, `wash` the element's colour in the
## well.
func _medal(parent: Control, x: float, y: float, d: float, icon: String, col: Color, lit := false,
		wash := Color.TRANSPARENT) -> Control:
	var ic: Texture2D = _svg(icon, _p(d * 0.58)) if icon != "" else null
	return _box(parent, x, y, d, d, func(c: Control) -> void:
		var s := c.size
		var ctr := s * 0.5
		if lit:
			for i in 6:
				c.draw_circle(ctr, s.x * 0.5 + _p(2.0 + i * 2.2), Color(BRONZE_HI, 0.045))
		c.draw_texture_rect(_svg("medallion", s.x), Rect2(Vector2.ZERO, s), false)
		if wash.a > 0.0:
			c.draw_texture_rect(_grad("r", Color(wash, 0.42), Color(wash, 0.0)), Rect2(s * 0.1, s * 0.8), false)
		if ic != null:
			var isz := s * 0.58
			c.draw_texture_rect(ic, Rect2(ctr - isz * 0.5 + Vector2(0, _p(1.5)), isz), false, Color(0, 0, 0, 0.6))
			c.draw_texture_rect(ic, Rect2(ctr - isz * 0.5, isz), false, col))


## A row: a stone slot with its medallion, its name in gold and its line under it. o: focus (the cursor: a gold edge, a glow
## and the tab at its left), chosen (its panel open: a bronze edge and a tab at its right), value ("normal": drawn
## "<  normal  >" at the right), icon_col, wash (an element's colour from the left), size, sub_size, compact (no medallion).
func _slot(parent: Control, x: float, y: float, w: float, h: float, name: String, sub := "", icon := "", o := {}) -> Control:
	var c := _box(parent, x, y, w, h, _draw_slot.bind(o))
	var foc := bool(o.get("focus", false))
	var tx := 16.0
	if icon != "":
		var d := minf(h - 14.0, 48.0)
		_medal(c, 10.0, (h - d) * 0.5, d, icon, o.get("icon_col", GOLD), foc, o.get("wash", Color.TRANSPARENT))
		tx = 10.0 + d + 14.0
	var ns := float(o.get("size", 23.0))
	var ss := float(o.get("sub_size", 14.5))
	var name_h := ns * 1.18
	var lines := 1
	if sub != "" and bool(o.get("wrap_sub", false)):
		var bf: Font = fonts.body
		if bf.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(ss)).x > _p(w - tx - 14.0):
			lines = 2
	var sub_h := ss * 1.22 * lines if sub != "" else 0.0
	var ny := (h - name_h - sub_h) * 0.5 - 1.0
	_text(c, tx, ny, name, "disp", ns, GOLD_HI if foc else GOLD)
	if o.has("value"):
		var vw := 190.0
		_text(c, w - 16.0 - vw, ny, "‹  %s  ›" % String(o.value), "disp", ns, GOLD_HI if foc else INK, vw,
				HORIZONTAL_ALIGNMENT_RIGHT)
	if sub != "":
		_text(c, tx, ny + name_h, sub, "body", ss, MUTED if not foc else INK.lerp(MUTED, 0.35), w - tx - 14.0,
				HORIZONTAL_ALIGNMENT_LEFT, lines > 1, true, lines == 1)
	return c


func _draw_slot(c: Control, o: Dictionary) -> void:
	var r := Rect2(Vector2.ZERO, c.size)
	var foc := bool(o.get("focus", false))
	var chosen := bool(o.get("chosen", false))
	if foc:
		_glow(c, r, Color(BRONZE_HI, 0.30), _p(13.0))
	c.draw_texture_rect(_grad("v", Color("1c2029"), Color("0f1217")), r, false, Color(1, 1, 1, 0.94))
	c.draw_texture_rect(grain, r, true, Color(1, 1, 1, 0.045))
	var wash: Color = o.get("wash", Color.TRANSPARENT)
	if wash.a > 0.0:
		c.draw_texture_rect(_grad("h", Color(wash, 0.16), Color(wash, 0.0)), Rect2(r.position, Vector2(r.size.x * 0.6,
				r.size.y)), false)
	if foc:
		c.draw_texture_rect(_grad("h", Color(BRONZE_HI, 0.20), Color(BRONZE_HI, 0.0)), r, false)
	elif chosen:
		c.draw_texture_rect(_grad("h", Color(BRONZE, 0.0), Color(BRONZE, 0.14)), r, false)
	c.draw_line(Vector2(2, 1.5), Vector2(r.size.x - 2, 1.5), Color(1, 1, 1, 0.06), 1.0)
	c.draw_rect(r.grow(1.0), Color(0, 0, 0, 0.85), false, 1.0)
	var bw := maxf(1.0, _p(1.7)) if (foc or chosen) else 1.0
	c.draw_rect(r.grow(-bw * 0.5), BRONZE_HI if foc else (BRONZE if chosen else EDGE), false, bw)
	var cy := r.size.y * 0.5
	var a := _p(7.5)
	if foc:
		var x0 := -_p(5.0)
		c.draw_colored_polygon(PackedVector2Array([Vector2(x0 - a * 1.1, cy - a), Vector2(x0, cy), Vector2(x0 - a * 1.1, cy + a)]),
				BRONZE_HI)
	if chosen or bool(o.get("tab_right", false)):
		var x1 := r.size.x + _p(5.0)
		c.draw_colored_polygon(PackedVector2Array([Vector2(x1, cy - a), Vector2(x1 + a * 1.1, cy), Vector2(x1, cy + a)]),
				BRONZE_HI)


## A button plate. kind: "red" (the reference's red-brown plate), "red_hi" (the primary: brighter, a gold edge), "dark" (a
## stone plate); focus adds the glow. icon: a glyph before the word.
func _button(parent: Control, x: float, y: float, w: float, h: float, text: String, o := {}) -> Control:
	var icon := String(o.get("icon", ""))
	var size := float(o.get("size", 18.0))
	var ic: Texture2D = _svg(icon, _p(size * 1.05)) if icon != "" else null
	return _box(parent, x, y, w, h, func(c: Control) -> void:
		var r := Rect2(Vector2.ZERO, c.size)
		var foc := bool(o.get("focus", false))
		var kind := String(o.get("kind", "red"))
		if foc:
			_glow(c, r, Color(BRONZE_HI, 0.42), _p(16.0))
		var col := PLATE_TXT
		if kind.begins_with("red"):
			var hi := foc or kind == "red_hi"
			var sbt := StyleBoxTexture.new()
			sbt.texture = _svg("plate_red_hi" if hi else "plate_red", c.size.y * 3.0)
			var m := 10.0 * c.size.y / 40.0
			sbt.texture_margin_left = m
			sbt.texture_margin_right = m
			sbt.texture_margin_top = m
			sbt.texture_margin_bottom = m
			c.draw_style_box(sbt, r)
			col = Color("fff0c0") if hi else PLATE_TXT
		else:
			c.draw_rect(r.grow(1.0), Color(0, 0, 0, 0.9))
			c.draw_texture_rect(_grad("v", Color("2a303a"), Color("13161c")), r, false)
			c.draw_texture_rect(grain, r, true, Color(1, 1, 1, 0.05))
			c.draw_rect(r.grow(-0.5), Color("5a606c") if not foc else BRONZE_HI, false, 1.0)
			c.draw_line(Vector2(2, 2), Vector2(r.size.x - 2, 2), Color(1, 1, 1, 0.08), 1.0)
			col = GOLD if not foc else GOLD_HI
		var f: Font = fonts.disp_b
		var fs := _fs(size)
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var iw := (ic.get_width() + _p(9.0)) if ic != null else 0.0
		var x0 := (r.size.x - tw - iw) * 0.5
		var base := r.size.y * 0.5 + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5
		if ic != null:
			var isz := Vector2(ic.get_width(), ic.get_height())
			c.draw_texture_rect(ic, Rect2(Vector2(x0, r.size.y * 0.5 - isz.y * 0.5 + _p(1.5)), isz), false, Color(0, 0, 0, 0.7))
			c.draw_texture_rect(ic, Rect2(Vector2(x0, r.size.y * 0.5 - isz.y * 0.5), isz), false, col)
		c.draw_string(f, Vector2(x0 + iw, base + _p(1.5)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.85))
		c.draw_string(f, Vector2(x0 + iw, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col))


## A key cap ("LMB", "E", "1"): returns its width (design px).
func _keycap(parent: Control, x: float, y: float, key: String, size := 13.0) -> float:
	var f: Font = fonts.body_sb
	var fs := _fs(size)
	var tw := f.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x / k
	var w := maxf(tw + 14.0, 26.0)
	var h := size + 11.0
	_box(parent, x, y, w, h, func(c: Control) -> void:
		var r := Rect2(Vector2.ZERO, c.size)
		c.draw_rect(r.grow(1.0), Color(0, 0, 0, 0.9))
		c.draw_texture_rect(_grad("v", Color("343a45"), Color("171a20")), r, false)
		c.draw_rect(r.grow(-0.5), Color("6a707c"), false, 1.0)
		c.draw_line(Vector2(2, 1.5), Vector2(r.size.x - 2, 1.5), Color(1, 1, 1, 0.12), 1.0)
		var base := r.size.y * 0.5 + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5
		c.draw_string(f, Vector2((r.size.x - tw * k) * 0.5, base), key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK))
	return w


## A talent chip as the Advancement window draws its nodes: the element's plate, the move's glyph in ink, a gold edge (worn);
## square: it changes what a move does (Twist, Technique), round: a number trade (Enhance).
func _chip(parent: Control, x: float, y: float, d: float, icon: String, col: Color, square: bool) -> Control:
	var ic := _svg(icon, _p(d * 0.7))
	return _box(parent, x, y, d, d, func(c: Control) -> void:
		var s := c.size
		var ctr := s * 0.5
		var r := Rect2(Vector2.ZERO, s)
		var lw := maxf(1.5, _p(2.0))
		_glow(c, r, Color(BRONZE_HI, 0.18), _p(6.0))
		if square:
			c.draw_rect(r.grow(1.5), Color(0, 0, 0, 0.95))
			c.draw_texture_rect(_grad("r", col.lightened(0.25), col.darkened(0.45)), r, false)
			c.draw_rect(r.grow(-lw * 0.5), BRONZE_HI, false, lw)
		else:
			c.draw_circle(ctr, s.x * 0.5 + 1.5, Color(0, 0, 0, 0.95))
			for i in 10:
				var t := i / 9.0
				c.draw_circle(ctr - Vector2(0, s.y * 0.04 * t), s.x * 0.5 * (1.0 - t * 0.85), col.darkened(0.45).lerp(col.lightened(0.25), t))
			c.draw_arc(ctr, s.x * 0.5 - lw * 0.5, 0.0, TAU, 48, BRONZE_HI, lw, true)
		var isz := s * 0.7
		c.draw_texture_rect(ic, Rect2(ctr - isz * 0.5, isz), false, Color(0.08, 0.05, 0.03, 0.9)))


# ---------------------------------------------------------------- the screen's ground: backdrop, shades, frame, title
func _backdrop(ui: Control, key: String, blur := false, darken := 0.0, lod := 1.2) -> void:
	var img: Image = bd.get(key, null)
	if img == null:
		var fill := ColorRect.new()
		fill.color = Color("1c2535")
		fill.size = ui.size
		ui.add_child(fill)
		print("  (no backdrop ", key, ")")
		return
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.size = ui.size
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if blur:
		var im := img.duplicate() as Image
		im.generate_mipmaps()
		t.texture = ImageTexture.create_from_image(im)
		t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var mat := ShaderMaterial.new()
		mat.shader = blur_shader
		mat.set_shader_parameter("darken", darken)
		mat.set_shader_parameter("lod", lod)
		t.material = mat
	else:
		t.texture = ImageTexture.create_from_image(img)
	ui.add_child(t)


func _shade(ui: Control, x: float, y: float, w: float, h: float, a: Color, b: Color, horizontal := true) -> void:
	var t := TextureRect.new()
	t.texture = _grad("h" if horizontal else "v", a, b)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.position = Vector2(_p(x), _p(y))
	t.size = Vector2(_p(w), _p(h))
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(t)


func _vignette(ui: Control, a: float) -> void:
	var t := TextureRect.new()
	t.texture = _grad("r", Color(SHADE, 0.0), Color(SHADE, a), 0.62, Color(SHADE, 0.0))
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.position = -Vector2(_p(160.0), _p(90.0))
	t.size = ui.size + Vector2(_p(320.0), _p(180.0))
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(t)


## The whole screen as one window, as the Advancement window is: a dark bezel, the bronze line, knots at the corners, the
## title plate at the top.
func _screen_frame(ui: Control, top: String) -> void:
	_box(ui, 0, 0, 1600, 900, func(c: Control) -> void:
		var r := Rect2(Vector2.ZERO, c.size)
		var e := _p(12.0)
		var band := Color(0.02, 0.025, 0.035, 0.92)
		c.draw_rect(Rect2(0, 0, r.size.x, e), band)
		c.draw_rect(Rect2(0, r.size.y - e, r.size.x, e), band)
		c.draw_rect(Rect2(0, 0, e, r.size.y), band)
		c.draw_rect(Rect2(r.size.x - e, 0, e, r.size.y), band)
		var inner := r.grow(-e)
		c.draw_rect(inner.grow(1.0), Color(0, 0, 0, 0.9), false, 1.5)
		c.draw_rect(inner, BRONZE, false, maxf(1.0, _p(2.0)))
		c.draw_rect(inner.grow(-_p(5.0)), Color(BRONZE_HI, 0.22), false, 1.0)
		_knots(c, inner, 112.0)
		if top != "":
			_strip(c, Vector2(r.size.x * 0.5, e), top, 13.0))


func _title(ui: Control, x: float, y: float, w: float) -> void:
	var t := TextureRect.new()
	t.texture = _grad("r", Color(SHADE, 0.78), Color(SHADE, 0.0), 0.55, Color(SHADE, 0.5))
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.position = Vector2(_p(x - 120.0), _p(y - 70.0))
	t.size = Vector2(_p(w + 240.0), _p(320.0))
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(t)
	_carved(ui, x - 40.0, y, w + 80.0, "TIDEBREAK", 82.0)
	_text(ui, x, y + 106.0, "ELEMENTAL ARENA COMBAT", "caps", 17.0, GOLD, w, HORIZONTAL_ALIGNMENT_CENTER)
	_box(ui, x + w * 0.5 - 230.0, y + 128.0, 460.0, 46.0, func(c: Control) -> void:
		c.draw_texture_rect(_svg("crest", c.size.x), Rect2(Vector2.ZERO, c.size), false))


func _bottom_bar(ui: Control, cap_title: String, cap: String) -> void:
	var b := _box(ui, 22, 818, 1556, 62, func(c: Control) -> void:
		var r := Rect2(Vector2.ZERO, c.size)
		c.draw_texture_rect(_grad("v", Color("1a1e26"), Color("0b0d11")), r, false, Color(1, 1, 1, 0.94))
		c.draw_texture_rect(grain, r, true, Color(1, 1, 1, 0.05))
		c.draw_line(Vector2(0, 0), Vector2(r.size.x, 0), Color(0, 0, 0, 0.9), 3.0)
		c.draw_line(Vector2(0, 1), Vector2(r.size.x, 1), BRONZE, maxf(1.0, _p(1.5)))
		c.draw_line(Vector2(0, _p(5.0)), Vector2(r.size.x, _p(5.0)), Color(BRONZE_HI, 0.15), 1.0)
		_diamond(c, Vector2(r.size.x * 0.5, 1), _p(5.0), BRONZE_HI))
	_text(b, 28, 9, cap_title, "disp", 18.0, GOLD)
	_text(b, 28, 35, cap, "body", 14.5, MUTED)
	var bx := 1556.0 - 26.0 - 132.0
	_button(b, bx, 12, 132, 38, "Quit", {"kind": "red", "size": 17.0, "icon": "i:door"})
	_button(b, bx - 144.0, 12, 132, 38, "Credits", {"kind": "dark", "size": 17.0})
	_button(b, bx - 288.0, 12, 132, 38, "Settings", {"kind": "dark", "size": 17.0, "icon": "i:sliders"})


# ================================================================ the words (the game's own)
func _rw(key: String, def := "") -> String:
	var v := RingMode.words(key)
	return v if v != "" and v != key else def


func _quick_line() -> String:
	var ql := String(MatchSetup.screens().get("quick_line", "%s against a random opponent  ·  %s  ·  %s"))
	return ql % ["Fire", "normal", "best of 3"]


func _play_panel(ui: Control, focus_row: String, chosen_row: String) -> void:
	var p := _panel(ui, 64, 214, 480, 388, "PLAY")
	var rows := [
		[MatchSetup.sport(), MatchSetup.menu_line(), "i:four"],
		["Start here", "learn at your own pace, or play an easy match", "i:flag"],
		["Quick match", _quick_line(), "i:bolt"],
		["Practice", "a %s dummy that stands still" % MatchSetup.competitor("water"), "i:post"],
	]
	var y := 36.0
	for r: Array in rows:
		_slot(p, 26, y, 428, 70, String(r[0]), String(r[1]), String(r[2]),
				{"focus": r[0] == focus_row, "chosen": r[0] == chosen_row})
		y += 86.0


# ================================================================ 1. the main menu
func _build_main(ui: Control) -> void:
	_backdrop(ui, main_bd)
	_shade(ui, 0, 0, 780, 900, Color(SHADE, 0.84), Color(SHADE, 0.0))
	_shade(ui, 960, 0, 640, 900, Color(SHADE, 0.0), Color(SHADE, 0.7))
	_shade(ui, 0, 600, 1600, 300, Color(SHADE, 0.0), Color(SHADE, 0.75), false)
	_vignette(ui, 0.6)
	_screen_frame(ui, "EARLY PLAYABLE DEMO  ·  IN DEVELOPMENT")
	_title(ui, 64, 30, 480)
	_play_panel(ui, "Quick match", "")
	_fighter_panel(ui, 1084, 150)
	var pic: Dictionary = {}
	for e: Dictionary in MenuPaintings.PICTURES:
		if String(e.file) == "sky.png":
			pic = e
	_bottom_bar(ui, String(pic.get("title", "Make waves")), String((pic.get("captions", [""]) as Array)[0]))


## The Fighter area: the class (the element and its fighting style), its rail, the loadout worn, and the two ways in: Class &
## talents (the Advancement window) and Your look (the character creator).
func _fighter_panel(ui: Control, x: float, y: float) -> void:
	var el := "fire"
	var col := MatchSetup.color(el)
	var p := _panel(ui, x, y, 452, 620, "FIGHTER")
	_medal(p, 24, 38, 104, "m:" + el, col, true, col)
	_text(p, 146, 40, "%s  ·  Boxing" % MatchSetup.label(el), "disp", 30.0, GOLD_HI)
	_text(p, 146, 82, "jab, cross, hook and uppercut; head movement and footwork", "body", 15.0, MUTED, 284.0,
			HORIZONTAL_ALIGNMENT_LEFT, true)
	_runs(p, 146, 124, [["+ Speed", GREEN], ["+ Mobility", GREEN], ["− Reach", MINUS], ["− Width", MINUS]], "body_sb", 14.5,
			12.0)
	# the class's rail: the style's traits, linked, as the reference's spec rail
	_rule(p, 24, 166, 404, "CLASS")
	var rail := [["Stance", "s:footwork__step"], ["Jab string", "s:fire_jab__embers"], ["Signature", "s:fire_blast__punch"],
			["Guard", "s:fire_parry__parry"], ["Perfect", "i:star"]]
	var d := 50.0
	var step := (404.0 - d) / 4.0
	_box(p, 24 + d * 0.5, 190 + d * 0.5 - 2.0, 404 - d, 4.0, func(c: Control) -> void:
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0, 0, 0, 0.9))
		c.draw_rect(Rect2(Vector2(0, c.size.y * 0.25), Vector2(c.size.x, c.size.y * 0.5)), BRONZE))
	for i in rail.size():
		var mx := 24.0 + i * step
		_medal(p, mx, 190, d, String(rail[i][1]), GOLD_HI if i != 4 else BRONZE_HI)
		_text(p, mx - 25.0, 244, String(rail[i][0]), "body", 13.5, MUTED, d + 50.0, HORIZONTAL_ALIGNMENT_CENTER)
	# the loadout worn (fire's starter loadout "Blaze", data/sway/skill_tree.json: 10 of the ring's 10 points)
	_rule(p, 24, 282, 404, "LOADOUT  ·  BLAZE", "10 / 10")
	var worn := [
		["Two-Hand Rhythm", "Technique  ·  2", "s:fire_blast__punch", true],
		["Ignite Step", "Twist  ·  2", "s:footwork__step", true],
		["Blazing Fireball", "Twist  ·  2", "s:fire_blast__fireball", true],
		["Crescent Burn", "Twist  ·  2", "s:fire_kick__high_kick", true],
		["Tight Embers", "Enhance  ·  1", "s:fire_jab__embers", false],
		["Reaching Parry", "Enhance  ·  1", "s:fire_parry__parry", false],
	]
	for i in worn.size():
		var cx := 24.0 + (i % 2) * 206.0
		var cy := 310.0 + (i / 2) * 46.0
		_chip(p, cx, cy, 36.0, String(worn[i][2]), col, bool(worn[i][3]))
		_text(p, cx + 48.0, cy - 2.0, String(worn[i][0]), "body", 15.5, INK)
		_text(p, cx + 48.0, cy + 18.0, String(worn[i][1]), "body", 12.5, FAINT.lerp(MUTED, 0.5))
	_slot(p, 24, 462, 404, 64, "Class & talents", "your class, its talents and three loadouts", "i:tree")
	_slot(p, 24, 536, 404, 64, "Your look", "the character creator: face, build and dress", "i:bust")


# ================================================================ 2. the Tidebreak match panel
func _build_match(ui: Control) -> void:
	var el := "water"
	_backdrop(ui, match_bd)
	_shade(ui, 0, 0, 780, 900, Color(SHADE, 0.84), Color(SHADE, 0.0))
	_shade(ui, 0, 600, 1600, 300, Color(SHADE, 0.0), Color(SHADE, 0.75), false)
	_vignette(ui, 0.6)
	_screen_frame(ui, "EARLY PLAYABLE DEMO  ·  IN DEVELOPMENT")
	_title(ui, 64, 30, 480)
	_play_panel(ui, "", MatchSetup.sport())
	var px := 584.0
	var pw := 952.0
	var iw := pw - 64.0
	var col_w := (iw - 16.0) * 0.5
	var rx := 32.0 + col_w + 16.0
	var p := _panel(ui, px, 92, pw, 708, MatchSetup.sport().to_upper())
	_text(p, 32, 30, MatchSetup.sport_line(), "body", 16.0, MUTED, iw, HORIZONTAL_ALIGNMENT_LEFT, true)
	_rule(p, 32, 98, iw, "YOUR ELEMENT")
	var cw := (iw - 3 * 12.0) / 4.0
	var i := 0
	for e: String in Bending.ELEMENTS:
		_element_card(p, 32 + i * (cw + 12.0), 122, cw, 108, e, e == el, e == el)
		i += 1
	# the chosen element's style, passive and buttons (KitWords, the keys scheme)
	var kit := _inset(p, 32, 250, col_w, 358)
	var ec := MatchSetup.color(el)
	_text(kit, 18, 12, "%s  ·  %s" % [MatchSetup.competitor(el), MatchSetup.style(el)], "body_sb", 15.5, ec.lerp(INK, 0.3),
			col_w - 36.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	_text(kit, 18, 58, KitWords.passive_line(el), "body", 14.0, INK.lerp(MUTED, 0.2), col_w - 36.0, HORIZONTAL_ALIGNMENT_LEFT,
			true)
	var ky := 116.0
	for line in KitWords.kit_lines(el, "", false):
		var parts := Array(String(line).split("   ", false))
		if parts.size() >= 3:
			_keycap(kit, 18, ky, String(parts[0]).strip_edges(), 12.5)
			_text(kit, 70, ky + 4.0, String(parts[1]).strip_edges(), "caps", 11.5, BRONZE_HI)
			_text(kit, 150, ky + 1.0, " ".join(PackedStringArray(parts.slice(2))).strip_edges(), "body", 15.0, INK,
					col_w - 166.0, HORIZONTAL_ALIGNMENT_LEFT, false, true, true)
		else:
			_text(kit, 18, ky, String(line), "body", 14.0, MUTED, col_w - 36.0)
		ky += 33.0
	# the match's choices: a press steps each
	var foe := "earth"
	var o := {"size": 21.0, "sub_size": 13.5}
	_slot(p, rx, 250, col_w, 80, "Opponent", "%s  ·  %s" % [MatchSetup.competitor(foe), MatchSetup.style(foe)], "m:" + foe,
			{"value": MatchSetup.label(foe), "icon_col": MatchSetup.color(foe), "wash": MatchSetup.color(foe), "size": 21.0,
			"sub_size": 13.5, "wrap_sub": true})
	var rows := [
		["Difficulty", MatchSetup.difficulty_line("normal"), "normal"],
		["Rules", "lives: 3 each, into the water loses one", MatchSetup.rule_label("stock")],
		["Games", "the first to win 2 games takes the match", MatchSetup.games_label(3)],
		["Light", MatchSetup.light_line("night"), "night"],
	]
	var ry := 340.0
	for r: Array in rows:
		var ro := o.duplicate()
		ro["value"] = String(r[2])
		_slot(p, rx, ry, col_w, 60, String(r[0]), String(r[1]), "", ro)
		ry += 68.0
	# the window's foot: Controls and Begin
	_box(p, 32, 626, iw, 2, func(c: Control) -> void:
		c.draw_texture_rect(_grad("h", Color(BRONZE, 0.0), Color(BRONZE, 0.0), 0.5, Color(BRONZE, 0.8)), Rect2(Vector2.ZERO,
				Vector2(c.size.x, maxf(1.0, _p(1.0)))), false))
	_button(p, 32, 644, 176, 44, KitWords.w("controls", "Controls"), {"kind": "dark", "size": 18.0, "icon": "i:keys"})
	_text(p, 222, 646, KitWords.w("controls_line"), "body", 14.0, MUTED, 380.0, HORIZONTAL_ALIGNMENT_LEFT, true)
	_button(p, pw - 32.0 - 250.0, 638, 250, 54, "Begin", {"kind": "red_hi", "size": 24.0, "icon": "i:play"})
	_bottom_bar(ui, "Make waves", "Jump, dodge and recover above the water. Practice has no countdown, so there is time to find what works for you.")


func _element_card(parent: Control, x: float, y: float, w: float, h: float, el: String, chosen: bool, foc: bool) -> void:
	var col := MatchSetup.color(el)
	var c := _box(parent, x, y, w, h, func(cc: Control) -> void:
		var r := Rect2(Vector2.ZERO, cc.size)
		if foc:
			_glow(cc, r, Color(BRONZE_HI, 0.34), _p(14.0))
		cc.draw_texture_rect(_grad("v", Color("1c2029"), Color("0f1217")), r, false, Color(1, 1, 1, 0.95))
		cc.draw_texture_rect(grain, r, true, Color(1, 1, 1, 0.045))
		cc.draw_texture_rect(_grad("v", Color(col, 0.30 if chosen else 0.12), Color(col, 0.0)), Rect2(r.position,
				Vector2(r.size.x, r.size.y * 0.75)), false)
		cc.draw_rect(Rect2(0, 0, r.size.x, maxf(2.0, _p(3.0))), Color(col, 0.9 if chosen else 0.5))
		cc.draw_rect(r.grow(1.0), Color(0, 0, 0, 0.85), false, 1.0)
		var bw := maxf(1.0, _p(2.0)) if (foc or chosen) else 1.0
		cc.draw_rect(r.grow(-bw * 0.5), BRONZE_HI if foc else (BRONZE if chosen else EDGE), false, bw)
		if foc:
			var a := _p(8.0)
			var cx := r.size.x * 0.5
			var by := r.size.y + _p(5.0)
			cc.draw_colored_polygon(PackedVector2Array([Vector2(cx - a, by), Vector2(cx + a, by), Vector2(cx, by + a)]), BRONZE_HI))
	_medal(c, 12, (h - 66.0) * 0.5, 66.0, "m:" + el, col, chosen, col)
	_text(c, 90, 24, MatchSetup.label(el), "disp", 27.0, GOLD_HI if chosen else GOLD)
	_text(c, 91, 60, MatchSetup.competitor(el), "body_sb", 15.5, col.lerp(INK, 0.25))
	if chosen:
		var f: Font = fonts.caps
		var tw := f.get_string_size("CHOSEN", HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(10.5)).x / k
		_box(c, w - tw - 26.0, 9, tw + 16.0, 19, func(cc: Control) -> void:
			var r := Rect2(Vector2.ZERO, cc.size)
			cc.draw_rect(r, Color(0.05, 0.04, 0.03, 0.85))
			cc.draw_rect(r, BRONZE_HI, false, 1.0))
		_text(c, w - tw - 18.0, 11, "CHOSEN", "caps", 10.5, GOLD_HI, 0.0, HORIZONTAL_ALIGNMENT_LEFT, false, false)


# ================================================================ 3. the ring's Esc menu
func _build_pause(ui: Control) -> void:
	_backdrop(ui, pause_bd, true, 0.3)
	_shade(ui, 0, 0, 1150, 900, Color(SHADE, 0.72), Color(SHADE, 0.0))
	_vignette(ui, 0.55)
	var wide := 1.0 if k > 0.99 else 1.25
	var pw := 462.0 * wide
	var bw := pw - 60.0
	var p := _panel(ui, 104, 84, pw, 712, _rw("menu_title", "Tidebreak").to_upper())
	_text(p, 0, 30, "Round 2  ·  2:14 left  ·  You 1  :  0 Tide", "disp", 18.5, GOLD, pw, HORIZONTAL_ALIGNMENT_CENTER)
	_box(p, pw * 0.5 - 170, 60, 340, 34, func(c: Control) -> void:
		c.draw_texture_rect(_svg("crest", c.size.x), Rect2(Vector2.ZERO, c.size), false))
	_button(p, 30, 106, bw, 54, _rw("resume", "Resume"), {"kind": "red_hi", "size": 22.0, "icon": "i:play"})
	var foe := "water"
	var rows := [
		[_rw("restart", "Restart match"), _rw("restart_line", ""), "i:restart", {}],
		["Element", _rw("element_line", ""), "m:fire", {"value": MatchSetup.label("fire"), "icon_col": MatchSetup.color("fire"),
				"wash": MatchSetup.color("fire")}],
		["Opponent", _rw("opponent_line", ""), "m:" + foe, {"value": MatchSetup.label(foe), "icon_col": MatchSetup.color(foe),
				"wash": MatchSetup.color(foe)}],
		["Options", "difficulty, rules, aim help, camera, replays", "i:sliders", {"focus": true, "tab_right": true}],
		[KitWords.w("controls", "Controls"), KitWords.w("controls_line"), "i:keys", {}],
		[_rw("main_menu", "Main menu"), "back to the title; nothing is saved in a match", "i:gate", {}],
	]
	var y := 178.0
	for r: Array in rows:
		var o: Dictionary = (r[3] as Dictionary).duplicate()
		o["size"] = 21.5
		o["sub_size"] = 13.5
		o["wrap_sub"] = true
		_slot(p, 30, y, bw, 66, String(r[0]), String(r[1]), String(r[2]), o)
		y += 76.0
	_button(p, 30, y + 6.0, bw, 46, _rw("quit", "Quit"), {"kind": "dark", "size": 18.0, "icon": "i:door"})
	_options_panel(ui, 104 + pw + 24.0, 136, 520.0 * wide)


## Options: the Esc menu's many rows (the match's rules, the aids, the camera, the replays) gathered into one panel, so the menu
## itself fits the screen. Each row's words are the game's own (its row_text and row_line).
func _options_panel(ui: Control, x: float, y: float, w: float) -> void:
	var rows: Array = [
		["Difficulty:  normal", MatchSetup.difficulty_line("normal")],
		[MatchSetup.menu_word("rules") % MatchSetup.rule_label("stock"), "lives: 3 each, into the water loses one"],
		[MatchSetup.menu_word("games") % MatchSetup.games_label(3), MatchSetup.menu_word("games_line")],
		[MatchSetup.aim_row(), MatchSetup.aim_row_line()],
		[FirstHints.row_text(), FirstHints.row_line()],
		[RingCamera.row_text(), RingCamera.row_line()],
		[RingCamera.jolt_row_text(), RingCamera.word("jolt_line")],
		[RingReplay.row_text(), RingReplay.row_line()],
		[Callouts.row_text(), Callouts.row_line()],
		[PhotoMode.row_text(), PhotoMode.row_line()],
	]
	var h := 34.0 + rows.size() * 60.0 + 12.0
	var p := _panel(ui, x, y, w, h, "OPTIONS")
	var ry := 34.0
	for r: Array in rows:
		var text := String(r[0])
		var name := text
		var o := {"size": 19.5, "sub_size": 12.5, "wrap_sub": true}
		var at := text.find(":")
		if at > 0:
			name = text.left(at).strip_edges()
			o["value"] = text.substr(at + 1).strip_edges()
		_slot(p, 24, ry, w - 48.0, 54, name, String(r[1]), "", o)
		ry += 60.0


# ================================================================ 4. the match-end screen
func _build_end(ui: Control) -> void:
	_backdrop(ui, end_bd, true, 0.12, 0.7)
	_shade(ui, 0, 0, 1000, 900, Color(SHADE, 0.7), Color(SHADE, 0.0))
	_vignette(ui, 0.55)
	var mw := func(key: String, def: String) -> String:
		return String((MatchSetup.screens().get("match", {}) as Dictionary).get(key, def))
	var p := _panel(ui, 96, 50, 700, 800, _rw("menu_title", "Tidebreak").to_upper())
	_carved(p, 0, 26, 700, String(mw.call("head_win", "Victory")).to_upper(), 66.0)
	_box(p, 350 - 210, 106, 420, 42, func(c: Control) -> void:
		c.draw_texture_rect(_svg("crest", c.size.x), Rect2(Vector2.ZERO, c.size), false))
	_text(p, 0, 146, String(mw.call("line_win", "You take the match")), "body", 19.0, INK, 700.0, HORIZONTAL_ALIGNMENT_CENTER)
	# the score: your medallion, the games, theirs
	_medal(p, 156, 184, 70, "m:fire", MatchSetup.color("fire"), true, MatchSetup.color("fire"))
	_medal(p, 474, 184, 70, "m:water", MatchSetup.color("water"), false, MatchSetup.color("water"))
	_text(p, 136, 256, "You", "disp", 18.0, GOLD, 110.0, HORIZONTAL_ALIGNMENT_CENTER)
	_text(p, 454, 256, "Tide", "disp", 18.0, GOLD, 110.0, HORIZONTAL_ALIGNMENT_CENTER)
	_text(p, 250, 180, "2  :  0", "disp_b", 60.0, GOLD_HI, 200.0, HORIZONTAL_ALIGNMENT_CENTER)
	_text(p, 0, 290, String(mw.call("lives_line", "Lives left  ·  you %d  ·  the %s %d")) % [3, "Tide", 0], "body", 15.0, MUTED,
			700.0, HORIZONTAL_ALIGNMENT_CENTER)
	# the falls, one line each
	var falls := _inset(p, 28, 324, 644, 214)
	_rule(falls, 18, 12, 608, "THE FALLS")
	var fl := String(mw.call("fall_line", "%s  ·  %s into the water at %d%%  ·  %s"))
	var lines := [
		[1, "0:41", "the Tide", 118, "Punch"], [1, "1:26", "you", 104, "Geyser"], [1, "2:03", "the Tide", 131, "High Kick"],
		[1, "2:58", "the Tide", 97, "Kick"], [2, "0:37", "the Tide", 112, "Punch"], [2, "1:15", "the Tide", 124, "Fireball"],
		[2, "1:49", "the Tide", 140, "Lightning"],
	]
	var fy := 38.0
	for l: Array in lines:
		_text(falls, 18, fy, "Game %d" % int(l[0]), "disp", 15.5, GOLD)
		var you_fell := String(l[2]) == "you"
		_text(falls, 96, fy + 1.0, fl % [String(l[1]), String(l[2]), int(l[3]), String(l[4])], "body", 15.0,
				MINUS.lerp(INK, 0.35) if you_fell else INK)
		fy += 24.5
	# the tally
	var ty := 552.0
	for t in [String(mw.call("tally_falls", "")) % [6, 1, 0], String(mw.call("tally_pct", "")) % [742, 88, 40],
			String(mw.call("tally_string", "")) % [4, 38], String(mw.call("tally_guards", "")) % [5, 3, 2, 1, 2]]:
		_text(p, 40, ty, t, "body", 15.0, INK.lerp(MUTED, 0.3))
		ty += 23.0
	_button(p, 28, 654, 316, 52, String(mw.call("rematch", "Rematch")), {"kind": "red_hi", "focus": true, "size": 21.0,
			"icon": "i:restart"})
	_button(p, 356, 654, 316, 52, String(mw.call("main_menu", "Main menu")), {"kind": "dark", "size": 19.0, "icon": "i:gate"})
	_slot(p, 28, 718, 316, 58, "Your element", String(mw.call("element_line", "for the rematch")), "m:fire",
			{"value": "Fire", "icon_col": MatchSetup.color("fire"), "size": 19.0, "sub_size": 12.5})
	_slot(p, 356, 718, 316, 58, "Opponent", String(mw.call("opponent_line", "for the rematch")), "m:water",
			{"value": "Water", "icon_col": MatchSetup.color("water"), "size": 19.0, "sub_size": 12.5})
	_highlights(ui, 1000, 96)


## The match's best plays (data/ring/highlights.json's words), each with Watch.
func _highlights(ui: Control, x: float, y: float) -> void:
	var hd: Dictionary = {}
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/ring/highlights.json"))
	if raw is Dictionary:
		hd = raw
	var plays: Dictionary = hd.get("plays", {})
	var pick := [["fast_ko", 1.3], ["launch", 17], ["catch", 0.08]]
	var p := _panel(ui, x, y, 500, 524, String(hd.get("head", "Highlights")).to_upper())
	var cy := 38.0
	for pk: Array in pick:
		var pl: Dictionary = plays.get(String(pk[0]), {})
		var line := String(pl.get("line", "")).replace("{who}", "You").replace("{whom}", "the Tide")
		var c := _box(p, 24, cy, 452, 142, func(cc: Control) -> void:
			var r := Rect2(Vector2.ZERO, cc.size)
			cc.draw_texture_rect(_grad("v", Color("1c2029"), Color("0f1217")), r, false, Color(1, 1, 1, 0.95))
			cc.draw_texture_rect(grain, r, true, Color(1, 1, 1, 0.045))
			cc.draw_rect(Rect2(0, 0, maxf(2.0, _p(4.0)), r.size.y), BRONZE_HI)
			cc.draw_rect(r.grow(1.0), Color(0, 0, 0, 0.85), false, 1.0)
			cc.draw_rect(r.grow(-0.5), EDGE, false, 1.0))
		_text(c, 22, 14, String(pl.get("title", "")), "disp", 23.0, GOLD)
		_text(c, 22, 46, line, "body", 15.0, MUTED, 410.0)
		_text(c, 22, 72, String(pl.get("num", "%s")) % pk[1], "disp_b", 38.0, INK)
		_button(c, 452 - 132, 84, 112, 40, String(hd.get("watch", "Watch")), {"kind": "red", "size": 16.0, "icon": "i:play"})
		cy += 158.0


# ================================================================ the four backdrops, one per element
func _build_sheet(ui: Control) -> void:
	var bg := ColorRect.new()
	bg.color = Color("0a0c10")
	bg.size = ui.size
	ui.add_child(bg)
	_screen_frame(ui, "THE FOUR BACKDROPS  ·  ONE PER ELEMENT")
	var tw := 640.0
	var th := tw * 9.0 / 16.0
	for i in sheet_bd.size():
		var key := String(sheet_bd[i])
		var x := 132.0 + (i % 2) * (tw + 56.0)
		var y := 70.0 + (i / 2) * (th + 60.0)
		var img: Image = bd.get(key, null)
		if img != null:
			var t := TextureRect.new()
			t.texture = ImageTexture.create_from_image(img)
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			t.position = Vector2(_p(x), _p(y))
			t.size = Vector2(_p(tw), _p(th))
			ui.add_child(t)
		var el := key.get_slice("_", 0)
		_box(ui, x, y, tw, th, func(c: Control) -> void:
			var r := Rect2(Vector2.ZERO, c.size)
			c.draw_rect(r.grow(1.0), Color(0, 0, 0, 0.9), false, 2.0)
			c.draw_rect(r, BRONZE, false, maxf(1.0, _p(2.0)))
			_knots(c, r, 64.0)
			_strip(c, Vector2(r.size.x * 0.5, r.size.y), "%s  ·  %s" % [MatchSetup.label(el).to_upper(),
					key.get_slice("_", 1).to_upper()], 13.0))
