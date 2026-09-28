extends SceneTree
## Rides the player's horse through shrub and sapling patches of the Frontier level (needs a
## window: the vegetation builds its shrubs and saplings only when it renders):
##
##   Godot --path . --resolution 1280x720 -s tests/horse/horse_shrub_ride.gd -- out=/tmp/shrubs [paths=3] [shots=1]
##
## 1. Survey: every hazel shrub and sapling (FrontierVegetation layout kinds 5-9) within
##    SURVEY_RADIUS of the fort, and the colliders around its stem (a trunk, stump, log or rock
##    hiding in a bush still blocks, as it should).
## 2. Paths: straight 24 m lines through the densest patches (at least MIN_PLANTS stems within
##    0.9 m of the line) on gentle ground, with nothing solid in the horse's way but the terrain and
##    the low obstacles it steps over (stumps and logs, HorseTerrain.LOW_GROUP; counted).
## 3. Rides: the player mounts the horse and rides each path at walk, trot and canter by the
##    riding input (W held, the cruise gait set); a ride passes when the horse keeps its speed
##    (real speed >= 90 % of the commanded speed after the start) and reaches the far end, with
##    nothing but the terrain in its slide collisions. Gameplay-camera shots in the patch.
## 4. Trees still block: ridden at a tree trunk at a trot, the horse stops at it.
## Prints SHRUB RIDE OK / FAILED.

const SURVEY_RADIUS := 170.0
const PATH_HALF := 12.0
const MIN_PLANTS := 3
const GAITS := [["walk", Horse.Gait.WALK], ["trot", Horse.Gait.TROT], ["canter", Horse.Gait.CANTER]]

var out := "user://horse_shrubs"
var n_paths := 3
var shots := true
var fails: Array[String] = []
var player: FrontierPlayer
var horse: Horse
var veg: FrontierVegetation


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("paths="):
			n_paths = int(a.substr(6))
		elif a.begins_with("shots="):
			shots = a.substr(6) != "0"
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	for i in 30:
		await physics_frame
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	var vs := current_scene.find_children("*", "FrontierVegetation", true, false)
	var hs := current_scene.find_children("*", "Horse", true, false)
	if player == null or vs.is_empty() or hs.is_empty():
		print("SHRUB RIDE FAILED: level, vegetation or horse missing")
		quit(1)
		return
	player.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	veg = vs[0]
	horse = hs[0]
	var plants := _survey()
	var paths := _paths(plants)
	print("paths: %d" % paths.size())
	if paths.is_empty():
		fails.append("no shrub path found")
	elif not player.mount(horse):
		fails.append("player could not mount the horse")
	else:
		for pi in paths.size():
			for g: Array in GAITS:
				await _ride(pi, paths[pi], g[0], g[1])
		await _tree_blocks()
		player.dismount()
	print("SHRUB RIDE %s %s" % ["OK" if fails.is_empty() else "FAILED", fails])
	quit(0 if fails.is_empty() else 1)


## Shrubs and saplings near the fort: [position, kind]; prints what stands around their stems.
func _survey() -> Array:
	var L = veg.layout
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.6
	cyl.height = 1.4
	q.shape = cyl
	var res := []
	var kinds := {}
	var near := {}
	for i in L.plant_pos.size():
		var k: int = L.plant_kind[i]
		var p: Vector3 = L.plant_pos[i]
		if k < 5 or Vector2(p.x, p.z).length() > SURVEY_RADIUS:
			continue
		res.append([p, k])
		kinds[k] = int(kinds.get(k, 0)) + 1
		q.transform = Transform3D(Basis(), p + Vector3(0, 0.9, 0))
		for h in space.intersect_shape(q, 8):
			var nm := _body_kind(h.collider)
			if nm != "terrain":
				near[nm] = int(near.get(nm, 0)) + 1
	print("survey: shrubs / saplings within %d m: %d %s; colliders within 0.6 m of a stem: %s"
			% [SURVEY_RADIUS, res.size(), kinds, near])
	return res


func _body_kind(c: Object) -> String:
	if c == null:
		return "?"
	var n := c as Node
	if n == null:
		return str(c)
	if n.is_in_group(&"terrain"):
		return "terrain"
	return String(n.name).get_slice("_", 0)


## The densest straight paths through the plants: [start, end, plant count].
func _paths(plants: Array) -> Array:
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.1, 1.5, 2.4)
	q.shape = box
	var cand := []
	var used := {}
	for pl: Array in plants:
		var c: Vector3 = pl[0]
		if FrontierTerrain.flat_distance(c.x, c.z) < 6.0:
			continue
		for a in 12:
			var ang := a * PI / 12.0
			var dir := Vector3(sin(ang), 0.0, cos(ang))
			var p0 := c - dir * PATH_HALF
			var p1 := c + dir * PATH_HALF
			var n := 0
			for o: Array in plants:
				var v: Vector3 = o[0] - p0
				var t := v.dot(dir)
				if t < 2.0 or t > 2.0 * PATH_HALF - 2.0:
					continue
				if (v - dir * t).length() < 0.9:
					n += 1
			if n < MIN_PLANTS:
				continue
			# gentle ground (the hills are another test) and nothing solid in the way
			var ok := true
			var lows := {}
			var y0 := FrontierTerrain.height_at(p0.x, p0.z)
			var lo := INF
			var hi := -INF
			for s in 25:
				var p := p0 + dir * (2.0 * PATH_HALF * s / 24.0)
				var y := FrontierTerrain.height_at(p.x, p.z)
				lo = minf(lo, y)
				hi = maxf(hi, y)
				if FrontierTerrain.normal_at(p.x, p.z).y < cos(deg_to_rad(12.0)):
					ok = false
					break
				q.transform = Transform3D(Basis.looking_at(dir), Vector3(p.x, y + 0.8, p.z))
				for h in space.intersect_shape(q, 4):
					var hn := h.collider as Node
					if hn and hn.is_in_group(HorseTerrain.LOW_GROUP):
						lows[hn.get_instance_id() * 1000 + int(h.shape)] = true
					elif _body_kind(h.collider) != "terrain":
						ok = false
				if not ok:
					break
			if ok and hi - lo < 3.0:
				cand.append([p0, p1, n + 2 * lows.size(), y0, lows.size()])
	cand.sort_custom(func(a: Array, b: Array) -> bool: return a[2] > b[2])
	var outp := []
	for cd: Array in cand:
		var key := Vector2i(roundi((cd[0] as Vector3).x / 20.0), roundi((cd[0] as Vector3).z / 20.0))
		if used.has(key):
			continue
		used[key] = true
		outp.append(cd)
		print("  path %d: %s -> %s, score %d, %d stumps / logs on the line" % [outp.size() - 1, cd[0], cd[1], cd[2], cd[4]])
		if outp.size() >= n_paths:
			break
	return outp


func _ride(pi: int, path: Array, gait_name: String, gait: int) -> void:
	var p0: Vector3 = path[0]
	var p1: Vector3 = path[1]
	var dir := (p1 - p0)
	dir.y = 0.0
	dir = dir.normalized()
	# a run-up of 8 m before the patch
	var start := p0 - dir * 8.0
	start.y = FrontierTerrain.height_at(start.x, start.z) + 0.05
	horse.speed = 0.0
	horse.velocity = Vector3.ZERO
	horse.global_position = start
	horse.rotation = Vector3(0.0, atan2(-dir.x, -dir.z), 0.0)
	horse.set_cruise_gait(gait)
	player.yaw = horse.rotation.y
	player.pitch = deg_to_rad(-8.0)
	for i in 30:
		await physics_frame
	var cruise: float = Horse.CRUISE[gait]
	Input.action_press("move_forward")
	var hits := {}
	var worst := INF
	var reached := false
	var shot_done := false
	var total := p0.distance_to(p1) + 8.0
	for f in int((total / cruise + 8.0) * 120.0):
		await physics_frame
		for k in horse.get_slide_collision_count():
			var nm := _body_kind(horse.get_slide_collision(k).get_collider())
			if nm != "terrain":
				hits[nm] = int(hits.get(nm, 0)) + 1
		var along := (horse.global_position - start).dot(dir)
		# after the horse reached its cruise speed, it keeps it through the patch
		if along > 8.0 and horse.speed > 0.1:
			var rv := horse.get_real_velocity()
			worst = minf(worst, Vector2(rv.x, rv.z).length() / maxf(horse.speed, 0.01))
		if shots and not shot_done and along > 8.0 + PATH_HALF:
			shot_done = true
			await _shot("path%d_%s" % [pi, gait_name])
		if along >= total:
			reached = true
			break
	Input.action_release("move_forward")
	var ok := reached and hits.is_empty() and worst >= 0.9
	var msg := "path %d %s: reached %s, speed kept %.2f (min real / commanded), hits %s, gait %s at %.2f m/s" % [
			pi, gait_name, reached, worst, hits, Horse.GAIT_CLIPS[horse.gait], horse.speed]
	print(("  ok   " if ok else "  FAIL ") + msg)
	if not ok:
		fails.append(msg)
	for i in 240:
		await physics_frame
		if horse.speed < 0.05:
			break


## A trot straight at the nearest clear tree trunk: the horse stops at it.
func _tree_blocks() -> void:
	var space := player.get_world_3d().direct_space_state
	var best := []
	for n in get_nodes_in_group(&"trees"):
		var body := n as StaticBody3D
		if body == null:
			continue
		for cs in body.get_children():
			var c := cs as CollisionShape3D
			if c == null or not (c.shape is CylinderShape3D):
				continue
			var tp := c.global_position
			var r := (c.shape as CylinderShape3D).radius
			if Vector2(tp.x, tp.z).length() > 90.0 or FrontierTerrain.flat_distance(tp.x, tp.z) < 8.0:
				continue
			# an approach of 12 m on gentle ground, clear up to the trunk
			for a in 8:
				var dir := Vector3(cos(a * TAU / 8.0), 0.0, sin(a * TAU / 8.0))
				var start := tp - dir * (12.0 + r)
				var hit_end := tp - dir * (r + 1.6)
				if absf(FrontierTerrain.height_at(start.x, start.z) - FrontierTerrain.height_at(tp.x, tp.z)) > 1.5:
					continue
				var q := PhysicsShapeQueryParameters3D.new()
				var box := BoxShape3D.new()
				box.size = Vector3(1.2, 1.4, 1.2)
				q.shape = box
				var clear := true
				for k in 11:
					var p := start.lerp(hit_end, k / 10.0)
					q.transform = Transform3D(Basis(), Vector3(p.x, FrontierTerrain.height_at(p.x, p.z) + 0.9, p.z))
					for h in space.intersect_shape(q, 4):
						var hc := h.collider as Node
						if hc and not hc.is_in_group(&"terrain") and not hc.is_in_group(HorseTerrain.LOW_GROUP):
							clear = false
				if clear:
					best = [start, dir, tp, r]
					break
			if not best.is_empty():
				break
		if not best.is_empty():
			break
	if best.is_empty():
		fails.append("no clear approach to a tree trunk found")
		return
	var start: Vector3 = best[0]
	var dir: Vector3 = best[1]
	var tp: Vector3 = best[2]
	horse.speed = 0.0
	horse.velocity = Vector3.ZERO
	horse.global_position = Vector3(start.x, FrontierTerrain.height_at(start.x, start.z) + 0.05, start.z)
	horse.rotation = Vector3(0.0, atan2(-dir.x, -dir.z), 0.0)
	player.yaw = horse.rotation.y
	horse.set_cruise_gait(Horse.Gait.TROT)
	for i in 30:
		await physics_frame
	Input.action_press("move_forward")
	var trunk_hits := 0
	var furthest := -INF
	for i in 900:
		await physics_frame
		for k in horse.get_slide_collision_count():
			var c := horse.get_slide_collision(k).get_collider() as Node
			if c and c.is_in_group(&"trees"):
				trunk_hits += 1
		furthest = maxf(furthest, (horse.global_position - tp).dot(dir))
	Input.action_release("move_forward")
	var ok := trunk_hits > 0 and furthest < 0.0
	var msg := "a tree trunk still blocks: %d trunk contacts, the horse got to %.2f m before the trunk's centre" % [trunk_hits, -furthest]
	print(("  ok   " if ok else "  FAIL ") + msg)
	if not ok:
		fails.append(msg)
	for i in 120:
		await physics_frame


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var p := "%s/%s.png" % [out, name]
	root.get_viewport().get_texture().get_image().save_png(p)
	print("saved ", p)
