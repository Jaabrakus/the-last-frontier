extends SceneTree
## Native 1920x1080 transparent trailer titles. No gameplay or font files are changed.
## GODOT_TIMEOUT=120 zsh tools/loop/godot_run.sh --path . --resolution 480x270 \
##   -s tools/ring/trailer_titles.gd -- out=res://artifacts/tidebreak_trailer_60/titles
## Uses the same installed Baskerville-first serif family as FrontierHUD, without bundling fonts.

const SIZE := Vector2i(1920, 1080)
const CARDS := ["opening", "four_elements", "one_arena", "make_waves", "closing"]

class TitleArt extends Node2D:
	const IVORY := Color("f3efdf")
	const BRASS := Color("c4ad78")
	const JADE := Color("85b8a4")
	var card := "opening"
	var serif: SystemFont
	var plate: GradientTexture2D
	var manifest: Dictionary = {}

	func _init() -> void:
		serif = SystemFont.new()
		serif.font_names = PackedStringArray(["Baskerville", "Hoefler Text", "Georgia", "Times New Roman", "Liberation Serif", "DejaVu Serif", "serif"])
		serif.fallbacks = [ThemeDB.fallback_font]
		serif.antialiasing = TextServer.FONT_ANTIALIASING_GRAY

	func configure(id: String) -> void:
		card = id
		var full := card in ["opening", "closing"]
		var gradient := Gradient.new()
		if full:
			gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
			gradient.colors = PackedColorArray([Color(0.018, 0.047, 0.043, 0.12), Color(0.018, 0.047, 0.043, 0.40), Color(0.018, 0.047, 0.043, 0.67), Color(0.018, 0.047, 0.043, 0.40), Color(0.018, 0.047, 0.043, 0.12)])
		else:
			gradient.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
			gradient.colors = PackedColorArray([Color(0.018, 0.047, 0.043, 0.66), Color(0.018, 0.047, 0.043, 0.43), Color(0.018, 0.047, 0.043, 0.0)])
		plate = GradientTexture2D.new()
		plate.gradient = gradient
		plate.width = 1920 if full else 1050
		plate.height = 1080 if full else 350
		plate.fill = GradientTexture2D.FILL_LINEAR if full else GradientTexture2D.FILL_RADIAL
		plate.fill_from = Vector2(0.5, 0.0) if full else Vector2(0.5, 0.5)
		plate.fill_to = Vector2(0.5, 1.0) if full else Vector2(1.0, 0.5)
		manifest = {"card": card, "canvas": [1920, 1080], "text": []}
		queue_redraw()

	func _font(tracking: int) -> FontVariation:
		var font := FontVariation.new()
		font.base_font = serif
		font.spacing_glyph = tracking
		return font

	func _text(text: String, at: Vector2, px: int, tracking: int, color: Color, centered := false) -> void:
		var font := _font(tracking)
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var base := at - Vector2(width * 0.5 if centered else 0.0, 0.0)
		draw_string_outline(font, base + Vector2(0, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 3, Color(0.01, 0.03, 0.027, 0.65))
		draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
		manifest.text.append({"copy": text, "baseline": [base.x, base.y], "font_px": px, "tracking_px": tracking, "width_px": width})

	func _emblem(center: Vector2, radius: float) -> void:
		# Four interrupted arcs suggest the arena and four equal elements; no historical symbol claim.
		for quadrant in 4:
			var angle := float(quadrant) * PI * 0.5
			draw_arc(center, radius, angle + 0.13, angle + PI * 0.5 - 0.13, 32, BRASS, 1.3, true)
			draw_arc(center, radius * 0.72, angle + 0.26, angle + PI * 0.5 - 0.26, 24, Color(JADE, 0.78), 1.0, true)
		var wave := PackedVector2Array()
		for i in 65:
			var t := float(i) / 64.0
			wave.append(center + Vector2(lerpf(-radius * 0.55, radius * 0.55, t), sin(t * TAU) * radius * 0.12))
		draw_polyline(wave, IVORY, 1.6, true)

	func _draw() -> void:
		manifest.text = []
		if card in ["opening", "closing"]:
			draw_texture_rect(plate, Rect2(Vector2.ZERO, Vector2(1920, 1080)), false)
			_emblem(Vector2(960, 360), 48.0)
			_text("TIDEBREAK", Vector2(960, 550), 132, 18, IVORY, true)
			draw_line(Vector2(665, 594), Vector2(886, 594), Color(BRASS, 0.75), 1.0, true)
			draw_line(Vector2(1034, 594), Vector2(1255, 594), Color(BRASS, 0.75), 1.0, true)
			for i in 4:
				draw_circle(Vector2(933 + i * 18, 594), 2.0, JADE)
			if card == "opening":
				_text("ELEMENTAL ARENA COMBAT", Vector2(960, 658), 25, 7, IVORY, true)
			else:
				_text("EARLY PLAYABLE DEMO", Vector2(960, 658), 25, 7, IVORY, true)
				_text("IN DEVELOPMENT", Vector2(960, 722), 22, 5, Color(JADE, 0.95), true)
		else:
			draw_texture_rect(plate, Rect2(12, 130, 1050, 350), false)
			draw_line(Vector2(130, 238), Vector2(218, 238), BRASS, 1.2, true)
			for i in 4:
				draw_circle(Vector2(235 + i * 13, 238), 1.5, Color(JADE, 0.9))
			var copy := {"four_elements": "FOUR ELEMENTS.", "one_arena": "ONE ARENA.", "make_waves": "MAKE WAVES."}
			_text(String(copy[card]), Vector2(128, 329), 70, 5, IVORY)
			draw_line(Vector2(131, 363), Vector2(452, 363), Color(BRASS, 0.60), 1.0, true)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Trailer title export requires a rendered driver, not --headless.")
		quit(2)
		return
	var out := "res://artifacts/tidebreak_trailer_60/titles"
	var preview := "res://artifacts/tidebreak_clean_hud/final_frames/t004.00.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
		elif arg.begins_with("preview="):
			preview = arg.substr(8)
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var art := TitleArt.new()
	viewport.add_child(art)
	var backdrop := Image.load_from_file(ProjectSettings.globalize_path(preview))
	if backdrop == null:
		backdrop = Image.create_empty(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
		backdrop.fill(Color("305d56"))
	backdrop.convert(Image.FORMAT_RGBA8)
	backdrop.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
	var contact := Image.create_empty(1280, 1080, false, Image.FORMAT_RGBA8)
	contact.fill(Color("102b27"))
	var records: Array[Dictionary] = []
	for i in CARDS.size():
		art.configure(CARDS[i])
		for frame in 3:
			await process_frame
			RenderingServer.force_draw(false)
		var result := viewport.get_texture().get_image()
		result.convert(Image.FORMAT_RGBA8)
		var path := out.path_join(CARDS[i] + ".png")
		var err := result.save_png(path)
		if err != OK:
			push_error("Could not save " + path)
			quit(1)
			return
		var comp := backdrop.duplicate() as Image
		comp.blend_rect(result, Rect2i(Vector2i.ZERO, SIZE), Vector2i.ZERO)
		comp.save_png(out.path_join(CARDS[i] + "_review.png"))
		comp.resize(640, 360, Image.INTERPOLATE_LANCZOS)
		contact.blit_rect(comp, Rect2i(0, 0, 640, 360), Vector2i((i % 2) * 640, (i / 2) * 360))
		records.append(art.manifest.duplicate(true))
		print("TITLE ", CARDS[i], " ", path)
	contact.save_png(out.path_join("contact_sheet.png"))
	var manifest := {"schema": "tidebreak-trailer-titles/v1", "engine": Engine.get_version_info().string,
		"font": art.serif.get_font_name(), "font_source": "Installed system font, using the game's Baskerville-first family stack; no font files redistributed.",
		"alpha": "RGBA8; full-frame semitransparent ink gradients on opening/closing; localized fading plates on midcards.",
		"review_background": preview, "cards": records}
	FileAccess.open(out.path_join("manifest.json"), FileAccess.WRITE).store_string(JSON.stringify(manifest, "\t") + "\n")
	print("TRAILER TITLES DONE")
	quit(0)
