extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, msg: String) -> void:
	if not ok:
		failures += 1
		push_error(msg)
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20, 0.2, 20)
	collision.shape = shape
	floor.add_child(collision)
	world.add_child(floor)
	floor.position.y = -0.1
	var p := FrontierPlayer.new()
	p.is_local = false
	p.controls = PlayerControls.new(false)
	p.use_appearance = false
	p.show_gear = false
	p.demo_horse = false
	p.demo_wheelbarrow = false
	world.add_child(p)
	p.position.y = 0.1
	var tandem: Node = load("res://features/tandem/frontier_tandem.gd").new()
	tandem.player = p
	p.add_child(tandem)
	var wide: Node = load("res://features/tandem/reverse_plank.gd").new()
	wide.player = p
	p.add_child(wide)
	await create_timer(3.0).timeout
	check(wide.start(), "Pose entry failed")
	if not wide.active: quit(1); return
	await create_timer(0.4).timeout
	check(p.kneeling == wide and not p.anim.active, "Competing animation ownership")
	await wide.invite_partner()
	check(is_instance_valid(wide.partner_pose) and wide.partner_pose.active, "Partner failed to enter wide kneel")
	if not is_instance_valid(wide.partner_pose): quit(1); return
	await create_timer(0.6).timeout
	check(wide.ap.current_animation == "reverse_plank/support", "Support hands not active")
	var peer: FrontierPlayer = wide.partner
	for n in ["l_knee", "r_knee"]:
		var pos := peer.skeleton.to_global(peer.skeleton.get_bone_global_pose(peer.skeleton.find_bone(n)).origin)
		check(absf(pos.y - 0.055) < 0.05, "Upper knee not grounded")
	for side in ["l", "r"]:
		var heel := p.skeleton.to_global(p.skeleton.get_bone_global_pose(p.skeleton.find_bone(side + "_heel")).origin)
		var toe := p.skeleton.to_global(p.skeleton.get_bone_global_pose(p.skeleton.find_bone(side + "_ball")).origin)
		check((toe - heel).normalized().dot(Vector3.UP) > 0.99, "Toes not upright")
		check(heel.y > 0.015 and heel.y < 0.055, "Heel not grounded")
	var upper_pelvis := peer.skeleton.to_global(peer.skeleton.get_bone_global_pose(peer.skeleton.find_bone("pelvis")).origin)
	var lower_pelvis := p.skeleton.to_global(p.skeleton.get_bone_global_pose(p.skeleton.find_bone("pelvis")).origin)
	check(upper_pelvis.y - lower_pelvis.y > 0.24, "Insufficient body clearance")
	print("SUPPORT pelvis clearance=", upper_pelvis.y - lower_pelvis.y)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(10, 0.1, 10)
	mesh.mesh = box
	world.add_child(mesh)
	mesh.position.y = -0.055
	var sun := DirectionalLight3D.new()
	world.add_child(sun)
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.6
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.22, 0.25, 0.3)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.65
	world.add_child(env)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 48
	for angle in ["side", "front"]:
		camera.position = Vector3(2.7, 1.0, 0.1) if angle == "side" else Vector3(1.8, 1.5, 2.2)
		camera.look_at(Vector3(0, 0.4, 0))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/hip-support-%s.png" % angle)
	wide.stop()
	check(p.kneeling == null and p.anim.active and p.anim.auto_process, "Movement/animation not restored")
	print("HIP_SUPPORT_CHECK failures=", failures)
	quit(failures)
