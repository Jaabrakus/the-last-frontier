extends SceneTree
## The baby's 11 animations, authored in code on the game's own Actor_B skeleton (no Blender): each clip is sampled at 24 fps from a
## pose function (forward kinematics on the skeleton itself, from the game's bind pose `null-add` in the clips' own bone axes, with the
## newborn's proportions (ChildProportion.rig: the bones' offsets as the baby's body has them): limbs aimed at directions, the trunk
## and head turned about the skeleton's axes) and written as an Animation on the bone tracks ("Skeleton3D:<bone>") into the library
## assets/baby/baby_anims.res, with assets/baby/MANIFEST.json (bones, animations, lengths, kinds). The character is standing in the skeleton's axes (x its left,
## y up, z front); the lying clips are turned onto the back by BabyBody.frame (adult up = the baby's long axis), the upright ones
## (sit_wobble, crawl, toddle) stand it on the floor: their root height is keyed so the lowest contact touches y = 0.
##   Godot --headless --path . -s tools/baby/make_baby_anims.gd
## Lying clips (swaddled ones keep the limbs near the body): idle_breathe sleep wake_yawn fuss cry suckle burp_pat kick_play.
## Upright: sit_wobble crawl toddle.

const OUT := "res://assets/baby/baby_anims.res"
const MANIFEST := "res://assets/baby/MANIFEST.json"
const FPS := 24.0

var sk: Skeleton3D
var idx := {}
var props: ChildProportion
var bind_local: Array = []     ## bone -> [position, rotation, scale] of the bind pose (null-add), in the clips' axes
var anim_bones: Array = []
var curl_sign := {"l": 1.0, "r": 1.0}

const CHILD := {
	"l_shoulder": "l_elbow", "l_elbow": "l_wrist", "r_shoulder": "r_elbow", "r_elbow": "r_wrist",
	"l_upper_leg": "l_knee", "l_knee": "l_ankle", "r_upper_leg": "r_knee", "r_knee": "r_ankle",
}
const FINGERS := ["index", "middle", "ring", "pinky"]
## Bones the clips animate (rotation tracks).
const BONES := ["root", "pelvis", "spinea", "spineb", "spinec", "spined", "neck", "heada", "headb", "jaw",
		"l_clavicle", "l_shoulder", "l_elbow", "l_wrist", "l_palm", "r_clavicle", "r_shoulder", "r_elbow", "r_wrist", "r_palm",
		"l_upper_leg", "l_knee", "l_ankle", "l_heel", "r_upper_leg", "r_knee", "r_ankle", "r_heel"]

## left-side directions (right = x mirrored): upper arm, forearm, thigh, shin. "swaddled" keeps them near the body.
const SW_U := Vector3(0.32, -0.85, 0.35)
const SW_F := Vector3(0.0, 0.4, 0.9)
const SW_T := Vector3(0.06, -1.0, 0.1)
const SW_S := Vector3(0.03, -1.0, 0.02)
const NB_U := Vector3(0.6, -0.5, 0.55)
const NB_F := Vector3(0.1, 0.55, 0.75)
const NB_T := Vector3(0.5, -0.35, 0.8)
const NB_S := Vector3(0.2, -0.85, -0.3)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var ps := load("res://characters/Actor_B.tscn") as PackedScene
	var m := ps.instantiate() as Node3D
	root.add_child(m)
	sk = m.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for i in sk.get_bone_count():
		idx[sk.get_bone_name(i)] = i
	for f in FINGERS:
		for side in ["l", "r"]:
			for part in ["a", "b", "c"]:
				anim_bones.append("%s_%s%s" % [side, f, part])
	for side in ["l", "r"]:
		for part in ["a", "b", "c"]:
			anim_bones.append("%s_thumb%s" % [side, part])
	anim_bones.append_array(BONES)
	var ap := m.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var bind_g := CharacterBodyMesh.bind_pose_globals(sk, ap.get_animation("actor_b/null-add"))
	for i in sk.get_bone_count():
		var par := sk.get_bone_parent(i)
		var gi: Transform3D = bind_g[i]
		var loc := gi if par < 0 else (bind_g[par] as Transform3D).affine_inverse() * gi
		bind_local.append([loc.origin, loc.basis.get_rotation_quaternion(), loc.basis.get_scale()])
	props = ChildProportion.attach(sk)
	props.rig(sk, bind_g, ChildLook.stage_form("newborn"))
	_find_curl()
	var lib := AnimationLibrary.new()
	var info := []
	for spec: Array in ANIMS():
		var a := _make(spec[0], float(spec[1]), spec[2], bool(spec[3]))
		lib.add_animation(spec[0], a)
		info.append({"name": spec[0], "length": snappedf(a.length, 0.0001), "loop": bool(spec[3]), "kind": String(spec[4])})
		print("anim ", spec[0], " ", a.length)
	DirAccess.make_dir_recursive_absolute("res://assets/baby")
	var err := ResourceSaver.save(lib, OUT)
	print("saved ", OUT, " err ", err)
	var mf := {"format": "frontier-baby-anims", "generator": "tools/baby/make_baby_anims.gd", "library": "baby", "fps": FPS,
			"skeleton": "characters/Actor_B.tscn (body v4), tracks Skeleton3D:<bone>", "bones": anim_bones, "animations": info,
			"attachments": {"chest": "spined", "head": "headb", "feet": ["l_heel", "r_heel"], "hands": ["l_wrist", "r_wrist"], "neck": "neck",
					"root": "root"},
			"frames": {"lying": "BabyBody.frame turns the standing character onto its back (head +x, front +y, left +z)",
					"ground": "upright, front toward -x, the origin on the floor (root height keyed)"}}
	var f := FileAccess.open(MANIFEST, FileAccess.WRITE)
	f.store_string(JSON.stringify(mf, "  "))
	f.close()
	print("MAKE BABY ANIMS DONE")
	quit()


# ---------------------------------------------------------------------------------------------------- the FK helpers
## A bone's global (skeleton space) as the baby's body has it: the pose with the newborn's offsets.
func _g(i: int) -> Transform3D:
	return props.posed_global(sk.get_bone_name(i))


func _pb(i: int) -> Basis:
	var p := sk.get_bone_parent(i)
	return _g(p).basis.orthonormalized() if p >= 0 else Basis()


## The bind pose (null-add) in the clips' own bone axes (the skeleton's rest has other axes).
func reset() -> void:
	for i in sk.get_bone_count():
		var b: Array = bind_local[i]
		sk.set_bone_pose_position(i, b[0])
		sk.set_bone_pose_rotation(i, b[1])
		sk.set_bone_pose_scale(i, b[2])


## Turns `bone` by skeleton-axis euler degrees about its head (parents as they are now).
func rot(bone: String, deg: Vector3) -> void:
	if not idx.has(bone):
		return
	var i: int = idx[bone]
	var r := Basis.from_euler(deg * (PI / 180.0), EULER_ORDER_XYZ)
	var nb := _pb(i).inverse() * r * _g(i).basis.orthonormalized()
	sk.set_bone_pose_rotation(i, nb.get_rotation_quaternion())


## Turns `bone` in its own frame.
func lrot(bone: String, axis: Vector3, deg: float) -> void:
	var i: int = idx[bone]
	sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i) * Quaternion(axis, deg * PI / 180.0))


## Points a limb bone (toward its child joint) along `dir` (skeleton space).
func aim(bone: String, dir: Vector3) -> void:
	var i: int = idx[bone]
	var c: int = idx[CHILD[bone]]
	var cur := (_g(c).origin - _g(i).origin).normalized()
	var q := Quaternion(cur, dir.normalized())
	var nb := _pb(i).inverse() * Basis(q) * _g(i).basis.orthonormalized()
	sk.set_bone_pose_rotation(i, nb.get_rotation_quaternion())


func mir(v: Vector3, side: String) -> Vector3:
	return v if side == "l" else Vector3(-v.x, v.y, v.z)


func arm(side: String, u: Vector3, f: Vector3) -> void:
	aim(side + "_shoulder", mir(u, side))
	aim(side + "_elbow", mir(f, side))


func leg(side: String, t: Vector3, s: Vector3) -> void:
	aim(side + "_upper_leg", mir(t, side))
	aim(side + "_knee", mir(s, side))


func _find_curl() -> void:
	# which way about a finger's local X curls it toward the palm (the tip nearer the wrist), per side
	for side in ["l", "r"]:
		reset()
		var a := "%s_indexa" % side
		var tip: int = idx["%s_indexc" % side]
		var wr: int = idx["%s_wrist" % side]
		var d0 := (_g(tip).origin - _g(wr).origin).length()
		lrot(a, Vector3(1, 0, 0), 40.0)
		var d1 := (_g(tip).origin - _g(wr).origin).length()
		curl_sign[side] = 1.0 if d1 < d0 else -1.0
	reset()


## Fists (k 0 open .. 1 tight); the thumb tucks across.
func curl(side: String, k: float) -> void:
	var sg: float = curl_sign[side]
	for f in FINGERS:
		for part: Array in [["a", 55.0], ["b", 80.0], ["c", 50.0]]:
			lrot("%s_%s%s" % [side, f, part[0]], Vector3(1, 0, 0), sg * float(part[1]) * k)
	for part: Array in [["a", 25.0], ["b", 35.0], ["c", 25.0]]:
		lrot("%s_thumb%s" % [side, part[0]], Vector3(1, 0, 0), sg * float(part[1]) * k * 0.6)


## The jaw open (0..1) and the head: nod (+ chin down), turn (+ to its left), tilt (+ to its right).
func head(nod: float, turn: float, tilt: float, jaw := 0.0) -> void:
	rot("neck", Vector3(nod * 0.35, turn * 0.35, tilt * 0.35))
	rot("heada", Vector3(nod * 0.65, turn * 0.65, tilt * 0.65))
	rot("jaw", Vector3(22.0 * jaw, 0, 0))


func s(t: float, T: float, k := 1.0, ph := 0.0) -> float:
	return sin(TAU * (k * t / T + ph))


func c(t: float, T: float, k := 1.0, ph := 0.0) -> float:
	return cos(TAU * (k * t / T + ph))


func pulse(t: float, t0: float, dur: float) -> float:
	var u := (t - t0) / dur
	return sin(PI * u) if u >= 0.0 and u <= 1.0 else 0.0


func trap(t: float, a: float, b: float, cc: float, d: float) -> float:
	return smoothstep(a, b, t) * (1.0 - smoothstep(cc, d, t))


# ---------------------------------------------------------------------------------------------------- the clips
func ANIMS() -> Array:
	return [
		["idle_breathe", 2.5, _idle, true, "lying"], ["sleep", 4.0, _sleep, true, "lying"], ["wake_yawn", 3.2, _yawn, false, "lying"],
		["fuss", 2.0, _fuss, true, "lying"], ["cry", 1.2, _cry, true, "lying"], ["suckle", 1.5, _suckle, true, "lying"],
		["burp_pat", 1.7, _burp, false, "lying"], ["kick_play", 3.0, _kick, true, "lying"],
		["sit_wobble", 3.0, _sit, true, "ground"], ["crawl", 1.2, _crawl, true, "ground"], ["toddle", 1.2, _toddle, true, "ground"],
	]


## The swaddled base: arms folded up to the chin over the blanket's rim, legs together.
func _swaddled(t: float, T: float, drift := 1.0) -> void:
	for side in ["l", "r"]:
		var ph := 0.0 if side == "l" else 0.4
		arm(side, SW_U + Vector3(0.03, 0.02, 0.02) * s(t, T, 1, ph) * drift, SW_F + Vector3(0.02, 0.03, 0.02) * s(t, T, 1, ph + 0.2) * drift)
		leg(side, SW_T, SW_S)
		curl(side, 0.85)
	rot("spined", Vector3(-1.2 * (0.5 - 0.5 * c(t, T)), 0, 0))


func _idle(t: float, T: float) -> void:
	_swaddled(t, T)
	head(1.5 * s(t, T, 1, 0.1), 2.5 * s(t, T, 1, 0.5), 1.5 * s(t, T, 1, 0.3), 0.02)


func _sleep(t: float, T: float) -> void:
	for side in ["l", "r"]:
		var ph := 0.0 if side == "l" else 0.25
		arm(side, Vector3(0.3, -0.9, 0.25), Vector3(-0.2, 0.25, 0.95) + Vector3(0, 0.02, 0) * s(t, T, 1, ph))
		leg(side, SW_T, SW_S)
		curl(side, 0.55 + 0.05 * s(t, T, 1, ph))
	head(2.0, -9.0 + 0.8 * s(t, T, 1, 0.3), 4.0, 0.08 + 0.02 * s(t, T, 1, 0.1) + 0.05 * pulse(t, 2.4, 0.5))
	rot("spined", Vector3(-0.8 * (0.5 - 0.5 * c(t, T)), 0, 0))


func _yawn(t: float, T: float) -> void:
	var y := trap(t, 0.45, 1.05, 1.55, 2.05)
	var st := trap(t, 0.5, 1.1, 1.5, 2.3)
	_swaddled(t, T, 0.6)
	for side in ["l", "r"]:
		arm(side, SW_U.lerp(Vector3(0.75, 0.1, 0.5), st), SW_F.lerp(Vector3(0.2, 0.7, 0.6), st))
		curl(side, 0.85 - 0.6 * st)
	head(-10.0 * st, 4.0 * (1 - st) * s(t, T, 1, 0.1), 2.0, 0.08 + 0.9 * y)
	rot("spinea", Vector3(-4.0 * st, 0, 0))
	rot("spineb", Vector3(-3.0 * st, 0, 0))


func _fuss(t: float, T: float) -> void:
	for side in ["l", "r"]:
		var ph := 0.0 if side == "l" else 0.5
		arm(side, SW_U + Vector3(0.1, 0.1, 0.15) * s(t, T, 2, ph), SW_F + Vector3(0.1, 0.15, -0.1) * s(t, T, 2, ph + 0.25))
		leg(side, SW_T + Vector3(0.05, 0.0, 0.1) * s(t, T, 2, ph + 0.3), SW_S)
		curl(side, 0.9)
	head(2.0 * s(t, T, 2, 0.2), 12.0 * s(t, T, 1, 0.0), 3.0 * s(t, T, 1, 0.25), 0.15 + 0.15 * (0.5 + 0.5 * s(t, T, 3, 0.0)))
	rot("spinea", Vector3(0, 3.0 * s(t, T, 1, 0.0), 4.0 * s(t, T, 1, 0.25)))
	rot("spined", Vector3(-1.5 * (0.5 - 0.5 * c(t, T, 2)), 0, 0))


func _cry(t: float, T: float) -> void:
	for side in ["l", "r"]:
		var ph := 0.0 if side == "l" else 0.5
		arm(side, Vector3(0.5, -0.55, 0.55) + Vector3(0.3, 0.2, 0.15) * s(t, T, 2, ph), Vector3(-0.1, 0.75, 0.5) + Vector3(0.2, 0.2, 0.15) * s(t, T, 2, ph + 0.2))
		leg(side, SW_T + Vector3(0.06, 0.0, 0.14) * s(t, T, 2, ph + 0.3), SW_S + Vector3(0.0, 0.0, 0.05) * s(t, T, 2, ph))
		curl(side, 1.0)
	head(-5.0 + 3.0 * s(t, T, 2, 0.1), 13.0 * s(t, T, 1, 0.0), 8.0 * s(t, T, 1, 0.25), 0.7 + 0.15 * c(t, T, 2))
	rot("spinea", Vector3(0, 4.0 * s(t, T, 1, 0.0), 3.0 * s(t, T, 1, 0.25)))
	rot("spined", Vector3(-3.0 * (0.5 - 0.5 * c(t, T, 3)), 0, 0))


func _suckle(t: float, T: float) -> void:
	var su := 0.5 - 0.5 * cos(TAU * 3.0 * t / T)
	for side in ["l", "r"]:
		var ph := 0.0 if side == "l" else 0.5
		var kn := s(t, T, 1, ph)
		arm(side, SW_U + Vector3(0.0, 0.05, 0.05), Vector3(-0.5, 0.45, 0.75) + Vector3(0.05, 0.12, 0.0) * kn)
		leg(side, SW_T, SW_S)
		curl(side, 0.55 + 0.35 * (0.5 + 0.5 * kn))
	head(-1.5 * su + 2.0 * pulse(t, 1.0, 0.4), 0.0, 1.5 * s(t, T, 1, 0.3), 0.06 + 0.16 * su)


func _burp(t: float, T: float) -> void:
	var j1 := pulse(t, 0.35, 0.22)
	var j2 := pulse(t, 0.95, 0.22)
	var jk := j1 + j2
	_swaddled(t, T, 0.8)
	for side in ["l", "r"]:
		arm(side, SW_U + Vector3(0.15, 0.1, 0.1) * jk, SW_F + Vector3(0.1, 0.1, -0.1) * jk)
		curl(side, 0.85)
	head(-4.0 * jk + 3.0 * trap(t, 0.9, 1.1, 1.3, 1.6), 2.5 * (j1 - j2), 3.0 * jk, 0.06 + 0.4 * pulse(t, 1.0, 0.45))
	rot("spined", Vector3(-4.0 * jk, 0, 0))
	rot("spineb", Vector3(-2.5 * jk, 0, 0))


func _kick(t: float, T: float) -> void:
	for side in ["l", "r"]:
		var ph := 0.0 if side == "l" else 0.5
		var k := s(t, T, 4, ph)
		leg(side, NB_T + Vector3(0.0, 0.4 * k, 0.0) + Vector3(0.05, 0.0, 0.0), NB_S + Vector3(0.0, -0.4 * s(t, T, 4, ph + 0.15), 0.6 * (0.5 + 0.5 * k)))
		var r := s(t, T, 2, ph + 0.1)
		arm(side, NB_U + Vector3(0.1, 0.25, 0.2) * r, NB_F + Vector3(0.15, 0.2, 0.15) * s(t, T, 2, ph + 0.35))
		curl(side, 0.35 + 0.3 * (0.5 + 0.5 * s(t, T, 4, ph)))
	head(3.0 * s(t, T, 2, 0.1), 14.0 * s(t, T, 1, 0.2), 4.0 * s(t, T, 1, 0.5), 0.28 + 0.12 * s(t, T, 4, 0.1))
	rot("spinea", Vector3(0, 3.0 * s(t, T, 2, 0.0), 0))


# --- upright: the root is raised so the lowest contact touches the floor (keyed by _make)
func _sit(t: float, T: float) -> void:
	var sw := s(t, T, 1, 0.0)
	var sw2 := s(t, T, 1, 0.25)
	for side in ["l", "r"]:
		var sg := 1.0 if side == "l" else -1.0
		leg(side, Vector3(0.3, 0.0, 1.0), Vector3(0.35, -0.85, 0.2))
		arm(side, Vector3(0.8 - 0.1 * sw2, 0.15 + 0.1 * sw * sg, 0.3), Vector3(0.5, 0.5, 0.6))
		curl(side, 0.4)
	rot("root", Vector3(-4.0, 0, 0))
	rot("spinea", Vector3(6.0 * sw2 + 4.0, 0, 6.0 * sw))
	rot("spineb", Vector3(3.0 * sw2, 0, 5.0 * sw))
	head(2.0 - 4.0 * sw2, 6.0 * s(t, T, 2, 0.2), -6.0 * sw, 0.2)


func _crawl(t: float, T: float) -> void:
	var ph := TAU * t / T
	rot("root", Vector3(75.0, 0, 0))
	rot("spinea", Vector3(10.0, 0, 5.0 * sin(ph)))
	rot("spineb", Vector3(4.0, 0, -5.0 * sin(ph)))
	head(-42.0 + 4.0 * sin(2.0 * ph), 0.0, -6.0 * sin(ph), 0.2)
	for side in ["l", "r"]:
		var a := ph + (0.0 if side == "l" else PI)
		arm(side, Vector3(0.15, -0.95 + 0.0, 0.2 + 0.5 * sin(a) - 0.1), Vector3(0.0, -0.95, 0.45 + 0.3 * sin(a)))
		var b := a + PI
		leg(side, Vector3(0.2, -0.3, 0.9 + 0.45 * sin(b)), Vector3(0.1, -0.5 - 0.5 * maxf(0.0, sin(b)), -0.85))
		curl(side, 0.3)


func _toddle(t: float, T: float) -> void:
	var ph := TAU * t / T
	rot("spinea", Vector3(3.0 * sin(ph), 5.0 * sin(ph), 3.0 * sin(ph)))
	rot("spineb", Vector3(2.0 * sin(ph), 0, -4.0 * sin(ph)))
	head(4.0 + 2.0 * cos(2.0 * ph), 4.0 * sin(ph + 1.0), -3.0 * sin(ph), 0.25)
	for side in ["l", "r"]:
		var a := ph + (0.0 if side == "l" else PI)
		var stride := sin(a)
		var lift := maxf(0.0, cos(a))
		leg(side, Vector3(0.15, -1.0, 0.55 * stride), Vector3(0.12, -1.0 + 0.9 * lift, -0.15 * stride - 0.6 * lift))
		arm(side, Vector3(0.85, 0.35, 0.15 + 0.1 * sin(a + 1.0)), Vector3(0.5, 0.75, 0.3))
		curl(side, 0.35)


# ---------------------------------------------------------------------------------------------------- sampling
func _make(name: String, T: float, fn: Callable, loop: bool) -> Animation:
	var a := Animation.new()
	var n := int(round(T * FPS))
	a.length = float(n) / FPS
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var ground: bool = name in ["sit_wobble", "crawl", "toddle"]
	var tracks := {}
	for b: String in anim_bones:
		var tr := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(tr, NodePath("Skeleton3D:%s" % b))
		tracks[b] = tr
	# the root's position keyed in every clip (lying: the bind pose's; upright: the lowest contact on the floor), so a clip after an
	# upright one does not keep its height
	var root_i: int = idx["root"]
	var bind_root: Vector3 = bind_local[root_i][0]
	var pos_track := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(pos_track, NodePath("Skeleton3D:root"))
	for f in n + 1:
		var t := float(f) / FPS * (T / (float(n) / FPS))       # (the last frame is exactly T: a loop closes on its first)
		reset()
		fn.call(t, T)
		var key := bind_root
		if ground:
			# the hips where the body shows them now, lowered by the lowest contact's height; the key the modifier turns into that
			var shown := _g(root_i).origin
			key = props.root_key_for(shown + Vector3(0.0, -_lowest(name), 0.0))
		for b: String in anim_bones:
			a.rotation_track_insert_key(tracks[b], float(f) / FPS, sk.get_bone_pose_rotation(idx[b]))
		a.position_track_insert_key(pos_track, float(f) / FPS, key)
	return a


## The lowest contact of the pose (skeleton units, scaled body): feet, and knees and hands when crawling.
func _lowest(name: String) -> float:
	var low := 1e9
	var pts := [["l_heel", 0.0], ["r_heel", 0.0], ["l_ball", 0.0], ["r_ball", 0.0]]
	if name == "crawl":
		pts = [["l_knee", 0.07], ["r_knee", 0.07], ["l_ball", 0.0], ["r_ball", 0.0], ["l_palm", 0.04], ["r_palm", 0.04], ["l_ankle", 0.05], ["r_ankle", 0.05]]
	elif name == "sit_wobble":
		pts = [["pelvis", 0.09], ["l_heel", 0.0], ["r_heel", 0.0], ["l_knee", 0.06], ["r_knee", 0.06]]
	for p: Array in pts:
		low = minf(low, _g(idx[p[0]]).origin.y - float(p[1]))
	return low
