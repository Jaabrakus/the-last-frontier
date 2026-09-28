extends SceneTree
## The plains bison in the game (WildlifeSpecies "bison"; user 2026-09-28: "bison behavior in the open plains a lot of
## them", "lets work on the bison so we can reuse a lot of the animal things for different animals"), filmed on the open
## land east of the fort with the game's HUD:
##   the herds from above    both herds grazing on the open land, a slow pass over them
##   the herd close          a herd grazing and its sentry standing, from the grass beside it
##   the stampede            a musket shot (WildlifeSpawner.shot): the herd runs together, followed alongside
##   the charge              a bison shot through the body with the hunter near turns on him, from the game's camera:
##                           the butt throws him down
## Windowed, fixed rate:
##
##   Godot --path . --resolution 1280x720 --fixed-fps 30 -s tools/wildlife/bison_film.gd -- out=<abs dir> [hour=9.0] \
##       wildlife=on survival=on survival_seed=7
##   <dir>/frames/f00000.jpg ...; then video_encode encode <dir>/frames 30 <film.mp4> (tools/showcase/video_encode.swift)
## Ends with BISON FILM DONE. The player is Actor_B animation data; the bison is Poly by Google's (CC-BY 3.0) rigged by
## this project on Quaternius's CC0 stag armature (assets/wildlife/bison/SOURCE.md).

const PLAINS := Vector2i(1, 0)

var out := ""
var hour := 9.0
var w: WildlifeSpawner
var p: FrontierPlayer
var cam: Camera3D
var frame := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var k := a.get_slice("=", 0)
		var v := a.substr(a.find("=") + 1)
		match k:
			"out": out = v
			"hour": hour = float(v)
	InputSetup.ensure()
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DirAccess.make_dir_recursive_absolute(out.path_join("frames"))
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _shoot(n := 1) -> void:
	for i in n:
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg(out.path_join("frames/f%05d.jpg" % frame), 0.92)
		frame += 1


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _on(pos: Vector3, up := 0.0) -> Vector3:
	return Vector3(pos.x, FrontierTerrain.height_at(pos.x, pos.z) + up, pos.z)


func _herds() -> Array[WildGroup]:
	var out_g: Array[WildGroup] = []
	for e in w.groups:
		if String(e.kind) == "bison_herd" and not (e.group as WildGroup).alive().is_empty():
			out_g.append(e.group)
	out_g.sort_custom(func(a: WildGroup, b: WildGroup) -> bool: return a.alive().size() > b.alive().size())
	return out_g


func _run() -> void:
	for i in 5:
		await process_frame
	p = current_scene.get_node("Player") as FrontierPlayer
	w = current_scene.get_node_or_null("Wildlife") as WildlifeSpawner
	if w == null:
		print("BISON FILM FAILED: no wildlife (pass wildlife=on)")
		quit(1)
		return
	p.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for c in root.find_children("*", "CharacterCreator", true, false):
		c.queue_free()
	paused = false
	w._restock_t = 1e9
	var rig := current_scene.get_node_or_null("EnvironmentRig") as EnvironmentRig
	if rig and rig.clock_driver:
		rig.clock_driver.clock.running = false
		rig.clock_driver.clock.set_time(hour)
	if rig and rig.get_camera_attributes():
		rig.get_camera_attributes().auto_exposure_speed = 30.0
	var herds := _herds()
	if herds.is_empty():
		print("BISON FILM FAILED: no bison herds")
		quit(1)
		return
	var g := herds[0]
	# the hunter on the land, well off the herd (it grazes on, awake within WildlifeSpawner.ACTIVE_D)
	p.global_position = _on(g.centroid() + Vector3(-130.0, 0.0, 30.0), 0.1)
	p.set_crouched(true)
	w._lod()
	cam = Camera3D.new()
	cam.fov = 50.0
	current_scene.add_child(cam)
	cam.current = true
	# let them settle, grazing (unfilmed)
	for i in 240:
		cam.global_position = _on(g.centroid() + Vector3(-60.0, 0.0, -40.0), 30.0)
		cam.look_at(g.centroid() + Vector3.UP, Vector3.UP)
		await process_frame
	# 1. from above: a slow pass over the herd, the other herd far off
	var c0 := g.centroid()
	var n1 := 150
	for i in n1:
		var k := float(i) / float(n1 - 1)
		var a := lerpf(-0.9, -0.3, k)
		cam.global_position = _on(c0 + Vector3(cos(a), 0.0, sin(a)) * 70.0, 26.0 - 6.0 * k)
		cam.look_at(g.centroid() + Vector3.UP * 1.0, Vector3.UP)
		await _shoot()
	# 2. close: from the grass beside it, low
	var n2 := 150
	var side := Vector3(0.0, 0.0, 1.0)
	for i in n2:
		var k := float(i) / float(n2 - 1)
		var c := g.centroid()
		cam.global_position = _on(c + side * 26.0 + Vector3(lerpf(-10.0, 6.0, k), 0.0, 0.0), 1.6)
		cam.look_at(c + Vector3.UP * 1.2, Vector3.UP)
		await _shoot()
	# 3. the stampede: a musket shot beyond the herd; the camera runs alongside
	var shot_at := g.centroid() + Vector3(-70.0, 0.0, 0.0)
	w.shot(_on(shot_at, 1.5), WildlifeSpawner.SHOT_LOUD_M)
	var n3 := 210
	for i in n3:
		var c := g.centroid()
		var v := Vector3.ZERO
		for a in g.alive():
			v += Vector3(a.velocity.x, 0.0, a.velocity.z)
		var run := v.normalized() if v.length() > 0.5 else Vector3.RIGHT
		var aside := run.cross(Vector3.UP).normalized()
		var want := _on(c + aside * 34.0 - run * 10.0, 4.0)
		cam.global_position = want if i == 0 else cam.global_position.lerp(want, 0.12)
		cam.look_at(c + Vector3.UP * 1.0, Vector3.UP)
		await _shoot()
	# 4. the charge, from the game's camera: one bison, the hunter standing 12 m before it, shot through the body
	await _wait(120)
	var herds2 := _herds()
	var g2 := herds2[herds2.size() - 1] if herds2.size() > 1 else g
	var bull: WildAnimal = g2.alive()[0]
	for b in g2.alive():
		if b != bull:
			b.set_active(false)
	bull.awareness = 0.0
	bull._enter(WildAnimal.State.IDLE, 5.0)
	await _wait(20)
	var fwd := -bull.global_basis.z
	p.set_crouched(false)
	p.global_position = _on(bull.global_position + fwd * 13.0, 0.1)
	var face := bull.global_position - p.global_position
	p.yaw = atan2(-face.x, -face.z)
	p.rotation.y = p.yaw
	p.pitch = deg_to_rad(-6.0)
	cam.current = false
	p.camera.current = true
	await _shoot(20)
	bull.apply_hit(160.0, bull.global_position + Vector3.UP * 1.1 - fwd * 0.9, (bull.global_position - p.global_position).normalized(), p, "body")
	var down_t := -1
	for i in 150:
		await _shoot()
		if down_t < 0 and PlayerRagdoll.of(p).is_down():
			down_t = i
		if down_t >= 0 and i - down_t > 60:
			break
	for b in g2.alive():
		b.set_active(true)
	print("BISON FILM DONE frames=%d herds=%d charge_down=%s" % [frame, herds.size(), down_t >= 0])
	quit()
