extends SceneTree
## Look-development shots of the horse under the game's lighting (EnvironmentRig: the
## late-afternoon HDRI sky, the sun at 19 deg, AgX, grade LUT) on Poly Haven forest ground,
## with Actor_B standing beside it for scale. Needs a window (not --headless); run it under a
## time limit, a script error leaves the window open.
##
##   Godot --path . --resolution 1280x720 -s tests/horse/horse_look_shots.gd -- out=/tmp/look \
##       [shots=turn,close,coats,ride,level] [coat=bay] [quality=high]
##
## turn   eight views round the standing horse, tacked, Actor_B beside it (turn_*.png, turn.png)
## close  head, eye, muzzle, legs, hooves, mane and tail close-ups (close_*.png, close.png)
## coats  the six coats side by side (coats.png) and head close-ups of each (coats_heads.png)
## ride   Actor_B mounted at a few gait phases (ride.png)
## level  the horse in the Frontier level next to the player (level_*.png)

const Rig := preload("res://tests/horse/horse_test_rig.gd")
const HorseLook := preload("res://scripts/horse/horse_look.gd")
const STAND_CLIPS := ["actor_b/actor_b-ambi-run^vault-over-round-up-exit-idle", "actor_b/actor_b-crouch-walk-fw^idle"]
const GROUND := "res://assets/polyhaven/textures/terrain/forest_ground_04/forest_ground_04_"

var args := {}
var r
var cam: Camera3D
var label: Label
var out := ""
var env_rig: EnvironmentRig
var stand: Node3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	out = args.get("out", "user://horse_look")
	DirAccess.make_dir_recursive_absolute(out)
	var shots: PackedStringArray = String(args.get("shots", "turn,close,coats,ride")).split(",")
	if "level" in shots:
		await _level()
		quit()
		return
	r = Rig.new()
	await r.build(self, true, false)
	r.horse.coat = args.get("coat", "bay")
	_world()
	cam = Camera3D.new()
	cam.fov = 35.0
	cam.near = 0.03
	r.world.add_child(cam)
	cam.current = true
	env_rig.follow_camera = cam
	_label()
	r.pose("idle", 0.0)
	await _frames(40)
	if "turn" in shots:
		await _turn()
	if "close" in shots:
		await _close()
	if "coats" in shots:
		await _coats()
	if "ride" in shots:
		await _ride()
	quit()


## Shows or hides the rider. A hidden rider must also let go of the reins: otherwise the
## rein strips still run to its (hidden) hands and stick up over the withers.
func _rider(on: bool) -> void:
	r.rider.visible = on
	r.link.drive_reins = on
	if not on:
		r.horse.set_rein_targets([])


func _world() -> void:
	var ws := WorldSettings.new()
	ws.quality = args.get("quality", "high")
	env_rig = EnvironmentRig.new()
	env_rig.name = "EnvironmentRig"
	r.world.add_child(env_rig)
	env_rig.build(ws)
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	plane.mesh = pm
	var gm := ORMMaterial3D.new()
	gm.albedo_texture = load(GROUND + "diffuse_2k.jpg")
	gm.normal_enabled = true
	gm.normal_texture = load(GROUND + "nor_gl_2k.jpg")
	gm.orm_texture = load(GROUND + "arm_2k.jpg")
	gm.uv1_scale = Vector3(20, 20, 1)
	gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	plane.material_override = gm
	r.world.add_child(plane)
	# Actor_B standing beside the horse (left side, level with the shoulder), for scale
	stand = (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	r.world.add_child(stand)
	var sk := stand.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := stand.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	BindRest.ensure(sk, ap)
	CharacterBodyMesh.attach(sk, ap)
	for c: String in STAND_CLIPS:
		if ap.has_animation(c):
			ap.play(c)
			ap.seek(ap.get_animation(c).length - 0.02, true)
			ap.pause()
			break
	stand.global_position = Vector3(-1.05, 0.0, -0.55)
	stand.rotation.y = deg_to_rad(-60.0)


func _label() -> void:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	label = Label.new()
	label.position = Vector2(14, 8)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 5)
	layer.add_child(label)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(path: String, text: String, settle := 14) -> Image:
	label.text = text
	await _frames(settle)
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(path)
	print("saved ", path)
	return img


func _look(from: Vector3, at: Vector3, fov := 35.0) -> void:
	cam.fov = fov
	cam.global_position = from
	cam.look_at(at)


## A point given in the model's rest space, carried by bone `b` in the current pose (world).
func _bone_pt(b: String, rest_pt: Vector3) -> Vector3:
	var sk: Skeleton3D = r.horse.skeleton
	var i := sk.find_bone(b)
	return sk.global_transform * (sk.get_bone_global_pose(i) * (sk.get_bone_global_rest(i).affine_inverse() * rest_pt))


## Horse space (model faces +z, Visual turned 180 deg): the horse walks along -z in the
## world, its left side is +x of the model = -x of the world.
func _hp(p: Vector3) -> Vector3:
	return r.horse.visual.global_transform * p


func _turn() -> void:
	_rider(false)
	stand.visible = true
	var imgs: Array[Image] = []
	var c := Vector3(0, 0.95, 0.05)
	for i in 8:
		var az := deg_to_rad(45.0 * i)
		var d := Vector3(sin(az), 0.0, -cos(az)) * 5.6
		_look(c + d + Vector3(0, 0.35, 0), c, 36.0)
		imgs.append(await _shot("%s/turn_%d.png" % [out, i * 45], "%s  turnaround %d deg (0 = in front)" % [r.horse.coat, i * 45]))
	_grid(imgs, 4, "%s/turn.png" % out)


func _close() -> void:
	_rider(false)
	stand.visible = false
	# head points (model rest space, revision 4 head) carried by the posed head bone
	var views := [
		["head34", _bone_pt("head", Vector3(0.0, 1.43, 1.20)), Vector3(-0.85, 0.25, -0.75), 32.0],
		["head_side", _bone_pt("head", Vector3(0.0, 1.43, 1.20)), Vector3(-1.2, 0.05, 0.0), 32.0],
		["eye", _bone_pt("head", Vector3(0.095, 1.549, 1.233)), Vector3(-0.42, 0.05, -0.12), 30.0],
		["muzzle", _bone_pt("head", Vector3(0.0, 1.30, 1.36)), Vector3(-0.35, 0.05, -0.45), 32.0],
		["forelegs", _hp(Vector3(0.0, 0.45, 0.60)), Vector3(-1.1, 0.05, -1.3), 34.0],
		["hindlegs", _hp(Vector3(0.0, 0.5, -0.5)), Vector3(-1.5, 0.1, 0.6), 34.0],
		["hooves", _hp(Vector3(0.0, 0.12, 0.3)), Vector3(-0.7, 0.18, -0.75), 34.0],
		["mane", _hp(Vector3(0.0, 1.43, 0.80)), Vector3(1.2, 0.35, -0.5), 34.0],
		["tail", _hp(Vector3(0.0, 0.95, -0.75)), Vector3(-0.9, 0.2, 1.6), 34.0],
		["saddle", _hp(Vector3(0.0, 1.30, 0.0)), Vector3(-1.4, 0.45, -0.6), 34.0],
	]
	var imgs: Array[Image] = []
	for v: Array in views:
		var at: Vector3 = v[1]
		_look(at + (v[2] as Vector3), at, v[3])
		imgs.append(await _shot("%s/close_%s.png" % [out, v[0]], "%s  %s" % [r.horse.coat, v[0]]))
	_grid(imgs, 5, "%s/close.png" % out)
	stand.visible = true


func _coats() -> void:
	_rider(false)
	stand.visible = false
	var extra: Array[Horse] = []
	var names: Array = HorseLook.coats()
	for i in names.size():
		var h: Horse
		if i == 0:
			h = r.horse
		else:
			h = Horse.new()
			r.world.add_child(h)
			extra.append(h)
		h.global_position = Vector3(0, 0, -2.4 * i)
		h.rotation.y = deg_to_rad(90.0)
		h.coat = names[i]
	await _frames(4)
	for h in extra:
		h.force_clip("idle", 0.3)
	_look(Vector3(-9.5, 1.6, -6.0), Vector3(0, 0.9, -6.0), 44.0)
	await _shot("%s/coats.png" % out, "coats: " + ", ".join(names), 30)
	var imgs: Array[Image] = []
	var all: Array = [r.horse] + extra
	for i in all.size():
		var h: Horse = all[i]
		var at: Vector3 = h.visual.global_transform * Vector3(0, 1.3, 1.25)
		_look(at + Vector3(-0.9, 0.3, 0.9), at, 34.0)
		imgs.append(await _shot("%s/coat_%s.png" % [out, names[i]], names[i]))
		_look(h.global_position + Vector3(-3.8, 1.2, 0.8), h.global_position + Vector3(0, 0.9, 0), 38.0)
		imgs.append(await _shot("%s/coat_%s_side.png" % [out, names[i]], names[i]))
	_grid(imgs, 4, "%s/coats_detail.png" % out)
	for h in extra:
		h.queue_free()
	r.horse.global_position = Vector3.ZERO
	r.horse.rotation.y = 0.0
	r.horse.coat = args.get("coat", "bay")


func _ride() -> void:
	_rider(true)
	stand.visible = false
	var imgs: Array[Image] = []
	for c: Array in [["idle", 0.0], ["walk", 0.3], ["trot", 0.2], ["canter", 0.4], ["gallop", 0.3], ["jump", 0.45]]:
		r.pose(c[0], c[1])
		var at: Vector3 = r.horse.global_position + Vector3(0, 1.2, 0)
		_look(at + Vector3(-4.6, 0.5, -1.8), at, 38.0)
		imgs.append(await _shot("%s/ride_%s.png" % [out, c[0]], "%s  %s %.2f" % [r.horse.coat, c[0], c[1]]))
	_grid(imgs, 3, "%s/ride.png" % out)


func _level() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(3)
	var player: FrontierPlayer = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _frames(60)
	var horse := Horse.new()
	horse.coat = args.get("coat", "bay")
	current_scene.add_child(horse)
	var p := player.global_position + player.global_basis * Vector3(1.6, 0, -3.2)
	var space: PhysicsDirectSpaceState3D = current_scene.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 20.0, p + Vector3.DOWN * 20.0)
	q.exclude = [horse.get_rid(), player.get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	if hit:
		p = hit.position
	horse.global_position = p
	horse.rotation.y = player.rotation.y + deg_to_rad(70.0)
	_label()
	await _frames(90)
	await _shot("%s/level_play.png" % out, "in the level: gameplay camera", 20)
	cam = Camera3D.new()
	current_scene.add_child(cam)
	cam.current = true
	var env: EnvironmentRig = current_scene.get_node_or_null("EnvironmentRig")
	if env:
		env.follow_camera = cam
	var c := horse.global_position + Vector3(0, 1.0, 0)
	for v: Array in [["side", Vector3(4.2, 0.6, 1.5)], ["front34", Vector3(-2.6, 0.5, -3.6)], ["far", Vector3(9.0, 1.8, 6.0)]]:
		var d: Vector3 = horse.global_basis * (v[1] as Vector3)
		cam.global_position = c + d
		cam.look_at(c)
		await _shot("%s/level_%s.png" % [out, v[0]], "in the level: " + String(v[0]), 30)


func _grid(imgs: Array[Image], cols: int, path: String) -> void:
	if imgs.is_empty():
		return
	var w := imgs[0].get_width() / 2
	var h := imgs[0].get_height() / 2
	var rows := (imgs.size() + cols - 1) / cols
	var g := Image.create(w * cols, h * rows, false, Image.FORMAT_RGBA8)
	for i in imgs.size():
		var im := imgs[i].duplicate() as Image
		im.convert(Image.FORMAT_RGBA8)
		im.resize(w, h, Image.INTERPOLATE_BILINEAR)
		g.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	g.save_png(path)
	print("saved ", path)
