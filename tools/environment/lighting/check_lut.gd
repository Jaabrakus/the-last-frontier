extends SceneTree
## Colour-grade LUT checks (look-dev spec 4.6, acceptance A5). Headless runs the data checks; a
## windowed run also renders through Godot's tonemapper:
##
##   Godot --headless --path . -s tools/environment/lighting/check_lut.gd
##   Godot --path . --resolution 640x240 -s tools/environment/lighting/check_lut.gd
##
## Data:
##   identity     grade() with every strength at 0 returns its input within 1/255 (17^3 grid)
##   id_texels    an identity LUT's texels match their texel coordinates within 1/255
##   neutral      the default grade keeps greys grey within 1/255 (33 steps)
##   monotonic    the default grade of a grey ramp never decreases
##   baked        the baked LUT for the current parameters exists and loads as a 64^3 Texture3D
## Rendered (window only; unshaded patches, linear tonemap, so the LUT is the only change):
##   render_id    an identity LUT renders every patch within 1/255 of no LUT at all (checks the
##                texel convention described in grade_lut.gd)
##   render_grade the baked LUT renders every patch within 2/255 of grade() on the CPU
## Ends with LUT CHECK PASSED / FAILED.

const GradeLut := preload("res://scripts/world/env/grade_lut.gd")

var failures := PackedStringArray()
var vp: SubViewport
var env: Environment
var colors: Array[Color] = []


func _initialize() -> void:
	_data_checks()
	if DisplayServer.get_name() != "headless":
		await _render_checks()
	else:
		print("skip render checks (headless)")
	if failures.is_empty():
		print("LUT CHECK PASSED")
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("LUT CHECK FAILED (%d)" % failures.size())
	quit(0 if failures.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)


func _data_checks() -> void:
	var idp := GradeLut.identity_params()
	var worst := 0.0
	for r in 17:
		for g in 17:
			for b in 17:
				var c := Color(r / 16.0, g / 16.0, b / 16.0)
				var o := GradeLut.grade(c, idp)
				worst = maxf(worst, maxf(absf(o.r - c.r), maxf(absf(o.g - c.g), absf(o.b - c.b))))
	_expect(worst <= 1.0 / 255.0, "identity: grade() with zero strengths differs by at most %.2f/255" % (worst * 255.0))

	worst = 0.0
	var n := 32
	for b in [0, 1, 15, 30, 31]:
		var img := GradeLut.slice_image(n, b, idp)
		for g in [0, 7, 31]:
			for r in n:
				var px := img.get_pixel(r, g)
				worst = maxf(worst, absf(px.r - GradeLut.texel_coord(r, n)))
				worst = maxf(worst, absf(px.g - GradeLut.texel_coord(g, n)))
				worst = maxf(worst, absf(px.b - GradeLut.texel_coord(b, n)))
	_expect(worst <= 1.0 / 255.0 + 1e-6, "id_texels: identity LUT texels within %.2f/255 of their coordinates" % (worst * 255.0))

	worst = 0.0
	var prev := -1.0
	var mono := true
	for i in 33:
		var v := i / 32.0
		var o := GradeLut.grade(Color(v, v, v))
		worst = maxf(worst, maxf(absf(o.r - o.g), absf(o.g - o.b)))
		var l := (o.r + o.g + o.b) / 3.0
		mono = mono and l >= prev - 1e-6
		prev = l
	_expect(worst <= 1.0 / 255.0, "neutral: default grade keeps greys within %.2f/255" % (worst * 255.0))
	_expect(mono, "monotonic: default grade of a grey ramp never decreases")

	var path := GradeLut.baked_path()
	var tex: Texture3D = load(path) if ResourceLoader.exists(path) else null
	_expect(tex != null and tex.get_width() == GradeLut.BAKED_SIZE and tex.get_depth() == GradeLut.BAKED_SIZE,
			"baked: %s loads as a %d^3 Texture3D" % [path, GradeLut.BAKED_SIZE])


func _render_checks() -> void:
	for i in 17:
		colors.append(Color(i / 16.0, i / 16.0, i / 16.0))
	for c in [Color(0.63, 0.17, 0.13), Color(0.36, 0.46, 0.35), Color(0.4, 0.46, 0.24), Color(0.63, 0.53, 0.41),
			Color(0.47, 0.56, 0.72), Color(0.84, 0.82, 0.76), Color(0.2, 0.25, 0.17), Color(0.95, 0.9, 0.77)]:
		colors.append(c)
	vp = SubViewport.new()
	vp.size = Vector2i(25 * 16, 16)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.0                       # 1 m tall, 25 m wide: one 16x16 px patch per metre.
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.position = Vector3(12.5, 0, 5)
	vp.add_child(cam)
	cam.current = true
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	for i in colors.size():
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = colors[i]
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(1, 1)
		q.mesh = qm
		q.material_override = m
		q.position = Vector3(i + 0.5, 0, 0)
		vp.add_child(q)

	var ref := await _capture(null)
	var ident := await _capture(GradeLut.build(GradeLut.BAKED_SIZE, GradeLut.identity_params()))
	var worst := 0
	for i in colors.size():
		worst = maxi(worst, _diff(ref[i], ident[i]))
	_expect(worst <= 1, "render_id: identity LUT renders within %d/255 of no LUT" % worst)

	var path := GradeLut.baked_path()
	if ResourceLoader.exists(path):
		var graded := await _capture(load(path))
		worst = 0
		var at := 0
		for i in colors.size():
			var want := GradeLut.grade(ref[i])
			var d := _diff(want, graded[i])
			if d > worst:
				worst = d
				at = i
		_expect(worst <= 2, "render_grade: baked LUT renders within %d/255 of grade() (worst patch %d)" % [worst, at])


func _capture(lut: Texture3D) -> Array[Color]:
	env.adjustment_enabled = lut != null
	env.adjustment_color_correction = lut
	for k in 6:
		await process_frame
	var img := vp.get_texture().get_image()
	var out: Array[Color] = []
	for i in colors.size():
		out.append(img.get_pixel(i * 16 + 8, 8))
	return out


func _diff(a: Color, b: Color) -> int:
	return maxi(absi(roundi(a.r * 255) - roundi(b.r * 255)), maxi(absi(roundi(a.g * 255) - roundi(b.g * 255)),
			absi(roundi(a.b * 255) - roundi(b.b * 255))))
