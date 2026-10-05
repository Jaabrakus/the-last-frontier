extends SceneTree
## Forest look captures for the 2026-09-24 focused pass (laggy / clipping / not unified). Windowed;
## renders off-window (tools/environment/offscreen_view.gd) so a covered window does not stall it,
## and unbinds all game input. Wrap it in a time limit:
##
##   Godot --path . --resolution 1280x720 -s tools/environment/vegetation/forest_shots.gd -- --no-capture \
##       out=<dir> [prefix=<tag>_] [settle=60] [quality=..] [only=name,...]
##
## Views: forest_interior, forest_deep, edge_from_fort (the walkway looking over the west wall
## to the tree line), edge_from_gate, range_firing_line, range_lookback, and one close-up per
## species (white pine, hemlock, oak, maple, birch, saplings / hazel): the layout tree of that
## species nearest to a fixed spot on the forest edge with a clear view, framed from 14-20 m at
## eye height (LOD0). Saves <prefix><view>.png and <prefix>sheet.png.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")
const Assets := preload("res://scripts/world/vegetation/veg_assets.gd")

const VIEWS := [
	["forest_interior", Vector3(-58.0, 1.7, -62.0), Vector3(-22.0, 4.0, -18.0), 65.0],
	["forest_deep", Vector3(-95.0, 1.7, -45.0), Vector3(-130.0, 4.0, -40.0), 65.0],
	["edge_from_fort", Vector3(-11.0, 5.0, 12.0), Vector3(-70.0, 6.0, 20.0), 60.0],
	["edge_from_gate", Vector3(3.0, 1.7, -24.0), Vector3(-45.0, 6.0, -60.0), 60.0],
	["range_firing_line", Vector3(-1.2, 1.7, -18.5), Vector3(0.0, 1.2, -110.0), 55.0],
	["range_lookback", Vector3(5.0, 1.7, -118.0), Vector3(0.0, 2.8, -16.0), 50.0],
]
## Species close-ups: [name, species ids, search centre].
const SPECIES_VIEWS := [
	["sp_white_pine", [0], Vector2(-45.0, 10.0)],
	["sp_hemlock", [1], Vector2(-45.0, -40.0)],
	["sp_oak", [2], Vector2(45.0, -40.0)],
	["sp_maple", [3], Vector2(45.0, 10.0)],
	["sp_birch", [4], Vector2(-40.0, 30.0)],
]

var args := {}
var view: SubViewport


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	var out: String = args.get("out", "user://forest_shots")
	var prefix: String = args.get("prefix", "")
	var settle := int(args.get("settle", "60"))
	var only: PackedStringArray = String(args.get("only", "")).split(",", false)
	DirAccess.make_dir_recursive_absolute(out)
	OS.low_processor_usage_mode_sleep_usec = 0
	# The window would sit on the user's screen for minutes: minimise it (the off-window view still
	# renders and times correctly while the window cannot draw). minimize=0 keeps it.
	if args.get("minimize", "1") != "0":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var level := current_scene
	var player := level.get_node("Player") as Node3D
	player.set("ignore_mouse_capture", true)
	if player.get("hud"):
		player.get("hud").visible = false
	player.global_position = Vector3(0, 0.1, 30)     # out of every view
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(1280, 720))
	root.disable_3d = true
	var grass := level.get_node_or_null("Terrain/Grass")
	if grass and "follow" in grass:
		grass.set("follow", view.camera)
	var views := []
	for v: Array in VIEWS:
		views.append(v)
	var lay: Variant = level.get_node("Vegetation").get("layout")
	for sv: Array in SPECIES_VIEWS:
		var cam := _species_camera(lay, sv[1], sv[2])
		if not cam.is_empty():
			views.append([sv[0], cam[0], cam[1], 45.0])
			print("FSHOT %s tree at %s" % [sv[0], cam[1]])
	var images: Array[Image] = []
	var first := true
	for v: Array in views:
		if not only.is_empty() and not String(v[0]) in only:
			continue
		_place(v[1], v[2], v[3])
		await _frames(settle + (120 if first else 0))
		first = false
		var img := view.get_texture().get_image()
		img.save_png(out.path_join("%s%s.png" % [prefix, v[0]]))
		images.append(img)
		print("FSHOT saved %s%s" % [prefix, v[0]])
	_sheet(images, out.path_join("%ssheet.png" % prefix))
	print("FOREST SHOTS DONE")
	quit()


## Camera [position, target] for a close-up of the tree of `kinds` nearest to `centre` whose view
## from 16 m (toward the fort side) is clear of other trunks.
func _species_camera(lay: Variant, kinds: Array, centre: Vector2) -> Array:
	var cands := []
	for i in lay.tree_pos.size():
		if lay.tree_kind[i] in kinds:
			var p: Vector3 = lay.tree_pos[i]
			cands.append([Vector2(p.x, p.z).distance_to(centre), i])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var best := -1
	for c: Array in cands.slice(0, 60):
		if _clear_view(lay, c[1]):
			best = c[1]
			break
	if best < 0:
		return []
	var p: Vector3 = lay.tree_pos[best]
	var t := Assets.tree(lay.tree_kind[best], lay.tree_variant[best])
	var h := float(t.get("height", 18.0)) * float(lay.tree_scale[best])
	var dir := _view_dir(p)
	var dist := clampf(h * 0.95, 12.0, 22.0)
	var cam := p + dir * dist
	cam.y = FrontierTerrain.height_at(cam.x, cam.z) + 1.7
	return [cam, p + Vector3(0, h * 0.45, 0)]


## Horizontal direction from a tree toward the fort (where the open ground is).
func _view_dir(p: Vector3) -> Vector3:
	var d := Vector3(-p.x, 0.0, -p.z - 60.0 if p.z < -40.0 else -p.z)
	return d.normalized()


func _clear_view(lay: Variant, i: int) -> bool:
	var p: Vector3 = lay.tree_pos[i]
	var dir := _view_dir(p)
	var a := Vector2(p.x, p.z)
	var b := a + Vector2(dir.x, dir.z) * 18.0
	for j in lay.tree_pos.size():
		if j == i:
			continue
		var q := Vector2(lay.tree_pos[j].x, lay.tree_pos[j].z)
		if q.distance_to(a) > 26.0:
			continue
		var ab := b - a
		var t := clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		if (a + ab * t).distance_to(q) < 3.0 and t > 0.12:
			return false
	return true


func _place(p: Vector3, target: Vector3, fov: float) -> void:
	view.camera.global_position = p
	view.camera.look_at(target)
	view.camera.fov = fov


func _sheet(images: Array[Image], path: String) -> void:
	if images.is_empty():
		return
	var cols := 4
	var w := 480
	var h := 270
	var rows := int(ceil(images.size() / float(cols)))
	var sheet := Image.create(w * cols, h * rows, false, Image.FORMAT_RGB8)
	for k in images.size():
		var im := images[k].duplicate() as Image
		im.convert(Image.FORMAT_RGB8)
		im.resize(w, h, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((k % cols) * w, (k / cols) * h))
	sheet.save_png(path)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
		if not DisplayServer.window_can_draw():
			RenderingServer.force_draw(false)
