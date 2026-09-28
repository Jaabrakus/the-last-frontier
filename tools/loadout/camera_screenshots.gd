extends SceneTree
## Loadout readability from the GAMEPLAY camera (windowed; the window appears on screen for a few seconds).
##
##   Godot --path <Frontier> --resolution 1280x720 -s tools/loadout/camera_screenshots.gd -- out=/abs/dir \
##       [presets=musket_bow,ranger_1758,...] [views=stand,crouch,aim,yaw90,yaw180,close] [hand=none|<kind>[@point]] [tag=x]
##
## Actor_B + the legacy body (the old right-hip horn hidden), posed on the first frame of a clip, with the
## weapon models of a preset (data/loadout/loadout_presets.json) placed at their stowed transforms
## (data/loadout/carry_gear.json points.*.stow.bind carried rigidly by the stow bone; two-anchor items are
## drawn rigid, which is exact in these idle poses to a few mm) and the in-hand weapon on its hand prop bone
## (Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO), as player.gd). The quiver and the reshaped powder horn
## are simple stand-in shapes (their models are later work). Straps are not drawn.
##
## Camera = player.gd: pivot eye_height 2.3 m above the feet (crouch 1.8 m), camera_distance 3.6 m behind,
## shoulder_offset 0, fov 70, pitch 0; the crosshair (drawn) is the screen centre = the pivot. The player's
## body always faces the camera direction while alive (player.gd rotation.y = yaw), so yaw 0 is the gameplay
## view; yaw 90 / 180 are the dead-orbit views, shown for completeness.
##
## Views: stand (stealth idle), crouch (crouch idle), aim (the in-hand weapon's aim idle), yaw90, yaw180,
## close (orthographic right side and back of the belt, for the pistol and horn). Files:
##   <out>/<preset>_<view>.png
## Read-only: nothing in the project is written.

const LIB := "actor_b/"
const CARRY := "res://data/loadout/carry_gear.json"
const PRESETS := "res://data/loadout/loadout_presets.json"
const AIM := {"musket": "actor_b-p-rifle-idle-aim", "pistol": "actor_b-p-pistol-aim-idle", "bow": "actor_b-p-bow-aim-idle"}
const EYE := 2.3
const CROUCH_DROP := 0.5
const DIST := 3.6
const FOV := 70.0

var args := {}
var sk: Skeleton3D
var ap: AnimationPlayer
var body: CharacterBodyMesh
var cam: Camera3D
var items_root: Node3D
var bind := []
var carry := {}
var presets := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	_run()


func _run() -> void:
	var out: String = args.get("out", OS.get_user_data_dir())
	DirAccess.make_dir_recursive_absolute(out)
	carry = JSON.parse_string(FileAccess.get_file_as_string(CARRY))
	presets = JSON.parse_string(FileAccess.get_file_as_string(PRESETS))
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.62, 0.68, 0.72)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.82)
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	world.add_child(env)
	for d in [Vector3(-0.5, -1.0, 0.7), Vector3(0.6, -0.5, -0.8)]:
		var l := DirectionalLight3D.new()
		l.light_energy = 1.2 if d.z > 0 else 0.6
		world.add_child(l)
		l.look_at_from_position(Vector3.ZERO, d, Vector3.UP)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 12)
	ground.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.42, 0.45, 0.36)
	ground.material_override = gmat
	world.add_child(ground)
	var inst := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate()
	world.add_child(inst)
	sk = inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	ap = inst.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	BindRest.ensure(sk, ap)
	body = CharacterBodyMesh.attach(sk, ap)
	bind = CharacterBodyMesh.bind_pose_globals(sk, ap.get_animation(LIB + "null-add"))
	_hide_old_horn()
	cam = Camera3D.new()
	cam.fov = FOV
	world.add_child(cam)
	cam.current = true
	_crosshair()
	items_root = Node3D.new()
	world.add_child(items_root)
	var want: Array = String(args.get("presets", ",".join(presets.presets.keys()))).split(",", false)
	var views: Array = String(args.get("views", "stand,crouch,aim,yaw90,yaw180")).split(",", false)
	for pid: String in want:
		if not presets.presets.has(pid):
			continue
		var pr: Dictionary = presets.presets[pid].duplicate()
		if args.has("hand"):
			pr["in_hand"] = "" if String(args.hand) == "none" else String(args.hand)
		var hand_kind := _kind(pr.get("in_hand", ""))
		for v: String in views:
			var clip: String = "actor_b-p-stealth-idle"
			if v == "crouch":
				clip = "actor_b-p-crouch-idle"
			elif v == "aim":
				clip = String(AIM.get(hand_kind, "actor_b-p-stealth-idle"))
			_pose(clip)
			await process_frame
			await process_frame
			_place(pr)
			if v == "close":
				await _close_views(out, pid)
				continue
			var eye: float = EYE - (CROUCH_DROP if v == "crouch" else 0.0)
			var yaw := 0.0
			if v == "yaw90":
				yaw = 90.0
			elif v == "yaw180":
				yaw = 180.0
			var piv := Vector3(0, eye, 0)
			var dir := Vector3(sin(deg_to_rad(yaw)), 0, -cos(deg_to_rad(yaw)))
			cam.projection = Camera3D.PROJECTION_PERSPECTIVE
			cam.fov = FOV
			cam.look_at_from_position(piv + dir * DIST, piv, Vector3.UP)
			for i in 3:
				await process_frame
			var path := "%s/%s%s_%s.png" % [out, pid, String(args.get("tag", "")), v]
			var img := root.get_texture().get_image()
			img.save_png(path)
			# the lower-middle of the frame, where the character stands, at 2x (same camera, for reading details)
			var w := img.get_width()
			var h := img.get_height()
			var crop := img.get_region(Rect2i(int(w * 0.34), int(h * 0.36), int(w * 0.32), int(h * 0.64)))
			crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_BILINEAR)
			crop.save_png(path.replace(".png", "_crop2x.png"))
			print("saved ", path)
	print("CAMERA SHOTS DONE -> ", out)
	quit()


func _close_views(out: String, pid: String) -> void:
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	for v: Array in [["right", Vector3(-2.5, 1.05, 0.0)], ["back", Vector3(0.0, 1.25, -2.5)], ["front", Vector3(0.0, 1.05, 2.5)]]:
		cam.size = 1.1 if String(v[0]) != "back" else 1.9
		var eye_p: Vector3 = v[1]
		cam.look_at_from_position(eye_p, Vector3(0, eye_p.y, 0), Vector3.UP)
		for i in 3:
			await process_frame
		var path := "%s/%s%s_close_%s.png" % [out, pid, String(args.get("tag", "")), v[0]]
		root.get_texture().get_image().save_png(path)
		print("saved ", path)


func _pose(clip: String) -> void:
	ap.play(LIB + clip)
	ap.seek(0.0, true)
	ap.pause()


func _kind(v: Variant) -> String:
	if v is Dictionary:
		return String(v.get("kind", ""))
	return String(v).get_slice("@", 0)


## The world transform of a bind-space transform carried rigidly by `bone` in the current pose.
func _carry(bone: String, t_bind: Transform3D) -> Transform3D:
	var b := sk.find_bone(bone)
	return sk.global_transform * sk.get_bone_global_pose(b) * (bind[b] as Transform3D).affine_inverse() * t_bind


func _place(pr: Dictionary) -> void:
	for c in items_root.get_children():
		c.free()
	var in_hand: String = String(pr.get("in_hand", ""))
	var hand_kind := _kind(in_hand)
	var hand_point: String = in_hand.get_slice("@", 1) if "@" in in_hand else ""
	var hand_done := false
	for pt: String in pr.items:
		var v: Variant = pr.items[pt]
		var kind := _kind(v)
		var count: int = int(v.get("count", 1)) if v is Dictionary else 1
		var key := "%s.%s" % [pt, kind]
		var in_hand_here: bool = kind == hand_kind and not hand_done and (hand_point == "" or hand_point == pt)
		if in_hand_here:
			hand_done = true
			_hand_model(kind)
			if kind != "spear_pair":
				continue
			count -= 1
		if not carry.points.has(key):
			continue
		var p: Dictionary = carry.points[key]
		if not p.has("stow"):
			_capsules(p, kind)
			continue
		var tb: Transform3D = str_to_var(String(p.stow.bind))
		var world := _carry(String(p.stow.bone), tb)
		match kind:
			"musket", "pistol", "bow":
				var m := WeaponModels.build(kind)
				items_root.add_child(m)
				m.global_transform = world
			"spear_pair":
				for i in count:
					var m := ThrowableModels.build("spear")
					items_root.add_child(m)
					m.global_transform = world * Transform3D(Basis(), Vector3(0.036 * i, 0, 0))
			"dart_bundle":
				for i in count:
					var m := ThrowableModels.build("atlatl_dart")
					items_root.add_child(m)
					var a := TAU * i / 5.0
					m.global_transform = world * Transform3D(Basis(), Vector3(cos(a), sin(a), 0) * 0.015)
			"tomahawk", "atlatl":
				var m := ThrowableModels.build(kind)
				items_root.add_child(m)
				m.global_transform = world
			"quiver":
				_quiver(world, int(v.get("arrows", 24)) if v is Dictionary else 24)
			_:
				_capsules(p, kind)
	if pr.gear.has("horn_strap") and carry.points.has("horn.powder_horn"):
		_capsules(carry.points["horn.powder_horn"], "powder_horn")


func _hand_model(kind: String) -> void:
	var name: String = {"spear_pair": "spear", "tomahawk": "tomahawk", "atlatl": "atlatl"}.get(kind, kind)
	var left := kind == "bow"
	var att := sk.find_bone("l_hand_prop_attachment" if left else "r_hand_prop_attachment")
	var m: Node3D = WeaponModels.build(name) if kind in ["musket", "pistol", "bow"] else ThrowableModels.build(name)
	items_root.add_child(m)
	m.global_transform = sk.global_transform * sk.get_bone_global_pose(att) * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)


func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.7
	return m


func _cyl(a: Vector3, b: Vector3, r0: float, r1: float, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r1
	cm.bottom_radius = r0
	cm.height = a.distance_to(b)
	cm.radial_segments = 14
	mi.mesh = cm
	mi.material_override = _mat(col)
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	mi.transform = Transform3D(Basis(x, y, x.cross(y) * -1.0).orthonormalized(), (a + b) * 0.5)
	items_root.add_child(mi)


func _quiver(world: Transform3D, arrows: int) -> void:
	# origin = mouth, +Y out of the mouth; 0.674 m long, radius 5 cm, leather
	var mouth := world.origin
	var down := -world.basis.y.normalized()
	_cyl(mouth + down * 0.674, mouth, 0.04, 0.05, Color(0.42, 0.26, 0.14))
	for i in mini(arrows, 8):
		var a := TAU * i / 8.0
		var o := mouth + (world.basis.x * cos(a) + world.basis.z * sin(a)).normalized() * 0.025
		_cyl(o - down * 0.0, o - down * 0.16, 0.004, 0.004, Color(0.75, 0.62, 0.42))
		_cyl(o - down * 0.08, o - down * 0.16, 0.012, 0.002, Color(0.9, 0.88, 0.8))


## Capsule stand-ins from capsules_bind (horn: tan horn with a dark wooden plug; others grey).
func _capsules(p: Dictionary, kind: String) -> void:
	var caps: Array = p.get("capsules_bind", [])
	for i in caps.size():
		var c: Dictionary = caps[i]
		var bone: String = String(c.bone) if String(c.bone) != "skin2" else "pelvis"
		var fa: Array = c["from"]
		var ta: Array = c["to"]
		var a := _carry(bone, Transform3D(Basis(), Vector3(fa[0], fa[1], fa[2]))).origin
		var b := _carry(bone, Transform3D(Basis(), Vector3(ta[0], ta[1], ta[2]))).origin
		var r: float = float(c.radius)
		if kind == "powder_horn":
			var r1: float = r * 0.62 if i == 0 else r * 0.45
			_cyl(a, b, r, r1, Color(0.86, 0.78, 0.6))
			if i == 0:
				_cyl(a - (b - a).normalized() * 0.02, a, r * 1.02, r * 1.02, Color(0.35, 0.2, 0.1))
			else:
				_cyl(b, b + (b - a).normalized() * 0.03, 0.007, 0.007, Color(0.35, 0.2, 0.1))
		else:
			_cyl(a, b, r, r, Color(0.5, 0.5, 0.5))


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


func _crosshair() -> void:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	for r: Rect2 in [Rect2(Vector2(-9, -1), Vector2(18, 2)), Rect2(Vector2(-1, -9), Vector2(2, 18))]:
		var cr := ColorRect.new()
		cr.color = Color(1, 0.2, 0.2, 0.9)
		cr.set_anchors_preset(Control.PRESET_CENTER)
		cr.offset_left = r.position.x
		cr.offset_top = r.position.y
		cr.offset_right = r.position.x + r.size.x
		cr.offset_bottom = r.position.y + r.size.y
		layer.add_child(cr)
