class_name BirdFlock
extends Node3D
## A flock of small birds (BirdLife): crossing the sky by day, or bursting up from the tree line at a shot. Tiny
## procedural birds in one MultiMesh (the wings beat in shaders/wildlife/flock_bird.gdshader); each bird keeps its own
## place in the loose flock, which drifts and wheels a little as it goes. Gone at the end of its path.

var count := 20
var from := Vector3.ZERO
var to := Vector3.ZERO
var speed := 11.0
## Bursting up (a flush): starts in the treetops and climbs steeply first.
var flush := false
var rng := RandomNumberGenerator.new()

var _t := 0.0
var _dur := 20.0
var _mm: MultiMesh
var _off := PackedVector3Array()


func setup(p_from: Vector3, p_to: Vector3, p_count: int, seed_: int, p_flush := false) -> void:
	from = p_from
	to = p_to
	count = p_count
	flush = p_flush
	rng.seed = seed_


func _ready() -> void:
	add_to_group(&"flocks")
	_dur = maxf(from.distance_to(to) / speed, 3.0)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.mesh = _bird_mesh()
	_mm.instance_count = count
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = _mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/wildlife/flock_bird.gdshader")
	mi.material_override = mat
	mi.custom_aabb = AABB(Vector3(-400, -100, -400), Vector3(800, 300, 800))
	add_child(mi)
	top_level = true
	global_position = Vector3.ZERO
	for i in count:
		_off.append(Vector3(rng.randf_range(-1, 1) * 6.0, rng.randf_range(-1, 1) * 2.5, rng.randf_range(-1, 1) * 6.0))
	_place(0.0)


func _process(dt: float) -> void:
	_t += dt
	if _t >= _dur:
		queue_free()
		return
	_place(dt)


func _place(_dt: float) -> void:
	var k := _t / _dur
	var c := from.lerp(to, k)
	if flush:
		c.y += (1.0 - exp(-_t * 1.4)) * 18.0          # up out of the trees, then away
	var dir := (to - from).normalized()
	var spread := 0.6 if flush and _t < 1.0 else 1.0
	for i in count:
		var o := _off[i]
		var w := Vector3(sin(_t * 0.7 + i) * 1.5, sin(_t * 1.3 + i * 2.1) * 0.8, cos(_t * 0.6 + i * 1.7) * 1.5)
		var p := c + (o + w) * spread
		var b := Basis.looking_at(dir + Vector3(0, 0.05 * sin(_t + i), 0), Vector3.UP)
		_mm.set_instance_transform(i, Transform3D(b, p))


## One bird: a slim body and two wings (their outer vertices marked in COLOR.r for the beat), ~0.3 m span.
static func _bird_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := [Vector3(0, 0, -0.1), Vector3(0.025, 0.005, 0.0), Vector3(0, 0.02, 0.0), Vector3(-0.025, 0.005, 0.0), Vector3(0, 0.0, 0.09)]
	for tri: Array in [[0, 1, 2], [0, 2, 3], [2, 1, 4], [3, 2, 4], [0, 3, 1], [1, 3, 4]]:
		for i: int in tri:
			st.set_color(Color(0, 0, 0))
			st.add_vertex(body[i])
	for side: float in [-1.0, 1.0]:
		var sh := Vector3(0.02 * side, 0.01, -0.03)
		var tip := Vector3(0.16 * side, 0.0, 0.01)
		var back := Vector3(0.02 * side, 0.01, 0.04)
		for v: Vector3 in [sh, tip, back]:
			st.set_color(Color(1, 0, 0) if v == tip else Color(0, 0, 0))
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()
