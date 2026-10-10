extends SceneTree
## The match setup's fighter cards measured against the approved mock-up (style B, tools/ui_audit/menu_variants/b_broadcast:
## its card_<element>_cut.png figures fitted into the 214 x 452 card): each element's card view from FighterWorld drawn alone on a
## clear background, the figure's box (where its alpha is) in card pixels, its height and its head and feet, printed beside the
## mock-up's (MOCK, measured from the mock-up's renders, 2026-10-10). Windowed (the figure is not drawn headless), a normal window;
## never the character creator; the look is a made-up one.
##   zsh tools/loop/godot_run.sh --path . --resolution 640x360 -s tools/ui_audit/card_figures.gd -- [out=DIR]

const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
## The mock-up's figure in its card (x0, y0, x1, y1 in card px; the card is 214 x 452).
const MOCK := {"earth": [25, 44, 177, 400], "water": [22, 36, 173, 410], "fire": [41, 35, 150, 411], "air": [27, 24, 173, 401]}
const CARD := Vector2i(214, 452)


func _initialize() -> void:
	if not CaptureKit.begin(self, "card_figures", "", false, true):
		return
	var look := AppearanceStore.default_look()
	look["name"] = "Rowan"
	FighterWorld.look_override = AppearanceStore.validate(look)
	_run.call_deferred()


func _run() -> void:
	var out := String(CaptureKit.args({"out": ""}).out)
	var fw := FighterWorld.make(root)
	await process_frame
	var worst := 0.0
	for el: String in Bending.ELEMENTS:
		var v := fw.view(el, "card", CARD * 2)
		fw.face(el, "card")
		var blob := (fw._figs[el].pivot as Node3D).find_child("Blob", true, false) as Node3D
		if blob != null:
			blob.visible = false                  # (the soft shadow under the feet is not the figure)
		v.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(v)
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := v.get_texture().get_image()
		if out != "":
			CaptureKit.save(img, out, "card_view_" + el, true)
		var bb := _alpha_box(img)
		var r := Rect2(bb.position / 2.0, bb.size / 2.0)
		var m: Array = MOCK[el]
		var mh := float(m[3] - m[1])
		var ratio := r.size.y / mh
		worst = maxf(worst, absf(1.0 - ratio))
		print("CARD %s: figure x %.0f..%.0f y %.0f..%.0f height %.0f  |  mock-up x %d..%d y %d..%d height %.0f  |  height %.0f%% of the mock-up's" % [el,
				r.position.x, r.end.x, r.position.y, r.end.y, r.size.y, m[0], m[2], m[1], m[3], mh, 100.0 * ratio])
		v.queue_free()
	print("CARD FIGURES DONE worst height off by %.0f%%" % (100.0 * worst))
	FighterWorld.look_override = {}
	quit(0)


## The box of the pixels with alpha over 40 / 255.
static func _alpha_box(img: Image) -> Rect2:
	var x0 := img.get_width()
	var y0 := img.get_height()
	var x1 := -1
	var y1 := -1
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 40.0 / 255.0:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	if x1 < 0:
		return Rect2()
	return Rect2(x0, y0, x1 - x0 + 1, y1 - y0 + 1)
