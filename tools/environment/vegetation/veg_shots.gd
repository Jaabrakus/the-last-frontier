extends SceneTree
## Package C look-dev captures (needs a window; wrap it in a time limit). Renders through the
## off-window view (tools/environment/offscreen_view.gd), so it works while the window is covered,
## and unbinds all game input like the other environment tools.
##
##   Godot --path . --resolution 1280x720 -s tools/environment/vegetation/veg_shots.gd -- \
##       out=<dir> [set=scenic|lod|close|all] [only=name,...] [script=res://...vegetation.gd]
##       [settle=60] [quality=..]
##
## Sets:
##   scenic  the 8 fixed views of tools/environment/scenic_shots.gd (same cameras)
##   lod     one tree of each canopy species seen from 25, 60, 120 and 200 m out in the open
##           (the LOD0 / LOD1 / LOD2 / impostor ranges), plus the view straddling a switch
##   close   under the canopy: forest floor, fern patch, forest edge from the clearing, looking up
##   lineup  C4 pop test: each canopy species alone on a plain in the level's sky and sun, the two
##           neighbouring LODs side by side at each switch distance (LOD0|LOD1 at 45 m,
##           LOD1|LOD2 at 105 m, LOD2|impostor at 165 m); saved as lineup_<species>.png
## script= rebuilds the level's vegetation from another script first (A/B before integrating).

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const Assets := preload("res://scripts/world/vegetation/veg_assets.gd")

const SCENIC := [
	["spawn_play", Vector3.ZERO, Vector3.ZERO, 70.0],
	["spawn_gate", Vector3(1.4, 1.7, 4.0), Vector3(0.0, 1.4, -45.0), 60.0],
	["firing_line", Vector3(-1.2, 1.7, -18.5), Vector3(0.0, 1.2, -110.0), 55.0],
	["range_lookback", Vector3(5.0, 1.7, -118.0), Vector3(0.0, 2.8, -16.0), 50.0],
	["walkway", Vector3(9.0, 5.0, -12.6), Vector3(-12.0, 1.0, -75.0), 65.0],
	["forest", Vector3(-58.0, 1.7, -62.0), Vector3(-22.0, 4.0, -18.0), 65.0],
	["parade", Vector3(7.0, 1.7, 11.0), Vector3(-8.0, 2.4, 3.0), 65.0],
	["aerial", Vector3(48.0, 30.0, 48.0), Vector3(0.0, 0.0, -22.0), 55.0],
]
const CLOSE := [
	["under_canopy", Vector3(-70.0, 1.7, -40.0), Vector3(-95.0, 3.0, -60.0), 65.0],
	["looking_up", Vector3(-72.0, 1.6, -44.0), Vector3(-74.0, 20.0, -50.0), 75.0],
	["edge_from_clearing", Vector3(-24.0, 1.7, 10.0), Vector3(-60.0, 6.0, 12.0), 60.0],
	["west_edge_sun", Vector3(-18.0, 1.7, -80.0), Vector3(-60.0, 6.0, -60.0), 60.0],
	["east_forest", Vector3(40.0, 1.7, -20.0), Vector3(80.0, 5.0, -30.0), 65.0],
	["south_meadow", Vector3(0.0, 1.8, 30.0), Vector3(0.0, 6.0, 90.0), 65.0],
]

var args := {}
var view: SubViewport
var player: Node3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	var out: String = args.get("out", "user://veg_shots")
	var which: String = args.get("set", "all")
	var settle := int(args.get("settle", "60"))
	var only: PackedStringArray = String(args.get("only", "")).split(",", false)
	DirAccess.make_dir_recursive_absolute(out)
	OS.low_processor_usage_mode_sleep_usec = 0
	_block_user_input()
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var lvl := current_scene
	player = lvl.get_node("Player")
	player.set("ignore_mouse_capture", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_release_all()
	if player.get("hud"):
		player.get("hud").visible = false
	if args.has("script"):
		var old := lvl.get_node_or_null("Vegetation")
		if old:
			lvl.remove_child(old)
			old.free()
		var v: Node3D = (load(String(args["script"])) as Script).new()
		v.name = "Vegetation"
		lvl.add_child(v)
		var rng := RandomNumberGenerator.new()
		rng.seed = 1776
		v.build(lvl.settings, rng)
		print("VEGSHOTS rebuilt vegetation: ", JSON.stringify(v.get("stats")))
	var px := DisplayServer.window_get_size()
	if args.has("size"):
		px = Vector2i(int(String(args["size"]).get_slice("x", 0)), int(String(args["size"]).get_slice("x", 1)))
	view = OffscreenView.new()
	view.name = "VegShotsView"
	root.add_child(view)
	view.setup(root, px)
	root.disable_3d = true
	await _frames(90)

	var views: Array = []
	if which in ["scenic", "all"]:
		views.append_array(SCENIC)
	if which in ["lod", "all"]:
		views.append_array(_lod_views(lvl))
	if which in ["close", "all"]:
		views.append_array(CLOSE)
	if which in ["lineup", "all"]:
		await _lineup(lvl, out, settle)
	var images: Array[Image] = []
	for v: Array in views:
		if not only.is_empty() and not String(v[0]) in only:
			continue
		var cam: Camera3D = view.camera
		if v[0] == "spawn_play":
			(player.get("camera") as Camera3D).current = true
			view.source = player.get("camera")
		else:
			view.source = null
			cam.fov = v[3]
			_place(cam, v[1], v[2])
		await _frames(settle)
		view.sync_camera()
		RenderingServer.force_draw(false)
		var img: Image = view.get_texture().get_image()
		var path := out.path_join("%s.png" % v[0])
		img.save_png(path)
		images.append(img)
		print("VEGSHOTS saved ", path)
	if images.size() > 1:
		_sheet(images, out.path_join("sheet.png"))
	print("VEGSHOTS DONE")
	quit()


## For each canopy species, a tree at the lane's west edge seen from 25, 60, 120 and 200 m
## (the LOD0 / LOD1 / LOD2 / impostor ranges), from the east-south-east and 8 deg above its
## mid-height so nothing in between blocks the view.
func _lod_views(lvl: Node) -> Array:
	var veg := lvl.get_node_or_null("Vegetation")
	var layout: Object = veg.get("layout") if veg else null
	var out := []
	if layout == null:
		return out
	var pos: PackedVector3Array = layout.get("tree_pos")
	var kinds: PackedInt32Array = layout.get("tree_kind")
	var scl: PackedFloat32Array = layout.get("tree_scale")
	var dir := Vector3(1.0, 0.0, 0.5).normalized()
	for k in Assets.CANOPY_COUNT:
		var best := -1
		var best_d := INF
		for i in pos.size():
			if kinds[i] != k:
				continue
			var d := pos[i].distance_to(Vector3(-36.0, pos[i].y, -60.0))
			if d < best_d:
				best_d = d
				best = i
		if best < 0:
			continue
		var t := pos[best]
		var h: float = float(Assets.tree(k, 0).get("height", 18.0)) * scl[best]
		var mid := t + Vector3(0, h * 0.5, 0)
		for dist: float in [25.0, 60.0, 120.0, 200.0]:
			var c := mid + dir * dist * cos(deg_to_rad(8.0)) + Vector3.UP * dist * sin(deg_to_rad(8.0))
			var fov := clampf(rad_to_deg(2.0 * atan(h * 0.8 / dist)), 10.0, 70.0)
			out.append(["lod_%s_%03d" % [Assets.SPECIES[k], int(dist)], c, mid, fov])
	return out


## Each canopy species (variant 0) alone in a private world lit by copies of the level's
## environment and sun; the neighbouring LODs at each switch distance, side by side.
func _lineup(lvl: Node, out: String, settle: int) -> void:
	var rig := lvl.get_node_or_null("EnvironmentRig")
	var vp := SubViewport.new()
	vp.size = Vector2i(360, 540)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.use_taa = root.use_taa
	vp.msaa_3d = root.msaa_3d
	vp.screen_space_aa = root.screen_space_aa
	root.add_child(vp)
	var we := WorldEnvironment.new()
	if rig and rig.has_method("get_environment") and rig.get_environment():
		we.environment = rig.get_environment()
	vp.add_child(we)
	if rig and rig.has_method("get_sun") and rig.get_sun():
		vp.add_child(rig.get_sun().duplicate())
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(600, 600)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.36, 0.34, 0.24)
	gm.roughness = 1.0
	ground.material_override = gm
	vp.add_child(ground)
	var cam := Camera3D.new()
	cam.far = 1000.0
	vp.add_child(cam)
	cam.current = true
	var mi := MeshInstance3D.new()
	if args.get("noshadow", "0") == "1":      # diagnostic: no self-shadowing in the lineup
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vp.add_child(mi)
	var imp := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = Assets.impostor_quad()
	mm.instance_count = 1
	imp.multimesh = mm
	imp.material_override = Assets.impostor_material()
	imp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vp.add_child(imp)
	var pairs := [[0, 1, 45.0], [1, 2, 105.0], [2, 3, 165.0]]
	for k in Assets.CANOPY_COUNT:
		var h: float = float(Assets.tree(k, 0).get("height", 18.0))
		var imgs: Array[Image] = []
		for pr: Array in pairs:
			for lod: int in [pr[0], pr[1]]:
				var dist: float = pr[2]
				mi.visible = lod < 3
				imp.visible = lod == 3
				if lod < 3:
					mi.mesh = Assets.tree_mesh(k, 0, lod)
					mi.material_override = Assets.tree_material(k)
				else:
					mm.set_instance_transform(0, Transform3D())
					mm.set_instance_custom_data(0, Color(float(Assets.impostor_row(k, 0)), 0, 0, 0))
				cam.fov = rad_to_deg(2.0 * atan(0.62 * h / dist))
				cam.global_position = Vector3(dist * 0.5, h * 0.5 + dist * 0.05, dist * 0.866)
				cam.look_at(Vector3(0, h * 0.5, 0))
				await _frames(settle)
				RenderingServer.force_draw(false)
				var img := vp.get_texture().get_image()
				img.convert(Image.FORMAT_RGBA8)
				imgs.append(img)
		var w := imgs[0].get_width()
		var hh := imgs[0].get_height()
		var sheet := Image.create(w * imgs.size() + 4 * (imgs.size() / 2 - 1), hh, false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0, 0, 0))
		for i in imgs.size():
			sheet.blit_rect(imgs[i], Rect2i(0, 0, w, hh), Vector2i(i * w + (i / 2) * 4, 0))
		var path := out.path_join("lineup_%s.png" % Assets.SPECIES[k])
		sheet.save_png(path)
		print("VEGSHOTS saved ", path)
	vp.queue_free()


func _place(cam: Camera3D, p: Vector3, target: Vector3) -> void:
	if p.y < 10.0:
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 60.0, p + Vector3.DOWN * 60.0)
		q.exclude = [(player as CollisionObject3D).get_rid()]
		var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
		if hit and p.y - hit.position.y < 1.6 and hit.position.y < p.y + 8.0:
			var lift: float = hit.position.y + 1.6 - p.y
			p.y += lift
			target.y += lift
	cam.global_position = p
	cam.look_at(target)


func _sheet(images: Array[Image], path: String) -> void:
	var w := images[0].get_width() / 2
	var h := images[0].get_height() / 2
	var cols := 4
	var rows := ceili(images.size() / float(cols))
	var sheet := Image.create(w * cols, h * rows, false, Image.FORMAT_RGBA8)
	for i in images.size():
		var im := images[i].duplicate() as Image
		im.convert(Image.FORMAT_RGBA8)
		im.resize(w, h, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	sheet.save_png(path)
	print("VEGSHOTS saved ", path)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
		if not DisplayServer.window_can_draw():
			RenderingServer.force_draw(false)


func _block_user_input() -> void:
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	_release_all()


func _release_all() -> void:
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			Input.action_release(action)
