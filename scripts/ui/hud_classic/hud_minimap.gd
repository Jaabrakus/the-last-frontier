class_name HudMinimap
extends Control
## The classic HUD's round minimap, top right (HudClassicMap; owner 2026-10-03: "can the hud be similar to world of warcraft
## vanilla?", in the game's own art: dark leather, brass edging, the HUD's serif):
##   the map     MinimapBake's survey map of the land (baked once per level), turned with the view: what the camera faces
##               is up; a disc of DIAMETER px showing `radius_m` m round the player (the zoom: ZOOMS)
##   the ring    a brass ring round it, N E S W on it where they lie (N red, WorldClock's north), two brass buttons on
##               the ring's lower corners to zoom (+ and -; the keys = and -, the wheel over the map while the cursor is free)
##   markers     the player's arrow in the middle (the way they face); the story's place (StoryHUD.marker_at: a gold
##               diamond, held on the ring when it is further than the map shows), the home (where the player last slept:
##               DeathRule.home) and the homestead (the storyline's place), the storyline's contacts (lanterns), the
##               horses that are the player's (tamed, or the demo horse: HorseMount on them), fighters in COMBAT (red) or
##               SUSPICIOUS (a red ring), the wreck once it is down (WreckFall LANDED)
##   under it    the date and the hour (WorldClock, the sun or the moon), on a small leather plaque
## Cheap: the map is one textured quad (a canvas shader turns and masks it); the markers' positions are read MARK_HZ times
## a second into fixed arrays (no allocation), the lists of who to read every SCAN_S; the ring and markers redraw only
## when the view or a marker moved.

const DIAMETER := 188.0
const RING := 10.0
const PLAQUE_H := 24.0
const ZOOMS := [70.0, 110.0, 170.0, 260.0, 420.0]
const ZOOM_DEFAULT := 2
const MARK_HZ := 10.0
const SCAN_S := 1.0
const MAX_MARKS := 64
const HEAR_PIN := 6.0           ## px from the ring's inner edge a far marker is held at
const NORTH := Color(0.88, 0.34, 0.26)
const FOE := Color(0.9, 0.2, 0.16)
const HORSE_C := Color(0.82, 0.66, 0.44)
const HOME_C := Color(0.95, 0.9, 0.78)
const WRECK_C := Color(1.0, 0.56, 0.2)
const CONTACT_C := Color(1.0, 0.8, 0.42)

enum Mark { STORY, HOME, HOMESTEAD, CONTACT, HORSE, FOE, WARY, WRECK }

const MAP_SHADER := "shader_type canvas_item;
uniform sampler2D map_tex : filter_linear_mipmap, repeat_disable;
uniform vec2 centre_uv = vec2(0.5);
uniform vec2 fwd = vec2(0.0, -1.0);
uniform vec2 radius_uv = vec2(0.1);
uniform vec4 outside : source_color = vec4(0.13, 0.09, 0.06, 1.0);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	vec2 right = vec2(-fwd.y, fwd.x);
	vec2 uv = centre_uv + (p.x * right - p.y * fwd) * radius_uv;
	vec3 c = texture(map_tex, uv).rgb;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) { c = outside.rgb; }
	c *= mix(1.0, 0.7, smoothstep(0.72, 1.0, r));
	COLOR = vec4(c, 1.0 - smoothstep(0.975, 1.0, r));
}"

var player: Node3D
var bake: MinimapBake
var zoom_i := ZOOM_DEFAULT
var radius_m: float = ZOOMS[ZOOM_DEFAULT]   ## shown now (eases to ZOOMS[zoom_i])
var fwd := Vector2(0.0, -1.0)              ## the view's forward on the ground (world x, z; unit)
var centre := Vector2.ZERO                 ## the player's (x, z)
var facing := Vector2(0.0, -1.0)           ## the player's own facing on the ground
var mark_pos := PackedVector2Array()       ## world (x, z) of each marker (the first `marks` used)
var mark_kind := PackedInt32Array()
var marks := 0
var clock_text := ""

var _map: ColorRect
var _mat: ShaderMaterial
var _over: Control
var _clock: Label
var _clock_icon: TextureRect
var _zin: Button
var _zout: Button
var _mark_t := 0.0
var _scan_t := 0.0
var _contacts: Array = []
var _horses: Array = []
var _fighters: Array = []
var _death: Node = null
var _drawn := Vector4.INF                  ## (centre, heading, radius) last drawn


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	var side := DIAMETER + RING * 2.0
	custom_minimum_size = Vector2(side, side + PLAQUE_H + 4.0)
	mark_pos.resize(MAX_MARKS)
	mark_kind.resize(MAX_MARKS)
	_map = ColorRect.new()
	_map.name = "Map"
	_map.position = Vector2(RING, RING)
	_map.size = Vector2(DIAMETER, DIAMETER)
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = MAP_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_map.material = _mat
	add_child(_map)
	_over = Control.new()
	_over.name = "Ring"
	_over.position = Vector2.ZERO
	_over.size = Vector2(side, side)
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.draw.connect(_draw_over)
	add_child(_over)
	# the date plaque under it
	var plaque := Control.new()
	plaque.name = "Plaque"
	plaque.position = Vector2(4.0, side + 2.0)
	plaque.size = Vector2(side - 8.0, PLAQUE_H)
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.draw.connect(func() -> void: HudClassicMap.draw_panel(plaque, Rect2(Vector2.ZERO, plaque.size), false))
	add_child(plaque)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.add_child(row)
	_clock_icon = TextureRect.new()
	_clock_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_clock_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_clock_icon.custom_minimum_size = Vector2(14, 14)
	_clock_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_clock_icon.modulate = HudClassicMap.BRASS_HI
	_clock_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_clock_icon)
	_clock = HudClassicMap.label(14, FrontierHUD.TEXT)
	_clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_clock)
	# the zoom buttons just outside the ring, in its square's lower corners (clear of the letters going round it)
	_zout = _zoom_button("-", 1)
	_zin = _zoom_button("+", -1)
	var c := Vector2(side, side) * 0.5
	var out_r := DIAMETER * 0.5 + RING + 12.0
	_zin.position = c + Vector2.from_angle(deg_to_rad(45.0)) * out_r - _zin.custom_minimum_size * 0.5
	_zout.position = c + Vector2.from_angle(deg_to_rad(135.0)) * out_r - _zout.custom_minimum_size * 0.5
	bake = MinimapBake.shared()
	_scan()
	_read_marks()


func _zoom_button(t: String, dz: int) -> Button:
	var b := Button.new()
	b.name = "ZoomIn" if dz < 0 else "ZoomOut"
	b.text = ""
	b.tooltip_text = "Zoom in  (=)" if dz < 0 else "Zoom out  (-)"
	b.custom_minimum_size = Vector2(20, 20)
	b.size = b.custom_minimum_size
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.pressed.connect(zoom.bind(dz))
	b.draw.connect(func() -> void:
		var s := b.size
		var m := s * 0.5
		b.draw_circle(m + Vector2(0.8, 1.2), s.x * 0.5, Color(0, 0, 0, 0.5))
		b.draw_circle(m, s.x * 0.5, HudClassicMap.BRASS_DARK)
		b.draw_circle(m, s.x * 0.5 - 1.5, HudClassicMap.BRASS.lerp(HudClassicMap.BRASS_HI, 0.35 if b.is_hovered() else 0.0))
		b.draw_circle(m, s.x * 0.5 - 3.5, ClassicSkin.LEATHER_LO)
		var ink := HudClassicMap.BRASS_HI
		b.draw_line(m - Vector2(4.5, 0), m + Vector2(4.5, 0), ink, 2.0, true)
		if t == "+":
			b.draw_line(m - Vector2(0, 4.5), m + Vector2(0, 4.5), ink, 2.0, true))
	add_child(b)
	return b


## One step in (dz -1) or out (+1).
func zoom(dz: int) -> void:
	zoom_i = clampi(zoom_i + dz, 0, ZOOMS.size() - 1)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and _disc_has(e.position):
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(-1)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(1)
			accept_event()


func _unhandled_key_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null or not k.pressed or k.echo or not is_visible_in_tree():
		return
	match k.physical_keycode:
		KEY_EQUAL, KEY_KP_ADD:
			zoom(-1)
		KEY_MINUS, KEY_KP_SUBTRACT:
			zoom(1)


func _disc_has(p: Vector2) -> bool:
	return p.distance_to(Vector2.ONE * (DIAMETER * 0.5 + RING)) <= DIAMETER * 0.5 + RING


func _process(delta: float) -> void:
	if bake != null and bake.poll() and _mat.get_shader_parameter(&"map_tex") != bake.texture:
		_mat.set_shader_parameter(&"map_tex", bake.texture)
		_drawn = Vector4.INF
	radius_m = lerpf(radius_m, float(ZOOMS[zoom_i]), clampf(delta * 10.0, 0.0, 1.0))
	if absf(radius_m - float(ZOOMS[zoom_i])) < 0.05:
		radius_m = float(ZOOMS[zoom_i])
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = SCAN_S
		_scan()
		_update_clock()
	_mark_t -= delta
	var moved := false
	if _mark_t <= 0.0:
		_mark_t = 1.0 / MARK_HZ
		_read_marks()
		moved = true
	_follow()
	var key := Vector4(centre.x, centre.y, atan2(fwd.y, fwd.x), radius_m)
	if moved or not key.is_equal_approx(_drawn):
		_drawn = key
		_apply()
		_over.queue_redraw()


## The view's heading and the player's place and facing (each frame: the map turns smoothly with the camera).
func _follow() -> void:
	if player != null and is_instance_valid(player):
		centre = Vector2(player.global_position.x, player.global_position.z)
		var yaw: Variant = player.get("yaw")
		var b := player.global_basis
		facing = Vector2(-sin(float(yaw)), -cos(float(yaw))) if yaw != null else Vector2(-b.z.x, -b.z.z).normalized()
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		var f := -cam.global_basis.z
		var f2 := Vector2(f.x, f.z)
		if f2.length() < 0.2:
			f2 = Vector2(cam.global_basis.y.x, cam.global_basis.y.z)     # (looking straight down: the screen's up)
		if f2.length() > 0.001:
			fwd = f2.normalized()


func _apply() -> void:
	if bake == null or bake.rect.size.x <= 0.0:
		return
	_mat.set_shader_parameter(&"centre_uv", bake.uv_of(centre))
	_mat.set_shader_parameter(&"fwd", fwd)
	_mat.set_shader_parameter(&"radius_uv", Vector2(radius_m, radius_m) / bake.rect.size)


## Where world (x, z) falls on the disc, from its middle, in px (may lie past the disc).
func to_disc(xz: Vector2) -> Vector2:
	var d := xz - centre
	var right := Vector2(-fwd.y, fwd.x)
	return Vector2(d.dot(right), -d.dot(fwd)) / radius_m * (DIAMETER * 0.5)


## The direction of world vector `dir` (x, z) on the disc (unit, screen).
func dir_on_disc(dir: Vector2) -> Vector2:
	var right := Vector2(-fwd.y, fwd.x)
	var v := Vector2(dir.dot(right), -dir.dot(fwd))
	return v.normalized() if v.length() > 0.0001 else Vector2(0, -1)


# --- Who is on the map ---------------------------------------------------------------------------------------------

## The lists of who to show (once a SCAN_S: these walk groups).
func _scan() -> void:
	var tree := get_tree() if is_inside_tree() else null
	if tree == null:
		return
	_contacts = tree.get_nodes_in_group(StoryContact.CONTACTS)
	_fighters = tree.get_nodes_in_group(NpcFighter.GROUP)
	_horses.clear()
	for n in tree.get_nodes_in_group(HorseMount.GROUP):
		if n is HorseMount and (n as HorseMount).horse != null:
			_horses.append((n as HorseMount).horse)
	if _death == null or not is_instance_valid(_death):
		var lvl := tree.current_scene
		_death = lvl.get_node_or_null(^"Death") if lvl else null


## Every marker's place now into mark_pos / mark_kind (MARK_HZ times a second; no allocation).
func _read_marks() -> void:
	marks = 0
	var tree := get_tree() if is_inside_tree() else null
	if tree == null:
		return
	var d := StoryDirector.find(tree)
	if d != null and d.hud != null and d.hud.marker_at is Vector3:
		var m: Vector3 = d.hud.marker_at
		_add(Vector2(m.x, m.z), Mark.STORY)
	if d != null and d.active():
		var pl := d.places()
		if pl.has("homestead"):
			var hp: Array = pl.homestead
			_add(Vector2(float(hp[0]), float(hp[1])), Mark.HOMESTEAD)
	if _death != null and is_instance_valid(_death) and bool(_death.get("has_home")):
		var h: Vector3 = _death.get("home")
		_add(Vector2(h.x, h.z), Mark.HOME)
	var wf := WreckFall.find(tree)
	if wf != null and wf.phase == WreckFall.Phase.LANDED:
		_add(Vector2(wf.at.x, wf.at.z), Mark.WRECK)
	for c in _contacts:
		if is_instance_valid(c) and (c as Node3D).is_visible_in_tree():
			var p := (c as Node3D).global_position
			_add(Vector2(p.x, p.z), Mark.CONTACT)
	for h in _horses:
		if is_instance_valid(h) and (h as Node3D).is_inside_tree():
			var p := (h as Node3D).global_position
			_add(Vector2(p.x, p.z), Mark.HORSE)
	for f in _fighters:
		if not is_instance_valid(f) or not f.has_method(&"state_name") or (f.has_method(&"is_dead") and f.is_dead()):
			continue
		var st := String(f.state_name())
		if st == "COMBAT" or st == "SUSPICIOUS":
			var p := (f as Node3D).global_position
			_add(Vector2(p.x, p.z), Mark.FOE if st == "COMBAT" else Mark.WARY)


func _add(xz: Vector2, kind: int) -> void:
	if marks >= MAX_MARKS:
		return
	mark_pos[marks] = xz
	mark_kind[marks] = kind
	marks += 1


## The markers of `kind` on the map now (tests).
func count_of(kind: int) -> int:
	var n := 0
	for i in marks:
		if mark_kind[i] == kind:
			n += 1
	return n


func _update_clock() -> void:
	var scene := get_tree().current_scene if is_inside_tree() else null
	var rig: Variant = scene.get("environment_rig") if scene else null
	var dn: DayNight = (rig as EnvironmentRig).clock_driver if rig is EnvironmentRig else null
	if dn == null or dn.clock == null:
		clock_text = ""
		_clock.text = ""
		_clock_icon.visible = false
		return
	var c: WorldClock = dn.clock
	clock_text = "%s  ·  %s" % [c.date_string(), c.time_string()]
	_clock.text = clock_text
	_clock_icon.visible = true
	var want := "hud_sun" if c.sun_direction().y > -0.05 else "hud_moon"
	if _clock_icon.get_meta(&"id", "") != want:
		var p := FrontierHUD.ICON_DIR + want + ".svg"
		_clock_icon.texture = load(p) if ResourceLoader.exists(p) else null
		_clock_icon.set_meta(&"id", want)


# --- Drawing -------------------------------------------------------------------------------------------------------
## The glyphs' outlines (px about the marker; the polylines close on their first point), made once: each draw moves and
## turns them with draw_set_transform, so the map turning (a redraw a frame) allocates nothing.
const LETTERS := ["N", "E", "S", "W"]
const PINNED := [Mark.STORY, Mark.HOME, Mark.HOMESTEAD, Mark.WRECK]
var _arrow := PackedVector2Array([Vector2(0, -9), Vector2(6.5, 6), Vector2(0, 2.5), Vector2(-6.5, 6)])
var _diamond := PackedVector2Array([Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)])
var _house := PackedVector2Array([Vector2(-5, 4), Vector2(-5, -1), Vector2(0, -6), Vector2(5, -1), Vector2(5, 4)])
var _lean_to := PackedVector2Array([Vector2(-5.5, 4), Vector2(0, -6), Vector2(5.5, 4)])
var _flame := PackedVector2Array([Vector2(0, -7), Vector2(3.5, -1), Vector2(4, 3), Vector2(0, 5.5), Vector2(-4, 3), Vector2(-3.5, -1)])
var _arrow_line := _closed(_arrow)
var _diamond_line := _closed(_diamond)
var _house_line := _closed(_house)
var _lean_to_line := _closed(_lean_to)
var _flame_line := _closed(_flame)


static func _closed(a: PackedVector2Array) -> PackedVector2Array:
	var b := a.duplicate()
	b.append(a[0])
	return b


func _draw_over() -> void:
	var side := _over.size.x
	var c := Vector2(side, side) * 0.5
	var r := DIAMETER * 0.5
	var font := FrontierHUD.serif()
	# the markers (the near ones first, the story's last: on top)
	for pass_i in 2:
		for i in marks:
			var k := mark_kind[i]
			if (k == Mark.STORY) != (pass_i == 1):
				continue
			var p := to_disc(mark_pos[i])
			var far := p.length() > r - HEAR_PIN
			if far:
				if k in PINNED:
					p = p.normalized() * (r - HEAR_PIN)          # (held on the ring: the way to it)
				else:
					continue
			_draw_mark(c + p, k, far)
	# the player in the middle: an arrow the way they face
	var fd := dir_on_disc(facing)
	var turn := atan2(fd.x, -fd.y)
	_over.draw_set_transform(c + Vector2(1.0, 1.4), turn)
	_over.draw_colored_polygon(_arrow, Color(0, 0, 0, 0.55))
	_over.draw_set_transform(c, turn)
	_over.draw_colored_polygon(_arrow, Color(1.0, 0.95, 0.82))
	_over.draw_polyline(_arrow_line, HudClassicMap.BRASS_DARK, 1.2, true)
	_over.draw_set_transform(Vector2.ZERO)
	# the ring: the classic frames' brass (ClassicSkin.ring, as round the portrait), a dark line at the map's edge
	var rr := r + RING * 0.5
	ClassicSkin.ring(_over, c, rr, RING - 2.0)
	_over.draw_arc(c, r + 0.5, 0.0, TAU, 96, Color(0.05, 0.035, 0.02, 0.9), 1.5, true)
	# small rivets round the ring, every 30 degrees between the letters
	for q in 12:
		var a := TAU * (q + 0.5) / 12.0
		var at := c + Vector2.from_angle(a) * rr
		_over.draw_circle(at, 1.6, HudClassicMap.BRASS_DARK)
		_over.draw_circle(at - Vector2(0.4, 0.4), 0.9, HudClassicMap.BRASS_HI)
	# N E S W on the ring where they lie (WorldClock's north: north is (-sin, -cos) of its offset, east a quarter on)
	var off := deg_to_rad(WorldClock.north_offset_deg())
	var n_w := Vector2(-sin(off), -cos(off))
	var e_w := Vector2(cos(off), -sin(off))
	for q in 4:
		var d := n_w if q == 0 else (e_w if q == 1 else (-n_w if q == 2 else -e_w))
		var at: Vector2 = c + dir_on_disc(d) * rr
		var nm: String = LETTERS[q]
		var fs := 15 if q == 0 else 12
		var tw := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		_over.draw_circle(at, 8.5 if q == 0 else 7.0, Color(0.07, 0.05, 0.03, 0.95))
		_over.draw_arc(at, 8.5 if q == 0 else 7.0, 0.0, TAU, 20, HudClassicMap.BRASS_HI if q == 0 else HudClassicMap.BRASS, 1.2, true)
		var tp := at + Vector2(-tw.x * 0.5, fs * 0.36)
		_over.draw_string(font, tp, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, NORTH if q == 0 else FrontierHUD.INK)


## A marker's glyph at `p` (our own: a diamond, a house, a lean-to, a lantern, a horseshoe, a dot, a flame).
func _draw_mark(p: Vector2, kind: int, far: bool) -> void:
	var o := _over
	var dark := Color(0.05, 0.035, 0.02, 0.85)
	match kind:
		Mark.STORY:
			var s := 6.5 if far else 7.5
			o.draw_set_transform(p, 0.0, Vector2(s, s))
			o.draw_colored_polygon(_diamond, Color(FrontierHUD.GOLD, 0.35))
			o.draw_polyline(_diamond_line, dark, 4.0 / s, true)
			o.draw_polyline(_diamond_line, FrontierHUD.GOLD, 2.0 / s, true)
			o.draw_set_transform(Vector2.ZERO)
			o.draw_circle(p, 2.0, FrontierHUD.GOLD)
		Mark.HOMESTEAD, Mark.HOME:
			var col := HOME_C if kind == Mark.HOMESTEAD else Color(0.72, 0.82, 1.0)
			o.draw_set_transform(p)
			if kind == Mark.HOMESTEAD:
				o.draw_polyline(_house_line, dark, 3.5, true)
				o.draw_colored_polygon(_house, col)
			else:
				o.draw_polyline(_lean_to_line, dark, 3.5, true)     # (where the player last slept: a lean-to)
				o.draw_colored_polygon(_lean_to, col)
			o.draw_set_transform(Vector2.ZERO)
			o.draw_line(p + Vector2(-1.4, 4), p + Vector2(-1.4, 0.6), dark, 1.6)
		Mark.CONTACT:
			o.draw_circle(p, 6.0, Color(CONTACT_C, 0.22))
			o.draw_circle(p, 3.6, dark)
			o.draw_circle(p, 2.6, CONTACT_C)
			o.draw_line(p + Vector2(0, -3.6), p + Vector2(0, -6.2), dark, 1.4)
		Mark.HORSE:
			o.draw_arc(p, 4.2, deg_to_rad(-20.0), deg_to_rad(200.0), 14, dark, 4.0, true)
			o.draw_arc(p, 4.2, deg_to_rad(-20.0), deg_to_rad(200.0), 14, HORSE_C, 2.2, true)
		Mark.FOE:
			o.draw_circle(p, 3.8, dark)
			o.draw_circle(p, 2.8, FOE)
		Mark.WARY:
			o.draw_arc(p, 3.6, 0.0, TAU, 14, dark, 3.2, true)
			o.draw_arc(p, 3.6, 0.0, TAU, 14, FOE.lerp(Color(1.0, 0.6, 0.3), 0.35), 1.6, true)
		Mark.WRECK:
			o.draw_set_transform(p)
			o.draw_polyline(_flame_line, dark, 3.0, true)
			o.draw_colored_polygon(_flame, WRECK_C)
			o.draw_set_transform(Vector2.ZERO)
			o.draw_circle(p + Vector2(0, 1.8), 1.8, Color(1.0, 0.9, 0.55))
