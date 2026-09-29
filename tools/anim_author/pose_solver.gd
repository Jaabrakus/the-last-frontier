extends RefCounted
## Poses Actor_B from a few body-space numbers (this project's own animation authoring: tools/anim_author/): the hips
## (the root bone: offset, turn, bend, carrying the pelvis and the spine as the game's clips do), the pelvis's own turn
## under them, the chest over them (one turn, shared out over the four spine bones), the head's turn (shared by
## the neck and the head), the collarbones, a two-handed tool (where the right hand holds it, the haft's way toward the
## head, the edge's way; the left hand further along the haft), the elbows' and the knees' ways, and the feet (where
## they stand, the heel off the ground, their turn). The arms and legs reach by two-bone IK; the fingers curl into a
## fist. Everything starts from the skeleton's rest pose: no clip's data is used by the solver itself.
## Body space: the body faces +Z, its left is +X, up is +Y, metres and degrees; the ground at y 0.
##
## p: {"hips": {"pos": [x,y,z], "yaw", "pitch", "roll"}, "pelvis": {"yaw", "pitch", "roll"},
##     "chest": {"yaw", "pitch", "roll"}, "waist": {...},
##     "head": {"yaw", "pitch", "roll"}, "clav": {"r": [yaw, pitch, roll], "l": [...]},
##     "tool": {"grip": [x,y,z], "haft": [x,y,z], "edge": [x,y,z] | "q": [x,y,z,w],
##              "spread": m | "left": [x,y,z], "lturn": [y,p,r] | "lq": [x,y,z,w], "right": [x,y,z], "rturn" | "rq",
##              "lfree": [x,y,z] (one-handed: the left wrist off the tool, there),
##              "rhand": {"at": [x,y,z], "haft": [x,y,z], "edge": [x,y,z], "rel": Transform3D} (the right hand off the
##              tool, its fist closed on something at `at` along `haft`: a cartridge, a ramrod; "rel", when given, is
##              the frame put there in the wrist's frame (fist_rel(): the curled fingers' hole) instead of the prop
##              bone's) | "rfree": [x,y,z] (its wrist there): the tool stays where the key puts it, carried by the right
##              hand's prop bone (the musket held in the left alone),
##              "lhand": {"at", "haft", "edge", "rel"} (the left fist closed there, as "rhand": the barrel held up),
##              "up": m (hold "blade": how far up the haft from the knob the right hand holds it; GRIP_M when missing)},
##     "elbows": {"r": [x,y,z], "l": [...]}, "knees": {...},
##     "feet": {"l": [x, z, heel_lift, yaw, pitch, roll], "r": [...]}, "fist": 0..1}
## hold (set before pose()): how the tool sits on the right hand's prop bone, as GatherTools holds it in the game:
##   "blade"  the one-hand frame (the haft along the bone's +Y, the edge its -Z, the hand GRIP_M up the haft)
##   "pipe"   the two-handed frame of the pipe clips (the haft along the bone's +Z, the edge its +Y, the hand at the knob)
##   "musket" the musket model on its socket as the game hangs it (FrontierPlayer musket_offset: turned half round Y):
##            the tool's frame is the model's own (the lock at the origin, +Y the barrel's top, -Z to the muzzle, so
##            "haft" is the barrel's top and "edge" the muzzle's way); "right" [0,0,0] with "rq" [0,1,0,0] is the right
##            hand on the grip, "left" the same with "lq" the left hand on the forestock (the prop bones coincide there,
##            as in the rifle clips)
## space (set before pose()): "body" (the default) or "chest": the tool's place and turn and the elbows' ways are in the
## chest's frame (its turn, from the top spine bone), the knees' in the pelvis's, so a body turning carries them round
## as it does (measured keys: fit_ref.gd).
## waist, when given, is the turn up to the middle of the spine (the lower two spine bones share it, the upper two the
## rest of the chest's turn); without it the four share the chest's turn evenly.
## tool.q (a quaternion: measured keys, fit_ref.gd) turns the tool instead of haft and edge; rq / lq turn the hands
## instead of rturn / lturn. tool.grip is where the right hand's prop bone is (the tool hangs on it as GatherTools hangs it). With "right"/"rturn"
## the tool is a thing of its own: the prop bone is set to carry it there and each hand is put on it where those say
## (the hand's own prop frame, as its rest has it, in the tool model's frame). Without them the right hand holds the
## tool at the prop bone's rest place in the hand, turned about the haft toward the edge. With "left"/"lturn" the left
## hand is put exactly in the tool's frame; with "spread" it closes on the haft that far below the right hand, turned
## the way that leads its forearm back to the shoulder.
## "elbows"/"knees" are the ways the joints bend out toward (the solver's defaults when missing).

const SPINE := ["spinea", "spineb", "spinec", "spined"]
const FINGERS := ["index", "middle", "ring", "pinky"]
const GRIP_M := 0.46
## GatherTools.two_hand_offset: the tool model on the prop bone in the pipe clips' two-handed frame.
const PIPE := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)), Vector3(0, 0, -0.035))
## FrontierPlayer's musket_offset: the musket model on its socket (the right hand's prop bone).
const MUSKET := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)

var sk: Skeleton3D
var rest := {}                   ## bone name -> rest global Transform3D (skeleton space)
var hold := "blade"
var space := "body"
## "pipe" (set before pose()): after the hands are on the tool, the right hand's prop bone is set to carry it in the
## pipe clips' two-handed frame (PIPE), wherever the hands hold it, so the game hangs it there as it hangs the clubbed
## musket (the fishing rod: FishingGear.rod_transform; a "blade" hold's hands, placed by _hand, with the tool's place
## the pipe clips' way). "": the prop bone as the hold leaves it.
var carry := ""
## A hand holding the tool ("right") bends at most wrist_bend degrees off its forearm's line and twists at most
## wrist_twist about it; the tool then follows the hand (0: the hand turns as the tool needs; set before pose(). The
## stabs: user 2026-09-27 "the wrist flexes inwards").
var wrist_bend := 0.0
var wrist_twist := 0.0
## The tool model's frame the last pose() put it in (skeleton space).
var tool_world := Transform3D()
var _i := {}


func _init(skeleton: Skeleton3D) -> void:
	sk = skeleton
	sk.reset_bone_poses()
	sk.force_update_all_bone_transforms()
	for b in sk.get_bone_count():
		rest[sk.get_bone_name(b)] = sk.get_bone_global_pose(b)
		_i[sk.get_bone_name(b)] = b


func idx(nm: String) -> int:
	return int(_i.get(nm, -1))


func g(nm: String) -> Transform3D:
	return sk.get_bone_global_pose(idx(nm))


func set_g(nm: String, t: Transform3D) -> void:
	sk.set_bone_global_pose(idx(nm), t)


## Turns a bone (and all under it) by `r` about its own position.
func turn(nm: String, r: Basis) -> void:
	var t := g(nm)
	set_g(nm, Transform3D(r * t.basis, t.origin))


static func euler(yaw: float, pitch: float, roll: float) -> Basis:
	# yaw about +Y (+ turns the face toward the body's left), pitch about +X (+ bends forward), roll about +Z (+ leans
	# toward the body's right... the head goes toward -X)
	return Basis(Vector3.UP, deg_to_rad(yaw)) * Basis(Vector3.RIGHT, deg_to_rad(pitch)) * Basis(Vector3.BACK, deg_to_rad(-roll))


## euler()'s numbers for a turn: [yaw, pitch, roll] in degrees.
static func angles(b: Basis) -> Array:
	var e := b.orthonormalized().get_euler(EULER_ORDER_YXZ)
	return [rad_to_deg(e.y), rad_to_deg(e.x), -rad_to_deg(e.z)]


## A part of a turn (`k` of the way from none to all of it).
static func part(b: Basis, k: float) -> Basis:
	return Basis(Quaternion.IDENTITY.slerp(b.orthonormalized().get_rotation_quaternion(), k))


static func _e(a) -> Basis:
	if a is Dictionary:
		var d: Dictionary = a
		return euler(float(d.get("yaw", 0.0)), float(d.get("pitch", 0.0)), float(d.get("roll", 0.0)))
	var arr: Array = a
	return euler(float(arr[0]), float(arr[1]) if arr.size() > 1 else 0.0, float(arr[2]) if arr.size() > 2 else 0.0)


## The tool model's frame on the right hand's prop bone for `hold`.
static func hold_xf(h: String, up := GRIP_M) -> Transform3D:
	if h == "musket":
		return MUSKET
	return PIPE if h == "pipe" else Transform3D(Basis(), Vector3(0, -up, 0))


## The tool model's transform in body space (its knob at the origin, the haft +Y, the edge -Z) for a pose's "tool".
static func tool_frame(tl: Dictionary, h := "blade") -> Transform3D:
	var grip := _v3(tl.grip)
	var b: Basis
	if tl.has("q"):
		b = _q(tl.q)
	else:
		var haft := _v3(tl.haft).normalized()
		var edge := _v3(tl.get("edge", [0, 0, 1]))
		edge = (edge - haft * edge.dot(haft)).normalized()
		var z := -edge
		var x := haft.cross(z).normalized()
		b = Basis(x, haft, x.cross(haft).normalized())
	var hx := hold_xf(h, float(tl.get("up", GRIP_M)))
	# the prop bone at the grip, turned so the tool's axes come out as asked
	var prop_b := b * hx.basis.inverse()
	return Transform3D(b, grip + prop_b * hx.origin)


## Sets the whole pose (see the top).
func pose(p: Dictionary) -> void:
	sk.reset_bone_poses()
	sk.force_update_all_bone_transforms()
	# the hips: the root carries the pelvis (under lower_base) and the spine (under upper_base) alike
	var hp: Dictionary = p.get("hips", {})
	var rr := g("root")
	var hb := _e(hp)
	set_g("root", Transform3D(hb * rr.basis, rr.origin + _v3(hp.get("pos", [0, 0, 0]))))
	var pr := g("pelvis")
	var pl := _e(p.get("pelvis", {}))
	set_g("pelvis", Transform3D(hb * pl * hb.inverse() * pr.basis, pr.origin))
	var pb := hb * pl
	# the spine's own: the chest over the hips, shared out over its four bones
	var chest := _e(p.get("chest", {}))
	var waist := _e(p.waist) if p.has("waist") else part(chest, 0.5)
	var lo := part(waist, 0.5)
	var hi := part(waist.inverse() * chest, 0.5)
	for k in SPINE.size():
		# (each share about the body's axes as the bones below leave them: the four make the chest's whole turn)
		var nm: String = SPINE[k]
		var t := g(nm)
		var base := hb if k < 2 else hb * waist
		var sh := lo if k < 2 else hi
		set_g(nm, Transform3D(base * sh * base.inverse() * t.basis, t.origin))
	var body := hb * chest
	var chest_xf := Transform3D(body, g("spined").origin)
	var half := part(_e(p.get("head", {})), 0.5)
	for nm: String in ["neck", "headb"]:
		var t := g(nm)
		set_g(nm, Transform3D(body * half * body.inverse() * t.basis, t.origin))
	var cl: Dictionary = p.get("clav", {})
	for side: String in ["r", "l"]:
		if cl.has(side):
			var t := g(side + "_clavicle")
			set_g(side + "_clavicle", Transform3D(body * _e(cl[side]) * body.inverse() * t.basis, t.origin))
	# the legs to the feet
	var ft: Dictionary = p.get("feet", {})
	var kn: Dictionary = p.get("knees", {})
	for side: String in ["l", "r"]:
		if ft.has(side):
			var f: Array = ft[side]
			var kp := _v3(kn[side]) if kn.has(side) else Vector3.ZERO
			_leg(side, f, pb * kp if space == "chest" else kp)
	# the tool in both hands
	var tl: Dictionary = p.get("tool", {})
	var el: Dictionary = p.get("elbows", {})
	if not tl.is_empty():
		var tf := tool_frame(tl, hold)
		var pole_r := _v3(el.r) if el.has("r") else Vector3.ZERO
		var pole_l := _v3(el.l) if el.has("l") else Vector3.ZERO
		if space == "chest":
			tf = chest_xf * tf
			pole_r = body * pole_r
			pole_l = body * pole_l
		tool_world = tf
		var hx := hold_xf(hold, float(tl.get("up", GRIP_M)))
		var grip := (tf * hx.affine_inverse()).origin
		var haft := tf.basis.y.normalized()
		var edge := -tf.basis.z.normalized()
		if tl.has("rhand") or tl.has("rfree"):
			# the right hand off the tool (the prop bone still carries the tool: below)
			if tl.has("rhand"):
				var rh: Dictionary = tl.rhand
				var at := _v3(rh.at)
				var hf := _v3(rh.get("haft", [0, 1, 0])).normalized()
				var ed := _v3(rh.get("edge", [0, 0, 0]))
				if space == "chest":
					at = chest_xf * at
					hf = body * hf
					ed = body * ed
				_hand("r", at, hf, ed, pole_r, rh.get("rel"))
			else:
				var rf := _v3(tl.rfree)
				_arm("r", chest_xf * rf if space == "chest" else rf, pole_r)
		elif tl.has("right"):
			var rxf := Transform3D(_q(tl.rq) if tl.has("rq") else _e(tl.get("rturn", [0, 0, 0])), _v3(tl.right))
			var held := _place("r", tf * rxf, pole_r, wrist_bend > 0.0)
			if wrist_bend > 0.0:
				# (the wrist kept natural: the tool goes where the hand has it)
				tf = held * rxf.affine_inverse()
				tool_world = tf
		elif hold == "pipe":
			_place("r", tf * hold_xf(hold).affine_inverse(), pole_r)
		else:
			_hand("r", grip, haft, edge, pole_r)
		if tl.has("lhand"):
			# the left fist closed on the tool (or anything) at `at` along `haft`, as "rhand" (body space, or the
			# chest's in space "chest"): the musket's barrel held up while the right hand loads it
			var lh: Dictionary = tl.lhand
			var lat := _v3(lh.at)
			var lhf := _v3(lh.get("haft", [0, 1, 0])).normalized()
			var led := _v3(lh.get("edge", [0, 0, 0]))
			if space == "chest":
				lat = chest_xf * lat
				lhf = body * lhf
				led = body * led
			_hand("l", lat, lhf, led, pole_l, lh.get("rel"))
		elif tl.has("lfree"):
			# a one-handed hold: the left hand off the tool, its wrist where lfree says (the body's frame, or the
			# chest's in space "chest")
			var lf := _v3(tl.lfree)
			_arm("l", chest_xf * lf if space == "chest" else lf, pole_l)
		elif tl.has("left"):
			var lt := Transform3D(_q(tl.lq) if tl.has("lq") else _e(tl.get("lturn", [0, 0, 0])), _v3(tl.left))
			_place("l", tf * lt, pole_l)
		else:
			_hand("l", grip - haft * float(tl.get("spread", 0.3)), haft, Vector3.ZERO, pole_l)
		if tl.has("right") or tl.has("rhand") or tl.has("rfree"):
			# the tool's own place: the prop bone carries it there (the bake keys it)
			set_g("r_hand_prop_attachment", tf * hold_xf(hold).affine_inverse())
		elif carry == "pipe":
			set_g("r_hand_prop_attachment", tf * PIPE.affine_inverse())
	_fist(float(p.get("fist", 1.0)))


## A hand's prop bone put exactly at `prop` (skeleton space): the arm reaches its wrist there, the wrist takes its turn.
## `limit`: the hand bent and twisted no further from its forearm than wrist_bend / wrist_twist. Returns where the
## hand's prop frame ends up.
func _place(side: String, prop: Transform3D, pole := Vector3.ZERO, limit := false) -> Transform3D:
	var rel: Transform3D = (rest[side + "_wrist"] as Transform3D).affine_inverse() * rest[side + "_hand_prop_attachment"]
	var w := prop * rel.affine_inverse()
	_arm(side, w.origin, pole)
	var w2 := g(side + "_wrist")
	var b := w.basis
	if limit:
		b = _wrist_limited(side, b)
	set_g(side + "_wrist", Transform3D(b, w2.origin))
	return g(side + "_wrist") * rel


## A wrist's turn `want` (skeleton space) brought within wrist_bend of its forearm's line and wrist_twist about it,
## from the straight wrist (its rest turn under the forearm as it is).
func _wrist_limited(side: String, want: Basis) -> Basis:
	var el := g(side + "_elbow")
	var wr := g(side + "_wrist")
	var straight := el.basis * ((rest[side + "_elbow"] as Transform3D).basis.inverse() * (rest[side + "_wrist"] as Transform3D).basis)
	var axis := (wr.origin - el.origin).normalized()
	var q := (want.orthonormalized() * straight.orthonormalized().inverse()).get_rotation_quaternion()
	var v := Vector3(q.x, q.y, q.z)
	var tw := Quaternion(axis.x * v.dot(axis), axis.y * v.dot(axis), axis.z * v.dot(axis), q.w)
	tw = tw.normalized() if tw.length_squared() > 1e-8 else Quaternion.IDENTITY
	var sw := q * tw.inverse()
	sw = _clamp_q(sw, deg_to_rad(wrist_bend))
	tw = _clamp_q(tw, deg_to_rad(wrist_twist))
	return Basis(sw * tw) * straight


static func _clamp_q(q: Quaternion, most: float) -> Quaternion:
	var a := q.get_angle()
	if a <= most or a < 1e-6:
		return q
	return Quaternion(q.get_axis(), most)


## A hand closed on the haft at `at`: its tool bone's +Y along the haft, rolled round it the way that leads the forearm
## back toward the shoulder (and, given `edge`, that turns the tool's edge, the bone's -Z, that way: the right hand
## carries the tool in the game); then the arm reaches the wrist there (two-bone IK) and the wrist takes the hand's turn.
func _hand(side: String, at: Vector3, haft: Vector3, edge := Vector3.ZERO, pole := Vector3.ZERO, grip: Variant = null) -> void:
	var wr := g(side + "_wrist")
	var prop := g(side + "_hand_prop_attachment")
	# (the tool bone in the wrist's frame: fixed; the palm is not turned) or the frame `grip` gives there
	var rel: Transform3D = grip if grip is Transform3D else wr.affine_inverse() * prop
	var sh := g(side + "_shoulder").origin
	var ref := (sh - at)
	ref = ref - haft * ref.dot(haft)
	if ref.length_squared() < 1e-6:
		ref = Vector3.BACK
	var best := Transform3D()
	var best_d := -INF
	for k in 24:
		var z0 := ref.normalized().rotated(haft, TAU * float(k) / 24.0)
		var x0 := haft.cross(z0).normalized()
		var pf := Transform3D(Basis(x0, haft, x0.cross(haft).normalized()), at)
		var w := pf * rel.affine_inverse()
		var d := (w.origin - at).normalized().dot((sh - at).normalized())
		if edge != Vector3.ZERO:
			d += 0.8 * (-pf.basis.z).dot(edge)
		if d > best_d:
			best_d = d
			best = w
	_arm(side, best.origin, pole)
	var w2 := g(side + "_wrist")
	set_g(side + "_wrist", Transform3D(best.basis, w2.origin))


## Where a closed hand holds what it closes on, in its wrist's frame: the hole the fingers curled by `amount` (as
## _fist()) leave, its +Y out of the thumb's side along what runs through it (the knuckles' line), its +Z toward the
## middle finger's knuckle. For "rhand"/"lhand" "rel": a rod, a barrel or a cartridge held in the fist rather than at the prop
## bone. Leaves the skeleton at rest.
func fist_rel(side: String, amount := 1.0) -> Transform3D:
	sk.reset_bone_poses()
	sk.force_update_all_bone_transforms()
	_fist(amount)
	var c := Vector3.ZERO
	var n := 0
	for f: String in FINGERS:
		for j: String in ["a", "b", "c"]:
			if idx(side + "_" + f + j) >= 0:
				c += g(side + "_" + f + j).origin
				n += 1
	c /= maxf(float(n), 1.0)
	var y := (g(side + "_indexa").origin - g(side + "_pinkya").origin).normalized()
	var back := g(side + "_middlea").origin - c
	var z := (back - y * back.dot(y)).normalized()
	var out := g(side + "_wrist").affine_inverse() * Transform3D(Basis(y.cross(z).normalized(), y, z), c)
	sk.reset_bone_poses()
	sk.force_update_all_bone_transforms()
	return out


## Two-bone IK: the shoulder's and the elbow's turns that put the wrist at `target`, the elbow bent toward `pole` (down
## and out when none is given).
func _arm(side: String, target: Vector3, pole := Vector3.ZERO) -> void:
	var sgn := 1.0 if side == "l" else -1.0
	if pole == Vector3.ZERO:
		pole = Vector3(sgn * 0.6, -1.0, -0.3)
	_two_bone(side + "_shoulder", side + "_elbow", side + "_wrist", target, pole)


## f: [x, z, heel_lift, yaw, pitch, roll] (the ankle over (x, z), raised heel_lift above its rest height; turned yaw,
## pitch, roll from its rest, or, without them, level with the heel rolled up onto the ball by the lift).
func _leg(side: String, f: Array, pole := Vector3.ZERO) -> void:
	var sgn := 1.0 if side == "l" else -1.0
	var ank_rest: Transform3D = rest[side + "_ankle"]
	var heel := float(f[2]) if f.size() > 2 else 0.0
	var target := Vector3(float(f[0]), ank_rest.origin.y + heel, float(f[1]))
	if pole == Vector3.ZERO:
		pole = Vector3(sgn * 0.15, 0.0, 1.0)
	_two_bone(side + "_upper_leg", side + "_knee", side + "_ankle", target, pole)
	var a := g(side + "_ankle")
	var b: Basis
	if f.size() > 3:
		b = euler(float(f[3]), float(f[4]) if f.size() > 4 else 0.0, float(f[5]) if f.size() > 5 else 0.0)
	else:
		b = Basis(Vector3.RIGHT, -clampf(heel / 0.12, 0.0, 1.0) * deg_to_rad(25.0))
	set_g(side + "_ankle", Transform3D(b * ank_rest.basis, a.origin))


## Turns the upper and the lower bone so the end reaches `target`, bending toward the pole (body-space direction).
func _two_bone(a_nm: String, b_nm: String, c_nm: String, target: Vector3, pole: Vector3) -> void:
	var A := g(a_nm)
	var B := g(b_nm)
	var C := g(c_nm)
	var la := A.origin.distance_to(B.origin)
	var lb := B.origin.distance_to(C.origin)
	var to := target - A.origin
	var d := clampf(to.length(), absf(la - lb) + 1e-3, (la + lb) * 0.999)
	var u := to.normalized()
	var v := pole - u * pole.dot(u)
	v = v.normalized() if v.length_squared() > 1e-6 else Vector3.DOWN
	var ca := clampf((la * la + d * d - lb * lb) / (2.0 * la * d), -1.0, 1.0)
	var knee := A.origin + (u * ca + v * sqrt(1.0 - ca * ca)) * la
	var end := A.origin + u * d
	var q1 := Quaternion((B.origin - A.origin).normalized(), (knee - A.origin).normalized())
	set_g(a_nm, Transform3D(Basis(q1) * A.basis, A.origin))
	var B2 := g(b_nm)
	var C2 := g(c_nm)
	var q2 := Quaternion((C2.origin - B2.origin).normalized(), (end - B2.origin).normalized())
	set_g(b_nm, Transform3D(Basis(q2) * B2.basis, B2.origin))


## The fingers curled into a fist round the haft (each joint about the knuckles' line, toward the palm).
func _fist(amount: float) -> void:
	if amount <= 0.0:
		return
	for side: String in ["r", "l"]:
		var line := g(side + "_pinkya").origin - g(side + "_indexa").origin
		var palm := g(side + "_palm")
		for f: String in FINGERS:
			for j: String in (["a", "b", "c", "d"] if f == "pinky" else ["a", "b", "c"]):
				var nm := side + "_" + f + j
				if idx(nm) < 0:
					continue
				var ang := deg_to_rad(80.0 if j == "a" else 85.0) * amount * (1.0 if side == "r" else -1.0)
				turn(nm, Basis(line.normalized(), ang))
		for j: String in ["b", "c"]:
			turn(side + "_thumb" + j, Basis((palm.basis.y).normalized(), deg_to_rad(35.0) * amount))


## The pose mirrored left for right through the body's middle (x -> -x): every turn mirrored (yaw and roll the other
## way, pitch as it is), the sides swapped (the collarbones, the elbows, the knees, the feet, the hands on the tool),
## and the tool mirrored with them (a tool is the same either side: its turn, a quaternion, conjugated by the
## mirror). A right-to-left swing becomes a left-to-right one.
static func mirror(p: Dictionary) -> Dictionary:
	var o := {}
	for k: String in p:
		var v = p[k]
		match k:
			"hips", "pelvis", "chest", "waist", "head":
				var d: Dictionary = (v as Dictionary).duplicate(true)
				if d.has("pos"):
					d.pos = _mx(d.pos)
				if d.has("yaw"):
					d.yaw = -float(d.yaw)
				if d.has("roll"):
					d.roll = -float(d.roll)
				o[k] = d
			"clav":
				o[k] = {}
				for side: String in v:
					o[k][_other(side)] = _me(v[side])
			"elbows", "knees":
				o[k] = {}
				for side: String in v:
					o[k][_other(side)] = _mx(v[side])
			"feet":
				o[k] = {}
				for side: String in v:
					var f: Array = (v[side] as Array).duplicate()
					f[0] = -float(f[0])
					if f.size() > 3:
						f[3] = -float(f[3])
					if f.size() > 5:
						f[5] = -float(f[5])
					o[k][_other(side)] = f
			"tool":
				var t := {}
				for tk: String in v:
					var tv = v[tk]
					match tk:
						"grip", "haft", "edge":
							t[tk] = _mx(tv)
						"q":
							t[tk] = _mq(tv)
						"right":
							t["left"] = _mx(tv)
						"left":
							t["right"] = _mx(tv)
						"rq":
							t["lq"] = _mq(tv)
						"lq":
							t["rq"] = _mq(tv)
						"rturn":
							t["lturn"] = _me(tv)
						"lturn":
							t["rturn"] = _me(tv)
						_:
							t[tk] = tv
				o[k] = t
			_:
				o[k] = v
	return o


static func _other(side: String) -> String:
	return "l" if side == "r" else ("r" if side == "l" else side)


## A place mirrored: [-x, y, z].
static func _mx(a) -> Array:
	var arr: Array = a
	return [-float(arr[0]), float(arr[1]), float(arr[2])]


## A turn [yaw, pitch, roll] mirrored: [-yaw, pitch, -roll].
static func _me(a) -> Array:
	var arr: Array = a
	return [-float(arr[0]), float(arr[1]) if arr.size() > 1 else 0.0, -float(arr[2]) if arr.size() > 2 else 0.0]


## A quaternion's turn mirrored (conjugated by x -> -x): [x, -y, -z, w].
static func _mq(a) -> Array:
	var arr: Array = a
	return [float(arr[0]), -float(arr[1]), -float(arr[2]), float(arr[3])]


static func _q(a) -> Basis:
	var arr: Array = a
	var q := Quaternion(float(arr[0]), float(arr[1]), float(arr[2]), float(arr[3]))
	return Basis(q.normalized() if q.length_squared() > 1e-8 else Quaternion.IDENTITY)


static func _v3(a) -> Vector3:
	if a is Vector3:
		return a
	var arr: Array = a
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
