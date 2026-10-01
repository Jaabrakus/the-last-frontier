extends SceneTree
## A flat grey arena with the real player and nothing else, to judge movement animation in (WASD, Shift sprint, Alt walk, C crouch,
## Space jump, 1-6 weapons, the mouse looks). A painted floor, a 1 m grid of posts to read speed and strides against.
##   Godot --path . -s tools/anim_author/test_arena.gd [-- weapon=musket]

var player: FrontierPlayer


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var level := Node3D.new()
	level.name = "Arena"
	root.add_child(level)
	current_scene = level
	var floor := StaticBody3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(300, 1, 300)
	var c := CollisionShape3D.new()
	c.shape = box
	floor.add_child(c)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box.size
	mesh.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.64, 0.66)
	mesh.material_override = m
	floor.add_child(mesh)
	floor.position.y = -0.5
	level.add_child(floor)
	# posts every 5 m on a grid, so a stride and a run read against something
	var post := CylinderMesh.new()
	post.top_radius = 0.06
	post.bottom_radius = 0.06
	post.height = 1.0
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.85, 0.35, 0.2)
	for x in range(-50, 51, 5):
		for z in range(-50, 51, 5):
			if x == 0 and z == 0:
				continue
			var p := MeshInstance3D.new()
			p.mesh = post
			p.material_override = pm
			p.position = Vector3(x, 0.5, z)
			level.add_child(p)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.65, 0.78)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.6
	env.environment = e
	level.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	level.add_child(sun)
	player = FrontierPlayer.new()
	player.name = "Player"
	player.use_appearance = false
	player.show_gear = false
	player.demo_horse = false
	player.demo_wheelbarrow = false
	level.add_child(player)
	player.global_position = Vector3(0, 0.1, 0)
	var weapon := "unarmed"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("weapon="):
			weapon = a.get_slice("=", 1)
	if weapon != "unarmed":
		await create_timer(2.0).timeout
		player.switch_weapon(weapon)
