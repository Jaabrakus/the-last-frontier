class_name BloodFx
## Blood where a melee blow lands on flesh (user 2026-09-27: "the footage does look good we just need to add blood
## effect and splash"): a spray of drops thrown on along the blade's way (and a few back the way it came), drops
## splashed on the ground where the spray comes down (decals, a moment later), and a wound's
## mark on the body struck (a decal on the bone nearest the blow, moving with it). `amount` scales it (the blow's
## weight: the crunch at the spine the most). Particles as Fx's (CPUParticles3D played as GPU particles, freeing
## themselves); the ground's and the bodies' marks keep to MAX_GROUND and MAX_BODY, the oldest going. No mist (user:
## "the blood cloud is to much", "no blood mist from the smoke animation"): drops and marks only.

const MAX_GROUND := 80
const MAX_BODY := 10
const BLOOD := Color(0.42, 0.02, 0.02)

static var _ground: Array = []
static var _tex: Texture2D


## Blood at `point` from a blow travelling `dir`, on the surface facing `normal`; `body` the one struck (its wound's
## mark), or null.
static func hit(parent: Node, point: Vector3, dir: Vector3, normal: Vector3, amount := 1.0, body: Node = null) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var way := dir.normalized() if dir.length_squared() > 1e-4 else -normal
	amount = clampf(amount, 0.3, 2.0)
	_spray(parent, point, (way * 0.8 + Vector3.UP * 0.3).normalized(), int(round(14.0 * amount)), 2.2, 4.8)
	_spray(parent, point, ((-way) * 0.6 + normal * 0.3 + Vector3.UP * 0.35).normalized(), int(round(5.0 * amount)), 1.2, 2.6)
	_splash(parent, point, way, amount)
	if body:
		_wound(body, point, way)


## Played once so the particles' shaders are ready before the first blow (Fx.warm_up).
static func warm(parent: Node, at: Vector3) -> void:
	_spray(parent, at, Vector3.UP, 2, 1.0, 2.0)


static func _spray(parent: Node, point: Vector3, dir: Vector3, n: int, v0: float, v1: float) -> void:
	var p := Fx._particles(parent, point, n, 0.04, 0.75)
	# (a particle billboard is drawn its mesh's size, 1 m, unless it keeps its scale: without it every drop was a
	# metre-wide red disc; user 2026-09-27: "you see what is that red mist")
	((p.mesh as QuadMesh).material as StandardMaterial3D).billboard_keep_scale = true
	p.direction = dir
	p.spread = 28.0
	p.initial_velocity_min = v0
	p.initial_velocity_max = v1
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.035
	p.scale_amount_max = 0.075
	p.scale_amount_curve = Fx._curve(1.0, 0.9, 0.6)
	p.color_ramp = Fx._ramp([Color(BLOOD, 1.0), Color(0.3, 0.0, 0.0, 0.95), Color(0.25, 0.0, 0.0, 0.0)])
	Fx._emit(p, true)


## Drops on the ground ahead along the spray, where they come down (a moment later).
static func _splash(parent: Node, point: Vector3, way: Vector3, amount: float) -> void:
	var tree := parent.get_tree()
	var flat := Vector3(way.x, 0.0, way.z)
	flat = flat.normalized() if flat.length_squared() > 1e-4 else Vector3.FORWARD
	var side := flat.cross(Vector3.UP)
	for i in int(round(4.0 + 4.0 * amount)):
		var along := randf_range(0.2, 1.3) * (0.6 + 0.4 * amount)
		var at := point + flat * along + side * randf_range(-0.3, 0.3)
		var fall := sqrt(2.0 * maxf(point.y - FrontierTerrain.height_at(at.x, at.z), 0.1) / 9.8)
		var size := randf_range(0.08, 0.2) * (0.7 + 0.3 * amount) * (1.3 if i == 0 else 1.0)
		tree.create_timer(fall * randf_range(0.8, 1.2)).timeout.connect(_ground_drop.bind(parent, at, size))


static func _ground_drop(parent: Node, at: Vector3, size: float) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var d := Decal.new()
	d.texture_albedo = _texture()
	d.modulate = Color(BLOOD, 0.95)
	d.size = Vector3(size, 0.8, size)
	WildlifeSpawner._on_ground_only(d)
	parent.add_child(d)
	d.global_position = Vector3(at.x, FrontierTerrain.height_at(at.x, at.z) + 0.03, at.z)
	d.rotation.y = randf() * TAU
	# (with the level's wildlife: aged and budgeted with the rest of the blood on the ground)
	var sp := WildlifeSpawner.find(parent.get_tree())
	if sp:
		d.modulate = Color(1.0, 1.0, 1.0, 0.95)
		d.texture_albedo = sp._blood_texture("red")
		sp.adopt_drop(d, "red", -2)
		return
	_ground.append(d)
	while _ground.size() > MAX_GROUND:
		var old = _ground.pop_front()
		if is_instance_valid(old):
			(old as Node).queue_free()


## The wound's mark: a decal on the bone of `body`'s skeleton nearest the blow, facing the way it came.
static func _wound(body: Node, point: Vector3, way: Vector3) -> void:
	var sks := body.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return
	var sk := sks[0] as Skeleton3D
	var best := -1
	var best_d := INF
	for i in sk.get_bone_count():
		var d := (sk.global_transform * sk.get_bone_global_pose(i).origin).distance_squared_to(point)
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		return
	var holder := sk.get_node_or_null(NodePath("Wounds_" + sk.get_bone_name(best))) as BoneAttachment3D
	if holder == null:
		holder = BoneAttachment3D.new()
		holder.name = "Wounds_" + sk.get_bone_name(best)
		holder.bone_name = sk.get_bone_name(best)
		sk.add_child(holder)
		# (on its bone at once: the skeleton puts it there only when it next moves, and till then it stands at the
		# skeleton's origin, where a mark placed for the bone would be blown up by the skeleton's scale)
		holder.transform = sk.get_bone_global_pose(best)
	var d := Decal.new()
	d.texture_albedo = _texture()
	d.modulate = Color(0.35, 0.01, 0.01, 0.9)
	var s := randf_range(0.1, 0.16)
	d.size = Vector3(s, 0.3, s)
	holder.add_child(d)
	# (its -Y, the way it projects, along the blow into the body; placed from where the holder is, on its bone, so
	# it is the size it is meant to be in the world whatever the skeleton's scale)
	var y := -way.normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).normalized()
	var want := Transform3D(Basis(x, y, x.cross(y)).orthonormalized(), point)
	d.transform = holder.global_transform.affine_inverse() * want
	var marks: Array = sk.get_meta(&"wound_marks", [])
	marks.append(d)
	while marks.size() > MAX_BODY:
		var old = marks.pop_front()
		if is_instance_valid(old):
			(old as Node).queue_free()
	sk.set_meta(&"wound_marks", marks)


## A splatter: a ragged blot with a few drops flung round it.
static func _texture() -> Texture2D:
	if _tex:
		return _tex
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.09
	noise.seed = 7
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var drops: Array = []
	for i in 7:
		var ang := rng.randf() * TAU
		drops.append([Vector2(cos(ang), sin(ang)) * rng.randf_range(0.55, 0.85), rng.randf_range(0.05, 0.11)])
	for y in n:
		for x in n:
			var v := Vector2(x - n * 0.5, y - n * 0.5) / (n * 0.5)
			var edge := 0.45 + 0.22 * noise.get_noise_2d(x, y)
			var a := clampf((edge - v.length()) * 7.0, 0.0, 1.0)
			for dr: Array in drops:
				a = maxf(a, clampf(((dr[1] as float) - v.distance_to(dr[0] as Vector2)) * 30.0, 0.0, 1.0))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_tex = ImageTexture.create_from_image(img)
	return _tex
