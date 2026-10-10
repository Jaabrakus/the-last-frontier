extends RefCounted
## The Practice stage the effect capture tools share (tools/fx/fx_lineup.gd, tools/fx/lightning_shots.gd): the ring scene with
## the player against a standing dummy, both set a fixed distance apart on the deck, the player's crosshair held on the dummy's
## chest, a camera of the tool's own, stills and contact sheets. Windowed tools only (they draw). Read-only on the game's files;
## it changes MatchSetup's statics for the run, as any Practice launch does.
##   const FxStage := preload("res://tools/fx/fx_stage.gd")
##   var st := FxStage.new(self)             # self: the tool's SceneTree script
##   st.start("fire")                         # before anything else: it queues the scene change
##   if not await st.wait_fight(): ...        # fills st.lvl, mode, ring, p, sway, bc, axis, mid
##   st.cam = st.side_camera(52.0, 5.4, 1.8, 1.0)
##   await st.frames(30)
##   await st.reset()                         # both whole, 8 m apart, facing each other
##   st.aiming = true                         # from here every frame keeps the crosshair on the dummy

var tree: SceneTree
var lvl: RingLevel
var mode: RingMode
var ring: RingArena
var p: FrontierPlayer
var sway: SwayCaster
var bc: BendCaster
## The deck's middle (world), and its long axis (level).
var mid := Vector3.ZERO
var axis := Vector3.RIGHT
## Frames the scene has drawn since start().
var frame := 0
## +1 when a larger FrontierPlayer.pitch looks up (calibrate_pitch()).
var pitch_sign := 1.0
## While true, frames() keeps the crosshair on the dummy's chest.
var aiming := false
## The camera frames() makes current when something else took over (null: leave the scene's).
var cam: Camera3D
## Called after every frame frames() waits (a tool's own camera work; optional).
var keeper: Callable = Callable()


func _init(t: SceneTree) -> void:
	tree = t


## Practice against a standing dummy of `el` (practice `practice`), the ring scene queued. Call it once, first.
func start(el: String, practice := "stand") -> void:
	MatchSetup._aim_help = "strong"
	SwayCaster.free_override = true
	RingReplay.force = "off"                      # (no fall replay holds the tree mid-shot)
	InputSetup.ensure()
	MatchSetup.element = el
	MatchSetup.set_practice(el, practice)
	MatchSetup.incoming = true
	tree.process_frame.connect(func() -> void: frame += 1)
	tree.change_scene_to_file("res://scenes/ring.tscn")


## Waits for the fight to begin (900 frames at most) and takes hold of the level; false when there is no practice fight.
func wait_fight() -> bool:
	for i in 900:
		await tree.process_frame
		lvl = tree.current_scene as RingLevel
		mode = RingMode.find(tree)
		if lvl != null and mode != null and mode.phase == "FIGHT" and not LoadingScreen.covering():
			break
	if lvl == null or mode == null or mode.phase != "FIGHT":
		return false
	ring = lvl.ring
	p = lvl.player
	sway = SwayCaster.of(p)
	bc = BendCaster.of(p)
	p.ignore_mouse_capture = true
	p.controls = PlayerControls.new(false)
	axis = ring.axis()
	axis.y = 0.0
	axis = axis.normalized()
	mid = ring.to_global(Vector3(0.0, ring.top(), 0.0))
	return true


## A camera on the scene, `side_m` metres across the deck from its middle and `up` high, looking at `look_up` over the middle.
## Not made current: set it as `cam` (or make_current() it) when the tool wants it.
func side_camera(fov: float, side_m: float, up: float, look_up: float) -> Camera3D:
	var c := Camera3D.new()
	c.fov = fov
	c.far = 1500.0
	tree.current_scene.add_child(c)
	var side := Vector3.UP.cross(axis).normalized()
	var eye := mid + side * side_m + Vector3.UP * up
	c.global_transform = Transform3D(Basis.looking_at(mid + Vector3.UP * look_up - eye, Vector3.UP), eye)
	return c


## Waits `n` frames, keeping the camera, the crosshair and the tool's own keeper going.
func frames(n: int) -> void:
	for i in n:
		await tree.process_frame
		keep()


func keep() -> void:
	if cam != null and is_instance_valid(cam) and tree.root.get_camera_3d() != cam:
		cam.make_current()
	if aiming:
		aim()
	if keeper.is_valid():
		keeper.call()


## The player's crosshair on the dummy's chest (his camera's yaw and pitch), so every cast goes at it.
func aim() -> void:
	var f := mode.foe if mode != null else null
	if f == null or not is_instance_valid(f) or p.camera == null:
		return
	var d := (NpcSenses.chest_of(f) - p.camera.global_position).normalized()
	p.yaw = atan2(-d.x, -d.z)
	p.pitch = asin(clampf(d.y, -1.0, 1.0)) * pitch_sign


## Finds which way a larger pitch looks (it differs with the camera rig): call it once, aiming off, a few frames in.
func calibrate_pitch() -> void:
	p.pitch = 0.3
	await frames(3)
	pitch_sign = 1.0 if p.camera != null and (-p.camera.global_basis.z).y > 0.0 else -1.0
	p.pitch = 0.0


## `n` put at `at` facing `face`, still, its knock state cleared.
func place(n: Node3D, at: Vector3, face: Vector3) -> void:
	var d := face - at
	var yaw := atan2(-d.x, -d.z)
	n.global_position = at + Vector3.UP * 0.05
	if n is FrontierPlayer:
		(n as FrontierPlayer).yaw = yaw
		n.rotation.y = yaw
		(n as FrontierPlayer).velocity = Vector3.ZERO
	elif n is CharacterBody3D:
		n.rotation.y = yaw
		(n as CharacterBody3D).velocity = Vector3.ZERO
	var kn := BendKnock.peek(n)
	if kn != null:
		kn.reset()
		kn.stun_t = 0.0
		kn.lying_t = 0.0


## Everything a shot left gone, both bodies whole and placed 8 m apart facing each other.
func reset() -> void:
	if sway != null:
		sway._end_charge()
		sway.grown = false
	if tree.paused or Engine.time_scale != 1.0:
		tree.paused = false                        # (a fall's replay or slow beat left over: the next shot plays at speed)
		Engine.time_scale = 1.0
	# (Practice's own reset: both whole at their ends, the deck cleared of what bending left on it (RingArena.clear_dropped:
	# bolts, zones, lifts, walls, loose stones; never the deck's seated stones))
	mode.reset_positions()
	await frames(2)
	var sp := SpellFx.of(tree.current_scene)
	if sp != null:
		sp.kill_all()
	var a := mid - axis * 4.0
	var b := mid + axis * 4.0
	place(p, a, b)
	if mode.foe != null and is_instance_valid(mode.foe):
		place(mode.foe, b, a)
	await frames(40)


## Every CanvasLayer (HUD, hints) hidden.
func hide_ui() -> void:
	for n in tree.root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false


## The window's frame as <path> (RGB8). The image.
func snap(path: String) -> Image:
	var img := tree.root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(path)
	return img


## A contact sheet: `cells` is rows of images (every cell `cell` px), the columns headed by `col_labels`, each row by
## `row_labels` (tinted `row_colors[r]` when given); saved as <file>. `left` is the label column's width, `top` the header's
## height.
func sheet(cells: Array, row_labels: Array, col_labels: Array, cell: Vector2i, file: String, row_colors := [], left := 150,
		top := 26) -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(left + cell.x * col_labels.size(), top + cells.size() * (cell.y + 4) + 4)
	sv.transparent_bg = false
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.disable_3d = true
	tree.root.add_child(sv)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.09)
	bg.size = Vector2(sv.size)
	sv.add_child(bg)
	for c in col_labels.size():
		label(sv, String(col_labels[c]), Vector2(left + c * cell.x + 6, 3), 16, Color(0.95, 0.9, 0.6))
	for r in cells.size():
		var y := top + r * (cell.y + 4)
		var col: Color = row_colors[r] if r < row_colors.size() else (Color(0.85, 0.85, 0.85) if r % 2 == 0 else Color(0.8, 0.75, 1.0))
		label(sv, String(row_labels[r]), Vector2(6, y + 8), 14, col)
		for c in (cells[r] as Array).size():
			var tr := TextureRect.new()
			tr.texture = ImageTexture.create_from_image(cells[r][c])
			tr.position = Vector2(left + c * cell.x, y)
			tr.size = Vector2(cell)
			sv.add_child(tr)
	for i in 3:
		await tree.process_frame
	var img := sv.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(file)
	print("sheet ", file)
	sv.queue_free()


static func label(parent: Node, text: String, at: Vector2, size: int, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.position = at
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", col)
	parent.add_child(l)
