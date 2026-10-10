extends RefCounted
## The ring (scenes/ring.tscn) staged at a quiet moment with every CanvasLayer hidden (no HUD, no hints), taken through
## off-window views as tools/ring/palette_shots.gd does. Nothing third-party: our own scene, our own fighters in their
## element's ring dress, our own light. Was menu_variants/b_broadcast/stage.gd (the mock-up of the style the owner chose on
## 2026-10-10, "Arena broadcast"); the live tool tools/ui_audit/lobby_backdrops.gd needs it, so it lives here and the mock-up's
## stage.gd extends this file.
##   lobby_<el>.png      1600 x 900: your fighter on the deck at the right third, facing the camera, the far gate soft
##   cut_<el>.png        720 x 1080 with alpha: the same fighter cut out (colour from the full render, alpha from a
##                       render of the fighter alone on a clear background)
##   frame_pause.png     1600 x 900: a match under way behind you (fire against water), the HUD hidden
##   frame_end.png       1600 x 900: the deck from above at the match's end
##   frame_setup.png     1600 x 900: the deck wide, for the setup screen
## Used by tools/ui_audit/lobby_backdrops.gd and menu_variants/b_broadcast.gd (part=render). Read-only on the game: it changes
## no game file; GameSettings goes to the caller's own cfg.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
## The cut-out's render layer (the fighter's meshes get it added; the mask camera sees only it).
const CUT_LAYER := 1 << 19

var tree: SceneTree
var out := ""
var lvl: RingLevel
var ring: RingArena
var player: FrontierPlayer
var mode: RingMode
var foe: NpcFighter
var view: SubViewport
var mask_view: SubViewport
var mask_cam: Camera3D
var _hold := {}


func _init(t: SceneTree, dir: String) -> void:
	tree = t
	out = dir
	DirAccess.make_dir_recursive_absolute(out)


func _frames(k: int) -> void:
	for i in k:
		await tree.process_frame


func _until(cond: Callable, limit_s: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(limit_s * 1000.0):
		if cond.call():
			return true
		await tree.process_frame
	return false


## The ring with the player in `el` against a bot in `foe_el`, the fight begun, the bot held, the HUD hidden.
func load_ring(el: String, foe_el: String) -> bool:
	tree.paused = false
	Engine.time_scale = 1.0
	MatchSetup.incoming = true
	MatchSetup.kind = "match"
	MatchSetup.element = el
	MatchSetup.foes = [foe_el]
	MatchSetup.light = "noon"
	MatchSetup.difficulty = "normal"
	player = null
	foe = null
	tree.change_scene_to_file("res://scenes/ring.tscn")
	await _frames(12)
	lvl = tree.current_scene as RingLevel
	if lvl == null:
		return false
	await _until(func() -> bool: return not bool(lvl.get_meta(&"loading_hold", false)), 60.0)
	ring = lvl.ring
	player = lvl.player
	mode = RingMode.find(tree)
	if mode == null or player == null:
		return false
	player.ignore_mouse_capture = true
	player.controls = PlayerControls.new(false)
	await _until(func() -> bool: return mode.phase == "COUNTDOWN" and mode.foe != null, 10.0)
	mode.phase_t = RingRules.num("countdown_s", 3.0) - 0.02
	await _until(func() -> bool: return mode.phase == "FIGHT", 4.0)
	foe = mode.foe if is_instance_valid(mode.foe) else null
	if foe == null:
		return false
	foe.held = true
	await _until(func() -> bool: return player.arena_element == el, 6.0)
	await _frames(20)
	if not tree.physics_frame.is_connected(_physics):
		tree.physics_frame.connect(_physics)
	_hide_layers()
	return true


## The clock kept from running out and the staged bodies kept where they were put.
func _physics() -> void:
	if mode != null and is_instance_valid(mode) and mode.phase == "FIGHT":
		mode.phase_t = 0.0
	for b: Node3D in _hold:
		if is_instance_valid(b):
			b.global_position = _hold[b]
			(b as CharacterBody3D).velocity = Vector3.ZERO


func _hide_layers() -> void:
	for layer: Node in tree.root.find_children("*", "CanvasLayer", true, false):
		if layer.name != "OffscreenMirror":
			(layer as CanvasLayer).visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## World point at ring-local x along the deck, z across, y over the deck.
func at(x: float, z := 0.0, y := 0.0) -> Vector3:
	return ring.to_global(Vector3(x, ring.top() + y, z))


func deck_way() -> Vector3:
	return (ring.global_basis * Vector3(1.0, 0.0, 0.0)).normalized()


## `b` put at `pos` facing world `way`, still, and held there.
func place(b: Node3D, pos: Vector3, way: Vector3) -> void:
	var yaw := atan2(-way.x, -way.z)
	b.global_position = pos
	(b as CharacterBody3D).velocity = Vector3.ZERO
	if b == player:
		player.yaw = yaw
		player.rotation.y = yaw
		player.pitch = -0.05
	else:
		b.rotation.y = yaw
		b.set(&"_face", yaw)
	var m := RingMoves.of(b)
	if m != null:
		m.placed()
	_hold[b] = pos


func release() -> void:
	_hold.clear()


## The views (made once; they live on the root, so they outlast each ring).
func _views(px: Vector2i) -> void:
	if view == null:
		view = OffscreenView.new()
		view.process_mode = Node.PROCESS_MODE_ALWAYS
		tree.root.add_child(view)
		view.setup(tree.root, px)
		mask_view = SubViewport.new()
		mask_view.process_mode = Node.PROCESS_MODE_ALWAYS
		mask_view.transparent_bg = true
		mask_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		mask_view.msaa_3d = Viewport.MSAA_4X
		tree.root.add_child(mask_view)
		mask_cam = Camera3D.new()
		mask_cam.cull_mask = CUT_LAYER
		mask_cam.current = true
		var env := Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		env.glow_enabled = false
		env.fog_enabled = false
		env.volumetric_fog_enabled = false
		env.ssao_enabled = false
		env.sdfgi_enabled = false
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color.WHITE
		mask_cam.environment = env
		mask_view.add_child(mask_cam)
	view.size = px
	mask_view.size = px
	view.copy_settings(tree.root)


## Frozen: the clock, the bodies and the light held; the 3D drawn only off-window.
func freeze() -> void:
	tree.root.disable_3d = true
	var rig := lvl.environment_rig
	rig.follow_camera = view.camera if view != null else null
	rig.process_mode = Node.PROCESS_MODE_ALWAYS
	if lvl.look != null:
		lvl.look.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.paused = true
	Engine.time_scale = 0.0


func thaw() -> void:
	tree.paused = false
	Engine.time_scale = 1.0
	tree.root.disable_3d = false


## A still through the view: camera at `from` looking at `to` (fov degrees), `dof` > 0: the far blur from that distance.
func shot(name: String, px: Vector2i, from: Vector3, to: Vector3, fov: float, dof := 0.0) -> Image:
	_views(px)
	lvl.environment_rig.follow_camera = view.camera
	view.camera.fov = fov
	view.camera.look_at_from_position(from, to)
	var base := lvl.environment_rig.get_camera_attributes()
	if dof > 0.0 and base != null:
		var a := base.duplicate() as CameraAttributesPractical
		a.dof_blur_far_enabled = true
		a.dof_blur_far_distance = dof
		a.dof_blur_far_transition = dof * 1.6
		a.dof_blur_amount = 0.06
		view.camera.attributes = a
	else:
		view.camera.attributes = null
	for i in 50:
		await tree.process_frame
		RenderingServer.force_draw(false)
	var img: Image = view.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	if name != "":
		img.save_png(out.path_join(name + ".png"))
		print("BROADCAST RENDER ", name)
	return img


## The fighter cut out: the colour of a full render (saved as `name`.png too when `keep`), the alpha of a render of the
## fighter alone (his blob shadow left out; cloth drawn see-through counts as whole) -> `name`_cut.png.
func cutout(name: String, px: Vector2i, from: Vector3, to: Vector3, fov: float, dof := 0.0, keep := false) -> Image:
	var tagged: Array[VisualInstance3D] = []
	for vi: Node in player.find_children("*", "VisualInstance3D", true, false):
		if vi is Decal or vi is Light3D or vi is GPUParticles3D or String(vi.name).to_lower().contains("shadow"):
			continue
		(vi as VisualInstance3D).layers |= CUT_LAYER
		tagged.append(vi as VisualInstance3D)
	var col := await shot(name if keep else "", px, from, to, fov, dof)
	mask_cam.fov = fov
	mask_cam.look_at_from_position(from, to)
	for i in 12:
		await tree.process_frame
		RenderingServer.force_draw(false)
	var mask: Image = mask_view.get_texture().get_image()
	mask.convert(Image.FORMAT_RGBA8)
	col.convert(Image.FORMAT_RGBA8)
	var cd := col.get_data()
	var md := mask.get_data()
	var n := px.x * px.y
	for i in n:
		cd[i * 4 + 3] = mini(255, int(md[i * 4 + 3] * 1.8))
	var img := Image.create_from_data(px.x, px.y, false, Image.FORMAT_RGBA8, cd)
	img.save_png(out.path_join(name + "_cut.png"))
	print("BROADCAST RENDER ", name, "_cut")
	for vi in tagged:
		vi.layers &= ~CUT_LAYER
	return img
