class_name BoatGear
extends RefCounted
## What is left inside a boat (user 2026-09-29: "oars will be left inside the boat"): its paddles or oars, lying along the floor, made in
## code (a shaft and a leaf-shaped blade in the project's Poly Haven wood). The one who gets in takes one up (Boat.take_paddle) and puts it
## back when they get out. Lengths in m.

const PADDLE_LEN := 1.35
const OAR_LEN := 2.3
const BLADE_LEN := 0.5
const BLADE_W := 0.13
## The paddle on the right hand's prop bone, as the authored clips hold it (tools/anim_author/author_paddle.gd): the pipe frame of the hand's
## prop bone (pose_solver PIPE), and the paddle model (its grip at the origin, the blade toward +Z) put in the tool frame whose haft runs
## from the blade's tip (the origin) up to the grip.
const PIPE := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)), Vector3(0, 0, -0.035))
const PADDLE_IN_HANDS := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)), Vector3(0, PADDLE_LEN, 0))
const WOOD := "res://assets/polyhaven/textures/structures/brown_planks_07/brown_planks_07_diffuse_2k.jpg"

static var _mat: StandardMaterial3D


static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		var t := load(WOOD) as Texture2D
		if t:
			_mat.albedo_texture = t
		_mat.albedo_color = Color(0.86, 0.74, 0.58)
		_mat.roughness = 0.75
		_mat.uv1_scale = Vector3(1.0, 4.0, 1.0)
	return _mat


## A paddle or an oar: the node's +Z is the way the blade points, its origin the middle of the grip end... the shaft runs from the grip
## (z = 0) to the tip of the blade (z = `length`). Held it is the hands on the shaft, the blade in the water.
static func make(kind: String) -> Node3D:
	var length := OAR_LEN if kind == "oars" else PADDLE_LEN
	var n := Node3D.new()
	n.name = "Paddle"
	var shaft := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.017
	cyl.bottom_radius = 0.019
	cyl.height = length - BLADE_LEN * 0.6
	shaft.mesh = cyl
	shaft.material_override = material()
	shaft.rotation.x = PI * 0.5
	shaft.position.z = (length - BLADE_LEN * 0.6) * 0.5
	n.add_child(shaft)
	var grip := MeshInstance3D.new()
	var gm := SphereMesh.new()
	gm.radius = 0.03
	gm.height = 0.06
	grip.mesh = gm
	grip.material_override = material()
	n.add_child(grip)
	var blade := MeshInstance3D.new()
	blade.mesh = _blade_mesh()
	blade.material_override = material()
	blade.position.z = length - BLADE_LEN
	n.add_child(blade)
	return n


## The blade: a leaf outline, tapering into the shaft, a little thick in the middle; in the X-Z plane, its tip at +Z.
static func _blade_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector2] = []
	var n := 10
	for i in n + 1:
		var t := float(i) / float(n)
		var w := BLADE_W * 0.5 * sin(PI * pow(t, 0.7))   # x half-width at z = t * BLADE_LEN
		pts.append(Vector2(w, t * BLADE_LEN))
	for i in n:
		for side in [1.0, -1.0]:
			var a := pts[i]
			var b := pts[i + 1]
			for y in [0.011, -0.011]:
				var q := [Vector3(side * a.x, y, a.y), Vector3(side * b.x, y, b.y), Vector3(0.0, y * 1.3, a.y), Vector3(0.0, y * 1.3, b.y)]
				var tri := [q[0], q[1], q[3], q[0], q[3], q[2]]
				if (side > 0.0) != (y > 0.0):
					tri.reverse()
				for v: Vector3 in tri:
					st.set_uv(Vector2(v.x * 3.0, v.z * 2.0))
					st.add_vertex(v)
	st.generate_normals()
	return st.commit()
