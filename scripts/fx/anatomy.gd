class_name Anatomy
extends Node3D
## The skeleton map under every body (user 2026-09-30, from a ragdoll video: "we dont need a x ray we just need a underlay where
## each person has a skeleton map"): bones, vertebrae, ribs, the spinal cord and the organs, procedural (no assets), each part
## riding the bone it belongs to, so it goes with the body: the animation, the ragdoll. Drawn over the body as a translucent
## underlay (N toggles it, Anatomy.shown).
##   humans    the player's rig (PlayerBody names: root, spinea .. heada, l_shoulder ..)
##   animals   the stand-in quadrupeds' shared rig (Back, Torso2, Neck1, FrontUpperLeg.L ..; bison, deer, wolf, fox)
## Wounds are mapped onto it: add_wound(point, direction, damage) lays the channel of the ball or the arrow through the body
## (a red line), and what it goes through is named in a label at the wound: "Heart, punctured", "Spinal cord, badly injured at
## T10", "T8 vertebra", "Rib 5 fractured".
## All sizes are metres: the skeleton's own scale (the animals' armature is 38x) is taken out in each part's transform.

## On or off for every body (N).
static var shown := false
## The hit-cam's slow-mo (off for films: the trailer sets it so).
static var slowmo_on := true

const BONE := Color(0.96, 0.94, 0.86, 0.5)
const CORD := Color(1.0, 0.92, 0.25, 0.85)
const WOUND := Color(0.92, 0.05, 0.05, 0.95)
## How far the body's skin fades while the map is shown (0 solid .. 1 gone).
const SKIN_FADE := 0.72
## How long a heart wound, or the cord high up, leaves a body on its feet (s) untreated.
## How fast each kind of wound loses blood against the base drain (PlayerWounds.DRAIN).
const FLESH_DRAIN := 0.7
const MORTAL_HEART_S := 8.0
const MORTAL_CORD_S := 12.0
## A brief slow-down of time on a mortal hit: scale and real seconds (not in headless runs or tests).
const SLOWMO := Vector2(0.3, 0.55)
## Organs, placed inside the body's own skin (the mesh's cross-section at their height, _slab): [name, colour, f (0 at the back ..
## 1 at the front/belly of that cross-section), side (of its half width), radii: along (m for a human, of the torso's length for
## an animal), depth (of the cross-section's depth), width (of its half width)].
## A human's are placed by real distance (m, for a 1.75 m body) down from the base of the neck; an animal's by a part of the way
## from the pelvis to the shoulders.
const ORGANS_HUMAN := [
	["Lung", Color(0.95, 0.55, 0.68, 0.72), 0.12, 0.5, 0.5, 0.12, 0.36, 0.38],
	["Lung", Color(0.95, 0.55, 0.68, 0.72), 0.12, 0.5, -0.5, 0.12, 0.36, 0.38],
	["Heart", Color(0.85, 0.06, 0.12, 0.88), 0.15, 0.66, 0.16, 0.055, 0.2, 0.2],
	["Liver", Color(0.5, 0.17, 0.11, 0.82), 0.26, 0.58, -0.4, 0.05, 0.22, 0.4],
	["Stomach", Color(0.9, 0.62, 0.3, 0.82), 0.26, 0.6, 0.4, 0.055, 0.2, 0.24],
	["Kidney", Color(0.55, 0.15, 0.2, 0.85), 0.34, 0.24, 0.4, 0.045, 0.1, 0.1],
	["Kidney", Color(0.55, 0.15, 0.2, 0.85), 0.34, 0.24, -0.4, 0.045, 0.1, 0.1],
	["Intestines", Color(0.92, 0.72, 0.62, 0.74), 0.43, 0.58, 0.0, 0.075, 0.3, 0.55],
]
const ORGANS := [
	["Heart", Color(0.85, 0.08, 0.14, 0.85), 0.78, 0.66, 0.0, 0.07, 0.22, 0.28],
	["Lung", Color(0.95, 0.55, 0.68, 0.72), 0.8, 0.4, 0.5, 0.15, 0.3, 0.38],
	["Lung", Color(0.95, 0.55, 0.68, 0.72), 0.8, 0.4, -0.5, 0.15, 0.3, 0.38],
	["Liver", Color(0.5, 0.18, 0.12, 0.82), 0.58, 0.5, -0.35, 0.09, 0.22, 0.36],
	["Stomach", Color(0.9, 0.62, 0.3, 0.82), 0.58, 0.55, 0.35, 0.1, 0.24, 0.34],
	["Kidney", Color(0.55, 0.16, 0.2, 0.85), 0.45, 0.22, 0.35, 0.05, 0.1, 0.12],
	["Kidney", Color(0.55, 0.16, 0.2, 0.85), 0.45, 0.22, -0.35, 0.05, 0.1, 0.12],
	["Intestines", Color(0.92, 0.72, 0.62, 0.74), 0.3, 0.55, 0.0, 0.14, 0.3, 0.5],
]
## Real human sizes (m, for 1.75 m): the skull's height.
const HUMAN_SKULL_H := 0.085

## The two rigs: spine (pelvis .. the neck's base), neck (to the head), head bone, bone segments [from, to] (a name to ""
## ends a limb a step past the last bone), the bones the limbs' roots are on.
const HUMAN := {
	"spine": ["root", "spinea", "spineb", "spined"],
	"neck": ["spined", "neck", "heada"],
	"head": "heada",
	"segments": [["neck", "l_shoulder"], ["l_shoulder", "l_elbow"], ["l_elbow", "l_wrist"], ["neck", "r_shoulder"],
			["r_shoulder", "r_elbow"], ["r_elbow", "r_wrist"], ["root", "l_upper_leg"], ["l_upper_leg", "l_knee"],
			["l_knee", "l_ankle"], ["l_ankle", "l_ball"], ["root", "r_upper_leg"], ["r_upper_leg", "r_knee"],
			["r_knee", "r_ankle"], ["r_ankle", "r_ball"]],
	"names": {"l_shoulder": "Left humerus", "l_elbow": "Left forearm", "r_shoulder": "Right humerus", "r_elbow": "Right forearm",
			"l_upper_leg": "Left femur", "l_knee": "Left shin", "r_upper_leg": "Right femur", "r_knee": "Right shin",
			"l_ankle": "Left foot", "r_ankle": "Right foot"},
	"up": ["root", "heada"],
}
const QUAD := {
	"spine": ["Back", "Torso", "Torso2", "Torso3"],
	"neck": ["Torso3", "Neck1", "Neck2", "Neck3", "Head"],
	"head": "Head",
	"segments": [["FrontShoulder.L", "FrontUpperLeg.L"], ["FrontUpperLeg.L", "FrontLowerLeg.L"], ["FrontLowerLeg.L", ""],
			["FrontShoulder.R", "FrontUpperLeg.R"], ["FrontUpperLeg.R", "FrontLowerLeg.R"], ["FrontLowerLeg.R", ""],
			["BackShoulder.L", "BackLeg.L"], ["BackLeg.L", "BackUpperLeg.L"], ["BackUpperLeg.L", "BackLowerLeg.L"],
			["BackLowerLeg.L", ""], ["BackShoulder.R", "BackLeg.R"], ["BackLeg.R", "BackUpperLeg.R"],
			["BackUpperLeg.R", "BackLowerLeg.R"], ["BackLowerLeg.R", ""], ["Tail1", "Tail2"], ["Tail2", "Tail3"]],
	"names": {"FrontUpperLeg.L": "Left foreleg", "FrontLowerLeg.L": "Left forehoof", "FrontUpperLeg.R": "Right foreleg",
			"FrontLowerLeg.R": "Right forehoof", "BackUpperLeg.L": "Left thigh", "BackLowerLeg.L": "Left hindleg",
			"BackUpperLeg.R": "Right thigh", "BackLowerLeg.R": "Right hindleg"},
	"up": ["Body", "Back"],
}

var skeleton: Skeleton3D
## The parts to test a wound against: {name, kind ("bone", "organ", "cord"), node, r (m), half (m, along its Y; 0 a ball)}.
var parts: Array[Dictionary] = []
var wounds: Array[Dictionary] = []
## What the last wound went through, in order from the entry: [{name, kind ("organ", "cord", "bone", "rib")}].
var last_hits: Array[Dictionary] = []
var human := false

var _rig: Dictionary
var _k := 1.0                               ## the skeleton's global scale
var _attach := {}                           ## bone index -> BoneAttachment3D
var _mat_cache := {}
var _up := Vector3.UP                       ## the body's up (skeleton space), its forward, its side
var _fwd := Vector3.FORWARD
var _side := Vector3.RIGHT
var _dorsal := Vector3.UP
var _torso_m := 0.5                         ## pelvis to the neck's base (m)
var _width_m := 0.3
var _tz := 1.0                              ## a human's torso length against a real one (the rig's is shorter)
var _floor := 0.0                           ## the skin's lowest point along the body's up (skeleton units)
var _skin: Array[Dictionary] = []           ## the body's skin for rays: {tri: TriangleMesh, to: the skeleton's rest frame to the mesh's own}
var _s := 1.0                               ## a human's size against a 1.75 m body


## An anatomy on `sk` (a human rig when it has a bone "spined", else a quadruped's), or null when the rig is not known.
static func attach_to(sk: Skeleton3D) -> Anatomy:
	var existing := sk.get_node_or_null(^"Anatomy") as Anatomy
	if existing:
		return existing
	var is_human := sk.find_bone("spined") >= 0 and sk.find_bone("heada") >= 0
	var rig: Dictionary = HUMAN if is_human else QUAD
	for bn: String in rig.spine:
		if sk.find_bone(bn) < 0:
			return null
	var a := Anatomy.new()
	a.name = "Anatomy"
	a.skeleton = sk
	a.human = is_human
	a._rig = rig
	sk.add_child(a)
	a._build()
	a.show_map(shown)
	return a


func _rest_pos(bone: String) -> Vector3:
	return skeleton.get_bone_global_rest(skeleton.find_bone(bone)).origin


func _along(names: Array, t: float) -> Vector3:
	var pts: Array[Vector3] = []
	for n: String in names:
		pts.append(_rest_pos(n))
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var at := t * total
	for i in pts.size() - 1:
		var l := pts[i].distance_to(pts[i + 1])
		if at <= l or i == pts.size() - 2:
			return pts[i].lerp(pts[i + 1], clampf(at / maxf(l, 1e-6), 0.0, 1.0))
		at -= l
	return pts[-1]


## The point `d` m (of the rig's own metres) down the spine from the neck's base, and the bone it lies on.
func _down(d: float) -> Array:
	var sp: Array = _rig.spine.duplicate()
	sp.reverse()                         # from the neck's base to the pelvis
	if human:
		sp.push_front("neck")
	var at := d / _k
	for i in sp.size() - 1:
		var a := _rest_pos(sp[i])
		var b := _rest_pos(sp[i + 1])
		var l := a.distance_to(b)
		if at <= l:
			return [a.lerp(b, at / maxf(l, 1e-6)), sp[i] if at < l * 0.5 else sp[i + 1]]
		at -= l
	var a2 := _rest_pos(sp[-2])
	var b2 := _rest_pos(sp[-1])
	return [b2 + (b2 - a2).normalized() * at, sp[-1]]


## The bone (of `names`) a point `t` along the chain rides.
func _bone_at(names: Array, t: float) -> String:
	var total := 0.0
	for i in names.size() - 1:
		total += _rest_pos(names[i]).distance_to(_rest_pos(names[i + 1]))
	var at := t * total
	for i in names.size() - 1:
		var l := _rest_pos(names[i]).distance_to(_rest_pos(names[i + 1]))
		if at <= l:
			return names[i] if at < l * 0.5 else names[i + 1]
		at -= l
	return names[-1]


func _build() -> void:
	var sb := skeleton.global_transform.basis
	_k = sb.get_scale().x
	var spine: Array = _rig.spine
	var pelvis := _rest_pos(spine[0])
	var shoulders := _rest_pos(spine[-1])
	_torso_m = maxf(pelvis.distance_to(shoulders) * _k, 0.1)
	# the body's axes in the skeleton's frame
	var upn: Array = _rig.up
	_up = (_rest_pos(upn[1]) - _rest_pos(upn[0])).normalized()
	if not human:
		# an animal's up: from its feet to its back (the rigs' own axes differ: the stand-ins are Z up, the bison Y up)
		var feet := Vector3.ZERO
		var nf := 0
		for fb in ["FrontLowerLeg.L", "FrontLowerLeg.R", "BackLowerLeg.L", "BackLowerLeg.R"]:
			if skeleton.find_bone(fb) >= 0:
				feet += _rest_pos(fb)
				nf += 1
		if nf > 0:
			_up = ((_rest_pos("Back") + _rest_pos("Torso2")) * 0.5 - feet / float(nf)).normalized()
	var along := (shoulders - pelvis).normalized()
	if human:
		# (a 1.75 m body: the head bone 1.5 m off the floor, the neck's base to the pelvis 0.53 m)
		_s = maxf(((_rest_pos("heada") - _rest_pos("l_ball")).dot(_up) * _k) / 1.5, 0.3)
		_tz = maxf((_rest_pos("neck") - _rest_pos("root")).length() * _k / 0.53, 0.3)
		var toe := _rest_pos("l_ball") - _rest_pos("l_ankle")
		_fwd = (toe - _up * toe.dot(_up)).normalized()
		_dorsal = -_fwd
	else:
		var head := _rest_pos(_rig.head) - pelvis
		_fwd = (head - _up * head.dot(_up)).normalized()
		_dorsal = _up
	_side = _fwd.cross(_up).normalized() if human else along.cross(_dorsal).normalized()
	_width_m = _torso_m * (0.6 if human else 0.55)
	_sample_skin()
	if human:
		_bone_parts_human()
	else:
		_bone_parts_quad()
	_spine_parts()
	_ribs()
	_organs()
	_skull()


# ---------------------------------------------------------------------------------------------------------------------
# Making parts


func _mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.render_priority = 40          # (depth-tested: it lies inside the body, the skin faded over it)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_cache[key] = m
	return m


func _attach_for(bone: String) -> BoneAttachment3D:
	var bi := skeleton.find_bone(bone)
	if bi < 0:
		return null
	if not _attach.has(bi):
		var ba := BoneAttachment3D.new()
		ba.name = "A_" + bone.replace(".", "_")
		add_child(ba)
		ba.use_external_skeleton = true
		ba.external_skeleton = ba.get_path_to(skeleton)
		ba.bone_idx = bi
		_attach[bi] = ba
	return _attach[bi]


## A mesh of `mesh` (metres) riding `bone`, at `at` (the rest pose's skeleton space) with `basis` (orthonormal, skeleton
## space), its metres kept by taking the skeleton's scale out of the transform.
func _part(mesh: Mesh, bone: String, at: Vector3, basis: Basis, c: Color, nm: String, kind: String, r: float, half: float,
		stretch := Vector3.ONE) -> MeshInstance3D:
	var ba := _attach_for(bone)
	if ba == null:
		return null
	var rest := skeleton.get_bone_global_rest(skeleton.find_bone(bone))
	var local := rest.affine_inverse() * Transform3D(basis, at)
	local.basis = local.basis.scaled(Vector3.ONE / _k) * Basis.from_scale(stretch)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c)
	mi.transform = local
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ba.add_child(mi)
	parts.append({"name": nm, "kind": kind, "node": mi, "r": r, "half": half, "rest": at, "basis": basis, "stretch": stretch})
	return mi


## A rod of radius `r` m from skeleton-space point `a` to `b`, on `bone`.
func _rod(a: Vector3, b: Vector3, bone: String, r: float, c: Color, nm: String, kind := "bone") -> void:
	var len_m := a.distance_to(b) * _k
	if len_m < 0.005:
		return
	var cap := CapsuleMesh.new()
	cap.radius = r
	cap.height = len_m + r * 2.0
	cap.radial_segments = 8
	cap.rings = 2
	var y := (b - a).normalized()
	_part(cap, bone, (a + b) * 0.5, _basis_y(y), c, nm, kind, r, len_m * 0.5)


func _ball(at: Vector3, bone: String, radii: Vector3, c: Color, nm: String, kind: String, basis := Basis.IDENTITY) -> MeshInstance3D:
	var sp := SphereMesh.new()
	sp.radius = 1.0
	sp.height = 2.0
	sp.radial_segments = 10
	sp.rings = 5
	return _part(sp, bone, at, basis, c, nm, kind, (radii.x + radii.y + radii.z) / 3.0, 0.0, radii)


## A basis (in the skeleton's frame) with Y along `y`.
func _basis_y(y: Vector3) -> Basis:
	var x := y.cross(_fwd if absf(y.dot(_fwd)) < 0.9 else _side).normalized()
	return Basis(x, y, x.cross(y).normalized())


func _bone_parts_human() -> void:
	var names: Dictionary = _rig.names
	for seg: Array in _rig.segments:
		var a := _rest_pos(seg[0])
		var b := _rest_pos(seg[1])
		var nm := String(names.get(seg[0], names.get(seg[1], "")))
		if nm == "":
			nm = "Collarbone" if String(seg[0]) == "neck" else ("Pelvis" if String(seg[0]) == "root" else "Bone")
		var r := clampf(a.distance_to(b) * _k * 0.03, 0.008, 0.018)
		_rod(a, b, seg[0], r, BONE, nm)
	# the pelvis: a bowl across the hips
	var hips := _rest_pos("root")
	_ball(hips - _up * (0.01 * _s) / _k, "root", Vector3(0.15, 0.065, 0.085) * _s, BONE, "Pelvis", "bone", Basis(_side, _up, _fwd).orthonormalized())


func _bone_parts_quad() -> void:
	var names: Dictionary = _rig.names
	for seg: Array in _rig.segments:
		var bone := String(seg[0])
		if skeleton.find_bone(bone) < 0:
			continue
		var a := _rest_pos(bone)
		var b: Vector3
		if String(seg[1]) == "":
			# the hoof: straight down from the last bone to the ground
			var down := maxf(a.dot(_up) - _floor, 0.04 / _k)
			b = a - _up * down
			if _skin.is_empty():
				var pi := skeleton.get_bone_parent(skeleton.find_bone(bone))
				b = a + (a - _rest_pos(skeleton.get_bone_name(pi))) * 0.9
		else:
			if skeleton.find_bone(seg[1]) < 0:
				continue
			b = _rest_pos(seg[1])
		var nm := String(names.get(bone, "Tail bone" if bone.begins_with("Tail") else "Leg bone"))
		var r := clampf(a.distance_to(b) * _k * 0.035, 0.006, 0.025)
		_rod(a, b, bone, r, BONE, nm)
	var pelvis := _rest_pos(_rig.spine[0])
	_ball(pelvis, _rig.spine[0], Vector3(_width_m * 0.28, _torso_m * 0.1, _torso_m * 0.1), BONE, "Pelvis", "bone",
			_basis_y(_dorsal))


## The body's skin for rays: a human's own skin meshes (head_Body, head_Face: not the clothes or the hair), an animal's the
## skinned mesh with the most vertices (the bind pose, the rig's rest pose).
func _sample_skin() -> void:
	var best: MeshInstance3D = null
	var best_n := 0
	var own: Array[MeshInstance3D] = []
	for mi in skeleton.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.skin == null or is_ancestor_of(m):
			continue
		if human and String(m.name).begins_with("head_"):
			own.append(m)
		var n := 0
		for si in m.mesh.get_surface_count():
			n += m.mesh.surface_get_array_len(si)
		if n > best_n:
			best_n = n
			best = m
	if not human or own.is_empty():
		own.clear()
		if best:
			own.append(best)
	_floor = INF
	for m in own:
		var to_sk := skeleton.global_transform.affine_inverse() * m.global_transform
		_skin.append({"tri": m.mesh.generate_triangle_mesh(), "to": to_sk.affine_inverse()})
		var bb := m.mesh.get_aabb()
		for i in 8:
			_floor = minf(_floor, (to_sk * bb.get_endpoint(i)).dot(_up))
	if _floor == INF:
		_floor = 0.0


## Distance to the first skin the ray from `from` along `dir` (skeleton space) meets, or INF.
func _shoot(from: Vector3, dir: Vector3) -> float:
	var best := INF
	for sk: Dictionary in _skin:
		var to: Transform3D = sk.to
		var f := to * from
		var d := (to.basis * dir).normalized()
		var hit: Dictionary = (sk.tri as TriangleMesh).intersect_ray(f, d)
		if hit.is_empty():
			continue
		best = minf(best, f.distance_to(hit.position as Vector3) * (to.basis.inverse() * d).length())
	return best


## The body's cross-section across `along` at `p` (skeleton space): {v0, v1: the skin's back and front along the ventral axis,
## relative to p; hw: its half width (skeleton units)}, from rays through p. Without skin: the torso's own proportions.
func _slab(p: Vector3, along: Vector3, dep_hint := -1.0) -> Dictionary:
	var ventral := -_dorsal
	var dep := _torso_m * (0.2 if human else 0.5) / _k
	var fallback := {"v0": -dep * 0.5, "v1": dep * 0.5, "hw": _width_m * 0.5 / _k}
	if _skin.is_empty():
		return fallback
	var far := 4.0 / _k
	# (the plane across `along` through p: ventral and side are taken square to it)
	var vdir := (ventral - along * ventral.dot(along)).normalized()
	var sdir := (_side - along * _side.dot(along)).normalized()
	var back := _shoot(p + (-vdir) * far, vdir)
	var front := _shoot(p + vdir * far, -vdir)
	if (back == INF or front == INF) and (dep_hint <= 0.0 or (back == INF and front == INF)):
		return fallback
	var v0 := -far + back                  # (along vdir from p: the back's coordinate)
	var v1 := far - front
	# (one side open, the face's hole in the skin: the depth it should have, from the side that is there)
	if back == INF:
		v0 = v1 - dep_hint
	elif front == INF:
		v1 = v0 + dep_hint
	if v1 - v0 < 0.02 / _k:
		return fallback
	var c := p + vdir * ((v0 + v1) * 0.5)
	var wl := _shoot(c + sdir * far, -sdir)
	var wr := _shoot(c - sdir * far, sdir)
	var hw := fallback.hw as float
	if wl != INF and wr != INF:
		hw = (far - wl + far - wr) * 0.5
	elif wl != INF or wr != INF:
		hw = far - minf(wl, wr)
	if human:
		# (the arms hang beside the chest: not past the shoulder)
		hw = minf(hw, maxf(absf(_rest_pos("l_shoulder").x - _rest_pos("root").x), 0.05) * 0.95)
	return {"v0": v0, "v1": v1, "hw": hw}


## The frame of a part along `along`: X across the body, Y along `along`, Z front/back.
func _frame(along: Vector3) -> Basis:
	var y := along.normalized()
	var x := (_side - y * _side.dot(y)).normalized()
	return Basis(x, y, x.cross(y).normalized())


## Vertebrae, C1..C7, T1..T12, L1..L5 from the head down to the pelvis, each riding the bone it lies on, set near the skin's
## back, and the cord in front of them.
func _spine_parts() -> void:
	var chain: Array = []
	var neck: Array = _rig.neck.duplicate()
	neck.reverse()
	chain.append_array(neck)
	var sp: Array = _rig.spine.duplicate()
	sp.reverse()
	for i in range(1, sp.size()):
		chain.append(sp[i])
	var ventral := -_dorsal
	var n := 24
	var prev := Vector3.ZERO
	for i in n:
		var t := float(i) / float(n - 1)
		var at := _along(chain, t)
		var bone := _bone_at(chain, t)
		var ax := _spine_dir(chain, t)
		var fit := _slab(at, ax)
		var dep: float = fit.v1 - fit.v0
		# (the vertebral body a fifth of the way from the back: the canal and the spine's process behind it)
		at += ventral * (float(fit.v0) + dep * (0.2 if human else 0.12))
		var nm := "C%d vertebra" % (i + 1) if i < 7 else ("T%d vertebra" % (i - 6) if i < 19 else "L%d vertebra" % (i - 18))
		var r := clampf(_torso_m * 0.03, 0.008, 0.03)
		if human:
			r = (0.013 + 0.012 * t) * _s
		r = minf(r, dep * _k * 0.16)
		var vm := _ball(at, bone, Vector3(r, r, r), BONE, nm, "bone")
		if vm:
			parts[-1].r = r * 1.3
		if i > 0:
			var cname := "Spinal cord, %s" % ("badly injured at " + nm.replace(" vertebra", ""))
			_rod(prev, at + ventral * (r * 0.9 / _k), bone, r * 0.4, CORD, cname, "cord")
		prev = at + ventral * (r * 0.9 / _k)


## The direction the spine runs at a point `t` along `names` (skeleton space).
func _spine_dir(names: Array, t: float) -> Vector3:
	var a := _along(names, clampf(t - 0.04, 0.0, 1.0))
	var b := _along(names, clampf(t + 0.04, 0.0, 1.0))
	var d := b - a
	return d.normalized() if d.length() > 1e-6 else _up


func _ribs() -> void:
	var spine: Array = _rig.spine
	var ventral := -_dorsal
	var n := 12 if human else 10
	for i in n:
		var k := float(i) / float(n - 1)
		var at: Vector3
		var bone: String
		var ax: Vector3
		if human:
			var f := _down((0.03 + 0.021 * float(i)) * _tz)
			at = f[0]
			bone = f[1]
			ax = _up
		else:
			var t := 0.55 + 0.42 * k
			at = _along(spine, t)
			bone = _bone_at(spine, t)
			ax = (_rest_pos(spine[-1]) - _rest_pos(spine[0])).normalized()
		var fit := _slab(at, ax)
		var dep: float = fit.v1 - fit.v0
		# narrow at the top, widest at the seventh, drawn in toward the last
		var taper := 0.6 + 0.4 * sin(PI * clampf(0.15 + k * 0.75, 0.0, 1.0))
		var centre := at + ventral * (float(fit.v0) + dep * 0.5)
		var tm := TorusMesh.new()
		tm.inner_radius = 0.475
		tm.outer_radius = 0.5
		tm.rings = 16
		tm.ring_segments = 5
		var w := float(fit.hw) * 0.86 * taper * _k
		var d := dep * 0.42 * taper * _k
		_part(tm, bone, centre, _frame(ax), BONE, "Rib %d" % (i + 1), "rib", w * 0.1, 0.0, Vector3(w * 2.0, 0.5, d * 2.0))


func _organs() -> void:
	var spine: Array = _rig.spine
	var ventral := -_dorsal
	for o: Array in (ORGANS_HUMAN if human else ORGANS):
		var at: Vector3
		var bone: String
		var ax: Vector3
		var along_m: float
		if human:
			var f := _down(float(o[2]) * _tz)
			at = f[0]
			bone = f[1]
			ax = _up
			along_m = float(o[5]) * _tz
		else:
			at = _along(spine, float(o[2]))
			bone = _bone_at(spine, float(o[2]))
			ax = (_rest_pos(spine[-1]) - _rest_pos(spine[0])).normalized()
			along_m = float(o[5]) * _torso_m
		var fit := _slab(at, ax)
		var dep: float = fit.v1 - fit.v0
		var hw: float = fit.hw
		var centre := at + ventral * (float(fit.v0) + dep * float(o[3])) + _side * (float(o[4]) * hw)
		# (radii in metres: across, along, front to back; kept inside the skin)
		var rx := minf(float(o[7]) * hw * _k, maxf(hw * (1.0 - absf(float(o[4]))) * _k * 0.95, 0.01))
		var rz := float(o[6]) * dep * _k
		_ball(centre, bone, Vector3(rx, along_m, rz), o[1], String(o[0]), "organ", _frame(ax))


func _skull() -> void:
	var head_bone: String = _rig.head
	var h := _rest_pos(head_bone)
	var neck: Array = _rig.neck
	var dir := (h - _rest_pos(neck[-2])).normalized()
	var ventral := -_dorsal
	if human:
		# the skull round the brain, real size (the skin over the face is open, rays do not read it): its middle a hand above the
		# head bone and a little forward, the jaw under it
		var c := h + dir * (0.10 * _s) / _k + _fwd * (0.045 * _s) / _k
		var rx := 0.068 * _s
		var ry := 0.095 * _s
		var rz := 0.078 * _s
		_ball(c, head_bone, Vector3(rx, ry, rz), Color(0.96, 0.94, 0.86, 0.22), "Skull", "bone", _frame(dir))
		_ball(c, head_bone, Vector3(rx * 0.78, ry * 0.8, rz * 0.78), Color(0.93, 0.66, 0.74, 0.7), "Brain", "organ", _frame(dir))
		_ball(h + _fwd * (0.06 * _s) / _k - dir * (0.005 * _s) / _k, head_bone, Vector3(rx * 0.6, 0.03 * _s, rz * 0.55), BONE, "Jaw", "bone", _frame(dir))
	else:
		var hm := _torso_m * 0.22
		var to := _fwd * hm * 1.5 / _k
		_rod(h, h + to, head_bone, hm * 0.32, BONE, "Skull", "bone")
		_ball(h + to * 0.15, head_bone, Vector3(hm * 0.22, hm * 0.28, hm * 0.25), Color(0.93, 0.74, 0.8, 0.85), "Brain", "organ", _frame(_fwd))

# ---------------------------------------------------------------------------------------------------------------------
# Wounds


## The channel of a ball or an arrow that struck at `point` going `direction` (world), through the body as far as `reach` m:
## a red line in the underlay and a label at the wound naming what it passes through. `damage` sets the labels' words.
## Returns the label's lines.
func add_wound(point: Vector3, direction: Vector3, damage := 50.0, reach := -1.0) -> Array[String]:
	var dir := direction.normalized() if direction.length_squared() > 1e-8 else Vector3.DOWN
	if reach < 0.0:
		reach = clampf(_torso_m * 0.9, 0.3, 1.2)
	var end := point + dir * reach
	var hits: Array[Dictionary] = []
	for p: Dictionary in parts:
		var node := p.node as MeshInstance3D
		if not is_instance_valid(node):
			continue
		var centre := node.global_position
		var half := float(p.half)
		var d: float
		if p.kind == "rib":
			# a ring round the spine: struck where the channel enters at its rim
			var lp: Vector3 = node.global_transform.affine_inverse() * point
			var radial := Vector2(lp.x, lp.z).length()
			if absf(radial - 0.46) < 0.13 and absf(lp.y) < 0.12:
				hits.append({"p": p, "d": 0.0, "t": 0.0})
			continue
		if half > 0.0:
			var ax := node.global_basis.y.normalized()
			d = _seg_dist(point, end, centre - ax * half, centre + ax * half)
		else:
			d = _seg_point_dist(point, end, centre)
		var r := float(p.r) * (1.25 if p.kind == "organ" else 1.1)
		if d <= r:
			hits.append({"p": p, "d": d, "t": clampf((centre - point).dot(dir) / reach, 0.0, 1.0)})
	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.t) < float(b.t))
	var lines: Array[String] = []
	var seen := {}
	for h in hits:
		var p: Dictionary = h.p
		var nm := String(p.name)
		if seen.has(nm) and p.kind != "organ":
			continue
		seen[nm] = true
		match String(p.kind):
			"organ":
				lines.append("%s, %s" % [nm, "punctured" if damage > 30.0 else "grazed"])
			"cord":
				lines.append(nm if damage > 30.0 else nm.replace("badly injured", "bruised"))
			_:
				lines.append("%s, %s" % [nm, "fractured" if damage > 30.0 else "chipped"] if not nm.contains("vertebra") else nm)
		if lines.size() >= 5:
			break
	last_hits.clear()
	for h in hits:
		last_hits.append({"name": String((h.p as Dictionary).name), "kind": String((h.p as Dictionary).kind)})
	_wound_line(point, end)
	_wound_label(point, lines)
	wounds.append({"point": point, "dir": dir, "lines": lines})
	return lines


## What a wound that went through `hits` (Anatomy.last_hits) does, for a blow of `damage`: {
##   lethal      dies at once (the brain)
##   drain_mult  how fast the blood goes (x PlayerWounds.DRAIN): the heart and lungs fast, the liver and kidneys steady, the stomach
##               and gut slow, a flesh wound slower still, so a body shot always bleeds, at the pace of what it went through
##   mortal_s    a mortal wound: dead in this many seconds, on their feet till then (the heart 8, the cord high up 12; treatment stretches it: PlayerWounds)
##   dmg_mult    x the blow's damage (what it tore through)
##   bleed_mult  x the blood it loses after
##   legs        the cord below the shoulders is cut: the legs are gone (a human is down for good, an animal drops)
##   limb        a limb bone broken ("" none): the bone's name
##   kind        an animal's wound kind (WildlifeSpecies.WOUNDS: heart, lungs, spine, head, gut, leg) the worst part gives, "" none
##   why         the part that decided it }
static func effect(hits: Array, damage: float) -> Dictionary:
	var out := {"lethal": false, "mortal_s": 0.0, "dmg_mult": 1.0, "bleed_mult": 1.0, "drain_mult": -1.0, "legs": false, "limb": "", "kind": "", "why": ""}
	var rank := {"": 0, "graze": 1, "leg": 2, "gut": 3, "lungs": 4, "head": 5, "spine": 6, "heart": 7}
	var serious := damage >= 25.0
	var levels: Array[int] = []
	var organ_dr := -1.0                # (what an organ or the cord does sets the pace; a bone only if none was hit)
	var other_dr := -1.0
	for h: Dictionary in hits:
		var nm := String(h.name)
		var kind := ""
		var dm := 1.0
		var bm := 1.0
		var dr := FLESH_DRAIN
		match String(h.kind):
			"organ":
				match nm:
					"Heart":
						kind = "heart"
						dm = 2.0
						bm = 2.5
						dr = 3.0
						if serious:
							out.mortal_s = maxf(float(out.mortal_s), MORTAL_HEART_S)
					"Brain":
						kind = "head"
						dm = 2.5
						if serious:
							out.lethal = true
					"Lung":
						kind = "lungs"
						dm = 1.4
						bm = 1.8
						dr = 1.7
					"Liver", "Kidney":
						kind = "gut"
						dm = 1.3
						bm = 2.0
						dr = 1.3
					_:
						kind = "gut"
						bm = 1.5
						dr = 0.5
			"cord":
				kind = "spine"
				dm = 1.5
				dr = 1.0
				levels.append(_level(nm.get_slice("injured at ", 1)))
			"bone":
				if nm == "Skull":
					kind = "head"
					dm = 1.5
				elif nm.contains("vertebra"):
					# (a ball through a vertebra goes through the canal behind it: the cord at that level)
					kind = "spine" if serious else ""
					dm = 1.5
					levels.append(_level(nm.get_slice(" ", 0)))
				elif nm != "Pelvis" and nm != "Jaw":
					kind = "leg"
					if serious:
						out.limb = nm
		if int(rank.get(kind, 0)) > int(rank.get(String(out.kind), 0)):
			out.kind = kind
			out.why = nm
		out.dmg_mult = maxf(float(out.dmg_mult), dm)
		out.bleed_mult = maxf(float(out.bleed_mult), bm)
		if String(h.kind) == "organ" or String(h.kind) == "cord":
			organ_dr = maxf(organ_dr, dr)
		else:
			other_dr = maxf(other_dr, dr)
	out.dmg_mult = minf(float(out.dmg_mult), 3.0)
	out.drain_mult = organ_dr if organ_dr >= 0.0 else (other_dr if other_dr >= 0.0 else FLESH_DRAIN)   # (nothing of note: flesh)
	# (the cord at the middle of the levels it went through: the neck and the chest down to T6, the breath goes with it, and it
	# is over; below that the legs go)
	if serious and not levels.is_empty():
		levels.sort()
		var lvl: int = levels[levels.size() / 2]
		if lvl <= 13:
			out.mortal_s = maxf(float(out.mortal_s), MORTAL_CORD_S)
		else:
			out.legs = true
	return out


## A vertebra's number down the whole column: C1..C7 1..7, T1..T12 8..19, L1..L5 20..24 ("T10" -> 17).
static func _level(tag: String) -> int:
	var n := int(tag.substr(1))
	if tag.begins_with("C"):
		return n
	if tag.begins_with("T"):
		return 7 + n
	return 19 + n


## The nearest part's bone takes the channel (it moves with it).
func _nearest_attach(world: Vector3) -> BoneAttachment3D:
	var best: BoneAttachment3D = null
	var best_d := INF
	for bi: int in _attach:
		var ba := _attach[bi] as BoneAttachment3D
		var d := ba.global_position.distance_to(world)
		if d < best_d:
			best_d = d
			best = ba
	return best


func _wound_line(a: Vector3, b: Vector3) -> void:
	var ba := _nearest_attach(a)
	if ba == null:
		return
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.008
	cyl.bottom_radius = 0.008
	cyl.height = a.distance_to(b)
	cyl.radial_segments = 6
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.material_override = _mat(WOUND)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ba.add_child(mi)
	var y := (b - a).normalized()
	var x := y.cross(Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD).normalized()
	var w := Transform3D(Basis(x, y, x.cross(y).normalized()), (a + b) * 0.5)
	mi.transform = ba.global_transform.affine_inverse() * w


func _wound_label(at: Vector3, lines: Array[String]) -> void:
	if lines.is_empty():
		return
	var ba := _nearest_attach(at)
	if ba == null:
		return
	var l := Label3D.new()
	l.text = "\n".join(lines)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true          # (a label reads through the body)
	l.fixed_size = true
	l.pixel_size = 0.0006
	l.font_size = 26
	l.outline_size = 8
	l.modulate = Color(1, 1, 1, 0.95)
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.render_priority = 60
	ba.add_child(l)
	# (on the parent's scale: world metres, offset a little off the body)
	l.transform = Transform3D(Basis.from_scale(Vector3.ONE / _k), ba.global_transform.affine_inverse() * (at + Vector3.UP * 0.12))


static func _seg_point_dist(a: Vector3, b: Vector3, p: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Closest distance between segments a0-a1 and b0-b1.
static func _seg_dist(a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3) -> float:
	var u := a1 - a0
	var v := b1 - b0
	var w := a0 - b0
	var a := u.dot(u)
	var b := u.dot(v)
	var c := v.dot(v)
	var d := u.dot(w)
	var e := v.dot(w)
	var den := a * c - b * b
	var s := 0.0
	var t := 0.0
	if den > 1e-9:
		s = clampf((b * e - c * d) / den, 0.0, 1.0)
	t = clampf((b * s + e) / maxf(c, 1e-9), 0.0, 1.0)
	s = clampf((b * t - d) / maxf(a, 1e-9), 0.0, 1.0)
	return (a0 + u * s).distance_to(b0 + v * t)


## Every body's underlay on or off (the N key); bodies built since follow.
static func set_shown(on: bool, tree: SceneTree, fade_s := 0.0) -> void:
	shown = on
	for n in tree.get_nodes_in_group(&"anatomy"):
		(n as Anatomy).show_map(on, fade_s)


## The map on or off for this body: the body's skin fades so it can be seen inside (and comes back). `fade_s` > 0: it comes
## in (or goes) over that long (a film's), the parts' own transparency with the skin's.
func show_map(on: bool, fade_s := 0.0) -> void:
	visible = on or fade_s > 0.0
	var skin: Array[MeshInstance3D] = []
	for mi in skeleton.find_children("*", "MeshInstance3D", true, false):
		if not is_ancestor_of(mi):
			skin.append(mi as MeshInstance3D)
	for g in skin:
		if on and not g.has_meta(&"anatomy_was"):
			g.set_meta(&"anatomy_was", g.transparency)
	var apply := func(k: float) -> void:
		# k 0 .. 1 toward the map shown
		for g in skin:
			if is_instance_valid(g) and g.has_meta(&"anatomy_was"):
				var was := float(g.get_meta(&"anatomy_was"))
				g.transparency = lerpf(was, maxf(was, SKIN_FADE), k)
		for d in parts:
			if is_instance_valid(d.node):
				(d.node as GeometryInstance3D).transparency = 1.0 - k
		if k <= 0.0:
			visible = false
			for g in skin:
				if is_instance_valid(g) and g.has_meta(&"anatomy_was"):
					g.remove_meta(&"anatomy_was")
	if fade_s > 0.0 and is_inside_tree():
		var tw := create_tween()
		tw.tween_method(apply, 0.0 if on else 1.0, 1.0 if on else 0.0, fade_s)
	else:
		apply.call(1.0 if on else 0.0)


func _enter_tree() -> void:
	add_to_group(&"anatomy")


## Time slows for SLOWMO.y real seconds (a clean kill, a mortal wound): the hit seen. Not headless.
static func slowmo(tree: SceneTree) -> void:
	if not slowmo_on or tree == null or DisplayServer.get_name() == "headless" or Engine.time_scale < 0.99:
		return
	Engine.time_scale = SLOWMO.x
	tree.create_timer(SLOWMO.y, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)


## The wound report: the lines a channel went through, as one line ("Heart, punctured  ·  Lung, punctured").
static func report(lines: Array) -> String:
	return "  ·  ".join(lines.slice(0, 3))
