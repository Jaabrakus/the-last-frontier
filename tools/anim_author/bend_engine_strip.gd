extends SceneTree
## In-engine review strips of our own ring-sport clips (animations_extra/Frontier_Bend.res): each clip posed on a ring
## competitor in his element's ring dress (NpcSquad.element_look of ring_team_a, dressed as NpcBody.build dresses a bot: Actor_B
## skinned by CharacterBodyMesh, PlayerAppearance.dress) standing on the dressed ring's deck (scenes/ring.tscn in a practice,
## RingDressing and RingLook at its light), seen from where the game sees him: the player's own camera behind him (the
## stock ring's arm, 5.25 m back and its pivot up; FOV 52.5) and an opponent's eye 15 m off, in front three quarters and
## square from the side (FOV 52.5), a row each, at the clip's key moments (a column each). The bones the clip keys are set
## from its tracks (nothing else is played); an airborne clip is shown lifted off the deck (air=...). The 15 m cells are cut
## from a 1920 x 1080 frame at its own pixels (the size he really is on a 1080p screen); the behind cell is the frame's middle
## scaled to the cell. Windowed (it draws):
##   Godot --path . -s tools/anim_author/bend_engine_strip.gd -- out=<dir> clips=own-bend-fall,... [air=own-bend-fall,...]
##       [light=noon] [elements=earth,water,fire,air] (cycled over the clips) [suffix=_engine]
## Writes <dir>/<clip without own-bend->< suffix>.png. Ends with BEND ENGINE STRIP DONE.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const LIB := "res://animations_extra/Frontier_Bend.res"
const GLB := "res://assets/character/actor_b_body.glb"
const W := 1920
const H := 1080
const CELL := Vector2i(480, 360)
## How high an airborne clip's figure is shown over the deck (m).
const AIR_LIFT := 1.4
## The cast a legs-only layer is shown under (at its strike).
const UNDER := &"own-bend-air-palm"
## [from, at, fov, the crop's size in the frame (its middle)] in the competitor's own frame (+Z his forward, +X his left).
const VIEWS := {
	"behind 5 m (the player's camera)": [Vector3(0.0, 2.35, -5.1), Vector3(0.0, 1.25, 1.5), 52.5, Vector2i(960, 720)],
	"foe 15 m, front 3/4": [Vector3(-7.5, 1.7, 13.0), Vector3(0.0, 1.0, 0.0), 52.5, Vector2i(480, 360)],
	"15 m, side (over the rail)": [Vector3(-14.8, 3.2, 0.0), Vector3(0.0, 1.0, 0.0), 52.5, Vector2i(480, 360)],
}

var out := ""
var only: PackedStringArray = []
var airborne: PackedStringArray = []
var light := "noon"
var elements: PackedStringArray = ["earth", "water", "fire", "air"]
var suffix := "_engine"
var view
var label: Label
var sk: Skeleton3D
var fig: Node3D
var mesh: CharacterBodyMesh
var deck_xf := Transform3D.IDENTITY
var lib: AnimationLibrary


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.get_slice("=", 1)
		elif a.begins_with("clips="):
			only = a.get_slice("=", 1).split(",", false)
		elif a.begins_with("air="):
			airborne = a.get_slice("=", 1).split(",", false)
		elif a.begins_with("light="):
			light = a.get_slice("=", 1)
		elif a.begins_with("elements="):
			elements = a.get_slice("=", 1).split(",", false)
		elif a.begins_with("suffix="):
			suffix = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure()
	MatchSetup.incoming = true
	MatchSetup.element = "earth"
	MatchSetup.light = light
	MatchSetup.set_practice("water", "stand")
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _run() -> void:
	for i in 4:
		await process_frame
	var lvl := current_scene as RingLevel
	if lvl == null or out == "":
		print("BEND ENGINE STRIP FAILED: no ring or no out=")
		quit(1)
		return
	var t := 0
	while t < 1200 and (float(lvl.get_meta(&"loading_progress", 1.0)) < 1.0 or bool(lvl.get_meta(&"loading_hold", false))):
		await process_frame
		t += 1
	# (the match's own two out of sight: the clip's figure alone on the deck)
	if lvl.player != null:
		lvl.player.visible = false
		if lvl.player.hud != null:
			lvl.player.hud.visible = false
	_hide_bodies()
	# the figure stands a little toward the player's end of the deck's middle, facing along the deck
	var ring := lvl.ring
	var at := ring.to_global(Vector3(-1.5, ring.top(), 0.0)) if ring != null else Vector3.ZERO
	var face := (ring.global_basis.x if ring != null else Vector3.FORWARD)
	face.y = 0.0
	# (the glb's figure faces its +Z: the basis' z the way he faces)
	deck_xf = Transform3D(Basis.looking_at(-face.normalized(), Vector3.UP), at)
	lib = load(LIB) as AnimationLibrary
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(W, H))
	root.disable_3d = true
	if lvl.environment_rig != null:
		lvl.environment_rig.follow_camera = view.camera
	label = Label.new()
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	view.add_child(label)
	for i in 60:
		await process_frame
	var idx := 0
	for nm: String in only:
		if not lib.has_animation(StringName(nm)):
			print("BEND ENGINE STRIP: no clip ", nm)
			continue
		var el: String = elements[idx % elements.size()]
		idx += 1
		_dress(el)
		var a := lib.get_animation(StringName(nm))
		var times := _moments(a)
		var cells: Array[Image] = []
		for vn: String in VIEWS:
			for tm: Array in times:
				cells.append(await _snap(a, nm in airborne, float(tm[0]), vn, "%s (%s)  %s %.2f s (f%d)\n%s" % [nm.trim_prefix(
						"own-bend-"), el, tm[1], float(tm[0]), int(round(float(tm[0]) * 30.0)), vn]))
		_sheet(cells, times.size(), out.path_join("%s%s.png" % [nm.trim_prefix("own-bend-"), suffix]))
	print("BEND ENGINE STRIP DONE")
	quit(0)


## Every body of the match out of sight (the practice dummy, a bot spawned late): the clip's figure alone on the deck.
func _hide_bodies() -> void:
	for n in current_scene.find_children("*", "", true, false):
		if n is CharacterBody3D or n is NpcFighter:
			(n as Node3D).visible = false
			n.process_mode = Node.PROCESS_MODE_DISABLED


## A new figure in `element`'s ring dress (the old one gone).
func _dress(element: String) -> void:
	_hide_bodies()
	if fig != null:
		fig.queue_free()
	fig = (load(GLB) as PackedScene).instantiate() as Node3D
	root.add_child(fig)
	fig.global_transform = deck_xf
	sk = fig.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for ap: AnimationPlayer in fig.find_children("*", "AnimationPlayer", true, false):
		ap.stop()
		ap.active = false
	for mi: MeshInstance3D in fig.find_children("*", "MeshInstance3D", true, false):
		mi.visible = false
	mesh = CharacterBodyMesh.attach(sk, null, GLB)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1750 + hash(element)
	var look := NpcSquad.element_look("ring_team_a", element, rng)
	if look.is_empty():
		look = NpcFactions.look_for("ring_team_a", rng)
	if mesh != null:
		PlayerAppearance.dress(mesh, AppearanceStore.validate(look))


## The key moments: a loop's quarters, else the start, the strike and the hold (both, in their order, when they differ: the
## strike is a reaction's key moment and must be seen in game), the recovery's start and the end.
func _moments(a: Animation) -> Array:
	if a.loop_mode != Animation.LOOP_NONE:
		return [[0.0, "loop 0/4"], [a.length * 0.25, "loop 1/4"], [a.length * 0.5, "loop 2/4"], [a.length * 0.75, "loop 3/4"]]
	var key := float(a.get_meta(&"strike_s", 0.0))
	var hold := float(a.get_meta(&"hold_s", key))
	var out := [[0.0, "start"]]
	if absf(key - hold) < 0.5 / 30.0:
		out.append([key, "strike"])
	elif key < hold:
		out.append_array([[key, "strike"], [hold, "hold"]])
	else:
		out.append_array([[hold, "hold"], [key, "strike"]])
	# (the peak between the key moment and the recovery when it is three frames or more from both: the air dodge's twist,
	# the double jump's tuck, the heavy landing's sag)
	var back := float(a.get_meta(&"back_s", a.length * 0.7))
	var from := maxf(key, hold)
	var mid: float = floorf((from + back) * 0.5 * 30.0 + 1e-3) / 30.0
	if mid - from >= 2.5 / 30.0 and back - mid >= 2.5 / 30.0:
		out.append([mid, "peak"])
	out.append_array([[back, "back"], [a.length, "end"]])
	return out


func _snap(a: Animation, air: bool, t: float, vn: String, text: String) -> Image:
	sk.reset_bone_poses()
	# (a layer that keys only some bones, the air legs, shown under the cast it plays beneath: UNDER at its strike)
	if not _keys_root(a) and lib.has_animation(UNDER):
		var u := lib.get_animation(UNDER)
		_set_clip(u, float(u.get_meta(&"strike_s", 0.0)))
	_set_clip(a, t)
	fig.global_transform = deck_xf.translated(Vector3.UP * (AIR_LIFT if air else 0.0))
	return await _shoot(VIEWS[vn], text)


func _keys_root(a: Animation) -> bool:
	for i in a.get_track_count():
		if String(a.track_get_path(i).get_concatenated_subnames()) == "root":
			return true
	return false


func _set_clip(a: Animation, t: float) -> void:
	for i in a.get_track_count():
		var b := sk.find_bone(String(a.track_get_path(i).get_concatenated_subnames()))
		if b < 0:
			continue
		match a.track_get_type(i):
			Animation.TYPE_ROTATION_3D:
				sk.set_bone_pose_rotation(b, a.rotation_track_interpolate(i, t))
			Animation.TYPE_POSITION_3D:
				sk.set_bone_pose_position(b, a.position_track_interpolate(i, t))


func _shoot(spec: Array, text: String) -> Image:
	var b0 := deck_xf.basis
	var o := fig.global_position
	view.camera.fov = float(spec[2])
	var from: Vector3 = o + b0 * (spec[0] as Vector3)
	var to: Vector3 = o + b0 * (spec[1] as Vector3)
	view.camera.global_transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), from)
	var crop: Vector2i = spec[3]
	var k := float(crop.x) / float(CELL.x)
	label.position = Vector2((Vector2i(W, H) - crop) / 2) + Vector2(8, 6) * k
	label.add_theme_font_size_override("font_size", int(15.0 * k))
	label.add_theme_constant_override("outline_size", int(4.0 * k))
	label.text = text
	for f in 6:
		await process_frame
	for f in 3:
		RenderingServer.force_draw(false)
		await process_frame
	var img: Image = view.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var cut := img.get_region(Rect2i((Vector2i(W, H) - crop) / 2, crop))
	if crop != CELL:
		cut.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
	print("  cell: ", text.replace("\n", " | "))
	return cut


func _sheet(cells: Array[Image], cols: int, path: String) -> void:
	if cells.is_empty():
		return
	cols = maxi(1, mini(cols, cells.size()))
	var rows := int(ceil(cells.size() / float(cols)))
	var sheet := Image.create(CELL.x * cols, CELL.y * rows, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.1, 0.1, 0.1))
	for i in cells.size():
		sheet.blit_rect(cells[i], Rect2i(Vector2i.ZERO, CELL), Vector2i((i % cols) * CELL.x, (i / cols) * CELL.y))
		sheet.fill_rect(Rect2i((i % cols) * CELL.x, (i / cols) * CELL.y, 2, CELL.y), Color(0.05, 0.05, 0.05))
	sheet.save_png(path)
	print("BEND ENGINE SHEET -> ", path)
