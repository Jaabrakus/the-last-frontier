class_name RingCrowd
extends Node3D
## The crowd in the Tidebreak ring's stands (RingDressing builds it): low-poly fans seated along every tier of both
## stands, in three poses (arms down, arms up, a straw hat), each pose one MultiMesh (three draws for the whole crowd),
## swaying in the shader (shaders/ring/ring_crowd.gdshader): no per-frame work on the CPU. The clothes are a festival
## mix with the near side's colour worn more on its own half. set_cheer(0..1) is the stands' mood (a roar on a ring-out).

const SHADER := "res://shaders/ring/ring_crowd.gdshader"
## Seat pitch along a tier (m) and the share of seats taken.
const PITCH := 0.62
const FILL := 0.86

var material: ShaderMaterial
var count := 0
var _cheer := 0.25
var _cheer_to := 0.25


## Fans on the tiers of both stands. sd: ring.json "surround"; ox: half the stands' length; oz: the stands' front (local z);
## sides: [Color, Color] the two sides' colours; skip_x: x positions with a post on each tier (no one sits there).
static func make(parent: Node3D, sd: Dictionary, ox: float, oz: float, top_y: float, sides: Array, skip: Array) -> RingCrowd:
	var crowd := RingCrowd.new()
	crowd.name = "Crowd"
	parent.add_child(crowd)
	crowd._build(sd, ox, oz, top_y, sides, skip)
	return crowd


func set_cheer(v: float, instant := false) -> void:
	_cheer_to = clampf(v, 0.0, 1.0)
	if instant:
		_cheer = _cheer_to
		if material != null:
			material.set_shader_parameter(&"cheer", _cheer)


func _process(dt: float) -> void:
	if material == null or is_equal_approx(_cheer, _cheer_to):
		return
	_cheer = move_toward(_cheer, _cheer_to, dt * 0.8)
	material.set_shader_parameter(&"cheer", _cheer)


func _build(sd: Dictionary, ox: float, oz: float, top_y: float, sides: Array, skip: Array) -> void:
	material = ShaderMaterial.new()
	material.shader = load(SHADER)
	material.set_shader_parameter(&"cheer", _cheer)
	var tiers := int(sd.get("tiers", 6))
	var td := float(sd.get("tier_d", 0.9))
	var th := float(sd.get("tier_h", 0.5))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1776
	var poses: Array[Array] = [[], [], []]           # [Transform3D, Color, Color custom]
	var palette := [Color(0.82, 0.78, 0.68), Color(0.62, 0.14, 0.1), Color(0.16, 0.36, 0.22), Color(0.72, 0.52, 0.16),
			Color(0.2, 0.22, 0.32), Color(0.5, 0.3, 0.5), Color(0.88, 0.86, 0.8), Color(0.42, 0.26, 0.16), Color(0.1, 0.42, 0.5)]
	for s in 2:
		var sz := -1.0 if s == 0 else 1.0
		for i in tiers:
			var z := sz * (oz + td * float(i) + td * 0.55)
			var y := top_y + th * float(i + 1)
			var x := -ox + 0.45 + rng.randf() * 0.2
			while x < ox - 0.4:
				var here := x
				x += PITCH * rng.randf_range(0.85, 1.2)
				if rng.randf() > FILL:
					continue
				var blocked := false
				for sx: float in skip:
					if absf(here - sx) < 0.55:
						blocked = true
						break
				if blocked:
					continue
				# the near side's colours on its own half, a festival mix everywhere
				var side := 0 if here < 0.0 else 1
				var col: Color = palette[rng.randi() % palette.size()]
				var r := rng.randf()
				if r < 0.34:
					col = (sides[side] as Color).lerp(Color(rng.randf(), rng.randf(), rng.randf()), 0.12)
				elif r < 0.4:
					col = (sides[1 - side] as Color)
				col = col * rng.randf_range(0.82, 1.08)
				col.a = 1.0
				var yaw := (0.0 if sz < 0.0 else PI) + rng.randf_range(-0.25, 0.25) + clampf(-here / ox, -1.0, 1.0) * 0.25 * -sz
				var sc := rng.randf_range(0.92, 1.1)
				var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * sc), Vector3(here + rng.randf_range(-0.06, 0.06), y, z + rng.randf_range(-0.08, 0.05)))
				var energy := rng.randf()
				var pose := 0
				var pr := rng.randf()
				if pr < 0.08 + 0.2 * energy * energy:
					pose = 1
				elif pr > 0.84:
					pose = 2
				var custom := Color(rng.randf(), pow(rng.randf(), 1.4), energy, rng.randf())
				poses[pose].append([xf, col, custom])
	var meshes := [figure(false, false), figure(true, false), figure(false, true)]
	for p in 3:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = meshes[p]
		mm.instance_count = poses[p].size()
		for k in poses[p].size():
			var e: Array = poses[p][k]
			mm.set_instance_transform(k, e[0])
			mm.set_instance_color(k, e[1])
			mm.set_instance_custom_data(k, e[2])
		var mi := MultiMeshInstance3D.new()
		mi.name = ["Seated", "Cheering", "Hats"][p]
		mi.multimesh = mm
		mi.material_override = material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(mi)
		count += poses[p].size()


## One seated fan (y 0 the seat, facing local +Z): legs forward, a body, a head with hair (or a straw hat), the arms
## down by the sides or raised. UV.x the part (0 skin, 0.25 hair, 0.5 clothes, 0.7 legs, 0.9 straw), UV.y 1 on the arms.
static func figure(arms_up: bool, hat: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# legs: thighs forward, shins down over the tier's edge
	_box(st, Vector3(0.0, 0.08, 0.2), Vector3(0.34, 0.15, 0.4), 0.7, 0.0)
	_box(st, Vector3(0.0, -0.17, 0.38), Vector3(0.3, 0.38, 0.13), 0.7, 0.0)
	# the body: a little wider at the shoulders
	_taper(st, Vector3(0.0, 0.14, 0.0), 0.36, 0.44, 0.52, 0.24, 0.5)
	# the head (a rounded drum) and its hair
	_drum(st, Vector3(0.0, 0.66, 0.0), 0.09, 0.115, 0.1, 0.27, 0.0)
	if hat:
		_cone(st, Vector3(0.0, 0.88, 0.0), 0.3, 0.2, 0.9)
	else:
		_drum(st, Vector3(0.0, 0.9, -0.012), 0.112, 0.1, 0.05, 0.05, 0.25)
		_box(st, Vector3(0.0, 0.8, -0.085), Vector3(0.2, 0.17, 0.06), 0.25, 0.0)
	if arms_up:
		for sx: float in [-1.0, 1.0]:
			_box(st, Vector3(sx * 0.27, 0.92, 0.02), Vector3(0.1, 0.5, 0.11), 0.5, 1.0, Basis(Vector3.BACK, -sx * 0.32))
			_box(st, Vector3(sx * 0.36, 1.2, 0.02), Vector3(0.09, 0.1, 0.1), 0.0, 1.0)
	else:
		for sx: float in [-1.0, 1.0]:
			_box(st, Vector3(sx * 0.27, 0.42, 0.04), Vector3(0.1, 0.42, 0.12), 0.5, 0.0, Basis(Vector3.RIGHT, -0.35))
	st.generate_normals()
	return st.commit()


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, uv: Vector2) -> void:
	# a-b-c-d counter-clockwise seen from the front; Godot's front faces are clockwise
	for p: Vector3 in [a, c, b, a, d, c]:
		st.set_uv(uv)
		st.set_smooth_group(-1)
		st.add_vertex(p)


static func _box(st: SurfaceTool, c: Vector3, s: Vector3, part: float, arm: float, b := Basis()) -> void:
	var h := s * 0.5
	var p := func(x: float, y: float, z: float) -> Vector3: return c + b * Vector3(x * h.x, y * h.y, z * h.z)
	var uv := Vector2(part, arm)
	_quad(st, p.call(-1, -1, 1), p.call(1, -1, 1), p.call(1, 1, 1), p.call(-1, 1, 1), uv)       # +Z
	_quad(st, p.call(1, -1, -1), p.call(-1, -1, -1), p.call(-1, 1, -1), p.call(1, 1, -1), uv)   # -Z
	_quad(st, p.call(1, -1, 1), p.call(1, -1, -1), p.call(1, 1, -1), p.call(1, 1, 1), uv)       # +X
	_quad(st, p.call(-1, -1, -1), p.call(-1, -1, 1), p.call(-1, 1, 1), p.call(-1, 1, -1), uv)   # -X
	_quad(st, p.call(-1, 1, 1), p.call(1, 1, 1), p.call(1, 1, -1), p.call(-1, 1, -1), uv)       # +Y
	_quad(st, p.call(-1, -1, -1), p.call(1, -1, -1), p.call(1, -1, 1), p.call(-1, -1, 1), uv)   # -Y


## A box narrower at the foot (w0) than at the top (w1), h high, d deep, its foot centred on `base`.
static func _taper(st: SurfaceTool, base: Vector3, w0: float, w1: float, h: float, d: float, part: float) -> void:
	var uv := Vector2(part, 0.0)
	var a0 := base + Vector3(-w0 * 0.5, 0.0, d * 0.5)
	var b0 := base + Vector3(w0 * 0.5, 0.0, d * 0.5)
	var c0 := base + Vector3(w0 * 0.5, 0.0, -d * 0.5)
	var d0 := base + Vector3(-w0 * 0.5, 0.0, -d * 0.5)
	var a1 := base + Vector3(-w1 * 0.5, h, d * 0.5)
	var b1 := base + Vector3(w1 * 0.5, h, d * 0.5)
	var c1 := base + Vector3(w1 * 0.5, h, -d * 0.5)
	var d1 := base + Vector3(-w1 * 0.5, h, -d * 0.5)
	_quad(st, a0, b0, b1, a1, uv)
	_quad(st, c0, d0, d1, c1, uv)
	_quad(st, b0, c0, c1, b1, uv)
	_quad(st, d0, a0, a1, d1, uv)
	_quad(st, a1, b1, c1, d1, uv)


## A six-sided drum on `base`: radius r0 at the foot, r_mid at its middle, r1 at the top, h high, capped.
static func _drum(st: SurfaceTool, base: Vector3, r0: float, r_mid: float, r1: float, h: float, part: float) -> void:
	var n := 6
	var uv := Vector2(part, 0.0)
	var rings := [[0.0, r0], [h * 0.5, r_mid], [h, r1]]
	for k in 2:
		for i in n:
			var a0 := TAU * float(i) / float(n)
			var a1 := TAU * float(i + 1) / float(n)
			var lo: Array = rings[k]
			var hi: Array = rings[k + 1]
			var p0 := base + Vector3(cos(a0) * float(lo[1]), float(lo[0]), sin(a0) * float(lo[1]))
			var p1 := base + Vector3(cos(a1) * float(lo[1]), float(lo[0]), sin(a1) * float(lo[1]))
			var q0 := base + Vector3(cos(a0) * float(hi[1]), float(hi[0]), sin(a0) * float(hi[1]))
			var q1 := base + Vector3(cos(a1) * float(hi[1]), float(hi[0]), sin(a1) * float(hi[1]))
			for p: Vector3 in [p0, p1, q1, p0, q1, q0]:
				st.set_uv(uv)
				st.set_smooth_group(-1)
				st.add_vertex(p)
	var top := base + Vector3(0.0, h, 0.0)
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		for p: Vector3 in [top, top + Vector3(cos(a0) * r1, 0.0, sin(a0) * r1), top + Vector3(cos(a1) * r1, 0.0, sin(a1) * r1)]:
			st.set_uv(uv)
			st.set_smooth_group(-1)
			st.add_vertex(p)


## A low cone (a straw hat): radius r, height h, its rim at `base`.
static func _cone(st: SurfaceTool, base: Vector3, r: float, h: float, part: float) -> void:
	var n := 8
	var uv := Vector2(part, 0.0)
	var tip := base + Vector3(0.0, h, 0.0)
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		var p0 := base + Vector3(cos(a0) * r, 0.0, sin(a0) * r)
		var p1 := base + Vector3(cos(a1) * r, 0.0, sin(a1) * r)
		for p: Vector3 in [p0, p1, tip]:
			st.set_uv(uv)
			st.set_smooth_group(-1)
			st.add_vertex(p)
		for p: Vector3 in [base, p1, p0]:
			st.set_uv(uv)
			st.set_smooth_group(-1)
			st.add_vertex(p)
