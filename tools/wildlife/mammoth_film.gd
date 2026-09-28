extends SceneTree
## A short film of the climbing yard's woolly mammoth at its pacing and meals (user 2026-09-27: "lets do the mammoth add
## turns into blender for them", "eating and drinking clips as well", "dont forget to show me as well"), in segments:
##   turn     it walks to the end of its beat and turns round on the spot (Turn_L twice, its feet stepping round)
##   forage   forage off to its side: it turns to it, walks up and eats it (Eat), the player's blackberries gone
##   drink    a stand-in pool where its trunk reaches (the level has no water yet): Drink, two squirts a draw
##   browse   a tree before it: Browse, the trunk up in the leaves, a spray torn off at each tug
##   grass    nothing else near: Eat, grass
## Frames are JPGs in <out>/ (numbered on across the segments), for an encoder (tools/showcase/video_encode.swift in the
## showcase clone, or any):
##   Godot --path . --fixed-fps 30 -s tools/wildlife/mammoth_film.gd -- out=<dir> [seg=turn,forage]
## The window opens but draws nothing (OffscreenView renders off-window).

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const FPS := 30.0

var out := "user://mammoth_film"
var segs: Array[String] = ["turn", "forage", "drink", "browse", "grass"]
var view
var yard: ClimbYard
var gi: StandInGiant
var p: FrontierPlayer
var spawn0: Transform3D
var frame := 0
## The camera each frame: from, at (world).
var cam_from := Vector3.ZERO
var cam_at := Vector3.FORWARD
## Leaves and limbs right before the lens fade out (the game's own fade from a tree perch: veg_clear_*,
## shaders/vegetation/near_fade.gdshaderinc) within CLEAR_R of the line from the camera `clear_to` of the way to cam_at.
const CLEAR_R := 2.5
var clear_to := 0.55


class FakeWater extends Node:
	var at := Vector3.ZERO
	func _ready() -> void:
		add_to_group(TorchState.WATER_GROUP)
	func is_under_water(pos: Vector3) -> bool:
		return Vector2(pos.x - at.x, pos.z - at.z).length() < 2.5 and pos.y < at.y + 0.5


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("seg="):
			segs.assign(a.substr(4).split(","))
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure()
	change_scene_to_file("res://scenes/climb_yard.tscn")
	await process_frame
	await process_frame
	var lvl := current_scene
	p = lvl.get_node("Player")
	yard = lvl.get("yard")
	gi = yard.giant
	spawn0 = gi.spawn
	p.ignore_mouse_capture = true
	p.hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for act in InputMap.get_actions():
		if not String(act).begins_with("ui_"):
			InputMap.action_erase_events(act)
	var rig := lvl.get_node("EnvironmentRig") as EnvironmentRig
	if rig and rig.clock_driver:
		rig.clock_driver.clock.running = false
		rig.clock_driver.clock.set_time(12.5)     # (the sun high: light under the trees)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = Vector2i(1280, 720)
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(1280, 720))
	view.camera.fov = 50.0
	root.disable_3d = true
	# the player out of the way (its temper is off in a -s run anyway)
	p.global_position = gi.where() + Vector3(0.0, 0.5, 90.0)
	await _run(90, false)
	for s in segs:
		print("MAMMOTH FILM segment %s at %.1f s" % [s, frame / FPS])
		await call("_seg_" + s)
	print("MAMMOTH FILM DONE (%d frames)" % frame)
	quit()


## `n` frames (1 / FPS of game time each), the camera where cam_from / cam_at say, saved when `rec`.
func _run(n: int, rec := true) -> void:
	for i in n:
		view.camera.global_transform = Transform3D(Basis.looking_at(cam_at - cam_from, Vector3.UP), cam_from)
		var far := cam_from.lerp(cam_at, clear_to)
		RenderingServer.global_shader_parameter_set(&"veg_clear_a", Vector4(cam_from.x, cam_from.y, cam_from.z, CLEAR_R))
		RenderingServer.global_shader_parameter_set(&"veg_clear_b", Vector4(far.x, far.y, far.z, 1.0))
		await process_frame
		if rec:
			frame += 1
			(view.get_texture().get_image() as Image).save_jpg(out.path_join("f%05d.jpg" % frame), 0.9)


func _secs(s: float) -> int:
	return int(s * FPS)


## The mammoth set down at `at` facing `dir`, its beat anew from there.
func _place(at: Vector3, dir: Vector3) -> void:
	gi.paces = false
	await _run(2, false)
	at.y = FrontierTerrain.height_at(at.x, at.z)
	gi._home = Transform3D(Basis.looking_at(Vector3(dir.x, 0.0, dir.z).normalized(), Vector3.UP), at)
	gi._pace_c = Vector3.INF
	gi.pace_state = "walk"
	gi._meal = ""
	gi._seek_t = -1e9
	gi.graze_chance = 0.0
	await _run(20, false)


func _ground(v: Vector3, up: float) -> Vector3:
	return Vector3(v.x, FrontierTerrain.height_at(v.x, v.z) + up, v.z)


## Trees (VegHarvest) within `r` of the line a..b; with `any`, every plant and rock too.
func _trees(a: Vector3, b: Vector3, r: float, any := false) -> int:
	var vh := VegHarvest.find(self)
	if vh == null:
		return 0
	var seen := {}
	for i in 13:
		for c: Dictionary in vh.near(a.lerp(b, i / 12.0), r):
			if any or String(c.get("type", "")) == "tree":
				if Vector2((c.pos as Vector3).x - a.lerp(b, i / 12.0).x, (c.pos as Vector3).z - a.lerp(b, i / 12.0).z).length() <= r:
					seen[c.pos] = true
	return seen.size()


## A camera `dist` from `at`, `up` m over the ground, off along whichever of `dirs` (flat; none: all round, every 30
## degrees) has the least in the way: trees within 3 m of the line (their crowns), anything else within 1.3 m; bar the
## last 3 m by `at` (the tree it browses).
func _view(at: Vector3, dirs: Array, dist: float, up: float) -> Vector3:
	if dirs.is_empty():
		for i in 12:
			dirs.append(Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 12.0))
	var best := Vector3.ZERO
	var fewest := 1 << 30
	for d: Vector3 in dirs:
		var from := at + d.normalized() * dist
		var n := _trees(from, at + d.normalized() * 3.0, 3.0) * 3 + _trees(from, at + d.normalized() * 3.0, 1.3, true)
		if n < fewest:
			fewest = n
			best = from
	return _ground(best, up)


func _seg_turn() -> void:
	await _place(spawn0.origin, -spawn0.basis.z)
	var h := gi.heading()
	var side := h.cross(Vector3.UP)
	# 1.3 m short of its beat's end: it walks there, turns round, and walks back
	gi._pace_c = gi._home.origin - h * (StandInGiant.PACE_M - 1.3)
	gi._pace_dir = h
	var spot := gi._home.origin + h * 1.3
	cam_from = _ground(spot - side * 10.5 + h * 5.0, 5.5)
	cam_at = _ground(spot, 1.6)
	gi.paces = true
	await _run(_secs(15.0))
	gi.paces = false


func _seg_forage() -> void:
	var ff := ForageField.find(self)
	if ff == null:
		return
	# the blackberry bush (big enough to see) nearest the yard (the yard's light); the way in and the camera's side the
	# clearest
	var at := Vector3.INF
	var best := INF
	for sp: Dictionary in ff.deer_spots(spawn0.origin, 140.0, 40):
		if String(sp.kind) != "blackberry":
			continue
		var score := (sp.pos as Vector3).distance_to(spawn0.origin)
		if score < best:
			best = score
			at = sp.pos
	if at == Vector3.INF:
		return
	var way := Vector3.RIGHT
	for d: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		if _trees(at, at + d * 8.0, 2.5) < _trees(at, at + way * 8.0, 2.5):
			way = d
	var from := at + way * 8.0
	var mid := (at + from) * 0.5
	var side := way.cross(Vector3.UP)
	gi.spawn = Transform3D(Basis(), from)
	await _place(from, way.cross(Vector3.UP))    # (the food off to its side: a quarter turn to it)
	cam_from = _view(mid, [], 13.0, 4.5)
	cam_at = _ground(mid, 1.4)
	gi.paces = true
	gi._seek_t = StandInGiant.SEEK_EVERY
	var t := 0.0
	var grazed := false
	while t < 40.0:
		await _run(1)
		t += 1.0 / FPS
		if gi.pace_state == "graze" and not grazed:
			grazed = true
			# closer: the trunk at the bush
			cam_from = _view(at + way * 2.2, [], 8.0, 2.6)
			cam_at = _ground(at + way * 2.2, 1.4)
		elif grazed and gi.pace_state != "graze":
			break
	await _run(_secs(0.5))
	print("  forage: %.2f eaten at %s" % [gi.eaten, str(at.snappedf(0.1))])
	gi.paces = false
	gi.spawn = spawn0


func _seg_drink() -> void:
	var spot := spawn0.origin + Vector3(12.0, 0.0, 30.0)      # (off the range lane: its signs out of the picture)
	await _place(spot, Vector3.FORWARD)
	var w := FakeWater.new()
	w.at = gi.body.global_transform * StandInGiant.DRINK_REACH
	w.at.y = FrontierTerrain.height_at(w.at.x, w.at.z)
	current_scene.add_child(w)
	# the pool to see (a flat disc: the level has no water yet)
	var pool := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 2.4
	cm.bottom_radius = 2.4
	cm.height = 0.6
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.27, 0.32)
	m.metallic = 0.2
	m.roughness = 0.08
	cm.material = m
	pool.mesh = cm
	current_scene.add_child(pool)
	# its face 15 cm over the highest ground under it (over the grass; on a slope its side shows, a bank)
	var top := w.at.y
	for i in 16:
		var q := w.at + Vector3(2.4, 0.0, 0.0).rotated(Vector3.UP, TAU * i / 16.0)
		top = maxf(top, FrontierTerrain.height_at(q.x, q.z))
	pool.global_position = Vector3(w.at.x, top + 0.15 - 0.3, w.at.z)
	var h := gi.heading()
	var side := h.cross(Vector3.UP)
	# (from its left: the range lane, off to its right, behind the camera)
	cam_from = _view(gi.where() + h * 3.4, [-side, -side + h * 0.5, -side - h * 0.4], 8.5, 4.2)
	cam_at = _ground(gi.where() + h * 3.4, 2.0)
	gi.paces = true
	await _run(_secs(0.8))
	gi._begin_meal(true)
	while gi.pace_state == "graze":
		await _run(1)
	await _run(_secs(0.6))
	print("  drink: %s, %d squirts" % [gi._meal, gi.squirts])
	gi.paces = false
	w.queue_free()
	pool.queue_free()


func _seg_browse() -> void:
	var vh := VegHarvest.find(self)
	var ff := ForageField.find(self)
	var tp := Vector3.INF
	var dir := Vector3(1.0, 0.0, 0.3).normalized()
	# a broadleaf tree (oak, maple, birch: VegAssets.SPECIES 2..4; a pine's low boughs hide the trunk in them) at the
	# woods' edge (the fewest others round it: in the light), its ground flat
	var trees := []
	for c: Dictionary in (vh.near(spawn0.origin, 90.0) if vh else []):
		if String(c.get("type", "")) != "tree" or not (int(c.get("kind", -1)) in [2, 3, 4]):
			continue
		var cp: Vector3 = c.pos
		var at := cp - dir * 5.5
		if absf(FrontierTerrain.height_at(at.x, at.z) - FrontierTerrain.height_at(cp.x, cp.z)) > 1.0:
			continue
		trees.append([_trees(cp, cp, 7.0), cp])
	trees.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	for e: Array in trees:
		var cp: Vector3 = e[1]
		var at := cp - dir * 5.5
		await _place(at, dir)
		if ff and not ff.deer_spots(gi.body.global_transform * StandInGiant.EAT_REACH, 3.0, 1).is_empty():
			continue
		tp = cp
		break
	if tp == Vector3.INF:
		return
	var side := dir.cross(Vector3.UP)
	cam_from = _view(tp - dir * 2.0, [side, -side, side - dir * 0.5, -side - dir * 0.5, side - dir, -side - dir], 10.0, 3.6)
	cam_at = _ground(tp - dir * 2.0, 3.4)
	gi.paces = true
	await _run(_secs(0.8))
	gi._begin_meal(true)
	while gi.pace_state == "graze":
		await _run(1)
	await _run(_secs(0.6))
	print("  browse: %s, %d sprays, tree at %s" % [gi._meal, gi.leaf_sheds, str(tp.snappedf(0.1))])
	gi.paces = false


func _seg_grass() -> void:
	var spot := spawn0.origin + Vector3(0.0, 0.0, 12.0)
	await _place(spot, Vector3.BACK)
	var h := gi.heading()
	var side := h.cross(Vector3.UP)
	cam_from = _ground(gi.where() + h * 9.0 + side * 5.0, 2.0)
	cam_at = _ground(gi.where() + h * 3.0, 1.6)
	gi.paces = true
	await _run(_secs(0.8))
	gi._begin_meal(true)
	while gi.pace_state == "graze":
		await _run(1)
	await _run(_secs(0.8))
	print("  grass: %s" % gi._meal)
	gi.paces = false
