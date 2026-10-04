extends SceneTree
## Films the climbing yard (scenes/climb_yard.tscn) through the player's own camera, the player driven by the game's
## input actions (hold G to grip, W A S D to crawl), with the grip ring and no text HUD (user rule for videos). Frames
## are JPGs in <out>/<segment>/, for an encoder (tools/showcase/video_encode.swift in the showcase clone, or any).
##   Godot --path . --fixed-fps 30 -s tools/climb/climb_film.gd -- out=<dir> [seg=cliff,giant] [size=1280x720]
##       [stills] (only a few frames per segment, as PNG stills)
## The window opens but draws nothing: the view renders off-window (OffscreenView); every input action is unbound
## while it runs, so key presses on the desktop cannot reach the game.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const Assets := preload("res://scripts/world/vegetation/veg_assets.gd")

var p: FrontierPlayer
var yard: ClimbYard
var view
var out := ""
var size := Vector2i(1280, 720)
var segs := PackedStringArray(["cliff", "giant"])
var stills := false
var recording := false
var frame := 0
var dir := ""
var log_lines := PackedStringArray()


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("seg="):
			segs = a.substr(4).split(",")
		elif a.begins_with("size="):
			var wh := a.substr(5).split("x")
			size = Vector2i(int(wh[0]), int(wh[1]))
		elif a == "stills":
			stills = true
	InputSetup.ensure()
	change_scene_to_file("res://scenes/climb_yard.tscn")
	await process_frame
	await process_frame
	var lvl := current_scene
	p = lvl.get_node("Player")
	yard = lvl.get("yard")
	p.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for act in InputMap.get_actions():
		if not String(act).begins_with("ui_"):
			InputMap.action_erase_events(act)
	var rig := lvl.get_node("EnvironmentRig") as EnvironmentRig
	if rig and rig.clock_driver:
		rig.clock_driver.clock.running = false
		rig.clock_driver.clock.set_time(10.5)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = size
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, size)
	view.source = p.camera
	root.disable_3d = true
	p.hud.visible = false
	for n in root.find_children("*", "CanvasLayer", true, false):
		if n.name == "GripHUD":
			(n as CanvasLayer).custom_viewport = view
	var tries := 0
	while (p.traversal == null or not p.traversal.world_ready) and tries < 2000:
		await process_frame
		tries += 1
	await _run(150)
	for s in segs:
		dir = out.path_join(s)
		DirAccess.make_dir_recursive_absolute(dir)
		frame = 0
		print("CLIMB FILM segment ", s)
		await call("_seg_" + s)
		_all_up()
		recording = false
	FileAccess.open(out.path_join("log.txt"), FileAccess.WRITE).store_string("\n".join(log_lines))
	print("CLIMB FILM DONE")
	quit()


## `n` frames of game time (1 / fixed fps each), recording them when on.
func _run(n: int) -> void:
	for i in n:
		await process_frame
		if recording:
			_save()


func _save() -> void:
	frame += 1
	if stills and frame % 45 != 1:
		return
	var img: Image = view.get_texture().get_image()
	if stills:
		img.save_png(dir.path_join("s%04d.png" % frame))
	else:
		img.save_jpg(dir.path_join("f%05d.jpg" % frame), 0.9)


func _note(tag: String) -> void:
	var g := p.grip
	var line := "%s f%d state=%d clip=%s stam=%.0f pos=%s" % [tag, frame, g.state, g._clip, g.stamina,
			str(p.global_position.snappedf(0.01))]
	log_lines.append(line)
	print(line)


func _press(a: String) -> void:
	Input.action_press(a)


func _release(a: String) -> void:
	Input.action_release(a)


func _all_up() -> void:
	for a in ["grip", "move_forward", "move_back", "move_left", "move_right", "jump", "sprint"]:
		Input.action_release(a)


func _place(station: String, pitch := 0.2) -> void:
	var st: Dictionary = yard.stations[station]
	p.global_position = (st.stand as Vector3) + Vector3(0.0, 0.1, 0.0)
	p.velocity = Vector3.ZERO
	var to: Vector3 = (st.look as Vector3) - p.global_position
	p.yaw = atan2(-to.x, -to.z)
	p.rotation.y = p.yaw
	p.pitch = pitch


## The camera eases round to `yaw_off` rad off the body's first facing and to `pitch` over `s` seconds (the mouse's
## work, done by the script).
func _swing_cam(yaw: float, pitch: float, s: float) -> void:
	var y0 := p.yaw
	var p0 := p.pitch
	var n := maxi(int(s * 30.0), 1)
	for i in n:
		var u := smoothstep(0.0, 1.0, float(i + 1) / float(n))
		p.yaw = lerp_angle(y0, yaw, u)
		p.pitch = lerpf(p0, pitch, u)
		await _run(1)


## Runs until `done` is true or `max_s` passes (recording).
func _until(done: Callable, max_s: float) -> void:
	for i in int(max_s * 30.0):
		if done.call():
			return
		await _run(1)


## Holds `a` until `done` is true or `max_s` passes (recording).
func _hold_until(a: String, done: Callable, max_s: float) -> void:
	_press(a)
	var n := int(max_s * 30.0)
	for i in n:
		await _run(1)
		if done.call():
			break
	_release(a)


func _seg_cliff() -> void:
	_place("cliff", 0.02)
	var face := p.yaw
	await _run(20)
	recording = true
	await _run(24)
	_press("grip")
	_note("grab")
	await _swing_cam(face + 0.5, 0.08, 1.3)
	# up a little, a step each way, down a little, then all the way up and over
	await _hold_until("move_forward", func() -> bool: return p.grip.anchor != null and p.grip.anchor.global_position.y > 2.6, 4.0)
	_note("mid")
	await _hold_until("move_right", func() -> bool: return false, 1.4)
	await _run(10)
	await _hold_until("move_left", func() -> bool: return false, 1.4)
	await _run(10)
	await _hold_until("move_back", func() -> bool: return false, 1.0)
	await _run(10)
	_note("up again")
	await _hold_until("move_forward", func() -> bool: return p.grip.state == PlayerGrip.UP, 12.0)
	_note("pull up")
	await _run(30)
	_note("on top")
	_release("grip")
	await _swing_cam(face + 0.9, -0.35, 1.5)
	await _run(20)


func _seg_giant() -> void:
	yard.giant.paces = false
	_place("giant", 0.15)
	var face := p.yaw
	await _run(20)
	recording = true
	await _run(20)
	_press("grip")
	_note("grab flank")
	await _swing_cam(face - 0.55, 0.1, 1.2)
	# up the flank and over its back: on the round body the grip carries on over the top (the back is gentle)
	await _hold_until("move_forward", func() -> bool: return p.grip.state == PlayerGrip.OFF \
			or (p.grip.anchor != null and p.grip.anchor.global_basis.y.y > 0.93), 12.0)
	_note("over the top")
	_release("grip")
	await _run(10)
	await _swing_cam(p.yaw - 0.6, -0.4, 1.2)
	_note("standing on the back")
	# the way to ride it: grip when it shakes, stand while it is calm (the grip refills), grip again when it warns of a
	# big one; then hold on through shake after shake until the grip gives out and it throws you off
	var gi := yard.giant
	await _until(func() -> bool: return gi.shaking, 12.0)
	_press("grip")
	_note("grip: small shake")
	await _until(func() -> bool: return not gi.shaking, 6.0)
	await _run(15)
	_release("grip")
	_note("stand while calm")
	await _until(func() -> bool: return gi.warning, 10.0)
	await _run(8)
	_press("grip")
	_note("warned: grip")
	await _until(func() -> bool: return gi.shaking, 3.0)
	_note("big shake")
	await _until(func() -> bool: return p.grip.state == PlayerGrip.OFF, 45.0)
	_note("thrown off")
	_release("grip")
	await _swing_cam(p.yaw, -0.15, 1.0)
	await _run(45)
	_note("end")


## The nearest sturdy tree to the fort's north gate (as tests/climb/test_tree_climb.gd picks it): [axis, radius, top].
func _tree() -> Array:
	var lay = current_scene.get("vegetation").layout
	var best := INF
	var out := []
	for i in lay.tree_pos.size():
		if lay.tree_collider[i] == 0:
			continue
		var info := Assets.tree(lay.tree_kind[i], lay.tree_variant[i])
		var s: float = lay.tree_scale[i]
		var r := clampf(float(info.get("trunk_radius", 0.3)) * s * 0.92, 0.1, 0.75)
		var h := maxf(float(info.get("collider_height", 6.0)) * s, 3.3)
		var pos: Vector3 = lay.tree_pos[i]
		if r < 0.22 or h < 5.0 or absf(pos.y - FrontierTerrain.height_at(pos.x, pos.z)) > 0.05:
			continue
		# on the forest's edge by the range lane (open ground on the lane side for the camera), near the fort
		var d := absf(FrontierTerrain.flat_distance(pos.x, pos.z) - 4.0) * 4.0 + absf(pos.z + 45.0) * 0.2
		if FrontierTerrain.flat_distance(pos.x, pos.z) < 2.5 or absf(pos.x) < 14.0:
			continue
		if d < best:
			best = d
			out = [pos, r, pos.y + h - 0.3]
	return out


func _seg_tree() -> void:
	var tr := _tree()
	var axis: Vector3 = tr[0]
	var r: float = tr[1]
	# from the lane side
	var to_open := Vector3(signf(axis.x) * 14.0 - axis.x, 0.0, 0.0)
	var at := axis + to_open.normalized() * (r + 0.55)
	print("tree at ", axis.snappedf(0.01), " r ", r, " crown ", tr[2])
	p.global_position = Vector3(at.x, FrontierTerrain.height_at(at.x, at.z) + 0.1, at.z)
	p.velocity = Vector3.ZERO
	var to := axis - p.global_position
	p.yaw = atan2(-to.x, -to.z)
	p.pitch = 0.1
	var face := p.yaw
	await _run(40)
	recording = true
	await _run(20)
	# E climbs a tree, branch to branch (user 2026-10-03; TreeClimb): up its trunk to the first branches
	p.grip.climb_up()
	_note("climb up")
	await _swing_cam(face + 0.45, 0.35, 1.2)
	await _until(func() -> bool: return p.grip.perched, 14.0)
	_note("up on the branch")
	await _run(30)
	# round to the open side, then aim out from the branch and fire
	var out: Vector3 = p.grip._perch_dir
	await _swing_cam(atan2(-out.x, -out.z) + 0.5, -0.1, 1.6)
	await _run(20)
	_press("aim")
	_note("aiming from the branch")
	await _run(50)
	_press("fire")
	await _run(4)
	_release("fire")
	_note("fired")
	await _run(50)
	_release("aim")
	await _run(40)
	_note("resting")
	p.grip.climb_down()
	_note("climb down")
	await _swing_cam(face + 0.45, 0.1, 1.2)
	await _until(func() -> bool: return p.grip.state == PlayerGrip.OFF and not p.grip.perched, 14.0)
	_note("down")
	await _run(45)


## The camera onto a point (the crosshair on it), easing over `s` seconds.
func _look_at_point(pt: Vector3, s: float) -> void:
	var eye := p.global_position + Vector3.UP * p.eye_height
	var d := pt - eye
	var yaw := atan2(-d.x, -d.z)
	var pitch := atan2(d.y, Vector2(d.x, d.z).length())
	await _swing_cam(yaw, pitch, s)


func _seg_hang() -> void:
	# a straw dummy out in the yard, the pistol drawn, up the cliff a little
	var st: Dictionary = yard.stations["cliff"]
	# (the demo horse out of the line of fire)
	for h in current_scene.find_children("*", "Horse", true, false):
		(h as Node3D).global_position += Vector3(-30.0, 0.0, 25.0)
	var dummy := TargetDummy.new()
	var dpos := (st.stand as Vector3) + Vector3(2.5, 0.0, 9.0)
	dummy.position = Vector3(dpos.x, FrontierTerrain.height_at(dpos.x, dpos.z), dpos.z)
	current_scene.add_child(dummy)       # (placed first: a dummy builds its parts where it is added)
	p.switch_weapon("pistol")
	await _run(90)
	_place("cliff", 0.1)
	var face := p.yaw
	await _run(20)
	recording = true
	await _run(15)
	_press("grip")
	_note("grab")
	await _run(40)
	await _swing_cam(face + 0.5, 0.2, 0.8)
	await _hold_until("move_forward", func() -> bool: return false, 1.8)
	await _run(10)
	# round to the dummy, the pistol out one-handed
	var torso := dummy.global_position + Vector3.UP * 1.25
	await _look_at_point(torso, 1.4)
	_press("aim")
	_note("pistol out")
	await _run(40)
	await _look_at_point(torso, 0.3)
	_press("fire")
	await _run(3)
	_release("fire")
	_note("pistol fired")
	await _run(45)
	_release("aim")
	await _run(40)
	# the tomahawk
	p.switch_weapon("tomahawk")
	await _run(10)
	_press("aim")
	_note("tomahawk out")
	await _run(45)
	await _look_at_point(torso + Vector3.UP * 0.15, 0.3)
	_press("fire")
	await _run(12)
	_release("fire")
	_note("thrown")
	await _run(50)
	_release("aim")
	await _run(30)
	# a look at the dummy
	await _look_at_point(torso, 0.6)
	await _run(40)
	_release("grip")
	await _run(40)


## Up a tree a little, a pistol shot and a tomahawk throw past the trunk at a dummy on the lane in front.
func _seg_treeaim() -> void:
	for h in current_scene.find_children("*", "Horse", true, false):
		(h as Node3D).global_position += Vector3(-30.0, 0.0, 25.0)
	var tr := _tree()
	var axis: Vector3 = tr[0]
	var r: float = tr[1]
	var lane := Vector3(signf(axis.x) * 14.0 - axis.x, 0.0, 0.0).normalized()
	var side := lane.cross(Vector3.UP)
	var dummy := TargetDummy.new()
	# out on the open lane, clear of the edge's trees (placed first: a dummy builds its parts where it is added)
	var dp := Vector3(signf(axis.x) * 12.0, 0.0, axis.z) + side * 0.6
	dummy.position = Vector3(dp.x, FrontierTerrain.height_at(dp.x, dp.z), dp.z)
	current_scene.add_child(dummy)
	p.switch_weapon("pistol")
	await _run(90)
	# on the trunk's far side from the lane: the lane is in front, past the trunk
	var at := axis - lane * (r + 0.55)
	p.global_position = Vector3(at.x, FrontierTerrain.height_at(at.x, at.z) + 0.1, at.z)
	p.velocity = Vector3.ZERO
	p.yaw = atan2(-lane.x, -lane.z)
	p.pitch = 0.1
	var face := p.yaw
	await _run(30)
	recording = true
	await _run(15)
	# (E's shinny up the trunk; the aim below holds it there one-handed)
	p.grip.climb_up()
	_note("climb up the trunk")
	await _run(30)
	await _swing_cam(face + 0.35, 0.15, 0.8)
	await _run(66)
	await _run(15)
	var torso := dummy.global_position + Vector3.UP * 1.25
	_press("aim")
	_note("pistol out")
	await _look_at_point(torso, 0.9)
	await _run(25)
	await _look_at_point(torso, 0.25)
	_press("fire")
	await _run(3)
	_release("fire")
	_note("pistol fired")
	await _run(50)
	_release("aim")
	await _run(35)
	p.switch_weapon("tomahawk")
	await _run(10)
	_press("aim")
	_note("tomahawk out")
	await _run(40)
	await _look_at_point(torso + Vector3.UP * 0.2, 0.3)
	_press("fire")
	await _run(12)
	_release("fire")
	_note("thrown")
	await _run(50)
	_release("aim")
	await _run(40)
	_press("grip")
	await _run(3)
	_release("grip")
	await _run(40)


## The felling axe's attacks at a straw dummy (AxeMelee): each direction, the stab, the parry, a high and a low cut,
## seen from the side (a still camera: the player's own turns the body with it).
func _seg_axe() -> void:
	for h in current_scene.find_children("*", "Horse", true, false):
		(h as Node3D).global_position += Vector3(-30.0, 0.0, 25.0)
	var spot: Vector3 = (yard.stations["giant"].stand as Vector3) + Vector3(-3.0, 0.0, 9.0)
	spot.y = FrontierTerrain.height_at(spot.x, spot.z)
	p.global_position = spot + Vector3(0, 0.05, 0)
	p.velocity = Vector3.ZERO
	p.yaw = 0.0
	p.pitch = 0.0
	var dummy := TargetDummy.new()
	dummy.position = spot + Vector3(0.0, 0.0, -0.8)       # (placed first: it builds where it is added)
	current_scene.add_child(dummy)
	p.gather.take_out("felling_axe")
	await _run(80)
	var cine := Camera3D.new()
	current_scene.add_child(cine)
	cine.fov = 45.0
	var look := spot + Vector3(0.0, 1.1, -0.4)
	cine.global_position = spot + Vector3(3.2, 1.5, -1.6)
	cine.look_at(look)
	view.source = cine
	recording = true
	await _run(20)
	var keys := {"D": ["move_right"], "A": ["move_left"], "W": ["move_forward"], "S": ["move_back"],
			"AD": ["move_left", "move_right"]}
	for dir: String in ["D", "A", "W", "S", "AD"]:
		p.global_position = spot + Vector3(0, 0.05, 0)
		p.velocity = Vector3.ZERO
		p.yaw = 0.0
		_note("attack " + dir)
		for a: String in keys[dir]:
			_press(a)
		_press("fire")
		await _run(2)
		for a: String in keys[dir]:
			_release(a)
		_release("fire")
		await _until(func() -> bool: return p.gather.phase == GatherTools.Phase.READY, 3.0)
		await _run(12)
	# high and low: the crosshair decides where it lands
	for pitch: float in [0.45, -0.5]:
		p.pitch = pitch
		p.global_position = spot + Vector3(0, 0.05, 0)
		_note("attack D, pitch %.2f" % pitch)
		_press("fire")
		await _run(2)
		_release("fire")
		await _until(func() -> bool: return p.gather.phase == GatherTools.Phase.READY, 3.0)
		await _run(12)
	p.pitch = 0.0
	view.source = p.camera


## Our own D (animations_extra/Frontier_Own.res, its key poses measured off the reference) swung twice, then the
## reference's clips twice, from the same camera: to compare them.
func _seg_axe_d() -> void:
	for h in current_scene.find_children("*", "Horse", true, false):
		(h as Node3D).global_position += Vector3(-30.0, 0.0, 25.0)
	var spot: Vector3 = (yard.stations["giant"].stand as Vector3) + Vector3(-3.0, 0.0, 9.0)
	spot.y = FrontierTerrain.height_at(spot.x, spot.z)
	p.global_position = spot + Vector3(0, 0.05, 0)
	p.velocity = Vector3.ZERO
	p.yaw = 0.0
	p.pitch = 0.0
	var dummy := TargetDummy.new()
	dummy.position = spot + Vector3(0.0, 0.0, -0.8)
	current_scene.add_child(dummy)
	dummy.max_health = 1.0e6              # (standing through every swing)
	dummy.health = 1.0e6
	p.gather.take_out("felling_axe")
	await _run(80)
	var cine := Camera3D.new()
	current_scene.add_child(cine)
	cine.fov = 45.0
	var look := spot + Vector3(0.0, 1.1, -0.4)
	view.source = cine
	recording = true
	var sp: Dictionary = p.gather.melee.data.swings.D
	var own := [String(sp.intro), String(sp.hit)]
	for pass_i in 2:
		cine.global_position = spot + (Vector3(3.2, 1.5, -1.6) if pass_i == 0 else Vector3(-3.2, 1.5, -1.6))
		cine.look_at(look)
		for which: Array in [own, ["atk-pipe-1-side-swing-intro", "atk-pipe-1-side-swing-miss"]]:
			sp.intro = which[0]
			sp.hit = which[1]
			for k in 2:
				p.global_position = spot + Vector3(0, 0.05, 0)
				p.velocity = Vector3.ZERO
				p.yaw = 0.0
				_note("D " + String(which[1]))
				_press("move_right")
				_press("fire")
				await _run(2)
				_release("move_right")
				_release("fire")
				await _until(func() -> bool: return p.gather.phase == GatherTools.Phase.READY, 3.0)
				await _run(10)
			await _run(20)
	sp.intro = own[0]
	sp.hit = own[1]
	view.source = p.camera


## The axe meeting things (user 2026-09-27: "a collision thing where it doesnt go thru the target", "if two weapons
## collide they both bounce back", "i still want the crunch maybe go all the way to the spine"): D into a straw
## dummy where its edge passes (it cuts in to the post, the crunch, and pulls out), into a wooden post (it bounces
## off), then against a sparring partner's D 2.1 m away (the axes meet, both bounce back); each at speed, then slowed.
func _seg_contact() -> void:
	for h in current_scene.find_children("*", "Horse", true, false):
		(h as Node3D).global_position += Vector3(-30.0, 0.0, 25.0)
	var spot: Vector3 = (yard.stations["giant"].stand as Vector3) + Vector3(-3.0, 0.0, 9.0)
	spot.y = FrontierTerrain.height_at(spot.x, spot.z)
	p.global_position = spot + Vector3(0, 0.05, 0)
	p.velocity = Vector3.ZERO
	p.yaw = 0.0
	p.pitch = 0.0
	p.gather.take_out("felling_axe")
	await _run(80)
	var cine := Camera3D.new()
	current_scene.add_child(cine)
	cine.fov = 42.0
	view.source = cine
	# the dummy
	var dummy := TargetDummy.new()
	dummy.position = spot + Vector3(0.0, 0.0, -1.05)
	current_scene.add_child(dummy)
	dummy.max_health = 1.0e6
	dummy.health = 1.0e6
	cine.global_position = spot + Vector3(2.7, 1.6, -1.9)
	cine.look_at(spot + Vector3(0.0, 1.3, -0.7))
	await _run(10)
	recording = true
	for slow in [1.0, 1.0, 0.3]:
		await _contact_swing(spot, slow)
	dummy.queue_free()
	# a wooden post
	var post := StaticBody3D.new()
	post.set_meta(&"surface", "wood")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 1.8, 0.2)
	cs.shape = box
	post.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box.size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.28, 0.17)
	mi.material_override = mat
	post.add_child(mi)
	current_scene.add_child(post)
	post.global_position = spot + Vector3(0.0, 0.9, -1.05)
	for slow in [1.0, 0.3]:
		await _contact_swing(spot, slow)
	post.queue_free()
	# the sparring partner: both swing at once
	var sp := SparringPartner.new()
	current_scene.add_child(sp)
	sp.global_position = spot + Vector3(0.0, 0.0, -2.1)
	for view_i in 2:
		if view_i == 0:
			cine.global_position = spot + Vector3(3.6, 1.6, -1.05)
			cine.look_at(spot + Vector3(0.0, 1.3, -1.05))
		else:
			cine.global_position = spot + Vector3(-3.0, 2.0, -0.4)
			cine.look_at(spot + Vector3(0.0, 1.3, -1.05))
		for slow in [1.0, 0.3]:
			await _contact_swing(spot, slow, sp)
	sp.queue_free()
	view.source = p.camera


func _contact_swing(spot: Vector3, slow: float, partner: SparringPartner = null) -> void:
	p.global_position = spot + Vector3(0, 0.05, 0)
	p.velocity = Vector3.ZERO
	p.yaw = 0.0
	await _run(8)
	Engine.time_scale = slow
	_press("move_right")
	_press("fire")
	if partner:
		partner.swing()
	await _run(2)
	_release("move_right")
	_release("fire")
	await _until(func() -> bool: return p.gather.phase == GatherTools.Phase.READY and (partner == null or partner.state == ""), 8.0)
	Engine.time_scale = 1.0
	await _run(14)


## The musket as a club (user 2026-09-27: "make it where we can turn muskets into clubs"): middle mouse turns it end
## for end, D, W and S into a straw dummy where the butt passes (at speed, then W slowed), middle mouse turns it back
## and it is aimed again.
func _seg_club() -> void:
	for h in current_scene.find_children("*", "Horse", true, false):
		(h as Node3D).global_position += Vector3(-30.0, 0.0, 25.0)
	var spot: Vector3 = (yard.stations["giant"].stand as Vector3) + Vector3(-3.0, 0.0, 9.0)
	spot.y = FrontierTerrain.height_at(spot.x, spot.z)
	p.global_position = spot + Vector3(0, 0.05, 0)
	p.velocity = Vector3.ZERO
	p.yaw = 0.0
	p.pitch = 0.0
	if p.weapon_key != "musket":
		p.switch_weapon("musket")
	await _run(90)
	var dummy := TargetDummy.new()
	dummy.position = spot + Vector3(0.0, 0.0, -1.6)
	current_scene.add_child(dummy)
	dummy.max_health = 1.0e6
	dummy.health = 1.0e6
	var cine := Camera3D.new()
	current_scene.add_child(cine)
	cine.fov = 45.0
	cine.global_position = spot + Vector3(3.4, 1.7, -1.4)
	cine.look_at(spot + Vector3(0.0, 1.3, -0.8))
	view.source = cine
	await _run(10)
	recording = true
	await _run(20)
	_press("club_grip")
	await _run(2)
	_release("club_grip")
	await _run(30)
	for pair: Array in [["move_right", 1.0], ["move_forward", 1.0], ["move_back", 1.0], ["move_forward", 0.3]]:
		p.global_position = spot + Vector3(0, 0.05, 0)
		p.velocity = Vector3.ZERO
		p.yaw = 0.0
		Engine.time_scale = float(pair[1])
		_press(String(pair[0]))
		_press("fire")
		await _run(2)
		_release(String(pair[0]))
		_release("fire")
		await _until(func() -> bool: return p.gather.phase == GatherTools.Phase.READY and p.gather._swing.is_empty(), 8.0)
		Engine.time_scale = 1.0
		await _run(12)
	_press("club_grip")
	await _run(2)
	_release("club_grip")
	await _run(30)
	_press("aim")
	await _run(40)
	_release("aim")
	await _run(20)
	dummy.queue_free()
	view.source = p.camera


## The stab (W/S + A/D; user 2026-09-27: "build the stab"): the felling axe thrust into a straw dummy at speed and
## slowed, then the musket clubbed thrusting its butt.
func _seg_stab() -> void:
	for h in current_scene.find_children("*", "Horse", true, false):
		(h as Node3D).global_position += Vector3(-30.0, 0.0, 25.0)
	var spot: Vector3 = (yard.stations["giant"].stand as Vector3) + Vector3(-3.0, 0.0, 9.0)
	spot.y = FrontierTerrain.height_at(spot.x, spot.z)
	p.global_position = spot + Vector3(0, 0.05, 0)
	p.velocity = Vector3.ZERO
	p.yaw = 0.0
	p.pitch = 0.0
	p.gather.take_out("felling_axe")
	await _run(80)
	var dummy := TargetDummy.new()
	dummy.position = spot + Vector3(0.0, 0.0, -1.05)
	current_scene.add_child(dummy)
	dummy.max_health = 1.0e6
	dummy.health = 1.0e6
	var cine := Camera3D.new()
	current_scene.add_child(cine)
	cine.fov = 42.0
	cine.global_position = spot + Vector3(3.0, 1.5, -0.7)
	cine.look_at(spot + Vector3(0.0, 1.2, -0.6))
	view.source = cine
	await _run(10)
	recording = true
	await _run(15)
	for slow in [1.0, 0.3]:
		await _stab_once(spot, slow)
	# the musket, clubbed
	p.gather.put_away()
	await _until(func() -> bool: return p.gather.tool == "", 4.0)
	p.switch_weapon("musket")
	await _until(func() -> bool: return p.weapon_key == "musket" and p.weapon.active and not p.is_switching(), 5.0)
	await _run(10)
	dummy.global_position = spot + Vector3(0.0, 0.0, -1.5)
	_press("club_grip")
	await _run(2)
	_release("club_grip")
	await _run(30)
	for slow in [1.0, 0.3]:
		await _stab_once(spot, slow)
	dummy.queue_free()
	view.source = p.camera


func _stab_once(spot: Vector3, slow: float) -> void:
	p.global_position = spot + Vector3(0, 0.05, 0)
	p.velocity = Vector3.ZERO
	p.yaw = 0.0
	await _run(6)
	Engine.time_scale = slow
	_press("move_forward")
	_press("move_right")
	_press("fire")
	await _run(2)
	_release("move_forward")
	_release("move_right")
	_release("fire")
	await _until(func() -> bool: return p.gather.phase == GatherTools.Phase.READY and p.gather._swing.is_empty(), 8.0)
	Engine.time_scale = 1.0
	await _run(12)


## A melee fight (user 2026-09-27: "show a melee fight in action please"): the player (the felling axe) and the
## sparring partner, a move at a time, face to face in reach (the partner stepping in first). Only counters block
## ("ad should only parry thrusts and [the] users should only block by counters and thats it") and the first blow to
## land wins the exchange ("if the other user hits the user [first] then a hit animation happens and it restarts the
## persons hit swing"; "its more about timing and who can win the exchange"): both D at once, then both A (facing each
## other the side cuts are mirrored: the same cut meets it head on, stopped short, both bounce back); the partner's W
## against the player's high block (S: the haft held up across); the partner's stab against the player's parry (A+D);
## the partner's D a
## moment ahead of the player's A (not its counter: it lands, the player flinches, their A lost); the player's D a
## moment ahead of the partner's W (the partner flinches); the player's stab under the partner's wind-up, in to the
## spine. Slowed from each move's start till both are done.
func _seg_fight() -> void:
	for h in current_scene.find_children("*", "Horse", true, false):
		(h as Node3D).global_position += Vector3(-30.0, 0.0, 25.0)
	var spot: Vector3 = (yard.stations["giant"].stand as Vector3) + Vector3(-3.0, 0.0, 9.0)
	spot.y = FrontierTerrain.height_at(spot.x, spot.z)
	p.global_position = spot + Vector3(0, 0.05, 0)
	p.velocity = Vector3.ZERO
	p.yaw = 0.0
	p.pitch = 0.0
	p.gather.take_out("felling_axe")
	await _until(func() -> bool: return p.gather.phase == GatherTools.Phase.READY, 6.0)
	var sp := SparringPartner.new()
	current_scene.add_child(sp)
	var far := spot + Vector3(0.0, 0.0, -2.4)
	var near := spot + Vector3(0.0, 0.0, -1.1)
	sp.global_position = Vector3(far.x, FrontierTerrain.height_at(far.x, far.z), far.z)
	var cine := Camera3D.new()
	current_scene.add_child(cine)
	cine.fov = 44.0
	cine.global_position = spot + Vector3(3.0, 1.6, -0.55)
	cine.look_at(spot + Vector3(0.0, 1.15, -0.55))
	view.source = cine
	await _run(20)
	recording = true
	await _run(20)
	fight_log = []
	await _step_partner(sp, near)
	await _run(10)
	# both D at once, then both A (mirrored, face to face: the edges meet head on): stopped short, both bounce back
	await _fight_beat(spot, ["move_right"], "D", 0.0, 0.45)
	await _fight_beat(spot, ["move_left"], "A", 0.0, 0.45)
	# the partner's W (the overhand chop), the player's high block (S) against it
	await _fight_beat(spot, ["move_back"], "W", -0.11, 0.45)
	# the partner's D a moment ahead of the player's A: it lands first, the player flinches, their A lost
	await _fight_beat(spot, ["move_left"], "D", -0.1, 0.45)
	# the player's D a moment ahead of the partner's W (slower to land): the partner flinches, its W lost
	await _fight_beat(spot, ["move_right"], "W", 0.1, 0.45)
	# the player's stab under the partner's wind-up, in to the spine
	await _fight_beat(spot, ["move_forward", "move_right"], "D", 0.17, 0.45)
	await _step_partner(sp, far)
	await _run(30)
	sp.queue_free()
	view.source = p.camera
	for line: String in fight_log:
		print("FIGHT ", line)


var fight_log: Array = []


## One move: the player's attack (the keys held with LMB; none: the player holds) and the partner's (`other`, "" none),
## the partner `lead_s` s of game time after the player (before, negative); slowed to `slow` from the start till both
## are done (the player's health topped up first).
func _fight_beat(spot: Vector3, keys: Array, other: String, lead_s: float, slow: float) -> void:
	var sp: SparringPartner = null
	for n in current_scene.get_children():
		if n is SparringPartner:
			sp = n
	p.global_position = spot + Vector3(0, 0.05, 0)
	p.velocity = Vector3.ZERO
	p.yaw = 0.0
	p.pitch = 0.0
	p.health = p.max_health
	p.grip.stamina = p.grip.stamina_max
	await _run(6)
	var hp_before: float = sp.damage_taken if sp else 0.0
	var struck_before: int = sp.struck if sp else 0
	p.gather.melee.last_contact = {}
	if sp:
		sp.last_contact = {}
	var got := {"hits": 0, "cut": ""}
	var on_hurt := func(_l: Vector2, _a: float, _h: bool) -> void: got.hits = int(got.hits) + 1
	var on_cut := func(d: String) -> void: got.cut = d
	p.hurt.connect(on_hurt)
	p.gather.melee.interrupted.connect(on_cut)
	Engine.time_scale = slow
	var wait := int(round(absf(lead_s) * 30.0 / slow))
	var t_me := 0 if lead_s >= 0.0 else wait
	var t_sp := wait if lead_s >= 0.0 else 0
	for f in maxi(t_me, t_sp) + 3:
		if f == t_me and not keys.is_empty():
			for k: String in keys:
				_press(k)
			_press("fire")
		if f == t_me + 2:
			for k: String in keys:
				_release(k)
			_release("fire")
		if f == t_sp and other != "" and sp:
			sp.swing(other)
		await _run(1)
	await _until(_fight_still.bind(sp), 10.0)
	Engine.time_scale = 1.0
	p.hurt.disconnect(on_hurt)
	p.gather.melee.interrupted.disconnect(on_cut)
	fight_log.append("player %s: %s%s%s | partner %s: %s%s | partner took %.0f" % [str(keys), _met(p.gather.melee.last_contact),
			", struck %d" % int(got.hits) if int(got.hits) > 0 else "", ", broken off (%s)" % got.cut if got.cut != "" else "",
			other, _met(sp.last_contact if sp else {}), ", flinched" if sp and sp.struck > struck_before else "",
			(sp.damage_taken if sp else 0.0) - hp_before])
	await _run(14)


static func _met(c: Dictionary) -> String:
	if c.is_empty():
		return "met nothing"
	var out := "met " + String(c.get("surface", "-"))
	if c.get("core", false):
		out += " (core)"
	if c.has("glance"):
		out += " glancing %.2f" % float(c.glance)
	if c.has("blocked"):
		out += " BLOCKED"
	return out


## Both done with their moves (both back on guard, the player's flinch over).
func _fight_still(sp: SparringPartner) -> bool:
	return p.gather.phase == GatherTools.Phase.READY and p.gather._swing.is_empty() and not p.gather.melee.flinching() \
			and (sp == null or sp.state == "")


## Player against player (user 2026-09-27: "can you use ai to check these", "show me too man i want to see"): this
## machine's player and a second FrontierPlayer on the map (is_local false), both with the felling axe, both played by
## MeleeDuelAI (reading the other's attacks and countering, attacking when left alone, feinting now and then, keeping
## in reach), the same melee as a person at the keys; a free duel for DUEL_S of game time, a little slowed, the
## camera beside them.
const DUEL_S := 24.0
const DUEL_SLOW := 0.7


func _seg_duel() -> void:
	for h in current_scene.find_children("*", "Horse", true, false):
		(h as Node3D).global_position += Vector3(-30.0, 0.0, 25.0)
	var spot: Vector3 = (yard.stations["giant"].stand as Vector3) + Vector3(-3.0, 0.0, 9.0)
	spot.y = FrontierTerrain.height_at(spot.x, spot.z)
	p.global_position = spot + Vector3(0, 0.05, 0)
	p.velocity = Vector3.ZERO
	p.yaw = 0.0
	p.pitch = 0.0
	var q := FrontierPlayer.new()
	q.name = "Player2"
	q.is_local = false
	q.controls = PlayerControls.new(false)
	q.demo_horse = false
	q.demo_wheelbarrow = false
	current_scene.add_child(q)
	var at := spot + Vector3(0.0, 0.0, -1.1)
	q.global_position = Vector3(at.x, FrontierTerrain.height_at(at.x, at.z) + 0.05, at.z)
	q.yaw = PI
	await _run(30)
	p.gather.take_out("felling_axe")
	q.gather.take_out("felling_axe")
	await _until(func() -> bool: return p.gather.phase == GatherTools.Phase.READY and q.gather.phase == GatherTools.Phase.READY, 8.0)
	for who: FrontierPlayer in [p, q]:
		who.max_health = 1.0e6
		who.health = 1.0e6
		who.grip.stamina = who.grip.stamina_max
	_expect_second(q)
	var cine := Camera3D.new()
	current_scene.add_child(cine)
	cine.fov = 46.0
	view.source = cine
	p.controls = PlayerControls.new(false)
	var ai_p := MeleeDuelAI.attach(p, q, 11)
	var ai_q := MeleeDuelAI.attach(q, p, 23)
	var hits := {"p": 0, "q": 0}
	p.hurt.connect(func(_l: Vector2, _a: float, _h: bool) -> void: hits.p += 1)
	q.hurt.connect(func(_l: Vector2, _a: float, _h: bool) -> void: hits.q += 1)
	var side := Vector3.RIGHT
	# (the stamina ring is drawn by the player's crosshair: not in a view from beside them)
	var rings := root.find_children("GripHUD", "CanvasLayer", true, false)
	for r in rings:
		(r as CanvasLayer).visible = false
	Engine.time_scale = DUEL_SLOW
	recording = true
	for f in int(DUEL_S * 30.0 / DUEL_SLOW):
		# (beside the pair, square on to the line between them, eased)
		var a := p.global_position
		var b := q.global_position
		var mid := (a + b) * 0.5
		var line := (b - a)
		line.y = 0.0
		if line.length() > 0.2:
			var s2 := line.normalized().cross(Vector3.UP)
			side = side.lerp(s2 if s2.dot(side) >= 0.0 else -s2, 0.05).normalized()
		var eye := mid + side * 3.2 + Vector3(0.0, 1.55, 0.0)
		cine.global_position = eye if f == 0 else cine.global_position.lerp(eye, 0.08)
		cine.look_at(mid + Vector3(0.0, 1.1, 0.0))
		await _run(1)
	Engine.time_scale = 1.0
	ai_p.enabled = false
	ai_q.enabled = false
	p.controls = PlayerControls.new()
	q.controls.release_all()
	await _run(30)
	for r in rings:
		(r as CanvasLayer).visible = true
	view.source = p.camera
	print("DUEL attacks %d / %d, feints %d / %d, countered %d / %d of %d / %d, blows landed on the player %d, on the other %d" % [
			ai_p.attacks, ai_q.attacks, ai_p.feints, ai_q.feints, ai_p.countered, ai_q.countered, ai_p.seen, ai_q.seen,
			hits.p, hits.q])
	q.queue_free()


## The second player on the map has nothing of this machine's screen (logged if it does).
func _expect_second(q: FrontierPlayer) -> void:
	var own := q.find_children("GripHUD", "CanvasLayer", true, false).size() + (1 if q.hud else 0)
	if own > 0:
		print("DUEL the second player has HUD of its own: ", own)


func _step_partner(sp: SparringPartner, to: Vector3) -> void:
	var from := sp.global_position
	var dest := Vector3(to.x, FrontierTerrain.height_at(to.x, to.z), to.z)
	for i in 12:
		sp.global_position = from.lerp(dest, smoothstep(0.0, 1.0, float(i + 1) / 12.0))
		await _run(1)
