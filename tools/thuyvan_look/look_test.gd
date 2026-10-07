extends SceneTree
## The Thủy Vân shaders together in one small look scene, in each look direction (ThuyVanLook, data/thuyvan/
## look_directions.json): a slab of painted ground with a gorge (tv_terrain.gdshader on a derived splat), its river over
## the white stones (tv_river.gdshader), a fall off the gorge's headwall with spray and a pool ring, mist bands at the
## direction's heights (tv_card.gdshader), karst towers with pines on their seats and a needle in the river
## (tv_rock.gdshader), four fog-stepped backdrop ranks (tv_rock_far.gdshader), a stilt house with a lantern post and
## banner, broadleaf trees, ferns and shrubs, under the direction's painted sky (tv_sky.gdshader), fog and grade. A
## stand-in landform at R1's heights (the plateau at ~212 m, the river at 140), not the T4 layout. Needs a window:
##
##   Godot --path . --resolution 1920x1080 -s tools/thuyvan_look/look_test.gd -- out=DIR [dirs=a,b] [karst=rock|paint]
##       [still=1] [w=1920] [h=1080] [hour=H]
##
## Writes DIR/shader_test_<direction>.png for each direction (default all three) and DIR/shader_test_triptych.png
## (stacked, as PAINT's board_diorama_triptych.png), and prints each direction's mid-grey check: a 0.5 sRGB card on the
## plateau, lit by the direction, as it reads on screen ("GREY <direction> <value>"; style guide 5.4: 0.55-0.60 at noon).
## `still=1` sets the river's flow_scale to 0 (the S1 still state); `hour=H` shows the day cycle's blend at that hour
## instead of the directions (shader_test_h<H>.png).

const Kit := preload("res://scripts/thuyvan/look/thuyvan_kit.gd")
const Look := preload("res://scripts/thuyvan/look/thuyvan_look.gd")
const TERRAIN := "res://assets/thuyvan/paint/terrain/tv_terrain_albedo_array.webp"
const WATER := "res://assets/thuyvan/paint/water/"
const ROCK_MAT := "res://assets/thuyvan/rock/materials/rock_karst.tres"
const PAINT_KARST := "res://assets/thuyvan/paint/rock/tv_karst_face_16m.png"
const PAINT_KARST_N := "res://assets/thuyvan/paint/rock/tv_karst_face_16m_normal.png"

const LEVEL := 140.0          ## the river's surface
const W_RIVER := 16.0         ## half width of the channel at the surface
const SPACING := 2.5          ## the ground mesh's grid (m)
const RECT := Rect2(-420.0, -900.0, 920.0, 1150.0)   ## x0, z0, width, depth of the detailed ground
const FALL_Z := -380.0        ## the headwall's foot
const CAM_POS := Vector3(22.0, 256.0, 175.0)
const CAM_AT := Vector3(14.0, 168.0, -380.0)
const GREY_AT := Vector3(-260.0, 0.0, 160.0)

var _out := ""
var _dirs: Array = []
var _karst := "rock"
var _still := false
var _msaa := true
var _debug := 0
var _hour := -1.0
var _w := 1920
var _h := 1080
var _world: Node3D
var _env: Environment
var _sun: DirectionalLight3D
var _cam: Camera3D
var _ui: CanvasLayer
var _caption: Label
var _river_mat: ShaderMaterial
var _mist: Node3D
var _cards: Array[ShaderMaterial] = []
var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
		elif a.begins_with("dirs="):
			_dirs = Array(a.substr(5).split(","))
		elif a.begins_with("karst="):
			_karst = a.substr(6)
		elif a.begins_with("still="):
			_still = a.substr(6) == "1"
		elif a.begins_with("hour="):
			_hour = float(a.substr(5))
		elif a.begins_with("msaa="):
			_msaa = a.substr(5) != "0"
		elif a.begins_with("debug="):
			_debug = int(a.substr(6))
		elif a.begins_with("w="):
			_w = int(a.substr(2))
		elif a.begins_with("h="):
			_h = int(a.substr(2))
	if _out.is_empty() or DisplayServer.get_name() == "headless":
		push_error("look_test: needs out=DIR and a window")
		quit(1)
		return
	if _dirs.is_empty():
		_dirs = Look.directions()
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = Vector2i(_w, _h)
	root.msaa_3d = Viewport.MSAA_4X if _msaa else Viewport.MSAA_DISABLED
	if not _msaa:
		root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	root.use_debanding = true
	_rng.seed = 1603
	_run.call_deferred()


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	_stage()
	_ground()
	_river()
	_fall()
	_rocks()
	_village()
	_plants()
	_grey_card()
	print("LOOK TEST built in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	var shots: Array[Image] = []
	var names: Array = []
	if _hour >= 0.0:
		var look := Look.at_hour(_hour)
		shots.append(await _shot(look, "Day cycle at %05.2f h (%s)" % [_hour, " + ".join(PackedStringArray(look.keys))]))
		names.append("h%05.2f" % _hour)
	else:
		for d: String in _dirs:
			var look := Look.resolve(d)
			if look.is_empty():
				continue
			var title := String(Look.data().looks[d].title)
			shots.append(await _shot(look, title + ("  (still river)" if _still else "")))
			names.append(d)
	for i in shots.size():
		var p := "%s/shader_test_%s%s.png" % [_out, names[i], "_still" if _still else ""]
		shots[i].save_png(p)
		print("LOOK TEST -> ", p)
	if shots.size() > 1:
		var sheet := Image.create(_w, _h * shots.size(), false, Image.FORMAT_RGB8)
		for i in shots.size():
			shots[i].convert(Image.FORMAT_RGB8)
			sheet.blit_rect(shots[i], Rect2i(0, 0, _w, _h), Vector2i(0, i * _h))
		var p := "%s/shader_test_triptych%s.png" % [_out, "_still" if _still else ""]
		sheet.save_png(p)
		print("LOOK TEST -> ", p)
	quit(0)


## One direction: the look applied, the mist bands at its heights, the hero shot, then the grey check.
func _shot(look: Dictionary, title: String) -> Image:
	Look.apply(look, _env, _sun, true)
	_mist_bands(look)
	_river_mat.set_shader_parameter("sky_tint", look.water_sky_tint)
	_cam.global_position = CAM_POS
	_cam.look_at(CAM_AT, Vector3.UP)
	_cam.fov = 50.0
	_caption.text = title
	_caption.get_parent().visible = true
	for i in 45:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	# the mid-grey check: straight down on the card from 6 m
	_caption.get_parent().visible = false
	var g := GREY_AT
	g.y = _height(g.x, g.z) + 0.2
	_cam.global_position = g + Vector3(0.0, 6.0, 0.01)
	_cam.look_at(g, Vector3.UP)
	_cam.fov = 20.0
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var gi := root.get_texture().get_image()
	var acc := Vector3.ZERO
	var n := 0
	for y in range(_h / 2 - 20, _h / 2 + 20, 4):
		for x in range(_w / 2 - 20, _w / 2 + 20, 4):
			var c := gi.get_pixel(x, y)
			acc += Vector3(c.r, c.g, c.b)
			n += 1
	acc /= maxf(n, 1)
	print("GREY %s %.3f (r %.3f g %.3f b %.3f)" % [look.key, (acc.x + acc.y + acc.z) / 3.0, acc.x, acc.y, acc.z])
	return img


# --- the stage -----------------------------------------------------------------------------------------------------

func _stage() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	var sh: Dictionary = Look.data().get("render", {}).get("shadows", {})
	_sun.directional_shadow_max_distance = float(sh.get("max_distance_m", 1500.0))
	_sun.directional_shadow_split_1 = 0.04
	_sun.directional_shadow_split_2 = 0.12
	_sun.directional_shadow_split_3 = 0.35
	_sun.shadow_blur = float(sh.get("blur", 1.5))
	_sun.shadow_bias = 0.08
	_sun.shadow_normal_bias = 1.5
	_world.add_child(_sun)
	_env = Environment.new()
	var we := WorldEnvironment.new()
	we.environment = _env
	_world.add_child(we)
	_cam = Camera3D.new()
	_cam.near = 0.3
	_cam.far = 14000.0
	_world.add_child(_cam)
	_cam.make_current()
	_ui = CanvasLayer.new()
	root.add_child(_ui)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.12, 0.72)
	sb.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	_caption = Label.new()
	_caption.add_theme_font_override("font", UiFonts.sans(600))
	_caption.add_theme_font_size_override("font_size", 22)
	_caption.add_theme_color_override("font_color", Color(0.96, 0.95, 0.92))
	panel.add_child(_caption)
	panel.position = Vector2(16, 14)
	_ui.add_child(panel)


# --- the landform --------------------------------------------------------------------------------------------------

static func river_x(z: float) -> float:
	return 30.0 + 22.0 * sin(z / 150.0) + 8.0 * sin(z / 53.0)


## The terraced hill east of the gorge: centre, radius, rise.
const HILL := Vector3(250.0, -170.0, 150.0)
const HILL_RISE := 42.0
const STEP_M := 3.0


func _hill(x: float, z: float) -> float:
	var r := Vector2(x - HILL.x, z - HILL.y).length()
	return HILL_RISE * exp(-pow(r / HILL.z, 2.0))


func _plateau(x: float, z: float) -> float:
	var east := x > river_x(z)
	var h := (212.0 if not east else 206.0) + 3.0 * sin(x / 37.0 + z / 51.0) + 2.0 * sin(z / 23.0 - x / 71.0)
	h += 26.0 * smoothstep(-620.0, -950.0, z)
	if east:
		var hill := _hill(x, z)
		if hill > 0.3:
			var q := floorf(hill / STEP_M)
			var f := hill / STEP_M - q
			h += (q + smoothstep(0.72, 1.0, f)) * STEP_M
	return h


func _gorge(x: float, z: float) -> float:
	var d := absf(x - river_x(z))
	var g: float
	if d < W_RIVER:
		g = 133.0 + 6.6 * pow(d / W_RIVER, 1.6)
	elif d < W_RIVER + 5.0:
		g = 139.6 + (d - W_RIVER) / 5.0 * 3.0
	else:
		var t := (d - W_RIVER - 5.0) / 28.0
		g = 142.6 + t * 95.0 + 5.0 * sin(t * 9.0) * clampf(1.0 - t, 0.0, 1.0)
	# the headwall: north of the fall's foot the gorge's floor climbs out over 30 m
	g += (1.0 - smoothstep(FALL_Z - 30.0, FALL_Z, z)) * 140.0
	return g


func _height(x: float, z: float) -> float:
	return minf(_plateau(x, z), _gorge(x, z))


## The derived splat (vista_spec 4) for the look scene, slices 0-11 (terrain_slices.json).
func _weights(x: float, z: float, h: float, slope: float) -> PackedFloat32Array:
	var w := PackedFloat32Array()
	w.resize(12)
	var d := absf(x - river_x(z))
	var n1 := 0.5 + 0.5 * sin(x * 0.043 + z * 0.031) * sin(z * 0.052 - x * 0.017)
	var n2 := 0.5 + 0.5 * sin(x * 0.11 - z * 0.07) * sin(z * 0.09 + x * 0.05)
	if h < LEVEL + 4.0:
		w[7] = 1.0                                         # white stone and gravel within 4 m of the water
		if h < LEVEL - 2.2:
			w[9] = 0.35 * n2                               # a little bank silt in the deep channel
	else:
		var hill := _hill(x, z) if x > river_x(z) else 0.0
		if slope > 45.0 or (slope > 30.0 and hill <= 3.0):
			w[10] = 1.0                                    # walls: the shader's cliff face takes it
		elif hill > 3.0:
			var f := fposmod(hill / STEP_M, 1.0)
			w[1] = 1.0                                     # terrace rice on the steps
			if f > 0.74:
				w[4] = 0.6                                 # laterite and grass on the risers
				w[0] = 0.6
				w[1] = 0.1
		else:
			w[0] = 0.55 + 0.45 * n1                        # grass and meadow in patches
			w[11] = 1.0 - n1
			if n2 > 0.72 and d > 70.0:
				w[2] = (n2 - 0.72) * 3.0                   # forest floor under the groves
			var fall_r := Vector2(x - river_x(FALL_Z), z - FALL_Z).length()
			if fall_r < 70.0:
				w[8] = 1.4 * (1.0 - fall_r / 70.0)         # moss and fern by the fall
		# the path along the west rim
		var px := river_x(z) - 62.0 + 6.0 * sin(z / 25.0)
		if x < river_x(z) and absf(x - px) < 2.4:
			w[3] = 2.0 * (1.0 - absf(x - px) / 2.4)
	return w


func _ground() -> void:
	var nx := int(RECT.size.x / SPACING) + 1
	var nz := int(RECT.size.y / SPACING) + 1
	var hs := PackedFloat32Array()
	hs.resize(nx * nz)
	for j in nz:
		var z := RECT.position.y + j * SPACING
		for i in nx:
			hs[j * nx + i] = _height(RECT.position.x + i * SPACING, z)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	verts.resize(nx * nz)
	normals.resize(nx * nz)
	var sp := [Image.create(nx, nz, false, Image.FORMAT_RGBA8), Image.create(nx, nz, false, Image.FORMAT_RGBA8),
			Image.create(nx, nz, false, Image.FORMAT_RGBA8)]
	for j in nz:
		for i in nx:
			var k := j * nx + i
			var hl := hs[j * nx + maxi(i - 1, 0)]
			var hr := hs[j * nx + mini(i + 1, nx - 1)]
			var hd := hs[maxi(j - 1, 0) * nx + i]
			var hu := hs[mini(j + 1, nz - 1) * nx + i]
			var nrm := Vector3(hl - hr, 2.0 * SPACING, hd - hu).normalized()
			var x := RECT.position.x + i * SPACING
			var z := RECT.position.y + j * SPACING
			verts[k] = Vector3(x, hs[k], z)
			normals[k] = nrm
			var w := _weights(x, z, hs[k], rad_to_deg(acos(clampf(nrm.y, -1.0, 1.0))))
			var m := 0.0
			for q in 12:
				m = maxf(m, w[q])
			var s := 1.0 / maxf(m, 1e-4)   # 8-bit: scale up so the strongest is 1 (the shader normalises)
			for q in 3:
				(sp[q] as Image).set_pixel(i, j, Color(w[q * 4] * s, w[q * 4 + 1] * s, w[q * 4 + 2] * s, w[q * 4 + 3] * s))
	var idx := PackedInt32Array()
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			idx.append_array([a, a + 1, a + nx, a + 1, a + nx + 1, a + nx])
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/thuyvan/tv_terrain.gdshader")
	mat.set_shader_parameter("albedo_array", load(TERRAIN))
	for q in 3:
		mat.set_shader_parameter("splat%d" % q, ImageTexture.create_from_image(sp[q]))
	mat.set_shader_parameter("splat_rect", Vector4(RECT.position.x - SPACING * 0.5, RECT.position.y - SPACING * 0.5,
			nx * SPACING, nz * SPACING))
	mat.set_shader_parameter("fallback_slice", 11)
	_add_mesh(verts, normals, idx, mat, "Ground")
	# the backdrop: the plateau carried out to 6 km on a coarse grid, sunk well under the detailed slab inside it
	var bv := PackedVector3Array()
	var bn := PackedVector3Array()
	var bi := PackedInt32Array()
	var step := 100.0
	var cnt := 121
	for j in cnt:
		for i in cnt:
			var x := -6000.0 + i * step
			var z := -6000.0 + j * step
			var inside := RECT.grow(-60.0).has_point(Vector2(x, z))
			var h := 90.0 if inside else _plateau(x, z) + 10.0 * sin(x / 410.0) * sin(z / 330.0) - 0.5
			bv.append(Vector3(x, h, z))
			bn.append(Vector3.UP)
	for j in cnt - 1:
		for i in cnt - 1:
			var a := j * cnt + i
			bi.append_array([a, a + 1, a + cnt, a + 1, a + cnt + 1, a + cnt])
	_add_mesh(bv, bn, bi, mat, "Backdrop")


func _add_mesh(verts: PackedVector3Array, normals: PackedVector3Array, idx: PackedInt32Array, mat: Material,
		nm: String, colors := PackedColorArray(), uv := PackedVector2Array(), uv2 := PackedVector2Array()) -> MeshInstance3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = idx
	if not colors.is_empty():
		arrays[Mesh.ARRAY_COLOR] = colors
	if not uv.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = uv
	if not uv2.is_empty():
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = mesh
	mi.material_override = mat
	_world.add_child(mi)
	return mi


# --- the river, the white stones -----------------------------------------------------------------------------------

func _river() -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	var across := 9
	var rows := 0
	var z := 250.0
	while z >= FALL_Z - 14.0:
		var cx := river_x(z)
		var dxdz := (river_x(z + 0.5) - river_x(z - 0.5))
		var f := Vector2(dxdz, 1.0).normalized()          # downstream: south, away from the fall
		var side := Vector3(f.y, 0.0, -f.x)
		var white := smoothstep(FALL_Z + 60.0, FALL_Z + 6.0, z)
		for a in across:
			var u := float(a) / float(across - 1)
			var p := Vector3(cx, LEVEL, z) + side * lerpf(-W_RIVER - 8.0, W_RIVER + 8.0, u)
			verts.append(p)
			normals.append(Vector3.UP)
			uv.append(Vector2(u, z))
			uv2.append(f)
			colors.append(Color(0.0, white, 0.0))
		rows += 1
		z -= 4.0
	for r in rows - 1:
		for a in across - 1:
			var i := r * across + a
			idx.append_array([i, i + across, i + 1, i + 1, i + across, i + across + 1])
	_river_mat = ShaderMaterial.new()
	_river_mat.shader = load("res://shaders/thuyvan/tv_river.gdshader")
	_river_mat.set_shader_parameter("ramp", load(WATER + "tv_river_ramp.png"))
	_river_mat.set_shader_parameter("flow_tex", load(WATER + "tv_river_flow.png"))
	_river_mat.set_shader_parameter("foam_tex", load(WATER + "tv_river_foam.png"))
	_river_mat.set_shader_parameter("flow_scale", 0.0 if _still else 1.0)
	_river_mat.set_shader_parameter("debug_view", _debug)
	var mi := _add_mesh(verts, normals, idx, _river_mat, "River", colors, uv, uv2)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the white stones of Đá Trắng: along both edges, in the shallows and on the gravel, a few in the channel
	var ps := Kit.scene(Kit.ROCK_DIR + "white_stones.glb")
	if ps == null:
		return
	var src := ps.instantiate()
	var meshes: Array[Mesh] = []
	for m in Kit._meshes(src):
		meshes.append(m.mesh)
	src.free()
	for i in 360:
		var sz := _rng.randf_range(FALL_Z + 20.0, 240.0)
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var dd := _rng.randf_range(W_RIVER - 7.0, W_RIVER + 4.0) if _rng.randf() < 0.85 else _rng.randf_range(0.0, W_RIVER)
		var x := river_x(sz) + side * dd
		var k := clampi(int(pow(_rng.randf(), 0.7) * meshes.size()), 0, meshes.size() - 1)
		var st := MeshInstance3D.new()
		st.mesh = meshes[k]
		var sc := _rng.randf_range(0.9, 2.4)
		st.scale = Vector3.ONE * sc
		st.position = Vector3(x, _height(x, sz) - 0.08 * sc, sz)
		st.rotation.y = _rng.randf() * TAU
		_world.add_child(st)


# --- the fall -----------------------------------------------------------------------------------------------------

func _card_mat(tex: String, scroll := Vector2.ZERO, alpha := 1.0, strength := 1.0, extra := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/thuyvan/tv_card.gdshader")
	m.set_shader_parameter("card_tex", load(tex))
	m.set_shader_parameter("scroll", scroll)
	m.set_shader_parameter("alpha_scale", alpha)
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("flow_scale", 0.0 if _still else 1.0)
	for k: String in extra:
		m.set_shader_parameter(k, extra[k])
	Look.register_card(m)
	_cards.append(m)
	return m


## A card through `path` (its centre line, bottom to top), `width` m wide across `right`, facing `facing`; UV v 0 at
## the top, repeating `vrep`; u across, repeating `urep`.
func _strip(path: PackedVector3Array, width: float, right: Vector3, facing: Vector3, mat: Material, vrep := 1.0,
		urep := 1.0) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var segs := path.size() - 1
	for j in path.size():
		var t := float(j) / segs
		for i in 2:
			verts.append(path[j] + right.normalized() * (float(i) - 0.5) * width)
			normals.append(facing.normalized())
			uv.append(Vector2(float(i) * urep, (1.0 - t) * vrep))
	for j in segs:
		var a := j * 2
		idx.append_array([a, a + 2, a + 1, a + 1, a + 2, a + 3])
	var mi := _add_mesh(verts, normals, idx, mat, "Card", PackedColorArray(), uv)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## A flat card from `bottom` up to `top`.
func _card(bottom: Vector3, top: Vector3, width: float, facing: Vector3, mat: Material, vrep := 1.0, urep := 1.0,
		segs := 1) -> MeshInstance3D:
	var path := PackedVector3Array()
	for j in segs + 1:
		path.append(bottom.lerp(top, float(j) / segs))
	return _strip(path, width, (top - bottom).cross(facing), facing, mat, vrep, urep)


## The fall's centre line down the headwall at x, `out` m in front of the rock: from the pool up the wall to the lip,
## then a few metres back over the top (the water coming over).
func _fall_path(x: float, out: float) -> PackedVector3Array:
	var path := PackedVector3Array()
	var top := _plateau(x, FALL_Z - 40.0)
	var n := 14
	for j in n + 1:
		var y := lerpf(LEVEL - 0.5, top - 0.6, float(j) / n)
		# the wall's z at height y: the gorge floor rises from FALL_Z northward (binary search)
		var za := FALL_Z + 6.0
		var zb := FALL_Z - 40.0
		for k in 24:
			var zm := (za + zb) * 0.5
			if _gorge(x, zm) < y:
				za = zm
			else:
				zb = zm
		path.append(Vector3(x, y, za + out))
	path.append(Vector3(x, top + 0.5, path[n].z - 5.0))
	return path


func _fall() -> void:
	var fx := river_x(FALL_Z) + 2.0
	var wid := 28.0
	var body := _fall_path(fx, 2.2)
	var fall_h := body[body.size() - 1].y - body[0].y
	var face := Vector3(0.0, 0.2, 1.0).normalized()
	var right := Vector3(1.0, 0.0, 0.0)
	var vrep := fall_h / (wid * 2.0)
	var mpu := fall_h / vrep
	_strip(body, wid, right, face, _card_mat(WATER + "tv_fall_body.png", Vector2(0.0, -0.8 / mpu), 1.7, 1.3), vrep)
	_strip(_fall_path(fx, 2.8), wid * 0.85, right, face,
			_card_mat(WATER + "tv_fall_streaks.png", Vector2(0.0, -1.4 / mpu), 1.4, 1.35), vrep * 1.3)
	for s in [-1.0, 1.0]:
		var edge := _fall_path(fx + s * wid * 0.48, 3.2)
		var erep := fall_h / (wid * 0.9)
		_strip(edge, wid * 0.22, right, face, _card_mat(WATER + "tv_fall_edge_foam.png", Vector2(0.0, -1.0 / (fall_h / erep)),
				1.0, 1.1), erep)
	# the lip: a short foam band across the top
	var lip := body[body.size() - 2]
	_card(lip + Vector3(0, -2.5, 1.5), lip + Vector3(0, 1.2, 0.5), wid * 1.05, face,
			_card_mat(WATER + "tv_fall_edge_foam.png", Vector2(0.4, 0.0), 0.9, 1.1), 1.0, 3.0)
	# spray puffs at the foot (billboards), the pool's foam ring, mist rising
	var spray := _card_mat(WATER + "tv_fall_spray.png", Vector2.ZERO, 0.9, 1.05,
			{"atlas_grid": Vector2(2, 2), "billboard": true, "proximity_fade": 6.0})
	for i in 6:
		var p := Vector3(fx + _rng.randf_range(-12.0, 12.0), LEVEL + _rng.randf_range(4.0, 14.0), FALL_Z + _rng.randf_range(4.0, 14.0))
		var c := _quad(p, _rng.randf_range(16.0, 26.0), spray)
		c.set_instance_shader_parameter("atlas_cell", float(i % 4))
	var ring := _card_mat(WATER + "tv_pool_foam_ring.png", Vector2.ZERO, 0.95, 1.05, {"proximity_fade": 0.0})
	var rm := _quad(Vector3(fx, LEVEL + 0.15, FALL_Z + 12.0), 34.0, ring)
	rm.rotation_degrees.x = -90.0
	var puffs := _card_mat(WATER + "tv_mist_puffs.png", Vector2.ZERO, 0.75, 1.0,
			{"atlas_grid": Vector2(2, 2), "billboard": true, "proximity_fade": 8.0})
	for i in 5:
		var p := Vector3(fx + _rng.randf_range(-20.0, 20.0), LEVEL + _rng.randf_range(16.0, 38.0), FALL_Z + _rng.randf_range(8.0, 30.0))
		var c := _quad(p, _rng.randf_range(24.0, 40.0), puffs)
		c.set_instance_shader_parameter("atlas_cell", float((i + 1) % 4))


## A square card of `size` m centred on `at`, facing +Z (billboards turn it).
func _quad(at: Vector3, size: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	_world.add_child(mi)
	return mi


## The direction's mist bands (palettes.json mist_bands_m). Bands under the plateau lie in the gorge as flat layers of
## soft puffs (seen from above, a standing card would be cut by both walls); bands above it stand as long cards facing
## the camera round the far towers' waists, as on the sheets.
func _mist_bands(look: Dictionary) -> void:
	if _mist:
		_mist.queue_free()
	_mist = Node3D.new()
	_world.add_child(_mist)
	var col: Color = look.get("mist_color", Color(0.9, 0.93, 0.93))
	var bands: Array = look.get("mist_bands_m", [])
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for bi in bands.size():
		var lo := float(bands[bi][0])
		var hi := float(bands[bi][1])
		var mid := (lo + hi) * 0.5
		if mid < 200.0:
			var puffs := _card_mat(WATER + "tv_mist_puffs.png", Vector2.ZERO, 0.5, 1.0,
					{"atlas_grid": Vector2(2, 2), "proximity_fade": 10.0, "near_fade": 30.0, "light_tint_amount": 0.0,
					"card_color": col})
			for i in 26:
				var z := rng.randf_range(FALL_Z + 10.0, 130.0)
				var y := lerpf(lo, hi, rng.randf())
				var at := Vector3(river_x(z) + rng.randf_range(-10.0, 10.0), y, z)
				var q := _quad(at, rng.randf_range(50.0, 90.0), puffs)
				q.rotation_degrees = Vector3(-90.0, rng.randf() * 360.0, 0.0)
				q.set_instance_shader_parameter("atlas_cell", float(i % 4))
				q.reparent(_mist)
			continue
		var hgt := (hi - lo) * 2.2
		for k in 5:
			var z := lerpf(-650.0, -1600.0, float(k) / 4.0)
			var cx := lerpf(-500.0, 500.0, rng.randf())
			var width := 500.0 + 250.0 * k
			var tex := WATER + "tv_mist_band_%s.png" % ["a", "b", "c"][(bi + k) % 3]
			var m := _card_mat(tex, Vector2(0.5 / width * 2.0, 0.0), 0.55, 1.0,
					{"end_fade": 0.25, "proximity_fade": 20.0, "near_fade": 30.0, "uv_scale": Vector2(2.0, 1.0),
					"light_tint_amount": 0.0, "card_color": col})
			var at := Vector3(cx, mid, z)
			var face := (CAM_POS - at)
			face.y = 0.0
			face = face.normalized()
			var c := _card(at - Vector3.UP * hgt * 0.5, at + Vector3.UP * hgt * 0.5, width, face, m, 1.0, 1.0, 1)
			c.reparent(_mist)


# --- the rocks -----------------------------------------------------------------------------------------------------

func _rocks() -> void:
	if _karst == "paint":
		var rm := load(ROCK_MAT) as ShaderMaterial
		if rm:
			rm.set_shader_parameter("rock_tex", load(PAINT_KARST))
			rm.set_shader_parameter("normal_tex", load(PAINT_KARST_N))
			rm.set_shader_parameter("normal_strength", 0.25)
	# hero towers on the plateaus (mid distance), with pines on their seats
	for t: Array in [["karst_hero_b", Vector3(-170.0, 0.0, -720.0), 20.0, 1.0], ["karst_hero_a", Vector3(330.0, 0.0, -640.0), -30.0, 1.1],
			["karst_hero_c", Vector3(-330.0, 0.0, -420.0), 70.0, 0.9], ["karst_hero_e", Vector3(160.0, 0.0, -980.0), 10.0, 1.2],
			["karst_hero_d", Vector3(470.0, 0.0, -200.0), -60.0, 0.9]]:
		var p: Vector3 = t[1]
		p.y = _height(p.x, p.z) - 2.0
		_tower(String(t[0]), p, float(t[2]), float(t[3]), true)
	# the needle in the river
	var nz := -150.0
	_tower("bridge_needle", Vector3(river_x(nz) + 5.0, 136.0, nz), 15.0, 1.0, true)
	# the four backdrop ranks (look_directions.json karst_ranks), across the view's width
	var far := ShaderMaterial.new()
	far.shader = load("res://shaders/thuyvan/tv_rock_far.gdshader")
	var rm2 := load(ROCK_MAT) as ShaderMaterial
	for p: Dictionary in rm2.shader.get_shader_uniform_list():
		var nm := String(p.name)
		var v: Variant = rm2.get_shader_parameter(nm)
		if v != null:
			far.set_shader_parameter(nm, v)
	Look.register_rank(far)
	var fwd := (CAM_AT - CAM_POS)
	fwd.y = 0.0
	fwd = fwd.normalized()
	var names := ["karst_far_a", "karst_far_b", "karst_far_c", "karst_far_d", "karst_far_e", "karst_far_f"]
	for r: Dictionary in Look.data().get("karst_ranks", []):
		var n := 4 + int(r.rank)
		for i in n:
			var yaw := lerpf(-62.0, 62.0, (float(i) + _rng.randf_range(0.1, 0.9)) / n)
			var dist := _rng.randf_range(float(r.from_m), float(r.to_m))
			var dir := fwd.rotated(Vector3.UP, deg_to_rad(-yaw))
			var p := CAM_POS + dir * dist
			p.y = _plateau(p.x, p.z) - 6.0
			var sc := _rng.randf_range(0.8, 1.6) * (1.0 + 0.25 * float(r.rank))
			var node := _tower(String(names[_rng.randi() % names.size()]), p, _rng.randf() * 360.0, sc, false)
			for mi in Kit._meshes(node):
				mi.material_override = far
				mi.set_instance_shader_parameter("rank_fog", float(r.fog))


func _tower(piece: String, at: Vector3, yaw: float, sc: float, pines: bool) -> Node3D:
	var n := Kit.rock(piece, false)
	if n == null:
		return null
	n.position = at
	n.rotation_degrees.y = yaw
	n.scale = Vector3.ONE * sc
	_world.add_child(n)
	if not pines:
		return n
	var meta: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string(Kit.ROCK_DIR + "rock_kit.json")) as Dictionary) \
			.get("pieces", {}).get(piece, {})
	for s: Dictionary in meta.get("seats", []):
		if String(s.kind) != "pine":
			continue
		var r := float(s.r)
		var v := 2 if r > 4.0 else (1 if r > 2.0 else 0)
		var pl := Kit.plant("tv_karst_pine", v, 0)
		if pl == null:
			continue
		var lp := Vector3(s.pos[0], s.pos[1], s.pos[2])
		pl.position = n.transform * lp
		pl.rotation.y = _rng.randf() * TAU
		pl.scale = Vector3.ONE * sc * _rng.randf_range(1.0, 1.5)
		_world.add_child(pl)
	return n


# --- the village ---------------------------------------------------------------------------------------------------

func _village() -> void:
	_place(Kit.village("stilt_house_large"), Vector3(-52.0, 0.0, -28.0), 70.0)
	_place(Kit.village("stilt_house_small"), Vector3(-92.0, 0.0, -70.0), 40.0)
	_place(Kit.village("lantern_post"), Vector3(-14.0, 0.0, 26.0), 20.0)
	_place(Kit.village("banner_indigo"), Vector3(-3.0, 0.0, 14.0), 10.0)
	_place(Kit.village("drying_rack"), Vector3(-40.0, 0.0, -2.0), 80.0)
	_place(Kit.village("water_jars"), Vector3(-44.0, 0.0, -12.0), 0.0)


func _place(n: Node3D, at: Vector3, yaw: float) -> void:
	if n == null:
		return
	at.y = _height(at.x, at.z)
	n.position = at
	n.rotation_degrees.y = yaw
	_world.add_child(n)


func _plants() -> void:
	# broadleaf groves on both plateaus (never on the path, the gorge or near the camera's view line)
	var placed := 0
	var tries := 0
	while placed < 520 and tries < 9000:
		tries += 1
		var x := _rng.randf_range(-400.0, 480.0)
		var z := _rng.randf_range(-880.0, 220.0)
		var d := x - river_x(z)
		if absf(d) < 52.0 or Vector2(x - CAM_POS.x, z - CAM_POS.z).length() < 80.0 \
				or Vector2(x - GREY_AT.x, z - GREY_AT.z).length() < 30.0:
			continue
		var west := d < 0.0
		var grove := sin(x * 0.021 + 1.3) * sin(z * 0.017 - 0.4)
		if grove < (-0.15 if west else 0.1):
			continue
		if not west and _hill(x, z) > 3.0:
			continue
		if west and absf(x + 50.0) < 25.0 and absf(z + 30.0) < 40.0:
			continue
		var v := _rng.randi_range(0, 2)
		_plant("tv_broadleaf", v, Vector3(x, 0.0, z), _rng.randf_range(0.9, 1.2))
		placed += 1
	# bamboo by the houses, ferns and shrubs on the lip near the camera and by the fall
	for p: Vector3 in [Vector3(-70.0, 0, -8.0), Vector3(-30.0, 0, -52.0), Vector3(-108.0, 0, -50.0)]:
		_plant("tv_bamboo", _rng.randi_range(0, 1), p, 1.0)
	for i in 70:
		var x := _rng.randf_range(-70.0, 12.0)
		var z := _rng.randf_range(20.0, 150.0)
		if river_x(z) - x < 40.0 or Vector2(x - CAM_POS.x, z - CAM_POS.z).length() < 10.0:
			continue
		_plant("tv_fern" if _rng.randf() < 0.55 else "tv_shrub", _rng.randi_range(0, 2), Vector3(x, 0, z), _rng.randf_range(1.0, 1.6))


func _plant(species: String, v: int, at: Vector3, sc: float) -> void:
	var pl := Kit.plant(species, v, 0)
	if pl == null:
		return
	at.y = _height(at.x, at.z) - 0.2
	pl.position = at
	pl.rotation.y = _rng.randf() * TAU
	pl.scale = Vector3.ONE * sc
	_world.add_child(pl)


## A 0.5 sRGB card on the plateau, lit like the world (the style guide's mid-grey check).
func _grey_card() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.5, 0.5, 0.5)
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	m.roughness = 0.95
	m.metallic_specular = 0.1
	var g := GREY_AT
	g.y = _height(g.x, g.z) + 0.2
	var mi := _quad(g, 3.0, m)
	mi.rotation_degrees.x = -90.0
