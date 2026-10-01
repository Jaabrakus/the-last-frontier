extends SceneTree
## Renders an authored move and the native one, side by side, in the game's renderer (the body's helper bones are driven at run time,
## so this is how the arms and the coat really look).
##   Godot --path . -s tools/anim_author/blender/preview_move.gd -- ours=<baked.json> native=<baked_native.json> obstacles=<..._obstacles.json>
##     out=<dir> [frames=24] [center=0,1.05,0.25] [dist=4.2]
## The authored span starts at ours.t_a in the move's time; native frames are sampled at t_a + t.
var args := {}


func _initialize() -> void:
	call_deferred("run")


static func build(d: Dictionary, bones: Dictionary, prefix: String) -> Animation:
	var a := Animation.new()
	a.length = float(d.length)
	a.loop_mode = Animation.LOOP_NONE
	var frames: Array = d.frames
	var tr_root := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(tr_root, NodePath(prefix + ":root"))
	for f in frames:
		var p: Array = f.root
		a.position_track_insert_key(tr_root, float(f.t), Vector3(p[0], p[1], p[2]))
	for b: String in bones:
		if not (frames[0].rot as Dictionary).has(b):
			continue
		var ti := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(ti, NodePath(prefix + ":" + b))
		var prev := Quaternion.IDENTITY
		for i in frames.size():
			var r: Array = frames[i].rot[b]
			var q := Quaternion(r[0], r[1], r[2], r[3]).normalized()
			if i > 0 and prev.dot(q) < 0.0:
				q = -q
			prev = q
			a.rotation_track_insert_key(ti, float(frames[i].t), q)
	return a


func run() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		args[s.get_slice("=", 0)] = s.substr(s.find("=") + 1)
	var out := str(args.out)
	DirAccess.make_dir_recursive_absolute(out)
	var ours: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(args.ours)))
	var nat: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(args.native)))
	var t_a := float(ours.t_a)
	# the bones the move's own clips key (the helper bones are the body's to drive)
	var lib := load("res://animations/Actor_B.res") as AnimationLibrary
	var bones := {}
	var prefix := "Skeleton3D"
	for p in ours.parts:
		var c := lib.get_animation(String(p.clip))
		for ti in c.get_track_count():
			if c.track_get_type(ti) == Animation.TYPE_ROTATION_3D:
				bones[String(c.track_get_path(ti).get_concatenated_subnames())] = true
				prefix = String(c.track_get_path(ti)).get_slice(":", 0)
	var native_a := build(nat, bones, prefix)
	var ours_a := build(ours, bones, prefix)
	for ob: Array in JSON.parse_string(FileAccess.get_file_as_string(str(args.obstacles))):
		_box(Vector3(ob[1][0], ob[1][1], ob[1][2]), Vector3(ob[2][0], ob[2][1], ob[2][2]), Color(ob[3][0], ob[3][1], ob[3][2]))
	_box(Vector3(-4, -0.05, -3), Vector3(4, 0.0, 5), Color(0.42, 0.45, 0.4))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.62, 0.68)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.77, 0.8)
	e.ambient_light_energy = 0.7
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.3
	root.add_child(sun)
	var n := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(n)
	var sk := n.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var aps := n.find_children("*", "AnimationPlayer", true, false)
	CharacterBodyMesh.attach(sk, aps[0], "res://assets/character/actor_b_body.glb")
	var ap := aps[0] as AnimationPlayer
	ap.speed_scale = 0.0
	var l := AnimationLibrary.new()
	l.add_animation(&"ours", ours_a)
	l.add_animation(&"native", native_a)
	ap.add_animation_library("v", l)
	var view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(330, 440))
	var cam: Camera3D = view.camera
	cam.fov = float(args.get("fov", 34.0))
	await process_frame
	await process_frame
	var frames := int(args.get("frames", 24))
	var c := str(args.get("center", "0,1.05,0.25")).split(",")
	var center := Vector3(float(c[0]), float(c[1]), float(c[2]))
	var dist := float(args.get("dist", 4.2))
	var all_views := {"side": center + Vector3(-dist, 0.1, 0), "back": center + Vector3(0, 0.25, -dist), "front": center + Vector3(0, 0.25, dist),
			"left": center + Vector3(dist, 0.1, 0), "front34": center + Vector3(-dist * 0.55, 0.3, dist * 0.8)}
	var views := {}
	for vn in str(args.get("views", "side,back")).split(","):
		views[vn] = all_views[vn]
	for vn: String in views:
		for who in ["native", "ours"]:
			ap.play("v/" + who)
			for i in frames:
				var t := float(ours.length) * float(i) / float(frames - 1)
				ap.seek(t + (t_a if who == "native" else 0.0), true)
				sk.force_update_all_bone_transforms()
				# (reading the pose after the seek makes the skeleton apply it before the picture is taken)
				var _flush := sk.get_bone_global_pose(sk.find_bone("pelvis")).origin + Vector3(ap.current_animation_position, 0, 0)
				cam.global_position = views[vn]
				cam.look_at(center)
				for f in 3:
					await process_frame
				RenderingServer.force_draw()    # (a covered window is not drawn on macOS; the offscreen view is, when forced)
				view.get_texture().get_image().save_png("%s/%s_%s_%02d.png" % [out, vn, who, i])
	print("PREVIEW ", out)
	quit()


const OffscreenView := preload("res://tools/environment/offscreen_view.gd")


func _box(lo: Vector3, hi: Vector3, c: Color) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = hi - lo
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	m.material_override = mat
	m.position = (lo + hi) * 0.5
	root.add_child(m)
