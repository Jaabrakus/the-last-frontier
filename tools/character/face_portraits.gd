extends SceneTree
## Portraits of the peoples presets (assets/character/body/peoples.json) with the customizer
## head on the game's body and outfit (PlayerAppearance.dress, the in-game path). Needs a
## window (not --headless); run it under a time limit:
##
##   Godot --path . --resolution 1280x720 -s tools/character/face_portraits.gd -- out=DIR \
##       [light=studio|game] [only=<people>,..] [views=front,34,side,back34] [hat=1|0] [presets=<id>,..]
##       [mode=presets|hair|anim] [zoom=<distance factor>] [dy=<look target offset, m>]
##       [bone=<skeleton bone to frame instead of the head, e.g. l_wrist>] [clip=<clip> t=<s>]
##       [style=stylized|realistic] [complexion=smooth|lined|weathered] [set=presets|stylized|all]
##       [ssao=0] [shadows=0] (studio: without SSAO or the key light's shadow, to tell them apart)
##
## light=studio  a plain Actor_B idling in a neutral three-point studio
## light=game    the real player in main.tscn under the game's own light and grade (u10, the
##               DayNight clock at hour=<h>, default 17), camera at the face
## mode=hair     every hair style on a few looks, back three-quarter, hat on and off
## mode=anim     the player's face in gameplay clips (run, crouch walk, aim, blink half way)
## Views: front, 34, side, back34, high34 (three-quarter from above the hat brim).
## style: the creator's Face style (default: the look's own, i.e. Stylized); complexion: the
## stylized paint's lines; set: which example individuals (the peoples presets, the stylized
## presets, or both; default presets).
## Writes <out>/<preset>_<view>.png (the central square of the window, labelled). Contact
## sheets: tools/character/face_sheets.py. Prints FACE PORTRAITS DONE (or FAILED).

const IDLE := &"actor_b/actor_b-p-stealth-idle"

var args := {}
var out := ""
var failures := PackedStringArray()
var cam: Camera3D
var label: Label
var world: Node3D
var actor: Node3D
var body: CharacterBodyMesh
var player: FrontierPlayer


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			args[a.get_slice("=", 0)] = a.substr(a.find("=") + 1)
	out = args.get("out", "user://face_portraits")
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, OS.has_environment("TB_ON_TOP"))
	var light := String(args.get("light", "studio"))
	if light == "game":
		await _game_stage()
	else:
		await _studio_stage()
	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	label = Label.new()
	label.position = Vector2(300, 12)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 6)
	canvas.add_child(label)
	match String(args.get("mode", "presets")):
		"hair": await _hair_shots(light)
		"anim": await _anim_shots()
		_: await _preset_shots(light)
	print("FACE PORTRAITS DONE" if failures.is_empty() else "FACE PORTRAITS FAILED: " + "; ".join(failures))
	quit(0 if failures.is_empty() else 1)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


# ---------------------------------------------------------------------------
# Stages
# ---------------------------------------------------------------------------
func _studio_stage() -> void:
	world = Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.34, 0.36, 0.38)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.57, 0.6)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = String(args.get("ssao", "1")) == "1"
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	for l in [[Vector3(-30, 25, 0), 1.1, true], [Vector3(-10, -50, 0), 0.35, false], [Vector3(-20, 165, 0), 0.6, false]]:
		var d := DirectionalLight3D.new()
		d.rotation_degrees = l[0]
		d.light_energy = l[1]
		d.shadow_enabled = l[2] and String(args.get("shadows", "1")) == "1"
		world.add_child(d)
	actor = (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	world.add_child(actor)
	var sk := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	body = CharacterBodyMesh.attach(sk, ap)
	BindRest.ensure_character(actor)
	# clip=<name> [t=<s>]: hold a pose of that clip instead of the idle (deformation checks)
	var clip := String(args.get("clip", IDLE))
	if not clip.contains("/"):
		clip = "actor_b/" + clip
	ap.play(clip)
	if args.has("t"):
		ap.seek(float(args.t), true)
		ap.pause()
	cam = Camera3D.new()
	cam.fov = 24.0
	world.add_child(cam)
	cam.current = true
	await _frames(4)


func _game_stage() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(3)
	player = current_scene.get_node("Player")
	player.ignore_mouse_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for n in current_scene.find_children("*", "", true, false):
		if n is DayNight:
			(n as DayNight).clock.running = false
			(n as DayNight).clock.set_time(float(args.get("hour", "17")))
	body = player.appearance.body
	# ssao=0 / ssil=0: the game's screen-space occlusion or indirect light off (to tell them apart)
	for n in current_scene.find_children("*", "WorldEnvironment", true, false):
		var e := (n as WorldEnvironment).environment
		if e and String(args.get("ssao", "1")) == "0":
			e.ssao_enabled = false
		if e and String(args.get("ssil", "1")) == "0":
			e.ssil_enabled = false
	# the game's HUD off (its aim dot sat at the screen centre, on the face)
	for n in current_scene.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	if player.has_method("toggle_hands_free"):
		player.toggle_hands_free()
	cam = Camera3D.new()
	cam.fov = 24.0
	current_scene.add_child(cam)
	cam.current = true
	await _frames(30)


## Head centre (or bone=<name>: that bone) and facing (world) of the shown character.
func _head() -> Array:
	var sk := body.skeleton
	var bone := String(args.get("bone", "headb"))
	var i := sk.find_bone(bone)
	var g := sk.global_transform * sk.get_bone_global_pose(i)
	if bone != "headb":
		return [g.origin, (-player.global_basis.z if player else actor.global_basis.z).normalized()]
	var fwd: Vector3
	if player:
		fwd = -player.global_basis.z
	else:
		fwd = actor.global_basis.z
	fwd.y = 0.0
	return [g.origin + Vector3(0, 0.035, 0) + fwd * 0.03, fwd.normalized()]


func _shoot(view: String, path: String, text: String) -> void:
	var h := _head()
	var c: Vector3 = h[0] + Vector3(0, float(args.get("dy", "0")), 0)
	var fwd: Vector3 = h[1]
	var ang := {"front": 0.0, "34": 38.0, "side": 88.0, "back34": 145.0, "high34": 38.0}.get(view, 0.0) as float
	var dir := fwd.rotated(Vector3.UP, deg_to_rad(ang))
	var dist := (0.95 if view != "back34" else 1.1) * float(args.get("zoom", "1"))
	# high34: from above the brim (a hat's crown and what pokes through it)
	var lift := 0.5 * dist if view == "high34" else 0.03
	cam.global_position = c + dir * dist + Vector3(0, lift, 0)
	cam.look_at(c + Vector3(0, -0.01, 0))
	label.text = text
	await _frames(3)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var s := mini(img.get_width(), img.get_height())
	var sq := img.get_region(Rect2i((img.get_width() - s) / 2, 0, s, s))
	sq.resize(480, 480, Image.INTERPOLATE_LANCZOS)
	var err := sq.save_png(path)
	if err != OK:
		failures.append("save " + path)


func _apply(look: Dictionary) -> void:
	if player:
		player.appearance.apply(look)
	else:
		PlayerAppearance.dress(body, look)
	await _frames(2)


func _set_hat(on: bool) -> void:
	for mi: MeshInstance3D in body.meshes:
		if String(mi.name) == "Hat":
			mi.visible = on


# ---------------------------------------------------------------------------
# Shots
# ---------------------------------------------------------------------------
func _preset_shots(light: String) -> void:
	var only := PackedStringArray(String(args.get("only", "")).split(",", false))
	var pick := PackedStringArray(String(args.get("presets", "")).split(",", false))
	var views := PackedStringArray(String(args.get("views", "front,34,side")).split(",", false))
	_set_hat(String(args.get("hat", "1")) == "1")
	var list: Array = CharacterPeoples.presets()
	match String(args.get("set", "presets")):
		"stylized": list = CharacterPeoples.stylized_presets()
		"all": list = CharacterPeoples.presets() + CharacterPeoples.stylized_presets()
	for pr: Dictionary in list:
		if not only.is_empty() and not String(pr.people) in only:
			continue
		if not pick.is_empty() and not String(pr.id) in pick:
			continue
		var look := CharacterPeoples.preset_look(String(pr.id))
		look.weathering = 0.3
		if args.has("style"):
			look["face_style"] = String(args.style)
		if args.has("complexion"):
			look["complexion"] = String(args.complexion)
		look.debug_view = int(args.get("debug", "0"))
		if args.has("face_only"):          # debugging: one feature at a weight, or none
			var fo := String(args.face_only)
			look.face = {} if fo == "none" else {fo.get_slice(":", 0): float(fo.get_slice(":", 1))}
		if args.has("sex"):
			look.sex = float(args.sex)
		if String(args.get("hat", "1")) != "1":
			look["outfit"] = {"head": {"id": "-"}}   # bare-headed: the hair is not pressed flat
		await _apply(look)
		_set_hat(String(args.get("hat", "1")) == "1")
		if args.has("hide"):
			for mi: MeshInstance3D in body.part_meshes("head"):
				if String(mi.name).ends_with(String(args.hide)):
					mi.visible = false
		for v in views:
			await _shoot(v, "%s/%s_%s.png" % [out, pr.id, v], "%s  (%s, %s)" % [pr.label, v, light])


func _hair_shots(light: String) -> void:
	var looks := ["english_m_a", "haudenosaunee_f_a", "west_african_m_b", "japanese_f_b"]
	var styles := []
	for f in DirAccess.get_files_at(BodyMaterials.HAIR_DIR):
		if f.ends_with(".glb"):
			styles.append(f.get_basename())
	var i := 0
	for st in styles:
		var look := CharacterPeoples.preset_look(looks[i % looks.size()])
		i += 1
		if args.has("style"):
			look["face_style"] = String(args.style)
		look.hair = {"style": st, "color": (look.hair as Dictionary).get("color", "black")}
		await _apply(look)
		for hat in [true, false]:
			# PlayerOutfit shows the tricorn unless the look's outfit takes the hat off ("-")
			look["outfit"] = {} if hat else {"head": {"id": "-"}}
			PlayerAppearance.dress(body, look)
			await _frames(2)
			for v in ["34", "back34"]:
				await _shoot(v, "%s/hair_%s_%s_%s.png" % [out, st, v, "hat" if hat else "nohat"],
						"%s  (%s, %s)" % [st, v, "hat" if hat else "no hat"])


func _anim_shots() -> void:
	if player == null:
		failures.append("mode=anim needs light=game")
		return
	await _apply(CharacterPeoples.preset_look(String(args.get("preset", "west_african_f_a"))))
	var shots := [["idle", []], ["run", ["move_forward", "sprint"]], ["crouch_walk", ["crouch", "move_forward"]],
			["aim", ["aim"]]]
	var views := PackedStringArray(String(args.get("views", "34")).split(",", false))
	for s: Array in shots:
		for a in s[1]:
			Input.action_press(a)
		await _frames(90)
		for v in views:
			await _shoot(v, "%s/anim_%s%s.png" % [out, s[0], "" if v == "34" else "_" + v], "anim: %s (%s)" % [s[0], v])
		for a in s[1]:
			Input.action_release(a)
		await _frames(30)
	player.appearance.blink.set_process(false)
	player.appearance.blink.set_blink(0.5)
	await _shoot("front", "%s/anim_blink_half.png" % out, "blink 0.5")
	player.appearance.blink.set_blink(1.0)
	await _shoot("front", "%s/anim_blink_closed.png" % out, "blink 1.0")
	player.appearance.blink.set_process(true)
