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


## A wrist's turn `want` (skeleton space) brought within wrist_bend of its forearm's line and wrist_twist about it
## (or `most_bend` / `most_twist`, degrees, when given), from the straight wrist (its rest turn under the forearm as it
## is).
func _wrist_limited(side: String, want: Basis, most_bend := -1.0, most_twist := -1.0) -> Basis:
	var el := g(side + "_elbow")
	var wr := g(side + "_wrist")
	var straight := el.basis * ((rest[side + "_elbow"] as Transform3D).basis.inverse() * (rest[side + "_wrist"] as Transform3D).basis)
	var axis := (wr.origin - el.origin).normalized()
	var q := (want.orthonormalized() * straight.orthonormalized().inverse()).get_rotation_quaternion()
	var v := Vector3(q.x, q.y, q.z)
	var tw := Quaternion(axis.x * v.dot(axis), axis.y * v.dot(axis), axis.z * v.dot(axis), q.w)
	tw = tw.normalized() if tw.length_squared() > 1e-8 else Quaternion.IDENTITY
	var sw := q * tw.inverse()
	sw = _clamp_q(sw, deg_to_rad(most_bend if most_bend >= 0.0 else wrist_bend))
	tw = _clamp_q(tw, deg_to_rad(most_twist if most_twist >= 0.0 else wrist_twist))
	return Basis(sw * tw) * straight


static func _clamp_q(q: Quaternion, most: float) -> Quaternion:
	if q.w < 0.0:
		q = -q   # (the short way round)
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
	if wrist_neutral:
		var nb := _neutral(side, at, haft, ref.normalized(), edge, pole, rel)
		_arm(side, (nb[0] as Transform3D).origin, nb[1])
		# (where no turn of the hand leaves the wrist easy, between two grips, it gives: the fist a little off its mark)
		var wb := _wrist_limited(side, (nb[0] as Transform3D).basis, NEUTRAL_BEND_MAX, 180.0)
		set_g(side + "_wrist", Transform3D(wb, g(side + "_wrist").origin))
		return
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


## _hand() with the wrist kept as straight as it will go (author_reload.gd; the user 2026-09-29: "the wrist still bends
## in weird ways, not natural": the fist hung off the forearm by up to 80 degrees on the rod). Searched together: the
## hand's roll about what it holds, the elbow's swing about the shoulder -> wrist line, and a tilt of what it holds
## across the fist (in the palm's plane, TILTS; neutral_tilt's sides: a rod lies a little aslant in a fist), for the
## least bend of the hand off its forearm's line (the rest pose's straight wrist; freer within WRIST_EASY_DEG); the
## forearm's roll kept within WRIST_ROLL_DEG of the thumb up (the thumb toward the shoulder's side of the forearm); the
## elbow near the pole's swing, out of the chest and no higher than the shoulder or the hand; `edge` (the hand's -Z
## that way) held to as firmly as its length says (1: the grip as keyed; less as the hand eases off it).
## Frame to frame (neutral_mode): "collect" notes each frame's costs over the roll and the tilt, plan_neutral() finds
## the cheapest way through them all that turns the hand no more than PLAN_ROLL_STEPS and PLAN_TILT_STEPS of the grid a
## frame, and "replay" poses each frame about the plan's (no pop from one answer to another: the grip turns over as it
## must, beforehand). Without a plan, each pose alone (near the last solve).
var wrist_neutral := false
const WRIST_EASY_DEG := 12.0
const WRIST_ROLL_DEG := 75.0
const NEUTRAL_ROLLS := 36
const NEUTRAL_SWINGS := 36
const TILTS := [-20.0, -10.0, 0.0, 10.0, 20.0]
## No further than this off the forearm's line, whatever the grip asks (degrees).
const NEUTRAL_BEND_MAX := 40.0
const PLAN_ROLL_STEPS := 2
const PLAN_TILT_STEPS := 1
## The sides whose hand may hold what it holds aslant (a thin rod or a cartridge; not a barrel: it would pass through
## the fingers): side -> true.
var neutral_tilt := {}
var neutral_mode := ""
var _last_neutral := {}   ## side -> [the wrist's turn, the elbow's side] of the last solve
var _neutral_i := {}      ## side -> the frame's index in the run
var _neutral_costs := {}  ## side -> per frame: PackedFloat32Array over roll * tilt (collect)
var _neutral_plan := {}   ## side -> per frame: Vector2(roll, tilt index) (replay)


## Starts a new run of poses (not the next frame of the last): `plan_too` forgets the plan and the costs as well.
func reset_neutral(plan_too := false) -> void:
	_last_neutral.clear()
	_neutral_i.clear()
	if plan_too:
		_neutral_costs.clear()
		_neutral_plan.clear()


## The cheapest way through the collected frames (see wrist_neutral): a frame's cost plus the turn from the last, 0.3
## a degree of roll and 0.5 of tilt, no further than PLAN_ROLL_STEPS / PLAN_TILT_STEPS.
func plan_neutral() -> void:
	var nt := TILTS.size()
	var ns := NEUTRAL_ROLLS * nt
	var roll_step := 0.3 * 360.0 / float(NEUTRAL_ROLLS)
	var tilt_step := 0.5 * 10.0
	for side: String in _neutral_costs:
		var frames: Array = _neutral_costs[side]
		var d := PackedFloat32Array(frames[0] as PackedFloat32Array)
		var back := []
		for f in range(1, frames.size()):
			var cf: PackedFloat32Array = frames[f]
			var nd := PackedFloat32Array()
			nd.resize(ns)
			var arg := PackedInt32Array()
			arg.resize(ns)
			for k in NEUTRAL_ROLLS:
				for ti in nt:
					var bestv := INF
					var besti := 0
					for dk in range(-PLAN_ROLL_STEPS, PLAN_ROLL_STEPS + 1):
						var pk := posmod(k + dk, NEUTRAL_ROLLS)
						for dt in range(-PLAN_TILT_STEPS, PLAN_TILT_STEPS + 1):
							var pt := ti + dt
							if pt < 0 or pt >= nt:
								continue
							var v := d[pk * nt + pt] + roll_step * absf(dk) + tilt_step * absf(dt)
							if v < bestv:
								bestv = v
								besti = pk * nt + pt
					nd[k * nt + ti] = cf[k * nt + ti] + bestv
					arg[k * nt + ti] = besti
			back.append(arg)
			d = nd
		var cur := 0
		for i in ns:
			if d[i] < d[cur]:
				cur = i
		var plan := []
		plan.resize(frames.size())
		for f in range(frames.size() - 1, -1, -1):
			plan[f] = Vector2(cur / nt, cur % nt)
			if f > 0:
				cur = (back[f - 1] as PackedInt32Array)[cur]
		_neutral_plan[side] = plan


## [the wrist's place and turn, the elbow's pole] for _hand() (wrist_neutral).
func _neutral(side: String, at: Vector3, haft: Vector3, ref: Vector3, edge: Vector3, pole: Vector3, rel: Transform3D) -> Array:
	var sgn := 1.0 if side == "l" else -1.0
	if pole == Vector3.ZERO:
		pole = Vector3(sgn * 0.6, -1.0, -0.3)
	var s := g(side + "_shoulder").origin
	var la := s.distance_to(g(side + "_elbow").origin)
	var lb := g(side + "_elbow").origin.distance_to(g(side + "_wrist").origin)
	var rw: Transform3D = rest[side + "_wrist"]
	var rb := rw.basis.orthonormalized().inverse()
	var f_local := rb * (rw.origin - (rest[side + "_elbow"] as Transform3D).origin).normalized()
	var t_local := rb * ((rest[side + "_indexa"] as Transform3D).origin - (rest[_knuckle(side, "pinky")] as Transform3D).origin).normalized()
	# the tilt's axis: the palm's normal in the hole's frame (square to its +Y and to the hand's length)
	var hl := rel.basis.orthonormalized().inverse() * (rb * ((rest[side + "_middlea"] as Transform3D).origin - rw.origin))
	hl = (hl - Vector3.UP * hl.y).normalized()
	var hn := Vector3.UP.cross(hl).normalized()
	var tilt_w := 0.2 + 4.0 * edge.length()
	var can_tilt: bool = neutral_tilt.get(side, false)
	var fi: int = _neutral_i.get(side, 0)
	_neutral_i[side] = fi + 1
	var plan: Array = _neutral_plan.get(side, []) if neutral_mode == "replay" else []
	var planned: Variant = plan[fi] if fi < plan.size() else null
	var last: Array = _last_neutral.get(side, []) if planned == null or fi > 0 else []
	var last_q := (last[0] as Basis).get_rotation_quaternion() if not last.is_empty() else Quaternion.IDENTITY
	var costs := PackedFloat32Array()
	if neutral_mode == "collect":
		costs.resize(NEUTRAL_ROLLS * TILTS.size())
		costs.fill(INF)
	var best := {"c": INF, "w": Transform3D(), "v": pole, "k": 0.0, "j": 0.0, "t": 0.0}
	for pass_i in 2:
		var at_k: float = best.k
		var at_j: float = best.j
		var at_t: float = best.t
		var tilts: Array
		var ks: Array
		var js: Array = range(NEUTRAL_SWINGS) if pass_i == 0 else range(9).map(func(i: int) -> float: return at_j + (i - 4) * 0.25)
		if pass_i == 0 and planned != null:
			# (the plan's roll and tilt; the swing searched)
			ks = [(planned as Vector2).x]
			tilts = [float(TILTS[int((planned as Vector2).y)]) if can_tilt else 0.0]
		elif pass_i == 0:
			ks = range(NEUTRAL_ROLLS)
			tilts = TILTS if can_tilt else [0.0]
		else:
			ks = range(9).map(func(i: int) -> float: return at_k + (i - 4) * 0.125)
			tilts = [at_t - 5.0, at_t, at_t + 5.0] if can_tilt else [0.0]
		for tilt: float in tilts:
			var inv := Transform3D(rel.basis * Basis(hn, deg_to_rad(tilt)), rel.origin).affine_inverse()
			var ti := TILTS.find(tilt) if can_tilt else TILTS.find(0.0)
			for kv: Variant in ks:
				var k := float(kv)
				var z0 := ref.rotated(haft, TAU * k / float(NEUTRAL_ROLLS))
				var x0 := haft.cross(z0).normalized()
				var pf := Transform3D(Basis(x0, haft, x0.cross(haft).normalized()), at)
				var w := pf * inv
				var c0 := tilt_w * absf(tilt)
				if edge != Vector3.ZERO:
					# (the keyed grip: 1 - cos of the hand's roll off it, weighed by how firmly it is held)
					c0 += 400.0 * (edge.length() - (-pf.basis.z).dot(edge))
				var cont := 0.0
				if not last.is_empty():
					cont = 0.3 * rad_to_deg(last_q.angle_to(w.basis.get_rotation_quaternion()))
				var to := w.origin - s
				var u := to.normalized()
				var d := clampf(to.length(), absf(la - lb) + 1e-3, (la + lb) * 0.999)
				var ca := clampf((la * la + d * d - lb * lb) / (2.0 * la * d), -1.0, 1.0)
				var sa := sqrt(1.0 - ca * ca)
				var v0 := pole - u * pole.dot(u)
				v0 = v0.normalized() if v0.length_squared() > 1e-6 else Vector3.DOWN
				var n := (w.basis * f_local).normalized()
				var tn := w.basis * t_local
				var high := maxf(s.y - 0.03, w.origin.y + 0.02)
				for jv: Variant in js:
					var j := float(jv)
					var phi := wrapf(TAU * j / float(NEUTRAL_SWINGS), -PI, PI)
					var v := v0.rotated(u, phi)
					var e := s + (u * ca + v * sa) * la
					var fa := (s + u * d - e).normalized()
					var bend := rad_to_deg(fa.angle_to(n))
					var c := c0 + 0.3 * bend + maxf(bend - WRIST_EASY_DEG, 0.0)
					# the forearm's roll off the thumb up
					var up := (s - e) - fa * (s - e).dot(fa)
					var th := tn - fa * tn.dot(fa)
					if up.length_squared() > 1e-4 and th.length_squared() > 1e-6:
						c += 2.0 * maxf(rad_to_deg(up.angle_to(th)) - WRIST_ROLL_DEG, 0.0) * minf(up.length() / (0.5 * la), 1.0)
					# the elbow: near the pole's swing, out of the chest, no higher than the shoulder or the hand
					c += 0.15 * maxf(absf(rad_to_deg(phi)) - 30.0, 0.0)
					c += 800.0 * maxf(-(e.x - s.x) * sgn - 0.02, 0.0)
					c += 300.0 * maxf(e.y - high, 0.0)
					if pass_i == 0 and not costs.is_empty() and ti >= 0:
						var ci := int(k) * TILTS.size() + ti
						costs[ci] = minf(costs[ci], c)
					c += cont
					if not last.is_empty():
						var swung := rad_to_deg(v.angle_to(last[1] as Vector3))
						c += 0.2 * swung + 1.0 * maxf(swung - 15.0, 0.0)
					if c < float(best.c):
						best = {"c": c, "w": w, "v": v, "k": k, "j": j, "t": tilt}
	if not costs.is_empty():
		if not _neutral_costs.has(side):
			_neutral_costs[side] = []
		(_neutral_costs[side] as Array).append(costs)
	_last_neutral[side] = [(best.w as Transform3D).basis, best.v]
	return [best.w, best.v]


## Where a closed hand holds what it closes on, in its wrist's frame: the hole the fingers curled by `amount` (as
## _fist()) leave, its +Y out of the thumb's side along what runs through it (the knuckles' line), its +Z toward the
## middle finger's knuckle. For "rhand"/"lhand" "rel": a rod, a barrel or a cartridge held in the fist rather than at the prop
## bone. The knuckles' line and the fingers' joints are the fingers' own (_knuckle(): this rig's pinky starts at its
## metacarpal, by the wrist; taken for its knuckle it laid the line along the hand, the rod 22 degrees off the forearm
## and the wrist bent to hold it). Leaves the skeleton at rest.
func fist_rel(side: String, amount := 1.0) -> Transform3D:
	sk.reset_bone_poses()
	sk.force_update_all_bone_transforms()
	_fist(amount)
	var c := Vector3.ZERO
	var n := 0
	for f: String in FINGERS:
		var k0 := _knuckle(side, f)
		for j in 3:
			var nm := k0.left(-1) + String.chr(k0.unicode_at(k0.length() - 1) + j)
			if idx(nm) >= 0:
				c += g(nm).origin
				n += 1
	c /= maxf(float(n), 1.0)
	var y := (g(side + "_indexa").origin - g(_knuckle(side, "pinky")).origin).normalized()
	var back := g(side + "_middlea").origin - c
	var z := (back - y * back.dot(y)).normalized()
	var out := g(side + "_wrist").affine_inverse() * Transform3D(Basis(y.cross(z).normalized(), y, z), c)
	sk.reset_bone_poses()
	sk.force_update_all_bone_transforms()
	return out


## A finger's knuckle bone (where it leaves the palm): its first, or its second when it has four (its first its
## metacarpal: this rig's pinky, pinkya under the palm).
func _knuckle(side: String, f: String) -> String:
	return side + "_" + f + ("b" if idx(side + "_" + f + "d") >= 0 else "a")


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


## A hand's fingers in a pose of their own instead of the curl: side ("r" / "l") -> {finger or thumb bone: its local
## rotation} (a grip from a clip: author_reload.gd's right fist is the torch's, which suits this body's hand).
var finger_pose := {}


## The fingers curled into a fist round the haft (each joint about the knuckles' line, toward the palm), or set to
## finger_pose for that hand.
func _fist(amount: float) -> void:
	for side: String in finger_pose:
		for nm: String in finger_pose[side]:
			if idx(nm) >= 0:
				sk.set_bone_pose_rotation(idx(nm), finger_pose[side][nm])
	if amount <= 0.0:
		return
	for side: String in ["r", "l"]:
		if finger_pose.has(side):
			continue
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
