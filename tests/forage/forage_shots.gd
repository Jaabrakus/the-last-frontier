extends SceneTree
## Windowed screenshots of the wild food and herb plants (scripts/forage; needs a window, not --headless):
##   <plant>.png      each plant close up, in its patch (blackberry, strawberry, plantain, wintergreen, ginseng,
##                    acorns, hazelnuts; then, on 19 September so the fruit and flowers are out, the plants for the
##                    remedies and the vices: willow, yarrow, slippery elm, elderberry, hemp, bearberry, red-osier,
##                    jimsonweed, crabapple)
##   <plant>_wide.png the patch where it grows
##   prompt.png       the gameplay camera at a bramble with the E prompt
##   pick_<clip>.png  picking, mid-clip: a bramble (waist), plantain (low), ginseng (ground), hazel (high)
##   pack.png         the inventory screen with a handful of each
##   sheet.png        all of them in one contact sheet
## and prints the frame time in the woods with the plants shown and hidden.
##
##   woods (only=woods)  the woods' own materials (user 2026-09-28): dry sticks, a fallen limb, arrowwood, pine pitch
##                    on a trunk, turkey feathers under the oaks, fieldstones, chert nodules, a dead sapling (kinds=...
##                    for some); the E prompt at the sticks; the pack; icons.png (icons=... for others)
##
##   Godot --path . --resolution 1280x720 -s tests/forage/forage_shots.gd -- out=/abs/dir [hour=11] [only=new|woods]
##
## The plants are the project's own models.

const CELL := Vector2i(640, 360)

var args := {}
var out := ""
var player: FrontierPlayer
var f: ForageField
var shots: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	out = String(args.get("out", "user://forage_shots"))
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	player = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for n in current_scene.find_children("*", "", true, false):
		if n is DayNight:
			(n as DayNight).clock.running = false
			(n as DayNight).clock.set_time(float(args.get("hour", "11")))
			if (n as DayNight).has_method("force_weather"):
				(n as DayNight).force_weather("clear")
	await _frames(int(args.get("settle", "200")))
	f = ForageField.find(self)
	var counts := {}
	for pa in f.patches:
		counts[pa.kind] = int(counts.get(pa.kind, 0)) + 1
	print("forage: build %.1f ms, patches %s, multimeshes %d, grass texels cleared %d" % [f.build_usec / 1000.0, counts,
			f.find_children("*", "MultiMeshInstance3D", false, false).size(), f.grass_cleared])
	if String(args.get("only", "")) == "woods":
		var woods: PackedStringArray = String(args.get("kinds", "deadwood,windfall,arrowwood,pine_pitch,turkey_scratch,fieldstones,flint_nodules,dead_pole")).split(",")
		for kind in woods:
			await _plant_shots(kind)
		var di := _patch("deadwood")
		_stand(di, 0, 1.0)
		await _phys(20)
		await _shot("prompt_woods", null)
		await _pack()
		await _icon_strip(String(args.get("icons", "shoots,pine_pitch,feathers,branches,firewood")).split(","))
		_sheet()
		print("SHOTS DONE ", out)
		quit()
		return
	var only_new := String(args.get("only", "")) == "new"
	if not only_new:
		for kind in ["blackberry", "strawberry", "plantain", "wintergreen", "ginseng", "acorns", "hazelnuts"]:
			await _plant_shots(kind)
	f.day_override = 262.0
	f._update_season(true)
	for kind in ["willow", "yarrow", "slippery_elm", "elderberry", "hemp", "bearberry", "red_osier", "jimsonweed", "crabapple"]:
		await _plant_shots(kind)
	f.day_override = -1.0
	f._update_season(true)
	if not only_new:
		await _prompt_and_picks()
	await _pack()
	if not only_new:
		await _perf()
	_sheet()
	print("SHOTS DONE ", out)
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _phys(n: int) -> void:
	for i in n:
		await physics_frame


func _look(from: Vector3, at: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at(at - from, Vector3.UP), from)


func _shot(name: String, cam_xf: Variant, fov := 45.0) -> void:
	var cam: Camera3D = null
	if cam_xf is Transform3D:
		cam = Camera3D.new()
		cam.fov = fov
		cam.near = 0.02
		cam.far = 800.0
		current_scene.add_child(cam)
		cam.global_transform = cam_xf
		cam.current = true
	await _frames(4)
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	if cam:
		cam.queue_free()
		player.camera.current = true
	img.save_png(out.path_join(name + ".png"))
	var cell := img.duplicate() as Image
	cell.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
	shots.append(cell)
	print("saved ", name)


func _sheet() -> void:
	var cols := 4
	var rows := ceili(shots.size() / float(cols))
	var grid := Image.create(CELL.x * cols, CELL.y * rows, false, Image.FORMAT_RGB8)
	for i in shots.size():
		grid.blit_rect(shots[i], Rect2i(Vector2i.ZERO, CELL), Vector2i((i % cols) * CELL.x, (i / cols) * CELL.y))
	grid.save_png(out.path_join("sheet.png"))


## The patch of `kind` nearest the fort (hazel: one 40+ m out, in the open enough to see).
func _patch(kind: String) -> int:
	var best := -1
	var bd := INF
	for i in f.patches.size():
		if f.patches[i].kind != kind:
			continue
		var d := Vector2(f.patches[i].pos.x, f.patches[i].pos.z).length()
		if kind in ["willow", "slippery_elm", "elderberry", "red_osier", "crabapple"] and d < 45.0:
			continue          # (the trees and shrubs: one away from the fort's buildings, in view)
		if d < bd:
			bd = d
			best = i
	return best


## The player out of the way, then a close shot of a plant and a wide one of its patch.
func _plant_shots(kind: String) -> void:
	var pi := _patch(kind)
	if pi < 0:
		print("no ", kind)
		return
	var pa: Dictionary = f.patches[pi]
	var pl: Dictionary = pa.plants[0]
	for q in pa.plants:
		if float(q.stock) > 0.0:
			pl = q
			break
	var p: Vector3 = pl.pos
	player.global_position = Vector3(0, FrontierTerrain.height_at(0, 6) + 0.1, 6)
	await _phys(6)
	var out_dir := Vector3(-p.x, 0.0, -p.z).normalized()
	var side := out_dir.cross(Vector3.UP).normalized()
	var h := {"blackberry": 0.9, "hazelnuts": 0.0, "ginseng": 0.35, "willow": 1.8, "slippery_elm": 2.8, "elderberry": 1.6,
			"hemp": 1.6, "red_osier": 1.5, "jimsonweed": 0.8, "crabapple": 2.3, "yarrow": 0.5, "bearberry": 0.05,
			"arrowwood": 1.7, "windfall": 0.1, "deadwood": 0.05, "turkey_scratch": 0.02, "dead_pole": 0.05, "fieldstones": 0.1,
			"flint_nodules": 0.05}.get(kind, 0.12) as float
	var dist := {"blackberry": 2.4, "hazelnuts": 1.1, "ginseng": 0.9, "acorns": 0.8, "willow": 3.4, "slippery_elm": 4.4,
			"elderberry": 3.0, "hemp": 2.6, "red_osier": 2.8, "jimsonweed": 1.7, "crabapple": 4.2, "yarrow": 0.95,
			"bearberry": 0.75, "arrowwood": 3.2, "windfall": 2.6, "deadwood": 1.5, "turkey_scratch": 1.0, "dead_pole": 2.6,
			"fieldstones": 1.3, "flint_nodules": 0.8}.get(kind, 0.7) as float
	var look := p + Vector3.UP * (h * 0.45)
	# (the shrubs and small trees from near their own height, under the canopy round them)
	var big := kind in ["willow", "slippery_elm", "elderberry", "red_osier", "crabapple", "hemp", "arrowwood"]
	var eye := look + (out_dir + side * 0.4).normalized() * dist + Vector3.UP * maxf(dist * (0.2 if big else 0.55), 0.3)
	if kind == "hazelnuts":
		# from outside the crown, along the cluster's way out from the shrub's middle
		var out_c := (p - (pa.pos as Vector3) - Vector3.UP * (p.y - float(pa.pos.y)) * 0.5).normalized()
		eye = p + out_c * 0.45 + Vector3.UP * 0.05
		look = p
	if kind == "pine_pitch":
		# on the trunk: from out of the bark, a little to the side
		var out_t := Vector3(sin(float(pl.yaw)), 0.0, cos(float(pl.yaw)))
		eye = p + (out_t + out_t.cross(Vector3.UP) * 0.3).normalized() * 0.8 + Vector3.UP * 0.1
		look = p
	await _shot(kind, _look(eye, look), 50.0)
	var c: Vector3 = pa.pos
	var r := float(pa.r)
	await _shot(kind + "_wide", _look(c + (out_dir + side * 0.3).normalized() * (r + 5.0) + Vector3.UP * 2.6, c + Vector3.UP * 0.2), 55.0)


func _stand(pi: int, li: int, dist := 1.2) -> void:
	var p: Vector3 = f.patches[pi].plants[li].pos
	var out_dir := Vector3(-p.x, 0.0, -p.z).normalized()
	var at := p + out_dir * dist
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.05
	player.global_position = at
	player.velocity = Vector3.ZERO
	var d := p - at
	player.yaw = atan2(-d.x, -d.z)
	player.rotation.y = player.yaw
	player.pitch = deg_to_rad(-18.0)


func _prompt_and_picks() -> void:
	var bi := _patch("blackberry")
	_stand(bi, 0)
	await _phys(20)
	await _shot("prompt", null)
	for kind in ["blackberry", "plantain", "ginseng", "hazelnuts"]:
		var pi := _patch(kind)
		if pi < 0:
			continue
		_stand(pi, 0, 1.0 if kind != "hazelnuts" else 1.4)
		await _phys(20)
		if not f._offer.is_empty() and bool(f._offer.get("can", false)):
			f.interact(player)
		else:
			print("no offer at ", kind, " ", f._offer)
			continue
		await _phys(int(120 * 2.6))
		var hs := player.global_basis.x
		var c := player.global_position + Vector3.UP * 0.8
		await _shot("pick_" + String(f.data.plants[kind].clip), _look(c + hs * 2.6 - player.global_basis.z * 0.6 + Vector3.UP * 0.6, c - player.global_basis.z * 0.5), 50.0)
		while f.picker.working:
			await physics_frame


func _pack() -> void:
	var inv := InventoryState.from_player(player)
	for item in ForageModels.ITEMS + ["willow_bark_tea", "slippery_elm_gruel", "elderberry_syrup"]:
		if inv.pack_count(item) == 0:
			inv.add(item, 3)
	player.inventory_pack = inv.pack.duplicate(true)
	var scr := InventoryScreen.open_for(player)
	await _frames(90)
	await _shot("pack", null)
	scr.close()
	await _frames(5)


## Frame time in the woods by a patch: the plants drawn, then hidden.
func _perf() -> void:
	var pi := _patch("wintergreen")
	_stand(pi, 0, 3.0)
	player.pitch = deg_to_rad(-8.0)
	await _frames(60)
	var ms := []
	for on in [true, false, true]:
		f.visible = on
		await _frames(30)
		var t0 := Time.get_ticks_usec()
		await _frames(120)
		ms.append((Time.get_ticks_usec() - t0) / 120000.0)
	print("perf: frame %.2f ms with the plants, %.2f ms without, %.2f ms with again" % [ms[0], ms[1], ms[2]])


## The pack icons of `kinds` in a row (icons.png), as ItemIcons renders them.
func _icon_strip(kinds: Array) -> void:
	var icons := ItemIcons.shared(self)
	var got := {}
	for i in 600:
		for k: String in kinds:
			if not got.has(k):
				var t := icons.get_icon(k)
				if t:
					got[k] = t.get_image()
		if got.size() == kinds.size():
			break
		await process_frame
	var sz := 128
	var strip := Image.create(sz * kinds.size(), sz, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0.16, 0.15, 0.13))
	for i in kinds.size():
		if got.has(kinds[i]):
			var im: Image = got[kinds[i]]
			im.convert(Image.FORMAT_RGBA8)
			im.resize(sz, sz)
			strip.blend_rect(im, Rect2i(0, 0, sz, sz), Vector2i(i * sz, 0))
	strip.save_png(out.path_join("icons.png"))
