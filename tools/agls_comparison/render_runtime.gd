extends SceneTree
var player: FrontierPlayer

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://.comparison-private/reports/gameplay-bow-" + name + ".png")
	print("LEGACY_RENDER_CAPTURE ", name)

func run() -> void:
	root.title = "Frontier Legacy — animation verification"
	var level := Node3D.new()
	root.add_child(level)
	current_scene = level
	var floor := StaticBody3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	var collider := CollisionShape3D.new()
	collider.shape = box
	floor.add_child(collider)
	var mesh := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = box.size
	mesh.mesh = floor_mesh
	floor.add_child(mesh)
	floor.position.y = -0.5
	level.add_child(floor)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.12, 0.15)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.7
	environment.environment = env
	level.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	sun.light_energy = 2.0
	sun.shadow_enabled = true
	level.add_child(sun)
	player = FrontierPlayer.new()
	player.name = "Player"
	player.is_local = false
	player.ignore_mouse_capture = true
	player.use_appearance = false
	player.show_gear = false
	player.demo_horse = false
	player.demo_wheelbarrow = false
	player.enable_grip = false
	player.position.y = 0.05
	level.add_child(player)
	var cam := Camera3D.new()
	level.add_child(cam)
	cam.position = Vector3(2.9, 1.75, -2.3)
	cam.look_at(Vector3(0, 1.1, 0))
	cam.fov = 40
	cam.current = true
	await frames(200)
	player.switch_weapon("bow")
	await frames(260)
	Input.action_press("fire")
	await frames(48)
	await capture("partial-draw")
	await frames(50)
	await capture("full-draw")
	Input.action_release("fire")
	await frames(15)
	await capture("release")
	await frames(120)
	Input.action_press("crouch")
	await frames(1)
	Input.action_release("crouch")
	await frames(100)
	Input.action_press("fire")
	await frames(100)
	await capture("crouch-draw")
	Input.action_release("fire")
	print("LEGACY_RENDER_COMPLETE")
	quit()
