class_name BodyBuild
extends RefCounted
## Fits a body model (BodyModel) to a rig and its skin (the user, 2026-10-03: hit detection and damage off an anatomically
## accurate body, "they have a perfect skeleton mesh"). Each shape is sized as the real one for a grown man (1.75 m; scaled by
## the rig's own height, _s) or a grown animal (by its trunk's length), set in the rig's rest pose and laid against the body's
## own skin where that matters: the trunk's cross-section at each height from rays on the skin meshes (_slab, as Anatomy's
## organs were), so the spine lies under the back, the ribs inside the chest wall, the sternum under the front; the limbs'
## flesh from rays across them. Built once per kind of body (BodyModel.of caches it); nothing of it runs after.
##
##   humans    the player's and the fighters' rig (Actor_B: root, pelvis, spinea..spined, neck, heada, headb, jaw, l_clavicle,
##             l_scapula, l_shoulder, l_elbow, l_wrist, l_palm and the fingers, l_upper_leg, l_knee, l_ankle, l_heel, l_ball)
##             skull (a shell round the brain), the face's bones, the jaw, C1-C7, T1-T12, L1-L5 (body, arch, processes),
##             the sacrum, the ribs 1-12 each side (each an arc of capsules round the chest wall, 8-10 to the costal margin,
##             11-12 floating), the sternum, the clavicles, the scapulae, the humerus, radius and ulna, the hand's bones, the
##             pelvis (ilium, acetabulum, pubis, ischium), the femur, kneecap, tibia and fibula, the foot's bones; the brain,
##             brainstem and cord (C1 to L5: the cauda below L2), the organs; the vessels: the aorta, the carotids, the
##             subclavian, brachial, radial and ulnar arteries, the iliac, femoral and popliteal arteries; the venae cavae,
##             the jugulars, the subclavian, brachial, iliac, femoral and popliteal veins; the flesh: head, neck, the trunk in
##             slabs, each limb
##   animals   the stand-in quadrupeds' rig (Back, Torso..Torso3, Neck1..3, Head, the legs' .L/.R chains: deer, bison, wolf, fox)
##             at the level Anatomy had for them: skull, brain and brainstem, C1-C7, T1-T13, L1-L6, the cord, the ribs 1-13, the
##             sternum, the scapulae, the pelvis and sacrum, each leg's bones (humerus, radius, fore cannon; femur, tibia, hind
##             cannon), the organs, the carotids and jugulars, the aorta and vena cava, the femoral and brachial vessels, flesh

const BONE := Color(0.95, 0.93, 0.85)
const CORD := Color(1.0, 0.86, 0.3)
const ARTERY := Color(0.86, 0.1, 0.1)
const VEIN := Color(0.2, 0.35, 0.9)
const FLESH := Color(0.8, 0.6, 0.55)
## Organs: colour and tissue.
const ORGAN := {
	"Brain": [Color(0.93, 0.7, 0.76), "brain"], "Brainstem": [Color(0.9, 0.66, 0.6), "brain"],
	"Left lung": [Color(0.96, 0.62, 0.7), "lung"], "Right lung": [Color(0.96, 0.62, 0.7), "lung"],
	"Heart": [Color(0.86, 0.12, 0.16), "organ"], "Liver": [Color(0.55, 0.2, 0.14), "organ"],
	"Stomach": [Color(0.92, 0.68, 0.38), "gut"], "Spleen": [Color(0.5, 0.18, 0.32), "organ"],
	"Left kidney": [Color(0.6, 0.18, 0.22), "organ"], "Right kidney": [Color(0.6, 0.18, 0.22), "organ"],
	"Intestines": [Color(0.94, 0.76, 0.64), "gut"],
}
## A bone's break (J a lead ball spends breaking through it), by its kind.
const BRK := {"femur": 120.0, "femur_end": 85.0, "tibia": 90.0, "tibia_end": 70.0, "fibula": 25.0, "humerus": 70.0,
		"humerus_end": 50.0, "radius": 30.0, "ulna": 30.0, "hand": 8.0, "foot": 18.0, "kneecap": 20.0, "clavicle": 25.0,
		"scapula": 20.0, "rib": 8.0, "sternum": 15.0, "vertebra_c": 30.0, "vertebra": 50.0, "arch": 15.0, "sacrum": 40.0,
		"ilium": 25.0, "acetabulum": 60.0, "pubis": 25.0, "skull": 45.0, "face": 30.0, "jaw": 30.0, "cannon": 70.0}

var sk: Skeleton3D
var m: BodyModel
var human := false
var k := 1.0
## The body's axes in the skeleton's frame: up (feet to head; an animal's feet to back), forward (where it faces), left.
var up := Vector3.UP
var fwd := Vector3.BACK
var left := Vector3.RIGHT
## A human's size against a 1.75 m man; an animal's trunk length (m) against a doe's (0.72 m).
var s := 1.0
var _skin: Array[Dictionary] = []          ## {tri: TriangleMesh, to: the skeleton's frame to the mesh's own}
var _floor := 0.0                           ## the skin's lowest along up (skeleton units)
var _corners: Array[Vector3] = []           ## the skin's bounds' corners (skeleton frame)
var _torso_m := 0.5
var _width_m := 0.3
var _dorsal := Vector3.UP


## A model of the body on `sk` (a human rig: bones "spined" and "heada"; else a quadruped's: "Back", "Torso3", "Head"), or
## null for a rig it does not know.
static func make(p_sk: Skeleton3D) -> BodyModel:
	var bb := BodyBuild.new()
	bb.sk = p_sk
	bb.human = p_sk.find_bone("spined") >= 0 and p_sk.find_bone("heada") >= 0 and p_sk.find_bone("l_upper_leg") >= 0
	if not bb.human:
		for bn: String in ["Back", "Torso", "Torso2", "Torso3", "Head"]:
			if p_sk.find_bone(bn) < 0:
				return null
	bb.m = BodyModel.new()
	bb.m.human = bb.human
	bb.k = p_sk.global_transform.basis.get_scale().x
	bb.m.k = bb.k
	bb._sample_skin()
	if bb.human:
		bb._human()
	else:
		bb._quad()
	bb.m.up = bb.up
	bb.m.fwd = bb.fwd
	bb.m.left = bb.left
	bb.m.chest_bone = p_sk.find_bone("spined" if bb.human else "Torso2")
	return bb.m


## A skin mesh of the body (its own skin: a human's "head_" part, or the undressed rig's Body and Face; an animal's biggest
## skinned mesh but its hair), not a garment, the hair or anything carried.
static func is_skin(mi: MeshInstance3D, p_sk: Skeleton3D) -> bool:
	if mi.mesh == null or mi.skin == null:
		return false
	var nm := String(mi.name).to_lower()
	for no: String in ["hair", "brow", "lash", "eye", "teeth", "tongue", "beard", "stubble", "pubic", "nail"]:
		if nm.contains(no):
			return false
	var is_human := p_sk.find_bone("spined") >= 0
	if is_human:
		return nm.begins_with("head_") or ((nm == "body" or nm == "face") and mi.is_visible_in_tree())
	return true


# ---------------------------------------------------------------------------------------------------------------------
# The skin and the rig


func _rest(bone: String) -> Vector3:
	return sk.get_bone_global_rest(sk.find_bone(bone)).origin


func _has(bone: String) -> bool:
	return sk.find_bone(bone) >= 0


## Metres in skeleton units.
func _u(metres: float) -> float:
	return metres / k


func _sample_skin() -> void:
	var cands: Array[MeshInstance3D] = []
	for mi in sk.find_children("*", "MeshInstance3D", true, false):
		var g := mi as MeshInstance3D
		if is_skin(g, sk):
			cands.append(g)
	if not human and cands.size() > 1:
		# an animal: the biggest one
		var best: MeshInstance3D = null
		var best_n := -1
		for g in cands:
			var n := 0
			for si in g.mesh.get_surface_count():
				n += g.mesh.surface_get_array_len(si)
			if n > best_n:
				best_n = n
				best = g
		cands = [best]
	if human:
		# the undressed rig's own skin is the upper body only: its garment mesh for the legs (rays only: _limb_r)
		var has_head := cands.any(func(g: MeshInstance3D) -> bool: return String(g.name).begins_with("head_"))
		if not has_head:
			for mi in sk.find_children("*", "MeshInstance3D", true, false):
				var g := mi as MeshInstance3D
				if g.mesh != null and g.skin != null and String(g.name) == "Clothes":
					cands.append(g)
	for g in cands:
		var to_sk := sk.global_transform.affine_inverse() * g.global_transform
		_skin.append({"tri": g.mesh.generate_triangle_mesh(), "to": to_sk.affine_inverse()})
		m.skin_names.append(String(g.name))
		var bb := g.mesh.get_aabb()
		for i in 8:
			_corners.append(to_sk * bb.get_endpoint(i))


## The skin's lowest point along the body's up (once up is known: the stand-ins are Z up, the bison Y up).
func _set_floor() -> void:
	_floor = INF
	for c in _corners:
		_floor = minf(_floor, c.dot(up))
	if _floor == INF:
		_floor = 0.0


## Distance (skeleton units) to the first skin the ray from `from` along `dir` (skeleton frame) meets, or INF.
func _shoot(from: Vector3, dir: Vector3) -> float:
	var best := INF
	for sk2: Dictionary in _skin:
		var to: Transform3D = sk2.to
		var f := to * from
		var d := (to.basis * dir).normalized()
		var hit: Dictionary = (sk2.tri as TriangleMesh).intersect_ray(f, d)
		if hit.is_empty():
			continue
		best = minf(best, f.distance_to(hit.position as Vector3) * (to.basis.inverse() * d).length())
	return best


## The body's cross-section across `along` at `p`: {v0, v1: the skin behind and in front along `ventral` from p (skeleton
## units, v0 < v1), hw: its half width}; without skin, `fallback` ({v0, v1, hw}).
func _slab(p: Vector3, along: Vector3, ventral: Vector3, fallback: Dictionary, max_hw := INF) -> Dictionary:
	if _skin.is_empty():
		return fallback
	var far := _u(3.0)
	var vdir := (ventral - along * ventral.dot(along)).normalized()
	var sdir := vdir.cross(along).normalized()
	var back_d := _shoot(p - vdir * far, vdir)
	var front_d := _shoot(p + vdir * far, -vdir)
	if back_d == INF or front_d == INF:
		return fallback
	var v0 := -far + back_d
	var v1 := far - front_d
	if v1 - v0 < _u(0.03) or v0 > 0.0 or v1 < 0.0:
		return fallback
	var c := p + vdir * ((v0 + v1) * 0.5)
	var wl := _shoot(c + sdir * far, -sdir)
	var wr := _shoot(c - sdir * far, sdir)
	var hw := float(fallback.hw)
	if wl != INF and wr != INF:
		hw = (far - wl + far - wr) * 0.5
	hw = minf(hw, max_hw)
	return {"v0": v0, "v1": v1, "hw": hw}


## A limb's flesh radius (m) at `t` along a..b (skeleton frame), from rays across it front and back; `fallback` when the
## skin is not there (or reads far off it).
func _limb_r(a: Vector3, b: Vector3, t: float, across: Vector3, fallback: float) -> float:
	if _skin.is_empty():
		return fallback
	var p := a.lerp(b, t)
	var ax := (b - a).normalized()
	var w := (across - ax * across.dot(ax)).normalized()
	var far := _u(1.0)
	var d0 := _shoot(p + w * far, -w)
	var d1 := _shoot(p - w * far, w)
	if d0 == INF or d1 == INF:
		return fallback
	var r := ((far - d0) + (far - d1)) * 0.5 * k
	if r < fallback * 0.55 or r > fallback * 1.6:
		return fallback
	return r


## A frame with Y along `y`, X as near `x_hint` as it can be (skeleton frame, orthonormal).
func _frame(y: Vector3, x_hint := Vector3.ZERO) -> Basis:
	var yy := y.normalized()
	var xh := x_hint if x_hint != Vector3.ZERO else left
	var x := xh - yy * xh.dot(yy)
	if x.length_squared() < 1e-6:
		x = fwd - yy * fwd.dot(yy)
	x = x.normalized()
	return Basis(x, yy, x.cross(yy).normalized())


## A shape on `bone` (a name, or the index), at `at` with `basis` (skeleton frame, rest pose), sized `size` (metres). `extra`:
## the shape's other keys (sub, brk, lvl, side, limb, vessel, top, th, col, tis).
func _add(nm: String, kind: String, bone: Variant, t: String, at: Vector3, basis: Basis, size: Vector3, extra := {}) -> void:
	var bi := sk.find_bone(String(bone)) if bone is String or bone is StringName else int(bone)
	if bi < 0:
		return
	var rest := sk.get_bone_global_rest(bi)
	var local := rest.affine_inverse() * Transform3D(basis.orthonormalized(), at)
	local.basis = local.basis.scaled(Vector3.ONE / k)
	var br := 0.0
	match t:
		"cap":
			br = size.x + size.y
		"cyl":
			br = Vector2(maxf(size.x, size.z), size.y).length()
		"box":
			var top: Vector2 = extra.get("top", Vector2(size.x, size.z))
			br = Vector2(maxf(maxf(size.x, size.z), maxf(top.x, top.y)), size.y).length() * 1.42
		_:
			br = maxf(size.x, maxf(size.y, size.z))
	var shp := {"name": nm, "kind": kind, "sub": "", "bone": bi, "t": t, "xf": local, "s": size, "br": br, "tis": "muscle",
			"col": FLESH, "lvl": 0, "side": "", "limb": ""}
	match kind:
		"bone":
			shp.tis = "bone"
			shp.col = BONE
		"organ":
			var o: Array = ORGAN.get(nm, [Color(0.8, 0.5, 0.5), "organ"])
			shp.col = o[0]
			shp.tis = o[1]
		"vessel":
			shp.tis = "vessel"
		"cord":
			shp.tis = "cord"
			shp.col = CORD
	for key: String in extra:
		shp[key] = extra[key]
	if kind == "vessel":
		shp.col = ARTERY if String(shp.get("vessel", "artery")) == "artery" else VEIN
	m.shapes.append(shp)


## A capsule from `a` to `b` (skeleton frame), radius `r` (m).
func _cap(nm: String, kind: String, bone: Variant, a: Vector3, b: Vector3, r: float, extra := {}) -> void:
	var len_m := a.distance_to(b) * k
	if len_m < 0.002:
		return
	_add(nm, kind, bone, "cap", (a + b) * 0.5, _frame(b - a), Vector3(r, len_m * 0.5, r), extra)


## A chain of capsules through `pts` (a vessel, the cord), each on the bone `bones[i]` (one name: all on it).
func _chain(nm: String, kind: String, bones: Variant, pts: Array, r: float, extra := {}) -> void:
	for i in pts.size() - 1:
		var bone: Variant = bones[i] if bones is Array else bones
		_cap(nm, kind, bone, pts[i], pts[i + 1], r, extra)


func _side_name(side: float, nm: String) -> String:
	return ("Left " if side > 0.0 else "Right ") + nm


# ---------------------------------------------------------------------------------------------------------------------
# A human


## The spine's chain point at height `h` (skeleton units along up) in the rest pose, and the bone there.
func _spine_at(h: float) -> Array:
	var chain := ["pelvis", "spinea", "spineb", "spinec", "spined", "neck", "heada", "headb"]
	var pts: Array[Vector3] = []
	for bn: String in chain:
		pts.append(_rest(bn))
	if h <= pts[0].dot(up):
		return [pts[0] + up * (h - pts[0].dot(up)), chain[0]]
	for i in pts.size() - 1:
		var h0 := pts[i].dot(up)
		var h1 := pts[i + 1].dot(up)
		if h <= h1:
			var t := clampf((h - h0) / maxf(h1 - h0, 1e-6), 0.0, 1.0)
			return [pts[i].lerp(pts[i + 1], t), chain[i] if t < 0.5 else chain[i + 1]]
	return [pts[-1] + up * (h - pts[-1].dot(up)), chain[-1]]


## The trunk's bone at height `h` (what the parts there ride).
func _trunk_bone(h: float) -> String:
	var best := "pelvis"
	for bn: String in ["pelvis", "spinea", "spineb", "spinec", "spined", "neck"]:
		if _rest(bn).dot(up) <= h + _u(0.02):
			best = bn
	return best


func _human() -> void:
	var root := _rest("root")
	up = (_rest("heada") - root).normalized()
	var toe := _rest("l_ball") - _rest("l_heel")
	fwd = (toe - up * toe.dot(up)).normalized()
	left = up.cross(fwd).normalized()
	var lr := _rest("l_shoulder") - _rest("r_shoulder")
	if lr.dot(left) < 0.0:
		left = -left
	fwd = left.cross(up).normalized()
	s = maxf(((_rest("heada") - _rest("l_heel")).dot(up) * k) / 1.5, 0.3)
	m.reach = 1.1 * s * 1.75 / 1.62 + 0.4
	m.back = 0.35
	var h_hip := (_rest("l_upper_leg") + _rest("r_upper_leg")).dot(up) * 0.5
	var h_s1 := h_hip + _u(0.095 * s)
	var h_t1 := _rest("neck").dot(up)
	var h_c1 := _rest("heada").dot(up) + (_rest("headb") - _rest("heada")).dot(up) * 0.6
	var max_hw := maxf(absf((_rest("l_shoulder") - root).dot(left)), _u(0.05)) * 0.95
	var fb := {"v0": _u(-0.11 * s), "v1": _u(0.11 * s), "hw": _u(0.15 * s)}
	# --- the column: L5..L1, T12..T1, C7..C1 (body centre heights), each level's canal (the cord) and body
	var levels: Array[Dictionary] = []          # from C1 down: {name, lvl, h, canal, body, bone, slab, rz, rx, hh}
	var lumbar := (h_t1 - h_s1) * 0.383
	var thor := (h_t1 - h_s1) - lumbar
	for i in 24:
		var h: float
		var nm: String
		var lv := i + 1
		if i < 7:
			h = h_c1 - (h_c1 - h_t1) * (float(i) + 0.5) / 7.0
			nm = "C%d" % (i + 1)
		elif i < 19:
			h = h_t1 - thor * (float(i - 7) + 0.5) / 12.0
			nm = "T%d" % (i - 6)
		else:
			h = h_s1 + lumbar - lumbar * (float(i - 19) + 0.5) / 5.0
			nm = "L%d" % (i - 18)
		var sp := _spine_at(h)
		var p: Vector3 = sp[0]
		var slab := _slab(p, up, fwd, fb, max_hw)
		var dep := float(slab.v1) - float(slab.v0)
		var canal_in := 0.04 if i < 7 else (0.048 if i < 19 else 0.062)
		var canal := p + fwd * (float(slab.v0) + minf(_u(canal_in * s), dep * 0.42))
		var rz := (0.0075 if i < 7 else (0.011 + 0.0003 * float(i - 7) if i < 19 else 0.0155)) * s
		var rx := (0.0085 if i < 7 else (0.013 + 0.0005 * float(i - 7) if i < 19 else 0.021)) * s
		var hh := (0.0055 if i < 7 else (0.0085 if i < 19 else 0.012)) * s
		var body := canal + fwd * _u(0.007 * s + rz)
		levels.append({"name": nm, "lvl": lv, "h": h, "canal": canal, "body": body, "bone": _trunk_bone(h) if i >= 7 else ("heada" if i < 2 else "neck"),
				"slab": slab, "p": p, "rz": rz, "rx": rx, "hh": hh})
	for L: Dictionary in levels:
		var nm := "%s vertebra" % String(L.name)
		var i := int(L.lvl) - 1
		var brk := float(BRK.vertebra_c if i < 7 else BRK.vertebra)
		var ex := {"sub": "vertebra", "brk": brk, "lvl": int(L.lvl)}
		_add(nm, "bone", L.bone, "cyl", L.body, _frame(up), Vector3(float(L.rx), float(L.hh), float(L.rz)), ex)
		# the arch round the canal's back, the spinous process on from it (sloping down in the chest): only what is round the canal
		# carries a break into the cord (sub "vertebra"), the processes do not (sub "process")
		var spin := (0.022 if i < 7 else 0.03) * s
		var arch_end := (L.canal as Vector3) - fwd * _u(0.012 * s)
		var tip := (L.canal as Vector3) - fwd * _u(spin) - up * _u(0.012 * s if (i >= 7 and i < 19) else 0.0)
		_cap(nm, "bone", L.bone, (L.canal as Vector3) - fwd * _u(0.006 * s), arch_end, 0.0055 * s, {"sub": "vertebra", "brk": BRK.arch, "lvl": int(L.lvl)})
		_cap(nm, "bone", L.bone, arch_end, tip, 0.0045 * s, {"sub": "process", "brk": BRK.arch, "lvl": int(L.lvl)})
		if i >= 7:
			# the transverse processes, across behind the canal
			var tw := (0.026 if i < 19 else 0.036) * s
			var c := (L.canal as Vector3) - fwd * _u(0.006 * s)
			_cap(nm, "bone", L.bone, c - left * _u(tw), c + left * _u(tw), 0.0045 * s, {"sub": "process", "brk": BRK.arch, "lvl": int(L.lvl)})
	# --- the cord through the canals, C1 to L5 (the cauda below L2), and the brainstem above it
	for i in range(1, levels.size()):
		var r := (0.0055 if i < 8 else (0.0045 if i < 20 else 0.004)) * s
		_cap("Spinal cord", "cord", levels[i].bone, levels[i - 1].canal, levels[i].canal, r, {"lvl": int(levels[i].lvl)})
	# --- the skull, the face, the jaw, the brain and brainstem (on the head's bones)
	var hb := _rest("headb")
	var vault_c := hb + up * _u(0.05 * s) + fwd * _u(0.008 * s)
	var vault_r := Vector3(0.07, 0.082, 0.1) * s
	var head_basis := _frame(up)
	_add("Skull", "bone", "headb", "shell", vault_c, head_basis, vault_r, {"sub": "skull", "brk": BRK.skull, "th": 0.007 * s})
	var face_c := hb - up * _u(0.004 * s) + fwd * _u(0.072 * s)
	_add("Skull", "bone", "headb", "box", face_c, head_basis, Vector3(0.036, 0.034, 0.028) * s, {"sub": "skull", "brk": BRK.face, "top": Vector2(0.05, 0.03) * s})
	_add("Brain", "organ", "headb", "ell", vault_c, head_basis, vault_r - Vector3.ONE * 0.008 * s)
	var c1 := levels[0].canal as Vector3
	_cap("Brainstem", "organ", "headb", vault_c - up * _u(0.05 * s) - fwd * _u(0.01 * s), c1, 0.012 * s)
	if _has("jaw"):
		var chin := (_rest("lower_mid_chin") if _has("lower_mid_chin") else hb - up * _u(0.06 * s) + fwd * _u(0.1 * s)) - fwd * _u(0.009 * s) + up * _u(0.006 * s)
		var ex_j := {"sub": "jaw", "brk": BRK.jaw}
		_cap("Jaw", "bone", "jaw", chin - left * _u(0.018 * s), chin + left * _u(0.018 * s), 0.009 * s, ex_j)
		for sd: float in [1.0, -1.0]:
			var corner := chin + left * _u(0.018 * s * sd)
			var angle := hb + left * _u(0.046 * s * sd) - up * _u(0.04 * s) + fwd * _u(0.03 * s)
			var condyle := hb + left * _u(0.05 * s * sd) + up * _u(0.0) + fwd * _u(0.012 * s)
			_cap("Jaw", "bone", "jaw", corner, angle, 0.008 * s, ex_j)
			_cap("Jaw", "bone", "jaw", angle, condyle, 0.008 * s, ex_j)
	# --- the ribs: 1-12 each side, arcs round the chest wall from the vertebra's side to the front
	var stern_top := Vector3.ZERO
	var stern_bot := Vector3.ZERO
	for ri in 12:
		var L: Dictionary = levels[7 + ri]
		var slab: Dictionary = L.slab
		var p := L.p as Vector3
		var h_back := float(L.h)
		var drop := _u((0.035 + 0.0045 * float(ri)) * s)
		if ri >= 10:
			drop = _u(0.02 * s)
		var th_end := PI - 0.13 if ri < 7 else ([2.75, 2.6, 2.4, 1.75, 1.35][ri - 7] as float)
		var front := _slab(_spine_at(h_back - drop)[0] as Vector3, up, fwd, fb, max_hw)
		var wall := _u(0.014 * s)
		var taper: float = [0.55, 0.7, 0.8, 0.88, 0.93, 0.97, 1.0, 1.0, 0.98, 0.95, 0.9, 0.85][ri]
		var bone := String(L.bone)
		for sd: float in [1.0, -1.0]:
			var pts: Array = []
			pts.append((L.canal as Vector3) + left * _u(0.026 * s * sd) + fwd * _u(0.004 * s))
			var n := 5
			for j in n:
				var th := 0.35 + (th_end - 0.35) * float(j) / float(n - 1)
				var u := (th - 0.35) / maxf(th_end - 0.35, 0.01)
				var sl := slab if u < 0.5 else front
				var c := p + fwd * ((float(sl.v0) + float(sl.v1)) * 0.5)
				var ra := maxf(float(sl.hw) * taper - wall, _u(0.04))
				var rb := maxf((float(sl.v1) - float(sl.v0)) * 0.5 * lerpf(taper, 1.0, 0.5) - wall, _u(0.04))
				var hh := h_back - drop * pow(u, 1.3)
				var q := c + left * (ra * sin(th) * sd) - fwd * (rb * cos(th))
				q += up * (hh - q.dot(up))
				pts.append(q)
			_chain(_side_name(sd, "rib %d" % (ri + 1)), "bone", bone, pts, (0.0055 if ri < 10 else 0.0045) * s,
					{"sub": "rib", "brk": BRK.rib, "lvl": ri + 1, "side": "l" if sd > 0.0 else "r"})
			if ri == 1 and sd > 0.0:
				stern_top = pts[-1]
			if ri == 6 and sd > 0.0:
				stern_bot = pts[-1]
	# --- the sternum, under the front of the chest
	var mid_x := root.dot(left)
	var st_a := stern_top - left * (stern_top.dot(left) - mid_x) + up * _u(0.02 * s)
	var st_b := stern_bot - left * (stern_bot.dot(left) - mid_x) - up * _u(0.035 * s)
	st_a += fwd * _u(0.004 * s)
	st_b += fwd * _u(0.004 * s)
	var st_len := st_a.distance_to(st_b) * k
	_add("Sternum", "bone", "spined", "box", (st_a + st_b) * 0.5, _frame(st_a - st_b, left), Vector3(0.012, st_len * 0.5, 0.006) * Vector3(s, 1.0, s),
			{"sub": "flat", "brk": BRK.sternum, "top": Vector2(0.026, 0.007) * s})
	var notch := st_a
	# --- the shoulder girdles, the arms, the hands
	for sd: float in [1.0, -1.0]:
		var pre := "l_" if sd > 0.0 else "r_"
		var lat := left * sd
		var sh := _rest(pre + "shoulder")
		var el := _rest(pre + "elbow")
		var wr := _rest(pre + "wrist")
		var ex := {"side": "l" if sd > 0.0 else "r"}
		# clavicle: from beside the notch out to the acromion over the shoulder joint, bowed forward in its middle
		var med := notch + lat * _u(0.02 * s) + up * _u(0.004 * s)
		var acro := sh + up * _u(0.028 * s) - fwd * _u(0.008 * s) + lat * _u(0.004 * s)
		var mid := med.lerp(acro, 0.45) + fwd * _u(0.012 * s)
		var cl_bone := pre + "clavicle"
		_chain(_side_name(sd, "clavicle"), "bone", cl_bone, [med, mid, acro], 0.0065 * s, ex.merged({"sub": "flat", "brk": BRK.clavicle}))
		# scapula: a plate on the back over ribs 2-7, and its neck out to the joint
		var t4: Dictionary = levels[7 + 4]
		var back_at := (t4.p as Vector3) + fwd * (float((t4.slab as Dictionary).v0) + _u(0.028 * s)) + lat * _u(0.08 * s)
		var sc_up := (up * 0.95 + lat * 0.15).normalized()
		var sc_n := (-fwd * 0.92 + lat * 0.38).normalized()
		var sc_x := sc_up.cross(sc_n).normalized()
		var sc_bone := pre + "scapula" if _has(pre + "scapula") else cl_bone
		_add(_side_name(sd, "scapula"), "bone", sc_bone, "box", back_at, Basis(sc_x, sc_up, sc_x.cross(sc_up)), Vector3(0.012, 0.075, 0.0032) * s,
				ex.merged({"sub": "flat", "brk": BRK.scapula, "top": Vector2(0.05, 0.0035) * s}))
		_cap(_side_name(sd, "scapula"), "bone", sc_bone, back_at + sc_up * _u(0.06 * s) + lat * _u(0.03 * s), sh - lat * _u(0.012 * s), 0.009 * s,
				ex.merged({"sub": "flat", "brk": BRK.scapula}))
		# humerus: its head in the joint, the shaft, the condyles at the elbow
		var arm := (el - sh).normalized()
		var hum := _side_name(sd, "humerus")
		_cap(hum, "bone", pre + "shoulder", sh + arm * _u(0.03 * s), el - arm * _u(0.022 * s), 0.0115 * s, ex.merged({"sub": "long", "brk": BRK.humerus, "limb": "arm"}))
		_add(hum, "bone", pre + "shoulder", "ell", sh, _frame(arm), Vector3(0.022, 0.024, 0.022) * s, ex.merged({"sub": "long", "brk": BRK.humerus_end, "limb": "arm"}))
		_add(hum, "bone", pre + "shoulder", "ell", el - arm * _u(0.008 * s), _frame(arm), Vector3(0.028, 0.013, 0.016) * s, ex.merged({"sub": "long", "brk": BRK.humerus_end, "limb": "arm"}))
		# radius (the thumb's side) and ulna
		var fore := (wr - el).normalized()
		var thumb_dir := Vector3.ZERO
		if _has(pre + "thumba") and _has(pre + "palm"):
			thumb_dir = _rest(pre + "thumba") - _rest(pre + "palm")
			thumb_dir = (thumb_dir - fore * thumb_dir.dot(fore)).normalized()
		if thumb_dir == Vector3.ZERO:
			thumb_dir = fwd
		_cap(_side_name(sd, "radius"), "bone", pre + "elbow", el + thumb_dir * _u(0.008 * s) + fore * _u(0.015 * s), wr + thumb_dir * _u(0.012 * s) - fore * _u(0.01 * s), 0.0065 * s,
				ex.merged({"sub": "long", "brk": BRK.radius, "limb": "arm"}))
		_cap(_side_name(sd, "ulna"), "bone", pre + "elbow", el - thumb_dir * _u(0.009 * s) - fore * _u(0.012 * s), wr - thumb_dir * _u(0.011 * s) - fore * _u(0.008 * s), 0.0065 * s,
				ex.merged({"sub": "long", "brk": BRK.ulna, "limb": "arm"}))
		# the hand: the wrist's bones, the metacarpals and the fingers on their own bones
		var hand := _side_name(sd, "hand")
		var hx := ex.merged({"sub": "small", "brk": BRK.hand, "limb": "arm"})
		if _has(pre + "palm"):
			_add(hand, "bone", pre + "wrist", "ell", wr + fore * _u(0.018 * s), _frame(fore, thumb_dir), Vector3(0.02, 0.013, 0.011) * s, hx)
			for f: String in ["index", "middle", "ring"]:
				var mc := pre + f + "_metacarpal"
				if not _has(mc):
					continue
				var fa := pre + f + "a"
				var fb2 := pre + f + "b"
				var fc := pre + f + "c"
				_cap(hand, "bone", mc, _rest(mc), _rest(fa), 0.0045 * s, hx)
				_cap(hand, "bone", fa, _rest(fa), _rest(fb2), 0.0042 * s, hx)
				_cap(hand, "bone", fb2, _rest(fb2), _rest(fc), 0.0038 * s, hx)
				_cap(hand, "bone", fc, _rest(fc), _rest(fc) + (_rest(fc) - _rest(fb2)) * 0.75, 0.0034 * s, hx)
			var pk := [pre + "pinkya", pre + "pinkyb", pre + "pinkyc", pre + "pinkyd"]
			if _has(pk[0]) and _has(pk[3]):
				for j in 3:
					_cap(hand, "bone", pk[j], _rest(pk[j]), _rest(pk[j + 1]), 0.004 * s, hx)
				_cap(hand, "bone", pk[3], _rest(pk[3]), _rest(pk[3]) + (_rest(pk[3]) - _rest(pk[2])) * 0.75, 0.0032 * s, hx)
			var th := [pre + "thumba", pre + "thumbb", pre + "thumbc"]
			if _has(th[0]) and _has(th[2]):
				for j in 2:
					_cap(hand, "bone", th[j], _rest(th[j]), _rest(th[j + 1]), 0.0048 * s, hx)
				_cap(hand, "bone", th[2], _rest(th[2]), _rest(th[2]) + (_rest(th[2]) - _rest(th[1])) * 0.8, 0.004 * s, hx)
	# --- the pelvis and sacrum, the legs, the feet
	var s1 := _spine_at(h_s1)
	var s1_slab := _slab(s1[0] as Vector3, up, fwd, fb, max_hw)
	var sac_top := (s1[0] as Vector3) + fwd * (float(s1_slab.v0) + _u(0.055 * s))
	var hip_c := (_rest("l_upper_leg") + _rest("r_upper_leg")) * 0.5
	var sac_bot := hip_c - up * _u(0.07 * s) + fwd * (sac_top - hip_c).dot(fwd) - fwd * _u(0.012 * s)
	var sac_len := sac_top.distance_to(sac_bot) * k
	_add("Sacrum", "bone", "pelvis", "box", (sac_top + sac_bot) * 0.5, _frame(sac_top - sac_bot), Vector3(0.016, sac_len * 0.5, 0.014) * Vector3(s, 1.0, s),
			{"sub": "pelvis", "brk": BRK.sacrum, "top": Vector2(0.05, 0.02) * s})
	var hip_slab := _slab(hip_c, up, fwd, fb, INF)
	var pubic := hip_c + fwd * (float(hip_slab.v1) - _u(0.028 * s)) - up * _u(0.02 * s)
	for sd: float in [1.0, -1.0]:
		var pre := "l_" if sd > 0.0 else "r_"
		var lat := left * sd
		var hip := _rest(pre + "upper_leg")
		var kn := _rest(pre + "knee")
		var an := _rest(pre + "ankle")
		var ex := {"side": "l" if sd > 0.0 else "r"}
		var px := ex.merged({"sub": "pelvis"})
		# the ilium's wing flaring up and out above the joint, the socket round the femur's head, the pubis to the
		# symphysis, the ischium down and back to the sitting bone, its ramus forward to the symphysis
		var wing := hip + up * _u(0.105 * s) - lat * _u(0.005 * s) - fwd * _u(0.012 * s)
		var wn := (lat * 0.8 - fwd * 0.25 + up * 0.1).normalized()
		var wy := (up - wn * up.dot(wn)).normalized()
		var wx := wy.cross(wn).normalized()
		_add("Pelvis", "bone", "pelvis", "box", wing, Basis(wx, wy, wx.cross(wy)), Vector3(0.04, 0.055, 0.005) * s, px.merged({"brk": BRK.ilium, "top": Vector2(0.062, 0.006) * s}))
		_add("Pelvis", "bone", "pelvis", "ell", hip - lat * _u(0.008 * s) + up * _u(0.008 * s), _frame(up), Vector3(0.03, 0.033, 0.03) * s, px.merged({"brk": BRK.acetabulum}))
		_cap("Pelvis", "bone", "pelvis", hip - lat * _u(0.02 * s) + fwd * _u(0.018 * s) - up * _u(0.01 * s), pubic + lat * _u(0.012 * s), 0.011 * s, px.merged({"brk": BRK.pubis}))
		var tub := hip - up * _u(0.075 * s) - fwd * _u(0.03 * s) - lat * _u(0.03 * s)
		_cap("Pelvis", "bone", "pelvis", hip - up * _u(0.028 * s) - lat * _u(0.012 * s), tub, 0.012 * s, px.merged({"brk": BRK.pubis}))
		_cap("Pelvis", "bone", "pelvis", tub, pubic + lat * _u(0.01 * s) - up * _u(0.015 * s), 0.008 * s, px.merged({"brk": BRK.pubis}))
		# femur: head, neck to the greater trochanter, the shaft, the condyles
		var fem := _side_name(sd, "femur")
		var fx := ex.merged({"sub": "long", "limb": "leg"})
		var thigh := (kn - hip).normalized()
		var shaft_a := hip + lat * _u(0.036 * s) - up * _u(0.05 * s)
		var shaft_b := kn + up * _u(0.035 * s) + lat * _u(0.003 * s)
		_cap(fem, "bone", pre + "upper_leg", shaft_a, shaft_b, 0.0135 * s, fx.merged({"brk": BRK.femur}))
		_add(fem, "bone", pre + "upper_leg", "ell", hip, _frame(up), Vector3(0.022, 0.022, 0.022) * s, fx.merged({"brk": BRK.femur_end}))
		var troch := hip + lat * _u(0.048 * s) - up * _u(0.03 * s)
		_cap(fem, "bone", pre + "upper_leg", hip, troch, 0.014 * s, fx.merged({"brk": BRK.femur_end}))
		_add(fem, "bone", pre + "upper_leg", "ell", kn + up * _u(0.018 * s) - fwd * _u(0.004 * s), _frame(thigh), Vector3(0.037, 0.022, 0.03) * s, fx.merged({"brk": BRK.femur_end}))
		_add(_side_name(sd, "kneecap"), "bone", pre + "knee", "ell", kn + fwd * _u(0.046 * s) + up * _u(0.012 * s), _frame(thigh), Vector3(0.021, 0.023, 0.009) * s,
				ex.merged({"sub": "small", "brk": BRK.kneecap, "limb": "leg"}))
		# tibia (front and inside) and fibula (outside and back)
		var shin := (an - kn).normalized()
		var tib := _side_name(sd, "tibia")
		_cap(tib, "bone", pre + "knee", kn - shin * _u(0.045 * s) + fwd * _u(0.008 * s), an - shin * _u(0.03 * s) + fwd * _u(0.01 * s) - lat * _u(0.004 * s), 0.0115 * s,
				ex.merged({"sub": "long", "brk": BRK.tibia, "limb": "leg"}))
		_add(tib, "bone", pre + "knee", "ell", kn - up * _u(0.026 * s), _frame(shin), Vector3(0.035, 0.018, 0.028) * s, ex.merged({"sub": "long", "brk": BRK.tibia_end, "limb": "leg"}))
		_cap(_side_name(sd, "fibula"), "bone", pre + "knee", kn - shin * _u(0.04 * s) + lat * _u(0.022 * s) - fwd * _u(0.012 * s), an + lat * _u(0.021 * s) - fwd * _u(0.008 * s), 0.006 * s,
				ex.merged({"sub": "long", "brk": BRK.fibula, "limb": "leg"}))
		# the foot: talus and heel bone on the ankle, the tarsals and metatarsals on the heel's bone, the toes on the ball's
		var foot := _side_name(sd, "foot")
		var fx2 := ex.merged({"sub": "small", "brk": BRK.foot, "limb": "leg"})
		var heel := _rest(pre + "heel")
		var ball := _rest(pre + "ball")
		_add(foot, "bone", pre + "ankle", "ell", an - up * _u(0.016 * s), _frame(up), Vector3(0.02, 0.015, 0.025) * s, fx2)
		var calc_a := an - up * _u(0.03 * s)
		var calc_b := heel + up * _u(0.022 * s) + fwd * _u(0.012 * s)
		_cap(foot, "bone", pre + "ankle", calc_a, calc_b, 0.019 * s, fx2)
		var mt_a := an + fwd * _u(0.03 * s) - up * _u(0.025 * s)
		var mt_b := ball + up * _u(0.008 * s)
		var foot_bone := pre + "heel" if _has(pre + "heel") else pre + "ankle"
		_add(foot, "bone", foot_bone, "box", (mt_a + mt_b) * 0.5, _frame(mt_b - mt_a, lat), Vector3(0.02, mt_a.distance_to(mt_b) * k * 0.5, 0.012) * Vector3(s, 1.0, s),
				fx2.merged({"top": Vector2(0.034, 0.008) * s}))
		_add(foot, "bone", pre + "ball", "box", ball + fwd * _u(0.03 * s) + up * _u(0.004 * s), _frame(fwd, lat), Vector3(0.033, 0.026, 0.007) * Vector3(s, s, s),
				fx2.merged({"top": Vector2(0.03, 0.006) * s}))
	# --- the organs, by real distance down the spine from the neck's base (x the rig's torso against a real one)
	var tz := maxf((_rest("neck") - root).dot(up) * k / 0.53, 0.3)
	var organs := [
		# [name, down (m), front (0 back .. 1 front of the cross-section), left (of the half width), radii (m: across, along, depth)]
		["Left lung", 0.12, 0.5, 0.48, Vector3(0.062, 0.12, 0.075)],
		["Right lung", 0.12, 0.5, -0.48, Vector3(0.066, 0.12, 0.078)],
		["Heart", 0.16, 0.64, 0.12, Vector3(0.045, 0.055, 0.04)],
		["Liver", 0.27, 0.55, -0.42, Vector3(0.09, 0.055, 0.062)],
		["Stomach", 0.26, 0.62, 0.38, Vector3(0.05, 0.058, 0.038)],
		["Spleen", 0.26, 0.3, 0.72, Vector3(0.026, 0.048, 0.022)],
		["Left kidney", 0.34, 0.24, 0.42, Vector3(0.028, 0.052, 0.02)],
		["Right kidney", 0.35, 0.24, -0.42, Vector3(0.028, 0.052, 0.02)],
		["Intestines", 0.43, 0.68, 0.0, Vector3(0.1, 0.075, 0.058)],
	]
	var heart_c := Vector3.ZERO
	var organ_at := {}
	for o: Array in organs:
		var h := h_t1 - _u(float(o[1]) * tz)
		var sp := _spine_at(h)
		var slab := _slab(sp[0] as Vector3, up, fwd, fb, max_hw)
		var dep := float(slab.v1) - float(slab.v0)
		var hw := float(slab.hw)
		var c := (sp[0] as Vector3) + fwd * (float(slab.v0) + dep * float(o[2])) + left * (float(o[3]) * hw)
		var rr := (o[4] as Vector3) * s
		rr.y *= tz / s
		# (kept inside the skin: no wider than the cross-section leaves room for)
		rr.x = minf(rr.x, maxf(hw * k * (1.0 - absf(float(o[3])) * 0.55), 0.02))
		rr.z = minf(rr.z, dep * k * (0.3 if String(o[0]) == "Intestines" else 0.42))
		_add(String(o[0]), "organ", _trunk_bone(h), "ell", c, _frame(up), rr)
		organ_at[String(o[0])] = c
		if String(o[0]) == "Heart":
			heart_c = c
	# --- the vessels
	_human_vessels(levels, heart_c, notch, organ_at)
	# --- the flesh: the trunk in slabs from the hips to the neck's base, the neck, the head, each limb
	var n_sl := 9
	var lo := h_hip - _u(0.02 * s)
	for i in n_sl:
		var h0 := lo + (h_t1 - lo) * float(i) / float(n_sl)
		var h1 := lo + (h_t1 - lo) * float(i + 1) / float(n_sl)
		var hm := (h0 + h1) * 0.5
		var sp := _spine_at(hm)
		var slab := _slab(sp[0] as Vector3, up, fwd, fb, max_hw)
		var c := (sp[0] as Vector3) + fwd * ((float(slab.v0) + float(slab.v1)) * 0.5)
		var nm := "Hips" if hm < h_s1 else ("Belly" if hm < levels[18].h else "Chest")
		_add(nm, "flesh", _trunk_bone(hm), "cyl", c, _frame(up), Vector3(float(slab.hw) * k, (h1 - h0) * k * 0.5 + 0.004, (float(slab.v1) - float(slab.v0)) * k * 0.5))
	for i in 2:
		var h0 := h_t1 + (h_c1 - h_t1) * float(i) * 0.55
		var h1 := h_t1 + (h_c1 - h_t1) * (float(i) * 0.55 + 0.6)
		var hm := (h0 + h1) * 0.5
		var sp := _spine_at(hm)
		var slab := _slab(sp[0] as Vector3, up, fwd, {"v0": _u(-0.055 * s), "v1": _u(0.06 * s), "hw": _u(0.058 * s)}, _u(0.075 * s))
		var c := (sp[0] as Vector3) + fwd * ((float(slab.v0) + float(slab.v1)) * 0.5)
		_add("Neck", "flesh", "neck", "cyl", c, _frame(up), Vector3(float(slab.hw) * k, (h1 - h0) * k * 0.5 + 0.004, (float(slab.v1) - float(slab.v0)) * k * 0.5))
	_add("Scalp and face", "flesh", "headb", "ell", vault_c + fwd * _u(0.004 * s) - up * _u(0.022 * s), head_basis, Vector3(0.08, 0.12, 0.118) * s)
	for sd: float in [1.0, -1.0]:
		var pre := "l_" if sd > 0.0 else "r_"
		var sh := _rest(pre + "shoulder")
		var el := _rest(pre + "elbow")
		var wr := _rest(pre + "wrist")
		var hip := _rest(pre + "upper_leg")
		var kn := _rest(pre + "knee")
		var an := _rest(pre + "ankle")
		var ua := _side_name(sd, "upper arm")
		_cap(ua, "flesh", pre + "shoulder", sh, sh.lerp(el, 0.5), _limb_r(sh, el, 0.25, fwd, 0.047 * s), {"side": "l" if sd > 0.0 else "r"})
		_cap(ua, "flesh", pre + "shoulder", sh.lerp(el, 0.5), el, _limb_r(sh, el, 0.75, fwd, 0.04 * s), {"side": "l" if sd > 0.0 else "r"})
		var fa := _side_name(sd, "forearm")
		_cap(fa, "flesh", pre + "elbow", el, el.lerp(wr, 0.5), _limb_r(el, wr, 0.25, fwd, 0.04 * s), {"side": "l" if sd > 0.0 else "r"})
		_cap(fa, "flesh", pre + "elbow", el.lerp(wr, 0.5), wr, _limb_r(el, wr, 0.75, fwd, 0.031 * s), {"side": "l" if sd > 0.0 else "r"})
		if _has(pre + "palm") and _has(pre + "middlec"):
			var tip := _rest(pre + "middlec") + (_rest(pre + "middlec") - _rest(pre + "middleb")) * 0.8
			var across := _rest(pre + "index_metacarpal") - _rest(pre + "pinkya") if _has(pre + "pinkya") else left
			_add(_side_name(sd, "hand"), "flesh", pre + "palm", "box", (wr + tip) * 0.5, _frame(tip - wr, across), Vector3(0.042, wr.distance_to(tip) * k * 0.5 + 0.006, 0.016) * Vector3(s, 1.0, s),
					{"side": "l" if sd > 0.0 else "r", "top": Vector2(0.04, 0.009) * s})
		var th := _side_name(sd, "thigh")
		_cap(th, "flesh", pre + "upper_leg", hip, hip.lerp(kn, 0.5), _limb_r(hip, kn, 0.25, fwd, 0.08 * s), {"side": "l" if sd > 0.0 else "r"})
		_cap(th, "flesh", pre + "upper_leg", hip.lerp(kn, 0.5), kn, _limb_r(hip, kn, 0.75, fwd, 0.06 * s), {"side": "l" if sd > 0.0 else "r"})
		var cf := _side_name(sd, "calf")
		_cap(cf, "flesh", pre + "knee", kn, kn.lerp(an, 0.45), _limb_r(kn, an, 0.25, fwd, 0.052 * s), {"side": "l" if sd > 0.0 else "r"})
		_cap(cf, "flesh", pre + "knee", kn.lerp(an, 0.45), an, _limb_r(kn, an, 0.75, fwd, 0.036 * s), {"side": "l" if sd > 0.0 else "r"})
		var heel := _rest(pre + "heel")
		var ball := _rest(pre + "ball")
		var toe_end := ball + fwd * _u(0.06 * s)
		var f_a := heel - fwd * _u(0.012 * s) + up * _u(0.036 * s)
		var f_b := toe_end + up * _u(0.016 * s)
		_add(_side_name(sd, "foot"), "flesh", pre + "heel" if _has(pre + "heel") else pre + "ankle", "box", (f_a + f_b) * 0.5, _frame(f_b - f_a, left * sd),
				Vector3(0.032, f_a.distance_to(f_b) * k * 0.5, 0.042) * Vector3(s, 1.0, s), {"side": "l" if sd > 0.0 else "r", "top": Vector2(0.045, 0.02) * s})


## The great vessels and the limbs' main ones, laid by the bones and organs they run beside.
func _human_vessels(levels: Array[Dictionary], heart_c: Vector3, notch: Vector3, organ_at: Dictionary) -> void:
	var ART := {"vessel": "artery"}
	var VN := {"vessel": "vein"}
	var lvl := func(nm: String) -> Dictionary:
		for L: Dictionary in levels:
			if String(L.name) == nm:
				return L
		return levels[0]
	var front_of := func(nm: String, ahead: float, lateral: float) -> Vector3:
		var L: Dictionary = lvl.call(nm)
		return (L.body as Vector3) + fwd * _u(float(L.rz) + ahead * s) + left * _u(lateral * s)
	# the aorta: up out of the heart, over in its arch to the left of T4, down in front of the spine, to L4
	var asc0 := heart_c + up * _u(0.035 * s) - left * _u(0.008 * s)
	var arch_top := (lvl.call("T3").body as Vector3).lerp(notch, 0.55) + up * _u(0.005 * s) + left * _u(0.004 * s)
	var arch_back: Vector3 = front_of.call("T4", 0.012, 0.016)
	var aorta_pts := [asc0, arch_top, arch_back, front_of.call("T7", 0.011, 0.016), front_of.call("T10", 0.011, 0.014),
			front_of.call("L1", 0.011, 0.012), front_of.call("L3", 0.011, 0.01), front_of.call("L4", 0.011, 0.008)]
	var aorta_bones := ["spined", "spined", "spined", _trunk_bone(lvl.call("T7").h), _trunk_bone(lvl.call("T10").h),
			_trunk_bone(lvl.call("L1").h), _trunk_bone(lvl.call("L3").h)]
	_chain("Aorta", "vessel", aorta_bones, aorta_pts, 0.0125 * s, ART)
	# the venae cavae: the superior up the right of the ascending aorta; the inferior down the right of the spine to L5
	var svc_top := (notch.lerp(lvl.call("T2").body as Vector3, 0.5)) - left * _u(0.022 * s)
	_cap("Superior vena cava", "vessel", "spined", heart_c + up * _u(0.04 * s) - left * _u(0.028 * s), svc_top, 0.01 * s, VN)
	var ivc := [heart_c - up * _u(0.045 * s) - left * _u(0.025 * s), front_of.call("T11", 0.016, -0.024), front_of.call("L1", 0.014, -0.022),
			front_of.call("L3", 0.013, -0.02), front_of.call("L5", 0.012, -0.012)]
	_chain("Inferior vena cava", "vessel", ["spinec", _trunk_bone(lvl.call("T11").h), _trunk_bone(lvl.call("L1").h), _trunk_bone(lvl.call("L3").h)], ivc, 0.011 * s, VN)
	var c1: Dictionary = lvl.call("C1")
	var c4: Dictionary = lvl.call("C4")
	var t1: Dictionary = lvl.call("T1")
	for sd: float in [1.0, -1.0]:
		var pre := "l_" if sd > 0.0 else "r_"
		var lat := left * sd
		var sx := {"side": "l" if sd > 0.0 else "r"}
		var sh := _rest(pre + "shoulder")
		var el := _rest(pre + "elbow")
		var wr := _rest(pre + "wrist")
		var hip := _rest(pre + "upper_leg")
		var kn := _rest(pre + "knee")
		# the carotid up the neck beside the windpipe, the jugular outside it
		var root := arch_top + left * _u((0.012 if sd > 0.0 else -0.035) * s)
		var car_lo := (t1.body as Vector3) + fwd * _u(float(t1.rz) + 0.022 * s) + lat * _u(0.022 * s)
		var car_mid := (c4.body as Vector3) + fwd * _u(float(c4.rz) + 0.016 * s) + lat * _u(0.024 * s)
		var car_hi := (c1.body as Vector3) + fwd * _u(float(c1.rz) + 0.012 * s) + lat * _u(0.03 * s)
		_chain(_side_name(sd, "carotid artery"), "vessel", ["spined", "neck", "heada"], [root, car_lo, car_mid, car_hi], 0.0035 * s, ART.merged(sx))
		var jug_lo := car_lo + lat * _u(0.014 * s) + fwd * _u(0.004 * s)
		_chain(_side_name(sd, "jugular vein"), "vessel", ["neck", "heada"], [jug_lo, car_mid + lat * _u(0.014 * s) + fwd * _u(0.004 * s), car_hi + lat * _u(0.008 * s)], 0.006 * s, VN.merged(sx))
		# the subclavian over the first rib behind the clavicle to the armpit, the brachial down the inside of the arm, the
		# radial and ulnar down the forearm
		var axilla := sh - up * _u(0.04 * s) - lat * _u(0.028 * s)
		var over_rib := notch.lerp(sh, 0.45) - fwd * _u(0.012 * s) + up * _u(0.004 * s)
		_chain(_side_name(sd, "subclavian artery"), "vessel", ["spined", pre + "clavicle", pre + "clavicle"], [root, over_rib, axilla], 0.0045 * s, ART.merged(sx))
		_chain(_side_name(sd, "subclavian vein"), "vessel", [pre + "clavicle", pre + "clavicle"], [jug_lo, over_rib + fwd * _u(0.012 * s) - up * _u(0.006 * s), axilla + fwd * _u(0.006 * s)], 0.006 * s, VN.merged(sx))
		var arm := (el - sh).normalized()
		var med := -lat
		var b0 := sh + arm * _u(0.05 * s) + med * _u(0.022 * s) + fwd * _u(0.006 * s)
		var b1 := el - arm * _u(0.01 * s) + med * _u(0.008 * s) + fwd * _u(0.016 * s)
		_chain(_side_name(sd, "brachial artery"), "vessel", [pre + "shoulder", pre + "shoulder"], [axilla, b0, b1], 0.0035 * s, ART.merged(sx))
		_chain(_side_name(sd, "brachial vein"), "vessel", [pre + "shoulder", pre + "shoulder"], [axilla + med * _u(0.006 * s), b0 + med * _u(0.009 * s), b1 + med * _u(0.007 * s)], 0.004 * s, VN.merged(sx))
		var fore := (wr - el).normalized()
		var thumb_dir := Vector3.ZERO
		if _has(pre + "thumba") and _has(pre + "palm"):
			thumb_dir = _rest(pre + "thumba") - _rest(pre + "palm")
			thumb_dir = (thumb_dir - fore * thumb_dir.dot(fore)).normalized()
		if thumb_dir == Vector3.ZERO:
			thumb_dir = fwd
		var palm_side := fore.cross(thumb_dir).normalized() * (1.0 if sd > 0.0 else -1.0)
		_cap(_side_name(sd, "radial artery"), "vessel", pre + "elbow", b1 + fore * _u(0.02 * s), wr + thumb_dir * _u(0.012 * s) + palm_side * _u(0.008 * s), 0.002 * s, ART.merged(sx))
		_cap(_side_name(sd, "ulnar artery"), "vessel", pre + "elbow", b1 + fore * _u(0.02 * s), wr - thumb_dir * _u(0.011 * s) + palm_side * _u(0.008 * s), 0.002 * s, ART.merged(sx))
		# the iliac from the aorta's fork to the groin, the femoral down the front and inside of the thigh to behind the knee,
		# the popliteal behind it; their veins inside them
		var fork: Vector3 = aorta_pts[-1]
		var si := (lvl.call("L5").body as Vector3) + lat * _u(0.045 * s) + fwd * _u(0.02 * s) - up * _u(0.02 * s)
		var groin := hip + fwd * _u(0.032 * s) - lat * _u(0.008 * s) + up * _u(0.02 * s)
		_chain(_side_name(sd, "iliac artery"), "vessel", ["pelvis", "pelvis"], [fork, si, groin], 0.0055 * s, ART.merged(sx))
		var f1 := hip.lerp(kn, 0.3) + fwd * _u(0.028 * s) - lat * _u(0.03 * s)
		var f2 := hip.lerp(kn, 0.66) + fwd * _u(0.006 * s) - lat * _u(0.03 * s)
		var pop := kn + up * _u(0.05 * s) - fwd * _u(0.035 * s) - lat * _u(0.004 * s)
		var pop_lo := kn - up * _u(0.07 * s) - fwd * _u(0.03 * s)
		_chain(_side_name(sd, "femoral artery"), "vessel", [pre + "upper_leg", pre + "upper_leg", pre + "upper_leg"], [groin, f1, f2, pop], 0.0045 * s, ART.merged(sx))
		_cap(_side_name(sd, "popliteal artery"), "vessel", pre + "knee", pop, pop_lo, 0.004 * s, ART.merged(sx))
		var ivc_end: Vector3 = ivc[-1]
		var vin := -lat * _u(0.012 * s) - fwd * _u(0.006 * s)
		_chain(_side_name(sd, "iliac vein"), "vessel", ["pelvis", "pelvis"], [ivc_end, si - fwd * _u(0.008 * s) - lat * _u(0.006 * s), groin - lat * _u(0.013 * s)], 0.0065 * s, VN.merged(sx))
		_chain(_side_name(sd, "femoral vein"), "vessel", [pre + "upper_leg", pre + "upper_leg", pre + "upper_leg"], [groin - lat * _u(0.013 * s), f1 + vin, f2 + vin, pop - fwd * _u(0.008 * s)], 0.0055 * s, VN.merged(sx))
		_cap(_side_name(sd, "popliteal vein"), "vessel", pre + "knee", pop - fwd * _u(0.008 * s), pop_lo - fwd * _u(0.008 * s), 0.0045 * s, VN.merged(sx))


# ---------------------------------------------------------------------------------------------------------------------
# An animal (the stand-ins' rig)


func _q(bone: String) -> Vector3:
	return _rest(bone)


## The point a part `t` along the chain `names` (rest pose) and the bone it rides.
func _chain_at(names: Array, t: float) -> Array:
	var pts: Array[Vector3] = []
	for n: String in names:
		pts.append(_rest(n))
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var at := t * total
	for i in pts.size() - 1:
		var l := pts[i].distance_to(pts[i + 1])
		if at <= l or i == pts.size() - 2:
			var u := clampf(at / maxf(l, 1e-6), 0.0, 1.0)
			return [pts[i].lerp(pts[i + 1], u), String(names[i]) if u < 0.5 else String(names[i + 1])]
		at -= l
	return [pts[-1], String(names[-1])]


func _quad() -> void:
	var spine := ["Back", "Torso", "Torso2", "Torso3"]
	var neck := ["Torso3", "Neck1", "Neck2", "Neck3", "Head"]
	var pelvis := _rest("Back")
	var shoulders := _rest("Torso3")
	_torso_m = maxf(pelvis.distance_to(shoulders) * k, 0.1)
	s = _torso_m / 0.72
	# up: from its feet to its back (the stand-ins are Z up, the bison Y up)
	var feet := Vector3.ZERO
	var nf := 0
	for fb: String in ["FrontLowerLeg.L", "FrontLowerLeg.R", "BackLowerLeg.L", "BackLowerLeg.R"]:
		if _has(fb):
			feet += _rest(fb)
			nf += 1
	up = ((pelvis + _rest("Torso2")) * 0.5 - feet / float(maxi(nf, 1))).normalized()
	var head := _rest("Head") - pelvis
	fwd = (head - up * head.dot(up)).normalized()
	left = up.cross(fwd).normalized()
	if _has("FrontUpperLeg.L") and _has("FrontUpperLeg.R") and (_rest("FrontUpperLeg.L") - _rest("FrontUpperLeg.R")).dot(left) < 0.0:
		left = -left
	_dorsal = up
	_set_floor()
	var along := (shoulders - pelvis).normalized()
	var ventral := -up
	_width_m = _torso_m * 0.55
	m.reach = _torso_m * 2.6 + 0.4
	m.back = maxf(_torso_m * 0.5, 0.35)
	var fb := {"v0": -_u(_torso_m * 0.25), "v1": _u(_torso_m * 0.25), "hw": _u(_width_m * 0.5)}
	# --- the column: C1-C7 down the neck from the head, T1-T13 and L1-L6 from the withers back to the pelvis
	var levels: Array[Dictionary] = []
	var rv := clampf(_torso_m * 0.034, 0.008, 0.06)
	for i in 26:
		var p: Vector3
		var bone: String
		var ax: Vector3
		var nm: String
		if i < 7:
			var t := (float(i) + 0.5) / 7.0
			var rn := neck.duplicate()
			rn.reverse()
			var c := _chain_at(rn, t * 0.92 + 0.04)
			p = c[0]
			bone = c[1]
			ax = (_chain_at(rn, minf(t * 0.92 + 0.08, 1.0))[0] as Vector3 - (_chain_at(rn, maxf(t * 0.92, 0.0))[0] as Vector3)).normalized()
			nm = "C%d" % (i + 1)
		else:
			# (T1 at the withers down to T13 a little behind the middle of the back; L1-L6 on to the pelvis)
			var j := i - 7
			var t := 1.0 - (float(j) + 0.5) / 13.0 * 0.62 if j < 13 else 0.38 - (float(j - 13) + 0.5) / 6.0 * 0.38
			var c := _chain_at(spine, t)
			p = c[0]
			bone = c[1]
			ax = along
			nm = "T%d" % (j + 1) if j < 13 else "L%d" % (j - 12)
		var slab := _slab(p, ax, ventral, fb)
		var dep := float(slab.v1) - float(slab.v0)
		var canal := p + ventral * (float(slab.v0) + dep * (0.16 if i < 7 else 0.14))
		var body := canal + ventral * _u(rv * 1.35)
		levels.append({"name": nm, "lvl": i + 1, "p": p, "canal": canal, "body": body, "bone": bone, "ax": ax, "slab": slab})
	for L: Dictionary in levels:
		var nm := "%s vertebra" % String(L.name)
		var i := int(L.lvl) - 1
		var ex := {"sub": "vertebra", "brk": BRK.vertebra * s * s, "lvl": int(L.lvl)}
		var hh := rv * (1.1 if i < 7 else 0.8)
		_add(nm, "bone", L.bone, "cyl", L.body, _frame(L.ax), Vector3(rv, hh, rv * 0.85), ex)
		# the spinous process up toward the back's skin (tall at the withers)
		var top := (L.p as Vector3) + _dorsal * (-float((L.slab as Dictionary).v0) - _u(0.012 * s))
		if i >= 7 and (top - (L.canal as Vector3)).dot(_dorsal) > _u(0.01):
			# (the arch round the canal carries a break into the cord; the spinous process on to the back does not)
			var arch_end := (L.canal as Vector3).lerp(top, 0.25)
			_cap(nm, "bone", L.bone, L.canal, arch_end, rv * 0.45, ex.merged({"brk": BRK.arch * s * s}))
			_cap(nm, "bone", L.bone, arch_end, top, rv * 0.35, ex.merged({"sub": "process", "brk": BRK.arch * s * s}))
	for i in range(1, levels.size()):
		_cap("Spinal cord", "cord", levels[i].bone, levels[i - 1].canal, levels[i].canal, rv * 0.3, {"lvl": int(levels[i].lvl)})
	# --- the skull round the brain, the face, the jaw
	var hb := _rest("Head")
	var hm := _torso_m * 0.22
	var hdir := fwd
	var cran_c := hb + hdir * _u(hm * 0.35) + up * _u(hm * 0.08)
	var cran_r := Vector3(hm * 0.34, hm * 0.32, hm * 0.42)
	_add("Skull", "bone", "Head", "shell", cran_c, _frame(hdir), Vector3(cran_r.x, cran_r.z, cran_r.y), {"sub": "skull", "brk": BRK.skull * s * s, "th": hm * 0.04})
	var muzzle_a := cran_c + hdir * _u(cran_r.z * 0.8)
	var muzzle_b := hb + hdir * _u(hm * 1.5) - up * _u(hm * 0.12)
	_add("Skull", "bone", "Head", "box", (muzzle_a + muzzle_b) * 0.5, _frame(muzzle_b - muzzle_a, left), Vector3(hm * 0.24, muzzle_a.distance_to(muzzle_b) * k * 0.5, hm * 0.26),
			{"sub": "skull", "brk": BRK.face * s * s, "top": Vector2(hm * 0.12, hm * 0.13)})
	_add("Brain", "organ", "Head", "ell", cran_c, _frame(hdir), Vector3(cran_r.x, cran_r.z, cran_r.y) * 0.8)
	_cap("Brainstem", "organ", "Head", cran_c - hdir * _u(cran_r.z * 0.6) - up * _u(cran_r.y * 0.2), levels[0].canal, hm * 0.06)
	for sd: float in [1.0, -1.0]:
		_cap("Jaw", "bone", "Head", cran_c - up * _u(cran_r.y * 0.9) + left * _u(cran_r.x * 0.6 * sd), muzzle_b - up * _u(hm * 0.3) + left * _u(hm * 0.05 * sd), hm * 0.06,
				{"sub": "jaw", "brk": BRK.jaw * s * s})
	# --- the ribs (1-13 each side) round the chest, sloping back as they go down; the sternum along the chest's floor
	var st_pts: Array[Vector3] = []
	for ri in 13:
		var L: Dictionary = levels[7 + ri]
		var slab: Dictionary = L.slab
		var p := L.p as Vector3
		var th_end := PI - 0.1 if ri < 8 else lerpf(2.7, 1.9, float(ri - 8) / 4.0)
		var c := p + ventral * ((float(slab.v0) + float(slab.v1)) * 0.5)
		var wall := _u(0.018 * s)
		var ra := maxf(float(slab.hw) - wall, _u(0.05 * s))
		var rb := maxf((float(slab.v1) - float(slab.v0)) * 0.5 - wall, _u(0.05 * s))
		for sd: float in [1.0, -1.0]:
			var pts: Array = [(L.canal as Vector3) + left * _u(rv * 1.6 * sd)]
			for j in 4:
				var th := 0.35 + (th_end - 0.35) * float(j) / 3.0
				var q := c + left * (ra * sin(th) * sd) - ventral * (rb * cos(th)) - along * (rb * 0.35 * (th / PI))
				pts.append(q)
			_chain(_side_name(sd, "rib %d" % (ri + 1)), "bone", L.bone, pts, clampf(_torso_m * 0.011, 0.004, 0.02),
					{"sub": "rib", "brk": BRK.rib * s * s, "lvl": ri + 1, "side": "l" if sd > 0.0 else "r"})
			if sd > 0.0 and ri < 8:
				st_pts.append((pts[-1] as Vector3) - left * (pts[-1] as Vector3).dot(left) + left * pelvis.dot(left))
	if st_pts.size() >= 2:
		var a := st_pts[0]
		var b := st_pts[-1]
		_add("Sternum", "bone", "Torso3", "box", (a + b) * 0.5, _frame(a - b, left), Vector3(_torso_m * 0.03, a.distance_to(b) * k * 0.5, _torso_m * 0.012),
				{"sub": "flat", "brk": BRK.sternum * s * s, "top": Vector2(_torso_m * 0.03, _torso_m * 0.012)})
	# --- the legs: the scapula and the foreleg's bones, the pelvis and the hind leg's
	for sd: float in [1.0, -1.0]:
		var sfx := ".L" if sd > 0.0 else ".R"
		var ex := {"side": "l" if sd > 0.0 else "r"}
		var sx := {"side": "l" if sd > 0.0 else "r", "limb": "leg"}
		var fu := "FrontUpperLeg" + sfx
		var fl := "FrontLowerLeg" + sfx
		var bl := "BackLeg" + sfx
		var bu := "BackUpperLeg" + sfx
		var bw := "BackLowerLeg" + sfx
		var r_long := clampf(_torso_m * 0.022, 0.006, 0.045)
		if _has(fu) and _has(fl):
			var j := _rest(fu)
			var kn := _rest(fl)
			var wither := shoulders + _dorsal * _u(_torso_m * 0.05) + left * _u(_width_m * 0.3 * sd)
			var sc_c := j.lerp(wither, 0.5)
			_add(_side_name(sd, "scapula"), "bone", "FrontShoulder" + sfx if _has("FrontShoulder" + sfx) else fu, "box", sc_c, _frame(wither - j, fwd),
					Vector3(_torso_m * 0.03, j.distance_to(wither) * k * 0.5, _torso_m * 0.008), ex.merged({"sub": "flat", "brk": BRK.scapula * s * s, "top": Vector2(_torso_m * 0.09, _torso_m * 0.008)}))
			var split := j.lerp(kn, 0.42)
			_cap(_side_name(sd, "humerus"), "bone", fu, j, split, r_long * 1.15, sx.merged({"sub": "long", "brk": BRK.humerus * s * s}))
			_cap(_side_name(sd, "radius"), "bone", fu, split, kn, r_long, sx.merged({"sub": "long", "brk": BRK.radius * 2.0 * s * s}))
			var gnd := kn - up * maxf(kn.dot(up) - _floor, _u(0.04))
			_cap(_side_name(sd, "fore cannon"), "bone", fl, kn, gnd, r_long * 0.75, sx.merged({"sub": "long", "brk": BRK.cannon * s * s}))
			# flesh: the upper foreleg thick, the lower thin
			_cap(_side_name(sd, "foreleg"), "flesh", fu, j, kn, _limb_r(j, kn, 0.35, fwd, _torso_m * 0.075), ex)
			_cap(_side_name(sd, "fore shank"), "flesh", fl, kn, gnd, _torso_m * 0.03, ex)
		if _has(bl) and _has(bu) and _has(bw):
			var hipj := _rest(bl)
			var stifle := _rest(bu)
			var hock := _rest(bw)
			var gnd := hock - up * maxf(hock.dot(up) - _floor, _u(0.04))
			_cap(_side_name(sd, "femur"), "bone", bl, hipj, stifle, r_long * 1.2, sx.merged({"sub": "long", "brk": BRK.femur * s * s}))
			_cap(_side_name(sd, "tibia"), "bone", bu, stifle, hock, r_long, sx.merged({"sub": "long", "brk": BRK.tibia * s * s}))
			_cap(_side_name(sd, "hind cannon"), "bone", bw, hock, gnd, r_long * 0.75, sx.merged({"sub": "long", "brk": BRK.cannon * s * s}))
			# the pelvis: the ilium forward and up to the hip's point by the spine, the ischium back to the pin bone
			var tuber := pelvis + fwd * _u(_torso_m * 0.08) + left * _u(_width_m * 0.42 * sd) + _dorsal * _u(_torso_m * 0.02)
			var pin := pelvis - fwd * _u(_torso_m * 0.2) + left * _u(_width_m * 0.18 * sd) - _dorsal * _u(_torso_m * 0.02)
			_cap("Pelvis", "bone", "Back", hipj, tuber, r_long * 1.3, ex.merged({"sub": "pelvis", "brk": BRK.ilium * s * s}))
			_cap("Pelvis", "bone", "Back", hipj, pin, r_long * 1.1, ex.merged({"sub": "pelvis", "brk": BRK.ilium * s * s}))
			_add("Pelvis", "bone", "Back", "ell", hipj, _frame(up), Vector3.ONE * r_long * 2.2, ex.merged({"sub": "pelvis", "brk": BRK.acetabulum * s * s}))
			_cap(_side_name(sd, "haunch"), "flesh", bl, hipj + _dorsal * _u(_torso_m * 0.05), stifle, _limb_r(hipj, stifle, 0.4, fwd, _torso_m * 0.11), ex)
			_cap(_side_name(sd, "gaskin"), "flesh", bu, stifle, hock, _limb_r(stifle, hock, 0.4, fwd, _torso_m * 0.055), ex)
			_cap(_side_name(sd, "hind shank"), "flesh", bw, hock, gnd, _torso_m * 0.03, ex)
	var sac_a := pelvis
	var sac_b := pelvis - along * _u(_torso_m * 0.22)
	_add("Sacrum", "bone", "Back", "box", (sac_a + sac_b) * 0.5, _frame(sac_a - sac_b), Vector3(rv * 1.6, sac_a.distance_to(sac_b) * k * 0.5, rv),
			{"sub": "pelvis", "brk": BRK.sacrum * s * s, "top": Vector2(rv * 2.4, rv)})
	# --- the organs (a part of the way from the pelvis to the shoulders)
	var organs := [
		["Heart", 0.8, 0.68, 0.0, Vector3(0.11, 0.07, 0.13)],
		["Left lung", 0.8, 0.42, 0.5, Vector3(0.15, 0.17, 0.2)],
		["Right lung", 0.8, 0.42, -0.5, Vector3(0.15, 0.17, 0.2)],
		["Liver", 0.6, 0.5, -0.35, Vector3(0.14, 0.09, 0.16)],
		["Stomach", 0.58, 0.58, 0.35, Vector3(0.15, 0.1, 0.17)],
		["Left kidney", 0.45, 0.22, 0.35, Vector3(0.05, 0.05, 0.04)],
		["Right kidney", 0.45, 0.22, -0.35, Vector3(0.05, 0.05, 0.04)],
		["Intestines", 0.3, 0.6, 0.0, Vector3(0.2, 0.15, 0.18)],
	]
	var heart_c := Vector3.ZERO
	for o: Array in organs:
		var c := _chain_at(spine, float(o[1]))
		var at: Vector3 = c[0]
		var slab := _slab(at, along, ventral, fb)
		var dep := float(slab.v1) - float(slab.v0)
		var hw := float(slab.hw)
		var cc := at + ventral * (float(slab.v0) + dep * float(o[2])) + left * (float(o[3]) * hw)
		var rr := (o[4] as Vector3) * _torso_m
		rr.x = minf(rr.x, maxf(hw * k * (1.0 - absf(float(o[3])) * 0.5), 0.02))
		rr.z = minf(rr.z, dep * k * 0.42)
		_add(String(o[0]), "organ", c[1], "ell", cc, _frame(along), rr)
		if String(o[0]) == "Heart":
			heart_c = cc
	# --- the vessels: the aorta from the heart up to the spine and back under it, the vena cava, the carotids and jugulars up
	# the neck, the femorals inside the thighs, the brachials inside the forelegs
	var ART := {"vessel": "artery"}
	var VN := {"vessel": "vein"}
	var under := func(L: Dictionary, below: float, lat: float) -> Vector3:
		return (L.body as Vector3) + ventral * _u(rv * 0.9 + below * s) + left * _u(lat * s)
	var ao: Array = [heart_c + _dorsal * _u(_torso_m * 0.06)]
	var ao_b: Array = [levels[9].bone]
	for li: int in [9, 13, 17, 21, 25]:
		ao.append(under.call(levels[li], 0.012, 0.008))
		ao_b.append(levels[li].bone)
	_chain("Aorta", "vessel", ao_b, ao, clampf(_torso_m * 0.022, 0.005, 0.03), ART)
	var vc: Array = [heart_c - along * _u(_torso_m * 0.06)]
	var vc_b: Array = [levels[13].bone]
	for li: int in [15, 19, 23, 25]:
		vc.append(under.call(levels[li], 0.016, -0.012))
		vc_b.append(levels[li].bone)
	_chain("Vena cava", "vessel", vc_b, vc, clampf(_torso_m * 0.025, 0.006, 0.035), VN)
	for sd: float in [1.0, -1.0]:
		var sx := {"side": "l" if sd > 0.0 else "r"}
		var car: Array = [heart_c + _dorsal * _u(_torso_m * 0.08) + along * _u(_torso_m * 0.06)]
		var car_b: Array = [levels[7].bone]
		var jug: Array = [car[0] + left * _u(0.02 * s * sd)]
		for li: int in [6, 4, 2, 0]:
			car.append(under.call(levels[li], 0.02, 0.02 * sd))
			car_b.append(levels[li].bone)
			jug.append(under.call(levels[li], 0.045, 0.03 * sd))
		_chain(_side_name(sd, "carotid artery"), "vessel", car_b, car, clampf(_torso_m * 0.008, 0.002, 0.012), ART.merged(sx))
		_chain(_side_name(sd, "jugular vein"), "vessel", car_b, jug, clampf(_torso_m * 0.011, 0.003, 0.016), VN.merged(sx))
		var sfx := ".L" if sd > 0.0 else ".R"
		if _has("BackLeg" + sfx) and _has("BackUpperLeg" + sfx):
			var hipj := _rest("BackLeg" + sfx)
			var stifle := _rest("BackUpperLeg" + sfx)
			var med := -left * sd
			var fork: Vector3 = ao[-1]
			var fa := [fork, hipj + med * _u(0.03 * s) + fwd * _u(0.02 * s), hipj.lerp(stifle, 0.55) + med * _u(0.025 * s), stifle - fwd * _u(0.03 * s)]
			_chain(_side_name(sd, "femoral artery"), "vessel", ["Back", "BackLeg" + sfx, "BackLeg" + sfx], fa, clampf(_torso_m * 0.007, 0.002, 0.01), ART.merged(sx))
			var fv: Array = []
			for p: Vector3 in fa:
				fv.append(p + med * _u(0.01 * s) - fwd * _u(0.006 * s))
			_chain(_side_name(sd, "femoral vein"), "vessel", ["Back", "BackLeg" + sfx, "BackLeg" + sfx], fv, clampf(_torso_m * 0.009, 0.003, 0.013), VN.merged(sx))
		if _has("FrontUpperLeg" + sfx) and _has("FrontLowerLeg" + sfx):
			var j := _rest("FrontUpperLeg" + sfx)
			var kn := _rest("FrontLowerLeg" + sfx)
			var med := -left * sd
			var ba := [heart_c + _dorsal * _u(_torso_m * 0.08), j + med * _u(0.035 * s), j.lerp(kn, 0.6) + med * _u(0.02 * s) - fwd * _u(0.01 * s)]
			_chain(_side_name(sd, "brachial artery"), "vessel", [levels[7].bone, "FrontUpperLeg" + sfx], ba, clampf(_torso_m * 0.007, 0.002, 0.01), ART.merged(sx))
	# --- the flesh: the trunk in slabs from the haunches to the breast, the neck, the head
	var n_sl := 10
	for i in n_sl:
		var t0 := -0.2 + 1.35 * float(i) / float(n_sl)
		var t1 := -0.2 + 1.35 * float(i + 1) / float(n_sl)
		var tm := (t0 + t1) * 0.5
		var at := pelvis.lerp(shoulders, tm)
		var bone := String(_chain_at(spine, clampf(tm, 0.0, 1.0))[1])
		var slab := _slab(at, along, ventral, fb)
		var c := at + ventral * ((float(slab.v0) + float(slab.v1)) * 0.5)
		var half := pelvis.distance_to(shoulders) * (t1 - t0) * 0.5 * k + 0.01
		_add("Barrel" if tm < 0.75 else "Chest", "flesh", bone, "cyl", c, _frame(along), Vector3(float(slab.hw) * k, half, (float(slab.v1) - float(slab.v0)) * k * 0.5))
	for i in 3:
		var t0 := float(i) / 3.0
		var t1 := float(i + 1) / 3.0
		var a: Vector3 = _chain_at(neck, t0)[0]
		var b: Vector3 = _chain_at(neck, t1)[0]
		var ax := (b - a).normalized()
		var mid := (a + b) * 0.5
		var slab := _slab(mid, ax, ventral, {"v0": -_u(_torso_m * 0.08), "v1": _u(_torso_m * 0.1), "hw": _u(_torso_m * 0.08)})
		var c := mid + ventral * ((float(slab.v0) + float(slab.v1)) * 0.5)
		_add("Neck", "flesh", String(_chain_at(neck, (t0 + t1) * 0.5)[1]), "cyl", c, _frame(ax), Vector3(float(slab.hw) * k, a.distance_to(b) * k * 0.5 + 0.01, (float(slab.v1) - float(slab.v0)) * k * 0.5))
	_add("Head", "flesh", "Head", "ell", (cran_c + muzzle_b) * 0.5, _frame(muzzle_b - cran_c, left), Vector3(cran_r.x * 1.25, (cran_c.distance_to(muzzle_b) * k * 0.5 + cran_r.z * 0.8), cran_r.y * 1.4))
