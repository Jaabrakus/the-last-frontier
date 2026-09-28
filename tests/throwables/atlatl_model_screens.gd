extends SceneTree
## In-engine screenshots of the atlatl and its dart (tools/models/atlatl.py) in the fort
## level's lighting. Needs a window, not --headless:
##   Godot --path . -s tests/throwables/atlatl_model_screens.gd -- out=/abs/dir
## The player's animation graph does not know the throwables yet, so the body stays in
## the pistol carry pose with the hand at the hip; the atlatl is placed by
## ThrowableAtlatl itself (raised along the throw line while winding up).
##
## Only the atlatl is thrown here (no spears in the dummy), with spread off, so the stuck
## shot always shows the dart; the cast's result is printed (STUCK ... in <node>) and the
## close-up camera is placed from where the dart actually came to rest.
## Saves:
##   atlatl_ingame_stuck_25m.png      the dart stuck in the 25 m dummy, from the side
##   atlatl_ingame_stuck_fletch.png   closer, on the fletching and the painted crest
##   atlatl_ingame_mid_raise_side.png raising (aim ~0.5): the dart stays seated on the board
##   atlatl_ingame_mid_raise_close.png the same moment, close up on the board
##   atlatl_ingame_raised_side.png    fully wound up, from the side
##   atlatl_ingame_raised_close.png   the held atlatl close up (stone, cap and hook, dart)
##   atlatl_ingame_play.png           gameplay camera while wound up (arc and aim dot)
##   atlatl_ingame_lineup.png         atlatl, dart and trade tomahawk on the ground

const DT := 1.0 / 120.0

var out := "user://atlatl_shots"
var player: FrontierPlayer
var w: ThrowableAtlatl


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	player = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for d in current_scene.find_children("*", "TargetDummy", true, false):
		(d as TargetDummy).max_health = 1.0e6
		(d as TargetDummy).health = 1.0e6
	var keys: Array[String] = ["atlatl"]
	var kit := ThrowableKit.install(player, keys)
	w = kit["atlatl"]
	w.use_scripted_input = true
	w.scripted_input = {"fire": false, "cancel": false}
	player.switch_weapon("pistol")
	await _frames(60)
	player.weapon.model.visible = false
	w.equip()
	(player.get_node("ThrowableArc") as ThrowableArc).source = w
	await _frames(90)
	# Spread off: the cast goes where the arc says.
	w.spread_base = 0.0
	w.spread_move = 0.0
	w.spread_undercharge = 0.0
	w.fire_bloom = 0.0
	w.spread_air = 0.0
	w._bloom = 0.0
	w.spread = 0.0

	# 1. One dart into the 25 m dummy's torso, then close-ups from where it came to rest.
	await _stand_and_aim(Vector3(0.0, 0.0, -21.0), Vector3(0.0, 1.2, -45.0))
	w.scripted_input["fire"] = true
	await _frames(100)
	var before := w.last_thrown
	w.scripted_input["fire"] = false
	for i in 120:
		await _frames(1)
		if w.last_thrown != before:
			break
	var p := w.last_thrown
	var first_hit := {}                         # lambdas capture locals by value: use a dict
	if p != before and p != null:
		p.hit.connect(func(c: Object, _pt: Vector3, _s: bool) -> void:
			if not first_hit.has("node") and c is Node:
				first_hit["node"] = str((c as Node).get_path()))
		for i in 600:
			await _frames(1)
			if p.phase == ThrownProjectile.Phase.STUCK or p.phase == ThrownProjectile.Phase.LYING:
				break
		print("CAST phase %s at %s, first hit %s, parent %s" % [ThrownProjectile.Phase.keys()[p.phase],
				p.global_position, first_hit.get("node", "?"), p.get_parent().get_path()])
		print("STUCK %s in %s" % [p.phase == ThrownProjectile.Phase.STUCK, _dummy_of(p)])
		await _frames(180)                        # let the damage popup fade
		var com := p.global_position
		var fwd := -p.global_basis.z.normalized()
		var side := fwd.cross(Vector3.UP).normalized()
		var cam := Camera3D.new()
		cam.fov = 40
		current_scene.add_child(cam)
		cam.current = true
		# The shaft sticks out behind the COM; frame the dummy and the whole dart.
		var mid := com - fwd * 0.35
		cam.look_at_from_position(mid - side * 2.1 + Vector3.UP * 0.45 - fwd * 0.6, mid, Vector3.UP)
		await _shot("atlatl_ingame_stuck_25m.png")
		var tail := com - fwd * 0.75                 # fletching / crest region
		cam.look_at_from_position(tail - side * 0.75 + Vector3.UP * 0.25 - fwd * 0.2, tail, Vector3.UP)
		await _shot("atlatl_ingame_stuck_fletch.png")
		cam.queue_free()
		player.camera.current = true
	else:
		print("CAST no dart left the atlatl")
	await _frames(int((w.follow_time + w.draw_time) * 120) + 30)

	# 2. Raising and raised, from the side (player frame), then the gameplay camera.
	await _stand_and_aim(Vector3(6.0, 0.0, -22.0), Vector3(6.0, 1.5, -45.0))
	w.scripted_input["fire"] = true
	for i in 60:
		await _frames(1)
		if w.aim >= 0.5:
			break
	print("MID RAISE aim %.2f state %s" % [w.aim, Throwable.State.keys()[w.state]])
	await _side_shot("atlatl_ingame_mid_raise_side.png", Vector3(1.5, 0.15, 0.9), Vector3(0.2, 0.95, -0.1), true)
	await _side_close("atlatl_ingame_mid_raise_close.png")
	await _frames(90)
	print("RAISED aim %.2f state %s" % [w.aim, Throwable.State.keys()[w.state]])
	await _side_shot("atlatl_ingame_raised_side.png", Vector3(2.4, 0.5, 0.2), Vector3(0.0, 1.0, -0.6), true)
	await _side_close("atlatl_ingame_raised_close.png")
	await _shot("atlatl_ingame_play.png")
	w.scripted_input["cancel"] = true
	await _frames(2)
	w.scripted_input["fire"] = false
	await _frames(60)

	# 3. Atlatl, dart and the iron trade tomahawk side by side on the ground.
	var base := Vector3(4.0, 0.0, 8.0)
	var y := _ground(base) + 0.02
	var items := [["atlatl_dart", Vector3(-0.92, 0.012, 0.05)], ["atlatl", Vector3(0.05, 0.015, 0.32)],
			["tomahawk", Vector3(-0.35, 0.03, 0.62)]]
	for it in items:
		var m := ThrowableModels.build(it[0])
		current_scene.add_child(m)
		var pos: Vector3 = base + it[1]
		pos.y = y + (it[1] as Vector3).y
		# A quarter turn about Y: model -Z (point, grip end) toward -X.
		var b := Basis(Vector3.UP, PI / 2)
		if it[0] == "tomahawk":
			b = Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1))   # lying on its side
		m.global_transform = Transform3D(b, pos)
	var cam3 := Camera3D.new()
	cam3.fov = 40
	current_scene.add_child(cam3)
	cam3.current = true
	cam3.look_at_from_position(base + Vector3(-0.1, y + 1.3, 1.6), base + Vector3(-0.1, y, 0.35), Vector3.UP)
	player.visible = false
	await _shot("atlatl_ingame_lineup.png")
	quit()


func _dummy_of(p: Node) -> String:
	var n := p.get_parent()
	while n:
		if n is TargetDummy:
			return str(n.name)
		n = n.get_parent()
	return "no dummy"


func _ground(pos: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 20.0, pos + Vector3.DOWN * 20.0)
	q.exclude = [player.get_rid()]
	var r: Dictionary = current_scene.get_world_3d().direct_space_state.intersect_ray(q)
	return (r.position as Vector3).y if r else 0.0


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
		if w.active:
			w.tick(DT)


func _stand_and_aim(pos: Vector3, target: Vector3) -> void:
	player.global_position = pos + Vector3.UP * 0.3
	player.velocity = Vector3.ZERO
	await _frames(30)
	for i in 5:
		var d := target - player.camera.global_position
		player.yaw = atan2(-d.x, -d.z)
		player.pitch = atan2(d.y, Vector2(d.x, d.z).length())
		await _frames(3)


## Camera in the player's frame (offset from the feet), looking at `look` (same frame).
## `hold` keeps the weapon state frozen while the frame renders (no ticks).
func _side_shot(file: String, offset: Vector3, look: Vector3, _hold := false) -> void:
	var cam := Camera3D.new()
	cam.fov = 40
	current_scene.add_child(cam)
	var b := player.global_basis
	cam.global_position = player.global_position + b * (offset + Vector3(0, 1.1, 0))
	cam.look_at(player.global_position + b * look)
	cam.current = true
	await _shot(file)
	cam.queue_free()
	player.camera.current = true


## Close-up of the held board from the right, 0.9 m away, centred on the bannerstone.
func _side_close(file: String) -> void:
	var cam := Camera3D.new()
	cam.fov = 35
	cam.near = 0.02
	current_scene.add_child(cam)
	var stone := w.model.global_transform * Vector3(0.0, 0.0, 0.25)
	var right := player.global_basis.x.normalized()
	cam.look_at_from_position(stone + right * 0.85 + Vector3.UP * 0.3 + player.global_basis.z * 0.1, stone, Vector3.UP)
	cam.current = true
	await _shot(file)
	cam.queue_free()
	player.camera.current = true


func _shot(file: String, settle := 3) -> void:
	for i in settle:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join(file))
	print("saved ", out.path_join(file))
