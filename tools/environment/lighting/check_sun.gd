extends SceneTree
## Sun and sky alignment checks (look-dev spec 3.2, acceptance A3). Windowed (the sky and the
## shadow are rendered); headless runs only the light-orientation check:
##
##   Godot --path . --resolution 640x360 -s tools/environment/lighting/check_sun.gd [-- rig=dev]
##
##   light      the DirectionalLight "Sun"'s -Z (its travel direction) is within 0.5 deg of
##              -EnvironmentRig.sun_direction()
##   sky_peak   the brightest direction of the rendered sky (disc and glow included) is within
##              1 deg of sun_direction()
##   hdri_sun   with the analytic disc and glow off, the centre of the panorama's own aureole
##              (where the photographed sun was painted out) is within 1 deg of sun_direction():
##              the panorama rotation matches the light
##   shadow     a 10 m pole on a flat plane casts its shadow toward azimuth 42.5 deg (+-1 deg), the
##              opposite of the sun, with the expected length 10 / tan(19.1 deg) (+-8 %: the
##              soft PCSS tip is cut short by the darkness threshold)
##   sky_5deg   the display value of the sky 5 deg above the horizon, facing away from the sun
##              (azimuth 42.5), at the base exposure with the full post chain: 0.78-0.88 (spec 2.3)
## The rig is built inside an isolated world (own SubViewport), so no level content interferes.
## Ends with SUN CHECK PASSED / FAILED.

var failures := PackedStringArray()
var vp: SubViewport
var cam: Camera3D
var rig: Node3D


func _initialize() -> void:
	var dev := "rig=dev" in OS.get_cmdline_user_args()
	var script: Script = load("res://tools/environment/lighting/testbed/environment_rig_dev.gd") if dev else EnvironmentRig
	var sun_dir: Vector3 = script.sun_direction()

	vp = SubViewport.new()
	vp.size = Vector2i(640, 360)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	cam = Camera3D.new()
	cam.far = 2000.0
	vp.add_child(cam)
	cam.current = true
	rig = script.new()
	rig.name = "EnvironmentRig"
	vp.add_child(rig)
	rig.build(WorldSettings.preset("high"))
	await process_frame                     # Nodes added in _initialize enter the tree next frame.

	var sun: DirectionalLight3D = rig.get_sun()
	var travel := -sun.global_transform.basis.z
	var ang := rad_to_deg(travel.angle_to(-sun_dir))
	_expect(ang <= 0.5, "light: Sun -Z is %.3f deg from -sun_direction() (<= 0.5)" % ang)

	if DisplayServer.get_name() == "headless":
		print("skip render checks (headless)")
	else:
		await _render_checks(sun_dir)
	if failures.is_empty():
		print("SUN CHECK PASSED")
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("SUN CHECK FAILED (%d)" % failures.size())
	quit(0 if failures.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)


func _render_checks(sun_dir: Vector3) -> void:
	var env: Environment = rig.get_environment()
	var sky_mat := env.sky.sky_material as ShaderMaterial
	var attrs: CameraAttributesPractical = rig.get_camera_attributes()
	# Raw sky radiance: no post, linear tonemap, low exposure so nothing clips.
	var saved := {"tm": env.tonemap_mode, "exp": env.tonemap_exposure, "adj": env.adjustment_enabled,
			"glow": env.glow_enabled, "fog": env.fog_enabled, "vfog": env.volumetric_fog_enabled,
			"ae": attrs.auto_exposure_enabled if attrs else false}
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.adjustment_enabled = false
	env.glow_enabled = false
	env.fog_enabled = false
	env.volumetric_fog_enabled = false
	if attrs:
		attrs.auto_exposure_enabled = false
	vp.use_taa = false

	# 1. Brightest direction with the disc (exposure low enough that only the disc nears 1).
	cam.fov = 8.0
	cam.global_position = Vector3.ZERO
	cam.look_at(sun_dir * 10.0 + Vector3(0.3, -0.2, 0.1))    # Off-centre on purpose.
	env.tonemap_exposure = 0.004
	var img := await _capture()
	var peak := _peak_direction(img, 0.98)
	var a1 := rad_to_deg(peak.angle_to(sun_dir))
	_expect(a1 <= 1.0, "sky_peak: brightest sky direction is %.3f deg from sun_direction() (<= 1)" % a1)

	# 2. The panorama's own sun (disc and glow off): centre of its aureole plateau.
	var disc: Variant = sky_mat.get_shader_parameter(&"sun_disc_scale")
	var glow: Variant = sky_mat.get_shader_parameter(&"sun_glow")
	sky_mat.set_shader_parameter(&"sun_disc_scale", 0.0)
	sky_mat.set_shader_parameter(&"sun_glow", 0.0)
	env.tonemap_exposure = 0.03
	img = await _capture()
	peak = _peak_direction(img, 0.97)
	var a2 := rad_to_deg(peak.angle_to(sun_dir))
	_expect(a2 <= 1.0, "hdri_sun: painted-out panorama sun centre is %.3f deg from sun_direction() (<= 1)" % a2)
	sky_mat.set_shader_parameter(&"sun_disc_scale", disc)
	sky_mat.set_shader_parameter(&"sun_glow", glow)

	# 3. Shadow of a 10 m pole on a plane, seen from straight above (orthographic).
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 120)
	plane.mesh = pm
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.8, 0.8, 0.8)
	plane.material_override = white
	vp.add_child(plane)
	var pole := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.3, 10.0, 0.3)
	pole.mesh = bm
	pole.position = Vector3(0, 5, 0)
	vp.add_child(pole)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 80.0
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.global_position = Vector3(0, 60, 0)
	cam.look_at(Vector3.ZERO, Vector3.FORWARD)          # Screen up = north (-Z).
	env.tonemap_exposure = 0.4
	img = await _capture()
	var lit := 0.0
	var n_lit := 0
	for p in [Vector2i(20, 20), Vector2i(620, 20), Vector2i(20, 340)]:
		lit += img.get_pixelv(p).get_luminance()
		n_lit += 1
	lit /= n_lit
	var sum := Vector2.ZERO
	var count := 0
	var far := 0.0
	var px_per_m := 360.0 / 80.0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).get_luminance() < lit * 0.6:
				var w := Vector2((x - 320) / px_per_m, (y - 180) / px_per_m)   # (east, south) metres.
				if w.length() < 0.6:
					continue                                                   # The pole itself.
				sum += w
				count += 1
				far = maxf(far, w.length())
	var c := sum / maxf(count, 1)
	var az := fposmod(rad_to_deg(atan2(c.x, -c.y)), 360.0)
	var want_az := fposmod(EnvironmentRig.SUN_AZIMUTH_DEG + 180.0, 360.0)
	var want_len := 10.0 / tan(deg_to_rad(EnvironmentRig.SUN_ELEVATION_DEG))
	_expect(count > 50 and absf(az - want_az) <= 1.0, "shadow: pole shadow points to azimuth %.2f deg (want %.1f +-1, %d px)" % [az, want_az, count])
	# The PCSS penumbra (0.53 deg) softens the tip, which the 60 % threshold cuts a little short.
	_expect(absf(far - want_len) <= want_len * 0.08, "shadow: length %.1f m (want %.1f +-8 %%)" % [far, want_len])
	plane.queue_free()
	pole.queue_free()

	# 4. Sky 5 deg above the horizon, facing away from the sun, full post chain at base exposure.
	env.tonemap_mode = saved.tm
	env.tonemap_exposure = saved.exp
	env.adjustment_enabled = saved.adj
	env.glow_enabled = saved.glow
	env.fog_enabled = saved.fog
	env.volumetric_fog_enabled = saved.vfog
	vp.use_taa = true
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 20.0
	cam.global_position = Vector3(0, 2, 0)
	var away := deg_to_rad(EnvironmentRig.SUN_AZIMUTH_DEG + 180.0)
	var el := deg_to_rad(5.0)
	cam.look_at(cam.global_position + Vector3(sin(away) * cos(el), sin(el), -cos(away) * cos(el)))
	img = await _capture(30)
	var v := 0.0
	for y in range(170, 190):
		for x in range(300, 340):
			var p := img.get_pixel(x, y)
			v += (p.r + p.g + p.b) / 3.0
	v /= 20.0 * 40.0
	_expect(v >= 0.78 and v <= 0.88, "sky_5deg: sky 5 deg above the horizon away from the sun = %.3f (0.78-0.88)" % v)


func _capture(frames := 8) -> Image:
	for k in frames:
		await process_frame
	return vp.get_texture().get_image()


## Direction of the centroid of the pixels at or above `frac` of the brightest pixel.
func _peak_direction(img: Image, frac: float) -> Vector3:
	var mx := 0.0
	for y in img.get_height():
		for x in img.get_width():
			mx = maxf(mx, img.get_pixel(x, y).get_luminance())
	var sum := Vector2.ZERO
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).get_luminance() >= mx * frac:
				sum += Vector2(x + 0.5, y + 0.5)
				n += 1
	return cam.project_ray_normal(sum / maxi(n, 1))
