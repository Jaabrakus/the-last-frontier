extends SceneTree
## Quality presets (look-dev spec 9.2, acceptance A6): builds the EnvironmentRig for low, medium
## and high, each in an isolated SubViewport, and checks that what it applied matches the
## WorldSettings preset and the spec table. Windowed or headless (headless checks only the
## environment resources and the log line, since the rig skips rendering setup there):
##
##   Godot --path . --resolution 640x360 -s tools/environment/lighting/check_presets.gd
##
## The live check of the command-line switch is the level itself: run it with -- quality=<q>
## and grep the "ENV quality=<q> ..." line (the scenic, benchmark and calibration tools print it).
## Ends with PRESET CHECK PASSED / FAILED.

var failures := PackedStringArray()


func _initialize() -> void:
	var headless := DisplayServer.get_name() == "headless"
	for q in ["low", "medium", "high"]:
		var s := WorldSettings.preset(q)
		var vp := SubViewport.new()
		vp.size = Vector2i(64, 64)
		vp.own_world_3d = true
		root.add_child(vp)
		var rig := EnvironmentRig.new()
		vp.add_child(rig)
		await process_frame
		rig.build(s)
		var env: Environment = rig.get_environment()
		var sun: DirectionalLight3D = rig.get_sun()
		var line: String = rig.log_line()
		_expect(line.begins_with("ENV quality=%s " % q), "%s: log line '%s'" % [q, line])
		_expect(sun.name == "Sun" and rig.get_node_or_null("WorldEnvironment") != null, "%s: nodes Sun and WorldEnvironment" % q)
		_expect(sun.directional_shadow_max_distance == s.shadow_max_distance, "%s: shadow distance %.0f m" % [q, sun.directional_shadow_max_distance])
		_expect(sun.directional_shadow_mode == (DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if s.shadow_splits >= 4 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS),
				"%s: %d shadow splits" % [q, s.shadow_splits])
		if not headless:
			_expect(env.sdfgi_enabled == s.sdfgi, "%s: sdfgi %s" % [q, env.sdfgi_enabled])
			_expect(env.ssao_enabled == s.ssao, "%s: ssao %s" % [q, env.ssao_enabled])
			_expect(not env.ssil_enabled and not env.ssr_enabled, "%s: ssil and ssr off" % q)
			_expect(env.volumetric_fog_enabled == s.volumetric_fog, "%s: volumetric fog %s" % [q, env.volumetric_fog_enabled])
			_expect(env.glow_enabled == s.glow, "%s: glow %s" % [q, env.glow_enabled])
			_expect(env.fog_enabled and env.tonemap_mode == Environment.TONE_MAPPER_AGX and env.adjustment_enabled,
					"%s: depth fog, AgX and the LUT on" % q)
			var ca: CameraAttributesPractical = rig.get_camera_attributes()
			_expect(ca != null and ca.auto_exposure_enabled == s.auto_exposure, "%s: auto exposure %s" % [q, ca.auto_exposure_enabled if ca else false])
			_expect(vp.msaa_3d == Viewport.MSAA_DISABLED, "%s: MSAA off" % q)
			match s.antialiasing:
				"taa":
					_expect(vp.use_taa and vp.scaling_3d_scale == 1.0, "%s: TAA at native resolution" % q)
				"fxaa":
					_expect(not vp.use_taa and vp.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA, "%s: FXAA, no TAA" % q)
				"metalfx":
					if RenderingServer.get_current_rendering_driver_name() == "metal":
						_expect(vp.scaling_3d_mode == Viewport.SCALING_3D_MODE_METALFX_TEMPORAL and is_equal_approx(vp.scaling_3d_scale, s.render_scale),
								"%s: MetalFX temporal at %.2f" % [q, vp.scaling_3d_scale])
					else:
						_expect(vp.use_taa, "%s: TAA (MetalFX unavailable off Metal)" % q)
			_expect((rig.get_node_or_null("DustMotes") != null) == (q != "low"), "%s: dust motes %s" % [q, "on" if q != "low" else "off"])
		vp.queue_free()
		await process_frame
	# The last build (high) leaves the RenderingServer at the high preset; the project defaults
	# (project.godot) are what the root viewport starts with.
	_expect(int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size")) == 4096, "project: directional shadow atlas 4096")
	_expect(int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d")) == 0, "project: msaa_3d off")
	_expect(bool(ProjectSettings.get_setting("rendering/occlusion_culling/use_occlusion_culling")), "project: occlusion culling on")
	_expect(bool(ProjectSettings.get_setting("rendering/global_illumination/gi/use_half_resolution")), "project: GI half resolution")
	if failures.is_empty():
		print("PRESET CHECK PASSED")
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("PRESET CHECK FAILED (%d)" % failures.size())
	quit(0 if failures.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)
