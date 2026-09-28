extends SceneTree
## The ridden horse on the Frontier level's real hills (HorseTerrain):
##
##   Godot --headless --path . -s tests/horse/horse_hills.gd -- [out=/tmp/hills] [gaits=walk,trot]
##   Godot --path . --resolution 1100x620 -s tests/horse/horse_hills.gd -- out=/tmp/hills strips=1   # side-view filmstrips
##       [only=moderate,steep] [cam=4.5] [gaits=walk]
##
## 1. Hills: straight lines on the level's terrain (FrontierTerrain height field) with a steady
##    grade, clear of trees and rocks, in three classes (gentle ~8-14 deg, moderate ~14-21 deg,
##    steep ~21-29 deg), plus a slope steeper than HorseTerrain.UP_LIMIT.
## 2. Rides: the player mounts the horse and rides each line up and down at walk and trot (riding
##    input: W held, the cruise gait set). Per run, over the part of the line on the hill:
##    - body pitch against the ground slope (uphill it follows the slope; downhill it stays a little
##      under it, the croup lowered);
##    - planted hooves: the toe's height above the ground under it (sinking / floating), and how far
##      a toe on the ground (within 2 cm) moves over its stance (sliding);
##    - speed: kept at or under the slope cap, the root's horizontal speed against the gait speed;
##    - the rider's incline additive phase (forward uphill, back downhill);
##    - the root stays on the floor from the run-up on (no hop over a height-field edge or, downhill,
##      the top edge).
## 3. Refusal: the horse ridden at a slope steeper than UP_LIMIT stops before it and does not climb.
## With strips=1 (window): a side-view filmstrip per run (<out>/strip_<line>_<dir>_<gait>.png).
## Prints HORSE HILLS OK / FAILED and writes <out>/hills_report.json.

const CLASSES := [["gentle", 8.0, 14.0], ["moderate", 14.0, 21.0], ["steep", 21.0, 29.0]]
const LINE_LEN := 16.0
const RUN_UP := 5.0
## Tolerances.
const PITCH_TOL := 4.0          # deg: uphill body pitch against the slope
const TOE_SINK_TOL := 0.025     # m: a planted toe below the ground (2nd percentile)
const TOE_FLOAT_TOL := 0.035    # m: above it (98th percentile)
const SLIDE_TOL := 0.02         # m: a grounded toe's travel over its stance (95th percentile)
const SPEED_TOL := 0.12         # fraction: root horizontal speed against the gait speed

var out := "user://horse_hills"
var strips := false
var gaits := ["walk", "trot"]
var only := []                  ## slope classes to ride (all when empty)
var cam_dist := 7.0             ## filmstrip camera distance (m)
var fails: Array[String] = []
var report := {}
var player: FrontierPlayer
var horse: Horse
var toe_local := {}
var strip_cam: Camera3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("strips="):
			strips = a.substr(7) == "1"
		elif a.begins_with("gaits="):
			gaits = Array(a.substr(6).split(","))
		elif a.begins_with("only="):
			only = Array(a.substr(5).split(","))
		elif a.begins_with("cam="):
			cam_dist = float(a.substr(4))
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	for i in 30:
		await physics_frame
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	var hs := current_scene.find_children("*", "Horse", true, false)
	if player == null or hs.is_empty():
		print("HORSE HILLS FAILED: level or horse missing")
		quit(1)
		return
	player.ignore_mouse_capture = true
	horse = hs[0]
	for leg: String in HorseTerrain.LEGS:
		var hb := horse.skeleton.find_bone(HorseTerrain.LEGS[leg][4])
		var toe: Array = horse.meta.sockets.hoof_toes[leg][1]
		toe_local[leg] = horse.skeleton.get_bone_global_rest(hb).affine_inverse() * Vector3(toe[0], toe[1], toe[2])
	if strips:
		strip_cam = Camera3D.new()
		strip_cam.fov = 38.0
		strip_cam.far = 400.0
		current_scene.add_child(strip_cam)
	var lines := _find_lines()
	if not player.mount(horse):
		fails.append("player could not mount the horse")
	else:
		for ln: Array in lines:
			if not only.is_empty() and not ln[0] in only:
				continue
			for dir in ["up", "down"]:
				for g: String in gaits:
					await _ride(ln, dir, g)
			if ln[0] != "gentle":
				await _traverse(ln)
				await _stand(ln)
		var steep := _find_steep()
		if steep.is_empty():
			print("  (no slope steeper than %.0f deg with a clear approach found: refusal not tested)" % HorseTerrain.UP_LIMIT)
			report["refusal"] = "not found"
		else:
			await _refusal(steep)
		player.dismount()
	var f := FileAccess.open(out + "/hills_report.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
	print("HORSE HILLS %s %s" % ["OK" if fails.is_empty() else "FAILED", fails])
	quit(0 if fails.is_empty() else 1)


func _check(ok: bool, msg: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + msg)
	if not ok:
		fails.append(msg)


# ---------------------------------------------------------------------------
# Finding hills
# ---------------------------------------------------------------------------
## One line per slope class: [class, start (bottom), end (top), mean slope deg].
func _find_lines() -> Array:
	var best := {}
	for zi in range(-230, 231, 6):
		for xi in range(-230, 231, 6):
			var p := Vector3(xi, 0.0, zi)
			if FrontierTerrain.flat_distance(p.x, p.z) < 4.0:
				continue
			var n := FrontierTerrain.normal_at(p.x, p.z)
			if n.y > cos(deg_to_rad(6.0)):
				continue
			# straight up the fall line
			var dir := Vector3(-n.x, 0.0, -n.z).normalized()
			var fit := _fit(p - dir * LINE_LEN * 0.5, dir, LINE_LEN)
			if fit.is_empty():
				continue
			for c: Array in CLASSES:
				if fit.slope < c[1] or fit.slope > c[2] or fit.rms > 0.12:
					continue
				var key: String = c[0]
				var score: float = -fit.rms - absf(fit.slope - 0.5 * (c[1] + c[2])) * 0.01
				if best.has(key) and best[key][4] >= score:
					continue
				var a: Vector3 = p - dir * (LINE_LEN * 0.5 + RUN_UP + 3.0)
				var b: Vector3 = p + dir * (LINE_LEN * 0.5 + RUN_UP + 3.0)
				if not _clear(a, b):
					continue
				best[key] = [key, p - dir * LINE_LEN * 0.5, p + dir * LINE_LEN * 0.5, fit.slope, score]
	var outp := []
	for c: Array in CLASSES:
		if best.has(c[0]):
			var l: Array = best[c[0]]
			print("  %s hill: %s -> %s, %.1f deg" % [l[0], l[1], l[2], l[3]])
			outp.append(l)
		else:
			print("  (no clear %s hill found)" % c[0])
	report["lines"] = outp.map(func(l: Array) -> Dictionary: return {"class": l[0], "bottom": str(l[1]), "top": str(l[2]), "slope_deg": snappedf(l[3], 0.1)})
	return outp


## Least-squares slope of the terrain along a line: {slope (deg), rms (m)} or {} off the map.
func _fit(p0: Vector3, dir: Vector3, length: float) -> Dictionary:
	var xs := []
	var ys := []
	for i in 17:
		var t := length * i / 16.0
		var q := p0 + dir * t
		if absf(q.x) > 380.0 or absf(q.z) > 380.0:
			return {}
		xs.append(t)
		ys.append(FrontierTerrain.height_at(q.x, q.z))
	var n := float(xs.size())
	var mx := 0.0
	var my := 0.0
	for i in xs.size():
		mx += xs[i] / n
		my += ys[i] / n
	var sxy := 0.0
	var sxx := 0.0
	for i in xs.size():
		sxy += (xs[i] - mx) * (ys[i] - my)
		sxx += (xs[i] - mx) * (xs[i] - mx)
	var k := sxy / sxx
	var rms := 0.0
	for i in xs.size():
		var e: float = ys[i] - (my + k * (xs[i] - mx))
		rms += e * e / n
	return {"slope": rad_to_deg(atan(k)), "rms": sqrt(rms)}


## Nothing solid but the terrain and the low obstacles along a..b (a 1.4 m wide horse box).
func _clear(a: Vector3, b: Vector3) -> bool:
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 1.4, 1.2)
	q.shape = box
	var dir := (b - a)
	dir.y = 0.0
	var L := dir.length()
	dir = dir.normalized()
	var steps := int(L / 0.8)
	for s in steps + 1:
		var p := a + dir * (L * s / steps)
		var y := FrontierTerrain.height_at(p.x, p.z)
		q.transform = Transform3D(Basis.looking_at(dir), Vector3(p.x, y + 1.25, p.z))
		for h in space.intersect_shape(q, 6):
			var c := h.collider as Node
			if c and not c.is_in_group(&"terrain") and not c.is_in_group(HorseTerrain.LOW_GROUP):
				return false
	return true


## A slope steeper than UP_LIMIT (over at least 3 m) with a clear, gentler approach below it:
## [approach start, the foot of the steep part, direction, slope deg] or [].
func _find_steep() -> Array:
	var lim: float = HorseTerrain.UP_LIMIT + 2.0
	for zi in range(-230, 231, 3):
		for xi in range(-230, 231, 3):
			var p := Vector3(xi, 0.0, zi)
			var n := FrontierTerrain.normal_at(p.x, p.z)
			if n.y > cos(deg_to_rad(lim)) or FrontierTerrain.flat_distance(p.x, p.z) < 4.0:
				continue
			var dir := Vector3(-n.x, 0.0, -n.z).normalized()
			var fit := _fit(p - dir * 1.5, dir, 3.0)
			if fit.is_empty() or fit.slope < lim:
				continue
			# a gentler approach of 8 m below the foot
			var foot := p - dir * 2.0
			var app := _fit(foot - dir * 8.0, dir, 8.0)
			if app.is_empty() or app.slope > 18.0:
				continue
			if not _clear(foot - dir * 9.0, foot):
				continue
			return [foot - dir * 8.0, foot, dir, fit.slope]
	return []


# ---------------------------------------------------------------------------
# Rides
# ---------------------------------------------------------------------------
func _place(at: Vector3, dir: Vector3) -> void:
	horse.speed = 0.0
	horse.velocity = Vector3.ZERO
	horse.global_position = Vector3(at.x, FrontierTerrain.height_at(at.x, at.z) + 0.05, at.z)
	horse.rotation = Vector3(0.0, atan2(-dir.x, -dir.z), 0.0)
	player.yaw = horse.rotation.y
	player.pitch = deg_to_rad(-10.0)


func _ground_y(p: Vector3) -> float:
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.5, p + Vector3.DOWN * 2.5)
	q.exclude = [horse.get_rid()]
	var hit := space.intersect_ray(q)
	return (hit.position as Vector3).y if not hit.is_empty() else FrontierTerrain.height_at(p.x, p.z)


func _ride(ln: Array, dir_name: String, gait_name: String) -> void:
	var bottom: Vector3 = ln[1]
	var top: Vector3 = ln[2]
	var up := dir_name == "up"
	var a := bottom if up else top
	var b := top if up else bottom
	var dir := (b - a)
	dir.y = 0.0
	var L := dir.length()
	dir = dir.normalized()
	var slope: float = ln[3] * (1.0 if up else -1.0)
	var gait: int = Horse.GAIT_CLIPS.find(gait_name)
	_place(a - dir * RUN_UP, dir)
	horse.set_cruise_gait(gait)
	for i in 40:
		await physics_frame
	Input.action_press("move_forward")
	var pitch := []
	var toe_err := []
	var slides := []
	var speeds := []
	var incl := []
	var caps := []
	var stance := {}
	var off_floor := 0
	var frames := []
	var strip_every := 0
	var tag := "%s_%s_%s" % [ln[0], dir_name, gait_name]
	var t := 0
	var max_t := int((L + RUN_UP + 4.0) / 0.3 * 120.0)
	var cam_side := dir.cross(Vector3.UP).normalized()
	while t < max_t:
		await physics_frame
		t += 1
		var along := (horse.global_position - a).dot(dir)
		if along > L:
			break
		# off the ground without a jump (a hop over a crest or a height-field edge), run-up included
		if not horse.is_on_floor() and not horse.airborne and along > 1.0 - RUN_UP:
			off_floor += 1
		if strips and along > 1.0 and frames.size() < 8:
			if strip_every <= 0:
				strip_every = maxi(int(1.1 * 120.0 / maxf(horse.speed, 0.3)), 18) if gait_name == "walk" else 30
				frames.append(await _strip_frame(cam_side))
			strip_every -= 1
		if along < 1.5:
			continue
		# on the hill
		pitch.append([horse.terrain.body_pitch_deg, horse.terrain.slope_deg])
		incl.append(player._rider_link.incline_phase() if player._rider_link else 0.5)
		var rv := horse.get_real_velocity()
		if horse.speed > 0.2:
			speeds.append(Vector2(rv.x, rv.z).length() / horse.speed)
		caps.append([horse.speed, horse.terrain.speed_cap()])
		for leg: String in HorseTerrain.LEGS:
			var hb := horse.skeleton.find_bone(HorseTerrain.LEGS[leg][4])
			var gp := horse.skeleton.global_transform * horse.skeleton.get_bone_global_pose(hb)
			var toe: Vector3 = gp * (toe_local[leg] as Vector3)
			var on: bool = horse.terrain.planted[leg]
			if on:
				var e := toe.y - _ground_y(toe)
				toe_err.append(e)
				# the toe on the ground (within 2 cm) must not move
				if e < 0.02:
					if not stance.has(leg):
						stance[leg] = toe
					else:
						slides.append(Vector2(toe.x - stance[leg].x, toe.z - stance[leg].z).length())
			else:
				stance.erase(leg)
	Input.action_release("move_forward")
	for i in 200:
		await physics_frame
		if horse.speed < 0.05:
			break
	if strips and not frames.is_empty():
		_save_strip(frames, "%s/strip_%s.png" % [out, tag], "%s %s at %s: slope %.1f deg" % [dir_name, ln[0], gait_name, absf(slope)])
	# --- numbers
	var rec := {"slope_deg": snappedf(slope, 0.1), "samples": pitch.size()}
	if pitch.is_empty():
		_check(false, "%s: the horse never got onto the hill" % tag)
		report[tag] = rec
		return
	var pm := 0.0
	var sm := 0.0
	for p: Array in pitch:
		pm += p[0] / pitch.size()
		sm += p[1] / pitch.size()
	toe_err.sort()
	slides.sort()
	speeds.sort()
	var sink: float = -toe_err[int(toe_err.size() * 0.02)] if not toe_err.is_empty() else 0.0
	var flt: float = toe_err[int(toe_err.size() * 0.98)] if not toe_err.is_empty() else 0.0
	var slide95: float = slides[int(slides.size() * 0.95)] if not slides.is_empty() else 0.0
	var spd50: float = speeds[speeds.size() / 2] if not speeds.is_empty() else 1.0
	var inc_m := 0.0
	for v: float in incl:
		inc_m += v / incl.size()
	var over := 0.0
	for c: Array in caps:
		over = maxf(over, c[0] - c[1])
	rec.merge({"ground_slope_measured": snappedf(sm, 0.1), "body_pitch_mean": snappedf(pm, 0.1),
			"toe_sink_p2": snappedf(sink, 0.001), "toe_float_p98": snappedf(flt, 0.001),
			"planted_slide_p95": snappedf(slide95, 0.001), "speed_ratio_median": snappedf(spd50, 0.001),
			"speed_over_cap_max": snappedf(over, 0.01), "incline_phase_mean": snappedf(inc_m, 0.01),
			"off_floor_ticks": off_floor, "final_speed": snappedf(horse.speed, 0.01)})
	report[tag] = rec
	print("  %s: %s" % [tag, rec])
	if up:
		_check(absf(pm - sm) < PITCH_TOL and pm > 0.5 * absf(slope),
				"%s: body pitch %.1f deg follows the slope %.1f deg (measured %.1f)" % [tag, pm, slope, sm])
		_check(inc_m < 0.5 - absf(slope) / 150.0, "%s: the rider leans forward (incline phase %.2f < 0.5)" % [tag, inc_m])
	else:
		_check(pm < -0.5 * absf(slope) and pm > sm - 1.0,
				"%s: body pitch %.1f deg follows the slope %.1f deg, a little under it (croup lowered)" % [tag, pm, sm])
		_check(inc_m > 0.5 + absf(slope) / 150.0, "%s: the rider leans back (incline phase %.2f > 0.5)" % [tag, inc_m])
	_check(sink < TOE_SINK_TOL and flt < TOE_FLOAT_TOL,
			"%s: planted toes on the ground (sink %.3f m, float %.3f m)" % [tag, sink, flt])
	_check(slide95 < SLIDE_TOL, "%s: toes on the ground stay put (travel over a stance p95 %.3f m)" % [tag, slide95])
	_check(absf(spd50 - 1.0) < SPEED_TOL, "%s: root horizontal speed %.2f x the gait speed" % [tag, spd50])
	_check(over < 0.3, "%s: speed within the slope cap (max over %.2f m/s)" % [tag, over])
	_check(off_floor <= 2, "%s: on the ground throughout, run-up included (%d ticks off the floor)" % [tag, off_floor])


## Across the hill (along its contour) at a walk: the legs on the downhill side reach down, the
## uphill ones flex; the toes stay on the ground and the body stays nearly level fore and aft.
func _traverse(ln: Array) -> void:
	var bottom: Vector3 = ln[1]
	var top: Vector3 = ln[2]
	var fall := (top - bottom)
	fall.y = 0.0
	fall = fall.normalized()
	var dir := fall.cross(Vector3.UP).normalized()
	var mid := (bottom + top) * 0.5
	var a := mid - dir * 6.0
	# a clear line along the contour, else the other way round
	if not _clear(a - dir * 3.0, a + dir * 15.0):
		dir = -dir
		a = mid - dir * 6.0
		if not _clear(a - dir * 3.0, a + dir * 15.0):
			print("  (%s hill: no clear traverse)" % ln[0])
			return
	_place(a, dir)
	horse.set_cruise_gait(Horse.Gait.WALK)
	for i in 40:
		await physics_frame
	Input.action_press("move_forward")
	var toe_err := []
	var pitch := []
	var misses := []
	var cost := []
	for t in 1200:
		await physics_frame
		var along := (horse.global_position - a).dot(dir)
		if along > 11.0:
			break
		if along < 1.5:
			continue
		pitch.append(absf(horse.terrain.body_pitch_deg))
		cost.append(horse.terrain.cost_us)
		for leg: String in HorseTerrain.LEGS:
			if horse.terrain.planted[leg]:
				var hb := horse.skeleton.find_bone(HorseTerrain.LEGS[leg][4])
				var gp := horse.skeleton.global_transform * horse.skeleton.get_bone_global_pose(hb)
				var toe: Vector3 = gp * (toe_local[leg] as Vector3)
				toe_err.append(toe.y - _ground_y(toe))
				misses.append(horse.terrain.ik_miss[leg])
	Input.action_release("move_forward")
	for i in 200:
		await physics_frame
		if horse.speed < 0.05:
			break
	var tag := "%s_traverse_walk" % ln[0]
	if toe_err.is_empty():
		_check(false, "%s: no samples" % tag)
		return
	toe_err.sort()
	misses.sort()
	cost.sort()
	var sink: float = -toe_err[int(toe_err.size() * 0.02)]
	var flt: float = toe_err[int(toe_err.size() * 0.98)]
	var pm := 0.0
	for p: float in pitch:
		pm = maxf(pm, p)
	report[tag] = {"toe_sink_p2": snappedf(sink, 0.001), "toe_float_p98": snappedf(flt, 0.001), "max_abs_pitch": snappedf(pm, 0.1),
			"ik_miss_p98": snappedf(misses[int(misses.size() * 0.98)], 0.001), "terrain_update_us_median": cost[cost.size() / 2]}
	print("  %s: %s" % [tag, report[tag]])
	_check(sink < TOE_SINK_TOL and flt < TOE_FLOAT_TOL, "%s: planted toes on the ground across the slope (sink %.3f m, float %.3f m)" % [tag, sink, flt])
	_check(pm < 6.0, "%s: the body stays level fore and aft on the contour (max |pitch| %.1f deg)" % [tag, pm])


## Standing on the hill facing up it for 3 s: pitched with it, the hooves still (the idle).
func _stand(ln: Array) -> void:
	var bottom: Vector3 = ln[1]
	var top: Vector3 = ln[2]
	var dir := (top - bottom)
	dir.y = 0.0
	dir = dir.normalized()
	_place((bottom + top) * 0.5, dir)
	# (the placing leaves the toe locks where the last ride had them, up to LOCK_MAX off the idle's
	# toes; once the horse has stopped they settle back at LOCK_SETTLE, which is over within 2 s:
	# the hooves are measured after that)
	for i in 240:
		await physics_frame
	var start := {}
	var worst := 0.0
	var err := 0.0
	for t in 360:
		await physics_frame
		for leg: String in HorseTerrain.LEGS:
			var hb := horse.skeleton.find_bone(HorseTerrain.LEGS[leg][4])
			var gp := horse.skeleton.global_transform * horse.skeleton.get_bone_global_pose(hb)
			var toe: Vector3 = gp * (toe_local[leg] as Vector3)
			if not start.has(leg):
				start[leg] = toe
			worst = maxf(worst, toe.distance_to(start[leg]))
			if t % 30 == 0:
				err = maxf(err, absf(toe.y - _ground_y(toe)))
	var tag := "%s_stand" % ln[0]
	report[tag] = {"pitch": snappedf(horse.terrain.body_pitch_deg, 0.1), "slope": snappedf(horse.terrain.slope_deg, 0.1),
			"toe_travel_max": snappedf(worst, 0.001), "toe_ground_err_max": snappedf(err, 0.001), "gait": Horse.GAIT_CLIPS[horse.gait]}
	print("  %s: %s" % [tag, report[tag]])
	_check(horse.gait == Horse.Gait.IDLE and worst < 0.03 and err < 0.03 and absf(horse.terrain.body_pitch_deg - horse.terrain.slope_deg) < PITCH_TOL,
			"%s: standing on the slope: pitch %.1f deg (slope %.1f), toes move %.3f m, off the ground %.3f m" % [
			tag, horse.terrain.body_pitch_deg, horse.terrain.slope_deg, worst, err])


func _refusal(st: Array) -> void:
	var start: Vector3 = st[0]
	var foot: Vector3 = st[1]
	var dir: Vector3 = st[2]
	_place(start, dir)
	horse.set_cruise_gait(Horse.Gait.TROT)
	for i in 40:
		await physics_frame
	Input.action_press("move_forward")
	var max_along := -INF
	var y0 := horse.global_position.y
	var max_rise := 0.0
	for i in 1200:
		await physics_frame
		max_along = maxf(max_along, (horse.global_position - foot).dot(dir))
		max_rise = maxf(max_rise, horse.global_position.y - FrontierTerrain.height_at(foot.x, foot.z))
	var stopped := horse.speed < 0.05
	Input.action_release("move_forward")
	report["refusal"] = {"slope_deg": snappedf(st[3], 0.1), "furthest_past_foot": snappedf(max_along, 0.01),
			"rise_above_foot": snappedf(max_rise, 0.01), "stopped": stopped, "grade_ahead": snappedf(horse.terrain.grade_ahead_deg, 0.1)}
	print("  refusal: %s" % report.refusal)
	_check(stopped and max_along < 1.5 and max_rise < 1.0,
			"refuses a %.0f deg slope: stopped %s, %.2f m past its foot, root %.2f m above it" % [st[3], stopped, max_along, max_rise])


# ---------------------------------------------------------------------------
# Filmstrips
# ---------------------------------------------------------------------------
func _strip_frame(side: Vector3) -> Image:
	var c := horse.global_position + Vector3.UP * 1.0
	strip_cam.global_position = c + side * cam_dist + Vector3.UP * 0.4 * cam_dist / 7.0
	strip_cam.look_at(c)
	strip_cam.current = true
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	player.camera.current = true
	var w := img.get_width() / 2
	var h := img.get_height() / 2
	img.resize(w, h)
	return img


func _save_strip(frames: Array, path: String, _title: String) -> void:
	var w: int = (frames[0] as Image).get_width()
	var h: int = (frames[0] as Image).get_height()
	var cols := 4
	var rows := int(ceil(frames.size() / float(cols)))
	var img := Image.create(w * cols, h * rows, false, (frames[0] as Image).get_format())
	for i in frames.size():
		img.blit_rect(frames[i], Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	img.save_png(path)
	print("saved ", path)
