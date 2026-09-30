extends SceneTree
## The canoe paddler's poses (user 2026-09-29: "the user is crouched, kind of like the aim crouch; the user raises up and does a
## paddling animation", "combine like an overhead swing from the axe but to the side"): this project's own, keyed by hand
## (tools/anim_author/pose_solver.gd, the rest pose and IK, no clip's data), for BoatRider:
##   paddle_crouch   crouched in the boat as in the aim crouch (the pelvis down, the chest leaning over the knees), the paddle held
##                   ready in both hands out over the right side, the blade by the water: a slow breath (a loop)
##   paddle_stroke   raised up out of the crouch (the hips half up, the knees still bent), a full stroke on the right side: the paddle
##                   swung up over the head like the axe's overhead, but out to the side, the blade dropped in ahead (the catch),
##                   pulled back along the hull with the body's weight (the drive), lifted out at the hip (the exit) and swung up
##                   and forward again (the recovery). A loop of one stroke.
## The left hand holds the top of the shaft, the right hand lower down (the paddle's blade end is the tool's knob: the right hand
## PADDLE_UP from it, the left above it), and the right hand's prop bone carries the paddle the pipe way (pose_solver carry "pipe"), so
## the game hangs it as it hangs the rod (BoatRider: PADDLE_IN_HANDS).
## Keys in the body's frame (+X its left, +Z ahead, heights from the boat's floor), written into data/anim_author/paddle.json; a
## preview renders them with the paddle; the bake puts them in animations_extra/Frontier_Own.res beside the others:
##   Godot --headless --path . -s tools/anim_author/author_paddle.gd                  (write the keys)
##   Godot --path . -s tools/anim_author/author_paddle.gd -- preview out=<abs dir>    (sheets of each clip, windowed)
##   Godot --headless --path . -s tools/anim_author/author_swings.gd -- bake data=res://data/anim_author/paddle.json

const Solver := preload("res://tools/anim_author/pose_solver.gd")
const Swings := preload("res://tools/anim_author/author_swings.gd")
const FitRef := preload("res://tools/anim_author/fit_ref.gd")
const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const DATA := "res://data/anim_author/paddle.json"
## The paddle: its length (BoatGear.PADDLE_LEN), the right hand's hold up the shaft from the blade's tip (the tool's knob), the left above it.
const PADDLE_LEN := 1.35
const PADDLE_UP := 0.78
const PADDLE_SPREAD := -0.42
## The paddle model (its grip at the origin, the blade at +Z) in the tool frame (the haft +Y from the knob = the blade's tip): the tip at the
## origin and the grip end up the haft. (BoatRider.PADDLE_IN_HANDS is the same.)
const PADDLE_IN_HANDS := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)), Vector3(0, PADDLE_LEN, 0))
## The crouch: the game's own (measured in the game: the root 0.369 m up against 0.905 standing).
const CROUCH_DROP := -0.53
const CELL := Vector2i(360, 400)

var args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		args[s.get_slice("=", 0)] = s.substr(s.find("=") + 1) if "=" in s else true
	var data := {"format": "frontier_anim_author", "version": 1,
			"summary": "The canoe paddler's poses, keyed by hand (tools/anim_author/author_paddle.gd): this project's own.",
			"clips": _clips()}
	var fa := FileAccess.open(DATA, FileAccess.WRITE)
	fa.store_string(FitRef.write_json(data))
	fa.close()
	print("PADDLE KEYS -> ", DATA)
	if args.has("check"):
		await _check(data.clips)
	if args.has("preview"):
		await _preview(data.clips)
	quit()


static func _a(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]


## A key: the paddle's blade tip and its grip end (body frame: they give the haft and where the hands are on it), and the body.
## b: hips_y (drop from standing), hips_z, hips_pitch, hips_yaw, chest_pitch, chest_yaw, chest_roll, head_pitch, head_yaw, er, el.
## The keys are written for a stroke on the RIGHT side; `left` gives the same stroke on the left (every x, yaw and roll mirrored, the feet and
## knees swapped) with the hands' roles changed to fit: the right hand, which carries the paddle, is the TOP hand (at the grip end) and the
## left the lower, where on the right side the right hand is the lower and the left the top.
static func _key(t: float, tip: Vector3, grip_end: Vector3, b: Dictionary, ease := "", left := false) -> Dictionary:
	var m := -1.0 if left else 1.0
	var tipm := Vector3(tip.x * m, tip.y, tip.z)
	var gm := Vector3(grip_end.x * m, grip_end.y, grip_end.z)
	var haft := (gm - tipm).normalized()
	var hold_up := PADDLE_UP - PADDLE_SPREAD if left else PADDLE_UP     # where the right hand is on the shaft from the tip
	var spread := -PADDLE_SPREAD if left else PADDLE_SPREAD             # the left hand's, from the right hand (negative: above it)
	var right := tipm + haft * hold_up
	var edge: Vector3 = b.get("edge", Vector3(0, 0, 1))
	var tool := {"grip": _a(right), "haft": _a(haft), "edge": _a(Vector3(edge.x * m, edge.y, edge.z)), "up": hold_up, "spread": spread}
	var er: Vector3 = b.get("er", Vector3(-0.7, -1.0, -0.1))
	var el: Vector3 = b.get("el", Vector3(0.6, -1.0, -0.1))
	var elbows := {"r": _a(er), "l": _a(el)}
	if left:
		elbows = {"r": _a(Vector3(-el.x, el.y, el.z)), "l": _a(Vector3(-er.x, er.y, er.z))}
	var feet := {"l": [0.13, 0.1, 0.0, 0.0, 0.0, 0.0], "r": [-0.13, -0.26, 0.05, 0.0, 0.0, 0.0]}
	var knees := {"r": [0.0, -0.1, 1.0], "l": [0.1, 0.0, 1.0]}
	if left:
		feet = {"r": [-0.13, 0.1, 0.0, 0.0, 0.0, 0.0], "l": [0.13, -0.26, 0.05, 0.0, 0.0, 0.0]}
		knees = {"l": [0.0, -0.1, 1.0], "r": [-0.1, 0.0, 1.0]}
	var k := {"t": t, "tool": tool,
		"hips": {"pos": _a(Vector3(float(b.get("hips_x", 0.0)) * m, float(b.get("hips_y", CROUCH_DROP)), float(b.get("hips_z", 0.0)))),
				"yaw": float(b.get("hips_yaw", 0.0)) * m, "pitch": float(b.get("hips_pitch", 12.0)), "roll": float(b.get("hips_roll", 0.0)) * m},
		"chest": {"yaw": float(b.get("chest_yaw", 0.0)) * m, "pitch": float(b.get("chest_pitch", 10.0)), "roll": float(b.get("chest_roll", 0.0)) * m},
		"head": {"yaw": float(b.get("head_yaw", 0.0)) * m, "pitch": float(b.get("head_pitch", 0.0)), "roll": 0.0},
		"elbows": elbows, "knees": knees, "feet": feet, "fist": 1.0}
	if ease != "":
		k["ease"] = ease
	return k


static func _clips() -> Dictionary:
	var out := _side(false)
	out.merge(_side(true))
	return out


## A key of this side's clips.
static func _k(left: bool, t: float, tip: Vector3, grip_end: Vector3, b: Dictionary, ease := "") -> Dictionary:
	return _key(t, tip, grip_end, b, ease, left)


static func _side(left: bool) -> Dictionary:
	var out := {}
	var sfx := "_l" if left else ""
	# crouched, the paddle held ready: the blade out over the right side by the water, ahead; the grip at the left shoulder; a breath
	var ready_a := {"hips_y": CROUCH_DROP, "hips_pitch": 14.0, "chest_pitch": 12.0, "chest_yaw": -10.0, "head_pitch": -8.0, "head_yaw": -6.0}
	var ready_b := {"hips_y": CROUCH_DROP + 0.015, "hips_pitch": 13.0, "chest_pitch": 11.0, "chest_yaw": -9.0, "head_pitch": -8.0, "head_yaw": -6.0}
	out["paddle_crouch" + sfx] = {"desc": "crouched in the canoe as in the aim crouch, the paddle held ready out over the %s side" % ("left" if left else "right"), "length": 3.0,
		"hold": "blade", "carry": "pipe", "space": "body", "authored": "keyed by hand (tools/anim_author/author_paddle.gd)",
		"keys": [
			_k(left, 0.0, Vector3(-0.55, 0.12, 0.95), Vector3(0.1, 1.0, 0.35), ready_a),
			_k(left, 1.5, Vector3(-0.55, 0.13, 0.95), Vector3(0.1, 1.02, 0.36), ready_b),
			_k(left, 3.0, Vector3(-0.55, 0.12, 0.95), Vector3(0.1, 1.0, 0.35), ready_a),
		]}
	# one stroke on the right: up out of the crouch; the recovery swings the paddle up over the head (the axe's overhead, out to the side)
	# and forward; the blade drops in ahead (the catch); the body's weight pulls it back along the hull (the drive); lifted out at the hip
	var up := CROUCH_DROP + 0.26
	out["paddle_stroke" + sfx] = {"desc": "raised out of the crouch, one full paddle stroke on the %s side (a loop)" % ("left" if left else "right"), "length": 1.6,
		"hold": "blade", "carry": "pipe", "space": "body", "authored": "keyed by hand (tools/anim_author/author_paddle.gd)",
		"keys": [
			# the catch: leaning out and forward, the blade in ahead of the knees, the arms long
			_k(left, 0.0, Vector3(-0.72, 0.02, 1.0), Vector3(0.05, 1.12, 0.5),
					{"hips_y": up, "hips_z": 0.1, "hips_pitch": 24.0, "chest_pitch": 22.0, "chest_yaw": -24.0, "head_pitch": -12.0, "head_yaw": -14.0, "er": Vector3(-0.9, -0.4, 0.3)}),
			# the drive: the body's weight back over the blade, the paddle upright at the side, the top hand pressing down
			_k(left, 0.42, Vector3(-0.78, -0.02, 0.32), Vector3(-0.05, 1.15, 0.22),
					{"hips_y": up + 0.02, "hips_z": -0.02, "hips_pitch": 14.0, "chest_pitch": 14.0, "chest_yaw": -12.0, "head_pitch": -6.0, "head_yaw": -8.0}, "linear"),
			# the exit: the blade drawn out at the hip, the body upright
			_k(left, 0.68, Vector3(-0.82, 0.12, -0.3), Vector3(0.08, 1.02, 0.3),
					{"hips_y": up + 0.05, "hips_z": -0.08, "hips_pitch": 8.0, "chest_pitch": 6.0, "chest_yaw": -4.0, "head_pitch": -2.0, "head_yaw": -2.0}),
			# the recovery: the blade lifted out and the paddle carried up in front of the face, then swung up over and out to the side (the
			# axe's overhead), clear of the head all the way (author_paddle.gd -- check)
			_k(left, 0.85, Vector3(-0.75, 0.5, -0.12), Vector3(0.15, 1.22, 0.52),
					{"hips_y": up + 0.07, "hips_z": 0.0, "hips_pitch": 8.0, "chest_pitch": 4.0, "chest_yaw": -8.0, "head_pitch": -2.0, "head_yaw": -5.0}),
			_k(left, 1.1, Vector3(-0.55, 0.95, 0.22), Vector3(0.3, 1.62, 0.28),
					{"hips_y": up + 0.09, "hips_z": 0.0, "hips_pitch": 4.0, "chest_pitch": 0.0, "chest_yaw": -6.0, "head_pitch": 2.0, "head_yaw": -4.0, "er": Vector3(-0.5, -0.4, -0.2), "el": Vector3(0.4, -0.6, 0.0)}),
			_k(left, 1.35, Vector3(-0.6, 0.55, 0.9), Vector3(0.12, 1.4, 0.35),
					{"hips_y": up + 0.04, "hips_z": 0.06, "hips_pitch": 14.0, "chest_pitch": 12.0, "chest_yaw": -16.0, "head_pitch": -8.0, "head_yaw": -10.0}),
			_k(left, 1.6, Vector3(-0.72, 0.02, 1.0), Vector3(0.05, 1.12, 0.5),
					{"hips_y": up, "hips_z": 0.1, "hips_pitch": 24.0, "chest_pitch": 22.0, "chest_yaw": -24.0, "head_pitch": -12.0, "head_yaw": -14.0, "er": Vector3(-0.9, -0.4, 0.3)}),
		]}
	return out


# --- preview -------------------------------------------------------------------------------------------------------

func _preview(clips: Dictionary) -> void:
	var out := str(args.get("out", "user://author_paddle"))
	DirAccess.make_dir_recursive_absolute(out)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.62, 0.68)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.72, 0.75)
	e.ambient_light_energy = 0.6
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.3
	world.add_child(sun)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.5, 0.38, 0.25)
	floor.material_override = fm
	world.add_child(floor)
	var n := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(n)
	var sk := n.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var aps := n.find_children("*", "AnimationPlayer", true, false)
	CharacterBodyMesh.attach(sk, aps[0] if not aps.is_empty() else null, "res://assets/character/actor_b_body.glb")
	var paddle := BoatGear.make("paddle")
	world.add_child(paddle)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.fov = 50.0
	cam.current = true
	await process_frame
	await process_frame
	var solver = Solver.new(sk)
	for name: String in clips:
		var clip: Dictionary = clips[name]
		solver.hold = str(clip.hold)
		solver.carry = str(clip.get("carry", ""))
		solver.space = str(clip.get("space", "body"))
		var len_s := float(clip.length)
		var moments: Array = [0.0, 0.25, 0.5, 0.75, 1.0] if name == "paddle_stroke" else [0.0, 0.5]
		if name in ["paddle_crouch_l", "paddle_stroke_l", "paddle_crouch"] and not args.has("all"):
			continue
		var views := {"side": [Vector3(-2.9, 0.95, 0.4), Vector3(0, 0.75, 0.4)],
				"front": [Vector3(-1.2, 1.2, 2.6), Vector3(0, 0.75, 0.3)],
				"back": [Vector3(-1.4, 1.5, -2.5), Vector3(0, 0.85, 0.4)]}
		var grid := Image.create(CELL.x * views.size(), CELL.y * moments.size(), false, Image.FORMAT_RGB8)
		for i in moments.size():
			var t: float = float(moments[i]) * len_s
			solver.pose(Swings.pose_at(clip, t))
			sk.force_update_all_bone_transforms()
			var prop := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("r_hand_prop_attachment"))
			paddle.global_transform = prop * Solver.PIPE * PADDLE_IN_HANDS
			var j := 0
			for v: String in views:
				var at: Vector3 = views[v][0]
				cam.transform = Transform3D(Basis.looking_at((views[v][1] as Vector3) - at, Vector3.UP), at)
				for f in 3:
					await RenderingServer.frame_post_draw
				var img: Image = root.get_viewport().get_texture().get_image()
				img.convert(Image.FORMAT_RGB8)
				var win := img.get_size()
				var sq := mini(win.x, win.y)
				var crop := img.get_region(Rect2i((win.x - sq) / 2, (win.y - sq) / 2, sq, sq))
				crop.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
				grid.blit_rect(crop, Rect2i(Vector2i.ZERO, CELL), Vector2i(j * CELL.x, i * CELL.y))
				j += 1
		grid.save_png(out.path_join(name + ".png"))
		print("  ", name, " -> ", out.path_join(name + ".png"))
	print("PADDLE PREVIEW DONE")


# --- clearance ------------------------------------------------------------------------------------------------------
## The shaft's least distance from the body's middle line (pelvis to head) over each clip, ignoring the stretch of shaft in the hands
## (HAND_M of each palm): the torso is about TORSO_R m thick to its middle, the head HEAD_R. A shaft nearer than that goes through the body.
const TORSO_R := 0.16
const HEAD_R := 0.13
const HAND_M := 0.16
const SPINE_LINE := ["pelvis", "spinea", "spineb", "spinec", "spined", "neck"]


func _check(clips: Dictionary) -> void:
	var n := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(n)
	var sk := n.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	await process_frame
	var solver = Solver.new(sk)
	var bad := 0
	for name: String in clips:
		var clip: Dictionary = clips[name]
		solver.hold = str(clip.hold)
		solver.carry = str(clip.get("carry", ""))
		solver.space = str(clip.get("space", "body"))
		var worst := INF
		var worst_t := 0.0
		var worst_head := INF
		var head_top := -INF
		var steps := 24
		for i in steps + 1:
			var t := float(clip.length) * float(i) / float(steps)
			solver.pose(Swings.pose_at(clip, t))
			sk.force_update_all_bone_transforms()
			var line: Array[Vector3] = []
			for bn: String in SPINE_LINE:
				line.append(sk.get_bone_global_pose(sk.find_bone(bn)).origin)
			var head := sk.get_bone_global_pose(sk.find_bone("headb")).origin
			head_top = maxf(head_top, head.y)
			var lp := sk.get_bone_global_pose(sk.find_bone("l_palm")).origin
			var rp := sk.get_bone_global_pose(sk.find_bone("r_palm")).origin
			var tw: Transform3D = solver.tool_world
			for k in 28:
				var pt := tw.origin + tw.basis.y.normalized() * PADDLE_LEN * float(k) / 27.0
				if pt.distance_to(lp) < HAND_M or pt.distance_to(rp) < HAND_M:
					continue
				var d := INF
				for j in line.size() - 1:
					d = minf(d, _seg_dist(pt, line[j], line[j + 1]))
				if d < worst:
					worst = d
					worst_t = t
				worst_head = minf(worst_head, pt.distance_to(head))
		var ok := worst >= TORSO_R and worst_head >= HEAD_R
		if not ok:
			bad += 1
		print("  %-18s shaft to the body's middle %.3f m (t %.2f s, wants >= %.2f), to the head %.3f m (wants >= %.2f) %s" % [name, worst, worst_t, TORSO_R, worst_head, HEAD_R, "ok" if ok else "THROUGH THE BODY"])
	print("PADDLE CLEARANCE ", "OK" if bad == 0 else "FAILED (%d clips)" % bad)


static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var u := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
	return p.distance_to(a + ab * u)
