extends SceneTree
## In-game screenshots of the spear model (tools/models/spear.py) for the design doc.
## Needs a window, not --headless:
##   Godot --path . --resolution 1600x900 -s tests/throwables/spear_model_screens.gd -- --no-capture out=/abs/dir
## Saves:
##   spear_ingame_held.png      raised in the hand during a wind-up, from the side
##   spear_ingame_flight.png    in flight, the stroud tails streamed back
##   spear_ingame_stuck_25m.png spear and atlatl dart stuck in the 25 m dummy, close
##   spear_ingame_stuck_far.png the same seen from about 11 m (telling the two apart)
##   spear_ingame_lying.png     a thrown spear lying blade-flat on the ground (pickup)
##   spear_ingame_lineup.png    spear, dart, tomahawk and atlatl on the ground
## The body stays in the pistol carry pose (the animation graph does not know the
## throwables yet); the held spear is placed by the Throwable.

var args := {}
var player: FrontierPlayer
var kit: Dictionary
var cur: Throwable
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.get_slice("=", 1)
	out = args.get("out", "user://spear_shots")
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
		(kit[k] as Throwable).use_scripted_input = true
	player.switch_weapon("pistol")
	await _frames(60)
	player.weapon.model.visible = false

	# 1. Wound up, from the side.
	await _use("spear")
	await _stand_and_aim(Vector3(0.0, 0.0, -33.0), Vector3(0.05, 1.05, -45.0))
	cur.scripted_input["fire"] = true
	await _frames(80)
	player.weapon.model.visible = false
	await _side_shot("spear_ingame_held.png", Vector3(2.4, 0.5, 0.4), Vector3(0, 1.2, -0.4))

	# 2. Released: follow it from the side of the lane and catch it mid-flight.
	cur.scripted_input["fire"] = false
	var cam := Camera3D.new()
	cam.fov = 35
	current_scene.add_child(cam)
	cam.global_position = Vector3(1.6, 1.55, -37.4)
	cam.look_at(Vector3(0.0, 1.3, -38.2))
	cam.current = true
	for i in 240:
		await _frames(1)
		if cur.last_thrown and cur.last_thrown.global_position.z < -37.6:
			break
	await _shot("spear_ingame_flight.png", 0)
	player.camera.current = true
	cam.queue_free()
	await _frames(240)

	# 3. An atlatl dart into the same dummy, then both close up and from 12 m.
	await _use("atlatl")
	await _stand_and_aim(Vector3(0.6, 0.0, -21.0), Vector3(0.0, 1.35, -45.0))
	cur.scripted_input["fire"] = true
	await _frames(90)
	cur.scripted_input["fire"] = false
	await _frames(240)
	player.visible = false
	var cam2 := Camera3D.new()
	cam2.fov = 40
	current_scene.add_child(cam2)
	cam2.global_position = Vector3(2.6, 1.7, -41.0)
	cam2.look_at(Vector3(0.0, 1.2, -44.6))
	cam2.current = true
	await _shot("spear_ingame_stuck_25m.png")
	cam2.fov = 60
	cam2.global_position = Vector3(10.0, 1.75, -40.0)
	cam2.look_at(Vector3(0.0, 1.2, -44.2))
	await _shot("spear_ingame_stuck_far.png")
	cam2.queue_free()
	player.visible = true
	player.camera.current = true

	# 4. A spear dropped onto open ground: lies blade-flat, the tails laid out.
	var base := Vector3(4.0, 0.0, 8.0)
	var gy := _ground(base)
	var lying := ThrownProjectile.new()
	lying.kind = "spear"
	lying.model_kind = "spear"
	lying.whoosh = false
	var ex: Array[RID] = [player.get_rid()]
	lying.exclude = ex
	current_scene.add_child(lying)
	lying.global_transform = Transform3D(Basis.looking_at(Vector3(-1, 0, -0.35).normalized(), Vector3.UP),
			base + Vector3(0.9, gy + 0.6, -1.2))
	lying._settle_at(lying.global_transform)
	await _frames(10)
	player.global_position = base + Vector3(0.6, 0.3, 2.4)
	var cam3 := Camera3D.new()
	cam3.fov = 45
	current_scene.add_child(cam3)
	var c: Vector3 = lying.global_position
	cam3.global_position = c + Vector3(0.35, 1.45, 1.6)
	cam3.look_at(c + Vector3(-0.1, 0.0, 0.0))
	cam3.current = true
	player.visible = false
	await _shot("spear_ingame_lying.png")
	lying.queue_free()

	# 5. The four models side by side on the ground, as they lie (spear blade-flat).
	var y := gy + 0.02
	var items := [["spear", Vector3(0.0, 0.0, 0.0), Basis(Vector3.UP, PI / 2)],
			["atlatl_dart", Vector3(-0.86, 0.01, 0.3), Basis(Vector3.UP, PI / 2)],
			["tomahawk", Vector3(-0.75, 0.01, 0.62), Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1))],
			["atlatl", Vector3(0.15, 0.01, 0.72), Basis(Vector3.UP, PI / 2)]]
	for it in items:
		var mdl := ThrowableModels.build(it[0])
		current_scene.add_child(mdl)
		var p: Vector3 = base + it[1]
		p.y = y + (it[1] as Vector3).y - (0.004 if it[0] == "spear" else 0.0)
		mdl.global_transform = Transform3D(it[2], p)
		if it[0] == "spear":
			var trim := mdl.find_child("Trim", true, false) as Node3D
			if trim:
				trim.rotation = ThrownProjectile.TRIM_LIE_ROT
	cam3.global_position = base + Vector3(0.0, y + 1.75, 1.75)
	cam3.look_at(base + Vector3(0.0, y, 0.38))
	await _shot("spear_ingame_lineup.png")
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
