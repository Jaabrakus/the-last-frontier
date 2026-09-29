class_name BabyModel
extends Node3D
## The baby. The fallback (no game character) is procedural and low-poly: a swaddled bundle (a blanket wrapped round the body with a trim band or two) and a round
## head with the face showing (eyes, a nose, a small mouth), the skin from the parents' looks. The long axis is x (the head at +x),
## the front (face, chest) +y; BabyHold carries it in a hold pose, the cradle holds it flat. It has four looks: asleep (eyes closed),
## awake, fretful, crying (the mouth open, the bundle trembling); `cried` is the hook for a sound (there is no audio here).
## A shawl (a draped cloth over the outer side of the baby) shows while it feeds.
## The body is the game's own character made small (BabyBody: Actor_B + body v4 + the face engine, a newborn's proportions baked by
## ChildProportion, the soft skin of ChildSkin, the baby animations of assets/baby/baby_anims.res, dressed from the child's look); the
## bundle below is only the fallback when the game's character is missing. Which animation plays comes from anim_for() (idle_breathe, sleep, fuss, cry, suckle while it feeds,
## burp_pat over the shoulder, wake_yawn on waking); the swaddle (a blanket mesh, baby.json "model" blanket colours) is shown only
## for the swaddled clips.
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
# the game's body made small (BabyBody)
var _bb: BabyBody
var _anim: AnimationPlayer
var _swaddle: Node3D
var _feeding := false
var _burping := false
var _burp_t := 0.0
var _cur := ""
var _want := ""
var _blanket := Color(0.83, 0.79, 0.68)
var _trim := Color(0.62, 0.36, 0.28)
var _look := {}
var _cue := {}
var _eyes_v := 0.0
var _swaddle_fit := 0      ## 0 not fitted, 1 to fit on the next update (a swaddled clip has posed the body), 2 fitted

## Tests: build the code-made bundle even though the game's character is there.
static var no_rig := false

## Animations the baby plays wrapped in the swaddle (fitted round it: fit_swaddle); the others it plays in its little linen gown.
const SWADDLED := ["idle_breathe", "sleep", "wake_yawn", "fuss", "cry", "suckle", "burp_pat"]
const LOOPS := ["idle_breathe", "sleep", "fuss", "cry", "suckle", "kick_play", "sit_wobble", "crawl", "toddle"]
## The clips of the upright baby (the others lie on the back).
const GROUND := ["sit_wobble", "crawl", "toddle"]


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
static func create(c: Dictionary, parents_melanin: Array = [0.3, 0.3], stage_size := 1.0, look := {}) -> BabyModel:
	var b := BabyModel.new()
	b.child = c
	b.name = "Baby"
	var rng := RandomNumberGenerator.new()
	rng.seed = int(c.get("seed", 1))
	var mel := 0.0
	for v: Variant in parents_melanin:
		mel += float(v)
	mel = mel / maxf(float(parents_melanin.size()), 1.0) + rng.randf_range(-0.06, 0.06)
	b._look = look.duplicate(true)
	if look.is_empty():
		b._look = {"melanin": mel, "sex": float(c.get("sex", 0.0)), "face": {}, "hair": {"style": "", "color": "dark_brown"}}
	else:
		# the child's look from its parents (ChildLook.from_parents): the same melanin the grown child will have
		mel = float(look.get("melanin", mel))
		b._look["sex"] = float(c.get("sex", look.get("sex", 0.0)))
	b.skin = skin_color(mel)
	if not look.is_empty() or ResourceLoader.exists(BodyMaterials.BODY_GLB):
		b.skin = BodyMaterials.tone_color(mel, b._look.get("undertone", "neutral")).lerp(Color(0.95, 0.55, 0.5), float(cfg().get("baby_flush", 0.05)))
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
	_blanket = _col(m.get("blanket", [0.83, 0.79, 0.68])).lightened(rng.randf_range(-0.05, 0.05))
	_trim = _col(m.get("blanket_trim", [0.62, 0.36, 0.28]))
	if _build_rig():
		_add_shawl(m)
		scale = Vector3.ONE * _size
		set_state("content", 0.0, false, false)
		return
	_build_bundle(rng)


## The game's character made small under this node (false when it is missing: the code-made bundle stands in).
func _build_rig() -> bool:
	if no_rig:
		return false
	_bb = BabyBody.create(_look, "infant" if String(child.get("stage", "")) == "infant" else "newborn")
	if _bb == null:
		return false
	add_child(_bb)
	_anim = _bb.ap
	_swaddle = MeshInstance3D.new()
	_swaddle.name = "baby_swaddle"
	(_swaddle as MeshInstance3D).mesh = swaddle_mesh()
	var mb := _mat(_blanket, 1.0)
	mb.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mt := _mat(_blanket.darkened(0.12), 1.0)
	mt.cull_mode = BaseMaterial3D.CULL_DISABLED
	(_swaddle as MeshInstance3D).set_surface_override_material(0, mb)
	(_swaddle as MeshInstance3D).set_surface_override_material(1, mt)
	_swaddle.visible = false
	add_child(_swaddle)
	if _anim != null:
		for n: String in LOOPS + ["wake_yawn", "burp_pat"]:
			if _bb.has_anim(n):
				_anim.get_animation("%s/%s" % [BabyBody.LIB, n]).loop_mode = Animation.LOOP_LINEAR if n in LOOPS else Animation.LOOP_NONE
		_anim.animation_finished.connect(_on_anim_done)
	return true


## The swaddling blanket in the baby frame (x along the body, the head end open below the chin): a rounded wrap from the chest to
## past the feet, a rolled rim at the top, two bands (surface 1) and a fold across the chest; arms free on top.
static func swaddle_mesh() -> ArrayMesh:
	var S := [[-0.25, 0.018, 0.017, 0.0, 0.0], [-0.235, 0.034, 0.03, 0.0, 0.0], [-0.21, 0.048, 0.043, 0.0, 0.0], [-0.17, 0.058, 0.052, 0.0, 0.0],
			[-0.12, 0.066, 0.06, 0.0, 0.0], [-0.06, 0.072, 0.066, 0.0, 0.0], [-0.005, 0.073, 0.068, 0.0, 0.0], [0.035, 0.068, 0.064, 0.0, 0.0],
			[0.055, 0.064, 0.06, 0.0, 0.0], [0.066, 0.067, 0.063, 0.0, 0.0], [0.074, 0.062, 0.058, 0.0, 0.0], [0.079, 0.05, 0.046, 0.0, 0.0],
			[0.082, 0.034, 0.03, 0.0, 0.0]]
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	_loft(st, S, 20)
	st.generate_normals()
	st.commit(mesh)
	var sb := SurfaceTool.new()
	sb.begin(Mesh.PRIMITIVE_TRIANGLES)
	sb.set_smooth_group(0)
	for x: float in [-0.03, -0.14]:
		var i := 0
		while i < S.size() - 2 and float((S[i + 1] as Array)[0]) < x:
			i += 1
		var a: Array = S[i]
		var b: Array = S[i + 1]
		var u := (x - float(a[0])) / (float(b[0]) - float(a[0]))
		var ry := lerpf(float(a[1]), float(b[1]), u)
		var rz := lerpf(float(a[2]), float(b[2]), u)
		_loft(sb, [[x - 0.009, ry + 0.005, rz + 0.005, 0.0, 0.0], [x, ry + 0.009, rz + 0.009, 0.0, 0.0], [x + 0.009, ry + 0.005, rz + 0.005, 0.0, 0.0]], 20)
	sb.generate_normals()
	sb.commit(mesh)
	return mesh


static func _loft(st: SurfaceTool, S: Array, segs: int, caps := true) -> void:
	var rings := []
	for sec: Array in S:
		var ring := []
		for k in segs:
			var a := TAU * k / segs
			ring.append(Vector3(float(sec[0]), float(sec[3]) + float(sec[1]) * cos(a), float(sec[4]) + float(sec[2]) * sin(a)))
		rings.append(ring)
	for i in rings.size() - 1:
		for k in segs:
			var k2 := (k + 1) % segs
			var a: Vector3 = rings[i][k]
			var b: Vector3 = rings[i + 1][k]
			var c: Vector3 = rings[i + 1][k2]
			var d: Vector3 = rings[i][k2]
			for v: Vector3 in [a, b, c, a, c, d]:
				st.add_vertex(v)
	# the end caps (fans to the centre)
	for end in ([0, rings.size() - 1] if caps else []):
		var sec: Array = S[end]
		var c := Vector3(float(sec[0]), float(sec[3]), float(sec[4]))
		for k in segs:
			var a: Vector3 = rings[end][k]
			var b: Vector3 = rings[end][(k + 1) % segs]
			for v: Vector3 in ([c, b, a] if end == 0 else [c, a, b]):
				st.add_vertex(v)


## The swaddle fitted round THIS baby as a swaddled clip holds it (legs together, arms up at the chin): the body's trunk and legs (the
## skin and the gown, CPU-skinned in the pose now, a sample of them) measured in slices along the body, each slice's extent plus a
## finger's width of blanket, smoothed; open at the chest under a rolled rim, rounded past the feet. In the baby frame.
func fit_swaddle() -> void:
	_swaddle_fit = 2
	if _bb == null or _bb.props == null:
		return
	var sk := _bb.sk
	var g: Array = _bb.props.skin_globals()
	var to_me := Transform3D()
	var n: Node = sk
	while n != null and n != self:
		to_me = (n as Node3D).transform * to_me if n is Node3D else to_me
		n = n.get_parent()
	var skip := {}
	for i in sk.get_bone_count():
		var nm := sk.get_bone_name(i)
		for k: String in ["head", "neck", "jaw", "shoulder", "elbow", "wrist", "forarm", "palm", "index", "middle", "ring", "pinky", "thumb", "deltoid", "clavicle", "wrinklemaps"]:
			if nm.contains(k):
				skip[i] = true
	var pts := PackedVector3Array()
	for mi: MeshInstance3D in _bb.body.meshes:
		if not is_instance_valid(mi) or not mi.visible or mi.mesh == null or mi.skin == null or mi.name.begins_with("hair"):
			continue
		var am := mi.mesh as ArrayMesh
		for si in am.get_surface_count():
			var arr := am.surface_get_arrays(si)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bo: Variant = arr[Mesh.ARRAY_BONES]
			var w: Variant = arr[Mesh.ARRAY_WEIGHTS]
			if bo == null or w == null or v.is_empty():
				continue
			var nb := (bo as PackedInt32Array).size() / v.size()
			var step := maxi(1, v.size() / 3000)
			for i in range(0, v.size(), step):
				var q := Vector3.ZERO
				var ws := 0.0
				var bad := 0.0
				for k in nb:
					var ww: float = (w as PackedFloat32Array)[i * nb + k]
					if ww <= 0.0:
						continue
					var bi: int = (bo as PackedInt32Array)[i * nb + k]
					var bone := mi.skin.get_bind_bone(bi)
					if skip.has(bone):
						bad += ww
					q += ((g[bone] as Transform3D) * mi.skin.get_bind_pose(bi) * v[i]) * ww
					ws += ww
				if ws > 0.0 and bad < 0.3:
					pts.append(to_me * (q / ws))
	if pts.size() < 50:
		return
	# the top: just under the arms' roots (the shoulders in the baby frame)
	var top := -INF
	for sh in ["l_shoulder", "r_shoulder"]:
		top = maxf(top, (to_me * (g[sk.find_bone(sh)] as Transform3D).origin).x)
	var x0 := INF
	for p in pts:
		x0 = minf(x0, p.x)
	var x1 := top - float(cfg().get("swaddle_top", 0.012))
	var ns := 12
	var secs: Array = []
	for k in ns + 1:
		var xa := lerpf(x0, x1, float(k) / ns)
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for p in pts:
			if absf(p.x - xa) < (x1 - x0) / ns * 0.75 and p.x <= x1 + 0.005:
				lo = lo.min(Vector2(p.y, p.z))
				hi = hi.max(Vector2(p.y, p.z))
		if lo.x == INF:
			continue
		secs.append([xa, hi.x - lo.x, hi.y - lo.y, (lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5])
	if secs.size() < 3:
		return
	var m := float(cfg().get("swaddle_margin", 0.01))
	var sm: Array = []
	for k in secs.size():
		var a: Array = secs[maxi(k - 1, 0)]
		var b: Array = secs[k]
		var c: Array = secs[mini(k + 1, secs.size() - 1)]
		var row := [b[0]]
		for j in range(1, 5):
			row.append((float(a[j]) + 2.0 * float(b[j]) + float(c[j])) * 0.25)
		# a blanket: at least round-ish (never a flat board), a finger's width off the body
		var ry := float(row[1]) * 0.5 + m
		var rz := float(row[2]) * 0.5 + m
		var r := maxf(ry, rz)
		var top_k := 1.0 - 0.12 * smoothstep(float(secs.size()) - 3.0, float(secs.size()) - 1.0, float(k))   # (hugging the chest at the top)
		sm.append([row[0], lerpf(ry, r, 0.35) * top_k, lerpf(rz, r, 0.35) * top_k, row[3], row[4]])
	# the end past the feet, rounded
	var f0: Array = sm[0]
	var ends := [[float(f0[0]) - 0.032, float(f0[1]) * 0.02, float(f0[2]) * 0.02, f0[3], f0[4]], [float(f0[0]) - 0.03, float(f0[1]) * 0.4, float(f0[2]) * 0.4, f0[3], f0[4]],
			[float(f0[0]) - 0.022, float(f0[1]) * 0.75, float(f0[2]) * 0.75, f0[3], f0[4]], [float(f0[0]) - 0.01, float(f0[1]) * 0.95, float(f0[2]) * 0.95, f0[3], f0[4]]]
	var loft: Array = ends + sm
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	_loft(st, loft, 24, false)
	st.generate_normals()
	st.commit(mesh)
	# the rolled rim at the top (surface 1: the blanket's edge, a shade darker)
	var sb := SurfaceTool.new()
	sb.begin(Mesh.PRIMITIVE_TRIANGLES)
	sb.set_smooth_group(0)
	var t: Array = sm[-1]
	var rr := 0.005
	_loft(sb, [[float(t[0]) - rr, float(t[1]) + rr * 0.3, float(t[2]) + rr * 0.3, t[3], t[4]], [float(t[0]) - rr * 0.2, float(t[1]) + rr, float(t[2]) + rr, t[3], t[4]],
			[float(t[0]) + rr * 0.4, float(t[1]) + rr * 0.6, float(t[2]) + rr * 0.6, t[3], t[4]], [float(t[0]) + rr * 0.5, float(t[1]) - rr * 0.2, float(t[2]) - rr * 0.2, t[3], t[4]]], 24, false)
	sb.generate_normals()
	sb.commit(mesh)
	(_swaddle as MeshInstance3D).mesh = mesh


## Which animation a state plays: asleep sleeps; at the breast it suckles; crying, fretful, else it breathes and looks about.
static func anim_for(mood: String, asleep: bool, feeding: bool) -> String:
	if asleep or mood == "asleep":
		return "sleep"
	if feeding:
		return "suckle"
	if mood in ["crying", "wailing"]:
		return "cry"
	if mood == "fretful":
		return "fuss"
	return "idle_breathe"


## Plays `name` (blended in); a one-shot goes back to what the state wants when it ends. False without the character or the animation.
func play(name: String, blend := 0.25) -> bool:
	if _bb == null or not _bb.has_anim(name):
		return false
	_cur = name
	_cue = (BabyCare.cfg().get("cues", {}) as Dictionary).get(name, {})
	_bb.set_frame(name in GROUND)
	if is_inside_tree():
		_bb.play(name, blend)
	if _swaddle != null:
		_swaddle.visible = name in SWADDLED and bool(cfg().get("swaddle", true))
		if _swaddle.visible:
			_swaddle_fit = 1           # (fitted again to this clip's pose on the next update)
	return true


## The face from the animation's cue (baby.json "cues"): the eyes held shut or blinking, the mouth's dark mesh by the cry level.
func _face() -> void:
	if _swaddle_fit == 1:
		fit_swaddle()
	var breath: Array = _cue.get("breath", [0.4, 0.6])
	_bb.set_breath((0.5 - 0.5 * cos(TAU * float(breath[0]) * _t)) * float(breath[1]))
	var eyes := float(_cue.get("eyes", 0.0))
	var open := float(_cue.get("mouth", 0.0))
	var pos := _anim.current_animation_position
	if bool(_cue.get("yawn", false)):
		var y := smoothstep(0.45, 1.05, pos) * (1.0 - smoothstep(1.55, 2.05, pos))
		open = open * y
		eyes = eyes * (1.0 - smoothstep(2.0, 2.5, pos))
	elif _cue.has("pulse"):
		var amp := float(_cue.get("pulse_amp", 0.2))
		open = open * (1.0 - amp * (0.5 - 0.5 * cos(TAU * float(_cue.pulse) * _t)))
		if _cur in ["cry", "fuss"]:
			open *= 0.7 + 0.3 * clampf(_cry, 0.0, 1.0)
	if absf(eyes - _eyes_v) > 0.01:
		_eyes_v = eyes
		_bb.set_eyes(eyes)
	_bb.set_mouth(open, float(_cue.get("width", 1.0)))


func current_animation() -> String:
	return _cur


## (Made before it is in the tree, or taken out and put back into another holder's hold: start what it was doing again.)
func _enter_tree() -> void:
	if _bb != null and _cur != "" and not _anim.is_playing():
		_bb.play(_cur, 0.0)


func _on_anim_done(_n: StringName) -> void:
	if _want != "":
		play(_want)


## Over the shoulder, awake: a pat on the back now and then (burp_pat), as long as it is held so.
func set_burping(on: bool) -> void:
	_burping = on
	if not on:
		_burp_t = 0.0


func _add_shawl(m: Dictionary) -> void:
	_shawl = MeshInstance3D.new()
	_shawl.name = "Shawl"
	_shawl.mesh = shawl_mesh()
	var sm := _mat(_col(m.get("shawl", [0.8, 0.72, 0.56])), 1.0)
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shawl.material_override = sm
	_shawl.visible = false
	add_child(_shawl)


func _build_bundle(rng: RandomNumberGenerator) -> void:
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
	var was_asleep := _asleep
	_mood = mood
	_cry = cry
	_asleep = asleep
	_feeding = shawl
	if _anim != null:
		_want = anim_for(mood, asleep, shawl)
		var waking := was_asleep and not asleep and _want in ["idle_breathe", "fuss"] and _bb.has_anim("wake_yawn")
		if waking:
			play("wake_yawn")
		elif _cur == "burp_pat" and _want == "idle_breathe" and _anim.is_playing():
			pass                                  # (the pat finishes, then _on_anim_done goes on)
		elif _want != _cur or not _anim.is_playing():
			if not (_cur == "wake_yawn" and _anim.is_playing() and _want in ["idle_breathe", "fuss"]):
				play(_want)
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
	if _anim != null:
		if _burping and not _asleep and not _feeding and _mood not in ["crying", "wailing"]:
			_burp_t -= dt
			if _burp_t <= 0.0:
				_burp_t = 5.5
				play("burp_pat")
		if _bb != null:
			_face()
		return
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
