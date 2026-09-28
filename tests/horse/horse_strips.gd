extends SceneTree
## Side-view strips of the horse with the Actor_B rider, one row per clip. Needs a window
## (not --headless); wrap it in a time limit, a script error leaves the window open.
##
##   Godot --path . --resolution 1100x620 -s tests/horse/horse_strips.gd -- out=/tmp/horse_strips \
##       [clips=walk,trot,...] [frames=8] [view=side|34|front|rear|rear34|hq|closeup|closeup34] [rider=1]
##       [stick=1] [phases=0.1,0.35,...] [hind=1] [fore=1] [tag=name] [clay=1] [tack=0]
##
## Skeleton close-ups (view=shoulder34 | shoulder | quarters | back | fore_close | hind_close): the
## shoulder-to-foreleg junction from the front left and from the side, the hip / stifle / gaskin
## from the side, the back line (withers to croup) from a little above, and tight views of the
## shoulder, arm and elbow (from the front left) and of the hip, stifle and hock (from behind). clay=1 draws the skin in plain grey
## (creases and volume show without the coat), tack=0 hides the saddle, cloth, girth and irons.
## fore=1 is hind=1 for the left fore leg.
##
## hind=1: per clip the left hind's touchdown, mid-stance, lift-off and mid-swing (from the
## footfalls in horse_meta.json) instead of evenly spaced phases. view=rear34 looks at the
## quarters from behind on the left, view=hq at the hindquarters from the side.
##
## For each clip: `frames` evenly spaced phases (one loop of a cycle, the whole one-shot) or
## the given phases, rendered from a fixed camera, each labelled with clip, phase and the
## footfalls (the hooves on the ground). The closeup views frame the rider
## on the saddle. stick=1 adds a measuring stick at the withers (1.42 / 1.47 m marks =
## 14 / 14.2 hands). Saves <out>/strip_<clip>[_tag].png and <out>/strips[_tag].png.

const Rig := preload("res://tests/horse/horse_test_rig.gd")
const DEFAULT_CLIPS := ["idle", "walk", "trot", "canter", "gallop", "sprint", "turn_l", "jump", "rear"]
const CELL := Vector2i(420, 360)

var args := {}
var r
var label: Label
var cam: Camera3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	var out: String = args.get("out", "user://horse_strips")
	DirAccess.make_dir_recursive_absolute(out)
	r = Rig.new()
	await r.build(self, args.get("rider", "1") == "1", true)
	if args.get("rider", "1") != "1":
		# a hidden rider lets go of the reins (they fall to the pommel)
		r.rider.visible = false
		r.link.drive_reins = false
		r.horse.set_rein_targets([])
	if args.get("stick", "0") == "1":
		_stick()
	if args.get("clay", "0") == "1" or args.get("tack", "1") == "0":
		_look_options()
	cam = Camera3D.new()
	cam.fov = 38.0
	r.world.add_child(cam)
	cam.current = true
	var layer := CanvasLayer.new()
	root.add_child(layer)
	label = Label.new()
	var vs := root.get_viewport().get_visible_rect().size
	label.position = Vector2((vs.x - minf(vs.x, vs.y * 1.2)) * 0.5 + 12.0, 8.0)
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 6)
	layer.add_child(label)
	var clips: Array = DEFAULT_CLIPS
	if args.has("clips"):
		clips = String(args.clips).split(",")
	var nframes := int(args.get("frames", "8"))
	var rows: Array[Image] = []
	for c: String in clips:
		var info: Dictionary = r.horse.meta.clips.get(c, {})
		var loops: bool = info.get("loop", false)
		var n := nframes + (2 if not loops else 0)
		var imgs: Array[Image] = []
		var phs: Array = []
		var hf := "LH" if args.get("hind", "0") == "1" else ("LF" if args.get("fore", "0") == "1" else "")
		if not hf.is_empty() and info.has("touchdown_phase"):
			var ns := float(info.get("strides", 1))
			var td := float(info.touchdown_phase[hf])
			var du := float(info.duty[1 if hf == "LH" else 0])
			for x in [td, td + 0.5 * du, td + du - 0.01, td + du + 0.5 * (1.0 - du)]:
				phs.append(fposmod(x / ns, 1.0))
		elif args.has("phases"):
			for x in String(args.phases).split(","):
				phs.append(float(x))
		else:
			for j in n:
				phs.append(float(j) / float(n) if loops else float(j) / float(n - 1))
		for ph: float in phs:
			r.pose(c, ph)
			_place_camera(c)
			label.text = "%s  %.2f  (%.2f s)\n%s" % [c, ph, ph * float(info.get("length", 1.0)), _footfalls()]
			await _frames(3)
			await RenderingServer.frame_post_draw
			var img := root.get_viewport().get_texture().get_image()
			imgs.append(_crop(img))
		var strip := _hstack(imgs)
		var tag: String = ("_" + String(args.tag)) if args.has("tag") else ""
		strip.save_png("%s/strip_%s%s.png" % [out, c, tag])
		print("saved %s/strip_%s%s.png" % [out, c, tag])
		rows.append(strip)
	var w := 0
	var h := 0
	for im in rows:
		w = maxi(w, im.get_width())
		h += im.get_height()
	var sheet := Image.create(w, h, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.1, 0.1, 0.1))
	var y := 0
	for im in rows:
		sheet.blit_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(0, y))
		y += im.get_height()
	var tag2: String = ("_" + String(args.tag)) if args.has("tag") else ""
	sheet.save_png("%s/strips%s.png" % [out, tag2])
	print("HORSE STRIPS DONE %s/strips%s.png" % [out, tag2])
	quit(0)


## Hooves on the ground now (toe within 1.5 cm of the ground), e.g. "down: LF RH".
func _footfalls() -> String:
	var h: Horse = r.horse
	var sk := h.skeleton
	var tt: Dictionary = h.meta.get("sockets", {}).get("hoof_toes", {})
	var on := {}
	for leg in tt:
		var b := sk.find_bone(String(tt[leg][0]))
		var a: Array = tt[leg][1]
		var p := sk.global_transform * (sk.get_bone_global_pose(b) * (sk.get_bone_global_rest(b).affine_inverse() * Vector3(a[0], a[1], a[2])))
		on[leg] = p.y - h.global_position.y < 0.015
	var down := []
	for leg in ["LF", "RF", "LH", "RH"]:
		if on.get(leg, false):
			down.append(leg)
	return "down: " + (" ".join(down) if not down.is_empty() else "none (suspension)")


## A measuring stick beside the horse's withers: 1.5 m tall, dark bands every 0.1 m and
## light marks at 1.42 m and 1.47 m (14 and 14.2 hands).
func _stick() -> void:
	# at the withers, just outside the horse's left side (towards the side camera)
	var at := Vector3(-0.45, 0.0, -0.5)
	var mk := func(h0: float, h1: float, col: Color, rad: float) -> void:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = rad
		cm.bottom_radius = rad
		cm.height = h1 - h0
		mi.mesh = cm
		mi.position = at + Vector3(0, (h0 + h1) * 0.5, 0)
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = m
		r.world.add_child(mi)
	for i in 15:
		mk.call(i * 0.1, (i + 1) * 0.1, Color(0.15, 0.15, 0.15) if i % 2 == 0 else Color(0.9, 0.9, 0.85), 0.012)
	for hh in [1.422, 1.473]:
		mk.call(hh - 0.004, hh + 0.004, Color(1.0, 0.2, 0.1), 0.05)


func _place_camera(c: String) -> void:
	# the horse faces -z (world); its left side faces -x
	var view: String = args.get("view", "side")
	var center := Vector3(0, 1.05, -0.35)
	if c == "rear":
		center = Vector3(0, 1.35, -0.1)
	elif c == "jump":
		center = Vector3(0, 1.3, -0.35)
	var off := Vector3(-4.3, 0.2, 0.0)
	if view == "34":
		off = Vector3(-3.3, 0.9, -2.8)
	elif view == "front":
		off = Vector3(0.0, 0.35, -4.3)
	elif view == "rear":
		off = Vector3(0.0, 0.5, 4.3)
	elif view == "rear34":
		center = Vector3(0, 0.85, 0.35)
		off = Vector3(-2.3, 0.55, 2.7)
	elif view == "hq":
		center = Vector3(0, 0.85, 0.3)
		off = Vector3(-3.0, 0.15, 0.0)
	elif view == "shoulder34":
		center = Vector3(0, 0.95, -0.55)
		off = Vector3(-1.9, 0.3, -1.45)
	elif view == "shoulder":
		center = Vector3(0, 0.9, -0.5)
		off = Vector3(-2.6, 0.1, 0.0)
	elif view == "quarters":
		center = Vector3(0, 0.9, 0.42)
		off = Vector3(-2.6, 0.12, 0.05)
	elif view == "fore_close":
		center = Vector3(0, 0.95, -0.5)
		off = Vector3(-1.6, 0.05, -0.4)
	elif view == "hind_close":
		center = Vector3(0, 0.85, 0.38)
		off = Vector3(-1.6, 0.1, 0.4)
	elif view == "back":
		center = Vector3(0, 1.1, -0.05)
		off = Vector3(-3.4, 1.2, 0.0)
	elif view == "closeup" or view == "closeup34":
		# the rider on the saddle: from the left, or from the front left
		var sad: Transform3D = r.horse.get_saddle_transform()
		center = sad.origin + sad.basis * Vector3(0.0, -0.05, 0.15)
		off = Vector3(-2.6, 0.1, 0.0) if view == "closeup" else Vector3(-1.9, 0.45, -1.75)
	cam.global_position = center + off
	cam.look_at(center)


## clay=1: the skin in plain grey; tack=0: saddle, cloth, girth, leathers and irons hidden.
func _look_options() -> void:
	var clay := StandardMaterial3D.new()
	clay.albedo_color = Color(0.62, 0.6, 0.57)
	clay.roughness = 0.75
	for mi: MeshInstance3D in r.horse.visual.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name)
		if args.get("clay", "0") == "1" and n == "HorseBody":
			mi.material_override = clay
		if args.get("tack", "1") == "0" and (n in ["Saddle", "SaddleCloth", "Girth"] or n.begins_with("Stirrup")):
			mi.visible = false


func _crop(img: Image) -> Image:
	img.convert(Image.FORMAT_RGB8)
	var s := img.get_size()
	var side := mini(s.x, int(s.y * 1.2))
	var rect := Rect2i((s.x - side) / 2, 0, side, s.y)
	var c := img.get_region(rect)
	c.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
	return c


func _hstack(imgs: Array[Image]) -> Image:
	var out := Image.create(CELL.x * imgs.size(), CELL.y, false, Image.FORMAT_RGB8)
	for i in imgs.size():
		out.blit_rect(imgs[i], Rect2i(Vector2i.ZERO, CELL), Vector2i(i * CELL.x, 0))
	return out


func _frames(n: int) -> void:
	for i in n:
		await process_frame
