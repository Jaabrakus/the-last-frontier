extends SceneTree
## Loadout body-fit screenshots (windowed; the window appears on screen for a few seconds).
##
##   Godot --path <Frontier> --resolution 1000x1000 -s tools/loadout/fit_screenshots.gd -- \
##       out=/abs/dir [survey=res://data/loadout/carry_points_survey.json]
##
## Actor_B + the legacy body (CharacterBodyMesh) in the first frame of the stealth idle, lit
## neutrally, orthographic cameras around the belt. Two sets:
##   belt_current_{front,back,right,left}.png   today's body: belt, crossed straps, shot pouch,
##                                              the old powder horn at the right hip
##   proposed_{front,back,right,left,back_full,three_quarter}.png
##                                              the old horn hidden, the recommended stow
##                                              placements of data/loadout/carry_points_survey.json
##                                              drawn as coloured capsules (pistol red, tomahawk
##                                              orange, knife yellow, horn tan, musket brown,
##                                              bow green, quiver blue, atlatl purple)
## Read-only: nothing in the project is written.

const LIB := "actor_b/"
const SHOW := ["belt.R_hip.pistol", "belt.back.tomahawk", "belt.back_left.knife", "belt.L_hip.pistol",
		"horn.back_R_top", "back.long_A.musket_outer", "back.long_B.bow", "back.quiver"]
const COLORS := {"pistol": Color(0.85, 0.15, 0.12), "tomahawk": Color(0.95, 0.55, 0.1), "knife": Color(0.95, 0.85, 0.2),
		"horn": Color(0.85, 0.72, 0.5), "musket": Color(0.45, 0.25, 0.12), "bow": Color(0.2, 0.65, 0.25),
		"quiver": Color(0.2, 0.4, 0.85), "atlatl": Color(0.55, 0.3, 0.75), "saber": Color(0.7, 0.7, 0.75)}

var args := {}
var sk: Skeleton3D
var body: CharacterBodyMesh
var cam: Camera3D
var overlay: Node3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	_run()


func _run() -> void:
	var out: String = args.get("out", OS.get_user_data_dir())
	DirAccess.make_dir_recursive_absolute(out)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.82, 0.83, 0.85)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.75, 0.78)
	e.ambient_light_energy = 0.9
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	world.add_child(env)
	for d in [Vector3(-0.6, -1.0, -0.8), Vector3(0.7, -0.6, 0.9)]:
		var l := DirectionalLight3D.new()
		l.light_energy = 1.1 if d.z < 0 else 0.7
		world.add_child(l)
		l.look_at_from_position(Vector3.ZERO, d, Vector3.UP)
	var inst := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate()
	world.add_child(inst)
	sk = inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	BindRest.ensure(sk, ap)
	body = CharacterBodyMesh.attach(sk, ap)
	ap.play(LIB + "actor_b-p-stealth-idle")
	ap.seek(0.0, true)
	ap.pause()
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	world.add_child(cam)
	cam.current = true
	for i in 6:
		await process_frame
	# today's body
	await _views(out, "belt_current", false)
	# proposed: hide the old horn surfaces, draw the placements
	_hide_old_horn()
	overlay = Node3D.new()
	world.add_child(overlay)
	_draw_placements(ap)
	await _views(out, "proposed", true)
	print("SCREENSHOTS DONE -> ", out)
	quit()


func _views(out: String, prefix: String, full: bool) -> void:
	var c := Vector3(0, 0.93, 0.02)
	var views := [["front", c + Vector3(0, 0, 2.5), 0.95], ["back", c + Vector3(0, 0, -2.5), 0.95],
			["right", c + Vector3(-2.5, 0, 0), 0.95], ["left", c + Vector3(2.5, 0, 0), 0.95]]
	if full:
		views.append(["back_full", Vector3(0, 1.3, -3.0), 2.45])
		views.append(["three_quarter", Vector3(-2.0, 1.45, -2.2), 2.1])
	for v: Array in views:
		var eye: Vector3 = v[1]
		var target := c if v[2] < 1.5 else Vector3(0, 1.25 if v[0] == "back_full" else 1.15, 0)
		cam.size = v[2]
		cam.look_at_from_position(eye, target, Vector3.UP)
		for i in 4:
			await process_frame
		var img := root.get_texture().get_image()
		var path := "%s/%s_%s.png" % [out, prefix, v[0]]
		img.save_png(path)
		print("saved ", path)


func _hide_old_horn() -> void:
	var clear := StandardMaterial3D.new()
	clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	clear.albedo_color = Color(1, 1, 1, 0)
	for mi in body.meshes:
		if String(mi.name) != "Gear":
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if m and m.resource_name in ["horn", "wood", "horn_tip"]:
				mi.set_surface_override_material(s, clear)


func _draw_placements(ap: AnimationPlayer) -> void:
	var path: String = args.get("survey", "res://data/loadout/carry_points_survey.json")
	var survey = JSON.parse_string(FileAccess.get_file_as_string(path))
	var nulladd := ap.get_animation(LIB + "null-add")
	var bind := CharacterBodyMesh.bind_pose_globals(sk, nulladd)
	for pid: String in SHOW:
		var p: Dictionary = survey.placements.get(pid, {})
		if p.is_empty():
			continue
		var col: Color = COLORS.get(p.kind, Color.WHITE)
		for cid in p.capsules:
			var cp: Dictionary = p.capsules[cid]
			var bn: String = cp.bone if cp.bone != "skin2" else "pelvis"
			var b := sk.find_bone(bn)
			var m := sk.get_bone_global_pose(b) * (bind[b] as Transform3D).affine_inverse()
			var fa: Array = cp["from"]
			var a := m * Vector3(fa[0], fa[1], fa[2])
			var ta: Array = cp["to"]
			var z := m * Vector3(ta[0], ta[1], ta[2])
			_capsule(a, z, float(cp.radius), col)


func _capsule(a: Vector3, b: Vector3, r: float, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = a.distance_to(b) + 2.0 * r
	cm.radial_segments = 16
	cm.rings = 4
	mi.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.6
	mat.emission_enabled = true
	mat.emission = col * 0.25
	mi.material_override = mat
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	mi.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)
	overlay.add_child(mi)
