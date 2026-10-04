extends "res://tools/showcase/clips.gd"
## Pictures of the game for the main menu and the loading screens (user 2026-09-28: "find pictures of our game or take
## pictures we have a lot of great scenes you can build"): each scene staged in the real level with the clips' staging
## (tools/showcase/clips.gd), the player driven as in play, and taken through the off-window view with no UI at all
## (no prompts, HUD or aim dot: the game's CanvasLayers are left out of the picture). Two or three takes a scene, a
## moment apart, to choose from.
##
##   Godot --path . --resolution 640x360 --fixed-fps 30 -s tools/menu/game_pictures.gd -- out=<dir> new_game \
##       size=1920x1080 [only=<id>,<id>] [wildlife=on birdlife=on]
##   <dir>/<scene>_<take>.png, <dir>/sheet.png
##
## The player is Actor_B animation data; the rest is the project's own or credited in CREDITS.md.

const PICTURES := ["fort_dawn", "torch_wall", "musket_smoke", "felling", "ride_dusk", "camp_night", "storm",
		"barrow", "cabin", "barricade", "forage", "perch", "river", "bow_evening", "dusk_meadow"]

var shots: Array[Image] = []


func _order() -> Array:
	return PICTURES


## The game's own UI stays out of the pictures.
func _redirect(_n: Node) -> void:
	pass


func _begin_segment() -> void:
	await super()


func _end_segment() -> void:
	recording = false
	aim_target = Vector3.INF
	for a in ["move_forward", "move_back", "move_left", "move_right", "sprint", "walk", "fire", "aim", "jump",
			"crouch", "reload", "interact", "grip", "torch"]:
		if InputMap.has_action(a):
			Input.action_release(a)
	held.clear()
	use_cine = false
	cam_fn = Callable()
	player.camera.current = true
	view.source = player.camera


func _write_log() -> void:
	if not shots.is_empty():
		_sheet(shots, out.path_join("sheet.png"), 4)


## The picture now (as the view shows it this frame).
func _shot(tag: String) -> void:
	await _frame()
	var img := view.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := out.path_join("%s_%s.png" % [cur_id, tag])
	img.save_png(path)
	shots.append(img)
	print("PICTURE ", path)


## A few takes `gap` s apart.
func _takes(n: int, gap: float) -> void:
	for i in n:
		await _shot(str(i + 1))
		if i < n - 1:
			await _warm(int(round(gap * fps)))


# --- the scenes ----------------------------------------------------------------------------------------------------

## The fort from the range lane at sunrise, the player walking home to the gate.
func seg_fort_dawn() -> void:
	_clock(6.4, "fair", 0.35)
	await _equip("musket")
	_place(0.4, -34.0, Vector3(0.0, 0.0, 0.0))
	_cam_at(Vector3(-22.0, _ground(-22.0, -52.0) + 7.5, -52.0), func() -> Vector3: return Vector3(2.0, 3.0, -8.0), 50.0, 20.0)
	await _warm(90)
	_press(&"walk")
	_press(&"move_forward")
	await _warm(40)
	await _takes(2, 0.6)
	_release(&"move_forward")
	_release(&"walk")
	_clock(7.2, "fair", 0.3)
	await _warm(60)
	await _shot("3")


## A raised torch by the palisade at dusk, the wall behind.
func seg_torch_wall() -> void:
	_clock(19.95, "clear", 0.0)
	await _equip("musket")
	var at := Vector3(19.2, 0.0, 6.0)
	_place(at.x, at.z, at + Vector3(10, 0, 0))
	if player.torch.count() < 2:
		player.torch.add_torches(2)
	await _warm(10)
	await _tap(&"torch")
	await _torch_in_hand()
	await _warm(10)
	await _tap(&"torch")
	await _warm(40)
	var p := player.global_position
	_cam_at(p + Vector3(3.4, 1.55, 1.9), func() -> Vector3: return player.global_position + Vector3(-0.3, 1.45, 0.0), 45.0, 20.0)
	await _warm(60)
	await _takes(2, 0.8)
	_cam_at(p + Vector3(2.6, 0.9, -2.8), func() -> Vector3: return player.global_position + Vector3(0.0, 1.6, 0.4), 50.0, 20.0)
	await _warm(30)
	await _shot("3")


## The musket fired at the range: the flash and the smoke, from the side.
func seg_musket_smoke() -> void:
	_clock(17.6, "fair", 0.2)
	var tgt := Vector3(2.5, 1.25, -70.0)
	_place(1.0, FrontierStructures.FIRING_LINE_Z - 1.3, tgt)
	await _equip("musket")
	aim_target = tgt
	aim_rate = 5.0
	_cam_rel(Vector3(-2.6, 1.45, -0.6), Vector3(0.6, 1.4, -2.0), 45.0, 20.0)
	await _warm(60)
	_press_ev(&"fire")
	await _warm(45)
	_release_ev(&"fire")
	var w := player.weapon as Firearm
	await _until(func() -> bool: return w.state != Firearm.State.AIMING, 3.0)
	await _warm(int(0.08 * fps))
	await _takes(3, 0.2)


## A maple coming down, seen across its fall.
func seg_felling() -> void:
	_clock(16.9, "fair", 0.2)
	var h := VegHarvest.find(self)
	var lt := _lone_tree(false)
	if lt.is_empty():
		return
	var tree := h.describe("tree", "tree", int(lt[0]))
	var tp: Vector3 = tree.pos
	var d := _fall_lane(tp, float(tree.height))
	var at := tp - d * (float(tree.radius) + 1.0)
	_place(at.x, at.z, tp)
	player.pitch = deg_to_rad(4.0)
	var gt: GatherTools = player.gather
	if gt.skills:
		gt.skills.set_points("woodcutting", 90.0)
	var side := d.cross(Vector3.UP).normalized()
	var cam := tp + side * 15.0 + d * 3.0
	cam.y = _ground(cam.x, cam.z) + 2.4
	_cam_at(cam, func() -> Vector3: return tp + d * 5.0 + Vector3.UP * 5.0, 55.0, 20.0)
	await _warm(30)
	await _tap(&"tool_axe")
	await _until(func() -> bool: return gt.phase == GatherTools.Phase.READY, 3.0)
	var felled := [null]
	gt.felled.connect(func(f: FelledTree) -> void: felled[0] = f, CONNECT_ONE_SHOT)
	_press(&"fire")
	await _until(func() -> bool: return felled[0] != null, 14.0)
	_release(&"fire")
	await _shot("1")
	await _warm(int(0.9 * fps))
	await _takes(2, 0.5)


## Riding at a canter in the evening light, from alongside.
func seg_ride_dusk() -> void:
	_clock(18.4, "fair", 0.2)
	var horse := _horse()
	if horse == null:
		return
	var lead := horse.get_node_or_null("Lead")
	if lead and lead.has_method("stop"):
		lead.stop()
	var hp := Vector3(-9.0, 0.0, -30.0)
	hp.y = _ground(hp.x, hp.z)
	horse.global_position = hp
	horse.look_at(hp + Vector3(0, 0, -1), Vector3.UP)
	horse.speed = 0.0
	await _warm(10)
	player.mount(horse)
	await _warm(80)
	player.yaw = horse.global_rotation.y
	_cam_rel(Vector3(4.6, 1.5, 0.6), Vector3(0.0, 1.3, -1.2), 50.0, 20.0, horse)
	_press(&"move_forward")
	await _warm(40)
	await _tap(&"sprint")
	await _warm(40)
	await _tap(&"sprint")
	await _warm(60)
	await _takes(3, 0.35)
	_release(&"move_forward")
	await _warm(60)
	player.dismount()
	await _warm(30)


## A campfire at night, the player crouched by it.
func seg_camp_night() -> void:
	_clock(21.3, "clear", 0.0)
	var fire_at := _ground_v(Vector3(24.0, 0, 14.0))
	var inv := InventoryState.from_player(player)
	inv.add("stone", 6)
	inv.add("firewood", 12)
	player.inventory_pack = inv.pack.duplicate(true)
	_place(fire_at.x + 1.5, fire_at.z + 0.9, fire_at)
	if not player.hands_free:
		player.toggle_hands_free()
	await _warm(60)
	var mode := player.get_node_or_null("BuildMode") as BuildMode
	if mode:
		mode.set_active(true)
		mode.select_type("campfire")
		mode.aim_at = fire_at
		await _warm(6)
		mode.refresh_placement()
		var fp := mode.place()
		mode.set_active(false)
		mode.aim_at = Vector3.INF
		var cf := fp.get_node_or_null("Campfire") as Campfire if fp else null
		if cf:
			cf.light()
			for k in 4:
				cf.add_wood(player)
			spawned.append(fp)
	await _tap(&"crouch")
	await _warm(60)
	_cam_at(fire_at + Vector3(-2.2, 0.9, 2.6), func() -> Vector3: return (fire_at + player.global_position) * 0.5 + Vector3.UP * 0.45, 50.0, 20.0)
	await _warm(40)
	await _takes(2, 0.5)
	await _tap(&"crouch")


## The storm front coming over the range, the player facing it.
func seg_storm() -> void:
	_clock(15.0, "fair", 0.3)
	var w := dn.weather
	dn.force_weather("storm")
	w.field.front.w = 1.0
	w.set("_front_strength", 1.0)
	w.kind_duration = 1.0e6
	_place(10.0, -44.0, Vector3(-40.0, 0.0, -100.0))
	await _equip("musket")
	var pos := player.global_position
	_storm_at(6.0, pos)
	var d2 := Vector2(w.field.front.x, w.field.front.y).normalized()
	_place(pos.x, pos.z, pos + Vector3(-d2.x, 0.0, -d2.y) * 100.0)
	player.pitch = deg_to_rad(10.0)
	_cam_rel(Vector3(1.2, 1.2, 3.6), Vector3(-0.2, 5.0, -14.0), 62.0, 20.0)
	await _warm(90)
	await _shot("1")
	_storm_at(2.0, pos)
	await _warm(60)
	await _shot("2")
	_storm_at(0.5, pos, true)
	await _warm(8)
	await _shot("3")
	dn.force_weather("fair")


## Home with a doe in the barrow, toward the fort in the late light.
func seg_barrow() -> void:
	_clock(17.2, "fair", 0.2)
	var w := Wheelbarrow.find(self)
	if w == null:
		return
	var way := Vector3(0.0, 0.0, 1.0)
	w.park_at(_ground_v(Vector3(2.0, 0, -46.0)), way)
	if not player.hands_free:
		player.toggle_hands_free()
	await _warm(50)
	var side := -w.global_basis.x
	side.y = 0.0
	side = side.normalized()
	var doe := WildAnimal.new()
	doe.setup("deer", null, null, 11)
	level.add_child(doe)
	spawned.append(doe)
	doe.global_position = _ground_v(w.bed_point() + side * 1.4)
	await _warm(3)
	doe.apply_hit(9999.0, doe.global_position + Vector3.UP * 0.6, Vector3.RIGHT, null, "vitals")
	await _skip(6.0)
	w.put_carcass(doe)
	await _warm(10)
	var fwd := w.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var g := w.grips_point()
	_place(g.x - fwd.x * 0.9, g.z - fwd.z * 0.9, w.bed_point())
	await _warm(10)
	w.start(player)
	await _warm(20)
	player.yaw = atan2(-way.x, -way.z) + PI
	_press(&"move_forward")
	await _warm(90)
	_cam_rel(Vector3(-3.6, 1.3, -2.4), Vector3(0.4, 0.8, 0.6), 48.0, 20.0)
	await _warm(60)
	await _takes(2, 0.5)
	_release(&"move_forward")
	await _warm(20)
	w.set_down("clip")


## A cabin by the fort in the evening, smoke from its chimney, the player at its door.
func seg_cabin() -> void:
	_clock(12.5, "fair", 0.25)
	var cabin := Vector3(24.0, 0.0, 2.0)
	var mode: BuildMode = player.building
	var inv := InventoryState.from_player(player)
	inv.add("log", 300)
	inv.add("stone", 200)
	inv.add("firewood", 10)
	player.inventory_pack = inv.pack.duplicate(true)
	_place(cabin.x + 4.0, cabin.z + 5.0, cabin)
	if not player.hands_free:
		player.toggle_hands_free()
	await _warm(60)
	var c := cabin + Vector3(0, _ground(cabin.x, cabin.z), 0)
	mode.set_active(true)
	var G := BuildGeometry
	var fl := await _build_piece(mode, "floor", c)
	if fl == null:
		mode.set_active(false)
		return
	var fo := fl.global_position
	var top := float(G.FLOOR_H)
	var walls := {}
	for sp: Array in [["wall", Vector3(1.3, 0, 0)], ["wall_window", Vector3(-1.3, 0, 0)], ["wall_door", Vector3(0, 0, 1.3)],
			["wall", Vector3(0, 0, -1.3)]]:
		walls[sp[1]] = await _build_piece(mode, String(sp[0]), fo + (sp[1] as Vector3) + Vector3(0, top, 0))
	for k: Vector3 in [Vector3(1.3, 0, 0), Vector3(-1.3, 0, 0)]:
		var wl: BuiltPiece = walls.get(k)
		if wl:
			await _build_piece(mode, "gable", wl.global_transform * Vector3(0, float(G.WALL_H) + 0.01, 0))
	await _build_piece(mode, "roof", fo + Vector3(0, top, 0))
	await _build_piece(mode, "hearth", fo + Vector3(2.3, 0, 0))
	mode.aim_at = Vector3.INF
	mode.set_active(false)
	for sp in level.find_children("*", "BuiltPiece", true, false):
		spawned.append(sp)
	var door: BuiltPiece = walls.get(Vector3(0, 0, 1.3))
	if door and door.door:
		door.door.set_open(true)
	for hf in level.find_children("*", "Campfire", true, false):
		if (hf as Node3D).global_position.distance_to(c) < 6.0:
			(hf as Campfire).light()
			for k in 3:
				(hf as Campfire).add_wood(player)
	_clock(18.7, "fair", 0.25)
	var door_at := fo + Vector3(0, 0, 2.4)
	_place(door_at.x + 0.8, door_at.z + 0.6, door_at + Vector3(4, 0, 6))
	await _warm(60)
	_cam_at(c + Vector3(7.5, 2.1, 8.0), func() -> Vector3: return c + Vector3(0.5, 1.9, 0.5), 50.0, 20.0)
	await _warm(60)
	await _shot("1")
	_cam_at(c + Vector3(-4.5, 1.6, 9.0), func() -> Vector3: return c + Vector3(0.8, 1.7, 0.8), 45.0, 20.0)
	await _warm(40)
	await _shot("2")


## Aiming over a log barricade on the range lane, from in front of it.
func seg_barricade() -> void:
	_clock(17.4, "fair", 0.2)
	await _equip("musket")
	var lp = player.log_pull
	var at := _ground_v(Vector3(-3.0, 0.0, -112.0))
	var ax := Vector3(1, 0, 0)
	var side := Vector3(0, 0, 1)
	var logs: Array = []
	for k in 2:
		var lg := _loose_log(at + side * (0.0 if k == 0 else 0.6), ax, 2.4, 0.22, 10 + k)
		await _warm(40)
		_place(lg.front.x - 0.9, lg.front.z, lg.front)
		await _warm(10)
		lp.start(lg, 0)
		await _warm(130)
		lp.stack_on = lp._find_stack()
		lp.lay()
		await _warm(80)
		logs.append(lg)
	var mid: Vector3 = logs[0].mid()
	_place(mid.x, mid.z + 0.9, mid - side * 20.0)
	player.pitch = deg_to_rad(-3.0)
	_press_ev(&"aim")
	await _warm(60)
	_cam_at(mid - side * 3.6 + ax * 1.3 + Vector3.UP * 0.7, func() -> Vector3: return mid + Vector3.UP * 1.0 + side * 0.6, 50.0, 20.0)
	await _warm(50)
	await _shot("1")
	_release_ev(&"aim")
	await _tap(&"crouch")
	await _warm(50)
	await _shot("2")
	await _tap(&"crouch")


## Picking blackberries at the clearing's edge, close.
func seg_forage() -> void:
	_clock(10.2, "fair", 0.2)
	var f := ForageField.find(self)
	if f == null:
		return
	var best := -1
	var bd := INF
	for i in f.patches.size():
		if f.patches[i].kind != "blackberry":
			continue
		var dd := Vector2(f.patches[i].pos.x, f.patches[i].pos.z).length()
		if dd < bd:
			bd = dd
			best = i
	if best < 0:
		return
	var pl: Dictionary = f.patches[best].plants[0]
	for q in f.patches[best].plants:
		if float(q.stock) > 0.0:
			pl = q
			break
	var pp: Vector3 = pl.pos
	var out_dir := Vector3(-pp.x, 0.0, -pp.z).normalized()
	var at := pp + out_dir * 1.0
	_place(at.x, at.z, pp)
	player.pitch = deg_to_rad(-20.0)
	if not player.hands_free:
		player.toggle_hands_free()
	await _warm(50)
	var side := out_dir.cross(Vector3.UP).normalized()
	_cam_at(at + side * 1.9 + out_dir * 0.9 + Vector3.UP * 1.0, func() -> Vector3: return (at + pp) * 0.5 + Vector3.UP * 0.75, 42.0, 20.0)
	await _warm(30)
	await _tap(&"interact")
	await _warm(int(1.1 * fps))
	await _takes(2, 0.7)


## Crouched on a branch high in a tree, seen from out in the open.
func seg_perch() -> void:
	_clock(16.4, "fair", 0.2)
	var t := _lone_tree(true)
	if t.is_empty():
		return
	var axis: Vector3 = t[1]
	var radius: float = clampf(float(t[2]) * 0.92, 0.1, 0.75)
	var to_open := (Vector3.ZERO - axis)
	to_open.y = 0.0
	to_open = to_open.normalized()
	var at := axis + to_open * (radius + 0.55)
	_place(at.x, at.z, axis)
	player.pitch = deg_to_rad(8.0)
	await _warm(30)
	var g: PlayerGrip = player.grip
	g.climb_up()                     # E up the tree (TreeClimb; user 2026-10-03: branch to branch): the shinny up its trunk
	await _until(func() -> bool: return g.perched, 18.0)
	await _warm(90)
	var pp := player.global_position
	var side := to_open.cross(Vector3.UP).normalized()
	_cam_at(pp + to_open * 5.5 + side * 2.0 + Vector3.UP * 0.6, func() -> Vector3: return player.global_position + Vector3.UP * 0.6, 50.0, 20.0)
	await _warm(40)
	await _shot("1")
	_cam_at(axis + to_open * 11.0 + side * 3.0 + Vector3(0, 1.7 - axis.y + _ground(axis.x + to_open.x * 11.0, axis.z + to_open.z * 11.0), 0),
			func() -> Vector3: return player.global_position, 45.0, 20.0)
	await _warm(40)
	await _shot("2")
	await _tap(&"jump", 0.5)
	await _warm(60)


## The river east of the fort at its first rapid, the player on the bank.
func seg_river() -> void:
	_clock(9.6, "fair", 0.25)
	var rs := WorldRiver.rapids()
	if rs.is_empty() or not WorldRiver.has_water():
		print("PICTURES: no river")
		return
	var z := float(rs[0].z)
	var x := WorldRiver.x_at(z)
	var bank := WorldRiver.bank() + 2.5
	var stand := Vector3(x - bank, 0.0, z + 4.0)
	await _equip("musket")
	_place(stand.x, stand.z, Vector3(x, 0.0, z - 6.0))
	await _warm(240)                      # (the square's ground streaming in)
	_place(stand.x, stand.z, Vector3(x, 0.0, z - 6.0))
	print("PICTURES river at x %.1f z %.1f level %.2f ground %.2f" % [x, z, WorldRiver.level_at(z), _ground(stand.x, stand.z)])
	var cam := Vector3(x - bank - 3.5, 0.0, z + 11.0)
	cam.y = _ground(cam.x, cam.z) + 2.2
	_cam_at(cam, func() -> Vector3: return Vector3(x, WorldRiver.level_at(z) + 0.6, z - 4.0), 55.0, 20.0)
	await _warm(60)
	await _shot("1")
	_clock(17.8, "fair", 0.25)
	await _warm(60)
	await _shot("2")


## Drawing the bow at the range's edge in the evening.
func seg_bow_evening() -> void:
	_clock(18.1, "fair", 0.15)
	var tgt := Vector3(0.0, 1.3, -45.0)
	_place(-1.0, FrontierStructures.FIRING_LINE_Z - 1.3, tgt)
	await _equip("bow")
	aim_target = tgt
	aim_rate = 5.0
	_cam_rel(Vector3(2.2, 1.35, -1.6), Vector3(-0.3, 1.45, 0.2), 45.0, 20.0)
	await _warm(50)
	_press(&"fire")
	await _warm(int(1.6 * fps))
	await _takes(2, 0.4)
	_release(&"fire")
	await _warm(40)


## Dusk over the meadow, the first stars and the fireflies.
func seg_dusk_meadow() -> void:
	_clock(20.2, "clear", 0.0)
	var m := Vector3(20.0, 0.0, -110.0)
	await _equip("musket")
	_place(m.x, m.z, Vector3(24.0, 0.0, -125.0))
	await _skip(3.0)
	var cam := Vector3(17.0, _ground(17.0, -101.0) + 1.4, -101.0)
	_cam_at(cam, func() -> Vector3: return Vector3(22.0, cam.y + 1.2, -126.0), 60.0, 20.0)
	await _warm(80)
	await _shot("1")
	_clock(20.6, "clear", 0.0)
	await _warm(60)
	await _shot("2")
