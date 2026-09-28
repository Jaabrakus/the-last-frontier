extends SceneTree
## Stills of the climbing yard's woolly mammoth and bison (user 2026-09-27: "lets add a mammoth in our test climb scene"):
## the mammoth standing (side and front), walking, warning of a big shake (the head lifted), shaking, down on a front
## knee and on a hind hock (its weak points), its attacks (the trunk coiled and swept, the stomp reared and slammed, a
## charge), the collision the grip holds drawn over it, and the bison. The player stands beside it for scale.
##   Godot --path . -s tests/climb/mammoth_shots.gd -- out=<dir>
## The window opens but draws nothing (OffscreenView renders off-window).

const OffscreenView := preload("res://tools/environment/offscreen_view.gd")

var out := "user://mammoth_shots"
var view
var yard: ClimbYard
var gi: StandInGiant
var p: FrontierPlayer


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure()
	change_scene_to_file("res://scenes/climb_yard.tscn")
	await process_frame
	await process_frame
	var lvl := current_scene
	p = lvl.get_node("Player")
	yard = lvl.get("yard")
	gi = yard.giant
	p.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for act in InputMap.get_actions():
		if not String(act).begins_with("ui_"):
			InputMap.action_erase_events(act)
	var rig := lvl.get_node("EnvironmentRig") as EnvironmentRig
	if rig and rig.clock_driver:
		rig.clock_driver.clock.running = false
		rig.clock_driver.clock.set_time(10.5)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = Vector2i(1280, 720)
	view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(1280, 720))
	root.disable_3d = true
	var st: Dictionary = yard.stations.giant
	p.global_position = (st.stand as Vector3) + Vector3(-1.2, 0.1, 3.0)
	await _frames(120)
	var c := gi._home.origin
	gi.paces = false
	await _frames(60)
	await _shot("1_side", c + Vector3(-11.0, 3.2, 5.0), c + Vector3(0.0, 2.4, 0.0))
	await _shot("2_front", c + Vector3(-5.5, 2.6, -11.0), c + Vector3(0.0, 2.2, -2.5))
	await _shot("3_back_right", c + Vector3(9.0, 4.5, 8.0), c + Vector3(0.0, 2.6, 0.0))
	# walking: the pacing at full speed
	gi.paces = true
	await _frames(240)
	await _shot("4_walking", c + Vector3(-11.0, 3.2, 3.0), gi.torso.global_position + Vector3(0.0, -0.5, 0.0))
	gi.paces = false
	gi._home = gi.spawn
	gi._pace_c = Vector3.INF
	# the warning: crouched, the head up
	gi._on_t = 99.0
	gi._shake_i = 1
	gi._wait = 0.0
	gi.warning = true
	gi._warn_t = 0.0
	await _frames(int(0.95 * 120))
	await _shot("5_warning", c + Vector3(-10.0, 2.8, -4.0), c + Vector3(0.0, 2.6, -1.5))
	await _frames(int(0.9 * 120))
	await _shot("6_shaking", c + Vector3(-10.0, 2.8, -4.0), c + Vector3(0.0, 2.6, -1.5))
	gi.shaking = false
	gi.warning = false
	gi._on_t = 0.0
	await _frames(60)
	# the weak points: down on the front left knee (falling, then down), up again, down on the right hind hock
	gi.knock_down("Front_L")
	await _frames(int(0.3 * 120))
	await _shot("10_kneel_front_falling", c + Vector3(-9.5, 2.2, -8.0), c + Vector3(0.0, 1.8, -1.5))
	await _frames(int(0.8 * 120))
	await _shot("11_kneel_front_down", c + Vector3(-9.5, 2.2, -8.0), c + Vector3(0.0, 1.8, -1.5))
	await _shot("12_kneel_front_side", c + Vector3(-12.0, 1.6, -2.0), c + Vector3(0.0, 1.8, -1.0))
	await _frames(int((StandInGiant.DOWN_S + 3.0) * 120))
	gi.knock_down("Hind_R")
	await _frames(int(1.1 * 120))
	await _shot("13_kneel_hind_down", c + Vector3(11.0, 2.6, 4.0), c + Vector3(0.0, 2.0, 0.5))
	await _frames(int((StandInGiant.DOWN_S + 3.0) * 120))
	# its attacks (MammothTemper's): the trunk coiled and swept to its left, the stomp reared and slammed, a charge
	gi.set_driven(true)
	var front := c + Vector3(-7.0, 2.4, -9.5)
	gi.act("TrunkSwing_L")
	await _frames(int(9.0 / 24.0 * 120))
	await _shot("14_trunk_coiled", front, c + Vector3(0.0, 2.0, -3.0))
	await _frames(int(8.0 / 24.0 * 120))
	await _shot("15_trunk_swept", front, c + Vector3(0.0, 2.0, -3.0))
	await _frames(120)
	gi.act("Stomp")
	await _frames(int(16.0 / 24.0 * 120))
	await _shot("16_stomp_reared", c + Vector3(-12.0, 3.0, -3.0), c + Vector3(0.0, 3.2, -1.0))
	await _frames(int(7.0 / 24.0 * 120))
	await _shot("17_stomp_slam", c + Vector3(-12.0, 3.0, -3.0), c + Vector3(0.0, 2.2, -1.0))
	await _frames(120)
	gi.drive_speed = MammothTemper.CHARGE_MPS
	gi.head_aim = -0.22
	await _frames(60)
	await _shot("18_charge", gi.where() + Vector3(-10.0, 2.2, -6.0), gi.where() + Vector3(0.0, 2.0, -1.0))
	gi.drive_speed = 0.0
	gi.set_driven(false)
	gi._home = gi.spawn
	await _frames(60)
	_show_collision()
	await _frames(4)
	await _shot("7_collision", c + Vector3(-11.0, 3.2, 5.0), c + Vector3(0.0, 2.4, 0.0))
	var bs: Dictionary = yard.stations.bison
	await _shot("8_bison", (bs.look as Vector3) + Vector3(-3.5, 0.9, 4.0), bs.look)
	await _shot("9_wide", c + Vector3(-6.0, 4.0, 22.0), c + Vector3(3.0, 2.0, 0.0))
	quit()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _shot(nm: String, from: Vector3, at: Vector3) -> void:
	view.source = null
	view.camera.global_transform = Transform3D(Basis.looking_at(at - from, Vector3.UP), from)
	view.camera.fov = 55.0
	for i in 3:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	var img: Image = view.get_texture().get_image()
	var path: String = out.path_join(nm + ".png")
	img.save_png(path)
	print("SHOT ", path)


## The bodies the grip holds, drawn see-through over the model (torso and hump green, head blue, legs orange).
func _show_collision() -> void:
	for b in [gi.torso, gi.head] + gi.legs:
		var col := Color(0.2, 1.0, 0.3, 0.35) if b == gi.torso else (Color(0.3, 0.5, 1.0, 0.35) if b == gi.head else Color(1.0, 0.6, 0.1, 0.35))
		for cs in (b as Node).get_children():
			if not (cs is CollisionShape3D):
				continue
			var s := (cs as CollisionShape3D).shape
			var m: Mesh
			if s is CapsuleShape3D:
				var cm := CapsuleMesh.new()
				cm.radius = (s as CapsuleShape3D).radius
				cm.height = (s as CapsuleShape3D).height
				m = cm
			elif s is SphereShape3D:
				var sm := SphereMesh.new()
				sm.radius = (s as SphereShape3D).radius
				sm.height = sm.radius * 2.0
				m = sm
			elif s is BoxShape3D:
				var bm := BoxMesh.new()
				bm.size = (s as BoxShape3D).size
				m = bm
			if m == null:
				continue
			var mi := MeshInstance3D.new()
			mi.mesh = m
			var mat := StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = col
			mat.no_depth_test = true
			mi.material_override = mat
			cs.add_child(mi)
