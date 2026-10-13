extends SceneTree
## Rendered RingLook regression: graphics choices survive mood changes, and the stopped-clock
## lighting does not accumulate its per-frame gains or remember an earlier mood's exposure.
##   GODOT_TIMEOUT=180 zsh tools/loop/godot_run.sh --path . --windowed --resolution 640x360 \
##       --fixed-fps 60 -s tests/ring/test_ring_lighting.gd
## A real render driver is required: headless skips RingLook's lighting writes and exits with 2.
## Uses the real EnvironmentRig/DayNight on a small static stage; no match, saved settings, or
## aesthetic numeric targets. Cloud cover is held clear to isolate repeated lighting updates.

const NAME := "RING LIGHTING"
const STABLE_FRAMES := 40
const REL_TOL := 0.01
const OffscreenView := preload("res://tools/environment/offscreen_view.gd")

class LightingStage:
	extends Node3D
	var environment_rig: EnvironmentRig
	var ring: RingArena

var checks := 0
var fails: Array[String] = []
var stage: LightingStage
var rig: EnvironmentRig
var env: Environment
var sun: DirectionalLight3D
var look: RingLook
var view: OffscreenView


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("%s REQUIRES RENDERING: run without --headless; no lighting checks were run" % NAME)
		quit(2)
		return
	create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	_run.call_deferred()


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _render_frames(n: int) -> void:
	for i in n:
		await process_frame
		# An obscured macOS window may never emit frame_post_draw. The off-window target
		# still draws explicitly, so a simultaneous capture cannot stall this regression.
		RenderingServer.force_draw(false)


func _lighting_values() -> Vector3:
	return Vector3(sun.light_energy, env.tonemap_exposure, env.tonemap_agx_contrast)


func _relative_delta(a: Vector3, b: Vector3) -> float:
	return maxf(maxf(absf(a.x - b.x) / maxf(absf(b.x), 0.0001),
			absf(a.y - b.y) / maxf(absf(b.y), 0.0001)),
			absf(a.z - b.z) / maxf(absf(b.z), 0.0001))


func _mood(name: String) -> void:
	look = RingLook.apply(stage, name)
	# Moving clouds are legitimate light changes; keep this fixture's weather constant so the
	# regression measures frame accumulation and mood state, rather than cloud transmittance.
	rig.clock_driver.force_cover = 0.0
	rig.clock_driver.force_weather("clear")
	await _render_frames(8)


func _run() -> void:
	stage = LightingStage.new()
	root.add_child(stage)
	current_scene = stage
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 3.0, 6.0), Vector3(0.0, 0.7, 0.0))
	camera.make_current()
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12.0, 12.0)
	floor_mesh.mesh = plane
	stage.add_child(floor_mesh)
	var subject := MeshInstance3D.new()
	subject.mesh = SphereMesh.new()
	subject.position.y = 1.0
	stage.add_child(subject)
	var settings := WorldSettings.preset("low")
	settings.glow = false
	settings.ssao = false
	rig = EnvironmentRig.new()
	stage.environment_rig = rig
	stage.add_child(rig)
	rig.build(settings)
	env = rig.get_environment()
	sun = rig.get_sun()
	_expect(env != null and sun != null and rig.clock_driver != null,
			"the rendered rig has its real Environment, sun, and DayNight driver")
	if env == null or sun == null or rig.clock_driver == null:
		_end()
		return
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(640, 360))
	view.source = camera
	view.sync_camera()
	rig.follow_camera = view.camera
	root.disable_3d = true
	await _render_frames(2)
	var frame := view.get_texture().get_image()
	_expect(frame != null and not frame.is_empty(), "the viewport produced a rendered frame")
	# Observe night before noon has touched the grade. A noon-only override that leaks into
	# later moods would otherwise pass a noon-to-noon comparison despite leaving night wrong.
	await _mood("night")
	var night_agx := env.tonemap_agx_contrast
	for mood: String in ["noon", "golden", "night", "noon"]:
		await _mood(mood)
		_expect(not env.glow_enabled and not env.ssao_enabled,
				"%s preserves explicit glow-off and SSAO-off choices" % mood)
		_expect(not env.sdfgi_enabled and not env.ssil_enabled and not env.volumetric_fog_enabled,
				"%s preserves the preset's disabled expensive effects" % mood)
	settings.glow = true
	settings.ssao = true
	await _mood("night")
	_expect(env.glow_enabled and env.ssao_enabled, "enabled settings take effect after a mood change")
	settings.glow = false
	settings.ssao = false
	await _mood("noon")
	_expect(not env.glow_enabled and not env.ssao_enabled, "turning effects off again takes effect")
	var before := _lighting_values()
	var clock := rig.clock_driver.clock
	var hour := clock.hour
	_expect(not clock.running and before.is_finite() and before.x > 0.0 and before.y > 0.0,
			"noon has finite positive light/exposure and a stopped clock")
	var drift := 0.0
	for i in STABLE_FRAMES:
		await _render_frames(1)
		drift = maxf(drift, _relative_delta(_lighting_values(), before))
	_expect(is_equal_approx(clock.hour, hour), "the stability sample kept the same clock time")
	_expect(drift <= REL_TOL,
			"repeated noon frames do not accumulate light/exposure gains (max drift %.5f)" % drift)
	for mood: String in ["golden", "night", "noon"]:
		await _mood(mood)
		if mood == "night":
			_expect(is_equal_approx(env.tonemap_agx_contrast, night_agx),
					"night restores its observed AgX grade after leaving noon")
	var after := _lighting_values()
	var round_trip := _relative_delta(after, before)
	_expect(after.is_finite() and round_trip <= REL_TOL,
			"returning to noon restores its prior light/exposure/AgX grade (relative change %.5f)" % round_trip)
	print("METRIC light_exposure_agx_before=%s after=%s max_frame_drift=%.6f round_trip=%.6f" %
			[before, after, drift, round_trip])
	_end()


func _end() -> void:
	print("%s %s (%d checks, %d failed)" % [NAME, "PASSED" if fails.is_empty() else "FAILED", checks, fails.size()])
	quit(0 if fails.is_empty() else 1)
