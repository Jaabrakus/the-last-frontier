extends SceneTree
## Gameplay-layout and surface regression check for the Frontier level. Every environment
## work package (lighting, terrain, vegetation, structures) must keep this passing.
## Headless is fine:
##
##   Godot --headless --path . -s tools/environment/check_layout.gd -- --no-capture
##
## Prints one "ok"/"FAIL" line per check and ends with LAYOUT CHECK PASSED / FAILED
## (exit code 0 / 1). What it checks:
##   spawn      player spawns at (0, 0.1, 6)
##   los        clear line of sight from the spawn (eye and gameplay camera) through the gate
##              to the 25 m dummy at (0, 1.2, -45), and from the firing line to every dummy
##   dummies    the six range dummies and the mover stand where frontier_level.gd puts them
##   flat       the fort (|x|,|z| < 26) and range lane (|x| < 14, -175 < z < -12) ground is flat
##              at y = 0 (a 2 m probe grid; structure tops are skipped)
##   ramps      walking north up both walkway ramps reaches the walkway (y > 2.2)
##   collide    walls, gate opening, cabin, storehouse, blockhouses, crates, barrels, trees,
##              rocks and the terrain all block rays where they should
##   surface    Sfx.surface_of (footsteps and projectile impacts) gives dirt / grass / wood /
##              stone / straw on the right things, and never "wood" on open ground
##   audio      the AmbienceBed, SfxVoices, Footsteps and WeaponAudio nodes exist
##   load       the level builds in under LOAD_BUDGET_MS headless (the animation suites reload
##              it for every test case)

const DUMMIES := [Vector3(-2.5, 0, -30), Vector3(0, 0, -45), Vector3(2.5, 0, -70),
		Vector3(-2.5, 0, -95), Vector3(0, 0, -120), Vector3(2.5, 0, -140)]
const MOVER := Vector3(-5, 0, -60)
## Headless level build + first frames. Baseline (flat-colour level): ~0.4 s.
const LOAD_BUDGET_MS := 2500.0

var player: FrontierPlayer
var space: PhysicsDirectSpaceState3D
var failures := PackedStringArray()


func _initialize() -> void:
	var t0 := Time.get_ticks_usec()
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var load_ms := (Time.get_ticks_usec() - t0) / 1000.0
	player = current_scene.get_node_or_null("Player") if current_scene else null
	if player == null:
		printerr("FAIL: level or player failed to load")
		print("LAYOUT CHECK FAILED")
		quit(1)
		return
	player.ignore_mouse_capture = true
	# The animation suites reload the level for every case, headless: keep the build fast.
	_expect(load_ms < LOAD_BUDGET_MS, "level load %.0f ms (budget %.0f ms headless)" % [load_ms, LOAD_BUDGET_MS])
	_expect(Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(0, 6)) < 0.05
			and absf(player.global_position.y - 0.1) < 0.15,
			"spawn at (0, 0.1, 6): %s" % player.global_position)
	await _physics(10)
	space = player.get_world_3d().direct_space_state

	_check_dummies()
	await _check_los()
	_check_flat()
	_check_collision()
	_check_surfaces()
	_check_audio()
	await _check_ramp(Vector3(14.0, 0.1, -8.0), "east")
	await _check_ramp(Vector3(-12.0, 0.1, -8.0), "west")

	if failures.is_empty():
		print("LAYOUT CHECK PASSED")
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("LAYOUT CHECK FAILED (%d)" % failures.size())
	quit(0 if failures.is_empty() else 1)


# --- Checks ------------------------------------------------------------------------------

func _check_dummies() -> void:
	var found: Array[Vector3] = []
	for n in _all(current_scene):
		if n is TargetDummy:
			found.append((n as TargetDummy)._start if "_start" in n else (n as Node3D).position)
	for p: Vector3 in DUMMIES + [MOVER]:
		var ok := false
		for f in found:
			if f.distance_to(p) < 0.05:
				ok = true
		_expect(ok, "dummy at %s" % p)


func _check_los() -> void:
	var target := Vector3(0, 1.2, -45)
	_expect(_hits_dummy(Vector3(0, 1.6, 6), target), "line of sight spawn eye (0,1.6,6) -> 25 m dummy (0,1.2,-45)")
	player.yaw = 0.0
	player.pitch = 0.0
	await _physics(5)
	_expect(_hits_dummy(player.camera.global_position, target),
			"line of sight gameplay camera %s -> 25 m dummy" % player.camera.global_position.snapped(Vector3.ONE * 0.01))
	for d: Vector3 in DUMMIES:
		var chest := d + Vector3(0, 1.2, 0)
		_expect(_hits_dummy(Vector3(0, 1.6, -20.6), chest), "line of sight firing line -> dummy %s" % chest)


func _check_flat() -> void:
	var bad := 0
	var worst := 0.0
	var probes := 0
	for x in range(-25, 26, 2):
		for z in range(-25, 26, 2):
			_flat_probe(Vector3(x, 0, z))
			probes += 1
	for x in range(-13, 14, 2):
		for z in range(-26, -174, -2):
			_flat_probe(Vector3(x, 0, z))
			probes += 1
	for r: Array in _flat_results:
		bad += 1
		worst = maxf(worst, absf(r[1]))
	_expect(bad == 0, "flat zones: %d probes, %d off y=0 (worst %.3f m)%s" % [probes, bad, worst,
			"" if bad == 0 else " e.g. %s" % str(_flat_results.slice(0, 4))])


var _flat_results := []


func _flat_probe(p: Vector3) -> void:
	var hit := _ray(p + Vector3.UP * 30.0, p + Vector3.DOWN * 5.0)
	if hit.is_empty():
		_flat_results.append([p, -99.0])
		return
	# Structures (crates, ramps, walkway, hay, rails) are not ground: only the ground's height
	# is checked.
	if not _is_ground(hit.collider):
		return
	var y: float = hit.position.y
	if absf(y) > 0.02:
		_flat_results.append([Vector2(p.x, p.z), snappedf(y, 0.001)])


func _check_collision() -> void:
	var cases := [
		["north wall (west of gate)", Vector3(-8, 1, -10), Vector3(-8, 1, -25), -15.81, "z"],
		["north wall (east of gate)", Vector3(8, 1, -10), Vector3(8, 1, -25), -15.81, "z"],
		["south wall", Vector3(3, 1, 12), Vector3(3, 1, 25), 15.81, "z"],
		["west wall", Vector3(-10, 1, 3), Vector3(-25, 1, 3), -15.81, "x"],
		["east wall", Vector3(10, 1, -3), Vector3(25, 1, -3), 15.81, "x"],
		["cabin", Vector3(-8, 1, 13), Vector3(-8, 1, 3), 9.5, "z"],
		["storehouse", Vector3(9, 1, 9), Vector3(9, 1, 0), 6.0, "z"],
		["NW blockhouse", Vector3(-10, 1, -14.5), Vector3(-20, 1, -14.5), -13.75, "x"],
		["SE blockhouse", Vector3(10, 1, 14.5), Vector3(20, 1, 14.5), 13.75, "x"],
		["stacked crates", Vector3(5.4, 3, -6.1), Vector3(5.4, -1, -6.1), 1.6, "y"],
		["barrel", Vector3(7, 3, -3), Vector3(7, -1, -3), 1.0, "y"],
		["walkway", Vector3(8, 4, -15), Vector3(8, 0.5, -15), 2.275, "y"],
	]
	for c: Array in cases:
		var hit := _ray(c[1], c[2])
		var axis: String = c[4]
		var got: float = hit.position[["x", "y", "z"].find(axis)] if not hit.is_empty() else INF
		_expect(not hit.is_empty() and absf(got - float(c[3])) < 0.35,
				"collides: %s (hit %s = %s, expected %.2f)" % [c[0], axis, str(snappedf(got, 0.01)) if got != INF else "none", c[3]])
	var gate := _ray(Vector3(0, 1.0, -10), Vector3(0, 1.0, -30))
	_expect(gate.is_empty(), "gate opening is clear at 1 m height (hit %s)" % ("none" if gate.is_empty() else str(gate.collider)))

	# Tree trunks: every tall wood collider outside the clearing blocks a horizontal ray.
	var trunks := _trunks()
	var blocked := 0
	var sample := 0
	var i := 0
	while i < trunks.size() and sample < 40:
		var t: Vector3 = trunks[i]
		i += maxi(1, trunks.size() / 40)
		sample += 1
		var h := _ray(t + Vector3(3, 1.2, 0.05), t + Vector3(-3, 1.2, 0.05))
		if not h.is_empty():
			blocked += 1
	_expect(trunks.size() >= 300, "tree trunk colliders outside the clearing: %d (>= 300)" % trunks.size())
	_expect(sample > 0 and blocked >= sample - 1, "tree trunks block rays: %d / %d sampled" % [blocked, sample])

	# Terrain: rays down anywhere in the world hit something.
	var misses := 0
	for x in range(-200, 201, 40):
		for z in range(-240, 161, 40):
			if _ray(Vector3(x, 200, z), Vector3(x, -100, z)).is_empty():
				misses += 1
	_expect(misses == 0, "ground collision everywhere in +-200 m (%d misses)" % misses)


func _check_surfaces() -> void:
	var down := [
		["fort floor", Vector3(0, 3, 0), "dirt"],
		["parade ground", Vector3(3, 3, -8), "dirt"],
		["range lane", Vector3(0, 3, -60), "dirt"],
		["lane 150 m", Vector3(1, 3, -150), "dirt"],
		["clearing outside the wall", Vector3(-21, 3, 0), "grass"],
		["lane shoulder", Vector3(9, 3, -80), "grass"],
		["walkway", Vector3(8, 4, -15), "wood"],
	]
	for c: Array in down:
		var hit := _ray(c[1], c[1] + Vector3.DOWN * 10.0)
		var s := _surface(hit)
		_expect(s == c[2], "surface: %s = %s (got %s)" % [c[0], c[2], s])
	var side := [
		["palisade", Vector3(8, 1, -10), Vector3(8, 1, -25), "wood"],
		["chimney", Vector3(-2.5, 3.4, 8), Vector3(-6, 3.4, 8), "stone"],
		["hay bale", Vector3(-5, 0.45, -32), Vector3(-5, 0.45, -38), "straw"],
		["dummy", Vector3(0, 1.2, -40), Vector3(0, 1.2, -50), "straw"],
	]
	for c: Array in side:
		var s := _surface(_ray(c[1], c[2]))
		_expect(s == c[3], "surface: %s = %s (got %s)" % [c[0], c[3], s])

	# Open ground outside the flat zones (hills, forest floor) must never read as wood; a ray
	# that lands on a trunk, stump or log is skipped.
	var wood := PackedStringArray()
	var n := 0
	for x in range(-180, 181, 30):
		for z in range(-220, 141, 30):
			if absf(x) < 30 and absf(z) < 30:
				continue
			var hit := _ray(Vector3(x, 200, z), Vector3(x, -100, z))
			if hit.is_empty() or not _is_ground(hit.collider):
				continue
			n += 1
			var s := _surface(hit)
			if s == "wood":
				wood.append("(%d,%d)" % [x, z])
	_expect(wood.is_empty() and n >= 100, "surface: open ground outside the flat zones is not wood (%d probes%s)" % [
			n, "" if wood.is_empty() else ", wood at " + ", ".join(wood.slice(0, 6))])

	# Rocks: group "rocks" (or legacy sphere-shaped bodies) must be stone.
	var rocks := 0
	var bad := 0
	for node in _all(current_scene):
		var body := node as StaticBody3D
		if body == null or body.has_meta(&"hit_part") or _in_dummy(body):
			continue
		var is_rock := body.is_in_group(&"rocks")
		if not is_rock:
			for ch in body.get_children():
				if ch is CollisionShape3D:
					is_rock = (ch as CollisionShape3D).shape is SphereShape3D
					break
		if not is_rock:
			continue
		rocks += 1
		if Sfx.surface_of(body, body.global_position + Vector3.UP * 2.0, Vector3.RIGHT) != "stone":
			bad += 1
	_expect(rocks > 0 and bad == 0, "surface: rocks are stone (%d rocks, %d not stone)" % [rocks, bad])


func _check_audio() -> void:
	for p: String in ["AmbienceBed", "SfxVoices", "Player/Footsteps", "Player/WeaponAudio"]:
		_expect(current_scene.get_node_or_null(p) != null or root.find_child(p.get_file(), true, false) != null,
				"audio node %s exists" % p)


func _check_ramp(start: Vector3, label: String) -> void:
	player.global_position = start
	player.velocity = Vector3.ZERO
	player.yaw = 0.0
	player.pitch = 0.0
	await _physics(20)
	Input.action_press("move_forward")
	var top := false
	for i in 600:
		await physics_frame
		if player.global_position.y > 2.2 and player.global_position.z < -14.5:
			top = true
			break
	Input.action_release("move_forward")
	await _physics(10)
	_expect(top, "walk up the %s ramp from %s: reached %s" % [label, start, player.global_position.snapped(Vector3.ONE * 0.01)])


# --- Helpers ------------------------------------------------------------------------------

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [player.get_rid()]
	return space.intersect_ray(q)


func _hits_dummy(from: Vector3, to: Vector3) -> bool:
	var hit := _ray(from, to + (to - from).normalized() * 0.5)
	if hit.is_empty():
		return false
	var n := hit.collider as Node
	while n:
		if n is TargetDummy:
			return true
		n = n.get_parent()
	print("    blocked by ", hit.collider, " at ", (hit.position as Vector3).snapped(Vector3.ONE * 0.01))
	return false


func _in_dummy(n: Node) -> bool:
	while n:
		if n is TargetDummy:
			return true
		n = n.get_parent()
	return false


func _surface(hit: Dictionary) -> String:
	if hit.is_empty():
		return "(no hit)"
	return Sfx.surface_of(hit.collider, hit.position, hit.normal)


## Ground = the terrain / floor colliders: in group "terrain", or a body whose first shape is
## a huge box, a height map or a trimesh.
func _is_ground(collider: Object) -> bool:
	var body := collider as CollisionObject3D
	if body == null:
		return false
	if body.is_in_group(&"terrain"):
		return true
	for ch in body.get_children():
		var cs := ch as CollisionShape3D
		if cs == null or cs.shape == null:
			continue
		if cs.shape is HeightMapShape3D or cs.shape is ConcavePolygonShape3D or cs.shape is WorldBoundaryShape3D:
			return true
		if cs.shape is BoxShape3D and (cs.shape as BoxShape3D).size.x > 100.0:
			return true
		return false
	return false


## Positions of tree trunk shapes (cylinders / capsules taller than 3 m) outside the clearing.
func _trunks() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for node in _all(current_scene):
		var cs := node as CollisionShape3D
		if cs == null or cs.shape == null:
			continue
		var h := 0.0
		if cs.shape is CylinderShape3D:
			h = (cs.shape as CylinderShape3D).height
		elif cs.shape is CapsuleShape3D:
			h = (cs.shape as CapsuleShape3D).height
		if h < 3.0:
			continue
		var p := cs.global_position
		if absf(p.x) < 26.0 and absf(p.z) < 26.0:
			continue
		out.append(Vector3(p.x, p.y - h * 0.5, p.z))
	return out


func _all(n: Node) -> Array[Node]:
	var out: Array[Node] = [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
	print(("  ok   " if cond else "  FAIL ") + msg)
