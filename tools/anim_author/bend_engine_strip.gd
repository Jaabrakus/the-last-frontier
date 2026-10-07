extends SceneTree
## In-engine review strips of our own ring-sport clips (animations_extra/Frontier_Bend.res): each clip posed on a ring
## competitor in his element's ring dress (NpcSquad.element_look of ring_team_a, dressed as NpcBody.build dresses a bot: Actor_B
## skinned by CharacterBodyMesh, PlayerAppearance.dress) standing on the dressed ring's deck (scenes/ring.tscn in a practice,
## RingDressing and RingLook at its light), seen from where the game sees him: the player's own camera behind him (the
## stock ring's arm, 5.25 m back and its pivot up; FOV 52.5) and an opponent's eye 15 m off, in front three quarters and
## square from the side (FOV 52.5), a row each, at the clip's key moments (a column each). The bones the clip keys are set
## from its tracks (nothing else is played); an airborne clip is shown lifted off the deck (air=...). The 15 m cells are cut
## from a 1920 x 1080 frame at its own pixels (the size he really is on a 1080p screen); the behind cell is the frame's middle
## scaled to the cell. An edge clip (meta lip_y: keyed in the hang's frame) is posed hanging at the deck's end lip instead,
## over a stand-in lip (the stock ring's pale coping over a flat stone face), and seen from the hang's own camera out over the
## water, from a foe on the deck 15 m off and from 15 m along the lip (EDGE_VIEWS). Windowed (it draws):
##   Godot --path . -s tools/anim_author/bend_engine_strip.gd -- out=<dir> clips=own-bend-fall,... [air=own-bend-fall,...]
##       [light=noon] [elements=earth,water,fire,air] (cycled over the clips) [suffix=_engine]
##       [rise=own-bend-edge-jump:11.8:19.9] (the code's jump, vy and gravity, added to that clip's root)
##       [stone=own-bend-jab-rise,...] (earth's Pop stone drawn where the code holds it, BendR3.pop_stone: 0.55 m ahead,
##       0.45 m to his right, 1.25 m up, radius 0.22 m, from the clip's stone_s on (the hand reaching it), else its strike)
##       [lip=own-bend-teeter,...] (the clip posed at the deck's end lip facing out over the water, the balls of the feet on
##       the stand-in coping's nose, the views turned with him)
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

## An edge clip's views (it is keyed in the hang's frame: the origin lip_y under the lip and lip_out out from the face, +Z the
## deck), placed at the deck's end lip: the player's own camera out over the water behind him (the hang's arm, about 5 m,
## its pivot a metre over the lip), a foe standing on the deck 15 m off in front three quarters, and 15 m off along the lip
## (his profile against the face). Each [from, at] is over the lip's height (added at the shot).
const EDGE_VIEWS := {
	"behind 5 m (the hang camera)": [Vector3(0.0, 2.2, -4.5), Vector3(0.0, 0.7, 1.2), 52.5, Vector2i(960, 720)],
	"foe on the deck 15 m, front 3/4": [Vector3(-7.5, 1.7, 13.0), Vector3(0.0, 0.0, 0.35), 52.5, Vector2i(480, 360)],
	"15 m along the lip (profile)": [Vector3(-14.8, 1.0, -0.6), Vector3(0.0, -0.3, 0.35), 52.5, Vector2i(480, 360)],
}
## The stand-in lip at the deck's end for the edge clips (the stock ring's pale coping over a stone face, as spec 5.1 draws
## it; the classic ring's plinth foot under it is covered so the face is one plane): its depth past the deck's end (m).
const LIP_OUT := 0.2
## How far along the lip from its middle the edge clips are posed (m): the stock ring stands a lantern pier just outside the
## middle of each lip (RingArena's lantern spots), which stood between the hang camera and the climber (pass 3 of P2's
## review), so the figure is shown on the open stretch of stone beside it.
const EDGE_ALONG := 2.0
## Earth's Pop stone where the code holds it (BendR3.pop_stone), in the figure's frame (+X his left), and its radius (m).
const POP_STONE := Vector3(-0.45, 1.25, 0.55)
const POP_STONE_R := 0.22
## A lip clip (the teeter) stands this far in from the lip's nose, so the balls of his feet are on the coping's edge (m).
const LIP_STAND_IN := 0.08
## A lip clip's views (he faces out over the water, +Z): the player's camera behind him over the deck, a foe on the deck 15 m
## off behind him three quarters, and 15 m along the lip on the open side (his profile against the water; the lantern pier
## stands on the other side of him).
const LIP_VIEWS := {
	"behind 5 m (the player's camera)": [Vector3(0.0, 2.35, -5.1), Vector3(0.0, 1.25, 1.5), 52.5, Vector2i(960, 720)],
	"foe on the deck 15 m, 3/4 behind": [Vector3(-7.5, 1.7, -13.0), Vector3(0.0, 1.0, 0.0), 52.5, Vector2i(480, 360)],
	"15 m along the lip (profile)": [Vector3(14.8, 1.8, -0.4), Vector3(0.0, 1.0, 0.3), 52.5, Vector2i(480, 360)],
}
## The wall a clip names (meta wall_z: the wall break) drawn there, a see-through stone pane from the deck up (m).
const WALL_SIZE := Vector3(2.4, 3.2, 0.08)
const WALL_COLOR := Color(0.5, 0.5, 0.54, 0.42)

var out := ""
var only: PackedStringArray = []
var edge_xf := Transform3D.IDENTITY
## rise=<clip>:<vy>:<g>[;...]: the code's own lift on that clip (the edge jump), added to the figure's place at the shot.
var rise := {}
var _cur_rise := Vector2.ZERO
var stone_clips: PackedStringArray = []
var lip_clips: PackedStringArray = []
var _stone: MeshInstance3D
var _cur := ""
var _lip_block: Node3D
var _wall: Node3D
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
		elif a.begins_with("stone="):
			stone_clips = a.get_slice("=", 1).split(",", false)
		elif a.begins_with("lip="):
			lip_clips = a.get_slice("=", 1).split(",", false)
		elif a.begins_with("rise="):
			for r in a.get_slice("=", 1).split(";", false):
				rise[r.get_slice(":", 0)] = Vector2(float(r.get_slice(":", 1)), float(r.get_slice(":", 2)))
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
	_edge_setup(ring)
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
		_cur_rise = rise.get(nm, Vector2.ZERO)
		_cur = nm
		var times := _moments(a)
		var cells: Array[Image] = []
		for vn: String in (EDGE_VIEWS if a.has_meta(&"lip_y") else (LIP_VIEWS if nm in lip_clips else VIEWS)):
			for tm: Array in times:
				cells.append(await _snap(a, nm in airborne, float(tm[0]), vn, "%s (%s)  %s %.2f s (f%d)\n%s" % [nm.trim_prefix(
						"own-bend-"), el, tm[1], float(tm[0]), int(round(float(tm[0]) * 30.0)), vn]))
		_sheet(cells, times.size(), out.path_join("%s%s.png" % [nm.trim_prefix("own-bend-"), suffix]))
	print("BEND ENGINE STRIP DONE")
	quit(0)


## The edge clips' place: at the deck's +X end (open, no ropes), on the middle of the lip, facing back along the deck, the
## origin lip_y (read per clip) under the lip and lip_out out from the stand-in face; and the stand-in lip block there.
func _edge_setup(ring: RingArena) -> void:
	if ring == null:
		return
	var hl := ring.half_l()
	var lip := ring.to_global(Vector3(hl + LIP_OUT, ring.top(), EDGE_ALONG))
	var into := -ring.global_basis.x
	into.y = 0.0
	edge_xf = Transform3D(Basis.looking_at(-into.normalized(), Vector3.UP), lip)
	_lip_block = Node3D.new()
	root.add_child(_lip_block)
	_lip_block.global_transform = edge_xf
	# (in the block's frame +Z is the deck: the face from the lip down to the water, then the pale coping on top)
	for part: Array in [[Vector3(6.0, 2.6, LIP_OUT + 0.1), Vector3(0.0, -1.3, (LIP_OUT + 0.1) * 0.5), Color(0.44, 0.42, 0.4)],
			[Vector3(6.0, 0.08, 0.29), Vector3(0.0, -0.035, 0.105), Color(0.83, 0.8, 0.73)]]:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = part[0]
		m.mesh = b
		var mat := StandardMaterial3D.new()
		mat.albedo_color = part[2]
		mat.roughness = 0.92
		m.material_override = mat
		m.position = part[1]
		_lip_block.add_child(m)


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
	# (the follow-through between the key moment and the recovery when it is three frames or more from both: the air
	# dodge's twist, the double jump's tuck, the heavy landing's sag; labelled as the contact sheets label it)
	var back := float(a.get_meta(&"back_s", a.length * 0.7))
	var from := maxf(key, hold)
	var mid: float = floorf((from + back) * 0.5 * 30.0 + 1e-3) / 30.0
	if mid - from >= 2.5 / 30.0 and back - mid >= 2.5 / 30.0:
		out.append([mid, "follow"])
	out.append_array([[back, "back"], [a.length, "end"]])
	# (in time order, a moment within half a frame of an earlier one dropped: a clip held at its end, the teeter, has its
	# hold on its last frame and no recovery of its own)
	out.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var kept := []
	for m: Array in out:
		if not kept.is_empty() and absf(float(m[0]) - float(kept[-1][0])) < 0.5 / 30.0:
			continue
		kept.append(m)
	return kept


func _snap(a: Animation, air: bool, t: float, vn: String, text: String) -> Image:
	sk.reset_bone_poses()
	if _wall != null:
		_wall.visible = false
	# (a layer that keys only some bones, the air legs, shown under the cast it plays beneath: UNDER at its strike)
	if not _keys_root(a) and lib.has_animation(UNDER):
		var u := lib.get_animation(UNDER)
		_set_clip(u, float(u.get_meta(&"strike_s", 0.0)))
	_set_clip(a, t)
	if _cur_rise != Vector2.ZERO:
		# (the code's jump lifts the body while the clip plays: added to the root, the cameras kept on the lip)
		var rb := sk.find_bone("root")
		sk.set_bone_pose_position(rb, sk.get_bone_pose_position(rb) + Vector3.UP * (_cur_rise.x * t - 0.5 * _cur_rise.y * t * t))
	if a.has_meta(&"lip_y"):
		# (the hang's frame: the origin lip_y under the lip and lip_out out from the face; the views over the lip's height)
		var ly := float(a.get_meta(&"lip_y"))
		fig.global_transform = edge_xf.translated_local(Vector3(0.0, -ly, -float(a.get_meta(&"lip_out", 0.35))))
		var spec: Array = (EDGE_VIEWS[vn] as Array).duplicate()
		spec[0] = (spec[0] as Vector3) + Vector3.UP * ly
		spec[1] = (spec[1] as Vector3) + Vector3.UP * ly
		return await _shoot(spec, text, edge_xf.basis)
	if _cur in lip_clips:
		# (at the deck's end lip facing out over the water: the edge frame turned about, stood LIP_STAND_IN in from the nose)
		var lxf := edge_xf * Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 0.0, LIP_STAND_IN))
		fig.global_transform = lxf
		_show_wall(a)
		_show_stone(a, t)
		return await _shoot(LIP_VIEWS[vn], text, lxf.basis)
	fig.global_transform = deck_xf.translated(Vector3.UP * (AIR_LIFT if air else 0.0))
	_show_wall(a)
	_show_stone(a, t)
	return await _shoot(VIEWS[vn], text)


## Earth's Pop stone drawn where the code holds it (POP_STONE in the figure's frame) for a stone= clip from the moment its
## hand reaches it (meta stone_s; strike_s for a clip without one).
func _show_stone(a: Animation, t: float) -> void:
	if _stone == null:
		_stone = MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = POP_STONE_R
		m.height = POP_STONE_R * 2.0
		_stone.mesh = m
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.46, 0.42, 0.37)
		mat.roughness = 0.95
		_stone.material_override = mat
		root.add_child(_stone)
	var from := float(a.get_meta(&"stone_s", a.get_meta(&"strike_s", 0.0)))
	_stone.visible = _cur in stone_clips and t >= from - 1e-4
	if _stone.visible and fig != null:
		_stone.global_position = fig.global_transform * POP_STONE


## The wall a clip names (meta wall_z) shown wall_z ahead of the figure, standing on the deck; hidden for every other clip.
func _show_wall(a: Animation) -> void:
	if _wall == null:
		_wall = Node3D.new()
		root.add_child(_wall)
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = WALL_SIZE
		m.mesh = b
		var mat := StandardMaterial3D.new()
		mat.albedo_color = WALL_COLOR
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.roughness = 0.9
		m.material_override = mat
		m.position = Vector3(0.0, WALL_SIZE.y * 0.5, WALL_SIZE.z * 0.5)
		_wall.add_child(m)
	_wall.visible = a.has_meta(&"wall_z")
	if _wall.visible:
		_wall.global_transform = deck_xf.translated_local(Vector3(0.0, 0.0, float(a.get_meta(&"wall_z"))))


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


func _shoot(spec: Array, text: String, basis := Basis()) -> Image:
	var b0 := deck_xf.basis if basis == Basis() else basis
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
