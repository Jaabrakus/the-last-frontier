class_name RingCrowd
extends Node3D
## The crowd in the Tidebreak ring's stands (RingDressing builds it; round 4 SHOW, the round-2 review: "the crowd is flat
## cut-outs"): fans seated along every tier of both stands, built in code as figures (a head with a jaw and hair or a hat, a
## torso with shoulders and chest, two-segment arms with hands, seated thighs and shins), in six poses (sitting idle,
## leaning forward, arms up, clapping, standing and waving a cloth flag in its side's colour, sitting with a parasol or a
## straw hat), each pose one MultiMesh (one draw), and a lighter mesh of each pose for the far view (visibility ranges:
## lod_m from the crowd's middle, never both drawn: six draws in any view). Each fan's height and build varied by
## build_var; skin, hair and clothes from the festival palette, the near side's colour worn more on its own half (`sides`,
## which RingDressing passes); seeded, so the same crowd stands there on every load. Every number in data/ring/crowd.json.
## Lit like the world (shaders/ring/ring_crowd.gdshader): lambert with wrap, a sky and deck ambient by the mood
## (set_light), an occlusion term, the awnings' shadows and the lanterns at night. No outline, no cel bands.
## The motion is the shader's (no per-frame work per fan): this only eases a few of its numbers.
##   set_cheer(v)                  the stands' mood 0..1 (the classic ring's knock-backs and ring-outs)
##   react(kind, side, strength)   "launch" an ooh (heads up, a lean forward); "fall" the stands rise in a ripple outward
##                                 from the fall's end (`side`: 0 the -X end, 1 the +X end) and sit back over sit_s; "last_life"
##                                 half the crowd up a while; "sudden" half up and clapping on the score's beat
##                                 (MusicDirector.ring_beat, else its own clock at the score's tempo) till "calm"
## It never reads where a competitor is: a fall's end is all it is told.

const SHADER := "res://shaders/ring/ring_crowd.gdshader"
const DATA := "res://data/ring/crowd.json"
const POSES := ["idle", "lean", "arms_up", "clap", "flag", "parasol"]
## The parts (UV.x) and the arm marks (UV.y) the shader reads.
const SKIN := 0.0
const HAIR := 0.25
const CLOTH := 0.5
const TRIM := 0.62
const LEGS := 0.75
const STRAW := 0.88
const POLE := 0.95
const FLAG := 1.0
const CANOPY := 1.12
const HEAD := 2.0

static var _data := {}

var material: ShaderMaterial
var count := 0
## Fans per pose, and each pose's triangles (near mesh, far mesh) as built.
var per_pose := {}
var tris_near := {}
var tris_far := {}
## Every fan as placed, by pose: [Transform3D, clothes Color, custom Color] (the MultiMeshes hold the same; the tests read
## this, a headless server keeps no instance data).
var placed: Array = []
## The last reaction asked for (kind, side, strength; the tests read it).
var last_react := {}
var _cheer := 0.25
var _cheer_to := 0.25
var _ooh := 0.0
var _ooh_t := -1.0
var _ripple_t := -100.0
var _stand := 0.0
var _stand_to := 0.0
var _stand_until := -1.0
var _clap := 0.0
var _clap_to := 0.0
var _clock := 0.0
var _ox := 27.8


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(DATA, FileAccess.READ)
		var d: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
		_data = d if d is Dictionary else {}
	return _data


static func num(key: String, def := 0.0) -> float:
	return float(data().get(key, def))


static func react_num(key: String, def := 0.0) -> float:
	return float((data().get("react", {}) as Dictionary).get(key, def))


## Fans on the tiers of both stands. sd: ring.json "surround"; ox: half the stands' length; oz: the stands' front (local z);
## sides: [Color, Color] the two sides' colours; skip: x positions with a post on each tier (no one sits there).
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


## The sky and deck ambient for the mood (crowd.json light.moods: "noon", "golden", "night").
func set_light(mood: String) -> void:
	if material == null:
		return
	var moods: Dictionary = (data().get("light", {}) as Dictionary).get("moods", {})
	var m: Dictionary = moods.get(mood, moods.get("noon", {}))
	material.set_shader_parameter(&"sky_amb", _vec(m.get("sky"), Vector3(0.2, 0.24, 0.3)))
	material.set_shader_parameter(&"deck_amb", _vec(m.get("deck"), Vector3(0.16, 0.13, 0.09)))


## The sides' colours (a flag waves its own half's).
func set_sides(sides: Array) -> void:
	if material != null and sides.size() >= 2:
		material.set_shader_parameter(&"side_a", sides[0])
		material.set_shader_parameter(&"side_b", sides[1])


## A moment in the match (see the header). side: the end it happened at (0 -X, 1 +X; -1 none).
func react(kind: String, side := -1, strength := 1.0) -> void:
	last_react = {"kind": kind, "side": side, "strength": strength, "at": _clock}
	if material == null:
		return
	match kind:
		"launch":
			_ooh_t = 0.0
			_ooh = maxf(_ooh, clampf(strength, 0.0, 1.0))
		"fall":
			var end := -1.0 if side == 0 else 1.0
			material.set_shader_parameter(&"ripple_origin", to_global(Vector3(end * _ox, 0.0, 0.0)))
			material.set_shader_parameter(&"ripple_axis", global_basis.x.normalized())
			material.set_shader_parameter(&"ripple_k", clampf(strength, 0.0, 1.0))
			_ripple_t = 0.0
			material.set_shader_parameter(&"ripple_t", _ripple_t)
		"last_life":
			_stand_to = maxf(_stand_to, 1.0)
			_stand_until = _clock + react_num("last_life_s", 6.0)
		"sudden":
			_stand_to = 1.0
			_stand_until = INF
			_clap_to = 1.0
		"calm":
			_stand_to = 0.0
			_stand_until = -1.0
			_clap_to = 0.0


## A shader number now (the tests read the reactions).
func param(name: StringName) -> Variant:
	return material.get_shader_parameter(name) if material != null else null


func _process(dt: float) -> void:
	if material == null:
		return
	_clock += dt
	if not is_equal_approx(_cheer, _cheer_to):
		_cheer = move_toward(_cheer, _cheer_to, dt * 0.8)
		material.set_shader_parameter(&"cheer", _cheer)
	if _ooh_t >= 0.0:
		_ooh_t += dt
		var len := react_num("ooh_s", 1.6)
		var env := smoothstep(0.0, 0.15, _ooh_t) * (1.0 - smoothstep(0.35, len, _ooh_t))
		material.set_shader_parameter(&"ooh", _ooh * env)
		if _ooh_t >= len:
			_ooh_t = -1.0
			_ooh = 0.0
	if _ripple_t > -50.0:
		_ripple_t += dt
		material.set_shader_parameter(&"ripple_t", _ripple_t)
		var whole := react_num("rise_s", 0.35) + react_num("hold_s", 0.9) + react_num("sit_s", 3.0)
		if _ripple_t > whole + 2.0 * _ox / maxf(react_num("ripple_mps", 16.0), 0.1):
			_ripple_t = -100.0
			material.set_shader_parameter(&"ripple_t", _ripple_t)
			material.set_shader_parameter(&"ripple_k", 0.0)
	if _stand_until >= 0.0 and _clock >= _stand_until:
		_stand_to = 0.0
		_stand_until = -1.0
	if not is_equal_approx(_stand, _stand_to):
		_stand = move_toward(_stand, _stand_to, dt / maxf(react_num("stand_s", 0.8), 0.05))
		material.set_shader_parameter(&"stand", _stand)
	if not is_equal_approx(_clap, _clap_to):
		_clap = move_toward(_clap, _clap_to, dt * 2.0)
		material.set_shader_parameter(&"clap", _clap)
	if _clap > 0.0:
		material.set_shader_parameter(&"beat", beat_now())


## The beat the clap keeps: the ring's score's (MusicDirector.ring_beat), else this crowd's own clock at its tempo.
func beat_now() -> float:
	var md := get_tree().get_first_node_in_group(MusicDirector.GROUP) as MusicDirector if is_inside_tree() else null
	if md != null and md.ring_playing():
		return md.ring_beat()
	return _clock * react_num("bpm", 132.0) / 60.0


# ---------------------------------------------------------------- the build
func _build(sd: Dictionary, ox: float, oz: float, top_y: float, sides: Array, skip: Array) -> void:
	_ox = ox
	material = ShaderMaterial.new()
	material.shader = load(SHADER)
	material.set_shader_parameter(&"cheer", _cheer)
	var lt: Dictionary = data().get("light", {})
	material.set_shader_parameter(&"wrap", float(lt.get("wrap", 0.35)))
	material.set_shader_parameter(&"ao_k", float(lt.get("ao", 0.75)))
	var defs := {"ooh_lean": 0.32, "ripple_mps": 16.0, "rise_s": 0.35, "hold_s": 0.9, "sit_s": 3.0, "reach_m": 60.0,
			"stand_share": 0.5}
	for k: String in defs:
		material.set_shader_parameter(StringName(k), react_num(k, float(defs[k])))
	set_light("noon")
	set_sides(sides)
	var tiers := int(sd.get("tiers", 6))
	var td := float(sd.get("tier_d", 0.9))
	var th := float(sd.get("tier_h", 0.5))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(num("seed", 1776))
	var pitch := num("pitch_m", 0.62)
	var fill := num("fill", 0.86)
	var bv := num("build_var", 0.08)
	var share: Dictionary = data().get("pose_share", {})
	var cum: Array[float] = []
	var tot := 0.0
	for p: String in POSES:
		tot += float(share.get(p, 1.0))
		cum.append(tot)
	var palette: Array = []
	for c: Variant in data().get("palette", []):
		palette.append(Color(float(c[0]), float(c[1]), float(c[2])))
	if palette.is_empty():
		palette = [Color(0.82, 0.78, 0.68)]
	var hat_share := num("hat_share", 0.5)
	var side_share := num("side_share", 0.34)
	var other_share := num("other_side_share", 0.06)
	var poses: Array[Array] = [[], [], [], [], [], []]           # [Transform3D, Color, Color custom]
	for s in 2:
		var sz := -1.0 if s == 0 else 1.0
		for i in tiers:
			var z := sz * (oz + td * float(i) + td * 0.55)
			var y := top_y + th * float(i + 1)
			var x := -ox + 0.45 + rng.randf() * 0.2
			while x < ox - 0.4:
				var here := x
				x += pitch * rng.randf_range(0.85, 1.2)
				if rng.randf() > fill:
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
				if r < side_share:
					col = (sides[side] as Color).lerp(Color(rng.randf(), rng.randf(), rng.randf()), 0.12)
				elif r < side_share + other_share:
					col = (sides[1 - side] as Color)
				col = col * rng.randf_range(0.82, 1.08)
				col.a = float(side)
				var yaw := (0.0 if sz < 0.0 else PI) + rng.randf_range(-0.25, 0.25) + clampf(-here / ox, -1.0, 1.0) * 0.25 * -sz
				var hgt := 1.0 + rng.randf_range(-bv, bv)
				var bld := 1.0 + rng.randf_range(-bv, bv)
				var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(bld, hgt, bld))
				var xf := Transform3D(basis, Vector3(here + rng.randf_range(-0.06, 0.06), y, z + rng.randf_range(-0.08, 0.05)))
				var energy := rng.randf()
				var pr := rng.randf() * tot
				var pose := 0
				while pose < POSES.size() - 1 and pr > cum[pose]:
					pose += 1
				# (the lively ones more often up on their feet with a flag or their arms up)
				if pose == 0 and energy > 0.85 and rng.randf() < 0.5:
					pose = 2
				var hair := rng.randf() * 0.499
				if pose == 5 and rng.randf() < hat_share:
					hair += 0.5
				var custom := Color(rng.randf(), pow(rng.randf(), 1.4), energy, hair)
				poses[pose].append([xf, col, custom])
	placed = poses
	var lod := num("lod_m", 27.0)
	var margin := num("lod_margin_m", 1.5)
	var shadows := bool(data().get("shadows", true))
	for p in POSES.size():
		per_pose[POSES[p]] = poses[p].size()
		for far: bool in [false, true]:
			var st := figure(POSES[p], far)
			var arr := st.commit_to_arrays()
			var n_tris := (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			if far:
				tris_far[POSES[p]] = n_tris
			else:
				tris_near[POSES[p]] = n_tris
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.use_custom_data = true
			mm.mesh = mesh
			mm.instance_count = poses[p].size()
			for k in poses[p].size():
				var e: Array = poses[p][k]
				mm.set_instance_transform(k, e[0])
				mm.set_instance_color(k, e[1])
				mm.set_instance_custom_data(k, e[2])
			var mi := MultiMeshInstance3D.new()
			mi.name = POSES[p].capitalize().replace(" ", "") + ("Far" if far else "")
			mi.multimesh = mm
			mi.material_override = material
			mi.set_instance_shader_parameter(&"pose_id", float(p))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			mi.extra_cull_margin = 0.6               # (the shader stands them up and waves their arms past the mesh's box)
			if far:
				mi.visibility_range_begin = lod
				mi.visibility_range_begin_margin = margin
			else:
				mi.visibility_range_end = lod
				mi.visibility_range_end_margin = margin
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			add_child(mi)
		count += poses[p].size()


## The crowd's triangles (near meshes, or the far ones), every fan counted.
func triangles(far := false) -> int:
	var n := 0
	for p: String in POSES:
		n += int((tris_far if far else tris_near).get(p, 0)) * int(per_pose.get(p, 0))
	return n


static func _vec(v: Variant, def: Vector3) -> Vector3:
	if v is Array and (v as Array).size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return def


# ---------------------------------------------------------------- the figures
## One fan in `pose` (y 0 the seat, facing local +Z; `far` the lighter mesh): a SurfaceTool ready to commit (flat
## normals; UV the part and the arm, UV2 the occlusion and the body's weight: see the shader's header).
static func figure(pose: String, far := false) -> SurfaceTool:
	var f := _Fig.new(far)
	var standing := pose == "flag"
	# the legs: seated (thighs forward, shins down over the tier's edge) or standing in front of the seat
	if standing:
		for sx: float in [-1.0, 1.0]:
			f.limb(Vector3(sx * 0.1, 0.5, 0.18), Vector3(sx * 0.1, 0.06, 0.22), 0.075, 0.06, LEGS, 0.0, 0.0)
			f.limb(Vector3(sx * 0.1, 0.06, 0.22), Vector3(sx * 0.1, -0.37, 0.24), 0.06, 0.05, LEGS, 0.0, 0.0)
			if not far:
				f.box(Vector3(sx * 0.1, -0.385, 0.29), Vector3(0.1, 0.07, 0.2), LEGS, 0.0, 0.0)
	else:
		for sx: float in [-1.0, 1.0]:
			f.box(Vector3(sx * 0.1, 0.075, 0.22), Vector3(0.145, 0.15, 0.46), LEGS, 0.0, -1.0)
			f.box(Vector3(sx * 0.1, -0.18, 0.42), Vector3(0.115, 0.4, 0.12), LEGS, 0.0, 0.0)
			if not far:
				f.box(Vector3(sx * 0.1, -0.395, 0.48), Vector3(0.105, 0.07, 0.21), LEGS, 0.0, 0.0)
	# the upper body, seated or stood up (ub), leaning forward from the hips in the leaning pose
	var ub := Vector3(0.0, 0.43, 0.2) if standing else Vector3.ZERO
	var wt := 0.0 if standing else 1.0
	f.frame = Transform3D(Basis(Vector3.RIGHT, 0.42) if pose == "lean" else Basis(), Vector3(0.0, 0.08, 0.0)) \
			* Transform3D(Basis(), Vector3(0.0, -0.08, 0.0) + ub)
	f.box(Vector3(0.0, 0.1, 0.0), Vector3(0.32, 0.17, 0.22), LEGS, 0.0, wt)
	# the torso: the waist, the chest, the shoulders
	# (the torso's top hidden under the shoulders, the head's under the hair: not built)
	f.loft([[0.16, 0.15, 0.1, 0.0], [0.42, 0.185, 0.115, 0.01], [0.6, 0.2, 0.09, -0.005]], 6 if not far else 4, CLOTH, 0.0, wt,
			far, false)
	if not far:
		f.box(Vector3(0.0, 0.585, -0.005), Vector3(0.42, 0.07, 0.17), CLOTH, 0.0, wt)
		f.box(Vector3(0.0, 0.18, 0.0), Vector3(0.31, 0.05, 0.215), TRIM, 0.0, wt)
	# the neck and the head with its jaw; hair, or (the parasol pose) a straw hat too
	f.loft([[0.6, 0.05, 0.05, 0.01], [0.68, 0.048, 0.048, 0.015]], 6 if not far else 4, SKIN, HEAD, wt, false, false)
	f.loft([[0.65, 0.075, 0.08, 0.025], [0.76, 0.108, 0.112, 0.012], [0.88, 0.085, 0.09, 0.0]], 8 if not far else 4, SKIN,
			HEAD, wt, false, false)
	if not far:
		f.box(Vector3(0.0, 0.672, 0.07), Vector3(0.12, 0.05, 0.07), SKIN, HEAD, wt)
	f.loft([[0.77, 0.132, 0.135, -0.012], [0.885, 0.118, 0.12, -0.012], [0.94, 0.06, 0.06, -0.01]], 6 if not far else 4, HAIR,
			HEAD, wt, true, false)
	if not far:
		f.box(Vector3(0.0, 0.74, -0.075), Vector3(0.19, 0.13, 0.05), HAIR, HEAD, wt)
	if pose == "parasol":
		f.disc(Vector3(0.0, 0.9, -0.005), 0.25, 8 if not far else 6, STRAW, HEAD, wt)
		f.loft([[0.9, 0.11, 0.115, -0.005], [0.99, 0.09, 0.095, -0.005]], 8 if not far else 4, STRAW, HEAD, wt, true, false)
	# the arms (shoulder, elbow, wrist) and hands, by the pose
	var sh := 0.205
	for sx: float in [-1.0, 1.0]:
		var s := Vector3(sx * sh, 0.57, 0.0)
		var el := Vector3(sx * 0.23, 0.32, 0.08)
		var wr := Vector3(sx * 0.15, 0.2, 0.36)
		match pose:
			"lean":
				# (before the lean: the elbows land on the knees, the hands under the chin)
				el = Vector3(sx * 0.15, 0.31, 0.29)
				wr = Vector3(sx * 0.06, 0.67, 0.1)
			"arms_up":
				el = Vector3(sx * 0.31, 0.86, 0.05)
				wr = Vector3(sx * 0.27, 1.12, 0.08)
			"clap":
				el = Vector3(sx * 0.25, 0.37, 0.15)
				wr = Vector3(sx * 0.05, 0.56, 0.3)
			"flag":
				if sx > 0.0:
					el = Vector3(0.33, 0.83, 0.03)
					wr = Vector3(0.36, 1.08, 0.05)
				else:
					el = Vector3(-0.24, 0.32, 0.02)
					wr = Vector3(-0.25, 0.1, 0.06)
			"parasol":
				if sx > 0.0:
					el = Vector3(0.24, 0.34, 0.14)
					wr = Vector3(0.17, 0.47, 0.3)
		var held := (pose == "flag" and sx > 0.0)
		f.limb(s, el, 0.055, 0.045, CLOTH, 0.5 if not held else 1.0, wt)
		f.limb(el, wr, 0.045, 0.038, CLOTH if pose != "arms_up" else SKIN, 1.0, wt)
		var hd := (wr - el).normalized()
		if not far:
			f.box(wr + hd * 0.05, Vector3(0.06, 0.09, 0.05), SKIN, 1.0, wt, Basis.looking_at(hd, Vector3.FORWARD if absf(hd.y) > 0.9 else Vector3.UP))
	# what is held: the flag on its pole, the parasol
	if pose == "flag":
		var hand := Vector3(0.37, 1.13, 0.06)
		f.limb(hand + Vector3(0.0, -0.25, 0.0), hand + Vector3(0.02, 0.72, 0.0), 0.016, 0.014, POLE, 1.0, 0.0)
		var top := hand + Vector3(0.02, 0.7, 0.0)
		var nx := 3 if not far else 1
		var ny := 2 if not far else 1
		f.cloth(top, Vector3(0.6, 0.0, 0.0), Vector3(0.0, -0.38, 0.0), nx, ny, FLAG, 1.0)
	elif pose == "parasol":
		var grip := Vector3(0.17, 0.49, 0.31)
		var tip := Vector3(0.08, 1.28, 0.06)
		f.limb(grip + (grip - tip).normalized() * 0.08, tip, 0.012, 0.012, POLE, 0.0, wt)
		f.cone(tip + Vector3(0.0, 0.05, 0.0), tip + Vector3(0.0, -0.12, 0.0), 0.46, 8 if not far else 6, CANOPY, 0.0, wt)
	f.st.generate_normals()
	return f.st


## The builder: a SurfaceTool with the part, arm, occlusion and weight on each vertex, everything placed through `frame`
## (the upper body's lean and stand-up), each face wound so its front faces out (Godot's front faces are clockwise).
class _Fig:
	var st := SurfaceTool.new()
	var far := false
	var frame := Transform3D()

	func _init(p_far: bool) -> void:
		far = p_far
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	## The occlusion where a vertex ends up (figure space): the seat and the hips' contact, the feet under the tier, the
	## laps by the body, under the arms, under the jaw.
	static func ao(p: Vector3, part: float, arm: float) -> float:
		var a := 1.0
		a -= 0.45 * smoothstep(0.14, -0.02, p.y) * (1.0 - smoothstep(0.25, 0.5, p.z))
		a -= 0.4 * smoothstep(-0.12, -0.42, p.y)
		if part == LEGS and p.y > 0.1 and p.y < 0.2:
			a -= 0.3 * (1.0 - smoothstep(0.05, 0.3, p.z))
		if part == CLOTH and arm == 0.0 and absf(p.x) > 0.12 and p.y > 0.25 and p.y < 0.62:
			a -= 0.35
		if part == SKIN and arm == HEAD and p.y < 0.68:
			a -= 0.3
		return clampf(a, 0.15, 1.0)

	func _v(p: Vector3, part: float, arm: float, w: float) -> void:
		var q := frame * p
		var ww := w
		if w < 0.0:
			ww = 1.0 - clampf(q.z / 0.44, 0.0, 1.0)      # (a thigh: the hip end rises, the knee stays)
		st.set_uv(Vector2(part, arm))
		st.set_uv2(Vector2(ao(q, part, arm), ww))
		st.set_smooth_group(-1)
		st.add_vertex(q)

	## A triangle whose front faces away from `inside` (figure space, before `frame`).
	func tri(a: Vector3, b: Vector3, c: Vector3, inside: Vector3, part: float, arm: float, w: float) -> void:
		var n := (b - a).cross(c - a)
		if n.dot((a + b + c) / 3.0 - inside) < 0.0:
			var t := b
			b = c
			c = t
		for p: Vector3 in [a, c, b]:
			_v(p, part, arm, w)

	## Both faces of a triangle (cloth, a brim).
	func tri2(a: Vector3, b: Vector3, c: Vector3, part: float, arm: float, w: float) -> void:
		for p: Vector3 in [a, c, b, a, b, c]:
			_v(p, part, arm, w)

	func box(c: Vector3, s: Vector3, part: float, arm: float, w: float, b := Basis()) -> void:
		var h := s * 0.5
		var pts: Array[Vector3] = []
		for k in 8:
			pts.append(c + b * Vector3(h.x * (1.0 if k & 1 else -1.0), h.y * (1.0 if k & 2 else -1.0), h.z * (1.0 if k & 4 else -1.0)))
		for face: Array in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
			tri(pts[face[0]], pts[face[1]], pts[face[2]], c, part, arm, w)
			tri(pts[face[0]], pts[face[2]], pts[face[3]], c, part, arm, w)

	## Rings up the Y axis: levels [y, rx, rz, z offset], n sides, capped on top / at the foot.
	func loft(levels: Array, n: int, part: float, arm: float, w: float, top: bool, foot: bool) -> void:
		var rings: Array = []
		for lv: Array in levels:
			var ring: Array[Vector3] = []
			for i in n:
				var a := TAU * (float(i) + 0.5) / float(n)
				ring.append(Vector3(cos(a) * float(lv[1]), float(lv[0]), float(lv[3]) + sin(a) * float(lv[2])))
			rings.append(ring)
		for k in rings.size() - 1:
			var lo: Array = rings[k]
			var hi: Array = rings[k + 1]
			var mid := Vector3(0.0, (float(levels[k][0]) + float(levels[k + 1][0])) * 0.5, float(levels[k][3]))
			for i in n:
				var j := (i + 1) % n
				tri(lo[i], lo[j], hi[j], mid, part, arm, w)
				tri(lo[i], hi[j], hi[i], mid, part, arm, w)
		for e: Array in ([[rings[-1], levels[-1], 1.0]] if top else []) + ([[rings[0], levels[0], -1.0]] if foot else []):
			var ring: Array = e[0]
			var cc := Vector3(0.0, float(e[1][0]), float(e[1][3]))
			for i in n:
				tri(cc, ring[i], ring[(i + 1) % n], cc - Vector3(0.0, float(e[2]), 0.0), part, arm, w)

	## A tube from a to b (radii ra, rb), 4 sides near (3 far), open ends (the joints overlap).
	func limb(a: Vector3, b: Vector3, ra: float, rb: float, part: float, arm: float, w: float) -> void:
		var d := (b - a).normalized()
		var u := d.cross(Vector3.FORWARD if absf(d.z) < 0.9 else Vector3.RIGHT).normalized()
		var v := d.cross(u).normalized()
		var n := 4 if not far else 3
		var mid := (a + b) * 0.5
		for i in n:
			var a0 := TAU * float(i) / float(n)
			var a1 := TAU * float(i + 1) / float(n)
			var p0 := a + (u * cos(a0) + v * sin(a0)) * ra
			var p1 := a + (u * cos(a1) + v * sin(a1)) * ra
			var q0 := b + (u * cos(a0) + v * sin(a0)) * rb
			var q1 := b + (u * cos(a1) + v * sin(a1)) * rb
			tri(p0, p1, q1, mid, part, arm, w)
			tri(p0, q1, q0, mid, part, arm, w)

	## A flat disc (a hat's brim), both faces.
	func disc(c: Vector3, r: float, n: int, part: float, arm: float, w: float) -> void:
		for i in n:
			var a0 := TAU * float(i) / float(n)
			var a1 := TAU * float(i + 1) / float(n)
			tri2(c, c + Vector3(cos(a0) * r, 0.0, sin(a0) * r), c + Vector3(cos(a1) * r, 0.0, sin(a1) * r), part, arm, w)

	## A cone from `tip` to its rim round `base` (a parasol's canopy), both faces.
	func cone(tip: Vector3, base: Vector3, r: float, n: int, part: float, arm: float, w: float) -> void:
		for i in n:
			var a0 := TAU * float(i) / float(n)
			var a1 := TAU * float(i + 1) / float(n)
			tri2(tip, base + Vector3(cos(a0) * r, 0.0, sin(a0) * r), base + Vector3(cos(a1) * r, 0.0, sin(a1) * r), part, arm, w)

	## A cloth (a flag) from its corner `o` along u and v, nx by ny quads, both faces.
	func cloth(o: Vector3, u: Vector3, v: Vector3, nx: int, ny: int, part: float, arm: float) -> void:
		for i in nx:
			for j in ny:
				var p00 := o + u * (float(i) / nx) + v * (float(j) / ny)
				var p10 := o + u * (float(i + 1) / nx) + v * (float(j) / ny)
				var p01 := o + u * (float(i) / nx) + v * (float(j + 1) / ny)
				var p11 := o + u * (float(i + 1) / nx) + v * (float(j + 1) / ny)
				tri2(p00, p10, p11, part, arm, 0.0)
				tri2(p00, p11, p01, part, arm, 0.0)
