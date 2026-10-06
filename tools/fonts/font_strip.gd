extends SceneTree
## The owner's font proof: Thủy Vân's names set by the engine's own text rendering in UiFonts' fonts, on a HUD-like
## dark panel and a light parchment one, at 14, 18, 24 and 40 px. Windowed (it draws in a SubViewport), the lead runs
## it in the lane:
##
##   Godot --path . -s tools/fonts/font_strip.gd -- --out=<folder>
##
## Writes <folder>/font_strip.png (default user://font_strip.png) and prints the face each role resolved to. When a
## free-licence family ships under assets/fonts (UiFonts.BUNDLED), its role shows twice: the shipped family and the
## system list it falls back to, so the two can be judged side by side.

const SIZES := [14, 18, 24, 40]
const LINES := ["Vạn Thủy, Capital of the Waters", "Hồ Tinh, the Fox-Blooded", "Đồng Lau, the Reed Marches",
		"Trường Sơn", "Ể Ỗ Ặ Ữ Ậ Ở"]
const COL_W := 1180
const PAD := 36
## [name, background, panel, panel edge, ink, soft ink, shadow]
const LOOKS := [
	["light", Color(0.93, 0.9, 0.84), Color(0.98, 0.96, 0.91), Color(0.62, 0.42, 0.2), Color(0.13, 0.11, 0.09),
			Color(0.42, 0.37, 0.31), Color(0, 0, 0, 0)],
	["dark", Color(0.07, 0.08, 0.09), Color(0.03, 0.035, 0.04, 0.78), Color(0.85, 0.62, 0.3, 0.95),
			Color(0.96, 0.93, 0.86), Color(0.72, 0.68, 0.6), Color(0, 0, 0, 0.75)],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "user://font_strip.png"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=").path_join("font_strip.png")
	UiFonts.reset()
	var roles: Array = []   ## [label, Font]
	for role: String in ["serif", "sans"]:
		var f := UiFonts.font(role)
		if f is SystemFont:
			roles.append(["%s  ·  %s (system)" % [role, f.get_font_name()], f])
		else:
			roles.append(["%s  ·  %s (shipped)" % [role, f.get_font_name()], f])
			var s := UiFonts.system(role)
			roles.append(["%s  ·  %s (system, for comparison)" % [role, s.get_font_name()], s])
	for r: Array in roles:
		print("FONT STRIP ROLE ", r[0])
	var vp := SubViewport.new()
	vp.size = Vector2i(COL_W * 2 + PAD * 3, 400)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	vp.add_child(row)
	for look: Array in LOOKS:
		row.add_child(_column(look, roles))
	await process_frame
	await process_frame
	var need := row.get_combined_minimum_size()
	vp.size = Vector2i(int(need.x), int(need.y))
	row.size = need
	for i in 4:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var path := ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := img.save_png(path)
	print("FONT STRIP WRITTEN %s %s (%s)" % [path, img.get_size(), error_string(err)])
	quit(0 if err == OK else 1)


func _column(look: Array, roles: Array) -> Control:
	var bg := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = look[1]
	sb.content_margin_left = PAD
	sb.content_margin_right = PAD
	sb.content_margin_top = PAD
	sb.content_margin_bottom = PAD
	bg.add_theme_stylebox_override("panel", sb)
	bg.custom_minimum_size.x = COL_W + PAD * 2
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 22)
	bg.add_child(vb)
	vb.add_child(_label("%s  ·  14, 18, 24, 40 px" % look[0], UiFonts.sans(600), 16, look[5], look[6]))
	for r: Array in roles:
		var panel := PanelContainer.new()
		var ps := StyleBoxFlat.new()
		ps.bg_color = look[2]
		ps.set_corner_radius_all(8)
		ps.border_width_left = 4
		ps.border_color = look[3]
		ps.content_margin_left = 22
		ps.content_margin_right = 26
		ps.content_margin_top = 14
		ps.content_margin_bottom = 18
		panel.add_theme_stylebox_override("panel", ps)
		vb.add_child(panel)
		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 10)
		panel.add_child(inner)
		inner.add_child(_label(String(r[0]), UiFonts.sans(600), 14, look[5], look[6]))
		var font: Font = r[1]
		var role := String(r[0]).get_slice(" ", 0)
		for size: int in SIZES:
			var flow := HFlowContainer.new()
			flow.custom_minimum_size.x = COL_W - 48
			flow.add_theme_constant_override("h_separation", int(size * 1.1))
			flow.add_theme_constant_override("v_separation", UiFonts.line_gap(role, size))
			flow.add_child(_label("%d" % size, UiFonts.sans(500), 12, look[5], look[6]))
			for t: String in LINES:
				flow.add_child(_label(t, font, size, look[4], look[6]))
			inner.add_child(flow)
	return bg


func _label(text: String, font: Font, size: int, color: Color, shadow: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if shadow.a > 0.0:
		l.add_theme_color_override("font_shadow_color", shadow)
		l.add_theme_constant_override("shadow_offset_x", maxi(1, size / 16))
		l.add_theme_constant_override("shadow_offset_y", maxi(1, size / 16))
	return l
