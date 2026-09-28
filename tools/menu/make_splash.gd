extends SceneTree
## The boot splash (user 2026-09-27: "instead of the godot"): the fort at evening (assets/ui/paintings/, painted by
## tools/menu/paint_views.gd) darkened toward the middle, the title over it. Windowed (it draws in a SubViewport):
##
##   Godot --path . -s tools/menu/make_splash.gd
##
## Writes assets/ui/splash.png (1920 x 1080; project.godot application/boot_splash/image, stretch Cover).

const OUT := "res://assets/ui/splash.png"
const PAINTING := "res://assets/ui/paintings/fort_evening.jpg"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(vp)
	var pic := TextureRect.new()
	pic.texture = load(PAINTING)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.size = Vector2(1920, 1080)
	vp.add_child(pic)
	var veil := ColorRect.new()
	veil.color = Color(0.03, 0.022, 0.014, 0.45)
	veil.size = Vector2(1920, 1080)
	vp.add_child(veil)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size = Vector2(1920, 1080)
	box.add_theme_constant_override("separation", 10)
	vp.add_child(box)
	var title := MenuUI.label("FRONTIER", 120, MenuUI.INK)
	var fv := FontVariation.new()
	fv.base_font = FrontierHUD.serif()
	fv.spacing_glyph = 18
	title.add_theme_font_override("font", fv)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := MenuUI.label("Cosby's Manor, on the Mohawk  ·  1765", 34, MenuUI.GOLD)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	for i in 4:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT))
	print("SPLASH WRITTEN ", img.get_size())
	quit(0)
