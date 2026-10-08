class_name MonsoonIdentity
extends RefCounted
## Project-authored release marks, built from mathematical paths, not reference assets.
## Cosmetic only: the existing caster remains the sole release and damage authority.

const CONFIG := "res://data/ring/monsoon_identity.json"
static var _config: Dictionary = {}
static var _meshes: Dictionary = {}


static func accent(element: String) -> Color:
	if _config.is_empty():
		_config = JSON.parse_string(FileAccess.get_file_as_string(CONFIG)) as Dictionary
	return Color.html(String((_config.get("elements", {}) as Dictionary).get(element, {}).get("accent", "#ffffff")))


static func mesh(element: String) -> ArrayMesh:
	if _meshes.has(element):
		return _meshes[element]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match element:
		"earth":
			for i in 3:
				var x := (i - 1) * 0.5
				_path(st, [Vector2(x - 0.2, 0.2), Vector2(x - 0.2, -0.05), Vector2(x, -0.3 - (0.15 if i == 1 else 0.0)), Vector2(x + 0.2, -0.05), Vector2(x + 0.2, 0.2)])
			_path(st, [Vector2(-0.78, 0.4), Vector2(0.78, 0.4)])
		"water":
			for i in 3:
				var pts: Array[Vector2] = []
				for j in 25:
					var x := -0.75 + j / 24.0 * 1.5
					pts.append(Vector2(x, sin(x * 4.0 + i * 0.6) * 0.13 + (i - 1) * 0.28))
				_path(st, pts)
		"fire":
			for i in 7:
				var a := PI + i * PI / 6.0
				_path(st, [Vector2(cos(a), sin(a)) * 0.24, Vector2(cos(a), sin(a)) * (0.72 if i % 2 == 0 else 0.55)])
			_path(st, [Vector2(-0.5, 0.2), Vector2(-0.2, 0.38), Vector2.ZERO, Vector2(0.2, 0.38), Vector2(0.5, 0.2)])
		"air":
			for i in 4:
				var pts: Array[Vector2] = []
				for j in 18:
					var f := j / 17.0
					var a := i * PI * 0.5 + f * 1.1
					pts.append(Vector2(cos(a), sin(a)) * lerpf(0.22, 0.75, f))
				_path(st, pts)
		_:
			return null
	var result := st.commit()
	_meshes[element] = result
	return result


static func _path(st: SurfaceTool, points: Array, width := 0.055) -> void:
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var side := (b - a).normalized().orthogonal() * width * 0.5
		for v: Vector2 in [a + side, b + side, b - side, a + side, b - side, a - side]:
			st.set_normal(Vector3.UP)
			st.set_uv(v * 0.5 + Vector2.ONE * 0.5)
			st.add_vertex(Vector3(v.x, 0.0, v.y))


static func release(body: Node3D, element: String, big: bool) -> void:
	if body == null or not body.is_inside_tree() or not BendLooks.live():
		return
	var shape := mesh(element)
	if shape == null:
		return
	var pool := ToonFxPool.of(body.get_tree().current_scene)
	if pool == null:
		return
	# At the caster's feet, including in the air; never projected onto a target or a hitbox.
	var xf := Transform3D(Basis(Vector3.UP, body.global_rotation.y), body.global_position + Vector3.UP * 0.06)
	pool.play("monsoon_seal", xf, 0.32 if big else 0.22, 0.55, 1.1 if big else 0.78,
			accent(element), Color.WHITE, shape)
