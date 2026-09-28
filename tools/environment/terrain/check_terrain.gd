extends SceneTree
## Package B acceptance check B2 (look-dev spec, section 10). Headless is fine:
##
##   Godot --headless --path . -s tools/environment/terrain/check_terrain.gd -- --no-capture
##
## Checks (one ok/FAIL line each, then CHECK TERRAIN PASSED / FAILED, exit code 0 / 1):
##   collision  1000 random points outside the flat zones: a ray down hits the ground within
##              3 cm of height_at() (the TerrainBody, or a path / rock overlay 1.5 cm above it).
##              Within 1 m of a flat zone the TerrainBody is up to 5 cm lower by design (the
##              flat-zone samples sit 5 cm under the GroundFloor box): those points are checked
##              against collision_height_at() and reported separately.
##   mesh       the LOD0 chunk mesh read back from its arrays (FrontierTerrain.grid_mesh(1)) and
##              lifted by the same height texels the shader fetches gives height_at() within
##              5 cm at 1000 random points (same samples, same diagonal: expected ~0)
##   cracks     along every chunk edge, the largest vertical gap between any two LOD levels is
##              smaller than the skirt depth (1.5 m), so skirts close every crack
##   flat       height_at == 0.0 exactly and forest_density == 0 on a 1 m grid over the flat zones
##   layers     ground_layers sums to 1; fort floor and lane strip are dirt, lane shoulders grass
##   api        cost per call of height_at, normal_at, forest_density, ground_layers (<= 2-4 us)
##   footsteps  Footsteps' 0.6 m down-ray from 0.1 m above the ground hits on the 200 steepest
##              samples (up to the outcrops' ~45-53 deg)
##   surfaces   Sfx.surface_of: paths -> dirt, outcrops -> stone, meadow / forest floor -> grass
##   load       FrontierTerrain.build() time headless (collision only), and the level load

var failures := PackedStringArray()
var space: PhysicsDirectSpaceState3D
var terrain: Node3D


func _initialize() -> void:
	var t0 := Time.get_ticks_usec()
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var load_ms := (Time.get_ticks_usec() - t0) / 1000.0
	terrain = current_scene.get_node_or_null("Terrain")
	if terrain == null or not FrontierTerrain.data_loaded():
		printerr("FAIL: terrain or its baked data missing")
		print("CHECK TERRAIN FAILED")
		quit(1)
		return
	var player := current_scene.get_node_or_null("Player")
	if player:
		player.set_physics_process(false)
		player.set_process(false)
	for i in 5:
		await physics_frame
	space = (terrain as Node3D).get_world_3d().direct_space_state
	# The level load includes the player's animation resources (~1.2 s cold, not package B's;
	# check_layout.gd preloads those before its timer). The terrain's own share is timed here.
	var tb := Time.get_ticks_usec()
	var probe_terrain := FrontierTerrain.new()
	root.add_child(probe_terrain)
	probe_terrain.build(WorldSettings.preset("high"))
	var build_ms := (Time.get_ticks_usec() - tb) / 1000.0
	probe_terrain.free()
	_expect(build_ms < 150.0, "load: FrontierTerrain.build() headless %.0f ms (budget 150; level load incl. player resources %.0f ms)" % [build_ms, load_ms])
	_check_collision()
	_check_mesh()
	_check_cracks()
	_check_flat()
	_check_layers()
	_check_api()
	_check_footsteps()
	_check_surfaces()
	if failures.is_empty():
		print("CHECK TERRAIN PASSED")
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("CHECK TERRAIN FAILED (%d)" % failures.size())
	quit(0 if failures.is_empty() else 1)


func _ground_ray(x: float, z: float) -> Dictionary:
	## First hit on a ground collider (group "terrain"), skipping trees, rocks and the rest.
	var from := Vector3(x, 300.0, z)
	var to := Vector3(x, -100.0, z)
	var exclude: Array[RID] = []
	for k in 16:
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.exclude = exclude
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return {}
		var body := hit.collider as CollisionObject3D
		if body and body.is_in_group(&"terrain"):
			return hit
		exclude.append(hit.rid)
	return {}


func _random_outside(rng: RandomNumberGenerator, lim := 395.0) -> Vector2:
	while true:
		var x := rng.randf_range(-lim, lim)
		var z := rng.randf_range(-lim, lim)
		if not FrontierTerrain.in_flat_zone(x, z):
			return Vector2(x, z)
	return Vector2.ZERO


func _check_collision() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var worst := 0.0
	var worst_at := Vector2.ZERO
	var worst_band := 0.0
	var worst_col := 0.0
	var band := 0
	var misses := 0
	for i in 1000:
		var p := _random_outside(rng)
		var hit := _ground_ray(p.x, p.y)
		if hit.is_empty():
			misses += 1
			continue
		var y: float = hit.position.y
		var h := FrontierTerrain.height_at(p.x, p.y)
		worst_col = maxf(worst_col, absf(y - FrontierTerrain.collision_height_at(p.x, p.y)) if (hit.collider as Node).name == "TerrainBody" else 0.0)
		if FrontierTerrain.flat_distance(p.x, p.y) < 1.0:
			band += 1
			worst_band = maxf(worst_band, absf(y - h))
			continue
		if absf(y - h) > worst:
			worst = absf(y - h)
			worst_at = p
	# The 1 m band just outside the flat zones (random points rarely land there).
	for i in 300:
		var t := rng.randf()
		var side := rng.randi_range(0, 3)
		var off := rng.randf_range(0.02, 0.98)
		var p := Vector2.ZERO
		match side:
			0: p = Vector2(lerpf(-26.0, 26.0, t), 26.0 + off)
			1: p = Vector2(-26.0 - off, lerpf(-26.0, 26.0, t))
			2: p = Vector2(26.0 + off, lerpf(-26.0, 26.0, t))
			3: p = Vector2(14.0 + off, lerpf(-175.0, -26.0, t))
		if FrontierTerrain.in_flat_zone(p.x, p.y):
			continue
		var hit := _ground_ray(p.x, p.y)
		if hit.is_empty():
			misses += 1
			continue
		band += 1
		worst_band = maxf(worst_band, absf(float(hit.position.y) - FrontierTerrain.height_at(p.x, p.y)))
		if (hit.collider as Node).name == "TerrainBody":
			worst_col = maxf(worst_col, absf(float(hit.position.y) - FrontierTerrain.collision_height_at(p.x, p.y)))
	_expect(misses == 0 and worst <= 0.03, "collision: ground ray vs height_at at 1000 random points outside the flat zones: worst %.4f m at %s (<= 0.03), %d misses" % [worst, worst_at, misses])
	_expect(worst_col <= 0.003, "collision: TerrainBody ray vs collision_height_at: worst %.4f m (same samples and diagonal)" % worst_col)
	_expect(worst_band <= 0.051, "collision: %d points within 1 m of a flat zone: worst %.3f m below height_at (<= 0.05 by design)" % [band, worst_band])


func _check_mesh() -> void:
	# Read the LOD0 chunk mesh back from its arrays and lift it like terrain.gdshader does.
	var mesh := FrontierTerrain.grid_mesh(1)
	var arr := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var img := FrontierTerrain.data_image("terrain_height.res")
	var hdata := img.get_data().to_float32_array()
	var n := FrontierTerrain.GRID_N
	var half := FrontierTerrain.GRID_HALF
	# Index the surface triangles (skirts excluded) by their 1 m cell.
	var tris := {}
	for t in range(0, idx.size(), 3):
		var a := verts[idx[t]]
		var b := verts[idx[t + 1]]
		var c := verts[idx[t + 2]]
		if a.y < 0.0 or b.y < 0.0 or c.y < 0.0:
			continue
		var cx := floori(minf(a.x, minf(b.x, c.x)))
		var cz := floori(minf(a.z, minf(b.z, c.z)))
		var key := Vector2i(cx, cz)
		if not tris.has(key):
			tris[key] = []
		tris[key].append([a, b, c])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var worst := 0.0
	var tested := 0
	for i in 1000:
		var p := _random_outside(rng, 380.0)
		# Chunk containing p and its centre.
		var ci := int(floor((p.x + half) / FrontierTerrain.CHUNK_SIZE))
		var cj := int(floor((p.y + half) / FrontierTerrain.CHUNK_SIZE))
		var centre := Vector2(ci * FrontierTerrain.CHUNK_SIZE - half + 32, cj * FrontierTerrain.CHUNK_SIZE - half + 32)
		var local := p - centre
		var key := Vector2i(floori(local.x), floori(local.y))
		if not tris.has(key):
			continue
		for tri: Array in tris[key]:
			var bc := _barycentric(local, tri[0], tri[1], tri[2])
			if bc.x < -1e-4 or bc.y < -1e-4 or bc.z < -1e-4:
				continue
			var hs := PackedFloat32Array()
			for v: Vector3 in tri:
				var w := Vector2(v.x, v.z) + centre
				hs.append(hdata[int(round(w.y + half)) * n + int(round(w.x + half))])
			var hm := bc.x * hs[0] + bc.y * hs[1] + bc.z * hs[2]
			worst = maxf(worst, absf(hm - FrontierTerrain.height_at(p.x, p.y)))
			tested += 1
			break
	_expect(tested >= 990 and worst <= 0.05, "mesh: LOD0 chunk mesh (read back from its arrays) vs height_at at %d points: worst %.5f m (<= 0.05)" % [tested, worst])


func _barycentric(p: Vector2, a3: Vector3, b3: Vector3, c3: Vector3) -> Vector3:
	var a := Vector2(a3.x, a3.z)
	var b := Vector2(b3.x, b3.z)
	var c := Vector2(c3.x, c3.z)
	var v0 := b - a
	var v1 := c - a
	var v2 := p - a
	var d := v0.x * v1.y - v1.x * v0.y
	var v := (v2.x * v1.y - v1.x * v2.y) / d
	var w := (v0.x * v2.y - v2.x * v0.y) / d
	return Vector3(1.0 - v - w, v, w)


## Height of the LOD grid with `step` spacing at world (x, z) on a chunk edge line.
func _lod_height(hdata: PackedFloat32Array, x: float, z: float, step: int) -> float:
	var n := FrontierTerrain.GRID_N
	var half := FrontierTerrain.GRID_HALF
	var fx := (x + half) / step
	var fz := (z + half) / step
	var i := int(floor(fx))
	var j := int(floor(fz))
	var u := fx - i
	var v := fz - j
	var h00 := hdata[mini(j * step, n - 1) * n + mini(i * step, n - 1)]
	var h10 := hdata[mini(j * step, n - 1) * n + mini((i + 1) * step, n - 1)]
	var h01 := hdata[mini((j + 1) * step, n - 1) * n + mini(i * step, n - 1)]
	var h11 := hdata[mini((j + 1) * step, n - 1) * n + mini((i + 1) * step, n - 1)]
	if u + v <= 1.0:
		return h00 + (h10 - h00) * u + (h01 - h00) * v
	return h11 + (h01 - h11) * (1.0 - u) + (h10 - h11) * (1.0 - v)


func _check_cracks() -> void:
	var hdata := FrontierTerrain.data_image("terrain_height.res").get_data().to_float32_array()
	var worst := 0.0
	var worst_at := Vector3.ZERO
	var half := FrontierTerrain.GRID_HALF
	var cs := FrontierTerrain.CHUNK_SIZE
	for k in range(1, FrontierTerrain.CHUNK_COUNT):
		var line := k * cs - half
		for t in range(-half, half):
			for s: float in [0.25, 0.5, 0.75]:
				var a := t + s
				for pair: Array in [[1, 2], [1, 4], [1, 8], [2, 4], [2, 8], [4, 8]]:
					var g1 := absf(_lod_height(hdata, line, a, int(pair[0])) - _lod_height(hdata, line, a, int(pair[1])))
					var g2 := absf(_lod_height(hdata, a, line, int(pair[0])) - _lod_height(hdata, a, line, int(pair[1])))
					if maxf(g1, g2) > worst:
						worst = maxf(g1, g2)
						worst_at = Vector3(line if g1 >= g2 else a, float(pair[1]), a if g1 >= g2 else line)
	_expect(worst < FrontierTerrain.SKIRT_DEPTH, "cracks: largest LOD gap on any chunk edge %.3f m at (x, step, z) %s < skirt %.1f m" % [worst, worst_at, FrontierTerrain.SKIRT_DEPTH])


func _check_flat() -> void:
	var bad := 0
	var fbad := 0
	var n := 0
	for x in range(-26, 27):
		for z in range(-26, 27):
			n += 1
			var jx := x + (0.37 if x < 26 else -0.37)
			var jz := z + (0.61 if z < 26 else -0.61)
			if FrontierTerrain.height_at(x, z) != 0.0 or FrontierTerrain.height_at(jx, jz) != 0.0:
				bad += 1
			if FrontierTerrain.forest_density(x, z) != 0.0:
				fbad += 1
	for x in range(-14, 15):
		for z in range(-175, -11):
			n += 1
			var jx := x + (0.29 if x < 14 else -0.29)
			var jz := z + (0.53 if z < -12 else -0.53)
			if FrontierTerrain.height_at(x, z) != 0.0 or FrontierTerrain.height_at(jx, jz) != 0.0:
				bad += 1
			if FrontierTerrain.forest_density(x, z) != 0.0:
				fbad += 1
	_expect(bad == 0 and fbad == 0, "flat: height_at == 0 and forest_density == 0 on %d flat-zone points (%d / %d off)" % [n, bad, fbad])
	# Terrain relief outside (sanity: it is not flat everywhere).
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var lo := INF
	var hi := -INF
	for i in 2000:
		var p := _random_outside(rng)
		var h := FrontierTerrain.height_at(p.x, p.y)
		lo = minf(lo, h)
		hi = maxf(hi, h)
	_expect(hi - lo > 10.0, "flat: relief outside the flat zones %.1f .. %.1f m" % [lo, hi])


func _check_layers() -> void:
	var worst := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 2000:
		var p := Vector2(rng.randf_range(-400, 400), rng.randf_range(-400, 400))
		var w := FrontierTerrain.ground_layers(p.x, p.y)
		var s := 0.0
		for v in w:
			s += v
		worst = maxf(worst, absf(s - 1.0))
	_expect(worst < 1e-4, "layers: ground_layers sums to 1 (worst error %.6f)" % worst)
	var cases := [["fort floor", Vector2(3, -2), FrontierTerrain.LAYER_DIRT],
			["lane strip", Vector2(0, -80), FrontierTerrain.LAYER_DIRT],
			["lane shoulder", Vector2(9.5, -80), -1],
			["deep forest", Vector2(-150, 60), FrontierTerrain.LAYER_FOREST_FLOOR]]
	for c: Array in cases:
		var w := FrontierTerrain.ground_layers(c[1].x, c[1].y)
		var ok := false
		if int(c[2]) >= 0:
			ok = w[int(c[2])] > 0.6
		else:
			ok = w[FrontierTerrain.LAYER_GRASS] + w[FrontierTerrain.LAYER_DRY_GRASS] > 0.6
		_expect(ok, "layers: %s at %s -> %s" % [c[0], c[1], Array(w).map(func(v): return snappedf(v, 0.01))])
	var fd_forest := FrontierTerrain.forest_density(-150, 60)
	var fd_edge := FrontierTerrain.forest_density(-30, 0)
	_expect(fd_forest > 0.6 and fd_edge < 0.5, "layers: forest_density deep forest %.2f, clearing edge (-30, 0) %.2f" % [fd_forest, fd_edge])


func _check_api() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var pts := PackedVector2Array()
	for i in 20000:
		pts.append(Vector2(rng.randf_range(-390, 390), rng.randf_range(-390, 390)))
	var names := ["height_at", "normal_at", "forest_density", "ground_layers", "grass_height_at"]
	var line := "api: us per call"
	var fail := false
	for nm: String in names:
		var t := Time.get_ticks_usec()
		for p in pts:
			match nm:
				"height_at": FrontierTerrain.height_at(p.x, p.y)
				"normal_at": FrontierTerrain.normal_at(p.x, p.y)
				"forest_density": FrontierTerrain.forest_density(p.x, p.y)
				"ground_layers": FrontierTerrain.ground_layers(p.x, p.y)
				"grass_height_at": FrontierTerrain.grass_height_at(p.x, p.y)
		var us := float(Time.get_ticks_usec() - t) / pts.size()
		line += " %s=%.2f" % [nm, us]
		if us > (6.0 if nm == "ground_layers" else 3.0):
			fail = true
	_expect(not fail, line + " (loop overhead included)")


func _check_footsteps() -> void:
	# The steepest samples: scan a grid for the largest slopes.
	var steep := []
	for x in range(-395, 396, 3):
		for z in range(-395, 396, 3):
			var n := FrontierTerrain.normal_at(x, z)
			if n.y < 0.8:
				steep.append([n.y, Vector2(x, z)])
	steep.sort_custom(func(a, b): return a[0] < b[0])
	var tested := 0
	var miss := 0
	var min_ny := 1.0
	for s: Array in steep.slice(0, 200):
		var p: Vector2 = s[1]
		var h := FrontierTerrain.collision_height_at(p.x, p.y)
		var from := Vector3(p.x, h + 0.1, p.y)
		var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 0.6)
		var hit := space.intersect_ray(q)
		tested += 1
		min_ny = minf(min_ny, float(s[0]))
		if hit.is_empty():
			miss += 1
	_expect(tested > 0 and miss == 0, "footsteps: 0.6 m down-ray hits on the %d steepest samples (down to %.0f deg): %d misses" % [tested, rad_to_deg(acos(min_ny)), miss])


func _check_surfaces() -> void:
	var cases := [
		["east path", Vector2(100.0, 51.0), "dirt"],
		["woodcutters' track", Vector2(-100.0, -18.0), "dirt"],
		["hunters' trail", Vector2(-38.0, 84.0), "dirt"],
		["outcrop on the ridge", Vector2(-170.0, 85.0), "stone"],
		["meadow outside the clearing", Vector2(-40.0, 25.0), "grass"],
		["deep forest floor", Vector2(-150.0, 60.0), "grass"],
	]
	for c: Array in cases:
		var p: Vector2 = c[1]
		var hit := _ground_ray(p.x, p.y)
		var s := "(no hit)" if hit.is_empty() else Sfx.surface_of(hit.collider, hit.position, hit.normal)
		_expect(s == c[2], "surfaces: %s at %s = %s (got %s)" % [c[0], p, c[2], s])


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
	print(("  ok   " if cond else "  FAIL ") + msg)
