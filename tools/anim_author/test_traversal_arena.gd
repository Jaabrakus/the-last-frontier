extends SceneTree
## A test level for the traversal moves with the real player: vault walls at the sprint vault's height (0.95 m, sprint at them and
## press Space), a lower and a higher wall, and platforms whose edge is an overhead lip (2.3 m: jump up to it for the hang climb-up).
##   Godot --path . -s tools/anim_author/test_traversal_arena.gd [-- --source-traversal] [weapon=bow] [legs=adapt|procedural|off]
## V cycles the vaults' lower half (PlayerTraversal.vault_legs_mode): off -> adapt -> procedural; the mode is shown top left.
## Cliffs to fall from (lane 4, left): 8 m, 4 m and 2 m; T, G and B put you on top. F cycles the fall: ours (FallPose)
## -> the edited source loop (own-arms-fall, the game's without FallPose) -> the original source loop (actor_b-p-fall, unedited).
## Our own authored traversal clips (data/anim_author/traversal_clips.json) play by default; --source-traversal plays the source's.

var player: FrontierPlayer


## V: the next vault-legs mode, shown on screen.
class LegsKey extends Node:
	var player: FrontierPlayer
	var label: Label
	const MODES := ["off", "adapt", "procedural"]
	const FALLS := ["ours (step off, fall, landing)", "edited source", "original source"]
	var fall_i := 0
	var _edited: Animation

	## The fall loop the locomotion plays (frontier_locomotion/own-arms-fall) swapped in place for `a`.
	func _set_fall_clip(original: bool) -> void:
		var ap: AnimationPlayer = player.anim._ap
		if ap == null or not ap.has_animation_library(&"frontier_locomotion"):
			return
		var lib := ap.get_animation_library(&"frontier_locomotion")
		if _edited == null:
			_edited = lib.get_animation(&"own-arms-fall")
		var a: Animation = _edited
		if original:
			a = ap.get_animation(&"actor_b/actor_b-p-fall").duplicate(true)
			a.loop_mode = _edited.loop_mode
		lib.remove_animation(&"own-arms-fall")
		lib.add_animation(&"own-arms-fall", a)

	func _unhandled_input(e: InputEvent) -> void:
		if e is InputEventKey and e.pressed and not e.echo:
			match (e as InputEventKey).keycode:
				KEY_T:
					player.global_position = Vector3(-14, 8.1, -10)
					player.velocity = Vector3.ZERO
				KEY_G:
					player.global_position = Vector3(-14, 4.1, -24)
					player.velocity = Vector3.ZERO
				KEY_B:
					player.global_position = Vector3(-14, 2.1, -38)
					player.velocity = Vector3.ZERO
				KEY_F:
					if player.anim != null and player.anim.fall_pose != null:
						fall_i = (fall_i + 1) % FALLS.size()
						player.anim.fall_pose.active = fall_i == 0
						_set_fall_clip(fall_i == 2)
						show_mode()
		if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_V and player.traversal != null:
			var i := MODES.find(player.traversal.vault_legs_mode)
			player.traversal.vault_legs_mode = MODES[(i + 1) % MODES.size()]
			show_mode()

	func show_mode() -> void:
		if label != null and player.traversal != null:
			label.text = "Vault legs: %s   (V to change)\nFall: %s   (F to change; T = 8 m, G = 4 m, B = 2 m ledge; H = empty hands)" % [
					player.traversal.vault_legs_mode, FALLS[fall_i]]


func _initialize() -> void:
	call_deferred("run")


func _box(level: Node3D, center: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	var c := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	c.shape = box
	body.add_child(c)
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	m.material_override = mat
	body.add_child(m)
	body.position = center
	level.add_child(body)


func run() -> void:
	var level := Node3D.new()
	level.name = "TraversalArena"
	root.add_child(level)
	current_scene = level
	_box(level, Vector3(0, -0.5, 0), Vector3(300, 1, 300), Color(0.62, 0.64, 0.66))
	# lane 1 (straight ahead): sprint vault walls, 0.95 m, 0.43 m deep, every 12 m
	for i in 4:
		_box(level, Vector3(0, 0.475, -10.0 - 12.0 * i), Vector3(2.4, 0.95, 0.43), Color(0.75, 0.55, 0.35))
	# lane 2 (left): a lower and a higher wall
	_box(level, Vector3(-6, 0.4, -10), Vector3(2.4, 0.8, 0.43), Color(0.55, 0.7, 0.45))
	_box(level, Vector3(-6, 0.5, -22), Vector3(2.4, 1.0, 0.43), Color(0.55, 0.7, 0.45))
	# lane 3 (right): platforms with an overhead lip at 2.3 m (the hang climb-up), and one at 2.5 m
	_box(level, Vector3(7, 1.15, -12), Vector3(4, 2.3, 4), Color(0.6, 0.6, 0.75))
	_box(level, Vector3(7, 1.25, -26), Vector3(4, 2.5, 4), Color(0.6, 0.6, 0.75))
	# lane 4 (far left): cliffs to fall from, 8 m and 4 m (T and G put you on top)
	_box(level, Vector3(-14, 4.0, -10), Vector3(4, 8.0, 4), Color(0.7, 0.62, 0.55))
	_box(level, Vector3(-14, 2.0, -24), Vector3(4, 4.0, 4), Color(0.7, 0.62, 0.55))
	_box(level, Vector3(-14, 1.0, -38), Vector3(4, 2.0, 4), Color(0.7, 0.62, 0.55))
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
	print("TRAVERSAL ARENA own clips: ", not TravPreviewActor.own_clips().is_empty())
	await create_timer(0.5).timeout
	for a in OS.get_cmdline_user_args():
		if a.begins_with("legs=") and player.traversal != null:
			player.traversal.vault_legs_mode = a.get_slice("=", 1)
	var layer := CanvasLayer.new()
	level.add_child(layer)
	var label := Label.new()
	label.position = Vector2(16, 12)
	label.add_theme_font_size_override("font_size", 22)
	layer.add_child(label)
	var keys := LegsKey.new()
	keys.player = player
	keys.label = label
	level.add_child(keys)
	keys.show_mode()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("weapon="):
			await create_timer(2.0).timeout
			player.switch_weapon(a.get_slice("=", 1))
