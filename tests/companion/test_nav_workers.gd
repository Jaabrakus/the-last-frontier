extends SceneTree
## PATHS in the level (NavWorld + NavMover): the household's bodies walk the navigation mesh baked at run time.
##   bake     the tiles round home are in soon after the level loads (gather on the main thread, bake on a worker thread: timed);
##            a piece built in the yard and a felled tree bake their tiles again, and the new path goes round the piece;
##   worker   from inside the cabin (its door shut: she opens it, it swings shut behind her) out of the yard through the gate to
##            a woods spot ~40 m out among trees, arriving in time with no jump; back through the gate into the storehouse (its
##            door shut too) and out of it again (shut behind her); into the cabin through the door the player opened (left
##            open: only the doors a walker opened are shut again); from outside the east palisade round it to the west;
##   recruit  a visitor (RecruitBody) at the same time walking from outside the east palisade into the yard: round and in by the
##            gate on the mesh, with no step-through;
##   rebake   the main thread's share: a frame's worst time with a rebake under way against one without, the server's own step;
##   child    a child following its mother the same route (cabin -> woods -> storehouse): it keeps up, with no teleport.
##   Godot --headless --fixed-fps 120 --path . -s tests/companion/test_nav_workers.gd -- survival=on
## (windowed with out=<abs dir>: shots of the walk and of the mesh overlay.)
var player: FrontierPlayer
var h: Household
var nav_w: NavWorld
var fails := 0
var out := ""
var cam: Camera3D

var _target := Vector3.ZERO
var _speed := Spouse.WALK_SPEED
var _driving := false
var _arrived := false
## Walk records: the worst jump in one frame, the gate crossings (x where z = -16 was crossed), the child's worst lag.
var _max_step := 0.0
var _gate_x: Array[float] = []
var _child_step := 0.0
var _last := Vector3.INF
var _child_last := Vector3.INF


func _expect(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		fails += 1


func _initialize() -> void:
	Sharpness.slips_on = false   # (exact planning and paths: no tired slips here; tests/companion/test_sharpness.gd has them)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.get_slice("=", 1)
	InputSetup.ensure()
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _shot(name: String, at: Vector3, from: Vector3) -> void:
	if out == "" or DisplayServer.get_name() == "headless":
		return
	if cam == null:
		cam = Camera3D.new()
		current_scene.add_child(cam)
	cam.current = true
	cam.global_position = from
	cam.look_at(at, Vector3.UP)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("saved ", name)


## The errand that walks her (it comes before her work and chores): to _target by walk_to, until there.
func _errand(_dt: float) -> Variant:
	if not _driving:
		return null
	var b := h.body
	var to := _target - b.global_position
	to.y = 0.0
	if to.length() < Spouse.ARRIVE:
		_arrived = true
		return [Vector3.ZERO, 0.0]
	return b.walk_to(_target, _speed)


func _place(n: Node3D, at: Vector3) -> void:
	n.global_position = at + Vector3.UP * 0.1
	(n as CharacterBody3D).velocity = Vector3.ZERO


## Walks her to `to` within `limit_s` seconds; returns the seconds taken (INF: not there). `kid`: a child to watch too.
func _walk(to: Vector3, limit_s: float, kid: ChildBody = null) -> float:
	var b := h.body
	_target = to
	_arrived = false
	_driving = true
	_last = b.global_position
	_child_last = kid.global_position if kid != null else Vector3.INF
	var t := 0.0
	var frames := int(limit_s * Engine.physics_ticks_per_second)
	var prev_z := b.global_position.z
	var cb := Callable(self, "_errand")
	for i in frames:
		await physics_frame
		if b.errand != cb:
			b.errand = cb   # (BabyLink clears the errand each tick when there is no baby: set again before her step)
		t += 1.0 / Engine.physics_ticks_per_second
		var p := b.global_position
		_max_step = maxf(_max_step, p.distance_to(_last))
		_last = p
		if (prev_z + 16.0) * (p.z + 16.0) < 0.0:
			_gate_x.append(p.x)
		prev_z = p.z
		if kid != null:
			_child_step = maxf(_child_step, kid.global_position.distance_to(_child_last))
			_child_last = kid.global_position
		if i % 600 == 0:
			print("  t %.0f s at %s, %.1f m to go, nav %s %s, path %d pts, tiles %d ready %d baking" % [t, p, Vector2(to.x - p.x, to.z - p.z).length(),
					b.nav.status, b.nav.reason, b.nav.path.size(), nav_w.ready_count(), nav_w.baking()], " ready here ", nav_w.ready_at(p), " there ", nav_w.ready_at(to), " iter ", nav_w.iteration(), " tile in ", nav_w.synced_at(p), " on_path ", b.nav.on_path, " driving ", _driving)
		if _arrived:
			break
	_driving = false
	return t if _arrived else INF


## The worst frame (ms of wall time from one physics frame to the next) over `n` frames.
func _worst_frame(n: int) -> float:
	var worst := 0.0
	var tf := Time.get_ticks_usec()
	for i in n:
		await physics_frame
		worst = maxf(worst, (Time.get_ticks_usec() - tf) / 1000.0)
		tf = Time.get_ticks_usec()
	return worst


## Waits for a kid to come up to its mother (within `r` m) and stop there (half a second standing), up to `limit_s`; returns the
## distance left.
func _catch_up(kid: ChildBody, r: float, limit_s: float) -> float:
	var still := 0
	for i in int(limit_s * Engine.physics_ticks_per_second):
		await physics_frame
		_child_step = maxf(_child_step, kid.global_position.distance_to(_child_last))
		var moved := Vector2(kid.global_position.x - _child_last.x, kid.global_position.z - _child_last.z).length()
		_child_last = kid.global_position
		still = still + 1 if moved < 0.002 else 0
		if kid.global_position.distance_to(h.body.global_position) <= r and still > Engine.physics_ticks_per_second / 2:
			break
	return kid.global_position.distance_to(h.body.global_position)


## A woods spot among trees: ~40 m from home, outside the palisade, on the mesh, the most trunks within 8 m.
func _woods_spot() -> Vector3:
	var v := current_scene.get_node("Vegetation") as FrontierVegetation
	var best := Vector3.INF
	var best_n := -1
	for k in 72:
		var a := TAU * k / 72.0
		for r: float in [38.0, 41.0, 44.0]:
			var p := h.home + Vector3(cos(a), 0.0, sin(a)) * r
			if absf(p.x) < 20.0 and absf(p.z) < 20.0:
				continue
			p.y = FrontierTerrain.height_at(p.x, p.z)
			if not nav_w.ready_at(p):
				continue
			var q := nav_w.snap(p)
			if Vector2(q.x - p.x, q.z - p.z).length() > 0.3:
				continue
			var n := 0
			for i in v.layout.tree_pos.size():
				if v.layout.tree_collider[i] != 0 and Vector2(v.layout.tree_pos[i].x - p.x, v.layout.tree_pos[i].z - p.z).length() < 8.0:
					n += 1
			if n > best_n:
				best_n = n
				best = q
	print("woods spot ", best, " with ", best_n, " trunks within 8 m, ", best.distance_to(h.home), " m from home")
	return best


func _door_of(name: String) -> BuildDoor:
	var st := current_scene.get_node("Structures") as FrontierStructures
	return st.doors.get(name) as BuildDoor if st != null else null


func _run() -> void:
	var t_start := Time.get_ticks_msec()
	await _frames(20)
	player = current_scene.get_node("Player") as FrontierPlayer
	player.ignore_mouse_capture = true
	for c in root.find_children("*", "CharacterCreator", true, false):
		if c.has_method("close"):
			c.close()
	paused = false
	for i in 600:
		await physics_frame
		h = Household.find(self)
		if h != null and h.body != null:
			break
	_expect(h != null and h.body != null, "the household and the wife's body are in (survival=on)")
	if h == null or h.body == null:
		quit(1)
		return
	nav_w = NavWorld.of(self)
	_expect(nav_w != null and h.body.nav != null and h.body.nav.world == nav_w, "the wife walks on the level's NavWorld")
	player.global_position = Vector3(3.0, 0.1, 12.0)   # out of the way, in the yard
	# ---- bake: the tiles round home
	var t0 := Time.get_ticks_msec()
	var home_tiles := 0
	for i in 20 * 120:
		await physics_frame
		home_tiles = 0
		var hk := NavWorld.key_of(h.home)
		for dz in range(-NavWorld.HOME_RING, NavWorld.HOME_RING + 1):
			for dx in range(-NavWorld.HOME_RING, NavWorld.HOME_RING + 1):
				var t: Variant = nav_w.tiles.get(hk + Vector2i(dx, dz))
				if t != null and t.state == "ready":
					home_tiles += 1
		if home_tiles >= 25 and nav_w.baking() == 0:
			break
	var wait_ms := Time.get_ticks_msec() - t0
	var st := nav_w.stats
	var n := maxi(int(st.baked), 1)
	print("slowest gather: ", st.get("gather_worst", {}))
	print("bake: %d tiles in, the home's 25 within %d ms of the body (level up %d ms); gather avg %.2f ms max %.2f ms (main thread); bake avg %.0f ms max %.0f ms (worker thread); last %s" % [
			int(st.baked), wait_ms, t0 - t_start, float(st.gather_ms) / n, float(st.gather_max), float(st.bake_ms) / n, float(st.bake_max), st.last])
	_expect(home_tiles >= 25, "the 5 x 5 tiles round home are baked (%d)" % home_tiles)
	_expect(float(st.gather_max) < 30.0, "a tile's geometry is gathered in under 30 ms on the main thread (max %.1f)" % float(st.gather_max))
	_expect(float(st.bake_ms) / n < 2000.0, "a tile bakes in under 2 s on average off the main thread (%.0f ms)" % (float(st.bake_ms) / n))
	_expect(wait_ms < 25000, "the home's tiles are in within 25 s (%d ms)" % wait_ms)
	# the tiles join edge to edge: a short walk across the seam at x = 0 in the yard is short (it went 20 m round by an edge
	# connection when the tiles' voxel heights were off by a part of a cell)
	var sp := nav_w.path(nav_w.snap(Vector3(1.5, 0.0, 4.0)), nav_w.snap(Vector3(-2.3, 0.0, 3.7)))
	var sl := 0.0
	for i in range(1, sp.size()):
		sl += sp[i - 1].distance_to(sp[i])
	_expect(sp.size() >= 2 and sl < 5.0, "across a tile seam in the yard: a 3.8 m walk has a %.1f m path" % sl)
	var conns := 0
	for k: Vector2i in nav_w.tiles:
		if (nav_w.tiles[k].region as RID).is_valid():
			conns += NavigationServer3D.region_get_connections_count(nav_w.tiles[k].region)
	# (separately baked tiles join by the server's edge connections: that is how a tiled mesh is meant to join; what matters is
	# that a path across any seam round home goes straight across it, not round)
	print("  tile edge connections: %d" % conns)
	var seam_worst := 0.0
	var seams := 0
	for sx: float in [-32.0, 0.0, 32.0]:
		for sz: float in [-24.0, -8.0, 8.0, 24.0]:
			var a := nav_w.snap(Vector3(sx + 1.6, 0.0, sz))
			var b := nav_w.snap(Vector3(sx - 1.6, 0.0, sz))
			if a.distance_to(Vector3(sx + 1.6, a.y, sz)) > 0.5 or b.distance_to(Vector3(sx - 1.6, b.y, sz)) > 0.5:
				continue          # (a tree or a building there: no open ground on both sides)
			var pp := nav_w.path(a, b)
			var pl := 0.0
			for i in range(1, pp.size()):
				pl += pp[i - 1].distance_to(pp[i])
			if pp.size() >= 2:
				seams += 1
				seam_worst = maxf(seam_worst, pl / maxf(a.distance_to(b), 0.01))
	_expect(seams >= 4 and seam_worst < 1.5, "across %d tile seams round home the paths go straight across (seam_worst %.2f x the straight line)" % [seams, seam_worst])
	if out != "":
		nav_w.show_debug(true)
		await _shot("nav_mesh_fort", Vector3(0, 0, -6), Vector3(0, 55, 30))
		nav_w.show_debug(false)

	var b := h.body
	h.set_role("stay")
	b.idle_clip = ""
	# ---- worker: cabin -> gate -> woods
	var cabin := _door_of("cabin")
	var store := _door_of("storehouse")
	_expect(cabin != null and not cabin.is_open and store != null and not store.is_open, "the cabin's and the storehouse's doors hang shut")
	var inside_cabin := Vector3(-8.0, 0.0, 6.6)
	_place(b, inside_cabin)
	await _frames(30)
	var woods := _woods_spot()
	_expect(woods != Vector3.INF, "a woods spot 38-44 m out is on the mesh")
	var p0 := nav_w.path(b.global_position, woods)
	var plen := 0.0
	for i in range(1, p0.size()):
		plen += p0[i - 1].distance_to(p0[i])
	print("path out: %d corners, %.1f m (straight %.1f m)" % [p0.size(), plen, b.global_position.distance_to(woods)])
	_gate_x.clear()
	_max_step = 0.0
	var opened0 := b.nav.doors_opened
	var t_out := await _walk(woods, plen / Spouse.WALK_SPEED * 1.6 + 20.0)
	_expect(t_out < INF, "she walks from the cabin to the woods spot (%.0f s for %.0f m of path)" % [t_out, plen])
	_expect(b.nav.doors_opened > opened0, "she opened the cabin's shut door on her way (%d)" % (b.nav.doors_opened - opened0))
	_expect(not cabin.is_open, "the cabin's door swung shut behind her")
	_expect(_gate_x.any(func(x: float) -> bool: return absf(x) < 1.4), "she went out through the gate (crossed z -16 at x %s)" % [_gate_x])
	_expect(_max_step < 0.25, "no jump on the way (largest step in a frame %.2f m)" % _max_step)
	await _shot("worker_in_woods", b.global_position + Vector3(0, 1.0, 0), b.global_position + Vector3(5, 3.5, 6))
	# ---- back: woods -> gate -> into the storehouse
	var inside_store := Vector3(9.6, 0.0, 4.0)
	_gate_x.clear()
	var opened1 := b.nav.doors_opened
	var t_back := await _walk(inside_store, 150.0)
	_expect(t_back < INF, "she walks back into the storehouse (%.0f s)" % t_back)
	_expect(_gate_x.any(func(x: float) -> bool: return absf(x) < 1.4), "back in through the gate (x %s)" % [_gate_x])
	_expect(b.nav.doors_opened > opened1, "she opened the storehouse's door")
	var inside := b.global_position.x > 6.8 and b.global_position.x < 11.3 and absf(b.global_position.z - 4.0) < 1.8
	_expect(inside, "she is inside the storehouse (%s)" % b.global_position)
	# ---- out of the storehouse again: its door shut behind her
	var yard := Vector3(2.0, 0.0, 1.0)
	yard.y = FrontierTerrain.height_at(yard.x, yard.z)
	yard = nav_w.snap(yard)
	var opened2 := b.nav.doors_opened
	var t_yard := await _walk(yard, 40.0)
	await _frames(int(3.0 * Engine.physics_ticks_per_second))
	_expect(t_yard < INF and not store.is_open, "out of the storehouse into the yard (%.0f s): its door is shut behind her (opened %d)" % [t_yard, b.nav.doors_opened - opened2])
	# ---- the player opens the cabin's door: she goes in through it, and it is left open (the player's, not hers)
	cabin.interact(player)
	await _frames(int(1.0 * Engine.physics_ticks_per_second))
	var opened3 := b.nav.doors_opened
	var t_in := await _walk(inside_cabin + Vector3(1.0, 0, 0), 40.0)
	_expect(t_in < INF and b.global_position.z > 5.0, "into the cabin through the open door (%.0f s, at %s)" % [t_in, b.global_position])
	await _walk(yard, 40.0)
	await _frames(int(3.0 * Engine.physics_ticks_per_second))
	_expect(cabin.is_open and b.nav.doors_opened == opened3, "the door the player opened is left open behind her (open %s)" % cabin.is_open)
	cabin.interact(player)   # shut again by the player
	await _frames(int(2.0 * Engine.physics_ticks_per_second))
	# ---- round the palisade: outside east to outside west
	var east := Vector3(24.0, 0.0, 2.0)
	var west := Vector3(-24.0, 0.0, 2.0)
	east.y = FrontierTerrain.height_at(east.x, east.z)
	west.y = FrontierTerrain.height_at(west.x, west.z)
	_place(b, east)
	# a visitor walks in at the same time, from outside the east palisade into the yard
	var rb := RecruitBody.spawn(current_scene, east + Vector3(0.0, 0.0, -3.0), h.sc.look, {}, false)
	var r_to := Vector3(2.0, 0.0, -6.0)
	r_to.y = FrontierTerrain.height_at(r_to.x, r_to.z)
	r_to = nav_w.snap(r_to)
	var r_arrived := [false]
	rb.arrived.connect(func(_b: RecruitBody) -> void: r_arrived[0] = true)
	await _frames(20)
	rb.walk([r_to])
	var t_rc := Time.get_ticks_msec()
	var t_round := await _walk(west, 120.0)
	var pr := b.nav.paths
	for i in 60 * Engine.physics_ticks_per_second:
		if r_arrived[0]:
			break
		await physics_frame
	var r_in := rb.global_position.x > -15.0 and rb.global_position.x < 15.0 and rb.global_position.z > -15.0 and rb.global_position.z < 15.0
	_expect(r_arrived[0] and r_in, "a visitor walks from outside the east palisade into the yard (%s, at %s)" % [r_arrived[0], rb.global_position])
	_expect(rb.ghosts == 0 and rb.nav.paths > 0, "on the mesh, with no step-through (paths %d, step-throughs %d, nav %s)" % [rb.nav.paths, rb.ghosts, rb.nav.reason])
	print("visitor: %.0f s of test time" % ((Time.get_ticks_msec() - t_rc) / 1000.0))
	rb.queue_free()
	_expect(t_round < INF, "from outside the east palisade round to the west (%.0f s, straight %.0f m)" % [t_round, east.distance_to(west)])
	_expect(t_round > east.distance_to(west) / Spouse.WALK_SPEED * 1.15, "the way went round the fort, not through the wall")
	_expect(_max_step < 0.25, "no jump (%.2f m)" % _max_step)
	print("paths asked %d, give-ups %d" % [pr, b.nav.give_ups])

	# ---- the bake again: a wall built in the yard, a tree felled
	var bw := BuildWorld.of(self, false)
	var before := int(nav_w.stats.baked)
	var at := Vector3(4.0, 0.0, -6.0)
	var a_pt := at + Vector3(0, 0, -4)
	var b_pt := at + Vector3(0, 0, 4)
	var straight_before := nav_w.path(a_pt, b_pt)
	var tk := NavWorld.key_of(at)
	var gen0 := int(nav_w.tiles[tk].gen)
	# the main thread: a frame's worst with nothing baking, then with the rebake (NavWorld's tick, the server's step)
	var calm := await _worst_frame(240)
	nav_w.stats.nav_max = 0.0
	nav_w.stats.tick_max = 0.0
	nav_w.stats.set_max = 0.0
	var worst := 0.0
	var piece := bw.add_piece("wall", Transform3D(Basis(), at), true, -1) if bw != null else null
	var t_rb := Time.get_ticks_msec()
	# its tile is baked again (a new generation, in the map) and synced; the worst frame from the 6th on (the first few are
	# the piece's own making, nav or not: ~30 ms)
	var tf := Time.get_ticks_usec()
	var nf := 0
	while Time.get_ticks_msec() - t_rb < 8000 and not (int(nav_w.tiles[tk].get("in_gen", 0)) > gen0 and nav_w.synced_at(at)):
		await physics_frame
		nf += 1
		if nf > 5:
			worst = maxf(worst, (Time.get_ticks_usec() - tf) / 1000.0)
		tf = Time.get_ticks_usec()
	var rb_ms := Time.get_ticks_msec() - t_rb
	for i in 4:
		await physics_frame
		worst = maxf(worst, (Time.get_ticks_usec() - tf) / 1000.0)
		tf = Time.get_ticks_usec()
	var ns := nav_w.stats
	print("rebake main thread: worst frame %.1f ms (%.1f ms with nothing baking); NavWorld tick max %.2f ms, mesh set %.2f ms, server step max %.2f ms; poll max %.2f ms; paths %d avg %.2f ms max %.2f ms" % [
			worst, calm, float(ns.tick_max), float(ns.set_max), float(ns.nav_max), float(ns.poll_max), int(ns.path_n), float(ns.path_ms) / maxi(int(ns.path_n), 1), float(ns.path_max)])
	_expect(float(ns.tick_max) + float(ns.nav_max) < 12.0, "a rebake costs the main thread little (NavWorld %.2f ms + server %.2f ms at worst)" % [float(ns.tick_max), float(ns.nav_max)])
	_expect(worst < maxf(calm * 1.5, calm + 15.0), "no stall while the tile bakes again (worst frame %.1f ms, %.1f without)" % [worst, calm])
	_expect(int(nav_w.stats.baked) > before and int(nav_w.tiles[tk].gen) > gen0, "a wall built in the yard bakes its tile again (in the map %d ms after it went up)" % rb_ms)
	var round_it := nav_w.path(a_pt, b_pt)
	var l0 := 0.0
	var l1 := 0.0
	for i in range(1, straight_before.size()):
		l0 += straight_before[i - 1].distance_to(straight_before[i])
	for i in range(1, round_it.size()):
		l1 += round_it[i - 1].distance_to(round_it[i])
	_expect(l1 > l0 + 0.5, "the path across the wall's spot goes round it now (%.1f m, was %.1f)" % [l1, l0])
	if piece != null:
		bw.remove_piece(piece)
	var vh := VegHarvest.find(self)
	if vh != null:
		var near := vh.near(woods, 12.0)
		for e: Dictionary in near:
			if String(e.type) == "tree":
				var fk := NavWorld.key_of(e.pos)
				var fgen := int(nav_w.tiles[fk].gen) if nav_w.tiles.has(fk) else 0
				var trunk: Vector3 = e.pos
				var blocked_before := not nav_w.on_mesh(trunk)
				vh.remove_tree(int(e.i))
				var t_f := Time.get_ticks_msec()
				while Time.get_ticks_msec() - t_f < 8000 and not (nav_w.tiles.has(fk) and int(nav_w.tiles[fk].get("in_gen", 0)) > fgen and nav_w.synced_at(trunk)):
					await physics_frame
				var f_ms := Time.get_ticks_msec() - t_f
				for i in 4:
					await physics_frame
				_expect(nav_w.tiles.has(fk) and int(nav_w.tiles[fk].get("in_gen", 0)) > fgen, "a felled tree bakes its tile again (in the map %d ms after)" % f_ms)
				_expect(blocked_before and nav_w.on_mesh(trunk), "where its trunk stood is walkable now (was blocked: %s)" % blocked_before)
				break

	# ---- the child: following its mother the same route
	var g := h.growth
	var core := h.bridge.core
	var now := core.state.minutes
	var kid_rec := Pregnancy.make_child(RandomNumberGenerator.new(), now - 200.0 * 1440.0, {"next_id": 7, "mother": h.sc.name, "father": "player", "kind": "spouse"})
	Growth.normalize(kid_rec, now)
	Growth.to_stage(kid_rec, "child", now)
	_place(b, inside_cabin)
	h.family.append(kid_rec)
	kid_rec["with"] = g.npc_role(kid_rec)
	kid_rec["mode"] = "follow"
	var kid: ChildBody = null
	for i in 240:
		await physics_frame
		kid = g.child_node(kid_rec) as ChildBody
		if kid != null:
			break
	_expect(kid != null, "the child's body is in")
	if kid != null:
		_place(kid, inside_cabin + Vector3(0.8, 0, -0.6))
		await _frames(60)
		_child_step = 0.0
		_child_last = kid.global_position
		_max_step = 0.0
		_gate_x.clear()
		var t_k := await _walk(woods, plen / Spouse.WALK_SPEED * 1.6 + 25.0, kid)
		_expect(t_k < INF, "with the child: she reaches the woods spot (%.0f s)" % t_k)
		var lag := await _catch_up(kid, 4.0, 25.0)
		_expect(lag <= 4.0, "the child followed her out through the gate to the woods (%.1f m from her)" % lag)
		_expect(not cabin.is_open, "the cabin's door is shut again behind the two of them")
		await _shot("child_follows_woods", (kid.global_position + b.global_position) * 0.5 + Vector3(0, 0.8, 0), b.global_position + Vector3(6, 4, 6))
		var t_k2 := await _walk(inside_store, 150.0, kid)
		_expect(t_k2 < INF, "with the child: back into the storehouse (%.0f s)" % t_k2)
		var lag2 := await _catch_up(kid, 2.6, 25.0)
		var kin := kid.global_position.x > 6.6 and kid.global_position.x < 11.4 and absf(kid.global_position.z - 4.0) < 2.0
		_expect(lag2 <= 2.6 and kin, "the child followed her back into the storehouse (%.1f m from her, at %s)" % [lag2, kid.global_position])
		_expect(kid.teleports == 0, "the child was never brought back by a jump (%d teleports)" % kid.teleports)
		_expect(_child_step < 0.25, "no jump in the child's walk (largest step %.2f m)" % _child_step)
		print("child: paths %d, doors %d, give-ups %d (%s)" % [kid.nav.paths, kid.nav.doors_opened, kid.nav.give_ups, kid.nav.reason])
	b.errand = Callable()
	print("NAV WORKERS DONE: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
