extends SceneTree
## A saber drawn, the scabbard steadied (user 2026-10-01: "a pose where the left hand is on the sheath while a sword is drawn
## on the right"): Actor_B standing easy, the saber (tools/models/saber.py, assets/weapons/saber.glb) in the right hand at the
## carry: the hand by the right hip, the blade up and a little forward, the edge ahead; the left fist closed round the
## scabbard's locket at the left hip, the empty scabbard hanging down and back from it. This project's own pose
## (tools/anim_author/pose_solver.gd: two-bone IK, the fists closed on the grip and on the scabbard), written as a one-key
## looping clip "own-saber-drawn-scabbard" into data/anim_author/saber_pose.tres; the saber on the right hand's prop bone
## (SABER_PROP_OFFSET, measured in saber.py), the scabbard placed in body space (SCABBARD_* below), and renders
## (front, the left side, three-quarter) to look at.
##   Godot --path . --resolution 1200x1200 -s tools/anim_author/author_saber_pose.gd -- [out=/abs/dir]

const Solver := preload("res://tools/anim_author/pose_solver.gd")
const SABER := "res://assets/weapons/saber.glb"
const OUT_CLIP := "res://data/anim_author/saber_pose.tres"
## saber.py, "Holding it": the model on r_hand_prop_attachment (model -Z along the prop's +Y, model +Y the finger side).
const SABER_PROP_OFFSET := Transform3D(Basis(Vector3(-0.9397, 0.0915, -0.3295), Vector3(0.3256, -0.0551, -0.9439),
		Vector3(-0.1045, -0.9943, 0.0220)), Vector3(0.0057, 0.0059, -0.0060))
## The felling axe's hold instead (user 2026-10-01: "use the same hand hold as a fell axe"): GatherTools hangs a tool on the prop bone
## with its haft along the bone's +Y and its edge along -Z, the hand round the haft at the bone (blade_offset: the knob carry_grip_m
## below). The saber the same way: its grip's middle at the bone, its blade (model -Z) along +Y, its edge (model +Y) along -Z.
const AXE_HOLD := Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0, -1, 0)), Vector3.ZERO)
## The saber in the fist's hole frame (PoseSolver.fist_rel: +Y along the knuckles' line out of the thumb's side, +Z toward the middle
## knuckle): model -Z (the blade) along +Y, model +Y (the edge) along +Z.
const IN_FIST := Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)), Vector3.ZERO)
## The pose, in body space (faces +Z, left +X, up +Y, m).
## The saber: the right hand by the hip, a little ahead; the blade up, forward and a touch out; the edge ahead.
const GRIP := Vector3(-0.21, 0.98, 0.20)
const BLADE := Vector3(-0.06, 0.80, 0.60)
const EDGE := Vector3(0.0, -0.35, 1.0)
## The scabbard: its throat at the left hip, hanging down and back (as a frog on the belt holds it), the left fist round its
## locket a hand's width below the throat.
const THROAT := Vector3(0.20, 0.99, 0.10)
const SCABBARD_DOWN := Vector3(0.05, -0.62, -0.78)
const HAND_DOWN := 0.07

var sk: Skeleton3D
var solver
var out_dir := "/tmp"
var _pose := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.trim_prefix("--").begins_with("out="):
			out_dir = a.trim_prefix("--").get_slice("=", 1)
	var actor := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(actor)
	await process_frame
	sk = actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	ap.stop()
	ap.active = false          # (it puts its own pose back every frame otherwise)
	var body := CharacterBodyMesh.attach(sk, ap)
	if body:
		PlayerAppearance.dress(body, AppearanceStore.load_current())
	solver = Solver.new(sk)
	solver.hold = "blade"
	# the right fist's hole (the curled fingers' tunnel) in the wrist's frame, before the pose: the saber's grip goes there
	var hole: Transform3D = solver.fist_rel("r")
	var down := SCABBARD_DOWN.normalized()
	var p := {
		"hips": {"pos": [0.0, -0.02, 0.0], "yaw": 6.0},
		"chest": {"yaw": -4.0, "pitch": 2.0},
		"head": {"yaw": -6.0, "pitch": -4.0},
		"tool": {"grip": [GRIP.x, GRIP.y, GRIP.z], "haft": [BLADE.x, BLADE.y, BLADE.z], "edge": [EDGE.x, EDGE.y, EDGE.z],
				"lhand": {"at": _arr(THROAT + down * HAND_DOWN), "haft": _arr(-down), "edge": [0.0, 0.0, 1.0]}},
		"elbows": {"r": [-0.6, -0.4, -0.5], "l": [0.7, -0.3, -0.4]},
	}
	_pose = p
	solver.pose(p)
	sk.force_update_all_bone_transforms()
	# the saber on the right hand's prop bone
	var saber := (load(SABER) as PackedScene).instantiate() as Node3D
	var att := BoneAttachment3D.new()
	att.bone_name = "r_wrist"
	sk.add_child(att)
	att.add_child(saber)
	# its grip in the fist's hole (user 2026-10-01: "have it grip the saber"): the blade out of the thumb's side (the hole's +Y), the
	# edge toward the knuckles (+Z: the knuckle bow over them); the hand itself is the felling axe's hold (AXE_HOLD, the pose)
	saber.transform = hole * IN_FIST
	var sc_in_hand := saber.find_child("Scabbard", true, false) as Node3D
	if sc_in_hand:
		sc_in_hand.visible = false
	# the empty scabbard hung from the left hip, the fist round its locket
	var sheath := (load(SABER) as PackedScene).instantiate() as Node3D
	actor.add_child(sheath)
	var blade_node := sheath.find_child("Saber", true, false) as Node3D
	if blade_node:
		blade_node.visible = false
	var throat_m := sheath.find_child("Throat", true, false) as Node3D
	var throat_local := throat_m.position if throat_m else Vector3(0, 0, -0.05)
	# model -Z down the scabbard, model +Y (the edge side) ahead
	var mz := -down
	var my := (Vector3(0, 0, 1) - down * Vector3(0, 0, 1).dot(down)).normalized()
	var mx := my.cross(mz).normalized()
	var b := Basis(mx, my, mz)
	sheath.transform = Transform3D(b, THROAT - b * throat_local)
	# how close the hands came
	var rel_l: Transform3D = solver.fist_rel("l")
	var lw := sk.get_bone_global_pose(sk.find_bone("l_wrist")) * rel_l
	print("SABER POSE left fist %.3f m from its place on the locket" % lw.origin.distance_to(THROAT + down * HAND_DOWN))
	print("SABER POSE saber tip at %s" % (saber.global_transform * Vector3(0, 0, -0.70)).snappedf(0.01))
	_write_clip()
	await _renders()
	quit()


static func _arr(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


## The pose as a one-key looping clip on every bone (rotations; the root's and the hips' places too).
func _write_clip() -> void:
	var anim := Animation.new()
	anim.length = 1.0
	anim.loop_mode = Animation.LOOP_LINEAR
	for i in sk.get_bone_count():
		var path := NodePath("Skeleton3D:" + sk.get_bone_name(i))
		var rt := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(rt, path)
		anim.rotation_track_insert_key(rt, 0.0, sk.get_bone_pose_rotation(i))
		if sk.get_bone_name(i) in ["root", "pelvis", "r_hand_prop_attachment", "l_hand_prop_attachment"]:
			var pt := anim.add_track(Animation.TYPE_POSITION_3D)
			anim.track_set_path(pt, path)
			anim.position_track_insert_key(pt, 0.0, sk.get_bone_pose_position(i))
	var lib := AnimationLibrary.new()
	lib.add_animation("own-saber-drawn-scabbard", anim)
	var err := ResourceSaver.save(lib, OUT_CLIP)
	print("SABER POSE clip -> %s (%s)" % [OUT_CLIP, error_string(err)])


func _renders() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.62, 0.63, 0.65)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.62)
	e.ambient_light_energy = 0.8
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	root.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 30.0
	root.add_child(cam)
	cam.current = true
	var target := Vector3(0, 1.0, 0)
	for v: Array in [["front", Vector3(0, 0.15, 1)], ["left", Vector3(1, 0.12, 0.05)], ["threequarter", Vector3(0.7, 0.18, 0.75)],
			["right", Vector3(-1, 0.12, 0.2)]]:
		cam.global_position = target + (v[1] as Vector3).normalized() * 4.4
		cam.look_at(target, Vector3.UP)
		for i in 6:
			solver.pose(_pose)
			await process_frame
		solver.pose(_pose)
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/saber_pose_%s.png" % [out_dir, v[0]])
	# the right hand close
	var hand := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("r_hand_prop_attachment")).origin
	for v: Array in [["hand_out", Vector3(-1, 0.3, 0.6)], ["hand_in", Vector3(0.6, 0.4, 0.9)]]:
		cam.global_position = hand + (v[1] as Vector3).normalized() * 0.75
		cam.look_at(hand, Vector3.UP)
		for i in 4:
			solver.pose(_pose)
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/saber_pose_%s.png" % [out_dir, v[0]])
	print("SABER POSE renders in ", out_dir)
