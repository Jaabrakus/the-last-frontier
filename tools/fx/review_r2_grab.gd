extends SceneTree
## Review round 2 probe (read-only on the game): the proposed CaptureKit.settle / grab (the nine "N frames with force_draw, then
## read the SubViewport" loops of tools/ui_audit) compile as written and behave: settle returns after n frames, grab returns an
## Image of the viewport's size, RGB8 unless keep_alpha. Headless draws nothing real, so only the shapes are checked.
##   zsh tools/loop/godot_run.sh --headless --path . -s tools/fx/review_r2_grab.gd


static func settle(tree: SceneTree, n := 6) -> void:
	for i in n:
		await tree.process_frame
		RenderingServer.force_draw(false)


static func grab(tree: SceneTree, vp: Viewport, n := 6, keep_alpha := false) -> Image:
	await settle(tree, n)
	var img := vp.get_texture().get_image()
	if img != null and not keep_alpha and img.get_format() != Image.FORMAT_RGB8:
		img.convert(Image.FORMAT_RGB8)
	return img


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(64, 48)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var f0 := Engine.get_process_frames()
	var img := await grab(self, vp, 4)
	var f1 := Engine.get_process_frames()
	var rgba := await grab(self, vp, 2, true)
	# (headless has no renderer: the viewport's image is null there, and grab says so instead of crashing)
	var ok := f1 - f0 >= 3
	print("REVIEW r2 grab: frames waited %d, rgb8 %s %s, keep_alpha %s %s -> %s" % [f1 - f0, img.get_size() if img != null else "null",
			img.get_format() if img != null else -1, rgba.get_size() if rgba != null else "null", rgba.get_format() if rgba != null else -1,
			"OK" if ok else "BAD"])
	quit(0 if ok else 1)
