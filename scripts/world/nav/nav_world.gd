class_name NavWorld
extends Node3D
## Pathfinding for the household's walking bodies (the workers, the children): a navigation mesh baked at run time, in
## tiles, round where they are and where they are going, on the NavigationServer (its own map; nothing else in the game
## uses navigation). The world is open and streamed and changes (a piece built or taken down, a tree felled, a rock
## quarried), so nothing is baked offline:
##   - tiles of TILE m on a fixed grid, each a server region with its own NavigationMesh; the bake bounds are the tile's
##     square with a BORDER of geometry round it, so neighbouring tiles meet edge to edge and the map joins them;
##   - which tiles: round every registered NavMover's body (BODY_RING) and its home (HOME_RING: the woods the workers go to),
##     the tile its target is in, and the tiles along a long walk (request); the ones far from them all are dropped;
##   - a bake: the geometry gathered on the main thread for the tile (NavSource: the ground from the height field, the
##     static colliders in the box; ~ms), baked on a worker thread (bake_from_source_geometry_data_async), then swapped
##     in as a new region for the tile's old one in one server step; MAX_BAKING at a time, nearest the walkers first;
##   - the map joins its regions on a worker thread too (async iterations: joining ~25 tiles of ~5000 polygons took the
##     main thread ~140 ms a rebake when it was synchronous); a tile's mesh is known to be in the map when the map says the
##     closest point to a spot on it is owned by its new region (the probe);
##   - rebakes: polled every POLL_S (and on BuildWorld.changed): a built piece added, taken down or re-dressed (its body
##     replaced: a palisade cut), a felled tree (VegHarvest.felled, the lying FelledTree trunks), a quarried rock marks the
##     tiles round it dirty; the old mesh is used until the new one is in;
##   - doors: every BuildDoor's leaves are left out of the bake (the doorway is open on the mesh); a NavMover coming to a
##     shut door opens it (open_door), and it is shut again once no walker is near it (only the doors a walker opened).
## NavWorld.of(tree) makes it under the level (a scene with a FrontierTerrain) on first use; null elsewhere (the walkers
## then steer straight, as before). A debug overlay of the baked mesh: `debug = true` or the user arg nav_debug=on.

signal tile_baked(key: Vector2i, ms: float)
## A tile's new mesh is in the map's paths.
signal tile_in(key: Vector2i)

const NODE_NAME := "NavWorld"
## A static body in this group is not baked (not an obstacle to the walkers).
const NO_NAV_GROUP := &"no_nav"
const TILE := 32.0
## The bake's voxels: 32 m is 256 cells (every size here a whole number of them: Recast rounds, and a tile's edge must fall
## on its neighbour's); the agent's radius and the doorways (0.9 m for a blockhouse's) need them this fine.
const CELL := 0.125
const CELL_H := 0.125
const AGENT_R := 0.375
const AGENT_H := 1.75
const CLIMB := 0.375
const SLOPE := 40.0
## Geometry taken round a tile's square (m), so its edges bake as if the neighbours were there: the bake's bounds are the
## square grown by it, and the same border_size is cut off the result again (the tile's mesh ends exactly on its square).
const BORDER := 1.0
const BODY_RING := 1
const HOME_RING := 2
## Tiles further than this from every walker and home are dropped (m, tile centre).
const KEEP_M := 240.0
const MAX_TILES := 144
const MAX_BAKING := 2
const POLL_S := 1.0

var map: RID
var debug := false
## Totals for the tests and the report: tiles baked, gather / bake ms (sum, max), the last tile's numbers; the main thread's
## share: the change poll (poll_max), setting a baked mesh on its region (set_max), the NavigationServer's own step each frame
## (nav_max: the map joining the regions again after a new mesh; Performance.TIME_NAVIGATION_PROCESS), this node's whole tick
## (tick_max), the path queries (path_n, path_ms, path_max); off it: a new mesh set to its being in the map's paths (sync_max).
var stats := {"baked": 0, "gather_ms": 0.0, "gather_max": 0.0, "bake_ms": 0.0, "bake_max": 0.0, "poll_max": 0.0, "set_max": 0.0,
		"nav_max": 0.0, "tick_max": 0.0, "path_n": 0, "path_ms": 0.0, "path_max": 0.0, "sync_max": 0.0, "last": {}}

## Vector2i -> {region: RID, state: "queued" | "baking" | "ready", dirty, gen, used (s), after; once baked: nm, in_gen, in_map,
## had (a mesh of it has been in the map), probe, set_us}
var tiles := {}
var movers: Array[NavMover] = []
var _queue: Array[Vector2i] = []
var _baking := 0
var _clock := 0.0
var _poll_t := 0.0
var _want_t := 0.0
var _requested := {}          ## Vector2i -> clock time it was last asked for
var _pieces := {}             ## piece id -> [tile keys, body instance id]
var _felled_seen := {}        ## VegHarvest.felled index -> true (seen, its tiles made dirty once)
var _rock_seen := {}          ## VegHarvest.rock_size index -> the size last seen
var _veg_primed := false
var _felled_nodes := {}       ## instance id -> true (FelledTree nodes seen)
var _doors: Array[BuildDoor] = []
var _doors_t := 0.0
var _opened := {}             ## door instance id -> {door, clear (s)}
var _debug_nodes := {}        ## Vector2i -> MeshInstance3D
var _debug_mat: StandardMaterial3D
var _player: Node3D
var _query: NavigationPathQueryParameters3D
var _result: NavigationPathQueryResult3D
var _bake_tasks: Array[int] = []      ## the WorkerThreadPool tasks of the bakes in flight (_start; waited in _exit_tree)


static func of(tree: SceneTree) -> NavWorld:
	var scene := tree.current_scene if tree else null
	if scene == null:
		return null
	var w := scene.get_node_or_null(NODE_NAME) as NavWorld
	if w != null:
		return w
	if not (scene.get_node_or_null("Terrain") is FrontierTerrain):
		return null
	w = NavWorld.new()
	w.name = NODE_NAME
	scene.add_child(w)
	return w


func _ready() -> void:
	map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_up(map, Vector3.UP)
	NavigationServer3D.map_set_cell_size(map, CELL)
	NavigationServer3D.map_set_cell_height(map, CELL_H)
	# tiles join where their border edges come within this: on sloping ground the two tiles' edges bake a little apart
	# (a 3 m step across the seam west of the fort went 13 m round at 0.3); a wall and the walker's clearance keep more than
	# a metre between the mesh on its two sides, and only tile borders are joined, so nothing joins through a wall
	NavigationServer3D.map_set_edge_connection_margin(map, 0.6)
	NavigationServer3D.map_set_merge_rasterizer_cell_scale(map, 0.25)
	NavigationServer3D.map_set_use_async_iterations(map, true)
	NavigationServer3D.map_set_active(map, true)
	if "nav_debug=on" in OS.get_cmdline_user_args():
		debug = true
	var bw := BuildWorld.of(get_tree(), false)
	if bw != null:
		bw.changed.connect(func() -> void: _poll_t = POLL_S)


func _exit_tree() -> void:
	# the bakes in flight finish first (a few tens of ms each, MAX_BAKING at most): none is left running into the server's
	# shutdown at a quit; their results are let go (_baked on a node that is gone)
	for task in _bake_tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	_bake_tasks.clear()
	for k: Vector2i in tiles:
		# (a tile queued or on its first bake has no region yet: freeing its empty RID was the "Attempted to free a
		# NavigationServer RID that did not exist" at every quit with tiles on their way)
		if (tiles[k].region as RID).is_valid():
			NavigationServer3D.free_rid(tiles[k].region)
	tiles.clear()
	if map.is_valid():
		NavigationServer3D.free_rid(map)
		map = RID()


static func key_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.z / TILE))


static func tile_box(k: Vector2i) -> AABB:
	return AABB(Vector3(k.x * TILE, 0.0, k.y * TILE), Vector3(TILE, 0.0, TILE))


# ---------------------------------------------------------------- walkers
func register(m: NavMover) -> void:
	if not movers.has(m):
		movers.append(m)
		_want_t = 0.0


func unregister(m: NavMover) -> void:
	movers.erase(m)


## Asks for the tiles along the way from `a` to `b` (a long walk), each with its neighbours when `ring`.
func request(a: Vector3, b: Vector3, ring := 0) -> void:
	var d := Vector2(b.x - a.x, b.z - a.z).length()
	var n := maxi(1, ceili(d / (TILE * 0.5)))
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		var k := key_of(p)
		for dz in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				_requested[k + Vector2i(dx, dz)] = _clock
	_want_t = 0.0


## Whether there is mesh in the map at `p` (its tile's first bake is in; a rebake's old mesh serves until the new one is in).
func ready_at(p: Vector3) -> bool:
	var t: Variant = tiles.get(key_of(p))
	return t != null and bool(t.get("had", false))


## Whether the tile at `p` is on its way (queued or baking, not in yet).
func pending_at(p: Vector3) -> bool:
	var t: Variant = tiles.get(key_of(p))
	return t != null and not bool(t.get("had", false))


## Whether the tile at `p` has its latest bake in the map (tests: a rebake is in).
func synced_at(p: Vector3) -> bool:
	var t: Variant = tiles.get(key_of(p))
	return t != null and t.state == "ready" and bool(t.get("in_map", false)) and int(t.get("in_gen", -1)) == int(t.gen)


## The tiles whose new region is not known to be in the map yet: in when the map's closest point to the probe (a spot on
## the new mesh) is owned by the new region.
func _check_in() -> void:
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return       # (the map not synchronized once yet: a first bake in before it is asked nothing)
	for k: Vector2i in tiles:
		var t: Dictionary = tiles[k]
		if t.state != "ready" or bool(t.get("in_map", true)):
			continue
		var probe: Vector3 = t.get("probe", Vector3.INF)
		if probe == Vector3.INF or NavigationServer3D.map_get_closest_point_owner(map, probe) == t.region:
			t.in_map = true
			t.had = true
			var ms := (Time.get_ticks_usec() - int(t.set_us)) / 1000.0
			stats.sync_max = maxf(float(stats.sync_max), ms)
			tile_in.emit(k)


## The nearest point on the mesh to `p` (p itself when there is no mesh there).
func snap(p: Vector3) -> Vector3:
	if not ready_at(p):
		return p
	var q := NavigationServer3D.map_get_closest_point(map, p)
	return q if q != Vector3.ZERO or p.length() < 0.01 else p


## Whether `p` is on the mesh (within 0.2 m of it across, 1 m up or down).
func on_mesh(p: Vector3) -> bool:
	if not ready_at(p):
		return true
	var q := NavigationServer3D.map_get_closest_point(map, p)
	return Vector2(q.x - p.x, q.z - p.z).length() < 0.2 and absf(q.y - p.y) < 1.0


## The way from `from` to `to` (corners; to the nearest reachable point when `to` cannot be reached). The search is not
## capped: a tile has thousands of polygons, and the server's default cap (4096) gave up half-way on a walk round the fort
## and answered with a path to the wrong side of the palisade.
func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	if _query == null:
		_query = NavigationPathQueryParameters3D.new()
		_query.path_search_max_polygons = 0
		_result = NavigationPathQueryResult3D.new()
	_query.map = map
	_query.start_position = from
	_query.target_position = to
	var t0 := Time.get_ticks_usec()
	NavigationServer3D.query_path(_query, _result)
	path_timed((Time.get_ticks_usec() - t0) / 1000.0)
	return _result.path


## The same query on a worker thread (the walkers' own: a long way over a few dozen tiles of thousands of polygons took the
## main thread up to ~14 ms): returns the WorkerThreadPool task; `res` holds the path once it is done and `ms` [0] its time.
## The server's map queries are thread-safe (they read the map's current iteration).
func path_async(from: Vector3, to: Vector3, q: NavigationPathQueryParameters3D, res: NavigationPathQueryResult3D, ms: Array) -> int:
	q.path_search_max_polygons = 0
	q.map = map
	q.start_position = from
	q.target_position = to
	return WorkerThreadPool.add_task(func() -> void:
		var t0 := Time.get_ticks_usec()
		NavigationServer3D.query_path(q, res)
		ms[0] = (Time.get_ticks_usec() - t0) / 1000.0, false, "nav path")


func path_timed(ms: float) -> void:
	stats.path_n = int(stats.path_n) + 1
	stats.path_ms = float(stats.path_ms) + ms
	stats.path_max = maxf(float(stats.path_max), ms)


func iteration() -> int:
	return NavigationServer3D.map_get_iteration_id(map)


func baking() -> int:
	return _baking


func ready_count() -> int:
	var n := 0
	for k: Vector2i in tiles:
		if tiles[k].state == "ready":
			n += 1
	return n


## Separation from the other walkers (and the player) close to `m`: a push (m/s-ish, horizontal), zero when clear. The
## smaller give way: a grown worker keeps her way past a child (the child steps aside), equals both step aside.
func separation(m: NavMover) -> Vector3:
	var me := m.body.global_position
	var push := Vector3.ZERO
	for o in movers:
		if o == m or o.body == null or not is_instance_valid(o.body) or o.radius < m.radius - 0.02:
			continue
		push += _push(me, o.body.global_position, m.radius + o.radius + 0.35)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
	if _player != null and m.body != _player:
		push += _push(me, _player.global_position, m.radius + 0.35 + 0.35)
	return push


func _push(me: Vector3, o: Vector3, reach: float) -> Vector3:
	var d := Vector3(me.x - o.x, 0.0, me.z - o.z)
	var l := d.length()
	if l >= reach or absf(me.y - o.y) > 1.5:
		return Vector3.ZERO
	if l < 0.01:
		d = Vector3(0.01, 0.0, 0.0)
		l = 0.01
	return d / l * (reach - l) / reach


# ---------------------------------------------------------------- doors
func doors() -> Array[BuildDoor]:
	if _clock - _doors_t > 3.0 or _doors_t == 0.0:
		_doors_t = _clock + 0.001
		_doors.clear()
		for n in get_tree().get_nodes_in_group(PlacedWeapon.GROUP):
			if n is BuildDoor:
				_doors.append(n as BuildDoor)
	return _doors


## The door a walk from `a` to `b` goes through (the nearest along it), or null.
func door_on(a: Vector3, b: Vector3, reach := 0.8) -> BuildDoor:
	var best: BuildDoor = null
	var bd := INF
	for d in doors():
		if not is_instance_valid(d):
			continue
		var c := d.global_position
		if absf(c.y - a.y) > 2.5:
			continue
		# the leg goes through the doorway: its ends on either side of the door's plane, crossing it within `reach` of the middle
		var n := Vector3(d.global_basis.z.x, 0.0, d.global_basis.z.z).normalized()
		var sa := Vector3(a.x - c.x, 0.0, a.z - c.z).dot(n)
		var sb := Vector3(b.x - c.x, 0.0, b.z - c.z).dot(n)
		if (sa > 0.05 and sb > 0.05) or (sa < -0.05 and sb < -0.05):
			continue
		var f := clampf(sa / (sa - sb), 0.0, 1.0) if absf(sa - sb) > 0.001 else 0.0
		var q := a.lerp(b, f)
		var off := Vector2(q.x - c.x, q.z - c.z).length()
		if off > (maxf(reach, 1.8) if d.kind == "gate" else reach):
			continue
		var along := Vector2(q.x - a.x, q.z - a.z).length()
		if along < bd:
			bd = along
			best = d
	return best


## A walker opens a shut door; it is shut again once none is near (only if a walker opened it). `hold_r`: it stays open
## while a walker is within this of it (a rider opens a gate from the saddle further off, and comes on at a trot).
func open_door(d: BuildDoor, hold_r := 2.3) -> void:
	if d == null or d.locked:
		return
	var id := d.get_instance_id()
	if _opened.has(id):
		_opened[id]["r"] = maxf(float(_opened[id].get("r", 2.3)), hold_r)
	if d.is_open:
		return
	d.set_open(true)
	_opened[id] = {"door": d, "clear": 0.0, "r": hold_r}


## Door `d` used by walker `by` (its E on the way, WalkPath's door steps): opened if shut, and held open while `by` or any
## other walker using it is within `hold_r`; shut behind them as open_door's are. A door the player opened is only passed.
func use_door(d: BuildDoor, by: Node3D, hold_r := 2.3) -> void:
	if d == null:
		return
	open_door(d, hold_r)
	var id := d.get_instance_id()
	if _opened.has(id):
		var us: Array = _opened[id].get("users", [])
		if not us.has(by):
			us.append(by)
		_opened[id]["users"] = us


func _close_doors(dt: float) -> void:
	for id: int in _opened.keys():
		var e: Dictionary = _opened[id]
		var d := e.door as BuildDoor
		if d == null or not is_instance_valid(d) or not d.is_open:
			_opened.erase(id)   # gone, or someone shut it
			continue
		var c := d.global_position
		var near := false
		var hold := float(e.get("r", 2.3))
		for m in movers:
			if m.body != null and is_instance_valid(m.body) and Vector2(m.body.global_position.x - c.x, m.body.global_position.z - c.z).length() < hold:
				near = true
				break
		for u: Variant in e.get("users", []):
			if not near and is_instance_valid(u) and Vector2((u as Node3D).global_position.x - c.x, (u as Node3D).global_position.z - c.z).length() < hold:
				near = true
		if not near and _player != null and is_instance_valid(_player) and _player.global_position.distance_to(c) < 1.6:
			near = true   # never shut on the player standing in the doorway
		e.clear = 0.0 if near else float(e.clear) + dt
		if float(e.clear) > 1.2:
			d.set_open(false)
			_opened.erase(id)


func npc_opened(d: BuildDoor) -> bool:
	return d != null and _opened.has(d.get_instance_id())


# ---------------------------------------------------------------- the tiles
func _physics_process(dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	_clock += dt
	for i in range(_bake_tasks.size() - 1, -1, -1):
		if WorkerThreadPool.is_task_completed(_bake_tasks[i]):
			WorkerThreadPool.wait_for_task_completion(_bake_tasks[i])     # (a finished task is waited for, once)
			_bake_tasks.remove_at(i)
	# the server's step of the frame before (the map's sync after a region got a new mesh is the costly one)
	stats.nav_max = maxf(float(stats.nav_max), Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0)
	_want_t -= dt
	if _want_t <= 0.0:
		_want_t = 0.5
		_want()
	_poll_t += dt
	if _poll_t >= POLL_S:
		_poll_t = 0.0
		var tp := Time.get_ticks_usec()
		_poll_changes()
		stats.poll_max = maxf(float(stats.poll_max), (Time.get_ticks_usec() - tp) / 1000.0)
	_close_doors(dt)
	_check_in()
	# (a tile marked dirty waits a moment: a body added this frame is not in the physics space's queries yet)
	var i := 0
	while _baking < MAX_BAKING and i < _queue.size():
		var k: Vector2i = _queue[i]
		var t: Variant = tiles.get(k)
		if t != null and float(t.get("after", 0.0)) > _clock:
			i += 1
			continue
		_queue.remove_at(i)
		_start(k)
	stats.tick_max = maxf(float(stats.tick_max), (Time.get_ticks_usec() - t0) / 1000.0)


## The tiles wanted now: queued when missing (or dirty), nearest a walker first; the far ones dropped.
func _want() -> void:
	var want := {}
	var bodies: Array[Vector3] = []
	for m in movers:
		if m.body == null or not is_instance_valid(m.body):
			continue
		var p := m.body.global_position
		bodies.append(p)
		_ring(want, key_of(p), BODY_RING)
		if m.home != Vector3.INF:
			_ring(want, key_of(m.home), HOME_RING)
			bodies.append(m.home)
		if m.target != Vector3.INF:
			_ring(want, key_of(m.target), 0)
	for k: Vector2i in _requested.keys():
		if _clock - float(_requested[k]) > 30.0:
			_requested.erase(k)
		else:
			want[k] = true
	for k: Vector2i in want:
		var t: Variant = tiles.get(k)
		if t == null:
			t = {"region": RID(), "state": "queued", "dirty": false, "gen": 0, "used": _clock}
			tiles[k] = t
			_queue.append(k)
		t.used = _clock
		if t.dirty and t.state == "ready" and not _queue.has(k):
			_queue.append(k)
	# nearest a walker first
	var c := _centre_of
	_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _near(c.call(a), bodies) < _near(c.call(b), bodies))
	# the far ones go
	if tiles.size() > 0:
		for k: Vector2i in tiles.keys():
			var t: Dictionary = tiles[k]
			if t.state == "baking" or want.has(k):
				continue
			if _near(_centre_of(k), bodies) > KEEP_M or (tiles.size() > MAX_TILES and _clock - float(t.used) > 20.0):
				_drop(k)


func _ring(want: Dictionary, k: Vector2i, r: int) -> void:
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			want[k + Vector2i(dx, dz)] = true


func _centre_of(k: Vector2i) -> Vector3:
	return Vector3((k.x + 0.5) * TILE, 0.0, (k.y + 0.5) * TILE)


func _near(c: Vector3, pts: Array[Vector3]) -> float:
	var best := INF
	for p in pts:
		best = minf(best, Vector2(p.x - c.x, p.z - c.z).length())
	return best


func _drop(k: Vector2i) -> void:
	var t: Dictionary = tiles[k]
	if t.region.is_valid():
		NavigationServer3D.free_rid(t.region)
	tiles.erase(k)
	_queue.erase(k)
	if _debug_nodes.has(k):
		(_debug_nodes[k] as Node).queue_free()
		_debug_nodes.erase(k)


## Gathers the tile's geometry (main thread) and bakes it on a worker thread.
func _start(k: Vector2i) -> void:
	var t: Variant = tiles.get(k)
	if t == null:
		return
	var t0 := Time.get_ticks_usec()
	var sq := tile_box(k)
	var gather_box := AABB(sq.position - Vector3(BORDER, 0, BORDER), sq.size + Vector3(BORDER * 2.0, 0, BORDER * 2.0))
	# the height range: the ground's in the box, with room for what stands on it
	var src := NavigationMeshSourceGeometryData3D.new()
	var st := {}
	NavSource._terrain(gather_box, src, st)
	# (on a world-wide lattice of CELL_H: Recast measures its voxels' heights from the box's floor, and a tile whose floor was
	# off its neighbour's by a part of a cell had its vertices on the seam at other heights; the map did not join those edges,
	# and a path across the seam was sent through an edge connection the long way round: 20 m for 4 in the yard)
	var lo := floorf((float(st.get("ground_lo", 0.0)) - 3.0) / CELL_H) * CELL_H
	var hi := ceilf((float(st.get("ground_hi", 0.0)) + 14.0) / CELL_H) * CELL_H
	var probe := AABB(Vector3(gather_box.position.x, lo, gather_box.position.z), Vector3(gather_box.size.x, hi - lo, gather_box.size.z))
	st["terrain_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	NavSource._colliders(get_world_3d(), probe, src, st)
	var gather_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var nm := _new_mesh()
	nm.filter_baking_aabb = AABB(Vector3(gather_box.position.x, lo, gather_box.position.z), Vector3(gather_box.size.x, hi - lo, gather_box.size.z))
	if t.state != "ready":
		t.state = "baking"
	t.dirty = false
	t.gen = int(t.gen) + 1
	var gen := int(t.gen)
	_baking += 1
	var started := Time.get_ticks_usec()
	# (the bake on a worker task of our own, not the server's _async one: a task this node holds is waited for when it
	# goes (_exit_tree); a server bake still running as the game quit crashed it, "recursive_mutex lock failed", exit 134)
	var task := WorkerThreadPool.add_task(func() -> void:
		NavigationServer3D.bake_from_source_geometry_data(nm, src)
		_baked.call_deferred(k, gen, nm, gather_ms, started, st), false, "nav bake")
	_bake_tasks.append(task)


func _new_mesh() -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.cell_size = CELL
	nm.cell_height = CELL_H
	nm.agent_radius = AGENT_R
	nm.agent_height = AGENT_H
	nm.agent_max_climb = CLIMB
	nm.agent_max_slope = SLOPE
	nm.border_size = BORDER
	nm.edge_max_error = 1.0
	nm.edge_max_length = 0.0
	nm.region_min_size = 6.0
	nm.region_merge_size = 20.0
	nm.detail_sample_distance = 2.0
	nm.detail_sample_max_error = 0.3
	nm.filter_low_hanging_obstacles = true
	nm.filter_ledge_spans = true
	nm.filter_walkable_low_height_spans = true
	# layers: a third quicker than watershed here, and far fewer edges clashing at the tile seams; monotone is quicker
	# still but its long slivers made paths wander (91 m for a 53 m walk out of the gate)
	nm.sample_partition_type = NavigationMesh.SAMPLE_PARTITION_LAYERS
	return nm


func _baked(k: Vector2i, gen: int, nm: NavigationMesh, gather_ms: float, started: int, st: Dictionary) -> void:
	_baking = maxi(_baking - 1, 0)
	var bake_ms := (Time.get_ticks_usec() - started) / 1000.0
	var t: Variant = tiles.get(k)
	if t == null or int(t.gen) != gen:
		return   # dropped, or baked again since
	# a new region for the new mesh, the old one freed in the same server step: the map's next iteration has the one or the
	# other, never neither or both (the region's own polygons are made in that step, synchronously, so it cannot miss it)
	var ts := Time.get_ticks_usec()
	var r := NavigationServer3D.region_create()
	NavigationServer3D.region_set_use_async_iterations(r, false)
	NavigationServer3D.region_set_navigation_mesh(r, nm)
	NavigationServer3D.region_set_map(r, map)
	NavigationServer3D.region_set_enabled(r, true)
	if (t.region as RID).is_valid():
		NavigationServer3D.free_rid(t.region)
	t.region = r
	stats.set_max = maxf(float(stats.set_max), (Time.get_ticks_usec() - ts) / 1000.0)
	t.state = "ready"
	t["nm"] = nm
	t["in_gen"] = gen   # the generation of the mesh set (tests: a rebake is in, with in_map)
	t["in_map"] = false
	t["set_us"] = Time.get_ticks_usec()
	t["probe"] = _probe_of(nm)
	stats.baked = int(stats.baked) + 1
	stats.gather_ms = float(stats.gather_ms) + gather_ms
	if gather_ms > float(stats.gather_max):
		stats.gather_max = gather_ms
		stats["gather_worst"] = {"tile": k, "terrain_ms": st.get("terrain_ms", 0.0), "shapes": st.get("shapes", 0)}
	stats.bake_ms = float(stats.bake_ms) + bake_ms
	stats.bake_max = maxf(float(stats.bake_max), bake_ms)
	stats.last = {"tile": k, "gather_ms": gather_ms, "bake_ms": bake_ms, "polys": nm.get_polygon_count(),
			"shapes": st.get("shapes", 0), "obstructions": st.get("obstructions", 0), "faces": st.get("faces", 0), "full": st.get("full", false)}
	if debug:
		_draw_tile(k, nm)
	tile_baked.emit(k, gather_ms + bake_ms)


## A spot on a mesh (the middle of its largest polygon) to ask the map about; INF for an empty mesh.
func _probe_of(nm: NavigationMesh) -> Vector3:
	var verts := nm.get_vertices()
	var best := -1.0
	var at := Vector3.INF
	for i in nm.get_polygon_count():
		var poly := nm.get_polygon(i)
		if poly.size() < 3:
			continue
		var c := Vector3.ZERO
		for j in poly.size():
			c += verts[poly[j]]
		c /= poly.size()
		var a := (verts[poly[1]] - verts[poly[0]]).cross(verts[poly[2]] - verts[poly[0]]).length()
		if a > best:
			best = a
			at = c
	return at


## Marks the tiles round a box of the world to bake again (and the walk grid's sectors there to be read again).
func dirty(center: Vector3, r: float) -> void:
	var wg := get_parent().get_node_or_null(WalkGrid.NODE_NAME) as WalkGrid if get_parent() else null
	if wg != null:
		wg.dirty(center, r)
	var a := key_of(center - Vector3(r, 0, r))
	var b := key_of(center + Vector3(r, 0, r))
	for z in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			var k := Vector2i(x, z)
			var t: Variant = tiles.get(k)
			if t == null:
				continue
			t.dirty = true
			t["after"] = _clock + 0.1
			if t.state == "ready" and not _queue.has(k):
				_queue.push_front(k)
			elif t.state == "baking":
				t.gen = int(t.gen) + 1   # the bake under way is stale: its result is dropped, the tile queued again
				t.state = "queued"
				if not _queue.has(k):
					_queue.push_front(k)


## What changed in the world since the last look: built pieces, felled trees, quarried rocks.
func _poll_changes() -> void:
	var bw := BuildWorld.of(get_tree(), false)
	if bw != null:
		var now := {}
		for p in bw.pieces():
			var body_id := p.body.get_instance_id() if p.body != null else 0
			now[p.piece_id] = [p.global_position, body_id]
			var was: Variant = _pieces.get(p.piece_id)
			if was == null or int(was[1]) != body_id:
				if not _pieces.is_empty() or tiles.size() > 0:
					dirty(p.global_position, 6.0)
		for id: int in _pieces:
			if not now.has(id):
				dirty(_pieces[id][0], 6.0)
		_pieces = now
	var h := VegHarvest.find(get_tree()) if tiles.size() > 0 else null
	if h != null:
		# only the trees felled and the rocks quarried since the last look (the ones before the first look are in the first bakes)
		if h.felled.size() != _felled_seen.size():
			for i: int in h.felled:
				if not _felled_seen.has(i):
					_felled_seen[i] = true
					if _veg_primed:
						dirty(h.lay.tree_pos[i], 3.0)
		for i: int in h.rock_size:
			var f := float(h.rock_size[i])
			if float(_rock_seen.get(i, -1.0)) != f:
				_rock_seen[i] = f
				if _veg_primed:
					dirty(h.lay.prop_pos[i], 3.0)
		_veg_primed = true
	for n in get_tree().get_nodes_in_group(&"felled_trees"):
		var id := n.get_instance_id()
		if not _felled_nodes.has(id) and n is Node3D:
			_felled_nodes[id] = true
			dirty((n as Node3D).global_position, 12.0)


# ---------------------------------------------------------------- debug overlay
func _draw_tile(k: Vector2i, nm: NavigationMesh) -> void:
	if _debug_nodes.has(k):
		(_debug_nodes[k] as Node).queue_free()
	if _debug_mat == null:
		_debug_mat = StandardMaterial3D.new()
		_debug_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_debug_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_debug_mat.albedo_color = Color(0.1, 0.8, 1.0, 0.35)
		_debug_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_debug_mat.no_depth_test = false
	var verts := nm.get_vertices()
	var tris := PackedVector3Array()
	var lines := PackedVector3Array()
	for i in nm.get_polygon_count():
		var poly := nm.get_polygon(i)
		for j in range(1, poly.size() - 1):
			tris.append(verts[poly[0]] + Vector3.UP * 0.06)
			tris.append(verts[poly[j]] + Vector3.UP * 0.06)
			tris.append(verts[poly[j + 1]] + Vector3.UP * 0.06)
		for j in poly.size():
			lines.append(verts[poly[j]] + Vector3.UP * 0.08)
			lines.append(verts[poly[(j + 1) % poly.size()]] + Vector3.UP * 0.08)
	var am := ArrayMesh.new()
	if not tris.is_empty():
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = tris
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		am.surface_set_material(0, _debug_mat)
		var b := []
		b.resize(Mesh.ARRAY_MAX)
		b[Mesh.ARRAY_VERTEX] = lines
		am.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, b)
		var lm := StandardMaterial3D.new()
		lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lm.albedo_color = Color(0.0, 0.3, 0.5)
		am.surface_set_material(1, lm)
	var mi := MeshInstance3D.new()
	mi.name = "NavDebug_%d_%d" % [k.x, k.y]
	mi.mesh = am
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_debug_nodes[k] = mi


## Draws every baked tile (turning the overlay on after the bakes).
func show_debug(on: bool) -> void:
	debug = on
	for k: Vector2i in _debug_nodes:
		(_debug_nodes[k] as Node).queue_free()
	_debug_nodes.clear()
	if not on:
		return
	for k: Vector2i in tiles:
		var t: Dictionary = tiles[k]
		if t.state == "ready" and t.get("nm") != null:
			_draw_tile(k, t.nm)
