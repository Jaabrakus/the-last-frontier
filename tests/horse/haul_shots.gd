extends SceneTree
## Windowed screenshots of log skidding and leading a horse (needs a window, not --headless), in the Frontier
## level with the real player riding:
##   drag_side.png   a felled tree's bole on the chain behind the ridden horse, from the side
##   drag_rear.png   the same from behind and above the log
##   harness.png     close up: breast strap, traces, singletree, chain, choker
##   turn.png        on a turn, from above: the log cutting the corner behind
##   play.png        the gameplay camera while hauling
##   unhitched.png   the bole lying loose after unhitching
##   lead.png        leading the horse on foot (the lead rope from the bit to the hand)
##   bundle.png      a bundle of logs from the pack on the chain
##   pile.png        the bundle laid down as a pile
##   carcass_*.png   (what=carcass [species=stag|deer|wolf|fox] [wildlife=on]) a dead animal on a rope behind the
##                   ridden horse: the prompt at its neck, from the side, the rope and the collar, the gameplay
##                   camera, a turn from above, let go, and the Skin prompt where it lies
##   sheet.png       all of them in one contact sheet
##
##   Godot --path . --resolution 1280x720 -s tests/horse/haul_shots.gd -- out=/abs/dir [hour=11] [what=...]
##
## The horse, the harness and the logs are the project's own; the animals are Quaternius's CC0 stand-in models
## (assets/wildlife/quaternius/SOURCE.md).

const CELL := Vector2i(640, 360)

var args := {}
var out := ""
var player: FrontierPlayer
var horse: Horse
var haul: HorseHaul
var lead: HorseLead
var shots: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	out = String(args.get("out", "user://haul_shots"))
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
	var hs := current_scene.find_children("*", "Horse", true, false)
	horse = hs[0]
	haul = horse.get_node("Haul")
	lead = horse.get_node("Lead")
	var what: PackedStringArray = String(args.get("what", "drag,lead,bundle")).split(",")
	if "drag" in what:
		await _drag()
	if "lead" in what:
		await _lead()
	if "bundle" in what:
		await _bundle()
	if "carcass" in what:
		await _carcass()
	_sheet()
	print("SHOTS DONE ", out)
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _phys(n: int) -> void:
	for i in n:
		await physics_frame


func _put_player(at: Vector3, look_at: Vector3) -> void:
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.05
	player.global_position = at
	player.velocity = Vector3.ZERO
	var d := look_at - at
	d.y = 0.0
	player.yaw = atan2(-d.x, -d.z)
	player.rotation.y = player.yaw
	player.pitch = deg_to_rad(-12.0)


func _look(from: Vector3, at: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at(at - from, Vector3.UP), from)


## Renders the frozen scene from `cam_xf` (null: the gameplay camera); saves <name>.png and keeps a cell.
func _shot(name: String, cam_xf: Variant, fov := 45.0) -> void:
	paused = true
	var cam: Camera3D = null
	if cam_xf is Transform3D:
		cam = Camera3D.new()
		cam.fov = fov
		cam.far = 800.0
		current_scene.add_child(cam)
		cam.global_transform = cam_xf
		cam.current = true
	await _frames(3)
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	if cam:
		cam.queue_free()
		player.camera.current = true
	paused = false
	img.save_png(out.path_join(name + ".png"))
	var cell := img.duplicate() as Image
	cell.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
	shots.append(cell)
	print("saved ", name)


func _sheet() -> void:
	var cols := 3
	var rows := ceili(shots.size() / float(cols))
	var grid := Image.create(CELL.x * cols, CELL.y * rows, false, Image.FORMAT_RGB8)
	for i in shots.size():
		grid.blit_rect(shots[i], Rect2i(Vector2i.ZERO, CELL), Vector2i((i % cols) * CELL.x, (i / cols) * CELL.y))
	grid.save_png(out.path_join("sheet.png"))


## A tree near the spawn, off the fort, with open ground ahead of where it falls.
func _fell_tree() -> FelledTree:
	var gt := player.gather
	var vh := VegHarvest.find(self)
	var want := int(args.get("tree", "-1"))
	var best := want
	if best < 0:
		var best_d := INF
		for i in vh.lay.tree_pos.size():
			if int(vh.lay.tree_kind[i]) >= VegHarvest.Assets.CANOPY_COUNT or vh.lay.tree_collider[i] == 0:
				continue
			var p: Vector3 = vh.lay.tree_pos[i]
			if absf(p.x) < 26.0 and absf(p.z) < 26.0:
				continue
			var d := vh.describe("tree", "tree", i)
			if d.is_empty() or String(d.species) != "white_pine" or float(d.radius) > 0.32 or float(d.radius) < 0.24:
				continue
			var dist := Vector2(p.x - player.global_position.x, p.z - player.global_position.z).length()
			if dist < best_d:
				best_d = dist
				best = i
	var desc := vh.describe("tree", "tree", best)
	print("tree %d: %s r %.2f h %.1f" % [best, desc.species, desc.radius, desc.height])
	var felled := [null]
	gt.felled.connect(func(ft: FelledTree) -> void: felled[0] = ft)
	# fell it away from the fort (toward open ground outward)
	var outward := Vector3(desc.pos.x, 0, desc.pos.z).normalized()
	_put_player(desc.pos - outward * 1.3, desc.pos)
	await _phys(3)
	gt._fell(desc)
	var ft: FelledTree = felled[0]
	for i in 120 * 10:
		await physics_frame
		if ft.is_down():
			break
	var logs := int(args.get("logs", "3"))
	while (not HorseHaul.can_start(haul.mass_of(ft)) or ft.logs_left > logs) and ft.logs_left > 1:
		ft.buck(ft.cut_work)
	await _phys(60)
	# into the open for the pictures: the fort's clearing, where the trunks do not hide it
	var spot := _open_spot(vh)
	if spot != Vector3.INF:
		ft.hinge = spot + Vector3.UP * float(ft.info.get("radius", 0.3))
		ft._apply_pose()
		print("moved to the open at ", spot)
	await _phys(10)
	return ft


## A gentle spot 28-90 m from the fort's middle with no trunk within 13 m and nothing else standing within
## 12 m (the range's targets and bales) (INF: none found).
func _open_spot(vh: VegHarvest) -> Vector3:
	var best := Vector3.INF
	var best_s := INF
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 12.0
	q.shape = sph
	var space := player.get_world_3d().direct_space_state
	for k in 600:
		var a := k * 2.39996
		var r := 28.0 + float(k % 30) * 2.1
		var p := Vector3(cos(a) * r, 0.0, sin(a) * r)
		if absf(p.x) < 30.0 and absf(p.z) < 30.0:
			continue
		var clear := true
		for i in vh.lay.tree_pos.size():
			var t: Vector3 = vh.lay.tree_pos[i]
			if absf(t.x - p.x) < 13.0 and absf(t.z - p.z) < 13.0 and Vector2(t.x - p.x, t.z - p.z).length() < 13.0:
				clear = false
				break
		if not clear:
			continue
		q.transform = Transform3D(Basis(), Vector3(p.x, FrontierTerrain.height_at(p.x, p.z) + 1.0, p.z))
		for hit: Dictionary in space.intersect_shape(q, 16):
			var col := hit.collider as Node
			if col is StaticBody3D and not col.is_in_group(&"terrain"):
				clear = false
				break
		if not clear:
			continue
		var h0 := FrontierTerrain.height_at(p.x, p.z)
		var slope := absf(FrontierTerrain.height_at(p.x + 4.0, p.z) - h0) + absf(FrontierTerrain.height_at(p.x, p.z + 4.0) - h0)
		if slope < best_s:
			best_s = slope
			best = Vector3(p.x, h0, p.z)
	return best


func _drag() -> void:
	var ft := await _fell_tree()
	# the horse's hindquarters by the butt, facing away from the top
	var away := -Vector3(ft.axis().x, 0, ft.axis().z).normalized()
	var hpos := ft.hinge + away * (Horse.HITCH_BACK + 2.3)
	hpos.y = FrontierTerrain.height_at(hpos.x, hpos.z)
	horse.global_position = hpos
	horse.look_at(hpos + away, Vector3.UP)
	horse.speed = 0.0
	await _phys(30)
	var s := haul.hitch_tree(ft, 0, player)
	print("hitched: %s %.1f m %.0f kg" % [s.load_name(), s.length, s.mass_kg])
	player.mount(horse)
	await _phys(120)
	player.yaw = horse.rotation.y
	Input.action_press(&"move_forward")
	# ride on; caught on a trunk, turn the horse (as the notice says) until the log comes free
	var turning := false
	var moved0 := horse.global_position
	for i in 120 * int(args.get("ride_s", "10")):
		await physics_frame
		if haul.jam_t > 0.4 and not turning:
			turning = true
			Input.action_press(&"move_right")
		elif turning and haul.jam_t <= 0.0:
			turning = false
			Input.action_release(&"move_right")
		if i % 60 == 0:
			print("t=%.1f v=%.2f cap=%.2f jam=%.2f stretch=%.2f pull=%.0f dist %.2f turning %s" % [i / 120.0, horse.speed, haul.cap, haul.jam_t,
					s.stretch, s.pull_kgf, s.front.distance_to(horse.get_hitch_point()), turning])
	Input.action_release(&"move_right")
	print("rode %.1f m with the log" % (horse.global_position - moved0).length())
	var mid := (horse.global_position + s.back) * 0.5
	var side := horse.global_basis.x
	await _shot("drag_side", _look(mid + side * 10.0 + Vector3.UP * 2.0, mid + Vector3.UP * 0.8), 55.0)
	var back := -s.axis()
	await _shot("drag_rear", _look(s.back - back * 4.0 + side * 1.5 + Vector3.UP * 3.2, horse.global_position + Vector3.UP * 0.8), 50.0)
	var hp := horse.get_hitch_point()
	await _shot("harness", _look(hp + horse.global_basis.z * 2.2 + side * 1.6 + Vector3.UP * 1.1, hp + Vector3.UP * 0.25 - horse.global_basis.z * 0.3), 50.0)
	await _shot("play", null)
	# a turn to the left
	Input.action_press(&"move_left")
	await _phys(int(120 * 2.6))
	var c := (horse.global_position + s.back) * 0.5
	await _shot("turn", _look(c + Vector3.UP * 13.0 + horse.global_basis.z * 3.0, c), 55.0)
	Input.action_release(&"move_left")
	Input.action_release(&"move_forward")
	await _phys(120 * 3)
	haul.unhitch()
	await _phys(120)
	mid = (s.front + s.back) * 0.5
	await _shot("unhitched", _look(mid + horse.global_basis.x * 5.0 + Vector3.UP * 2.2 + horse.global_basis.z * 2.0, mid), 50.0)
	Input.action_press(&"interact")
	await _phys(80)
	Input.action_release(&"interact")
	await _phys(30)


func _lead() -> void:
	var fwd := -horse.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	_put_player(lead.bit_point() + fwd * 1.2, lead.bit_point())
	await _phys(3)
	lead.start(player)
	# walk off ahead of it
	_put_player(player.global_position, player.global_position + fwd)
	Input.action_press(&"walk")
	Input.action_press(&"move_forward")
	await _phys(120 * 5)
	var side := horse.global_basis.x
	var c := (horse.global_position + player.global_position) * 0.5
	await _shot("lead", _look(c + side * 6.5 + Vector3.UP * 1.8 + fwd * 1.0, c + Vector3.UP * 1.0), 50.0)
	if args.has("debug_near"):
		for n in current_scene.find_children("*", "GeometryInstance3D", true, false):
			var gi := n as GeometryInstance3D
			if gi.is_visible_in_tree() and gi.global_position.distance_to(player.global_position + fwd * 1.5 + Vector3.UP) < 2.5:
				print("near: ", gi.get_path(), " ", gi.get_class(), " ", gi.global_position)
	Input.action_release(&"move_forward")
	Input.action_release(&"walk")
	await _phys(120 * 3)


func _bundle() -> void:
	player.gather.give("log", 6)
	lead.stop()
	await _phys(10)
	var s := haul.hitch_pack(player)
	if s == null:
		print("no bundle")
		return
	await _phys(60)
	lead.start(player)
	var fwd := -horse.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	_put_player(horse.global_position + fwd * 3.2, horse.global_position + fwd * 10.0)
	Input.action_press(&"walk")
	Input.action_press(&"move_forward")
	await _phys(120 * 5)
	Input.action_release(&"move_forward")
	Input.action_release(&"walk")
	await _phys(120 * 2)
	var side := horse.global_basis.x
	var mid := (s.front + s.back) * 0.5
	await _shot("bundle", _look(mid + side * 4.5 + Vector3.UP * 1.8 + horse.global_basis.z * 2.5, mid + Vector3.UP * 0.4), 50.0)
	var pile := haul.unhitch()
	await _phys(30)
	if pile:
		var pc := pile.global_transform * Vector3(0, 1.2, 0.2)
		await _shot("pile", _look(pc + side * 3.5 + Vector3.UP * 1.6 + horse.global_basis.z * 1.5, pc), 50.0)


func _carcass() -> void:
	var sp := String(args.get("species", "stag"))
	var w := current_scene.get_node_or_null("Wildlife") as WildlifeSpawner
	var a: WildAnimal = null
	if w:
		for x in w.animals():
			if x.species == "wolf":
				x.global_position = Vector3(285.0, FrontierTerrain.height_at(285.0, 285.0), 285.0)
				x.awareness = 0.0
			elif x.species == sp and a == null and not x.is_dead():
				a = x
	if a == null:
		a = WildAnimal.new()
		a.setup(sp, null, null, 5)
		current_scene.add_child(a)
	var spot := _open_spot(VegHarvest.find(self))
	if spot == Vector3.INF:
		spot = Vector3(0, 0, 40)
	var out_dir := Vector3(spot.x, 0.0, spot.z).normalized()
	# the horse in the open facing out, the animal behind it with its head toward it
	var hpos := spot - out_dir * 6.0
	hpos.y = FrontierTerrain.height_at(hpos.x, hpos.z)
	lead.stop()
	horse.global_position = hpos
	horse.look_at(hpos + out_dir, Vector3.UP)
	horse.speed = 0.0
	await _phys(20)
	var back := -out_dir
	var at := horse.get_hitch_point() + back * 2.6
	at.y = FrontierTerrain.height_at(at.x, at.z)
	a.global_position = at
	a.rotation.y = atan2(back.x, back.z)
	a._yaw = a.rotation.y
	a.set_active(true)
	await _phys(2)
	a.apply_hit(9999.0, a.global_position + Vector3.UP * 0.6, Vector3.RIGHT, player, "vitals")
	await _phys(int(1.8 * 120))
	var side := back.cross(Vector3.UP).normalized()
	var neck := CarcassLoad.neck_point(a)
	_put_player(neck + side * 1.6 - back * 0.3, neck)
	await _phys(12)
	await _shot("carcass_prompt", null)
	var s := haul.hitch_carcass(a)
	if s == null:
		print("no carcass load")
		return
	print("roped: %s %.0f kg, %.2f m neck to rump" % [s.load_name(), s.mass_kg, s.length])
	player.mount(horse)
	await _phys(120)
	player.yaw = horse.rotation.y
	Input.action_press(&"move_forward")
	await _phys(120 * int(args.get("ride_s", "7")))
	var hs := horse.global_basis.x
	var mid := (horse.global_position + s.back) * 0.5
	await _shot("carcass_side", _look(mid + hs * 8.0 + Vector3.UP * 1.8, mid + Vector3.UP * 0.7), 55.0)
	var hp := horse.get_hitch_point()
	var c := (hp + s.front) * 0.5
	await _shot("carcass_rope", _look(c + hs * 2.6 + horse.global_basis.z * 1.2 + Vector3.UP * 1.3, c + Vector3.DOWN * 0.2), 50.0)
	var col: Node3D = s.get_node_or_null("Collar")
	if col:
		var co := col.global_position
		print("collar at %s r %.3f, neck %s, rope end %s" % [co, s._collar_r, CarcassLoad.neck_point(a), s.chain_point()])
		await _shot("carcass_collar", _look(co + hs * 1.1 + Vector3.UP * 0.7 - horse.global_basis.z * 0.4, co), 45.0)
	await _shot("carcass_play", null)
	Input.action_press(&"move_left")
	await _phys(int(120 * 2.4))
	var tc := (horse.global_position + s.back) * 0.5
	await _shot("carcass_turn", _look(tc + Vector3.UP * 11.0 + horse.global_basis.z * 3.0, tc), 55.0)
	Input.action_release(&"move_left")
	Input.action_release(&"move_forward")
	await _phys(120 * 3)
	haul.unhitch()
	await _phys(60)
	var body := a.interact_point()
	await _shot("carcass_down", _look(body + hs * 3.6 + Vector3.UP * 1.9 + horse.global_basis.z * 1.5, body), 50.0)
	Input.action_press(&"interact")
	await _phys(80)
	Input.action_release(&"interact")
	await _phys(60)
	_put_player(body + hs * 1.6, body)
	await _phys(12)
	await _shot("carcass_skin", null)
