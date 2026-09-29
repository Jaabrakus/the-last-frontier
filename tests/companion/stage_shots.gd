extends SceneTree
## Look-check of every life stage's body and face, windowed, on a plain backdrop (no level): the mother holding the baby (cradle),
## a toddler, a child, a teen and the father (the player's look), side by side from the front and the side (lineup_front.png,
## lineup_side.png); face close-ups of each stage (faces_front.png, faces_side.png); the round-face gauge -1..1 on a toddler and a baby
## (round_strip.png); the bodies' flatness at the chest and hips, front and side, without clothes on the skin (flat_check.png); the
## baby in every hold, the mother's cradle and feeding holds, the father's shoulder hold and cradle on his right arm, and asleep in the
## cradle (holds.png, holds_close.png).
## All the children are the same child (one seed) of the same parents. Heights and head ratios are printed.
##   Godot --path . --resolution 1280x720 -s tests/companion/stage_shots.gd -- out=<abs dir> [only=lineup,faces,round,flat] [seed=5]
var out := ""
var only: PackedStringArray = []
var seed_v := 5
var cam: Camera3D
var sun: DirectionalLight3D

const IDLE := "actor_b/actor_b-p-relax-idle"
const STAGES := ["toddler", "child", "teen"]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.get_slice("=", 1)
		elif a.begins_with("only="):
			only = a.get_slice("=", 1).split(",")
		elif a.begins_with("seed="):
			seed_v = int(a.get_slice("=", 1))
	_run.call_deferred()


func _want(k: String) -> bool:
	return only.is_empty() or k in only


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _snap() -> Image:
	await _frames(3)
	await _frames(2)
	return root.get_viewport().get_texture().get_image()


func _scene() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.6, 0.64, 0.68)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.78, 0.78, 0.8)
	e.ambient_light_energy = 0.65
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	root.add_child(env)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	root.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 150, 0)
	fill.light_energy = 0.35
	root.add_child(fill)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.46, 0.44, 0.4)
	floor_mi.material_override = fm
	root.add_child(floor_mi)
	cam = Camera3D.new()
	root.add_child(cam)
	cam.current = true


## A figure: Actor_B at `stage` from `look` (the adult's own look for "adult"), idling (the pose held), at `pos` facing +z.
func _figure(look: Dictionary, sex: float, stage: String, pos: Vector3, bare := false) -> Dictionary:
	var ps := load("res://characters/Actor_B.tscn") as PackedScene
	var m := ps.instantiate() as Node3D
	m.position = pos
	m.scale = Vector3.ONE * float(Growth.stage_row(stage).get("scale", 1.0))
	root.add_child(m)
	var sk := m.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := m.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var lk := look.duplicate(true)
	if bare:
		lk["outfit"] = {"shirt": {"id": "-"}, "legs.lower": {"id": "-"}}
	var body: CharacterBodyMesh
	if stage == "adult":
		body = CharacterBodyMesh.attach_parts(sk, ap, {"head": BodyMaterials.BODY_GLB})
		PlayerAppearance.dress(body, AppearanceStore.validate(lk))
	else:
		body = ChildBody.dress_body(sk, ap, lk, sex, stage)
	var s := float(Growth.stage_row(stage).get("scale", 1.0))
	m.scale = Vector3.ONE * s
	if ap.has_animation(IDLE):
		ap.play(IDLE)
		ap.seek(0.6, true)
		ap.pause()
	var p := ChildProportion.of(body)
	return {"node": m, "sk": sk, "body": body, "scale": s, "prop": p, "stage": stage, "ap": ap}


## Crown, chin and sole heights of a figure (metres: the baked meshes' bind shape x the scale; the chin the most forward point of the
## face's midline below the lips, less a centimetre of the adult's), and the height over the head's height.
func _measure(f: Dictionary) -> Dictionary:
	var body: CharacterBodyMesh = f.body
	var lo := INF
	var top := -INF
	var p: ChildProportion = f.prop
	var lip := p.map_point("headb", Vector3(0, p.lip_y if p.lip_y > 0.0 else 1.411, 0.12)).y if p != null else 1.411
	var cz := -INF
	var chin := 0.0
	var hs := (p._a[p.get_parent().find_bone("headb")] as Basis).y.y if p != null else 1.0
	for mi: MeshInstance3D in body.part_meshes("head"):
		var am := mi.mesh as ArrayMesh
		for s in am.get_surface_count():
			var mat := am.surface_get_material(s)
			if mat == null or mat.resource_name != "skin":
				continue
			for q: Vector3 in am.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				lo = minf(lo, q.y)
				top = maxf(top, q.y)
				if absf(q.x) < 0.004 and q.y < lip - 0.01 * hs and q.y > lip - 0.09 * hs and q.z > cz:
					cz = q.z
					chin = q.y
	var s: float = f.scale
	var head := (top - (chin - 0.01 * hs)) * s
	return {"height": (top - lo) * s, "crown": top * s, "head": head, "ratio": (top - lo) * s / maxf(head, 0.001)}


func _view(at: Vector3, from: Vector3, fov := 30.0) -> void:
	cam.fov = fov
	cam.global_position = from
	cam.look_at(at, Vector3.UP)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	_scene()
	var mother := CharacterPeoples.preset_look("english_f_a") if not CharacterPeoples.preset("english_f_a").is_empty() else AppearanceStore.default_look()
	mother["sex"] = 0.0
	var father := AppearanceStore.default_look()
	father["sex"] = 1.0
	var girl := {"id": "c", "sex": 0.0, "seed": seed_v}
	var look := Growth.mix_look(girl, mother, father)
	var neutral := ChildLook.body_for_stage(look, "child")
	if _want("lineup"):
		await _lineup(mother, father, look, neutral)
	if _want("faces"):
		await _faces(mother, look, neutral)
	if _want("round"):
		await _round_strip(look, neutral)
	if _want("flat"):
		await _flat(neutral)
	if _want("holds"):
		await _holds(mother, father, look)
	print("STAGE SHOTS DONE ", out)
	quit()


func _clear(figs: Array) -> void:
	for f: Dictionary in figs:
		(f.node as Node).queue_free()


func _lineup(mother: Dictionary, father: Dictionary, look: Dictionary, neutral: Dictionary) -> void:
	var figs := []
	var mom := _figure(mother, 0.0, "adult", Vector3(-1.5, 0, 0))
	figs.append(mom)
	# the baby in her arms (the cradle hold)
	var hold := BabyHold.attach(mom.sk)
	hold.alive_motion = false
	hold.engage("cradle", 1.0, true)
	var baby := BabyModel.create({"id": "c", "name": "Ada", "sex": 0.0, "seed": seed_v}, [0.3, 0.3], 1.0, look)
	hold.hold.add_child(baby)
	baby.set_state("content", 0.0, false, false)
	var xs := [-0.55, 0.15, 0.95]
	for i in STAGES.size():
		var st: String = STAGES[i]
		figs.append(_figure(neutral if st != "teen" else look, 0.0, st, Vector3(xs[i], 0, 0)))
	figs.append(_figure(father, 1.0, "adult", Vector3(1.85, 0, 0)))
	await _frames(10)
	if baby._bb != null:
		var bm := _measure({"body": baby._bb.body, "prop": baby._bb.props, "scale": float(BabyBody.cfg().get("scale", 0.3))})
		print("baby     length %.3f m  head %.3f m  lengths/head %.2f  (a newborn: about 0.48-0.50, 0.115-0.12, 4)" % [bm.height, bm.head, bm.ratio])
	for f: Dictionary in figs:
		var mm := _measure(f)
		var p: ChildProportion = f.prop
		print("%-8s height %.3f m  head %.3f m  heights/head %.2f  leg share %.2f" % [f.stage, mm.height, mm.head, mm.ratio, p.leg_scale() if p != null else 1.0])
	_view(Vector3(0.15, 0.85, 0), Vector3(0.15, 1.0, 6.2), 30.0)
	var a := await _snap()
	a.save_png(out.path_join("lineup_front.png"))
	for f: Dictionary in figs:
		(f.node as Node3D).rotation_degrees.y = -90.0
	await _frames(4)
	var b := await _snap()
	b.save_png(out.path_join("lineup_side.png"))
	print("saved lineup")
	_clear(figs)
	await _frames(3)


## The middle of the face (world): the head bone as the body shows it, a little forward.
func _head_at(sk: Skeleton3D) -> Vector3:
	var p: ChildProportion = null
	for q in sk.get_children():
		if q is ChildProportion:
			p = q
	var g := p.posed_global("headb") if p != null else sk.get_bone_global_pose(sk.find_bone("headb"))
	return sk.global_transform * g.origin


## The head's size factor of a figure (the model's scale x the form's head height).
func _head_size(node: Node, st: String) -> float:
	var p: ChildProportion = null
	var sc := 1.0
	if node is BabyModel:
		p = (node as BabyModel)._bb.props
		sc = float(BabyBody.cfg().get("scale", 0.3))
	else:
		for c in node.find_children("*", "Skeleton3D", true, false):
			for q in c.get_children():
				if q is ChildProportion:
					p = q
		sc = float(Growth.stage_row(st).get("scale", 1.0)) if st != "adult" else 1.0
	if p == null:
		return sc
	return sc * (p._a[p.get_parent().find_bone("headb")] as Basis).y.y


## Face close-ups: baby (in a plain frame), toddler, child, teen, mother; front row and three-quarter row.
func _faces(mother: Dictionary, look: Dictionary, neutral: Dictionary) -> void:
	var sheet := Image.create(320 * 5, 400 * 2, false, Image.FORMAT_RGB8)
	var specs := [["baby", look], ["toddler", neutral], ["child", neutral], ["teen", look], ["adult", mother]]
	for col in specs.size():
		var st: String = specs[col][0]
		var f: Dictionary
		var at := Vector3.ZERO
		var node: Node3D
		if st == "baby":
			var baby := BabyModel.create({"id": "c", "name": "Ada", "sex": 0.0, "seed": seed_v}, [0.3, 0.3], 1.0, look)
			root.add_child(baby)
			baby.set_process(false)
			baby.set_state("content", 0.0, false, false)
			baby._anim.play("baby/idle_breathe")
			baby._anim.seek(0.5, true)
			baby._anim.pause()
			baby.basis = Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0))      # head up (the baby frame's x), face to +z
			baby.position = Vector3(0, 0.6, 0)
			node = baby
			await _frames(2)
			at = _head_at(baby._bb.sk)
		else:
			f = _figure(specs[col][1], 0.0, st, Vector3.ZERO)
			node = f.node
			await _frames(6)
			at = _head_at(f.sk)
		var size := 0.3 * _head_size(node, st)
		print("face ", st, " at ", at, " size ", size)
		for row in 2:
			var dir := Vector3(0, 0.05, 1).normalized() if row == 0 else Vector3(0.75, 0.05, 0.66).normalized()
			if st == "baby":
				dir = Vector3(0, 0.05, 1).normalized() if row == 0 else Vector3(0.75, 0.05, 0.66).normalized()
			_view(at + Vector3(0, -0.01 * size / 0.34, 0), at + dir * size * 3.2, 22.0)
			var img := await _snap()
			var vs := img.get_size()
			var cw := int(float(vs.y) * 320.0 / 400.0)
			img = img.get_region(Rect2i((vs.x - cw) / 2, 0, cw, vs.y))
			img.resize(320, 400, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(img, Rect2i(0, 0, 320, 400), Vector2i(320 * col, 400 * row))
		node.queue_free()
		await _frames(2)
	sheet.save_png(out.path_join("faces.png"))
	print("saved faces")


## The round-face gauge: child_round -1, -0.5, 0, 0.5, 1 on the baby (top) and the toddler (bottom), from the front.
func _round_strip(look: Dictionary, neutral: Dictionary) -> void:
	var sheet := Image.create(256 * 5, 320 * 2, false, Image.FORMAT_RGB8)
	var gs := [-1.0, -0.5, 0.0, 0.5, 1.0]
	for row in 2:
		for col in 5:
			var lk: Dictionary = (look if row == 0 else neutral).duplicate(true)
			lk["child_round"] = gs[col]
			var at := Vector3.ZERO
			var node: Node3D
			var size := 0.34
			if row == 0:
				var baby := BabyModel.create({"id": "c", "name": "Ada", "sex": 0.0, "seed": seed_v}, [0.3, 0.3], 1.0, lk)
				root.add_child(baby)
				baby.set_process(false)
				baby._anim.play("baby/idle_breathe")
				baby._anim.seek(0.5, true)
				baby._anim.pause()
				baby.basis = Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0))
				baby.position = Vector3(0, 0.6, 0)
				node = baby
				size = 0.3 * _head_size(baby, "baby")
				await _frames(2)
				at = _head_at(baby._bb.sk)
			else:
				var f := _figure(lk, 0.0, "toddler", Vector3.ZERO)
				node = f.node
				size = 0.3 * _head_size(f.node, "toddler")
				await _frames(2)
				at = _head_at(f.sk)
			_view(at, at + Vector3(0, 0.02, 1) * size * 3.2, 22.0)
			var img := await _snap()
			var vs := img.get_size()
			var cw := int(float(vs.y) * 256.0 / 320.0)
			img = img.get_region(Rect2i((vs.x - cw) / 2, 0, cw, vs.y))
			img.resize(256, 320, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(img, Rect2i(0, 0, 256, 320), Vector2i(256 * col, 320 * row))
			node.queue_free()
			await _frames(2)
	sheet.save_png(out.path_join("round_strip.png"))
	print("saved round strip")


## The flat asexual body: toddler, child and teen with nothing on, front and side (the check that nothing adult shows).
func _flat(neutral: Dictionary) -> void:
	var figs := []
	var xs := [-0.8, 0.0, 0.9]
	for i in STAGES.size():
		figs.append(_figure(neutral, 0.0, STAGES[i], Vector3(xs[i], 0, 0), true))
	await _frames(6)
	var sheet := Image.create(640 * 2, 360, false, Image.FORMAT_RGB8)
	_view(Vector3(0.05, 0.6, 0), Vector3(0.05, 0.75, 4.4), 30.0)
	var a := await _snap()
	a.resize(640, 360, Image.INTERPOLATE_LANCZOS)
	sheet.blit_rect(a, Rect2i(0, 0, 640, 360), Vector2i(0, 0))
	for f: Dictionary in figs:
		(f.node as Node3D).rotation_degrees.y = -90.0
	await _frames(3)
	var b := await _snap()
	b.resize(640, 360, Image.INTERPOLATE_LANCZOS)
	sheet.blit_rect(b, Rect2i(0, 0, 640, 360), Vector2i(640, 0))
	sheet.save_png(out.path_join("flat_check.png"))
	print("saved flat")
	_clear(figs)


## The holds: the mother cradling (content) and feeding (suckling, under the shawl), the father with the baby over his shoulder and in
## the crook of his right arm, the baby asleep in the cradle; the whole group and each close.
func _holds(mother: Dictionary, father: Dictionary, look: Dictionary) -> void:
	var specs := [[mother, 0.0, "cradle", 1.0, "content"], [mother, 0.0, "feed", 1.0, "feed"], [father, 1.0, "shoulder", 1.0, "burp"],
			[father, 1.0, "cradle", -1.0, "fretful"]]
	var figs := []
	var babies := []
	for i in specs.size():
		var sp: Array = specs[i]
		var f := _figure(sp[0], float(sp[1]), "adult", Vector3(-2.4 + 1.2 * i, 0, 0))
		figs.append(f)
		var hold := BabyHold.attach(f.sk)
		hold.alive_motion = false
		hold.engage(String(sp[2]), float(sp[3]), true)
		var baby := BabyModel.create({"id": "c", "name": "Ada", "sex": 0.0, "seed": seed_v}, [0.3, 0.3], 1.0, look)
		hold.hold.add_child(baby)
		match String(sp[4]):
			"feed":
				baby.set_state("content", 0.0, false, true)
			"burp":
				baby.set_state("content", 0.0, false, false)
				baby.play("burp_pat", 0.0)
			"fretful":
				baby.set_state("fretful", 0.4, false, false)
			_:
				baby.set_state("content", 0.0, false, false)
		babies.append(baby)
	var cr := Cradle.new()
	root.add_child(cr)
	cr.position = Vector3(2.5, 0, 0.3)
	var crm := MeshInstance3D.new()                # (the piece's own mesh: the building system gives it one in the game)
	crm.mesh = BuildGeometry.mesh("cradle", 0, {})
	cr.add_child(crm)
	var sleeper := BabyModel.create({"id": "c", "name": "Ada", "sex": 0.0, "seed": seed_v}, [0.3, 0.3], 1.0, look)
	cr.mount().add_child(sleeper)
	sleeper.set_state("asleep", 0.0, true, false)
	await _frames(20)
	_view(Vector3(0.0, 0.9, 0), Vector3(0.0, 1.3, 5.8), 34.0)
	(await _snap()).save_png(out.path_join("holds.png"))
	var sheet := Image.create(400 * 5, 400, false, Image.FORMAT_RGB8)
	for i in specs.size():
		var b: BabyModel = babies[i]
		var at: Vector3 = b.global_position + Vector3(0, 0.02, 0)
		var fwd := (figs[i].node as Node3D).global_basis.z
		_view(at, at + Vector3(0.12, 0.28, 0.0) + fwd * 0.75, 30.0)
		var img := await _snap()
		var vs := img.get_size()
		img = img.get_region(Rect2i((vs.x - vs.y) / 2, 0, vs.y, vs.y))
		img.resize(400, 400, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(img, Rect2i(0, 0, 400, 400), Vector2i(400 * i, 0))
	var at2 := sleeper.global_position
	_view(at2, at2 + Vector3(0.0, 0.75, 0.35), 34.0)
	var im2 := await _snap()
	var vs2 := im2.get_size()
	im2 = im2.get_region(Rect2i((vs2.x - vs2.y) / 2, 0, vs2.y, vs2.y))
	im2.resize(400, 400, Image.INTERPOLATE_LANCZOS)
	sheet.blit_rect(im2, Rect2i(0, 0, 400, 400), Vector2i(1600, 0))
	sheet.save_png(out.path_join("holds_close.png"))
	print("saved holds")
	_clear(figs)
	cr.queue_free()
	await _frames(3)
