extends SceneTree
## The stab (user 2026-09-27: "WD or WA or SA or SD is a stab"; "build the stab"; "its a under hand thrust not a over
## hand"; one hand, for the musket clubbed too): this project's own one-handed underhand thrust, keyed by hand (no clip
## it was measured off), "axe_stab". From a ready stance the right hand draws the weapon back low to the hip, the elbow
## down, the head aimed ahead and up (the edge down: the fist upright), the left hand forward; then a lunge onto the
## right foot drives it out from below, the arm long and low (the hand at the belly), the head rising into the target,
## the left hand pulled back to the hip (a fencer's balance); held a moment; brought back. The right hand holds it where
## it carries it (the blade frame). The crosshair's height leans it up or down in the game (AxeMelee._lean). Clubbed,
## the musket is thrust the same way, butt first ("club_stab"). Each is held as the pose it comes in from holds it (the
## axe as its carry, the club as its guard's right hand), so the weapon does not turn in the hand as the stab fades in
## and out (user: "the hold hand twist and turns", "same with axe").
## Writes it (body space: the tool and the elbows as the body has them) into data/anim_author/axe_swings.json; then
## author_swings.gd -- bake. Every key is checked: the hands reach where they hold.
##   Godot --headless --path . -s tools/anim_author/author_thrust.gd

const Solver := preload("res://tools/anim_author/pose_solver.gd")
const FitRef := preload("res://tools/anim_author/fit_ref.gd")
const DATA := "res://data/anim_author/axe_swings.json"
const LENGTH := 0.75
## The intro (up to the draw back) and the hit, as the melee data plays them.
const SPLIT := 0.14
## The holding wrist kept near its forearm's line (pose_solver.gd wrist_bend / wrist_twist; user: "the wrist flexes
## inwards"): the weapon follows the hand.
const WRIST_BEND := 35.0
const WRIST_TWIST := 60.0

var sk: Skeleton3D
var solver
## The hold the keys are built for: {"hold", "hand_y" (how far up the haft the right hand holds), "right", "rq" (the
## right hand in the tool's frame), "edge" (the way the edge turns)}.
var _grip := {}


func _initialize() -> void:
	var n := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate()
	root.add_child(n)
	await process_frame
	await process_frame
	sk = n.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	solver = Solver.new(sk)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	# the axe: held as its carry holds it (the machete carry the axe is ready in), so nothing turns in the hand as the
	# stab comes in from the carry and goes back to it
	var carry := _carry_grip()
	_grip = {"hold": "blade", "hand_y": Solver.GRIP_M, "right": carry[0], "rq": carry[1], "edge": [0.0, -1.0, 0.0]}
	data.clips["axe_stab"] = _clip("the felling axe's stab (W/S + A/D): a one-handed underhand thrust of the head straight ahead",
			"blade", _one_handed(), "a one-handed lunge, held as the axe's carry holds it")
	# the musket clubbed: held as its two-handed guard's right hand holds it (the D swing's first pose), the left
	# letting go; the gun's roll kept near the guard's
	var g0: Dictionary = (data.clips.axe_d.keys as Array)[0].tool
	_grip = {"hold": "pipe", "hand_y": float((g0.right as Array)[1]), "right": g0.right, "rq": g0.rq,
			"edge": [-0.4, -0.9, 0.2]}
	data.clips["club_stab"] = _clip("the musket clubbed's stab (W/S + A/D): a one-handed underhand thrust of the butt straight ahead",
			"pipe", _one_handed(), "a one-handed lunge, held as the club's guard holds it with its right hand")
	var fa := FileAccess.open(DATA, FileAccess.WRITE)
	fa.store_string(FitRef.write_json(data))
	fa.close()
	quit()


func _clip(desc: String, hold: String, keys: Array, how: String) -> Dictionary:
	var back: Dictionary = (keys[0] as Dictionary).duplicate(true)
	back["t"] = LENGTH
	back["ease"] = ""
	keys.append(back)
	# (each quaternion on the same side as the one before: q and -q are the one turn, and the keys are eased
	# number by number)
	for i in range(1, keys.size()):
		var a: Array = keys[i - 1].tool.q
		var b: Array = keys[i].tool.q
		if float(a[0]) * float(b[0]) + float(a[1]) * float(b[1]) + float(a[2]) * float(b[2]) + float(a[3]) * float(b[3]) < 0.0:
			keys[i].tool.q = b.map(func(x) -> float: return -float(x))
	_check(keys, hold)
	print("THRUST %s: %d keys, %.2f s" % [desc.get_slice(" (", 0), keys.size(), LENGTH])
	return {"desc": desc, "length": LENGTH, "hold": hold, "space": "body", "split": SPLIT,
			"wrist_bend": WRIST_BEND, "wrist_twist": WRIST_TWIST,
			"authored": "keyed by hand (tools/anim_author/author_thrust.gd), " + how, "keys": keys}


## Every key: each hand that holds reaches its grip on the haft; a free left hand its place.
func _check(keys: Array, hold: String) -> void:
	solver.space = "body"
	solver.hold = hold
	solver.wrist_bend = WRIST_BEND
	solver.wrist_twist = WRIST_TWIST
	for k: Dictionary in keys:
		solver.pose(k)
		var tw: Transform3D = solver.tool_world
		var tl: Dictionary = k.tool
		for side: String in ["r", "l"]:
			var rel: Transform3D = (solver.rest[side + "_wrist"] as Transform3D).affine_inverse() * solver.rest[side + "_hand_prop_attachment"]
			var wr := sk.get_bone_global_pose(sk.find_bone(side + "_wrist")).origin
			var off := 0.0
			if side == "l" and tl.has("lfree"):
				off = wr.distance_to(Solver._v3(tl.lfree))
			else:
				var want: Vector3 = tw * Solver._v3(tl["right" if side == "r" else "left"])
				off = (sk.get_bone_global_pose(sk.find_bone(side + "_wrist")) * rel).origin.distance_to(want)
			if off > 0.02:
				print("REACH t %.2f %s hand %.3f m short" % [float(k.t), side, off])
		print("  key t %.2f head %s haft %s" % [float(k.t), (tw * Vector3(0, 0.8, 0)).snappedf(0.01), (tw.basis.y as Vector3).normalized().snappedf(0.01)])


## The one-handed thrust (the felling axe): the right hand holds it where it carries it (the blade frame: the hand
## GRIP_M up the haft), the left hand free.
func _one_handed() -> Array:
	var ready := {"t": 0.0,
		"hips": {"pos": [0.0, -0.06, 0.0], "yaw": -10.0, "pitch": 5.0, "roll": 0.0},
		"pelvis": {"yaw": 0.0, "pitch": 0.0, "roll": 0.0},
		"chest": {"yaw": -5.0, "pitch": 6.0, "roll": 0.0}, "waist": {"yaw": -3.0, "pitch": 3.0, "roll": 0.0},
		"head": {"yaw": 12.0, "pitch": -4.0, "roll": 0.0},
		"clav": {"r": [0.0, 0.0, 0.0], "l": [0.0, 0.0, 0.0]},
		"elbows": {"r": [-0.5, -1.0, -0.2], "l": [0.5, -1.0, 0.0]},
		"knees": {"r": [-0.1, 0.0, 1.0], "l": [0.1, 0.0, 1.0]},
		"feet": {"l": [0.14, 0.20, 0.0, -10.0, 0.0, 0.0], "r": [-0.16, -0.18, 0.0, -30.0, 0.0, 0.0]},
		"tool": {"right": _grip.right, "rq": _grip.rq, "lfree": [0.22, 1.02, 0.22]}}
	_tool(ready, [-0.26, 0.95, 0.2], [0.0, 0.55, 0.83])
	var lunge_feet := {"r": [-0.12, 0.50, 0.0, 5.0, 0.0, 0.0], "l": [0.16, -0.14, 0.09, -20.0, 28.0, 0.0]}
	return [ready,
		# drawn back underhand: the hand low at the right hip, the elbow down and back, the head aimed ahead and up,
		# the left hand forward
		_key(0.14, "out", ready, {
			"hips": {"pos": [0.0, -0.10, -0.06], "yaw": -25.0, "pitch": 4.0, "roll": 0.0},
			"chest": {"yaw": -15.0, "pitch": 2.0, "roll": 0.0}, "waist": {"yaw": -8.0, "pitch": 1.0, "roll": 0.0},
			"head": {"yaw": 35.0, "pitch": -5.0, "roll": 0.0},
			"elbows": {"r": [-0.3, -1.0, -0.6], "l": [0.5, -0.8, 0.3]},
			"tool": {"at": [-0.24, 0.90, -0.08], "haft": [0.02, 0.30, 1.0],
				"lfree": [0.25, 1.12, 0.36]}}),
		# driven out from below: a lunge onto the right foot, the arm long and low (the hand at the belly, the elbow
		# down), the head rising ahead into the target on the body's middle line (where the crosshair is: the haft
		# angled in a little), the left hand back to the hip
		_key(0.26, "fast", ready, {
			"hips": {"pos": [0.0, -0.16, 0.30], "yaw": 12.0, "pitch": 16.0, "roll": 0.0},
			"chest": {"yaw": 15.0, "pitch": 14.0, "roll": 0.0}, "waist": {"yaw": 7.0, "pitch": 7.0, "roll": 0.0},
			"head": {"yaw": -20.0, "pitch": -22.0, "roll": 0.0},
			"elbows": {"r": [-0.3, -0.4, -1.0], "l": [0.6, -0.8, -0.3]},
			"knees": {"r": [-0.1, 0.0, 1.0], "l": [0.1, -0.2, 1.0]},
			"feet": lunge_feet,
			"tool": {"at": [-0.04, 0.80, 0.88], "haft": [0.18, 0.6, 0.8],
				"lfree": [0.30, 1.0, -0.02]}}),
		_key(0.34, "out", ready, {
			"hips": {"pos": [0.0, -0.16, 0.29], "yaw": 12.0, "pitch": 16.0, "roll": 0.0},
			"chest": {"yaw": 15.0, "pitch": 14.0, "roll": 0.0}, "waist": {"yaw": 7.0, "pitch": 7.0, "roll": 0.0},
			"head": {"yaw": -20.0, "pitch": -22.0, "roll": 0.0},
			"elbows": {"r": [-0.3, -0.4, -1.0], "l": [0.6, -0.8, -0.3]},
			"knees": {"r": [-0.1, 0.0, 1.0], "l": [0.1, -0.2, 1.0]},
			"feet": lunge_feet,
			"tool": {"at": [-0.04, 0.80, 0.86], "haft": [0.18, 0.62, 0.78],
				"lfree": [0.30, 1.0, -0.02]}}),
		]


## A key at `t` (eased in by `ease`): the guard with `over` laid on it; the tool given as where the right hand holds it
## ("at") and the haft's way, body space (_tool).
func _key(t: float, ease: String, guard: Dictionary, over: Dictionary) -> Dictionary:
	var k := guard.duplicate(true)
	k["t"] = t
	k["ease"] = ease
	for part: String in over:
		if part == "tool":
			continue
		k[part] = over[part]
	var o: Dictionary = over.get("tool", {})
	if not o.is_empty():
		_tool(k, o.at, o.haft)
		if o.has("lfree"):
			k.tool["lfree"] = o.lfree
	return k


## Sets a key's tool (body space): the point of the haft the right hand holds (_grip.hand_y up it) at `at`, the haft
## the way `haft` says, the edge turned as _grip.edge; its prop bone's place for the hold worked out from that.
func _tool(k: Dictionary, at: Array, haft: Array) -> void:
	var h := Solver._v3(haft).normalized()
	var e := Solver._v3(_grip.edge)
	e = (e - h * e.dot(h)).normalized()
	var x := h.cross(-e).normalized()
	var b := Basis(x, h, x.cross(h).normalized())
	var tool := Transform3D(b, Solver._v3(at) - h * float(_grip.hand_y))
	var prop := tool * Solver.hold_xf(String(_grip.hold)).affine_inverse()
	var q := b.get_rotation_quaternion()
	k.tool["grip"] = _a3(prop.origin)
	k.tool["q"] = [q.x, q.y, q.z, q.w]


## How the axe's carry (GatherData clips "carry", at its end) has the prop bone in the right hand, as the solver's
## "right" and "rq": the hand's own rest prop frame in the tool's (the blade hold) frame.
func _carry_grip() -> Array:
	var gd := GatherData.get_default()
	var lib := load(String(gd.clips.get("library", "res://animations_extra/Actor_B_from_A.res"))) as AnimationLibrary
	var anim := lib.get_animation(String(gd.clips.carry))
	sk.reset_bone_poses()
	var prop_in_wrist := ToolPose.clip_relative(sk, anim, anim.length, "r_hand_prop_attachment", "r_wrist")
	var rel: Transform3D = (solver.rest["r_wrist"] as Transform3D).affine_inverse() * solver.rest["r_hand_prop_attachment"]
	var right := Solver.hold_xf("blade").affine_inverse() * prop_in_wrist.affine_inverse() * rel
	var q := right.basis.orthonormalized().get_rotation_quaternion()
	return [_a3(right.origin), [q.x, q.y, q.z, q.w]]


func _gp(nm: String) -> Vector3:
	return sk.get_bone_global_pose(sk.find_bone(nm)).origin


static func _a3(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]
