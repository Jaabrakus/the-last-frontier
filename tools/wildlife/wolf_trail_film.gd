extends SceneTree
## Films wolves on a blood trail (WildPlanner TRACK; user 2026-09-28: "show me"), on the real level with its wildlife,
## through a script camera (no text on screen: user rule for videos):
##   Godot --path . --fixed-fps 30 -s tools/wildlife/wolf_trail_film.gd -- wildlife=on out=<dir> [size=1280x720]
## One run of beats, JPG frames in <out>/ (for tools/showcase/video_encode.swift):
##   shot     a deer the player shot runs off bleeding and drops
##   track    the land short of deer, the pack crosses its blood, follows the drops and finds it dead: their kill
##   eat      they eat it
##   starving the land starving, another pack takes the player's fresh kill from under him and comes for him
## The view renders off-window (OffscreenView); input actions are unbound while it runs.

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")

var w: WildlifeSpawner
var p: FrontierPlayer
var g: WildGroup
var view
var out := ""
var size := Vector2i(1280, 720)
var frame := 0
var recording := false
var bites := 0
## The land's hunger held for the beat (the ecology's day ticks would move it).
var _h := 0.55
## The pack's own notice of the player held off (he stands by the camera, out of sight, while it films them).
var _calm := true
var _cam_pos := Vector3.INF
var _cam_look := Vector3.ZERO
var _used: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("size="):
			var wh := a.substr(5).split("x")
			size = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure()
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	var lvl := current_scene
	p = lvl.get_node("Player") as FrontierPlayer
	w = lvl.get_node_or_null("Wildlife") as WildlifeSpawner
	if w == null:
		push_error("wolf_trail_film: no wildlife (pass wildlife=on)")
		quit(1)
		return
	p.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for act in InputMap.get_actions():
		if not String(act).begins_with("ui_"):
			InputMap.action_erase_events(act)
	var rig := lvl.get_node_or_null("EnvironmentRig") as EnvironmentRig
	if rig and rig.clock_driver:
		rig.clock_driver.clock.running = false
		rig.clock_driver.clock.set_time(10.5)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = size
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, size)
	root.disable_3d = true
	if p.hud:
		p.hud.visible = false
	var tries := 0
	while (p.traversal == null or not p.traversal.world_ready) and tries < 2000:
		await process_frame
		tries += 1
	w._restock_t = 1e9
	await _run(60)
	var wolves := w.animals().filter(func(a: WildAnimal) -> bool: return a.species == "wolf" and not a.is_dead())
	g = (wolves[0] as WildAnimal).group if not wolves.is_empty() else null
	if g == null:
		push_error("wolf_trail_film: no wolf pack")
		quit(1)
		return
	for a: WildAnimal in wolves:
		if a.group != g:
			_away(a)
	p.wounds.struck.connect(func(_r: String, _s: String, _k: String, _d: float) -> void: bites += 1)
	await _shot_and_track()
	await _starving()
	print("WOLF TRAIL FILM DONE frames=%d" % frame)
	quit()


# --- Frames, the camera --------------------------------------------------------------------------

## `n` frames of game time (1 / fixed fps each), recording them when on.
func _run(n: int) -> void:
	for i in n:
		await process_frame
		_hold()
		if recording:
			_save()


func _save() -> void:
	frame += 1
	var img: Image = view.get_texture().get_image()
	img.save_jpg(out.path_join("f%05d.jpg" % frame), 0.9)


func _hold() -> void:
	w.ecology.pop.wolf = 5.0
	w.ecology.pop.bison = 0.0
	w.ecology.pop.deer = WildlifeEcology.PER_WOLF * 5.0 * (1.0 - _h)
	p.velocity = Vector3.ZERO
	if p.health < p.max_health * 0.6:
		p.health = p.max_health
		p.wounds.pool = 0.0
	if _calm and g:
		for a: WildAnimal in g.alive():
			a.awareness = 0.0


## The camera eased toward `pos`, looking at `look` (`k` of the way a frame; 1 cuts); kept above the ground.
func _cam(pos: Vector3, look: Vector3, k := 0.08) -> void:
	var gy := FrontierTerrain.height_at(pos.x, pos.z) + 1.2
	pos.y = maxf(pos.y, gy)
	# (pulled in before a trunk or a rock between it and what it looks at)
	var q := PhysicsRayQueryParameters3D.create(look, pos, 1)
	var hit: Dictionary = (view.camera as Camera3D).get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and not (hit.collider is WildAnimal or hit.collider is FrontierPlayer):
		pos = (hit.position as Vector3) + (look - pos).normalized() * 0.5
	if _cam_pos == Vector3.INF or k >= 1.0:
		_cam_pos = pos
		_cam_look = look
	else:
		_cam_pos = _cam_pos.lerp(pos, k)
		_cam_look = _cam_look.lerp(look, k * 1.5)
	view.camera.global_position = _cam_pos
	view.camera.look_at(_cam_look, Vector3.UP)
	view.camera.fov = 55.0


# --- The setting ---------------------------------------------------------------------------------

func _ground(at: Vector3) -> Vector3:
	return Vector3(at.x, FrontierTerrain.height_at(at.x, at.z) + 0.02, at.z)


func _away(a: WildAnimal) -> void:
	a.global_position = _ground(Vector3(-200.0, 0.0, 200.0 + randf() * 20.0))
	a.set_active(false)


## The player (hidden) by the camera: the land round the view streams in as it would round him.
func _player_at(at: Vector3, shown: bool) -> void:
	p.global_position = _ground(at) + Vector3.UP * 0.1
	p.velocity = Vector3.ZERO
	p.visible = shown


func _pack_at(pk: WildGroup, at: Vector3, need: float) -> void:
	var i := 0
	for a: WildAnimal in pk.alive():
		a.global_position = _ground(at + Vector3(float(i % 3) * 1.8, 0.0, floorf(i / 3.0) * 1.8))
		a.set_active(true)
		a.awareness = 0.0
		a.hunger = need
		a.health = float(a.data.health)
		a._enter(WildAnimal.State.IDLE, 1.0)
		i += 1
	pk.activity = WildGroup.Activity.BED
	pk.activity_since = w.now
	pk.dest_set = false
	pk.prey = null
	pk.carcass = null
	pk.trail_of = null
	pk.trail_wait = -1.0
	pk.after_player_until = -1e9
	pk.trails_left.clear()
	pk.shadowing = false
	pk.losses = 0
	pk.routed_until = -1e9


func _deer(at: Vector3) -> WildAnimal:
	for a in w.animals():
		if a.species == "deer" and not a.is_dead() and not (a in _used):
			_used.append(a)
			a.global_position = _ground(at)
			a.set_active(true)
			a.awareness = 0.0
			a._enter(WildAnimal.State.IDLE, 2.0)
			return a
	return null


## The player's shot from `from` into `d`: through the lungs (it runs on seconds and drops; WildlifeSpecies.WOUNDS).
func _shoot(d: WildAnimal, dmg: float, from: Vector3) -> void:
	var dir := d.global_position - from
	dir.y = 0.0
	d.apply_hit(dmg, _lungs_of(d), dir.normalized(), p, "body")


## The middle of `d`'s lungs (WildlifeSpecies.LUNGS in its body capsule): a shot through there is a lung shot.
func _lungs_of(d: WildAnimal) -> Vector3:
	var sb: StaticBody3D = d._zones[0]
	var cap := d._body_capsule()
	var axis := sb.global_basis.y.normalized()
	var hb := d._skel.find_bone(String((d.data.head as Array)[1]))
	if (d._skel.global_transform * d._skel.get_bone_global_pose(hb).origin - sb.global_position).dot(axis) < 0.0:
		axis = -axis
	var up := (Vector3.UP - axis * Vector3.UP.dot(axis)).normalized()
	var o: Array = WildlifeSpecies.LUNGS
	return sb.global_position + axis * cap.height * 0.5 * float(o[0]) + up * cap.radius * float(o[1])


func _flat(v: Vector3) -> Vector3:
	v.y = 0.0
	return v.normalized() if v.length_squared() > 1e-4 else Vector3.FORWARD


# --- The beats -----------------------------------------------------------------------------------

## A deer he shot runs off bleeding and drops; the pack crosses its blood, follows it to the deer and eats.
func _shot_and_track() -> void:
	_h = 0.55
	_calm = true
	w.animal_blood.clear()
	var from := Vector3(0.0, 0.0, -45.0)
	var spot := Vector3(2.0, 0.0, -80.0)
	var d := _deer(spot)
	if d == null:
		return
	d.rotation.y = PI
	d._flee_jitter = 0.0                # (it runs straight off down the open lane: the trail in the open)
	_player_at(spot + Vector3(-12.0, 0.0, 6.0), false)
	_cam(spot + Vector3(-8.0, 2.4, 5.0), spot + Vector3(0.0, 0.7, 0.0), 1.0)
	recording = true
	await _run(24)
	_shoot(d, 30.0, from)
	var start := d.global_position
	var dead_t := 0
	var n := 0
	var side := 1.0
	# the deer: followed from behind and to its side till it lies dead (the pack set down by the splash meanwhile)
	while n < 16 * 30 and dead_t < 50:
		var v := _flat(d.velocity if d.velocity.length() > 0.5 else d.global_position - start)
		var s := v.cross(Vector3.UP) * side
		_cam(d.global_position - v * 7.5 + s * 3.5 + Vector3.UP * 2.6, d.global_position + v * 1.5 + Vector3.UP * 0.5, 0.07)
		_player_at(_cam_pos - v * 4.0, false)
		if n == 4 * 30:
			_pack_at(g, start + _flat(from - start) * 10.0, 0.45)
		if d.is_dead():
			dead_t += 1
		await _run(1)
		n += 1
	# the pack on the trail: from behind the leader, looking on along the drops
	var lead := g.leader()
	_cam(lead.global_position + _flat(lead.global_position - d.global_position) * 7.0 + Vector3.UP * 3.0,
			lead.global_position, 1.0)
	n = 0
	var eating := 0
	while n < 60 * 30 and eating < 5 * 30:
		lead = g.leader()
		var ahead := _flat((g.dest if g.dest_set else d.global_position) - lead.global_position)
		if g.activity == WildGroup.Activity.EAT:
			ahead = _flat(d.global_position - lead.global_position)
		var s2 := ahead.cross(Vector3.UP)
		if g.activity == WildGroup.Activity.EAT and lead.global_position.distance_to(d.global_position) < 4.0:
			# at the kill: a slow turn round it
			eating += 1
			var a := float(eating) / 30.0 * 0.12
			var round_ := Vector3(cos(a), 0.0, sin(a))
			_cam(d.global_position + round_ * 7.5 + Vector3.UP * 2.6, d.global_position + Vector3.UP * 0.4, 0.05)
		else:
			var on := lead.global_position + ahead * 4.0
			_cam(lead.global_position - ahead * 5.5 + s2 * 1.6 + Vector3.UP * 2.2,
					Vector3(on.x, FrontierTerrain.height_at(on.x, on.z) + 0.2, on.z), 0.06)
		_player_at(_cam_pos - ahead * 5.0, false)
		await _run(1)
		n += 1
	print("track: activity=%s carcass=%s deer dead=%s by=%s" % [WildGroup.Activity.keys()[g.activity],
			str(g.carcass == d), str(d.is_dead()), d.killed_by])
	recording = false
	for a: WildAnimal in g.alive():
		_away(a)
	g.carcass = null
	g.activity = WildGroup.Activity.BED
	w.remove_carcass(d)


## Starving, the pack takes his fresh kill from under him and comes for him.
func _starving() -> void:
	_h = 0.9
	w.animal_blood.clear()
	var spot := Vector3(4.0, 0.0, -150.0)
	var d := _deer(spot)
	if d == null:
		return
	_player_at(spot + Vector3(1.8, 0.0, 0.4), true)
	p.yaw = atan2(-(spot.x - p.global_position.x), -(spot.z - p.global_position.z))
	p.rotation.y = p.yaw
	_shoot(d, 999.0, p.global_position)
	await _run(45)
	var pack_from := spot + Vector3(-30.0, 0.0, -8.0)
	# another pack (not the one that has just eaten)
	var g2 := w._spawn_group("wolf_pack", pack_from, false, 4)
	await _run(2)
	_pack_at(g2, pack_from, 0.45)
	_calm = false
	var to_pack := _flat(pack_from - p.global_position)
	var s := to_pack.cross(Vector3.UP)
	_cam(p.global_position - to_pack * 6.5 + s * 2.5 + Vector3.UP * 2.4, p.global_position + to_pack * 6.0, 1.0)
	recording = true
	bites = 0
	var n := 0
	var after := 0
	while n < 24 * 30 and after < 50:
		var mid := Vector3.ZERO
		for a: WildAnimal in g2.alive():
			mid += a.global_position
		mid /= maxf(g2.alive().size(), 1.0)
		var tp := _flat(mid - p.global_position)
		var s3 := tp.cross(Vector3.UP)
		var look := p.global_position.lerp(mid, 0.4) + Vector3.UP * 0.6
		_cam(p.global_position - tp * 6.5 + s3 * 2.5 + Vector3.UP * 2.4, look, 0.05)
		p.velocity = Vector3.ZERO
		if bites > 0:
			after += 1
		await _run(1)
		n += 1
	print("starving: took=%s after_player=%s bites=%d" % [str(g2.carcass == d), str(g2.after_player_until > w.now), bites])
	recording = false
