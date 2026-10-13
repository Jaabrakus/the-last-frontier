extends SceneTree
## Review round 1 probe (read-only): the cost of CascadeFx.Emitter.render() changing MultiMesh.instance_count every frame
## (cascade_fx.gd: mm.instance_count = n) against a buffer allocated once with visible_instance_count = n, plus the
## per-frame 256x1 RGBAF ImageTexture re-upload for emitters with no particles. Windowed (it draws):
##   zsh tools/loop/godot_run.sh --path . --resolution 640x360 --fixed-fps 60 -s tools/fx/review_r1_multimesh.gd
## 30 emitters (8 effects x ~4 emitters) with a particle count that wanders between 0 and 120; each variant draws the same
## scene; the time is the main thread's per-frame work + RenderingServer.force_draw (CPU side of the draw).

const EMITTERS := 30
const FRAMES := 240
const MAXN := 128

var mmis: Array[MultiMeshInstance3D] = []
var counts: Array[int] = []
var imgs: Array[Image] = []
var texs: Array[ImageTexture] = []
var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_run.call_deferred()


func _build(variant: String) -> void:
	for m in mmis:
		m.queue_free()
	mmis.clear()
	counts.clear()
	imgs.clear()
	texs.clear()
	for i in EMITTERS:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		var q := QuadMesh.new()
		q.size = Vector2.ONE * 0.2
		mm.mesh = q
		if variant == "alloc_once":
			mm.instance_count = MAXN
			mm.visible_instance_count = 0
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = mat
		mi.top_level = true
		mi.extra_cull_margin = 10000.0
		root.add_child(mi)
		mmis.append(mi)
		counts.append(rng.randi_range(0, MAXN))
		var im := Image.create(256, 1, false, Image.FORMAT_RGBAF)
		imgs.append(im)
		texs.append(ImageTexture.create_from_image(im))


## One frame of Emitter.render() for every emitter: `variant` is how the count is applied.
func _update(variant: String, upload_when_empty: bool) -> void:
	for i in EMITTERS:
		var c := clampi(counts[i] + rng.randi_range(-6, 6), 0, MAXN)
		counts[i] = c
		var mm := mmis[i].multimesh
		if variant == "instance_count":
			mm.instance_count = c
		else:
			mm.visible_instance_count = c
		for k in c:
			mm.set_instance_transform(k, Transform3D(Basis(), Vector3(float(k % 16) * 0.3 - 2.4, float(i) * 0.12 - 1.5, -float(k / 16) * 0.3)))
			mm.set_instance_color(k, Color(1, 0.5, 0.2, 0.5))
			mm.set_instance_custom_data(k, Color(1, 1, 1, 1))
			imgs[i].set_pixel(k, 0, Color(0.0, 0.0, 0.3, 0.7))
		if c > 0 or upload_when_empty:
			texs[i].update(imgs[i])


func _measure(variant: String, label: String, upload_when_empty := true) -> void:
	_build("alloc_once" if variant == "visible_count" else "plain")
	for f in 30:
		_update(variant, upload_when_empty)
		RenderingServer.force_draw(false, 0.0)
	var totals: Array[float] = []
	var scripts: Array[float] = []
	for f in FRAMES:
		var t0 := Time.get_ticks_usec()
		_update(variant, upload_when_empty)
		var t1 := Time.get_ticks_usec()
		RenderingServer.force_draw(false, 0.0)
		var t2 := Time.get_ticks_usec()
		scripts.append((t1 - t0) / 1000.0)
		totals.append((t2 - t0) / 1000.0)
	totals.sort()
	scripts.sort()
	print("  %-58s median: script %.2f ms, total %.2f ms   p90 total %.2f ms   max %.1f ms" % [label, scripts[FRAMES / 2], totals[FRAMES / 2],
			totals[int(FRAMES * 0.9)], totals[FRAMES - 1]])


func _run() -> void:
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.global_position = Vector3(0, 0, 6)
	cam.current = true
	await process_frame
	await process_frame
	rng.seed = 7
	print("REVIEW multimesh churn, %d emitters, counts wander 0..%d, %d frames, renderer %s / %s" % [EMITTERS, MAXN, FRAMES,
			RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()])
	for round_i in 3:
		_measure("instance_count", "instance_count = n each frame (as render())")
		_measure("visible_count", "allocated once, visible_instance_count = n")
		_measure("instance_count", "instance_count = n, no texture upload when n == 0", false)
	quit(0)
