extends SceneTree
## Lightning's Spellbreak shading, old against new, for the owner (the shots half of tests/fx/test_lightning_look.gd, which keeps
## the headless checks): the old cel bolt against the restyled one (BendLooks.SB_BOLT: our own forked bolt drawn with
## shaders/cascade/lightning_bolt.gdshader on Spellbreak's lightning textures) in a fire Practice against a standing dummy (the
## Spellbreak bridge off: SbFx.force_on false), the player and the dummy 8 m apart, from the side and from over the player's
## shoulder: frames at the lock's charge, the release (+3 frames), the strike's first frame and +6 / +12 frames (the hit, the
## erosion). The strike's forks are seeded the same for both looks. Writes
## artifacts/fx_integration/lightning/frames/<side|eye>_<old|new>_<phase>.png and compare.png (side), compare_eye.png (over the
## shoulder), compare_zoom.png (the hands and the bolt's middle at full size). Optional out=<dir>. Windowed only (it draws).
##   zsh tools/loop/godot_run.sh --path . --resolution 1600x900 --fixed-fps 60 -s tools/fx/lightning_shots.gd [-- out=<dir>]
## The wrapper adds --disable-vsync --max-fps 60 and never pins the window on top. The stage is tools/fx/fx_stage.gd.

const FxStage := preload("res://tools/fx/fx_stage.gd")
const SHOTS_LIMIT_S := 600.0
const PHASES := ["charge", "release", "strike00", "strike06", "strike12"]
const PHASE_LABELS := ["charge (lock)", "release (hand flash)", "strike", "strike +0.1 s", "hit / erosion +0.2 s"]

var out := ""
var st: FxStage
var side_cam: Camera3D
var eye_cam: Camera3D
var view := "side"


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("lightning_shots: needs a window (not --headless)")
		quit(1)
		return
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		if kv.get_slice("=", 0) == "out":
			out = kv.get_slice("=", 1)
	if out == "":
		out = ProjectSettings.globalize_path("res://").path_join("artifacts/fx_integration/lightning")
	DirAccess.make_dir_recursive_absolute(out.path_join("frames"))
	create_timer(SHOTS_LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("LIGHTNING SHOTS FAILED (watchdog)")
		quit(2))
	SbFx.force_on = false                         # (today's looks for everything else: only the bolt's shading differs)
	st = FxStage.new(self)
	st.keeper = _keep
	st.start("fire")
	_run.call_deferred()


## The camera of the view in force (the side camera, or over the player's shoulder looking at the dummy); the stage keeps the
## crosshair on the dummy's chest.
func _keep() -> void:
	var f := st.mode.foe if st.mode != null else null
	if view == "eye" and eye_cam != null and f != null and is_instance_valid(f):
		var fwd := f.global_position - st.p.global_position
		fwd.y = 0.0
		fwd = fwd.normalized()
		var right := fwd.cross(Vector3.UP).normalized()
		var e := st.p.global_position - fwd * 3.2 + right * 0.9 + Vector3.UP * 2.0
		eye_cam.global_transform = Transform3D(Basis.looking_at(f.global_position + Vector3.UP - e, Vector3.UP), e)
	var want := eye_cam if view == "eye" else side_cam
	if want != null and root.get_camera_3d() != want:
		want.make_current()


func _run() -> void:
	if not await st.wait_fight():
		print("LIGHTNING SHOTS FAILED: no practice fight")
		quit(1)
		return
	side_cam = st.side_camera(52.0, 5.4, 1.8, 1.2)
	eye_cam = Camera3D.new()
	eye_cam.fov = 62.0
	eye_cam.far = 1500.0
	current_scene.add_child(eye_cam)
	side_cam.make_current()
	await st.frames(30)
	await st.calibrate_pitch()
	for v: String in ["side", "eye"]:
		view = v
		for look_new in [false, true]:
			BendLooks.sb_bolt = look_new
			await _shot(v, "new" if look_new else "old")
	BendLooks.sb_bolt = BendLooks.SB_BOLT
	await _compose("side", Rect2i(0, 250, 1600, 470), "compare.png")
	await _compose("eye", Rect2i(260, 140, 1080, 640), "compare_eye.png")
	await _zoom()
	print("LIGHTNING SHOTS DONE -> ", out)
	quit(0)


## Whether the strike's bolt is drawn now (the restyled one: a long SbBolt; the old one: a pool bolt's strips).
func _strike_on() -> bool:
	var pool := ToonFxPool.of(current_scene)
	if pool == null:
		return false
	for c in pool.get_children():
		if c is BendLooks.SbBolt:
			var sb := c as BendLooks.SbBolt
			if sb.on and sb.a.distance_to(sb.b) > 1.5:
				return true
		elif c is MeshInstance3D and (c as MeshInstance3D).visible and (c as MeshInstance3D).mesh is ImmediateMesh \
				and ((c as MeshInstance3D).mesh as ImmediateMesh).get_surface_count() > 0:
			return true
	return false


func _arc_on() -> bool:
	var pool := ToonFxPool.of(current_scene)
	if pool == null:
		return false
	for c in pool.get_children():
		if c is BendLooks.SbBolt and (c as BendLooks.SbBolt).on:
			return true
	return false


func _shot(v: String, look: String) -> void:
	await st.reset()
	st.hide_ui()
	st.aiming = true
	await st.frames(3)
	var sway := st.sway
	sway.move = "fire_arc"
	sway._pin_id = "fire_arc"
	sway._pin_mode = "lightning"
	sway._pin_on = true
	sway._began()
	# (the lock filling; the frame taken near its end, with an arc on the hands when the restyled charge has one)
	for i in 130:
		if sway.charge != null and is_instance_valid(sway.charge):
			sway.charge.set(&"level", clampf(float(i) / 110.0, 0.0, 1.0))
		await st.frames(1)
		if i >= 110 and (look == "old" or _arc_on()):
			break
	_snap(v, look, "charge")
	sway._end_charge()
	sway.move = ""
	sway._pin_on = false
	BendCast.cast(st.bc, "fire_arc", "lightning")
	var rel := st.frame
	var s0 := -1
	while st.frame - rel < 90:
		await process_frame
		st.keep()
		var k := st.frame - rel
		if k == 3:
			_snap(v, look, "release")
		if s0 < 0 and _strike_on():
			s0 = k
		if s0 < 0 and k >= 10:
			ToonFx.vis_rng.seed = 777               # (the same forks for both looks: the strike is built in a frame or two)
		if s0 >= 0:
			var d := k - s0
			if d in [0, 6, 12]:
				_snap(v, look, "strike%02d" % d)
			if d >= 12:
				break
	st.aiming = false
	print("  shot %s %s: strike %d frames after the release" % [v, look, s0])


func _snap(v: String, look: String, ph: String) -> void:
	st.snap(out.path_join("frames").path_join("%s_%s_%s.png" % [v, look, ph]))


## A sheet of view `v`: the old row above the new row, PHASES across, each frame cut to `crop`.
func _compose(v: String, crop: Rect2i, file: String) -> void:
	var cw := 560
	var ch := int(round(float(cw) * crop.size.y / crop.size.x))
	var rows := [["old", "OLD (today's cel bolt)"], ["new", "NEW (Spellbreak shading)"]]
	var cells: Array = []
	for r: Array in rows:
		var line: Array = []
		for ph: String in PHASES:
			var img := Image.load_from_file(out.path_join("frames").path_join("%s_%s_%s.png" % [v, r[0], ph]))
			if img == null or img.is_empty():
				img = Image.create(crop.size.x, crop.size.y, false, Image.FORMAT_RGB8)
			else:
				img = img.get_region(crop)
			img.resize(cw, ch, Image.INTERPOLATE_LANCZOS)
			line.append(img)
		cells.append(line)
	await _sheet(cells, [rows[0][1], rows[1][1]], PHASE_LABELS, Vector2i(cw, ch), file)


## compare_zoom.png: at full size, old above new: the caster's hands at the charge and the release, the bolt's middle at the
## strike and +0.1 s.
func _zoom() -> void:
	var hands := Rect2i(760, 250, 840, 300)
	var middle := Rect2i(380, 330, 840, 300)
	var cols := [["charge", hands], ["release", hands], ["strike00", middle], ["strike06", middle]]
	var cells: Array = []
	for look: String in ["old", "new"]:
		var line: Array = []
		for c: Array in cols:
			var crop: Rect2i = c[1]
			var img := Image.load_from_file(out.path_join("frames").path_join("side_%s_%s.png" % [look, c[0]]))
			line.append(img.get_region(crop) if img != null and not img.is_empty() else Image.create(crop.size.x, crop.size.y,
					false, Image.FORMAT_RGB8))
		cells.append(line)
	await _sheet(cells, ["OLD", "NEW"], ["charge (the caster's hands)", "release (hand flash)", "strike (the bolt's middle)",
			"strike +0.1 s"], middle.size, "compare_zoom.png")


func _sheet(cells: Array, row_labels: Array, col_labels: Array, cell: Vector2i, file: String) -> void:
	await st.sheet(cells, row_labels.map(func(l: String) -> String: return l.replace(" (", "\n(")), col_labels, cell, out.path_join(file))
