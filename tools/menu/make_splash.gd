extends SceneTree
## Tidebreak boot splash, rendered from an unchanged arena still and native vector/type graphics.
## GODOT_TIMEOUT=120 zsh tools/loop/godot_run.sh --path . --resolution 480x270 -s tools/menu/make_splash.gd
## Writes assets/ui/tidebreak_splash.png; the previous splash remains available as historical artwork.

const OUT := "res://assets/ui/tidebreak_splash.png"
const PICTURE := "res://assets/ui/tidebreak/deck.png"
const TITLES := preload("res://tools/ring/trailer_titles.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Splash generation requires a rendered Godot window.")
		quit(2)
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var pic := TextureRect.new()
	pic.texture = load(PICTURE)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.size = Vector2(1920, 1080)
	vp.add_child(pic)
	var veil := ColorRect.new()
	veil.color = Color(MenuUI.BACKDROP, 0.36)
	veil.size = Vector2(1920, 1080)
	vp.add_child(veil)
	var art := TITLES.TitleArt.new()
	art.configure("opening")
	vp.add_child(art)
	var note := MenuUI.label("EARLY PLAYABLE DEMO  ·  IN DEVELOPMENT", 23, MenuUI.DIM)
	note.position = Vector2(0, 945)
	note.size = Vector2(1920, 50)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vp.add_child(note)
	for i in 6:
		await process_frame
		RenderingServer.force_draw(false)
	var img := vp.get_texture().get_image()
	var err := img.save_png(ProjectSettings.globalize_path(OUT))
	print("SPLASH WRITTEN ", img.get_size(), " result=", err)
	quit(0 if err == OK else 1)
