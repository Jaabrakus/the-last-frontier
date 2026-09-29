extends SceneTree
## Close-ups of the baby's face, windowed, on a plain backdrop in soft light: two children of different parents (a fair and a darker
## one), each from the front, three-quarter and the side, awake (idle_breathe), asleep and crying (faces_babies.png); and the skin as
## the game's adult skin next to the baby's soft one (faces_skin.png).
##   Godot --path . --resolution 1280x720 -s tests/companion/baby_faces.gd -- out=<abs dir> [only=babies,skin] [close=1]
var out := ""
var only: PackedStringArray = []
var close := false
var cam: Camera3D

const W := 400
const H := 440


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.get_slice("=", 1)
		elif a == "close=1":
			close = true
		elif a.begins_with("only="):
			only = a.get_slice("=", 1).split(",")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _snap() -> Image:
	await _frames(4)
	var img := root.get_viewport().get_texture().get_image()
	var vs := img.get_size()
	var cw := int(float(vs.y) * float(W) / float(H))          # (a centred crop of the picture's aspect: no stretching)
	img = img.get_region(Rect2i((vs.x - cw) / 2, 0, cw, vs.y))
	img.resize(W, H, Image.INTERPOLATE_LANCZOS)
	return img


## One baby in `anim` at `t`, its head up and its face toward +z, photographed from `view` (0 front, 1 three-quarter, 2 side). The
## baby of a look is made once and posed again for each view.
var _babies := {}


func _face(look: Dictionary, anim: String, t: float, view: int) -> Image:
	var key := hash([look, BabyBody.soften])
	var b: BabyModel = _babies.get(key)
	if b == null:
		for o: BabyModel in _babies.values():
			o.visible = false
		b = BabyModel.create({"id": "c", "name": "x", "sex": float(look.get("sex", 0.0)), "seed": 3}, [0.3, 0.3], 1.0, look)
		root.add_child(b)
		b.set_process(false)
		_babies[key] = b
	for o: BabyModel in _babies.values():
		o.visible = o == b
	b.play(anim, 0.0)
	b._anim.play("baby/" + anim)
	b._anim.seek(t, true)
	b._anim.pause()
	b.basis = Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0))     # head up (the baby frame's x), face to +z
	b.position = Vector3(0, 0.5, 0)
	b._cry = 0.9
	b._t = t
	b._face()
	b._bb.set_process(false)             # (no random blink in a shot)
	b._bb.set_blink(b._eyes_v)
	await _frames(3)
	var sk := b._bb.sk
	var at := sk.global_transform * b._bb.props.posed_global("headb").origin
	if close:
		# the middle of the face (the adult's nose root, where this face has it), posed
		var pr := b._bb.props
		at = sk.global_transform * pr.posed_global("headb") * pr.bind_global("headb").affine_inverse() * pr.map_face("headb", Vector3(0.0, 1.45, 0.07))
	var dirs := [Vector3(0, 0.08, 1), Vector3(0.72, 0.1, 0.68), Vector3(1, 0.06, 0.02)]
	var hb := b._bb.props.head_basis()                  # the views are the head's own (the clip turns and tilts it)
	cam.global_position = at + hb * (dirs[view] as Vector3).normalized() * (0.3 if close else 0.48)
	cam.look_at(at - hb.y * (0.0 if close else 0.012), hb.y)
	return await _snap()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.58, 0.6)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.72, 0.76)
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	root.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 30, 0)
	key.light_energy = 1.3
	key.light_color = Color(1.0, 0.96, 0.9)
	root.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, 200, 0)
	rim.light_energy = 0.5
	root.add_child(rim)
	cam = Camera3D.new()
	cam.fov = 26.0
	root.add_child(cam)
	cam.current = true
	# two children: a fair and a darker one, from different parents
	var m1 := AppearanceStore.default_look()
	m1["sex"] = 0.0
	var f1 := AppearanceStore.default_look()
	f1["sex"] = 1.0
	var m2 := CharacterPeoples.preset_look("japanese_f_a") if not CharacterPeoples.preset("japanese_f_a").is_empty() else m1
	var f2 := CharacterPeoples.preset_look("west_african_m_a") if not CharacterPeoples.preset("west_african_m_a").is_empty() else f1
	var looks := [ChildLook.from_parents(m1, f1, 0.0, 11), ChildLook.from_parents(m2, f2, 1.0, 5)]
	if not only.is_empty() and not "babies" in only:
		pass
	else:
		var sheet := Image.create(W * 5, H * 2, false, Image.FORMAT_RGB8)
		for row in 2:
			var specs := [["idle_breathe", 0.5, 0], ["idle_breathe", 0.5, 1], ["idle_breathe", 0.5, 2], ["sleep", 1.0, 0], ["cry", 0.4, 0]]
			for col in specs.size():
				var sp: Array = specs[col]
				sheet.blit_rect(await _face(looks[row], sp[0], sp[1], sp[2]), Rect2i(0, 0, W, H), Vector2i(W * col, H * row))
		sheet.save_png(out.path_join("faces_babies.png"))
		print("saved babies")
	if only.is_empty() or "skin" in only:
		var sk := Image.create(W * 4, H, false, Image.FORMAT_RGB8)
		var c := 0
		for soft: bool in [false, true]:
			BabyBody.soften = soft
			for li in 2:
				sk.blit_rect(await _face(looks[li], "idle_breathe", 0.5, 1), Rect2i(0, 0, W, H), Vector2i(W * c, 0))
				c += 1
		BabyBody.soften = true
		sk.save_png(out.path_join("faces_skin.png"))
		print("saved skin")
	print("BABY FACES DONE ", out)
	quit()
