extends SceneTree
## Contact sheets of our own ring-sport clips (animations_extra/Frontier_Bend.res: tools/anim_author/install_bend.gd) for the
## owner to judge by eye before any more are authored (he rejected and deleted a stiff solver-authored gait library on
## 2026-10-01, so the first set waits on his look): Actor_B's textured body (assets/character/actor_b_body.glb on its own
## skeleton, skinned by CharacterBodyMesh as the game does, the helper bones driven: the bones the clips key are set from
## their tracks, nothing else is played) on a plain floor, each clip sampled
## at its moments (the start, the wind-up's hold_s, the strike's way in, strike_s, the follow-through, back_s, up_s, the end) and
## seen from the front three quarters and from the right side, a row each, labelled; one sheet a clip (clips_<name>.png) and a
## lineup of every clip at its hold and its strike (clips_lineup.png), and one an element (clips_lineup_<earth | water | fire |
## air | knock>.png: its stance, then each of its casts at its hold and its strike; the throws with earth's). A stance (a loop:
## meta loop) is sampled at eight even moments through its loop instead. Rendered through tools/environment/offscreen_view.gd
## (a covered macOS window is not drawn; the SubViewport is, when forced), so it needs a window (not --headless).
##   Godot --path . -s tools/anim_author/bend_preview.gd -- out=<dir> [clips=own-bend-earth-stomp,...] [lib=res://...]
##       [prefix=clips2_]   (the sheets' file names: <prefix><name>.png, <prefix>lineup.png, <prefix>lineup_<element>.png)
##       [frames=8]   exactly that many moments a sheet (the named moments first, the rest filled evenly)
##       [seam=1]     and for a loop <prefix><name>_seam.png: its first and its last frame side by side, front and side
##                    (a clip whose tail loops, meta loop_from_s: that loop's first frame and the clip's last)
##       [under=own-bend-air-palm]   a clip that keys only some bones (the air legs) shown over that clip at its strike
##       [suffix=_sheet]   appended to each clip sheet's name; [lineup=name] the lineup's file (<prefix><name>.png)
##       [loopcells=1]   how many even moments of a loop the lineups show (its start, then evenly through it)
##       [at=own-bend-rise-earth:13,22;...]   the lineup cells of a clip at those frames (instead of its hold and strike)
##       [rise=own-bend-edge-jump:11.8:19.9]   the code's jump (vy, gravity) added to that clip's root, as the game moves it
## An edge clip (meta lip_y: keyed in the hang's frame) is shown at a block of the deck (its lip lip_y over the origin and
## lip_out ahead, a pale coping on a stone face), framed round the lip (EDGE_VIEWS).

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const CELL := Vector2i(300, 400)
const GLB := "res://assets/character/actor_b_body.glb"
const CENTER := Vector3(0.0, 0.95, 0.15)
## Where a clip lying on the deck is framed (meta lying): low over the lying body's middle.
const LOW_CENTER := Vector3(0.0, 0.3, -0.15)
## How far the side view of a lying clip is centred toward the head (m, -Z), so the head and the hat stay in the frame.
const LYING_SIDE_SHIFT := -0.2
## A clip that starts on the deck and stands up (the getups: its first frame's head under this height, m) seen from the
## side further back and centred toward the head, so the lying start and the standing end both stay in the frame.
const LOW_START_Y := 0.5
const RISING_SIDE := Vector3(0.0, -0.2, -0.3)
const RISING_SIDE_BACK := 1.3
## The wall a clip names (meta wall_z: the wall break) drawn there: its size (m) and its see-through stone.
const WALL_SIZE := Vector3(1.6, 2.4, 0.06)
const WALL_COLOR := Color(0.5, 0.52, 0.58, 0.38)
## (the character faces +Z, +X its left)
const VIEWS := {"front34": Vector3(-2.3, 0.35, 3.0), "side": Vector3(-3.7, 0.15, 0.15)}
## An edge clip's views about the lip (the deck ahead of him, +Z): from the deck's front three quarters a little over it (what
## a foe on the deck sees: the hands and the head over the lip), and square from the side a little over the deck (the profile:
## the hands on the deck, the head over the lip, the feet on the face); a wider frame, the climbs ending a metre in.
const EDGE_VIEWS := {"front34": Vector3(-3.3, 1.25, 4.1), "side": Vector3(-5.6, 0.45, 0.0)}
## The deck's block an edge clip is shown at (its lip's nose at the node's origin: the deck ahead, +Z, its top at the origin's
## height), a pale stone coping along the lip over a darker stone face.
const LEDGE_W := 1.8
const LEDGE_D := 3.0
const LEDGE_H := 3.2

var out := ""
var lib_path := "res://animations_extra/Frontier_Bend.res"
var only: PackedStringArray = []
var prefix := "clips_"
var n_frames := 0
var seam := false
var under := ""
var suffix := ""
var lineup_name := "lineup"
var loop_cells := 1
## at=<clip>:<frame>,<frame>[;...]: the lineup cells of that clip at those frames (its signature moments) instead of its
## hold_s and strike_s (and a loop's even moments).
var lineup_at := {}
var _under_anim: Animation
var view
var label: Label
var sk: Skeleton3D
var _ledge: Node3D
var _wall: Node3D
## rise=<clip>:<vy>:<g>[;...]: the code's own lift added to that clip's root (the edge jump: the game's jump carries the
## body up while the clip plays), so the sheet shows what the game shows. Clip name -> (vy m/s, g m/s^2); by animation.
var _rise_args := {}
var _rise := {}
var _low_start := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.get_slice("=", 1)
		elif a.begins_with("clips="):
			only = a.get_slice("=", 1).split(",", false)
		elif a.begins_with("lib="):
			lib_path = a.get_slice("=", 1)
		elif a.begins_with("prefix="):
			prefix = a.get_slice("=", 1)
		elif a.begins_with("frames="):
			n_frames = int(a.get_slice("=", 1))
		elif a.begins_with("seam="):
			seam = a.get_slice("=", 1) == "1"
		elif a.begins_with("under="):
			under = a.get_slice("=", 1)
		elif a.begins_with("suffix="):
			suffix = a.get_slice("=", 1)
		elif a.begins_with("loopcells="):
			loop_cells = maxi(1, int(a.get_slice("=", 1)))
		elif a.begins_with("lineup="):
			lineup_name = a.get_slice("=", 1)
		elif a.begins_with("at="):
			for r in a.get_slice("=", 1).split(";", false):
				lineup_at[r.get_slice(":", 0)] = r.get_slice(":", 1).split(",", false)
		elif a.begins_with("rise="):
			for r in a.get_slice("=", 1).split(";", false):
				_rise_args[r.get_slice(":", 0)] = Vector2(float(r.get_slice(":", 1)), float(r.get_slice(":", 2)))
	_run.call_deferred()


func _run() -> void:
	if out == "":
		push_error("bend_preview: out=<dir>")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out)
	var lib := load(lib_path) as AnimationLibrary
	if under != "" and lib.has_animation(StringName(under)):
		_under_anim = lib.get_animation(StringName(under))
	for rn: String in _rise_args:
		if lib.has_animation(StringName(rn)):
			_rise[lib.get_animation(StringName(rn))] = _rise_args[rn]
	_stage()
	var body := (load(GLB) as PackedScene).instantiate() as Node3D
	root.add_child(body)
	sk = body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for ap: AnimationPlayer in body.find_children("*", "AnimationPlayer", true, false):
		ap.stop()
		ap.active = false
	# the body as the game skins it: CharacterBodyMesh drives the twist, sleeve and coat helper bones from the pose (the
	# glb's own meshes would leave the sleeves at the rest); with no AnimationPlayer it binds with the glb's own binds
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		mi.visible = false
	CharacterBodyMesh.attach(sk, null, GLB)
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, CELL)
	view.camera.fov = 36.0
	root.disable_3d = true
	label = Label.new()
	label.position = Vector2(8, 6)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.08, 0.08, 0.1))
	view.add_child(label)
	await process_frame
	await process_frame
	var lineup: Array[Image] = []
	var by_el := {}
	var names := lib.get_animation_list()
	# (each element's stance first in its lineup)
	names.sort_custom(func(x: StringName, y: StringName) -> bool:
		var sx := String(x).contains("-stance-")
		var sy := String(y).contains("-stance-")
		return sx and not sy if sx != sy else String(x) < String(y))
	for nm: StringName in names:
		if not only.is_empty() and not String(nm) in only:
			continue
		var a := lib.get_animation(nm)
		var times := _moments(a)
		var cells: Array[Image] = []
		for vn: String in VIEWS:
			for tm: Array in times:
				cells.append(await _snap(a, float(tm[0]), vn, "%s\n%s %.2f s (f%d)" % [String(nm).trim_prefix("own-bend-"), tm[1],
						float(tm[0]), int(round(float(tm[0]) * 30.0))]))
		_sheet(cells, times.size(), out.path_join("%s%s%s.png" % [prefix, String(nm).trim_prefix("own-bend-"), suffix]))
		# (a clip whose tail loops (meta loop_from_s: the air Rise's glide) shows that loop's first frame and its last)
		if seam and (a.has_meta(&"loop") or a.has_meta(&"loop_from_s")):
			var sc: Array[Image] = []
			var t0 := float(a.get_meta(&"loop_from_s", 0.0))
			for vn: String in VIEWS:
				for tm: Array in [[t0, "loop's first"], [a.length, "last"]]:
					sc.append(await _snap(a, float(tm[0]), vn, "%s seam\n%s frame %.2f s (f%d)" % [String(nm).trim_prefix(
							"own-bend-"), tm[1], float(tm[0]), int(round(float(tm[0]) * 30.0))]))
			_sheet(sc, 2, out.path_join("%s%s_seam.png" % [prefix, String(nm).trim_prefix("own-bend-")]))
		var el := _element(String(nm))
		if not by_el.has(el):
			by_el[el] = [] as Array[Image]
		if lineup_at.has(String(nm)):
			for fr: String in lineup_at[String(nm)]:
				var im3 := await _snap(a, int(fr) / 30.0, "front34", "%s\nf%s" % [String(nm).trim_prefix("own-bend-"), fr])
				lineup.append(im3)
				(by_el[el] as Array[Image]).append(im3)
			continue
		if a.has_meta(&"loop"):
			for li in loop_cells:
				var im := await _snap(a, a.length * li / loop_cells, "front34", "%s\nloop %d/%d" % [String(nm).trim_prefix(
						"own-bend-"), li, loop_cells])
				lineup.append(im)
				(by_el[el] as Array[Image]).append(im)
		for key in ["hold_s", "strike_s"]:
			if a.has_meta(key):
				var im2 := await _snap(a, float(a.get_meta(key)), "front34", "%s\n%s" % [String(nm).trim_prefix("own-bend-"), key])
				lineup.append(im2)
				(by_el[el] as Array[Image]).append(im2)
	_sheet(lineup, 8, out.path_join("%s%s.png" % [prefix, lineup_name]))
	for el: String in by_el:
		_sheet(by_el[el], 7, out.path_join("%slineup_%s.png" % [prefix, el]))
	print("BEND PREVIEW -> ", out)
	quit()


## The element a clip's lineup is: own-bend-<earth | water | fire | air | knock>-..., a stance's own, the throws earth's.
func _element(nm: String) -> String:
	var rest := nm.trim_prefix("own-bend-").trim_prefix("stance-")
	var head := rest.get_slice("-", 0)
	return "earth" if head == "throw" else head


## The clip's moments: [time, what], in order, without near repeats (a stance: eight even moments through its loop).
func _moments(a: Animation) -> Array:
	if a.has_meta(&"loop"):
		var loop := []
		for i in 8:
			loop.append([a.length * i / 8.0, "loop %d/8" % i])
		return loop
	var named := _on_frames(_named_moments(a))
	if n_frames <= 0:
		return named
	# exactly n_frames: the least telling named moments dropped first, then fills on whole frames, each the frame farthest
	# from every moment already shown (so no two columns show the same frame and every label is its real frame)
	var drop := ["wind 47%", "wind 63%", "wind 79%", "hit+", "way in", "recover", "follow"]
	while named.size() > n_frames and not drop.is_empty():
		var k: String = drop.pop_front()
		named = named.filter(func(e: Array) -> bool: return String(e[1]) != k)
	var last := int(round(a.length * 30.0))
	while named.size() < n_frames:
		var best := -1
		var gap := 0
		for fr in last + 1:
			var g := 1 << 20
			for e: Array in named:
				g = mini(g, absi(fr - int(round(float(e[0]) * 30.0))))
			if g > gap:
				gap = g
				best = fr
		if best < 0:
			break
		named.append([best / 30.0, "f%d" % best])
	named.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	return named


## Moments put on whole frames (a sheet shows the frames the game plays), the later of two on one frame dropped.
func _on_frames(arr: Array) -> Array:
	var res := []
	var seen := {}
	for e: Array in arr:
		var fr := int(round(float(e[0]) * 30.0))
		if seen.has(fr):
			continue
		seen[fr] = true
		res.append([fr / 30.0, e[1]])
	return res


## The clip's own named moments (start, hold, strike, ...).
func _named_moments(a: Animation) -> Array:
	var m := {"start": 0.0, "end": a.length}
	for k in ["hold_s", "strike_s", "back_s", "up_s"]:
		if a.has_meta(k):
			m[k.trim_suffix("_s")] = float(a.get_meta(k))
	if a.has_meta("strike_s") and a.has_meta("hold_s") and float(a.get_meta("strike_s")) > float(a.get_meta("hold_s")):
		m["way in"] = (float(a.get_meta("hold_s")) + float(a.get_meta("strike_s"))) * 0.5
	if a.has_meta("strike_s"):
		var s := float(a.get_meta("strike_s"))
		var nxt := float(a.get_meta("back_s", a.length))
		if float(a.get_meta("hold_s", 0.0)) > s:
			m["hit+"] = s + (float(a.get_meta("hold_s")) - s) * 0.5
		m["follow"] = s + (nxt - s) * 0.4
	if a.has_meta("back_s"):
		m["recover"] = (float(a.get_meta("back_s")) + a.length) * 0.5
	# a long wind-up (the boulder's kick and stomp, the lightning's circles) shown on its way to the hold
	var h := float(a.get_meta("hold_s", 0.0))
	if h >= 0.4 and float(a.get_meta("strike_s", 0.0)) > h:
		for k: float in [0.47, 0.63, 0.79]:
			m["wind %d%%" % int(k * 100.0)] = h * k
	var arr := []
	for k: String in m:
		arr.append([float(m[k]), k])
	arr.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var res := []
	for e: Array in arr:
		if res.is_empty() or float(e[0]) - float(res[-1][0]) > 0.02:
			res.append(e)
	return res


func _apply(a: Animation, t: float) -> void:
	# (every bone back to the rest first, so a clip that keys only some bones never shows the last clip's pose; such a clip
	# is shown over `under` at its strike when that is given)
	sk.reset_bone_poses()
	if _under_anim != null and a != _under_anim and not _keys_root(a):
		_set_clip(_under_anim, float(_under_anim.get_meta(&"strike_s", 0.0)))
	_set_clip(a, t)
	if _rise.has(a):
		var r: Vector2 = _rise[a]
		var rb := sk.find_bone("root")
		sk.set_bone_pose_position(rb, sk.get_bone_pose_position(rb) + Vector3.UP * (r.x * t - 0.5 * r.y * t * t))
	sk.force_update_all_bone_transforms()


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


## Whether a clip starts lying on the deck (its first frame's head under LOW_START_Y), cached per clip.
func _starts_low(a: Animation) -> bool:
	if not _low_start.has(a):
		_apply(a, 0.0)
		var hb := sk.find_bone("heada")
		_low_start[a] = hb >= 0 and sk.get_bone_global_pose(hb).origin.y < LOW_START_Y
	return bool(_low_start[a])


func _snap(a: Animation, t: float, vn: String, text: String) -> Image:
	var rising := vn == "side" and not a.has_meta(&"lip_y") and not a.has_meta(&"lying") and _starts_low(a)
	_apply(a, t)
	label.text = text
	# (an edge clip, keyed in the hang's frame with its lip at meta lip_y over the origin and lip_out ahead: seen round the
	# lip, the deck's block shown; every other clip on the floor as before)
	var c := CENTER
	var off: Vector3 = VIEWS[vn]
	_ledge.visible = a.has_meta(&"lip_y")
	if _ledge.visible:
		_ledge.position = Vector3(0.0, float(a.get_meta(&"lip_y")), float(a.get_meta(&"lip_out", 0.35)))
		c = Vector3(0.0, float(a.get_meta(&"lip_y")) + 0.1, float(a.get_meta(&"lip_out", 0.35)) + 0.3)
		off = EDGE_VIEWS[vn]
	elif a.has_meta(&"lying"):
		# (a figure lying on the deck its whole length (meta lying: the lie, the bounce): framed low round its middle, nearer;
		# the side view a little further back and toward the head, so the head and the hat are not cut off)
		c = LOW_CENTER
		off = VIEWS[vn] * 0.8 + Vector3(0.0, 0.25, 0.0)
		if vn == "side":
			c = LOW_CENTER + Vector3(0.0, 0.0, LYING_SIDE_SHIFT)
			off = VIEWS[vn] + Vector3(0.0, 0.25, 0.0)
	elif rising:
		# (a getup: from the side a little further back and toward the head, the lying start and the stand both in frame)
		c = CENTER + RISING_SIDE
		off = VIEWS[vn] * RISING_SIDE_BACK
	# (a clip that names a wall ahead, meta wall_z: the wall drawn there, a see-through pane so the figure on it shows)
	_wall.visible = a.has_meta(&"wall_z")
	if _wall.visible:
		_wall.position = Vector3(0.0, 0.0, float(a.get_meta(&"wall_z")))
	if _rise.has(a):
		# (the code's lift carries the body high: the frame follows it up once it is past the lip, the lip kept in view)
		var rr: Vector2 = _rise[a]
		c.y += maxf(0.0, (rr.x * t - 0.5 * rr.y * t * t) - 0.8) * 0.8
	view.camera.global_position = c + off
	view.camera.look_at(c)
	for f in 3:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	return (view.get_texture().get_image() as Image)


func _sheet(cells: Array[Image], cols: int, path: String) -> void:
	if cells.is_empty():
		return
	cols = maxi(1, mini(cols, cells.size()))
	var rows := int(ceil(cells.size() / float(cols)))
	var sheet := Image.create(CELL.x * cols, CELL.y * rows, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.3, 0.3, 0.3))
	for i in cells.size():
		var im := cells[i]
		im.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(im, Rect2i(Vector2i.ZERO, CELL), Vector2i((i % cols) * CELL.x, (i / cols) * CELL.y))
		# a thin line between the cells
		sheet.fill_rect(Rect2i((i % cols) * CELL.x, (i / cols) * CELL.y, 1, CELL.y), Color(0.2, 0.2, 0.22))
	sheet.save_png(path)
	print("BEND SHEET -> ", path)


## A plain lit floor with a sky colour (no level: the clips alone), a stone grid on the floor to read the feet's slide.
func _stage() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.72, 0.76, 0.8)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.78, 0.78, 0.8)
	e.ambient_light_energy = 0.75
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	root.add_child(sun)
	_ledge = Node3D.new()
	_ledge.visible = false
	root.add_child(_ledge)
	for part: Array in [[Vector3(LEDGE_W, LEDGE_H, LEDGE_D), Vector3(0.0, -LEDGE_H * 0.5, LEDGE_D * 0.5), Color(0.42, 0.4, 0.38)],
			[Vector3(LEDGE_W, 0.1, 0.29), Vector3(0.0, -0.05, 0.105), Color(0.8, 0.77, 0.7)]]:
		var bm := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = part[0]
		bm.mesh = bx
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = part[2]
		bmat.roughness = 0.9
		bm.material_override = bmat
		bm.position = part[1]
		_ledge.add_child(bm)
	# (the wall a clip names: its near face at the node's origin, its foot on the floor; an edge line drawn opaque)
	_wall = Node3D.new()
	_wall.visible = false
	root.add_child(_wall)
	var wm := MeshInstance3D.new()
	var wb := BoxMesh.new()
	wb.size = WALL_SIZE
	wm.mesh = wb
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = WALL_COLOR
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	wmat.roughness = 0.9
	wm.material_override = wmat
	wm.position = Vector3(0.0, WALL_SIZE.y * 0.5, WALL_SIZE.z * 0.5)
	_wall.add_child(wm)
	for edge: Vector3 in [Vector3(-WALL_SIZE.x * 0.5, WALL_SIZE.y * 0.5, 0.0), Vector3(WALL_SIZE.x * 0.5, WALL_SIZE.y * 0.5, 0.0)]:
		var em := MeshInstance3D.new()
		var eb := BoxMesh.new()
		eb.size = Vector3(0.025, WALL_SIZE.y, 0.025)
		em.mesh = eb
		var emat := StandardMaterial3D.new()
		emat.albedo_color = Color(0.25, 0.27, 0.32)
		em.material_override = emat
		em.position = edge
		_wall.add_child(em)
	for ix in range(-4, 4):
		for iz in range(-4, 4):
			var m := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.49, 0.04, 0.49)
			m.mesh = b
			var mat := StandardMaterial3D.new()
			var k := 0.5 + 0.06 * float((ix + iz) & 1)
			mat.albedo_color = Color(k, k * 0.97, k * 0.9)
			mat.roughness = 0.95
			m.material_override = mat
			m.position = Vector3(ix * 0.5 + 0.25, -0.02, iz * 0.5 + 0.25)
			root.add_child(m)
