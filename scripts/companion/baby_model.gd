class_name BabyModel
extends Node3D
## The baby, procedural and low-poly: a swaddled bundle (a blanket wrapped round the body with a trim band or two) and a round
## head with the face showing (eyes, a nose, a small mouth), the skin from the parents' looks. The long axis is x (the head at +x),
## the front (face, chest) +y; BabyHold carries it in a hold pose, the cradle holds it flat. It has four looks: asleep (eyes closed),
## awake, fretful, crying (the mouth open, the bundle trembling); `cried` is the hook for a sound (there is no audio here).
## A shawl (a draped cloth over the outer side of the baby) shows while it feeds.
##   var b := BabyModel.create(child, [mother_melanin, father_melanin]); b.set_state("crying", 0.7, false, false)

signal cried   ## the baby began to cry (a sound hook)

var child := {}
var skin := Color(0.9, 0.72, 0.62)
var _mood := ""
var _cry := 0.0
var _asleep := false
var _t := 0.0
var _mouth: MeshInstance3D
var _eyes_open: Node3D
var _eyes_shut: Node3D
var _bundle: Node3D
var _shawl: MeshInstance3D
var _size := 1.0


static func cfg() -> Dictionary:
	return (BabyCare.cfg().get("model", {}) as Dictionary)


## The skin from the data's ramp for a melanin 0..1 (a newborn's a touch flushed).
static func skin_color(melanin: float) -> Color:
	var ramp: Dictionary = cfg().get("melanin_skin", {"0.0": [0.93, 0.77, 0.68], "1.0": [0.38, 0.24, 0.17]})
	var stops := []
	for k: Variant in ramp:
		stops.append([float(String(k)), _col(ramp[k])])
	stops.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var m := clampf(melanin, 0.0, 1.0)
	var c: Color = (stops[0] as Array)[1]
	for i in stops.size():
		var s0: Array = stops[i]
		if m >= float(s0[0]):
			c = s0[1]
			if i + 1 < stops.size():
				var s1: Array = stops[i + 1]
				c = (s0[1] as Color).lerp(s1[1], clampf((m - float(s0[0])) / maxf(float(s1[0]) - float(s0[0]), 0.0001), 0.0, 1.0))
	return c.lerp(Color(0.95, 0.55, 0.5), float(cfg().get("baby_flush", 0.05)))


static func _col(a: Variant) -> Color:
	return Color(float(a[0]), float(a[1]), float(a[2])) if a is Array and (a as Array).size() >= 3 else Color(0.9, 0.7, 0.6)


## The baby for a child record; `parents_melanin` the two parents' looks' melanin (0..1). The blanket's colour comes from the
## data and the child's seed nudges it, the skin blends the parents.
static func create(c: Dictionary, parents_melanin: Array = [0.3, 0.3], stage_size := 1.0) -> BabyModel:
	var b := BabyModel.new()
	b.child = c
	b.name = "Baby"
	var rng := RandomNumberGenerator.new()
	rng.seed = int(c.get("seed", 1))
	var mel := 0.0
	for v: Variant in parents_melanin:
		mel += float(v)
	mel = mel / maxf(float(parents_melanin.size()), 1.0) + rng.randf_range(-0.06, 0.06)
	b.skin = skin_color(mel)
	b._size = stage_size
	b._build(rng)
	return b


func _mat(col: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	return m


func _part(parent: Node3D, mesh: Mesh, col: Color, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(col)
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _build(rng: RandomNumberGenerator) -> void:
	var m := cfg()
	var len_m := float(m.get("length", 0.44))
	var br := float(m.get("body_radius", 0.068))
	var hr := float(m.get("head_radius", 0.066))
	var hx := float(m.get("head_x", 0.175))
	var blanket := _col(m.get("blanket", [0.83, 0.79, 0.68]))
	blanket = blanket.lightened(rng.randf_range(-0.05, 0.05))
	var trim := _col(m.get("blanket_trim", [0.62, 0.36, 0.28]))
	_bundle = Node3D.new()
	_bundle.name = "Bundle"
	add_child(_bundle)
	# the swaddled body: a capsule along x, the blanket's bands over it
	var cap := CapsuleMesh.new()
	cap.radius = br
	cap.height = len_m * 0.78
	cap.radial_segments = 12
	cap.rings = 4
	_part(_bundle, cap, blanket, Vector3(-len_m * 0.5 + len_m * 0.39 - 0.02, 0, 0), Vector3(0, 0, PI * 0.5), Vector3(1.0, 1.0, 1.15))
	for x: float in [-0.02, -0.13]:
		var band := CylinderMesh.new()
		band.top_radius = br * 1.05
		band.bottom_radius = br * 1.05
		band.height = 0.035
		band.radial_segments = 12
		_part(_bundle, band, trim, Vector3(x, 0, 0), Vector3(0, 0, PI * 0.5), Vector3(1.0, 1.0, 1.15))
	# a folded corner of the blanket at the neck
	var fold := SphereMesh.new()
	fold.radius = br * 0.9
	fold.height = br * 1.4
	fold.radial_segments = 10
	fold.rings = 5
	_part(_bundle, fold, blanket, Vector3(hx - hr - 0.005, 0, 0), Vector3.ZERO, Vector3(0.8, 1.0, 1.1))
	# the head
	var head := SphereMesh.new()
	head.radius = hr
	head.height = hr * 2.0
	head.radial_segments = 14
	head.rings = 8
	_part(_bundle, head, skin, Vector3(hx, 0, 0), Vector3.ZERO, Vector3(0.96, 1.0, 1.0))
	# the face on the front (+y)
	var dark := Color(0.16, 0.1, 0.09)
	var nose := SphereMesh.new()
	nose.radius = 0.008
	nose.height = 0.016
	nose.radial_segments = 6
	nose.rings = 3
	_part(_bundle, nose, skin.darkened(0.04), Vector3(hx + 0.006, hr * 0.99, 0))
	_eyes_open = Node3D.new()
	_eyes_shut = Node3D.new()
	_bundle.add_child(_eyes_open)
	_bundle.add_child(_eyes_shut)
	for sz: float in [-1.0, 1.0]:
		var eye := SphereMesh.new()
		eye.radius = 0.0065
		eye.height = 0.013
		eye.radial_segments = 6
		eye.rings = 3
		_part(_eyes_open, eye, dark, Vector3(hx + 0.02, hr * 0.94, sz * 0.026))
		var lid := BoxMesh.new()
		lid.size = Vector3(0.005, 0.003, 0.02)
		_part(_eyes_shut, lid, dark, Vector3(hx + 0.02, hr * 0.955, sz * 0.026))
	var mouth := SphereMesh.new()
	mouth.radius = 0.011
	mouth.height = 0.022
	mouth.radial_segments = 8
	mouth.rings = 4
	_mouth = _part(_bundle, mouth, Color(0.45, 0.16, 0.16), Vector3(hx - 0.024, hr * 0.955, 0), Vector3.ZERO, Vector3(0.8, 0.3, 1.5))
	# the shawl (shown while it feeds)
	_shawl = MeshInstance3D.new()
	_shawl.name = "Shawl"
	_shawl.mesh = shawl_mesh()
	_shawl.material_override = _mat(_col(m.get("shawl", [0.42, 0.34, 0.3])), 1.0)
	(_shawl.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	(_shawl.material_override as StandardMaterial3D).albedo_color = _col(m.get("shawl", [0.8, 0.72, 0.56]))
	_shawl.visible = false
	add_child(_shawl)
	scale = Vector3.ONE * _size
	set_state("content", 0.0, false, false)


## A soft wool cloth laid over the baby's outer side (-y): a curved wrap round the bundle (a little more than half round), a few
## hanging folds along its length, the head end (+x) left open so the face shows. Smooth-shaded. In the baby's frame.
static func shawl_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var nx := 12
	var nt := 10
	var x0 := -0.24
	var x1 := 0.085
	var r0 := 0.088
	var pts := []
	for i in nx + 1:
		var row := []
		var fx := float(i) / nx
		var x := lerpf(x0, x1, fx)
		# the cloth narrows toward the head end and hangs a little past the feet
		var r := r0 * lerpf(1.05, 0.9, fx)
		for j in nt + 1:
			var t := lerpf(-1.75, 1.75, float(j) / nt)          # radians round the outer side
			var fold := 1.0 + 0.09 * sin(x * 38.0 + t * 3.0)
			var rr := r * fold
			var y := -cos(t) * rr + 0.01
			var z := sin(t) * rr * 1.1
			if fx < 0.15:
				y -= (0.15 - fx) * 0.06                          # the foot end hangs
			row.append(Vector3(x, y, z))
		pts.append(row)
	for i in nx:
		for j in nt:
			var a: Vector3 = pts[i][j]
			var b: Vector3 = pts[i + 1][j]
			var c: Vector3 = pts[i + 1][j + 1]
			var d: Vector3 = pts[i][j + 1]
			for v: Vector3 in [a, c, b, a, d, c]:
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()


## The look: `mood` ("asleep", "content", "fretful", "crying", "wailing"), `cry` 0..1, `shawl` on or off.
func set_state(mood: String, cry: float, asleep: bool, shawl: bool) -> void:
	var began := mood in ["crying", "wailing"] and _mood not in ["crying", "wailing"]
	_mood = mood
	_cry = cry
	_asleep = asleep
	if _eyes_open != null:
		_eyes_open.visible = not asleep and mood not in ["crying", "wailing"]
		_eyes_shut.visible = asleep or mood in ["crying", "wailing"]
	if _shawl != null:
		_shawl.visible = shawl
	if not mood in ["crying", "wailing"] and _mouth != null:
		_mouth.scale = Vector3(0.8, 0.3, 1.5) if mood != "fretful" else Vector3(0.8, 0.5, 1.3)
	if began:
		cried.emit()


func _process(dt: float) -> void:
	_t += dt
	if _mouth == null:
		return
	if _mood in ["crying", "wailing"]:
		var cs := float(cfg().get("cry_scale", 1.1))
		var pulse := 0.5 + 0.5 * sin(_t * (9.0 + 4.0 * _cry))
		_mouth.scale = Vector3(1.0, lerpf(0.7, 1.4, pulse) * cs, 1.1)
		# the bundle trembles, more the louder
		_bundle.rotation = Vector3(sin(_t * 23.0) * 0.012 * (0.5 + _cry), 0.0, sin(_t * 17.0) * 0.02 * (0.5 + _cry))
	else:
		_bundle.rotation = _bundle.rotation.lerp(Vector3.ZERO, clampf(dt * 6.0, 0.0, 1.0))
		if _asleep:
			# a slow breath
			_bundle.scale = Vector3.ONE * (1.0 + 0.012 * sin(_t * 1.8))
		else:
			_bundle.scale = Vector3.ONE
