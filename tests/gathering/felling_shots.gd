extends SceneTree
## Windowed screenshots of gathering (needs a window, not --headless): the real level, the real player and input.
##
##   what=pack     the felling axe on the pack's tool loop, close up (pack.png)
##   what=pose     the tool poses: on the pack, the draw, the carry, the felling swing and the overhead blow,
##                 from the side, the front and the gameplay camera (one grid per tool: pose_<tool>.png)
##   what=fell     the felling filmstrip: the axe drawn, strokes into a tree, the fall frame by frame, the tree
##                 down, bucking, the stump (fell_<n>.png pages of 6 frames, and fell_strip.png, one row)
##   what=mine     the mattock breaking a rock down (mine.png)
##   what=sapling  a sapling cut with E (sapling.png)
##   what=icons    the inventory icons of the tools and the gathered items and the dart bundle (icons.png)
##   what=inventory  the inventory screen with the tool loop slot (inventory.png)
##
##   Godot --path . --resolution 1280x720 -s tests/gathering/felling_shots.gd -- --no-capture out=/abs/dir \
##       [what=pose,fell,mine,sapling,icons,inventory] [hour=11] [tree=<index>]
##
## Animation data: animations_extra/Actor_B_from_A.res and animations/Actor_B.res. Models of the tools, the
## items, the stump handling and the fall are the project's own.

const CELL := Vector2i(420, 300)

var args := {}
var out := ""
var player: FrontierPlayer
var gt: GatherTools
var h: VegHarvest


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	out = String(args.get("out", "user://gathering_shots"))
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
	gt = player.gather
	h = VegHarvest.find(self)
	print("vegetation: %d trees, %d plants, %d props; gathering grid built in %.1f ms" % [h.lay.tree_pos.size(),
			h.lay.plant_pos.size(), h.lay.prop_pos.size(), h.build_ms])
	var what: PackedStringArray = String(args.get("what", "pose,fell,mine,sapling,icons,inventory")).split(",")
	if "icons" in what:
		await _icons()
	if "inventory" in what:
		await _inventory()
	if "pack" in what:
		await _pack()
	if "pose" in what:
		await _poses("felling_axe")
		await _poses("mattock")
	if "fell" in what:
		await _fell()
	if "sapling" in what:
		await _sapling()
	if "mine" in what:
		await _mine()
	print("SHOTS DONE ", out)
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _phys(n: int) -> void:
	for i in n:
		await physics_frame


func _until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _phys(3)
	Input.action_release(action)
	await _phys(2)


func _stand_at(pos: Vector3, r: float, gap: float, from: Vector3) -> void:
	var d := Vector3(pos.x - from.x, 0.0, pos.z - from.z)
	d = d.normalized() if d.length() > 1e-3 else Vector3.FORWARD
	var at := pos - d * (r + gap)
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.05
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.yaw = atan2(-d.x, -d.z)
	player.rotation.y = player.yaw
	player.pitch = deg_to_rad(-12.0)


## Renders the frozen scene from `cam_xf` (null: the gameplay camera) into a CELL image.
func _grab(cam_xf: Variant, fov := 40.0) -> Image:
	var cam: Camera3D = null
	if cam_xf is Transform3D:
		cam = Camera3D.new()
		cam.fov = fov
		cam.far = 800.0
		current_scene.add_child(cam)
		cam.global_transform = cam_xf
		cam.current = true
	await _frames(2)
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	if cam:
		cam.queue_free()
		player.camera.current = true
	var sz := img.get_size()
	var hgt := sz.y
	var wdt := int(hgt * float(CELL.x) / CELL.y)
	var crop := img.get_region(Rect2i((sz.x - wdt) / 2, 0, wdt, hgt))
	crop.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
	return crop


func _look(from: Vector3, at: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at(at - from, Vector3.UP), from)


## Side, front and gameplay views of the player.
func _views(label: String) -> Array:
	paused = true
	var c := player.global_position + Vector3(0, 1.0, 0)
	var b := player.global_basis
	var side := await _grab(_look(c + b * Vector3(2.6, 0.3, 0.2), c))
	var front := await _grab(_look(c + b * Vector3(0.8, 0.4, -2.8), c))
	var back := await _grab(_look(c + b * Vector3(-0.9, 0.6, 2.6), c))
	var play := await _grab(null)
	paused = false
	return [label, [side, front, back, play]]


func _save_grid(shots: Array, rows: int, path: String) -> void:
	if shots.is_empty():
		return
	var cols := shots.size()
	var grid := Image.create(CELL.x * cols, CELL.y * rows, false, Image.FORMAT_RGB8)
	for c in cols:
		var views: Array = shots[c][1]
		for r in mini(rows, views.size()):
			grid.blit_rect(views[r], Rect2i(Vector2i.ZERO, CELL), Vector2i(c * CELL.x, r * CELL.y))
	grid.save_png(path)
	var labels := []
	for s: Array in shots:
		labels.append(String(s[0]))
	print("saved %s: %s" % [path, ", ".join(labels)])


# --- Poses ------------------------------------------------------------------------------------------

func _poses(kind: String) -> void:
	if args.get("nogear", "0") == "1":
		# the slung weapons hide the tool on the pack: take them out of the picture
		for n in player.skeleton.find_children("Stowed_*", "Node3D", true, false):
			(n as Node3D).visible = false
	player.global_position = Vector3(float(args.get("x", "0")), 0.3, float(args.get("z", "30")))
	player.yaw = 0.0
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	await _phys(60)
	var shots: Array = []
	shots.append(await _views("on the pack"))
	gt.take_out(kind)
	await _until(func() -> bool: return gt.phase == GatherTools.Phase.DRAW_GRAB and gt._t > 0.25, 200)
	shots.append(await _views("draw: reach"))
	await _until(func() -> bool: return gt.phase == GatherTools.Phase.DRAW_OUT and gt._t > 0.35, 200)
	shots.append(await _views("draw: out"))
	await _until(func() -> bool: return gt.phase == GatherTools.Phase.READY, 300)
	await _phys(30)
	shots.append(await _views("carry"))
	# swings with nothing to hit: drive the swing clock directly
	for sw in ["side", "chop"]:
		# a target that is nothing (no impact lands): only the swing plays
		gt.target = {"type": "pose", "i": -1, "src": "", "pos": player.global_position - player.global_basis.z * 1.3,
				"radius": 0.3, "dist": 1.0}
		gt.call(&"_start_swing", sw)
		var s: Dictionary = gt.get("_swing")
		for f: float in [0.35, 0.8, 1.0]:
			await _until(func() -> bool: return float(s.get("u", 0.0)) >= f * float(s.impact), 300)
			shots.append(await _views("%s %.0f%%" % [sw, f * 100.0]))
		gt.target = {}
		await _until(func() -> bool: return gt.phase == GatherTools.Phase.READY, 400)
	Input.action_press(&"move_forward")
	await _phys(80)
	shots.append(await _views("walking"))
	Input.action_release(&"move_forward")
	await _phys(30)
	gt.put_away()
	await _until(func() -> bool: return gt.phase == GatherTools.Phase.STOW_PLACE, 300)
	shots.append(await _views("stowing"))
	await _until(func() -> bool: return gt.phase == GatherTools.Phase.IDLE, 300)
	await _phys(30)
	# pages of 6
	for p0 in range(0, shots.size(), 6):
		_save_grid(shots.slice(p0, p0 + 6), 4, out.path_join("pose_%s_%d.png" % [kind, p0 / 6]))


## The tool on the pack, close up (hands free, gear as worn): back, right, left and three-quarter views.
func _pack() -> void:
	player.global_position = Vector3(0, 0.3, 30)
	player.yaw = 0.0
	player.rotation.y = 0.0
	if not player.hands_free:
		player.toggle_hands_free()
	await _phys(120)
	paused = true
	var c := player.global_position + Vector3(0, 1.2, 0)
	var b := player.global_basis
	var shots: Array = []
	for pair in [["back", Vector3(0.0, 0.2, 1.8)], ["right", Vector3(1.8, 0.2, 0.2)], ["left", Vector3(-1.8, 0.2, 0.2)],
			["back right", Vector3(1.2, 0.5, 1.4)]]:
		shots.append([pair[0], [await _grab(_look(c + b * pair[1], c), 45.0)]])
	paused = false
	_save_grid(shots, 1, out.path_join("pack.png"))


# --- Felling ----------------------------------------------------------------------------------------

func _pick_tree() -> int:
	if args.has("tree"):
		return int(args.tree)
	# a tree at the edge of the fort's clearing (the camera stands in the clearing), clear of the range lane
	var best := -1
	var bs := INF
	for i in h.lay.tree_pos.size():
		if int(h.lay.tree_kind[i]) >= VegHarvest.Assets.CANOPY_COUNT or h.lay.tree_collider[i] == 0:
			continue
		var p: Vector3 = h.lay.tree_pos[i]
		var rad := Vector2(p.x, p.z).length()
		if rad < 26.0 or rad > 60.0 or (absf(p.x) < 10.0 and p.z < 0.0):
			continue
		var d := h.describe("tree", "tree", i)
		if float(d.height) < 13.0 or float(d.radius) > 0.42 or float(d.radius) < 0.18:
			continue
		# open ground round it (fewer trees in 7 m), a clean bole (white pine, oak), near the clearing
		var crowd := h.near(p, 7.0).filter(func(e: Dictionary) -> bool: return String(e.type) == "tree").size()
		var sc := rad * 0.3 + crowd * 3.0 + (0.0 if String(d.species) in ["white_pine", "oak"] else 8.0)
		if sc < bs:
			bs = sc
			best = i
	return best


func _fell() -> void:
	var i := _pick_tree()
	if i < 0:
		print("no tree to fell")
		return
	var tree := h.describe("tree", "tree", i)
	print("felling tree %d: %s r=%.2f h=%.1f at %s" % [i, tree.species, tree.radius, tree.height, tree.pos])
	var tp: Vector3 = tree.pos
	var outward := Vector3(tp.x, 0, tp.z).normalized()
	var tangent := outward.cross(Vector3.UP).normalized()
	# the player on one side along the clearing's edge: the tree falls along the edge, in the camera's view
	_stand_at(tp, float(tree.radius), 1.0, tp - tangent * 5.0)
	player.pitch = deg_to_rad(4.0)
	await _phys(30)
	var shots: Array = []
	var fall_dir := tangent
	var wide := _look(tp - outward * 15.0 + fall_dir * 5.0 + Vector3.UP * 2.2, tp + fall_dir * 6.0 + Vector3.UP * 4.0)
	var close := _look(player.global_position - outward * 3.2 + Vector3.UP * 1.3 - fall_dir * 1.0, player.global_position + Vector3.UP * 1.0 + fall_dir * 0.6)
	await _tap(&"tool_axe")
	await _until(func() -> bool: return gt.phase == GatherTools.Phase.READY, 400)
	shots.append(["axe out", [await _grab_paused(null), await _grab_paused(wide, 50.0), await _grab_paused(close, 45.0)]])
	var felled := [null]
	gt.felled.connect(func(ft: FelledTree) -> void: felled[0] = ft, CONNECT_ONE_SHOT)
	Input.action_press(&"fire")
	var got := 0
	var n := 0
	while felled[0] == null and n < 120 * 40:
		n += 1
		var s: Dictionary = gt.get("_swing")
		var phase := -1.0 if s.is_empty() else float(s.u) / float(s.impact)
		if got == 0 and phase > 0.45 and phase < 0.55 or got == 1 and phase > 0.97 and phase < 1.03:
			shots.append(["wind up" if got == 0 else "stroke lands", [await _grab_paused(null), await _grab_paused(wide, 50.0),
					await _grab_paused(close, 45.0)]])
			got += 1
		await physics_frame
	Input.action_release(&"fire")
	var ft: FelledTree = felled[0]
	if ft == null:
		print("the tree did not fall")
		_save_grid(shots, 3, out.path_join("fell_0.png"))
		return
	# the fall, every 0.5 s
	var t0 := 0.0
	while not ft.is_down() and t0 < 8.0:
		shots.append(["fall %.1fs %.0f deg" % [t0, rad_to_deg(ft.theta)], [await _grab_paused(null), await _grab_paused(wide, 50.0),
				await _grab_paused(close, 45.0)]])
		await _phys(60)
		t0 += 0.5
	await _until(func() -> bool: return ft.is_down(), 600)
	await _phys(90)
	var over := _look(ft.hinge + Vector3(0, 7, 0) - ft.fall_dir * 5.0 - outward * 7.0, ft.hinge + ft.fall_dir * 7.0)
	shots.append(["down", [await _grab_paused(null), await _grab_paused(wide, 50.0), await _grab_paused(over, 60.0)]])
	# buck it
	var mid := ft.hinge + ft.axis() * minf(float(ft.info.crown_bottom), ft.length) * 0.5
	var side := ft.fall_dir.cross(Vector3.UP).normalized()
	if side.dot(outward) > 0.0:
		side = -side
	_stand_at(Vector3(mid.x, 0, mid.z), float(ft.info.radius), 0.85, mid + side * 3.0)
	player.pitch = deg_to_rad(-8.0)
	await _phys(30)
	var bclose := _look(player.global_position + side * 3.0 + ft.fall_dir * 2.2 + Vector3.UP * 1.4, player.global_position + Vector3.UP * 0.7 - side * 0.6)
	Input.action_press(&"fire")
	got = 0
	n = 0
	while is_instance_valid(ft) and ft.state != FelledTree.State.GONE and n < 120 * 60:
		n += 1
		var s: Dictionary = gt.get("_swing")
		var phase := -1.0 if s.is_empty() else float(s.u) / float(s.impact)
		if got < 2 and (got == 0 and phase > 0.5 and phase < 0.56 or got == 1 and phase > 0.98 and phase < 1.04):
			shots.append(["bucking %s" % ("wind up" if got == 0 else "blow"), [await _grab_paused(null), await _grab_paused(wide, 50.0),
					await _grab_paused(bclose, 45.0)]])
			got += 1
		await physics_frame
	Input.action_release(&"fire")
	await _phys(200)
	var stump_view := _look(tp - outward * 2.4 + tangent * 1.2 + Vector3.UP * 1.5, tp + Vector3.UP * 0.3)
	shots.append(["stump", [await _grab_paused(null), await _grab_paused(wide, 50.0), await _grab_paused(stump_view, 45.0)]])
	var inv := InventoryState.from_player(player)
	print("pack: logs %d firewood %d branches %d; woodcutting %.2f" % [inv.pack_count("log"), inv.pack_count("firewood"),
			inv.pack_count("branches"), gt.skills.points_of("woodcutting")])
	for p0 in range(0, shots.size(), 6):
		_save_grid(shots.slice(p0, p0 + 6), 3, out.path_join("fell_%d.png" % (p0 / 6)))
	# the filmstrip: one row of the wide view
	var strip: Array = []
	for s: Array in shots:
		strip.append([s[0], [s[1][1]]])
	_save_grid(strip, 1, out.path_join("fell_strip.png"))


func _grab_paused(cam_xf: Variant, fov := 40.0) -> Image:
	paused = true
	var img := await _grab(cam_xf, fov)
	paused = false
	return img


# --- Sapling, rock -----------------------------------------------------------------------------------

func _sapling() -> void:
	var near := h.near(player.global_position, 150.0).filter(func(d: Dictionary) -> bool: return String(d.type) == "sapling")
	if near.is_empty():
		print("no sapling")
		return
	var sp: Dictionary = near[0]
	_stand_at(sp.pos, float(sp.radius), 0.7, sp.pos + Vector3(-2, 0, 1))
	await _phys(20)
	var shots: Array = []
	var side := _look(player.global_position + player.global_basis * Vector3(2.8, 0.8, -0.5), sp.pos + Vector3.UP * 1.0)
	shots.append(["sapling: %s" % gt.prompt(), [await _grab_paused(null), await _grab_paused(side, 50.0)]])
	var poles0 := InventoryState.from_player(player).pack_count("pole")
	for k in gt.sapling_strokes():
		await _until(func() -> bool: return player.interactor.target == gt.gather_target, 60)
		await _tap(ThrownPickup.INTERACT)
		await _until(func() -> bool: return gt.phase == GatherTools.Phase.SWING, 400)
		await _until(func() -> bool: return gt.phase == GatherTools.Phase.READY, 400)
		shots.append(["E stroke %d" % (k + 1), [await _grab_paused(null), await _grab_paused(side, 50.0)]])
	var poles := InventoryState.from_player(player).pack_count("pole")
	print("sapling: poles %d -> %d, cut %s" % [poles0, poles, h.cut.has("%s:%d" % [sp.src, int(sp.i)])])
	_save_grid(shots, 2, out.path_join("sapling.png"))
	gt.put_away()
	await _until(func() -> bool: return gt.phase == GatherTools.Phase.IDLE, 300)


func _mine() -> void:
	var p := player.global_position
	var best := {}
	var bd := INF
	for i in h.lay.prop_pos.size():
		var k: int = h.lay.prop_kind[i]
		if k < VegHarvest.Assets.ROCK_FIRST or k > VegHarvest.Assets.ROCK_LAST:
			continue
		var d := h.describe("rock", "prop", i)
		if d.is_empty() or String(d.name) == "boulder":
			continue
		var dist := (d.pos as Vector3).distance_to(p)
		if dist < bd:
			bd = dist
			best = d
	if best.is_empty():
		return
	_stand_at(best.pos, float(best.radius), 0.5, best.pos + Vector3(2, 0, -2))
	await _phys(20)
	var shots: Array = []
	var view := _look(best.pos + Vector3(3.0, 2.0, 1.0), best.pos + Vector3.UP * 0.4)
	await _tap(&"tool_mattock")
	await _until(func() -> bool: return gt.tool == "mattock" and gt.phase == GatherTools.Phase.READY, 600)
	shots.append(["%s" % gt.prompt(), [await _grab_paused(null), await _grab_paused(view, 50.0)]])
	Input.action_press(&"fire")
	var i := int(best.i)
	var total := int(gt.rock_state(i).total)
	var marks := [total - 1, int(total * 0.5), 1, 0]
	var got := 0
	for m: int in marks:
		await _until(func() -> bool: return int(gt.rock_state(i).left) <= m, 120 * 60)
		await _phys(30)
		shots.append(["%d left" % int(gt.rock_state(i).left), [await _grab_paused(null), await _grab_paused(view, 50.0)]])
		got += 1
	Input.action_release(&"fire")
	var inv := InventoryState.from_player(player)
	print("mine: %s, stones %d flint %d, mining %.2f" % [best.name, inv.pack_count("stone"), inv.pack_count("flint"), gt.skills.points_of("mining")])
	_save_grid(shots, 2, out.path_join("mine.png"))
	gt.put_away()
	await _until(func() -> bool: return gt.phase == GatherTools.Phase.IDLE, 300)


# --- Icons, inventory ------------------------------------------------------------------------------------

func _icons() -> void:
	var icons := ItemIcons.shared(self)
	var kinds := ["felling_axe", "mattock", "log", "firewood", "branches", "pole", "stone", "flint", "dart_bundle", "tomahawk", "musket"]
	for k in kinds:
		icons.get_icon(k)
	for i in 400:
		var all := true
		for k in kinds:
			if icons.get_icon(k) == null:
				all = false
		if all:
			break
		await process_frame
	var grid := Image.create(128 * kinds.size(), 128, false, Image.FORMAT_RGBA8)
	grid.fill(Color(0.12, 0.1, 0.08, 1.0))
	for c in kinds.size():
		var tex := icons.get_icon(kinds[c])
		if tex:
			var img := tex.get_image()
			img.convert(Image.FORMAT_RGBA8)
			grid.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(c * 128, 0))
	grid.save_png(out.path_join("icons.png"))
	print("saved icons.png: ", ", ".join(kinds))


func _inventory() -> void:
	# a few gathered things so the pack shows them
	gt.give("log", 3)
	gt.give("stone", 5)
	gt.give("flint", 1)
	gt.give("branches", 4)
	var scr := InventoryScreen.open_for(player)
	await _frames(90)
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join("inventory.png"))
	print("saved inventory.png")
	scr.close()
	await _frames(10)
