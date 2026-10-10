extends SceneTree
## Review probe (read-only): the width of the creator's two-line hint at the creator's 12 px font against its strip
## (hint_box offsets 176 .. 16 + LEFT_W, content margin 4 each side). Headless; touches nothing.
func _initialize() -> void:
	var font := ThemeDB.fallback_font
	var text: String = CharacterCreator.HINT
	var strip_w := float(16 + CharacterCreator.LEFT_W - (166 + 10))
	var inner := strip_w - 8.0
	for line in text.split("\n"):
		var w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		print("HINT line '%s' = %.1f px; strip inner %.1f px -> %s" % [line, w, inner, "FITS" if w <= inner else "OVERRUNS by %.1f" % (w - inner)])
	var lb := Label.new()
	lb.text = text
	lb.add_theme_font_size_override("font_size", 12)
	print("Label minimum size ", lb.get_minimum_size())
	lb.free()
	# the default look's brows: the preset's own and the Eyebrows choice the default snaps to
	var raw := CharacterPeoples.preset_look(AppearanceStore.DEFAULT_PRESET)
	var dl := AppearanceStore.default_look()
	print("default brows: preset's own %s -> snapped %s (id %s)" % [raw.get("brows"), dl.get("brows"), dl.get("eyebrows")])
	quit(0)
