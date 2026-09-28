extends SceneTree
## Screenshots of the thrown weapons for the design doc (needs a window, not
## --headless). The player's animation graph does not know the throwables yet, so
## the body stays in the pistol carry pose; the held weapon is placed by the
## Throwable itself (raised along the throw line while winding up).
##
##   Godot --path . -s tests/throwables/throwables_screens.gd -- --no-capture out=/abs/dir
##
## Saves: spear_windup_play.png (gameplay camera, arc and landing ring), spear_windup_side.png,
## tomahawk_flight.png (mid-spin), stuck_closeup_25m.png / stuck_closeup_10m.png (spear, dart and
## tomahawk in the dummies), atlatl_raised_side.png, atlatl_raised_play.png, models_lineup.png.

var args := {}
var player: FrontierPlayer
var kit: Dictionary
var cur: Throwable
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	out = args.get("out", "user://throwable_shots")
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
	kit = ThrowableKit.install(player)
	for k in kit:
		var w := kit[k] as Throwable
		w.use_scripted_input = true
		# No spread: every throw lands where it is aimed, so the close-ups find their targets.
		w.spread_base = 0.0
		w.spread_move = 0.0
		w.spread_undercharge = 0.0
		w.spread_air = 0.0
		w.spread_fatigue = 0.0
		w.fire_bloom = 0.0
		w.spread = 0.0
	player.switch_weapon("pistol")
	await _frames(60)
	player.weapon.model.visible = false

	# 1. Spear wound up at the 25 m dummy: gameplay camera with the arc.
	await _use("spear")
	await _stand_and_aim(Vector3(0.0, 0.0, -30.0), Vector3(0.0, 1.25, -45.0))
	cur.scripted_input["fire"] = true
	await _frames(80)
	player.weapon.model.visible = false
	await _shot("spear_windup_play.png")
	await _side_shot("spear_windup_side.png", Vector3(2.4, 0.5, 0.4), Vector3(0, 1.2, -0.4))
	cur.scripted_input["fire"] = false
	await _frames(240)

	# 2. Tomahawk in flight, seen from the side of the lane.
	await _use("tomahawk")
	await _stand_and_aim(Vector3(-2.5, 0.0, -21.4), Vector3(-2.5, 1.2, -30.0))
	cur.scripted_input["fire"] = true
	await _frames(60)
	cur.scripted_input["fire"] = false
	var cam := Camera3D.new()
	cam.fov = 50
	current_scene.add_child(cam)
	cam.global_position = Vector3(-0.3, 1.5, -25.4)
	cam.look_at(Vector3(-2.5, 1.25, -25.9))
	cam.current = true
	for i in 200:
		await _frames(1)
		if cur.last_thrown and cur.last_thrown.global_position.z < -25.7:
			break
	await _shot("tomahawk_flight.png", 0)
	player.camera.current = true
	cam.queue_free()
	await _frames(200)

	# 3. Atlatl cast into the 25 m dummy, then everything stuck close up.
	await _use("atlatl")
	await _stand_and_aim(Vector3(0.0, 0.0, -21.0), Vector3(0.0, 1.35, -45.0))
	cur.scripted_input["fire"] = true
	await _frames(90)
	cur.scripted_input["fire"] = false
	await _frames(240)
	await _use("spear")
	await _stand_and_aim(Vector3(0.0, 0.0, -33.0), Vector3(0.05, 1.05, -45.0))
	cur.scripted_input["fire"] = true
	await _frames(90)
	cur.scripted_input["fire"] = false
	await _frames(240)
	var cam2 := Camera3D.new()
	cam2.fov = 40
	current_scene.add_child(cam2)
	cam2.global_position = Vector3(2.6, 1.7, -41.0)
	cam2.look_at(Vector3(0.0, 1.2, -44.6))
	cam2.current = true
	await _shot("stuck_closeup_25m.png")
	cam2.global_position = Vector3(-0.3, 1.6, -26.6)
	cam2.look_at(Vector3(-2.5, 1.2, -29.9))
	await _shot("stuck_closeup_10m.png")
	cam2.queue_free()
	player.camera.current = true

	# 4. Atlatl with a dart seated, raised, from the side.
	await _use("atlatl")
	await _stand_and_aim(Vector3(6.0, 0.0, -22.0), Vector3(6.0, 1.5, -45.0))
	cur.scripted_input["fire"] = true
	await _frames(80)
	await _side_shot("atlatl_raised_side.png", Vector3(2.6, 0.6, 0.2), Vector3(0, 1.3, -0.6))
	await _shot("atlatl_raised_play.png")
	cur.scripted_input["fire"] = false
	await _frames(120)

	# 5. The four models side by side on the ground in the fort, in game lighting.
	var base := Vector3(4.0, 0.0, 8.0)
	var y := _ground(base) + 0.02
	# Rotated a quarter turn about Y: model -Z (points, blade) toward -X.
	var items := [["spear", Vector3(0.0, 0.03, 0.0)], ["atlatl_dart", Vector3(-0.86, 0.03, 0.3)],
			["tomahawk", Vector3(-0.75, 0.03, 0.62)], ["atlatl", Vector3(0.15, 0.03, 0.72)]]
	for it in items:
		var m := ThrowableModels.build(it[0])
		current_scene.add_child(m)
		var p: Vector3 = base + it[1]
		p.y = y + (it[1] as Vector3).y
		var b := Basis(Vector3.UP, PI / 2)
		if it[0] == "tomahawk":
			# Lying flat on its side: haft toward +X (head right), blade toward the camera.
			b = Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1))
		m.global_transform = Transform3D(b, p)
	var cam3 := Camera3D.new()
	cam3.fov = 40
	current_scene.add_child(cam3)
	cam3.global_position = base + Vector3(0.0, y + 1.75, 1.75)
	cam3.look_at(base + Vector3(0.0, y, 0.38))
	cam3.current = true
	player.visible = false
	await _shot("models_lineup.png")
	quit()


func _ground(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 20.0, p + Vector3.DOWN * 20.0)
	q.exclude = [player.get_rid()]
	var r: Dictionary = current_scene.get_world_3d().direct_space_state.intersect_ray(q)
	return (r.position as Vector3).y if r else 0.0


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
		if cur and cur.active:
			cur.tick(1.0 / 120.0)


func _use(key: String) -> void:
	if cur:
		cur.unequip()
	cur = kit[key]
	cur.scripted_input = {"fire": false, "cancel": false}
	cur.equip()
	(player.get_node("ThrowableArc") as ThrowableArc).source = cur
	await _frames(90)


func _stand_and_aim(pos: Vector3, target: Vector3) -> void:
	player.global_position = pos + Vector3.UP * 0.3
	player.velocity = Vector3.ZERO
	await _frames(30)
	for i in 5:
		var from := player.camera.global_position
		var d := target - from
		player.yaw = atan2(-d.x, -d.z)
		player.pitch = atan2(d.y, Vector2(d.x, d.z).length())
		await _frames(3)


## Camera placed in the player's frame (offset from the chest), looking at `look` (same frame).
func _side_shot(file: String, offset: Vector3, look: Vector3) -> void:
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


func _shot(file: String, settle := 3) -> void:
	for i in settle:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join(file))
	print("saved ", out.path_join(file))
