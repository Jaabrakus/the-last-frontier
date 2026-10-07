class_name ThuyVanCards
extends RefCounted
## Thủy Vân's effect cards and simple meshes (shaders/thuyvan/tv_card.gdshader; PAINT's falls, spray, mist, foam rings,
## skyline cards in assets/thuyvan/paint/water/ and sky/), shared by ThuyVanWater (the falls) and ThuyVanDressing (mist,
## skyline). The look test's helpers (tools/thuyvan_look/look_test.gd), as statics:
##   ThuyVanCards.material("tv_fall_body.png", Vector2(0, -0.2), 1.7, 1.3, {"proximity_fade": 0.6})
##   ThuyVanCards.strip(parent, path, width, right, facing, mat, vrep)   # a ribbon through a centre line
##   ThuyVanCards.card(parent, bottom, top, width, facing, mat)          # a flat card
##   ThuyVanCards.quad(parent, at, size, mat)                            # a square card (billboards turn it)
##   ThuyVanCards.fall(parent, path, width, facing, rng)                 # a whole fall: body, streaks, edges, lip,
##                                                                       # spray, pool ring and mist at its foot
## Every card material is registered with ThuyVanLook, so its tint follows the light.

const Look := preload("res://scripts/thuyvan/look/thuyvan_look.gd")
const WATER := "res://assets/thuyvan/paint/water/"
const SKY := "res://assets/thuyvan/paint/sky/"
const SHADER := "res://shaders/thuyvan/tv_card.gdshader"
## A fall's cards hang 2-3 m off the rock: a short soft contact only, or the rock shows through them.
const FALL_FADE := {"proximity_fade": 0.6}


## A card material on `tex` (a file under WATER, or a res:// path): `scroll` UV/s, `alpha` and `strength` scales, any
## other uniforms in `extra`.
static func material(tex: String, scroll := Vector2.ZERO, alpha := 1.0, strength := 1.0, extra := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SHADER)
	m.set_shader_parameter("card_tex", load(tex if tex.begins_with("res://") else WATER + tex))
	m.set_shader_parameter("scroll", scroll)
	m.set_shader_parameter("alpha_scale", alpha)
	m.set_shader_parameter("strength", strength)
	for k: String in extra:
		m.set_shader_parameter(k, extra[k])
	Look.register_card(m)
	return m


static func mesh_instance(parent: Node, verts: PackedVector3Array, normals: PackedVector3Array, idx: PackedInt32Array,
		mat: Material, nm: String, colors := PackedColorArray(), uv := PackedVector2Array(),
		uv2 := PackedVector2Array()) -> MeshInstance3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = idx
	if not colors.is_empty():
		arrays[Mesh.ARRAY_COLOR] = colors
	if not uv.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = uv
	if not uv2.is_empty():
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## A card through `path` (its centre line, bottom to top), `width` m wide across `right`, facing `facing`; UV v 0 at the
## top, repeating `vrep`; u across, repeating `urep`.
static func strip(parent: Node, path: PackedVector3Array, width: float, right: Vector3, facing: Vector3, mat: Material,
		vrep := 1.0, urep := 1.0) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var segs := path.size() - 1
	for j in path.size():
		var t := float(j) / segs
		for i in 2:
			verts.append(path[j] + right.normalized() * (float(i) - 0.5) * width)
			normals.append(facing.normalized())
			uv.append(Vector2(float(i) * urep, (1.0 - t) * vrep))
	for j in segs:
		var a := j * 2
		idx.append_array([a, a + 2, a + 1, a + 1, a + 2, a + 3])
	var mi := mesh_instance(parent, verts, normals, idx, mat, "Card", PackedColorArray(), uv)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## A flat card from `bottom` up to `top`.
static func card(parent: Node, bottom: Vector3, top: Vector3, width: float, facing: Vector3, mat: Material, vrep := 1.0,
		urep := 1.0, segs := 1) -> MeshInstance3D:
	var path := PackedVector3Array()
	for j in segs + 1:
		path.append(bottom.lerp(top, float(j) / segs))
	return strip(parent, path, width, (top - bottom).cross(facing), facing, mat, vrep, urep)


## A square card of `size` m centred on `at`, facing +Z (billboards turn it).
static func quad(parent: Node, at: Vector3, size: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	parent.add_child(mi)
	return mi


## A whole fall down `path` (its centre line from the pool up to the lip, the last point the water coming over), `width`
## m wide, facing `facing` (out of the rock, toward who sees it): the body and streak ribbons, both edges' foam, a foam
## band across the lip, spray billboards and a foam ring at the foot, mist rising. Its materials: `mats` (shared between
## falls; made on first use).
static func fall(parent: Node, path: PackedVector3Array, width: float, facing: Vector3, rng: RandomNumberGenerator,
		mats: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Fall"
	parent.add_child(root)
	facing = facing.normalized()
	var right := Vector3.UP.cross(facing).normalized()
	var fall_h := path[path.size() - 1].y - path[0].y
	var vrep := maxf(fall_h / (width * 2.0), 0.5)
	var mpu := fall_h / vrep
	if mats.is_empty():
		mats["body"] = material("tv_fall_body.png", Vector2.ZERO, 1.7, 1.3, FALL_FADE)
		mats["streaks"] = material("tv_fall_streaks.png", Vector2.ZERO, 1.4, 1.35, FALL_FADE)
		mats["edge"] = material("tv_fall_edge_foam.png", Vector2.ZERO, 1.0, 1.1, FALL_FADE)
		mats["lip"] = material("tv_fall_edge_foam.png", Vector2(0.4, 0.0), 0.9, 1.1, FALL_FADE)
		mats["spray"] = material("tv_fall_spray.png", Vector2.ZERO, 0.9, 1.05,
				{"atlas_grid": Vector2(2, 2), "billboard": true, "proximity_fade": 6.0})
		mats["ring"] = material("tv_pool_foam_ring.png", Vector2.ZERO, 0.95, 1.05, {"proximity_fade": 0.0})
		mats["puffs"] = material("tv_mist_puffs.png", Vector2.ZERO, 0.7, 1.0,
				{"atlas_grid": Vector2(2, 2), "billboard": true, "proximity_fade": 8.0, "near_fade": 20.0})
	# each fall scrolls at its own metres per UV: its own copies of the scrolling materials
	var body := mats["body"].duplicate() as ShaderMaterial
	body.set_shader_parameter("scroll", Vector2(0.0, -0.8 / mpu))
	Look.register_card(body)
	var streaks := mats["streaks"].duplicate() as ShaderMaterial
	streaks.set_shader_parameter("scroll", Vector2(0.0, -1.4 / mpu))
	Look.register_card(streaks)
	var erep := maxf(fall_h / (width * 0.9), 0.5)
	var edge := mats["edge"].duplicate() as ShaderMaterial
	edge.set_shader_parameter("scroll", Vector2(0.0, -1.0 / (fall_h / erep)))
	Look.register_card(edge)
	strip(root, path, width, right, facing, body, vrep)
	strip(root, _offset(path, facing * 0.6), width * 0.85, right, facing, streaks, vrep * 1.3)
	for s in [-1.0, 1.0]:
		strip(root, _offset(path, right * s * width * 0.48 + facing * 1.0), width * 0.22, right, facing, edge, erep)
	var lip := path[path.size() - 2]
	card(root, lip + Vector3(0, -2.5, 0) + facing * 1.5, lip + Vector3(0, 1.2, 0) + facing * 0.5, width * 1.05, facing,
			mats["lip"], 1.0, 3.0)
	var foot := path[0]
	var sc := clampf(width / 20.0, 0.5, 1.6)
	for i in 6:
		var p := foot + right * rng.randf_range(-0.6, 0.6) * width + facing * rng.randf_range(3.0, 12.0) * sc \
				+ Vector3.UP * rng.randf_range(3.0, 12.0) * sc
		var c := quad(root, p, rng.randf_range(14.0, 24.0) * sc, mats["spray"])
		c.set_instance_shader_parameter("atlas_cell", float(i % 4))
	var rm := quad(root, foot + Vector3.UP * 0.6 + facing * 8.0 * sc, 30.0 * sc, mats["ring"])
	rm.rotation_degrees.x = -90.0
	for i in 4:
		var p := foot + right * rng.randf_range(-0.8, 0.8) * width + facing * rng.randf_range(6.0, 24.0) * sc \
				+ Vector3.UP * rng.randf_range(12.0, 30.0) * sc
		var c := quad(root, p, rng.randf_range(22.0, 36.0) * sc, mats["puffs"])
		c.set_instance_shader_parameter("atlas_cell", float((i + 1) % 4))
	return root


static func _offset(path: PackedVector3Array, by: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in path:
		out.append(p + by)
	return out
