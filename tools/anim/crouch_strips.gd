extends SceneTree
## Side- and front-view strips of crouch <-> stand transitions (CROUCH_HANDS), rendered from the same cases and the
## same driver as tests/anim/test_crouch_transitions.gd (CrouchHarness: a fresh FrontierPlayer on a flat arena with a
## 1 m floor grid, so foot slide shows against the lines). Needs a window (not --headless):
##
##   Godot --fixed-fps 120 --path . --resolution 320x240 -s tools/anim/crouch_strips.gd -- --no-capture \
##       out=/tmp/strips cases='musket/run_W/*,musket/still/*' [step=6] [from=-0.1] [to=1.5] [cols=11] \
##       [tile=180x240] [set=override_crouch_crossfade=1]
##
## Per case: <out>/<case>_side.png and <out>/<case>_front.png, a tile every `step` physics frames (120 Hz; 6 = every
## 3rd frame at 60 fps) from `from` to `to` seconds around the toggle, `cols` tiles per row. Each tile is labelled
## with the time from the toggle, the lower-body state, the two heaviest lower clips with their weights, the pelvis
## height, the body speed and the crouch-change additive. Side view: from the character's right (+X); front view:
## from in front. The cameras follow the player (fixed offset), the floor grid does not.

var args := {}
var h: CrouchHarness
var views: Array = []          ## [{name, vp: SubViewport, cam: Camera3D, label: Label, tiles: Array}]
var step := 6
var t_from := -0.1
var t_to := 1.5
var cols := 11
var tile := Vector2i(180, 240)
var _toggle_i := -1
var _busy := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if "=" in s:
			args[s.get_slice("=", 0)] = s.substr(s.find("=") + 1)
	var out: String = args.get("out", "user://crouch_strips")
	DirAccess.make_dir_recursive_absolute(out)
	step = int(args.get("step", "6"))
	t_from = float(args.get("from", "-0.1"))
	t_to = float(args.get("to", "1.5"))
	cols = int(args.get("cols", "11"))
	if args.has("tile"):
		var p: PackedStringArray = String(args.tile).split("x")
		tile = Vector2i(int(p[0]), int(p[1]))
	var globs: PackedStringArray = String(args.get("cases", "musket/run_W/down")).split(",", false)
	await process_frame
	await process_frame
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.62, 0.70, 0.78)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.75, 0.78)
	e.ambient_light_energy = 0.8
	env.environment = e
	root.add_child(env)
	for nm in ["side", "front"]:
		var vp := SubViewport.new()
		vp.size = tile
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var cam := Camera3D.new()
		cam.fov = 40
		vp.add_child(cam)
		cam.current = true
		var lb := Label.new()
		lb.add_theme_font_size_override("font_size", 10)
		lb.add_theme_color_override("font_color", Color.BLACK)
		lb.position = Vector2(3, 1)
		lb.size = Vector2(tile.x - 6, 60)
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vp.add_child(lb)
		views.append({"name": nm, "vp": vp, "cam": cam, "label": lb, "tiles": []})
	h = CrouchHarness.new(self, null)
	h.player_props = _props(String(args.get("set", "")))
	h.ensure_arena()
	h.on_frame = _on_frame
	for c: Dictionary in CrouchHarness.all_cases():
		var hit := false
		for g in globs:
			if String(c.key).match(g):
				hit = true
		if not hit:
			continue
		for v: Dictionary in views:
			v.tiles = []
		_toggle_i = -1
		var r: Dictionary = await h.run_case(c)
		if r.has("error"):
			print("strips: %s: %s" % [c.key, r.error])
			continue
		await _drain()
		var s := CrouchHarness.analyze(r)
		print(CrouchHarness.line(s))
		var base := out.path_join(String(c.key).replace("/", "_"))
		for v: Dictionary in views:
			var img := _compose(v.tiles, String(c.key) + " (" + String(v.name) + ")")
			if img != null:
				img.save_png(base + "_%s.png" % v.name)
				print("saved ", ProjectSettings.globalize_path(base + "_%s.png" % v.name))
	quit()


func _drain() -> void:
	var n := 0
	while _busy and n < 30:
		await process_frame
		n += 1


## Harness hook: after each recorded pose update. Captures both views every `step` frames inside the window.
func _on_frame(hh: CrouchHarness, rec: Dictionary) -> void:
	if _toggle_i < 0 and rec.ph != "pre":
		_toggle_i = int(rec.i)
	var i := int(rec.i)
	var hz := float(Engine.physics_ticks_per_second)
	var t: float
	if _toggle_i < 0:
		# PRE: time from the end of PRE (the toggle comes PRE_S after its first frame)
		t = (i - int(CrouchHarness.PRE_S * hz)) / hz
	else:
		t = (i - _toggle_i) / hz
	if t < t_from - 1e-6 or t > t_to + 1e-6:
		return
	var k := roundi(t * hz)
	if posmod(k, step) != 0:
		return
	var p: FrontierPlayer = hh.player
	var center := p.global_position + Vector3(0, 0.75, 0)
	var right := p.global_basis.x
	var fwd := -p.global_basis.z
	for v: Dictionary in views:
		var cam: Camera3D = v.cam
		var off: Vector3 = (right * 3.4 + Vector3.UP * 0.35) if v.name == "side" else (fwd * 3.4 + Vector3.UP * 0.35)
		cam.global_position = center + off
		cam.look_at(center, Vector3.UP)
		var sl: Array = rec.slots.duplicate()
		sl.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]))
		var clips: Array = []
		for j in mini(2, sl.size()):
			clips.append("%s %.2f" % [String(sl[j][0]).trim_prefix("actor_b-p-"), float(sl[j][1])])
		var cc := ""
		if not (rec.cc as Array).is_empty():
			cc = " +" + String(rec.cc[0][1]).trim_prefix("actor_b-p-").get_slice("-", 0)
		(v.label as Label).text = "%+.2fs %s %s\n%s\npelvis %.2f v %.1f%s" % [t, rec.state, "C" if rec.crouched else "S",
				"\n".join(clips), float(rec.py), float(rec.v), cc]
	_busy = true
	await RenderingServer.frame_post_draw
	for v: Dictionary in views:
		var img: Image = (v.vp as SubViewport).get_texture().get_image()
		(v.tiles as Array).append(img)
	_busy = false


func _compose(tiles: Array, title: String) -> Image:
	if tiles.is_empty():
		return null
	var rows := ceili(tiles.size() / float(cols))
	var head := 0
	var img := Image.create(cols * tile.x + (cols - 1) * 2, rows * tile.y + (rows - 1) * 2 + head, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.1, 0.1, 0.1))
	for k in tiles.size():
		var t: Image = tiles[k]
		t.convert(Image.FORMAT_RGBA8)
		var x := (k % cols) * (tile.x + 2)
		var y := head + (k / cols) * (tile.y + 2)
		img.blit_rect(t, Rect2i(Vector2i.ZERO, tile), Vector2i(x, y))
	return img


static func _props(spec: String) -> Dictionary:
	var out := {}
	for kv in spec.split(",", false):
		var k := kv.get_slice("=", 0)
		var v := kv.substr(kv.find("=") + 1) if "=" in kv else "1"
		if v in ["1", "true"]:
			out[k] = true
		elif v in ["0", "false"]:
			out[k] = false
		elif v.is_valid_float():
			out[k] = float(v)
		else:
			out[k] = v
	return out
