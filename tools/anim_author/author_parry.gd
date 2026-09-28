extends SceneTree
## The parry (A+D; user 2026-09-27: "ad should only parry thrusts", "the thrust parry is weird"): this project's own
## two-handed parry against a stab, keyed by hand, "axe_parry" (the felling axe, and the musket clubbed). From the guard
## (the D swing's first pose, exactly: nothing pops as it begins) the hands set the axe a little up and right, then
## drive it up, left and out across the chest, the haft sweeping through the line a thrust comes in on (the middle, at
## the chest) and knocking its point aside; held a moment; brought back to the guard. The body turns into the sweep a
## little; the feet stay. The haft keeps the guard's roll in the hands (each key's tool the guard's turned only as far
## as its haft turns), so the grip does not twist.
## Keyed as the body has it and written in the chest's frame (the D swing's space: its guard key as it is) into
## data/anim_author/axe_swings.json; then author_swings.gd -- bake. Every key is checked: the hands reach the haft.
##   Godot --headless --path . -s tools/anim_author/author_parry.gd

const Solver := preload("res://tools/anim_author/pose_solver.gd")
const FitRef := preload("res://tools/anim_author/fit_ref.gd")
const DATA := "res://data/anim_author/axe_swings.json"
const LENGTH := 0.62
## The intro (up to the set) and the hit, as the melee data plays them; the sweep's window (the data's "strike") is
## from the set to the end of the hold.
const SPLIT := 0.1
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
	solver.pose(guard)
	var g0: Transform3D = solver.tool_world
	var mid0 := g0 * Vector3(0, MID_Y, 0)
	var h0 := g0.basis.y.normalized()
	# (as the body has them: +X the left, +Z ahead)
	var keys := [guard,
		# set: up a little and to the right, the haft more upright
		_key(guard, g0, 0.1, "out", mid0 + Vector3(-0.12, 0.1, 0.0), Vector3(-0.7, 0.7, 0.05), -44.0, 0.0),
		# the sweep: up, left and out across the chest, the head leading a little
		# (out at arm's length, the head clear of the face)
		_key(guard, g0, 0.24, "fast", mid0 + Vector3(0.28, 0.18, 0.18), Vector3(-0.8, 0.5, 0.3), -38.0, 8.0),
		# held
		_key(guard, g0, 0.36, "out", mid0 + Vector3(0.3, 0.17, 0.16), Vector3(-0.8, 0.5, 0.28), -38.0, 8.0),
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
	data.clips["axe_parry"] = {"desc": "the parry (A+D): a two-handed sweep of the haft across the chest, knocking a thrust aside",
			"length": LENGTH, "hold": "pipe", "space": "chest", "split": SPLIT,
			"authored": "keyed by hand (tools/anim_author/author_parry.gd) from the D swing's guard", "keys": keys}
	print("PARRY: %d keys, %.2f s" % [keys.size(), LENGTH])
	var fa := FileAccess.open(DATA, FileAccess.WRITE)
	fa.store_string(FitRef.write_json(data))
	fa.close()
	quit()


## A key at `t`: the guard with the hips yawed to `hips_yaw` and the chest to `chest_yaw`, the axe's middle (MID_Y up
## the haft) at `mid` with the haft along `haft` (as the body has them), turned from the guard's axe `g0` only as far
## as its haft turns; written in the key's chest frame.
func _key(guard: Dictionary, g0: Transform3D, t: float, ease: String, mid: Vector3, haft: Vector3, hips_yaw: float,
		chest_yaw: float) -> Dictionary:
	var k: Dictionary = guard.duplicate(true)
	k["t"] = t
	k["ease"] = ease
	k.hips.yaw = hips_yaw
	k.chest.yaw = float(guard.chest.yaw) + chest_yaw
	var h := haft.normalized()
	var b := Basis(Quaternion(g0.basis.y.normalized(), h)) * g0.basis.orthonormalized()
	var tool := Transform3D(b, mid - h * MID_Y)
	# (the key's chest frame, as the solver makes it: its body turn at the upper spine)
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


## Every key: each hand reaches its place on the haft; prints where the axe's middle and head are.
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
		print("  key t %.2f mid %s head %s haft %s" % [float(k.t), (tw * Vector3(0, MID_Y, 0)).snappedf(0.01),
				(tw * Vector3(0, 0.8, 0)).snappedf(0.01), tw.basis.y.normalized().snappedf(0.01)])
