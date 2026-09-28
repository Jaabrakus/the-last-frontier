extends SceneTree
## The high block, S (user 2026-09-27: "im thinking we dont even have a rising cut for axes and clubs we just have a
## parry like two hand hold for the over hand swin"): not an attack but the answer to W's overhand chop, as the parry
## (A+D) is the stab's: this project's own two-handed block, keyed by hand, "axe_block_high" (the felling axe, and the
## musket clubbed). From the guard (the D swing's first pose, exactly: nothing pops as it begins) the axe comes up fast
## in both hands and is held across, high and out in front (user: "the overhand block or s click should have the axe
## and musket be high like that but in front"), the haft level and square to the front, the head out to the right,
## the upper hand slid out along the haft for a wide hold, the knees bent under it and the body squared up to the front;
## held there through the chop; back to the guard. The feet stay. (The rising cut it replaces, keyed from the start of
## youtube.com/shorts/45Jv_U7DAcw, is gone.)
## Keyed as the body has it and written in the chest's frame (the D swing's space) into data/anim_author/axe_swings.json
## as "axe_block_high" (the old fitted rising cut "axe_s" taken out); then author_swings.gd -- bake. Every key is
## checked: the hands reach the haft.
##   Godot --headless --path . -s tools/anim_author/author_high_block.gd

const Solver := preload("res://tools/anim_author/pose_solver.gd")
const FitRef := preload("res://tools/anim_author/fit_ref.gd")
const DATA := "res://data/anim_author/axe_swings.json"
const LENGTH := 0.95
## The intro (up to the axe raised) and the hold, as the melee data plays them; the block's window (the data's
## "strike") is from the raise to the end of the hold.
const SPLIT := 0.15
## How far up the haft the point between the hands is (the guard's hands: the left at 0.12, the right at 0.43).
const MID_Y := 0.27

var sk: Skeleton3D
var solver


func _initialize() -> void:
	var n := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate()
	root.add_child(n)
	await process_frame
	await process_frame
	sk = n.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	solver = Solver.new(sk)
	solver.space = "chest"
	solver.hold = "pipe"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var guard: Dictionary = (data.clips.axe_d.keys[0] as Dictionary).duplicate(true)
	guard["t"] = 0.0
	# (as the body has them: +X the left, +Z ahead, heights from the ground)
	var keys := [guard,
		# up high and out in front (user: "high like that but in front"): the haft level and square to the front,
		# above the head's height and an arm's reach out, the head out to the right, the edge up;
		# the upper hand slid out along it for a wide hold, the knees bent, the body squared up
		_key(guard, 0.15, "out", Vector3(-0.08, 1.46, 0.52), Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.25),
				{"yaw": -28.0, "y": -0.14, "chest_yaw": 0.0, "chest_pitch": -6.0, "right_y": 0.52}),
		# held through the chop
		_key(guard, 0.6, "", Vector3(-0.08, 1.44, 0.53), Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.25),
				{"yaw": -28.0, "y": -0.15, "chest_yaw": 0.0, "chest_pitch": -5.0, "right_y": 0.52}),
		]
	var back: Dictionary = guard.duplicate(true)
	back["t"] = LENGTH
	back["ease"] = ""
	keys.append(back)
	for i in range(1, keys.size()):
		var a: Array = keys[i - 1].tool.q
		var b: Array = keys[i].tool.q
		if float(a[0]) * float(b[0]) + float(a[1]) * float(b[1]) + float(a[2]) * float(b[2]) + float(a[3]) * float(b[3]) < 0.0:
			keys[i].tool.q = b.map(func(x) -> float: return -float(x))
	_check(keys)
	data.clips.erase("axe_s")
	data.clips["axe_block_high"] = {"desc": "S: the high block, the haft held across above the head in both hands against W's chop",
			"length": LENGTH, "hold": "pipe", "space": "chest", "split": SPLIT,
			"authored": "keyed by hand (tools/anim_author/author_high_block.gd) from the D swing's guard", "keys": keys}
	print("HIGH BLOCK: %d keys, %.2f s" % [keys.size(), LENGTH])
	var fa := FileAccess.open(DATA, FileAccess.WRITE)
	fa.store_string(FitRef.write_json(data))
	fa.close()
	quit()


## A key at `t`: the guard with the body as `body` says (hips yaw and drop, the chest's extra yaw and pitch), the axe's
## middle (MID_Y up the haft) at `mid`, its haft along `haft` and its edge toward `edge` (as the body has them); written
## in the key's chest frame.
func _key(guard: Dictionary, t: float, ease: String, mid: Vector3, haft: Vector3, edge: Vector3, body: Dictionary) -> Dictionary:
	var k: Dictionary = guard.duplicate(true)
	k["t"] = t
	k["ease"] = ease
	k.hips.yaw = float(body.yaw)
	k.hips.pos = [float(guard.hips.pos[0]), float(body.y), float(guard.hips.pos[2])]
	k.chest.yaw = float(guard.chest.yaw) + float(body.chest_yaw)
	k.chest.pitch = float(guard.chest.pitch) + float(body.chest_pitch)
	if body.has("right_y"):
		# (the upper hand slid along the haft: toward the head for a wide hold)
		var r: Array = (k.tool.right as Array).duplicate()
		r[1] = float(body.right_y)
		k.tool["right"] = r
	var h := haft.normalized()
	var e := edge - h * edge.dot(h)
	e = e.normalized() if e.length_squared() > 1e-6 else Vector3.FORWARD
	# (the tool's frame: the haft +Y, the edge -Z)
	var z := -e
	var x := h.cross(z).normalized()
	var b := Basis(x, h, x.cross(h).normalized())
	var tool := Transform3D(b, mid - h * MID_Y)
	var probe: Dictionary = k.duplicate(true)
	probe.erase("tool")
	solver.pose(probe)
	var chest_xf := Transform3D(Solver._e(k.hips) * Solver._e(k.chest), solver.g("spined").origin)
	var local := chest_xf.affine_inverse() * tool
	var prop := local * Solver.hold_xf("pipe").affine_inverse()
	var q := local.basis.orthonormalized().get_rotation_quaternion()
	k.tool["grip"] = [prop.origin.x, prop.origin.y, prop.origin.z]
	k.tool["q"] = [q.x, q.y, q.z, q.w]
	return k


## Every key: each hand reaches its place on the haft; prints where the axe's head is.
func _check(keys: Array) -> void:
	for k: Dictionary in keys:
		solver.pose(k)
		var tw: Transform3D = solver.tool_world
		var tl: Dictionary = k.tool
		for side: String in ["r", "l"]:
			var rel: Transform3D = (solver.rest[side + "_wrist"] as Transform3D).affine_inverse() * solver.rest[side + "_hand_prop_attachment"]
			var want: Vector3 = tw * Solver._v3(tl["right" if side == "r" else "left"])
			var off := (sk.get_bone_global_pose(sk.find_bone(side + "_wrist")) * rel).origin.distance_to(want)
			if off > 0.02:
				print("REACH t %.2f %s hand %.3f m short" % [float(k.t), side, off])
		print("  key t %.2f head %s edge %s" % [float(k.t), (tw * Vector3(0, 0.8, 0)).snappedf(0.01), (-tw.basis.z).normalized().snappedf(0.01)])
